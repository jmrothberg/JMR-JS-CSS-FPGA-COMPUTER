// UART tether — GUI mirror + typing (BASIC top_nexys_a7 method, simplified).
//
//   RX: raw ASCII bytes → keyboard FIFO push (LF/CR fold to 0x0D = Enter;
//       0x1B Esc passes through for BREAK). No command grammar — the JS
//       console owns the glass, exactly like the USB keyboard path.
//   TX dumps (yield between rows / between key notes):
//       "S<rowhex>:" + 64 chars + "\n"          text console rows 0..F
//       "P<rr>:" + 160 hex nibbles + "\n"       subsample 160×120 of 640×480 FB
//       "K\n"                                   USB Host ps2_strobe edge
//       Host places rows by index and resyncs on torn frames (BASIC method).
//       HDMI paints full 640×480; tether keeps 160×120×4 for bandwidth.//
// uart_simple is the proven BASIC 8N1 core (rounded divider, wr_en-safe busy).
module uart_simple #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic       tx,
    input  logic       wr_en,
    input  logic [7:0] wr_data,
    output logic       tx_busy,
    output logic       rx_ready,
    input  logic       rx_pop,
    output logic [7:0] rx_data
);
    // Round to nearest, not truncate (BASIC fix for slow-clock baud error).
    localparam int DIV = (CLK_HZ + (BAUD / 2)) / BAUD;

    // TX
    logic [15:0] tx_div;
    logic [3:0]  tx_bit;
    logic [9:0]  tx_shift;
    logic        tx_active;

    // Include wr_en, or every other byte is silently dropped (BASIC fix:
    // tx_active only rises the cycle AFTER wr_en is sampled).
    assign tx_busy = tx_active | wr_en;
    assign tx = tx_active ? tx_shift[0] : 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_active <= 1'b0;
            tx_div <= '0;
            tx_bit <= '0;
            tx_shift <= '1;
        end else if (tx_active) begin
            if (tx_div == DIV[15:0] - 16'd1) begin
                tx_div <= '0;
                tx_shift <= {1'b1, tx_shift[9:1]};
                if (tx_bit == 4'd9)
                    tx_active <= 1'b0;
                else
                    tx_bit <= tx_bit + 4'd1;
            end else begin
                tx_div <= tx_div + 16'd1;
            end
        end else if (wr_en) begin
            tx_shift <= {1'b1, wr_data, 1'b0}; // stop, data, start
            tx_bit <= '0;
            tx_div <= '0;
            tx_active <= 1'b1;
        end
    end

    // RX
    logic [15:0] rx_div;
    logic [3:0]  rx_bit;
    logic [7:0]  rx_shift;
    logic        rx_active;
    logic        rx_ready_r;
    logic [7:0]  rx_data_r;
    logic        rx_q, rx_qq;

    assign rx_ready = rx_ready_r;
    assign rx_data  = rx_data_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_q <= 1'b1;
            rx_qq <= 1'b1;
            rx_active <= 1'b0;
            rx_ready_r <= 1'b0;
            rx_data_r <= 8'h00;
            rx_div <= '0;
            rx_bit <= '0;
            rx_shift <= '0;
        end else begin
            rx_q <= rx;
            rx_qq <= rx_q;
            if (rx_pop)
                rx_ready_r <= 1'b0;

            if (!rx_active) begin
                if (rx_qq == 1'b0) begin // start bit
                    rx_active <= 1'b1;
                    rx_div <= DIV[15:0] / 16'd2;
                    rx_bit <= '0;
                end
            end else if (rx_div == DIV[15:0] - 16'd1) begin
                rx_div <= '0;
                if (rx_bit == 4'd0) begin
                    rx_bit <= 4'd1;      // mid-start sampled; next are data
                end else if (rx_bit <= 4'd8) begin
                    rx_shift <= {rx_qq, rx_shift[7:1]};
                    rx_bit <= rx_bit + 4'd1;
                end else begin
                    rx_data_r <= rx_shift;
                    rx_ready_r <= 1'b1;
                    rx_active <= 1'b0;
                end
            end else begin
                rx_div <= rx_div + 16'd1;
            end
        end
    end
endmodule


module jmr_uart_link #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 115200,
    // NEW: Nexys Video PROG jack is FT245 FIFO (DPTI), not UART. T100/A7 used UART.
    parameter bit USE_DPTI = 0
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       uart_rx,     // J13 FT232R (unused when USE_DPTI)
    output logic       uart_tx,
    // DPTI / FT2232 ch B on J12 PROG (Nexys Video tether — same cable as JTAG)
    inout  wire  [7:0] prog_d,
    input  logic       prog_rxen = 1'b1,
    input  logic       prog_txen = 1'b1,
    output logic       prog_rdn,
    output logic       prog_wrn,
    output logic       prog_oen,
    output logic       prog_siwun,
    // Keyboard inject (merged with PS/2 in the top)
    output logic       kbd_push,
    output logic [7:0] kbd_data,
    // NEW: GUI play keys over PROG tether (ORed with JB stick; console optional)
    output logic [5:0] joy_bits,
    // Char VRAM dump read port (jmr_js_core dump_addr/dump_data)
    output logic [9:0] dump_addr,
    input  logic [7:0] dump_data,
    // NEW: subsample of 640×480 FB for tether (160×120 → host ×4)
    output logic [18:0] dump_fb_raddr,
    input  logic [7:0]  dump_fb_rdata,
    // NEW: when game_mode, stream P-rows (mini-FB) instead of text S-rows
    input  logic       game_mode = 1'b0,
    // NEW: log USB scancodes to tether (flight-log proof without guessing LEDs)
    input  logic       ps2_strobe = 1'b0,
    // NEW: HTML RUN .JSH stream (0xFD + u32 LE length + payload)
    output logic       jsb_tether_stb,
    output logic [7:0] jsb_tether_data,
    output logic       jsb_tether_eof,
    input  logic       jsb_tether_rdy = 1'b0
);
    logic       rx_ready;
    logic [7:0] rx_data;
    logic       tx_busy;
    logic       wr_en;
    logic [7:0] wr_data;
    logic       rx_pop;
    // NEW: 0xFD + u32 LE length + payload → console C_JSB_TETHER (not kbd)
    typedef enum logic [2:0] {
        JSH_IDLE, JSH_L0, JSH_L1, JSH_L2, JSH_L3, JSH_DATA
    } jsh_t;
    jsh_t jsh_st;
    logic [31:0] jsh_left;
    logic        jsh_eof_pend;
    // Board freeze root cause (2026-08-25): eof was a 1-cycle pulse
    // raised the same cycle the LAST data byte strobes - the console is
    // then in C_JSB_FEED processing that byte and returns to
    // C_JSB_TETHER only cycles later, so it could never see the pulse:
    // every HTML RUN parked forever after a perfect stream. Hold eof
    // until the console (jsb_tether_rdy) samples it.
    logic        jsh_eof_hold;
    wire jsh_hold = (jsh_st == JSH_DATA) && !jsb_tether_rdy;
    assign rx_pop = rx_ready && !jsh_hold;
    assign jsb_tether_stb = rx_ready && (jsh_st == JSH_DATA) && jsb_tether_rdy;
    assign jsb_tether_data = rx_data;
    assign jsb_tether_eof = jsh_eof_hold;

    generate
        if (USE_DPTI) begin : g_dpti
            assign uart_tx = 1'b1;
            jmr_ft245_async u_phy (
                .clk(clk), .rst_n(rst_n),
                .d(prog_d), .rxf_n(prog_rxen), .txe_n(prog_txen),
                .rd_n(prog_rdn), .wr_n(prog_wrn),
                .oe_n(prog_oen), .siwu_n(prog_siwun),
                .wr_en(wr_en), .wr_data(wr_data), .tx_busy(tx_busy),
                .rx_ready(rx_ready), .rx_pop(rx_pop), .rx_data(rx_data)
            );
        end else begin : g_uart
            assign prog_rdn = 1'b1;
            assign prog_wrn = 1'b1;
            assign prog_oen = 1'b1;
            assign prog_siwun = 1'b1;
            uart_simple #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_uart (
                .clk(clk), .rst_n(rst_n),
                .rx(uart_rx), .tx(uart_tx),
                .wr_en(wr_en), .wr_data(wr_data), .tx_busy(tx_busy),
                .rx_ready(rx_ready), .rx_pop(rx_pop), .rx_data(rx_data)
            );
        end
    endgenerate

    // RX → keyboard FIFO, KEYBITS 0xFE, or JSHLOAD 0xFD (HTML RUN blob).
    logic joy_cmd;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kbd_push <= 1'b0;
            kbd_data <= 8'h00;
            joy_bits <= 6'b0;
            joy_cmd <= 1'b0;
            jsh_st <= JSH_IDLE;
            jsh_left <= 32'd0;
            jsh_eof_pend <= 1'b0;
            jsh_eof_hold <= 1'b0;
        end else begin
            kbd_push <= 1'b0;
            jsh_eof_pend <= 1'b0;
            if (jsh_eof_pend)                       jsh_eof_hold <= 1'b1;
            else if (jsh_eof_hold && jsb_tether_rdy) jsh_eof_hold <= 1'b0;
            if (rx_ready && rx_pop) begin
                if (jsh_st == JSH_L0) begin
                    jsh_left[7:0] <= rx_data;
                    jsh_st <= JSH_L1;
                end else if (jsh_st == JSH_L1) begin
                    jsh_left[15:8] <= rx_data;
                    jsh_st <= JSH_L2;
                end else if (jsh_st == JSH_L2) begin
                    jsh_left[23:16] <= rx_data;
                    jsh_st <= JSH_L3;
                end else if (jsh_st == JSH_L3) begin
                    jsh_left[31:24] <= rx_data;
                    if ({rx_data, jsh_left[23:0]} == 32'd0) begin
                        jsh_eof_pend <= 1'b1;
                        jsh_st <= JSH_IDLE;
                    end else
                        jsh_st <= JSH_DATA;
                end else if (jsh_st == JSH_DATA) begin
                    if (jsh_left <= 32'd1) begin
                        jsh_left <= 32'd0;
                        jsh_eof_pend <= 1'b1;
                        jsh_st <= JSH_IDLE;
                    end else
                        jsh_left <= jsh_left - 32'd1;
                end else if (joy_cmd) begin
                    joy_bits <= rx_data[5:0];
                    joy_cmd <= 1'b0;
                end else if (rx_data == 8'hFD) begin
                    jsh_st <= JSH_L0;
                    jsh_left <= 32'd0;
                end else if (rx_data == 8'hFE) begin
                    joy_cmd <= 1'b1;
                end else begin
                    kbd_push <= 1'b1;
                    kbd_data <= (rx_data == 8'h0A || rx_data == 8'h0D) ? 8'h0D : rx_data;
                end
            end
        end
    end

    // TX dump FSM:
    //   text:  "S<rowhex>:" + 64 chars + "\n"   (rows 0..F)
    //   game:  "P<rr>:" + 160 hex nibbles + "\n" (subsample of 640×480)
    //   key:   "K\n" once when ps2_strobe fires (between dumps)
    typedef enum logic [3:0] {
        HB_IDLE, HB_HDR, HB_ROW, HB_ROW2, HB_COLON, HB_BYTE, HB_NL, HB_K, HB_KNL
    } hb_t;
    hb_t hb_state;
    logic        dump_active;
    logic        dump_game;     // latched at dump start
    logic [21:0] dump_div;
    logic [6:0]  fb_row;        // 0..119
    logic [7:0]  fb_col;        // 0..159
    logic        k_pending;
    logic        ps2_strobe_q;
    // NEW: register pixel/char before wr_data (dump_addr→RAM→wr was WNS −0.025)
    logic [7:0]  dump_byte_q;

    function automatic logic [7:0] hex_digit(input logic [3:0] n);
        hex_digit = (n < 4'd10) ? (8'h30 + {4'b0, n}) : (8'h37 + {4'b0, n});
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hb_state <= HB_IDLE;
            dump_addr <= '0;
            dump_fb_raddr <= '0;
            dump_active <= 1'b0;
            dump_game <= 1'b0;
            dump_div <= '0;
            fb_row <= '0;
            fb_col <= '0;
            wr_en <= 1'b0;
            wr_data <= 8'h0;
            k_pending <= 1'b0;
            ps2_strobe_q <= 1'b0;
            dump_byte_q <= 8'h20;
        end else begin
            wr_en <= 1'b0;
            dump_div <= dump_div + 22'd1;
            ps2_strobe_q <= ps2_strobe;
            // Rising edge of USB scancode strobe → one tether note
            if (ps2_strobe && !ps2_strobe_q)
                k_pending <= 1'b1;
            // Sample VRAM/FB one cycle ahead of HB_BYTE consume
            if (dump_game)
                dump_byte_q <= hex_digit(dump_fb_rdata[3:0]);
            else
                dump_byte_q <= (dump_data < 8'h20 || dump_data > 8'h7E) ? 8'h20 : dump_data;

            unique case (hb_state)
                HB_IDLE: begin
                    if (k_pending && !tx_busy && !dump_active) begin
                        k_pending <= 1'b0;
                        hb_state <= HB_K;
                    end else if (dump_active && !tx_busy) begin
                        hb_state <= HB_HDR;
                    end else if (dump_div == 22'h3FFFFF && !tx_busy) begin
                        dump_addr <= '0;
                        dump_fb_raddr <= '0;
                        fb_row <= '0;
                        fb_col <= '0;
                        dump_game <= game_mode;
                        dump_active <= 1'b1;
                        hb_state <= HB_HDR;
                    end
                end
                HB_K: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= "K";
                    hb_state <= HB_KNL;
                end
                HB_KNL: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= 8'h0A;
                    hb_state <= HB_IDLE;
                end
                HB_HDR: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= dump_game ? "P" : "S";
                    hb_state <= dump_game ? HB_ROW : HB_ROW;
                end
                // Text: one hex digit. Game: two hex digits for row 0..119.
                HB_ROW: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    if (dump_game) begin
                        wr_data <= hex_digit(fb_row[6:4]);
                        hb_state <= HB_ROW2;
                    end else begin
                        wr_data <= (dump_addr[9:6] < 4'd10)
                                 ? (8'h30 + {4'b0, dump_addr[9:6]})
                                 : (8'h37 + {4'b0, dump_addr[9:6]});
                        hb_state <= HB_COLON;
                    end
                end
                HB_ROW2: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(fb_row[3:0]);
                    hb_state <= HB_COLON;
                end
                HB_COLON: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= ":";
                    hb_state <= HB_BYTE;
                end
                HB_BYTE: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    // NEW: use registered sample (breaks dump_addr→wr_data combo)
                    wr_data <= dump_byte_q;
                    if (dump_game) begin
                        if (fb_col == 8'd159) begin
                            hb_state <= HB_NL;
                        end else begin
                            fb_col <= fb_col + 8'd1;
                            // subsample: next pixel at (row*4, col*4) in 640×480
                            dump_fb_raddr <= 19'(fb_row) * 19'd2560
                                          + 19'(fb_col + 8'd1) * 19'd4;
                        end
                    end else begin
                        if (dump_addr[5:0] == 6'd63) hb_state <= HB_NL;
                        dump_addr <= dump_addr + 10'd1;
                    end
                end
                HB_NL: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= 8'h0A;
                    if (dump_game) begin
                        fb_col <= 8'd0;
                        if (fb_row == 7'd119) begin
                            dump_active <= 1'b0;
                            fb_row <= '0;
                            dump_fb_raddr <= '0;
                        end else begin
                            fb_row <= fb_row + 7'd1;
                            // next subsample row start: ((row+1)*4)*640
                            dump_fb_raddr <= 19'(fb_row + 7'd1) * 19'd2560;
                        end
                    end else begin
                        // dump_addr wrapped to 0 => all 16 rows sent
                        if (dump_addr == 10'd0) dump_active <= 1'b0;
                    end
                    hb_state <= HB_IDLE;
                end
                default: hb_state <= HB_IDLE;
            endcase
        end
    end
endmodule
