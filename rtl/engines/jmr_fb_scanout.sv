// Draw-bank line prefetcher + 2-line ping-pong buffer.
//
// Run 52 (2026-08-28): scanout reads the PERSISTENT DRAW BANK directly
// (jmr_mini_fb Port B, freed by deleting jmr_fb_present) instead of a
// DDR3 front image. The whole present pipeline is gone: no S_FB_SYNC
// wait (768,008 core clk per frame in every presenting title, measured),
// no DDR3 front region, two fewer SRAM arbiter clients — and scanout
// can never starve on the DDR3 bridge again (the run-32/33 black-screen
// class is structurally deleted). Cost, accepted by the user: single-
// buffer tearing, small now that draws run at ~1 px/clk in the raster
// engine.
//
// This module keeps the NEXT beam line resident in a dual-clock 2x640
// BRAM while the current line scans out, so the pixel side sees the
// same 1-beat registered-read contract as before. Fetch: streaming
// 1 px/clk through Port B's registered read (~641 clk per line against
// a 32 us line period).
//
// CDC: the beam line number crosses core-ward as gray code through 2
// FFs — unchanged.
module jmr_fb_scanout (
    // core-clock side (draw-bank Port B master)
    input  logic        clk,
    input  logic        rst_n,
    output logic [18:0] copy_raddr,
    input  logic [7:0]  copy_rdata,
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
    // Registered decode (run-32 lesson): keep the gray prefix-XOR +
    // compare cone off the address path.
    logic [9:0] y_core_q;
    always_ff @(posedge clk) y_core_q <= y_core;

    logic [9:0]  fetched_line;   // last line fully fetched
    logic [9:0]  tgt;            // line being fetched
    logic [9:0]  wx;             // Port B address cursor
    logic [9:0]  wxo;            // write-back cursor (rdata lags 1 beat)
    logic        busy, primed;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            primed <= 1'b0;
            fetched_line <= 10'd1023;
            tgt <= 10'd0;
            wx <= 10'd0;
            wxo <= 10'd0;
            copy_raddr <= 19'd0;
        end else if (!busy) begin
            // want the line AFTER the beam (wraps 479 -> 0)
            logic [9:0] want;
            want = (y_core_q >= 10'd479) ? 10'd0 : (y_core_q + 10'd1);
            if (want != fetched_line) begin
                busy <= 1'b1;
                primed <= 1'b0;
                tgt <= want;
                wx <= 10'd0;
                wxo <= 10'd0;
                copy_raddr <= 19'(want) * 19'd640;
            end
        end else begin
            // streaming: advance the address every clk; rdata lags one
            // beat, so the write-back cursor trails the address cursor.
            if (wx != 10'd639) begin
                wx <= wx + 10'd1;
                copy_raddr <= copy_raddr + 19'd1;
            end
            if (!primed) primed <= 1'b1;
            else begin
                linebuf[{tgt[0], wxo}] <= copy_rdata;
                if (wxo == 10'd639) begin
                    busy <= 1'b0;
                    fetched_line <= tgt;
                end else wxo <= wxo + 10'd1;
            end
        end
    end
endmodule
