// Full CH9350 state-2 keyboard reports, received through the C3 U3 forwarding image.
// FIFO contains whole reports; key_valid/key_ready is an acknowledged event stream.
module jmr_c3_reports #(parameter integer CLK_HZ=32500000, BAUD=115200,
 parameter integer FIFO_BITS=6)(input wire clk,reset,rx,input wire key_ready,
 output wire key_valid,output wire [9:0] key_event,output reg fault,
 output reg [24:0] mouse, output reg mouse_valid,
 output reg signed [7:0] wheel);
 localparam integer BT=CLK_HZ/BAUD;
 (* ASYNC_REG="TRUE" *) reg [2:0] sync;
 reg [31:0] timer; reg [3:0] bitno;reg [1:0] uart;
 reg [7:0] shift,byte_data;reg byte_valid,byte_error;
 always @(posedge clk) begin
  if(reset) begin sync<=7;timer<=0;bitno<=0;uart<=0;byte_valid<=0;byte_error<=0;shift<=0;byte_data<=0;end
  else begin
   sync<={sync[1:0],rx};byte_valid<=0;byte_error<=0;
   case(uart)
    0:if(!sync[2])begin timer<=BT/2-1;uart<=1;end
    1:if(timer!=0)timer<=timer-1;else if(!sync[2])begin timer<=BT-1;bitno<=0;uart<=2;end else uart<=0;
    2:if(timer!=0)timer<=timer-1;else begin shift[bitno]<=sync[2];timer<=BT-1;if(bitno==7)uart<=3;else bitno<=bitno+1;end
    3:if(timer!=0)timer<=timer-1;else begin uart<=0;if(sync[2])begin byte_data<=shift;byte_valid<=1;end else byte_error<=1;end
   endcase
  end
 end
 function automatic [8:0] code(input [7:0] usage);
 begin
 case(usage)
 8'd4:code=9'h01c;
 8'd5:code=9'h032;
 8'd6:code=9'h021;
 8'd7:code=9'h023;
 8'd8:code=9'h024;
 8'd9:code=9'h02b;
 8'd10:code=9'h034;
 8'd11:code=9'h033;
 8'd12:code=9'h043;
 8'd13:code=9'h03b;
 8'd14:code=9'h042;
 8'd15:code=9'h04b;
 8'd16:code=9'h03a;
 8'd17:code=9'h031;
 8'd18:code=9'h044;
 8'd19:code=9'h04d;
 8'd20:code=9'h015;
 8'd21:code=9'h02d;
 8'd22:code=9'h01b;
 8'd23:code=9'h02c;
 8'd24:code=9'h03c;
 8'd25:code=9'h02a;
 8'd26:code=9'h01d;
 8'd27:code=9'h022;
 8'd28:code=9'h035;
 8'd29:code=9'h01a;
 8'd30:code=9'h016;
 8'd31:code=9'h01e;
 8'd32:code=9'h026;
 8'd33:code=9'h025;
 8'd34:code=9'h02e;
 8'd35:code=9'h036;
 8'd36:code=9'h03d;
 8'd37:code=9'h03e;
 8'd38:code=9'h046;
 8'd39:code=9'h045;
 8'd40:code=9'h05a;
 8'd41:code=9'h076;
 8'd42:code=9'h066;
 8'd43:code=9'h00d;
 8'd44:code=9'h029;
 8'd45:code=9'h04e;
 8'd46:code=9'h055;
 8'd47:code=9'h054;
 8'd48:code=9'h05b;
 8'd49:code=9'h05d;
 8'd50:code=9'h000;
 8'd51:code=9'h04c;
 8'd52:code=9'h052;
 8'd53:code=9'h00e;
 8'd54:code=9'h041;
 8'd55:code=9'h049;
 8'd56:code=9'h04a;
 8'd57:code=9'h058;
 8'd58:code=9'h005; 8'd59:code=9'h006; 8'd60:code=9'h004;
 8'd61:code=9'h00c; 8'd62:code=9'h003; 8'd63:code=9'h00b;
 8'd64:code=9'h083; 8'd65:code=9'h00a; 8'd66:code=9'h001;
 8'd67:code=9'h009; 8'd68:code=9'h078; 8'd69:code=9'h007;
 8'd73:code=9'h170; 8'd74:code=9'h16c; 8'd75:code=9'h17d;
 8'd76:code=9'h171; 8'd77:code=9'h169; 8'd78:code=9'h17a;
 8'd79:code=9'h174;
 8'd80:code=9'h16b;
 8'd81:code=9'h172;
 8'd82:code=9'h175;
