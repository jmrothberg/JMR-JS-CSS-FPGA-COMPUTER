// Shared JS-native core — Verilator tops this; board top is PHY shell only.
// Pattern cite: BASIC jmr_core + standalone_mode.
// NEW: storage_engine + work/source BRAM for DIR/LOAD/SAVE/REMOVE.
module jmr_js_core #(
    parameter int unsigned SD_INIT_DIV = 127,
    parameter int unsigned SD_RUN_DIV  = 3,
    // NEW: FPGA-SIM FRAME_DIV=1 (one tick per ~2 clk when idle). Board keeps 65535.
    parameter int unsigned FRAME_DIV   = 65535,
    // NEW: 1 = behavioral 4 MB SRAM (FPGA-SIM). 0 = ports for board MIG / ASIC.
    // Not `ifdef SYNTHESIS` — same RTL, board instantiates #(.SRAM_INTERNAL(0)).
    parameter bit SRAM_INTERNAL = 1,
    // 2026-08-25 div8 timing rescue: u_vm runs on clk/VM_CLK_DIV. Run-30
    // post-route measurement: all 6,000 worst failing paths start AND end
    // inside u_vm (WNS -58.737 at 10 ns -> +11.26 ns at 80 ns); nothing
    // outside the VM fails, and jmr_fb_scanout needs the full 100 MHz (one
    // SRAM fetch per 100 ns sustains 640x480). 1 = passthrough (battery
    // speed); board default 8.
    parameter int unsigned VM_CLK_DIV = 7
) (
    input  logic        clk,
    input  logic        pixel_clk,   // mini-FB read domain (board HDMI)
    input  logic        rst_n,
    input  logic        standalone_mode,
    input  logic        kbd_push,
    input  logic [7:0]  kbd_data,
    input  logic [5:0]  joy_in,
    output logic [5:0]  joy_out,
    output logic [6:0]  stor_dbg_state_o,
    output logic [6:0]  cons_dbg_state_o,
    output logic        game_view_o,
    output logic [31:0] vdbg_o,
    output logic        vdbg_fault_o,
    output logic [31:0] vm_hdbg,
    output logic [31:0] vm_fdbg,
    output logic        vm_fdbg_v,
    output logic [127:0] vm_ftrace,
    // sound-native poke (core clock; PSG leaf + CDC live in the top)
    output logic        snd_tgl,
    output logic [1:0]  snd_ch,
    output logic [15:0] snd_freq,
    output logic [3:0]  snd_vol,
    output logic [7:0]  snd_frames,
    output logic [7:0]  snd_slide,
    // FPGA-SIM keyboard/joystick ARE these ports (GUI KEYEVT / KEYBITS).
    // No PS/2 or I2C in this module. Board PHY is top_nexys_video only.
    // LED proofs: tools/pmod_input_test + tools/hid_led_blink — not this file.
    // NEW: raw keyboard events for games (sim KEYEVT / board PS/2 decode)
    input  logic        sd_card_present = 1'b1,
    input  logic        key_evt_stb = 1'b0,
    input  logic [7:0]  key_evt_code = 8'd0,
    input  logic        key_evt_down = 1'b0,
    input  logic [9:0]  dump_addr,
    output logic [7:0]  dump_data,
    output logic [9:0]  cursor,
    output logic        ready_lit,
    input  logic [9:0]  scan_addr,
    output logic [7:0]  scan_data,
    // Mini-canvas scanout (game mode) — native 640×480
    output logic        game_mode,
    input  logic [18:0] fb_raddr, // Session-1: unused (scanout is DDR3-side)
    input  logic [9:0]  fb_x,
    input  logic [9:0]  fb_y,
    output logic [7:0]  fb_rdata,
    // NEW: tether FB dump (core clk)
    input  logic [18:0] dump_fb_raddr = 19'd0,
    output logic [7:0]  dump_fb_rdata,
    // NEW: title palette readout (ASET 256×RGB888) — HDMI top + sim PAL? dump
    input  logic [7:0]  pal_raddr = 8'd0,
    output logic [23:0] pal_rdata,
    // NEW: µSD SPI (storage_engine owns the master)
    output logic        sd_sck,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n,
    // NEW: FPGA-SIM JSHLOAD pulse (tied 0 on the board)
    input  logic        sim_vm_start = 1'b0,
    // NEW: FPGA-SIM FRAME — pulse one frame_tick when already in S_WAIT_FRAME
    input  logic        sim_frame_pulse = 1'b0,
    // NEW: PROG FT245 .JSH stream (HTML RUN). Sim leaves these at default 0.
    input  logic        jsb_tether_stb = 1'b0,
    input  logic [7:0]  jsb_tether_data = 8'd0,
    input  logic        jsb_tether_eof = 1'b0,
    output logic        jsb_tether_rdy,
    // NEW: FPGA-SIM RAM LOAD — SOURCE poked by the host, LOAD skips FAT open
    input  logic        sim_src_bypass = 1'b0,
    input  logic [15:0] sim_src_lines = 16'd0,
    // NEW: asset SRAM port when SRAM_INTERNAL=0 (board MIG). Sim leaves defaults.
    output logic        sram_ext_req,
    output logic        sram_ext_we,
    output logic [20:0] sram_ext_addr,
    output logic [15:0] sram_ext_wdata,
    input  logic [15:0] sram_ext_rdata = 16'd0,
    input  logic        sram_ext_ack = 1'b0
);
    logic kbd_empty, kbd_full, kbd_pop, kbd_clear;
    logic [7:0] kbd_q;
    logic video_busy;
    logic cls, put_en, print_nl;
    logic [7:0] put_char;
    logic run_pulse;
    logic vm_start;
    logic halt_pulse;
    logic demo_busy, demo_done;
    logic vm_busy, vm_done;
    logic fb_we /*verilator public_flat_rd*/; logic fb_swap, demo_fb_we, demo_fb_swap, vm_fb_we, vm_fb_swap;
    logic [18:0] fb_waddr, demo_fb_waddr, vm_fb_waddr;
    logic [7:0]  fb_wdata, demo_fb_wdata, vm_fb_wdata;
    logic frame_tick;
    logic [15:0] frame_div /*verilator public_flat_rw*/;
    // NEW: console loads .JSB into VM code BRAM
    logic        code_we /*verilator public_flat_rd*/;
    logic [14:0]  code_waddr /*verilator public_flat_rd*/;
    logic [31:0] code_wdata /*verilator public_flat_rd*/;
    logic        stor_get_byte, stor_nl_scan;
    logic [7:0]  stor_get_data;
    logic [15:0] stor_nl_count;
    // NEW: 4 MB external asset SRAM (jmr_sram_port) — console writes the ASET
    // payload during RUN load; the VM blitter reads sprite pixels while running.
    // The two masters never overlap (load completes before vm_start).
    logic [6:0]  stor_dbg_state;
    logic [17:0] vm_src_setlen;
    logic        vm_src_setlen_stb;
    logic        cons_sram_req, cons_sram_we, vm_sram_req, vm_sram_we;
    logic [20:0] cons_sram_addr, vm_sram_addr;
    logic [15:0] cons_sram_wdata, vm_sram_wdata, sram_rdata;
    logic        sram_ack, sram_req, sram_we;
    logic [20:0] sram_addr;
    logic [15:0] sram_wdata;
    // NEW: ASET palette load (console) → palette BRAM (read by scanout/dump)
    logic        pal_we;
    logic [7:0]  pal_waddr;
    logic [23:0] pal_wdata;
    // NEW: VM getImageData reads the back bank (PYTHON canvas.back twin)
    logic [18:0] vm_dump_addr;
    logic        vm_dump_sel;
    logic [7:0]  dump_back_rdata;

    // Console ↔ storage
    logic        stor_open, stor_close, stor_readline, stor_putc;
    logic        stor_dir, stor_dir_next, stor_delete;
    logic [7:0]  stor_mode, stor_chan, stor_name_len, stor_putc_data;
    logic [15:0] stor_name_addr;
    logic        stor_busy, stor_done, stor_err, stor_eof;
    logic [7:0]  stor_line_len;

    // Mem masters
    logic        c_mem_en, c_mem_we, c_mem_gnt;
    logic [15:0] c_mem_addr;
    logic [7:0]  c_mem_wdata, c_mem_rdata;
    logic        s_mem_en, s_mem_we, s_mem_gnt;
    logic [15:0] s_mem_addr;
    logic [7:0]  s_mem_wdata, s_mem_rdata;

    assign joy_out = joy_in;

    // ---- work RAM 0xB000-0xDFFF (12 KB) — NAME/STORAGE only -------------
    // 2026-08-22: array moved to external SRAM (WORK_SRAM_BASE, 1 byte per
    // 16-bit word). Both masters already stall on gnt, so the variable
    // req/ack latency is safe by construction.
    localparam logic [20:0] WORK_SRAM_BASE = 21'd1634304;
    logic        ram_we;
    logic [13:0] ram_addr;
    logic [7:0]  ram_wdata, ram_rdata;
    logic        ram_req;
    logic        ram_sel_stor; // 1 = storage master won
    logic        work_req, work_we_l, work_ack, work_sel_stor;
    // 2026-08-27 DIR wedge (board E-telemetry: console stuck C_DIR_CH,
    // storage idle, 21.5s ?IO): the work-RAM request latch waits on the
    // sram fabric (DDR3 bridge on board) with no reissue protection — a
    // lost/misattributed ack starves it forever. Same class the VM port
    // already guards against (vm_ack_hold). Reissue after 2^12 idle-held
    // cycles (41us >> any legit bridge latency); work ops are idempotent
    // (byte reads / same-value writes) so reissue is safe.
    logic [11:0] work_wd;
    logic        work_pause;
    logic [13:0] work_addr_l;
    logic [7:0]  work_wdata_l;

    wire in_work_c = (c_mem_addr >= 16'hB000) && (c_mem_addr < 16'hE000);
    wire in_work_s = (s_mem_addr >= 16'hB000) && (s_mem_addr < 16'hE000);

    // Storage has priority when requesting (FAT walks cannot stall)
    always_comb begin
        ram_req = 1'b0;
        ram_we = 1'b0;
        ram_addr = 14'h0;
        ram_wdata = 8'h0;
        ram_sel_stor = 1'b0;
        if (s_mem_en && in_work_s) begin
            ram_req = 1'b1;
            ram_sel_stor = 1'b1;
            ram_we = s_mem_we;
            ram_addr = 14'(s_mem_addr - 16'hB000);
            ram_wdata = s_mem_wdata;
        end else if (c_mem_en && in_work_c) begin
            ram_req = 1'b1;
            ram_we = c_mem_we;
            ram_addr = 14'(c_mem_addr - 16'hB000);
            ram_wdata = c_mem_wdata;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ram_rdata <= 8'h00;
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            work_req <= 1'b0;
            work_wd <= 12'd0;
            work_pause <= 1'b0;
            work_we_l <= 1'b0;
            work_sel_stor <= 1'b0;
            work_addr_l <= '0;
            work_wdata_l <= '0;
        end else begin
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            if (work_pause) begin
                // one-cycle gap: fabric sees req fall, then the same latched
                // request re-presents (addr/data/sel untouched)
                work_pause <= 1'b0;
                work_req   <= 1'b1;
            end else if (work_req) begin
                if (work_ack) begin
                    work_req <= 1'b0;
                    work_wd  <= 12'd0;
                    ram_rdata <= work_we_l ? work_wdata_l : sram_rdata[7:0];
                    if (work_sel_stor) s_mem_gnt <= 1'b1;
                    else c_mem_gnt <= 1'b1;
                end else begin
                    work_wd <= work_wd + 12'd1;
                    if (&work_wd) begin
                        // ack lost: withdraw for one cycle and reissue
                        work_req   <= 1'b0;
                        work_pause <= 1'b1;
                        work_wd    <= 12'd0;
                    end
                end
            end else if (ram_req) begin
                work_req <= 1'b1;
                work_we_l <= ram_we;
                work_addr_l <= ram_addr;
                work_wdata_l <= ram_wdata;
                work_sel_stor <= ram_sel_stor;
            end
        end
    end
    assign s_mem_rdata = ram_rdata;
    assign c_mem_rdata = ram_rdata;

    jmr_keyboard_fifo u_kbd (
        .clk(clk), .rst_n(rst_n),
        .push(kbd_push), .push_data(kbd_data),
        .pop(kbd_pop), .clear(kbd_clear),
        .data(kbd_q), .empty(kbd_empty), .full(kbd_full)
    );

    jmr_video_vram u_vid (
        .clk(clk), .scan_clk(pixel_clk), .rst_n(rst_n),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .busy(video_busy), .cursor(cursor),
        .scan_addr(scan_addr), .scan_data(scan_data),
        .dump_addr(dump_addr), .dump_data(dump_data)
    );

    // Compile handshake: the console owns storage and the SOURCE window,
    // the VM runs the compiler as an ordinary program.
    logic [17:0] cons_src_len;
    logic        cmp_arm;

    jmr_console_engine u_cons (
        .clk(clk), .rst_n(rst_n),
        .enable(standalone_mode && !game_mode),
        .kbd_empty(kbd_empty), .kbd_data(kbd_q),
        .kbd_pop(kbd_pop), .kbd_clear(kbd_clear),
        .video_busy(video_busy),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .ready_lit(ready_lit),
        .src_len_o(cons_src_len),
        .src_setlen_i(vm_src_setlen),
        .src_setlen_stb_i(vm_src_setlen_stb),
        .cmp_done_i(vm_cmp_done),
        .cmp_status_i(vm_cmp_status),
        .cmp_len_i(vm_cmp_len),
        .vm_busy_i(vm_busy),
        .cmp_arm_o(cmp_arm),
        .dbg_state(cons_dbg_state_o),
        .run_pulse(run_pulse),
        .vm_start(vm_start),
        .halt_pulse(halt_pulse),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .sram_req(cons_sram_req), .sram_we(cons_sram_we),
        .sram_addr(cons_sram_addr), .sram_wdata(cons_sram_wdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd2)),
        .sram_rdata(sram_rdata),
        .pal_we(pal_we), .pal_waddr(pal_waddr), .pal_wdata(pal_wdata),
        .stor_open(stor_open), .stor_mode(stor_mode), .stor_chan(stor_chan),
        .stor_name_addr(stor_name_addr), .stor_name_len(stor_name_len),
        .stor_close(stor_close), .stor_readline(stor_readline),
        .stor_get_byte(stor_get_byte), .stor_get_data(stor_get_data),
        .stor_nl_scan(stor_nl_scan), .stor_nl_count(stor_nl_count),
        .stor_putc(stor_putc), .stor_putc_data(stor_putc_data),
        .stor_dir(stor_dir), .stor_dir_next(stor_dir_next), .stor_delete(stor_delete),
        .stor_busy(stor_busy), .stor_done(stor_done),
        .stor_err(stor_err), .stor_eof(stor_eof), .stor_line_len(stor_line_len),
        .mem_en(c_mem_en), .mem_we(c_mem_we), .mem_addr(c_mem_addr),
        .mem_wdata(c_mem_wdata), .mem_rdata(c_mem_rdata), .mem_gnt(c_mem_gnt),
        .jsb_tether_stb(jsb_tether_stb), .jsb_tether_data(jsb_tether_data),
        .jsb_tether_eof(jsb_tether_eof), .jsb_tether_rdy(jsb_tether_rdy),
        .sim_src_bypass(sim_src_bypass), .sim_src_lines(sim_src_lines)
    );

    storage_engine #(
        .SD_INIT_DIV(SD_INIT_DIV),
        .SD_RUN_DIV(SD_RUN_DIV)
    ) u_stor (
        .clk(clk), .rst_n(rst_n),
        .start_open(stor_open), .mode_in(stor_mode), .chan_in(stor_chan),
        .name_addr(stor_name_addr), .name_len(stor_name_len),
        .start_close(stor_close), .start_readline(stor_readline),
        .start_readfield(1'b0), .start_get_byte(stor_get_byte), .get_byte(stor_get_data),
        .start_nl_scan(stor_nl_scan), .nl_count(stor_nl_count),
        .start_putc(stor_putc), .putc_data(stor_putc_data),
        .start_dir(stor_dir), .start_dir_next(stor_dir_next),
        .start_delete(stor_delete),
        .card_present(sd_card_present),
        .dbg_state(stor_dbg_state),
        .line_len(stor_line_len), .eof(stor_eof), .err(stor_err),
        .done(stor_done), .busy(stor_busy),
        .sink_wr_en(1'b0), .sink_wr_char(8'h0), .sink_busy(),
        .mem_en(s_mem_en), .mem_we(s_mem_we), .mem_addr(s_mem_addr),
        .mem_wdata(s_mem_wdata), .mem_rdata(s_mem_rdata), .mem_gnt(s_mem_gnt),
        .spi_sck(sd_sck), .spi_mosi(sd_mosi), .spi_miso(sd_miso), .spi_cs_n(sd_cs_n)
    );

    // Session-1 (2026-08-23): single persistent draw bank; present engine
    // streams it to the DDR3 front; scanout prefetches lines back.
    logic [18:0] fbp_copy_raddr;
    logic [7:0]  fbp_copy_rdata;
    logic        fb_present_busy /*verilator public_flat_rd*/;
    logic        fbp_sram_req, fbp_sram_we;
    logic [20:0] fbp_sram_addr;
    logic [15:0] fbp_sram_wdata;
    logic        scan_sram_req;
    logic [20:0] scan_sram_addr;
    // C1 (run 50/51): full-rate raster/blit/imgd engine — the VM hands
    // per-op scalars over a go/busy handshake; the engine writes the FB
    // port at core rate and reads sprites/ImageData as arbiter owner 6.
    logic        rast_go, rast_busy, rast_aset;
    logic [1:0]  rast_mode;
    logic [9:0]  rast_dx, rast_dy, rast_w, rast_h;
    logic [7:0]  rast_color;
    logic [15:0] rast_sx, rast_sy, rast_qx, rast_rxr, rast_qy, rast_ryr;
    logic [21:0] rast_sbase;
    logic [15:0] rast_stride;
    logic        rast_fb_we;
    logic [18:0] rast_fb_waddr;
    logic [7:0]  rast_fb_wdata;
    logic        rast_sram_req;
    logic [20:0] rast_sram_addr;
    // rast_done: busy can rise AND fall between two VM beats (a 1x1
    // fill is ~2 clk) — a level the VM samples at beat rate, set on the
    // falling edge of busy, cleared at the next op's go edge (the
    // latch-until-beat pattern from TIMING_WALL Class A).
    logic rast_go_q, rast_busy_q, rast_done;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rast_go_q <= 1'b0;
            rast_busy_q <= 1'b0;
            rast_done <= 1'b0;
        end else begin
            rast_go_q <= rast_go;
            rast_busy_q <= rast_busy;
            if (rast_go && !rast_go_q) rast_done <= 1'b0;
            else if (rast_busy_q && !rast_busy) rast_done <= 1'b1;
        end
    end
    jmr_raster_engine u_rast (
        .clk(clk), .rst_n(rst_n),
        .go(rast_go), .mode(rast_mode),
        .dx(rast_dx), .dy(rast_dy), .w(rast_w), .h(rast_h),
        .color(rast_color),
        .sx(rast_sx), .sy(rast_sy),
        .qx(rast_qx), .rxr(rast_rxr), .qy(rast_qy), .ryr(rast_ryr),
        .sbase(rast_sbase), .stride(rast_stride), .aset(rast_aset),
        .busy(rast_busy),
        .fb_we(rast_fb_we), .fb_waddr(rast_fb_waddr), .fb_wdata(rast_fb_wdata),
        .sram_req(rast_sram_req), .sram_addr(rast_sram_addr),
        .sram_rdata(sram_rdata), .sram_ack(sram_ack && (sram_owner_q == 3'd6))
    );
    jmr_mini_fb u_fb (
        .wr_clk(clk), .rst_n(rst_n),
        .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
        .copy_raddr(fbp_copy_raddr), .copy_rdata(fbp_copy_rdata),
        .dump_raddr(vm_dump_sel ? vm_dump_addr : dump_fb_raddr),
        .dump_rdata(dump_fb_rdata)
    );
    // canvas is single-surface now: back/front dumps are the same data
    assign dump_back_rdata = dump_fb_rdata;
    assign stor_dbg_state_o = stor_dbg_state;
    assign game_view_o = game_view;
    logic game_mode_q2;
    always_ff @(posedge clk) game_mode_q2 <= game_mode;
    // Board 2026-08-26: the run-44 FB zero-fill ran, but scan switched
    // to the FB view immediately on game entry and showed the OLD DDR3
    // content during the ~10ms clear (the "previous game flash"). Hold
    // the view on the console until the clear pass completes.
    logic game_view;
    always_ff @(posedge clk) begin
        if (!rst_n || !game_mode) game_view <= 1'b0;
        else if (game_mode && game_mode_q2 && !fb_present_busy) game_view <= 1'b1;
    end
    jmr_fb_present u_fbpres (
        .clk(clk), .rst_n(rst_n),
        .clear_go(game_mode && !game_mode_q2), // scrub old FB on game entry
        .swap(fb_swap), .busy(fb_present_busy),
        .copy_raddr(fbp_copy_raddr), .copy_rdata(fbp_copy_rdata),
        .sram_req(fbp_sram_req), .sram_we(fbp_sram_we),
        .sram_addr(fbp_sram_addr), .sram_wdata(fbp_sram_wdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd4))
    );
    jmr_fb_scanout u_fbscan (
        .clk(clk), .rst_n(rst_n),
        .sram_req(scan_sram_req), .sram_addr(scan_sram_addr),
        .sram_rdata(sram_rdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd1)),
        .pixel_clk(pixel_clk),
        .fb_x(fb_x), .fb_y(fb_y),
        .fb_rdata(fb_rdata)
    );

    jmr_rectdemo_engine u_demo (
        .clk(clk), .rst_n(rst_n),
        .start(run_pulse),
        .busy(demo_busy), .done(demo_done),
        .fb_we(demo_fb_we), .fb_waddr(demo_fb_waddr),
        .fb_wdata(demo_fb_wdata), .fb_swap(demo_fb_swap)
    );

    // ~60 Hz frame tick for startLoop (100e6/60 ≈ 1.67e6)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            frame_div <= '0;
            frame_tick <= 1'b0;
        end else begin
            frame_tick <= 1'b0;
            if (frame_div == FRAME_DIV[15:0]) begin
                frame_div <= '0;
                frame_tick <= 1'b1;
            end else frame_div <= frame_div + 16'd1;
        end
    end

    // ------------------------------------------------------------------
    // div8 VM clock. BUFGCE keeps vm_clk rising edges a subset of clk
    // rising edges, so clk<->vm_clk boundary paths are ordinary same-tree
    // 10 ns paths (constraints/nexys_video.xdc adds the generated clock).
    // The Verilator branch has the same contract: vm_clk rises exactly at
    // clk edges where the registered vm_ce is high, so sim and silicon
    // sample identically at the boundary.
    logic vm_ce;
    logic vm_clk;
    generate if (VM_CLK_DIV == 1) begin : g_vmclk_pass
        assign vm_ce  = 1'b1;
        assign vm_clk = clk;
    end else begin : g_vmclk_div
        logic [$clog2(VM_CLK_DIV)-1:0] vmdiv_cnt;
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                vmdiv_cnt <= '0;
                vm_ce     <= 1'b0;
            end else begin
                vmdiv_cnt <= (vmdiv_cnt == VM_CLK_DIV - 1) ? '0 : vmdiv_cnt + 1'b1;
                vm_ce     <= (vmdiv_cnt == VM_CLK_DIV - 2);
            end
        end
`ifdef VERILATOR
        // BUFGCE latches CE while clk is LOW; gating with the raw vm_ce
        // glitches (vm_ce rises just after a posedge while clk is still
        // high -> spurious vm_clk edge mid-window, VM clocks twice per
        // beat: the event latch was consumed at the glitch edge AND the
        // real edge, double-enqueuing every key event). Register the
        // gate on negedge = exact BUFGCE semantics.
        logic vm_ce_n;
        always_ff @(negedge clk) vm_ce_n <= vm_ce;
        assign vm_clk = clk & vm_ce_n;
`else
        BUFGCE u_vm_bufgce (.I(clk), .CE(vm_ce), .O(vm_clk));
`endif
    end endgenerate

    // 100 MHz strobes last one clk cycle; the VM samples only on vm_ce
    // beats. Latch each until the beat that consumes it. Set wins over
    // clear: a strobe landing ON a beat is held for the next one (the
    // sampling edge reads the pre-edge value, so nothing is lost).
    logic       vm_start_lat, vm_stop_lat, vm_ftick_lat, vm_kev_lat;
    logic [7:0] vm_kev_code_lat;
    logic       vm_kev_down_lat;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vm_start_lat <= 1'b0; vm_stop_lat <= 1'b0;
            vm_ftick_lat <= 1'b0; vm_kev_lat  <= 1'b0;
            vm_kev_code_lat <= 8'd0; vm_kev_down_lat <= 1'b0;
        end else begin
            if (vm_start | sim_vm_start)  vm_start_lat <= 1'b1;
            else if (vm_ce)               vm_start_lat <= 1'b0;
            if ((kbd_push && kbd_data == 8'h1B) || halt_pulse)
                                          vm_stop_lat <= 1'b1;
            else if (vm_ce)               vm_stop_lat <= 1'b0;
            if (frame_tick | sim_frame_pulse) vm_ftick_lat <= 1'b1;
            else if (vm_ce)               vm_ftick_lat <= 1'b0;
            if (key_evt_stb) begin
                vm_kev_lat      <= 1'b1;
                vm_kev_code_lat <= key_evt_code;
                vm_kev_down_lat <= key_evt_down;
            end else if (vm_ce)           vm_kev_lat <= 1'b0;
        end
    end

    // sram ack shim. The arbiter ack is one clk cycle; the VM samples on
    // vm_ce beats only, and its FSM does not obey either simple contract:
    // some seams re-arm sram_req for the NEXT transaction on the very
    // consume beat (sprite demand-load -> first blit fetch), and some
    // sites issue a request but sample the ack several beats later. So
    // the hold is MATCH-based: latch the served request (addr/we/wdata)
    // with the ack, deliver the ack only while the VM's live request
    // still equals the held one, and clear only at a beat where it no
    // longer matches (transaction consumed or superseded). A same-request
    // re-delivery is idempotent (same-addr read returns the same data; a
    // same-addr/wdata write already committed); a changed request drops
    // the orphan and is re-served one beat later. The arbiter's VM grant
    // is blocked while anything is held, so at most one serve is in
    // flight per beat window and an ack can never race a consume.
    logic        vm_ack_hold;
    logic [15:0] vm_rdata_hold;
    logic [20:0] vm_held_addr;
    logic        vm_held_we;
    logic [15:0] vm_held_wdata;
    logic        vm_req_match;

    // Compile handshake between the console (which owns storage and the
    // SOURCE window) and the VM (which runs the compiler as a program).
    logic        vm_cmp_done;
    logic [7:0]  vm_cmp_status;
    logic [20:0] vm_cmp_len;
    logic [6:0]  vm_cmp_msglen;

    jmr_js_vm #(.CODE_HEX("invaders_jsb.hex")) u_vm (
        .clk(vm_clk), .clk_code_w(clk), .rst_n(rst_n),
        .start(vm_start_lat),
        // V1.5 standalone compile: source length in, exit report out.
        .src_len_i(cons_src_len),
        .src_setlen_o(vm_src_setlen),
        .src_setlen_stb_o(vm_src_setlen_stb),
        .cmp_done_o(vm_cmp_done),
        .cmp_status_o(vm_cmp_status),
        .cmp_len_o(vm_cmp_len),
        .cmp_msglen_o(vm_cmp_msglen),
        .stop(vm_stop_lat),
        .frame_tick(vm_ftick_lat),
        .joy_in(joy_in),
        .key_evt_stb(vm_kev_lat),
        .key_evt_code(vm_kev_code_lat),
        .key_evt_down(vm_kev_down_lat),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .busy(vm_busy), .done(vm_done),
        .vdbg_o(vdbg_o), .vdbg_fault_o(vdbg_fault_o),
        .vm_hdbg(vm_hdbg), .vm_fdbg(vm_fdbg), .vm_fdbg_v(vm_fdbg_v),
        .vm_ftrace(vm_ftrace),
        .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .fb_we(vm_fb_we), .fb_waddr(vm_fb_waddr),
        .fb_wdata(vm_fb_wdata), .fb_swap(vm_fb_swap),
        .fb_present_busy(fb_present_busy),
        .fb_dump_addr(vm_dump_addr), .fb_dump_sel(vm_dump_sel),
        .fb_dump_back(dump_back_rdata),
        .fb_dump_front(dump_fb_rdata),
        .sram_req(vm_sram_req), .sram_addr(vm_sram_addr),
        .sram_we(vm_sram_we), .sram_wdata(vm_sram_wdata),
        .sram_rdata(vm_ack_hold ? vm_rdata_hold : sram_rdata),
        .sram_ack(vm_ack_hold && vm_req_match_q),
        .rast_go(rast_go), .rast_mode(rast_mode),
        .rast_dx(rast_dx), .rast_dy(rast_dy),
        .rast_w(rast_w), .rast_h(rast_h),
        .rast_color(rast_color),
        .rast_sx(rast_sx), .rast_sy(rast_sy),
        .rast_qx(rast_qx), .rast_rxr(rast_rxr),
        .rast_qy(rast_qy), .rast_ryr(rast_ryr),
        .rast_sbase(rast_sbase), .rast_stride(rast_stride),
        .rast_aset(rast_aset),
        .rast_done(rast_done)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vm_ack_hold   <= 1'b0;
            vm_rdata_hold <= 16'd0;
        end else if (sram_ack && (sram_owner_q == 3'd5)) begin
            vm_ack_hold   <= 1'b1;
            vm_rdata_hold <= sram_rdata;
            vm_held_addr  <= sram_addr;
            vm_held_we    <= sram_we;
            vm_held_wdata <= sram_wdata;
        end else if (vm_ce && !vm_req_match) begin
            vm_ack_hold   <= 1'b0;
        end
    end
    assign vm_req_match = vm_sram_req
        && (vm_held_addr == vm_sram_addr)
        && (vm_held_we == vm_sram_we)
        && (!vm_sram_we || (vm_held_wdata == vm_sram_wdata));
    // Registered copy for the DELIVERY side only (run-32: the comb
    // compare fed VM clock-enables at -0.13). Both compare operands are
    // stable from the ack to the beat that consumes it (the VM holds its
    // request while waiting; held_* freeze at the ack), so the one-clk
    // lag never changes the delivered value: an ack at clk j is
    // consumable at the beat >= j+1, exactly as before. The hold-clear
    // keeps the comb match (core-internal, short).
    logic vm_req_match_q;
    always_ff @(posedge clk) vm_req_match_q <= vm_req_match;

    // Asset-SRAM arbiter — console (load) wins; the VM reads sprite pixels
    // and, since 2026-08-21, also streams the ImageData snapshot (read AND
    // write) at the top of the bank. The two masters still never overlap
    // (load completes before vm_start).
    // Owner is latched per transaction so a request that arrives mid-flight
    // cannot steal the address/ack. Priority (Session-1): scanout line
    // prefetch is TOP (a starved line buffer is visible glass) > console
    // (load) > work RAM > FB present > VM.
    // Run 55 (-0.270 family, run 54): per-client ACK gates use the
    // REGISTERED owner. The comb sram_owner resolves the next grant from
    // live requests (incl. vm_sram_req on vm_clk), so gating acks with
    // it dragged the whole request cone into every client's clock-enable
    // (worst: vm_sram_req -> fbscan linebuf CE, 8 levels). Logically a
    // false path — an ack implies the owner was latched — but the tools
    // cannot see that. Every ack source (sim model, bridge cache/merge/
    // read) is registered >=1 cycle after grant, so sram_owner_q is
    // always valid at ack time. Request-side muxes stay comb (they must
    // present the request at grant).
    logic [2:0] sram_owner_q;
    logic [2:0] sram_owner;
    always_comb begin
        sram_owner = sram_owner_q;
        if (sram_owner_q == 3'd0) begin
            if (scan_sram_req)      sram_owner = 3'd1;
            else if (cons_sram_req) sram_owner = 3'd2;
            else if (work_req)      sram_owner = 3'd3;
            else if (fbp_sram_req)  sram_owner = 3'd4;
            else if (rast_sram_req) sram_owner = 3'd6;
            else if (vm_sram_req && !vm_ack_hold) sram_owner = 3'd5;
        end
    end
    always_ff @(posedge clk) begin
        if (!rst_n) sram_owner_q <= 3'd0;
        else        sram_owner_q <= sram_ack ? 3'd0 : sram_owner;
    end
    assign sram_req   = (sram_owner == 3'd1) ? scan_sram_req :
                        (sram_owner == 3'd2) ? cons_sram_req :
                        (sram_owner == 3'd3) ? work_req :
                        (sram_owner == 3'd4) ? fbp_sram_req :
                        (sram_owner == 3'd6) ? rast_sram_req :
                        (sram_owner == 3'd5) ? vm_sram_req : 1'b0;
    assign sram_we    = (sram_owner == 3'd2) ? cons_sram_we :
                        (sram_owner == 3'd3) ? work_we_l :
                        (sram_owner == 3'd4) ? fbp_sram_we :
                        (sram_owner == 3'd5) ? vm_sram_we : 1'b0; // 6: read-only
    assign sram_addr  = (sram_owner == 3'd1) ? scan_sram_addr :
                        (sram_owner == 3'd2) ? cons_sram_addr :
                        (sram_owner == 3'd3) ? (WORK_SRAM_BASE + 21'(work_addr_l)) :
                        (sram_owner == 3'd4) ? fbp_sram_addr :
                        (sram_owner == 3'd6) ? rast_sram_addr :
                                               vm_sram_addr;
    assign sram_wdata = (sram_owner == 3'd2) ? cons_sram_wdata :
                        (sram_owner == 3'd3) ? {8'd0, work_wdata_l} :
                        (sram_owner == 3'd4) ? fbp_sram_wdata : vm_sram_wdata;
    assign work_ack   = sram_ack && (sram_owner_q == 3'd3);

    // NEW: behavioral 4 MB SRAM (FPGA-SIM, SRAM_INTERNAL=1). Board uses
    // #(.SRAM_INTERNAL(0)) and the MIG DDR3 bridge on these ports.
    generate
        if (SRAM_INTERNAL) begin : g_sram
            jmr_sram_model u_sram (
                .clk(clk), .rst_n(rst_n),
                .req(sram_req), .we(sram_we), .addr(sram_addr),
                .wdata(sram_wdata), .rdata(sram_rdata), .ack(sram_ack)
            );
            assign sram_ext_req   = 1'b0;
            assign sram_ext_we    = 1'b0;
            assign sram_ext_addr  = 21'd0;
            assign sram_ext_wdata = 16'd0;
        end else begin : g_ext
            assign sram_ext_req   = sram_req;
            assign sram_ext_we    = sram_we;
            assign sram_ext_addr  = sram_addr;
            assign sram_ext_wdata = sram_wdata;
            assign sram_rdata     = sram_ext_rdata;
            assign sram_ack       = sram_ext_ack;
        end
    endgenerate

    // NEW: per-title 256-entry palette (loaded from the ASET section on RUN)
    jmr_palette_bram u_palette (
        .wr_clk(clk), .rd_clk(pixel_clk),
        .we(pal_we), .waddr(pal_waddr), .wdata(pal_wdata),
        .raddr(pal_raddr), .rdata(pal_rdata)
    );

    // Mux FB writers — VM preferred while busy
    // C1: the raster engine owns the FB write port while busy — the VM
    // is blocked on rast_busy then, so the paths are mutually exclusive
    // by the handshake, and the mux only arbitrates the idle default.
    // Select on busy OR the write itself: the engine's LAST pixel write
    // asserts one clk after busy falls (registered fb_we), and a 1x1 op
    // IS its last pixel — keying on busy alone dropped it.
    assign fb_we    = (rast_busy || rast_fb_we) ? rast_fb_we    : vm_busy ? vm_fb_we    : demo_fb_we;
    assign fb_waddr = (rast_busy || rast_fb_we) ? rast_fb_waddr : vm_busy ? vm_fb_waddr : demo_fb_waddr;
    assign fb_wdata = (rast_busy || rast_fb_we) ? rast_fb_wdata : vm_busy ? vm_fb_wdata : demo_fb_wdata;
    // vm_fb_swap is a vm_clk-wide pulse (= VM_CLK_DIV clk cycles); the
    // present engine consumes edges at 100 MHz, so pass only the rise.
    logic vm_fb_swap_q;
    always_ff @(posedge clk) vm_fb_swap_q <= vm_fb_swap;
    assign fb_swap  = vm_busy ? (vm_fb_swap && !vm_fb_swap_q) : demo_fb_swap;

    always_ff @(posedge clk) begin
        if (!rst_n) game_mode <= 1'b0;
        else if ((kbd_push && kbd_data == 8'h1B) || halt_pulse) game_mode <= 1'b0;
        // Enter on RUN/vm_start only. demo_busy/vm_busy must not retrigger
        // after ESC — console enable is !game_mode, so LIST after RUN died.
        // cmp_arm: a compile runs the VM without becoming a GAME. The text
        // screen stays up, READY stays dark, and the RUN path is untouched.
        // Cheaper and safer than consuming vm_done to undo a game_mode we
        // never needed to enter — that edge would touch every title.
        else if ((run_pulse || vm_start || sim_vm_start) && !cmp_arm)
            game_mode <= 1'b1;
    end
endmodule
