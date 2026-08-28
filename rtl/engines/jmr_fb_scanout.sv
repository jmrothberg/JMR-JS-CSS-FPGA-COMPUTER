// DDR3 front-image line prefetcher + 2-line ping-pong buffer.
//
// Session-1 (2026-08-23): the scanout FB moved to DDR3 (front image at
// FB_SRAM_BASE, 2 px per 16-bit word, little pixel first). This module
// keeps the NEXT beam line resident in a dual-clock 2x640 BRAM while the
// current line scans out, so the pixel side sees the same 1-beat
// registered-read contract the old BRAM bank gave jmr_text_hdmi_scanout.
//
// CDC: the beam line number crosses core-ward as gray code through 2 FFs.
// Budget: 320 words/line, held-until-ack sram reads; the arbiter gives
// this channel TOP priority, so a line lands in ~2k core cycles against a
// 32 us line period.
module jmr_fb_scanout #(
    parameter logic [20:0] FB_SRAM_BASE = 21'd1480704
) (
    // core-clock side (sram master)
    input  logic        clk,
    input  logic        rst_n,
    output logic        sram_req,
    output logic [20:0] sram_addr,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack,
    // pixel-clock side
    input  logic        pixel_clk,
    input  logic [9:0]  fb_x,
    input  logic [9:0]  fb_y,
    output logic [7:0]  fb_rdata
);
    // ---------------- 2-line ping-pong buffer (1 BRAM tile) ----------
    (* ram_style = "block" *) logic [7:0] linebuf [0:2047] /*verilator public_flat_rd*/;

    // ---------------- pixel side: registered read ---------------------
    always_ff @(posedge pixel_clk)
        fb_rdata <= linebuf[{fb_y[0], fb_x}];

    // beam line, gray-coded for the crossing
    logic [9:0] y_gray_p;
    always_ff @(posedge pixel_clk)
        y_gray_p <= fb_y ^ (fb_y >> 1);

    // ---------------- core side: prefetch next line -------------------
    logic [9:0] y_gray_m1, y_gray_m2, y_core;
    always_ff @(posedge clk) begin
        y_gray_m1 <= y_gray_p;
        y_gray_m2 <= y_gray_m1;
    end
    always_comb begin
        logic [9:0] g;
        g = y_gray_m2;
        for (int i = 8; i >= 0; i--) g[i] = g[i] ^ g[i+1];
        y_core = g;
    end
    // Registered decode: the gray prefix-XOR plus the +1/compare/x320
    // address cone was 10-11 LUT levels and set run-32's residual WNS
    // (-1.17). One register here lags the prefetch decision a single
    // 10 ns cycle behind the beam - noise against the 32 us line time.
    logic [9:0] y_core_q;
    always_ff @(posedge clk) y_core_q <= y_core;

    logic [9:0]  fetched_line;   // last line fully fetched
    logic [9:0]  tgt;            // line being fetched
    logic [9:0]  wx;             // pixel within line (steps by 2)
    logic        busy;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sram_req <= 1'b0;
            busy <= 1'b0;
            fetched_line <= 10'd1023;
            tgt <= 10'd0;
            wx <= 10'd0;
        end else if (!busy) begin
            // want the line AFTER the beam (wraps 479 -> 0)
            logic [9:0] want;
            want = (y_core_q >= 10'd479) ? 10'd0 : (y_core_q + 10'd1);
            if (want != fetched_line) begin
                busy <= 1'b1;
                tgt <= want;
                wx <= 10'd0;
                sram_req <= 1'b1;
                sram_addr <= FB_SRAM_BASE + 21'(want) * 21'd320;
            end
        end else if (sram_ack) begin
            linebuf[{tgt[0], wx}]           <= sram_rdata[7:0];
            linebuf[{tgt[0], wx | 10'd1}]   <= sram_rdata[15:8];
            if (wx == 10'd638) begin
                sram_req <= 1'b0;
                busy <= 1'b0;
                fetched_line <= tgt;
            end else begin
                wx <= wx + 10'd2;
                sram_addr <= sram_addr + 21'd1;
            end
        end
    end
endmodule
