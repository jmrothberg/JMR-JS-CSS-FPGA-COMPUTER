// Adapted from Macintosh/rtl/board/ps2_mouse_host.sv (local native implementation).
// Native three-byte PS/2 mouse host. Ports expose open-drain LOW enables;
// board wiring must use assign pin = low ? 1'b0 : 1'bz, never drive high.
// Protocol references: Digilent PmodPS/2 manual; U Toronto DE1-SoC PS/2 guide.
module jmr_ps2_mouse_host #(
 parameter int CLK_HZ=32500000,
 parameter int POWER_CYCLES=CLK_HZ,
 parameter int INHIBIT_CYCLES=(CLK_HZ/10000)+1,
 parameter int SETUP_CYCLES=(CLK_HZ/100000)+1,
 parameter int TIMEOUT_CYCLES=CLK_HZ*2,
 parameter int FRAME_TIMEOUT_CYCLES=CLK_HZ/500
)(input logic clk,reset,input logic clock_in,data_in,
 output logic clock_low,data_low,output logic [24:0] packet,
 output logic ready,output logic [31:0] errors);
 typedef enum logic [3:0] {POWER,INHIBIT,REQUEST,SEND,ACK_BIT,REPLY,BAT,IDENT,STREAM} state_t;
 state_t state;
 (* ASYNC_REG="TRUE" *) logic [2:0] clock_sync,data_sync;
 logic old_clock;
 wire falling=old_clock && (clock_sync==0);
 logic [31:0] timer,frame_timer;
 logic [7:0] command,rx_data,flags,dx;
 logic [3:0] tx_index,rx_index;
 logic parity,rx_valid,rx_bad;
 logic [1:0] packet_index;
 always_ff @(posedge clk) begin
  if(reset) begin clock_sync<=7;data_sync<=7;old_clock<=1;end
  else begin clock_sync<={clock_sync[1:0],clock_in};data_sync<={data_sync[1:0],data_in};if(clock_sync==7)old_clock<=1;else if(clock_sync==0)old_clock<=0;end
 end
 wire receiving=state==REPLY || state==BAT || state==IDENT || state==STREAM;
 // Reject framing/parity errors before handing a byte to the packet parser.
 always_ff @(posedge clk) begin
  rx_valid<=0;rx_bad<=0;
  if(reset || !receiving) begin rx_index<=0;rx_data<=0;parity<=0;frame_timer<=0;end
  else begin
   if(rx_index!=0) frame_timer<=frame_timer+1;
   if(rx_index!=0 && frame_timer>=FRAME_TIMEOUT_CYCLES) begin rx_bad<=1;rx_index<=0;frame_timer<=0;end
   else if(falling) begin
    frame_timer<=0;
    if(rx_index==0) begin if(!data_sync[2]) begin rx_index<=1;parity<=0;end end
    else if(rx_index<=8) begin rx_data[rx_index-1]<=data_sync[2];parity<=parity^data_sync[2];rx_index<=rx_index+1;end
    else if(rx_index==9) begin parity<=parity^data_sync[2];rx_index<=10;end
    else begin rx_index<=0;if(data_sync[2] && parity) rx_valid<=1;else rx_bad<=1;end
   end
  end
 end
 always_ff @(posedge clk) begin
  if(reset) begin state<=POWER;timer<=0;clock_low<=0;data_low<=0;command<=8'hff;tx_index<=0;
   packet<=0;ready<=0;errors<=0;packet_index<=0;flags<=0;dx<=0;end
  else begin
   timer<=timer+1;
   if((state!=POWER && state!=STREAM && timer>=TIMEOUT_CYCLES) || (state==STREAM && packet_index!=0 && timer>=FRAME_TIMEOUT_CYCLES*5) || rx_bad) begin
    errors<=errors+1;ready<=0;clock_low<=0;data_low<=0;state<=POWER;timer<=0;command<=8'hff;packet_index<=0;
    // Release a held guest button on lost communication.
    packet<={~packet[24],16'd0,8'h08};
   end else case(state)
    POWER:if(timer>=POWER_CYCLES) begin clock_low<=1;timer<=0;command<=8'hff;state<=INHIBIT;end
    INHIBIT:if(timer>=INHIBIT_CYCLES) begin data_low<=1;timer<=0;state<=REQUEST;end
    REQUEST:if(timer>=SETUP_CYCLES) begin clock_low<=0;timer<=0;tx_index<=0;state<=SEND;end
    SEND:if(falling) begin
     if(tx_index<8) data_low<=!command[tx_index[2:0]];
     else if(tx_index==8) data_low<=^command; // drive low when odd parity bit is zero
     else begin data_low<=0;state<=ACK_BIT;end
     tx_index<=tx_index+1;
    end
    ACK_BIT:if(falling) begin
     if(data_sync[2]) begin state<=POWER;timer<=0;errors<=errors+1;command<=8'hff;end
     else begin state<=REPLY;timer<=0;end
    end
    REPLY:if(rx_valid) begin
     if(rx_data==8'hfa) begin
      timer<=0;if(command==8'hff) state<=BAT;
      else begin state<=STREAM;ready<=1;packet_index<=0;end
     end else begin state<=POWER;timer<=0;errors<=errors+1;command<=8'hff;end
    end
    BAT:if(rx_valid) begin
     timer<=0;if(rx_data==8'haa) state<=IDENT;
     else begin state<=POWER;errors<=errors+1;command<=8'hff;end
    end
    IDENT:if(rx_valid) begin
     timer<=0;if(rx_data==0) begin command<=8'hf4;clock_low<=1;state<=INHIBIT;end
     else begin state<=POWER;errors<=errors+1;command<=8'hff;end
    end
    STREAM:begin
     if(packet_index==0 || rx_valid) timer<=0;
     if(rx_valid) case(packet_index)
      0:if(rx_data[3]) begin flags<=rx_data;packet_index<=1;end
      1:begin dx<=rx_data;packet_index<=2;end
      2:begin
       // Overflowed movement is discarded, but button state still updates.
       // The JS machine preserves all three button bits.
       packet<={~packet[24],flags[7:6]!=0?16'd0:{rx_data,dx},
                flags};
       packet_index<=0;
      end
      default:packet_index<=0;
     endcase
    end
    default:begin state<=POWER;timer<=0;clock_low<=0;data_low<=0;ready<=0;end
   endcase
  end
 end
endmodule
