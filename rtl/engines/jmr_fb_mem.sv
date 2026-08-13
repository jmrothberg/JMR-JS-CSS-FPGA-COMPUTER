// Framebuffer BRAM model for early SIM / tiny test patterns.
// LLM NOTE: Full 640×480×2 lives in DDR3 on the board — do NOT infer this
// entire array into LUTs for production. Sim uses this behavioral mem;
// synth builds should replace with DDR3 port (see docs/FPGA_BRINGUP.md).
module jmr_fb_mem #(
    parameter int DEPTH = 307200  // 640*480 — sim only / BRAM smoke
) (
    input  wire        clk,
    input  wire        we,
    input  wire [18:0] addr,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata
);
    (* ram_style = "block" *) reg [7:0] mem [0:DEPTH-1];
    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule
