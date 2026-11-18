// Preserve the qualified JS read-cache/write-combine contract. The MIG-like
// burst side terminates locally in a bounded 50 MHz HyperBus transaction.
module jmr_hyperram_sram #(parameter [24:0] BIST_LAST=25'h1fffff8)(
 input wire clk,ramclk,ck90,ref200,rst_n,
 input wire req,we,input wire [24:0] addr,input wire [15:0] wdata,
 output wire [15:0] rdata,output wire ack,output wire ready,fault,
 output wire HR_CK_P_SRC,HR_CK_N_SRC,HR_RESET_N,HR_CS_N,
 inout wire [7:0] HR_DQ,inout wire HR_RWDS);
 wire [28:0] app_addr;wire [2:0] app_cmd;
 wire app_en,wren,endflag;wire [127:0] wrdata;wire [15:0] mask;
 reg [127:0] rddata;reg rdvalid;
 wire bus_ready,bus_fault,done;wire [511:0] result;
 reg command_toggle,command_write;
 reg [24:0] command_addr;reg [127:0] command_data;reg [15:0] command_mask;
 reg have_data,busy,reading;
 reg prefetch_valid;
 reg [19:0] prefetch_base;
 reg [511:0] prefetch_data;
 reg [1:0] read_slot;
 (* ASYNC_REG="TRUE" *) reg [1:0] ready_sync,fault_sync,done_sync;
 assign ready=ready_sync[1] && !fault_sync[1];
 assign fault=fault_sync[1];
 wire app_rdy=ready && !busy && (!app_en || app_cmd==1 || have_data);
 wire wdf_rdy=ready && !busy && !have_data;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   ready_sync<=0;fault_sync<=0;done_sync<=0;command_toggle<=0;
   command_write<=0;command_addr<=0;command_data<=0;command_mask<=0;
   have_data<=0;busy<=0;reading<=0;rddata<=0;rdvalid<=0;
   prefetch_valid<=0;prefetch_base<=0;prefetch_data<=0;read_slot<=0;
  end else begin
   ready_sync<={ready_sync[0],bus_ready};
   fault_sync<={fault_sync[0],bus_fault};done_sync<={done_sync[0],done};rdvalid<=0;
   if(wren && wdf_rdy)begin command_data<=wrdata;command_mask<=mask;have_data<=1;end
   if(app_en && app_rdy)begin
    have_data<=0;
    if(app_cmd==1 && prefetch_valid && app_addr[24:5]==prefetch_base)begin
     rddata<=prefetch_data[{app_addr[4:3],7'b0}+:128];rdvalid<=1;
    end else begin
     command_addr<=app_cmd==0?app_addr[24:0]:{app_addr[24:5],5'b0};
     command_write<=app_cmd==0;read_slot<=app_addr[4:3];
     reading<=app_cmd==1;busy<=1;command_toggle<=~command_toggle;
    end
    if(app_cmd==0 && app_addr[24:5]==prefetch_base)prefetch_valid<=0;
   end
   if(busy && done_sync[1]==command_toggle)begin
    busy<=0;
    if(reading)begin
     rddata<=result[{read_slot,7'b0}+:128];rdvalid<=1;
     prefetch_data<=result;prefetch_base<=command_addr[24:5];prefetch_valid<=1;
    end
   end
  end
 end
 jmr_ddr3_sram_bridge cache(.clk(clk),.rst_n(rst_n),.calib_done(ready),
  .req(req),.we(we),.addr(addr),.wdata(wdata),.rdata(rdata),.ack(ack),
  .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),
  .app_wdf_data(wrdata),.app_wdf_end(endflag),.app_wdf_mask(mask),.app_wdf_wren(wren),
  .app_rd_data(rddata),.app_rd_data_valid(rdvalid),.app_rdy(app_rdy),.app_wdf_rdy(wdf_rdy));
 // Read a full 32-word aligned line, then satisfy four cache fills locally.
 // Writes remain masked eight-word bursts and invalidate this read-ahead.
 jmr_hyperram_bus #(.BIST_LAST(BIST_LAST),.READ_WORDS(32)) bus(.clk(ramclk),.ck90(ck90),.ref200(ref200),.rst_n(rst_n),
  .command_toggle(command_toggle),.command_write(command_write),
  .command_addr(command_addr),.command_data(command_data),.command_mask(command_mask),
  .done_toggle(done),.result(result),.ready(bus_ready),.fault(bus_fault),
  .HR_CK_P_SRC(HR_CK_P_SRC),.HR_CK_N_SRC(HR_CK_N_SRC),.HR_RESET_N(HR_RESET_N),
  .HR_CS_N(HR_CS_N),.HR_DQ(HR_DQ),.HR_RWDS(HR_RWDS));
endmodule
