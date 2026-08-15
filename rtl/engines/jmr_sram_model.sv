// Behavioral 4 MB asset SRAM — 2M x 16 (IS61WV204816 contract).
// FPGA-SIM implementation of the jmr_sram_port: simple synchronous
// req/ack at core clock. The board swaps this for a MIG DDR3 bridge and
// the ASIC for the real chip — nothing above the port changes.
// Port contract (docs/ARCHITECTURE.md):
//   addr[20:0]  16-bit word address (2M words = 4 MB)
//   wdata[15:0] / rdata[15:0]
//   we, req     — hold req until ack (1 cycle later); drop on ack
module jmr_sram_model (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        we,
    input  logic [20:0] addr,
    input  logic [15:0] wdata,
    output logic [15:0] rdata,
    output logic        ack
);
    // 2M x 16 — Verilator allocates this on the host; never synthesized
    // for the board (the DDR3 bridge replaces it behind the same port).
    logic [15:0] mem [0:2097151] /*verilator public_flat_rw*/;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ack   <= 1'b0;
            rdata <= 16'h0;
        end else begin
            ack <= 1'b0;
            if (req && !ack) begin
                if (we) mem[addr] <= wdata;
                rdata <= mem[addr];
                ack <= 1'b1;
            end
        end
    end
endmodule
