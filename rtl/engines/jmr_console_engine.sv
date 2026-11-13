// Program, SOURCE, FAT and compiler services for Finder and tether.
// Named operations enter services directly; no command monitor parser.
// HTML RUN: host compile-on-RUN streams ProgramImage over PROG (missing → ?NH;
// never silently run invaders_jsb.hex). Card is HTML only.
//
module jmr_console_engine (
    input  logic        clk,
    input  logic        rst_n,
    // Keyboard FIFO
    input  logic        failure_dismiss = 1'b0, // supervisor: drop the error reply, no monitor
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
    output logic        command_failed_o,
    output logic [4:0]  fail_reason_o,     // reply code of the failure; valid while command_failed_o
    output logic        interactive_o,
    output logic [2:0] system_role_o,system_stage_o,
    output logic [127:0] ui_source_name_o,
    output logic [4:0] ui_source_len_o,
    output logic ui_unnamed_o,
    // Typed program-loader service; request tuple is held until accepted.
    input logic shell_request=1'b0,
    input logic [95:0] shell_name=96'd0,
    input logic [3:0] shell_len=4'd0,shell_how=4'd8,
    input logic monitor_visible=1'b1,
    input logic host_req_valid=1'b0,
    input logic [183:0] host_req_body=184'd0,
    input logic host_req_crc_ok=1'b0,
    output logic host_req_ready,
    output logic host_q_valid,
    output logic [95:0] host_q_payload,
    input logic host_q_ready=1'b0,
    input logic finder_active_i=1'b0,
    input logic [7:0] app_role_i=8'd0,vm_fault_i=8'd0,
    output logic host_hold_o,host_started,host_started_finder,tether_abort,
    output logic host_receive_request,host_receive_pending,
    input logic host_receive_taken=1'b0,host_receive_yield=1'b0,present_busy_i=1'b0,
    output logic shell_accepted,
    input logic sys_ready,
    output logic sys_we,
    output logic [13:0] sys_addr,
    output logic [15:0] sys_data,
    output logic [1:0] sys_status,
    output logic toolbox_code_we,
    output logic [12:0] toolbox_code_addr,
    output logic [31:0] toolbox_code_data,
    input logic park_finder=1'b0,forget_finder=1'b0,
    input logic document_new=1'b0,
    input logic [2:0] document_new_role=3'd1,
    input logic ui_set_name=1'b0,
    input logic [95:0] ui_name=96'd0,
    input logic [3:0] ui_name_len=4'd0,
    // V1.5 standalone compile: the VM's srcLen() reads this. A wire, not a
    // state — poking the value through memory would cost two encodings.
    output logic [17:0] src_len_o,
    // srcSetLen (VM nid 50): a PROGRAM edited SOURCE — adopt its length so
    // File and compiler services see the edit. Strobe is a one-shot from the VM.
    input  logic [17:0] src_setlen_i,
    input  logic        src_setlen_stb_i,
    input  logic        cmp_done_i,
    input  logic [7:0]  cmp_status_i,
    // Length of the compiler's ASCII diagnostic, staged in the arena at
    // CSTG_HDR_MSG. 0 = no message (a bare ?CE is printed).
    input  logic [6:0]  cmp_msglen_i,
    input  logic [20:0] cmp_len_i,
    input  logic        vm_busy_i,
    output logic        cmp_arm_o,   // high across a compile: no game_mode
    output logic [6:0]  dbg_state,    // E-line console-state telemetry
    // Silicon games ladder: pulse when monitor sees RUN (RECTDEMO only)
    output logic        run_pulse,
    // Start bytecode VM after .JSB loaded into code BRAM
    output logic        vm_start,
    // NEW/CLS halt the VM so leftover game FB does not stick after NEW
    output logic        halt_pulse,
    // Write port into VM code_mem
    output logic [31:0] image_code_bytes,
    output logic image_code_valid,
    output logic        code_we,
    output logic [15:0] code_waddr,
    output logic [31:0] code_wdata,
    // ASET section → external asset SRAM (jmr_sram_port write master)
    output logic        sram_req,
    output logic        sram_we,
    output logic [24:0] sram_addr,
    output logic [15:0] sram_wdata,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack,
    // ASET palette (payload bytes 0..767 = 256×RGB888) → palette BRAM
    output logic        pal_we,
    output logic [7:0]  pal_waddr,
    output logic [23:0] pal_wdata,
    // storage_engine (BASIC handshake)
    output logic        stor_open,
    output logic [7:0]  stor_mode,
    output logic [7:0]  stor_chan,
    output logic [15:0] stor_name_addr,
    output logic [7:0]  stor_name_len,
    output logic        stor_close,
    output logic        stor_readline,
    output logic        stor_get_byte,
    input  logic [7:0]  stor_get_data,
    output logic        stor_putc,
    output logic [7:0]  stor_putc_data,
    output logic        stor_dir,
    output logic        stor_dir_next,
    output logic        stor_dir_all, // 1 = DIR * (show .JSH/.ART)
    output logic        stor_delete,
    input  logic        stor_busy,
    input  logic        stor_done,
    input  logic        stor_err,
    input  logic        stor_eof,
    input  logic [7:0]  stor_line_len,
    // Work RAM master (NAME_BUF 0xB850, STORAGE_BUFFER 0xBB00)
    // SOURCE is a dedicated 64 KiB byte window in external memory.
    output logic        mem_en,
    output logic        mem_we,
    output logic [15:0] mem_addr,
    output logic [7:0]  mem_wdata,
    input  logic [7:0]  mem_rdata,
    input  logic        mem_gnt,
    // HTML RUN streams compiled .JSH over PROG (not FAT). Sim uses JSHLOAD.
    input  logic        jsb_tether_stb = 1'b0,
    input  logic [7:0]  jsb_tether_data = 8'd0,
    input  logic        jsb_tether_eof = 1'b0,
    output logic        jsb_tether_rdy,
    // gui-put: 0xFC SOURCE stream (same wires as 0xFD, tagged src). Tied 0
    // unless uart_link saw 0xFC. FPGA-SIM drives this from SRCSTREAM.
    input  logic        jsb_tether_src = 1'b0,
    input  logic        jsb_tether_big = 1'b0,   // 0xFB CART big put
    input  logic        jsb_tether_crc_err = 1'b0  // With eof — discard the stream, ?CK
);
    localparam logic [15:0] NAME_BUF        = 16'hB850;
    localparam logic [15:0] STORAGE_BUFFER  = 16'hBB00;
    // Dedicated SOURCE BRAM (INVADERS/PACMAN HTML). ASET SRAM stays art from 0.
    // 131072 -> 65536: 13 BRAM tiles back. Card .HTM copies are squashed
    // (make_sd_image) — every title's source fits except MK (85K), whose
    // The editor receives the first 64 KiB; a larger file retains a prefix.
    // Program execution
    // compiles from the host file regardless (C_LD_RD "SOURCE full" arm).
    localparam int unsigned SOURCE_MAX      = 65536;
    // LUTRAM fit: source_mem moved to the external 4MB SRAM
    // (words SRC_SRAM_BASE..+SOURCE_MAX-1, one byte per 16-bit word). The
    // old on-chip array was 8.2k LUTRAM against a failing 46.2k cap. The
    // internal 1-beat req/gnt protocol is kept; consumers already wait on
    // src_gnt, so the extra ack latency is absorbed by the protocol.
    localparam logic [21:0] SRC_SRAM_BASE = 22'd3821568; // below IMGD region
    // V1.5 standalone-compile arena (mirror of jmr_js_vm_pkg / jsb_format).
    // CART: the art arena, words 0..1,480,703, packed 2 bytes per word
    // (2,961,408 B). Staging ground for a big put (0xFB) until SAVE
    // writes it. Mirrors jmr_js_vm_pkg.CART_SRAM_BASE.
    localparam logic [21:0] CART_SRAM_BASE = 21'd0;
    // Big put ceiling: CART bank = jmr_js_vm_pkg.CART_WORDS (1,480,704)
    // x 2 B/word. Mirrored like CART_SRAM_BASE (the console does not import the pkg).
    localparam logic [22:0] BIG_MAX_BYTES = 23'(2*jmr_js_vm_pkg::CART_WORDS);
    localparam logic [21:0] CSCR_SRAM_BASE = 22'd3747840;
    localparam int unsigned CSCR_WORDS     = 73728;
    localparam logic [21:0] CIMG_SRAM_BASE = 22'd3887104;
    localparam logic [20:0] CSTG_HDR_OUT   = 21'd76;  // u32: image offset
    // Item C: 16-byte filename the PROGRAM asks the console to operate on
    // (SAVE / DELETE / LOAD / mint-as). NUL or space terminates.
    localparam logic [20:0] CSTG_HDR_NM    = 21'd96;  // 16 B: filename
    localparam int          CSTG_HDR_NMLEN = 16;
    // Compiler diagnostic text, up to 127 B (cmp_msglen is 7 bits).
    localparam logic [20:0] CSTG_HDR_MSG   = 21'd128;
    localparam logic [20:0] CSTG_HDR_PSEL  = 21'd64;  // u8: next program

    function automatic logic [21:0] cstg_word(input logic [20:0] i);
        cstg_word = (i < 21'(CSCR_WORDS))
            ? (CSCR_SRAM_BASE + i)
            : (CIMG_SRAM_BASE + (i - 21'(CSCR_WORDS)));
    endfunction

    // Chain-program names. Literals, because these are system programs the
    // machine loads by identity, not titles the user names.
    // Chain-program name ROM, 8 rows x 12 chars, indexed by PROGSEL.
    // THIS ORDER IS A CONTRACT: append only, NEVER renumber — the Python
    // side (jsb_format.COMPILE_CHAIN) indexes the same numbers, and a
    // renumber would silently chain-load the wrong program.
    //   0 ARTSCAN  1 ARTPNG  2 COMPILER  3 COMPIL2
    //   4 MINTASM  5 EDIT    6 READ    7 spare (blank -> caller must not chain)
    // Rows 1/3/4/5 exist so those programs ship as CARD FILES with no RTL
    // change; that is the difference between "copy a file" and "re-synthesise".
    function automatic logic [7:0] cmp_name_char(input logic [3:0] sel,
                                                 input logic [6:0] i);
        logic [7:0] c;
        c = 8'h20;
        case (sel)
        3'd0: case (i)                      // "ARTSCAN.JSH"
                7'd0: c = "A"; 7'd1: c = "R"; 7'd2: c = "T"; 7'd3: c = "S";
                7'd4: c = "C"; 7'd5: c = "A"; 7'd6: c = "N"; 7'd7: c = ".";
                7'd8: c = "J"; 7'd9: c = "S"; default: c = "H";
              endcase
        3'd1: case (i)                      // "ARTPNG.JSH"
                7'd0: c = "A"; 7'd1: c = "R"; 7'd2: c = "T"; 7'd3: c = "P";
                7'd4: c = "N"; 7'd5: c = "G"; 7'd6: c = "."; 7'd7: c = "J";
                7'd8: c = "S"; default: c = "H";
              endcase
        3'd2: case (i)                      // "COMPILER.JSH"
                7'd0: c = "C"; 7'd1: c = "O"; 7'd2: c = "M"; 7'd3: c = "P";
                7'd4: c = "I"; 7'd5: c = "L"; 7'd6: c = "E"; 7'd7: c = "R";
                7'd8: c = "."; 7'd9: c = "J"; 7'd10: c = "S"; default: c = "H";
              endcase
        3'd3: case (i)                      // "COMPIL2.JSH"
                7'd0: c = "C"; 7'd1: c = "O"; 7'd2: c = "M"; 7'd3: c = "P";
                7'd4: c = "I"; 7'd5: c = "L"; 7'd6: c = "2"; 7'd7: c = ".";
                7'd8: c = "J"; 7'd9: c = "S"; default: c = "H";
              endcase
        3'd4: case (i)                      // "MINTASM.JSH"
                7'd0: c = "M"; 7'd1: c = "I"; 7'd2: c = "N"; 7'd3: c = "T";
                7'd4: c = "A"; 7'd5: c = "S"; 7'd6: c = "M"; 7'd7: c = ".";
                7'd8: c = "J"; 7'd9: c = "S"; default: c = "H";
              endcase
        3'd5: case (i)                      // "EDITOR.JSH"
                7'd0: c = "E"; 7'd1: c = "D"; 7'd2: c = "I"; 7'd3: c = "T";
                7'd4: c = "O"; 7'd5: c = "R"; 7'd6: c = "."; 7'd7: c = "J";
                7'd8: c = "S"; default: c = "H";
              endcase
        3'd6: case (i)                      // "READ.JSH"
                7'd0: c = "R"; 7'd1: c = "E"; 7'd2: c = "A"; 7'd3: c = "D";
                7'd4: c = "."; 7'd5: c = "J"; 7'd6: c = "S"; default: c = "H";
              endcase
        default: c = 8'h20;                 // 7 spare: blank name
        4'd7:case(i)0:c="C";1:c="O";2:c="M";3:c="P";4:c="I";5:c="L";6:c="E";7:c=".";8:c="J";9:c="S";default:c="H";endcase
        4'd8:case(i)0:c="F";1:c="I";2:c="N";3:c="D";4:c="E";5:c="R";6:c=".";7:c="J";8:c="S";default:c="H";endcase
        endcase
        cmp_name_char = c;
    endfunction
    // Length of each chain-ROM row. MUST track cmp_name_char above — a
    // mismatch truncates or over-reads the filename passed to storage.
    function automatic logic [7:0] cmp_name_len(input logic [3:0] sel);
        case (sel)
            3'd0: cmp_name_len = 8'd11; // ARTSCAN.JSH
            3'd1: cmp_name_len = 8'd10; // ARTPNG.JSH
            3'd2: cmp_name_len = 8'd12; // COMPILER.JSH
            3'd3: cmp_name_len = 8'd11; // COMPIL2.JSH
            3'd4: cmp_name_len = 8'd11; // MINTASM.JSH
            3'd5: cmp_name_len = 8'd10; // EDITOR.JSH
            3'd6: cmp_name_len = 8'd8;  // READ.JSH
            4'd7:cmp_name_len=11;4'd8:cmp_name_len=10;
            default: cmp_name_len = 8'd0; // spare rows: no name
        endcase
    endfunction
    logic        src_req, src_we, src_gnt;
    logic [16:0] src_addr;
    logic [7:0]  src_wdata, src_rdata;
    // High byte of the same SRAM word. Every arena region except CART is
    // 1 B/word so this is normally ignored; CART packs 2 B/word and the
    // ARTX payload append needs both halves.
    logic [7:0]  src_rdata_hi;
    logic        srcb_pend, srcb_we_l;
    logic [7:0]  srcb_wd_l;

    typedef enum logic [6:0] {
        C_PROMPT=7'd2,
        C_IDLE=7'd3,
        C_JSB_DRAIN=7'd6,
        C_WAIT_VIDEO=7'd5,
        C_REPLY=7'd7,
        C_DIR0=7'd8,
        C_DIR0W=7'd9,
        C_DIRN=7'd10,
        C_DIRNW=7'd11,
        C_DIR_RD=7'd12,
        C_DIR_CH=7'd13,
        C_DIR_PUT=7'd14,
        C_DIR_NL=7'd15,
        C_NWR=7'd18,
        C_NWR_W=7'd19,
        C_LD_OPEN=7'd20,
        C_LD_OPENW=7'd21,
        C_LD_RL=7'd22,
        C_LD_RLW=7'd23,
        C_LD_RD=7'd24,
        C_LD_RDW=7'd25,
        C_LD_WRW=7'd26,
        C_LD_NLW=7'd27,
        C_LD_CLOSE=7'd28,
        C_LD_CLOSEW=7'd29,
        C_LD_GB=7'd30,
        C_LD_GBW=7'd31,
        C_LD_GB_WR=7'd32,
        C_SV_OPEN=7'd38,
        C_SV_OPENW=7'd39,
        C_SV_RD=7'd40,
        C_SV_RDW=7'd41,
        C_SV_PUT=7'd42,
        C_SV_PUTW=7'd43,
        C_SV_CLOSE=7'd44,
        C_SV_CLOSEW=7'd45,
        C_RM=7'd46,
        C_RMW=7'd47,
        C_CMP_WAIT=7'd48,
        C_JSB_PREP=7'd79,
        C_JSB_NWR_W=7'd80,
        C_JSB_OPEN=7'd81,
        C_JSB_OPENW=7'd82,
        C_JSB_GB=7'd83,
        C_JSB_GBW=7'd84,
        C_JSB_CLOSE=7'd85,
        C_JSB_CLOSEW=7'd86,
        C_JSB_SRAMW=7'd87,
        C_JSB_PEEK=7'd88,
        C_JSB_PEEKW=7'd89,
        C_JSB_TETHER=7'd90,
        C_JSB_FEED=7'd91,
        C_JSB_TEOF=7'd92,
        C_SRC_TETHER=7'd93,
        C_SRC_WR=7'd94,
        C_BIG_TETHER=7'd95,
        C_BIG_WR=7'd96,
        C_CMP_MSG_RD=7'd99,
        C_CMP_MSG_PUT=7'd100,
        C_SAVE_COMMIT=7'd109,
        C_CACHE_WRITE=7'd111,
        C_CACHE_READ=7'd112,
        C_CACHE_GAP=7'd113,
        C_RESIDENT=7'd114,
        C_SYS=7'd115,
        C_NPUT=7'd116
    } cstate_t;
    // public_flat_rd: sim-only STOR? probe (metacomment, no synthesis effect)
    // Explicit one-hot storage: synthesis did not extract this multi-service
    // controller as an FSM, so an encoding hint alone had no effect. Control
    // reads the individual state bits directly; the binary encoder is for
    // existing diagnostics only and never feeds the next-state decisions.
    (* fsm_encoding = "none" *) logic [116:0] state_q;
    cstate_t state /*verilator public_flat_rd*/, ret_state;
    always_comb begin
        state = cstate_t'(7'd0);
        for (integer code=0;code<117;code=code+1)
            state = cstate_t'(7'(state) | (7'(code) & {7{state_q[code]}}));
    end
    assign dbg_state = 7'(state);

    logic finder_cache_valid /*verilator public_flat_rd*/;
    logic finder_state_valid /*verilator public_flat_rd*/;
    // SYSTEM.SYS is validated in the existing 24 KiB SRAM reservation before
    // any live UI RAM is written. One sequential port, no second resource bank.
    localparam logic [21:0] SYS_STAGE_BASE=22'd3565568;
    localparam int SYS_BYTES=24320;
    logic sys_attempted,sys_good;
    logic sys_rom;
    logic [15:0] rom_low;
    logic [1:0] rom_status /*verilator public_flat_rd*/;
    wire [15:0] sys_length=sys_rom?16'd32768:16'(SYS_BYTES);
    // ROM loads only at cold boot, before SOURCE is live. Reuse SOURCE scratch
    // because a 32KiB ROM would overrun the smaller persistent SYS reservation.
    wire [21:0] resource_stage_base=sys_rom?SRC_SRAM_BASE:SYS_STAGE_BASE;
    logic [3:0] sys_phase;
    logic [15:0] sys_i;
    logic [31:0] sys_crc,sys_expected;
    logic [7:0] sys_low;
    // C_SYS compares of sys_i against the sys_rom-selected length, registered
    // every clock. Phase 5 is entered from phase 4 (which waits on stor_busy)
    // and phase 13 from 12; sys_i and sys_rom only change in phases 1/3/5/9/13
    // or on entry, so the flags are current whenever those phases read them.
    logic sys_at_end_q,sys_past_end_q,sys_last_word_q,sys_pad_q;
    always_ff @(posedge clk)begin
        sys_at_end_q<=sys_i==sys_length+16;
        sys_past_end_q<=sys_i>=sys_length+16;
        sys_last_word_q<=sys_i==(sys_length>>1)-1;
        sys_pad_q<=sys_rom && sys_i>=32780;
    end
    function automatic logic [31:0] sys_crc_byte(input logic [31:0] crc,input logic [7:0] b);
     logic [31:0] c;begin c=crc^{24'd0,b};
      for(integer k=0;k<8;k=k+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;
      sys_crc_byte=c;
     end
    endfunction
    function automatic logic [7:0] sys_header(input logic [3:0] i);
     // JMRS, version u16=1, header u16=16, payload u32=24320.
     case(i)0:sys_header="J";1:sys_header="M";2:sys_header="R";3:sys_header=sys_rom?"T":"S";
      4:sys_header=sys_rom?2:1;6:sys_header=16;8:sys_header=0;9:sys_header=sys_rom?128:95;default:sys_header=0;endcase
    endfunction
    task automatic finish_system_file(input logic [1:0] status);
      if(sys_rom)begin rom_status<=status;sys_rom<=0;sys_i<=0;sys_phase<=0;end
      else begin sys_status<=status;name_i<=0;state_q <= (117'd1 << C_JSB_PREP);end
    endtask
    logic park_pending,resident_restore,resident_init,resident_cancelled;
    logic [2:0] resident_phase;
    logic [16:0] resident_i;
    logic [15:0] resident_word;
    logic finder_cache_fill,finder_cache_replay,cache_tail;
    logic [17:0] finder_cache_length /*verilator public_flat_rd*/;
    logic [7:0] cache_low;
    logic [15:0] cache_word;
    logic [31:0] finder_cache_hits /*verilator public_flat_rd*/;

    logic [4:0] reply_sel;   // 5 bits — rows 16+ (?CK, STATUS)
    assign fail_reason_o = reply_sel;
    logic [6:0] reply_idx;
    logic [6:0] name_i,name_len_r;
    logic service_load_pending;
    logic [95:0] service_name_q;
    logic [3:0] service_how;
    logic [7:0] name_char_q;
    // V1.5 standalone compile
    // 0 = NAME.JSH derived from src_name; 1 = chain-program ROM row
    // selected by cmp_progsel; 2 = filename from the arena header
    // (CSTG_HDR_NAME) for the cdone SAVE/DELETE/LOAD/mint-as ops.
    logic [1:0]  jsb_name_src;
    logic [3:0]  cmp_progsel;   // PROGSEL -> cmp_name_char row (a contract)
    logic raw_save_resume, save_failed; // cdone129 continuation; sticky disk error
    logic        cmp_save_mode;  // C_SV_* pumps the arena instead of SOURCE
    logic        cmp_arm_r;      // held across the whole chain (no game_mode)
    logic [4:0]  cmp_ph;   // 0-5 header, 6 decide, 7-22 filename, 23 dispatch
    logic        cmp_nw;   // filename byte: SRAM read done, mem write pending
    logic [7:0]  cmp_ch;   // diagnostic byte in flight (item G)
    // Item H: the LOADed file exceeded the SOURCE window, so the buffer
    // holds only a prefix. Cleared on any fresh LOAD.
    logic        src_trunc;
    // NEW 2: filename source for a cdone file op — 1 = the loaded title's
    // name (src_name), 0 = the 16-byte name in the arena header.
    logic        cmp_use_srcname;
    // A chain program owns the screen AS A GAME: game_mode rises
    // (framebuffer visible, key events flow). Every entry to C_CMP_WAIT
    // sets it, so that wait has no deadline — an interactive session
    // ends only by cdone, a VM stop, or a host stop.
    logic        cmp_interactive;
    assign interactive_o=cmp_interactive;
    assign system_role_o=cmp_arm_r?3'd3:cmp_interactive?(cmp_progsel==8?3'd0:cmp_progsel==5?3'd1:cmp_progsel==7?3'd3:3'd2):3'd0;
    assign system_stage_o=cmp_progsel;
    assign ui_source_len_o=src_name_len;
    for(genvar ui_n=0;ui_n<16;ui_n=ui_n+1)begin:g_ui_name
        assign ui_source_name_o[ui_n*8+:8]=src_name[ui_n];
    end
    function automatic logic [7:0] ui_untitled(input integer i,input logic note);
        case(i)
            0:ui_untitled="U";1:ui_untitled="N";2:ui_untitled="T";3:ui_untitled="I";
            4:ui_untitled="T";5:ui_untitled="L";6:ui_untitled="E";7:ui_untitled="D";8:ui_untitled=".";
            9:ui_untitled=note?"T":"H";10:ui_untitled=note?"X":"T";11:ui_untitled=note?"T":"M";
            default:ui_untitled=0;
        endcase
    endfunction
    // Art append: after the image bytes the SAVE pump writes cmp_art_len
    // bytes out of the CART arena, where a big put staged them. It is
    // staged rather than streamed file-to-file because storage_engine is
    // single-channel ("channel 1 only").
    // CART holds 2,961,408 B vs the largest payload 2,801,304 B.
    logic        cmp_art_mode;   // this mint appends an ARTX payload
    logic [22:0] cmp_art_len;    // payload bytes to append
    logic [22:0] cmp_art_i;      // bytes appended so far
    logic        cmp_art_hi;     // CART is packed 2 B/word: which half
    // 16-bit CART writes. The bank-1 client zero-extended every
    // write ({8'd0, src_wdata}) so the art stager's low bytes never
    // reached SRAM; src_w16 carries the held low byte alongside.
    logic [7:0]  src_wlo;
    logic        src_w16;
    // Big put (0xFB): .ART/.ARTX streamed into the CART staging
    // bank, packed 2 B/word from word 0; SAVE pumps it through the
    // mint's art-append path (cmp_save_mode + cmp_art_mode, img_len 0).
    logic [22:0] big_len;        // bytes received (max 2*CART_WORDS)
    logic [7:0]  big_lo;         // held low byte of the pair
    logic        big_hi;         // 1 = a low byte is held
    logic        big_eof;        // flushing the odd tail byte at eof
    logic        big_staged;     // CART holds a put; next SAVE writes it
    logic        big_trunc;      // stream exceeded the bank -> SAVE says ?TR
    logic [7:0]  cmp_nm_len;
    logic        cmp_pend;
    logic [21:0] cmp_rd_addr;
    logic [20:0] cmp_out_off;
    logic [20:0] cmp_img_len;
    logic [20:0] cmp_i;
    logic [33:0] cmp_wd;
    logic        src_bank;
    assign cmp_arm_o = cmp_arm_r;
    // Fixed-byte rolling suffix for the typed filename writer.
    logic [7:0] name_tail [0:4];
    // Registered recovery-message ROM (13 levels:
    // reply_char's sel*idx case fed state/reply CEs combinationally).
    // Registered lookup + a one-beat settle whenever sel/idx moved.
    logic [7:0] reply_ch_q;
    logic [6:0] ridx_q;
    logic [4:0] rsel_q;
    logic [7:0] dir_n, dir_idx;
    logic [17:0] src_len /*verilator public_flat_rw*/;     // bytes in SOURCE BRAM (0..131072)
    // src_len==0, written beside every src_len write (the zero test fed the
    // jsb_word/jsb_bi clock enables through the run/open dispatch).
    logic        src_len_z;
    // cdone() race arm: exec64's cmp_done is sticky and its p_clr wipe rides
    // the slow vm_clk header walk — the console reaches C_CMP_WAIT first and
    // consumed the PREVIOUS program's status (board: COMPILE
    // answered OK instantly = the editor's stale F3 quit; second COMPILE
    // worked because launch #1 had cleared the latch). Accept cmp_done only
    // after it has been seen LOW since this launch.
    logic cdone_seen_low;
    logic raw_cdone_armed;
    logic handoff_stop_pending; // wait for VM stop before reading continuation or loading code
    wire raw_cdone_pending = raw_cdone_armed && cmp_done_i &&
        (cmp_status_i == 8'h80 || cmp_status_i == 8'h81);
    assign src_len_o = src_len;
    logic [17:0] src_i;
    logic [7:0]  rd_ch;
    logic cmd_is_load;
    // Last LOADed name (upcased) — classify HTML vs JS vs RECTDEMO
    logic [7:0]  src_name [0:15] /*verilator public_flat_rw*/;
    logic [4:0]  src_name_len /*verilator public_flat_rw*/;
    logic        src_is_rectdemo /*verilator public_flat_rw*/;
    logic        src_is_html /*verilator public_flat_rw*/;   // .HTM / .HTML — RUN loads .JSH (else ?NH)
    logic        src_is_js /*verilator public_flat_rw*/;     // .JS — RUN loads companion .JSB
    logic        jsb_want_jsh;  // HTML sidecar uses .JSH not .JSB
    // Board directive: no wait may hard-wedge the console.
    // C_JSB_TETHER waits on the HOST (the protocol has no board->host
    // request: the host only compiles when it saw RUN typed through the
    // GUI, so a PS/2 RUN waits forever). ESC aborts; ~10.7s of stream
    // silence (2^30 clks, reset per byte) aborts too. And a generic
    // storage watchdog: armed on any stor strobe, cleared on stor_done,
    // ~32s (longer than storage's own 21.5s op watchdog, so storage
    // always errors first and this is pure belt-and-braces).
    logic [30:0] teth_wd; // bit 30 = expired (one flop, no 30-input AND in the state decode)
    logic [31:0] cons_stor_wd;
    logic        cons_stor_arm;
    // Universal progress watchdog (board directive: DIR must NOT be able
    // to freeze, root cause known or not). Any state that is not an
    // interactive wait must make progress; ~21.5s parked anywhere else
    // forces ?IO + prompt. The tether wait has its own shorter timeout.
    logic [31:0] cons_prog_wd;
    logic        jsb_tether_mode; // HTML RUN — bytes from PROG, not FAT
    logic [7:0]  jsb_din;         // Latched stream byte (FAT or tether)
    // JSB stream packer
    logic [15:0] jsb_waddr;
    logic [1:0]  jsb_bi;        // byte index 0..3 within word
    logic [31:0] jsb_word;
    logic [7:0]  jsb_name_len;
    // ASET stream splitter — code bytes → code BRAM (as before), ASET
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
    // C_JSB_FEED / C_JSB_TEOF decisions, registered every clock. The state
    // before FEED is always GB, GBW, TETHER or CACHE_GAP (TEOF: one of those
    // or DRAIN/CACHE_GAP), none of which writes jsb_boff, jsb_aset_off,
    // jsb_has_aset, aset_seen, aset_len, aset_pay, jsb_bi or jsb_waddr; the
    // states that do (FEED, the load set-up) never lead straight into FEED.
    // So each flag equals the compare on the current value when it is read.
    logic        feed_big_q, feed_aset_q, rel_lt4_q, rel_lt8_q, pay_lt768_q;
    logic        boff_ge16_q, boff_eq10_q, boff_eq12_q, boff_eq13_q, boff_eq14_q;
    logic        waddr_full_q;
    logic [1:0]  rel_lo_q;
    always_ff @(posedge clk) begin
        feed_big_q  <= aset_seen && aset_len > 2*jmr_js_vm_pkg::CART_WORDS;
        feed_aset_q <= jsb_has_aset && jsb_aset_off != 23'd0
                       && jsb_boff >= 23'd16 && jsb_boff >= jsb_aset_off;
        rel_lt4_q   <= aset_rel < 23'd4;
        rel_lt8_q   <= aset_rel < 23'd8;
        rel_lo_q    <= aset_rel[1:0];
        pay_lt768_q <= aset_pay < 23'd768;
        boff_ge16_q <= jsb_boff >= 23'd16;
        boff_eq10_q <= jsb_boff == 23'd10;
        boff_eq12_q <= jsb_boff == 23'd12;
        boff_eq13_q <= jsb_boff == 23'd13;
        boff_eq14_q <= jsb_boff == 23'd14;
        waddr_full_q <= jsb_waddr == 16'hFFFF;
    end
    assign jsb_tether_rdy = (state_q[C_JSB_DRAIN]) || (state_q[C_JSB_TETHER]) || (state_q[C_SRC_TETHER])
                         || (state_q[C_BIG_TETHER]);
    logic        ld_err;        // LOAD ?LS/?IO sticky until CLOSEW



    // DIR handshake self-heal: board capture proved storage can
    // return to idle without the console ever seeing done (32 s ?IO with
    // both sides idle). If the wait state sees storage idle AND silent for
    // 2^22 clks (42 ms — impossible mid-op, busy is high then), re-issue
    // the request. Bounded; the watchdogs still backstop.
    logic [21:0] dir_hs_wd;
    logic [1:0]  dir_hs_retry;
    logic        dir_hs_hit; // registered (&dir_hs_wd): keeps the 22-wide AND
                             // out of the dispatch cone

    

    // EDIT n

    // Case-insensitive compare helpers (FIFO no longer folds a-z)
    function automatic logic [7:0] up(input logic [7:0] c);
        up = (c >= 8'h61 && c <= 8'h7A) ? (c - 8'h20) : c;
    endfunction
    function automatic logic is_sp(input logic [7:0] c);
        is_sp = (c == " ");
    endfunction

    // Error messages remain read-only recovery diagnostics. Commands and
    // normal progress text have no parser, keyboard editor or pager here.
    always_ff @(posedge clk) begin
        reply_ch_q<=reply_char(reply_sel,reply_idx);
        ridx_q<=reply_idx;rsel_q<=reply_sel;
    end
    function automatic logic service_error(input logic [4:0] code);
        service_error=code==4 || code==6 || code==7 || code==9 || code==10 || code==14 || code==15 || code==16 || code==17;
    endfunction
    function automatic logic [7:0] reply_char(input logic [4:0] code,input logic [6:0] i);
        if(i==0)reply_char=service_error(code)?"?":8'd0;
        else if(i==1)case(code)
            4:reply_char="I";6:reply_char="F";7:reply_char="N";
            9:reply_char="N";10:reply_char="L";14:reply_char="C";15:reply_char="T";16:reply_char="C";17:reply_char="T";
            default:reply_char=0;
        endcase
        else if(i==2)case(code)
            4:reply_char="O";6:reply_char="N";7:reply_char="B";
            9:reply_char="H";10:reply_char="S";14:reply_char="E";15:reply_char="R";16:reply_char="K";17:reply_char="B";
            default:reply_char=0;
        endcase
        else reply_char=0;
    endfunction

    assign ready_lit = (state_q[C_IDLE] || state_q[C_PROMPT]) && !park_pending && !raw_cdone_pending;
    assign stor_chan = 8'd1;
    assign stor_name_addr = NAME_BUF;

    // SOURCE lives in external SRAM; the req/gnt bridge is appended inside
    // the main console FSM block (it shares the sram_* channel with the
    // ASET flash states, which never overlap source traffic).

    // Loader services also used by explicit recovery commands. They only
    // assign the existing registers/states; no extra instruction/pixel cycles.
    task automatic run_loaded_source;
        begin
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
                            state_q <= (117'd1 << C_JSB_PREP);
                        end else if (src_is_rectdemo) begin
                            run_pulse <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                        end else if (src_len_z && !src_is_js) begin
                            run_pulse <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                        end else if (src_is_js || src_name_len != 0) begin
                            // Any LOADed program (INVADERS / PACMAN.JS / …) → NAME.JSB
                            jsb_want_jsh <= 1'b0;
                            jsb_tether_mode <= 1'b0;
                            name_i <= 0;
                            dir_n <= 0;
                            jsb_waddr <= 0;
                            jsb_bi <= 0;
                            jsb_word <= 0;
                            state_q <= (117'd1 << C_JSB_PREP);
                        end else begin
                            reply_sel <= 4'd7; reply_idx <= 0; state_q <= (117'd1 << C_REPLY); // ?NB
                        end
        end
    endtask
    task automatic open_document(input logic reader);
        begin
                        if (src_len_z && src_name_len==0) begin
                            reply_sel <= 4'd7; reply_idx <= 0; // ?NB
                            state_q <= (117'd1 << C_REPLY);
                        end else begin
                            // NO cmp_arm: the editor is a GAME (visible,
                            // interactive). cdone still reaches C_CMP_WAIT.
                            cmp_arm_r <= 1'b0;
                            cmp_interactive <= 1'b1;
                            jsb_name_src <= 2'd1; cmp_progsel <= reader ? 4'd6 : 4'd5;
                            cmp_save_mode <= 1'b0;
                            jsb_want_jsh <= 1'b1; jsb_tether_mode <= 1'b0;
                            name_i <= 0; dir_n <= 0; jsb_waddr <= 0;
                            jsb_bi <= 0; jsb_word <= 0; ld_err <= 0;
                            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                            sram_last <= 0; cmp_wd <= '0; cmp_ph <= 5'd0;
                            cmp_nw <= 1'b0; cmp_nm_len <= 8'd0;
                            cmp_pend <= 1'b0;
                            state_q <= (117'd1 << C_JSB_PREP);
                        end
        end
    endtask
    task automatic start_system(input logic [3:0] program_slot);
        begin
            src_bank<=0;cmp_arm_r<=0;cmp_interactive<=1;
            jsb_name_src<=1;cmp_progsel<=program_slot;
            cmp_save_mode<=0;jsb_want_jsh<=1;jsb_tether_mode<=0;
            name_i<=0;dir_n<=0;jsb_waddr<=0;jsb_bi<=0;jsb_word<=0;ld_err<=0;
            jsb_boff<=0;jsb_aset_off<=0;jsb_has_aset<=0;aset_seen<=0;aset_len<=0;aset_pay<=0;
            sram_last<=0;cmp_wd<=0;cmp_ph<=0;cmp_nw<=0;cmp_nm_len<=0;cmp_pend<=0;
            cache_tail<=0;finder_cache_fill<=0;finder_cache_replay<=0;
            pal_idx<=0;pal_ph<=0;
            if(program_slot==8 && !sys_attempted)begin
                sys_attempted<=1;sys_i<=0;sys_phase<=0;state_q <= (117'd1 << C_SYS);
            end else if(program_slot==8 && finder_cache_valid)begin
                finder_cache_replay<=1;finder_cache_hits<=finder_cache_hits+1'b1;
                cdone_seen_low<=0;state_q <= (117'd1 << C_JSB_GB);
            end else state_q <= (117'd1 << C_JSB_PREP);
        end
    endtask
    task automatic launch_loaded_source;
        begin
            service_load_pending<=0;
            case(service_how)
                1: open_document(1'b0);
                2: open_document(1'b1);
                3: start_system(4'd7);
                default: run_loaded_source();
            endcase
        end
    endtask

    // Single-owner typed tether services. Packets and responses are held until
    // accepted; no operation depends on text output or keyboard commands.
    typedef enum logic [2:0] {H_NONE,H_CHECK,H_BEGIN,H_STOP,H_PARK,H_WAIT,H_NOTIFY} host_state_t;
    host_state_t host_state;
    logic host_active,host_owned,host_last_valid,host_finish_pending,host_status_tail,host_link_event,tether_abort_q;
    logic [183:0] host_body,host_last_body;
    logic [7:0] host_result_status,host_last_status;
    logic [31:0] host_result_value,host_last_value,host_status_tx;
    logic source_stage_valid,cart_stage_valid,library_dirty;
    logic [7:0] source_stage_error,cart_stage_error;
    logic [3:0] host_check_i,host_stem_n,host_ext_n;
    logic host_dot,host_bad_name,host_stream_announced;
    logic [95:0] host_check_name;
    logic [31:0] host_watchdog,catalog_count;
    logic [95:0] catalog_name;
    logic [1:0] catalog_chunk;
    wire [7:0] host_op=host_body[15:8];
    wire [31:0] host_tx=host_body[47:16],host_arg=host_body[79:48];
    wire [7:0] host_name_len=host_body[87:80];
    wire [95:0] host_name=host_body[183:88];
    // Build 96 timing: the request from u_link lands in a plain console-side
    // register (hreq_*) before any decode, with its request-only verdicts
    // (version, op, length, argument ranges) computed on the way in. The
    // accepted request's op/argument flags (ho_*/ha_*) are written beside
    // host_body so H_BEGIN and host_begin_owned decode registered bits, not
    // 8-/32-bit compares. Costs one clock per tether request; no program-
    // visible latency.
    logic hreq_v,hreq_crc_ok,hreq_badver,hreq_op0,hreq_op6,hreq_opgt7,hreq_len_bad;
    logic hreq_arg_eq0,hreq_arg_gt1,hreq_arg_gt3,hreq_arg_lt16,hreq_arg_gt7f;
    logic [183:0] hreq_body;
    logic ho_1,ho_2,ho_3,ho_4,ho_5,ho_7,ho_23,ho_name;
    logic ha_eq0,ha_gt1,ha_gt3,ha_lt16,ha_gt7f;
    logic arg_ne_src_q,arg_ne_big_q,hb_wait_q;
    wire host_req_go=hreq_v && !host_q_valid && !host_finish_pending && !host_status_tail && !host_link_event;
    // Full packet identity remains exact; keep its combinational
    // reduction balanced across native words instead of a tall carry chain.
    (* keep="true", dont_touch="true" *) wire [5:0] request_same_active_words,request_same_last_words;
    for(genvar word=0;word<5;word=word+1)begin: g_host_identity
        assign request_same_active_words[word]=hreq_body[word*32+:32]==host_body[word*32+:32];
        assign request_same_last_words[word]=hreq_body[word*32+:32]==host_last_body[word*32+:32];
    end
    assign request_same_active_words[5]=hreq_body[183:160]==host_body[183:160];
    assign request_same_last_words[5]=hreq_body[183:160]==host_last_body[183:160];
    wire [7:0] request_op=hreq_body[15:8];
    wire [31:0] request_tx=hreq_body[47:16],request_arg=hreq_body[79:48];
    wire [31:0] host_snapshot={8'd0,vm_fault_i,app_role_i,1'b0,tether_abort,finder_active_i,host_owned,
        cart_stage_valid,source_stage_valid,stor_busy,vm_busy_i};
    assign host_req_ready=!hreq_v;
    assign host_hold_o=host_owned || host_active;
    assign host_receive_pending=host_active && ho_1 && ha_eq0 &&
        (host_state==H_NOTIFY || host_state==H_STOP || host_state==H_PARK);
    function automatic logic fat_letter(input logic [7:0] c);
        fat_letter=c>=8'd33 && c<=8'd126 && c!="." && c!="/" && c!="\\" &&
            c!=":" && c!="*" && c!="?" && c!=34 && c!="<" && c!=">" && c!="|" &&
            c!="+" && c!="," && c!=";" && c!="=" && c!="[" && c!="]";
    endfunction
    task automatic host_reply(input logic [7:0] op,input logic [31:0] tx,
        input logic [7:0] phase,status,input logic [31:0] value);
        begin host_q_valid<=1;host_q_payload<={8'd1,op,tx,phase,status,value};end
    endtask
    task automatic host_finish(input logic [7:0] status,input logic [31:0] value);
        begin
            host_result_status<=status;host_result_value<=value;
            host_finish_pending<=1;host_state<=H_NONE;host_receive_request<=0;
        end
    endtask
    task automatic host_begin_owned;
        begin
            // ho_* are one-hot copies of host_op written with host_body.
            if(ho_1)begin
                    if(ha_eq0)begin host_owned<=1;host_finish(0,0);end
                    else begin
                        host_owned<=0;source_stage_valid<=0;cart_stage_valid<=0;
                        if(library_dirty)begin
                            sys_attempted<=0;finder_cache_valid<=0;finder_state_valid<=0;
                            library_dirty<=0;
                            // C_SYS must be selected now (nonblocking resets
                            // above cannot alter start_system's current guard).
                            start_system(4'd8);sys_attempted<=1;sys_rom<=1;sys_i<=0;sys_phase<=0;state_q <= (117'd1 << C_SYS);
                        end else start_system(4'd8);
                        host_state<=H_WAIT;
                    end
            end else if(ho_23)begin
                    service_name_q<=host_name;name_len_r<=7'(host_name_len);name_i<=0;
                    cmd_is_load<=0;
                    cmp_save_mode<=0;cmp_art_mode<=0;raw_save_resume<=0;src_bank<=0;
                    big_staged<=ho_3;
                    state_q <= (117'd1 << C_NWR);host_state<=H_WAIT;
            end else if(ho_4)begin
                    host_owned<=0;service_name_q<=host_name;service_how<=host_arg[3:0];
                    service_load_pending<=1;name_len_r<=7'(host_name_len);name_i<=0;
                    cmd_is_load<=1;src_bank<=0;src_trunc<=0;
                    state_q <= (117'd1 << C_NWR);host_state<=H_WAIT;
            end else if(ho_5)begin
                    host_owned<=0;start_system(4'd7);
                    cmp_interactive<=0;jsb_name_src<=0;jsb_tether_mode<=1;
                    state_q <= (117'd1 << C_JSB_TETHER);host_state<=H_WAIT;
            end else if(ho_7)begin
                    stor_dir_all<=1;catalog_count<=0;
                    dir_hs_wd<=0;dir_hs_retry<=0;
                    state_q <= (117'd1 << C_DIR0);host_state<=H_WAIT;
            end else host_finish(3,0);
        end
    endtask

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_q <= (117'd1 << C_PROMPT);
            host_receive_request<=0;host_started<=0;host_started_finder<=0;tether_abort<=0;tether_abort_q<=0;host_link_event<=0;
            host_state<=H_NONE;host_active<=0;host_owned<=0;host_last_valid<=0;
            host_finish_pending<=0;host_status_tail<=0;host_body<=0;host_last_body<=0;
            hreq_v<=0;ho_1<=0;ho_2<=0;ho_3<=0;ho_4<=0;ho_5<=0;ho_7<=0;ho_23<=0;ho_name<=0;
            ha_eq0<=0;ha_gt1<=0;ha_gt3<=0;ha_lt16<=0;ha_gt7f<=0;
            host_result_status<=0;host_result_value<=0;host_last_status<=0;host_last_value<=0;
            host_status_tx<=0;host_q_valid<=0;host_q_payload<=0;
            source_stage_valid<=0;cart_stage_valid<=0;source_stage_error<=0;cart_stage_error<=0;library_dirty<=0;
            host_check_i<=0;host_stem_n<=0;host_ext_n<=0;host_dot<=0;host_bad_name<=0;host_stream_announced<=0;host_check_name<=0;
            host_watchdog<=0;catalog_count<=0;catalog_name<=0;catalog_chunk<=0;
            service_load_pending<=0;service_name_q<=0;service_how<=0;shell_accepted<=0;
            command_failed_o <= 1'b0;
            ret_state <= C_IDLE;

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
            image_code_bytes<=0;image_code_valid<=0;
            
            stor_open <= 0; stor_close <= 0; stor_readline <= 0; stor_get_byte <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            
            stor_mode <= "I"; stor_name_len <= 0; stor_putc_data <= 0;
            mem_en <= 0; mem_we <= 0; mem_addr <= 0; mem_wdata <= 0;
            src_req <= 0; src_we <= 0; src_addr <= 0; src_wdata <= 0;
            src_gnt <= 0; src_rdata <= 0; src_rdata_hi <= 0; srcb_pend <= 0; srcb_we_l <= 0; srcb_wd_l <= 0;
            src_len <= 0; src_len_z <= 1'b1; src_i <= 0;
            jsb_name_src <= 2'd0; cmp_progsel <= 3'd0;
            raw_save_resume <= 0; save_failed <= 0;
            cmp_save_mode <= 1'b0; cmp_arm_r <= 1'b0;
            cmp_ph <= 5'd0; cmp_nw <= 1'b0; cmp_nm_len <= 8'd0; cmp_pend <= 1'b0; cmp_rd_addr <= '0;
            src_trunc <= 1'b0; cmp_use_srcname <= 1'b0;
            sys_rom<=1;rom_status<=0;rom_low<=0;toolbox_code_we<=0;toolbox_code_addr<=0;toolbox_code_data<=0;sys_we<=0;sys_addr<=0;sys_data<=0;sys_status<=0;sys_attempted<=0;sys_good<=0;sys_phase<=0;sys_i<=0;sys_crc<=0;sys_expected<=0;sys_low<=0;
            finder_state_valid<=0;park_pending<=0;resident_restore<=0;resident_init<=0;resident_cancelled<=0;resident_phase<=0;resident_i<=0;resident_word<=0;
            finder_cache_valid<=0;finder_cache_fill<=0;finder_cache_replay<=0;finder_cache_length<=0;cache_tail<=0;cache_low<=0;cache_word<=0;finder_cache_hits<=0;
            cmp_interactive <= 1'b0;
            ui_unnamed_o<=0;
            cdone_seen_low <= 1'b0;
            raw_cdone_armed <= 1'b0;
            handoff_stop_pending <= 1'b0;
            cmp_art_mode <= 1'b0; cmp_art_len <= '0;
            src_wlo <= '0; src_w16 <= 1'b0;
            big_len <= '0; big_lo <= '0; big_hi <= 1'b0; big_eof <= 1'b0;
            big_staged <= 1'b0; big_trunc <= 1'b0;
            cmp_art_i <= '0; cmp_art_hi <= 1'b0;
            cmp_out_off <= '0; cmp_img_len <= '0; cmp_i <= '0; cmp_wd <= '0;
            src_bank <= 1'b0;
            name_len_r <= 0; name_i <= 0;   name_char_q<=0;
            dir_n <= 0; dir_idx <= 0;
            cmd_is_load <= 0;  
            stor_dir_all <= 1'b0;
            src_name_len <= 0; src_is_rectdemo <= 0; src_is_html <= 0; src_is_js <= 0;
            jsb_waddr <= 0; jsb_bi <= 0; jsb_word <= 0; jsb_name_len <= 0;
            jsb_want_jsh <= 1'b0;
            jsb_tether_mode <= 1'b0;
            teth_wd <= 30'd0;
            cons_stor_wd <= 32'd0;
            cons_stor_arm <= 1'b0;
            cons_prog_wd <= 32'd0;
            jsb_din <= 8'h0;
            ld_err <= 0;
              
            sram_req <= 0; sram_we <= 0; sram_addr <= 0; sram_wdata <= 0;
            pal_we <= 0; pal_waddr <= 0; pal_wdata <= 0;
            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
            sram_lo <= 0; sram_last <= 0;
            pal_r <= 0; pal_g <= 0; pal_idx <= 0; pal_ph <= 0;

              
             
        end else begin
            shell_accepted<=0;host_started<=0;
            toolbox_code_we<=0;
            
            kbd_pop <= 0;
            kbd_clear<=0;
            cls <= 0;
            put_en <= 0;
            print_nl <= 0;
            run_pulse <= 0;
            vm_start <= 0;
            halt_pulse <= 0;
            code_we <= 0;
            stor_open <= 0; stor_close <= 0; stor_readline <= 0; stor_get_byte <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            
            mem_en <= 0; mem_we <= 0;
            src_req <= 0; src_we <= 0;
            pal_we <= 0; // 1-cycle palette write strobes (sram_req holds to ack)

            // srcSetLen (VM nid 50): a PROGRAM edited SOURCE. Placed BEFORE
            // the state case on purpose — a console action in the same beat
            // (LOAD/EDIT writing src_len) must win, since the console owns
            // the buffer whenever it is not parked waiting on the VM.
            if (src_setlen_stb_i) begin src_len <= src_setlen_i; src_len_z <= src_setlen_i == 18'd0; end
            sys_we<=0;
            // Ordinary RUN callers may request the same raw continuation as
            // interactive clients. Require a fresh low before accepting sticky
            // cdone, and reserve the console before the shell can return Home.
            if (handoff_stop_pending && !vm_busy_i) handoff_stop_pending <= 0;
            if (state_q[C_CMP_WAIT]) raw_cdone_armed <= 0;
            else if (vm_busy_i && !cmp_done_i) raw_cdone_armed <= 1;
            // A discarded Finder copy must drain its current SRAM beat but
            // must neither publish a parked image nor start a restored VM.
            if (!state_q[C_RESIDENT]) resident_cancelled <= 0;
            else if (forget_finder) resident_cancelled <= 1;
            unique case (1'b1)
                state_q[C_PROMPT]: begin
                    raw_save_resume<=0;src_bank<=0;cmp_save_mode<=0;
                    cmp_art_mode<=0;cmp_interactive<=0;
                    big_staged<=0;src_w16<=0;jsb_name_src<=0;
                    state_q <= (117'd1 << C_IDLE);
                end
                state_q[C_IDLE]: begin
                    // Bulk staging is accepted only under Finder ownership.
                    if (host_owned && jsb_tether_src) begin
                        src_len <= 0; src_len_z <= 1'b1;
                        src_trunc <= 1'b0;
                        src_i <= 0;
                        src_bank <= 1'b0;
                        teth_wd <= 30'd0;
                        state_q <= (117'd1 << C_SRC_TETHER);
                    end else if (host_owned && jsb_tether_big) begin
                        // 0xFB big put -> CART staging bank
                        big_len <= '0; big_hi <= 1'b0; big_eof <= 1'b0;
                        big_staged <= 1'b0; big_trunc <= 1'b0;
                        src_bank <= 1'b1;
                        teth_wd <= 30'd0;
                        state_q <= (117'd1 << C_BIG_TETHER);
                    end
                end
                state_q[C_WAIT_VIDEO]: begin
                    if (!video_busy) begin
                        // Every ret_state writer selects one of these four
                        // constants. Explicit targets permit FSM extraction;
                        // a general state-register data input prevented it.
                        case (ret_state)
                            C_PROMPT: state_q <= (117'd1 << C_PROMPT);
                            C_REPLY: state_q <= (117'd1 << C_REPLY);
                            C_CMP_MSG_RD: state_q <= (117'd1 << C_CMP_MSG_RD);
                            default: state_q <= (117'd1 << C_IDLE);
                        endcase
                    end
                end
                state_q[C_REPLY]: begin
                    service_load_pending<=0;
                    if(!service_error(reply_sel))state_q <= (117'd1 << C_PROMPT);
                    else if(host_owned)begin
                        // Bulk CRC/range failures are staged status for the
                        // following COMMIT; no monitor display blocks recovery.
                        command_failed_o<=0;state_q <= (117'd1 << C_PROMPT);
                    end else begin
                        command_failed_o<=1;
                        if(failure_dismiss)begin command_failed_o<=0;state_q <= (117'd1 << C_PROMPT);end
                        else if(ridx_q!=reply_idx || rsel_q!=reply_sel)begin end
                        else if(!monitor_visible)begin end
                        else if(reply_ch_q==0)begin
                            if(reply_sel==14 && cmp_msglen_i!=0)begin
                                cmp_i<=0;cmp_pend<=0;state_q <= (117'd1 << C_CMP_MSG_RD);
                            end else begin print_nl<=1;state_q <= (117'd1 << C_WAIT_VIDEO);ret_state<=C_PROMPT;end
                        end else if(!video_busy)begin
                            put_en<=1;put_char<=reply_ch_q;reply_idx<=reply_idx+1'b1;
                            state_q <= (117'd1 << C_WAIT_VIDEO);ret_state<=C_REPLY;
                        end
                    end
                end

                state_q[C_DIR0]: if (!stor_busy) begin
                    stor_dir <= 1'b1;
                    
                    dir_hs_wd <= 22'd0;
                    dir_hs_retry <= 2'd0;
                    state_q <= (117'd1 << C_DIR0W);
                end
                state_q[C_DIR0W]: if (stor_done) begin
                    dir_hs_wd <= 22'd0;
                    if (stor_err) begin
                        // transient SPI/mount error: retry (S_ERR poisoned the
                        // mount, so this re-strobe remounts cleanly) — heals
                        // the long-standing intermittent ?IO on DIR/LIST
                        if (dir_hs_retry != 2'd3) begin
                            dir_hs_retry <= dir_hs_retry + 2'd1;
                            stor_dir <= 1'b1;
                        end else begin reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY); end
                    end
                    else state_q <= (117'd1 << C_DIRN);
                end else if (!stor_busy && dir_hs_hit && dir_hs_retry != 2'd3) begin
                    dir_hs_retry <= dir_hs_retry + 2'd1;
                    dir_hs_wd <= 22'd0;
                    stor_dir <= 1'b1; // lost handshake: restart the catalog
                end else if (!kbd_empty && kbd_data == 8'h1B) begin
                    // ESC while storage works: consume it, bail to prompt.
                    // A late stor_done pulse with nobody waiting is ignored;
                    // storage completes or watchdogs out on its own.
                    kbd_pop <= 1'b1;
                     state_q <= (117'd1 << C_PROMPT);
                end
                state_q[C_DIRN]: if (!stor_busy) begin
                    stor_dir_next <= 1'b1;
                    dir_hs_wd <= 22'd0;
                    state_q <= (117'd1 << C_DIRNW);
                end
                state_q[C_DIRNW]: if (stor_done) begin
                    dir_hs_wd <= 22'd0;
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY); end
                    else if (stor_eof) begin host_finish(0,catalog_count);state_q <= (117'd1 << C_PROMPT);end
                    else begin
                        dir_n <= stor_line_len; dir_idx <= 0;catalog_name<=0;catalog_chunk<=0;
                        state_q <= (117'd1 << C_DIR_RD);
                    end
                end else if (!stor_busy && dir_hs_hit && dir_hs_retry != 2'd3) begin
                    dir_hs_retry <= dir_hs_retry + 2'd1;
                    dir_hs_wd <= 22'd0;
                    stor_dir_next <= 1'b1; // lost handshake: fetch next name
                end else if (!kbd_empty && kbd_data == 8'h1B) begin
                    kbd_pop <= 1'b1;
                     state_q <= (117'd1 << C_PROMPT);
                end
                state_q[C_DIR_RD]: begin
                    if(dir_n==0 || dir_n>12)begin host_finish(5,0);state_q <= (117'd1 << C_PROMPT);end
                    else if(dir_idx>=12)state_q <= (117'd1 << C_DIR_NL);
                    else if(dir_idx>=dir_n)begin
                        catalog_name<={8'd0,catalog_name[95:8]};dir_idx<=dir_idx+1'b1;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                        state_q <= (117'd1 << C_DIR_CH);
                    end
                end
                state_q[C_DIR_CH]: if (mem_gnt) begin
                    rd_ch <= mem_rdata;catalog_name<={mem_rdata,catalog_name[95:8]};
                    dir_hs_wd <= 22'd0;
                    state_q <= (117'd1 << C_DIR_PUT);
                end else if (dir_hs_hit) begin
                    // The mem request is a 1-cycle pulse into a
                    // shared latch — if the latch was busy that cycle the
                    // pulse is DROPPED and nothing re-asks (board R49:
                    // console parked here, cons=0x0D, 21.5s ?IO). Re-issue
                    // the identical read; repeats until granted.
                    dir_hs_wd <= 22'd0;
                    mem_en <= 1'b1; mem_we <= 1'b0;
                    mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                end
                state_q[C_DIR_PUT]: begin
                    dir_idx<=dir_idx+1'b1;state_q <= (117'd1 << C_DIR_RD);
                end
                state_q[C_DIR_NL]:if(!host_q_valid && !host_finish_pending && !host_status_tail && !hreq_v && !host_req_valid)begin
                    host_reply(7,host_tx,8'h10+{6'd0,catalog_chunk},dir_n,catalog_name[31:0]);
                    catalog_name<=catalog_name>>32;catalog_chunk<=catalog_chunk+1'b1;
                    if(catalog_chunk==2)begin catalog_count<=catalog_count+1'b1;state_q <= (117'd1 << C_DIRN);end
                end

                state_q[C_NWR]: begin
                    if (name_i >= name_len_r) begin
                        stor_name_len <= {1'b0, name_len_r};
                        // Retain the normalized SOURCE filename and suffix.
                        if (cmd_is_load) begin
                            ui_unnamed_o<=0;
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
                        if (cmd_is_load) state_q <= (117'd1 << C_LD_OPEN);
                        else state_q <= (117'd1 << C_SV_OPEN);
                    end else begin
                        name_char_q<=service_name_q[7:0];
                        state_q <= (117'd1 << C_NPUT);
                    end
                end
                state_q[C_NPUT]:begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i};
                        // FAT 8.3 is uppercase — match BASIC storage_engine
                        mem_wdata <= up(name_char_q);
                        if (name_i < 16)
                            src_name[name_i[3:0]] <= up(name_char_q);
                        name_tail[0] <= up(name_char_q);
                        name_tail[1] <= name_tail[0];
                        name_tail[2] <= name_tail[1];
                        name_tail[3] <= name_tail[2];
                        name_tail[4] <= name_tail[3];
                        state_q <= (117'd1 << C_NWR_W);
                end
                state_q[C_NWR_W]: if (mem_gnt) begin
                    service_name_q<=service_name_q>>8;
                    name_i <= name_i + 1'b1;
                    state_q <= (117'd1 << C_NWR);
                end

                // ---- LOAD -----------------------------------------------
                state_q[C_LD_OPEN]: if (!stor_busy) begin
                    stor_mode <= "I";
                    stor_open <= 1'b1;
                    src_len <= 0; src_len_z <= 1'b1;
                    ld_err <= 0;
                    state_q <= (117'd1 << C_LD_OPENW);
                end
                state_q[C_LD_OPENW]: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd6; reply_idx <= 0; state_q <= (117'd1 << C_REPLY); end
                    // HTML: copy bytes into SOURCE (prefix) — long data: lines must not ?LS
                    else if (src_is_html) state_q <= (117'd1 << C_LD_GB);
                    else state_q <= (117'd1 << C_LD_RL);
                end
                state_q[C_LD_RL]: if (!stor_busy) begin
                    stor_readline <= 1'b1;
                    state_q <= (117'd1 << C_LD_RLW);
                end
                state_q[C_LD_RLW]: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_LD_CLOSE);
                    end else if (stor_eof) state_q <= (117'd1 << C_LD_CLOSE);
                    else begin
                        // FAT lines >128 → ?LS (unlistable / overflow)
                        if (stor_line_len > 8'd128) begin
                            ld_err <= 1'b1; reply_sel <= 4'd10; reply_idx <= 0; state_q <= (117'd1 << C_LD_CLOSE);
                        end else begin
                            dir_n <= stor_line_len; dir_idx <= 0; state_q <= (117'd1 << C_LD_RD);
                        end
                    end
                end
                state_q[C_LD_RD]: begin
                    if (dir_idx >= dir_n) begin
                        // append NL
                        if (src_len < SOURCE_MAX) begin
                            src_req <= 1'b1; src_we <= 1'b1;
                            src_addr <= src_len[16:0];
                            src_wdata <= 8'h0A;
                            state_q <= (117'd1 << C_LD_NLW);
                        end else begin
                            // SOURCE full: preserve the edit prefix; execution uses the full image.
                            state_q <= (117'd1 << C_LD_CLOSE);
                        end
                    end else if (src_len < SOURCE_MAX) begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                        state_q <= (117'd1 << C_LD_RDW);
                    end else begin
                        state_q <= (117'd1 << C_LD_CLOSE);
                    end
                end
                state_q[C_LD_RDW]: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    src_req <= 1'b1; src_we <= 1'b1;
                    src_addr <= src_len[16:0];
                    src_wdata <= mem_rdata;
                    state_q <= (117'd1 << C_LD_WRW);
                end
                state_q[C_LD_WRW]: if (src_gnt) begin
                    src_len <= src_len + 1'b1; src_len_z <= &src_len;
                    dir_idx <= dir_idx + 1'b1;
                    state_q <= (117'd1 << C_LD_RD);
                end
                state_q[C_LD_NLW]: if (src_gnt) begin
                    src_len <= src_len + 1'b1; src_len_z <= &src_len;
                    
                    state_q <= (117'd1 << C_LD_RL);
                end
                // HTML: retain a 64 KiB SOURCE prefix without scanning unused text.
                state_q[C_LD_GB]: if (!stor_busy) begin
                    if (src_len >= SOURCE_MAX) begin
                        // Item H: the file is LARGER than the SOURCE window,
                        // so what sits in the buffer is a prefix. COMPILE
                        // re-reads the card, so editing this buffer and
                        // compiling would silently discard the edit.
                        src_trunc <= 1'b1;
                        state_q <= (117'd1 << C_LD_CLOSE);
                    end else begin
                        stor_get_byte <= 1'b1;
                        state_q <= (117'd1 << C_LD_GBW);
                    end
                end
                state_q[C_LD_GBW]: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_LD_CLOSE);
                    end else if (stor_eof) state_q <= (117'd1 << C_LD_CLOSE);
                    else begin
                        src_req <= 1'b1; src_we <= 1'b1;
                        src_addr <= src_len[16:0];
                        src_wdata <= stor_get_data;

                        state_q <= (117'd1 << C_LD_GB_WR);
                    end
                end
                state_q[C_LD_GB_WR]: if (src_gnt) begin
                    src_len <= src_len + 1'b1; src_len_z <= &src_len;
                    state_q <= (117'd1 << C_LD_GB);
                end
                state_q[C_LD_CLOSE]: if (!stor_busy) begin stor_close <= 1'b1; state_q <= (117'd1 << C_LD_CLOSEW); end
                state_q[C_LD_CLOSEW]: if (stor_done) begin
                    if (ld_err)
                        state_q <= (117'd1 << C_REPLY);
                    else begin

                        if(service_load_pending)launch_loaded_source();
                        else begin reply_sel<=5;reply_idx<=0;state_q <= (117'd1 << C_REPLY);end
                    end
                end
                // Item G: stream the compiler's ASCII diagnostic out of the
                // arena (CSTG_HDR_MSG, cmp_msglen_i bytes) after "?CE".
                // A space is printed first so the line reads "?CE L12 ...".
                state_q[C_CMP_MSG_RD]: begin
                    if (cmp_i >= 21'(cmp_msglen_i)) begin
                        print_nl <= 1'b1;
                        
                        state_q <= (117'd1 << C_WAIT_VIDEO);
                        ret_state <= C_PROMPT;
                    end else if (!cmp_pend) begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_bank <= 1'b1;
                        cmp_rd_addr <= cstg_word(CSTG_HDR_MSG + cmp_i);
                        cmp_pend <= 1'b1;
                    end else if (src_gnt) begin
                        cmp_pend <= 1'b0;
                        cmp_ch   <= src_rdata;
                        cmp_i    <= cmp_i + 21'd1;
                        state_q <= (117'd1 << C_CMP_MSG_PUT);
                    end
                end
                state_q[C_CMP_MSG_PUT]: if (!video_busy) begin
                    // NUL inside the text prints as a space rather than
                    // ending the line: the length is authoritative.
                    put_en   <= 1'b1;
                    put_char <= (cmp_ch == 8'h00) ? 8'h20 : cmp_ch;
                    state_q <= (117'd1 << C_WAIT_VIDEO);
                    ret_state <= C_CMP_MSG_RD;
                end
                state_q[C_SV_OPEN]: if (big_staged && big_trunc) begin
                    // The put overflowed the CART bank — refuse
                    // rather than write a truncated art file.
                    big_staged <= 1'b0;
                    reply_sel <= 5'd15; reply_idx <= 0;   // ?TR
                    state_q <= (117'd1 << C_REPLY);
                end else if (!stor_busy) begin
                    save_failed <= 0;
                    stor_mode <= "O";
                    stor_open <= 1'b1;
                    src_i <= 0;
                    if (big_staged) begin
                        // Pump the staged CART bytes through the
                        // mint's art-append loop (no image bytes first).
                        cmp_save_mode <= 1'b1; cmp_art_mode <= 1'b1;
                        cmp_img_len <= '0; cmp_i <= '0;
                        cmp_art_i <= '0; cmp_art_hi <= 1'b0;
                        cmp_art_len <= big_len;
                        src_bank <= 1'b1;
                    end
                    state_q <= (117'd1 << C_SV_OPENW);
                end
                state_q[C_SV_OPENW]: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY); end
                    else state_q <= (117'd1 << C_SV_RD);
                end
                state_q[C_SV_RD]: begin
                    if (cmp_save_mode) begin
                        // Mint: pump the assembled image out of the arena,
                        // then (art titles) the ARTX payload out of CART.
                        if (cmp_i >= cmp_img_len) begin
                            if (cmp_art_mode && cmp_art_i < cmp_art_len) begin
                                src_req <= 1'b1; src_we <= 1'b0;
                                src_bank <= 1'b1;
                                cmp_rd_addr <= CART_SRAM_BASE
                                             + 22'(cmp_art_i[22:1]);
                                cmp_art_hi  <= cmp_art_i[0];
                                state_q <= (117'd1 << C_SV_RDW);
                            end else state_q <= (117'd1 << C_SV_CLOSE);
                        end else begin
                            src_req <= 1'b1; src_we <= 1'b0;
                            src_bank <= 1'b1;
                            cmp_rd_addr <= cstg_word(cmp_out_off + cmp_i);
                            state_q <= (117'd1 << C_SV_RDW);
                        end
                    end else if (src_i >= src_len) state_q <= (117'd1 << C_SV_CLOSE);
                    else begin
                        src_req <= 1'b1; src_we <= 1'b0;
                        src_addr <= src_i[16:0];
                        state_q <= (117'd1 << C_SV_RDW);
                    end
                end
                state_q[C_SV_RDW]: if (src_gnt) begin
                    // ARTX bytes come packed 2/word out of CART; image bytes
                    // are 1 B/word like every other arena region.
                    if (cmp_art_mode && cmp_i >= cmp_img_len) begin
                        rd_ch <= cmp_art_hi ? src_rdata_hi : src_rdata;
                        cmp_art_i <= cmp_art_i + 22'd1;
                    end else rd_ch <= src_rdata;
                    state_q <= (117'd1 << C_SV_PUT);
                end
                state_q[C_SV_PUT]: if (!stor_busy) begin
                    stor_putc <= 1'b1;
                    stor_putc_data <= rd_ch;
                    state_q <= (117'd1 << C_SV_PUTW);
                end
                state_q[C_SV_PUTW]: if (stor_done) begin
                    if (stor_err) begin save_failed <= 1; reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_SV_CLOSE); end
                    else if (cmp_save_mode) begin cmp_i <= cmp_i + 21'd1; state_q <= (117'd1 << C_SV_RD); end
                    else begin src_i <= src_i + 1'b1; state_q <= (117'd1 << C_SV_RD); end
                end
                state_q[C_SV_CLOSE]: if (!stor_busy) begin stor_close <= 1'b1; state_q <= (117'd1 << C_SV_CLOSEW); end
                state_q[C_SV_CLOSEW]: if (stor_done) begin
                    cmp_save_mode <= 1'b0;
                    big_staged <= 1'b0;
                    raw_save_resume <= 1'b0;
                    reply_idx <= 0;
                    if (save_failed || stor_err) begin
                        reply_sel <= 4'd4; state_q <= (117'd1 << C_REPLY);
                    end else if (raw_save_resume) begin
                        // Caller owns RES32..52 and pending208..239. Only
                        // reload its explicit continuation; no UI policy here.
                        cmp_interactive <= 1; jsb_name_src <= 1;
                        name_i <= 0; dir_n <= 0; jsb_waddr <= 0;
                        jsb_bi <= 0; jsb_word <= 0; ld_err <= 0;
                        jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                        aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                        sram_last <= 0; cmp_wd <= 0; cmp_ph <= 0;
                        cmp_nw <= 0; cmp_nm_len <= 0; cmp_pend <= 0;
                        // Operation-specific completion marker; software clears
                        // it before SAVE and consumes it before pending actions.
                        src_req <= 1; src_we <= 1; src_bank <= 1;
                        cmp_rd_addr <= cstg_word(21'd65); src_wdata <= 8'd1;
                        state_q <= (117'd1 << C_SAVE_COMMIT);
                    end else begin
                        reply_sel <= (cmp_save_mode && !big_staged) ? 5'd13 : 5'd11;
                        state_q <= (117'd1 << C_REPLY);
                    end
                end

                state_q[C_SAVE_COMMIT]: if (src_gnt) begin
                    src_bank <= 0; state_q <= (117'd1 << C_JSB_PREP);
                end

                // ---- REMOVE ---------------------------------------------
                // ---- V1.5 standalone compile ---------------------------
                // One state, phase-stepped, because console encodings are
                // the scarce resource (117 of 128 before this).
                //   0 wait for cdone   1-4 read the published image offset
                //   5 read PROGSEL     6 relaunch / mint / fail
                state_q[C_CMP_WAIT]: begin
                    // Swallow the keystroke that got us here (an ESC which
                    // killed a previous VM must not become a command) — but
                    // ONLY on the first beat. Holding kbd_clear for the whole
                    // wait drained the FIFO continuously, so an INTERACTIVE
                    // chain program could never receive a keypress: the
                    // editor launched by EDIT looked hung.
                    // Typing RUN afterwards started the same loaded program
                    // outside this state, which is why it then worked. The
                    // compiler needs no input; the editor does.
                    kbd_clear <= (cmp_wd == 34'd0);
                    if (handoff_stop_pending && vm_busy_i) begin
                        // halt_pulse crosses to the VM clock; do not race its busy acknowledgement.
                    end else if (cmp_ph == 5'd0) begin
                        if (!cmp_done_i) cdone_seen_low <= 1'b1;
                        if (cmp_done_i && cdone_seen_low) begin
                            if (cmp_status_i == 8'h80 || cmp_status_i == 8'h81) begin
                                halt_pulse <= 1'b1; handoff_stop_pending <= 1'b1;
                            end
                            cmp_img_len <= cmp_len_i;
                            cmp_ph <= 5'd1;
                            cmp_out_off <= 21'd0;
                        end else if (!vm_busy_i && cmp_wd[20]) begin
                            // VM stopped without reporting: fault or ESC.
                            cmp_arm_r <= 1'b0;
                            src_bank <= 1'b0;   // belt: see C_PROMPT
                            reply_sel <= 4'd14; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                        end else begin
                            cmp_wd <= cmp_wd + 1'b1;
                        end
                    end else if (cmp_ph <= 5'd5) begin
                        // Read one arena byte per phase: 4 for the image
                        // offset the compiler published, 1 for PROGSEL.
                        if (!cmp_pend) begin
                            src_req <= 1'b1; src_we <= 1'b0;
                            src_bank <= 1'b1;
                            cmp_rd_addr <= (cmp_ph == 5'd5)
                                ? cstg_word(CSTG_HDR_PSEL)
                                : cstg_word(CSTG_HDR_OUT + 21'(cmp_ph) - 21'd1);
                            cmp_pend <= 1'b1;
                        end else if (src_gnt) begin
                            cmp_pend <= 1'b0;
                            if (cmp_ph == 5'd5) begin
                                // PROGSEL selects one of nine bounded chain rows.
                                jsb_name_src <= 2'd1;
                                cmp_progsel <= (src_rdata <= 8'd8) ? src_rdata[3:0] : 4'd15;
                                cmp_ph <= 5'd6;
                            end else begin
                                case (cmp_ph)
                                    5'd1: cmp_out_off[7:0]   <= src_rdata;
                                    5'd2: cmp_out_off[15:8]  <= src_rdata;
                                    default: cmp_out_off[20:16] <= src_rdata[4:0];
                                endcase
                                cmp_ph <= cmp_ph + 5'd1;
                            end
                        end
                    end else if (cmp_ph == 5'd6 &&
                                 (cmp_status_i == 8'h81 || cmp_status_i == 8'h82 ||
                                  cmp_status_i == 8'h83 || cmp_status_i == 8'h84)) begin
                        // Item C: these ops name a FILE, so pull the 16-byte
                        // arena filename into NAME_BUF before dispatching.
                        // 0x00 / 0x80 skip this entirely and behave exactly as
                        // before — the two paths already proven in FPGA-SIM.
                        name_i <= 0; cmp_nm_len <= 8'd0;
                        // 0x81 (SAVE) uses the loaded title's name; the
                        // others name their target in the arena header.
                        cmp_use_srcname <= (cmp_status_i == 8'h81);
                        cmp_ph <= 5'd7;
                    end else if (cmp_ph >= 5'd7 && cmp_ph <= 5'd22) begin
                        // One filename byte per phase: SRAM read, then the
                        // NAME_BUF write (which needs its own mem_gnt).
                        if (cmp_use_srcname) begin
                            // NEW 2: 0x81 saves under the name the console
                            // already has. The editor cannot know it — only
                            // the console does — so the bytes come from
                            // src_name, not the arena. Same phases, no SRAM.
                            if (!cmp_nw) begin
                                mem_en <= 1'b1; mem_we <= 1'b1;
                                mem_addr  <= NAME_BUF + 16'(cmp_ph) - 16'd7;
                                mem_wdata <= (16'(cmp_ph) - 16'd7
                                              < 16'(src_name_len))
                                             ? src_name[4'(cmp_ph - 5'd7)]
                                             : 8'h20;
                                cmp_nw <= 1'b1;
                            end else if (mem_gnt) begin
                                cmp_nw <= 1'b0;
                                cmp_nm_len <= {3'd0, src_name_len};
                                cmp_ph <= cmp_ph + 5'd1;
                            end
                        end else if (!cmp_pend && !cmp_nw) begin
                            src_req <= 1'b1; src_we <= 1'b0;
                            src_bank <= 1'b1;
                            cmp_rd_addr <=
                                cstg_word(CSTG_HDR_NM + 21'(cmp_ph) - 21'd7);
                            cmp_pend <= 1'b1;
                        end else if (cmp_pend && src_gnt) begin
                            cmp_pend <= 1'b0;
                            cmp_nw   <= 1'b1;
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr  <= NAME_BUF + 16'(cmp_ph) - 16'd7;
                            mem_wdata <= src_rdata;
                            // NUL or space ends the name; everything before
                            // the first terminator counts.
                            if (src_rdata != 8'h00 && src_rdata != 8'h20 &&
                                cmp_nm_len == (8'(cmp_ph) - 8'd7))
                                cmp_nm_len <= 8'(cmp_ph) - 8'd6;
                        end else if (cmp_nw && mem_gnt) begin
                            cmp_nw <= 1'b0;
                            cmp_ph <= cmp_ph + 5'd1;
                        end
                    end else begin
                        src_bank <= 1'b0;
                        if ((cmp_status_i == 8'h81 || cmp_status_i == 8'h80) && cmp_progsel > 8) begin
                            cmp_arm_r <= 0; halt_pulse <= 1; raw_save_resume <= 0;
                            reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                        end else if (cmp_status_i == 8'h81) begin
                            // SAVE: SOURCE -> current file, then explicit caller.
                            raw_save_resume <= 1;
                            cmp_arm_r <= 1'b0;
                            halt_pulse <= 1'b1;      // leave game view
                            cmp_interactive <= 1'b0;
                            cmp_save_mode <= 1'b0; // plain source, not an image
                            stor_name_len <= cmp_nm_len;
                            src_i <= 0; src_bank <= 1'b0;
                            state_q <= (117'd1 << C_SV_OPEN);
                        end else if (cmp_status_i == 8'h82) begin
                            // DELETE the arena-named file.
                            cmp_arm_r <= 1'b0;
                            stor_name_len <= cmp_nm_len;
                            state_q <= (117'd1 << C_RM);
                        end else if (cmp_status_i == 8'h83) begin
                            // LOAD the arena-named file into SOURCE.
                            cmp_arm_r <= 1'b0;
                            stor_name_len <= cmp_nm_len;
                            src_len <= 0; src_len_z <= 1'b1; src_i <= 0; src_bank <= 1'b0;
                            state_q <= (117'd1 << C_LD_OPEN);
                        end else if (cmp_status_i == 8'h84) begin
                            // Mint the staged image under the arena name.
                            cmp_arm_r <= 1'b0;
                            cmp_save_mode <= 1'b1;
                            jsb_name_src <= 2'd2;   // name already in NAME_BUF
                            jsb_name_len <= cmp_nm_len;
                            stor_name_len <= cmp_nm_len;
                            jsb_want_jsh <= 1'b1;
                            cmp_i <= 21'd0;
                            name_i <= 0; dir_n <= 0;
                            state_q <= (117'd1 << C_SV_OPEN);
                        end else if (cmp_status_i == 8'h80) begin
                            // NEXT: load the program PROGSEL named and rerun.
                            name_i <= 0; dir_n <= 0; jsb_waddr <= 0;
                            jsb_bi <= 0; jsb_word <= 0; ld_err <= 0;
                            jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                            aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                            sram_last <= 0; cmp_wd <= '0; cmp_ph <= 5'd0; cmp_nw <= 1'b0; cmp_nm_len <= 8'd0;
                            state_q <= (117'd1 << C_JSB_PREP);
                        end else if (cmp_status_i == 8'd0 &&
                                     cmp_len_i == 21'd0) begin
                            // NEW 2: the editor quitting without saving —
                            // there is no staged image to mint, so just
                            // acknowledge and return to READY. (The compiler
                            // always reports a non-zero image length here.)
                            cmp_arm_r <= 1'b0;
                            src_bank <= 1'b0;   // belt: see C_PROMPT
                            // interactive quit: leave game view or the
                            // console prints READY behind the frozen frame
                            halt_pulse <= 1'b1;
                            cmp_interactive <= 1'b0;
                            reply_sel <= 4'd2; reply_idx <= 0; // OK
                            state_q <= (117'd1 << C_REPLY);
                        end else if (cmp_status_i == 8'h85) begin
                            // Mint NAME.JSH, then append cmp_art_len bytes
                            // from CART. cmp_len_i is the image length;
                            // cmp_art_len is the length of the last big put
                            // that SAVE wrote (0 if none since reset).
                            cmp_arm_r <= 1'b0;
                            cmp_save_mode <= 1'b1;
                            cmp_art_mode <= 1'b1;
                            cmp_art_i <= '0; cmp_art_hi <= 1'b0;
                            jsb_name_src <= 2'd0;
                            jsb_want_jsh <= 1'b1;
                            cmp_i <= 21'd0;
                            name_i <= 0; dir_n <= 0;
                            state_q <= (117'd1 << C_JSB_PREP);
                        end else if (cmp_status_i == 8'd0) begin
                            // DONE: mint NAME.JSH from the staged image.
                            cmp_arm_r <= 1'b0;
                            cmp_save_mode <= 1'b1;
                            jsb_name_src <= 2'd0;
                            jsb_want_jsh <= 1'b1;
                            cmp_i <= 21'd0;
                            name_i <= 0; dir_n <= 0;
                            state_q <= (117'd1 << C_JSB_PREP);
                        end else begin
                            cmp_arm_r <= 1'b0;
                            reply_sel <= 4'd14; reply_idx <= 0;  // ?CE
                            state_q <= (117'd1 << C_REPLY);
                        end
                    end
                end
                state_q[C_RM]: if (!stor_busy) begin stor_delete <= 1'b1; state_q <= (117'd1 << C_RMW); end
                state_q[C_RMW]: if (stor_done) begin
                    if (stor_err) reply_sel <= 4'd4; else reply_sel <= 4'd2;
                    reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                end

                // ---- CLS ------------------------------------------------
                state_q[C_JSB_PREP]:if(jsb_name_src==1 && cmp_progsel==8 && sys_attempted && (rom_status!=1 || sys_status!=1))begin
                    // ?TB: TOOLBOX.ROM missing or bad. The bit holds no Toolbox
                    // copy, so Finder cannot start without the card's ROM.
                    ld_err<=1;reply_sel<=(rom_status!=1)?5'd17:5'd9;reply_idx<=0;state_q <= (117'd1 << C_REPLY);
                end else begin
                    cdone_seen_low <= 1'b0;   // re-arm the cdone edge gate
                    if (jsb_name_src != 2'd0) begin
                        // A chain program, loaded by identity not by title.
                        if ({1'b0, name_i} >= cmp_name_len(cmp_progsel)) begin
                            stor_name_len <= cmp_name_len(cmp_progsel);
                            state_q <= (117'd1 << C_JSB_OPEN);
                        end else begin
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= cmp_name_char(cmp_progsel, name_i);
                            state_q <= (117'd1 << C_JSB_NWR_W);
                        end
                    end else if (dir_n == 8'd0) begin
                        if (name_i >= src_name_len) begin
                            // end of name with no '.' — append .JSB here
                            jsb_name_len <= {3'b0, name_i} + 8'd4;
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= ".";
                            dir_n <= 8'd1;
                            state_q <= (117'd1 << C_JSB_NWR_W);
                        end else if (src_name[name_i[3:0]] == ".") begin
                            jsb_name_len <= {3'b0, name_i} + 8'd4;
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= ".";
                            dir_n <= 8'd1;
                            state_q <= (117'd1 << C_JSB_NWR_W);
                        end else begin
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= NAME_BUF + {9'h0, name_i};
                            mem_wdata <= src_name[name_i[3:0]];
                            state_q <= (117'd1 << C_JSB_NWR_W);
                        end
                    end else if (dir_n == 8'd1) begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd1;
                        mem_wdata <= "J";
                        dir_n <= 8'd2;
                        state_q <= (117'd1 << C_JSB_NWR_W);
                    end else if (dir_n == 8'd2) begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd2;
                        mem_wdata <= "S";
                        dir_n <= 8'd3;
                        state_q <= (117'd1 << C_JSB_NWR_W);
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= NAME_BUF + {9'h0, name_i} + 16'd3;
                        mem_wdata <= jsb_want_jsh ? "H" : "B";
                        dir_n <= 8'd4;
                        state_q <= (117'd1 << C_JSB_NWR_W);
                    end
                end
                state_q[C_JSB_NWR_W]: if (mem_gnt) begin
                    if (dir_n == 8'd0) begin
                        name_i <= name_i + 1'b1;
                        state_q <= (117'd1 << C_JSB_PREP);
                    end else if (dir_n == 8'd4) begin
                        stor_name_len <= jsb_name_len;
                        // The mint reuses this name builder, then goes to the
                        // byte-transparent SAVE pump instead of the loader;
                        // everything else is a normal chain-load.
                        state_q <= cmp_save_mode ? (117'd1 << C_SV_OPEN) : (117'd1 << C_JSB_OPEN);
                    end else
                        state_q <= (117'd1 << C_JSB_PREP);
                end
                state_q[C_JSB_OPEN]: if (!stor_busy) begin
                    finder_cache_replay<=0;cache_tail<=0;
                    finder_cache_fill<=jsb_name_src==1 && cmp_progsel==8;
                    if(jsb_name_src==1 && cmp_progsel==8)finder_cache_valid<=0;
                    stor_mode <= "I";
                    stor_open <= 1'b1;
                    jsb_waddr <= 0;
                    jsb_bi <= 0;
                    jsb_word <= 0;
                    ld_err <= 0;
                    // Fresh ASET splitter per load
                    jsb_boff <= 0; jsb_aset_off <= 0; jsb_has_aset <= 0;
                    aset_seen <= 0; aset_len <= 0; aset_pay <= 0;
                    sram_last <= 0; pal_idx <= 0; pal_ph <= 0;
                    state_q <= (117'd1 << C_JSB_OPENW);
                end
                state_q[C_JSB_OPENW]: if (stor_done) begin
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
                            state_q <= (117'd1 << C_JSB_TETHER);
                        end else begin
                            // tether-fed retry missing too → ?NH; .JS → ?NB
                            reply_sel <= jsb_want_jsh ? 4'd9 : 4'd7;
                            reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                        end
                    end else state_q <= (117'd1 << C_JSB_GB);
                end
                state_q[C_JSB_GB]: if(finder_cache_replay)begin
                    if(jsb_boff>=finder_cache_length)state_q <= (117'd1 << C_JSB_TEOF);
                    else if(jsb_boff[0])begin jsb_din<=cache_word[15:8];state_q <= (117'd1 << C_JSB_FEED);end
                    else begin
                        sram_req<=1;sram_we<=0;sram_addr<=jmr_js_vm_pkg::SYSTEM_CACHE_BASE+22'(jsb_boff>>1);state_q <= (117'd1 << C_CACHE_READ);
                    end
                end else if (!stor_busy) begin
                    stor_get_byte <= 1'b1;
                    state_q <= (117'd1 << C_JSB_GBW);
                end
                state_q[C_JSB_GBW]: if (stor_done) begin
                    if (stor_err) begin
                        ld_err <= 1'b1; reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_JSB_CLOSE);
                    end else if (stor_eof) begin
                        state_q <= (117'd1 << C_JSB_TEOF);
                    end else begin
                        jsb_din <= stor_get_data;
                        state_q <= (117'd1 << C_JSB_FEED);
                        if(finder_cache_fill)begin
                            if(jsb_boff>=jmr_js_vm_pkg::FINDER_CACHE_BYTES)finder_cache_fill<=0;
                            else if(!jsb_boff[0])cache_low<=stor_get_data;
                            else begin
                                sram_req<=1;sram_we<=1;sram_addr<=jmr_js_vm_pkg::SYSTEM_CACHE_BASE+22'(jsb_boff>>1);
                                sram_wdata<={stor_get_data,cache_low};state_q <= (117'd1 << C_CACHE_WRITE);
                            end
                        end
                    end
                end
                // CRC-validated SOURCE staging for named COMMIT.
                state_q[C_SRC_TETHER]: begin
                    if (jsb_tether_eof) begin
                        teth_wd <= 30'd0;
                        if (jsb_tether_crc_err) begin
                            // Trailer CRC mismatch — the bytes in
                            // SOURCE are not the host's file. Drop them
                            // and say so; the host retries.
                            src_len <= 0; src_len_z <= 1'b1; src_trunc <= 1'b0;
                            reply_sel <= 5'd16; reply_idx <= 0;
                            state_q <= (117'd1 << C_REPLY);
                        end else
                            state_q <= (117'd1 << C_IDLE);
                    end else if (jsb_tether_stb) begin
                        teth_wd <= 30'd0;
                        if (src_len >= SOURCE_MAX) begin
                            src_trunc <= 1'b1;
                            // drain leftover bytes so the UART does not stall
                        end else begin
                            src_req <= 1'b1; src_we <= 1'b1;
                            src_addr <= src_len[16:0];
                            src_wdata <= jsb_tether_data;
                            state_q <= (117'd1 << C_SRC_WR);
                        end
                    end else if ((!kbd_empty && kbd_data == 8'h1B)
                                 || teth_wd[30]) begin
                        if (!kbd_empty && kbd_data == 8'h1B) kbd_pop <= 1'b1;
                        teth_wd <= 30'd0;
                        state_q <= (117'd1 << C_IDLE);
                    end else teth_wd <= teth_wd + 30'd1;
                end
                state_q[C_SRC_WR]: if (src_gnt) begin
                    src_len <= src_len + 1'b1; src_len_z <= &src_len;
                    state_q <= (117'd1 << C_SRC_TETHER);
                end
                // Big put: same stream contract as C_SRC_TETHER
                // (stb/eof/crc_err/ESC/10.7 s silence), bytes packed two
                // per CART word. The odd tail byte is flushed at eof.
                state_q[C_BIG_TETHER]: begin
                    if (jsb_tether_eof) begin
                        teth_wd <= 30'd0;
                        if (jsb_tether_crc_err) begin
                            big_len <= '0; big_staged <= 1'b0; big_hi <= 1'b0;
                            src_bank <= 1'b0;
                            reply_sel <= 5'd16; reply_idx <= 0;   // ?CK
                            state_q <= (117'd1 << C_REPLY);
                        end else begin
                            big_staged <= 1'b1;
                            if (big_hi) begin
                                src_req <= 1'b1; src_we <= 1'b1;
                                src_bank <= 1'b1;
                                cmp_rd_addr <= CART_SRAM_BASE + 22'(big_len[22:1]);
                                src_wdata <= 8'd0; src_wlo <= big_lo; src_w16 <= 1'b1;
                                big_hi <= 1'b0; big_eof <= 1'b1;
                                state_q <= (117'd1 << C_BIG_WR);
                            end else begin
                                src_bank <= 1'b0;
                                state_q <= (117'd1 << C_IDLE);
                            end
                        end
                    end else if (jsb_tether_stb) begin
                        teth_wd <= 30'd0;
                        if (big_len >= BIG_MAX_BYTES) begin
                            big_trunc <= 1'b1;      // drain, never wedge
                        end else if (!big_hi) begin
                            big_lo <= jsb_tether_data;
                            big_hi <= 1'b1;
                            big_len <= big_len + 22'd1;
                        end else begin
                            src_req <= 1'b1; src_we <= 1'b1;
                            src_bank <= 1'b1;
                            cmp_rd_addr <= CART_SRAM_BASE + 22'(big_len[22:1]);
                            src_wdata <= jsb_tether_data;   // high half
                            src_wlo <= big_lo; src_w16 <= 1'b1;
                            big_hi <= 1'b0;
                            big_len <= big_len + 22'd1;
                            state_q <= (117'd1 << C_BIG_WR);
                        end
                    end else if ((!kbd_empty && kbd_data == 8'h1B)
                                 || teth_wd[30]) begin
                        if (!kbd_empty && kbd_data == 8'h1B) kbd_pop <= 1'b1;
                        teth_wd <= 30'd0;
                        big_staged <= 1'b0; big_hi <= 1'b0;
                        src_bank <= 1'b0;
                        state_q <= (117'd1 << C_IDLE);
                    end else teth_wd <= teth_wd + 30'd1;
                end
                state_q[C_BIG_WR]: if (src_gnt) begin
                    src_w16 <= 1'b0;
                    if (big_eof) begin
                        big_eof <= 1'b0;
                        src_bank <= 1'b0;
                        state_q <= (117'd1 << C_IDLE);
                    end else state_q <= (117'd1 << C_BIG_TETHER);
                end
                // HTML RUN — PROG/host byte stream (same splitter as FAT GBW)
                state_q[C_JSB_DRAIN]:begin
                    // Finish the CRC-framed packet even when an early asset
                    // header is bad. Otherwise the transport waits forever
                    // for a consumer that already left the image state.
                    if(jsb_tether_eof)state_q <= (117'd1 << C_JSB_TEOF);
                    else if(jsb_tether_stb)teth_wd<=0;
                    else if(teth_wd[30] || (!kbd_empty && kbd_data==27))begin
                        tether_abort<=1;ld_err<=1;image_code_valid<=0;
                        reply_sel<=9;reply_idx<=0;state_q <= (117'd1 << C_REPLY);
                    end else teth_wd<=teth_wd+1'b1;
                end
                state_q[C_JSB_TETHER]: begin
                    if (jsb_tether_eof)
                        state_q <= (117'd1 << C_JSB_TEOF);
                    else if (jsb_tether_stb) begin
                        teth_wd <= 30'd0;
                        jsb_din <= jsb_tether_data;
                        state_q <= (117'd1 << C_JSB_FEED);
                    end else if ((!kbd_empty && kbd_data == 8'h1B)
                                 || teth_wd[30]) begin
                        // ESC (head of the kbd FIFO) or ~10.7s of host
                        // silence: fail loud (?NB), never a dead console
                        // (a PS/2 RUN cannot trigger the host compile -
                        // the protocol has no board request)
                        if (!kbd_empty && kbd_data == 8'h1B) kbd_pop <= 1'b1;
                        teth_wd <= 30'd0;
                        ld_err <= 1'b1;
                        reply_sel <= 4'd7; reply_idx <= 0;
                        state_q <= (117'd1 << C_REPLY);
                    end else teth_wd <= teth_wd + 30'd1;
                end
                state_q[C_SYS]:case(sys_phase)
                    0:begin
                        mem_en<=1;mem_we<=1;mem_addr<=NAME_BUF+16'(sys_i);
                        if(sys_rom)case(sys_i)0:mem_wdata<="T";1:mem_wdata<="O";2:mem_wdata<="O";3:mem_wdata<="L";4:mem_wdata<="B";5:mem_wdata<="O";6:mem_wdata<="X";7:mem_wdata<=".";8:mem_wdata<="R";9:mem_wdata<="O";default:mem_wdata<="M";endcase
                        else case(sys_i)0:mem_wdata<="S";1:mem_wdata<="Y";2:mem_wdata<="S";3:mem_wdata<="T";4:mem_wdata<="E";5:mem_wdata<="M";6:mem_wdata<=".";7:mem_wdata<="S";8:mem_wdata<="Y";default:mem_wdata<="S";endcase
                        sys_phase<=1;
                    end
                    1:if(mem_gnt)begin
                        if(sys_i==(sys_rom?10:9))begin stor_name_len<=sys_rom?11:10;sys_phase<=2;end
                        else begin sys_i<=sys_i+1'b1;sys_phase<=0;end
                    end
                    2:if(!stor_busy)begin stor_mode<="I";stor_open<=1;sys_phase<=3;end
                    3:if(stor_done)begin
                        if(stor_err)finish_system_file(2);
                        else begin sys_i<=0;sys_good<=1;sys_crc<=32'hffffffff;sys_expected<=0;sys_phase<=4;end
                    end
                    4:if(!stor_busy)begin stor_get_byte<=1;sys_phase<=5;end
                    5:if(stor_done)begin
                        if(stor_err || stor_eof)begin
                            sys_good<=!stor_err && sys_good && sys_at_end_q && (~sys_crc)==sys_expected;
                            sys_phase<=8;
                        end else if(sys_past_end_q)begin sys_good<=0;sys_phase<=8;end
                        else begin
                            sys_i<=sys_i+1'b1;sys_phase<=4;
                            if(sys_i<12)begin if(stor_get_data!=sys_header(sys_i[3:0]))begin sys_good<=0;sys_phase<=8;end end
                            else if(sys_i<16)sys_expected[sys_i[1:0]*8+:8]<=stor_get_data;
                            else begin
                                sys_crc<=sys_crc_byte(sys_crc,stor_get_data);
                                // Final virtual instruction is immutable JUMP 8192 padding.
                                if(sys_pad_q && stor_get_data!=(sys_i[1:0]==0?8'h0b:sys_i[1:0]==2?8'h20:8'h00))sys_good<=0;
                                if(!sys_i[0])sys_low<=stor_get_data;
                                else begin
                                    sram_req<=1;sram_we<=1;sram_addr<=resource_stage_base+22'((sys_i-16)>>1);
                                    sram_wdata<={stor_get_data,sys_low};sys_phase<=6;
                                end
                            end
                        end
                    end
                    6:if(sram_ack)begin sram_req<=0;sram_we<=0;sys_phase<=7;end
                    7:sys_phase<=4;
                    8:if(!stor_busy)begin stor_close<=1;sys_phase<=9;end
                    9:if(stor_done)begin
                        if(!sys_good || stor_err)finish_system_file(3);
                        else begin sys_i<=0;sys_phase<=10;end
                    end
                    10:if(sys_rom || sys_ready)begin sram_req<=1;sram_we<=0;sram_addr<=resource_stage_base+22'(sys_i);sys_phase<=11;end
                    11:if(sram_ack)begin
                        sram_req<=0;sys_phase<=12;
                        if(sys_rom)begin
                            if(!sys_i[0])rom_low<=sram_rdata;
                            else begin toolbox_code_we<=1;toolbox_code_addr<=sys_i[13:1];toolbox_code_data<={sram_rdata,rom_low};end
                        end else begin sys_we<=1;sys_addr<=sys_i[13:0];sys_data<=sram_rdata;end
                    end
                    12:if(sys_rom || !sys_ready)sys_phase<=13;
                    13:if(sys_rom || sys_ready)begin
                        if(sys_last_word_q)finish_system_file(1);
                        else begin sys_i<=sys_i+1'b1;sys_phase<=10;end
                    end
                    default:finish_system_file(3);
                endcase
                state_q[C_RESIDENT]:case(resident_phase)
                    0:begin
                        sram_req<=1;sram_we<=0;
                        sram_addr<=resident_restore?(jmr_js_vm_pkg::FINDER_STATE_BASE+22'(resident_i>>1)):(CSCR_SRAM_BASE+22'(resident_i));
                        resident_phase<=1;
                    end
                    1:if(sram_ack)begin
                        sram_req<=0;
                        if(resident_restore)resident_word<=sram_rdata;
                        else if(resident_i[0])resident_word[15:8]<=sram_rdata[7:0];
                        else resident_word[7:0]<=sram_rdata[7:0];
                        resident_phase<=2;
                    end
                    2:if(!resident_restore && !resident_i[0])begin resident_i<=resident_i+1'b1;resident_phase<=0;end
                      else resident_phase<=3;
                    3:begin
                        sram_req<=1;sram_we<=1;
                        sram_addr<=resident_restore?(CSCR_SRAM_BASE+22'(resident_i)):(jmr_js_vm_pkg::FINDER_STATE_BASE+22'(resident_i>>1));
                        // Force a content redraw on return, preserving windows,
                        // directory state. Icon pixels extend beyond the parked half;
                        // invalidate flags so MacPaint scratch cannot become icon runs.
                        // Also discard the launch gesture, as the Python backend does.
                        sram_wdata<=resident_init?16'd0:resident_restore?{8'd0,
                            ((resident_i>=48000 && resident_i<48256) || resident_i==16392 || resident_i==16395)?8'd0:
                            resident_i==16385?8'd1:resident_i[0]?resident_word[15:8]:resident_word[7:0]}:resident_word;
                        resident_phase<=4;
                    end
                    4:if(sram_ack)begin sram_req<=0;sram_we<=0;resident_phase<=5;end
                    5:begin
                        resident_i<=resident_i+1'b1;
                        if(resident_init || resident_cancelled || forget_finder || resident_i==CSCR_WORDS-1)begin
                            if(resident_cancelled || forget_finder)begin finder_state_valid<=0;park_pending<=0;state_q <= (117'd1 << C_PROMPT);end
                            else if(resident_restore)begin vm_start<=1;cmp_ph<=0;cmp_wd<=0;state_q <= (117'd1 << C_CMP_WAIT);end
                            else begin finder_state_valid<=1;park_pending<=0;state_q <= (117'd1 << C_PROMPT);end
                        end else resident_phase<=(resident_restore && !resident_i[0])?3:0;
                    end
                    default:resident_phase<=0;
                endcase
                state_q[C_CACHE_WRITE]:if(sram_ack)begin
                    sram_req<=0;sram_we<=0;state_q <= (117'd1 << C_CACHE_GAP);
                end
                state_q[C_CACHE_READ]:if(sram_ack)begin
                    sram_req<=0;cache_word<=sram_rdata;jsb_din<=sram_rdata[7:0];state_q <= (117'd1 << C_CACHE_GAP);
                end
                state_q[C_CACHE_GAP]:state_q <= cache_tail?(117'd1 << C_JSB_TEOF):(117'd1 << C_JSB_FEED);
                state_q[C_JSB_TEOF]: if(finder_cache_fill && jsb_boff[0] && !cache_tail)begin
                    sram_req<=1;sram_we<=1;sram_addr<=jmr_js_vm_pkg::SYSTEM_CACHE_BASE+22'(jsb_boff>>1);
                    sram_wdata<={8'd0,cache_low};cache_tail<=1;state_q <= (117'd1 << C_CACHE_WRITE);
                end else begin
                    if (jsb_bi != 2'd0) begin
                        code_we <= 1'b1;
                        code_waddr <= jsb_waddr;
                        code_wdata <= jsb_word;
                    end
                    image_code_bytes <= jsb_has_aset ? {9'd0,jsb_aset_off} : {9'd0,jsb_boff};
                    image_code_valid <= !ld_err && boff_ge16_q &&
                                        !(host_active && ho_5 && host_arg!=32'(jsb_boff)) &&
                                        !(jsb_tether_mode && jsb_tether_crc_err) &&
                                        (!jsb_has_aset || (aset_seen && aset_pay >= aset_len));
                    // A corrupted program stream never runs — ?CK.
                    if(!boff_ge16_q || (host_active && ho_5 && host_arg!=32'(jsb_boff)))begin
                        ld_err<=1;reply_sel<=7;reply_idx<=0;state_q <= (117'd1 << C_JSB_CLOSE);
                    end else if (jsb_tether_mode && jsb_tether_crc_err) begin
                        ld_err <= 1'b1; reply_sel <= 5'd16; reply_idx <= 0;
                        state_q <= (117'd1 << C_JSB_CLOSE);
                    end else
                    // NEW fail loud: header promised an ASET section but the
                    // stream ended early → ?NH, never silent blank sprites
                    if (jsb_has_aset && (!aset_seen || aset_pay < aset_len)) begin
                        ld_err <= 1'b1; reply_sel <= 4'd9; reply_idx <= 0;
                        state_q <= (117'd1 << C_JSB_CLOSE);
                    end else if (aset_seen && aset_pay[0]) begin
                        sram_req <= 1'b1; sram_we <= 1'b1;
                        sram_addr <= aset_pay[22:1];
                        sram_wdata <= {8'h00, sram_lo};
                        sram_last <= 1'b1;
                        state_q <= (117'd1 << C_JSB_SRAMW);
                    end else
                        state_q <= (117'd1 << C_JSB_CLOSE);
                end
                state_q[C_JSB_FEED]: begin
                    if(feed_big_q)begin
                        ld_err<=1;reply_sel<=4'd9;reply_idx<=0;state_q <= jsb_tether_mode?(117'd1 << C_JSB_DRAIN):(117'd1 << C_JSB_CLOSE);
                    end else if (feed_aset_q) begin
                        // ---- ASET section: "ASET" + u32 len, then payload → SRAM
                        jsb_boff <= jsb_boff + 23'd1;
                        state_q <= jsb_tether_mode ? (117'd1 << C_JSB_TETHER) : (117'd1 << C_JSB_GB);
                        if (rel_lt4_q) begin
                            if ((rel_lo_q == 2'd0 && jsb_din != "A") ||
                                (rel_lo_q == 2'd1 && jsb_din != "S") ||
                                (rel_lo_q == 2'd2 && jsb_din != "E") ||
                                (rel_lo_q == 2'd3 && jsb_din != "T")) begin
                                ld_err <= 1'b1; reply_sel <= 4'd9; reply_idx <= 0;
                                state_q <= jsb_tether_mode ? (117'd1 << C_JSB_DRAIN) : (117'd1 << C_JSB_CLOSE);
                            end
                        end else if (rel_lt8_q) begin
                            unique case (rel_lo_q)
                                2'd0: aset_len[7:0]   <= jsb_din;
                                2'd1: aset_len[15:8]  <= jsb_din;
                                2'd2: aset_len[22:16] <= jsb_din[6:0];
                                default: aset_seen <= 1'b1;
                            endcase
                        end else begin
                            if (pay_lt768_q) begin
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
                                sram_addr <= aset_pay[22:1];
                                sram_wdata <= {jsb_din, sram_lo};
                                state_q <= (117'd1 << C_JSB_SRAMW);
                            end
                        end
                    end else begin
                        jsb_boff <= jsb_boff + 23'd1;
                        if (boff_eq10_q) jsb_has_aset <= jsb_din[1];
                        if (jsb_has_aset) begin
                            if (boff_eq12_q) jsb_aset_off[7:0]   <= jsb_din;
                            if (boff_eq13_q) jsb_aset_off[15:8]  <= jsb_din;
                            if (boff_eq14_q) jsb_aset_off[22:16] <= jsb_din[6:0];
                        end
                        case (jsb_bi)
                            2'd0: jsb_word <= {24'h0, jsb_din};
                            2'd1: jsb_word <= {16'h0, jsb_din, jsb_word[7:0]};
                            2'd2: jsb_word <= {8'h0, jsb_din, jsb_word[15:0]};
                            default: begin
                                code_we <= 1'b1;
                                code_waddr <= jsb_waddr;
                                code_wdata <= {jsb_din, jsb_word[23:0]};
                                jsb_waddr <= jsb_waddr + 16'd1;
                            end
                        endcase
                        if (jsb_bi == 2'd3 && waddr_full_q)
                            state_q <= jsb_tether_mode ? (117'd1 << C_JSB_TETHER) : (117'd1 << C_JSB_PEEK);
                        else begin
                            jsb_bi <= jsb_bi + 2'd1;
                            state_q <= jsb_tether_mode ? (117'd1 << C_JSB_TETHER) : (117'd1 << C_JSB_GB);
                        end
                    end
                end
                // Hold the SRAM write until the port acks, then stream on
                state_q[C_JSB_SRAMW]: if (sram_ack) begin
                    sram_req <= 1'b0; sram_we <= 1'b0;
                    state_q <= sram_last ? (117'd1 << C_JSB_CLOSE)
                           : (jsb_tether_mode ? (117'd1 << C_JSB_TETHER) : (117'd1 << C_JSB_GB));
                end
                state_q[C_JSB_CLOSE]: if(finder_cache_replay)begin
                    finder_cache_replay<=0;
                    if(ld_err)begin finder_cache_valid<=0;state_q <= (117'd1 << C_REPLY);end
                    else if(finder_state_valid)begin
                        resident_restore<=1;resident_init<=0;resident_phase<=0;resident_i<=0;state_q <= (117'd1 << C_RESIDENT);
                    end else begin resident_restore<=1;resident_init<=1;resident_phase<=3;resident_i<=16384;state_q <= (117'd1 << C_RESIDENT);end
                end else if (jsb_tether_mode) begin
                    // no FAT handle — PROG stream already ended
                    if (ld_err)
                        state_q <= (117'd1 << C_REPLY);
                    else begin
                        vm_start <= 1'b1;
                        reply_sel <= 4'd2; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                    end
                end else if (!stor_busy) begin stor_close <= 1'b1; state_q <= (117'd1 << C_JSB_CLOSEW); end
                state_q[C_JSB_CLOSEW]: if (stor_done) begin
                    if(finder_cache_fill && !ld_err && !stor_err && jsb_boff!=0 && jsb_boff<=jmr_js_vm_pkg::FINDER_CACHE_BYTES)begin
                        finder_cache_valid<=1;finder_cache_length<=jsb_boff[17:0];
                    end
                    finder_cache_fill<=0;
                    if (ld_err || stor_err)
                        state_q <= (117'd1 << C_REPLY);
                    else if (jsb_name_src != 2'd0) begin
                        // Finder initializes its scratch marker before entering the VM.
                        vm_start <= cmp_progsel!=8;
                        cmp_ph <= 5'd0; cmp_nw <= 1'b0; cmp_nm_len <= 8'd0; cmp_pend <= 1'b0; cmp_wd <= '0;
                        if(cmp_progsel==8)begin resident_restore<=1;resident_init<=1;resident_phase<=3;resident_i<=16384;state_q <= (117'd1 << C_RESIDENT);end
                        else state_q <= (117'd1 << C_CMP_WAIT);
                    end else begin
                        vm_start <= 1'b1;
                        reply_sel <= 4'd2; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                    end
                end
                // Code BRAM full after word 7FFF — more code bytes → ?NB, never truncated RUN
                state_q[C_JSB_PEEK]: if (!stor_busy) begin
                    stor_get_byte <= 1'b1;
                    state_q <= (117'd1 << C_JSB_PEEKW);
                end
                state_q[C_JSB_PEEKW]: if (stor_done) begin
                    if (stor_err || stor_eof)
                        state_q <= (117'd1 << C_JSB_CLOSE);
                    else if (jsb_has_aset && jsb_aset_off != 23'd0
                             && (jsb_boff + 23'd1) >= jsb_aset_off)
                        state_q <= (117'd1 << C_JSB_CLOSE); // ASET follows — code fit
                    else begin
                        ld_err <= 1'b1; reply_sel <= 4'd7; reply_idx <= 0;
                        state_q <= (117'd1 << C_JSB_CLOSE);
                    end
                end

                default: state_q <= (117'd1 << C_IDLE);
            endcase

            // DIR handshake silence counter: counts only while waiting in the
            // DIR wait states with storage idle and no done this cycle.
            if ((state_q[C_DIR0W] || state_q[C_DIRNW]) && !stor_busy && !stor_done) begin
                if (!(&dir_hs_wd)) dir_hs_wd <= dir_hs_wd + 22'd1;
            end
            if (state_q[C_DIR_CH] && !mem_gnt) begin
                if (!(&dir_hs_wd)) dir_hs_wd <= dir_hs_wd + 22'd1;
            end
            // single-cycle qualifier: self-clearing so one timeout = one retry
            dir_hs_hit <= (&dir_hs_wd) && !dir_hs_hit;
            // Console-side storage watchdog (after the case, so it wins the
            // beat). Armed by any stor strobe (read one cycle late - the
            // strobes are 1-cycle registers), cleared on stor_done; the DIR
            // pager is naturally unarmed between pages (done pulses per
            // page). Storage's own 21.5s op watchdog errors first in every
            // storage-side stall, so this fires only for the class where
            // the command never started or done was lost - fail to ?IO,
            // never a dead console.
            if (stor_dir || stor_dir_next || stor_open || stor_readline
                || stor_close || stor_delete
                || stor_get_byte || stor_putc)
                cons_stor_arm <= 1'b1;
            else if (stor_done)
                cons_stor_arm <= 1'b0;
            if (stor_done || !cons_stor_arm)
                cons_stor_wd <= 32'd0;
            else begin
                cons_stor_wd <= (state_q[C_CMP_WAIT]) ? 32'd0
                                                      : (cons_stor_wd + 32'd1);
                if (!state_q[C_CMP_WAIT] && cons_stor_wd[31] && cons_stor_wd[30]) begin // ~32s
                    cons_stor_arm <= 1'b0;
                    cons_stor_wd  <= 32'd0;
                    reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                end
            end
            // C_CMP_WAIT is progress by definition: the VM is computing and
            // issues no storage ops for the whole compile. Without this the
            // 21.5 s clock fires mid-compile and reports ?IO, which looks
            // like a disk fault rather than a watchdog.
            if (state_q[C_IDLE] || state_q[C_PROMPT]
                || state_q[C_CMP_WAIT] || stor_done)
                // stor_done counts as progress: a standalone DONKEY.JSH
                // load is 2.36MB of get_byte pulses over minutes - alive
                // the whole time. A wedged op stops pulsing done and the
                // 21.5s clock runs out as before.
                cons_prog_wd <= 32'd0;
            else begin
                cons_prog_wd <= cons_prog_wd + 32'd1;
                if (cons_prog_wd[31]) begin // ~21.5s
                    cons_prog_wd <= 32'd0;
                    reply_sel <= 4'd4; reply_idx <= 0; state_q <= (117'd1 << C_REPLY);
                end
            end

            // Native menu requests arrive only after the previous command
            // is idle. SOURCE and its filename stay owned by this console.
            if(park_finder && finder_cache_valid)park_pending<=1;
            if(forget_finder)begin finder_state_valid<=0;park_pending<=0;end
            if(park_pending && !vm_busy_i && (state_q[C_IDLE] || state_q[C_PROMPT]))begin
                resident_restore<=0;resident_init<=0;resident_phase<=0;resident_i<=0;state_q <= (117'd1 << C_RESIDENT);
            end
            if(shell_request && ready_lit && !vm_busy_i && !host_hold_o)begin
                shell_accepted<=1;command_failed_o<=0;
                service_how<=shell_how;service_name_q<=shell_name;
                service_load_pending<=0;
                if(shell_how==8)start_system(4'd8);
                else if(shell_len==0 || shell_len>12)begin
                    reply_sel<=4'd6;reply_idx<=0;state_q <= (117'd1 << C_REPLY);
                end else begin
                    // Enter the name writer directly; the command parser,
                    // line buffer and keyboard have no role in Finder launch.
                    halt_pulse<=1;
                    service_load_pending<=1;
                    name_len_r<={3'd0,shell_len};name_i<=0;
                    cmd_is_load<=1;
                    src_bank<=0;src_trunc<=0;
                    state_q <= (117'd1 << C_NWR);
                end
            end
            if(raw_cdone_pending && !host_hold_o && (state_q[C_IDLE] || state_q[C_PROMPT]))begin
                raw_cdone_armed<=0; cdone_seen_low<=1;
                halt_pulse<=1'b1; handoff_stop_pending<=1'b1;
                cmp_arm_r<=0; cmp_interactive<=1;
                cmp_img_len<=cmp_len_i; cmp_out_off<=0;
                cmp_ph<=1; cmp_wd<=1; cmp_pend<=0;
                cmp_save_mode<=0; cmp_art_mode<=0; big_staged<=0;
                state_q <= (117'd1 << C_CMP_WAIT);
            end
            if(document_new)begin
                src_len<=0;src_len_z<=1'b1;src_name_len<=12;ui_unnamed_o<=1;
                src_is_html<=document_new_role!=5;src_is_js<=0;
                for(integer nn=0;nn<16;nn=nn+1)src_name[nn]<=ui_untitled(nn,document_new_role==5);
            end
            if(ui_set_name)begin
                src_name_len<={1'b0,ui_name_len};ui_unnamed_o<=0;
                for(integer nn=0;nn<16;nn=nn+1)src_name[nn]<=nn<12 && nn<ui_name_len?ui_name[nn*8+:8]:8'd0;
                src_is_html<=ui_name_len>=4 && ui_name[(ui_name_len-4)*8+:32]==32'h4d54482e;
                src_is_js<=ui_name_len>=3 && ui_name[(ui_name_len-3)*8+:24]==24'h534a2e;
            end

            tether_abort_q<=tether_abort;
            if(tether_abort && !tether_abort_q)host_link_event<=1;
            // Service response storage is independent of the UART serializer;
            // a completion cannot overwrite an unconsumed acceptance record.
            if(host_q_valid && host_q_ready)host_q_valid<=0;
            if(host_finish_pending && !host_q_valid)begin
                host_reply(host_op,host_tx,2,host_result_status,host_result_value);
                if(!ho_7)begin
                    host_last_body<=host_body;host_last_status<=host_result_status;
                    host_last_value<=host_result_value;host_last_valid<=1;
                end
                host_finish_pending<=0;host_active<=0;
            end else if(host_status_tail && !host_q_valid)begin
                host_reply(0,host_status_tx,2,0,32'h0000007f);host_status_tail<=0;
            end else if(host_link_event && !host_q_valid)begin
                host_reply(0,0,3,0,host_snapshot);host_link_event<=0;
            end
            if(src_setlen_stb_i || state_q[C_LD_OPEN])source_stage_valid<=0;
            if(state_q[C_IDLE] && host_owned && jsb_tether_src)begin
                source_stage_valid<=0;source_stage_error<=0;
            end
            if(state_q[C_IDLE] && host_owned && jsb_tether_big)begin
                cart_stage_valid<=0;cart_stage_error<=0;
            end
            if(state_q[C_SRC_TETHER] && jsb_tether_eof)begin
                source_stage_valid<=!jsb_tether_crc_err && !src_trunc;
                source_stage_error<=jsb_tether_crc_err?8'd6:src_trunc?8'd5:8'd0;
            end
            if(state_q[C_BIG_TETHER] && jsb_tether_eof)begin
                cart_stage_error<=jsb_tether_crc_err?8'd6:big_trunc?8'd5:8'd0;
                if(!big_hi)cart_stage_valid<=!jsb_tether_crc_err && !big_trunc;
            end
            if(state_q[C_BIG_WR] && src_gnt && big_eof)
                cart_stage_valid<=!big_trunc && cart_stage_error==0;
            // No stage is valid after an interrupted transfer.
            if((state_q[C_SRC_TETHER] || state_q[C_BIG_TETHER]) &&
                ((!kbd_empty && kbd_data==27) || teth_wd[30]))begin
                source_stage_valid<=0;cart_stage_valid<=0;
                source_stage_error<=8;cart_stage_error<=8;tether_abort<=1;
            end
            if(host_active && host_state!=H_NONE)begin
                host_watchdog<=host_watchdog+1'b1;
                if(host_state!=H_NOTIFY && (stor_done || jsb_tether_stb || sram_ack))host_watchdog<=0;
                else if(host_watchdog[31])begin
                    // Existing storage/VM watchdogs remain authoritative;
                    // this also bounds a lost host-service handoff.
                    host_finish(7,0);
                end
            end
            case(host_state)
                H_CHECK:begin
                    host_check_name<=host_check_name>>8;
                    host_check_i<=host_check_i+1'b1;
                    if(host_check_i<host_name_len)begin
                        if(host_check_name[7:0]==".")begin
                            if(host_dot || host_stem_n==0)host_bad_name<=1;
                            host_dot<=1;
                        end else begin
                            if(!fat_letter(host_check_name[7:0]))host_bad_name<=1;
                            if(host_dot)begin
                                if(host_ext_n==3)host_bad_name<=1;
                                host_ext_n<=host_ext_n+1'b1;
                            end else begin
                                if(host_stem_n==8)host_bad_name<=1;
                                host_stem_n<=host_stem_n+1'b1;
                            end
                        end
                    end else if(host_check_name[7:0]!=0)host_bad_name<=1;
                    if(host_check_i==11)host_state<=H_BEGIN;
                end
                H_BEGIN:begin
                    if(ho_name &&
                        (host_bad_name || host_stem_n==0 || (host_dot && host_ext_n==0)))host_finish(4,0);
                    else if(ho_23 && !host_owned)host_finish(1,0);
                    else if(ho_23 && (hb_wait_q ||
                        srcb_pend || src_req || state_q[C_SRC_TETHER] || state_q[C_SRC_WR] ||
                         state_q[C_BIG_TETHER] || state_q[C_BIG_WR]))begin
                        // The CRC trailer may arrive before an outstanding
                        // SOURCE write or odd CART tail reaches SRAM. Await
                        // that acknowledged staging completion, not a timer.
                    end
                    // arg_ne_*_q compare the previous clock's lengths; hb_wait_q
                    // (above) holds one clock after any staging write.
                    else if(ho_2 && (!source_stage_valid || arg_ne_src_q))
                        host_finish(source_stage_error!=0?source_stage_error:8'd5,32'(src_len));
                    else if(ho_3 && (!cart_stage_valid || arg_ne_big_q))
                        host_finish(cart_stage_error!=0?cart_stage_error:8'd5,32'(big_len));
                    else if(ho_7 && !host_owned)host_finish(1,0);
                    else if(ho_1 && ha_gt1)host_finish(5,0);
                    else if(ho_4 && (ha_gt3 || library_dirty))host_finish(5,0);
                    else if(ho_5 && (library_dirty || ha_lt16 || ha_gt7f))host_finish(5,0);
                    else if(vm_busy_i)begin
                        // Finder may be parked; an editor/game with unsaved
                        // data is never stopped merely to import a file.
                        if(finder_active_i && state_q[C_CMP_WAIT] && cmp_ph==0 && !srcb_pend && !stor_busy)begin
                            raw_cdone_armed<=0;
                            if(ho_1 && ha_eq0)begin
                                // Finder paints its own receiving panel and
                                // yields through the existing sysRun service.
                                host_receive_request<=1;host_state<=H_NOTIFY;
                            end else begin halt_pulse<=1;host_state<=H_STOP;end
                        end else host_finish(1,0);
                    end else if(ready_lit)begin
                        if(!present_busy_i)host_begin_owned();
                    end
                    else host_finish(1,0);
                end
                H_NOTIFY:begin
                    if(host_receive_taken)host_receive_request<=0;
                    if(host_receive_yield)host_state<=H_STOP;
                    else if(host_watchdog[29])host_finish(1,0);
                end
                H_STOP:if(!vm_busy_i && !present_busy_i && !srcb_pend && !stor_busy)begin
                    cmp_interactive<=0;cmp_arm_r<=0;raw_cdone_armed<=0;
                    state_q <= (117'd1 << C_PROMPT);host_state<=H_PARK;
                    if(finder_cache_valid)park_pending<=1;
                end
                H_PARK:if(ready_lit && !vm_busy_i)host_begin_owned();
                H_WAIT:begin
                    if(ho_5 && !host_stream_announced && state_q[C_JSB_TETHER] && !host_q_valid)begin
                        // Only invite bulk bytes once Finder is safely parked
                        // and the actual image consumer can accept them.
                        host_reply(5,host_tx,1,0,host_arg);host_stream_announced<=1;
                    end
                    if((ho_1 || ho_4 || ho_5) && (vm_start || run_pulse))begin
                        host_started<=1;host_started_finder<=ho_1;host_finish(0,ho_5?32'(jsb_boff):image_code_bytes);
                    end
                    if(ho_23 && state_q[C_SV_CLOSEW] && stor_done)begin
                        if(save_failed || stor_err)host_finish(7,0);
                        else begin
                            host_finish(0,host_arg);source_stage_valid<=0;cart_stage_valid<=0;
                            // A replacement library or Finder must never use
                            // an older executable/cache at the next refresh.
                            if(host_name==96'h004d4f522e584f424c4f4f54 || // TOOLBOX.ROM
                               host_name==96'h004b4e4c2e584f424c4f4f54 || // TOOLBOX.LNK
                               host_name==96'h000048534a2e5245444e4946 || // FINDER.JSH
                               host_name==96'h00005359532e4d4554535953)begin // SYSTEM.SYS
                                library_dirty<=1;finder_cache_valid<=0;finder_state_valid<=0;
                            end
                        end
                    end
                    if(state_q[C_REPLY] && service_error(reply_sel))begin
                        host_finish(tether_abort?8'd8:reply_sel==16?8'd6:(reply_sel==7 || reply_sel==15)?8'd5:8'd7,
                            tether_abort?32'h80000000:32'(reply_sel));
                        state_q <= (117'd1 << C_PROMPT);command_failed_o<=0;
                    end
                end
                default:;
            endcase
            // Console-side request register (see hreq_* above).
            arg_ne_src_q<=host_arg!=32'(src_len);
            arg_ne_big_q<=host_arg!=32'(big_len);
            hb_wait_q<=srcb_pend || src_req || src_setlen_stb_i || state_q[C_SRC_TETHER] ||
                state_q[C_SRC_WR] || state_q[C_BIG_TETHER] || state_q[C_BIG_WR];
            if(host_req_valid && !hreq_v)begin
                hreq_v<=1;hreq_body<=host_req_body;hreq_crc_ok<=host_req_crc_ok;
                hreq_badver<=host_req_body[7:0]!=1;
                hreq_op0<=host_req_body[15:8]==0;hreq_op6<=host_req_body[15:8]==6;
                hreq_opgt7<=host_req_body[15:8]>7;
                hreq_len_bad<=(host_req_body[15:8]==2 || host_req_body[15:8]==3 || host_req_body[15:8]==4) ?
                    (host_req_body[87:80]==0 || host_req_body[87:80]>12) : host_req_body[87:80]!=0;
                hreq_arg_eq0<=host_req_body[79:48]==0;hreq_arg_gt1<=host_req_body[79:48]>1;
                hreq_arg_gt3<=host_req_body[79:48]>3;hreq_arg_lt16<=host_req_body[79:48]<16;
                hreq_arg_gt7f<=host_req_body[79:48]>32'h007fffff;
            end
            if(host_req_go)begin
                hreq_v<=0;
                if(!hreq_crc_ok)host_reply(request_op,request_tx,2,6,0);
                else if(hreq_badver)host_reply(request_op,request_tx,2,2,0);
                else if(hreq_op6)begin
                    if(host_active && request_arg==host_tx)host_reply(6,request_tx,1,0,0);
                    else if(host_last_valid && request_arg==host_last_body[47:16])host_reply(6,request_tx,2,host_last_status,host_last_value);
                    else host_reply(6,request_tx,2,9,0);
                end else if(hreq_op0)begin
                    host_reply(0,request_tx,3,0,host_snapshot);
                    host_status_tail<=1;host_status_tx<=request_tx;
                end else if(host_active && request_tx==host_tx)begin
                    if((&request_same_active_words))begin
                        if(!ho_5 || host_stream_announced)host_reply(request_op,request_tx,1,0,0);
                        // Otherwise its original acceptance is still pending
                        // the FD consumer; do not invite the bytes early.
                    end else host_reply(request_op,request_tx,2,10,0);
                end else if(host_last_valid && request_tx==host_last_body[47:16])begin
                    if((&request_same_last_words))host_reply(request_op,request_tx,2,host_last_status,host_last_value);
                    else host_reply(request_op,request_tx,2,10,0);
                end else if(host_active)host_reply(request_op,request_tx,2,1,0);
                else if(tether_abort)host_reply(request_op,request_tx,2,8,32'h80000000);
                else if(hreq_opgt7)host_reply(request_op,request_tx,2,3,0);
                else if(hreq_len_bad)host_reply(request_op,request_tx,2,4,0);
                else begin
                    host_body<=hreq_body;host_active<=1;host_watchdog<=0;host_stream_announced<=0;
                    ho_1<=request_op==1;ho_2<=request_op==2;ho_3<=request_op==3;ho_4<=request_op==4;
                    ho_5<=request_op==5;ho_7<=request_op==7;
                    ho_23<=request_op==2 || request_op==3;
                    ho_name<=request_op==2 || request_op==3 || request_op==4;
                    ha_eq0<=hreq_arg_eq0;ha_gt1<=hreq_arg_gt1;ha_gt3<=hreq_arg_gt3;
                    ha_lt16<=hreq_arg_lt16;ha_gt7f<=hreq_arg_gt7f;
                    host_check_name<=hreq_body[183:88];host_check_i<=0;
                    host_stem_n<=0;host_ext_n<=0;host_dot<=0;host_bad_name<=0;
                    host_state<=(request_op==2 || request_op==3 || request_op==4)?H_CHECK:H_BEGIN;
                    if(request_op!=5)host_reply(request_op,request_tx,1,0,0);
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
                // src_bank picks the arena for the compile paths; the
                // dedicated cmp_rd_addr avoids widening src_addr, which is
                // shared with LOAD / SAVE / the EDIT memmove.
                sram_addr  <= src_bank ? cmp_rd_addr
                                       : (SRC_SRAM_BASE + 21'(src_addr));
                sram_wdata <= src_w16 ? {src_wdata, src_wlo} : {8'd0, src_wdata};
                srcb_we_l  <= src_we;
                srcb_wd_l  <= src_wdata;
            end else if (srcb_pend && sram_ack) begin
                srcb_pend <= 1'b0;
                sram_req  <= 1'b0;
                sram_we   <= 1'b0;
                src_rdata <= srcb_we_l ? srcb_wd_l : sram_rdata[7:0];
                src_rdata_hi <= sram_rdata[15:8];
                src_gnt   <= 1'b1;
            end
        end
    end
endmodule
