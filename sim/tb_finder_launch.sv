`timescale 1ns/1ps
module tb_finder_launch;
 logic clk=0;always #5 clk=~clk;
 logic rst_n=0,ready=0,clear=0,launch=0;
 wire key_push;wire[7:0]key_data;wire tool_start,tool_finder,busy,loading;
 jmr_finder_shell dut(.clk(clk),.rst_n(rst_n),.enabled(1'b1),.ready(ready),.failed(1'b0),
 .keyboard_empty(1'b1),.keyboard_full(1'b0),.console_clear(clear),.vm_busy(1'b0),
 .storage_busy(1'b0),.disk_busy(1'b0),.actions_busy(1'b0),.fs_busy(1'b0),
 .home_stb(1'b0),.home_on(1'b0),.quit(1'b0),.launch(launch),
 .launch_name(96'h00004d54482e4f4d45444254),.launch_len(4'd10),.launch_how(4'd0),
 .key_push(key_push),.key_data(key_data),.tool_start(tool_start),.tool_finder(tool_finder),.busy(busy),.loading(loading));
 task step;@(posedge clk);#1;endtask
 initial begin
  repeat(3)step();rst_n=1;step();launch=1;step();launch=0;ready=1;
  // Console's drain appears after ready, as enable crosses the VM handoff.
  repeat(3)begin step();if(key_push)$fatal(1,"sent before delayed drain");end
  clear=1;repeat(4)step();clear=0;
  repeat(90)begin step();if(key_push)$fatal(1,"did not wait for stable console");end
  repeat(20)begin step();if(key_push)begin
   if(key_data!="L")$fatal(1,"first LOAD character lost");
   $display("PASS Finder waits for console drain and preserves LOAD L");$finish;
  end end
  $fatal(1,"no launch after settled console");
 end
endmodule
