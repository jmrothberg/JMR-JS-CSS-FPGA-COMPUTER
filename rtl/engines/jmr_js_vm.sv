// JMR-JS stack VM — BRAM code (writable from FAT .JSB) + 640×480 game FB.
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
    // NEW: console loads NAME.JSB into code BRAM before start
    input  logic        code_we,
    input  logic [14:0] code_waddr,
    input  logic [31:0] code_wdata,
    output logic        busy,
    output logic        done,
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap
);
    localparam int CODE_WORDS = 32768;
    localparam int MAX_CONSTS = 1024;
    localparam int MAX_VARS   = 512;
    localparam int STACK_DEPTH = 512; // PACMAN maze literals ~320 deep
    // NEW: native 640×480 FB (matches PYTHON glass; no scale4)
    localparam int MW = 640;
    localparam int MH = 480;
    localparam int FB_PIXELS = MW * MH;

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
    localparam logic [7:0] OP_MAKE_ARR   = 8'd19;
    localparam logic [7:0] OP_ARR_GET    = 8'd20;
    localparam logic [7:0] OP_ARR_SET    = 8'd21;
    localparam logic [7:0] OP_LET_VAR    = 8'd22;
    localparam logic [7:0] OP_MOD        = 8'd23;
    localparam logic [7:0] OP_CALL_USER  = 8'd24;
    localparam logic [7:0] OP_RET_VAL    = 8'd25;
    localparam logic [7:0] OP_MAKE_OBJ   = 8'd26;
    localparam logic [7:0] OP_GET_PROP   = 8'd27;
    localparam logic [7:0] OP_SET_PROP   = 8'd28;
    localparam logic [7:0] OP_NEW_OBJ    = 8'd29;
    localparam logic [7:0] OP_CALL_METH  = 8'd30;
    localparam logic [7:0] OP_BIT_OR     = 8'd31;
    localparam logic [7:0] OP_BIT_AND    = 8'd32;
    localparam logic [7:0] OP_MAKE_FN    = 8'd33;
    localparam logic [7:0] OP_CALL_VAL   = 8'd34;

    (* ram_style = "block" *) logic [31:0] code_mem [0:CODE_WORDS-1];
    initial $readmemh(CODE_HEX, code_mem);
    logic [14:0] code_raddr;
    logic [31:0] code_rdata;
    // Read port (VM fetch) + write port (FAT .JSB load) — dual-port BRAM
    always_ff @(posedge clk) begin
        code_rdata <= code_mem[code_raddr];
        if (code_we)
            code_mem[code_waddr] <= code_wdata;
    end

    logic signed [31:0] consts [0:MAX_CONSTS-1];
    logic signed [31:0] vars   [0:MAX_VARS-1];
    logic               var_init [0:MAX_VARS-1];
    logic signed [31:0] stack  [0:STACK_DEPTH-1];
    logic [8:0]  sp;
    logic [15:0] ip;
    logic [15:0] n_ops, n_consts, ops_base, jsb_flags;
    logic        looping, running;
    // NEW: tagged stack/vars for HTML heap (0=int 1=obj 2=arr 3=str 4=fn 5=undef 6=elem)
    logic [2:0]  stack_tag [0:STACK_DEPTH-1];
    logic [2:0]  var_tag   [0:MAX_VARS-1];
    localparam int MAX_OBJ = 2048; // bunkers + grid + per-frame {velocity} literals
    localparam int OBJ_SLOTS = 32; // PACMAN Item.assign copies ~20 settings onto this
    localparam int MAX_ARR = 256;
    localparam int ARR_CAP = 128;
    localparam int MAX_CLS = 16;
    localparam int MAX_CMETH = 16;
    localparam int CSTK = 128;
    logic [15:0] n_obj, n_arr;
    logic [5:0]  obj_n    [0:MAX_OBJ-1];
    logic [15:0] obj_key  [0:MAX_OBJ-1][0:OBJ_SLOTS-1];
    logic [31:0] obj_val  [0:MAX_OBJ-1][0:OBJ_SLOTS-1];
    logic [2:0]  obj_tag  [0:MAX_OBJ-1][0:OBJ_SLOTS-1];
    logic [15:0] obj_cls  [0:MAX_OBJ-1];
    logic [7:0]  arr_len  [0:MAX_ARR-1];
    logic [31:0] arr_val  [0:MAX_ARR-1][0:ARR_CAP-1];
    logic [2:0]  arr_tag  [0:MAX_ARR-1][0:ARR_CAP-1];
    logic [15:0] cls_name [0:MAX_CLS-1];
    logic [15:0] cls_ctor [0:MAX_CLS-1];
    logic [4:0]  cls_nmeth[0:MAX_CLS-1];
    logic [15:0] cls_mname[0:MAX_CLS-1][0:MAX_CMETH-1];
    logic [15:0] cls_mip  [0:MAX_CLS-1][0:MAX_CMETH-1];
    logic [4:0]  n_cls;
    logic [15:0] cstack_ip [0:CSTK-1];
    logic [15:0] cstack_this [0:CSTK-1];
    logic        cstack_isctor [0:CSTK-1];
    logic        cstack_isfe [0:CSTK-1]; // NEW: forEach frame under callback
    logic [15:0] cstack_ctorobj [0:CSTK-1];
    logic [15:0] cstack_fe_arr [0:CSTK-1];
    logic [15:0] cstack_fe_fn [0:CSTK-1];
    logic [7:0]  cstack_fe_i [0:CSTK-1];
    logic [6:0]  csp;
    logic [15:0] this_obj;
    logic [8:0]  var_this;   // NEW: LOAD_VAR slot for __this
    logic        this_ok;
    logic [15:0] raf_fn [0:7];
    logic [3:0]  raf_n;
    logic [15:0] kd_fn, ku_fn, click_fn; // interned MAKE_FN entries; 0xFFFF=none
    logic        click_fired; // NEW: HTML auto-start click once
    logic        pre_click_raf; // NEW: one rAF (Image.onload) before click
    logic [5:0]  prev_joy;
    logic [7:0]  fill_style_i;
    logic [31:0] lfsr;
    logic [15:0] id_fillrect, id_length, id_push, id_splice, id_foreach;
    logic [15:0] id_getctx, id_click, id_ael, id_key, id_keycode;
    logic [15:0] id_arrow_l, id_arrow_r, id_space, id_a, id_d, id_keydown, id_keyup;
    logic [15:0] id_reduce, id_draw, id_update, id_fillstyle, id_clearrect, id_drawimage;
    logic [15:0] id_this_name, id_black, id_white, id_red, id_yellow, id_cyan, id_gold;
    logic [15:0] id_src, id_onload, id_width, id_height;
    logic [15:0] id_hex_fff, id_hex_3f6, id_hex_f5a, id_hex_fc0, id_hex_2ec, id_hex_000;
    logic [15:0] id_save, id_restore, id_translate, id_rotate;
    logic [15:0] id_assign, id_bind, id_proto, id_filltext, id_arc, id_enter;
    logic [15:0] id_now, id_gettime;
    logic [15:0] id_beginpath, id_fill, id_stroke, id_moveto, id_lineto, id_closepath, id_strokestyle;
    logic [15:0] id_hex_09f, id_hex_f5f5, id_hex_ffe6, id_hex_f00, id_hex_aaa;
    logic [15:0] spr_nid [0:7]; // intern idx of "jmr:spr:0"..7
    logic [1:0]  path_kind; // 0 none 1 arc 2 moveto 3 lineto
    logic signed [31:0] path_x0, path_y0, path_x1, path_y1, path_r;
    logic        path_stroke;
    localparam int SPR_BYTES = 262144;
    localparam int MAX_SPR = 8;
    (* ram_style = "block" *) logic [7:0] spr_mem [0:SPR_BYTES-1];
    logic [17:0] spr_off [0:MAX_SPR-1];
    logic [9:0]  spr_ww [0:MAX_SPR-1];
    logic [9:0]  spr_hh [0:MAX_SPR-1];
    logic [3:0]  n_spr, spr_i;
    logic [2:0]  spr_hdr;
    logic [17:0] spr_wp, spr_left;
    logic [7:0]  blit_si;
    logic [9:0]  blit_sx, blit_sy, blit_sw, blit_sh;
    logic [31:0] time_ms; // PACMAN Date.now / getTime — must advance or start() skips draw
    localparam int MAX_FN_PROTO = 64;
    logic [15:0] fn_proto_ip [0:MAX_FN_PROTO-1];
    logic [15:0] fn_proto_oid [0:MAX_FN_PROTO-1];
    logic [6:0]  n_fn_proto;
    logic [8:0]  intern_var [0:1023];
    logic        intern_var_ok [0:1023];
    logic [2:0]  enter_n;
    logic [3:0]  enter_delay;
    logic [15:0] id_keys_name, id_pressed, id_kspace; // keys.a.pressed table
    logic [8:0]  var_keys;
    logic        keys_ok;
    logic [15:0] keys_a_oid, keys_d_oid, keys_sp_oid;
    // NEW: canvas 2d translate so Player.drawImage(-w/2,-h/2) lands on position
    logic signed [31:0] ctx_tx, ctx_ty, saved_tx, saved_ty;
    // NEW: JSB v2 trailer walk (byte offset into code_mem)
    logic [18:0] trail_off; // PACMAN .JSH trailer sits past 64K byte
    logic [15:0] trail_n, trail_i, name_len_r, nhash, name_idx, trail_acc;
    logic [4:0]  trail_ph;
    logic [7:0]  trail_cls_i, trail_meth_i, trail_nmeth;
    logic [8:0]  trail_var_slot;
    logic [7:0]  trail_tb; // NEW: combo byte from code_rdata (do not declare inside always_ff)
    logic [15:0] trail_guard; // NEW: force FETCH if walker never hits phase 22

    typedef enum logic [5:0] {
        S_IDLE,
        S_RD,          // generic: wait 1 cycle after code_raddr change
        S_GOT_MAGIC,
        S_GOT_HDR1,
        S_GOT_HDR2,
        S_LD_CONST,
        S_TRAIL,       // NEW: JSB v2 name/class trailer
        S_FETCH_WAIT,
        S_EXEC,
        S_NAT, S_CLEAR, S_RECT, S_CIRCLE, S_LINE, S_BLIT, S_SPR, S_WAIT_FRAME, S_DONE,
        // NEW: multi-cycle divide — single-cycle 32-bit '/' was the −90 ns WNS
        // critical path on the board (337 logic levels / 300 CARRY4).
        S_DIV, S_DIV_FIN,
        // NEW: 3-cycle multiply — latch ops → DSP into mul_prod → stack write.
        // Prior "2-cycle" still did mul_a*mul_b into stack same clock (WNS −0.183).
        S_MUL, S_MUL_WR,
        // NEW: binop/compare/neg — compute alu_r then write stack (sp→ALU→stack was −0.6 ns)
        S_ALU, S_ALU_WR,
        S_CALL, S_FOREACH, S_KEYEV
    } st_t;
    st_t state, ret_state;

    logic [15:0] c_i;
    // NEW: 10-bit coords for 640×480 (was 8-bit mini after scale4)
    logic [9:0]  rx, ry, rw, rh, x, y;
    logic [7:0]  color;
    logic [18:0] clr_idx;
    logic [7:0]  nat_id, nat_argc;
    logic signed [31:0] a_s, b_s;

    // NEW: registered multiply operands + product (break DSP→stack path)
    logic signed [31:0] mul_a, mul_b, mul_prod;

    // NEW: ALU pipeline for ADD/SUB/LT/GT/EQ/NEG/NOT
    logic signed [31:0] alu_a, alu_b, alu_r;
    logic [2:0] alu_op;  // 0 ADD 1 SUB 2 LT 3 GT 4 EQ 5 NEG 6 NOT

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
    // NEW: clip fillRect args to FB (no wrap — was the sparse BOARD bug)
    function automatic logic [9:0] clip_u(input logic signed [31:0] v, input int unsigned lim);
        if (v < 0) clip_u = 10'd0;
        else if (v >= lim) clip_u = 10'(lim - 1);
        else clip_u = 10'(v);
    endfunction
    function automatic logic [9:0] clip_sz(
        input logic signed [31:0] v,
        input logic [9:0] origin,
        input int unsigned lim
    );
        logic signed [31:0] room;
        room = lim - 32'(origin);
        if (v <= 0) clip_sz = 10'd0;
        else if (v > room) clip_sz = 10'(room);
        else clip_sz = 10'(v);
    endfunction
    // NEW: JSB v2 float consts are IEEE bits; use as i32 (0.12→0, 5.0→5). Raw bits made width/x garbage so Left never moved.
    function automatic logic signed [31:0] f32_to_i(input logic [31:0] bits);
        logic [7:0] exp;
        logic [23:0] mant;
        logic signed [31:0] mag;
        exp = bits[30:23];
        mant = {1'b1, bits[22:0]};
        if (exp == 8'd0 || exp < 8'd127)
            mag = 32'sd0;
        else if (exp >= 8'd151)
            mag = 32'sd2147483647;
        else
            mag = $signed({8'd0, mant} >> (8'd150 - exp));
        f32_to_i = bits[31] ? -mag : mag;
    endfunction

    task automatic next_op;
        ip <= ip + 16'd1;
        code_raddr <= 15'(ops_base + ip + 16'd1);
        state <= S_FETCH_WAIT;
    endtask
    // NEW: consume one trailer byte; word wrap → S_RD (must not run on intern/done)
    task automatic trail_bump;
        if (trail_off[1:0] == 2'd3) begin
            code_raddr <= 15'(trail_off[16:2] + 15'd1);
            trail_off <= trail_off + 16'd1;
            state <= S_RD;
            ret_state <= S_TRAIL;
        end         else trail_off <= trail_off + 16'd1;
    endtask
    // NEW: KEYBITS OR into HTML keys.*.pressed (plan: debug OR, no WASD map in handlers)
    task automatic poke_pressed(input logic [15:0] child_ni, input logic down);
        logic [10:0] koid, child;
        logic found;
        koid = vars[var_keys][10:0];
        child = 11'd0;
        for (int s = 0; s < OBJ_SLOTS; s++)
            if (s < obj_n[koid] && obj_key[koid][s] == child_ni)
                child = obj_val[koid][s][10:0];
        found = 1'b0;
        for (int s = 0; s < OBJ_SLOTS; s++) begin
            if (s < obj_n[child] && obj_key[child][s] == id_pressed) begin
                obj_val[child][s] <= down ? 32'sd1 : 32'sd0;
                obj_tag[child][s] <= 3'd0;
                found = 1'b1;
            end
        end
    endtask
    always_comb begin
        case (trail_off[1:0])
            2'd0: trail_tb = code_rdata[7:0];
            2'd1: trail_tb = code_rdata[15:8];
            2'd2: trail_tb = code_rdata[23:16];
            default: trail_tb = code_rdata[31:24];
        endcase
    end

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
                    code_raddr <= 15'd0;
                    state <= S_RD;
                    ret_state <= S_GOT_MAGIC;
                end
                S_RD: state <= ret_state;

                S_GOT_MAGIC: begin
                    if (code_rdata != 32'h3142534A) begin
                        running <= 1'b0;
                        state <= S_DONE;
                    end else begin
                        code_raddr <= 15'd1;
                        state <= S_RD;
                        ret_state <= S_GOT_HDR1;
                    end
                end
                S_GOT_HDR1: begin
                    n_ops    <= code_rdata[15:0];
                    n_consts <= code_rdata[31:16];
                    code_raddr <= 15'd2;
                    state <= S_RD;
                    ret_state <= S_GOT_HDR2;
                end
                S_GOT_HDR2: begin
                    ops_base <= 16'd3 + n_consts;
                    jsb_flags <= code_rdata[31:16];
                    for (int i = 0; i < MAX_VARS; i++) var_init[i] <= 1'b0;
                    n_obj <= 0; n_arr <= 0; n_cls <= 0; csp <= 0; raf_n <= 0;
                    kd_fn <= 16'hFFFF; ku_fn <= 16'hFFFF; click_fn <= 16'hFFFF;
                    click_fired <= 1'b0;
                    pre_click_raf <= 1'b0;
                    fill_style_i <= 8'd1; lfsr <= 32'hACE1; this_obj <= 0;
                    var_this <= 9'd0; this_ok <= 1'b0; id_this_name <= 16'hFFFF;
                    var_keys <= 9'd0; keys_ok <= 1'b0;
                    keys_a_oid <= 16'hFFFF; keys_d_oid <= 16'hFFFF; keys_sp_oid <= 16'hFFFF;
                    id_keys_name <= 16'hFFFF; id_pressed <= 16'hFFFF; id_kspace <= 16'hFFFF;
                    id_fillrect <= 16'hFFFF; id_length <= 16'hFFFF; id_push <= 16'hFFFF;
                    id_splice <= 16'hFFFF; id_foreach <= 16'hFFFF; id_getctx <= 16'hFFFF;
                    id_click <= 16'hFFFF; id_ael <= 16'hFFFF; id_key <= 16'hFFFF;
                    id_fillstyle <= 16'hFFFF; id_clearrect <= 16'hFFFF; id_drawimage <= 16'hFFFF;
                    id_keydown <= 16'hFFFF; id_keyup <= 16'hFFFF; id_width <= 16'hFFFF;
                    id_height <= 16'hFFFF; id_black <= 16'hFFFF; id_white <= 16'hFFFF;
                    id_save <= 16'hFFFF; id_restore <= 16'hFFFF;
                    id_translate <= 16'hFFFF; id_rotate <= 16'hFFFF;
                    id_assign <= 16'hFFFF; id_bind <= 16'hFFFF;
                    id_proto <= 16'hFFFF; id_filltext <= 16'hFFFF; id_arc <= 16'hFFFF;
                    id_enter <= 16'hFFFF; id_keycode <= 16'hFFFF;
                    id_now <= 16'hFFFF; id_gettime <= 16'hFFFF;
                    id_beginpath <= 16'hFFFF; id_fill <= 16'hFFFF; id_stroke <= 16'hFFFF;
                    id_moveto <= 16'hFFFF; id_lineto <= 16'hFFFF; id_closepath <= 16'hFFFF;
                    id_strokestyle <= 16'hFFFF;
                    id_hex_09f <= 16'hFFFF; id_hex_f5f5 <= 16'hFFFF; id_hex_ffe6 <= 16'hFFFF;
                    id_hex_f00 <= 16'hFFFF; id_hex_aaa <= 16'hFFFF;
                    path_kind <= 2'd0; n_spr <= 4'd0; spr_wp <= 18'd0; spr_hdr <= 3'd0;
                    time_ms <= 32'd0;
                    n_fn_proto <= 7'd0;
                    enter_n <= 3'd2; enter_delay <= 4'd2;
                    for (int i = 0; i < 1024; i++) intern_var_ok[i] <= 1'b0;
                    ctx_tx <= 32'sd0; ctx_ty <= 32'sd0;
                    saved_tx <= 32'sd0; saved_ty <= 32'sd0;
                    trail_off <= 19'(16'd3 + n_consts + n_ops) << 2;
                    trail_ph <= 5'd0;
                    trail_guard <= 16'd0;
                    if (n_consts == 16'd0) begin
                        ip <= '0;
                        if (code_rdata[16]) begin
                            code_raddr <= 15'((16'd3 + n_ops));
                            state <= S_RD;
                            ret_state <= S_TRAIL;
                        end else begin
                            code_raddr <= 15'd3;
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        c_i <= '0;
                        code_raddr <= 15'd3;
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end
                S_LD_CONST: begin
                    consts[c_i[9:0]] <= $signed(code_rdata);
                    if (c_i + 16'd1 >= n_consts) begin
                        ip <= '0;
                        if (jsb_flags[0]) begin
                            code_raddr <= 15'(16'd3 + n_consts + n_ops);
                            state <= S_RD;
                            ret_state <= S_TRAIL;
                        end else begin
                            code_raddr <= 15'(16'd3 + n_consts);
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        c_i <= c_i + 16'd1;
                        code_raddr <= 15'(16'd3 + c_i + 16'd1);
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end

                S_TRAIL: begin
                    // JSB v2 trailer: names (hash intern ids) + skip vars + class table
                    trail_guard <= trail_guard + 16'd1;
                    if (trail_guard >= 16'd40000) begin
                        // walker missed phase 22 — run ops (argc=4 fillRect still paints)
                        code_raddr <= 15'(ops_base);
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic [7:0] tb;
                        case (trail_off[1:0])
                            2'd0: tb = code_rdata[7:0];
                            2'd1: tb = code_rdata[15:8];
                            2'd2: tb = code_rdata[23:16];
                            default: tb = code_rdata[31:24];
                        endcase
                        unique case (trail_ph)
                            5'd0: begin trail_acc[7:0] <= tb; trail_ph <= 5'd1; end
                            5'd1: begin
                                trail_n <= ({tb, trail_acc[7:0]} > 16'd1024) ? 16'd1024
                                         : {tb, trail_acc[7:0]};
                                name_idx <= 0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd6 : 5'd2;
                            end
                            5'd2: begin trail_acc[7:0] <= tb; trail_ph <= 5'd3; end
                            5'd3: begin
                                // u16 name hash (JSB v2) — intern, then next hash or varmap
                                if ({tb, trail_acc[7:0]} == 16'd18951) id_fillrect <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd15078) id_length <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44826) id_push <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd18044) id_splice <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54890) id_foreach <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd29049) id_getctx <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd50568) id_click <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58957) id_ael <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd40543) id_key <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd30956) id_keycode <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31632) id_arrow_l <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd22451) id_arrow_r <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32)    id_space <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd97)    id_a <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd100)   id_d <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31617) id_keydown <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd37178) id_keyup <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62822) id_reduce <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11588) id_draw <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd14537) id_update <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd12782) id_fillstyle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38353) id_clearrect <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13943) id_drawimage <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49533) id_save <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd53902) id_restore <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61774) id_translate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56667) id_rotate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd33007) id_assign <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9277) id_bind <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9506) id_proto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13648) id_filltext <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31314) id_arc <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5816) id_enter <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54382) id_beginpath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62851) id_fill <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd30264) id_stroke <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38444) id_moveto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36239) id_lineto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd64061) id_closepath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd55897) id_strokestyle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd42106) id_hex_09f <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54400) id_hex_f5f5 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61684) id_hex_ffe6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62915) id_hex_f00 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58654) id_hex_aaa <= name_idx;
                                if ({tb, trail_acc[7:0]} >= 16'd46080 && {tb, trail_acc[7:0]} <= 16'd46087)
                                    spr_nid[{tb, trail_acc[7:0]}[2:0]] <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd43734) id_now <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd47939) id_gettime <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd27262) id_this_name <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11764) id_keys_name <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44066) id_pressed <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61702) id_kspace <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36863) id_black <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52265) id_white <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd47249) id_red <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd25716) id_yellow <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54051) id_cyan <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32864) id_gold <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd48612) id_src <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52037) id_onload <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11718) id_width <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd37159) id_height <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45091) id_hex_fff <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54211) id_hex_3f6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45411) id_hex_f5a <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd16643) id_hex_fc0 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd10674) id_hex_2ec <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44003) id_hex_000 <= name_idx;
                                if (name_idx + 16'd1 >= trail_n) trail_ph <= 5'd6;
                                else begin
                                    name_idx <= name_idx + 16'd1;
                                    trail_ph <= 5'd2;
                                end
                            end
                            5'd6: begin trail_acc[7:0] <= tb; trail_ph <= 5'd7; end
                            5'd7: begin
                                trail_i <= {tb, trail_acc[7:0]};
                                trail_var_slot <= 9'd0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd10 : 5'd8;
                            end
                            5'd8: begin trail_acc[7:0] <= tb; trail_ph <= 5'd9; end
                            5'd9: begin
                                // var-map u16 = interned name idx; capture __this slot
                                if ({tb, trail_acc[7:0]} == id_this_name) begin
                                    var_this <= trail_var_slot;
                                    this_ok <= 1'b1;
                                end
                                if ({tb, trail_acc[7:0]} == id_keys_name) begin
                                    var_keys <= trail_var_slot;
                                    keys_ok <= 1'b1;
                                end
                                intern_var[{tb, trail_acc[7:0]}[9:0]] <= trail_var_slot;
                                intern_var_ok[{tb, trail_acc[7:0]}[9:0]] <= 1'b1;
                                if (trail_i <= 16'd1) trail_ph <= 5'd10;
                                else begin
                                    trail_i <= trail_i - 16'd1;
                                    trail_var_slot <= trail_var_slot + 9'd1;
                                    trail_ph <= 5'd8;
                                end
                            end
                            5'd10: begin trail_acc[7:0] <= tb; trail_ph <= 5'd11; end
                            5'd11: begin
                                n_cls <= {tb, trail_acc[7:0]}[4:0];
                                trail_cls_i <= 0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd22 : 5'd12;
                            end
                            5'd12: begin trail_acc[7:0] <= tb; trail_ph <= 5'd13; end
                            5'd13: begin
                                cls_name[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]};
                                trail_ph <= 5'd14;
                            end
                            5'd14: begin trail_acc[7:0] <= tb; trail_ph <= 5'd15; end
                            5'd15: begin
                                cls_ctor[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]};
                                trail_ph <= 5'd16;
                            end
                            5'd16: begin trail_acc[7:0] <= tb; trail_ph <= 5'd17; end
                            5'd17: begin
                                cls_nmeth[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]}[4:0];
                                trail_nmeth <= {tb, trail_acc[7:0]}[7:0];
                                trail_meth_i <= 0;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    if (trail_cls_i + 8'd1 >= {3'd0, n_cls}) trail_ph <= 5'd22;
                                    else begin
                                        trail_cls_i <= trail_cls_i + 8'd1;
                                        trail_ph <= 5'd12;
                                    end
                                end else trail_ph <= 5'd18;
                            end
                            5'd18: begin trail_acc[7:0] <= tb; trail_ph <= 5'd19; end
                            5'd19: begin
                                cls_mname[trail_cls_i[3:0]][trail_meth_i[3:0]] <= {tb, trail_acc[7:0]};
                                trail_ph <= 5'd20;
                            end
                            5'd20: begin trail_acc[7:0] <= tb; trail_ph <= 5'd21; end
                            5'd21: begin
                                cls_mip[trail_cls_i[3:0]][trail_meth_i[3:0]] <= {tb, trail_acc[7:0]};
                                if (trail_meth_i + 8'd1 >= trail_nmeth) begin
                                    if (trail_cls_i + 8'd1 >= {3'd0, n_cls}) trail_ph <= 5'd22;
                                    else begin
                                        trail_cls_i <= trail_cls_i + 8'd1;
                                        trail_ph <= 5'd12;
                                    end
                                end else begin
                                    trail_meth_i <= trail_meth_i + 8'd1;
                                    trail_ph <= 5'd18;
                                end
                            end
                            5'd22: begin
                                // peek SPR1 after class table (before UTF-8 names)
                                trail_acc[7:0] <= tb;
                                trail_ph <= 5'd23;
                            end
                            5'd23: begin trail_acc[15:8] <= tb; trail_ph <= 5'd24; end
                            5'd24: begin
                                trail_n[7:0] <= tb;
                                trail_ph <= 5'd25;
                            end
                            5'd25: begin
                                // bytes: acc[7:0], acc[15:8], trail_n[7:0], tb  == "SPR1"?
                                if (trail_acc[7:0] == 8'h53 && trail_acc[15:8] == 8'h50 &&
                                    trail_n[7:0] == 8'h52 && tb == 8'h31) begin
                                    trail_ph <= 5'd26;
                                end else begin
                                    code_raddr <= 15'(ops_base);
                                    state <= S_FETCH_WAIT;
                                    trail_ph <= 5'd31;
                                end
                            end
                            5'd26: begin trail_acc[7:0] <= tb; trail_ph <= 5'd27; end
                            5'd27: begin
                                n_spr <= ({tb, trail_acc[7:0]} > 16'd8) ? 4'd8
                                       : {tb, trail_acc[7:0]}[3:0];
                                spr_i <= 4'd0;
                                spr_wp <= 18'd0;
                                spr_left <= 18'd0;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    code_raddr <= 15'(ops_base);
                                    state <= S_FETCH_WAIT;
                                    trail_ph <= 5'd31;
                                end else begin
                                    trail_ph <= 5'd31;
                                    spr_hdr <= 3'd0;
                                    state <= S_SPR;
                                end
                            end
                            default: begin
                                // unknown phase — do not hang HTML RUN
                                code_raddr <= 15'(ops_base);
                                state <= S_FETCH_WAIT;
                            end
                        endcase
                        if (trail_ph != 5'd31 && state != S_SPR) begin
                            if (trail_off[1:0] == 2'd3) begin
                                code_raddr <= 15'(trail_off[16:2] + 15'd1);
                                trail_off <= trail_off + 16'd1;
                                state <= S_RD;
                                ret_state <= S_TRAIL;
                            end else trail_off <= trail_off + 16'd1;
                        end
                        // FETCH only after SPR miss or empty pack
                        if (trail_ph == 5'd31 && state != S_SPR) begin
                            code_raddr <= 15'(ops_base);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end

                S_FETCH_WAIT: state <= S_EXEC;

                S_EXEC: begin
                    if (ip >= n_ops) begin
                        fb_swap <= 1'b1; // one swap after the draw pass (not per-rect)
                        state <= S_WAIT_FRAME;
                    end else begin
                        unique case (code_rdata[7:0])
                            OP_LOAD_CONST: begin
                                // a1: 0=i32 1=str intern 2=undef 3=float bits→int
                                if (code_rdata[31:24] == 8'd1) begin
                                    stack[sp] <= {16'd0, code_rdata[23:8]};
                                    stack_tag[sp] <= 3'd3;
                                end else if (code_rdata[31:24] == 8'd2) begin
                                    stack[sp] <= 32'sd0;
                                    stack_tag[sp] <= 3'd5;
                                end else if (code_rdata[31:24] == 8'd3) begin
                                    // float bits → signed int (0.12 scale → 0 so x stays GAME_WIDTH/2)
                                    stack[sp] <= f32_to_i(consts[code_rdata[17:8]]);
                                    stack_tag[sp] <= 3'd0;
                                end else begin
                                    stack[sp] <= consts[code_rdata[17:8]];
                                    stack_tag[sp] <= 3'd0;
                                end
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_LOAD_VAR: begin
                                stack[sp] <= vars[code_rdata[16:8]];
                                stack_tag[sp] <= var_tag[code_rdata[16:8]];
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_STORE_VAR: begin
                                vars[code_rdata[16:8]] <= stack[sp - 8'd1];
                                var_tag[code_rdata[16:8]] <= stack_tag[sp - 8'd1];
                                var_init[code_rdata[16:8]] <= 1'b1;
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_LET_VAR: begin
                                if (!var_init[code_rdata[16:8]]) begin
                                    vars[code_rdata[16:8]] <= stack[sp - 8'd1];
                                    var_tag[code_rdata[16:8]] <= stack_tag[sp - 8'd1];
                                    var_init[code_rdata[16:8]] <= 1'b1;
                                end
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_ADD: begin
                                alu_a <= stack[sp - 8'd2];
                                alu_b <= stack[sp - 8'd1];
                                alu_op <= 3'd0;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_SUB: begin
                                alu_a <= stack[sp - 8'd2];
                                alu_b <= stack[sp - 8'd1];
                                alu_op <= 3'd1;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_MUL: begin
                                // NEW: register operands, multiply next cycle (timing)
                                mul_a <= stack[sp - 8'd2];
                                mul_b <= stack[sp - 8'd1];
                                state <= S_MUL;
                            end
                            OP_DIV: begin
                                // NEW: multi-cycle divide (see S_DIV) — the old
                                // single-cycle '/' blew board timing (WNS −90 ns)
                                if (stack[sp - 8'd1] == 0) begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else begin
                                    div_neg <= stack[sp - 8'd2][31] ^ stack[sp - 8'd1][31];
                                    div_uq  <= stack[sp - 8'd2][31]
                                               ? 32'(-stack[sp - 8'd2]) : 32'(stack[sp - 8'd2]);
                                    div_ub  <= stack[sp - 8'd1][31]
                                               ? 32'(-stack[sp - 8'd1]) : 32'(stack[sp - 8'd1]);
                                    div_rem <= '0;
                                    div_cnt <= '0;
                                    state <= S_DIV;
                                end
                            end
                            OP_LT: begin
                                alu_a <= stack[sp - 8'd2];
                                alu_b <= stack[sp - 8'd1];
                                alu_op <= 3'd2;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_GT: begin
                                alu_a <= stack[sp - 8'd2];
                                alu_b <= stack[sp - 8'd1];
                                alu_op <= 3'd3;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_EQ: begin
                                alu_a <= stack[sp - 8'd2];
                                alu_b <= stack[sp - 8'd1];
                                alu_op <= 3'd4;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_JUMP: begin
                                ip <= code_rdata[23:8];
                                code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                state <= S_FETCH_WAIT;
                            end
                            OP_JIF: begin
                                // JS falsy: undef or int 0 — objects/strings/fns at oid 0 are still truthy
                                a_s = (stack_tag[sp - 8'd1] == 3'd5 ||
                                       (stack_tag[sp - 8'd1] == 3'd0 && stack[sp - 8'd1] == 0))
                                      ? 32'sd0 : 32'sd1;
                                sp <= sp - 8'd1;
                                if (a_s == 0) begin
                                    ip <= code_rdata[23:8];
                                    code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                end else begin
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
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
                                if (looping) begin
                                    fb_swap <= 1'b1;
                                    state <= S_WAIT_FRAME;
                                end
                                else begin running <= 1'b0; state <= S_DONE; end
                            end
                            OP_POP: begin sp <= sp - 8'd1; next_op(); end
                            OP_DUP: begin
                                stack[sp] <= stack[sp - 8'd1];
                                stack_tag[sp] <= stack_tag[sp - 8'd1];
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_NEG: begin
                                alu_a <= stack[sp - 8'd1];
                                alu_op <= 3'd5;
                                state <= S_ALU;
                            end
                            OP_NOT: begin
                                // JS !x — objects/strings/fns truthy even when the packed oid is 0
                                alu_a <= (stack_tag[sp - 8'd1] == 3'd5 ||
                                          (stack_tag[sp - 8'd1] == 3'd0 && stack[sp - 8'd1] == 0))
                                         ? 32'sd0 : 32'sd1;
                                alu_op <= 3'd6;
                                state <= S_ALU;
                            end
                            OP_MOD: begin
                                // NEW: a % b — reuse divider remainder (approx); 0 if b==0
                                if (stack[sp - 8'd1] == 0) begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else begin
                                    alu_a <= stack[sp - 8'd2];
                                    alu_b <= stack[sp - 8'd1];
                                    stack[sp - 8'd2] <= stack[sp - 8'd2] - (stack[sp - 8'd2] / stack[sp - 8'd1]) * stack[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_BIT_OR: begin
                                stack[sp - 8'd2] <= stack[sp - 8'd2] | stack[sp - 8'd1];
                                stack_tag[sp - 8'd2] <= 3'd0;
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_BIT_AND: begin
                                stack[sp - 8'd2] <= stack[sp - 8'd2] & stack[sp - 8'd1];
                                stack_tag[sp - 8'd2] <= 3'd0;
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_MAKE_ARR: begin
                                arr_len[n_arr[7:0]] <= code_rdata[15:8];
                                for (int k = 0; k < ARR_CAP; k++) begin
                                    if (k < code_rdata[15:8]) begin
                                        arr_val[n_arr[7:0]][k] <= stack[sp - 8'(code_rdata[15:8] - k)];
                                        arr_tag[n_arr[7:0]][k] <= stack_tag[sp - 8'(code_rdata[15:8] - k)];
                                    end
                                end
                                sp <= sp - code_rdata[15:8];
                                stack[sp - code_rdata[15:8]] <= {16'd0, n_arr};
                                stack_tag[sp - code_rdata[15:8]] <= 3'd2;
                                n_arr <= n_arr + 16'd1;
                                sp <= sp - code_rdata[15:8] + 8'd1;
                                next_op();
                            end
                            OP_ARR_GET: begin
                                // stack [arr, idx]
                                if (stack_tag[sp - 8'd2] == 3'd2) begin
                                    stack[sp - 8'd2] <= arr_val[stack[sp - 8'd2][7:0]][stack[sp - 8'd1][6:0]];
                                    stack_tag[sp - 8'd2] <= arr_tag[stack[sp - 8'd2][7:0]][stack[sp - 8'd1][6:0]];
                                end else begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    stack_tag[sp - 8'd2] <= 3'd5;
                                end
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_ARR_SET: begin
                                // [arr, idx, val]
                                if (stack_tag[sp - 8'd3] == 3'd2) begin
                                    arr_val[stack[sp - 8'd3][7:0]][stack[sp - 8'd2][6:0]] <= stack[sp - 8'd1];
                                    arr_tag[stack[sp - 8'd3][7:0]][stack[sp - 8'd2][6:0]] <= stack_tag[sp - 8'd1];
                                end
                                stack[sp - 8'd3] <= stack[sp - 8'd1];
                                stack_tag[sp - 8'd3] <= stack_tag[sp - 8'd1];
                                sp <= sp - 8'd2;
                                next_op();
                            end
                            OP_MAKE_OBJ: begin
                                obj_n[n_obj[10:0]] <= 0;
                                obj_cls[n_obj[10:0]] <= 0;
                                stack[sp] <= {16'd0, n_obj};
                                stack_tag[sp] <= 3'd1;
                                n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_GET_PROP: begin
                                if (stack_tag[sp - 8'd1] == 3'd2 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    stack[sp - 8'd1] <= {24'd0, arr_len[stack[sp - 8'd1][7:0]]};
                                    stack_tag[sp - 8'd1] <= 3'd0;
                                end else if (stack_tag[sp - 8'd1] == 3'd1) begin
                                    begin
                                        logic [10:0] gi, pi;
                                        logic foundp;
                                        gi = stack[sp - 8'd1][10:0];
                                        stack[sp - 8'd1] <= 32'sd0;
                                        stack_tag[sp - 8'd1] <= 3'd5;
                                        foundp = 1'b0;
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s < obj_n[gi] && obj_key[gi][s] == code_rdata[23:8]) begin
                                                stack[sp - 8'd1] <= obj_val[gi][s];
                                                stack_tag[sp - 8'd1] <= obj_tag[gi][s];
                                                foundp = 1'b1;
                                            end
                                        end
                                        // PACMAN Item.prototype.foo — walk __proto__ if miss
                                        if (!foundp && code_rdata[23:8] != id_proto) begin
                                            pi = 11'd0;
                                            for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                if (s < obj_n[gi] && obj_key[gi][s] == id_proto &&
                                                    obj_tag[gi][s] == 3'd1)
                                                    pi = obj_val[gi][s][10:0];
                                            end
                                            for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                if (s < obj_n[pi] && obj_key[pi][s] == code_rdata[23:8]) begin
                                                    stack[sp - 8'd1] <= obj_val[pi][s];
                                                    stack_tag[sp - 8'd1] <= obj_tag[pi][s];
                                                end
                                            end
                                        end
                                        // GET_PROP prototype on instance with no slot: alloc empty proto
                                        if (!foundp && code_rdata[23:8] == id_proto) begin
                                            obj_n[n_obj[10:0]] <= 0;
                                            obj_cls[n_obj[10:0]] <= 0;
                                            stack[sp - 8'd1] <= {16'd0, n_obj};
                                            stack_tag[sp - 8'd1] <= 3'd1;
                                            if (obj_n[gi] < OBJ_SLOTS[5:0]) begin
                                                obj_key[gi][obj_n[gi]] <= id_proto;
                                                obj_val[gi][obj_n[gi]] <= {16'd0, n_obj};
                                                obj_tag[gi][obj_n[gi]] <= 3'd1;
                                                obj_n[gi] <= obj_n[gi] + 6'd1;
                                            end
                                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                                        end
                                        // KEYBITS OR into HTML keys.*.pressed at read
                                        if (code_rdata[23:8] == id_pressed || code_rdata[23:8] == 16'd198) begin
                                            if (gi == keys_a_oid[10:0] && joy_in[2]) begin
                                                stack[sp - 8'd1] <= 32'sd1;
                                                stack_tag[sp - 8'd1] <= 3'd0;
                                            end else if (gi == keys_d_oid[10:0] && joy_in[3]) begin
                                                stack[sp - 8'd1] <= 32'sd1;
                                                stack_tag[sp - 8'd1] <= 3'd0;
                                            end else if (gi == keys_sp_oid[10:0] && joy_in[4]) begin
                                                stack[sp - 8'd1] <= 32'sd1;
                                                stack_tag[sp - 8'd1] <= 3'd0;
                                            end
                                        end
                                    end
                                end else if (stack_tag[sp - 8'd1] == 3'd4 &&
                                            code_rdata[23:8] == id_proto) begin
                                    // Fn.prototype — stable heap object per MAKE_FN entry
                                    begin
                                        logic [15:0] poid;
                                        logic hit;
                                        hit = 1'b0;
                                        poid = 16'd0;
                                        for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                            if (i < n_fn_proto && fn_proto_ip[i] == stack[sp - 8'd1][15:0]) begin
                                                hit = 1'b1;
                                                poid = fn_proto_oid[i];
                                            end
                                        end
                                        if (!hit && n_fn_proto < MAX_FN_PROTO[6:0]) begin
                                            poid = n_obj;
                                            obj_n[n_obj[10:0]] <= 0;
                                            obj_cls[n_obj[10:0]] <= 0;
                                            fn_proto_ip[n_fn_proto] <= stack[sp - 8'd1][15:0];
                                            fn_proto_oid[n_fn_proto] <= n_obj;
                                            n_fn_proto <= n_fn_proto + 7'd1;
                                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                                        end
                                        stack[sp - 8'd1] <= {16'd0, poid};
                                        stack_tag[sp - 8'd1] <= 3'd1;
                                    end
                                end else if (stack_tag[sp - 8'd1] == 3'd6 && code_rdata[23:8] == id_click) begin
                                    stack[sp - 8'd1] <= 32'sd1;
                                    stack_tag[sp - 8'd1] <= 3'd4; // truthy click handle
                                end else if (stack_tag[sp - 8'd1] == 3'd6 &&
                                            (code_rdata[23:8] == id_width || code_rdata[23:8] == id_height)) begin
                                    // canvas.width / canvas.height (INVADERS GAME_WIDTH path is literals; keep DOM sized)
                                    stack[sp - 8'd1] <= (code_rdata[23:8] == id_width) ? 32'sd640 : 32'sd480;
                                    stack_tag[sp - 8'd1] <= 3'd0;
                                end else if (stack_tag[sp - 8'd1] == 3'd6) begin
                                    // DOM .style → same elem so .style.display is a no-op SET
                                    stack_tag[sp - 8'd1] <= 3'd6;
                                end else begin
                                    stack[sp - 8'd1] <= 32'sd0;
                                    stack_tag[sp - 8'd1] <= 3'd5;
                                end
                                next_op();
                            end
                            OP_SET_PROP: begin
                                // [obj, val]  a0=name
                                if (stack_tag[sp - 8'd2] == 3'd1) begin
                                    begin
                                        logic [10:0] oi;
                                        logic found;
                                        oi = stack[sp - 8'd2][10:0];
                                        found = 1'b0;
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s < obj_n[oi] && obj_key[oi][s] == code_rdata[23:8]) begin
                                                obj_val[oi][s] <= stack[sp - 8'd1];
                                                obj_tag[oi][s] <= stack_tag[sp - 8'd1];
                                                found = 1'b1;
                                            end
                                        end
                                        if (!found && obj_n[oi] < OBJ_SLOTS[5:0]) begin
                                            obj_key[oi][obj_n[oi]] <= code_rdata[23:8];
                                            obj_val[oi][obj_n[oi]] <= stack[sp - 8'd1];
                                            obj_tag[oi][obj_n[oi]] <= stack_tag[sp - 8'd1];
                                            obj_n[oi] <= obj_n[oi] + 6'd1;
                                        end
                                        // last .a/.d/.space object wins — INVADERS keys table
                                        // hardcoded idx: intern miss still captures (same as forEach=112)
                                        if (stack_tag[sp - 8'd1] == 3'd1) begin
                                            if (code_rdata[23:8] == id_a || code_rdata[23:8] == 16'd98)
                                                keys_a_oid <= stack[sp - 8'd1][15:0];
                                            if (code_rdata[23:8] == id_d || code_rdata[23:8] == 16'd199)
                                                keys_d_oid <= stack[sp - 8'd1][15:0];
                                            if (code_rdata[23:8] == id_kspace || code_rdata[23:8] == 16'd204)
                                                keys_sp_oid <= stack[sp - 8'd1][15:0];
                                        end
                                        if (code_rdata[23:8] == id_src && stack_tag[sp - 8'd1] == 3'd3) begin
                                            // Image.src = "jmr:spr:N" → pack index in obj_cls
                                            for (int k = 0; k < 8; k++)
                                                if (stack[sp - 8'd1][15:0] == spr_nid[k[2:0]])
                                                    obj_cls[oi] <= 16'hFFC0 | k[15:0];
                                        end
                                    end
                                    // Image.onload = fn — invoke now so player.image exists before animate
                                    if (code_rdata[23:8] == id_onload && stack_tag[sp - 8'd1] == 3'd4) begin
                                        cstack_ip[csp] <= ip + 16'd1;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b0;
                                        cstack_isfe[csp] <= 1'b0;
                                        csp <= csp + 7'd1;
                                        ip <= stack[sp - 8'd1][15:0];
                                        code_raddr <= 15'(ops_base + stack[sp - 8'd1][15:0]);
                                        stack[sp - 8'd2] <= stack[sp - 8'd1];
                                        stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                        sp <= sp - 8'd1;
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        stack[sp - 8'd2] <= stack[sp - 8'd1];
                                        stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                        sp <= sp - 8'd1;
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'd2] == 3'd2 &&
                                           (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    arr_len[stack[sp - 8'd2][7:0]] <= stack[sp - 8'd1][7:0];
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                           (code_rdata[23:8] == id_fillstyle ||
                                            code_rdata[23:8] == id_strokestyle)) begin
                                    // ctx.fillStyle / strokeStyle — CanvasEngine pal 0..7
                                    if (stack[sp - 8'd1][15:0] == id_black || stack[sp - 8'd1][15:0] == id_hex_000)
                                        fill_style_i <= 8'd0;
                                    else if (stack[sp - 8'd1][15:0] == id_white || stack[sp - 8'd1][15:0] == id_hex_fff
                                          || stack[sp - 8'd1][15:0] == id_hex_aaa
                                          || stack[sp - 8'd1][15:0] == id_hex_f5f5)
                                        fill_style_i <= 8'd1;
                                    else if (stack[sp - 8'd1][15:0] == id_red || stack[sp - 8'd1][15:0] == id_hex_f00)
                                        fill_style_i <= 8'd2;
                                    else if (stack[sp - 8'd1][15:0] == id_hex_3f6 || stack[sp - 8'd1][15:0] == id_hex_2ec)
                                        fill_style_i <= 8'd3;
                                    else if (stack[sp - 8'd1][15:0] == id_cyan || stack[sp - 8'd1][15:0] == id_hex_09f)
                                        fill_style_i <= 8'd4;
                                    else if (stack[sp - 8'd1][15:0] == id_yellow || stack[sp - 8'd1][15:0] == id_gold
                                          || stack[sp - 8'd1][15:0] == id_hex_fc0
                                          || stack[sp - 8'd1][15:0] == id_hex_ffe6)
                                        fill_style_i <= 8'd5;
                                    else if (stack[sp - 8'd1][15:0] == id_hex_f5a)
                                        fill_style_i <= 8'd7;
                                    else fill_style_i <= 8'd1;
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else begin
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_MAKE_FN: begin
                                stack[sp] <= {8'd0, code_rdata[31:24], code_rdata[23:8]}; // nparam, entry
                                stack_tag[sp] <= 3'd4;
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_CALL_USER: begin
                                cstack_ip[csp] <= ip + 16'd1;
                                cstack_this[csp] <= this_obj;
                                cstack_isctor[csp] <= 1'b0;
                                cstack_isfe[csp] <= 1'b0;
                                csp <= csp + 7'd1;
                                ip <= code_rdata[23:8];
                                code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                state <= S_FETCH_WAIT;
                            end
                            OP_CALL_VAL: begin
                                // argc in a0; stack [fn, args...] — pop fn, leave args (PYTHON call_fn)
                                if (stack_tag[sp - 8'(code_rdata[15:8]) - 8'd1] == 3'd4) begin
                                    begin
                                        logic [7:0] ac;
                                        ac = code_rdata[15:8];
                                        for (int k = 0; k < 8; k++) begin
                                            if (k < ac) begin
                                                stack[sp - ac - 8'd1 + k[7:0]] <= stack[sp - ac + k[7:0]];
                                                stack_tag[sp - ac - 8'd1 + k[7:0]] <= stack_tag[sp - ac + k[7:0]];
                                            end
                                        end
                                        sp <= sp - 8'd1;
                                    end
                                    cstack_ip[csp] <= ip + 16'd1;
                                    cstack_this[csp] <= this_obj;
                                    cstack_isctor[csp] <= 1'b0;
                                    cstack_isfe[csp] <= 1'b0;
                                    csp <= csp + 7'd1;
                                    ip <= stack[sp - 8'(code_rdata[15:8]) - 8'd1][15:0];
                                    code_raddr <= 15'(ops_base + stack[sp - 8'(code_rdata[15:8]) - 8'd1][15:0]);
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    sp <= sp - 8'(code_rdata[15:8]) - 8'd1;
                                    stack[sp - 8'(code_rdata[15:8]) - 8'd1] <= 32'sd0;
                                    stack_tag[sp - 8'(code_rdata[15:8]) - 8'd1] <= 3'd5;
                                    sp <= sp - 8'(code_rdata[15:8]);
                                    next_op();
                                end
                            end
                            OP_RET_VAL: begin
                                if (csp == 0) begin
                                    fb_swap <= 1'b1;
                                    state <= S_WAIT_FRAME;
                                end else if (cstack_ip[csp - 7'd1] == 16'hFFFE) begin
                                    // NEW: return from forEach callback → next element
                                    csp <= csp - 7'd1;
                                    if (sp != 0) sp <= sp - 8'd1; // discard callback retval
                                    cstack_fe_i[csp - 7'd2] <= cstack_fe_i[csp - 7'd2] + 8'd1;
                                    state <= S_FOREACH;
                                end else begin
                                    csp <= csp - 7'd1;
                                    this_obj <= cstack_this[csp - 7'd1];
                                    if (this_ok) begin
                                        vars[var_this] <= {16'd0, cstack_this[csp - 7'd1]};
                                        var_tag[var_this] <= 3'd1;
                                    end
                                    if (cstack_isctor[csp - 7'd1]) begin
                                        stack[sp - 8'd1] <= {16'd0, cstack_ctorobj[csp - 7'd1]};
                                        stack_tag[sp - 8'd1] <= 3'd1;
                                    end
                                    ip <= cstack_ip[csp - 7'd1];
                                    code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd1]);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_NEW_OBJ: begin
                                obj_n[n_obj[10:0]] <= 0;
                                obj_cls[n_obj[10:0]] <= code_rdata[23:8];
                                begin
                                    logic [15:0] ctor_ip;
                                    logic [8:0] vslot;
                                    ctor_ip = 16'hFFFF;
                                    for (int c = 0; c < MAX_CLS; c++) begin
                                        if (c < n_cls && cls_name[c] == code_rdata[23:8])
                                            ctor_ip = cls_ctor[c];
                                    end
                                    // PACMAN `var Item = function` — class table ctor is FFFF
                                    if (ctor_ip == 16'hFFFF && intern_var_ok[code_rdata[17:8]]) begin
                                        vslot = intern_var[code_rdata[17:8]];
                                        if (var_tag[vslot] == 3'd4)
                                            ctor_ip = vars[vslot][15:0];
                                    end
                                    // copy Fn.prototype onto new object
                                    for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                        if (i < n_fn_proto && fn_proto_ip[i] == ctor_ip) begin
                                            obj_key[n_obj[10:0]][0] <= id_proto;
                                            obj_val[n_obj[10:0]][0] <= {16'd0, fn_proto_oid[i]};
                                            obj_tag[n_obj[10:0]][0] <= 3'd1;
                                            obj_n[n_obj[10:0]] <= 6'd1;
                                        end
                                    end
                                    if (ctor_ip != 16'hFFFF) begin
                                        cstack_ip[csp] <= ip + 16'd1;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b1;
                                        cstack_isfe[csp] <= 1'b0;
                                        cstack_ctorobj[csp] <= n_obj;
                                        csp <= csp + 7'd1;
                                        this_obj <= n_obj;
                                        if (this_ok) begin
                                            vars[var_this] <= n_obj;
                                            var_tag[var_this] <= 3'd1;
                                        end
                                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                                        ip <= ctor_ip;
                                        code_raddr <= 15'(ops_base + ctor_ip);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        stack[sp] <= {16'd0, n_obj};
                                        stack_tag[sp] <= 3'd1;
                                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                                        sp <= sp + 8'd1;
                                        next_op();
                                    end
                                end
                            end
                            OP_CALL_METH: begin
                                // [obj, args...] a0=meth intern a1=argc
                                if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                    code_rdata[23:8] == id_push) begin
                                    begin
                                        logic [7:0] ai, al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][7:0];
                                        al = arr_len[ai];
                                        if (al < ARR_CAP[7:0]) begin
                                            arr_val[ai][al] <= stack[sp - 8'd1];
                                            arr_tag[ai][al] <= stack_tag[sp - 8'd1];
                                            arr_len[ai] <= al + 8'd1;
                                        end
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= {24'd0, al + 8'd1};
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           (code_rdata[23:8] == id_foreach ||
                                            code_rdata[23:8] == 16'd112)) begin
                                    // arr.forEach(fn) — frame holds arr/fn/nparam; S_FOREACH drains
                                    cstack_ip[csp] <= ip + 16'd1;
                                    cstack_this[csp] <= this_obj;
                                    cstack_isctor[csp] <= 1'b0;
                                    cstack_isfe[csp] <= 1'b1;
                                    cstack_fe_arr[csp] <= stack[sp - 8'(code_rdata[31:24]) - 8'd1][15:0];
                                    cstack_fe_fn[csp] <= stack[sp - 8'd1][15:0];
                                    cstack_ctorobj[csp] <= {8'd0, stack[sp - 8'd1][23:16]}; // nparam
                                    cstack_fe_i[csp] <= 8'd0;
                                    csp <= csp + 7'd1;
                                    sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                    state <= S_FOREACH;
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_splice) begin
                                    // splice(start, n) — shift-delete (INVADERS cull)
                                    begin
                                        logic [7:0] ai, st, cnt;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][7:0];
                                        st = (code_rdata[31:24] >= 8'd1) ? stack[sp - 8'(code_rdata[31:24])][7:0] : 8'd0;
                                        cnt = (code_rdata[31:24] >= 8'd2) ? stack[sp - 8'd1][7:0] : 8'd1;
                                        if (st < arr_len[ai]) begin
                                            for (int j = 0; j < ARR_CAP - 1; j++) begin
                                                if (j >= st && (j + cnt) < ARR_CAP) begin
                                                    arr_val[ai][j] <= arr_val[ai][j + cnt];
                                                    arr_tag[ai][j] <= arr_tag[ai][j + cnt];
                                                end
                                            end
                                            if (arr_len[ai] > cnt) arr_len[ai] <= arr_len[ai] - cnt;
                                            else arr_len[ai] <= 8'd0;
                                        end
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'sd0;
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd2;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_ael) begin
                                    // el.addEventListener(type, fn) — same as document native
                                    if (stack[sp - 8'd2][15:0] == id_keydown)
                                        kd_fn <= stack[sp - 8'd1][15:0];
                                    if (stack[sp - 8'd2][15:0] == id_keyup)
                                        ku_fn <= stack[sp - 8'd1][15:0];
                                    if (stack[sp - 8'd2][15:0] == id_click && click_fn == 16'hFFFF)
                                        click_fn <= stack[sp - 8'd1][15:0];
                                    stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'sd0;
                                    stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd5;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd6 &&
                                           code_rdata[23:8] == id_getctx) begin
                                    stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'd1; // canvas2d elem
                                    stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd6;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd6 &&
                                           code_rdata[23:8] == id_click) begin
                                    if (click_fn != 16'hFFFF) begin
                                        click_fired <= 1'b1;
                                        cstack_ip[csp] <= ip + 16'd1;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b0;
                                        cstack_isfe[csp] <= 1'b0;
                                        csp <= csp + 7'd1;
                                        ip <= click_fn;
                                        code_raddr <= 15'(ops_base + click_fn);
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_now ||
                                           code_rdata[23:8] == id_gettime) begin
                                    // Date.now() / date.getTime() — PACMAN start() skips draw if Δ<16
                                    begin
                                        logic [31:0] t;
                                        t = time_ms + 32'd17;
                                        time_ms <= t;
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= t;
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                            obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][10:0]] == 16'hFFFD &&
                                            code_rdata[31:24] == 8'd0) begin
                                    // (new Date()).getTime() even if intern id_gettime missed
                                    begin
                                        logic [31:0] t;
                                        t = time_ms + 32'd17;
                                        time_ms <= t;
                                        stack[sp - 8'd1] <= t;
                                        stack_tag[sp - 8'd1] <= 3'd0;
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_bind) begin
                                    // fn.bind(this) — leave the fn (PYTHON copies bound_this)
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_assign) begin
                                    // Object.assign(target, ...src) — append src slots onto target
                                    begin
                                        logic [10:0] ti, si;
                                        logic [5:0] tn;
                                        logic [7:0] aca;
                                        aca = code_rdata[31:24];
                                        ti = stack[sp - aca][10:0];
                                        tn = obj_n[ti];
                                        if (stack_tag[sp - aca] == 3'd1) begin
                                            for (int src = 0; src < 3; src++) begin
                                                if (src < aca - 8'd1) begin
                                                    si = stack[sp - aca + 8'(src) + 8'd1][10:0];
                                                    if (stack_tag[sp - aca + 8'(src) + 8'd1] == 3'd1) begin
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            if (s < obj_n[si] && tn < OBJ_SLOTS[5:0]) begin
                                                                obj_key[ti][tn] <= obj_key[si][s];
                                                                obj_val[ti][tn] <= obj_val[si][s];
                                                                obj_tag[ti][tn] <= obj_tag[si][s];
                                                                tn = tn + 6'd1;
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                            obj_n[ti] <= tn;
                                        end
                                        stack[sp - aca - 8'd1] <= stack[sp - aca];
                                        stack_tag[sp - aca - 8'd1] <= stack_tag[sp - aca];
                                        sp <= sp - aca;
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_save) begin
                                    saved_tx <= ctx_tx; saved_ty <= ctx_ty;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_restore) begin
                                    ctx_tx <= saved_tx; ctx_ty <= saved_ty;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_translate) begin
                                    ctx_tx <= ctx_tx + stack[sp - 8'd2];
                                    ctx_ty <= ctx_ty + stack[sp - 8'd1];
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rotate) begin
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_beginpath ||
                                           code_rdata[23:8] == id_closepath) begin
                                    path_kind <= 2'd0;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_arc && code_rdata[31:24] >= 8'd3) begin
                                    path_x0 <= stack[sp - 8'(code_rdata[31:24])] + ctx_tx;
                                    path_y0 <= stack[sp - 8'(code_rdata[31:24]) + 8'd1] + ctx_ty;
                                    path_r  <= stack[sp - 8'(code_rdata[31:24]) + 8'd2];
                                    path_kind <= 2'd1;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_moveto && code_rdata[31:24] >= 8'd2) begin
                                    path_x0 <= stack[sp - 8'd2] + ctx_tx;
                                    path_y0 <= stack[sp - 8'd1] + ctx_ty;
                                    path_kind <= 2'd2;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_lineto && code_rdata[31:24] >= 8'd2) begin
                                    path_x1 <= stack[sp - 8'd2] + ctx_tx;
                                    path_y1 <= stack[sp - 8'd1] + ctx_ty;
                                    path_kind <= 2'd3;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_fill ||
                                           code_rdata[23:8] == id_stroke) begin
                                    color <= fill_style_i;
                                    path_stroke <= (code_rdata[23:8] == id_stroke);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    ip <= ip + 16'd1;
                                    if (path_kind == 2'd1) begin
                                        rx <= clip_u(path_x0, MW);
                                        ry <= clip_u(path_y0, MH);
                                        rw <= clip_sz(path_r < 0 ? -path_r : path_r, 10'd0, 512);
                                        x <= clip_u(path_x0 - path_r, MW);
                                        y <= clip_u(path_y0 - path_r, MH);
                                        state <= S_CIRCLE;
                                    end else if (path_kind == 2'd3) begin
                                        rx <= clip_u(path_x0, MW);
                                        ry <= clip_u(path_y0, MH);
                                        x  <= clip_u(path_x1, MW);
                                        y  <= clip_u(path_y1, MH);
                                        state <= S_LINE;
                                    end else begin
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end else if (code_rdata[23:8] == id_filltext) begin
                                    color <= fill_style_i;
                                    rx <= clip_u(stack[sp - 8'd2] + ctx_tx, MW);
                                    ry <= clip_u(stack[sp - 8'd1] + ctx_ty, MH);
                                    rw <= 10'd64; rh <= 10'd8;
                                    x <= clip_u(stack[sp - 8'd2] + ctx_tx, MW);
                                    y <= clip_u(stack[sp - 8'd1] + ctx_ty, MH);
                                    sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                    ip <= ip + 16'd1;
                                    state <= S_RECT;
                                end else if (code_rdata[23:8] == id_drawimage) begin
                                    // real sprite blit when Image.src was jmr:spr:N
                                    begin
                                        logic [15:0] ioid;
                                        logic [7:0] ac, si;
                                        ac = code_rdata[31:24];
                                        // args: img at sp-ac, then dx,dy[,dw,dh] or 9-arg sheet
                                        ioid = stack[sp - ac][15:0];
                                        si = obj_cls[ioid[10:0]][2:0];
                                        if (obj_cls[ioid[10:0]][15:4] == 12'hFFC && {1'b0, si} < n_spr) begin
                                            blit_si <= si;
                                            if (ac >= 8'd9) begin
                                                blit_sx <= clip_u(stack[sp - 8'd8], 1024);
                                                blit_sy <= clip_u(stack[sp - 8'd7], 1024);
                                                blit_sw <= clip_sz(stack[sp - 8'd6], 10'd0, 1024);
                                                blit_sh <= clip_sz(stack[sp - 8'd5], 10'd0, 1024);
                                                rx <= clip_u(stack[sp - 8'd4] + ctx_tx, MW);
                                                ry <= clip_u(stack[sp - 8'd3] + ctx_ty, MH);
                                                rw <= clip_sz(stack[sp - 8'd2], clip_u(stack[sp - 8'd4] + ctx_tx, MW), MW);
                                                rh <= clip_sz(stack[sp - 8'd1], clip_u(stack[sp - 8'd3] + ctx_ty, MH), MH);
                                            end else if (ac >= 8'd5) begin
                                                blit_sx <= 10'd0; blit_sy <= 10'd0;
                                                blit_sw <= spr_ww[si[2:0]]; blit_sh <= spr_hh[si[2:0]];
                                                rx <= clip_u(stack[sp - 8'd4] + ctx_tx, MW);
                                                ry <= clip_u(stack[sp - 8'd3] + ctx_ty, MH);
                                                rw <= clip_sz(stack[sp - 8'd2], clip_u(stack[sp - 8'd4] + ctx_tx, MW), MW);
                                                rh <= clip_sz(stack[sp - 8'd1], clip_u(stack[sp - 8'd3] + ctx_ty, MH), MH);
                                            end else begin
                                                blit_sx <= 10'd0; blit_sy <= 10'd0;
                                                blit_sw <= spr_ww[si[2:0]]; blit_sh <= spr_hh[si[2:0]];
                                                rx <= clip_u(stack[sp - 8'd2] + ctx_tx, MW);
                                                ry <= clip_u(stack[sp - 8'd1] + ctx_ty, MH);
                                                rw <= spr_ww[si[2:0]]; rh <= spr_hh[si[2:0]];
                                            end
                                            x <= 10'd0; y <= 10'd0;
                                            sp <= sp - ac - 8'd1;
                                            ip <= ip + 16'd1;
                                            state <= S_BLIT;
                                        end else begin
                                            // no sprite — skip (do not paint a giant magenta box)
                                            sp <= sp - ac - 8'd1;
                                            next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_fillrect ||
                                           code_rdata[23:8] == id_clearrect ||
                                           code_rdata[31:24] == 8'd4) begin
                                    // ctx.fillRect(x,y,w,h) — argc=4 fallback if intern id missed
                                    color <= (code_rdata[23:8] == id_clearrect) ? 8'd0 : fill_style_i;
                                    begin
                                        logic [9:0] tw, th, tx, ty;
                                        tx = clip_u(stack[sp - 8'd4] + ctx_tx, MW);
                                        ty = clip_u(stack[sp - 8'd3] + ctx_ty, MH);
                                        tw = clip_sz(stack[sp - 8'd2], tx, MW);
                                        th = clip_sz(stack[sp - 8'd1], ty, MH);
                                        rx <= tx; ry <= ty; rw <= tw; rh <= th;
                                        x <= tx; y <= ty;
                                    end
                                    sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                    ip <= ip + 16'd1; // else S_RECT re-fetches this fillRect forever
                                    state <= S_RECT;
                                end else begin
                                    // class method lookup — pop receiver, leave args
                                    begin
                                        logic [15:0] mip, oid;
                                        logic [2:0] ot;
                                        logic [7:0] ac;
                                        mip = 16'hFFFF;
                                        ac = code_rdata[31:24];
                                        ot = stack_tag[sp - ac - 8'd1];
                                        oid = stack[sp - ac - 8'd1][15:0];
                                        if (ot == 3'd1) begin
                                            for (int c = 0; c < MAX_CLS; c++) begin
                                                if (c < n_cls && cls_name[c] == obj_cls[oid[10:0]]) begin
                                                    for (int m = 0; m < MAX_CMETH; m++) begin
                                                        if (m < cls_nmeth[c] && cls_mname[c][m] == code_rdata[23:8])
                                                            mip = cls_mip[c][m];
                                                    end
                                                end
                                            end
                                        end
                                        if (mip != 16'hFFFF) begin
                                            for (int k = 0; k < 8; k++) begin
                                                if (k < ac) begin
                                                    stack[sp - ac - 8'd1 + k[7:0]] <= stack[sp - ac + k[7:0]];
                                                    stack_tag[sp - ac - 8'd1 + k[7:0]] <= stack_tag[sp - ac + k[7:0]];
                                                end
                                            end
                                            sp <= sp - 8'd1;
                                            cstack_ip[csp] <= ip + 16'd1;
                                            cstack_this[csp] <= this_obj;
                                            cstack_isctor[csp] <= 1'b0;
                                            cstack_isfe[csp] <= 1'b0;
                                            csp <= csp + 7'd1;
                                            this_obj <= oid;
                                            if (this_ok) begin
                                                vars[var_this] <= oid;
                                                var_tag[var_this] <= 3'd1;
                                            end
                                            ip <= mip;
                                            code_raddr <= 15'(ops_base + mip);
                                            state <= S_FETCH_WAIT;
                                        end else begin
                                            // instance-property Fn (PACMAN this.createStage)
                                            begin
                                                logic [15:0] fip;
                                                logic [10:0] pi;
                                                fip = 16'hFFFF;
                                                pi = 11'd0;
                                                if (ot == 3'd1) begin
                                                    for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                        if (s < obj_n[oid[10:0]] &&
                                                            obj_key[oid[10:0]][s] == code_rdata[23:8] &&
                                                            obj_tag[oid[10:0]][s] == 3'd4)
                                                            fip = obj_val[oid[10:0]][s][15:0];
                                                    end
                                                    if (fip == 16'hFFFF) begin
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            if (s < obj_n[oid[10:0]] &&
                                                                obj_key[oid[10:0]][s] == id_proto &&
                                                                obj_tag[oid[10:0]][s] == 3'd1)
                                                                pi = obj_val[oid[10:0]][s][10:0];
                                                        end
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            if (s < obj_n[pi] &&
                                                                obj_key[pi][s] == code_rdata[23:8] &&
                                                                obj_tag[pi][s] == 3'd4)
                                                                fip = obj_val[pi][s][15:0];
                                                        end
                                                    end
                                                end
                                                if (fip != 16'hFFFF) begin
                                                    for (int k = 0; k < 8; k++) begin
                                                        if (k < ac) begin
                                                            stack[sp - ac - 8'd1 + k[7:0]] <= stack[sp - ac + k[7:0]];
                                                            stack_tag[sp - ac - 8'd1 + k[7:0]] <= stack_tag[sp - ac + k[7:0]];
                                                        end
                                                    end
                                                    sp <= sp - 8'd1;
                                                    cstack_ip[csp] <= ip + 16'd1;
                                                    cstack_this[csp] <= this_obj;
                                                    cstack_isctor[csp] <= 1'b0;
                                                    cstack_isfe[csp] <= 1'b0;
                                                    csp <= csp + 7'd1;
                                                    this_obj <= oid;
                                                    if (this_ok) begin
                                                        vars[var_this] <= oid;
                                                        var_tag[var_this] <= 3'd1;
                                                    end
                                                    ip <= fip;
                                                    code_raddr <= 15'(ops_base + fip);
                                                    state <= S_FETCH_WAIT;
                                                end else begin
                                                    stack[sp - ac - 8'd1] <= 32'sd0;
                                                    stack_tag[sp - ac - 8'd1] <= 3'd5;
                                                    sp <= sp - ac;
                                                    next_op();
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            default: next_op();
                        endcase
                    end
                end

                S_NAT: begin
                    unique case (nat_id)
                        8'd0: begin
                            sp <= sp - nat_argc[7:0];
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd1: begin
                            if (nat_argc >= 8'd1) begin
                                color <= sat8(stack[sp - 8'd1]);
                                sp <= sp - 8'd1;
                            end else color <= 8'd0;
                            clr_idx <= '0;
                            state <= S_CLEAR;
                        end
                        8'd2: begin
                            // fillRect(x,y,w,h,color) — native 640×480, clipped
                            color <= sat8(stack[sp - 8'd1]);
                            rx <= clip_u(stack[sp - 8'd5], MW);
                            ry <= clip_u(stack[sp - 8'd4], MH);
                            rw <= clip_sz(stack[sp - 8'd3], clip_u(stack[sp - 8'd5], MW), MW);
                            rh <= clip_sz(stack[sp - 8'd2], clip_u(stack[sp - 8'd4], MH), MH);
                            x  <= clip_u(stack[sp - 8'd5], MW);
                            y  <= clip_u(stack[sp - 8'd4], MH);
                            sp <= sp - 8'd5;
                            state <= S_RECT;
                        end
                        8'd3: begin
                            fb_swap <= 1'b1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd4: begin
                            // NEW: keyLeft = JOY_LEFT bit2 (was [0]=UP — gun ignored arrows)
                            stack[sp] <= joy_in[2] ? 32'sd1 : 32'sd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd5: begin
                            // NEW: keyRight = JOY_RIGHT bit3 (was [1]=DOWN)
                            stack[sp] <= joy_in[3] ? 32'sd1 : 32'sd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd6: begin
                            // keyFire = JOY_FIRE1 bit4 (unchanged; matches PYTHON)
                            stack[sp] <= joy_in[4] ? 32'sd1 : 32'sd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd7: begin
                            looping <= 1'b1;
                            fb_swap <= 1'b1;
                            state <= S_WAIT_FRAME;
                        end
                        8'd8: begin
                            // NEW: keyUp = JOY_UP bit0 (DONKEY climb)
                            stack[sp] <= joy_in[0] ? 32'sd1 : 32'sd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd9: begin
                            // NEW: keyDown = JOY_DOWN bit1
                            stack[sp] <= joy_in[1] ? 32'sd1 : 32'sd0;
                            stack_tag[sp] <= 3'd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        // NEW: Math / DOM / rAF (HTML .JSH)
                        8'd10, 8'd11: begin // floor / abs
                            stack[sp - 8'd1] <= (nat_id == 8'd11 && stack[sp - 8'd1][31]) ?
                                -stack[sp - 8'd1] : stack[sp - 8'd1];
                            stack_tag[sp - 8'd1] <= 3'd0;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd12: begin // min
                            stack[sp - 8'd2] <= (stack[sp - 8'd2] < stack[sp - 8'd1]) ?
                                stack[sp - 8'd2] : stack[sp - 8'd1];
                            stack_tag[sp - 8'd2] <= 3'd0;
                            sp <= sp - 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd13: begin // max
                            stack[sp - 8'd2] <= (stack[sp - 8'd2] > stack[sp - 8'd1]) ?
                                stack[sp - 8'd2] : stack[sp - 8'd1];
                            stack_tag[sp - 8'd2] <= 3'd0;
                            sp <= sp - 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd14: begin // random 0..0 (int); LFSR bump
                            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
                            stack[sp] <= 32'sd0;
                            stack_tag[sp] <= 3'd0;
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd16, 8'd17, 8'd18: begin // getElementById / query / create → elem stub
                            sp <= sp - nat_argc[7:0];
                            stack[sp - nat_argc[7:0]] <= 32'sd0;
                            stack_tag[sp - nat_argc[7:0]] <= 3'd6;
                            sp <= sp - nat_argc[7:0] + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd19, 8'd20: begin // addEventListener
                            // last keydown wins (window handler after playerName);
                            // first click wins (start button before clearLB)
                            if (stack[sp - 8'd2][15:0] == id_keydown)
                                kd_fn <= stack[sp - 8'd1][15:0];
                            if (stack[sp - 8'd2][15:0] == id_keyup)
                                ku_fn <= stack[sp - 8'd1][15:0];
                            if (stack[sp - 8'd2][15:0] == id_click && click_fn == 16'hFFFF)
                                click_fn <= stack[sp - 8'd1][15:0];
                            sp <= sp - nat_argc[7:0];
                            stack[sp - nat_argc[7:0]] <= 32'sd0;
                            stack_tag[sp - nat_argc[7:0]] <= 3'd5;
                            sp <= sp - nat_argc[7:0] + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd25: begin // Date() stub — getTime via obj_cls magic (intern-miss safe)
                            obj_n[n_obj[10:0]] <= 0;
                            obj_cls[n_obj[10:0]] <= 16'hFFFD;
                            stack[sp] <= {16'd0, n_obj};
                            stack_tag[sp] <= 3'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd26: begin // Image() — stub size so onload scale is nonzero
                            obj_n[n_obj[10:0]] <= 5'd2;
                            obj_cls[n_obj[10:0]] <= 16'hFFC0;
                            obj_key[n_obj[10:0]][0] <= id_width;
                            obj_val[n_obj[10:0]][0] <= 32'sd300;
                            obj_tag[n_obj[10:0]][0] <= 3'd0;
                            obj_key[n_obj[10:0]][1] <= id_height;
                            obj_val[n_obj[10:0]][1] <= 32'sd200;
                            obj_tag[n_obj[10:0]][1] <= 3'd0;
                            stack[sp] <= {16'd0, n_obj};
                            stack_tag[sp] <= 3'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd27, 8'd28, 8'd29: begin // rAF / setTimeout / setInterval
                            if (raf_n < 4'd8 && nat_argc >= 8'd1) begin
                                raf_fn[raf_n] <= stack[sp - nat_argc[7:0]][15:0];
                                raf_n <= raf_n + 4'd1;
                            end
                            sp <= sp - nat_argc[7:0];
                            stack[sp - nat_argc[7:0]] <= 32'sd1;
                            stack_tag[sp - nat_argc[7:0]] <= 3'd0;
                            sp <= sp - nat_argc[7:0] + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        default: begin
                            sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            stack[sp] <= 32'sd0;
                            stack_tag[sp] <= 3'd5;
                            sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    endcase
                end
                S_CLEAR: begin
                    fb_we <= 1'b1;
                    fb_waddr <= clr_idx;
                    fb_wdata <= color;
                    if (clr_idx == 19'(FB_PIXELS - 1)) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else clr_idx <= clr_idx + 19'd1;
                end
                S_RECT: begin
                    if (rw == 10'd0 || rh == 10'd0) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        // Clip: never wrap out of FB (BOARD sparse-pixel bug)
                        if (x < 10'(MW) && y < 10'(MH)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(y) * 19'(MW) + 19'(x);
                            fb_wdata <= color;
                        end
                        if (x == (rx + rw - 10'd1)) begin
                            x <= rx;
                            if (y == (ry + rh - 10'd1)) begin
                                // draw into back; swap once at frame end (S_WAIT_FRAME)
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else y <= y + 10'd1;
                        end else x <= x + 10'd1;
                    end
                end
                S_CIRCLE: begin
                    // rx,ry center; rw radius; x,y walk bbox; path_stroke = outline
                    begin
                        logic signed [11:0] dx, dy;
                        logic [21:0] d2, r2, r2in;
                        dx = $signed({2'b0, x}) - $signed({2'b0, rx});
                        dy = $signed({2'b0, y}) - $signed({2'b0, ry});
                        d2 = 22'(dx * dx + dy * dy);
                        r2 = 22'(rw) * 22'(rw);
                        r2in = (rw <= 10'd1) ? 22'd0 : 22'(rw - 10'd1) * 22'(rw - 10'd1);
                        if (x < 10'(MW) && y < 10'(MH) && d2 <= r2 && (!path_stroke || d2 >= r2in)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(y) * 19'(MW) + 19'(x);
                            fb_wdata <= color;
                        end
                    end
                    if (x >= rx + rw || x == 10'(MW - 1)) begin
                        x <= clip_u($signed({22'd0, rx}) - $signed({22'd0, rw}), MW);
                        if (y >= ry + rw || y == 10'(MH - 1)) begin
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else y <= y + 10'd1;
                    end else x <= x + 10'd1;
                end
                S_LINE: begin
                    // Chebyshev walk (rx,ry) → (x,y) — maze stubs of ~10px
                    if (rx < 10'(MW) && ry < 10'(MH)) begin
                        fb_we <= 1'b1;
                        fb_waddr <= 19'(ry) * 19'(MW) + 19'(rx);
                        fb_wdata <= color;
                    end
                    if (rx == x && ry == y) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        if (rx < x) rx <= rx + 10'd1;
                        else if (rx > x) rx <= rx - 10'd1;
                        if (ry < y) ry <= ry + 10'd1;
                        else if (ry > y) ry <= ry - 10'd1;
                    end
                end
                S_BLIT: begin
                    if (rw == 10'd0 || rh == 10'd0) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        begin
                            logic [9:0] sx, sy;
                            logic [17:0] so;
                            logic [7:0] pix;
                            sx = blit_sx + ((blit_sw == 10'd0 || rw == 10'd0) ? 10'd0
                                 : 10'((32'(x) * 32'(blit_sw)) / 32'(rw)));
                            sy = blit_sy + ((blit_sh == 10'd0 || rh == 10'd0) ? 10'd0
                                 : 10'((32'(y) * 32'(blit_sh)) / 32'(rh)));
                            so = spr_off[blit_si[2:0]] + 18'(sy) * 18'(spr_ww[blit_si[2:0]]) + 18'(sx);
                            pix = spr_mem[so];
                            if (pix != 8'd0 && (rx + x) < 10'(MW) && (ry + y) < 10'(MH)) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(ry + y) * 19'(MW) + 19'(rx + x);
                                fb_wdata <= pix;
                            end
                        end
                        if (x == (rw - 10'd1)) begin
                            x <= 10'd0;
                            if (y == (rh - 10'd1)) begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else y <= y + 10'd1;
                        end else x <= x + 10'd1;
                    end
                end
                S_SPR: begin
                    // copy sprite pack from code_mem trailer bytes (trail_tb)
                    if (trail_off[1:0] == 2'd3) begin
                        code_raddr <= 15'(trail_off[16:2] + 15'd1);
                        trail_off <= trail_off + 16'd1;
                        state <= S_RD;
                        ret_state <= S_SPR;
                    end else begin
                        trail_off <= trail_off + 16'd1;
                        if (spr_left == 18'd0) begin
                            // header w/h via spr_hdr 0..3
                            if (spr_hdr == 3'd0) begin
                                trail_acc[7:0] <= trail_tb;
                                spr_hdr <= 3'd1;
                            end else if (spr_hdr == 3'd1) begin
                                spr_ww[spr_i[2:0]] <= {trail_tb, trail_acc[7:0]}[9:0];
                                spr_hdr <= 3'd2;
                            end else if (spr_hdr == 3'd2) begin
                                trail_acc[7:0] <= trail_tb;
                                spr_hdr <= 3'd3;
                            end else begin
                                spr_hh[spr_i[2:0]] <= {trail_tb, trail_acc[7:0]}[9:0];
                                spr_off[spr_i[2:0]] <= spr_wp;
                                spr_left <= 18'({trail_tb, trail_acc[7:0]}[9:0]) * 18'(spr_ww[spr_i[2:0]]);
                                spr_hdr <= 3'd0;
                                if (18'({trail_tb, trail_acc[7:0]}[9:0]) * 18'(spr_ww[spr_i[2:0]]) == 18'd0) begin
                                    if (spr_i + 4'd1 >= n_spr) begin
                                        code_raddr <= 15'(ops_base);
                                        state <= S_FETCH_WAIT;
                                    end else spr_i <= spr_i + 4'd1;
                                end
                            end
                        end else begin
                            if (spr_wp < 18'(SPR_BYTES))
                                spr_mem[spr_wp] <= trail_tb;
                            spr_wp <= spr_wp + 18'd1;
                            spr_left <= spr_left - 18'd1;
                            if (spr_left == 18'd1) begin
                                if (spr_i + 4'd1 >= n_spr) begin
                                    code_raddr <= 15'(ops_base);
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    spr_i <= spr_i + 4'd1;
                                    spr_hdr <= 3'd0;
                                end
                            end
                        end
                    end
                end
                // NEW: ALU result into alu_r (no stack write this cycle)
                S_ALU: begin
                    unique case (alu_op)
                        3'd0: alu_r <= alu_a + alu_b;
                        3'd1: alu_r <= alu_a - alu_b;
                        3'd2: alu_r <= (alu_a < alu_b) ? 32'sd1 : 32'sd0;
                        3'd3: alu_r <= (alu_a > alu_b) ? 32'sd1 : 32'sd0;
                        3'd4: alu_r <= (alu_a == alu_b) ? 32'sd1 : 32'sd0;
                        3'd5: alu_r <= -alu_a;
                        3'd6: alu_r <= (alu_a == 0) ? 32'sd1 : 32'sd0;
                        default: alu_r <= 32'sd0;
                    endcase
                    state <= S_ALU_WR;
                end
                // NEW: stack write from alu_r — binary ops already did sp--
                S_ALU_WR: begin
                    stack[sp - 8'd1] <= alu_r;
                    stack_tag[sp - 8'd1] <= 3'd0; // EQ/ADD result is i32, not leftover str/obj tag
                    next_op();
                end
                // NEW: DSP multiply into mul_prod only (no stack write this cycle)
                S_MUL: begin
                    mul_prod <= mul_a * mul_b;
                    state <= S_MUL_WR;
                end
                // NEW: stack write from registered product — closes −0.183 ns WNS
                S_MUL_WR: begin
                    stack[sp - 8'd2] <= mul_prod;
                    sp <= sp - 8'd1;
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
                    stack[sp - 8'd2] <= div_neg ? -$signed(div_uq) : $signed(div_uq);
                    sp <= sp - 8'd1;
                    next_op();
                end
                S_FOREACH: begin
                    // NEW: drain arr.forEach(fn) using frame at csp-1
                    if (csp == 0) begin
                        state <= S_WAIT_FRAME;
                    end else if (cstack_fe_i[csp - 7'd1] >= arr_len[cstack_fe_arr[csp - 7'd1][7:0]]) begin
                        stack[sp] <= 32'sd0;
                        stack_tag[sp] <= 3'd5;
                        sp <= sp + 8'd1;
                        ip <= cstack_ip[csp - 7'd1];
                        this_obj <= cstack_this[csp - 7'd1];
                        csp <= csp - 7'd1;
                        code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd1]);
                        state <= S_FETCH_WAIT;
                    end else begin
                        // bind nparam args: el, then idx if the callback asked for it
                        stack[sp] <= arr_val[cstack_fe_arr[csp - 7'd1][7:0]][cstack_fe_i[csp - 7'd1][6:0]];
                        stack_tag[sp] <= arr_tag[cstack_fe_arr[csp - 7'd1][7:0]][cstack_fe_i[csp - 7'd1][6:0]];
                        if (cstack_ctorobj[csp - 7'd1][7:0] >= 8'd2) begin
                            stack[sp + 8'd1] <= {24'd0, cstack_fe_i[csp - 7'd1]};
                            stack_tag[sp + 8'd1] <= 3'd0;
                            sp <= sp + 8'd2;
                        end else
                            sp <= sp + 8'd1;
                        cstack_ip[csp] <= 16'hFFFE;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        ip <= cstack_fe_fn[csp - 7'd1];
                        code_raddr <= 15'(ops_base + cstack_fe_fn[csp - 7'd1]);
                        state <= S_FETCH_WAIT;
                    end
                end
                S_WAIT_FRAME: if (frame_tick) begin
                    prev_joy <= joy_in;
                    // KEYBITS level → keys.a/d/space.pressed (HTML table the animate() reads)
                    if (keys_ok) begin
                        poke_pressed(id_a, joy_in[2]);
                        poke_pressed(id_d, joy_in[3]);
                        poke_pressed(id_kspace, joy_in[4]);
                    end
                    if (enter_n != 0 && enter_delay != 0)
                        enter_delay <= enter_delay - 4'd1;
                    // KEYBITS edges → keydown/keyup with event.key + keyCode (HTML bindings)
                    if (kd_fn != 16'hFFFF && (joy_in & ~prev_joy) != 0) begin
                        obj_n[n_obj[10:0]] <= 6'd2;
                        obj_cls[n_obj[10:0]] <= 0;
                        obj_key[n_obj[10:0]][0] <= id_key;
                        obj_val[n_obj[10:0]][0] <= {16'd0,
                            joy_in[2] ? id_arrow_l : joy_in[3] ? id_arrow_r :
                            joy_in[4] ? id_space : id_arrow_l};
                        obj_tag[n_obj[10:0]][0] <= 3'd3;
                        obj_key[n_obj[10:0]][1] <= id_keycode;
                        obj_val[n_obj[10:0]][1] <= joy_in[2] ? 32'sd37 : joy_in[3] ? 32'sd39 :
                            joy_in[4] ? 32'sd32 : joy_in[0] ? 32'sd38 : 32'sd40;
                        obj_tag[n_obj[10:0]][1] <= 3'd0;
                        stack[sp] <= {16'd0, n_obj};
                        stack_tag[sp] <= 3'd1;
                        sp <= sp + 8'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                        ip <= kd_fn;
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + kd_fn);
                        state <= S_FETCH_WAIT;
                    end else if (ku_fn != 16'hFFFF && (prev_joy & ~joy_in) != 0) begin
                        obj_n[n_obj[10:0]] <= 6'd2;
                        obj_key[n_obj[10:0]][0] <= id_key;
                        obj_val[n_obj[10:0]][0] <= {16'd0,
                            prev_joy[2] ? id_arrow_l : prev_joy[3] ? id_arrow_r :
                            prev_joy[4] ? id_space : id_arrow_l};
                        obj_tag[n_obj[10:0]][0] <= 3'd3;
                        obj_key[n_obj[10:0]][1] <= id_keycode;
                        obj_val[n_obj[10:0]][1] <= prev_joy[2] ? 32'sd37 : prev_joy[3] ? 32'sd39 :
                            prev_joy[4] ? 32'sd32 : 32'sd38;
                        obj_tag[n_obj[10:0]][1] <= 3'd0;
                        stack[sp] <= {16'd0, n_obj};
                        stack_tag[sp] <= 3'd1;
                        sp <= sp + 8'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                        ip <= ku_fn;
                        cstack_ip[csp] <= n_ops;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + ku_fn);
                        state <= S_FETCH_WAIT;
                    end else if (raf_n != 0 && !pre_click_raf) begin
                        // one rAF first (Image.onload) so player.image is set
                        pre_click_raf <= 1'b1;
                        ip <= raf_fn[0];
                        raf_n <= raf_n - 4'd1;
                        raf_fn[0] <= raf_fn[1];
                        raf_fn[1] <= raf_fn[2];
                        raf_fn[2] <= raf_fn[3];
                        raf_fn[3] <= raf_fn[4];
                        raf_fn[4] <= raf_fn[5];
                        raf_fn[5] <= raf_fn[6];
                        raf_fn[6] <= raf_fn[7];
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + raf_fn[0]);
                        state <= S_FETCH_WAIT;
                    end else if (click_fn != 16'hFFFF && !click_fired) begin
                        // HTML auto-start: idle animate re-queues rAF so click never drained
                        click_fired <= 1'b1;
                        ip <= click_fn;
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + click_fn);
                        state <= S_FETCH_WAIT;
                    end else if (enter_n != 0 && kd_fn != 16'hFFFF && pre_click_raf &&
                                enter_delay == 4'd0) begin
                        // DONKEY/PACMAN title: synthetic Enter (PYTHON _enter_left)
                        enter_n <= enter_n - 3'd1;
                        enter_delay <= 4'd8;
                        obj_n[n_obj[10:0]] <= 6'd2;
                        obj_cls[n_obj[10:0]] <= 0;
                        obj_key[n_obj[10:0]][0] <= id_key;
                        obj_val[n_obj[10:0]][0] <= {16'd0, id_enter};
                        obj_tag[n_obj[10:0]][0] <= 3'd3;
                        obj_key[n_obj[10:0]][1] <= id_keycode;
                        obj_val[n_obj[10:0]][1] <= 32'sd13;
                        obj_tag[n_obj[10:0]][1] <= 3'd0;
                        stack[sp] <= {16'd0, n_obj};
                        stack_tag[sp] <= 3'd1;
                        sp <= sp + 8'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? 16'd1024 : (n_obj + 16'd1);
                        ip <= kd_fn;
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + kd_fn);
                        state <= S_FETCH_WAIT;
                    end else if (raf_n != 0) begin
                        ip <= raf_fn[0];
                        raf_n <= raf_n - 4'd1;
                        raf_fn[0] <= raf_fn[1];
                        raf_fn[1] <= raf_fn[2];
                        raf_fn[2] <= raf_fn[3];
                        raf_fn[3] <= raf_fn[4];
                        raf_fn[4] <= raf_fn[5];
                        raf_fn[5] <= raf_fn[6];
                        raf_fn[6] <= raf_fn[7];
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + raf_fn[0]);
                        state <= S_FETCH_WAIT;
                    end else if (looping) begin
                        ip <= '0;
                        sp <= '0;
                        code_raddr <= 15'(ops_base);
                        state <= S_FETCH_WAIT;
                    end else begin
                        ip <= n_ops;
                        code_raddr <= 15'(ops_base);
                        state <= S_FETCH_WAIT;
                    end
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
