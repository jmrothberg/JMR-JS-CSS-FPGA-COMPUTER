// Tiny HDMI mouse probe. Not the JS computer and not FPGA-SIM.
// Cursor, a left box, a right box, and a scroll track. Own Vivado project
// under build/mouse_probe so it cannot clobber build/nexys_video.
module top_mouse_probe (
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

    logic clock_low, data_low, sample, ready, wheel_ok;
    logic signed [11:0] dx, dy;
    logic signed [7:0] dz;
    logic [2:0] buttons;
    logic key_mode;
    assign ps2_clk = clock_low ? 1'b0 : 1'bz;
    assign ps2_data = data_low ? 1'b0 : 1'bz;
    mouse_probe_host #(.CLK_HZ(25000000)) u_mouse (
        .clk(pixel_clk), .reset(!rst_n),
        .listen_keys(key_mode),
        .clock_in(ps2_clk), .data_in(ps2_data),
        .clock_low(clock_low), .data_low(data_low),
        .sample(sample), .dx(dx), .dy(dy), .dz(dz), .buttons(buttons),
        .ready(ready), .wheel_ok(wheel_ok),
        .scan_stb(scan_stb), .scan_byte(scan_byte)
    );

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
    logic [7:0] letter;
    logic key_brk, key_ext;
    logic [19:0] letter_flash;
    logic btn_prev;
    // F10 is ignored for 3 seconds so a mouse byte cannot bounce the mode
    // while the plug is being swapped.
    logic [26:0] f10_wait;
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
            key_brk <= 0;
            key_ext <= 0;
            letter_flash <= 0;
            key_mode <= 0;
            btn_prev <= 0;
            f10_wait <= 0;
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
                    // Make and break both count: a press whose make byte
                    // looked like a mouse packet still shows on release.
                    if (!key_ext && set2_char(scan_byte) != 0) begin
                        letter <= set2_char(scan_byte);
                        letter_flash <= 20'd250000;
                        // Releases repeat the same code. Keep the line to makes.
                        if (key_mode && !key_brk) begin
                            if (ntyped == 32) typed <= {typed[247:0], set2_char(scan_byte)};
                            else typed[255 - {ntyped[4:0], 3'b000} -: 8] <= set2_char(scan_byte);
                            if (ntyped != 32) ntyped <= ntyped + 1'b1;
                        end
                    end
                    key_brk <= 0;
                    key_ext <= 0;
                    // Set-2 F10 make is 09. Break is F0 09 and must not count.
                    if (key_mode && f10_wait == 0 && !key_brk && !key_ext
                        && scan_byte == 8'h09)
                        key_mode <= 0;
                end
            end
            btn_prev <= btn[0];
            if (key_mode) begin
                if (f10_wait != 0) f10_wait <= f10_wait - 1'b1;
            end else if (btn[0] && !btn_prev && over_go) begin
                key_mode <= 1;
                f10_wait <= 27'd75000000;
                typed <= 0;
                ntyped <= 0;
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
        // Letter box. Dark until a Set-2 letter or digit comes through.
        if (box(hcnt, vcnt, 268, 372, 400, 470))
            pix = letter != 0 ? 24'h182040 : 24'h181818;
        if (letter != 0 && hcnt >= 288 && hcnt < 328 && vcnt >= 408 && vcnt < 464
            && gcol < 5 && grow < 7 && glyph5(letter, grow)[gbit])
            pix = letter_flash != 0 ? 24'hffffff : 24'hc0d0ff;
        // Mode switch. Click GO TO KEY with the mouse. F10 returns.
        // The note turns yellow once F10 is armed.
        if (box(hcnt, vcnt, 36, 160, 88, 128)) begin
            if (key_mode) pix = 24'h806000;
            else if (over_go) pix = 24'h3060a0;
            else pix = 24'h203040;
        end
        if (stamp(hcnt, vcnt, 10'd44, 10'd100, 5'd9, TXT_GO))
            pix = 24'hffffff;
        if (stamp(hcnt, vcnt, 10'd348, 10'd100, 5'd16, TXT_F10))
            pix = (key_mode && f10_wait == 0) ? 24'hffe080 : 24'hc0c0c0;
        // Typed line. Mouse packets are not letters, so this stays put
        // while the mouse moves.
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
    assign led = {ps2_data, ps2_clk, ready, wheel_flash != 0, btn[2], btn[1], btn[0], hb[24]};

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
