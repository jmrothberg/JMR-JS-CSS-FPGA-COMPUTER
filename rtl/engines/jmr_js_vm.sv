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
    // 2026-08-25 div8: code loads stream at the full 100 MHz console rate
    // while the VM core runs on the /8 BUFGCE clock. The code BRAM write
    // port keeps the full-rate clock (true dual port, one clock per port).
    input  logic        clk_code_w,
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
    // BOARD tether VM heartbeat (spec 2026-08-26): flopped scalars only,
    // packed on the VM clock - the link samples a register, never the
    // FSM cone. {1'b0, st[6:0], fault[7:0], ip[15:0]}.
    output logic [31:0] vdbg_o,
    output logic        vdbg_fault_o,
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap,
    // NEW: getImageData reads the back bank (FM _nat_get_image_data twin).
    // Muxed onto mini_fb dump_raddr; dump_back is the non-front bank.
    input  logic        fb_present_busy, // Session-1: DDR3 present in flight
    output logic [18:0] fb_dump_addr,
    output logic        fb_dump_sel,
    input  logic [7:0]  fb_dump_back,
    // NEW: front-bank dump read (same dump_raddr) for S_FB_SYNC copy
    input  logic [7:0]  fb_dump_front,
    // NEW: external asset SRAM read port (jmr_sram_port master, read-only) —
    // ASET sprite banks live there; blitter fetches pixels 2-per-16-bit word
    output logic        sram_req,
    output logic [20:0] sram_addr,
    // 2026-08-21 fit: write channel added so the ImageData snapshot lives at
    // the top of the external asset bank instead of an 80-tile on-chip BRAM.
    // Console owns the bus outside RUN; the core mux keeps console priority.
    output logic        sram_we,
    output logic [15:0] sram_wdata,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack,
    // C1 (run 50/51): full-rate raster engine handshake. The VM latches
    // the op's scalars, pulses rast_go for ONE beat, then blocks until
    // rast_busy has risen and fallen. Engine: jmr_raster_engine.sv.
    output logic        rast_go,
    output logic [1:0]  rast_mode,
    output logic [9:0]  rast_dx,
    output logic [9:0]  rast_dy,
    output logic [9:0]  rast_w,
    output logic [9:0]  rast_h,
    output logic [7:0]  rast_color,
    output logic [15:0] rast_sx,
    output logic [15:0] rast_sy,
    output logic [15:0] rast_qx,
    output logic [15:0] rast_rxr,
    output logic [15:0] rast_qy,
    output logic [15:0] rast_ryr,
    output logic [21:0] rast_sbase,
    output logic [15:0] rast_stride,
    output logic        rast_aset,
    input  logic        rast_done   // op completed (level; cleared at next go)
);
    // 2026-08-21 fit: measured code high-water (ops_base+n_ops) across the
    // seven card titles: PACMAN 16443 worst. 20480 = 1.25x. Console clamps
    // writes and the tools refuse bigger images - loud, not wrap.
    localparam int CODE_WORDS = 20480; // 2026-08-21(3): 20 tiles; the HM raf test's extended PACMAN image is 19527 words - 19456 was 71 words of headroom
    localparam int MAX_CONSTS = 1024;
    localparam int MAX_VARS   = 512;
    localparam int STACK_DEPTH = 1024; // RTL vspmax=71 (40-frame PACMAN attract); flat
                                       // array literals push per element, so a literal
                                       // near 1000 slots still fits; vsp>=1008 faults (8'd7).
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

    // 2026-08-21 fit: pow2-chunked (16K+4K = 20480 exact) - see the heap
    // slot arrays for why. The boot hex (tiny stub) loads into chunk 0.
    (* ram_style = "block" *) logic [31:0] code_mem_c0 [0:16383] /*verilator public_flat_rw*/;
    (* ram_style = "block" *) logic [31:0] code_mem_c1 [0:4095]  /*verilator public_flat_rw*/;
    initial $readmemh(CODE_HEX, code_mem_c0);
    logic [14:0] code_raddr_ff;
    logic [14:0] code_raddr;
    logic [31:0] code_rdata;
    // Read port (VM fetch) + write port (FAT .JSB load) — dual-port BRAM,
    // pow2-chunked. Registered chunk select keeps the 1-beat fetch contract.
    // Out-of-range writes drop (too-big images refused loud at S_GOT_HDR2).
    logic [31:0] code_r_c0, code_r_c1;
    logic        code_rsel;
    always_ff @(posedge clk) begin
        code_r_c0 <= code_mem_c0[code_raddr[13:0]];
        code_r_c1 <= code_mem_c1[(code_raddr - 15'd16384) & 15'hFFF];
        code_rsel <= (code_raddr >= 15'd16384);
    end
    // Write port on the full-rate clock (console streams during load; the
    // VM is stopped then, so the domains never touch the same word live).
    // One pipeline stage before the BRAMs: the raw console strobe fanned
    // out to WEA pins across the die and was pblock36's routed head
    // (-0.261, u_cons/code_we -> code_mem WEA). code_we is fire-and-
    // forget (no handshake), so the extra cycle is invisible.
    logic        code_we_q;
    logic [14:0] code_waddr_q2;
    logic [31:0] code_wdata_q2;
    always_ff @(posedge clk_code_w) begin
        code_we_q     <= code_we;
        code_waddr_q2 <= code_waddr;
        code_wdata_q2 <= code_wdata;
        if (code_we_q) begin
            if (code_waddr_q2 < 15'd16384)
                code_mem_c0[code_waddr_q2[13:0]] <= code_wdata_q2;
            else if (code_waddr_q2 < 15'(CODE_WORDS))
                code_mem_c1[code_waddr_q2[11:0] & 12'hFFF] <= code_wdata_q2;
        end
    end
    assign code_rdata = code_rsel ? code_r_c1 : code_r_c0;

    logic signed [31:0] consts [0:MAX_CONSTS-1];
    logic signed [31:0] vars   [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic               var_init [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic signed [31:0] stack  [0:STACK_DEPTH-1];
    // UG901 Port A: FSM pulses these; do not poke stack[i] from the 7k-line FSM.
    logic        stack_we;
    logic [10:0] stack_waddr;
    logic signed [31:0] stack_wdata;
    logic        stack_dual_pend; // FOREACH el then idx (1 write/clock)
    // NEW: public for the sim server VMSTAT? probe (FPGA-SIM bring-up only)
    logic [10:0] sp /*verilator public_flat_rd*/; // 2048-deep eval stack
    logic [15:0] ip_ff;
    logic [15:0] ip /*verilator public_flat_rd*/;
    logic [15:0] n_ops, n_consts;
    logic [15:0] ops_base /*verilator public_flat_rd*/;
    logic [15:0] jsb_flags /*verilator public_flat_rd*/;
    // 2026-08-21 fit (REMOVING_EXEC32 Phase 3b, the synthesis half): every
    // image that reaches execution is Value64 - a non-V64 image faults code 9
    // at S_GOT_HDR2 (which reads the RAW header word, not this bit). Reading
    // the execution guards as constant 1 lets Vivado prove the whole tagged
    // twin (S_EXEC/S_NAT decode, tagged GC, stack/stack_tag/gc_queue/*_tmem/
    // tfn_*) unreachable and sweep it from the netlist. FPGA-SIM behavior is
    // identical: the FF bit is 1 whenever running. Do NOT route new logic
    // through v64_on; use v64_on.
    localparam bit v64_on = 1'b1;
    logic        looping, running /*verilator public_flat_rd*/;
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
    logic [1023:0] vst_win_pack;
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
    logic        vvars_we;
    logic [8:0]  vvars_waddr;
    logic [63:0] vvars_wdata;
    logic [8:0]  vvars_raddr;
    (* ram_style = "distributed" *) logic vvar_valid [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic [11:0] vsp_ff;
    logic [11:0] vsp /*verilator public_flat_rd*/;
    logic [7:0] vcsp_ff;
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
    logic [1:0] vobj_alloc [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic        vobj_alloc_we;
    logic [9:0]  vobj_alloc_waddr;
    logic [1:0]  vobj_alloc_wdata;
    logic [12:0] vobj_alloc_raddr;
    (* ram_style = "block" *) logic [11:0] vobj_gen [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [5:0] vobj_len [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // NEW_OBJ stores the interned class name so CALL_METH can find the
    // class-table method (PYTHON _value_object_classes). 16'hFFFF = none.
    (* ram_style = "block" *) logic [15:0] vobj_cls [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // PYTHON _value_object_protos / _value_function_prototypes. `var Stage =
    // function` + Stage.prototype.createItem is not a JSB class-method table.
    (* ram_style = "block" *) logic [63:0] vobj_proto [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_proto [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // Object/array slots are 1-D SRAM after the MAX_* localparams (not 2-D
    // combo arrays — Synth 8-4556 / ASIC SRAM).
    (* ram_style = "block" *) logic [11:0] vfn_gen [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // Function handles are their own leftover-BRAM bank (vfn_* already
    // 1024-wide). They must not occupy vobj_alloc — that shared the 1024
    // bump with objects and faulted MAKE_OBJ while function slots were
    // the ones that were full (same PYTHON lists, same split).
    (* ram_style = "distributed" *) logic vfn_valid [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic vfn_mark [0:OBJ_PHYS-1];
    logic [15:0] vfn_entry [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [5:0] vfn_nparam [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_env [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_bound_this [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [2:0] vfn_flags [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic varr_valid [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [11:0] varr_gen [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] varr_len [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic        varr_len_we;
    logic [11:0] varr_len_waddr;
    logic [7:0]  varr_len_wdata;
    logic [11:0] varr_len_raddr;
    (* ram_style = "distributed" *) logic varr_long [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] varr_lidx [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic vlong_used [0:LONG_PHYS-1];
    (* ram_style = "distributed" *) logic vobj_mark [0:OBJ_PHYS-1];
    (* ram_style = "distributed" *) logic varr_mark [0:MAX_ARR-1];
    (* ram_style = "distributed" *) logic venv_valid [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [11:0] venv_gen [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] venv_parent [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    logic [4:0] venv_len [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    // Env slots are 1-D venv_slot SRAM (not 2-D combo — Synth 8-4556).
    logic [63:0] vthis_ff;
    logic [63:0] vthis /*verilator public_flat_rd*/;
    logic [63:0] venv_ff;
    logic [63:0] venv /*verilator public_flat_rd*/;
    logic [15:0] vframe_return_ip [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [11:0] vframe_base_sp [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_this [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_env [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_fn [0:CSTK-1] /*verilator public_flat_rd*/;
    logic [63:0] vframe_ctor [0:CSTK-1] /*verilator public_flat_rd*/;
    // MAKE_FN in this activation captured venv; RET must not recycle it.
    logic vframe_escaped [0:CSTK-1];
    // 17-bit entries: every enqueued word is a NaN-boxed heap ref
    // ({16'h7ff9, kind[47:44], idx[12:0]}); pop rebuilds the full word.
    (* ram_style = "block" *) logic [16:0] vgc_queue [0:MAX_OBJ+MAX_ARR+ENV_DEPTH-1];
    logic [13:0] vgc_qr_ff, vgc_qw_ff, vgc_clear_i_ff;
    logic [13:0] vgc_qr /*verilator public_flat_rd*/, vgc_qw /*verilator public_flat_rd*/, vgc_clear_i;
    logic [12:0] vgc_obj_i;
    logic [11:0] vgc_arr_i;
    logic [7:0] vgc_slot_i;
    logic [63:0] vgc_cur;
    logic [11:0] vgc_root_i;
    logic [13:0] valloc_i_ff;
    logic [13:0] valloc_i;
    logic [13:0] vobj_next, varr_next, vfn_next;
    logic [9:0] venv_next;
    logic [1:0] valloc_kind_ff;
    logic [1:0] valloc_kind /*verilator public_flat_rd*/;
    logic valloc_retried_ff;
    logic valloc_retried;
    logic vgc_halt_after_ff;
    logic vgc_halt_after;
    // C4 (run 50): a forced (alloc-retry) GC already collected this
    // frame; the scheduled frame-end GC is then pure re-walk of the
    // same heap (~24% of an old PACMAN frame ran 4 GCs). Scheduling
    // only: forced GCs still fire on pressure. Set at the four forced
    // entries, consumed+cleared at the S_FB_SYNC frame-end decision.
    logic gc_ran_this_frame;
    (* ram_style = "distributed" *) logic venv_mark [0:ENV_PHYS-1];
    logic [9:0] vgc_env_i;
    logic [2:0] vgc_root_phase;
    logic vcall_value_ff;
    logic vcall_value;
    logic [15:0] vcall_entry_ff;
    logic [15:0] vcall_entry;
    logic [11:0] vcall_argc_ff;
    logic [11:0] vcall_argc;
    // CALL_METH / NEW_OBJ ctor: bind this + constructor_value like PYTHON.
    logic vcall_set_this_ff;
    logic vcall_set_this;
    logic [63:0] vcall_this_ff;
    logic [63:0] vcall_this;
    logic [63:0] vcall_ctor_val_ff;
    logic [63:0] vcall_ctor_val;
    // PYTHON builtin objects (ELEMENT/CONTEXT/IMAGE) + listener/key dispatch.
    logic [3:0] vobj_builtin [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [2:0] vnat_dom_ff;
    logic [2:0] vnat_dom;
    logic [63:0] vnat_style;
    // PYTHON measureText {width} — one reused object (tagged metrics_oid).
    logic [63:0] vmetrics;
    logic        valloc_metrics_ff;
    logic        valloc_metrics;
    logic [15:0] vmetrics_w;
    logic [63:0] vkev_event;
    logic        vkey_custom;    // dispatchEvent scan: resume program, no kev pop
    logic [63:0] vkey_want_ev;   // dispatchEvent: event type string handle
    logic [15:0] vkey_ret_ip;    // dispatchEvent: program resume ip
    logic [11:0] vkey_ret_sp;    // dispatchEvent: program resume vsp
    logic [63:0] vlistener_ev [0:15] /*verilator public_flat_rd*/;
    logic [63:0] vlistener_fn [0:15] /*verilator public_flat_rd*/;
    logic [4:0] vlistener_n_ff;
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
    // Length latched from varr_len_rdata on FOREACH pin (CALL_METHOD raddr).
    // Combo varr_len[vfe_arr[11:0]] / varr_valid[] in the unique case is a
    // BRAM mux that reads 0, so FOREACH took the done path with i>=0.
    logic [7:0] vfe_len;
    // Coherent asynchronous Value64 subset: rAF and timer queues use stable
    // function handles and explicit callback frames. Listener/key dispatch
    // remains an unsupported native surface until its event objects land.
    logic [63:0] vraf [0:7] /*verilator public_flat_rd*/;
    logic [3:0] vraf_n_ff /*verilator public_flat_rd*/;
    logic [3:0] vraf_n /*verilator public_flat_rd*/;
    logic [63:0] vraf_snap [0:7];
    logic [3:0] vraf_snap_n /*verilator public_flat_rd*/;
    logic [3:0] vraf_i /*verilator public_flat_rd*/;
    logic vtimer_valid [0:63] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic signed [31:0] vtimer_due [0:63] /*verilator public_flat_rd*/;
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
    logic vgc_wait_after_ff;
    logic vgc_wait_after;
    // After a mid-op collect, resume the caller instead of S_V64_ALLOC.
    // 0=alloc retry  1=re-fetch current op (map/filter dest)  2=JSON.parse
    // 3=JSON.stringify result object.
    logic [1:0] vgc_resume;
    logic [11:0] vnat_base_ff;
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
    // Sticky: CTOR_ENV intern path (not combo NEW_OBJ&&bind_ins). BIND
    // then ALLOC kind 3 must still see a FUNCTION callee (PACMAN Stage).
    logic        intern_ctor_hold;
    // Latched while CTOR_ENV/VARS muxes hp_rval (tfn_rd_arm). ALLOC kind 3
    // re-sample of vfn_entry_rdata was createStage+4 on the title (PACMAN
    // LOAD_VAR stage eip=1720, Stage frame still live, venvi invalid).
    logic [15:0] intern_ctor_entry;
    logic [5:0]  intern_ctor_nparam;
    logic [2:0]  intern_ctor_flags;
    logic [63:0] intern_ctor_env;
    // Math.min/max one arg per clock (not a 256-wide vstack mux).
    logic        minmax_is_min;
    logic [7:0]  minmax_k, minmax_n;
    logic [11:0] minmax_base;
    logic [63:0] minmax_acc;
    logic [18:0] vdraw_i_ff;
    logic [18:0] vdraw_i;
    logic [9:0] vdraw_x_ff, vdraw_y_ff, vdraw_w_ff, vdraw_h_ff;
    logic [9:0] vdraw_x, vdraw_y, vdraw_w, vdraw_h;
    // Scan cursor so S_V64_RECT is adders, not /% per pixel (Verilator
    // combo divide made full-canvas fillRect feel frozen-slow).
    logic [9:0] vdraw_cx, vdraw_cy;
    // S_V64_RECT_LD: one SRAM beat per fillRect arg (addr, then vst_rdata).
    logic        rect_ld_arm;
    logic [1:0]  rect_ld_k;
    logic [7:0] vdraw_color_ff;
    logic [7:0] vdraw_color;
    // NEW: tagged stack/vars for HTML heap (0=int 1=obj 2=arr 3=str 4=fn 5=undef 6=elem)
    logic [2:0]  stack_tag [0:STACK_DEPTH-1];
    logic        stack_tag_we;
    logic [10:0] stack_tag_waddr;
    logic [2:0]  stack_tag_wdata;
    logic [2:0]  var_tag   [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    // Slot SRAM must fit leftover T200 BRAM after dual 640×480 FB (~0.6 MB)
    // of ~1.64 MB total: leftover ~1 MB for code + heap + console. Overflow
    // loud. Same numbers in hardware_model/js_vm.py. Not title-sized.
    // 2026-08-21(2): 768 PEGGED in PACMAN play (fault 3 at obj=768, GC
    // thrashing) - the FM census that said 567 was splash-biased. User call:
    // keep near 1024 for future titles, brought down only "a little" for
    // fit. 960 is safe as a non-pow2 LOGICAL cap because every side array
    // keeps OBJ_PHYS=1024 physical rows (see below) and the slot array is
    // claim-bounded. vobj_slot BRAM = 30720x80 = 75 tiles.
    localparam int MAX_OBJ = 960;
    // 2026-08-21(final): bisect-proven floor. The attract-mode ghost-AI tick
    // (4x JSON.parse maze + BFS in ONE frame) legitimately bursts ~330 objects
    // over the ~570 steady live: 896 pegged at rafcall 30, 960 clears it. // 2026-08-21(4): first-.bin margin call (user). 960 was paper 365/365; 896 = 70 tiles, margin ~5. #79 (PACMAN pathfinder explosion) kills any cap equally, so the 64 slots buy nothing until it is fixed. Revisit after the utilization report.
    // The fn bank (vfn_*) shares this cap: measured fn peak PACMAN 510 ->
    // 768 = 1.5x. Handle-range checks all compare against MAX_OBJ.
    //
    // PHYSICAL vs LOGICAL depth (bug #76, 2026-08-21): the small per-handle
    // side arrays are written through FIXED-WIDTH bit slices ([9:0] obj,
    // [8:0] env, [6:0] long-arr) at the exec-write block and pokes. When the
    // caps were 1024/512/128 the slice width EQUALLED the array depth, so a
    // stray high index was architecturally in-bounds. After the cap shrink a
    // sliced write above the cap became an OUT-OF-BOUNDS write in the
    // Verilated model (INVADERS lost bunker cell #32 of every bunker after
    // the first - adjacent-state corruption at the S_ARR_PROMOTE boundary).
    // The side arrays therefore keep 2^slice-width PHYSICAL depth; the
    // LOGICAL caps above still bound allocation (and the BRAM-heavy slot
    // arrays, whose addresses are computed from claim-bounded values, keep
    // their shrunk sizes). Rows above the cap are inert: no scan reads them.
    localparam int OBJ_PHYS  = 1024; // 2^10 - e64/poke write slices are [9:0]
    localparam int ENV_PHYS  = 512;  // 2^9  - write slices are [8:0]
    localparam int LONG_PHYS = 128;  // 2^7  - write slices are [6:0]
    localparam int OBJ_RING = MAX_OBJ / 2; // wrap point: boot heap stays below
    localparam int OBJ_SLOTS = 32; // property slots per object (Object.assign)
    // Two-tier arrays, same total bits as 512×128: short 1024×32 (nested
    // number-array maps / JSON clones) plus long 256×128 (push past 32).
    // Handle stays put on promote (varr_long + varr_lidx). Overflow loud.
    // Same 65536 × 64b words as 1024×32+256×128 (leftover BRAM). More short
    // handles for nested map + JSON clones; long bank still covers push>32.
    localparam int MAX_ARR_SHORT = 1536;
    localparam int ARR_SHORT_CAP = 32;
    // 2026-08-21(2): measured long-array (len>32) peak in play is TWO
    // (INVADERS bunkers use 4). 16 = 4x headroom; pays for MAX_OBJ 960.
    // varr_slot BRAM = 51200x64 = 100 tiles. LONG_PHYS stays 128.
    localparam int MAX_ARR_LONG = 12; // 2026-08-21(final): measured peak 2 in play; INVADERS bunkers use 4
    localparam int MAX_ARR = MAX_ARR_SHORT + MAX_ARR_LONG;
    localparam int ARR_RING = MAX_ARR / 2;
    // NEW: per-call lexical env (FM bytecode.py env dict). LIFO frames;
    // MAKE_FN snapshots the current frame onto the Fn heap object so
    // setTimeout/rAF closures keep forEach params after the call returns.
    // Slot SRAM is 1-D venv_slot (Synth 8-4556 was 2-D venv_val). Same
    // ENV_DEPTH in hardware_model/js_vm.py. Overflow loud.
    // 2026-08-21 fit: measured live-env peak PACMAN 157; 256 = 1.63x.
    // venv_slot BRAM 19 -> 10 tiles. Overflow is loud (fault 4 path).
    localparam int ENV_DEPTH = 384;
    // 2026-08-21(final): 256 CORRUPTED PACMAN - the finder's recursive BFS
    // transiently holds ~300 envs (between-frame envl~140 missed the
    // recursion peak); at 256 live envs got recycled mid-recursion and the
    // callbacks ran on broken environments (the maze-flood, #79 trail).
    // 384 bisect-proven clean; 512 is the pre-fit fallback (+5 tiles).
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
    (* ram_style = "distributed" *) logic [7:0] arr_len [0:MAX_ARR-1] /*verilator public_flat_rd*/;
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
    // Flattened {class,method} tables in LUTRAM; the method scan walks
    // them one entry per beat (pipelined read), replacing the one-beat
    // 256-way comparator forest. cls_name/cls_ctor/cls_nmeth stay FFs
    // for the comb class find (tiny).
    (* ram_style = "distributed" *) logic [15:0] cls_mname [0:MAX_CLS*MAX_CMETH-1];
    (* ram_style = "distributed" *) logic [15:0] cls_mip   [0:MAX_CLS*MAX_CMETH-1];
    logic [7:0]  clsm_raddr;
    logic [15:0] clsm_name_rd, clsm_ip_rd;
    logic        cmn_we, cmi_we;
    logic [7:0]  cmn_wa, cmi_wa;
    logic [15:0] cmn_wd, cmi_wd;
    logic        cls_seq, cls_prime;
    // Class table scan: one (c) or (c,m) per clock. unique case must not CAM.
    logic cls_scan, cls_armed, cls_done, cls_ctor_mode, cls_hit;
    // exec method-lookup service: exec raises cm_req (level) with key/cls;
    // the sequential scanner runs ctor_mode=0 and the result pulses back.
    logic        e64_cm_req;
    logic [15:0] e64_cm_key, e64_cm_cls;
    logic        cm_serving, cm_served_hold, cm_res_we;
    logic [15:0] cm_res_mip;
    // exec listener-op service (add/remove): sequential walk over the
    // SINGLE parent table; result is a held level (the cm lesson).
    logic        e64_lsv_req;
    logic [1:0]  e64_lsv_op;
    logic [63:0] e64_lsv_ev, e64_lsv_fn;
    logic        lsv_serving /*verilator public_flat_rd*/, lsv_served_hold, lsv_res_we /*verilator public_flat_rd*/, lsv_arm;
    logic [2:0]  lsv_res;
    logic [4:0]  lsv_res_n_out;
    logic [4:0]  lsv_k, lsv_w, lsv_same;
    logic        lsv_dup;
    logic [3:0] cls_c, cls_m;
    logic [15:0] cls_cls, cls_key, cls_ctor_q, cls_mip_q, cls_gip_q;
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
    // flatten: 2-deep TOS window (like vst_win). Mux must not clock
    // cstack[csp-1], cstack[csp-2], and GC_ROOT in one always_ff (3 ports).
    logic [15:0] cs_win1_ip, cs_win2_ip;
    logic [15:0] cs_win1_this, cs_win2_this;
    logic        cs_win1_isctor, cs_win2_isctor;
    logic        cs_win1_isfe, cs_win2_isfe;
    logic [15:0] cs_win1_ctorobj, cs_win2_ctorobj;
    logic [15:0] cs_win1_fe_arr, cs_win2_fe_arr;
    logic [15:0] cs_win1_fe_fn, cs_win2_fe_fn;
    logic [7:0]  cs_win1_fe_i, cs_win2_fe_i;
    logic [15:0] cs_win1_map_arr, cs_win2_map_arr;
    logic [5:0]  cs_win1_env, cs_win2_env;
    logic [15:0] cs_pend_ip, cs_pend_this;
    logic        cs_pend_valid;
    logic [1:0]  cs_refill; // 0 idle; 1 one load; 2 two loads
    logic        cs_refill_arm, cs_refill_win1;
    logic [6:0]  cs_raddr_ff;
    logic [6:0]  csp_e32_d; // exec csp last clock (we_q is 1 cycle late)
    logic [6:0]  csp /*verilator public_flat_rd*/;
    logic [5:0]  env_sp /*verilator public_flat_rd*/; // 0 = top-level (vars[] only)
    logic [15:0] env_oid [0:ENV_PHYS-1]; // NEW: live heap env objects (not value snapshots)
    logic        env_cap [0:ENV_PHYS-1]; // NEW: MAKE_FN captured this frame
    logic [15:0] env_free [0:ENV_PHYS-1] /*verilator public_flat_rd*/; // NEW: recycled uncaptured env oids (peek)
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
    // flatten: WAIT_FRAME obj_cls/tfn raddr must not combo-read to_fn[0]
    // (already muxed as e32_to_fn_rdata). Scalar tap, updated on writes to slot 0.
    logic [15:0] to_fn0;
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
    localparam int NAME_CAP = 16384; // measured peak 3,644 bytes (PACMAN); 4.5x headroom, loud refuse past cap
    // UG901 RAM_STYLE=block (not a heuristic). Read process below matches
    // simple_dual_one_clock.v — not the 40-array mux.
    (* ram_style = "block" *) logic [7:0]  name_mem [0:NAME_CAP-1] /*verilator public_flat_rd*/;
    logic        name_we;
    logic [14:0] name_waddr;
    logic [7:0]  name_wdata;
    // Multi-port-by-replication (2026-08-24): 4 read sites made BRAM
    // infeasible (Synth 8-6849) and the LUTRAM cost ~384 prims of SLICEM.
    // Four mirrored copies, one per read port, half a tile each.
    (* ram_style = "block" *) logic [15:0] name_off [0:1023] /*verilator public_flat_rd*/;   // intern idx -> first byte in name_mem
    (* ram_style = "block" *) logic [15:0] name_off_r1 [0:1023];
    (* ram_style = "block" *) logic [15:0] name_off_r2 [0:1023];
    (* ram_style = "block" *) logic [15:0] name_off_r3 [0:1023];
    // NAMB u16 byte length. Hash-table name_len_tbl is u8 (concat fold).
    // str[i] / str.length must use this or a 624-char layout literal
    // reports length 112 (624&255) and never carves tunnels.
    (* ram_style = "block" *) logic [15:0] name_blen [0:1023] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [15:0] name_blen_r1 [0:1023];
    logic [15:0] name_rdaddr;
    logic [14:0] name_mem_raddr;
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
    logic [15:0] char_id [0:255] /*verilator public_flat_rd*/;
    logic        char_ok [0:255] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic name_has [0:1023];   // this intern id has bytes in name_mem
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
    (* ram_style = "distributed" *) logic [7:0] txt_buf [0:TXT_MAX-1];
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
    // ctx.textAlign is written by the exec that runs SET_PROP, and the
    // parent's copy is only ever reset — so the text pen always used
    // left-align for Value64 titles (DONKEY's centred title text sat
    // off to one side). Read the live exec value, like every other
    // exec-owned scalar.
    logic [1:0]  ctx_align_eff;
    logic [7:0]  ctx_font_px;           // ctx.font "NNpx ..." size (FM default 8)
    logic [7:0]  fpx_acc;               // digits seen while parsing ctx.font
    logic [7:0]  fp_left;               // bytes left in the font string
    // NEW: JSON/text scratch (stringify/parse/replace) — VM cap, sticky ovf
    (* ram_style = "block" *) logic [7:0]  json_mem [0:JSON_CAP-1];
    logic        json_we;
    logic [12:0] json_waddr;
    logic [7:0]  json_wdata;
    logic [13:0] json_wp /*verilator public_flat_rd*/, json_rp, json_src, json_srclen, json_dst;
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
    // imgd_pix BRAM removed 2026-08-21: the one ImageData snapshot now lives
    // in external SRAM words [IMGD_SRAM_BASE .. IMGD_SRAM_BASE+FB_PIXELS-1],
    // one pixel per 16-bit word (low byte). Top 600KB of the 4MB bank is
    // reserved for it - ASET art must stay below IMGD_SRAM_BASE (tools cap
    // ASET far under this; loud check lives in compile).
    localparam logic [20:0] IMGD_SRAM_BASE = 21'd1789952; // 2*1024*1024-307200
    logic        imgd_pend; // one outstanding IMGD sram transfer (GET wr / PUT rd)
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
    // One index/clock parent heap wipe (S_HEAP_CLR). Do not parallel-clear
    // MAX_OBJ/MAX_ARR/ENV in S_GOT_HDR2 — that is SRAM, not FFs.
    logic        heap_clr_busy;
    logic [11:0] heap_clr_i;
    logic [15:0] id_find; // Array.find
    logic [15:0] id_findindex, id_filter; // Array.findIndex / Array.filter
    logic [15:0] id_slice; // #40 Array.slice
    logic [15:0] id_sort; // #41 Array.sort
    logic e64_vfe_sort_q;
    logic        click_fired; // NEW: HTML auto-start click once
    logic        pre_click_raf; // NEW: one rAF (Image.onload) before click
    logic [5:0]  prev_joy;
    logic [5:0]  joy_down_edge, joy_up_edge;
    logic [7:0]  fill_style_i;
    logic [7:0]  stroke_style_i; // PYTHON ctx.strokeStyle — not fillStyle
    logic [31:0] lfsr;
    // Bring-up mirrors (read-only aliases; no logic, no extra FFs).
    logic [15:0] dbg_id_keydown /*verilator public_flat_rd*/;
    logic [15:0] dbg_id_keyup /*verilator public_flat_rd*/;
    logic [15:0] id_fillrect, id_length, id_push, id_pop, id_splice, id_foreach;
    logic [15:0] id_map, id_unshift; // Array.map / Array.unshift
    logic [15:0] id_getctx, id_click, id_ael, id_key, id_keycode;
    logic [15:0] id_rel, id_disp; // removeEventListener / dispatchEvent
    logic [15:0] id_document, id_window; // seed vars so `if (document.dispatchEvent)` is truthy
    logic [15:0] id_arrow_l, id_arrow_r, id_space, id_a, id_d, id_keydown, id_keyup;
    // potential-bugs #15: DONKEY drives WASD + pause. Without these,
    // e.key is undefined for w/s/p and the handler's === test never matches.
    logic [15:0] id_w, id_s, id_p;
    // NEW: e.key for the vertical arrows. Without these the Up/Down keyCode
    // arrived with event.key = "ArrowLeft" (the old ternary default), so a
    // `switch (e.key)` game turned left on every vertical press.
    logic [15:0] id_arrow_u, id_arrow_d;
    logic [15:0] id_reduce, id_draw, id_update, id_fillstyle, id_clearrect;
    logic [15:0] id_drawimage /*verilator public_flat_rd*/;
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
    logic [15:0] id_textbaseline, id_top, id_middle, id_bottom; // #37
    logic [1:0] e64_ctx_baseline_q;
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
    (* ram_style = "block" *) logic [15:0] name_hash_tbl [0:1023] /*verilator public_flat_rd*/; // intern idx -> encoder u16 hash
    logic        name_hash_we;
    logic [9:0]  name_hash_waddr;
    logic [15:0] name_hash_wdata;
    logic [9:0]  name_hash_raddr;
    (* ram_style = "block" *) logic [7:0]  name_len_tbl  [0:1023] /*verilator public_flat_rd*/; // intern idx -> byte length (concat fold)
    (* ram_style = "block" *) logic [7:0]  name_len_tbl_r1 [0:1023];
    logic [15:0] names_n /*verilator public_flat_rd*/;
    // End of the trailer-loaded (static) names, and the byte pointer at
    // that moment. Strings built at run time (`"SCORE " + score`) intern
    // above this and are never reclaimed, so the 1024-slot table filled
    // after a few hundred frames and every later intern degraded. Recycle
    // the dynamic region as a ring instead of exhausting it: per-frame HUD
    // strings are rebuilt every frame, so an old one going stale is fine,
    // while the static names the program compares against are untouched.
    logic [15:0] names_static;
    logic [15:0] nb_static;
    logic [11:0]  jn_arr;
    logic [15:0] jn_i, jn_h;
    logic [7:0]  jn_len;
    // Last-4 intern FIND cache (VM-wide). One Port-A probe/clock via jn_i;
    // not a CAM in unique case. CONCAT/JOIN enter FIND with state already
    // FIND, so the overlay beat never plants — plant on !jn_cache_try.
    logic [15:0] jn_hit_h0, jn_hit_h1, jn_hit_h2, jn_hit_h3;
    logic [7:0]  jn_hit_l0, jn_hit_l1, jn_hit_l2, jn_hit_l3;
    logic [15:0] jn_hit_i0, jn_hit_i1, jn_hit_i2, jn_hit_i3;
    logic [3:0]  jn_hit_v;
    logic [2:0]  jn_cache_i;  // 0..3 = probe slot, 4 = linear scan this visit
    logic        jn_cache_try;
    logic [10:0] jn_res;
    logic signed [31:0] idx_v;
    logic [2:0]  idx_t;
    logic [15:0] dbg_join_miss /*verilator public_flat_rd*/; // unsupported join/indexOf shapes
    // NEW: path bring-up latch — first 16 transformed S_PDO commands
    logic [79:0] dbg_pdo [0:15] /*verilator public_flat_rd*/;
    logic [4:0]  dbg_pdo_n /*verilator public_flat_rw*/; // rw: probe re-arms it
    // NEW: rect bring-up latch — {color, rx, ry, rw, rh} of first 16 rects
    logic [47:0] dbg_rect [0:63] /*verilator public_flat_rd*/;
    logic [6:0]  dbg_rect_n /*verilator public_flat_rw*/;
    logic [9:0]  dbg_last_y;
    logic [7:0]  dbg_last_c;
    logic [15:0] dbg_swap_n /*verilator public_flat_rd*/; // presents since RUN
    // NEW: raster px counters (flood hunt) — cleared by PDOCLR
    logic [31:0] dbg_line_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_circ_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_rect_px /*verilator public_flat_rw*/;
    // Bring-up: key dispatch visibility (FRAME_KEY entries vs callbacks).
    logic [15:0] dbg_key_scan /*verilator public_flat_rw*/;
    logic [15:0] dbg_key_call /*verilator public_flat_rw*/;
    logic [15:0] dbg_key_alloc /*verilator public_flat_rw*/;
    logic [63:0] dbg_key_want /*verilator public_flat_rd*/;
    logic [63:0] dbg_key_lastev /*verilator public_flat_rd*/;
    logic [15:0] dbg_key_cmp /*verilator public_flat_rw*/;
    logic [7:0]  dbg_bad_state /*verilator public_flat_rd*/;
    logic [1:0]  dbg_align /*verilator public_flat_rd*/;
    logic [15:0] dbg_evkey /*verilator public_flat_rd*/;   // id planted as event.key
    logic [15:0] dbg_txtw  /*verilator public_flat_rd*/;   // last fillText pen width
    logic [15:0] dbg_txt_n /*verilator public_flat_rw*/;   // fillText calls
    // A fillText whose intern has no bytes is an unrenderable STRING,
    // not a full table. It used to bump dbg_str_ovf, which the global
    // fault sweep turns into fault 5 and halts the VM — so one HUD
    // draw of `"SCORE " + score` could kill the machine mid-game.
    // Count it loudly on its own counter and keep running.
    logic [15:0] dbg_txt_miss /*verilator public_flat_rw*/;
    // rAF dispatches vs frame ends: if these diverge, the frame loop is
    // re-dispatching callbacks instead of finishing the frame.
    logic [15:0] dbg_raf_call /*verilator public_flat_rw*/;
    logic [15:0] dbg_frame_end /*verilator public_flat_rw*/;
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
    logic        valloc_now_fn_ff;
    logic        valloc_now_fn;
    logic        valloc_regex_ff;
    logic        valloc_regex;
    // Packed pattern/flags from the const pool (same i32 as tagged CLS_REGEX).
    logic [31:0] valloc_regex_pack_ff;
    logic [31:0] valloc_regex_pack;
    // Array(n) hole count for native 34 (PYTHON length-n undefined slots).
    logic [7:0]  valloc_arr_n_ff;
    logic [7:0]  valloc_arr_n;
    // MAKE_FN entry/a1 latched at fetch. S_V64_ALLOC must not re-read
    // code_rdata — GC resume (or a JUMP-to-MAKE_FN with a skipped RET_VAL
    // a0=0 in the previous word) would store entry 0, and CALL_METHOD
    // then restarts the ProgramImage (maps IIFE nested until MAX_ARR).
    logic [15:0] valloc_fn_entry_ff;
    logic [15:0] valloc_fn_entry;
    logic [7:0]  valloc_fn_a1_ff;
    logic [7:0]  valloc_fn_a1;
    // GET_PROP .prototype on a function: alloc empty proto object (PYTHON).
    logic        valloc_proto_ff;
    logic        valloc_proto;
    logic [12:0] valloc_proto_fn_ff;
    logic [12:0] valloc_proto_fn;
    // fn.bind(this) — PYTHON copies entry/env and sets has_bound_this.
    logic        valloc_bind_ff;
    logic        valloc_bind;
    logic [12:0] valloc_bind_src_ff;
    logic [12:0] valloc_bind_src;
    logic [63:0] valloc_bind_this_ff;
    logic [63:0] valloc_bind_this;
    logic [5:0]  vctor_scan;
    logic        vctor_armed;
    // Class-field trampoline (compiler JUMP after param LET_VARs). Last
    // ctor LET_VAR HEAP_WR skips that JUMP so startSelect lands (DONKEY).
    logic [15:0] vctor_jmp;
    logic [5:0]  vctor_lets;
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
    (* ram_style = "block" *) logic [7:0] fill_lut [0:1023];
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
    // A canvas is persistent: only present when this frame actually
    // drew into the back bank. Presenting unconditionally flipped a
    // title that draws once (DONKEY's title screen) to the stale
    // empty bank on the very next frame_tick — the glass went black
    // while the drawn bank sat behind it.
    logic        fb_dirty;
    logic        fbs_armed; // S_FB_SYNC dump-read settle beat
    // Port A write strobes (FPGA_FIT census): the FSM must not poke
    // these BRAM-attributed arrays directly (Vivado 8-7186 ignores
    // ram_style when the CPU always_ff writes them — the 2026-08-20
    // mapping OOM). Sites set we/waddr/wdata; the read process owns
    // the single write port. Writes land one beat later; every
    // consumer reads via registered *_rdata beats later still.
    logic vgc_queue_pa_we; logic [11:0] vgc_queue_pa_waddr; logic [16:0] vgc_queue_pa_wdata;
    logic vconsts_pa_we; logic [9:0] vconsts_pa_waddr; logic [63:0] vconsts_pa_wdata;
    logic vobj_proto_pa_we; logic [12:0] vobj_proto_pa_waddr; logic [63:0] vobj_proto_pa_wdata;
    logic vfn_proto_pa_we; logic [12:0] vfn_proto_pa_waddr; logic [63:0] vfn_proto_pa_wdata;
    logic vfn_env_pa_we; logic [12:0] vfn_env_pa_waddr; logic [63:0] vfn_env_pa_wdata;
    logic vfn_bound_this_pa_we; logic [12:0] vfn_bound_this_pa_waddr; logic [63:0] vfn_bound_this_pa_wdata;
    logic venv_parent_pa_we; logic [9:0] venv_parent_pa_waddr; logic [63:0] venv_parent_pa_wdata;
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
    // flatten: sin_q 256 ROM — raddr this clock, rdata next (not function peek).
    logic [15:0] sin_turn, arc_ts, arc_te;
    logic [3:0]  sin_ph;
    logic [15:0] sin_q_rdata;
    logic [7:0]  sin_raddr;
    logic [7:0]  txt_buf_rdata;
    logic [15:0] pow31_rdata;
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
    // 262144 -> 32768: ~50 BRAM tiles back. All HTML titles are
    // aset_mode=1 (sprites blit from the external asset SRAM); spr_mem
    // only serves the .JS probe SPR1 packs, which are tiny.
    localparam int SPR_BYTES = 32768;
    // NEW: 16 ASET sprite descriptors (was 8 — silently dropped DONKEY sheets
    // beyond the clamp). obj_cls FFC0|idx encoding carries a 4-bit index;
    // compile_js.py fails loud if a title ever exceeds this.
    localparam int MAX_SPR = 16;
    localparam logic signed [31:0] FX_ONE = 32'sh0001_0000; // Q16.16 1.0
    // spr_mem moved to external SRAM 2026-08-22 (words SPR_SRAM_BASE..+32767,
    // one byte per word) - was 6k LUTRAM against the failing 46.2k cap.
    localparam logic [20:0] SPR_SRAM_BASE = 21'd1691648;
    logic        sprb_pend; // one in-flight sprite-byte write
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
    logic        blit_wait;
    logic [18:0] blit_waddr_q;
    logic        blit_inb_q;   // NEW: SRAM read handshake inside S_BLIT
    // flatten: spr_mem 256K / imgd_pix FB — raddr this clock, rdata next.
    // spr_mem_rdata retired (external SRAM)
    logic [17:0] spr_raddr;
    logic [21:0] spr_so; // ASET word addr; spr_raddr is the low 18 for spr_mem
    logic [63:0] vraf_rdata;
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
    logic [2:0]  kev_wp /*verilator public_flat_rd*/, kev_rp /*verilator public_flat_rd*/;
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
        // Registered vvars[intern_var] ctor lookup (no combo vvars[vslot]).
        S_V64_CTOR_VARS,
        // Synth 8-3380 / unroll: walk tagged-env recycle and find-free
        // one index per clock (not a task for-loop over ENV_DEPTH/MAX_*).
        S_REL_ENV, S_FREE_OBJ, S_FREE_ARR,
        // 1W1R vstack copies (bind_argv / ctor insert) and Math.min/max.
        S_V64_BIND, S_V64_MINMAX,
        // After a vsp drop of 16+ the TOS FF window is stale; refill from BRAM.
        S_V64_WIN_FILL,
        // Short→long array promote (same handle; copy then flip varr_long).
        S_ARR_PROMOTE,
        // fillRect args from vstack SRAM (window can still be the last bar).
        S_V64_RECT_LD,
        // Sequential p_clr walk (one index/clock) before const load.
        S_HEAP_CLR,
        // #40 Array.slice element copy (append-only; keep numeric order).
        S_V64_SLICE,
        // #41 Array.sort bubble walk.
        S_V64_SORT
        // Post-present bank sync (MUST stay last: sim_main and
        // debug RPCs hardcode earlier state numbers).
        , S_FB_SYNC
        , S_V64_DISPATCH
    } st_t;
    // V1 fit: one-hot the 68-state parent register — 349 state==X decodes
    // become single-FF tests; FF headroom is 8x.
    (* fsm_encoding = "one_hot" *) st_t state /*verilator public_flat_rd*/;
    st_t ret_state;
    logic vprom_done, vprom_copy, hp_prom_wr;
    logic [7:0] hp_prom_phys;
    st_t vprom_ret;

    // Packed object slot {key[15:0], val[63:0]} and array val SRAM.
    // 1W1R registered — storage_engine sbuf / jmr_video_vram Port A.
    // Dump/CHECKPOINT peeks this array (not a third hardware port).
    // 2026-08-21 fit: Vivado pads every BRAM to 2^(address width), so the
    // non-pow2 heap arrays each wasted 5-32 tiles (utilization_hier.rpt).
    // Each is decomposed into EXACT pow2 chunks (zero padding):
    //   vobj 30720 = 16K+8K+4K+2K   varr 50688 = 32K+16K+1K+512(+256)
    //   venv 6144  = 4K+2K          (code_mem is split at its declaration)
    // Chunk selects are REGISTERED beside the data - the 1-beat read
    // contract is bit-identical. Sub-indices are masked to the pow2 chunk
    // size so no read is ever out of bounds (#76 lesson).
    (* ram_style = "block" *) logic [79:0] vobj_slot_c0 [0:16383] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c1 [0:8191]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c2 [0:4095]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c3 [0:2047]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [2:0] vobj_tmem [0:VOBJ_WORDS-1]
        /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c0 [0:32767] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c1 [0:16383] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c2 [0:2047]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [2:0] varr_tmem [0:VARR_WORDS-1]
        /*verilator public_flat_rd*/;
    // Packed env slot {key[8:0], val[63:0]} in low 73 of 80. 1W1R like vobj.
    (* ram_style = "block" *) logic [79:0] venv_slot_c0 [0:4095] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] venv_slot_c1 [0:2047] /*verilator public_flat_rd*/;
    // 2026-08-21 LUT fit: the vframe record arrays (6 of the 7; escaped is
    // 128 flat FFs and keeps its partial-field writers) live in a DEDICATED
    // write process so they infer RAM instead of ~30k FFs each dragging
    // ~10 LUTs of 112-state decode (utilization_hier.rpt: the parent held
    // 1.72M logic LUTs). Reads were ALREADY registered; the parent-side
    // writer becomes a one-beat strobe (call-write vs return-read are many
    // beats apart), the exec-side writer moves here unchanged.
    logic        vfr_we;
    logic [6:0]  vfr_wa;
    logic [15:0] vfr_rip;
    logic [11:0] vfr_bsp;
    logic [63:0] vfr_this, vfr_env, vfr_fn, vfr_ctor;
    always_ff @(posedge clk) begin
        if (vfr_we) begin
            vframe_return_ip[vfr_wa] <= vfr_rip;
            vframe_base_sp[vfr_wa]   <= vfr_bsp;
            vframe_this[vfr_wa]      <= vfr_this;
            vframe_env[vfr_wa]       <= vfr_env;
            vframe_fn[vfr_wa]        <= vfr_fn;
            vframe_ctor[vfr_wa]      <= vfr_ctor;
        end else if (e64_vframe_we) begin
            vframe_return_ip[e64_vframe_waddr] <= e64_vframe_rip_wdata;
            vframe_base_sp[e64_vframe_waddr]   <= e64_vframe_bsp_wdata;
            vframe_this[e64_vframe_waddr]      <= e64_vframe_this_wdata;
            vframe_env[e64_vframe_waddr]       <= e64_vframe_env_wdata;
            vframe_fn[e64_vframe_waddr]        <= e64_vframe_fn_wdata;
            vframe_ctor[e64_vframe_waddr]      <= e64_vframe_ctor_wdata;
        end
    end

    // Same LUT-fit treatment for the pure-value metadata writers. vobj_len
    // and venv_len STAY as FFs: their read-modify-write sites sit on the
    // 2-beat heap loop where a strobed (+1 beat) write could be read stale.
    // vobj_len / venv_len: strobed writes land one beat later than the old
    // direct writes; the read capture FORWARDS a same-address in-flight
    // write, restoring the exact original read-after-write timing (a
    // consumer whose raddr was armed on the write beat still sees the new
    // value on the next edge). This closes the RMW hazard that blocked the
    // first conversion attempt.
    logic        vol_we, vel_we;
    logic [12:0] vobj_len_ridx;
    logic [9:0]  venv_len_ridx;
    logic [12:0] vol_wa;
    logic [5:0]  vol_wd;
    logic [8:0]  vel_wa;
    logic [4:0]  vel_wd;
    always_ff @(posedge clk) begin
        if (vol_we) vobj_len[vol_wa[9:0]] <= vol_wd;
        else if (e32_vobj_len_we) vobj_len[e32_vobj_len_waddr[9:0]] <= e32_vobj_len_wdata;
        if (vel_we) venv_len[vel_wa] <= vel_wd;
        else if (e64_venv_len_we) venv_len[e64_venv_len_waddr[8:0]] <= e64_venv_len_wdata;
    end

    logic        vom_we_cls, vom_we_bi, veg_we;
    logic [12:0] vom_wa;
    logic [15:0] vom_cls;
    logic [3:0]  vom_bi;
    logic [8:0]  veg_wa;
    logic [11:0] veg_wd;
    logic        vog_we, vfg_we, vag_we;
    logic [9:0]  vog_wa, vfg_wa;
    logic [11:0] vag_wa;
    logic [11:0] vog_wd, vfg_wd, vag_wd;
    logic        vmko_we, vmkf_we, vmka_we, vmke_we;
    logic [9:0]  vmko_wa, vmkf_wa;
    logic [11:0] vmka_wa;
    logic [8:0]  vmke_wa;
    logic        vmko_wd, vmkf_wd, vmka_wd, vmke_wd;
    logic        vfv_we, vav_we, vev_we, vvv_we, vlo_we;
    logic [9:0]  vfv_wa;
    logic [10:0] vav_wa, vlo_wa;
    logic [8:0]  vev_wa, vvv_wa;
    logic        vfv_wd, vav_wd, vev_wd, vvv_wd, vlo_wd;
    logic        vli_we;
    logic [10:0] vli_wa;
    logic [7:0]  vli_wd;
    logic        alw_we;
    logic [10:0] alw_wa;
    logic [7:0]  alw_wd;
    logic        nof_we, nbl_we, nlt_we, flu_we;
    logic [9:0]  nof_wa, nbl_wa, nlt_wa, flu_wa;
    logic [15:0] nof_wd, nbl_wd;
    logic [7:0]  nlt_wd, flu_wd;
    logic        vlu_we;
    logic [6:0]  vlu_wa;
    logic        vlu_wd;
    logic        vtd_we, nh_we, txw_we, cse_we;
    logic [5:0]  vtd_wa, txw_wa;
    logic signed [31:0] vtd_wd;
    logic [9:0]  nh_wa;
    logic        nh_wd;
    logic [7:0]  txw_wd;
    logic [6:0]  cse_wa;
    logic [5:0]  cse_wd;
    always_ff @(posedge clk) begin
        if (vom_we_cls)
            vobj_cls[vom_wa[9:0]] <= vom_cls;
        else if (e64_vobj_cls_we)
            vobj_cls[e64_vobj_cls_waddr[9:0]] <= e64_vobj_cls_wdata;
        if (vom_we_bi) vobj_builtin[vom_wa[9:0]] <= vom_bi;
        if (veg_we) venv_gen[veg_wa] <= veg_wd;
        else if (e64_venv_gen_we) venv_gen[e64_venv_gen_waddr[8:0]] <= e64_venv_gen_wdata;
        if (vog_we) vobj_gen[vog_wa] <= vog_wd;
        if (vfg_we) vfn_gen[vfg_wa] <= vfg_wd;
        if (vag_we) varr_gen[vag_wa] <= vag_wd;
        if (vmko_we) vobj_mark[vmko_wa] <= vmko_wd;
        if (vmkf_we) vfn_mark[vmkf_wa] <= vmkf_wd;
        if (vmka_we) varr_mark[vmka_wa] <= vmka_wd;
        if (vmke_we) venv_mark[vmke_wa] <= vmke_wd;
        // e64_*_we are one-shot pulses (exec clears them on its first
        // idle beat — see the exec-write region comment). The else-if
        // drops an e64 write only if a parent strobe fires the same beat;
        // parent metadata strobes fire mid-state, e64 pulses land on the
        // leave-EXEC beat, so the two never coincide today. If a state
        // ever strobes metadata on its FIRST beat, revisit this priority.
        if (vfv_we) vfn_valid[vfv_wa] <= vfv_wd;
        if (vav_we) varr_valid[vav_wa] <= vav_wd;
        else if (e64_varr_valid_we) varr_valid[e64_varr_valid_waddr[10:0]] <= e64_varr_valid_wdata;
        if (vev_we) venv_valid[vev_wa] <= vev_wd;
        else if (e64_venv_valid_we) venv_valid[e64_venv_valid_waddr[8:0]] <= e64_venv_valid_wdata;
        if (vvv_we) vvar_valid[vvv_wa] <= vvv_wd;
        else if (e64_vvar_valid_we) vvar_valid[e64_vvar_valid_waddr[8:0]] <= e64_vvar_valid_wdata;
        if (vlo_we) varr_long[vlo_wa] <= vlo_wd;
        else if (e64_varr_long_we) varr_long[e64_varr_long_waddr[10:0]] <= e64_varr_long_wdata;
        if (vli_we) varr_lidx[vli_wa] <= vli_wd;
        else if (e64_varr_lidx_we) varr_lidx[e64_varr_lidx_waddr[10:0]] <= e64_varr_lidx_wdata;
        if (alw_we) arr_len[alw_wa] <= alw_wd;
        if (nof_we) begin
            name_off[nof_wa] <= nof_wd;
            name_off_r1[nof_wa] <= nof_wd;
            name_off_r2[nof_wa] <= nof_wd;
            name_off_r3[nof_wa] <= nof_wd;
        end
        if (nbl_we) begin
            name_blen[nbl_wa] <= nbl_wd;
            name_blen_r1[nbl_wa] <= nbl_wd;
        end
        if (nlt_we) begin
            name_len_tbl[nlt_wa] <= nlt_wd;
            name_len_tbl_r1[nlt_wa] <= nlt_wd;
        end
        if (flu_we) fill_lut[flu_wa] <= flu_wd;
        if (vlu_we) vlong_used[vlu_wa] <= vlu_wd;
        if (vtd_we) vtimer_due[vtd_wa] <= vtd_wd;
        if (txw_we) txt_buf[txw_wa] <= txw_wd;
        if (cse_we) cstack_env[cse_wa] <= cse_wd;
        if (cmn_we) cls_mname[cmn_wa] <= cmn_wd;
        if (cmi_we) cls_mip[cmi_wa] <= cmi_wd;
        clsm_name_rd <= cls_mname[clsm_raddr];
        clsm_ip_rd <= cls_mip[clsm_raddr];
    end

    logic        vobj_we, varr_we, venv_we;
    logic [VOBJ_AW-1:0] vobj_waddr, vobj_raddr;
    logic [VARR_AW-1:0] varr_waddr, varr_raddr;
    logic [VENV_AW-1:0] venv_waddr, venv_raddr;
    logic [79:0] vobj_wdata, vobj_rdata;
    logic [79:0] venv_wdata, venv_rdata;
    logic [2:0]  vobj_trdata, varr_trdata, hp_tag_ff;
    logic [2:0]  hp_tag;
    logic [63:0] varr_wdata, varr_rdata;

    // Two-tier array address (not MAX_ARR×128 concat). long/lidx are SRAM:
    // raddr this clock, varr_long_rdata / varr_lidx_rdata next (never peek).
    function automatic [VARR_AW-1:0] varr_slot_addr;
        input [11:0] aid;
        input [6:0] slot;
        begin
            // Linear 1-D (same as sim/sim_main.cpp varr_addr). Packed
            // {1'b0,aid[9:0],slot[4:0]} only had 1024 unique short rows.
            if (varr_long_rdata)
                varr_slot_addr = VARR_AW'(VARR_SHORT_WORDS
                    + {1'b0, varr_lidx_rdata, slot});
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
    logic [3:0]  hp_cmd_ff;
    logic [3:0]  hp_cmd;
    logic        hp_v64_ff;
    logic        hp_v64;
    logic [12:0] hp_oid_ff;
    logic [12:0] hp_oid;
    logic [11:0] hp_aid_ff;
    logic [11:0] hp_aid;
    logic        hp_env_ff;
    logic        hp_env; // S_HEAP_* talks to venv_slot (LOAD/STORE/LET/ctor)
    logic [9:0]  hp_eid_ff;
    logic [9:0]  hp_eid;
    logic [4:0]  hp_slot_ff;
    logic [4:0]  hp_slot;
    logic [6:0]  hp_aslot_ff;
    logic [6:0]  hp_aslot;
    logic [5:0]  hp_len_ff;
    logic [5:0]  hp_len;
    logic [7:0]  hp_alen_ff, hp_lim_ff;
    logic [7:0]  hp_alen, hp_lim;
    logic [15:0] hp_key_ff;
    logic [15:0] hp_key;
    logic [63:0] hp_wval_ff, hp_rval_ff;
    logic [63:0] hp_wval, hp_rval;
    logic        hp_hit_ff;
    logic        hp_hit;
    st_t         hp_ret_ff;
    st_t         hp_ret;
    st_t         rel_ret, bind_ret;
    st_t         vst_refill_ret;
    logic [2:0]  hp_phase_ff;
    logic [2:0]  hp_phase;
    logic [63:0] hp_proto_ff;
    logic [63:0] hp_proto;
    logic [15:0] hp_qk_ff [0:3];
    logic [15:0] hp_qk [0:3];
    logic [63:0] hp_qv_ff [0:3];
    logic [63:0] hp_qv [0:3];
    logic [2:0]  hp_qt_ff [0:3];
    logic [2:0]  hp_qt [0:3];
    logic [2:0]  hp_qn_ff, hp_qi_ff;
    logic [2:0]  hp_qn, hp_qi;
    logic        vgc_rd_arm, jn_rd_arm, vfe_rd_arm, vjs_rd_arm;
    // S_V64_STRIDX: name_rdata then char_id_rdata (two Port A lags).
    logic        stridx_rd_arm;
    // flatten: second beat after varr_rdata / vobj_rdata so name_hash raddr
    // can follow the intern id (stale 0 = wait, never peek).
    logic        jn_name_arm, vjs_name_arm, tfn_rd_arm;
    // flatten: long_rdata then slot raddr (JOIN/IDXOF/FOREACH/JSON/GC_ARR).
    logic        jn_slot_arm /*verilator public_flat_rd*/;
    // flatten: HEAP_WAIT / HEAP_AWR long_rdata then slot raddr/waddr.
    logic        hp_slot_arm;
    // Same-oid/eid slot++ stays in HEAP_CMP one extra clock (Port A rdata
    // + overlay latch into exec hp_slot_q). Do not combo-peek; do not
    // bounce to HEAP_WAIT (that was 3 extra beats per key).
    logic        hp_slot_pend;
    // flatten: mark_task latches the handle; next beats consume *_rdata.
    logic        vgc_mark_pend /*verilator public_flat_rd*/, vgc_mark_arm;
    logic [63:0] vgc_mark_word /*verilator public_flat_rd*/;
    // ALLOC free-scan wait. Do not reuse jn_rd_arm — JOIN after a take
    // would skip its length beat (arm stays 1).
    logic        valloc_rd_arm;
    // flatten: HEAP proto follow / ASSIGN nsv — raddr = hp_proto this clock.
    logic        hp_proto_arm /*verilator public_flat_rd*/;
    // venv_len_rdata is a registered read. LET_VAR picks the new slot
    // with it AND increments the length with it, so using it in the same
    // beat it is requested makes every declaration land in slot 0 and the
    // length never advance: a program whose top level runs inside an env
    // (INVADERS) lost every top-level `let`, and reads fell through to an
    // empty vvars entry. One settle beat before it is used.
    logic        env_len_arm;
    // flatten: json_mem is 8K SRAM; rdata next clock (PARSE/REPL/IDXSTR/TXT).
    logic [7:0]  json_mem_rdata, json_ch0;
    logic [12:0] json_rdaddr;
    logic        vlong_used_rdata;
    logic        gc_obj_mark_rdata, gc_arr_mark_rdata;
    logic signed [31:0] vtimer_due_rdata;
    logic [63:0] vtimer_fn_rdata;
    logic signed [63:0] vtimer_period_rdata;
    logic [63:0] vlistener_ev_rdata, vlistener_fn_rdata;
    // FRAME_TIMER / FRAME_KEY sequential scan (not N parallel SRAM ports).
    logic        vt_found, vk_found;
    logic [6:0]  vt_pick;
    logic [4:0]  vk_pick;
    logic signed [31:0] vt_best_due, vt_best_id;
    // flatten: latch due timer/rAF handle; unique case consumes *_rdata.
    logic [15:0] to_fire_fn, to_fire_id;
    logic        e32_env_cap_rdata;
    logic [13:0] gc_queue_rdata;
    logic [16:0] vgc_queue_rdata;
    logic [15:0] e32_raf_fn_rdata;
    logic [15:0] e32_raf_tap1, e32_raf_tap2, e32_raf_tap3, e32_raf_tap4;
    logic [15:0] e32_raf_tap5, e32_raf_tap6, e32_raf_tap7;
    logic [15:0] e32_kd_slot_rdata, e32_ku_slot_rdata;
    logic [12:0] hp_si_ff, hp_ti;
    logic [12:0] hp_si;
    logic [4:0]  hp_ss_ff;
    logic [4:0]  hp_ss;
    logic [5:0]  hp_tn_ff;
    logic [5:0]  hp_tn;
    // Sequential array init copies stack[hp_vbase+i] (regs, not SRAM mux).
    logic        hp_from_stack_ff;
    logic        hp_from_stack;
    logic        hp_make_arr_ff;
    logic        hp_make_arr; // MAKE_ARRAY: write handle after fill (not before)
    logic [11:0] hp_vbase_ff;
    logic [11:0] hp_vbase;
    logic [15:0] hp_spr_w_ff, hp_spr_h_ff;
    logic [15:0] hp_spr_w, hp_spr_h;
    // OGETI continuation: 0 parse 1 putimg 2 meas 3 idxof 4 repl 5 regex
    logic [3:0]  hp_nat_ff;
    logic [3:0]  hp_nat;

    // #40 Array.slice scratch
    logic [11:0] sl_src, sl_dst;
    logic [7:0] sl_i, sl_end, sl_di;
    // #41 Array.sort scratch: j cursor, pass-swapped flag, the two elements.
    logic [7:0] so_j;
    logic so_swapped;
    // #60: listener-count snapshot at key-event dispatch — listeners added
    // DURING a dispatch must not run for the same event (browser defers to
    // the next event; DONKEY's title Enter also fired the character-select
    // handler it had just registered, skipping that screen).
    logic [4:0] vkey_ln;
    logic [63:0] so_a, so_b;
    // NEW: S_ARR_DCOPY scratch (SET_PROP array-over-array deep row copy)
    logic [11:0] dc_src, dc_dst;
    logic [7:0]  dc_i;
    logic        dc_arm;

    logic [15:0] c_i;
    // NEW: 10-bit coords for 640×480 (was 8-bit mini after scale4)
    logic [9:0]  rx, ry, rw, rh, x, y;
    logic [7:0]  color;
    // Scaled-blit source coords: per-pixel divides replaced by an exact
    // DDA (floor((x*sw)/rw) == x*(sw/rw) + floor(x*(sw%rw)/rw), carried
    // incrementally). qx/rx_r/qy/ry_r come from the blit_div_ph setup
    // divides at S_BLIT entry; the DDA advances with the put-beat walk.
    logic [15:0] dda_sx, dda_ax, dda_sy, dda_ay;
    logic [15:0] bdiv_qx, bdiv_rx, bdiv_qy, bdiv_ry;
    logic [1:0]  blit_div_ph;   // 0 idle/done, 1 dividing sw/rw, 2 sh/rh
    logic [4:0]  bdiv_i;
    logic [15:0] bdiv_quo;
    logic [16:0] bdiv_rem;      // one bit wider than the 16-bit divisor
    logic [15:0] bdiv_num, bdiv_den;
    // spr_so multiply deleted (run 50/51 C1): the per-pixel source
    // offset lives in jmr_raster_engine as an incremental DDA — the
    // 16x22 multiply left the netlist with it. spr_so/spr_raddr are
    // unread now (S_SPR uploads use spr_wp).
    always_comb begin
        spr_so = 22'd0;
        spr_raddr = 18'd0;
    end
    // flatten: sin_q raddr from sin_turn (not function peek / unique-case ROM).
    assign sin_raddr = sin_turn[14] ? (8'd255 - sin_turn[13:6]) : sin_turn[13:6];
    logic [18:0] clr_idx;
    // C1: engine-wait flags. rast_go is a STROBE (default-cleared every
    // beat); rast_wait/rast_started are STATE (potential-bugs #73 class:
    // never put a handshake flag in the default-clear block).
    logic rast_wait;
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
    // v64_mul_task deleted 2026-08-27 (run 50): its only caller was the
    // rAF timestamp; that product is now the sequential raf engine (see
    // raf_pack_n). exec64 made the same move on 2026-08-24 (fpm/nwm).

    // v64_norm_shift / v64_unbiased_exp / v64_handle: jmr_value_pkg

    // Mark one valid stable handle and enqueue it exactly once. Future frame
    // and queue roots enter through this same single-word root interface.
    task automatic v64_gc_mark_task(input logic [63:0] word);
        begin
            vgc_mark_word <= word;
            vgc_mark_pend <= 1'b1;
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
    // flatten: unique case / tasks consume e32_tfn_entry_rdata (raddr last beat).
    function automatic logic [15:0] fn_entry(input logic [15:0] oid);
        fn_entry = e32_tfn_entry_rdata;
    endfunction
    function automatic logic [7:0] fn_nparam(input logic [15:0] oid);
        fn_nparam = 8'd0;
    endfunction
    // NEW: live heap env (FM env dict). Parent oid in slot0.
    task automatic push_fresh_env(input logic [15:0] parent);
        logic [15:0] oid;
        if (env_sp < TAGGED_ENV_DEPTH[5:0]) begin
            if (env_free_n != 6'd0) begin
                oid = e32_env_free_rdata;
                env_free_n <= env_free_n - 6'd1;
            end else begin
                oid = n_obj;
                if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
            end
            ; // p3b: dead tagged write removed (obj_cls)
            ; // p3b: dead tagged write removed (obj_n)
            ; // p3b: dead tagged write removed (tenv_parent)
            begin vol_we <= 1'b1; vol_wa <= oid[12:0]; vol_wd <= 6'd1; end
            ; // p3b: dead tagged write removed (env_oid)
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
        // flatten: obj_n / tfn_* raddr last beat (FOREACH/KEYEV/rAF/METH mux).
        parent = (e32_obj_n_rdata > 6'd2) ? e32_tfn_parent_rdata : 16'd0;
        begin cse_we <= 1'b1; cse_wa <= csp; cse_wd <= env_sp; end
        push_fresh_env(parent);
        // Fn slot3 is the receiver captured by an arrow or a materialized
        // class method. Regular callbacks deliberately enter with no `this`.
        if (e32_obj_n_rdata > 6'd3 && e32_tfn_has_this_rdata) begin
            this_obj <= e32_tfn_this_rdata;
            if (this_ok) begin
                ; // p3b: dead tagged write removed (vars)
                ; // p3b: dead tagged write removed (var_tag)
            end
        end else begin
            this_obj <= 16'hFFFF;
            if (this_ok) begin
                ; // p3b: dead tagged write removed (vars)
                ; // p3b: dead tagged write removed (var_tag)
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
        hs_st(S_REL_ENV);
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
    genvar gi_vst;
    generate
        for (gi_vst = 0; gi_vst < 16; gi_vst++) begin : g_vst_pack
            assign vst_win_pack[64*gi_vst +: 64] = vst_win[gi_vst];
        end
    endgenerate
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
    // potential-bugs #56: exec's vst_we_q is REGISTERED and exec freezes
    // after issuing a multi-beat parent op. The stale write request then
    // REPLAYED on the returning FETCH_WAIT beat, overwriting the parent's
    // result (join's pre-written UNDEFINED clobbered the interned handle —
    // code.join('') read undefined with joinmiss=0). An exec write is valid
    // exactly one beat after an enabled exec beat: the leave beat for
    // hand-off ops, the next fetch/exec beat for 1-beat ops.
    logic e64_wr_ok;
    always_ff @(posedge clk) begin
        if (!rst_n) e64_wr_ok <= 1'b0;
        else e64_wr_ok <= (state == S_V64_EXEC) && !e64_leave_hold;
    end

    // Full-depth TOS window push. Sites that plant a pushed value with
    // vst_hold_win must shift ALL 16 slots: hold_win suppresses the
    // automatic shift, so hand-shifting only win[1] left win[2..15] one
    // slot behind. Every value deeper than the new TOS was then read from
    // the wrong slot — `x + 6 * s` in a function lost `x` (INVADERS
    // drawCannon painted at 12,438 instead of 312,438; drawBitmap's y
    // collapsed so every sprite stacked on one row).
    task automatic vst_push_win(input logic [63:0] v);
        integer wi;
        for (wi = 15; wi > 0; wi = wi - 1)
            vst_win[wi] <= vst_win[wi - 1];
        vst_win[0] <= v;
    endtask
    // 32-bit stack / tag: same we/waddr/wdata shape as json_putc (UG901 Port A).
    task automatic stack_wr(
        input logic [10:0] addr,
        input logic signed [31:0] data,
        input logic [2:0] tag
    );
        // p3b (2026-08-22): the tagged eval stack is unreachable (images
        // without FLAG_VALUE64 fault 9 at load) but the v64_on fold could
        // not prove it to synthesis - ~330k FF bits of tagged arrays
        // survived and cost ~1M LUTs of state-decode. Writes neutered;
        // reader logic sweeps to constants. FPGA-SIM behavior unchanged.
    endtask
    task automatic name_hash_wr(input logic [9:0] addr, input logic [15:0] data);
        name_hash_we <= 1'b1;
        name_hash_waddr <= addr;
        name_hash_wdata <= data;
    endtask
    // Remember a FIND hit/alloc in slot 0 (shift). Skip if id already cached.
    task automatic jn_cache_remember(input logic [15:0] id);
        if ((jn_hit_v[0] && jn_hit_i0 == id) ||
            (jn_hit_v[1] && jn_hit_i1 == id) ||
            (jn_hit_v[2] && jn_hit_i2 == id) ||
            (jn_hit_v[3] && jn_hit_i3 == id)) begin
        end else begin
            jn_hit_h3 <= jn_hit_h2; jn_hit_l3 <= jn_hit_l2; jn_hit_i3 <= jn_hit_i2;
            jn_hit_h2 <= jn_hit_h1; jn_hit_l2 <= jn_hit_l1; jn_hit_i2 <= jn_hit_i1;
            jn_hit_h1 <= jn_hit_h0; jn_hit_l1 <= jn_hit_l0; jn_hit_i1 <= jn_hit_i0;
            jn_hit_h0 <= jn_h; jn_hit_l0 <= jn_len; jn_hit_i0 <= id;
            jn_hit_v  <= {jn_hit_v[2:0], 1'b1};
        end
    endtask
    task automatic varr_len_wr(input logic [11:0] addr, input logic [7:0] data);
        varr_len_we <= 1'b1;
        varr_len_waddr <= addr;
        varr_len_wdata <= data;
    endtask
    task automatic vobj_alloc_wr(input logic [9:0] addr, input logic [1:0] data);
        vobj_alloc_we <= 1'b1;
        vobj_alloc_waddr <= addr;
        vobj_alloc_wdata <= data;
    endtask
    task automatic vvars_wr(input logic [8:0] addr, input logic [63:0] data);
        vvars_we <= 1'b1;
        vvars_waddr <= addr;
        vvars_wdata <= data;
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
    // flatten: shift 2-deep cstack window from the same literals as SRAM[csp].
    task automatic cstk_win_shift_push(
        input logic [15:0] ip_i,
        input logic [15:0] this_i,
        input logic isctor_i,
        input logic isfe_i
    );
        cs_win2_ip <= cs_win1_ip;
        cs_win2_this <= cs_win1_this;
        cs_win2_isctor <= cs_win1_isctor;
        cs_win2_isfe <= cs_win1_isfe;
        cs_win2_ctorobj <= cs_win1_ctorobj;
        cs_win2_fe_arr <= cs_win1_fe_arr;
        cs_win2_fe_fn <= cs_win1_fe_fn;
        cs_win2_fe_i <= cs_win1_fe_i;
        cs_win2_map_arr <= cs_win1_map_arr;
        cs_win2_env <= cs_win1_env;
        cs_win1_ip <= ip_i;
        cs_win1_this <= this_i;
        cs_win1_isctor <= isctor_i;
        cs_win1_isfe <= isfe_i;
        cs_win1_ctorobj <= 16'd0;
        cs_win1_fe_arr <= 16'd0;
        cs_win1_fe_fn <= 16'd0;
        cs_win1_fe_i <= 8'd0;
        cs_win1_map_arr <= 16'd0;
        cs_win1_env <= env_sp;
    endtask
    task automatic cstk_push_ret(input logic [15:0] ip_i, input logic [15:0] this_i);
        ; // p3b: dead tagged write removed (cstack_ip)
        ; // p3b: dead tagged write removed (cstack_this)
        cstack_isctor[csp] <= 1'b0;
        cstack_isfe[csp] <= 1'b0;
        cstk_win_shift_push(ip_i, this_i, 1'b0, 1'b0);
        bump_csp();
    endtask
    task automatic cstk_arm_frame(input logic [15:0] ip_i, input logic [15:0] this_i);
        ; // p3b: dead tagged write removed (cstack_ip)
        ; // p3b: dead tagged write removed (cstack_this)
        cstack_isctor[csp] <= 1'b0;
        cstack_isfe[csp] <= 1'b0;
        cs_pend_ip <= ip_i;
        cs_pend_this <= this_i;
        cs_pend_valid <= 1'b1;
    endtask
    task automatic cstk_pop1();
        cs_win1_ip <= cs_win2_ip;
        cs_win1_this <= cs_win2_this;
        cs_win1_isctor <= cs_win2_isctor;
        cs_win1_isfe <= cs_win2_isfe;
        cs_win1_ctorobj <= cs_win2_ctorobj;
        cs_win1_fe_arr <= cs_win2_fe_arr;
        cs_win1_fe_fn <= cs_win2_fe_fn;
        cs_win1_fe_i <= cs_win2_fe_i;
        cs_win1_map_arr <= cs_win2_map_arr;
        cs_win1_env <= cs_win2_env;
        if (csp >= 7'd3) begin
            cs_refill <= 2'd1;
            cs_refill_win1 <= 1'b0;
            cs_raddr_ff <= csp - 7'd3;
            cs_refill_arm <= 1'b0;
        end
        csp <= csp - 7'd1;
    endtask
    task automatic cstk_pop2();
        if (csp >= 7'd3) begin
            cs_refill <= (csp >= 7'd4) ? 2'd2 : 2'd1;
            cs_refill_win1 <= 1'b1;
            cs_raddr_ff <= csp - 7'd3;
            cs_refill_arm <= 1'b0;
        end
        csp <= csp - 7'd2;
    endtask
    task automatic cstk_win_load1();
        cs_win1_ip <= e32_cs1_ip_rdata;
        cs_win1_this <= e32_cs1_this_rdata;
        cs_win1_isctor <= e32_cs1_isctor_rdata;
        cs_win1_isfe <= e32_cs1_isfe_rdata;
        cs_win1_ctorobj <= e32_cs1_ctorobj_rdata;
        cs_win1_fe_arr <= e32_cs1_fe_arr_rdata;
        cs_win1_fe_fn <= e32_cs1_fe_fn_rdata;
        cs_win1_fe_i <= e32_cs1_fe_i_rdata;
        cs_win1_map_arr <= e32_cs1_map_arr_rdata;
        cs_win1_env <= e32_cs1_env_rdata;
    endtask
    task automatic cstk_win_load2();
        cs_win2_ip <= e32_cs1_ip_rdata;
        cs_win2_this <= e32_cs1_this_rdata;
        cs_win2_isctor <= e32_cs1_isctor_rdata;
        cs_win2_isfe <= e32_cs1_isfe_rdata;
        cs_win2_ctorobj <= e32_cs1_ctorobj_rdata;
        cs_win2_fe_arr <= e32_cs1_fe_arr_rdata;
        cs_win2_fe_fn <= e32_cs1_fe_fn_rdata;
        cs_win2_fe_i <= e32_cs1_fe_i_rdata;
        cs_win2_map_arr <= e32_cs1_map_arr_rdata;
        cs_win2_env <= e32_cs1_env_rdata;
    endtask
    task automatic cstk_win_from_wdata();
        cs_win1_ip <= e32_cstack_ip_wdata;
        cs_win1_this <= e32_cstack_this_wdata;
        cs_win1_isctor <= e32_cstack_isctor_wdata;
        cs_win1_isfe <= e32_cstack_isfe_wdata;
        cs_win1_ctorobj <= e32_cstack_ctorobj_wdata;
        cs_win1_fe_arr <= e32_cstack_fe_arr_wdata;
        cs_win1_fe_fn <= e32_cstack_fe_fn_wdata;
        cs_win1_fe_i <= e32_cstack_fe_i_wdata;
        cs_win1_map_arr <= e32_cstack_map_arr_wdata;
        cs_win1_env <= e32_cstack_env_wdata;
    endtask
    task automatic cstk_win_shift_to_2();
        cs_win2_ip <= cs_win1_ip;
        cs_win2_this <= cs_win1_this;
        cs_win2_isctor <= cs_win1_isctor;
        cs_win2_isfe <= cs_win1_isfe;
        cs_win2_ctorobj <= cs_win1_ctorobj;
        cs_win2_fe_arr <= cs_win1_fe_arr;
        cs_win2_fe_fn <= cs_win1_fe_fn;
        cs_win2_fe_i <= cs_win1_fe_i;
        cs_win2_map_arr <= cs_win1_map_arr;
        cs_win2_env <= cs_win1_env;
    endtask
    task automatic boundary_sp(input logic [10:0] next_sp);
        // One callback return value is permitted; anything more is a real
        // stack-balance defect and must remain visible as a machine fault.
        if (sp > 11'd1) dbg_stack_ovf <= dbg_stack_ovf + 16'd1;
        sp <= next_sp;
    endtask
    task automatic gc_mark_obj(input logic [15:0] oid);
        // flatten: latch; unique case stalls and consumes gc_*_mark_rdata.
        begin
            vgc_mark_word <= {47'd0, 1'b0, oid};
            vgc_mark_pend <= 1'b1;
        end
    endtask
    task automatic gc_mark_value(input logic [2:0] tag, input logic [31:0] value);
        logic [15:0] oid;
        oid = value[15:0];
        if (tag == 3'd2) begin
            vgc_mark_word <= {47'd0, 1'b1, oid};
            vgc_mark_pend <= 1'b1;
        end else if (tag == 3'd1 || tag == 3'd4 || tag == 3'd6) begin
            gc_mark_obj(oid);
        end else if (tag == 3'd3 && oid < n_obj) begin
            // flatten: CLS_DYNSTR was obj_cls[oid] in this task (unique-case port).
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
    // unused — never combo stack[i] (Synth 8-4767 / flatten)
    function automatic logic signed [31:0] sti(input logic [10:0] i);
        sti = 32'sd0;
    endfunction
    // unused — never combo stack[i]
    function automatic logic signed [31:0] stfx(input logic [10:0] i);
        stfx = 32'sd0;
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
    // flatten: unique case consumes sin_q_rdata (raddr last beat).
    function automatic logic signed [16:0] sin_from_q(
        input logic [15:0] t, input logic [15:0] q);
        sin_from_q = t[15] ? -$signed({1'b0, q}) : $signed({1'b0, q});
    endfunction
    function automatic logic signed [16:0] sin_t(input logic [15:0] t);
        sin_t = sin_from_q(t, sin_q_rdata);
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

    task automatic e32_poke(input logic [5:0] sel, input logic [15:0] addr,
                            input logic [63:0] data);
        e32_p_we <= 1'b1;
        e32_p_sel <= sel;
        e32_p_addr <= addr;
        e32_p_data <= data;
    endtask
    task automatic hs_ip(input logic [15:0] v); ip_ff <= v; hs_m_ip <= 1'b1; endtask
    task automatic hs_code(input logic [14:0] v); code_raddr_ff <= v; hs_m_code <= 1'b1; endtask
    task automatic hs_st(input st_t s); state <= s; hs_m_state <= 1'b1; endtask
    task automatic hs_vsp(input logic [11:0] v); vsp_ff <= v; hs_m_vsp <= 1'b1; endtask
    task automatic hs_hp_cmd(input logic [3:0] v); hp_cmd_ff <= v; hs_m_hp_cmd <= 1'b1; endtask
    task automatic hs_hp_v64(input logic v); hp_v64_ff <= v; hs_m_hp_v64 <= 1'b1; endtask
    task automatic hs_hp_oid(input logic [12:0] v); hp_oid_ff <= v; hs_m_hp_oid <= 1'b1; endtask
    task automatic hs_hp_aid(input logic [11:0] v); hp_aid_ff <= v; hs_m_hp_aid <= 1'b1; endtask
    task automatic hs_hp_env(input logic v); hp_env_ff <= v; hs_m_hp_env <= 1'b1; endtask
    task automatic hs_hp_eid(input logic [9:0] v); hp_eid_ff <= v; hs_m_hp_eid <= 1'b1; endtask
    task automatic hs_hp_slot(input logic [4:0] v); hp_slot_ff <= v; hs_m_hp_slot <= 1'b1; endtask
    // Next key on the same object/env: one Port-A wait in HEAP_CMP.
    task automatic hp_next_slot();
        begin
            hs_hp_slot(hp_slot + 5'd1);
            hp_slot_pend <= 1'b1;
        end
    endtask
    task automatic hs_hp_aslot(input logic [6:0] v); hp_aslot_ff <= v; hs_m_hp_aslot <= 1'b1; endtask
    task automatic hs_hp_len(input logic [5:0] v); hp_len_ff <= v; hs_m_hp_len <= 1'b1; endtask
    task automatic hs_hp_alen(input logic [7:0] v); hp_alen_ff <= v; hs_m_hp_alen <= 1'b1; endtask
    task automatic hs_hp_lim(input logic [7:0] v); hp_lim_ff <= v; hs_m_hp_lim <= 1'b1; endtask
    task automatic hs_hp_key(input logic [15:0] v); hp_key_ff <= v; hs_m_hp_key <= 1'b1; endtask
    task automatic hs_hp_wval(input logic [63:0] v); hp_wval_ff <= v; hs_m_hp_wval <= 1'b1; endtask
    task automatic hs_hp_rval(input logic [63:0] v); hp_rval_ff <= v; hs_m_hp_rval <= 1'b1; endtask
    task automatic hs_hp_hit(input logic v); hp_hit_ff <= v; hs_m_hp_hit <= 1'b1; endtask
    task automatic hs_hp_ret(input st_t v); hp_ret_ff <= v; hs_m_hp_ret <= 1'b1; endtask
    task automatic hs_hp_phase(input logic [2:0] v); hp_phase_ff <= v; hs_m_hp_phase <= 1'b1; endtask
    task automatic hs_hp_proto(input logic [63:0] v); hp_proto_ff <= v; hs_m_hp_proto <= 1'b1; endtask
    task automatic hs_hp_qn(input logic [2:0] v); hp_qn_ff <= v; hs_m_hp_qn <= 1'b1; endtask
    task automatic hs_hp_qi(input logic [2:0] v); hp_qi_ff <= v; hs_m_hp_qi <= 1'b1; endtask
    task automatic hs_hp_si(input logic [12:0] v); hp_si_ff <= v; hs_m_hp_si <= 1'b1; endtask
    task automatic hs_hp_ss(input logic [4:0] v); hp_ss_ff <= v; hs_m_hp_ss <= 1'b1; endtask
    task automatic hs_hp_tn(input logic [5:0] v); hp_tn_ff <= v; hs_m_hp_tn <= 1'b1; endtask
    task automatic hs_hp_from_stack(input logic v); hp_from_stack_ff <= v; hs_m_hp_from_stack <= 1'b1; endtask
    task automatic hs_hp_make_arr(input logic v); hp_make_arr_ff <= v; hs_m_hp_make_arr <= 1'b1; endtask
    task automatic hs_hp_vbase(input logic [11:0] v); hp_vbase_ff <= v; hs_m_hp_vbase <= 1'b1; endtask
    task automatic hs_hp_spr_w(input logic [15:0] v); hp_spr_w_ff <= v; hs_m_hp_spr_w <= 1'b1; endtask
    task automatic hs_hp_spr_h(input logic [15:0] v); hp_spr_h_ff <= v; hs_m_hp_spr_h <= 1'b1; endtask
    task automatic hs_hp_nat(input logic [3:0] v); hp_nat_ff <= v; hs_m_hp_nat <= 1'b1; endtask
    task automatic hs_hp_tag(input logic [2:0] v); hp_tag_ff <= v; hs_m_hp_tag <= 1'b1; endtask
    task automatic hs_valloc_kind(input [1:0] v); valloc_kind_ff <= v; hs_m_valloc_kind <= 1'b1; endtask
    task automatic hs_valloc_i(input [13:0] v); valloc_i_ff <= v; hs_m_valloc_i <= 1'b1; endtask
    task automatic hs_valloc_arr_n(input [7:0] v); valloc_arr_n_ff <= v; hs_m_valloc_arr_n <= 1'b1; endtask
    task automatic hs_valloc_retried(input logic v); valloc_retried_ff <= v; hs_m_valloc_retried <= 1'b1; endtask
    task automatic hs_vnat_dom(input [2:0] v); vnat_dom_ff <= v; hs_m_vnat_dom <= 1'b1; endtask
    task automatic hs_vnat_base(input [11:0] v); vnat_base_ff <= v; hs_m_vnat_base <= 1'b1; endtask
    task automatic hs_valloc_now_fn(input logic v); valloc_now_fn_ff <= v; hs_m_valloc_now_fn <= 1'b1; endtask
    task automatic hs_valloc_bind(input logic v); valloc_bind_ff <= v; hs_m_valloc_bind <= 1'b1; endtask
    task automatic hs_valloc_bind_src(input [12:0] v); valloc_bind_src_ff <= v; hs_m_valloc_bind_src <= 1'b1; endtask
    task automatic hs_valloc_bind_this(input [63:0] v); valloc_bind_this_ff <= v; hs_m_valloc_bind_this <= 1'b1; endtask
    task automatic hs_valloc_fn_entry(input [15:0] v); valloc_fn_entry_ff <= v; hs_m_valloc_fn_entry <= 1'b1; endtask
    task automatic hs_valloc_fn_a1(input [7:0] v); valloc_fn_a1_ff <= v; hs_m_valloc_fn_a1 <= 1'b1; endtask
    task automatic hs_valloc_proto(input logic v); valloc_proto_ff <= v; hs_m_valloc_proto <= 1'b1; endtask
    task automatic hs_valloc_proto_fn(input [12:0] v); valloc_proto_fn_ff <= v; hs_m_valloc_proto_fn <= 1'b1; endtask
    task automatic hs_valloc_metrics(input logic v); valloc_metrics_ff <= v; hs_m_valloc_metrics <= 1'b1; endtask
    task automatic hs_valloc_regex(input logic v); valloc_regex_ff <= v; hs_m_valloc_regex <= 1'b1; endtask
    task automatic hs_valloc_regex_pack(input [31:0] v); valloc_regex_pack_ff <= v; hs_m_valloc_regex_pack <= 1'b1; endtask
    task automatic hs_vcall_value(input logic v); vcall_value_ff <= v; hs_m_vcall_value <= 1'b1; endtask
    task automatic hs_vcall_argc(input [11:0] v); vcall_argc_ff <= v; hs_m_vcall_argc <= 1'b1; endtask
    task automatic hs_vcall_entry(input [15:0] v); vcall_entry_ff <= v; hs_m_vcall_entry <= 1'b1; endtask
    task automatic hs_vcall_set_this(input logic v); vcall_set_this_ff <= v; hs_m_vcall_set_this <= 1'b1; endtask
    task automatic hs_vcall_this(input [63:0] v); vcall_this_ff <= v; hs_m_vcall_this <= 1'b1; endtask
    task automatic hs_vcall_ctor_val(input [63:0] v); vcall_ctor_val_ff <= v; hs_m_vcall_ctor_val <= 1'b1; endtask
    task automatic hs_vcsp(input [7:0] v); vcsp_ff <= v; hs_m_vcsp <= 1'b1; endtask
    task automatic hs_vthis(input [63:0] v); vthis_ff <= v; hs_m_vthis <= 1'b1; endtask
    task automatic hs_venv(input [63:0] v); venv_ff <= v; hs_m_venv <= 1'b1; endtask
    task automatic hs_vraf_n(input [3:0] v); vraf_n_ff <= v; hs_m_vraf_n <= 1'b1; endtask
    task automatic hs_vlistener_n(input [4:0] v); vlistener_n_ff <= v; hs_m_vlistener_n <= 1'b1; endtask
    task automatic hs_vgc_halt_after(input logic v); vgc_halt_after_ff <= v; hs_m_vgc_halt_after <= 1'b1; endtask
    task automatic hs_vgc_wait_after(input logic v); vgc_wait_after_ff <= v; hs_m_vgc_wait_after <= 1'b1; endtask
    task automatic hs_vgc_clear_i(input [13:0] v); vgc_clear_i_ff <= v; hs_m_vgc_clear_i <= 1'b1; endtask
    task automatic hs_vgc_qr(input [13:0] v); vgc_qr_ff <= v; hs_m_vgc_qr <= 1'b1; endtask
    task automatic hs_vgc_qw(input [13:0] v); vgc_qw_ff <= v; hs_m_vgc_qw <= 1'b1; endtask
    task automatic hs_vdraw_i(input [18:0] v); vdraw_i_ff <= v; hs_m_vdraw_i <= 1'b1; endtask
    task automatic hs_vdraw_x(input [9:0] v); vdraw_x_ff <= v; hs_m_vdraw_x <= 1'b1; endtask
    task automatic hs_vdraw_y(input [9:0] v); vdraw_y_ff <= v; hs_m_vdraw_y <= 1'b1; endtask
    task automatic hs_vdraw_w(input [9:0] v); vdraw_w_ff <= v; hs_m_vdraw_w <= 1'b1; endtask
    task automatic hs_vdraw_h(input [9:0] v); vdraw_h_ff <= v; hs_m_vdraw_h <= 1'b1; endtask
    task automatic hs_vdraw_color(input [7:0] v); vdraw_color_ff <= v; hs_m_vdraw_color <= 1'b1; endtask
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
            e64_p_data <= {data[63:44], vobj_gen_rdata, data[31:0]};
        else
            e64_p_data <= data;
    endtask
    task automatic json_putc(input logic [7:0] ch);
        if (json_wp < 14'(JSON_CAP)) begin
            // Write port only — do not poke json_mem[] from the FSM.
            json_we <= 1'b1;
            json_waddr <= json_wp[12:0];
            json_wdata <= ch;
            json_wp <= json_wp + 14'd1;
        end else dbg_json_ovf <= dbg_json_ovf + 16'd1;
    endtask
    task automatic next_op;
        hs_ip(ip + 16'd1);
        hs_code(15'(ops_base + ip + 16'd1));
        hs_st(S_FETCH_WAIT);
    endtask
    // After a ctor param LET_VAR: skip the compiler JUMP to class fields.
    task automatic ctor_after_let;
        if (vctor_lets == 6'd1 && vctor_jmp != 16'hFFFF) begin
            hs_ip(vctor_jmp);
            hs_code(15'(ops_base + vctor_jmp));
            vctor_jmp <= 16'hFFFF;
            vctor_lets <= 6'd0;
        end else begin
            hs_ip(ip + 16'd1);
            hs_code(15'(ops_base + ip + 16'd1));
            if (vctor_lets != 6'd0)
                vctor_lets <= vctor_lets - 6'd1;
        end
    endtask
    // NEW: consume one trailer byte; word wrap → S_RD (must not run on intern/done)
    task automatic trail_bump;
        if (trail_off[1:0] == 2'd3) begin
            hs_code(15'(trail_off[16:2] + 15'd1));
            trail_off <= trail_off + 16'd1;
            hs_st(S_RD);
            ret_state <= S_TRAIL;
        end         else trail_off <= trail_off + 16'd1;
    endtask

    // Object/array slot SRAM: 1 write + 1 registered read (VRAM Port A),
    // now pow2-chunked. Registered chunk selects keep the 1-beat contract.
    logic [79:0] vobj_r_c0, vobj_r_c1, vobj_r_c2, vobj_r_c3;
    logic [1:0]  vobj_rsel;
    logic [63:0] varr_r_c0, varr_r_c1, varr_r_c2;
    logic [1:0]  varr_rsel;
    logic [79:0] venv_r_c0, venv_r_c1;
    logic        venv_rsel;
    always_ff @(posedge clk) begin
        if (vobj_we) begin
            if (vobj_waddr < 15'd16384)
                vobj_slot_c0[vobj_waddr[13:0]] <= vobj_wdata;
            else if (vobj_waddr < 15'd24576)
                vobj_slot_c1[vobj_waddr[12:0] & 13'h1FFF] <= vobj_wdata;
            else if (vobj_waddr < 15'd28672)
                vobj_slot_c2[vobj_waddr[11:0] & 12'hFFF] <= vobj_wdata;
            else
                vobj_slot_c3[vobj_waddr[10:0] & 11'h7FF] <= vobj_wdata;
            vobj_tmem[vobj_waddr] <= (hp_cmd == HP_OSETI)
                ? hp_qt[hp_qi[1:0]] : hp_tag;
        end
        vobj_r_c0 <= vobj_slot_c0[vobj_raddr[13:0]];
        vobj_r_c1 <= vobj_slot_c1[(vobj_raddr - 15'd16384) & 15'h1FFF];
        vobj_r_c2 <= vobj_slot_c2[(vobj_raddr - 15'd24576) & 15'hFFF];
        vobj_r_c3 <= vobj_slot_c3[(vobj_raddr - 15'd28672) & 15'h7FF];
        vobj_rsel <= (vobj_raddr < 15'd16384) ? 2'd0 :
                     (vobj_raddr < 15'd24576) ? 2'd1 :
                     (vobj_raddr < 15'd28672) ? 2'd2 : 2'd3;
        vobj_trdata <= vobj_tmem[vobj_raddr];
        if (varr_we) begin
            if (varr_waddr < 16'd32768)
                varr_slot_c0[varr_waddr[14:0]] <= varr_wdata;
            else if (varr_waddr < 16'd49152)
                varr_slot_c1[varr_waddr[13:0] & 14'h3FFF] <= varr_wdata;
            else
                varr_slot_c2[varr_waddr[10:0] & 11'h7FF] <= varr_wdata;
            // 32-bit HEAP_FILL tag: registered (same addr as stack_rdata).
            varr_tmem[varr_waddr] <= (hp_from_stack && !hp_v64)
                ? e32_stack_tag_rdata
                : hp_tag;
        end
        varr_r_c0 <= varr_slot_c0[varr_raddr[14:0]];
        varr_r_c1 <= varr_slot_c1[(varr_raddr - 16'd32768) & 16'h3FFF];
        varr_r_c2 <= varr_slot_c2[(varr_raddr - 16'd49152) & 16'h7FF];
        varr_rsel <= (varr_raddr < 16'd32768) ? 2'd0 :
                     (varr_raddr < 16'd49152) ? 2'd1 : 2'd2;
        varr_trdata <= varr_tmem[varr_raddr];
        if (venv_we) begin
            if (venv_waddr < 13'd4096)
                venv_slot_c0[venv_waddr[11:0]] <= venv_wdata;
            else
                venv_slot_c1[venv_waddr[10:0] & 11'h7FF] <= venv_wdata;
        end
        venv_r_c0 <= venv_slot_c0[venv_raddr[11:0]];
        venv_r_c1 <= venv_slot_c1[(venv_raddr - 13'd4096) & 13'h7FF];
        venv_rsel <= (venv_raddr >= 13'd4096);
    end
    assign vobj_rdata = (vobj_rsel == 2'd0) ? vobj_r_c0 :
                        (vobj_rsel == 2'd1) ? vobj_r_c1 :
                        (vobj_rsel == 2'd2) ? vobj_r_c2 : vobj_r_c3;
    assign varr_rdata = (varr_rsel == 2'd0) ? varr_r_c0 :
                        (varr_rsel == 2'd1) ? varr_r_c1 : varr_r_c2;
    assign venv_rdata = venv_rsel ? venv_r_c1 : venv_r_c0;

    // Value64 operand stack: 1 write + 1 registered read (same as vobj_slot).
    // Exec keeps priority in its own states, but the arm must be
    // `e64_vst_we_q && <state>` — not `<state>` alone. vst_we is a
    // registered pulse, so a parent vst_wr() issued the same beat as
    // hs_st(S_FETCH_WAIT) lands with state already FETCH_WAIT and used to
    // be swallowed with no writer at all: MAKE_ARRAY planted its handle
    // only in vst_win (nested [[..],[..]] read back the inner's first
    // element), STRIDX_WR / S_V64_RECT lost their result the same way.
    // Still one write port — the two arms are mutually exclusive.
    always_ff @(posedge clk) begin
        if (e64_vst_we_q && e64_wr_ok &&
            (state == S_V64_EXEC ||
             state == S_FETCH_WAIT ||
             state == S_V64_WIN_FILL)) begin
            vstack[e64_vst_waddr_q[9:0]] <= e64_vst_wdata_q;
        end else if (vst_we)
            vstack[vst_waddr[9:0]] <= vst_wdata;
        vst_rdata <= vstack[vst_raddr[9:0]];
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
        // HEAP_AWR: first cycle muxes varr_long[hp_aid]; write when hp_slot_arm
        // (long_rdata valid). Stale 0 = wait, never peek.
        varr_we = (state == S_HEAP_AWR && hp_slot_arm) ||
            (state == S_HEAP_FILL &&
             !(hp_from_stack && hp_phase != 3'd1));
        varr_waddr = hp_prom_wr
            ? VARR_AW'(VARR_SHORT_WORDS + {1'b0, hp_prom_phys, hp_aslot})
            : varr_slot_addr(hp_aid, hp_aslot);
        // 32-bit arm: registered stack_rdata (never combo stack[i] — Synth 8-4767).
        varr_wdata = hp_from_stack
            ? (hp_v64
                ? vst_rdata
                : {32'd0, e32_stack_rdata})
            : hp_wval;
        varr_raddr = varr_slot_addr(hp_aid, hp_aslot);
        venv_we = (state == S_HEAP_WR) && hp_env;
        venv_waddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        venv_wdata = {7'd0, hp_key[8:0], hp_wval};
        venv_raddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        // Address mux only (narrow). unique is OK here; the 70 GB cone was
        // unique case (casestate) on the parent FSM, not this raddr comb.
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
                varr_raddr = varr_slot_addr(e64_vfe_arr_q[11:0], e64_vfe_i_q[6:0]);
            S_FOREACH:
                varr_raddr = varr_slot_addr(e32_cs1_fe_arr_rdata[11:0],
                    e32_cs1_fe_i_rdata[6:0]);
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
        // potential-bugs #53: exec-issued push enters S_HEAP_FILL with a
        // leave beat (casestate FILL, parent state still EXEC). The phase
        // 0->1 sequencer runs on casestate, but this raddr was gated on
        // parent state only, so the write beat stored vst_rdata registered
        // from the DEFAULT raddr (vsp-16 / 0) — a garbage word — into the
        // array slot. Length was right (varr_len_we in exec), elements were
        // junk: a.push(x); a[0] returned a stale stack word. Parent-issued
        // fills (MAKE_ARRAY literals via S_V64_ALLOC) have no leave beat,
        // which is why literals worked and push did not.
        // potential-bugs #58 (real cause): casestate_q lags one beat, so on
        // the FIRST S_V64_WIN_FILL beat after a make_arr fill this branch was
        // still taken (casestate_q==S_HEAP_FILL): raddr = hp_vbase+hp_aslot
        // (the LAST ELEMENT) instead of vsp-1-refill_i. The refill's first
        // consumed rdata was that element, so win[1] got e.g. 15.0 where the
        // receiver object should be — SET_PROP silently dropped `{m:[16+]}`
        // (PACMAN maze). Exclude the beat once state is WIN_FILL.
        if ((state == S_HEAP_FILL ||
             (casestate_q == S_HEAP_FILL && state != S_V64_WIN_FILL)) &&
            hp_from_stack && hp_v64)
            vst_raddr = hp_vbase + {5'd0, hp_aslot};
        else if (state == S_V64_BIND)
            vst_raddr = bind_src + {4'd0, bind_k};
        else if (state == S_V64_MINMAX)
            vst_raddr = minmax_base + {4'd0, minmax_k};
        else if (state == S_V64_WIN_FILL)
            vst_raddr = vsp - {8'd0, vst_refill_i} - 12'd1;
        else if (state == S_V64_RECT_LD)
            vst_raddr = vnat_base + 12'd1 + {10'd0, rect_ld_k};
        else if (state == S_V64_GC_ROOT && vgc_root_phase == 3'd1)
            vst_raddr = vgc_root_i;
    end
    // HEAP_FILL / ASSIGN: share exec32 stack read port (rdata next clock).
    always_comb begin
        stack_rd_a = e32_stack_raddr;
        if ((state == S_HEAP_FILL || casestate_q == S_HEAP_FILL) &&
            hp_from_stack && !hp_v64)
            stack_rd_a = hp_vbase[10:0] + {4'd0, hp_aslot};
        else if ((state == S_HEAP_WAIT || state == S_HEAP_CMP) &&
                 hp_cmd == HP_ASSIGN && hp_phase == 3'd3 && !hp_v64)
            stack_rd_a = hp_vbase[10:0] + {8'd0, hp_qi} + 11'd1;
        else if (state == S_ENV_LOAD && sp >= 11'd1)
            stack_rd_a = sp - 11'd1;
        else if (state == S_V64_METH && !hp_v64)
            stack_rd_a = ((sp >= {3'd0, vcall_argc[7:0]}) ?
                (sp - {3'd0, vcall_argc[7:0]} + {3'd0, bind_k}) : 11'd0);
        else if (state == S_GC_ROOT && gc_root_i >= 13'd512 &&
                 gc_root_i < 13'd2560)
            stack_rd_a = gc_root_i[10:0] - 11'd512;
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
    logic signed [31:0] e32_alu_a_q;
    logic signed [31:0] e32_alu_b_q;
    logic e32_alu_fx_q;
    logic [2:0] e32_alu_op_q;
    logic [15:0] e32_blit_sh_q;
    logic [7:0] e32_blit_si_q;
    logic [15:0] e32_blit_sw_q;
    logic [15:0] e32_blit_sx_q;
    logic [15:0] e32_blit_sy_q;
    logic [2:0] e32_cc_at_q;
    logic signed [31:0] e32_cc_av_q;
    logic e32_cc_bok_q;
    logic [2:0] e32_cc_bt_q;
    logic signed [31:0] e32_cc_bv_q;
    logic [3:0] e32_cc_d_q;
    logic [15:0] e32_cc_h_q;
    logic [7:0] e32_cc_len_q;
    logic e32_cc_second_q;
    logic [1:0] e32_cc_st_q;
    logic e32_click_fired_q;
    logic [15:0] e32_click_fn_q;
    logic [18:0] e32_clr_idx_q;
    logic [14:0] e32_code_raddr_q;
    logic [7:0] e32_color_q;
    logic [6:0] e32_csp_q;
    logic [1:0] e32_ctx_align_q;
    logic [7:0] e32_ctx_font_px_q;
    logic e32_ctx_smooth_q;
    logic signed [31:0] e32_ctx_sx_q;
    logic signed [31:0] e32_ctx_sy_q;
    logic signed [31:0] e32_ctx_tx_q;
    logic signed [31:0] e32_ctx_ty_q;
    logic [15:0] e32_dbg_call_ovf_q;
    logic [15:0] e32_dbg_cb_ip_q;
    logic [15:0] e32_dbg_di_hit_q;
    logic [15:0] e32_dbg_di_miss_q;
    logic [15:0] e32_dbg_div_n_q;
    logic [15:0] e32_dbg_find_hit_q;
    logic [15:0] e32_dbg_heap_ovf_q;
    logic [15:0] e32_dbg_json_ovf_q;
    logic [15:0] e32_dbg_path_ovf_q;
    logic [15:0] e32_dbg_splice_n_q;
    logic [15:0] e32_dbg_stack_ovf_q;
    logic [15:0] e32_dbg_tmr_sched_q;
    logic [15:0] e32_dbg_to_ovf_q;
    logic e32_did_swap_q;
    logic [5:0] e32_div_cnt_q;
    logic e32_div_int_in_q;
    logic e32_div_neg_q;
    logic [31:0] e32_div_rem_q;
    logic [31:0] e32_div_ub_q;
    logic [47:0] e32_div_uq_q;
    logic [5:0] e32_env_free_n_q;
    logic e32_env_is_store_q;
    logic [8:0] e32_env_ld_slot_q;
    logic [5:0] e32_env_sp_q;
    logic [15:0] e32_env_walk_q;
    logic [18:0] e32_fb_dump_addr_q;
    logic e32_fb_dump_sel_q;
    logic e32_fb_swap_q;
    logic [7:0] e32_fill_style_i_q;
    logic [7:0] e32_fp_left_q;
    logic [7:0] e32_fpx_acc_q;
    logic e32_frame_fire_q;
    logic [11:0] e32_hp_aid_q;
    logic [7:0] e32_hp_alen_q;
    logic [6:0] e32_hp_aslot_q;
    logic [3:0] e32_hp_cmd_q;
    logic e32_hp_from_stack_q;
    logic e32_hp_hit_q;
    logic [15:0] e32_hp_key_q;
    logic [5:0] e32_hp_len_q;
    logic [7:0] e32_hp_lim_q;
    logic e32_hp_make_arr_q;
    logic [3:0] e32_hp_nat_q;
    logic [12:0] e32_hp_oid_q;
    logic [2:0] e32_hp_phase_q;
    logic [63:0] e32_hp_proto_q;
    logic [2:0] e32_hp_qi_q;
    logic [2:0] e32_hp_qn_q;
    logic [6:0] e32_hp_ret_q;
    logic [63:0] e32_hp_rval_q;
    logic [12:0] e32_hp_si_q;
    logic [4:0] e32_hp_slot_q;
    logic [4:0] e32_hp_ss_q;
    logic [2:0] e32_hp_tag_q;
    logic [5:0] e32_hp_tn_q;
    logic e32_hp_v64_q;
    logic [11:0] e32_hp_vbase_q;
    logic [63:0] e32_hp_wval_q;
    logic [7:0] e32_idx_needle_q;
    logic [2:0] e32_idx_t_q;
    logic signed [31:0] e32_idx_v_q;
    logic e32_imgd_armed_q;
    logic [9:0] e32_imgd_h_q;
    logic [18:0] e32_imgd_i_q;
    logic [18:0] e32_imgd_n_q;
    logic [10:0] e32_imgd_res_q;
    logic [9:0] e32_imgd_w_q;
    logic [9:0] e32_imgd_x_q;
    logic [9:0] e32_imgd_x0_q;
    logic [9:0] e32_imgd_y_q;
    logic [9:0] e32_imgd_y0_q;
    logic [15:0] e32_ip_q;
    logic [11:0] e32_jn_arr_q;
    logic [15:0] e32_jn_h_q;
    logic [15:0] e32_jn_i_q;
    logic [10:0] e32_jn_res_q;
    logic [5:0] e32_js_sp_q;
    logic [13:0] e32_json_dst_q;
    logic [2:0] e32_json_pph_q;
    logic [10:0] e32_json_res_q;
    logic [13:0] e32_json_rp_q;
    logic [13:0] e32_json_src_q;
    logic [13:0] e32_json_srclen_q;
    logic [13:0] e32_json_wp_q;
    logic [2:0] e32_kd_n_q;
    logic [15:0] e32_kev_fn_q;
    logic e32_kev_is_down_q;
    logic [1:0] e32_kev_li_q;
    logic [15:0] e32_kev_obj_q;
    logic [15:0] e32_kev_ret_ip_q;
    logic [15:0] e32_keys_a_oid_q;
    logic [15:0] e32_keys_d_oid_q;
    logic [15:0] e32_keys_sp_oid_q;
    logic [2:0] e32_ku_n_q;
    logic [31:0] e32_lfsr_q;
    logic e32_looping_q;
    logic [15:0] e32_metrics_oid_q;
    logic signed [31:0] e32_mul_a_q;
    logic signed [31:0] e32_mul_b_q;
    logic e32_mul_fx_a_q;
    logic e32_mul_fx_b_q;
    logic [15:0] e32_n_arr_q;
    logic [15:0] e32_n_arr_keep_q;
    logic [6:0] e32_n_fn_proto_q;
    logic [15:0] e32_n_obj_q;
    logic [15:0] e32_n_obj_keep_q;
    logic e32_namcpy_armed_q;
    logic e32_namcpy_repl_q;
    logic [15:0] e32_name_rdaddr_q;
    logic [7:0] e32_nat_argc_q;
    logic [7:0] e32_nat_id_q;
    logic e32_path_active_q;
    logic [1:0] e32_path_kind_q;
    logic e32_path_stroke_q;
    logic [4:0] e32_pc_n_q;
    logic [4:0] e32_pi_q;
    logic e32_present_pend_q;
    logic [3:0] e32_raf_n_q;
    logic [5:0] e32_rel_i_q;
    logic [5:0] e32_rel_lim_q;
    logic [5:0] e32_rel_nn_q;
    logic [6:0] e32_rel_ret_q;
    logic [5:0] e32_rel_saved_q;
    logic e32_repl_did_q;
    logic e32_repl_g_q;
    logic [7:0] e32_repl_nlen_q;
    logic [7:0] e32_repl_pat0_q;
    logic [7:0] e32_repl_pat1_q;
    logic [7:0] e32_repl_rch_q;
    logic [9:0] e32_rh_q;
    logic e32_running_q;
    logic [9:0] e32_rw_q;
    logic [9:0] e32_rx_q;
    logic [9:0] e32_ry_q;
    logic signed [31:0] e32_saved_sx_q;
    logic signed [31:0] e32_saved_sy_q;
    logic signed [31:0] e32_saved_tx_q;
    logic signed [31:0] e32_saved_ty_q;
    logic [10:0] e32_sp_q;
    logic [4:0] e32_sq_i_q;
    logic [47:0] e32_sq_rad_q;
    logic [25:0] e32_sq_rem_q;
    logic [23:0] e32_sq_root_q;
    logic [6:0] e32_state_q;
    logic signed [31:0] e32_str_pf_ci_q;
    logic [15:0] e32_str_pf_id_q;
    logic e32_str_pf_ok_q;
    logic [10:0] e32_str_res_q;
    logic [15:0] e32_this_obj_q;
    logic [6:0] e32_to_n_q;
    logic [15:0] e32_to_seq_q;
    logic [6:0] e32_txt_bn_q;
    logic [3:0] e32_txt_ph_q;
    logic signed [15:0] e32_txt_px_q;
    logic signed [15:0] e32_txt_py_q;
    logic [15:0] e32_txt_rp_q;
    logic [31:0] e32_txt_val_q;
    logic [2:0] e32_txt_vt_q;
    logic [11:0] e32_vcall_argc_q;
    logic [63:0] e32_vcall_this_q;
    logic [9:0] e32_x_q;
    logic [1:0] e32_xf_dst_q;
    logic signed [31:0] e32_xf_h_q;
    logic signed [31:0] e32_xf_w_q;
    logic signed [31:0] e32_xf_x_q;
    logic signed [31:0] e32_xf_y_q;
    logic [9:0] e32_y_q;
    logic [63:0] e32_hp_qk_pack_q;
    logic [11:0] e32_hp_qt_pack_q;
    logic [255:0] e32_hp_qv_pack_q;
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
    logic [9:0] e32_intern_var_raddr;
    logic [8:0] e32_intern_var_rdata;
    logic e32_intern_var_ok_rdata;
    logic [8:0] e32_env_oid_raddr;
    logic [15:0] e32_env_oid_rdata;
    logic [7:0] e32_char_id_raddr;
    logic [15:0] e32_char_id_rdata;
    logic e32_char_ok_rdata;
    logic [5:0] e32_to_raddr;
    logic [11:0] e32_to_delay_rdata, e32_to_period_rdata;
    logic [15:0] e32_to_fn_rdata, e32_to_id_rdata;
    logic e32_to_we;
    logic [5:0] e32_to_waddr;
    logic [11:0] e32_to_delay_wdata, e32_to_period_wdata;
    logic [15:0] e32_to_fn_wdata, e32_to_id_wdata;
    logic [6:0] e32_fn_proto_raddr;
    logic [15:0] e32_fn_proto_ip_rdata, e32_fn_proto_oid_rdata;
    logic e32_fn_proto_we;
    logic [6:0] e32_fn_proto_waddr;
    logic [15:0] e32_fn_proto_ip_wdata, e32_fn_proto_oid_wdata;
    logic e32_cstack_we;
    logic [6:0] e32_cstack_waddr;
    logic [15:0] e32_cstack_ctorobj_wdata;
    logic [5:0] e32_cstack_env_wdata;
    logic [15:0] e32_cstack_fe_arr_wdata, e32_cstack_fe_fn_wdata;
    logic [7:0] e32_cstack_fe_i_wdata;
    logic [15:0] e32_cstack_ip_wdata;
    logic e32_cstack_isctor_wdata, e32_cstack_isfe_wdata;
    logic [15:0] e32_cstack_map_arr_wdata, e32_cstack_this_wdata;
    logic [15:0] e32_cs1_ip_rdata, e32_cs2_ip_rdata;
    logic [15:0] e32_cs1_this_rdata, e32_cs2_this_rdata;
    logic e32_cs1_isctor_rdata, e32_cs2_isctor_rdata;
    logic e32_cs1_isfe_rdata, e32_cs2_isfe_rdata;
    logic [15:0] e32_cs1_ctorobj_rdata, e32_cs2_ctorobj_rdata;
    logic [15:0] e32_cs1_fe_arr_rdata, e32_cs2_fe_arr_rdata;
    logic [15:0] e32_cs1_fe_fn_rdata, e32_cs2_fe_fn_rdata;
    logic [7:0] e32_cs1_fe_i_rdata, e32_cs2_fe_i_rdata;
    logic [15:0] e32_cs1_map_arr_rdata, e32_cs2_map_arr_rdata;
    logic [5:0] e32_cs1_env_rdata, e32_cs2_env_rdata;
    // Exec-owned large memories: scalar poke/clr (not unpacked array ports).
    logic e32_p_clr, e32_p_we;
    logic e32_p_clr_busy;
    logic e32_leave_hold;
    logic [5:0] e32_p_sel;
    logic [15:0] e32_p_addr, e32_p_addr2;
    logic [63:0] e32_p_data;
    logic [15:0] e32_obj_cls_rdata;
    logic [9:0] e32_obj_cls_raddr;
    logic [5:0] e32_obj_n_rdata;
    logic [9:0] e32_obj_n_raddr;
    logic [15:0] e32_tfn_entry_rdata;
    logic e32_tfn_has_this_rdata;
    logic [7:0] e32_tfn_nparam_rdata;
    logic [15:0] e32_tfn_parent_rdata;
    logic [15:0] e32_tenv_parent_rdata;
    logic [15:0] e32_tfn_this_rdata;
    logic [2:0] e32_tfn_this_tag_rdata;
    logic [12:0] e32_tfn_raddr;
    logic [10:0] e32_stack_raddr, e32_stack_raddr2;
    logic signed [31:0] e32_stack_rdata, e32_stack_rdata2;
    logic [2:0] e32_stack_tag_rdata;
    logic [10:0] stack_rd_a;
    logic [9:0] e32_intern_tos, e32_intern_nos;
    logic [11:0] e32_aid_tos, e32_aid_nos;
    logic [8:0] e32_vars_raddr;
    logic [15:0] e32_env_free_rdata;
    logic e32_name_has_tos, e32_name_has_nos;
    logic [15:0] e32_name_hash_tos, e32_name_hash_nos;
    logic [7:0] e32_name_len_tos, e32_name_len_nos;
    logic [15:0] e32_name_off_tos, e32_name_off_nos;
    logic [7:0] e32_arr_len_tos_rdata, e32_arr_len_nos_rdata;
    logic signed [31:0] e32_vars_rdata;
    logic signed [31:0] e32_consts_rdata;
    logic [9:0] e32_consts_raddr;
    logic e32_var_init_rdata;
    logic [2:0] e32_var_tag_rdata;
    logic [7:0] fill_lut_rdata;
    logic [255:0] spr_hh_pack, spr_nid_pack, spr_ww_pack;
    logic [63:0] hp_qk_ff_pack;
    logic [11:0] hp_qt_ff_pack;
    logic [255:0] hp_qv_ff_pack;
    // HEAP/FETCH handshake: parent writes these FFs; exec applies only
    // the masked scalars (ip / hp_* / code_raddr / state). Not a full FF dump.
    logic hs64, hs32;
    logic hs_m_ip, hs_m_code, hs_m_state, hs_m_vsp;
    logic hs_m_hp_cmd, hs_m_hp_v64, hs_m_hp_oid, hs_m_hp_aid, hs_m_hp_env;
    logic hs_m_hp_eid, hs_m_hp_slot, hs_m_hp_aslot, hs_m_hp_len, hs_m_hp_alen;
    logic hs_m_hp_lim, hs_m_hp_key, hs_m_hp_wval, hs_m_hp_rval, hs_m_hp_hit;
    logic hs_m_hp_ret, hs_m_hp_phase, hs_m_hp_proto, hs_m_hp_qn, hs_m_hp_qi;
    logic hs_m_hp_si, hs_m_hp_ss, hs_m_hp_tn, hs_m_hp_from_stack, hs_m_hp_make_arr;
    logic hs_m_hp_vbase, hs_m_hp_spr_w, hs_m_hp_spr_h, hs_m_hp_nat, hs_m_hp_tag;
    logic hs_m_hp_qk, hs_m_hp_qv, hs_m_hp_qt;
    logic hs_m_valloc_kind, hs_m_valloc_i, hs_m_valloc_arr_n, hs_m_valloc_retried, hs_m_vnat_dom, hs_m_vnat_base, hs_m_valloc_now_fn, hs_m_valloc_bind, hs_m_valloc_bind_src, hs_m_valloc_bind_this, hs_m_valloc_fn_entry, hs_m_valloc_fn_a1, hs_m_valloc_proto, hs_m_valloc_proto_fn, hs_m_valloc_metrics, hs_m_valloc_regex, hs_m_valloc_regex_pack, hs_m_vcall_value, hs_m_vcall_argc, hs_m_vcall_entry, hs_m_vcall_set_this, hs_m_vcall_this, hs_m_vcall_ctor_val, hs_m_vcsp, hs_m_vthis, hs_m_venv;
    logic hs_m_vraf_n /*verilator public_flat_rd*/;
    logic hs_m_vlistener_n, hs_m_vgc_halt_after, hs_m_vgc_wait_after, hs_m_vgc_clear_i, hs_m_vgc_qr, hs_m_vgc_qw;
    logic hs_m_vdraw_i, hs_m_vdraw_x, hs_m_vdraw_y, hs_m_vdraw_w, hs_m_vdraw_h, hs_m_vdraw_color;
    logic hs_m_vfe_i, hs_m_vfe_pop;

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
    // exec32 retired (docs/REMOVING_EXEC32.md Phase 3). The tagged
    // decoder is unhooked: hs32 is tied 0 and every e32_*_q wire the
    // module drove is now undriven (reads as 0 — the safe-constant
    // fall-through the raddr muxes require). Parent-driven e32_-named
    // signals (the 74 KEEP set) are parent silicon and stay.

    // Hierarchical jmr_js_vm_exec64: keep_hierarchy so Vivado does not flatten
    // the opcode mux back into the parent always_ff.
    logic e64_aset_win_retried_q;
    logic [7:0] e64_bind_argc_q;
    logic [11:0] e64_bind_base_q;
    logic [15:0] e64_bind_ip_q;
    logic [7:0] e64_bind_k_q;
    logic [1:0] e64_bind_mode_q;
    logic [7:0] e64_bind_n_q;
    logic e64_bind_rd_arm_q;
    logic [6:0] e64_bind_ret_q;
    logic [11:0] e64_bind_src_q;
    logic [11:0] e64_bind_vsp_next_q;
    logic [15:0] e64_blit_sh_q;
    logic [7:0] e64_blit_si_q;
    logic [15:0] e64_blit_sw_q;
    logic [15:0] e64_blit_sx_q;
    logic [15:0] e64_blit_sy_q;
    logic [2:0] e64_cc_at_q;
    logic signed [31:0] e64_cc_av_q;
    logic e64_cc_bok_q;
    logic [2:0] e64_cc_bt_q;
    logic signed [31:0] e64_cc_bv_q;
    logic [3:0] e64_cc_d_q;
    logic [15:0] e64_cc_h_q;
    logic [7:0] e64_cc_len_q;
    logic e64_cc_second_q;
    logic [1:0] e64_cc_st_q;
    logic [14:0] e64_code_raddr_q;
    logic [7:0] e64_color_q;
    logic [1:0] e64_ctx_align_q;
    logic e64_ctx_smooth_q;
    logic signed [31:0] e64_ctx_sx_q /*verilator public_flat_rd*/;
    logic signed [31:0] e64_ctx_sy_q;
    logic signed [31:0] e64_ctx_tx_q;
    logic signed [31:0] e64_ctx_ty_q;
    logic [15:0] e64_dbg_di_hit_q /*verilator public_flat_rd*/;
    logic [15:0] e64_dbg_di_miss_q /*verilator public_flat_rd*/;
    logic [15:0] e64_dbg_div_n_q;
    logic [15:0] e64_dbg_json_ovf_q;
    logic [15:0] e64_dbg_path_ovf_q;
    logic [7:0] e64_fault_code_q;
    logic [18:0] e64_fb_dump_addr_q;
    logic e64_fb_dump_sel_q;
    logic e64_fb_swap_q;
    logic [7:0] e64_fill_style_i_q;
    logic [7:0] e64_stroke_style_i_q;
    logic [11:0] e64_hp_aid_q;
    logic [7:0] e64_hp_alen_q;
    logic [6:0] e64_hp_aslot_q;
    logic [3:0] e64_hp_cmd_q;
    logic [9:0] e64_hp_eid_q;
    logic e64_hp_env_q;
    logic e64_hp_from_stack_q;
    logic e64_hp_hit_q;
    logic [15:0] e64_hp_key_q;
    logic [5:0] e64_hp_len_q;
    logic [7:0] e64_hp_lim_q;
    logic e64_hp_make_arr_q;
    logic [3:0] e64_hp_nat_q;
    logic [12:0] e64_hp_oid_q;
    logic [2:0] e64_hp_phase_q;
    logic [63:0] e64_hp_proto_q;
    logic [2:0] e64_hp_qi_q;
    logic [2:0] e64_hp_qn_q;
    logic [6:0] e64_hp_ret_q;
    logic [63:0] e64_hp_rval_q;
    logic [12:0] e64_hp_si_q;
    logic [4:0] e64_hp_slot_q;
    logic [15:0] e64_hp_spr_h_q;
    logic [15:0] e64_hp_spr_w_q;
    logic [4:0] e64_hp_ss_q;
    logic [2:0] e64_hp_tag_q;
    logic [5:0] e64_hp_tn_q;
    logic e64_hp_v64_q;
    logic [11:0] e64_hp_vbase_q;
    logic [63:0] e64_hp_wval_q;
    logic e64_imgd_armed_q;
    logic [9:0] e64_imgd_h_q;
    logic [18:0] e64_imgd_i_q;
    logic [18:0] e64_imgd_n_q;
    logic e64_imgd_v64_q;
    logic [9:0] e64_imgd_w_q;
    logic [9:0] e64_imgd_x_q;
    logic [9:0] e64_imgd_x0_q;
    logic [9:0] e64_imgd_y_q;
    logic [9:0] e64_imgd_y0_q;
    logic [15:0] e64_ip_q;
    logic [11:0] e64_jn_arr_q;
    logic [15:0] e64_jn_h_q;
    logic [15:0] e64_jn_i_q;
    logic [10:0] e64_jn_res_q;
    logic [5:0] e64_js_sp_q;
    logic [2:0] e64_json_pph_q;
    logic [13:0] e64_json_rp_q;
    logic [13:0] e64_json_src_q;
    logic [13:0] e64_json_srclen_q;
    logic [13:0] e64_json_wp_q;
    logic e64_looping_q;
    logic e64_machine_fault_q;
    logic [63:0] e64_minmax_acc_q;
    logic [11:0] e64_minmax_base_q;
    logic e64_minmax_is_min_q;
    logic [7:0] e64_minmax_k_q;
    logic [7:0] e64_minmax_n_q;
    logic e64_namcpy_armed_q;
    logic e64_namcpy_repl_q;
    logic e64_namcpy_v64_q;
    logic [15:0] e64_name_rdaddr_q;
    logic e64_path_active_q;
    logic [1:0] e64_path_kind_q;
    logic e64_path_stroke_q;
    logic [4:0] e64_pc_n_q;
    // #49: path-command write mirror from exec64 into the parent arrays that
    // S_PWALK actually rasters from.
    // #54: stringify seed mirror
    logic e64_js_we_q;
    logic [4:0] e64_js_waddr_q;
    logic [7:0] e64_js_i_wdata_q;
    logic [2:0] e64_js_ph_wdata_q;
    logic [63:0] e64_vjs_val_wdata_q;
    logic e64_pc_we_q;
    logic [3:0] e64_pc_waddr_q;
    logic [1:0] e64_pc_op_wdata_q;
    logic signed [31:0] e64_pc_a1_wdata_q, e64_pc_a2_wdata_q;
    logic signed [31:0] e64_pc_a3_wdata_q, e64_pc_a4_wdata_q, e64_pc_a5_wdata_q;
    logic e64_pc_ccw_wdata_q;
    logic [4:0] e64_pi_q;
    logic e64_repl_did_q;
    logic e64_repl_g_q;
    logic [7:0] e64_repl_nlen_q;
    logic [7:0] e64_repl_pat0_q;
    logic [7:0] e64_repl_pat1_q;
    logic [7:0] e64_repl_rch_q;
    logic [9:0] e64_rh_q;
    logic e64_running_q;
    logic [9:0] e64_rw_q;
    logic [9:0] e64_rx_q;
    logic [9:0] e64_ry_q;
    logic signed [31:0] e64_saved_sx_q;
    logic signed [31:0] e64_saved_sy_q;
    logic signed [31:0] e64_saved_tx_q;
    logic signed [31:0] e64_saved_ty_q;
    logic [4:0] e64_sq_i_q;
    logic [47:0] e64_sq_rad_q;
    logic [25:0] e64_sq_rem_q;
    logic [23:0] e64_sq_root_q;
    logic [6:0] e64_state_q;
    logic [6:0] e64_txt_bn_q;
    logic [3:0] e64_txt_ph_q;
    logic signed [15:0] e64_txt_px_q;
    logic signed [15:0] e64_txt_py_q;
    logic [31:0] e64_txt_val_q;
    logic [2:0] e64_txt_vt_q;
    logic e64_v64_concat_q;
    logic e64_v64_join_q;
    logic e64_v64_repl_q;
    logic e64_v64_sqrt_q;
    logic [7:0] e64_valloc_arr_n_q;
    logic e64_valloc_bind_q;
    logic [12:0] e64_valloc_bind_src_q;
    logic [63:0] e64_valloc_bind_this_q;
    logic [7:0] e64_valloc_fn_a1_q;
    logic [15:0] e64_valloc_fn_entry_q;
    logic [13:0] e64_valloc_i_q;
    logic [1:0] e64_valloc_kind_q;
    logic e64_valloc_metrics_q;
    logic e64_valloc_now_fn_q;
    logic e64_valloc_proto_q;
    logic [12:0] e64_valloc_proto_fn_q;
    logic e64_valloc_regex_q;
    logic [31:0] e64_valloc_regex_pack_q;
    logic e64_valloc_retried_q;
    logic [13:0] e64_varr_next_q;
    logic [11:0] e64_vcall_argc_q;
    logic [63:0] e64_vcall_ctor_val_q;
    logic [15:0] e64_vcall_entry_q;
    logic e64_vcall_set_this_q;
    logic [63:0] e64_vcall_this_q;
    logic e64_vcall_value_q;
    logic [8:0] e64_vconsole_n_q;
    logic [7:0] e64_vcsp_q;
    logic [7:0] e64_vdiv_count_q;
    logic [52:0] e64_vdiv_den_q;
    logic signed [12:0] e64_vdiv_exp_q;
    logic [106:0] e64_vdiv_num_q;
    logic [106:0] e64_vdiv_quot_q;
    logic [53:0] e64_vdiv_rem_q;
    logic e64_vdiv_sign_q;
    logic [7:0] e64_vdraw_color_q;
    logic [9:0] e64_vdraw_h_q;
    logic [18:0] e64_vdraw_i_q;
    logic [9:0] e64_vdraw_w_q;
    logic [9:0] e64_vdraw_x_q;
    logic [9:0] e64_vdraw_y_q;
    logic [63:0] e64_venv_q;
    logic [9:0] e64_venv_next_q;
    logic [63:0] e64_vfe_arr_q;
    logic [11:0] e64_vfe_base_q;
    logic [63:0] e64_vfe_fn_q;
    logic [7:0] e64_vfe_i_q;
    logic [7:0] e64_vfe_len_q;
    logic [63:0] e64_vfe_map_q;
    logic e64_vfe_reduce_q;
    logic e64_vfe_findidx_q;
    logic [1:0] e64_vfe_mode_q;
    logic [15:0] e64_vfe_ret_q;
    logic [3:0] e64_vfe_sp_q;
    logic e64_vfree_armed_q;
    logic e64_vfree_arr_long_q;
    logic [13:0] e64_vgc_clear_i_q;
    logic e64_vgc_halt_after_q;
    logic [13:0] e64_vgc_qr_q;
    logic [13:0] e64_vgc_qw_q;
    logic [1:0] e64_vgc_resume_q;
    logic e64_vgc_wait_after_q;
    logic e64_vjs_rd_arm_q;
    logic [4:0] e64_vlistener_n_q;
    logic [15:0] e64_vmetrics_w_q;
    logic [11:0] e64_vmod_count_q;
    logic [52:0] e64_vmod_den_q;
    logic signed [12:0] e64_vmod_exp_q;
    logic [52:0] e64_vmod_rem_q;
    logic e64_vmod_sign_q;
    logic [11:0] e64_vnat_base_q;
    logic [2:0] e64_vnat_dom_q;
    logic e64_vprom_copy_q;
    logic e64_vprom_done_q;
    logic [6:0] e64_vprom_ret_q;
    logic [3:0] e64_vraf_n_q;
    logic [31:0] e64_vrng_q;
    logic [11:0] e64_vsp_q;
    logic e64_vst_hold_win_q;
    logic e64_vst_refill_arm_q;
    logic [3:0] e64_vst_refill_i_q;
    logic [6:0] e64_vst_refill_ret_q;
    logic [11:0] e64_vst_waddr_q;
    logic [63:0] e64_vst_wdata_q;
    logic e64_vst_we_q;
    logic [63:0] e64_vthis_q;
    logic [6:0] e64_vtimer_n_q;
    logic [31:0] e64_vtimer_seq_q;
    logic [9:0] e64_x_q;
    logic [9:0] e64_y_q;
    logic [63:0] e64_hp_qk_pack_q;
    logic [11:0] e64_hp_qt_pack_q;
    logic [255:0] e64_hp_qv_pack_q;
    logic e64_json_mem_we;
    logic [12:0] e64_json_mem_waddr;
    logic [7:0] e64_json_mem_wdata;
    logic [9:0] e64_name_blen_raddr;
    logic e64_name_blen_we;
    logic [9:0] e64_name_blen_waddr;
    logic [15:0] e64_name_blen_wdata;
    logic [9:0] e64_name_hash_raddr;
    logic e64_name_hash_we;
    logic [9:0] e64_name_hash_waddr;
    logic [15:0] e64_name_hash_wdata;
    logic e64_name_has_we;
    logic [9:0] e64_name_has_waddr;
    logic e64_name_has_wdata;
    logic [15:0] name_blen_rdata;
    logic [15:0] name_hash_rdata;
    // Exec64 heap raddr (parent SRAM, rdata next clock).
    logic [8:0] e64_vvars_raddr;
    logic [9:0] e64_venv_raddr;
    logic [11:0] e64_varr_raddr;
    logic [12:0] e64_vobj_raddr;
    logic [12:0] e64_vfn_raddr;
    logic [9:0] e64_name_off_raddr;
    logic [9:0] e64_fill_lut_raddr;
    logic [6:0] e64_vframe_raddr;
    logic [5:0] e64_vtimer_raddr;
    logic [9:0] e64_vconsts_raddr;
    logic [63:0] vvars_rdata;
    logic vvar_valid_rdata;
    logic [63:0] venv_parent_rdata;
    logic [4:0] venv_len_rdata;
    logic [11:0] venv_gen_rdata;
    logic venv_valid_rdata /*verilator public_flat_rd*/;
    logic [7:0] varr_len_rdata;
    logic varr_valid_rdata;
    logic [11:0] varr_gen_rdata;
    logic varr_long_rdata;
    logic [7:0] varr_lidx_rdata;
    logic [1:0] vobj_alloc_rdata;
    logic [11:0] vobj_gen_rdata;
    logic vobj_mark_rdata, vfn_mark_rdata, varr_mark_rdata, venv_mark_rdata;
    logic [63:0] vobj_proto_rdata;
    logic [15:0] vobj_cls_rdata;
    logic [5:0] vobj_len_rdata;
    logic [3:0] vobj_builtin_rdata;
    logic vfn_valid_rdata;
    logic [11:0] vfn_gen_rdata;
    logic [63:0] vfn_proto_rdata;
    logic [63:0] vfn_env_rdata;
    logic [5:0] vfn_nparam_rdata;
    logic [15:0] vfn_entry_rdata;
    logic [2:0] vfn_flags_rdata;
    logic [63:0] vfn_bound_this_rdata;
    logic [63:0] vconsts_rdata;
    logic [15:0] vframe_rip_rdata;
    logic [11:0] vframe_bsp_rdata;
    logic vframe_esc_rdata;
    logic [63:0] vframe_this_rdata;
    logic [63:0] vframe_env_rdata;
    logic [63:0] vframe_fn_rdata;
    logic [63:0] vframe_ctor_rdata;
    logic vtimer_valid_rdata;
    logic signed [31:0] vtimer_id_rdata;
    logic [15:0] name_off_rdata;
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
    logic e64_p_clr_busy;
    logic e64_leave_hold;
    logic e64_vraf_we;
    logic [2:0] e64_vraf_waddr;
    logic [63:0] e64_vraf_wdata;
    logic e64_vtimer_we;
    logic [5:0] e64_vtimer_waddr;
    logic e64_vtimer_valid_wdata;
    logic signed [31:0] e64_vtimer_due_wdata;
    logic [63:0] e64_vtimer_fn_wdata;
    logic signed [31:0] e64_vtimer_id_wdata;
    logic signed [63:0] e64_vtimer_period_wdata;
    logic e64_vst_win0_we;
    logic [63:0] e64_vst_win0_wdata;
    (* keep_hierarchy = "yes" *)
    jmr_js_vm_exec64 u_exec64 (
        .clk(clk),
        .rst_n(rst_n),
        .enable((state == S_V64_EXEC)),
        .leave_hold(e64_leave_hold),
        .hs_m_ip(hs_m_ip),
        .hs_m_code(hs_m_code),
        .hs_m_state(hs_m_state),
        .hs_m_vsp(hs_m_vsp),
        .hs_m_hp_cmd(hs_m_hp_cmd),
        .hs_m_hp_v64(hs_m_hp_v64),
        .hs_m_hp_oid(hs_m_hp_oid),
        .hs_m_hp_aid(hs_m_hp_aid),
        .hs_m_hp_env(hs_m_hp_env),
        .hs_m_hp_eid(hs_m_hp_eid),
        .hs_m_hp_slot(hs_m_hp_slot),
        .hs_m_hp_aslot(hs_m_hp_aslot),
        .hs_m_hp_len(hs_m_hp_len),
        .hs_m_hp_alen(hs_m_hp_alen),
        .hs_m_hp_lim(hs_m_hp_lim),
        .hs_m_hp_key(hs_m_hp_key),
        .hs_m_hp_wval(hs_m_hp_wval),
        .hs_m_hp_rval(hs_m_hp_rval),
        .hs_m_hp_hit(hs_m_hp_hit),
        .hs_m_hp_ret(hs_m_hp_ret),
        .hs_m_hp_phase(hs_m_hp_phase),
        .hs_m_hp_proto(hs_m_hp_proto),
        .hs_m_hp_qn(hs_m_hp_qn),
        .hs_m_hp_qi(hs_m_hp_qi),
        .hs_m_hp_si(hs_m_hp_si),
        .hs_m_hp_ss(hs_m_hp_ss),
        .hs_m_hp_tn(hs_m_hp_tn),
        .hs_m_hp_from_stack(hs_m_hp_from_stack),
        .hs_m_hp_make_arr(hs_m_hp_make_arr),
        .hs_m_hp_vbase(hs_m_hp_vbase),
        .hs_m_hp_spr_w(hs_m_hp_spr_w),
        .hs_m_hp_spr_h(hs_m_hp_spr_h),
        .hs_m_hp_nat(hs_m_hp_nat),
        .hs_m_hp_tag(hs_m_hp_tag),
        .hs_m_hp_qk(hs_m_hp_qk),
        .hs_m_hp_qv(hs_m_hp_qv),
        .hs_m_hp_qt(hs_m_hp_qt),
        .hs_m_valloc_kind(hs_m_valloc_kind),
        .hs_m_valloc_i(hs_m_valloc_i),
        .hs_m_valloc_arr_n(hs_m_valloc_arr_n),
        .hs_m_valloc_retried(hs_m_valloc_retried),
        .hs_m_vnat_dom(hs_m_vnat_dom),
        .hs_m_vnat_base(hs_m_vnat_base),
        .hs_m_valloc_now_fn(hs_m_valloc_now_fn),
        .hs_m_valloc_bind(hs_m_valloc_bind),
        .hs_m_valloc_bind_src(hs_m_valloc_bind_src),
        .hs_m_valloc_bind_this(hs_m_valloc_bind_this),
        .hs_m_valloc_fn_entry(hs_m_valloc_fn_entry),
        .hs_m_valloc_fn_a1(hs_m_valloc_fn_a1),
        .hs_m_valloc_proto(hs_m_valloc_proto),
        .hs_m_valloc_proto_fn(hs_m_valloc_proto_fn),
        .hs_m_valloc_metrics(hs_m_valloc_metrics),
        .hs_m_valloc_regex(hs_m_valloc_regex),
        .hs_m_valloc_regex_pack(hs_m_valloc_regex_pack),
        .hs_m_vcall_value(hs_m_vcall_value),
        .hs_m_vcall_argc(hs_m_vcall_argc),
        .hs_m_vcall_entry(hs_m_vcall_entry),
        .hs_m_vcall_set_this(hs_m_vcall_set_this),
        .hs_m_vcall_this(hs_m_vcall_this),
        .hs_m_vcall_ctor_val(hs_m_vcall_ctor_val),
        .hs_m_vcsp(hs_m_vcsp),
        .hs_m_vthis(hs_m_vthis),
        .hs_m_venv(hs_m_venv),
        .hs_m_vraf_n(hs_m_vraf_n),
        .hs_m_vlistener_n(hs_m_vlistener_n),
        .hs_m_vgc_halt_after(hs_m_vgc_halt_after),
        .hs_m_vgc_wait_after(hs_m_vgc_wait_after),
        .hs_m_vgc_clear_i(hs_m_vgc_clear_i),
        .hs_m_vgc_qr(hs_m_vgc_qr),
        .hs_m_vgc_qw(hs_m_vgc_qw),
        .hs_m_vdraw_i(hs_m_vdraw_i),
        .hs_m_vdraw_x(hs_m_vdraw_x),
        .hs_m_vdraw_y(hs_m_vdraw_y),
        .hs_m_vdraw_w(hs_m_vdraw_w),
        .hs_m_vdraw_h(hs_m_vdraw_h),
        .hs_m_vdraw_color(hs_m_vdraw_color),
        .hs_m_vfe_i(hs_m_vfe_i),
        .hs_m_vfe_pop(hs_m_vfe_pop),
        .p_clr_busy_q(e64_p_clr_busy),
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
        .p_aset_win_retried(aset_win_retried),
        .p_bind_argc(bind_argc),
        .p_bind_base(bind_base),
        .p_bind_ip(bind_ip),
        .p_bind_k(bind_k),
        .p_bind_mode(bind_mode),
        .p_bind_n(bind_n),
        .p_bind_rd_arm(bind_rd_arm),
        .p_bind_ret(bind_ret),
        .p_bind_src(bind_src),
        .p_bind_vsp_next(bind_vsp_next),
        .p_blit_sh(blit_sh),
        .p_blit_si(blit_si),
        .p_blit_sw(blit_sw),
        .p_blit_sx(blit_sx),
        .p_blit_sy(blit_sy),
        .p_cc_at(cc_at),
        .p_cc_av(cc_av),
        .p_cc_bok(cc_bok),
        .p_cc_bt(cc_bt),
        .p_cc_bv(cc_bv),
        .p_cc_d(cc_d),
        .p_cc_h(cc_h),
        .p_cc_len(cc_len),
        .p_cc_second(cc_second),
        .p_cc_st(cc_st),
        .p_code_raddr(code_raddr_ff),
        .code_rdata(code_rdata),
        .p_color(color),
        .p_ctx_align(ctx_align),
        .p_ctx_smooth(ctx_smooth),
        .p_ctx_sx(ctx_sx),
        .p_ctx_sy(ctx_sy),
        .p_ctx_tx(ctx_tx),
        .p_ctx_ty(ctx_ty),
        .p_dbg_di_hit(dbg_di_hit),
        .p_dbg_di_miss(dbg_di_miss),
        .p_dbg_div_n(dbg_div_n),
        .p_dbg_json_ovf(dbg_json_ovf),
        .p_dbg_path_ovf(dbg_path_ovf),
        .dbg_str_ovf(dbg_str_ovf),
        .p_fault_code(fault_code),
        .p_fb_dump_addr(fb_dump_addr),
        .p_fb_dump_sel(fb_dump_sel),
        .p_fb_swap(fb_swap),
        .p_fill_style_i(fill_style_i),
        .p_stroke_style_i(stroke_style_i),
        .p_hp_aid(hp_aid_ff),
        .p_hp_alen(hp_alen_ff),
        .p_hp_aslot(hp_aslot_ff),
        .p_hp_cmd(hp_cmd_ff),
        .p_hp_eid(hp_eid_ff),
        .p_hp_env(hp_env_ff),
        .p_hp_from_stack(hp_from_stack_ff),
        .p_hp_hit(hp_hit_ff),
        .p_hp_key(hp_key_ff),
        .p_hp_len(hp_len_ff),
        .p_hp_lim(hp_lim_ff),
        .p_hp_make_arr(hp_make_arr_ff),
        .p_hp_nat(hp_nat_ff),
        .p_hp_oid(hp_oid_ff),
        .p_hp_phase(hp_phase_ff),
        .p_hp_proto(hp_proto_ff),
        .p_hp_qi(hp_qi_ff),
        .p_hp_qk_pack(hp_qk_ff_pack),
        .p_hp_qn(hp_qn_ff),
        .p_hp_qt_pack(hp_qt_ff_pack),
        .p_hp_qv_pack(hp_qv_ff_pack),
        .p_hp_ret(hp_ret_ff),
        .p_hp_rval(hp_rval_ff),
        .p_hp_si(hp_si_ff),
        .p_hp_slot(hp_slot_ff),
        .p_hp_spr_h(hp_spr_h_ff),
        .p_hp_spr_w(hp_spr_w_ff),
        .p_hp_ss(hp_ss_ff),
        .p_hp_tag(hp_tag_ff),
        .p_hp_tn(hp_tn_ff),
        .p_hp_v64(hp_v64_ff),
        .p_hp_vbase(hp_vbase_ff),
        .p_hp_wval(hp_wval_ff),
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
        .id_slice(id_slice),
        .id_sort(id_sort),
        .vfe_sort_q(e64_vfe_sort_q),
        .id_find(id_find),
        .id_findindex(16'hFFFF), // V1 wall: findIndex removed (no title uses it)
        .id_font(id_font),
        .id_disp(id_disp),
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
        .id_quadcurve(id_quadcurve),
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
        .id_textbaseline(id_textbaseline),
        .id_top(id_top),
        .id_middle(id_middle),
        .id_bottom(id_bottom),
        .ctx_baseline_q(e64_ctx_baseline_q),
        .id_translate(id_translate),
        .id_unshift(id_unshift),
        .id_white(id_white),
        .id_width(id_width),
        .p_imgd_armed(imgd_armed),
        .p_imgd_h(imgd_h),
        .p_imgd_i(imgd_i),
        .p_imgd_n(imgd_n),
        .p_imgd_v64(imgd_v64),
        .p_imgd_w(imgd_w),
        .p_imgd_x(imgd_x),
        .p_imgd_x0(imgd_x0),
        .p_imgd_y(imgd_y),
        .p_imgd_y0(imgd_y0),
        .p_ip(ip_ff),
        .p_jn_arr(jn_arr),
        .p_jn_h(jn_h),
        .p_jn_i(jn_i),
        .p_jn_res(jn_res),
        .joy_in(joy_in),
        .p_js_sp(js_sp),
        .p_json_pph(json_pph),
        .p_json_rp(json_rp),
        .p_json_src(json_src),
        .p_json_srclen(json_srclen),
        .p_json_wp(json_wp),
        .p_looping(looping),
        .p_machine_fault(machine_fault),
        .p_minmax_acc(minmax_acc),
        .p_minmax_base(minmax_base),
        .p_minmax_is_min(minmax_is_min),
        .p_minmax_k(minmax_k),
        .p_minmax_n(minmax_n),
        .n_cls(n_cls),
        .cm_req_q(e64_cm_req),
        .cm_key_q(e64_cm_key),
        .cm_cls_q(e64_cm_cls),
        .cm_res_we(cm_res_we),
        .cm_res_mip(cm_res_mip),
        .lsv_req_q(e64_lsv_req),
        .lsv_op_q(e64_lsv_op),
        .lsv_ev_q(e64_lsv_ev),
        .lsv_fn_q(e64_lsv_fn),
        .lsv_res_we(lsv_res_we),
        .lsv_res(lsv_res),
        .lsv_res_n(lsv_res_n_out),
        .n_consts(n_consts),
        .n_ops(n_ops),
        .n_spr(n_spr),
        .p_namcpy_armed(namcpy_armed),
        .p_namcpy_repl(namcpy_repl),
        .p_namcpy_v64(namcpy_v64),
        .p_name_rdaddr(name_rdaddr),
        .name_blen_rdata(name_blen_rdata),
        .name_hash_rdata(name_hash_rdata),
        .name_rdata(name_rdata),
        .name_off_rdata(name_off_rdata),
        .vvars_rdata(vvars_rdata),
        .vvar_valid_rdata(vvar_valid_rdata),
        .venv_len_rdata(venv_len_rdata),
        .venv_gen_rdata(venv_gen_rdata),
        .venv_valid_rdata(venv_valid_rdata),
        .varr_len_rdata(varr_len_rdata),
        .varr_valid_rdata(varr_valid_rdata),
        .varr_gen_rdata(varr_gen_rdata),
        .varr_long_rdata(varr_long_rdata),
        .varr_lidx_rdata(varr_lidx_rdata),
        .vobj_alloc_rdata(vobj_alloc_rdata),
        .vobj_gen_rdata(vobj_gen_rdata),
        .vobj_proto_rdata(vobj_proto_rdata),
        .vobj_cls_rdata(vobj_cls_rdata),
        .vobj_len_rdata(vobj_len_rdata),
        .vobj_builtin_rdata(vobj_builtin_rdata),
        .vfn_valid_rdata(vfn_valid_rdata),
        .vfn_gen_rdata(vfn_gen_rdata),
        .vfn_proto_rdata(vfn_proto_rdata),
        .vfn_env_rdata(vfn_env_rdata),
        .vfn_nparam_rdata(vfn_nparam_rdata),
        .vfn_entry_rdata(vfn_entry_rdata),
        .vfn_flags_rdata(vfn_flags_rdata),
        .vfn_bound_this_rdata(vfn_bound_this_rdata),
        .vconsts_rdata(vconsts_rdata),
        .vframe_rip_rdata(vframe_rip_rdata),
        .vframe_bsp_rdata(vframe_bsp_rdata),
        .vframe_esc_rdata(vframe_esc_rdata),
        .vframe_this_rdata(vframe_this_rdata),
        .vframe_env_rdata(vframe_env_rdata),
        .vframe_fn_rdata(vframe_fn_rdata),
        .vframe_ctor_rdata(vframe_ctor_rdata),
        .fill_lut_rdata(fill_lut_rdata),
        .vtimer_valid_rdata(vtimer_valid_rdata),
        .vtimer_id_rdata(vtimer_id_rdata),
        .names_n(names_n),
        .ops_base(ops_base),
        .p_path_active(path_active),
        .p_path_kind(path_kind),
        .p_path_stroke(path_stroke),
        .p_pc_n(pc_n),
        .p_pi(pi),
        .p_repl_did(repl_did),
        .p_repl_g(repl_g),
        .p_repl_nlen(repl_nlen),
        .p_repl_pat0(repl_pat0),
        .p_repl_pat1(repl_pat1),
        .p_repl_rch(repl_rch),
        .p_rh(rh),
        .p_running(running),
        .p_rw(rw),
        .p_rx(rx),
        .p_ry(ry),
        .p_saved_sx(saved_sx),
        .p_saved_sy(saved_sy),
        .p_saved_tx(saved_tx),
        .p_saved_ty(saved_ty),
        .sp(sp),
        .spr_hh_pack(spr_hh_pack),
        .spr_nid_pack(spr_nid_pack),
        .spr_ww_pack(spr_ww_pack),
        .p_sq_i(sq_i),
        .p_sq_rad(sq_rad),
        .p_sq_rem(sq_rem),
        .p_sq_root(sq_root),
        .p_state(state),
        .this_ok(this_ok),
        .p_txt_bn(txt_bn),
        .p_txt_ph(txt_ph),
        .p_txt_px(txt_px),
        .p_txt_py(txt_py),
        .p_txt_val(txt_val),
        .p_txt_vt(txt_vt),
        .p_v64_concat(v64_concat),
        .p_v64_join(v64_join),
        .p_v64_repl(v64_repl),
        .p_v64_sqrt(v64_sqrt),
        .p_valloc_arr_n(valloc_arr_n_ff),
        .p_valloc_bind(valloc_bind_ff),
        .p_valloc_bind_src(valloc_bind_src_ff),
        .p_valloc_bind_this(valloc_bind_this_ff),
        .p_valloc_fn_a1(valloc_fn_a1_ff),
        .p_valloc_fn_entry(valloc_fn_entry_ff),
        .p_valloc_i(valloc_i_ff),
        .p_valloc_kind(valloc_kind_ff),
        .p_valloc_metrics(valloc_metrics_ff),
        .p_valloc_now_fn(valloc_now_fn_ff),
        .p_valloc_proto(valloc_proto_ff),
        .p_valloc_proto_fn(valloc_proto_fn_ff),
        .p_valloc_regex(valloc_regex_ff),
        .p_valloc_regex_pack(valloc_regex_pack_ff),
        .p_valloc_retried(valloc_retried_ff),
        .var_this(var_this),
        .p_varr_next(varr_next),
        .p_vcall_argc(vcall_argc_ff),
        .p_vcall_ctor_val(vcall_ctor_val_ff),
        .p_vcall_entry(vcall_entry_ff),
        .p_vcall_set_this(vcall_set_this_ff),
        .p_vcall_this(vcall_this_ff),
        .p_vcall_value(vcall_value_ff),
        .p_vconsole_n(vconsole_n),
        .p_vcsp(vcsp_ff),
        .p_vdiv_count(vdiv_count),
        .p_vdiv_den(vdiv_den),
        .p_vdiv_exp(vdiv_exp),
        .p_vdiv_num(vdiv_num),
        .p_vdiv_quot(vdiv_quot),
        .p_vdiv_rem(vdiv_rem),
        .p_vdiv_sign(vdiv_sign),
        .p_vdraw_color(vdraw_color_ff),
        .p_vdraw_h(vdraw_h_ff),
        .p_vdraw_i(vdraw_i_ff),
        .p_vdraw_w(vdraw_w_ff),
        .p_vdraw_x(vdraw_x_ff),
        .p_vdraw_y(vdraw_y_ff),
        .p_venv(venv_ff),
        .p_venv_next(venv_next),
        .p_vfe_arr(vfe_arr),
        .p_vfe_base(vfe_base),
        .p_vfe_fn(vfe_fn),
        .p_vfe_i(e64_vfe_i_q + 8'd1),
        .p_vfe_map(vfe_map),
        .p_vfe_mode(vfe_mode),
        .p_vfe_ret(vfe_ret),
        .p_vfe_sp(vfe_sp),
        .vfn_next(vfn_next),
        .vframe_no(vframe_no),
        .p_vfree_armed(vfree_armed),
        .p_vfree_arr_long(vfree_arr_long),
        .vfree_ok(vfree_ok),
        .p_vgc_clear_i(vgc_clear_i_ff),
        .p_vgc_halt_after(vgc_halt_after_ff),
        .p_vgc_qr(vgc_qr_ff),
        .p_vgc_qw(vgc_qw_ff),
        .p_vgc_resume(vgc_resume),
        .p_vgc_wait_after(vgc_wait_after_ff),
        .p_vjs_rd_arm(vjs_rd_arm),
        .p_vlistener_n(vlistener_n_ff),
        .vmetrics(vmetrics),
        .p_vmetrics_w(vmetrics_w),
        .p_vmod_count(vmod_count),
        .p_vmod_den(vmod_den),
        .p_vmod_exp(vmod_exp),
        .p_vmod_rem(vmod_rem),
        .p_vmod_sign(vmod_sign),
        .p_vnat_base(vnat_base_ff),
        .p_vnat_dom(vnat_dom_ff),
        .vobj_next(vobj_next),
        .p_vprom_copy(vprom_copy),
        .p_vprom_done(vprom_done),
        .p_vprom_ret(vprom_ret),
        .p_vraf_n(vraf_n_ff),
        .p_vrng(vrng),
        .p_vsp(vsp_ff),
        .p_vst_hold_win(vst_hold_win),
        .p_vst_refill_arm(vst_refill_arm),
        .p_vst_refill_i(vst_refill_i),
        .p_vst_refill_ret(vst_refill_ret),
        .p_vst_waddr(vst_waddr),
        .p_vst_wdata(vst_wdata),
        .p_vst_we(vst_we),
        .vst_win_pack(vst_win_pack),
        .p_vthis(vthis_ff),
        .p_vtimer_n(vtimer_n),
        .p_vtimer_seq(vtimer_seq),
        .p_x(x),
        .p_y(y),
        .aset_win_retried_q(e64_aset_win_retried_q),
        .bind_argc_q(e64_bind_argc_q),
        .bind_base_q(e64_bind_base_q),
        .bind_ip_q(e64_bind_ip_q),
        .bind_k_q(e64_bind_k_q),
        .bind_mode_q(e64_bind_mode_q),
        .bind_n_q(e64_bind_n_q),
        .bind_rd_arm_q(e64_bind_rd_arm_q),
        .bind_ret_q(e64_bind_ret_q),
        .bind_src_q(e64_bind_src_q),
        .bind_vsp_next_q(e64_bind_vsp_next_q),
        .blit_sh_q(e64_blit_sh_q),
        .blit_si_q(e64_blit_si_q),
        .blit_sw_q(e64_blit_sw_q),
        .blit_sx_q(e64_blit_sx_q),
        .blit_sy_q(e64_blit_sy_q),
        .cc_at_q(e64_cc_at_q),
        .cc_av_q(e64_cc_av_q),
        .cc_bok_q(e64_cc_bok_q),
        .cc_bt_q(e64_cc_bt_q),
        .cc_bv_q(e64_cc_bv_q),
        .cc_d_q(e64_cc_d_q),
        .cc_h_q(e64_cc_h_q),
        .cc_len_q(e64_cc_len_q),
        .cc_second_q(e64_cc_second_q),
        .cc_st_q(e64_cc_st_q),
        .code_raddr_q(e64_code_raddr_q),
        .color_q(e64_color_q),
        .ctx_align_q(e64_ctx_align_q),
        .ctx_smooth_q(e64_ctx_smooth_q),
        .ctx_sx_q(e64_ctx_sx_q),
        .ctx_sy_q(e64_ctx_sy_q),
        .ctx_tx_q(e64_ctx_tx_q),
        .ctx_ty_q(e64_ctx_ty_q),
        .dbg_di_hit_q(e64_dbg_di_hit_q),
        .dbg_di_miss_q(e64_dbg_di_miss_q),
        .dbg_div_n_q(e64_dbg_div_n_q),
        .dbg_json_ovf_q(e64_dbg_json_ovf_q),
        .dbg_path_ovf_q(e64_dbg_path_ovf_q),
        .fault_code_q(e64_fault_code_q),
        .fb_dump_addr_q(e64_fb_dump_addr_q),
        .fb_dump_sel_q(e64_fb_dump_sel_q),
        .fb_swap_q(e64_fb_swap_q),
        .fill_style_i_q(e64_fill_style_i_q),
        .stroke_style_i_q(e64_stroke_style_i_q),
        .hp_aid_q(e64_hp_aid_q),
        .hp_alen_q(e64_hp_alen_q),
        .hp_aslot_q(e64_hp_aslot_q),
        .hp_cmd_q(e64_hp_cmd_q),
        .hp_eid_q(e64_hp_eid_q),
        .hp_env_q(e64_hp_env_q),
        .hp_from_stack_q(e64_hp_from_stack_q),
        .hp_hit_q(e64_hp_hit_q),
        .hp_key_q(e64_hp_key_q),
        .hp_len_q(e64_hp_len_q),
        .hp_lim_q(e64_hp_lim_q),
        .hp_make_arr_q(e64_hp_make_arr_q),
        .hp_nat_q(e64_hp_nat_q),
        .hp_oid_q(e64_hp_oid_q),
        .hp_phase_q(e64_hp_phase_q),
        .hp_proto_q(e64_hp_proto_q),
        .hp_qi_q(e64_hp_qi_q),
        .hp_qn_q(e64_hp_qn_q),
        .hp_ret_q(e64_hp_ret_q),
        .hp_rval_q(e64_hp_rval_q),
        .hp_si_q(e64_hp_si_q),
        .hp_slot_q(e64_hp_slot_q),
        .hp_spr_h_q(e64_hp_spr_h_q),
        .hp_spr_w_q(e64_hp_spr_w_q),
        .hp_ss_q(e64_hp_ss_q),
        .hp_tag_q(e64_hp_tag_q),
        .hp_tn_q(e64_hp_tn_q),
        .hp_v64_q(e64_hp_v64_q),
        .hp_vbase_q(e64_hp_vbase_q),
        .hp_wval_q(e64_hp_wval_q),
        .imgd_armed_q(e64_imgd_armed_q),
        .imgd_h_q(e64_imgd_h_q),
        .imgd_i_q(e64_imgd_i_q),
        .imgd_n_q(e64_imgd_n_q),
        .imgd_v64_q(e64_imgd_v64_q),
        .imgd_w_q(e64_imgd_w_q),
        .imgd_x_q(e64_imgd_x_q),
        .imgd_x0_q(e64_imgd_x0_q),
        .imgd_y_q(e64_imgd_y_q),
        .imgd_y0_q(e64_imgd_y0_q),
        .ip_q(e64_ip_q),
        .jn_arr_q(e64_jn_arr_q),
        .jn_h_q(e64_jn_h_q),
        .jn_i_q(e64_jn_i_q),
        .jn_res_q(e64_jn_res_q),
        .js_sp_q(e64_js_sp_q),
        .json_pph_q(e64_json_pph_q),
        .json_rp_q(e64_json_rp_q),
        .json_src_q(e64_json_src_q),
        .json_srclen_q(e64_json_srclen_q),
        .json_wp_q(e64_json_wp_q),
        .looping_q(e64_looping_q),
        .machine_fault_q(e64_machine_fault_q),
        .minmax_acc_q(e64_minmax_acc_q),
        .minmax_base_q(e64_minmax_base_q),
        .minmax_is_min_q(e64_minmax_is_min_q),
        .minmax_k_q(e64_minmax_k_q),
        .minmax_n_q(e64_minmax_n_q),
        .namcpy_armed_q(e64_namcpy_armed_q),
        .namcpy_repl_q(e64_namcpy_repl_q),
        .namcpy_v64_q(e64_namcpy_v64_q),
        .name_rdaddr_q(e64_name_rdaddr_q),
        .path_active_q(e64_path_active_q),
        .path_kind_q(e64_path_kind_q),
        .path_stroke_q(e64_path_stroke_q),
        .pc_n_q(e64_pc_n_q),
        .js_we_q(e64_js_we_q),
        .js_waddr_q(e64_js_waddr_q),
        .js_i_wdata_q(e64_js_i_wdata_q),
        .js_ph_wdata_q(e64_js_ph_wdata_q),
        .vjs_val_wdata_q(e64_vjs_val_wdata_q),
        .pc_we_q(e64_pc_we_q),
        .pc_waddr_q(e64_pc_waddr_q),
        .pc_op_wdata_q(e64_pc_op_wdata_q),
        .pc_a1_wdata_q(e64_pc_a1_wdata_q),
        .pc_a2_wdata_q(e64_pc_a2_wdata_q),
        .pc_a3_wdata_q(e64_pc_a3_wdata_q),
        .pc_a4_wdata_q(e64_pc_a4_wdata_q),
        .pc_a5_wdata_q(e64_pc_a5_wdata_q),
        .pc_ccw_wdata_q(e64_pc_ccw_wdata_q),
        .pi_q(e64_pi_q),
        .repl_did_q(e64_repl_did_q),
        .repl_g_q(e64_repl_g_q),
        .repl_nlen_q(e64_repl_nlen_q),
        .repl_pat0_q(e64_repl_pat0_q),
        .repl_pat1_q(e64_repl_pat1_q),
        .repl_rch_q(e64_repl_rch_q),
        .rh_q(e64_rh_q),
        .running_q(e64_running_q),
        .rw_q(e64_rw_q),
        .rx_q(e64_rx_q),
        .ry_q(e64_ry_q),
        .saved_sx_q(e64_saved_sx_q),
        .saved_sy_q(e64_saved_sy_q),
        .saved_tx_q(e64_saved_tx_q),
        .saved_ty_q(e64_saved_ty_q),
        .sq_i_q(e64_sq_i_q),
        .sq_rad_q(e64_sq_rad_q),
        .sq_rem_q(e64_sq_rem_q),
        .sq_root_q(e64_sq_root_q),
        .state_q(e64_state_q),
        .txt_bn_q(e64_txt_bn_q),
        .txt_ph_q(e64_txt_ph_q),
        .txt_px_q(e64_txt_px_q),
        .txt_py_q(e64_txt_py_q),
        .txt_val_q(e64_txt_val_q),
        .txt_vt_q(e64_txt_vt_q),
        .v64_concat_q(e64_v64_concat_q),
        .v64_join_q(e64_v64_join_q),
        .v64_repl_q(e64_v64_repl_q),
        .v64_sqrt_q(e64_v64_sqrt_q),
        .valloc_arr_n_q(e64_valloc_arr_n_q),
        .valloc_bind_q(e64_valloc_bind_q),
        .valloc_bind_src_q(e64_valloc_bind_src_q),
        .valloc_bind_this_q(e64_valloc_bind_this_q),
        .valloc_fn_a1_q(e64_valloc_fn_a1_q),
        .valloc_fn_entry_q(e64_valloc_fn_entry_q),
        .valloc_i_q(e64_valloc_i_q),
        .valloc_kind_q(e64_valloc_kind_q),
        .valloc_metrics_q(e64_valloc_metrics_q),
        .valloc_now_fn_q(e64_valloc_now_fn_q),
        .valloc_proto_q(e64_valloc_proto_q),
        .valloc_proto_fn_q(e64_valloc_proto_fn_q),
        .valloc_regex_q(e64_valloc_regex_q),
        .valloc_regex_pack_q(e64_valloc_regex_pack_q),
        .valloc_retried_q(e64_valloc_retried_q),
        .varr_next_q(e64_varr_next_q),
        .vcall_argc_q(e64_vcall_argc_q),
        .vcall_ctor_val_q(e64_vcall_ctor_val_q),
        .vcall_entry_q(e64_vcall_entry_q),
        .vcall_set_this_q(e64_vcall_set_this_q),
        .vcall_this_q(e64_vcall_this_q),
        .vcall_value_q(e64_vcall_value_q),
        .vconsole_n_q(e64_vconsole_n_q),
        .vcsp_q(e64_vcsp_q),
        .vdiv_count_q(e64_vdiv_count_q),
        .vdiv_den_q(e64_vdiv_den_q),
        .vdiv_exp_q(e64_vdiv_exp_q),
        .vdiv_num_q(e64_vdiv_num_q),
        .vdiv_quot_q(e64_vdiv_quot_q),
        .vdiv_rem_q(e64_vdiv_rem_q),
        .vdiv_sign_q(e64_vdiv_sign_q),
        .vdraw_color_q(e64_vdraw_color_q),
        .vdraw_h_q(e64_vdraw_h_q),
        .vdraw_i_q(e64_vdraw_i_q),
        .vdraw_w_q(e64_vdraw_w_q),
        .vdraw_x_q(e64_vdraw_x_q),
        .vdraw_y_q(e64_vdraw_y_q),
        .venv_q(e64_venv_q),
        .venv_next_q(e64_venv_next_q),
        .vfe_arr_q(e64_vfe_arr_q),
        .vfe_base_q(e64_vfe_base_q),
        .vfe_fn_q(e64_vfe_fn_q),
        .vfe_i_q(e64_vfe_i_q),
        .vfe_len_q(e64_vfe_len_q),
        .vfe_map_q(e64_vfe_map_q),
        .vfe_reduce_q(e64_vfe_reduce_q),
        .vfe_findidx_q(e64_vfe_findidx_q),
        .id_reduce(id_reduce),
        .vfe_mode_q(e64_vfe_mode_q),
        .vfe_ret_q(e64_vfe_ret_q),
        .vfe_sp_q(e64_vfe_sp_q),
        .vfree_armed_q(e64_vfree_armed_q),
        .vfree_arr_long_q(e64_vfree_arr_long_q),
        .vgc_clear_i_q(e64_vgc_clear_i_q),
        .vgc_halt_after_q(e64_vgc_halt_after_q),
        .vgc_qr_q(e64_vgc_qr_q),
        .vgc_qw_q(e64_vgc_qw_q),
        .vgc_resume_q(e64_vgc_resume_q),
        .vgc_wait_after_q(e64_vgc_wait_after_q),
        .vjs_rd_arm_q(e64_vjs_rd_arm_q),
        .vlistener_n_q(e64_vlistener_n_q),
        .vmetrics_w_q(e64_vmetrics_w_q),
        .vmod_count_q(e64_vmod_count_q),
        .vmod_den_q(e64_vmod_den_q),
        .vmod_exp_q(e64_vmod_exp_q),
        .vmod_rem_q(e64_vmod_rem_q),
        .vmod_sign_q(e64_vmod_sign_q),
        .vnat_base_q(e64_vnat_base_q),
        .vnat_dom_q(e64_vnat_dom_q),
        .vprom_copy_q(e64_vprom_copy_q),
        .vprom_done_q(e64_vprom_done_q),
        .vprom_ret_q(e64_vprom_ret_q),
        .vraf_n_q(e64_vraf_n_q),
        .vrng_q(e64_vrng_q),
        .vsp_q(e64_vsp_q),
        .vst_hold_win_q(e64_vst_hold_win_q),
        .vst_refill_arm_q(e64_vst_refill_arm_q),
        .vst_refill_i_q(e64_vst_refill_i_q),
        .vst_refill_ret_q(e64_vst_refill_ret_q),
        .vst_waddr_q(e64_vst_waddr_q),
        .vst_wdata_q(e64_vst_wdata_q),
        .vst_we_q(e64_vst_we_q),
        .vthis_q(e64_vthis_q),
        .vtimer_n_q(e64_vtimer_n_q),
        .vtimer_seq_q(e64_vtimer_seq_q),
        .x_q(e64_x_q),
        .y_q(e64_y_q),
        .hp_qk_pack_q(e64_hp_qk_pack_q),
        .hp_qt_pack_q(e64_hp_qt_pack_q),
        .hp_qv_pack_q(e64_hp_qv_pack_q),
        .json_mem_we_q(e64_json_mem_we),
        .json_mem_waddr_q(e64_json_mem_waddr),
        .json_mem_wdata_q(e64_json_mem_wdata),
        .vvars_raddr_q(e64_vvars_raddr),
        .venv_raddr_q(e64_venv_raddr),
        .varr_raddr_q(e64_varr_raddr),
        .vobj_raddr_q(e64_vobj_raddr),
        .vfn_raddr_q(e64_vfn_raddr),
        .name_off_raddr_q(e64_name_off_raddr),
        .fill_lut_raddr_q(e64_fill_lut_raddr),
        .vframe_raddr_q(e64_vframe_raddr),
        .vtimer_raddr_q(e64_vtimer_raddr),
        .vconsts_raddr_q(e64_vconsts_raddr),
        .name_blen_raddr_q(e64_name_blen_raddr),
        .name_blen_we_q(e64_name_blen_we),
        .name_blen_waddr_q(e64_name_blen_waddr),
        .name_blen_wdata_q(e64_name_blen_wdata),
        .name_hash_raddr_q(e64_name_hash_raddr),
        .name_hash_we_q(e64_name_hash_we),
        .name_hash_waddr_q(e64_name_hash_waddr),
        .name_hash_wdata_q(e64_name_hash_wdata),
        .name_has_we_q(e64_name_has_we),
        .name_has_waddr_q(e64_name_has_waddr),
        .name_has_wdata_q(e64_name_has_wdata),
        .varr_len_we_q(e64_varr_len_we),
        .varr_len_waddr_q(e64_varr_len_waddr),
        .varr_len_wdata_q(e64_varr_len_wdata),
        .varr_lidx_we_q(e64_varr_lidx_we),
        .varr_lidx_waddr_q(e64_varr_lidx_waddr),
        .varr_lidx_wdata_q(e64_varr_lidx_wdata),
        .varr_long_we_q(e64_varr_long_we),
        .varr_long_waddr_q(e64_varr_long_waddr),
        .varr_long_wdata_q(e64_varr_long_wdata),
        .varr_valid_we_q(e64_varr_valid_we),
        .varr_valid_waddr_q(e64_varr_valid_waddr),
        .varr_valid_wdata_q(e64_varr_valid_wdata),
        .venv_gen_we_q(e64_venv_gen_we),
        .venv_gen_waddr_q(e64_venv_gen_waddr),
        .venv_gen_wdata_q(e64_venv_gen_wdata),
        .venv_len_we_q(e64_venv_len_we),
        .venv_len_waddr_q(e64_venv_len_waddr),
        .venv_len_wdata_q(e64_venv_len_wdata),
        .venv_valid_we_q(e64_venv_valid_we),
        .venv_valid_waddr_q(e64_venv_valid_waddr),
        .venv_valid_wdata_q(e64_venv_valid_wdata),
        .vobj_cls_we_q(e64_vobj_cls_we),
        .vobj_cls_waddr_q(e64_vobj_cls_waddr),
        .vobj_cls_wdata_q(e64_vobj_cls_wdata),
        .vvar_valid_we_q(e64_vvar_valid_we),
        .vvar_valid_waddr_q(e64_vvar_valid_waddr),
        .vvar_valid_wdata_q(e64_vvar_valid_wdata),
        .vvars_we_q(e64_vvars_we),
        .vvars_waddr_q(e64_vvars_waddr),
        .vvars_wdata_q(e64_vvars_wdata),
        .vframe_we_q(e64_vframe_we),
        .vframe_waddr_q(e64_vframe_waddr),
        .vframe_rip_wdata_q(e64_vframe_rip_wdata),
        .vframe_bsp_wdata_q(e64_vframe_bsp_wdata),
        .vframe_esc_wdata_q(e64_vframe_esc_wdata),
        .vframe_this_wdata_q(e64_vframe_this_wdata),
        .vframe_env_wdata_q(e64_vframe_env_wdata),
        .vframe_fn_wdata_q(e64_vframe_fn_wdata),
        .vframe_ctor_wdata_q(e64_vframe_ctor_wdata),
        .vraf_we_q(e64_vraf_we),
        .vraf_waddr_q(e64_vraf_waddr),
        .vraf_wdata_q(e64_vraf_wdata),
        .vtimer_we_q(e64_vtimer_we),
        .vtimer_waddr_q(e64_vtimer_waddr),
        .vtimer_valid_wdata_q(e64_vtimer_valid_wdata),
        .vtimer_due_wdata_q(e64_vtimer_due_wdata),
        .vtimer_fn_wdata_q(e64_vtimer_fn_wdata),
        .vtimer_id_wdata_q(e64_vtimer_id_wdata),
        .vtimer_period_wdata_q(e64_vtimer_period_wdata),
        .vst_win0_we_q(e64_vst_win0_we),
        .vst_win0_wdata_q(e64_vst_win0_wdata)
    );

    // HEAP/FETCH use exec scalars (ip/hp_*/code_raddr/state), not a parent snapshot.
    st_t casestate;
    always_comb begin
        hs64 = v64_on && ((state == S_V64_EXEC) || (state == S_FETCH_WAIT) ||
            (state == S_HEAP_WAIT) || (state == S_HEAP_CMP) || (state == S_HEAP_WR) ||
            (state == S_HEAP_AWR) || (state == S_HEAP_FILL) || (state == S_V64_ALLOC) ||
            (state == S_WAIT_FRAME) || (state == S_V64_WAIT_FRAME) ||
            (state == S_V64_FRAME_RAF) || (state == S_V64_FRAME_TIMER) ||
            (state == S_V64_FRAME_KEY) || (state == S_V64_BIND) ||
            (state == S_V64_RECT) || (state == S_V64_RECT_LD) || (state == S_V64_CLEAR) ||
            (state == S_V64_CTOR_PAD) || (state == S_V64_CTOR_ENV) ||
            (state == S_V64_CTOR_VARS) ||
            (state == S_V64_FOREACH) || (state == S_V64_FE_ELEM) ||
            (state == S_V64_FE_FILTER) || (state == S_V64_METH) ||
            (state == S_V64_MINMAX) || (state == S_V64_WIN_FILL) ||
            (state == S_V64_RECT_LD) ||
            (state == S_V64_JSON) || (state == S_V64_JSON_PARSE) ||
            (state == S_V64_STRIDX) || (state == S_V64_STRIDX_WR) ||
            (state == S_V64_DIV) || (state == S_V64_DIV_FIN) ||
            (state == S_V64_MOD) || (state == S_V64_CONST_HI) ||
            (state == S_V64_IDXSCAN) || (state == S_V64_OGETI_NAT) ||
            (state == S_V64_GC_CLEAR) || (state == S_V64_GC_ROOT) ||
            (state == S_V64_GC_POP) || (state == S_V64_GC_OBJ) ||
            (state == S_V64_GC_ARR) || (state == S_V64_GC_FN) ||
            (state == S_V64_GC_ENV) || (state == S_V64_GC_SWEEP_OBJ) ||
            (state == S_V64_GC_SWEEP_ARR) || (state == S_V64_GC_SWEEP_ENV) ||
            (state == S_V64_SLICE) || // #40 exec-entered slice copy
            (state == S_V64_SORT) || // #41 exec-entered sort walk
            // potential-bugs #68: exec-entered result-array scan. Without
            // this, hp_ret (and friends) read the PARENT ffs mid-scan —
            // stale S_V64_FOREACH from the previous filter/map walk — so a
            // second filter/map in one program exited its scan INTO the
            // walk state and re-dispatched the CALL_METH per iteration.
            (state == S_FREE_ARR) ||
            (state == S_TXT_LD) || (state == S_TXT_DRAW) ||
            (state == S_CONCAT) || (state == S_JOIN) ||
            (state == S_JOIN_FIND) || (state == S_STR_WR));
        // exec32 retirement Phase 2: tagged images fault at S_GOT_HDR2,
        // so this arm can never be taken. Forced low ahead of the Phase 3
        // unhook so a silent dependency surfaces while the module is still
        // wired (docs/REMOVING_EXEC32.md).
        hs32 = 1'b0 && ((state == S_EXEC) || (state == S_NAT) ||
            (state == S_FETCH_WAIT) || (state == S_HEAP_WAIT) || (state == S_HEAP_CMP) ||
            (state == S_HEAP_WR) || (state == S_HEAP_AWR) || (state == S_HEAP_FILL));
        if ((state == S_V64_EXEC) && e64_leave_hold)
            casestate = st_t'(e64_state_q);
        else if (((state == S_EXEC) || (state == S_NAT)) && e32_leave_hold)
            casestate = st_t'(e32_state_q);
        else
            casestate = state;
    end
    // UG901: SRAM address mux must see a flop, not combo casestate (leave_hold
    // overlay of e32/e64_state_q). That combo fanout into ~40 memories was the
    // post-8-6014 70 GB wall. FSM case (casestate) stays combo for same-cycle
    // leave_hold. Extra rdata beat on overlay is OK (wait already).
    st_t casestate_q /*verilator public_flat_rd*/;
    always_ff @(posedge clk) begin
        if (!rst_n) casestate_q <= S_IDLE;
        else casestate_q <= casestate;
    end
    always_ff @(posedge clk) begin
        vdbg_o       <= {1'b0, 7'(casestate_q), fault_code, ip};
        vdbg_fault_o <= machine_fault;

    end

    // Live HEAP/FETCH view: these clock in exec. Masked parent writes (hs_m_*)
    // overlay for the SRAM wait cycle after a poke.
    // The 69-member hs64 handshake mux family is (* dont_touch *): each is a
    // tiny two-level 2:1 selector, and ExploreArea's Retarget pass hunting
    // cross-instance sharing across a near-identical family this large is
    // the prime suspect for the 14h opt_design stall (log frozen, CPU
    // pinned, near-zero I/O — the AMD-documented pattern). Fencing them
    // costs ~nothing in area; if ExploreArea still stalls, the trigger is
    // elsewhere (see OVERNIGHT_STATUS.md 2026-08-24).
    (* dont_touch = "true" *)
    assign ip = hs64 ? (hs_m_ip ? ip_ff : e64_ip_q) :
                hs32 ? (hs_m_ip ? ip_ff : e32_ip_q) : ip_ff;
    (* dont_touch = "true" *)
    assign code_raddr = hs64 ? (hs_m_code ? code_raddr_ff : e64_code_raddr_q) :
                hs32 ? (hs_m_code ? code_raddr_ff : e32_code_raddr_q) : code_raddr_ff;
    (* dont_touch = "true" *)
    assign vsp = hs64 ? (hs_m_vsp ? vsp_ff : e64_vsp_q) : vsp_ff;
    (* dont_touch = "true" *)
    assign hp_cmd = hs64 ? (hs_m_hp_cmd ? hp_cmd_ff : e64_hp_cmd_q) :
                hs32 ? (hs_m_hp_cmd ? hp_cmd_ff : e32_hp_cmd_q) : hp_cmd_ff;
    (* dont_touch = "true" *)
    assign hp_v64 = hs64 ? (hs_m_hp_v64 ? hp_v64_ff : e64_hp_v64_q) :
                hs32 ? (hs_m_hp_v64 ? hp_v64_ff : e32_hp_v64_q) : hp_v64_ff;
    (* dont_touch = "true" *)
    assign hp_oid = hs64 ? (hs_m_hp_oid ? hp_oid_ff : e64_hp_oid_q) :
                hs32 ? (hs_m_hp_oid ? hp_oid_ff : e32_hp_oid_q) : hp_oid_ff;
    (* dont_touch = "true" *)
    assign hp_aid = hs64 ? (hs_m_hp_aid ? hp_aid_ff : e64_hp_aid_q) :
                hs32 ? (hs_m_hp_aid ? hp_aid_ff : e32_hp_aid_q) : hp_aid_ff;
    (* dont_touch = "true" *)
    assign hp_env = hs64 ? (hs_m_hp_env ? hp_env_ff : e64_hp_env_q) : hp_env_ff;
    (* dont_touch = "true" *)
    assign hp_eid = hs64 ? (hs_m_hp_eid ? hp_eid_ff : e64_hp_eid_q) : hp_eid_ff;
    (* dont_touch = "true" *)
    assign hp_slot = hs64 ? (hs_m_hp_slot ? hp_slot_ff : e64_hp_slot_q) :
                hs32 ? (hs_m_hp_slot ? hp_slot_ff : e32_hp_slot_q) : hp_slot_ff;
    (* dont_touch = "true" *)
    assign hp_aslot = hs64 ? (hs_m_hp_aslot ? hp_aslot_ff : e64_hp_aslot_q) :
                hs32 ? (hs_m_hp_aslot ? hp_aslot_ff : e32_hp_aslot_q) : hp_aslot_ff;
    (* dont_touch = "true" *)
    assign hp_len = hs64 ? (hs_m_hp_len ? hp_len_ff : e64_hp_len_q) :
                hs32 ? (hs_m_hp_len ? hp_len_ff : e32_hp_len_q) : hp_len_ff;
    (* dont_touch = "true" *)
    assign hp_alen = hs64 ? (hs_m_hp_alen ? hp_alen_ff : e64_hp_alen_q) :
                hs32 ? (hs_m_hp_alen ? hp_alen_ff : e32_hp_alen_q) : hp_alen_ff;
    (* dont_touch = "true" *)
    assign hp_lim = hs64 ? (hs_m_hp_lim ? hp_lim_ff : e64_hp_lim_q) :
                hs32 ? (hs_m_hp_lim ? hp_lim_ff : e32_hp_lim_q) : hp_lim_ff;
    (* dont_touch = "true" *)
    assign hp_key = hs64 ? (hs_m_hp_key ? hp_key_ff : e64_hp_key_q) :
                hs32 ? (hs_m_hp_key ? hp_key_ff : e32_hp_key_q) : hp_key_ff;
    (* dont_touch = "true" *)
    assign hp_wval = hs64 ? (hs_m_hp_wval ? hp_wval_ff : e64_hp_wval_q) :
                hs32 ? (hs_m_hp_wval ? hp_wval_ff : e32_hp_wval_q) : hp_wval_ff;
    (* dont_touch = "true" *)
    assign hp_rval = hs64 ? (hs_m_hp_rval ? hp_rval_ff : e64_hp_rval_q) :
                hs32 ? (hs_m_hp_rval ? hp_rval_ff : e32_hp_rval_q) : hp_rval_ff;
    (* dont_touch = "true" *)
    assign hp_hit = hs64 ? (hs_m_hp_hit ? hp_hit_ff : e64_hp_hit_q) :
                hs32 ? (hs_m_hp_hit ? hp_hit_ff : e32_hp_hit_q) : hp_hit_ff;
    (* dont_touch = "true" *)
    assign hp_ret = hs64 ? (hs_m_hp_ret ? hp_ret_ff : st_t'(e64_hp_ret_q)) :
                hs32 ? (hs_m_hp_ret ? hp_ret_ff : st_t'(e32_hp_ret_q)) : hp_ret_ff;
    (* dont_touch = "true" *)
    assign hp_phase = hs64 ? (hs_m_hp_phase ? hp_phase_ff : e64_hp_phase_q) :
                hs32 ? (hs_m_hp_phase ? hp_phase_ff : e32_hp_phase_q) : hp_phase_ff;
    (* dont_touch = "true" *)
    assign hp_proto = hs64 ? (hs_m_hp_proto ? hp_proto_ff : e64_hp_proto_q) :
                hs32 ? (hs_m_hp_proto ? hp_proto_ff : e32_hp_proto_q) : hp_proto_ff;
    (* dont_touch = "true" *)
    assign hp_qn = hs64 ? (hs_m_hp_qn ? hp_qn_ff : e64_hp_qn_q) :
                hs32 ? (hs_m_hp_qn ? hp_qn_ff : e32_hp_qn_q) : hp_qn_ff;
    (* dont_touch = "true" *)
    assign hp_qi = hs64 ? (hs_m_hp_qi ? hp_qi_ff : e64_hp_qi_q) :
                hs32 ? (hs_m_hp_qi ? hp_qi_ff : e32_hp_qi_q) : hp_qi_ff;
    (* dont_touch = "true" *)
    assign hp_si = hs64 ? (hs_m_hp_si ? hp_si_ff : e64_hp_si_q) :
                hs32 ? (hs_m_hp_si ? hp_si_ff : e32_hp_si_q) : hp_si_ff;
    (* dont_touch = "true" *)
    assign hp_ss = hs64 ? (hs_m_hp_ss ? hp_ss_ff : e64_hp_ss_q) :
                hs32 ? (hs_m_hp_ss ? hp_ss_ff : e32_hp_ss_q) : hp_ss_ff;
    (* dont_touch = "true" *)
    assign hp_tn = hs64 ? (hs_m_hp_tn ? hp_tn_ff : e64_hp_tn_q) :
                hs32 ? (hs_m_hp_tn ? hp_tn_ff : e32_hp_tn_q) : hp_tn_ff;
    (* dont_touch = "true" *)
    assign hp_from_stack = hs64 ? (hs_m_hp_from_stack ? hp_from_stack_ff : e64_hp_from_stack_q) :
                hs32 ? (hs_m_hp_from_stack ? hp_from_stack_ff : e32_hp_from_stack_q) : hp_from_stack_ff;
    (* dont_touch = "true" *)
    assign hp_make_arr = hs64 ? (hs_m_hp_make_arr ? hp_make_arr_ff : e64_hp_make_arr_q) :
                hs32 ? (hs_m_hp_make_arr ? hp_make_arr_ff : e32_hp_make_arr_q) : hp_make_arr_ff;
    (* dont_touch = "true" *)
    assign hp_vbase = hs64 ? (hs_m_hp_vbase ? hp_vbase_ff : e64_hp_vbase_q) :
                hs32 ? (hs_m_hp_vbase ? hp_vbase_ff : e32_hp_vbase_q) : hp_vbase_ff;
    (* dont_touch = "true" *)
    assign hp_spr_w = hs64 ? (hs_m_hp_spr_w ? hp_spr_w_ff : e64_hp_spr_w_q) : hp_spr_w_ff;
    (* dont_touch = "true" *)
    assign hp_spr_h = hs64 ? (hs_m_hp_spr_h ? hp_spr_h_ff : e64_hp_spr_h_q) : hp_spr_h_ff;
    (* dont_touch = "true" *)
    assign hp_nat = hs64 ? (hs_m_hp_nat ? hp_nat_ff : e64_hp_nat_q) :
                hs32 ? (hs_m_hp_nat ? hp_nat_ff : e32_hp_nat_q) : hp_nat_ff;
    (* dont_touch = "true" *)
    assign hp_tag = hs64 ? (hs_m_hp_tag ? hp_tag_ff : e64_hp_tag_q) :
                hs32 ? (hs_m_hp_tag ? hp_tag_ff : e32_hp_tag_q) : hp_tag_ff;
    // ALLOC leave: read exec valloc_*/vcall_*/vnat_*/vcsp, not a dump.
    // During ALLOC the scan lives in parent *_ff. hs_m is one-shot, so
    // after the rdata wait beat the mux would snap back to frozen exec
    // valloc_i_q (always the first slot) and skip every later hole.
    assign valloc_kind = (state == S_V64_ALLOC || hs_m_valloc_kind) ? valloc_kind_ff :
                (hs64 ? e64_valloc_kind_q : valloc_kind_ff);
    assign valloc_i = (state == S_V64_ALLOC || hs_m_valloc_i) ? valloc_i_ff :
                (hs64 ? e64_valloc_i_q : valloc_i_ff);
    (* dont_touch = "true" *)
    assign valloc_arr_n = hs64 ? (hs_m_valloc_arr_n ? valloc_arr_n_ff : e64_valloc_arr_n_q) : valloc_arr_n_ff;
    (* dont_touch = "true" *)
    assign valloc_retried = hs64 ? (hs_m_valloc_retried ? valloc_retried_ff : e64_valloc_retried_q) : valloc_retried_ff;
    (* dont_touch = "true" *)
    assign vnat_dom = hs64 ? (hs_m_vnat_dom ? vnat_dom_ff : e64_vnat_dom_q) : vnat_dom_ff;
    assign ctx_align_eff = v64_on ? e64_ctx_align_q : e32_ctx_align_q;
    // S_ARR_PROMOTE is requested by exec (arr.push / ARRAY_SET growing
    // past ARR_SHORT_CAP) as well as by the parent's JSON parse. Exec
    // sets its own vprom_ret (= S_V64_EXEC); the parent's copy is only
    // written by the JSON paths and otherwise still holds its reset
    // value S_IDLE — so an exec-requested promote 'returned' into a
    // silent halt with fault=0. INVADERS froze exactly there on Space
    // (startGame pushes past the short-array cap).
    // potential-bugs #57: the unconditional e64_vprom_ret_q pick fixed the
    // exec-requested promote (push/ARR_SET past the short cap) but broke the
    // PARENT-requested ones: S_V64_JSON_PARSE sets the parent vprom_ret and
    // never touches exec's, whose reset value is 0 = S_IDLE — parsing an
    // array longer than 32 rows (PACMAN's maze) promoted correctly and then
    // 'returned' into a silent halt (fault=0, S_IDLE; VRING showed
    // S_ARR_PROMOTE -> S_IDLE). Track who requested the promote: the
    // first-entry guard fires only for exec entries (parent hs_st entries
    // arrive with state already S_ARR_PROMOTE).
    logic vprom_from_exec;
    st_t vprom_ret_eff;
    assign vprom_ret_eff = (v64_on && vprom_from_exec)
                                        ? st_t'(e64_vprom_ret_q)
                                        : vprom_ret;
    assign dbg_align = ctx_align_eff;
    (* dont_touch = "true" *)
    assign vnat_base = hs64 ? (hs_m_vnat_base ? vnat_base_ff : e64_vnat_base_q) : vnat_base_ff;
    (* dont_touch = "true" *)
    assign valloc_now_fn = hs64 ? (hs_m_valloc_now_fn ? valloc_now_fn_ff : e64_valloc_now_fn_q) : valloc_now_fn_ff;
    (* dont_touch = "true" *)
    assign valloc_bind = hs64 ? (hs_m_valloc_bind ? valloc_bind_ff : e64_valloc_bind_q) : valloc_bind_ff;
    (* dont_touch = "true" *)
    assign valloc_bind_src = hs64 ? (hs_m_valloc_bind_src ? valloc_bind_src_ff : e64_valloc_bind_src_q) : valloc_bind_src_ff;
    (* dont_touch = "true" *)
    assign valloc_bind_this = hs64 ? (hs_m_valloc_bind_this ? valloc_bind_this_ff : e64_valloc_bind_this_q) : valloc_bind_this_ff;
    (* dont_touch = "true" *)
    assign valloc_fn_entry = hs64 ? (hs_m_valloc_fn_entry ? valloc_fn_entry_ff : e64_valloc_fn_entry_q) : valloc_fn_entry_ff;
    (* dont_touch = "true" *)
    assign valloc_fn_a1 = hs64 ? (hs_m_valloc_fn_a1 ? valloc_fn_a1_ff : e64_valloc_fn_a1_q) : valloc_fn_a1_ff;
    (* dont_touch = "true" *)
    assign valloc_proto = hs64 ? (hs_m_valloc_proto ? valloc_proto_ff : e64_valloc_proto_q) : valloc_proto_ff;
    (* dont_touch = "true" *)
    assign valloc_proto_fn = hs64 ? (hs_m_valloc_proto_fn ? valloc_proto_fn_ff : e64_valloc_proto_fn_q) : valloc_proto_fn_ff;
    (* dont_touch = "true" *)
    assign valloc_metrics = hs64 ? (hs_m_valloc_metrics ? valloc_metrics_ff : e64_valloc_metrics_q) : valloc_metrics_ff;
    (* dont_touch = "true" *)
    assign valloc_regex = hs64 ? (hs_m_valloc_regex ? valloc_regex_ff : e64_valloc_regex_q) : valloc_regex_ff;
    (* dont_touch = "true" *)
    assign valloc_regex_pack = hs64 ? (hs_m_valloc_regex_pack ? valloc_regex_pack_ff : e64_valloc_regex_pack_q) : valloc_regex_pack_ff;
    (* dont_touch = "true" *)
    assign vcall_value = hs64 ? (hs_m_vcall_value ? vcall_value_ff : e64_vcall_value_q) : vcall_value_ff;
    (* dont_touch = "true" *)
    assign vcall_argc = hs64 ? (hs_m_vcall_argc ? vcall_argc_ff : e64_vcall_argc_q) : vcall_argc_ff;
    (* dont_touch = "true" *)
    assign vcall_entry = hs64 ? (hs_m_vcall_entry ? vcall_entry_ff : e64_vcall_entry_q) : vcall_entry_ff;
    (* dont_touch = "true" *)
    assign vcall_set_this = hs64 ? (hs_m_vcall_set_this ? vcall_set_this_ff : e64_vcall_set_this_q) : vcall_set_this_ff;
    (* dont_touch = "true" *)
    assign vcall_this = hs64 ? (hs_m_vcall_this ? vcall_this_ff : e64_vcall_this_q) : vcall_this_ff;
    (* dont_touch = "true" *)
    assign vcall_ctor_val = hs64 ? (hs_m_vcall_ctor_val ? vcall_ctor_val_ff : e64_vcall_ctor_val_q) : vcall_ctor_val_ff;
    (* dont_touch = "true" *)
    assign vcsp = hs64 ? (hs_m_vcsp ? vcsp_ff : e64_vcsp_q) : vcsp_ff;
    (* dont_touch = "true" *)
    assign vthis = hs64 ? (hs_m_vthis ? vthis_ff : e64_vthis_q) : vthis_ff;
    (* dont_touch = "true" *)
    assign venv = hs64 ? (hs_m_venv ? venv_ff : e64_venv_q) : venv_ff;
    // rAF/GC flags: WAIT_FRAME and GC_CLEAR read exec, not parent zeros.
    (* dont_touch = "true" *)
    assign vraf_n = hs64 ? (hs_m_vraf_n ? vraf_n_ff : e64_vraf_n_q) : vraf_n_ff;
    (* dont_touch = "true" *)
    assign vlistener_n = hs64 ? (hs_m_vlistener_n ? vlistener_n_ff : e64_vlistener_n_q) : vlistener_n_ff;
    assign dbg_id_keydown = id_keydown;
    assign dbg_id_keyup = id_keyup;
    (* dont_touch = "true" *)
    assign vgc_halt_after = hs64 ? (hs_m_vgc_halt_after ? vgc_halt_after_ff : e64_vgc_halt_after_q) : vgc_halt_after_ff;
    (* dont_touch = "true" *)
    assign vgc_wait_after = hs64 ? (hs_m_vgc_wait_after ? vgc_wait_after_ff : e64_vgc_wait_after_q) : vgc_wait_after_ff;
    (* dont_touch = "true" *)
    assign vgc_clear_i = hs64 ? (hs_m_vgc_clear_i ? vgc_clear_i_ff : e64_vgc_clear_i_q) : vgc_clear_i_ff;
    (* dont_touch = "true" *)
    assign vgc_qr = hs64 ? (hs_m_vgc_qr ? vgc_qr_ff : e64_vgc_qr_q) : vgc_qr_ff;
    (* dont_touch = "true" *)
    assign vgc_qw = hs64 ? (hs_m_vgc_qw ? vgc_qw_ff : e64_vgc_qw_q) : vgc_qw_ff;
    (* dont_touch = "true" *)
    assign vdraw_i = hs64 ? (hs_m_vdraw_i ? vdraw_i_ff : e64_vdraw_i_q) : vdraw_i_ff;
    assign vdraw_x = (state == S_V64_RECT) ? vdraw_x_ff :
        (hs64 ? (hs_m_vdraw_x ? vdraw_x_ff : e64_vdraw_x_q) : vdraw_x_ff);
    assign vdraw_y = (state == S_V64_RECT) ? vdraw_y_ff :
        (hs64 ? (hs_m_vdraw_y ? vdraw_y_ff : e64_vdraw_y_q) : vdraw_y_ff);
    assign vdraw_w = (state == S_V64_RECT) ? vdraw_w_ff :
        (hs64 ? (hs_m_vdraw_w ? vdraw_w_ff : e64_vdraw_w_q) : vdraw_w_ff);
    assign vdraw_h = (state == S_V64_RECT) ? vdraw_h_ff :
        (hs64 ? (hs_m_vdraw_h ? vdraw_h_ff : e64_vdraw_h_q) : vdraw_h_ff);
    (* dont_touch = "true" *)
    assign vdraw_color = hs64 ? (hs_m_vdraw_color ? vdraw_color_ff : e64_vdraw_color_q) : vdraw_color_ff;
    genvar gi_hs;
    generate
        for (gi_hs = 0; gi_hs < 4; gi_hs++) begin : g_hp_q
            assign hp_qk[gi_hs] = hs64 ? (hs_m_hp_qk ? hp_qk_ff[gi_hs] : e64_hp_qk_pack_q[16*gi_hs +: 16]) :
                hs32 ? (hs_m_hp_qk ? hp_qk_ff[gi_hs] : e32_hp_qk_pack_q[16*gi_hs +: 16]) : hp_qk_ff[gi_hs];
            assign hp_qv[gi_hs] = hs64 ? (hs_m_hp_qv ? hp_qv_ff[gi_hs] : e64_hp_qv_pack_q[64*gi_hs +: 64]) :
                hs32 ? (hs_m_hp_qv ? hp_qv_ff[gi_hs] : e32_hp_qv_pack_q[64*gi_hs +: 64]) : hp_qv_ff[gi_hs];
            assign hp_qt[gi_hs] = hs64 ? (hs_m_hp_qt ? hp_qt_ff[gi_hs] : e64_hp_qt_pack_q[3*gi_hs +: 3]) :
                hs32 ? (hs_m_hp_qt ? hp_qt_ff[gi_hs] : e32_hp_qt_pack_q[3*gi_hs +: 3]) : hp_qt_ff[gi_hs];
        end
    endgenerate
    genvar gi_e32pack;
    generate
        for (gi_e32pack = 0; gi_e32pack < 4; gi_e32pack++) begin : g_e32_hp_pack
            assign hp_qk_ff_pack[16*gi_e32pack +: 16] = hp_qk_ff[gi_e32pack];
            assign hp_qt_ff_pack[3*gi_e32pack +: 3] = hp_qt_ff[gi_e32pack];
            assign hp_qv_ff_pack[64*gi_e32pack +: 64] = hp_qv_ff[gi_e32pack];
        end
        for (gi_e32pack = 0; gi_e32pack < 16; gi_e32pack++) begin : g_e32_spr_pack
            assign spr_hh_pack[16*gi_e32pack +: 16] = spr_hh[gi_e32pack];
            assign spr_nid_pack[16*gi_e32pack +: 16] = spr_nid[gi_e32pack];
            assign spr_ww_pack[16*gi_e32pack +: 16] = spr_ww[gi_e32pack];
        end
    endgenerate

    // flatten: one cstack raddr. GC_ROOT walks gc_root_i; refill is pop
    // repair. TOS/NOS are window FFs — never cstack[csp-1] and [csp-2] together.
    logic        cstack_gc_rd;
    logic [6:0]  cstack_gc_raddr;
    logic        cstack_sram_rd;
    logic [6:0]  cstack_raddr;
    logic [8:0]  env_cap_raddr;
    assign cstack_gc_rd =
        (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
        (gc_root_i >= 13'd2745 && gc_root_i < 13'd3257);
    assign cstack_gc_raddr =
        (gc_root_i >= 13'd3129) ? 7'(gc_root_i - 13'd3129) :
        (gc_root_i >= 13'd3001) ? 7'(gc_root_i - 13'd3001) :
        (gc_root_i >= 13'd2873) ? 7'(gc_root_i - 13'd2873) :
        7'(gc_root_i - 13'd2745);
    assign cstack_sram_rd = cstack_gc_rd || (cs_refill != 2'd0);
    assign cstack_raddr = cstack_gc_rd ? cstack_gc_raddr : cs_raddr_ff;
    // flatten: env_cap 512 — one raddr, rdata next. Never env_cap[0] default.
    assign env_cap_raddr =
        (casestate_q == S_HEAP_CLR || state == S_HEAP_CLR) ? heap_clr_i[8:0] :
        (casestate_q == S_REL_ENV || state == S_REL_ENV) ? {3'd0, rel_i} :
        {3'd0, env_sp};

    // flatten: v64_mul_task / *_pack_task inlined into unique case (casestate)
    // is a 106-bit combo mul + unrolled 53/107-bit for-loops in THAT cone
    // (14:01 bit: ~72 GB RSS, log frozen after e32_p_clr). One always_comb
    // here is one mul/pack, not one copy per case arm. Unique case only
    // consumes the wires.
    logic [63:0] vdiv_pack_n, vmod_pack_n;
    logic [53:0] vmod_shifted_n;
    logic [52:0] vmod_next_rem_n;
    assign vmod_shifted_n = {vmod_rem, 1'b0};
    assign vmod_next_rem_n = (vmod_shifted_n >= {1'b0, vmod_den})
        ? 53'(vmod_shifted_n - {1'b0, vmod_den})
        : vmod_shifted_n[52:0];
    always_comb begin
        v64_div_pack_task(vdiv_sign, vdiv_exp, vdiv_quot, vdiv_rem,
                          vdiv_pack_n);
        v64_mod_pack_task(vmod_sign, vmod_exp, vmod_next_rem_n, vmod_pack_n);
    end

    // C3 (run 50): the rAF timestamp vframe_no * 50/3 was the parent's
    // ONLY combinational 53x53 double multiply (v64_mul_task, deleted)
    // and the measured worst intra-VM cone (run 49 checkpoint: 75.3 ns
    // of the 80 ns budget, 86 levels, every worst path vframe_no ->
    // vst_wdata). Free-running engine, one beat per multiplier bit:
    // acc = vframe_no * RAF_TS_M exactly (85-bit integer product), then
    // one pack beat (leading-bit scan of the REGISTERED product, round
    // to nearest even) = bit-identical to the IEEE double product for
    // every n, since both inputs are exact. ~34 VM beats once per
    // frame; the rAF push stalls on raf_ts_rdy so a stale value is
    // unobservable by construction (covers program-start vframe_no
    // resets and the same-beat increment hazard alike).
    localparam logic [52:0] RAF_TS_M = 53'h10AAAAAAAAAAAB; // mant(50/3)
    logic [31:0] raf_n_q, raf_n_cap, raf_nsh;
    logic [84:0] raf_acc, raf_msh;
    logic [5:0]  raf_i;
    logic        raf_run, raf_pck;
    logic [63:0] raf_ts_q;
    logic        raf_ts_rdy;
    logic [63:0] raf_pack_n;
    always_comb begin
        logic [6:0]  rp;
        logic [6:0]  rsh;
        logic [52:0] rmant;
        logic        rg, rst_s;
        logic [53:0] rrnd;
        rp = 7'd0;
        for (int k = 0; k < 85; k++)
            if (raf_acc[k]) rp = 7'(k);          // fixed-bit scan (log depth)
        rsh = rp - 7'd52;                        // rp >= 52 for any n >= 1
        rmant = 53'(raf_acc >> rsh);
        rg = (rsh != 7'd0) ? raf_acc[rsh - 7'd1] : 1'b0;
        rst_s = 1'b0;
        for (int k = 0; k < 85; k++)
            if (7'(k) + 7'd1 < rsh && raf_acc[k]) rst_s = 1'b1;
        rrnd = {1'b0, rmant} + 54'(rg && (rst_s || rmant[0]));
        if (rrnd[53]) begin
            rmant = rrnd[53:1];
            rp = rp + 7'd1;
        end else rmant = rrnd[52:0];
        // value = acc * 2^-48 -> biased exponent = 1023 + rp - 48
        raf_pack_n = (raf_acc == 85'd0)
            ? 64'd0
            : {1'b0, 11'(11'd975 + 11'(rp)), rmant[51:0]};
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            raf_n_q <= 32'hFFFFFFFF;   // != any real vframe_no: recompute
            raf_ts_q <= 64'd0;
            raf_run <= 1'b0;
            raf_pck <= 1'b0;
        end else if (raf_run) begin
            if (raf_nsh[0]) raf_acc <= raf_acc + raf_msh;
            raf_msh <= raf_msh << 1;
            raf_nsh <= raf_nsh >> 1;
            raf_i <= raf_i + 6'd1;
            if (raf_i == 6'd31) begin
                raf_run <= 1'b0;
                raf_pck <= 1'b1;
            end
        end else if (raf_pck) begin
            raf_ts_q <= raf_pack_n;
            raf_n_q <= raf_n_cap;
            raf_pck <= 1'b0;
        end else if (vframe_no != raf_n_q) begin
            raf_n_cap <= vframe_no;
            raf_nsh <= vframe_no;
            raf_msh <= {32'd0, RAF_TS_M};
            raf_acc <= 85'd0;
            raf_i <= 6'd0;
            raf_run <= 1'b1;
        end
    end
    assign raf_ts_rdy = !raf_run && !raf_pck && (raf_n_q == vframe_no);

    // Intern `new Stage` (`var Stage = function`): ctor handle is bind_ins
    // (CTOR_ENV), not VST_AT. NEW_OBJ clocks vcall_value=0; CTOR_ENV
    // hs_vcall_value(1) is one-shot, so kind 3 saw is_valcall=0 and
    // CTOR_PAD entry FFFF (PACMAN LOAD_VAR stage fault 4 after LET_VAR).
    // Combo NEW_OBJ&&bind_ins also dropped after BIND (code_rdata no
    // longer NEW_OBJ / bind_ins last arg). intern_ctor_hold stays.
    wire intern_ctor_fn;
    assign intern_ctor_fn = intern_ctor_hold;

    // Read+write are their own processes (same shape as jmr_mini_fb Port A).
    // The 7k-line FSM poking ram[i] <= made Vivado build FFs (70 GB after e32_p_clr).
    // STRIDX must keep exec's byte address while casestate_q leaves EXEC
    // (second wait beat). Switching to parent name_rdaddr mid-op would
    // clobber name_rdata before char_id is captured (splash sprites gone).
    assign name_mem_raddr = ((casestate_q == S_V64_EXEC) ||
                             (casestate_q == S_V64_STRIDX))
        ? e64_name_rdaddr_q[14:0] : name_rdaddr[14:0];
    assign json_rdaddr =
        ((casestate_q == S_REPL) && jn_name_arm) ? (json_rp[12:0] + 13'd1) :
        ((casestate_q == S_TXT_LD) && (txt_ph == 4'd4)) ? txt_rp[12:0] :
        json_rp[12:0];
    always_ff @(posedge clk) begin
        if (name_we) name_mem[name_waddr] <= name_wdata;
        name_rdata <= name_mem[name_mem_raddr];
    end
    always_ff @(posedge clk) begin
        if (json_we) json_mem[json_waddr] <= json_wdata;
        json_mem_rdata <= json_mem[json_rdaddr];
    end
    always_ff @(posedge clk) begin
        // spr_mem external - no on-chip storage
    end
    always_ff @(posedge clk) begin
        // imgd_pix array deleted - snapshot pixels stream over the external
        // SRAM port from S_IMGD_GET / S_IMGD_PUT (blit-style req/ack).
    end

    // Scalar write mux (exec we same cycle; parent *_we is the json_putc NBA).
    wire stack_ram_we = stack_we ||
        (((state == S_EXEC) || (state == S_NAT)) && e32_stack_we);
    wire [10:0] stack_ram_waddr = stack_we ? stack_waddr : e32_stack_waddr[10:0];
    wire signed [31:0] stack_ram_wdata = stack_we ? stack_wdata : e32_stack_wdata;
    wire stack_tag_ram_we = stack_tag_we ||
        (((state == S_EXEC) || (state == S_NAT)) && e32_stack_tag_we);
    wire [10:0] stack_tag_ram_waddr = stack_tag_we ? stack_tag_waddr
        : e32_stack_tag_waddr[10:0];
    wire [2:0] stack_tag_ram_wdata = stack_tag_we ? stack_tag_wdata
        : e32_stack_tag_wdata;
    wire name_hash_ram_we = name_hash_we ||
        (e64_p_we && e64_p_sel == 6'd40) || e64_name_hash_we;
    wire [9:0] name_hash_ram_waddr = name_hash_we ? name_hash_waddr :
        (e64_p_we && e64_p_sel == 6'd40) ? e64_p_addr[9:0] : e64_name_hash_waddr;
    wire [15:0] name_hash_ram_wdata = name_hash_we ? name_hash_wdata :
        (e64_p_we && e64_p_sel == 6'd40) ? e64_p_data[15:0] : e64_name_hash_wdata;
    wire varr_len_ram_we = varr_len_we ||
        ((state == S_V64_EXEC) && e64_varr_len_we);
    wire [11:0] varr_len_ram_waddr = varr_len_we ? varr_len_waddr
        : e64_varr_len_waddr;
    wire [7:0] varr_len_ram_wdata = varr_len_we ? varr_len_wdata
        : e64_varr_len_wdata;
    wire vvars_ram_we = vvars_we ||
        ((state == S_V64_EXEC) && e64_vvars_we);
    wire [8:0] vvars_ram_waddr = vvars_we ? vvars_waddr : e64_vvars_waddr[8:0];
    wire [63:0] vvars_ram_wdata = vvars_we ? vvars_wdata : e64_vvars_wdata;

    // Address mux only — not forty rdata <= mem[f()] in one process (UG901).
    assign name_hash_raddr =
        ((casestate_q == S_JOIN_FIND) || (state == S_JOIN_FIND)) ? jn_i[9:0] :
        ((casestate_q == S_JSON) || (state == S_JSON)) && (js_sp != 6'd0) &&
            (js_tag[js_sp - 6'd1] == 3'd3) ? js_val[js_sp - 6'd1][9:0] :
        ((casestate_q == S_JSON) || (state == S_JSON)) && (js_sp != 6'd0) ?
            vobj_rdata[73:64] :
        ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
            (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
        // jn_slot_arm, not jn_name_arm: the walk consumes hash/len one
        // beat after jn_name_arm is SET, but the nonblocking flag reads 0
        // during its own set beat — the raddr fell through to the exec
        // fallback row and the registered rdata lagged a row behind. Every
        // string-digit element then failed the len==1/digit test and
        // coerced to 0 ("1100".join gave "0000"). jn_slot_arm is already
        // high on the name-arm beat and varr_rdata holds this element.
        (((casestate_q == S_JOIN) || (state == S_JOIN)) && jn_slot_arm) ?
            varr_rdata[9:0] :
        hs64 ? e64_name_hash_raddr : e32_intern_tos;
    assign varr_len_raddr =
        (casestate_q == S_ARR_DCOPY || state == S_ARR_DCOPY) ? dc_src :
        (casestate_q == S_JOIN || state == S_JOIN ||
         casestate_q == S_IDXOF || state == S_IDXOF) ? jn_arr :
        (casestate_q == S_GC_ARR || state == S_GC_ARR) ? gc_cur[11:0] :
        (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
            vgc_cur[11:0] :
        (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
            hp_aid :
        (casestate_q == S_V64_FE_FILTER || state == S_V64_FE_FILTER) ?
            vfe_map[11:0] :
        (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
            ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
        ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
         valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr;
    assign vobj_alloc_raddr =
        vgc_mark_pend ? vgc_mark_word[12:0] :
        (casestate_q == S_V64_GC_SWEEP_OBJ ||
         state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
        ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
          casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
         valloc_rd_arm && hp_cmd == HP_ASSIGN &&
         hp_phase == 3'd3) ?
            `VST_AT(hp_vbase + {9'd0, hp_qi} + 12'd1)[12:0] :
        ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
          casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
         hp_proto_arm) ? hp_proto[12:0] :
        (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
         casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ? hp_oid :
        (casestate_q == S_FREE_OBJ || state == S_FREE_OBJ) ?
            valloc_i[12:0] :
        (casestate_q == S_V64_OGETI_NAT || state == S_V64_OGETI_NAT) ?
            vmetrics[12:0] :
        ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
         valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr;
    assign vvars_raddr =
        (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
            vgc_root_i[8:0] :
        (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
         casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
         casestate_q == S_RD && ret_state == S_V64_CTOR_VARS ||
         casestate_q == S_V64_CTOR_VARS ||
         state == S_V64_CTOR_VARS) ? hp_key[8:0] : e64_vvars_raddr;

    // True dual-port 1W2R (UG901): Port A write+TOS, Port B NOS.
    always_ff @(posedge clk) begin
        if (stack_ram_we) stack[stack_ram_waddr] <= stack_ram_wdata;
        e32_stack_rdata <= (stack_ram_we && stack_ram_waddr == stack_rd_a)
            ? stack_ram_wdata : stack[stack_rd_a];
    end
    always_ff @(posedge clk) begin
        e32_stack_rdata2 <= (stack_ram_we && stack_ram_waddr == e32_stack_raddr2)
            ? stack_ram_wdata : stack[e32_stack_raddr2];
    end
    always_ff @(posedge clk) begin
        if (stack_tag_ram_we) stack_tag[stack_tag_ram_waddr] <= stack_tag_ram_wdata;
        e32_stack_tag_rdata <= stack_tag[stack_rd_a];
    end
    always_ff @(posedge clk) begin
        if (name_hash_ram_we) name_hash_tbl[name_hash_ram_waddr] <= name_hash_ram_wdata;
        name_hash_rdata <= name_hash_tbl[name_hash_raddr];
        e32_name_hash_tos <= name_hash_tbl[name_hash_raddr];
    end
    always_ff @(posedge clk) begin
        e32_name_hash_nos <= name_hash_tbl[e32_intern_nos];
    end
    always_ff @(posedge clk) begin
        if (varr_len_ram_we) varr_len[varr_len_ram_waddr] <= varr_len_ram_wdata;
        varr_len_rdata <= varr_len[varr_len_raddr];
    end
    always_ff @(posedge clk) begin
        if (vobj_alloc_we) vobj_alloc[vobj_alloc_waddr] <= vobj_alloc_wdata;
        vobj_alloc_rdata <= vobj_alloc[vobj_alloc_raddr[9:0]];
    end
    always_ff @(posedge clk) begin
        if (vvars_ram_we) vvars[vvars_ram_waddr] <= vvars_ram_wdata;
        vvars_rdata <= vvars[vvars_raddr];
    end

    // Remaining small/metadata rdata. Heap tables above now match imgd Port A.
    always_ff @(posedge clk) begin
            vraf_rdata <= vraf[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[2:0] : bind_k[2:0]];
            sin_q_rdata <= sin_q[sin_raddr];
            txt_buf_rdata <= txt_buf[txt_i[5:0]];
            pow31_rdata <= pow31_tbl[e32_name_len_tos[7:0]];
            name_blen_rdata <= name_blen[e64_name_blen_raddr];
            // name_hash_tbl: own Port A/B processes (not this mux).
            name_off_rdata <= name_off[hs64 ? e64_name_off_raddr : e32_intern_tos];
            if (vconsts_pa_we) vconsts[vconsts_pa_waddr] <= vconsts_pa_wdata;
        vconsts_rdata <= vconsts[e64_vconsts_raddr];
            // vvars: own Port A process (not this mux).
            vvar_valid_rdata <= vvar_valid[(casestate_q == S_V64_GC_ROOT ||
                state == S_V64_GC_ROOT) ? vgc_root_i[8:0] :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_RD && ret_state == S_V64_CTOR_VARS ||
                 casestate_q == S_V64_CTOR_VARS ||
                 state == S_V64_CTOR_VARS) ? hp_key[8:0] : e64_vvars_raddr];
            // 1W1R parent env chain (HEAP_CMP must not combo venv_parent[hp_eid]).
            // Current-env metadata follows parent venv[], not exec venv_raddr_q:
            // ALLOC freezes exec raddr (often 0). LOAD_VAR then saw
            // venv_valid_rdata=0 and faulted 4 (keep gen; extra clocks OK).
            if (venv_parent_pa_we) venv_parent[venv_parent_pa_waddr] <= venv_parent_pa_wdata;
            venv_parent_rdata <= venv_parent[
                (casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : hp_eid];
            venv_valid_rdata <= venv_valid[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? venv_parent_rdata[9:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0])];
            venv_len_ridx =
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_WR || state == S_HEAP_WR) ?
                    (hp_proto_arm ? venv_parent_rdata[9:0] : hp_eid) :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0]);
            // same-beat write-forward: restores the old direct-write timing
            venv_len_rdata <= (vel_we && vel_wa == venv_len_ridx[8:0])
                ? vel_wd : venv_len[venv_len_ridx[8:0]];
            venv_gen_rdata <= venv_gen[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? venv_parent_rdata[9:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0])];
            // Length addr this clock; unique case uses varr_len_rdata next.
            // varr_len: own Port A process (not this mux).
            varr_valid_rdata <= varr_valid[
                vgc_mark_pend ? vgc_mark_word[11:0] :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_gen_rdata <= varr_gen[
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_long_rdata <= varr_long[
                (casestate_q == S_ARR_DCOPY || state == S_ARR_DCOPY) ?
                    ((hp_phase == 3'd0) ? dc_src : dc_dst) :
                (casestate_q == S_JOIN || state == S_JOIN ||
                 casestate_q == S_IDXOF || state == S_IDXOF) ? jn_arr :
                (casestate_q == S_GC_ARR || state == S_GC_ARR) ? gc_cur[11:0] :
                (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
                    vgc_cur[11:0] :
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_arr_rdata[11:0] :
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) ?
                    e64_vfe_arr_q[11:0] :
                (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
                    hp_aid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON ||
                 casestate_q == S_JSON || state == S_JSON) ?
                    ((js_sp != 6'd0) ? (v64_on ?
                        vjs_val[js_sp - 6'd1][11:0] :
                        js_val[js_sp - 6'd1][11:0]) : 12'd0) :
                (casestate_q == S_V64_JSON_PARSE || state == S_V64_JSON_PARSE) ?
                    ((js_sp >= 6'd2 && jn_slot_arm) ?
                        vjs_val[js_sp - 6'd2][11:0] :
                     (js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_AWR || state == S_HEAP_AWR ||
                 casestate_q == S_HEAP_FILL || state == S_HEAP_FILL) ?
                    hp_aid :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_lidx_rdata <= varr_lidx[
                (casestate_q == S_ARR_DCOPY || state == S_ARR_DCOPY) ?
                    ((hp_phase == 3'd0) ? dc_src : dc_dst) :
                (casestate_q == S_JOIN || state == S_JOIN ||
                 casestate_q == S_IDXOF || state == S_IDXOF) ? jn_arr :
                (casestate_q == S_GC_ARR || state == S_GC_ARR) ? gc_cur[11:0] :
                (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
                    vgc_cur[11:0] :
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_arr_rdata[11:0] :
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) ?
                    e64_vfe_arr_q[11:0] :
                (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
                    hp_aid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON ||
                 casestate_q == S_JSON || state == S_JSON) ?
                    ((js_sp != 6'd0) ? (v64_on ?
                        vjs_val[js_sp - 6'd1][11:0] :
                        js_val[js_sp - 6'd1][11:0]) : 12'd0) :
                (casestate_q == S_V64_JSON_PARSE || state == S_V64_JSON_PARSE) ?
                    ((js_sp >= 6'd2 && jn_slot_arm) ?
                        vjs_val[js_sp - 6'd2][11:0] :
                     (js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_AWR || state == S_HEAP_AWR ||
                 casestate_q == S_HEAP_FILL || state == S_HEAP_FILL) ?
                    hp_aid :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            // vobj_alloc: own Port A process (not this mux).
            vobj_gen_rdata <= vobj_gen[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 valloc_rd_arm && hp_cmd == HP_ASSIGN &&
                 hp_phase == 3'd3) ?
                    `VST_AT(hp_vbase + {9'd0, hp_qi} + 12'd1)[12:0] :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? hp_proto[12:0] :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_WR || state == S_HEAP_WR) ? hp_oid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    valloc_i[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV ||
                 casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS ||
                 ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                  valloc_kind == 2'd0)) ? valloc_i[12:0] : e64_vobj_raddr];
            vobj_mark_rdata <= vobj_mark[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i : 13'd0];
            vfn_mark_rdata <= vfn_mark[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i : 13'd0];
            varr_mark_rdata <= varr_mark[
                vgc_mark_pend ? vgc_mark_word[11:0] :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i : 12'd0];
            venv_mark_rdata <= venv_mark[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i : 10'd0];
            if (vobj_proto_pa_we) vobj_proto[vobj_proto_pa_waddr] <= vobj_proto_pa_wdata;
            vobj_proto_rdata <= vobj_proto[
                (casestate_q == S_V64_GC_OBJ || state == S_V64_GC_OBJ) ?
                    vgc_cur[12:0] : e64_vobj_raddr];
            vobj_cls_rdata <= vobj_cls[
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ? hp_oid :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr];
            vobj_len_ridx =
                (casestate_q == S_V64_GC_OBJ || state == S_V64_GC_OBJ) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_DISPATCH || state == S_V64_DISPATCH) ?
                    hp_oid :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ?
                    ((hp_cmd == HP_ASSIGN && hp_phase == 3'd0) ? hp_si : hp_oid) :
                // potential-bugs #64: KEYEVT's OSETI enters S_HEAP_WR
                // DIRECTLY (never through HEAP_WAIT/CMP), so the qi-loop's
                // final `vobj_len_rdata < qn+slot` gate read a STALE address
                // (exec's frozen vobj_raddr). A stale len >= 3 skipped the
                // len write: the key-event object kept n=0, e.key/e.keyCode
                // read undefined, and DONKEY's Enter gate never matched.
                (casestate_q == S_HEAP_WR || state == S_HEAP_WR) ? hp_oid :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr;
            // same-beat write-forward (see venv_len above)
            vobj_len_rdata <= (vol_we && vol_wa[9:0] == vobj_len_ridx[9:0])
                ? vol_wd : vobj_len[vobj_len_ridx[9:0]];
            vobj_builtin_rdata <= vobj_builtin[
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_OGETI_NAT || state == S_V64_OGETI_NAT) ?
                    hp_oid : e64_vobj_raddr];
            vfn_valid_rdata <= vfn_valid[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2) ? valloc_i[12:0] : e64_vfn_raddr];
            vfn_gen_rdata <= vfn_gen[
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                (casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2) ? valloc_i[12:0] : e64_vfn_raddr];
            if (vfn_proto_pa_we) vfn_proto[vfn_proto_pa_waddr] <= vfn_proto_pa_wdata;
            vfn_proto_rdata <= vfn_proto[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] : e64_vfn_raddr];
            if (vfn_env_pa_we) vfn_env[vfn_env_pa_waddr] <= vfn_env_pa_wdata;
            vfn_env_rdata <= vfn_env[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_nparam_rdata <= vfn_nparam[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_entry_rdata <= vfn_entry[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_flags_rdata <= vfn_flags[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            if (vfn_bound_this_pa_we) vfn_bound_this[vfn_bound_this_pa_waddr] <= vfn_bound_this_pa_wdata;
            vfn_bound_this_rdata <= vfn_bound_this[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vframe_rip_rdata <= vframe_return_ip[
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) &&
                (e64_vcsp_q != 8'd0) ? (e64_vcsp_q - 8'd1) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_bsp_rdata <= vframe_base_sp[
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) &&
                (e64_vcsp_q != 8'd0) ? (e64_vcsp_q - 8'd1) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_esc_rdata <= vframe_escaped[e64_vframe_raddr];
            vframe_this_rdata <= vframe_this[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_env_rdata <= vframe_env[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_fn_rdata <= vframe_fn[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_ctor_rdata <= vframe_ctor[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            fill_lut_rdata <= fill_lut[hs64 ? e64_fill_lut_raddr : e32_intern_tos];
            vtimer_valid_rdata <= vtimer_valid[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_id_rdata <= vtimer_id[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_due_rdata <= vtimer_due[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                e64_vtimer_raddr];
            vtimer_fn_rdata <= vtimer_fn[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_period_rdata <= vtimer_period[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                e64_vtimer_raddr];
            vlistener_ev_rdata <= vlistener_ev[
                lsv_serving ? lsv_k[3:0] :
                (casestate_q == S_V64_FRAME_KEY || state == S_V64_FRAME_KEY) ?
                    ((bind_k < 8'd16) ? bind_k[3:0] : vk_pick[3:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[4:1] : 4'd0];
            vlistener_fn_rdata <= vlistener_fn[
                lsv_serving ? lsv_k[3:0] :
                (casestate_q == S_V64_FRAME_KEY || state == S_V64_FRAME_KEY) ?
                    ((bind_k < 8'd16) ? bind_k[3:0] : vk_pick[3:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[4:1] : 4'd0];
            vlong_used_rdata <= vlong_used[
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR ||
                 casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE ||
                 ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                  valloc_kind == 2'd1)) ? valloc_i[6:0] : 7'd0];
            gc_obj_mark_rdata <= gc_obj_mark[
                vgc_mark_pend ? vgc_mark_word[12:0] : gc_i];
            gc_arr_mark_rdata <= gc_arr_mark[
                vgc_mark_pend ? vgc_mark_word[11:0] : gc_i[11:0]];
            // NEW: registered glyph fetch — one row of one character per cycle
            font_rdata <= font_rom[font_raddr];
            // exec32: scalar rdata from parent 1-D arrays (no unpacked ports).
            e32_obj_cls_rdata <= obj_cls[
                (casestate_q == S_GC_OBJ || state == S_GC_OBJ) ?
                    gc_cur[9:0] :
                (casestate_q == S_TXT_LD || state == S_TXT_LD) ?
                    txt_val[9:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][9:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[9:0] :
                     to_fn0[9:0]) :
                e32_obj_cls_raddr];
            e32_obj_n_rdata <= obj_n[
                (casestate_q == S_JSON || state == S_JSON) ?
                    ((js_sp != 6'd0) ? js_val[js_sp - 6'd1][9:0] : 10'd0) :
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[9:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[9:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[9:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][9:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[9:0] :
                     to_fn0[9:0]) :
                (casestate_q == S_ENV_LOAD || state == S_ENV_LOAD) ?
                    env_walk[9:0] :
                (casestate_q == S_GC_OBJ || state == S_GC_OBJ) ?
                    gc_cur[9:0] :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_cmd == HP_ASSIGN) ? hp_si[9:0] : e32_obj_n_raddr];
            e32_tfn_entry_rdata <= tfn_entry[
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[12:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[12:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][12:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[12:0] :
                     to_fn0[12:0]) :
                e32_tfn_raddr];
            e32_tfn_has_this_rdata <= tfn_has_this[
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[12:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[12:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][12:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[12:0] :
                     to_fn0[12:0]) :
                e32_tfn_raddr];
            e32_tfn_nparam_rdata <= tfn_nparam[e32_tfn_raddr];
            e32_tfn_parent_rdata <= tfn_parent[
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[12:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[12:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][12:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[12:0] :
                     to_fn0[12:0]) :
                (casestate_q == S_GC_OBJ || state == S_GC_OBJ) ?
                    gc_cur[12:0] :
                e32_tfn_raddr];
            e32_tenv_parent_rdata <= tenv_parent[
                (casestate_q == S_GC_OBJ || state == S_GC_OBJ) ?
                    gc_cur[12:0] : env_walk[12:0]];
            e32_tfn_this_rdata <= tfn_this[
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[12:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[12:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][12:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[12:0] :
                     to_fn0[12:0]) :
                e32_tfn_raddr];
            e32_tfn_this_tag_rdata <= tfn_this_tag[
                (casestate_q == S_FOREACH || state == S_FOREACH) ?
                    e32_cs1_fe_fn_rdata[12:0] :
                (casestate_q == S_KEYEV || state == S_KEYEV) ?
                    kev_fn[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH) ?
                    hp_rval[12:0] :
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    ((raf_n != 4'd0) ? raf_fn[0][12:0] :
                     (to_fire_fn != 16'd0) ? to_fire_fn[12:0] :
                     to_fn0[12:0]) :
                e32_tfn_raddr];
            // stack / name_hash_tbl: own Port A/B processes (not this mux).
            e32_name_has_tos <= name_has[
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] : e32_intern_tos];
            e32_name_has_nos <= name_has[e32_intern_nos];
            e32_name_len_tos <= name_len_tbl[
                ((casestate_q == S_JOIN_FIND) || (state == S_JOIN_FIND)) ? jn_i[9:0] :
                ((casestate_q == S_JSON) || (state == S_JSON)) && (js_sp != 6'd0) &&
                    (js_tag[js_sp - 6'd1] == 3'd3) ? js_val[js_sp - 6'd1][9:0] :
                ((casestate_q == S_JSON) || (state == S_JSON)) && (js_sp != 6'd0) ?
                    vobj_rdata[73:64] :
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] :
                // same jn_slot_arm timing as name_hash_raddr above
                (((casestate_q == S_JOIN) || (state == S_JOIN)) && jn_slot_arm) ?
                    varr_rdata[9:0] :
                e32_intern_tos];
            e32_name_len_nos <= name_len_tbl_r1[e32_intern_nos];
            e32_name_off_tos <= name_off_r1[
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] :
                hs64 ? e64_name_off_raddr : e32_intern_tos];
            e32_name_off_nos <= name_off_r2[e32_intern_nos];
            e32_arr_len_tos_rdata <= arr_len[
                ((state == S_FOREACH) || (casestate_q == S_FOREACH))
                    ? e32_cs1_fe_arr_rdata[11:0] :
                ((state == S_ARR_DCOPY) || (casestate_q == S_ARR_DCOPY))
                    ? dc_src :
                ((state == S_JOIN) || (casestate_q == S_JOIN) ||
                 (state == S_IDXOF) || (casestate_q == S_IDXOF))
                    ? jn_arr :
                ((state == S_JSON) || (casestate_q == S_JSON))
                    ? ((js_sp != 6'd0) ? js_val[js_sp - 6'd1][11:0] : 12'd0) :
                ((state == S_GC_ARR) || (casestate_q == S_GC_ARR))
                    ? gc_cur[11:0] : e32_aid_tos];
            e32_arr_len_nos_rdata <= arr_len[e32_aid_nos];
            e32_vars_rdata <= vars[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i < 13'd512) ? gc_root_i[8:0] :
                (casestate_q == S_ENV_LOAD || state == S_ENV_LOAD) ?
                    env_ld_slot : e32_vars_raddr];
            e32_intern_var_rdata <= intern_var[
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? vcall_entry[9:0] :
                hs64 ? code_rdata[17:8] : e32_intern_var_raddr];
            e32_intern_var_ok_rdata <= intern_var_ok[
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? vcall_entry[9:0] :
                hs64 ? code_rdata[17:8] : e32_intern_var_raddr];
            e32_env_oid_rdata <= env_oid[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2640 && gc_root_i < 13'd2672) ?
                    (gc_root_i - 13'd2640) :
                (casestate_q == S_REL_ENV || state == S_REL_ENV) ?
                    rel_i : e32_env_oid_raddr];
            // STRIDX_WR samples char_id_rdata. casestate_q is STRIDX_WR
            // that beat — without it the mux dropped name_rdata and WR
            // planted undefined, so row[col]==="1" never fired.
            e32_char_id_rdata <= char_id[
                ((state == S_STRIDX) || (state == S_V64_STRIDX) ||
                 (state == S_STRIDX_WR) || (state == S_V64_STRIDX_WR) ||
                 (casestate_q == S_STRIDX) || (casestate_q == S_V64_STRIDX) ||
                 (casestate_q == S_STRIDX_WR) ||
                 (casestate_q == S_V64_STRIDX_WR))
                ? name_rdata : e32_char_id_raddr];
            e32_char_ok_rdata <= char_ok[
                ((state == S_STRIDX) || (state == S_V64_STRIDX) ||
                 (state == S_STRIDX_WR) || (state == S_V64_STRIDX_WR) ||
                 (casestate_q == S_STRIDX) || (casestate_q == S_V64_STRIDX) ||
                 (casestate_q == S_STRIDX_WR) ||
                 (casestate_q == S_V64_STRIDX_WR))
                ? name_rdata :
                ((state == S_STR_WR) || (casestate_q == S_STR_WR))
                ? txt_buf_rdata : e32_char_id_raddr];
            e32_to_delay_rdata <= to_delay[
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    (vt_found ? (bind_k[5:0] + 6'd1) : bind_k[5:0]) :
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2568 && gc_root_i < 13'd2632) ?
                    (gc_root_i - 13'd2568) : e32_to_raddr];
            e32_to_fn_rdata <= to_fn[
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    (vt_found ? (bind_k[5:0] + 6'd1) : bind_k[5:0]) :
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2568 && gc_root_i < 13'd2632) ?
                    (gc_root_i - 13'd2568) : e32_to_raddr];
            e32_to_id_rdata <= to_id[
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    (vt_found ? (bind_k[5:0] + 6'd1) : bind_k[5:0]) :
                e32_to_raddr];
            e32_to_period_rdata <= to_period[
                (casestate_q == S_WAIT_FRAME || state == S_WAIT_FRAME) ?
                    (vt_found ? (bind_k[5:0] + 6'd1) : bind_k[5:0]) :
                e32_to_raddr];
            e32_fn_proto_ip_rdata <= fn_proto_ip[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2681 && gc_root_i < 13'd2745) ?
                    (gc_root_i - 13'd2681) : e32_fn_proto_raddr];
            e32_fn_proto_oid_rdata <= fn_proto_oid[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2681 && gc_root_i < 13'd2745) ?
                    (gc_root_i - 13'd2681) : e32_fn_proto_raddr];
            // flatten: one SRAM index (GC_ROOT / pop refill). Else window FFs.
            if (cstack_sram_rd) begin
                e32_cs1_ip_rdata <= cstack_ip[cstack_raddr];
                e32_cs1_this_rdata <= cstack_this[cstack_raddr];
                e32_cs1_isctor_rdata <= cstack_isctor[cstack_raddr];
                e32_cs1_isfe_rdata <= cstack_isfe[cstack_raddr];
                e32_cs1_ctorobj_rdata <= cstack_ctorobj[cstack_raddr];
                e32_cs1_fe_arr_rdata <= cstack_fe_arr[cstack_raddr];
                e32_cs1_fe_fn_rdata <= cstack_fe_fn[cstack_raddr];
                e32_cs1_fe_i_rdata <= cstack_fe_i[cstack_raddr];
                e32_cs1_map_arr_rdata <= cstack_map_arr[cstack_raddr];
                e32_cs1_env_rdata <= cstack_env[cstack_raddr];
            end else begin
                e32_cs1_ip_rdata <= cs_win1_ip;
                e32_cs1_this_rdata <= cs_win1_this;
                e32_cs1_isctor_rdata <= cs_win1_isctor;
                e32_cs1_isfe_rdata <= cs_win1_isfe;
                e32_cs1_ctorobj_rdata <= cs_win1_ctorobj;
                e32_cs1_fe_arr_rdata <= cs_win1_fe_arr;
                e32_cs1_fe_fn_rdata <= cs_win1_fe_fn;
                e32_cs1_fe_i_rdata <= cs_win1_fe_i;
                e32_cs1_map_arr_rdata <= cs_win1_map_arr;
                e32_cs1_env_rdata <= cs_win1_env;
            end
            e32_cs2_ip_rdata <= cs_win2_ip;
            e32_cs2_this_rdata <= cs_win2_this;
            e32_cs2_isctor_rdata <= cs_win2_isctor;
            e32_cs2_isfe_rdata <= cs_win2_isfe;
            e32_cs2_ctorobj_rdata <= cs_win2_ctorobj;
            e32_cs2_fe_arr_rdata <= cs_win2_fe_arr;
            e32_cs2_fe_fn_rdata <= cs_win2_fe_fn;
            e32_cs2_fe_i_rdata <= cs_win2_fe_i;
            e32_cs2_map_arr_rdata <= cs_win2_map_arr;
            e32_cs2_env_rdata <= cs_win2_env;
            e32_consts_rdata <= consts[e32_consts_raddr];
            e32_var_init_rdata <= var_init[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i < 13'd512) ? gc_root_i[8:0] :
                (casestate_q == S_ENV_LOAD || state == S_ENV_LOAD) ?
                    env_ld_slot : e32_vars_raddr];
            e32_var_tag_rdata <= var_tag[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i < 13'd512) ? gc_root_i[8:0] :
                (casestate_q == S_ENV_LOAD || state == S_ENV_LOAD) ?
                    env_ld_slot : e32_vars_raddr];
            e32_env_free_rdata <= env_free[
                (casestate_q == S_REL_ENV || state == S_REL_ENV) ?
                    {1'b0, bind_k} :
                (env_free_n != 6'd0) ? {3'd0, env_free_n - 6'd1} : 9'd0];
            e32_env_cap_rdata <= env_cap[env_cap_raddr];
            gc_queue_rdata <= gc_queue[gc_qr];
            if (vgc_queue_pa_we) vgc_queue[vgc_queue_pa_waddr] <= vgc_queue_pa_wdata;
        vgc_queue_rdata <= vgc_queue[vgc_qr];
            e32_raf_fn_rdata <= raf_fn[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2560 && gc_root_i < 13'd2568) ?
                    (gc_root_i - 13'd2560) : 3'd0];
            e32_raf_tap1 <= raf_fn[1];
            e32_raf_tap2 <= raf_fn[2];
            e32_raf_tap3 <= raf_fn[3];
            e32_raf_tap4 <= raf_fn[4];
            e32_raf_tap5 <= raf_fn[5];
            e32_raf_tap6 <= raf_fn[6];
            e32_raf_tap7 <= raf_fn[7];
            e32_kd_slot_rdata <= kd_slot[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2632 && gc_root_i < 13'd2636) ?
                    2'(gc_root_i - 13'd2632) : 2'd0];
            e32_ku_slot_rdata <= ku_slot[
                (casestate_q == S_GC_ROOT || state == S_GC_ROOT) &&
                (gc_root_i >= 13'd2636 && gc_root_i < 13'd2640) ?
                    2'(gc_root_i - 13'd2636) : 2'd0];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hs_st(S_IDLE);
            running <= 1'b0;
            looping <= 1'b0;
            fb_we <= 1'b0; fb_swap <= 1'b0;
            rast_go <= 1'b0; rast_wait <= 1'b0;
            did_swap <= 1'b0; present_pend <= 1'b0; fb_dirty <= 1'b0;
            fbs_armed <= 1'b0;
            env_len_arm <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0;
            fb_dump_addr <= '0; fb_dump_sel <= 1'b0;
            sp <= '0; hs_ip('0);
            hs_vsp('0); hs_vcsp('0); vconst_lo <= '0;
            rect_ld_arm <= 1'b0;
            rect_ld_k <= 2'd0;
            vsp_d <= '0;
            vst_we <= 1'b0;
            imgd_pend <= 1'b0;
            sprb_pend <= 1'b0;
            name_we <= 1'b0;
            json_we <= 1'b0;
            stack_we <= 1'b0;
            stack_tag_we <= 1'b0;
            name_hash_we <= 1'b0;
            varr_len_we <= 1'b0;
            vobj_alloc_we <= 1'b0;
            vvars_we <= 1'b0;
            stack_dual_pend <= 1'b0;
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
            intern_ctor_hold <= 1'b0;
            intern_ctor_entry <= 16'd0;
            intern_ctor_nparam <= 6'd0;
            intern_ctor_flags <= 3'd0;
            intern_ctor_env <= V64_UNDEFINED;
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
            hs_vgc_qr('0); hs_vgc_qw('0); hs_vgc_clear_i('0);
            vgc_obj_i <= '0; vgc_arr_i <= '0; vgc_slot_i <= '0;
            vgc_cur <= '0; vgc_root_i <= '0; hs_valloc_i('0);
            vobj_next <= '0; varr_next <= '0; vfn_next <= '0;
            venv_next <= '0; hs_valloc_kind(2'd0);
            hs_valloc_retried(1'b0);
            hs_vgc_halt_after(1'b0);
            gc_ran_this_frame <= 1'b0;
            vgc_env_i <= '0; vgc_root_phase <= '0;
            cls_scan <= 1'b0; cls_armed <= 1'b0; cls_done <= 1'b0;
            cls_hit <= 1'b0;
            cls_ctor_mode <= 1'b0; cls_c <= 4'd0; cls_m <= 4'd0;
            cls_seq <= 1'b0; cls_prime <= 1'b0;
            cm_serving <= 1'b0; cm_served_hold <= 1'b0; cm_res_we <= 1'b0;
            lsv_serving <= 1'b0; lsv_served_hold <= 1'b0; lsv_res_we <= 1'b0;
            lsv_arm <= 1'b0; lsv_k <= 5'd0; lsv_w <= 5'd0; lsv_same <= 5'd0; lsv_dup <= 1'b0; lsv_res <= 3'd0;
            cls_cls <= 16'd0; cls_key <= 16'd0;
            cls_ctor_q <= 16'hFFFF; cls_mip_q <= 16'hFFFF; cls_gip_q <= 16'hFFFF;
            hs_vcall_value(1'b0); hs_vcall_entry('0); hs_vcall_argc('0);
            hs_vcall_set_this(1'b0);
            hs_vcall_this(V64_UNDEFINED);
            hs_vcall_ctor_val(V64_UNDEFINED);
            imgd_v64 <= 1'b0;
            hs_vthis(V64_UNDEFINED); hs_venv(V64_UNDEFINED);
            hs_vraf_n('0); vraf_snap_n <= '0; vraf_i <= '0;
            vtimer_n <= '0; vframe_no <= '0; vtimer_seq <= 32'd1;
            vrng <= 32'h6d2b79f5; vconsole_n <= '0;
            vtimer_pick <= '0; vcallback_raf <= 1'b0;
            vcallback_timer <= 1'b0; hs_vgc_wait_after(1'b0);
            vgc_resume <= 2'd0;
            hs_vnat_base('0); hs_vdraw_i('0);
            vdraw_cx <= '0; vdraw_cy <= '0;
            hs_vnat_dom(3'd0); vnat_style <= V64_UNDEFINED;
            vmetrics <= V64_UNDEFINED;
            hs_valloc_metrics(1'b0);
            vmetrics_w <= 16'd0;
            vkev_event <= V64_UNDEFINED; vlistener_n_ff <= 5'd0;
            vkey_custom <= 1'b0; vkey_want_ev <= 64'd0;
            vkey_li <= 5'd0;
            v64_frame_armed <= 1'b0;
            vcallback_key <= 1'b0; vcallback_fe <= 1'b0;
            vfe_arr <= V64_UNDEFINED; vfe_fn <= V64_UNDEFINED;
            vfe_i <= 8'd0; vfe_ret <= 16'd0; vfe_base <= '0; vfe_sp <= 4'd0;
            vfe_mode <= 2'd0;
            vfe_map <= V64_UNDEFINED;
            hs_valloc_now_fn(1'b0);
            hs_valloc_regex(1'b0);
            hs_valloc_regex_pack(32'd0);
            hs_valloc_arr_n(8'd0);
            hs_valloc_fn_entry(16'd0);
            hs_valloc_fn_a1(8'd0);
            hs_valloc_proto(1'b0);
            hs_valloc_proto_fn(13'd0);
            hs_valloc_bind(1'b0);
            hs_valloc_bind_src(13'd0);
            hs_valloc_bind_this(V64_UNDEFINED);
            vctor_scan <= '0;
            vctor_armed <= 1'b0;
            vctor_jmp <= 16'hFFFF;
            vctor_lets <= 6'd0;
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            hs_m_ip <= 1'b0; hs_m_code <= 1'b0; hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
            hs_m_hp_cmd <= 1'b0; hs_m_hp_v64 <= 1'b0; hs_m_hp_oid <= 1'b0;
            hs_m_hp_aid <= 1'b0; hs_m_hp_env <= 1'b0; hs_m_hp_eid <= 1'b0;
            hs_m_hp_slot <= 1'b0; hs_m_hp_aslot <= 1'b0; hs_m_hp_len <= 1'b0;
            hs_m_hp_alen <= 1'b0; hs_m_hp_lim <= 1'b0; hs_m_hp_key <= 1'b0;
            hs_m_hp_wval <= 1'b0; hs_m_hp_rval <= 1'b0; hs_m_hp_hit <= 1'b0;
            hs_m_hp_ret <= 1'b0; hs_m_hp_phase <= 1'b0; hs_m_hp_proto <= 1'b0;
            hs_m_hp_qn <= 1'b0; hs_m_hp_qi <= 1'b0; hs_m_hp_si <= 1'b0;
            hs_m_hp_ss <= 1'b0; hs_m_hp_tn <= 1'b0; hs_m_hp_from_stack <= 1'b0;
            hs_m_hp_make_arr <= 1'b0; hs_m_hp_vbase <= 1'b0;
            hs_m_hp_spr_w <= 1'b0; hs_m_hp_spr_h <= 1'b0; hs_m_hp_nat <= 1'b0;
            hs_m_hp_tag <= 1'b0; hs_m_hp_qk <= 1'b0; hs_m_hp_qv <= 1'b0; hs_m_hp_qt <= 1'b0;
            hs_m_valloc_kind <= 1'b0; hs_m_valloc_i <= 1'b0; hs_m_valloc_arr_n <= 1'b0; hs_m_valloc_retried <= 1'b0; hs_m_vnat_dom <= 1'b0; hs_m_vnat_base <= 1'b0; hs_m_valloc_now_fn <= 1'b0; hs_m_valloc_bind <= 1'b0; hs_m_valloc_bind_src <= 1'b0; hs_m_valloc_bind_this <= 1'b0; hs_m_valloc_fn_entry <= 1'b0; hs_m_valloc_fn_a1 <= 1'b0; hs_m_valloc_proto <= 1'b0; hs_m_valloc_proto_fn <= 1'b0; hs_m_valloc_metrics <= 1'b0; hs_m_valloc_regex <= 1'b0; hs_m_valloc_regex_pack <= 1'b0; hs_m_vcall_value <= 1'b0; hs_m_vcall_argc <= 1'b0; hs_m_vcall_entry <= 1'b0; hs_m_vcall_set_this <= 1'b0; hs_m_vcall_this <= 1'b0; hs_m_vcall_ctor_val <= 1'b0; hs_m_vcsp <= 1'b0; hs_m_vthis <= 1'b0; hs_m_venv <= 1'b0; hs_m_vraf_n <= 1'b0; hs_m_vlistener_n <= 1'b0; hs_m_vgc_halt_after <= 1'b0; hs_m_vgc_wait_after <= 1'b0; hs_m_vgc_clear_i <= 1'b0; hs_m_vgc_qr <= 1'b0; hs_m_vgc_qw <= 1'b0; hs_m_vdraw_i <= 1'b0; hs_m_vdraw_x <= 1'b0; hs_m_vdraw_y <= 1'b0; hs_m_vdraw_w <= 1'b0; hs_m_vdraw_h <= 1'b0; hs_m_vdraw_color <= 1'b0; hs_m_vfe_i <= 1'b0; hs_m_vfe_pop <= 1'b0;
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;
            e32_p_clr <= 1'b0;
            e32_p_we <= 1'b0;
            hs_hp_env(1'b0); hs_hp_eid('0);
            hs_hp_slot('0); hs_hp_aslot('0); hs_hp_len('0); hs_hp_alen('0);
            hs_hp_lim('0); hs_hp_key('0); hs_hp_wval('0); hs_hp_rval('0);
            hs_hp_hit(1'b0); hs_hp_phase('0); hs_hp_qn('0); hs_hp_qi('0);
            hs_hp_tag(3'd0); vgc_rd_arm <= 1'b0; jn_rd_arm <= 1'b0;
            jn_hit_v <= 4'd0; jn_cache_try <= 1'b0; jn_cache_i <= 3'd0;
            jn_name_arm <= 1'b0; vjs_name_arm <= 1'b0; tfn_rd_arm <= 1'b0;
            jn_slot_arm <= 1'b0; hp_slot_arm <= 1'b0; hp_slot_pend <= 1'b0;
            vfe_rd_arm <= 1'b0; vjs_rd_arm <= 1'b0; valloc_rd_arm <= 1'b0;
            stridx_rd_arm <= 1'b0;
            hp_proto_arm <= 1'b0;
            json_ch0 <= 8'd0;
            vt_found <= 1'b0; vk_found <= 1'b0;
            vt_pick <= 7'd0; vk_pick <= 5'd0;
            vt_best_due <= 32'sh7fffffff; vt_best_id <= 32'sh7fffffff;
            to_fire_fn <= 16'd0; to_fire_id <= 16'd0;
            vgc_mark_pend <= 1'b0; vgc_mark_arm <= 1'b0;
            vgc_mark_word <= 64'd0;
            hs_hp_from_stack(1'b0); hs_hp_make_arr(1'b0); hs_hp_vbase('0);
            hs_hp_spr_w('0); hs_hp_spr_h('0); hs_hp_nat(4'd0);
            n_ops <= '0; n_consts <= '0; ops_base <= '0;
            hs_code('0);
            nat_id <= '0; nat_argc <= '0;
            c_i <= '0;
            gc_qr <= '0; gc_qw <= '0; gc_i <= '0; gc_root_i <= '0;
            gc_slot <= '0; gc_cur <= '0;
            gc_obj_high <= '0; gc_arr_high <= '0; dbg_gc_n <= '0;
            dbg_stack_ovf <= '0; dbg_call_ovf <= '0;
            machine_fault <= 1'b0; fault_code <= 8'd0;
            prev_joy <= 6'd0; joy_down_edge <= 6'd0; joy_up_edge <= 6'd0;
            sram_req <= 1'b0; sram_addr <= '0; blit_wait <= 1'b0;
            sram_we <= 1'b0; sram_wdata <= '0;
            sin_ph <= 4'd0; sin_turn <= 16'd0;
            aset_mode <= 1'b0; sprd_mode <= 1'b0; hdr_w <= 16'd3;
            boot_clr <= 1'b0;
            heap_clr_busy <= 1'b0;
            heap_clr_i <= 12'd0;
            to_fn0 <= 16'd0;
            cs_win1_ip <= 16'd0; cs_win2_ip <= 16'd0;
            cs_win1_this <= 16'd0; cs_win2_this <= 16'd0;
            cs_win1_isctor <= 1'b0; cs_win2_isctor <= 1'b0;
            cs_win1_isfe <= 1'b0; cs_win2_isfe <= 1'b0;
            cs_win1_ctorobj <= 16'd0; cs_win2_ctorobj <= 16'd0;
            cs_win1_fe_arr <= 16'd0; cs_win2_fe_arr <= 16'd0;
            cs_win1_fe_fn <= 16'd0; cs_win2_fe_fn <= 16'd0;
            cs_win1_fe_i <= 8'd0; cs_win2_fe_i <= 8'd0;
            cs_win1_map_arr <= 16'd0; cs_win2_map_arr <= 16'd0;
            cs_win1_env <= 6'd0; cs_win2_env <= 6'd0;
            cs_pend_ip <= 16'd0; cs_pend_this <= 16'd0; cs_pend_valid <= 1'b0;
            cs_refill <= 2'd0; cs_refill_arm <= 1'b0; cs_refill_win1 <= 1'b0;
            cs_raddr_ff <= 7'd0; csp_e32_d <= 7'd0;
        end else begin
            fb_we <= 1'b0;
            fb_swap <= 1'b0;
            rast_go <= 1'b0;
            vst_we <= 1'b0;
            vfr_we <= 1'b0;
            vom_we_cls <= 1'b0; vom_we_bi <= 1'b0; veg_we <= 1'b0;
            vog_we <= 1'b0; vfg_we <= 1'b0; vag_we <= 1'b0;
            vmko_we <= 1'b0; vmkf_we <= 1'b0; vmka_we <= 1'b0; vmke_we <= 1'b0;
            vfv_we <= 1'b0; vav_we <= 1'b0; vev_we <= 1'b0; vvv_we <= 1'b0; vlo_we <= 1'b0;
            vli_we <= 1'b0; alw_we <= 1'b0;
            nof_we <= 1'b0; nbl_we <= 1'b0; nlt_we <= 1'b0; flu_we <= 1'b0;
            vlu_we <= 1'b0;
            vtd_we <= 1'b0; nh_we <= 1'b0; txw_we <= 1'b0; cse_we <= 1'b0;
            cmn_we <= 1'b0; cmi_we <= 1'b0;
            vol_we <= 1'b0; vel_we <= 1'b0;
            // imgd_pend is HANDSHAKE STATE (held across beats until sram_ack),
            // not a strobe - it must NOT be cleared here. The old imgd_we that
            // lived on this line was a one-shot BRAM write strobe.
            vgc_queue_pa_we <= 1'b0; vconsts_pa_we <= 1'b0;
            vobj_proto_pa_we <= 1'b0; vfn_proto_pa_we <= 1'b0;
            vfn_env_pa_we <= 1'b0; vfn_bound_this_pa_we <= 1'b0;
            venv_parent_pa_we <= 1'b0;
            // spr strobe retired (external SRAM)
            name_we <= 1'b0;
            json_we <= 1'b0;
            stack_we <= 1'b0;
            stack_tag_we <= 1'b0;
            name_hash_we <= 1'b0;
            varr_len_we <= 1'b0;
            vobj_alloc_we <= 1'b0;
            vvars_we <= 1'b0;
            csp_e32_d <= e32_csp_q;
            // TOS window follows last cycle's write + this cycle's vsp
            // (already NBA-updated from the previous op). S_V64_BIND holds
            // the window; skip one cycle after it so vsp_d can catch up.
            // Do not skip vst_we on that release cycle — GET_PROP x then
            // SET_PROP x ({x:current.x}) stored leftover NaN while the
            // object still had x=12 (PACMAN ARRAY_SET 241, change=1 wrap).
            // leave_hold: parent unique case (ALLOC/HEAP) writes vst_wr/hs_vsp
            // while state is still EXEC. Window must follow parent that beat
            // or MAKE_FN+CALL_VAL / HEAP LOAD_VAR TOS is the previous value
            // (DONKEY IIFE fault 4, inner rAF nid 27).
            begin
                logic [11:0] wvsp;
                logic wvst_we;
                logic [11:0] wvst_waddr;
                logic [63:0] wvst_wdata;
                logic use_e64_win;
                logic use_e64_wr;
                // Sticky hs_m_vsp: parent vsp_ff is truth (MAKE_FN ALLOC
                // push). Extra EXEC beat with lagged e64_vsp_q shifted the
                // TOS window (win[0]=UNDEF, Fn in win[1]) — nonempty IIFE
                // CALL_VAL fault 4. Empty IIFE had vsp_d==e64 so no shift.
                use_e64_win = (state == S_V64_EXEC) && !e64_leave_hold
                    && !hs_m_vsp;
                wvsp = use_e64_win ? e64_vsp_q : vsp;
                // The write the window follows MUST be the write the vstack
                // SRAM takes, selected the same way (see the vstack Port A
                // process). Keying it off use_e64_win instead diverged them:
                // exec's *_we_q is registered, so it lands on the leave_hold
                // / FETCH_WAIT beat when use_e64_win is already false — SRAM
                // stored exec's word while the window shifted the parent's
                // stale vst_wdata into win[0]. That is why a pushed callee
                // handle read back untagged (CALL_VAL fault 4 on any call
                // with computed args) and why fillRect saw the previous
                // rect's x/y (INVADERS score-table sprites all on one spot).
                use_e64_wr = e64_vst_we_q && e64_wr_ok &&
                    ((state == S_V64_EXEC) || (state == S_FETCH_WAIT) ||
                     (state == S_V64_WIN_FILL));
                wvst_we = use_e64_wr ? 1'b1 : vst_we;
                wvst_waddr = use_e64_wr ? e64_vst_waddr_q : vst_waddr;
                wvst_wdata = use_e64_wr ? e64_vst_wdata_q : vst_wdata;
            if (use_e64_win ? e64_vst_hold_win_q : vst_hold_win) begin
                if (state != S_V64_BIND && state != S_V64_WIN_FILL) begin
                    if (wvst_we) begin
                        integer d;
                        d = integer'(wvsp) - 1 - integer'(wvst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= wvst_wdata;
                    end
                    vst_hold_win <= 1'b0;
                end
            end else if (wvsp > vsp_d) begin
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
                    vst_win[0] <= wvst_wdata;
                end else if (wvsp < vsp_d) begin
                    begin
                        integer sh, wi;
                        sh = integer'(vsp_d) - integer'(wvsp);
                        if (wvst_we && wvst_waddr == (wvsp - 12'd1))
                            vst_win[0] <= wvst_wdata;
                        else if (sh < 16)
                            vst_win[0] <= vst_win[sh[3:0]];
                        for (wi = 1; wi < 16; wi++)
                            if (wi + sh < 16)
                                vst_win[wi] <= vst_win[wi[3:0] + sh[3:0]];
                    end
                end else if (wvst_we) begin
                    begin
                        integer d;
                        d = integer'(wvsp) - 1 - integer'(wvst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= wvst_wdata;
                    end
                end
            end
            vsp_d <= ((state == S_V64_EXEC) && !e64_leave_hold && !hs_m_vsp)
                ? e64_vsp_q : vsp;
            // Exec-owned copies: default no poke; states below may pulse.
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            // ip/vsp overlay must survive FETCH_WAIT after ALLOC/HEAP poke.
            // Clearing every cycle dropped hs_m before CALL_VAL: vsp mux was
            // e64=0 while vst_win[0] already held the Fn (IIFE fault 4).
            if ((state == S_V64_EXEC) && !e64_leave_hold) begin
                hs_m_ip <= 1'b0; hs_m_code <= 1'b0;
                hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
                hs_m_vcsp <= 1'b0; hs_m_venv <= 1'b0; hs_m_vthis <= 1'b0;
            end else if (!hs64) begin
                hs_m_ip <= 1'b0; hs_m_code <= 1'b0;
                hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
                hs_m_vcsp <= 1'b0; hs_m_venv <= 1'b0; hs_m_vthis <= 1'b0;
            end
            hs_m_hp_cmd <= 1'b0; hs_m_hp_v64 <= 1'b0; hs_m_hp_oid <= 1'b0;
            hs_m_hp_aid <= 1'b0; hs_m_hp_env <= 1'b0; hs_m_hp_eid <= 1'b0;
            hs_m_hp_slot <= 1'b0; hs_m_hp_aslot <= 1'b0; hs_m_hp_len <= 1'b0;
            hs_m_hp_alen <= 1'b0; hs_m_hp_lim <= 1'b0; hs_m_hp_key <= 1'b0;
            hs_m_hp_wval <= 1'b0; hs_m_hp_rval <= 1'b0; hs_m_hp_hit <= 1'b0;
            hs_m_hp_ret <= 1'b0; hs_m_hp_phase <= 1'b0; hs_m_hp_proto <= 1'b0;
            hs_m_hp_qn <= 1'b0; hs_m_hp_qi <= 1'b0; hs_m_hp_si <= 1'b0;
            hs_m_hp_ss <= 1'b0; hs_m_hp_tn <= 1'b0; hs_m_hp_from_stack <= 1'b0;
            hs_m_hp_make_arr <= 1'b0; hs_m_hp_vbase <= 1'b0;
            hs_m_hp_spr_w <= 1'b0; hs_m_hp_spr_h <= 1'b0; hs_m_hp_nat <= 1'b0;
            hs_m_hp_tag <= 1'b0; hs_m_hp_qk <= 1'b0; hs_m_hp_qv <= 1'b0; hs_m_hp_qt <= 1'b0;
            hs_m_valloc_kind <= 1'b0; hs_m_valloc_i <= 1'b0; hs_m_valloc_arr_n <= 1'b0; hs_m_valloc_retried <= 1'b0; hs_m_vnat_dom <= 1'b0; hs_m_vnat_base <= 1'b0; hs_m_valloc_now_fn <= 1'b0; hs_m_valloc_bind <= 1'b0; hs_m_valloc_bind_src <= 1'b0; hs_m_valloc_bind_this <= 1'b0; hs_m_valloc_fn_entry <= 1'b0; hs_m_valloc_fn_a1 <= 1'b0; hs_m_valloc_proto <= 1'b0; hs_m_valloc_proto_fn <= 1'b0; hs_m_valloc_metrics <= 1'b0; hs_m_valloc_regex <= 1'b0; hs_m_valloc_regex_pack <= 1'b0; hs_m_vcall_value <= 1'b0; hs_m_vcall_argc <= 1'b0; hs_m_vcall_entry <= 1'b0; hs_m_vcall_set_this <= 1'b0; hs_m_vcall_this <= 1'b0; hs_m_vcall_ctor_val <= 1'b0; hs_m_vraf_n <= 1'b0; hs_m_vlistener_n <= 1'b0; hs_m_vgc_halt_after <= 1'b0; hs_m_vgc_wait_after <= 1'b0; hs_m_vgc_clear_i <= 1'b0; hs_m_vgc_qr <= 1'b0; hs_m_vgc_qw <= 1'b0; hs_m_vdraw_i <= 1'b0; hs_m_vdraw_x <= 1'b0; hs_m_vdraw_y <= 1'b0; hs_m_vdraw_w <= 1'b0; hs_m_vdraw_h <= 1'b0; hs_m_vdraw_color <= 1'b0; hs_m_vfe_i <= 1'b0; hs_m_vfe_pop <= 1'b0;
            // potential-bugs #49: mirror exec64's path-command writes into the
            // parent arrays that S_PWALK / S_PDO / S_LINE / S_CIRCLE / S_QSEG
            // raster from. exec64 fills its own copy then asks for S_PWALK,
            // but the parent's pc_* had NO writer at all — pc_n stuck at 0, so
            // the walk aborted on beat 0 and every arc / lineTo / fill /
            // stroke painted nothing (PX line=0 circ=0 in every title).
            // 16 slots of FFs, not SRAM; same shape as the #47 mirror.
            // pc_we defaults to 0 in exec64's always_comb, so this is quiet
            // whenever exec is disabled or the opcode is not a path command.
            // potential-bugs #54: mirror exec64's vjs seed writes (stringify
            // JSON.stringify(x) writes vjs_val[0]=x in exec's copy; the parent
            // S_V64_JSON walker reads the parent copy).
            if (v64_on && e64_js_we_q) begin
                vjs_val[e64_js_waddr_q] <= e64_vjs_val_wdata_q;
                js_i  [e64_js_waddr_q] <= e64_js_i_wdata_q;
                js_ph [e64_js_waddr_q] <= e64_js_ph_wdata_q;
            end
            if (v64_on && e64_pc_we_q) begin
                pc_op [e64_pc_waddr_q] <= e64_pc_op_wdata_q;
                pc_a1 [e64_pc_waddr_q] <= e64_pc_a1_wdata_q;
                pc_a2 [e64_pc_waddr_q] <= e64_pc_a2_wdata_q;
                pc_a3 [e64_pc_waddr_q] <= e64_pc_a3_wdata_q;
                pc_a4 [e64_pc_waddr_q] <= e64_pc_a4_wdata_q;
                pc_a5 [e64_pc_waddr_q] <= e64_pc_a5_wdata_q;
                pc_ccw[e64_pc_waddr_q] <= e64_pc_ccw_wdata_q;
            end
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;
            e32_p_clr <= 1'b0;
            e32_p_we <= 1'b0;
            // Parent-only name_blen / name_hash_tbl: rdata next clock, no exec copy.
            // One write port: p_clr we (exec combo) OR trail/JOIN poke 17/40
            // (parent p_we, same posedge exec consumes the poke). Combo we
            // from poke is a cycle late and missed the pulse — intern
            // lengths stayed post-p_clr zero.
            if (e64_p_we && e64_p_sel == 6'd17) begin
                begin nbl_we <= 1'b1; nbl_wa <= e64_p_addr[9:0]; nbl_wd <= e64_p_data[15:0]; end
            end else if (e64_p_we && e64_p_sel == 6'd41) begin
                // Trail phase 4 pokes 41 (u8 intern len). Same Port A as
                // poke 17 so GET_PROP .length is not a second FSM driver.
                begin nbl_we <= 1'b1; nbl_wa <= e64_p_addr[9:0]; nbl_wd <= {8'd0, e64_p_data[7:0]}; end
            end else if (e64_name_blen_we)
                begin nbl_we <= 1'b1; nbl_wa <= e64_name_blen_waddr; nbl_wd <= e64_name_blen_wdata; end
            // name_hash_tbl writes: Port A process (name_hash_we / poke 40 / exec we).
            // name_has: ONE write statement so 1W is provable (three
            // separate writes kept it FF — census: 7.7k LUTs). Priority
            // preserves the old semantics: poke17 sets the bit and used
            // to exclude name_has_we; nh (heap-clr/load) never collides.
            begin
                logic nh_do;
                logic [9:0] nh_a;
                logic nh_d;
                nh_do = 1'b0; nh_a = '0; nh_d = 1'b0;
                if (nh_we) begin
                    nh_do = 1'b1; nh_a = nh_wa; nh_d = nh_wd;
                end else if (e64_p_we && e64_p_sel == 6'd17) begin
                    nh_do = 1'b1; nh_a = e64_p_addr[9:0]; nh_d = 1'b1;
                end else if (e64_name_has_we) begin
                    nh_do = 1'b1; nh_a = e64_name_has_waddr; nh_d = e64_name_has_wdata;
                end
                if (nh_do) name_has[nh_a] <= nh_d;
            end
            kd_fn <= kd_slot[0];
            ku_fn <= ku_slot[0];
            if (fb_swap || ((state == S_V64_EXEC) && e64_fb_swap_q))
                dbg_swap_n <= dbg_swap_n + 16'd1; // NEW: present count
            // Exec nid 3 (swapBuffers) only set e64_fb_swap_q; dbg counted
            // it but mini_fb.front never flipped, so fillRect landed in the
            // back bank and HDMI/FB? stayed empty. Pulse on the leave_hold
            // beat only (one present per opcode).
            if ((state == S_V64_EXEC) && e64_leave_hold && e64_fb_swap_q) begin
                fb_swap <= 1'b1;
                fb_dirty <= 1'b0;
            end
            // Any pixel written to the back bank makes this frame presentable.
            // casestate_q term: the last copy write is registered on the
            // final S_FB_SYNC beat and SEEN one beat later (state already
            // S_V64_GC_CLEAR) — without it that drain write re-marked the
            // frame dirty and every frame re-presented forever.
            if (fb_we && state != S_FB_SYNC && casestate_q != S_FB_SYNC)
                fb_dirty <= 1'b1;
            // C1: the engine draws on the VM's behalf now, so the VM's own
            // fb_we never fires for rect/clear/blit/imgd — the implicit
            // frame-end present (fb_dirty at 14423) starved and legacy .JS
            // titles stopped presenting (battery: swaps stuck at 2 across
            // 43 frames). Any engine issue marks the frame dirty. (A blit
            // of only-transparent pixels now also marks dirty — one benign
            // extra present of an unchanged FB, matching the "this frame
            // drew" intent.)
            if (rast_go)
                fb_dirty <= 1'b1;
            // S_ARR_PROMOTE completion sets vprom_done so the requester
            // stops asking. The JSON paths consume-and-clear it themselves;
            // an exec-requested promote had no such clear, and exec only ever
            // cleared its OWN copy — which the parent never set. Exec then
            // re-requested the promote every beat and the push at that ip
            // spun for the whole 64M frame (INVADERS after Space). Retire the
            // flag at the instruction boundary: exec has already re-evaluated
            // by then.
            if (state == S_FETCH_WAIT) vprom_done <= 1'b0;
            // NEW: capture raw host key events (any state; drained per frame)
            if (key_evt_stb && (kev_wp + 3'd1) != kev_rp) begin
                kev_q[kev_wp] <= {key_evt_down, key_evt_code};
                kev_wp <= kev_wp + 3'd1;
                // 2026-08-21 (DONKEY Mario->Luigi, second occurrence): the
                // dispatch-time supersede only fires when the real event is
                // ALREADY queued. An edge captured while vlistener_n was
                // momentarily 0 (screen swap re-registers listeners) or
                // before this strobe's RPC landed sat armed and converted
                // into a phantom synthetic arrow seconds later. Supersede at
                // ENQUEUE too: any real key traffic invalidates captured
                // KEYBITS edges and re-baselines prev_joy, so only a real
                // joystick (KEYBITS with no KEYEVT twin) ever converts.
                joy_down_edge <= 6'd0;
                joy_up_edge <= 6'd0;
                prev_joy <= joy_in;
            end
            // EXEC scalar we is not an else-if vs unique case: leave_hold
            // must still enter ALLOC/RECT/BIND (casestate). Apply we here.
            // RET_VAL clocks win0_we_q; next cycle is FETCH_WAIT / WIN_FILL
            // (not EXEC). Plant regardless so LET_VAR sees the instance.
            if (e64_vst_win0_we)
                vst_win[0] <= e64_vst_win0_wdata;
            // Same reason as vst_win0_we above, for every other exec write:
            // *_we_q is a registered pulse, visible the cycle AFTER exec
            // decided — by then leave_hold has already moved state to
            // ALLOC / HEAP_* / FETCH_WAIT, so gating this block on
            // `state == S_V64_EXEC` silently dropped every write that
            // coincided with leaving EXEC. venv_valid was the loudest:
            // a ctor's env lost its valid bit, so the next LOAD_VAR down
            // the env chain faulted 4 (PACMAN `new Stage()`). Exec clears
            // *_we_q on its first idle beat, so this still applies exactly
            // one write. The parent FSM case runs later in this same
            // always_ff, so a parent write to the same array still wins.
            begin
                if (e64_vraf_we) vraf[e64_vraf_waddr] <= e64_vraf_wdata;
                if (e64_vtimer_we) begin
                    vtimer_valid[e64_vtimer_waddr] <= e64_vtimer_valid_wdata;
                    // potential-bugs #66: exec setTimeout/clearTimeout only
                    // adjusted EXEC's vtimer_n copy; the parent FF (which
                    // decrements when a timer FIRES in S_V64_FRAME_TIMER)
                    // never saw the increments, and exec never saw the
                    // fire-time decrements — its copy climbed monotonically
                    // to 64 and every later setTimeout faulted 3/3816
                    // (DONKEY throws several timers per barrel). Keep the
                    // parent FF as truth here, and let the frozen exec
                    // absorb p_vtimer_n below.
                    if (e64_vtimer_valid_wdata)
                        vtimer_n <= vtimer_n + 7'd1;
                    else if (vtimer_n != 7'd0)
                        vtimer_n <= vtimer_n - 7'd1;
                    if (e64_vtimer_valid_wdata) begin
                        begin vtd_we <= 1'b1; vtd_wa <= e64_vtimer_waddr; vtd_wd <= e64_vtimer_due_wdata; end
                        vtimer_fn[e64_vtimer_waddr] <= e64_vtimer_fn_wdata;
                        vtimer_id[e64_vtimer_waddr] <= e64_vtimer_id_wdata;
                        vtimer_period[e64_vtimer_waddr] <= e64_vtimer_period_wdata;
                    end
                end
                // listener table writes/compaction: the lsv service owns them
                // now (single table; #77's dual-copy sync is structurally gone).
                if (e64_json_mem_we) begin
                    json_we <= 1'b1;
                    json_waddr <= e64_json_mem_waddr[12:0];
                    json_wdata <= e64_json_mem_wdata;
                end
                // varr_len / vvars writes: Port A processes (not this FSM).
                // moved to Port A process (metadata evacuation)
                // moved to Port A process (metadata evacuation)
                if (e64_varr_long_we && e64_varr_long_wdata && e64_varr_lidx_we)
                    begin vlu_we <= 1'b1; vlu_wa <= e64_varr_lidx_wdata[6:0]; vlu_wd <= 1'b1; end
                // moved to Port A process (metadata evacuation)
                // e64_venv_gen_we applies in the dedicated metadata process
                // e64_venv_len_we applies in the dedicated len process
                // moved to Port A process (metadata evacuation)
                // e64_vobj_cls_we applies in the dedicated metadata process
                // moved to Port A process (metadata evacuation)
                if (e64_vframe_we)
                    // record fields write in the dedicated vframe process;
                    // escaped stays here (flat FFs, partial-field writers)
                    vframe_escaped[e64_vframe_waddr] <= e64_vframe_esc_wdata;
            end
            if ((state == S_EXEC) || (state == S_NAT)) begin
                // we_q is registered; apply on EXEC/NAT including leave_hold.
                // arr_len writes: Port A process (e32 channel is driverless)
                if (e32_env_cap_we) env_cap[e32_env_cap_waddr[8:0]] <= e32_env_cap_wdata;
                if (e32_env_oid_we) env_oid[e32_env_oid_waddr[8:0]] <= e32_env_oid_wdata;
                if (e32_json_mem_we) begin
                    json_we <= 1'b1;
                    json_waddr <= e32_json_mem_waddr[12:0];
                    json_wdata <= e32_json_mem_wdata;
                end
                if (e32_obj_cls_we) obj_cls[e32_obj_cls_waddr[9:0]] <= e32_obj_cls_wdata;
                if (e32_obj_n_we) obj_n[e32_obj_n_waddr[9:0]] <= e32_obj_n_wdata;
                // stack / stack_tag writes: Port A processes (not this FSM).
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
                // e32_vobj_len_we applies in the dedicated len process
                if (e32_fn_proto_we) begin
                    fn_proto_ip[e32_fn_proto_waddr] <= e32_fn_proto_ip_wdata;
                    fn_proto_oid[e32_fn_proto_waddr] <= e32_fn_proto_oid_wdata;
                    n_fn_proto <= e32_n_fn_proto_q;
                end
                if (e32_cstack_we) begin
                    ; // p3b: dead tagged write removed (cstack_ctorobj)
                    begin cse_we <= 1'b1; cse_wa <= e32_cstack_waddr[6:0]; cse_wd <= e32_cstack_env_wdata; end
                    ; // p3b: dead tagged write removed (cstack_fe_arr)
                    ; // p3b: dead tagged write removed (cstack_fe_fn)
                    ; // p3b: dead tagged write removed (cstack_fe_i)
                    ; // p3b: dead tagged write removed (cstack_ip)
                    cstack_isctor[e32_cstack_waddr] <= e32_cstack_isctor_wdata;
                    cstack_isfe[e32_cstack_waddr] <= e32_cstack_isfe_wdata;
                    ; // p3b: dead tagged write removed (cstack_map_arr)
                    ; // p3b: dead tagged write removed (cstack_this)
                    // flatten: we_q is 1 cycle late; csp_e32_d is exec csp at issue.
                    if (e32_csp_q > csp_e32_d && e32_cstack_waddr == csp_e32_d) begin
                        cstk_win_shift_to_2();
                        cstk_win_from_wdata();
                    end else if (e32_csp_q < csp_e32_d && csp_e32_d >= 7'd2 &&
                                 e32_cstack_waddr == (csp_e32_d - 7'd2)) begin
                        cs_win1_ip <= cs_win2_ip;
                        cs_win1_this <= cs_win2_this;
                        cs_win1_isctor <= cs_win2_isctor;
                        cs_win1_isfe <= cs_win2_isfe;
                        cs_win1_ctorobj <= cs_win2_ctorobj;
                        cs_win1_fe_arr <= cs_win2_fe_arr;
                        cs_win1_fe_fn <= cs_win2_fe_fn;
                        cs_win1_fe_i <= e32_cstack_fe_i_wdata;
                        cs_win1_map_arr <= cs_win2_map_arr;
                        cs_win1_env <= cs_win2_env;
                    end else if (csp_e32_d >= 7'd1 &&
                                 e32_cstack_waddr == (csp_e32_d - 7'd1)) begin
                        cstk_win_from_wdata();
                    end else if (csp_e32_d >= 7'd2 &&
                                 e32_cstack_waddr == (csp_e32_d - 7'd2)) begin
                        cs_win2_fe_i <= e32_cstack_fe_i_wdata;
                    end
                end else if (e32_csp_q < csp_e32_d && csp_e32_d >= 7'd1) begin
                    cs_win1_ip <= cs_win2_ip;
                    cs_win1_this <= cs_win2_this;
                    cs_win1_isctor <= cs_win2_isctor;
                    cs_win1_isfe <= cs_win2_isfe;
                    cs_win1_ctorobj <= cs_win2_ctorobj;
                    cs_win1_fe_arr <= cs_win2_fe_arr;
                    cs_win1_fe_fn <= cs_win2_fe_fn;
                    cs_win1_fe_i <= cs_win2_fe_i;
                    cs_win1_map_arr <= cs_win2_map_arr;
                    cs_win1_env <= cs_win2_env;
                end
                if (e32_to_we) begin
                    to_fn[e32_to_waddr] <= e32_to_fn_wdata;
                    to_delay[e32_to_waddr] <= e32_to_delay_wdata;
                    to_id[e32_to_waddr] <= e32_to_id_wdata;
                    to_period[e32_to_waddr] <= e32_to_period_wdata;
                    if (e32_to_waddr == 6'd0)
                        to_fn0 <= e32_to_fn_wdata;
                end
                to_n <= e32_to_n_q;
                to_seq <= e32_to_seq_q;
            end
            // Class table is 16×16 FFs (not intern SRAM). Match in one clock.
            // Sequential (c,m) was 256 clocks per GET_PROP miss — play CALL
            // paid that every method. unique-case CAM over BRAM is still
            // forbidden; this is FF equality outside the opcode case.
            if (lsv_served_hold) begin
                if (!e64_lsv_req) begin
                    lsv_served_hold <= 1'b0;
                    lsv_res_we <= 1'b0;
                end
            end else if (v64_on && e64_lsv_req && !lsv_serving) begin
                lsv_serving <= 1'b1;
                lsv_k <= 5'd0;
                lsv_w <= 5'd0;
                lsv_same <= 5'd0;
                lsv_dup <= 1'b0;
                lsv_arm <= 1'b0;
            end else if (lsv_serving) begin
                if (!lsv_arm) begin
                    if (lsv_k >= vlistener_n) begin
                        lsv_serving <= 1'b0;
                        lsv_served_hold <= 1'b1;
                        lsv_res_we <= 1'b1;
                        if (e64_lsv_op == 2'd1) begin
                            lsv_res_n_out <= vlistener_n;
                            if (lsv_dup) lsv_res <= 3'd1;
                            else if (lsv_same >= 5'd4) lsv_res <= 3'd2;
                            else if (vlistener_n >= 5'd16) lsv_res <= 3'd3;
                            else begin
                                lsv_res <= 3'd0;
                                vlistener_ev[vlistener_n[3:0]] <= e64_lsv_ev;
                                vlistener_fn[vlistener_n[3:0]] <= e64_lsv_fn;
                                // the hs mask cannot land while exec is held
                                // (mask applies live in the frozen branch);
                                // the count rides the result instead.
                                lsv_res_n_out <= vlistener_n + 5'd1;
                                vlistener_n_ff <= vlistener_n + 5'd1;
                            end
                        end else begin
                            lsv_res <= 3'd0;
                            for (int t = 0; t < 16; t++)
                                if (5'(t) >= lsv_w && 5'(t) < vlistener_n) begin
                                    vlistener_ev[t] <= V64_UNDEFINED;
                                    vlistener_fn[t] <= V64_UNDEFINED;
                                end
                            lsv_res_n_out <= lsv_w;
                            vlistener_n_ff <= lsv_w;
                        end
                    end else
                        lsv_arm <= 1'b1; // rdata mux is pointed at lsv_k
                end else begin
                    lsv_arm <= 1'b0;
                    if (e64_lsv_op == 2'd1) begin
                        if (v64_equal(vlistener_ev_rdata, e64_lsv_ev)) begin
                            lsv_same <= lsv_same + 5'd1;
                            if (v64_equal(vlistener_fn_rdata, e64_lsv_fn))
                                lsv_dup <= 1'b1;
                        end
                    end else begin
                        if (!(v64_equal(vlistener_ev_rdata, e64_lsv_ev) &&
                              v64_equal(vlistener_fn_rdata, e64_lsv_fn))) begin
                            vlistener_ev[lsv_w[3:0]] <= vlistener_ev_rdata;
                            vlistener_fn[lsv_w[3:0]] <= vlistener_fn_rdata;
                            lsv_w <= lsv_w + 5'd1;
                        end
                    end
                    lsv_k <= lsv_k + 5'd1;
                end
            end
            if (cm_served_hold) begin
                // Result is LEVEL, held until exec drops the request —
                // exec's *_n consumption only lands on enable&&!leave_hold
                // beats, so a one-beat pulse could be missed (livelock).
                if (!e64_cm_req) begin
                    cm_served_hold <= 1'b0;
                    cm_res_we <= 1'b0;
                end
            end else if (v64_on && e64_cm_req && !cm_serving &&
                         !cls_scan && !cls_seq) begin
                cls_cls <= e64_cm_cls;
                cls_key <= e64_cm_key;
                cls_ctor_mode <= 1'b0;
                cls_mip_q <= 16'hFFFF;
                cls_scan <= 1'b1;
                cls_armed <= 1'b0;
                cls_done <= 1'b0;
                cm_serving <= 1'b1;
            end
            if (cm_serving && cls_done) begin
                // exec's CAM matched only non-getter entries; the walk fills
                // cls_mip_q with exactly those, so hand that back.
                cm_res_we <= 1'b1;
                cm_res_mip <= cls_mip_q;
                cm_serving <= 1'b0;
                cm_served_hold <= 1'b1;
                cls_done <= 1'b0;
            end
            if (cls_scan) begin
                if (cls_ctor_mode) begin
                    for (int ci = 0; ci < MAX_CLS; ci++) begin
                        if ((5'(ci) < n_cls) && (cls_name[ci] == cls_cls)) begin
                            cls_ctor_q <= cls_ctor[ci];
                            cls_hit <= 1'b1;
                        end
                    end
                    cls_scan <= 1'b0;
                    cls_armed <= 1'b0;
                    cls_done <= 1'b1;
                end else if (!cls_seq) begin
                    // Beat 1: comb class find over the small FF arrays,
                    // then start the method walk (or finish on miss).
                    logic       f_hit;
                    logic [3:0] f_ci;
                    f_hit = 1'b0; f_ci = 4'd0;
                    for (int ci = 0; ci < MAX_CLS; ci++)
                        if ((5'(ci) < n_cls) && (cls_name[ci] == cls_cls)) begin
                            f_hit = 1'b1; f_ci = 4'(ci);
                        end
                    if (!f_hit) begin
                        cls_scan <= 1'b0;
                        cls_armed <= 1'b0;
                        cls_done <= 1'b1;
                    end else begin
                        cls_seq <= 1'b1;
                        cls_prime <= 1'b1;
                        cls_c <= f_ci;
                        cls_m <= 4'd0;
                        clsm_raddr <= {f_ci, 4'd0};
                    end
                end else if (cls_prime) begin
                    // Beat 2: first read in flight; advance the address.
                    cls_prime <= 1'b0;
                    cls_m <= 4'd1;
                    clsm_raddr <= {cls_c, 4'd1};
                end else begin
                    // One method per beat: compare the landed read for
                    // entry cls_m-1 while entry cls_m is in flight.
                    logic [3:0] mprev;
                    mprev = cls_m - 4'd1;
                    if (({1'b0, mprev} < cls_nmeth[cls_c]) &&
                        (clsm_name_rd[14:0] == cls_key[14:0])) begin
                        if (clsm_name_rd[15])
                            cls_gip_q <= clsm_ip_rd;
                        else
                            cls_mip_q <= clsm_ip_rd;
                    end
                    if (({1'b0, mprev} + 5'd1 >= cls_nmeth[cls_c]) ||
                        (mprev == 4'(MAX_CMETH - 1))) begin
                        cls_seq <= 1'b0;
                        cls_scan <= 1'b0;
                        cls_armed <= 1'b0;
                        cls_done <= 1'b1;
                    end else begin
                        cls_m <= cls_m + 4'd1;
                        // 2026-08-26 DONKEY root cause: issuing the
                        // pre-increment index re-read the entry the
                        // prime beat already issued, lagging every
                        // later comparison by one entry - the LAST
                        // method's data landed one beat after the
                        // walk terminated and was NEVER compared. Any
                        // class with >=3 methods could not resolve
                        // its final method (Mario/DK/Barrel .update
                        // are all declared last: no player, no kong,
                        // no barrels). Issue one ahead.
                        clsm_raddr <= {cls_c, cls_m + 4'd1};
                    end
                end
            end
            if (stop) begin
                running <= 1'b0;
                looping <= 1'b0;
                sram_req <= 1'b0; sram_we <= 1'b0; blit_wait <= 1'b0; // NEW: drop mid-blit SRAM req
                        hs_st(S_IDLE);
            end else if (((state == S_EXEC) || (state == S_NAT)) && !e32_leave_hold) begin
                // we already applied above. Skip unique case (no EXEC arm).
            end else if ((state == S_V64_EXEC) && !e64_leave_hold) begin
                // we already applied above. Skip unique case (no EXEC arm).
            end else if (vgc_mark_pend) begin
                // flatten: unique case must not peek alloc/valid from a handle.
                if (!vgc_mark_arm)
                    vgc_mark_arm <= 1'b1;
                else begin
                    begin
                        logic [3:0] mk;
                        logic [31:0] mi;
                        logic [15:0] oid32;
                        mk = vgc_mark_word[47:44];
                        mi = vgc_mark_word[31:0];
                        oid32 = vgc_mark_word[15:0];
                        if (v64_on &&
                            vgc_mark_word[63:48] == 16'h7ff9 &&
                            (mk == V64_KIND_OBJECT || mk == V64_KIND_ELEMENT) &&
                            mi < MAX_OBJ &&
                            vobj_alloc_rdata == 2'd1 &&
                            !vobj_mark_rdata) begin
                            begin vmko_we <= 1'b1; vmko_wa <= mi[9:0]; vmko_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (v64_on &&
                                     vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd7 && mi < MAX_OBJ &&
                                     vfn_valid_rdata && !vfn_mark_rdata) begin
                            begin vmkf_we <= 1'b1; vmkf_wa <= mi[9:0]; vmkf_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (v64_on &&
                                     vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd6 && mi < MAX_ARR &&
                                     varr_valid_rdata && !varr_mark_rdata) begin
                            begin vmka_we <= 1'b1; vmka_wa <= mi[11:0]; vmka_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (v64_on &&
                                     vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd9 && mi < ENV_DEPTH &&
                                     venv_valid_rdata && !venv_mark_rdata) begin
                            begin vmke_we <= 1'b1; vmke_wa <= mi[8:0]; vmke_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (!v64_on && vgc_mark_word[16] &&
                                     oid32 < n_arr && oid32 < 16'(MAX_ARR) &&
                                     !gc_arr_mark_rdata) begin
                            gc_arr_mark[oid32[11:0]] <= 1'b1;
                            ; // p3b: dead tagged write removed (gc_queue)
                            gc_qw <= gc_qw + 14'd1;
                            if (oid32 + 16'd1 > gc_arr_high)
                                gc_arr_high <= oid32 + 16'd1;
                        end else if (!v64_on && !vgc_mark_word[16] &&
                                     oid32 < n_obj && oid32 < 16'(MAX_OBJ) &&
                                     !gc_obj_mark_rdata) begin
                            gc_obj_mark[oid32[12:0]] <= 1'b1;
                            ; // p3b: dead tagged write removed (gc_queue)
                            gc_qw <= gc_qw + 14'd1;
                            if (oid32 + 16'd1 > gc_obj_high)
                                gc_obj_high <= oid32 + 16'd1;
                        end
                    end
                    vgc_mark_pend <= 1'b0;
                    vgc_mark_arm <= 1'b0;
                end
            end else if (cs_refill != 2'd0) begin
                // flatten: one cstack slot/clock into the 2-deep window after pop.
                if (!cs_refill_arm)
                    cs_refill_arm <= 1'b1;
                else begin
                    if (cs_refill_win1) begin
                        cstk_win_load1();
                        cs_refill_win1 <= 1'b0;
                        if (cs_refill == 2'd2) begin
                            cs_raddr_ff <= cs_raddr_ff - 7'd1;
                            cs_refill <= 2'd1;
                        end else
                            cs_refill <= 2'd0;
                    end else begin
                        cstk_win_load2();
                        cs_refill <= 2'd0;
                    end
                    cs_refill_arm <= 1'b0;
                end
            // UG901: unique case = parallel_case (every arm a mux). This FSM
            // is ~80 states × blocking temps; that was the 70 GB flatten after
            // unused-FF. Plain case sequences; SRAM still rdata<=mem[raddr].
            end else case (casestate)
                S_IDLE: if (start) begin
                    running <= 1'b1;
                    looping <= 1'b0;
                    sp <= '0;
                    hs_vsp('0);
                    hs_vcsp('0);
                    hs_code(15'd0);
                    hs_st(S_RD);
                    ret_state <= S_GOT_MAGIC;
                end
                S_RD: hs_st(ret_state);

                S_GOT_MAGIC: begin
                    if (code_rdata != 32'h3142534A) begin
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else begin
                        hs_code(15'd1);
                        hs_st(S_RD);
                        ret_state <= S_GOT_HDR1;
                    end
                end
                S_GOT_HDR1: begin
                    n_ops    <= code_rdata[15:0];
                    n_consts <= code_rdata[31:16];
                    hs_code(15'd2);
                    hs_st(S_RD);
                    ret_state <= S_GOT_HDR2;
                end
                S_GOT_HDR2: begin
                    // exec32 retirement Phase 2 (docs/REMOVING_EXEC32.md):
                    // an image without FLAG_VALUE64 (flags bit3 =
                    // code_rdata[19]) has no decoder any more. Fault loud;
                    // never reach S_EXEC / hs32.
                    if (!code_rdata[19]) begin
                        machine_fault <= 1'b1;
                        fault_code <= 8'd9; // 9 = tagged image refused
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else if ({16'd0, (code_rdata[17] ? 16'd4 : 16'd3)}
                               + {15'd0, (code_rdata[19] ? {n_consts, 1'b0}
                                                         : {1'b0, n_consts})}
                               + {16'd0, n_ops} > 32'(CODE_WORDS)) begin
                        // 2026-08-21 fit: CODE_WORDS shrank to the measured
                        // envelope. An image whose header promises more words
                        // than code_mem holds is refused LOUD here - the
                        // write clamp above would otherwise truncate it and
                        // the VM would fetch zeros mid-program.
                        machine_fault <= 1'b1;
                        fault_code <= 8'd3; // capacity
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else begin
                    // NEW: flags bit1 (ASET) → u32 aset_byte_off occupies word 3,
                    // consts start at word 4; sprites blit from the asset SRAM.
                    aset_mode <= code_rdata[17];
                    hdr_w <= code_rdata[17] ? 16'd4 : 16'd3;
                    ops_base <= (code_rdata[17] ? 16'd4 : 16'd3)
                              + (code_rdata[19] ? (n_consts << 1) : n_consts);
                    jsb_flags <= code_rdata[31:16];
                    e64_p_clr <= 1'b1;
                    e32_p_clr <= 1'b1;
                    heap_clr_busy <= 1'b1;
                    heap_clr_i <= 12'd0;
                    hs_vsp('0); hs_vcsp('0);
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
                        hs_valloc_retried(1'b0);
                        hs_vthis(V64_UNDEFINED);
                        hs_venv(V64_UNDEFINED);
                        hs_vcall_set_this(1'b0);
                        hs_vcall_this(V64_UNDEFINED);
                        hs_vcall_ctor_val(V64_UNDEFINED);
                        intern_ctor_hold <= 1'b0;
                        intern_ctor_entry <= 16'd0;
                        intern_ctor_nparam <= 6'd0;
                        intern_ctor_flags <= 3'd0;
                        intern_ctor_env <= V64_UNDEFINED;
                        hs_vraf_n(4'd0);
                        vtimer_n <= 7'd0;
                        vframe_no <= 32'd0;
                        gc_ran_this_frame <= 1'b0; // C4
                        // Last intern coords survive RUN otherwise PACMAN
                        // SNAP shows the previous title's vdraw (INVADERS 14×5).
                        hs_vdraw_x('0); hs_vdraw_y('0);
                        hs_vdraw_w('0); hs_vdraw_h('0);
                        hs_vdraw_color('0);
                        vtimer_seq <= 32'd1;
                        vrng <= 32'h6d2b79f5;
                        vconsole_n <= 9'd0;
                        hs_vnat_dom(3'd0);
                        vnat_style <= V64_UNDEFINED;
                        vkev_event <= V64_UNDEFINED;
                        hs_vlistener_n(5'd0);
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
                    end
                    n_obj <= 0; n_arr <= 0; n_cls <= 0; csp <= 0; raf_n <= 0;
                    to_fn0 <= 16'd0;
                    cs_win1_ip <= 16'd0; cs_win2_ip <= 16'd0;
                    cs_win1_this <= 16'd0; cs_win2_this <= 16'd0;
                    cs_win1_isctor <= 1'b0; cs_win2_isctor <= 1'b0;
                    cs_win1_isfe <= 1'b0; cs_win2_isfe <= 1'b0;
                    cs_win1_ctorobj <= 16'd0; cs_win2_ctorobj <= 16'd0;
                    cs_win1_fe_arr <= 16'd0; cs_win2_fe_arr <= 16'd0;
                    cs_win1_fe_fn <= 16'd0; cs_win2_fe_fn <= 16'd0;
                    cs_win1_fe_i <= 8'd0; cs_win2_fe_i <= 8'd0;
                    cs_win1_map_arr <= 16'd0; cs_win2_map_arr <= 16'd0;
                    cs_win1_env <= 6'd0; cs_win2_env <= 6'd0;
                    cs_pend_valid <= 1'b0;
                    cs_refill <= 2'd0; cs_refill_arm <= 1'b0;
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
                    id_slice <= 16'hFFFF; // #40
                    id_sort <= 16'hFFFF; // #41
                    click_fired <= 1'b0;
                    pre_click_raf <= 1'b0;
                    prev_joy <= joy_in; joy_down_edge <= 0; joy_up_edge <= 0;
                    fill_style_i <= 8'd0; stroke_style_i <= 8'd0; lfsr <= 32'hACE1; this_obj <= 16'hFFFF;
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
                    id_reduce <= 16'hFFFF; // #39
                    id_keydown <= 16'hFFFF; id_keyup <= 16'hFFFF; id_width <= 16'hFFFF;
                    id_space <= 16'hFFFF; id_arrow_l <= 16'hFFFF; id_arrow_r <= 16'hFFFF;
                    id_w <= 16'hFFFF; id_s <= 16'hFFFF; id_p <= 16'hFFFF;
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
                    id_textbaseline <= 16'hFFFF; id_top <= 16'hFFFF;
                    id_middle <= 16'hFFFF; id_bottom <= 16'hFFFF;
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
                    jn_hit_v <= 4'd0; jn_cache_try <= 1'b0; jn_cache_i <= 3'd0;
                    v64_concat <= 1'b0;
                    v64_join <= 1'b0;
                    v64_sqrt <= 1'b0;
                    v64_repl <= 1'b0;
                    dbg_rect_n <= 7'd0; dbg_swap_n <= 16'd0;
            dbg_last_y <= 10'd0; dbg_last_c <= 8'd0;
            dbg_key_scan <= 16'd0; dbg_key_call <= 16'd0;
            dbg_key_alloc <= 16'd0; dbg_key_cmp <= 16'd0; dbg_txt_n <= 16'd0;
            dbg_txt_miss <= 16'd0; dbg_raf_call <= 16'd0; dbg_frame_end <= 16'd0;
            dbg_bad_state <= 8'd0;
            dbg_key_want <= 64'd0; dbg_key_lastev <= 64'd0;
                    dbg_line_px <= 32'd0; dbg_circ_px <= 32'd0; dbg_rect_px <= 32'd0;
                    pc_n <= 5'd0; pi <= 5'd0; path_active <= 1'b0; dbg_path_ovf <= 16'd0;
                    qseg <= 4'd0; arc_ang <= 1'b0;
                    id_strokestyle <= 16'hFFFF;
                    id_hex_09f <= 16'hFFFF; id_hex_f5f5 <= 16'hFFFF; id_hex_ffe6 <= 16'hFFFF;
                    id_hex_f00 <= 16'hFFFF; id_hex_aaa <= 16'hFFFF;
                    path_kind <= 2'd0; n_spr <= 5'd0; spr_wp <= 18'd0; spr_hdr <= 3'd0;
                    dbg_di_hit <= 16'd0; dbg_di_miss <= 16'd0;
                    sprd_mode <= 1'b0; blit_wait <= 1'b0; sram_req <= 1'b0; sram_we <= 1'b0;
                    time_ms <= 32'd0;
                    n_fn_proto <= 7'd0;
                    enter_n <= 3'd0; enter_delay <= 4'd0; // hack retired (KEYEVT)
                    kev_wp <= 3'd0; kev_rp <= 3'd0;
                    names_static <= 16'd0; nb_static <= 16'd0;
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
                        hs_ip('0);
                        if (code_rdata[16]) begin
                            hs_code(15'((code_rdata[17] ? 16'd4 : 16'd3) + n_ops));
                            ret_state <= S_TRAIL;
                        end else begin
                            hs_code(code_rdata[17] ? 15'd4 : 15'd3);
                            ret_state <= S_FETCH_WAIT;
                        end
                        hs_st(S_HEAP_CLR);
                    end else begin
                        c_i <= '0;
                        hs_code(code_rdata[17] ? 15'd4 : 15'd3);
                        ret_state <= S_LD_CONST;
                        hs_st(S_HEAP_CLR);
                    end
                    end
                end
                S_HEAP_CLR: begin
                    // One index per clock on parent 1-D banks (SRAM has no
                    // parallel clear). Walk MAX_ARR (widest). Exec p_clr
                    // still wipes its leftover copies the same way.
                    if (heap_clr_busy) begin
                        if (heap_clr_i < 12'd256)
                            char_ok[heap_clr_i[7:0]] <= 1'b0;
                        if (heap_clr_i < 12'd64)
                            vtimer_valid[heap_clr_i[5:0]] <= 1'b0;
                        if (heap_clr_i < 12'(MAX_VARS)) begin
                            ; // p3b: dead tagged write removed (var_init)
                            ; // p3b: dead tagged write removed (vars)
                            begin vvv_we <= 1'b1; vvv_wa <= heap_clr_i[8:0]; vvv_wd <= 1'b0; end
                        end
                        if (heap_clr_i < 12'(MAX_OBJ)) begin
                            vobj_alloc_wr(heap_clr_i[9:0], 2'd0);
                            begin vog_we <= 1'b1; vog_wa <= heap_clr_i[9:0]; vog_wd <= 12'd1; end
                            begin vfg_we <= 1'b1; vfg_wa <= heap_clr_i[9:0]; vfg_wd <= 12'd1; end
                            begin vfv_we <= 1'b1; vfv_wa <= heap_clr_i[9:0]; vfv_wd <= 1'b0; end
                            begin vmkf_we <= 1'b1; vmkf_wa <= heap_clr_i[9:0]; vmkf_wd <= 1'b0; end
                            begin vol_we <= 1'b1; vol_wa <= {3'd0, heap_clr_i[9:0]}; vol_wd <= 6'd0; end
                            begin vmko_we <= 1'b1; vmko_wa <= heap_clr_i[9:0]; vmko_wd <= 1'b0; end
                            vom_we_bi <= 1'b1; vom_wa <= {3'd0, heap_clr_i[9:0]}; vom_bi <= 4'd0;
                        end
                        if (heap_clr_i < 12'(MAX_ARR)) begin
                            begin vav_we <= 1'b1; vav_wa <= heap_clr_i[10:0]; vav_wd <= 1'b0; end
                            begin vag_we <= 1'b1; vag_wa <= heap_clr_i[11:0]; vag_wd <= 12'd1; end
                            varr_len_wr(heap_clr_i[11:0], 8'd0);
                            begin alw_we <= 1'b1; alw_wa <= heap_clr_i[10:0]; alw_wd <= 8'd0; end
                            begin vmka_we <= 1'b1; vmka_wa <= heap_clr_i[11:0]; vmka_wd <= 1'b0; end
                            begin vlo_we <= 1'b1; vlo_wa <= heap_clr_i[10:0]; vlo_wd <= 1'b0; end
                            begin vli_we <= 1'b1; vli_wa <= heap_clr_i[10:0]; vli_wd <= 8'd0; end
                        end
                        if (heap_clr_i < 12'(MAX_ARR_LONG))
                            begin vlu_we <= 1'b1; vlu_wa <= heap_clr_i[6:0]; vlu_wd <= 1'b0; end
                        if (heap_clr_i < 12'(ENV_DEPTH)) begin
                            begin vev_we <= 1'b1; vev_wa <= heap_clr_i[8:0]; vev_wd <= 1'b0; end
                            veg_we <= 1'b1; veg_wa <= heap_clr_i[8:0]; veg_wd <= 12'd1;
                            begin vel_we <= 1'b1; vel_wa <= heap_clr_i[8:0]; vel_wd <= 5'd0; end
                            begin vmke_we <= 1'b1; vmke_wa <= heap_clr_i[8:0]; vmke_wd <= 1'b0; end
                            env_cap[heap_clr_i[8:0]] <= 1'b0;
                        end
                        if (heap_clr_i < 12'd1024) begin
                            begin flu_we <= 1'b1; flu_wa <= heap_clr_i[9:0]; flu_wd <= 8'hFF; end
                            begin nh_we <= 1'b1; nh_wa <= heap_clr_i[9:0]; nh_wd <= 1'b0; end
                            intern_var_ok[heap_clr_i[9:0]] <= 1'b0;
                        end
                        if (heap_clr_i + 12'd1 >= 12'(MAX_ARR))
                            heap_clr_busy <= 1'b0;
                        else
                            heap_clr_i <= heap_clr_i + 12'd1;
                    end else if (!e64_p_clr_busy && !e32_p_clr_busy) begin
                        if (ret_state == S_FETCH_WAIT)
                            hs_st(S_FETCH_WAIT);
                        else begin
                            hs_st(S_RD);
                        end
                    end
                end
                S_LD_CONST: begin
                    if (v64_on) begin
                        // Value64 constants are little-endian low/high u32 pairs.
                        vconst_lo <= code_rdata;
                        hs_code(15'(hdr_w + (c_i << 1) + 16'd1));
                        hs_st(S_RD);
                        ret_state <= S_V64_CONST_HI;
                    end else begin
                        ; // p3b: dead tagged write removed (consts)
                        if (c_i + 16'd1 >= n_consts) begin
                            hs_ip('0);
                            if (jsb_flags[0]) begin
                                hs_code(15'(hdr_w + n_consts + n_ops));
                                hs_st(S_RD);
                                ret_state <= S_TRAIL;
                            end else begin
                                hs_code(15'(hdr_w + n_consts));
                                hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            c_i <= c_i + 16'd1;
                            hs_code(15'(hdr_w + c_i + 16'd1));
                            hs_st(S_RD);
                            ret_state <= S_LD_CONST;
                        end
                    end
                end
                S_V64_CONST_HI: begin
                    vconsts_pa_we <= 1'b1;
                    vconsts_pa_waddr <= c_i[9:0];
                    vconsts_pa_wdata <= {code_rdata, vconst_lo};
                    e64_poke(6'd14, {6'd0, c_i[9:0]}, {code_rdata, vconst_lo});
                    if (c_i + 16'd1 >= n_consts) begin
                        hs_ip('0);
                        if (jsb_flags[0]) begin
                            hs_code(15'(ops_base + n_ops));
                            hs_st(S_RD);
                            ret_state <= S_TRAIL;
                        end else begin
                            hs_code(15'(ops_base));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else begin
                        c_i <= c_i + 16'd1;
                        hs_code(15'(hdr_w + ((c_i + 16'd1) << 1)));
                        hs_st(S_RD);
                        ret_state <= S_LD_CONST;
                    end
                end

                S_TRAIL: begin
                    // JSB v2 trailer: names (hash intern ids) + skip vars + class table
                    trail_guard <= trail_guard + 20'd1;
                    if (trail_guard >= 20'd200000) begin
                        // walker missed phase 22 — run ops (argc=4 fillRect still paints)
                        hs_code(15'(ops_base));
                        hs_st(S_FETCH_WAIT);
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
                                if ({tb, trail_acc[7:0]} == 16'd15762) id_slice <= name_idx; // #40
                                if ({tb, trail_acc[7:0]} == 16'd62878) id_sort <= name_idx; // #41
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
                                if ({tb, trail_acc[7:0]} == 16'd119)   id_w <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd115)   id_s <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd112)   id_p <= name_idx;
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
                                if ({tb, trail_acc[7:0]} == 16'd4754) id_textbaseline <= name_idx; // #37
                                if ({tb, trail_acc[7:0]} == 16'd49493) id_top <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd55701) id_middle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd39467) id_bottom <= name_idx;
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
                                name_hash_wr(name_idx[9:0], {tb, trail_acc[7:0]});
                                nhash <= {tb, trail_acc[7:0]};
                                // Poke 40 → exec name_hash_we. Indexed write
                                // above is not the SRAM we port (LOAD fill).
                                e64_poke(6'd40, {6'd0, name_idx[9:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                // NEW: u8 length byte follows each hash (concat fold)
                                trail_ph <= 5'd4;
                            end
                            5'd4: begin
                                begin nlt_we <= 1'b1; nlt_wa <= name_idx[9:0]; nlt_wd <= tb; end
                                e64_poke(6'd41, {6'd0, name_idx[9:0]}, {56'd0, tb});
                                // Space intern: hash 32 + len 1 (U+0020). Confirm
                                // here so e.key === " " matches KEYEVT payload.
                                if (nhash == 16'd32 && tb == 8'd1)
                                    id_space <= name_idx;
                                // "ArrowDown": hash 43 + len 9 (hash alone is
                                // also '+' and other short names)
                                if (nhash == 16'd43 && tb == 8'd9)
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
                                e32_poke(6'd17, {6'd0, {tb, trail_acc[7:0]}[9:0]},
                                         {54'd0, 1'b1, trail_var_slot});
                                // LOAD_VAR uses varmap slots, not intern idx (PYTHON seeds document/window)
                                if ({tb, trail_acc[7:0]} == id_document ||
                                    {tb, trail_acc[7:0]} == id_window) begin
                                    ; // p3b: dead tagged write removed (vars)
                                    e32_poke(6'd20, {7'd0, trail_var_slot}, 64'd0);
                                    ; // p3b: dead tagged write removed (var_tag)
                                    ; // p3b: dead tagged write removed (var_init)
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
                                begin cmn_we <= 1'b1; cmn_wa <= {trail_cls_i[3:0], trail_meth_i[3:0]}; cmn_wd <= {tb, trail_acc[7:0]}; end
                                e64_poke(6'd39, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                e64_p_addr2 <= {12'd0, trail_meth_i[3:0]};
                                trail_ph <= 5'd20;
                            end
                            5'd20: begin trail_acc[7:0] <= tb; trail_ph <= 5'd21; end
                            5'd21: begin
                                begin cmi_we <= 1'b1; cmi_wa <= {trail_cls_i[3:0], trail_meth_i[3:0]}; cmi_wd <= {tb, trail_acc[7:0]}; end
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
                                    hs_code(15'(ops_base));
                                    hs_st(S_FETCH_WAIT);
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
                                    hs_st(S_SPR);
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
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
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
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd4: begin fsty_n[7:0] <= tb; spr_hdr <= 3'd5; end
                                    default: begin
                                        fsty_n[15:8] <= tb;
                                        spr_hdr <= 3'd0;
                                        if ({tb, fsty_n[7:0]} == 16'd0) begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
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
                                        begin flu_we <= 1'b1; flu_wa <= fsty_name[9:0]; flu_wd <= tb; end
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
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd1, 3'd2: begin
                                        if ((spr_hdr == 3'd1 && tb == 8'h41) ||
                                            (spr_hdr == 3'd2 && tb == 8'h4D))
                                            spr_hdr <= spr_hdr + 3'd1;
                                        else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
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
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
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
                                e64_poke(6'd17, {6'd0, nb_i[9:0]},
                                         {32'd0, nb_wp, tb, trail_acc[7:0]});
                                // nb_len counts DOWN per byte, so it cannot tell a
                                // 1-char name from the last byte of a long one —
                                // that mixed whole-name ids into the char table.
                                nb_one <= ({tb, trail_acc[7:0]} == 16'd1);
                                begin nof_we <= 1'b1; nof_wa <= nb_i[9:0]; nof_wd <= nb_wp; end
                                // NEW: bytes for this id are real (fillText and
                                // str[i] both refuse hash-only ids)
                                if (nb_wp + {tb, trail_acc[7:0]} <= 16'(NAME_CAP))
                                    begin nh_we <= 1'b1; nh_wa <= nb_i[9:0]; nh_wd <= 1'b1; end
                                names_ok <= 1'b1;
                                names_static <= nb_i + 16'd1;
                                nb_static <= nb_wp;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    // empty name — nothing to copy
                                    if (nb_i + 16'd1 >= names_n) begin
                                        hs_code(15'(ops_base));
                                        hs_st(S_FETCH_WAIT);
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else trail_ph <= 6'd34;
                            end
                            6'd34: begin
                                if (nb_wp < 16'(NAME_CAP)) begin
                                    name_we <= 1'b1;
                                    name_waddr <= nb_wp[14:0];
                                    name_wdata <= tb;
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
                                        hs_code(15'(ops_base));
                                        hs_st(S_FETCH_WAIT);
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else nb_len <= nb_len - 16'd1;
                            end
                            default: begin
                                // unknown phase — do not hang HTML RUN
                                hs_code(15'(ops_base));
                                hs_st(S_FETCH_WAIT);
                            end
                        endcase
                        if (trail_ph != 5'd31 && state != S_SPR) begin
                            if (trail_off[1:0] == 2'd3) begin
                                hs_code(15'(trail_off[16:2] + 15'd1));
                                trail_off <= trail_off + 16'd1;
                                hs_st(S_RD);
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
                            hs_code(15'(ops_base));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end

                S_FETCH_WAIT: begin
                    hs_hp_env(1'b0);
                    // NEW: clear both FB banks once after header/trail, before first op
                    if (boot_clr) begin
                        color <= 8'd0;
                        clr_idx <= '0;
                        hs_st(S_CLEAR);
                    end else if (dc_arm) begin
                        // NEW: pending SET_PROP array deep copy runs between ops
                        dc_arm <= 1'b0;
                        hs_st(S_ARR_DCOPY);
                    end else if (v64_on)
                        hs_st(S_V64_EXEC);
                    else
                        hs_st(S_EXEC);
                end

                S_V64_SLICE: begin
                    // #40 Array.slice(start,end): exec pushed the result
                    // handle already; this walk copies src[start..end-1] ->
                    // dst[0..] by reference. Exec passes src/start/end/dst
                    // in hp_aid/hp_aslot/hp_lim/hp_oid (hs64-muxed).
                    if (state != S_V64_SLICE) begin
                        hs_st(S_V64_SLICE);
                        sl_src <= hp_aid;
                        sl_dst <= hp_oid[11:0];
                        sl_i <= {1'b0, hp_aslot}; // src cursor (start)
                        sl_end <= hp_lim;         // src end (exclusive)
                        sl_di <= 8'd0;            // dst cursor
                        hs_hp_phase(3'd0);
                        hs_ip(e64_ip_q);
                        hs_code(15'(ops_base + e64_ip_q));
                    end else if (hp_phase == 3'd0) begin
                        if (sl_i >= sl_end) begin
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_hp_cmd(HP_AGETI);
                            hs_hp_v64(1'b1);
                            hs_hp_aid(sl_src);
                            hs_hp_aslot(sl_i[6:0]);
                            hs_hp_alen(sl_end);
                            hs_hp_ret(S_V64_SLICE);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_WAIT);
                        end
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_v64(1'b1);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aid(sl_dst);
                        hs_hp_aslot(sl_di[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_ret(S_V64_SLICE);
                        hs_hp_phase(3'd0);
                        sl_i <= sl_i + 8'd1;
                        sl_di <= sl_di + 8'd1;
                        hs_st(S_HEAP_AWR);
                    end
                end
                S_V64_SORT: begin
                    // #41 Array.sort(cmp): bubble passes over vfe_arr.
                    // hp_phase: 0 = read a, 1 = read b, 2 = call comparator,
                    // 3 = act on cmp (exec fffc arm re-enters with phase 3
                    // and the result in vfe_map), 4 = swap writeback.
                    if (state != S_V64_SORT) begin
                        hs_st(S_V64_SORT);
                        // Same GC-root mirror as S_V64_FOREACH first-entry:
                        // a comparator-only fn/arr must survive a mid-sort
                        // GC (potential-bugs #47 discipline).
                        if (e64_vfe_sp_q > vfe_sp && vfe_sp < 4'd8) begin
                            vfe_arr_s[vfe_sp[2:0]] <= vfe_arr;
                            vfe_fn_s[vfe_sp[2:0]]  <= vfe_fn;
                            vfe_map_s[vfe_sp[2:0]] <= vfe_map;
                        end
                        vfe_arr <= e64_vfe_arr_q;
                        vfe_fn <= e64_vfe_fn_q;
                        vfe_i <= e64_vfe_i_q;
                        vfe_ret <= e64_vfe_ret_q;
                        vfe_base <= e64_vfe_base_q;
                        vfe_mode <= e64_vfe_mode_q;
                        vfe_map <= e64_vfe_map_q;
                        vfe_sp <= e64_vfe_sp_q;
                        vfe_len <= e64_vfe_len_q;
                        hs_vcsp(e64_vcsp_q);
                        if (hp_phase == 3'd0) begin
                            // fresh dispatch (not a comparator return)
                            so_j <= 8'd0;
                            so_swapped <= 1'b0;
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                        end
                    end else if (hp_phase == 3'd0) begin
                        if (so_j + 8'd1 >= e64_vfe_len_q) begin
                            if (!so_swapped) begin
                                // done: sort returns the receiver.
                                vst_wr(e64_vfe_base_q, e64_vfe_arr_q);
                                hs_vsp(e64_vfe_base_q + 12'd1);
                                hs_ip(e64_vfe_ret_q);
                                hs_code(15'(ops_base + e64_vfe_ret_q));
                                if (e64_vcsp_q != 8'd0 &&
                                    vframe_rip_rdata == 16'hfffc &&
                                    vframe_bsp_rdata ==
                                        (e64_vfe_base_q + 12'd2))
                                    hs_vcsp(e64_vcsp_q - 8'd1);
                                else
                                    hs_vcsp(e64_vcsp_q);
                                if (e64_vfe_sp_q != 4'd0) begin
                                    hs_m_vfe_pop <= 1'b1;
                                    vfe_sp <= vfe_sp - 4'd1;
                                end else begin
                                    vfe_arr <= V64_UNDEFINED;
                                    vfe_fn <= V64_UNDEFINED;
                                    vfe_mode <= 2'd0;
                                    vfe_map <= V64_UNDEFINED;
                                end
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                so_j <= 8'd0;
                                so_swapped <= 1'b0;
                            end
                        end else begin
                            hs_hp_cmd(HP_AGETI);
                            hs_hp_v64(1'b1);
                            hs_hp_aid(e64_vfe_arr_q[11:0]);
                            hs_hp_aslot(so_j[6:0]);
                            hs_hp_alen(e64_vfe_len_q);
                            hs_hp_ret(S_V64_SORT);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_WAIT);
                        end
                    end else if (hp_phase == 3'd1) begin
                        so_a <= hp_rval;
                        hs_hp_cmd(HP_AGETI);
                        hs_hp_v64(1'b1);
                        hs_hp_aid(e64_vfe_arr_q[11:0]);
                        hs_hp_aslot(7'(so_j + 8'd1));
                        hs_hp_alen(e64_vfe_len_q);
                        hs_hp_ret(S_V64_SORT);
                        hs_hp_phase(3'd2);
                        hs_st(S_HEAP_WAIT);
                    end else if (hp_phase == 3'd2) begin
                        // push fn, a, b then call the comparator (same
                        // stack shape and ALLOC reserve as S_V64_FOREACH).
                        if (!vfe_rd_arm) begin
                            so_b <= hp_rval;
                            vst_wr(vsp, e64_vfe_fn_q);
                            hs_vsp(vsp + 12'd1);
                            vfe_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            vst_wr(vsp, so_a);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd1;
                        end else if (bind_k == 8'd1) begin
                            vst_wr(vsp, so_b);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd2;
                        end else begin
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd2);
                            vcallback_fe <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_vsp(vsp);
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            hs_hp_phase(3'd0);
                            hs_st(S_V64_ALLOC);
                        end
                    end else if (hp_phase == 3'd3) begin
                        // comparator returned; result (number) in exec
                        // vfe_map. cmp > 0 -> swap.
                        if (v64_less(64'd0, e64_vfe_map_q)) begin
                            hs_hp_cmd(HP_ASETI);
                            hs_hp_v64(1'b1);
                            hs_hp_from_stack(1'b0);
                            hs_hp_aid(e64_vfe_arr_q[11:0]);
                            hs_hp_aslot(so_j[6:0]);
                            hs_hp_wval(so_b);
                            hs_hp_ret(S_V64_SORT);
                            hs_hp_phase(3'd4);
                            hs_st(S_HEAP_AWR);
                        end else begin
                            so_j <= so_j + 8'd1;
                            hs_hp_phase(3'd0);
                        end
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_v64(1'b1);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aid(e64_vfe_arr_q[11:0]);
                        hs_hp_aslot(7'(so_j + 8'd1));
                        hs_hp_wval(so_a);
                        hs_hp_ret(S_V64_SORT);
                        hs_hp_phase(3'd0);
                        so_swapped <= 1'b1;
                        so_j <= so_j + 8'd1;
                        hs_st(S_HEAP_AWR);
                    end
                end
                S_ARR_DCOPY: begin
                    // Sequential 1W1R copy. Nested child-array identity copy
                    // is a later 1-D-port walk, not a 128-wide combo.
                    // Wait one beat for varr_len_rdata / e32_arr_len_tos_rdata.
                    if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (dc_i >= ((varr_len_rdata > e32_arr_len_tos_rdata)
                            ? varr_len_rdata : e32_arr_len_tos_rdata)) begin
                        hs_hp_phase(3'd0);
                        dc_arm <= 1'b0;
                        jn_rd_arm <= 1'b0;
                        hs_st(S_EXEC);
                    end else if (hp_phase == 3'd0) begin
                        hs_hp_cmd(HP_AGETI);
                        hs_hp_v64(1'b0);
                        hs_hp_aid(dc_src);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_alen(e32_arr_len_tos_rdata);
                        hs_hp_ret(S_ARR_DCOPY);
                        hs_hp_phase(3'd1);
                        hs_st(S_HEAP_WAIT);
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_v64(1'b0);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aid(dc_dst);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_tag(hp_tag);
                        hs_hp_ret(S_ARR_DCOPY);
                        hs_hp_phase(3'd0);
                        dc_i <= dc_i + 8'd1;
                        hs_st(S_HEAP_AWR);
                    end
                end

                // S_EXEC body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                // S_NAT body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                S_CLEAR: begin
                    if (!rast_wait) begin
                        // C1: full-screen fill through the engine
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= 10'd0;
                        rast_dy <= 10'd0;
                        rast_w <= 10'(MW);
                        rast_h <= 10'(MH);
                        rast_color <= color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        if (boot_clr) begin
                            fb_swap <= 1'b1;
                            clr_idx <= '0;
                            if (boot_clr_n == 2'd1) begin
                                boot_clr <= 1'b0;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else
                                boot_clr_n <= boot_clr_n - 2'd1;
                        end else begin
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_FB_SYNC: begin
                    // Session-1: the two-bank copy-back is gone — the draw
                    // bank IS the persistent canvas. This state now only
                    // waits out the DDR3 present (fb_swap pulsed on entry;
                    // busy asserts the following beat, so arm one beat).
                    if (!fbs_armed)
                        fbs_armed <= 1'b1;
                    else if (!fb_present_busy) begin
                        fbs_armed <= 1'b0;
                        clr_idx <= '0;
                        fb_dump_sel <= 1'b0;
                        gc_ran_this_frame <= 1'b0; // C4: consume the flag
                        if (gc_ran_this_frame) begin
                            // C4: a forced GC already collected this
                            // frame -- the scheduled pass would re-walk
                            // the same heap for nothing. Cursor rewinds
                            // happened at that GC's own exit.
                            hs_st(S_WAIT_FRAME);
                        end else begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b1);
                            hs_vgc_wait_after(1'b1);
                            hs_st(S_V64_GC_CLEAR);
                        end
                    end
                end
                S_RECT: begin
                    if (rw == 10'd0 || rh == 10'd0) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!rast_wait) begin
                        // C1: engine fill at 1 px/clk (dest bounds checked
                        // per pixel in the engine — the old per-pixel clip)
                        if (dbg_rect_n < 7'd64) begin
                            `ifndef SYNTHESIS
                            dbg_rect[dbg_rect_n[5:0]] <= {color, rx, ry, rw, rh};
                            `endif // sim-only probe store
                            dbg_rect_n <= dbg_rect_n + 7'd1;
                        end
                        if (color != 8'd0)
                            dbg_rect_px <= dbg_rect_px + 32'(20'(rw) * 20'(rh));
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= rx;
                        rast_dy <= ry;
                        rast_w <= rw;
                        rast_h <= rh;
                        rast_color <= color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        // draw into back; swap once at frame end (S_WAIT_FRAME)
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
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
                            if (path_active) hs_st(S_PWALK);
                            else begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
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
                                if (qseg != 4'd0 && qseg <= 4'd8) hs_st(S_QSEG);
                                else begin
                                    qseg <= 4'd0;
                                    hs_st(S_PWALK);
                                end
                            end else begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
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
                    // (mirror write for #49 is above the case — see e64_pc_we_q)
                    // NEW: command walk (FM _raster_path) — transform each
                    // command's points with the CURRENT ctx transform
                    //
                    // potential-bugs #49 first-entry latch. Same shape as
                    // S_TXT_LD (~9350): exec64 leaves state==S_V64_EXEC on the
                    // hand-off beat, so without this the very first beat
                    // compares the parent's stale pc_n (0 after RUN) and
                    // aborts before any mirrored write is visible. The raster
                    // states are NOT in hs64, so `ip` here is the last parent
                    // hs_ip (FIND/FOREACH) — pull exec's already-incremented
                    // ip/vsp across too, or the done-path hs_code(ops_base+ip)
                    // re-fetches a stale op and re-issues fill/stroke.
                    if (state != S_PWALK) begin
                        hs_st(S_PWALK);
                        path_active <= 1'b1;
                        path_stroke <= e64_path_stroke_q;
                        pc_n <= e64_pc_n_q;
                        pi <= 5'd0;
                        color <= e64_color_q;
                        ctx_sx <= e64_ctx_sx_q;
                        ctx_sy <= e64_ctx_sy_q;
                        ctx_tx <= e64_ctx_tx_q;
                        ctx_ty <= e64_ctx_ty_q;
                        // 2026-08-25: the drawImage debug counters were
                        // never absorbed from exec64 - VMSTAT reported
                        // dihit=0/dimiss=0 forever (a dead instrument that
                        // cost a night of misdirection on DONKEY).
                        dbg_di_hit  <= e64_dbg_di_hit_q;
                        dbg_di_miss <= e64_dbg_di_miss_q;
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else if (pi >= pc_n) begin
                        path_active <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                        xf_x <= pc_a1[pi[3:0]];
                        xf_y <= pc_a2[pi[3:0]];
                        xf_w <= pc_a3[pi[3:0]];
                        xf_h <= pc_a4[pi[3:0]];
                        xf_dst <= 2'd3;
                        hs_st(S_XF_MUL);
                    end else begin
                        p1x <= (pc_a1[pi[3:0]] >>> 16) + ctx_tx;
                        p1y <= (pc_a2[pi[3:0]] >>> 16) + ctx_ty;
                        // slot2: Q end point translates; arc radius must not
                        p2x <= (pc_a3[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_tx : 32'sd0);
                        p2y <= (pc_a4[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_ty : 32'sd0);
                        hs_st(S_PDO);
                    end
                end
                S_PDO: begin
                    // flatten: arc edges wait sin_q_rdata (4 beats). Stay in
                    // S_PDO; do not bump pi until the last beat (same as the
                    // old one-cycle leave).
                    if (sin_ph != 4'd0) begin
                        // odd = wait (mux samples sin_raddr); even = consume rdata
                        if (sin_ph[0])
                            sin_ph <= sin_ph + 4'd1;
                        else if (sin_ph == 4'd2) begin
                            vs_x <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_ts;
                            sin_ph <= 4'd3;
                        end else if (sin_ph == 4'd4) begin
                            vs_y <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_te + 16'h4000;
                            sin_ph <= 4'd5;
                        end else if (sin_ph == 4'd6) begin
                            ve_x <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_te;
                            sin_ph <= 4'd7;
                        end else begin
                            ve_y <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_ph <= 4'd0;
                            pi <= pi + 5'd1;
                            hs_st(S_CIRCLE);
                        end
                    end else begin
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
                        `ifndef SYNTHESIS
                        dbg_pdo[dbg_pdo_n[3:0]] <= {14'd0, pc_op[pi[3:0]],
                            p1x[15:0], p1y[15:0], p2x[15:0], p2y[15:0]};
                        `endif // sim-only probe store
                        dbg_pdo_n <= dbg_pdo_n + 5'd1;
                    end
                    if (pc_op[pi[3:0]] == 2'd0) begin
                        pi <= pi + 5'd1;
                        cur_x <= p1x; cur_y <= p1y;
                        hs_st(S_PWALK);
                    end else if (pc_op[pi[3:0]] == 2'd1) begin
                        pi <= pi + 5'd1;
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
                        hs_st(S_LINE);
                    end else if (pc_op[pi[3:0]] == 2'd2) begin
                        // quadratic — FM subdivides into 8 line segments
                        pi <= pi + 5'd1;
                        qx0 <= cur_x; qy0 <= cur_y;
                        qcx <= p1x; qcy <= p1y;
                        qex <= p2x; qey <= p2y;
                        p2x <= cur_x; p2y <= cur_y; // prev bezier point
                        qseg <= 4'd1;
                        cur_x <= p2x; cur_y <= p2y;
                        hs_st(S_QSEG);
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
                        arc_sweep_gt_pi <= (sw > FX_PI);
                        arc_ang <= !full_arc;
                        r_ = p2x; if (r_ < 32'sd1) r_ = 32'sd1; // FM max(1, r*sx)
                        rx <= clip_u(p1x, MW); ry <= clip_u(p1y, MH);
                        rw <= clip_sz(r_, 10'd0, 512);
                        x <= clip_u(p1x - r_, MW);
                        y <= clip_u(p1y - r_, MH);
                        cur_x <= p1x; cur_y <= p1y; // FM: _path_x/_path_y = arc center
                        if (skip_arc) begin
                            pi <= pi + 5'd1;
                            hs_st(S_PWALK);
                        end else begin
                            // flatten: raddr this clock, 4× (wait + consume)
                            arc_ts <= t_s;
                            arc_te <= t_e;
                            sin_turn <= t_s + 16'h4000; // cos(start)
                            sin_ph <= 4'd1;
                        end
                    end
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
                    hs_st(S_QPX);
                end
                S_QPX: begin
                    p1x <= 32'((64'(qk1) * 64'(qx0) + 64'(qk2) * 64'(qcx) * 64'd2
                               + 64'(qk3) * 64'(qex)) >>> 16);
                    hs_st(S_QPY);
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
                    hs_st(S_LINE);
                end
                S_JOIN: begin
                    // BIND-style plant: parent jn_* is not muxed from exec.
                    if (state != S_JOIN) begin
                        hs_st(S_JOIN);
                        if (v64_on) begin
                            jn_arr <= e64_jn_arr_q;
                            jn_i <= e64_jn_i_q;
                            jn_h <= e64_jn_h_q;
                            jn_res <= e64_jn_res_q;
                            v64_join <= e64_v64_join_q;
                            cc_bok <= e64_cc_bok_q;
                            txt_bn <= e64_txt_bn_q;
                            // #54 family: JOIN_FIND's result vst_wr plants the
                            // TOS window at depth (vsp-1-jn_res) using PARENT
                            // vsp, and the completion hs_code uses PARENT ip.
                            // Without these the SRAM got the joined intern but
                            // win[0] kept the pre-written UNDEFINED —
                            // code.join('') read back undefined with
                            // joinmiss=0 (PACMAN maze wall switch).
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                    end else if (!jn_rd_arm) begin
                        // Length + long/lidx share one wait (jn_arr raddr this clock).
                        jn_rd_arm <= 1'b1;
                    end else if (!jn_slot_arm) begin
                        // flatten: slot raddr from varr_long_rdata (stale 0 = wait).
                        jn_slot_arm <= 1'b1;
                    end else if (!jn_name_arm) begin
                        // flatten: name_hash raddr = varr_rdata intern id.
                        jn_name_arm <= 1'b1;
                    end else
                    // NEW: fold single-digit elems into the encoder u16 hash
                    // (h = h*31 + '0'+d), matching jsb name interning
                    if (v64_join) begin
                        if (jn_i >= 16'({8'd0, varr_len_rdata})) begin
                            jn_i <= 16'd0;
                            jn_len <= varr_len_rdata;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            jn_name_arm <= 1'b0;
                            hs_st(S_JOIN_FIND);
                        end else begin
                            logic signed [31:0] ev;
                            logic [63:0] elem;
                            elem = varr_rdata;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            jn_name_arm <= 1'b0;
                            ev = $signed(v64_to_uint32(elem));
                            if (elem[63:48] == V64_TAG_PREFIX &&
                                elem[47:44] == 4'd4 &&
                                e32_name_len_tos == 8'd1 &&
                                name_hash_rdata[7:0] >= 8'h30 &&
                                name_hash_rdata[7:0] <= 8'h39)
                                ev = 32'(name_hash_rdata[7:0] - 8'h30);
                            if (ev < 32'sd0 || ev > 32'sd9) begin
                                dbg_join_miss <= dbg_join_miss + 16'd1;
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_join <= 1'b0;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                                if (jn_i < 16'(TXT_MAX)) begin
                                    begin txw_we <= 1'b1; txw_wa <= jn_i[5:0]; txw_wd <= 8'h30 + 8'(ev); end
                                    txt_bn <= 7'(jn_i) + 7'd1;
                                    cc_bok <= 1'b1;
                                end else cc_bok <= 1'b0;
                                jn_i <= jn_i + 16'd1;
                            end
                        end
                    end else if (jn_i >= 16'({8'd0, e32_arr_len_tos_rdata})) begin
                        jn_i <= 16'd0;
                        jn_len <= e32_arr_len_tos_rdata; // one char per digit elem
                        jn_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        jn_name_arm <= 1'b0;
                        hs_st(S_JOIN_FIND);
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
                        jn_slot_arm <= 1'b0;
                        jn_name_arm <= 1'b0;
                        if (et == 3'd3 && e32_name_len_tos == 8'd1 &&
                            name_hash_rdata[7:0] >= 8'h30 &&
                            name_hash_rdata[7:0] <= 8'h39) begin
                            // interned "0".."9" — same as number digits for maze wall codes
                            ev = 32'(name_hash_rdata[7:0] - 8'h30);
                            et = 3'd0;
                        end
                        if ((et != 3'd0 && et != 3'd7) || ev < 32'sd0 || ev > 32'sd9) begin
                            // non-digit join shape — honest miss, result undefined
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            stack_wr(jn_res, 32'sd0, 3'd5);
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                            if (jn_i < 16'(TXT_MAX)) begin
                                begin txw_we <= 1'b1; txw_wa <= jn_i[5:0]; txw_wd <= 8'h30 + 8'(ev); end
                                txt_bn <= 7'(jn_i) + 7'd1;
                                cc_bok <= 1'b1;
                            end else cc_bok <= 1'b0;
                            jn_i <= jn_i + 16'd1;
                        end
                    end
                end
                S_SQRT: begin
                    // Math.sqrt first-entry (PACMAN position2coord `offset`):
                    // exec enters directly with every seed (radicand, cursor,
                    // v64 flag) in ITS OWN FFs; the parent copies below were
                    // never written, so the loop ran on garbage, the
                    // completion took the 32-bit else (v64_sqrt parent FF
                    // stayed 0) and re-decoded the same CALL forever — the
                    // 64M frame cap burned at the splash. Same discipline as
                    // every other exec-entered state.
                    if (state != S_SQRT && v64_on && e64_leave_hold)
                    begin
                        hs_st(S_SQRT);
                        sq_rad <= e64_sq_rad_q;
                        sq_rem <= e64_sq_rem_q;
                        sq_root <= e64_sq_root_q;
                        sq_i <= e64_sq_i_q;
                        v64_sqrt <= e64_v64_sqrt_q;
                        hs_vnat_base(e64_vnat_base_q);
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else begin
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
                                hs_vsp(vnat_base + 12'd1);
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                v64_sqrt <= 1'b0;
                                hs_st(S_FETCH_WAIT);
                            end else begin
                            stack_wr(sp - 8'd1, {8'd0,
                                (rem2 >= trial) ? {sq_root[22:0], 1'b1}
                                                : {sq_root[22:0], 1'b0}}, 3'd7);
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                            end
                        end else sq_i <= sq_i - 5'd1;
                    end
                    end
                end
                S_JOIN_FIND: begin
                    // flatten: one intern slot/clock via name_hash_rdata (not a 16-CAM).
                    // Last-4 FF cache probes cached ids first (same Port A). Repeat
                    // concat must not walk names_n. CONCAT/JOIN enter with state
                    // already FIND, so plant on !jn_cache_try (overlay never runs).
                    // Miss allocates a NEW dynamic intern slot, so the same
                    // dynamic string ('s1i3') always resolves to the same id —
                    // object keys and EQ then work with no string heap.
                    if (state != S_JOIN_FIND) begin
                        hs_st(S_JOIN_FIND);
                        jn_cache_i <= 3'd0;
                        jn_cache_try <= 1'b0;
                    end else if (jn_cache_i < 3'd4 && !jn_cache_try) begin
                        // Next live cache slot, else linear from 0.
                        // Hash/len are FFs (not intern SRAM). Skip slots that
                        // cannot match; Port A still confirms the id.
                        if (jn_cache_i <= 3'd0 && jn_hit_v[0] &&
                            jn_hit_h0 == jn_h && jn_hit_l0 == jn_len) begin
                            jn_i <= jn_hit_i0;
                            jn_cache_i <= 3'd0;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd1 && jn_hit_v[1] &&
                            jn_hit_h1 == jn_h && jn_hit_l1 == jn_len) begin
                            jn_i <= jn_hit_i1;
                            jn_cache_i <= 3'd1;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd2 && jn_hit_v[2] &&
                            jn_hit_h2 == jn_h && jn_hit_l2 == jn_len) begin
                            jn_i <= jn_hit_i2;
                            jn_cache_i <= 3'd2;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd3 && jn_hit_v[3] &&
                            jn_hit_h3 == jn_h && jn_hit_l3 == jn_len) begin
                            jn_i <= jn_hit_i3;
                            jn_cache_i <= 3'd3;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else begin
                            jn_cache_i <= 3'd4;
                            jn_i <= 16'd0;
                            jn_rd_arm <= 1'b0;
                        end
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (jn_i < names_n &&
                        name_hash_rdata == jn_h &&
                        e32_name_len_tos == jn_len) begin
                        if (v64_concat || v64_join) begin
                            vst_wr(jn_res, v64_handle(
                                4'd4, 12'd0, {16'd0, jn_i}
                            ));
                            v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                        end else begin
                        stack_wr(jn_res, {16'd0, jn_i}, 3'd3);
                        end
                        jn_cache_remember(jn_i);
                        jn_cache_try <= 1'b0;
                        jn_cache_i <= 3'd0;
                        jn_rd_arm <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (jn_cache_try) begin
                        // Cached id missed — next slot, or linear from 0.
                        jn_cache_try <= 1'b0;
                        jn_rd_arm <= 1'b0;
                        if (jn_cache_i >= 3'd3) begin
                            jn_cache_i <= 3'd4;
                            jn_i <= 16'd0;
                        end else
                            jn_cache_i <= jn_cache_i + 3'd1;
                    end else if (jn_i + 16'd1 >= names_n) begin
                        jn_rd_arm <= 1'b0;
                        jn_cache_try <= 1'b0;
                        jn_cache_i <= 3'd0;
                        if (names_n < 16'd1024) begin
                            name_hash_wr(names_n[9:0], jn_h);
                            begin nlt_we <= 1'b1; nlt_wa <= names_n[9:0]; nlt_wd <= jn_len; end
                            // Same we port as trail (poke 40 then 17 next
                            // byte-copy). Indexed writes are not the SRAM we.
                            e64_poke(6'd40, {6'd0, names_n[9:0]},
                                     {48'd0, jn_h});
                            jn_cache_remember(names_n);
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, v64_handle(
                                    4'd4, 12'd0, {16'd0, names_n}
                                ));
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end else begin
                            stack_wr(jn_res, {16'd0, names_n}, 3'd3);
                            end
                            // Ring-recycle the dynamic region.
                            if (names_n + 16'd1 >= 16'd1024 &&
                                names_static != 16'd0) begin
                                names_n <= names_static;
                                nb_wp <= nb_static;
                            end else
                            names_n <= names_n + 16'd1;
                            // NEW: and its characters, staged in txt_buf by
                            // S_CONCAT — that is what makes fillText("SCORE "+n)
                            // and str[i] on a built string work at all
                            if (cc_bok && jn_len <= 8'(TXT_MAX) &&
                                ({1'b0, nb_wp} + {9'd0, jn_len}) <= 17'(NAME_CAP)) begin
                                begin nof_we <= 1'b1; nof_wa <= names_n[9:0]; nof_wd <= nb_wp; end
                                name_has[names_n[9:0]] <= 1'b1;
                                txt_i <= 7'd0;
                                hs_st(S_STR_WR);
                            end else begin
                                // Not a full table: this one string could not
                                // stage its bytes. dbg_str_ovf feeds the global
                                // fault sweep (fault 5, running <= 0), so a
                                // single `"SCORE " + score` halted the machine
                                // mid-game. Real capacity overflow (NAME_CAP,
                                // ~7266) stays fatal; this degrades to a blank
                                // string and keeps the game alive.
                                if (!cc_bok) dbg_txt_miss <= dbg_txt_miss + 16'd1;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            // intern table full — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end else begin
                            stack_wr(jn_res, 32'sd0, 3'd5);
                            end
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else begin
                        jn_i <= jn_i + 16'd1;
                        jn_rd_arm <= 1'b0;
                    end
                end
                S_CONCAT: begin
                    // NEW: JS string + — fold current operand into (cc_h, cc_len).
                    // Strings fold via h*31^len_b + h_b; ints fold decimal digits
                    // MSD-first (subtract powers of ten). Then find-or-alloc.
                    // Leave cycle: parent state is still EXEC. Pin like TXT
                    // or ADD has already decremented vsp / advanced ip and the
                    // next EXEC beat re-runs ADD with one operand (fault 1).
                    logic signed [31:0] v_;
                    logic [2:0] t_;
                    // BIND-style: plant exec stash first. Same-cycle FSM would
                    // fold parent cc_av=0 (never written) and sticky-fault 5.
                    if (state != S_CONCAT) begin
                        hs_st(S_CONCAT);
                        if (v64_on) begin
                            cc_av <= e64_cc_av_q;
                            cc_bv <= e64_cc_bv_q;
                            cc_at <= e64_cc_at_q;
                            cc_bt <= e64_cc_bt_q;
                            cc_second <= e64_cc_second_q;
                            cc_st <= e64_cc_st_q;
                            cc_h <= e64_cc_h_q;
                            cc_len <= e64_cc_len_q;
                            cc_bok <= e64_cc_bok_q;
                            cc_d <= e64_cc_d_q;
                            txt_bn <= e64_txt_bn_q;
                            jn_res <= e64_jn_res_q;
                            v64_concat <= e64_v64_concat_q;
                        end
                    end else begin
                    v_ = cc_second ? cc_bv : cc_av;
                    t_ = cc_second ? cc_bt : cc_at;
                    if (cc_st == 2'd0 && t_ == 3'd3 && !jn_rd_arm) begin
                        // flatten: name_hash / name_len raddr = intern id.
                        jn_rd_arm <= 1'b1;
                        jn_slot_arm <= 1'b0;
                    end else if (cc_st == 2'd0 && t_ == 3'd3 && !jn_slot_arm) begin
                        // flatten: pow31_rdata from e32_name_len_tos (256 ROM).
                        jn_slot_arm <= 1'b1;
                    end else if (cc_st == 2'd0) begin
                        // classify operand
                        if (t_ == 3'd3) begin
                            cc_h <= 16'(32'(cc_h) * 32'(pow31_rdata)
                                        + 32'(name_hash_rdata));
                            cc_len <= cc_len + e32_name_len_tos;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            // NEW: copy this operand's characters into txt_buf so
                            // the joined intern can be given real bytes. The
                            // hash fold above is unchanged, so ids do not move.
                            if (names_ok && e32_name_has_tos &&
                                ({1'b0, txt_bn} + {1'b0, e32_name_len_tos[6:0]})
                                    <= 8'(TXT_MAX)) begin
                                cc_cp <= e32_name_off_tos;
                                cc_cn <= e32_name_len_tos;
                                name_rdaddr <= e32_name_off_tos;
                                cc_st <= 2'd2;
                            end else begin
                                cc_bok <= 1'b0; // hash-only, as before
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'(pow31_rdata)
                                                + 32'(name_hash_rdata));
                                    jn_len <= cc_len + e32_name_len_tos;
                                    jn_i <= 16'd0;
                                    jn_rd_arm <= 1'b0;
                                    hs_st(S_JOIN_FIND);
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
                                    begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h2D; end
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
                            stack_wr(jn_res, 32'sd0, 3'd5);
                            end
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
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
                                begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h30 + {4'd0, cc_d}; end
                                txt_bn <= txt_bn + 7'd1;
                            end else cc_bok <= 1'b0;
                            if (cc_pi == 4'd0) begin
                                // operand done
                                cc_st <= 2'd0;
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                                    jn_len <= cc_len + 8'd1;
                                    jn_i <= 16'd0;
                                    hs_st(S_JOIN_FIND);
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
                                hs_st(S_JOIN_FIND);
                            end else cc_second <= 1'b1;
                        end else if (name_rdaddr == cc_cp) begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 0
                        end else begin
                            begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= name_rdata; end
                            txt_bn <= txt_bn + 7'd1;
                            cc_cn <= cc_cn - 8'd1;
                            if (cc_cn > 8'd1) name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                    end
                end
                S_IDXOF: begin
                    // NEW: arr.indexOf(v) linear scan (FM list.index twin)
                    if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (!jn_slot_arm) begin
                        // flatten: slot raddr from varr_long_rdata.
                        jn_slot_arm <= 1'b1;
                    end else if (jn_i >= 16'({8'd0, e32_arr_len_tos_rdata})) begin
                        stack_wr(jn_res, -32'sd1, 3'd0);
                        jn_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                    logic [2:0] at2;
                    logic signed [31:0] av, nv;
                    logic tag_ok;
                        at2 = varr_trdata;
                        av = $signed(varr_rdata[31:0]);
                    nv = idx_v;
                        jn_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                    // int/fx compare in the same Q16.16 domain
                    if (at2 == 3'd0 && idx_t == 3'd7) av = av <<< 16;
                    if (idx_t == 3'd0 && at2 == 3'd7) nv = nv <<< 16;
                    tag_ok = (at2 == idx_t) ||
                             ((at2 == 3'd0 || at2 == 3'd7) &&
                              (idx_t == 3'd0 || idx_t == 3'd7));
                        if (tag_ok && av == nv) begin
                        stack_wr(jn_res, {16'd0, jn_i}, 3'd0);
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
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
                    hs_st(S_XF_APPLY);
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
                        hs_st(S_PDO);
                    end else if (xf_dst == 2'd2) begin
                        // NEW: fillText pen — glyph size comes from ctx.font, and
                        // the pen may sit off-glass (centred text clips per pixel)
                        txt_px <= 16'(ix_);
                        txt_py <= 16'(iy_);
                        hs_st(S_TXT_LD);
                    end else begin
                        iw_ = trunc32(xfp_w); if (iw_ < 32'sd1) iw_ = 32'sd1;
                        ih_ = trunc32(xfp_h); if (ih_ < 32'sd1) ih_ = 32'sd1;
                        rx <= clip_u(ix_, MW); ry <= clip_u(iy_, MH);
                        rw <= clip_sz(iw_, clip_u(ix_, MW), MW);
                        rh <= clip_sz(ih_, clip_u(iy_, MH), MH);
                        x <= (xf_dst == 2'd1) ? 10'd0 : clip_u(ix_, MW);
                        y <= (xf_dst == 2'd1) ? 10'd0 : clip_u(iy_, MH);
                        hs_st((xf_dst == 2'd1) ? S_BLIT : S_RECT);
                    end
                end
                S_BLIT: begin
                    // potential-bugs #51: exec64's drawImage hit (~5838) plants
                    // rw/rh/rx/ry/blit_* in ITS OWN FFs and requests S_BLIT,
                    // but the parent copies this raster reads were never
                    // written from e64_*_q — parent rw stayed 0, so a hit was
                    // an immediate rw==0 exit with dbg_di_hit counted and zero
                    // pixels (DONKEY sheets blank, INVADERS player/explosions
                    // blank). Same overlay class as #49's S_PWALK: first-entry
                    // latch, plus hs_ip/hs_vsp because the drawImage hit does
                    // not set code_raddr_n and S_BLIT is not in hs64 — the
                    // done-path hs_code(ops_base + ip) would re-fetch a stale
                    // op otherwise.
                    if (state != S_BLIT) begin
                        // debug counters ride the blit handoff (the ctx-block
                        // sync never ran on this path - VMSTAT dihit was 0)
                        dbg_di_hit  <= e64_dbg_di_hit_q;
                        dbg_di_miss <= e64_dbg_di_miss_q;
                        hs_st(S_BLIT);
                        if (v64_on) begin
                            rw <= e64_rw_q;
                            rh <= e64_rh_q;
                            rx <= e64_rx_q;
                            ry <= e64_ry_q;
                            x <= e64_x_q;
                            y <= e64_y_q;
                            blit_si <= e64_blit_si_q;
                            blit_sx <= e64_blit_sx_q;
                            blit_sy <= e64_blit_sy_q;
                            blit_sw <= e64_blit_sw_q;
                            blit_sh <= e64_blit_sh_q;
                            blit_wait <= 1'b0;
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            bdiv_num <= e64_blit_sw_q; bdiv_den <= {6'd0, e64_rw_q};
                        end else begin
                            // legacy (non-v64) entry: parent regs already valid
                            bdiv_num <= blit_sw; bdiv_den <= {6'd0, rw};
                        end
                        dda_sx <= 16'd0; dda_ax <= 16'd0;
                        dda_sy <= 16'd0; dda_ay <= 16'd0;
                        blit_div_ph <= 2'd1;
                        bdiv_i <= 5'd15; bdiv_quo <= 16'd0; bdiv_rem <= 17'd0;
                    end else if (rw == 10'd0 || rh == 10'd0) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (blit_div_ph != 2'd0) begin
                        // 16-beat restoring divide, twice (sw/rw then sh/rh).
                        logic [16:0] btry;
                        btry = {bdiv_rem[15:0], bdiv_num[bdiv_i[3:0]]};
                        if (btry >= {1'b0, bdiv_den}) begin
                            bdiv_rem <= btry - {1'b0, bdiv_den};
                            bdiv_quo[bdiv_i[3:0]] <= 1'b1;
                        end else begin
                            bdiv_rem <= btry;
                            bdiv_quo[bdiv_i[3:0]] <= 1'b0;
                        end
                        if (bdiv_i[3:0] == 4'd0) begin
                            if (blit_div_ph == 2'd1) begin
                                bdiv_qx <= (btry >= {1'b0, bdiv_den})
                                    ? (bdiv_quo | 16'd1) : (bdiv_quo & ~16'd1);
                                bdiv_rx <= 16'((btry >= {1'b0, bdiv_den})
                                    ? (btry - {1'b0, bdiv_den}) : btry);
                                blit_div_ph <= 2'd2;
                                bdiv_i <= 5'd15; bdiv_quo <= 16'd0; bdiv_rem <= 17'd0;
                                bdiv_num <= blit_sh; bdiv_den <= {6'd0, rh};
                            end else begin
                                bdiv_qy <= (btry >= {1'b0, bdiv_den})
                                    ? (bdiv_quo | 16'd1) : (bdiv_quo & ~16'd1);
                                bdiv_ry <= 16'((btry >= {1'b0, bdiv_den})
                                    ? (btry - {1'b0, bdiv_den}) : btry);
                                blit_div_ph <= 2'd0;
                            end
                        end else bdiv_i <= bdiv_i - 5'd1;
                    end else if (!rast_wait) begin
                        // C1: the DDA walk lives in jmr_raster_engine now —
                        // one SRAM fetch per WORD (one-word cache) at core
                        // rate, ~1 clk/px instead of >=2 VM beats/px. The
                        // engine reproduces the exact floor DDA (gated by
                        // test_blit_scale_exact + the word-boundary gates).
                        rast_go <= 1'b1;
                        rast_mode <= 2'd1;
                        rast_dx <= rx;
                        rast_dy <= ry;
                        rast_w <= rw;
                        rast_h <= rh;
                        rast_sx <= blit_sx;
                        rast_sy <= blit_sy;
                        rast_qx <= bdiv_qx;
                        rast_rxr <= bdiv_rx;
                        rast_qy <= bdiv_qy;
                        rast_ryr <= bdiv_ry;
                        rast_sbase <= spr_off[blit_si[3:0]];
                        rast_stride <= spr_ww[blit_si[3:0]];
                        rast_aset <= aset_mode;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_SPR: begin
                    // copy sprite pack from code_mem trailer bytes (trail_tb).
                    // Parse the current byte EVERY cycle — including when
                    // trail_off[1:0]==3. Fetching the next word without
                    // consuming byte 3 skipped every 4th header/pixel (wrong
                    // stride / blank tiny sprites). S_TRAIL already parses
                    // then fetches; match that. NAMB follows the pixels.
                    //
                    // 2026-08-22 LUTRAM fit: sprite bytes go to the external
                    // SRAM (SPR_SRAM_BASE, one byte per word). While a write
                    // is in flight the WHOLE arm freezes (trail_off/trail_tb
                    // hold), so the byte-per-beat parse resumes exactly.
                    logic spr_end;
                    spr_end = 1'b0;
                    if (sprb_pend) begin
                        if (sram_ack) begin
                            sram_req <= 1'b0;
                            sram_we  <= 1'b0;
                            sprb_pend <= 1'b0;
                        end
                    end else
                    if (spr_left == 18'd0) begin
                        // header w/h via spr_hdr 0..3
                        if (spr_hdr == 3'd0) begin
                            trail_acc[7:0] <= trail_tb;
                            spr_hdr <= 3'd1;
                        end else if (spr_hdr == 3'd1) begin
                            // 2026-08-26 (user diff): full 16-bit width like the
                            // SPRD path - the [9:0] mask wrapped any sheet wider
                            // than 1023 px into a garbage row stride
                            // (tests/test_wide_sprite_sheets.py gate).
                            spr_ww[spr_i[3:0]] <= {trail_tb, trail_acc[7:0]};
                            spr_hdr <= 3'd2;
                        end else if (spr_hdr == 3'd2) begin
                            trail_acc[7:0] <= trail_tb;
                            spr_hdr <= 3'd3;
                        end else begin
                            spr_hh[spr_i[3:0]] <= {trail_tb, trail_acc[7:0]};
                            spr_off[spr_i[3:0]] <= 22'(spr_wp);
                            // 18-bit stream count bounds SPR-path sprites at
                            // 256K pixels; larger art rides ASET (unchanged).
                            spr_left <= 18'({trail_tb, trail_acc[7:0]}) * 18'(spr_ww[spr_i[3:0]]);
                            spr_hdr <= 3'd0;
                            if (18'({trail_tb, trail_acc[7:0]}) * 18'(spr_ww[spr_i[3:0]]) == 18'd0) begin
                                if (spr_i + 5'd1 >= n_spr) begin
                                    spr_hdr <= 3'd0;
                                    trail_ph <= 6'd35;
                                    spr_end = 1'b1;
                                end else spr_i <= spr_i + 5'd1;
                            end
                        end
                    end else begin
                        if ({1'b0, spr_wp} < 19'(SPR_BYTES)) begin
                            sram_req   <= 1'b1;
                            sram_we    <= 1'b1;
                            sram_addr  <= SPR_SRAM_BASE + 21'(spr_wp);
                            sram_wdata <= {8'd0, trail_tb};
                            sprb_pend  <= 1'b1;
                        end
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
                    if (!sprb_pend) begin
                        // byte consumed this beat — advance the stream. During
                        // a write stall the whole arm (incl. this) freezes.
                        if (trail_off[1:0] == 2'd3) begin
                            hs_code(15'(trail_off[16:2] + 15'd1));
                            trail_off <= trail_off + 16'd1;
                            hs_st(S_RD);
                            ret_state <= spr_end ? S_TRAIL : S_SPR;
                        end else begin
                            trail_off <= trail_off + 16'd1;
                            if (spr_end) hs_st(S_TRAIL);
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
                    hs_st(S_ALU_WR);
                end
                // NEW: stack write from alu_r — binary ops already did sp--
                S_ALU_WR: begin
                    stack_wr(sp - 8'd1, alu_r, alu_fx ? 3'd7 : 3'd0);
                    // fx ADD/SUB/NEG keep Q16.16; compares/NOT are plain ints
                    next_op();
                end
                // NEW: DSP multiply into mul_prod only (no stack write this cycle)
                S_MUL: begin
                    mul_prod <= 64'(mul_a) * 64'(mul_b);
                    hs_st(S_MUL_WR);
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
                        stack_wr(sp - 8'd2, 32'(p), (mul_fx_a || mul_fx_b) ? 3'd7 : 3'd0);
                    end
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
                    if (div_cnt == 6'd47) hs_st(S_DIV_FIN);
                    else div_cnt <= div_cnt + 6'd1;
                end
                S_DIV_FIN: begin
                    // Q16.16 quotient; int/int exact division stays a plain int
                    begin
                        logic [31:0] qmag;
                        qmag = (|div_uq[47:31]) ? 32'h7FFFFFFF : div_uq[31:0];
                        if (div_int_in && qmag[15:0] == 16'd0) begin
                            stack_wr(sp - 8'd2, div_neg ? -$signed({16'd0, qmag[31:16]})
                                                        : $signed({16'd0, qmag[31:16]}), 3'd0);
                        end else begin
                            stack_wr(sp - 8'd2, div_neg ? -$signed(qmag) : $signed(qmag), 3'd7);
                        end
                    end
                    sp <= sp - 8'd1;
                    next_op();
                end
                S_FOREACH: begin
                    // NEW: drain arr.forEach(fn) using frame at csp-1
                    if (csp == 0) begin
                        hs_st(S_WAIT_FRAME);
                    end else if (!vfe_rd_arm) begin
                        // Wait e32_cs1_* / arr_len rdata (raddr is next-clock).
                        vfe_rd_arm <= 1'b1;
                    end else if (e32_cs1_fe_i_rdata >= e32_arr_len_tos_rdata) begin
                        if (e32_cs1_map_arr_rdata == 16'hFFFD) begin
                            stack_wr(sp, -32'sd1, 3'd0);
                        end else if (e32_cs1_map_arr_rdata != 16'hFFFF &&
                            e32_cs1_map_arr_rdata != 16'hFFFE) begin
                            stack_wr(sp, {16'd0, e32_cs1_map_arr_rdata}, 3'd2);
                        end else begin
                            stack_wr(sp, 32'sd0, 3'd5);
                        end
                        sp <= sp + 8'd1;
                        arm_release_env(e32_cs1_env_rdata, S_FETCH_WAIT);
                        hs_ip(e32_cs1_ip_rdata);
                        this_obj <= e32_cs1_this_rdata;
                        if (this_ok) begin
                            ; // p3b: dead tagged write removed (vars)
                            ; // p3b: dead tagged write removed (var_tag)
                        end
                        cstk_pop1();
                        hs_code(15'(ops_base + e32_cs1_ip_rdata));
                        vfe_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        stack_dual_pend <= 1'b0;
                    end else if (!jn_slot_arm) begin
                        // flatten: slot raddr from varr_long_rdata.
                        jn_slot_arm <= 1'b1;
                    end else if (e32_cs1_ctorobj_rdata[7:0] >= 8'd2 &&
                                 !stack_dual_pend) begin
                        // UG901 1 write/clock: el this beat, idx next.
                        stack_wr(sp, varr_rdata[31:0], varr_trdata);
                        stack_dual_pend <= 1'b1;
                    end else begin
                        vfe_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        stack_dual_pend <= 1'b0;
                        // bind nparam args: el, then idx if the callback asked for it
                        begin
                            logic [15:0] foid;
                            logic [12:0] fo;
                            foid = e32_cs1_fe_fn_rdata;
                            fo = foid[12:0];
                            // Pass only parameters the callback declared.
                            // Always pushing `el` leaked one stack word per
                            // element for zero-argument map callbacks.
                            if (e32_cs1_ctorobj_rdata[7:0] >= 8'd2)
                                stack_wr(sp + 8'd1, {24'd0, e32_cs1_fe_i_rdata}, 3'd0);
                            else if (e32_cs1_ctorobj_rdata[7:0] >= 8'd1)
                                stack_wr(sp, varr_rdata[31:0], varr_trdata);
                            if (e32_cs1_ctorobj_rdata[7:0] >= 8'd2)
                                sp <= sp + 8'd2;
                            else if (e32_cs1_ctorobj_rdata[7:0] >= 8'd1)
                                sp <= sp + 8'd1;
                            enter_captured_fn(foid);
                            cstk_push_ret(16'hFFFE, this_obj);
                            hs_ip(e32_tfn_entry_rdata);
                            hs_code(15'(ops_base + e32_tfn_entry_rdata));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                // Overlay from exec32: parent state is still EXEC while
                // casestate is WAIT_FRAME. FRAME pulses only on parent
                // state==WAIT_FRAME — latch or tagged rAF hangs in EXEC
                // (64M cap, raf=0, ip=n_ops).
                S_WAIT_FRAME: begin
                    if (state != S_WAIT_FRAME)
                        hs_st(S_WAIT_FRAME);
                    else if (v64_on) begin
                    if (frame_tick) begin
                        v64_frame_armed <= 1'b1;
                        // KEYBITS edge capture (the tagged arm computed
                        // these; the Value64 arm never did, so a joystick
                        // press was invisible to v64 listeners).
                        joy_down_edge <= joy_in & ~prev_joy;
                        joy_up_edge <= prev_joy & ~joy_in;
                        prev_joy <= joy_in;
                        // Per-frame callback marker. dbg_cb_ip was sticky
                        // (set at the first rAF call, cleared only at RUN),
                        // so the host FRAME rpc's "callback done" break
                        // fired the moment an EVENT dispatch returned to
                        // WAIT_FRAME — every event frame ended before its
                        // own rAF ran (events and rAF never shared a
                        // frame; player_x/title_gamestate snippets, MRDO
                        // startHeld). Browser order is events THEN rAF in
                        // the same frame.
                        dbg_cb_ip <= 16'd0;
                    end
                    if (frame_tick || v64_frame_armed) begin
                        // frame_fire is set by the 32-bit GC and cleared
                        // only in the 32-bit WAIT_FRAME arm — a Value64 title
                        // never runs that arm, so a stuck flag made the host
                        // FRAME exit predicate (!frame_continue) false
                        // forever: ~1000 presents inside one RPC and a
                        // blocked GUI. Consume it on this path too.
                        frame_fire <= 1'b0;
                        // KEYBITS edges → synthetic KEYEVT on the Value64
                        // path. The tagged arm dispatched joystick edges to
                        // S_KEYEV; the Value64 arm only drained kev_q, so a
                        // physical-joystick (KEYBITS) keydown/keyup never
                        // reached v64 listeners (found by the exec32 cut:
                        // DOWNUP snippet, keyup keyCode 40). Reuse the
                        // proven kev_q dispatch below — one edge bit per
                        // frame, guarded like the tagged arm so GUI
                        // KEYEVT+KEYBITS does not double-fire. kev_q's only
                        // other writer is the KEYEVT strobe beat, which runs
                        // in its own RPC window, never during FRAME.
                        if (kev_rp == kev_wp && vlistener_n != 5'd0 &&
                            joy_down_edge != 0) begin
                            v64_frame_armed <= 1'b1;
                            jn_slot_arm <= 1'b0; // #69: restart any pending rAF snapshot
                            kev_q[kev_wp] <= {1'b1,
                                joy_down_edge[0] ? 8'd38 :
                                joy_down_edge[1] ? 8'd40 :
                                joy_down_edge[2] ? 8'd37 :
                                joy_down_edge[3] ? 8'd39 :
                                joy_down_edge[4] ? 8'd32 : 8'd13};
                            kev_wp <= kev_wp + 3'd1;
                            joy_down_edge <= 6'd0;
                        end else if (kev_rp == kev_wp && vlistener_n != 5'd0 &&
                            joy_up_edge != 0) begin
                            v64_frame_armed <= 1'b1;
                            jn_slot_arm <= 1'b0; // #69
                            kev_q[kev_wp] <= {1'b0,
                                joy_up_edge[0] ? 8'd38 :
                                joy_up_edge[1] ? 8'd40 :
                                joy_up_edge[2] ? 8'd37 :
                                joy_up_edge[3] ? 8'd39 :
                                joy_up_edge[4] ? 8'd32 : 8'd13};
                            kev_wp <= kev_wp + 3'd1;
                            joy_up_edge <= 6'd0;
                        end else
                        if (kev_rp != kev_wp) begin
                            v64_frame_armed <= 1'b1;
                            // A real KEYEVT supersedes the KEYBITS tether:
                            // the GUI sends arrows BOTH ways, and a captured
                            // joy edge that survived this dispatch converted
                            // into a SECOND synthetic arrow once the queue
                            // drained — a late ArrowRight flipped DONKEY's
                            // chosen character (Mario → Luigi) seconds into
                            // the game.
                            joy_down_edge <= 6'd0;
                            joy_up_edge <= 6'd0;
                            // #69: an event dispatch may interleave with a
                            // snapshot the previous FRAME rpc left half-done
                            // (jn_slot_arm=1, copy pending). The listener
                            // scan (S_V64_FRAME_KEY) reuses bind_k, so the
                            // resumed copy loop skipped and vraf_snap kept
                            // STALE fns — the walk then called the keyup
                            // listener as "the rAF callback" and the real
                            // tick entry was lost (queue already cleared):
                            // the game loop died after two event frames in a
                            // row. Restart the snapshot from phase 1 after
                            // the events drain.
                            jn_slot_arm <= 1'b0;
                            bind_rd_arm <= 1'b0;
                            vfe_rd_arm <= 1'b0;
                            dbg_key_alloc <= dbg_key_alloc + 16'd1;
                            hs_vnat_dom(3'd5);
                            hs_valloc_kind(2'd0);
                            hs_valloc_i(vobj_next);
                            hs_valloc_retried(1'b0);
                            hs_st(S_V64_ALLOC);
                        end else begin
                        // Stay armed until FRAME_RAF: a 1-cycle frame_tick
                        // (sim_frame_pulse / vsync) used to clear armed the
                        // same beat as jn_slot_arm, so the snapshot never
                        // finished and rAF never ran after the first present.
                        if (!jn_slot_arm) begin
                        vframe_no <= vframe_no + 32'd1;
                        vraf_snap_n <= vraf_n;
                        vraf_i <= 4'd0;
                        jn_slot_arm <= 1'b1;
                        bind_k <= 8'd0;
                        vfe_rd_arm <= 1'b0;
                        end else if (bind_k < {4'd0, vraf_n}) begin
                            if (!vfe_rd_arm)
                                vfe_rd_arm <= 1'b1;
                            else begin
                                vraf_snap[bind_k[2:0]] <= vraf_rdata;
                                bind_k <= bind_k + 8'd1;
                                vfe_rd_arm <= 1'b0;
                            end
                        end else begin
                        v64_frame_armed <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        bind_k <= 8'd0;
                        vfe_rd_arm <= 1'b0;
                        hs_vraf_n(4'd0);
                        hs_st(S_V64_FRAME_RAF);
                        end
                        end
                    end
                end else if (frame_tick || v64_frame_armed) begin
                    // flatten: one to_delay slot/clock (not 64 SRAM ports).
                    if (frame_tick && !v64_frame_armed) begin
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
                        v64_frame_armed <= 1'b1;
                        bind_k <= 8'd0;
                        jn_rd_arm <= 1'b0;
                    end else if (bind_k < 8'(TIMER_DEPTH) &&
                                 bind_k < {1'b0, to_n}) begin
                        if (!jn_rd_arm)
                            jn_rd_arm <= 1'b1;
                        else begin
                            if (e32_to_delay_rdata != 12'd0)
                                to_delay[bind_k[5:0]] <=
                                    e32_to_delay_rdata - 12'd1;
                            bind_k <= bind_k + 8'd1;
                            jn_rd_arm <= 1'b0;
                        end
                    end else begin
                    v64_frame_armed <= 1'b0;
                    jn_rd_arm <= 1'b0;
                    bind_k <= 8'd0;
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
                    hs_st(S_GC_CLEAR);
                    // KEYBITS level → keys.a/d/space.pressed (HTML table the animate() reads)
                    if (keys_ok) begin
                        poke_pressed(id_a, joy_in[2]);
                        poke_pressed(id_d, joy_in[3]);
                        poke_pressed(id_kspace, joy_in[4]);
                    end
                    if (enter_n != 0 && enter_delay != 0)
                        enter_delay <= enter_delay - 4'd1;
                    end
                    end else if (frame_fire) begin
                    frame_fire <= 1'b0;
                    // KEYBITS edges → keydown/keyup with event.key + keyCode (HTML bindings)
                    // Skip when a KEYEVT is queued so GUI KEYEVT+KEYBITS does not double-fire.
                    if (kd_fn != 16'hFFFF && joy_down_edge != 0 && kev_rp == kev_wp) begin
                        joy_down_edge <= 6'd0;
                        ; // p3b: dead tagged write removed (obj_n)
                        ; // p3b: dead tagged write removed (obj_cls)
                        // heap slots via S_HEAP_* (OSETI) — tagged KEYBITS path
                        // NEW: frame boundary — reset the eval stack (leftovers
                        // are leaks; ~1 word/frame overflowed sp at ~500 frames)
                        stack_wr(0, {16'd0, n_obj}, 3'd1);
                        boundary_sp(11'd1);
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= kd_fn;
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= 1'b1;
                        kev_ret_ip <= n_ops;
                        cstk_arm_frame(16'hFFFD, this_obj);
                        // S_KEYEV: env alloc next cycle so it cannot clobber the event
                        hs_st(S_KEYEV);
                    end else if (ku_fn != 16'hFFFF && joy_up_edge != 0 && kev_rp == kev_wp) begin
                        joy_up_edge <= 6'd0;
                        ; // p3b: dead tagged write removed (obj_n)
                        // heap slots via S_HEAP_* (OSETI) — tagged KEYBITS path
                        stack_wr(0, {16'd0, n_obj}, 3'd1);
                        boundary_sp(11'd1);
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= ku_fn;
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= 1'b0;
                        kev_ret_ip <= n_ops;
                        cstk_arm_frame(16'hFFFD, this_obj);
                        hs_st(S_KEYEV);
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
                        ; // p3b: dead tagged write removed (obj_n)
                        ; // p3b: dead tagged write removed (obj_cls)
                        hs_hp_cmd(HP_OSETI);
                        hs_hp_v64(1'b0);
                        hs_hp_oid(n_obj[12:0]);
                        hs_hp_slot(5'd0);
                        hs_hp_qn(3'd2);
                        hs_hp_qi(3'd0);
                        hp_qk_ff[0] <= id_key;
                        hs_m_hp_qk <= 1'b1;
                        hp_qv_ff[0] <= {48'd0,
                            (kev_q[kev_rp][7:0] == 8'd13) ? id_enter :
                            (kev_q[kev_rp][7:0] == 8'd32) ? id_space :
                            (kev_q[kev_rp][7:0] == 8'd37) ? id_arrow_l :
                            (kev_q[kev_rp][7:0] == 8'd39) ? id_arrow_r :
                            (kev_q[kev_rp][7:0] == 8'd38) ? id_arrow_u :
                            (kev_q[kev_rp][7:0] == 8'd40) ? id_arrow_d :
                            (kev_q[kev_rp][7:0] == 8'd65) ? id_a :
                            (kev_q[kev_rp][7:0] == 8'd68) ? id_d :
                            (kev_q[kev_rp][7:0] == 8'd87) ? id_w :
                            (kev_q[kev_rp][7:0] == 8'd83) ? id_s :
                            (kev_q[kev_rp][7:0] == 8'd80) ? id_p : 16'hFFFF};
                        hs_m_hp_qv <= 1'b1;
                        // potential-bugs #15: the id ternary above already
                        // resolves 87/83/80 (w/s/p), but this tag list did
                        // not, so `e.key` for those three carried type 5
                        // (undefined) and DONKEY's WASD / pause compares
                        // never matched on the tagged path. Same set as the
                        // Value64 KEYEVT intern (~10704).
                        hp_qt_ff[0] <= ((kev_q[kev_rp][7:0] == 8'd13) ||
                            (kev_q[kev_rp][7:0] == 8'd32) ||
                            (kev_q[kev_rp][7:0] == 8'd37) ||
                            (kev_q[kev_rp][7:0] == 8'd39) ||
                            (kev_q[kev_rp][7:0] == 8'd38) ||
                            (kev_q[kev_rp][7:0] == 8'd40) ||
                            (kev_q[kev_rp][7:0] == 8'd65) ||
                            (kev_q[kev_rp][7:0] == 8'd87) ||
                            (kev_q[kev_rp][7:0] == 8'd83) ||
                            (kev_q[kev_rp][7:0] == 8'd80) ||
                            (kev_q[kev_rp][7:0] == 8'd68)) ? 3'd3 : 3'd5;
                        hs_m_hp_qt <= 1'b1;
                        hp_qk_ff[1] <= id_keycode;
                        hs_m_hp_qk <= 1'b1;
                        hp_qv_ff[1] <= {56'd0, kev_q[kev_rp][7:0]};
                        hs_m_hp_qv <= 1'b1;
                        hp_qt_ff[1] <= 3'd0;
                        hs_m_hp_qt <= 1'b1;
                        hs_hp_ret(S_KEYEV);
                        stack_wr(0, {16'd0, n_obj}, 3'd1);
                        boundary_sp(11'd1);
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        kev_fn <= kev_q[kev_rp][8] ? kd_fn : ku_fn;
                        kev_li <= 2'd0;
                        kev_obj <= n_obj;
                        kev_is_down <= kev_q[kev_rp][8];
                        kev_ret_ip <= n_ops;
                        cstk_arm_frame(16'hFFFD, this_obj);
                        hs_st(S_HEAP_WR);
                    end else if (raf_n != 0) begin
                        boundary_sp(11'd0); // frame boundary: checked eval stack
                        hs_ip(fn_entry(e32_raf_fn_rdata));
                        raf_n <= raf_n - 4'd1;
                        enter_captured_fn(e32_raf_fn_rdata);
                        raf_fn[0] <= e32_raf_tap1;
                        raf_fn[1] <= e32_raf_tap2;
                        raf_fn[2] <= e32_raf_tap3;
                        raf_fn[3] <= e32_raf_tap4;
                        raf_fn[4] <= e32_raf_tap5;
                        raf_fn[5] <= e32_raf_tap6;
                        raf_fn[6] <= e32_raf_tap7;
                        cstk_push_ret(n_ops, this_obj);
                        hs_code(15'(ops_base + fn_entry(e32_raf_fn_rdata)));
                        hs_st(S_FETCH_WAIT);
                    end else if (looping) begin
                        hs_ip('0);
                        boundary_sp(11'd0);
                        hs_code(15'(ops_base));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        hs_ip(n_ops);
                        hs_code(15'(ops_base));
                        hs_st(S_FETCH_WAIT);
                    end
                end else if (vt_found) begin
                    // flatten: compact one timer slot/clock (not 64 SRAM ports).
                    if ({1'b0, bind_k} + 9'd1 < {2'd0, to_n}) begin
                        if (!jn_rd_arm)
                            jn_rd_arm <= 1'b1;
                        else begin
                            to_fn[bind_k[5:0]] <= e32_to_fn_rdata;
                            if (bind_k[5:0] == 6'd0)
                                to_fn0 <= e32_to_fn_rdata;
                            to_delay[bind_k[5:0]] <= e32_to_delay_rdata;
                            to_period[bind_k[5:0]] <= e32_to_period_rdata;
                            to_id[bind_k[5:0]] <= e32_to_id_rdata;
                            bind_k <= bind_k + 8'd1;
                            jn_rd_arm <= 1'b0;
                        end
                    end else begin
                        if (vk_found) begin
                            to_fn[to_n - 7'd1] <= to_fire_fn;
                            if (to_n == 7'd1)
                                to_fn0 <= to_fire_fn;
                            to_delay[to_n - 7'd1] <= vt_best_due[11:0];
                            to_period[to_n - 7'd1] <= vt_best_due[11:0];
                            to_id[to_n - 7'd1] <= to_fire_id;
                        end else
                            to_n <= to_n - 7'd1;
                        vt_found <= 1'b0;
                        vk_found <= 1'b0;
                        bind_k <= 8'd0;
                        jn_rd_arm <= 1'b0;
                        if (vt_pick[6]) begin
                            dbg_tmr_fire <= dbg_tmr_fire + 16'd1;
                            boundary_sp(11'd0);
                            hs_ip(e32_tfn_entry_rdata);
                            enter_captured_fn(to_fire_fn);
                            cstk_push_ret(n_ops, this_obj);
                            hs_code(15'(ops_base + e32_tfn_entry_rdata));
                            hs_st(S_FETCH_WAIT);
                        end
                        to_fire_fn <= 16'd0;
                        to_fire_id <= 16'd0;
                    end
                end else if (to_n != 0) begin
                    // flatten: wait to_delay[0] rdata; never peek.
                    if (!vfe_rd_arm)
                        vfe_rd_arm <= 1'b1;
                    else if (e32_to_delay_rdata == 12'd0) begin
                        logic fn_ok;
                        fn_ok = (e32_obj_cls_rdata == CLS_FN);
                        vfe_rd_arm <= 1'b0;
                        to_fire_fn <= e32_to_fn_rdata;
                        to_fire_id <= e32_to_id_rdata;
                        vt_best_due <= {20'd0, e32_to_period_rdata};
                        vt_pick[6] <= fn_ok;
                        if (!fn_ok) dbg_tmr_mis <= dbg_tmr_mis + 16'd1;
                        if (fn_ok && e32_to_period_rdata != 12'd0 &&
                            to_n == 7'd1) begin
                            to_delay[0] <= e32_to_period_rdata;
                            dbg_tmr_fire <= dbg_tmr_fire + 16'd1;
                            boundary_sp(11'd0);
                            hs_ip(e32_tfn_entry_rdata);
                            enter_captured_fn(e32_to_fn_rdata);
                            cstk_push_ret(n_ops, this_obj);
                            hs_code(15'(ops_base + e32_tfn_entry_rdata));
                            hs_st(S_FETCH_WAIT);
                            to_fire_fn <= 16'd0;
                        end else begin
                            vk_found <= fn_ok && (e32_to_period_rdata != 12'd0);
                            vt_found <= 1'b1;
                            bind_k <= 8'd0;
                            jn_rd_arm <= 1'b0;
                        end
                    end else
                        vfe_rd_arm <= 1'b0;
                end
                end
                S_KEYEV: begin
                    // Event object was allocated last cycle (n_obj already bumped).
                    // flatten: tfn_* / obj_n raddr = kev_fn this clock.
                    if (!tfn_rd_arm)
                        tfn_rd_arm <= 1'b1;
                    else begin
                    enter_captured_fn(kev_fn);
                    if (cs_pend_valid)
                        cstk_win_shift_push(cs_pend_ip, cs_pend_this, 1'b0, 1'b0);
                    cs_pend_valid <= 1'b0;
                    bump_csp();
                    hs_ip(e32_tfn_entry_rdata);
                    hs_code(15'(ops_base + e32_tfn_entry_rdata));
                    tfn_rd_arm <= 1'b0;
                    hs_st(S_FETCH_WAIT);
                    end
                end
                S_ENV_LOAD: begin
                    // Sequential env slot walk (registered SRAM). Parent is
                    // 1-D tenv_parent, not a combo vobj_slot[VOBJ_AW'({eo, 5'(0)})][63:0] mux.
                    if (hp_phase == 3'd0) begin
                        hs_hp_phase(3'd1);
                    end else if (hp_slot < e32_obj_n_rdata) begin
                        if (vobj_rdata[79:64] == {7'd0, env_ld_slot}) begin
                                if (env_is_store) begin
                                hs_hp_cmd(HP_OSETI);
                                hs_hp_v64(1'b0);
                                hs_hp_oid(env_walk[12:0]);
                                hs_hp_qn(3'd1);
                                hs_hp_qi(3'd0);
                                hp_qk_ff[0] <= {7'd0, env_ld_slot};
                                hs_m_hp_qk <= 1'b1;
                                hp_qv_ff[0] <= {32'd0, e32_stack_rdata};
                                hs_m_hp_qv <= 1'b1;
                                hp_qt_ff[0] <= e32_stack_tag_rdata;
                                hs_m_hp_qt <= 1'b1;
                                hs_hp_tag(e32_stack_tag_rdata);
                                sp <= sp - 8'd1;
                                hs_hp_ret(S_FETCH_WAIT);
                                hs_code(15'(ops_base + ip));
                                hs_st(S_HEAP_WR);
                                end else begin
                                stack_wr(sp, vobj_rdata[31:0], vobj_trdata);
                                sp <= sp + 8'd1;
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            hs_hp_slot(hp_slot + 5'd1);
                            hs_hp_phase(3'd0);
                        end
                    end else if (e32_tenv_parent_rdata != 16'd0 &&
                                 e32_tenv_parent_rdata != env_walk) begin
                        env_walk <= e32_tenv_parent_rdata;
                        hs_hp_slot(5'd1);
                        hs_hp_phase(3'd0);
                        end else begin
                            if (env_is_store) begin
                                ; // p3b: dead tagged write removed (vars)
                                ; // p3b: dead tagged write removed (var_tag)
                                ; // p3b: dead tagged write removed (var_init)
                                sp <= sp - 8'd1;
                            end else begin
                                stack_wr(sp, e32_vars_rdata, e32_var_tag_rdata);
                                sp <= sp + 8'd1;
                            end
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                    end
                end
                S_JSON: begin
                    // V1 JSON-engine removal (2026-08-23): the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_JSON_PARSE: begin
                    // V1 JSON-engine removal (2026-08-23): the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_REPL: begin
                    if (json_rp >= json_src + json_srclen) begin
                        if (v64_repl) begin
                            if (!vfree_armed) begin
                                vfree_armed <= 1'b1;
                                hs_valloc_i(14'd0);
                                hs_hp_ret(S_REPL);
                                hs_st(S_FREE_OBJ);
                            end else begin
                                vfree_armed <= 1'b0;
                                v64_repl <= 1'b0;
                                if (vfree_ok) begin
                                    vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd7;
                                    begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd7, 2'd0, 6'd2});
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= 16'd0;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number({18'd0, json_wp});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= 16'd1;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(
                                        {18'd0, json_dst - json_wp});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd5, vobj_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    hs_vsp(vnat_base + 12'd1);
                                    vobj_next <= valloc_i + 14'd1;
                                    hs_code(15'(ops_base + ip));
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end
                            end
                        end else begin
                        ; // p3b: dead tagged write removed (obj_cls)
                        ; // p3b: dead tagged write removed (obj_n)
                        hs_hp_cmd(HP_OSETI);
                        hs_hp_v64(1'b0);
                        hs_hp_oid(n_obj[12:0]);
                        hs_hp_slot(5'd0);
                        hs_hp_qn(3'd2);
                        hs_hp_qi(3'd0);
                        hp_qk_ff[0] <= 16'd0;
                        hs_m_hp_qk <= 1'b1;
                        hp_qv_ff[0] <= {50'd0, json_wp};
                        hs_m_hp_qv <= 1'b1;
                        hp_qt_ff[0] <= 3'd0;
                        hs_m_hp_qt <= 1'b1;
                        hp_qk_ff[1] <= 16'd1;
                        hs_m_hp_qk <= 1'b1;
                        hp_qv_ff[1] <= {50'd0, json_dst - json_wp};
                        hs_m_hp_qv <= 1'b1;
                        hp_qt_ff[1] <= 3'd0;
                        hs_m_hp_qt <= 1'b1;
                        stack_wr(json_res, {16'd0, n_obj}, 3'd1);
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= json_res + 11'd1;
                        hs_code(15'(ops_base + ip));
                        hs_hp_ret(S_FETCH_WAIT);
                        hs_st(S_HEAP_WR);
                        end
                    end else if (!vjs_rd_arm) begin
                        vjs_rd_arm <= 1'b1;
                    end else if (repl_nlen > 8'd1 && !jn_name_arm) begin
                        json_ch0 <= json_mem_rdata;
                        jn_name_arm <= 1'b1;
                    end else begin
                        logic match;
                        logic [7:0] ch0;
                        ch0 = (repl_nlen > 8'd1) ? json_ch0 : json_mem_rdata;
                        match = (ch0 == repl_pat0) &&
                            (repl_nlen <= 8'd1 ||
                             (json_rp + 14'd1 < json_src + json_srclen &&
                              json_mem_rdata == repl_pat1));
                        vjs_rd_arm <= 1'b0;
                        jn_name_arm <= 1'b0;
                        if (match && (repl_g || !repl_did) && json_dst < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_dst[12:0];
                            json_wdata <= repl_rch;
                            json_dst <= json_dst + 14'd1;
                            json_rp <= json_rp + ((repl_nlen <= 8'd1) ? 14'd1 : 14'(repl_nlen));
                            repl_did <= 1'b1;
                        end else if (json_dst < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_dst[12:0];
                            json_wdata <= ch0;
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
                    if (state != S_STR_WR)
                        hs_st(S_STR_WR);
                    // NEW: append the staged characters of a joined string to
                    // name_mem. names_n was bumped in S_JOIN_FIND, so the id
                    // being filled in is names_n-1.
                    if (txt_i >= 7'(jn_len)) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!jn_rd_arm) begin
                        // flatten: txt_buf_rdata, then char_ok[txt_buf_rdata]
                        jn_rd_arm <= 1'b1;
                        jn_slot_arm <= 1'b0;
                    end else if (!jn_slot_arm) begin
                        jn_slot_arm <= 1'b1;
                    end else begin
                        jn_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        // Cycle after JOIN_FIND poke 40: fill name_blen/off
                        // on the same we port as trail NAMB.
                        if (txt_i == 7'd0)
                            e64_poke(6'd17, {6'd0, (names_n - 16'd1)},
                                     {32'd0, nb_wp, 8'd0, jn_len});
                        name_we <= 1'b1;
                        name_waddr <= nb_wp[14:0];
                        name_wdata <= txt_buf_rdata;
                        if (jn_len == 8'd1 && !e32_char_ok_rdata) begin
                            char_id[txt_buf_rdata] <= names_n - 16'd1;
                            char_ok[txt_buf_rdata] <= 1'b1;
                        end
                        nb_wp <= nb_wp + 16'd1;
                        txt_i <= txt_i + 7'd1;
                    end
                end
                S_FONTPX: begin
                    // NEW: ctx.font size. Walk the string for the first digit run
                    // that is followed by 'p' — the same first-match the FM regex
                    // (\d+)\s*px takes, so '12px/20px' and 'bold 24px X' agree.
                    // Value64 entry (the only live one): exec parsed nothing —
                    // it parks the font string's intern id in its hp_key copy
                    // and settles stack/ip before requesting this state.
                    // BIND-style first-entry seed from exec regs (hp_key is
                    // NOT hs64-muxed here).
                    if (state != S_FONTPX && v64_on && e64_leave_hold) begin
                        hs_st(S_FONTPX);
                        name_rdaddr <= name_off_r3[e64_hp_key_q[9:0]];
                        fp_left <= name_blen_r1[e64_hp_key_q[9:0]][7:0];
                        txt_ph <= 4'd0;
                        fpx_acc <= 8'd0;
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else
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
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            fp_left <= fp_left - 8'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                end
                S_TXT_LD: begin
                    // Leave cycle: parent state is still EXEC. Pin like RECT
                    // / ALLOC or exec re-issues POP (DONKEY/INVADERS fillText
                    // eip=next, fault 1, vsp already collapsed).
                    if (state != S_TXT_LD) begin
                        hs_st(S_TXT_LD);
                        // BIND-style: parent txt_* is not muxed from exec.
                        if (v64_on) begin
                            txt_val <= e64_txt_val_q;
                            txt_vt <= e64_txt_vt_q;
                            txt_px <= e64_txt_px_q;
                            txt_py <= e64_txt_py_q;
                            txt_ph <= e64_txt_ph_q;
                            txt_bn <= e64_txt_bn_q;
                            color <= e64_color_q;
                        end
                    end else begin
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
                            if (txt_vt == 3'd3 && names_ok && e32_name_has_tos) begin
                                nl = e32_name_len_tos;
                                txt_len <= (nl > 8'(TXT_MAX)) ? 7'(TXT_MAX) : 7'(nl);
                                name_rdaddr <= e32_name_off_tos;
                                txt_ph <= (nl == 8'd0) ? 4'd6 : 4'd2;
                            end else if (txt_vt == 3'd1 &&
                                         e32_obj_cls_rdata == CLS_DYNSTR) begin
                                hs_hp_cmd(HP_OGETI);
                                hs_hp_v64(1'b0);
                                hs_hp_oid(txt_val[12:0]);
                                hs_hp_slot(5'd0);
                                hs_hp_qn(3'd2);
                                hs_hp_qi(3'd0);
                                hs_hp_nat(4'd9);
                                hs_hp_ret(S_V64_OGETI_NAT);
                                hs_st(S_HEAP_WAIT);
                            end else if (txt_vt == 3'd0 || txt_vt == 3'd7) begin
                                logic signed [31:0] iv;
                                iv = fxi(txt_val, txt_vt);
                                if (iv < 0) begin
                                    begin txw_we <= 1'b1; txw_wa <= 6'd0; txw_wd <= 8'h2D; end // '-'
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
                                dbg_txt_miss <= dbg_txt_miss + 16'd1;
                                txt_ph <= 4'd6;
                            end
                        end
                        4'd2: begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 1
                            txt_ph <= 4'd3;
                        end
                        4'd3: begin
                            begin txw_we <= 1'b1; txw_wa <= txt_i[5:0]; txw_wd <= name_rdata; end
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                name_rdaddr <= name_rdaddr + 16'd1;
                            end
                        end
                        4'd4: begin
                            if (!vjs_rd_arm)
                                vjs_rd_arm <= 1'b1;
                            else begin
                            begin txw_we <= 1'b1; txw_wa <= txt_i[5:0]; txw_wd <= json_mem_rdata; end
                            vjs_rd_arm <= 1'b0;
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                txt_rp <= txt_rp + 16'd1;
                            end
                            end
                        end
                        4'd5: begin
                            // MSD-first digits (no divider): subtract P10 and count
                            if (txt_v >= 32'(P10[txt_pi])) begin
                                txt_v <= txt_v - 32'(P10[txt_pi]);
                                txt_d <= txt_d + 4'd1;
                            end else begin
                                begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h30 + {4'd0, txt_d}; end
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
                            dbg_txtw <= w_;
                            dbg_txt_n <= dbg_txt_n + 16'd1;
                            txt_x0 <= txt_px - ((ctx_align_eff == 2'd1) ? 16'($signed(w_) >>> 1)
                                             : (ctx_align_eff == 2'd2) ? 16'($signed(w_))
                                             : 16'sd0);
                            // #37 textBaseline: top = y; middle = y - 4k;
                            // bottom/alphabetic = y - 8k (today's default).
                            txt_y0 <= txt_py -
                                ((v64_on && e64_ctx_baseline_q == 2'd1)
                                    ? 16'sd0
                                 : (v64_on && e64_ctx_baseline_q == 2'd2)
                                    ? 16'(4 * {12'd0, txt_k})
                                    : 16'(8 * {12'd0, txt_k}));
                            if (txt_len == 7'd0) begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else if (txt_ph == 4'd6) begin
                                // flatten: txt_i=0 then wait txt_buf_rdata
                                txt_i <= 7'd0;
                                txt_ph <= 4'd7;
                            end else if (txt_ph == 4'd7) begin
                                txt_ph <= 4'd8;
                            end else begin
                                font_raddr <= {txt_buf_rdata[6:0], 3'd0};
                                txt_i <= 7'd0; txt_row <= 3'd0; txt_col <= 3'd0;
                                txt_kx <= 4'd0; txt_ky <= 4'd0;
                                txt_ph <= 4'd0;
                                hs_st(S_TXT_DRAW);
                            end
                        end
                    endcase
                    end
                end
                S_TXT_DRAW: begin
                    if (state != S_TXT_DRAW)
                        hs_st(S_TXT_DRAW);
                    // NEW: 8x8 glyph raster, one pixel per cycle, scaled k*k.
                    // Set bits only (transparent background, like FM fill_text).
                    if (txt_ph == 4'd4)
                        txt_ph <= 4'd5; // wait txt_buf_rdata of new txt_i
                    else if (txt_ph == 4'd5) begin
                        font_raddr <= {txt_buf_rdata[6:0], 3'd0};
                        txt_ph <= 4'd0;
                    end else if (txt_ph == 4'd0) txt_ph <= 4'd1; // font_rom read latency
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
                                font_raddr <= {txt_buf_rdata[6:0], txt_row + 3'd1};
                                txt_ph <= 4'd0;
                            end else if (txt_i + 7'd1 >= txt_len) begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                txt_i <= txt_i + 7'd1;
                                txt_row <= 3'd0;
                                txt_ph <= 4'd4;
                            end
                        end
                    end
                end
                S_NAMCPY: begin
                    // interned name_mem → json_mem via registered name_rdata
                    // (same BRAM lag as str[i]; do not combinational-read NAME_CAP).
                    //
                    // potential-bugs #54: first-entry hs_st + seed copy, same
                    // class as #53. exec enters this state directly (JSON.parse
                    // of an interned string, replace, indexOf) but every seed
                    // it computed (name_rdaddr, json_src/srclen/rp/wp, pph,
                    // js_sp, namcpy_v64/repl) lives in EXEC's FFs; this arm
                    // reads the PARENT FFs, which nothing ever wrote. Parse of
                    // a constant string copied garbage and faulted 1 at the
                    // next LET_VAR (site 3423). The hs_st also stops exec
                    // re-running the CALL_NATIVE while the copy walks.
                    if (casestate_q != S_NAMCPY) begin
                        hs_st(S_NAMCPY);
                        if (v64_on) begin
                            name_rdaddr <= e64_name_rdaddr_q;
                            json_src    <= e64_json_src_q;
                            json_srclen <= e64_json_srclen_q;
                            json_rp     <= e64_json_rp_q;
                            json_wp     <= e64_json_wp_q;
                            json_pph    <= e64_json_pph_q;
                            js_sp       <= e64_js_sp_q;
                            namcpy_v64  <= e64_namcpy_v64_q;
                            namcpy_repl <= e64_namcpy_repl_q;
                            // String.replace parent latches (PACMAN ghost
                            // AI: stringify(...).replace(/2/g,0)): v64_repl
                            // and repl_rch only ever lived in EXEC's FFs, so
                            // the S_REPL completion took the 32-BIT dynstr
                            // path (pushed onto the wrong stack — the result
                            // read back 0.0 / undefined). repl_pat0==0 means
                            // "pattern is a RegExp object" — those fields
                            // were parent-written by the nat=5 read; do not
                            // clobber them.
                            v64_repl <= e64_v64_repl_q;
                            repl_rch <= e64_repl_rch_q;
                            repl_did <= 1'b0;
                            if (e64_repl_pat0_q != 8'd0) begin
                                repl_pat0 <= e64_repl_pat0_q;
                                repl_pat1 <= 8'd0;
                                repl_nlen <= 8'd1;
                                repl_g <= e64_repl_g_q;
                            end

                            // completion branches read hp_nat (indexOf) and
                            // hp_wval (needle); NAMCPY is not in hs64 so the
                            // muxes fall back to the parent _ff copies.
                            hs_hp_nat(e64_hp_nat_q);
                            hs_hp_wval(e64_hp_wval_q);
                            hs_vnat_base(e64_vnat_base_q);
                            // completion chains end with hs_code(ops_base+ip)
                            // — parent ip must be exec's, not a stale hs_ip.
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                        namcpy_armed <= 1'b0;
                    end
                    else if (!namcpy_armed) namcpy_armed <= 1'b1;
                    else begin
                        if (json_wp < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_wp[12:0];
                            json_wdata <= name_rdata;
                        end
                        if (json_wp + 14'd1 >= json_srclen || json_wp + 14'd1 >= 14'(JSON_CAP)) begin
                            json_src <= 14'd0;
                            json_rp <= 14'd0;
                            namcpy_armed <= 1'b0;
                            if (namcpy_v64) begin
                                namcpy_v64 <= 1'b0;
                                json_wp <= 14'd0;
                                hs_st(S_V64_JSON_PARSE);
                            end else if (namcpy_repl) begin
                                json_dst <= json_srclen;
                                json_wp <= json_srclen;
                                hs_st(S_REPL);
                            end else if (hp_nat == 4'd3) begin
                                // interned indexOf: name_mem was copied 1 byte/clock
                                json_src <= 14'd0;
                                json_rp <= 14'd0;
                                json_wp <= 14'd0;
                                idx_needle <= hp_wval[7:0];
                                hs_st(S_IDXSTR);
                            end else begin
                                json_wp <= 14'd0;
                                hs_st(S_JSON_PARSE);
                            end
                        end else begin
                            json_wp <= json_wp + 14'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                            namcpy_armed <= 1'b0;
                        end
                    end
                end
                S_STRIDX: hs_st(S_STRIDX_WR); // wait: name_rdata lags name_rdaddr 1 cycle
                S_STRIDX_WR: begin
                    // name_rdata is this char. Prefetch i+1 so the next sequential
                    // str[i] hits in EXEC (string-row sprites: row[col]==="1").
                    if (e32_char_ok_rdata) begin
                        stack_wr(str_res, {16'd0, e32_char_id_rdata}, 3'd3);
                    end else begin
                        stack_wr(str_res, 32'sd0, 3'd5);
                    end
                    name_rdaddr <= name_rdaddr + 16'd1;
                    str_pf_ci <= str_pf_ci + 32'sd1;
                    str_pf_ok <= 1'b1;
                    hs_code(15'(ops_base + ip));
                    hs_st(S_FETCH_WAIT);
                end
                S_IDXSTR: begin
                    // Value64 dynstr indexOf (hp_v64) writes the IEEE index;
                    // tagged CPU keeps json_res. One json_mem byte/clock.
                    if (json_rp >= json_src + json_srclen) begin
                        if (hp_v64) begin
                            vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                            hs_vsp(hp_vbase + 12'd1);
                        end else begin
                            stack_wr(json_res, -32'sd1, 3'd0);
                            sp <= json_res + 11'd1;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!vjs_rd_arm) begin
                        vjs_rd_arm <= 1'b1;
                    end else if (json_mem_rdata == idx_needle) begin
                        vjs_rd_arm <= 1'b0;
                        if (hp_v64) begin
                            vst_wr(hp_vbase,
                                v64_int32_number(32'(json_rp - json_src)));
                            hs_vsp(hp_vbase + 12'd1);
                        end else begin
                            stack_wr(json_res, 32'(json_rp - json_src), 3'd0);
                            sp <= json_res + 11'd1;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        vjs_rd_arm <= 1'b0;
                        json_rp <= json_rp + 14'd1;
                    end
                end
                S_IMGD_GET: begin
                    // #54: exec-direct entry (getImageData — PACMAN's maze
                    // cache). All imgd_* seeds live in exec FFs; this arm read
                    // the parent's, which nothing wrote.
                    if (casestate_q != S_IMGD_GET) begin
                        hs_st(S_IMGD_GET);
                        if (v64_on) begin
                            imgd_x0 <= e64_imgd_x0_q;
                            imgd_y0 <= e64_imgd_y0_q;
                            imgd_w  <= e64_imgd_w_q;
                            imgd_h  <= e64_imgd_h_q;
                            imgd_x  <= e64_imgd_x_q;
                            imgd_y  <= e64_imgd_y_q;
                            imgd_i  <= e64_imgd_i_q;
                            imgd_n  <= e64_imgd_n_q;
                            imgd_v64 <= e64_imgd_v64_q;
                            fb_dump_addr <= e64_fb_dump_addr_q;
                            hs_vnat_base(e64_vnat_base_q);
                        end
                        imgd_armed <= 1'b0;
                        imgd_pend <= 1'b0;
                        fb_dump_sel <= 1'b1;
                        if (v64_on) begin
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                    end else begin
                    casestate_imgd_body: begin end
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
                                hs_valloc_i(14'd0);
                                hs_hp_ret(S_IMGD_GET);
                                hs_st(S_FREE_OBJ);
                            end else begin
                                vfree_armed <= 1'b0;
                                if (vfree_ok) begin
                                    vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                    vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= CLS_IMGD;
                                    begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd0, 2'd0, 6'd2});
                                    e64_p_addr2 <= CLS_IMGD;
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number({22'd0, imgd_w});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number({22'd0, imgd_h});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd5, vobj_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    hs_vsp(vnat_base + 12'd1);
                                    vobj_next <= valloc_i + 14'd1;
                                    imgd_v64 <= 1'b0;
                                    fb_dump_sel <= 1'b0;
                                    hs_code(15'(ops_base + ip));
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    machine_fault <= 1'b1; fault_code <= 8'd3;
                                    running <= 1'b0; hs_st(S_DONE);
                                end
                            end
                        end else begin
                        ; // p3b: dead tagged write removed (obj_cls)
                        ; // p3b: dead tagged write removed (obj_n)
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                        stack_wr(imgd_res, {16'd0, n_obj}, 3'd1);
                        if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                        n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                        sp <= imgd_res + 11'd1;
                        fb_dump_sel <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                        end
                    end else if (!imgd_armed) begin
                        // settle beat: fb_dump_back is registered one cycle
                        // after fb_dump_addr - same arm as before the SRAM move
                        imgd_armed <= 1'b1;
                    end else if (!imgd_pend) begin
                        // issue: one 16-bit word per pixel (low byte), write
                        // held until ack like S_BLIT. OOB pixels write nothing
                        // but still take the ack beat so the walk stays uniform.
                        sram_req   <= 1'b1;
                        sram_we    <= (imgd_i < 19'(FB_PIXELS));
                        sram_addr  <= IMGD_SRAM_BASE
                                    + ((imgd_i < 19'(FB_PIXELS)) ? 21'(imgd_i) : 21'd0);
                        sram_wdata <= {8'd0, fb_dump_back};
                        imgd_pend  <= 1'b1;
                    end else if (sram_ack) begin
                        sram_req <= 1'b0;
                        sram_we  <= 1'b0;
                        imgd_pend <= 1'b0;
                        imgd_armed <= 1'b0; // fresh settle after the addr advance
                        if (imgd_i == (imgd_n - 19'd1)) begin
                            if (imgd_v64) begin
                                if (!vfree_armed) begin
                                    vfree_armed <= 1'b1;
                                    hs_valloc_i(14'd0);
                                    hs_hp_ret(S_IMGD_GET);
                                    hs_st(S_FREE_OBJ);
                                end else begin
                                    vfree_armed <= 1'b0;
                                    if (vfree_ok) begin
                                        vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                        vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= CLS_IMGD;
                                        begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd0, 2'd0, 6'd2});
                                        e64_p_addr2 <= CLS_IMGD;
                                        hs_hp_cmd(HP_OSETI);
                                        hs_hp_v64(1'b1);
                                        hs_hp_oid(valloc_i[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_hp_qn(3'd2);
                                        hs_hp_qi(3'd0);
                                        hp_qk_ff[0] <= id_width;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[0] <= v64_int32_number({22'd0, imgd_w});
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[0] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        hp_qk_ff[1] <= id_height;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[1] <= v64_int32_number({22'd0, imgd_h});
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[1] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        vst_wr(vnat_base, v64_handle(
                                            4'd5, vobj_gen_rdata,
                                            {19'd0, valloc_i[12:0]}
                                        ));
                                        hs_vsp(vnat_base + 12'd1);
                                        vobj_next <= valloc_i + 14'd1;
                                        imgd_v64 <= 1'b0;
                                        fb_dump_sel <= 1'b0;
                                        hs_code(15'(ops_base + ip));
                                        hs_hp_ret(S_FETCH_WAIT);
                                        hs_st(S_HEAP_WR);
                                    end else begin
                                        machine_fault <= 1'b1; fault_code <= 8'd3;
                                        running <= 1'b0; hs_st(S_DONE);
                                    end
                                end
                            end else begin
                            ; // p3b: dead tagged write removed (obj_cls)
                            ; // p3b: dead tagged write removed (obj_n)
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
            // flatten: heap write via S_HEAP_* only
                            stack_wr(imgd_res, {16'd0, n_obj}, 3'd1);
                            if (n_obj >= 16'(MAX_OBJ - 1)) dbg_heap_ovf <= dbg_heap_ovf + 16'd1;
                            n_obj <= (n_obj >= 16'(MAX_OBJ - 1)) ? n_obj : (n_obj + 16'd1);
                            sp <= imgd_res + 11'd1;
                            fb_dump_sel <= 1'b0;
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
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
                    end // #54 guard else
                end
                S_IMGD_PUT: begin
                    if (imgd_w == 10'd0 || imgd_h == 10'd0) begin
                        if (imgd_v64) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            imgd_v64 <= 1'b0;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!rast_wait) begin
                        // C1: linear DMA from the external snapshot region
                        // through the engine (was one arbiter round trip
                        // per PIXEL at VM-beat pace — MRDOFAST's 63% sink).
                        rast_go <= 1'b1;
                        rast_mode <= 2'd2;
                        rast_dx <= imgd_x0;
                        rast_dy <= imgd_y0;
                        rast_w <= imgd_w;
                        rast_h <= imgd_h;
                        rast_sbase <= 22'(imgd_i);
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        if (imgd_v64) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            imgd_v64 <= 1'b0;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_GC_CLEAR: begin
                    gc_obj_mark[gc_i] <= 1'b0;
                    if (gc_i < 13'(MAX_ARR))
                        gc_arr_mark[gc_i[11:0]] <= 1'b0;
                    if (gc_i == 13'(MAX_OBJ - 1)) begin
                        gc_root_i <= 13'd0;
                        hs_st(S_GC_ROOT);
                    end else
                        gc_i <= gc_i + 13'd1;
                end
                S_GC_ROOT: begin
                    // vars, eval stack, callback queues/listeners, active envs,
                    // native-held objects, prototype cache, then call frames.
                    if (gc_root_i < 13'd512) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            if (e32_var_init_rdata)
                                gc_mark_value(
                                    e32_var_tag_rdata,
                                    e32_vars_rdata
                                );
                            vgc_rd_arm <= 1'b0;
                            gc_root_i <= gc_root_i + 13'd1;
                        end
                    end else if (gc_root_i < 13'd2560) begin
                        if ((gc_root_i - 13'd512) < sp) begin
                            if (!vgc_rd_arm)
                                vgc_rd_arm <= 1'b1;
                            else begin
                                gc_mark_value(
                                    e32_stack_tag_rdata,
                                    e32_stack_rdata
                                );
                                vgc_rd_arm <= 1'b0;
                                gc_root_i <= gc_root_i + 13'd1;
                            end
                        end else
                            gc_root_i <= gc_root_i + 13'd1;
                    end else begin
                    // flatten: wait *_rdata; never peek raf/to/env/cstack SRAM.
                    if (gc_root_i < 13'd2672 ||
                        (gc_root_i >= 13'd2681 && gc_root_i < 13'd3257)) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            if (gc_root_i < 13'd2568) begin
                                if ((gc_root_i - 13'd2560) < raf_n)
                                    gc_mark_obj(e32_raf_fn_rdata);
                            end else if (gc_root_i < 13'd2632) begin
                                if ((gc_root_i - 13'd2568) < to_n)
                                    gc_mark_obj(e32_to_fn_rdata);
                            end else if (gc_root_i < 13'd2636) begin
                                if ((gc_root_i - 13'd2632) < kd_n)
                                    gc_mark_obj(e32_kd_slot_rdata);
                            end else if (gc_root_i < 13'd2640) begin
                                if ((gc_root_i - 13'd2636) < ku_n)
                                    gc_mark_obj(e32_ku_slot_rdata);
                            end else if (gc_root_i < 13'd2672) begin
                                if ((gc_root_i - 13'd2640) < env_sp)
                                    gc_mark_obj(e32_env_oid_rdata);
                            end else if (gc_root_i < 13'd2745) begin
                                if ((gc_root_i - 13'd2681) < n_fn_proto)
                                    gc_mark_obj(e32_fn_proto_oid_rdata);
                            end else if (gc_root_i < 13'd2873) begin
                                if ((gc_root_i - 13'd2745) < csp)
                                    gc_mark_obj(e32_cs1_this_rdata);
                            end else if (gc_root_i < 13'd3001) begin
                                if ((gc_root_i - 13'd2873) < csp &&
                                    e32_cs1_isctor_rdata)
                                    gc_mark_obj(e32_cs1_ctorobj_rdata);
                            end else if (gc_root_i < 13'd3129) begin
                                if ((gc_root_i - 13'd3001) < csp &&
                                    e32_cs1_isfe_rdata)
                                    gc_mark_value(
                                        3'd2,
                                        {16'd0, e32_cs1_fe_arr_rdata}
                                    );
                            end else if (gc_root_i < 13'd3257) begin
                                if ((gc_root_i - 13'd3129) < csp &&
                                    e32_cs1_isfe_rdata)
                                    gc_mark_obj(e32_cs1_fe_fn_rdata);
                            end
                            vgc_rd_arm <= 1'b0;
                            if (gc_root_i == 13'd3256)
                                hs_st(S_GC_POP);
                            else
                                gc_root_i <= gc_root_i + 13'd1;
                        end
                    end else begin
                        if (gc_root_i == 13'd2672) begin
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
                        end
                        gc_root_i <= gc_root_i + 13'd1;
                    end
                    end
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
                        hs_st(S_WAIT_FRAME);
                    end else if (!vgc_rd_arm) begin
                        vgc_rd_arm <= 1'b1;
                    end else begin
                        gc_cur <= gc_queue_rdata;
                        gc_qr <= gc_qr + 14'd1;
                        gc_slot <= 7'd0;
                        vgc_rd_arm <= 1'b0;
                        hs_st(gc_queue_rdata[13] ? S_GC_ARR : S_GC_OBJ);
                    end
                end
                S_GC_OBJ: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (gc_slot < e32_obj_n_rdata) begin
                        if (e32_obj_cls_rdata == CLS_ENV &&
                            gc_slot == 7'd0) begin
                            if (e32_tenv_parent_rdata != 16'd0)
                                gc_mark_obj(e32_tenv_parent_rdata);
                        gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end else if (e32_obj_cls_rdata == CLS_FN &&
                                     gc_slot == 7'd2) begin
                            if (e32_tfn_parent_rdata != 16'd0)
                                gc_mark_obj(e32_tfn_parent_rdata);
                            gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end else begin
                            gc_mark_value(vobj_trdata, vobj_rdata[31:0]);
                            gc_slot <= gc_slot + 7'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        hs_st(S_GC_POP);
                    end
                end
                S_GC_ARR: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (!jn_slot_arm)
                        jn_slot_arm <= 1'b1;
                    else if (gc_slot < e32_arr_len_tos_rdata) begin
                        gc_mark_value(varr_trdata, varr_rdata[31:0]);
                        gc_slot <= gc_slot + 7'd1;
                        vgc_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        hs_st(S_GC_POP);
                    end
                end
                // S_V64_EXEC body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                S_V64_ALLOC: begin
                    // Leave cycle: parent state is still EXEC. Stay in ALLOC
                    // while the free-slot scan walks (same pin as RECT /
                    // GC_CLEAR). Without this, exec re-issues MAKE_ARR from
                    // i=0 every clock and arrays never land (INVADERS
                    // obj=1023 arr=0).
                    if (state != S_V64_ALLOC) begin
                        hs_st(S_V64_ALLOC);
                        // Latch exec start so ALLOC uses parent *_ff (hs_m
                        // is one-shot; rdata wait must not snap to e64).
                        hs_valloc_kind(e64_valloc_kind_q);
                        hs_valloc_i(e64_valloc_i_q);
                        valloc_rd_arm <= 1'b0;
                        // GET_PROP / prior NEW_OBJ left cls_done+cls_ctor_q
                        // (Game ctor=1). Next nested `new Item` then
                        // re-entered Game until CSTK (PACMAN fault 2).
                        cls_done <= 1'b0;
                        cls_hit <= 1'b0;
                    end else if (casestate_q != S_V64_ALLOC)
                        // casestate_q SRAM mux: vfn_env/entry rdata is one
                        // beat after q==ALLOC. Kind 3 intern `new Stage`
                        // used BIND leftover entry (PACMAN LOAD_VAR stage
                        // fault 4; snippet NEW_OBJ Game HEAP re-issue).
                        hs_st(S_V64_ALLOC);
                    else if (cls_scan)
                        hs_st(S_V64_ALLOC);
                    else if (cls_done && cls_ctor_mode &&
                             (valloc_kind == 2'd0) &&
                             (code_rdata[7:0] == OP_NEW_OBJ)) begin
                        // Object already written; ctor_ip from class scan FF.
                        begin
                            logic [15:0] ctor_ip;
                            logic [63:0] handle;
                            logic [11:0] argc;
                            logic [8:0] vslot;
                            ctor_ip = cls_ctor_q;
                            argc = vcall_argc;
                            handle = v64_handle(
                                4'd5, vobj_gen_rdata,
                                {19'd0, valloc_i[12:0]}
                            );
                            cls_done <= 1'b0;
                            // Class table ctor wins when it has an IP.
                            // ctor_q=FFFF is miss OR `var Item = function`
                            // (PACMAN Stage/Item). PYTHON / exec32 then
                            // use intern_var even if cls_hit. Skipping
                            // that re-used leftover Game ctor=1.
                            if (cls_hit && ctor_ip != 16'hFFFF) begin
                                if (vcsp >= CSTK) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd2;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else if (e32_intern_var_ok_rdata) begin
                                    // potential-bugs #52: PYTHON NEW_OBJ links
                                    // instance.__proto__ = ctorFn.prototype on
                                    // EVERY class-table hit
                                    // (_value64_ctor_function_for_class +
                                    // _value_object_protos), not only on the
                                    // dynamic env/vars ctor paths. This inline
                                    // dispatch skipped the link, so
                                    // `function Stage(){}` +
                                    // `Stage.prototype.m = ...` + `new Stage()`
                                    // left vobj_proto UNDEFINED and every
                                    // prototype member read undefined with no
                                    // fault — PACMAN's title items were never
                                    // created (createItem/bind/draw all
                                    // prototype methods): black glass.
                                    // Route through the existing S_RD →
                                    // S_V64_CTOR_VARS machinery, which reads
                                    // vvars[slot] (hoisted fn), writes
                                    // vobj_proto[valloc_i] <= vfn_proto, and
                                    // then dispatches this same ctor_ip via
                                    // its ctor_ip != FFFF branch. All the
                                    // read-mux cases for this route already
                                    // exist (vvars_raddr, vfn_proto_rdata,
                                    // vfn_valid_rdata). Two extra clocks per
                                    // `new`, Port A legal.
                                    hs_hp_key({7'd0, e32_intern_var_rdata});
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    ret_state <= S_V64_CTOR_VARS;
                                    hs_st(S_RD);
                                end else begin
                                    // Class name is not a var (pure `class`
                                    // syntax): methods live in cls_mip, no
                                    // runtime prototype object to link.
                                    hs_vcall_value(1'b0);
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    hs_vcall_set_this(1'b1);
                                    hs_vcall_this(handle);
                                    hs_vcall_ctor_val(handle);
                                    hs_valloc_kind(2'd3);
                                    hs_valloc_i({4'd0, venv_next});
                                    hs_valloc_retried(1'b0);
                                    valloc_rd_arm <= 1'b0;
                                end
                            end else if (ctor_ip == 16'hFFFF &&
                                e32_intern_var_ok_rdata &&
                                venv[63:48] == 16'h7ff9 &&
                                venv[47:44] == 4'd9) begin
                                if (venv[31:0] >= ENV_DEPTH ||
                                    !venv_valid_rdata ||
                                    venv_gen_rdata != venv[43:32]) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd4;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    vslot = e32_intern_var_rdata;
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    hs_hp_env(1'b1);
                                    hs_hp_cmd(HP_GETPROP);
                                    hs_hp_v64(1'b1);
                                    hs_hp_eid(venv[9:0]);
                                    hs_hp_len({1'b0, venv_len_rdata});
                                    hs_hp_slot(5'd0);
                                    hs_hp_key({7'd0, vslot});
                                    hs_hp_phase(3'd0);
                                    hs_hp_hit(1'b0);
                                    hs_hp_ret(S_V64_CTOR_ENV);
                                    hs_st(S_HEAP_WAIT);
                                end
                            end else if (ctor_ip == 16'hFFFF &&
                                e32_intern_var_ok_rdata) begin
                                hs_hp_key({7'd0, e32_intern_var_rdata});
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                ret_state <= S_V64_CTOR_VARS;
                                hs_st(S_RD);
                            end else begin
                                vst_wr(vsp - argc, handle);
                                hs_vsp(vsp - argc + 12'd1);
                                if (e64_vcsp_q != 8'd0)
                                    hs_vcsp(e64_vcsp_q - 8'd1);
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end
                    else if (!valloc_rd_arm) begin
                        // *_valid_rdata is last beat's valloc_i. Wait
                        // after increment or kind change (holes after GC).
                        valloc_rd_arm <= 1'b1;
                        hs_st(S_V64_ALLOC);
                    end else if (valloc_kind == 2'd1) begin
                            logic [15:0] count;
                        logic need_long;
                        // Latched at OP_MAKE_ARR / Array(n). Do not use
                        // code_rdata here — GC resume would re-decode a
                        // different word as the length.
                        count = {8'd0, valloc_arr_n};
                        need_long = (count > 16'(ARR_SHORT_CAP));
                        if ((!need_long && valloc_i < MAX_ARR &&
                             !varr_valid_rdata &&
                             (valloc_i < 14'(MAX_ARR_SHORT) ||
                              !vlong_used_rdata)) ||
                            (need_long && valloc_i >= 14'(MAX_ARR_SHORT) &&
                             valloc_i < MAX_ARR &&
                             !varr_valid_rdata &&
                             !vlong_used_rdata)) begin
                            logic take_long;
                            take_long = need_long ||
                                (valloc_i >= 14'(MAX_ARR_SHORT));
                            begin vav_we <= 1'b1; vav_wa <= valloc_i[10:0]; vav_wd <= 1'b1; end
                            varr_len_wr(valloc_i[11:0], count[7:0]);
                            begin vlo_we <= 1'b1; vlo_wa <= valloc_i[10:0]; vlo_wd <= take_long; end
                            e64_poke(6'd45, {4'd0, valloc_i[11:0]},
                                     {55'd0, take_long, count[7:0]});
                            e64_p_addr2 <= {8'd0, valloc_i[7:0]};
                            if (take_long) begin
                                begin vli_we <= 1'b1; vli_wa <= valloc_i[10:0]; vli_wd <= valloc_i[7:0]; end
                                begin vlu_we <= 1'b1; vlu_wa <= valloc_i[6:0]; vlu_wd <= 1'b1; end
                            end
                            varr_next <= valloc_i + 14'd1;
                            if (vnat_dom == 3'd7) begin
                                vst_wr(vnat_base, v64_handle(
                                    4'd6, varr_gen_rdata,
                                    {20'd0, valloc_i[11:0]}
                                ));
                                hs_vsp(vnat_base + 12'd1);
                                hs_vnat_dom(3'd0);
                                hs_hp_make_arr(1'b0);
                            end else if (count == 16'd0) begin
                                vst_wr(vsp, v64_handle(
                                    4'd6, varr_gen_rdata,
                                    {20'd0, valloc_i[11:0]}
                                ));
                                hs_vsp(vsp + 12'd1);
                            end else begin
                                // Leave e0..eN-1 on the stack; S_HEAP_FILL
                                // copies them, then writes the handle at vbase.
                                hs_hp_make_arr(1'b1);
                                hs_hp_rval(v64_handle(
                                4'd6, varr_gen_rdata,
                                {20'd0, valloc_i[11:0]}
                            ));
                            hs_vsp(vsp - count + 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            if (count == 16'd0)
                            hs_st(S_FETCH_WAIT);
                            else begin
                                hs_hp_cmd(HP_AFILL);
                                hs_hp_v64(1'b1);
                                hs_hp_from_stack((vnat_dom != 3'd7));
                                hs_hp_aid(valloc_i[11:0]);
                                hs_hp_aslot(7'd0);
                                hs_hp_lim(count[7:0]);
                                hs_hp_vbase((vnat_dom == 3'd7)
                                    ? 12'd0 : (vsp - count));
                                hs_hp_wval(V64_UNDEFINED);
                                hs_hp_ret(S_FETCH_WAIT);
                                hs_st(S_HEAP_FILL);
                            end
                        end else if (valloc_i + 14'd1 < MAX_ARR) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else if (valloc_kind == 2'd3) begin
                        if (valloc_i < ENV_DEPTH &&
                            !venv_valid_rdata) begin
                            logic [11:0] base_sp;
                            logic [7:0] nparam;
                            logic [7:0] fr;
                            logic [63:0] function_handle, parent_env;
                            logic [63:0] ctor_inst;
                            logic is_valcall;
                            // Kind 0 / CTOR_ENV planted the instance in *_ff;
                            // hs_m is already clear so the mux is leftover
                            // exec UNDEF. Nested `new` inside a constructor
                            // also leaves vcall_value mux=1 (IIFE/CALL_VAL)
                            // and would BIND as a call — empty this.n=n.
                            if (vcall_ctor_val_ff[63:48] == V64_TAG_PREFIX &&
                                vcall_ctor_val_ff[47:44] == V64_KIND_OBJECT)
                                ctor_inst = vcall_ctor_val_ff;
                            else
                                ctor_inst = vcall_ctor_val;
                            is_valcall = vcallback_fe || intern_ctor_fn ||
                                (vcall_value &&
                                !(ctor_inst[63:48] == V64_TAG_PREFIX &&
                                  ctor_inst[47:44] == V64_KIND_OBJECT &&
                                  !vcall_value_ff));
                            base_sp = vsp - vcall_argc -
                                      (is_valcall ? 12'd1 : 12'd0);
                            // forEach: callee is vfe_fn. VST_AT(vsp-argc-1)
                            // misses when parent vsp/window and exec vsp
                            // disagree (LET_VAR fault 1, n stays 0).
                            // Intern NEW_OBJ: callee is bind_ins, not stack
                            // (NEW_OBJ never pushed the function).
                            function_handle = vcallback_fe
                                ? e64_vfe_fn_q
                                : intern_ctor_fn ? bind_ins
                                : (is_valcall
                                    ? `VST_AT(vsp - vcall_argc - 12'd1)
                                    : V64_UNDEFINED);
                            parent_env = intern_ctor_fn ? intern_ctor_env
                                : (is_valcall ? vfn_env_rdata : venv);
                            // ALLOC re-issue can see venv already this slot
                            // (nested CALL_USER). A self-parent makes
                            // STORE_VAR HEAP_CMP walk forever (eid=2→2).
                            if (parent_env[63:48] == V64_TAG_PREFIX &&
                                parent_env[47:44] == V64_KIND_ENV &&
                                parent_env[9:0] == valloc_i[9:0])
                                parent_env = V64_UNDEFINED;
                            nparam = intern_ctor_fn
                                ? {2'd0, intern_ctor_nparam}
                                : (is_valcall
                                ? {2'd0, vfn_nparam_rdata}
                                : vcall_argc);
                            // forEach args sit at vfe_base+2 (pushed fn)
                            // then elem. Do not use exec vsp (frozen at
                            // CALL_METHOD) — that made bind_vsp_next=0
                            // and LET_VAR fault 1.
                            if (vcallback_fe) begin
                                if (nparam == 8'd0)
                                    nparam = 8'd1;
                                base_sp = e64_vfe_base_q + 12'd2;
                            end
                            // CALL_USER/NEW_OBJ clock exec vcsp+1 before
                            // ALLOC, so the new slot is e64-1. Parent-
                            // reserve paths (FOREACH / FRAME_RAF / LOOKFN
                            // / getter) poke hs_vcsp(e64+1) the cycle
                            // before ALLOC; exec has not absorbed it, so
                            // e64 is still the caller. Using e64-1 then
                            // overwrote that caller with 0xfffc (animate
                            // RET_VAL fault 2; leftover rAF overflow).
                            if (hs_m_vcsp &&
                                (vcsp_ff == (e64_vcsp_q + 8'd1)))
                                fr = e64_vcsp_q;
                            else
                                fr = (e64_vcsp_q != 8'd0)
                                     ? (e64_vcsp_q - 8'd1) : vcsp;
                            begin vev_we <= 1'b1; vev_wa <= valloc_i[8:0]; vev_wd <= 1'b1; end
                            begin vel_we <= 1'b1; vel_wa <= valloc_i[8:0]; vel_wd <= 5'd0; end
                            e64_poke(6'd46, {6'd0, valloc_i[9:0]},
                                     {52'd0, venv_gen_rdata});
                            venv_parent_pa_we <= 1'b1;
                            venv_parent_pa_waddr <= valloc_i[9:0];
                            venv_parent_pa_wdata <= parent_env;
                            venv_next <= valloc_i[9:0] + 10'd1;
                            // CALL_USER clocks ip_n=entry before ALLOC.
                            // ip+1 was then entry+1 (INVADERS vret=1798).
                            // bind_ip holds call-site+1 from that EXEC beat.
                            vfr_we  <= 1'b1;
                            vfr_wa  <= fr[6:0];
                            vfr_rip <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc
                                : ((ip == vcall_entry) ? e64_bind_ip_q
                                                      : (ip + 16'd1));
                            vfr_bsp  <= base_sp;
                            vfr_this <= vthis;
                            vfr_env  <= venv;
                            vfr_fn   <= function_handle;
                            vfr_ctor <= ctor_inst;
                            vframe_escaped[fr] <= 1'b0;
                            e64_p_frame_we <= 1'b1;
                            e64_p_frame_idx <= fr[6:0];
                            e64_p_frame_rip <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc
                                : ((ip == vcall_entry) ? e64_bind_ip_q
                                                      : (ip + 16'd1));
                            e64_p_frame_bsp <= base_sp;
                            e64_p_frame_esc <= 1'b0;
                            e64_p_frame_this <= vthis;
                            e64_p_frame_env <= venv;
                            e64_p_frame_fnv <= function_handle;
                            e64_p_frame_ctor <= ctor_inst;
                            hs_vcsp(fr + 8'd1);
                            vcallback_raf <= 1'b0;
                            vcallback_timer <= 1'b0;
                            vcallback_key <= 1'b0;
                            vcallback_fe <= 1'b0;
                            hs_venv(v64_handle(
                                4'd9, venv_gen_rdata,
                                {22'd0, valloc_i[9:0]}
                            ));
                            if (is_valcall) begin
                                // Arrow/bound keep lexical this; CALL_METHOD
                                // own-property sets vcall_this (game.init).
                                // Nested NEW_OBJ may still see leftover
                                // vcall_value=1; keep the instance in this.
                                hs_vthis((ctor_inst[63:48] == V64_TAG_PREFIX &&
                                          ctor_inst[47:44] == V64_KIND_OBJECT)
                                       ? ctor_inst
                                       : (((intern_ctor_fn
                                            ? intern_ctor_flags[0]
                                            : vfn_flags_rdata[0]) ||
                                          (intern_ctor_fn
                                            ? intern_ctor_flags[2]
                                            : vfn_flags_rdata[2]))
                                       ? vfn_bound_this_rdata
                                       : vcall_set_this
                                       ? vcall_this : V64_UNDEFINED));
                                bind_mode <= 2'd0;
                                bind_k <= 8'd0;
                                bind_n <= nparam;
                                bind_argc <= vcall_argc[7:0];
                                bind_base <= base_sp;
                                bind_src <= vcallback_fe
                                    ? (e64_vfe_base_q + 12'd3)
                                    : (vsp - vcall_argc);
                                bind_vsp_next <= base_sp + nparam;
                                bind_ip <= intern_ctor_fn
                                    ? intern_ctor_entry : vfn_entry_rdata;
                                bind_ret <= S_FETCH_WAIT;
                                bind_rd_arm <= 1'b0;
                                intern_ctor_hold <= 1'b0;
                                hs_st(S_V64_BIND);
                            end else begin
                                hs_vthis((ctor_inst[63:48] == V64_TAG_PREFIX &&
                                          ctor_inst[47:44] == V64_KIND_OBJECT)
                                       ? ctor_inst
                                       : (vcall_set_this
                                          ? vcall_this : V64_UNDEFINED));
                                vctor_scan <= 6'd0;
                                vctor_armed <= 1'b0;
                                // CALL_USER entry lives in exec q; NEW_OBJ
                                // cls_ctor lives in vcall_entry_ff. Latch the
                                // mux into ff so CTOR_PAD (hs_m already 0)
                                // does not bind_ip=0 and skip the ctor.
                                hs_vcall_entry(vcall_entry);
                                hs_ip(vcall_entry);
                                hs_code(15'(ops_base + vcall_entry));
                                intern_ctor_hold <= 1'b0;
                                hs_st(S_V64_CTOR_PAD);
                            end
                            hs_vcall_set_this(1'b0);
                            hs_vcall_ctor_val(V64_UNDEFINED);
                        end else if (valloc_i + 14'd1 < ENV_DEPTH) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else if (valloc_kind == 2'd2) begin
                        if (valloc_i < MAX_OBJ &&
                            !vfn_valid_rdata) begin
                            vfn_next <= valloc_i + 14'd1;
                            begin vfv_we <= 1'b1; vfv_wa <= valloc_i[9:0]; vfv_wd <= 1'b1; end
                                if (valloc_now_fn) begin
                                    vfn_entry[valloc_i[12:0]] <= 16'hfffa;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd0;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'd0;
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= V64_UNDEFINED;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0, 3'd0, 6'd0, 16'hfffa});
                                    e64_p_data2 <= V64_UNDEFINED;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= V64_UNDEFINED;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    // Same-cycle TOS: leave_hold ALLOC window
                                    // otherwise sees exec vst_we=0 (IIFE CALL_VAL).
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_now_fn(1'b0);
                                end else if (valloc_bind &&
                                             valloc_bind_src == 13'h1FFF) begin
                                    vfn_entry[valloc_i[12:0]] <= valloc_fn_entry;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd1;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'b100;
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= valloc_bind_this;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0, 3'b100, 6'd1,
                                              valloc_fn_entry});
                                    e64_p_data2 <= V64_UNDEFINED;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_bind_this;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_bind(1'b0);
                                    hs_valloc_fn_entry(16'd0);
                                end else if (valloc_bind) begin
                                    vfn_entry[valloc_i[12:0]] <=
                                        vfn_entry_rdata;
                                    vfn_nparam[valloc_i[12:0]] <=
                                        vfn_nparam_rdata;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= vfn_env_rdata;
                                    // [2]=has_bound_this (PYTHON bind).
                                    vfn_flags[valloc_i[12:0]] <=
                                        {1'b1, vfn_flags_rdata[1],
                                         vfn_flags_rdata[0]};
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= valloc_bind_this;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0,
                                              1'b1,
                                              vfn_flags_rdata[1],
                                              vfn_flags_rdata[0],
                                              vfn_nparam_rdata,
                                              vfn_entry_rdata});
                                    e64_p_data2 <= vfn_env_rdata;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_bind_this;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_bind(1'b0);
                                end else begin
                                    vfn_entry[valloc_i[12:0]] <= valloc_fn_entry;
                                    vfn_nparam[valloc_i[12:0]] <= valloc_fn_a1[5:0];
                                vfn_env_pa_we <= 1'b1;
                                vfn_env_pa_waddr <= valloc_i[12:0];
                                vfn_env_pa_wdata <= venv;
                                    // [2]=arrow [1]=IIFE (JSB a1 bit6) [0]=arrow
                                    // this-bind. CALL_VAL reads [1] for flat IIFE.
                                vfn_flags[valloc_i[12:0]] <=
                                        {valloc_fn_a1[7], valloc_fn_a1[6],
                                         valloc_fn_a1[7]};
                                vfn_bound_this_pa_we <= 1'b1;
                                vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                vfn_bound_this_pa_wdata <= valloc_fn_a1[7] ? vthis : V64_UNDEFINED;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
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
                                    // 16-bit poke: [15]=escaped, [6:0]=frame.
                                    // `{1'b1, 8'd0, vcsp-1}` is 17 bits; the
                                    // flag MSB was truncated so exec RET
                                    // always recycled the captured env
                                    // (PACMAN `_context` LOAD → undefined →
                                    // fillRect never interned, vdraw=0,0,0,0).
                                    if (vcsp != 8'd0)
                                        e64_p_addr2 <= {1'b1, 8'd0,
                                                        vcsp[6:0] - 7'd1};
                                    vst_wr(vsp, v64_handle(
                                    4'd7, vfn_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                    ));
                                    // Push: keep previous TOS in win[1]. Plant
                                    // win[0] alone made `this.f = (e)=>{}` a
                                    // SET_PROP on the Fn (PYTHON sloppy
                                    // no-op) so class-field arrows never
                                    // stuck (DONKEY this.startSelect).
                                    vst_push_win(v64_handle(
                                    4'd7, vfn_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    // Closure captured this activation's env.
                                    if (vcsp != 8'd0)
                                        vframe_escaped[vcsp - 8'd1] <= 1'b1;
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                            end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else begin
                        if (valloc_i < MAX_OBJ &&
                            vobj_alloc_rdata == 0) begin
                            vobj_next <= valloc_i + 14'd1;
                            if (code_rdata[7:0] == OP_NEW_OBJ) begin
                                vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd0; end
                                // Latched intern (vcall_entry), not code_rdata
                                // — HEAP between `new Game` and nested
                                // `new Item` reused Game's name.
                                vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= vcall_entry;
                                vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd0;
                                vobj_proto_pa_we <= 1'b1;
                                vobj_proto_pa_waddr <= valloc_i[12:0];
                                vobj_proto_pa_wdata <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                e64_p_addr2 <= vcall_entry;
                                // Class ctor: one c/clock (not a unique-case CAM).
                                cls_scan <= 1'b1;
                                cls_armed <= 1'b0;
                                cls_done <= 1'b0;
                                cls_hit <= 1'b0;
                                cls_ctor_mode <= 1'b1;
                                cls_c <= 4'd0;
                                cls_cls <= vcall_entry;
                                cls_ctor_q <= 16'hFFFF;
                                hs_st(S_V64_ALLOC);
                            end else begin
                                logic [63:0] handle;
                                logic [15:0] key_intern;
                                handle = v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                );
                                vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= 16'hFFFF;
                                vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd0;
                                begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd0; end
                                vobj_proto_pa_we <= 1'b1;
                                vobj_proto_pa_waddr <= valloc_i[12:0];
                                vobj_proto_pa_wdata <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                if (valloc_proto) begin
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_proto_fn;
                                    vfn_proto_pa_wdata <= handle;
                                    vst_wr(vnat_base, handle);
                                    hs_valloc_proto(1'b0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end else if (valloc_metrics) begin
                                    vmetrics <= handle;
                                    vst_wr(vnat_base, handle);
                                    hs_valloc_metrics(1'b0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd1);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number({16'd0, vmetrics_w});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd1) begin
                                    // querySelector style object
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vnat_style <= handle;
                                    hs_vnat_dom(3'd2);
                                    hs_valloc_i(valloc_i + 14'd1);
                                    valloc_rd_arm <= 1'b0;
                                end else if (vnat_dom == 3'd2) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd3);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_style;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= vnat_style;
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd640);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[2] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[2] <= v64_int32_number(32'd480);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[2] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd3) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd5;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd5, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    // Pin fillStyle@0 strokeStyle@1 so SET_PROP
                                    // writes one slot (MRDO palK).
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_fillstyle;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_strokestyle;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd4) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd2;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd2, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
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
                                        ? id_d
                                        : (kev_q[kev_rp][7:0] == 8'd87)
                                        ? id_w
                                        : (kev_q[kev_rp][7:0] == 8'd83)
                                        ? id_s
                                        : (kev_q[kev_rp][7:0] == 8'd80)
                                        ? id_p : 16'hFFFF;
                                    vkev_event <= handle;
                                    hs_vnat_dom(3'd0);
                                    vkey_li <= 5'd0;
                                    vkey_ln <= vlistener_n; // #60 snapshot
                                    // Seed the FRAME_KEY listener scan HERE.
                                    // Its own `state != S_V64_FRAME_KEY`
                                    // first-entry arm never runs on this path:
                                    // HEAP_WR returns with hs_st(hp_ret), so
                                    // state is already FRAME_KEY on arrival.
                                    // bind_k kept whatever the previous state
                                    // left (FRAME_TIMER counts to 64), so the
                                    // `bind_k < 16` scan was skipped and every
                                    // key event was dropped without a single
                                    // listener compare — no title responded to
                                    // Space / Enter / arrows.
                                    bind_k <= 8'd0;
                                    bind_rd_arm <= 1'b0;
                                    vk_found <= 1'b0;
                                    vk_pick <= 5'd0;
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd3);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_type;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, kev_q[kev_rp][8]
                                            ? id_keydown : id_keyup}
                                    );
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_key;
                                    hs_m_hp_qk <= 1'b1;
                                    dbg_evkey <= key_intern;
                                    hp_qv_ff[1] <= (key_intern == 16'hFFFF)
                                        ? V64_UNDEFINED
                                        : v64_handle(4'd4, 12'd0,
                                                     {16'd0, key_intern});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[2] <= id_keycode;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[2] <= v64_int32_number(
                                            {24'd0, kev_q[kev_rp][7:0]}
                                        );
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[2] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_V64_FRAME_KEY);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd6) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd3;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd3, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end else begin
                                    if (valloc_regex) begin
                                        vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd6;
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd6, 2'd0, 6'd0});
                                        hs_valloc_regex(1'b0);
                                        vst_wr(vsp, handle);
                            hs_vsp(vsp + 12'd1);
                            hs_ip(ip + 16'd1);
                                        hs_code(15'(ops_base + ip + 16'd1));
                                        hs_hp_cmd(HP_OSETI);
                                        hs_hp_v64(1'b1);
                                        hs_hp_oid(valloc_i[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_hp_qn(3'd1);
                                        hs_hp_qi(3'd0);
                                        hp_qk_ff[0] <= 16'd0;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[0] <= {32'd0, valloc_regex_pack};
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[0] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        hs_hp_ret(S_FETCH_WAIT);
                                        hs_st(S_HEAP_WR);
                                    end else begin
                                    vst_wr(vsp, handle);
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                                    end
                                end
                            end
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end
                end
                S_V64_GC_CLEAR: begin
                    // Leave cycle: parent state is still EXEC. Stay in CLEAR
                    // so exec enable drops and hs_* pokes apply.
                    if (state != S_V64_GC_CLEAR)
                        hs_st(S_V64_GC_CLEAR);
                    else begin
                    if (vgc_clear_i < MAX_OBJ) begin
                        begin vmko_we <= 1'b1; vmko_wa <= vgc_clear_i[9:0]; vmko_wd <= 1'b0; end
                        begin vmkf_we <= 1'b1; vmkf_wa <= vgc_clear_i[9:0]; vmkf_wd <= 1'b0; end
                    end
                    else if (vgc_clear_i < MAX_OBJ + MAX_ARR)
                        begin vmka_we <= 1'b1; vmka_wa <= 12'(vgc_clear_i - MAX_OBJ); vmka_wd <= 1'b0; end
                    else
                        begin vmke_we <= 1'b1; vmke_wa <= 9'(vgc_clear_i - MAX_OBJ - MAX_ARR); vmke_wd <= 1'b0; end
                    if (vgc_clear_i + 14'd1 >=
                        MAX_OBJ + MAX_ARR + ENV_DEPTH) begin
                        vgc_root_i <= 12'd0;
                        vgc_root_phase <= 3'd0;
                        hs_st(S_V64_GC_ROOT);
                    end else
                        hs_vgc_clear_i(vgc_clear_i + 14'd1);
                    end
                end
                S_V64_GC_ROOT: begin
                    case (vgc_root_phase)
                        3'd0: begin
                            if (vgc_root_i < MAX_VARS) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                    if (vvar_valid_rdata)
                                        v64_gc_mark_task(vvars_rdata);
                                    vgc_root_i <= vgc_root_i + 12'd1;
                                    vgc_rd_arm <= 1'b0;
                                end
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
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                case (vgc_root_i[1:0])
                                    2'd0: v64_gc_mark_task(
                                        vframe_this_rdata
                                    );
                                    2'd1: v64_gc_mark_task(
                                        vframe_env_rdata
                                    );
                                    2'd2: v64_gc_mark_task(
                                        vframe_fn_rdata
                                    );
                                    default: v64_gc_mark_task(
                                        vframe_ctor_rdata
                                    );
                                endcase
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd5;
                            end
                        end
                        3'd5: begin
                            if (vgc_root_i < vraf_n) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                v64_gc_mark_task(vraf_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
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
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                if (vtimer_valid_rdata)
                                    v64_gc_mark_task(vtimer_fn_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd7;
                            end
                        end
                        default: begin
                            if (vgc_root_i < 12'd32) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                if (vgc_root_i[0])
                                    v64_gc_mark_task(vlistener_fn_rdata);
                                else
                                    v64_gc_mark_task(vlistener_ev_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
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
                                hs_st(S_V64_GC_POP);
                        end
                    endcase
                end
                S_V64_GC_POP: begin
                    if (vgc_qr < vgc_qw) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                        vgc_cur <= {16'h7ff9, vgc_queue_rdata[16:13], 31'd0, vgc_queue_rdata[12:0]};
                        hs_vgc_qr(vgc_qr + 14'd1);
                        vgc_slot_i <= 8'd0;
                        vgc_rd_arm <= 1'b0;
                        if (vgc_queue_rdata[16:13] == V64_KIND_OBJECT ||
                            vgc_queue_rdata[16:13] == V64_KIND_ELEMENT)
                            hs_st(S_V64_GC_OBJ);
                        else if (vgc_queue_rdata[16:13] == 4'd6)
                            hs_st(S_V64_GC_ARR);
                        else if (vgc_queue_rdata[16:13] == 4'd7)
                            hs_st(S_V64_GC_FN);
                        else
                            hs_st(S_V64_GC_ENV);
                        end
                    end else begin
                        vgc_obj_i <= 13'd0;
                        hs_st(S_V64_GC_SWEEP_OBJ);
                    end
                end
                S_V64_GC_OBJ: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (vgc_slot_i < vobj_len_rdata) begin
                        v64_gc_mark_task(vobj_rdata[63:0]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == {2'b0, vobj_len_rdata})
                    begin
                        v64_gc_mark_task(vobj_proto_rdata);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                    end else
                        hs_st(S_V64_GC_POP);
                end
                S_V64_GC_ARR: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (!jn_slot_arm)
                        jn_slot_arm <= 1'b1;
                    else if (vgc_slot_i < varr_len_rdata) begin
                        v64_gc_mark_task(varr_rdata);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                        vgc_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                    end else begin
                        jn_slot_arm <= 1'b0;
                        hs_st(S_V64_GC_POP);
                    end
                end
                S_V64_GC_FN: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (vgc_slot_i == 0) begin
                        v64_gc_mark_task(vfn_env_rdata);
                        vgc_slot_i <= 8'd1;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == 1) begin
                        v64_gc_mark_task(vfn_bound_this_rdata);
                        vgc_slot_i <= 8'd2;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == 2) begin
                        v64_gc_mark_task(vfn_proto_rdata);
                        vgc_slot_i <= 8'd3;
                        vgc_rd_arm <= 1'b0;
                    end else
                        hs_st(S_V64_GC_POP);
                end
                S_V64_GC_ENV: begin
                    if (vgc_slot_i == 0) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(venv_parent_rdata);
                            vgc_slot_i <= 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else if (vgc_slot_i <= venv_len_rdata) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(venv_rdata[63:0]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        hs_st(S_V64_GC_POP);
                    end
                end
                S_V64_GC_SWEEP_OBJ: begin
                    logic free_obj;
                    logic free_fn;
                    logic [11:0] new_fgen;
                    logic [11:0] new_ogen;
                    // Obj and Fn share the index space; poke 48 flags each
                    // independently so a swept object cannot clear a live fn.
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    free_obj = (vobj_alloc_rdata == 2'd1 &&
                                !vobj_mark_rdata);
                    free_fn = (vfn_valid_rdata && !vfn_mark_rdata);
                    new_fgen = (vfn_gen_rdata == 12'hfff)
                        ? 12'd1 : vfn_gen_rdata + 12'd1;
                    new_ogen = (vobj_gen_rdata == 12'hfff)
                        ? 12'd1 : vobj_gen_rdata + 12'd1;
                    if (free_obj) begin
                        vobj_alloc_wr(vgc_obj_i[9:0], 2'd0);
                        begin vol_we <= 1'b1; vol_wa <= vgc_obj_i; vol_wd <= 6'd0; end
                        begin vog_we <= 1'b1; vog_wa <= vgc_obj_i[9:0]; vog_wd <= new_ogen; end
                    end
                    if (free_fn) begin
                        begin vfv_we <= 1'b1; vfv_wa <= vgc_obj_i[9:0]; vfv_wd <= 1'b0; end
                        begin vfg_we <= 1'b1; vfg_wa <= vgc_obj_i[9:0]; vfg_wd <= new_fgen; end
                    end
                    if (free_obj || free_fn)
                        e64_poke(6'd48, {3'd0, vgc_obj_i},
                                 {20'd0, new_fgen, 30'd0, free_fn, free_obj});
                    vgc_rd_arm <= 1'b0;
                    if (vgc_obj_i + 13'd1 >= MAX_OBJ) begin
                        vgc_arr_i <= 12'd0;
                        hs_st(S_V64_GC_SWEEP_ARR);
                    end else
                        vgc_obj_i <= vgc_obj_i + 13'd1;
                    end
                end
                S_V64_GC_SWEEP_ARR: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    if (varr_valid_rdata && !varr_mark_rdata) begin
                        begin vav_we <= 1'b1; vav_wa <= vgc_arr_i[10:0]; vav_wd <= 1'b0; end
                        varr_len_wr(vgc_arr_i, 8'd0);
                        e64_poke(6'd49, {4'd0, vgc_arr_i}, 64'd0);
                        if (varr_long_rdata)
                            // #76: full-width 8-bit index into the 128-deep
                            // occupancy map - slice like every other writer.
                            begin vlu_we <= 1'b1; vlu_wa <= varr_lidx_rdata[6:0]; vlu_wd <= 1'b0; end
                        begin vlo_we <= 1'b1; vlo_wa <= vgc_arr_i[10:0]; vlo_wd <= 1'b0; end
                        begin
                            vag_we <= 1'b1; vag_wa <= vgc_arr_i;
                            vag_wd <= (varr_gen_rdata == 12'hfff)
                                ? 12'd1 : varr_gen_rdata + 12'd1;
                        end
                    end
                    vgc_rd_arm <= 1'b0;
                    if (vgc_arr_i + 12'd1 >= MAX_ARR) begin
                        vgc_env_i <= 10'd0;
                        hs_st(S_V64_GC_SWEEP_ENV);
                    end else
                        vgc_arr_i <= vgc_arr_i + 12'd1;
                    end
                end
                S_V64_GC_SWEEP_ENV: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    if (venv_valid_rdata && !venv_mark_rdata) begin
                        begin vev_we <= 1'b1; vev_wa <= vgc_env_i[8:0]; vev_wd <= 1'b0; end
                        begin vel_we <= 1'b1; vel_wa <= vgc_env_i[8:0]; vel_wd <= 5'd0; end
                        e64_poke(6'd50, {6'd0, vgc_env_i}, 64'd0);
                        veg_we <= 1'b1; veg_wa <= vgc_env_i[8:0];
                        veg_wd <= (venv_gen_rdata == 12'hfff)
                            ? 12'd1 : venv_gen_rdata + 12'd1;
                    end
                    vgc_rd_arm <= 1'b0;
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
                                hs_vgc_wait_after(1'b0);
                                hs_st(S_WAIT_FRAME);
                            end else begin
                                // Script-end halt: the last ops (explicit
                                // swapBuffers + POP tails) ran exec-only,
                                // so the parent ip/vsp mirrors are stale
                                // here and CHECKPOINT? hashed a leftover
                                // stack word (value64 parity tests).
                                // Absorb the exec truth before S_DONE.
                                hs_ip(e64_ip_q);
                                hs_vsp(e64_vsp_q);
                                hs_vcsp(e64_vcsp_q);
                                hs_vthis(e64_vthis_q);
                                hs_venv(e64_venv_q);
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end
                        end else begin
                            hs_valloc_retried(1'b1);
                            hs_valloc_i(14'd0);
                            // potential-bugs #61: resume re-enters S_V64_ALLOC
                            // with valloc_rd_arm still 1 from the exhausted
                            // pre-GC scan. The first scan beat then trusted
                            // *_valid_rdata whose raddr was still the sweep's
                            // vgc_env_i (casestate_q lag) — the just-freed
                            // slot, rdata 0 — and committed the new env over
                            // LIVE slot 0 (venv_next was reset to 0): len
                            // wiped, parent rewritten, gen unchanged, so all
                            // stale handles now resolved to the new occupant.
                            // PACMAN's Game closure (_stages/_index/_events)
                            // lived in e0 and died on the first mid-frame GC
                            // (black screen, frozen Date limiter). Force a
                            // fresh settle read before the scan trusts rdata.
                            valloc_rd_arm <= 1'b0;
                            if (vgc_resume == 2'd1) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_FETCH_WAIT);
                            end else if (vgc_resume == 2'd2) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_V64_JSON_PARSE);
                            end else if (vgc_resume == 2'd3) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_V64_JSON);
                            end else begin
                                vgc_resume <= 2'd0;
                            hs_st(S_V64_ALLOC);
                            end
                        end
                    end else
                        vgc_env_i <= vgc_env_i + 10'd1;
                    end
                end
                S_V64_CLEAR: begin
                    if (state != S_V64_CLEAR)
                        hs_st(S_V64_CLEAR);
                    else if (!rast_wait) begin
                        // C1: full-screen fill through the engine
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= 10'd0;
                        rast_dy <= 10'd0;
                        rast_w <= 10'(MW);
                        rast_h <= 10'(MH);
                        rast_color <= vdraw_color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_RECT_LD: begin
                    // Two clocks per arg (addr, then vst_rdata). Extra clocks
                    // OK. Do not write vst_win — that smash killed the bars.
                    logic signed [31:0] raw_i;
                    logic [9:0] clipped;
                    if (state != S_V64_RECT_LD) begin
                        hs_st(S_V64_RECT_LD);
                        rect_ld_arm <= 1'b0;
                        rect_ld_k <= 2'd0;
                    end else if (!rect_ld_arm) begin
                        rect_ld_arm <= 1'b1;
                        hs_st(S_V64_RECT_LD);
                    end else begin
                        raw_i = $signed(v64_to_int32(vst_rdata));
                        if (rect_ld_k[0] == 1'b0)
                            clipped = clip_u(32'((raw_i * e64_ctx_sx_q) >>> 16)
                                             + e64_ctx_tx_q, MW);
                        else
                            clipped = clip_u(32'((raw_i * e64_ctx_sy_q) >>> 16)
                                             + e64_ctx_ty_q, MH);
                        unique case (rect_ld_k)
                            2'd0: hs_vdraw_x(clipped);
                            2'd1: hs_vdraw_y(clipped);
                            2'd2: hs_vdraw_w(clip_sz(32'((raw_i * e64_ctx_sx_q)
                                             >>> 16), 10'd0, MW));
                            default: hs_vdraw_h(clip_sz(32'((raw_i * e64_ctx_sy_q)
                                             >>> 16), 10'd0, MH));
                        endcase
                        rect_ld_arm <= 1'b0;
                        if (rect_ld_k == 2'd3) begin
                            hs_vdraw_i(19'd0);
                            hs_st(S_V64_RECT);
                        end else begin
                            rect_ld_k <= rect_ld_k + 2'd1;
                            hs_st(S_V64_RECT_LD);
                        end
                    end
                end
                S_V64_RECT: begin
                    logic [19:0] total;
                    logic [9:0] px, py;
                    if (state != S_V64_RECT) begin
                        hs_st(S_V64_RECT);
                        // Native fillRect (nid 2) latched x/y/w/h in exec.
                        // CALL_METH comes here from RECT_LD with SRAM args
                        // already in vdraw_*_ff (state is already RECT).
                        hs_vdraw_x(e64_vdraw_x_q);
                        hs_vdraw_y(e64_vdraw_y_q);
                        hs_vdraw_w(e64_vdraw_w_q);
                        hs_vdraw_h(e64_vdraw_h_q);
                    end
                    total = 20'(vdraw_w) * 20'(vdraw_h);
                    px = 10'd0; py = 10'd0; // C1: walk lives in the engine
                    if (vdraw_w == 0 || vdraw_h == 0) begin
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end else if (!rast_wait) begin
                        // C1: hand the clipped rect to the full-rate engine
                        // (1 px/clk instead of 1 px/beat) and block on the
                        // rise-then-fall of rast_busy.
                        if (dbg_rect_n < 7'd64) begin
                            `ifndef SYNTHESIS
                            dbg_rect[dbg_rect_n[5:0]] <=
                                {vdraw_color, vdraw_x, vdraw_y, vdraw_w, vdraw_h};
                            `endif // sim-only probe store
                            dbg_rect_n <= dbg_rect_n + 7'd1;
                        end
                        if (vdraw_color != 8'd0)
                            dbg_rect_px <= dbg_rect_px + 32'(total);
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= vdraw_x;
                        rast_dy <= vdraw_y;
                        rast_w <= vdraw_w;
                        rast_h <= vdraw_h;
                        rast_color <= vdraw_color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_WAIT_FRAME: hs_st(S_WAIT_FRAME);
                S_V64_FOREACH: begin
                    // Leave cycle: parent state is still EXEC. Copy exec's
                    // CALL_METHOD plant (parent vfe_* stay UNDEF otherwise —
                    // done path hs_ip(0) re-enters until vfe_sp>=8 fault 3).
                    if (state != S_V64_FOREACH) begin
                        hs_st(S_V64_FOREACH);
                        // potential-bugs #47: S_V64_GC_ROOT phase 7 marks the
                        // PARENT vfe_*_s, but the live nest stack is exec64's
                        // (vfe_s_we) and the parent copies were never written.
                        // A nested walk (INVADERS grids.forEach ->
                        // grid.invaders.forEach -> projectiles.forEach) whose
                        // inner callback triggers a mid-walk GC (ALLOC /
                        // FREE_ARR / JSON retry, vgc_halt_after=0) therefore
                        // lost the OUTER array / callback / map array: swept
                        // vfe_fn -> fault 4 on resume, swept vfe_map -> map
                        // and filter write into a recycled array. Mirror the
                        // push here: on this beat vfe_sp / vfe_arr are still
                        // the OUTER walk (exec64 saved exactly these at
                        // vfe_s_waddr = old vfe_sp), so the shadow matches
                        // slot for slot. Re-entry after a callback has
                        // e64_vfe_sp_q == vfe_sp and does not fire.
                        // Stale slots above vfe_sp are left alone on pop:
                        // between the pop and the next re-latch the shadow is
                        // the outer walk's ONLY root. Marking a stale word is
                        // conservative (v64_gc_mark_task checks tag/kind/
                        // bound/valid), never a fault.
                        if (e64_vfe_sp_q > vfe_sp && vfe_sp < 4'd8) begin
                            vfe_arr_s[vfe_sp[2:0]] <= vfe_arr;
                            vfe_fn_s[vfe_sp[2:0]]  <= vfe_fn;
                            vfe_map_s[vfe_sp[2:0]] <= vfe_map;
                        end
                        vfe_arr <= e64_vfe_arr_q;
                        vfe_fn <= e64_vfe_fn_q;
                        vfe_i <= e64_vfe_i_q;
                        vfe_ret <= e64_vfe_ret_q;
                        vfe_base <= e64_vfe_base_q;
                        vfe_mode <= e64_vfe_mode_q;
                        vfe_map <= e64_vfe_map_q;
                        vfe_sp <= e64_vfe_sp_q;
                        vfe_len <= e64_vfe_len_q;
                        // RET 0xfffc leave_hold: parent still EXEC so the
                        // EXEC !leave_hold hs_m_vcsp clear did not run.
                        // Sync exec depth (including 0) before the next
                        // EXEC opnd beat re-raises via sticky hs_m.
                        hs_vcsp(e64_vcsp_q);
                    end else if (e64_vfe_arr_q[63:48] != V64_TAG_PREFIX ||
                        e64_vfe_arr_q[47:44] != V64_KIND_ARRAY ||
                        e64_vfe_i_q >= e64_vfe_len_q) begin
                        if (!vfe_rd_arm)
                            vfe_rd_arm <= 1'b1;
                        else begin
                        vfe_rd_arm <= 1'b0;
                        vst_wr(e64_vfe_base_q,
                            e64_vfe_findidx_q ? v64_int32_number(32'hFFFFFFFF)
                            : (e64_vfe_mode_q == 2'd2 || e64_vfe_mode_q == 2'd3 ||
                             e64_vfe_reduce_q) // #39: reduce returns the acc
                            ? e64_vfe_map_q : V64_UNDEFINED);
                        hs_vsp(e64_vfe_base_q + 12'd1);
                        hs_ip(e64_vfe_ret_q);
                        hs_code(15'(ops_base + e64_vfe_ret_q));
                        // RET 0xfffc overlay can leave this callback's
                        // frame live (one_fe vret=fffc, rAF never parked).
                        // Pop only that frame: matching bsp is the ALLOC
                        // forEach slot. Nested inner done must not pop
                        // the outer callback (different base).
                        if (e64_vcsp_q != 8'd0 &&
                            vframe_rip_rdata == 16'hfffc &&
                            vframe_bsp_rdata ==
                                (e64_vfe_base_q + 12'd2))
                            hs_vcsp(e64_vcsp_q - 8'd1);
                        else
                            hs_vcsp(e64_vcsp_q);
                        if (e64_vfe_sp_q != 4'd0) begin
                            // Exec nest stack is the owner. Parent vfe_*_s
                            // is never written (CALL_METHOD saves in exec).
                            hs_m_vfe_pop <= 1'b1;
                            vfe_sp <= vfe_sp - 4'd1;
                        end else begin
                            vfe_arr <= V64_UNDEFINED;
                            vfe_fn <= V64_UNDEFINED;
                            vfe_mode <= 2'd0;
                            vfe_map <= V64_UNDEFINED;
                        end
                        hs_st(S_FETCH_WAIT);
                        end
                    end else if (e64_vfe_fn_q[63:48] != V64_TAG_PREFIX ||
                                 e64_vfe_fn_q[47:44] != V64_KIND_FUNCTION) begin
                        machine_fault <= 1'b1; fault_code <= 8'd4;
                        running <= 1'b0; hs_st(S_DONE);
                    end else if (vcsp >= CSTK ||
                                 (!vfe_rd_arm &&
                                  vsp + 12'd4 > STACK_DEPTH) ||
                                 (vfe_rd_arm && vsp >= STACK_DEPTH)) begin
                        machine_fault <= 1'b1;
                        fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                        running <= 1'b0; hs_st(S_DONE);
                    end else begin
                        // 1W1R + TOS window only shifts ±1 per clock, and
                        // ALLOC's `VST_AT is combo on last cycle's window —
                        // idle one beat after the last push so TOS is fn.
                        if (!vfe_rd_arm) begin
                            vst_wr(vsp, e64_vfe_fn_q);
                            hs_vsp(vsp + 12'd1);
                            vfe_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            // #39 reduce: (acc, elem, i, arr) — acc first.
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? e64_vfe_map_q : varr_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd1;
                        end else if (bind_k == 8'd1) begin
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? varr_rdata
                                : v64_int32_number({24'd0, e64_vfe_i_q}));
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd2;
                        end else if (bind_k == 8'd2) begin
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? v64_int32_number({24'd0, e64_vfe_i_q})
                                : e64_vfe_arr_q);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd3;
                        end else if (e64_vfe_reduce_q && bind_k == 8'd3)
                        begin
                            vst_wr(vsp, e64_vfe_arr_q);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd4;
                        end else begin
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(e64_vfe_reduce_q ? 12'd4 : 12'd3);
                            vcallback_fe <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            // Callback ALLOC writes e64-1. Exec did not +1
                            // (NEW_OBJ/CALL_USER do). Nested forEach then
                            // overwrote the live frame and never RET
                            // (INVADERS vfe_sp>=8 fault 3).
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_vsp(vsp);
                            vfe_i <= e64_vfe_i_q + 8'd1;
                            hs_m_vfe_i <= 1'b1;
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            hs_st(S_V64_ALLOC);
                        end
                    end
                end
                // name_rdata lags name_rdaddr 1 clock; char_id_rdata lags
                // name_rdata another. Hopping STRIDX→WR the first beat used
                // char_id[stale], so interned row[col]==="1" was never true
                // (INVADERS drawBitmap painted 0 sprite pixels). Same
                // casestate_q stay as HEAP_WAIT — extra clock, Port A, no peek.
                S_V64_STRIDX: begin
                    // name_rdata lags name_rdaddr 1 clock; char_id_rdata
                    // lags name_rdata another. One casestate stay left
                    // WR sampling char_id[stale] so row[col]==="1" never
                    // fired (INVADERS splash bars painted, sprites not).
                    if (casestate_q != S_V64_STRIDX) begin
                        stridx_rd_arm <= 1'b0;
                        hs_st(S_V64_STRIDX);
                    end else if (!stridx_rd_arm) begin
                        stridx_rd_arm <= 1'b1;
                        hs_st(S_V64_STRIDX);
                    end else begin
                        stridx_rd_arm <= 1'b0;
                        hs_st(S_V64_STRIDX_WR);
                    end
                end
                S_V64_STRIDX_WR: begin
                    // SRAM write alone leaves vst_win[0] as the original
                    // intern (the whole row). Then `row[col]==="1"` compared
                    // "0110" to "1" and drawBitmap painted 0 sprite pixels.
                    // HEAP plants TOS the same way (hold_win skips the we path).
                    // Plant TOS. Do not hold_win — that skipped the next
                    // LOAD_CONST shift so `row[col]==="1"` compared the
                    // char to itself / the row (0 sprite pixels).
                    begin
                        logic [63:0] ch;
                        ch = e32_char_ok_rdata
                            ? v64_handle(4'd4, 12'd0,
                                         {16'd0, e32_char_id_rdata})
                            : V64_UNDEFINED;
                        vst_wr(vsp - 12'd1, ch);
                        vst_win[0] <= ch;
                    end
                    hs_code(15'(ops_base + ip));
                    hs_st(S_FETCH_WAIT);
                end
                S_V64_JSON: begin
                    // V1 JSON-engine removal (2026-08-23): the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_V64_JSON_PARSE: begin
                    // V1 JSON-engine removal (2026-08-23): the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_V64_CTOR_PAD: begin
                    // PYTHON _value64_entry_nparam: count leading LET_VAR
                    // (a1 bit0) then bind_argv (pad undefined / drop extras).
                    // vcall_entry mux is e64_q here (hs_m cleared). NEW_OBJ
                    // never clocks entry in exec — use ff (kind 3 latched).
                    if (!vctor_armed) begin
                        vctor_armed <= 1'b1;
                        // Refetch ctor+scan so stop-on-JUMP is not stale
                        // NEW_OBJ code_rdata (0-param startSelect skip).
                        hs_code(15'(ops_base + vcall_entry_ff +
                            {10'd0, vctor_scan}));
                    end
                    else if (code_rdata[7:0] == OP_LET_VAR &&
                             code_rdata[24] && vctor_scan < 6'd63) begin
                        vctor_scan <= vctor_scan + 6'd1;
                        vctor_armed <= 1'b0;
                        hs_code(15'(ops_base + vcall_entry_ff +
                            {10'd0, vctor_scan} + 16'd1));
                    end else begin
                        logic [11:0] base_sp;
                        logic [7:0] nparam;
                        logic is_fj;
                        nparam = {2'd0, vctor_scan};
                        is_fj = (code_rdata[7:0] == OP_JUMP);
                        base_sp = vsp - vcall_argc;
                        bind_mode <= 2'd0;
                        bind_k <= 8'd0;
                        bind_n <= nparam;
                        bind_argc <= vcall_argc[7:0];
                        bind_base <= base_sp;
                        bind_src <= vsp - vcall_argc;
                        bind_vsp_next <= base_sp + nparam;
                        // 0-param ctor: first op is JUMP to field inits.
                        // nparam>0: LET_VARs then that JUMP — HEAP_WR uses
                        // vctor_jmp after the last param (DONKEY startSelect).
                        vctor_jmp <= is_fj ? code_rdata[23:8] : 16'hFFFF;
                        vctor_lets <= vctor_scan;
                        bind_ip <= vcall_entry_ff;
                        bind_ret <= S_FETCH_WAIT;
                        bind_rd_arm <= 1'b0;
                        vctor_armed <= 1'b0;
                        hs_st(S_V64_BIND);
                        // CALL_USER ALLOC already hs_vcsp. Re-arm so
                        // FETCH_WAIT after BIND copies vcsp_ff into exec
                        // (RET_VAL was seeing exec vcsp=0 → fault 2).
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
                    end
                end
                S_V64_CTOR_ENV: begin
                    // NEW_OBJ after sequential env lookup (hp_rval / vcall_entry).
                    if (!tfn_rd_arm)
                        tfn_rd_arm <= 1'b1;
                    else begin
                        logic [15:0] ctor_ip;
                        logic [63:0] handle, ctor_fn;
                        logic [11:0] argc;
                        logic ctor_fn_ok;
                        ctor_ip = vcall_entry_ff;
                        argc = vcall_argc;
                        handle = v64_handle(
                            4'd5, vobj_gen_rdata,
                            {19'd0, valloc_i[12:0]}
                        );
                        ctor_fn = hp_rval;
                        ctor_fn_ok = (ctor_fn[63:48] == V64_TAG_PREFIX &&
                            ctor_fn[47:44] == V64_KIND_FUNCTION &&
                            ctor_fn[31:0] < MAX_OBJ &&
                            vfn_valid_rdata &&
                            vfn_gen_rdata == ctor_fn[43:32]);
                        hs_hp_env(1'b0);
                        tfn_rd_arm <= 1'b0;
                        if (ctor_fn_ok) begin
                            vobj_proto_pa_we <= 1'b1;
                            vobj_proto_pa_waddr <= valloc_i[12:0];
                            vobj_proto_pa_wdata <= vfn_proto_rdata;
                        end
                        if (ctor_ip != 16'hFFFF) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end
                        end else if (ctor_fn_ok) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                bind_k <= (argc == 0) ? 8'd0
                                    : (argc - 8'd1);
                                bind_n <= argc;
                                bind_argc <= argc;
                                bind_base <= vsp - argc;
                                bind_src <= vsp - argc;
                                bind_ins <= ctor_fn;
                                intern_ctor_hold <= 1'b1;
                                intern_ctor_entry <= vfn_entry_rdata;
                                intern_ctor_nparam <= vfn_nparam_rdata;
                                intern_ctor_flags <= vfn_flags_rdata;
                                intern_ctor_env <= vfn_env_rdata;
                                bind_vsp_next <= vsp + 12'd1;
                                bind_ret <= S_V64_ALLOC;
                                bind_rd_arm <= 1'b0;
                                hs_vcall_value(1'b1);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_BIND);
                            end
                        end else begin
                            vst_wr(vsp - argc, handle);
                            hs_vsp(vsp - argc + 12'd1);
                            if (e64_vcsp_q != 8'd0)
                                hs_vcsp(e64_vcsp_q - 8'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_V64_CTOR_VARS: begin
                    // NEW_OBJ varmap after registered vvars_rdata (S_RD beat).
                    if (!tfn_rd_arm)
                        tfn_rd_arm <= 1'b1;
                    else begin
                        logic [15:0] ctor_ip;
                        logic [63:0] handle, ctor_fn;
                        logic [11:0] argc;
                        logic ctor_fn_ok;
                        ctor_ip = vcall_entry_ff;
                        argc = vcall_argc;
                        handle = v64_handle(
                            4'd5, vobj_gen_rdata,
                            {19'd0, valloc_i[12:0]}
                        );
                        ctor_fn = vvar_valid_rdata
                            ? vvars_rdata : V64_UNDEFINED;
                        ctor_fn_ok = (ctor_fn[63:48] == V64_TAG_PREFIX &&
                            ctor_fn[47:44] == V64_KIND_FUNCTION &&
                            ctor_fn[31:0] < MAX_OBJ &&
                            vfn_valid_rdata &&
                            vfn_gen_rdata == ctor_fn[43:32]);
                        tfn_rd_arm <= 1'b0;
                        if (ctor_fn_ok) begin
                            vobj_proto_pa_we <= 1'b1;
                            vobj_proto_pa_waddr <= valloc_i[12:0];
                            vobj_proto_pa_wdata <= vfn_proto_rdata;
                        end
                        if (ctor_ip != 16'hFFFF) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end
                        end else if (ctor_fn_ok) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                bind_k <= (argc == 0) ? 8'd0
                                    : (argc - 8'd1);
                                bind_n <= argc;
                                bind_argc <= argc;
                                bind_base <= vsp - argc;
                                bind_src <= vsp - argc;
                                bind_ins <= ctor_fn;
                                intern_ctor_hold <= 1'b1;
                                intern_ctor_entry <= vfn_entry_rdata;
                                intern_ctor_nparam <= vfn_nparam_rdata;
                                intern_ctor_flags <= vfn_flags_rdata;
                                intern_ctor_env <= vfn_env_rdata;
                                bind_vsp_next <= vsp + 12'd1;
                                bind_ret <= S_V64_ALLOC;
                                bind_rd_arm <= 1'b0;
                                hs_vcall_value(1'b1);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_BIND);
                            end
                        end else begin
                            vst_wr(vsp - argc, handle);
                            hs_vsp(vsp - argc + 12'd1);
                            if (e64_vcsp_q != 8'd0)
                                hs_vcsp(e64_vcsp_q - 8'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_HEAP_WAIT: begin
                    // flatten: beat 0 muxes varr_long[hp_aid]; beat 1 slot raddr
                    // from long_rdata; HEAP_CMP sees varr_rdata.
                    // casestate_q SRAM mux (Agent 1 UG901): raddr is the flop,
                    // not combo casestate. Wait until q==WAIT so *_rdata is
                    // this HEAP, not leftover EXEC/ALLOC (intern NEW_OBJ Game
                    // re-issue hang: S_EXEC ip=NEW_OBJ hp=5 forever).
                    hp_slot_pend <= 1'b0;
                    if (casestate_q != S_HEAP_WAIT)
                        hs_st(S_HEAP_WAIT);
                    else if (!hp_slot_arm &&
                             (hp_cmd == HP_ARRGET || hp_cmd == HP_ARRSET ||
                              hp_cmd == HP_AFILL || hp_cmd == HP_PUSH ||
                              hp_cmd == HP_UNSHIFT || hp_cmd == HP_SPLICE ||
                              hp_cmd == HP_AGETI || hp_cmd == HP_ASETI))
                        hp_slot_arm <= 1'b1;
                    else begin
                        hp_slot_arm <= 1'b0;
                        hs_st(S_HEAP_CMP);
                    end
                end
                S_HEAP_CMP: begin
                    if (hp_slot_pend)
                        hp_slot_pend <= 1'b0;
                    else if (cls_scan)
                        ; // FF class match this clock (cls_done next). Not a BRAM CAM.
                    else if (cls_done) begin
                        begin
                            logic [15:0] gip;
                            logic [15:0] mip;
                            gip = cls_gip_q;
                            mip = cls_mip_q;
                            cls_done <= 1'b0;
                            if (gip != 16'hFFFF && hp_v64) begin
                                hs_vsp(vsp - 12'd1);
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(gip);
                                hs_vcall_argc(12'd0);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, hp_oid}
                                ));
                                hs_vcall_ctor_val(V64_UNDEFINED);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                if (e64_vcsp_q < CSTK)
                                    hs_vcsp(e64_vcsp_q + 8'd1);
                                hs_st(S_V64_ALLOC);
                            end else if (mip != 16'hFFFF && hp_v64) begin
                                hs_vnat_base(vsp - 12'd1);
                                hs_valloc_kind(2'd2);
                                hs_valloc_i(vfn_next);
                                hs_valloc_fn_entry(mip);
                                hs_valloc_bind(1'b1);
                                hs_valloc_bind_src(13'h1FFF);
                                hs_valloc_bind_this(v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, hp_oid}
                                ));
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end else if (hp_proto[63:48] == V64_TAG_PREFIX &&
                                hp_proto[47:44] == V64_KIND_OBJECT &&
                                hp_proto[31:0] < MAX_OBJ) begin
                                if (!hp_proto_arm) begin
                                    hp_proto_arm <= 1'b1;
                                    hs_st(S_HEAP_WAIT);
                                end else if (vobj_alloc_rdata == 2'd1 &&
                                    vobj_gen_rdata == hp_proto[43:32]) begin
                                    hp_proto_arm <= 1'b0;
                                    hs_hp_phase(3'd1);
                                    hs_hp_oid(hp_proto[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_st(S_HEAP_WAIT);
                                end else begin
                                    hp_proto_arm <= 1'b0;
                                if (hp_v64) begin
                                    vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                    vst_win[0] <= V64_UNDEFINED;
                                end else begin
                                    stack_wr(sp - 8'd1, 32'd0, 3'd5);
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                                end
                            end else begin
                                // PYTHON GET_PROP miss → undefined. MAKE_OBJ
                                // proto is UNDEF, so the object-proto arm
                                // above is skipped. Without this, cls_done
                                // clears and HEAP_CMP restarts cls_scan
                                // forever (`{n:1}.missing`, PACMAN options).
                                hp_proto_arm <= 1'b0;
                                if (hp_v64) begin
                                    vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                    vst_win[0] <= V64_UNDEFINED;
                                end else begin
                                    stack_wr(sp - 8'd1, 32'd0, 3'd5);
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end else
                    // rdata valid this cycle. Stop at len, not a 32-wide mux.
                    // Object GET/SET/LOOKFN: exec copies of alloc/gen can lag.
                    // Reject stale handles here on the parent heap (keep gen).
                    // Compare the gen latched at issue (hp_spr_w[11:0]), not
                    // TOS — the window can hold a different word (false stale).
                    if (!hp_env && hp_v64 && hp_phase == 3'd0 &&
                        hp_slot == 5'd0 &&
                        (hp_cmd == HP_GETPROP || hp_cmd == HP_SETPROP ||
                         hp_cmd == HP_LOOKFN) &&
                        (vobj_alloc_rdata != 2'd1 ||
                         vobj_gen_rdata != hp_spr_w[11:0])) begin
                        if (hp_cmd == HP_SETPROP) begin
                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                            hs_vsp(vsp - 12'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_LOOKFN) begin
                            hs_hp_rval(V64_UNDEFINED);
                            hs_hp_hit(1'b0);
                            hs_st(hp_ret);
                        end else begin
                            vst_wr(vsp - 12'd1, V64_UNDEFINED);
                            vst_win[0] <= V64_UNDEFINED;
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else if (hp_env) begin
                        if (hp_slot < hp_len[4:0] &&
                            venv_rdata[72:64] == hp_key[8:0]) begin
                            hs_hp_hit(1'b1);
                            hs_hp_rval(venv_rdata[63:0]);
                            if (hp_cmd == HP_GETPROP) begin
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    // Drop hp_env so the next GET_PROP/SET_PROP
                                    // walks the object, not this env (`x`/`y`
                                    // after LOAD_VAR current).
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, venv_rdata[63:0]);
                                    // Push: keep previous TOS in win[1]. Plant
                                    // win[0] alone + later vsp shift turned
                                    // `this.n=n` into SET_PROP on the number
                                    // (nested ctor param; P.n never stuck).
                                    vst_push_win(venv_rdata[63:0]);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                            end else if (hp_phase == 3'd1) begin
                                // LET_VAR non-local: env hit is not a write.
                                if (!vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                            end else
                                hs_st(S_HEAP_WR);
                        end else if (hp_phase == 3'd5 ||
                                     hp_phase == 3'd6) begin
                            // Verified slot-hint first guess missed (or
                            // hint >= len): restart a FULL scan from slot
                            // 0. The hint is never trusted (#55 — inliner
                            // can rebind a name at a lower slot); it only
                            // short-circuits the common case where the
                            // key really is at its compile-time slot.
                            // Phase 6 = hinted local LET_VAR; its full
                            // scan is the normal phase-2 find-or-append.
                            hs_hp_phase(hp_phase == 3'd6 ? 3'd2 : 3'd0);
                            hs_hp_slot(5'd0);
                            hp_slot_pend <= 1'b1;
                        end else if (hp_slot + 5'd1 < hp_len[4:0]) begin
                            hp_next_slot();
                        end else begin
                            if (hp_phase != 3'd2 &&
                                venv_parent_rdata[63:48] == 16'h7ff9 &&
                                venv_parent_rdata[47:44] == 4'd9 &&
                                venv_parent_rdata[31:0] < ENV_DEPTH &&
                                venv_parent_rdata[9:0] != hp_eid) begin
                                if (!hp_proto_arm) begin
                                    hp_proto_arm <= 1'b1;
                                    hs_st(S_HEAP_WAIT);
                                end else if (venv_valid_rdata &&
                                    venv_gen_rdata ==
                                        venv_parent_rdata[43:32]) begin
                                hp_proto_arm <= 1'b0;
                                // Live parent: walk. A swept/stale parent
                                // (GC of an IIFE env still named on a
                                // closure) falls through to vvars like
                                // PYTHON globals — not ERROR_HANDLE.
                                hs_hp_eid(venv_parent_rdata[9:0]);
                                hs_hp_len({1'b0, venv_len_rdata});
                                hs_hp_slot(5'd0);
                                hs_st(S_HEAP_WAIT);
                                end else begin
                                    hp_proto_arm <= 1'b0;
                                    if (hp_cmd == HP_GETPROP) begin
                                hs_hp_hit(1'b0);
                                hs_hp_rval(vvar_valid_rdata
                                    ? vvars_rdata : V64_UNDEFINED);
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_push_win(vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                                    end else if (hp_phase == 3'd2) begin
                                if (venv_len_rdata >= 5'(ENV_SLOTS)) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    hs_hp_slot(venv_len_rdata);
                                    hs_hp_hit(1'b0);
                                    hs_st(S_HEAP_WR);
                                end
                                    end else begin
                                if (hp_phase == 3'd0 ||
                                    !vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                                    end
                                end
                            end else if (hp_cmd == HP_GETPROP) begin
                                hs_hp_hit(1'b0);
                                hs_hp_rval(vvar_valid_rdata
                                    ? vvars_rdata : V64_UNDEFINED);
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_push_win(vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                            end else if (hp_phase == 3'd2) begin
                                if (venv_len_rdata >= 5'(ENV_SLOTS)) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    hs_hp_slot(venv_len_rdata);
                                    hs_hp_hit(1'b0);
                                    hs_st(S_HEAP_WR);
                                end
                            end else begin
                                if (hp_phase == 3'd0 ||
                                    !vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end else if (hp_cmd == HP_OGETI) begin
                        hs_hp_rval(vobj_rdata[63:0]);
                        hs_hp_key(vobj_rdata[79:64]);
                        hs_hp_tag(vobj_trdata);
                        // PACMAN maze-cache bug: `hp_qv[...] <=` wrote into
                        // the hs64 MUX (multi-driven; the continuous assign
                        // wins), so the walk's slot reads never landed —
                        // S_V64_OGETI_NAT consumed the EXEC copy's leftovers.
                        // putImageData worked only while those leftovers were
                        // the creation's width/height pokes; the first
                        // JSON.parse (PACMAN's per-frame NPC churn) replaced
                        // them and every later putImageData saw w/h=0 (maze
                        // vanished after frame 1). Poke hp_qv_ff + mask like
                        // every other hp_q* writer so exec absorbs it.
                        hp_qv_ff[hp_qi[1:0]] <= vobj_rdata[63:0];
                        hs_m_hp_qv <= 1'b1;
                        hp_qk_ff[hp_qi[1:0]] <= vobj_rdata[79:64];
                        hs_m_hp_qk <= 1'b1;
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hp_next_slot();
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_ARRGET || hp_cmd == HP_AGETI) begin
                        hs_hp_rval((hp_aslot < hp_alen)
                            ? varr_rdata : (hp_v64 ? V64_UNDEFINED : 64'd0));
                        hs_hp_tag(varr_trdata);
                        if (hp_cmd == HP_ARRGET) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd2, (hp_aslot < hp_alen)
                                    ? varr_rdata : V64_UNDEFINED);
                                hs_vsp(vsp - 12'd1);
                            end else begin
                                stack_wr(sp - 8'd2, varr_rdata[31:0], varr_trdata);
                                sp <= sp - 8'd1;
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_v64 && hp_ret == S_FETCH_WAIT) begin
                            // Array.pop: last slot already addressed.
                            vst_wr(vnat_base, (hp_aslot < hp_alen)
                                ? varr_rdata : V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            hs_st(S_FETCH_WAIT);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_phase == 3'd0) begin
                            hs_hp_wval(varr_rdata);
                            hs_hp_aslot(hp_aslot + 7'd1);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_SPLICE) begin
                        hs_hp_wval(varr_rdata);
                        hs_hp_aslot(hp_aslot - hp_lim[6:0]);
                        hs_st(S_HEAP_AWR);
                    end else if (hp_cmd == HP_ASSIGN) begin
                        if (hp_phase == 3'd3) begin
                            if (hp_qi + 3'd1 >= hp_qn) begin
                                // Result already at hp_vbase-2; drop sources.
                                if (hp_v64)
                                    hs_vsp(hp_vbase - 12'd1);
                                hs_st(hp_ret);
                            end else begin
                                if (hp_v64) begin
                                    logic [63:0] nsv;
                                    logic src_ok;
                                    logic [12:0] nsi;
                                    nsv = `VST_AT(hp_vbase + {9'd0, hp_qi} + 12'd1);
                                    if (nsv[63:48] == V64_TAG_PREFIX &&
                                        (nsv[47:44] == V64_KIND_OBJECT ||
                                         nsv[47:44] == V64_KIND_ELEMENT) &&
                                        nsv[31:0] < MAX_OBJ) begin
                                        if (!valloc_rd_arm) begin
                                            valloc_rd_arm <= 1'b1;
                                            hs_st(S_HEAP_WAIT);
                                        end else begin
                                            src_ok = (vobj_alloc_rdata == 2'd1 &&
                                                vobj_gen_rdata == nsv[43:32]);
                                            nsi = nsv[12:0];
                                            valloc_rd_arm <= 1'b0;
                                            hs_hp_qi(hp_qi + 3'd1);
                                            if (src_ok) begin
                                                hs_hp_si(nsi);
                                                hs_hp_ss(5'd0);
                                                hs_hp_phase(3'd0);
                                                hs_st(S_HEAP_WAIT);
                                            end else
                                                hs_st(S_HEAP_WAIT);
                                        end
                                    end else begin
                                        hs_hp_qi(hp_qi + 3'd1);
                                        hs_st(S_HEAP_WAIT);
                                    end
                                end else begin
                                    logic src_ok;
                                    logic [12:0] nsi;
                                    hs_hp_qi(hp_qi + 3'd1);
                                    nsi = e32_stack_rdata[12:0];
                                    src_ok = (e32_stack_tag_rdata == 3'd1);
                                    if (src_ok) begin
                                        hs_hp_si(nsi);
                                        hs_hp_ss(5'd0);
                                        hs_hp_phase(3'd0);
                                        hs_st(S_HEAP_WAIT);
                                    end else
                                        hs_st(S_HEAP_WAIT);
                                end
                            end
                        end else if (hp_phase == 3'd4) begin
                            // settled TARGET-length read (see the exec
                            // Object.assign dispatch): raddr is hp_oid on
                            // non-phase-0 beats.
                            if (!valloc_rd_arm) begin
                                valloc_rd_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_tn(hp_v64 ? vobj_len_rdata[5:0]
                                                : e32_obj_n_rdata[5:0]);
                                hs_hp_phase(3'd0);
                                hs_st(S_HEAP_WAIT);
                            end
                        end else if (hp_phase == 3'd0) begin
                            // PACMAN ghosts/pacman invisible: this beat's
                            // vobj_len_rdata (source length) and vobj_rdata
                            // (source slot) are only correct one beat after
                            // the phase-0 raddr muxes engage. The FIRST
                            // Object.assign worked off lucky leftovers; every
                            // later one read a stale len (0-ish), decided
                            // `hp_ss >= len` immediately, and copied NOTHING
                            // — resetItems left the NPC/player items with no
                            // type/draw/update. One settle beat, same
                            // discipline as phase 3 below.
                            if (!valloc_rd_arm) begin
                                valloc_rd_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else if (hp_ss >= (hp_v64 ? vobj_len_rdata[4:0]
                                                 : e32_obj_n_rdata[4:0])) begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_phase(3'd3);
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_key(vobj_rdata[79:64]);
                                hs_hp_wval(vobj_rdata[63:0]);
                                hs_hp_tag(vobj_trdata);
                                hs_hp_phase(3'd1);
                                hs_hp_slot(5'd0);
                                hs_hp_len(hp_tn);
                                hs_st(S_HEAP_WAIT);
                            end
                        end else begin
                            // phase 1: scan target for hp_key
                            if (hp_slot < hp_tn[4:0] &&
                                vobj_rdata[79:64] == hp_key) begin
                                hs_hp_phase(3'd2);
                                hs_st(S_HEAP_WR);
                            end else if (hp_slot + 5'd1 < hp_tn[4:0]) begin
                                hp_next_slot();
                            end else if (hp_tn < OBJ_SLOTS[5:0]) begin
                                hs_hp_slot(hp_tn[4:0]);
                                hs_hp_tn(hp_tn + 6'd1);
                                begin vol_we <= 1'b1; vol_wa <= hp_oid; vol_wd <= hp_tn + 6'd1; end
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, hp_tn + 6'd1});
                                if (!hp_v64)
                                    ; // p3b: dead tagged write removed (obj_n)
                                hs_hp_phase(3'd2);
                                hs_st(S_HEAP_WR);
                            end else begin
                                hs_hp_ss(hp_ss + 5'd1);
                                hs_hp_phase(3'd0);
                                hs_st(S_HEAP_WAIT);
                            end
                        end
                    end else if (hp_slot < vobj_len_rdata &&
                                 vobj_rdata[79:64] == hp_key) begin
                        hs_hp_hit(1'b1);
                        hs_hp_rval(vobj_rdata[63:0]);
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
                                stack_wr(sp - 8'd2, vobj_rdata[31:0], vobj_trdata);
                                sp <= sp - 8'd1;
                            end else begin
                                stack_wr(sp - 8'd1, vobj_rdata[31:0], vobj_trdata);
                            end
                            if (hp_cmd == HP_GETIDX && hp_v64)
                                hs_vsp(vsp - 12'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            hs_hp_key(vobj_rdata[79:64]);
                            hs_st(S_HEAP_WR);
                        end else if (hp_cmd == HP_LOOKFN) begin
                            // CALL_METHOD wants a function slot, not any key.
                            if ((hp_v64 &&
                                 (vobj_rdata[63:48] != V64_TAG_PREFIX ||
                                  vobj_rdata[47:44] != 4'd7)) ||
                                (!hp_v64 && vobj_trdata != 3'd4)) begin
                                if (hp_slot + 5'd1 < vobj_len_rdata[4:0]) begin
                                    hp_next_slot();
                                end else begin
                                    hs_hp_hit(1'b0);
                                    if (hp_phase == 3'd0 &&
                                        hp_proto[63:48] == V64_TAG_PREFIX &&
                                        hp_proto[47:44] == V64_KIND_OBJECT &&
                                        hp_proto[31:0] < MAX_OBJ) begin
                                        if (!hp_proto_arm) begin
                                            hp_proto_arm <= 1'b1;
                                            hs_st(S_HEAP_WAIT);
                                        end else if (vobj_alloc_rdata == 2'd1) begin
                                        hp_proto_arm <= 1'b0;
                                        hs_hp_phase(3'd1);
                                        hs_hp_oid(hp_proto[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_st(S_HEAP_WAIT);
                                        end else begin
                                            hp_proto_arm <= 1'b0;
                                            hs_hp_rval(V64_UNDEFINED);
                                            hs_st(hp_ret);
                                        end
                                    end else begin
                                        hs_hp_rval(V64_UNDEFINED);
                                        hs_st(hp_ret);
                                    end
                                end
                            end else begin
                                hs_hp_rval(vobj_rdata[63:0]);
                                hs_hp_tag(vobj_trdata);
                                hs_st(hp_ret);
                            end
                        end else if (hp_cmd == HP_OGETI)
                            hs_st(hp_ret);
                        else
                            hs_st(hp_ret);
                    end else if (hp_slot + 5'd1 < vobj_len_rdata[4:0]) begin
                        // Latch __proto__ while walking so tagged miss can
                        // follow it without a second combo scan.
                        if (!hp_v64 &&
                            (hp_cmd == HP_GETPROP || hp_cmd == HP_LOOKFN) &&
                            vobj_rdata[79:64] == id_proto)
                            hs_hp_proto(vobj_rdata[63:0]);
                        hp_next_slot();
                    end else begin
                        hs_hp_hit(1'b0);
                        if (hp_cmd == HP_GETPROP && hp_phase == 3'd0) begin
                            // Class getter/method: one (c,m) per clock.
                            cls_scan <= 1'b1;
                            cls_armed <= 1'b0;
                            cls_done <= 1'b0;
                            cls_ctor_mode <= 1'b0;
                            cls_c <= 4'd0;
                            cls_m <= 4'd0;
                            cls_cls <= vobj_cls_rdata;
                            cls_key <= {1'b0, hp_key[14:0]};
                            cls_mip_q <= 16'hFFFF;
                            cls_gip_q <= 16'hFFFF;
                            // Stay HEAP_CMP: cls_scan match is FFs this clock.
                        end else if (hp_cmd == HP_LOOKFN && hp_phase == 3'd0 &&
                            hp_v64 &&
                            hp_proto[63:48] == V64_TAG_PREFIX &&
                            hp_proto[47:44] == V64_KIND_OBJECT &&
                            hp_proto[31:0] < MAX_OBJ) begin
                            if (!hp_proto_arm) begin
                                hp_proto_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else if (vobj_alloc_rdata == 2'd1) begin
                                hp_proto_arm <= 1'b0;
                                hs_hp_phase(3'd1);
                                hs_hp_oid(hp_proto[12:0]);
                                hs_hp_slot(5'd0);
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                hp_proto_arm <= 1'b0;
                                hs_hp_rval(V64_UNDEFINED);
                                hs_hp_hit(1'b0);
                                hs_st(hp_ret);
                            end
                        end else if (hp_cmd == HP_LOOKFN && hp_phase == 3'd0 &&
                            !hp_v64 && hp_proto[15:0] != 16'hFFFF) begin
                            hs_hp_phase(3'd1);
                            hs_hp_oid(hp_proto[12:0]);
                            hs_hp_slot(5'd0);
                            hs_st(S_HEAP_WAIT);
                        end else if ((hp_cmd == HP_SETPROP ||
                                      hp_cmd == HP_SETIDX) &&
                                     vobj_len_rdata < OBJ_SLOTS[5:0]) begin
                            hs_hp_slot(vobj_len_rdata[4:0]);
                            begin vol_we <= 1'b1; vol_wa <= hp_oid; vol_wd <= vobj_len_rdata + 6'd1; end
                            e64_poke(6'd2, {3'd0, hp_oid},
                                     {58'd0, vobj_len_rdata + 6'd1});
                            if (!hp_v64)
                                ; // p3b: dead tagged write removed (obj_n)
                            hs_st(S_HEAP_WR);
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            running <= 1'b0; hs_st(S_DONE);
                        end else if (hp_cmd == HP_GETIDX) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                hs_vsp(vsp - 12'd1);
                            end else begin
                                stack_wr(sp - 8'd2, 32'd0, 3'd5);
                                sp <= sp - 8'd1;
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_GETPROP) begin
                            if (hp_v64) begin
                                vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                vst_win[0] <= V64_UNDEFINED;
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_hp_rval(hp_v64 ? V64_UNDEFINED : 64'd0);
                            hs_hp_hit(1'b0);
                            hs_st(hp_ret);
                        end
                    end
                end
                S_HEAP_WR: begin
                    if (hp_env) begin
                        if (!hp_hit) begin
                            begin vel_we <= 1'b1; vel_wa <= hp_eid[8:0]; vel_wd <= venv_len_rdata + 5'd1; end
                            e64_poke(6'd10, {6'd0, hp_eid},
                                     {59'd0, venv_len_rdata + 5'd1});
                        end
                        hs_vsp(vsp - 12'd1);
                        ctor_after_let();
                        hs_hp_env(1'b0);
                        hs_st(S_FETCH_WAIT);
                    end else if (hp_cmd == HP_OSETI) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hs_st(S_HEAP_WR);
                        end else begin
                            if (vobj_len_rdata < {3'd0, hp_qn} + {1'b0, hp_slot}) begin
                                begin vol_we <= 1'b1; vol_wa <= hp_oid;
                                      vol_wd <= {3'd0, hp_qn} + {1'b0, hp_slot}; end
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, {3'd0, hp_qn} + {1'b0, hp_slot}});
                                if (!hp_v64)
                                    ; // p3b: dead tagged write removed (obj_n)
                            end else if (!hp_v64)
                                ; // p3b: dead tagged write removed (obj_n)
                            hs_st(hp_ret);
                        end
                    end else if (hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX)
                    begin
                        // Image.src jmr:spr:N also writes width/height
                        // (phase 3→4→5). Do not combo-walk slots for that.
                        if (hp_phase == 3'd3) begin
                            hs_hp_key(id_width);
                            hs_hp_wval(v64_int32_number({16'd0, hp_spr_w}));
                            hs_hp_slot(5'd0);
                            hs_hp_len(vobj_len_rdata);
                            hs_hp_phase(3'd4);
                            hs_hp_hit(1'b0);
                            hs_st(S_HEAP_WAIT);
                        end else if (hp_phase == 3'd4) begin
                            hs_hp_key(id_height);
                            hs_hp_wval(v64_int32_number({16'd0, hp_spr_h}));
                            hs_hp_slot(5'd0);
                            hs_hp_len(vobj_len_rdata);
                            hs_hp_phase(3'd5);
                            hs_hp_hit(1'b0);
                            hs_st(S_HEAP_WAIT);
                        end else if (hp_phase == 3'd6) begin
                            // Image.onload = fn — invoke now (title img ready).
                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                            hs_vsp(vsp - 12'd1);
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd0);
                            hs_vcall_set_this(1'b1);
                            hs_vcall_this(v64_handle(
                                4'd5, vobj_gen_rdata, {19'd0, hp_oid}
                            ));
                            hs_vcall_ctor_val(V64_UNDEFINED);
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            // Do not hs_ip(ip+1) here: kind 3 ALLOC already
                            // stores return_ip=ip+1 (after SET_PROP). Doing
                            // both skipped the next op (fillStyle / fillText).
                            // onload CALL_VAL while a constructor is live.
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_st(S_V64_ALLOC);
                        end else if (hp_v64) begin
                            if (hp_cmd == HP_SETIDX) begin
                                vst_wr(vsp - 12'd3, hp_wval);
                                hs_vsp(vsp - 12'd2);
                            end else begin
                                vst_wr(vsp - 12'd2, hp_wval);
                                hs_vsp(vsp - 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            if (hp_cmd == HP_SETIDX) begin
                                stack_wr(sp - 8'd3, hp_wval[31:0], hp_tag);
                                sp <= sp - 8'd2;
                            end else begin
                                stack_wr(sp - 8'd2, hp_wval[31:0], hp_tag);
                                sp <= sp - 8'd1;
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else if (hp_cmd == HP_ASSIGN) begin
                        hs_hp_ss(hp_ss + 5'd1);
                        hs_hp_phase(3'd0);
                        hs_st(S_HEAP_WAIT);
                    end else
                        hs_st(hp_ret);
                end
                S_HEAP_AWR: begin
                    // flatten: beat 0 muxes varr_long[hp_aid]; write when
                    // hp_slot_arm (long_rdata valid). varr_we gated on arm.
                    //
                    // potential-bugs #53: first-entry hs_st, same discipline
                    // as S_HEAP_WAIT above. exec enters this state DIRECTLY
                    // (ARR_SET in-bounds, RET_VAL 0xfffc map-store), and
                    // without the hs_st the parent `state` FF never became
                    // S_HEAP_AWR — so `varr_we = (state == S_HEAP_AWR &&
                    // hp_slot_arm)` never fired and the element write was
                    // SILENTLY LOST (a[1] = 7 left the slot untouched, no
                    // fault; VARRPEEK showed the literal fill intact and the
                    // set absent). The hs_st also disables exec the next
                    // beat, stopping the leave_hold re-run. Reset slot_arm so
                    // the settle beat re-reads varr_long[hp_aid] under this
                    // state's own raddr mux.
                    if (casestate_q != S_HEAP_AWR) begin
                        hs_st(S_HEAP_AWR);
                        hp_slot_arm <= 1'b0;
                    end else if (!hp_slot_arm)
                        hp_slot_arm <= 1'b1;
                    else begin
                    hp_slot_arm <= 1'b0;
                    if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_aslot > 7'd1) begin
                            hs_hp_aslot(hp_aslot - 7'd2);
                            hs_hp_phase(3'd0);
                            hs_st(S_HEAP_WAIT);
                        end else begin
                            hs_hp_aslot(7'd0);
                            hs_hp_wval(hp_rval);
                            hs_hp_cmd(HP_ASETI);
                            hs_st(S_HEAP_AWR);
                        end
                    end else if (hp_cmd == HP_SPLICE) begin
                        if (hp_aslot + hp_lim[6:0] + 7'd1 < hp_alen) begin
                            hs_hp_aslot(hp_aslot + hp_lim[6:0] + 7'd1);
                            hs_st(S_HEAP_WAIT);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_PUSH) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hs_hp_aslot(hp_aslot + 7'd1);
                            hs_hp_wval(hp_qv[hp_qi[1:0] + 2'd1]);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_ARRSET) begin
                        if (hp_v64) begin
                            vst_wr(vsp - 12'd3, hp_wval);
                            hs_vsp(vsp - 12'd2);
                        end else begin
                            stack_wr(sp - 8'd3, hp_wval[31:0], hp_tag);
                            sp <= sp - 8'd2;
                        end
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end else
                        hs_st(hp_ret);
                    end
                end
                S_HEAP_FILL: begin
                    // Value64 stack→array: wait one clock for vst_rdata
                    // (1W1R), then write. Combo `VST_AT(hp_vbase+i) was a
                    // second port and killed ram_style=block.
                    // Wait one clock for vst_rdata (v64) or stack_rdata (32-bit).
                    //
                    // potential-bugs #53: first-entry hs_st, same discipline
                    // as S_HEAP_WAIT. exec enters DIRECTLY (push / unshift /
                    // ARR_SET grow / .length grow), and without the hs_st the
                    // parent `state` never became S_HEAP_FILL: the phase beat
                    // ran on the casestate overlay while `vst_raddr` (gated
                    // on parent state) still pointed at the DEFAULT slot, so
                    // the write stored a stale stack word — a.push(7) put the
                    // RECEIVER HANDLE (or stack[0]) in the slot. Reset the
                    // phase so the raddr settle beat runs under this state.
                    if (casestate_q != S_HEAP_FILL) begin
                        hs_st(S_HEAP_FILL);
                        if (hp_from_stack)
                            hs_hp_phase(3'd0);
                    end else if (hp_from_stack && hp_phase != 3'd1) begin
                        hs_hp_phase(3'd1);
                        hs_st(S_HEAP_FILL);
                    end else if ({1'b0, hp_aslot} + 8'd1 < hp_lim) begin
                        hs_hp_aslot(hp_aslot + 7'd1);
                        hs_hp_phase(3'd0);
                        hs_st(S_HEAP_FILL);
                    end else if (hp_cmd == HP_ARRSET) begin
                        hs_hp_aslot(hp_lim[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_phase(3'd0);
                        hs_st(S_HEAP_AWR);
                    end else begin
                        // MAKE_ARRAY handle after SRAM copy — writing it first
                        // made a[0] the array itself (PACMAN ARRAY_GET fault=255).
                        if (hp_make_arr) begin
                            if (hp_v64)
                                vst_wr(hp_vbase, hp_rval);
                            else begin
                                stack_wr(hp_vbase[10:0], hp_rval[31:0], 3'd2);
                            end
                            hs_hp_make_arr(1'b0);
                            hs_hp_phase(3'd0);
                            // MAKE_ARRAY of 16+ drops vsp by >=15; the TOS
                            // window only slides ±1/clock (or FF-copy if
                            // sh<16, which still misses `this` below 16
                            // elements). SET_PROP then peeks win[1] leftover
                            // instead of the receiver. PYTHON's stack is
                            // deep; refill win[1..] from BRAM. win[0] is
                            // the handle from vst_wr above.
                            // potential-bugs #58 (real cause): the refill
                            // gate was `hp_lim >= 16`, but the hazard is not
                            // the array's length — it is how far vsp DROPS.
                            // MAKE_ARRAY pops hp_lim and pushes 1, so the
                            // window shifts by hp_lim-1; slots at wi where
                            // wi + (hp_lim-1) >= 16 scroll in from BELOW the
                            // 16-deep window and are simply left stale (the
                            // shift loop can only copy from win[wi+sh]).
                            // `{ m: [15 numbers] }` is the smallest failing
                            // case: MAKE_OBJ + DUP put the object at depth
                            // 16 during the pushes, so after MAKE_ARRAY the
                            // object came back as garbage, LET_VAR stored the
                            // garbage, and the object AND array were
                            // unreachable (GC freed them: arr=0, cfg.m
                            // undefined, no fault). PACMAN's maze is exactly
                            // this shape — `{'map':[31 rows of 28]}` x12 —
                            // so the maze/beans data never existed: nothing
                            // to stroke, and empty beans read as "all eaten"
                            // (instant YOU WIN). A bare 31-row literal with
                            // nothing under it was fine, which is why the
                            // isolated probes passed.
                            // Refill iff a live slot would be stale:
                            // vsp + hp_lim > 17. Costs <=15 x2 clocks.
                            if (hp_v64 && vsp >= 12'd2 &&
                                (13'(vsp) + 13'(hp_lim) > 13'd17)) begin
                                vst_refill_i <= 4'd1;
                                vst_refill_arm <= 1'b0;
                                vst_refill_ret <= hp_ret;
                                vst_hold_win <= 1'b1;
                                // hold_win skips the vst_we window path, so
                                // plant TOS here (handle is hp_rval).
                                vst_win[0] <= hp_rval;
                                hs_st(S_V64_WIN_FILL);
                            end else
                                hs_st(hp_ret);
                        end else begin
                            hs_hp_phase(3'd0);
                            hs_st(hp_ret);
                        end
                    end
                end
                S_REL_ENV: begin
                    // One live env_sp slot per clock. Dup scan is one
                    // env_free slot/clock (not 32 SRAM ports).
                    if (env_sp == 6'd0 || rel_i >= rel_lim) begin
                        env_free_n <= rel_nn;
                        env_sp <= rel_saved;
                        bind_k <= 8'd0;
                        jn_rd_arm <= 1'b0;
                        vfe_rd_arm <= 1'b0;
                        vk_found <= 1'b0;
                        hs_st(rel_ret);
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                        bind_k <= 8'd0;
                        vk_found <= 1'b0;
                        vfe_rd_arm <= 1'b0;
                    end else if (bind_k < 8'd32) begin
                        if (!vfe_rd_arm)
                            vfe_rd_arm <= 1'b1;
                        else begin
                            if (bind_k < {2'd0, rel_nn} &&
                                e32_env_free_rdata == e32_env_oid_rdata)
                                vk_found <= 1'b1;
                            bind_k <= bind_k + 8'd1;
                            vfe_rd_arm <= 1'b0;
                        end
                    end else if (!vfe_rd_arm) begin
                        vfe_rd_arm <= 1'b1; // wait env_cap[rel_i] rdata
                    end else begin
                        if (!e32_env_cap_rdata) begin
                            if (rel_i == (rel_lim - 6'd1) &&
                                n_obj == (e32_env_oid_rdata + 16'd1))
                                n_obj <= e32_env_oid_rdata;
                            else if (!vk_found &&
                                     rel_nn < TAGGED_ENV_DEPTH[5:0] &&
                                     (!obj_keep_ok ||
                                      e32_env_oid_rdata < n_obj_keep))
                            begin
                                ; // p3b: dead tagged write removed (env_free)
                                rel_nn <= rel_nn + 6'd1;
                            end
                        end
                        rel_i <= rel_i + 6'd1;
                        jn_rd_arm <= 1'b0;
                        vfe_rd_arm <= 1'b0;
                        bind_k <= 8'd0;
                        vk_found <= 1'b0;
                    end
                end
                S_FREE_OBJ: begin
                    if (!valloc_rd_arm)
                        valloc_rd_arm <= 1'b1;
                    else if (valloc_i < MAX_OBJ &&
                        vobj_alloc_rdata == 2'd0) begin
                        vfree_ok <= 1'b1;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                        hs_valloc_i(valloc_i + 14'd1);
                        valloc_rd_arm <= 1'b0;
                    end else begin
                        vfree_ok <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end
                end
                S_FREE_ARR: begin
                    // potential-bugs #68: exec enters DIRECTLY for the
                    // filter/map result-array scan (state_n = S_FREE_ARR)
                    // with hp_ret = S_FETCH_WAIT. Without the standard
                    // first-entry guard the parent state stayed S_V64_EXEC,
                    // valloc_rd_arm was stale so the scan "completed" off a
                    // stale rdata, and the completion's hs_st(S_FETCH_WAIT)
                    // fetched from the parent's STALE code_raddr — the
                    // CALL_METH was never re-decoded: filter()/map()
                    // returned the callback fn and never ran it (INVADERS
                    // leaderboard, PACMAN filter). Seed ip/code so the
                    // FETCH_WAIT return re-decodes the SAME op.
                    if (casestate_q != S_FREE_ARR && state != S_FREE_ARR) begin
                        hs_st(S_FREE_ARR);
                        valloc_rd_arm <= 1'b0;
                        if (v64_on && e64_leave_hold) begin
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                        end
                    end else if (vfree_arr_long && valloc_i < 14'(MAX_ARR_SHORT)) begin
                        hs_valloc_i(14'(MAX_ARR_SHORT));
                    end else if (!valloc_rd_arm)
                        valloc_rd_arm <= 1'b1;
                    else if (valloc_i < MAX_ARR &&
                        !varr_valid_rdata &&
                        (valloc_i < 14'(MAX_ARR_SHORT) ||
                         !vlong_used_rdata) &&
                        (!vfree_arr_long ||
                         valloc_i >= 14'(MAX_ARR_SHORT))) begin
                        vfree_ok <= 1'b1;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end else if (valloc_i + 14'd1 < MAX_ARR) begin
                        hs_valloc_i(valloc_i + 14'd1);
                        valloc_rd_arm <= 1'b0;
                    end else begin
                        vfree_ok <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end
                end
                S_ARR_PROMOTE: begin
                    // Same handle; copy short SRAM into a free long phys row.
                    // First-entry latch: exec requests this state directly
                    // (arr.push / ARRAY_SET past ARR_SHORT_CAP). Without it
                    // the parent's state stayed S_V64_EXEC, so exec was
                    // re-enabled after a single beat and re-requested the
                    // promote forever — INVADERS' startGame push spun for the
                    // whole 64M frame and the game appeared to hang.
                    if (state != S_ARR_PROMOTE) begin
                        hs_st(S_ARR_PROMOTE);
                        vprom_from_exec <= 1'b1; // #57: exec-entered
                        jn_rd_arm <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        // S_ARR_PROMOTE is NOT in the hs64 list, so every
                        // muxed scalar below reads the PARENT's ff, not
                        // exec's. An exec-requested promote therefore scanned
                        // for a free long row starting from a stale valloc_i
                        // (left over from some earlier object alloc); with
                        // that >= MAX_ARR_LONG the scan fell straight through
                        // to "no free long row" and raised fault 3 with the
                        // heap almost empty (INVADERS: obj=646 of 1024,
                        // arr=25, every *ovf counter 0). Seed the parent's
                        // copies from exec here — same shape as the
                        // S_V64_WIN_FILL seed — and leave the parent's own
                        // JSON-parse entry (which sets these itself) alone.
                        if (v64_on && state == S_V64_EXEC) begin
                            hs_valloc_i(e64_valloc_i_q);
                            hs_hp_aid(e64_hp_aid_q);
                            vprom_copy <= e64_vprom_copy_q;
                        end
                    end else if (casestate_q != S_ARR_PROMOTE) begin
                        // potential-bugs #58: PARENT-requested entry (JSON
                        // parse). The exec guard above tests `state !=
                        // S_ARR_PROMOTE`, which is already false here, so it
                        // never fires — and jn_rd_arm / valloc_rd_arm kept
                        // whatever the previous state left them at. The very
                        // first *_rdata was then consumed a beat early:
                        //   * stale varr_long_rdata=1 -> the promote
                        //     "completed" with NO copy and without setting
                        //     varr_long[aid], so the caller's next element
                        //     wrapped into short slot (32 & 0x1F) = 0 and
                        //     overwrote element 0;
                        //   * stale vlong_used_rdata=0 -> handed out an
                        //     already-occupied long row, aliasing two arrays
                        //     onto one physical row.
                        // Both give "length correct, early slots garbage" —
                        // PACMAN's maze data AND beans data are >32 rows, so
                        // the maze drew nothing and
                        // JSON.stringify(beans.data).indexOf(0) < 0 was true
                        // on frame 1 (instant YOU WIN). exec-requested
                        // promotes (push / ARRAY_SET) were always fine
                        // because the guard above reset these.
                        // One extra beat; Port A rules unchanged.
                        jn_rd_arm <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (varr_long_rdata) begin
                        jn_rd_arm <= 1'b0;
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        if (vprom_from_exec) begin
                            // #78 (INVADERS bunker cell 32): an exec-requested
                            // promote must NOT jump straight back to
                            // S_V64_EXEC. The direct return resumed the
                            // decoder on a STALE code_rdata and a stale
                            // eval-stack window (the first promote survived
                            // only because its window happened to be
                            // coherent): CALL_METH push re-read its receiver
                            // one slot off, arr_ok failed, and the pending
                            // push fell into the generic method path and
                            // vanished - every promote after the first lost
                            // the boundary element. Resume through the
                            // standard FETCH_WAIT path: re-arm the fetch at
                            // exec's ip and re-enter EXEC with a coherent
                            // window. The re-decoded op cannot re-promote:
                            // varr_long[aid] is 1 now, which steers push /
                            // ARRAY_SET / unshift to their normal branches.
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_st(vprom_ret_eff);
                        end
                    end else if (!vprom_copy) begin
                        if (!valloc_rd_arm)
                            valloc_rd_arm <= 1'b1;
                        else if (valloc_i < 14'(MAX_ARR_LONG) &&
                            !vlong_used_rdata) begin
                            begin vlu_we <= 1'b1; vlu_wa <= valloc_i[6:0]; vlu_wd <= 1'b1; end
                            hp_prom_phys <= valloc_i[7:0];
                            vprom_copy <= 1'b1;
                            dc_i <= 8'd0;
                            hs_hp_phase(3'd0);
                            hp_prom_wr <= 1'b0;
                            jn_rd_arm <= 1'b0;
                            valloc_rd_arm <= 1'b0;
                        end else if (valloc_i + 14'd1 < 14'(MAX_ARR_LONG)) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else begin
                            machine_fault <= 1'b1;
                            fault_code <= 8'd3;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (dc_i >= varr_len_rdata) begin
                        begin vlo_we <= 1'b1; vlo_wa <= hp_aid[10:0]; vlo_wd <= 1'b1; end
                        begin vli_we <= 1'b1; vli_wa <= hp_aid[10:0]; vli_wd <= hp_prom_phys; end
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        jn_rd_arm <= 1'b0;
                        if (vprom_from_exec) begin
                            // #78 (INVADERS bunker cell 32): an exec-requested
                            // promote must NOT jump straight back to
                            // S_V64_EXEC. The direct return resumed the
                            // decoder on a STALE code_rdata and a stale
                            // eval-stack window (the first promote survived
                            // only because its window happened to be
                            // coherent): CALL_METH push re-read its receiver
                            // one slot off, arr_ok failed, and the pending
                            // push fell into the generic method path and
                            // vanished - every promote after the first lost
                            // the boundary element. Resume through the
                            // standard FETCH_WAIT path: re-arm the fetch at
                            // exec's ip and re-enter EXEC with a coherent
                            // window. The re-decoded op cannot re-promote:
                            // varr_long[aid] is 1 now, which steers push /
                            // ARRAY_SET / unshift to their normal branches.
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_st(vprom_ret_eff);
                        end
                    end else if (hp_phase == 3'd0) begin
                        hs_hp_cmd(HP_AGETI);
                        hs_hp_v64(1'b1);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_alen(varr_len_rdata);
                        hs_hp_ret(S_ARR_PROMOTE);
                        hs_hp_phase(3'd1);
                        hp_prom_wr <= 1'b0;
                        hs_st(S_HEAP_WAIT);
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_v64(1'b1);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_ret(S_ARR_PROMOTE);
                        hs_hp_phase(3'd0);
                        dc_i <= dc_i + 8'd1;
                        hp_prom_wr <= 1'b1;
                        hs_st(S_HEAP_AWR);
                    end
                end
                S_V64_BIND: begin
                    if (state != S_V64_BIND) begin
                        hs_st(S_V64_BIND);
                        // IIFE CALL_VAL clocks bind_* in exec then leave_hold
                        // → BIND. ALLOC/CTOR_PAD already wrote parent bind_*
                        // (state may still be EXEC on the overlay beat —
                        // only copy exec bind_* on leave_hold, else ctor
                        // field JUMP bind_ip is wiped).
                        if (v64_on && e64_leave_hold) begin
                            bind_mode <= e64_bind_mode_q;
                            bind_k <= e64_bind_k_q;
                            bind_n <= e64_bind_n_q;
                            bind_argc <= e64_bind_argc_q;
                            bind_base <= e64_bind_base_q;
                            bind_src <= e64_bind_src_q;
                            bind_vsp_next <= e64_bind_vsp_next_q;
                            bind_ip <= e64_bind_ip_q;
                            bind_ret <= st_t'(e64_bind_ret_q);
                            bind_rd_arm <= e64_bind_rd_arm_q;
                            // potential-bugs #62: the exec class-method hit
                            // (CALL_METH cm_mip) sets valloc_kind_n=3 and
                            // enters BIND with bind_ret=S_V64_ALLOC. But the
                            // valloc_kind/valloc_i muxes prefer the PARENT
                            // ff whenever state==S_V64_ALLOC, and this path
                            // never poked the ff — the ALLOC then ran with
                            // whatever the last exec-initiated alloc left
                            // (junk=[] left kind=1/count=0), so the method
                            // call pushed an empty array as its "result",
                            // never entered the body, and left argc args on
                            // the stack (INVADERS bunkers[bi].hitAt: vcsp
                            // climbed on every re-issue, RET warped into
                            // top-level code, vfe hit 8 → fault 3/5298).
                            // Latch exec's alloc request like ALLOC's own
                            // first-entry does.
                            hs_valloc_kind(e64_valloc_kind_q);
                            hs_valloc_i(e64_valloc_i_q);
                            hs_valloc_retried(e64_valloc_retried_q);
                            // potential-bugs #65: every BIND completion
                            // re-pokes hs_vcsp(vcsp_ff), but parent vcsp_ff
                            // only tracks parent POKES — exec-side RETs pop
                            // the exec register and leave the ff stale-HIGH
                            // (a getter dispatch inside the previous call
                            // raised it with hs_vcsp(e64+1)). The next
                            // exec-entered BIND then re-injected the stale
                            // ff: the ALLOC commit saw ff == e64+1, treated
                            // the call as parent-reserved, wrote the frame
                            // one slot high and leaked +1 vcsp per method
                            // call (DONKEY Mario.collision per platform per
                            // frame -> fault 2 at CSTK, game froze on the
                            // first game frame). Latch exec's vcsp like the
                            // rest of this block; parent-initiated BINDs
                            // never run this arm, so their fresh reserve
                            // (FOREACH / FRAME_RAF / LOOKFN) is untouched.
                            hs_vcsp(e64_vcsp_q);
                        end
                    // bind_mode 0: dest[k]=(k<argc)?src[k]:UNDEF, k=0..n-1
                    // bind_mode 1: dest[k]=dest[k+1] (drop callee), k=0..n-1
                    // bind_mode 2: dest[k+1]=src[k] downward
                    // bind_mode 3: write bind_ins at bind_base (after mode 2)
                    end else if (bind_mode == 2'd3) begin
                        vst_wr(bind_base, bind_ins);
                        begin
                            integer fd;
                            fd = integer'(bind_n);
                            if (fd >= 0 && fd < 16)
                                vst_win[fd[3:0]] <= bind_ins;
                        end
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        hs_vsp(bind_vsp_next);
                        hs_st(bind_ret);
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
                    end else if (bind_n == 8'd0) begin
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        hs_vsp(bind_vsp_next);
                        if (bind_mode != 2'd1) begin
                            hs_ip(bind_ip);
                            hs_code(15'(ops_base + bind_ip));
                        end
                        hs_st(bind_ret);
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
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
                            hs_vsp(bind_vsp_next);
                            if (bind_mode != 2'd1) begin
                                hs_ip(bind_ip);
                                hs_code(15'(ops_base + bind_ip));
                            end
                            hs_st(bind_ret);
                            if (vcsp_ff != 8'd0)
                                hs_vcsp(vcsp_ff);
                        end else
                            bind_k <= bind_k + 8'd1;
                    end
                end
                S_V64_MINMAX: begin
                    // Exec seeds minmax_*_n on CALL_NATIVE min/max then
                    // leave_hold. Parent FFs stay 0 unless copied — result
                    // wrote vsp=1 and `48+Math.min(...)*16` ADDed underflow
                    // (INVADERS Space → new Grid startY, fault 1).
                    if (state != S_V64_MINMAX) begin
                        hs_st(S_V64_MINMAX);
                        minmax_base <= e64_minmax_base_q;
                        minmax_acc <= e64_minmax_acc_q;
                        minmax_is_min <= e64_minmax_is_min_q;
                        minmax_k <= e64_minmax_k_q;
                        minmax_n <= e64_minmax_n_q;
                        bind_rd_arm <= 1'b0;
                    end else if (casestate_q != S_V64_MINMAX)
                        hs_st(S_V64_MINMAX);
                    else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                    end else if (minmax_k >= minmax_n) begin
                        vst_wr(minmax_base, minmax_acc);
                        hs_vsp(minmax_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        bind_rd_arm <= 1'b0;
                        hs_st(S_FETCH_WAIT);
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
                    // Exec RET_VAL/RETURN clocks refill_* into e64_*_q and
                    // leave_hold→WIN_FILL. Parent vst_refill_ret stays
                    // reset-IDLE unless HEAP MAKE_ARRAY wrote it — then
                    // hs_st(IDLE) after ctor `push(new Particle)` (INVADERS
                    // parks before rAF(animate); IPTRACE 85 then mux ip_ff).
                    if (vst_refill_ret == S_IDLE) begin
                        vst_refill_i <= e64_vst_refill_i_q;
                        vst_refill_arm <= e64_vst_refill_arm_q;
                        vst_refill_ret <= st_t'(e64_vst_refill_ret_q);
                        vst_hold_win <= e64_vst_hold_win_q;
                        // Exec vsp is truth. Sticky hs_m_vsp can leave
                        // parent vsp_ff at 0, so raddr underflowed and
                        // fillRect y/w from GET_PROP never saw the canvas
                        // (vdraw stayed 0). HEAP-initiated refill already
                        // has parent vsp (ret != IDLE).
                        hs_vsp(e64_vsp_q);
                        hs_st(S_V64_WIN_FILL);
                    end else if (!vst_refill_arm) begin
                        vst_refill_arm <= 1'b1;
                        hs_st(S_V64_WIN_FILL);
                    end else begin
                        vst_win[vst_refill_i] <= vst_rdata;
                        // +1 fills every live slot (ARRAY_SET needs win[2]
                        // when vsp==3). +2 skipped the handle.
                        if (vst_refill_i == 4'd15 ||
                            ({8'd0, vst_refill_i} + 12'd1 >= vsp)) begin
                            vst_hold_win <= 1'b0;
                            vst_refill_arm <= 1'b0;
                            hs_st(vst_refill_ret);
                            // So the next exec-initiated refill can seed.
                            vst_refill_ret <= S_IDLE;
                        end else begin
                            vst_refill_i <= vst_refill_i + 4'd1;
                            vst_refill_arm <= 1'b0;
                            hs_st(S_V64_WIN_FILL);
                        end
                    end
                end
                S_V64_METH: begin
                    // LOOKFN finished: own/proto function or unknown method.
                    if (!hp_v64) begin
                        if (hp_hit && hp_tag == 3'd4) begin
                            if (!tfn_rd_arm) begin
                                tfn_rd_arm <= 1'b1;
                                bind_k <= 8'd0;
                                jn_rd_arm <= 1'b0;
                            end else if (bind_k < vcall_argc[7:0]) begin
                                if (!jn_rd_arm)
                                    jn_rd_arm <= 1'b1;
                                else begin
                                    stack_wr(sp - vcall_argc[7:0] - 8'd1 + bind_k, e32_stack_rdata, e32_stack_tag_rdata);
                                    bind_k <= bind_k + 8'd1;
                                    jn_rd_arm <= 1'b0;
                                end
                            end else begin
                                logic [7:0] ac;
                                logic [15:0] oid, fip;
                                ac = vcall_argc[7:0];
                                oid = vcall_this[15:0];
                                fip = hp_rval[15:0];
                                sp <= sp - 8'd1;
                                enter_captured_fn(fip);
                                cstk_push_ret(ip + 16'd1, this_obj);
                                this_obj <= oid;
                                if (this_ok) begin
                                    ; // p3b: dead tagged write removed (vars)
                                    ; // p3b: dead tagged write removed (var_tag)
                                end
                                hs_ip(e32_tfn_entry_rdata);
                                hs_code(15'(ops_base + e32_tfn_entry_rdata));
                                tfn_rd_arm <= 1'b0;
                                jn_rd_arm <= 1'b0;
                                hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            begin
                                logic [7:0] ac;
                                ac = vcall_argc[7:0];
                                stack_wr(sp - ac - 8'd1, 32'sd0, 3'd5);
                                sp <= sp - ac;
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end else begin
                        if (!tfn_rd_arm)
                            tfn_rd_arm <= 1'b1;
                        else if (hp_hit &&
                            hp_rval[63:48] == V64_TAG_PREFIX &&
                            hp_rval[47:44] == 4'd7 &&
                            hp_rval[31:0] < MAX_OBJ &&
                            vfn_valid_rdata) begin
                        tfn_rd_arm <= 1'b0;
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
                        hs_vcall_value(1'b1);
                        hs_vcall_set_this(1'b1);
                        hs_vcall_ctor_val(V64_UNDEFINED);
                        hs_valloc_kind(2'd3);
                        hs_valloc_i({4'd0, venv_next});
                        hs_valloc_retried(1'b0);
                        // LOOKFN method: CALL_VAL-shaped ALLOC, not NEW_OBJ.
                        if (e64_vcsp_q < CSTK)
                            hs_vcsp(e64_vcsp_q + 8'd1);
                        hs_st(S_V64_ALLOC);
                    end else begin
                        tfn_rd_arm <= 1'b0;
                        vst_wr(vnat_base, (vobj_builtin_rdata == 4'd6)
                            ? v64_handle(4'd3, 12'd0, 32'd0)
                            : (vobj_builtin_rdata != 4'd0)
                            ? vcall_this : V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                    end
                end
                S_V64_FE_ELEM: begin
                    if (!hp_v64) begin
                        if (!vfe_rd_arm)
                            vfe_rd_arm <= 1'b1;
                        else begin
                        stack_wr(sp - 8'd1, hp_rval[31:0], hp_tag);
                        arm_release_env(e32_cs1_env_rdata, S_FETCH_WAIT);
                        hs_ip(e32_cs2_ip_rdata);
                        this_obj <= e32_cs2_this_rdata;
                        if (this_ok) begin
                            ; // p3b: dead tagged write removed (vars)
                            ; // p3b: dead tagged write removed (var_tag)
                        end
                        cstk_pop2();
                        hs_code(15'(ops_base + e32_cs2_ip_rdata));
                        vfe_rd_arm <= 1'b0;
                        end
                    end else begin
                    // findIndex: the AGETI slot IS the matched index.
                    vst_wr(vfe_base, e64_vfe_findidx_q
                        ? v64_int32_number({25'd0, hp_aslot})
                        : hp_rval);
                    hs_vsp(vfe_base + 12'd1);
                    hs_ip(vfe_ret);
                    hs_code(15'(ops_base + vfe_ret));
                    if (vfe_sp != 4'd0) begin
                        hs_m_vfe_pop <= 1'b1;
                        vfe_sp <= vfe_sp - 4'd1;
                    end else begin
                        vfe_arr <= V64_UNDEFINED;
                        vfe_fn <= V64_UNDEFINED;
                        vfe_mode <= 2'd0;
                        vfe_map <= V64_UNDEFINED;
                    end
                    hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_FE_FILTER: begin
                    if (!vfe_rd_arm) begin
                        vfe_rd_arm <= 1'b1;
                    end else begin
                        logic [7:0] fl;
                        fl = varr_len_rdata;
                        vfe_rd_arm <= 1'b0;
                        if (fl < ARR_CAP[7:0]) begin
                            varr_len_wr(vfe_map[11:0], fl + 8'd1);
                            e64_poke(6'd6, {4'd0, vfe_map[11:0]},
                                     {56'd0, fl + 8'd1});
                            hs_hp_cmd(HP_ASETI);
                            hs_hp_v64(1'b1);
                            hs_hp_from_stack(1'b0);
                            hs_hp_aid(vfe_map[11:0]);
                            hs_hp_aslot(fl[6:0]);
                            hs_hp_wval(hp_rval);
                            hs_hp_ret(S_V64_FOREACH);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(S_V64_FOREACH);
                    end
                end
                S_V64_IDXSCAN: begin
                    if (v64_equal(hp_rval, hp_wval)) begin
                        vst_wr(hp_vbase, v64_int32_number({24'd0, hp_aslot}));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_st(S_FETCH_WAIT);
                    end else if (hp_aslot + 7'd1 < hp_alen) begin
                        hs_hp_aslot(hp_aslot + 7'd1);
                        hs_st(S_HEAP_WAIT);
                    end else begin
                        vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_st(S_FETCH_WAIT);
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
                            hs_st(S_V64_JSON_PARSE);
                        end
                        4'd1: begin
                            imgd_w <= v64_to_uint32(hp_qv[0])[9:0];
                            imgd_h <= v64_to_uint32(hp_qv[1])[9:0];
                            imgd_x <= 10'd0; imgd_y <= 10'd0;
                            imgd_i <= 19'd0;
                            imgd_v64 <= 1'b1;
                            // potential-bugs #54 (putImageData leg): the
                            // destination corner and the return ip/base were
                            // exec FFs; the parent copies were stale (x0/y0
                            // only worked because the previous GET's guard
                            // left 0,0). S_IMGD_PUT is not in hs64, so its
                            // completion vst_wr(vnat_base)/hs_code(ops_base+ip)
                            // used the parent _ff leftovers.
                            imgd_x0 <= e64_imgd_x0_q;
                            imgd_y0 <= e64_imgd_y0_q;
                            hs_vnat_base(hp_vbase);
                            hs_ip(e64_ip_q);
                            hs_st(S_IMGD_PUT);
                        end
                        4'd2: begin
                            if (!valloc_rd_arm)
                                valloc_rd_arm <= 1'b1;
                            else begin
                            begin
                                logic [15:0] tl;
                                tl = 16'(v64_to_uint32(hp_qv[1]));
                                vmetrics_w <= (tl << 3);
                                valloc_rd_arm <= 1'b0;
                                if (vmetrics[63:48] == V64_TAG_PREFIX &&
                                    vmetrics[47:44] == V64_KIND_OBJECT &&
                                    vmetrics[31:0] < MAX_OBJ &&
                                    vobj_alloc_rdata == 2'd1)
                                begin
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(vmetrics[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd1);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number({16'd0, tl << 3});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    vst_wr(hp_vbase, vmetrics);
                                    hs_vsp(hp_vbase + 12'd1);
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    hs_valloc_metrics(1'b1);
                                    hs_vnat_base(hp_vbase);
                                    hs_valloc_kind(2'd0);
                                    hs_valloc_i(vobj_next);
                                    hs_valloc_retried(1'b0);
                                    hs_st(S_V64_ALLOC);
                                end
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
                            // The comment above said "same latch as replace"
                            // but the latches were missing: S_IDXSTR's
                            // completion reads hp_vbase/ip via the PARENT
                            // ffs (not hs64-muxed there), which were stale —
                            // r.indexOf(...) on a dynstr wrote the result
                            // nowhere and parked the program at the CALL ip
                            // (WAIT_FRAME, LETs after never ran).
                            hs_hp_vbase(e64_hp_vbase_q);
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            hs_st(S_IDXSTR);
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
                                vobj_builtin_rdata == 4'd6)
                                ; // regex pack already in hp_wval
                            // Dynstr-haystack leg never passes the S_NAMCPY
                            // guard: base/ip/vsp for the completion push
                            // also only lived in EXEC's FFs (the result
                            // handle was written to slot 0 instead of the
                            // receiver slot).
                            hs_vnat_base(e64_vnat_base_q);
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            // String.replace parent latches (PACMAN ghost
                            // AI: stringify(...).replace(/2/g,0)): v64_repl
                            // and repl_rch only ever lived in EXEC's FFs, so
                            // the S_REPL completion took the 32-BIT dynstr
                            // path (pushed onto the wrong stack — the result
                            // read back 0.0 / undefined). repl_pat0==0 means
                            // "pattern is a RegExp object" — those fields
                            // were parent-written by the nat=5 read; do not
                            // clobber them.
                            v64_repl <= e64_v64_repl_q;
                            repl_rch <= e64_repl_rch_q;
                            repl_did <= 1'b0;
                            if (e64_repl_pat0_q != 8'd0) begin
                                repl_pat0 <= e64_repl_pat0_q;
                                repl_pat1 <= 8'd0;
                                repl_nlen <= 8'd1;
                                repl_g <= e64_repl_g_q;
                            end
                            hs_st(S_REPL);
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
                                    hs_hp_nat(4'd4);
                                    hs_hp_cmd(HP_OGETI);
                                    hs_hp_v64(1'b1);
                                    hs_hp_oid(hp_si);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hs_hp_ret(S_V64_OGETI_NAT);
                                    hs_st(S_HEAP_WAIT);
                                end else
                                    hs_st(S_NAMCPY);
                            end
                        end
                        4'd6: begin
                            stack_wr(sp - 8'd1, hp_rval[31:0], 3'd0);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                        4'd7: begin
                            json_src <= hp_qv[0][13:0];
                            json_srclen <= hp_qv[1][13:0];
                            json_rp <= hp_qv[0][13:0];
                            if (hp_lim == 8'd1) begin
                                json_dst <= hp_qv[0][13:0] + hp_qv[1][13:0];
                                json_wp <= hp_qv[0][13:0] + hp_qv[1][13:0];
                                hs_st(S_REPL);
                            end else if (hp_lim == 8'd2)
                                hs_st(S_IDXSTR);
                            else
                                hs_st(S_JSON_PARSE);
                        end
                        4'd8: begin
                            imgd_w <= hp_qv[0][9:0];
                            imgd_h <= hp_qv[1][9:0];
                            hs_st(S_IMGD_PUT);
                        end
                        4'd9: begin
                            txt_rp <= 16'(hp_qv[0][13:0]);
                            txt_len <= (hp_qv[1][13:0] > 14'(TXT_MAX))
                                ? 7'(TXT_MAX) : 7'(hp_qv[1][13:0]);
                            txt_ph <= (hp_qv[1][13:0] == 14'd0) ? 4'd6 : 4'd4;
                            hs_st(S_TXT_LD);
                        end
                        4'd10: begin
                            repl_pat0 <= hp_qv[0][7:0];
                            repl_pat1 <= hp_qv[0][15:8];
                            repl_nlen <= hp_qv[0][23:16];
                            repl_g <= hp_qv[0][24];
                            if (hp_phase == 3'd1) begin
                                hs_hp_nat(4'd7);
                                hs_hp_lim(8'd1);
                                hs_hp_cmd(HP_OGETI);
                                hs_hp_v64(1'b0);
                                hs_hp_oid(hp_si);
                                hs_hp_slot(5'd0);
                                hs_hp_qn(3'd2);
                                hs_hp_qi(3'd0);
                                hs_hp_ret(S_V64_OGETI_NAT);
                                hs_st(S_HEAP_WAIT);
                            end else
                                hs_st(S_REPL);
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
                                ; // p3b: dead tagged write removed (obj_cls)
                                ; // p3b: dead tagged write removed (obj_n)
                                hs_hp_cmd(HP_OSETI);
                                hs_hp_v64(1'b0);
                                hs_hp_oid(moid[12:0]);
                                hs_hp_slot(5'd0);
                                hs_hp_qn(3'd1);
                                hs_hp_qi(3'd0);
                                hp_qk_ff[0] <= id_width;
                                hs_m_hp_qk <= 1'b1;
                                hp_qv_ff[0] <= {32'd0, 32'(px_) * 32'(tl)};
                                hs_m_hp_qv <= 1'b1;
                                hp_qt_ff[0] <= 3'd0;
                                hs_m_hp_qt <= 1'b1;
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
                                stack_wr(hp_vbase[10:0] - 11'd1, {16'd0, moid}, 3'd1);
                                sp <= hp_vbase[10:0];
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_hp_ret(S_FETCH_WAIT);
                                hs_st(S_HEAP_WR);
                            end
                        end
                        default: hs_st(S_FETCH_WAIT);
                    endcase
                end
                S_V64_DISPATCH: begin
                    // dispatchEvent(ev): find ev.type in the object's slots
                    // (2 beats/slot, default vobj_raddr = {hp_oid, hp_slot}),
                    // then run the FRAME_KEY listener scan in custom mode
                    // with the REAL event object (all user fields intact).
                    // No .type property = no listeners match = resume.
                    if (state != S_V64_DISPATCH && v64_on &&
                        e64_leave_hold) begin
                        hs_st(S_V64_DISPATCH);
                        vkev_event <= e64_hp_wval_q;
                        hs_hp_oid(e64_hp_wval_q[12:0]);
                        hs_hp_slot(5'd0);
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                        // resume point survives the listener calls (the
                        // muxed ip/vsp reflect the LISTENER's exec run by
                        // the time the scan ends).
                        vkey_ret_ip <= e64_ip_q;
                        vkey_ret_sp <= e64_vsp_q;
                        vkey_want_ev <= V64_UNDEFINED;
                        bind_rd_arm <= 1'b0;
                    end else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                    end else if ({1'b0, hp_slot} < vobj_len_rdata) begin
                        if (vobj_rdata[79:64] == id_type &&
                            id_type != 16'hFFFF) begin
                            vkey_want_ev <= vobj_rdata[63:0];
                            vkey_custom <= 1'b1;
                            vkey_li <= 5'd0;
                            // exec copy: the parent vlistener_n_ff is stale
                            // outside the hs64 states (registration happens
                            // in exec).
                            vkey_ln <= e64_vlistener_n_q;
                            bind_rd_arm <= 1'b0;
                            hs_st(S_V64_FRAME_KEY);
                        end else begin
                            hs_hp_slot(hp_slot + 5'd1);
                            bind_rd_arm <= 1'b0;
                        end
                    end else begin
                        bind_rd_arm <= 1'b0;
                        hs_ip(vkey_ret_ip);
                        hs_vsp(vkey_ret_sp);
                        hs_code(15'(ops_base + vkey_ret_ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_FRAME_KEY: begin
                    logic [63:0] want;
                    want = vkey_custom ? vkey_want_ev : v64_handle(
                        4'd4, 12'd0,
                        {16'd0, kev_q[kev_rp][8] ? id_keydown : id_keyup}
                    );
                    if (state != S_V64_FRAME_KEY) begin
                        hs_st(S_V64_FRAME_KEY);
                        dbg_key_scan <= dbg_key_scan + 16'd1;
                        bind_k <= 8'd0;
                        bind_rd_arm <= 1'b0;
                        vk_found <= 1'b0;
                        vk_pick <= 5'd0;
                    end else if (bind_k < 8'd16) begin
                        if (!bind_rd_arm)
                            bind_rd_arm <= 1'b1;
                        else begin
                            if (bind_k < {3'd0, vkey_ln}) begin
                                dbg_key_cmp <= dbg_key_cmp + 16'd1;
                                dbg_key_want <= want;
                                dbg_key_lastev <= vlistener_ev_rdata;
                            end
                            if (!vk_found && bind_k >= {3'd0, vkey_li} &&
                                bind_k < {3'd0, vkey_ln} && // #60 snapshot
                                v64_equal(vlistener_ev_rdata, want)) begin
                                vk_found <= 1'b1;
                                vk_pick <= bind_k[4:0];
                            end
                            bind_k <= bind_k + 8'd1;
                            bind_rd_arm <= 1'b0;
                        end
                    end else if (vk_found) begin
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0; hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            bind_rd_arm <= 1'b1;
                        end else if (bind_k == 8'd16) begin
                            vst_wr(vsp, vlistener_fn_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd17;
                            bind_rd_arm <= 1'b0;
                        end else if (bind_k == 8'd17) begin
                            vst_wr(vsp, vkev_event);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd18;
                        end else begin
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            vk_found <= 1'b0;
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd1);
                            dbg_key_call <= dbg_key_call + 16'd1;
                            vcallback_key <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            vkey_li <= vk_pick + 5'd1;
                            hs_st(S_V64_ALLOC);
                        end
                    end else if (vkey_custom) begin
                        // dispatchEvent: synchronous — all listeners ran;
                        // resume the program (exec already advanced ip and
                        // planted the true result). No kev entry to pop.
                        vkey_custom <= 1'b0;
                        vkey_li <= 5'd0;
                        bind_rd_arm <= 1'b0;
                        hs_ip(vkey_ret_ip);
                        hs_vsp(vkey_ret_sp);
                        hs_code(15'(ops_base + vkey_ret_ip));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        kev_rp <= kev_rp + 3'd1;
                        vkey_li <= 5'd0;
                        bind_rd_arm <= 1'b0;
                        hs_st(S_WAIT_FRAME);
                    end
                end
                S_V64_FRAME_RAF: begin
                    // First-entry latch, same as every other multi-beat arm.
                    // Entering from S_WAIT_FRAME the parent already hs_st'd
                    // here, but a rAF callback's RET_VAL requests this state
                    // from exec: casestate is FRAME_RAF for one beat while
                    // the parent's state stays S_V64_EXEC, so exec was
                    // re-enabled and ran the same RET_VAL twice — the second
                    // pass saw vcsp already 0 and faulted 2 (PACMAN).
                    if (state != S_V64_FRAME_RAF) begin
                        hs_st(S_V64_FRAME_RAF);
                    end else if (vraf_i < vraf_snap_n) begin
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            // Beat 0: push fn. Two vst_wr in one cycle kept
                            // only the timestamp; window shifts ±1 so vsp+2
                            // also desynced TOS (INVADERS rAF never re-armed).
                            vst_wr(vsp, vraf_snap[vraf_i]);
                            hs_vsp(vsp + 12'd1);
                            bind_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            // C3: sequential raf engine (see raf_pack_n).
                            // Stall this beat until the frame's timestamp
                            // is packed (~34 beats after vframe_no moved;
                            // dispatch reaches here much later, but the
                            // guard makes it correct, not just likely).
                            if (raf_ts_rdy) begin
                                vst_wr(vsp, raf_ts_q);
                                hs_vsp(vsp + 12'd1);
                                bind_k <= 8'd1;
                            end
                        end else begin
                            // Idle: ALLOC combo-reads last cycle's TOS window.
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            // Mark "a frame callback ran this frame". The
                            // host FRAME rpc ends a frame on
                            // (left_wait && back in S_WAIT_FRAME && cbip != 0);
                            // dbg_cb_ip was only ever written by the 32-bit
                            // path, so for HTML/Value64 titles FRAME could
                            // only end via the 2000-clock idle fallback. That
                            // works for a static splash but never during play
                            // (the VM leaves S_WAIT_FRAME again immediately),
                            // so every play frame burned the whole 64M cap and
                            // the GUI blocked on the RPC.
                            // potential-bugs #5: a function handle with
                            // oid 0 makes cb_ip 0, and the host FRAME
                            // exit tests cbip != 0. Use a plain marker.
                            dbg_cb_ip <= 16'h1;
                            dbg_raf_call <= dbg_raf_call + 16'd1;
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd1);
                            vcallback_raf <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            vraf_i <= vraf_i + 4'd1;
                            hs_st(S_V64_ALLOC);
                        end
                    end else begin
                        vraf_snap_n <= 4'd0;
                        bind_rd_arm <= 1'b0;
                        bind_k <= 8'd0;
                        vt_found <= 1'b0;
                        vt_pick <= 7'd0;
                        vt_best_due <= 32'sh7fffffff;
                        vt_best_id <= 32'sh7fffffff;
                        hs_st(S_V64_FRAME_TIMER);
                    end
                end
                S_V64_FRAME_TIMER: begin
                    // Same first-entry latch as S_V64_FRAME_RAF above.
                    if (state != S_V64_FRAME_TIMER) begin
                        hs_st(S_V64_FRAME_TIMER);
                    end else if (bind_k < 8'd64) begin
                        if (!bind_rd_arm)
                            bind_rd_arm <= 1'b1;
                        else begin
                            if (vtimer_valid_rdata &&
                                vtimer_due_rdata <= $signed(vframe_no) &&
                                (!vt_found || vtimer_due_rdata < vt_best_due ||
                                 (vtimer_due_rdata == vt_best_due &&
                                  vtimer_id_rdata < vt_best_id))) begin
                                vt_found <= 1'b1;
                                vt_pick <= bind_k[6:0];
                                vt_best_due <= vtimer_due_rdata;
                                vt_best_id <= vtimer_id_rdata;
                            end
                            bind_k <= bind_k + 8'd1;
                            bind_rd_arm <= 1'b0;
                        end
                    end else if (vt_found) begin
                        if (vcsp >= CSTK || vsp >= STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            bind_rd_arm <= 1'b1;
                        end else if (bind_k == 8'd64) begin
                            vst_wr(vsp, vtimer_fn_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd65;
                            bind_rd_arm <= 1'b0;
                        end else begin
                            bind_rd_arm <= 1'b0;
                            vt_found <= 1'b0;
                            if (vtimer_period_rdata < 64'sd0) begin
                                vtimer_valid[vt_pick[5:0]] <= 1'b0;
                                vtimer_n <= vtimer_n - 7'd1;
                            end else
                                begin vtd_we <= 1'b1; vtd_wa <= vt_pick[5:0];
                                      vtd_wd <= vtimer_due_rdata + vtimer_period_rdata[31:0]; end
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd0);
                            vcallback_timer <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_st(S_V64_ALLOC);
                        end
                    end else begin
                        bind_rd_arm <= 1'b0;
                        // PYTHON present(): scanout the back — but only if
                        // this frame drew. See fb_dirty.
                        dbg_frame_end <= dbg_frame_end + 16'd1;
                        // Swap ONLY if this frame drew. The unconditional
                        // swap alternated the two banks on every FRAME, so
                        // an event-driven screen that draws ONCE (DONKEY
                        // title, character select) flickered against the
                        // stale other bank ("flashing splash behind the
                        // menu"). A frame that drew still swaps (top-level
                        // snippets included: their writes set fb_dirty and
                        // this beat runs at that frame's end); an explicit
                        // swapBuffers already presented and cleared
                        // fb_dirty, so it is not double-swapped either.
                        if (fb_dirty) begin
                            fb_swap <= 1'b1;
                            fb_dirty <= 1'b0;
                            // Copy the presented frame into the new back
                            // bank before the next frame draws. A partial
                            // redraw (DONKEY charsel repaints only the
                            // 36x21 selector arrow) otherwise lands on the
                            // stale two-presents-ago bank and resurrects
                            // it ("old KONG splash returns on LUIGI").
                            // Browser canvas semantics: content persists.
                            clr_idx <= '0;
                            fbs_armed <= 1'b0;
                            fb_dump_sel <= 1'b1;
                            fb_dump_addr <= '0;
                            hs_st(S_FB_SYNC);
                        end else begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b1);
                            hs_vgc_wait_after(1'b1);
                            hs_st(S_V64_GC_CLEAR);
                        end
                    end
                end
                S_V64_DIV: begin
                    logic [53:0] shifted_rem, next_rem;
                    logic quotient_bit;
                    // Exec seeds vdiv_*_n on the OP_DIV leave_hold beat.
                    // Parent FFs stayed 0 after the one-heap split, so
                    // 640/1510 (and any non-2^k /) packed +0. setTransform
                    // then kept identity and fillText(x=755) clipped off glass.
                    if (vdiv_count == 8'd0) begin
                        vdiv_num <= e64_vdiv_num_q;
                        vdiv_den <= e64_vdiv_den_q;
                        vdiv_rem <= e64_vdiv_rem_q;
                        vdiv_quot <= e64_vdiv_quot_q;
                        vdiv_count <= e64_vdiv_count_q;
                        vdiv_exp <= e64_vdiv_exp_q;
                        vdiv_sign <= e64_vdiv_sign_q;
                    end else begin
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
                        hs_st(S_V64_DIV_FIN);
                    end
                end
                S_V64_DIV_FIN: begin
                    // flatten: pack is always_comb vdiv_pack_n (107-bit for
                    // must not inline into unique case).
                    vst_wr(vsp - 12'd2, vdiv_pack_n);
                    hs_vsp(vsp - 12'd1);
                    hs_ip(ip + 16'd1);
                    hs_code(15'(ops_base + ip + 16'd1));
                    hs_st(S_FETCH_WAIT);
                end
                S_V64_MOD: begin
                    logic [53:0] shifted_rem;
                    logic [52:0] next_rem;
                    // Same one-heap seed as S_V64_DIV: exec OP_MOD leaves
                    // the restoring state in *_q; parent FFs were 0.
                    if (vmod_count == 12'd0) begin
                        vmod_rem <= e64_vmod_rem_q;
                        vmod_den <= e64_vmod_den_q;
                        vmod_count <= e64_vmod_count_q;
                        vmod_exp <= e64_vmod_exp_q;
                        vmod_sign <= e64_vmod_sign_q;
                    end else begin
                    shifted_rem = {vmod_rem, 1'b0};
                    next_rem = (shifted_rem >= {1'b0, vmod_den})
                             ? 53'(shifted_rem - {1'b0, vmod_den})
                             : shifted_rem[52:0];
                    vmod_rem <= next_rem;
                    vmod_count <= vmod_count - 12'd1;
                    if (vmod_count == 12'd1) begin
                        // flatten: pack is always_comb vmod_pack_n from
                        // vmod_next_rem_n (same next_rem as this arm).
                        vst_wr(vsp - 12'd2, vmod_pack_n);
                        hs_vsp(vsp - 12'd1);
                        ctor_after_let();
                        hs_hp_env(1'b0);
                        hs_st(S_FETCH_WAIT);
                    end
                    end
                end
                S_DONE: begin
                    running <= 1'b0;
                    hs_st(S_IDLE);
                end
                default: begin
                    // No parent arm for the state exec asked for:
                    // record it instead of idling silently.
                    dbg_bad_state <= 8'(casestate);
                    hs_st(S_IDLE);
                end
            endcase
            // Exec faults lived only in e64_*_q; parent VMSTAT/FRAME saw
            // fault=0 and S_DONE→IDLE (inner rAF / JUMP looked clean).
            // Only while hs64. HEAP_CLR is not hs64; copying leftover
            // e64_fault during the next title's load made PACMAN/DONKEY
            // SNAP fault=2 and the GUI bounce to READY.
            // Also copy on the S_DONE transition itself: exec can fault
            // while the parent sits in a state that is not in the hs64 list
            // (S_ARR_PROMOTE, GC, ...), and then the machine stopped with
            // fault=0 and no evidence at all — a "silent halt". S_DONE only
            // happens when something deliberately stops, so this cannot
            // resurrect a stale exec fault during a title load (the
            // HEAP_CLR hazard the hs64 guard was protecting against).
            if (v64_on && e64_machine_fault_q &&
                (hs64 || casestate == S_DONE)) begin
                machine_fault <= 1'b1;
                fault_code <= e64_fault_code_q;
            end
            // vstack is 1024 deep; fault before any index wraps (measured
            // gameplay peak is 71, flat array literals push one slot per
            // element, so only a ~1000-element literal can get here).
            if (v64_on && vsp >= 12'd1008 && !machine_fault) begin
                machine_fault <= 1'b1;
                fault_code <= 8'd7;
            end
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
                hs_st(S_DONE);
            end
        end
    end
endmodule
`undef VST_AT
`undef VST_REL
