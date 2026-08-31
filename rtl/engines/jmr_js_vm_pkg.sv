// Shared VM FSM enum + opcode/heap command ids.
// Enum order is the VMSTAT sname table in sim/sim_main.cpp — do not reorder.
package jmr_js_vm_pkg;
    // ---- V1.5 standalone-compile arena ------------------------------
    // Mirrors functional_model/jsb_format.py. Live only while a compiler
    // program runs, when no title is loaded, so ASET art, SPR and IMGD are
    // all dead and can be borrowed.
    //   CART  art staging, packed 2 B/word at its final RUN-time addresses
    //   CSCR  compiler scratch (the hole above WORK, plus SPR), 1 B/word
    //   CIMG  assembled image (the IMGD snapshot region), 1 B/word
    // stgRead/stgWrite see CSCR and CIMG as ONE flat byte arena.
    localparam logic [20:0] SRC_SRAM_BASE  = 21'd1724416; // = console SOURCE
    localparam logic [20:0] CART_SRAM_BASE = 21'd0;
    localparam int unsigned CART_WORDS     = 1480704;     // = FB_SRAM_BASE
    localparam logic [20:0] CSCR_SRAM_BASE = 21'd1650688;
    localparam int unsigned CSCR_WORDS     = 73728;
    localparam logic [20:0] CIMG_SRAM_BASE = 21'd1789952;
    localparam int unsigned CIMG_WORDS     = 307200;
    localparam int unsigned CSTG_WORDS     = CSCR_WORDS + CIMG_WORDS;
    // SOURCE window, 1 B/word. srcWrite (nid 49) bounds against this; it is
    // also the ring modulus for src_fill_mode on titles larger than the
    // window (PACFAST is already 65,946 B).
    localparam int unsigned SOURCE_MAX     = 65536;
    // Arena header: 16-byte filename at byte offset 96, read by C_CMP_WAIT
    // for the cdone file-op dispatch (SAVE/DELETE/LOAD/mint-as).
    localparam int unsigned CSTG_HDR_NAME  = 96;
    localparam int unsigned CSTG_HDR_NAMEN = 16;

    // Flat arena byte index -> absolute SRAM word.
    function automatic logic [20:0] cstg_word(input logic [20:0] i);
        cstg_word = (i < 21'(CSCR_WORDS))
            ? (CSCR_SRAM_BASE + i)
            : (CIMG_SRAM_BASE + (i - 21'(CSCR_WORDS)));
    endfunction

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
    localparam int CODE_WORDS = 20480; // 2026-08-21(final): see parent
    localparam int MAX_CONSTS = 1024;
    localparam int MAX_VARS   = 512;
    localparam int STACK_DEPTH = 2048;
    localparam int MW = 640;
    localparam int MH = 480;
    localparam int FB_PIXELS = MW * MH;
    localparam int MAX_OBJ = 960;      // 2026-08-21(final): see parent
    localparam int OBJ_SLOTS = 32;
    localparam int MAX_ARR_SHORT = 1536;
    localparam int ARR_SHORT_CAP = 32;
    localparam int MAX_ARR_LONG = 12;  // 2026-08-21(final): see parent
    localparam int MAX_ARR = MAX_ARR_SHORT + MAX_ARR_LONG;
    localparam int ENV_DEPTH = 384;    // 2026-08-21(final): 256 corrupted PACMAN's BFS recursion; see parent
    localparam int TAGGED_ENV_DEPTH = 32;
    localparam int ENV_SLOTS = 16;
    localparam int TIMER_DEPTH = 64;
    localparam int CSTK = 128;
    localparam int JSON_CAP = 8192;
    localparam int JSON_STK = 32;
    localparam int ARR_CAP = 128;
    localparam int MAX_CLS = 16;
    localparam int NAME_CAP = 32768;
    localparam int MAX_FN_PROTO = 64;
    localparam int MAX_CMETH = 16;
    localparam int TXT_MAX = 64;
    localparam int PATH_MAX = 16;
    localparam int MAX_SPR = 16;
    localparam logic signed [31:0] FX_ONE = 32'sh0001_0000;
    localparam logic [15:0] CLS_FN = 16'hFFEF;
    localparam logic [15:0] CLS_REGEX = 16'hFFEE;
    localparam logic [15:0] CLS_DYNSTR = 16'hFFED;
    localparam logic [15:0] CLS_IMGD = 16'hFFEC;
    localparam logic [15:0] CLS_ENV = 16'hFFEA;

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
        // fillRect x/y/w/h from vstack SRAM (TOS window can still hold the
        // last literal bar while ADD/MUL results are only in SRAM).
        S_V64_RECT_LD,
        // Parent-only p_clr walk placeholder — keeps this enum numerically
        // aligned with jmr_js_vm's local st_t (which has S_HEAP_CLR here).
        S_HEAP_CLR,
        // #40 Array.slice: sequential AGETI->ASETI element copy (appended
        // so existing sname= indices stay valid).
        S_V64_SLICE,
        // #41 Array.sort: bubble walk, one comparator call per compare.
        S_V64_SORT
        // Keep numerically aligned with the parent's enum tail (the parent
        // decodes exec state_n requests by the same encoding).
        , S_FB_SYNC
        , S_V64_DISPATCH
        // V1.5 standalone compile. ONE state serves srcByte / stgRead /
        // stgWrite / artWrite2 via a mode select, so six natives cost a
        // single encoding — the scarce resource here is st_t entries
        // (112 of 128 before this), not LUTs.
        , S_CSRAM
    } st_t;
endpackage
