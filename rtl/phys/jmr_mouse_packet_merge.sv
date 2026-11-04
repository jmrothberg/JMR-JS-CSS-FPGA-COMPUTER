// Two independently clocked PS/2 hosts, one pointer. Host outputs are in clk.
// Each host holds its report until the next physical packet (many cycles).
// Consume at most one per cycle; simultaneous reports survive on both inputs.
// Buttons are ORed: an idle backup mouse cannot release the other's drag.
module jmr_mouse_packet_merge (
 input logic clk,rst_n,
 input logic [24:0] packet_a,packet_b,
 output logic [24:0] packet
);
 logic seen_a,seen_b,prefer_b;
 logic [2:0] buttons_a,buttons_b;
 wire pending_a=packet_a[24]!=seen_a;
 wire pending_b=packet_b[24]!=seen_b;
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   seen_a<=packet_a[24];seen_b<=packet_b[24];prefer_b<=0;
   buttons_a<=0;buttons_b<=0;packet<=0;
  end else if(pending_b && (!pending_a || prefer_b))begin
   seen_b<=packet_b[24];buttons_b<=packet_b[2:0];prefer_b<=0;
   packet<={~packet[24],packet_b[23:3],packet_b[2:0]|buttons_a};
  end else if(pending_a)begin
   seen_a<=packet_a[24];buttons_a<=packet_a[2:0];prefer_b<=1;
   packet<={~packet[24],packet_a[23:3],packet_a[2:0]|buttons_b};
  end
 end
endmodule
