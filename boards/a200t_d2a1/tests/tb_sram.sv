`timescale 1ps/1ps
module tb_sram;
 reg clk=0,ramclk=0,ck90=0,ref200=0,rst_n=0;
 always #5000 clk=~clk;
 always #10000 ramclk=~ramclk;
 initial begin #5000;forever #10000 ck90=~ck90;end
 always #2500 ref200=~ref200;
 wire [7:0] dq;wire rwds,ckp,ckn,csn,resetn,ready,fault,ack;
 reg req=0,we=0;reg [24:0] addr=0;reg [15:0] wdata=0;wire [15:0] rdata;
 jmr_hyperram_sram #(.BIST_LAST(25'd56)) dut(
  .clk(clk),.ramclk(ramclk),.ck90(ck90),.ref200(ref200),.rst_n(rst_n),
  .req(req),.we(we),.addr(addr),.wdata(wdata),.rdata(rdata),.ack(ack),
  .ready(ready),.fault(fault),.HR_DQ(dq),.HR_RWDS(rwds),
  .HR_CK_P_SRC(ckp),.HR_CK_N_SRC(ckn),.HR_CS_N(csn),.HR_RESET_N(resetn));
 s80ks5122 memory(.DQ7(dq[7]),.DQ6(dq[6]),.DQ5(dq[5]),.DQ4(dq[4]),
  .DQ3(dq[3]),.DQ2(dq[2]),.DQ1(dq[1]),.DQ0(dq[0]),.RWDS(rwds),
  .CSNeg(csn),.CK(ckp),.CKn(ckn),.RESETNeg(resetn));
 always @(posedge fault)$fatal(1,"memory fault");
 task access(input bit writing,input [24:0] a,input [15:0] d,input [15:0] expected);
  begin
   @(negedge clk);req=1;we=writing;addr=a;wdata=d;
   do @(negedge clk);while(!ack);
   if(!writing && rdata!==expected)$fatal(1,"SRAM mismatch %h expected=%h got=%h",a,expected,rdata);
   req=0;@(negedge clk);
  end
 endtask
 integer i;reg [24:0] a;time scan_start;
 initial begin
  #1000001;rst_n=1;wait(ready);
  // Force write-combine flushes, read misses, read hits and invalidations.
  for(i=0;i<32;i=i+1)access(1,25'(i),16'(i)^16'h97a5,0);
  for(i=0;i<32;i=i+1)access(0,25'(i),0,16'(i)^16'h97a5);
  access(1,3,16'h18ed,0);access(0,3,0,16'h18ed);access(0,2,0,16'h97a7);
  // Exercise every word address bit with all writes before any reads.
  for(i=0;i<25;i=i+1)access(1,25'b1<<i,16'h7713^16'(i),0);
  for(i=0;i<25;i=i+1)access(0,25'b1<<i,0,16'h7713^16'(i));
  for(i=0;i<24;i=i+1)begin
   a=25'h0fffff8+25'(i);access(1,a,16'habe1^16'(i),0);
  end
  for(i=0;i<24;i=i+1)begin
   a=25'h0fffff8+25'(i);access(0,a,0,16'habe1^16'(i));
  end
  // One displayed row needs 320 packed words within a 32-us scan line.
  for(i=0;i<320;i=i+1)access(1,25'h2000+25'(i),16'(i)^16'hc59e,0);
  scan_start=$time;
  for(i=0;i<320;i=i+1)access(0,25'h2000+25'(i),0,16'(i)^16'hc59e);
  $display("SCAN_ROW_WORDS=320 SCAN_ROW_PS=%0t BUDGET_PS=32000000",$time-scan_start);
  if($time-scan_start>32000000)$fatal(1,"Video row missed 32-us memory deadline");
  $display("HYPERRAM_SRAM_PASS cache/write-combine/masks/all25addressbits/die-boundary");$finish;
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
 integer clocks=0;
 always @(negedge csn)clocks=0;
 always @(posedge ckp)if(!csn)clocks++;
 always @(posedge csn)if($time>1000000 && !dut.bus.writing && clocks!=16+dut.bus.words)
  $fatal(1,"Read-ahead clocked beyond its requested burst");
endmodule
