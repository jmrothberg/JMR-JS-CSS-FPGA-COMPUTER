// Actual present and DDR3 bridge; only the MIG application port is modeled.
module tb_present_bridge #(parameter bit DIRTY_COPY = 0)(
 input logic clk,rst_n,swap,clear_go,we,flush,
 input logic [18:0] waddr,input logic [7:0] wdata,
 input logic verify_addr_valid,input logic [21:0] verify_addr,
 output logic busy,req_o,we_o,ack_o,
 output logic [21:0] addr_o,output logic [15:0] data_o,rdata_o,
 output logic [28:0] app_addr, output logic [2:0] app_cmd,
 output logic app_en,app_wdf_end,app_wdf_wren,
 output logic [127:0] app_wdf_data,output logic [15:0] app_wdf_mask,
 input logic [127:0] app_rd_data,input logic app_rd_data_valid,app_rdy,app_wdf_rdy
);
 logic [18:0] craddr;logic [7:0] crdata,unused;
 logic preq,pwe;logic [21:0] paddr;logic [15:0] pdata;
 logic [1199:0] dirty_blocks;logic dirty_clear;
 jmr_mini_fb fb(.wr_clk(clk),.rst_n(rst_n),.we(we),.address_we(we),.waddr(waddr),.wdata(wdata),
  .dirty_blocks(dirty_blocks),.dirty_clear(dirty_clear),
  .copy_raddr(craddr),.copy_rdata(crdata),.dump_raddr(19'd0),.dump_rdata(unused));
 jmr_fb_present #(.DIRTY_COPY(DIRTY_COPY)) pres(.clk(clk),.rst_n(rst_n),.swap(swap),.clear_go(clear_go),.busy(busy),
  .dirty_blocks(dirty_blocks),.dirty_clear(dirty_clear),
  .copy_raddr(craddr),.copy_rdata(crdata),.sram_req(preq),.sram_we(pwe),
  .sram_addr(paddr),.sram_wdata(pdata),.sram_ack(ack_o&&!flush));
 assign req_o=flush||preq;assign we_o=flush?1'b0:pwe;
 assign addr_o=flush?(verify_addr_valid?verify_addr:22'd3731455):paddr;
 assign data_o=pdata;
 jmr_ddr3_sram_bridge bridge(.clk(clk),.rst_n(rst_n),.calib_done(1'b1),
  .req(req_o),.we(we_o),.addr(addr_o),.wdata(data_o),.rdata(rdata_o),.ack(ack_o),
  .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_wdf_data(app_wdf_data),
  .app_wdf_end(app_wdf_end),.app_wdf_mask(app_wdf_mask),.app_wdf_wren(app_wdf_wren),
  .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),
  .app_rdy(app_rdy),.app_wdf_rdy(app_wdf_rdy));
endmodule
