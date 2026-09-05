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
    // run 71: the remaining cone (compare + increment + x320 DSP + 21-bit
    // base add, 10-11 levels) set run 71's WNS (-0.448) and thinned runs
    // 50/52/70b. Split it: stage 1 = the wanted line, stage 2 = its SRAM
    // base. want_qq rides beside line_base_q so the two are always from
    // the same beam sample. Prefetch now lags the beam 3 cycles (30 ns)
    // against a 32 us line - still noise.
    logic [9:0]  want_q, want_qq;
    logic [20:0] line_base_q;
    always_ff @(posedge clk) begin
        want_q      <= (y_core_q >= 10'd479) ? 10'd0 : (y_core_q + 10'd1);
        want_qq     <= want_q;
        line_base_q <= FB_SRAM_BASE + 21'(want_q) * 21'd320;
    end

    logic [9:0]  fetched_line;   // last line fully fetched
    logic [9:0]  tgt;            // line being fetched
    logic [9:0]  wx;             // pixel within line (steps by 2)
    logic        busy;
    logic        wr_hi;          // staggered high-byte write pending
    logic [7:0]  hi_byte;
    logic [10:0] hi_addr;
    always_ff @(posedge clk) begin
        /* SINGLE write statement (vstack 1W recipe, run 58 census):
           the ack arm wrote BOTH bytes of the sram word in one cycle —
           two write ports made ram_style="block" infeasible, and this
           2048-deep buffer fell back to 16,496 FFs + ~10.6k LUTs of
           read muxes instead of ONE BRAM tile. The high byte now lands
           the cycle after the ack: bridge acks are >=2 cycles apart
           (req && !ack handshake), so the stagger can never collide
           with the next ack's low byte. wr_hi priority is belt-and-
           suspenders for that impossible case. */
        logic        lb_we;
        logic [10:0] lb_wa;
        logic [7:0]  lb_wd;
        lb_we = rst_n && (wr_hi || (busy && sram_ack));
        lb_wa = wr_hi ? hi_addr : {tgt[0], wx};
        lb_wd = wr_hi ? hi_byte : sram_rdata[7:0];
        if (lb_we) linebuf[lb_wa] <= lb_wd;
`ifndef SYNTHESIS
        // the stagger's one assumption, checked on every sim cycle:
        if (wr_hi && busy && sram_ack)
            $error("fbscan: ack collided with staggered high-byte write");
`endif
        wr_hi   <= rst_n && busy && sram_ack;
        hi_addr <= {tgt[0], wx | 10'd1};
        hi_byte <= sram_rdata[15:8];
        if (!rst_n) begin
            sram_req <= 1'b0;
            busy <= 1'b0;
            fetched_line <= 10'd1023;
            tgt <= 10'd0;
            wx <= 10'd0;
        end else if (!busy) begin
            // want the line AFTER the beam (wraps 479 -> 0); both values
            // come pre-computed from the two-stage pipe above
            if (want_qq != fetched_line) begin
                busy <= 1'b1;
                tgt <= want_qq;
                wx <= 10'd0;
                sram_req <= 1'b1;
                sram_addr <= line_base_q;
            end
        end else if (sram_ack) begin
            // byte writes handled by the single-port stanza above
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
