// Char VRAM 64×16 + put/CLS/NL/scroll — BASIC video_engine method, dual-clock BRAM.
// LLM NOTE: Port A @ clk (CPU put/scroll/dump). Port B @ scan_clk=pixel_clk (HDMI).
// Async assign scan_data=mem[scan_addr] across clocks tore glyphs on the monitor.
module jmr_video_vram (
    input  logic        clk,
    input  logic        scan_clk,  // NEW: pixel_clk — true dual-port like BASIC VRAM
    input  logic        rst_n,
    // Writer
    input  logic        cls,
    input  logic        put_en,
    input  logic [7:0]  put_char,
    input  logic        print_nl,
    output logic        busy,
    output logic [9:0]  cursor,
    // Scanout read port (pixel clock)
    input  logic [9:0]  scan_addr,
    output logic [7:0]  scan_data,
    // Host dump (SCREEN?) — core clock
    input  logic [9:0]  dump_addr,
    output logic [7:0]  dump_data
);
    localparam int COLS = 64;
    localparam int ROWS = 16;
    localparam int CELLS = 1024;

    (* ram_style = "block" *) logic [7:0] mem [0:CELLS-1];

    typedef enum logic [2:0] {
        // NEW: V_SCROLL_WR — scroll copy is now read-then-write (2 cycles).
        // Single-cycle mem[idx] <= mem[idx+64] was the board's worst path
        // (1024:1 read mux + write in one clock, routed WNS −0.268 ns).
        V_IDLE, V_CLS, V_PUT, V_NL, V_SCROLL, V_SCROLL_WR, V_SCROLL_CLR
    } vstate_t;
    vstate_t state;
    logic [9:0] cur, idx;
    logic [7:0] scroll_byte; // NEW: registered read for the 2-cycle scroll copy

    assign cursor = cur;
    assign busy = (state != V_IDLE);

    // Port B @ pixel_clk — HDMI scan (BASIC memory_arbiter method)
    always_ff @(posedge scan_clk) begin
        scan_data <= mem[scan_addr];
    end

    // Dump @ core clk (tether S-rows)
    always_ff @(posedge clk) begin
        dump_data <= mem[dump_addr];
    end

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
                    // copy row (idx/64)+1 → idx/64, read phase (see V_SCROLL_WR)
                    if (idx < 10'(CELLS - COLS)) begin
                        scroll_byte <= mem[idx + 10'(COLS)];
                        state <= V_SCROLL_WR;
                    end else begin
                        idx <= 10'(CELLS - COLS);
                        state <= V_SCROLL_CLR;
                    end
                end
                V_SCROLL_WR: begin
                    // NEW: write phase — breaks the read-mux→write timing path
                    mem[idx] <= scroll_byte;
                    idx <= idx + 1'b1;
                    state <= V_SCROLL;
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
