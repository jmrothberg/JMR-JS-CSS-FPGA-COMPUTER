`timescale 1ps/1ps
module tb_missing_ram;
 reg clk=0,ck90=0,ref200=0,rst_n=0;
 always #10000 clk=~clk;
 initial begin #5000;forever #10000 ck90=~ck90;end
 always #2500 ref200=~ref200;
 wire [7:0] dq;tri0 rwds;wire ready,fault;
 jmr_hyperram_bus dut(.clk(clk),.ck90(ck90),.ref200(ref200),.rst_n(rst_n),
  .command_toggle(1'b0),.command_write(1'b0),.command_addr(25'd0),
  .command_data(128'd0),.command_mask(16'd0),.done_toggle(),.result(),
  .ready(ready),.fault(fault),.HR_DQ(dq),.HR_RWDS(rwds),
  .HR_CS_N(),.HR_RESET_N(),.HR_CK_P_SRC(),.HR_CK_N_SRC());
 initial begin
  #1000001;rst_n=1;
  wait(fault);#100000;
  if(ready)$fatal(1,"Missing RAM allowed boot");
  $display("MISSING_RAM_PASS timed out and kept computer in reset");$finish;
 end
 initial begin #300000000;$fatal(1,"missing-RAM watchdog failed");end
endmodule
