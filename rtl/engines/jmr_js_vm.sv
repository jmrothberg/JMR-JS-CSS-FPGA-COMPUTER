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
    // Stable Value64 heaps. Object and future function handles share the
    // 8192-slot object index space; kind 1 is object and kind 2 is reserved
    // for a function slot. Generations never use zero.
    logic [1:0] vobj_alloc [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [11:0] vobj_gen [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [5:0] vobj_len [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    // NEW_OBJ stores the interned class name so CALL_METH can find the
    // class-table method (PYTHON _value_object_classes). 16'hFFFF = none.
    logic [15:0] vobj_cls [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [15:0] vobj_key [0:MAX_OBJ-1][0:OBJ_SLOTS-1] /*verilator public_flat_rd*/;
    logic [63:0] vobj_val [0:MAX_OBJ-1][0:OBJ_SLOTS-1] /*verilator public_flat_rd*/;
    logic [11:0] vfn_gen [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [15:0] vfn_entry [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [5:0] vfn_nparam [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [63:0] vfn_env [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [63:0] vfn_bound_this [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [2:0] vfn_flags [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic varr_valid [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [11:0] varr_gen [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [7:0] varr_len [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [63:0] varr_val [0:MAX_ARR-1][0:ARR_CAP-1] /*verilator public_flat_rd*/;
    logic vobj_mark [0:MAX_OBJ-1];
    logic varr_mark [0:MAX_ARR-1];
    logic venv_valid [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [11:0] venv_gen [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [63:0] venv_parent [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [4:0] venv_len [0:ENV_DEPTH-1] /*verilator public_flat_rd*/;
    logic [8:0] venv_key [0:ENV_DEPTH-1][0:ENV_SLOTS-1] /*verilator public_flat_rd*/;
    logic [63:0] venv_val [0:ENV_DEPTH-1][0:ENV_SLOTS-1] /*verilator public_flat_rd*/;
    logic [63:0] vthis /*verilator public_flat_rd*/;
    logic [63:0] venv /*verilator public_flat_rd*/;
    logic [15:0] vframe_return_ip [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [11:0] vframe_base_sp [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_this [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_env [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_fn [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_ctor [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vgc_queue [0:MAX_OBJ+MAX_ARR+ENV_DEPTH-1];
    logic [13:0] vgc_qr, vgc_qw, vgc_clear_i;
    logic [12:0] vgc_obj_i;
    logic [11:0] vgc_arr_i;
    logic [7:0] vgc_slot_i;
    logic [63:0] vgc_cur;
    logic [11:0] vgc_root_i;
    logic [13:0] valloc_i;
    logic [13:0] vobj_next, varr_next;
    logic [5:0] venv_next;
    logic [1:0] valloc_kind;
    logic valloc_retried, vgc_halt_after;
    logic venv_mark [0:ENV_DEPTH-1];
    logic [5:0] vgc_env_i;
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
    logic [11:0] vnat_base;
    logic [18:0] vdraw_i;
    logic [9:0] vdraw_x, vdraw_y, vdraw_w, vdraw_h;
    logic [7:0] vdraw_color;
    // NEW: tagged stack/vars for HTML heap (0=int 1=obj 2=arr 3=str 4=fn 5=undef 6=elem)
    logic [2:0]  stack_tag [0:STACK_DEPTH-1];
    logic [2:0]  var_tag   [0:MAX_VARS-1] /*verilator public_flat_rd*/;
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
    logic [15:0] obj_key  [0:MAX_OBJ-1][0:OBJ_SLOTS-1] /*verilator public_flat_rd*/;
    logic [31:0] obj_val  [0:MAX_OBJ-1][0:OBJ_SLOTS-1] /*verilator public_flat_rd*/;
    logic [2:0]  obj_tag  [0:MAX_OBJ-1][0:OBJ_SLOTS-1] /*verilator public_flat_rd*/;
    logic [15:0] obj_cls  [0:MAX_OBJ-1] /*verilator public_flat_rd*/;
    logic [7:0]  arr_len  [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic [31:0] arr_val  [0:MAX_ARR-1][0:ARR_CAP-1] /*verilator public_flat_rd*/;
    logic [2:0]  arr_tag  [0:MAX_ARR-1][0:ARR_CAP-1] /*verilator public_flat_rd*/;
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
    logic [31:0] lfsr;
    logic [15:0] id_fillrect, id_length, id_push, id_splice, id_foreach;
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
    // Date.now / performance.now GET_PROP allocates a native-35 function
    // (PYTHON entry=-35). CALL_VAL sees vfn_entry 16'hfffa.
    logic        valloc_now_fn;
    logic        valloc_regex;
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
        S_V64_JSON, S_V64_JSON_PARSE
    } st_t;
    st_t state /*verilator public_flat_rd*/, ret_state;

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
                kind == 4'd5 && index < MAX_OBJ &&
                vobj_alloc[index[12:0]] == 2'd1 &&
                vobj_gen[index[12:0]] == generation &&
                !vobj_mark[index[12:0]]) begin
                vobj_mark[index[12:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd7 && index < MAX_OBJ &&
                         vobj_alloc[index[12:0]] == 2'd2 &&
                         vfn_gen[index[12:0]] == generation &&
                         !vobj_mark[index[12:0]]) begin
                vobj_mark[index[12:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd6 && index < MAX_ARR &&
                         varr_valid[index[11:0]] &&
                         varr_gen[index[11:0]] == generation &&
                         !varr_mark[index[11:0]]) begin
                varr_mark[index[11:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end else if (word[63:48] == 16'h7ff9 &&
                         kind == 4'd9 && index < ENV_DEPTH &&
                         venv_valid[index[4:0]] &&
                         venv_gen[index[4:0]] == generation &&
                         !venv_mark[index[4:0]]) begin
                venv_mark[index[4:0]] <= 1'b1;
                vgc_queue[vgc_qw] <= word;
                vgc_qw <= vgc_qw + 14'd1;
            end
        end
    endtask

    task automatic v64_env_lookup_task(
        input logic [8:0] slot,
        output logic found,
        output logic [63:0] value,
        output logic [4:0] env_index,
        output logic handle_error
    );
        logic [63:0] cursor;
        logic active;
        begin
            cursor = venv;
            found = 1'b0;
            value = V64_UNDEFINED;
            env_index = 5'd0;
            handle_error = 1'b0;
            active = 1'b1;
            for (int depth = 0; depth < ENV_DEPTH; depth++) begin
                if (active && cursor[63:48] == 16'h7ff9 &&
                    cursor[47:44] == 4'd9) begin
                    if (cursor[31:0] >= ENV_DEPTH ||
                        !venv_valid[cursor[4:0]] ||
                        venv_gen[cursor[4:0]] != cursor[43:32]) begin
                        handle_error = 1'b1;
                        active = 1'b0;
                    end else begin
                        for (int k = 0; k < ENV_SLOTS; k++)
                            if (!found && k < venv_len[cursor[4:0]] &&
                                venv_key[cursor[4:0]][k] == slot) begin
                                found = 1'b1;
                                value = venv_val[cursor[4:0]][k];
                                env_index = cursor[4:0];
                                active = 1'b0;
                            end
                        if (active)
                            cursor = venv_parent[cursor[4:0]];
                    end
                end else begin
                    active = 1'b0;
                end
            end
        end
    endtask

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
        // Fn slot3 is the receiver captured by an arrow or a materialized
        // class method. Regular callbacks deliberately enter with no `this`.
        if (obj_n[fo] > 6'd3 && obj_tag[fo][3] == 3'd1) begin
            this_obj <= obj_val[fo][3][15:0];
            if (this_ok) begin
                vars[var_this] <= obj_val[fo][3];
                var_tag[var_this] <= 3'd1;
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
    // Jumping env_sp to `saved` used to free only the TOP frame, so a nested
    // forEach/finder return leaked middle oids AND could push the same oid
    // twice (PACMAN ENVSTAT free=2296,2295,2296). Nursery oids on the free
    // list sit ABOVE n_obj_keep — the bump allocator then overwrites that
    // env as a regular object in the same frame, so forEach LOAD f misses
    // and item.times stays 0 (stale vars[]).
    task automatic release_env_to(input logic [5:0] saved);
        logic [5:0] nn;
        logic dup;
        logic [15:0] oid;
        nn = env_free_n;
        for (int i = 0; i < ENV_DEPTH; i++) begin
            if (i >= 32'(saved) && i < 32'(env_sp) && env_sp != 6'd0 &&
                !env_cap[i[5:0]]) begin
                oid = env_oid[i[5:0]];
                dup = 1'b0;
                for (int j = 0; j < ENV_DEPTH; j++)
                    if (j < 32'(nn) && env_free[j] == oid) dup = 1'b1;
                if (i == 32'(env_sp) - 1 && n_obj == (oid + 16'd1))
                    n_obj <= oid;
                else if (!dup && nn < ENV_DEPTH[5:0] &&
                         (!obj_keep_ok || oid < n_obj_keep)) begin
                    env_free[nn] <= oid;
                    nn = nn + 6'd1;
                end
            end
        end
        env_free_n <= nn;
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
            did_swap <= 1'b0; present_pend <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0;
            fb_dump_addr <= '0; fb_dump_sel <= 1'b0;
            sp <= '0; ip <= '0;
            vsp <= '0; vcsp <= '0; vconst_lo <= '0;
            vdiv_num <= '0; vdiv_quot <= '0; vdiv_rem <= '0;
            vdiv_den <= '0; vdiv_count <= '0; vdiv_exp <= '0;
            vdiv_sign <= 1'b0;
            vmod_rem <= '0; vmod_den <= '0; vmod_count <= '0;
            vmod_exp <= '0; vmod_sign <= 1'b0;
            vgc_qr <= '0; vgc_qw <= '0; vgc_clear_i <= '0;
            vgc_obj_i <= '0; vgc_arr_i <= '0; vgc_slot_i <= '0;
            vgc_cur <= '0; vgc_root_i <= '0; valloc_i <= '0;
            vobj_next <= '0; varr_next <= '0;
            venv_next <= '0; valloc_kind <= 2'd0;
            valloc_retried <= 1'b0;
            vgc_halt_after <= 1'b0;
            vgc_env_i <= '0; vgc_root_phase <= '0;
            vcall_value <= 1'b0; vcall_entry <= '0; vcall_argc <= '0;
            vcall_set_this <= 1'b0;
            vcall_this <= V64_UNDEFINED;
            vcall_ctor_val <= V64_UNDEFINED;
            vthis <= V64_UNDEFINED; venv <= V64_UNDEFINED;
            vraf_n <= '0; vraf_snap_n <= '0; vraf_i <= '0;
            vtimer_n <= '0; vframe_no <= '0; vtimer_seq <= 32'd1;
            vrng <= 32'h6d2b79f5; vconsole_n <= '0;
            vtimer_pick <= '0; vcallback_raf <= 1'b0;
            vcallback_timer <= 1'b0; vgc_wait_after <= 1'b0;
            vnat_base <= '0; vdraw_i <= '0;
            vnat_dom <= 3'd0; vnat_style <= V64_UNDEFINED;
            vkev_event <= V64_UNDEFINED; vlistener_n <= 5'd0;
            vkey_li <= 5'd0;
            v64_frame_armed <= 1'b0;
            vcallback_key <= 1'b0; vcallback_fe <= 1'b0;
            vfe_arr <= V64_UNDEFINED; vfe_fn <= V64_UNDEFINED;
            vfe_i <= 8'd0; vfe_ret <= 16'd0; vfe_base <= '0; vfe_sp <= 4'd0;
            valloc_now_fn <= 1'b0;
            valloc_regex <= 1'b0;
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
                    vsp <= '0; vcsp <= '0;
                    if (code_rdata[19]) begin
                        vobj_next <= 14'd0;
                        varr_next <= 14'd0;
                        venv_next <= 6'd0;
                        vthis <= V64_UNDEFINED;
                        venv <= V64_UNDEFINED;
                        vcall_set_this <= 1'b0;
                        vcall_this <= V64_UNDEFINED;
                        vcall_ctor_val <= V64_UNDEFINED;
                        vraf_n <= 4'd0;
                        vtimer_n <= 7'd0;
                        vframe_no <= 32'd0;
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
                            vobj_len[i] <= 6'd0;
                            vobj_mark[i] <= 1'b0;
                            vobj_builtin[i] <= 4'd0;
                        end
                        for (int i = 0; i < MAX_ARR; i++) begin
                            varr_valid[i] <= 1'b0;
                            varr_gen[i] <= 12'd1;
                            varr_len[i] <= 8'd0;
                            varr_mark[i] <= 1'b0;
                        end
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
                    fill_style_i <= 8'd1; lfsr <= 32'hACE1; this_obj <= 16'hFFFF;
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
                    for (int i = 0; i < 1024; i++) name_has[i] <= 1'b0;
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
                                // NEW: u8 length byte follows each hash (concat fold)
                                trail_ph <= 5'd4;
                            end
                            5'd4: begin
                                name_len_tbl[name_idx[9:0]] <= tb;
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
                                if (nb_wp < 16'(NAME_CAP)) name_mem[nb_wp[14:0]] <= tb;
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
                    // NEW: one element per cycle. Both-array elements copy the
                    // CHILD's contents into the existing dst child (keeps its
                    // old-space id — JS identity is approximated the same way
                    // the outer in-place copy already does). Anything else is
                    // a plain value/ref copy, same as the old single-cycle
                    // loop. Depth stops at 1: grand-children still ref-copy.
                    if (dc_i >= ARR_CAP[7:0]) begin
                        state <= S_EXEC;
                    end else begin
                        if (dc_i < arr_len[dc_src] &&
                            arr_tag[dc_src][dc_i[6:0]] == 3'd2 &&
                            arr_tag[dc_dst][dc_i[6:0]] == 3'd2 &&
                            arr_val[dc_src][dc_i[6:0]][11:0] !=
                            arr_val[dc_dst][dc_i[6:0]][11:0]) begin
                            begin
                                logic [11:0] cs, cd;
                                cs = arr_val[dc_src][dc_i[6:0]][11:0];
                                cd = arr_val[dc_dst][dc_i[6:0]][11:0];
                                arr_len[cd] <= arr_len[cs];
                                for (int k = 0; k < ARR_CAP; k++) begin
                                    arr_val[cd][k] <= arr_val[cs][k];
                                    arr_tag[cd][k] <= arr_tag[cs][k];
                                end
                            end
                        end else begin
                            arr_val[dc_dst][dc_i[6:0]] <= arr_val[dc_src][dc_i[6:0]];
                            arr_tag[dc_dst][dc_i[6:0]] <= arr_tag[dc_src][dc_i[6:0]];
                        end
                        dc_i <= dc_i + 8'd1;
                    end
                end

                S_EXEC: begin
                    if (ip >= n_ops) begin
                        // One implicit present per FRAME, not per pass: mark the
                        // pass end and let S_WAIT_FRAME swap once at frame_tick
                        // after every callback of this frame (rAF + timers +
                        // key listeners) has run — same order the FM presents.
                        present_pend <= 1'b1;
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
                                    cc_second <= 1'b0; cc_st <= 2'd0;
                                    cc_h <= 16'd0; cc_len <= 8'd0; cc_d <= 4'd0;
                                    // NEW: rebuild the characters too (txt_buf)
                                    cc_bok <= 1'b1; txt_bn <= 7'd0;
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
                                // NEW: 1-cycle /2 (arithmetic shift). `cell/2` and
                                // `width/2` were 48 restoring steps each; a frame of
                                // those loops paid millions of clocks. Shift is
                                // JS-honest: even/even stays int, odd/2 is fx (5/2).
                                end else if (stack_tag[sp - 8'd1] != 3'd7 &&
                                             (stack[sp - 8'd1] == 32'sd2 ||
                                              stack[sp - 8'd1] == -32'sd2) &&
                                             stack[sp - 8'd2] != 32'sh80000000) begin
                                    if (stack_tag[sp - 8'd2] == 3'd7) begin
                                        stack[sp - 8'd2] <= stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] >>> 1)
                                            : 32'(stack[sp - 8'd2] >>> 1);
                                        stack_tag[sp - 8'd2] <= 3'd7;
                                    end else if (!stack[sp - 8'd2][0]) begin
                                        stack[sp - 8'd2] <= stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] >>> 1)
                                            : 32'(stack[sp - 8'd2] >>> 1);
                                        stack_tag[sp - 8'd2] <= 3'd0;
                                    end else begin
                                        stack[sp - 8'd2] <= stack[sp - 8'd1][31]
                                            ? -32'(stack[sp - 8'd2] <<< 15)
                                            : 32'(stack[sp - 8'd2] <<< 15);
                                        stack_tag[sp - 8'd2] <= 3'd7;
                                    end
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
                                    dbg_div_n <= dbg_div_n + 16'd1;
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
                                    // NEW: OOB (idx<0 or idx>=len) is undefined.
                                    // 7-bit wrap of -1 read slot 127, so map.get(-1)
                                    // returned leftover instead of -1 (falsy 0 vs
                                    // JS truthy -1) and left-edge wall codes broke.
                                    begin
                                        logic signed [31:0] aidx32;
                                        logic [11:0] aid;
                                        aid = stack[sp - 8'd2][11:0];
                                        aidx32 = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                        if (aidx32 < 0 || aidx32 >= 32'(arr_len[aid])) begin
                                            stack[sp - 8'd2] <= 32'sd0;
                                            stack_tag[sp - 8'd2] <= 3'd5;
                                        end else begin
                                            stack[sp - 8'd2] <= arr_val[aid][7'(aidx32)];
                                            stack_tag[sp - 8'd2] <= arr_tag[aid][7'(aidx32)];
                                        end
                                    end
                                    sp <= sp - 8'd1;
                                    next_op();
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
                                        sp <= sp - 8'd1;
                                        next_op();
                                    end
                                // NEW: "str"[i] — one char. name_mem is BRAM, so the
                                // byte lands next cycle in S_STRIDX. This is what
                                // string-row sprites need (row[col] === "1").
                                end else if (stack_tag[sp - 8'd2] == 3'd3 && names_ok &&
                                             (stack_tag[sp - 8'd1] == 3'd0 ||
                                              stack_tag[sp - 8'd1] == 3'd7)) begin
                                    begin
                                        logic signed [31:0] ci;
                                        ci = fxi(stack[sp - 8'd1], stack_tag[sp - 8'd1]);
                                        if (ci >= 0 && ci < 32'(name_len_tbl[stack[sp - 8'd2][9:0]])) begin
                                            if (str_pf_ok && str_pf_id == stack[sp - 8'd2][15:0] &&
                                                str_pf_ci == ci &&
                                                name_rdaddr == name_off[stack[sp - 8'd2][9:0]] + 16'(ci)) begin
                                                // NEW: sequential hit — name_rdata is this char
                                                if (char_ok[name_rdata]) begin
                                                    stack[sp - 8'd2] <= {16'd0, char_id[name_rdata]};
                                                    stack_tag[sp - 8'd2] <= 3'd3;
                                                end else begin
                                                    stack[sp - 8'd2] <= 32'sd0;
                                                    stack_tag[sp - 8'd2] <= 3'd5;
                                                end
                                                sp <= sp - 8'd1;
                                                name_rdaddr <= name_off[stack[sp - 8'd2][9:0]] + 16'(ci) + 16'd1;
                                                str_pf_id <= stack[sp - 8'd2][15:0];
                                                str_pf_ci <= ci + 32'sd1;
                                                str_pf_ok <= 1'b1;
                                                next_op();
                                            end else begin
                                                name_rdaddr <= name_off[stack[sp - 8'd2][9:0]] + 16'(ci);
                                                str_res <= 11'(sp - 8'd2);
                                                str_pf_id <= stack[sp - 8'd2][15:0];
                                                str_pf_ci <= ci;
                                                str_pf_ok <= 1'b0;
                                                sp <= sp - 8'd1;
                                                ip <= ip + 16'd1;
                                                state <= S_STRIDX;
                                            end
                                        end else begin
                                            // out of range is undefined, same as PYTHON
                                            stack[sp - 8'd2] <= 32'sd0;
                                            stack_tag[sp - 8'd2] <= 3'd5;
                                            sp <= sp - 8'd1;
                                            next_op();
                                        end
                                    end
                                end else begin
                                    stack[sp - 8'd2] <= 32'sd0;
                                    stack_tag[sp - 8'd2] <= 3'd5;
                                    sp <= sp - 8'd1;
                                    next_op();
                                end
                            end
                            OP_ARR_SET: begin
                                // [arr, idx, val] — fx index floors first (LHS needs a plain var)
                                begin
                                    logic signed [31:0] aidx32;
                                    logic [6:0] aidx;
                                    logic [11:0] aid;
                                    aidx32 = fxi(stack[sp - 8'd2], stack_tag[sp - 8'd2]);
                                    aidx = 7'(aidx32);
                                    aid = stack[sp - 8'd3][11:0];
                                    if (stack_tag[sp - 8'd3] == 3'd2 &&
                                        aidx32 >= 0 && aidx32 < ARR_CAP) begin
                                        arr_val[aid][aidx] <= stack[sp - 8'd1];
                                        arr_tag[aid][aidx] <= stack_tag[sp - 8'd1];
                                        // NEW: a[i]= grows length (JS). Without this,
                                        // [] then a[x]=1 left len=0 so stringify/finder
                                        // saw empty rows.
                                        if (aidx32 >= 32'(arr_len[aid]))
                                            arr_len[aid] <= 8'(aidx32 + 32'sd1);
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
                                // NEW: "str".length — the interned length table
                                // already had this; only arrays were answered, so
                                // `col < row.length` was col < undefined and every
                                // character loop body was skipped.
                                end else if (stack_tag[sp - 8'd1] == 3'd3 &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    stack[sp - 8'd1] <= {24'd0, name_len_tbl[stack[sp - 8'd1][9:0]]};
                                    stack_tag[sp - 8'd1] <= 3'd0;
                                // NEW: dynamic string (replace / JSON result) length
                                end else if (stack_tag[sp - 8'd1] == 3'd1 &&
                                    obj_cls[stack[sp - 8'd1][12:0]] == CLS_DYNSTR &&
                                    (code_rdata[23:8] == id_length || code_rdata[23:8] == 16'd66)) begin
                                    stack[sp - 8'd1] <= obj_val[stack[sp - 8'd1][12:0]][1];
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
                                                    foundp = 1'b1;
                                                end
                                            end
                                        end
                                        // NEW: this.method as a VALUE (DONKEY
                                        // addEventListener(this.startSelect)).
                                        // CALL_METH already finds class methods;
                                        // GET_PROP did not — listeners were undefined.
                                        if (!foundp && code_rdata[23:8] != id_proto) begin
                                            logic [15:0] mip;
                                            mip = 16'hFFFF;
                                            for (int c = 0; c < MAX_CLS; c++) begin
                                                if (c < n_cls && cls_name[c] == obj_cls[gi]) begin
                                                    for (int m = 0; m < MAX_CMETH; m++) begin
                                                        // bit15 = getter; those stay CALL_METH
                                                        if (m < cls_nmeth[c]
                                                            && cls_mname[c][m][14:0]
                                                               == code_rdata[22:8]
                                                            && cls_mname[c][m][15] == 1'b0)
                                                            mip = cls_mip[c][m];
                                                    end
                                                end
                                            end
                                            if (mip != 16'hFFFF) begin
                                                obj_cls[n_obj[12:0]] <= CLS_FN;
                                                // A method read as a value is a stable bound Fn.
                                                obj_n[n_obj[12:0]] <= 6'd4;
                                                obj_key[n_obj[12:0]][0] <= 16'd0;
                                                obj_val[n_obj[12:0]][0] <= {16'd0, mip};
                                                obj_tag[n_obj[12:0]][0] <= 3'd0;
                                                obj_key[n_obj[12:0]][1] <= 16'd1;
                                                obj_val[n_obj[12:0]][1] <= 32'd1;
                                                obj_tag[n_obj[12:0]][1] <= 3'd0;
                                                obj_key[n_obj[12:0]][2] <= 16'd2;
                                                obj_val[n_obj[12:0]][2] <= 32'd0;
                                                obj_tag[n_obj[12:0]][2] <= 3'd0;
                                                obj_key[n_obj[12:0]][3] <= 16'd3;
                                                obj_val[n_obj[12:0]][3] <= {16'd0, gi};
                                                obj_tag[n_obj[12:0]][3] <= 3'd1;
                                                stack[sp - 8'd1] <= {16'd0, n_obj};
                                                stack_tag[sp - 8'd1] <= 3'd4;
                                                if (obj_n[gi] < OBJ_SLOTS[5:0]) begin
                                                    obj_key[gi][obj_n[gi]] <= code_rdata[23:8];
                                                    obj_val[gi][obj_n[gi]] <= {16'd0, n_obj};
                                                    obj_tag[gi][obj_n[gi]] <= 3'd4;
                                                    obj_n[gi] <= obj_n[gi] + 6'd1;
                                                end
                                                if (obj_keep_ok && n_obj >= n_obj_keep)
                                                    n_obj_keep <= n_obj + 16'd1;
                                                n_obj <= (n_obj >= 16'(MAX_OBJ - 1))
                                                         ? n_obj : (n_obj + 16'd1);
                                                foundp = 1'b1;
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
                                        logic [12:0] oi, src, dst;
                                        logic found;
                                        logic [4:0] found_s;
                                        oi = stack[sp - 8'd2][12:0];
                                        found = 1'b0;
                                        found_s = 5'd0;
                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                            if (s < obj_n[oi] && obj_key[oi][s] == code_rdata[23:8]) begin
                                                found = 1'b1;
                                                found_s = 5'(s);
                                            end
                                        end
                                        // NEW: in-place copy when overwriting an
                                        // existing object (item.coord = {x,y} every
                                        // frame). Replacing the pointer made
                                        // player.control a nursery oid that the
                                        // frame rewind deleted — PACMAN reverse
                                        // never applied. First store of a new
                                        // object onto old-space still commits keep.
                                        if (found && obj_tag[oi][found_s] == 3'd1
                                            && stack_tag[sp - 8'd1] == 3'd1) begin
                                            dst = obj_val[oi][found_s][12:0];
                                            src = stack[sp - 8'd1][12:0];
                                            obj_n[dst] <= obj_n[src];
                                            obj_cls[dst] <= obj_cls[src];
                                            for (int k = 0; k < OBJ_SLOTS; k++) begin
                                                obj_key[dst][k] <= obj_key[src][k];
                                                obj_val[dst][k] <= obj_val[src][k];
                                                obj_tag[dst][k] <= obj_tag[src][k];
                                            end
                                        // NEW: same in place for array-over-array
                                        // (this.path = finder(), this.cells =
                                        // rebuild()). Without this the slot took a
                                        // nursery arr oid every frame, and deep keep
                                        // below would otherwise have to grow the
                                        // watermark on each store to save it.
                                        end else if (found && obj_tag[oi][found_s] == 3'd2
                                                     && stack_tag[sp - 8'd1] == 3'd2) begin
                                            dst = obj_val[oi][found_s][11:0];
                                            src = stack[sp - 8'd1][11:0];
                                            arr_len[dst[11:0]] <= arr_len[src[11:0]];
                                            // NEW: element copy moved to S_ARR_DCOPY
                                            // (runs before the next op). Nested rows
                                            // (both sides arrays) copy CONTENTS into
                                            // the existing dst row so old-space keeps
                                            // owning them — a ref copy left nursery
                                            // row ids that the frame rewind recycled
                                            // (PACMAN map.data re-parse at level
                                            // start → maze read 4-wide draw temps).
                                            if (dst[11:0] != src[11:0]) begin
                                                dc_dst <= dst[11:0];
                                                dc_src <= src[11:0];
                                                dc_i <= 8'd0;
                                                dc_arm <= 1'b1;
                                            end
                                        end else if (found) begin
                                            obj_val[oi][found_s] <= stack[sp - 8'd1];
                                            obj_tag[oi][found_s] <= stack_tag[sp - 8'd1];
                                            // NEW: deep — children were allocated
                                            // after the stored value (ctor fields)
                                            if ({3'd0, oi} < n_obj_keep)
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
                                        end else if (obj_n[oi] < OBJ_SLOTS[5:0]) begin
                                            obj_key[oi][obj_n[oi]] <= code_rdata[23:8];
                                            obj_val[oi][obj_n[oi]] <= stack[sp - 8'd1];
                                            obj_tag[oi][obj_n[oi]] <= stack_tag[sp - 8'd1];
                                            obj_n[oi] <= obj_n[oi] + 6'd1;
                                            if ({3'd0, oi} < n_obj_keep)
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
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
                                        bump_csp();
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
                                             code_rdata[23:8] == id_textalign) begin
                                    // NEW: ctx.textAlign — FM fill_text shifts the
                                    // pen by half / all of the text width
                                    ctx_align <= (stack[sp - 8'd1][15:0] == id_center) ? 2'd1
                                               : (stack[sp - 8'd1][15:0] == id_right)  ? 2'd2
                                               : 2'd0;
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    next_op();
                                end else if (stack_tag[sp - 8'd2] == 3'd6 &&
                                             code_rdata[23:8] == id_font) begin
                                    // NEW: ctx.font = "bold 24px Foo" — walk the
                                    // bytes for the first NNpx run, exactly what
                                    // FM machine._font_scale's regex takes.
                                    stack[sp - 8'd2] <= stack[sp - 8'd1];
                                    stack_tag[sp - 8'd2] <= stack_tag[sp - 8'd1];
                                    sp <= sp - 8'd1;
                                    if (stack_tag[sp - 8'd1] == 3'd3 && names_ok &&
                                        name_has[stack[sp - 8'd1][9:0]]) begin
                                        txt_rp <= name_off[stack[sp - 8'd1][9:0]];
                                        name_rdaddr <= name_off[stack[sp - 8'd1][9:0]];
                                        fp_left <= name_len_tbl[stack[sp - 8'd1][9:0]];
                                        fpx_acc <= 8'd0;
                                        ctx_font_px <= 8'd8; // no "px" found → FM default
                                        ip <= ip + 16'd1;
                                        state <= S_FONTPX;
                                    end else begin
                                        ctx_font_px <= 8'd8;
                                        next_op();
                                    end
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
                                // NEW: heap Fn {entry, nparam, live env oid,
                                // bound this}. a1 bit7 is the ProgramImage's
                                // arrow flag; arrows capture the current receiver.
                                begin
                                    logic [12:0] fo;
                                    logic [15:0] eoid;
                                    logic bind_this;
                                    fo = n_obj[12:0];
                                    eoid = (env_sp != 0) ? env_oid[env_sp - 6'd1] : 16'd0;
                                    bind_this = code_rdata[31] && this_obj != 16'hFFFF;
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
                                    obj_key[fo][3] <= 16'd3;
                                    obj_val[fo][3] <= {16'd0, this_obj};
                                    obj_tag[fo][3] <= 3'd1;
                                    obj_n[fo] <= bind_this ? 6'd4 :
                                                 ((eoid != 16'd0) ? 6'd3 : 6'd2);
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
                                bump_csp();
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
                                        bump_csp();
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
                                            dbg_find_hit <= dbg_find_hit + 16'd1;
                                            stack[sp - 8'd1] <=
                                                arr_val[cstack_fe_arr[csp - 7'd2][11:0]]
                                                       [cstack_fe_i[csp - 7'd2][6:0]];
                                            stack_tag[sp - 8'd1] <=
                                                arr_tag[cstack_fe_arr[csp - 7'd2][11:0]]
                                                       [cstack_fe_i[csp - 7'd2][6:0]];
                                            release_env_to(cstack_env[csp - 7'd1]);
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
                                            state <= S_FETCH_WAIT;
                                        end else if (md == 16'hFFFD && truthy) begin
                                            // findIndex hit — return current index
                                            stack[sp - 8'd1] <= {24'd0, cstack_fe_i[csp - 7'd2]};
                                            stack_tag[sp - 8'd1] <= 3'd0;
                                            release_env_to(cstack_env[csp - 7'd1]);
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
                                            state <= S_FETCH_WAIT;
                                        end else begin
                                            if (cstack_isctor[csp - 7'd2] &&
                                                md != 16'hFFFF && md != 16'hFFFE && md != 16'hFFFD &&
                                                truthy) begin
                                                // filter: keep source element
                                                begin
                                                    logic [7:0] fl;
                                                    fl = arr_len[md[11:0]];
                                                    if (fl < ARR_CAP[7:0]) begin
                                                        arr_val[md[11:0]][fl[6:0]] <=
                                                            arr_val[cstack_fe_arr[csp - 7'd2][11:0]]
                                                                   [cstack_fe_i[csp - 7'd2][6:0]];
                                                        arr_tag[md[11:0]][fl[6:0]] <=
                                                            arr_tag[cstack_fe_arr[csp - 7'd2][11:0]]
                                                                   [cstack_fe_i[csp - 7'd2][6:0]];
                                                        arr_len[md[11:0]] <= fl + 8'd1;
                                                    end
                                                end
                                            end else if (md != 16'hFFFF && md != 16'hFFFE &&
                                                       md != 16'hFFFD && !cstack_isctor[csp - 7'd2] &&
                                                       sp != 0) begin
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
                                            boundary_sp(11'd1);
                                            cstack_ip[csp - 7'd1] <= 16'hFFFD;
                                            cstack_isctor[csp - 7'd1] <= 1'b0;
                                            cstack_isfe[csp - 7'd1] <= 1'b0;
                                            state <= S_KEYEV;
                                        end else if (kev_ret_ip == n_ops) begin
                                            // Hardware KEYEVT owns the input
                                            // phase; continue into this same
                                            // frame's rAF phase after listeners.
                                            frame_fire <= 1'b1;
                                            state <= S_WAIT_FRAME;
                                        end else begin
                                            ip <= kev_ret_ip;
                                            code_raddr <= 15'(ops_base + kev_ret_ip);
                                            state <= S_FETCH_WAIT;
                                        end
                                    end
                                end else begin
                                    // NEW: a callback frame returns to the frame
                                    // boundary sentinel (cstack_ip == n_ops). Latch
                                    // the RET site so a loop that stops re-arming
                                    // itself can be found (PACMAN start() fn dies
                                    // mid-frame and raf drops to 0 with no trace).
                                    if (cstack_ip[csp - 7'd1] == n_ops) dbg_cb_ip <= ip;
                                    release_env_to(cstack_env[csp - 7'd1]);
                                    csp <= csp - 7'd1;
                                    this_obj <= cstack_this[csp - 7'd1];
                                    if (this_ok) begin
                                        vars[var_this] <= (cstack_this[csp - 7'd1] == 16'hFFFF)
                                                          ? 32'd0
                                                          : {16'd0, cstack_this[csp - 7'd1]};
                                        var_tag[var_this] <= (cstack_this[csp - 7'd1] == 16'hFFFF)
                                                             ? 3'd5 : 3'd1;
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
                                        bump_csp();
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
                                            // Deep: grids.push(new Grid()) must also
                                            // keep the fields the ctor built after it.
                                            if (arr_keep_ok && {4'd0, ai} < n_arr_keep)
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
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
                                            code_rdata[23:8] == id_find ||
                                            (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex) ||
                                            (id_filter != 16'hFFFF &&
                                             code_rdata[23:8] == id_filter))) begin
                                    // arr.forEach/map/find/findIndex/filter
                                    cstack_ip[csp] <= ip + 16'd1;
                                    cstack_this[csp] <= this_obj;
                                    cstack_isctor[csp] <= (id_filter != 16'hFFFF &&
                                                           code_rdata[23:8] == id_filter);
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
                                    end else if (code_rdata[23:8] == id_filter) begin
                                        arr_len[n_arr[11:0]] <= 8'd0;
                                        cstack_map_arr[csp] <= n_arr;
                                        if (n_arr >= 16'(MAX_ARR - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                        n_arr <= (n_arr >= 16'(MAX_ARR - 1)) ? n_arr : (n_arr + 16'd1);
                                    end else if (id_find != 16'hFFFF &&
                                                code_rdata[23:8] == id_find)
                                        cstack_map_arr[csp] <= 16'hFFFE; // find sentinel
                                    else if (id_findindex != 16'hFFFF &&
                                             code_rdata[23:8] == id_findindex)
                                        cstack_map_arr[csp] <= 16'hFFFD; // findIndex sentinel
                                    else
                                        cstack_map_arr[csp] <= 16'hFFFF;
                                    cstack_env[csp] <= env_sp;
                                    bump_csp();
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
                                                commit_deep_keep(stack_tag[sp - 8'd1]);
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
                                        dbg_splice_n <= dbg_splice_n + 16'd1;
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
                                        if (rt == 3'd1) begin
                                            json_src <= obj_val[recv[12:0]][0][13:0];
                                            json_srclen <= obj_val[recv[12:0]][1][13:0];
                                            json_rp <= obj_val[recv[12:0]][0][13:0];
                                            json_dst <= obj_val[recv[12:0]][0][13:0]
                                                + obj_val[recv[12:0]][1][13:0];
                                            json_wp <= obj_val[recv[12:0]][0][13:0]
                                                + obj_val[recv[12:0]][1][13:0];
                                            state <= S_REPL;
                                        end else if (name_len_tbl[recv[9:0]] == 8'd1 &&
                                                     !name_has[recv[9:0]]) begin
                                            // interned 1-char without NAMB: hash == byte
                                            json_mem[0] <= name_hash_tbl[recv[9:0]][7:0];
                                            json_src <= 14'd0;
                                            json_srclen <= 14'd1;
                                            json_rp <= 14'd0;
                                            json_dst <= 14'd1;
                                            json_wp <= 14'd1;
                                            state <= S_REPL;
                                        end else begin
                                            // interned longer: copy name_mem → json_mem
                                            json_src <= 14'd0;
                                            json_srclen <= {6'd0, name_len_tbl[recv[9:0]]};
                                            json_rp <= 14'd0;
                                            name_rdaddr <= name_off[recv[9:0]];
                                            json_wp <= 14'd0;
                                            namcpy_repl <= 1'b1;
                                            namcpy_armed <= 1'b0;
                                            state <= S_NAMCPY;
                                        end
                                        repl_did <= 1'b0;
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
                                        boundary_sp(11'd1);
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
                                        bump_csp();
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
                                    // NEW: real glyphs. args are (text, x, y[, maxW])
                                    // counted from the first one, so a 4-arg call
                                    // still finds x/y. The text value is latched
                                    // here because sp moves this cycle.
                                    begin
                                        logic [10:0] a0;
                                        a0 = sp - 11'(code_rdata[31:24]); // text slot
                                        color <= fill_style_i;
                                        txt_val <= stack[a0];
                                        txt_vt <= stack_tag[a0];
                                        txt_ph <= 4'd0;
                                        sp <= sp - 8'(code_rdata[31:24]) - 8'd1;
                                        ip <= ip + 16'd1;
                                        if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                                            // scaled ctx (DONKEY world→glass): the pen
                                            // goes through the shared _xf multiplier
                                            xf_x <= stfx(a0 + 11'd1);
                                            xf_y <= stfx(a0 + 11'd2);
                                            xf_w <= 32'sd0; xf_h <= 32'sd0;
                                            xf_dst <= 2'd2;
                                            state <= S_XF_MUL;
                                        end else begin
                                            txt_px <= 16'(sti(a0 + 11'd1) + ctx_tx);
                                            txt_py <= 16'(sti(a0 + 11'd2) + ctx_ty);
                                            state <= S_TXT_LD;
                                        end
                                    end
                                end else if (code_rdata[23:8] == id_measuretext) begin
                                    // NEW: {width} so games can right-align text.
                                    // Same geometry FM _nat_measure_text reports:
                                    // len x 8 x scale (scale folds ctx_sx below).
                                    //
                                    // ONE reserved metrics object, allocated on
                                    // first use and kept for good. A fresh object
                                    // per call is what a browser does, but here any
                                    // store into old space raises the keep
                                    // watermark to the bump pointer
                                    // (commit_deep_keep), so one new object per
                                    // frame walked that watermark up until the
                                    // array ring wrapped and recycled the oldest
                                    // live data — PACMAN's maze rows read back 0
                                    // and half the walls stopped being drawn.
                                    begin
                                        logic [7:0] ac;
                                        logic [15:0] tl;
                                        logic [15:0] px_;
                                        logic [15:0] moid;
                                        ac = code_rdata[31:24];
                                        tl = 16'd0;
                                        if (stack_tag[sp - ac] == 3'd3)
                                            tl = {8'd0, name_len_tbl[stack[sp - ac][9:0]]};
                                        else if (stack_tag[sp - ac] == 3'd1 &&
                                                 obj_cls[stack[sp - ac][12:0]] == CLS_DYNSTR)
                                            tl = {2'd0, obj_val[stack[sp - ac][12:0]][1][13:0]};
                                        // px per char = font px (x ctx scale) rounded
                                        // to the 8-px glyph grid, same as fill_text
                                        px_ = 16'((48'(ctx_font_px) * 48'(ctx_sx)
                                                  + 48'sd262144) >>> 19);
                                        if (px_ == 16'd0) px_ = 16'd1;
                                        moid = (metrics_oid == 16'hFFFF) ? n_obj : metrics_oid;
                                        obj_cls[moid[12:0]] <= 16'd0; // plain object
                                        obj_n[moid[12:0]] <= 6'd1;
                                        obj_key[moid[12:0]][0] <= id_width;
                                        obj_val[moid[12:0]][0] <= 32'(tl) * 32'd8 * 32'(px_);
                                        obj_tag[moid[12:0]][0] <= 3'd0;
                                        if (metrics_oid == 16'hFFFF) begin
                                            if (n_obj >= 16'(MAX_OBJ - 1))
                                                dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                                            else begin
                                                metrics_oid <= n_obj;
                                                n_obj <= n_obj + 16'd1;
                                                // VM-owned: a rewind must never
                                                // recycle the slot metrics_oid names
                                                if ((n_obj + 16'd1) > n_obj_keep)
                                                    n_obj_keep <= n_obj + 16'd1;
                                            end
                                        end
                                        stack[sp - ac - 8'd1] <= {16'd0, moid};
                                        stack_tag[sp - ac - 8'd1] <= 3'd1;
                                        sp <= sp - ac;
                                        next_op();
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
                                        // 32-bit product: 10-bit ww*hh of 640×480
                                        // wrapped to 0 and skipped the copy (or a
                                        // 19-bit self-mul truncated the count).
                                        imgd_n <= (32'(ww) * 32'(hh) > 32'(FB_PIXELS))
                                            ? 19'(FB_PIXELS) : 19'(32'(ww) * 32'(hh));
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
                                            bump_csp();
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
                                                    bump_csp();
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
                                // NEW: rAF fn must survive the frame nursery
                                // rewind or PACMAN start() loop dies (raf=0)
                                commit_obj_keep(stack_tag[sp - nat_argc[7:0]],
                                                stack[sp - nat_argc[7:0]][15:0]);
                            end
                            sp <= sp - nat_argc[7:0];
                            stack[sp - nat_argc[7:0]] <= 32'sd1;
                            stack_tag[sp - nat_argc[7:0]] <= 3'd0;
                            sp <= sp - nat_argc[7:0] + 8'd1;
                            code_raddr <= 15'(ops_base + ip);
                            state <= S_FETCH_WAIT;
                        end
                        8'd28, 8'd29: begin // setTimeout / setInterval — frame delay queue
                            if (to_n < TIMER_DEPTH[6:0] && nat_argc >= 8'd1) begin
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
                                to_n <= to_n + 7'd1;
                                to_seq <= to_seq + 16'd1;
                                dbg_tmr_sched <= dbg_tmr_sched + 16'd1;
                                commit_obj_keep(stack_tag[sp - nat_argc[7:0]],
                                                stack[sp - nat_argc[7:0]][15:0]);
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
                                for (i = 0; i < TIMER_DEPTH; i++) begin
                                    if (i < to_n && to_id[i] != want) begin
                                        to_fn[j] <= to_fn[i];
                                        to_delay[j] <= to_delay[i];
                                        to_period[j] <= to_period[i];
                                        to_id[j] <= to_id[i];
                                        j = j + 1;
                                    end
                                end
                                to_n <= 7'(j);
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
                                boundary_sp(11'd1);
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
                            end else if (nat_argc >= 8'd1 &&
                                         stack_tag[sp - nat_argc[7:0]] == 3'd3) begin
                                // interned literal — copy name_mem into json_mem then parse
                                json_src <= 14'd0;
                                json_srclen <= {6'd0, name_len_tbl[stack[sp - nat_argc[7:0]][9:0]]};
                                json_rp <= 14'd0;
                                js_sp <= 6'd0;
                                js_ph[0] <= 3'd0;
                                json_pph <= 3'd0;
                                sp <= sp - nat_argc[7:0];
                                if (name_len_tbl[stack[sp - nat_argc[7:0]][9:0]] == 8'd0) begin
                                    stack[11'(sp - nat_argc[7:0])] <= 32'sd0;
                                    stack_tag[11'(sp - nat_argc[7:0])] <= 3'd5;
                                    sp <= 11'(sp - nat_argc[7:0]) + 11'd1;
                                    code_raddr <= 15'(ops_base + ip);
                                    state <= S_FETCH_WAIT;
                                end else if (name_len_tbl[stack[sp - nat_argc[7:0]][9:0]] == 8'd1 &&
                                             !name_has[stack[sp - nat_argc[7:0]][9:0]]) begin
                                    json_mem[0] <= name_hash_tbl[stack[sp - nat_argc[7:0]][9:0]][7:0];
                                    state <= S_JSON_PARSE;
                                end else begin
                                    name_rdaddr <= name_off[stack[sp - nat_argc[7:0]][9:0]];
                                    json_wp <= 14'd0;
                                    namcpy_repl <= 1'b0;
                                    namcpy_armed <= 1'b0;
                                    state <= S_NAMCPY;
                                end
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
                        8'd40: begin // typeof — JS tag string (PACMAN map hole checks)
                            begin
                                logic [2:0] tt;
                                logic [15:0] tn;
                                tt = (nat_argc >= 8'd1) ? stack_tag[sp - nat_argc[7:0]] : 3'd5;
                                tn = 16'hFFFF;
                                if (tt == 3'd5) tn = id_str_undef;
                                else if (tt == 3'd3) tn = (id_str_string != 16'hFFFF)
                                    ? id_str_string : id_str_undef;
                                else if (tt == 3'd4) tn = (id_str_function != 16'hFFFF)
                                    ? id_str_function : id_str_undef;
                                else if (tt == 3'd1 || tt == 3'd2) tn = (id_str_object != 16'hFFFF)
                                    ? id_str_object : id_str_undef;
                                else tn = (id_str_number != 16'hFFFF)
                                    ? id_str_number : 16'hFFFE;
                                sp <= (nat_argc == 0) ? sp : (sp - nat_argc[7:0]);
                                if (tn == 16'hFFFE) begin
                                    // "number" was never interned — still != 'undefined'
                                    stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 32'sd1;
                                    stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd0;
                                end else if (tn != 16'hFFFF) begin
                                    stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= {16'd0, tn};
                                    stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd3;
                                end else begin
                                    stack[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 32'sd0;
                                    stack_tag[sp - ((nat_argc == 0) ? 8'd0 : nat_argc[7:0])] <= 3'd5;
                                end
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
                        // NEW: the digits are staged as characters too, so a join
                        // result is a full string (bytes, not just a hash). Without
                        // this the alloc path below would inherit whatever the last
                        // concat left in txt_buf.
                        et = arr_tag[jn_arr][jn_i[6:0]];
                        ev = (et == 3'd7) ? ($signed(arr_val[jn_arr][jn_i[6:0]]) >>> 16)
                                          : $signed(arr_val[jn_arr][jn_i[6:0]]);
                        if (et == 3'd3 && name_len_tbl[arr_val[jn_arr][jn_i[6:0]][9:0]] == 8'd1 &&
                            name_hash_tbl[arr_val[jn_arr][jn_i[6:0]][9:0]][7:0] >= 8'h30 &&
                            name_hash_tbl[arr_val[jn_arr][jn_i[6:0]][9:0]][7:0] <= 8'h39) begin
                            // interned "0".."9" — same as number digits for maze wall codes
                            ev = 32'(name_hash_tbl[arr_val[jn_arr][jn_i[6:0]][9:0]][7:0] - 8'h30);
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
                        if (v64_concat) begin
                            vstack[jn_res] <= v64_handle(
                                4'd4, 12'd0, {16'd0, hidx}
                            );
                            v64_concat <= 1'b0;
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
                            if (v64_concat) begin
                                vstack[jn_res] <= v64_handle(
                                    4'd4, 12'd0, {16'd0, names_n}
                                );
                                v64_concat <= 1'b0;
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
                            if (v64_concat) begin
                                vstack[jn_res] <= V64_UNDEFINED;
                                v64_concat <= 1'b0;
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
                            if (v64_concat) begin
                                vstack[jn_res] <= V64_UNDEFINED;
                                v64_concat <= 1'b0;
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
                        release_env_to(cstack_env[csp - 7'd1]);
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
                            // Pass only parameters the callback declared.
                            // Always pushing `el` leaked one stack word per
                            // element for zero-argument map callbacks.
                            if (cstack_ctorobj[csp - 7'd1][7:0] >= 8'd1) begin
                                stack[sp] <=
                                    arr_val[cstack_fe_arr[csp - 7'd1][11:0]]
                                           [cstack_fe_i[csp - 7'd1][6:0]];
                                stack_tag[sp] <=
                                    arr_tag[cstack_fe_arr[csp - 7'd1][11:0]]
                                           [cstack_fe_i[csp - 7'd1][6:0]];
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
                            ip <= obj_val[fo][0][15:0];
                            code_raddr <= 15'(ops_base + obj_val[fo][0][15:0]);
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
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            joy_down_edge[2] ? id_arrow_l : joy_down_edge[3] ? id_arrow_r :
                            joy_down_edge[4] ? id_space : joy_down_edge[0] ? id_arrow_u :
                            joy_down_edge[1] ? id_arrow_d : 16'hFFFF};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= joy_down_edge[2] ? 32'sd37 : joy_down_edge[3] ? 32'sd39 :
                            joy_down_edge[4] ? 32'sd32 : joy_down_edge[0] ? 32'sd38 : 32'sd40;
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
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
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            joy_up_edge[2] ? id_arrow_l : joy_up_edge[3] ? id_arrow_r :
                            joy_up_edge[4] ? id_space : joy_up_edge[0] ? id_arrow_u :
                            joy_up_edge[1] ? id_arrow_d : 16'hFFFF};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= joy_up_edge[2] ? 32'sd37 : joy_up_edge[3] ? 32'sd39 :
                            joy_up_edge[4] ? 32'sd32 : joy_up_edge[0] ? 32'sd38 : 32'sd40;
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
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
                        obj_key[n_obj[12:0]][0] <= id_key;
                        obj_val[n_obj[12:0]][0] <= {16'd0,
                            (kev_q[kev_rp][7:0] == 8'd13) ? id_enter :
                            (kev_q[kev_rp][7:0] == 8'd32) ? id_space :
                            (kev_q[kev_rp][7:0] == 8'd37) ? id_arrow_l :
                            (kev_q[kev_rp][7:0] == 8'd39) ? id_arrow_r :
                            (kev_q[kev_rp][7:0] == 8'd38) ? id_arrow_u :
                            (kev_q[kev_rp][7:0] == 8'd40) ? id_arrow_d :
                            (kev_q[kev_rp][7:0] == 8'd65) ? id_a :
                            (kev_q[kev_rp][7:0] == 8'd68) ? id_d : 16'hFFFF};
                        obj_tag[n_obj[12:0]][0] <= 3'd3;
                        obj_key[n_obj[12:0]][1] <= id_keycode;
                        obj_val[n_obj[12:0]][1] <= 32'({24'd0, kev_q[kev_rp][7:0]});
                        obj_tag[n_obj[12:0]][1] <= 3'd0;
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
                        state <= S_KEYEV;
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
                        // whatever code obj_val[fo][0] pointed at (often ip 0 =
                        // top level, which re-runs boot and resets globals).
                        fn_ok = (obj_cls[fo] == CLS_FN);
                        if (!fn_ok) dbg_tmr_mis <= dbg_tmr_mis + 16'd1;
                        if (fn_ok) begin
                            dbg_tmr_fire <= dbg_tmr_fire + 16'd1;
                            boundary_sp(11'd0);
                            ip <= obj_val[fo][0][15:0];
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
                            code_raddr <= 15'(ops_base + obj_val[fo][0][15:0]);
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
                                txt_rp <= 16'(obj_val[txt_val[12:0]][0][13:0]);
                                txt_len <= (obj_val[txt_val[12:0]][1][13:0] > 14'(TXT_MAX))
                                         ? 7'(TXT_MAX) : 7'(obj_val[txt_val[12:0]][1][13:0]);
                                txt_ph <= (obj_val[txt_val[12:0]][1][13:0] == 14'd0)
                                        ? 4'd6 : 4'd4;
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
                    // registered 1 cycle after dump_raddr). S_CLEAR twin: one
                    // index, always i++ until n — 10-bit x+w wrap spun until
                    // the 16M FRAME cap. 1 px/cycle × 307200 fits; do not
                    // raise the cap. Host FB? must not walk dump_sel (GET
                    // holds it).
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
                        imgd_armed <= 1'b1;
                    end else begin
                        if (imgd_i < 19'(FB_PIXELS))
                            imgd_pix[imgd_i] <= fb_dump_back;
                        if (imgd_i == (imgd_n - 19'd1)) begin
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
                        // Closure/environment parent handles are stored
                        // untagged in their fixed metadata slots.
                        if (obj_cls[gc_cur[12:0]] == CLS_ENV &&
                            gc_slot == 7'd0 &&
                            obj_val[gc_cur[12:0]][0][15:0] != 16'd0)
                            gc_mark_obj(obj_val[gc_cur[12:0]][0][15:0]);
                        else if (obj_cls[gc_cur[12:0]] == CLS_FN &&
                                 gc_slot == 7'd2 &&
                                 obj_val[gc_cur[12:0]][2][15:0] != 16'd0)
                            gc_mark_obj(obj_val[gc_cur[12:0]][2][15:0]);
                        else
                            gc_mark_value(
                                obj_tag[gc_cur[12:0]][gc_slot[4:0]],
                                obj_val[gc_cur[12:0]][gc_slot[4:0]]
                            );
                        gc_slot <= gc_slot + 7'd1;
                    end else
                        state <= S_GC_POP;
                end
                S_GC_ARR: begin
                    if (gc_slot < arr_len[gc_cur[11:0]]) begin
                        gc_mark_value(
                            arr_tag[gc_cur[11:0]][gc_slot[6:0]],
                            arr_val[gc_cur[11:0]][gc_slot[6:0]]
                        );
                        gc_slot <= gc_slot + 7'd1;
                    end else
                        state <= S_GC_POP;
                end
                S_V64_EXEC: begin
                    // Small gated scalar island. Every opcode not implemented
                    // here faults with ERROR_UNSUPPORTED; it never falls into
                    // the legacy tagged/Q16 executor.
                    if (ip >= n_ops) begin
                        if (vsp != 0) begin
                            machine_fault <= 1'b1;
                            fault_code <= 8'd1;
                            running <= 1'b0;
                            state <= S_DONE;
                        end else if (vcsp != 0) begin
                            machine_fault <= 1'b1;
                            fault_code <= 8'd2;
                            running <= 1'b0;
                            state <= S_DONE;
                        end else begin
                            vgc_clear_i <= 14'd0;
                            vgc_qr <= 14'd0;
                            vgc_qw <= 14'd0;
                            vgc_halt_after <= 1'b1;
                            vgc_wait_after <= (vraf_n != 0 || vtimer_n != 0);
                            state <= S_V64_GC_CLEAR;
                        end
                    end else begin
                        unique case (code_rdata[7:0])
                            OP_LOAD_CONST: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if ((code_rdata[31:24] == 8'd0 ||
                                             code_rdata[31:24] == 8'd3) &&
                                             code_rdata[23:8] >= n_consts) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[31:24] == 8'd0 ||
                                             code_rdata[31:24] == 8'd3) begin
                                    vstack[vsp] <=
                                        (vconsts[code_rdata[17:8]][62:52] == 11'h7ff &&
                                         vconsts[code_rdata[17:8]][51:0] != 0)
                                        ? V64_CANON_NAN
                                        : vconsts[code_rdata[17:8]];
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd1 &&
                                             code_rdata[23:8] < names_n) begin
                                    vstack[vsp] <= v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, code_rdata[23:8]}
                                    );
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd2) begin
                                    vstack[vsp] <= V64_UNDEFINED;
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (code_rdata[31:24] == 8'd4) begin
                                    // RegExp stub (PYTHON interned pattern).
                                    valloc_regex <= 1'b1;
                                    vnat_base <= vsp;
                                    valloc_kind <= 2'd0;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end else begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end
                            end
                            OP_LOAD_VAR: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[23:17] != 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic found, handle_error;
                                    logic [63:0] value;
                                    logic [4:0] env_index;
                                    v64_env_lookup_task(
                                        code_rdata[16:8], found, value,
                                        env_index, handle_error
                                    );
                                    if (handle_error) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd4;
                                        running <= 1'b0;
                                        state <= S_DONE;
                                    end else begin
                                        vstack[vsp] <=
                                            (this_ok &&
                                             code_rdata[16:8] == var_this)
                                            ? vthis
                                            : found
                                            ? value
                                            : vvar_valid[code_rdata[16:8]]
                                            ? vvars[code_rdata[16:8]]
                                            : V64_UNDEFINED;
                                        vsp <= vsp + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_STORE_VAR, OP_LET_VAR: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[23:17] != 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic found, handle_error, local_found;
                                    logic [63:0] old_value;
                                    logic [4:0] env_index;
                                    local_found = 1'b0;
                                    v64_env_lookup_task(
                                        code_rdata[16:8], found, old_value,
                                        env_index, handle_error
                                    );
                                    if (handle_error) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd4;
                                        running <= 1'b0;
                                        state <= S_DONE;
                                    end else if (code_rdata[7:0] == OP_LET_VAR &&
                                                 code_rdata[24]) begin
                                        if (vcsp == 0) begin
                                            machine_fault <= 1'b1;
                                            fault_code <= 8'd2;
                                            running <= 1'b0;
                                            state <= S_DONE;
                                        end else if (
                                            venv[63:48] != 16'h7ff9 ||
                                            venv[47:44] != 4'd9 ||
                                            venv[31:0] >= ENV_DEPTH ||
                                            !venv_valid[venv[4:0]] ||
                                            venv_gen[venv[4:0]] !=
                                                venv[43:32]) begin
                                            // Flat IIFE: LET_VAR local with
                                            // no ENV stores the global
                                            // (PYTHON Value64 / JSB a1 bit6).
                                            vvars[code_rdata[16:8]] <=
                                                vstack[vsp - 12'd1];
                                            vvar_valid[code_rdata[16:8]] <=
                                                1'b1;
                                            vsp <= vsp - 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(
                                                ops_base + ip + 16'd1
                                            );
                                            state <= S_FETCH_WAIT;
                                        end else begin
                                            for (int k = 0; k < ENV_SLOTS; k++)
                                                if (k < venv_len[venv[4:0]] &&
                                                    venv_key[venv[4:0]][k] ==
                                                        code_rdata[16:8]) begin
                                                    local_found = 1'b1;
                                                    venv_val[venv[4:0]][k] <=
                                                        vstack[vsp - 12'd1];
                                                end
                                            if (!local_found &&
                                                venv_len[venv[4:0]] >=
                                                    ENV_SLOTS) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                if (!local_found) begin
                                                    venv_key[venv[4:0]]
                                                            [venv_len[venv[4:0]]] <=
                                                        code_rdata[16:8];
                                                    venv_val[venv[4:0]]
                                                            [venv_len[venv[4:0]]] <=
                                                        vstack[vsp - 12'd1];
                                                    venv_len[venv[4:0]] <=
                                                        venv_len[venv[4:0]] + 5'd1;
                                                end
                                                vsp <= vsp - 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <= 15'(
                                                    ops_base + ip + 16'd1
                                                );
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                    end else begin
                                        if (this_ok &&
                                            code_rdata[16:8] == var_this) begin
                                            if (code_rdata[7:0] == OP_STORE_VAR ||
                                                !vvar_valid[code_rdata[16:8]])
                                                vthis <= vstack[vsp - 12'd1];
                                        end else if (
                                            code_rdata[7:0] == OP_STORE_VAR &&
                                            found) begin
                                            for (int k = 0; k < ENV_SLOTS; k++)
                                                if (k < venv_len[env_index] &&
                                                    venv_key[env_index][k] ==
                                                        code_rdata[16:8])
                                                    venv_val[env_index][k] <=
                                                        vstack[vsp - 12'd1];
                                        end else if (
                                            code_rdata[7:0] == OP_STORE_VAR ||
                                            !vvar_valid[code_rdata[16:8]]
                                        ) begin
                                            vvars[code_rdata[16:8]] <=
                                                vstack[vsp - 12'd1];
                                            vvar_valid[code_rdata[16:8]] <= 1'b1;
                                        end
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_MAKE_ARR: begin
                                if (code_rdata[23:8] > ARR_CAP) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd3;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vsp < code_rdata[19:8] ||
                                             (code_rdata[23:8] == 0 &&
                                              vsp >= 12'(STACK_DEPTH))) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    valloc_kind <= 2'd1;
                                    valloc_i <= varr_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_MAKE_OBJ: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    valloc_kind <= 2'd0;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_CALL: begin
                                logic [7:0] nid, argc;
                                logic [11:0] base;
                                logic [63:0] result;
                                logic bad_fn, found_slot;
                                logic [6:0] free_slot;
                                logic signed [31:0] ms, frames, wanted;
                                nid = code_rdata[15:8];
                                argc = code_rdata[31:24];
                                base = vsp - argc;
                                result = V64_UNDEFINED;
                                bad_fn = 1'b0;
                                found_slot = 1'b0;
                                free_slot = 7'd0;
                                ms = 32'sd0;
                                frames = 32'sd1;
                                wanted = -32'sd1;
                                if (vsp < argc) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd1;
                                    running <= 1'b0;
                                    state <= S_DONE;
                                end else begin
                                    unique case (nid)
                                        8'd0: begin // bounded diagnostic sink
                                            if (vconsole_n >= 9'd256) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                vconsole_n <= vconsole_n + 9'd1;
                                                vstack[base] <= result;
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                        8'd1: begin // clear(back buffer, color)
                                            vdraw_color <= (argc != 0)
                                                ? v64_to_uint32(vstack[base])[7:0]
                                                : 8'd0;
                                            vdraw_i <= 19'd0;
                                            vnat_base <= base;
                                            state <= S_V64_CLEAR;
                                        end
                                        8'd2: begin // fillRect(x,y,w,h[,color])
                                            if (argc < 4) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd5;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                vdraw_x <= v64_to_uint32(vstack[base])[9:0];
                                                vdraw_y <= v64_to_uint32(vstack[base + 1])[9:0];
                                                vdraw_w <= v64_to_uint32(vstack[base + 2])[9:0];
                                                vdraw_h <= v64_to_uint32(vstack[base + 3])[9:0];
                                                vdraw_color <= (argc > 4)
                                                    ? v64_to_uint32(vstack[base + 4])[7:0]
                                                    : 8'hff;
                                                vdraw_i <= 19'd0;
                                                vnat_base <= base;
                                                state <= S_V64_RECT;
                                            end
                                        end
                                        8'd3: begin
                                            fb_swap <= 1'b1;
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd4, 8'd5, 8'd6, 8'd8, 8'd9: begin
                                            // play_bits: left=4 right=8 fire=16 up=1 down=2
                                            result = v64_handle(
                                                V64_KIND_BOOL, 12'd0,
                                                {31'd0,
                                                 (nid == 8'd4) ? joy_in[2] :
                                                 (nid == 8'd5) ? joy_in[3] :
                                                 (nid == 8'd6) ? joy_in[4] :
                                                 (nid == 8'd8) ? joy_in[0] :
                                                 joy_in[1]}
                                            );
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd7: begin // startLoop
                                            looping <= 1'b1;
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd10: begin // Math.floor
                                            result = (argc == 0)
                                                ? V64_CANON_NAN
                                                : v64_floor_number(vstack[base]);
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd11: begin // Math.abs
                                            if (argc == 0) result = V64_CANON_NAN;
                                            else if (vstack[base][62:52] == 11'h7ff &&
                                                     vstack[base][51:0] != 0)
                                                result = V64_CANON_NAN;
                                            else
                                                result = {1'b0, vstack[base][62:0]};
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd12, 8'd13: begin // Math.min/max
                                            result = (nid == 8'd12)
                                                ? 64'h7ff0000000000000
                                                : 64'hfff0000000000000;
                                            for (int k = 0; k < 256; k++)
                                                if (k < argc) begin
                                                    if (vstack[base + k][62:52] == 11'h7ff &&
                                                        vstack[base + k][51:0] != 0)
                                                        result = V64_CANON_NAN;
                                                    else if (nid == 8'd12
                                                             ? v64_less(vstack[base + k], result)
                                                             : v64_less(result, vstack[base + k]))
                                                        result = vstack[base + k];
                                                end
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd14: begin // deterministic LCG / 2^32
                                            logic [31:0] next_rng;
                                            next_rng = 32'(vrng * 32'd1664525 +
                                                           32'd1013904223);
                                            vrng <= next_rng;
                                            vstack[base] <= v64_u32_fraction(next_rng);
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd27: begin // requestAnimationFrame
                                            bad_fn = argc == 0 ||
                                                vstack[base][63:48] != 16'h7ff9 ||
                                                vstack[base][47:44] != 4'd7 ||
                                                vstack[base][31:0] >= MAX_OBJ ||
                                                vobj_alloc[vstack[base][12:0]] != 2'd2 ||
                                                vfn_gen[vstack[base][12:0]] !=
                                                    vstack[base][43:32];
                                            if (bad_fn) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd4;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else if (vraf_n >= 4'd8) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                vraf[vraf_n] <= vstack[base];
                                                vraf_n <= vraf_n + 4'd1;
                                                vstack[base] <= result;
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                        8'd28, 8'd29: begin // timeout / interval
                                            bad_fn = argc == 0 ||
                                                vstack[base][63:48] != 16'h7ff9 ||
                                                vstack[base][47:44] != 4'd7 ||
                                                vstack[base][31:0] >= MAX_OBJ ||
                                                vobj_alloc[vstack[base][12:0]] != 2'd2 ||
                                                vfn_gen[vstack[base][12:0]] !=
                                                    vstack[base][43:32];
                                            for (int k = 0; k < 64; k++)
                                                if (!found_slot && !vtimer_valid[k]) begin
                                                    found_slot = 1'b1;
                                                    free_slot = 7'(k);
                                                end
                                            if (argc > 1)
                                                ms = $signed(v64_to_uint32(vstack[base + 1]));
                                            if (ms > 0)
                                                frames = (ms * 32'sd3 + 32'sd25) /
                                                         32'sd50;
                                            if (frames < 1)
                                                frames = 1;
                                            if (bad_fn) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd4;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else if (!found_slot || vtimer_n >= 7'd64) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                vtimer_valid[free_slot] <= 1'b1;
                                                vtimer_due[free_slot] <=
                                                    $signed(vframe_no) + frames;
                                                vtimer_id[free_slot] <= $signed(vtimer_seq);
                                                vtimer_period[free_slot] <=
                                                    (nid == 8'd29) ? 64'(frames) : -64'sd1;
                                                vtimer_fn[free_slot] <= vstack[base];
                                                vtimer_n <= vtimer_n + 7'd1;
                                                vtimer_seq <= vtimer_seq + 32'd1;
                                                vstack[base] <=
                                                    v64_int32_number(vtimer_seq);
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <=
                                                    15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                        8'd30, 8'd31: begin // clear timer
                                            if (argc != 0)
                                                wanted = $signed(
                                                    v64_to_uint32(vstack[base])
                                                );
                                            for (int k = 0; k < 64; k++)
                                                if (vtimer_valid[k] &&
                                                    vtimer_id[k] == wanted) begin
                                                    vtimer_valid[k] <= 1'b0;
                                                    vtimer_n <= vtimer_n - 7'd1;
                                                end
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd16, 8'd17, 8'd18: begin
                                            // getElementById / querySelector /
                                            // createElement → ELEMENT+style
                                            vnat_dom <= 3'd1;
                                            vnat_base <= base;
                                            valloc_kind <= 2'd0;
                                            valloc_i <= vobj_next;
                                            valloc_retried <= 1'b0;
                                            state <= S_V64_ALLOC;
                                        end
                                        8'd19, 8'd20: begin // addEventListener
                                            logic [63:0] ev, fn;
                                            logic [4:0] same_n;
                                            logic dup;
                                            ev = (argc != 0) ? vstack[base] : V64_UNDEFINED;
                                            fn = (argc > 1) ? vstack[base + 1] : V64_UNDEFINED;
                                            same_n = 5'd0;
                                            dup = 1'b0;
                                            for (int k = 0; k < 16; k++)
                                                if (k < vlistener_n) begin
                                                    if (v64_equal(vlistener_ev[k], ev) &&
                                                        v64_equal(vlistener_fn[k], fn))
                                                        dup = 1'b1;
                                                    if (v64_equal(vlistener_ev[k], ev))
                                                        same_n = same_n + 5'd1;
                                                end
                                            if (fn[63:48] != 16'h7ff9 ||
                                                fn[47:44] != 4'd7) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd4;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else if (!dup && same_n >= 5'd4) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else if (!dup && vlistener_n >= 5'd16) begin
                                                machine_fault <= 1'b1;
                                                fault_code <= 8'd3;
                                                running <= 1'b0;
                                                state <= S_DONE;
                                            end else begin
                                                if (!dup) begin
                                                    vlistener_ev[vlistener_n] <= ev;
                                                    vlistener_fn[vlistener_n] <= fn;
                                                    vlistener_n <= vlistener_n + 5'd1;
                                                end
                                                vstack[base] <= result;
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <=
                                                    15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                        8'd21, 8'd22, 8'd32: begin
                                            // localStorage get/set/remove stub
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd23: begin
                                            // JSON.parse: null/undefined → null
                                            // (getLeaderboard || []). Interned /
                                            // dynstr → nested Value64 arrays.
                                            if (argc == 0 ||
                                                vstack[base][63:48] == V64_TAG_PREFIX &&
                                                (vstack[base][47:44] == V64_KIND_UNDEFINED ||
                                                 vstack[base][47:44] == V64_KIND_NULL)) begin
                                                vstack[base] <= V64_NULL;
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <=
                                                    15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end else if (vstack[base][63:48] == V64_TAG_PREFIX &&
                                                       vstack[base][47:44] == V64_KIND_STRING &&
                                                       vstack[base][15:0] < names_n) begin
                                                json_src <= 14'd0;
                                                json_srclen <= {6'd0,
                                                    name_len_tbl[vstack[base][9:0]]};
                                                json_rp <= 14'd0;
                                                js_sp <= 6'd0;
                                                json_pph <= 3'd0;
                                                vnat_base <= base;
                                                if (name_len_tbl[vstack[base][9:0]] == 8'd0) begin
                                                    vstack[base] <= V64_NULL;
                                                    vsp <= base + 12'd1;
                                                    ip <= ip + 16'd1;
                                                    code_raddr <=
                                                        15'(ops_base + ip + 16'd1);
                                                    state <= S_FETCH_WAIT;
                                                end else begin
                                                    name_rdaddr <=
                                                        name_off[vstack[base][9:0]];
                                                    json_wp <= 14'd0;
                                                    namcpy_repl <= 1'b0;
                                                    namcpy_v64 <= 1'b1;
                                                    namcpy_armed <= 1'b0;
                                                    state <= S_NAMCPY;
                                                end
                                            end else if (vstack[base][63:48] == V64_TAG_PREFIX &&
                                                       vstack[base][47:44] == V64_KIND_OBJECT &&
                                                       vstack[base][31:0] < MAX_OBJ &&
                                                       vobj_alloc[vstack[base][12:0]] == 2'd1 &&
                                                       vobj_builtin[vstack[base][12:0]] == 4'd7) begin
                                                json_src <= 14'(v64_to_uint32(
                                                    vobj_val[vstack[base][12:0]][0]));
                                                json_srclen <= 14'(v64_to_uint32(
                                                    vobj_val[vstack[base][12:0]][1]));
                                                json_rp <= 14'(v64_to_uint32(
                                                    vobj_val[vstack[base][12:0]][0]));
                                                js_sp <= 6'd0;
                                                json_pph <= 3'd0;
                                                vnat_base <= base;
                                                state <= S_V64_JSON_PARSE;
                                            end else begin
                                                vstack[base] <= V64_NULL;
                                                vsp <= base + 12'd1;
                                                ip <= ip + 16'd1;
                                                code_raddr <=
                                                    15'(ops_base + ip + 16'd1);
                                                state <= S_FETCH_WAIT;
                                            end
                                        end
                                        8'd24: begin
                                            // JSON.stringify → dynstr in json_mem
                                            json_wp <= 14'd0;
                                            js_sp <= 6'd1;
                                            vjs_val[0] <= (argc != 0)
                                                ? vstack[base] : V64_UNDEFINED;
                                            js_i[0] <= 8'd0;
                                            js_ph[0] <= 3'd0;
                                            vnat_base <= base;
                                            state <= S_V64_JSON;
                                        end
                                        8'd25: begin // Date() stub object
                                            vnat_dom <= 3'd6;
                                            vnat_base <= base;
                                            valloc_kind <= 2'd0;
                                            valloc_i <= vobj_next;
                                            valloc_retried <= 1'b0;
                                            state <= S_V64_ALLOC;
                                        end
                                        8'd26: begin // Image() stub
                                            vnat_dom <= 3'd4;
                                            vnat_base <= base;
                                            valloc_kind <= 2'd0;
                                            valloc_i <= vobj_next;
                                            valloc_retried <= 1'b0;
                                            state <= S_V64_ALLOC;
                                        end
                                        8'd33: begin // unknown CALL_NATIVE no-op
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd34: begin // Array(...) empty stub
                                            vnat_dom <= 3'd7;
                                            vnat_base <= base;
                                            valloc_kind <= 2'd1;
                                            valloc_i <= varr_next;
                                            valloc_retried <= 1'b0;
                                            state <= S_V64_ALLOC;
                                        end
                                        8'd35: begin // performance.now
                                            logic [63:0] frame_number;
                                            frame_number = v64_int32_number(vframe_no);
                                            v64_mul_task(
                                                frame_number,
                                                64'h4030aaaaaaaaaaab,
                                                result
                                            );
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        8'd36, 8'd37: begin // removeEventListener
                                            vstack[base] <= result;
                                            vsp <= base + 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <= 15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                        default: begin
                                            machine_fault <= 1'b1;
                                            fault_code <= 8'd5;
                                            running <= 1'b0;
                                            state <= S_DONE;
                                        end
                                    endcase
                                end
                            end
                            OP_MAKE_FN: begin
                                if (vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    valloc_kind <= 2'd2;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_CALL_USER: begin
                                if (vcsp >= CSTK) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vsp < code_rdata[31:24]) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vcall_value <= 1'b0;
                                    vcall_entry <= code_rdata[23:8];
                                    vcall_argc <= code_rdata[31:24];
                                    vcall_set_this <= 1'b0;
                                    vcall_ctor_val <= V64_UNDEFINED;
                                    valloc_kind <= 2'd3;
                                    valloc_i <= venv_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_CALL_VAL: begin
                                logic [15:0] argc;
                                logic [63:0] handle;
                                logic iife_flat;
                                logic [11:0] base_sp;
                                logic [7:0] nparam;
                                argc = code_rdata[23:8];
                                handle = (vsp > argc)
                                    ? vstack[vsp - argc - 12'd1]
                                    : V64_UNDEFINED;
                                iife_flat = (handle[63:48] == 16'h7ff9 &&
                                             handle[47:44] == 4'd7 &&
                                             handle[31:0] < MAX_OBJ &&
                                             vobj_alloc[handle[12:0]] == 2'd2 &&
                                             vfn_gen[handle[12:0]] ==
                                                handle[43:32] &&
                                             vfn_flags[handle[12:0]][1] &&
                                             (vfn_env[handle[12:0]][63:48] !=
                                                V64_TAG_PREFIX ||
                                              vfn_env[handle[12:0]][47:44] !=
                                                V64_KIND_ENV));
                                if (vcsp >= CSTK) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vsp < argc + 16'd1) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (handle[63:48] != 16'h7ff9 ||
                                             handle[47:44] != 4'd7 ||
                                             handle[31:0] >= MAX_OBJ ||
                                             vobj_alloc[handle[12:0]] != 2'd2 ||
                                             vfn_gen[handle[12:0]] !=
                                                handle[43:32]) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd4;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vfn_entry[handle[12:0]] ==
                                           16'hfffa) begin
                                    // Date.now / performance.now native 35.
                                    logic [63:0] now_result;
                                    logic [11:0] now_base;
                                    now_base = vsp - argc - 12'd1;
                                    v64_mul_task(
                                        v64_int32_number(vframe_no),
                                        64'h4030aaaaaaaaaaab,
                                        now_result
                                    );
                                    vstack[now_base] <= now_result;
                                    vsp <= now_base + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (iife_flat) begin
                                    // JSB MAKE_FN a1 bit6: top-level IIFE is
                                    // a flat call (no ENV). Same ProgramImage
                                    // as PYTHON Value64.
                                    base_sp = vsp - argc - 12'd1;
                                    nparam = {2'd0, vfn_nparam[handle[12:0]]};
                                    vframe_return_ip[vcsp] <= ip + 16'd1;
                                    vframe_base_sp[vcsp] <= base_sp;
                                    vframe_this[vcsp] <= vthis;
                                    vframe_env[vcsp] <= venv;
                                    vframe_fn[vcsp] <= handle;
                                    vframe_ctor[vcsp] <= V64_UNDEFINED;
                                    vcsp <= vcsp + 8'd1;
                                    vthis <= V64_UNDEFINED;
                                    for (int k = 0; k < 64; k++)
                                        if (k < nparam)
                                            vstack[base_sp + k] <=
                                                (k < argc)
                                                ? vstack[vsp - argc + k]
                                                : V64_UNDEFINED;
                                    vsp <= base_sp + nparam;
                                    ip <= vfn_entry[handle[12:0]];
                                    code_raddr <= 15'(
                                        ops_base + vfn_entry[handle[12:0]]
                                    );
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    vcall_value <= 1'b1;
                                    vcall_entry <= 16'd0;
                                    vcall_argc <= argc[11:0];
                                    vcall_set_this <= 1'b0;
                                    vcall_ctor_val <= V64_UNDEFINED;
                                    valloc_kind <= 2'd3;
                                    valloc_i <= venv_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_RET_VAL: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vcsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (
                                    vsp - 12'd1 != vframe_base_sp[vcsp - 8'd1]
                                ) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vthis <= vframe_this[vcsp - 8'd1];
                                    venv <= vframe_env[vcsp - 8'd1];
                                    vcsp <= vcsp - 8'd1;
                                    if (vframe_return_ip[vcsp - 8'd1] ==
                                        16'hffff) begin
                                        vsp <= vframe_base_sp[vcsp - 8'd1];
                                        state <= S_V64_FRAME_RAF;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffe
                                    ) begin
                                        vsp <= vframe_base_sp[vcsp - 8'd1];
                                        state <= S_V64_FRAME_TIMER;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffd
                                    ) begin
                                        vsp <= vframe_base_sp[vcsp - 8'd1];
                                        state <= S_V64_FRAME_KEY;
                                    end else if (
                                        vframe_return_ip[vcsp - 8'd1] ==
                                        16'hfffc
                                    ) begin
                                        vsp <= vframe_base_sp[vcsp - 8'd1];
                                        state <= S_V64_FOREACH;
                                    end else begin
                                        // PYTHON RET_VAL: constructor frames
                                        // yield the instance, not undefined.
                                        vstack[vframe_base_sp[vcsp - 8'd1]] <=
                                            (vframe_ctor[vcsp - 8'd1][63:48] ==
                                             V64_TAG_PREFIX &&
                                             vframe_ctor[vcsp - 8'd1][47:44] ==
                                             V64_KIND_OBJECT)
                                            ? vframe_ctor[vcsp - 8'd1]
                                            : vstack[vsp - 12'd1];
                                        vsp <=
                                            vframe_base_sp[vcsp - 8'd1] + 12'd1;
                                        ip <= vframe_return_ip[vcsp - 8'd1];
                                        code_raddr <= 15'(
                                            ops_base +
                                            vframe_return_ip[vcsp - 8'd1]
                                        );
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_ARR_GET: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic index_valid;
                                    logic signed [32:0] array_index;
                                    handle = vstack[vsp - 12'd2];
                                    v64_array_index_task(
                                        vstack[vsp - 12'd1],
                                        index_valid, array_index
                                    );
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd4 &&
                                        handle[31:0] < 32'd1024) begin
                                        // PYTHON: interned "str"[i] is one char.
                                        // name_mem is BRAM — result in S_V64_STRIDX.
                                        if (!index_valid) begin
                                            machine_fault <= 1'b1;
                                            fault_code <= 8'hff;
                                            running <= 1'b0;
                                            state <= S_DONE;
                                        end else if (array_index < 0 ||
                                            array_index >=
                                                name_len_tbl[handle[9:0]]) begin
                                            vstack[vsp - 12'd2] <=
                                                V64_UNDEFINED;
                                            vsp <= vsp - 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <=
                                                15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end else begin
                                            name_rdaddr <=
                                                name_off[handle[9:0]] +
                                                16'(array_index);
                                            vsp <= vsp - 12'd1;
                                            ip <= ip + 16'd1;
                                            state <= S_V64_STRIDX;
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid[handle[11:0]] ||
                                        varr_gen[handle[11:0]] != handle[43:32]) begin
                                        // JS: Number[index] is undefined, not a type fault.
                                        vstack[vsp - 12'd2] <= V64_UNDEFINED;
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else if (!index_valid) begin
                                        machine_fault <= 1'b1; fault_code <= 8'hff;
                                        running <= 1'b0; state <= S_DONE;
                                    end else begin
                                        vstack[vsp - 12'd2] <=
                                            (array_index >= 0 &&
                                             array_index < varr_len[handle[11:0]])
                                            ? varr_val[handle[11:0]][array_index[6:0]]
                                            : V64_UNDEFINED;
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_ARR_SET: begin
                                if (vsp < 12'd3) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic index_valid;
                                    logic signed [32:0] array_index;
                                    handle = vstack[vsp - 12'd3];
                                    v64_array_index_task(
                                        vstack[vsp - 12'd2],
                                        index_valid, array_index
                                    );
                                    if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd6 ||
                                        handle[31:0] >= MAX_ARR ||
                                        !varr_valid[handle[11:0]] ||
                                        varr_gen[handle[11:0]] != handle[43:32]) begin
                                        machine_fault <= 1'b1; fault_code <= 8'd4;
                                        running <= 1'b0; state <= S_DONE;
                                    end else if (!index_valid) begin
                                        machine_fault <= 1'b1; fault_code <= 8'hff;
                                        running <= 1'b0; state <= S_DONE;
                                    end else if (array_index < 0 ||
                                                 array_index >= ARR_CAP) begin
                                        machine_fault <= 1'b1; fault_code <= 8'hff;
                                        running <= 1'b0; state <= S_DONE;
                                    end else begin
                                        if (array_index >= varr_len[handle[11:0]]) begin
                                            for (int k = 0; k < ARR_CAP; k++)
                                                if (k >= varr_len[handle[11:0]] &&
                                                    k < array_index)
                                                    varr_val[handle[11:0]][k] <=
                                                        V64_UNDEFINED;
                                            varr_len[handle[11:0]] <=
                                                array_index[7:0] + 8'd1;
                                        end
                                        varr_val[handle[11:0]][array_index[6:0]] <=
                                            vstack[vsp - 12'd1];
                                        vstack[vsp - 12'd3] <= vstack[vsp - 12'd1];
                                        vsp <= vsp - 12'd2;
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_GET_PROP: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] handle, result;
                                    logic found;
                                    handle = vstack[vsp - 12'd1];
                                    found = 1'b0;
                                    result = V64_UNDEFINED;
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd6 &&
                                        handle[31:0] < MAX_ARR &&
                                        varr_valid[handle[11:0]] &&
                                        varr_gen[handle[11:0]] == handle[43:32]) begin
                                        if (code_rdata[23:8] == id_length)
                                            result = v64_int32_number(
                                                {24'd0, varr_len[handle[11:0]]}
                                            );
                                        vstack[vsp - 12'd1] <= result;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else if (handle[63:48] == 16'h7ff9 &&
                                                 handle[47:44] == 4'd4 &&
                                                 handle[31:0] < 32'd1024) begin
                                        if (code_rdata[23:8] == id_now) begin
                                            // PYTHON: Date.now / performance.now
                                            // on the interned constructor name.
                                            valloc_now_fn <= 1'b1;
                                            vnat_base <= vsp - 12'd1;
                                            valloc_kind <= 2'd2;
                                            valloc_i <= vobj_next;
                                            valloc_retried <= 1'b0;
                                            state <= S_V64_ALLOC;
                                        end else begin
                                            if (code_rdata[23:8] == id_length)
                                                result = v64_int32_number(
                                                    {24'd0, name_len_tbl[handle[9:0]]}
                                                );
                                            vstack[vsp - 12'd1] <= result;
                                            ip <= ip + 16'd1;
                                            code_raddr <=
                                                15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd5 ||
                                        handle[31:0] >= MAX_OBJ ||
                                        vobj_alloc[handle[12:0]] != 2'd1 ||
                                        vobj_gen[handle[12:0]] != handle[43:32]) begin
                                        // PYTHON: missing/primitive GET_PROP
                                        // is undefined (width/height → 640/480).
                                        if (code_rdata[23:8] == id_width)
                                            result = v64_int32_number(32'd640);
                                        else if (code_rdata[23:8] == id_height)
                                            result = v64_int32_number(32'd480);
                                        vstack[vsp - 12'd1] <= result;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        for (int k = 0; k < OBJ_SLOTS; k++)
                                            if (k < vobj_len[handle[12:0]] &&
                                                vobj_key[handle[12:0]][k] ==
                                                    code_rdata[23:8]) begin
                                                found = 1'b1;
                                                result = vobj_val[handle[12:0]][k];
                                            end
                                        vstack[vsp - 12'd1] <= result;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end
                            end
                            OP_SET_PROP: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] handle;
                                    logic found;
                                    handle = vstack[vsp - 12'd2];
                                    found = 1'b0;
                                    if (handle[63:48] == 16'h7ff9 &&
                                        handle[47:44] == 4'd6 &&
                                        handle[31:0] < MAX_ARR &&
                                        varr_valid[handle[11:0]] &&
                                        varr_gen[handle[11:0]] == handle[43:32] &&
                                        code_rdata[23:8] == id_length) begin
                                        logic [31:0] new_len;
                                        new_len = v64_to_uint32(vstack[vsp - 12'd1]);
                                        if (new_len > ARR_CAP) begin
                                            machine_fault <= 1'b1;
                                            fault_code <= 8'd3;
                                            running <= 1'b0;
                                            state <= S_DONE;
                                        end else begin
                                            if (new_len > varr_len[handle[11:0]])
                                                for (int k = 0; k < ARR_CAP; k++)
                                                    if (k >= varr_len[handle[11:0]] &&
                                                        k < new_len)
                                                        varr_val[handle[11:0]][k] <=
                                                            V64_UNDEFINED;
                                            varr_len[handle[11:0]] <= new_len[7:0];
                                            vstack[vsp - 12'd2] <=
                                                vstack[vsp - 12'd1];
                                            vsp <= vsp - 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <=
                                                15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                    end else if (handle[63:48] != 16'h7ff9 ||
                                        handle[47:44] != 4'd5 ||
                                        handle[31:0] >= MAX_OBJ ||
                                        vobj_alloc[handle[12:0]] != 2'd1 ||
                                        vobj_gen[handle[12:0]] != handle[43:32]) begin
                                        // PYTHON: SET_PROP on a primitive is a
                                        // sloppy-mode no-op (Date.now = fn).
                                        vstack[vsp - 12'd2] <=
                                            vstack[vsp - 12'd1];
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        for (int k = 0; k < OBJ_SLOTS; k++)
                                            if (k < vobj_len[handle[12:0]] &&
                                                vobj_key[handle[12:0]][k] ==
                                                    code_rdata[23:8]) begin
                                                found = 1'b1;
                                                vobj_val[handle[12:0]][k] <=
                                                    vstack[vsp - 12'd1];
                                            end
                                        if (!found &&
                                            vobj_len[handle[12:0]] >= OBJ_SLOTS) begin
                                            machine_fault <= 1'b1;
                                            fault_code <= 8'd3;
                                            running <= 1'b0;
                                            state <= S_DONE;
                                        end else begin
                                            if (!found) begin
                                                vobj_key[handle[12:0]]
                                                        [vobj_len[handle[12:0]]] <=
                                                    code_rdata[23:8];
                                                vobj_val[handle[12:0]]
                                                        [vobj_len[handle[12:0]]] <=
                                                    vstack[vsp - 12'd1];
                                                vobj_len[handle[12:0]] <=
                                                    vobj_len[handle[12:0]] + 6'd1;
                                            end
                                            if (code_rdata[23:8] == id_fillstyle ||
                                                code_rdata[23:8] == id_strokestyle) begin
                                                logic [63:0] style_val;
                                                style_val = vstack[vsp - 12'd1];
                                                if (v64_is_number(style_val))
                                                    fill_style_i <=
                                                        v64_to_uint32(style_val)[7:0];
                                                else if (style_val[63:48] == 16'h7ff9 &&
                                                         style_val[47:44] == 4'd4 &&
                                                         style_val[15:0] < 16'd1024 &&
                                                         fill_lut[style_val[9:0]] != 8'hFF)
                                                    fill_style_i <=
                                                        fill_lut[style_val[9:0]];
                                                else if (style_val[15:0] == id_black ||
                                                         style_val[15:0] == id_hex_000)
                                                    fill_style_i <= 8'd0;
                                                else if (style_val[15:0] == id_white ||
                                                         style_val[15:0] == id_hex_fff)
                                                    fill_style_i <= 8'd1;
                                                else
                                                    fill_style_i <= 8'd1;
                                            end
                                            vstack[vsp - 12'd2] <=
                                                vstack[vsp - 12'd1];
                                            vsp <= vsp - 12'd1;
                                            ip <= ip + 16'd1;
                                            code_raddr <=
                                                15'(ops_base + ip + 16'd1);
                                            state <= S_FETCH_WAIT;
                                        end
                                    end
                                end
                            end
                            OP_NEW_OBJ: begin
                                if (vsp < code_rdata[31:24]) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[31:24] == 8'd0 &&
                                             vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    valloc_kind <= 2'd0;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end
                            end
                            OP_CALL_METH: begin
                                logic [11:0] argc, base;
                                logic [63:0] receiver;
                                logic [15:0] mip;
                                logic obj_ok, arr_ok;
                                logic [7:0] paint_color;
                                logic [4:0] same_n;
                                logic dup;
                                logic [63:0] ev, fn;
                                argc = {4'd0, code_rdata[31:24]};
                                base = vsp - argc - 12'd1;
                                receiver = (vsp > argc)
                                    ? vstack[base]
                                    : V64_UNDEFINED;
                                mip = 16'hFFFF;
                                obj_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          receiver[47:44] == V64_KIND_OBJECT &&
                                          receiver[31:0] < MAX_OBJ &&
                                          vobj_alloc[receiver[12:0]] == 2'd1 &&
                                          vobj_gen[receiver[12:0]] ==
                                              receiver[43:32]);
                                arr_ok = (receiver[63:48] == V64_TAG_PREFIX &&
                                          receiver[47:44] == V64_KIND_ARRAY &&
                                          receiver[31:0] < MAX_ARR &&
                                          varr_valid[receiver[11:0]] &&
                                          varr_gen[receiver[11:0]] ==
                                              receiver[43:32]);
                                paint_color = 8'd0;
                                same_n = 5'd0;
                                dup = 1'b0;
                                ev = V64_UNDEFINED;
                                fn = V64_UNDEFINED;
                                if (vcsp >= CSTK) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (vsp < argc + 12'd1) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[23:8] == id_assign &&
                                           argc >= 12'd1) begin
                                    // Object.assign(target, ...src) — overwrite
                                    // existing keys, append new (PYTHON / tagged).
                                    begin
                                        logic [63:0] tgt, sv;
                                        logic [12:0] ti, si;
                                        logic [5:0] tn, tn0;
                                        logic tgt_ok, src_ok, hitp;
                                        logic [5:0] hidx;
                                        tgt = vstack[base + 12'd1];
                                        tgt_ok = (tgt[63:48] == V64_TAG_PREFIX &&
                                                  (tgt[47:44] == V64_KIND_OBJECT ||
                                                   tgt[47:44] == V64_KIND_ELEMENT) &&
                                                  tgt[31:0] < MAX_OBJ &&
                                                  vobj_alloc[tgt[12:0]] == 2'd1 &&
                                                  vobj_gen[tgt[12:0]] ==
                                                      tgt[43:32]);
                                        if (tgt_ok) begin
                                            ti = tgt[12:0];
                                            tn = vobj_len[ti];
                                            tn0 = vobj_len[ti];
                                            for (int src = 0; src < 3; src++)
                                                if (src < argc - 12'd1) begin
                                                    sv = vstack[base + 12'd2 + src];
                                                    src_ok = (sv[63:48] == V64_TAG_PREFIX &&
                                                              (sv[47:44] == V64_KIND_OBJECT ||
                                                               sv[47:44] == V64_KIND_ELEMENT) &&
                                                              sv[31:0] < MAX_OBJ &&
                                                              vobj_alloc[sv[12:0]] == 2'd1);
                                                    if (src_ok) begin
                                                        si = sv[12:0];
                                                        for (int s = 0; s < OBJ_SLOTS; s++) begin
                                                            hitp = 1'b0;
                                                            hidx = 6'd0;
                                                            for (int t = 0; t < OBJ_SLOTS; t++)
                                                                if (t < tn0 &&
                                                                    vobj_key[ti][t] ==
                                                                        vobj_key[si][s]) begin
                                                                    hitp = 1'b1;
                                                                    hidx = 6'(t);
                                                                end
                                                            if (s < vobj_len[si]) begin
                                                                if (hitp)
                                                                    vobj_val[ti][hidx] <=
                                                                        vobj_val[si][s];
                                                                else if (tn < OBJ_SLOTS[5:0]) begin
                                                                    vobj_key[ti][tn] <=
                                                                        vobj_key[si][s];
                                                                    vobj_val[ti][tn] <=
                                                                        vobj_val[si][s];
                                                                    tn = tn + 6'd1;
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            vobj_len[ti] <= tn;
                                        end
                                        vstack[base] <= tgt;
                                        vsp <= base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end else if (arr_ok &&
                                           code_rdata[23:8] == id_push) begin
                                    if (varr_len[receiver[11:0]] + argc[7:0] >
                                            ARR_CAP[7:0]) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end else begin
                                        for (int k = 0; k < 64; k++)
                                            if (k < argc)
                                                varr_val[receiver[11:0]]
                                                    [varr_len[receiver[11:0]] + k] <=
                                                    vstack[base + 12'd1 + k];
                                        varr_len[receiver[11:0]] <=
                                            varr_len[receiver[11:0]] + argc[7:0];
                                        vstack[base] <= v64_int32_number(
                                            {24'd0, varr_len[receiver[11:0]]} +
                                            {20'd0, argc}
                                        );
                                        vsp <= base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end else if (arr_ok &&
                                           code_rdata[23:8] == id_foreach) begin
                                    if (vfe_sp >= 4'd8) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end else begin
                                        vfe_arr_s[vfe_sp] <= vfe_arr;
                                        vfe_fn_s[vfe_sp] <= vfe_fn;
                                        vfe_i_s[vfe_sp] <= vfe_i;
                                        vfe_ret_s[vfe_sp] <= vfe_ret;
                                        vfe_base_s[vfe_sp] <= vfe_base;
                                        vfe_sp <= vfe_sp + 4'd1;
                                        vfe_arr <= receiver;
                                        vfe_fn <= (argc != 0)
                                            ? vstack[vsp - 12'd1]
                                            : V64_UNDEFINED;
                                        vfe_i <= 8'd0;
                                        vfe_ret <= ip + 16'd1;
                                        vfe_base <= base;
                                        vnat_base <= base;
                                        state <= S_V64_FOREACH;
                                    end
                                end else if (code_rdata[23:8] == id_getctx) begin
                                    vnat_dom <= 3'd3;
                                    vnat_base <= base;
                                    valloc_kind <= 2'd0;
                                    valloc_i <= vobj_next;
                                    valloc_retried <= 1'b0;
                                    state <= S_V64_ALLOC;
                                end else if (obj_ok && argc >= 12'd4 &&
                                           (code_rdata[23:8] == id_fillrect ||
                                            code_rdata[23:8] == id_clearrect)) begin
                                    if (code_rdata[23:8] != id_clearrect)
                                        for (int k = 0; k < OBJ_SLOTS; k++)
                                            if (k < vobj_len[receiver[12:0]] &&
                                                vobj_key[receiver[12:0]][k] ==
                                                    id_fillstyle) begin
                                                if (v64_is_number(
                                                        vobj_val[receiver[12:0]][k]))
                                                    paint_color = v64_to_uint32(
                                                        vobj_val[receiver[12:0]][k]
                                                    )[7:0];
                                                else if (
                                                    vobj_val[receiver[12:0]][k][15:0]
                                                        < 16'd1024 &&
                                                    fill_lut[vobj_val[receiver[12:0]][k][9:0]]
                                                        != 8'hFF)
                                                    paint_color = fill_lut[
                                                        vobj_val[receiver[12:0]][k][9:0]
                                                    ];
                                                else
                                                    paint_color = fill_style_i;
                                            end
                                    vdraw_x <= v64_to_uint32(vstack[base + 1])[9:0];
                                    vdraw_y <= v64_to_uint32(vstack[base + 2])[9:0];
                                    vdraw_w <= v64_to_uint32(vstack[base + 3])[9:0];
                                    vdraw_h <= v64_to_uint32(vstack[base + 4])[9:0];
                                    vdraw_color <= (code_rdata[23:8] == id_clearrect)
                                        ? 8'd0 : paint_color;
                                    vdraw_i <= 19'd0;
                                    vnat_base <= base;
                                    state <= S_V64_RECT;
                                end else if (obj_ok && argc >= 12'd3 &&
                                           code_rdata[23:8] == id_filltext) begin
                                    // Reuse S_TXT_LD / S_TXT_DRAW (same glyphs as
                                    // the tagged VM). Interned text + fill_style_i.
                                    color <= fill_style_i;
                                    if (vstack[base + 1][63:48] == V64_TAG_PREFIX &&
                                        vstack[base + 1][47:44] == 4'd4)
                                        begin
                                            txt_val <= {16'd0, vstack[base + 1][15:0]};
                                            txt_vt <= 3'd3;
                                        end
                                    else begin
                                        txt_val <= 32'd0;
                                        txt_vt <= 3'd5;
                                    end
                                    txt_ph <= 4'd0;
                                    txt_px <= $signed(
                                        v64_to_uint32(vstack[base + 2])[15:0]
                                    );
                                    txt_py <= $signed(
                                        v64_to_uint32(vstack[base + 3])[15:0]
                                    );
                                    vstack[base] <= V64_UNDEFINED;
                                    vsp <= base + 12'd1;
                                    ip <= ip + 16'd1;
                                    state <= S_TXT_LD;
                                end else if (arr_ok &&
                                           code_rdata[23:8] == id_splice) begin
                                    logic [7:0] st, cnt, al;
                                    al = varr_len[receiver[11:0]];
                                    st = (argc >= 12'd1)
                                        ? v64_to_uint32(vstack[base + 1])[7:0]
                                        : 8'd0;
                                    cnt = (argc >= 12'd2)
                                        ? v64_to_uint32(vstack[base + 2])[7:0]
                                        : 8'd1;
                                    if (st < al) begin
                                        for (int j = 0; j < ARR_CAP - 1; j++)
                                            if (j >= st && (j + cnt) < ARR_CAP)
                                                varr_val[receiver[11:0]][j] <=
                                                    varr_val[receiver[11:0]]
                                                            [j + cnt];
                                        varr_len[receiver[11:0]] <=
                                            (al > cnt) ? (al - cnt) : 8'd0;
                                    end
                                    vstack[base] <= V64_UNDEFINED;
                                    vsp <= base + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (code_rdata[23:8] == id_ael) begin
                                    ev = (argc != 0) ? vstack[base + 1]
                                        : V64_UNDEFINED;
                                    fn = (argc > 1) ? vstack[base + 2]
                                        : V64_UNDEFINED;
                                    for (int k = 0; k < 16; k++)
                                        if (k < vlistener_n) begin
                                            if (v64_equal(vlistener_ev[k], ev) &&
                                                v64_equal(vlistener_fn[k], fn))
                                                dup = 1'b1;
                                            if (v64_equal(vlistener_ev[k], ev))
                                                same_n = same_n + 5'd1;
                                        end
                                    if (fn[63:48] != 16'h7ff9 ||
                                        fn[47:44] != 4'd7) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd4;
                                        running <= 1'b0; state <= S_DONE;
                                    end else if (!dup && same_n >= 5'd4) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end else if (!dup && vlistener_n >= 5'd16) begin
                                        machine_fault <= 1'b1;
                                        fault_code <= 8'd3;
                                        running <= 1'b0; state <= S_DONE;
                                    end else begin
                                        if (!dup) begin
                                            vlistener_ev[vlistener_n] <= ev;
                                            vlistener_fn[vlistener_n] <= fn;
                                            vlistener_n <= vlistener_n + 5'd1;
                                        end
                                        vstack[base] <= V64_UNDEFINED;
                                        vsp <= base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end else if (obj_ok) begin
                                    for (int c = 0; c < MAX_CLS; c++)
                                        if (c < n_cls &&
                                            cls_name[c] ==
                                                vobj_cls[receiver[12:0]])
                                            for (int m = 0; m < MAX_CMETH; m++)
                                                if (m < cls_nmeth[c] &&
                                                    cls_mname[c][m] ==
                                                        code_rdata[23:8])
                                                    mip = cls_mip[c][m];
                                    if (mip != 16'hFFFF) begin
                                        for (int k = 0; k < 64; k++)
                                            if (k < argc)
                                                vstack[base + k] <=
                                                    vstack[base + k + 12'd1];
                                        vsp <= vsp - 12'd1;
                                        vcall_value <= 1'b0;
                                        vcall_entry <= mip;
                                        vcall_argc <= argc;
                                        vcall_set_this <= 1'b1;
                                        vcall_this <= receiver;
                                        vcall_ctor_val <= V64_UNDEFINED;
                                        valloc_kind <= 2'd3;
                                        valloc_i <= venv_next;
                                        valloc_retried <= 1'b0;
                                        state <= S_V64_ALLOC;
                                    end else begin
                                        // Unknown method on ELEMENT/CONTEXT
                                        // returns the receiver (play().catch()).
                                        // RegExp.test stub is false (not iOS).
                                        vstack[base] <=
                                            (vobj_builtin[receiver[12:0]] == 4'd6)
                                            ? v64_handle(4'd3, 12'd0, 32'd0)
                                            : (vobj_builtin[receiver[12:0]] != 4'd0)
                                            ? receiver : V64_UNDEFINED;
                                        vsp <= base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end
                                end else begin
                                    vstack[base] <= V64_UNDEFINED;
                                    vsp <= base + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_ADD, OP_SUB, OP_MUL: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[7:0] == OP_ADD &&
                                    ((vstack[vsp - 12'd2][63:48] == V64_TAG_PREFIX &&
                                      vstack[vsp - 12'd2][47:44] == 4'd4) ||
                                     (vstack[vsp - 12'd1][63:48] == V64_TAG_PREFIX &&
                                      vstack[vsp - 12'd1][47:44] == 4'd4))) begin
                                    // PYTHON: string + ToString(other). Reuse
                                    // tagged S_CONCAT intern find-or-alloc.
                                    cc_av <= (vstack[vsp - 12'd2][63:48] ==
                                              V64_TAG_PREFIX &&
                                              vstack[vsp - 12'd2][47:44] == 4'd4)
                                        ? $signed({16'd0, vstack[vsp - 12'd2][15:0]})
                                        : $signed(v64_to_uint32(vstack[vsp - 12'd2]));
                                    cc_at <= (vstack[vsp - 12'd2][63:48] ==
                                              V64_TAG_PREFIX &&
                                              vstack[vsp - 12'd2][47:44] == 4'd4)
                                        ? 3'd3 : 3'd0;
                                    cc_bv <= (vstack[vsp - 12'd1][63:48] ==
                                              V64_TAG_PREFIX &&
                                              vstack[vsp - 12'd1][47:44] == 4'd4)
                                        ? $signed({16'd0, vstack[vsp - 12'd1][15:0]})
                                        : $signed(v64_to_uint32(vstack[vsp - 12'd1]));
                                    cc_bt <= (vstack[vsp - 12'd1][63:48] ==
                                              V64_TAG_PREFIX &&
                                              vstack[vsp - 12'd1][47:44] == 4'd4)
                                        ? 3'd3 : 3'd0;
                                    cc_second <= 1'b0; cc_st <= 2'd0;
                                    cc_h <= 16'd0; cc_len <= 8'd0; cc_d <= 4'd0;
                                    cc_bok <= 1'b1; txt_bn <= 7'd0;
                                    v64_concat <= 1'b1;
                                    jn_res <= 11'(vsp - 12'd2);
                                    vsp <= vsp - 12'd1;
                                    ip <= ip + 16'd1;
                                    state <= S_CONCAT;
                                end else if (!v64_is_number(vstack[vsp - 12'd2]) ||
                                             !v64_is_number(vstack[vsp - 12'd1])) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] arithmetic_result;
                                    if (code_rdata[7:0] == OP_ADD)
                                        v64_add_task(vstack[vsp - 12'd2],
                                                     vstack[vsp - 12'd1],
                                                     arithmetic_result);
                                    else if (code_rdata[7:0] == OP_SUB)
                                        v64_add_task(vstack[vsp - 12'd2],
                                                     {~vstack[vsp - 12'd1][63],
                                                      vstack[vsp - 12'd1][62:0]},
                                                     arithmetic_result);
                                    else
                                        v64_mul_task(vstack[vsp - 12'd2],
                                                     vstack[vsp - 12'd1],
                                                     arithmetic_result);
                                    vstack[vsp - 12'd2] <= arithmetic_result;
                                    vsp <= vsp - 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_DIV: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (!v64_is_number(vstack[vsp - 12'd2]) ||
                                             !v64_is_number(vstack[vsp - 12'd1])) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] aa, bb, immediate_result;
                                    logic [52:0] ma, mb, na, nb;
                                    logic [5:0] sha, shb;
                                    logic immediate;
                                    aa = vstack[vsp - 12'd2];
                                    bb = vstack[vsp - 12'd1];
                                    immediate = 1'b1;
                                    immediate_result = V64_CANON_NAN;
                                    if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
                                        (bb[62:52] == 11'h7ff && bb[51:0] != 0) ||
                                        ((aa[62:0] == 0 && bb[62:0] == 0)) ||
                                        (aa[62:52] == 11'h7ff &&
                                         bb[62:52] == 11'h7ff)) begin
                                        immediate_result = V64_CANON_NAN;
                                    end else if (aa[62:52] == 11'h7ff ||
                                                 bb[62:0] == 0) begin
                                        immediate_result =
                                            {aa[63] ^ bb[63], 11'h7ff, 52'd0};
                                    end else if (aa[62:0] == 0 ||
                                                 bb[62:52] == 11'h7ff) begin
                                        immediate_result =
                                            {aa[63] ^ bb[63], 63'd0};
                                    end else begin
                                        immediate = 1'b0;
                                        ma = {(aa[62:52] != 0), aa[51:0]};
                                        mb = {(bb[62:52] != 0), bb[51:0]};
                                        sha = v64_norm_shift(ma);
                                        shb = v64_norm_shift(mb);
                                        na = ma << sha;
                                        nb = mb << shb;
                                        vdiv_num <= {na, 54'd0};
                                        vdiv_den <= nb;
                                        vdiv_rem <= 54'd0;
                                        vdiv_quot <= 107'd0;
                                        vdiv_count <= 8'd107;
                                        vdiv_exp <=
                                            v64_unbiased_exp(aa[62:52], sha)
                                          - v64_unbiased_exp(bb[62:52], shb);
                                        vdiv_sign <= aa[63] ^ bb[63];
                                    end
                                    if (immediate) begin
                                        vstack[vsp - 12'd2] <= immediate_result;
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        state <= S_V64_DIV;
                                    end
                                end
                            end
                            OP_MOD: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (!v64_is_number(vstack[vsp - 12'd2]) ||
                                             !v64_is_number(vstack[vsp - 12'd1])) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [63:0] aa, bb, immediate_result;
                                    logic [52:0] ma, mb, na, nb, initial_rem;
                                    logic [5:0] sha, shb;
                                    logic signed [12:0] ea, eb;
                                    logic immediate;
                                    integer distance;
                                    aa = vstack[vsp - 12'd2];
                                    bb = vstack[vsp - 12'd1];
                                    immediate = 1'b1;
                                    immediate_result = V64_CANON_NAN;
                                    if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
                                        (bb[62:52] == 11'h7ff && bb[51:0] != 0) ||
                                        aa[62:52] == 11'h7ff ||
                                        bb[62:0] == 0) begin
                                        immediate_result = V64_CANON_NAN;
                                    end else if (aa[62:0] == 0 ||
                                                 bb[62:52] == 11'h7ff) begin
                                        immediate_result = aa;
                                    end else begin
                                        ma = {(aa[62:52] != 0), aa[51:0]};
                                        mb = {(bb[62:52] != 0), bb[51:0]};
                                        sha = v64_norm_shift(ma);
                                        shb = v64_norm_shift(mb);
                                        na = ma << sha;
                                        nb = mb << shb;
                                        ea = v64_unbiased_exp(aa[62:52], sha);
                                        eb = v64_unbiased_exp(bb[62:52], shb);
                                        if (ea < eb || (ea == eb && na < nb)) begin
                                            immediate_result = aa;
                                        end else begin
                                            initial_rem = (na >= nb) ? na - nb : na;
                                            distance = ea - eb;
                                            if (distance == 0) begin
                                                v64_mod_pack_task(
                                                    aa[63], eb, initial_rem,
                                                    immediate_result
                                                );
                                            end else begin
                                                immediate = 1'b0;
                                                vmod_rem <= initial_rem;
                                                vmod_den <= nb;
                                                vmod_count <= 12'(distance);
                                                vmod_exp <= eb;
                                                vmod_sign <= aa[63];
                                            end
                                        end
                                    end
                                    if (immediate) begin
                                        vstack[vsp - 12'd2] <= immediate_result;
                                        vsp <= vsp - 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        state <= S_V64_MOD;
                                    end
                                end
                            end
                            OP_BIT_OR, OP_BIT_AND: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    logic [31:0] left_int, right_int, bit_result;
                                    // ToInt32: BOOL true|false, not a Number-only fault
                                    left_int = v64_to_int32(vstack[vsp - 12'd2]);
                                    right_int = v64_to_int32(vstack[vsp - 12'd1]);
                                    bit_result = (code_rdata[7:0] == OP_BIT_OR)
                                               ? left_int | right_int
                                               : left_int & right_int;
                                    vstack[vsp - 12'd2] <=
                                        v64_int32_number(bit_result);
                                    vsp <= vsp - 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_LT, OP_GT, OP_EQ: begin
                                if (vsp < 12'd2) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[7:0] != OP_EQ &&
                                             (!v64_is_number(vstack[vsp - 12'd2]) ||
                                              !v64_is_number(vstack[vsp - 12'd1]))) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vstack[vsp - 12'd2] <=
                                        {16'h7ff9, 4'd3, 12'd0, 31'd0,
                                         (code_rdata[7:0] == OP_EQ)
                                         ? v64_equal(vstack[vsp - 12'd2],
                                                     vstack[vsp - 12'd1])
                                         : (code_rdata[7:0] == OP_LT)
                                         ? v64_less(vstack[vsp - 12'd2],
                                                    vstack[vsp - 12'd1])
                                         : v64_less(vstack[vsp - 12'd1],
                                                    vstack[vsp - 12'd2])};
                                    vsp <= vsp - 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_JUMP: begin
                                if (code_rdata[23:8] > n_ops) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    ip <= code_rdata[23:8];
                                    code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_JIF: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[23:8] > n_ops) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vsp <= vsp - 12'd1;
                                    if (!v64_truthy(vstack[vsp - 12'd1])) begin
                                        ip <= code_rdata[23:8];
                                        code_raddr <= 15'(ops_base + code_rdata[23:8]);
                                    end else begin
                                        ip <= ip + 16'd1;
                                        code_raddr <= 15'(ops_base + ip + 16'd1);
                                    end
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_POP: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vsp <= vsp - 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_DUP: begin
                                if (vsp == 0 || vsp >= 12'(STACK_DEPTH)) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    vstack[vsp] <= vstack[vsp - 12'd1];
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_NEG, OP_NOT: begin
                                if (vsp == 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0; state <= S_DONE;
                                end else if (code_rdata[7:0] == OP_NEG &&
                                             !v64_is_number(vstack[vsp - 12'd1])) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd5;
                                    running <= 1'b0; state <= S_DONE;
                                end else begin
                                    if (code_rdata[7:0] == OP_NEG)
                                        vstack[vsp - 12'd1] <=
                                            (vstack[vsp - 12'd1][62:52] == 11'h7ff &&
                                             vstack[vsp - 12'd1][51:0] != 0)
                                            ? V64_CANON_NAN
                                            : {~vstack[vsp - 12'd1][63],
                                               vstack[vsp - 12'd1][62:0]};
                                    else
                                        vstack[vsp - 12'd1] <=
                                            {16'h7ff9, 4'd3, 12'd0, 31'd0,
                                             !v64_truthy(vstack[vsp - 12'd1])};
                                    ip <= ip + 16'd1;
                                    code_raddr <= 15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end
                            end
                            OP_RETURN: begin
                                if (vsp != 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd1;
                                    running <= 1'b0;
                                    state <= S_DONE;
                                end else if (vcsp != 0) begin
                                    machine_fault <= 1'b1; fault_code <= 8'd2;
                                    running <= 1'b0;
                                    state <= S_DONE;
                                end else begin
                                    vgc_clear_i <= 14'd0;
                                    vgc_qr <= 14'd0;
                                    vgc_qw <= 14'd0;
                                    vgc_halt_after <= 1'b1;
                                    vgc_wait_after <=
                                        (vraf_n != 0 || vtimer_n != 0);
                                    state <= S_V64_GC_CLEAR;
                                end
                            end
                            default: begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd5;
                                running <= 1'b0;
                                state <= S_DONE;
                            end
                        endcase
                    end
                end
                S_V64_ALLOC: begin
                    if (valloc_kind == 2'd1) begin
                        if (valloc_i < MAX_ARR &&
                            !varr_valid[valloc_i[11:0]]) begin
                            logic [15:0] count;
                            count = (vnat_dom == 3'd7) ? 16'd0 : code_rdata[23:8];
                            varr_valid[valloc_i[11:0]] <= 1'b1;
                            varr_len[valloc_i[11:0]] <= count[7:0];
                            varr_next <= valloc_i + 14'd1;
                            for (int k = 0; k < ARR_CAP; k++)
                                if (k < count)
                                    varr_val[valloc_i[11:0]][k] <=
                                        vstack[vsp - count + k];
                            if (vnat_dom == 3'd7) begin
                                vstack[vnat_base] <= v64_handle(
                                    4'd6, varr_gen[valloc_i[11:0]],
                                    {20'd0, valloc_i[11:0]}
                                );
                                vsp <= vnat_base + 12'd1;
                                vnat_dom <= 3'd0;
                            end else begin
                                vstack[vsp - count] <= v64_handle(
                                    4'd6, varr_gen[valloc_i[11:0]],
                                    {20'd0, valloc_i[11:0]}
                                );
                                vsp <= vsp - count + 12'd1;
                            end
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
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
                            !venv_valid[valloc_i[4:0]]) begin
                            logic [11:0] base_sp;
                            logic [7:0] nparam;
                            logic [63:0] function_handle, parent_env;
                            base_sp = vsp - vcall_argc -
                                      (vcall_value ? 12'd1 : 12'd0);
                            function_handle = vcall_value
                                ? vstack[vsp - vcall_argc - 12'd1]
                                : V64_UNDEFINED;
                            parent_env = vcall_value
                                ? vfn_env[function_handle[12:0]] : venv;
                            nparam = vcall_value
                                ? {2'd0, vfn_nparam[function_handle[12:0]]}
                                : vcall_argc;
                            venv_valid[valloc_i[4:0]] <= 1'b1;
                            venv_len[valloc_i[4:0]] <= 5'd0;
                            venv_parent[valloc_i[4:0]] <= parent_env;
                            venv_next <= valloc_i[5:0] + 6'd1;
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
                            vcsp <= vcsp + 8'd1;
                            vcallback_raf <= 1'b0;
                            vcallback_timer <= 1'b0;
                            vcallback_key <= 1'b0;
                            vcallback_fe <= 1'b0;
                            venv <= v64_handle(
                                4'd9, venv_gen[valloc_i[4:0]],
                                {27'd0, valloc_i[4:0]}
                            );
                            if (vcall_value) begin
                                vthis <= vfn_flags[function_handle[12:0]][0] ||
                                         vfn_flags[function_handle[12:0]][2]
                                       ? vfn_bound_this[function_handle[12:0]]
                                       : V64_UNDEFINED;
                                for (int k = 0; k < 64; k++)
                                    if (k < nparam)
                                        vstack[base_sp + k] <=
                                            (k < vcall_argc)
                                            ? vstack[vsp - vcall_argc + k]
                                            : V64_UNDEFINED;
                                vsp <= base_sp + nparam;
                                ip <= vfn_entry[function_handle[12:0]];
                                code_raddr <= 15'(
                                    ops_base + vfn_entry[function_handle[12:0]]
                                );
                            end else begin
                                vthis <= vcall_set_this
                                       ? vcall_this : V64_UNDEFINED;
                                ip <= vcall_entry;
                                code_raddr <= 15'(ops_base + vcall_entry);
                            end
                            vcall_set_this <= 1'b0;
                            vcall_ctor_val <= V64_UNDEFINED;
                            state <= S_FETCH_WAIT;
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
                    end else begin
                        if (valloc_i < MAX_OBJ &&
                            vobj_alloc[valloc_i[12:0]] == 0) begin
                            vobj_next <= valloc_i + 14'd1;
                            if (valloc_kind == 2'd2) begin
                                vobj_alloc[valloc_i[12:0]] <= 2'd2;
                                if (valloc_now_fn) begin
                                    vfn_entry[valloc_i[12:0]] <= 16'hfffa;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd0;
                                    vfn_env[valloc_i[12:0]] <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'd0;
                                    vfn_bound_this[valloc_i[12:0]] <=
                                        V64_UNDEFINED;
                                    vstack[vnat_base] <= v64_handle(
                                        4'd7, vfn_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    vsp <= vnat_base + 12'd1;
                                    valloc_now_fn <= 1'b0;
                                end else begin
                                    vfn_entry[valloc_i[12:0]] <= code_rdata[23:8];
                                    vfn_nparam[valloc_i[12:0]] <= code_rdata[29:24];
                                    vfn_env[valloc_i[12:0]] <= venv;
                                    // [2]=arrow [1]=IIFE (JSB a1 bit6) [0]=arrow
                                    // this-bind. CALL_VAL reads [1] for flat IIFE.
                                    vfn_flags[valloc_i[12:0]] <=
                                        {code_rdata[31], code_rdata[30],
                                         code_rdata[31]};
                                    vfn_bound_this[valloc_i[12:0]] <=
                                        code_rdata[31] ? vthis : V64_UNDEFINED;
                                    vstack[vsp] <= v64_handle(
                                        4'd7, vfn_gen[valloc_i[12:0]],
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    vsp <= vsp + 12'd1;
                                end
                                ip <= ip + 16'd1;
                                code_raddr <= 15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end else if (code_rdata[7:0] == OP_NEW_OBJ) begin
                                logic [15:0] ctor_ip;
                                logic [63:0] handle;
                                logic [11:0] argc;
                                ctor_ip = 16'hFFFF;
                                argc = {4'd0, code_rdata[31:24]};
                                handle = v64_handle(
                                    4'd5, vobj_gen[valloc_i[12:0]],
                                    {19'd0, valloc_i[12:0]}
                                );
                                vobj_alloc[valloc_i[12:0]] <= 2'd1;
                                vobj_len[valloc_i[12:0]] <= 6'd0;
                                vobj_cls[valloc_i[12:0]] <= code_rdata[23:8];
                                vobj_builtin[valloc_i[12:0]] <= 4'd0;
                                for (int c = 0; c < MAX_CLS; c++)
                                    if (c < n_cls &&
                                        cls_name[c] == code_rdata[23:8])
                                        ctor_ip = cls_ctor[c];
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
                                        valloc_i <= {8'd0, venv_next};
                                        valloc_retried <= 1'b0;
                                    end
                                end else begin
                                    // Ctor-less NEW_OBJ: drop args, push the
                                    // instance (PYTHON constructor_ip None).
                                    vstack[vsp - argc] <= handle;
                                    vsp <= vsp - argc + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
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
                                if (vnat_dom == 3'd1) begin
                                    // querySelector style object
                                    vobj_builtin[valloc_i[12:0]] <= 4'd1;
                                    vnat_style <= handle;
                                    vnat_dom <= 3'd2;
                                    valloc_i <= valloc_i + 14'd1;
                                end else if (vnat_dom == 3'd2) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd1;
                                    vobj_len[valloc_i[12:0]] <= 6'd3;
                                    vobj_key[valloc_i[12:0]][0] <= id_style;
                                    vobj_val[valloc_i[12:0]][0] <= vnat_style;
                                    vobj_key[valloc_i[12:0]][1] <= id_width;
                                    vobj_val[valloc_i[12:0]][1] <=
                                        v64_int32_number(32'd640);
                                    vobj_key[valloc_i[12:0]][2] <= id_height;
                                    vobj_val[valloc_i[12:0]][2] <=
                                        v64_int32_number(32'd480);
                                    vstack[vnat_base] <= handle;
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (vnat_dom == 3'd3) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd5;
                                    vstack[vnat_base] <= handle;
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else if (vnat_dom == 3'd4) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd2;
                                    vobj_len[valloc_i[12:0]] <= 6'd2;
                                    vobj_key[valloc_i[12:0]][0] <= id_width;
                                    vobj_val[valloc_i[12:0]][0] <=
                                        v64_int32_number(32'd1);
                                    vobj_key[valloc_i[12:0]][1] <= id_height;
                                    vobj_val[valloc_i[12:0]][1] <=
                                        v64_int32_number(32'd1);
                                    vstack[vnat_base] <= handle;
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
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
                                    vobj_len[valloc_i[12:0]] <= 6'd3;
                                    vobj_key[valloc_i[12:0]][0] <= id_type;
                                    vobj_val[valloc_i[12:0]][0] <= v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, kev_q[kev_rp][8]
                                            ? id_keydown : id_keyup}
                                    );
                                    vobj_key[valloc_i[12:0]][1] <= id_key;
                                    vobj_val[valloc_i[12:0]][1] <=
                                        (key_intern == 16'hFFFF)
                                        ? V64_UNDEFINED
                                        : v64_handle(4'd4, 12'd0,
                                                     {16'd0, key_intern});
                                    vobj_key[valloc_i[12:0]][2] <= id_keycode;
                                    vobj_val[valloc_i[12:0]][2] <=
                                        v64_int32_number(
                                            {24'd0, kev_q[kev_rp][7:0]}
                                        );
                                    vkev_event <= handle;
                                    vnat_dom <= 3'd0;
                                    vkey_li <= 5'd0;
                                    state <= S_V64_FRAME_KEY;
                                end else if (vnat_dom == 3'd6) begin
                                    vobj_builtin[valloc_i[12:0]] <= 4'd3;
                                    vstack[vnat_base] <= handle;
                                    vsp <= vnat_base + 12'd1;
                                    vnat_dom <= 3'd0;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
                                end else begin
                                    if (valloc_regex) begin
                                        vobj_builtin[valloc_i[12:0]] <= 4'd6;
                                        valloc_regex <= 1'b0;
                                    end
                                    vstack[vsp] <= handle;
                                    vsp <= vsp + 12'd1;
                                    ip <= ip + 16'd1;
                                    code_raddr <=
                                        15'(ops_base + ip + 16'd1);
                                    state <= S_FETCH_WAIT;
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
                    if (vgc_clear_i < MAX_OBJ)
                        vobj_mark[vgc_clear_i[12:0]] <= 1'b0;
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
                            if (vgc_root_i < vsp) begin
                                v64_gc_mark_task(vstack[vgc_root_i]);
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
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
                                state <= S_V64_GC_POP;
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
                        if (vgc_queue[vgc_qr][47:44] == 4'd5)
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
                        v64_gc_mark_task(
                            vobj_val[vgc_cur[12:0]][vgc_slot_i[4:0]]
                        );
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_ARR: begin
                    if (vgc_slot_i < varr_len[vgc_cur[11:0]]) begin
                        v64_gc_mark_task(
                            varr_val[vgc_cur[11:0]][vgc_slot_i[6:0]]
                        );
                        vgc_slot_i <= vgc_slot_i + 8'd1;
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
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_ENV: begin
                    if (vgc_slot_i == 0) begin
                        v64_gc_mark_task(venv_parent[vgc_cur[4:0]]);
                        vgc_slot_i <= 8'd1;
                    end else if (vgc_slot_i <= venv_len[vgc_cur[4:0]]) begin
                        v64_gc_mark_task(
                            venv_val[vgc_cur[4:0]][vgc_slot_i - 8'd1]
                        );
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                    end else
                        state <= S_V64_GC_POP;
                end
                S_V64_GC_SWEEP_OBJ: begin
                    if (vobj_alloc[vgc_obj_i] != 0 &&
                        !vobj_mark[vgc_obj_i]) begin
                        vobj_alloc[vgc_obj_i] <= 2'd0;
                        vobj_len[vgc_obj_i] <= 6'd0;
                        if (vobj_alloc[vgc_obj_i] == 2'd2)
                            vfn_gen[vgc_obj_i] <=
                                (vfn_gen[vgc_obj_i] == 12'hfff)
                                ? 12'd1 : vfn_gen[vgc_obj_i] + 12'd1;
                        else
                            vobj_gen[vgc_obj_i] <=
                                (vobj_gen[vgc_obj_i] == 12'hfff)
                                ? 12'd1 : vobj_gen[vgc_obj_i] + 12'd1;
                    end
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
                        varr_gen[vgc_arr_i] <=
                            (varr_gen[vgc_arr_i] == 12'hfff)
                            ? 12'd1 : varr_gen[vgc_arr_i] + 12'd1;
                    end
                    if (vgc_arr_i + 12'd1 >= MAX_ARR) begin
                        vgc_env_i <= 6'd0;
                        state <= S_V64_GC_SWEEP_ENV;
                    end else
                        vgc_arr_i <= vgc_arr_i + 12'd1;
                end
                S_V64_GC_SWEEP_ENV: begin
                    if (venv_valid[vgc_env_i] &&
                        !venv_mark[vgc_env_i]) begin
                        venv_valid[vgc_env_i] <= 1'b0;
                        venv_len[vgc_env_i] <= 5'd0;
                        venv_gen[vgc_env_i] <=
                            (venv_gen[vgc_env_i] == 12'hfff)
                            ? 12'd1 : venv_gen[vgc_env_i] + 12'd1;
                    end
                    if (vgc_env_i + 6'd1 >= ENV_DEPTH) begin
                        if (vgc_halt_after) begin
                            if (vgc_wait_after) begin
                                vgc_wait_after <= 1'b0;
                                state <= S_WAIT_FRAME;
                            end else begin
                                running <= 1'b0;
                                state <= S_DONE;
                            end
                        end else begin
                            valloc_i <= 14'd0;
                            if (valloc_kind == 2'd1)
                                varr_next <= 14'd0;
                            else if (valloc_kind == 2'd3)
                                venv_next <= 6'd0;
                            else
                                vobj_next <= 14'd0;
                            valloc_retried <= 1'b1;
                            state <= S_V64_ALLOC;
                        end
                    end else
                        vgc_env_i <= vgc_env_i + 6'd1;
                end
                S_V64_CLEAR: begin
                    fb_we <= 1'b1;
                    fb_waddr <= vdraw_i;
                    fb_wdata <= vdraw_color;
                    if (vdraw_i + 19'd1 >= FB_PIXELS) begin
                        vstack[vnat_base] <= V64_UNDEFINED;
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
                    px = vdraw_x;
                    py = vdraw_y;
                    if (vdraw_w == 0 || vdraw_h == 0) begin
                        vstack[vnat_base] <= V64_UNDEFINED;
                        vsp <= vnat_base + 12'd1;
                        ip <= ip + 16'd1;
                        code_raddr <= 15'(ops_base + ip + 16'd1);
                        state <= S_FETCH_WAIT;
                    end else begin
                        px = vdraw_x + 10'(vdraw_i % vdraw_w);
                        py = vdraw_y + 10'(vdraw_i / vdraw_w);
                        if (px < MW && py < MH) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(py) * 19'(MW) + 19'(px);
                            fb_wdata <= vdraw_color;
                        end
                        if (vdraw_i + 19'd1 >= total) begin
                            vstack[vnat_base] <= V64_UNDEFINED;
                            vsp <= vnat_base + 12'd1;
                            ip <= ip + 16'd1;
                            code_raddr <= 15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else
                            vdraw_i <= vdraw_i + 19'd1;
                    end
                end
                S_V64_WAIT_FRAME: state <= S_WAIT_FRAME;
                S_V64_FOREACH: begin
                    if (vfe_arr[63:48] != V64_TAG_PREFIX ||
                        vfe_arr[47:44] != V64_KIND_ARRAY ||
                        !varr_valid[vfe_arr[11:0]] ||
                        vfe_i >= varr_len[vfe_arr[11:0]]) begin
                        vstack[vfe_base] <= V64_UNDEFINED;
                        vsp <= vfe_base + 12'd1;
                        ip <= vfe_ret;
                        code_raddr <= 15'(ops_base + vfe_ret);
                        if (vfe_sp != 4'd0) begin
                            vfe_arr <= vfe_arr_s[vfe_sp - 4'd1];
                            vfe_fn <= vfe_fn_s[vfe_sp - 4'd1];
                            vfe_i <= vfe_i_s[vfe_sp - 4'd1];
                            vfe_ret <= vfe_ret_s[vfe_sp - 4'd1];
                            vfe_base <= vfe_base_s[vfe_sp - 4'd1];
                            vfe_sp <= vfe_sp - 4'd1;
                        end else begin
                            vfe_arr <= V64_UNDEFINED;
                            vfe_fn <= V64_UNDEFINED;
                        end
                        state <= S_FETCH_WAIT;
                    end else if (vfe_fn[63:48] != V64_TAG_PREFIX ||
                                 vfe_fn[47:44] != V64_KIND_FUNCTION) begin
                        machine_fault <= 1'b1; fault_code <= 8'd4;
                        running <= 1'b0; state <= S_DONE;
                    end else if (vcsp >= CSTK || vsp + 12'd4 > STACK_DEPTH) begin
                        machine_fault <= 1'b1;
                        fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                        running <= 1'b0; state <= S_DONE;
                    end else begin
                        vstack[vsp] <= vfe_fn;
                        vstack[vsp + 12'd1] <=
                            varr_val[vfe_arr[11:0]][vfe_i];
                        vstack[vsp + 12'd2] <=
                            v64_int32_number({24'd0, vfe_i});
                        vstack[vsp + 12'd3] <= vfe_arr;
                        vsp <= vsp + 12'd4;
                        vcall_value <= 1'b1;
                        vcall_argc <= 12'd3;
                        vcallback_fe <= 1'b1;
                        valloc_kind <= 2'd3;
                        valloc_i <= venv_next;
                        valloc_retried <= 1'b0;
                        vfe_i <= vfe_i + 8'd1;
                        state <= S_V64_ALLOC;
                    end
                end
                S_V64_STRIDX: state <= S_V64_STRIDX_WR;
                S_V64_STRIDX_WR: begin
                    if (char_ok[name_rdata])
                        vstack[vsp - 12'd1] <= v64_handle(
                            4'd4, 12'd0, {16'd0, char_id[name_rdata]}
                        );
                    else
                        vstack[vsp - 12'd1] <= V64_UNDEFINED;
                    code_raddr <= 15'(ops_base + ip);
                    state <= S_FETCH_WAIT;
                end
                S_V64_JSON: begin
                    // Walk nested Value64 arrays/numbers into json_mem.
                    if (js_sp == 6'd0) begin
                        if (vobj_next < MAX_OBJ &&
                            vobj_alloc[vobj_next[12:0]] == 2'd0) begin
                            vobj_alloc[vobj_next[12:0]] <= 2'd1;
                            vobj_builtin[vobj_next[12:0]] <= 4'd7;
                            vobj_len[vobj_next[12:0]] <= 6'd2;
                            vobj_key[vobj_next[12:0]][0] <= 16'd0;
                            vobj_val[vobj_next[12:0]][0] <=
                                v64_int32_number(32'd0);
                            vobj_key[vobj_next[12:0]][1] <= 16'd1;
                            vobj_val[vobj_next[12:0]][1] <=
                                v64_int32_number({18'd0, json_wp});
                            vstack[vnat_base] <= v64_handle(
                                4'd5, vobj_gen[vobj_next[12:0]],
                                {19'd0, vobj_next[12:0]}
                            );
                            vsp <= vnat_base + 12'd1;
                            vobj_next <= vobj_next + 14'd1;
                            ip <= ip + 16'd1;
                            code_raddr <=
                                15'(ops_base + ip + 16'd1);
                            state <= S_FETCH_WAIT;
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; state <= S_DONE;
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
                            end else if (ii != 8'd0) begin
                                json_putc(8'h2C);
                                js_ph[t] <= 3'd2;
                            end else if (js_sp < JSON_STK[5:0]) begin
                                vjs_val[js_sp] <= varr_val[ai][ii[6:0]];
                                js_i[js_sp] <= 8'd0;
                                js_ph[js_sp] <= 3'd0;
                                js_i[t] <= ii + 8'd1;
                                js_sp <= js_sp + 6'd1;
                            end else begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                js_sp <= t;
                            end
                        end else if (ph == 3'd2) begin
                            if (js_sp < JSON_STK[5:0]) begin
                                vjs_val[js_sp] <= varr_val[ai][ii[6:0]];
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
                        end else js_sp <= t;
                    end
                end
                S_V64_JSON_PARSE: begin
                    if (json_rp >= json_src + json_srclen) begin
                        vstack[vnat_base] <= (js_sp == 0)
                            ? V64_NULL : vjs_val[0];
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
                                        vstack[vnat_base] <= nv;
                                        vsp <= vnat_base + 12'd1;
                                        ip <= ip + 16'd1;
                                        code_raddr <=
                                            15'(ops_base + ip + 16'd1);
                                        state <= S_FETCH_WAIT;
                                    end else begin
                                        logic [5:0] p;
                                        p = js_sp - 6'd1;
                                        varr_val[vjs_val[p][11:0]][js_i[p][6:0]]
                                            <= nv;
                                        varr_len[vjs_val[p][11:0]] <=
                                            js_i[p] + 8'd1;
                                        js_i[p] <= js_i[p] + 8'd1;
                                        json_pph <= 3'd0;
                                    end
                                end
                            end
                        end else if (ch == 8'h5B) begin
                            if (varr_next >= MAX_ARR ||
                                varr_valid[varr_next[11:0]]) begin
                                machine_fault <= 1'b1; fault_code <= 8'd3;
                                running <= 1'b0; state <= S_DONE;
                            end else if (js_sp >= JSON_STK[5:0]) begin
                                dbg_json_ovf <= dbg_json_ovf + 16'd1;
                                json_rp <= json_rp + 14'd1;
                            end else begin
                                varr_valid[varr_next[11:0]] <= 1'b1;
                                varr_len[varr_next[11:0]] <= 8'd0;
                                vjs_val[js_sp] <= v64_handle(
                                    4'd6, varr_gen[varr_next[11:0]],
                                    {20'd0, varr_next[11:0]}
                                );
                                js_i[js_sp] <= 8'd0;
                                js_sp <= js_sp + 6'd1;
                                varr_next <= varr_next + 14'd1;
                                json_rp <= json_rp + 14'd1;
                            end
                        end else if (ch == 8'h5D) begin
                            json_rp <= json_rp + 14'd1;
                            if (js_sp <= 6'd1) begin
                                vstack[vnat_base] <= (js_sp == 0)
                                    ? V64_NULL : vjs_val[0];
                                vsp <= vnat_base + 12'd1;
                                ip <= ip + 16'd1;
                                code_raddr <=
                                    15'(ops_base + ip + 16'd1);
                                state <= S_FETCH_WAIT;
                            end else begin
                                logic [5:0] p, c;
                                c = js_sp - 6'd1;
                                p = js_sp - 6'd2;
                                varr_val[vjs_val[p][11:0]][js_i[p][6:0]]
                                    <= vjs_val[c];
                                varr_len[vjs_val[p][11:0]] <=
                                    js_i[p] + 8'd1;
                                js_i[p] <= js_i[p] + 8'd1;
                                js_sp <= c;
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
                        end else begin
                            vstack[vsp] <= vlistener_fn[pick];
                            vstack[vsp + 12'd1] <= vkev_event;
                            vsp <= vsp + 12'd2;
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
                        end else begin
                            frame_number = v64_int32_number(vframe_no);
                            v64_mul_task(
                                frame_number, 64'h4030aaaaaaaaaaab,
                                timestamp
                            );
                            vstack[vsp] <= vraf_snap[vraf_i];
                            vstack[vsp + 12'd1] <= timestamp;
                            vsp <= vsp + 12'd2;
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
                        end else begin
                            vstack[vsp] <= vtimer_fn[pick];
                            vsp <= vsp + 12'd1;
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
                    vstack[vsp - 12'd2] <= result;
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
                        vstack[vsp - 12'd2] <= result;
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
