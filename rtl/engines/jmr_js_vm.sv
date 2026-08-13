// JMR-JS stack VM — single-port BRAM code fetch (board timing safe).
// ISA: functional_model/bytecode.py + jsb_format.py
module jmr_js_vm #(
    parameter string CODE_HEX = "invaders_jsb.hex"
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic        stop,
    input  logic        frame_tick,
    input  logic [5:0]  joy_in,
    output logic        busy,
    output logic        done,
    output logic        fb_we,
    output logic [14:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap
);
    localparam int CODE_WORDS = 1024;
    localparam int MAX_CONSTS = 256;
    localparam int MAX_VARS   = 64;
    localparam int STACK_DEPTH = 64;
    localparam int MW = 160;
    localparam int MH = 120;

    localparam logic [7:0] OP_LOAD_CONST = 8'd1;
    localparam logic [7:0] OP_LOAD_VAR   = 8'd2;
    localparam logic [7:0] OP_STORE_VAR  = 8'd3;
    localparam logic [7:0] OP_ADD        = 8'd4;
    localparam logic [7:0] OP_SUB        = 8'd5;
    localparam logic [7:0] OP_MUL        = 8'd6;
    localparam logic [7:0] OP_DIV        = 8'd7;
    localparam logic [7:0] OP_LT         = 8'd8;
    localparam logic [7:0] OP_GT         = 8'd9;
    localparam logic [7:0] OP_EQ         = 8'd10;
    localparam logic [7:0] OP_JUMP       = 8'd11;
    localparam logic [7:0] OP_JIF        = 8'd12;
    localparam logic [7:0] OP_CALL       = 8'd13;
    localparam logic [7:0] OP_RETURN     = 8'd14;
    localparam logic [7:0] OP_POP        = 8'd15;
    localparam logic [7:0] OP_DUP        = 8'd16;
    localparam logic [7:0] OP_NEG        = 8'd17;
    localparam logic [7:0] OP_NOT        = 8'd18;
    localparam logic [7:0] OP_LET_VAR    = 8'd22;

    (* ram_style = "block" *) logic [31:0] code_mem [0:CODE_WORDS-1];
    initial $readmemh(CODE_HEX, code_mem);
    logic [9:0]  code_raddr;
    logic [31:0] code_rdata;
    always_ff @(posedge clk) code_rdata <= code_mem[code_raddr];

    logic signed [31:0] consts [0:MAX_CONSTS-1];
    logic signed [31:0] vars   [0:MAX_VARS-1];
    logic               var_init [0:MAX_VARS-1];
    logic signed [31:0] stack  [0:STACK_DEPTH-1];
    logic [5:0]  sp;
    logic [15:0] ip;
    logic [15:0] n_ops, n_consts, ops_base;
    logic        looping, running;

    typedef enum logic [4:0] {
        S_IDLE,
        S_RD,          // generic: wait 1 cycle after code_raddr change
        S_GOT_MAGIC,
        S_GOT_HDR1,
        S_GOT_HDR2,
        S_LD_CONST,
        S_FETCH_WAIT,
        S_EXEC,
        S_NAT, S_CLEAR, S_RECT, S_WAIT_FRAME, S_DONE,
        // NEW: multi-cycle divide — single-cycle 32-bit '/' was the −90 ns WNS
        // critical path on the board (337 logic levels / 300 CARRY4).
        S_DIV, S_DIV_FIN,
        // NEW: 2-cycle multiply — stack-read → DSP → stack-write in one clock
        // still missed timing by ~3 ns; register operands first
        S_MUL
    } st_t;
    st_t state, ret_state;

    logic [15:0] c_i;
    logic [7:0]  rx, ry, rw, rh, color, x, y;
    logic [14:0] clr_idx;
    logic [7:0]  nat_id, nat_argc;
    logic signed [31:0] a_s, b_s;

    // NEW: registered multiply operands (2-cycle OP_MUL — board timing)
    logic signed [31:0] mul_a, mul_b;

    // NEW: restoring-divider state (32 cycles @ core clk; result matches the
    // old single-cycle signed '/' — truncate toward zero, div-by-0 → 0)
    logic [31:0] div_uq;   // shifting dividend, becomes |quotient|
    logic [31:0] div_ub;   // |divisor|
    logic [31:0] div_rem;  // partial remainder
    logic [5:0]  div_cnt;
    logic        div_neg;  // result sign
    logic [32:0] div_rnext;
    assign div_rnext = {div_rem, div_uq[31]};

    assign busy = running;
    assign done = (state == S_DONE);

    function automatic logic [7:0] sat8(input logic signed [31:0] v);
        if (v < 0) sat8 = 8'd0;
        else if (v > 255) sat8 = 8'd255;
        else sat8 = 8'(v);
    endfunction
    function automatic logic [7:0] scale4(input logic signed [31:0] v);
        scale4 = sat8(v >>> 2);
    endfunction

    task automatic next_op;
        ip <= ip + 16'd1;
        code_raddr <= 10'(ops_base + ip + 16'd1);
        state <= S_FETCH_WAIT;
    endtask

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            running <= 1'b0;
            looping <= 1'b0;
            fb_we <= 1'b0; fb_swap <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0;
            sp <= '0; ip <= '0;
            n_ops <= '0; n_consts <= '0; ops_base <= '0;
            code_raddr <= '0;
            nat_id <= '0; nat_argc <= '0;
            c_i <= '0;
        end else begin
            fb_we <= 1'b0;
            fb_swap <= 1'b0;
            if (stop) begin
                running <= 1'b0;
                looping <= 1'b0;
                state <= S_IDLE;
            end else unique case (state)
                S_IDLE: if (start) begin
                    running <= 1'b1;
                    looping <= 1'b0;
                    sp <= '0;
                    code_raddr <= 10'd0;
                    state <= S_RD;
                    ret_state <= S_GOT_MAGIC;
                end
                S_RD: state <= ret_state;

                S_GOT_MAGIC: begin
                    if (code_rdata != 32'h3142534A) begin
                        running <= 1'b0;
                        state <= S_DONE;
                    end else begin
                        code_raddr <= 10'd1;
                        state <= S_RD;
                        ret_state <= S_GOT_HDR1;
                    end
                end
                S_GOT_HDR1: begin
                    n_ops    <= code_rdata[15:0];
                    n_consts <= code_rdata[31:16];
                    code_raddr <= 10'd2;
                    state <= S_RD;
                    ret_state <= S_GOT_HDR2;
                end
                S_GOT_HDR2: begin
                    ops_base <= 16'd3 + n_consts;
                    for (int i = 0; i < MAX_VARS; i++) var_init[i] <= 1'b0;
                    if (n_consts == 16'd0) begin
                        ip <= '0;
                        code_raddr <= 10'd3;
                        state <= S_FETCH_WAIT;
                    end else begin
                        c_i <= '0;
                        code_raddr <= 10'd3;
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end
                S_LD_CONST: begin
                    consts[c_i[7:0]] <= $signed(code_rdata);
                    if (c_i + 16'd1 >= n_consts) begin
                        ip <= '0;
                        code_raddr <= 10'(16'd3 + n_consts);
                        state <= S_FETCH_WAIT;
                    end else begin
                        c_i <= c_i + 16'd1;
                        code_raddr <= 10'(16'd3 + c_i + 16'd1);
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end

                S_FETCH_WAIT: state <= S_EXEC;

                S_EXEC: begin
                    if (ip >= n_ops) begin
                        if (looping) state <= S_WAIT_FRAME;
                        else begin running <= 1'b0; state <= S_DONE; end
                    end else begin
                        unique case (code_rdata[7:0])
                            OP_LOAD_CONST: begin
                                stack[sp] <= consts[code_rdata[15:8]];
                                sp <= sp + 6'd1;
                                next_op();
                            end
                            OP_LOAD_VAR: begin
                                stack[sp] <= vars[code_rdata[13:8]];
                                sp <= sp + 6'd1;
                                next_op();
                            end
                            OP_STORE_VAR: begin
                                vars[code_rdata[13:8]] <= stack[sp - 6'd1];
                                var_init[code_rdata[13:8]] <= 1'b1;
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_LET_VAR: begin
                                if (!var_init[code_rdata[13:8]]) begin
                                    vars[code_rdata[13:8]] <= stack[sp - 6'd1];
                                    var_init[code_rdata[13:8]] <= 1'b1;
                                end
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_ADD: begin
                                stack[sp - 6'd2] <= stack[sp - 6'd2] + stack[sp - 6'd1];
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_SUB: begin
                                stack[sp - 6'd2] <= stack[sp - 6'd2] - stack[sp - 6'd1];
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_MUL: begin
                                // NEW: register operands, multiply next cycle (timing)
                                mul_a <= stack[sp - 6'd2];
                                mul_b <= stack[sp - 6'd1];
                                state <= S_MUL;
                            end
                            OP_DIV: begin
                                // NEW: multi-cycle divide (see S_DIV) — the old
                                // single-cycle '/' blew board timing (WNS −90 ns)
                                if (stack[sp - 6'd1] == 0) begin
                                    stack[sp - 6'd2] <= 32'sd0;
                                    sp <= sp - 6'd1;
                                    next_op();
                                end else begin
                                    div_neg <= stack[sp - 6'd2][31] ^ stack[sp - 6'd1][31];
                                    div_uq  <= stack[sp - 6'd2][31]
                                               ? 32'(-stack[sp - 6'd2]) : 32'(stack[sp - 6'd2]);
                                    div_ub  <= stack[sp - 6'd1][31]
                                               ? 32'(-stack[sp - 6'd1]) : 32'(stack[sp - 6'd1]);
                                    div_rem <= '0;
                                    div_cnt <= '0;
                                    state <= S_DIV;
                                end
                            end
                            OP_LT: begin
                                stack[sp - 6'd2] <=
                                    (stack[sp - 6'd2] < stack[sp - 6'd1]) ? 32'sd1 : 32'sd0;
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_GT: begin
                                stack[sp - 6'd2] <=
                                    (stack[sp - 6'd2] > stack[sp - 6'd1]) ? 32'sd1 : 32'sd0;
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_EQ: begin
                                stack[sp - 6'd2] <=
                                    (stack[sp - 6'd2] == stack[sp - 6'd1]) ? 32'sd1 : 32'sd0;
                                sp <= sp - 6'd1;
                                next_op();
                            end
                            OP_JUMP: begin
                                ip <= code_rdata[23:8];
                                code_raddr <= 10'(ops_base + code_rdata[23:8]);
                                state <= S_FETCH_WAIT;
                            end
                            OP_JIF: begin
                                a_s = stack[sp - 6'd1];
                                sp <= sp - 6'd1;
                                if (a_s == 0) begin
                                    ip <= code_rdata[23:8];
                                    code_raddr <= 10'(ops_base + code_rdata[23:8]);
                                end else begin
                                    ip <= ip + 16'd1;
                                    code_raddr <= 10'(ops_base + ip + 16'd1);
                                end
                                state <= S_FETCH_WAIT;
                            end
                            OP_CALL: begin
                                nat_id <= code_rdata[15:8];
                                nat_argc <= code_rdata[31:24];
                                ip <= ip + 16'd1;
                                state <= S_NAT;
                            end
                            OP_RETURN: begin
                                if (looping) state <= S_WAIT_FRAME;
                                else begin running <= 1'b0; state <= S_DONE; end
                            end
                            OP_POP: begin sp <= sp - 6'd1; next_op(); end
                            OP_DUP: begin
                                stack[sp] <= stack[sp - 6'd1];
                                sp <= sp + 6'd1;
                                next_op();
                            end
                            OP_NEG: begin
                                stack[sp - 6'd1] <= -stack[sp - 6'd1];
                                next_op();
                            end
                            OP_NOT: begin
                                stack[sp - 6'd1] <=
                                    (stack[sp - 6'd1] == 0) ? 32'sd1 : 32'sd0;
                                next_op();
                            end
                            default: next_op();
                        endcase
                    end
                end

                S_NAT: begin
                    unique case (nat_id)
                        8'd0: begin
                            sp <= sp - nat_argc[5:0];
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd1: begin
                            if (nat_argc >= 8'd1) begin
                                color <= sat8(stack[sp - 6'd1]);
                                sp <= sp - 6'd1;
                            end else color <= 8'd0;
                            clr_idx <= '0;
                            state <= S_CLEAR;
                        end
                        8'd2: begin
                            color <= sat8(stack[sp - 6'd1]);
                            rh <= scale4(stack[sp - 6'd2]);
                            rw <= scale4(stack[sp - 6'd3]);
                            ry <= scale4(stack[sp - 6'd4]);
                            rx <= scale4(stack[sp - 6'd5]);
                            x  <= scale4(stack[sp - 6'd5]);
                            y  <= scale4(stack[sp - 6'd4]);
                            sp <= sp - 6'd5;
                            state <= S_RECT;
                        end
                        8'd3: begin
                            fb_swap <= 1'b1;
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd4: begin
                            stack[sp] <= joy_in[0] ? 32'sd1 : 32'sd0;
                            sp <= sp + 6'd1;
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd5: begin
                            stack[sp] <= joy_in[1] ? 32'sd1 : 32'sd0;
                            sp <= sp + 6'd1;
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd6: begin
                            stack[sp] <= joy_in[4] ? 32'sd1 : 32'sd0;
                            sp <= sp + 6'd1;
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd7: begin
                            looping <= 1'b1;
                            state <= S_WAIT_FRAME;
                        end
                        default: begin
                            code_raddr <= 10'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    endcase
                end
                S_CLEAR: begin
                    fb_we <= 1'b1;
                    fb_waddr <= clr_idx;
                    fb_wdata <= color;
                    if (clr_idx == 15'(MW * MH - 1)) begin
                        code_raddr <= 10'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else clr_idx <= clr_idx + 15'd1;
                end
                S_RECT: begin
                    if (rw == 8'd0 || rh == 8'd0) begin
                        code_raddr <= 10'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        fb_we <= 1'b1;
                        fb_waddr <= 15'(y) * 15'(MW) + 15'(x);
                        fb_wdata <= color;
                        if (x == (rx + rw - 8'd1)) begin
                            x <= rx;
                            if (y == (ry + rh - 8'd1)) begin
                                code_raddr <= 10'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else y <= y + 8'd1;
                        end else x <= x + 8'd1;
                    end
                end
                // NEW: 2nd multiply cycle — DSP path from registered operands
                S_MUL: begin
                    stack[sp - 6'd2] <= mul_a * mul_b;
                    sp <= sp - 6'd1;
                    next_op();
                end
                // NEW: one restoring-division step per clock (32 total)
                S_DIV: begin
                    if (div_rnext >= {1'b0, div_ub}) begin
                        div_rem <= 32'(div_rnext - {1'b0, div_ub});
                        div_uq  <= {div_uq[30:0], 1'b1};
                    end else begin
                        div_rem <= div_rnext[31:0];
                        div_uq  <= {div_uq[30:0], 1'b0};
                    end
                    if (div_cnt == 6'd31) state <= S_DIV_FIN;
                    else div_cnt <= div_cnt + 6'd1;
                end
                S_DIV_FIN: begin
                    stack[sp - 6'd2] <= div_neg ? -$signed(div_uq) : $signed(div_uq);
                    sp <= sp - 6'd1;
                    next_op();
                end
                S_WAIT_FRAME: if (frame_tick) begin
                    ip <= '0;
                    sp <= '0;
                    code_raddr <= 10'(ops_base);
                    state <= S_FETCH_WAIT;
                end
                S_DONE: begin
                    running <= 1'b0;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
