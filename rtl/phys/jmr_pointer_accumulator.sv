// Signed PS/2-format reports -> the common canvas pointer handshake.
// Also usable after the custom board's CH9350L report decoder. A 16-report
// FIFO preserves button transitions while the VM event queue is occupied.
module jmr_pointer_accumulator (
 input logic clk,rst_n,
 input logic [24:0] packet,
 output logic sample_valid,
 input logic sample_ready,
 output logic [9:0] sample_x,
 output logic [8:0] sample_y,
 output logic [2:0] sample_buttons,
 output logic [31:0] dropped_reports
);
 (* ram_style="distributed" *) logic [23:0] reports [0:15];
 logic [3:0] wp,rp;
 logic [4:0] count;
 logic toggle_q,release_pending;
 logic [9:0] x;
 logic [8:0] y;
 logic [23:0] head;
 logic signed [11:0] nx,ny,dx,dy;
 wire incoming=packet[24]!=toggle_q;
 wire pop=sample_valid && sample_ready && !release_pending;
 wire put=incoming && (count<16 || pop);
 assign head=reports[rp];
 always_comb begin
  dx=$signed({{4{head[4]}},head[15:8]});
  dy=$signed({{4{head[5]}},head[23:16]});
  if(head[7:6]!=0)begin dx=0;dy=0;end
  nx=$signed({2'd0,x})+dx;
  ny=$signed({3'd0,y})-dy;
  sample_valid=release_pending || count!=0;
  sample_x=release_pending?x:nx<0?10'd0:nx>639?10'd639:10'(nx);
  sample_y=release_pending?y:ny<0?9'd0:ny>479?9'd479:9'(ny);
  sample_buttons=release_pending?3'd0:head[2:0];
 end
 always_ff @(posedge clk) if(put)reports[wp]<=packet[23:0];
 always_ff @(posedge clk)begin
  if(!rst_n)begin wp<=0;rp<=0;count<=0;toggle_q<=packet[24];x<=320;y<=240;release_pending<=0;dropped_reports<=0;end
  else begin
   toggle_q<=packet[24];
   case({put,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
   if(put)wp<=wp+1'b1;
   if(pop)rp<=rp+1'b1;
   if(sample_valid && sample_ready)begin x<=sample_x;y<=sample_y;if(release_pending)release_pending<=0;end
   if(incoming && !put)begin
    // Report overload explicitly and release any held button; never leave
    // the machine stuck dragging after losing a release to a full queue.
    dropped_reports<=dropped_reports+1'b1;count<=0;wp<=rp;release_pending<=1;
   end
  end
 end
endmodule
