`timescale 1ns/1ps
module tb_input;
 reg clk=0,rst_n=0,rx=1;always #5 clk=~clk;
 wire push,stb,down,mvalid,fault;wire [7:0] ascii,code;
 wire [9:0] mx;wire [8:0] my;wire [2:0] mb;
 jmr_c3_input #(.CLK_HZ(1843200)) dut(.clk(clk),.rst_n(rst_n),.rx(rx),
 .kbd_push(push),.kbd_ascii(ascii),.kev_stb(stb),.kev_down(down),.kev_code(code),
 .mouse_valid(mvalid),.mouse_ready(1'b1),.mouse_x(mx),.mouse_y(my),.mouse_buttons(mb),.fault(fault));
 integer ke=0,chars=0,mice=0;reg [7:0] lastcode,lastchar;reg lastdown;
 reg [9:0] x;reg [8:0] y;reg [2:0] buttons;
 always @(posedge clk)begin
  if(stb)begin ke++;lastcode=code;lastdown=down;end
  if(push)begin chars++;lastchar=ascii;end
  if(mvalid)begin mice++;x=mx;y=my;buttons=mb;end
 end
 task sendbyte(input [7:0] b);begin
  @(negedge clk);rx=0;repeat(16)@(negedge clk);
  for(integer i=0;i<8;i++)begin rx=b[i];repeat(16)@(negedge clk);end
  rx=1;repeat(16)@(negedge clk);
 end endtask
 task header(input [7:0] t);begin sendbyte('h57);sendbyte('hab);sendbyte(t);end endtask
 task keyboard(input [7:0] mods,k);begin
  header(1);sendbyte(mods);sendbyte(0);sendbyte(k);repeat(5)sendbyte(0);
  repeat(2300)@(negedge clk);
 end endtask
 initial begin
  repeat(6)@(negedge clk);rst_n=1;
  keyboard(0,4);if(ke!=1 || lastcode!=65 || !lastdown || lastchar!="a")$fatal(1,"A make");
  keyboard(0,0);if(ke!=2 || lastdown)$fatal(1,"A release");
  keyboard(2,4);if(lastchar!="A" || ke!=4)$fatal(1,"shift before make");
  keyboard(0,0);keyboard(1,0);if(lastcode!=17 || !lastdown)$fatal(1,"Ctrl");
  keyboard(0,0);keyboard(4,0);if(lastcode!=18 || !lastdown)$fatal(1,"Alt");
  keyboard(0,0);keyboard(8,0);if(lastcode!=91 || !lastdown)$fatal(1,"GUI");
  keyboard(0,0);keyboard(0,41);if(lastcode!=27 || lastchar!=27)$fatal(1,"Esc");
  keyboard(0,0);keyboard(0,79);if(lastcode!=39 || !lastdown)$fatal(1,"right arrow");
  keyboard(0,0);keyboard(0,59);if(lastcode!=113)$fatal(1,"F2");keyboard(0,0);
  header(2);sendbyte(5);sendbyte(7);sendbyte(9);sendbyte(0);
  repeat(100)@(negedge clk);
  if(mice!=1 || x!=327 || y!=249 || buttons!=5)$fatal(1,"mouse signed coordinates/buttons %d %d %d",x,y,buttons);
  header(2);sendbyte(0);sendbyte('hfd);sendbyte('hfe);sendbyte(0);
  repeat(100)@(negedge clk);
  if(mice!=2 || x!=324 || y!=247 || buttons!=0 || fault)$fatal(1,"mouse release");
  $display("C3_INPUT_PASS keyboard press/release/modifiers/Esc/F2/arrows and pointer/button directions");$finish;
 end
 initial begin #10000000;$fatal(1,"watchdog");end
endmodule
