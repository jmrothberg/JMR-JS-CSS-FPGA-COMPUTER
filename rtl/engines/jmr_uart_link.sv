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
    input  logic [7:0] ps2_code = 8'h00,
    // storage state telemetry: "Dxx" line when it CHANGES while busy
    // (a stalled DIR parks in one state - one line names it)
    input  logic [6:0] stor_state = 7'd0,
    input  logic [15:0] stor_op_clk = 16'd0,   // run 71: E line carries it
    input  logic [6:0] cons_state = 7'd0,
    // BOARD VM heartbeat: packed {0,st[6:0],fault[7:0],ip[15:0]}, already
    // registered in the VM domain - sampled here as a plain register.
    input  logic [31:0] vm_vdbg = 32'd0,
    input  logic        vm_vdbg_fault = 1'b0,
    // run-60 observability: heap gauge + fault snapshot + ip trace
    input  logic [31:0] vm_hdbg = 32'd0,
    input  logic [31:0] vm_fdbg = 32'd0,
    input  logic        vm_fdbg_v = 1'b0,
    input  logic [47:0] vm_gdbg = 48'd0,
    input  logic [127:0] vm_ftrace = 128'd0,
    // NEW: HTML RUN .JSH stream (0xFD + u32 LE length + payload)
    //       SOURCE put (0xFC + u32 LE length + payload) — then host SAVE
    output logic       jsb_tether_stb,
    output logic [7:0] jsb_tether_data,
    output logic       jsb_tether_eof,
    output logic       jsb_tether_src, // 1 while an 0xFC SOURCE stream is live
    output logic       jsb_tether_crc_err, // run 71: held with eof when the
                                           // trailer CRC-32 mismatched
    input  logic       jsb_tether_rdy = 1'b0
);
    logic       rx_ready;
    logic [7:0] rx_data;
    logic       tx_busy;
    logic       wr_en;
    logic [7:0] wr_data;
    logic       rx_pop;
    // NEW: 0xFD + u32 LE length + payload → console C_JSB_TETHER (not kbd)
    typedef enum logic [3:0] {
        JSH_IDLE, JSH_L0, JSH_L1, JSH_L2, JSH_L3, JSH_DATA,
        JSH_C0, JSH_C1, JSH_C2, JSH_C3   // run 71: CRC-32 trailer
    } jsh_t;
    jsh_t jsh_st;
    logic [31:0] jsh_left;
    logic        jsh_eof_pend;
    logic        jsh_src; // 1 = 0xFC SOURCE fill (not 0xFD ProgramImage)
    // Board freeze root cause (2026-08-25): eof was a 1-cycle pulse
    // raised the same cycle the LAST data byte strobes - the console is
    // then in C_JSB_FEED processing that byte and returns to
    // C_JSB_TETHER only cycles later, so it could never see the pulse:
    // every HTML RUN parked forever after a perfect stream. Hold eof
    // until the console (jsb_tether_rdy) samples it.
    logic        jsh_eof_hold;
    wire jsh_hold = (jsh_st == JSH_DATA) && !jsb_tether_rdy;

    // Run 71: CRC-32 (IEEE, reflected, init FFFFFFFF, final ~) over the
    // 0xFC/0xFD payload, byte-serial so it costs one 32-bit register and a
    // few XOR levels. The host appends crc32(payload) little-endian after
    // the payload; a mismatch raises jsb_tether_crc_err alongside eof and
    // the console discards the stream (?CK) — a dropped USB byte can never
    // become a silently corrupted SOURCE or program image again.
    logic [31:0] crc_acc, crc_rx;
    logic        crc_err_r;
    function automatic logic [31:0] crc32_byte(input logic [31:0] c, input logic [7:0] b);
        logic [31:0] x;
        begin
            x = c ^ {24'd0, b};
            for (int i = 0; i < 8; i++)
                x = x[0] ? ((x >> 1) ^ 32'hEDB88320) : (x >> 1);
            crc32_byte = x;
        end
    endfunction
    assign jsb_tether_crc_err = crc_err_r;
    assign rx_pop = rx_ready && !jsh_hold;
    assign jsb_tether_stb = rx_ready && (jsh_st == JSH_DATA) && jsb_tether_rdy;
    assign jsb_tether_data = rx_data;
    assign jsb_tether_eof = jsh_eof_hold;
    assign jsb_tether_src = jsh_src;

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

    // RX → keyboard FIFO, KEYBITS 0xFE, JSHLOAD 0xFD, SOURCE put 0xFC.
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
            jsh_src <= 1'b0;
            crc_acc <= 32'hFFFFFFFF; crc_rx <= 32'd0; crc_err_r <= 1'b0;
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
                    crc_acc <= 32'hFFFFFFFF;
                    crc_err_r <= 1'b0;
                    if ({rx_data, jsh_left[23:0]} == 32'd0) begin
                        jsh_eof_pend <= 1'b1;
                        jsh_src <= 1'b0;
                        jsh_st <= JSH_IDLE;
                    end else
                        jsh_st <= JSH_DATA;
                end else if (jsh_st == JSH_DATA) begin
                    crc_acc <= crc32_byte(crc_acc, rx_data);
                    if (jsh_left <= 32'd1) begin
                        jsh_left <= 32'd0;
                        jsh_st <= JSH_C0;     // trailer next; eof after it
                    end else
                        jsh_left <= jsh_left - 32'd1;
                end else if (jsh_st == JSH_C0) begin
                    crc_rx[7:0] <= rx_data;   jsh_st <= JSH_C1;
                end else if (jsh_st == JSH_C1) begin
                    crc_rx[15:8] <= rx_data;  jsh_st <= JSH_C2;
                end else if (jsh_st == JSH_C2) begin
                    crc_rx[23:16] <= rx_data; jsh_st <= JSH_C3;
                end else if (jsh_st == JSH_C3) begin
                    crc_err_r <= ({rx_data, crc_rx[23:0]} != ~crc_acc);
                    jsh_eof_pend <= 1'b1;
                    jsh_src <= 1'b0;
                    jsh_st <= JSH_IDLE;
                end else if (joy_cmd) begin
                    joy_bits <= rx_data[5:0];
                    joy_cmd <= 1'b0;
                end else if (rx_data == 8'hFC) begin
                    // gui-put: SOURCE fill, then host types SAVE
                    jsh_st <= JSH_L0;
                    jsh_left <= 32'd0;
                    jsh_src <= 1'b1;
                end else if (rx_data == 8'hFD) begin
                    jsh_st <= JSH_L0;
                    jsh_left <= 32'd0;
                    jsh_src <= 1'b0;
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
    typedef enum logic [4:0] {
        HB_IDLE, HB_HDR, HB_ROW, HB_ROW2, HB_COLON, HB_BYTE, HB_NL, HB_K, HB_KH, HB_KL, HB_KNL,
        HB_V, HB_VN, HB_VNL, HB_E2, HB_E3,
        HB_H, HB_HN, HB_F, HB_FN, HB_T, HB_TN, HB_G, HB_GN, HB_E4
    } hb_t;
    hb_t hb_state;
    // run-60 observability serializers
    logic        h_pending, f_pending, t_pending, fdbg_v_q;
    logic [31:0] h_latch, f_latch, fp_latch;
    logic [127:0] t_latch;
    logic [2:0]  h_nib;
    logic [3:0]  f_nib;
    logic [4:0]  t_nib;
    logic [15:0] e_op_q;
    logic [1:0]  e_nib;
    logic        g_pending;
    logic [47:0] g_latch;
    logic [3:0]  g_nib;
    logic        dump_active;
    logic        dump_game;     // latched at dump start
    logic [21:0] dump_div;
    logic [6:0]  fb_row;        // 0..119
    logic [7:0]  fb_col;        // 0..159
    logic        k_pending;
    logic        ps2_strobe_q;
    logic [7:0]  k_code_q;
    logic [6:0]  stor_q;
    logic        d_pending;
    logic [1:0]  d_sel; // 0=K 1=D 2=E line
    logic [7:0]  d_code_q;
    logic        v_pending;
    logic [31:0] v_latch;
    logic [2:0]  v_nib;
    logic        vfault_q, dump_active_q;
    logic        e_pending, e_chg;
    logic [7:0]  e_code_q;
    logic [7:0]  e_cons_q;
    logic [26:0] e_beat;
    logic        v_beat_q;
    logic [26:0] d_dwell;  // continuous-busy dwell (board: the old
    // single-state equality never fired - a stall can LOOP between states)
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
            stor_q <= 7'd0; d_pending <= 1'b0; d_sel <= 2'd0;
            v_pending <= 1'b0; v_latch <= 32'd0; v_nib <= 3'd0;
            h_pending <= 1'b0; h_latch <= 32'd0;
            f_pending <= 1'b0; f_latch <= 32'd0; fp_latch <= 32'd0;
            t_pending <= 1'b0; t_latch <= 128'd0; t_nib <= 5'd0;
            g_pending <= 1'b0; g_latch <= 48'd0; g_nib <= 4'd0;
            fdbg_v_q <= 1'b0;
            vfault_q <= 1'b0; dump_active_q <= 1'b0;
            d_code_q <= 8'd0; d_dwell <= 26'd0;
            e_pending <= 1'b0; e_chg <= 1'b0; e_code_q <= 8'd0; e_cons_q <= 8'd0; e_op_q <= 16'd0; e_beat <= 27'd0; v_beat_q <= 1'b0;
            dump_byte_q <= 8'h20;
        end else begin
            wr_en <= 1'b0;
            dump_div <= dump_div + 22'd1;
            ps2_strobe_q <= ps2_strobe;
            // Rising edge of USB scancode strobe → one tether note
            if (ps2_strobe && !ps2_strobe_q)
                begin k_pending <= 1'b1; k_code_q <= ps2_code; end
                // VM heartbeat: one V line per completed S/P dump, plus one on a
                // machine_fault rise (spec: V<st2><fault2><ip4>).
                dump_active_q <= dump_active;
                vfault_q <= vm_vdbg_fault;
                v_beat_q <= e_beat[25];
                if ((dump_active_q && !dump_active) || (vm_vdbg_fault && !vfault_q)
                    || (e_beat[25] && !v_beat_q)) begin
                    // 2026-08-27: third arm = free-running ~0.67s beat, so the
                    // heartbeat is alive at the console too (was dump/fault
                    // only: lively in games, silent at READY).
                    v_pending <= 1'b1;
                    v_latch   <= vm_vdbg;
                    // H-line rides the same triggers: heap gauge beside
                    // every heartbeat (obj/arr/env live counts).
                    h_pending <= 1'b1;
                    h_latch   <= vm_hdbg;
                end
                // F+T lines: once per fault edge — the full forensic
                // snapshot (alloc kind/retried, state, vsp/vcsp, pool
                // counts at fault) and the last-8 committed ips.
                fdbg_v_q <= vm_fdbg_v;
                if (vm_fdbg_v && !fdbg_v_q) begin
                    f_pending <= 1'b1;
                    f_latch   <= vm_fdbg;
                    fp_latch  <= vm_hdbg;
                    t_pending <= 1'b1;
                    t_latch   <= vm_ftrace;
                    // G-line: {fault_site16, fault_arg32} — the site that
                    // faulted and the value it refused (index / nid).
                    g_pending <= 1'b1;
                    g_latch   <= vm_gdbg;
                end
                // storage stall telemetry: after ~0.67s of CONTINUOUS busy,
                // emit the current state every ~0.17s. Catches parked AND
                // looping stalls; normal ops idle between console strobes and
                // never accumulate a second of busy.
                if (stor_state == 7'd0) d_dwell <= 27'd0;
                else if (&d_dwell) d_dwell <= 27'h4000000; // 2026-08-27: re-arm,
                // don't saturate - a long stall used to get 4 D lines
                // (0.671..1.174s) then permanent silence; now one per ~0.67s
                // for the stall's whole duration.
                else d_dwell <= d_dwell + 27'd1;
                if (stor_state != stor_q) stor_q <= stor_state;
                if (d_dwell >= 27'h4000000 && d_dwell[23:0] == 24'd0) begin
                    d_pending <= 1'b1;
                    d_code_q  <= {1'b0, stor_state};
                end
                // 2026-08-27: free-running storage-state beat (E line, ~1.34s):
                // reports the state REGARDLESS of dwell - replaces inferring
                // storage health from timeout durations. Change-triggered too
                // capped at one per 2^20 clks (~10ms) so churn can't flood TX.
                e_beat <= e_beat + 27'd1;
                if (stor_state != stor_q) e_chg <= 1'b1;
                if (e_beat == 27'd0 || (e_chg && e_beat[19:0] == 20'd0)) begin
                    e_pending <= 1'b1;
                    e_code_q  <= {1'b0, stor_state};
                    e_cons_q  <= {1'b0, cons_state};
                    e_op_q    <= stor_op_clk;
                    e_chg     <= 1'b0;
                end
            // Sample VRAM/FB one cycle ahead of HB_BYTE consume
            if (dump_game)
                dump_byte_q <= hex_digit(dump_fb_rdata[3:0]);
            else
                dump_byte_q <= (dump_data < 8'h20 || dump_data > 8'h7E) ? 8'h20 : dump_data;

            unique case (hb_state)
                HB_IDLE: begin
                    if (k_pending && !tx_busy && !dump_active) begin
                        k_pending <= 1'b0;
                        d_sel <= 2'd0;
                        hb_state <= HB_K;
                    end else if (d_pending && !tx_busy && !dump_active) begin
                        d_pending <= 1'b0;
                        d_sel <= 2'd1;
                        hb_state <= HB_K;
                    end else if (e_pending && !tx_busy && !dump_active) begin
                        e_pending <= 1'b0;
                        d_sel <= 2'd2;
                        hb_state <= HB_K;
                    end else if (v_pending && !tx_busy && !dump_active) begin
                        v_pending <= 1'b0;
                        v_nib <= 3'd7;
                        hb_state <= HB_V;
                    end else if (f_pending && !tx_busy && !dump_active) begin
                        f_pending <= 1'b0;
                        f_nib <= 4'd15;
                        hb_state <= HB_F;
                    end else if (t_pending && !tx_busy && !dump_active) begin
                        t_pending <= 1'b0;
                        t_nib <= 5'd31;
                        hb_state <= HB_T;
                    end else if (g_pending && !tx_busy && !dump_active) begin
                        g_pending <= 1'b0;
                        g_nib <= 4'd11;
                        hb_state <= HB_G;
                    end else if (h_pending && !tx_busy && !dump_active) begin
                        h_pending <= 1'b0;
                        h_nib <= 3'd7;
                        hb_state <= HB_H;
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
                    wr_data <= (d_sel == 2'd2) ? "E" : (d_sel == 2'd1) ? "D" : "K";
                    hb_state <= HB_KH;
                end
                HB_KH: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit((d_sel == 2'd2) ? {1'b0, e_code_q[6:4]}
                                       : (d_sel == 2'd1) ? {1'b0, d_code_q[6:4]}
                                       : k_code_q[7:4]);
                    hb_state <= HB_KL;
                end
                HB_KL: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit((d_sel == 2'd2) ? e_code_q[3:0]
                                       : (d_sel == 2'd1) ? d_code_q[3:0]
                                       : k_code_q[3:0]);
                    hb_state <= (d_sel == 2'd2) ? HB_E2 : HB_KNL;
                end
                // E line carries console state too: Exxyy = stor, cons
                HB_E2: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit({1'b0, e_cons_q[6:4]});
                    hb_state <= HB_E3;
                end
                HB_E3: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(e_cons_q[3:0]);
                    e_nib <= 2'd3;
                    hb_state <= HB_E4;
                end
                // run 71: Exxyyzzzz — zzzz = storage op duration (x256 clk)
                HB_E4: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(e_op_q[{e_nib, 2'b00} +: 4]);
                    if (e_nib == 2'd0) hb_state <= HB_KNL;
                    else e_nib <= e_nib - 2'd1;
                end
                HB_V: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= "V";
                    hb_state <= HB_VN;
                end
                HB_VN: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(v_latch[{v_nib, 2'b00} +: 4]);
                    if (v_nib == 3'd0) hb_state <= HB_VNL;
                    else v_nib <= v_nib - 3'd1;
                end
                HB_H: if (!tx_busy) begin
                    wr_en <= 1'b1; wr_data <= "H"; hb_state <= HB_HN;
                end
                HB_HN: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(h_latch[{h_nib, 2'b00} +: 4]);
                    if (h_nib == 3'd0) hb_state <= HB_VNL;
                    else h_nib <= h_nib - 3'd1;
                end
                HB_F: if (!tx_busy) begin
                    wr_en <= 1'b1; wr_data <= "F"; hb_state <= HB_FN;
                end
                HB_FN: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(f_nib[3]
                        ? f_latch[{f_nib[2:0], 2'b00} +: 4]
                        : fp_latch[{f_nib[2:0], 2'b00} +: 4]);
                    if (f_nib == 4'd0) hb_state <= HB_VNL;
                    else f_nib <= f_nib - 4'd1;
                end
                HB_T: if (!tx_busy) begin
                    wr_en <= 1'b1; wr_data <= "T"; hb_state <= HB_TN;
                end
                HB_G: if (!tx_busy) begin
                    wr_en <= 1'b1; wr_data <= "G"; hb_state <= HB_GN;
                end
                HB_GN: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(g_latch[{g_nib, 2'b00} +: 4]);
                    if (g_nib == 4'd0) hb_state <= HB_VNL;
                    else g_nib <= g_nib - 4'd1;
                end
                HB_TN: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= hex_digit(t_latch[{t_nib, 2'b00} +: 4]);
                    if (t_nib == 5'd0) hb_state <= HB_VNL;
                    else t_nib <= t_nib - 5'd1;
                end
                HB_VNL: if (!tx_busy) begin
                    wr_en <= 1'b1;
                    wr_data <= 8'h0A;
                    hb_state <= HB_IDLE;
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
