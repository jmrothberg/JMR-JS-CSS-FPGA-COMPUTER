// C3 U3 raw-report firmware -> existing JS keyboard and pointer contracts.
// Whole-report queue and release-before-modifier-before-make ordering are
// retained from the owner-tested Macintosh decoder. U3 is not reprogrammed.
module jmr_c3_input #(parameter integer CLK_HZ=100000000)(
 input wire clk,rst_n,rx,
 output wire kbd_push, output wire [7:0] kbd_ascii,
 output wire kev_stb,kev_down,output wire [7:0] kev_code,
 output wire mouse_valid,input wire mouse_ready,
 output wire [9:0] mouse_x,output wire [8:0] mouse_y,
 output wire [2:0] mouse_buttons,output wire fault);
 wire valid,ready; wire [9:0] event_word; wire [24:0] packet;
 jmr_c3_reports #(.CLK_HZ(CLK_HZ)) reports(
  .clk(clk),.reset(!rst_n),.rx(rx),.key_ready(ready),
  .key_valid(valid),.key_event(event_word),.fault(fault),
  .mouse(packet),.mouse_valid(),.wheel());
 reg [2:0] phase;
 reg [9:0] held;
 reg [7:0] sc;
 reg stb;
 assign ready=phase==0;
 always @(posedge clk) begin
  if(!rst_n)begin phase<=0;held<=0;sc<=0;stb<=0;end
  else begin
   stb<=0;
   case(phase)
    0:if(valid)begin held<=event_word;phase<=1;end
    1:begin if(held[8])begin sc<=8'he0;stb<=1;end phase<=2;end
    2:phase<=3;
    3:begin if(!held[9])begin sc<=8'hf0;stb<=1;end phase<=4;end
    4:phase<=5;
    5:begin sc<=held[7:0];stb<=1;phase<=6;end
    default:phase<=0;
   endcase
  end
 end
 jmr_c3_set2_decode keyboard(.clk(clk),.rst_n(rst_n),.scancode(sc),.strobe(stb),
  .ascii(kbd_ascii),.ascii_strobe(kbd_push),.kev_code(kev_code),
  .kev_down(kev_down),.kev_stb(kev_stb));
 jmr_pointer_accumulator pointer(.clk(clk),.rst_n(rst_n),.packet(packet),
  .sample_valid(mouse_valid),.sample_ready(mouse_ready),
  .sample_x(mouse_x),.sample_y(mouse_y),.sample_buttons(mouse_buttons),
  .dropped_reports());
endmodule
