// PS/2 mouse host for the HDMI mouse probe only. Not used by the JS top.
// Same open-drain bit timing as jmr_ps2_mouse_host, plus the IntelliMouse
// sample-rate magic so a wheel mouse sends a fourth byte. A mouse that
// rejects that magic falls back to the ordinary 3-byte stream.
module mouse_probe_host #(
    parameter int CLK_HZ = 25000000
) (
    input  logic clk,
    input  logic reset,
    // Keyboard listen. The clock is released so the PIC24 can send
    // Set-2 bytes. Clearing this restarts the mouse reset.
    input  logic listen_keys,
    input  logic clock_in,
    input  logic data_in,
    output logic clock_low,
    output logic data_low,
    output logic sample,
    output logic signed [11:0] dx,
    output logic signed [11:0] dy,
    output logic signed [7:0] dz,
    output logic [2:0] buttons,
    output logic ready,
    output logic wheel_ok,
    // A byte that is not a mouse packet, or the whole stream when the
    // device answered keyboard ID AB. Set-2 make codes land here.
    output logic scan_stb,
    output logic [7:0] scan_byte
);
    localparam int POWER_CYCLES = CLK_HZ;
    localparam int INHIBIT_CYCLES = (CLK_HZ / 10000) + 1;
    localparam int SETUP_CYCLES = (CLK_HZ / 100000) + 1;
    localparam int TIMEOUT_CYCLES = CLK_HZ * 2;
    localparam int FRAME_TIMEOUT_CYCLES = CLK_HZ / 500;
    // Bytes inside one mouse packet are ~1 ms apart. A key is one byte,
    // then a gap. 3 ms separates those two shapes.
    localparam int KEY_GAP_CYCLES = CLK_HZ / 300;

    typedef enum logic [3:0] {
        POWER, INHIBIT, REQUEST, SEND, ACK_BIT, REPLY, BAT, IDENT, READ_ID, STREAM, KEYSTREAM, LISTEN
    } state_t;
    state_t state;

    function automatic logic [7:0] script_byte(input logic [2:0] i);
        case (i)
            3'd0: script_byte = 8'hF3;
            3'd1: script_byte = 8'hC8;
            3'd2: script_byte = 8'hF3;
            3'd3: script_byte = 8'h64;
            3'd4: script_byte = 8'hF3;
            3'd5: script_byte = 8'h50;
            3'd6: script_byte = 8'hF2;
            default: script_byte = 8'hF4;
        endcase
    endfunction

    (* ASYNC_REG = "TRUE" *) logic [2:0] clock_sync, data_sync;
    logic old_clock;
    wire falling = old_clock && (clock_sync == 0);
    logic [31:0] timer, frame_timer;
    logic [7:0] command, rx_data, flags, xbyte, ybyte;
    logic [3:0] tx_index, rx_index;
    logic parity, rx_valid, rx_bad;
    logic [1:0] packet_index;
    logic [2:0] script_i;
    logic plain_mode, tried_magic, keyboard_mode, key_prefix;
    logic hold_valid;
    logic [7:0] hold_byte;
    logic [16:0] hold_timer;
    logic [1:0] swallow_n;

    wire receiving = state == REPLY || state == BAT || state == IDENT
        || state == READ_ID || state == STREAM || state == KEYSTREAM
        || state == LISTEN;

    always_ff @(posedge clk) begin
        if (reset) begin
            clock_sync <= 7;
            data_sync <= 7;
            old_clock <= 1;
        end else begin
            clock_sync <= {clock_sync[1:0], clock_in};
            data_sync <= {data_sync[1:0], data_in};
            if (clock_sync == 7) old_clock <= 1;
            else if (clock_sync == 0) old_clock <= 0;
        end
    end

    always_ff @(posedge clk) begin
        rx_valid <= 0;
        rx_bad <= 0;
        if (reset || !receiving) begin
            rx_index <= 0;
            rx_data <= 0;
            parity <= 0;
            frame_timer <= 0;
        end else begin
            if (rx_index != 0) frame_timer <= frame_timer + 1;
            if (rx_index != 0 && frame_timer >= FRAME_TIMEOUT_CYCLES) begin
                rx_bad <= 1;
                rx_index <= 0;
                frame_timer <= 0;
            end else if (falling) begin
                frame_timer <= 0;
                if (rx_index == 0) begin
                    if (!data_sync[2]) begin
                        rx_index <= 1;
                        parity <= 0;
                    end
                end else if (rx_index <= 8) begin
                    rx_data[rx_index-1] <= data_sync[2];
                    parity <= parity ^ data_sync[2];
                    rx_index <= rx_index + 1;
                end else if (rx_index == 9) begin
                    parity <= parity ^ data_sync[2];
                    rx_index <= 10;
                end else begin
                    rx_index <= 0;
                    if (data_sync[2] && parity) rx_valid <= 1;
                    else rx_bad <= 1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= POWER;
            timer <= 0;
            clock_low <= 0;
            data_low <= 0;
            command <= 8'hFF;
            tx_index <= 0;
            ready <= 0;
            sample <= 0;
            dx <= 0;
            dy <= 0;
            dz <= 0;
            buttons <= 0;
            wheel_ok <= 0;
            packet_index <= 0;
            flags <= 0;
            xbyte <= 0;
            ybyte <= 0;
            script_i <= 0;
            plain_mode <= 0;
            tried_magic <= 0;
            keyboard_mode <= 0;
            key_prefix <= 0;
            scan_stb <= 0;
            scan_byte <= 0;
            hold_valid <= 0;
            hold_byte <= 0;
            hold_timer <= 0;
            swallow_n <= 0;
        end else begin
            timer <= timer + 1;
            sample <= 0;
            scan_stb <= 0;
            if (listen_keys) begin
                // Stop driving the bus. A keyboard only talks while the
                // clock wire is free.
                clock_low <= 0;
                data_low <= 0;
                ready <= 1;
                keyboard_mode <= 1;
                key_prefix <= 0;
                packet_index <= 0;
                if (state != LISTEN) begin
                    state <= LISTEN;
                    timer <= 0;
                    hold_valid <= 0;
                    swallow_n <= 0;
                end else if (rx_valid && swallow_n != 0) begin
                    // Rest of a mouse packet (Y, and Z when the wheel is on).
                    swallow_n <= swallow_n - 1'b1;
                end else if (rx_valid && hold_valid) begin
                    // The held byte was a mouse status: the next byte
                    // arrived with no gap. Drop it and the bytes after it.
                    // A move of 9 counts is byte 09, which is also F10.
                    hold_valid <= 0;
                    swallow_n <= wheel_ok ? 2'd2 : 2'd1;
                end else if (rx_valid && rx_data[3]) begin
                    // Might be a mouse status or a key whose code has bit 3
                    // set (F10 is 09, A is 1C). Wait one gap to tell.
                    hold_valid <= 1;
                    hold_byte <= rx_data;
                    hold_timer <= 0;
                end else if (rx_valid) begin
                    scan_byte <= rx_data;
                    scan_stb <= 1;
                end else if (hold_valid && hold_timer >= KEY_GAP_CYCLES[16:0]) begin
                    hold_valid <= 0;
                    scan_byte <= hold_byte;
                    scan_stb <= 1;
                end else if (hold_valid) begin
                    hold_timer <= hold_timer + 1'b1;
                end
            end else if (state == LISTEN) begin
                clock_low <= 1;
                data_low <= 0;
                ready <= 0;
                keyboard_mode <= 0;
                command <= 8'hFF;
                tx_index <= 0;
                timer <= 0;
                hold_valid <= 0;
                swallow_n <= 0;
                state <= INHIBIT;
            // KEYSTREAM and LISTEN stay in receive. Pulling the clock low
            // inhibits the PIC24 keyboard path.
            end else if (state != KEYSTREAM && (
                (state != POWER && state != STREAM && timer >= TIMEOUT_CYCLES)
                || (state == STREAM && packet_index != 0 && timer >= FRAME_TIMEOUT_CYCLES * 5)
                || rx_bad)) begin
                clock_low <= 0;
                data_low <= 0;
                ready <= 0;
                keyboard_mode <= 0;
                key_prefix <= 0;
                state <= POWER;
                timer <= 0;
                command <= 8'hFF;
                packet_index <= 0;
                if (!ready && tried_magic) plain_mode <= 1;
            end else case (state)
                POWER: if (timer >= POWER_CYCLES) begin
                    clock_low <= 1;
                    timer <= 0;
                    command <= 8'hFF;
                    state <= INHIBIT;
                end
                INHIBIT: if (timer >= INHIBIT_CYCLES) begin
                    data_low <= 1;
                    timer <= 0;
                    state <= REQUEST;
                end
                REQUEST: if (timer >= SETUP_CYCLES) begin
                    clock_low <= 0;
                    timer <= 0;
                    tx_index <= 0;
                    state <= SEND;
                end
                SEND: if (falling) begin
                    if (tx_index < 8) data_low <= !command[tx_index[2:0]];
                    else if (tx_index == 8) data_low <= ^command;
                    else begin
                        data_low <= 0;
                        state <= ACK_BIT;
                    end
                    tx_index <= tx_index + 1;
                end
                ACK_BIT: if (falling) begin
                    if (data_sync[2]) begin
                        state <= POWER;
                        timer <= 0;
                        command <= 8'hFF;
                        keyboard_mode <= 0;
                        if (tried_magic) plain_mode <= 1;
                    end else begin
                        state <= REPLY;
                        timer <= 0;
                    end
                end
                REPLY: if (rx_valid) begin
                    if (rx_data == 8'hFA) begin
                        timer <= 0;
                        if (command == 8'hFF) state <= BAT;
                        else if (command == 8'hF2) state <= READ_ID;
                        else if (script_i == 7) begin
                            ready <= 1;
                            if (keyboard_mode) state <= KEYSTREAM;
                            else begin
                                state <= STREAM;
                                packet_index <= 0;
                            end
                        end else begin
                            script_i <= script_i + 1;
                            command <= script_byte(script_i + 1);
                            clock_low <= 1;
                            state <= INHIBIT;
                        end
                    end else begin
                        state <= POWER;
                        timer <= 0;
                        command <= 8'hFF;
                        keyboard_mode <= 0;
                        if (tried_magic) plain_mode <= 1;
                    end
                end
                BAT: if (rx_valid) begin
                    timer <= 0;
                    if (rx_data == 8'hAA) state <= IDENT;
                    else begin
                        state <= POWER;
                        command <= 8'hFF;
                        keyboard_mode <= 0;
                    end
                end
                IDENT: if (rx_valid) begin
                    timer <= 0;
                    if (rx_data == 0) begin
                        keyboard_mode <= 0;
                        if (plain_mode) begin
                            script_i <= 7;
                            command <= 8'hF4;
                            wheel_ok <= 0;
                        end else begin
                            script_i <= 0;
                            command <= script_byte(0);
                            tried_magic <= 1;
                        end
                        clock_low <= 1;
                        state <= INHIBIT;
                    end else if (rx_data == 8'hAB) begin
                        // Keyboard ID, not a mouse. Enable the stream and
                        // do not parse the following bytes as movement.
                        keyboard_mode <= 1;
                        script_i <= 7;
                        command <= 8'hF4;
                        clock_low <= 1;
                        state <= INHIBIT;
                    end else begin
                        state <= POWER;
                        command <= 8'hFF;
                        keyboard_mode <= 0;
                    end
                end
                READ_ID: if (rx_valid) begin
                    timer <= 0;
                    wheel_ok <= (rx_data == 8'h03);
                    script_i <= 7;
                    command <= 8'hF4;
                    clock_low <= 1;
                    state <= INHIBIT;
                end
                STREAM: begin
                    if (packet_index == 0 || rx_valid) timer <= 0;
                    if (rx_valid) case (packet_index)
                        2'd0: if (key_prefix || !rx_data[3]) begin
                            // Not a mouse status byte, or the data byte that
                            // follows E0/F0. A Set-2 letter whose own bit 3
                            // is set would otherwise be eaten as movement.
                            scan_byte <= rx_data;
                            scan_stb <= 1;
                            key_prefix <= (rx_data == 8'hE0) || (rx_data == 8'hF0);
                        end else begin
                            flags <= rx_data;
                            packet_index <= 1;
                            key_prefix <= 0;
                        end
                        2'd1: begin
                            xbyte <= rx_data;
                            packet_index <= 2;
                        end
                        2'd2: begin
                            ybyte <= rx_data;
                            if (wheel_ok) packet_index <= 3;
                            else begin
                                packet_index <= 0;
                                buttons <= flags[2:0];
                                if (flags[7:6] != 0) begin
                                    dx <= 0;
                                    dy <= 0;
                                end else begin
                                    dx <= {{4{flags[4]}}, xbyte};
                                    dy <= {{4{flags[5]}}, ybyte};
                                end
                                dz <= 0;
                                sample <= 1;
                            end
                        end
                        default: begin
                            packet_index <= 0;
                            buttons <= flags[2:0];
                            if (flags[7:6] != 0) begin
                                dx <= 0;
                                dy <= 0;
                            end else begin
                                dx <= {{4{flags[4]}}, xbyte};
                                dy <= {{4{flags[5]}}, ybyte};
                            end
                            dz <= $signed(rx_data);
                            sample <= 1;
                        end
                    endcase
                end
                KEYSTREAM: if (rx_valid) begin
                    timer <= 0;
                    scan_byte <= rx_data;
                    scan_stb <= 1;
                end
                default: begin
                    state <= POWER;
                    timer <= 0;
                    clock_low <= 0;
                    data_low <= 0;
                    ready <= 0;
                end
            endcase
        end
    end
endmodule
