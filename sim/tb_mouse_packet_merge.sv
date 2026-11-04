// Both live ports share position and preserve button transitions.
module tb_mouse_packet_merge;
 logic clk=0,rst_n=0;
 logic [24:0] a=0,b=0,packet;
 logic valid,ready=1;logic [9:0] x;logic [8:0] y;logic [2:0] buttons;
 logic [31:0] dropped;integer n=0;integer last_x=320,last_y=240,last_buttons=0;
 always #5 clk=~clk;
 jmr_mouse_packet_merge dut(.clk,.rst_n,.packet_a(a),.packet_b(b),.packet);
 jmr_pointer_accumulator pointer(.clk,.rst_n,.packet,.sample_valid(valid),.sample_ready(ready),.sample_x(x),.sample_y(y),.sample_buttons(buttons),.dropped_reports(dropped));
 always @(posedge clk)if(rst_n && valid && ready)begin n++;last_x=x;last_y=y;last_buttons=buttons;end
 task automatic drain;
  repeat(10)@(negedge clk);
  if(dropped!=0)$fatal(1,"unexpected report loss");
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  @(negedge clk);a={~a[24],8'd0,8'd5,8'h09};b={~b[24],8'd3,8'd0,8'h0a};
  drain();
  if(n!=2 || last_x!=325 || last_y!=237 || last_buttons!=3)$fatal(1,"simultaneous movement/buttons");
  // A release cannot release B's right button.
  a={~a[24],16'd0,8'h08};drain();
  if(last_buttons!=2)$fatal(1,"other mouse released held button");
  b={~b[24],16'd0,8'h08};drain();
  if(last_buttons!=0)$fatal(1,"button release lost");
  // Hold consumer: both simultaneous reports must survive until accepted.
  ready=0;a={~a[24],8'd0,8'hfe,8'h18};b={~b[24],8'hff,8'd0,8'h28};
  drain();if(n!=4)$fatal(1,"consumer backpressure ignored");
  ready=1;drain();
  if(n!=6 || last_x!=323 || last_y!=238)$fatal(1,"signed movement or queued reports lost");
  // Idle backup must never manufacture reports or reset the pointer.
  repeat(1000)@(negedge clk);if(n!=6)$fatal(1,"phantom idle report");
  $display("PASS dual mouse: simultaneous packets, shared position, buttons, backpressure, idle");$finish;
 end
endmodule
