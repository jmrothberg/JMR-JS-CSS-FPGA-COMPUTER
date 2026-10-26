// Actual ImageData engine and bridge; only the MIG application port is modeled.
module tb_raster_bridge(
 input logic clk,rst_n,go,flip_x,flip_y,
 input logic signed [11:0] dx,dy,input logic [9:0] w,h,
 input logic [21:0] source,
 output logic busy,fb_we,req_o,ack_o,
 output logic [18:0] fb_addr,output logic [7:0] fb_data,
 output logic [20:0] addr_o,
 output logic [28:0] app_addr,output logic [2:0] app_cmd,
 output logic app_en,app_wdf_end,app_wdf_wren,
 output logic [127:0] app_wdf_data,output logic [15:0] app_wdf_mask,
 input logic [127:0] app_rd_data,input logic app_rd_data_valid,app_rdy,app_wdf_rdy
);
 logic [15:0] rdata;
 jmr_raster_engine raster(.clk(clk),.rst_n(rst_n),.go(go),.mode(2'd2),
  .dx(dx),.dy(dy),.w(w),.h(h),.color(8'd0),.sx(16'd0),.sy(16'd0),
  .qx(16'd0),.rxr(16'd0),.qy(16'd0),.ryr(16'd0),.sbase(source),
  .stride(16'd0),.aset(1'b0),.flip_x(flip_x),.flip_y(flip_y),.busy(busy),
  .fb_we(fb_we),.fb_waddr(fb_addr),.fb_wdata(fb_data),
  .sram_req(req_o),.sram_addr(addr_o),.sram_rdata(rdata),.sram_ack(ack_o));
 jmr_ddr3_sram_bridge bridge(.clk(clk),.rst_n(rst_n),.calib_done(1'b1),
  .req(req_o),.we(1'b0),.addr(addr_o),.wdata(16'd0),.rdata(rdata),.ack(ack_o),
  .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_wdf_data(app_wdf_data),
  .app_wdf_end(app_wdf_end),.app_wdf_mask(app_wdf_mask),.app_wdf_wren(app_wdf_wren),
  .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),
  .app_rdy(app_rdy),.app_wdf_rdy(app_wdf_rdy));
endmodule
