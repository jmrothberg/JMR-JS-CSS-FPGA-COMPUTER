// BRAM-style palette: 256 × 24-bit RGB (inferred BRAM on FPGA).
// LLM NOTE: Keep palette in BRAM — do not unpack into LUT flops.
module jmr_palette_bram (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  waddr,
    input  wire [23:0] wdata,
    input  wire [7:0]  raddr,
    output reg  [23:0] rdata
);
    (* ram_style = "block" *) reg [23:0] mem [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 24'h000000;
        mem[0] = 24'h000000;
        mem[1] = 24'hffffff;
        mem[2] = 24'hff0000;
        mem[3] = 24'h00ff00;
        mem[4] = 24'h0000ff;
    end
    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
        rdata <= mem[raddr];
    end
endmodule
