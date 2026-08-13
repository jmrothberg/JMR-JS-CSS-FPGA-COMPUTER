// Char VRAM 64×16 + put/CLS/NL/scroll — BASIC video_engine method, local BRAM.
// LLM NOTE: Dual-port: CPU writes via put_*; scanout reads via scan_addr.
module jmr_video_vram (
    input  logic        clk,
    input  logic        rst_n,
    // Writer
    input  logic        cls,
    input  logic        put_en,
    input  logic [7:0]  put_char,
    input  logic        print_nl,
    output logic        busy,
    output logic [9:0]  cursor,
    // Scanout read port
    input  logic [9:0]  scan_addr,
    output logic [7:0]  scan_data,
    // Host dump (SCREEN?) — same BRAM read
    input  logic [9:0]  dump_addr,
    output logic [7:0]  dump_data
);
    localparam int COLS = 64;
    localparam int ROWS = 16;
    localparam int CELLS = 1024;

    (* ram_style = "block" *) logic [7:0] mem [0:CELLS-1];

    typedef enum logic [2:0] {
        V_IDLE, V_CLS, V_PUT, V_NL, V_SCROLL, V_SCROLL_CLR
    } vstate_t;
    vstate_t state;
    logic [9:0] cur, idx;

    assign cursor = cur;
    assign busy = (state != V_IDLE);
    assign scan_data = mem[scan_addr];
    assign dump_data = mem[dump_addr];

    integer i;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= V_IDLE;
            cur <= 10'd0;
            idx <= 10'd0;
            for (i = 0; i < CELLS; i = i + 1) mem[i] <= 8'h20;
        end else begin
            unique case (state)
                V_IDLE: begin
                    if (cls) begin
                        idx <= 10'd0;
                        state <= V_CLS;
                    end else if (put_en) begin
                        state <= V_PUT;
                    end else if (print_nl) begin
                        state <= V_NL;
                    end
                end
                V_CLS: begin
                    mem[idx] <= 8'h20;
                    if (idx == CELLS[9:0] - 1'b1) begin
                        cur <= 10'd0;
                        state <= V_IDLE;
                    end else idx <= idx + 1'b1;
                end
                V_PUT: begin
                    // NEW: BS/DEL — match BASIC video_engine (cursor back + erase)
                    if (put_char == 8'h08 || put_char == 8'h7F) begin
                        if (cur != 10'd0) begin
                            mem[cur - 10'd1] <= 8'h20;
                            cur <= cur - 10'd1;
                        end
                        state <= V_IDLE;
                    end else begin
                        mem[cur] <= put_char;
                        if (cur[5:0] == 6'd63) begin
                            // end of row → NL behavior
                            if (cur[9:6] == 4'd15) begin
                                idx <= 10'd0;
                                state <= V_SCROLL;
                            end else begin
                                cur <= {cur[9:6] + 1'b1, 6'd0};
                                state <= V_IDLE;
                            end
                        end else begin
                            cur <= cur + 1'b1;
                            state <= V_IDLE;
                        end
                    end
                end
                V_NL: begin
                    if (cur[9:6] == 4'd15) begin
                        idx <= 10'd0;
                        state <= V_SCROLL;
                    end else begin
                        cur <= {cur[9:6] + 1'b1, 6'd0};
                        state <= V_IDLE;
                    end
                end
                V_SCROLL: begin
                    // copy row (idx/64)+1 → idx/64 one cell at a time
                    if (idx < 10'(CELLS - COLS)) begin
                        mem[idx] <= mem[idx + 10'(COLS)];
                        idx <= idx + 1'b1;
                    end else begin
                        idx <= 10'(CELLS - COLS);
                        state <= V_SCROLL_CLR;
                    end
                end
                V_SCROLL_CLR: begin
                    mem[idx] <= 8'h20;
                    if (idx == CELLS[9:0] - 1'b1) begin
                        cur <= 10'(CELLS - COLS);
                        state <= V_IDLE;
                    end else idx <= idx + 1'b1;
                end
                default: state <= V_IDLE;
            endcase
        end
    end
endmodule
