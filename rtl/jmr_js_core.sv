// Shared JS-native core — Verilator tops this; board top is PHY shell only.
// Pattern cite: BASIC jmr_core + standalone_mode.
// NEW: storage_engine + work/source BRAM for DIR/LOAD/SAVE/REMOVE.
module jmr_js_core #(
    parameter int unsigned SD_INIT_DIV = 127,
    parameter int unsigned SD_RUN_DIV  = 3,
    // NEW: FPGA-SIM FRAME_DIV=1 (one tick per ~2 clk when idle). Board keeps 65535.
    parameter int unsigned FRAME_DIV   = 65535
) (
    input  logic        clk,
    input  logic        pixel_clk,   // mini-FB read domain (board HDMI)
    input  logic        rst_n,
    input  logic        standalone_mode,
    input  logic        kbd_push,
    input  logic [7:0]  kbd_data,
    input  logic [5:0]  joy_in,
    output logic [5:0]  joy_out,
    // NEW: raw keyboard events for games (sim KEYEVT / board PS/2 decode)
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
    input  logic [18:0] fb_raddr,
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
    input  logic [15:0] sim_src_lines = 16'd0
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
    logic fb_we, fb_swap, demo_fb_we, demo_fb_swap, vm_fb_we, vm_fb_swap;
    logic [18:0] fb_waddr, demo_fb_waddr, vm_fb_waddr;
    logic [7:0]  fb_wdata, demo_fb_wdata, vm_fb_wdata;
    logic frame_tick;
    logic [15:0] frame_div /*verilator public_flat_rw*/;
    // NEW: console loads .JSB into VM code BRAM
    logic        code_we;
    logic [14:0]  code_waddr;
    logic [31:0] code_wdata;
    logic        stor_get_byte, stor_nl_scan;
    logic [7:0]  stor_get_data;
    logic [15:0] stor_nl_count;
    // NEW: 4 MB external asset SRAM (jmr_sram_port) — console writes the ASET
    // payload during RUN load; the VM blitter reads sprite pixels while running.
    // The two masters never overlap (load completes before vm_start).
    logic        cons_sram_req, cons_sram_we, vm_sram_req;
    logic [20:0] cons_sram_addr, vm_sram_addr;
    logic [15:0] cons_sram_wdata, sram_rdata;
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
    // Indexed by addr[13:0] relative to 0xB000. Registered 1-cycle read.
    (* ram_style = "block" *) logic [7:0] work_ram [0:12287];
    logic        ram_we;
    logic [13:0] ram_addr;
    logic [7:0]  ram_wdata, ram_rdata;
    logic        ram_req, ram_req_q;
    logic        ram_sel_stor; // 1 = storage master won
    // NEW: 2-cycle RAM — latch addr then access+gnt (closes state→RAM→rdata WNS)
    logic        ram_pend;
    logic        ram_pend_we, ram_pend_stor;
    logic [13:0] ram_pend_addr;
    logic [7:0]  ram_pend_wdata;

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
            ram_req_q <= 1'b0;
            ram_rdata <= 8'h00;
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            ram_pend <= 1'b0;
            ram_pend_we <= 1'b0;
            ram_pend_stor <= 1'b0;
            ram_pend_addr <= '0;
            ram_pend_wdata <= '0;
        end else begin
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            if (ram_pend) begin
                if (ram_pend_we) work_ram[ram_pend_addr] <= ram_pend_wdata;
                ram_rdata <= ram_pend_we ? ram_pend_wdata : work_ram[ram_pend_addr];
                if (ram_pend_stor) s_mem_gnt <= 1'b1;
                else c_mem_gnt <= 1'b1;
                ram_pend <= 1'b0;
                ram_req_q <= 1'b1;
            end else if (ram_req) begin
                ram_pend <= 1'b1;
                ram_pend_addr <= ram_addr;
                ram_pend_we <= ram_we;
                ram_pend_wdata <= ram_wdata;
                ram_pend_stor <= ram_sel_stor;
                ram_req_q <= 1'b0;
            end else begin
                ram_req_q <= 1'b0;
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

    jmr_console_engine u_cons (
        .clk(clk), .rst_n(rst_n),
        .enable(standalone_mode && !game_mode),
        .kbd_empty(kbd_empty), .kbd_data(kbd_q),
        .kbd_pop(kbd_pop), .kbd_clear(kbd_clear),
        .video_busy(video_busy),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .ready_lit(ready_lit),
        .run_pulse(run_pulse),
        .vm_start(vm_start),
        .halt_pulse(halt_pulse),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .sram_req(cons_sram_req), .sram_we(cons_sram_we),
        .sram_addr(cons_sram_addr), .sram_wdata(cons_sram_wdata),
        .sram_ack(sram_ack),
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
        .line_len(stor_line_len), .eof(stor_eof), .err(stor_err),
        .done(stor_done), .busy(stor_busy),
        .sink_wr_en(1'b0), .sink_wr_char(8'h0), .sink_busy(),
        .mem_en(s_mem_en), .mem_we(s_mem_we), .mem_addr(s_mem_addr),
        .mem_wdata(s_mem_wdata), .mem_rdata(s_mem_rdata), .mem_gnt(s_mem_gnt),
        .spi_sck(sd_sck), .spi_mosi(sd_mosi), .spi_miso(sd_miso), .spi_cs_n(sd_cs_n)
    );

    jmr_mini_fb u_fb (
        .wr_clk(clk), .rd_clk(pixel_clk), .rst_n(rst_n),
        .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata), .swap(fb_swap),
        .raddr(fb_raddr), .rdata(fb_rdata),
        .dump_raddr(vm_dump_sel ? vm_dump_addr : dump_fb_raddr),
        .dump_rdata(dump_fb_rdata),
        .dump_back_rdata(dump_back_rdata)
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

    jmr_js_vm #(.CODE_HEX("invaders_jsb.hex")) u_vm (
        .clk(clk), .rst_n(rst_n),
        .start(vm_start | sim_vm_start),
        .stop((kbd_push && kbd_data == 8'h1B) || halt_pulse),
        .frame_tick(frame_tick | sim_frame_pulse),
        .joy_in(joy_in),
        .key_evt_stb(key_evt_stb),
        .key_evt_code(key_evt_code),
        .key_evt_down(key_evt_down),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .busy(vm_busy), .done(vm_done),
        .fb_we(vm_fb_we), .fb_waddr(vm_fb_waddr),
        .fb_wdata(vm_fb_wdata), .fb_swap(vm_fb_swap),
        .fb_dump_addr(vm_dump_addr), .fb_dump_sel(vm_dump_sel),
        .fb_dump_back(dump_back_rdata),
        .sram_req(vm_sram_req), .sram_addr(vm_sram_addr),
        .sram_rdata(sram_rdata), .sram_ack(sram_ack)
    );

    // NEW: asset-SRAM arbiter — console (load) wins; VM only reads while running
    assign sram_req   = cons_sram_req | vm_sram_req;
    assign sram_we    = cons_sram_req ? cons_sram_we : 1'b0;
    assign sram_addr  = cons_sram_req ? cons_sram_addr : vm_sram_addr;
    assign sram_wdata = cons_sram_wdata;

    // NEW: behavioral 4 MB SRAM (FPGA-SIM). Board build swaps this instance
    // for the MIG DDR3 bridge behind the identical port; ASIC uses the real
    // IS61WV204816 — nothing above the port changes.
    jmr_sram_model u_sram (
        .clk(clk), .rst_n(rst_n),
        .req(sram_req), .we(sram_we), .addr(sram_addr),
        .wdata(sram_wdata), .rdata(sram_rdata), .ack(sram_ack)
    );

    // NEW: per-title 256-entry palette (loaded from the ASET section on RUN)
    jmr_palette_bram u_palette (
        .clk(clk), .we(pal_we), .waddr(pal_waddr), .wdata(pal_wdata),
        .raddr(pal_raddr), .rdata(pal_rdata)
    );

    // Mux FB writers — VM preferred while busy
    assign fb_we    = vm_busy ? vm_fb_we    : demo_fb_we;
    assign fb_waddr = vm_busy ? vm_fb_waddr : demo_fb_waddr;
    assign fb_wdata = vm_busy ? vm_fb_wdata : demo_fb_wdata;
    assign fb_swap  = vm_busy ? vm_fb_swap  : demo_fb_swap;

    always_ff @(posedge clk) begin
        if (!rst_n) game_mode <= 1'b0;
        else if ((kbd_push && kbd_data == 8'h1B) || halt_pulse) game_mode <= 1'b0;
        // Enter on RUN/vm_start only. demo_busy/vm_busy must not retrigger
        // after ESC — console enable is !game_mode, so LIST after RUN died.
        else if (run_pulse || vm_start || sim_vm_start)
            game_mode <= 1'b1;
    end
endmodule
