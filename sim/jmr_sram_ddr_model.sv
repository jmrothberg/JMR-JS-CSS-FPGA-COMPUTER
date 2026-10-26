// Campaign-only: actual board bridge, modeled always-ready MIG with 25-cycle reads.
// No HDMI scanout traffic is driven by the existing RPC harness.
module jmr_sram_model(input logic clk,rst_n,req,we,input logic [20:0] addr,
 input logic [15:0] wdata,output logic [15:0] rdata,output logic ack);
 logic [15:0] mem [0:2097151] /*verilator public_flat_rw*/;
 logic [28:0] app_addr;logic [2:0] app_cmd;logic app_en,wdf_end,wdf_wren;
 logic [127:0] wdf_data,rd_data,pending_data;logic [15:0] wdf_mask,pending_mask;
 logic rd_valid,reading,wdf_pending;logic [20:0] read_addr;logic [5:0] countdown;
 jmr_ddr3_sram_bridge bridge(.clk(clk),.rst_n(rst_n),.calib_done(1'b1),
  .req(req),.we(we),.addr(addr),.wdata(wdata),.rdata(rdata),.ack(ack),
  .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_wdf_data(wdf_data),
  .app_wdf_end(wdf_end),.app_wdf_mask(wdf_mask),.app_wdf_wren(wdf_wren),
  .app_rd_data(rd_data),.app_rd_data_valid(rd_valid),.app_rdy(1'b1),.app_wdf_rdy(1'b1));
 always_ff @(posedge clk) begin
  if(!rst_n) begin reading<=0;rd_valid<=0;countdown<=0;wdf_pending<=0;end
  else begin
   rd_valid<=0;
   if(reading) begin
    if(countdown==0) begin
     for(integer i=0;i<8;i++) rd_data[16*i+:16]<=mem[read_addr+21'(i)];
     rd_valid<=1;reading<=0;
    end else countdown<=countdown-1'b1;
   end
   if(wdf_wren) begin
    if(!wdf_end || wdf_pending) $error("MIG write data protocol");
    pending_data<=wdf_data;pending_mask<=wdf_mask;wdf_pending<=1;
   end
   if(app_en) begin
    if(app_cmd==1) begin
     if(reading) $error("multiple outstanding MIG reads");
     reading<=1;read_addr<=app_addr[20:0];countdown<=25;
    end else if(app_cmd==0) begin
     if(!wdf_pending && !wdf_wren) $error("MIG write command without data");
     for(integer i=0;i<8;i++) begin
      if(!(wdf_wren?wdf_mask[2*i]:pending_mask[2*i]))
       mem[app_addr[20:0]+21'(i)][7:0]<=wdf_wren?wdf_data[16*i+:8]:pending_data[16*i+:8];
      if(!(wdf_wren?wdf_mask[2*i+1]:pending_mask[2*i+1]))
       mem[app_addr[20:0]+21'(i)][15:8]<=wdf_wren?wdf_data[16*i+8+:8]:pending_data[16*i+8+:8];
     end
     wdf_pending<=0;
    end else $error("unexpected MIG command");
   end
  end
 end
endmodule
