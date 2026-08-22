// Mini canvas 640×480×8 double buffer — dual-clock (core write / pixel read).
// Native glass size. Each bank is true dual-port BRAM only:
//   Port A (wr_clk): ONE address — write-priority mux of back-buffer write
//                    and tether/sync dump read (see note below)
//   Port B (rd_clk): HDMI read
//
// 2026-08-21 fit rewrite, two changes measured from utilization_hier.rpt:
// 1. The old code read `mem[dump_raddr]` and wrote `mem[waddr]` in the same
//    wr_clk process at DIFFERENT addresses — that is a third port, and
//    Vivado silently DUPLICATED each bank's RAM (2×80 = 160 tiles/bank,
//    320 total). Port A now has a single write-priority address: on a beat
//    where the back bank is written, that bank's dump read returns the
//    write row instead (read-first). Every dump consumer (S_FB_SYNC reads
//    the FRONT bank while writing the BACK; IMGD_GET reads with fb writes
//    idle; host FB? runs with the VM paused) never needs a bank's dump
//    data on that same bank's write beat — the tether mirror is the only
//    path that can collide and it only ever shows a transient pixel.
// 2. Each bank is decomposed into EXACT power-of-two chunks
//    (256K+32K+8K+4K = 307200, zero padding). Vivado pads any BRAM to
//    2^(address width), which cost 80 tiles/bank; the exact decomposition
//    maps 64+8+2+1 = 75 tiles/bank, 150 total. Chunk selects are
//    registered beside the data so the 1-beat read contract is unchanged.
module jmr_mini_fb (
    input  logic        wr_clk,
    input  logic        rd_clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [18:0] waddr,
    input  logic [7:0]  wdata,
    input  logic        swap,
    input  logic [18:0] raddr,
    output logic [7:0]  rdata,
    // tether dump port (core clk) — shares Port A with writes
    input  logic [18:0] dump_raddr = 19'd0,
    output logic [7:0]  dump_rdata,
    // back-buffer dump (reads both banks; mux only — no 3rd port)
    output logic [7:0]  dump_back_rdata
);
    localparam int PIXELS = 640 * 480;
    // exact pow2 chunks: [0,256K) [256K,288K) [288K,296K) [296K,300K)
    localparam int C0 = 262144;
    localparam int C1 = 32768;
    localparam int C2 = 8192;
    localparam int C3 = 4096;

    (* ram_style = "block" *) logic [7:0] mem0_c0 [0:C0-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c1 [0:C1-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c2 [0:C2-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem0_c3 [0:C3-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem1_c0 [0:C0-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem1_c1 [0:C1-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem1_c2 [0:C2-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] mem1_c3 [0:C3-1] /*verilator public_flat_rd*/;

    logic front /*verilator public_flat_rd*/;

    always_ff @(posedge wr_clk) begin
        if (!rst_n) front <= 1'b0;
        else if (swap) front <= ~front;
    end

    // chunk decode (combinational; selects are REGISTERED beside the data)
    function automatic [1:0] chunk_of(input logic [18:0] a);
        if (a < 19'(C0))                 chunk_of = 2'd0;
        else if (a < 19'(C0 + C1))       chunk_of = 2'd1;
        else if (a < 19'(C0 + C1 + C2))  chunk_of = 2'd2;
        else                             chunk_of = 2'd3;
    endfunction

    // ---------------- bank 0: Port A (core clock) ----------------
    logic        b0_wr;
    logic [18:0] a0;
    assign b0_wr = we && !front;
    assign a0    = b0_wr ? waddr : dump_raddr;
    logic [7:0] d0_c0, d0_c1, d0_c2, d0_c3;
    logic [1:0] d0_sel;
    always_ff @(posedge wr_clk) begin
        if (b0_wr) begin
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
    logic [7:0] d0;
    assign d0 = (d0_sel == 2'd0) ? d0_c0 :
                (d0_sel == 2'd1) ? d0_c1 :
                (d0_sel == 2'd2) ? d0_c2 : d0_c3;

    // ---------------- bank 1: Port A (core clock) ----------------
    logic        b1_wr;
    logic [18:0] a1;
    assign b1_wr = we && front;
    assign a1    = b1_wr ? waddr : dump_raddr;
    logic [7:0] d1_c0, d1_c1, d1_c2, d1_c3;
    logic [1:0] d1_sel;
    always_ff @(posedge wr_clk) begin
        if (b1_wr) begin
            unique case (chunk_of(a1))
                2'd0: mem1_c0[a1[17:0]]              <= wdata;
                2'd1: mem1_c1[a1 - 19'(C0)]          <= wdata;
                2'd2: mem1_c2[a1 - 19'(C0 + C1)]     <= wdata;
                2'd3: mem1_c3[a1 - 19'(C0 + C1 + C2)]<= wdata;
            endcase
        end
        d1_c0 <= mem1_c0[a1[17:0]];
        d1_c1 <= mem1_c1[(a1 - 19'(C0)) & 19'(C1-1)];
        d1_c2 <= mem1_c2[(a1 - 19'(C0 + C1)) & 19'(C2-1)];
        d1_c3 <= mem1_c3[(a1 - 19'(C0 + C1 + C2)) & 19'(C3-1)];
        d1_sel <= chunk_of(a1);
    end
    logic [7:0] d1;
    assign d1 = (d1_sel == 2'd0) ? d1_c0 :
                (d1_sel == 2'd1) ? d1_c1 :
                (d1_sel == 2'd2) ? d1_c2 : d1_c3;

    // ---------------- Port B: HDMI scanout (pixel clock) ----------------
    logic [7:0] r0_c0, r0_c1, r0_c2, r0_c3, r1_c0, r1_c1, r1_c2, r1_c3;
    logic [1:0] rb_sel;
    always_ff @(posedge rd_clk) begin
        r0_c0 <= mem0_c0[raddr[17:0]];
        r0_c1 <= mem0_c1[(raddr - 19'(C0)) & 19'(C1-1)];
        r0_c2 <= mem0_c2[(raddr - 19'(C0 + C1)) & 19'(C2-1)];
        r0_c3 <= mem0_c3[(raddr - 19'(C0 + C1 + C2)) & 19'(C3-1)];
        r1_c0 <= mem1_c0[raddr[17:0]];
        r1_c1 <= mem1_c1[(raddr - 19'(C0)) & 19'(C1-1)];
        r1_c2 <= mem1_c2[(raddr - 19'(C0 + C1)) & 19'(C2-1)];
        r1_c3 <= mem1_c3[(raddr - 19'(C0 + C1 + C2)) & 19'(C3-1)];
        rb_sel <= chunk_of(raddr);
    end
    logic [7:0] r0, r1;
    assign r0 = (rb_sel == 2'd0) ? r0_c0 :
                (rb_sel == 2'd1) ? r0_c1 :
                (rb_sel == 2'd2) ? r0_c2 : r0_c3;
    assign r1 = (rb_sel == 2'd0) ? r1_c0 :
                (rb_sel == 2'd1) ? r1_c1 :
                (rb_sel == 2'd2) ? r1_c2 : r1_c3;

    assign rdata           = front ? r0 : r1;
    assign dump_rdata      = front ? d0 : d1;
    assign dump_back_rdata = front ? d1 : d0;
endmodule
