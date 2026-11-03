// Tiny HDMI mouse probe. Not the JS computer and not FPGA-SIM.
// Cursor, a left box, a right box, and a scroll track. Own Vivado project
// under build/mouse_probe so it cannot clobber build/nexys_video.
// PS2_MOUSE_ON_JA=0 is the proven bit: mouse on J15, keyboard on the Pmods.
// PS2_MOUSE_ON_JA=1 is the test bit: wired USB keyboard on J15, PS/2 mouse on JA.
module top_mouse_probe #(
    parameter bit PS2_MOUSE_ON_JA =
`ifdef PROBE_JA_MOUSE
        1'b1
`else
        1'b0
`endif
) (
    input  wire clk100,
    input  wire cpu_resetn,
    input  wire btnc,
    output wire hdmi_tx_clk_p,
    output wire hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    inout  wire hdmi_tx_cec,
    inout  wire hdmi_tx_rscl,
    inout  wire hdmi_tx_rsda,
    inout  wire ps2_clk,
    inout  wire ps2_data,
    // Pmod JA top row all 4 signal pins (JA1=AB22, JA2=AB21, JA3=AB20, JA4=AB18).
    // JA1 and JA3 are inout so the swapped test can host a PS/2 mouse
    // (data JA1, clock JA3). The proven build never drives them.
    inout  wire pmod_ja1,
    input  wire pmod_ja2,
    inout  wire pmod_ja3,
    input  wire pmod_ja4,
    // Pmod JC top row all 4 signal pins (JC1=Y6, JC2=AA6, JC3=AA8, JC4=AB8) — 0-ohm like JB
    input  wire pmod_jc1,
    input  wire pmod_jc2,
    input  wire pmod_jc3,
    input  wire pmod_jc4,
    // Pmod JB top row all 4 signal pins (JB1=V9, JB2=V8, JB3=V7, JB4=W7)
    input  wire pmod_jb1,
    input  wire pmod_jb2,
    input  wire pmod_jb3,
    input  wire pmod_jb4,
    output logic [7:0] led
);
    assign hdmi_tx_cec = 1'bz;
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;

    wire pixel_mmcm, pixel_clk, mmcm_locked, clkfb;
    wire mclk_unused, clk200_unused;

`ifdef SYNTHESIS
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .CLKFBOUT_MULT_F(6.0),
        .CLKOUT0_DIVIDE_F(24.0),
        .CLKOUT1_DIVIDE(50),
        .CLKOUT2_DIVIDE(3)
    ) u_mmcm (
        .CLKIN1(clk100),
        .CLKFBIN(clkfb),
        .CLKFBOUT(clkfb),
        .CLKOUT0(pixel_mmcm),
        .CLKOUT1(mclk_unused),
        .CLKOUT2(clk200_unused),
        .LOCKED(mmcm_locked),
        .PWRDWN(1'b0),
        .RST(~cpu_resetn)
    );
`else
    assign pixel_mmcm = clk100;
    assign mmcm_locked = 1'b1;
    assign mclk_unused = 0;
    assign clk200_unused = 0;
`endif
    BUFG u_pix (.I(pixel_mmcm), .O(pixel_clk));

    logic [1:0] rst_sync;
    always_ff @(posedge pixel_clk or negedge cpu_resetn) begin
        if (!cpu_resetn) rst_sync <= 2'b00;
        else rst_sync <= {rst_sync[0], mmcm_locked & ~btnc};
    end
    wire rst_n = rst_sync[1];

    logic j15_clk_low, j15_dat_low, ja_clk_low, ja_dat_low;
    logic j15_sample, ja_sample, j15_ready, ja_ready, j15_wheel, ja_wheel;
    logic signed [11:0] j15_dx, j15_dy, ja_dx, ja_dy;
    logic signed [7:0] j15_dz, ja_dz;
    logic [2:0] j15_btn, ja_btn;
    logic j15_scan_stb, j15_raw_stb;
    logic [7:0] j15_scan_byte, j15_raw_byte;
    logic sample, ready, wheel_ok;
    logic signed [11:0] dx, dy;
    logic signed [7:0] dz;
    logic [2:0] buttons;
    logic key_mode;
    assign key_mode = 1'b0;
    // J15. Proven build: mouse host drives the bus. Swapped test: listen
    // only, so a wired USB keyboard's Set-2 bytes get through. Pulling
    // this clock low inhibits the PIC24 keyboard path.
    assign ps2_clk = j15_clk_low ? 1'b0 : 1'bz;
    assign ps2_data = j15_dat_low ? 1'b0 : 1'bz;
    // JA mouse host. Driven only in the swapped test. Data = JA1, clock = JA3,
    // the same pairing the keyboard used on this Pmod.
    assign pmod_ja3 = (PS2_MOUSE_ON_JA && ja_clk_low) ? 1'b0 : 1'bz;
    assign pmod_ja1 = (PS2_MOUSE_ON_JA && ja_dat_low) ? 1'b0 : 1'bz;
    mouse_probe_host #(.CLK_HZ(25000000)) u_j15 (
        .clk(pixel_clk), .reset(!rst_n),
        .listen_keys(PS2_MOUSE_ON_JA),
        .clock_in(ps2_clk), .data_in(ps2_data),
        .clock_low(j15_clk_low), .data_low(j15_dat_low),
        .sample(j15_sample), .dx(j15_dx), .dy(j15_dy), .dz(j15_dz),
        .buttons(j15_btn), .ready(j15_ready), .wheel_ok(j15_wheel),
        .scan_stb(j15_scan_stb), .scan_byte(j15_scan_byte),
        .raw_stb(j15_raw_stb), .raw_byte(j15_raw_byte)
    );
    // Held in reset in the proven build so it cannot pull JA clock low
    // and silence a keyboard plugged in there.
    mouse_probe_host #(.CLK_HZ(25000000)) u_ja (
        .clk(pixel_clk), .reset(!rst_n || !PS2_MOUSE_ON_JA),
        .listen_keys(1'b0),
        .clock_in(pmod_ja3), .data_in(pmod_ja1),
        .clock_low(ja_clk_low), .data_low(ja_dat_low),
        .sample(ja_sample), .dx(ja_dx), .dy(ja_dy), .dz(ja_dz),
        .buttons(ja_btn), .ready(ja_ready), .wheel_ok(ja_wheel),
        .scan_stb(), .scan_byte(),
        .raw_stb(), .raw_byte()
    );
    assign sample   = PS2_MOUSE_ON_JA ? ja_sample : j15_sample;
    assign dx       = PS2_MOUSE_ON_JA ? ja_dx     : j15_dx;
    assign dy       = PS2_MOUSE_ON_JA ? ja_dy     : j15_dy;
    assign dz       = PS2_MOUSE_ON_JA ? ja_dz     : j15_dz;
    assign buttons  = PS2_MOUSE_ON_JA ? ja_btn    : j15_btn;
    assign ready    = PS2_MOUSE_ON_JA ? ja_ready  : j15_ready;
    assign wheel_ok = PS2_MOUSE_ON_JA ? ja_wheel  : j15_wheel;
    // Simultaneous PS/2 keyboard receivers on Pmod JA:
    // 1) 6-pin PmodPS2 standard: JA1=data, JA3=clk (and reversed JA3=data, JA1=clk)
    // 2) 4-pin header on pins 3..6 (next to GND/VCC): JA3+JA4 in either order
    // 3) Jumper wires on JA1+JA2 in either order
    wire [7:0] sc_13, sc_31, sc_34, sc_43, sc_12, sc_21;
    wire       st_13, st_31, st_34, st_43, st_12, st_21;
    wire       pe_13, pe_31, pe_34, pe_43, pe_12, pe_21;
    ps2_rx u_ja_13 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja3), .ps2_data(pmod_ja1), .scancode(sc_13), .strobe(st_13), .parity_err(pe_13));
    ps2_rx u_ja_31 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja1), .ps2_data(pmod_ja3), .scancode(sc_31), .strobe(st_31), .parity_err(pe_31));
    ps2_rx u_ja_34 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja4), .ps2_data(pmod_ja3), .scancode(sc_34), .strobe(st_34), .parity_err(pe_34));
    ps2_rx u_ja_43 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja3), .ps2_data(pmod_ja4), .scancode(sc_43), .strobe(st_43), .parity_err(pe_43));
    ps2_rx u_ja_12 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja2), .ps2_data(pmod_ja1), .scancode(sc_12), .strobe(st_12), .parity_err(pe_12));
    ps2_rx u_ja_21 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_ja1), .ps2_data(pmod_ja2), .scancode(sc_21), .strobe(st_21), .parity_err(pe_21));
    // In ps2_rx.sv, parity_err = ^{shift[10], shift[9:2]} which is 1 on
    // VALID odd parity! Checking !pe threw away every valid byte.
    // Match top_nexys_video.sv: gate on strobe (or pe==1 for valid odd parity).
    wire v_13 = st_13 && pe_13;
    wire v_31 = st_31 && pe_31;
    wire v_34 = st_34 && pe_34;
    wire v_43 = st_43 && pe_43;
    wire v_12 = st_12 && pe_12;
    wire v_21 = st_21 && pe_21;
    // Same all-pair receiver set on Pmod JC (0-ohm shunts like JB)
    wire [7:0] c_13, c_31, c_34, c_43, c_12, c_21;
    wire       cs_13, cs_31, cs_34, cs_43, cs_12, cs_21;
    wire       ce_13, ce_31, ce_34, ce_43, ce_12, ce_21;
    ps2_rx u_jc_13 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc3), .ps2_data(pmod_jc1), .scancode(c_13), .strobe(cs_13), .parity_err(ce_13));
    ps2_rx u_jc_31 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc1), .ps2_data(pmod_jc3), .scancode(c_31), .strobe(cs_31), .parity_err(ce_31));
    ps2_rx u_jc_34 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc4), .ps2_data(pmod_jc3), .scancode(c_34), .strobe(cs_34), .parity_err(ce_34));
    ps2_rx u_jc_43 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc3), .ps2_data(pmod_jc4), .scancode(c_43), .strobe(cs_43), .parity_err(ce_43));
    ps2_rx u_jc_12 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc2), .ps2_data(pmod_jc1), .scancode(c_12), .strobe(cs_12), .parity_err(ce_12));
    ps2_rx u_jc_21 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jc1), .ps2_data(pmod_jc2), .scancode(c_21), .strobe(cs_21), .parity_err(ce_21));
    wire vc_13 = cs_13 && ce_13;
    wire vc_31 = cs_31 && ce_31;
    wire vc_34 = cs_34 && ce_34;
    wire vc_43 = cs_43 && ce_43;
    wire vc_12 = cs_12 && ce_12;
    wire vc_21 = cs_21 && ce_21;
    // Same all-pair receiver set on Pmod JB (JB1=V9, JB2=V8, JB3=V7, JB4=W7)
    wire [7:0] b_13, b_31, b_34, b_43, b_12, b_21;
    wire       bs_13, bs_31, bs_34, bs_43, bs_12, bs_21;
    wire       be_13, be_31, be_34, be_43, be_12, be_21;
    ps2_rx u_jb_13 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb3), .ps2_data(pmod_jb1), .scancode(b_13), .strobe(bs_13), .parity_err(be_13));
    ps2_rx u_jb_31 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb1), .ps2_data(pmod_jb3), .scancode(b_31), .strobe(bs_31), .parity_err(be_31));
    ps2_rx u_jb_34 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb4), .ps2_data(pmod_jb3), .scancode(b_34), .strobe(bs_34), .parity_err(be_34));
    ps2_rx u_jb_43 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb3), .ps2_data(pmod_jb4), .scancode(b_43), .strobe(bs_43), .parity_err(be_43));
    ps2_rx u_jb_12 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb2), .ps2_data(pmod_jb1), .scancode(b_12), .strobe(bs_12), .parity_err(be_12));
    ps2_rx u_jb_21 (.clk(pixel_clk), .rst_n(rst_n), .ps2_clk(pmod_jb1), .ps2_data(pmod_jb2), .scancode(b_21), .strobe(bs_21), .parity_err(be_21));
    wire vb_13 = bs_13 && be_13;
    wire vb_31 = bs_31 && be_31;
    wire vb_34 = bs_34 && be_34;
    wire vb_43 = bs_43 && be_43;
    wire vb_12 = bs_12 && be_12;
    wire vb_21 = bs_21 && be_21;
    // Swapped test: JA is the mouse, so its bytes must not be typed as letters.
    wire pmod_scan_stb = (PS2_MOUSE_ON_JA ? 1'b0 : (v_13 | v_31 | v_34 | v_43 | v_12 | v_21))
                    | vc_13 | vc_31 | vc_34 | vc_43 | vc_12 | vc_21
                    | vb_13 | vb_31 | vb_34 | vb_43 | vb_12 | vb_21;
    wire [7:0] pmod_scan_byte = v_13 ? sc_13 : v_31 ? sc_31 : v_34 ? sc_34 : v_43 ? sc_43 : v_12 ? sc_12 : v_21 ? sc_21
                     : vc_13 ? c_13 : vc_31 ? c_31 : vc_34 ? c_34 : vc_43 ? c_43 : vc_12 ? c_12 : vc_21 ? c_21
                     : vb_13 ? b_13 : vb_31 ? b_31 : vb_34 ? b_34 : vb_43 ? b_43 : vb_12 ? b_12 : b_21;
    assign scan_stb  = PS2_MOUSE_ON_JA ? j15_scan_stb  : pmod_scan_stb;
    assign scan_byte = PS2_MOUSE_ON_JA ? j15_scan_byte : pmod_scan_byte;
    // Every valid byte on any JA pin pair, including host commands the
    // device clocks back. This is the raw window, separate from the cursor.
    wire ja_hit = v_13 | v_31 | v_34 | v_43 | v_12 | v_21;
    wire [7:0] ja_hit_byte = v_13 ? sc_13 : v_31 ? sc_31 : v_34 ? sc_34
                           : v_43 ? sc_43 : v_12 ? sc_12 : sc_21;
    logic [127:0] ja_raw, usb_raw;
    logic [15:0] ja_raw_n, usb_raw_n;
    always_ff @(posedge pixel_clk) begin
        if (!rst_n) begin
            ja_raw <= '0;
            ja_raw_n <= '0;
            usb_raw <= '0;
            usb_raw_n <= '0;
        end else begin
            if (ja_hit) begin
                ja_raw <= {ja_raw[119:0], ja_hit_byte};
                if (ja_raw_n != 16'hFFFF) ja_raw_n <= ja_raw_n + 1'b1;
            end
            if (j15_raw_stb) begin
                usb_raw <= {usb_raw[119:0], j15_raw_byte};
                if (usb_raw_n != 16'hFFFF) usb_raw_n <= usb_raw_n + 1'b1;
            end
        end
    end

    logic [9:0] px;
    logic [8:0] py;
    logic [2:0] btn;
    logic signed [12:0] wheel;
    logic wheel_id;
    logic [19:0] wheel_flash;
    logic signed [12:0] nx, ny, nw;
    logic [9:0] px_next;
    logic [8:0] py_next;
    logic signed [12:0] wheel_next;
    logic scan_stb;
    logic [7:0] scan_byte;
    logic [7:0] letter, last_make;
    logic key_brk, key_ext;
    logic [19:0] letter_flash;
    logic btn_prev;
    // F10 is ignored for 3 seconds so a mouse byte cannot bounce the mode
    // while the plug is being swapped.
    logic [26:0] f10_wait;
    // F10 counts only when byte 09 is alone. A mouse packet is a burst,
    // so a move of 9 counts must not leave keyboard mode.
    logic [16:0] since_byte;
    logic arm_f10;
    // Last 32 typed characters. First character sits at bits [255:248].
    logic [255:0] typed;
    logic [5:0] ntyped;
    wire [4:0] line2_n = ntyped[5] ? 5'd16 : (ntyped[4:0] - 5'd16);
    wire over_go = (px >= 10'd36) && (px < 10'd160)
        && (py >= 9'd88) && (py < 9'd128);
    always_comb begin
        nx = $signed({3'b0, px}) + dx;
        ny = $signed({4'b0, py}) - dy;
        if (nx < 0) px_next = 0;
        else if (nx > 639) px_next = 639;
        else px_next = nx[9:0];
        if (ny < 0) py_next = 0;
        else if (ny > 479) py_next = 479;
        else py_next = ny[8:0];
        nw = wheel - ({{5{dz[7]}}, dz} * 13'sd8);
        if (nw > 152) wheel_next = 152;
        else if (nw < -140) wheel_next = -140;
        else wheel_next = nw;
    end
    always_ff @(posedge pixel_clk) begin
        if (!rst_n) begin
            px <= 320;
            py <= 240;
            btn <= 0;
            wheel <= 0;
            wheel_id <= 0;
            wheel_flash <= 0;
            letter <= 0;
            last_make <= 0;
            key_brk <= 0;
            key_ext <= 0;
            letter_flash <= 0;
            btn_prev <= 0;
            f10_wait <= 0;
            since_byte <= 0;
            arm_f10 <= 0;
            typed <= 0;
            ntyped <= 0;
        end else begin
            wheel_id <= wheel_ok;
            if (wheel_flash != 0) wheel_flash <= wheel_flash - 1'b1;
            if (sample) begin
                btn <= buttons;
                px <= px_next;
                py <= py_next;
                wheel <= wheel_next;
                if (dz != 0) wheel_flash <= 20'd250000;
            end
            if (letter_flash != 0) letter_flash <= letter_flash - 1'b1;
            if (scan_stb) begin
                if (scan_byte == 8'hE0) key_ext <= 1;
                else if (scan_byte == 8'hF0) key_brk <= 1;
                else begin
                    // JA is a dedicated PS/2 keyboard — show every make immediately.
                    if (!key_ext && !key_brk && set2_char(scan_byte) != 0) begin
                        letter <= set2_char(scan_byte);
                        letter_flash <= 20'd250000;
                        if (ntyped == 32) typed <= {typed[247:0], set2_char(scan_byte)};
                        else typed[255 - {ntyped[4:0], 3'b000} -: 8] <= set2_char(scan_byte);
                        if (ntyped != 32) ntyped <= ntyped + 1'b1;
                    end
                    key_brk <= 0;
                    key_ext <= 0;
                end
            end
        end
    end

    localparam int H_VISIBLE = 640;
    localparam int H_FP = 16;
    localparam int H_SYNC = 96;
    localparam int H_TOTAL = 800;
    localparam int V_VISIBLE = 480;
    localparam int V_FP = 10;
    localparam int V_SYNC = 2;
    localparam int V_TOTAL = 525;

    logic [9:0] hcnt, vcnt;
    logic [23:0] vid_pData;
    logic vid_pVDE, vid_pHSync, vid_pVSync;
    logic overlay_opaque;
    logic [23:0] overlay_rgb;
    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
    jmr_mouse_overlay u_arrow (
        .x(hcnt), .y(vcnt[8:0]), .mouse_x(px), .mouse_y(py),
        .show_pointer(visible), .opaque(overlay_opaque), .rgb(overlay_rgb)
    );

    function automatic logic box(input logic [9:0] x, input logic [9:0] y,
        input int x0, input int x1, input int y0, input int y1);
        box = (x >= x0) && (x < x1) && (y >= y0) && (y < y1);
    endfunction

    // PS/2 Set-2 make code → one character. 0 means "not a letter or digit".
    function automatic logic [7:0] set2_char(input logic [7:0] sc);
        case (sc)
            8'h1C: set2_char = "A"; 8'h32: set2_char = "B"; 8'h21: set2_char = "C";
            8'h23: set2_char = "D"; 8'h24: set2_char = "E"; 8'h2B: set2_char = "F";
            8'h34: set2_char = "G"; 8'h33: set2_char = "H"; 8'h43: set2_char = "I";
            8'h3B: set2_char = "J"; 8'h42: set2_char = "K"; 8'h4B: set2_char = "L";
            8'h3A: set2_char = "M"; 8'h31: set2_char = "N"; 8'h44: set2_char = "O";
            8'h4D: set2_char = "P"; 8'h15: set2_char = "Q"; 8'h2D: set2_char = "R";
            8'h1B: set2_char = "S"; 8'h2C: set2_char = "T"; 8'h3C: set2_char = "U";
            8'h2A: set2_char = "V"; 8'h1D: set2_char = "W"; 8'h22: set2_char = "X";
            8'h35: set2_char = "Y"; 8'h1A: set2_char = "Z";
            8'h45: set2_char = "0"; 8'h16: set2_char = "1"; 8'h1E: set2_char = "2";
            8'h26: set2_char = "3"; 8'h25: set2_char = "4"; 8'h2E: set2_char = "5";
            8'h36: set2_char = "6"; 8'h3D: set2_char = "7"; 8'h3E: set2_char = "8";
            8'h46: set2_char = "9";
            default: set2_char = 8'h00;
        endcase
    endfunction

    // 5-wide rows, bit 4 on the left. Bit 34 is the top-left pixel.
    function automatic logic [4:0] glyph5(input logic [7:0] ch, input logic [2:0] row);
        logic [34:0] bits;
        case (ch)
            "A": bits = 35'b01110_10001_10001_11111_10001_10001_10001;
            "B": bits = 35'b11110_10001_10001_11110_10001_10001_11110;
            "C": bits = 35'b01110_10001_10000_10000_10000_10001_01110;
            "D": bits = 35'b11110_10001_10001_10001_10001_10001_11110;
            "E": bits = 35'b11111_10000_10000_11110_10000_10000_11111;
            "F": bits = 35'b11111_10000_10000_11110_10000_10000_10000;
            "G": bits = 35'b01110_10001_10000_10111_10001_10001_01110;
            "H": bits = 35'b10001_10001_10001_11111_10001_10001_10001;
            "I": bits = 35'b01110_00100_00100_00100_00100_00100_01110;
            "J": bits = 35'b00001_00001_00001_00001_10001_10001_01110;
            "K": bits = 35'b10001_10010_10100_11000_10100_10010_10001;
            "L": bits = 35'b10000_10000_10000_10000_10000_10000_11111;
            "M": bits = 35'b10001_11011_10101_10101_10001_10001_10001;
            "N": bits = 35'b10001_11001_10101_10011_10001_10001_10001;
            "O": bits = 35'b01110_10001_10001_10001_10001_10001_01110;
            "P": bits = 35'b11110_10001_10001_11110_10000_10000_10000;
            "Q": bits = 35'b01110_10001_10001_10001_10101_10010_01101;
            "R": bits = 35'b11110_10001_10001_11110_10100_10010_10001;
            "S": bits = 35'b01110_10001_10000_01110_00001_10001_01110;
            "T": bits = 35'b11111_00100_00100_00100_00100_00100_00100;
            "U": bits = 35'b10001_10001_10001_10001_10001_10001_01110;
            "V": bits = 35'b10001_10001_10001_10001_10001_01010_00100;
            "W": bits = 35'b10001_10001_10001_10101_10101_11011_10001;
            "X": bits = 35'b10001_10001_01010_00100_01010_10001_10001;
            "Y": bits = 35'b10001_10001_01010_00100_00100_00100_00100;
            "Z": bits = 35'b11111_00001_00010_00100_01000_10000_11111;
            "0": bits = 35'b01110_10001_10011_10101_11001_10001_01110;
            "1": bits = 35'b00100_01100_00100_00100_00100_00100_01110;
            "2": bits = 35'b01110_10001_00001_00110_01000_10000_11111;
            "3": bits = 35'b11111_00001_00010_00110_00001_10001_01110;
            "4": bits = 35'b00010_00110_01010_10010_11111_00010_00010;
            "5": bits = 35'b11111_10000_11110_00001_00001_10001_01110;
            "6": bits = 35'b00110_01000_10000_11110_10001_10001_01110;
            "7": bits = 35'b11111_00001_00010_00100_01000_01000_01000;
            "8": bits = 35'b01110_10001_10001_01110_10001_10001_01110;
            "9": bits = 35'b01110_10001_10001_01111_00001_00010_01100;
            default: bits = 35'd0;
        endcase
        if (row > 6) glyph5 = 5'd0;
        else glyph5 = bits[(3'd6 - row) * 5 +: 5];
    endfunction

    function automatic logic [7:0] hexch(input logic [3:0] nib);
        if (nib < 4'd10) hexch = 8'h30 + {4'b0, nib};
        else hexch = 8'h41 + {4'b0, nib} - 8'd10;
    endfunction

    // 16 hex digits, first nibble at bit 127, matching stamp().
    function automatic logic [127:0] hexline(input logic [63:0] bytes);
        integer i;
        hexline = '0;
        for (i = 0; i < 16; i = i + 1)
            hexline[127 - i*8 -: 8] = hexch(bytes[63 - i*4 -: 4]);
    endfunction

    // Scale-2 text. str is packed with the first character at bit 127.
    localparam logic [127:0] TXT_GO = {"GO TO KEY", 56'h0};
    localparam logic [127:0] TXT_F10 = "HIT F10 TO MOUSE";
    function automatic logic stamp(
        input logic [9:0] x, input logic [9:0] y,
        input logic [9:0] x0, input logic [9:0] y0,
        input logic [4:0] n, input logic [127:0] str);
        logic [9:0] relx, rely, xrem;
        logic [4:0] ci;
        logic [2:0] col, row;
        logic [7:0] ch;
        logic [4:0] bits;
        integer i;
        stamp = 0;
        if (x >= x0 && y >= y0) begin
            relx = x - x0;
            rely = y - y0;
            if (rely < 10'd14) begin
                ci = 0;
                xrem = relx;
                for (i = 0; i < 16; i = i + 1) begin
                    if (xrem >= 10'd12 && ci < n) begin
                        xrem = xrem - 10'd12;
                        ci = ci + 1'b1;
                    end
                end
                col = xrem[3:1];
                row = rely[3:1];
                if (ci < n && ci < 5'd16 && xrem < 10'd10 && row < 3'd7) begin
                    ch = str[8'd127 - {4'b0, ci[3:0], 3'b000} -: 8];
                    bits = glyph5(ch, row);
                    stamp = bits[3'd4 - col];
                end
            end
        end
    endfunction

    logic [23:0] pix;
    logic signed [12:0] mark;
    // Glyph origin is a multiple of 8 so the column is a bit slice.
    wire [9:0] glyph_x = hcnt - 10'd288;
    wire [9:0] glyph_y = vcnt - 10'd408;
    wire [2:0] gcol = glyph_x[5:3];
    wire [2:0] grow = glyph_y[5:3];
    wire [2:0] gbit = (gcol < 5) ? (3'd4 - gcol) : 3'd0;
    always_comb begin
        pix = 24'h202020;
        mark = 240 - wheel;
        if (hcnt < 2 || hcnt >= 638 || vcnt < 2 || vcnt >= 478)
            pix = 24'h404040;
        // On-glass label so this bit is not confused with the JA-mouse test.
        if (PS2_MOUSE_ON_JA && stamp(hcnt, vcnt, 10'd440, 10'd8, 5'd8, {"JA MOUSE", 64'h0}))
            pix = 24'hffffff;
        if (!PS2_MOUSE_ON_JA && stamp(hcnt, vcnt, 10'd428, 10'd8, 5'd9, {"USB MOUSE", 56'h0}))
            pix = 24'hffffff;
        // Left window: raw bytes on JA (the PS/2 keyboard in this bit).
        // Right window: raw bytes from the USB mouse host on J15.
        // Cursor, buttons, wheel, and the typed line are the decoded output.
        if (box(hcnt, vcnt, 8, 212, 76, 136))
            pix = 24'h101018;
        if (stamp(hcnt, vcnt, 10'd14, 10'd80, 5'd11,
                {"JA RAW ", hexch(ja_raw_n[15:12]), hexch(ja_raw_n[11:8]),
                 hexch(ja_raw_n[7:4]), hexch(ja_raw_n[3:0]), 40'h0}))
            pix = 24'hffffff;
        if (ja_raw_n != 0 && stamp(hcnt, vcnt, 10'd14, 10'd96, 5'd16, hexline(ja_raw[127:64])))
            pix = 24'h80ff80;
        if (ja_raw_n != 0 && stamp(hcnt, vcnt, 10'd14, 10'd112, 5'd16, hexline(ja_raw[63:0])))
            pix = 24'hc0ffc0;
        if (box(hcnt, vcnt, 420, 632, 76, 136))
            pix = 24'h101018;
        if (stamp(hcnt, vcnt, 10'd426, 10'd80, 5'd12,
                {"USB RAW ", hexch(usb_raw_n[15:12]), hexch(usb_raw_n[11:8]),
                 hexch(usb_raw_n[7:4]), hexch(usb_raw_n[3:0]), 32'h0}))
            pix = 24'hffffff;
        if (usb_raw_n != 0 && stamp(hcnt, vcnt, 10'd426, 10'd96, 5'd16, hexline(usb_raw[127:64])))
            pix = 24'h80ff80;
        if (usb_raw_n != 0 && stamp(hcnt, vcnt, 10'd426, 10'd112, 5'd16, hexline(usb_raw[63:0])))
            pix = 24'hc0ffc0;
        // Left and right click targets.
        if (box(hcnt, vcnt, 48, 280, 160, 360)) begin
            if (btn[0] && box(px, {1'b0, py}, 48, 280, 160, 360)) pix = 24'h20e060;
            else pix = 24'h103018;
        end
        if (box(hcnt, vcnt, 360, 592, 160, 360)) begin
            if (btn[1] && box(px, {1'b0, py}, 360, 592, 160, 360)) pix = 24'he04040;
            else pix = 24'h301010;
        end
        // Button lamps stay lit while the button is down, on or off a box.
        if (box(hcnt, vcnt, 48, 96, 36, 72))
            pix = btn[0] ? 24'h20e060 : 24'h103018;
        if (box(hcnt, vcnt, 544, 592, 36, 72))
            pix = btn[1] ? 24'he04040 : 24'h301010;
        if (box(hcnt, vcnt, 300, 340, 36, 72))
            pix = btn[2] ? 24'he0e040 : 24'h303010;
        // Scroll track. The marker moves 8 pixels per wheel notch.
        if (box(hcnt, vcnt, 304, 336, 88, 392))
            pix = wheel_id ? 24'h303030 : 24'h401818;
        if (vcnt == 240 && hcnt >= 304 && hcnt < 336)
            pix = 24'h808080;
        if (wheel_id && hcnt >= 306 && hcnt < 334
            && $signed({3'b0, vcnt}) >= mark && $signed({3'b0, vcnt}) < mark + 12)
            pix = wheel_flash != 0 ? 24'hffffff : 24'hc0c0c0;
        // Three pips when the mouse answered ID 03 (wheel). One pip otherwise.
        if (box(hcnt, vcnt, 250, 262, 48, 60))
            pix = wheel_id ? 24'hffffff : 24'h804040;
        if (wheel_id && box(hcnt, vcnt, 266, 278, 48, 60))
            pix = 24'hffffff;
        if (wheel_id && box(hcnt, vcnt, 282, 294, 48, 60))
            pix = 24'hffffff;
        // Letter box. Dark until a Set-2 letter or digit comes through on JA.
        if (box(hcnt, vcnt, 268, 372, 400, 470))
            pix = letter != 0 ? 24'h182040 : 24'h181818;
        if (letter != 0 && hcnt >= 288 && hcnt < 328 && vcnt >= 408 && vcnt < 464
            && gcol < 5 && grow < 7 && glyph5(letter, grow)[gbit])
            pix = letter_flash != 0 ? 24'hffffff : 24'hc0d0ff;
        // Typed line from JA PS/2 keyboard (no mode switching).
        if (ntyped != 0 && stamp(hcnt, vcnt, 10'd36, 10'd362,
                ntyped > 16 ? 5'd16 : ntyped[4:0], typed[255:128]))
            pix = 24'hffffff;
        if (ntyped > 16 && stamp(hcnt, vcnt, 10'd36, 10'd378,
                line2_n, typed[127:0]))
            pix = 24'hffffff;
    end

    always_ff @(posedge pixel_clk) begin
        if (!rst_n) begin
            hcnt <= 0;
            vcnt <= 0;
            vid_pData <= 0;
            vid_pVDE <= 0;
            vid_pHSync <= 0;
            vid_pVSync <= 0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL - 1) vcnt <= 0;
                else vcnt <= vcnt + 1'b1;
            end else hcnt <= hcnt + 1'b1;
            vid_pHSync <= (hcnt >= H_VISIBLE + H_FP) && (hcnt < H_VISIBLE + H_FP + H_SYNC);
            vid_pVSync <= (vcnt >= V_VISIBLE + V_FP) && (vcnt < V_VISIBLE + V_FP + V_SYNC);
            vid_pVDE <= visible;
            if (visible && overlay_opaque) vid_pData <= overlay_rgb;
            else vid_pData <= pix;
        end
    end

    logic [24:0] hb;
    always_ff @(posedge pixel_clk) begin
        if (!rst_n) hb <= 0;
        else hb <= hb + 1'b1;
    end
    // LD0 heartbeat, LD1 left, LD2 right, LD3 middle, LD4 wheel notch,
    // LD5 stream ready, LD6 clock, LD7 data.
    // LD6/LD7 follow whichever bus the mouse host is driving.
    wire led_clk = PS2_MOUSE_ON_JA ? pmod_ja3 : ps2_clk;
    wire led_dat = PS2_MOUSE_ON_JA ? pmod_ja1 : ps2_data;
    assign led = {led_dat, led_clk, ready, wheel_flash != 0, btn[2], btn[1], btn[0], hb[24]};

    jmr_rgb2dvi_wrap u_tmds (
        .TMDS_Clk_p(hdmi_tx_clk_p),
        .TMDS_Clk_n(hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_p),
        .TMDS_Data_n(hdmi_tx_n),
        .aRst(~rst_n),
        .vid_pData({vid_pData[23:16], vid_pData[7:0], vid_pData[15:8]}),
        .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync),
        .vid_pVSync(vid_pVSync),
        .PixelClk(pixel_clk)
    );
endmodule
