// 50 MHz HyperBus, 90 degree forwarded CK, source-synchronous RX.
// RX words are a transaction mailbox: held after CK stops, consumed only
// after synchronized completion. No asynchronous per-word data sampling.
module jmr_hyperram_phy(
 input wire clk,ck90,ref200,rst_n,
 input wire active,drive_dq,drive_mask,clear_rx,
 input wire [15:0] tx_word,input wire [1:0] tx_mask,
 output wire [511:0] rx_data,output wire [5:0] rx_count,
 output wire delay_ready,
 output wire HR_CK_P_SRC,HR_CK_N_SRC,
 inout wire [7:0] HR_DQ,inout wire HR_RWDS);
 reg ck_enable,dq_z,mask_z,rx_reset;
 always @(posedge clk) begin
  ck_enable<=rst_n && active;
  dq_z<=!rst_n || !drive_dq;
  mask_z<=!rst_n || !drive_mask;
  rx_reset<=!rst_n || clear_rx;
 end
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) ckP(.C(ck90),.CE(1'b1),
  .D1(ck_enable),.D2(1'b0),.Q(HR_CK_P_SRC),.R(!rst_n),.S(1'b0));
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) ckN(.C(ck90),.CE(1'b1),
  .D1(!ck_enable),.D2(1'b1),.Q(HR_CK_N_SRC),.R(1'b0),.S(!rst_n));
 wire [7:0] din;
 for(genvar k=0;k<8;k=k+1)begin:g_dq
  wire dout;
  ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) od(.C(clk),.CE(1'b1),
   .D1(tx_word[k+8]),.D2(tx_word[k]),.Q(dout),.R(1'b0),.S(1'b0));
  IOBUF io(.I(dout),.O(din[k]),.IO(HR_DQ[k]),.T(dq_z));
 end
 wire maskout,rwds_in,rwds_delayed,rxclk;
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) om(.C(clk),.CE(1'b1),
  .D1(tx_mask[1]),.D2(tx_mask[0]),.Q(maskout),.R(1'b0),.S(1'b0));
 IOBUF ri(.I(maskout),.O(rwds_in),.IO(HR_RWDS),.T(mask_z));
 (* IODELAY_GROUP="JMR_HR_RX" *) IDELAYCTRL delayctrl(
  .REFCLK(ref200),.RST(!rst_n),.RDY(delay_ready));
 (* IODELAY_GROUP="JMR_HR_RX" *) IDELAYE2 #(
  .DELAY_SRC("IDATAIN"),.IDELAY_TYPE("FIXED"),.IDELAY_VALUE(26),
  .HIGH_PERFORMANCE_MODE("TRUE"),.REFCLK_FREQUENCY(200.0),
  .SIGNAL_PATTERN("CLOCK")) rdly(
  .IDATAIN(rwds_in),.DATAIN(1'b0),.DATAOUT(rwds_delayed),.C(1'b0),
  .CE(1'b0),.INC(1'b0),.LD(1'b0),.LDPIPEEN(1'b0),.REGRST(1'b0),
  .CINVCTRL(1'b0),.CNTVALUEIN(5'b0),.CNTVALUEOUT());
 // BUFR permits fabric mailbox flops in this clock region. RWDS is MRCC.
 BUFR #(.BUFR_DIVIDE("BYPASS")) readbuf(.I(rwds_delayed),.O(rxclk),.CE(1'b1),.CLR(1'b0));
 wire [7:0] high_byte,low_byte;
 for(genvar k=0;k<8;k=k+1)begin:g_rx
  IDDR #(.DDR_CLK_EDGE("OPPOSITE_EDGE")) capture(.C(rxclk),.CE(1'b1),
   .D(din[k]),.Q1(high_byte[k]),.Q2(low_byte[k]),.R(1'b0),.S(1'b0));
 end
 reg [511:0] received;
 reg [5:0] count;
 always @(negedge rxclk or posedge rx_reset)begin
  if(rx_reset)count<=0;
  else if(count<32)count<=count+1'b1;
 end
 // At the following rising edge BOTH IDDR halves of the preceding word
 // are stable. The last word stays in the I/O registers: draining it here
 // would require an extra physical CK and could cross the die boundary.
 always @(posedge rxclk or posedge rx_reset)begin
  if(rx_reset)received<=0;
  else if(count!=0 && count<=32)received[(count-1)*16+:16]<={high_byte,low_byte};
 end
 reg [511:0] complete;
 always @* begin
  complete=received;
  if(count!=0 && count<=32)complete[(count-1)*16+:16]={high_byte,low_byte};
 end
 assign rx_data=complete;
 assign rx_count=count;
endmodule
