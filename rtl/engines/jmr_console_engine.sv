// Standalone READY console — BASIC console_engine method + FAT32 storage.
// Verbs: HELP / DIR / LOAD / SAVE / REMOVE / LIST / MEM / NEW / RUN
// HTML RUN: host compile-on-RUN streams ProgramImage over PROG (missing → ?NH;
// never silently run invaders_jsb.hex). Card is HTML only.
//
// Section map (C_* states):
//   input:    C_IDLE, C_ECHO, C_PARSE
//   replies:  C_REPLY  (sel 0=HELP 1=MEM 2=OK 3=?SN ERROR 4=?IO
//                       5=LOADED 6=?FN FILE NOT FOUND 7=?NB 8=-- MORE --)
//   disk:     C_DIR / C_LOAD / C_SAVE / C_REMOVE / C_LD_* / C_SV_* / C_JSB_*
//   listing:  C_LIST, C_LIST_WRAP*, C_MORE
//   edit/run: C_EDIT, C_RUN (compile-on-RUN → ProgramImage → VM)
module jmr_console_engine (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,       // standalone & idle
    // Keyboard FIFO
    input  logic        kbd_empty,
    input  logic [7:0]  kbd_data,
    output logic        kbd_pop,
    output logic        kbd_clear,
    // Video
    input  logic        video_busy,
    output logic        cls,
    output logic        put_en,
    output logic [7:0]  put_char,
    output logic        print_nl,
    // Status
    output logic        ready_lit,
    // Silicon games ladder: pulse when monitor sees RUN (RECTDEMO only)
    output logic        run_pulse,
    // NEW: start bytecode VM after .JSB loaded into code BRAM
    output logic        vm_start,
    // NEW: NEW/CLS halt the VM so leftover game FB does not stick after NEW
    output logic        halt_pulse,
    // NEW: write port into VM code_mem
    output logic        code_we,
    output logic [14:0] code_waddr,
    output logic [31:0] code_wdata,
    // NEW: ASET section → external asset SRAM (jmr_sram_port write master)
    output logic        sram_req,
    output logic        sram_we,
    output logic [20:0] sram_addr,
    output logic [15:0] sram_wdata,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack,
    // NEW: ASET palette (payload bytes 0..767 = 256×RGB888) → palette BRAM
    output logic        pal_we,
    output logic [7:0]  pal_waddr,
    output logic [23:0] pal_wdata,
    // NEW: storage_engine (BASIC handshake)
    output logic        stor_open,
    output logic [7:0]  stor_mode,
    output logic [7:0]  stor_chan,
    output logic [15:0] stor_name_addr,
    output logic [7:0]  stor_name_len,
    output logic        stor_close,
    output logic        stor_readline,
    output logic        stor_get_byte,
    input  logic [7:0]  stor_get_data,
    output logic        stor_nl_scan,     // NEW: count remaining 0x0A per sector
    input  logic [15:0] stor_nl_count,
    output logic        stor_putc,
    output logic [7:0]  stor_putc_data,
    output logic        stor_dir,
    output logic        stor_dir_next,
    output logic        stor_delete,
    input  logic        stor_busy,
    input  logic        stor_done,
    input  logic        stor_err,
    input  logic        stor_eof,
    input  logic [7:0]  stor_line_len,
    // NEW: work RAM master (NAME_BUF 0xB850, STORAGE_BUFFER 0xBB00)
    // SOURCE is a dedicated 128 KiB BRAM — not the 12 KB work map.
    output logic        mem_en,
    output logic        mem_we,
    output logic [15:0] mem_addr,
    output logic [7:0]  mem_wdata,
    input  logic [7:0]  mem_rdata,
    input  logic        mem_gnt,
    // NEW: HTML RUN streams compiled .JSH over PROG (not FAT). Sim uses JSHLOAD.
    input  logic        jsb_tether_stb = 1'b0,
    input  logic [7:0]  jsb_tether_data = 8'd0,
    input  logic        jsb_tether_eof = 1'b0,
    output logic        jsb_tether_rdy,
    // NEW: FPGA-SIM RAM LOAD — host already poked SOURCE/src_len, so LOAD skips
    // the FAT open and announces with sim_src_lines. Tied 0 on the board.
    input  logic        sim_src_bypass = 1'b0,
    input  logic [15:0] sim_src_lines = 16'd0
);
    localparam logic [15:0] NAME_BUF        = 16'hB850;
    localparam logic [15:0] STORAGE_BUFFER  = 16'hBB00;
    // Dedicated SOURCE BRAM (INVADERS/PACMAN HTML). ASET SRAM stays art from 0.
    // 131072 -> 65536: 13 BRAM tiles back. Card .HTM copies are squashed
    // (make_sd_image) — every title's source fits except MK (85K), whose
    // LIST shows the first 64K; oversize LOAD keeps the prefix and RUN
    // compiles from the host file regardless (C_LD_RD "SOURCE full" arm).
    localparam int unsigned SOURCE_MAX      = 65536;
    // 2026-08-22 LUTRAM fit: source_mem moved to the external 4MB SRAM
    // (words SRC_SRAM_BASE..+SOURCE_MAX-1, one byte per 16-bit word). The
    // old on-chip array was 8.2k LUTRAM against a failing 46.2k cap. The
    // internal 1-beat req/gnt protocol is kept; consumers already wait on
    // src_gnt, so the extra ack latency is absorbed by the protocol.
    localparam logic [20:0] SRC_SRAM_BASE = 21'd1724416; // below IMGD region
    logic        src_req, src_we, src_gnt;
    logic [16:0] src_addr;
    logic [7:0]  src_wdata, src_rdata;
    logic        srcb_pend, srcb_we_l;
    logic [7:0]  srcb_wd_l;

    typedef enum logic [6:0] {
        C_BOOT_CLS, C_BOOT_MSG, C_PROMPT, C_IDLE, C_ECHO, C_WAIT_VIDEO,
        C_EXEC, C_REPLY,
        // DIR
        C_DIR0, C_DIR0W, C_DIRN, C_DIRNW, C_DIR_RD, C_DIR_CH, C_DIR_PUT, C_DIR_NL,
        // name parse / write for LOAD SAVE REMOVE
        C_PF, C_PF2, C_NWR, C_NWR_W,
        // LOAD
        C_LD_OPEN, C_LD_OPENW, C_LD_RL, C_LD_RLW,
        C_LD_RD, C_LD_RDW, C_LD_WRW, C_LD_NLW, C_LD_CLOSE, C_LD_CLOSEW,
        C_LD_GB, C_LD_GBW, C_LD_GB_WR, // HTML: byte-copy into SOURCE (no 128-char ?LS)
        C_LD_NLSCANW, C_LD_ANN_SP, C_LD_ANN_NAME, C_LD_ANN_PAR, C_LD_ANN_TAIL,
        // SAVE
        C_SV_OPEN, C_SV_OPENW, C_SV_RD, C_SV_RDW, C_SV_PUT, C_SV_PUTW, C_SV_CLOSE, C_SV_CLOSEW,
        // REMOVE
        C_RM, C_RMW,
        // NEW: numbered LIST + MORE + ranges (BASIC method)
        C_LIST_PARSE, C_LIST_PAR_LO, C_LIST_PAR_HI,
        C_LIST_INIT, C_LIST_LINE, C_LIST_PEEL, C_LIST_EMIT_DIG,
        C_LIST_SP, C_LIST_RD_GO, C_LIST_RD, C_LIST_CH, C_LIST_PUT,
        C_LIST_PUT_LAST, C_LIST_NL_FORCE, C_LIST_NL, C_LIST_WRAP, C_LIST_WRAP_PAGE,
        C_LIST_MORE, C_LIST_WAIT,
        // NEW: HTML LIST re-streams the file from the card (SOURCE holds 128K)
        C_LIST_CNWR, C_LIST_CNWR_W, C_LIST_COPEN, C_LIST_COPENW,
        C_LIST_CARD_GB, C_LIST_CARD_GBW, C_LIST_CARD_FIRST, C_LIST_PUT_CARD,
        C_LIST_CCLOSE, C_LIST_CCLOSEW,
        // NEW: CLS + EDIT n
        C_CLS, C_EDIT_PARSE, C_EDIT_FIND, C_EDIT_RD, C_EDIT_CH,
        C_EDIT_SHOW, C_EDIT_PEEL, C_EDIT_EMIT, C_EDIT_SP, C_EDIT_BODY,
        C_EDIT_BODY_RD, C_EDIT_BODY_CH, C_EDIT_BODY_PUT, C_EDIT_NL, C_EDIT_ARM,
        C_EDIT_REPL, C_EDIT_GROW, C_EDIT_GROW_RD, C_EDIT_GROW_WR,
        C_EDIT_SHRINK, C_EDIT_SHRINK_RD, C_EDIT_SHRINK_WR,
        C_EDIT_WR_NEW, C_EDIT_WR_WAIT, C_EDIT_WR_NL,
        // NEW: load companion .JSB from FAT into VM code BRAM
        C_JSB_PREP, C_JSB_NWR, C_JSB_NWR_W, C_JSB_OPEN, C_JSB_OPENW,
        C_JSB_GB, C_JSB_GBW, C_JSB_CLOSE, C_JSB_CLOSEW,
        C_JSB_SRAMW, // NEW: wait asset-SRAM write ack (ASET payload word)
        C_JSB_PEEK, C_JSB_PEEKW, // NEW: code-BRAM full — fail loud if more bytes
        C_JSB_TETHER, C_JSB_FEED, C_JSB_TEOF // NEW: PROG/host .JSH stream (no FAT)
    } cstate_t;
    cstate_t state, ret_state;

    logic [7:0] line [0:127];
    logic [6:0] line_len;
    logic [6:0] msg_idx;
    logic [7:0] ch;
    logic [3:0] reply_sel;
    logic [6:0] reply_idx;
    logic [6:0] name_i, name_start, name_len_r;
    // C_NWR walk keeps the last five upcased name chars in a shift
    // register, so the .HTM/.HTML/.JS suffix classify at walk end reads
    // fixed positions instead of five 127:1 dynamic muxes off
    // name_start+name_len_r (run-32's -1.06 path family). tail[0] is the
    // most recent char. RECTDEMO likewise compares src_name, which the
    // same walk already captures upcased at fixed indices.
    logic [7:0] name_tail [0:4];
    // Number-parse char pipeline (run-33 residual: name_i -> 127:1 line
    // mux -> digit classify -> state CE was 13 LUT levels, -0.496). The
    // parse states read ch_ni_q and stall one beat via (ni_q != name_i)
    // whenever the index moved, so each loop iteration self-paces to two
    // beats. line[] is frozen post-Enter, so the pipe is always coherent.
    logic [7:0] ch_ni_q;
    logic [6:0] ni_q;
    logic [7:0] dir_n, dir_idx;
    logic [17:0] src_len /*verilator public_flat_rw*/;     // bytes in SOURCE BRAM (0..131072)
    logic [17:0] src_i;
    logic [7:0]  rd_ch;
    logic        cmd_is_load, cmd_is_save, cmd_is_remove;
    // NEW: last LOADed name (upcased) — classify HTML vs JS vs RECTDEMO
    logic [7:0]  src_name [0:15] /*verilator public_flat_rw*/;
    logic [4:0]  src_name_len /*verilator public_flat_rw*/;
    logic        src_is_rectdemo /*verilator public_flat_rw*/;
    logic        src_is_html /*verilator public_flat_rw*/;   // .HTM / .HTML — RUN loads .JSH (else ?NH)
    logic        src_is_js /*verilator public_flat_rw*/;     // .JS — RUN loads companion .JSB
    logic        jsb_want_jsh;  // NEW: HTML sidecar uses .JSH not .JSB
    // Board directive 2026-08-25: no wait may hard-wedge the console.
    // C_JSB_TETHER waits on the HOST (the protocol has no board->host
    // request: the host only compiles when it saw RUN typed through the
    // GUI, so a PS/2 RUN waits forever). ESC aborts; ~10.7s of stream
    // silence (2^30 clks, reset per byte) aborts too. And a generic
    // storage watchdog: armed on any stor strobe, cleared on stor_done,
    // ~32s (longer than storage's own 21.5s op watchdog, so storage
    // always errors first and this is pure belt-and-braces).
    logic [29:0] teth_wd;
    logic [31:0] cons_stor_wd;
    logic        cons_stor_arm;
    logic        jsb_tether_mode; // NEW: HTML RUN — bytes from PROG, not FAT
    logic [7:0]  jsb_din;         // NEW: latched stream byte (FAT or tether)
    // NEW: JSB stream packer
    logic [14:0] jsb_waddr;
    logic [1:0]  jsb_bi;        // byte index 0..3 within word
    logic [31:0] jsb_word;
    logic [7:0]  jsb_name_len;
    // NEW: ASET stream splitter — code bytes → code BRAM (as before), ASET
    // payload → asset SRAM (palette bytes 0..767 also tap the palette BRAM)
    logic [22:0] jsb_boff;      // byte offset within the .JSH stream
    logic [22:0] jsb_aset_off;  // header u32 at bytes 12..15 (0 = none yet)
    logic        jsb_has_aset;  // header flags bit1 (byte 10 bit1)
    logic        aset_seen;     // "ASET" magic matched at aset_off
    logic [22:0] aset_len;      // payload length from the ASET header
    logic [22:0] aset_pay;      // payload byte counter == SRAM byte address
    logic [7:0]  sram_lo;       // low byte latch for 16-bit word packing
    logic        sram_last;     // final odd-byte flush → CLOSE after ack
    logic [7:0]  pal_r, pal_g;  // palette byte packer (RGB triplets)
    logic [7:0]  pal_idx;
    logic [1:0]  pal_ph;
    logic [22:0] aset_rel;      // byte offset inside the ASET section
    assign aset_rel = jsb_boff - jsb_aset_off;
    assign jsb_tether_rdy = (state == C_JSB_TETHER);
    logic        ld_err;        // NEW: LOAD ?LS/?IO sticky until CLOSEW
    logic [15:0] ld_nlines;     // NEW: newline count for LOADED NAME (N LINES)
    logic        ld_need_eol;   // last HTML byte was not NL
    logic        ld_ann;        // announce name+count after LOADED
    // NEW: LIST range / MORE (display numbers 10,20,… like PYTHON)
    logic        list_page;
    logic [15:0] list_lo, list_hi, list_disp;
    logic [3:0]  list_on_page;
    logic [5:0]  list_col;        // 0..63 glass wrap (FM _list_paged twin)
    logic        list_wrap_more;  // MORE after a wrap, resume same source line
    logic        dir_more;       // MORE issued from DIR paging (resume C_DIRN)
    logic        list_eat_nl;     // drop leftover CR from LINE so first MORE waits
    logic        list_skip;       // line outside range — consume without print
    logic        list_from_card;  // HTML LIST: get_byte from FAT, not SOURCE
    logic        list_bol;        // beginning of line — emit number first
    logic [15:0] peel_mag, peel_q;
    logic [3:0]  peel_rem;
    logic [4:0]  peel_bit;
    logic [7:0]  digs [0:4];
    logic [2:0]  dig_n, dig_i;
    // NEW: EDIT n
    logic        edit_pending;
    logic [15:0] edit_disp;
    logic [17:0] edit_start, edit_end;  // byte offsets of target line
    logic [17:0] edit_copy_i, edit_new_len;
    logic [4:0]  peel_tmp;  // NEW: /10 peel scratch (no nested logic decls)

    // Case-insensitive compare helpers (FIFO no longer folds a-z)
    function automatic logic [7:0] up(input logic [7:0] c);
        up = (c >= 8'h61 && c <= 8'h7A) ? (c - 8'h20) : c;
    endfunction
    function automatic logic is_sp(input logic [7:0] c);
        is_sp = (c == " ");
    endfunction

    // C_EXEC dispatch predicates, registered every clk. line/line_len
    // change at most one char per keystroke, and C_EXEC always runs at
    // least two cycles after the last edit (Enter -> C_WAIT_VIDEO ->
    // C_EXEC), so the one-cycle predicate lag can never be observed.
    // This kills run-32's residual worst path (-1.249ns, 14 LUT levels:
    // the priority chain ANDed each arm's len+char compares in one
    // cycle); the chain now selects among registered single bits.
    logic p_help_q, p_dir_q, p_cls_q, p_list_q, p_edit_q, p_mem_q,
          p_new_q, p_run_q, p_load_q, p_save_q, p_remove_q;
    always_ff @(posedge clk) begin
        p_help_q <= (line_len == 4 && up(line[0])=="H" && up(line[1])=="E" && up(line[2])=="L" && up(line[3])=="P");
        p_dir_q  <= (line_len == 3 && up(line[0])=="D" && up(line[1])=="I" && up(line[2])=="R");
        p_cls_q  <= (line_len == 3 && up(line[0])=="C" && up(line[1])=="L" && up(line[2])=="S");
        p_list_q <= (line_len >= 4 && up(line[0])=="L" && up(line[1])=="I" && up(line[2])=="S" && up(line[3])=="T" && (line_len == 4 || is_sp(line[4])));
        p_edit_q <= (line_len >= 5 && up(line[0])=="E" && up(line[1])=="D" && up(line[2])=="I" && up(line[3])=="T" && is_sp(line[4]));
        p_mem_q  <= (line_len == 3 && up(line[0])=="M" && up(line[1])=="E" && up(line[2])=="M");
        p_new_q  <= (line_len == 3 && up(line[0])=="N" && up(line[1])=="E" && up(line[2])=="W");
        p_run_q  <= (line_len >= 3 && up(line[0])=="R" && up(line[1])=="U" && up(line[2])=="N" && (line_len == 3 || is_sp(line[3])));
        p_load_q <= (line_len >= 5 && up(line[0])=="L" && up(line[1])=="O" && up(line[2])=="A" && up(line[3])=="D" && is_sp(line[4]));
        p_save_q <= (line_len >= 5 && up(line[0])=="S" && up(line[1])=="A" && up(line[2])=="V" && up(line[3])=="E" && is_sp(line[4]));
        p_remove_q <= (line_len >= 7 && up(line[0])=="R" && up(line[1])=="E" && up(line[2])=="M" && up(line[3])=="O" && up(line[4])=="V" && up(line[5])=="E" && is_sp(line[6]));
    end
    always_ff @(posedge clk) begin
        ch_ni_q <= line[name_i];
        ni_q    <= name_i;
    end


    function automatic logic [7:0] banner_char(input logic [6:0] i);
        case (i)
            0: banner_char = "J"; 1: banner_char = "M"; 2: banner_char = "R";
            3: banner_char = " "; 4: banner_char = "J"; 5: banner_char = "S";
            6: banner_char = "-"; 7: banner_char = "N"; 8: banner_char = "A";
            9: banner_char = "T"; 10: banner_char = "I"; 11: banner_char = "V";
            12: banner_char = "E"; 13: banner_char = "-"; 14: banner_char = "C";
            15: banner_char = "P"; 16: banner_char = "U"; 17: banner_char = " ";
            18: banner_char = "V"; 19: banner_char = "1"; 20: banner_char = ".";
            21: banner_char = "0";
            default: banner_char = 8'h00;
        endcase
    endfunction

    function automatic logic [7:0] ready_char(input logic [6:0] i);
        case (i)
            0: ready_char = "R"; 1: ready_char = "E"; 2: ready_char = "A";
            3: ready_char = "D"; 4: ready_char = "Y";
            default: ready_char = 8'h00;
        endcase
    endfunction

    // 0=HELP 1=MEM 2=OK 3=?SN ERROR 4=?IO 5=LOADED 6=?FN FILE NOT FOUND 7=?NB 8=-- MORE --
    // 9=?NH (HTML not runnable yet) 10=?LS 11=HTML (LIST stub)
    function automatic logic [7:0] reply_char(input logic [3:0] sel, input logic [6:0] i);
        case (sel)
            4'd0: case (i)
                // DIR LOAD SAVE NEW LIST EDIT RUN (same verbs as PYTHON HELP)
                0: reply_char="D";1: reply_char="I";2: reply_char="R";3: reply_char=" ";
                4: reply_char="L";5: reply_char="O";6: reply_char="A";7: reply_char="D";
                8: reply_char=" ";9: reply_char="S";10: reply_char="A";11: reply_char="V";
                12: reply_char="E";13: reply_char=" ";14: reply_char="N";15: reply_char="E";
                16: reply_char="W";17: reply_char=" ";18: reply_char="L";19: reply_char="I";
                20: reply_char="S";21: reply_char="T";22: reply_char=" ";23: reply_char="E";
                24: reply_char="D";25: reply_char="I";26: reply_char="T";27: reply_char=" ";
                28: reply_char="R";29: reply_char="U";30: reply_char="N"; default: reply_char=8'h00;
            endcase
            4'd1: case (i)
                0: reply_char="F";1: reply_char="B";2: reply_char=" ";3: reply_char="6";
                4: reply_char="4";5: reply_char="0";6: reply_char="X";7: reply_char="4";
                8: reply_char="8";9: reply_char="0"; default: reply_char=8'h00;
            endcase
            4'd2: case (i)
                0: reply_char="O";1: reply_char="K"; default: reply_char=8'h00;
            endcase
            4'd4: case (i)
                0: reply_char="?";1: reply_char="I";2: reply_char="O"; default: reply_char=8'h00;
            endcase
            4'd5: case (i)
                0: reply_char="L";1: reply_char="O";2: reply_char="A";3: reply_char="D";
                4: reply_char="E";5: reply_char="D"; default: reply_char=8'h00;
            endcase
            4'd6: case (i)
                // ?FN FILE NOT FOUND
                0: reply_char="?";1: reply_char="F";2: reply_char="N";3: reply_char=" ";
                4: reply_char="F";5: reply_char="I";6: reply_char="L";7: reply_char="E";
                8: reply_char=" ";9: reply_char="N";10: reply_char="O";11: reply_char="T";
                12: reply_char=" ";13: reply_char="F";14: reply_char="O";15: reply_char="U";
                16: reply_char="N";17: reply_char="D"; default: reply_char=8'h00;
            endcase
            4'd7: case (i)
                // ?NB — no bytecode companion .JSB
                0: reply_char="?";1: reply_char="N";2: reply_char="B"; default: reply_char=8'h00;
            endcase
            4'd8: case (i)
                // -- MORE --
                0: reply_char="-";1: reply_char="-";2: reply_char=" ";3: reply_char="M";
                4: reply_char="O";5: reply_char="R";6: reply_char="E";7: reply_char=" ";
                8: reply_char="-";9: reply_char="-"; default: reply_char=8'h00;
            endcase
            4'd9: case (i)
                // ?NH — HTML not executable on RTL VM yet
                0: reply_char="?";1: reply_char="N";2: reply_char="H"; default: reply_char=8'h00;
            endcase
            4'd10: case (i)
                // ?LS — line/source too long
                0: reply_char="?";1: reply_char="L";2: reply_char="S"; default: reply_char=8'h00;
            endcase
            4'd11: case (i)
                // LIST stub for HTML titles
                0: reply_char="(";1: reply_char="H";2: reply_char="T";3: reply_char="M";
                4: reply_char="L";5: reply_char=")"; default: reply_char=8'h00;
            endcase
            default: case (i)
                // ?SN ERROR — unknown verb (laod)
                0: reply_char="?";1: reply_char="S";2: reply_char="N";3: reply_char=" ";
                4: reply_char="E";5: reply_char="R";6: reply_char="R";7: reply_char="O";
                8: reply_char="R"; default: reply_char=8'h00;
            endcase
        endcase
    endfunction

    assign ready_lit = (state == C_IDLE || state == C_PROMPT);
    assign stor_chan = 8'd1;
    assign stor_name_addr = NAME_BUF;

    // SOURCE lives in external SRAM; the req/gnt bridge is appended inside
    // the main console FSM block (it shares the sram_* channel with the
    // ASET flash states, which never overlap source traffic).

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= C_BOOT_CLS;
            ret_state <= C_IDLE;
            line_len <= 0;
            msg_idx <= 0;
            reply_sel <= 0;
            reply_idx <= 0;
            kbd_pop <= 0;
            kbd_clear <= 0;
            cls <= 0;
            put_en <= 0;
            put_char <= 0;
            print_nl <= 0;
            run_pulse <= 0;
            vm_start <= 0;
            halt_pulse <= 0;
            code_we <= 0;
            ch <= 0;
            stor_open <= 0; stor_close <= 0; stor_readline <= 0; stor_get_byte <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            stor_nl_scan <= 0;
            stor_mode <= "I"; stor_name_len <= 0; stor_putc_data <= 0;
            mem_en <= 0; mem_we <= 0; mem_addr <= 0; mem_wdata <= 0;
            src_req <= 0; src_we <= 0; src_addr <= 0; src_wdata <= 0;
            src_gnt <= 0; src_rdata <= 0; srcb_pend <= 0; srcb_we_l <= 0; srcb_wd_l <= 0;
            src_len <= 0; src_i <= 0;
            name_len_r <= 0; name_i <= 0; name_start <= 0;
            dir_n <= 0; dir_idx <= 0;
            cmd_is_load <= 0; cmd_is_save <= 0; cmd_is_remove <= 0;
            src_name_len <= 0; src_is_rectdemo <= 0; src_is_html <= 0; src_is_js <= 0;
            jsb_waddr <= 0; jsb_bi <= 0; jsb_word <= 0; jsb_name_len <= 0;
            jsb_want_jsh <= 1'b0;
            jsb_tether_mode <= 1'b0;
            teth_wd <= 30'd0;
            cons_stor_wd <= 32'd0;
            cons_stor_arm <= 1'b0;
            jsb_din <= 8'h0;
            ld_err <= 0;
            ld_nlines <= 0; ld_need_eol <= 0; ld_ann <= 0;
            sram_req <= 0; sram_we <= 0; sram_addr <= 0; sram_wdata <= 0;
            pal_we <= 0; pal_waddr <= 0; pal_wdata <= 0;
            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
            sram_lo <= 0; sram_last <= 0;
            pal_r <= 0; pal_g <= 0; pal_idx <= 0; pal_ph <= 0;
            list_page <= 0; list_lo <= 16'd10; list_hi <= 16'hFFFF;
            list_disp <= 16'd10; list_on_page <= 0; list_skip <= 0;
            list_col <= 0; list_wrap_more <= 0; list_eat_nl <= 0;
            list_from_card <= 0; list_bol <= 0;
            edit_pending <= 0; edit_disp <= 0;
            edit_start <= 0; edit_end <= 0;
        end else begin
            kbd_pop <= 0;
            kbd_clear <= 0;
            cls <= 0;
            put_en <= 0;
            print_nl <= 0;
            run_pulse <= 0;
            vm_start <= 0;
            halt_pulse <= 0;
            code_we <= 0;
            stor_open <= 0; stor_close <= 0; stor_readline <= 0; stor_get_byte <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            stor_nl_scan <= 0;
            mem_en <= 0; mem_we <= 0;
            src_req <= 0; src_we <= 0;
            pal_we <= 0; // NEW: 1-cycle palette write strobes (sram_req holds to ack)

            unique case (state)
                C_BOOT_CLS: begin
                    cls <= 1'b1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_BOOT_MSG;
                    msg_idx <= 0;
                end
                C_BOOT_MSG: begin
                    if (banner_char(msg_idx) == 8'h00) begin
                        print_nl <= 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_PROMPT;
                        msg_idx <= 0;
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        put_char <= banner_char(msg_idx);
                        msg_idx <= msg_idx + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_BOOT_MSG;
                    end
                end
                C_PROMPT: begin
                    if (msg_idx < 5) begin
                        if (!video_busy) begin
                            put_en <= 1'b1;
                            put_char <= ready_char(msg_idx);
                            msg_idx <= msg_idx + 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_PROMPT;
                        end
                    end else if (msg_idx == 5) begin
                        print_nl <= 1'b1;
                        msg_idx <= 6;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_PROMPT;
                    end else if (msg_idx == 6) begin
                        if (!video_busy) begin
                            put_en <= 1'b1;
                            put_char <= ">";
                            msg_idx <= 7;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_PROMPT;
                        end
                    end else if (msg_idx == 7) begin
                        if (!video_busy) begin
                            put_en <= 1'b1;
                            put_char <= " ";
                            line_len <= 0;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_IDLE;
                        end
                    end
                end
                C_IDLE: begin
                    if (enable && !kbd_empty && !video_busy) begin
                        ch <= kbd_data;
                        kbd_pop <= 1'b1;
                        state <= C_ECHO;
                    end
                end
                C_ECHO: begin
                    if (ch == 8'h0D || ch == 8'h0A) begin
                        print_nl <= 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_EXEC;
                    end else if (ch == 8'h08 || ch == 8'h7F) begin
                        if (line_len != 0) begin
                            line_len <= line_len - 1'b1;
                            put_en <= 1'b1;
                            put_char <= 8'h08;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_IDLE;
                        end else state <= C_IDLE;
                    end else if (ch >= 8'h20 && ch < 8'h7F) begin
                        if (line_len < 7'd127) begin
                            line[line_len] <= ch;
                            line_len <= line_len + 1'b1;
                            put_en <= 1'b1;
                            put_char <= ch;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_IDLE;
                        end else state <= C_IDLE;
                    end else state <= C_IDLE;
                end
                C_WAIT_VIDEO: begin
                    if (!video_busy) state <= ret_state;
                end
                C_EXEC: begin
                    reply_sel <= 4'd3; // ?
                    cmd_is_load <= 0; cmd_is_save <= 0; cmd_is_remove <= 0;
                    // NEW: EDIT waiting — next typed line replaces that source line
                    if (edit_pending) begin
                        edit_pending <= 0;
                        src_i <= 0;
                        edit_copy_i <= 0;
                        edit_new_len <= {9'h0, line_len};
                        state <= C_EDIT_REPL;
                    end else if (line_len == 0) begin
                        msg_idx <= 0;
                        state <= C_PROMPT;
                    end else if (p_help_q) begin
                        reply_sel <= 4'd0; reply_idx <= 0; state <= C_REPLY;
                    end else if (p_dir_q) begin
                        state <= C_DIR0;
                    end else if (p_cls_q) begin
                        // NEW: CLS like BASIC
                        state <= C_CLS;
                    end else if (p_list_q) begin
                        // NEW: LIST / LIST - / LIST n-m — parse then numbered dump
                        list_page <= 1'b1;
                        list_lo <= 16'd10;
                        list_hi <= 16'hFFFF;
                        list_on_page <= 0;
                        // Parse rest after "LIST"
                        if (line_len == 4) begin
                            state <= C_LIST_INIT;
                        end else begin
                            // skip spaces
                            name_i <= 5;
                            state <= C_LIST_PARSE;
                        end
                    end else if (p_edit_q) begin
                        // NEW: EDIT n
                        name_i <= 5;
                        peel_mag <= 0;
                        state <= C_EDIT_PARSE;
                    end else if (p_mem_q) begin
                        reply_sel <= 4'd1; reply_idx <= 0; state <= C_REPLY;
                    end else if (p_new_q) begin
                        src_len <= 0; src_name_len <= 0;
                        src_is_rectdemo <= 0; src_is_html <= 0; src_is_js <= 0;
                        halt_pulse <= 1'b1; // drop game_mode / stop VM (cyan stub leftover)
                        reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                    end else if (p_run_q) begin
                        // HTML RUN, standalone-first (CONSTITUTION rule 10):
                        // try NAME.JSH from the card (the builder emits it
                        // beside every .HTML; on-device SAVE deletes it, so a
                        // stale image can never run silently). FAT miss falls
                        // back to the host tether at C_JSB_OPENW.
                        // RECTDEMO → rect engine; empty NEW → rect; missing JSB → ?NB
                        if (src_is_html) begin
                            jsb_want_jsh <= 1'b1;
                            jsb_tether_mode <= 1'b0;
                            name_i <= 0;
                            dir_n <= 0;
                            jsb_waddr <= 0;
                            jsb_bi <= 0;
                            jsb_word <= 0;
                            ld_err <= 0;
                            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                            sram_last <= 0; pal_idx <= 0; pal_ph <= 0;
                            state <= C_JSB_PREP;
                        end else if (src_is_rectdemo) begin
                            run_pulse <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                        end else if (src_len == 0 && !src_is_js) begin
                            run_pulse <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                        end else if (src_is_js || src_name_len != 0) begin
                            // NEW: any LOADed program (INVADERS / PACMAN.JS / …) → NAME.JSB
                            jsb_want_jsh <= 1'b0;
                            jsb_tether_mode <= 1'b0;
                            name_i <= 0;
                            dir_n <= 0;
                            jsb_waddr <= 0;
                            jsb_bi <= 0;
                            jsb_word <= 0;
                            state <= C_JSB_PREP;
                        end else begin
                            reply_sel <= 4'd7; reply_idx <= 0; state <= C_REPLY; // ?NB
                        end
                    end else if (p_load_q) begin
                        cmd_is_load <= 1'b1; name_start <= 5; state <= C_PF;
                    end else if (p_save_q) begin
                        cmd_is_save <= 1'b1; name_start <= 5; state <= C_PF;
                    end else if (p_remove_q) begin
                        cmd_is_remove <= 1'b1; name_start <= 7; state <= C_PF;
                    end else begin
                        reply_idx <= 0; state <= C_REPLY;
                    end
                end
                C_REPLY: begin
                    if (reply_char(reply_sel, reply_idx) == 8'h00) begin
                        if (ld_ann && reply_sel == 4'd5) begin
                            // NEW: same line as PYTHON — LOADED NAME (N LINES)
                            name_i <= 0;
                            state <= C_LD_ANN_SP;
                        end else begin
                            print_nl <= 1'b1;
                            msg_idx <= 0;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_PROMPT;
                        end
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        put_char <= reply_char(reply_sel, reply_idx);
                        reply_idx <= reply_idx + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_REPLY;
                    end
                end

                // ---- DIR (BASIC ST_DIR*) --------------------------------
                C_DIR0: if (!stor_busy) begin
                    stor_dir <= 1'b1;
                    list_on_page <= 0;
                    dir_more <= 1'b0;
                    state <= C_DIR0W;
                end
                C_DIR0W: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else state <= C_DIRN;
                end else if (!kbd_empty && kbd_data == 8'h1B) begin
                    // ESC while storage works: consume it, bail to prompt.
                    // A late stor_done pulse with nobody waiting is ignored;
                    // storage completes or watchdogs out on its own.
                    kbd_pop <= 1'b1;
                    msg_idx <= 0; state <= C_PROMPT;
                end
                C_DIRN: if (!stor_busy) begin stor_dir_next <= 1'b1; state <= C_DIRNW; end
                C_DIRNW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else if (stor_eof) begin msg_idx <= 0; state <= C_PROMPT; end
                    else begin dir_n <= stor_line_len; dir_idx <= 0; state <= C_DIR_RD; end
                end else if (!kbd_empty && kbd_data == 8'h1B) begin
                    kbd_pop <= 1'b1;
                    msg_idx <= 0; state <= C_PROMPT;
                end
                C_DIR_RD: begin
                    if (dir_idx >= dir_n) state <= C_DIR_NL;
                    else begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                        state <= C_DIR_CH;
                    end
                end
                C_DIR_CH: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    state <= C_DIR_PUT;
                end
                C_DIR_PUT: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    dir_idx <= dir_idx + 1'b1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_DIR_RD;
                end
                C_DIR_NL: if (!video_busy) begin
                    // DIR pages like LIST: without this a long directory
                    // (titles + saved files) scrolled its head off the
                    // glass and "DIR doesn't list .HTML" — the .HTM rows
                    // printed first and were gone before READY.
                    print_nl <= 1'b1;
                    state <= C_WAIT_VIDEO;
                    if (list_on_page >= 4'd13) begin
                        list_on_page <= 0;
                        dir_more <= 1'b1;
                        reply_sel <= 4'd8; reply_idx <= 0;
                        ret_state <= C_LIST_MORE;
                    end else begin
                        list_on_page <= list_on_page + 4'd1;
                        ret_state <= C_DIRN;
                    end
                end

                // ---- parse filename after verb --------------------------
                C_PF: begin
                    name_i <= 0;
                    if (name_start >= line_len) begin
                        reply_sel <= 4'd6; reply_idx <= 0; state <= C_REPLY;
                    end else begin
                        // skip leading quote
                        if (line[name_start] == "\"" || line[name_start] == "'")
                            name_start <= name_start + 1'b1;
                        // compute length into name_len_r next cycle via C_PF2
                        state <= C_PF2;
                    end
                end
                C_PF2: begin
                    // trailing quote strip + length
                    if (line_len > name_start &&
                        (line[line_len - 1] == "\"" || line[line_len - 1] == "'"))
                        name_len_r <= line_len - name_start - 1'b1;
                    else
                        name_len_r <= line_len - name_start;
                    if ((line_len > name_start &&
                         (line[line_len - 1] == "\"" || line[line_len - 1] == "'") &&
                         (line_len - name_start - 1'b1) == 0) ||
                        (!(line_len > name_start &&
                           (line[line_len - 1] == "\"" || line[line_len - 1] == "'")) &&
                         (line_len - name_start) == 0)) begin
                        reply_sel <= 4'd6; reply_idx <= 0; state <= C_REPLY;
                    end else begin
                        name_i <= 0;
                        state <= C_NWR;
                    end
                end
                C_NWR: begin
                    if (name_i >= name_len_r) begin
                        stor_name_len <= {1'b0, name_len_r};
                        // Remember upcased name for RUN gate / LIST header
                        if (cmd_is_load) begin
                            src_name_len <= (name_len_r > 5'd16) ? 5'd16 : name_len_r[4:0];
                            // RECTDEMO.JS or RECTDEMO → silicon demo allowed
                            src_is_rectdemo <=
                                (name_len_r >= 8 &&
                                 src_name[0]=="R" && src_name[1]=="E" &&
                                 src_name[2]=="C" && src_name[3]=="T" &&
                                 src_name[4]=="D" && src_name[5]=="E" &&
                                 src_name[6]=="M" && src_name[7]=="O");
                            // Extension classify — never use INVADERS prefix as bytecode gate
                            // .HTM / .HTML → html; .JS → js (FAT may store .HTM for .HTML)
                            // (name_tail is upcased; "." has no case)
                            src_is_html <=
                                (name_len_r >= 4 &&
                                 name_tail[3]=="." && name_tail[2]=="H" &&
                                 name_tail[1]=="T" && name_tail[0]=="M")
                                ||
                                (name_len_r >= 5 &&
                                 name_tail[4]=="." && name_tail[3]=="H" &&
                                 name_tail[2]=="T" && name_tail[1]=="M" &&
                                 name_tail[0]=="L");
                            src_is_js <=
                                (name_len_r >= 3 &&
                                 name_tail[2]=="." && name_tail[1]=="J" &&
                                 name_tail[0]=="S")
                                &&
                                !(name_len_r >= 4 &&
                                  name_tail[3]=="." && name_tail[2]=="H" &&
                                  name_tail[1]=="T" && name_tail[0]=="M")
                                &&
                                !(name_len_r >= 5 &&
                                  name_tail[4]=="." && name_tail[3]=="H" &&
                                  name_tail[2]=="T" && name_tail[1]=="M" &&
                                  name_tail[0]=="L");
                        end
                        if (cmd_is_load) state <= C_LD_OPEN;
                        else if (cmd_is_save) state <= C_SV_OPEN;
                        else state <= C_RM;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i};
                        // FAT 8.3 is uppercase — match BASIC storage_engine
                        mem_wdata <= up(line[name_start + name_i]);
                        if (name_i < 16)
                            src_name[name_i[3:0]] <= up(line[name_start + name_i]);
                        name_tail[0] <= up(line[name_start + name_i]);
                        name_tail[1] <= name_tail[0];
                        name_tail[2] <= name_tail[1];
                        name_tail[3] <= name_tail[2];
                        name_tail[4] <= name_tail[3];
                        state <= C_NWR_W;
                    end
                end
                C_NWR_W: if (mem_gnt) begin
                    name_i <= name_i + 1'b1;
                    state <= C_NWR;
                end

                // ---- LOAD -----------------------------------------------
                C_LD_OPEN: if (!stor_busy) begin
                    // NEW: FPGA-SIM RAM LOAD — SOURCE was poked by the host, so
                    // announce straight away (same glass rows as a FAT LOAD:
                    // typed line echoed above, LOADED at the cursor).
                    if (sim_src_bypass) begin
                        ld_err <= 0;
                        ld_need_eol <= 0;
                        ld_nlines <= sim_src_lines;
                        ld_ann <= 1'b1;
                        reply_sel <= 4'd5; reply_idx <= 0; state <= C_REPLY;
                    end else begin
                        stor_mode <= "I";
                        stor_open <= 1'b1;
                        src_len <= 0;
                        ld_err <= 0;
                        ld_nlines <= 0;
                        ld_need_eol <= 0;
                        ld_ann <= 0;
                        state <= C_LD_OPENW;
                    end
                end
                C_LD_OPENW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd6; reply_idx <= 0; state <= C_REPLY; end
                    // HTML: copy bytes into SOURCE (prefix) — long data: lines must not ?LS
                    else if (src_is_html) state <= C_LD_GB;
                    else state <= C_LD_RL;
                end
                C_LD_RL: if (!stor_busy) begin
                    stor_readline <= 1'b1;
                    state <= C_LD_RLW;
                end
                C_LD_RLW: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state <= C_LD_CLOSE;
                    end else if (stor_eof) state <= C_LD_CLOSE;
                    else begin
                        // NEW: FAT lines >128 → ?LS (unlistable / overflow)
                        if (stor_line_len > 8'd128) begin
                            ld_err <= 1'b1; reply_sel <= 4'd10; reply_idx <= 0; state <= C_LD_CLOSE;
                        end else begin
                            dir_n <= stor_line_len; dir_idx <= 0; state <= C_LD_RD;
                        end
                    end
                end
                C_LD_RD: begin
                    if (dir_idx >= dir_n) begin
                        // append NL
                        if (src_len < SOURCE_MAX) begin
                            src_req <= 1'b1; src_we <= 1'b1;
                            src_addr <= src_len[16:0];
                            src_wdata <= 8'h0A;
                            state <= C_LD_NLW;
                        end else begin
                            // SOURCE full — keep prefix for LIST, RUN uses .JSB
                            state <= C_LD_CLOSE;
                        end
                    end else if (src_len < SOURCE_MAX) begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                        state <= C_LD_RDW;
                    end else begin
                        state <= C_LD_CLOSE;
                    end
                end
                C_LD_RDW: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    src_req <= 1'b1; src_we <= 1'b1;
                    src_addr <= src_len[16:0];
                    src_wdata <= mem_rdata;
                    state <= C_LD_WRW;
                end
                C_LD_WRW: if (src_gnt) begin
                    src_len <= src_len + 1'b1;
                    dir_idx <= dir_idx + 1'b1;
                    state <= C_LD_RD;
                end
                C_LD_NLW: if (src_gnt) begin
                    src_len <= src_len + 1'b1;
                    ld_nlines <= ld_nlines + 16'd1;
                    state <= C_LD_RL;
                end
                // HTML: stream file bytes into SOURCE (128K), then sector NL scan
                C_LD_GB: if (!stor_busy) begin
                    if (src_len >= SOURCE_MAX) begin
                        stor_nl_scan <= 1'b1;
                        state <= C_LD_NLSCANW;
                    end else begin
                        stor_get_byte <= 1'b1;
                        state <= C_LD_GBW;
                    end
                end
                C_LD_GBW: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state <= C_LD_CLOSE;
                    end else if (stor_eof) state <= C_LD_CLOSE;
                    else begin
                        src_req <= 1'b1; src_we <= 1'b1;
                        src_addr <= src_len[16:0];
                        src_wdata <= stor_get_data;
                        if (stor_get_data == 8'h0A)
                            ld_nlines <= ld_nlines + 16'd1;
                        ld_need_eol <= (stor_get_data != 8'h0A && stor_get_data != 8'h0D);
                        state <= C_LD_GB_WR;
                    end
                end
                C_LD_GB_WR: if (src_gnt) begin
                    src_len <= src_len + 1'b1;
                    state <= C_LD_GB;
                end
                C_LD_NLSCANW: if (stor_done) begin
                    if (!stor_err)
                        ld_nlines <= ld_nlines + stor_nl_count;
                    state <= C_LD_CLOSE;
                end
                C_LD_CLOSE: if (!stor_busy) begin stor_close <= 1'b1; state <= C_LD_CLOSEW; end
                C_LD_CLOSEW: if (stor_done) begin
                    if (ld_err)
                        state <= C_REPLY;
                    else begin
                        if (ld_need_eol)
                            ld_nlines <= ld_nlines + 16'd1;
                        ld_ann <= 1'b1;
                        reply_sel <= 4'd5; reply_idx <= 0; state <= C_REPLY;
                    end
                end
                C_LD_ANN_SP: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= " ";
                    name_i <= 0;
                    dir_idx <= 0;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LD_ANN_NAME;
                end
                C_LD_ANN_NAME: begin
                    if (name_i >= {2'b0, src_name_len}) begin
                        state <= C_LD_ANN_PAR;
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        put_char <= src_name[name_i[3:0]];
                        name_i <= name_i + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LD_ANN_NAME;
                    end
                end
                C_LD_ANN_PAR: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= (dir_idx == 8'd0) ? " " : "(";
                    if (dir_idx == 8'd0) begin
                        dir_idx <= 8'd1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LD_ANN_PAR;
                    end else begin
                        dir_idx <= 0;
                        peel_mag <= ld_nlines;
                        dig_n <= 0;
                        peel_bit <= 5'd16;
                        peel_rem <= 0;
                        peel_q <= 0;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_PEEL;
                    end
                end
                C_LD_ANN_TAIL: begin
                    if (msg_idx >= 7) begin
                        ld_ann <= 1'b0;
                        print_nl <= 1'b1;
                        msg_idx <= 0;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_PROMPT;
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        case (msg_idx)
                            0: put_char <= " ";
                            1: put_char <= "L";
                            2: put_char <= "I";
                            3: put_char <= "N";
                            4: put_char <= "E";
                            5: put_char <= "S";
                            default: put_char <= ")";
                        endcase
                        msg_idx <= msg_idx + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LD_ANN_TAIL;
                    end
                end

                // ---- SAVE -----------------------------------------------
                C_SV_OPEN: if (!stor_busy) begin
                    stor_mode <= "O";
                    stor_open <= 1'b1;
                    src_i <= 0;
                    state <= C_SV_OPENW;
                end
                C_SV_OPENW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else state <= C_SV_RD;
                end
                C_SV_RD: begin
                    if (src_i >= src_len) state <= C_SV_CLOSE;
                    else begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= src_i[16:0];
                        state <= C_SV_RDW;
                    end
                end
                C_SV_RDW: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    state <= C_SV_PUT;
                end
                C_SV_PUT: if (!stor_busy) begin
                    stor_putc <= 1'b1;
                    stor_putc_data <= rd_ch;
                    state <= C_SV_PUTW;
                end
                C_SV_PUTW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_SV_CLOSE; end
                    else begin src_i <= src_i + 1'b1; state <= C_SV_RD; end
                end
                C_SV_CLOSE: if (!stor_busy) begin stor_close <= 1'b1; state <= C_SV_CLOSEW; end
                C_SV_CLOSEW: if (stor_done) begin
                    reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                end

                // ---- REMOVE ---------------------------------------------
                C_RM: if (!stor_busy) begin stor_delete <= 1'b1; state <= C_RMW; end
                C_RMW: if (stor_done) begin
                    if (stor_err) reply_sel <= 4'd4; else reply_sel <= 4'd2;
                    reply_idx <= 0; state <= C_REPLY;
                end

                // ---- CLS ------------------------------------------------
                C_CLS: begin
                    // NEW: wait until video idle, then pulse cls (if already busy,
                    // a pulse is ignored and WAIT would skip the clear)
                    msg_idx <= 0;
                    ret_state <= C_PROMPT;
                    if (!video_busy) begin
                        cls <= 1'b1;
                        state <= C_WAIT_VIDEO;
                    end
                end

                // ---- LIST parse: LIST - / LIST n / LIST n-m --------------
                C_LIST_PARSE: begin
                    if (ni_q != name_i) begin
                        // char pipe settling
                    end else if (name_i >= line_len) begin
                        state <= C_LIST_INIT;
                    end else if (is_sp(ch_ni_q)) begin
                        name_i <= name_i + 1'b1;
                    end else if (ch_ni_q == "-") begin
                        // LIST -  or LIST -m
                        if (name_i + 1'b1 >= line_len) begin
                            list_page <= 1'b1;
                            state <= C_LIST_INIT;
                        end else begin
                            list_page <= 1'b0;
                            list_lo <= 16'd10;
                            peel_mag <= 0;
                            name_i <= name_i + 1'b1;
                            state <= C_LIST_PAR_HI;
                        end
                    end else if (ch_ni_q >= "0" && ch_ni_q <= "9") begin
                        list_page <= 1'b0;
                        peel_mag <= 0;
                        state <= C_LIST_PAR_LO;
                    end else begin
                        reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                    end
                end
                C_LIST_PAR_LO: begin
                    if (ni_q != name_i) begin
                        // char pipe settling
                    end else if (name_i >= line_len) begin
                        // NEW: list_hi must use peel_mag — same-cycle list_lo is still old
                        list_lo <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        list_hi <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        state <= C_LIST_INIT;
                    end else if (ch_ni_q >= "0" && ch_ni_q <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, ch_ni_q - "0"};
                        name_i <= name_i + 1'b1;
                    end else if (ch_ni_q == "-") begin
                        list_lo <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        name_i <= name_i + 1'b1;
                        peel_mag <= 0;
                        state <= C_LIST_PAR_HI;
                    end else begin
                        list_lo <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        list_hi <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        state <= C_LIST_INIT;
                    end
                end
                C_LIST_PAR_HI: begin
                    if (ni_q != name_i) begin
                        // char pipe settling
                    end else if (name_i >= line_len) begin
                        list_hi <= (peel_mag == 0) ? 16'hFFFF : peel_mag;
                        state <= C_LIST_INIT;
                    end else if (ch_ni_q >= "0" && ch_ni_q <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, ch_ni_q - "0"};
                        name_i <= name_i + 1'b1;
                    end else begin
                        list_hi <= (peel_mag == 0) ? 16'hFFFF : peel_mag;
                        state <= C_LIST_INIT;
                    end
                end

                // ---- LIST numbered dump ---------------------------------
                C_LIST_INIT: begin
                    if (src_is_html && src_name_len != 0) begin
                        // LIST HTML from the card so PACMAN.HTML pages like PYTHON
                        list_from_card <= 1'b1;
                        list_bol <= 1'b1;
                        src_i <= 0;
                        list_disp <= 16'd10;
                        list_on_page <= 0;
                        list_col <= 0;
                        list_wrap_more <= 0;
                        list_skip <= 1'b0;
                        name_i <= 0;
                        state <= C_LIST_CNWR;
                    end else if (src_len == 0) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else begin
                        list_from_card <= 1'b0;
                        src_i <= 0;
                        list_disp <= 16'd10;
                        list_on_page <= 0;
                        list_col <= 0;
                        list_wrap_more <= 0;
                        list_skip <= 1'b0;
                        state <= C_LIST_LINE;
                    end
                end
                C_LIST_LINE: begin
                    if (src_i >= src_len) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else if (list_disp > list_hi) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else begin
                        // NEW: decide skip from list_disp/list_lo this cycle —
                        // do not use registered list_skip (NBA would be stale)
                        if (list_disp < list_lo) begin
                            list_skip <= 1'b1;
                            // consume until NL without printing
                            src_req <= 1'b1; src_we <= 1'b0;
                            src_addr <= src_i[16:0];
                            state <= C_LIST_RD;
                        end else begin
                            list_skip <= 1'b0;
                            peel_mag <= list_disp;
                            dig_n <= 0;
                            peel_bit <= 5'd16;
                            peel_rem <= 0;
                            peel_q <= 0;
                            state <= C_LIST_PEEL;
                        end
                    end
                end
                // Multi-cycle /10 digit peel (16-bit; not the VM 32-bit critical path)
                C_LIST_PEEL: begin
                    if (peel_mag == 0 && dig_n != 0) begin
                        dig_i <= dig_n;
                        state <= C_LIST_EMIT_DIG;
                    end else if (peel_mag == 0 && dig_n == 0) begin
                        digs[0] <= "0";
                        dig_n <= 1;
                        dig_i <= 1;
                        state <= C_LIST_EMIT_DIG;
                    end else begin
                        digs[dig_n] <= 8'("0") + 8'(peel_mag % 16'd10);
                        peel_mag <= peel_mag / 16'd10;
                        dig_n <= dig_n + 3'd1;
                    end
                end
                C_LIST_EMIT_DIG: begin
                    if (dig_i == 0) begin
                        if (ld_ann) begin
                            msg_idx <= 0;
                            state <= C_LD_ANN_TAIL;
                        end else state <= C_LIST_SP;
                    end else if (!video_busy) begin
                        dig_i <= dig_i - 3'd1;
                        put_en <= 1'b1;
                        put_char <= digs[dig_i - 3'd1];
                        // LIST wrap tracks the glass column, including "NNN "
                        if (!ld_ann)
                            list_col <= list_col + 6'd1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_EMIT_DIG;
                    end
                end
                C_LIST_SP: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= " ";
                    list_col <= list_col + 6'd1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= list_from_card ? C_LIST_CARD_FIRST : C_LIST_RD_GO;
                end
                C_LIST_RD_GO: begin
                    src_req <= 1'b1; src_we <= 1'b0;
                    src_addr <= src_i[16:0];
                    state <= C_LIST_RD;
                end
                C_LIST_RD: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    state <= C_LIST_CH;
                end
                C_LIST_CH: begin
                    src_i <= src_i + 1'b1;
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D) begin
                        if (list_skip) begin
                            list_disp <= list_disp + 16'd10;
                            state <= C_LIST_LINE;
                        // wrap already sat at col 0 — extra print_nl skipped a row
                        end else if (list_col == 6'd0) begin
                            state <= C_LIST_NL;
                        end else if (!video_busy) begin
                            print_nl <= 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_LIST_NL;
                        end
                    end else if (src_i + 1'b1 >= src_len) begin
                        // last line without NL
                        if (list_skip) begin
                            list_disp <= list_disp + 16'd10;
                            state <= C_LIST_LINE;
                        end else if (rd_ch >= 8'h20 && rd_ch < 8'h7F) begin
                            state <= C_LIST_PUT_LAST;
                        end else begin
                            print_nl <= 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_LIST_NL;
                        end
                    end else if (list_skip) begin
                        state <= C_LIST_RD_GO;
                    end else if (rd_ch >= 8'h20 && rd_ch < 8'h7F) begin
                        state <= C_LIST_PUT;
                    end else begin
                        state <= C_LIST_RD_GO;
                    end
                end
                C_LIST_PUT: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    if (list_col >= 6'd63) begin
                        list_col <= 0;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_WRAP;
                    end else begin
                        list_col <= list_col + 6'd1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_RD_GO;
                    end
                end
                C_LIST_PUT_LAST: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LIST_NL_FORCE;
                end
                C_LIST_NL_FORCE: begin
                    if (list_col == 6'd0) begin
                        state <= C_LIST_NL;
                    end else begin
                        print_nl <= 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_NL;
                    end
                end
                C_LIST_NL: begin
                    list_disp <= list_disp + 16'd10;
                    list_bol <= 1'b1;
                    list_col <= 0;
                    if (list_page) begin
                        if (list_on_page >= 4'd13) begin
                            list_on_page <= 0;
                            reply_sel <= 4'd8; reply_idx <= 0;
                            list_eat_nl <= 1'b1;
                            state <= C_LIST_MORE;
                        end else begin
                            list_on_page <= list_on_page + 4'd1;
                            state <= list_from_card ? C_LIST_CARD_GB : C_LIST_LINE;
                        end
                    end else state <= list_from_card ? C_LIST_CARD_GB : C_LIST_LINE;
                end
                C_LIST_WRAP: begin
                    // V_PUT already advanced at col 63. Extra print_nl used to
                    // skip a glass row (3-char remnant + blank) on every wrap.
                    state <= C_LIST_WRAP_PAGE;
                end
                C_LIST_WRAP_PAGE: begin
                    if (list_page) begin
                        if (list_on_page >= 4'd13) begin
                            list_on_page <= 0;
                            list_wrap_more <= 1'b1;
                            list_eat_nl <= 1'b1;
                            reply_sel <= 4'd8; reply_idx <= 0;
                            state <= C_LIST_MORE;
                        end else begin
                            list_on_page <= list_on_page + 4'd1;
                            state <= list_from_card ? C_LIST_CARD_GB : C_LIST_RD_GO;
                        end
                    end else state <= list_from_card ? C_LIST_CARD_GB : C_LIST_RD_GO;
                end
                C_LIST_MORE: begin
                    if (reply_char(reply_sel, reply_idx) == 8'h00) begin
                        print_nl <= 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_WAIT;
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        put_char <= reply_char(reply_sel, reply_idx);
                        reply_idx <= reply_idx + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_MORE;
                    end
                end
                C_LIST_WAIT: if (enable && !kbd_empty) begin
                    ch <= kbd_data;
                    kbd_pop <= 1'b1;
                    if (list_eat_nl && (kbd_data == 8'h0D || kbd_data == 8'h0A)) begin
                        // LINE's terminating CR must not page the first MORE.
                        list_eat_nl <= 1'b0;
                    end else if (kbd_data == 8'h1B || kbd_data == 8'h03) begin
                        list_eat_nl <= 1'b0;
                        state <= dir_more ? C_PROMPT
                               : list_from_card ? C_LIST_CCLOSE : C_PROMPT;
                        dir_more <= 1'b0;
                        msg_idx <= 0;
                    end else begin
                        list_eat_nl <= 1'b0;
                        // Space/Enter/any key → next page
                        if (dir_more) begin
                            dir_more <= 1'b0;
                            state <= C_DIRN;
                        end else if (list_wrap_more) begin
                            list_wrap_more <= 1'b0;
                            state <= list_from_card ? C_LIST_CARD_GB : C_LIST_RD_GO;
                        end else
                            state <= list_from_card ? C_LIST_CARD_GB : C_LIST_LINE;
                    end
                end
                // HTML LIST: reopen LOADed name and stream bytes (long lines OK)
                C_LIST_CNWR: begin
                    if (name_i >= src_name_len) begin
                        stor_name_len <= {3'b0, src_name_len};
                        state <= C_LIST_COPEN;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i};
                        mem_wdata <= src_name[name_i[3:0]];
                        state <= C_LIST_CNWR_W;
                    end
                end
                C_LIST_CNWR_W: if (mem_gnt) begin
                    name_i <= name_i + 1'b1;
                    state <= C_LIST_CNWR;
                end
                C_LIST_COPEN: if (!stor_busy) begin
                    stor_mode <= "I";
                    stor_open <= 1'b1;
                    state <= C_LIST_COPENW;
                end
                C_LIST_COPENW: if (stor_done) begin
                    if (stor_err) begin
                        reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY;
                    end else state <= C_LIST_CARD_GB;
                end
                C_LIST_CARD_GB: if (!stor_busy) begin
                    stor_get_byte <= 1'b1;
                    state <= C_LIST_CARD_GBW;
                end
                C_LIST_CARD_GBW: if (stor_done) begin
                    if (stor_err || stor_eof) state <= C_LIST_CCLOSE;
                    else if (list_disp > list_hi) state <= C_LIST_CCLOSE;
                    else if (list_bol) begin
                        rd_ch <= stor_get_data;
                        if (list_disp < list_lo) begin
                            list_skip <= 1'b1;
                            list_bol <= 1'b0;
                            if (stor_get_data == 8'h0A || stor_get_data == 8'h0D) begin
                                list_disp <= list_disp + 16'd10;
                                list_bol <= 1'b1;
                            end
                            state <= C_LIST_CARD_GB;
                        end else begin
                            list_skip <= 1'b0;
                            list_bol <= 1'b0;
                            peel_mag <= list_disp;
                            dig_n <= 0;
                            peel_bit <= 5'd16;
                            peel_rem <= 0;
                            peel_q <= 0;
                            state <= C_LIST_PEEL;
                        end
                    end else if (list_skip) begin
                        if (stor_get_data == 8'h0A || stor_get_data == 8'h0D) begin
                            list_disp <= list_disp + 16'd10;
                            list_bol <= 1'b1;
                        end
                        state <= C_LIST_CARD_GB;
                    end else if (stor_get_data == 8'h0A || stor_get_data == 8'h0D) begin
                        if (list_col == 6'd0) begin
                            state <= C_LIST_NL;
                        end else begin
                            print_nl <= 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_LIST_NL;
                        end
                    end else if (stor_get_data >= 8'h20 && stor_get_data < 8'h7F) begin
                        rd_ch <= stor_get_data;
                        state <= C_LIST_PUT_CARD;
                    end else state <= C_LIST_CARD_GB;
                end
                C_LIST_CARD_FIRST: begin
                    // after "NNNN " — emit first byte of the line (already in rd_ch)
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D) begin
                        if (list_col == 6'd0) begin
                            state <= C_LIST_NL;
                        end else begin
                            print_nl <= 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_LIST_NL;
                        end
                    end else if (rd_ch >= 8'h20 && rd_ch < 8'h7F) begin
                        state <= C_LIST_PUT_CARD;
                    end else state <= C_LIST_CARD_GB;
                end
                C_LIST_PUT_CARD: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    if (list_col >= 6'd63) begin
                        list_col <= 0;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_WRAP;
                    end else begin
                        list_col <= list_col + 6'd1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_CARD_GB;
                    end
                end
                C_LIST_CCLOSE: if (!stor_busy) begin
                    stor_close <= 1'b1;
                    state <= C_LIST_CCLOSEW;
                end
                C_LIST_CCLOSEW: if (stor_done) begin
                    list_from_card <= 1'b0;
                    msg_idx <= 0;
                    state <= C_PROMPT;
                end

                // ---- EDIT n ---------------------------------------------
                C_EDIT_PARSE: begin
                    if (ni_q != name_i) begin
                        // char pipe settling
                    end else if (name_i >= line_len) begin
                        if (peel_mag == 0) begin
                            reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                        end else begin
                            edit_disp <= peel_mag;
                            src_i <= 0;
                            list_disp <= 16'd10;
                            edit_start <= 0;
                            state <= C_EDIT_FIND;
                        end
                    end else if (is_sp(ch_ni_q)) begin
                        name_i <= name_i + 1'b1;
                    end else if (ch_ni_q >= "0" && ch_ni_q <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, ch_ni_q - "0"};
                        name_i <= name_i + 1'b1;
                    end else if (peel_mag == 0) begin
                        reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                    end else begin
                        edit_disp <= peel_mag;
                        src_i <= 0;
                        list_disp <= 16'd10;
                        edit_start <= 0;
                        state <= C_EDIT_FIND;
                    end
                end
                C_EDIT_FIND: begin
                    if (list_disp == edit_disp) begin
                        edit_start <= src_i;
                        state <= C_EDIT_SHOW;
                    end else if (src_i >= src_len) begin
                        reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                    end else begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= src_i[16:0];
                        state <= C_EDIT_RD;
                    end
                end
                C_EDIT_RD: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    state <= C_EDIT_CH;
                end
                C_EDIT_CH: begin
                    // NEW: advance to next byte (src_i+1) — old path re-read
                    // SOURCE+src_i and left edit_start one past the line start
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D) begin
                        src_i <= src_i + 1'b1;
                        list_disp <= list_disp + 16'd10;
                        state <= C_EDIT_FIND;
                    end else if (src_i + 1'b1 >= src_len) begin
                        src_i <= src_i + 1'b1;
                        list_disp <= list_disp + 16'd10;
                        state <= C_EDIT_FIND;
                    end else begin
                        src_i <= src_i + 1'b1;
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= src_i[16:0] + 17'd1;
                        state <= C_EDIT_RD;
                    end
                end
                C_EDIT_SHOW: begin
                    peel_mag <= edit_disp;
                    dig_n <= 0;
                    state <= C_EDIT_PEEL;
                end
                C_EDIT_PEEL: begin
                    if (peel_mag == 0 && dig_n != 0) begin
                        dig_i <= dig_n;
                        state <= C_EDIT_EMIT;
                    end else if (peel_mag == 0) begin
                        digs[0] <= "0"; dig_n <= 1; dig_i <= 1;
                        state <= C_EDIT_EMIT;
                    end else begin
                        digs[dig_n] <= 8'("0") + 8'(peel_mag % 16'd10);
                        peel_mag <= peel_mag / 16'd10;
                        dig_n <= dig_n + 3'd1;
                    end
                end
                C_EDIT_EMIT: begin
                    if (dig_i == 0) state <= C_EDIT_SP;
                    else if (!video_busy) begin
                        dig_i <= dig_i - 3'd1;
                        put_en <= 1'b1;
                        put_char <= digs[dig_i - 3'd1];
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_EDIT_EMIT;
                    end
                end
                C_EDIT_SP: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= " ";
                    src_i <= edit_start;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_EDIT_BODY;
                end
                C_EDIT_BODY: begin
                    src_req <= 1'b1; src_we <= 1'b0;
                    src_addr <= src_i[16:0];
                    state <= C_EDIT_BODY_RD;
                end
                C_EDIT_BODY_RD: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    state <= C_EDIT_BODY_CH;
                end
                C_EDIT_BODY_CH: begin
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D || src_i >= src_len) begin
                        edit_end <= src_i;  // points at NL or past end
                        if (!video_busy) begin
                            print_nl <= 1'b1;
                            state <= C_WAIT_VIDEO;
                            ret_state <= C_EDIT_ARM;
                        end
                    end else if (rd_ch >= 8'h20 && rd_ch < 8'h7F) begin
                        state <= C_EDIT_BODY_PUT;
                    end else begin
                        src_i <= src_i + 1'b1;
                        state <= C_EDIT_BODY;
                    end
                end
                C_EDIT_BODY_PUT: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    src_i <= src_i + 1'b1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_EDIT_BODY;
                end
                C_EDIT_ARM: begin
                    // Prefill done on glass; next Enter line replaces this source line
                    edit_pending <= 1'b1;
                    msg_idx <= 6;  // skip READY — just "> "
                    state <= C_PROMPT;
                end
                // Replace: shift tail by delta first, then write new text + NL
                C_EDIT_REPL: begin
                    if (18'({8'h0, line_len}) + 18'd1 > (edit_end - edit_start + 18'd1)) begin
                        peel_mag <= 16'(18'({8'h0, line_len}) + 18'd1 - (edit_end - edit_start + 18'd1));
                        edit_copy_i <= src_len;
                        state <= C_EDIT_GROW;
                    end else if (18'({8'h0, line_len}) + 18'd1 < (edit_end - edit_start + 18'd1)) begin
                        peel_mag <= 16'((edit_end - edit_start + 18'd1) - (18'({8'h0, line_len}) + 18'd1));
                        edit_copy_i <= edit_end + 18'd1;
                        state <= C_EDIT_SHRINK;
                    end else begin
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end
                end
                C_EDIT_GROW: begin
                    if (edit_copy_i == (edit_end + 18'd1) || src_len == edit_end + 18'd1) begin
                        src_len <= src_len + {2'b0, peel_mag};
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end else begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= 17'(edit_copy_i - 18'd1);
                        state <= C_EDIT_GROW_RD;
                    end
                end
                C_EDIT_GROW_RD: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    src_req <= 1'b1; src_we <= 1'b1;
                    src_addr <= 17'((edit_copy_i - 18'd1) + {2'b0, peel_mag});
                    src_wdata <= src_rdata;
                    state <= C_EDIT_GROW_WR;
                end
                C_EDIT_GROW_WR: if (src_gnt) begin
                    edit_copy_i <= edit_copy_i - 18'd1;
                    state <= C_EDIT_GROW;
                end
                C_EDIT_SHRINK: begin
                    if (edit_copy_i >= src_len) begin
                        src_len <= src_len - {2'b0, peel_mag};
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end else begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= edit_copy_i[16:0];
                        state <= C_EDIT_SHRINK_RD;
                    end
                end
                C_EDIT_SHRINK_RD: if (src_gnt) begin
                    rd_ch <= src_rdata;
                    src_req <= 1'b1; src_we <= 1'b1;
                    src_addr <= 17'(edit_copy_i - {2'b0, peel_mag});
                    src_wdata <= src_rdata;
                    state <= C_EDIT_SHRINK_WR;
                end
                C_EDIT_SHRINK_WR: if (src_gnt) begin
                    edit_copy_i <= edit_copy_i + 18'd1;
                    state <= C_EDIT_SHRINK;
                end
                C_EDIT_WR_NEW: begin
                    if (name_i >= line_len) begin
                        src_req <= 1'b1; src_we <= 1'b1;
                        src_addr <= src_i[16:0];
                        src_wdata <= 8'h0A;
                        state <= C_EDIT_WR_NL;
                    end else begin
                        src_req <= 1'b1; src_we <= 1'b1;
                        src_addr <= src_i[16:0];
                        src_wdata <= line[name_i];
                        state <= C_EDIT_WR_WAIT;
                    end
                end
                C_EDIT_WR_WAIT: if (src_gnt) begin
                    name_i <= name_i + 1'b1;
                    src_i <= src_i + 1'b1;
                    state <= C_EDIT_WR_NEW;
                end
                C_EDIT_WR_NL: if (src_gnt) begin
                    reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                end

                // ---- RUN → FAT-load companion .JSB into code BRAM ----------
                // dir_n: 0=copy base, 1=write J, 2=write S, 3=write B, 4=done
                // No '.' in name (LOAD "invaders") → append ".JSB" after full name
                C_JSB_PREP: begin
                    if (dir_n == 8'd0) begin
                        if (name_i >= src_name_len) begin
                            // end of name with no '.' — append .JSB here
                            jsb_name_len <= {3'b0, name_i} + 8'd4;
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= ".";
                            dir_n <= 8'd1;
                            state <= C_JSB_NWR_W;
                        end else if (src_name[name_i[3:0]] == ".") begin
                            jsb_name_len <= {3'b0, name_i} + 8'd4;
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= ".";
                            dir_n <= 8'd1;
                            state <= C_JSB_NWR_W;
                        end else begin
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= src_name[name_i[3:0]];
                            state <= C_JSB_NWR_W;
                        end
                    end else if (dir_n == 8'd1) begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd1;
                        mem_wdata <= "J";
                        dir_n <= 8'd2;
                        state <= C_JSB_NWR_W;
                    end else if (dir_n == 8'd2) begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd2;
                        mem_wdata <= "S";
                        dir_n <= 8'd3;
                        state <= C_JSB_NWR_W;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd3;
                        mem_wdata <= jsb_want_jsh ? "H" : "B";
                        dir_n <= 8'd4;
                        state <= C_JSB_NWR_W;
                    end
                end
                C_JSB_NWR_W: if (mem_gnt) begin
                    if (dir_n == 8'd0) begin
                        name_i <= name_i + 1'b1;
                        state <= C_JSB_PREP;
                    end else if (dir_n == 8'd4) begin
                        stor_name_len <= jsb_name_len;
                        state <= C_JSB_OPEN;
                    end else
                        state <= C_JSB_PREP;
                end
                C_JSB_NWR: state <= C_JSB_PREP; // unused alias
                C_JSB_OPEN: if (!stor_busy) begin
                    stor_mode <= "I";
                    stor_open <= 1'b1;
                    jsb_waddr <= 0;
                    jsb_bi <= 0;
                    jsb_word <= 0;
                    ld_err <= 0;
                    // NEW: fresh ASET splitter per load
                    jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                    aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                    sram_last <= 0; pal_idx <= 0; pal_ph <= 0;
                    state <= C_JSB_OPENW;
                end
                C_JSB_OPENW: if (stor_done) begin
                    if (stor_err) begin
                        if (jsb_want_jsh && !jsb_tether_mode) begin
                            // no NAME.JSH on card → host tether fallback
                            // (its own ESC + ~10.7s timeout end in ?NB)
                            jsb_tether_mode <= 1'b1;
                            jsb_waddr <= 0; jsb_bi <= 0; jsb_word <= 0;
                            ld_err <= 0;
                            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                            sram_last <= 0; pal_idx <= 0; pal_ph <= 0;
                            state <= C_JSB_TETHER;
                        end else begin
                            // tether-fed retry missing too → ?NH; .JS → ?NB
                            reply_sel <= jsb_want_jsh ? 4'd9 : 4'd7;
                            reply_idx <= 0; state <= C_REPLY;
                        end
                    end else state <= C_JSB_GB;
                end
                C_JSB_GB: if (!stor_busy) begin
                    stor_get_byte <= 1'b1;
                    state <= C_JSB_GBW;
                end
                C_JSB_GBW: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state <= C_JSB_CLOSE;
                    end else if (stor_eof) begin
                        state <= C_JSB_TEOF;
                    end else begin
                        jsb_din <= stor_get_data;
                        state <= C_JSB_FEED;
                    end
                end
                // NEW: HTML RUN — PROG/host byte stream (same splitter as FAT GBW)
                C_JSB_TETHER: begin
                    if (jsb_tether_eof)
                        state <= C_JSB_TEOF;
                    else if (jsb_tether_stb) begin
                        teth_wd <= 30'd0;
                        jsb_din <= jsb_tether_data;
                        state <= C_JSB_FEED;
                    end else if ((!kbd_empty && kbd_data == 8'h1B)
                                 || (&teth_wd)) begin
                        // ESC (head of the kbd FIFO) or ~10.7s of host
                        // silence: fail loud (?NB), never a dead console
                        // (a PS/2 RUN cannot trigger the host compile -
                        // the protocol has no board request)
                        if (!kbd_empty && kbd_data == 8'h1B) kbd_pop <= 1'b1;
                        teth_wd <= 30'd0;
                        ld_err <= 1'b1;
                        reply_sel <= 4'd7; reply_idx <= 0;
                        state <= C_REPLY;
                    end else teth_wd <= teth_wd + 30'd1;
                end
                C_JSB_TEOF: begin
                    if (jsb_bi != 2'd0) begin
                        code_we <= 1'b1;
                        code_waddr <= jsb_waddr;
                        code_wdata <= jsb_word;
                    end
                    // NEW fail loud: header promised an ASET section but the
                    // stream ended early → ?NH, never silent blank sprites
                    if (jsb_has_aset && (!aset_seen || aset_pay < aset_len)) begin
                        ld_err <= 1'b1; reply_sel <= 4'd9; reply_idx <= 0;
                        state <= C_JSB_CLOSE;
                    end else if (aset_seen && aset_pay[0]) begin
                        sram_req <= 1'b1; sram_we <= 1'b1;
                        sram_addr <= aset_pay[21:1];
                        sram_wdata <= {8'h00, sram_lo};
                        sram_last <= 1'b1;
                        state <= C_JSB_SRAMW;
                    end else
                        state <= C_JSB_CLOSE;
                end
                C_JSB_FEED: begin
                    if (jsb_has_aset && jsb_aset_off != 23'd0
                                 && jsb_boff >= 23'd16 && jsb_boff >= jsb_aset_off) begin
                        // ---- ASET section: "ASET" + u32 len, then payload → SRAM
                        jsb_boff <= jsb_boff + 23'd1;
                        state <= jsb_tether_mode ? C_JSB_TETHER : C_JSB_GB;
                        if (aset_rel < 23'd4) begin
                            if ((aset_rel == 23'd0 && jsb_din != "A") ||
                                (aset_rel == 23'd1 && jsb_din != "S") ||
                                (aset_rel == 23'd2 && jsb_din != "E") ||
                                (aset_rel == 23'd3 && jsb_din != "T")) begin
                                ld_err <= 1'b1; reply_sel <= 4'd9; reply_idx <= 0;
                                state <= C_JSB_CLOSE;
                            end
                        end else if (aset_rel < 23'd8) begin
                            unique case (aset_rel[1:0])
                                2'd0: aset_len[7:0]   <= jsb_din;
                                2'd1: aset_len[15:8]  <= jsb_din;
                                2'd2: aset_len[22:16] <= jsb_din[6:0];
                                default: aset_seen <= 1'b1;
                            endcase
                        end else begin
                            if (aset_pay < 23'd768) begin
                                if (pal_ph == 2'd0) begin
                                    pal_r <= jsb_din; pal_ph <= 2'd1;
                                end else if (pal_ph == 2'd1) begin
                                    pal_g <= jsb_din; pal_ph <= 2'd2;
                                end else begin
                                    pal_we <= 1'b1;
                                    pal_waddr <= pal_idx;
                                    pal_wdata <= {pal_r, pal_g, jsb_din};
                                    pal_idx <= pal_idx + 8'd1;
                                    pal_ph <= 2'd0;
                                end
                            end
                            aset_pay <= aset_pay + 23'd1;
                            if (!aset_pay[0])
                                sram_lo <= jsb_din;
                            else begin
                                sram_req <= 1'b1; sram_we <= 1'b1;
                                sram_addr <= aset_pay[21:1];
                                sram_wdata <= {jsb_din, sram_lo};
                                state <= C_JSB_SRAMW;
                            end
                        end
                    end else begin
                        jsb_boff <= jsb_boff + 23'd1;
                        if (jsb_boff == 23'd10) jsb_has_aset <= jsb_din[1];
                        if (jsb_has_aset) begin
                            if (jsb_boff == 23'd12) jsb_aset_off[7:0]   <= jsb_din;
                            if (jsb_boff == 23'd13) jsb_aset_off[15:8]  <= jsb_din;
                            if (jsb_boff == 23'd14) jsb_aset_off[22:16] <= jsb_din[6:0];
                        end
                        case (jsb_bi)
                            2'd0: jsb_word <= {24'h0, jsb_din};
                            2'd1: jsb_word <= {16'h0, jsb_din, jsb_word[7:0]};
                            2'd2: jsb_word <= {8'h0, jsb_din, jsb_word[15:0]};
                            default: begin
                                code_we <= 1'b1;
                                code_waddr <= jsb_waddr;
                                code_wdata <= {jsb_din, jsb_word[23:0]};
                                jsb_waddr <= jsb_waddr + 15'd1;
                            end
                        endcase
                        if (jsb_bi == 2'd3 && jsb_waddr == 15'h7FFF)
                            state <= jsb_tether_mode ? C_JSB_TETHER : C_JSB_PEEK;
                        else begin
                            jsb_bi <= jsb_bi + 2'd1;
                            state <= jsb_tether_mode ? C_JSB_TETHER : C_JSB_GB;
                        end
                    end
                end
                // NEW: hold the SRAM write until the port acks, then stream on
                C_JSB_SRAMW: if (sram_ack) begin
                    sram_req <= 1'b0; sram_we <= 1'b0;
                    state <= sram_last ? C_JSB_CLOSE
                           : (jsb_tether_mode ? C_JSB_TETHER : C_JSB_GB);
                end
                C_JSB_CLOSE: if (jsb_tether_mode) begin
                    // no FAT handle — PROG stream already ended
                    if (ld_err)
                        state <= C_REPLY;
                    else begin
                        vm_start <= 1'b1;
                        reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                    end
                end else if (!stor_busy) begin stor_close <= 1'b1; state <= C_JSB_CLOSEW; end
                C_JSB_CLOSEW: if (stor_done) begin
                    if (ld_err)
                        state <= C_REPLY;
                    else begin
                        vm_start <= 1'b1;
                        reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                    end
                end
                // NEW: code BRAM full after word 7FFF — more code bytes → ?NB, never truncated RUN
                C_JSB_PEEK: if (!stor_busy) begin
                    stor_get_byte <= 1'b1;
                    state <= C_JSB_PEEKW;
                end
                C_JSB_PEEKW: if (stor_done) begin
                    if (stor_err || stor_eof)
                        state <= C_JSB_CLOSE;
                    else if (jsb_has_aset && jsb_aset_off != 23'd0
                             && (jsb_boff + 23'd1) >= jsb_aset_off)
                        state <= C_JSB_CLOSE; // ASET follows — code fit
                    else begin
                        ld_err <= 1'b1; reply_sel <= 4'd7; reply_idx <= 0;
                        state <= C_JSB_CLOSE;
                    end
                end

                default: state <= C_IDLE;
            endcase
            // Console-side storage watchdog (after the case, so it wins the
            // beat). Armed by any stor strobe (read one cycle late - the
            // strobes are 1-cycle registers), cleared on stor_done; the DIR
            // pager is naturally unarmed between pages (done pulses per
            // page). Storage's own 21.5s op watchdog errors first in every
            // storage-side stall, so this fires only for the class where
            // the command never started or done was lost - fail to ?IO,
            // never a dead console.
            if (stor_dir || stor_dir_next || stor_open || stor_readline
                || stor_close || stor_delete || stor_nl_scan
                || stor_get_byte || stor_putc)
                cons_stor_arm <= 1'b1;
            else if (stor_done)
                cons_stor_arm <= 1'b0;
            if (stor_done || !cons_stor_arm)
                cons_stor_wd <= 32'd0;
            else begin
                cons_stor_wd <= cons_stor_wd + 32'd1;
                if (cons_stor_wd[31] && cons_stor_wd[30]) begin // ~32s
                    cons_stor_arm <= 1'b0;
                    cons_stor_wd  <= 32'd0;
                    reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY;
                end
            end

            // ---- SOURCE -> external SRAM bridge (appended; every beat) ----
            // src_req is a 1-beat pulse from the states above; latch it,
            // hold the sram request until ack, then pulse src_gnt with the
            // byte. ASET-flash states drive sram_* too, but never in the
            // same states as source traffic.
            src_gnt <= 1'b0;
            if (src_req && !srcb_pend) begin
                srcb_pend  <= 1'b1;
                sram_req   <= 1'b1;
                sram_we    <= src_we;
                sram_addr  <= SRC_SRAM_BASE + 21'(src_addr);
                sram_wdata <= {8'd0, src_wdata};
                srcb_we_l  <= src_we;
                srcb_wd_l  <= src_wdata;
            end else if (srcb_pend && sram_ack) begin
                srcb_pend <= 1'b0;
                sram_req  <= 1'b0;
                sram_we   <= 1'b0;
                src_rdata <= srcb_we_l ? srcb_wd_l : sram_rdata[7:0];
                src_gnt   <= 1'b1;
            end
        end
    end
endmodule
