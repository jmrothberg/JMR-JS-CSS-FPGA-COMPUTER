// RECTDEMO fillRect engine — same geometry as storage/RECTDEMO.JS on mini FB.
// LLM NOTE: Hardcoded native path until full bytecode VM lands; same glass intent.
module jmr_rectdemo_engine (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    output logic        busy,
    output logic        done,
    // Mini FB write
    output logic        fb_we,
    output logic [14:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap
);
    localparam int W = 160;
    localparam int H = 120;

    typedef enum logic [3:0] {
        S_IDLE, S_CLEAR, S_RECT1, S_RECT2, S_SWAP, S_DONE
    } state_t;
    state_t state;

    logic [14:0] idx;
    logic [7:0]  rx, ry, rw, rh, color;
    logic [7:0]  x, y;

    assign busy = (state != S_IDLE && state != S_DONE);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            fb_we <= 0; fb_waddr <= 0; fb_wdata <= 0; fb_swap <= 0;
            idx <= 0; x <= 0; y <= 0;
            rx <= 0; ry <= 0; rw <= 0; rh <= 0; color <= 0;
        end else begin
            fb_we <= 0;
            fb_swap <= 0;
            done <= 0;
            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        idx <= 0;
                        state <= S_CLEAR;
                    end
                end
                S_CLEAR: begin
                    fb_we <= 1'b1;
                    fb_waddr <= idx;
                    fb_wdata <= 8'd0;
                    if (idx == 15'(W * H - 1)) begin
                        // fillRect(10,10,100,60,2) scaled 160/640 = /4 → (2,2,25,15,2)
                        rx <= 8'd2; ry <= 8'd2; rw <= 8'd25; rh <= 8'd15; color <= 8'd2;
                        x <= 8'd2; y <= 8'd2;
                        state <= S_RECT1;
                    end else idx <= idx + 1'b1;
                end
                S_RECT1, S_RECT2: begin
                    fb_we <= 1'b1;
                    fb_waddr <= 15'(y) * 15'(W) + 15'(x);
                    fb_wdata <= color;
                    if (x == rx + rw - 1'b1) begin
                        x <= rx;
                        if (y == ry + rh - 1'b1) begin
                            if (state == S_RECT1) begin
                                // fillRect(120,10,100,60,4) → (30,2,25,15,4)
                                rx <= 8'd30; ry <= 8'd2; rw <= 8'd25; rh <= 8'd15; color <= 8'd4;
                                x <= 8'd30; y <= 8'd2;
                                state <= S_RECT2;
                            end else state <= S_SWAP;
                        end else y <= y + 1'b1;
                    end else x <= x + 1'b1;
                end
                S_SWAP: begin
                    fb_swap <= 1'b1;
                    state <= S_DONE;
                end
                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
