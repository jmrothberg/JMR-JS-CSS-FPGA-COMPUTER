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
    input  logic        dirty_clear,
    output logic [1199:0] dirty_blocks,
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
    // Every chunk starts on its own power-of-two boundary. Use the same
    // bank-local address net for Port A reads and writes, so each bank has
    // exactly one address per port. Invalid writes must not wrap into bank 3.
    wire [17:0] a_c0 = a0[17:0];
    wire [14:0] a_c1 = a0[14:0];
    wire [12:0] a_c2 = a0[12:0];
    wire [11:0] a_c3 = a0[11:0];
    wire [17:0] b_c0 = copy_raddr[17:0];
    wire [14:0] b_c1 = copy_raddr[14:0];
    wire [12:0] b_c2 = copy_raddr[12:0];
    wire [11:0] b_c3 = copy_raddr[11:0];
    logic [7:0] d0_c0, d0_c1, d0_c2, d0_c3;
    logic [1:0] d0_sel;
    always_ff @(posedge wr_clk) begin
        if (we && a0 < 19'd307200) begin
            unique case (chunk_of(a0))
                2'd0: mem0_c0[a_c0] <= wdata;
                2'd1: mem0_c1[a_c1] <= wdata;
                2'd2: mem0_c2[a_c2] <= wdata;
                2'd3: mem0_c3[a_c3] <= wdata;
            endcase
        end
        d0_c0 <= mem0_c0[a_c0];
        d0_c1 <= mem0_c1[a_c1];
        d0_c2 <= mem0_c2[a_c2];
        d0_c3 <= mem0_c3[a_c3];
        d0_sel <= chunk_of(a0);
    end
    assign dump_rdata = (d0_sel == 2'd0) ? d0_c0 :
                        (d0_sel == 2'd1) ? d0_c1 :
                        (d0_sel == 2'd2) ? d0_c2 : d0_c3;

    // Read-first Port A already returns the old byte of a draw write.
    // Pipeline the selected old byte, comparison and 256-byte block mark,
    // updating only when contents changed. No additional framebuffer port or
    // image copy is introduced. The first present always transfers all.
    logic dirty_we_q;
    logic [18:0] dirty_addr_q;
    logic [7:0] dirty_data_q;
    logic [7:0] dirty_old_q, dirty_new_q;
    logic dirty_compare_q;
    logic [10:0] dirty_compare_block_q;
    logic dirty_changed_q;
    logic [10:0] dirty_block_q;
    always_ff @(posedge wr_clk) begin
        if (!rst_n) begin
            dirty_blocks <= '1;
            dirty_we_q <= 1'b0;
            dirty_changed_q <= 1'b0;
            dirty_compare_q <= 1'b0;
        end else begin
            dirty_we_q <= we;
            dirty_addr_q <= waddr;
            dirty_data_q <= wdata;
            // Keep bank selection, byte comparison and block decoding in
            // separate stages, each with an ordinary 100 MHz requirement.
            dirty_old_q <= dump_rdata;
            dirty_new_q <= dirty_data_q;
            dirty_compare_q <= dirty_we_q && dirty_addr_q < 19'd307200;
            dirty_compare_block_q <= dirty_addr_q[18:8];
            dirty_changed_q <= dirty_compare_q && dirty_old_q != dirty_new_q;
            dirty_block_q <= dirty_compare_block_q;
            if (dirty_clear) dirty_blocks <= '0;
            if (dirty_changed_q) dirty_blocks[dirty_block_q] <= 1'b1;
        end
    end

    // ---------------- Port B: present-copy read (core clk) ----------------
    logic [7:0] c_c0, c_c1, c_c2, c_c3;
    logic [1:0] c_sel;
    always_ff @(posedge wr_clk) begin
        c_c0 <= mem0_c0[b_c0];
        c_c1 <= mem0_c1[b_c1];
        c_c2 <= mem0_c2[b_c2];
        c_c3 <= mem0_c3[b_c3];
        c_sel <= chunk_of(copy_raddr);
    end
    assign copy_rdata = (c_sel == 2'd0) ? c_c0 :
                        (c_sel == 2'd1) ? c_c1 :
                        (c_sel == 2'd2) ? c_c2 : c_c3;
endmodule
