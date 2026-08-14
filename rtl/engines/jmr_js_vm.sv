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
    // NEW: raw host keyboard events (GUI/board PS/2) — the HTML decides
    // bindings; no hardcoded key maps here (replaces the synthetic-Enter hack)
    input  logic        key_evt_stb,
    input  logic [7:0]  key_evt_code,
    input  logic        key_evt_down,
    // NEW: console loads NAME.JSB into code BRAM before start
    input  logic        code_we,
    input  logic [14:0] code_waddr,
    input  logic [31:0] code_wdata,
    output logic        busy,
    output logic        done,
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap,
    // NEW: getImageData reads the back bank (FM _nat_get_image_data twin).
    // Muxed onto mini_fb dump_raddr; dump_back is the non-front bank.
    output logic [18:0] fb_dump_addr,
    output logic        fb_dump_sel,
    input  logic [7:0]  fb_dump_back,
    // NEW: external asset SRAM read port (jmr_sram_port master, read-only) —
    // ASET sprite banks live there; blitter fetches pixels 2-per-16-bit word
    output logic        sram_req,
    output logic [20:0] sram_addr,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack
);
    localparam int CODE_WORDS = 32768;
    localparam int MAX_CONSTS = 1024;
    localparam int MAX_VARS   = 512;
    localparam int STACK_DEPTH = 2048; // PACMAN.HTML maze literals: FM peak 969
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
    logic signed [31:0] vars   [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic               var_init [0:MAX_VARS-1];
    logic signed [31:0] stack  [0:STACK_DEPTH-1];
    // NEW: public for the sim server VMSTAT? probe (FPGA-SIM bring-up only)
    logic [10:0] sp /*verilator public_flat_rd*/; // 2048-deep eval stack
    logic [15:0] ip /*verilator public_flat_rd*/;
    logic [15:0] n_ops, n_consts, ops_base, jsb_flags;
    logic        looping, running;
    // NEW: tagged stack/vars for HTML heap (0=int 1=obj 2=arr 3=str 4=fn 5=undef 6=elem)
    logic [2:0]  stack_tag [0:STACK_DEPTH-1];
    logic [2:0]  var_tag   [0:MAX_VARS-1];
    // NEW: INVADERS.HTML boot alone allocates ~1.8K objects (VMSTAT audit) —
    // grow the VM, never the games. Temporaries recycle in the upper ring.
    localparam int MAX_OBJ = 8192;
    localparam int OBJ_RING = MAX_OBJ / 2; // wrap point: boot heap stays below
    localparam int OBJ_SLOTS = 32; // PACMAN Item.assign copies ~20 settings onto this
    localparam int MAX_ARR = 4096;
    localparam int ARR_RING = MAX_ARR / 2;
    // NEW: per-call lexical env (FM bytecode.py env dict). LIFO frames;
    // MAKE_FN snapshots the current frame onto the Fn heap object so
    // setTimeout/rAF closures keep forEach params after the call returns.
    localparam int ENV_DEPTH = 32;
    localparam int ENV_SLOTS = 16;
    localparam logic [15:0] CLS_FN = 16'hFFEF;
    localparam logic [15:0] CLS_REGEX = 16'hFFEE;  // packed pattern+flags in slot0
    localparam logic [15:0] CLS_DYNSTR = 16'hFFED; // JSON/replace text in json_mem
    localparam logic [15:0] CLS_IMGD = 16'hFFEC;   // one ImageData snapshot (VM cap)
    localparam logic [15:0] CLS_ENV = 16'hFFEA;    // live lexical env (FM env dict)
    localparam int JSON_CAP = 8192; // VM-capped scratch; loud overflow, not title-sized
    localparam int JSON_STK = 32;
    localparam int ARR_CAP = 128;
    localparam int ARR_KEEP_DELAY = 8; // boot rAF/click/nextStage before nursery
    localparam int MAX_CLS = 16;
    localparam int MAX_CMETH = 16;
    localparam int CSTK = 128;
    logic [15:0] n_obj /*verilator public_flat_rd*/, n_arr /*verilator public_flat_rd*/;
    logic [15:0] n_arr_keep;
    logic        arr_keep_ok;
    logic [3:0]  arr_keep_wait;
    // NEW: per-frame object bump rewind (call envs / temps). Same policy as
    // arrays: do not wrap live slots; commit keep when a nursery obj/fn is
    // stored into the pre-frame heap or a timer/rAF queue.
    logic [15:0] n_obj_keep;
    logic        obj_keep_ok;
    logic [3:0]  obj_keep_wait;
    logic        frame_fire; // NEW: fire rAF/keys the cycle after obj rewind
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
    logic [15:0] cstack_map_arr [0:CSTK-1]; // FFFF=forEach; else dest arr for map
    logic [5:0]  cstack_env [0:CSTK-1]; // NEW: saved env_sp
    logic [6:0]  csp;
    logic [5:0]  env_sp; // 0 = top-level (vars[] only)
    logic [15:0] env_oid [0:ENV_DEPTH-1]; // NEW: live heap env objects (not value snapshots)
    logic        env_cap [0:ENV_DEPTH-1]; // NEW: MAKE_FN captured this frame
    logic [15:0] env_free [0:ENV_DEPTH-1]; // NEW: recycled uncaptured env oids
    logic [5:0]  env_free_n;
    logic [15:0] env_walk; // heap env object id (parent chain)
    logic [8:0]  env_ld_slot;
    logic        env_is_store;
    logic [15:0] dbg_heap_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_to_ovf /*verilator public_flat_rd*/;
    logic [15:0] to_fn [0:7]; // NEW: setTimeout/setInterval queue (Fn obj idx)
    logic [3:0]  to_n;
    logic [11:0] to_delay [0:7]; // remaining frames (delay_ms/17)
    logic [11:0] to_period [0:7]; // 0 = one-shot; else interval re-arm
    logic [15:0] to_id [0:7];
    logic [15:0] to_seq;
    logic [15:0] id_replace;
    // NEW: JSON/text scratch (stringify/parse/replace) — VM cap, sticky ovf
    logic [7:0]  json_mem [0:JSON_CAP-1];
    logic [13:0] json_wp, json_rp, json_src, json_srclen, json_dst;
    logic [15:0] dbg_json_ovf /*verilator public_flat_rd*/;
    logic [2:0]  js_tag [0:JSON_STK-1];
    logic [31:0] js_val [0:JSON_STK-1];
    logic [7:0]  js_i   [0:JSON_STK-1];
    logic [2:0]  js_ph  [0:JSON_STK-1];
    logic [5:0]  js_sp;
    logic [10:0] json_res;
    logic [2:0]  json_pph; // parse substate (0=value 3=number 7=skipstr)
    logic signed [31:0] json_num;
    logic        json_neg;
    logic [7:0]  json_digs [0:9];
    logic [3:0]  json_dn, json_di;
    logic [7:0]  repl_pat0, repl_pat1, repl_nlen, repl_rch;
    logic        repl_g, repl_did;
    logic [13:0] idx_off;
    logic [7:0]  idx_needle;
    // NEW: one ImageData snapshot (FM canvas.back copy). VM cap = 1 buffer.
    logic [7:0]  imgd_pix [0:FB_PIXELS-1];
    logic [18:0] imgd_i, imgd_n;
    logic [9:0]  imgd_x0, imgd_y0, imgd_w, imgd_h, imgd_x, imgd_y;
    logic        imgd_armed;
    logic [10:0] imgd_res;
    logic [15:0] this_obj;
    logic [8:0]  var_this;   // NEW: LOAD_VAR slot for __this
    logic        this_ok;
    logic [15:0] raf_fn [0:7];
    logic [3:0]  raf_n /*verilator public_flat_rd*/;
    logic [15:0] kd_fn /*verilator public_flat_rd*/, ku_fn, click_fn; // interned MAKE_FN entries; 0xFFFF=none
    // NEW: keydown/keyup listener table (4 slots, fire all; last-wins was a parity gap)
    logic [15:0] kd_slot [0:3], ku_slot [0:3];
    logic [2:0]  kd_n, ku_n;
    logic [1:0]  kev_li;   // which table slot is firing
    logic [15:0] kev_obj;  // event object reused for remaining listeners
    logic        kev_is_down;
    logic [15:0] kev_ret_ip; // after listener table: next op (dispatchEvent) or n_ops (KEYEVT)
    logic        boot_clr; // NEW: clear both FB banks before first op
    logic [1:0]  boot_clr_n;
    logic [15:0] id_find; // Array.find
    logic        click_fired; // NEW: HTML auto-start click once
    logic        pre_click_raf; // NEW: one rAF (Image.onload) before click
    logic [5:0]  prev_joy;
    logic [7:0]  fill_style_i;
    logic [31:0] lfsr;
    logic [15:0] id_fillrect, id_length, id_push, id_splice, id_foreach;
    logic [15:0] id_map, id_unshift; // Array.map / Array.unshift
    logic [15:0] id_getctx, id_click, id_ael, id_key, id_keycode;
    logic [15:0] id_rel, id_disp; // removeEventListener / dispatchEvent
    logic [15:0] id_document, id_window; // seed vars so `if (document.dispatchEvent)` is truthy
    logic [15:0] id_arrow_l, id_arrow_r, id_space, id_a, id_d, id_keydown, id_keyup;
    logic [15:0] id_reduce, id_draw, id_update, id_fillstyle, id_clearrect, id_drawimage;
    logic [15:0] id_this_name, id_black, id_white, id_red, id_yellow, id_cyan, id_gold;
    logic [15:0] id_src, id_onload, id_width, id_height;
    logic [15:0] id_hex_fff, id_hex_3f6, id_hex_f5a, id_hex_fc0, id_hex_2ec, id_hex_000;
    logic [15:0] id_save, id_restore, id_translate, id_rotate;
    logic [15:0] id_settransform; // NEW: ctx.setTransform(a,b,c,d,e,f)
    logic [15:0] id_assign, id_bind, id_proto, id_filltext, id_arc, id_enter;
    // NEW: DOM event ctors — PYTHON NEW_OBJ copies (type, options) so
    // `new KeyboardEvent("keydown", {key:"Enter",...})` has e.key (DONKEY boot)
    logic [15:0] id_kbevent, id_domevent, id_customev, id_mouseev, id_type;
    logic [15:0] id_now, id_gettime;
    logic [15:0] id_beginpath, id_fill, id_stroke, id_moveto, id_lineto, id_closepath, id_strokestyle;
    logic [15:0] id_quadcurve; // NEW: ctx.quadraticCurveTo (PACMAN maze/ghost skirts)
    // NEW: getImageData/putImageData — must NOT hit the fillRect argc-4
    // fallback (getImageData(0,0,640,480) painted a full-screen rect with the
    // stale wall strokeStyle: the PACMAN purple flood)
    logic [15:0] id_getimgdata, id_putimgdata;
    // NEW: Math.sqrt bit-serial regs — radicand Q32.32-ish (val<<16), 24-bit root
    logic [47:0] sq_rad;
    logic [25:0] sq_rem;
    logic [23:0] sq_root;
    logic [4:0]  sq_i;
    // NEW: Array.join('') + indexOf — PACMAN maze wall-shape switch does
    // neighbors.join('') == '1100'. join hashes the digits with the SAME
    // u16 hash the encoder used, then maps back to an interned name so
    // string EQ (intern id compare) just works. No dynamic string heap.
    logic [15:0] id_join, id_indexof;
    logic [15:0] name_hash_tbl [0:1023]; // intern idx -> encoder u16 hash
    logic [7:0]  name_len_tbl  [0:1023]; // intern idx -> byte length (concat fold)
    logic [15:0] names_n;
    logic [11:0]  jn_arr;
    logic [15:0] jn_i, jn_h;
    logic [7:0]  jn_len;
    logic [10:0] jn_res;
    logic signed [31:0] idx_v;
    logic [2:0]  idx_t;
    logic [15:0] dbg_join_miss /*verilator public_flat_rd*/; // unsupported join/indexOf shapes
    // NEW: path bring-up latch — first 16 transformed S_PDO commands
    logic [79:0] dbg_pdo [0:15] /*verilator public_flat_rd*/;
    logic [4:0]  dbg_pdo_n /*verilator public_flat_rw*/; // rw: probe re-arms it
    // NEW: rect bring-up latch — {color, rx, ry, rw, rh} of first 16 rects
    logic [47:0] dbg_rect [0:15] /*verilator public_flat_rd*/;
    logic [4:0]  dbg_rect_n /*verilator public_flat_rw*/;
    logic [15:0] dbg_swap_n /*verilator public_flat_rd*/; // presents since RUN
    // NEW: raster px counters (flood hunt) — cleared by PDOCLR
    logic [31:0] dbg_line_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_circ_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_rect_px /*verilator public_flat_rw*/;
    // NEW: string concat ('s'+_index etc.) — operand stash + digit fold
    logic signed [31:0] cc_av, cc_bv, cc_v;
    logic [2:0]  cc_at, cc_bt, cc_t;
    logic        cc_second, cc_st;
    logic [15:0] cc_h;
    logic [7:0]  cc_len;
    logic [3:0]  cc_pi, cc_d;
    logic [15:0] pow31_tbl [0:255]; // 31^i mod 2^16 (concat hash fold)
    initial begin
        pow31_tbl[0] = 16'd1;
        for (int i = 1; i < 256; i++)
            pow31_tbl[i] = 16'(32'(pow31_tbl[i - 1]) * 32'd31);
    end
    localparam int unsigned P10 [0:9] = '{1, 10, 100, 1000, 10000, 100000,
                                          1000000, 10000000, 100000000, 1000000000};
    logic [15:0] id_hex_09f, id_hex_f5f5, id_hex_ffe6, id_hex_f00, id_hex_aaa;
    logic [15:0] spr_nid [0:15] /*verilator public_flat_rd*/; // intern idx of "jmr:spr:0"..15
    // NEW: FSTY fillStyle LUT — compiler-resolved name→palette index so RTL
    // paints the exact indices the FM does (0xFF = not a color, use fallback)
    logic [7:0]  fill_lut [0:1023];
    logic [15:0] fsty_n, fsty_name;
    // NEW: pass called swapBuffers explicitly (legacy .JS) — no auto-swap
    logic        did_swap;
    // NEW: bring-up probes — drawImage sprite-marker hits vs misses
    logic [15:0] dbg_di_hit /*verilator public_flat_rd*/, dbg_di_miss /*verilator public_flat_rd*/;
    logic [1:0]  path_kind; // 0 none 1 arc 2 moveto 3 lineto
    logic signed [31:0] path_x0, path_y0, path_x1, path_y1, path_r;
    logic        path_stroke;
    // NEW: multi-command path buffer (FM bytecode.py obj["_path"] twin) —
    // raw Q16.16 args recorded at dispatch, _xf transform applied at
    // fill()/stroke() raster time exactly like machine.py _raster_path.
    localparam int PATH_MAX = 16;
    logic [1:0]         pc_op  [0:PATH_MAX-1]; // 0=M 1=L 2=Q 3=A
    logic signed [31:0] pc_a1  [0:PATH_MAX-1]; // x | cx
    logic signed [31:0] pc_a2  [0:PATH_MAX-1]; // y | cy
    logic signed [31:0] pc_a3  [0:PATH_MAX-1]; // r | end x
    logic signed [31:0] pc_a4  [0:PATH_MAX-1]; // arc a0 | end y
    logic signed [31:0] pc_a5  [0:PATH_MAX-1]; // arc a1
    logic               pc_ccw [0:PATH_MAX-1];
    logic [4:0]         pc_n, pi;
    logic [15:0]        dbg_path_ovf /*verilator public_flat_rd*/; // fail-visible overflow
    logic               path_active;            // raster states return to S_PWALK
    // walk scratch (device-space ints after _xf)
    logic signed [31:0] cur_x, cur_y, p1x, p1y, p2x, p2y;
    // quadratic subdivision (FM: 8 line segments)
    logic signed [31:0] qx0, qy0, qcx, qcy, qex, qey;
    logic signed [31:0] qk1, qk2, qk3;          // u^2, u*t, t^2 (Q16.16)
    logic [3:0]         qseg;
    // arc angle sweep (per-pixel cross-product test replaces FM atan2)
    logic               arc_ang, arc_sweep_gt_pi;
    logic signed [16:0] vs_x, vs_y, ve_x, ve_y; // Q1.15 sector edge vectors
    // signed Bresenham line (FM machine._line twin)
    logic signed [15:0] bl_x, bl_y, bl_x1, bl_y1;
    logic signed [16:0] bl_dx, bl_dy;           // dx, -dy (FM err terms)
    logic               bl_sx, bl_sy;
    logic signed [17:0] bl_err;
    logic [12:0]        bl_guard;
    localparam logic signed [31:0] FX_2PI = 32'sd411775; // 2*pi Q16.16
    localparam logic signed [31:0] FX_PI  = 32'sd205887;
    // quarter-wave sine ROM, 256 x Q1.15 (sin_q[i] = sin(i/256 * pi/2))
    logic [15:0] sin_q [0:255];
    localparam int SPR_BYTES = 262144;
    // NEW: 16 ASET sprite descriptors (was 8 — silently dropped DONKEY sheets
    // beyond the clamp). obj_cls FFC0|idx encoding carries a 4-bit index;
    // compile_js.py fails loud if a title ever exceeds this.
    localparam int MAX_SPR = 16;
    localparam logic signed [31:0] FX_ONE = 32'sh0001_0000; // Q16.16 1.0
    (* ram_style = "block" *) logic [7:0] spr_mem [0:SPR_BYTES-1];
    // NEW: ASET sprites live in the 4 MB asset SRAM — offsets are 22-bit byte
    // addresses in the payload; DONKEY sheets are 1470×750 so w/h are u16.
    logic [21:0] spr_off [0:MAX_SPR-1];
    logic [15:0] spr_ww [0:MAX_SPR-1];
    logic [15:0] spr_hh [0:MAX_SPR-1];
    logic [4:0]  n_spr /*verilator public_flat_rd*/, spr_i; // NEW: 5-bit for 16 sprites
    logic [2:0]  spr_hdr;
    logic [17:0] spr_wp, spr_left;
    logic [7:0]  blit_si;
    logic [15:0] blit_sx, blit_sy, blit_sw, blit_sh;
    logic        aset_mode;   // NEW: header flags bit1 — sprites in asset SRAM
    logic        sprd_mode;   // NEW: trailer carries SPRD descriptors (no pixels)
    logic        blit_wait;   // NEW: SRAM read handshake inside S_BLIT
    logic [15:0] hdr_w;       // NEW: header words (3, or 4 when ASET off present)
    logic [31:0] time_ms; // PACMAN Date.now / getTime — must advance or start() skips draw
    localparam int MAX_FN_PROTO = 64;
    logic [15:0] fn_proto_ip [0:MAX_FN_PROTO-1];
    logic [15:0] fn_proto_oid [0:MAX_FN_PROTO-1];
    logic [6:0]  n_fn_proto;
    logic [8:0]  intern_var [0:1023];
    logic        intern_var_ok [0:1023];
    logic [2:0]  enter_n;
    logic [3:0]  enter_delay;
    // NEW: raw key-event FIFO (host → keydown/keyup dispatch, one per frame)
    logic [8:0]  kev_q [0:7]; // {down, keyCode}
    logic [2:0]  kev_wp, kev_rp;
    logic [15:0] kev_fn; // handler for S_KEYEV (event alloc + env must be 2-cycle)
    logic [15:0] id_keys_name, id_pressed, id_kspace; // keys.a.pressed table
    logic [8:0]  var_keys;
    logic        keys_ok;
    logic [15:0] keys_a_oid, keys_d_oid, keys_sp_oid;
    // NEW: canvas 2d translate so Player.drawImage(-w/2,-h/2) lands on position
    logic signed [31:0] ctx_tx, ctx_ty, saved_tx, saved_ty;
    // NEW: setTransform axis scale (Q16.16) — FM machine.py _xf spec:
    // ix=int(x*sx+tx), iw=max(1,int(w*sx)) (DONKEY world 1510x685 → glass)
    logic signed [31:0] ctx_sx, ctx_sy, saved_sx, saved_sy;
    // scaled-draw pipeline: latch raw args, multiply, then enter draw state
    logic signed [31:0] xf_x, xf_y, xf_w, xf_h;     // Q16.16 raw args
    logic signed [63:0] xfp_x, xfp_y, xfp_w, xfp_h; // Q32.32 products
    logic [1:0]         xf_dst; // 0=S_RECT 1=S_BLIT 2=fillText S_RECT
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
        // NEW: scaled-draw transform (setTransform sx/sy != 1): registered
        // multiply cycle then apply/clip cycle — keeps DSP mults off the
        // single-cycle dispatch path (same reason as S_MUL)
        S_XF_MUL, S_XF_APPLY,
        // NEW: path raster walk (FM _raster_path twin): per-command transform
        // then line / quadratic-subdivision / angular-arc raster
        S_PWALK, S_PDO, S_QSEG, S_QPX, S_QPY,
        // NEW: array natives — join('') digit-hash + reverse intern scan,
        // linear indexOf (PACMAN maze wall-shape switch); string concat fold
        S_JOIN, S_JOIN_FIND, S_IDXOF, S_CONCAT,
        S_SQRT, // NEW: Math.sqrt bit-serial (PACMAN position2coord offset)
        // NEW: multi-cycle divide — single-cycle 32-bit '/' was the −90 ns WNS
        // critical path on the board (337 logic levels / 300 CARRY4).
        S_DIV, S_DIV_FIN,
        // NEW: 3-cycle multiply — latch ops → DSP into mul_prod → stack write.
        // Prior "2-cycle" still did mul_a*mul_b into stack same clock (WNS −0.183).
        S_MUL, S_MUL_WR,
        // NEW: binop/compare/neg — compute alu_r then write stack (sp→ALU→stack was −0.6 ns)
        S_ALU, S_ALU_WR,
        S_CALL, S_FOREACH, S_KEYEV, S_ENV_LOAD,
        // NEW: JSON.stringify/parse + String.replace/indexOf on dyn strings
        S_JSON, S_JSON_PARSE, S_REPL, S_IDXSTR,
        // NEW: Canvas ImageData snapshot (one buffer, FM twin)
        S_IMGD_GET, S_IMGD_PUT
    } st_t;
    st_t state /*verilator public_flat_rd*/, ret_state;

    logic [15:0] c_i;
    // NEW: 10-bit coords for 640×480 (was 8-bit mini after scale4)
    logic [9:0]  rx, ry, rw, rh, x, y;
    logic [7:0]  color;
    logic [18:0] clr_idx;
    logic [7:0]  nat_id, nat_argc;
    logic signed [31:0] a_s, b_s;

    // NEW: registered multiply operands + product (break DSP→stack path).
    // 64-bit product: fx×fx needs the >>16 correction (Q16.16 renormalize).
    logic signed [31:0] mul_a, mul_b;
    logic signed [63:0] mul_prod;

    // NEW: ALU pipeline for ADD/SUB/LT/GT/EQ/NEG/NOT
    logic signed [31:0] alu_a, alu_b, alu_r;
    logic [2:0] alu_op;  // 0 ADD 1 SUB 2 LT 3 GT 4 EQ 5 NEG 6 NOT
    // NEW: Q16.16 mixed arithmetic — operands lifted to fx when either is fx;
    // ADD/SUB/NEG results stay fx, compares are plain ints.
    logic        alu_fx;
    logic        mul_fx_a, mul_fx_b;
    logic        div_int_in;   // both DIV inputs were ints (exact → int result)

    // NEW: restoring-divider state (48 cycles @ core clk) — dividend is
    // |N| << 16 so the quotient lands in Q16.16 (truncate toward zero, /0 → 0)
    logic [47:0] div_uq;   // shifting dividend, becomes |quotient| (Q16.16)
    logic [31:0] div_ub;   // |divisor|
    logic [31:0] div_rem;  // partial remainder
    logic [5:0]  div_cnt;
    logic        div_neg;  // result sign
    logic [32:0] div_rnext;
    assign div_rnext = {div_rem, div_uq[47]};

    assign busy = running;
    assign done = (state == S_DONE);

    function automatic logic [7:0] sat8(input logic signed [31:0] v);
        if (v < 0) sat8 = 8'd0;
        else if (v > 255) sat8 = 8'd255;
        else sat8 = 8'(v);
    endfunction
    // NEW: Fn heap object slot0 = entry ip (tag-4 stack value is the obj idx)
    function automatic logic [15:0] fn_entry(input logic [15:0] oid);
        fn_entry = obj_val[oid[12:0]][0][15:0];
    endfunction
    function automatic logic [7:0] fn_nparam(input logic [15:0] oid);
        fn_nparam = obj_val[oid[12:0]][1][7:0];
    endfunction
    // NEW: live heap env (FM env dict). Parent oid in slot0.
    task automatic push_fresh_env(input logic [15:0] parent);
        logic [15:0] oid;
        if (env_sp < ENV_DEPTH[5:0]) begin
            if (env_free_n != 6'd0) begin
                oid = env_free[env_free_n - 6'd1];
                env_free_n <= env_free_n - 6'd1;
            end else begin
                oid = n_obj;
                if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
            end
            obj_cls[oid[12:0]] <= CLS_ENV;
            obj_n[oid[12:0]] <= 6'd1;
            obj_key[oid[12:0]][0] <= 16'd0;
            obj_val[oid[12:0]][0] <= {16'd0, parent};
            obj_tag[oid[12:0]][0] <= 3'd0;
            env_oid[env_sp] <= oid;
            env_cap[env_sp] <= 1'b0;
            env_sp <= env_sp + 6'd1;
        end
    endtask
    // NEW: restore captured env from a MAKE_FN heap object (timers / rAF / meth).
    // Fresh call env whose parent is the captured env object
    // (FM call_fn env={__par: fn.env}). STORE walks the parent chain.
    task automatic enter_captured_fn(input logic [15:0] foid);
        logic [12:0] fo;
        logic [15:0] parent;
        fo = foid[12:0];
        parent = (obj_n[fo] > 6'd2) ? obj_val[fo][2][15:0] : 16'd0;
        cstack_env[csp] <= env_sp;
        push_fresh_env(parent);
    endtask
    // NEW: keydown/keyup listener table (4 slots; same (type,fn) registers once)
    task automatic add_key_listener(input logic is_down, input logic [15:0] fn);
        integer i;
        logic dup;
        dup = 1'b0;
        if (is_down) begin
            for (i = 0; i < 4; i++)
                if (i < kd_n && kd_slot[i] == fn) dup = 1'b1;
            if (!dup && kd_n < 3'd4) begin
                kd_slot[kd_n] <= fn;
                kd_n <= kd_n + 3'd1;
            end
        end else begin
            for (i = 0; i < 4; i++)
                if (i < ku_n && ku_slot[i] == fn) dup = 1'b1;
            if (!dup && ku_n < 3'd4) begin
                ku_slot[ku_n] <= fn;
                ku_n <= ku_n + 3'd1;
            end
        end
    endtask
    task automatic remove_key_listener(input logic is_down, input logic [15:0] fn);
        integer i, j;
        if (is_down) begin
            j = 0;
            for (i = 0; i < 4; i++) begin
                if (i < kd_n && kd_slot[i] != fn) begin
                    kd_slot[j] <= kd_slot[i];
                    j = j + 1;
                end
            end
            kd_n <= 3'(j);
            for (i = j; i < 4; i++) kd_slot[i] <= 16'hFFFF;
        end else begin
            j = 0;
            for (i = 0; i < 4; i++) begin
                if (i < ku_n && ku_slot[i] != fn) begin
                    ku_slot[j] <= ku_slot[i];
                    j = j + 1;
                end
            end
            ku_n <= 3'(j);
            for (i = j; i < 4; i++) ku_slot[i] <= 16'hFFFF;
        end
    endtask
    // NEW: recycle this call's env unless MAKE_FN captured it (live closure).
    task automatic release_env_to(input logic [5:0] saved);
        if (env_sp > saved && env_sp != 6'd0) begin
            if (!env_cap[env_sp - 6'd1]) begin
                if (n_obj == (env_oid[env_sp - 6'd1] + 16'd1))
                    n_obj <= env_oid[env_sp - 6'd1];
                else if (env_free_n < ENV_DEPTH[5:0]) begin
                    env_free[env_free_n] <= env_oid[env_sp - 6'd1];
                    env_free_n <= env_free_n + 6'd1;
                end
            end
        end
        env_sp <= saved;
    endtask
    // NEW: nursery obj/fn stored into an *old-space array* (boot snapshot).
    // Callers must check dest oid < n_arr_keep. Do not use on SET_PROP —
    // item.coord = position2coord() every frame would freeze the bump
    // (PACMAN FPGA-SIM heapovf=8896 / ghosts never left the house).
    task automatic commit_obj_keep(input logic [2:0] tag, input logic [15:0] oid);
        if (obj_keep_ok && (tag == 3'd1 || tag == 3'd4) && oid >= n_obj_keep)
            n_obj_keep <= oid + 16'd1;
    endtask
    // NEW: same watermark as objects — stored array oid+1, never n_arr.
    // JSON.parse / Array.fill / map temps sit above keep and rewind.
    task automatic commit_arr_keep(input logic [2:0] tag, input logic [15:0] oid);
        if (arr_keep_ok && tag == 3'd2 && oid >= n_arr_keep)
            n_arr_keep <= oid + 16'd1;
    endtask
    // NEW: clip fillRect args to FB (no wrap — was the sparse BOARD bug)
    function automatic logic [9:0] clip_u(input logic signed [31:0] v, input int unsigned lim);
        if (v < 0) clip_u = 10'd0;
        else if (v >= lim) clip_u = 10'(lim - 1);
        else clip_u = 10'(v);
    endfunction
    // NEW: 16-bit clamp for blit source coords (ASET sheets exceed 10 bits)
    function automatic logic [15:0] clip_src(input logic signed [31:0] v);
        if (v < 0) clip_src = 16'd0;
        else if (v > 32'sd65535) clip_src = 16'd65535;
        else clip_src = 16'(v);
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
    // NEW: float bits → Q16.16 fixed (tag 7). 0.12*width must not be 0 —
    // fractions are the FM parity gap (INVADERS ship scale, DONKEY 640/1510).
    function automatic logic signed [31:0] f32_to_fx(input logic [31:0] bits);
        logic [7:0] exp;
        logic [23:0] mant;
        logic signed [31:0] mag;
        exp = bits[30:23];
        mant = {1'b1, bits[22:0]};
        if (exp == 8'd0 || exp < 8'd103)          // |v| < 2^-24 → 0
            mag = 32'sd0;
        else if (exp >= 8'd142)                    // |v| >= 2^15 clamps Q16.16
            mag = 32'sd2147483647;
        else if (exp >= 8'd134)                    // v×2^16 = mant×2^(exp-134)
            mag = $signed({8'd0, mant} << (exp - 8'd134));
        else
            mag = $signed({8'd0, mant} >> (8'd134 - exp));
        f32_to_fx = bits[31] ? -mag : mag;
    endfunction
    // NEW: tag-aware int read — Q16.16 (tag 7) floors to i32, others pass through
    function automatic logic signed [31:0] fxi(
        input logic signed [31:0] v, input logic [2:0] t);
        fxi = (t == 3'd7) ? (v >>> 16) : v;
    endfunction
    // NEW: lift an int operand into Q16.16 when its partner is fx
    function automatic logic signed [31:0] fxlift(
        input logic signed [31:0] v, input logic [2:0] t, input logic pair_fx);
        fxlift = (pair_fx && t != 3'd7) ? (v <<< 16) : v;
    endfunction
    // NEW: stack read floored to int — draw/native args must not see raw Q16.16
    function automatic logic signed [31:0] sti(input logic [10:0] i);
        sti = (stack_tag[i] == 3'd7) ? (stack[i] >>> 16) : stack[i];
    endfunction
    // NEW: stack read AS Q16.16 — scaled draws keep the fraction until the
    // final int() like FM _xf (int lifts <<16, fx passes raw)
    function automatic logic signed [31:0] stfx(input logic [10:0] i);
        stfx = (stack_tag[i] == 3'd7) ? stack[i] : (stack[i] <<< 16);
    endfunction
    // NEW: Q32.32 → int, truncating toward zero (Python int() spec in FM _xf)
    function automatic logic signed [31:0] trunc32(input logic signed [63:0] v);
        trunc32 = v[63] ? -32'((-v) >>> 32) : 32'(v >>> 32);
    endfunction

    // NEW: saturate a 33-bit sum to int32 — FM floats never wrap on overflow
    function automatic logic signed [31:0] sat33(input logic signed [32:0] v);
        if (v > 33'sd2147483647) sat33 = 32'sd2147483647;
        else if (v < -33'sd2147483648) sat33 = -32'sd2147483648;
        else sat33 = 32'(v);
    endfunction

    // NEW: quarter-wave sine ROM init (Q1.15) — arc angle sector vectors
    initial begin
        sin_q[0]=16'd0; sin_q[1]=16'd201; sin_q[2]=16'd402; sin_q[3]=16'd603; sin_q[4]=16'd804; sin_q[5]=16'd1005; sin_q[6]=16'd1206; sin_q[7]=16'd1407;
        sin_q[8]=16'd1608; sin_q[9]=16'd1809; sin_q[10]=16'd2009; sin_q[11]=16'd2210; sin_q[12]=16'd2410; sin_q[13]=16'd2611; sin_q[14]=16'd2811; sin_q[15]=16'd3012;
        sin_q[16]=16'd3212; sin_q[17]=16'd3412; sin_q[18]=16'd3612; sin_q[19]=16'd3811; sin_q[20]=16'd4011; sin_q[21]=16'd4210; sin_q[22]=16'd4410; sin_q[23]=16'd4609;
        sin_q[24]=16'd4808; sin_q[25]=16'd5007; sin_q[26]=16'd5205; sin_q[27]=16'd5404; sin_q[28]=16'd5602; sin_q[29]=16'd5800; sin_q[30]=16'd5998; sin_q[31]=16'd6195;
        sin_q[32]=16'd6393; sin_q[33]=16'd6590; sin_q[34]=16'd6786; sin_q[35]=16'd6983; sin_q[36]=16'd7179; sin_q[37]=16'd7375; sin_q[38]=16'd7571; sin_q[39]=16'd7767;
        sin_q[40]=16'd7962; sin_q[41]=16'd8157; sin_q[42]=16'd8351; sin_q[43]=16'd8545; sin_q[44]=16'd8739; sin_q[45]=16'd8933; sin_q[46]=16'd9126; sin_q[47]=16'd9319;
        sin_q[48]=16'd9512; sin_q[49]=16'd9704; sin_q[50]=16'd9896; sin_q[51]=16'd10087; sin_q[52]=16'd10278; sin_q[53]=16'd10469; sin_q[54]=16'd10659; sin_q[55]=16'd10849;
        sin_q[56]=16'd11039; sin_q[57]=16'd11228; sin_q[58]=16'd11417; sin_q[59]=16'd11605; sin_q[60]=16'd11793; sin_q[61]=16'd11980; sin_q[62]=16'd12167; sin_q[63]=16'd12353;
        sin_q[64]=16'd12539; sin_q[65]=16'd12725; sin_q[66]=16'd12910; sin_q[67]=16'd13094; sin_q[68]=16'd13279; sin_q[69]=16'd13462; sin_q[70]=16'd13645; sin_q[71]=16'd13828;
        sin_q[72]=16'd14010; sin_q[73]=16'd14191; sin_q[74]=16'd14372; sin_q[75]=16'd14553; sin_q[76]=16'd14732; sin_q[77]=16'd14912; sin_q[78]=16'd15090; sin_q[79]=16'd15269;
        sin_q[80]=16'd15446; sin_q[81]=16'd15623; sin_q[82]=16'd15800; sin_q[83]=16'd15976; sin_q[84]=16'd16151; sin_q[85]=16'd16325; sin_q[86]=16'd16499; sin_q[87]=16'd16673;
        sin_q[88]=16'd16846; sin_q[89]=16'd17018; sin_q[90]=16'd17189; sin_q[91]=16'd17360; sin_q[92]=16'd17530; sin_q[93]=16'd17700; sin_q[94]=16'd17869; sin_q[95]=16'd18037;
        sin_q[96]=16'd18204; sin_q[97]=16'd18371; sin_q[98]=16'd18537; sin_q[99]=16'd18703; sin_q[100]=16'd18868; sin_q[101]=16'd19032; sin_q[102]=16'd19195; sin_q[103]=16'd19357;
        sin_q[104]=16'd19519; sin_q[105]=16'd19680; sin_q[106]=16'd19841; sin_q[107]=16'd20000; sin_q[108]=16'd20159; sin_q[109]=16'd20317; sin_q[110]=16'd20475; sin_q[111]=16'd20631;
        sin_q[112]=16'd20787; sin_q[113]=16'd20942; sin_q[114]=16'd21096; sin_q[115]=16'd21250; sin_q[116]=16'd21403; sin_q[117]=16'd21554; sin_q[118]=16'd21705; sin_q[119]=16'd21856;
        sin_q[120]=16'd22005; sin_q[121]=16'd22154; sin_q[122]=16'd22301; sin_q[123]=16'd22448; sin_q[124]=16'd22594; sin_q[125]=16'd22739; sin_q[126]=16'd22884; sin_q[127]=16'd23027;
        sin_q[128]=16'd23170; sin_q[129]=16'd23311; sin_q[130]=16'd23452; sin_q[131]=16'd23592; sin_q[132]=16'd23731; sin_q[133]=16'd23870; sin_q[134]=16'd24007; sin_q[135]=16'd24143;
        sin_q[136]=16'd24279; sin_q[137]=16'd24413; sin_q[138]=16'd24547; sin_q[139]=16'd24680; sin_q[140]=16'd24811; sin_q[141]=16'd24942; sin_q[142]=16'd25072; sin_q[143]=16'd25201;
        sin_q[144]=16'd25329; sin_q[145]=16'd25456; sin_q[146]=16'd25582; sin_q[147]=16'd25708; sin_q[148]=16'd25832; sin_q[149]=16'd25955; sin_q[150]=16'd26077; sin_q[151]=16'd26198;
        sin_q[152]=16'd26319; sin_q[153]=16'd26438; sin_q[154]=16'd26556; sin_q[155]=16'd26674; sin_q[156]=16'd26790; sin_q[157]=16'd26905; sin_q[158]=16'd27019; sin_q[159]=16'd27133;
        sin_q[160]=16'd27245; sin_q[161]=16'd27356; sin_q[162]=16'd27466; sin_q[163]=16'd27575; sin_q[164]=16'd27683; sin_q[165]=16'd27790; sin_q[166]=16'd27896; sin_q[167]=16'd28001;
        sin_q[168]=16'd28105; sin_q[169]=16'd28208; sin_q[170]=16'd28310; sin_q[171]=16'd28411; sin_q[172]=16'd28510; sin_q[173]=16'd28609; sin_q[174]=16'd28706; sin_q[175]=16'd28803;
        sin_q[176]=16'd28898; sin_q[177]=16'd28992; sin_q[178]=16'd29085; sin_q[179]=16'd29177; sin_q[180]=16'd29268; sin_q[181]=16'd29358; sin_q[182]=16'd29447; sin_q[183]=16'd29534;
        sin_q[184]=16'd29621; sin_q[185]=16'd29706; sin_q[186]=16'd29791; sin_q[187]=16'd29874; sin_q[188]=16'd29956; sin_q[189]=16'd30037; sin_q[190]=16'd30117; sin_q[191]=16'd30195;
        sin_q[192]=16'd30273; sin_q[193]=16'd30349; sin_q[194]=16'd30424; sin_q[195]=16'd30498; sin_q[196]=16'd30571; sin_q[197]=16'd30643; sin_q[198]=16'd30714; sin_q[199]=16'd30783;
        sin_q[200]=16'd30852; sin_q[201]=16'd30919; sin_q[202]=16'd30985; sin_q[203]=16'd31050; sin_q[204]=16'd31113; sin_q[205]=16'd31176; sin_q[206]=16'd31237; sin_q[207]=16'd31297;
        sin_q[208]=16'd31356; sin_q[209]=16'd31414; sin_q[210]=16'd31470; sin_q[211]=16'd31526; sin_q[212]=16'd31580; sin_q[213]=16'd31633; sin_q[214]=16'd31685; sin_q[215]=16'd31736;
        sin_q[216]=16'd31785; sin_q[217]=16'd31833; sin_q[218]=16'd31880; sin_q[219]=16'd31926; sin_q[220]=16'd31971; sin_q[221]=16'd32014; sin_q[222]=16'd32057; sin_q[223]=16'd32098;
        sin_q[224]=16'd32137; sin_q[225]=16'd32176; sin_q[226]=16'd32213; sin_q[227]=16'd32250; sin_q[228]=16'd32285; sin_q[229]=16'd32318; sin_q[230]=16'd32351; sin_q[231]=16'd32382;
        sin_q[232]=16'd32412; sin_q[233]=16'd32441; sin_q[234]=16'd32469; sin_q[235]=16'd32495; sin_q[236]=16'd32521; sin_q[237]=16'd32545; sin_q[238]=16'd32567; sin_q[239]=16'd32589;
        sin_q[240]=16'd32609; sin_q[241]=16'd32628; sin_q[242]=16'd32646; sin_q[243]=16'd32663; sin_q[244]=16'd32678; sin_q[245]=16'd32692; sin_q[246]=16'd32705; sin_q[247]=16'd32717;
        sin_q[248]=16'd32728; sin_q[249]=16'd32737; sin_q[250]=16'd32745; sin_q[251]=16'd32752; sin_q[252]=16'd32757; sin_q[253]=16'd32761; sin_q[254]=16'd32765; sin_q[255]=16'd32766;
    end
    // NEW: Q16.16 radians -> 16-bit turns (natural wrap = mod 2pi)
    function automatic logic [15:0] fx_turn(input logic signed [31:0] a);
        logic signed [47:0] p;
        p = 48'(a) * 48'sd10430; // 10430 = 65536 / 2pi
        fx_turn = p[31:16];
    endfunction
    // NEW: sin of a 16-bit turn via quarter-wave ROM (Q1.15 signed)
    function automatic logic signed [16:0] sin_t(input logic [15:0] t);
        logic [15:0] q;
        q = (t[14]) ? sin_q[8'd255 - t[13:6]] : sin_q[t[13:6]];
        sin_t = t[15] ? -$signed({1'b0, q}) : $signed({1'b0, q});
    endfunction
    function automatic logic signed [16:0] cos_t(input logic [15:0] t);
        cos_t = sin_t(t + 16'h4000);
    endfunction
    // NEW: (a1 - a0) mod 2pi in Q16.16 (FM sweep computation)
    function automatic logic signed [31:0] fx_mod2pi(input logic signed [31:0] d);
        logic signed [31:0] r;
        r = d;
        if (r < 0) r = r + FX_2PI;
        if (r < 0) r = r + FX_2PI;
        if (r >= FX_2PI) r = r - FX_2PI;
        if (r >= FX_2PI) r = r - FX_2PI;
        fx_mod2pi = r;
    endfunction

    task automatic json_putc(input logic [7:0] ch);
        if (json_wp < 14'(JSON_CAP)) begin
            json_mem[json_wp[12:0]] <= ch;
            json_wp <= json_wp + 14'd1;
        end else dbg_json_ovf <= dbg_json_ovf + 16'd1;
    endtask
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
        logic [12:0] koid, child;
        logic found;
        koid = vars[var_keys][12:0];
        child = 11'd0;
        for (int s = 0; s < OBJ_SLOTS; s++)
            if (s < obj_n[koid] && obj_key[koid][s] == child_ni)
                child = obj_val[koid][s][12:0];
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
            did_swap <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0;
            fb_dump_addr <= '0; fb_dump_sel <= 1'b0;
            sp <= '0; ip <= '0;
            n_ops <= '0; n_consts <= '0; ops_base <= '0;
            code_raddr <= '0;
            nat_id <= '0; nat_argc <= '0;
            c_i <= '0;
            sram_req <= 1'b0; sram_addr <= '0; blit_wait <= 1'b0;
            aset_mode <= 1'b0; sprd_mode <= 1'b0; hdr_w <= 16'd3;
            boot_clr <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            fb_swap <= 1'b0;
            kd_fn <= kd_slot[0];
            ku_fn <= ku_slot[0];
            if (fb_swap) dbg_swap_n <= dbg_swap_n + 16'd1; // NEW: present count
            // NEW: capture raw host key events (any state; drained per frame)
            if (key_evt_stb && (kev_wp + 3'd1) != kev_rp) begin
                kev_q[kev_wp] <= {key_evt_down, key_evt_code};
                kev_wp <= kev_wp + 3'd1;
            end
            if (stop) begin
                running <= 1'b0;
                looping <= 1'b0;
                sram_req <= 1'b0; blit_wait <= 1'b0; // NEW: drop mid-blit SRAM req
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
                    // NEW: flags bit1 (ASET) → u32 aset_byte_off occupies word 3,
                    // consts start at word 4; sprites blit from the asset SRAM.
                    aset_mode <= code_rdata[17];
                    hdr_w <= code_rdata[17] ? 16'd4 : 16'd3;
                    ops_base <= (code_rdata[17] ? 16'd4 : 16'd3) + n_consts;
                    jsb_flags <= code_rdata[31:16];
                    for (int i = 0; i < MAX_VARS; i++) var_init[i] <= 1'b0;
                    for (int i = 0; i < 1024; i++) fill_lut[i] <= 8'hFF; // NEW: FSTY default
                    n_obj <= 0; n_arr <= 0; n_cls <= 0; csp <= 0; raf_n <= 0;
                    arr_keep_ok <= 1'b0; n_arr_keep <= 0;
                    arr_keep_wait <= ARR_KEEP_DELAY[3:0];
                    obj_keep_ok <= 1'b0; n_obj_keep <= 0;
                    obj_keep_wait <= ARR_KEEP_DELAY[3:0];
                    frame_fire <= 1'b0;
                    env_sp <= 0; env_free_n <= 0; to_n <= 0; to_seq <= 16'd1; dbg_heap_ovf <= 0; dbg_to_ovf <= 0;
                    dbg_json_ovf <= 0; js_sp <= 0; json_wp <= 0;
                    kd_fn <= 16'hFFFF; ku_fn <= 16'hFFFF; click_fn <= 16'hFFFF;
                    kd_n <= 3'd0; ku_n <= 3'd0; kev_li <= 2'd0;
                    kd_slot[0] <= 16'hFFFF; kd_slot[1] <= 16'hFFFF;
                    kd_slot[2] <= 16'hFFFF; kd_slot[3] <= 16'hFFFF;
                    ku_slot[0] <= 16'hFFFF; ku_slot[1] <= 16'hFFFF;
                    ku_slot[2] <= 16'hFFFF; ku_slot[3] <= 16'hFFFF;
                    boot_clr <= 1'b1; boot_clr_n <= 2'd2;
                    id_find <= 16'hFFFF;
                    click_fired <= 1'b0;
                    pre_click_raf <= 1'b0;
                    fill_style_i <= 8'd1; lfsr <= 32'hACE1; this_obj <= 0;
                    var_this <= 9'd0; this_ok <= 1'b0; id_this_name <= 16'hFFFF;
                    var_keys <= 9'd0; keys_ok <= 1'b0;
                    keys_a_oid <= 16'hFFFF; keys_d_oid <= 16'hFFFF; keys_sp_oid <= 16'hFFFF;
                    id_keys_name <= 16'hFFFF; id_pressed <= 16'hFFFF; id_kspace <= 16'hFFFF;
                    id_fillrect <= 16'hFFFF; id_length <= 16'hFFFF; id_push <= 16'hFFFF;
                    id_splice <= 16'hFFFF; id_foreach <= 16'hFFFF; id_getctx <= 16'hFFFF;
                    id_map <= 16'hFFFF; id_unshift <= 16'hFFFF;
                    id_click <= 16'hFFFF; id_ael <= 16'hFFFF; id_key <= 16'hFFFF;
                    id_rel <= 16'hFFFF; id_disp <= 16'hFFFF;
                    id_document <= 16'hFFFF; id_window <= 16'hFFFF;
                    id_fillstyle <= 16'hFFFF; id_clearrect <= 16'hFFFF; id_drawimage <= 16'hFFFF;
                    id_keydown <= 16'hFFFF; id_keyup <= 16'hFFFF; id_width <= 16'hFFFF;
                    id_space <= 16'hFFFF; id_arrow_l <= 16'hFFFF; id_arrow_r <= 16'hFFFF;
                    id_a <= 16'hFFFF; id_d <= 16'hFFFF; kev_fn <= 16'hFFFF;
                    id_height <= 16'hFFFF; id_black <= 16'hFFFF; id_white <= 16'hFFFF;
                    id_save <= 16'hFFFF; id_restore <= 16'hFFFF;
                    id_translate <= 16'hFFFF; id_rotate <= 16'hFFFF;
                    id_settransform <= 16'hFFFF;
                    id_assign <= 16'hFFFF; id_bind <= 16'hFFFF;
                    id_proto <= 16'hFFFF; id_filltext <= 16'hFFFF; id_arc <= 16'hFFFF;
                    id_enter <= 16'hFFFF; id_keycode <= 16'hFFFF;
                    id_kbevent <= 16'hFFFF; id_domevent <= 16'hFFFF;
                    id_customev <= 16'hFFFF; id_mouseev <= 16'hFFFF;
                    id_type <= 16'hFFFF;
                    id_now <= 16'hFFFF; id_gettime <= 16'hFFFF;
                    id_beginpath <= 16'hFFFF; id_fill <= 16'hFFFF; id_stroke <= 16'hFFFF;
                    id_moveto <= 16'hFFFF; id_lineto <= 16'hFFFF; id_closepath <= 16'hFFFF;
                    id_quadcurve <= 16'hFFFF;
                    id_getimgdata <= 16'hFFFF; id_putimgdata <= 16'hFFFF;
                    id_join <= 16'hFFFF; id_indexof <= 16'hFFFF; id_replace <= 16'hFFFF;
                    names_n <= 16'd0; dbg_join_miss <= 16'd0; dbg_pdo_n <= 5'd0;
                    dbg_rect_n <= 5'd0; dbg_swap_n <= 16'd0;
                    dbg_line_px <= 32'd0; dbg_circ_px <= 32'd0; dbg_rect_px <= 32'd0;
                    pc_n <= 5'd0; pi <= 5'd0; path_active <= 1'b0; dbg_path_ovf <= 16'd0;
                    qseg <= 4'd0; arc_ang <= 1'b0;
                    id_strokestyle <= 16'hFFFF;
                    id_hex_09f <= 16'hFFFF; id_hex_f5f5 <= 16'hFFFF; id_hex_ffe6 <= 16'hFFFF;
                    id_hex_f00 <= 16'hFFFF; id_hex_aaa <= 16'hFFFF;
                    path_kind <= 2'd0; n_spr <= 5'd0; spr_wp <= 18'd0; spr_hdr <= 3'd0;
                    dbg_di_hit <= 16'd0; dbg_di_miss <= 16'd0;
                    sprd_mode <= 1'b0; blit_wait <= 1'b0; sram_req <= 1'b0;
                    time_ms <= 32'd0;
                    n_fn_proto <= 7'd0;
                    enter_n <= 3'd0; enter_delay <= 4'd0; // hack retired (KEYEVT)
                    kev_wp <= 3'd0; kev_rp <= 3'd0;
                    for (int i = 0; i < 1024; i++) intern_var_ok[i] <= 1'b0;
                    ctx_tx <= 32'sd0; ctx_ty <= 32'sd0;
                    saved_tx <= 32'sd0; saved_ty <= 32'sd0;
                    ctx_sx <= FX_ONE; ctx_sy <= FX_ONE;   // NEW: identity scale
                    saved_sx <= FX_ONE; saved_sy <= FX_ONE;
                    trail_off <= 19'((code_rdata[17] ? 16'd4 : 16'd3) + n_consts + n_ops) << 2;
                    trail_ph <= 5'd0;
                    trail_guard <= 16'd0;
                    if (n_consts == 16'd0) begin
                        ip <= '0;
                        if (code_rdata[16]) begin
                            code_raddr <= 15'((code_rdata[17] ? 16'd4 : 16'd3) + n_ops);
                            state <= S_RD;
                            ret_state <= S_TRAIL;
                        end else begin
                            code_raddr <= code_rdata[17] ? 15'd4 : 15'd3;
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        c_i <= '0;
                        code_raddr <= code_rdata[17] ? 15'd4 : 15'd3;
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end
                S_LD_CONST: begin
                    consts[c_i[9:0]] <= $signed(code_rdata);
                    if (c_i + 16'd1 >= n_consts) begin
                        ip <= '0;
                        if (jsb_flags[0]) begin
                            code_raddr <= 15'(hdr_w + n_consts + n_ops);
                            state <= S_RD;
                            ret_state <= S_TRAIL;
                        end else begin
                            code_raddr <= 15'(hdr_w + n_consts);
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        c_i <= c_i + 16'd1;
                        code_raddr <= 15'(hdr_w + c_i + 16'd1);
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
                                // NEW: keep name count for join hash->intern reverse scan
                                names_n <= ({tb, trail_acc[7:0]} > 16'd1024) ? 16'd1024
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
                                if ({tb, trail_acc[7:0]} == 16'd42332) id_map <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38281) id_unshift <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62905) id_find <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd29049) id_getctx <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd50568) id_click <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58957) id_ael <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36682) id_rel <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd64064) id_disp <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd53531) id_document <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56304) id_window <= name_idx;
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
                                if ({tb, trail_acc[7:0]} == 16'd22767) id_getimgdata <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd21846) id_putimgdata <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13943) id_drawimage <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49533) id_save <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd53902) id_restore <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61774) id_translate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd40234) id_settransform <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56667) id_rotate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd33007) id_assign <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9277) id_bind <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9506) id_proto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13648) id_filltext <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31314) id_arc <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5816) id_enter <= name_idx;
                                // NEW: DOM event ctor names + "type" (jsb_format._name_hash)
                                if ({tb, trail_acc[7:0]} == 16'd38611) id_kbevent <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd33402) id_domevent <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd7561)  id_customev <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd16661) id_mouseev <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36666) id_type <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54382) id_beginpath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62851) id_fill <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd30264) id_stroke <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38444) id_moveto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5522)  id_quadcurve <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36239) id_lineto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd64061) id_closepath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd55897) id_strokestyle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd42106) id_hex_09f <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54400) id_hex_f5f5 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61684) id_hex_ffe6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62915) id_hex_f00 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58654) id_hex_aaa <= name_idx;
                                // NEW: "jmr:spr:0".."9" hash 46080..46089 contiguous;
                                // "jmr:spr:10".."15" hash 52303..52308 (two digits)
                                if ({tb, trail_acc[7:0]} >= 16'd46080 && {tb, trail_acc[7:0]} <= 16'd46089)
                                    spr_nid[4'(({tb, trail_acc[7:0]}) - 16'd46080)] <= name_idx;
                                if ({tb, trail_acc[7:0]} >= 16'd52303 && {tb, trail_acc[7:0]} <= 16'd52308)
                                    spr_nid[4'(({tb, trail_acc[7:0]}) - 16'd52303 + 16'd10)] <= name_idx;
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
                                if ({tb, trail_acc[7:0]} == 16'd56618) id_join <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd17993) id_indexof <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45748) id_replace <= name_idx;
                                // NEW: full hash table — join result maps back to intern id
                                name_hash_tbl[name_idx[9:0]] <= {tb, trail_acc[7:0]};
                                // NEW: u8 length byte follows each hash (concat fold)
                                trail_ph <= 5'd4;
                            end
                            5'd4: begin
                                name_len_tbl[name_idx[9:0]] <= tb;
                                // Space intern: hash 32 + len 1 (U+0020). Confirm
                                // here so e.key === " " matches KEYEVT payload.
                                if (name_hash_tbl[name_idx[9:0]] == 16'd32 && tb == 8'd1)
                                    id_space <= name_idx;
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
                                // LOAD_VAR uses varmap slots, not intern idx (PYTHON seeds document/window)
                                if ({tb, trail_acc[7:0]} == id_document ||
                                    {tb, trail_acc[7:0]} == id_window) begin
                                    vars[trail_var_slot] <= 32'sd0;
                                    var_tag[trail_var_slot] <= 3'd6;
                                    var_init[trail_var_slot] <= 1'b1;
                                end
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
                                // bytes: acc[7:0], acc[15:8], trail_n[7:0], tb == "SPR1"
                                // (inline pixels) or "SPRD" (ASET descriptors)
                                if (trail_acc[7:0] == 8'h53 && trail_acc[15:8] == 8'h50 &&
                                    trail_n[7:0] == 8'h52 && (tb == 8'h31 || tb == 8'h44)) begin
                                    sprd_mode <= (tb == 8'h44);
                                    trail_ph <= 5'd26;
                                end else begin
                                    code_raddr <= 15'(ops_base);
                                    state <= S_FETCH_WAIT;
                                    trail_ph <= 5'd31;
                                end
                            end
                            5'd26: begin trail_acc[7:0] <= tb; trail_ph <= 5'd27; end
                            5'd27: begin
                                // NEW: 16 descriptors (compile_js.py fails loud past
                                // MAX_SPR, so this clamp is defensive only)
                                n_spr <= ({tb, trail_acc[7:0]} > 16'd16) ? 5'd16
                                       : {tb, trail_acc[7:0]}[4:0];
                                spr_i <= 5'd0;
                                spr_wp <= 18'd0;
                                spr_left <= 18'd0;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    // NEW: empty SPRD (PACMAN) → FSTY follows in aset mode
                                    if (sprd_mode) begin
                                        spr_hdr <= 3'd0;
                                        trail_ph <= 5'd29;
                                    end else begin
                                        code_raddr <= 15'(ops_base);
                                        state <= S_FETCH_WAIT;
                                        trail_ph <= 5'd31;
                                    end
                                end else if (sprd_mode) begin
                                    // SPRD: 8-byte descriptors (w,h u16 + u32 SRAM
                                    // offset) — no pixel copy, stay in S_TRAIL
                                    spr_hdr <= 3'd0;
                                    trail_ph <= 5'd28;
                                end else begin
                                    trail_ph <= 5'd31;
                                    spr_hdr <= 3'd0;
                                    state <= S_SPR;
                                end
                            end
                            5'd28: begin
                                // NEW: SPRD descriptor walk — spr_hdr counts the 8
                                // bytes; off byte 3 ignored (bank is 4 MB / 22 bits)
                                unique case (spr_hdr)
                                    3'd0: begin trail_acc[7:0] <= tb; spr_hdr <= 3'd1; end
                                    3'd1: begin spr_ww[spr_i[3:0]] <= {tb, trail_acc[7:0]}; spr_hdr <= 3'd2; end
                                    3'd2: begin trail_acc[7:0] <= tb; spr_hdr <= 3'd3; end
                                    3'd3: begin spr_hh[spr_i[3:0]] <= {tb, trail_acc[7:0]}; spr_hdr <= 3'd4; end
                                    3'd4: begin spr_off[spr_i[3:0]][7:0]   <= tb; spr_hdr <= 3'd5; end
                                    3'd5: begin spr_off[spr_i[3:0]][15:8]  <= tb; spr_hdr <= 3'd6; end
                                    3'd6: begin spr_off[spr_i[3:0]][21:16] <= tb[5:0]; spr_hdr <= 3'd7; end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (spr_i + 5'd1 >= n_spr)
                                            trail_ph <= 5'd29; // NEW: FSTY LUT follows SPRD
                                        else spr_i <= spr_i + 5'd1;
                                    end
                                endcase
                            end
                            5'd29: begin
                                // NEW: FSTY magic + u16 row count (spr_hdr = byte pos)
                                unique case (spr_hdr)
                                    3'd0: begin
                                        if (tb == 8'h46) spr_hdr <= 3'd1; // 'F'
                                        else begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd1, 3'd2, 3'd3: begin
                                        // 'S','T','Y' — any mismatch bails to code
                                        if ((spr_hdr == 3'd1 && tb == 8'h53) ||
                                            (spr_hdr == 3'd2 && tb == 8'h54) ||
                                            (spr_hdr == 3'd3 && tb == 8'h59))
                                            spr_hdr <= spr_hdr + 3'd1;
                                        else begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd4: begin fsty_n[7:0] <= tb; spr_hdr <= 3'd5; end
                                    default: begin
                                        fsty_n[15:8] <= tb;
                                        spr_hdr <= 3'd0;
                                        if ({tb, fsty_n[7:0]} == 16'd0) begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end else trail_ph <= 5'd30;
                                    end
                                endcase
                            end
                            5'd30: begin
                                // NEW: FSTY rows (u16 name_idx, u16 palette idx)
                                unique case (spr_hdr)
                                    3'd0: begin fsty_name[7:0] <= tb; spr_hdr <= 3'd1; end
                                    3'd1: begin fsty_name[15:8] <= tb; spr_hdr <= 3'd2; end
                                    3'd2: begin
                                        fill_lut[fsty_name[9:0]] <= tb;
                                        spr_hdr <= 3'd3;
                                    end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (fsty_n <= 16'd1) begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end else fsty_n <= fsty_n - 16'd1;
                                    end
                                endcase
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

                S_FETCH_WAIT: begin
                    // NEW: clear both FB banks once after header/trail, before first op
                    if (boot_clr) begin
                        color <= 8'd0;
                        clr_idx <= '0;
                        state <= S_CLEAR;
                    end else
                        state <= S_EXEC;
                end

                S_EXEC: begin
                    if (ip >= n_ops) begin
                        // One implicit present per pass (HTML rAF never calls
                        // swapBuffers) — but a legacy .JS pass that swapped
                        // explicitly must NOT swap again (double swap blanked
                        // INVADERS.JS: front always showed the undrawn buffer)
                        if (!did_swap) fb_swap <= 1'b1;
                        did_swap <= 1'b0;
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
                                    // NEW: float const → Q16.16 fixed (tag 7) — real
                                    // fractions (0.12 ship scale, PACMAN *.5 speeds)
                                    stack[sp] <= f32_to_fx(consts[code_rdata[17:8]]);
                                    stack_tag[sp] <= 3'd7;
                                end else if (code_rdata[31:24] == 8'd4) begin
                                    // NEW: RegExp stub — packed pattern+flags in const pool
                                    obj_cls[n_obj[12:0]] <= CLS_REGEX;
                                    obj_n[n_obj[12:0]] <= 6'd1;
                                    obj_key[n_obj[12:0]][0] <= 16'd0;
                                    obj_val[n_obj[12:0]][0] <= consts[code_rdata[17:8]];
                                    obj_tag[n_obj[12:0]][0] <= 3'd0;
                                    stack[sp] <= {16'd0, n_obj};
                                    stack_tag[sp] <= 3'd1;
                                    if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                    n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                end else begin
                                    stack[sp] <= consts[code_rdata[17:8]];
                                    stack_tag[sp] <= 3'd0;
                                end
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_LOAD_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk <= env_oid[env_sp - 6'd1];
                                    env_ld_slot <= code_rdata[16:8];
                                    env_is_store <= 1'b0;
                                    ip <= ip + 16'd1;
                                    state <= S_ENV_LOAD;
                                end else begin
                                    stack[sp] <= vars[code_rdata[16:8]];
                                    stack_tag[sp] <= var_tag[code_rdata[16:8]];
                                    sp <= sp + 8'd1;
                                    next_op();
                                end
                            end
                            OP_STORE_VAR: begin
                                if (env_sp != 0) begin
                                    env_walk <= env_oid[env_sp - 6'd1];
                                    env_ld_slot <= code_rdata[16:8];
                                    env_is_store <= 1'b1;
                                    ip <= ip + 16'd1;
                                    state <= S_ENV_LOAD;
                                end else begin
                                    vars[code_rdata[16:8]] <= stack[sp - 8'd1];
                                    var_tag[code_rdata[16:8]] <= stack_tag[sp - 8'd1];
                                    var_init[code_rdata[16:8]] <= 1'b1;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_LET_VAR: begin
                                // NEW: a1 bit0 = call-frame local — upsert into
                                // the LIFO env so nested MAKE_FN can snapshot it.
                                if (code_rdata[24] || !var_init[code_rdata[16:8]]) begin
                                    vars[code_rdata[16:8]] <= stack[sp - 8'd1];
                                    var_tag[code_rdata[16:8]] <= stack_tag[sp - 8'd1];
                                    var_init[code_rdata[16:8]] <= 1'b1;
                                end
                                if (code_rdata[24] && env_sp != 0) begin
                                    begin
                                        logic hit;
                                        logic [5:0] ni;
                                        logic [12:0] eo;
                                        hit = 1'b0;
                                        eo = env_oid[env_sp - 6'd1][12:0];
                                        ni = obj_n[eo];
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s >= 1 && s < ni &&
                                                obj_key[eo][s] == {7'd0, code_rdata[16:8]}) begin
                                                obj_val[eo][s] <= stack[sp - 8'd1];
                                                obj_tag[eo][s] <= stack_tag[sp - 8'd1];
                                                hit = 1'b1;
                                            end
                                        end
                                        if (!hit && ni < OBJ_SLOTS[5:0]) begin
                                            obj_key[eo][ni] <= {7'd0, code_rdata[16:8]};
                                            obj_val[eo][ni] <= stack[sp - 8'd1];
                                            obj_tag[eo][ni] <= stack_tag[sp - 8'd1];
                                            obj_n[eo] <= ni + 6'd1;
                                        end
                                    end
                                end
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_ADD: begin
                                if (stack_tag[sp - 8'd2] == 3'd3 ||
                                    stack_tag[sp - 8'd1] == 3'd3) begin
                                    // NEW: string concat — fold both operands into the
                                    // encoder u16 hash, then find-or-alloc an intern id.
                                    // PACMAN event keys: 's'+_index, 's1i'+id
                                    cc_av <= stack[sp - 8'd2]; cc_at <= stack_tag[sp - 8'd2];
                                    cc_bv <= stack[sp - 8'd1]; cc_bt <= stack_tag[sp - 8'd1];
                                    cc_second <= 1'b0; cc_st <= 1'b0;
                                    cc_h <= 16'd0; cc_len <= 8'd0; cc_d <= 4'd0;
                                    jn_res <= 11'(sp - 8'd2);
                                    sp <= sp - 8'd1;
                                    ip <= ip + 16'd1;
                                    state <= S_CONCAT;
                                end else begin
                                    // NEW: mixed Q16.16 — lift the int side when the other is fx
                                    alu_fx <= (stack_tag[sp - 8'd2] == 3'd7 || stack_tag[sp - 8'd1] == 3'd7);
                                    alu_a <= fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                    stack_tag[sp - 8'd1] == 3'd7);
                                    alu_b <= fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                    stack_tag[sp - 8'd2] == 3'd7);
                                    alu_op <= 3'd0;
                                    sp <= sp - 8'd1;
                                    state <= S_ALU;
                                end
                            end
                            OP_SUB: begin
                                alu_fx <= (stack_tag[sp - 8'd2] == 3'd7 || stack_tag[sp - 8'd1] == 3'd7);
                                alu_a <= fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b <= fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op <= 3'd1;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_MUL: begin
                                // NEW: register operands, multiply next cycle (timing)
                                mul_a <= stack[sp - 8'd2];
                                mul_b <= stack[sp - 8'd1];
                                mul_fx_a <= (stack_tag[sp - 8'd2] == 3'd7);
                                mul_fx_b <= (stack_tag[sp - 8'd1] == 3'd7);
                                state <= S_MUL;
                            end
                            OP_DIV: begin
                                // NEW: multi-cycle divide (see S_DIV) — the old
                                // single-cycle '/' blew board timing (WNS −90 ns).
                                // JS-honest: quotient computed in Q16.16 ((N<<16)/D
                                // after lifting both to fx); int/int exact stays int
                                // (indices), inexact becomes fx (DONKEY 640/1510).
                                if (stack[sp - 8'd1] == 0) begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    stack_tag[sp - 8'd2] <= 3'd0;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else begin
                                    logic signed [31:0] na, nb;
                                    na = fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], 1'b1);
                                    nb = fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], 1'b1);
                                    div_int_in <= (stack_tag[sp - 8'd2] != 3'd7 &&
                                                   stack_tag[sp - 8'd1] != 3'd7);
                                    div_neg <= na[31] ^ nb[31];
                                    // 48-bit dividend = |N| << 16 (fx quotient)
                                    div_uq  <= {(na[31] ? 32'(-na) : 32'(na)), 16'd0};
                                    div_ub  <= nb[31] ? 32'(-nb) : 32'(nb);
                                    div_rem <= '0;
                                    div_cnt <= '0;
                                    state <= S_DIV;
                                end
                            end
                            OP_LT: begin
                                alu_fx <= 1'b0; // compares always yield i32 bool
                                alu_a <= fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b <= fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op <= 3'd2;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_GT: begin
                                alu_fx <= 1'b0;
                                alu_a <= fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                stack_tag[sp - 8'd1] == 3'd7);
                                alu_b <= fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                stack_tag[sp - 8'd2] == 3'd7);
                                alu_op <= 3'd3;
                                sp <= sp - 8'd1;
                                state <= S_ALU;
                            end
                            OP_EQ: begin
                                if (stack_tag[sp - 8'd2] == 3'd5 ||
                                    stack_tag[sp - 8'd1] == 3'd5) begin
                                    // NEW: undefined equals only undefined — FM
                                    // (None == 0) is False; value-only compare made
                                    // PACMAN skip its whole frame (update()!=false)
                                    stack[sp - 8'd2] <=
                                        (stack_tag[sp - 8'd2] == stack_tag[sp - 8'd1])
                                        ? 32'sd1 : 32'sd0;
                                    stack_tag[sp - 8'd2] <= 3'd0;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd3 &&
                                           stack_tag[sp - 8'd1] == 3'd3) begin
                                    // Intern strings: same id, or same hash+len
                                    // (e.key === " " when KEYEVT intern aliases).
                                    begin
                                        logic [9:0] ia, ib;
                                        ia = stack[sp - 8'd2][9:0];
                                        ib = stack[sp - 8'd1][9:0];
                                        stack[sp - 8'd2] <=
                                            (stack[sp - 8'd2][15:0] == stack[sp - 8'd1][15:0] ||
                                             (name_hash_tbl[ia] == name_hash_tbl[ib] &&
                                              name_len_tbl[ia] == name_len_tbl[ib] &&
                                              name_len_tbl[ia] != 8'd0))
                                            ? 32'sd1 : 32'sd0;
                                        stack_tag[sp - 8'd2] <= 3'd0;
                                        sp <= sp - 8'd1;
                                        next_op();
                                    end
                                end else begin
                                    alu_fx <= 1'b0;
                                    alu_a <= fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2],
                                                    stack_tag[sp - 8'd1] == 3'd7);
                                    alu_b <= fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1],
                                                    stack_tag[sp - 8'd2] == 3'd7);
                                    alu_op <= 3'd4;
                                    sp <= sp - 8'd1;
                                    state <= S_ALU;
                                end
                            end
                            OP_JUMP: begin
                                ip <= code_rdata[23:8];
                                code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                state <= S_FETCH_WAIT;
                            end
                            OP_JIF: begin
                                // JS falsy: undef, int 0, or fx 0.0 — objects/strings/fns at oid 0 are still truthy
                                a_s = (stack_tag[sp - 8'd1] == 3'd5 ||
                                       ((stack_tag[sp - 8'd1] == 3'd0 || stack_tag[sp - 8'd1] == 3'd7)
                                        && stack[sp - 8'd1] == 0))
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
                            // POP saturates at empty: draw natives push no
                            // return but the compiler still emits POP after
                            // statement calls (FM pushes undefined) — the
                            // unguarded pop wrapped sp to 2047 in PACMAN boot
                            OP_POP: begin if (sp != 0) sp <= sp - 8'd1; next_op(); end
                            OP_DUP: begin
                                stack[sp] <= stack[sp - 8'd1];
                                stack_tag[sp] <= stack_tag[sp - 8'd1];
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_NEG: begin
                                alu_fx <= (stack_tag[sp - 8'd1] == 3'd7); // -fx stays fx
                                alu_a <= stack[sp - 8'd1];
                                alu_op <= 3'd5;
                                state <= S_ALU;
                            end
                            OP_NOT: begin
                                // JS !x — objects/strings/fns truthy even when the packed oid is 0
                                alu_fx <= 1'b0;
                                alu_a <= (stack_tag[sp - 8'd1] == 3'd5 ||
                                          ((stack_tag[sp - 8'd1] == 3'd0 || stack_tag[sp - 8'd1] == 3'd7)
                                           && stack[sp - 8'd1] == 0))
                                         ? 32'sd0 : 32'sd1;
                                alu_op <= 3'd6;
                                state <= S_ALU;
                            end
                            OP_MOD: begin
                                // NEW: a % b on floored ints (fx operands coerce) — 0 if b==0
                                begin
                                    logic signed [31:0] ma, mb;
                                    ma = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2]);
                                    mb = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                    if (mb == 0)
                                        stack[sp - 8'd2] <= 32'sd0;
                                    else
                                        stack[sp - 8'd2] <= ma - (ma / mb) * mb;
                                    stack_tag[sp - 8'd2] <= 3'd0;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_BIT_OR: begin
                                // NEW: `v|0` is the JS float→int idiom — floor fx first
                                stack[sp - 8'd2] <= fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2])
                                                  | fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                stack_tag[sp - 8'd2] <= 3'd0;
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_BIT_AND: begin
                                stack[sp - 8'd2] <= fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2])
                                                  & fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                stack_tag[sp - 8'd2] <= 3'd0;
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_MAKE_ARR: begin
                                arr_len[n_arr[11:0]] <= code_rdata[15:8];
                                for (int k = 0; k < ARR_CAP; k++) begin
                                    if (k < code_rdata[15:8]) begin
                                        arr_val[n_arr[11:0]][k] <= stack[sp - 8'(code_rdata[15:8] - k)];
                                        arr_tag[n_arr[11:0]][k] <= stack_tag[sp - 8'(code_rdata[15:8] - k)];
                                    end
                                end
                                sp <= sp - code_rdata[15:8];
                                stack[sp - code_rdata[15:8]] <= {16'd0, n_arr};
                                stack_tag[sp - code_rdata[15:8]] <= 3'd2;
                                if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                n_arr <= (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                sp <= sp - code_rdata[15:8] + 8'd1;
                                next_op();
                            end
                            OP_ARR_GET: begin
                                // stack [arr, idx] — fx index floors (a[i*0.5] etc.)
                                if (stack_tag[sp - 8'd2] == 3'd2) begin
                                    stack[sp - 8'd2] <= arr_val[stack[sp - 8'd2][11:0]]
                                        [7'(fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]))];
                                    stack_tag[sp - 8'd2] <= arr_tag[stack[sp - 8'd2][11:0]]
                                        [7'(fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]))];
                                end else if (stack_tag[sp - 8'd2] == 3'd1 &&
                                             stack_tag[sp - 8'd1] == 3'd3) begin
                                    // NEW: obj[strkey] bracket get — PACMAN
                                    // _events['keydown']['s'+_index] dispatch
                                    begin
                                        logic [12:0] gi2;
                                        gi2 = stack[sp - 8'd2][12:0];
                                        stack[sp - 8'd2] <= 32'sd0;
                                        stack_tag[sp - 8'd2] <= 3'd5;
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s < obj_n[gi2] &&
                                                obj_key[gi2][s] == stack[sp - 8'd1][15:0]) begin
                                                stack[sp - 8'd2] <= obj_val[gi2][s];
                                                stack_tag[sp - 8'd2] <= obj_tag[gi2][s];
                                            end
                                        end
                                    end
                                end else begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    stack_tag[sp - 8'd2] <= 3'd5;
                                end
                                sp <= sp - 8'd1;
                                next_op();
                            end
                            OP_ARR_SET: begin
                                // [arr, idx, val] — fx index floors first (LHS needs a plain var)
                                begin
                                    logic [6:0] aidx;
                                    aidx = 7'(fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2]));
                                    if (stack_tag[sp - 8'd3] == 3'd2) begin
                                        arr_val[stack[sp - 8'd3][11:0]][aidx] <= stack[sp - 8'd1];
                                        arr_tag[stack[sp - 8'd3][11:0]][aidx] <= stack_tag[sp - 8'd1];
                                    end else if (stack_tag[sp - 8'd3] == 3'd1 &&
                                                 stack_tag[sp - 8'd2] == 3'd3) begin
                                        // NEW: obj[strkey] = v — overwrite-or-append
                                        // (PACMAN _events registry: 's1i3' keys)
                                        logic [12:0] ti2;
                                        logic [5:0] tn2;
                                        logic fnd2;
                                        ti2 = stack[sp - 8'd3][12:0];
                                        tn2 = obj_n[ti2];
                                        fnd2 = 1'b0;
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s < tn2 &&
                                                obj_key[ti2][s] == stack[sp - 8'd2][15:0]) begin
                                                obj_val[ti2][s] <= stack[sp - 8'd1];
                                                obj_tag[ti2][s] <= stack_tag[sp - 8'd1];
                                                fnd2 = 1'b1;
                                            end
                                        end
                                        if (!fnd2 && tn2 < 6'(OBJ_SLOTS)) begin
                                            obj_key[ti2][tn2[4:0]] <= stack[sp - 8'd2][15:0];
                                            obj_val[ti2][tn2[4:0]] <= stack[sp - 8'd1];
                                            obj_tag[ti2][tn2[4:0]] <= stack_tag[sp - 8'd1];
                                            obj_n[ti2] <= tn2 + 6'd1;
                                        end
                                    end
                                    // NEW: ARRAY_SET is overwrite (steps[y][x]=from,
                                    // code[i]=1). Do not raise keep — finder BFS
                                    // nodes and maze `code` rows must rewind.
                                end
                                stack[sp - 8'd3] <= stack[sp - 8'd1];
                                stack_tag[sp - 8'd3] <= stack_tag[sp - 8'd1];
                                sp <= sp - 8'd2;
                                next_op();
                            end
                            OP_MAKE_OBJ: begin
                                obj_n[n_obj[12:0]] <= 0;
                                obj_cls[n_obj[12:0]] <= 0;
                                stack[sp] <= {16'd0, n_obj};
                                stack_tag[sp] <= 3'd1;
                                n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                sp <= sp + 8'd1;
                                next_op();
                            end
                            OP_GET_PROP: begin
                                if (stack_tag[sp - 8'd1] == 3'd2 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    stack[sp - 8'd1] <= {24'd0, arr_len[stack[sp - 8'd1][11:0]]};
                                    stack_tag[sp - 8'd1] <= 3'd0;
                                end else if (stack_tag[sp - 8'd1] == 3'd1) begin
                                    begin
                                        logic [12:0] gi, pi;
                                        logic foundp;
                                        gi = stack[sp - 8'd1][12:0];
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
                                                    pi = obj_val[gi][s][12:0];
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
                                            obj_n[n_obj[12:0]] <= 0;
                                            obj_cls[n_obj[12:0]] <= 0;
                                            stack[sp - 8'd1] <= {16'd0, n_obj};
                                            stack_tag[sp - 8'd1] <= 3'd1;
                                            if (obj_n[gi] < OBJ_SLOTS[5:0]) begin
                                                obj_key[gi][obj_n[gi]] <= id_proto;
                                                obj_val[gi][obj_n[gi]] <= {16'd0, n_obj};
                                                obj_tag[gi][obj_n[gi]] <= 3'd1;
                                                obj_n[gi] <= obj_n[gi] + 6'd1;
                                            end
                                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                        end
                                        // KEYBITS OR into HTML keys.*.pressed at read
                                        if (code_rdata[23:8] == id_pressed || code_rdata[23:8] == 16'd198) begin
                                            if (gi == keys_a_oid[12:0] && joy_in[2]) begin
                                                stack[sp - 8'd1] <= 32'sd1;
                                                stack_tag[sp - 8'd1] <= 3'd0;
                                            end else if (gi == keys_d_oid[12:0] && joy_in[3]) begin
                                                stack[sp - 8'd1] <= 32'sd1;
                                                stack_tag[sp - 8'd1] <= 3'd0;
                                            end else if (gi == keys_sp_oid[12:0] && joy_in[4]) begin
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
                                            obj_n[n_obj[12:0]] <= 0;
                                            obj_cls[n_obj[12:0]] <= 0;
                                            fn_proto_ip[n_fn_proto] <= stack[sp - 8'd1][15:0];
                                            fn_proto_oid[n_fn_proto] <= n_obj;
                                            n_fn_proto <= n_fn_proto + 7'd1;
                                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
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
                                        logic [12:0] oi;
                                        logic found;
                                        oi = stack[sp - 8'd2][12:0];
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
                                        // NEW: SET_PROP overwrite (item.coord =
                                        // position2coord(), this.path = finder())
                                        // must NOT raise keep. Raising it every
                                        // frame saturated MAX_OBJ/MAX_ARR.
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
                                            // NEW: also publish the real sheet size (SPRD) —
                                            // width*scale must match the FM, not the 300×200 stub
                                            for (int k = 0; k < MAX_SPR; k++)
                                                if (stack[sp - 8'd1][15:0] == spr_nid[k[3:0]]) begin
                                                    obj_cls[oi] <= 16'hFFC0 | k[15:0];
                                                    if (obj_cls[oi][15:4] == 12'hFFC) begin
                                                        obj_val[oi][0] <= 32'(spr_ww[k[3:0]]);
                                                        obj_val[oi][1] <= 32'(spr_hh[k[3:0]]);
                                                    end
                                                end
                                        end
                                    end
                                    // Image.onload = fn — invoke now so player.image exists before animate
                                    if (code_rdata[23:8] == id_onload && stack_tag[sp - 8'd1] == 3'd4) begin
                                        cstack_ip[csp] <= ip + 16'd1;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b0;
                                        cstack_isfe[csp] <= 1'b0;
                                        enter_captured_fn(stack[sp - 8'd1][15:0]);
                                        csp <= csp + 7'd1;
                                        ip <= fn_entry(stack[sp - 8'd1][15:0]);
                                        code_raddr <= 15'(ops_base + fn_entry(stack[sp - 8'd1][15:0]));
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
                                    arr_len[stack[sp - 8'd2][11:0]] <= stack[sp - 8'd1][7:0];
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                           (code_rdata[23:8] == id_fillstyle ||
                                            code_rdata[23:8] == id_strokestyle)) begin
                                    // ctx.fillStyle / strokeStyle — FSTY LUT first
                                    // (compiler-resolved 256-palette index, exact FM
                                    // parity); legacy 8-color chain only as fallback
                                    if (stack_tag[sp - 8'd1] == 3'd3 &&
                                        stack[sp - 8'd1][15:0] < 16'd1024 &&
                                        fill_lut[stack[sp - 8'd1][9:0]] != 8'hFF)
                                        fill_style_i <= fill_lut[stack[sp - 8'd1][9:0]];
                                    else if (stack_tag[sp - 8'd1] == 3'd0 ||
                                             stack_tag[sp - 8'd1] == 3'd7)
                                        // numeric fillStyle — direct palette index
                                        fill_style_i <= 8'(fxi(stack[sp - 8'd1],
                                                               stack_tag[sp - 8'd1]));
                                    else if (stack[sp - 8'd1][15:0] == id_black || stack[sp - 8'd1][15:0] == id_hex_000)
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
                                // NEW: heap Fn {entry, nparam, live env oid}
                                // so timers/rAF share the call env (FM dict ref).
                                begin
                                    logic [12:0] fo;
                                    logic [15:0] eoid;
                                    fo = n_obj[12:0];
                                    eoid = (env_sp != 0) ? env_oid[env_sp - 6'd1] : 16'd0;
                                    obj_cls[fo] <= CLS_FN;
                                    obj_key[fo][0] <= 16'd0;
                                    obj_val[fo][0] <= {16'd0, code_rdata[23:8]};
                                    obj_tag[fo][0] <= 3'd0;
                                    obj_key[fo][1] <= 16'd1;
                                    obj_val[fo][1] <= {24'd0, 2'd0, code_rdata[29:24]};
                                    obj_tag[fo][1] <= 3'd0;
                                    obj_key[fo][2] <= 16'd2;
                                    obj_val[fo][2] <= {16'd0, eoid};
                                    obj_tag[fo][2] <= 3'd0;
                                    obj_n[fo] <= (eoid != 16'd0) ? 6'd3 : 6'd2;
                                    if (env_sp != 6'd0)
                                        env_cap[env_sp - 6'd1] <= 1'b1;
                                    stack[sp] <= {16'd0, n_obj};
                                    stack_tag[sp] <= 3'd4;
                                    if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                    n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                    sp <= sp + 8'd1;
                                    next_op();
                                end
                            end
                            OP_CALL_USER: begin
                                cstack_ip[csp] <= ip + 16'd1;
                                cstack_this[csp] <= this_obj;
                                cstack_isctor[csp] <= 1'b0;
                                cstack_isfe[csp] <= 1'b0;
                                cstack_env[csp] <= env_sp;
                                push_fresh_env(16'd0);
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
                                        logic [15:0] foid;
                                        logic [12:0] fo;
                                        logic [5:0]  capn;
                                        ac = code_rdata[15:8];
                                        foid = stack[sp - ac - 8'd1][15:0];
                                        fo = foid[12:0];
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
                                        enter_captured_fn(foid);
                                        csp <= csp + 7'd1;
                                        ip <= obj_val[fo][0][15:0];
                                        code_raddr <= 15'(ops_base + obj_val[fo][0][15:0]);
                                        state <= S_FETCH_WAIT;
                                    end
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
                                    // NEW: return from forEach/map/find callback → next element
                                    begin
                                        logic [15:0] md;
                                        logic truthy;
                                        md = cstack_map_arr[csp - 7'd2];
                                        truthy = (sp != 0) && (stack_tag[sp - 8'd1] != 3'd5) &&
                                                 !((stack_tag[sp - 8'd1] == 3'd0 ||
                                                    stack_tag[sp - 8'd1] == 3'd7) &&
                                                   stack[sp - 8'd1] == 32'sd0);
                                        if (md == 16'hFFFE && truthy) begin
                                            // find hit — return current element, pop callback+fe frames
                                            stack[sp - 8'd1] <=
                                                arr_val[cstack_fe_arr[csp - 7'd2][11:0]]
                                                       [cstack_fe_i[csp - 7'd2][6:0]];
                                            stack_tag[sp - 8'd1] <=
                                                arr_tag[cstack_fe_arr[csp - 7'd2][11:0]]
                                                       [cstack_fe_i[csp - 7'd2][6:0]];
                                            release_env_to(cstack_env[csp - 7'd1]);
                                            ip <= cstack_ip[csp - 7'd2];
                                            this_obj <= cstack_this[csp - 7'd2];
                                            csp <= csp - 7'd2;
                                            code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd2]);
                                            state <= S_FETCH_WAIT;
                                        end else begin
                                            if (md != 16'hFFFF && md != 16'hFFFE && sp != 0) begin
                                                arr_val[md[11:0]][cstack_fe_i[csp - 7'd2][6:0]] <=
                                                    stack[sp - 8'd1];
                                                arr_tag[md[11:0]][cstack_fe_i[csp - 7'd2][6:0]] <=
                                                    stack_tag[sp - 8'd1];
                                            end
                                            release_env_to(cstack_env[csp - 7'd1]);
                                            csp <= csp - 7'd1;
                                            if (sp != 0) sp <= sp - 8'd1;
                                            cstack_fe_i[csp - 7'd2] <= cstack_fe_i[csp - 7'd2] + 8'd1;
                                            state <= S_FOREACH;
                                        end
                                    end
                                end else if (cstack_ip[csp - 7'd1] == 16'hFFFD) begin
                                    // NEW: return from key listener → next table slot (same event)
                                    release_env_to(cstack_env[csp - 7'd1]);
                                    csp <= csp - 7'd1;
                                    kev_li <= kev_li + 2'd1;
                                    begin
                                        logic [2:0] nn;
                                        logic [15:0] nxt;
                                        nn = kev_is_down ? kd_n : ku_n;
                                        nxt = kev_is_down
                                            ? kd_slot[kev_li + 2'd1] : ku_slot[kev_li + 2'd1];
                                        if ({1'b0, kev_li} + 3'd1 < nn && nxt != 16'hFFFF) begin
                                            kev_fn <= nxt;
                                            stack[0] <= {16'd0, kev_obj};
                                            stack_tag[0] <= 3'd1;
                                            sp <= 11'd1;
                                            cstack_ip[csp - 7'd1] <= 16'hFFFD;
                                            cstack_this[csp - 7'd1] <= this_obj;
                                            cstack_isctor[csp - 7'd1] <= 1'b0;
                                            cstack_isfe[csp - 7'd1] <= 1'b0;
                                            state <= S_KEYEV;
                                        end else begin
                                            ip <= kev_ret_ip;
                                            code_raddr <= 15'(ops_base + kev_ret_ip);
                                            state <= S_FETCH_WAIT;
                                        end
                                    end
                                end else begin
                                    release_env_to(cstack_env[csp - 7'd1]);
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
                                obj_n[n_obj[12:0]] <= 0;
                                obj_cls[n_obj[12:0]] <= code_rdata[23:8];
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
                                        if (var_tag[vslot] == 3'd4) begin
                                            ctor_ip = fn_entry(vars[vslot][15:0]);
                                            // proto table is keyed by Fn obj idx (MAKE_FN heap)
                                            for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                                if (i < n_fn_proto && fn_proto_ip[i] == vars[vslot][15:0]) begin
                                                    obj_key[n_obj[12:0]][0] <= id_proto;
                                                    obj_val[n_obj[12:0]][0] <= {16'd0, fn_proto_oid[i]};
                                                    obj_tag[n_obj[12:0]][0] <= 3'd1;
                                                    obj_n[n_obj[12:0]] <= 6'd1;
                                                end
                                            end
                                        end
                                    end
                                    // copy Fn.prototype onto new object
                                    for (int i = 0; i < MAX_FN_PROTO; i++) begin
                                        if (i < n_fn_proto && fn_proto_ip[i] == ctor_ip) begin
                                            obj_key[n_obj[12:0]][0] <= id_proto;
                                            obj_val[n_obj[12:0]][0] <= {16'd0, fn_proto_oid[i]};
                                            obj_tag[n_obj[12:0]][0] <= 3'd1;
                                            obj_n[n_obj[12:0]] <= 6'd1;
                                        end
                                    end
                                    if (ctor_ip != 16'hFFFF) begin
                                        cstack_ip[csp] <= ip + 16'd1;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b1;
                                        cstack_isfe[csp] <= 1'b0;
                                        cstack_env[csp] <= env_sp;
                                        cstack_ctorobj[csp] <= n_obj;
                                        // env object at n_obj+1 (instance is n_obj)
                                        obj_cls[n_obj[12:0] + 13'd1] <= CLS_ENV;
                                        obj_n[n_obj[12:0] + 13'd1] <= 6'd1;
                                        obj_key[n_obj[12:0] + 13'd1][0] <= 16'd0;
                                        obj_val[n_obj[12:0] + 13'd1][0] <= 32'd0;
                                        obj_tag[n_obj[12:0] + 13'd1][0] <= 3'd0;
                                        if (env_sp < ENV_DEPTH[5:0]) begin
                                            env_oid[env_sp] <= n_obj + 16'd1;
                                            env_cap[env_sp] <= 1'b0;
                                            env_sp <= env_sp + 6'd1;
                                        end
                                        csp <= csp + 7'd1;
                                        this_obj <= n_obj;
                                        if (this_ok) begin
                                            vars[var_this] <= n_obj;
                                            var_tag[var_this] <= 3'd1;
                                        end
                                        if (n_obj >= 16'(MAX_OBJ - 2)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                        n_obj <= (n_obj >= 16'(MAX_OBJ - 2)) ? n_obj : (n_obj + 16'd2);
                                        ip <= ctor_ip;
                                        code_raddr <= 15'(ops_base + ctor_ip);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        // NEW: pop argc (was leaked). DOM event ctors
                                        // copy (type, options) like PYTHON bytecode.py.
                                        begin
                                            logic [7:0]  nac;
                                            logic [12:0] dst, src;
                                            logic [5:0]  nn;
                                            logic        is_dom;
                                            nac = code_rdata[31:24];
                                            dst = n_obj[12:0];
                                            obj_cls[dst] <= code_rdata[23:8];
                                            is_dom = (code_rdata[23:8] == id_kbevent)
                                                  || (code_rdata[23:8] == id_domevent)
                                                  || (code_rdata[23:8] == id_customev)
                                                  || (code_rdata[23:8] == id_mouseev);
                                            nn = 6'd0;
                                            if (is_dom && nac >= 8'd1 &&
                                                stack_tag[sp - nac] == 3'd3 &&
                                                id_type != 16'hFFFF) begin
                                                obj_key[dst][0] <= id_type;
                                                obj_val[dst][0] <= stack[sp - nac];
                                                obj_tag[dst][0] <= 3'd3;
                                                nn = 6'd1;
                                            end
                                            if (is_dom && nac >= 8'd2 &&
                                                stack_tag[sp - nac + 8'd1] == 3'd1) begin
                                                src = stack[sp - nac + 8'd1][12:0];
                                                for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                    if (s < obj_n[src] && nn < OBJ_SLOTS[5:0]) begin
                                                        obj_key[dst][nn] <= obj_key[src][s];
                                                        obj_val[dst][nn] <= obj_val[src][s];
                                                        obj_tag[dst][nn] <= obj_tag[src][s];
                                                        nn = nn + 6'd1;
                                                    end
                                                end
                                            end
                                            obj_n[dst] <= nn;
                                            stack[sp - nac] <= {16'd0, n_obj};
                                            stack_tag[sp - nac] <= 3'd1;
                                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                            sp <= (nac == 8'd0) ? (sp + 8'd1) : (sp - nac + 8'd1);
                                            next_op();
                                        end
                                    end
                                end
                            end
                            OP_CALL_METH: begin
                                // [obj, args...] a0=meth intern a1=argc
                                if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                    code_rdata[23:8] == id_push) begin
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        if (al < ARR_CAP[7:0]) begin
                                            arr_val[ai][al] <= stack[sp - 8'd1];
                                            arr_tag[ai][al] <= stack_tag[sp - 8'd1];
                                            arr_len[ai] <= al + 8'd1;
                                            // NEW: keep only if dest array is
                                            // old-space (global arr.push). Finder
                                            // new_list.push(to) is nursery — rewind.
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_obj_keep(stack_tag[sp - 8'd1],
                                                                stack[sp - 8'd1][15:0]);
                                        end
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= {24'd0, al + 8'd1};
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_fill) begin
                                    // arr.fill(v) — not ctx.fill()
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        for (int k = 0; k < ARR_CAP; k++) begin
                                            if (k < al) begin
                                                arr_val[ai][k] <= (code_rdata[31:24] >= 8'd1)
                                                    ? stack[sp - 8'd1] : 32'sd0;
                                                arr_tag[ai][k] <= (code_rdata[31:24] >= 8'd1)
                                                    ? stack_tag[sp - 8'd1] : 3'd0;
                                            end
                                        end
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <=
                                            stack[sp - 8'(code_rdata[31:24]) - 8'd1];
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd2;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           (code_rdata[23:8] == id_foreach ||
                                            code_rdata[23:8] == 16'd112 ||
                                            code_rdata[23:8] == id_map ||
                                            code_rdata[23:8] == id_find)) begin
                                    // arr.forEach(fn) / arr.map(fn) / arr.find(fn)
                                    cstack_ip[csp] <= ip + 16'd1;
                                    cstack_this[csp] <= this_obj;
                                    cstack_isctor[csp] <= 1'b0;
                                    cstack_isfe[csp] <= 1'b1;
                                    cstack_fe_arr[csp] <= stack[sp - 8'(code_rdata[31:24]) - 8'd1][15:0];
                                    cstack_fe_fn[csp] <= stack[sp - 8'd1][15:0];
                                    cstack_ctorobj[csp] <= {8'd0, fn_nparam(stack[sp - 8'd1][15:0])};
                                    cstack_fe_i[csp] <= 8'd0;
                                    if (code_rdata[23:8] == id_map) begin
                                        arr_len[n_arr[11:0]] <=
                                            arr_len[stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0]];
                                        cstack_map_arr[csp] <= n_arr;
                                        // NEW: map() output is nursery; SET_PROP
                                        // commits if stored. Do not freeze temps.
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                        n_arr <= (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (code_rdata[23:8] == id_find)
                                        cstack_map_arr[csp] <= 16'hFFFE; // find sentinel
                                    else
                                        cstack_map_arr[csp] <= 16'hFFFF;
                                    cstack_env[csp] <= env_sp;
                                    csp <= csp + 7'd1;
                                    sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                    state <= S_FOREACH;
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_unshift) begin
                                    // arr.unshift(v) — insert at 0
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] al;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                        al = arr_len[ai];
                                        if (al < ARR_CAP[7:0]) begin
                                            for (int j = ARR_CAP - 1; j > 0; j--) begin
                                                if (j <= al) begin
                                                    arr_val[ai][j] <= arr_val[ai][j - 1];
                                                    arr_tag[ai][j] <= arr_tag[ai][j - 1];
                                                end
                                            end
                                            arr_val[ai][0] <= (code_rdata[31:24] >= 8'd1)
                                                ? stack[sp - 8'd1] : 32'sd0;
                                            arr_tag[ai][0] <= (code_rdata[31:24] >= 8'd1)
                                                ? stack_tag[sp - 8'd1] : 3'd5;
                                            arr_len[ai] <= al + 8'd1;
                                            // NEW: same as push — old-space dest only
                                            // (finder result.unshift is nursery).
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_obj_keep(stack_tag[sp - 8'd1],
                                                                stack[sp - 8'd1][15:0]);
                                        end
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= {24'd0, al + 8'd1};
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_splice) begin
                                    // splice(start, n) — shift-delete (INVADERS cull)
                                    begin
                                        logic [11:0] ai;
                                        logic [7:0] st, cnt;
                                        ai = stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
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
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_join) begin
                                    // NEW: arr.join('') — hash the digit chars with the
                                    // encoder's u16 hash, then reverse-map to an interned
                                    // name so string EQ (intern-id compare) just works.
                                    // PACMAN maze wall-shape switch: neighbors.join('')=='1100'
                                    jn_arr <= stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                    jn_i <= 16'd0; jn_h <= 16'd0;
                                    jn_res <= 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    ip <= ip + 16'd1;
                                    state <= S_JOIN;
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd2 &&
                                           code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1) begin
                                    // NEW: arr.indexOf(v) — linear scan, -1 when absent (FM twin)
                                    jn_arr <= stack[sp - 8'(code_rdata[31:24]) - 8'd1][11:0];
                                    jn_i <= 16'd0;
                                    idx_v <= $signed(stack[sp - 8'(code_rdata[31:24])]);
                                    idx_t <= stack_tag[sp - 8'(code_rdata[31:24])];
                                    jn_res <= 11'(sp - 8'(code_rdata[31:24]) - 8'd1);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    ip <= ip + 16'd1;
                                    state <= S_IDXOF;
                                end else if (code_rdata[23:8] == id_replace &&
                                           code_rdata[31:24] >= 8'd2 &&
                                           (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd3 ||
                                            (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                             obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == CLS_DYNSTR))) begin
                                    // String.replace — dynstr or interned 1-char; pattern
                                    // is packed RegExp or interned/int. Any HTML.
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv, p0;
                                        logic [2:0]  rt, pt;
                                        logic [31:0] preg;
                                        ac = code_rdata[31:24];
                                        recv = stack[sp - ac - 8'd1][15:0];
                                        rt = stack_tag[sp - ac - 8'd1];
                                        p0 = stack[sp - ac][15:0];
                                        pt = stack_tag[sp - ac];
                                        json_res <= 11'(sp - ac - 8'd1);
                                        sp <= sp - ac;
                                        ip <= ip + 16'd1;
                                        if (rt == 3'd1) begin
                                            json_src <= obj_val[recv[12:0]][0][13:0];
                                            json_srclen <= obj_val[recv[12:0]][1][13:0];
                                        end else begin
                                            // interned 1-char: hash == byte when len==1
                                            json_mem[0] <= name_hash_tbl[recv[9:0]][7:0];
                                            json_src <= 14'd0;
                                            json_srclen <= (name_len_tbl[recv[9:0]] == 8'd1)
                                                ? 14'd1 : 14'd0;
                                        end
                                        repl_g <= 1'b0; repl_nlen <= 8'd1; repl_pat1 <= 8'd0;
                                        repl_pat0 <= 8'd0;
                                        if (pt == 3'd1 && obj_cls[p0[12:0]] == CLS_REGEX) begin
                                            preg = obj_val[p0[12:0]][0];
                                            repl_pat0 <= preg[7:0];
                                            repl_pat1 <= preg[15:8];
                                            repl_nlen <= preg[23:16];
                                            repl_g <= preg[24];
                                        end else if (pt == 3'd3 && name_len_tbl[p0[9:0]] == 8'd1)
                                            repl_pat0 <= name_hash_tbl[p0[9:0]][7:0];
                                        else if (pt == 3'd0)
                                            repl_pat0 <= 8'(fxi(stack[sp - ac], pt) + 32'sd48);
                                        // replacement: int → digit, intern 1-char, else '0'
                                        if (stack_tag[sp - 8'd1] == 3'd3 &&
                                            name_len_tbl[stack[sp - 8'd1][9:0]] == 8'd1)
                                            repl_rch <= name_hash_tbl[stack[sp - 8'd1][9:0]][7:0];
                                        else if (stack_tag[sp - 8'd1] == 3'd0)
                                            repl_rch <= 8'(fxi(stack[sp - 8'd1], 3'd0) + 32'sd48);
                                        else
                                            repl_rch <= 8'h30;
                                        json_rp <= (rt == 3'd1) ? obj_val[recv[12:0]][0][13:0] : 14'd0;
                                        json_dst <= (rt == 3'd1)
                                            ? (obj_val[recv[12:0]][0][13:0] + obj_val[recv[12:0]][1][13:0])
                                            : 14'd1;
                                        json_wp <= (rt == 3'd1)
                                            ? (obj_val[recv[12:0]][0][13:0] + obj_val[recv[12:0]][1][13:0])
                                            : 14'd1;
                                        repl_did <= 1'b0;
                                        state <= S_REPL;
                                    end
                                end else if (code_rdata[23:8] == id_indexof &&
                                           code_rdata[31:24] >= 8'd1 &&
                                           stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                           obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == CLS_DYNSTR) begin
                                    // dynstr.indexOf(v) — JS coerces number 0 → "0"
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] recv;
                                        ac = code_rdata[31:24];
                                        recv = stack[sp - ac - 8'd1][15:0];
                                        json_src <= obj_val[recv[12:0]][0][13:0];
                                        json_srclen <= obj_val[recv[12:0]][1][13:0];
                                        json_rp <= obj_val[recv[12:0]][0][13:0];
                                        json_res <= 11'(sp - ac - 8'd1);
                                        if (stack_tag[sp - ac] == 3'd3 &&
                                            name_len_tbl[stack[sp - ac][9:0]] == 8'd1)
                                            idx_needle <= name_hash_tbl[stack[sp - ac][9:0]][7:0];
                                        else
                                            idx_needle <= 8'(fxi(stack[sp - ac], stack_tag[sp - ac]) + 32'sd48);
                                        sp <= sp - ac;
                                        ip <= ip + 16'd1;
                                        state <= S_IDXSTR;
                                    end
                                end else if (code_rdata[23:8] == id_ael) begin
                                    // el.addEventListener(type, fn) — table, not last-wins
                                    if (stack[sp - 8'd2][15:0] == id_keydown)
                                        add_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_keyup)
                                        add_key_listener(1'b0, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_click && click_fn == 16'hFFFF)
                                        click_fn <= stack[sp - 8'd1][15:0];
                                    stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'sd0;
                                    stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd5;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rel) begin
                                    // el.removeEventListener(type, fn)
                                    if (stack[sp - 8'd2][15:0] == id_keydown)
                                        remove_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                                    if (stack[sp - 8'd2][15:0] == id_keyup)
                                        remove_key_listener(1'b0, stack[sp - 8'd1][15:0]);
                                    stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'sd0;
                                    stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd5;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_disp) begin
                                    // el.dispatchEvent(ev) — fire listeners now (PYTHON parity)
                                    if (code_rdata[31:24] >= 8'd1 &&
                                        stack_tag[sp - 8'd1] == 3'd1 &&
                                        kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                        logic [15:0] oid;
                                        oid = stack[sp - 8'd1][15:0];
                                        kev_obj <= oid;
                                        kev_fn <= kd_slot[0];
                                        kev_li <= 2'd0;
                                        kev_is_down <= 1'b1;
                                        kev_ret_ip <= ip + 16'd1;
                                        stack[0] <= {16'd0, oid};
                                        stack_tag[0] <= 3'd1;
                                        sp <= 11'd1;
                                        cstack_ip[csp] <= 16'hFFFD;
                                        cstack_this[csp] <= this_obj;
                                        cstack_isctor[csp] <= 1'b0;
                                        cstack_isfe[csp] <= 1'b0;
                                        state <= S_KEYEV;
                                    end else begin
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= 32'sd1;
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
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
                                        enter_captured_fn(click_fn);
                                        csp <= csp + 7'd1;
                                        ip <= fn_entry(click_fn);
                                        code_raddr <= 15'(ops_base + fn_entry(click_fn));
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_now ||
                                           code_rdata[23:8] == id_gettime) begin
                                    // Date.now() / date.getTime() — pure READ of the frame
                                    // clock (advances once per frame in S_WAIT_FRAME, FM twin)
                                    begin
                                        stack[sp - 8'(code_rdata[31:24]) - 8'd1] <= time_ms;
                                        stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] <= 3'd0;
                                        sp <= sp - 8'(code_rdata[31:24]);
                                        next_op();
                                    end
                                end else if (stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd1 &&
                                            obj_cls[stack[sp - 8'(code_rdata[31:24]) - 8'd1][12:0]] == 16'hFFFD &&
                                            code_rdata[31:24] == 8'd0) begin
                                    // (new Date()).getTime() even if intern id_gettime missed
                                    // — pure READ of the frame clock (FM twin)
                                    begin
                                        stack[sp - 8'd1] <= time_ms;
                                        stack_tag[sp - 8'd1] <= 3'd0;
                                        next_op();
                                    end
                                end else if (code_rdata[23:8] == id_bind &&
                                           stack_tag[sp - 8'(code_rdata[31:24]) - 8'd1] == 3'd4) begin
                                    // fn.bind(this) — leave the fn (PYTHON copies bound_this)
                                    // NEW: FUNCTION receivers only (FM cls_name=="Fn") —
                                    // swallowing stage.bind('keydown',cb) killed PACMAN keys
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_assign) begin
                                    // Object.assign(target, ...src) — append src slots onto target
                                    begin
                                        logic [12:0] ti, si;
                                        logic [5:0] tn;
                                        logic [7:0] aca;
                                        aca = code_rdata[31:24];
                                        ti = stack[sp - aca][12:0];
                                        tn = obj_n[ti];
                                        if (stack_tag[sp - aca] == 3'd1) begin
                                            // NEW: overwrite keys the target already has
                                            // instead of appending duplicates — repeated
                                            // Item reset()/assign filled all 32 slots and
                                            // then DROPPED x/y (PACMAN items stuck at 0,0)
                                            logic [5:0] tn0;
                                            tn0 = obj_n[ti];
                                            for (int src = 0; src < 3; src++) begin
                                                if (src < aca - 8'd1) begin
                                                    si = stack[sp - aca + 8'(src) + 8'd1][12:0];
                                                    if (stack_tag[sp - aca + 8'(src) + 8'd1] == 3'd1) begin
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            logic hitp;
                                                            logic [5:0] hidx;
                                                            hitp = 1'b0; hidx = 6'd0;
                                                            for (int t = 0; t < OBJ_SLOTS; t++) begin
                                                                if (t < tn0 && obj_key[ti][t] == obj_key[si][s]) begin
                                                                    hitp = 1'b1;
                                                                    hidx = 6'(t);
                                                                end
                                                            end
                                                            if (s < obj_n[si]) begin
                                                                if (hitp) begin
                                                                    obj_val[ti][hidx] <= obj_val[si][s];
                                                                    obj_tag[ti][hidx] <= obj_tag[si][s];
                                                                end else if (tn < OBJ_SLOTS[5:0]) begin
                                                                    obj_key[ti][tn] <= obj_key[si][s];
                                                                    obj_val[ti][tn] <= obj_val[si][s];
                                                                    obj_tag[ti][tn] <= obj_tag[si][s];
                                                                    tn = tn + 6'd1;
                                                                end
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
                                    saved_sx <= ctx_sx; saved_sy <= ctx_sy; // NEW: FM saves scale too
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_restore) begin
                                    ctx_tx <= saved_tx; ctx_ty <= saved_ty;
                                    ctx_sx <= saved_sx; ctx_sy <= saved_sy; // NEW
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_translate) begin
                                    ctx_tx <= ctx_tx + sti(sp - 9'd2);
                                    ctx_ty <= ctx_ty + sti(sp - 9'd1);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_settransform &&
                                           code_rdata[31:24] >= 8'd6) begin
                                    // NEW: setTransform(a,b,c,d,e,f) — FM spec
                                    // (bytecode.py): _sx=a or 1, _sy=d or 1,
                                    // _tx=e, _ty=f. Shear b,c ignored like FM.
                                    ctx_sx <= (stfx(sp - 9'd6) == 32'sd0) ? FX_ONE : stfx(sp - 9'd6);
                                    ctx_sy <= (stfx(sp - 9'd3) == 32'sd0) ? FX_ONE : stfx(sp - 9'd3);
                                    ctx_tx <= sti(sp - 9'd2);
                                    ctx_ty <= sti(sp - 9'd1);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_rotate) begin
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_beginpath ||
                                           code_rdata[23:8] == id_closepath) begin
                                    // NEW: beginPath resets the command buffer;
                                    // closePath is a no-op like FM _raster_path "Z"
                                    if (code_rdata[23:8] == id_beginpath) pc_n <= 5'd0;
                                    path_kind <= 2'd0;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_arc && code_rdata[31:24] >= 8'd3) begin
                                    // NEW: record raw fx args (FM records argv; _xf at raster)
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op[pc_n[3:0]] <= 2'd3;
                                        pc_a1[pc_n[3:0]] <= stfx(sp - 9'(code_rdata[31:24]));
                                        pc_a2[pc_n[3:0]] <= stfx(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_a3[pc_n[3:0]] <= stfx(sp - 9'(code_rdata[31:24]) + 9'd2);
                                        pc_a4[pc_n[3:0]] <= (code_rdata[31:24] > 8'd3)
                                            ? stfx(sp - 9'(code_rdata[31:24]) + 9'd3) : 32'sd0;
                                        pc_a5[pc_n[3:0]] <= (code_rdata[31:24] > 8'd4)
                                            ? stfx(sp - 9'(code_rdata[31:24]) + 9'd4) : 32'sd0;
                                        pc_ccw[pc_n[3:0]] <= (code_rdata[31:24] > 8'd5)
                                            && (stack[sp - 9'd1] != 32'd0);
                                        pc_n <= pc_n + 5'd1;
                                    end else dbg_path_ovf <= dbg_path_ovf + 16'd1;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if ((code_rdata[23:8] == id_moveto ||
                                            code_rdata[23:8] == id_lineto) &&
                                           code_rdata[31:24] >= 8'd2) begin
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op[pc_n[3:0]] <= (code_rdata[23:8] == id_moveto) ? 2'd0 : 2'd1;
                                        pc_a1[pc_n[3:0]] <= stfx(sp - 9'(code_rdata[31:24]));
                                        pc_a2[pc_n[3:0]] <= stfx(sp - 9'(code_rdata[31:24]) + 9'd1);
                                        pc_n <= pc_n + 5'd1;
                                    end else dbg_path_ovf <= dbg_path_ovf + 16'd1;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_quadcurve &&
                                           code_rdata[31:24] >= 8'd4) begin
                                    // NEW: quadraticCurveTo(cx,cy,x,y)
                                    if (pc_n < 5'(PATH_MAX)) begin
                                        pc_op[pc_n[3:0]] <= 2'd2;
                                        pc_a1[pc_n[3:0]] <= stfx(sp - 9'd4);
                                        pc_a2[pc_n[3:0]] <= stfx(sp - 9'd3);
                                        pc_a3[pc_n[3:0]] <= stfx(sp - 9'd2);
                                        pc_a4[pc_n[3:0]] <= stfx(sp - 9'd1);
                                        pc_n <= pc_n + 5'd1;
                                    end else dbg_path_ovf <= dbg_path_ovf + 16'd1;
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    next_op();
                                end else if (code_rdata[23:8] == id_fill ||
                                           code_rdata[23:8] == id_stroke) begin
                                    // NEW: walk the whole command buffer (FM
                                    // _raster_path). Path survives fill() —
                                    // only beginPath clears it, like FM.
                                    color <= fill_style_i;
                                    path_stroke <= (code_rdata[23:8] == id_stroke);
                                    sp <= sp - 8'(code_rdata[31:24]);
                                    ip <= ip + 16'd1;
                                    pi <= 5'd0;
                                    path_active <= 1'b1;
                                    state <= S_PWALK;
                                end else if (code_rdata[23:8] == id_filltext) begin
                                    color <= fill_style_i;
                                    if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                        // NEW: scale the text position (glyphs are
                                        // still the 64x8 stub — rtl-canvas debt)
                                        xf_x <= stfx(sp - 9'd2); xf_y <= stfx(sp - 9'd1);
                                        xf_w <= 32'sd64 <<< 16; xf_h <= 32'sd8 <<< 16;
                                        xf_dst <= 2'd2;
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip <= ip + 16'd1;
                                        state <= S_XF_MUL;
                                    end else begin
                                        rx <= clip_u(sti(sp - 9'd2) + ctx_tx, MW);
                                        ry <= clip_u(sti(sp - 9'd1) + ctx_ty, MH);
                                        rw <= 10'd64; rh <= 10'd8;
                                        x <= clip_u(sti(sp - 9'd2) + ctx_tx, MW);
                                        y <= clip_u(sti(sp - 9'd1) + ctx_ty, MH);
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip <= ip + 16'd1;
                                        state <= S_RECT;
                                    end
                                end else if (code_rdata[23:8] == id_drawimage) begin
                                    // real sprite blit when Image.src was jmr:spr:N
                                    begin
                                        logic [15:0] ioid;
                                        logic [7:0] ac, si;
                                        ac = code_rdata[31:24];
                                        // args: img at sp-ac, then dx,dy[,dw,dh] or 9-arg sheet
                                        ioid = stack[sp - ac][15:0];
                                        si = 8'(obj_cls[ioid[12:0]][3:0]); // NEW: 4-bit idx (16 sprites)
                                        if (obj_cls[ioid[12:0]][15:4] == 12'hFFC && {1'b0, si} < {4'd0, n_spr}) begin
                                            dbg_di_hit <= dbg_di_hit + 16'd1;
                                            blit_si <= si;
                                            if (ac >= 8'd9) begin
                                                // NEW: 16-bit source window (full-res ASET sheets)
                                                blit_sx <= clip_src(sti(sp - 9'd8));
                                                blit_sy <= clip_src(sti(sp - 9'd7));
                                                blit_sw <= clip_src(sti(sp - 9'd6));
                                                blit_sh <= clip_src(sti(sp - 9'd5));
                                            end else begin
                                                blit_sx <= 16'd0; blit_sy <= 16'd0;
                                                blit_sw <= spr_ww[si[3:0]]; blit_sh <= spr_hh[si[3:0]];
                                            end
                                            if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                                // NEW: scaled dest — FM _xf on dx,dy,dw,dh
                                                // (DONKEY setTransform world→glass)
                                                if (ac >= 8'd5) begin
                                                    xf_x <= stfx(sp - 9'd4); xf_y <= stfx(sp - 9'd3);
                                                    xf_w <= stfx(sp - 9'd2); xf_h <= stfx(sp - 9'd1);
                                                end else begin
                                                    xf_x <= stfx(sp - 9'd2); xf_y <= stfx(sp - 9'd1);
                                                    xf_w <= 32'(spr_ww[si[3:0]]) <<< 16;
                                                    xf_h <= 32'(spr_hh[si[3:0]]) <<< 16;
                                                end
                                                xf_dst <= 2'd1;
                                                sp <= sp - ac - 8'd1;
                                                ip <= ip + 16'd1;
                                                state <= S_XF_MUL;
                                            end else begin
                                                if (ac >= 8'd5) begin
                                                    rx <= clip_u(sti(sp - 9'd4) + ctx_tx, MW);
                                                    ry <= clip_u(sti(sp - 9'd3) + ctx_ty, MH);
                                                    rw <= clip_sz(sti(sp - 9'd2), clip_u(sti(sp - 9'd4) + ctx_tx, MW), MW);
                                                    rh <= clip_sz(sti(sp - 9'd1), clip_u(sti(sp - 9'd3) + ctx_ty, MH), MH);
                                                end else begin
                                                    rx <= clip_u(sti(sp - 9'd2) + ctx_tx, MW);
                                                    ry <= clip_u(sti(sp - 9'd1) + ctx_ty, MH);
                                                    // dest = natural size, clipped to the glass
                                                    rw <= (spr_ww[si[3:0]] > 16'(MW)) ? 10'(MW) : spr_ww[si[3:0]][9:0];
                                                    rh <= (spr_hh[si[3:0]] > 16'(MH)) ? 10'(MH) : spr_hh[si[3:0]][9:0];
                                                end
                                                x <= 10'd0; y <= 10'd0;
                                                sp <= sp - ac - 8'd1;
                                                ip <= ip + 16'd1;
                                                state <= S_BLIT;
                                            end
                                        end else begin
                                            // no sprite — skip (do not paint a giant magenta box)
                                            dbg_di_miss <= dbg_di_miss + 16'd1;
                                            sp <= sp - ac - 8'd1;
                                            next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_getimgdata) begin
                                    // ctx.getImageData(x,y,w,h) — copy back buffer (FM twin)
                                    begin
                                        logic signed [31:0] gx, gy, gw, gh;
                                        logic [9:0] x0, y0, ww, hh;
                                        logic [7:0] acg;
                                        acg = code_rdata[31:24];
                                        gx = (acg >= 8'd1) ? sti(sp - acg) : 32'sd0;
                                        gy = (acg >= 8'd2) ? sti(sp - acg + 8'd1) : 32'sd0;
                                        gw = (acg >= 8'd3) ? sti(sp - acg + 8'd2) : 32'sd0;
                                        gh = (acg >= 8'd4) ? sti(sp - acg + 8'd3) : 32'sd0;
                                        x0 = clip_u(gx, MW);
                                        y0 = clip_u(gy, MH);
                                        ww = clip_sz(gw, x0, MW);
                                        hh = clip_sz(gh, y0, MH);
                                        imgd_x0 <= x0; imgd_y0 <= y0;
                                        imgd_w <= ww; imgd_h <= hh;
                                        imgd_x <= x0; imgd_y <= y0;
                                        imgd_i <= 19'd0;
                                        imgd_n <= 19'(ww) * 19'(hh);
                                        imgd_armed <= 1'b0;
                                        imgd_res <= 11'(sp - acg - 8'd1);
                                        sp <= sp - acg - 8'd1;
                                        ip <= ip + 16'd1;
                                        fb_dump_sel <= 1'b1;
                                        fb_dump_addr <= 19'(y0) * 19'(MW) + 19'(x0);
                                        state <= S_IMGD_GET;
                                    end
                                end else if (code_rdata[23:8] == id_putimgdata) begin
                                    // ctx.putImageData(img, dx, dy) — blit snapshot to back
                                    begin
                                        logic [7:0] acp;
                                        logic [15:0] src;
                                        acp = code_rdata[31:24];
                                        src = (acp >= 8'd1) ? stack[sp - acp][15:0] : 16'd0;
                                        if (acp >= 8'd1 && stack_tag[sp - acp] == 3'd1 &&
                                            obj_cls[src[12:0]] == CLS_IMGD) begin
                                            imgd_x0 <= (acp >= 8'd2) ? clip_u(sti(sp - acp + 8'd1), MW) : 10'd0;
                                            imgd_y0 <= (acp >= 8'd3) ? clip_u(sti(sp - acp + 8'd2), MH) : 10'd0;
                                            imgd_w <= obj_val[src[12:0]][0][9:0];
                                            imgd_h <= obj_val[src[12:0]][1][9:0];
                                            imgd_x <= 10'd0; imgd_y <= 10'd0;
                                            imgd_i <= 19'd0;
                                            sp <= sp - acp - 8'd1;
                                            ip <= ip + 16'd1;
                                            state <= S_IMGD_PUT;
                                        end else begin
                                            sp <= sp - acp;
                                            next_op();
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_fillrect ||
                                           code_rdata[23:8] == id_clearrect) begin
                                    // ctx.fillRect / clearRect(x,y,w,h) — intern ids only
                                    // (argc-4 fallback retired: it swallowed getImageData)
                                    color <= (code_rdata[23:8] == id_clearrect) ? 8'd0 : fill_style_i;
                                    if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                        // NEW: scaled rect — FM _xf (DONKEY girders)
                                        xf_x <= stfx(sp - 9'd4); xf_y <= stfx(sp - 9'd3);
                                        xf_w <= stfx(sp - 9'd2); xf_h <= stfx(sp - 9'd1);
                                        xf_dst <= 2'd0;
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip <= ip + 16'd1;
                                        state <= S_XF_MUL;
                                    end else begin
                                        begin
                                            logic [9:0] tw, th, tx, ty;
                                            tx = clip_u(sti(sp - 9'd4) + ctx_tx, MW);
                                            ty = clip_u(sti(sp - 9'd3) + ctx_ty, MH);
                                            tw = clip_sz(sti(sp - 9'd2), tx, MW);
                                            th = clip_sz(sti(sp - 9'd1), ty, MH);
                                            rx <= tx; ry <= ty; rw <= tw; rh <= th;
                                            x <= tx; y <= ty;
                                        end
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip <= ip + 16'd1; // else S_RECT re-fetches this fillRect forever
                                        state <= S_RECT;
                                    end
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
                                                if (c < n_cls && cls_name[c] == obj_cls[oid[12:0]]) begin
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
                                            cstack_env[csp] <= env_sp;
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
                                                logic [12:0] pi;
                                                fip = 16'hFFFF;
                                                pi = 11'd0;
                                                if (ot == 3'd1) begin
                                                    for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                        if (s < obj_n[oid[12:0]] &&
                                                            obj_key[oid[12:0]][s] == code_rdata[23:8] &&
                                                            obj_tag[oid[12:0]][s] == 3'd4)
                                                            fip = obj_val[oid[12:0]][s][15:0];
                                                    end
                                                    if (fip == 16'hFFFF) begin
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            if (s < obj_n[oid[12:0]] &&
                                                                obj_key[oid[12:0]][s] == id_proto &&
                                                                obj_tag[oid[12:0]][s] == 3'd1)
                                                                pi = obj_val[oid[12:0]][s][12:0];
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
                                                    enter_captured_fn(fip);
                                                    csp <= csp + 7'd1;
                                                    this_obj <= oid;
                                                    if (this_ok) begin
                                                        vars[var_this] <= oid;
                                                        var_tag[var_this] <= 3'd1;
                                                    end
                                                    ip <= fn_entry(fip);
                                                    code_raddr <= 15'(ops_base + fn_entry(fip));
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
                            rx <= clip_u(sti(sp - 9'd5), MW);
                            ry <= clip_u(sti(sp - 9'd4), MH);
                            rw <= clip_sz(sti(sp - 9'd3), clip_u(sti(sp - 9'd5), MW), MW);
                            rh <= clip_sz(sti(sp - 9'd2), clip_u(sti(sp - 9'd4), MH), MH);
                            x  <= clip_u(sti(sp - 9'd5), MW);
                            y  <= clip_u(sti(sp - 9'd4), MH);
                            sp <= sp - 8'd5;
                            state <= S_RECT;
                        end
                        8'd3: begin
                            fb_swap <= 1'b1;
                            did_swap <= 1'b1; // explicit present — skip pass-end auto-swap
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
                            // Present only if the pass did not already swap —
                            // swapBuffers()+startLoop() double-swap left front
                            // permanently on the undrawn bank (INVADERS.JS blank)
                            if (!did_swap) fb_swap <= 1'b1;
                            did_swap <= 1'b0;
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
                        8'd10: begin // Math.floor — fx floors to int (arith >>16)
                            stack[sp - 8'd1] <= fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                            stack_tag[sp - 8'd1] <= 3'd0;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd11: begin // Math.abs — keeps fx tag (abs(0.5)=0.5)
                            stack[sp - 8'd1] <= stack[sp - 8'd1][31] ?
                                -stack[sp - 8'd1] : stack[sp - 8'd1];
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd12: begin // min — fx-aware compare, keep the winner's tag
                            if (fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], stack_tag[sp - 8'd1] == 3'd7)
                              < fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], stack_tag[sp - 8'd2] == 3'd7)) begin
                                stack[sp - 8'd2] <= stack[sp - 8'd2];
                                stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd2];
                            end else begin
                                stack[sp - 8'd2] <= stack[sp - 8'd1];
                                stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                            end
                            sp <= sp - 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd13: begin // max
                            if (fxlift(stack[sp - 8'd2], stack_tag[sp - 8'd2], stack_tag[sp - 8'd1] == 3'd7)
                              > fxlift(stack[sp - 8'd1], stack_tag[sp - 8'd1], stack_tag[sp - 8'd2] == 3'd7)) begin
                                stack[sp - 8'd2] <= stack[sp - 8'd2];
                                stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd2];
                            end else begin
                                stack[sp - 8'd2] <= stack[sp - 8'd1];
                                stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                            end
                            sp <= sp - 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd15: begin // NEW: Math.sqrt — bit-serial, Q16.16 in/out
                            begin
                                logic signed [31:0] v;
                                v = (stack_tag[sp - 8'd1] == 3'd7)
                                    ? $signed(stack[sp - 8'd1])
                                    : ($signed(stack[sp - 8'd1]) <<< 16);
                                if (v < 0) v = 32'sd0; // FM NaN → draw-safe 0
                                sq_rad <= {v, 16'd0}; // sqrt(v * 2^16) = Q16.16 root
                                sq_rem <= 26'd0;
                                sq_root <= 24'd0;
                                sq_i <= 5'd23;
                                state <= S_SQRT;
                            end
                        end
                        8'd14: begin // NEW: Math.random → Q16.16 fraction 0..1
                            // xorshift32 (was 1-bit LFSR shift: consecutive values
                            // ~2× apart → INVADERS stars spawned on a diagonal lattice)
                            begin
                                logic [31:0] x1, x2, x3;
                                x1 = lfsr ^ (lfsr << 13);
                                x2 = x1 ^ (x1 >> 17);
                                x3 = x2 ^ (x2 << 5);
                                lfsr <= x3;
                                stack[sp] <= {16'd0, x3[31:16]};
                            end
                            stack_tag[sp] <= 3'd7;
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
                            if (stack[sp - 8'd2][15:0] == id_keydown)
                                add_key_listener(1'b1, stack[sp - 8'd1][15:0]);
                            if (stack[sp - 8'd2][15:0] == id_keyup)
                                add_key_listener(1'b0, stack[sp - 8'd1][15:0]);
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
                            obj_n[n_obj[12:0]] <= 0;
                            obj_cls[n_obj[12:0]] <= 16'hFFFD;
                            stack[sp] <= {16'd0, n_obj};
                            stack_tag[sp] <= 3'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd26: begin // Image() — stub size so onload scale is nonzero
                            obj_n[n_obj[12:0]] <= 5'd2;
                            obj_cls[n_obj[12:0]] <= 16'hFFC0;
                            obj_key[n_obj[12:0]][0] <= id_width;
                            obj_val[n_obj[12:0]][0] <= 32'sd300;
                            obj_tag[n_obj[12:0]][0] <= 3'd0;
                            obj_key[n_obj[12:0]][1] <= id_height;
                            obj_val[n_obj[12:0]][1] <= 32'sd200;
                            obj_tag[n_obj[12:0]][1] <= 3'd0;
                            stack[sp] <= {16'd0, n_obj};
                            stack_tag[sp] <= 3'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd27: begin // requestAnimationFrame — keep Fn obj idx
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
                        8'd28, 8'd29: begin // setTimeout / setInterval — frame delay queue
                            if (to_n < 4'd8 && nat_argc >= 8'd1) begin
                                logic signed [31:0] ms;
                                logic [11:0] fr;
                                ms = (nat_argc >= 8'd2)
                                    ? fxi(stack[sp - nat_argc[7:0] + 8'd1],
                                          stack_tag[sp - nat_argc[7:0] + 8'd1])
                                    : 32'sd0;
                                if (ms < 0) ms = 32'sd0;
                                fr = (ms < 32'sd17) ? 12'd1 : 12'(ms / 32'sd17);
                                to_fn[to_n] <= stack[sp - nat_argc[7:0]][15:0];
                                to_delay[to_n] <= fr;
                                to_period[to_n] <= (nat_id == 8'd29) ? fr : 12'd0;
                                to_id[to_n] <= to_seq;
                                to_n <= to_n + 4'd1;
                                to_seq <= to_seq + 16'd1;
                            end else if (nat_argc >= 8'd1)
                                dbg_to_ovf <= dbg_to_ovf + 16'd1;
                            sp <= sp - nat_argc[7:0];
                            stack[sp - nat_argc[7:0]] <= {16'd0, to_seq};
                            stack_tag[sp - nat_argc[7:0]] <= 3'd0;
                            sp <= sp - nat_argc[7:0] + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd30, 8'd31: begin // clearTimeout / clearInterval
                            if (nat_argc >= 8'd1) begin
                                logic [15:0] want;
                                integer i, j;
                                want = stack[sp - nat_argc[7:0]][15:0];
                                j = 0;
                                for (i = 0; i < 8; i++) begin
                                    if (i < to_n && to_id[i] != want) begin
                                        to_fn[j] <= to_fn[i];
                                        to_delay[j] <= to_delay[i];
                                        to_period[j] <= to_period[i];
                                        to_id[j] <= to_id[i];
                                        j = j + 1;
                                    end
                                end
                                to_n <= 4'(j);
                            end
                            sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 32'sd0;
                            stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd5;
                            sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd36, 8'd37: begin // removeEventListener
                            if (nat_argc >= 8'd2) begin
                                if (stack[sp - nat_argc[7:0]][15:0] == id_keydown)
                                    remove_key_listener(1'b1, stack[sp - nat_argc[7:0] + 8'd1][15:0]);
                                if (stack[sp - nat_argc[7:0]][15:0] == id_keyup)
                                    remove_key_listener(1'b0, stack[sp - nat_argc[7:0] + 8'd1][15:0]);
                            end
                            sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 32'sd0;
                            stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd5;
                            sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd38, 8'd39: begin // dispatchEvent — fire listeners now (PYTHON parity)
                            if (nat_argc >= 8'd1 && stack_tag[sp - nat_argc[7:0]] == 3'd1
                                && kd_n != 3'd0 && kd_slot[0] != 16'hFFFF) begin
                                logic [15:0] oid;
                                oid = stack[sp - nat_argc[7:0]][15:0];
                                kev_obj <= oid;
                                kev_fn <= kd_slot[0];
                                kev_li <= 2'd0;
                                kev_is_down <= 1'b1;
                                kev_ret_ip <= ip; // OP_CALL already did ip+1
                                stack[0] <= {16'd0, oid};
                                stack_tag[0] <= 3'd1;
                                sp <= 11'd1;
                                cstack_ip[csp] <= 16'hFFFD;
                                cstack_this[csp] <= this_obj;
                                cstack_isctor[csp] <= 1'b0;
                                cstack_isfe[csp] <= 1'b0;
                                state <= S_KEYEV;
                            end else begin
                                sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 32'sd1;
                                stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd0;
                                sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
                        end
                        8'd23: begin // JSON.parse
                            json_res <= 11'(sp - nat_argc[7:0]);
                            if (nat_argc >= 8'd1 &&
                                stack_tag[sp - nat_argc[7:0]] == 3'd1 &&
                                obj_cls[stack[sp - nat_argc[7:0]][12:0]] == CLS_DYNSTR) begin
                                json_src <= obj_val[stack[sp - nat_argc[7:0]][12:0]][0][13:0];
                                json_srclen <= obj_val[stack[sp - nat_argc[7:0]][12:0]][1][13:0];
                                json_rp <= obj_val[stack[sp - nat_argc[7:0]][12:0]][0][13:0];
                                js_sp <= 6'd0;
                                js_ph[0] <= 3'd0;
                                json_pph <= 3'd0;
                                sp <= sp - nat_argc[7:0];
                                state <= S_JSON_PARSE;
                            end else begin
                                stack[sp - nat_argc[7:0]] <= 32'sd0;
                                stack_tag[sp - nat_argc[7:0]] <= 3'd5;
                                sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
                        end
                        8'd24: begin // JSON.stringify
                            json_res <= 11'(sp - nat_argc[7:0]);
                            json_wp <= 14'd0;
                            js_sp <= 6'd1;
                            js_tag[0] <= (nat_argc >= 8'd1) ? stack_tag[sp - nat_argc[7:0]] : 3'd5;
                            js_val[0] <= (nat_argc >= 8'd1) ? stack[sp - nat_argc[7:0]] : 32'sd0;
                            js_i[0] <= 8'd0;
                            js_ph[0] <= 3'd0;
                            sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                            state <= S_JSON;
                        end
                        8'd34: begin // Array(n) — length n, holes undefined
                            begin
                                logic [7:0] aln;
                                aln = (nat_argc >= 8'd1) ?
                                    ((fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]]) > ARR_CAP)
                                        ? ARR_CAP[7:0]
                                        : (fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]]) < 0)
                                            ? 8'd0
                                            : 8'(fxi(stack[sp - nat_argc[7:0]], stack_tag[sp - nat_argc[7:0]])))
                                    : 8'd0;
                                arr_len[n_arr[11:0]] <= aln;
                                for (int k = 0; k < ARR_CAP; k++) begin
                                    arr_val[n_arr[11:0]][k] <= 32'sd0;
                                    arr_tag[n_arr[11:0]][k] <= 3'd5;
                                end
                                sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                stack[sp - nat_argc[7:0]] <= {16'd0, n_arr};
                                stack_tag[sp - nat_argc[7:0]] <= 3'd2;
                                // NEW: Array(n) is nursery (finder steps).
                                if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                n_arr <= (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                sp <= (nat_argc == 0) ? (sp + 8'd1) : (sp - nat_argc[7:0] + 8'd1);
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
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
                        if (boot_clr) begin
                            fb_swap <= 1'b1;
                            clr_idx <= '0;
                            if (boot_clr_n == 2'd1) begin
                                boot_clr <= 1'b0;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else
                                boot_clr_n <= boot_clr_n - 2'd1;
                        end else begin
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    end else clr_idx <= clr_idx + 19'd1;
                end
                S_RECT: begin
                    if (rw == 10'd0 || rh == 10'd0) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        // NEW: bring-up latch (first pixel only)
                        if (dbg_rect_n < 5'd16 && x == rx && y == ry) begin
                            dbg_rect[dbg_rect_n[3:0]] <= {color, rx, ry, rw, rh};
                            dbg_rect_n <= dbg_rect_n + 5'd1;
                        end
                        if (color != 8'd0) dbg_rect_px <= dbg_rect_px + 32'd1;
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
                    // NEW: arc_ang = angular pie test (FM fill_circle a0/a1) via
                    // cross products against the sector edge vectors (no atan2)
                    begin
                        logic signed [11:0] dx, dy;
                        logic [21:0] d2, r2, r2in;
                        logic signed [31:0] c1, c2;
                        logic ang_ok;
                        dx = $signed({2'b0, x}) - $signed({2'b0, rx});
                        dy = $signed({2'b0, y}) - $signed({2'b0, ry});
                        d2 = 22'(dx * dx + dy * dy);
                        r2 = 22'(rw) * 22'(rw);
                        r2in = (rw <= 10'd1) ? 22'd0 : 22'(rw - 10'd1) * 22'(rw - 10'd1);
                        c1 = 32'(vs_x) * 32'(dy) - 32'(vs_y) * 32'(dx);
                        c2 = 32'(dx) * 32'(ve_y) - 32'(dy) * 32'(ve_x);
                        ang_ok = (!arc_ang) || (d2 == 22'd0)
                               || (arc_sweep_gt_pi ? (c1 >= 0 || c2 >= 0)
                                                   : (c1 >= 0 && c2 >= 0));
                        if (x < 10'(MW) && y < 10'(MH) && d2 <= r2 && ang_ok
                            && (!path_stroke || d2 >= r2in)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(y) * 19'(MW) + 19'(x);
                            fb_wdata <= color;
                            dbg_circ_px <= dbg_circ_px + 32'd1; // flood hunt
                        end
                    end
                    if (x >= rx + rw || x == 10'(MW - 1)) begin
                        x <= clip_u($signed({22'd0, rx}) - $signed({22'd0, rw}), MW);
                        if (y >= ry + rw || y == 10'(MH - 1)) begin
                            // NEW: chain back to the path walk
                            if (path_active) state <= S_PWALK;
                            else begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
                        end else y <= y + 10'd1;
                    end else x <= x + 10'd1;
                end
                S_LINE: begin
                    // NEW: signed Bresenham (FM machine._line twin) — endpoints
                    // may sit offscreen; per-pixel bounds check, guard bails
                    // pathological walks loudly via dbg_path_ovf
                    begin
                        logic signed [17:0] e2;
                        logic signed [15:0] nx, ny;
                        logic signed [17:0] nerr;
                        if (bl_x >= 16'sd0 && bl_x < 16'(MW) &&
                            bl_y >= 16'sd0 && bl_y < 16'(MH)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(bl_y) * 19'(MW) + 19'(bl_x);
                            fb_wdata <= color;
                            dbg_line_px <= dbg_line_px + 32'd1; // flood hunt
                        end
                        if ((bl_x == bl_x1 && bl_y == bl_y1) || bl_guard == 13'd4095) begin
                            if (bl_guard == 13'd4095) dbg_path_ovf <= dbg_path_ovf + 16'd1;
                            if (path_active) begin
                                if (qseg != 4'd0 && qseg <= 4'd8) state <= S_QSEG;
                                else begin
                                    qseg <= 4'd0;
                                    state <= S_PWALK;
                                end
                            end else begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
                        end else begin
                            e2 = bl_err <<< 1;
                            nx = bl_x; ny = bl_y; nerr = bl_err;
                            if (e2 > -bl_dy) begin
                                nerr = nerr - 18'(bl_dy);
                                nx = bl_x + (bl_sx ? 16'sd1 : -16'sd1);
                            end
                            if (e2 < bl_dx) begin
                                nerr = nerr + 18'(bl_dx);
                                ny = bl_y + (bl_sy ? 16'sd1 : -16'sd1);
                            end
                            bl_x <= nx; bl_y <= ny; bl_err <= nerr;
                            bl_guard <= bl_guard + 13'd1;
                        end
                    end
                end
                S_PWALK: begin
                    // NEW: command walk (FM _raster_path) — transform each
                    // command's points with the CURRENT ctx transform
                    if (pi >= pc_n) begin
                        path_active <= 1'b0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                        xf_x <= pc_a1[pi[3:0]];
                        xf_y <= pc_a2[pi[3:0]];
                        xf_w <= pc_a3[pi[3:0]];
                        xf_h <= pc_a4[pi[3:0]];
                        xf_dst <= 2'd3;
                        state <= S_XF_MUL;
                    end else begin
                        p1x <= (pc_a1[pi[3:0]] >>> 16) + ctx_tx;
                        p1y <= (pc_a2[pi[3:0]] >>> 16) + ctx_ty;
                        // slot2: Q end point translates; arc radius must not
                        p2x <= (pc_a3[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_tx : 32'sd0);
                        p2y <= (pc_a4[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_ty : 32'sd0);
                        state <= S_PDO;
                    end
                end
                S_PDO: begin
                    // NEW: execute one transformed path command.
                    // Bring-up latch: SUSPICIOUS commands only (wall-flood hunt) —
                    // lineto far from cur, arc radius > 32, or way off-glass.
                    if (dbg_pdo_n < 5'd16 &&
                        ((pc_op[pi[3:0]] == 2'd1 &&
                          (p1x - cur_x > 32'sd64 || cur_x - p1x > 32'sd64 ||
                           p1y - cur_y > 32'sd64 || cur_y - p1y > 32'sd64)) ||
                         (pc_op[pi[3:0]] == 2'd3 && p2x > 32'sd32) ||
                         p1x < -32'sd64 || p1x > 32'sd704 ||
                         p1y < -32'sd64 || p1y > 32'sd544)) begin
                        dbg_pdo[dbg_pdo_n[3:0]] <= {14'd0, pc_op[pi[3:0]],
                            p1x[15:0], p1y[15:0], p2x[15:0], p2y[15:0]};
                        dbg_pdo_n <= dbg_pdo_n + 5'd1;
                    end
                    pi <= pi + 5'd1;
                    if (pc_op[pi[3:0]] == 2'd0) begin
                        cur_x <= p1x; cur_y <= p1y;
                        state <= S_PWALK;
                    end else if (pc_op[pi[3:0]] == 2'd1) begin
                        bl_x <= 16'(cur_x); bl_y <= 16'(cur_y);
                        bl_x1 <= 16'(p1x); bl_y1 <= 16'(p1y);
                        bl_dx <= (p1x > cur_x) ? 17'(p1x - cur_x) : 17'(cur_x - p1x);
                        bl_dy <= (p1y > cur_y) ? 17'(p1y - cur_y) : 17'(cur_y - p1y);
                        bl_sx <= (cur_x < p1x); bl_sy <= (cur_y < p1y);
                        bl_err <= 18'(((p1x > cur_x) ? (p1x - cur_x) : (cur_x - p1x))
                                    - ((p1y > cur_y) ? (p1y - cur_y) : (cur_y - p1y)));
                        bl_guard <= 13'd0;
                        qseg <= 4'd0;
                        cur_x <= p1x; cur_y <= p1y;
                        state <= S_LINE;
                    end else if (pc_op[pi[3:0]] == 2'd2) begin
                        // quadratic — FM subdivides into 8 line segments
                        qx0 <= cur_x; qy0 <= cur_y;
                        qcx <= p1x; qcy <= p1y;
                        qex <= p2x; qey <= p2y;
                        p2x <= cur_x; p2y <= cur_y; // prev bezier point
                        qseg <= 4'd1;
                        cur_x <= p2x; cur_y <= p2y;
                        state <= S_QSEG;
                    end else begin
                        // arc — FM fill_circle: full if |a1-a0| >= 2pi, skip if
                        // a0 == a1, else angular pie with the ccw sweep
                        logic signed [31:0] da_abs, sw, r_;
                        logic [15:0] t_s, t_e;
                        logic full_arc, skip_arc;
                        da_abs = pc_a5[pi[3:0]] - pc_a4[pi[3:0]];
                        if (da_abs < 0) da_abs = -da_abs;
                        full_arc = (da_abs >= 32'sd411770); // 2pi - eps
                        skip_arc = (!full_arc) && (pc_a4[pi[3:0]] == pc_a5[pi[3:0]]);
                        sw = pc_ccw[pi[3:0]]
                           ? fx_mod2pi(pc_a4[pi[3:0]] - pc_a5[pi[3:0]])
                           : fx_mod2pi(pc_a5[pi[3:0]] - pc_a4[pi[3:0]]);
                        if (sw == 32'sd0) sw = FX_2PI;
                        t_s = fx_turn(pc_ccw[pi[3:0]] ? pc_a5[pi[3:0]] : pc_a4[pi[3:0]]);
                        t_e = fx_turn(pc_ccw[pi[3:0]] ? pc_a4[pi[3:0]] : pc_a5[pi[3:0]]);
                        vs_x <= cos_t(t_s); vs_y <= sin_t(t_s);
                        ve_x <= cos_t(t_e); ve_y <= sin_t(t_e);
                        arc_sweep_gt_pi <= (sw > FX_PI);
                        arc_ang <= !full_arc;
                        r_ = p2x; if (r_ < 32'sd1) r_ = 32'sd1; // FM max(1, r*sx)
                        rx <= clip_u(p1x, MW); ry <= clip_u(p1y, MH);
                        rw <= clip_sz(r_, 10'd0, 512);
                        x <= clip_u(p1x - r_, MW);
                        y <= clip_u(p1y - r_, MH);
                        cur_x <= p1x; cur_y <= p1y; // FM: _path_x/_path_y = arc center
                        state <= skip_arc ? S_PWALK : S_CIRCLE;
                    end
                end
                S_QSEG: begin
                    // NEW: bezier weights for t = qseg/8 (Q16.16)
                    logic signed [31:0] t_, u_;
                    t_ = 32'(qseg) <<< 13;
                    u_ = FX_ONE - t_;
                    qk1 <= 32'((64'(u_) * 64'(u_)) >>> 16);
                    qk2 <= 32'((64'(u_) * 64'(t_)) >>> 16);
                    qk3 <= 32'((64'(t_) * 64'(t_)) >>> 16);
                    state <= S_QPX;
                end
                S_QPX: begin
                    p1x <= 32'((64'(qk1) * 64'(qx0) + 64'(qk2) * 64'(qcx) * 64'd2
                               + 64'(qk3) * 64'(qex)) >>> 16);
                    state <= S_QPY;
                end
                S_QPY: begin
                    logic signed [31:0] by_;
                    by_ = 32'((64'(qk1) * 64'(qy0) + 64'(qk2) * 64'(qcy) * 64'd2
                              + 64'(qk3) * 64'(qey)) >>> 16);
                    bl_x <= 16'(p2x); bl_y <= 16'(p2y);
                    bl_x1 <= 16'(p1x); bl_y1 <= 16'(by_);
                    bl_dx <= (p1x > p2x) ? 17'(p1x - p2x) : 17'(p2x - p1x);
                    bl_dy <= (by_ > p2y) ? 17'(by_ - p2y) : 17'(p2y - by_);
                    bl_sx <= (p2x < p1x); bl_sy <= (p2y < by_);
                    bl_err <= 18'(((p1x > p2x) ? (p1x - p2x) : (p2x - p1x))
                                - ((by_ > p2y) ? (by_ - p2y) : (p2y - by_)));
                    bl_guard <= 13'd0;
                    p2x <= p1x; p2y <= by_;
                    qseg <= qseg + 4'd1;
                    state <= S_LINE;
                end
                S_JOIN: begin
                    // NEW: fold single-digit elems into the encoder u16 hash
                    // (h = h*31 + '0'+d), matching jsb name interning
                    if (jn_i >= 16'({8'd0, arr_len[jn_arr]})) begin
                        jn_i <= 16'd0;
                        jn_len <= arr_len[jn_arr]; // one char per digit elem
                        state <= S_JOIN_FIND;
                    end else begin
                        logic [2:0] et;
                        logic signed [31:0] ev;
                        et = arr_tag[jn_arr][jn_i[6:0]];
                        ev = (et == 3'd7) ? ($signed(arr_val[jn_arr][jn_i[6:0]]) >>> 16)
                                          : $signed(arr_val[jn_arr][jn_i[6:0]]);
                        if ((et != 3'd0 && et != 3'd7) || ev < 32'sd0 || ev > 32'sd9) begin
                            // non-digit join shape — honest miss, result undefined
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else begin
                            jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                            jn_i <= jn_i + 16'd1;
                        end
                    end
                end
                S_SQRT: begin
                    // NEW: restoring bit-serial sqrt — 24 cycles, Q16.16 result
                    begin
                        logic [25:0] rem2, trial;
                        rem2 = {sq_rem[23:0], 2'((sq_rad >> ({1'b0, sq_i} * 6'd2)) & 48'd3)};
                        trial = {sq_root[23:0], 2'b01};
                        if (rem2 >= trial) begin
                            sq_rem <= rem2 - trial;
                            sq_root <= {sq_root[22:0], 1'b1};
                        end else begin
                            sq_rem <= rem2;
                            sq_root <= {sq_root[22:0], 1'b0};
                        end
                        if (sq_i == 5'd0) begin
                            stack[sp - 8'd1] <= {8'd0,
                                (rem2 >= trial) ? {sq_root[22:0], 1'b1}
                                                : {sq_root[22:0], 1'b0}};
                            stack_tag[sp - 8'd1] <= 3'd7;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else sq_i <= sq_i - 5'd1;
                    end
                end
                S_JOIN_FIND: begin
                    // NEW: reverse scan (hash, len) -> intern id, 16 names/cycle.
                    // Miss allocates a NEW dynamic intern slot, so the same
                    // dynamic string ('s1i3') always resolves to the same id —
                    // object keys and EQ then work with no string heap.
                    logic hitf;
                    logic [15:0] hidx;
                    hitf = 1'b0; hidx = 16'd0;
                    for (int k = 0; k < 16; k++) begin
                        if ((jn_i + 16'(k)) < names_n &&
                            name_hash_tbl[10'(jn_i + 16'(k))] == jn_h &&
                            name_len_tbl[10'(jn_i + 16'(k))] == jn_len) begin
                            hitf = 1'b1;
                            hidx = jn_i + 16'(k);
                        end
                    end
                    if (hitf) begin
                        stack[jn_res] <= {16'd0, hidx};
                        stack_tag[jn_res] <= 3'd3;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (jn_i + 16'd16 >= names_n) begin
                        if (names_n < 16'd1024) begin
                            name_hash_tbl[names_n[9:0]] <= jn_h;
                            name_len_tbl[names_n[9:0]] <= jn_len;
                            stack[jn_res] <= {16'd0, names_n};
                            stack_tag[jn_res] <= 3'd3;
                            names_n <= names_n + 16'd1;
                        end else begin
                            // intern table full — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                        end
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else jn_i <= jn_i + 16'd16;
                end
                S_CONCAT: begin
                    // NEW: JS string + — fold current operand into (cc_h, cc_len).
                    // Strings fold via h*31^len_b + h_b; ints fold decimal digits
                    // MSD-first (subtract powers of ten). Then find-or-alloc.
                    logic signed [31:0] v_;
                    logic [2:0] t_;
                    v_ = cc_second ? cc_bv : cc_av;
                    t_ = cc_second ? cc_bt : cc_at;
                    if (cc_st == 1'b0) begin
                        // classify operand
                        if (t_ == 3'd3) begin
                            cc_h <= 16'(32'(cc_h) * 32'(pow31_tbl[name_len_tbl[v_[9:0]]])
                                        + 32'(name_hash_tbl[v_[9:0]]));
                            cc_len <= cc_len + name_len_tbl[v_[9:0]];
                            if (cc_second) begin
                                jn_h <= 16'(32'(cc_h) * 32'(pow31_tbl[name_len_tbl[v_[9:0]]])
                                            + 32'(name_hash_tbl[v_[9:0]]));
                                jn_len <= cc_len + name_len_tbl[v_[9:0]];
                                jn_i <= 16'd0;
                                state <= S_JOIN_FIND;
                            end else cc_second <= 1'b1;
                        end else if (t_ == 3'd0 || t_ == 3'd7) begin
                            // integer (fx floors) — fold '-' then digits
                            logic signed [31:0] iv;
                            iv = (t_ == 3'd7) ? (v_ >>> 16) : v_;
                            if (iv < 0) begin
                                cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd45); // '-'
                                cc_len <= cc_len + 8'd1;
                                iv = -iv;
                            end
                            cc_v <= iv;
                            cc_d <= 4'd0;
                            cc_pi <= (iv >= 32'sd1000000000) ? 4'd9
                                   : (iv >= 32'sd100000000) ? 4'd8
                                   : (iv >= 32'sd10000000) ? 4'd7
                                   : (iv >= 32'sd1000000) ? 4'd6
                                   : (iv >= 32'sd100000) ? 4'd5
                                   : (iv >= 32'sd10000) ? 4'd4
                                   : (iv >= 32'sd1000) ? 4'd3
                                   : (iv >= 32'sd100) ? 4'd2
                                   : (iv >= 32'sd10) ? 4'd1 : 4'd0;
                            cc_st <= 1'b1;
                        end else begin
                            // undefined/obj/arr/fn concat — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        // digit loop: subtract P10[cc_pi] until below, fold digit
                        if (cc_v >= 32'(P10[cc_pi])) begin
                            cc_v <= cc_v - 32'(P10[cc_pi]);
                            cc_d <= cc_d + 4'd1;
                        end else begin
                            cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                            cc_len <= cc_len + 8'd1;
                            cc_d <= 4'd0;
                            if (cc_pi == 4'd0) begin
                                // operand done
                                cc_st <= 1'b0;
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                                    jn_len <= cc_len + 8'd1;
                                    jn_i <= 16'd0;
                                    state <= S_JOIN_FIND;
                                end else cc_second <= 1'b1;
                            end else cc_pi <= cc_pi - 4'd1;
                        end
                    end
                end
                S_IDXOF: begin
                    // NEW: arr.indexOf(v) linear scan (FM list.index twin)
                    logic [2:0] at2;
                    logic signed [31:0] av, nv;
                    logic tag_ok;
                    at2 = arr_tag[jn_arr][jn_i[6:0]];
                    av = $signed(arr_val[jn_arr][jn_i[6:0]]);
                    nv = idx_v;
                    // int/fx compare in the same Q16.16 domain
                    if (at2 == 3'd0 && idx_t == 3'd7) av = av <<< 16;
                    if (idx_t == 3'd0 && at2 == 3'd7) nv = nv <<< 16;
                    tag_ok = (at2 == idx_t) ||
                             ((at2 == 3'd0 || at2 == 3'd7) &&
                              (idx_t == 3'd0 || idx_t == 3'd7));
                    if (jn_i >= 16'({8'd0, arr_len[jn_arr]})) begin
                        stack[jn_res] <= -32'sd1;
                        stack_tag[jn_res] <= 3'd0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (tag_ok && av == nv) begin
                        stack[jn_res] <= {16'd0, jn_i};
                        stack_tag[jn_res] <= 3'd0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else jn_i <= jn_i + 16'd1;
                end
                S_XF_MUL: begin
                    // NEW: Q16.16 × Q16.16 → Q32.32 products, registered so the
                    // four DSP mults never sit on the single-cycle dispatch path
                    xfp_x <= 64'(xf_x) * 64'(ctx_sx);
                    xfp_y <= 64'(xf_y) * 64'(ctx_sy);
                    xfp_w <= 64'(xf_w) * 64'(ctx_sx);
                    xfp_h <= 64'(xf_h) * 64'(ctx_sy);
                    state <= S_XF_APPLY;
                end
                S_XF_APPLY: begin
                    // NEW: FM machine.py _xf — ix=int(x*sx+tx), iw=max(1,int(w*sx))
                    logic signed [31:0] ix_, iy_, iw_, ih_;
                    ix_ = trunc32(xfp_x + (64'(ctx_tx) <<< 32));
                    iy_ = trunc32(xfp_y + (64'(ctx_ty) <<< 32));
                    if (xf_dst == 2'd3) begin
                        // path point pair: slot2 = Q end point (translates) or
                        // arc radius channel (no translate — S_PDO reads p2x raw)
                        p1x <= ix_; p1y <= iy_;
                        p2x <= trunc32(xfp_w)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_tx : 32'sd0);
                        p2y <= trunc32(xfp_h)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_ty : 32'sd0);
                        state <= S_PDO;
                    end else begin
                        iw_ = trunc32(xfp_w); if (iw_ < 32'sd1) iw_ = 32'sd1;
                        ih_ = trunc32(xfp_h); if (ih_ < 32'sd1) ih_ = 32'sd1;
                        if (xf_dst == 2'd2) begin
                            iw_ = 32'sd64; ih_ = 32'sd8; // fillText stub keeps its size
                        end
                        rx <= clip_u(ix_, MW); ry <= clip_u(iy_, MH);
                        rw <= clip_sz(iw_, clip_u(ix_, MW), MW);
                        rh <= clip_sz(ih_, clip_u(iy_, MH), MH);
                        x <= (xf_dst == 2'd1) ? 10'd0 : clip_u(ix_, MW);
                        y <= (xf_dst == 2'd1) ? 10'd0 : clip_u(iy_, MH);
                        state <= (xf_dst == 2'd1) ? S_BLIT : S_RECT;
                    end
                end
                S_BLIT: begin
                    if (rw == 10'd0 || rh == 10'd0) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        // NEW: source coords are 16-bit (DONKEY 1470×750 sheets);
                        // so is a 22-bit byte offset into the 4 MB asset SRAM.
                        logic [15:0] sx, sy;
                        logic [21:0] so;
                        logic [7:0] pix;
                        logic       put;
                        sx = blit_sx + ((blit_sw == 16'd0 || rw == 10'd0) ? 16'd0
                             : 16'((32'(x) * 32'(blit_sw)) / 32'(rw)));
                        sy = blit_sy + ((blit_sh == 16'd0 || rh == 10'd0) ? 16'd0
                             : 16'((32'(y) * 32'(blit_sh)) / 32'(rh)));
                        so = spr_off[blit_si[3:0]] + 22'(sy) * 22'(spr_ww[blit_si[3:0]]) + 22'(sx);
                        put = 1'b0;
                        pix = 8'd0;
                        if (!aset_mode) begin
                            pix = spr_mem[so[17:0]];
                            put = 1'b1;
                        end else if (!blit_wait) begin
                            // NEW: ASET — fetch the 16-bit SRAM word holding this pixel
                            sram_req <= 1'b1;
                            sram_addr <= so[21:1];
                            blit_wait <= 1'b1;
                        end else if (sram_ack) begin
                            pix = so[0] ? sram_rdata[15:8] : sram_rdata[7:0];
                            sram_req <= 1'b0;
                            blit_wait <= 1'b0;
                            put = 1'b1;
                        end
                        if (put) begin
                            if (pix != 8'd0 && (rx + x) < 10'(MW) && (ry + y) < 10'(MH)) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(ry + y) * 19'(MW) + 19'(rx + x);
                                fb_wdata <= pix;
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
                                spr_ww[spr_i[3:0]] <= {6'd0, {trail_tb, trail_acc[7:0]}[9:0]};
                                spr_hdr <= 3'd2;
                            end else if (spr_hdr == 3'd2) begin
                                trail_acc[7:0] <= trail_tb;
                                spr_hdr <= 3'd3;
                            end else begin
                                spr_hh[spr_i[3:0]] <= {6'd0, {trail_tb, trail_acc[7:0]}[9:0]};
                                spr_off[spr_i[3:0]] <= 22'(spr_wp);
                                spr_left <= 18'({trail_tb, trail_acc[7:0]}[9:0]) * 18'(spr_ww[spr_i[3:0]][9:0]);
                                spr_hdr <= 3'd0;
                                if (18'({trail_tb, trail_acc[7:0]}[9:0]) * 18'(spr_ww[spr_i[3:0]][9:0]) == 18'd0) begin
                                    if (spr_i + 5'd1 >= n_spr) begin
                                        code_raddr <= 15'(ops_base);
                                        state <= S_FETCH_WAIT;
                                    end else spr_i <= spr_i + 5'd1;
                                end
                            end
                        end else begin
                            if ({1'b0, spr_wp} < 19'(SPR_BYTES))
                                spr_mem[spr_wp] <= trail_tb;
                            spr_wp <= spr_wp + 18'd1;
                            spr_left <= spr_left - 18'd1;
                            if (spr_left == 18'd1) begin
                                if (spr_i + 5'd1 >= n_spr) begin
                                    code_raddr <= 15'(ops_base);
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    spr_i <= spr_i + 5'd1;
                                    spr_hdr <= 3'd0;
                                end
                            end
                        end
                    end
                end
                // NEW: ALU result into alu_r (no stack write this cycle)
                S_ALU: begin
                    // NEW: ADD/SUB/NEG saturate (33-bit) — FM floats never wrap;
                    // saturated dx*dx + dy*dy must stay MAXINT, not go negative
                    unique case (alu_op)
                        3'd0: alu_r <= sat33(33'(alu_a) + 33'(alu_b));
                        3'd1: alu_r <= sat33(33'(alu_a) - 33'(alu_b));
                        3'd2: alu_r <= (alu_a < alu_b) ? 32'sd1 : 32'sd0;
                        3'd3: alu_r <= (alu_a > alu_b) ? 32'sd1 : 32'sd0;
                        3'd4: alu_r <= (alu_a == alu_b) ? 32'sd1 : 32'sd0;
                        3'd5: alu_r <= sat33(-33'(alu_a));
                        3'd6: alu_r <= (alu_a == 0) ? 32'sd1 : 32'sd0;
                        default: alu_r <= 32'sd0;
                    endcase
                    state <= S_ALU_WR;
                end
                // NEW: stack write from alu_r — binary ops already did sp--
                S_ALU_WR: begin
                    stack[sp - 8'd1] <= alu_r;
                    // fx ADD/SUB/NEG keep Q16.16; compares/NOT are plain ints
                    stack_tag[sp - 8'd1] <= alu_fx ? 3'd7 : 3'd0;
                    next_op();
                end
                // NEW: DSP multiply into mul_prod only (no stack write this cycle)
                S_MUL: begin
                    mul_prod <= 64'(mul_a) * 64'(mul_b);
                    state <= S_MUL_WR;
                end
                // NEW: stack write from registered product — closes −0.183 ns WNS
                S_MUL_WR: begin
                    // int×int → int; int×fx → fx as-is; fx×fx → renormalize >>16.
                    // NEW: saturate to int32 — FM floats never wrap; fx dx*dx
                    // overflow made hitAt distances NEGATIVE, so every INVADERS
                    // bullet "hit" a bunker cell on frame 1 and died
                    begin
                        logic signed [63:0] p;
                        p = (mul_fx_a && mul_fx_b) ? (mul_prod >>> 16) : mul_prod;
                        if (p > 64'sd2147483647) p = 64'sd2147483647;
                        else if (p < -64'sd2147483648) p = -64'sd2147483648;
                        stack[sp - 8'd2] <= 32'(p);
                    end
                    stack_tag[sp - 8'd2] <= (mul_fx_a || mul_fx_b) ? 3'd7 : 3'd0;
                    sp <= sp - 8'd1;
                    next_op();
                end
                // NEW: one restoring-division step per clock (32 total)
                S_DIV: begin
                    if (div_rnext >= {1'b0, div_ub}) begin
                        div_rem <= 32'(div_rnext - {1'b0, div_ub});
                        div_uq  <= {div_uq[46:0], 1'b1};
                    end else begin
                        div_rem <= div_rnext[31:0];
                        div_uq  <= {div_uq[46:0], 1'b0};
                    end
                    if (div_cnt == 6'd47) state <= S_DIV_FIN;
                    else div_cnt <= div_cnt + 6'd1;
                end
                S_DIV_FIN: begin
                    // Q16.16 quotient; int/int exact division stays a plain int
                    begin
                        logic [31:0] qmag;
                        qmag = (|div_uq[47:31]) ? 32'h7FFFFFFF : div_uq[31:0];
                        if (div_int_in && qmag[15:0] == 16'd0) begin
                            stack[sp - 8'd2] <= div_neg ? -$signed({16'd0, qmag[31:16]})
                                                        : $signed({16'd0, qmag[31:16]});
                            stack_tag[sp - 8'd2] <= 3'd0;
                        end else begin
                            stack[sp - 8'd2] <= div_neg ? -$signed(qmag) : $signed(qmag);
                            stack_tag[sp - 8'd2] <= 3'd7;
                        end
                    end
                    sp <= sp - 8'd1;
                    next_op();
                end
                S_FOREACH: begin
                    // NEW: drain arr.forEach(fn) using frame at csp-1
                    if (csp == 0) begin
                        state <= S_WAIT_FRAME;
                    end else if (cstack_fe_i[csp - 7'd1] >= arr_len[cstack_fe_arr[csp - 7'd1][11:0]]) begin
                        if (cstack_map_arr[csp - 7'd1] != 16'hFFFF &&
                            cstack_map_arr[csp - 7'd1] != 16'hFFFE) begin
                            stack[sp] <= {16'd0, cstack_map_arr[csp - 7'd1]};
                            stack_tag[sp] <= 3'd2;
                        end else begin
                            stack[sp] <= 32'sd0;
                            stack_tag[sp] <= 3'd5; // forEach void / find miss
                        end
                        sp <= sp + 8'd1;
                        release_env_to(cstack_env[csp - 7'd1]);
                        ip <= cstack_ip[csp - 7'd1];
                        this_obj <= cstack_this[csp - 7'd1];
                        csp <= csp - 7'd1;
                        code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd1]);
                        state <= S_FETCH_WAIT;
                    end else begin
                        // bind nparam args: el, then idx if the callback asked for it
                        begin
                            logic [15:0] foid;
                            logic [12:0] fo;
                            logic [5:0]  capn;
                            foid = cstack_fe_fn[csp - 7'd1];
                            fo = foid[12:0];
                            capn = (obj_n[fo] > 6'd2) ? 6'(obj_n[fo] - 6'd2) : 6'd0;
                            stack[sp] <= arr_val[cstack_fe_arr[csp - 7'd1][11:0]][cstack_fe_i[csp - 7'd1][6:0]];
                            stack_tag[sp] <= arr_tag[cstack_fe_arr[csp - 7'd1][11:0]][cstack_fe_i[csp - 7'd1][6:0]];
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
                            enter_captured_fn(foid);
                            csp <= csp + 7'd1;
                            ip <= obj_val[fo][0][15:0];
                            code_raddr <= 15'(ops_base + obj_val[fo][0][15:0]);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end
                S_WAIT_FRAME: if (frame_tick) begin
                    prev_joy <= joy_in;
                    // NEW: FM frame clock twin — Date.now advances once per rAF
                    // frame (machine.py vm.time_ms = frame*16.67). The old
                    // +17-per-CALL hack made game time race ahead: PACMAN
                    // ghosts sped up and the run left the maze stage unattended.
                    time_ms <= time_ms + 32'd17;
                    // NEW: tick timer delays once per frame (setTimeout ms/17)
                    for (int ti = 0; ti < 8; ti++)
                        if (ti < to_n && to_delay[ti] != 12'd0)
                            to_delay[ti] <= to_delay[ti] - 12'd1;
                    // NEW: per-frame array nursery — rewind MAKE_ARR temps so
                    // n_arr cannot saturate. Same as objects: do not wait for
                    // click_fired (boot rAF already allocates).
                    if (arr_keep_ok)
                        n_arr <= n_arr_keep;
                    else begin
                        if (arr_keep_wait != 4'd0)
                            arr_keep_wait <= arr_keep_wait - 4'd1;
                        else begin
                            n_arr_keep <= n_arr;
                            arr_keep_ok <= 1'b1;
                        end
                    end
                    // NEW: object bump rewind the cycle BEFORE rAF/keys so
                    // enter_captured_fn's n_obj++ does not fight n_obj<=keep.
                    // Do not wait for click_fired — boot rAF/nextStage already
                    // allocate; an 8-frame post-click delay overflows first.
                    if (obj_keep_ok)
                        n_obj <= n_obj_keep;
                    else begin
                        if (obj_keep_wait != 4'd0)
                            obj_keep_wait <= obj_keep_wait - 4'd1;
                        else begin
                            n_obj_keep <= n_obj;
                            obj_keep_ok <= 1'b1;
                        end
                    end
                    // KEYBITS level → keys.a/d/space.pressed (HTML table the animate() reads)
                    if (keys_ok) begin
                        poke_pressed(id_a, joy_in[2]);
                        poke_pressed(id_d, joy_in[3]);
                        poke_pressed(id_kspace, joy_in[4]);
                    end
                    if (enter_n != 0 && enter_delay != 0)
                        enter_delay <= enter_delay - 4'd1;
                    frame_fire <= 1'b1;
                    end else if (frame_fire) begin
                    frame_fire <= 1'b0;
                    // KEYBITS edges → keydown/keyup with event.key + keyCode (HTML bindings)
                    // Skip when a KEYEVT is queued so GUI KEYEVT+KEYBITS does not double-fire.
                    if (kd_fn != 16'hFFFF && (joy_in & ~prev_joy) != 0 && kev_rp == kev_wp) begin
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_cls[n_obj[12:0]] <= 0;
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            joy_in[2] ? id_arrow_l : joy_in[3] ? id_arrow_r :
                            joy_in[4] ? id_space : id_arrow_l};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= joy_in[2] ? 32'sd37 : joy_in[3] ? 32'sd39 :
                            joy_in[4] ? 32'sd32 : joy_in[0] ? 32'sd38 : 32'sd40;
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        // NEW: frame boundary — reset the eval stack (leftovers
                        // are leaks; ~1 word/frame overflowed sp at ~500 frames)
                        stack[0] <= {16'd0, n_obj};
                        stack_tag[0] <= 3'd1;
                        sp <= 11'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= kd_slot[0];
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= 1'b1;
                        kev_ret_ip <= n_ops;
                        cstack_ip[csp] <= 16'hFFFD;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        // S_KEYEV: env alloc next cycle so it cannot clobber the event
                        state <= S_KEYEV;
                    end else if (ku_fn != 16'hFFFF && (prev_joy & ~joy_in) != 0 && kev_rp == kev_wp) begin
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            prev_joy[2] ? id_arrow_l : prev_joy[3] ? id_arrow_r :
                            prev_joy[4] ? id_space : id_arrow_l};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= prev_joy[2] ? 32'sd37 : prev_joy[3] ? 32'sd39 :
                            prev_joy[4] ? 32'sd32 : 32'sd38;
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        stack[0] <= {16'd0, n_obj}; // frame boundary: fresh stack
                        stack_tag[0] <= 3'd1;
                        sp <= 11'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= ku_slot[0];
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= 1'b0;
                        kev_ret_ip <= n_ops;
                        cstack_ip[csp] <= 16'hFFFD;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        state <= S_KEYEV;
                    end else if (raf_n != 0 && (!pre_click_raf || raf_n > 4'd1)) begin
                        // Drain nested boot rAFs (HTML queues extra frames before
                        // the looping animate) before auto-click. A canvas
                        // click listener must not steal those slots.
                        pre_click_raf <= 1'b1;
                        sp <= '0; // frame boundary: fresh eval stack
                        ip <= fn_entry(raf_fn[0]);
                        raf_n <= raf_n - 4'd1;
                        enter_captured_fn(raf_fn[0]);
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
                        code_raddr <= 15'(ops_base + fn_entry(raf_fn[0]));
                        state <= S_FETCH_WAIT;
                    end else if (click_fn != 16'hFFFF && !click_fired) begin
                        // HTML auto-start: idle animate re-queues rAF so click never drained
                        click_fired <= 1'b1;
                        sp <= '0; // frame boundary: fresh eval stack
                        ip <= fn_entry(click_fn);
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        enter_captured_fn(click_fn);
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + fn_entry(click_fn));
                        state <= S_FETCH_WAIT;
                    end else if (kev_rp != kev_wp &&
                                (kev_q[kev_rp][8] ? kd_n : ku_n) == 3'd0) begin
                        // no handler registered for this direction — drop event
                        kev_rp <= kev_rp + 3'd1;
                    end else if (kev_rp != kev_wp) begin
                        // NEW: real host key event (KEYEVT) — replaces the
                        // synthetic-Enter title hack; e.keyCode is the truth,
                        // e.key interned only for codes we know (else undefined)
                        kev_rp <= kev_rp + 3'd1;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_cls[n_obj[12:0]] <= 0;
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            (kev_q[kev_rp][7:0] == 8'd13) ? id_enter :
                            (kev_q[kev_rp][7:0] == 8'd32) ? id_space :
                            (kev_q[kev_rp][7:0] == 8'd37) ? id_arrow_l :
                            (kev_q[kev_rp][7:0] == 8'd39) ? id_arrow_r :
                            (kev_q[kev_rp][7:0] == 8'd65) ? id_a :
                            (kev_q[kev_rp][7:0] == 8'd68) ? id_d : 16'hFFFF};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= 32'({24'd0, kev_q[kev_rp][7:0]});
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        stack[0] <= {16'd0, n_obj}; // frame boundary: fresh stack
                        stack_tag[0] <= 3'd1;
                        sp <= 11'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= kev_q[kev_rp][8] ? kd_slot[0] : ku_slot[0];
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= kev_q[kev_rp][8];
                        kev_ret_ip <= n_ops;
                        cstack_ip[csp] <= 16'hFFFD;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        state <= S_KEYEV;
                    end else if (raf_n != 0) begin
                        sp <= '0; // frame boundary: fresh eval stack
                        ip <= fn_entry(raf_fn[0]);
                        raf_n <= raf_n - 4'd1;
                        enter_captured_fn(raf_fn[0]);
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
                        code_raddr <= 15'(ops_base + fn_entry(raf_fn[0]));
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
                end else if (to_n != 0 && to_delay[0] == 12'd0) begin
                    // NEW: due timer after rAF (FM drains timers after rAF)
                    begin
                        logic [15:0] foid;
                        logic [12:0] fo;
                        foid = to_fn[0];
                        fo = foid[12:0];
                        sp <= '0;
                        ip <= obj_val[fo][0][15:0];
                        if (to_period[0] != 12'd0 && to_n == 4'd1) begin
                            to_delay[0] <= to_period[0]; // re-arm sole interval
                        end else if (to_period[0] != 12'd0) begin
                            to_fn[0] <= to_fn[1]; to_delay[0] <= to_delay[1];
                            to_period[0] <= to_period[1]; to_id[0] <= to_id[1];
                            to_fn[1] <= to_fn[2]; to_delay[1] <= to_delay[2];
                            to_period[1] <= to_period[2]; to_id[1] <= to_id[2];
                            to_fn[2] <= to_fn[3]; to_delay[2] <= to_delay[3];
                            to_period[2] <= to_period[3]; to_id[2] <= to_id[3];
                            to_fn[3] <= to_fn[4]; to_delay[3] <= to_delay[4];
                            to_period[3] <= to_period[4]; to_id[3] <= to_id[4];
                            to_fn[4] <= to_fn[5]; to_delay[4] <= to_delay[5];
                            to_period[4] <= to_period[5]; to_id[4] <= to_id[5];
                            to_fn[5] <= to_fn[6]; to_delay[5] <= to_delay[6];
                            to_period[5] <= to_period[6]; to_id[5] <= to_id[6];
                            to_fn[6] <= to_fn[7]; to_delay[6] <= to_delay[7];
                            to_period[6] <= to_period[7]; to_id[6] <= to_id[7];
                            to_fn[to_n - 4'd1] <= foid;
                            to_delay[to_n - 4'd1] <= to_period[0];
                            to_period[to_n - 4'd1] <= to_period[0];
                            to_id[to_n - 4'd1] <= to_id[0];
                        end else begin
                            to_n <= to_n - 4'd1;
                            to_fn[0] <= to_fn[1]; to_delay[0] <= to_delay[1];
                            to_period[0] <= to_period[1]; to_id[0] <= to_id[1];
                            to_fn[1] <= to_fn[2]; to_delay[1] <= to_delay[2];
                            to_period[1] <= to_period[2]; to_id[1] <= to_id[2];
                            to_fn[2] <= to_fn[3]; to_delay[2] <= to_delay[3];
                            to_period[2] <= to_period[3]; to_id[2] <= to_id[3];
                            to_fn[3] <= to_fn[4]; to_delay[3] <= to_delay[4];
                            to_period[3] <= to_period[4]; to_id[3] <= to_id[4];
                            to_fn[4] <= to_fn[5]; to_delay[4] <= to_delay[5];
                            to_period[4] <= to_period[5]; to_id[4] <= to_id[5];
                            to_fn[5] <= to_fn[6]; to_delay[5] <= to_delay[6];
                            to_period[5] <= to_period[6]; to_id[5] <= to_id[6];
                            to_fn[6] <= to_fn[7]; to_delay[6] <= to_delay[7];
                            to_period[6] <= to_period[7]; to_id[6] <= to_id[7];
                        end
                        cstack_ip[csp] <= n_ops;
                        cstack_this[csp] <= this_obj;
                        cstack_isctor[csp] <= 1'b0;
                        cstack_isfe[csp] <= 1'b0;
                        enter_captured_fn(foid);
                        csp <= csp + 7'd1;
                        code_raddr <= 15'(ops_base + obj_val[fo][0][15:0]);
                        state <= S_FETCH_WAIT;
                    end
                end
                S_KEYEV: begin
                    // Event object was allocated last cycle (n_obj already bumped).
                    enter_captured_fn(kev_fn);
                    csp <= csp + 7'd1;
                    ip <= fn_entry(kev_fn);
                    code_raddr <= 15'(ops_base + fn_entry(kev_fn));
                    state <= S_FETCH_WAIT;
                end
                S_ENV_LOAD: begin
                    // Walk live heap env parent chain (FM env.__par), then vars[].
                    begin
                        logic hit;
                        logic [12:0] eo;
                        logic [15:0] par;
                        hit = 1'b0;
                        eo = env_walk[12:0];
                        par = obj_val[eo][0][15:0];
                        for (int s = 1; s < OBJ_SLOTS; s++) begin
                            if (s < obj_n[eo] && obj_key[eo][s] == {7'd0, env_ld_slot}) begin
                                hit = 1'b1;
                                if (env_is_store) begin
                                    obj_val[eo][s] <= stack[sp - 8'd1];
                                    obj_tag[eo][s] <= stack_tag[sp - 8'd1];
                                end else begin
                                    stack[sp] <= obj_val[eo][s];
                                    stack_tag[sp] <= obj_tag[eo][s];
                                end
                            end
                        end
                        if (hit) begin
                            if (env_is_store) sp <= sp - 8'd1;
                            else sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else if (par != 16'd0 && par != env_walk) begin
                            env_walk <= par;
                        end else begin
                            if (env_is_store) begin
                                vars[env_ld_slot] <= stack[sp - 8'd1];
                                var_tag[env_ld_slot] <= stack_tag[sp - 8'd1];
                                var_init[env_ld_slot] <= 1'b1;
                                sp <= sp - 8'd1;
                            end else begin
                                stack[sp] <= vars[env_ld_slot];
                                stack_tag[sp] <= var_tag[env_ld_slot];
                                sp <= sp + 8'd1;
                            end
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end
                S_JSON: begin
                    // Walk nested arrays/objects/numbers into json_mem (VM cap).
                    if (js_sp == 6'd0) begin
                        obj_cls[n_obj[12:0]] <= CLS_DYNSTR;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_key[n_obj[12:0]][0] <= 16'd0;
                        obj_val[n_obj[12:0]][0] <= 32'd0;
                        obj_tag[n_obj[12:0]][0] <= 3'd0;
                        obj_key[n_obj[12:0]][1] <= 16'd1;
                        obj_val[n_obj[12:0]][1] <= {18'd0, json_wp};
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        stack[json_res] <= {16'd0, n_obj};
                        stack_tag[json_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic [5:0] t;
                        logic [2:0] tg, ph;
                        logic [31:0] v;
                        logic [7:0]  ii;
                        t = js_sp - 6'd1;
                        tg = js_tag[t];
                        ph = js_ph[t];
                        v = js_val[t];
                        ii = js_i[t];
                        if (ph == 3'd0) begin
                            if (tg == 3'd0 || tg == 3'd7) begin
                                json_num <= (tg == 3'd7) ? $signed(v >>> 16) : $signed(v);
                                json_neg <= ((tg == 3'd7) ? $signed(v >>> 16) : $signed(v)) < 0;
                                js_ph[t] <= 3'd3;
                            end else if (tg == 3'd5) begin
                                json_di <= 4'd0;
                                js_ph[t] <= 3'd4;
                            end else if (tg == 3'd2) begin
                                json_putc(8'h5B);
                                js_ph[t] <= 3'd1;
                                js_i[t] <= 8'd0;
                            end else if (tg == 3'd1) begin
                                json_putc(8'h7B);
                                js_ph[t] <= 3'd5;
                                js_i[t] <= 8'd0;
                            end else if (tg == 3'd3) begin
                                json_putc(8'h22);
                                js_ph[t] <= 3'd7;
                            end else begin
                                json_putc(8'h6E); // n of null
                                json_di <= 4'd1;
                                js_ph[t] <= 3'd4;
                            end
                        end else if (ph == 3'd1) begin
                            if (ii >= arr_len[v[11:0]]) begin
                                json_putc(8'h5D);
                                js_sp <= t;
                            end else if (ii != 8'd0) begin
                                json_putc(8'h2C);
                                js_ph[t] <= 3'd2;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= arr_tag[v[11:0]][ii[6:0]];
                                js_val[js_sp] <= arr_val[v[11:0]][ii[6:0]];
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= js_sp + 6'd1;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_sp <= t;
                            end
                        end else if (ph == 3'd2) begin
                            if (tg == 3'd1) begin
                                json_putc(8'h3A);
                                if (js_sp < JSON_STK[5:0]) begin
                                    js_tag[js_sp] <= obj_tag[v[12:0]][ii];
                                    js_val[js_sp] <= obj_val[v[12:0]][ii];
                                    js_i[js_sp] <= 8'd0;
                                    js_ph[js_sp] <= 3'd0;
                                    js_i[t] <= ii + 8'd1;
                                    js_ph[t] <= 3'd5;
                                    js_sp <= js_sp + 6'd1;
                                end else js_sp <= t;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= arr_tag[v[11:0]][ii[6:0]];
                                js_val[js_sp] <= arr_val[v[11:0]][ii[6:0]];
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_ph[t] <= 3'd1;
                                js_sp <= js_sp + 6'd1;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_sp <= t;
                            end
                        end else if (ph == 3'd3) begin
                            begin
                                logic signed [31:0] mag;
                                logic [31:0] x;
                                logic [3:0] n;
                                logic [7:0] tmp [0:9];
                                mag = json_neg ? -json_num : json_num;
                                x = 32'(mag);
                                n = 4'd0;
                                for (int d = 0; d < 10; d++) tmp[d] = 8'h30;
                                if (json_neg) json_putc(8'h2D);
                                if (x == 32'd0) n = 4'd1;
                                else begin
                                    for (int d = 0; d < 10; d++) begin
                                        if (x != 32'd0) begin
                                            tmp[n] = 8'h30 + 8'(x % 32'd10);
                                            x = x / 32'd10;
                                            n = n + 4'd1;
                                        end
                                    end
                                end
                                for (int d = 0; d < 10; d++) json_digs[d] <= tmp[d];
                                json_dn <= (n == 4'd0) ? 4'd1 : n;
                                json_di <= (n == 4'd0) ? 4'd1 : n;
                                js_ph[t] <= 3'd6;
                            end
                        end else if (ph == 3'd6) begin
                            json_putc(json_digs[json_di - 4'd1]);
                            if (json_di <= 4'd1) js_sp <= t;
                            else json_di <= json_di - 4'd1;
                        end else if (ph == 3'd4) begin
                            if (json_di == 4'd0) json_putc(8'h6E);
                            else if (json_di == 4'd1) json_putc(8'h75);
                            else if (json_di == 4'd2) json_putc(8'h6C);
                            else json_putc(8'h6C);
                            if (json_di >= 4'd3) js_sp <= t;
                            else json_di <= json_di + 4'd1;
                        end else if (ph == 3'd5) begin
                            if (ii >= obj_n[v[12:0]]) begin
                                json_putc(8'h7D);
                                js_sp <= t;
                            end else if (ii != 8'd0) begin
                                json_putc(8'h2C);
                                js_ph[t] <= 3'd7;
                            end else begin
                                json_putc(8'h22);
                                js_ph[t] <= 3'd7;
                            end
                        end else if (ph == 3'd7) begin
                            if (tg == 3'd3) begin
                                if (name_len_tbl[v[9:0]] == 8'd1)
                                    json_putc(name_hash_tbl[v[9:0]][7:0]);
                                else json_putc(8'h3F);
                                js_ph[t] <= 3'd8;
                            end else begin
                                json_putc((name_len_tbl[obj_key[v[12:0]][ii][9:0]] == 8'd1)
                                    ? name_hash_tbl[obj_key[v[12:0]][ii][9:0]][7:0] : 8'h5F);
                                js_ph[t] <= 3'd8;
                            end
                        end else if (ph == 3'd8) begin
                            json_putc(8'h22);
                            if (tg == 3'd3) js_sp <= t;
                            else js_ph[t] <= 3'd2;
                        end else begin
                            js_sp <= t;
                        end
                    end
                end
                S_JSON_PARSE: begin
                    if (json_rp >= json_src + json_srclen) begin
                        stack[json_res] <= (js_sp == 0) ? 32'sd0 : js_val[0];
                        stack_tag[json_res] <= (js_sp == 0) ? 3'd5 : js_tag[0];
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic [7:0] ch;
                        ch = json_mem[json_rp[12:0]];
                        if (ch == 8'h20 || ch == 8'h0A || ch == 8'h0D || ch == 8'h09) begin
                            json_rp <= json_rp + 14'd1;
                        end else if (json_pph == 3'd3) begin
                            // accumulating number
                            if (ch >= 8'h30 && ch <= 8'h39) begin
                                json_num <= json_num * 32'sd10 + $signed({24'd0, ch - 8'h30});
                                json_rp <= json_rp + 14'd1;
                            end else begin
                                begin
                                    logic signed [31:0] nv;
                                    nv = json_neg ? -json_num : json_num;
                                    json_rp <= json_rp; // complete value
                                    if (js_sp == 6'd0) begin
                                        js_val[0] <= nv;
                                        js_tag[0] <= 3'd0;
                                        js_sp <= 6'd1;
                                        stack[json_res] <= nv;
                                        stack_tag[json_res] <= 3'd0;
                                        sp <= json_res + 11'd1;
                                        code_raddr <= 15'(ops_base + ip);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        logic [5:0] p;
                                        p = js_sp - 6'd1;
                                        if (js_tag[p] == 3'd2) begin
                                            arr_val[js_val[p][11:0]][js_i[p][6:0]] <= nv;
                                            arr_tag[js_val[p][11:0]][js_i[p][6:0]] <= 3'd0;
                                            arr_len[js_val[p][11:0]] <= js_i[p] + 8'd1;
                                            js_i[p] <= js_i[p] + 8'd1;
                                        end
                                        json_pph <= 3'd0;
                                    end
                                end
                            end
                        end else if (ch == 8'h5B) begin
                            arr_len[n_arr[11:0]] <= 8'd0;
                            if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= 3'd2;
                                js_val[js_sp] <= {16'd0, n_arr};
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd1;
                                js_sp <= js_sp + 6'd1;
                            end
                            if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                            n_arr <= (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                            json_rp <= json_rp + 14'd1;
                        end else if (ch == 8'h5D) begin
                            json_rp <= json_rp + 14'd1;
                            if (js_sp <= 6'd1) begin
                                stack[json_res] <= js_val[0];
                                stack_tag[json_res] <= 3'd2;
                                sp <= json_res + 11'd1;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                logic [5:0] p, c;
                                c = js_sp - 6'd1;
                                p = js_sp - 6'd2;
                                if (js_tag[p] == 3'd2) begin
                                    arr_val[js_val[p][11:0]][js_i[p][6:0]] <= js_val[c];
                                    arr_tag[js_val[p][11:0]][js_i[p][6:0]] <= 3'd2;
                                    arr_len[js_val[p][11:0]] <= js_i[p] + 8'd1;
                                    js_i[p] <= js_i[p] + 8'd1;
                                end
                                js_sp <= c;
                            end
                        end else if (ch == 8'h2C) begin
                            json_rp <= json_rp + 14'd1;
                        end else if (ch == 8'h7B) begin
                            obj_n[n_obj[12:0]] <= 6'd0;
                            obj_cls[n_obj[12:0]] <= 16'd0;
                            if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= 3'd1;
                                js_val[js_sp] <= {16'd0, n_obj};
                                js_i[js_sp] <= 8'd0;
                                js_sp <= js_sp + 6'd1;
                            end
                            if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            json_rp <= json_rp + 14'd1;
                        end else if (ch == 8'h7D) begin
                            json_rp <= json_rp + 14'd1;
                            if (js_sp <= 6'd1) begin
                                stack[json_res] <= js_val[0];
                                stack_tag[json_res] <= 3'd1;
                                sp <= json_res + 11'd1;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else js_sp <= js_sp - 6'd1;
                        end else if (json_pph == 3'd7) begin
                            json_rp <= json_rp + 14'd1;
                            if (ch == 8'h22) json_pph <= 3'd0;
                        end else if (ch == 8'h22) begin
                            json_rp <= json_rp + 14'd1;
                            json_pph <= 3'd7; // skip string
                        end else if (ch == 8'h6E) begin
                            json_rp <= json_rp + 14'd4; // null
                        end else if (ch == 8'h2D || (ch >= 8'h30 && ch <= 8'h39)) begin
                            json_neg <= (ch == 8'h2D);
                            json_num <= (ch == 8'h2D) ? 32'sd0 : $signed({24'd0, ch - 8'h30});
                            json_rp <= json_rp + 14'd1;
                            json_pph <= 3'd3;
                        end else json_rp <= json_rp + 14'd1;
                    end
                end
                S_REPL: begin
                    if (json_rp >= json_src + json_srclen) begin
                        obj_cls[n_obj[12:0]] <= CLS_DYNSTR;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_key[n_obj[12:0]][0] <= 16'd0;
                        obj_val[n_obj[12:0]][0] <= {18'd0, json_wp};
                        obj_tag[n_obj[12:0]][0] <= 3'd0;
                        obj_key[n_obj[12:0]][1] <= 16'd1;
                        obj_val[n_obj[12:0]][1] <= {18'd0, json_dst - json_wp};
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        stack[json_res] <= {16'd0, n_obj};
                        stack_tag[json_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic match;
                        match = (json_mem[json_rp[12:0]] == repl_pat0) &&
                            (repl_nlen <= 8'd1 ||
                             (json_rp + 14'd1 < json_src + json_srclen &&
                              json_mem[json_rp[12:0] + 13'd1] == repl_pat1));
                        if (match && (repl_g || !repl_did) && json_dst < 14'(JSON_CAP)) begin
                            json_mem[json_dst[12:0]] <= repl_rch;
                            json_dst <= json_dst + 14'd1;
                            json_rp <= json_rp + ((repl_nlen <= 8'd1) ? 14'd1 : 14'(repl_nlen));
                            repl_did <= 1'b1;
                        end else if (json_dst < 14'(JSON_CAP)) begin
                            json_mem[json_dst[12:0]] <= json_mem[json_rp[12:0]];
                            json_dst <= json_dst + 14'd1;
                            json_rp <= json_rp + 14'd1;
                        end else begin
                            dbg_json_ovf <= dbg_json_ovf + 16'd1;
                            json_rp <= json_src + json_srclen;
                        end
                    end
                end
                S_IDXSTR: begin
                    if (json_rp >= json_src + json_srclen) begin
                        stack[json_res] <= -32'sd1;
                        stack_tag[json_res] <= 3'd0;
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (json_mem[json_rp[12:0]] == idx_needle) begin
                        stack[json_res] <= 32'(json_rp - json_src);
                        stack_tag[json_res] <= 3'd0;
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else json_rp <= json_rp + 14'd1;
                end
                S_IMGD_GET: begin
                    // Copy back-buffer rect into the one snapshot (dump_back is
                    // registered 1 cycle after fb_dump_addr).
                    fb_we <= 1'b0;
                    fb_dump_sel <= 1'b1;
                    if (imgd_n == 19'd0) begin
                        obj_cls[n_obj[12:0]] <= CLS_IMGD;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_key[n_obj[12:0]][0] <= id_width;
                        obj_val[n_obj[12:0]][0] <= {22'd0, imgd_w};
                        obj_tag[n_obj[12:0]][0] <= 3'd0;
                        obj_key[n_obj[12:0]][1] <= id_height;
                        obj_val[n_obj[12:0]][1] <= {22'd0, imgd_h};
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
                        stack[imgd_res] <= {16'd0, n_obj};
                        stack_tag[imgd_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= imgd_res + 11'd1;
                        fb_dump_sel <= 1'b0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (!imgd_armed) begin
                        // dump_back is registered 1 cycle after dump_raddr
                        imgd_armed <= 1'b1;
                    end else begin
                        if (imgd_i < 19'(FB_PIXELS))
                            imgd_pix[imgd_i] <= fb_dump_back;
                        if (imgd_x >= (imgd_x0 + imgd_w - 10'd1) || imgd_x == 10'(MW - 1)) begin
                            imgd_x <= imgd_x0;
                            fb_dump_addr <= 19'(imgd_y + 10'd1) * 19'(MW) + 19'(imgd_x0);
                            if (imgd_y >= (imgd_y0 + imgd_h - 10'd1) || imgd_y == 10'(MH - 1)) begin
                                obj_cls[n_obj[12:0]] <= CLS_IMGD;
                                obj_n[n_obj[12:0]] <= 6'd2;
                                obj_key[n_obj[12:0]][0] <= id_width;
                                obj_val[n_obj[12:0]][0] <= {22'd0, imgd_w};
                                obj_tag[n_obj[12:0]][0] <= 3'd0;
                                obj_key[n_obj[12:0]][1] <= id_height;
                                obj_val[n_obj[12:0]][1] <= {22'd0, imgd_h};
                                obj_tag[n_obj[12:0]][1] <= 3'd0;
                                stack[imgd_res] <= {16'd0, n_obj};
                                stack_tag[imgd_res] <= 3'd1;
                                if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                                sp <= imgd_res + 11'd1;
                                fb_dump_sel <= 1'b0;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                imgd_y <= imgd_y + 10'd1;
                                imgd_i <= imgd_i + 19'd1;
                            end
                        end else begin
                            imgd_x <= imgd_x + 10'd1;
                            imgd_i <= imgd_i + 19'd1;
                            fb_dump_addr <= 19'(imgd_y) * 19'(MW) + 19'(imgd_x + 10'd1);
                        end
                    end
                end
                S_IMGD_PUT: begin
                    if (imgd_w == 10'd0 || imgd_h == 10'd0) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        begin
                            logic [9:0] px, py;
                            px = imgd_x0 + imgd_x;
                            py = imgd_y0 + imgd_y;
                            if (px < 10'(MW) && py < 10'(MH) && imgd_i < 19'(FB_PIXELS)) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(py) * 19'(MW) + 19'(px);
                                fb_wdata <= imgd_pix[imgd_i];
                            end else fb_we <= 1'b0;
                        end
                        if (imgd_x >= (imgd_w - 10'd1)) begin
                            imgd_x <= 10'd0;
                            if (imgd_y >= (imgd_h - 10'd1)) begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                imgd_y <= imgd_y + 10'd1;
                                imgd_i <= imgd_i + 19'd1;
                            end
                        end else begin
                            imgd_x <= imgd_x + 10'd1;
                            imgd_i <= imgd_i + 19'd1;
                        end
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
