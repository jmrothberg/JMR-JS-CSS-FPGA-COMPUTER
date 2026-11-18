`timescale 1ps/1ps
module tb_hyperram;
 reg clk=0,ck90=0,ref200=0,rst_n=0;
 always #10000 clk=~clk;
 initial begin #5000;forever #10000 ck90=~ck90;end
 always #2500 ref200=~ref200;
 wire [7:0] dq;wire rwds,ckp,ckn,csn,resetn,ready,fault,done;
 reg toggle=0,writing=0;reg [24:0] address=0;
 reg [127:0] data=0;reg [15:0] mask=0;wire [511:0] result;
 // Shorten BIST range for simulation only; hardware scans all 64 MiB.
 jmr_hyperram_bus #(.BIST_LAST(25'd56)) dut(.clk(clk),.ck90(ck90),.ref200(ref200),.rst_n(rst_n),
 .command_toggle(toggle),.command_write(writing),.command_addr(address),
 .command_data(data),.command_mask(mask),.done_toggle(done),.result(result),
 .ready(ready),.fault(fault),.HR_CK_P_SRC(ckp),.HR_CK_N_SRC(ckn),
 .HR_CS_N(csn),.HR_RESET_N(resetn),.HR_DQ(dq),.HR_RWDS(rwds));
 s80ks5122 memory(.DQ7(dq[7]),.DQ6(dq[6]),.DQ5(dq[5]),.DQ4(dq[4]),
 .DQ3(dq[3]),.DQ2(dq[2]),.DQ1(dq[1]),.DQ0(dq[0]),.RWDS(rwds),
 .CSNeg(csn),.CK(ckp),.CKn(ckn),.RESETNeg(resetn));
 always @(posedge fault) $fatal(1,"HyperRAM initialization/transaction fault step=%d data=%h count=%d",dut.step,dut.rx_data,dut.rx_count);
 task transaction(input bit wr,input [24:0] a,input [127:0] d,input [15:0] m);
 begin
  @(posedge clk);writing=wr;address=a;data=d;mask=m;toggle=~toggle;
  wait(done==toggle);#100000;
 end endtask
 reg [24:0] addresses[0:6];integer i;
 initial begin
  #1000001;rst_n=1; wait(ready);$display("INIT_PASS");
  addresses[0]=0;addresses[1]=8;addresses[2]=25'h0fffff8;
  addresses[3]=25'h1000000;addresses[4]=25'h1000008;
  addresses[5]=25'h1400000;addresses[6]=25'h1fffff8;
  for(i=0;i<7;i=i+1)transaction(1,addresses[i],128'h123456789abcdeff987654321234abcd^i,0);
  for(i=0;i<7;i=i+1)begin
   transaction(0,addresses[i],0,0);
   if(result[127:0]!==(128'h123456789abcdeff987654321234abcd^i))$fatal(1,"read mismatch at %h got=%h",addresses[i],result);
  end
  transaction(1,0,128'hfedcba9876543210aabbccddeeff0123,16'h5555);
  transaction(0,0,0,0);
  if(result[127:0]!==128'hfe34ba7876bc32ffaa76cc32ee3401cd)$fatal(1,"mask mismatch got=%h",result);
  // Write every address before reading any, to expose aliases.
  for(i=3;i<25;i=i+1)transaction(1,25'b1<<i,128'hfedcba98765432100123456789abcdef^i,0);
  for(i=3;i<25;i=i+1)begin
   transaction(0,25'b1<<i,0,0);
   if(result[127:0]!==(128'hfedcba98765432100123456789abcdef^i))$fatal(1,"address bit alias %d",i);
  end
  $display("HYPERRAM_BUS_PASS");$finish;
 end
 time selected_at;
 integer clocks_in_transaction=0;
 time last_dq_change=0,last_mask_change=0,last_ck=0,last_cs_rise=0;
 always @(dq)begin
  if(!csn && !dut.phy.dq_z && !$isunknown(dq) && $time-last_ck<500)
   $fatal(1,"Independent host DQ hold <0.5ns");
  last_dq_change=$time;
 end
 always @(rwds)begin
  if(!csn && !dut.phy.mask_z && !$isunknown(rwds) && $time-last_ck<500)
   $fatal(1,"Independent host RWDS mask hold <0.5ns");
  last_mask_change=$time;
 end
 always @(ckp)begin
  if(!csn && !dut.phy.dq_z && ($isunknown(dq) || $time-last_dq_change<500))
   $fatal(1,"Independent host DQ setup <0.5ns or unknown");
  if(!csn && !dut.phy.mask_z && ($isunknown(rwds) || $time-last_mask_change<500))
   $fatal(1,"Independent host mask setup <0.5ns or unknown");
  if(!csn && $time-selected_at<4000)$fatal(1,"CS setup <4ns");
  last_ck=$time;
 end
 always @(posedge csn)last_cs_rise=$time;
 always @(negedge csn)if($time>1000000 && $time-last_cs_rise<35000)
  $fatal(1,"CS-high recovery <35ns");
 always @(negedge csn)begin selected_at=$time;clocks_in_transaction=0;end
 always @(posedge ckp)if(!csn)clocks_in_transaction++;
 always @(posedge csn)if($time>1000000)begin
  if($time-selected_at>4000000)$fatal(1,"CS low >4us");
  if(!dut.writing && clocks_in_transaction!=16+dut.words)
   $fatal(1,"Read must stop at requested word, clocks=%0d words=%0d",clocks_in_transaction,dut.words);
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
