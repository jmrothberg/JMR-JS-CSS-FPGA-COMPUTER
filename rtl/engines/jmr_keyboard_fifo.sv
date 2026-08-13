// Keyboard FIFO — fixed depth. NEW: no a-z fold (JS needs full keyboard;
// BASIC folded for Model I; verbs are matched case-insensitively in console).
// NEW: DEPTH 128 — fits one monitor line (127) + CR; 16 overflowed during
// EDIT echo when the glass scrolled (long replace never reached edit_pending).
module jmr_keyboard_fifo #(
    parameter int DEPTH = 128
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       push,
    input  logic [7:0] push_data,
    input  logic       pop,
    input  logic       clear,
    output logic [7:0] data,
    output logic       empty,
    output logic       full
);
    localparam int AW = $clog2(DEPTH);
    logic [7:0] mem [0:DEPTH-1];
    logic [AW-1:0] rd_ptr, wr_ptr;
    logic [AW:0]   count;

    assign empty = (count == 0);
    assign full  = (count == DEPTH[AW:0]);
    assign data  = mem[rd_ptr];

    always_ff @(posedge clk) begin
        if (!rst_n || clear) begin
            rd_ptr <= '0;
            wr_ptr <= '0;
            count  <= '0;
        end else begin
            unique case ({push && !full, pop && !empty})
                2'b10: begin
                    mem[wr_ptr] <= push_data;
                    wr_ptr <= wr_ptr + 1'b1;
                    count  <= count + 1'b1;
                end
                2'b01: begin
                    rd_ptr <= rd_ptr + 1'b1;
                    count  <= count - 1'b1;
                end
                2'b11: begin
                    mem[wr_ptr] <= push_data;
                    wr_ptr <= wr_ptr + 1'b1;
                    rd_ptr <= rd_ptr + 1'b1;
                end
                default: ;
            endcase
        end
    end
endmodule
