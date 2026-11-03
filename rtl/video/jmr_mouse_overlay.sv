// Original Macintosh arrow. Quit lives in the Enterprise menu.
module jmr_mouse_overlay (
 input logic [9:0] x,y,mouse_x,
 input logic [8:0] mouse_y,
 input logic show_pointer,
 output logic opaque,
 output logic [23:0] rgb
);
 logic signed [11:0] cx,cy;
 logic [15:0] mask,bits;
 always_comb begin
  cx=$signed({2'b0,x})-$signed({2'b0,mouse_x})+12'd1;
  cy=$signed({2'b0,y})-$signed({3'b0,mouse_y})+12'd1;
  opaque=0;rgb=0;mask=0;bits=0;
  case(cy)
   0:begin mask=16'hc000;bits=16'h0000;end
   1:begin mask=16'he000;bits=16'h4000;end
   2:begin mask=16'hf000;bits=16'h6000;end
   3:begin mask=16'hf800;bits=16'h7000;end
   4:begin mask=16'hfc00;bits=16'h7800;end
   5:begin mask=16'hfe00;bits=16'h7c00;end
   6:begin mask=16'hff00;bits=16'h7e00;end
   7:begin mask=16'hff80;bits=16'h7f00;end
   8:begin mask=16'hffc0;bits=16'h7f80;end
   9:begin mask=16'hffe0;bits=16'h7c00;end
   10:begin mask=16'hfe00;bits=16'h6c00;end
   11:begin mask=16'hef00;bits=16'h4600;end
   12:begin mask=16'hcf00;bits=16'h0600;end
   13:begin mask=16'h8780;bits=16'h0300;end
   14:begin mask=16'h0780;bits=16'h0300;end
   15:begin mask=16'h0380;bits=16'h0000;end
   default:;
  endcase
  if(show_pointer && cx>=0 && cx<16 && cy>=0 && cy<16 && mask[15-cx])begin
   opaque=1;rgb=bits[15-cx]?24'h000000:24'hffffff;
  end
 end
endmodule
