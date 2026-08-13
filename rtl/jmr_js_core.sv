// Shared JS-native core — Verilator tops this; board top is PHY shell only.
// Pattern cite: BASIC jmr_core + standalone_mode.
// NEW: storage_engine + work/source BRAM for DIR/LOAD/SAVE/REMOVE.
module jmr_js_core #(
    parameter int unsigned SD_INIT_DIV = 127,
    parameter int unsigned SD_RUN_DIV  = 3
) (
    input  logic        clk,
    input  logic        pixel_clk,   // mini-FB read domain (board HDMI)
    input  logic        rst_n,
    input  logic        standalone_mode,
    input  logic        kbd_push,
    input  logic [7:0]  kbd_data,
    input  logic [5:0]  joy_in,
    output logic [5:0]  joy_out,
    input  logic [9:0]  dump_addr,
    output logic [7:0]  dump_data,
    output logic [9:0]  cursor,
    output logic        ready_lit,
    input  logic [9:0]  scan_addr,
    output logic [7:0]  scan_data,
    // Mini-canvas scanout (game mode)
    output logic        game_mode,
    input  logic [14:0] fb_raddr,
    output logic [7:0]  fb_rdata,
    // NEW: tether FB dump (core clk) — full 640×480 mirror path
    input  logic [14:0] dump_fb_raddr = 15'd0,
    output logic [7:0]  dump_fb_rdata,
    // NEW: µSD SPI (storage_engine owns the master)
    output logic        sd_sck,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n
);
    logic kbd_empty, kbd_full, kbd_pop, kbd_clear;
    logic [7:0] kbd_q;
    logic video_busy;
    logic cls, put_en, print_nl;
    logic [7:0] put_char;
    logic run_pulse;
    logic vm_start;
    logic demo_busy, demo_done;
    logic vm_busy, vm_done;
    logic fb_we, fb_swap, demo_fb_we, demo_fb_swap, vm_fb_we, vm_fb_swap;
    logic [14:0] fb_waddr, demo_fb_waddr, vm_fb_waddr;
    logic [7:0]  fb_wdata, demo_fb_wdata, vm_fb_wdata;
    logic frame_tick;
    logic [15:0] frame_div;

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

    // ---- work RAM 0xB000-0xDFFF (12 KB) — NAME/STORAGE/SOURCE ------------
    // Indexed by addr[13:0] relative to 0xB000. Registered 1-cycle read.
    (* ram_style = "block" *) logic [7:0] work_ram [0:12287];
    logic        ram_we;
    logic [13:0] ram_addr;
    logic [7:0]  ram_wdata, ram_rdata;
    logic        ram_req, ram_req_q;
    logic        ram_sel_stor; // 1 = storage master won

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
        end else begin
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            if (ram_req) begin
                if (ram_we) work_ram[ram_addr] <= ram_wdata;
                ram_rdata <= work_ram[ram_addr];
                // write-first: readback shows new data on write
                if (ram_we) ram_rdata <= ram_wdata;
                ram_req_q <= 1'b1;
                if (ram_sel_stor) s_mem_gnt <= 1'b1;
                else c_mem_gnt <= 1'b1;
            end else ram_req_q <= 1'b0;
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
        .clk(clk), .rst_n(rst_n),
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
        .stor_open(stor_open), .stor_mode(stor_mode), .stor_chan(stor_chan),
        .stor_name_addr(stor_name_addr), .stor_name_len(stor_name_len),
        .stor_close(stor_close), .stor_readline(stor_readline),
        .stor_putc(stor_putc), .stor_putc_data(stor_putc_data),
        .stor_dir(stor_dir), .stor_dir_next(stor_dir_next), .stor_delete(stor_delete),
        .stor_busy(stor_busy), .stor_done(stor_done),
        .stor_err(stor_err), .stor_eof(stor_eof), .stor_line_len(stor_line_len),
        .mem_en(c_mem_en), .mem_we(c_mem_we), .mem_addr(c_mem_addr),
        .mem_wdata(c_mem_wdata), .mem_rdata(c_mem_rdata), .mem_gnt(c_mem_gnt)
    );

    storage_engine #(
        .SD_INIT_DIV(SD_INIT_DIV),
        .SD_RUN_DIV(SD_RUN_DIV)
    ) u_stor (
        .clk(clk), .rst_n(rst_n),
        .start_open(stor_open), .mode_in(stor_mode), .chan_in(stor_chan),
        .name_addr(stor_name_addr), .name_len(stor_name_len),
        .start_close(stor_close), .start_readline(stor_readline),
        .start_readfield(1'b0), .start_get_byte(1'b0), .get_byte(),
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
        .dump_raddr(dump_fb_raddr), .dump_rdata(dump_fb_rdata)
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
            if (frame_div == 16'd65535) begin
                frame_div <= '0;
                frame_tick <= 1'b1;
            end else frame_div <= frame_div + 16'd1;
        end
    end

    jmr_js_vm #(.CODE_HEX("invaders_jsb.hex")) u_vm (
        .clk(clk), .rst_n(rst_n),
        .start(vm_start),
        .stop(kbd_push && kbd_data == 8'h1B),
        .frame_tick(frame_tick),
        .joy_in(joy_in),
        .busy(vm_busy), .done(vm_done),
        .fb_we(vm_fb_we), .fb_waddr(vm_fb_waddr),
        .fb_wdata(vm_fb_wdata), .fb_swap(vm_fb_swap)
    );

    // Mux FB writers — VM preferred while busy
    assign fb_we    = vm_busy ? vm_fb_we    : demo_fb_we;
    assign fb_waddr = vm_busy ? vm_fb_waddr : demo_fb_waddr;
    assign fb_wdata = vm_busy ? vm_fb_wdata : demo_fb_wdata;
    assign fb_swap  = vm_busy ? vm_fb_swap  : demo_fb_swap;

    always_ff @(posedge clk) begin
        if (!rst_n) game_mode <= 1'b0;
        else if (kbd_push && kbd_data == 8'h1B) game_mode <= 1'b0;
        else if (run_pulse || demo_busy || demo_done || vm_start || vm_busy)
            game_mode <= 1'b1;
    end
endmodule
