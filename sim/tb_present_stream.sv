module tb_present_stream (
    input logic clk, rst_n, swap, clear_go, ack,
    input logic we,
    input logic [18:0] waddr,
    input logic [7:0] wdata,
    output logic busy, req,
    output logic [20:0] addr,
    output logic [15:0] data
);
    logic [18:0] copy_addr;
    logic [7:0] copy_data, unused;
    logic is_write;
    jmr_mini_fb fb(.wr_clk(clk), .rst_n(rst_n), .we(we),
        .waddr(waddr), .wdata(wdata), .copy_raddr(copy_addr),
        .copy_rdata(copy_data), .dump_raddr(19'd0), .dump_rdata(unused));
    jmr_fb_present dut(.clk(clk), .rst_n(rst_n), .swap(swap),
        .clear_go(clear_go), .busy(busy), .copy_raddr(copy_addr),
        .copy_rdata(copy_data), .sram_req(req), .sram_we(is_write),
        .sram_addr(addr), .sram_wdata(data), .sram_ack(ack));
endmodule
