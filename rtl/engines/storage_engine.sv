// NEW Phase6: Storage Engine — all-RTL sequential channel I/O on a FAT32 card.
//
// Mirrors functional_model/engines/storage_engine.py (channel 1 only:
// OPEN "I"/"O", CLOSE, LINE INPUT#, INPUT#, PRINT#) and the minimal FAT32
// layout of hardware_model/fat32.py (MBR + one partition, 512-byte sectors,
// root directory only, 8.3 upper-case names, create / grow / overwrite /
// Delete).
//
// Physical layer is the existing rtl/phys/sd_spi_master.sv; this module owns
// the 512-byte sector buffer it fills (CMD17) and drains (CMD24).
//
// Data hand-off to the micro-sequencer goes through STORAGE_BUFFER (0xBB00),
// exactly like the Hardware Model streaming path: LINE INPUT# / INPUT# leave
// the line (or field) there and report its length, and the sequencer turns it
// into a String Space entry (string_engine copy mode) or parses a number.
//
// Channel registers (docs/HARDWARE_GATE.md, "Storage Engine") are published
// into the I/O page on OPEN / CLOSE.

module storage_engine #(
    // Passed straight to sd_spi_master so the board can slow SD init to
    // the spec window at its 4.6875 MHz core clock. Defaults = sim behaviour.
    parameter int unsigned SD_INIT_DIV = 127,
    parameter int unsigned SD_RUN_DIV  = 3
) (
    input  logic        clk,
    input  logic        rst_n,

    // -- micro-sequencer command interface (one channel) -------------------
    input  logic        start_open_i,       // OPEN mode_in, chan_in, name
    input  logic [7:0]  mode_in_i,          // ASCII 'I' or 'O'
    input  logic [7:0]  chan_in_i,
    input  logic [15:0] name_addr_i,        // address of first file-name char
    input  logic [7:0]  name_len_i,
    input  logic        start_close_i,      // CLOSE
    input  logic        card_present = 1'b1, // hot-swap detect (board sd_cd)
    input  logic        start_readline_i,   // LINE INPUT# -> STORAGE_BUFFER
    input  logic        start_readfield_i,  // INPUT#      -> STORAGE_BUFFER
    // Raw file byte for PATCH.BIN boot loader (after OPEN "I")
    input  logic        start_get_byte_i = 1'b0,
    output logic [7:0]  get_byte,
    input  logic        start_putc_i,       // PRINT# separator / newline
    input  logic [7:0]  putc_data_i,
    // Console DIR catalog + REMOVE (DIR uses BRAM sbuf sequential dent walk)
    input  logic        start_dir_i,
    input  logic        start_dir_next_i,
    input  logic        dir_show_all_i = 1'b0, // DIR *: do not hide .JSH/.ART
    input  logic        dir_show_system_i = 1'b0,
    input  logic        dir_raw_names_i = 1'b0,
    output logic [31:0] file_size_o,
    output logic [31:0] dir_size_o,
    input  logic        start_delete_i,
    input logic start_rename_i=1'b0, // rename the currently open input file to name_addr
    output logic not_found_o,
    output logic [15:0] dir_date_o,
    output logic [7:0] dir_attr_o,

    output logic [7:0]  line_len,         // bytes left in STORAGE_BUFFER
    output logic        eof,              // last read hit end of file
    output logic        err,              // file not found / no space / SD error
    output logic        done,             // one-cycle command completion
    output logic        busy,
    output logic [6:0]  dbg_state, // board telemetry: which state a stall parks in
    output logic [15:0] dbg_op_clk, // Clocks (x256, saturating) the current/last op took

    // -- print_engine character sink (FILE_PRINT_VALUE) --------------------
    // Same hand-shake shape as video_engine: hold wr_en until sink_busy rises.
    input  logic        sink_wr_en,
    input  logic [7:0]  sink_wr_char,
    output logic        sink_busy,

    // -- CPU memory master (STORAGE_BUFFER, file name, channel registers) --
    output logic        mem_en,
    output logic        mem_we,
    output logic [15:0] mem_addr,
    output logic [7:0]  mem_wdata,
    input  logic [7:0]  mem_rdata,
    input  logic        mem_gnt,

    // -- microSD SPI pins --------------------------------------------------
    output logic        spi_sck,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs_n
);
    // ---- memory map constants (functional_model/memory_map.py) -----------
    localparam logic [15:0] STORAGE_BUFFER    = 16'hBB00;
    localparam logic [15:0] IO_STORAGE_STATUS = 16'hB440;
    localparam logic [15:0] IO_SEQ_MODE       = 16'hB441;
    localparam logic [15:0] IO_SEQ_CHANNEL    = 16'hB442;
    localparam logic [15:0] IO_SEQ_OFFSET_LO  = 16'hB443;
    localparam logic [15:0] IO_SEQ_OFFSET_HI  = 16'hB444;
    localparam logic [15:0] IO_SEQ_NAME       = 16'hB450;

    localparam logic [31:0] FAT_EOC = 32'h0FFFFFFF;
    localparam logic [31:0] FAT_BAD = 32'h0FFFFFF7;

    // ---- SPI master + sector buffer --------------------------------------
    logic [7:0]  sd_cmd_r;
    logic [31:0] sd_lba_r;
    logic [7:0]  sd_status;
    logic        sd_ack;
    logic        sd_abort;          // One-beat abort to the SPI master
    logic [26:0] sd_wd;             // S_SD_WAIT watchdog
    logic [8:0]  sd_buf_addr;
    logic [7:0]  sd_buf_wdata;
    logic        sd_buf_we;

    // 512B sector pad in BRAM — simple dual-port 1W1R (SPI|FS time-mux)
    // Dual independent read ports made Vivado refuse ram_style=block (Synth 8-6849).
    (* ram_style = "block" *) logic [7:0] sbuf [0:511];
    logic        fs_buf_we;
    logic [8:0]  fs_buf_addr;
    logic [7:0]  fs_buf_wdata;
    logic [8:0]  fs_rd_addr;     // FS read address (when SPI idle)
    logic [8:0]  sbuf_raddr;
    logic [8:0]  sbuf_waddr;
    logic [7:0]  sbuf_wdata;
    logic        sbuf_we;
    logic [7:0]  sbuf_rdata;     // Registered read data (SPI + FS)
    logic [7:0]  br_byte;        // S_BRC capture
    logic [4:0]  br_i;           // Multi-byte gather index
    logic [31:0] br_acc;         // LE word gather (FAT / MBR LBA)
    logic [7:0]  dent [0:31];    // One dirent window (flops, not sbuf ports)
    logic [4:0]  dent_i;
    logic [3:0]  mnt_phase;      // BPB field gather
    logic [15:0] reserved_sect;  // BPB reserved sector count

    // SPI owns the read addr while busy; FS only reads in S_BR* (SPI idle)
    // FS-side patch writes (S_AP2, S_FS2, S_CL2, S_CL4, S_RENAME_PATCH,
    // S_DEL_PK) are decoded from the 129-fanout state register; land them
    // in a register and write one clock later. Every one of those states is
    // followed by at least one non-accessing beat before the sector is read
    // back (S_BR*) or written to the card (sd_go → command bytes first),
    // and the SPI side only writes sbuf while a read command is in flight.
    logic        fs_buf_we_q;
    logic [8:0]  fs_buf_addr_q;
    logic [7:0]  fs_buf_wdata_q;
    always_ff @(posedge clk) begin
        if (!rst_n) fs_buf_we_q <= 1'b0;
        else        fs_buf_we_q <= fs_buf_we;
        fs_buf_addr_q  <= fs_buf_addr;
        fs_buf_wdata_q <= fs_buf_wdata;
    end
    assign sbuf_we    = sd_buf_we | fs_buf_we_q;
    assign sbuf_waddr = sd_buf_we ? sd_buf_addr : fs_buf_addr_q;
    assign sbuf_wdata = sd_buf_we ? sd_buf_wdata : fs_buf_wdata_q;
    assign sbuf_raddr = sd_status[1] ? sd_buf_addr : fs_rd_addr;

    always_ff @(posedge clk) begin
        if (sbuf_we) sbuf[sbuf_waddr] <= sbuf_wdata;
        sbuf_rdata <= sbuf[sbuf_raddr];
    end

    sd_spi_master #(
        .INIT_DIV (SD_INIT_DIV),
        .RUN_DIV  (SD_RUN_DIV)
    ) u_sd (
        .clk      (clk),
        .rst_n    (rst_n),
        .cmd      (sd_cmd_r),
        .lba      (sd_lba_r),
        .status   (sd_status),
        .ack_done (sd_ack),
        .abort    (sd_abort),
        .spi_sck  (spi_sck),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso),
        .spi_cs_n (spi_cs_n),
        .buf_addr (sd_buf_addr),
        .buf_wdata(sd_buf_wdata),
        .buf_rdata(sbuf_rdata), // 1-cycle latency OK (SPI samples after addr settle)
        .buf_we   (sd_buf_we)
    );

    // ---- states ----------------------------------------------------------
    typedef enum logic [6:0] {
        S_IDLE=7'd0,
        S_FIN=7'd1,
        S_ERR=7'd2,
        S_SINK_END=7'd3,
        S_MW=7'd4,
        S_MR=7'd5,
        S_MRC=7'd6,
        S_BR=7'd7,
        S_BRC=7'd8,
        S_SD_WAIT=7'd9,
        S_SD_CLR=7'd10,
        S_SD_ABORT=7'd11,
        S_MNT0=7'd12,
        S_MNT1=7'd13,
        S_MNT2=7'd14,
        S_MNT2A=7'd15,
        S_MNT2B=7'd16,
        S_MNT2C=7'd17,
        S_MNT3=7'd18,
        S_MNT3G=7'd19,
        S_MNT3C=7'd20,
        S_NM_RD=7'd21,
        S_NM_CAP=7'd22,
        S_DS_START=7'd23,
        S_DS_BASE=7'd24,
        S_DS_SECT=7'd25,
        S_DS_ENT=7'd26,
        S_DS_LD=7'd27,
        S_DS_LDC=7'd28,
        S_DS_EVAL=7'd29,
        S_FG0=7'd30,
        S_FG1=7'd31,
        S_FG1A=7'd32,
        S_FG1B=7'd33,
        S_FS0=7'd34,
        S_FS1=7'd35,
        S_FS1B=7'd36,
        S_FS2=7'd37,
        S_FS3=7'd38,
        S_FS4=7'd39,
        S_AL0=7'd40,
        S_AL1=7'd41,
        S_AL1R=7'd42,
        S_AL1C=7'd43,
        S_AL1D=7'd44,
        S_AL2=7'd45,
        S_AL3=7'd46,
        S_FC0=7'd47,
        S_FC1=7'd48,
        S_FC2=7'd49,
        S_RB0=7'd50,
        S_RB0C=7'd51,
        S_RB1=7'd52,
        S_RBA0=7'd53,
        S_RBA1=7'd54,
        S_RBA1B=7'd55,
        S_GB0=7'd56,
        S_GB1=7'd57,
        S_RL0=7'd60,
        S_RL1=7'd61,
        S_RL2=7'd62,
        S_RF0=7'd63,
        S_RF1=7'd64,
        S_RF2=7'd65,
        S_RF3=7'd66,
        S_RF4=7'd67,
        S_RF5=7'd68,
        S_RF6=7'd69,
        S_CPY=7'd70,
        S_OP0=7'd71,
        S_OP1=7'd72,
        S_OP2=7'd73,
        S_OP3=7'd74,
        S_AP0=7'd75,
        S_AP1=7'd76,
        S_AP2=7'd77,
        S_AP3=7'd78,
        S_AP4=7'd79,
        S_AP5=7'd80,
        S_CL0=7'd81,
        S_CL1=7'd82,
        S_CL2=7'd83,
        S_CL3=7'd84,
        S_CL4=7'd85,
        S_CL4W=7'd86,
        S_CL5=7'd87,
        S_PUB=7'd88,
        S_DEL0=7'd89,
        S_DEL1=7'd90,
        S_DEL2=7'd91,
        S_DEL_RD=7'd92,
        S_DEL_PK=7'd93,
        S_DEL_WR=7'd94,
        S_DEL_FC=7'd95,
        S_DIR0=7'd96,
        S_DIR_N=7'd97,
        S_DIR_LD=7'd98,
        S_DIR_LDC=7'd99,
        S_DIR_EV=7'd100,
        S_DIR_FMT=7'd101,
        S_DIR_ADV=7'd102,
        S_DS_CHAIN=7'd103,
        S_APPEND_LOC=7'd104,
        S_APPEND_NEXT=7'd105,
        S_APPEND_SECTOR=7'd106,
        S_APPEND_READY=7'd107,
        S_RENAME_READ=7'd108,
        S_RENAME_PATCH=7'd109,
        S_RENAME_WRITE=7'd110,
        S_DIR_CHAIN=7'd111,
        S_DIR_CHAIN_LOADED=7'd112
    } state_t;

    state_t state;

    // 6-deep return stack (deepest path: open -> free chain -> fat set -> SD)
    logic [6:0] rstk [0:5];
    logic [2:0] rsp;

    // ---- geometry / volume ----------------------------------------------
    logic        mounted;
    logic [31:0] part_lba, fat_start, data_start, spf;
    logic [7:0]  spc, nfats;
    // log2(spc) — FAT32 spc is a power of two, so cluster→LBA math can
    // shift instead of DSP-multiply (the multiply broke board timing, WNS −3 ns)
    logic [2:0]  spc_shift;
    logic [31:0] root_clus;

    // ---- open channel ----------------------------------------------------
    logic [7:0]  mode_r, chan_r;
    logic [7:0]  name83 [0:10];
    logic [15:0] nm_addr;
    logic [7:0]  nm_len, nm_i, stem_i, ext_i;
    logic        in_ext;

    logic [31:0] f_first, f_size, f_pos;
    logic [31:0] append_remaining;
    assign file_size_o = f_size;
    assign dir_size_o={dent[31],dent[30],dent[29],dent[28]};
    assign dir_date_o={dent[25],dent[24]};
    assign dir_attr_o=dent[11];
    logic [31:0] cur_clus, data_lba, buf_lba;
    logic [31:0] lba_off;  // Pipeline (clus-2)<<spc then +data_start (WNS)
    logic [7:0]  sect_in_clus;
    logic [9:0]  rd_off;
    logic [9:0]  wr_idx;
    logic [31:0] dir_lba, slot_lba;
    logic [9:0]  dir_off, slot_off;
    logic        slot_ok, found_r;
    logic [31:0] ent_clus, ent_size;
    // public_flat_rd: sim-only STOR? probe (metacomment, no synthesis effect)
    logic        eof_r /*verilator public_flat_rd*/, err_r /*verilator public_flat_rd*/, done_r;
    // Bare OPEN "ADV01" retries .BAS/.DAT/.JMR/.TXT (matches FM resolve_storage_name)
    logic        bare_name;
    logic [2:0]  alt_try;

    // ---- line buffer -----------------------------------------------------
    // BRAM'd (was ~3k LUTs of comb-read muxing at the final
    // 189-slice placement gap). Writes go through one strobe; the parser
    // reads two registered ports (line_pos scans, i9 trim/copy) with a
    // 2-beat arm per step — INPUT#/DIR are cold paths.
    // Each byte is stored with its INPUT# class {comma, quote, blank}
    // (computed from the registered write byte), so the field scanner tests
    // RAM output bits instead of comparing the RAM output byte.
    (* ram_style = "block" *) logic [10:0] linebuf [0:255];
    logic [10:0] lb_pos_x, lb_i9_x;
    logic        lbw_we;
    logic [7:0]  lbw_wa;
    logic [7:0]  lbw_wd;
    wire  [10:0] lbw_wcls = {lbw_wd == 8'h2C, lbw_wd == 8'h22,
                             lbw_wd == 8'h20 || lbw_wd == 8'h09, lbw_wd};
    wire  [7:0]  lb_pos_q = lb_pos_x[7:0];
    wire  [7:0]  lb_i9_q  = lb_i9_x[7:0];
    wire         lb_pos_blank = lb_pos_x[8], lb_pos_quote = lb_pos_x[9];
    wire         lb_pos_comma = lb_pos_x[10], lb_i9_blank = lb_i9_x[8];
    logic [8:0]  lb_i9_addr;
    logic        lb_arm;
    logic        dirfmt_l;
    always_comb lb_i9_addr = (state == S_CPY) ? (fld_off + cpy_i)
                                              : (fld_off + fld_len - 9'd1);
    logic [8:0]  line_n;     // bytes in linebuf
    logic [8:0]  line_pos;   // INPUT# cursor within linebuf
    logic [8:0]  fld_off, fld_len;
    logic [8:0]  cpy_i;

    // ---- scratch ---------------------------------------------------------
    logic [15:0] maddr;
    logic [7:0]  mdata, mbyte;
    logic [7:0]  rb_byte, app_byte;
    logic [31:0] ds_clus, ds_lba;
    logic [7:0]  ds_sect;
    logic [9:0]  ds_off;
    logic [31:0] fg_clus, fat_val, fg_lba;
    // Classification of fat_val, registered where fat_val is loaded (its
    // only writer, S_FG1B): the cluster-chain states test flags, not 32-bit
    // compares. fat_eq_ds compares against ds_clus, which no S_FG*/S_BR*
    // state writes, so it is still current in S_DIR_CHAIN.
    logic        fat_lt2, fat_eoc, fat_rsv, fat_eq_ds;
    logic [31:0] fs_clus, fs_val, fs_lba;
    logic [7:0]  fs_i, fs_bi;
    logic [31:0] al_clus, al_prev, al_lba, al_guard;
    logic [31:0] fc_clus, fc_next, fc_guard;
    // Dir-scan chain guard. First-light board lesson: DIR
    // and LOAD wedged forever with busy high — a FAT entry read off the
    // real card can point back into the valid cluster range and form a
    // cycle, which the well-formed sim card image can never produce.
    // S_FC0 already had fc_guard; the S_DS_CHAIN walk had no bound.
    logic [15:0] ds_guard;
    // Timing: the cluster->LBA arithmetic
    // fed sd_lba_r/buf_lba in one beat (DSP product + barrel shift + two
    // 32-bit adds; l1 DSP -> sd_lba_r -0.727, ds_clus -> buf_lba 16
    // levels). Same recipe as the S_RBA1/S_RBA1B split: one settle beat.
    // ds_base is per-cluster loop-invariant across the sector walk.
    logic [31:0] ds_base;
    logic [31:0] fs_pre;
    // Op watchdog (board directive: a storage stall must never
    // freeze the machine with no escape). Storage returns to S_IDLE
    // between DIR pages — the console strobes the next step only when
    // !busy — so every busy episode is pure SD/FAT work with no user
    // pacing. Any single episode over ~21 s (2^31 clks) forces S_ERR,
    // whose existing cleanup (done_r + err_r + poison) unblocks the
    // console through the normal ?IO path.
    logic [31:0] op_wd;
    // First-write retry. An SD command that times out (S_SD_ABORT, ~1.3 s)
    // or returns an SPI error used to fail the operation and unmount the
    // card, so the first save after a long idle could fail while the next
    // one, which remounts, succeeded. An OPEN, DELETE or DIR that fails that
    // way before it has written any sector now remounts and runs once more
    // from its start; only a second failure reaches the caller.
    logic [1:0]  op_kind;    // 0 not restartable, 1 OPEN, 2 DELETE, 3 DIR
    logic [7:0]  op_mode0;   // OPEN mode as accepted (append rewrites mode_r)
    logic        op_wrote;   // a sector write was issued during this op
    logic        op_retried;
    logic        sd_fail;    // the op saw an SD timeout or SPI error
    wire         op_retry_ok = sd_fail && !op_retried && !op_wrote && op_kind != 2'd0;
    logic        cp_q;
    logic [9:0]  pad_i;
    logic [5:0]  ent_i;
    logic [4:0]  pub_i;
    logic        sink_busy_r;
    // 0 = LINE INPUT# consumer, 1 = INPUT# field scanner refill
    logic        rl_field;
    logic        cl_data_done; // CLOSE data-sector flush latch
    logic        cat_on /*verilator public_flat_rd*/;
    logic        cat_all; // latched at start_dir: 1 = DIR *
    logic cat_system;
    logic cat_raw;
`ifdef VERILATOR
    integer dirtrace_fd = 0;
    state_t dirtrace_last;
    logic [31:0] trace_cyc = 0;
`endif       // DIR catalog scan active
    logic        dir_yield;    // S_DIR_ADV should S_CPY after advancing


    // Command boundary register. The requester mux in jmr_js_core (Finder
    // file services / Toolbox / console) and this module's dispatch chain
    // were one 12-level path. Each strobe and the arguments sampled with it
    // land here first. busy includes the registered strobe, so it still
    // rises on the clock after the requester's strobe, exactly as before;
    // the operation itself (and done) is one clock later. The print sink
    // (sink_wr_en) is not staged: it is tied off in jmr_js_core.
    logic        start_open, start_close, start_readline, start_readfield;
    logic        start_get_byte, start_putc, start_dir, start_dir_next;
    logic        start_delete, start_rename;
    logic [7:0]  mode_in, chan_in, name_len, putc_data;
    logic [15:0] name_addr;
    logic        dir_show_all, dir_show_system, dir_raw_names;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            start_open <= 1'b0; start_close <= 1'b0; start_readline <= 1'b0;
            start_readfield <= 1'b0; start_get_byte <= 1'b0; start_putc <= 1'b0;
            start_dir <= 1'b0; start_dir_next <= 1'b0; start_delete <= 1'b0;
            start_rename <= 1'b0;
        end else begin
            start_open <= start_open_i; start_close <= start_close_i;
            start_readline <= start_readline_i; start_readfield <= start_readfield_i;
            start_get_byte <= start_get_byte_i; start_putc <= start_putc_i;
            start_dir <= start_dir_i; start_dir_next <= start_dir_next_i;
            start_delete <= start_delete_i; start_rename <= start_rename_i;
        end
        mode_in <= mode_in_i; chan_in <= chan_in_i;
        name_addr <= name_addr_i; name_len <= name_len_i;
        putc_data <= putc_data_i;
        dir_show_all <= dir_show_all_i; dir_show_system <= dir_show_system_i;
        dir_raw_names <= dir_raw_names_i;
    end
    wire cmd_pending = start_open || start_close || start_readline || start_readfield
        || start_get_byte || start_putc || start_dir || start_dir_next
        || start_delete || start_rename;
    assign busy      = (state != S_IDLE) || cmd_pending;
    // Instrument: how long each storage op takes, in 256-clock units,
    // saturating. Rides the E-line so the flight log can split LOAD/COMPILE
    // time into SD-sector time vs per-byte handshakes before anyone builds
    // a burst path. Reset when a new op is accepted (S_IDLE with a start).
    logic [23:0] op_clk_r;
    assign dbg_op_clk = op_clk_r[23:8];
    always_ff @(posedge clk) begin
        if (!rst_n) op_clk_r <= 24'd0;
        else if (state == S_IDLE) begin
            if (start_open || start_close || start_readline || start_readfield || start_get_byte
                || start_putc || start_dir || start_dir_next || start_delete)
                op_clk_r <= 24'd0;
        end else if (!(&op_clk_r)) op_clk_r <= op_clk_r + 24'd1;
    end
    assign dbg_state = state;
    assign done      = done_r;
    assign eof       = eof_r;
    assign err       = err_r;
    assign line_len  = fld_len[7:0];
    assign sink_busy = sink_busy_r;
    // Expose last S_RB0C byte for PATCH.BIN / binary readers
    assign get_byte  = rb_byte;


    // ---- helpers ---------------------------------------------------------
    function automatic logic [7:0] upcase(input logic [7:0] c);
        upcase = (c >= 8'h61 && c <= 8'h7A) ? (c - 8'h20) : c;
    endfunction

    // Name/attr compare against dent[] window (filled via S_DS_LD*)
    // The 11-byte compare fed the S_DS_EVAL state decode
    // combinationally (dent -> state, 11 logic levels, -0.208 ns).
    // dent[0..10] are written >=21 beats before EVAL (bytes 11..31 load
    // after them), so a free-running register costs zero beats and takes
    // the 88-bit AND out of the dispatch cone (the 7f4f113 recipe).
    wire name_hit = (dent[0]  == name83[0])  && (dent[1]  == name83[1])
                 && (dent[2]  == name83[2])  && (dent[3]  == name83[3])
                 && (dent[4]  == name83[4])  && (dent[5]  == name83[5])
                 && (dent[6]  == name83[6])  && (dent[7]  == name83[7])
                 && (dent[8]  == name83[8])  && (dent[9]  == name83[9])
                 && (dent[10] == name83[10]);
    logic name_hit_q;
    always_ff @(posedge clk) name_hit_q <= name_hit;
    wire [7:0] ds_attr = dent[11];
    // S_DIR_FMT reads dent[dent_i] only for dent_i 0..7 and dent[dent_i-1]
    // only for dent_i 9..11: narrow muxes instead of 32:1 reads of dent[].
    wire [7:0] fmt_stem_ch = dent[{2'b00, dent_i[2:0]}];
    wire [7:0] fmt_ext_ch  = (dent_i[1:0] == 2'd1) ? dent[8]
                           : (dent_i[1:0] == 2'd2) ? dent[9] : dent[10];
    wire       fmt_ext_nb  = fmt_ext_ch != 8'h20;
    // DIR always hides machine programs (PYTHON _SYSTEM_STEMS). DIR * still
    // skips these; it only adds .JSH/.ART for titles.
    wire dent_sys = (dent[0]=="E" && dent[1]=="D" && dent[2]=="I" && dent[3]=="T"
                  && dent[4]=="O" && dent[5]=="R" && dent[6]==8'h20 && dent[7]==8'h20)
                 || (dent[0]=="C" && dent[1]=="O" && dent[2]=="M" && dent[3]=="P"
                  && dent[4]=="I" && dent[5]=="L" && dent[6]=="E" && dent[7]=="R")
                 || (dent[0]=="A" && dent[1]=="R" && dent[2]=="T" && dent[3]=="S"
                  && dent[4]=="C" && dent[5]=="A" && dent[6]=="N" && dent[7]==8'h20)
                 || (dent[0]=="A" && dent[1]=="R" && dent[2]=="T" && dent[3]=="P"
                  && dent[4]=="N" && dent[5]=="G" && dent[6]==8'h20 && dent[7]==8'h20)
                 || (dent[0]=="C" && dent[1]=="O" && dent[2]=="M" && dent[3]=="P"
                  && dent[4]=="I" && dent[5]=="L" && dent[6]=="2" && dent[7]==8'h20)
                 || (dent[0]=="M" && dent[1]=="I" && dent[2]=="N" && dent[3]=="T"
                  && dent[4]=="A" && dent[5]=="S" && dent[6]=="M" && dent[7]==8'h20)
                 || (dent[0]=="R" && dent[1]=="E" && dent[2]=="A" && dent[3]=="D"
                  && dent[4]==8'h20 && dent[5]==8'h20 && dent[6]==8'h20 && dent[7]==8'h20) || (dent[0]=="F" && dent[1]=="I" && dent[2]=="N" && dent[3]=="D"
                  && dent[4]=="E" && dent[5]=="R" && dent[6]==8'h20 && dent[7]==8'h20);

    // FAT entry byte offset inside its sector
    wire [9:0] fg_off = {fg_clus[6:0], 2'b00};
    wire [9:0] fs_off = {fs_clus[6:0], 2'b00};
    wire [9:0] al_off = {al_clus[6:0], 2'b00};

    // Directory entry byte for CLOSE (32-byte record, dates left zero)
    function automatic logic [7:0] ent_byte(input logic [5:0] i,
                                            input logic [31:0] fc,
                                            input logic [31:0] sz);
        unique case (i)
            6'd0:  ent_byte = name83[0];
            6'd1:  ent_byte = name83[1];
            6'd2:  ent_byte = name83[2];
            6'd3:  ent_byte = name83[3];
            6'd4:  ent_byte = name83[4];
            6'd5:  ent_byte = name83[5];
            6'd6:  ent_byte = name83[6];
            6'd7:  ent_byte = name83[7];
            6'd8:  ent_byte = name83[8];
            6'd9:  ent_byte = name83[9];
            6'd10: ent_byte = name83[10];
            6'd11: ent_byte = 8'h20;              // ATTR_ARCHIVE
            6'd20: ent_byte = fc[23:16];
            6'd21: ent_byte = fc[31:24];
            6'd26: ent_byte = fc[7:0];
            6'd27: ent_byte = fc[15:8];
            6'd28: ent_byte = sz[7:0];
            6'd29: ent_byte = sz[15:8];
            6'd30: ent_byte = sz[23:16];
            6'd31: ent_byte = sz[31:24];
            default: ent_byte = 8'h00;
        endcase
    endfunction

    // FAT value byte for the 4-byte entry patch
    function automatic logic [7:0] fs_val_byte(input logic [7:0] i);
        unique case (i[1:0])
            2'd0: fs_val_byte = fs_val[7:0];
            2'd1: fs_val_byte = fs_val[15:8];
            2'd2: fs_val_byte = fs_val[23:16];
            default: fs_val_byte = fs_val[31:24];
        endcase
    endfunction

    // Channel-register publish table
    logic [15:0] pub_addr;
    logic [7:0]  pub_data;
    wire  [15:0] pub_off = f_pos[15:0] | ((mode_r == 8'h4F) ? f_size[15:0] : 16'h0);
    always_comb begin
        pub_addr = 16'h0;
        pub_data = 8'h0;
        unique case (pub_i)
            5'd0: begin pub_addr = IO_STORAGE_STATUS;
                        pub_data = {5'b0, (mode_r != 8'h0), err_r, busy}; end
            // bit0 = busy (matches memory_map IO_STORAGE_STATUS / GUI light)
            5'd1: begin pub_addr = IO_SEQ_MODE;      pub_data = mode_r; end
            5'd2: begin pub_addr = IO_SEQ_CHANNEL;   pub_data = (mode_r != 8'h0) ? chan_r : 8'h0; end
            5'd3: begin pub_addr = IO_SEQ_OFFSET_LO; pub_data = pub_off[7:0]; end
            5'd4: begin pub_addr = IO_SEQ_OFFSET_HI; pub_data = pub_off[15:8]; end
            default: begin
                pub_addr = IO_SEQ_NAME + {11'h0, (pub_i - 5'd5)};
                pub_data = (mode_r == 8'h0 || pub_i > 5'd15) ? 8'h00
                                                             : name83[pub_i - 5'd5];
            end
        endcase
    end

    // ---- combinational memory / sector-buffer ports ----------------------
    always_comb begin
        mem_en    = 1'b0;
        mem_we    = 1'b0;
        mem_addr  = 16'h0;
        mem_wdata = 8'h0;
        if (state == S_MW) begin
            mem_en = 1'b1; mem_we = 1'b1; mem_addr = maddr; mem_wdata = mdata;
        end else if (state == S_MR) begin
            mem_en = 1'b1; mem_addr = maddr;
        end
    end

    always_comb begin
        fs_buf_we    = 1'b0;
        fs_buf_addr  = 9'h0;
        fs_buf_wdata = 8'h0;
        unique case (state)
            S_AP2: begin
                fs_buf_we = 1'b1; fs_buf_addr = wr_idx[8:0]; fs_buf_wdata = app_byte;
            end
            S_FS2: begin
                fs_buf_we = 1'b1; fs_buf_addr = fs_off[8:0] + {7'h0, fs_bi[1:0]};
                fs_buf_wdata = fs_val_byte(fs_bi);
            end
            S_CL2: begin
                fs_buf_we = 1'b1; fs_buf_addr = pad_i[8:0]; fs_buf_wdata = 8'h00;
            end
            S_CL4: begin
                fs_buf_we = 1'b1; fs_buf_addr = dir_off[8:0] + {3'h0, ent_i};
                fs_buf_wdata = ent_byte(ent_i, f_first, f_size);
            end
            // REMOVE — poke dirent[0]=0xE5
            S_RENAME_PATCH: begin
                fs_buf_we=1;fs_buf_addr=dir_off[8:0]+{3'd0,ent_i};fs_buf_wdata=name83[ent_i];
            end
            S_DEL_PK: begin
                fs_buf_we = 1'b1; fs_buf_addr = dir_off[8:0]; fs_buf_wdata = 8'hE5;
            end
            default: ;
        endcase
    end

    // ---- main FSM --------------------------------------------------------
    task automatic push_call(input logic [6:0] nxt, input logic [6:0] ret);
        begin
            rstk[rsp] <= ret;
            rsp        <= rsp + 3'd1;
            state      <= state_t'(nxt);
        end
    endtask

    task automatic pop_ret;
        begin
            rsp   <= rsp - 3'd1;
            state <= state_t'(rstk[rsp - 3'd1]);
        end
    endtask

    // Issue one SPI command (1=init, 2=read, 3=write) then return to `ret`
    task automatic sd_go(input logic [7:0] c, input logic [31:0] l,
                         input logic [6:0] ret);
        begin
            sd_cmd_r <= c;
            sd_lba_r <= l;
            push_call(S_SD_WAIT, ret);
        end
    endtask

    // Run the accepted OPEN/DELETE/DIR again from its start on a remounted
    // card (see op_retry_ok). The call stack restarts empty.
    task automatic retry_op;
        begin
            op_retried <= 1'b1; sd_fail <= 1'b0;
            mounted <= 1'b0; err_r <= 1'b0; eof_r <= 1'b0; not_found_o <= 1'b0;
            buf_lba <= 32'hFFFFFFFF;
            nm_i <= 8'h0; stem_i <= 8'h0; ext_i <= 8'h0; in_ext <= 1'b0;
            al_prev <= 32'h0; alt_try <= 3'd0; bare_name <= 1'b1;
            for (int k = 0; k < 11; k++) name83[k] <= 8'h20;
            rsp <= 3'd1;
            if (op_kind == 2'd3) begin
                fld_len <= 9'h0; cat_on <= 1'b1;
                rstk[0] <= S_DIR0; state <= S_MNT0;
            end else begin
                if (op_kind == 2'd1) mode_r <= op_mode0;
                rstk[0] <= (op_kind == 2'd1) ? S_OP0 : S_DEL0;
                state <= S_NM_RD;
            end
        end
    endtask

    // Synchronous reset so linebuf[] can infer as RAM (Synth 8-4767 —
    // async reset in the sensitivity list blocks inference). name83[] is still
    // reset below and stays registers, which is fine at 11 bytes.
    always_ff @(posedge clk) begin
        if (lbw_we) linebuf[lbw_wa] <= lbw_wcls;
        lb_pos_x <= linebuf[line_pos[7:0]];
        lb_i9_x  <= linebuf[lb_i9_addr[7:0]];
    end
    always_ff @(posedge clk) begin
        logic [8:0] i9;
        if (!rst_n) begin
            state <= S_IDLE;
            lbw_we <= 1'b0; lb_arm <= 1'b0; dirfmt_l <= 1'b0;
            rsp <= 3'd0;
            sd_cmd_r <= 8'h0;
            sd_wd <= 27'd0; sd_abort <= 1'b0;
            sd_lba_r <= 32'h0;
            mounted <= 1'b0;
            part_lba <= 32'h0; fat_start <= 32'h0; data_start <= 32'h0;
            spf <= 32'h0; spc <= 8'h0; spc_shift <= 3'd0; nfats <= 8'h0; root_clus <= 32'h2;
            mode_r <= 8'h0; chan_r <= 8'h0;not_found_o<=0;append_remaining<=0;
            for (int k = 0; k < 11; k++) name83[k] <= 8'h20;
            nm_addr <= 16'h0; nm_len <= 8'h0; nm_i <= 8'h0;
            stem_i <= 8'h0; ext_i <= 8'h0; in_ext <= 1'b0;
            f_first <= 32'h0; f_size <= 32'h0; f_pos <= 32'h0;
            cur_clus <= 32'h0; data_lba <= 32'h0; buf_lba <= 32'hFFFFFFFF;
            lba_off <= 32'h0;
            sect_in_clus <= 8'h0; rd_off <= 10'h0; wr_idx <= 10'h0;
            dir_lba <= 32'h0; slot_lba <= 32'h0; dir_off <= 10'h0; slot_off <= 10'h0;
            slot_ok <= 1'b0; found_r <= 1'b0;
            ent_clus <= 32'h0; ent_size <= 32'h0;
            eof_r <= 1'b0; err_r <= 1'b0; done_r <= 1'b0;

            bare_name <= 1'b0; alt_try <= 3'd0;
            cat_on <= 1'b0; cat_all <= 1'b0; cat_system <= 1'b0; cat_raw <= 1'b0; dir_yield <= 1'b0;
            line_n <= 9'h0; line_pos <= 9'h0; fld_off <= 9'h0; fld_len <= 9'h0;
            cpy_i <= 9'h0;
            maddr <= 16'h0; mdata <= 8'h0; mbyte <= 8'h0;
            rb_byte <= 8'h0; app_byte <= 8'h0;
            fs_rd_addr <= 9'h0; br_byte <= 8'h0; br_i <= 5'h0; br_acc <= 32'h0;
            dent_i <= 5'h0; mnt_phase <= 4'h0; reserved_sect <= 16'h0;
            for (int k = 0; k < 32; k++) dent[k] <= 8'h0;
            ds_clus <= 32'h0; ds_lba <= 32'h0; ds_sect <= 8'h0; ds_off <= 10'h0;
            fg_clus <= 32'h0; fat_val <= 32'h0; fg_lba <= 32'h0;
            fat_lt2 <= 1'b1; fat_eoc <= 1'b0; fat_rsv <= 1'b0; fat_eq_ds <= 1'b1;
            fs_clus <= 32'h0; fs_val <= 32'h0; fs_lba <= 32'h0;
            fs_i <= 8'h0; fs_bi <= 8'h0;
            al_clus <= 32'h0; al_prev <= 32'h0; al_lba <= 32'h0; al_guard <= 32'h0;
            fc_clus <= 32'h0; fc_next <= 32'h0; fc_guard <= 32'h0;
            ds_guard <= 16'h0;
            ds_base <= 32'h0; fs_pre <= 32'h0;
            op_wd <= 32'h0;
            op_kind <= 2'd0; op_mode0 <= 8'h0; op_wrote <= 1'b0; op_retried <= 1'b0; sd_fail <= 1'b0;
            pad_i <= 10'h0; ent_i <= 6'h0; pub_i <= 5'h0;
            sink_busy_r <= 1'b0;
            rl_field <= 1'b0;
            cl_data_done <= 1'b0; // CLOSE flushes data sector once
        end else begin
            lbw_we <= 1'b0;
            done_r <= 1'b0;

            unique case (state)
                // ---------------- command dispatch ------------------------
                S_IDLE: begin
                    if(start_open || start_dir || start_dir_next || start_delete || start_rename)not_found_o<=0;
                    sink_busy_r <= 1'b0;
                    rsp <= 3'd0; // clean slate per op: no cross-op stack drift
                    if (cmd_pending || sink_wr_en) begin
                        op_wrote <= 1'b0; op_retried <= 1'b0; sd_fail <= 1'b0;
                        op_mode0 <= mode_in;
                        op_kind <= start_open ? 2'd1
                                 : (start_close || start_readline || start_readfield || start_get_byte
                                    || start_putc || sink_wr_en) ? 2'd0
                                 : start_dir ? 2'd3
                                 : (start_dir_next || start_rename) ? 2'd0
                                 : start_delete ? 2'd2 : 2'd0;
                    end

                    if (start_open) begin
                        mode_r  <= mode_in;
                        chan_r  <= chan_in;
                        nm_addr <= name_addr;
                        nm_len  <= name_len;
                        nm_i    <= 8'h0;
                        stem_i  <= 8'h0;
                        ext_i   <= 8'h0;
                        al_prev <= 32'h0; // Don't link a stale cluster on first alloc
                        in_ext  <= 1'b0;
                        err_r   <= 1'b0;
                        eof_r   <= 1'b0;
                        bare_name <= 1'b1;   // cleared if name contains '.'
                        alt_try   <= 3'd0;
                        for (int k = 0; k < 11; k++) name83[k] <= 8'h20;
                        push_call(S_NM_RD, S_OP0);
                    end else if (start_close) begin
                        state <= S_CL0;
                    end else if (start_readline) begin
                        // Clear sticky SPI err so LINE INPUT# matches OPEN
                        eof_r    <= 1'b0;
                        err_r    <= 1'b0;
                        line_n   <= 9'h0;
                        rl_field <= 1'b0;   // plain LINE INPUT#
                        state    <= S_RL0;
                    end else if (start_readfield) begin
                        eof_r <= 1'b0;
                        err_r <= 1'b0; // Same sticky-err hygiene as readline
                        state <= S_RF0;
                    end else if (start_get_byte) begin
                        // One raw file byte (PATCH.BIN boot); eof if past end
                        eof_r <= 1'b0;
                        err_r <= 1'b0;
                        state <= S_GB0;
                    end else if (start_putc) begin
                        app_byte <= putc_data;
                        push_call(S_AP0, S_FIN);
                    end else if (sink_wr_en) begin
                        app_byte    <= sink_wr_char;
                        sink_busy_r <= 1'b1;
                        push_call(S_AP0, S_SINK_END);
                    // DIR — always remount (hot-swap µSD without reset)
                    end else if (start_dir) begin
                        err_r <= 1'b0; eof_r <= 1'b0; fld_len <= 9'h0;
                        cat_on <= 1'b1;
                        cat_all <= dir_show_all;
                        cat_system <= dir_show_system;
                        cat_raw <= dir_raw_names;
                        // No forced remount. DIR was the ONLY
                        // command that re-initialized a live card (its board
                        // wedge slice); hot-swap is handled by card_present
                        // clearing `mounted` below, same as an SPI error.
                        // The remount is now CONDITIONAL, matching
                        // start_open (:1246) and S_DEL0 (:1423). 86011a9 removed
                        // `mounted <= 1'b0` but left this push_call unconditional,
                        // so DIR still re-ran full SPI init on a live card.
                        if (!mounted) push_call(S_MNT0, S_DIR0);
                        else state <= S_DIR0;
                    end else if (start_dir_next) begin
                        err_r <= 1'b0; eof_r <= 1'b0; fld_len <= 9'h0;
                        if (!cat_on) begin
                            eof_r <= 1'b1;
                            state <= S_FIN;
                        end else state <= S_DIR_N;
                    end else if (start_rename) begin
                        if(mode_r!=8'h49)state<=S_ERR;
                        else begin
                            nm_addr<=name_addr;nm_len<=name_len;nm_i<=0;stem_i<=0;ext_i<=0;in_ext<=0;
                            err_r<=0;eof_r<=0;bare_name<=0;
                            for(int k=0;k<11;k++)name83[k]<=8'h20;
                            push_call(S_NM_RD,S_RENAME_READ);
                        end
                    end else if (start_delete) begin
                        nm_addr <= name_addr; nm_len <= name_len;
                        nm_i <= 8'h0; stem_i <= 8'h0; ext_i <= 8'h0; in_ext <= 1'b0;
                        err_r <= 1'b0; eof_r <= 1'b0;
                        bare_name <= 1'b1; alt_try <= 3'd0;
                        for (int k = 0; k < 11; k++) name83[k] <= 8'h20;
                        push_call(S_NM_RD, S_DEL0);
                    end
                end

                S_FIN: if (err_r && op_retry_ok) retry_op();
                else begin
                    done_r <= 1'b1;
                    state  <= S_IDLE;
                end

                S_ERR: if (op_retry_ok) retry_op();
                else begin
                    // Clear mode so a failed OPEN cannot leave LINE INPUT# spinning
                    err_r  <= 1'b1;
                    done_r <= 1'b1;
                    mode_r <= 8'h0;
                    mounted <= 1'b0; // Poison mount — next DIR/LOAD remounts
                    rsp    <= 3'd0;
                    state  <= S_IDLE;
                end

                // Sink writes never pulse `done` — the print engine owns that
                // hand-shake through sink_busy.
                S_SINK_END: begin
                    sink_busy_r <= 1'b0;
                    state       <= S_IDLE;
                end

                // ---------------- RAM helpers -----------------------------
                S_MW:  if (mem_gnt) pop_ret();
                S_MR:  if (mem_gnt) state <= S_MRC;
                S_MRC: begin
                    mbyte <= mem_rdata;
                    pop_ret();
                end
                // Sbuf BRAM read — addr already on fs_rd_addr; +1 cycle then capture
                S_BR:  state <= S_BRC;
                S_BRC: begin
                    br_byte <= sbuf_rdata;
                    pop_ret();
                end

                // ---------------- SPI command completion ------------------
                S_SD_WAIT: begin
                if (sd_cmd_r == 8'd3) op_wrote <= 1'b1;
                if (sd_ack) begin
                    sd_wd    <= 27'd0;
                    sd_cmd_r <= 8'h0;
                    state    <= S_SD_CLR;
                end else if (&sd_wd) begin
                    // Watchdog (~1.3 s at 100 MHz): the card never
                    // answered. Board: a SAVE sat here 85 s and
                    // a DIR wedged until power-cycle. Abort the SPI master,
                    // poison the mount, fail the op loud (?IO) — never wait
                    // forever again.
                    sd_wd    <= 27'd0;
                    sd_abort <= 1'b1;
                    sd_cmd_r <= 8'h0;
                    state    <= S_SD_ABORT;
                end else sd_wd <= sd_wd + 27'd1;
                end
                S_SD_ABORT: begin
                    sd_abort <= 1'b0;
                    sd_fail  <= 1'b1;
                    mounted  <= 1'b0;
                    state    <= S_ERR;
                end
                S_SD_CLR: begin
                    if (sd_status[2]) begin
                        err_r <= 1'b1;
                        sd_fail <= 1'b1;
                        mounted <= 1'b0; // SPI fail → remount next time
                    end
                    pop_ret();
                end

                // ---------------- mount -----------------------------------
                S_MNT0: sd_go(8'd1, 32'h0, S_MNT1);
                S_MNT1: sd_go(8'd2, 32'h0, S_MNT2);
                // BRAM — gather MBR type byte then optional LBA
                S_MNT2: begin
                    buf_lba    <= 32'h0;
                    fs_rd_addr <= 9'd450;
                    push_call(S_BR, S_MNT2A);
                end
                S_MNT2A: begin
                    if (br_byte == 8'h0B || br_byte == 8'h0C || br_byte == 8'h0E) begin
                        br_i   <= 5'd0;
                        br_acc <= 32'h0;
                        state  <= S_MNT2B;
                    end else begin
                        part_lba <= 32'h0;                 // superfloppy
                        sd_go(8'd2, 32'h0, S_MNT3);
                    end
                end
                S_MNT2B: begin
                    fs_rd_addr <= 9'd454 + {5'h0, br_i[3:0]};
                    push_call(S_BR, S_MNT2C);
                end
                S_MNT2C: begin
                    // LE32 partition LBA at MBR +454
                    unique case (br_i[1:0])
                        2'd0: br_acc <= {24'h0, br_byte};
                        2'd1: br_acc <= {16'h0, br_byte, br_acc[7:0]};
                        2'd2: br_acc <= {8'h0, br_byte, br_acc[15:0]};
                        2'd3: begin
                            part_lba <= {br_byte, br_acc[23:0]};
                            sd_go(8'd2, {br_byte, br_acc[23:0]}, S_MNT3);
                        end
                    endcase
                    if (br_i < 5'd3) begin
                        br_i  <= br_i + 5'd1;
                        state <= S_MNT2B;
                    end
                end
                S_MNT3: begin
                    mnt_phase <= 4'd0;
                    state     <= S_MNT3G;
                end
                S_MNT3G: begin
                    // phases: 0=spc@13 1..2=reserved@14-15 3=nfats@16
                    // 4..7=spf@36-39  8..11=root_clus@44-47
                    unique case (mnt_phase)
                        4'd0:  fs_rd_addr <= 9'd13;
                        4'd1:  fs_rd_addr <= 9'd14;
                        4'd2:  fs_rd_addr <= 9'd15;
                        4'd3:  fs_rd_addr <= 9'd16;
                        4'd4:  fs_rd_addr <= 9'd36;
                        4'd5:  fs_rd_addr <= 9'd37;
                        4'd6:  fs_rd_addr <= 9'd38;
                        4'd7:  fs_rd_addr <= 9'd39;
                        4'd8:  fs_rd_addr <= 9'd44;
                        4'd9:  fs_rd_addr <= 9'd45;
                        4'd10: fs_rd_addr <= 9'd46;
                        default: fs_rd_addr <= 9'd47;
                    endcase
                    push_call(S_BR, S_MNT3C);
                end
                S_MNT3C: begin
                    unique case (mnt_phase)
                        // Also latch log2(spc) — FAT32 spc is a power of
                        // two; shift replaces the timing-breaking DSP multiply
                        4'd0:  begin
                            spc <= br_byte;
                            unique casez (br_byte)
                                8'b1???????: spc_shift <= 3'd7;
                                8'b01??????: spc_shift <= 3'd6;
                                8'b001?????: spc_shift <= 3'd5;
                                8'b0001????: spc_shift <= 3'd4;
                                8'b00001???: spc_shift <= 3'd3;
                                8'b000001??: spc_shift <= 3'd2;
                                8'b0000001?: spc_shift <= 3'd1;
                                default:     spc_shift <= 3'd0;
                            endcase
                        end
                        4'd1:  reserved_sect[7:0]  <= br_byte;
                        4'd2:  reserved_sect[15:8] <= br_byte;
                        4'd3:  nfats <= br_byte;
                        4'd4:  br_acc[7:0]   <= br_byte;
                        4'd5:  br_acc[15:8]  <= br_byte;
                        4'd6:  br_acc[23:16] <= br_byte;
                        4'd7:  spf <= {br_byte, br_acc[23:16], br_acc[15:8], br_acc[7:0]};
                        4'd8:  br_acc[7:0]   <= br_byte;
                        4'd9:  br_acc[15:8]  <= br_byte;
                        4'd10: br_acc[23:16] <= br_byte;
                        4'd11: begin
                            root_clus  <= {br_byte, br_acc[23:16], br_acc[15:8], br_acc[7:0]};
                            fat_start  <= part_lba + {16'h0, reserved_sect};
                            data_start <= part_lba + {16'h0, reserved_sect}
                                        + {24'h0, nfats} * spf;
                            buf_lba    <= part_lba;
                            mounted    <= 1'b1;
                            pop_ret();
                        end
                        default: ;
                    endcase
                    if (mnt_phase < 4'd11) begin
                        mnt_phase <= mnt_phase + 4'd1;
                        state     <= S_MNT3G;
                    end
                end

                // ---------------- 8.3 name fetch --------------------------
                S_NM_RD: begin
                    maddr <= nm_addr + {8'h0, nm_i};
                    push_call(S_MR, S_NM_CAP);
                end
                S_NM_CAP: begin
                    if (mbyte == 8'h2E) begin
                        in_ext    <= 1'b1;
                        bare_name <= 1'b0;   // Explicit extension present
                        ext_i     <= 8'h0;
                    end else if (!in_ext) begin
                        if (stem_i < 8'd8) name83[stem_i[3:0]] <= upcase(mbyte);
                        stem_i <= stem_i + 8'd1;
                    end else begin
                        if (ext_i < 8'd3) name83[4'd8 + ext_i[1:0]] <= upcase(mbyte);
                        ext_i <= ext_i + 8'd1;
                    end
                    // Do NOT invent .BAS here — OPEN path applies FM suffixes
                    if (nm_i + 8'd1 >= nm_len) pop_ret();
                    else begin
                        nm_i  <= nm_i + 8'd1;
                        state <= S_NM_RD;
                    end
                end

                // ---------------- root directory scan ---------------------
                S_DS_START: begin
                    ds_clus <= root_clus;
                    ds_sect <= 8'h0;
                    ds_guard <= 16'h0;
                    found_r <= 1'b0;
                    slot_ok <= 1'b0;
                    state   <= S_DS_BASE;
                end
                S_DS_BASE: begin
                    ds_base <= data_start + ((ds_clus - 32'd2) << spc_shift);
                    state   <= S_DS_SECT;
                end
                S_DS_SECT: begin
                    ds_off  <= 10'h0;
                    ds_lba  <= ds_base + {24'h0, ds_sect};
                    buf_lba <= ds_base + {24'h0, ds_sect};
                    sd_go(8'd2, ds_base + {24'h0, ds_sect}, S_DS_ENT);
                end
                // Load 32-byte dirent into dent[] via BRAM, then evaluate
                S_DS_ENT: begin
                    dent_i <= 5'd0;
                    state  <= S_DS_LD;
                end
                S_DS_LD: begin
                    fs_rd_addr <= ds_off[8:0] + {4'h0, dent_i};
                    push_call(S_BR, S_DS_LDC);
                end
                S_DS_LDC: begin
                    dent[dent_i] <= br_byte;
                    if (dent_i >= 5'd31) state <= S_DS_EVAL;
                    else begin
                        dent_i <= dent_i + 5'd1;
                        state  <= S_DS_LD;
                    end
                end
                S_DS_EVAL: begin
                    if (dent[0] == 8'h00) begin
                        if (!slot_ok) begin
                            slot_ok  <= 1'b1;
                            slot_lba <= ds_lba;
                            slot_off <= ds_off;
                        end
                        pop_ret();
                    end else if (dent[0] == 8'hE5) begin
                        if (!slot_ok) begin
                            slot_ok  <= 1'b1;
                            slot_lba <= ds_lba;
                            slot_off <= ds_off;
                        end
                        if (ds_off + 10'd32 >= 10'd512) begin
                            if (ds_sect + 8'd1 >= spc) begin
                                fg_clus <= ds_clus;
                                push_call(S_FG0, S_DS_CHAIN);
                            end else begin
                                ds_sect <= ds_sect + 8'd1;
                                state   <= S_DS_SECT;
                            end
                        end else begin
                            ds_off <= ds_off + 10'd32;
                            state  <= S_DS_ENT;
                        end
                    end else if (ds_attr == 8'h0F || ds_attr[3]) begin
                        if (ds_off + 10'd32 >= 10'd512) begin
                            if (ds_sect + 8'd1 >= spc) begin
                                fg_clus <= ds_clus;
                                push_call(S_FG0, S_DS_CHAIN);
                            end else begin
                                ds_sect <= ds_sect + 8'd1;
                                state   <= S_DS_SECT;
                            end
                        end else begin
                            ds_off <= ds_off + 10'd32;
                            state  <= S_DS_ENT;
                        end
                    end else if (name_hit_q) begin
                        found_r  <= 1'b1;
                        dir_lba  <= ds_lba;
                        dir_off  <= ds_off;
                        ent_clus <= {dent[21], dent[20], dent[27], dent[26]};
                        ent_size <= {dent[31], dent[30], dent[29], dent[28]};
                        pop_ret();
                    end else begin
                        if (ds_off + 10'd32 >= 10'd512) begin
                            if (ds_sect + 8'd1 >= spc) begin
                                fg_clus <= ds_clus;
                                push_call(S_FG0, S_DS_CHAIN);
                            end else begin
                                ds_sect <= ds_sect + 8'd1;
                                state   <= S_DS_SECT;
                            end
                        end else begin
                            ds_off <= ds_off + 10'd32;
                            state  <= S_DS_ENT;
                        end
                    end
                end
                S_DS_CHAIN: begin
                    // Next root-dir cluster after spc sectors. EOC → not found.
                    // Guard: a cyclic chain (garbage FAT data off a real card)
                    // must land in ?IO, never spin busy forever.
                    if (ds_guard > 16'd65534)
                        state <= S_ERR;
                    else if (fat_lt2 || fat_eoc)
                        pop_ret();
                    else begin
                        ds_clus  <= fat_val;
                        ds_sect  <= 8'h0;
                        ds_guard <= ds_guard + 16'd1;
                        state    <= S_DS_BASE;
                    end
                end

                // ---------------- FAT get ---------------------------------
                S_FG0: begin
                    fg_lba  <= fat_start + (fg_clus >> 7);
                    buf_lba <= fat_start + (fg_clus >> 7);
                    sd_go(8'd2, fat_start + (fg_clus >> 7), S_FG1);
                end
                S_FG1: begin
                    br_i   <= 5'd0;
                    br_acc <= 32'h0;
                    state  <= S_FG1A;
                end
                S_FG1A: begin
                    fs_rd_addr <= fg_off[8:0] + {7'h0, br_i[1:0]};
                    push_call(S_BR, S_FG1B);
                end
                S_FG1B: begin
                    unique case (br_i[1:0])
                        2'd0: br_acc <= {24'h0, br_byte};
                        2'd1: br_acc <= {16'h0, br_byte, br_acc[7:0]};
                        2'd2: br_acc <= {8'h0, br_byte, br_acc[15:0]};
                        2'd3: begin
                            fat_val <= {br_byte, br_acc[23:0]} & 32'h0FFFFFFF;
                            fat_lt2 <= ({br_byte, br_acc[23:0]} & 32'h0FFFFFFF) < 32'd2;
                            fat_eoc <= ({br_byte, br_acc[23:0]} & 32'h0FFFFFFF) >= 32'h0FFFFFF8;
                            fat_rsv <= ({br_byte, br_acc[23:0]} & 32'h0FFFFFFF) >= 32'h0FFFFFF0
                                    && ({br_byte, br_acc[23:0]} & 32'h0FFFFFFF) < 32'h0FFFFFF8;
                            fat_eq_ds <= ({br_byte, br_acc[23:0]} & 32'h0FFFFFFF) == ds_clus;
                            pop_ret();
                        end
                    endcase
                    if (br_i < 5'd3) begin
                        br_i  <= br_i + 5'd1;
                        state <= S_FG1A;
                    end
                end

                // ---------------- FAT set (every FAT copy) ----------------
                S_FS0: begin
                    fs_i  <= 8'h0;
                    state <= S_FS1;
                end
                S_FS1: begin
                    if (fs_i >= nfats) pop_ret();
                    else begin
                        fs_pre <= {24'h0, fs_i} * spf + (fs_clus >> 7);
                        state  <= S_FS1B;
                    end
                end
                S_FS1B: begin
                    fs_lba  <= fat_start + fs_pre;
                    buf_lba <= fat_start + fs_pre;
                    fs_bi   <= 8'h0;
                    sd_go(8'd2, fat_start + fs_pre, S_FS2);
                end
                S_FS2: begin
                    // fs_buf_we patches one byte per cycle (see always_comb)
                    if (fs_bi >= 8'd3) state <= S_FS3;
                    else fs_bi <= fs_bi + 8'd1;
                end
                // Write THIS fat copy, then advance fs_i after the SPI op
                // completes (old path bumped fs_i when the write started, which
                // raced the next S_FS1 and could skip FAT2 / reuse fs_lba).
                S_FS3: sd_go(8'd3, fs_lba, S_FS4);
                S_FS4: begin
                    fs_i  <= fs_i + 8'd1;
                    state <= S_FS1;
                end

                // ---------------- allocate one free cluster ---------------
                S_AL0: begin
                    al_clus  <= 32'd2;
                    al_lba   <= fat_start;
                    al_guard <= 32'h0;
                    buf_lba  <= fat_start;
                    sd_go(8'd2, fat_start, S_AL1);
                end
                // BRAM — gather FAT entry then decide
                S_AL1: begin
                    br_i   <= 5'd0;
                    br_acc <= 32'h0;
                    state  <= S_AL1R;
                end
                S_AL1R: begin
                    fs_rd_addr <= al_off[8:0] + {7'h0, br_i[1:0]};
                    push_call(S_BR, S_AL1C);
                end
                S_AL1C: begin
                    unique case (br_i[1:0])
                        2'd0: br_acc <= {24'h0, br_byte};
                        2'd1: br_acc <= {16'h0, br_byte, br_acc[7:0]};
                        2'd2: br_acc <= {8'h0, br_byte, br_acc[15:0]};
                        2'd3: begin
                            br_acc <= {br_byte, br_acc[23:0]} & 32'h0FFFFFFF;
                            state  <= S_AL1D;
                        end
                    endcase
                    if (br_i < 5'd3) begin
                        br_i  <= br_i + 5'd1;
                        state <= S_AL1R;
                    end
                end
                S_AL1D: begin
                    if (br_acc == 32'h0) begin
                        state <= S_AL2;
                    end else if (al_guard > 32'd65535) begin
                        state <= S_ERR;         // disk full
                    end else begin
                        al_guard <= al_guard + 32'd1;
                        al_clus  <= al_clus + 32'd1;
                        if (al_clus[6:0] == 7'd127) begin
                            al_lba  <= al_lba + 32'd1;
                            buf_lba <= al_lba + 32'd1;
                            sd_go(8'd2, al_lba + 32'd1, S_AL1);
                        end else state <= S_AL1;
                    end
                end
                S_AL2: begin
                    fs_clus <= al_clus;
                    fs_val  <= FAT_EOC;
                    push_call(S_FS0, S_AL3);
                end
                S_AL3: begin
                    if (al_prev >= 32'd2) begin
                        fs_clus <= al_prev;
                        fs_val  <= al_clus;
                        al_prev <= 32'h0;
                        push_call(S_FS0, S_AL3);
                    end else pop_ret();
                end

                // ---------------- free a cluster chain --------------------
                S_FC0: begin
                    if (fc_clus < 32'd2 || fc_clus >= FAT_BAD || fc_guard > 32'd65535)
                        pop_ret();
                    else begin
                        fg_clus <= fc_clus;
                        push_call(S_FG0, S_FC1);
                    end
                end
                S_FC1: begin
                    fc_next <= fat_val;
                    fs_clus <= fc_clus;
                    fs_val  <= 32'h0;
                    push_call(S_FS0, S_FC2);
                end
                S_FC2: begin
                    fc_guard <= fc_guard + 32'd1;
                    fc_clus  <= fc_next;
                    state    <= S_FC0;
                end

                // ---------------- read one file byte ----------------------
                S_RB0: begin
                    if (buf_lba == data_lba) begin
                        fs_rd_addr <= rd_off[8:0];
                        push_call(S_BR, S_RB0C);
                    end else begin
                        buf_lba <= data_lba;
                        sd_go(8'd2, data_lba, S_RB1);
                    end
                end
                S_RB0C: begin
                    rb_byte <= br_byte;
                    pop_ret();
                end
                S_RB1: begin
                    fs_rd_addr <= rd_off[8:0];
                    push_call(S_BR, S_RB0C);
                end
                // advance read position by one byte
                S_RBA0: begin
                    f_pos <= f_pos + 32'd1;
                    if (rd_off >= 10'd511) begin
                        rd_off <= 10'h0;
                        if (sect_in_clus + 8'd1 >= spc) begin
                            fg_clus <= cur_clus;
                            push_call(S_FG0, S_RBA1);
                        end else begin
                            sect_in_clus <= sect_in_clus + 8'd1;
                            data_lba     <= data_lba + 32'd1;
                            pop_ret();
                        end
                    end else begin
                        rd_off <= rd_off + 10'd1;
                        pop_ret();
                    end
                end
                S_RBA1: begin
                    // Split LBA math — was fat_val→data_lba in one cycle (−0.5 ns WNS)
                    cur_clus     <= fat_val;
                    sect_in_clus <= 8'h0;
                    lba_off      <= (fat_val - 32'd2) << spc_shift;
                    state        <= S_RBA1B;
                end
                S_RBA1B: begin
                    data_lba <= data_start + lba_off;
                    pop_ret();
                end

                // Public get_byte — S_RB0 then advance; eof at f_size
                S_GB0: begin
                    if (mode_r != 8'h49) state <= S_ERR;
                    else if (f_pos >= f_size) begin
                        eof_r <= 1'b1;
                        state <= S_FIN;
                    end else push_call(S_RB0, S_GB1);
                end
                S_GB1: push_call(S_RBA0, S_FIN);

                // ---------------- LINE INPUT# -----------------------------
                // Shared line filler: reads up to the next LF into linebuf.
                // rl_ret picks the consumer (LINE INPUT# vs INPUT# refill).
                S_RL0: begin
                    line_n <= 9'h0;
                    state  <= S_RL1;
                end
                S_RL1: begin
                    if (mode_r != 8'h49) state <= S_ERR;
                    else if (f_pos >= f_size) begin
                        if (line_n == 9'h0) eof_r <= 1'b1;
                        if (!rl_field) begin
                            fld_off  <= 9'h0;
                            fld_len  <= line_n;
                            cpy_i    <= 9'h0;
                            line_pos <= line_n;
                            state    <= S_CPY;
                        end else begin
                            line_pos <= 9'h0;
                            state    <= S_RF1;
                        end
                    end else push_call(S_RB0, S_RL2);
                end
                S_RL2: begin
                    if (rb_byte == 8'h0A) begin
                        // end of line — consume the LF and hand the line over
                        if (!rl_field) begin
                            fld_off  <= 9'h0;
                            fld_len  <= line_n;
                            cpy_i    <= 9'h0;
                            line_pos <= line_n;
                            push_call(S_RBA0, S_CPY);
                        end else begin
                            line_pos <= 9'h0;
                            push_call(S_RBA0, S_RF1);
                        end
                    end else begin
                        if (rb_byte != 8'h0D && line_n < 9'd255) begin
                            begin lbw_we <= 1'b1; lbw_wa <= line_n[7:0]; lbw_wd <= rb_byte; end
                            line_n <= line_n + 9'd1;
                        end
                        push_call(S_RBA0, S_RL1);
                    end
                end

                // ---------------- INPUT# field ----------------------------
                S_RF0: begin
                    if (mode_r != 8'h49) state <= S_ERR;
                    else if (line_pos >= line_n) begin
                        rl_field <= 1'b1;        // refill then re-scan
                        state    <= S_RL0;
                    end else state <= S_RF1;
                end
                S_RF1: begin
                    // skip blanks; an exhausted line means "read the next one"
                    if (line_pos >= line_n) begin
                        if (eof_r) begin
                            fld_off <= 9'h0;
                            fld_len <= 9'h0;
                            cpy_i   <= 9'h0;
                            state   <= S_CPY;
                        end else begin
                            rl_field <= 1'b1;
                            state    <= S_RL0;
                        end
                    end else if (!lb_arm) lb_arm <= 1'b1;
                    else if (lb_pos_blank) begin
                        line_pos <= line_pos + 9'd1;
                        lb_arm <= 1'b0;
                    end else begin
                        lb_arm <= 1'b0;
                        state <= S_RF2;
                    end
                end
                S_RF2: begin
                    if (!lb_arm) lb_arm <= 1'b1;
                    else if (lb_pos_quote) begin  // quoted field
                        fld_off  <= line_pos + 9'd1;
                        line_pos <= line_pos + 9'd1;
                        lb_arm   <= 1'b0;
                        state    <= S_RF3;
                    end else begin
                        fld_off <= line_pos;
                        lb_arm  <= 1'b0;
                        state   <= S_RF5;
                    end
                end
                S_RF3: begin
                    if (line_pos >= line_n) begin
                        fld_len <= line_pos - fld_off;
                        state   <= S_RF4;
                    end else if (!lb_arm) lb_arm <= 1'b1;
                    else if (lb_pos_quote) begin
                        fld_len  <= line_pos - fld_off;
                        line_pos <= line_pos + 9'd1;
                        lb_arm   <= 1'b0;
                        state    <= S_RF4;
                    end else begin
                        line_pos <= line_pos + 9'd1;
                        lb_arm <= 1'b0;
                    end
                end
                S_RF4: begin
                    // after a quoted field: skip blanks then one comma
                    if (!lb_arm) lb_arm <= 1'b1;
                    else if (line_pos < line_n && lb_pos_blank) begin
                        line_pos <= line_pos + 9'd1;
                        lb_arm <= 1'b0;
                    end else begin
                        lb_arm <= 1'b0;
                        if (line_pos < line_n && lb_pos_comma)
                            line_pos <= line_pos + 9'd1;
                        cpy_i <= 9'h0;
                        state <= S_CPY;
                    end
                end
                S_RF5: begin
                    // unquoted field runs to a comma or end of line
                    if (!lb_arm) lb_arm <= 1'b1;
                    else if (line_pos < line_n && !lb_pos_comma) begin
                        line_pos <= line_pos + 9'd1;
                        lb_arm <= 1'b0;
                    end else begin
                        fld_len <= line_pos - fld_off;
                        if (line_pos < line_n) line_pos <= line_pos + 9'd1;
                        lb_arm <= 1'b0;
                        state <= S_RF6;
                    end
                end
                S_RF6: begin
                    // strip trailing blanks (leading ones were skipped in S_RF1)
                    if (!lb_arm) lb_arm <= 1'b1;
                    else if (fld_len != 9'h0 && lb_i9_blank) begin
                        fld_len <= fld_len - 9'd1;
                        lb_arm <= 1'b0;
                    end else begin
                        cpy_i <= 9'h0;
                        lb_arm <= 1'b0;
                        state <= S_CPY;
                    end
                end

                // ---------------- linebuf -> STORAGE_BUFFER ---------------
                S_CPY: begin
                    if (cpy_i >= fld_len) state <= S_FIN;
                    else if (!lb_arm) lb_arm <= 1'b1;
                    else begin
                        maddr <= STORAGE_BUFFER + {7'h0, cpy_i};
                        mdata <= lb_i9_q;
                        cpy_i <= cpy_i + 9'd1;
                        lb_arm <= 1'b0;
                        push_call(S_MW, S_CPY);
                    end
                end

                // ---------------- OPEN ------------------------------------
                S_OP0: begin
                    if (!mounted) push_call(S_MNT0, S_OP1);
                    else state <= S_OP1;
                end
                S_OP1: push_call(S_DS_START, S_OP2);
                S_OP2: begin
                    buf_lba  <= 32'hFFFFFFFF;   // dir scan clobbered the buffer
                    line_n   <= 9'h0;
                    line_pos <= 9'h0;
                    if (mode_r == 8'h49) begin  // 'I'
                        if (!found_r) begin
                            // Bare OPEN "FOO" — try .JS/.HTML/.PNG/.DAT (JS FM resolve)
                            if (bare_name && alt_try < 3'd4) begin
                                unique case (alt_try)
                                    3'd0: begin // .JS
                                        name83[8] <= 8'h4A; name83[9] <= 8'h53; name83[10] <= 8'h20;
                                    end
                                    3'd1: begin // .HTM (8.3 of HTML)
                                        name83[8] <= 8'h48; name83[9] <= 8'h54; name83[10] <= 8'h4D;
                                    end
                                    3'd2: begin // .PNG
                                        name83[8] <= 8'h50; name83[9] <= 8'h4E; name83[10] <= 8'h47;
                                    end
                                    default: begin // .DAT
                                        name83[8] <= 8'h44; name83[9] <= 8'h41; name83[10] <= 8'h54;
                                    end
                                endcase
                                alt_try <= alt_try + 3'd1;
                                push_call(S_DS_START, S_OP2);
                            end else begin not_found_o<=1;state<=S_ERR;end
                        end else begin
                            f_first      <= ent_clus;
                            f_size       <= ent_size;
                            f_pos        <= 32'h0;
                            cur_clus     <= ent_clus;
                            sect_in_clus <= 8'h0;
                            rd_off       <= 10'h0;
                            data_lba     <= data_start + ((ent_clus - 32'd2) << spc_shift);
                            pub_i        <= 5'h0;
                            err_r        <= 1'b0;
                            state        <= S_PUB;
                        end
                    end else if(mode_r==8'h41 && found_r)begin // A: append without a file copy
                        mode_r<=8'h4f;f_first<=ent_clus;f_size<=ent_size;f_pos<=ent_size;
                        cur_clus<=ent_clus;append_remaining<=ent_size;pub_i<=0;err_r<=0;
                        if(ent_size==0)begin cur_clus<=0;wr_idx<=0;state<=S_PUB;end
                        else state<=S_APPEND_LOC;
                    end else begin              // 'O' — create / overwrite
                        // Bare SAVE "FOO" → resolve FOO.JS before create
                        if (bare_name && name83[8] == 8'h20 && alt_try == 3'd0) begin
                            name83[8]  <= 8'h4A;
                            name83[9]  <= 8'h53;
                            name83[10] <= 8'h20;
                            alt_try    <= 3'd1;
                            push_call(S_DS_START, S_OP2);
                        end else if (found_r) begin
                            fc_clus  <= ent_clus;
                            fc_guard <= 32'h0;
                            push_call(S_FC0, S_OP3);
                        end else if (slot_ok) begin
                            dir_lba <= slot_lba;
                            dir_off <= slot_off;
                            state   <= S_OP3;
                        end else state <= S_ERR;
                    end
                end
                S_OP3: begin
                    mode_r<=8'h4f;
                    f_first      <= 32'h0;
                    f_size       <= 32'h0;
                    f_pos        <= 32'h0;
                    cur_clus     <= 32'h0;
                    sect_in_clus <= 8'h0;
                    wr_idx       <= 10'h0;
                    buf_lba      <= 32'hFFFFFFFF;
                    pub_i        <= 5'h0;
                    err_r        <= 1'b0;
                    state        <= S_PUB;
                end

                // Walk only the FAT chain, then read the partial final sector.
                // One channel and the existing sector buffer suffice for append.
                S_APPEND_LOC:begin
                    if(append_remaining >= (32'd512<<spc_shift))begin
                        append_remaining<=append_remaining-(32'd512<<spc_shift);
                        fg_clus<=cur_clus;push_call(S_FG0,S_APPEND_NEXT);
                    end else begin
                        sect_in_clus<=8'(append_remaining>>9);wr_idx<={1'b0,append_remaining[8:0]};
                        lba_off<=((cur_clus-32'd2)<<spc_shift)+(append_remaining>>9);state<=S_APPEND_SECTOR;
                    end
                end
                S_APPEND_NEXT:begin
                    if(fat_eoc && append_remaining==0)begin
                        al_prev<=cur_clus;push_call(S_AL0,S_APPEND_READY);
                    end else if(fat_lt2 || fat_eoc)state<=S_ERR;
                    else begin cur_clus<=fat_val;state<=S_APPEND_LOC;end
                end
                S_APPEND_READY:begin cur_clus<=al_clus;state<=S_APPEND_LOC;end
                S_APPEND_SECTOR:begin
                    data_lba<=data_start+lba_off;buf_lba<=data_start+lba_off;
                    if(wr_idx!=0)sd_go(8'd2,data_start+lba_off,S_PUB);else state<=S_PUB;
                end
                S_RENAME_READ:begin ent_i<=0;sd_go(8'd2,dir_lba,S_RENAME_PATCH);end
                S_RENAME_PATCH:if(ent_i==10)state<=S_RENAME_WRITE;else ent_i<=ent_i+1'b1;
                S_RENAME_WRITE:begin buf_lba<=32'hffffffff;sd_go(8'd3,dir_lba,S_FIN);end

                // ---------------- append one byte (PRINT#) ----------------
                S_AP0: begin
                    if (mode_r != 8'h4F) pop_ret();      // not open for output
                    else if (cur_clus == 32'h0) begin
                        al_prev <= 32'h0;
                        push_call(S_AL0, S_AP1);
                    end else state <= S_AP2;
                end
                S_AP1: begin
                    f_first      <= al_clus;
                    cur_clus     <= al_clus;
                    sect_in_clus <= 8'h0;
                    data_lba     <= data_start + ((al_clus - 32'd2) << spc_shift);
                    wr_idx       <= 10'h0;
                    buf_lba      <= 32'hFFFFFFFF;
                    state        <= S_AP2;
                end
                S_AP2: begin
                    // fs_buf_we writes app_byte into sbuf[wr_idx] this cycle
                    wr_idx <= wr_idx + 10'd1;
                    f_size <= f_size + 32'd1;
                    state  <= S_AP3;
                end
                S_AP3: begin
                    if (wr_idx >= 10'd512) sd_go(8'd3, data_lba, S_AP4);
                    else pop_ret();
                end
                S_AP4: begin
                    wr_idx  <= 10'h0;
                    buf_lba <= 32'hFFFFFFFF;
                    if (sect_in_clus + 8'd1 >= spc) begin
                        al_prev <= cur_clus;
                        push_call(S_AL0, S_AP5);
                    end else begin
                        sect_in_clus <= sect_in_clus + 8'd1;
                        data_lba     <= data_lba + 32'd1;
                        pop_ret();
                    end
                end
                S_AP5: begin
                    cur_clus     <= al_clus;
                    sect_in_clus <= 8'h0;
                    data_lba     <= data_start + ((al_clus - 32'd2) << spc_shift);
                    pop_ret();
                end

                // ---------------- CLOSE -----------------------------------
                S_CL0: begin
                    cl_data_done <= 1'b0;
                    if (mode_r != 8'h4F) state <= S_CL5;      // input / idle
                    else if (wr_idx != 10'h0) begin
                        pad_i <= wr_idx;
                        state <= S_CL1;
                    end else state <= S_CL3;
                end
                S_CL1: state <= (pad_i >= 10'd512) ? S_CL3 : S_CL2;
                S_CL2: begin
                    pad_i <= pad_i + 10'd1;                   // zero-pad tail
                    state <= S_CL1;
                end
                S_CL3: begin
                    // Flush data at most once (wr_idx sticky caused a
                    // second CMD24 of the data LBA and then skipped the dirent).
                    if (!cl_data_done && wr_idx != 10'h0) begin
                        cl_data_done <= 1'b1;
                        wr_idx  <= 10'h0;
                        buf_lba <= 32'hFFFFFFFF;
                        sd_go(8'd3, data_lba, S_CL3);
                    end else begin
                        ent_i   <= 6'h0;
                        buf_lba <= dir_lba;
                        sd_go(8'd2, dir_lba, S_CL4);
                    end
                end
                S_CL4: begin
                    // fs_buf_we patches the 32-byte directory record
                    // Defer CMD24 to S_CL4W so all 32 patches land first
                    // (mirrors S_FS2 → S_FS3), otherwise the dirent write was
                    // skipped/raced and P.DAT never appeared on card.img.
                    if (ent_i >= 6'd31) state <= S_CL4W;
                    else ent_i <= ent_i + 6'd1;
                end
                S_CL4W: sd_go(8'd3, dir_lba, S_CL5);
                S_CL5: begin
                    mode_r   <= 8'h0;
                    line_n   <= 9'h0;
                    line_pos <= 9'h0;
                    pub_i    <= 5'h0;
                    cl_data_done <= 1'b0;
                    state    <= S_PUB;
                end

                // ---------------- publish channel registers ---------------
                S_PUB: begin
                    if (pub_i >= 5'd21) state <= S_FIN;
                    else begin
                        maddr <= pub_addr;
                        mdata <= pub_data;
                        pub_i <= pub_i + 5'd1;
                        push_call(S_MW, S_PUB);
                    end
                end

                // REMOVE "NAME" — find (bare suffixes like OPEN I) + E5 + free
                S_DEL0: if (!mounted) push_call(S_MNT0, S_DEL1); else state <= S_DEL1;
                S_DEL1: push_call(S_DS_START, S_DEL2);
                S_DEL2: begin
                    buf_lba <= 32'hFFFFFFFF;
                    if (!found_r) begin
                        if (bare_name && alt_try < 3'd4) begin
                            unique case (alt_try)
                                3'd0: begin name83[8]<=8'h4A; name83[9]<=8'h53; name83[10]<=8'h20; end // .JS
                                3'd1: begin name83[8]<=8'h48; name83[9]<=8'h54; name83[10]<=8'h4D; end // .HTM
                                3'd2: begin name83[8]<=8'h50; name83[9]<=8'h4E; name83[10]<=8'h47; end // .PNG
                                default: begin name83[8]<=8'h44; name83[9]<=8'h41; name83[10]<=8'h54; end // .DAT
                            endcase
                            alt_try <= alt_try + 3'd1;
                            push_call(S_DS_START, S_DEL2);
                        end else begin not_found_o<=1;state<=S_ERR;end
                    end else sd_go(8'd2, dir_lba, S_DEL_RD);
                end
                S_DEL_RD: state <= S_DEL_PK;
                S_DEL_PK: state <= S_DEL_WR;
                S_DEL_WR: sd_go(8'd3, dir_lba, S_DEL_FC);
                S_DEL_FC: begin
                    if (ent_clus >= 32'd2) begin
                        fc_clus <= ent_clus; fc_guard <= 32'h0;
                        push_call(S_FC0, S_FIN);
                    end else state <= S_FIN;
                end

                // DIR catalog — sequential dent[] walk, one name per start_dir_next
                S_DIR0: begin
                    ds_guard  <= 16'd0;
                    ds_clus   <= root_clus;
                    ds_sect   <= 8'h0;
                    ds_off    <= 10'h0;
                    dir_yield <= 1'b0;
                    // ds_base steers every S_DIR_ADV sector advance; without
                    // this a cold DIR inherits stale ds_base (0 after reset)
                    // and reads LBA 1 instead of root sector 1 — the listing
                    // silently truncates at 16 entries.
                    ds_base   <= data_start + ((root_clus - 32'd2) << spc_shift);
                    ds_lba    <= data_start + ((root_clus - 32'd2) << spc_shift);
                    buf_lba   <= data_start + ((root_clus - 32'd2) << spc_shift);
                    sd_go(8'd2, data_start + ((root_clus - 32'd2) << spc_shift), S_FIN);
                end
                S_DIR_N: begin
                    dent_i    <= 5'd0;
                    dir_yield <= 1'b0;
                    state     <= S_DIR_LD;
                end
                S_DIR_LD: begin
                    fs_rd_addr <= ds_off[8:0] + {4'h0, dent_i};
                    push_call(S_BR, S_DIR_LDC);
                end
                S_DIR_LDC: begin
                    dent[dent_i] <= br_byte;
                    if (dent_i >= 5'd31) state <= S_DIR_EV;
                    else begin
                        dent_i <= dent_i + 5'd1;
                        state  <= S_DIR_LD;
                    end
                end
                S_DIR_EV: begin
                    if (dent[0] == 8'h00) begin
                        eof_r  <= 1'b1;
                        cat_on <= 1'b0;
                        state  <= S_FIN;
                    end else if (dent[0] == 8'hE5 || dent[11] == 8'h0F || dent[11][3] || (cat_raw && dent[11][4])) begin
                        state <= S_DIR_ADV; // skip
                    end else if (dent_sys && !cat_system) begin
                        state <= S_DIR_ADV; // EDITOR/COMPILER/ARTSCAN — not titles
                    end else if (
                        !cat_all && (
                        (dent[8] == "J" && dent[9] == "S" && dent[10] == "H") ||
                        (dent[8] == "J" && dent[9] == "S" && dent[10] == "B") ||
                        (dent[8] == "A" && dent[9] == "R" && (dent[10] == "T" || dent[10] == "J")) ||
                        (dent[8] == "I" && dent[9] == "C" && dent[10] == "N")
                    )) begin
                        state <= S_DIR_ADV; // hide .JSH/.JSB/.ART/.ARJ/.ICN unless DIR *
                    end else begin
                        dent_i <= 5'd0;
                        line_n <= 9'h0;
                        state  <= S_DIR_FMT;
                    end
                end
                S_DIR_FMT: begin
                    // Build "NAME.EXT" in linebuf from dent[0..10]
                    if (dent_i < 5'd8) begin
                        if (fmt_stem_ch != 8'h20) begin
                            begin lbw_we <= 1'b1; lbw_wa <= line_n[7:0]; lbw_wd <= fmt_stem_ch; end
                            line_n <= line_n + 9'd1;
                        end
                        dent_i <= dent_i + 5'd1;
                    end else if (dent_i == 5'd8) begin
                        if (dent[8] != 8'h20 || dent[9] != 8'h20 || dent[10] != 8'h20) begin
                            begin lbw_we <= 1'b1; lbw_wa <= line_n[7:0]; lbw_wd <= "."; end
                            line_n <= line_n + 9'd1;
                        end
                        dent_i <= 5'd9;
                    end else begin
                        // dent_i 9..11 → ext dent[8..10]
                        if (fmt_ext_nb) begin
                            begin lbw_we <= 1'b1; lbw_wa <= line_n[7:0]; lbw_wd <= fmt_ext_ch; end
                            line_n <= line_n + 9'd1;
                        end
                        if (dent_i >= 5'd11) begin
                            fld_off   <= 9'h0;
                            // Include this cycle's optional ext byte in length
                            // .HTM on FAT → glass .HTML (PYTHON names)
                            if (!cat_raw && dent[8] == "H" && dent[9] == "T" && dent[10] == "M") begin
                                // one strobe per beat: the "L" append takes
                                // its own beat via dirfmt_l (write collision
                                // with the ext byte above otherwise)
                                dirfmt_l <= 1'b1;
                                fld_len <= line_n + (fmt_ext_nb ? 9'd1 : 9'd0) + 9'd1;
                            end else
                                fld_len <= line_n + (fmt_ext_nb ? 9'd1 : 9'd0);
                            cpy_i     <= 9'h0;
                            dir_yield <= 1'b1;
                            state     <= S_DIR_ADV;
                        end else dent_i <= dent_i + 5'd1;
                    end
                end
                S_DIR_ADV: begin
                    if (dirfmt_l) begin
                        lbw_we <= 1'b1; lbw_wa <= 8'(fld_len - 9'd1); lbw_wd <= "L";
                        dirfmt_l <= 1'b0;
                    end
                    if (ds_off + 10'd32 >= 10'd512) begin
                        if (ds_sect + 8'd1 >= spc) begin
                            // Keep the pending name in linebuf while fetching
                            // the next root cluster. dent[] (size/date/attr)
                            // also remains valid until this entry is returned.
                            fg_clus <= ds_clus;
                            push_call(S_FG0, S_DIR_CHAIN);
                        end else begin
                            ds_sect <= ds_sect + 8'd1;
                            ds_off  <= 10'h0;
                            ds_lba  <= ds_base + {24'h0, ds_sect + 8'd1};
                            buf_lba <= ds_base + {24'h0, ds_sect + 8'd1};
                            sd_go(8'd2, ds_base + {24'h0, ds_sect + 8'd1},
                                  dir_yield ? S_CPY : S_DIR_N);
                        end
                    end else begin
                        ds_off <= ds_off + 10'd32;
                        state  <= dir_yield ? S_CPY : S_DIR_N;
                    end
                end

                S_DIR_CHAIN: begin
                    // FAT_BAD (0x0FFFFFF7) lies inside the reserved range.
                    if (err_r || ds_guard == 16'hffff || fat_lt2 ||
                        fat_eq_ds || fat_rsv) begin
                        cat_on <= 1'b0;
                        state <= S_ERR;
                    end else if (fat_eoc) begin
                        cat_on <= 1'b0;
                        if (dir_yield) state <= S_CPY;
                        else begin eof_r <= 1'b1; state <= S_FIN; end
                    end else begin
                        ds_guard <= ds_guard + 16'd1;
                        ds_clus <= fat_val;
                        ds_sect <= 8'd0;
                        ds_off <= 10'd0;
                        ds_base <= data_start + ((fat_val - 32'd2) << spc_shift);
                        ds_lba <= data_start + ((fat_val - 32'd2) << spc_shift);
                        buf_lba <= data_start + ((fat_val - 32'd2) << spc_shift);
                        sd_go(8'd2, data_start + ((fat_val - 32'd2) << spc_shift), S_DIR_CHAIN_LOADED);
                    end
                end
                S_DIR_CHAIN_LOADED: begin
                    if (err_r) begin cat_on <= 1'b0; state <= S_ERR; end
                    else state <= dir_yield ? S_CPY : S_DIR_N;
                end

                // A garbage state used to fall back to S_IDLE
                // SILENTLY (no done) — the console then waited 32 s for a
                // pulse that never came. Fail loud instead.
                default: state <= S_ERR;
            endcase
`ifdef VERILATOR
            trace_cyc <= trace_cyc + 1;
            // Sim-only DIR-walk trace to file (never stdout: RPC stream).
            if (state inside {S_DIR0, S_DIR_N, S_DIR_LD, S_DIR_LDC, S_DIR_EV,
                              S_DIR_FMT, S_DIR_ADV, S_CPY}
                || (cat_on && state inside {S_FIN, S_SD_WAIT})) begin
                if (dirtrace_fd == 0)
                    dirtrace_fd = $fopen("dirtrace.log", "w");
                if (state != dirtrace_last) begin
                    $fdisplay(dirtrace_fd, "c=%0d st=%0d off=%0d sect=%0d yield=%0d cat=%0d d0=%02x spc=%0d eof=%0d fl=%0d ln=%0d lba=%0d",
                              trace_cyc, state, ds_off, ds_sect, dir_yield, cat_on,
                              dent[0], spc, eof_r, fld_len, line_n, ds_lba);
                    dirtrace_last <= state;
                    $fflush(dirtrace_fd);
                end
            end
`endif
            // hot-swap: any card-detect change poisons the mount
            cp_q <= card_present;
            if (cp_q != card_present) mounted <= 1'b0;
            // watchdog override (after the case, so it wins the beat)
            if (state == S_IDLE) op_wd <= 32'h0;
            else begin
                op_wd <= op_wd + 32'd1;
                if (op_wd[31]) begin
                    op_wd <= 32'h0;
                    state <= S_ERR;
                end
            end
        end
    end
endmodule
