// Coherent bundled UI state between independent core and pixel clocks.
// The source holds the entire bundle until the destination acknowledges it.
module jmr_ui_snapshot #(parameter integer WIDTH=1)(
 input logic clk,rst_n,pixel_clk,
 input logic [WIDTH-1:0] source,
 output logic [WIDTH-1:0] pixels
);
 logic [WIDTH-1:0] holding;
 logic request,ack,seen,pending;
 (* ASYNC_REG="TRUE" *) logic [1:0] ack_sync,request_sync;
 always_ff @(posedge clk)begin
  if(!rst_n)begin holding<=0;request<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   // The handshake itself bounds the capture rate. Re-capture even when the
   // value is unchanged: a wide change detector puts every menu selection on
   // the enable path of the entire bundle. Repeated equal snapshots are safe.
   if(ack_sync[1]==request)begin holding<=source;request<=!request;end
  end
 end
 always_ff @(posedge pixel_clk)begin
  if(!rst_n)begin pixels<=0;request_sync<=0;ack<=0;seen<=0;pending<=0;end
  else begin
   request_sync<={request_sync[0],request};
   if(request_sync[1]!=seen)begin seen<=request_sync[1];pending<=1;end
   else if(pending)begin pixels<=holding;ack<=seen;pending<=0;end
  end
 end
endmodule

// Boot-only resource transport. Hold each word until its pixel-clock write
// has occurred; no resource RAM is written across the display clock domain.
module jmr_resource_bridge (
 input logic clk,pixel_clk,rst_n,
 input logic write_valid,
 input logic [13:0] write_addr,
 input logic [15:0] write_data,
 output logic ready,
 output logic pixel_valid,
 output logic [13:0] pixel_addr,
 output logic [15:0] pixel_data
);
 logic [29:0] holding;
 logic request,ack,seen,pending;
 (* ASYNC_REG="TRUE" *) logic [1:0] request_sync,ack_sync;
 assign ready=request==ack_sync[1];
 always_ff @(posedge clk)begin
  if(!rst_n)begin holding<=0;request<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(write_valid && ready)begin holding<={write_addr,write_data};request<=!request;end
  end
 end
 always_ff @(posedge pixel_clk)begin
  if(!rst_n)begin request_sync<=0;seen<=0;ack<=0;pending<=0;pixel_valid<=0;pixel_addr<=0;pixel_data<=0;end
  else begin
   request_sync<={request_sync[0],request};pixel_valid<=0;
   if(request_sync[1]!=seen)begin
    {pixel_addr,pixel_data}<=holding;pixel_valid<=1;seen<=request_sync[1];pending<=1;
   end else if(pending)begin
    // Consumer RAM samples pixel_valid at this edge, before acknowledging.
    ack<=seen;pending<=0;
   end
  end
 end
endmodule
