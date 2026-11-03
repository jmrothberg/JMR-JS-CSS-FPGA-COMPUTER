// Behavioral 8 MiB external-memory window — 4M x 16.
// FPGA-SIM implementation of the jmr_sram_port: simple synchronous
// req/ack at core clock. The board swaps this for a MIG DDR3 bridge and
// custom boards for their memory controller — nothing above the port changes.
// Port contract (docs/ARCHITECTURE.md):
//   addr[21:0]  16-bit word address (4M words = 8 MiB)
//   wdata[15:0] / rdata[15:0]
//   we, req     — hold req until ack (1 cycle later); drop on ack
module jmr_sram_model (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        we,
    input  logic [21:0] addr,
    input  logic [15:0] wdata,
    output logic [15:0] rdata,
    output logic        ack
);
    // 4M x 16 — Verilator allocates this on the host; never synthesized
    // for the board (the DDR3 bridge replaces it behind the same port).
    logic [15:0] mem [0:4194303] /*verilator public_flat_rw*/;

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