default:code=0;
endcase
end endfunction
 // CH9350 relative Y is screen-down; the Mac PS/2 input expects up.
 reg [7:0] mouse_buttons,mouse_x,mouse_y;
 wire signed [7:0] ps2_y = mouse_y==8'h80 ? 8'sd127 : -$signed(mouse_y);
 reg [63:0] reports[0:(1<<FIFO_BITS)-1];
 reg [FIFO_BITS:0] wp,rp;
 wire full=(wp[FIFO_BITS]!=rp[FIFO_BITS]) && (wp[FIFO_BITS-1:0]==rp[FIFO_BITS-1:0]);
 reg [2:0] parser,index;
 reg [63:0] incoming;
 reg [31:0] gap;
 reg [511:0] held,target;
 reg [8:0] scan;
 reg [1:0] phase;
 reg busy,recover;
 wire modifier=(scan==9'h012 || scan==9'h014 || scan==9'h011 || scan==9'h11f);
 wire changed=held[scan]!=target[scan];
 assign key_valid=busy && changed && ((phase==0 && !modifier && !target[scan]) || (phase==1 && modifier) || (phase==2 && !modifier && target[scan]));
 assign key_event={target[scan],scan};
 reg [511:0] decoded;reg rollover;reg [63:0] front;reg [8:0] c;integer i;
 always @* begin
  front=reports[rp[FIFO_BITS-1:0]];decoded=0;rollover=0;c=0;
  decoded[9'h012]=front[1]|front[5];
  decoded[9'h014]=front[0]|front[4]; // Ctrl
  decoded[9'h011]=front[2]|front[6]; // Alt
  decoded[9'h11f]=front[3]|front[7]; // GUI/Windows
  for(i=2;i<8;i=i+1)begin
   c=code(front[i*8+:8]);if(c!=0)decoded[c]=1;
   if(front[i*8+:8]>=1 && front[i*8+:8]<=3)rollover=1;
  end
 end
 always @(posedge clk)begin
  if(reset)begin mouse<=0;mouse_valid<=0;wheel<=0;mouse_buttons<=0;mouse_x<=0;mouse_y<=0;wp<=0;rp<=0;parser<=0;index<=0;incoming<=0;gap<=0;held<=0;target<=0;scan<=0;phase<=0;busy<=0;recover<=0;fault<=0;end
  else begin
   mouse_valid<=0;
   // Framing faults/partial packets do not fabricate a new keyboard state.
   if(parser!=0)begin
    if(gap==CLK_HZ/50)begin parser<=0;gap<=0;fault<=1;end else gap<=gap+1;
   end
   if(byte_error)begin parser<=0;fault<=1;end
   if(byte_valid)begin
    gap<=0;
    case(parser)
     0:if(byte_data==8'h57)parser<=1;
     1:if(byte_data==8'hab)parser<=2;else parser<=byte_data==8'h57 ? 1 : 0;
     2:begin index<=0;incoming<=0;if(byte_data==1)parser<=3;else if(byte_data==8'h80)parser<=4;else if(byte_data==2)parser<=5;else if(byte_data==4)parser<=6;else parser<=0;end
     3:begin
      incoming[index*8+:8]<=byte_data;
      if(index==7)begin
       parser<=0;
       if(full)begin fault<=1;recover<=1;end else begin reports[wp[FIFO_BITS-1:0]]<={byte_data,incoming[55:0]};wp<=wp+1'b1;end
      end else index<=index+1'b1;
     end
     4:parser<=0; // indicator state, not a key event
     5:begin
      case(index)
       0:mouse_buttons<=byte_data;
       1:mouse_x<=byte_data;
       2:mouse_y<=byte_data;
       3:begin
        // Preserve all three buttons; the 128K Mac uses the left button.
        mouse<={~mouse[24],ps2_y,mouse_x,2'b00,ps2_y[7],mouse_x[7],1'b1,mouse_buttons[2:0]};
        wheel<=byte_data;mouse_valid<=1;parser<=0;
       end
      endcase
      if(index!=3)index<=index+1'b1;
     end
     6:begin // Absolute-mode reports are framed but intentionally not translated.
      if(index==6)begin parser<=0;fault<=1;end else index<=index+1'b1;
     end
     default:parser<=0;
    endcase
   end
   if(recover)begin
    wp<=0;rp<=0;target<=0;scan<=0;phase<=0;busy<=1;recover<=0;parser<=0;
   end else if(!busy && rp!=wp)begin
    rp<=rp+1'b1;
    if(rollover)fault<=1; // preserve held state until a valid report arrives
    else begin target<=decoded;scan<=0;phase<=0;busy<=1;end
   end else if(busy && (!key_valid || key_ready))begin
    if(key_valid)held[scan]<=target[scan];
    if(scan==511)begin scan<=0;if(phase==2)busy<=0;else phase<=phase+1'b1;end
    else scan<=scan+1'b1;
   end
  end
 end
endmodule
