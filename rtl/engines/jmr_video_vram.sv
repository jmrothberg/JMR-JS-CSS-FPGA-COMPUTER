// Char VRAM 64×16 + put/CLS/NL/scroll — BASIC video_engine method, dual-clock BRAM.
// LLM NOTE: Port A @ clk (CPU put/scroll/dump). Port B @ scan_clk=pixel_clk (HDMI).
// Async assign scan_data=mem[scan_addr] across clocks tore glyphs on the monitor.
// SRAM/ASIC: no reset-for over mem (cannot infer BRAM; SRAM has no parallel clear).
// Dump shares Port A read with scroll — a third concurrent port forced LUTRAM.
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

    (* ram_style = "block" *) logic [7:0] mem [0:CELLS-1] /*verilator public_flat_rw*/;

    typedef enum logic [2:0] {
        // NEW: V_SCROLL_WR — scroll copy is now read-then-write (2 cycles).
        // Single-cycle mem[idx] <= mem[idx+64] was the board's worst path
        // (1024:1 read mux + write in one clock, routed WNS −0.268 ns).
        V_IDLE, V_CLS, V_PUT, V_NL, V_SCROLL, V_SCROLL_WR, V_SCROLL_CLR
    } vstate_t;
    vstate_t state;
    logic [9:0] cur, idx;
    // Port A: one write + one registered read (dump, or scroll source).
    logic       porta_we;
    logic [9:0] porta_waddr;
    logic [7:0] porta_wdata;
    logic [9:0] porta_raddr;
    logic [7:0] porta_rdata;

    assign cursor = cur;
    assign busy = (state != V_IDLE);
    assign dump_data = porta_rdata;

    // Port B @ pixel_clk — HDMI scan (BASIC memory_arbiter method)
    always_ff @(posedge scan_clk) begin
        scan_data <= mem[scan_addr];
    end

    // Port A @ core clk — 1W1R; dump_addr unless V_SCROLL is fetching the next row.
    always_comb begin
        porta_we    = 1'b0;
        porta_waddr = cur;
        porta_wdata = 8'h20;
        porta_raddr = (state == V_SCROLL) ? (idx + 10'(COLS)) : dump_addr;
        if (rst_n) begin
            unique case (state)
                V_CLS, V_SCROLL_CLR: begin
                    porta_we    = 1'b1;
                    porta_waddr = idx;
                    porta_wdata = 8'h20;
                end
                V_PUT: begin
                    if (put_char == 8'h08 || put_char == 8'h7F) begin
                        if (cur != 10'd0) begin
                            porta_we    = 1'b1;
                            porta_waddr = cur - 10'd1;
                            porta_wdata = 8'h20;
                        end
                    end else begin
                        porta_we    = 1'b1;
                        porta_waddr = cur;
                        porta_wdata = put_char;
                    end
                end
                V_SCROLL_WR: begin
                    porta_we    = 1'b1;
                    porta_waddr = idx;
                    porta_wdata = porta_rdata;
                end
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (porta_we)
            mem[porta_waddr] <= porta_wdata;
        porta_rdata <= mem[porta_raddr];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Walk-clear on release (V_CLS); SRAM cannot fill in the reset branch.
            state <= V_CLS;
            cur <= 10'd0;
            idx <= 10'd0;
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
                    if (idx == CELLS[9:0] - 1'b1) begin
                        cur <= 10'd0;
                        state <= V_IDLE;
                    end else idx <= idx + 1'b1;
                end
                V_PUT: begin
                    // NEW: BS/DEL — match BASIC video_engine (cursor back + erase)
                    if (put_char == 8'h08 || put_char == 8'h7F) begin
                        if (cur != 10'd0)
                            cur <= cur - 10'd1;
                        state <= V_IDLE;
                    end else begin
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
                    // Address is porta_raddr this cycle; porta_rdata valid next.
                    if (idx < 10'(CELLS - COLS)) begin
                        state <= V_SCROLL_WR;
                    end else begin
                        idx <= 10'(CELLS - COLS);
                        state <= V_SCROLL_CLR;
                    end
                end
                V_SCROLL_WR: begin
                    // NEW: write phase — breaks the read-mux→write timing path
                    idx <= idx + 1'b1;
                    state <= V_SCROLL;
                end
                V_SCROLL_CLR: begin
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
