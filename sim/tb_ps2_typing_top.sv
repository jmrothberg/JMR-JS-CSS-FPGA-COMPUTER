// PS/2 typing harness — waveform → ASCII → console HELP reply in char VRAM.
module tb_ps2_typing_top (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    input  logic [9:0] dump_addr,
    output logic [7:0] dump_data,
    output logic       ready_lit,
    output logic       ascii_strobe_mon,
    output logic [7:0] ascii_mon
);
    logic [7:0] scancode;
    logic       strobe, parity_err;
    logic [7:0] ascii;
    logic       ascii_strobe;
    logic       kbd_empty, kbd_full, kbd_pop, kbd_clear;
    logic [7:0] kbd_q;
    logic       video_busy, cls, put_en, print_nl;
    logic [7:0] put_char;
    logic [9:0] cursor, scan_addr;
    logic [7:0] scan_data;
    logic       run_pulse, vm_start;

    // Unused storage stubs (HELP/DIR path only needs replies)
    logic stor_busy, stor_done, stor_err, stor_eof;
    logic [7:0] stor_line_len;
    logic mem_en, mem_we, mem_gnt;
    logic [15:0] mem_addr;
    logic [7:0] mem_wdata, mem_rdata;

    assign stor_busy = 1'b0;
    assign stor_done = 1'b0;
    assign stor_err = 1'b0;
    assign stor_eof = 1'b1;
    assign stor_line_len = 8'd0;
    assign mem_gnt = mem_en;
    assign mem_rdata = 8'h00;
    assign ascii_strobe_mon = ascii_strobe;
    assign ascii_mon = ascii;
    assign scan_addr = 10'd0;

    ps2_rx u_rx (
        .clk(clk), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .scancode(scancode), .strobe(strobe), .parity_err(parity_err)
    );
    ps2_decode u_dec (
        .clk(clk), .rst_n(rst_n),
        .scancode(scancode), .strobe(strobe),
        .ascii(ascii), .ascii_strobe(ascii_strobe)
    );
    jmr_keyboard_fifo u_fifo (
        .clk(clk), .rst_n(rst_n),
        .push(ascii_strobe), .push_data(ascii),
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
        .enable(1'b1),
        .kbd_empty(kbd_empty), .kbd_data(kbd_q),
        .kbd_pop(kbd_pop), .kbd_clear(kbd_clear),
        .video_busy(video_busy),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .ready_lit(ready_lit),
        .run_pulse(run_pulse), .vm_start(vm_start),
        .stor_open(), .stor_mode(), .stor_chan(),
        .stor_name_addr(), .stor_name_len(),
        .stor_close(), .stor_readline(),
        .stor_putc(), .stor_putc_data(),
        .stor_dir(), .stor_dir_next(), .stor_delete(),
        .stor_busy(stor_busy), .stor_done(stor_done),
        .stor_err(stor_err), .stor_eof(stor_eof), .stor_line_len(stor_line_len),
        .mem_en(mem_en), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata), .mem_gnt(mem_gnt)
    );
endmodule
