// JMR-JS stack VM — BRAM code (writable from FAT .JSB) + 640×480 game FB.
// ISA: functional_model/bytecode.py + jsb_format.py
//
// Section map (st_t groups — keep enum order; append new states at the end):
//   boot/load:  S_IDLE..S_TRAIL, S_FETCH_WAIT, S_EXEC, S_NAT
//   raster:     S_CLEAR, S_RECT, S_CIRCLE, S_LINE, S_BLIT, S_SPR, S_PWALK..S_QPY
//   frame:      S_WAIT_FRAME, S_DONE, S_XF_MUL, S_XF_APPLY
//   strings:    S_JOIN..S_CONCAT, S_STRIDX, S_STRIDX_WR, S_REPL, S_IDXSTR,
//               S_FONTPX..S_STR_WR, S_NAMCPY (interned → json_mem)
//   numbers:    S_SQRT, S_DIV, S_MUL, S_ALU
//   calls:      S_CALL, S_FOREACH, S_KEYEV, S_ENV_LOAD
//   JSON:       S_JSON, S_JSON_PARSE
//   ImageData:  S_IMGD_GET, S_IMGD_PUT
module jmr_js_vm #(
    parameter string CODE_HEX = "invaders_jsb.hex",
    // NEW: the 8x8 glyph table PYTHON draws with (functional_model/font8.py,
    // exported by tools/export_font_rom_hex.py) so ctx.fillText paints real
    // characters instead of the old 64x8 bar stub
    parameter string FONT_HEX = "font_rom.hex"
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

    (* ram_style = "block" *) logic [31:0] code_mem [0:CODE_WORDS-1] /*verilator public_flat_rw*/;
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
    logic               var_init [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic signed [31:0] stack  [0:STACK_DEPTH-1];
    // NEW: public for the sim server VMSTAT? probe (FPGA-SIM bring-up only)
    logic [10:0] sp /*verilator public_flat_rd*/; // 2048-deep eval stack
    logic [15:0] ip /*verilator public_flat_rd*/;
    logic [15:0] n_ops, n_consts;
    logic [15:0] ops_base /*verilator public_flat_rd*/;
    logic [15:0] jsb_flags /*verilator public_flat_rd*/;
    logic        looping, running;
    // Value64 is a gated scalar island. It deliberately does not reuse the
    // legacy Q16/tag stack, so a FLAG_VALUE64 image cannot alias old state.
    (* ram_style = "block" *) logic [63:0] vconsts [0:MAX_CONSTS-1];
    (* ram_style = "block" *) logic [63:0] vstack [0:STACK_DEPTH-1] /*verilator public_flat_rd*/;
    // TOS window (FFs) + 1W1R BRAM. CPU combo reads vst_peek[]; writes vst_wr().
    // Vivado 8-7186: ram_style=block is ignored if the CPU always_ff also
    // combo-reads the array (LUTRAM, blows 30 MHz).
    logic [63:0] vst_win [0:15] /*verilator public_flat_rd*/;
    // Combo TOS-window peek — not a function (Vivado Synth 8-660 will not
    // resolve function automatic vst_at from the unique case). Index 0 = TOS.
    // Window only; do not combo-read vstack BRAM (vst_rdata is last beat).
    logic [63:0] vst_peek [0:15];
    logic        vst_we;
    logic [11:0] vst_waddr, vst_raddr;
    logic [63:0] vst_wdata, vst_rdata;
    logic [11:0] vsp_d;
    logic        vst_hold_win;
    // S_V64_WIN_FILL: sequential BRAM reload of vst_win[1..15] (win[0] is TOS).
    logic [3:0]  vst_refill_i;
    logic        vst_refill_arm;
    // ARRAY_SET win[1] (index) can be leftover after getImageData / nested
    // forEach. One BRAM refill then retry; still fault 241 if BRAM is not a
    // Number (do not no-op).
    logic        aset_win_retried;
    (* ram_style = "block" *) logic [63:0] vvars [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic vvar_valid [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic [11:0] vsp /*verilator public_flat_rd*/;
    logic [7:0] vcsp /*verilator public_flat_rd*/;
    logic [31:0] vconst_lo;
    // Value64 DIV/MOD use restoring integer datapaths, one quotient bit per
    // clock. They remain wholly separate from the legacy Q16 divider.
    logic [106:0] vdiv_num, vdiv_quot;
    logic [53:0] vdiv_rem;
    logic [52:0] vdiv_den;
    logic [7:0] vdiv_count;
    logic signed [12:0] vdiv_exp;
    logic vdiv_sign;
    logic [52:0] vmod_rem, vmod_den;
    logic [11:0] vmod_count;
    logic signed [12:0] vmod_exp;
    logic vmod_sign;
    // Stable Value64 heaps. Object and function handles share the
    // MAX_OBJ-slot index space; kind 1 is object and kind 2 is reserved
    // for a function slot. Generations never use zero.
    logic [1:0] vobj_alloc [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [11:0] vobj_gen [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [5:0] vobj_len [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // NEW_OBJ stores the interned class name so CALL_METH can find the
    // class-table method (PYTHON _value_object_classes). 16'hFFFF = none.
    logic [15:0] vobj_cls [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // PYTHON _value_object_protos / _value_function_prototypes. `var Stage =
    // function` + Stage.prototype.createItem is not a JSB class-method table.
    logic [63:0] vobj_proto [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [63:0] vfn_proto [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // Object/array slots are 1-D SRAM after the MAX_* localparams (not 2-D
    // combo arrays — Synth 8-4556 / ASIC SRAM).
    logic [11:0] vfn_gen [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // Function handles are their own leftover-BRAM bank (vfn_* already
    // 1024-wide). They must not occupy vobj_alloc — that shared the 1024
    // bump with objects and faulted MAKE_OBJ while function slots were
    // the ones that were full (same PYTHON lists, same split).
    logic        vfn_valid [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic        vfn_mark [0:MAX_OBJ-1];
    logic [15:0] vfn_entry [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [5:0] vfn_nparam [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [63:0] vfn_env [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [63:0] vfn_bound_this [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [2:0] vfn_flags [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic varr_valid [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [11:0] varr_gen [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [7:0] varr_len [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic varr_long [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [7:0] varr_lidx [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic vlong_used [0:MAX_ARR_LONG-1];
    logic vobj_mark [0:MAX_OBJ-1];
    logic varr_mark [0:MAX_ARR-1];
    logic venv_valid [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [11:0] venv_gen [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [63:0] venv_parent [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [4:0] venv_len [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    // Env slots are 1-D venv_slot SRAM (not 2-D combo — Synth 8-4556).
    logic [63:0] vthis /*verilator public_flat_rd*/;
    logic [63:0] venv /*verilator public_flat_rd*/;
    logic [15:0] vframe_return_ip [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [11:0] vframe_base_sp [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_this [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_env [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_fn [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_ctor [0:CSTK-1] /*verilator public_flat_rd*/;
    // MAKE_FN in this activation captured venv; RET must not recycle it.
    logic vframe_escaped [0:CSTK-1];
    logic [63:0] vgc_queue [0:MAX_OBJ+MAX_ARR+ENV_DEPTH-1];
    logic [13:0] vgc_qr, vgc_qw, vgc_clear_i;
    logic [12:0] vgc_obj_i;
    logic [11:0] vgc_arr_i;
    logic [7:0] vgc_slot_i;
    logic [63:0] vgc_cur;
    logic [11:0] vgc_root_i;
    logic [13:0] valloc_i;
    logic [13:0] vobj_next, varr_next, vfn_next;
    logic [9:0] venv_next;
    logic [1:0] valloc_kind;
    logic valloc_retried, vgc_halt_after;
    logic venv_mark [0:ENV_DEPTH-1];
    logic [9:0] vgc_env_i;
    logic [2:0] vgc_root_phase;
    logic vcall_value;
    logic [15:0] vcall_entry;
    logic [11:0] vcall_argc;
    // CALL_METH / NEW_OBJ ctor: bind this + constructor_value like PYTHON.
    logic vcall_set_this;
    logic [63:0] vcall_this;
    logic [63:0] vcall_ctor_val;
    // PYTHON builtin objects (ELEMENT/CONTEXT/IMAGE) + listener/key dispatch.
    logic [3:0] vobj_builtin [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [2:0] vnat_dom;
    logic [63:0] vnat_style;
    // PYTHON measureText {width} — one reused object (tagged metrics_oid).
    logic [63:0] vmetrics;
    logic        valloc_metrics;
    logic [15:0] vmetrics_w;
    logic [63:0] vkev_event;
    logic [63:0] vlistener_ev [0:15] /*verilator public_flat_rd*/;
    logic [63:0] vlistener_fn [0:15] /*verilator public_flat_rd*/;
    logic [4:0] vlistener_n /*verilator public_flat_rd*/;
    logic [4:0] vkey_li;
    logic v64_frame_armed;
    logic vcallback_key, vcallback_fe;
    logic [63:0] vfe_arr, vfe_fn;
    logic [7:0] vfe_i;
    logic [15:0] vfe_ret;
    // forEach completion must not share vnat_base with fillRect/getContext
    // inside the callback (that left two extras on animate's RET_VAL).
    logic [11:0] vfe_base;
    // Nested forEach (grids.forEach → invaders.forEach → projectiles.forEach).
    logic [63:0] vfe_arr_s [0:7];
    logic [63:0] vfe_fn_s [0:7];
    logic [7:0] vfe_i_s [0:7];
    logic [15:0] vfe_ret_s [0:7];
    logic [11:0] vfe_base_s [0:7];
    logic [3:0] vfe_sp;
    // 0=forEach 1=Array.find 2=Array.map 3=Array.filter
    logic [1:0] vfe_mode;
    logic [1:0] vfe_mode_s [0:7];
    logic [63:0] vfe_map;
    logic [63:0] vfe_map_s [0:7];
    // Coherent asynchronous Value64 subset: rAF and timer queues use stable
    // function handles and explicit callback frames. Listener/key dispatch
    // remains an unsupported native surface until its event objects land.
    logic [63:0] vraf [0:7] /*verilator public_flat_rd*/;
    logic [3:0] vraf_n /*verilator public_flat_rd*/;
    logic [63:0] vraf_snap [0:7];
    logic [3:0] vraf_snap_n, vraf_i;
    logic vtimer_valid [0:63] /*verilator public_flat_rd*/;
    logic signed [31:0] vtimer_due [0:63] /*verilator public_flat_rd*/;
    logic signed [31:0] vtimer_id [0:63] /*verilator public_flat_rd*/;
    logic signed [63:0] vtimer_period [0:63] /*verilator public_flat_rd*/;
    logic [63:0] vtimer_fn [0:63] /*verilator public_flat_rd*/;
    logic [6:0] vtimer_n /*verilator public_flat_rd*/;
    logic [31:0] vframe_no /*verilator public_flat_rd*/;
    logic [31:0] vtimer_seq /*verilator public_flat_rd*/;
    logic [31:0] vrng;
    logic [8:0] vconsole_n;
    logic [6:0] vtimer_pick;
    logic vcallback_raf, vcallback_timer;
    logic vgc_wait_after;
    // After a mid-op collect, resume the caller instead of S_V64_ALLOC.
    // 0=alloc retry  1=re-fetch current op (map/filter dest)  2=JSON.parse
    // 3=JSON.stringify result object.
    logic [1:0] vgc_resume;
    logic [11:0] vnat_base;
    // Sequential find-free (S_FREE_OBJ / S_FREE_ARR) — no MAX_* combo mux.
    logic vfree_armed, vfree_ok;
    logic vfree_arr_long;
    // Tagged-env recycle FSM (S_REL_ENV) — not nested ENV_DEPTH×ENV_DEPTH.
    logic [5:0] rel_saved, rel_lim, rel_i, rel_nn;
    // Sequential vstack copy/shift (S_V64_BIND).
    logic [1:0]  bind_mode;
    logic [7:0]  bind_k, bind_n, bind_argc;
    logic [11:0] bind_base, bind_src, bind_vsp_next;
    logic [15:0] bind_ip;
    logic [63:0] bind_ins;
    logic        bind_armed, bind_rd_arm;
    // Math.min/max one arg per clock (not a 256-wide vstack mux).
    logic        minmax_is_min;
    logic [7:0]  minmax_k, minmax_n;
    logic [11:0] minmax_base;
    logic [63:0] minmax_acc;
    logic [18:0] vdraw_i;
    logic [9:0] vdraw_x, vdraw_y, vdraw_w, vdraw_h;
    // Scan cursor so S_V64_RECT is adders, not /% per pixel (Verilator
    // combo divide made full-canvas fillRect feel frozen-slow).
    logic [9:0] vdraw_cx, vdraw_cy;
    logic [7:0] vdraw_color;
    // NEW: tagged stack/vars for HTML heap (0=int 1=obj 2=arr 3=str 4=fn 5=undef 6=elem)
    logic [2:0]  stack_tag [0:STACK_DEPTH-1];
    logic [2:0]  var_tag   [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    // Slot SRAM must fit leftover T200 BRAM after dual 640×480 FB (~0.6 MB)
    // of ~1.64 MB total: leftover ~1 MB for code + heap + console. Overflow
    // loud. Same numbers in hardware_model/js_vm.py. Not title-sized.
    localparam int MAX_OBJ = 1024;
    localparam int OBJ_RING = MAX_OBJ / 2; // wrap point: boot heap stays below
    localparam int OBJ_SLOTS = 32; // property slots per object (Object.assign)
    // Two-tier arrays, same total bits as 512×128: short 1024×32 (nested
    // number-array maps / JSON clones) plus long 256×128 (push past 32).
    // Handle stays put on promote (varr_long + varr_lidx). Overflow loud.
    // Same 65536 × 64b words as 1024×32+256×128 (leftover BRAM). More short
    // handles for nested map + JSON clones; long bank still covers push>32.
    localparam int MAX_ARR_SHORT = 1536;
    localparam int ARR_SHORT_CAP = 32;
    localparam int MAX_ARR_LONG = 128;
    localparam int MAX_ARR = MAX_ARR_SHORT + MAX_ARR_LONG;
    localparam int ARR_RING = MAX_ARR / 2;
    // NEW: per-call lexical env (FM bytecode.py env dict). LIFO frames;
    // MAKE_FN snapshots the current frame onto the Fn heap object so
    // setTimeout/rAF closures keep forEach params after the call returns.
    // Slot SRAM is 1-D venv_slot (Synth 8-4556 was 2-D venv_val). Same
    // ENV_DEPTH in hardware_model/js_vm.py. Overflow loud.
    localparam int ENV_DEPTH = 512;
    localparam int TAGGED_ENV_DEPTH = 32;
    localparam int ENV_SLOTS = 16;
    // Finite general timer queue. A legal JS loop can have one pending timeout
    // per frame until an older delay expires, so eight entries was not viable.
    localparam int TIMER_DEPTH = 64;
    localparam logic [15:0] CLS_FN = 16'hFFEF;
    localparam logic [15:0] CLS_REGEX = 16'hFFEE;  // packed pattern+flags in slot0
    localparam logic [15:0] CLS_DYNSTR = 16'hFFED; // JSON/replace text in json_mem
    localparam logic [15:0] CLS_IMGD = 16'hFFEC;   // one ImageData snapshot (VM cap)
    localparam logic [15:0] CLS_ENV = 16'hFFEA;    // live lexical env (FM env dict)
    localparam int JSON_CAP = 8192; // VM-capped scratch; loud overflow, not title-sized
    localparam int JSON_STK = 32;
    localparam int ARR_CAP = 128;
    // 1-D slot SRAM: two-tier concat, not MAX_ARR×ARR_CAP (that would be
    // 1280×128). Short aid*32+slot with aid[10:0] (0..1535); long
    // VARR_SHORT_WORDS+lidx*128+slot. aid[9:0] aliased 1024..1535 onto
    // 0..511 (PACMAN map[0].length undefined at arr>1024 → finder 241).
    // Object slot field is 5 bits (OBJ_SLOTS=32). Array slot field is
    // 7 bits (ARR_CAP=128). Same memories for tagged and Value64
    // (tagged val is the low 32 bits).
    localparam int VOBJ_WORDS = MAX_OBJ * OBJ_SLOTS;
    localparam int VARR_SHORT_WORDS = MAX_ARR_SHORT * ARR_SHORT_CAP;
    localparam int VARR_WORDS = VARR_SHORT_WORDS + MAX_ARR_LONG * ARR_CAP;
    localparam int VENV_WORDS = ENV_DEPTH * ENV_SLOTS;
    localparam int VOBJ_AW = $clog2(VOBJ_WORDS);
    localparam int VARR_AW = $clog2(VARR_WORDS);
    localparam int VENV_AW = $clog2(VENV_WORDS);
    // NEW: 3, was 8. With no rewind during the grace window, 8 frames of
    // per-frame temps got baked into the kept region when the watermark
    // snapshots (PACMAN sat at obj=3263), leaving too little nursery headroom —
    // a frame then allocated over its own live rAF Fn object, so the dispatcher
    // ran a stale function that never re-armed and the game froze on its first
    // drawn frame (raf=0). 3 still covers the boot rAF/click/nextStage chain.
    localparam int ARR_KEEP_DELAY = 3; // boot rAF/click/nextStage before nursery
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
    logic [15:0] n_obj_keep /*verilator public_flat_rd*/; // NEW: debug peek (bring-up)
    logic        obj_keep_ok;
    logic [3:0]  obj_keep_wait;
    logic        frame_fire /*verilator public_flat_rd*/; // fire rAF/keys after GC or input
    // NEW: public for the sim OBJPEEK probe (bring-up visibility only)
    logic [5:0]  obj_n    [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [15:0] obj_cls  [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // 1-D Fn metadata (not a slot mux). MAKE_FN writes these + SRAM via OSETI.
    logic [15:0] tfn_entry [0:MAX_OBJ-1];
    logic [7:0]  tfn_nparam [0:MAX_OBJ-1];
    logic [15:0] tfn_parent [0:MAX_OBJ-1];
    logic [15:0] tfn_this [0:MAX_OBJ-1];
    logic [2:0]  tfn_this_tag [0:MAX_OBJ-1];
    logic        tfn_has_this [0:MAX_OBJ-1];
    logic [15:0] tenv_parent [0:MAX_OBJ-1];
    logic [7:0]  arr_len  [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    // Stable-handle collector. It traces roots at frame safe points and only
    // reclaims an unmarked tail; live object/array indices never move.
    logic        gc_obj_mark [0:MAX_OBJ-1];
    logic        gc_arr_mark [0:MAX_ARR-1];
    logic [13:0] gc_queue [0:16383]; // bit13=array, bits12:0=stable index
    logic [13:0] gc_qr, gc_qw;
    logic [12:0] gc_i;
    logic [12:0] gc_root_i;
    logic [6:0]  gc_slot;
    logic [13:0] gc_cur;
    logic [15:0] gc_obj_high, gc_arr_high;
    logic [15:0] dbg_gc_n /*verilator public_flat_rd*/;
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
    logic [6:0]  csp /*verilator public_flat_rd*/;
    logic [5:0]  env_sp /*verilator public_flat_rd*/; // 0 = top-level (vars[] only)
    logic [15:0] env_oid [0:ENV_DEPTH-1]; // NEW: live heap env objects (not value snapshots)
    logic        env_cap [0:ENV_DEPTH-1]; // NEW: MAKE_FN captured this frame
    logic [15:0] env_free [0:ENV_DEPTH-1] /*verilator public_flat_rd*/; // NEW: recycled uncaptured env oids (peek)
    logic [5:0]  env_free_n /*verilator public_flat_rd*/;
    logic [15:0] env_walk; // heap env object id (parent chain)
    logic [8:0]  env_ld_slot;
    logic        env_is_store;
    logic [15:0] dbg_heap_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_to_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_stack_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_call_ovf /*verilator public_flat_rd*/;
    logic        machine_fault /*verilator public_flat_rd*/;
    logic [7:0]  fault_code /*verilator public_flat_rd*/;
    logic [15:0] to_fn [0:TIMER_DEPTH-1] /*verilator public_flat_rd*/; // setTimeout/setInterval Fn handles
    logic [6:0]  to_n /*verilator public_flat_rd*/;
    // NEW: timers whose queued oid no longer holds a CLS_FN at fire time.
    // Executing such a slot ran top-level code mid-game (globals reset,
    // INVADERS kill timers lost) — count and drop instead.
    logic [15:0] dbg_tmr_mis /*verilator public_flat_rd*/;
    logic [15:0] dbg_tmr_sched /*verilator public_flat_rd*/; // setTimeout accepted
    logic [15:0] dbg_tmr_fire /*verilator public_flat_rd*/;  // callbacks launched
    // NEW: Array.find hits + splice calls — play log must show whether a
    // timeout actually culled (tsch/tfire alone cannot).
    logic [15:0] dbg_find_hit /*verilator public_flat_rd*/;
    logic [15:0] dbg_splice_n /*verilator public_flat_rd*/;
    // NEW: slow-path S_DIV entries (not the 1-cycle /2 shift). Play logs
    // show whether a frame is still paying 48 clocks per `width/2`.
    logic [15:0] dbg_div_n /*verilator public_flat_rd*/;
    logic [11:0] to_delay [0:TIMER_DEPTH-1] /*verilator public_flat_rd*/; // remaining frames (delay_ms/17)
    logic [11:0] to_period [0:TIMER_DEPTH-1]; // 0 = one-shot; else interval re-arm
    logic [15:0] to_id [0:TIMER_DEPTH-1];
    logic [15:0] to_seq;
    logic [15:0] id_replace;
    // NEW: interned string BYTES. jsb_format already writes every name as UTF-8
    // at the end of the trailer, but only PYTHON decoded it — RTL kept a hash +
    // length and no characters, so str[i] was undefined and str.length was
    // undefined too. Any string-row sprite therefore drew nothing (INVADERS
    // drawBitmap walks row[col] === "1"), while fillRect/drawImage art painted.
    // On-chip BRAM with a registered read: one-cycle random access on FPGA and
    // ASIC alike. The 4 MB external bank stays for art, never for code strings.
    localparam int NAME_CAP = 32768;
    logic [7:0]  name_mem [0:NAME_CAP-1] /*verilator public_flat_rd*/;
    logic [15:0] name_off [0:1023] /*verilator public_flat_rd*/;   // intern idx -> first byte in name_mem
    // NAMB u16 byte length. Hash-table name_len_tbl is u8 (concat fold).
    // str[i] / str.length must use this or a 624-char layout literal
    // reports length 112 (624&255) and never carves tunnels.
    logic [15:0] name_blen [0:1023] /*verilator public_flat_rd*/;
    logic [15:0] name_rdaddr;
    logic [7:0]  name_rdata;          // registered read (BRAM, not a mux)
    // NEW: sequential str[i] prefetch — next GET_IDX of i+1 hits name_rdata
    logic [15:0] str_pf_id;
    logic signed [31:0] str_pf_ci;
    logic        str_pf_ok;
    logic [15:0] dbg_str_ovf /*verilator public_flat_rd*/; // bytes past NAME_CAP
    // NEW: ip where the last frame-level callback returned (VMSTAT cbip)
    logic [15:0] dbg_cb_ip /*verilator public_flat_rd*/;
    // NEW: byte -> interned idx for every 1-char name, so str[i] hands back a
    // value that OP_EQ matches against a "x" literal by intern id — one lookup,
    // no scan over the name table.
    logic [15:0] char_id [0:255];
    logic        char_ok [0:255];
    logic        name_has [0:1023];   // this intern id has bytes in name_mem
    logic        names_ok;            // name bytes present AND byte-aligned
    logic [15:0] nb_i, nb_len;
    logic        nb_one;              // this name is exactly 1 byte (char lookup)
    logic [15:0] nb_wp /*verilator public_flat_rd*/; // bytes loaded (VMSTAT strb)
    logic [10:0] str_res;             // stack slot the char is written back to
    // NEW: 8x8 glyph ROM — one BRAM, registered read, same bytes as the console
    // scanout font. fillText was a filled 64x8 bar before this; every HUD in
    // every title (not just the three) now gets the PYTHON glyphs.
    (* ram_style = "block" *) logic [7:0] font_rom [0:1023];
    initial $readmemh(FONT_HEX, font_rom);
    logic [9:0]  font_raddr;
    logic [7:0]  font_rdata;          // registered read (BRAM, not a mux)
    // NEW: text staging buffer. Interned bytes, dynstr bytes and plain numbers
    // are all expanded here, so the glyph raster (and the string concat that
    // materialises dynamic interns) has exactly one byte source.
    localparam int TXT_MAX = 64;
    logic [7:0]  txt_buf [0:TXT_MAX-1];
    logic [6:0]  txt_len, txt_i, txt_bn;
    logic [3:0]  txt_ph;
    logic [2:0]  txt_row, txt_col;
    logic [3:0]  txt_k, txt_kx, txt_ky; // integer glyph scale + sub-pixel repeat
    logic [7:0]  txt_bits;
    logic signed [15:0] txt_px, txt_py; // pen after ctx transform (may be off-glass)
    logic signed [15:0] txt_x0, txt_y0; // aligned top-left of the first glyph
    logic [3:0]  txt_pi;                // P10 index while expanding a number
    logic [3:0]  txt_d;                 // digit being accumulated
    logic signed [31:0] txt_v;
    logic [15:0] txt_rp;                // name_mem / json_mem read cursor
    logic [31:0] txt_val;               // the text argument itself
    logic [2:0]  txt_vt;
    logic signed [47:0] txt_kp;         // font_px x ctx_sx (scale product)
    logic [15:0] txt_w;                 // text width in device pixels
    logic [1:0]  ctx_align;             // ctx.textAlign 0=left 1=center 2=right
    logic [7:0]  ctx_font_px;           // ctx.font "NNpx ..." size (FM default 8)
    logic [7:0]  fpx_acc;               // digits seen while parsing ctx.font
    logic [7:0]  fp_left;               // bytes left in the font string
    // NEW: JSON/text scratch (stringify/parse/replace) — VM cap, sticky ovf
    logic [7:0]  json_mem [0:JSON_CAP-1];
    logic [13:0] json_wp, json_rp, json_src, json_srclen, json_dst;
    logic        namcpy_repl; // S_NAMCPY then S_REPL (else S_JSON_PARSE)
    logic        namcpy_v64;  // S_NAMCPY then S_V64_JSON_PARSE
    logic        namcpy_armed; // wait 1 cycle for registered name_rdata
    logic [63:0] vjs_val [0:JSON_STK-1]; // Value64 stringify/parse walk
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
    // ram_style block: a 307200-entry unpacked mux in Verilator made
    // S_IMGD_GET miss its i++ NBA and spin until the 16M FRAME cap.
    (* ram_style = "block" *) logic [7:0] imgd_pix [0:FB_PIXELS-1];
    logic [18:0] imgd_i /*verilator public_flat_rd*/, imgd_n /*verilator public_flat_rd*/;
    logic [9:0]  imgd_x0, imgd_y0, imgd_w /*verilator public_flat_rd*/, imgd_h /*verilator public_flat_rd*/, imgd_x, imgd_y;
    logic        imgd_armed;
    logic        imgd_v64;              // Value64 get/putImageData uses vobj not tagged n_obj
    logic [10:0] imgd_res;
    // 16'hFFFF is the explicit JavaScript "no dynamic this" sentinel.
    // Real heap handles are below MAX_OBJ, so object 0 remains a valid receiver.
    logic [15:0] this_obj;
    logic [8:0]  var_this;   // NEW: LOAD_VAR slot for __this
    logic        this_ok;
    logic [15:0] raf_fn [0:7] /*verilator public_flat_rd*/; // NEW: debug peek (bring-up)
    logic [3:0]  raf_n /*verilator public_flat_rd*/;
    logic [15:0] kd_fn /*verilator public_flat_rd*/, ku_fn, click_fn; // interned MAKE_FN entries; 0xFFFF=none
    // NEW: keydown/keyup listener table (4 slots, fire all; last-wins was a parity gap)
    logic [15:0] kd_slot [0:3], ku_slot [0:3];
    logic [2:0]  kd_n /*verilator public_flat_rd*/, ku_n /*verilator public_flat_rd*/;
    logic [1:0]  kev_li;   // which table slot is firing
    logic [15:0] kev_obj;  // event object reused for remaining listeners
    logic        kev_is_down;
    logic [15:0] kev_ret_ip; // after listener table: next op (dispatchEvent) or n_ops (KEYEVT)
    logic        boot_clr; // NEW: clear both FB banks before first op
    logic [1:0]  boot_clr_n;
    logic [15:0] id_find; // Array.find
    logic [15:0] id_findindex, id_filter; // Array.findIndex / Array.filter
    logic        click_fired; // NEW: HTML auto-start click once
    logic        pre_click_raf; // NEW: one rAF (Image.onload) before click
    logic [5:0]  prev_joy;
    logic [5:0]  joy_down_edge, joy_up_edge;
    logic [7:0]  fill_style_i;
    logic [7:0]  stroke_style_i; // PYTHON ctx.strokeStyle — not fillStyle
    logic [31:0] lfsr;
    logic [15:0] id_fillrect, id_length, id_push, id_pop, id_splice, id_foreach;
    logic [15:0] id_map, id_unshift; // Array.map / Array.unshift
    logic [15:0] id_getctx, id_click, id_ael, id_key, id_keycode;
    logic [15:0] id_rel, id_disp; // removeEventListener / dispatchEvent
    logic [15:0] id_document, id_window; // seed vars so `if (document.dispatchEvent)` is truthy
    logic [15:0] id_arrow_l, id_arrow_r, id_space, id_a, id_d, id_keydown, id_keyup;
    // NEW: e.key for the vertical arrows. Without these the Up/Down keyCode
    // arrived with event.key = "ArrowLeft" (the old ternary default), so a
    // `switch (e.key)` game turned left on every vertical press.
    logic [15:0] id_arrow_u, id_arrow_d;
    logic [15:0] id_reduce, id_draw, id_update, id_fillstyle, id_clearrect, id_drawimage;
    logic [15:0] id_this_name, id_black, id_white, id_red, id_yellow, id_cyan, id_gold;
    logic [15:0] id_src, id_onload, id_width, id_height;
    logic [15:0] id_style; // nested canvas.style for GET_PROP/SET_PROP
    logic [15:0] id_hex_fff, id_hex_3f6, id_hex_f5a, id_hex_fc0, id_hex_2ec, id_hex_000;
    logic [15:0] id_save, id_restore, id_translate, id_rotate;
    logic [15:0] id_settransform; // NEW: ctx.setTransform(a,b,c,d,e,f)
    logic [15:0] id_assign, id_bind, id_proto, id_filltext, id_arc, id_enter;
    // NEW: text state — ctx.font px size, ctx.textAlign and its two non-left
    // values, plus measureText (games right-align HUD text with its width)
    logic [15:0] id_font, id_textalign, id_center, id_right, id_measuretext;
    logic [15:0] id_imgsmooth; // ctx.imageSmoothingEnabled (hash 54440)
    logic        ctx_smooth;   // 1 default; indexed blit is always nearest
    logic [15:0] metrics_oid; // the one reserved measureText result object
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
    // NEW: typeof result intern ids (jsb_format._name_hash of the JS strings)
    logic [15:0] id_str_undef, id_str_number, id_str_string, id_str_object, id_str_function;
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
    logic [7:0]  name_len_tbl  [0:1023] /*verilator public_flat_rd*/; // intern idx -> byte length (concat fold)
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
    logic        cc_second;
    logic [1:0]  cc_st;   // 0=classify 1=digit fold 2=copy operand bytes
    logic [15:0] cc_h;
    logic [7:0]  cc_len;
    logic [3:0]  cc_pi, cc_d;
    // NEW: the joined string also gets real BYTES (staged in txt_buf, then
    // written into name_mem when the intern is allocated). Without this a
    // concat was hash-only, so "SCORE " + n had a length but no characters
    // and fillText / str[i] / .length could not see it.
    logic [15:0] cc_cp;   // name_mem read cursor for a string operand
    logic [7:0]  cc_cn;   // bytes still to copy
    logic        cc_bok;  // every operand's bytes made it into txt_buf
    // Value64 string + reuses S_CONCAT / S_JOIN_FIND; write vstack not stack.
    logic        v64_concat;
    logic        v64_join; // arr.join('') writeback via S_JOIN_FIND → vstack
    logic        v64_sqrt; // Math.sqrt writeback via S_SQRT → vstack
    // Value64 String.replace reuses S_REPL match, then writes a dynstr.
    logic        v64_repl;
    // Date.now / performance.now GET_PROP allocates a native-35 function
    // (PYTHON entry=-35). CALL_VAL sees vfn_entry 16'hfffa.
    logic        valloc_now_fn;
    logic        valloc_regex;
    // Packed pattern/flags from the const pool (same i32 as tagged CLS_REGEX).
    logic [31:0] valloc_regex_pack;
    // Array(n) hole count for native 34 (PYTHON length-n undefined slots).
    logic [7:0]  valloc_arr_n;
    // MAKE_FN entry/a1 latched at fetch. S_V64_ALLOC must not re-read
    // code_rdata — GC resume (or a JUMP-to-MAKE_FN with a skipped RET_VAL
    // a0=0 in the previous word) would store entry 0, and CALL_METHOD
    // then restarts the ProgramImage (maps IIFE nested until MAX_ARR).
    logic [15:0] valloc_fn_entry;
    logic [7:0]  valloc_fn_a1;
    // GET_PROP .prototype on a function: alloc empty proto object (PYTHON).
    logic        valloc_proto;
    logic [12:0] valloc_proto_fn;
    // fn.bind(this) — PYTHON copies entry/env and sets has_bound_this.
    logic        valloc_bind;
    logic [12:0] valloc_bind_src;
    logic [63:0] valloc_bind_this;
    logic [5:0]  vctor_scan;
    logic        vctor_armed;
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
    // NEW: a pass (rAF/timer/key callback or top-level) finished this frame.
    // Present ONCE at the next frame tick instead of once per callback return:
    // every setTimeout callback and key listener crossed the ip>=n_ops
    // boundary and pulsed its own fb_swap, so buffers flipped mid-frame and
    // the glass interleaved two half-drawn banks (PACMAN maze mutilated on
    // keypress, INVADERS ran at half speed with vanishing draws).
    logic        present_pend;
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
    // NEW: 6 bits — phases 32..34 stream the trailer's UTF-8 name bytes
    // (5'd31 stays the "done, go run code" sentinel and still zero-extends)
    logic [5:0]  trail_ph;
    logic [7:0]  trail_cls_i, trail_meth_i, trail_nmeth;
    logic [8:0]  trail_var_slot;
    logic [7:0]  trail_tb; // NEW: combo byte from code_rdata (do not declare inside always_ff)
    // NEW: 20 bits — the walk now also streams the UTF-8 name bytes, so the
    // watchdog has to allow NAME_CAP bytes on top of the tables it used to cover
    logic [19:0] trail_guard; // NEW: force FETCH if walker never hits phase 22

    typedef enum logic [6:0] {
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
        // NEW: str[i] — address cycle then write-back for the registered
        // name_mem (BRAM) read
        S_STRIDX, S_STRIDX_WR,
        // NEW: real fillText — parse ctx.font px, stage the text bytes, then
        // raster 8x8 glyphs; S_STR_WR gives a joined string its bytes
        S_FONTPX, S_TXT_LD, S_TXT_DRAW, S_STR_WR,
        // NEW: Canvas ImageData snapshot (one buffer, FM twin)
        S_IMGD_GET, S_IMGD_PUT,
        // NEW: copy interned name_mem bytes into json_mem (parse/replace).
        // Appended so existing sname= indices stay valid.
        S_NAMCPY,
        // NEW: depth-1 element copy for SET_PROP array-over-array
        // (map.data = JSON.parse(...) at PACMAN level start / any re-parse).
        // Ref-copying rows left nursery arr ids inside an old-space array;
        // the next frame rewind recycled those ids into draw temps
        // (code=[0,0,0,0]) so the maze read back 4-wide garbage.
        S_ARR_DCOPY,
        // Stable-handle mark/tail-sweep collector at frame safe points.
        S_GC_CLEAR, S_GC_ROOT, S_GC_POP, S_GC_OBJ, S_GC_ARR,
        // Value64 states are append-only: every legacy state keeps its number.
        S_V64_CONST_HI, S_V64_EXEC,
        S_V64_DIV, S_V64_DIV_FIN, S_V64_MOD,
        S_V64_ALLOC, S_V64_GC_CLEAR, S_V64_GC_ROOT,
        S_V64_GC_POP, S_V64_GC_OBJ, S_V64_GC_ARR,
        S_V64_GC_SWEEP_OBJ, S_V64_GC_SWEEP_ARR,
        S_V64_GC_FN, S_V64_GC_ENV, S_V64_GC_SWEEP_ENV,
        S_V64_CLEAR, S_V64_RECT, S_V64_WAIT_FRAME,
        S_V64_FRAME_RAF, S_V64_FRAME_TIMER,
        S_V64_FOREACH, S_V64_FRAME_KEY,
        // name_mem BRAM lag for Value64 "str"[i] (row[col]==="1").
        S_V64_STRIDX, S_V64_STRIDX_WR,
        // Value64 JSON.stringify/parse of nested number arrays (map.data clone).
        S_V64_JSON, S_V64_JSON_PARSE,
        // Pad missing ctor/method args to LET_VAR nparam (PYTHON bind_argv).
        S_V64_CTOR_PAD,
        // 1-D heap slot scan (registered SRAM). Append-only numbers.
        S_HEAP_WAIT, S_HEAP_CMP, S_HEAP_WR, S_HEAP_AWR, S_HEAP_FILL,
        S_V64_METH, S_V64_FE_ELEM, S_V64_FE_FILTER, S_V64_OGETI_NAT,
        S_V64_IDXSCAN,
        // Env slot scan completion (NEW_OBJ ctor lookup after S_HEAP_*).
        S_V64_CTOR_ENV,
        // Synth 8-3380 / unroll: walk tagged-env recycle and find-free
        // one index per clock (not a task for-loop over ENV_DEPTH/MAX_*).
        S_REL_ENV, S_FREE_OBJ, S_FREE_ARR,
        // 1W1R vstack copies (bind_argv / ctor insert) and Math.min/max.
        S_V64_BIND, S_V64_MINMAX,
        // After a vsp drop of 16+ the TOS FF window is stale; refill from BRAM.
        S_V64_WIN_FILL,
        // Short→long array promote (same handle; copy then flip varr_long).
        S_ARR_PROMOTE
    } st_t;
    st_t state /*verilator public_flat_rd*/, ret_state;
    logic vprom_done, vprom_copy, hp_prom_wr;
    logic [7:0] hp_prom_phys;
    st_t vprom_ret;

    // Packed object slot {key[15:0], val[63:0]} and array val SRAM.
    // 1W1R registered — storage_engine sbuf / jmr_video_vram Port A.
    // Dump/CHECKPOINT peeks this array (not a third hardware port).
    (* ram_style = "block" *) logic [79:0] vobj_slot [0:VOBJ_WORDS-1]
        /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [2:0] vobj_tmem [0:VOBJ_WORDS-1]
        /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot [0:VARR_WORDS-1]
        /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [2:0] varr_tmem [0:VARR_WORDS-1]
        /*verilator public_flat_rd*/;
    // Packed env slot {key[8:0], val[63:0]} in low 73 of 80. 1W1R like vobj.
    (* ram_style = "block" *) logic [79:0] venv_slot [0:VENV_WORDS-1]
        /*verilator public_flat_rd*/;
    logic        vobj_we, varr_we, venv_we;
    logic [VOBJ_AW-1:0] vobj_waddr, vobj_raddr;
    logic [VARR_AW-1:0] varr_waddr, varr_raddr;
    logic [VENV_AW-1:0] venv_waddr, venv_raddr;
    logic [79:0] vobj_wdata, vobj_rdata;
    logic [79:0] venv_wdata, venv_rdata;
    logic [2:0]  vobj_trdata, varr_trdata, hp_tag;
    logic [63:0] varr_wdata, varr_rdata;

    // Two-tier array address (not MAX_ARR×128 concat). Combo mux of the
    // per-handle bank bit is metadata, not a megabit slot mux.
    function automatic [VARR_AW-1:0] varr_slot_addr;
        input [11:0] aid;
        input [6:0] slot;
        begin
            // Linear 1-D (same as sim/sim_main.cpp varr_addr). Packed
            // {1'b0,aid[9:0],slot[4:0]} only had 1024 unique short rows.
            if (varr_long[aid])
                varr_slot_addr = VARR_AW'(VARR_SHORT_WORDS
                    + {1'b0, varr_lidx[aid], slot});
            else
                varr_slot_addr = VARR_AW'({aid[10:0], slot[4:0]});
        end
    endfunction

    // Heap FSM: scan stops at vobj_len / varr_len, 2 clks/slot (addr, cmp).
    localparam logic [3:0] HP_GETPROP = 4'd0;
    localparam logic [3:0] HP_SETPROP = 4'd1;
    localparam logic [3:0] HP_ARRGET  = 4'd2;
    localparam logic [3:0] HP_ARRSET  = 4'd3;
    localparam logic [3:0] HP_AFILL   = 4'd4;
    localparam logic [3:0] HP_OSETI   = 4'd5;
    localparam logic [3:0] HP_OGETI   = 4'd6;
    localparam logic [3:0] HP_LOOKFN  = 4'd7;
    localparam logic [3:0] HP_GETIDX  = 4'd8;
    localparam logic [3:0] HP_SETIDX  = 4'd9;
    localparam logic [3:0] HP_PUSH    = 4'd10;
    localparam logic [3:0] HP_UNSHIFT = 4'd11;
    localparam logic [3:0] HP_SPLICE  = 4'd12;
    localparam logic [3:0] HP_ASSIGN  = 4'd13;
    localparam logic [3:0] HP_AGETI   = 4'd14;
    localparam logic [3:0] HP_ASETI   = 4'd15;
    logic [3:0]  hp_cmd;
    logic        hp_v64;
    logic [12:0] hp_oid;
    logic [11:0] hp_aid;
    logic        hp_env; // S_HEAP_* talks to venv_slot (LOAD/STORE/LET/ctor)
    logic [9:0]  hp_eid;
    logic [4:0]  hp_slot;
    logic [6:0]  hp_aslot;
    logic [5:0]  hp_len;
    logic [7:0]  hp_alen, hp_lim;
    logic [15:0] hp_key;
    logic [63:0] hp_wval, hp_rval;
    logic        hp_hit;
    st_t         hp_ret;
    st_t         rel_ret, bind_ret;
    st_t         vst_refill_ret;
    logic [2:0]  hp_phase;
    logic [63:0] hp_proto;
    logic [15:0] hp_qk [0:3];
    logic [63:0] hp_qv [0:3];
    logic [2:0]  hp_qt [0:3];
    logic [2:0]  hp_qn, hp_qi;
    logic        vgc_rd_arm, jn_rd_arm, vfe_rd_arm, vjs_rd_arm;
    logic [12:0] hp_si, hp_ti;
    logic [4:0]  hp_ss;
    logic [5:0]  hp_tn;
    // Sequential array init copies stack[hp_vbase+i] (regs, not SRAM mux).
    logic        hp_from_stack;
    logic        hp_make_arr; // MAKE_ARRAY: write handle after fill (not before)
    logic [11:0] hp_vbase;
    logic [15:0] hp_spr_w, hp_spr_h;
    // OGETI continuation: 0 parse 1 putimg 2 meas 3 idxof 4 repl 5 regex
    logic [3:0]  hp_nat;

    // NEW: S_ARR_DCOPY scratch (SET_PROP array-over-array deep row copy)
    logic [11:0] dc_src, dc_dst;
    logic [7:0]  dc_i;
    logic        dc_arm;

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
    import jmr_value_pkg::*;
    // Number/tag helpers live in jmr_value.sv. Heap/GC tasks stay below.

    // Synthesizable integer/bit IEEE-754 binary64 add. NaNs are always
    // canonicalized to the frozen Value64 ABI word.
    task automatic v64_add_task(
        input logic [63:0] aa,
        input logic [63:0] bb,
        output logic [63:0] result
    );
        logic sa, sb, sr;
        logic [10:0] ea, eb;
        logic [51:0] fa, fb;
        logic [52:0] ma, mb, mant;
        logic [55:0] xa, xb, sig;
        logic [56:0] sum;
        logic [53:0] rounded;
        integer er, diff;
        logic [10:0] ef;
        begin
            sa = aa[63]; sb = bb[63];
            ea = aa[62:52]; eb = bb[62:52];
            fa = aa[51:0]; fb = bb[51:0];
            if ((ea == 11'h7ff && fa != 0) ||
                (eb == 11'h7ff && fb != 0) ||
                (ea == 11'h7ff && eb == 11'h7ff && sa != sb)) begin
                result = V64_CANON_NAN;
            end else if (ea == 11'h7ff) begin
                result = {sa, 11'h7ff, 52'd0};
            end else if (eb == 11'h7ff) begin
                result = {sb, 11'h7ff, 52'd0};
            end else if (aa[62:0] == 0 && bb[62:0] == 0) begin
                result = {sa & sb, 63'd0};
            end else if (aa[62:0] == 0) begin
                result = bb;
            end else if (bb[62:0] == 0) begin
                result = aa;
            end else begin
                ma = {1'b0, fa};
                mb = {1'b0, fb};
                if (ea != 0) ma[52] = 1'b1;
                if (eb != 0) mb[52] = 1'b1;
                xa = {ma, 3'b000};
                xb = {mb, 3'b000};
                // Keep xa as the larger magnitude so subtraction has no sign
                // borrow and signed zero cancellation is deterministic.
                if (((ea == 0) ? 1 : ea) < ((eb == 0) ? 1 : eb) ||
                    (((ea == 0) ? 1 : ea) == ((eb == 0) ? 1 : eb) &&
                     ma < mb)) begin
                    sig = xa; xa = xb; xb = sig;
                    er = (eb == 0) ? 1 : eb;
                    diff = er - ((ea == 0) ? 1 : ea);
                    sr = sb;
                end else begin
                    er = (ea == 0) ? 1 : ea;
                    diff = er - ((eb == 0) ? 1 : eb);
                    sr = sa;
                end
                xb = v64_shr_sticky(xb, diff);
                if (sa == sb) begin
                    sum = {1'b0, xa} + {1'b0, xb};
                    if (sum[56]) begin
                        sig = sum[56:1];
                        sig[0] = sig[0] | sum[0];
                        er = er + 1;
                    end else
                        sig = sum[55:0];
                end else begin
                    sig = xa - xb;
                    if (sig == 0)
                        sr = 1'b0;
                    for (int k = 0; k < 55; k++) begin
                        if (sig[55] == 1'b0 && sig != 0 && er > 1) begin
                            sig = sig << 1;
                            er = er - 1;
                        end
                    end
                end
                mant = sig[55:3];
                rounded = {1'b0, mant}
                        + (sig[2] && (sig[1] || sig[0] || mant[0]));
                if (rounded[53]) begin
                    mant = rounded[53:1];
                    er = er + 1;
                end else
                    mant = rounded[52:0];
                if (er >= 2047)
                    result = {sr, 11'h7ff, 52'd0};
                else if (mant == 0)
                    result = {sr, 63'd0};
                else begin
                    ef = (er == 1 && !mant[52]) ? 11'd0 : 11'(er);
                    result = {sr, ef, mant[51:0]};
                end
            end
        end
    endtask

    // Synthesizable 53x53 integer multiply with binary64 normalization and
    // round-to-nearest-even.
    task automatic v64_mul_task(
        input logic [63:0] aa,
        input logic [63:0] bb,
        output logic [63:0] result
    );
        logic sign;
        logic [10:0] ea, eb, ef;
        logic [51:0] fa, fb;
        logic [52:0] ma, mb, q;
        logic [53:0] rounded;
        logic [105:0] product;
        logic guard, sticky;
        integer p, er, shift;
        begin
            sign = aa[63] ^ bb[63];
            ea = aa[62:52]; eb = bb[62:52];
            fa = aa[51:0]; fb = bb[51:0];
            if ((ea == 11'h7ff && fa != 0) ||
                (eb == 11'h7ff && fb != 0) ||
                ((ea == 11'h7ff || eb == 11'h7ff) &&
                 (aa[62:0] == 0 || bb[62:0] == 0))) begin
                result = V64_CANON_NAN;
            end else if (ea == 11'h7ff || eb == 11'h7ff) begin
                result = {sign, 11'h7ff, 52'd0};
            end else if (aa[62:0] == 0 || bb[62:0] == 0) begin
                result = {sign, 63'd0};
            end else begin
                ma = {1'b0, fa};
                mb = {1'b0, fb};
                if (ea != 0) ma[52] = 1'b1;
                if (eb != 0) mb[52] = 1'b1;
                product = 106'(ma) * 106'(mb);
                p = -1;
                for (int k = 0; k < 106; k++)
                    if (product[k])
                        p = k;
                er = ((ea == 0) ? 1 : ea)
                   + ((eb == 0) ? 1 : eb) - 1023 + p - 104;
                shift = p - 52;
                ef = 11'(er);
                if (er <= 0) begin
                    shift = shift + 1 - er;
                    ef = 11'd0;
                end
                q = (shift >= 106) ? 53'd0 : 53'(product >> shift);
                guard = 1'b0;
                sticky = 1'b0;
                if (shift > 0 && shift <= 106) begin
                    guard = product[shift - 1];
                    for (int k = 0; k < 106; k++)
                        if (k < shift - 1)
                            sticky = sticky | product[k];
                end else if (shift > 106)
                    sticky = |product;
                rounded = {1'b0, q} + (guard && (sticky || q[0]));
                if (ef != 0 && rounded[53]) begin
                    q = rounded[53:1];
                    er = er + 1;
                    ef = 11'(er);
                end else
                    q = rounded[52:0];
                if (er >= 2047)
                    result = {sign, 11'h7ff, 52'd0};
                else if (ef == 0 && q[52])
                    result = {sign, 11'd1, q[51:0]};
                else if (q == 0)
                    result = {sign, 63'd0};
                else
                    result = {sign, ef, q[51:0]};
            end
        end
    endtask

    // v64_norm_shift / v64_unbiased_exp / v64_handle: jmr_value_pkg

    // Mark one valid stable handle and enqueue it exactly once. Future frame
    // and queue roots enter through this same single-word root interface.
    task automatic v64_gc_mark_task(input logic [63:0] word);
        logic [3:0] kind;
        logic [11:0] generation;
        logic [31:0] index;
        begin
            kind = word[47:44];
            generation = word[43:32];
            index = word[31:0];
            if (word[63:48] == 16'h7ff9 &&
                (kind == V64_KIND_OBJECT || kind == V64_KIND_ELEMENT) &&
                index < MAX_OBJ &&
                vobj_alloc[index[12:0]] == 2'd1 &&
                !vobj_mark[index[12:0]]) begin
                // PYTHON marks OBJECT and ELEMENT (canvas / Image). Kind 8
                // used to fall through to the ENV walk and drop canvas slots.
                // Skip gen match: exec/parent dual-copy skew dropped PACMAN
                // `_` / maps after Date() GC (black FB, vdraw=0).
                // FORBIDDEN 2026-08-17: that skip is the overnight cheat, not
                // a PACMAN fix. Restore gen match; one physical heap.
                vobj_mark[index[12:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd7 && index < MAX_OBJ &&
                         vfn_valid[index[12:0]] &&
                         !vfn_mark[index[12:0]]) begin
                // Root handles may carry a stale gen after exec/parent
                // dual-copy poke; a live vfn_valid slot is still a root
                // (PACMAN rAF `fn` fault=4 when gen skew skipped the mark).
                // FORBIDDEN 2026-08-17: skipping fn gen is the same cheat.
                // Fix dual-copy, do not drop generation.
                vfn_mark[index[12:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd6 && index < MAX_ARR &&
                         varr_valid[index[11:0]] &&
                         !varr_mark[index[11:0]]) begin
                varr_mark[index[11:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd9 && index < ENV_DEPTH &&
                         venv_valid[index[9:0]] &&
                         !venv_mark[index[9:0]]) begin
                venv_mark[index[9:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end
        end
    endtask

    // Env LOAD/STORE/LET walk S_HEAP_* (hp_env). Combo v64_env_lookup_task
    // was a 1024×16 mux (Synth 8-4556 on venv_val).

    // ARRAY_GET/SET use Number-to-integer truncation without modulo wrapping.
    task automatic v64_array_index_task(
        input logic [63:0] value,
        output logic valid,
        output logic signed [32:0] index
    );
        logic [52:0] mant;
        logic [32:0] magnitude;
        integer unbiased;
        begin
            valid = value[62:52] != 11'h7ff;
            index = 33'sd0;
            if (valid && value[62:0] != 0 && value[62:52] != 0) begin
                mant = {1'b1, value[51:0]};
                unbiased = value[62:52] - 1023;
                if (unbiased >= 0) begin
                    if (unbiased > 31)
                        magnitude = 33'h1ffffffff;
                    else if (unbiased >= 52)
                        magnitude = 33'(mant << (unbiased - 52));
                    else
                        magnitude = 33'(mant >> (52 - unbiased));
                    index = value[63] ? -$signed(magnitude)
                                      : $signed(magnitude);
                end
            end
        end
    endtask

    // v64_to_uint32 / v64_int32_number / v64_u32_fraction: jmr_value_pkg

    // Round a restoring-divider quotient to binary64, including gradual
    // underflow. div_rem contributes the exact sticky bit beyond quot[0].
    task automatic v64_div_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [106:0] quot,
        input logic [53:0] div_rem,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [53:0] rounded;
        logic guard, sticky;
        integer top, unbiased, shift;
        begin
            top = quot[54] ? 54 : 53;
            unbiased = exponent + top - 54;
            shift = top - 52;
            if (unbiased < -1022)
                shift = shift + (-1022 - unbiased);
            mant = (shift >= 107) ? 53'd0 : 53'(quot >> shift);
            guard = 1'b0;
            sticky = |div_rem;
            if (shift > 0 && shift <= 107) begin
                guard = quot[shift - 1];
                for (int k = 0; k < 107; k++)
                    if (k < shift - 1)
                        sticky = sticky | quot[k];
            end else if (shift > 107) begin
                sticky = sticky | (|quot);
            end
            rounded = {1'b0, mant}
                    + (guard && (sticky || mant[0]));
            if (unbiased >= -1022) begin
                if (rounded[53]) begin
                    mant = rounded[53:1];
                    unbiased = unbiased + 1;
                end else
                    mant = rounded[52:0];
                if (unbiased > 1023)
                    result = {sign, 11'h7ff, 52'd0};
                else
                    result = {sign, 11'(unbiased + 1023), mant[51:0]};
            end else if (rounded[52]) begin
                result = {sign, 11'd1, 52'd0};
            end else if (rounded == 0) begin
                result = {sign, 63'd0};
            end else begin
                result = {sign, 11'd0, rounded[51:0]};
            end
        end
    endtask

    // MOD's integer remainder is exact at the divisor's binary scale.
    task automatic v64_mod_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [52:0] remainder,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [63:0] fraction;
        integer top, unbiased, shift;
        begin
            if (remainder == 0) begin
                result = {sign, 63'd0};
            end else begin
                top = 0;
                for (int k = 0; k < 53; k++)
                    if (remainder[k])
                        top = k;
                unbiased = exponent - 52 + top;
                if (unbiased >= -1022) begin
                    mant = remainder << (52 - top);
                    result = {sign, 11'(unbiased + 1023), mant[51:0]};
                end else begin
                    shift = exponent + 1022;
                    if (shift >= 0)
                        fraction = 64'(remainder) << shift;
                    else
                        fraction = 64'(remainder) >> (-shift);
                    result = {sign, 11'd0, fraction[51:0]};
                end
            end
        end
    endtask
    // NEW: Fn heap object slot0 = entry ip (tag-4 stack value is the obj idx)
    function automatic logic [15:0] fn_entry(input logic [15:0] oid);
        fn_entry = tfn_entry[oid[12:0]];
    endfunction
    function automatic logic [7:0] fn_nparam(input logic [15:0] oid);
        fn_nparam = tfn_nparam[oid[12:0]];
    endfunction
    // NEW: live heap env (FM env dict). Parent oid in slot0.
    task automatic push_fresh_env(input logic [15:0] parent);
        logic [15:0] oid;
        if (env_sp < TAGGED_ENV_DEPTH[5:0]) begin
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
            tenv_parent[oid[12:0]] <= parent;
            vobj_len[oid[12:0]] <= 6'd1;
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
        parent = (obj_n[fo] > 6'd2) ? tfn_parent[fo] : 16'd0;
        cstack_env[csp] <= env_sp;
        push_fresh_env(parent);
        // Fn slot3 is the receiver captured by an arrow or a materialized
        // class method. Regular callbacks deliberately enter with no `this`.
        if (obj_n[fo] > 6'd3 && tfn_has_this[fo]) begin
            this_obj <= tfn_this[fo];
            if (this_ok) begin
                vars[var_this] <= {16'd0, tfn_this[fo]};
                var_tag[var_this] <= tfn_this_tag[fo];
            end
        end else begin
            this_obj <= 16'hFFFF;
            if (this_ok) begin
                vars[var_this] <= 32'd0;
                var_tag[var_this] <= 3'd5;
            end
        end
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
            // Synth 8-3380: trip count must be constant (j is runtime).
            for (i = 0; i < 4; i++)
                if (i >= j) kd_slot[i] <= 16'hFFFF;
        end else begin
            j = 0;
            for (i = 0; i < 4; i++) begin
                if (i < ku_n && ku_slot[i] != fn) begin
                    ku_slot[j] <= ku_slot[i];
                    j = j + 1;
                end
            end
            ku_n <= 3'(j);
            for (i = 0; i < 4; i++)
                if (i >= j) ku_slot[i] <= 16'hFFFF;
        end
    endtask
    // NEW: recycle this call's env unless MAKE_FN captured it (live closure).
    // Jumping env_sp to `saved` used to free only the TOP frame, so a nested
    // forEach/finder return leaked middle oids AND could push the same oid
    // twice (PACMAN ENVSTAT free=2296,2295,2296). Nursery oids on the free
    // list sit ABOVE n_obj_keep — the bump allocator then overwrites that
    // env as a regular object in the same frame, so forEach LOAD f misses
    // and item.times stays 0 (stale vars[]).
    // Walk one live index per clock in S_REL_ENV (TAGGED_ENV_DEPTH=32).
    // Nested for (i,j) over ENV_DEPTH is 1024×1024 unroll — Verilator yes,
    // Vivado no (same class as combo heap).
    task automatic arm_release_env(input logic [5:0] saved, input st_t nxt);
        rel_saved <= saved;
        rel_lim <= env_sp;
        rel_i <= saved;
        rel_nn <= env_free_n;
        rel_ret <= nxt;
        state <= S_REL_ENV;
    endtask
    // Combo TOS-window mux. Vivado Synth 8-660: function automatic vst_at
    // is not resolved from the giant unique case (Verilator is). Deep stack
    // copies already go through S_V64_BIND / S_HEAP_FILL (vst_rdata).
    always_comb begin
        vst_peek[0]  = vst_win[0];
        vst_peek[1]  = vst_win[1];
        vst_peek[2]  = vst_win[2];
        vst_peek[3]  = vst_win[3];
        vst_peek[4]  = vst_win[4];
        vst_peek[5]  = vst_win[5];
        vst_peek[6]  = vst_win[6];
        vst_peek[7]  = vst_win[7];
        vst_peek[8]  = vst_win[8];
        vst_peek[9]  = vst_win[9];
        vst_peek[10] = vst_win[10];
        vst_peek[11] = vst_win[11];
        vst_peek[12] = vst_win[12];
        vst_peek[13] = vst_win[13];
        vst_peek[14] = vst_win[14];
        vst_peek[15] = vst_win[15];
    end
    // Relative slot from TOS (0=TOS). Out-of-window → slot 0, not BRAM.
    // No extra parens around vst_peek[i] — `(expr)[62:52]` is illegal SV
    // (Synth 8-660 site was Math.abs `vst_at(base)[62:52]`).
    `define VST_REL(addr) (((((vsp)>(addr)) && (((vsp)-(addr)-12'd1)<12'd16))) ? 4'((vsp)-(addr)-12'd1) : 4'd0)
    `define VST_AT(addr) vst_peek[`VST_REL(addr)]
    task automatic vst_wr(input logic [11:0] addr, input logic [63:0] data);
        vst_we <= 1'b1;
        vst_waddr <= addr;
        vst_wdata <= data;
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
    // NEW: registering a frame callback IS the end of boot. The keep watermark
    // only armed after ARR_KEEP_DELAY frames, so a loop registered from
    // top-level (PACMAN init() -> start() -> requestAnimationFrame(fn)) left its
    // Fn object in the nursery; the first rewind recycled that oid and the
    // dispatcher then ran whatever function had taken the slot over — it
    // returned without re-arming, so raf stuck at 0 and the game froze on its
    // first drawn frame (cbip landed inside the Game factory, not the loop).
    // A registered callback is live by definition, and everything allocated up
    // to it is the program's boot state, so arm both watermarks here. Only on
    // the FIRST registration: re-arming every frame would walk the bump pointer
    // up and saturate the heap.
    task automatic commit_boot_keep();
        obj_keep_ok <= 1'b1;
        arr_keep_ok <= 1'b1;
        if (n_obj > n_obj_keep) n_obj_keep <= n_obj;
        if (n_arr > n_arr_keep) n_arr_keep <= n_arr;
    endtask
    // NEW: a value stored into old space also owns whatever it points at, and a
    // constructor allocates those children AFTER the instance itself, so
    // stored_oid+1 kept the parent and rewound its contents (INVADERS:
    // grids.push(new Grid()) kept the Grid and dropped this.invaders plus every
    // Invader one frame later — the alien formation vanished and the array
    // watermark was never committed at all). Allocation is a bump pointer, so
    // "everything allocated so far" is exactly that subgraph: raise BOTH
    // watermarks to the current pointers.
    // Per-frame churn does not reach here — object/array slot overwrites copy
    // in place below and keep their old oid, so the bump cannot creep
    // (test_rtl_coord_overwrite_does_not_heapovf).
    task automatic commit_deep_keep(input logic [2:0] tag);
        if (tag == 3'd1 || tag == 3'd4 || tag == 3'd2) begin
            if (obj_keep_ok && n_obj > n_obj_keep) n_obj_keep <= n_obj;
            if (arr_keep_ok && n_arr > n_arr_keep) n_arr_keep <= n_arr;
        end
    endtask
    task automatic bump_csp();
        if (csp >= 7'(CSTK - 1))
            dbg_call_ovf <= dbg_call_ovf + 16'd1;
        else
            csp <= csp + 7'd1;
    endtask
    task automatic boundary_sp(input logic [10:0] next_sp);
        // One callback return value is permitted; anything more is a real
        // stack-balance defect and must remain visible as a machine fault.
        if (sp > 11'd1) dbg_stack_ovf <= dbg_stack_ovf + 16'd1;
        sp <= next_sp;
    endtask
    task automatic gc_mark_obj(input logic [15:0] oid);
        if (oid < n_obj && oid < 16'(MAX_OBJ) && !gc_obj_mark[oid[12:0]]) begin
            gc_obj_mark[oid[12:0]] <= 1'b1;
            gc_queue[gc_qw] <= {1'b0, oid[12:0]};
            gc_qw <= gc_qw + 14'd1;
            if (oid + 16'd1 > gc_obj_high) gc_obj_high <= oid + 16'd1;
        end
    endtask
    task automatic gc_mark_value(input logic [2:0] tag, input logic [31:0] value);
        logic [15:0] oid;
        oid = value[15:0];
        if (tag == 3'd2) begin
            if (oid < n_arr && oid < 16'(MAX_ARR) && !gc_arr_mark[oid[11:0]]) begin
                gc_arr_mark[oid[11:0]] <= 1'b1;
                gc_queue[gc_qw] <= {1'b1, 1'b0, oid[11:0]};
                gc_qw <= gc_qw + 14'd1;
                if (oid + 16'd1 > gc_arr_high) gc_arr_high <= oid + 16'd1;
            end
        end else if (tag == 3'd1 || tag == 3'd4 || tag == 3'd6) begin
            gc_mark_obj(oid);
        end else if (tag == 3'd3 && oid < n_obj &&
                     obj_cls[oid[12:0]] == CLS_DYNSTR) begin
            gc_mark_obj(oid);
        end
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
    // IEEE binary64 → Q16.16 (path/arc args). Compare the exponent to
    // 1023/1059 directly — do not stash (exp-1023) in a signed local.
    function automatic logic signed [31:0] v64_to_fx(input logic [63:0] v);
        logic [10:0] exponent;
        logic [52:0] mant;
        logic [31:0] mag;
        begin
            exponent = v[62:52];
            mant = {1'b1, v[51:0]};
            mag = 32'd0;
            if (!v64_is_number(v) || exponent == 11'h7ff)
                mag = 32'd0;
            else if (exponent >= 11'd1059 && exponent < 11'd1091)
                mag = 32'(mant << (exponent - 11'd1059));
            else if (exponent >= 11'd1007 && exponent < 11'd1059)
                mag = 32'(mant >> (11'd1059 - exponent));
            v64_to_fx = v[63] ? -$signed(mag) : $signed(mag);
        end
    endfunction
    // Q16.16 → IEEE. Unbiased exp is top-16; IEEE exp = top+1007
    // (1023-16). Do not stash (top-16) in a signed local.
    function automatic logic [63:0] v64_from_fx(input logic signed [31:0] fx);
        logic sign;
        logic [31:0] magnitude;
        logic [52:0] mant;
        integer top;
        begin
            sign = fx[31];
            magnitude = sign ? (~fx + 32'd1) : fx;
            if (magnitude == 0)
                v64_from_fx = 64'd0;
            else begin
                top = 0;
                for (int k = 0; k < 32; k++)
                    if (magnitude[k])
                        top = k;
                mant = 53'(magnitude) << (52 - top);
                v64_from_fx = {sign, 11'(top + 1007), mant[51:0]};
            end
        end
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

    task automatic e64_poke(input logic [5:0] sel, input logic [15:0] addr,
                            input logic [63:0] data);
        e64_p_we <= 1'b1;
        e64_p_sel <= sel;
        e64_p_addr <= addr;
        // Object alloc: copy parent gen into [43:32] so exec GET_PROP
        // matches the handle (dual-copy). Call sites keep packing len/builtin.
        // FORBIDDEN 2026-08-17: dual-copy poke is not the legal shape.
        // One physical SRAM; do not paper over gen skew here.
        if (sel == 6'd44)
            e64_p_data <= {data[63:44], vobj_gen[addr[12:0]], data[31:0]};
        else
            e64_p_data <= data;
    endtask
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

    // Object/array slot SRAM: 1 write + 1 registered read (VRAM Port A).
    always_ff @(posedge clk) begin
        if (vobj_we) begin
            vobj_slot[vobj_waddr] <= vobj_wdata;
            vobj_tmem[vobj_waddr] <= (hp_cmd == HP_OSETI)
                ? hp_qt[hp_qi[1:0]] : hp_tag;
        end
        vobj_rdata <= vobj_slot[vobj_raddr];
        vobj_trdata <= vobj_tmem[vobj_raddr];
        if (varr_we) begin
            varr_slot[varr_waddr] <= varr_wdata;
            varr_tmem[varr_waddr] <= (hp_from_stack && !hp_v64)
                ? stack_tag[hp_vbase[10:0] + {4'd0, hp_aslot}]
                : hp_tag;
        end
        varr_rdata <= varr_slot[varr_raddr];
        varr_trdata <= varr_tmem[varr_raddr];
        if (venv_we)
            venv_slot[venv_waddr] <= venv_wdata;
        venv_rdata <= venv_slot[venv_raddr];
    end

    // Value64 operand stack: 1 write + 1 registered read (same as vobj_slot).
    always_ff @(posedge clk) begin
        if (vst_we)
            vstack[vst_waddr] <= vst_wdata;
        vst_rdata <= vstack[vst_raddr];
    end

    always_comb begin
        vobj_we = (state == S_HEAP_WR) && !hp_env;
        vobj_waddr = (hp_cmd == HP_OSETI)
            ? VOBJ_AW'({hp_oid, hp_slot + {2'd0, hp_qi[2:0]}})
            : VOBJ_AW'({hp_oid, hp_slot});
        vobj_wdata = (hp_cmd == HP_OSETI)
            ? {hp_qk[hp_qi[1:0]], hp_qv[hp_qi[1:0]]}
            : {hp_key, hp_wval};
        vobj_raddr = VOBJ_AW'({hp_oid, hp_slot});
        varr_we = (state == S_HEAP_AWR) ||
            (state == S_HEAP_FILL &&
             !(hp_from_stack && hp_v64 && hp_phase != 3'd1));
        varr_waddr = hp_prom_wr
            ? VARR_AW'(VARR_SHORT_WORDS + {1'b0, hp_prom_phys, hp_aslot})
            : varr_slot_addr(hp_aid, hp_aslot);
        varr_wdata = hp_from_stack
            ? (hp_v64
                ? vst_rdata
                : {32'd0, stack[hp_vbase[10:0] + {4'd0, hp_aslot}]})
            : hp_wval;
        varr_raddr = varr_slot_addr(hp_aid, hp_aslot);
        venv_we = (state == S_HEAP_WR) && hp_env;
        venv_waddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        venv_wdata = {7'd0, hp_key[8:0], hp_wval};
        venv_raddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        unique case (state)
            S_ENV_LOAD:
                vobj_raddr = VOBJ_AW'({env_walk[12:0], hp_slot});
            S_V64_GC_OBJ:
                vobj_raddr = VOBJ_AW'({vgc_cur[12:0], vgc_slot_i[4:0]});
            S_ARR_DCOPY:
                varr_raddr = (hp_phase == 3'd0)
                    ? varr_slot_addr(dc_src, dc_i[6:0])
                    : varr_slot_addr(dc_dst, dc_i[6:0]);
            S_GC_OBJ:
                vobj_raddr = VOBJ_AW'({gc_cur[12:0], gc_slot[4:0]});
            S_GC_ARR:
                varr_raddr = varr_slot_addr(gc_cur[11:0], gc_slot[6:0]);
            S_V64_GC_ARR:
                varr_raddr = varr_slot_addr(vgc_cur[11:0], vgc_slot_i[6:0]);
            S_V64_GC_ENV:
                if (vgc_slot_i != 0)
                    venv_raddr = VENV_AW'(
                        {vgc_cur[9:0], vgc_slot_i[3:0] - 4'd1}
                    );
            S_V64_FOREACH:
                varr_raddr = varr_slot_addr(vfe_arr[11:0], vfe_i[6:0]);
            S_FOREACH:
                varr_raddr = varr_slot_addr(cstack_fe_arr[csp - 7'd1][11:0],
                    cstack_fe_i[csp - 7'd1][6:0]);
            S_JOIN, S_IDXOF:
                varr_raddr = varr_slot_addr(jn_arr, jn_i[6:0]);
            S_V64_JSON:
                if (js_sp != 0) begin
                    varr_raddr = varr_slot_addr(
                        vjs_val[js_sp - 6'd1][11:0], js_i[js_sp - 6'd1][6:0]
                    );
                    vobj_raddr = VOBJ_AW'(
                        {vjs_val[js_sp - 6'd1][12:0], js_i[js_sp - 6'd1][4:0]}
                    );
                end
            S_JSON:
                if (js_sp != 0) begin
                    varr_raddr = varr_slot_addr(
                        js_val[js_sp - 6'd1][11:0], js_i[js_sp - 6'd1][6:0]
                    );
                    vobj_raddr = VOBJ_AW'(
                        {js_val[js_sp - 6'd1][12:0], js_i[js_sp - 6'd1][4:0]}
                    );
                end
            default: ;
        endcase
        if ((state == S_HEAP_WAIT || state == S_HEAP_CMP) &&
            hp_cmd == HP_ASSIGN && hp_phase == 3'd0)
            vobj_raddr = VOBJ_AW'({hp_si, hp_ss});
        if (state == S_ARR_DCOPY && hp_phase != 3'd0)
            varr_raddr = varr_slot_addr(dc_dst, dc_i[6:0]);
    end

    always_comb begin
        vst_raddr = (vsp >= 12'd16) ? (vsp - 12'd16) : 12'd0;
        if (state == S_HEAP_FILL && hp_from_stack && hp_v64)
            vst_raddr = hp_vbase + {5'd0, hp_aslot};
        else if (state == S_V64_BIND)
            vst_raddr = bind_src + {4'd0, bind_k};
        else if (state == S_V64_MINMAX)
            vst_raddr = minmax_base + {4'd0, minmax_k};
        else if (state == S_V64_WIN_FILL)
            vst_raddr = vsp - {8'd0, vst_refill_i} - 12'd1;
        else if (state == S_V64_GC_ROOT && vgc_root_phase == 3'd1)
            vst_raddr = vgc_root_i;
    end

    // KEYBITS poke is sequential-heap (no combo slot mux). Tagged path
    // arms HP_SETPROP from S_WAIT_FRAME; this task is a no-op stub.
    task automatic poke_pressed(input logic [15:0] child_ni, input logic down);
        begin
            // Slot walk lives in S_HEAP_*; do not mux obj_key here.
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

    // Hierarchical jmr_js_vm_exec32: keep_hierarchy so Vivado does not flatten
    // the opcode mux back into the parent always_ff.
    logic signed [31:0] e32_alu_a_n;
    logic signed [31:0] e32_alu_b_n;
    logic e32_alu_fx_n;
    logic [2:0] e32_alu_op_n;
    logic [15:0] e32_blit_sh_n;
    logic [7:0] e32_blit_si_n;
    logic [15:0] e32_blit_sw_n;
    logic [15:0] e32_blit_sx_n;
    logic [15:0] e32_blit_sy_n;
    logic [2:0] e32_cc_at_n;
    logic signed [31:0] e32_cc_av_n;
    logic e32_cc_bok_n;
    logic [2:0] e32_cc_bt_n;
    logic signed [31:0] e32_cc_bv_n;
    logic [3:0] e32_cc_d_n;
    logic [15:0] e32_cc_h_n;
    logic [7:0] e32_cc_len_n;
    logic e32_cc_second_n;
    logic [1:0] e32_cc_st_n;
    logic e32_click_fired_n;
    logic [15:0] e32_click_fn_n;
    logic [18:0] e32_clr_idx_n;
    logic [14:0] e32_code_raddr_n;
    logic [7:0] e32_color_n;
    logic [6:0] e32_csp_n;
    logic [1:0] e32_ctx_align_n;
    logic [7:0] e32_ctx_font_px_n;
    logic e32_ctx_smooth_n;
    logic signed [31:0] e32_ctx_sx_n;
    logic signed [31:0] e32_ctx_sy_n;
    logic signed [31:0] e32_ctx_tx_n;
    logic signed [31:0] e32_ctx_ty_n;
    logic [15:0] e32_dbg_call_ovf_n;
    logic [15:0] e32_dbg_cb_ip_n;
    logic [15:0] e32_dbg_di_hit_n;
    logic [15:0] e32_dbg_di_miss_n;
    logic [15:0] e32_dbg_div_n_n;
    logic [15:0] e32_dbg_find_hit_n;
    logic [15:0] e32_dbg_heap_ovf_n;
    logic [15:0] e32_dbg_json_ovf_n;
    logic [15:0] e32_dbg_path_ovf_n;
    logic [15:0] e32_dbg_splice_n_n;
    logic [15:0] e32_dbg_stack_ovf_n;
    logic [15:0] e32_dbg_tmr_sched_n;
    logic [15:0] e32_dbg_to_ovf_n;
    logic e32_did_swap_n;
    logic [5:0] e32_div_cnt_n;
    logic e32_div_int_in_n;
    logic e32_div_neg_n;
    logic [31:0] e32_div_rem_n;
    logic [31:0] e32_div_ub_n;
    logic [47:0] e32_div_uq_n;
    logic [5:0] e32_env_free_n_n;
    logic e32_env_is_store_n;
    logic [8:0] e32_env_ld_slot_n;
    logic [5:0] e32_env_sp_n;
    logic [15:0] e32_env_walk_n;
    logic [18:0] e32_fb_dump_addr_n;
    logic e32_fb_dump_sel_n;
    logic e32_fb_swap_n;
    logic [7:0] e32_fill_style_i_n;
    logic [7:0] e32_fp_left_n;
    logic [7:0] e32_fpx_acc_n;
    logic e32_frame_fire_n;
    logic [11:0] e32_hp_aid_n;
    logic [7:0] e32_hp_alen_n;
    logic [6:0] e32_hp_aslot_n;
    logic [3:0] e32_hp_cmd_n;
    logic e32_hp_from_stack_n;
    logic e32_hp_hit_n;
    logic [15:0] e32_hp_key_n;
    logic [5:0] e32_hp_len_n;
    logic [7:0] e32_hp_lim_n;
    logic e32_hp_make_arr_n;
    logic [3:0] e32_hp_nat_n;
    logic [12:0] e32_hp_oid_n;
    logic [2:0] e32_hp_phase_n;
    logic [63:0] e32_hp_proto_n;
    logic [2:0] e32_hp_qi_n;
    logic [2:0] e32_hp_qn_n;
    logic [6:0] e32_hp_ret_n;
    logic [63:0] e32_hp_rval_n;
    logic [12:0] e32_hp_si_n;
    logic [4:0] e32_hp_slot_n;
    logic [4:0] e32_hp_ss_n;
    logic [2:0] e32_hp_tag_n;
    logic [5:0] e32_hp_tn_n;
    logic e32_hp_v64_n;
    logic [11:0] e32_hp_vbase_n;
    logic [63:0] e32_hp_wval_n;
    logic [7:0] e32_idx_needle_n;
    logic [2:0] e32_idx_t_n;
    logic signed [31:0] e32_idx_v_n;
    logic e32_imgd_armed_n;
    logic [9:0] e32_imgd_h_n;
    logic [18:0] e32_imgd_i_n;
    logic [18:0] e32_imgd_n_n;
    logic [10:0] e32_imgd_res_n;
    logic [9:0] e32_imgd_w_n;
    logic [9:0] e32_imgd_x_n;
    logic [9:0] e32_imgd_x0_n;
    logic [9:0] e32_imgd_y_n;
    logic [9:0] e32_imgd_y0_n;
    logic [15:0] e32_ip_n;
    logic [11:0] e32_jn_arr_n;
    logic [15:0] e32_jn_h_n;
    logic [15:0] e32_jn_i_n;
    logic [10:0] e32_jn_res_n;
    logic [5:0] e32_js_sp_n;
    logic [13:0] e32_json_dst_n;
    logic [2:0] e32_json_pph_n;
    logic [10:0] e32_json_res_n;
    logic [13:0] e32_json_rp_n;
    logic [13:0] e32_json_src_n;
    logic [13:0] e32_json_srclen_n;
    logic [13:0] e32_json_wp_n;
    logic [2:0] e32_kd_n_n;
    logic [15:0] e32_kev_fn_n;
    logic e32_kev_is_down_n;
    logic [1:0] e32_kev_li_n;
    logic [15:0] e32_kev_obj_n;
    logic [15:0] e32_kev_ret_ip_n;
    logic [15:0] e32_keys_a_oid_n;
    logic [15:0] e32_keys_d_oid_n;
    logic [15:0] e32_keys_sp_oid_n;
    logic [2:0] e32_ku_n_n;
    logic [31:0] e32_lfsr_n;
    logic e32_looping_n;
    logic [15:0] e32_metrics_oid_n;
    logic signed [31:0] e32_mul_a_n;
    logic signed [31:0] e32_mul_b_n;
    logic e32_mul_fx_a_n;
    logic e32_mul_fx_b_n;
    logic [15:0] e32_n_arr_n;
    logic [15:0] e32_n_arr_keep_n;
    logic [6:0] e32_n_fn_proto_n;
    logic [15:0] e32_n_obj_n;
    logic [15:0] e32_n_obj_keep_n;
    logic e32_namcpy_armed_n;
    logic e32_namcpy_repl_n;
    logic [15:0] e32_name_rdaddr_n;
    logic [7:0] e32_nat_argc_n;
    logic [7:0] e32_nat_id_n;
    logic e32_path_active_n;
    logic [1:0] e32_path_kind_n;
    logic e32_path_stroke_n;
    logic [4:0] e32_pc_n_n;
    logic [4:0] e32_pi_n;
    logic e32_present_pend_n;
    logic [3:0] e32_raf_n_n;
    logic [5:0] e32_rel_i_n;
    logic [5:0] e32_rel_lim_n;
    logic [5:0] e32_rel_nn_n;
    logic [6:0] e32_rel_ret_n;
    logic [5:0] e32_rel_saved_n;
    logic e32_repl_did_n;
    logic e32_repl_g_n;
    logic [7:0] e32_repl_nlen_n;
    logic [7:0] e32_repl_pat0_n;
    logic [7:0] e32_repl_pat1_n;
    logic [7:0] e32_repl_rch_n;
    logic [9:0] e32_rh_n;
    logic e32_running_n;
    logic [9:0] e32_rw_n;
    logic [9:0] e32_rx_n;
    logic [9:0] e32_ry_n;
    logic signed [31:0] e32_saved_sx_n;
    logic signed [31:0] e32_saved_sy_n;
    logic signed [31:0] e32_saved_tx_n;
    logic signed [31:0] e32_saved_ty_n;
    logic [10:0] e32_sp_n;
    logic [4:0] e32_sq_i_n;
    logic [47:0] e32_sq_rad_n;
    logic [25:0] e32_sq_rem_n;
    logic [23:0] e32_sq_root_n;
    logic [6:0] e32_state_n;
    logic signed [31:0] e32_str_pf_ci_n;
    logic [15:0] e32_str_pf_id_n;
    logic e32_str_pf_ok_n;
    logic [10:0] e32_str_res_n;
    logic [15:0] e32_this_obj_n;
    logic [6:0] e32_to_n_n;
    logic [15:0] e32_to_seq_n;
    logic [6:0] e32_txt_bn_n;
    logic [3:0] e32_txt_ph_n;
    logic signed [15:0] e32_txt_px_n;
    logic signed [15:0] e32_txt_py_n;
    logic [15:0] e32_txt_rp_n;
    logic [31:0] e32_txt_val_n;
    logic [2:0] e32_txt_vt_n;
    logic [11:0] e32_vcall_argc_n;
    logic [63:0] e32_vcall_this_n;
    logic [9:0] e32_x_n;
    logic [1:0] e32_xf_dst_n;
    logic signed [31:0] e32_xf_h_n;
    logic signed [31:0] e32_xf_w_n;
    logic signed [31:0] e32_xf_x_n;
    logic signed [31:0] e32_xf_y_n;
    logic [9:0] e32_y_n;
    logic [15:0] e32_cstack_ctorobj_n [0:CSTK-1];
    logic [5:0] e32_cstack_env_n [0:CSTK-1];
    logic [15:0] e32_cstack_fe_arr_n [0:CSTK-1];
    logic [15:0] e32_cstack_fe_fn_n [0:CSTK-1];
    logic [7:0] e32_cstack_fe_i_n [0:CSTK-1];
    logic [15:0] e32_cstack_ip_n [0:CSTK-1];
    logic e32_cstack_isctor_n [0:CSTK-1];
    logic e32_cstack_isfe_n [0:CSTK-1];
    logic [15:0] e32_cstack_map_arr_n [0:CSTK-1];
    logic [15:0] e32_cstack_this_n [0:CSTK-1];
    logic [15:0] e32_fn_proto_ip_n [0:MAX_FN_PROTO-1];
    logic [15:0] e32_fn_proto_oid_n [0:MAX_FN_PROTO-1];
    logic [15:0] e32_hp_qk_n [0:3];
    logic [2:0] e32_hp_qt_n [0:3];
    logic [63:0] e32_hp_qv_n [0:3];
    logic [7:0] e32_js_i_n [0:JSON_STK-1];
    logic [2:0] e32_js_ph_n [0:JSON_STK-1];
    logic [2:0] e32_js_tag_n [0:JSON_STK-1];
    logic [31:0] e32_js_val_n [0:JSON_STK-1];
    logic [15:0] e32_kd_slot_n [0:3];
    logic [15:0] e32_ku_slot_n [0:3];
    logic signed [31:0] e32_pc_a1_n [0:PATH_MAX-1];
    logic signed [31:0] e32_pc_a2_n [0:PATH_MAX-1];
    logic signed [31:0] e32_pc_a3_n [0:PATH_MAX-1];
    logic signed [31:0] e32_pc_a4_n [0:PATH_MAX-1];
    logic signed [31:0] e32_pc_a5_n [0:PATH_MAX-1];
    logic e32_pc_ccw_n [0:PATH_MAX-1];
    logic [1:0] e32_pc_op_n [0:PATH_MAX-1];
    logic [15:0] e32_raf_fn_n [0:7];
    logic [11:0] e32_to_delay_n [0:TIMER_DEPTH-1];
    logic [15:0] e32_to_fn_n [0:TIMER_DEPTH-1];
    logic [15:0] e32_to_id_n [0:TIMER_DEPTH-1];
    logic [11:0] e32_to_period_n [0:TIMER_DEPTH-1];
    logic e32_arr_len_we;
    logic [11:0] e32_arr_len_waddr;
    logic [7:0] e32_arr_len_wdata;
    logic e32_env_cap_we;
    logic [11:0] e32_env_cap_waddr;
    logic [31:0] e32_env_cap_wdata;
    logic e32_env_oid_we;
    logic [11:0] e32_env_oid_waddr;
    logic [15:0] e32_env_oid_wdata;
    logic e32_json_mem_we;
    logic [12:0] e32_json_mem_waddr;
    logic [7:0] e32_json_mem_wdata;
    logic e32_obj_cls_we;
    logic [11:0] e32_obj_cls_waddr;
    logic [15:0] e32_obj_cls_wdata;
    logic e32_obj_n_we;
    logic [11:0] e32_obj_n_waddr;
    logic [5:0] e32_obj_n_wdata;
    logic e32_stack_we;
    logic [11:0] e32_stack_waddr;
    logic signed [31:0] e32_stack_wdata;
    logic e32_stack_tag_we;
    logic [11:0] e32_stack_tag_waddr;
    logic [2:0] e32_stack_tag_wdata;
    logic e32_tenv_parent_we;
    logic [11:0] e32_tenv_parent_waddr;
    logic [15:0] e32_tenv_parent_wdata;
    logic e32_tfn_entry_we;
    logic [11:0] e32_tfn_entry_waddr;
    logic [15:0] e32_tfn_entry_wdata;
    logic e32_tfn_has_this_we;
    logic [11:0] e32_tfn_has_this_waddr;
    logic [31:0] e32_tfn_has_this_wdata;
    logic e32_tfn_nparam_we;
    logic [11:0] e32_tfn_nparam_waddr;
    logic [7:0] e32_tfn_nparam_wdata;
    logic e32_tfn_parent_we;
    logic [11:0] e32_tfn_parent_waddr;
    logic [15:0] e32_tfn_parent_wdata;
    logic e32_tfn_this_we;
    logic [11:0] e32_tfn_this_waddr;
    logic [15:0] e32_tfn_this_wdata;
    logic e32_tfn_this_tag_we;
    logic [11:0] e32_tfn_this_tag_waddr;
    logic [2:0] e32_tfn_this_tag_wdata;
    logic e32_var_init_we;
    logic [11:0] e32_var_init_waddr;
    logic [31:0] e32_var_init_wdata;
    logic e32_var_tag_we;
    logic [11:0] e32_var_tag_waddr;
    logic [2:0] e32_var_tag_wdata;
    logic e32_vars_we;
    logic [11:0] e32_vars_waddr;
    logic signed [31:0] e32_vars_wdata;
    logic e32_vobj_len_we;
    logic [11:0] e32_vobj_len_waddr;
    logic [5:0] e32_vobj_len_wdata;
    // Exec-owned large memories: scalar poke/clr (not unpacked array ports).
    logic e32_p_clr, e32_p_we;
    logic [5:0] e32_p_sel;
    logic [15:0] e32_p_addr, e32_p_addr2;
    logic [63:0] e32_p_data;
    logic e64_p_clr, e64_p_we;
    logic [5:0] e64_p_sel;
    logic [15:0] e64_p_addr, e64_p_addr2;
    logic [63:0] e64_p_data, e64_p_data2, e64_p_data3, e64_p_data4, e64_p_data5;
    logic e64_p_frame_we;
    logic [6:0] e64_p_frame_idx;
    logic [15:0] e64_p_frame_rip;
    logic [11:0] e64_p_frame_bsp;
    logic e64_p_frame_esc;
    logic [63:0] e64_p_frame_this, e64_p_frame_env, e64_p_frame_fnv, e64_p_frame_ctor;
    (* keep_hierarchy = "yes" *)
    jmr_js_vm_exec32 u_exec32 (
        .clk(clk),
        .enable(((state == S_EXEC) || (state == S_NAT))),
        .p_clr(e32_p_clr),
        .p_we(e32_p_we),
        .p_sel(e32_p_sel),
        .p_addr(e32_p_addr),
        .p_addr2(e32_p_addr2),
        .p_data(e32_p_data),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_fx(alu_fx),
        .alu_op(alu_op),
        .arr_keep_ok(arr_keep_ok),
        .blit_sh(blit_sh),
        .blit_si(blit_si),
        .blit_sw(blit_sw),
        .blit_sx(blit_sx),
        .blit_sy(blit_sy),
        .cc_at(cc_at),
        .cc_av(cc_av),
        .cc_bok(cc_bok),
        .cc_bt(cc_bt),
        .cc_bv(cc_bv),
        .cc_d(cc_d),
        .cc_h(cc_h),
        .cc_len(cc_len),
        .cc_second(cc_second),
        .cc_st(cc_st),
        .click_fired(click_fired),
        .click_fn(click_fn),
        .clr_idx(clr_idx),
        .code_raddr(code_raddr),
        .code_rdata(code_rdata),
        .color(color),
        .csp(csp),
        .cstack_ctorobj(cstack_ctorobj),
        .cstack_env(cstack_env),
        .cstack_fe_arr(cstack_fe_arr),
        .cstack_fe_fn(cstack_fe_fn),
        .cstack_fe_i(cstack_fe_i),
        .cstack_ip(cstack_ip),
        .cstack_isctor(cstack_isctor),
        .cstack_isfe(cstack_isfe),
        .cstack_map_arr(cstack_map_arr),
        .cstack_this(cstack_this),
        .ctx_align(ctx_align),
        .ctx_font_px(ctx_font_px),
        .ctx_smooth(ctx_smooth),
        .ctx_sx(ctx_sx),
        .ctx_sy(ctx_sy),
        .ctx_tx(ctx_tx),
        .ctx_ty(ctx_ty),
        .dbg_call_ovf(dbg_call_ovf),
        .dbg_cb_ip(dbg_cb_ip),
        .dbg_di_hit(dbg_di_hit),
        .dbg_di_miss(dbg_di_miss),
        .dbg_div_n(dbg_div_n),
        .dbg_find_hit(dbg_find_hit),
        .dbg_heap_ovf(dbg_heap_ovf),
        .dbg_json_ovf(dbg_json_ovf),
        .dbg_path_ovf(dbg_path_ovf),
        .dbg_splice_n(dbg_splice_n),
        .dbg_stack_ovf(dbg_stack_ovf),
        .dbg_tmr_sched(dbg_tmr_sched),
        .dbg_to_ovf(dbg_to_ovf),
        .did_swap(did_swap),
        .div_cnt(div_cnt),
        .div_int_in(div_int_in),
        .div_neg(div_neg),
        .div_rem(div_rem),
        .div_ub(div_ub),
        .div_uq(div_uq),
        .env_cap(env_cap),
        .env_free(env_free),
        .env_free_n(env_free_n),
        .env_is_store(env_is_store),
        .env_ld_slot(env_ld_slot),
        .env_oid(env_oid),
        .env_sp(env_sp),
        .env_walk(env_walk),
        .fb_dump_addr(fb_dump_addr),
        .fb_dump_sel(fb_dump_sel),
        .fb_swap(fb_swap),
        .fill_style_i(fill_style_i),
        .fn_proto_ip(fn_proto_ip),
        .fn_proto_oid(fn_proto_oid),
        .fp_left(fp_left),
        .fpx_acc(fpx_acc),
        .frame_fire(frame_fire),
        .frame_tick(frame_tick),
        .hp_aid(hp_aid),
        .hp_alen(hp_alen),
        .hp_aslot(hp_aslot),
        .hp_cmd(hp_cmd),
        .hp_from_stack(hp_from_stack),
        .hp_hit(hp_hit),
        .hp_key(hp_key),
        .hp_len(hp_len),
        .hp_lim(hp_lim),
        .hp_make_arr(hp_make_arr),
        .hp_nat(hp_nat),
        .hp_oid(hp_oid),
        .hp_phase(hp_phase),
        .hp_proto(hp_proto),
        .hp_qi(hp_qi),
        .hp_qk(hp_qk),
        .hp_qn(hp_qn),
        .hp_qt(hp_qt),
        .hp_qv(hp_qv),
        .hp_ret(hp_ret),
        .hp_rval(hp_rval),
        .hp_si(hp_si),
        .hp_slot(hp_slot),
        .hp_ss(hp_ss),
        .hp_tag(hp_tag),
        .hp_tn(hp_tn),
        .hp_v64(hp_v64),
        .hp_vbase(hp_vbase),
        .hp_wval(hp_wval),
        .id_a(id_a),
        .id_ael(id_ael),
        .id_arc(id_arc),
        .id_assign(id_assign),
        .id_beginpath(id_beginpath),
        .id_bind(id_bind),
        .id_black(id_black),
        .id_center(id_center),
        .id_clearrect(id_clearrect),
        .id_click(id_click),
        .id_closepath(id_closepath),
        .id_customev(id_customev),
        .id_cyan(id_cyan),
        .id_d(id_d),
        .id_disp(id_disp),
        .id_domevent(id_domevent),
        .id_drawimage(id_drawimage),
        .id_fill(id_fill),
        .id_fillrect(id_fillrect),
        .id_fillstyle(id_fillstyle),
        .id_filltext(id_filltext),
        .id_filter(id_filter),
        .id_find(id_find),
        .id_findindex(id_findindex),
        .id_font(id_font),
        .id_foreach(id_foreach),
        .id_getctx(id_getctx),
        .id_getimgdata(id_getimgdata),
        .id_gettime(id_gettime),
        .id_gold(id_gold),
        .id_height(id_height),
        .id_hex_000(id_hex_000),
        .id_hex_09f(id_hex_09f),
        .id_hex_2ec(id_hex_2ec),
        .id_hex_3f6(id_hex_3f6),
        .id_hex_aaa(id_hex_aaa),
        .id_hex_f00(id_hex_f00),
        .id_hex_f5a(id_hex_f5a),
        .id_hex_f5f5(id_hex_f5f5),
        .id_hex_fc0(id_hex_fc0),
        .id_hex_ffe6(id_hex_ffe6),
        .id_hex_fff(id_hex_fff),
        .id_imgsmooth(id_imgsmooth),
        .id_indexof(id_indexof),
        .id_join(id_join),
        .id_kbevent(id_kbevent),
        .id_keydown(id_keydown),
        .id_keyup(id_keyup),
        .id_kspace(id_kspace),
        .id_length(id_length),
        .id_lineto(id_lineto),
        .id_map(id_map),
        .id_measuretext(id_measuretext),
        .id_mouseev(id_mouseev),
        .id_moveto(id_moveto),
        .id_now(id_now),
        .id_onload(id_onload),
        .id_proto(id_proto),
        .id_push(id_push),
        .id_putimgdata(id_putimgdata),
        .id_quadcurve(id_quadcurve),
        .id_red(id_red),
        .id_rel(id_rel),
        .id_replace(id_replace),
        .id_restore(id_restore),
        .id_right(id_right),
        .id_rotate(id_rotate),
        .id_save(id_save),
        .id_settransform(id_settransform),
        .id_splice(id_splice),
        .id_src(id_src),
        .id_str_function(id_str_function),
        .id_str_number(id_str_number),
        .id_str_object(id_str_object),
        .id_str_string(id_str_string),
        .id_str_undef(id_str_undef),
        .id_stroke(id_stroke),
        .id_strokestyle(id_strokestyle),
        .id_textalign(id_textalign),
        .id_translate(id_translate),
        .id_type(id_type),
        .id_unshift(id_unshift),
        .id_white(id_white),
        .id_width(id_width),
        .id_yellow(id_yellow),
        .idx_needle(idx_needle),
        .idx_t(idx_t),
        .idx_v(idx_v),
        .imgd_armed(imgd_armed),
        .imgd_h(imgd_h),
        .imgd_i(imgd_i),
        .imgd_n(imgd_n),
        .imgd_res(imgd_res),
        .imgd_w(imgd_w),
        .imgd_x(imgd_x),
        .imgd_x0(imgd_x0),
        .imgd_y(imgd_y),
        .imgd_y0(imgd_y0),
        .intern_var(intern_var),
        .intern_var_ok(intern_var_ok),
        .ip(ip),
        .jn_arr(jn_arr),
        .jn_h(jn_h),
        .jn_i(jn_i),
        .jn_res(jn_res),
        .joy_in(joy_in),
        .js_i(js_i),
        .js_ph(js_ph),
        .js_sp(js_sp),
        .js_tag(js_tag),
        .js_val(js_val),
        .json_dst(json_dst),
        .json_pph(json_pph),
        .json_res(json_res),
        .json_rp(json_rp),
        .json_src(json_src),
        .json_srclen(json_srclen),
        .json_wp(json_wp),
        .kd_n(kd_n),
        .kd_slot(kd_slot),
        .kev_fn(kev_fn),
        .kev_is_down(kev_is_down),
        .kev_li(kev_li),
        .kev_obj(kev_obj),
        .kev_ret_ip(kev_ret_ip),
        .keys_a_oid(keys_a_oid),
        .keys_d_oid(keys_d_oid),
        .keys_sp_oid(keys_sp_oid),
        .ku_n(ku_n),
        .ku_slot(ku_slot),
        .lfsr(lfsr),
        .looping(looping),
        .metrics_oid(metrics_oid),
        .mul_a(mul_a),
        .mul_b(mul_b),
        .mul_fx_a(mul_fx_a),
        .mul_fx_b(mul_fx_b),
        .n_arr(n_arr),
        .n_arr_keep(n_arr_keep),
        .n_cls(n_cls),
        .n_fn_proto(n_fn_proto),
        .n_obj(n_obj),
        .n_obj_keep(n_obj_keep),
        .n_ops(n_ops),
        .n_spr(n_spr),
        .namcpy_armed(namcpy_armed),
        .namcpy_repl(namcpy_repl),
        .name_has(name_has),
        .name_rdaddr(name_rdaddr),
        .name_rdata(name_rdata),
        .names_ok(names_ok),
        .nat_argc(nat_argc),
        .nat_id(nat_id),
        .obj_cls(obj_cls),
        .obj_keep_ok(obj_keep_ok),
        .obj_n(obj_n),
        .ops_base(ops_base),
        .path_active(path_active),
        .path_kind(path_kind),
        .path_stroke(path_stroke),
        .pc_a1(pc_a1),
        .pc_a2(pc_a2),
        .pc_a3(pc_a3),
        .pc_a4(pc_a4),
        .pc_a5(pc_a5),
        .pc_ccw(pc_ccw),
        .pc_n(pc_n),
        .pc_op(pc_op),
        .pi(pi),
        .present_pend(present_pend),
        .raf_fn(raf_fn),
        .raf_n(raf_n),
        .rel_i(rel_i),
        .rel_lim(rel_lim),
        .rel_nn(rel_nn),
        .rel_ret(rel_ret),
        .rel_saved(rel_saved),
        .repl_did(repl_did),
        .repl_g(repl_g),
        .repl_nlen(repl_nlen),
        .repl_pat0(repl_pat0),
        .repl_pat1(repl_pat1),
        .repl_rch(repl_rch),
        .rh(rh),
        .running(running),
        .rw(rw),
        .rx(rx),
        .ry(ry),
        .saved_sx(saved_sx),
        .saved_sy(saved_sy),
        .saved_tx(saved_tx),
        .saved_ty(saved_ty),
        .sp(sp),
        .spr_hh(spr_hh),
        .spr_nid(spr_nid),
        .spr_ww(spr_ww),
        .sq_i(sq_i),
        .sq_rad(sq_rad),
        .sq_rem(sq_rem),
        .sq_root(sq_root),
        .stack_tag(stack_tag),
        .start(start),
        .state(state),
        .str_pf_ci(str_pf_ci),
        .str_pf_id(str_pf_id),
        .str_pf_ok(str_pf_ok),
        .str_res(str_res),
        .tenv_parent(tenv_parent),
        .tfn_entry(tfn_entry),
        .tfn_has_this(tfn_has_this),
        .tfn_nparam(tfn_nparam),
        .tfn_parent(tfn_parent),
        .tfn_this(tfn_this),
        .tfn_this_tag(tfn_this_tag),
        .this_obj(this_obj),
        .this_ok(this_ok),
        .time_ms(time_ms),
        .to_delay(to_delay),
        .to_fn(to_fn),
        .to_id(to_id),
        .to_n(to_n),
        .to_period(to_period),
        .to_seq(to_seq),
        .txt_bn(txt_bn),
        .txt_buf(txt_buf),
        .txt_ph(txt_ph),
        .txt_px(txt_px),
        .txt_py(txt_py),
        .txt_rp(txt_rp),
        .txt_val(txt_val),
        .txt_vt(txt_vt),
        .var_init(var_init),
        .var_tag(var_tag),
        .var_this(var_this),
        .vars(vars),
        .vcall_argc(vcall_argc),
        .vcall_this(vcall_this),
        .x(x),
        .xf_dst(xf_dst),
        .xf_h(xf_h),
        .xf_w(xf_w),
        .xf_x(xf_x),
        .xf_y(xf_y),
        .y(y),
        .alu_a_n(e32_alu_a_n),
        .alu_b_n(e32_alu_b_n),
        .alu_fx_n(e32_alu_fx_n),
        .alu_op_n(e32_alu_op_n),
        .blit_sh_n(e32_blit_sh_n),
        .blit_si_n(e32_blit_si_n),
        .blit_sw_n(e32_blit_sw_n),
        .blit_sx_n(e32_blit_sx_n),
        .blit_sy_n(e32_blit_sy_n),
        .cc_at_n(e32_cc_at_n),
        .cc_av_n(e32_cc_av_n),
        .cc_bok_n(e32_cc_bok_n),
        .cc_bt_n(e32_cc_bt_n),
        .cc_bv_n(e32_cc_bv_n),
        .cc_d_n(e32_cc_d_n),
        .cc_h_n(e32_cc_h_n),
        .cc_len_n(e32_cc_len_n),
        .cc_second_n(e32_cc_second_n),
        .cc_st_n(e32_cc_st_n),
        .click_fired_n(e32_click_fired_n),
        .click_fn_n(e32_click_fn_n),
        .clr_idx_n(e32_clr_idx_n),
        .code_raddr_n(e32_code_raddr_n),
        .color_n(e32_color_n),
        .csp_n(e32_csp_n),
        .ctx_align_n(e32_ctx_align_n),
        .ctx_font_px_n(e32_ctx_font_px_n),
        .ctx_smooth_n(e32_ctx_smooth_n),
        .ctx_sx_n(e32_ctx_sx_n),
        .ctx_sy_n(e32_ctx_sy_n),
        .ctx_tx_n(e32_ctx_tx_n),
        .ctx_ty_n(e32_ctx_ty_n),
        .dbg_call_ovf_n(e32_dbg_call_ovf_n),
        .dbg_cb_ip_n(e32_dbg_cb_ip_n),
        .dbg_di_hit_n(e32_dbg_di_hit_n),
        .dbg_di_miss_n(e32_dbg_di_miss_n),
        .dbg_div_n_n(e32_dbg_div_n_n),
        .dbg_find_hit_n(e32_dbg_find_hit_n),
        .dbg_heap_ovf_n(e32_dbg_heap_ovf_n),
        .dbg_json_ovf_n(e32_dbg_json_ovf_n),
        .dbg_path_ovf_n(e32_dbg_path_ovf_n),
        .dbg_splice_n_n(e32_dbg_splice_n_n),
        .dbg_stack_ovf_n(e32_dbg_stack_ovf_n),
        .dbg_tmr_sched_n(e32_dbg_tmr_sched_n),
        .dbg_to_ovf_n(e32_dbg_to_ovf_n),
        .did_swap_n(e32_did_swap_n),
        .div_cnt_n(e32_div_cnt_n),
        .div_int_in_n(e32_div_int_in_n),
        .div_neg_n(e32_div_neg_n),
        .div_rem_n(e32_div_rem_n),
        .div_ub_n(e32_div_ub_n),
        .div_uq_n(e32_div_uq_n),
        .env_free_n_n(e32_env_free_n_n),
        .env_is_store_n(e32_env_is_store_n),
        .env_ld_slot_n(e32_env_ld_slot_n),
        .env_sp_n(e32_env_sp_n),
        .env_walk_n(e32_env_walk_n),
        .fb_dump_addr_n(e32_fb_dump_addr_n),
        .fb_dump_sel_n(e32_fb_dump_sel_n),
        .fb_swap_n(e32_fb_swap_n),
        .fill_style_i_n(e32_fill_style_i_n),
        .fp_left_n(e32_fp_left_n),
        .fpx_acc_n(e32_fpx_acc_n),
        .frame_fire_n(e32_frame_fire_n),
        .hp_aid_n(e32_hp_aid_n),
        .hp_alen_n(e32_hp_alen_n),
        .hp_aslot_n(e32_hp_aslot_n),
        .hp_cmd_n(e32_hp_cmd_n),
        .hp_from_stack_n(e32_hp_from_stack_n),
        .hp_hit_n(e32_hp_hit_n),
        .hp_key_n(e32_hp_key_n),
        .hp_len_n(e32_hp_len_n),
        .hp_lim_n(e32_hp_lim_n),
        .hp_make_arr_n(e32_hp_make_arr_n),
        .hp_nat_n(e32_hp_nat_n),
        .hp_oid_n(e32_hp_oid_n),
        .hp_phase_n(e32_hp_phase_n),
        .hp_proto_n(e32_hp_proto_n),
        .hp_qi_n(e32_hp_qi_n),
        .hp_qn_n(e32_hp_qn_n),
        .hp_ret_n(e32_hp_ret_n),
        .hp_rval_n(e32_hp_rval_n),
        .hp_si_n(e32_hp_si_n),
        .hp_slot_n(e32_hp_slot_n),
        .hp_ss_n(e32_hp_ss_n),
        .hp_tag_n(e32_hp_tag_n),
        .hp_tn_n(e32_hp_tn_n),
        .hp_v64_n(e32_hp_v64_n),
        .hp_vbase_n(e32_hp_vbase_n),
        .hp_wval_n(e32_hp_wval_n),
        .idx_needle_n(e32_idx_needle_n),
        .idx_t_n(e32_idx_t_n),
        .idx_v_n(e32_idx_v_n),
        .imgd_armed_n(e32_imgd_armed_n),
        .imgd_h_n(e32_imgd_h_n),
        .imgd_i_n(e32_imgd_i_n),
        .imgd_n_n(e32_imgd_n_n),
        .imgd_res_n(e32_imgd_res_n),
        .imgd_w_n(e32_imgd_w_n),
        .imgd_x_n(e32_imgd_x_n),
        .imgd_x0_n(e32_imgd_x0_n),
        .imgd_y_n(e32_imgd_y_n),
        .imgd_y0_n(e32_imgd_y0_n),
        .ip_n(e32_ip_n),
        .jn_arr_n(e32_jn_arr_n),
        .jn_h_n(e32_jn_h_n),
        .jn_i_n(e32_jn_i_n),
        .jn_res_n(e32_jn_res_n),
        .js_sp_n(e32_js_sp_n),
        .json_dst_n(e32_json_dst_n),
        .json_pph_n(e32_json_pph_n),
        .json_res_n(e32_json_res_n),
        .json_rp_n(e32_json_rp_n),
        .json_src_n(e32_json_src_n),
        .json_srclen_n(e32_json_srclen_n),
        .json_wp_n(e32_json_wp_n),
        .kd_n_n(e32_kd_n_n),
        .kev_fn_n(e32_kev_fn_n),
        .kev_is_down_n(e32_kev_is_down_n),
        .kev_li_n(e32_kev_li_n),
        .kev_obj_n(e32_kev_obj_n),
        .kev_ret_ip_n(e32_kev_ret_ip_n),
        .keys_a_oid_n(e32_keys_a_oid_n),
        .keys_d_oid_n(e32_keys_d_oid_n),
        .keys_sp_oid_n(e32_keys_sp_oid_n),
        .ku_n_n(e32_ku_n_n),
        .lfsr_n(e32_lfsr_n),
        .looping_n(e32_looping_n),
        .metrics_oid_n(e32_metrics_oid_n),
        .mul_a_n(e32_mul_a_n),
        .mul_b_n(e32_mul_b_n),
        .mul_fx_a_n(e32_mul_fx_a_n),
        .mul_fx_b_n(e32_mul_fx_b_n),
        .n_arr_n(e32_n_arr_n),
        .n_arr_keep_n(e32_n_arr_keep_n),
        .n_fn_proto_n(e32_n_fn_proto_n),
        .n_obj_n(e32_n_obj_n),
        .n_obj_keep_n(e32_n_obj_keep_n),
        .namcpy_armed_n(e32_namcpy_armed_n),
        .namcpy_repl_n(e32_namcpy_repl_n),
        .name_rdaddr_n(e32_name_rdaddr_n),
        .nat_argc_n(e32_nat_argc_n),
        .nat_id_n(e32_nat_id_n),
        .path_active_n(e32_path_active_n),
        .path_kind_n(e32_path_kind_n),
        .path_stroke_n(e32_path_stroke_n),
        .pc_n_n(e32_pc_n_n),
        .pi_n(e32_pi_n),
        .present_pend_n(e32_present_pend_n),
        .raf_n_n(e32_raf_n_n),
        .rel_i_n(e32_rel_i_n),
        .rel_lim_n(e32_rel_lim_n),
        .rel_nn_n(e32_rel_nn_n),
        .rel_ret_n(e32_rel_ret_n),
        .rel_saved_n(e32_rel_saved_n),
        .repl_did_n(e32_repl_did_n),
        .repl_g_n(e32_repl_g_n),
        .repl_nlen_n(e32_repl_nlen_n),
        .repl_pat0_n(e32_repl_pat0_n),
        .repl_pat1_n(e32_repl_pat1_n),
        .repl_rch_n(e32_repl_rch_n),
        .rh_n(e32_rh_n),
        .running_n(e32_running_n),
        .rw_n(e32_rw_n),
        .rx_n(e32_rx_n),
        .ry_n(e32_ry_n),
        .saved_sx_n(e32_saved_sx_n),
        .saved_sy_n(e32_saved_sy_n),
        .saved_tx_n(e32_saved_tx_n),
        .saved_ty_n(e32_saved_ty_n),
        .sp_n(e32_sp_n),
        .sq_i_n(e32_sq_i_n),
        .sq_rad_n(e32_sq_rad_n),
        .sq_rem_n(e32_sq_rem_n),
        .sq_root_n(e32_sq_root_n),
        .state_n(e32_state_n),
        .str_pf_ci_n(e32_str_pf_ci_n),
        .str_pf_id_n(e32_str_pf_id_n),
        .str_pf_ok_n(e32_str_pf_ok_n),
        .str_res_n(e32_str_res_n),
        .this_obj_n(e32_this_obj_n),
        .to_n_n(e32_to_n_n),
        .to_seq_n(e32_to_seq_n),
        .txt_bn_n(e32_txt_bn_n),
        .txt_ph_n(e32_txt_ph_n),
        .txt_px_n(e32_txt_px_n),
        .txt_py_n(e32_txt_py_n),
        .txt_rp_n(e32_txt_rp_n),
        .txt_val_n(e32_txt_val_n),
        .txt_vt_n(e32_txt_vt_n),
        .vcall_argc_n(e32_vcall_argc_n),
        .vcall_this_n(e32_vcall_this_n),
        .x_n(e32_x_n),
        .xf_dst_n(e32_xf_dst_n),
        .xf_h_n(e32_xf_h_n),
        .xf_w_n(e32_xf_w_n),
        .xf_x_n(e32_xf_x_n),
        .xf_y_n(e32_xf_y_n),
        .y_n(e32_y_n),
        .cstack_ctorobj_n(e32_cstack_ctorobj_n),
        .cstack_env_n(e32_cstack_env_n),
        .cstack_fe_arr_n(e32_cstack_fe_arr_n),
        .cstack_fe_fn_n(e32_cstack_fe_fn_n),
        .cstack_fe_i_n(e32_cstack_fe_i_n),
        .cstack_ip_n(e32_cstack_ip_n),
        .cstack_isctor_n(e32_cstack_isctor_n),
        .cstack_isfe_n(e32_cstack_isfe_n),
        .cstack_map_arr_n(e32_cstack_map_arr_n),
        .cstack_this_n(e32_cstack_this_n),
        .fn_proto_ip_n(e32_fn_proto_ip_n),
        .fn_proto_oid_n(e32_fn_proto_oid_n),
        .hp_qk_n(e32_hp_qk_n),
        .hp_qt_n(e32_hp_qt_n),
        .hp_qv_n(e32_hp_qv_n),
        .js_i_n(e32_js_i_n),
        .js_ph_n(e32_js_ph_n),
        .js_tag_n(e32_js_tag_n),
        .js_val_n(e32_js_val_n),
        .kd_slot_n(e32_kd_slot_n),
        .ku_slot_n(e32_ku_slot_n),
        .pc_a1_n(e32_pc_a1_n),
        .pc_a2_n(e32_pc_a2_n),
        .pc_a3_n(e32_pc_a3_n),
        .pc_a4_n(e32_pc_a4_n),
        .pc_a5_n(e32_pc_a5_n),
        .pc_ccw_n(e32_pc_ccw_n),
        .pc_op_n(e32_pc_op_n),
        .raf_fn_n(e32_raf_fn_n),
        .to_delay_n(e32_to_delay_n),
        .to_fn_n(e32_to_fn_n),
        .to_id_n(e32_to_id_n),
        .to_period_n(e32_to_period_n),
        .arr_len_we(e32_arr_len_we),
        .arr_len_waddr(e32_arr_len_waddr),
        .arr_len_wdata(e32_arr_len_wdata),
        .env_cap_we(e32_env_cap_we),
        .env_cap_waddr(e32_env_cap_waddr),
        .env_cap_wdata(e32_env_cap_wdata),
        .env_oid_we(e32_env_oid_we),
        .env_oid_waddr(e32_env_oid_waddr),
        .env_oid_wdata(e32_env_oid_wdata),
        .json_mem_we(e32_json_mem_we),
        .json_mem_waddr(e32_json_mem_waddr),
        .json_mem_wdata(e32_json_mem_wdata),
        .obj_cls_we(e32_obj_cls_we),
        .obj_cls_waddr(e32_obj_cls_waddr),
        .obj_cls_wdata(e32_obj_cls_wdata),
        .obj_n_we(e32_obj_n_we),
        .obj_n_waddr(e32_obj_n_waddr),
        .obj_n_wdata(e32_obj_n_wdata),
        .stack_we(e32_stack_we),
        .stack_waddr(e32_stack_waddr),
        .stack_wdata(e32_stack_wdata),
        .stack_tag_we(e32_stack_tag_we),
        .stack_tag_waddr(e32_stack_tag_waddr),
        .stack_tag_wdata(e32_stack_tag_wdata),
        .tenv_parent_we(e32_tenv_parent_we),
        .tenv_parent_waddr(e32_tenv_parent_waddr),
        .tenv_parent_wdata(e32_tenv_parent_wdata),
        .tfn_entry_we(e32_tfn_entry_we),
        .tfn_entry_waddr(e32_tfn_entry_waddr),
        .tfn_entry_wdata(e32_tfn_entry_wdata),
        .tfn_has_this_we(e32_tfn_has_this_we),
        .tfn_has_this_waddr(e32_tfn_has_this_waddr),
        .tfn_has_this_wdata(e32_tfn_has_this_wdata),
        .tfn_nparam_we(e32_tfn_nparam_we),
        .tfn_nparam_waddr(e32_tfn_nparam_waddr),
        .tfn_nparam_wdata(e32_tfn_nparam_wdata),
        .tfn_parent_we(e32_tfn_parent_we),
        .tfn_parent_waddr(e32_tfn_parent_waddr),
        .tfn_parent_wdata(e32_tfn_parent_wdata),
        .tfn_this_we(e32_tfn_this_we),
        .tfn_this_waddr(e32_tfn_this_waddr),
        .tfn_this_wdata(e32_tfn_this_wdata),
        .tfn_this_tag_we(e32_tfn_this_tag_we),
        .tfn_this_tag_waddr(e32_tfn_this_tag_waddr),
        .tfn_this_tag_wdata(e32_tfn_this_tag_wdata),
        .var_init_we(e32_var_init_we),
        .var_init_waddr(e32_var_init_waddr),
        .var_init_wdata(e32_var_init_wdata),
        .var_tag_we(e32_var_tag_we),
        .var_tag_waddr(e32_var_tag_waddr),
        .var_tag_wdata(e32_var_tag_wdata),
        .vars_we(e32_vars_we),
        .vars_waddr(e32_vars_waddr),
        .vars_wdata(e32_vars_wdata),
        .vobj_len_we(e32_vobj_len_we),
        .vobj_len_waddr(e32_vobj_len_waddr),
        .vobj_len_wdata(e32_vobj_len_wdata)
    );

    // Hierarchical jmr_js_vm_exec64: keep_hierarchy so Vivado does not flatten
    // the opcode mux back into the parent always_ff.
    logic e64_aset_win_retried_n;
    logic [7:0] e64_bind_argc_n;
    logic [11:0] e64_bind_base_n;
    logic [15:0] e64_bind_ip_n;
    logic [7:0] e64_bind_k_n;
    logic [1:0] e64_bind_mode_n;
    logic [7:0] e64_bind_n_n;
    logic e64_bind_rd_arm_n;
    logic [6:0] e64_bind_ret_n;
    logic [11:0] e64_bind_src_n;
    logic [11:0] e64_bind_vsp_next_n;
    logic [15:0] e64_blit_sh_n;
    logic [7:0] e64_blit_si_n;
    logic [15:0] e64_blit_sw_n;
    logic [15:0] e64_blit_sx_n;
    logic [15:0] e64_blit_sy_n;
    logic [2:0] e64_cc_at_n;
    logic signed [31:0] e64_cc_av_n;
    logic e64_cc_bok_n;
    logic [2:0] e64_cc_bt_n;
    logic signed [31:0] e64_cc_bv_n;
    logic [3:0] e64_cc_d_n;
    logic [15:0] e64_cc_h_n;
    logic [7:0] e64_cc_len_n;
    logic e64_cc_second_n;
    logic [1:0] e64_cc_st_n;
    logic [14:0] e64_code_raddr_n;
    logic [7:0] e64_color_n;
    logic [1:0] e64_ctx_align_n;
    logic e64_ctx_smooth_n;
    logic signed [31:0] e64_ctx_sx_n;
    logic signed [31:0] e64_ctx_sy_n;
    logic signed [31:0] e64_ctx_tx_n;
    logic signed [31:0] e64_ctx_ty_n;
    logic [15:0] e64_dbg_di_hit_n;
    logic [15:0] e64_dbg_di_miss_n;
    logic [15:0] e64_dbg_div_n_n;
    logic [15:0] e64_dbg_json_ovf_n;
    logic [15:0] e64_dbg_path_ovf_n;
    logic [7:0] e64_fault_code_n;
    logic [18:0] e64_fb_dump_addr_n;
    logic e64_fb_dump_sel_n;
    logic e64_fb_swap_n;
    logic [7:0] e64_fill_style_i_n;
    logic [7:0] e64_stroke_style_i_n;
    logic [11:0] e64_hp_aid_n;
    logic [7:0] e64_hp_alen_n;
    logic [6:0] e64_hp_aslot_n;
    logic [3:0] e64_hp_cmd_n;
    logic [9:0] e64_hp_eid_n;
    logic e64_hp_env_n;
    logic e64_hp_from_stack_n;
    logic e64_hp_hit_n;
    logic [15:0] e64_hp_key_n;
    logic [5:0] e64_hp_len_n;
    logic [7:0] e64_hp_lim_n;
    logic e64_hp_make_arr_n;
    logic [3:0] e64_hp_nat_n;
    logic [12:0] e64_hp_oid_n;
    logic [2:0] e64_hp_phase_n;
    logic [63:0] e64_hp_proto_n;
    logic [2:0] e64_hp_qi_n;
    logic [2:0] e64_hp_qn_n;
    logic [6:0] e64_hp_ret_n;
    logic [63:0] e64_hp_rval_n;
    logic [12:0] e64_hp_si_n;
    logic [4:0] e64_hp_slot_n;
    logic [15:0] e64_hp_spr_h_n;
    logic [15:0] e64_hp_spr_w_n;
    logic [4:0] e64_hp_ss_n;
    logic [2:0] e64_hp_tag_n;
    logic [5:0] e64_hp_tn_n;
    logic e64_hp_v64_n;
    logic [11:0] e64_hp_vbase_n;
    logic [63:0] e64_hp_wval_n;
    logic e64_imgd_armed_n;
    logic [9:0] e64_imgd_h_n;
    logic [18:0] e64_imgd_i_n;
    logic [18:0] e64_imgd_n_n;
    logic e64_imgd_v64_n;
    logic [9:0] e64_imgd_w_n;
    logic [9:0] e64_imgd_x_n;
    logic [9:0] e64_imgd_x0_n;
    logic [9:0] e64_imgd_y_n;
    logic [9:0] e64_imgd_y0_n;
    logic [15:0] e64_ip_n;
    logic [11:0] e64_jn_arr_n;
    logic [15:0] e64_jn_h_n;
    logic [15:0] e64_jn_i_n;
    logic [10:0] e64_jn_res_n;
    logic [5:0] e64_js_sp_n;
    logic [2:0] e64_json_pph_n;
    logic [13:0] e64_json_rp_n;
    logic [13:0] e64_json_src_n;
    logic [13:0] e64_json_srclen_n;
    logic [13:0] e64_json_wp_n;
    logic e64_looping_n;
    logic e64_machine_fault_n;
    logic [63:0] e64_minmax_acc_n;
    logic [11:0] e64_minmax_base_n;
    logic e64_minmax_is_min_n;
    logic [7:0] e64_minmax_k_n;
    logic [7:0] e64_minmax_n_n;
    logic e64_namcpy_armed_n;
    logic e64_namcpy_repl_n;
    logic e64_namcpy_v64_n;
    logic [15:0] e64_name_rdaddr_n;
    logic e64_path_active_n;
    logic [1:0] e64_path_kind_n;
    logic e64_path_stroke_n;
    logic [4:0] e64_pc_n_n;
    logic [4:0] e64_pi_n;
    logic e64_repl_did_n;
    logic e64_repl_g_n;
    logic [7:0] e64_repl_nlen_n;
    logic [7:0] e64_repl_pat0_n;
    logic [7:0] e64_repl_pat1_n;
    logic [7:0] e64_repl_rch_n;
    logic [9:0] e64_rh_n;
    logic e64_running_n;
    logic [9:0] e64_rw_n;
    logic [9:0] e64_rx_n;
    logic [9:0] e64_ry_n;
    logic signed [31:0] e64_saved_sx_n;
    logic signed [31:0] e64_saved_sy_n;
    logic signed [31:0] e64_saved_tx_n;
    logic signed [31:0] e64_saved_ty_n;
    logic [4:0] e64_sq_i_n;
    logic [47:0] e64_sq_rad_n;
    logic [25:0] e64_sq_rem_n;
    logic [23:0] e64_sq_root_n;
    logic [6:0] e64_state_n;
    logic [6:0] e64_txt_bn_n;
    logic [3:0] e64_txt_ph_n;
    logic signed [15:0] e64_txt_px_n;
    logic signed [15:0] e64_txt_py_n;
    logic [31:0] e64_txt_val_n;
    logic [2:0] e64_txt_vt_n;
    logic e64_v64_concat_n;
    logic e64_v64_join_n;
    logic e64_v64_repl_n;
    logic e64_v64_sqrt_n;
    logic [7:0] e64_valloc_arr_n_n;
    logic e64_valloc_bind_n;
    logic [12:0] e64_valloc_bind_src_n;
    logic [63:0] e64_valloc_bind_this_n;
    logic [7:0] e64_valloc_fn_a1_n;
    logic [15:0] e64_valloc_fn_entry_n;
    logic [13:0] e64_valloc_i_n;
    logic [1:0] e64_valloc_kind_n;
    logic e64_valloc_metrics_n;
    logic e64_valloc_now_fn_n;
    logic e64_valloc_proto_n;
    logic [12:0] e64_valloc_proto_fn_n;
    logic e64_valloc_regex_n;
    logic [31:0] e64_valloc_regex_pack_n;
    logic e64_valloc_retried_n;
    logic [13:0] e64_varr_next_n;
    logic [11:0] e64_vcall_argc_n;
    logic [63:0] e64_vcall_ctor_val_n;
    logic [15:0] e64_vcall_entry_n;
    logic e64_vcall_set_this_n;
    logic [63:0] e64_vcall_this_n;
    logic e64_vcall_value_n;
    logic [8:0] e64_vconsole_n_n;
    logic [7:0] e64_vcsp_n;
    logic [7:0] e64_vdiv_count_n;
    logic [52:0] e64_vdiv_den_n;
    logic signed [12:0] e64_vdiv_exp_n;
    logic [106:0] e64_vdiv_num_n;
    logic [106:0] e64_vdiv_quot_n;
    logic [53:0] e64_vdiv_rem_n;
    logic e64_vdiv_sign_n;
    logic [7:0] e64_vdraw_color_n;
    logic [9:0] e64_vdraw_h_n;
    logic [18:0] e64_vdraw_i_n;
    logic [9:0] e64_vdraw_w_n;
    logic [9:0] e64_vdraw_x_n;
    logic [9:0] e64_vdraw_y_n;
    logic [63:0] e64_venv_n;
    logic [9:0] e64_venv_next_n;
    logic [63:0] e64_vfe_arr_n;
    logic [11:0] e64_vfe_base_n;
    logic [63:0] e64_vfe_fn_n;
    logic [7:0] e64_vfe_i_n;
    logic [63:0] e64_vfe_map_n;
    logic [1:0] e64_vfe_mode_n;
    logic [15:0] e64_vfe_ret_n;
    logic [3:0] e64_vfe_sp_n;
    logic e64_vfree_armed_n;
    logic e64_vfree_arr_long_n;
    logic [13:0] e64_vgc_clear_i_n;
    logic e64_vgc_halt_after_n;
    logic [13:0] e64_vgc_qr_n;
    logic [13:0] e64_vgc_qw_n;
    logic [1:0] e64_vgc_resume_n;
    logic e64_vgc_wait_after_n;
    logic e64_vjs_rd_arm_n;
    logic [4:0] e64_vlistener_n_n;
    logic [15:0] e64_vmetrics_w_n;
    logic [11:0] e64_vmod_count_n;
    logic [52:0] e64_vmod_den_n;
    logic signed [12:0] e64_vmod_exp_n;
    logic [52:0] e64_vmod_rem_n;
    logic e64_vmod_sign_n;
    logic [11:0] e64_vnat_base_n;
    logic [2:0] e64_vnat_dom_n;
    logic e64_vprom_copy_n;
    logic e64_vprom_done_n;
    logic [6:0] e64_vprom_ret_n;
    logic [3:0] e64_vraf_n_n;
    logic [31:0] e64_vrng_n;
    logic [11:0] e64_vsp_n;
    logic e64_vst_hold_win_n;
    logic e64_vst_refill_arm_n;
    logic [3:0] e64_vst_refill_i_n;
    logic [6:0] e64_vst_refill_ret_n;
    logic [11:0] e64_vst_waddr_n;
    logic [63:0] e64_vst_wdata_n;
    logic e64_vst_we_n;
    logic [63:0] e64_vthis_n;
    logic [6:0] e64_vtimer_n_n;
    logic [31:0] e64_vtimer_seq_n;
    logic [9:0] e64_x_n;
    logic [9:0] e64_y_n;
    logic [15:0] e64_hp_qk_n [0:3];
    logic [2:0] e64_hp_qt_n [0:3];
    logic [63:0] e64_hp_qv_n [0:3];
    logic [7:0] e64_js_i_n [0:JSON_STK-1];
    logic [2:0] e64_js_ph_n [0:JSON_STK-1];
    logic signed [31:0] e64_pc_a1_n [0:PATH_MAX-1];
    logic signed [31:0] e64_pc_a2_n [0:PATH_MAX-1];
    logic signed [31:0] e64_pc_a3_n [0:PATH_MAX-1];
    logic signed [31:0] e64_pc_a4_n [0:PATH_MAX-1];
    logic signed [31:0] e64_pc_a5_n [0:PATH_MAX-1];
    logic e64_pc_ccw_n [0:PATH_MAX-1];
    logic [1:0] e64_pc_op_n [0:PATH_MAX-1];
    logic [63:0] e64_vfe_arr_s_n [0:7];
    logic [11:0] e64_vfe_base_s_n [0:7];
    logic [63:0] e64_vfe_fn_s_n [0:7];
    logic [7:0] e64_vfe_i_s_n [0:7];
    logic [63:0] e64_vfe_map_s_n [0:7];
    logic [1:0] e64_vfe_mode_s_n [0:7];
    logic [15:0] e64_vfe_ret_s_n [0:7];
    logic [11:0] e64_vframe_base_sp_n [0:CSTK-1];
    logic [63:0] e64_vframe_ctor_n [0:CSTK-1];
    logic [63:0] e64_vframe_env_n [0:CSTK-1];
    logic e64_vframe_escaped_n [0:CSTK-1];
    logic [63:0] e64_vframe_fn_n [0:CSTK-1];
    logic [15:0] e64_vframe_return_ip_n [0:CSTK-1];
    logic [63:0] e64_vframe_this_n [0:CSTK-1];
    logic [63:0] e64_vjs_val_n [0:JSON_STK-1];
    logic [63:0] e64_vlistener_ev_n [0:15];
    logic [63:0] e64_vlistener_fn_n [0:15];
    logic e64_vlong_used_n [0:MAX_ARR_LONG-1];
    logic [63:0] e64_vraf_n [0:7];
    logic [63:0] e64_vst_win_n [0:15];
    logic signed [31:0] e64_vtimer_due_n [0:63];
    logic [63:0] e64_vtimer_fn_n [0:63];
    logic signed [31:0] e64_vtimer_id_n [0:63];
    logic signed [63:0] e64_vtimer_period_n [0:63];
    logic e64_vtimer_valid_n [0:63];
    logic e64_json_mem_we;
    logic [12:0] e64_json_mem_waddr;
    logic [7:0] e64_json_mem_wdata;
    logic e64_varr_len_we;
    logic [11:0] e64_varr_len_waddr;
    logic [7:0] e64_varr_len_wdata;
    logic e64_varr_lidx_we;
    logic [11:0] e64_varr_lidx_waddr;
    logic [7:0] e64_varr_lidx_wdata;
    logic e64_varr_long_we;
    logic [11:0] e64_varr_long_waddr;
    logic [31:0] e64_varr_long_wdata;
    logic e64_varr_valid_we;
    logic [11:0] e64_varr_valid_waddr;
    logic [31:0] e64_varr_valid_wdata;
    logic e64_venv_gen_we;
    logic [11:0] e64_venv_gen_waddr;
    logic [11:0] e64_venv_gen_wdata;
    logic e64_venv_len_we;
    logic [11:0] e64_venv_len_waddr;
    logic [4:0] e64_venv_len_wdata;
    logic e64_venv_valid_we;
    logic [11:0] e64_venv_valid_waddr;
    logic [31:0] e64_venv_valid_wdata;
    logic e64_vobj_cls_we;
    logic [11:0] e64_vobj_cls_waddr;
    logic [15:0] e64_vobj_cls_wdata;
    logic e64_vvar_valid_we;
    logic [11:0] e64_vvar_valid_waddr;
    logic [31:0] e64_vvar_valid_wdata;
    logic e64_vvars_we;
    logic [11:0] e64_vvars_waddr;
    logic [63:0] e64_vvars_wdata;
    logic e64_vframe_we;
    logic [6:0] e64_vframe_waddr;
    logic [15:0] e64_vframe_rip_wdata;
    logic [11:0] e64_vframe_bsp_wdata;
    logic e64_vframe_esc_wdata;
    logic [63:0] e64_vframe_this_wdata;
    logic [63:0] e64_vframe_env_wdata;
    logic [63:0] e64_vframe_fn_wdata;
    logic [63:0] e64_vframe_ctor_wdata;
    (* keep_hierarchy = "yes" *)
    jmr_js_vm_exec64 u_exec64 (
        .clk(clk),
        .enable((state == S_V64_EXEC)),
        .p_clr(e64_p_clr),
        .p_we(e64_p_we),
        .p_sel(e64_p_sel),
        .p_addr(e64_p_addr),
        .p_addr2(e64_p_addr2),
        .p_data(e64_p_data),
        .p_data2(e64_p_data2),
        .p_data3(e64_p_data3),
        .p_data4(e64_p_data4),
        .p_data5(e64_p_data5),
        .p_frame_we(e64_p_frame_we),
        .p_frame_idx(e64_p_frame_idx),
        .p_frame_rip(e64_p_frame_rip),
        .p_frame_bsp(e64_p_frame_bsp),
        .p_frame_esc(e64_p_frame_esc),
        .p_frame_this(e64_p_frame_this),
        .p_frame_env(e64_p_frame_env),
        .p_frame_fn(e64_p_frame_fnv),
        .p_frame_ctor(e64_p_frame_ctor),
        .aset_win_retried(aset_win_retried),
        .bind_argc(bind_argc),
        .bind_base(bind_base),
        .bind_ip(bind_ip),
        .bind_k(bind_k),
        .bind_mode(bind_mode),
        .bind_n(bind_n),
        .bind_rd_arm(bind_rd_arm),
        .bind_ret(bind_ret),
        .bind_src(bind_src),
        .bind_vsp_next(bind_vsp_next),
        .blit_sh(blit_sh),
        .blit_si(blit_si),
        .blit_sw(blit_sw),
        .blit_sx(blit_sx),
        .blit_sy(blit_sy),
        .cc_at(cc_at),
        .cc_av(cc_av),
        .cc_bok(cc_bok),
        .cc_bt(cc_bt),
        .cc_bv(cc_bv),
        .cc_d(cc_d),
        .cc_h(cc_h),
        .cc_len(cc_len),
        .cc_second(cc_second),
        .cc_st(cc_st),
        .code_raddr(code_raddr),
        .code_rdata(code_rdata),
        .color(color),
        .ctx_align(ctx_align),
        .ctx_smooth(ctx_smooth),
        .ctx_sx(ctx_sx),
        .ctx_sy(ctx_sy),
        .ctx_tx(ctx_tx),
        .ctx_ty(ctx_ty),
        .dbg_di_hit(dbg_di_hit),
        .dbg_di_miss(dbg_di_miss),
        .dbg_div_n(dbg_div_n),
        .dbg_json_ovf(dbg_json_ovf),
        .dbg_path_ovf(dbg_path_ovf),
        .dbg_str_ovf(dbg_str_ovf),
        .fault_code(fault_code),
        .fb_dump_addr(fb_dump_addr),
        .fb_dump_sel(fb_dump_sel),
        .fb_swap(fb_swap),
        .fill_style_i(fill_style_i),
        .stroke_style_i(stroke_style_i),
        .hp_aid(hp_aid),
        .hp_alen(hp_alen),
        .hp_aslot(hp_aslot),
        .hp_cmd(hp_cmd),
        .hp_eid(hp_eid),
        .hp_env(hp_env),
        .hp_from_stack(hp_from_stack),
        .hp_hit(hp_hit),
        .hp_key(hp_key),
        .hp_len(hp_len),
        .hp_lim(hp_lim),
        .hp_make_arr(hp_make_arr),
        .hp_nat(hp_nat),
        .hp_oid(hp_oid),
        .hp_phase(hp_phase),
        .hp_proto(hp_proto),
        .hp_qi(hp_qi),
        .hp_qk(hp_qk),
        .hp_qn(hp_qn),
        .hp_qt(hp_qt),
        .hp_qv(hp_qv),
        .hp_ret(hp_ret),
        .hp_rval(hp_rval),
        .hp_si(hp_si),
        .hp_slot(hp_slot),
        .hp_spr_h(hp_spr_h),
        .hp_spr_w(hp_spr_w),
        .hp_ss(hp_ss),
        .hp_tag(hp_tag),
        .hp_tn(hp_tn),
        .hp_v64(hp_v64),
        .hp_vbase(hp_vbase),
        .hp_wval(hp_wval),
        .id_ael(id_ael),
        .id_arc(id_arc),
        .id_assign(id_assign),
        .id_beginpath(id_beginpath),
        .id_bind(id_bind),
        .id_black(id_black),
        .id_center(id_center),
        .id_clearrect(id_clearrect),
        .id_closepath(id_closepath),
        .id_drawimage(id_drawimage),
        .id_fill(id_fill),
        .id_fillrect(id_fillrect),
        .id_fillstyle(id_fillstyle),
        .id_filltext(id_filltext),
        .id_filter(id_filter),
        .id_find(id_find),
        .id_foreach(id_foreach),
        .id_getctx(id_getctx),
        .id_getimgdata(id_getimgdata),
        .id_gettime(id_gettime),
        .id_height(id_height),
        .id_hex_000(id_hex_000),
        .id_hex_fff(id_hex_fff),
        .id_imgsmooth(id_imgsmooth),
        .id_indexof(id_indexof),
        .id_join(id_join),
        .id_length(id_length),
        .id_lineto(id_lineto),
        .id_map(id_map),
        .id_measuretext(id_measuretext),
        .id_moveto(id_moveto),
        .id_now(id_now),
        .id_onload(id_onload),
        .id_pop(id_pop),
        .id_proto(id_proto),
        .id_push(id_push),
        .id_putimgdata(id_putimgdata),
        .id_replace(id_replace),
        .id_restore(id_restore),
        .id_right(id_right),
        .id_save(id_save),
        .id_settransform(id_settransform),
        .id_splice(id_splice),
        .id_src(id_src),
        .id_str_function(id_str_function),
        .id_str_number(id_str_number),
        .id_str_object(id_str_object),
        .id_str_string(id_str_string),
        .id_str_undef(id_str_undef),
        .id_stroke(id_stroke),
        .id_strokestyle(id_strokestyle),
        .id_textalign(id_textalign),
        .id_translate(id_translate),
        .id_unshift(id_unshift),
        .id_white(id_white),
        .id_width(id_width),
        .imgd_armed(imgd_armed),
        .imgd_h(imgd_h),
        .imgd_i(imgd_i),
        .imgd_n(imgd_n),
        .imgd_v64(imgd_v64),
        .imgd_w(imgd_w),
        .imgd_x(imgd_x),
        .imgd_x0(imgd_x0),
        .imgd_y(imgd_y),
        .imgd_y0(imgd_y0),
        .ip(ip),
        .jn_arr(jn_arr),
        .jn_h(jn_h),
        .jn_i(jn_i),
        .jn_res(jn_res),
        .joy_in(joy_in),
        .js_i(js_i),
        .js_ph(js_ph),
        .js_sp(js_sp),
        .json_pph(json_pph),
        .json_rp(json_rp),
        .json_src(json_src),
        .json_srclen(json_srclen),
        .json_wp(json_wp),
        .looping(looping),
        .machine_fault(machine_fault),
        .minmax_acc(minmax_acc),
        .minmax_base(minmax_base),
        .minmax_is_min(minmax_is_min),
        .minmax_k(minmax_k),
        .minmax_n(minmax_n),
        .n_cls(n_cls),
        .n_consts(n_consts),
        .n_ops(n_ops),
        .n_spr(n_spr),
        .namcpy_armed(namcpy_armed),
        .namcpy_repl(namcpy_repl),
        .namcpy_v64(namcpy_v64),
        .name_rdaddr(name_rdaddr),
        .names_n(names_n),
        .ops_base(ops_base),
        .path_active(path_active),
        .path_kind(path_kind),
        .path_stroke(path_stroke),
        .pc_a1(pc_a1),
        .pc_a2(pc_a2),
        .pc_a3(pc_a3),
        .pc_a4(pc_a4),
        .pc_a5(pc_a5),
        .pc_ccw(pc_ccw),
        .pc_n(pc_n),
        .pc_op(pc_op),
        .pi(pi),
        .repl_did(repl_did),
        .repl_g(repl_g),
        .repl_nlen(repl_nlen),
        .repl_pat0(repl_pat0),
        .repl_pat1(repl_pat1),
        .repl_rch(repl_rch),
        .rh(rh),
        .running(running),
        .rw(rw),
        .rx(rx),
        .ry(ry),
        .saved_sx(saved_sx),
        .saved_sy(saved_sy),
        .saved_tx(saved_tx),
        .saved_ty(saved_ty),
        .sp(sp),
        .spr_hh(spr_hh),
        .spr_nid(spr_nid),
        .spr_ww(spr_ww),
        .sq_i(sq_i),
        .sq_rad(sq_rad),
        .sq_rem(sq_rem),
        .sq_root(sq_root),
        .state(state),
        .this_ok(this_ok),
        .txt_bn(txt_bn),
        .txt_ph(txt_ph),
        .txt_px(txt_px),
        .txt_py(txt_py),
        .txt_val(txt_val),
        .txt_vt(txt_vt),
        .v64_concat(v64_concat),
        .v64_join(v64_join),
        .v64_repl(v64_repl),
        .v64_sqrt(v64_sqrt),
        .valloc_arr_n(valloc_arr_n),
        .valloc_bind(valloc_bind),
        .valloc_bind_src(valloc_bind_src),
        .valloc_bind_this(valloc_bind_this),
        .valloc_fn_a1(valloc_fn_a1),
        .valloc_fn_entry(valloc_fn_entry),
        .valloc_i(valloc_i),
        .valloc_kind(valloc_kind),
        .valloc_metrics(valloc_metrics),
        .valloc_now_fn(valloc_now_fn),
        .valloc_proto(valloc_proto),
        .valloc_proto_fn(valloc_proto_fn),
        .valloc_regex(valloc_regex),
        .valloc_regex_pack(valloc_regex_pack),
        .valloc_retried(valloc_retried),
        .var_this(var_this),
        .varr_next(varr_next),
        .vcall_argc(vcall_argc),
        .vcall_ctor_val(vcall_ctor_val),
        .vcall_entry(vcall_entry),
        .vcall_set_this(vcall_set_this),
        .vcall_this(vcall_this),
        .vcall_value(vcall_value),
        .vconsole_n(vconsole_n),
        .vcsp(vcsp),
        .vdiv_count(vdiv_count),
        .vdiv_den(vdiv_den),
        .vdiv_exp(vdiv_exp),
        .vdiv_num(vdiv_num),
        .vdiv_quot(vdiv_quot),
        .vdiv_rem(vdiv_rem),
        .vdiv_sign(vdiv_sign),
        .vdraw_color(vdraw_color),
        .vdraw_h(vdraw_h),
        .vdraw_i(vdraw_i),
        .vdraw_w(vdraw_w),
        .vdraw_x(vdraw_x),
        .vdraw_y(vdraw_y),
        .venv(venv),
        .venv_next(venv_next),
        .vfe_arr(vfe_arr),
        .vfe_arr_s(vfe_arr_s),
        .vfe_base(vfe_base),
        .vfe_base_s(vfe_base_s),
        .vfe_fn(vfe_fn),
        .vfe_fn_s(vfe_fn_s),
        .vfe_i(vfe_i),
        .vfe_i_s(vfe_i_s),
        .vfe_map(vfe_map),
        .vfe_map_s(vfe_map_s),
        .vfe_mode(vfe_mode),
        .vfe_mode_s(vfe_mode_s),
        .vfe_ret(vfe_ret),
        .vfe_ret_s(vfe_ret_s),
        .vfe_sp(vfe_sp),
        .vfn_next(vfn_next),
        .vframe_no(vframe_no),
        .vfree_armed(vfree_armed),
        .vfree_arr_long(vfree_arr_long),
        .vfree_ok(vfree_ok),
        .vgc_clear_i(vgc_clear_i),
        .vgc_halt_after(vgc_halt_after),
        .vgc_qr(vgc_qr),
        .vgc_qw(vgc_qw),
        .vgc_resume(vgc_resume),
        .vgc_wait_after(vgc_wait_after),
        .vjs_rd_arm(vjs_rd_arm),
        .vjs_val(vjs_val),
        .vlistener_ev(vlistener_ev),
        .vlistener_fn(vlistener_fn),
        .vlistener_n(vlistener_n),
        .vmetrics(vmetrics),
        .vmetrics_w(vmetrics_w),
        .vmod_count(vmod_count),
        .vmod_den(vmod_den),
        .vmod_exp(vmod_exp),
        .vmod_rem(vmod_rem),
        .vmod_sign(vmod_sign),
        .vnat_base(vnat_base),
        .vnat_dom(vnat_dom),
        .vobj_next(vobj_next),
        .vprom_copy(vprom_copy),
        .vprom_done(vprom_done),
        .vprom_ret(vprom_ret),
        .vraf(vraf),
        .vraf_n(vraf_n),
        .vrng(vrng),
        .vsp(vsp),
        .vst_hold_win(vst_hold_win),
        .vst_refill_arm(vst_refill_arm),
        .vst_refill_i(vst_refill_i),
        .vst_refill_ret(vst_refill_ret),
        .vst_waddr(vst_waddr),
        .vst_wdata(vst_wdata),
        .vst_we(vst_we),
        .vst_win(vst_win),
        .vst_peek(vst_peek),
        .vthis(vthis),
        .vtimer_due(vtimer_due),
        .vtimer_fn(vtimer_fn),
        .vtimer_id(vtimer_id),
        .vtimer_n(vtimer_n),
        .vtimer_period(vtimer_period),
        .vtimer_seq(vtimer_seq),
        .vtimer_valid(vtimer_valid),
        .x(x),
        .y(y),
        .aset_win_retried_n(e64_aset_win_retried_n),
        .bind_argc_n(e64_bind_argc_n),
        .bind_base_n(e64_bind_base_n),
        .bind_ip_n(e64_bind_ip_n),
        .bind_k_n(e64_bind_k_n),
        .bind_mode_n(e64_bind_mode_n),
        .bind_n_n(e64_bind_n_n),
        .bind_rd_arm_n(e64_bind_rd_arm_n),
        .bind_ret_n(e64_bind_ret_n),
        .bind_src_n(e64_bind_src_n),
        .bind_vsp_next_n(e64_bind_vsp_next_n),
        .blit_sh_n(e64_blit_sh_n),
        .blit_si_n(e64_blit_si_n),
        .blit_sw_n(e64_blit_sw_n),
        .blit_sx_n(e64_blit_sx_n),
        .blit_sy_n(e64_blit_sy_n),
        .cc_at_n(e64_cc_at_n),
        .cc_av_n(e64_cc_av_n),
        .cc_bok_n(e64_cc_bok_n),
        .cc_bt_n(e64_cc_bt_n),
        .cc_bv_n(e64_cc_bv_n),
        .cc_d_n(e64_cc_d_n),
        .cc_h_n(e64_cc_h_n),
        .cc_len_n(e64_cc_len_n),
        .cc_second_n(e64_cc_second_n),
        .cc_st_n(e64_cc_st_n),
        .code_raddr_n(e64_code_raddr_n),
        .color_n(e64_color_n),
        .ctx_align_n(e64_ctx_align_n),
        .ctx_smooth_n(e64_ctx_smooth_n),
        .ctx_sx_n(e64_ctx_sx_n),
        .ctx_sy_n(e64_ctx_sy_n),
        .ctx_tx_n(e64_ctx_tx_n),
        .ctx_ty_n(e64_ctx_ty_n),
        .dbg_di_hit_n(e64_dbg_di_hit_n),
        .dbg_di_miss_n(e64_dbg_di_miss_n),
        .dbg_div_n_n(e64_dbg_div_n_n),
        .dbg_json_ovf_n(e64_dbg_json_ovf_n),
        .dbg_path_ovf_n(e64_dbg_path_ovf_n),
        .fault_code_n(e64_fault_code_n),
        .fb_dump_addr_n(e64_fb_dump_addr_n),
        .fb_dump_sel_n(e64_fb_dump_sel_n),
        .fb_swap_n(e64_fb_swap_n),
        .fill_style_i_n(e64_fill_style_i_n),
        .stroke_style_i_n(e64_stroke_style_i_n),
        .hp_aid_n(e64_hp_aid_n),
        .hp_alen_n(e64_hp_alen_n),
        .hp_aslot_n(e64_hp_aslot_n),
        .hp_cmd_n(e64_hp_cmd_n),
        .hp_eid_n(e64_hp_eid_n),
        .hp_env_n(e64_hp_env_n),
        .hp_from_stack_n(e64_hp_from_stack_n),
        .hp_hit_n(e64_hp_hit_n),
        .hp_key_n(e64_hp_key_n),
        .hp_len_n(e64_hp_len_n),
        .hp_lim_n(e64_hp_lim_n),
        .hp_make_arr_n(e64_hp_make_arr_n),
        .hp_nat_n(e64_hp_nat_n),
        .hp_oid_n(e64_hp_oid_n),
        .hp_phase_n(e64_hp_phase_n),
        .hp_proto_n(e64_hp_proto_n),
        .hp_qi_n(e64_hp_qi_n),
        .hp_qn_n(e64_hp_qn_n),
        .hp_ret_n(e64_hp_ret_n),
        .hp_rval_n(e64_hp_rval_n),
        .hp_si_n(e64_hp_si_n),
        .hp_slot_n(e64_hp_slot_n),
        .hp_spr_h_n(e64_hp_spr_h_n),
        .hp_spr_w_n(e64_hp_spr_w_n),
        .hp_ss_n(e64_hp_ss_n),
        .hp_tag_n(e64_hp_tag_n),
        .hp_tn_n(e64_hp_tn_n),
        .hp_v64_n(e64_hp_v64_n),
        .hp_vbase_n(e64_hp_vbase_n),
        .hp_wval_n(e64_hp_wval_n),
        .imgd_armed_n(e64_imgd_armed_n),
        .imgd_h_n(e64_imgd_h_n),
        .imgd_i_n(e64_imgd_i_n),
        .imgd_n_n(e64_imgd_n_n),
        .imgd_v64_n(e64_imgd_v64_n),
        .imgd_w_n(e64_imgd_w_n),
        .imgd_x_n(e64_imgd_x_n),
        .imgd_x0_n(e64_imgd_x0_n),
        .imgd_y_n(e64_imgd_y_n),
        .imgd_y0_n(e64_imgd_y0_n),
        .ip_n(e64_ip_n),
        .jn_arr_n(e64_jn_arr_n),
        .jn_h_n(e64_jn_h_n),
        .jn_i_n(e64_jn_i_n),
        .jn_res_n(e64_jn_res_n),
        .js_sp_n(e64_js_sp_n),
        .json_pph_n(e64_json_pph_n),
        .json_rp_n(e64_json_rp_n),
        .json_src_n(e64_json_src_n),
        .json_srclen_n(e64_json_srclen_n),
        .json_wp_n(e64_json_wp_n),
        .looping_n(e64_looping_n),
        .machine_fault_n(e64_machine_fault_n),
        .minmax_acc_n(e64_minmax_acc_n),
        .minmax_base_n(e64_minmax_base_n),
        .minmax_is_min_n(e64_minmax_is_min_n),
        .minmax_k_n(e64_minmax_k_n),
        .minmax_n_n(e64_minmax_n_n),
        .namcpy_armed_n(e64_namcpy_armed_n),
        .namcpy_repl_n(e64_namcpy_repl_n),
        .namcpy_v64_n(e64_namcpy_v64_n),
        .name_rdaddr_n(e64_name_rdaddr_n),
        .path_active_n(e64_path_active_n),
        .path_kind_n(e64_path_kind_n),
        .path_stroke_n(e64_path_stroke_n),
        .pc_n_n(e64_pc_n_n),
        .pi_n(e64_pi_n),
        .repl_did_n(e64_repl_did_n),
        .repl_g_n(e64_repl_g_n),
        .repl_nlen_n(e64_repl_nlen_n),
        .repl_pat0_n(e64_repl_pat0_n),
        .repl_pat1_n(e64_repl_pat1_n),
        .repl_rch_n(e64_repl_rch_n),
        .rh_n(e64_rh_n),
        .running_n(e64_running_n),
        .rw_n(e64_rw_n),
        .rx_n(e64_rx_n),
        .ry_n(e64_ry_n),
        .saved_sx_n(e64_saved_sx_n),
        .saved_sy_n(e64_saved_sy_n),
        .saved_tx_n(e64_saved_tx_n),
        .saved_ty_n(e64_saved_ty_n),
        .sq_i_n(e64_sq_i_n),
        .sq_rad_n(e64_sq_rad_n),
        .sq_rem_n(e64_sq_rem_n),
        .sq_root_n(e64_sq_root_n),
        .state_n(e64_state_n),
        .txt_bn_n(e64_txt_bn_n),
        .txt_ph_n(e64_txt_ph_n),
        .txt_px_n(e64_txt_px_n),
        .txt_py_n(e64_txt_py_n),
        .txt_val_n(e64_txt_val_n),
        .txt_vt_n(e64_txt_vt_n),
        .v64_concat_n(e64_v64_concat_n),
        .v64_join_n(e64_v64_join_n),
        .v64_repl_n(e64_v64_repl_n),
        .v64_sqrt_n(e64_v64_sqrt_n),
        .valloc_arr_n_n(e64_valloc_arr_n_n),
        .valloc_bind_n(e64_valloc_bind_n),
        .valloc_bind_src_n(e64_valloc_bind_src_n),
        .valloc_bind_this_n(e64_valloc_bind_this_n),
        .valloc_fn_a1_n(e64_valloc_fn_a1_n),
        .valloc_fn_entry_n(e64_valloc_fn_entry_n),
        .valloc_i_n(e64_valloc_i_n),
        .valloc_kind_n(e64_valloc_kind_n),
        .valloc_metrics_n(e64_valloc_metrics_n),
        .valloc_now_fn_n(e64_valloc_now_fn_n),
        .valloc_proto_n(e64_valloc_proto_n),
        .valloc_proto_fn_n(e64_valloc_proto_fn_n),
        .valloc_regex_n(e64_valloc_regex_n),
        .valloc_regex_pack_n(e64_valloc_regex_pack_n),
        .valloc_retried_n(e64_valloc_retried_n),
        .varr_next_n(e64_varr_next_n),
        .vcall_argc_n(e64_vcall_argc_n),
        .vcall_ctor_val_n(e64_vcall_ctor_val_n),
        .vcall_entry_n(e64_vcall_entry_n),
        .vcall_set_this_n(e64_vcall_set_this_n),
        .vcall_this_n(e64_vcall_this_n),
        .vcall_value_n(e64_vcall_value_n),
        .vconsole_n_n(e64_vconsole_n_n),
        .vcsp_n(e64_vcsp_n),
        .vdiv_count_n(e64_vdiv_count_n),
        .vdiv_den_n(e64_vdiv_den_n),
        .vdiv_exp_n(e64_vdiv_exp_n),
        .vdiv_num_n(e64_vdiv_num_n),
        .vdiv_quot_n(e64_vdiv_quot_n),
        .vdiv_rem_n(e64_vdiv_rem_n),
        .vdiv_sign_n(e64_vdiv_sign_n),
        .vdraw_color_n(e64_vdraw_color_n),
        .vdraw_h_n(e64_vdraw_h_n),
        .vdraw_i_n(e64_vdraw_i_n),
        .vdraw_w_n(e64_vdraw_w_n),
        .vdraw_x_n(e64_vdraw_x_n),
        .vdraw_y_n(e64_vdraw_y_n),
        .venv_n(e64_venv_n),
        .venv_next_n(e64_venv_next_n),
        .vfe_arr_n(e64_vfe_arr_n),
        .vfe_base_n(e64_vfe_base_n),
        .vfe_fn_n(e64_vfe_fn_n),
        .vfe_i_n(e64_vfe_i_n),
        .vfe_map_n(e64_vfe_map_n),
        .vfe_mode_n(e64_vfe_mode_n),
        .vfe_ret_n(e64_vfe_ret_n),
        .vfe_sp_n(e64_vfe_sp_n),
        .vfree_armed_n(e64_vfree_armed_n),
        .vfree_arr_long_n(e64_vfree_arr_long_n),
        .vgc_clear_i_n(e64_vgc_clear_i_n),
        .vgc_halt_after_n(e64_vgc_halt_after_n),
        .vgc_qr_n(e64_vgc_qr_n),
        .vgc_qw_n(e64_vgc_qw_n),
        .vgc_resume_n(e64_vgc_resume_n),
        .vgc_wait_after_n(e64_vgc_wait_after_n),
        .vjs_rd_arm_n(e64_vjs_rd_arm_n),
        .vlistener_n_n(e64_vlistener_n_n),
        .vmetrics_w_n(e64_vmetrics_w_n),
        .vmod_count_n(e64_vmod_count_n),
        .vmod_den_n(e64_vmod_den_n),
        .vmod_exp_n(e64_vmod_exp_n),
        .vmod_rem_n(e64_vmod_rem_n),
        .vmod_sign_n(e64_vmod_sign_n),
        .vnat_base_n(e64_vnat_base_n),
        .vnat_dom_n(e64_vnat_dom_n),
        .vprom_copy_n(e64_vprom_copy_n),
        .vprom_done_n(e64_vprom_done_n),
        .vprom_ret_n(e64_vprom_ret_n),
        .vraf_n_n(e64_vraf_n_n),
        .vrng_n(e64_vrng_n),
        .vsp_n(e64_vsp_n),
        .vst_hold_win_n(e64_vst_hold_win_n),
        .vst_refill_arm_n(e64_vst_refill_arm_n),
        .vst_refill_i_n(e64_vst_refill_i_n),
        .vst_refill_ret_n(e64_vst_refill_ret_n),
        .vst_waddr_n(e64_vst_waddr_n),
        .vst_wdata_n(e64_vst_wdata_n),
        .vst_we_n(e64_vst_we_n),
        .vthis_n(e64_vthis_n),
        .vtimer_n_n(e64_vtimer_n_n),
        .vtimer_seq_n(e64_vtimer_seq_n),
        .x_n(e64_x_n),
        .y_n(e64_y_n),
        .hp_qk_n(e64_hp_qk_n),
        .hp_qt_n(e64_hp_qt_n),
        .hp_qv_n(e64_hp_qv_n),
        .js_i_n(e64_js_i_n),
        .js_ph_n(e64_js_ph_n),
        .pc_a1_n(e64_pc_a1_n),
        .pc_a2_n(e64_pc_a2_n),
        .pc_a3_n(e64_pc_a3_n),
        .pc_a4_n(e64_pc_a4_n),
        .pc_a5_n(e64_pc_a5_n),
        .pc_ccw_n(e64_pc_ccw_n),
        .pc_op_n(e64_pc_op_n),
        .vfe_arr_s_n(e64_vfe_arr_s_n),
        .vfe_base_s_n(e64_vfe_base_s_n),
        .vfe_fn_s_n(e64_vfe_fn_s_n),
        .vfe_i_s_n(e64_vfe_i_s_n),
        .vfe_map_s_n(e64_vfe_map_s_n),
        .vfe_mode_s_n(e64_vfe_mode_s_n),
        .vfe_ret_s_n(e64_vfe_ret_s_n),
        .vjs_val_n(e64_vjs_val_n),
        .vlistener_ev_n(e64_vlistener_ev_n),
        .vlistener_fn_n(e64_vlistener_fn_n),
        .vraf_arr_n(e64_vraf_n),
        .vst_win_n(e64_vst_win_n),
        .vtimer_due_n(e64_vtimer_due_n),
        .vtimer_fn_n(e64_vtimer_fn_n),
        .vtimer_id_n(e64_vtimer_id_n),
        .vtimer_period_n(e64_vtimer_period_n),
        .vtimer_valid_n(e64_vtimer_valid_n),
        .json_mem_we(e64_json_mem_we),
        .json_mem_waddr(e64_json_mem_waddr),
        .json_mem_wdata(e64_json_mem_wdata),
        .varr_len_we(e64_varr_len_we),
        .varr_len_waddr(e64_varr_len_waddr),
        .varr_len_wdata(e64_varr_len_wdata),
        .varr_lidx_we(e64_varr_lidx_we),
        .varr_lidx_waddr(e64_varr_lidx_waddr),
        .varr_lidx_wdata(e64_varr_lidx_wdata),
        .varr_long_we(e64_varr_long_we),
        .varr_long_waddr(e64_varr_long_waddr),
        .varr_long_wdata(e64_varr_long_wdata),
        .varr_valid_we(e64_varr_valid_we),
        .varr_valid_waddr(e64_varr_valid_waddr),
        .varr_valid_wdata(e64_varr_valid_wdata),
        .venv_gen_we(e64_venv_gen_we),
        .venv_gen_waddr(e64_venv_gen_waddr),
        .venv_gen_wdata(e64_venv_gen_wdata),
        .venv_len_we(e64_venv_len_we),
        .venv_len_waddr(e64_venv_len_waddr),
        .venv_len_wdata(e64_venv_len_wdata),
        .venv_valid_we(e64_venv_valid_we),
        .venv_valid_waddr(e64_venv_valid_waddr),
        .venv_valid_wdata(e64_venv_valid_wdata),
        .vobj_cls_we(e64_vobj_cls_we),
        .vobj_cls_waddr(e64_vobj_cls_waddr),
        .vobj_cls_wdata(e64_vobj_cls_wdata),
        .vvar_valid_we(e64_vvar_valid_we),
        .vvar_valid_waddr(e64_vvar_valid_waddr),
        .vvar_valid_wdata(e64_vvar_valid_wdata),
        .vvars_we(e64_vvars_we),
        .vvars_waddr(e64_vvars_waddr),
        .vvars_wdata(e64_vvars_wdata),
        .vframe_we(e64_vframe_we),
        .vframe_waddr(e64_vframe_waddr),
        .vframe_rip_wdata(e64_vframe_rip_wdata),
        .vframe_bsp_wdata(e64_vframe_bsp_wdata),
        .vframe_esc_wdata(e64_vframe_esc_wdata),
        .vframe_this_wdata(e64_vframe_this_wdata),
        .vframe_env_wdata(e64_vframe_env_wdata),
        .vframe_fn_wdata(e64_vframe_fn_wdata),
        .vframe_ctor_wdata(e64_vframe_ctor_wdata)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            running <= 1'b0;
            looping <= 1'b0;
            fb_we <= 1'b0; fb_swap <= 1'b0;
            did_swap <= 1'b0; present_pend <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0;
            fb_dump_addr <= '0; fb_dump_sel <= 1'b0;
            sp <= '0; ip <= '0;
            vsp <= '0; vcsp <= '0; vconst_lo <= '0;
            vsp_d <= '0;
            vst_we <= 1'b0;
            vst_waddr <= '0;
            vst_wdata <= '0;
            vst_hold_win <= 1'b0;
            vst_refill_i <= 4'd0;
            vst_refill_arm <= 1'b0;
            vst_refill_ret <= S_IDLE;
            aset_win_retried <= 1'b0;
            vfree_armed <= 1'b0;
            vfree_ok <= 1'b0;
            vfree_arr_long <= 1'b0;
            vprom_done <= 1'b0;
            vprom_copy <= 1'b0;
            hp_prom_wr <= 1'b0;
            hp_prom_phys <= 8'd0;
            vprom_ret <= S_IDLE;
            rel_saved <= '0; rel_lim <= '0; rel_i <= '0; rel_nn <= '0;
            rel_ret <= S_IDLE;
            bind_mode <= 2'd0;
            bind_k <= '0; bind_n <= '0; bind_argc <= '0;
            bind_base <= '0; bind_src <= '0; bind_vsp_next <= '0;
            bind_ip <= '0; bind_ins <= V64_UNDEFINED;
            bind_ret <= S_IDLE;
            bind_armed <= 1'b0; bind_rd_arm <= 1'b0;
            minmax_is_min <= 1'b0;
            minmax_k <= '0; minmax_n <= '0;
            minmax_base <= '0; minmax_acc <= V64_UNDEFINED;
            vdiv_num <= '0; vdiv_quot <= '0; vdiv_rem <= '0;
            vdiv_den <= '0; vdiv_count <= '0; vdiv_exp <= '0;
            vdiv_sign <= 1'b0;
            vmod_rem <= '0; vmod_den <= '0; vmod_count <= '0;
            vmod_exp <= '0; vmod_sign <= 1'b0;
            vgc_qr <= '0; vgc_qw <= '0; vgc_clear_i <= '0;
            vgc_obj_i <= '0; vgc_arr_i <= '0; vgc_slot_i <= '0;
            vgc_cur <= '0; vgc_root_i <= '0; valloc_i <= '0;
            vobj_next <= '0; varr_next <= '0; vfn_next <= '0;
            venv_next <= '0; valloc_kind <= 2'd0;
            valloc_retried <= 1'b0;
            vgc_halt_after <= 1'b0;
            vgc_env_i <= '0; vgc_root_phase <= '0;
            vcall_value <= 1'b0; vcall_entry <= '0; vcall_argc <= '0;
            vcall_set_this <= 1'b0;
            vcall_this <= V64_UNDEFINED;
            vcall_ctor_val <= V64_UNDEFINED;
            imgd_v64 <= 1'b0;
            vthis <= V64_UNDEFINED; venv <= V64_UNDEFINED;
            vraf_n <= '0; vraf_snap_n <= '0; vraf_i <= '0;
            vtimer_n <= '0; vframe_no <= '0; vtimer_seq <= 32'd1;
            vrng <= 32'h6d2b79f5; vconsole_n <= '0;
            vtimer_pick <= '0; vcallback_raf <= 1'b0;
            vcallback_timer <= 1'b0; vgc_wait_after <= 1'b0;
            vgc_resume <= 2'd0;
            vnat_base <= '0; vdraw_i <= '0;
            vdraw_cx <= '0; vdraw_cy <= '0;
            vnat_dom <= 3'd0; vnat_style <= V64_UNDEFINED;
            vmetrics <= V64_UNDEFINED;
            valloc_metrics <= 1'b0;
            vmetrics_w <= 16'd0;
            vkev_event <= V64_UNDEFINED; vlistener_n <= 5'd0;
            vkey_li <= 5'd0;
            v64_frame_armed <= 1'b0;
            vcallback_key <= 1'b0; vcallback_fe <= 1'b0;
            vfe_arr <= V64_UNDEFINED; vfe_fn <= V64_UNDEFINED;
            vfe_i <= 8'd0; vfe_ret <= 16'd0; vfe_base <= '0; vfe_sp <= 4'd0;
            vfe_mode <= 2'd0;
            vfe_map <= V64_UNDEFINED;
            valloc_now_fn <= 1'b0;
            valloc_regex <= 1'b0;
            valloc_regex_pack <= 32'd0;
            valloc_arr_n <= 8'd0;
            valloc_fn_entry <= 16'd0;
            valloc_fn_a1 <= 8'd0;
            valloc_proto <= 1'b0;
            valloc_proto_fn <= 13'd0;
            valloc_bind <= 1'b0;
            valloc_bind_src <= 13'd0;
            valloc_bind_this <= V64_UNDEFINED;
            vctor_scan <= '0;
            vctor_armed <= 1'b0;
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;
            e32_p_clr <= 1'b0;
            e32_p_we <= 1'b0;
            hp_env <= 1'b0; hp_eid <= '0;
            hp_slot <= '0; hp_aslot <= '0; hp_len <= '0; hp_alen <= '0;
            hp_lim <= '0; hp_key <= '0; hp_wval <= '0; hp_rval <= '0;
            hp_hit <= 1'b0; hp_phase <= '0; hp_qn <= '0; hp_qi <= '0;
            hp_tag <= 3'd0; vgc_rd_arm <= 1'b0; jn_rd_arm <= 1'b0;
            vfe_rd_arm <= 1'b0; vjs_rd_arm <= 1'b0;
            hp_from_stack <= 1'b0; hp_make_arr <= 1'b0; hp_vbase <= '0;
            hp_spr_w <= '0; hp_spr_h <= '0; hp_nat <= 4'd0;
            n_ops <= '0; n_consts <= '0; ops_base <= '0;
            code_raddr <= '0;
            nat_id <= '0; nat_argc <= '0;
            c_i <= '0;
            gc_qr <= '0; gc_qw <= '0; gc_i <= '0; gc_root_i <= '0;
            gc_slot <= '0; gc_cur <= '0;
            gc_obj_high <= '0; gc_arr_high <= '0; dbg_gc_n <= '0;
            dbg_stack_ovf <= '0; dbg_call_ovf <= '0;
            machine_fault <= 1'b0; fault_code <= 8'd0;
            prev_joy <= 6'd0; joy_down_edge <= 6'd0; joy_up_edge <= 6'd0;
            sram_req <= 1'b0; sram_addr <= '0; blit_wait <= 1'b0;
            aset_mode <= 1'b0; sprd_mode <= 1'b0; hdr_w <= 16'd3;
            boot_clr <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            fb_swap <= 1'b0;
            vst_we <= 1'b0;
            // TOS window follows last cycle's write + this cycle's vsp
            // (already NBA-updated from the previous op). S_V64_BIND holds
            // the window; skip one cycle after it so vsp_d can catch up.
            // Do not skip vst_we on that release cycle — GET_PROP x then
            // SET_PROP x ({x:current.x}) stored leftover NaN while the
            // object still had x=12 (PACMAN ARRAY_SET 241, change=1 wrap).
            if (vst_hold_win) begin
                if (state != S_V64_BIND && state != S_V64_WIN_FILL) begin
                    if (vst_we) begin
                        integer d;
                        d = integer'(vsp) - 1 - integer'(vst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= vst_wdata;
                    end
                    vst_hold_win <= 1'b0;
                end
            end else if (vsp > vsp_d) begin
                    vst_win[15] <= vst_win[14];
                    vst_win[14] <= vst_win[13];
                    vst_win[13] <= vst_win[12];
                    vst_win[12] <= vst_win[11];
                    vst_win[11] <= vst_win[10];
                    vst_win[10] <= vst_win[9];
                    vst_win[9] <= vst_win[8];
                    vst_win[8] <= vst_win[7];
                    vst_win[7] <= vst_win[6];
                    vst_win[6] <= vst_win[5];
                    vst_win[5] <= vst_win[4];
                    vst_win[4] <= vst_win[3];
                    vst_win[3] <= vst_win[2];
                    vst_win[2] <= vst_win[1];
                    vst_win[1] <= vst_win[0];
                    vst_win[0] <= vst_wdata;
                end else if (vsp < vsp_d) begin
                    begin
                        integer sh, wi;
                        sh = integer'(vsp_d) - integer'(vsp);
                        if (vst_we && vst_waddr == (vsp - 12'd1))
                            vst_win[0] <= vst_wdata;
                        else if (sh < 16)
                            vst_win[0] <= vst_win[sh[3:0]];
                        for (wi = 1; wi < 16; wi++)
                            if (wi + sh < 16)
                                vst_win[wi] <= vst_win[wi[3:0] + sh[3:0]];
                    end
                end else if (vst_we) begin
                    begin
                        integer d;
                        d = integer'(vsp) - 1 - integer'(vst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= vst_wdata;
                    end
                end
            vsp_d <= vsp;
            // Exec-owned copies: default no poke; states below may pulse.
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;
            e32_p_clr <= 1'b0;
            e32_p_we <= 1'b0;
            // NEW: registered name_mem read — BRAM, so str[i] costs one cycle
            // (S_STRIDX) instead of a 32 KB combinational mux
            name_rdata <= name_mem[name_rdaddr[14:0]];
            // NEW: registered glyph fetch — one row of one character per cycle
            font_rdata <= font_rom[font_raddr];
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
            end else if ((state == S_EXEC) || (state == S_NAT)) begin
                alu_a <= e32_alu_a_n;
                alu_b <= e32_alu_b_n;
                alu_fx <= e32_alu_fx_n;
                alu_op <= e32_alu_op_n;
                blit_sh <= e32_blit_sh_n;
                blit_si <= e32_blit_si_n;
                blit_sw <= e32_blit_sw_n;
                blit_sx <= e32_blit_sx_n;
                blit_sy <= e32_blit_sy_n;
                cc_at <= e32_cc_at_n;
                cc_av <= e32_cc_av_n;
                cc_bok <= e32_cc_bok_n;
                cc_bt <= e32_cc_bt_n;
                cc_bv <= e32_cc_bv_n;
                cc_d <= e32_cc_d_n;
                cc_h <= e32_cc_h_n;
                cc_len <= e32_cc_len_n;
                cc_second <= e32_cc_second_n;
                cc_st <= e32_cc_st_n;
                click_fired <= e32_click_fired_n;
                click_fn <= e32_click_fn_n;
                clr_idx <= e32_clr_idx_n;
                code_raddr <= e32_code_raddr_n;
                color <= e32_color_n;
                csp <= e32_csp_n;
                ctx_align <= e32_ctx_align_n;
                ctx_font_px <= e32_ctx_font_px_n;
                ctx_smooth <= e32_ctx_smooth_n;
                ctx_sx <= e32_ctx_sx_n;
                ctx_sy <= e32_ctx_sy_n;
                ctx_tx <= e32_ctx_tx_n;
                ctx_ty <= e32_ctx_ty_n;
                dbg_call_ovf <= e32_dbg_call_ovf_n;
                dbg_cb_ip <= e32_dbg_cb_ip_n;
                dbg_di_hit <= e32_dbg_di_hit_n;
                dbg_di_miss <= e32_dbg_di_miss_n;
                dbg_div_n <= e32_dbg_div_n_n;
                dbg_find_hit <= e32_dbg_find_hit_n;
                dbg_heap_ovf <= e32_dbg_heap_ovf_n;
                dbg_json_ovf <= e32_dbg_json_ovf_n;
                dbg_path_ovf <= e32_dbg_path_ovf_n;
                dbg_splice_n <= e32_dbg_splice_n_n;
                dbg_stack_ovf <= e32_dbg_stack_ovf_n;
                dbg_tmr_sched <= e32_dbg_tmr_sched_n;
                dbg_to_ovf <= e32_dbg_to_ovf_n;
                did_swap <= e32_did_swap_n;
                div_cnt <= e32_div_cnt_n;
                div_int_in <= e32_div_int_in_n;
                div_neg <= e32_div_neg_n;
                div_rem <= e32_div_rem_n;
                div_ub <= e32_div_ub_n;
                div_uq <= e32_div_uq_n;
                env_free_n <= e32_env_free_n_n;
                env_is_store <= e32_env_is_store_n;
                env_ld_slot <= e32_env_ld_slot_n;
                env_sp <= e32_env_sp_n;
                env_walk <= e32_env_walk_n;
                fb_dump_addr <= e32_fb_dump_addr_n;
                fb_dump_sel <= e32_fb_dump_sel_n;
                fb_swap <= e32_fb_swap_n;
                fill_style_i <= e32_fill_style_i_n;
                fp_left <= e32_fp_left_n;
                fpx_acc <= e32_fpx_acc_n;
                frame_fire <= e32_frame_fire_n;
                hp_aid <= e32_hp_aid_n;
                hp_alen <= e32_hp_alen_n;
                hp_aslot <= e32_hp_aslot_n;
                hp_cmd <= e32_hp_cmd_n;
                hp_from_stack <= e32_hp_from_stack_n;
                hp_hit <= e32_hp_hit_n;
                hp_key <= e32_hp_key_n;
                hp_len <= e32_hp_len_n;
                hp_lim <= e32_hp_lim_n;
                hp_make_arr <= e32_hp_make_arr_n;
                hp_nat <= e32_hp_nat_n;
                hp_oid <= e32_hp_oid_n;
                hp_phase <= e32_hp_phase_n;
                hp_proto <= e32_hp_proto_n;
                hp_qi <= e32_hp_qi_n;
                hp_qn <= e32_hp_qn_n;
                hp_ret <= st_t'(e32_hp_ret_n);
                hp_rval <= e32_hp_rval_n;
                hp_si <= e32_hp_si_n;
                hp_slot <= e32_hp_slot_n;
                hp_ss <= e32_hp_ss_n;
                hp_tag <= e32_hp_tag_n;
                hp_tn <= e32_hp_tn_n;
                hp_v64 <= e32_hp_v64_n;
                hp_vbase <= e32_hp_vbase_n;
                hp_wval <= e32_hp_wval_n;
                idx_needle <= e32_idx_needle_n;
                idx_t <= e32_idx_t_n;
                idx_v <= e32_idx_v_n;
                imgd_armed <= e32_imgd_armed_n;
                imgd_h <= e32_imgd_h_n;
                imgd_i <= e32_imgd_i_n;
                imgd_n <= e32_imgd_n_n;
                imgd_res <= e32_imgd_res_n;
                imgd_w <= e32_imgd_w_n;
                imgd_x <= e32_imgd_x_n;
                imgd_x0 <= e32_imgd_x0_n;
                imgd_y <= e32_imgd_y_n;
                imgd_y0 <= e32_imgd_y0_n;
                ip <= e32_ip_n;
                jn_arr <= e32_jn_arr_n;
                jn_h <= e32_jn_h_n;
                jn_i <= e32_jn_i_n;
                jn_res <= e32_jn_res_n;
                js_sp <= e32_js_sp_n;
                json_dst <= e32_json_dst_n;
                json_pph <= e32_json_pph_n;
                json_res <= e32_json_res_n;
                json_rp <= e32_json_rp_n;
                json_src <= e32_json_src_n;
                json_srclen <= e32_json_srclen_n;
                json_wp <= e32_json_wp_n;
                kd_n <= e32_kd_n_n;
                kev_fn <= e32_kev_fn_n;
                kev_is_down <= e32_kev_is_down_n;
                kev_li <= e32_kev_li_n;
                kev_obj <= e32_kev_obj_n;
                kev_ret_ip <= e32_kev_ret_ip_n;
                keys_a_oid <= e32_keys_a_oid_n;
                keys_d_oid <= e32_keys_d_oid_n;
                keys_sp_oid <= e32_keys_sp_oid_n;
                ku_n <= e32_ku_n_n;
                lfsr <= e32_lfsr_n;
                looping <= e32_looping_n;
                metrics_oid <= e32_metrics_oid_n;
                mul_a <= e32_mul_a_n;
                mul_b <= e32_mul_b_n;
                mul_fx_a <= e32_mul_fx_a_n;
                mul_fx_b <= e32_mul_fx_b_n;
                n_arr <= e32_n_arr_n;
                n_arr_keep <= e32_n_arr_keep_n;
                n_fn_proto <= e32_n_fn_proto_n;
                n_obj <= e32_n_obj_n;
                n_obj_keep <= e32_n_obj_keep_n;
                namcpy_armed <= e32_namcpy_armed_n;
                namcpy_repl <= e32_namcpy_repl_n;
                name_rdaddr <= e32_name_rdaddr_n;
                nat_argc <= e32_nat_argc_n;
                nat_id <= e32_nat_id_n;
                path_active <= e32_path_active_n;
                path_kind <= e32_path_kind_n;
                path_stroke <= e32_path_stroke_n;
                pc_n <= e32_pc_n_n;
                pi <= e32_pi_n;
                present_pend <= e32_present_pend_n;
                raf_n <= e32_raf_n_n;
                rel_i <= e32_rel_i_n;
                rel_lim <= e32_rel_lim_n;
                rel_nn <= e32_rel_nn_n;
                rel_ret <= st_t'(e32_rel_ret_n);
                rel_saved <= e32_rel_saved_n;
                repl_did <= e32_repl_did_n;
                repl_g <= e32_repl_g_n;
                repl_nlen <= e32_repl_nlen_n;
                repl_pat0 <= e32_repl_pat0_n;
                repl_pat1 <= e32_repl_pat1_n;
                repl_rch <= e32_repl_rch_n;
                rh <= e32_rh_n;
                running <= e32_running_n;
                rw <= e32_rw_n;
                rx <= e32_rx_n;
                ry <= e32_ry_n;
                saved_sx <= e32_saved_sx_n;
                saved_sy <= e32_saved_sy_n;
                saved_tx <= e32_saved_tx_n;
                saved_ty <= e32_saved_ty_n;
                sp <= e32_sp_n;
                sq_i <= e32_sq_i_n;
                sq_rad <= e32_sq_rad_n;
                sq_rem <= e32_sq_rem_n;
                sq_root <= e32_sq_root_n;
                state <= st_t'(e32_state_n);
                str_pf_ci <= e32_str_pf_ci_n;
                str_pf_id <= e32_str_pf_id_n;
                str_pf_ok <= e32_str_pf_ok_n;
                str_res <= e32_str_res_n;
                this_obj <= e32_this_obj_n;
                to_n <= e32_to_n_n;
                to_seq <= e32_to_seq_n;
                txt_bn <= e32_txt_bn_n;
                txt_ph <= e32_txt_ph_n;
                txt_px <= e32_txt_px_n;
                txt_py <= e32_txt_py_n;
                txt_rp <= e32_txt_rp_n;
                txt_val <= e32_txt_val_n;
                txt_vt <= e32_txt_vt_n;
                vcall_argc <= e32_vcall_argc_n;
                vcall_this <= e32_vcall_this_n;
                x <= e32_x_n;
                xf_dst <= e32_xf_dst_n;
                xf_h <= e32_xf_h_n;
                xf_w <= e32_xf_w_n;
                xf_x <= e32_xf_x_n;
                xf_y <= e32_xf_y_n;
                y <= e32_y_n;
                cstack_ctorobj <= e32_cstack_ctorobj_n;
                cstack_env <= e32_cstack_env_n;
                cstack_fe_arr <= e32_cstack_fe_arr_n;
                cstack_fe_fn <= e32_cstack_fe_fn_n;
                cstack_fe_i <= e32_cstack_fe_i_n;
                cstack_ip <= e32_cstack_ip_n;
                cstack_isctor <= e32_cstack_isctor_n;
                cstack_isfe <= e32_cstack_isfe_n;
                cstack_map_arr <= e32_cstack_map_arr_n;
                cstack_this <= e32_cstack_this_n;
                fn_proto_ip <= e32_fn_proto_ip_n;
                fn_proto_oid <= e32_fn_proto_oid_n;
                hp_qk <= e32_hp_qk_n;
                hp_qt <= e32_hp_qt_n;
                hp_qv <= e32_hp_qv_n;
                js_i <= e32_js_i_n;
                js_ph <= e32_js_ph_n;
                js_tag <= e32_js_tag_n;
                js_val <= e32_js_val_n;
                kd_slot <= e32_kd_slot_n;
                ku_slot <= e32_ku_slot_n;
                pc_a1 <= e32_pc_a1_n;
                pc_a2 <= e32_pc_a2_n;
                pc_a3 <= e32_pc_a3_n;
                pc_a4 <= e32_pc_a4_n;
                pc_a5 <= e32_pc_a5_n;
                pc_ccw <= e32_pc_ccw_n;
                pc_op <= e32_pc_op_n;
                raf_fn <= e32_raf_fn_n;
                to_delay <= e32_to_delay_n;
                to_fn <= e32_to_fn_n;
                to_id <= e32_to_id_n;
                to_period <= e32_to_period_n;
                if (e32_arr_len_we) arr_len[e32_arr_len_waddr[10:0]] <= e32_arr_len_wdata;
                if (e32_env_cap_we) env_cap[e32_env_cap_waddr[8:0]] <= e32_env_cap_wdata;
                if (e32_env_oid_we) env_oid[e32_env_oid_waddr[8:0]] <= e32_env_oid_wdata;
                if (e32_json_mem_we) json_mem[e32_json_mem_waddr[12:0]] <= e32_json_mem_wdata;
                if (e32_obj_cls_we) obj_cls[e32_obj_cls_waddr[9:0]] <= e32_obj_cls_wdata;
                if (e32_obj_n_we) obj_n[e32_obj_n_waddr[9:0]] <= e32_obj_n_wdata;
                if (e32_stack_we) stack[e32_stack_waddr[10:0]] <= e32_stack_wdata;
                if (e32_stack_tag_we) stack_tag[e32_stack_tag_waddr[10:0]] <= e32_stack_tag_wdata;
                if (e32_tenv_parent_we) tenv_parent[e32_tenv_parent_waddr[9:0]] <= e32_tenv_parent_wdata;
                if (e32_tfn_entry_we) tfn_entry[e32_tfn_entry_waddr[9:0]] <= e32_tfn_entry_wdata;
                if (e32_tfn_has_this_we) tfn_has_this[e32_tfn_has_this_waddr[9:0]] <= e32_tfn_has_this_wdata;
                if (e32_tfn_nparam_we) tfn_nparam[e32_tfn_nparam_waddr[9:0]] <= e32_tfn_nparam_wdata;
                if (e32_tfn_parent_we) tfn_parent[e32_tfn_parent_waddr[9:0]] <= e32_tfn_parent_wdata;
                if (e32_tfn_this_we) tfn_this[e32_tfn_this_waddr[9:0]] <= e32_tfn_this_wdata;
                if (e32_tfn_this_tag_we) tfn_this_tag[e32_tfn_this_tag_waddr[9:0]] <= e32_tfn_this_tag_wdata;
                if (e32_var_init_we) var_init[e32_var_init_waddr[8:0]] <= e32_var_init_wdata;
                if (e32_var_tag_we) var_tag[e32_var_tag_waddr[8:0]] <= e32_var_tag_wdata;
                if (e32_vars_we) vars[e32_vars_waddr[8:0]] <= e32_vars_wdata;
                if (e32_vobj_len_we) vobj_len[e32_vobj_len_waddr[9:0]] <= e32_vobj_len_wdata;
            end else if (state == S_V64_EXEC) begin
                aset_win_retried <= e64_aset_win_retried_n;
                bind_argc <= e64_bind_argc_n;
                bind_base <= e64_bind_base_n;
                bind_ip <= e64_bind_ip_n;
                bind_k <= e64_bind_k_n;
                bind_mode <= e64_bind_mode_n;
                bind_n <= e64_bind_n_n;
                bind_rd_arm <= e64_bind_rd_arm_n;
                bind_ret <= st_t'(e64_bind_ret_n);
                bind_src <= e64_bind_src_n;
                bind_vsp_next <= e64_bind_vsp_next_n;
                blit_sh <= e64_blit_sh_n;
                blit_si <= e64_blit_si_n;
                blit_sw <= e64_blit_sw_n;
                blit_sx <= e64_blit_sx_n;
                blit_sy <= e64_blit_sy_n;
                cc_at <= e64_cc_at_n;
                cc_av <= e64_cc_av_n;
                cc_bok <= e64_cc_bok_n;
                cc_bt <= e64_cc_bt_n;
                cc_bv <= e64_cc_bv_n;
                cc_d <= e64_cc_d_n;
                cc_h <= e64_cc_h_n;
                cc_len <= e64_cc_len_n;
                cc_second <= e64_cc_second_n;
                cc_st <= e64_cc_st_n;
                code_raddr <= e64_code_raddr_n;
                color <= e64_color_n;
                ctx_align <= e64_ctx_align_n;
                ctx_smooth <= e64_ctx_smooth_n;
                ctx_sx <= e64_ctx_sx_n;
                ctx_sy <= e64_ctx_sy_n;
                ctx_tx <= e64_ctx_tx_n;
                ctx_ty <= e64_ctx_ty_n;
                dbg_di_hit <= e64_dbg_di_hit_n;
                dbg_di_miss <= e64_dbg_di_miss_n;
                dbg_div_n <= e64_dbg_div_n_n;
                dbg_json_ovf <= e64_dbg_json_ovf_n;
                dbg_path_ovf <= e64_dbg_path_ovf_n;
                fault_code <= e64_fault_code_n;
                fb_dump_addr <= e64_fb_dump_addr_n;
                fb_dump_sel <= e64_fb_dump_sel_n;
                fb_swap <= e64_fb_swap_n;
                fill_style_i <= e64_fill_style_i_n;
                stroke_style_i <= e64_stroke_style_i_n;
                hp_aid <= e64_hp_aid_n;
                hp_alen <= e64_hp_alen_n;
                hp_aslot <= e64_hp_aslot_n;
                hp_cmd <= e64_hp_cmd_n;
                hp_eid <= e64_hp_eid_n;
                hp_env <= e64_hp_env_n;
                hp_from_stack <= e64_hp_from_stack_n;
                hp_hit <= e64_hp_hit_n;
                hp_key <= e64_hp_key_n;
                hp_len <= e64_hp_len_n;
                // Exec vobj_len/venv_len/varr_len can lag parent HEAP pokes.
                // Scan the parent copy so LOAD_VAR/GET_PROP/ARRAY_GET see live slots.
                if (e64_hp_env_n)
                    hp_len <= {1'b0, venv_len[e64_hp_eid_n]};
                else if (e64_hp_cmd_n == HP_GETPROP ||
                         e64_hp_cmd_n == HP_SETPROP ||
                         e64_hp_cmd_n == HP_LOOKFN)
                    hp_len <= vobj_len[e64_hp_oid_n];
                if (e64_hp_cmd_n == HP_ARRGET || e64_hp_cmd_n == HP_ARRSET ||
                    e64_hp_cmd_n == HP_AGETI || e64_hp_cmd_n == HP_ASETI ||
                    e64_hp_cmd_n == HP_AFILL || e64_hp_cmd_n == HP_PUSH ||
                    e64_hp_cmd_n == HP_UNSHIFT || e64_hp_cmd_n == HP_SPLICE)
                    hp_alen <= varr_len[e64_hp_aid_n];
                hp_lim <= e64_hp_lim_n;
                hp_make_arr <= e64_hp_make_arr_n;
                hp_nat <= e64_hp_nat_n;
                hp_oid <= e64_hp_oid_n;
                hp_phase <= e64_hp_phase_n;
                hp_proto <= e64_hp_proto_n;
                hp_qi <= e64_hp_qi_n;
                hp_qn <= e64_hp_qn_n;
                hp_ret <= st_t'(e64_hp_ret_n);
                hp_rval <= e64_hp_rval_n;
                hp_si <= e64_hp_si_n;
                hp_slot <= e64_hp_slot_n;
                hp_spr_h <= e64_hp_spr_h_n;
                hp_spr_w <= e64_hp_spr_w_n;
                hp_ss <= e64_hp_ss_n;
                hp_tag <= e64_hp_tag_n;
                hp_tn <= e64_hp_tn_n;
                if (e64_hp_cmd_n == HP_ASSIGN)
                    hp_tn <= vobj_len[e64_hp_oid_n];
                hp_v64 <= e64_hp_v64_n;
                hp_vbase <= e64_hp_vbase_n;
                hp_wval <= e64_hp_wval_n;
                imgd_armed <= e64_imgd_armed_n;
                imgd_h <= e64_imgd_h_n;
                imgd_i <= e64_imgd_i_n;
                imgd_n <= e64_imgd_n_n;
                imgd_v64 <= e64_imgd_v64_n;
                imgd_w <= e64_imgd_w_n;
                imgd_x <= e64_imgd_x_n;
                imgd_x0 <= e64_imgd_x0_n;
                imgd_y <= e64_imgd_y_n;
                imgd_y0 <= e64_imgd_y0_n;
                ip <= e64_ip_n;
                jn_arr <= e64_jn_arr_n;
                jn_h <= e64_jn_h_n;
                jn_i <= e64_jn_i_n;
                jn_res <= e64_jn_res_n;
                js_sp <= e64_js_sp_n;
                json_pph <= e64_json_pph_n;
                json_rp <= e64_json_rp_n;
                json_src <= e64_json_src_n;
                json_srclen <= e64_json_srclen_n;
                json_wp <= e64_json_wp_n;
                looping <= e64_looping_n;
                machine_fault <= e64_machine_fault_n;
                minmax_acc <= e64_minmax_acc_n;
                minmax_base <= e64_minmax_base_n;
                minmax_is_min <= e64_minmax_is_min_n;
                minmax_k <= e64_minmax_k_n;
                minmax_n <= e64_minmax_n_n;
                namcpy_armed <= e64_namcpy_armed_n;
                namcpy_repl <= e64_namcpy_repl_n;
                namcpy_v64 <= e64_namcpy_v64_n;
                name_rdaddr <= e64_name_rdaddr_n;
                path_active <= e64_path_active_n;
                path_kind <= e64_path_kind_n;
                path_stroke <= e64_path_stroke_n;
                pc_n <= e64_pc_n_n;
                pi <= e64_pi_n;
                repl_did <= e64_repl_did_n;
                repl_g <= e64_repl_g_n;
                repl_nlen <= e64_repl_nlen_n;
                repl_pat0 <= e64_repl_pat0_n;
                repl_pat1 <= e64_repl_pat1_n;
                repl_rch <= e64_repl_rch_n;
                rh <= e64_rh_n;
                running <= e64_running_n;
                rw <= e64_rw_n;
                rx <= e64_rx_n;
                ry <= e64_ry_n;
                saved_sx <= e64_saved_sx_n;
                saved_sy <= e64_saved_sy_n;
                saved_tx <= e64_saved_tx_n;
                saved_ty <= e64_saved_ty_n;
                sq_i <= e64_sq_i_n;
                sq_rad <= e64_sq_rad_n;
                sq_rem <= e64_sq_rem_n;
                sq_root <= e64_sq_root_n;
                state <= st_t'(e64_state_n);
                txt_bn <= e64_txt_bn_n;
                txt_ph <= e64_txt_ph_n;
                txt_px <= e64_txt_px_n;
                txt_py <= e64_txt_py_n;
                txt_val <= e64_txt_val_n;
                txt_vt <= e64_txt_vt_n;
                v64_concat <= e64_v64_concat_n;
                v64_join <= e64_v64_join_n;
                v64_repl <= e64_v64_repl_n;
                v64_sqrt <= e64_v64_sqrt_n;
                valloc_arr_n <= e64_valloc_arr_n_n;
                valloc_bind <= e64_valloc_bind_n;
                valloc_bind_src <= e64_valloc_bind_src_n;
                valloc_bind_this <= e64_valloc_bind_this_n;
                valloc_fn_a1 <= e64_valloc_fn_a1_n;
                valloc_fn_entry <= e64_valloc_fn_entry_n;
                valloc_i <= e64_valloc_i_n;
                valloc_kind <= e64_valloc_kind_n;
                valloc_metrics <= e64_valloc_metrics_n;
                valloc_now_fn <= e64_valloc_now_fn_n;
                valloc_proto <= e64_valloc_proto_n;
                valloc_proto_fn <= e64_valloc_proto_fn_n;
                valloc_regex <= e64_valloc_regex_n;
                valloc_regex_pack <= e64_valloc_regex_pack_n;
                valloc_retried <= e64_valloc_retried_n;
                varr_next <= e64_varr_next_n;
                vcall_argc <= e64_vcall_argc_n;
                vcall_ctor_val <= e64_vcall_ctor_val_n;
                vcall_entry <= e64_vcall_entry_n;
                vcall_set_this <= e64_vcall_set_this_n;
                vcall_this <= e64_vcall_this_n;
                vcall_value <= e64_vcall_value_n;
                vconsole_n <= e64_vconsole_n_n;
                vcsp <= e64_vcsp_n;
                vdiv_count <= e64_vdiv_count_n;
                vdiv_den <= e64_vdiv_den_n;
                vdiv_exp <= e64_vdiv_exp_n;
                vdiv_num <= e64_vdiv_num_n;
                vdiv_quot <= e64_vdiv_quot_n;
                vdiv_rem <= e64_vdiv_rem_n;
                vdiv_sign <= e64_vdiv_sign_n;
                vdraw_color <= e64_vdraw_color_n;
                vdraw_h <= e64_vdraw_h_n;
                vdraw_i <= e64_vdraw_i_n;
                vdraw_w <= e64_vdraw_w_n;
                vdraw_x <= e64_vdraw_x_n;
                vdraw_y <= e64_vdraw_y_n;
                venv <= e64_venv_n;
                venv_next <= e64_venv_next_n;
                vfe_arr <= e64_vfe_arr_n;
                vfe_base <= e64_vfe_base_n;
                vfe_fn <= e64_vfe_fn_n;
                vfe_i <= e64_vfe_i_n;
                vfe_map <= e64_vfe_map_n;
                vfe_mode <= e64_vfe_mode_n;
                vfe_ret <= e64_vfe_ret_n;
                vfe_sp <= e64_vfe_sp_n;
                vfree_armed <= e64_vfree_armed_n;
                vfree_arr_long <= e64_vfree_arr_long_n;
                vgc_clear_i <= e64_vgc_clear_i_n;
                vgc_halt_after <= e64_vgc_halt_after_n;
                vgc_qr <= e64_vgc_qr_n;
                vgc_qw <= e64_vgc_qw_n;
                vgc_resume <= e64_vgc_resume_n;
                vgc_wait_after <= e64_vgc_wait_after_n;
                vjs_rd_arm <= e64_vjs_rd_arm_n;
                vlistener_n <= e64_vlistener_n_n;
                vmetrics_w <= e64_vmetrics_w_n;
                vmod_count <= e64_vmod_count_n;
                vmod_den <= e64_vmod_den_n;
                vmod_exp <= e64_vmod_exp_n;
                vmod_rem <= e64_vmod_rem_n;
                vmod_sign <= e64_vmod_sign_n;
                vnat_base <= e64_vnat_base_n;
                vnat_dom <= e64_vnat_dom_n;
                vprom_copy <= e64_vprom_copy_n;
                vprom_done <= e64_vprom_done_n;
                vprom_ret <= st_t'(e64_vprom_ret_n);
                vraf_n <= e64_vraf_n_n;
                vrng <= e64_vrng_n;
                vsp <= e64_vsp_n;
                vst_hold_win <= e64_vst_hold_win_n;
                vst_refill_arm <= e64_vst_refill_arm_n;
                vst_refill_i <= e64_vst_refill_i_n;
                vst_refill_ret <= st_t'(e64_vst_refill_ret_n);
                vst_waddr <= e64_vst_waddr_n;
                vst_wdata <= e64_vst_wdata_n;
                vst_we <= e64_vst_we_n;
                vthis <= e64_vthis_n;
                vtimer_n <= e64_vtimer_n_n;
                vtimer_seq <= e64_vtimer_seq_n;
                x <= e64_x_n;
                y <= e64_y_n;
                hp_qk <= e64_hp_qk_n;
                hp_qt <= e64_hp_qt_n;
                hp_qv <= e64_hp_qv_n;
                js_i <= e64_js_i_n;
                js_ph <= e64_js_ph_n;
                pc_a1 <= e64_pc_a1_n;
                pc_a2 <= e64_pc_a2_n;
                pc_a3 <= e64_pc_a3_n;
                pc_a4 <= e64_pc_a4_n;
                pc_a5 <= e64_pc_a5_n;
                pc_ccw <= e64_pc_ccw_n;
                pc_op <= e64_pc_op_n;
                vfe_arr_s <= e64_vfe_arr_s_n;
                vfe_base_s <= e64_vfe_base_s_n;
                vfe_fn_s <= e64_vfe_fn_s_n;
                vfe_i_s <= e64_vfe_i_s_n;
                vfe_map_s <= e64_vfe_map_s_n;
                vfe_mode_s <= e64_vfe_mode_s_n;
                vfe_ret_s <= e64_vfe_ret_s_n;
                vjs_val <= e64_vjs_val_n;
                vlistener_ev <= e64_vlistener_ev_n;
                vlistener_fn <= e64_vlistener_fn_n;
                vraf <= e64_vraf_n;
                vst_win <= e64_vst_win_n;
                vtimer_due <= e64_vtimer_due_n;
                vtimer_fn <= e64_vtimer_fn_n;
                vtimer_id <= e64_vtimer_id_n;
                vtimer_period <= e64_vtimer_period_n;
                vtimer_valid <= e64_vtimer_valid_n;
                if (e64_json_mem_we) json_mem[e64_json_mem_waddr[12:0]] <= e64_json_mem_wdata;
                if (e64_varr_len_we) varr_len[e64_varr_len_waddr[10:0]] <= e64_varr_len_wdata;
                if (e64_varr_lidx_we) varr_lidx[e64_varr_lidx_waddr[10:0]] <= e64_varr_lidx_wdata;
                if (e64_varr_long_we) varr_long[e64_varr_long_waddr[10:0]] <= e64_varr_long_wdata;
                if (e64_varr_valid_we) varr_valid[e64_varr_valid_waddr[10:0]] <= e64_varr_valid_wdata;
                if (e64_venv_gen_we) venv_gen[e64_venv_gen_waddr[8:0]] <= e64_venv_gen_wdata;
                if (e64_venv_len_we) venv_len[e64_venv_len_waddr[8:0]] <= e64_venv_len_wdata;
                if (e64_venv_valid_we) venv_valid[e64_venv_valid_waddr[8:0]] <= e64_venv_valid_wdata;
                if (e64_vobj_cls_we) vobj_cls[e64_vobj_cls_waddr[9:0]] <= e64_vobj_cls_wdata;
                if (e64_vvar_valid_we) vvar_valid[e64_vvar_valid_waddr[8:0]] <= e64_vvar_valid_wdata;
                if (e64_vvars_we) vvars[e64_vvars_waddr[8:0]] <= e64_vvars_wdata;
                if (e64_vframe_we) begin
                    vframe_return_ip[e64_vframe_waddr] <= e64_vframe_rip_wdata;
                    vframe_base_sp[e64_vframe_waddr] <= e64_vframe_bsp_wdata;
                    vframe_escaped[e64_vframe_waddr] <= e64_vframe_esc_wdata;
                    vframe_this[e64_vframe_waddr] <= e64_vframe_this_wdata;
                    vframe_env[e64_vframe_waddr] <= e64_vframe_env_wdata;
                    vframe_fn[e64_vframe_waddr] <= e64_vframe_fn_wdata;
                    vframe_ctor[e64_vframe_waddr] <= e64_vframe_ctor_wdata;
                end
            end else unique case (state)
                S_IDLE: if (start) begin
                    running <= 1'b1;
                    looping <= 1'b0;
                    sp <= '0;
                    vsp <= '0;
                    vcsp <= '0;
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
                    ops_base <= (code_rdata[17] ? 16'd4 : 16'd3)
                              + (code_rdata[19] ? (n_consts << 1) : n_consts);
                    jsb_flags <= code_rdata[31:16];
                    for (int i = 0; i < MAX_VARS; i++) var_init[i] <= 1'b0;
                    for (int i = 0; i < MAX_VARS; i++) vvar_valid[i] <= 1'b0;
                    e64_p_clr <= 1'b1;
                    e32_p_clr <= 1'b1;
                    vsp <= '0; vcsp <= '0;
                    vsp_d <= '0;
                    vst_hold_win <= 1'b0;
                    vfree_armed <= 1'b0;
                    vfree_ok <= 1'b0;
                    vfree_arr_long <= 1'b0;
                    vprom_done <= 1'b0;
                    vprom_copy <= 1'b0;
                    hp_prom_wr <= 1'b0;
                    if (code_rdata[19]) begin
                        vobj_next <= 14'd0;
                        varr_next <= 14'd0;
                        vfn_next <= 14'd0;
                        venv_next <= 10'd0;
                        vgc_resume <= 2'd0;
                        valloc_retried <= 1'b0;
                        vthis <= V64_UNDEFINED;
                        venv <= V64_UNDEFINED;
                        vcall_set_this <= 1'b0;
                        vcall_this <= V64_UNDEFINED;
                        vcall_ctor_val <= V64_UNDEFINED;
                        vraf_n <= 4'd0;
                        vtimer_n <= 7'd0;
                        vframe_no <= 32'd0;
                        // Last intern coords survive RUN otherwise PACMAN
                        // SNAP shows the previous title's vdraw (INVADERS 14×5).
                        vdraw_x <= '0; vdraw_y <= '0;
                        vdraw_w <= '0; vdraw_h <= '0;
                        vdraw_color <= '0;
                        vtimer_seq <= 32'd1;
                        vrng <= 32'h6d2b79f5;
                        vconsole_n <= 9'd0;
                        vnat_dom <= 3'd0;
                        vnat_style <= V64_UNDEFINED;
                        vkev_event <= V64_UNDEFINED;
                        vlistener_n <= 5'd0;
                        vkey_li <= 5'd0;
                        v64_frame_armed <= 1'b0;
                        vcallback_key <= 1'b0;
                        vcallback_fe <= 1'b0;
                        vfe_arr <= V64_UNDEFINED;
                        vfe_fn <= V64_UNDEFINED;
                        vfe_i <= 8'd0;
                        vfe_ret <= 16'd0;
                        vfe_mode <= 2'd0;
                        vfe_map <= V64_UNDEFINED;
                        for (int i = 0; i < 16; i++) begin
                            vlistener_ev[i] <= V64_UNDEFINED;
                            vlistener_fn[i] <= V64_UNDEFINED;
                        end
                        for (int i = 0; i < 64; i++)
                            vtimer_valid[i] <= 1'b0;
                        for (int i = 0; i < MAX_OBJ; i++) begin
                            vobj_alloc[i] <= 2'd0;
                            vobj_gen[i] <= 12'd1;
                            vfn_gen[i] <= 12'd1;
                            vfn_valid[i] <= 1'b0;
                            vfn_mark[i] <= 1'b0;
                            vobj_len[i] <= 6'd0;
                            vobj_mark[i] <= 1'b0;
                            vobj_builtin[i] <= 4'd0;
                        end
                        for (int i = 0; i < MAX_ARR; i++) begin
                            varr_valid[i] <= 1'b0;
                            varr_gen[i] <= 12'd1;
                            varr_len[i] <= 8'd0;
                            varr_mark[i] <= 1'b0;
                            varr_long[i] <= 1'b0;
                            varr_lidx[i] <= 8'd0;
                        end
                        for (int i = 0; i < MAX_ARR_LONG; i++)
                            vlong_used[i] <= 1'b0;
                        for (int i = 0; i < ENV_DEPTH; i++) begin
                            venv_valid[i] <= 1'b0;
                            venv_gen[i] <= 12'd1;
                            venv_len[i] <= 5'd0;
                            venv_mark[i] <= 1'b0;
                        end
                    end
                    for (int i = 0; i < 1024; i++) fill_lut[i] <= 8'hFF; // NEW: FSTY default
                    n_obj <= 0; n_arr <= 0; n_cls <= 0; csp <= 0; raf_n <= 0;
                    arr_keep_ok <= 1'b0; n_arr_keep <= 0;
                    arr_keep_wait <= ARR_KEEP_DELAY[3:0];
                    obj_keep_ok <= 1'b0; n_obj_keep <= 0;
                    obj_keep_wait <= ARR_KEEP_DELAY[3:0];
                    frame_fire <= 1'b0;
                    gc_qr <= 0; gc_qw <= 0; gc_i <= 0; gc_root_i <= 0;
                    gc_obj_high <= 0; gc_arr_high <= 0; dbg_gc_n <= 0;
                    dc_arm <= 1'b0; // NEW: no stale SET_PROP deep copy across RUNs
                    env_sp <= 0; env_free_n <= 0; to_n <= 0; to_seq <= 16'd1; dbg_heap_ovf <= 0; dbg_to_ovf <= 0;
                    dbg_json_ovf <= 0; js_sp <= 0; json_wp <= 0;
                    dbg_stack_ovf <= 0; dbg_call_ovf <= 0;
                    machine_fault <= 1'b0; fault_code <= 8'd0;
                    kd_fn <= 16'hFFFF; ku_fn <= 16'hFFFF; click_fn <= 16'hFFFF;
                    kd_n <= 3'd0; ku_n <= 3'd0; kev_li <= 2'd0;
                    kd_slot[0] <= 16'hFFFF; kd_slot[1] <= 16'hFFFF;
                    kd_slot[2] <= 16'hFFFF; kd_slot[3] <= 16'hFFFF;
                    ku_slot[0] <= 16'hFFFF; ku_slot[1] <= 16'hFFFF;
                    ku_slot[2] <= 16'hFFFF; ku_slot[3] <= 16'hFFFF;
                    boot_clr <= 1'b1; boot_clr_n <= 2'd2;
                    id_find <= 16'hFFFF;
                    id_findindex <= 16'hFFFF; id_filter <= 16'hFFFF;
                    click_fired <= 1'b0;
                    pre_click_raf <= 1'b0;
                    prev_joy <= joy_in; joy_down_edge <= 0; joy_up_edge <= 0;
                    fill_style_i <= 8'd1; stroke_style_i <= 8'd1; lfsr <= 32'hACE1; this_obj <= 16'hFFFF;
                    var_this <= 9'd0; this_ok <= 1'b0; id_this_name <= 16'hFFFF;
                    var_keys <= 9'd0; keys_ok <= 1'b0;
                    keys_a_oid <= 16'hFFFF; keys_d_oid <= 16'hFFFF; keys_sp_oid <= 16'hFFFF;
                    id_keys_name <= 16'hFFFF; id_pressed <= 16'hFFFF; id_kspace <= 16'hFFFF;
                    id_fillrect <= 16'hFFFF; id_length <= 16'hFFFF; id_push <= 16'hFFFF;
                    id_pop <= 16'hFFFF;
                    id_splice <= 16'hFFFF; id_foreach <= 16'hFFFF; id_getctx <= 16'hFFFF;
                    id_map <= 16'hFFFF; id_unshift <= 16'hFFFF;
                    id_click <= 16'hFFFF; id_ael <= 16'hFFFF; id_key <= 16'hFFFF;
                    id_rel <= 16'hFFFF; id_disp <= 16'hFFFF;
                    id_document <= 16'hFFFF; id_window <= 16'hFFFF;
                    id_fillstyle <= 16'hFFFF; id_clearrect <= 16'hFFFF; id_drawimage <= 16'hFFFF;
                    id_keydown <= 16'hFFFF; id_keyup <= 16'hFFFF; id_width <= 16'hFFFF;
                    id_space <= 16'hFFFF; id_arrow_l <= 16'hFFFF; id_arrow_r <= 16'hFFFF;
                    id_arrow_u <= 16'hFFFF; id_arrow_d <= 16'hFFFF;
                    id_a <= 16'hFFFF; id_d <= 16'hFFFF; kev_fn <= 16'hFFFF;
                    id_height <= 16'hFFFF; id_black <= 16'hFFFF; id_white <= 16'hFFFF;
                    id_style <= 16'hFFFF;
                    id_save <= 16'hFFFF; id_restore <= 16'hFFFF;
                    id_translate <= 16'hFFFF; id_rotate <= 16'hFFFF;
                    id_settransform <= 16'hFFFF;
                    id_assign <= 16'hFFFF; id_bind <= 16'hFFFF;
                    id_proto <= 16'hFFFF; id_filltext <= 16'hFFFF; id_arc <= 16'hFFFF;
                    id_font <= 16'hFFFF; id_textalign <= 16'hFFFF;
                    id_imgsmooth <= 16'hFFFF;
                    id_center <= 16'hFFFF; id_right <= 16'hFFFF;
                    id_measuretext <= 16'hFFFF; metrics_oid <= 16'hFFFF;
                    id_enter <= 16'hFFFF; id_keycode <= 16'hFFFF;
                    id_kbevent <= 16'hFFFF; id_domevent <= 16'hFFFF;
                    id_customev <= 16'hFFFF; id_mouseev <= 16'hFFFF;
                    id_type <= 16'hFFFF;
                    id_now <= 16'hFFFF; id_gettime <= 16'hFFFF;
                    id_beginpath <= 16'hFFFF; id_fill <= 16'hFFFF; id_stroke <= 16'hFFFF;
                    id_moveto <= 16'hFFFF; id_lineto <= 16'hFFFF; id_closepath <= 16'hFFFF;
                    id_quadcurve <= 16'hFFFF;
                    id_getimgdata <= 16'hFFFF; id_putimgdata <= 16'hFFFF;
                    id_str_undef <= 16'hFFFF; id_str_number <= 16'hFFFF;
                    id_str_string <= 16'hFFFF; id_str_object <= 16'hFFFF;
                    id_str_function <= 16'hFFFF;
                    id_join <= 16'hFFFF; id_indexof <= 16'hFFFF; id_replace <= 16'hFFFF;
                    names_n <= 16'd0; dbg_join_miss <= 16'd0; dbg_pdo_n <= 5'd0;
                    v64_concat <= 1'b0;
                    v64_join <= 1'b0;
                    v64_sqrt <= 1'b0;
                    v64_repl <= 1'b0;
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
                    // NEW: string bytes / char lookup start empty every LOAD
                    for (int i = 0; i < 256; i++) char_ok[i] <= 1'b0;
                    for (int i = 0; i < 1024; i++) begin
                        name_has[i] <= 1'b0;
                        name_blen[i] <= 16'd0;
                    end
                    names_ok <= 1'b0; nb_i <= 16'd0; nb_len <= 16'd0; nb_wp <= 16'd0;
                    dbg_str_ovf <= 16'd0; name_rdaddr <= 16'd0; str_res <= 11'd0;
                    str_pf_ok <= 1'b0; str_pf_id <= 16'd0; str_pf_ci <= 32'sd0;
                    namcpy_repl <= 1'b0; namcpy_v64 <= 1'b0; namcpy_armed <= 1'b0;
                    // NEW: fillText defaults match FM (8 px glyphs, left align)
                    ctx_align <= 2'd0; ctx_font_px <= 8'd8;
                    font_raddr <= 10'd0; txt_len <= 7'd0; txt_ph <= 4'd0;
                    dbg_cb_ip <= 16'd0; dbg_tmr_mis <= 16'd0;
                    dbg_tmr_sched <= 16'd0; dbg_tmr_fire <= 16'd0;
                    dbg_find_hit <= 16'd0; dbg_splice_n <= 16'd0;
                    dbg_div_n <= 16'd0;
                    ctx_tx <= 32'sd0; ctx_ty <= 32'sd0;
                    saved_tx <= 32'sd0; saved_ty <= 32'sd0;
                    ctx_sx <= FX_ONE; ctx_sy <= FX_ONE;   // NEW: identity scale
                    ctx_smooth <= 1'b1; // NEW: imageSmoothingEnabled default true
                    saved_sx <= FX_ONE; saved_sy <= FX_ONE;
                    trail_off <= 19'((code_rdata[17] ? 16'd4 : 16'd3)
                                  + (code_rdata[19] ? (n_consts << 1) : n_consts)
                                  + n_ops) << 2;
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
                    if (jsb_flags[3]) begin
                        // Value64 constants are little-endian low/high u32 pairs.
                        vconst_lo <= code_rdata;
                        code_raddr <= 15'(hdr_w + (c_i << 1) + 16'd1);
                        state <= S_RD;
                        ret_state <= S_V64_CONST_HI;
                    end else begin
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
                end
                S_V64_CONST_HI: begin
                    vconsts[c_i[9:0]] <= {code_rdata, vconst_lo};
                    e64_poke(6'd14, {6'd0, c_i[9:0]}, {code_rdata, vconst_lo});
                    if (c_i + 16'd1 >= n_consts) begin
                        ip <= '0;
                        if (jsb_flags[0]) begin
                            code_raddr <= 15'(ops_base + n_ops);
                            state <= S_RD;
                            ret_state <= S_TRAIL;
                        end else begin
                            code_raddr <= 15'(ops_base);
                            state <= S_FETCH_WAIT;
                        end
                    end else begin
                        c_i <= c_i + 16'd1;
                        code_raddr <= 15'(hdr_w + ((c_i + 16'd1) << 1));
                        state <= S_RD;
                        ret_state <= S_LD_CONST;
                    end
                end

                S_TRAIL: begin
                    // JSB v2 trailer: names (hash intern ids) + skip vars + class table
                    trail_guard <= trail_guard + 20'd1;
                    if (trail_guard >= 20'd200000) begin
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
                                if ({tb, trail_acc[7:0]} == 16'd45649) id_pop <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd18044) id_splice <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54890) id_foreach <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd42332) id_map <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38281) id_unshift <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62905) id_find <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61081) id_findindex <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52088) id_filter <= name_idx;
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
                                // "ArrowUp" — "ArrowDown" hash is 43, small
                                // enough to collide, so it is confirmed with
                                // the length byte in trail_ph 4 below.
                                if ({tb, trail_acc[7:0]} == 16'd14436) id_arrow_u <= name_idx;
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
                                // NEW: text metrics/state names (jsb_format._name_hash)
                                if ({tb, trail_acc[7:0]} == 16'd3151)  id_font <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38360) id_textalign <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52309) id_center <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49692) id_right <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32683) id_measuretext <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54440) id_imgsmooth <= name_idx;
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
                                if ({tb, trail_acc[7:0]} == 16'd7601) id_style <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45091) id_hex_fff <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54211) id_hex_3f6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45411) id_hex_f5a <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd16643) id_hex_fc0 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd10674) id_hex_2ec <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44003) id_hex_000 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56618) id_join <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd17993) id_indexof <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45748) id_replace <= name_idx;
                                // NEW: typeof() result strings
                                if ({tb, trail_acc[7:0]} == 16'd24912) id_str_undef <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56137) id_str_number <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd24593) id_str_string <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd41791) id_str_object <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd29656) id_str_function <= name_idx;
                                // NEW: full hash table — join result maps back to intern id
                                name_hash_tbl[name_idx[9:0]] <= {tb, trail_acc[7:0]};
                                e64_poke(6'd40, {6'd0, name_idx[9:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                // NEW: u8 length byte follows each hash (concat fold)
                                trail_ph <= 5'd4;
                            end
                            5'd4: begin
                                name_len_tbl[name_idx[9:0]] <= tb;
                                name_blen[name_idx[9:0]] <= {8'd0, tb};
                                e64_poke(6'd41, {6'd0, name_idx[9:0]}, {56'd0, tb});
                                // Space intern: hash 32 + len 1 (U+0020). Confirm
                                // here so e.key === " " matches KEYEVT payload.
                                if (name_hash_tbl[name_idx[9:0]] == 16'd32 && tb == 8'd1)
                                    id_space <= name_idx;
                                // "ArrowDown": hash 43 + len 9 (hash alone is
                                // also '+' and other short names)
                                if (name_hash_tbl[name_idx[9:0]] == 16'd43 && tb == 8'd9)
                                    id_arrow_d <= name_idx;
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
                                e64_poke(6'd37, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
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
                                e64_poke(6'd38, {12'd0, trail_cls_i[3:0]},
                                         {59'd0, {tb, trail_acc[7:0]}[4:0]});
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
                                e64_poke(6'd39, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                e64_p_addr2 <= {12'd0, trail_meth_i[3:0]};
                                trail_ph <= 5'd20;
                            end
                            5'd20: begin trail_acc[7:0] <= tb; trail_ph <= 5'd21; end
                            5'd21: begin
                                cls_mip[trail_cls_i[3:0]][trail_meth_i[3:0]] <= {tb, trail_acc[7:0]};
                                e64_poke(6'd31, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                e64_p_addr2 <= {12'd0, trail_meth_i[3:0]};
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
                                // NEW: "NAMB" — UTF-8 name bytes with no sprite
                                // block in front (plain .JS). Self-describing, so
                                // the section start never has to be inferred from
                                // where the class table happened to end.
                                end else if (trail_acc[7:0] == 8'h4E && trail_acc[15:8] == 8'h41 &&
                                             trail_n[7:0] == 8'h4D && tb == 8'h42) begin
                                    nb_i <= 16'd0;
                                    nb_wp <= 16'd0;
                                    trail_ph <= 6'd32;
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
                                        // NEW: empty SPR1 — name bytes follow
                                        spr_hdr <= 3'd0;
                                        trail_ph <= 6'd35;
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
                                        e64_poke(6'd15, {6'd0, fsty_name[9:0]}, {56'd0, tb});
                                        spr_hdr <= 3'd3;
                                    end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (fsty_n <= 16'd1) begin
                                            // NEW: names follow FSTY — peek "NAMB"
                                            trail_acc <= 16'd0;
                                            trail_ph <= 6'd35;
                                        end else fsty_n <= fsty_n - 16'd1;
                                    end
                                endcase
                            end
                            // NEW: "NAMB" peek after the SPRD/FSTY blocks. Same
                            // 4-byte compare as the sprite magic; a miss just means
                            // no string bytes (names_ok stays 0) and never hangs RUN.
                            6'd35: begin
                                unique case (spr_hdr)
                                    3'd0: begin
                                        if (tb == 8'h4E) spr_hdr <= 3'd1;
                                        else begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd1, 3'd2: begin
                                        if ((spr_hdr == 3'd1 && tb == 8'h41) ||
                                            (spr_hdr == 3'd2 && tb == 8'h4D))
                                            spr_hdr <= spr_hdr + 3'd1;
                                        else begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (tb == 8'h42) begin
                                            nb_i <= 16'd0;
                                            nb_wp <= 16'd0;
                                            trail_ph <= 6'd32;
                                        end else begin
                                            code_raddr <= 15'(ops_base);
                                            state <= S_FETCH_WAIT;
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                endcase
                            end
                            // NEW: per-name u16 length, then its raw bytes. Order is
                            // the intern order, so nb_i IS the intern index and
                            // name_off[] lands a direct BRAM address for str[i].
                            6'd32: begin trail_acc[7:0] <= tb; trail_ph <= 6'd33; end
                            6'd33: begin
                                nb_len <= {tb, trail_acc[7:0]};
                                // NAMB length is the real interned byte count
                                // (hash u8 is only for concat fold).
                                name_blen[nb_i[9:0]] <= {tb, trail_acc[7:0]};
                                e64_poke(6'd17, {6'd0, nb_i[9:0]},
                                         {32'd0, nb_wp, tb, trail_acc[7:0]});
                                // nb_len counts DOWN per byte, so it cannot tell a
                                // 1-char name from the last byte of a long one —
                                // that mixed whole-name ids into the char table.
                                nb_one <= ({tb, trail_acc[7:0]} == 16'd1);
                                name_off[nb_i[9:0]] <= nb_wp;
                                // NEW: bytes for this id are real (fillText and
                                // str[i] both refuse hash-only ids)
                                if (nb_wp + {tb, trail_acc[7:0]} <= 16'(NAME_CAP))
                                    name_has[nb_i[9:0]] <= 1'b1;
                                names_ok <= 1'b1;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    // empty name — nothing to copy
                                    if (nb_i + 16'd1 >= names_n) begin
                                        code_raddr <= 15'(ops_base);
                                        state <= S_FETCH_WAIT;
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else trail_ph <= 6'd34;
                            end
                            6'd34: begin
                                if (nb_wp < 16'(NAME_CAP)) begin
                                    name_mem[nb_wp[14:0]] <= tb;
                                    e64_poke(6'd16, nb_wp, {56'd0, tb});
                                end
                                else dbg_str_ovf <= dbg_str_ovf + 16'd1;
                                nb_wp <= nb_wp + 16'd1;
                                // 1-char name → the byte→intern lookup str[i] uses
                                if (nb_one && nb_i < 16'd1024) begin
                                    char_id[tb] <= nb_i;
                                    char_ok[tb] <= 1'b1;
                                end
                                if (nb_len <= 16'd1) begin
                                    if (nb_i + 16'd1 >= names_n) begin
                                        code_raddr <= 15'(ops_base);
                                        state <= S_FETCH_WAIT;
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else nb_len <= nb_len - 16'd1;
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
                                // SPR1 pixel copy starts this cycle when count>0.
                                // ret_state must be S_SPR — S_TRAIL + ph 31 would
                                // skip the pack (dihit with a blank FB).
                                if (trail_ph == 5'd27 && !sprd_mode &&
                                    {tb, trail_acc[7:0]} != 16'd0)
                                    ret_state <= S_SPR;
                                else
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
                    hp_env <= 1'b0;
                    // NEW: clear both FB banks once after header/trail, before first op
                    if (boot_clr) begin
                        color <= 8'd0;
                        clr_idx <= '0;
                        state <= S_CLEAR;
                    end else if (dc_arm) begin
                        // NEW: pending SET_PROP array deep copy runs between ops
                        dc_arm <= 1'b0;
                        state <= S_ARR_DCOPY;
                    end else if (jsb_flags[3])
                        state <= S_V64_EXEC;
                    else
                        state <= S_EXEC;
                end

                S_ARR_DCOPY: begin
                    // Sequential 1W1R copy. Nested child-array identity copy
                    // is a later 1-D-port walk, not a 128-wide combo.
                    if (dc_i >= ((varr_len[dc_src] > arr_len[dc_src])
                            ? varr_len[dc_src] : arr_len[dc_src])) begin
                        hp_phase <= 3'd0;
                        dc_arm <= 1'b0;
                        state <= S_EXEC;
                    end else if (hp_phase == 3'd0) begin
                        hp_cmd <= HP_AGETI;
                        hp_v64 <= 1'b0;
                        hp_aid <= dc_src;
                        hp_aslot <= dc_i[6:0];
                        hp_alen <= arr_len[dc_src];
                        hp_ret <= S_ARR_DCOPY;
                        hp_phase <= 3'd1;
                        state <= S_HEAP_WAIT;
                    end else begin
                        hp_cmd <= HP_ASETI;
                        hp_v64 <= 1'b0;
                        hp_from_stack <= 1'b0;
                        hp_aid <= dc_dst;
                        hp_aslot <= dc_i[6:0];
                        hp_wval <= hp_rval;
                        hp_tag <= hp_tag;
                        hp_ret <= S_ARR_DCOPY;
                        hp_phase <= 3'd0;
                        dc_i <= dc_i + 8'd1;
                        state <= S_HEAP_AWR;
                    end
                end

                // S_EXEC body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                // S_NAT body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
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
                    if (v64_join) begin
                        if (jn_i >= 16'({8'd0, varr_len[jn_arr]})) begin
                            jn_i <= 16'd0;
                            jn_len <= varr_len[jn_arr];
                            jn_rd_arm <= 1'b0;
                            state <= S_JOIN_FIND;
                        end else if (!jn_rd_arm) begin
                            jn_rd_arm <= 1'b1;
                        end else begin
                            logic signed [31:0] ev;
                            logic [63:0] elem;
                            elem = varr_rdata;
                            jn_rd_arm <= 1'b0;
                            ev = $signed(v64_to_uint32(elem));
                            if (elem[63:48] == V64_TAG_PREFIX &&
                                elem[47:44] == 4'd4 &&
                                name_len_tbl[elem[9:0]] == 8'd1 &&
                                name_hash_tbl[elem[9:0]][7:0] >= 8'h30 &&
                                name_hash_tbl[elem[9:0]][7:0] <= 8'h39)
                                ev = 32'(name_hash_tbl[elem[9:0]][7:0] - 8'h30);
                            if (ev < 32'sd0 || ev > 32'sd9) begin
                                dbg_join_miss <= dbg_join_miss + 16'd1;
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_join <= 1'b0;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                                if (jn_i < 16'(TXT_MAX)) begin
                                    txt_buf[jn_i[5:0]] <= 8'h30 + 8'(ev);
                                    txt_bn <= 7'(jn_i) + 7'd1;
                                    cc_bok <= 1'b1;
                                end else cc_bok <= 1'b0;
                                jn_i <= jn_i + 16'd1;
                            end
                        end
                    end else if (jn_i >= 16'({8'd0, arr_len[jn_arr]})) begin
                        jn_i <= 16'd0;
                        jn_len <= arr_len[jn_arr]; // one char per digit elem
                        jn_rd_arm <= 1'b0;
                        state <= S_JOIN_FIND;
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else begin
                        logic [2:0] et;
                        logic signed [31:0] ev;
                        // NEW: the digits are staged as characters too, so a join
                        // result is a full string (bytes, not just a hash). Without
                        // this the alloc path below would inherit whatever the last
                        // concat left in txt_buf.
                        et = varr_trdata;
                        ev = (et == 3'd7) ? ($signed(varr_rdata[31:0]) >>> 16)
                                          : $signed(varr_rdata[31:0]);
                        jn_rd_arm <= 1'b0;
                        if (et == 3'd3 && name_len_tbl[varr_rdata[9:0]] == 8'd1 &&
                            name_hash_tbl[varr_rdata[9:0]][7:0] >= 8'h30 &&
                            name_hash_tbl[varr_rdata[9:0]][7:0] <= 8'h39) begin
                            // interned "0".."9" — same as number digits for maze wall codes
                            ev = 32'(name_hash_tbl[varr_rdata[9:0]][7:0] - 8'h30);
                            et = 3'd0;
                        end
                        if ((et != 3'd0 && et != 3'd7) || ev < 32'sd0 || ev > 32'sd9) begin
                            // non-digit join shape — honest miss, result undefined
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else begin
                            jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                            if (jn_i < 16'(TXT_MAX)) begin
                                txt_buf[jn_i[5:0]] <= 8'h30 + 8'(ev);
                                txt_bn <= 7'(jn_i) + 7'd1;
                                cc_bok <= 1'b1;
                            end else cc_bok <= 1'b0;
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
                            if (v64_sqrt) begin
                                vst_wr(vnat_base, v64_from_fx($signed({8'd0,
                                    (rem2 >= trial) ? {sq_root[22:0], 1'b1}
                                                    : {sq_root[22:0], 1'b0}})));
                                vsp <= vnat_base + 12'd1;
                                ip <= ip + 16'd1;
                                code_raddr <=
                                    15'(ops_base + ip + 16'd1);
                                v64_sqrt <= 1'b0;
                                state <= S_FETCH_WAIT;
                            end else begin
                            stack[sp - 8'd1] <= {8'd0,
                                (rem2 >= trial) ? {sq_root[22:0], 1'b1}
                                                : {sq_root[22:0], 1'b0}};
                            stack_tag[sp - 8'd1] <= 3'd7;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                            end
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
                        if (v64_concat || v64_join) begin
                            vst_wr(jn_res, v64_handle(
                                4'd4, 12'd0, {16'd0, hidx}
                            ));
                            v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                        end else begin
                        stack[jn_res] <= {16'd0, hidx};
                        stack_tag[jn_res] <= 3'd3;
                        end
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (jn_i + 16'd16 >= names_n) begin
                        if (names_n < 16'd1024) begin
                            name_hash_tbl[names_n[9:0]] <= jn_h;
                            name_len_tbl[names_n[9:0]] <= jn_len;
                            name_blen[names_n[9:0]] <= {8'd0, jn_len};
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, v64_handle(
                                    4'd4, 12'd0, {16'd0, names_n}
                                ));
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end else begin
                            stack[jn_res] <= {16'd0, names_n};
                            stack_tag[jn_res] <= 3'd3;
                            end
                            names_n <= names_n + 16'd1;
                            // NEW: and its characters, staged in txt_buf by
                            // S_CONCAT — that is what makes fillText("SCORE "+n)
                            // and str[i] on a built string work at all
                            if (cc_bok && jn_len <= 8'(TXT_MAX) &&
                                ({1'b0, nb_wp} + {9'd0, jn_len}) <= 17'(NAME_CAP)) begin
                                name_off[names_n[9:0]] <= nb_wp;
                                name_has[names_n[9:0]] <= 1'b1;
                                txt_i <= 7'd0;
                                state <= S_STR_WR;
                            end else begin
                                if (!cc_bok) dbg_str_ovf <= dbg_str_ovf + 16'd1;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end
                        end else begin
                            // intern table full — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end else begin
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                            end
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
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
                    if (cc_st == 2'd0) begin
                        // classify operand
                        if (t_ == 3'd3) begin
                            cc_h <= 16'(32'(cc_h) * 32'(pow31_tbl[name_len_tbl[v_[9:0]]])
                                        + 32'(name_hash_tbl[v_[9:0]]));
                            cc_len <= cc_len + name_len_tbl[v_[9:0]];
                            // NEW: copy this operand's characters into txt_buf so
                            // the joined intern can be given real bytes. The
                            // hash fold above is unchanged, so ids do not move.
                            if (names_ok && name_has[v_[9:0]] &&
                                ({1'b0, txt_bn} + {1'b0, name_len_tbl[v_[9:0]][6:0]})
                                    <= 8'(TXT_MAX)) begin
                                cc_cp <= name_off[v_[9:0]];
                                cc_cn <= name_len_tbl[v_[9:0]];
                                name_rdaddr <= name_off[v_[9:0]];
                                cc_st <= 2'd2;
                            end else begin
                                cc_bok <= 1'b0; // hash-only, as before
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'(pow31_tbl[name_len_tbl[v_[9:0]]])
                                                + 32'(name_hash_tbl[v_[9:0]]));
                                    jn_len <= cc_len + name_len_tbl[v_[9:0]];
                                    jn_i <= 16'd0;
                                    state <= S_JOIN_FIND;
                                end else cc_second <= 1'b1;
                            end
                        end else if (t_ == 3'd0 || t_ == 3'd7) begin
                            // integer (fx floors) — fold '-' then digits
                            logic signed [31:0] iv;
                            iv = (t_ == 3'd7) ? (v_ >>> 16) : v_;
                            if (iv < 0) begin
                                cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd45); // '-'
                                cc_len <= cc_len + 8'd1;
                                if (txt_bn < 7'(TXT_MAX)) begin
                                    txt_buf[txt_bn[5:0]] <= 8'h2D;
                                    txt_bn <= txt_bn + 7'd1;
                                end else cc_bok <= 1'b0;
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
                            cc_st <= 2'd1;
                        end else begin
                            // undefined/obj/arr/fn concat — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end else begin
                            stack[jn_res] <= 32'sd0;
                            stack_tag[jn_res] <= 3'd5;
                            end
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                    end else if (cc_st == 2'd1) begin
                        // digit loop: subtract P10[cc_pi] until below, fold digit
                        if (cc_v >= 32'(P10[cc_pi])) begin
                            cc_v <= cc_v - 32'(P10[cc_pi]);
                            cc_d <= cc_d + 4'd1;
                        end else begin
                            cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                            cc_len <= cc_len + 8'd1;
                            cc_d <= 4'd0;
                            // NEW: same digit as a character
                            if (txt_bn < 7'(TXT_MAX)) begin
                                txt_buf[txt_bn[5:0]] <= 8'h30 + {4'd0, cc_d};
                                txt_bn <= txt_bn + 7'd1;
                            end else cc_bok <= 1'b0;
                            if (cc_pi == 4'd0) begin
                                // operand done
                                cc_st <= 2'd0;
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                                    jn_len <= cc_len + 8'd1;
                                    jn_i <= 16'd0;
                                    state <= S_JOIN_FIND;
                                end else cc_second <= 1'b1;
                            end else cc_pi <= cc_pi - 4'd1;
                        end
                    end else begin
                        // NEW: copy one operand's bytes (name_mem is registered, so
                        // the first byte lands the cycle after cc_st became 2)
                        if (cc_cn == 8'd0) begin
                            cc_st <= 2'd0;
                            if (cc_second) begin
                                jn_h <= cc_h; jn_len <= cc_len; // folded already
                                jn_i <= 16'd0;
                                state <= S_JOIN_FIND;
                            end else cc_second <= 1'b1;
                        end else if (name_rdaddr == cc_cp) begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 0
                        end else begin
                            txt_buf[txt_bn[5:0]] <= name_rdata;
                            txt_bn <= txt_bn + 7'd1;
                            cc_cn <= cc_cn - 8'd1;
                            if (cc_cn > 8'd1) name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                end
                S_IDXOF: begin
                    // NEW: arr.indexOf(v) linear scan (FM list.index twin)
                    if (jn_i >= 16'({8'd0, arr_len[jn_arr]})) begin
                        stack[jn_res] <= -32'sd1;
                        stack_tag[jn_res] <= 3'd0;
                        jn_rd_arm <= 1'b0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else begin
                    logic [2:0] at2;
                    logic signed [31:0] av, nv;
                    logic tag_ok;
                        at2 = varr_trdata;
                        av = $signed(varr_rdata[31:0]);
                    nv = idx_v;
                        jn_rd_arm <= 1'b0;
                    // int/fx compare in the same Q16.16 domain
                    if (at2 == 3'd0 && idx_t == 3'd7) av = av <<< 16;
                    if (idx_t == 3'd0 && at2 == 3'd7) nv = nv <<< 16;
                    tag_ok = (at2 == idx_t) ||
                             ((at2 == 3'd0 || at2 == 3'd7) &&
                              (idx_t == 3'd0 || idx_t == 3'd7));
                        if (tag_ok && av == nv) begin
                        stack[jn_res] <= {16'd0, jn_i};
                        stack_tag[jn_res] <= 3'd0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else jn_i <= jn_i + 16'd1;
                    end
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
                    end else if (xf_dst == 2'd2) begin
                        // NEW: fillText pen — glyph size comes from ctx.font, and
                        // the pen may sit off-glass (centred text clips per pixel)
                        txt_px <= 16'(ix_);
                        txt_py <= 16'(iy_);
                        state <= S_TXT_LD;
                    end else begin
                        iw_ = trunc32(xfp_w); if (iw_ < 32'sd1) iw_ = 32'sd1;
                        ih_ = trunc32(xfp_h); if (ih_ < 32'sd1) ih_ = 32'sd1;
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
                    // copy sprite pack from code_mem trailer bytes (trail_tb).
                    // Parse the current byte EVERY cycle — including when
                    // trail_off[1:0]==3. Fetching the next word without
                    // consuming byte 3 skipped every 4th header/pixel (wrong
                    // stride / blank tiny sprites). S_TRAIL already parses
                    // then fetches; match that. NAMB follows the pixels.
                    logic spr_end;
                    spr_end = 1'b0;
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
                                    spr_hdr <= 3'd0;
                                    trail_ph <= 6'd35;
                                    spr_end = 1'b1;
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
                                spr_hdr <= 3'd0;
                                trail_ph <= 6'd35;
                                spr_end = 1'b1;
                            end else begin
                                spr_i <= spr_i + 5'd1;
                                spr_hdr <= 3'd0;
                            end
                        end
                    end
                    if (trail_off[1:0] == 2'd3) begin
                        code_raddr <= 15'(trail_off[16:2] + 15'd1);
                        trail_off <= trail_off + 16'd1;
                        state <= S_RD;
                        ret_state <= spr_end ? S_TRAIL : S_SPR;
                    end else begin
                        trail_off <= trail_off + 16'd1;
                        if (spr_end) state <= S_TRAIL;
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
                        if (cstack_map_arr[csp - 7'd1] == 16'hFFFD) begin
                            stack[sp] <= -32'sd1;
                            stack_tag[sp] <= 3'd0; // findIndex miss
                        end else if (cstack_map_arr[csp - 7'd1] != 16'hFFFF &&
                            cstack_map_arr[csp - 7'd1] != 16'hFFFE) begin
                            stack[sp] <= {16'd0, cstack_map_arr[csp - 7'd1]};
                            stack_tag[sp] <= 3'd2;
                        end else begin
                            stack[sp] <= 32'sd0;
                            stack_tag[sp] <= 3'd5; // forEach void / find miss
                        end
                        sp <= sp + 8'd1;
                        arm_release_env(cstack_env[csp - 7'd1], S_FETCH_WAIT);
                        ip <= cstack_ip[csp - 7'd1];
                        this_obj <= cstack_this[csp - 7'd1];
                        if (this_ok) begin
                            vars[var_this] <= (cstack_this[csp - 7'd1] == 16'hFFFF)
                                              ? 32'd0
                                              : {16'd0, cstack_this[csp - 7'd1]};
                            var_tag[var_this] <= (cstack_this[csp - 7'd1] == 16'hFFFF)
                                                 ? 3'd5 : 3'd1;
                        end
                        csp <= csp - 7'd1;
                        code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd1]);
                        vfe_rd_arm <= 1'b0;
                    end else if (!vfe_rd_arm) begin
                        vfe_rd_arm <= 1'b1;
                    end else begin
                        vfe_rd_arm <= 1'b0;
                        // bind nparam args: el, then idx if the callback asked for it
                        begin
                            logic [15:0] foid;
                            logic [12:0] fo;
                            logic [5:0]  capn;
                            foid = cstack_fe_fn[csp - 7'd1];
                            fo = foid[12:0];
                            capn = (obj_n[fo] > 6'd2) ? 6'(obj_n[fo] - 6'd2) : 6'd0;
                            // Pass only parameters the callback declared.
                            // Always pushing `el` leaked one stack word per
                            // element for zero-argument map callbacks.
                            if (cstack_ctorobj[csp - 7'd1][7:0] >= 8'd1) begin
                                stack[sp] <= varr_rdata[31:0];
                                stack_tag[sp] <= varr_trdata;
                                if (cstack_ctorobj[csp - 7'd1][7:0] >= 8'd2) begin
                                    stack[sp + 8'd1] <= {24'd0, cstack_fe_i[csp - 7'd1]};
                                    stack_tag[sp + 8'd1] <= 3'd0;
                                    sp <= sp + 8'd2;
                                end else
                                    sp <= sp + 8'd1;
                            end
                            cstack_ip[csp] <= 16'hFFFE;
                            cstack_this[csp] <= this_obj;
                            cstack_isctor[csp] <= 1'b0;
                            cstack_isfe[csp] <= 1'b0;
                            enter_captured_fn(foid);
                            bump_csp();
                            ip <= tfn_entry[fo];
                            code_raddr <= 15'(ops_base + tfn_entry[fo]);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end
                S_WAIT_FRAME: if (jsb_flags[3]) begin
                    if (frame_tick)
                        v64_frame_armed <= 1'b1;
                    if (frame_tick || v64_frame_armed) begin
                        if (kev_rp != kev_wp) begin
                            v64_frame_armed <= 1'b1;
                            vnat_dom <= 3'd5;
                            valloc_kind <= 2'd0;
                            valloc_i <= vobj_next;
                            valloc_retried <= 1'b0;
                            state <= S_V64_ALLOC;
                        end else begin
                            v64_frame_armed <= 1'b0;
                        vframe_no <= vframe_no + 32'd1;
                        vraf_snap_n <= vraf_n;
                        vraf_i <= 4'd0;
                        for (int k = 0; k < 8; k++)
                            if (k < vraf_n)
                                vraf_snap[k] <= vraf[k];
                        vraf_n <= 4'd0;
                        state <= S_V64_FRAME_RAF;
                        end
                    end
                end else if (frame_tick) begin
                    joy_down_edge <= joy_in & ~prev_joy;
                    joy_up_edge <= prev_joy & ~joy_in;
                    prev_joy <= joy_in;
                    // NEW: the one implicit present per frame (see present_pend).
                    // An explicit swapBuffers in the pass already flipped —
                    // do not flip a second time (front would show the stale bank).
                    if (present_pend && !did_swap) fb_swap <= 1'b1;
                    present_pend <= 1'b0;
                    did_swap <= 1'b0;
                    // NEW: FM frame clock twin — Date.now advances once per rAF
                    // frame (machine.py vm.time_ms = frame*16.67). The old
                    // +17-per-CALL hack made game time race ahead: PACMAN
                    // ghosts sped up and the run left the maze stage unattended.
                    time_ms <= time_ms + 32'd17;
                    // NEW: tick timer delays once per frame (setTimeout ms/17)
                    for (int ti = 0; ti < TIMER_DEPTH; ti++)
                        if (ti < to_n && to_delay[ti] != 12'd0)
                            to_delay[ti] <= to_delay[ti] - 12'd1;
                    // NEW: per-frame array nursery — rewind MAKE_ARR temps so
                    // n_arr cannot saturate. Same as objects: do not wait for
                    // click_fired (boot rAF already allocates).
                    // NEW: object bump rewind the cycle BEFORE rAF/keys so
                    // enter_captured_fn's n_obj++ does not fight n_obj<=keep.
                    // Do not wait for click_fired — boot rAF/nextStage already
                    // allocate; an 8-frame post-click delay overflows first.
                    // RETIRED: the two watermark rewinds described above
                    // guessed liveness and recycled live callbacks/children.
                    // Start a real root trace; GC completion arms frame_fire.
                    gc_i <= 13'd0;
                    gc_qr <= 14'd0;
                    gc_qw <= 14'd0;
                    gc_obj_high <= 16'd0;
                    gc_arr_high <= 16'd0;
                    state <= S_GC_CLEAR;
                    // KEYBITS level → keys.a/d/space.pressed (HTML table the animate() reads)
                    if (keys_ok) begin
                        poke_pressed(id_a, joy_in[2]);
                        poke_pressed(id_d, joy_in[3]);
                        poke_pressed(id_kspace, joy_in[4]);
                    end
                    if (enter_n != 0 && enter_delay != 0)
                        enter_delay <= enter_delay - 4'd1;
                    end else if (frame_fire) begin
                    frame_fire <= 1'b0;
                    // KEYBITS edges → keydown/keyup with event.key + keyCode (HTML bindings)
                    // Skip when a KEYEVT is queued so GUI KEYEVT+KEYBITS does not double-fire.
                    if (kd_fn != 16'hFFFF && joy_down_edge != 0 && kev_rp == kev_wp) begin
                        joy_down_edge <= 6'd0;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        obj_cls[n_obj[12:0]] <= 0;
                        // heap slots via S_HEAP_* (OSETI) — tagged KEYBITS path
                        // NEW: frame boundary — reset the eval stack (leftovers
                        // are leaks; ~1 word/frame overflowed sp at ~500 frames)
                        stack[0] <= {16'd0, n_obj};
                        stack_tag[0] <= 3'd1;
                        boundary_sp(11'd1);
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
                    end else if (ku_fn != 16'hFFFF && joy_up_edge != 0 && kev_rp == kev_wp) begin
                        joy_up_edge <= 6'd0;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        // heap slots via S_HEAP_* (OSETI) — tagged KEYBITS path
                        stack[0] <= {16'd0, n_obj}; // frame boundary: fresh stack
                        stack_tag[0] <= 3'd1;
                        boundary_sp(11'd1);
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
                    // KEYEVT before rAF (PYTHON drains keys then rAF). Do not
                    // auto-fire click_fn — attract waits for Space / .click().
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
                        hp_cmd <= HP_OSETI;
                        hp_v64 <= 1'b0;
                        hp_oid <= n_obj[12:0];
                        hp_slot <= 5'd0;
                        hp_qn <= 3'd2;
                        hp_qi <= 3'd0;
                        hp_qk[0] <= id_key;
                        hp_qv[0] <= {48'd0,
                            (kev_q[kev_rp][7:0] == 8'd13) ? id_enter :
                            (kev_q[kev_rp][7:0] == 8'd32) ? id_space :
                            (kev_q[kev_rp][7:0] == 8'd37) ? id_arrow_l :
                            (kev_q[kev_rp][7:0] == 8'd39) ? id_arrow_r :
                            (kev_q[kev_rp][7:0] == 8'd38) ? id_arrow_u :
                            (kev_q[kev_rp][7:0] == 8'd40) ? id_arrow_d :
                            (kev_q[kev_rp][7:0] == 8'd65) ? id_a :
                            (kev_q[kev_rp][7:0] == 8'd68) ? id_d : 16'hFFFF};
                        hp_qt[0] <= ((kev_q[kev_rp][7:0] == 8'd13) ||
                            (kev_q[kev_rp][7:0] == 8'd32) ||
                            (kev_q[kev_rp][7:0] == 8'd37) ||
                            (kev_q[kev_rp][7:0] == 8'd39) ||
                            (kev_q[kev_rp][7:0] == 8'd38) ||
                            (kev_q[kev_rp][7:0] == 8'd40) ||
                            (kev_q[kev_rp][7:0] == 8'd65) ||
                            (kev_q[kev_rp][7:0] == 8'd68)) ? 3'd3 : 3'd5;
                        hp_qk[1] <= id_keycode;
                        hp_qv[1] <= {56'd0, kev_q[kev_rp][7:0]};
                        hp_qt[1] <= 3'd0;
                        hp_ret <= S_KEYEV;
                        stack[0] <= {16'd0, n_obj}; // frame boundary: fresh stack
                        stack_tag[0] <= 3'd1;
                        boundary_sp(11'd1);
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
                        state <= S_HEAP_WR;
                    end else if (raf_n != 0) begin
                        boundary_sp(11'd0); // frame boundary: checked eval stack
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
                        bump_csp();
                        code_raddr <= 15'(ops_base + fn_entry(raf_fn[0]));
                        state <= S_FETCH_WAIT;
                    end else if (looping) begin
                        ip <= '0;
                        boundary_sp(11'd0);
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
                        logic fn_ok;
                        foid = to_fn[0];
                        fo = foid[12:0];
                        // NEW: fire only a live Fn. A recycled oid here executed
                        // whatever code vobj_slot[VOBJ_AW'({fo, 5'(0)})][63:0] pointed at (often ip 0 =
                        // top level, which re-runs boot and resets globals).
                        fn_ok = (obj_cls[fo] == CLS_FN);
                        if (!fn_ok) dbg_tmr_mis <= dbg_tmr_mis + 16'd1;
                        if (fn_ok) begin
                            dbg_tmr_fire <= dbg_tmr_fire + 16'd1;
                            boundary_sp(11'd0);
                            ip <= tfn_entry[fo];
                        end
                        if (fn_ok && to_period[0] != 12'd0 && to_n == 7'd1) begin
                            to_delay[0] <= to_period[0]; // re-arm sole interval
                        end else if (fn_ok && to_period[0] != 12'd0) begin
                            for (int ti = 0; ti < TIMER_DEPTH - 1; ti++) begin
                                if (ti + 1 < to_n) begin
                                    to_fn[ti] <= to_fn[ti + 1];
                                    to_delay[ti] <= to_delay[ti + 1];
                                    to_period[ti] <= to_period[ti + 1];
                                    to_id[ti] <= to_id[ti + 1];
                                end
                            end
                            to_fn[to_n - 7'd1] <= foid;
                            to_delay[to_n - 7'd1] <= to_period[0];
                            to_period[to_n - 7'd1] <= to_period[0];
                            to_id[to_n - 7'd1] <= to_id[0];
                        end else begin
                            to_n <= to_n - 7'd1;
                            for (int ti = 0; ti < TIMER_DEPTH - 1; ti++) begin
                                if (ti + 1 < to_n) begin
                                    to_fn[ti] <= to_fn[ti + 1];
                                    to_delay[ti] <= to_delay[ti + 1];
                                    to_period[ti] <= to_period[ti + 1];
                                    to_id[ti] <= to_id[ti + 1];
                                end
                            end
                        end
                        if (fn_ok) begin
                            cstack_ip[csp] <= n_ops;
                            cstack_this[csp] <= this_obj;
                            cstack_isctor[csp] <= 1'b0;
                            cstack_isfe[csp] <= 1'b0;
                            enter_captured_fn(foid);
                            bump_csp();
                            code_raddr <= 15'(ops_base + tfn_entry[fo]);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end
                S_KEYEV: begin
                    // Event object was allocated last cycle (n_obj already bumped).
                    enter_captured_fn(kev_fn);
                    bump_csp();
                    ip <= fn_entry(kev_fn);
                    code_raddr <= 15'(ops_base + fn_entry(kev_fn));
                    state <= S_FETCH_WAIT;
                end
                S_ENV_LOAD: begin
                    // Sequential env slot walk (registered SRAM). Parent is
                    // 1-D tenv_parent, not a combo vobj_slot[VOBJ_AW'({eo, 5'(0)})][63:0] mux.
                    if (hp_phase == 3'd0) begin
                        hp_phase <= 3'd1;
                    end else if (hp_slot < obj_n[env_walk[12:0]]) begin
                        if (vobj_rdata[79:64] == {7'd0, env_ld_slot}) begin
                                if (env_is_store) begin
                                hp_cmd <= HP_OSETI;
                                hp_v64 <= 1'b0;
                                hp_oid <= env_walk[12:0];
                                hp_qn <= 3'd1;
                                hp_qi <= 3'd0;
                                hp_qk[0] <= {7'd0, env_ld_slot};
                                hp_qv[0] <= {32'd0, stack[sp - 8'd1]};
                                hp_qt[0] <= stack_tag[sp - 8'd1];
                                hp_tag <= stack_tag[sp - 8'd1];
                                sp <= sp - 8'd1;
                                hp_ret <= S_FETCH_WAIT;
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_HEAP_WR;
                                end else begin
                                stack[sp] <= vobj_rdata[31:0];
                                stack_tag[sp] <= vobj_trdata;
                                sp <= sp + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                            end
                        end else begin
                            hp_slot <= hp_slot + 5'd1;
                            hp_phase <= 3'd0;
                        end
                    end else if (tenv_parent[env_walk[12:0]] != 16'd0 &&
                                 tenv_parent[env_walk[12:0]] != env_walk) begin
                        env_walk <= tenv_parent[env_walk[12:0]];
                        hp_slot <= 5'd1;
                        hp_phase <= 3'd0;
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
                S_JSON: begin
                    // Walk nested arrays/objects/numbers into json_mem (VM cap).
                    if (js_sp == 6'd0) begin
                        obj_cls[n_obj[12:0]] <= CLS_DYNSTR;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        hp_cmd <= HP_OSETI;
                        hp_v64 <= 1'b0;
                        hp_oid <= n_obj[12:0];
                        hp_slot <= 5'd0;
                        hp_qn <= 3'd2;
                        hp_qi <= 3'd0;
                        hp_qk[0] <= 16'd0;
                        hp_qv[0] <= 64'd0;
                        hp_qt[0] <= 3'd0;
                        hp_qk[1] <= 16'd1;
                        hp_qv[1] <= {50'd0, json_wp};
                        hp_qt[1] <= 3'd0;
                        stack[json_res] <= {16'd0, n_obj};
                        stack_tag[json_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        hp_ret <= S_FETCH_WAIT;
                        state <= S_HEAP_WR;
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
                                vjs_rd_arm <= 1'b0;
                            end else if (ii != 8'd0) begin
                                json_putc(8'h2C);
                                js_ph[t] <= 3'd2;
                                vjs_rd_arm <= 1'b0;
                            end else if (!vjs_rd_arm) begin
                                vjs_rd_arm <= 1'b1;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= varr_trdata;
                                js_val[js_sp] <= varr_rdata[31:0];
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= js_sp + 6'd1;
                                vjs_rd_arm <= 1'b0;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_sp <= t;
                                vjs_rd_arm <= 1'b0;
                            end
                        end else if (ph == 3'd2) begin
                            if (tg == 3'd1) begin
                                json_putc(8'h3A);
                                if (!vjs_rd_arm)
                                    vjs_rd_arm <= 1'b1;
                                else if (js_sp < JSON_STK[5:0]) begin
                                    js_tag[js_sp] <= vobj_trdata;
                                    js_val[js_sp] <= vobj_rdata[31:0];
                                    js_i[js_sp] <= 8'd0;
                                    js_ph[js_sp] <= 3'd0;
                                    js_i[t] <= ii + 8'd1;
                                    js_ph[t] <= 3'd5;
                                    js_sp <= js_sp + 6'd1;
                                    vjs_rd_arm <= 1'b0;
                                end else begin
                                    js_sp <= t;
                                    vjs_rd_arm <= 1'b0;
                                end
                            end else if (!vjs_rd_arm) begin
                                vjs_rd_arm <= 1'b1;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                js_tag[js_sp] <= varr_trdata;
                                js_val[js_sp] <= varr_rdata[31:0];
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_ph[t] <= 3'd1;
                                js_sp <= js_sp + 6'd1;
                                vjs_rd_arm <= 1'b0;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_sp <= t;
                                vjs_rd_arm <= 1'b0;
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
                            end else if (!vjs_rd_arm) begin
                                vjs_rd_arm <= 1'b1;
                            end else begin
                                json_putc((name_len_tbl[vobj_rdata[73:64]] == 8'd1)
                                    ? name_hash_tbl[vobj_rdata[73:64]][7:0] : 8'h5F);
                                js_ph[t] <= 3'd8;
                                vjs_rd_arm <= 1'b0;
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
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
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
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
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
                        if (v64_repl) begin
                            if (!vfree_armed) begin
                                vfree_armed <= 1'b1;
                                valloc_i <= 14'd0;
                                hp_ret <= S_REPL;
                                state <= S_FREE_OBJ;
                            end else begin
                                vfree_armed <= 1'b0;
                                v64_repl <= 1'b0;
                                if (vfree_ok) begin
                                    vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                    vobj_builtin[valloc_i[12:0]] <= 4'd7;
                                    vobj_len[valloc_i[12:0]] <= 6'd2;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd7, 2'd0, 6'd2});
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd2;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= 16'd0;
                                    hp_qv[0] <= v64_int32_number({18'd0, json_wp});
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= 16'd1;
                                    hp_qv[1] <= v64_int32_number(
                                        {18'd0, json_dst - json_wp});
                                    hp_qt[1] <= 3'd0;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd5, vobj_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vsp <= vnat_base + 12'd1;
                                    vobj_next <= valloc_i + 14'd1;
                                    code_raddr <= 15'(ops_base + ip);
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3;
                                    running <= 1'b0;
                                    state <= S_DONE;
                                end
                            end
                        end else begin
                        obj_cls[n_obj[12:0]] <= CLS_DYNSTR;
                        obj_n[n_obj[12:0]] <= 6'd2;
                        hp_cmd <= HP_OSETI;
                        hp_v64 <= 1'b0;
                        hp_oid <= n_obj[12:0];
                        hp_slot <= 5'd0;
                        hp_qn <= 3'd2;
                        hp_qi <= 3'd0;
                        hp_qk[0] <= 16'd0;
                        hp_qv[0] <= {50'd0, json_wp};
                        hp_qt[0] <= 3'd0;
                        hp_qk[1] <= 16'd1;
                        hp_qv[1] <= {50'd0, json_dst - json_wp};
                        hp_qt[1] <= 3'd0;
                        stack[json_res] <= {16'd0, n_obj};
                        stack_tag[json_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= json_res + 11'd1;
                        code_raddr <= 15'(ops_base + ip);
                        hp_ret <= S_FETCH_WAIT;
                        state <= S_HEAP_WR;
                        end
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
                // NEW: str[i] result. name_rdata now holds the character. A 1-char
                // interned name has hash == its byte, so char_id turns the byte
                // straight into that intern id and OP_EQ compares it to a "x"
                // literal with no string walk. A character the program never wrote
                // as a literal cannot equal any literal, so undefined is correct.
                S_STR_WR: begin
                    // NEW: append the staged characters of a joined string to
                    // name_mem. names_n was bumped in S_JOIN_FIND, so the id
                    // being filled in is names_n-1.
                    if (txt_i >= 7'(jn_len)) begin
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else begin
                        name_mem[nb_wp[14:0]] <= txt_buf[txt_i[5:0]];
                        if (jn_len == 8'd1 && !char_ok[txt_buf[txt_i[5:0]]]) begin
                            char_id[txt_buf[txt_i[5:0]]] <= names_n - 16'd1;
                            char_ok[txt_buf[txt_i[5:0]]] <= 1'b1;
                        end
                        nb_wp <= nb_wp + 16'd1;
                        txt_i <= txt_i + 7'd1;
                    end
                end
                S_FONTPX: begin
                    // NEW: ctx.font size. Walk the string for the first digit run
                    // that is followed by 'p' — the same first-match the FM regex
                    // (\d+)\s*px takes, so '12px/20px' and 'bold 24px X' agree.
                    if (txt_ph == 4'd0) begin
                        name_rdaddr <= name_rdaddr + 16'd1; // prime byte 1
                        txt_ph <= 4'd1;
                    end else begin
                        logic got;
                        got = 1'b0;
                        if (name_rdata >= 8'h30 && name_rdata <= 8'h39)
                            fpx_acc <= (fpx_acc >= 8'd26) ? fpx_acc
                                     : (fpx_acc * 8'd10 + (name_rdata - 8'h30));
                        else if ((name_rdata == 8'h70 || name_rdata == 8'h50) &&
                                 fpx_acc != 8'd0) begin
                            ctx_font_px <= fpx_acc;
                            got = 1'b1;
                        end else if (name_rdata != 8'h20)
                            fpx_acc <= 8'd0; // digits not followed by px
                        if (got || fp_left <= 8'd1) begin
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end else begin
                            fp_left <= fp_left - 8'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                end
                S_TXT_LD: begin
                    // NEW: stage the fillText argument into txt_buf. Interned
                    // strings come from name_mem, joined/JSON strings from
                    // json_mem, numbers are expanded to digits — after this the
                    // raster never cares where the text came from.
                    case (txt_ph)
                        4'd0: begin
                            // FM _font_scale: max(1, round(px * ctx_sx / 8))
                            txt_kp <= 48'(ctx_font_px) * 48'(ctx_sx);
                            txt_ph <= 4'd1;
                        end
                        4'd1: begin
                            logic signed [47:0] kq;
                            logic [7:0] nl;
                            kq = (txt_kp + 48'sd262144) >>> 19;
                            txt_k <= (kq < 48'sd1) ? 4'd1
                                   : (kq > 48'sd15) ? 4'd15 : 4'(kq);
                            txt_i <= 7'd0; txt_bn <= 7'd0; txt_d <= 4'd0;
                            if (txt_vt == 3'd3 && names_ok && name_has[txt_val[9:0]]) begin
                                nl = name_len_tbl[txt_val[9:0]];
                                txt_len <= (nl > 8'(TXT_MAX)) ? 7'(TXT_MAX) : 7'(nl);
                                name_rdaddr <= name_off[txt_val[9:0]];
                                txt_ph <= (nl == 8'd0) ? 4'd6 : 4'd2;
                            end else if (txt_vt == 3'd1 &&
                                         obj_cls[txt_val[12:0]] == CLS_DYNSTR) begin
                                hp_cmd <= HP_OGETI;
                                hp_v64 <= 1'b0;
                                hp_oid <= txt_val[12:0];
                                hp_slot <= 5'd0;
                                hp_qn <= 3'd2;
                                hp_qi <= 3'd0;
                                hp_nat <= 4'd9;
                                hp_ret <= S_V64_OGETI_NAT;
                                state <= S_HEAP_WAIT;
                            end else if (txt_vt == 3'd0 || txt_vt == 3'd7) begin
                                logic signed [31:0] iv;
                                iv = fxi(txt_val, txt_vt);
                                if (iv < 0) begin
                                    txt_buf[0] <= 8'h2D; // '-'
                                    txt_bn <= 7'd1;
                                    iv = -iv;
                                end
                                txt_v <= iv;
                                txt_pi <= (iv >= 32'sd1000000000) ? 4'd9
                                        : (iv >= 32'sd100000000) ? 4'd8
                                        : (iv >= 32'sd10000000) ? 4'd7
                                        : (iv >= 32'sd1000000) ? 4'd6
                                        : (iv >= 32'sd100000) ? 4'd5
                                        : (iv >= 32'sd10000) ? 4'd4
                                        : (iv >= 32'sd1000) ? 4'd3
                                        : (iv >= 32'sd100) ? 4'd2
                                        : (iv >= 32'sd10) ? 4'd1 : 4'd0;
                                txt_ph <= 4'd5;
                            end else begin
                                // hash-only intern (no bytes) or undefined: draw
                                // nothing and count it — never a bar of garbage
                                txt_len <= 7'd0;
                                dbg_str_ovf <= dbg_str_ovf + 16'd1;
                                txt_ph <= 4'd6;
                            end
                        end
                        4'd2: begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 1
                            txt_ph <= 4'd3;
                        end
                        4'd3: begin
                            txt_buf[txt_i[5:0]] <= name_rdata;
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                name_rdaddr <= name_rdaddr + 16'd1;
                            end
                        end
                        4'd4: begin
                            txt_buf[txt_i[5:0]] <= json_mem[txt_rp[12:0]];
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                txt_rp <= txt_rp + 16'd1;
                            end
                        end
                        4'd5: begin
                            // MSD-first digits (no divider): subtract P10 and count
                            if (txt_v >= 32'(P10[txt_pi])) begin
                                txt_v <= txt_v - 32'(P10[txt_pi]);
                                txt_d <= txt_d + 4'd1;
                            end else begin
                                txt_buf[txt_bn[5:0]] <= 8'h30 + {4'd0, txt_d};
                                txt_bn <= txt_bn + 7'd1;
                                txt_d <= 4'd0;
                                if (txt_pi == 4'd0) begin
                                    txt_len <= txt_bn + 7'd1;
                                    txt_ph <= 4'd6;
                                end else txt_pi <= txt_pi - 4'd1;
                            end
                        end
                        default: begin
                            // FM fill_text: centre/right shift the pen by the text
                            // width, and y is a baseline (top = y - 8*scale)
                            logic [15:0] w_;
                            w_ = 16'(txt_len) * 16'd8 * 16'(txt_k);
                            txt_x0 <= txt_px - ((ctx_align == 2'd1) ? 16'($signed(w_) >>> 1)
                                             : (ctx_align == 2'd2) ? 16'($signed(w_))
                                             : 16'sd0);
                            txt_y0 <= txt_py - 16'(8 * {12'd0, txt_k});
                            if (txt_len == 7'd0) begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                font_raddr <= {txt_buf[0][6:0], 3'd0};
                                txt_i <= 7'd0; txt_row <= 3'd0; txt_col <= 3'd0;
                                txt_kx <= 4'd0; txt_ky <= 4'd0;
                                txt_ph <= 4'd0;
                                state <= S_TXT_DRAW;
                            end
                        end
                    endcase
                end
                S_TXT_DRAW: begin
                    // NEW: 8x8 glyph raster, one pixel per cycle, scaled k*k.
                    // Set bits only (transparent background, like FM fill_text).
                    if (txt_ph == 4'd0) txt_ph <= 4'd1; // font_rom read latency
                    else if (txt_ph == 4'd1) begin
                        txt_bits <= font_rdata;
                        txt_col <= 3'd0; txt_kx <= 4'd0; txt_ky <= 4'd0;
                        txt_ph <= 4'd2;
                    end else begin
                        logic signed [31:0] xx, yy;
                        logic on, adv;
                        logic [6:0] ni_;
                        ni_ = txt_i + 7'd1;
                        on = txt_bits[3'd7 - txt_col];
                        xx = $signed({16'd0, txt_x0})
                           + ((32'({2'd0, txt_i}) * 32'sd8 + 32'({29'd0, txt_col}))
                              * 32'({28'd0, txt_k}))
                           + 32'({28'd0, txt_kx});
                        yy = $signed({16'd0, txt_y0})
                           + (32'({29'd0, txt_row}) * 32'({28'd0, txt_k}))
                           + 32'({28'd0, txt_ky});
                        if (on && xx >= 32'sd0 && xx < $signed(32'(MW)) &&
                            yy >= 32'sd0 && yy < $signed(32'(MH))) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(yy) * 19'(MW) + 19'(xx);
                            fb_wdata <= color;
                        end
                        // clear pixels cost no time: skip the whole k*k block
                        adv = 1'b0;
                        if (!on) adv = 1'b1;
                        else if (txt_kx + 4'd1 >= txt_k) begin
                            if (txt_ky + 4'd1 >= txt_k) adv = 1'b1;
                            else begin txt_ky <= txt_ky + 4'd1; txt_kx <= 4'd0; end
                        end else txt_kx <= txt_kx + 4'd1;
                        if (adv) begin
                            txt_kx <= 4'd0; txt_ky <= 4'd0;
                            if (txt_col != 3'd7) txt_col <= txt_col + 3'd1;
                            else if (txt_row != 3'd7) begin
                                txt_row <= txt_row + 3'd1;
                                font_raddr <= {txt_buf[txt_i[5:0]][6:0], txt_row + 3'd1};
                                txt_ph <= 4'd0;
                            end else if (txt_i + 7'd1 >= txt_len) begin
                                code_raddr <= 15'(ops_base + ip);
                                state <= S_FETCH_WAIT;
                            end else begin
                                txt_i <= txt_i + 7'd1;
                                txt_row <= 3'd0;
                                font_raddr <= {txt_buf[ni_[5:0]][6:0], 3'd0};
                                txt_ph <= 4'd0;
                            end
                        end
                    end
                end
                S_NAMCPY: begin
                    // interned name_mem → json_mem via registered name_rdata
                    // (same BRAM lag as str[i]; do not combinational-read NAME_CAP).
                    if (!namcpy_armed) namcpy_armed <= 1'b1;
                    else begin
                        if (json_wp < 14'(JSON_CAP))
                            json_mem[json_wp[12:0]] <= name_rdata;
                        if (json_wp + 14'd1 >= json_srclen || json_wp + 14'd1 >= 14'(JSON_CAP)) begin
                            json_src <= 14'd0;
                            json_rp <= 14'd0;
                            namcpy_armed <= 1'b0;
                            if (namcpy_v64) begin
                                namcpy_v64 <= 1'b0;
                                json_wp <= 14'd0;
                                state <= S_V64_JSON_PARSE;
                            end else if (namcpy_repl) begin
                                json_dst <= json_srclen;
                                json_wp <= json_srclen;
                                state <= S_REPL;
                            end else if (hp_nat == 4'd3) begin
                                // interned indexOf: name_mem was copied 1 byte/clock
                                json_src <= 14'd0;
                                json_rp <= 14'd0;
                                json_wp <= 14'd0;
                                idx_needle <= hp_wval[7:0];
                                state <= S_IDXSTR;
                            end else begin
                                json_wp <= 14'd0;
                                state <= S_JSON_PARSE;
                            end
                        end else begin
                            json_wp <= json_wp + 14'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                            namcpy_armed <= 1'b0;
                        end
                    end
                end
                S_STRIDX: state <= S_STRIDX_WR; // wait: name_rdata lags name_rdaddr 1 cycle
                S_STRIDX_WR: begin
                    // name_rdata is this char. Prefetch i+1 so the next sequential
                    // str[i] hits in EXEC (string-row sprites: row[col]==="1").
                    if (char_ok[name_rdata]) begin
                        stack[str_res] <= {16'd0, char_id[name_rdata]};
                        stack_tag[str_res] <= 3'd3;
                    end else begin
                        stack[str_res] <= 32'sd0;
                        stack_tag[str_res] <= 3'd5;
                    end
                    name_rdaddr <= name_rdaddr + 16'd1;
                    str_pf_ci <= str_pf_ci + 32'sd1;
                    str_pf_ok <= 1'b1;
                    code_raddr <= 15'(ops_base + ip);
                    state <= S_FETCH_WAIT;
                end
                S_IDXSTR: begin
                    // Value64 dynstr indexOf (hp_v64) writes the IEEE index;
                    // tagged CPU keeps json_res. One json_mem byte/clock.
                    if (json_rp >= json_src + json_srclen) begin
                        if (hp_v64) begin
                            vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                            vsp <= hp_vbase + 12'd1;
                        end else begin
                            stack[json_res] <= -32'sd1;
                            stack_tag[json_res] <= 3'd0;
                            sp <= json_res + 11'd1;
                        end
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else if (json_mem[json_rp[12:0]] == idx_needle) begin
                        if (hp_v64) begin
                            vst_wr(hp_vbase,
                                v64_int32_number(32'(json_rp - json_src)));
                            vsp <= hp_vbase + 12'd1;
                        end else begin
                            stack[json_res] <= 32'(json_rp - json_src);
                            stack_tag[json_res] <= 3'd0;
                            sp <= json_res + 11'd1;
                        end
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                    end else json_rp <= json_rp + 14'd1;
                end
                S_IMGD_GET: begin
                    // Copy back-buffer rect into the one snapshot (dump_back is
                    // registered 1 cycle after dump_raddr). S_CLEAR twin: one
                    // index, always i++ until n — 10-bit x+w wrap spun until
                    // the 16M FRAME cap. 1 px/cycle × 307200 fits; do not
                    // raise the cap. Host FB? must not walk dump_sel (GET
                    // holds it).
                    fb_we <= 1'b0;
                    fb_dump_sel <= 1'b1;
                    if (imgd_n == 19'd0) begin
                        if (imgd_v64) begin
                            // Value64 ImageData handle (same snapshot buffer).
                            if (!vfree_armed) begin
                                vfree_armed <= 1'b1;
                                valloc_i <= 14'd0;
                                hp_ret <= S_IMGD_GET;
                                state <= S_FREE_OBJ;
                            end else begin
                                vfree_armed <= 1'b0;
                                if (vfree_ok) begin
                                    vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                    vobj_cls[valloc_i[12:0]] <= CLS_IMGD;
                                    vobj_len[valloc_i[12:0]] <= 6'd2;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd0, 2'd0, 6'd2});
                                    e64_p_addr2 <= CLS_IMGD;
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd2;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_width;
                                    hp_qv[0] <= v64_int32_number({22'd0, imgd_w});
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= id_height;
                                    hp_qv[1] <= v64_int32_number({22'd0, imgd_h});
                                    hp_qt[1] <= 3'd0;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd5, vobj_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vsp <= vnat_base + 12'd1;
                                    vobj_next <= valloc_i + 14'd1;
                                    imgd_v64 <= 1'b0;
                                    fb_dump_sel <= 1'b0;
                                    code_raddr <= 15'(ops_base + ip);
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else begin
                                    machine_fault <= 1'b1; fault_code <= 8'd3;
                                    running <= 1'b0; state <= S_DONE;
                                end
                            end
                        end else begin
                        obj_cls[n_obj[12:0]] <= CLS_IMGD;
                        obj_n[n_obj[12:0]] <= 6'd2;
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                        stack[imgd_res] <= {16'd0, n_obj};
                        stack_tag[imgd_res] <= 3'd1;
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= imgd_res + 11'd1;
                        fb_dump_sel <= 1'b0;
                        code_raddr <= 15'(ops_base + ip);
                        state <= S_FETCH_WAIT;
                        end
                    end else if (!imgd_armed) begin
                        imgd_armed <= 1'b1;
                    end else begin
                        if (imgd_i < 19'(FB_PIXELS))
                            imgd_pix[imgd_i] <= fb_dump_back;
                        if (imgd_i == (imgd_n - 19'd1)) begin
                            if (imgd_v64) begin
                                if (!vfree_armed) begin
                                    vfree_armed <= 1'b1;
                                    valloc_i <= 14'd0;
                                    hp_ret <= S_IMGD_GET;
                                    state <= S_FREE_OBJ;
                                end else begin
                                    vfree_armed <= 1'b0;
                                    if (vfree_ok) begin
                                        vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                        vobj_cls[valloc_i[12:0]] <= CLS_IMGD;
                                        vobj_len[valloc_i[12:0]] <= 6'd2;
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd0, 2'd0, 6'd2});
                                        e64_p_addr2 <= CLS_IMGD;
                                        hp_cmd <= HP_OSETI;
                                        hp_v64 <= 1'b1;
                                        hp_oid <= valloc_i[12:0];
                                        hp_slot <= 5'd0;
                                        hp_qn <= 3'd2;
                                        hp_qi <= 3'd0;
                                        hp_qk[0] <= id_width;
                                        hp_qv[0] <= v64_int32_number({22'd0, imgd_w});
                                        hp_qt[0] <= 3'd0;
                                        hp_qk[1] <= id_height;
                                        hp_qv[1] <= v64_int32_number({22'd0, imgd_h});
                                        hp_qt[1] <= 3'd0;
                                        vst_wr(vnat_base, v64_handle(
                                            4'd5, vobj_gen[valloc_i[12:0]],
                                            {19'd0, valloc_i[12:0]}
                                        ));
                                        vsp <= vnat_base + 12'd1;
                                        vobj_next <= valloc_i + 14'd1;
                                        imgd_v64 <= 1'b0;
                                        fb_dump_sel <= 1'b0;
                                        code_raddr <= 15'(ops_base + ip);
                                        hp_ret <= S_FETCH_WAIT;
                                        state <= S_HEAP_WR;
                                    end else begin
                                        machine_fault <= 1'b1; fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end
                                end
                            end else begin
                            obj_cls[n_obj[12:0]] <= CLS_IMGD;
                            obj_n[n_obj[12:0]] <= 6'd2;
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                            stack[imgd_res] <= {16'd0, n_obj};
                            stack_tag[imgd_res] <= 3'd1;
                            if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp <= imgd_res + 11'd1;
                            fb_dump_sel <= 1'b0;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                            end
                        end else begin
                            imgd_i <= imgd_i + 19'd1;
                            if (imgd_x >= (imgd_x0 + imgd_w - 10'd1) || imgd_x == 10'(MW - 1)) begin
                                imgd_x <= imgd_x0;
                                imgd_y <= imgd_y + 10'd1;
                                fb_dump_addr <= 19'(imgd_y + 10'd1) * 19'(MW) + 19'(imgd_x0);
                            end else begin
                                imgd_x <= imgd_x + 10'd1;
                                fb_dump_addr <= 19'(imgd_y) * 19'(MW) + 19'(imgd_x + 10'd1);
                            end
                        end
                    end
                end
                S_IMGD_PUT: begin
                    if (imgd_w == 10'd0 || imgd_h == 10'd0) begin
                        if (imgd_v64) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            vsp <= vnat_base + 12'd1;
                            imgd_v64 <= 1'b0;
                        end
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
                                if (imgd_v64) begin
                                    vst_wr(vnat_base, V64_UNDEFINED);
                                    vsp <= vnat_base + 12'd1;
                                    imgd_v64 <= 1'b0;
                                end
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
                S_GC_CLEAR: begin
                    gc_obj_mark[gc_i] <= 1'b0;
                    if (gc_i < 13'(MAX_ARR))
                        gc_arr_mark[gc_i[11:0]] <= 1'b0;
                    if (gc_i == 13'(MAX_OBJ - 1)) begin
                        gc_root_i <= 13'd0;
                        state <= S_GC_ROOT;
                    end else
                        gc_i <= gc_i + 13'd1;
                end
                S_GC_ROOT: begin
                    // vars, eval stack, callback queues/listeners, active envs,
                    // native-held objects, prototype cache, then call frames.
                    if (gc_root_i < 13'd512) begin
                        if (var_init[gc_root_i[8:0]])
                            gc_mark_value(
                                var_tag[gc_root_i[8:0]],
                                vars[gc_root_i[8:0]]
                            );
                    end else if (gc_root_i < 13'd2560) begin
                        if ((gc_root_i - 13'd512) < sp)
                            gc_mark_value(
                                stack_tag[gc_root_i - 13'd512],
                                stack[gc_root_i - 13'd512]
                            );
                    end else if (gc_root_i < 13'd2568) begin
                        if ((gc_root_i - 13'd2560) < raf_n)
                            gc_mark_obj(raf_fn[gc_root_i - 13'd2560]);
                    end else if (gc_root_i < 13'd2632) begin
                        if ((gc_root_i - 13'd2568) < to_n)
                            gc_mark_obj(to_fn[gc_root_i - 13'd2568]);
                    end else if (gc_root_i < 13'd2636) begin
                        if ((gc_root_i - 13'd2632) < kd_n)
                            gc_mark_obj(kd_slot[gc_root_i - 13'd2632]);
                    end else if (gc_root_i < 13'd2640) begin
                        if ((gc_root_i - 13'd2636) < ku_n)
                            gc_mark_obj(ku_slot[gc_root_i - 13'd2636]);
                    end else if (gc_root_i < 13'd2672) begin
                        if ((gc_root_i - 13'd2640) < env_sp)
                            gc_mark_obj(env_oid[gc_root_i - 13'd2640]);
                    end else if (gc_root_i == 13'd2672) begin
                        if (metrics_oid != 16'hFFFF) gc_mark_obj(metrics_oid);
                    end else if (gc_root_i == 13'd2673) begin
                        if (keys_a_oid != 16'hFFFF) gc_mark_obj(keys_a_oid);
                    end else if (gc_root_i == 13'd2674) begin
                        if (keys_d_oid != 16'hFFFF) gc_mark_obj(keys_d_oid);
                    end else if (gc_root_i == 13'd2675) begin
                        if (keys_sp_oid != 16'hFFFF) gc_mark_obj(keys_sp_oid);
                    end else if (gc_root_i == 13'd2676) begin
                        if (this_ok) gc_mark_obj(this_obj);
                    end else if (gc_root_i == 13'd2677) begin
                        if (kev_obj < n_obj) gc_mark_obj(kev_obj);
                    end else if (gc_root_i == 13'd2678) begin
                        if (click_fn != 16'hFFFF) gc_mark_obj(click_fn);
                    end else if (gc_root_i == 13'd2679) begin
                        if (kd_fn != 16'hFFFF) gc_mark_obj(kd_fn);
                    end else if (gc_root_i == 13'd2680) begin
                        if (ku_fn != 16'hFFFF) gc_mark_obj(ku_fn);
                    end else if (gc_root_i < 13'd2745) begin
                        if ((gc_root_i - 13'd2681) < n_fn_proto)
                            gc_mark_obj(fn_proto_oid[gc_root_i - 13'd2681]);
                    end else if (gc_root_i < 13'd2873) begin
                        if ((gc_root_i - 13'd2745) < csp)
                            gc_mark_obj(cstack_this[gc_root_i - 13'd2745]);
                    end else if (gc_root_i < 13'd3001) begin
                        if ((gc_root_i - 13'd2873) < csp &&
                            cstack_isctor[gc_root_i - 13'd2873])
                            gc_mark_obj(cstack_ctorobj[gc_root_i - 13'd2873]);
                    end else if (gc_root_i < 13'd3129) begin
                        if ((gc_root_i - 13'd3001) < csp &&
                            cstack_isfe[gc_root_i - 13'd3001])
                            gc_mark_value(
                                3'd2,
                                {16'd0, cstack_fe_arr[gc_root_i - 13'd3001]}
                            );
                    end else if (gc_root_i < 13'd3257) begin
                        if ((gc_root_i - 13'd3129) < csp &&
                            cstack_isfe[gc_root_i - 13'd3129])
                            gc_mark_obj(cstack_fe_fn[gc_root_i - 13'd3129]);
                    end
                    if (gc_root_i == 13'd3256)
                        state <= S_GC_POP;
                    else
                        gc_root_i <= gc_root_i + 13'd1;
                end
                S_GC_POP: begin
                    if (gc_qr == gc_qw) begin
                        // Tail sweep: every retained handle keeps its index.
                        n_obj <= gc_obj_high;
                        n_arr <= gc_arr_high;
                        n_obj_keep <= gc_obj_high;
                        n_arr_keep <= gc_arr_high;
                        obj_keep_ok <= 1'b1;
                        arr_keep_ok <= 1'b1;
                        dbg_gc_n <= dbg_gc_n + 16'd1;
                        frame_fire <= 1'b1;
                        state <= S_WAIT_FRAME;
                    end else begin
                        gc_cur <= gc_queue[gc_qr];
                        gc_qr <= gc_qr + 14'd1;
                        gc_slot <= 7'd0;
                        state <= gc_queue[gc_qr][13] ? S_GC_ARR : S_GC_OBJ;
                    end
                end
                S_GC_OBJ: begin
                    if (gc_slot < obj_n[gc_cur[12:0]]) begin
                        if (obj_cls[gc_cur[12:0]] == CLS_ENV &&
                            gc_slot == 7'd0) begin
                            if (tenv_parent[gc_cur[12:0]] != 16'd0)
                                gc_mark_obj(tenv_parent[gc_cur[12:0]]);
                        gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end else if (obj_cls[gc_cur[12:0]] == CLS_FN &&
                                     gc_slot == 7'd2) begin
                            if (tfn_parent[gc_cur[12:0]] != 16'd0)
                                gc_mark_obj(tfn_parent[gc_cur[12:0]]);
                            gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end else if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            gc_mark_value(vobj_trdata, vobj_rdata[31:0]);
                            gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        state <= S_GC_POP;
                    end
                end
                S_GC_ARR: begin
                    if (gc_slot < arr_len[gc_cur[11:0]]) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            gc_mark_value(varr_trdata, varr_rdata[31:0]);
                        gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        state <= S_GC_POP;
                    end
                end
                // S_V64_EXEC body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                S_V64_ALLOC: begin
                    if (valloc_kind == 2'd1) begin
                            logic [15:0] count;
                        logic need_long;
                        // Latched at OP_MAKE_ARR / Array(n). Do not use
                        // code_rdata here — GC resume would re-decode a
                        // different word as the length.
                        count = {8'd0, valloc_arr_n};
                        need_long = (count > 16'(ARR_SHORT_CAP));
                        if ((!need_long && valloc_i < MAX_ARR &&
                             !varr_valid[valloc_i[11:0]] &&
                             (valloc_i < 14'(MAX_ARR_SHORT) ||
                              !vlong_used[valloc_i[7:0]])) ||
                            (need_long && valloc_i >= 14'(MAX_ARR_SHORT) &&
                             valloc_i < MAX_ARR &&
                             !varr_valid[valloc_i[11:0]] &&
                             !vlong_used[valloc_i[7:0]])) begin
                            logic take_long;
                            take_long = need_long ||
                                (valloc_i >= 14'(MAX_ARR_SHORT));
                            varr_valid[valloc_i[11:0]] <= 1'b1;
                            varr_len[valloc_i[11:0]] <= count[7:0];
                            varr_long[valloc_i[11:0]] <= take_long;
                            e64_poke(6'd45, {4'd0, valloc_i[11:0]},
                                     {55'd0, take_long, count[7:0]});
                            e64_p_addr2 <= {8'd0, valloc_i[7:0]};
                            if (take_long) begin
                                varr_lidx[valloc_i[11:0]] <= valloc_i[7:0];
                                vlong_used[valloc_i[7:0]] <= 1'b1;
                            end
                            varr_next <= valloc_i + 14'd1;
                            if (vnat_dom == 3'd7) begin
                                vst_wr(vnat_base, v64_handle(
                                    4'd6, varr_gen[valloc_i[11:0]],
                                    {20'd0, valloc_i[11:0]}
                                ));
                                vsp <= vnat_base + 12'd1;
                                vnat_dom <= 3'd0;
                                hp_make_arr <= 1'b0;
                            end else if (count == 16'd0) begin
                                vst_wr(vsp, v64_handle(
                                    4'd6, varr_gen[valloc_i[11:0]],
                                    {20'd0, valloc_i[11:0]}
                                ));
                                vsp <= vsp + 12'd1;
                            end else begin
                                // Leave e0..eN-1 on the stack; S_HEAP_FILL
                                // copies them, then writes the handle at vbase.
                                hp_make_arr <= 1'b1;
                                hp_rval <= v64_handle(
                                4'd6, varr_gen[valloc_i[11:0]],
                                {20'd0, valloc_i[11:0]}
                            );
                            vsp <= vsp - count + 12'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            if (count == 16'd0)
                            state <= S_FETCH_WAIT;
                            else begin
                                hp_cmd <= HP_AFILL;
                                hp_v64 <= 1'b1;
                                hp_from_stack <= (vnat_dom != 3'd7);
                                hp_aid <= valloc_i[11:0];
                                hp_aslot <= 7'd0;
                                hp_lim <= count[7:0];
                                hp_vbase <= (vnat_dom == 3'd7)
                                    ? 12'd0 : (vsp - count);
                                hp_wval <= V64_UNDEFINED;
                                hp_ret <= S_FETCH_WAIT;
                                state <= S_HEAP_FILL;
                            end
                        end else if (valloc_i + 14'd1 < MAX_ARR) begin
                            valloc_i <= valloc_i + 14'd1;
                        end else if (!valloc_retried) begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b0;
                            state <= S_V64_GC_CLEAR;
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                        end
                    end else if (valloc_kind == 2'd3) begin
                        if (valloc_i < ENV_DEPTH &&
                            !venv_valid[valloc_i[9:0]]) begin
                            logic [11:0] base_sp;
                            logic [7:0] nparam;
                            logic [63:0] function_handle, parent_env;
                            base_sp = vsp - vcall_argc -
                                      (vcall_value ? 12'd1 : 12'd0);
                            function_handle = vcall_value
                                ? `VST_AT(vsp - vcall_argc - 12'd1)
                                : V64_UNDEFINED;
                            parent_env = vcall_value
                                ? vfn_env[function_handle[12:0]] : venv;
                            nparam = vcall_value
                                ? {2'd0, vfn_nparam[function_handle[12:0]]}
                                : vcall_argc;
                            venv_valid[valloc_i[9:0]] <= 1'b1;
                            venv_len[valloc_i[9:0]] <= 5'd0;
                            e64_poke(6'd46, {6'd0, valloc_i[9:0]},
                                     {52'd0, venv_gen[valloc_i[9:0]]});
                            venv_parent[valloc_i[9:0]] <= parent_env;
                            venv_next <= valloc_i[9:0] + 10'd1;
                            vframe_return_ip[vcsp] <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc : ip + 16'd1;
                            vframe_base_sp[vcsp] <= base_sp;
                            vframe_this[vcsp] <= vthis;
                            vframe_env[vcsp] <= venv;
                            vframe_fn[vcsp] <= function_handle;
                            vframe_ctor[vcsp] <= vcall_ctor_val;
                            vframe_escaped[vcsp] <= 1'b0;
                            e64_p_frame_we <= 1'b1;
                            e64_p_frame_idx <= vcsp[6:0];
                            e64_p_frame_rip <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc : (ip + 16'd1);
                            e64_p_frame_bsp <= base_sp;
                            e64_p_frame_esc <= 1'b0;
                            e64_p_frame_this <= vthis;
                            e64_p_frame_env <= venv;
                            e64_p_frame_fnv <= function_handle;
                            e64_p_frame_ctor <= vcall_ctor_val;
                            vcsp <= vcsp + 8'd1;
                            vcallback_raf <= 1'b0;
                            vcallback_timer <= 1'b0;
                            vcallback_key <= 1'b0;
                            vcallback_fe <= 1'b0;
                            venv <= v64_handle(
                                4'd9, venv_gen[valloc_i[9:0]],
                                {22'd0, valloc_i[9:0]}
                            );
                            if (vcall_value) begin
                                // Arrow/bound keep lexical this; CALL_METHOD
                                // own-property sets vcall_this (game.init).
                                vthis <= (vfn_flags[function_handle[12:0]][0] ||
                                          vfn_flags[function_handle[12:0]][2])
                                       ? vfn_bound_this[function_handle[12:0]]
                                       : vcall_set_this
                                       ? vcall_this : V64_UNDEFINED;
                                bind_mode <= 2'd0;
                                bind_k <= 8'd0;
                                bind_n <= nparam;
                                bind_argc <= vcall_argc[7:0];
                                bind_base <= base_sp;
                                bind_src <= vsp - vcall_argc;
                                bind_vsp_next <= base_sp + nparam;
                                bind_ip <= vfn_entry[function_handle[12:0]];
                                bind_ret <= S_FETCH_WAIT;
                                bind_rd_arm <= 1'b0;
                                state <= S_V64_BIND;
                            end else begin
                                vthis <= vcall_set_this
                                       ? vcall_this : V64_UNDEFINED;
                                vctor_scan <= 6'd0;
                                vctor_armed <= 1'b0;
                                code_raddr <= 15'(ops_base + vcall_entry);
                                state <= S_V64_CTOR_PAD;
                            end
                            vcall_set_this <= 1'b0;
                            vcall_ctor_val <= V64_UNDEFINED;
                        end else if (valloc_i + 14'd1 < ENV_DEPTH) begin
                            valloc_i <= valloc_i + 14'd1;
                        end else if (!valloc_retried) begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b0;
                            state <= S_V64_GC_CLEAR;
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                        end
                    end else if (valloc_kind == 2'd2) begin
                        if (valloc_i < MAX_OBJ &&
                            !vfn_valid[valloc_i[12:0]]) begin
                            vfn_next <= valloc_i + 14'd1;
                            vfn_valid[valloc_i[12:0]] <= 1'b1;
                                if (valloc_now_fn) begin
                                    vfn_entry[valloc_i[12:0]] <= 16'hfffa;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd0;
                                    vfn_env[valloc_i[12:0]] <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'd0;
                                    vfn_bound_this[valloc_i[12:0]] <=
                                        V64_UNDEFINED;
                                    vfn_proto[valloc_i[12:0]] <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0, 3'd0, 6'd0, 16'hfffa});
                                    e64_p_data2 <= V64_UNDEFINED;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= V64_UNDEFINED;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vsp <= vnat_base + 12'd1;
                                    valloc_now_fn <= 1'b0;
                                end else if (valloc_bind) begin
                                    vfn_entry[valloc_i[12:0]] <=
                                        vfn_entry[valloc_bind_src];
                                    vfn_nparam[valloc_i[12:0]] <=
                                        vfn_nparam[valloc_bind_src];
                                    vfn_env[valloc_i[12:0]] <=
                                        vfn_env[valloc_bind_src];
                                    // [2]=has_bound_this (PYTHON bind).
                                    vfn_flags[valloc_i[12:0]] <=
                                        {1'b1, vfn_flags[valloc_bind_src][1],
                                         vfn_flags[valloc_bind_src][0]};
                                    vfn_bound_this[valloc_i[12:0]] <=
                                        valloc_bind_this;
                                    vfn_proto[valloc_i[12:0]] <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0,
                                              1'b1,
                                              vfn_flags[valloc_bind_src][1],
                                              vfn_flags[valloc_bind_src][0],
                                              vfn_nparam[valloc_bind_src],
                                              vfn_entry[valloc_bind_src]});
                                    e64_p_data2 <= vfn_env[valloc_bind_src];
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_bind_this;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vsp <= vnat_base + 12'd1;
                                    valloc_bind <= 1'b0;
                                end else begin
                                    vfn_entry[valloc_i[12:0]] <= valloc_fn_entry;
                                    vfn_nparam[valloc_i[12:0]] <= valloc_fn_a1[5:0];
                                vfn_env[valloc_i[12:0]] <= venv;
                                    // [2]=arrow [1]=IIFE (JSB a1 bit6) [0]=arrow
                                    // this-bind. CALL_VAL reads [1] for flat IIFE.
                                vfn_flags[valloc_i[12:0]] <=
                                        {valloc_fn_a1[7], valloc_fn_a1[6],
                                         valloc_fn_a1[7]};
                                vfn_bound_this[valloc_i[12:0]] <=
                                        valloc_fn_a1[7] ? vthis : V64_UNDEFINED;
                                    vfn_proto[valloc_i[12:0]] <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0,
                                              valloc_fn_a1[7],
                                              valloc_fn_a1[6],
                                              valloc_fn_a1[7],
                                              valloc_fn_a1[5:0],
                                              valloc_fn_entry});
                                    e64_p_data2 <= venv;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_fn_a1[7]
                                        ? vthis : V64_UNDEFINED;
                                    if (vcsp != 8'd0)
                                        e64_p_addr2 <= {1'b1, 8'd0,
                                                        vcsp - 8'd1};
                                    vst_wr(vsp, v64_handle(
                                    4'd7, vfn_gen[valloc_i[12:0]],
                                    {19'd0, valloc_i[12:0]}
                                    ));
                                    vsp <= vsp + 12'd1;
                                    // Closure captured this activation's env.
                                    if (vcsp != 8'd0)
                                        vframe_escaped[vcsp - 8'd1] <= 1'b1;
                                end
                                ip <= ip + 16'd1;
                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            valloc_i <= valloc_i + 14'd1;
                        end else if (!valloc_retried) begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b0;
                            state <= S_V64_GC_CLEAR;
                            end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                        end
                    end else begin
                        if (valloc_i < MAX_OBJ &&
                            vobj_alloc[valloc_i[12:0]] == 0) begin
                            vobj_next <= valloc_i + 14'd1;
                            if (code_rdata[7:0] == OP_NEW_OBJ) begin
                                logic [15:0] ctor_ip;
                                logic [63:0] handle, ctor_fn;
                                logic [11:0] argc;
                                logic [8:0] vslot;
                                logic ctor_fn_ok;
                                ctor_ip = 16'hFFFF;
                                argc = {4'd0, code_rdata[31:24]};
                                ctor_fn = V64_UNDEFINED;
                                ctor_fn_ok = 1'b0;
                                handle = v64_handle(
                                    4'd5, vobj_gen[valloc_i[12:0]],
                                    {19'd0, valloc_i[12:0]}
                                );
                                vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                vobj_len[valloc_i[12:0]] <= 6'd0;
                                vobj_cls[valloc_i[12:0]] <= code_rdata[23:8];
                                vobj_builtin[valloc_i[12:0]] <= 4'd0;
                                vobj_proto[valloc_i[12:0]] <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                e64_p_addr2 <= code_rdata[23:8];
                                for (int c = 0; c < MAX_CLS; c++)
                                    if (c < n_cls &&
                                        cls_name[c] == code_rdata[23:8])
                                        ctor_ip = cls_ctor[c];
                                // PYTHON _value64_ctor_function_for_class:
                                // `new Stage` looks up the function in env
                                // then varmap (nested `var Stage = function`).
                                if (intern_var_ok[code_rdata[17:8]] &&
                                    venv[63:48] == 16'h7ff9 &&
                                    venv[47:44] == 4'd9) begin
                                    if (venv[31:0] >= ENV_DEPTH ||
                                        !venv_valid[venv[9:0]] ||
                                        venv_gen[venv[9:0]] !=
                                            venv[43:32]) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd4;
                                        running <= 1'b0;
                                        state <= S_DONE;
                                    end else begin
                                        vslot = intern_var[code_rdata[17:8]];
                                        vcall_entry <= ctor_ip;
                                        hp_env <= 1'b1;
                                        hp_cmd <= HP_GETPROP;
                                        hp_v64 <= 1'b1;
                                        hp_eid <= venv[9:0];
                                        hp_len <= {1'b0, venv_len[venv[9:0]]};
                                        hp_slot <= 5'd0;
                                        hp_key <= {7'd0, vslot};
                                        hp_phase <= 3'd0;
                                        hp_hit <= 1'b0;
                                        hp_ret <= S_V64_CTOR_ENV;
                                        state <= S_HEAP_WAIT;
                                    end
                                end else begin
                                if (intern_var_ok[code_rdata[17:8]]) begin
                                    vslot = intern_var[code_rdata[17:8]];
                                    ctor_fn = vvar_valid[vslot]
                                        ? vvars[vslot] : V64_UNDEFINED;
                                    if (ctor_fn[63:48] == V64_TAG_PREFIX &&
                                        ctor_fn[47:44] == V64_KIND_FUNCTION &&
                                        ctor_fn[31:0] < MAX_OBJ &&
                                        vfn_valid[ctor_fn[12:0]] &&
                                        vfn_gen[ctor_fn[12:0]] ==
                                            ctor_fn[43:32])
                                        ctor_fn_ok = 1'b1;
                                end
                                if (ctor_fn_ok)
                                    vobj_proto[valloc_i[12:0]] <=
                                        vfn_proto[ctor_fn[12:0]];
                                if (ctor_ip != 16'hFFFF) begin
                                    if (vcsp >= CSTK) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd2;
                                        running <= 1'b0;
                                        state <= S_DONE;
                                    end else begin
                                        vcall_value <= 1'b0;
                                        vcall_entry <= ctor_ip;
                                        vcall_argc <= argc;
                                        vcall_set_this <= 1'b1;
                                        vcall_this <= handle;
                                        vcall_ctor_val <= handle;
                                        valloc_kind <= 2'd3;
                                        valloc_i <= {4'd0, venv_next};
                                        valloc_retried <= 1'b0;
                                    end
                                end else if (ctor_fn_ok) begin
                                    // constructor_ip None + function ctor:
                                    // call the function with this=instance.
                                    if (vcsp >= CSTK) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd2;
                                        running <= 1'b0;
                                        state <= S_DONE;
                                    end else begin
                                        bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                        bind_k <= (argc == 0) ? 8'd0
                                            : (argc - 8'd1);
                                        bind_n <= argc;
                                        bind_argc <= argc;
                                        bind_base <= vsp - argc;
                                        bind_src <= vsp - argc;
                                        bind_ins <= ctor_fn;
                                        bind_vsp_next <= vsp + 12'd1;
                                        bind_ret <= S_V64_ALLOC;
                                        bind_rd_arm <= 1'b0;
                                        vcall_value <= 1'b1;
                                        vcall_argc <= argc;
                                        vcall_set_this <= 1'b1;
                                        vcall_this <= handle;
                                        vcall_ctor_val <= handle;
                                        valloc_kind <= 2'd3;
                                        valloc_i <= {4'd0, venv_next};
                                        valloc_retried <= 1'b0;
                                        state <= S_V64_BIND;
                                    end
                                end else begin
                                    // Ctor-less NEW_OBJ: drop args, push the
                                    // instance (PYTHON constructor_ip None).
                                    vst_wr(vsp - argc, handle);
                                    vsp <= vsp - argc + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                                end
                            end else begin
                                logic [63:0] handle;
                                logic [15:0] key_intern;
                                handle = v64_handle(
                                    4'd5, vobj_gen[valloc_i[12:0]],
                                    {19'd0, valloc_i[12:0]}
                                );
                                vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                vobj_cls[valloc_i[12:0]] <= 16'hFFFF;
                                vobj_builtin[valloc_i[12:0]] <= 4'd0;
                                vobj_len[valloc_i[12:0]] <= 6'd0;
                                vobj_proto[valloc_i[12:0]] <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                if (valloc_proto) begin
                                    vfn_proto[valloc_proto_fn] <= handle;
                                    vst_wr(vnat_base, handle);
                                    valloc_proto <= 1'b0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (valloc_metrics) begin
                                    vmetrics <= handle;
                                    vst_wr(vnat_base, handle);
                                    valloc_metrics <= 1'b0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd1;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_width;
                                    hp_qv[0] <=
                                        v64_int32_number({16'd0, vmetrics_w});
                                    hp_qt[0] <= 3'd0;
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else if (vnat_dom == 3'd1) begin
                                    // querySelector style object
                                    vobj_builtin[valloc_i[12:0]] <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vnat_style <= handle;
                                    vnat_dom <= 3'd2;
                                    valloc_i <= valloc_i + 14'd1;
                                end else if (vnat_dom == 3'd2) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd3;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_style;
                                    hp_qv[0] <= vnat_style;
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= id_width;
                                    hp_qv[1] <= v64_int32_number(32'd640);
                                    hp_qt[1] <= 3'd0;
                                    hp_qk[2] <= id_height;
                                    hp_qv[2] <= v64_int32_number(32'd480);
                                    hp_qt[2] <= 3'd0;
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else if (vnat_dom == 3'd3) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd5;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd5, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    // Pin fillStyle@0 strokeStyle@1 so SET_PROP
                                    // writes one slot (MRDO palK).
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd2;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_fillstyle;
                                    hp_qv[0] <= v64_int32_number(32'd1);
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= id_strokestyle;
                                    hp_qv[1] <= v64_int32_number(32'd1);
                                    hp_qt[1] <= 3'd0;
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else if (vnat_dom == 3'd4) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd2;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd2, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd2;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_width;
                                    hp_qv[0] <= v64_int32_number(32'd1);
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= id_height;
                                    hp_qv[1] <= v64_int32_number(32'd1);
                                    hp_qt[1] <= 3'd0;
                                    hp_ret <= S_FETCH_WAIT;
                                    state <= S_HEAP_WR;
                                end else if (vnat_dom == 3'd5) begin
                                    key_intern = (kev_q[kev_rp][7:0] == 8'd13)
                                        ? id_enter
                                        : (kev_q[kev_rp][7:0] == 8'd32)
                                        ? id_space
                                        : (kev_q[kev_rp][7:0] == 8'd37)
                                        ? id_arrow_l
                                        : (kev_q[kev_rp][7:0] == 8'd39)
                                        ? id_arrow_r
                                        : (kev_q[kev_rp][7:0] == 8'd38)
                                        ? id_arrow_u
                                        : (kev_q[kev_rp][7:0] == 8'd40)
                                        ? id_arrow_d
                                        : (kev_q[kev_rp][7:0] == 8'd65)
                                        ? id_a
                                        : (kev_q[kev_rp][7:0] == 8'd68)
                                        ? id_d : 16'hFFFF;
                                    vkev_event <= handle;
                                    vnat_dom <= 3'd0;
                                    vkey_li <= 5'd0;
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= valloc_i[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd3;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_type;
                                    hp_qv[0] <= v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, kev_q[kev_rp][8]
                                            ? id_keydown : id_keyup}
                                    );
                                    hp_qt[0] <= 3'd0;
                                    hp_qk[1] <= id_key;
                                    hp_qv[1] <=
                                        (key_intern == 16'hFFFF)
                                        ? V64_UNDEFINED
                                        : v64_handle(4'd4, 12'd0,
                                                     {16'd0, key_intern});
                                    hp_qt[1] <= 3'd0;
                                    hp_qk[2] <= id_keycode;
                                    hp_qv[2] <=
                                        v64_int32_number(
                                            {24'd0, kev_q[kev_rp][7:0]}
                                        );
                                    hp_qt[2] <= 3'd0;
                                    hp_ret <= S_V64_FRAME_KEY;
                                    state <= S_HEAP_WR;
                                end else if (vnat_dom == 3'd6) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd3;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd3, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    if (valloc_regex) begin
                                        vobj_builtin[valloc_i[12:0]] <= 4'd6;
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd6, 2'd0, 6'd0});
                                        valloc_regex <= 1'b0;
                                        vst_wr(vsp, handle);
                            vsp <= vsp + 12'd1;
                            ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        hp_cmd <= HP_OSETI;
                                        hp_v64 <= 1'b1;
                                        hp_oid <= valloc_i[12:0];
                                        hp_slot <= 5'd0;
                                        hp_qn <= 3'd1;
                                        hp_qi <= 3'd0;
                                        hp_qk[0] <= 16'd0;
                                        hp_qv[0] <= {32'd0, valloc_regex_pack};
                                        hp_qt[0] <= 3'd0;
                                        hp_ret <= S_FETCH_WAIT;
                                        state <= S_HEAP_WR;
                                    end else begin
                                    vst_wr(vsp, handle);
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            valloc_i <= valloc_i + 14'd1;
                        end else if (!valloc_retried) begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b0;
                            state <= S_V64_GC_CLEAR;
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                        end
                    end
                end
                S_V64_GC_CLEAR: begin
                    if (vgc_clear_i < MAX_OBJ) begin
                        vobj_mark[vgc_clear_i[12:0]] <= 1'b0;
                        vfn_mark[vgc_clear_i[12:0]] <= 1'b0;
                    end
                    else if (vgc_clear_i < MAX_OBJ + MAX_ARR)
                        varr_mark[vgc_clear_i - MAX_OBJ] <= 1'b0;
                    else
                        venv_mark[vgc_clear_i - MAX_OBJ - MAX_ARR] <= 1'b0;
                    if (vgc_clear_i + 14'd1 >=
                        MAX_OBJ + MAX_ARR + ENV_DEPTH) begin
                        vgc_root_i <= 12'd0;
                        vgc_root_phase <= 3'd0;
                        state <= S_V64_GC_ROOT;
                    end else
                        vgc_clear_i <= vgc_clear_i + 14'd1;
                end
                S_V64_GC_ROOT: begin
                    case (vgc_root_phase)
                        3'd0: begin
                            if (vgc_root_i < MAX_VARS) begin
                                if (vvar_valid[vgc_root_i[8:0]])
                                    v64_gc_mark_task(vvars[vgc_root_i[8:0]]);
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd1;
                            end
                        end
                        3'd1: begin
                            // PYTHON marks the whole eval stack. `VST_AT` is
                            // only the TOS window — deep JSON/MAKE_ARRAY
                            // slots live in vstack BRAM.
                            if (vgc_root_i < vsp) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                    v64_gc_mark_task(vst_rdata);
                                vgc_root_i <= vgc_root_i + 12'd1;
                                    vgc_rd_arm <= 1'b0;
                                end
                            end else begin
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd2;
                            end
                        end
                        3'd2: begin
                            if (vgc_root_i == 12'd0) begin
                            v64_gc_mark_task(vthis);
                                vgc_root_i <= 12'd1;
                            end else if (vgc_root_i == 12'd1) begin
                                v64_gc_mark_task(vcall_this);
                                vgc_root_i <= 12'd2;
                            end else begin
                                v64_gc_mark_task(vcall_ctor_val);
                                vgc_root_i <= 12'd0;
                            vgc_root_phase <= 3'd3;
                            end
                        end
                        3'd3: begin
                            v64_gc_mark_task(venv);
                            vgc_root_i <= 12'd0;
                            vgc_root_phase <= 3'd4;
                        end
                        3'd4: begin
                            if ((vgc_root_i >> 2) < vcsp) begin
                                case (vgc_root_i[1:0])
                                    2'd0: v64_gc_mark_task(
                                        vframe_this[vgc_root_i >> 2]
                                    );
                                    2'd1: v64_gc_mark_task(
                                        vframe_env[vgc_root_i >> 2]
                                    );
                                    2'd2: v64_gc_mark_task(
                                        vframe_fn[vgc_root_i >> 2]
                                    );
                                    default: v64_gc_mark_task(
                                        vframe_ctor[vgc_root_i >> 2]
                                    );
                                endcase
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd5;
                            end
                        end
                        3'd5: begin
                            if (vgc_root_i < vraf_n) begin
                                v64_gc_mark_task(vraf[vgc_root_i[2:0]]);
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < vraf_n + vraf_snap_n) begin
                                v64_gc_mark_task(
                                    vraf_snap[vgc_root_i - vraf_n]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd6;
                            end
                        end
                        3'd6: begin
                            if (vgc_root_i < 12'd64) begin
                                if (vtimer_valid[vgc_root_i[5:0]])
                                    v64_gc_mark_task(
                                        vtimer_fn[vgc_root_i[5:0]]
                                    );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd7;
                            end
                        end
                        default: begin
                            if (vgc_root_i < 12'd32) begin
                                if (vgc_root_i[0])
                                    v64_gc_mark_task(
                                        vlistener_fn[vgc_root_i[4:1]]
                                    );
                                else
                                    v64_gc_mark_task(
                                        vlistener_ev[vgc_root_i[4:1]]
                                    );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i == 12'd32) begin
                                v64_gc_mark_task(vnat_style);
                                vgc_root_i <= 12'd33;
                            end else if (vgc_root_i == 12'd33) begin
                                v64_gc_mark_task(vkev_event);
                                vgc_root_i <= 12'd34;
                            end else if (vgc_root_i == 12'd34) begin
                                v64_gc_mark_task(vfe_arr);
                                vgc_root_i <= 12'd35;
                            end else if (vgc_root_i == 12'd35) begin
                                v64_gc_mark_task(vfe_fn);
                                vgc_root_i <= 12'd36;
                            end else if (vgc_root_i == 12'd36) begin
                                v64_gc_mark_task(vmetrics);
                                vgc_root_i <= 12'd37;
                            end else if (vgc_root_i == 12'd37) begin
                                v64_gc_mark_task(vfe_map);
                                vgc_root_i <= 12'd38;
                            end else if (vgc_root_i < 12'd46) begin
                                v64_gc_mark_task(
                                    vfe_arr_s[vgc_root_i - 12'd38]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd54) begin
                                v64_gc_mark_task(
                                    vfe_fn_s[vgc_root_i - 12'd46]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd62) begin
                                v64_gc_mark_task(
                                    vfe_map_s[vgc_root_i - 12'd54]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd62 + 12'(JSON_STK))
                            begin
                                if ((vgc_root_i - 12'd62) < {6'd0, js_sp})
                                    v64_gc_mark_task(
                                        vjs_val[vgc_root_i - 12'd62]
                                    );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else
                                state <= S_V64_GC_POP;
                        end
                    endcase
                end
                S_V64_GC_POP: begin
                    if (vgc_qr < vgc_qw) begin
                        vgc_cur <= vgc_queue[vgc_qr];
                        vgc_qr <= vgc_qr + 14'd1;
                        vgc_slot_i <= 8'd0;
                        if (vgc_queue[vgc_qr][47:44] == V64_KIND_OBJECT ||
                            vgc_queue[vgc_qr][47:44] == V64_KIND_ELEMENT)
                            state <= S_V64_GC_OBJ;
                        else if (vgc_queue[vgc_qr][47:44] == 4'd6)
                            state <= S_V64_GC_ARR;
                        else if (vgc_queue[vgc_qr][47:44] == 4'd7)
                            state <= S_V64_GC_FN;
                        else
                            state <= S_V64_GC_ENV;
                    end else begin
                        vgc_obj_i <= 13'd0;
                        state <= S_V64_GC_SWEEP_OBJ;
                    end
                end
                S_V64_GC_OBJ: begin
                    if (vgc_slot_i < vobj_len[vgc_cur[12:0]]) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(vobj_rdata[63:0]);
                            vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else if (vgc_slot_i == {2'b0, vobj_len[vgc_cur[12:0]]})
                    begin
                        v64_gc_mark_task(vobj_proto[vgc_cur[12:0]]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_ARR: begin
                    if (vgc_slot_i < varr_len[vgc_cur[11:0]]) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(varr_rdata);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_FN: begin
                    if (vgc_slot_i == 0) begin
                        v64_gc_mark_task(vfn_env[vgc_cur[12:0]]);
                        vgc_slot_i <= 8'd1;
                    end else if (vgc_slot_i == 1) begin
                        v64_gc_mark_task(vfn_bound_this[vgc_cur[12:0]]);
                        vgc_slot_i <= 8'd2;
                    end else if (vgc_slot_i == 2) begin
                        v64_gc_mark_task(vfn_proto[vgc_cur[12:0]]);
                        vgc_slot_i <= 8'd3;
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_ENV: begin
                    if (vgc_slot_i == 0) begin
                        v64_gc_mark_task(venv_parent[vgc_cur[9:0]]);
                        vgc_slot_i <= 8'd1;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i <= venv_len[vgc_cur[9:0]]) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(venv_rdata[63:0]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        state <= S_V64_GC_POP;
                    end
                end
                S_V64_GC_SWEEP_OBJ: begin
                    logic free_obj;
                    logic free_fn;
                    logic [11:0] new_fgen;
                    // Obj and Fn share the index space; poke 48 flags each
                    // independently so a swept object cannot clear a live fn.
                    free_obj = (vobj_alloc[vgc_obj_i] == 2'd1 &&
                                !vobj_mark[vgc_obj_i]);
                    free_fn = (vfn_valid[vgc_obj_i] && !vfn_mark[vgc_obj_i]);
                    new_fgen = (vfn_gen[vgc_obj_i] == 12'hfff)
                        ? 12'd1 : vfn_gen[vgc_obj_i] + 12'd1;
                    if (free_obj) begin
                        vobj_alloc[vgc_obj_i] <= 2'd0;
                        vobj_len[vgc_obj_i] <= 6'd0;
                        vobj_gen[vgc_obj_i] <=
                            (vobj_gen[vgc_obj_i] == 12'hfff)
                            ? 12'd1 : vobj_gen[vgc_obj_i] + 12'd1;
                    end
                    if (free_fn) begin
                        vfn_valid[vgc_obj_i] <= 1'b0;
                        vfn_gen[vgc_obj_i] <= new_fgen;
                    end
                    if (free_obj || free_fn)
                        e64_poke(6'd48, {3'd0, vgc_obj_i},
                                 {20'd0, new_fgen, 30'd0, free_fn, free_obj});
                    if (vgc_obj_i + 13'd1 >= MAX_OBJ) begin
                        vgc_arr_i <= 12'd0;
                        state <= S_V64_GC_SWEEP_ARR;
                    end else
                        vgc_obj_i <= vgc_obj_i + 13'd1;
                end
                S_V64_GC_SWEEP_ARR: begin
                    if (varr_valid[vgc_arr_i] &&
                        !varr_mark[vgc_arr_i]) begin
                        varr_valid[vgc_arr_i] <= 1'b0;
                        varr_len[vgc_arr_i] <= 8'd0;
                        e64_poke(6'd49, {4'd0, vgc_arr_i}, 64'd0);
                        if (varr_long[vgc_arr_i])
                            vlong_used[varr_lidx[vgc_arr_i]] <= 1'b0;
                        varr_long[vgc_arr_i] <= 1'b0;
                        varr_gen[vgc_arr_i] <=
                            (varr_gen[vgc_arr_i] == 12'hfff)
                            ? 12'd1 : varr_gen[vgc_arr_i] + 12'd1;
                    end
                    if (vgc_arr_i + 12'd1 >= MAX_ARR) begin
                        vgc_env_i <= 10'd0;
                        state <= S_V64_GC_SWEEP_ENV;
                    end else
                        vgc_arr_i <= vgc_arr_i + 12'd1;
                end
                S_V64_GC_SWEEP_ENV: begin
                    if (venv_valid[vgc_env_i] &&
                        !venv_mark[vgc_env_i]) begin
                        venv_valid[vgc_env_i] <= 1'b0;
                        venv_len[vgc_env_i] <= 5'd0;
                        e64_poke(6'd50, {6'd0, vgc_env_i}, 64'd0);
                        venv_gen[vgc_env_i] <=
                            (venv_gen[vgc_env_i] == 12'hfff)
                            ? 12'd1 : venv_gen[vgc_env_i] + 12'd1;
                    end
                    if (vgc_env_i + 10'd1 >= ENV_DEPTH) begin
                        // Bump cursors skip holes until MAX; rewind so the
                        // next alloc reuses swept slots (OBJ_RING leftover).
                        dbg_gc_n <= dbg_gc_n + 16'd1;
                        vobj_next <= 14'd0;
                        varr_next <= 14'd0;
                        vfn_next <= 14'd0;
                        venv_next <= 10'd0;
                        if (vgc_halt_after) begin
                            vgc_resume <= 2'd0;
                            if (vgc_wait_after) begin
                                vgc_wait_after <= 1'b0;
                                state <= S_WAIT_FRAME;
                            end else begin
                                running <= 1'b0;
                                state <= S_DONE;
                            end
                        end else begin
                            valloc_retried <= 1'b1;
                            valloc_i <= 14'd0;
                            if (vgc_resume == 2'd1) begin
                                vgc_resume <= 2'd0;
                                state <= S_FETCH_WAIT;
                            end else if (vgc_resume == 2'd2) begin
                                vgc_resume <= 2'd0;
                                state <= S_V64_JSON_PARSE;
                            end else if (vgc_resume == 2'd3) begin
                                vgc_resume <= 2'd0;
                                state <= S_V64_JSON;
                            end else begin
                                vgc_resume <= 2'd0;
                            state <= S_V64_ALLOC;
                            end
                        end
                    end else
                        vgc_env_i <= vgc_env_i + 10'd1;
                end
                S_V64_CLEAR: begin
                    fb_we <= 1'b1;
                    fb_waddr <= vdraw_i;
                    fb_wdata <= vdraw_color;
                    if (vdraw_i + 19'd1 >= FB_PIXELS) begin
                        vst_wr(vnat_base, V64_UNDEFINED);
                        vsp <= vnat_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end else
                        vdraw_i <= vdraw_i + 19'd1;
                end
                S_V64_RECT: begin
                    logic [19:0] total;
                    logic [9:0] px, py;
                    total = 20'(vdraw_w) * 20'(vdraw_h);
                    px = (vdraw_i == 19'd0) ? vdraw_x : vdraw_cx;
                    py = (vdraw_i == 19'd0) ? vdraw_y : vdraw_cy;
                    if (vdraw_w == 0 || vdraw_h == 0) begin
                        vst_wr(vnat_base, V64_UNDEFINED);
                        vsp <= vnat_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end else begin
                        if (px < MW && py < MH) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(py) * 19'(MW) + 19'(px);
                            fb_wdata <= vdraw_color;
                        end
                        if (vdraw_i + 19'd1 >= total) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            vsp <= vnat_base + 12'd1;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else begin
                            vdraw_i <= vdraw_i + 19'd1;
                            if (10'(px - vdraw_x) + 10'd1 >= vdraw_w) begin
                                vdraw_cx <= vdraw_x;
                                vdraw_cy <= py + 10'd1;
                            end else begin
                                vdraw_cx <= px + 10'd1;
                                vdraw_cy <= py;
                            end
                        end
                    end
                end
                S_V64_WAIT_FRAME: state <= S_WAIT_FRAME;
                S_V64_FOREACH: begin
                    if (vfe_arr[63:48] != V64_TAG_PREFIX ||
                        vfe_arr[47:44] != V64_KIND_ARRAY ||
                        !varr_valid[vfe_arr[11:0]] ||
                        vfe_i >= varr_len[vfe_arr[11:0]]) begin
                        vst_wr(vfe_base, (vfe_mode == 2'd2 || vfe_mode == 2'd3)
                            ? vfe_map : V64_UNDEFINED);
                        vsp <= vfe_base + 12'd1;
                        ip <= vfe_ret;
                        code_raddr <= 15'(ops_base + vfe_ret);
                        if (vfe_sp != 4'd0) begin
                            vfe_arr <= vfe_arr_s[vfe_sp - 4'd1];
                            vfe_fn <= vfe_fn_s[vfe_sp - 4'd1];
                            vfe_i <= vfe_i_s[vfe_sp - 4'd1];
                            vfe_ret <= vfe_ret_s[vfe_sp - 4'd1];
                            vfe_base <= vfe_base_s[vfe_sp - 4'd1];
                            vfe_mode <= vfe_mode_s[vfe_sp - 4'd1];
                            vfe_map <= vfe_map_s[vfe_sp - 4'd1];
                            vfe_sp <= vfe_sp - 4'd1;
                        end else begin
                            vfe_arr <= V64_UNDEFINED;
                            vfe_fn <= V64_UNDEFINED;
                            vfe_mode <= 2'd0;
                            vfe_map <= V64_UNDEFINED;
                        end
                        state <= S_FETCH_WAIT;
                    end else if (vfe_fn[63:48] != V64_TAG_PREFIX ||
                                 vfe_fn[47:44] != V64_KIND_FUNCTION) begin
                        machine_fault <= 1'b1; fault_code <= 8'd4;
                        running <= 1'b0; state <= S_DONE;
                    end else if (vcsp >= CSTK ||
                                 (!vfe_rd_arm &&
                                  vsp + 12'd4 > STACK_DEPTH) ||
                                 (vfe_rd_arm && vsp >= STACK_DEPTH)) begin
                        machine_fault <= 1'b1;
                        fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                        running <= 1'b0; state <= S_DONE;
                    end else begin
                        // 1W1R + TOS window only shifts ±1 per clock, and
                        // ALLOC's `VST_AT is combo on last cycle's window —
                        // idle one beat after the last push so TOS is fn.
                        if (!vfe_rd_arm) begin
                            vst_wr(vsp, vfe_fn);
                            vsp <= vsp + 12'd1;
                            vfe_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            vst_wr(vsp, varr_rdata);
                            vsp <= vsp + 12'd1;
                            bind_k <= 8'd1;
                        end else if (bind_k == 8'd1) begin
                            vst_wr(vsp, v64_int32_number({24'd0, vfe_i}));
                            vsp <= vsp + 12'd1;
                            bind_k <= 8'd2;
                        end else if (bind_k == 8'd2) begin
                            vst_wr(vsp, vfe_arr);
                            vsp <= vsp + 12'd1;
                            bind_k <= 8'd3;
                        end else begin
                            vcall_value <= 1'b1;
                            vcall_argc <= 12'd3;
                            vcallback_fe <= 1'b1;
                            valloc_kind <= 2'd3;
                            valloc_i <= {4'd0, venv_next};
                            valloc_retried <= 1'b0;
                            vfe_i <= vfe_i + 8'd1;
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            state <= S_V64_ALLOC;
                        end
                    end
                end
                S_V64_STRIDX: state <= S_V64_STRIDX_WR;
                S_V64_STRIDX_WR: begin
                    if (char_ok[name_rdata])
                        vst_wr(vsp - 12'd1, v64_handle(
                            4'd4, 12'd0, {16'd0, char_id[name_rdata]}
                        ));
                    else
                        vst_wr(vsp - 12'd1, V64_UNDEFINED);
                    code_raddr <= 15'(ops_base + ip);
                    state <= S_FETCH_WAIT;
                end
                S_V64_JSON: begin
                    // Walk nested Value64 arrays/numbers into json_mem.
                    if (js_sp == 6'd0) begin
                        if (!vfree_armed) begin
                            vfree_armed <= 1'b1;
                            valloc_i <= 14'd0;
                            hp_ret <= S_V64_JSON;
                            state <= S_FREE_OBJ;
                        end else begin
                            vfree_armed <= 1'b0;
                            if (vfree_ok) begin
                            valloc_retried <= 1'b0;
                            vobj_alloc[valloc_i[12:0]] <= 2'd1;
                            vobj_builtin[valloc_i[12:0]] <= 4'd7;
                            e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                     {52'd0, 4'd7, 2'd0, 6'd0});
                            vst_wr(vnat_base, v64_handle(
                                4'd5, vobj_gen[valloc_i[12:0]],
                                {19'd0, valloc_i[12:0]}
                            ));
                            vsp <= vnat_base + 12'd1;
                            vobj_next <= valloc_i + 14'd1;
                            ip <= ip + 16'd1;
                            code_raddr <=
                                15'(ops_base + ip + 16'd1);
                            hp_cmd <= HP_OSETI;
                            hp_v64 <= 1'b1;
                            hp_oid <= valloc_i[12:0];
                            hp_slot <= 5'd0;
                            hp_qn <= 3'd2;
                            hp_qi <= 3'd0;
                            hp_qk[0] <= 16'd0;
                            hp_qv[0] <= v64_int32_number(32'd0);
                            hp_qt[0] <= 3'd0;
                            hp_qk[1] <= 16'd1;
                            hp_qv[1] <= v64_int32_number({18'd0, json_wp});
                            hp_qt[1] <= 3'd0;
                            hp_ret <= S_FETCH_WAIT;
                            state <= S_HEAP_WR;
                            end else if (!valloc_retried) begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b0;
                            vgc_resume <= 2'd3;
                            state <= S_V64_GC_CLEAR;
                            end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                            end
                        end
                    end else begin
                        logic [5:0] t;
                        logic [2:0] ph;
                        logic [63:0] v;
                        logic [7:0] ii;
                        logic [11:0] ai;
                        t = js_sp - 6'd1;
                        ph = js_ph[t];
                        v = vjs_val[t];
                        ii = js_i[t];
                        ai = v[11:0];
                        if (ph == 3'd0) begin
                            if (v64_is_number(v) &&
                                v[62:52] != 11'h7ff) begin
                                json_num <= $signed(v64_to_uint32(v));
                                json_neg <= v[63];
                                js_ph[t] <= 3'd3;
                            end else if (v[63:48] == V64_TAG_PREFIX &&
                                       v[47:44] == V64_KIND_ARRAY &&
                                       v[31:0] < MAX_ARR &&
                                       varr_valid[ai]) begin
                                json_putc(8'h5B);
                                js_ph[t] <= 3'd1;
                                js_i[t] <= 8'd0;
                            end else begin
                                json_putc(8'h6E);
                                json_di <= 4'd1;
                                js_ph[t] <= 3'd4;
                            end
                        end else if (ph == 3'd1) begin
                            if (ii >= varr_len[ai]) begin
                                json_putc(8'h5D);
                                js_sp <= t;
                                vjs_rd_arm <= 1'b0;
                            end else if (ii != 8'd0) begin
                                json_putc(8'h2C);
                                js_ph[t] <= 3'd2;
                                vjs_rd_arm <= 1'b0;
                            end else if (!vjs_rd_arm) begin
                                vjs_rd_arm <= 1'b1;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                vjs_val[js_sp] <= varr_rdata;
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= js_sp + 6'd1;
                                vjs_rd_arm <= 1'b0;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= t;
                                vjs_rd_arm <= 1'b0;
                            end
                        end else if (ph == 3'd2) begin
                            if (!vjs_rd_arm)
                                vjs_rd_arm <= 1'b1;
                            else if (js_sp < JSON_STK[5:0]) begin
                                vjs_val[js_sp] <= varr_rdata;
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_ph[t] <= 3'd1;
                                js_sp <= js_sp + 6'd1;
                                vjs_rd_arm <= 1'b0;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= t;
                                vjs_rd_arm <= 1'b0;
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
                        end else js_sp <= t;
                    end
                end
                S_V64_JSON_PARSE: begin
                    if (json_rp >= json_src + json_srclen) begin
                        vst_wr(vnat_base, (js_sp == 0)
                            ? V64_NULL : vjs_val[0]);
                        vsp <= vnat_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic [7:0] ch;
                        ch = json_mem[json_rp[12:0]];
                        if (ch == 8'h20 || ch == 8'h0A ||
                            ch == 8'h0D || ch == 8'h09) begin
                            json_rp <= json_rp + 14'd1;
                        end else if (json_pph == 3'd3) begin
                            if (ch >= 8'h30 && ch <= 8'h39) begin
                                json_num <= json_num * 32'sd10 +
                                    $signed({24'd0, ch - 8'h30});
                                json_rp <= json_rp + 14'd1;
                            end else begin
                                begin
                                    logic [63:0] nv;
                                    nv = v64_int32_number(
                                        json_neg ? -json_num : json_num
                                    );
                                    if (js_sp == 6'd0) begin
                                        vst_wr(vnat_base, nv);
                                        vsp <= vnat_base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        logic [5:0] p;
                                        p = js_sp - 6'd1;
                                        if (!varr_long[vjs_val[p][11:0]] &&
                                            js_i[p] >= ARR_SHORT_CAP[7:0] &&
                                            !vprom_done) begin
                                            hp_aid <= vjs_val[p][11:0];
                                            valloc_i <= 14'd0;
                                            vprom_copy <= 1'b0;
                                            vprom_ret <= S_V64_JSON_PARSE;
                                            state <= S_ARR_PROMOTE;
                                        end else begin
                                        vprom_done <= 1'b0;
                                        varr_len[vjs_val[p][11:0]] <=
                                            js_i[p] + 8'd1;
                                        e64_poke(6'd6, {4'd0, vjs_val[p][11:0]},
                                                 {56'd0, js_i[p] + 8'd1});
                                        js_i[p] <= js_i[p] + 8'd1;
                                        json_pph <= 3'd0;
                                        hp_cmd <= HP_ASETI;
                                        hp_v64 <= 1'b1;
                                        hp_from_stack <= 1'b0;
                                        hp_aid <= vjs_val[p][11:0];
                                        hp_aslot <= js_i[p][6:0];
                                        hp_wval <= nv;
                                        hp_ret <= S_V64_JSON_PARSE;
                                        state <= S_HEAP_AWR;
                                        end
                                    end
                                end
                            end
                        end else if (ch == 8'h5B) begin
                            if (!vfree_armed) begin
                                vfree_armed <= 1'b1;
                                vfree_arr_long <= 1'b0;
                                valloc_i <= 14'd0;
                                hp_ret <= S_V64_JSON_PARSE;
                                state <= S_FREE_ARR;
                            end else begin
                                vfree_armed <= 1'b0;
                                if (!vfree_ok) begin
                                    // Collect then retry this '['. Direct
                                    // fault=3 skipped frame-end reuse.
                                    if (!valloc_retried) begin
                                        vgc_clear_i <= 14'd0;
                                        vgc_qr <= 14'd0;
                                        vgc_qw <= 14'd0;
                                        vgc_halt_after <= 1'b0;
                                        vgc_resume <= 2'd2;
                                        state <= S_V64_GC_CLEAR;
                                    end else begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end
                                end else if (js_sp >= JSON_STK[5:0]) begin
                                    dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                    json_rp <= json_rp + 14'd1;
                                end else begin
                                    valloc_retried <= 1'b0;
                                    varr_valid[valloc_i[11:0]] <= 1'b1;
                                    varr_len[valloc_i[11:0]] <= 8'd0;
                                    // Spill into long handles when short is
                                    // full (aid >= MAX_ARR_SHORT). Must mark
                                    // the long bank; short is linear aid*32.
                                    if (valloc_i >= 14'(MAX_ARR_SHORT)) begin
                                        varr_long[valloc_i[11:0]] <= 1'b1;
                                        varr_lidx[valloc_i[11:0]] <=
                                            valloc_i[7:0];
                                        vlong_used[valloc_i[7:0]] <= 1'b1;
                                    end else
                                        varr_long[valloc_i[11:0]] <= 1'b0;
                                    // Exec ARRAY_GET uses its varr_valid/len
                                    // copy; JSON.parse must poke or finder
                                    // sees length 0 and floods push (fault=3).
                                    e64_poke(6'd45, {4'd0, valloc_i[11:0]},
                                             {55'd0,
                                              (valloc_i >= 14'(MAX_ARR_SHORT)),
                                              8'd0});
                                    e64_p_addr2 <= {8'd0, valloc_i[7:0]};
                                    vjs_val[js_sp] <= v64_handle(
                                        4'd6, varr_gen[valloc_i[11:0]],
                                        {20'd0, valloc_i[11:0]}
                                    );
                                    js_i[js_sp] <= 8'd0;
                                    js_sp <= js_sp + 6'd1;
                                    varr_next <= valloc_i + 14'd1;
                                    json_rp <= json_rp + 14'd1;
                                end
                            end
                        end else if (ch == 8'h5D) begin
                            if (js_sp <= 6'd1) begin
                                json_rp <= json_rp + 14'd1;
                                vst_wr(vnat_base, (js_sp == 0)
                                    ? V64_NULL : vjs_val[0]);
                                vsp <= vnat_base + 12'd1;
                                ip <= ip + 16'd1;
                                code_raddr <=
                                    15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end else begin
                                logic [5:0] p, c;
                                c = js_sp - 6'd1;
                                p = js_sp - 6'd2;
                                if (!varr_long[vjs_val[p][11:0]] &&
                                    js_i[p] >= ARR_SHORT_CAP[7:0] &&
                                    !vprom_done) begin
                                    hp_aid <= vjs_val[p][11:0];
                                    valloc_i <= 14'd0;
                                    vprom_copy <= 1'b0;
                                    vprom_ret <= S_V64_JSON_PARSE;
                                    state <= S_ARR_PROMOTE;
                                end else begin
                                vprom_done <= 1'b0;
                                json_rp <= json_rp + 14'd1;
                                varr_len[vjs_val[p][11:0]] <=
                                    js_i[p] + 8'd1;
                                e64_poke(6'd6, {4'd0, vjs_val[p][11:0]},
                                         {56'd0, js_i[p] + 8'd1});
                                js_i[p] <= js_i[p] + 8'd1;
                                js_sp <= c;
                                hp_cmd <= HP_ASETI;
                                hp_v64 <= 1'b1;
                                hp_from_stack <= 1'b0;
                                hp_aid <= vjs_val[p][11:0];
                                hp_aslot <= js_i[p][6:0];
                                hp_wval <= vjs_val[c];
                                hp_ret <= S_V64_JSON_PARSE;
                                state <= S_HEAP_AWR;
                                end
                            end
                        end else if (ch == 8'h2C) begin
                            json_rp <= json_rp + 14'd1;
                        end else if (json_pph == 3'd7) begin
                            json_rp <= json_rp + 14'd1;
                            if (ch == 8'h22) json_pph <= 3'd0;
                        end else if (ch == 8'h22) begin
                            json_rp <= json_rp + 14'd1;
                            json_pph <= 3'd7;
                        end else if (ch == 8'h6E || ch == 8'h74 ||
                                   ch == 8'h66) begin
                            json_rp <= json_rp + 14'd4;
                        end else if (ch == 8'h2D ||
                                   (ch >= 8'h30 && ch <= 8'h39)) begin
                            json_neg <= (ch == 8'h2D);
                            json_num <= (ch == 8'h2D) ? 32'sd0
                                : $signed({24'd0, ch - 8'h30});
                            json_rp <= json_rp + 14'd1;
                            json_pph <= 3'd3;
                        end else json_rp <= json_rp + 14'd1;
                    end
                end
                S_V64_CTOR_PAD: begin
                    // PYTHON _value64_entry_nparam: count leading LET_VAR
                    // (a1 bit0) then bind_argv (pad undefined / drop extras).
                    if (!vctor_armed)
                        vctor_armed <= 1'b1;
                    else if (code_rdata[7:0] == OP_LET_VAR &&
                             code_rdata[24] && vctor_scan < 6'd63) begin
                        vctor_scan <= vctor_scan + 6'd1;
                        vctor_armed <= 1'b0;
                        code_raddr <= 15'(ops_base + vcall_entry +
                            {10'd0, vctor_scan} + 16'd1);
                    end else begin
                        logic [11:0] base_sp;
                        logic [7:0] nparam;
                        nparam = {2'd0, vctor_scan};
                        base_sp = vsp - vcall_argc;
                        bind_mode <= 2'd0;
                        bind_k <= 8'd0;
                        bind_n <= nparam;
                        bind_argc <= vcall_argc[7:0];
                        bind_base <= base_sp;
                        bind_src <= vsp - vcall_argc;
                        bind_vsp_next <= base_sp + nparam;
                        bind_ip <= vcall_entry;
                        bind_ret <= S_FETCH_WAIT;
                        bind_rd_arm <= 1'b0;
                        vctor_armed <= 1'b0;
                        state <= S_V64_BIND;
                    end
                end
                S_V64_CTOR_ENV: begin
                    // NEW_OBJ after sequential env lookup (hp_rval / vcall_entry).
                    begin
                        logic [15:0] ctor_ip;
                        logic [63:0] handle, ctor_fn;
                        logic [11:0] argc;
                        logic ctor_fn_ok;
                        ctor_ip = vcall_entry;
                        argc = {4'd0, code_rdata[31:24]};
                        handle = v64_handle(
                            4'd5, vobj_gen[valloc_i[12:0]],
                            {19'd0, valloc_i[12:0]}
                        );
                        ctor_fn = hp_rval;
                        ctor_fn_ok = (ctor_fn[63:48] == V64_TAG_PREFIX &&
                            ctor_fn[47:44] == V64_KIND_FUNCTION &&
                            ctor_fn[31:0] < MAX_OBJ &&
                            vfn_valid[ctor_fn[12:0]] &&
                            vfn_gen[ctor_fn[12:0]] == ctor_fn[43:32]);
                        hp_env <= 1'b0;
                        if (ctor_fn_ok)
                            vobj_proto[valloc_i[12:0]] <=
                                vfn_proto[ctor_fn[12:0]];
                        if (ctor_ip != 16'hFFFF) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                state <= S_DONE;
                            end else begin
                                vcall_value <= 1'b0;
                                vcall_entry <= ctor_ip;
                                vcall_argc <= argc;
                                vcall_set_this <= 1'b1;
                                vcall_this <= handle;
                                vcall_ctor_val <= handle;
                                valloc_kind <= 2'd3;
                                valloc_i <= {4'd0, venv_next};
                                valloc_retried <= 1'b0;
                                state <= S_V64_ALLOC;
                            end
                        end else if (ctor_fn_ok) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                state <= S_DONE;
                            end else begin
                                bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                bind_k <= (argc == 0) ? 8'd0
                                    : (argc - 8'd1);
                                bind_n <= argc;
                                bind_argc <= argc;
                                bind_base <= vsp - argc;
                                bind_src <= vsp - argc;
                                bind_ins <= ctor_fn;
                                bind_vsp_next <= vsp + 12'd1;
                                bind_ret <= S_V64_ALLOC;
                                bind_rd_arm <= 1'b0;
                                vcall_value <= 1'b1;
                                vcall_argc <= argc;
                                vcall_set_this <= 1'b1;
                                vcall_this <= handle;
                                vcall_ctor_val <= handle;
                                valloc_kind <= 2'd3;
                                valloc_i <= {4'd0, venv_next};
                                valloc_retried <= 1'b0;
                                state <= S_V64_BIND;
                            end
                        end else begin
                            vst_wr(vsp - argc, handle);
                            vsp <= vsp - argc + 12'd1;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end
                    end
                end
                S_HEAP_WAIT: state <= S_HEAP_CMP;
                S_HEAP_CMP: begin
                    // rdata valid this cycle. Stop at len, not a 32-wide mux.
                    // Object GET/SET/LOOKFN: exec copies of alloc/gen can lag.
                    // Reject stale handles here on the parent heap (keep gen).
                    // Compare the gen latched at issue (hp_spr_w[11:0]), not
                    // TOS — the window can hold a different word (false stale).
                    if (!hp_env && hp_v64 && hp_phase == 3'd0 &&
                        hp_slot == 5'd0 &&
                        (hp_cmd == HP_GETPROP || hp_cmd == HP_SETPROP ||
                         hp_cmd == HP_LOOKFN) &&
                        (vobj_alloc[hp_oid] != 2'd1 ||
                         vobj_gen[hp_oid] != hp_spr_w[11:0])) begin
                        if (hp_cmd == HP_SETPROP) begin
                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                            vsp <= vsp - 12'd1;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else if (hp_cmd == HP_LOOKFN) begin
                            hp_rval <= V64_UNDEFINED;
                            hp_hit <= 1'b0;
                            state <= hp_ret;
                        end else begin
                            vst_wr(vsp - 12'd1, V64_UNDEFINED);
                            vst_win[0] <= V64_UNDEFINED;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end
                    end else if (hp_env) begin
                        if (hp_slot < hp_len[4:0] &&
                            venv_rdata[72:64] == hp_key[8:0]) begin
                            hp_hit <= 1'b1;
                            hp_rval <= venv_rdata[63:0];
                            if (hp_cmd == HP_GETPROP) begin
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hp_env <= 1'b0;
                                    state <= S_V64_CTOR_ENV;
                                end else begin
                                    // Drop hp_env so the next GET_PROP/SET_PROP
                                    // walks the object, not this env (`x`/`y`
                                    // after LOAD_VAR current).
                                    hp_env <= 1'b0;
                                    vst_wr(vsp, venv_rdata[63:0]);
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end else if (hp_phase == 3'd1) begin
                                // LET_VAR non-local: env hit is not a write.
                                if (!vvar_valid[hp_key[8:0]]) begin
                                    vvars[hp_key[8:0]] <= hp_wval;
                                    vvar_valid[hp_key[8:0]] <= 1'b1;
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hp_env <= 1'b0;
                                vsp <= vsp - 12'd1;
                                ip <= ip + 16'd1;
                                code_raddr <=
                                    15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end else
                                state <= S_HEAP_WR;
                        end else if (hp_slot + 5'd1 < hp_len[4:0]) begin
                            hp_slot <= hp_slot + 5'd1;
                            state <= S_HEAP_WAIT;
                        end else begin
                            if (hp_phase != 3'd2 &&
                                venv_parent[hp_eid][63:48] == 16'h7ff9 &&
                                venv_parent[hp_eid][47:44] == 4'd9 &&
                                venv_parent[hp_eid][31:0] < ENV_DEPTH &&
                                venv_valid[venv_parent[hp_eid][9:0]] &&
                                venv_gen[venv_parent[hp_eid][9:0]] ==
                                    venv_parent[hp_eid][43:32]) begin
                                // Live parent: walk. A swept/stale parent
                                // (GC of an IIFE env still named on a
                                // closure) falls through to vvars like
                                // PYTHON globals — not ERROR_HANDLE.
                                hp_eid <= venv_parent[hp_eid][9:0];
                                hp_len <= {1'b0,
                                    venv_len[venv_parent[hp_eid][9:0]]};
                                hp_slot <= 5'd0;
                                state <= S_HEAP_WAIT;
                            end else if (hp_cmd == HP_GETPROP) begin
                                hp_hit <= 1'b0;
                                hp_rval <= vvar_valid[hp_key[8:0]]
                                    ? vvars[hp_key[8:0]] : V64_UNDEFINED;
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hp_env <= 1'b0;
                                    state <= S_V64_CTOR_ENV;
                                end else begin
                                    hp_env <= 1'b0;
                                    vst_wr(vsp, vvar_valid[hp_key[8:0]]
                                        ? vvars[hp_key[8:0]] : V64_UNDEFINED);
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end else if (hp_phase == 3'd2) begin
                                if (venv_len[hp_eid] >= 5'(ENV_SLOTS)) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3;
                                    running <= 1'b0;
                                    state <= S_DONE;
                                end else begin
                                    hp_slot <= venv_len[hp_eid];
                                    hp_hit <= 1'b0;
                                    state <= S_HEAP_WR;
                                end
                            end else begin
                                if (hp_phase == 3'd0 ||
                                    !vvar_valid[hp_key[8:0]]) begin
                                    vvars[hp_key[8:0]] <= hp_wval;
                                    vvar_valid[hp_key[8:0]] <= 1'b1;
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hp_env <= 1'b0;
                                vsp <= vsp - 12'd1;
                                ip <= ip + 16'd1;
                                code_raddr <=
                                    15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end
                        end
                    end else if (hp_cmd == HP_OGETI) begin
                        hp_rval <= vobj_rdata[63:0];
                        hp_key <= vobj_rdata[79:64];
                        hp_tag <= vobj_trdata;
                        hp_qv[hp_qi[1:0]] <= vobj_rdata[63:0];
                        hp_qk[hp_qi[1:0]] <= vobj_rdata[79:64];
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hp_qi <= hp_qi + 3'd1;
                            hp_slot <= hp_slot + 5'd1;
                            state <= S_HEAP_WAIT;
                        end else
                            state <= hp_ret;
                    end else if (hp_cmd == HP_ARRGET || hp_cmd == HP_AGETI) begin
                        hp_rval <= (hp_aslot < hp_alen)
                            ? varr_rdata : (hp_v64 ? V64_UNDEFINED : 64'd0);
                        hp_tag <= varr_trdata;
                        if (hp_cmd == HP_ARRGET) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd2, (hp_aslot < hp_alen)
                                    ? varr_rdata : V64_UNDEFINED);
                                vsp <= vsp - 12'd1;
                            end else begin
                                stack[sp - 8'd2] <= varr_rdata[31:0];
                                stack_tag[sp - 8'd2] <= varr_trdata;
                                sp <= sp - 8'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else if (hp_v64 && hp_ret == S_FETCH_WAIT) begin
                            // Array.pop: last slot already addressed.
                            vst_wr(vnat_base, (hp_aslot < hp_alen)
                                ? varr_rdata : V64_UNDEFINED);
                            vsp <= vnat_base + 12'd1;
                            state <= S_FETCH_WAIT;
                        end else
                            state <= hp_ret;
                    end else if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_phase == 3'd0) begin
                            hp_wval <= varr_rdata;
                            hp_aslot <= hp_aslot + 7'd1;
                            hp_phase <= 3'd1;
                            state <= S_HEAP_AWR;
                        end else
                            state <= hp_ret;
                    end else if (hp_cmd == HP_SPLICE) begin
                        hp_wval <= varr_rdata;
                        hp_aslot <= hp_aslot - hp_lim[6:0];
                        state <= S_HEAP_AWR;
                    end else if (hp_cmd == HP_ASSIGN) begin
                        if (hp_phase == 3'd3) begin
                            if (hp_qi + 3'd1 >= hp_qn) begin
                                // Result already at hp_vbase-2; drop sources.
                                if (hp_v64)
                                    vsp <= hp_vbase - 12'd1;
                                state <= hp_ret;
                            end else begin
                                hp_qi <= hp_qi + 3'd1;
                                begin
                                    logic [63:0] nsv;
                                    logic src_ok;
                                    logic [12:0] nsi;
                                    if (hp_v64) begin
                                        nsv = `VST_AT(hp_vbase + {9'd0, hp_qi} + 12'd1);
                                        src_ok = (nsv[63:48] == V64_TAG_PREFIX &&
                                            (nsv[47:44] == V64_KIND_OBJECT ||
                                             nsv[47:44] == V64_KIND_ELEMENT) &&
                                            nsv[31:0] < MAX_OBJ &&
                                            vobj_alloc[nsv[12:0]] == 2'd1 &&
                                            vobj_gen[nsv[12:0]] == nsv[43:32]);
                                        nsi = nsv[12:0];
                                    end else begin
                                        nsi = stack[hp_vbase[10:0] + {8'd0, hp_qi} + 11'd1][12:0];
                                        src_ok = (stack_tag[hp_vbase[10:0] + {8'd0, hp_qi} + 11'd1] == 3'd1);
                                    end
                                    if (src_ok) begin
                                        hp_si <= nsi;
                                        hp_ss <= 5'd0;
                                        hp_phase <= 3'd0;
                                        state <= S_HEAP_WAIT;
                                    end else
                                        state <= S_HEAP_WAIT;
                                end
                            end
                        end else if (hp_phase == 3'd0) begin
                            if (hp_ss >= (hp_v64 ? vobj_len[hp_si][4:0]
                                                 : obj_n[hp_si][4:0])) begin
                                hp_phase <= 3'd3;
                                state <= S_HEAP_WAIT;
                            end else begin
                                hp_key <= vobj_rdata[79:64];
                                hp_wval <= vobj_rdata[63:0];
                                hp_tag <= vobj_trdata;
                                hp_phase <= 3'd1;
                                hp_slot <= 5'd0;
                                hp_len <= hp_tn;
                                state <= S_HEAP_WAIT;
                            end
                        end else begin
                            // phase 1: scan target for hp_key
                            if (hp_slot < hp_tn[4:0] &&
                                vobj_rdata[79:64] == hp_key) begin
                                hp_phase <= 3'd2;
                                state <= S_HEAP_WR;
                            end else if (hp_slot + 5'd1 < hp_tn[4:0]) begin
                                hp_slot <= hp_slot + 5'd1;
                                state <= S_HEAP_WAIT;
                            end else if (hp_tn < OBJ_SLOTS[5:0]) begin
                                hp_slot <= hp_tn[4:0];
                                hp_tn <= hp_tn + 6'd1;
                                vobj_len[hp_oid] <= hp_tn + 6'd1;
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, hp_tn + 6'd1});
                                if (!hp_v64)
                                    obj_n[hp_oid] <= hp_tn + 6'd1;
                                hp_phase <= 3'd2;
                                state <= S_HEAP_WR;
                            end else begin
                                hp_ss <= hp_ss + 5'd1;
                                hp_phase <= 3'd0;
                                state <= S_HEAP_WAIT;
                            end
                        end
                    end else if (hp_slot < hp_len &&
                                 vobj_rdata[79:64] == hp_key) begin
                        hp_hit <= 1'b1;
                        hp_rval <= vobj_rdata[63:0];
                        if (hp_cmd == HP_GETPROP || hp_cmd == HP_GETIDX) begin
                            if (hp_v64) begin
                                vst_wr((hp_cmd == HP_GETIDX)
                                    ? (vsp - 12'd2) : (vsp - 12'd1), vobj_rdata[63:0]);
                                // Plant TOS now: hold_win can skip the vst_we
                                // window path for a cycle, and SET_PROP reads
                                // win[0] (PACMAN current.x=12, to.x stored NaN).
                                if (hp_cmd == HP_GETPROP)
                                    vst_win[0] <= vobj_rdata[63:0];
                            end
                            else if (hp_cmd == HP_GETIDX) begin
                                stack[sp - 8'd2] <= vobj_rdata[31:0];
                                stack_tag[sp - 8'd2] <= vobj_trdata;
                                sp <= sp - 8'd1;
                            end else begin
                                stack[sp - 8'd1] <= vobj_rdata[31:0];
                                stack_tag[sp - 8'd1] <= vobj_trdata;
                            end
                            if (hp_cmd == HP_GETIDX && hp_v64)
                                vsp <= vsp - 12'd1;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            hp_key <= vobj_rdata[79:64];
                            state <= S_HEAP_WR;
                        end else if (hp_cmd == HP_LOOKFN) begin
                            // CALL_METHOD wants a function slot, not any key.
                            if ((hp_v64 &&
                                 (vobj_rdata[63:48] != V64_TAG_PREFIX ||
                                  vobj_rdata[47:44] != 4'd7)) ||
                                (!hp_v64 && vobj_trdata != 3'd4)) begin
                                if (hp_slot + 5'd1 < hp_len[4:0]) begin
                                    hp_slot <= hp_slot + 5'd1;
                                    state <= S_HEAP_WAIT;
                                end else begin
                                    hp_hit <= 1'b0;
                                    if (hp_phase == 3'd0 &&
                                        hp_proto[63:48] == V64_TAG_PREFIX &&
                                        hp_proto[47:44] == V64_KIND_OBJECT &&
                                        hp_proto[31:0] < MAX_OBJ &&
                                        vobj_alloc[hp_proto[12:0]] == 2'd1) begin
                                        hp_phase <= 3'd1;
                                        hp_oid <= hp_proto[12:0];
                                        hp_len <= vobj_len[hp_proto[12:0]];
                                        hp_slot <= 5'd0;
                                        state <= S_HEAP_WAIT;
                                    end else begin
                                        hp_rval <= V64_UNDEFINED;
                                        state <= hp_ret;
                                    end
                                end
                            end else begin
                                hp_rval <= vobj_rdata[63:0];
                                hp_tag <= vobj_trdata;
                                state <= hp_ret;
                            end
                        end else if (hp_cmd == HP_OGETI)
                            state <= hp_ret;
                        else
                            state <= hp_ret;
                    end else if (hp_slot + 5'd1 < hp_len[4:0]) begin
                        // Latch __proto__ while walking so tagged miss can
                        // follow it without a second combo scan.
                        if (!hp_v64 &&
                            (hp_cmd == HP_GETPROP || hp_cmd == HP_LOOKFN) &&
                            vobj_rdata[79:64] == id_proto)
                            hp_proto <= vobj_rdata[63:0];
                        hp_slot <= hp_slot + 5'd1;
                        state <= S_HEAP_WAIT;
                    end else begin
                        hp_hit <= 1'b0;
                        if (hp_cmd == HP_GETPROP && hp_phase == 3'd0) begin
                            begin
                                logic [15:0] gip;
                                gip = 16'hFFFF;
                                for (int c = 0; c < MAX_CLS; c++)
                                    if (c < n_cls &&
                                        cls_name[c] == vobj_cls[hp_oid])
                                        for (int m = 0; m < MAX_CMETH; m++)
                                            if (m < cls_nmeth[c] &&
                                                cls_mname[c][m][15] &&
                                                cls_mname[c][m][14:0] ==
                                                    hp_key[14:0])
                                                gip = cls_mip[c][m];
                                if (gip != 16'hFFFF && hp_v64) begin
                                    vsp <= vsp - 12'd1;
                                    vcall_value <= 1'b0;
                                    vcall_entry <= gip;
                                    vcall_argc <= 12'd0;
                                    vcall_set_this <= 1'b1;
                                    vcall_this <= v64_handle(
                                        4'd5, vobj_gen[hp_oid],
                                        {19'd0, hp_oid}
                                    );
                                    vcall_ctor_val <= V64_UNDEFINED;
                                    valloc_kind <= 2'd3;
                                    valloc_i <= {4'd0, venv_next};
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end else if (hp_proto[63:48] == V64_TAG_PREFIX &&
                                    hp_proto[47:44] == V64_KIND_OBJECT &&
                                    hp_proto[31:0] < MAX_OBJ &&
                                    vobj_alloc[hp_proto[12:0]] == 2'd1 &&
                                    vobj_gen[hp_proto[12:0]] ==
                                        hp_proto[43:32]) begin
                                    hp_phase <= 3'd1;
                                    hp_oid <= hp_proto[12:0];
                                    hp_len <= vobj_len[hp_proto[12:0]];
                                    hp_slot <= 5'd0;
                                    state <= S_HEAP_WAIT;
                                end else begin
                                    if (hp_v64) begin
                                        vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                        vst_win[0] <= V64_UNDEFINED;
                                    end else begin
                                        stack[sp - 8'd1] <= 32'd0;
                                        stack_tag[sp - 8'd1] <= 3'd5;
                                    end
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                        end else if (hp_cmd == HP_LOOKFN && hp_phase == 3'd0 &&
                            ((hp_v64 &&
                              hp_proto[63:48] == V64_TAG_PREFIX &&
                              hp_proto[47:44] == V64_KIND_OBJECT &&
                              hp_proto[31:0] < MAX_OBJ &&
                              vobj_alloc[hp_proto[12:0]] == 2'd1) ||
                             (!hp_v64 && hp_proto[15:0] != 16'hFFFF))) begin
                            hp_phase <= 3'd1;
                            hp_oid <= hp_proto[12:0];
                            hp_len <= hp_v64 ? vobj_len[hp_proto[12:0]]
                                             : obj_n[hp_proto[12:0]];
                            hp_slot <= 5'd0;
                            state <= S_HEAP_WAIT;
                        end else if ((hp_cmd == HP_SETPROP ||
                                      hp_cmd == HP_SETIDX) &&
                                     hp_len < OBJ_SLOTS[5:0]) begin
                            hp_slot <= hp_len[4:0];
                            vobj_len[hp_oid] <= hp_len + 6'd1;
                            e64_poke(6'd2, {3'd0, hp_oid},
                                     {58'd0, hp_len + 6'd1});
                            if (!hp_v64)
                                obj_n[hp_oid] <= hp_len + 6'd1;
                            state <= S_HEAP_WR;
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
                        end else if (hp_cmd == HP_GETIDX) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                vsp <= vsp - 12'd1;
                            end else begin
                                stack[sp - 8'd2] <= 32'd0;
                                stack_tag[sp - 8'd2] <= 3'd5;
                                sp <= sp - 8'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else if (hp_cmd == HP_GETPROP) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                vst_win[0] <= V64_UNDEFINED;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else begin
                            hp_rval <= hp_v64 ? V64_UNDEFINED : 64'd0;
                            hp_hit <= 1'b0;
                            state <= hp_ret;
                        end
                    end
                end
                S_HEAP_WR: begin
                    if (hp_env) begin
                        if (!hp_hit) begin
                            venv_len[hp_eid] <= venv_len[hp_eid] + 5'd1;
                            e64_poke(6'd10, {6'd0, hp_eid},
                                     {59'd0, venv_len[hp_eid] + 5'd1});
                        end
                        vsp <= vsp - 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        hp_env <= 1'b0;
                        state <= S_FETCH_WAIT;
                    end else if (hp_cmd == HP_OSETI) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hp_qi <= hp_qi + 3'd1;
                            state <= S_HEAP_WR;
                        end else begin
                            if (vobj_len[hp_oid] < {3'd0, hp_qn} + {1'b0, hp_slot}) begin
                                vobj_len[hp_oid] <=
                                    {3'd0, hp_qn} + {1'b0, hp_slot};
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, {3'd0, hp_qn} + {1'b0, hp_slot}});
                                if (!hp_v64)
                                    obj_n[hp_oid] <=
                                        {3'd0, hp_qn} + {1'b0, hp_slot};
                            end else if (!hp_v64)
                                obj_n[hp_oid] <= vobj_len[hp_oid];
                            state <= hp_ret;
                        end
                    end else if (hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX)
                    begin
                        // Image.src jmr:spr:N also writes width/height
                        // (phase 3→4→5). Do not combo-walk slots for that.
                        if (hp_phase == 3'd3) begin
                            hp_key <= id_width;
                            hp_wval <= v64_int32_number({16'd0, hp_spr_w});
                            hp_slot <= 5'd0;
                            hp_len <= vobj_len[hp_oid];
                            hp_phase <= 3'd4;
                            hp_hit <= 1'b0;
                            state <= S_HEAP_WAIT;
                        end else if (hp_phase == 3'd4) begin
                            hp_key <= id_height;
                            hp_wval <= v64_int32_number({16'd0, hp_spr_h});
                            hp_slot <= 5'd0;
                            hp_len <= vobj_len[hp_oid];
                            hp_phase <= 3'd5;
                            hp_hit <= 1'b0;
                            state <= S_HEAP_WAIT;
                        end else if (hp_phase == 3'd6) begin
                            // Image.onload = fn — invoke now (title img ready).
                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                            vsp <= vsp - 12'd1;
                            vcall_value <= 1'b1;
                            vcall_argc <= 12'd0;
                            vcall_set_this <= 1'b1;
                            vcall_this <= v64_handle(
                                4'd5, vobj_gen[hp_oid], {19'd0, hp_oid}
                            );
                            vcall_ctor_val <= V64_UNDEFINED;
                            valloc_kind <= 2'd3;
                            valloc_i <= {4'd0, venv_next};
                            valloc_retried <= 1'b0;
                            ip <= ip + 16'd1;
                            state <= S_V64_ALLOC;
                        end else if (hp_v64) begin
                            if (hp_cmd == HP_SETIDX) begin
                                vst_wr(vsp - 12'd3, hp_wval);
                                vsp <= vsp - 12'd2;
                            end else begin
                                vst_wr(vsp - 12'd2, hp_wval);
                                vsp <= vsp - 12'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else begin
                            if (hp_cmd == HP_SETIDX) begin
                                stack[sp - 8'd3] <= hp_wval[31:0];
                                stack_tag[sp - 8'd3] <= hp_tag;
                                sp <= sp - 8'd2;
                            end else begin
                                stack[sp - 8'd2] <= hp_wval[31:0];
                                stack_tag[sp - 8'd2] <= hp_tag;
                                sp <= sp - 8'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end
                    end else if (hp_cmd == HP_ASSIGN) begin
                        hp_ss <= hp_ss + 5'd1;
                        hp_phase <= 3'd0;
                        state <= S_HEAP_WAIT;
                    end else
                        state <= hp_ret;
                end
                S_HEAP_AWR: begin
                    if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_aslot > 7'd1) begin
                            hp_aslot <= hp_aslot - 7'd2;
                            hp_phase <= 3'd0;
                            state <= S_HEAP_WAIT;
                        end else begin
                            hp_aslot <= 7'd0;
                            hp_wval <= hp_rval;
                            hp_cmd <= HP_ASETI;
                            state <= S_HEAP_AWR;
                        end
                    end else if (hp_cmd == HP_SPLICE) begin
                        if (hp_aslot + hp_lim[6:0] + 7'd1 < hp_alen) begin
                            hp_aslot <= hp_aslot + hp_lim[6:0] + 7'd1;
                            state <= S_HEAP_WAIT;
                        end else
                            state <= hp_ret;
                    end else if (hp_cmd == HP_PUSH) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hp_qi <= hp_qi + 3'd1;
                            hp_aslot <= hp_aslot + 7'd1;
                            hp_wval <= hp_qv[hp_qi[1:0] + 2'd1];
                            state <= S_HEAP_AWR;
                        end else
                            state <= hp_ret;
                    end else if (hp_cmd == HP_ARRSET) begin
                        if (hp_v64) begin
                            vst_wr(vsp - 12'd3, hp_wval);
                            vsp <= vsp - 12'd2;
                        end else begin
                            stack[sp - 8'd3] <= hp_wval[31:0];
                            stack_tag[sp - 8'd3] <= hp_tag;
                            sp <= sp - 8'd2;
                        end
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end else
                        state <= hp_ret;
                end
                S_HEAP_FILL: begin
                    // Value64 stack→array: wait one clock for vst_rdata
                    // (1W1R), then write. Combo `VST_AT(hp_vbase+i) was a
                    // second port and killed ram_style=block.
                    if (hp_from_stack && hp_v64 && hp_phase != 3'd1) begin
                        hp_phase <= 3'd1;
                        state <= S_HEAP_FILL;
                    end else if ({1'b0, hp_aslot} + 8'd1 < hp_lim) begin
                        hp_aslot <= hp_aslot + 7'd1;
                        hp_phase <= 3'd0;
                        state <= S_HEAP_FILL;
                    end else if (hp_cmd == HP_ARRSET) begin
                        hp_aslot <= hp_lim[6:0];
                        hp_wval <= hp_rval;
                        hp_phase <= 3'd0;
                        state <= S_HEAP_AWR;
                    end else begin
                        // MAKE_ARRAY handle after SRAM copy — writing it first
                        // made a[0] the array itself (PACMAN ARRAY_GET fault=255).
                        if (hp_make_arr) begin
                            if (hp_v64)
                                vst_wr(hp_vbase, hp_rval);
                            else begin
                                stack[hp_vbase[10:0]] <= hp_rval[31:0];
                                stack_tag[hp_vbase[10:0]] <= 3'd2;
                            end
                            hp_make_arr <= 1'b0;
                            hp_phase <= 3'd0;
                            // MAKE_ARRAY of 16+ drops vsp by >=15; the TOS
                            // window only slides ±1/clock (or FF-copy if
                            // sh<16, which still misses `this` below 16
                            // elements). SET_PROP then peeks win[1] leftover
                            // instead of the receiver. PYTHON's stack is
                            // deep; refill win[1..] from BRAM. win[0] is
                            // the handle from vst_wr above.
                            if (hp_v64 && hp_lim >= 8'd16 && vsp >= 12'd2) begin
                                vst_refill_i <= 4'd1;
                                vst_refill_arm <= 1'b0;
                                vst_refill_ret <= hp_ret;
                                vst_hold_win <= 1'b1;
                                // hold_win skips the vst_we window path, so
                                // plant TOS here (handle is hp_rval).
                                vst_win[0] <= hp_rval;
                                state <= S_V64_WIN_FILL;
                            end else
                                state <= hp_ret;
                        end else begin
                            hp_phase <= 3'd0;
                            state <= hp_ret;
                        end
                    end
                end
                S_REL_ENV: begin
                    // One live env_sp slot per clock. Dup scan is constant
                    // TAGGED_ENV_DEPTH=32, not ENV_DEPTH=1024.
                    if (env_sp == 6'd0 || rel_i >= rel_lim) begin
                        env_free_n <= rel_nn;
                        env_sp <= rel_saved;
                        state <= rel_ret;
                    end else begin
                        begin
                            logic dup;
                            logic [15:0] oid;
                            oid = env_oid[rel_i];
                            dup = 1'b0;
                            for (int j = 0; j < 32; j++)
                                if (j < 32'(rel_nn) && env_free[j] == oid)
                                    dup = 1'b1;
                            if (!env_cap[rel_i]) begin
                                if (rel_i == (rel_lim - 6'd1) &&
                                    n_obj == (oid + 16'd1))
                                    n_obj <= oid;
                                else if (!dup &&
                                         rel_nn < TAGGED_ENV_DEPTH[5:0] &&
                                         (!obj_keep_ok || oid < n_obj_keep))
                                begin
                                    env_free[rel_nn] <= oid;
                                    rel_nn <= rel_nn + 6'd1;
                                end
                            end
                            rel_i <= rel_i + 6'd1;
                        end
                    end
                end
                S_FREE_OBJ: begin
                    if (valloc_i < MAX_OBJ &&
                        vobj_alloc[valloc_i[12:0]] == 2'd0) begin
                        vfree_ok <= 1'b1;
                        state <= hp_ret;
                    end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                        valloc_i <= valloc_i + 14'd1;
                    end else begin
                        vfree_ok <= 1'b0;
                        state <= hp_ret;
                    end
                end
                S_FREE_ARR: begin
                    if (vfree_arr_long && valloc_i < 14'(MAX_ARR_SHORT)) begin
                        valloc_i <= 14'(MAX_ARR_SHORT);
                    end else if (valloc_i < MAX_ARR &&
                        !varr_valid[valloc_i[11:0]] &&
                        (valloc_i < 14'(MAX_ARR_SHORT) ||
                         !vlong_used[valloc_i[7:0]]) &&
                        (!vfree_arr_long ||
                         valloc_i >= 14'(MAX_ARR_SHORT))) begin
                        vfree_ok <= 1'b1;
                        state <= hp_ret;
                    end else if (valloc_i + 14'd1 < MAX_ARR) begin
                        valloc_i <= valloc_i + 14'd1;
                    end else begin
                        vfree_ok <= 1'b0;
                        state <= hp_ret;
                    end
                end
                S_ARR_PROMOTE: begin
                    // Same handle; copy short SRAM into a free long phys row.
                    if (varr_long[hp_aid]) begin
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        state <= vprom_ret;
                    end else if (!vprom_copy) begin
                        if (valloc_i < 14'(MAX_ARR_LONG) &&
                            !vlong_used[valloc_i[7:0]]) begin
                            vlong_used[valloc_i[7:0]] <= 1'b1;
                            hp_prom_phys <= valloc_i[7:0];
                            vprom_copy <= 1'b1;
                            dc_i <= 8'd0;
                            hp_phase <= 3'd0;
                            hp_prom_wr <= 1'b0;
                        end else if (valloc_i + 14'd1 < 14'(MAX_ARR_LONG)) begin
                            valloc_i <= valloc_i + 14'd1;
                        end else begin
                            machine_fault <= 1'b1;
                            fault_code <= 8'd3;
                            running <= 1'b0;
                            state <= S_DONE;
                        end
                    end else if (dc_i >= varr_len[hp_aid]) begin
                        varr_long[hp_aid] <= 1'b1;
                        varr_lidx[hp_aid] <= hp_prom_phys;
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        state <= vprom_ret;
                    end else if (hp_phase == 3'd0) begin
                        hp_cmd <= HP_AGETI;
                        hp_v64 <= 1'b1;
                        hp_aslot <= dc_i[6:0];
                        hp_alen <= varr_len[hp_aid];
                        hp_ret <= S_ARR_PROMOTE;
                        hp_phase <= 3'd1;
                        hp_prom_wr <= 1'b0;
                        state <= S_HEAP_WAIT;
                    end else begin
                        hp_cmd <= HP_ASETI;
                        hp_v64 <= 1'b1;
                        hp_from_stack <= 1'b0;
                        hp_aslot <= dc_i[6:0];
                        hp_wval <= hp_rval;
                        hp_ret <= S_ARR_PROMOTE;
                        hp_phase <= 3'd0;
                        dc_i <= dc_i + 8'd1;
                        hp_prom_wr <= 1'b1;
                        state <= S_HEAP_AWR;
                    end
                end
                S_V64_BIND: begin
                    // bind_mode 0: dest[k]=(k<argc)?src[k]:UNDEF, k=0..n-1
                    // bind_mode 1: dest[k]=dest[k+1] (drop callee), k=0..n-1
                    // bind_mode 2: dest[k+1]=src[k] downward
                    // bind_mode 3: write bind_ins at bind_base (after mode 2)
                    if (bind_mode == 2'd3) begin
                        vst_wr(bind_base, bind_ins);
                        begin
                            integer fd;
                            fd = integer'(bind_n);
                            if (fd >= 0 && fd < 16)
                                vst_win[fd[3:0]] <= bind_ins;
                        end
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        vsp <= bind_vsp_next;
                        state <= bind_ret;
                    end else if (bind_n == 8'd0) begin
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        vsp <= bind_vsp_next;
                        if (bind_mode != 2'd1) begin
                            ip <= bind_ip;
                            code_raddr <= 15'(ops_base + bind_ip);
                        end
                        state <= bind_ret;
                    end else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                        bind_armed <= 1'b1;
                        vst_hold_win <= 1'b1;
                    end else begin
                        logic [63:0] srcv;
                        logic [11:0] dst;
                        integer fd;
                        srcv = (bind_mode == 2'd0 && bind_k >= bind_argc)
                            ? V64_UNDEFINED : vst_rdata;
                        dst = (bind_mode == 2'd2)
                            ? (bind_base + {4'd0, bind_k} + 12'd1)
                            : (bind_base + {4'd0, bind_k});
                        vst_wr(dst, srcv);
                        fd = integer'(bind_vsp_next) - 1 - integer'(dst);
                        if (fd >= 0 && fd < 16)
                            vst_win[fd[3:0]] <= srcv;
                        bind_rd_arm <= 1'b0;
                        if (bind_mode == 2'd2) begin
                            if (bind_k == 8'd0)
                                bind_mode <= 2'd3;
                            else
                                bind_k <= bind_k - 8'd1;
                        end else if (bind_k + 8'd1 >= bind_n) begin
                            bind_armed <= 1'b0;
                            vsp <= bind_vsp_next;
                            if (bind_mode != 2'd1) begin
                                ip <= bind_ip;
                                code_raddr <= 15'(ops_base + bind_ip);
                            end
                            state <= bind_ret;
                        end else
                            bind_k <= bind_k + 8'd1;
                    end
                end
                S_V64_MINMAX: begin
                    if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                    end else if (minmax_k >= minmax_n) begin
                        vst_wr(minmax_base, minmax_acc);
                        vsp <= minmax_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        bind_rd_arm <= 1'b0;
                        state <= S_FETCH_WAIT;
                    end else begin
                        logic [63:0] arg;
                        arg = vst_rdata;
                        if (arg[62:52] == 11'h7ff && arg[51:0] != 0)
                            minmax_acc <= V64_CANON_NAN;
                        else if (minmax_is_min
                                 ? v64_less(arg, minmax_acc)
                                 : v64_less(minmax_acc, arg))
                            minmax_acc <= arg;
                        minmax_k <= minmax_k + 8'd1;
                        bind_rd_arm <= 1'b0;
                    end
                end
                S_V64_WIN_FILL: begin
                    // Reload vst_win[i] from vstack[vsp-1-i], one slot per
                    // two clocks (addr, then vst_rdata). Starts at i=1:
                    // win[0] already has the MAKE_ARRAY/RET_VAL handle.
                    vst_hold_win <= 1'b1;
                    if (!vst_refill_arm) begin
                        vst_refill_arm <= 1'b1;
                        state <= S_V64_WIN_FILL;
                    end else begin
                        vst_win[vst_refill_i] <= vst_rdata;
                        // +1 fills every live slot (ARRAY_SET needs win[2]
                        // when vsp==3). +2 skipped the handle.
                        if (vst_refill_i == 4'd15 ||
                            ({8'd0, vst_refill_i} + 12'd1 >= vsp)) begin
                            vst_hold_win <= 1'b0;
                            vst_refill_arm <= 1'b0;
                            state <= vst_refill_ret;
                        end else begin
                            vst_refill_i <= vst_refill_i + 4'd1;
                            vst_refill_arm <= 1'b0;
                            state <= S_V64_WIN_FILL;
                        end
                    end
                end
                S_V64_METH: begin
                    // LOOKFN finished: own/proto function or unknown method.
                    if (!hp_v64) begin
                        if (hp_hit && hp_tag == 3'd4) begin
                            begin
                                logic [7:0] ac;
                                logic [15:0] oid, fip;
                                ac = vcall_argc[7:0];
                                oid = vcall_this[15:0];
                                fip = hp_rval[15:0];
                                for (int k = 0; k < 8; k++) begin
                                    if (k < ac) begin
                                        stack[sp - ac - 8'd1 + k[7:0]] <=
                                            stack[sp - ac + k[7:0]];
                                        stack_tag[sp - ac - 8'd1 + k[7:0]] <=
                                            stack_tag[sp - ac + k[7:0]];
                                    end
                                end
                                sp <= sp - 8'd1;
                                cstack_ip[csp] <= ip + 16'd1;
                                cstack_this[csp] <= this_obj;
                                cstack_isctor[csp] <= 1'b0;
                                cstack_isfe[csp] <= 1'b0;
                                enter_captured_fn(fip);
                                bump_csp();
                                this_obj <= oid;
                                if (this_ok) begin
                                    vars[var_this] <= oid;
                                    var_tag[var_this] <= 3'd1;
                                end
                                ip <= fn_entry(fip);
                                code_raddr <= 15'(ops_base + fn_entry(fip));
                                state <= S_FETCH_WAIT;
                            end
                        end else begin
                            begin
                                logic [7:0] ac;
                                ac = vcall_argc[7:0];
                                stack[sp - ac - 8'd1] <= 32'sd0;
                                stack_tag[sp - ac - 8'd1] <= 3'd5;
                                sp <= sp - ac;
                                ip <= ip + 16'd1;
                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end
                        end
                    end else if (hp_hit &&
                        hp_rval[63:48] == V64_TAG_PREFIX &&
                        hp_rval[47:44] == 4'd7 &&
                        hp_rval[31:0] < MAX_OBJ &&
                        vfn_valid[hp_rval[12:0]]) begin
                        vst_wr(vnat_base, hp_rval);
                        // Plant TOS window this cycle: S_V64_ALLOC reads
                        // VST_AT(callee) next clock. vst_we window update is
                        // one cycle later, so ALLOC would see the receiver
                        // (vfn_entry=0 → ip=0 → maps IIFE nested).
                        begin
                            integer fd;
                            fd = integer'(vcall_argc);
                            if (fd >= 0 && fd < 16)
                                vst_win[fd[3:0]] <= hp_rval;
                        end
                        vcall_value <= 1'b1;
                        vcall_set_this <= 1'b1;
                        vcall_ctor_val <= V64_UNDEFINED;
                        valloc_kind <= 2'd3;
                        valloc_i <= {4'd0, venv_next};
                        valloc_retried <= 1'b0;
                        state <= S_V64_ALLOC;
                    end else begin
                        vst_wr(vnat_base, (vobj_builtin[hp_oid] == 4'd6)
                            ? v64_handle(4'd3, 12'd0, 32'd0)
                            : (vobj_builtin[hp_oid] != 4'd0)
                            ? vcall_this : V64_UNDEFINED);
                        vsp <= vnat_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end
                end
                S_V64_FE_ELEM: begin
                    if (!hp_v64) begin
                        stack[sp - 8'd1] <= hp_rval[31:0];
                        stack_tag[sp - 8'd1] <= hp_tag;
                        arm_release_env(cstack_env[csp - 7'd1], S_FETCH_WAIT);
                        ip <= cstack_ip[csp - 7'd2];
                        this_obj <= cstack_this[csp - 7'd2];
                        if (this_ok) begin
                            vars[var_this] <= (cstack_this[csp - 7'd2] == 16'hFFFF)
                                              ? 32'd0
                                              : {16'd0, cstack_this[csp - 7'd2]};
                            var_tag[var_this] <= (cstack_this[csp - 7'd2] == 16'hFFFF)
                                                 ? 3'd5 : 3'd1;
                        end
                        csp <= csp - 7'd2;
                        code_raddr <= 15'(ops_base + cstack_ip[csp - 7'd2]);
                    end else begin
                    vst_wr(vfe_base, hp_rval);
                    vsp <= vfe_base + 12'd1;
                    ip <= vfe_ret;
                    code_raddr <= 15'(ops_base + vfe_ret);
                    if (vfe_sp != 4'd0) begin
                        vfe_arr <= vfe_arr_s[vfe_sp - 4'd1];
                        vfe_fn <= vfe_fn_s[vfe_sp - 4'd1];
                        vfe_i <= vfe_i_s[vfe_sp - 4'd1];
                        vfe_ret <= vfe_ret_s[vfe_sp - 4'd1];
                        vfe_base <= vfe_base_s[vfe_sp - 4'd1];
                        vfe_mode <= vfe_mode_s[vfe_sp - 4'd1];
                        vfe_map <= vfe_map_s[vfe_sp - 4'd1];
                        vfe_sp <= vfe_sp - 4'd1;
                    end else begin
                        vfe_arr <= V64_UNDEFINED;
                        vfe_fn <= V64_UNDEFINED;
                        vfe_mode <= 2'd0;
                        vfe_map <= V64_UNDEFINED;
                    end
                    state <= S_FETCH_WAIT;
                    end
                end
                S_V64_FE_FILTER: begin
                    begin
                        logic [7:0] fl;
                        fl = varr_len[vfe_map[11:0]];
                        if (fl < ARR_CAP[7:0]) begin
                            varr_len[vfe_map[11:0]] <= fl + 8'd1;
                            e64_poke(6'd6, {4'd0, vfe_map[11:0]},
                                     {56'd0, fl + 8'd1});
                            hp_cmd <= HP_ASETI;
                            hp_v64 <= 1'b1;
                            hp_from_stack <= 1'b0;
                            hp_aid <= vfe_map[11:0];
                            hp_aslot <= fl[6:0];
                            hp_wval <= hp_rval;
                            hp_ret <= S_V64_FOREACH;
                            state <= S_HEAP_AWR;
                        end else
                            state <= S_V64_FOREACH;
                    end
                end
                S_V64_IDXSCAN: begin
                    if (v64_equal(hp_rval, hp_wval)) begin
                        vst_wr(hp_vbase, v64_int32_number({24'd0, hp_aslot}));
                        vsp <= hp_vbase + 12'd1;
                        state <= S_FETCH_WAIT;
                    end else if (hp_aslot + 7'd1 < hp_alen) begin
                        hp_aslot <= hp_aslot + 7'd1;
                        state <= S_HEAP_WAIT;
                    end else begin
                        vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                        vsp <= hp_vbase + 12'd1;
                        state <= S_FETCH_WAIT;
                    end
                end
                S_V64_OGETI_NAT: begin
                    case (hp_nat)
                        4'd0: begin
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            js_sp <= 6'd0;
                            json_pph <= 3'd0;
                            state <= S_V64_JSON_PARSE;
                        end
                        4'd1: begin
                            imgd_w <= v64_to_uint32(hp_qv[0])[9:0];
                            imgd_h <= v64_to_uint32(hp_qv[1])[9:0];
                            imgd_x <= 10'd0; imgd_y <= 10'd0;
                            imgd_i <= 19'd0;
                            imgd_v64 <= 1'b1;
                            state <= S_IMGD_PUT;
                        end
                        4'd2: begin
                            begin
                                logic [15:0] tl;
                                tl = 16'(v64_to_uint32(hp_qv[1]));
                                vmetrics_w <= (tl << 3);
                                if (vmetrics[63:48] == V64_TAG_PREFIX &&
                                    vmetrics[47:44] == V64_KIND_OBJECT &&
                                    vmetrics[31:0] < MAX_OBJ &&
                                    vobj_alloc[vmetrics[12:0]] == 2'd1)
                                begin
                                    hp_cmd <= HP_OSETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= vmetrics[12:0];
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd1;
                                    hp_qi <= 3'd0;
                                    hp_qk[0] <= id_width;
                                    hp_qv[0] <=
                                        v64_int32_number({16'd0, tl << 3});
                                    hp_qt[0] <= 3'd0;
                                    hp_ret <= S_FETCH_WAIT;
                                    vst_wr(hp_vbase, vmetrics);
                                    vsp <= hp_vbase + 12'd1;
                                    state <= S_HEAP_WR;
                                end else begin
                                    valloc_metrics <= 1'b1;
                                    vnat_base <= hp_vbase;
                                    valloc_kind <= 2'd0;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                        end
                        4'd3: begin
                            // Dynstr indexOf: same latch as replace (4'd4) then
                            // S_IDXSTR. Do not combo-for JSON_CAP (Vivado hang).
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            // OGETI overwrites hp_key with the slot name;
                            // needle was saved in hp_wval (same as tagged S_IDXSTR).
                            idx_needle <= hp_wval[7:0];
                            state <= S_IDXSTR;
                        end
                        4'd4: begin
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            json_dst <= 14'(v64_to_uint32(hp_qv[0]))
                                + 14'(v64_to_uint32(hp_qv[1]));
                            json_wp <= 14'(v64_to_uint32(hp_qv[0]))
                                + 14'(v64_to_uint32(hp_qv[1]));
                            if (hp_oid != 13'd0 &&
                                vobj_builtin[hp_oid] == 4'd6)
                                ; // regex pack already in hp_wval
                            state <= S_REPL;
                        end
                        4'd5: begin
                            begin
                                logic [31:0] preg;
                                preg = hp_qv[0][31:0];
                                repl_pat0 <= preg[7:0];
                                repl_pat1 <= preg[15:8];
                                repl_nlen <= preg[23:16];
                                repl_g <= preg[24];
                                if (hp_phase == 3'd1) begin
                                    hp_nat <= 4'd4;
                                    hp_cmd <= HP_OGETI;
                                    hp_v64 <= 1'b1;
                                    hp_oid <= hp_si;
                                    hp_slot <= 5'd0;
                                    hp_qn <= 3'd2;
                                    hp_qi <= 3'd0;
                                    hp_ret <= S_V64_OGETI_NAT;
                                    state <= S_HEAP_WAIT;
                                end else
                                    state <= S_NAMCPY;
                            end
                        end
                        4'd6: begin
                            stack[sp - 8'd1] <= hp_rval[31:0];
                            stack_tag[sp - 8'd1] <= 3'd0;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end
                        4'd7: begin
                            json_src <= hp_qv[0][13:0];
                            json_srclen <= hp_qv[1][13:0];
                            json_rp <= hp_qv[0][13:0];
                            if (hp_lim == 8'd1) begin
                                json_dst <= hp_qv[0][13:0] + hp_qv[1][13:0];
                                json_wp <= hp_qv[0][13:0] + hp_qv[1][13:0];
                                state <= S_REPL;
                            end else if (hp_lim == 8'd2)
                                state <= S_IDXSTR;
                            else
                                state <= S_JSON_PARSE;
                        end
                        4'd8: begin
                            imgd_w <= hp_qv[0][9:0];
                            imgd_h <= hp_qv[1][9:0];
                            state <= S_IMGD_PUT;
                        end
                        4'd9: begin
                            txt_rp <= 16'(hp_qv[0][13:0]);
                            txt_len <= (hp_qv[1][13:0] > 14'(TXT_MAX))
                                ? 7'(TXT_MAX) : 7'(hp_qv[1][13:0]);
                            txt_ph <= (hp_qv[1][13:0] == 14'd0) ? 4'd6 : 4'd4;
                            state <= S_TXT_LD;
                        end
                        4'd10: begin
                            repl_pat0 <= hp_qv[0][7:0];
                            repl_pat1 <= hp_qv[0][15:8];
                            repl_nlen <= hp_qv[0][23:16];
                            repl_g <= hp_qv[0][24];
                            if (hp_phase == 3'd1) begin
                                hp_nat <= 4'd7;
                                hp_lim <= 8'd1;
                                hp_cmd <= HP_OGETI;
                                hp_v64 <= 1'b0;
                                hp_oid <= hp_si;
                                hp_slot <= 5'd0;
                                hp_qn <= 3'd2;
                                hp_qi <= 3'd0;
                                hp_ret <= S_V64_OGETI_NAT;
                                state <= S_HEAP_WAIT;
                            end else
                                state <= S_REPL;
                        end
                        4'd11: begin
                            begin
                                logic [15:0] tl, px_, moid;
                                logic [7:0] ac;
                                tl = {2'd0, hp_rval[13:0]};
                                ac = 8'(sp - hp_vbase[10:0]);
                                px_ = 16'((48'(ctx_font_px) * 48'(ctx_sx)
                                          + 48'sd262144) >>> 19);
                                if (px_ == 16'd0) px_ = 16'd1;
                                moid = (metrics_oid == 16'hFFFF) ? n_obj : metrics_oid;
                                obj_cls[moid[12:0]] <= 16'd0;
                                obj_n[moid[12:0]] <= 6'd1;
                                hp_cmd <= HP_OSETI;
                                hp_v64 <= 1'b0;
                                hp_oid <= moid[12:0];
                                hp_slot <= 5'd0;
                                hp_qn <= 3'd1;
                                hp_qi <= 3'd0;
                                hp_qk[0] <= id_width;
                                hp_qv[0] <= {32'd0, 32'(px_) * 32'(tl)};
                                hp_qt[0] <= 3'd0;
                                if (metrics_oid == 16'hFFFF) begin
                                    if (n_obj >= 16'(MAX_OBJ - 1))
                                        dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                    else begin
                                        metrics_oid <= n_obj;
                                        n_obj <= n_obj + 16'd1;
                                        if ((n_obj + 16'd1) > n_obj_keep)
                                            n_obj_keep <= n_obj + 16'd1;
                                    end
                                end
                                stack[hp_vbase[10:0] - 11'd1] <= {16'd0, moid};
                                stack_tag[hp_vbase[10:0] - 11'd1] <= 3'd1;
                                sp <= hp_vbase[10:0];
                                ip <= ip + 16'd1;
                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                hp_ret <= S_FETCH_WAIT;
                                state <= S_HEAP_WR;
                            end
                        end
                        default: state <= S_FETCH_WAIT;
                    endcase
                end
                S_V64_FRAME_KEY: begin
                    logic [63:0] want;
                    logic found_fn;
                    logic [4:0] pick;
                    want = v64_handle(
                        4'd4, 12'd0,
                        {16'd0, kev_q[kev_rp][8] ? id_keydown : id_keyup}
                    );
                    found_fn = 1'b0;
                    pick = 5'd0;
                    for (int k = 0; k < 16; k++)
                        if (!found_fn && k >= vkey_li && k < vlistener_n &&
                            v64_equal(vlistener_ev[k], want)) begin
                            found_fn = 1'b1;
                            pick = 5'(k);
                        end
                    if (found_fn) begin
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0; state <= S_DONE;
                        end else if (!bind_rd_arm) begin
                            // Beat 0: push fn. vst_wr is 1W; window follows +1.
                            vst_wr(vsp, vlistener_fn[pick]);
                            vsp <= vsp + 12'd1;
                            bind_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            vst_wr(vsp, vkev_event);
                            vsp <= vsp + 12'd1;
                            bind_k <= 8'd1;
                        end else begin
                            // Idle: ALLOC combo-reads last cycle's TOS window.
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            vcall_value <= 1'b1;
                            vcall_argc <= 12'd1;
                            vcallback_key <= 1'b1;
                            valloc_kind <= 2'd3;
                            valloc_i <= venv_next;
                            valloc_retried <= 1'b0;
                            vkey_li <= pick + 5'd1;
                            state <= S_V64_ALLOC;
                        end
                    end else begin
                        kev_rp <= kev_rp + 3'd1;
                        vkey_li <= 5'd0;
                        bind_rd_arm <= 1'b0;
                        state <= S_WAIT_FRAME;
                    end
                end
                S_V64_FRAME_RAF: begin
                    if (vraf_i < vraf_snap_n) begin
                        logic [63:0] timestamp, frame_number;
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            state <= S_DONE;
                        end else if (!bind_rd_arm) begin
                            // Beat 0: push fn. Two vst_wr in one cycle kept
                            // only the timestamp; window shifts ±1 so vsp+2
                            // also desynced TOS (INVADERS rAF never re-armed).
                            vst_wr(vsp, vraf_snap[vraf_i]);
                            vsp <= vsp + 12'd1;
                            bind_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            frame_number = v64_int32_number(vframe_no);
                            v64_mul_task(
                                frame_number, 64'h4030aaaaaaaaaaab,
                                timestamp
                            );
                            vst_wr(vsp, timestamp);
                            vsp <= vsp + 12'd1;
                            bind_k <= 8'd1;
                        end else begin
                            // Idle: ALLOC combo-reads last cycle's TOS window.
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            vcall_value <= 1'b1;
                            vcall_argc <= 12'd1;
                            vcallback_raf <= 1'b1;
                            valloc_kind <= 2'd3;
                            valloc_i <= venv_next;
                            valloc_retried <= 1'b0;
                            vraf_i <= vraf_i + 4'd1;
                            state <= S_V64_ALLOC;
                        end
                    end else begin
                        vraf_snap_n <= 4'd0;
                        bind_rd_arm <= 1'b0;
                        state <= S_V64_FRAME_TIMER;
                    end
                end
                S_V64_FRAME_TIMER: begin
                    logic found_due;
                    logic [6:0] pick;
                    logic signed [31:0] best_due, best_id;
                    found_due = 1'b0;
                    pick = 7'd0;
                    best_due = 32'sh7fffffff;
                    best_id = 32'sh7fffffff;
                    for (int k = 0; k < 64; k++)
                        if (vtimer_valid[k] &&
                            vtimer_due[k] <= $signed(vframe_no) &&
                            (!found_due || vtimer_due[k] < best_due ||
                             (vtimer_due[k] == best_due &&
                              vtimer_id[k] < best_id))) begin
                            found_due = 1'b1;
                            pick = 7'(k);
                            best_due = vtimer_due[k];
                            best_id = vtimer_id[k];
                        end
                    if (found_due) begin
                        if (vcsp >= CSTK || vsp >= STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            state <= S_DONE;
                        end else if (!bind_rd_arm) begin
                            vst_wr(vsp, vtimer_fn[pick]);
                            vsp <= vsp + 12'd1;
                            bind_rd_arm <= 1'b1;
                        end else begin
                            // Idle so `VST_AT sees the fn (argc 0 → TOS).
                            bind_rd_arm <= 1'b0;
                            if (vtimer_period[pick] < 0) begin
                                vtimer_valid[pick] <= 1'b0;
                                vtimer_n <= vtimer_n - 7'd1;
                            end else
                                vtimer_due[pick] <= vtimer_due[pick] +
                                    vtimer_period[pick][31:0];
                            vcall_value <= 1'b1;
                            vcall_argc <= 12'd0;
                            vcallback_timer <= 1'b1;
                            valloc_kind <= 2'd3;
                            valloc_i <= venv_next;
                            valloc_retried <= 1'b0;
                            state <= S_V64_ALLOC;
                        end
                    end else begin
                        bind_rd_arm <= 1'b0;
                        fb_swap <= 1'b1; // PYTHON present(): scanout the back
                        vgc_clear_i <= 14'd0;
                        vgc_qr <= 14'd0;
                        vgc_qw <= 14'd0;
                        vgc_halt_after <= 1'b1;
                        vgc_wait_after <= 1'b1;
                        state <= S_V64_GC_CLEAR;
                    end
                end
                S_V64_DIV: begin
                    logic [53:0] shifted_rem, next_rem;
                    logic quotient_bit;
                    shifted_rem = {vdiv_rem[52:0], vdiv_num[106]};
                    quotient_bit = shifted_rem >= {1'b0, vdiv_den};
                    next_rem = quotient_bit
                             ? shifted_rem - {1'b0, vdiv_den}
                             : shifted_rem;
                    vdiv_num <= {vdiv_num[105:0], 1'b0};
                    vdiv_rem <= next_rem;
                    vdiv_quot <= {vdiv_quot[105:0], quotient_bit};
                    vdiv_count <= vdiv_count - 8'd1;
                    if (vdiv_count == 8'd1)
                        state <= S_V64_DIV_FIN;
                end
                S_V64_DIV_FIN: begin
                    logic [63:0] result;
                    v64_div_pack_task(
                        vdiv_sign, vdiv_exp, vdiv_quot, vdiv_rem, result
                    );
                    vst_wr(vsp - 12'd2, result);
                    vsp <= vsp - 12'd1;
                    ip <= ip + 16'd1;
                    code_raddr <= 15'(ops_base + ip + 16'd1);
                    state <= S_FETCH_WAIT;
                end
                S_V64_MOD: begin
                    logic [53:0] shifted_rem;
                    logic [52:0] next_rem;
                    shifted_rem = {vmod_rem, 1'b0};
                    next_rem = (shifted_rem >= {1'b0, vmod_den})
                             ? 53'(shifted_rem - {1'b0, vmod_den})
                             : shifted_rem[52:0];
                    vmod_rem <= next_rem;
                    vmod_count <= vmod_count - 12'd1;
                    if (vmod_count == 12'd1) begin
                        logic [63:0] result;
                        v64_mod_pack_task(
                            vmod_sign, vmod_exp, next_rem, result
                        );
                        vst_wr(vsp - 12'd2, result);
                        vsp <= vsp - 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end
                end
                S_DONE: begin
                    running <= 1'b0;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
            // Capacity and stale-handle failures are architectural errors.
            // Stop once, retain a compact fault code, and never hide them by
            // resetting a stack or wrapping an allocation pointer.
            if (!machine_fault &&
                (dbg_heap_ovf != 0 || dbg_to_ovf != 0 ||
                 dbg_json_ovf != 0 || dbg_path_ovf != 0 ||
                 dbg_str_ovf != 0 || dbg_stack_ovf != 0 ||
                 dbg_call_ovf != 0 || dbg_tmr_mis != 0)) begin
                machine_fault <= 1'b1;
                if (dbg_heap_ovf != 0) fault_code <= 8'd1;
                else if (dbg_to_ovf != 0) fault_code <= 8'd2;
                else if (dbg_json_ovf != 0) fault_code <= 8'd3;
                else if (dbg_path_ovf != 0) fault_code <= 8'd4;
                else if (dbg_str_ovf != 0) fault_code <= 8'd5;
                else if (dbg_stack_ovf != 0) fault_code <= 8'd6;
                else if (dbg_call_ovf != 0) fault_code <= 8'd7;
                else fault_code <= 8'd8;
                running <= 1'b0;
                state <= S_DONE;
            end
        end
    end
endmodule
`undef VST_AT
`undef VST_REL
