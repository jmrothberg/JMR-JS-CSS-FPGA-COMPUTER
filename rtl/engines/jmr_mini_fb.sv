// Mini canvas 160×120×8 double buffer — dual-clock (core write / pixel read).
module jmr_mini_fb (
    input  logic        wr_clk,
    input  logic        rd_clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [14:0] waddr,
    input  logic [7:0]  wdata,
    input  logic        swap,
    input  logic [14:0] raddr,
    output logic [7:0]  rdata,
    // NEW: core-clk dump port for PROG tether mirror (HDMI uses raddr/rd_clk)
    input  logic [14:0] dump_raddr = 15'd0,
    output logic [7:0]  dump_rdata
);
    localparam int PIXELS = 160 * 120;
    (* ram_style = "block" *) logic [7:0] mem0 [0:PIXELS-1];
    (* ram_style = "block" *) logic [7:0] mem1 [0:PIXELS-1];
    logic front;

    always_ff @(posedge wr_clk) begin
        if (!rst_n) front <= 1'b0;
        else begin
            if (swap) front <= ~front;
            if (we) begin
                if (front) mem1[waddr] <= wdata;
                else mem0[waddr] <= wdata;
            end
        end
    end

    always_ff @(posedge rd_clk) begin
        rdata <= front ? mem0[raddr] : mem1[raddr];
    end

    // NEW: same front buffer, wr_clk — tether FB rows without fighting HDMI
    always_ff @(posedge wr_clk) begin
        dump_rdata <= front ? mem0[dump_raddr] : mem1[dump_raddr];
    end
endmodule
