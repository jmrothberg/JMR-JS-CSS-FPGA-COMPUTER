// Mini canvas 640×480×8 — SINGLE persistent draw bank (BRAM) + DDR3 front.
//
// 2026-08-23 Session-1 rewrite (NEVER-table row consciously relaxed, user):
// JS canvas is a persistent surface; the old two-bank ping-pong emulated it
// with fb_swap + a 307k-cycle S_FB_SYNC copy-back after every present. Now
// the draw bank never flips: present = stream this bank into the DDR3 front
// image (jmr_fb_present in jmr_js_core), scanout = DDR3 line prefetch
// (jmr_fb_scanout). One bank = 75 BRAM tiles (was 150); S_FB_SYNC is gone.
//
//   Port A (wr_clk): ONE address — write-priority mux of draw writes and
//                    dump/tether reads (unchanged discipline: dump data is
//                    registered one beat behind dump_raddr).
//   Port B (wr_clk): present-copy read — sequential, core clock. The old
//                    pixel-clock scanout port moved to jmr_fb_scanout.
module jmr_mini_fb (
    input  logic        wr_clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [18:0] waddr,
    input  logic [7:0]  wdata,
    // present-copy read port (core clk, sequential)
    input  logic [18:0] copy_raddr,
    output logic [7:0]  copy_rdata,
    // tether/IMGD dump port (core clk) — shares Port A with writes
    input  logic [18:0] dump_raddr,
    output logic [7:0]  dump_rdata
);
    // exact pow2 chunks: [0,256K) [256K,288K) [288K,296K) [296K,300K)
    localparam int C0 = 262144;
    localparam int C1 = 32768;
    localparam int C2 = 8192;
    localparam int C3 = 4096;

    (* ram_style = "block" *) logic [7:0] mem0_c0 [0:C0-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c1 [0:C1-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c2 [0:C2-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c3 [0:C3-1] /*verilator public_flat_rd*/;

    function automatic [1:0] chunk_of(input logic [18:0] a);
        if (a < 19'(C0))                 chunk_of = 2'd0;
        else if (a < 19'(C0 + C1))       chunk_of = 2'd1;
        else if (a < 19'(C0 + C1 + C2))  chunk_of = 2'd2;
        else                             chunk_of = 2'd3;
    endfunction

    // ---------------- Port A: draw writes + dump reads ----------------
    logic [18:0] a0;
    assign a0 = we ? waddr : dump_raddr;
    logic [7:0] d0_c0, d0_c1, d0_c2, d0_c3;
    logic [1:0] d0_sel;
    always_ff @(posedge wr_clk) begin
        if (we) begin
            unique case (chunk_of(a0))
                2'd0: mem0_c0[a0[17:0]]              <= wdata;
                2'd1: mem0_c1[a0 - 19'(C0)]          <= wdata;
                2'd2: mem0_c2[a0 - 19'(C0 + C1)]     <= wdata;
                2'd3: mem0_c3[a0 - 19'(C0 + C1 + C2)]<= wdata;
            endcase
        end
        d0_c0 <= mem0_c0[a0[17:0]];
        d0_c1 <= mem0_c1[(a0 - 19'(C0)) & 19'(C1-1)];
        d0_c2 <= mem0_c2[(a0 - 19'(C0 + C1)) & 19'(C2-1)];
        d0_c3 <= mem0_c3[(a0 - 19'(C0 + C1 + C2)) & 19'(C3-1)];
        d0_sel <= chunk_of(a0);
    end
    assign dump_rdata = (d0_sel == 2'd0) ? d0_c0 :
                        (d0_sel == 2'd1) ? d0_c1 :
                        (d0_sel == 2'd2) ? d0_c2 : d0_c3;

    // ---------------- Port B: present-copy read (core clk) ----------------
    logic [7:0] c_c0, c_c1, c_c2, c_c3;
    logic [1:0] c_sel;
    always_ff @(posedge wr_clk) begin
        c_c0 <= mem0_c0[copy_raddr[17:0]];
        c_c1 <= mem0_c1[(copy_raddr - 19'(C0)) & 19'(C1-1)];
        c_c2 <= mem0_c2[(copy_raddr - 19'(C0 + C1)) & 19'(C2-1)];
        c_c3 <= mem0_c3[(copy_raddr - 19'(C0 + C1 + C2)) & 19'(C3-1)];
        c_sel <= chunk_of(copy_raddr);
    end
    assign copy_rdata = (c_sel == 2'd0) ? c_c0 :
                        (c_sel == 2'd1) ? c_c1 :
                        (c_sel == 2'd2) ? c_c2 : c_c3;
endmodule
