// Mini canvas 640×480×8 double buffer — dual-clock (core write / pixel read).
// NEW: native glass size. Each bank is true dual-port BRAM only:
//   Port A (wr_clk): write back-buffer + tether dump read
//   Port B (rd_clk): HDMI read
// A third concurrent access forced LUTRAM and over-utilized the T200.
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
    output logic [7:0]  dump_rdata
);
    localparam int PIXELS = 640 * 480;
    (* ram_style = "block" *) logic [7:0] mem0 [0:PIXELS-1];
    (* ram_style = "block" *) logic [7:0] mem1 [0:PIXELS-1];
    logic front;
    logic [7:0] r0, r1, d0, d1;

    always_ff @(posedge wr_clk) begin
        if (!rst_n) front <= 1'b0;
        else if (swap) front <= ~front;
    end

    // Port A mem0: write when back is mem0; always dump-read
    always_ff @(posedge wr_clk) begin
        if (we && !front)
            mem0[waddr] <= wdata;
        d0 <= mem0[dump_raddr];
    end
    // Port A mem1
    always_ff @(posedge wr_clk) begin
        if (we && front)
            mem1[waddr] <= wdata;
        d1 <= mem1[dump_raddr];
    end

    // Port B: HDMI scanout (always read both, mux — keeps BRAM dual-port clean)
    always_ff @(posedge rd_clk) begin
        r0 <= mem0[raddr];
        r1 <= mem1[raddr];
    end

    assign rdata      = front ? r0 : r1;
    assign dump_rdata = front ? d0 : d1;
endmodule
