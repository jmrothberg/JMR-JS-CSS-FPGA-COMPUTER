`timescale 1ns/1ps
module tb_resource_bridge;
 logic clk=0,pixel_clk=0,rst_n=0,valid=0,ready,pv;
 logic [13:0] addr=0,pa;logic [15:0] data=0,pd;
 integer received=0;
 always #5 clk=~clk;
 initial begin #3;forever #20 pixel_clk=~pixel_clk;end
 jmr_resource_bridge dut(.clk(clk),.pixel_clk(pixel_clk),.rst_n(rst_n),
  .write_valid(valid),.write_addr(addr),.write_data(data),.ready(ready),
  .pixel_valid(pv),.pixel_addr(pa),.pixel_data(pd));
 always @(posedge pixel_clk)if(rst_n && pv)begin
  if(pa!=14'(received) || pd!=(16'(received)^16'hA53C))$fatal(1,"Resource lost, duplicated or torn: %d %h %h",received,pa,pd);
  received=received+1;
 end
 initial begin
  #100;@(negedge clk);rst_n=1;
  for(integer i=0;i<12160;i=i+1)begin
   wait(ready);@(negedge clk);addr=14'(i);data=16'(i)^16'hA53C;valid=1;
   @(negedge clk);valid=0;
   wait(!ready);wait(ready);
   if(received!=i+1)$fatal(1,"Acknowledged before the destination RAM write");
  end
  $display("PASS all 12160 resource words, asynchronous 100/25 MHz clocks, ordered delivery and write-before-ack");$finish;
 end
 initial begin #5000000;$fatal(1,"Resource bridge timeout");end
endmodule
