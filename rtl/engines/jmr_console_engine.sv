// Standalone READY console — BASIC console_engine method + FAT32 storage.
// Verbs: HELP / DIR / LOAD / SAVE / REMOVE / LIST / MEM / NEW / RUN
// NEW: LIST dumps SOURCE BRAM; RUN only starts RECTDEMO if that file is loaded
// (LOAD INVADERS + RUN must NOT silently run the wrong demo).
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
    // Silicon games ladder: pulse when monitor sees RUN
    output logic        run_pulse,
    // NEW: start bytecode VM (INVADERS.JSB etc.)
    output logic        vm_start,
    // NEW: storage_engine (BASIC handshake)
    output logic        stor_open,
    output logic [7:0]  stor_mode,
    output logic [7:0]  stor_chan,
    output logic [15:0] stor_name_addr,
    output logic [7:0]  stor_name_len,
    output logic        stor_close,
    output logic        stor_readline,
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
    // NEW: work RAM master (NAME_BUF 0xB850, STORAGE_BUFFER 0xBB00, SOURCE 0xC000)
    output logic        mem_en,
    output logic        mem_we,
    output logic [15:0] mem_addr,
    output logic [7:0]  mem_wdata,
    input  logic [7:0]  mem_rdata,
    input  logic        mem_gnt
);
    localparam logic [15:0] NAME_BUF        = 16'hB850;
    localparam logic [15:0] STORAGE_BUFFER  = 16'hBB00;
    localparam logic [15:0] SOURCE_BASE     = 16'hC000;
    localparam int unsigned SOURCE_MAX      = 8192;

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
        // SAVE
        C_SV_OPEN, C_SV_OPENW, C_SV_RD, C_SV_RDW, C_SV_PUT, C_SV_PUTW, C_SV_CLOSE, C_SV_CLOSEW,
        // REMOVE
        C_RM, C_RMW,
        // NEW: numbered LIST + MORE + ranges (BASIC method)
        C_LIST_PARSE, C_LIST_PAR_LO, C_LIST_PAR_HI,
        C_LIST_INIT, C_LIST_LINE, C_LIST_PEEL, C_LIST_EMIT_DIG,
        C_LIST_SP, C_LIST_RD_GO, C_LIST_RD, C_LIST_CH, C_LIST_PUT,
        C_LIST_PUT_LAST, C_LIST_NL_FORCE, C_LIST_NL,
        C_LIST_MORE, C_LIST_WAIT,
        // NEW: CLS + EDIT n
        C_CLS, C_EDIT_PARSE, C_EDIT_FIND, C_EDIT_RD, C_EDIT_CH,
        C_EDIT_SHOW, C_EDIT_PEEL, C_EDIT_EMIT, C_EDIT_SP, C_EDIT_BODY,
        C_EDIT_BODY_RD, C_EDIT_BODY_CH, C_EDIT_BODY_PUT, C_EDIT_NL, C_EDIT_ARM,
        C_EDIT_REPL, C_EDIT_GROW, C_EDIT_GROW_RD, C_EDIT_GROW_WR,
        C_EDIT_SHRINK, C_EDIT_SHRINK_RD, C_EDIT_SHRINK_WR,
        C_EDIT_WR_NEW, C_EDIT_WR_NL
    } cstate_t;
    cstate_t state, ret_state;

    logic [7:0] line [0:127];
    logic [6:0] line_len;
    logic [6:0] msg_idx;
    logic [7:0] ch;
    logic [3:0] reply_sel;
    logic [6:0] reply_idx;
    logic [6:0] name_i, name_start, name_len_r;
    logic [7:0] dir_n, dir_idx;
    logic [15:0] src_len;     // bytes in SOURCE_BASE
    logic [15:0] src_i;
    logic [7:0]  rd_ch;
    logic        cmd_is_load, cmd_is_save, cmd_is_remove;
    // NEW: last LOADed name (upcased) so RUN won't fake RECTDEMO for INVADERS
    logic [7:0]  src_name [0:15];
    logic [4:0]  src_name_len;
    logic        src_is_rectdemo;
    logic        src_is_invaders;  // NEW: LOAD INVADERS* → VM has bytecode
    // NEW: LIST range / MORE (display numbers 10,20,… like PYTHON)
    logic        list_page;
    logic [15:0] list_lo, list_hi, list_disp;
    logic [3:0]  list_on_page;
    logic        list_skip;       // line outside range — consume without print
    logic [15:0] peel_mag, peel_q;
    logic [3:0]  peel_rem;
    logic [4:0]  peel_bit;
    logic [7:0]  digs [0:4];
    logic [2:0]  dig_n, dig_i;
    // NEW: EDIT n
    logic        edit_pending;
    logic [15:0] edit_disp;
    logic [15:0] edit_start, edit_end;  // byte offsets of target line
    logic [15:0] edit_copy_i, edit_new_len;
    logic [4:0]  peel_tmp;  // NEW: /10 peel scratch (no nested logic decls)

    // Case-insensitive compare helpers (FIFO no longer folds a-z)
    function automatic logic [7:0] up(input logic [7:0] c);
        up = (c >= 8'h61 && c <= 8'h7A) ? (c - 8'h20) : c;
    endfunction
    function automatic logic is_sp(input logic [7:0] c);
        is_sp = (c == " ");
    endfunction

    function automatic logic [7:0] banner_char(input logic [6:0] i);
        case (i)
            0: banner_char = "J"; 1: banner_char = "M"; 2: banner_char = "R";
            3: banner_char = " "; 4: banner_char = "J"; 5: banner_char = "S";
            6: banner_char = "-"; 7: banner_char = "N"; 8: banner_char = "A";
            9: banner_char = "T"; 10: banner_char = "I"; 11: banner_char = "V";
            12: banner_char = "E"; 13: banner_char = "-"; 14: banner_char = "C";
            15: banner_char = "P"; 16: banner_char = "U"; 17: banner_char = " ";
            18: banner_char = "V"; 19: banner_char = "0"; 20: banner_char = ".";
            21: banner_char = "0"; 22: banner_char = "."; 23: banner_char = "1";
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

    // 0=HELP 1=MEM 2=OK 3=? 4=?IO 5=LOADED 6=?FN 7=(NO VM) 8=-- MORE --
    function automatic logic [7:0] reply_char(input logic [3:0] sel, input logic [6:0] i);
        case (sel)
            4'd0: case (i)
                0: reply_char="H";1: reply_char="E";2: reply_char="L";3: reply_char="P";
                4: reply_char=" ";5: reply_char="D";6: reply_char="I";7: reply_char="R";
                8: reply_char=" ";9: reply_char="L";10: reply_char="O";11: reply_char="A";
                12: reply_char="D";13: reply_char=" ";14: reply_char="L";15: reply_char="I";
                16: reply_char="S";17: reply_char="T";18: reply_char=" ";19: reply_char="E";
                20: reply_char="D";21: reply_char="I";22: reply_char="T";23: reply_char=" ";
                24: reply_char="C";25: reply_char="L";26: reply_char="S";27: reply_char=" ";
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
                0: reply_char="?";1: reply_char="F";2: reply_char="N"; default: reply_char=8'h00;
            endcase
            4'd7: case (i)
                // ?NB — no bytecode for this LOAD (VM exists; companion .JSB missing)
                0: reply_char="?";1: reply_char="N";2: reply_char="B"; default: reply_char=8'h00;
            endcase
            4'd8: case (i)
                // -- MORE --
                0: reply_char="-";1: reply_char="-";2: reply_char=" ";3: reply_char="M";
                4: reply_char="O";5: reply_char="R";6: reply_char="E";7: reply_char=" ";
                8: reply_char="-";9: reply_char="-"; default: reply_char=8'h00;
            endcase
            default: case (i)
                0: reply_char="?"; default: reply_char=8'h00;
            endcase
        endcase
    endfunction

    assign ready_lit = (state == C_IDLE || state == C_PROMPT);
    assign stor_chan = 8'd1;
    assign stor_name_addr = NAME_BUF;

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
            ch <= 0;
            stor_open <= 0; stor_close <= 0; stor_readline <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            stor_mode <= "I"; stor_name_len <= 0; stor_putc_data <= 0;
            mem_en <= 0; mem_we <= 0; mem_addr <= 0; mem_wdata <= 0;
            src_len <= 0; src_i <= 0;
            name_len_r <= 0; name_i <= 0; name_start <= 0;
            dir_n <= 0; dir_idx <= 0;
            cmd_is_load <= 0; cmd_is_save <= 0; cmd_is_remove <= 0;
            src_name_len <= 0; src_is_rectdemo <= 0; src_is_invaders <= 0;
            list_page <= 0; list_lo <= 16'd10; list_hi <= 16'hFFFF;
            list_disp <= 16'd10; list_on_page <= 0; list_skip <= 0;
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
            stor_open <= 0; stor_close <= 0; stor_readline <= 0;
            stor_putc <= 0; stor_dir <= 0; stor_dir_next <= 0; stor_delete <= 0;
            mem_en <= 0; mem_we <= 0;

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
                    end else if (line_len == 4 &&
                               up(line[0])=="H" && up(line[1])=="E" &&
                               up(line[2])=="L" && up(line[3])=="P") begin
                        reply_sel <= 4'd0; reply_idx <= 0; state <= C_REPLY;
                    end else if (line_len == 3 &&
                               up(line[0])=="D" && up(line[1])=="I" &&
                               up(line[2])=="R") begin
                        state <= C_DIR0;
                    end else if (line_len == 3 &&
                               up(line[0])=="C" && up(line[1])=="L" &&
                               up(line[2])=="S") begin
                        // NEW: CLS like BASIC
                        state <= C_CLS;
                    end else if (line_len >= 4 &&
                               up(line[0])=="L" && up(line[1])=="I" &&
                               up(line[2])=="S" && up(line[3])=="T" &&
                               (line_len == 4 || is_sp(line[4]))) begin
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
                    end else if (line_len >= 5 &&
                               up(line[0])=="E" && up(line[1])=="D" &&
                               up(line[2])=="I" && up(line[3])=="T" &&
                               is_sp(line[4])) begin
                        // NEW: EDIT n
                        name_i <= 5;
                        peel_mag <= 0;
                        state <= C_EDIT_PARSE;
                    end else if (line_len == 3 &&
                               up(line[0])=="M" && up(line[1])=="E" &&
                               up(line[2])=="M") begin
                        reply_sel <= 4'd1; reply_idx <= 0; state <= C_REPLY;
                    end else if (line_len == 3 &&
                               up(line[0])=="N" && up(line[1])=="E" &&
                               up(line[2])=="W") begin
                        src_len <= 0; src_name_len <= 0; src_is_rectdemo <= 0; src_is_invaders <= 0;
                        reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                    end else if (line_len >= 3 &&
                               up(line[0])=="R" && up(line[1])=="U" &&
                               up(line[2])=="N" &&
                               (line_len == 3 || is_sp(line[3]))) begin
                        // RECTDEMO → hardcoded engine; INVADERS → bytecode VM; else ?NB
                        if (src_is_rectdemo || src_len == 0) begin
                            run_pulse <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                        end else if (src_is_invaders) begin
                            vm_start <= 1'b1;
                            reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                        end else begin
                            reply_sel <= 4'd7; reply_idx <= 0; state <= C_REPLY;
                        end
                    end else if (line_len >= 5 &&
                               up(line[0])=="L" && up(line[1])=="O" &&
                               up(line[2])=="A" && up(line[3])=="D" &&
                               is_sp(line[4])) begin
                        cmd_is_load <= 1'b1; name_start <= 5; state <= C_PF;
                    end else if (line_len >= 5 &&
                               up(line[0])=="S" && up(line[1])=="A" &&
                               up(line[2])=="V" && up(line[3])=="E" &&
                               is_sp(line[4])) begin
                        cmd_is_save <= 1'b1; name_start <= 5; state <= C_PF;
                    end else if (line_len >= 7 &&
                               up(line[0])=="R" && up(line[1])=="E" &&
                               up(line[2])=="M" && up(line[3])=="O" &&
                               up(line[4])=="V" && up(line[5])=="E" &&
                               is_sp(line[6])) begin
                        cmd_is_remove <= 1'b1; name_start <= 7; state <= C_PF;
                    end else begin
                        reply_idx <= 0; state <= C_REPLY;
                    end
                end
                C_REPLY: begin
                    if (reply_char(reply_sel, reply_idx) == 8'h00) begin
                        print_nl <= 1'b1;
                        msg_idx <= 0;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_PROMPT;
                    end else if (!video_busy) begin
                        put_en <= 1'b1;
                        put_char <= reply_char(reply_sel, reply_idx);
                        reply_idx <= reply_idx + 1'b1;
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_REPLY;
                    end
                end

                // ---- DIR (BASIC ST_DIR*) --------------------------------
                C_DIR0: if (!stor_busy) begin stor_dir <= 1'b1; state <= C_DIR0W; end
                C_DIR0W: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else state <= C_DIRN;
                end
                C_DIRN: if (!stor_busy) begin stor_dir_next <= 1'b1; state <= C_DIRNW; end
                C_DIRNW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else if (stor_eof) begin msg_idx <= 0; state <= C_PROMPT; end
                    else begin dir_n <= stor_line_len; dir_idx <= 0; state <= C_DIR_RD; end
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
                    print_nl <= 1'b1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_DIRN;
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
                                 up(line[name_start+0])=="R" && up(line[name_start+1])=="E" &&
                                 up(line[name_start+2])=="C" && up(line[name_start+3])=="T" &&
                                 up(line[name_start+4])=="D" && up(line[name_start+5])=="E" &&
                                 up(line[name_start+6])=="M" && up(line[name_start+7])=="O");
                            // INVADERS.JS → bytecode VM (invaders_jsb.hex)
                            src_is_invaders <=
                                (name_len_r >= 8 &&
                                 up(line[name_start+0])=="I" && up(line[name_start+1])=="N" &&
                                 up(line[name_start+2])=="V" && up(line[name_start+3])=="A" &&
                                 up(line[name_start+4])=="D" && up(line[name_start+5])=="E" &&
                                 up(line[name_start+6])=="R" && up(line[name_start+7])=="S");
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
                        state <= C_NWR_W;
                    end
                end
                C_NWR_W: if (mem_gnt) begin
                    name_i <= name_i + 1'b1;
                    state <= C_NWR;
                end

                // ---- LOAD -----------------------------------------------
                C_LD_OPEN: if (!stor_busy) begin
                    stor_mode <= "I";
                    stor_open <= 1'b1;
                    src_len <= 0;
                    state <= C_LD_OPENW;
                end
                C_LD_OPENW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_REPLY; end
                    else state <= C_LD_RL;
                end
                C_LD_RL: if (!stor_busy) begin
                    stor_readline <= 1'b1;
                    state <= C_LD_RLW;
                end
                C_LD_RLW: if (stor_done) begin
                    if (stor_err) begin reply_sel <= 4'd4; reply_idx <= 0; state <= C_LD_CLOSE; end
                    else if (stor_eof) state <= C_LD_CLOSE;
                    else begin dir_n <= stor_line_len; dir_idx <= 0; state <= C_LD_RD; end
                end
                C_LD_RD: begin
                    if (dir_idx >= dir_n) begin
                        // append NL
                        if (src_len < SOURCE_MAX[15:0]) begin
                            mem_en <= 1'b1; mem_we <= 1'b1;
                            mem_addr <= SOURCE_BASE + src_len;
                            mem_wdata <= 8'h0A;
                            state <= C_LD_NLW;
                        end else state <= C_LD_RL;
                    end else if (src_len < SOURCE_MAX[15:0]) begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= STORAGE_BUFFER + {8'h0, dir_idx};
                        state <= C_LD_RDW;
                    end else state <= C_LD_RL;
                end
                C_LD_RDW: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    mem_en <= 1'b1; mem_we <= 1'b1;
                    mem_addr <= SOURCE_BASE + src_len;
                    mem_wdata <= mem_rdata;
                    state <= C_LD_WRW;
                end
                C_LD_WRW: if (mem_gnt) begin
                    src_len <= src_len + 1'b1;
                    dir_idx <= dir_idx + 1'b1;
                    state <= C_LD_RD;
                end
                C_LD_NLW: if (mem_gnt) begin
                    src_len <= src_len + 1'b1;
                    state <= C_LD_RL;
                end
                C_LD_CLOSE: if (!stor_busy) begin stor_close <= 1'b1; state <= C_LD_CLOSEW; end
                C_LD_CLOSEW: if (stor_done) begin
                    reply_sel <= 4'd5; reply_idx <= 0; state <= C_REPLY;
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
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= SOURCE_BASE + src_i;
                        state <= C_SV_RDW;
                    end
                end
                C_SV_RDW: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
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
                    cls <= 1'b1;
                    msg_idx <= 0;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_PROMPT;
                end

                // ---- LIST parse: LIST - / LIST n / LIST n-m --------------
                C_LIST_PARSE: begin
                    if (name_i >= line_len) begin
                        state <= C_LIST_INIT;
                    end else if (is_sp(line[name_i])) begin
                        name_i <= name_i + 1'b1;
                    end else if (line[name_i] == "-") begin
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
                    end else if (line[name_i] >= "0" && line[name_i] <= "9") begin
                        list_page <= 1'b0;
                        peel_mag <= 0;
                        state <= C_LIST_PAR_LO;
                    end else begin
                        reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                    end
                end
                C_LIST_PAR_LO: begin
                    if (name_i >= line_len) begin
                        // NEW: list_hi must use peel_mag — same-cycle list_lo is still old
                        list_lo <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        list_hi <= (peel_mag == 0) ? 16'd10 : peel_mag;
                        state <= C_LIST_INIT;
                    end else if (line[name_i] >= "0" && line[name_i] <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, line[name_i] - "0"};
                        name_i <= name_i + 1'b1;
                    end else if (line[name_i] == "-") begin
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
                    if (name_i >= line_len) begin
                        list_hi <= (peel_mag == 0) ? 16'hFFFF : peel_mag;
                        state <= C_LIST_INIT;
                    end else if (line[name_i] >= "0" && line[name_i] <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, line[name_i] - "0"};
                        name_i <= name_i + 1'b1;
                    end else begin
                        list_hi <= (peel_mag == 0) ? 16'hFFFF : peel_mag;
                        state <= C_LIST_INIT;
                    end
                end

                // ---- LIST numbered dump ---------------------------------
                C_LIST_INIT: begin
                    if (src_len == 0) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else begin
                        src_i <= 0;
                        list_disp <= 16'd10;
                        list_on_page <= 0;
                        state <= C_LIST_LINE;
                    end
                end
                C_LIST_LINE: begin
                    if (src_i >= src_len) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else if (list_disp > list_hi) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else begin
                        list_skip <= (list_disp < list_lo);
                        if (list_skip) begin
                            // consume until NL without printing
                            mem_en <= 1'b1; mem_we <= 1'b0;
                            mem_addr <= SOURCE_BASE + src_i;
                            state <= C_LIST_RD;
                        end else begin
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
                    if (dig_i == 0) state <= C_LIST_SP;
                    else if (!video_busy) begin
                        dig_i <= dig_i - 3'd1;
                        put_en <= 1'b1;
                        put_char <= digs[dig_i - 3'd1];
                        state <= C_WAIT_VIDEO;
                        ret_state <= C_LIST_EMIT_DIG;
                    end
                end
                C_LIST_SP: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= " ";
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LIST_RD_GO;
                end
                C_LIST_RD_GO: begin
                    mem_en <= 1'b1; mem_we <= 1'b0;
                    mem_addr <= SOURCE_BASE + src_i;
                    state <= C_LIST_RD;
                end
                C_LIST_RD: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    state <= C_LIST_CH;
                end
                C_LIST_CH: begin
                    src_i <= src_i + 1'b1;
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D) begin
                        if (list_skip) begin
                            list_disp <= list_disp + 16'd10;
                            state <= C_LIST_LINE;
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
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LIST_RD_GO;
                end
                C_LIST_PUT_LAST: if (!video_busy) begin
                    put_en <= 1'b1;
                    put_char <= rd_ch;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LIST_NL_FORCE;
                end
                C_LIST_NL_FORCE: begin
                    print_nl <= 1'b1;
                    state <= C_WAIT_VIDEO;
                    ret_state <= C_LIST_NL;
                end
                C_LIST_NL: begin
                    list_disp <= list_disp + 16'd10;
                    if (list_page) begin
                        if (list_on_page >= 4'd13) begin
                            list_on_page <= 0;
                            reply_sel <= 4'd8; reply_idx <= 0;
                            state <= C_LIST_MORE;
                        end else begin
                            list_on_page <= list_on_page + 4'd1;
                            state <= C_LIST_LINE;
                        end
                    end else state <= C_LIST_LINE;
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
                    if (kbd_data == 8'h1B || kbd_data == 8'h03) begin
                        msg_idx <= 0; state <= C_PROMPT;
                    end else begin
                        // Space/Enter/any key → next page
                        state <= C_LIST_LINE;
                    end
                end

                // ---- EDIT n ---------------------------------------------
                C_EDIT_PARSE: begin
                    if (name_i >= line_len) begin
                        if (peel_mag == 0) begin
                            reply_sel <= 4'd3; reply_idx <= 0; state <= C_REPLY;
                        end else begin
                            edit_disp <= peel_mag;
                            src_i <= 0;
                            list_disp <= 16'd10;
                            edit_start <= 0;
                            state <= C_EDIT_FIND;
                        end
                    end else if (is_sp(line[name_i])) begin
                        name_i <= name_i + 1'b1;
                    end else if (line[name_i] >= "0" && line[name_i] <= "9") begin
                        peel_mag <= peel_mag * 16'd10 + {12'h0, line[name_i] - "0"};
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
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= SOURCE_BASE + src_i;
                        state <= C_EDIT_RD;
                    end
                end
                C_EDIT_RD: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    state <= C_EDIT_CH;
                end
                C_EDIT_CH: begin
                    src_i <= src_i + 1'b1;
                    if (rd_ch == 8'h0A || rd_ch == 8'h0D) begin
                        list_disp <= list_disp + 16'd10;
                        state <= C_EDIT_FIND;
                    end else if (src_i >= src_len) begin
                        list_disp <= list_disp + 16'd10;
                        state <= C_EDIT_FIND;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= SOURCE_BASE + src_i;
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
                    mem_en <= 1'b1; mem_we <= 1'b0;
                    mem_addr <= SOURCE_BASE + src_i;
                    state <= C_EDIT_BODY_RD;
                end
                C_EDIT_BODY_RD: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
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
                    if ({8'h0, line_len} + 16'd1 > (edit_end - edit_start + 16'd1)) begin
                        peel_mag <= ({8'h0, line_len} + 16'd1) - (edit_end - edit_start + 16'd1);
                        edit_copy_i <= src_len;
                        state <= C_EDIT_GROW;
                    end else if ({8'h0, line_len} + 16'd1 < (edit_end - edit_start + 16'd1)) begin
                        peel_mag <= (edit_end - edit_start + 16'd1) - ({8'h0, line_len} + 16'd1);
                        edit_copy_i <= edit_end + 16'd1;
                        state <= C_EDIT_SHRINK;
                    end else begin
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end
                end
                C_EDIT_GROW: begin
                    if (edit_copy_i == (edit_end + 16'd1) || src_len == edit_end + 16'd1) begin
                        src_len <= src_len + peel_mag;
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= SOURCE_BASE + edit_copy_i - 16'd1;
                        state <= C_EDIT_GROW_RD;
                    end
                end
                C_EDIT_GROW_RD: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    state <= C_EDIT_GROW_WR;
                end
                C_EDIT_GROW_WR: begin
                    mem_en <= 1'b1; mem_we <= 1'b1;
                    mem_addr <= SOURCE_BASE + (edit_copy_i - 16'd1) + peel_mag;
                    mem_wdata <= rd_ch;
                    edit_copy_i <= edit_copy_i - 16'd1;
                    state <= C_EDIT_GROW;
                end
                C_EDIT_SHRINK: begin
                    if (edit_copy_i >= src_len) begin
                        src_len <= src_len - peel_mag;
                        name_i <= 0;
                        src_i <= edit_start;
                        state <= C_EDIT_WR_NEW;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b0;
                        mem_addr <= SOURCE_BASE + edit_copy_i;
                        state <= C_EDIT_SHRINK_RD;
                    end
                end
                C_EDIT_SHRINK_RD: if (mem_gnt) begin
                    rd_ch <= mem_rdata;
                    state <= C_EDIT_SHRINK_WR;
                end
                C_EDIT_SHRINK_WR: begin
                    mem_en <= 1'b1; mem_we <= 1'b1;
                    mem_addr <= SOURCE_BASE + edit_copy_i - peel_mag;
                    mem_wdata <= rd_ch;
                    edit_copy_i <= edit_copy_i + 16'd1;
                    state <= C_EDIT_SHRINK;
                end
                C_EDIT_WR_NEW: begin
                    if (name_i >= line_len) begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= SOURCE_BASE + src_i;
                        mem_wdata <= 8'h0A;
                        state <= C_EDIT_WR_NL;
                    end else begin
                        mem_en <= 1'b1; mem_we <= 1'b1;
                        mem_addr <= SOURCE_BASE + src_i;
                        mem_wdata <= line[name_i];
                        name_i <= name_i + 1'b1;
                        src_i <= src_i + 1'b1;
                        state <= C_EDIT_WR_NEW;
                    end
                end
                C_EDIT_WR_NL: if (mem_gnt) begin
                    reply_sel <= 4'd2; reply_idx <= 0; state <= C_REPLY;
                end

                default: state <= C_IDLE;
            endcase
        end
    end
endmodule
