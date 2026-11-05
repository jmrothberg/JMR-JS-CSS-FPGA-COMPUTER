// Disk-program Toolbox primitives. No application-specific state or code.
// Same held req/reply and SRAM handshake as the file services (100 MHz).
// Logical arena addresses preserve the existing byte-per-word ABI.
module jmr_toolbox (
 input logic clk,rst_n,req,sys_valid,
 input logic [31:0] op,a,b,c,
 output logic busy,reply,
 output logic [31:0] result,
 output logic sram_req,sram_we,
 output logic [21:0] sram_addr,
 output logic [15:0] sram_wdata,
 input logic sram_ack,input logic [15:0] sram_rdata,
 output logic fb_we,output logic [18:0] fb_addr,output logic [7:0] fb_data,
 output logic fb_req,output logic [18:0] fb_raddr,
 input logic fb_ack,input logic [7:0] fb_rdata
);
 import jmr_js_vm_pkg::*;
 typedef enum logic [5:0] {IDLE,DISPATCH,READ_BLOCK,READ_SAVE,WRITE_BLOCK,
 FILL,CHUNK,DESC,DESC_SAVE,VALIDATE,CHECK_GEOMETRY,GEOMETRY,PIXEL,PIXEL_SAVE,COORD,DRAW,
 NEXT_PIXEL,STORE_PIXEL,RESOURCE_READ,RESOURCE_WRITE,COPY_VALIDATE,COPY_CHECK,COPY_SETUP,COPY_COORD,COPY_READ,COPY_FB_WAIT,COPY_SAVE,COPY_WRITE,COPY_NEXT,WAIT_MEM,GAP,DONE} state_t;
 state_t state,after_mem;
 logic [31:0] cmd,src,dst,left,total,desc_ptr;
 logic backwards;
 logic [4:0] count,index;
 logic [7:0] buffer[0:15];
 logic [7:0] desc[0:127];
 logic [31:0] copy_base,copy_extent;
 logic [15:0] copy_stride,copy_sw,copy_sh,copy_w,copy_h;
 logic signed [15:0] copy_dx,copy_dy,copy_cx,copy_cy;
 logic [15:0] copy_cw,copy_ch;
 logic copy_screen,copy_source_screen,copy_reverse,copy_ok;
 logic [31:0] copy_src_addr,copy_dst_addr;
 logic signed [31:0] copy_x,copy_y;
 logic [7:0] di;
 logic [7:0] byte_q,fill_value,pixel_q;
 logic [31:0] row_addr,pixel_addr,extent;
 logic [15:0] x,y,w,h,stride,sx,sy,sw,sh;
 logic signed [15:0] dx,dy,cx,cy;
 logic [15:0] cw,ch;
 logic [7:0] fmt,flags,scale,fg,bg;
 logic [3:0] zx,zy;
 logic [2:0] bitpos;
 
 logic [31:0] base,arena_limit;
 logic geometry_ok;
 logic cached_valid,read_high;
 logic [31:0] cached_addr;
 logic [7:0] cached_byte;
 logic signed [31:0] draw_x,draw_y;
 wire [1:0] zoom_shift=scale==8?2'd3:scale==4?2'd2:scale==2?2'd1:2'd0;
 wire signed [31:0] px=32'($signed(dx))+($signed({16'd0,x})<<<zoom_shift)+$signed({28'd0,zx});
 wire signed [31:0] py=32'($signed(dy))+($signed({16'd0,y})<<<zoom_shift)+$signed({28'd0,zy});
 function automatic logic [15:0] d16(input integer i);return {desc[i+1],desc[i]};endfunction
 function automatic logic range_ok(input logic [31:0] p,n);
  return p<=CSTG_WORDS && n<=CSTG_WORDS && n<=CSTG_WORDS-p;
 endfunction
 task automatic mem(input logic wr,input logic [31:0] p,input logic [7:0] v,input state_t ret);
  read_high<=0;sram_req<=1;sram_we<=wr;sram_addr<=cstg_word(p[20:0]);sram_wdata<={8'd0,v};after_mem<=ret;state<=WAIT_MEM;
 endtask
 assign busy=state!=IDLE;
 assign reply=state==DONE;
 always_ff @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;sram_req<=0;sram_we<=0;fb_we<=0;fb_req<=0;result<=0;end
  else begin
   fb_we<=0;
   // Finish an accepted bus transfer before aborting a stopped application.
   if(!req && !sram_req && !fb_req && state!=IDLE)state<=IDLE;
   else case(state)
    IDLE:if(req)begin cmd<=op;src<=a;dst<=b;left<=c;total<=c;fill_value<=b[7:0];desc_ptr<=a;state<=DISPATCH;end
    DISPATCH:begin
     cached_valid<=0;
     result<=32'hffffffff;
     case(cmd)
      0:begin result<=32'h0001003f;state<=DONE;end // v1 + operations 1 through 6
      1:if(range_ok(src,left)&&range_ok(dst,left))begin
       backwards<=dst>src && dst-src<left;
       if(left==0)begin result<=0;state<=DONE;end else state<=CHUNK;
      end else state<=DONE;
      2:if(range_ok(src,left))begin
       if(left==0)begin result<=0;state<=DONE;end else state<=FILL;
      end else state<=DONE;
      3,4:if(range_ok(desc_ptr,64))begin di<=0;state<=DESC;end else state<=DONE;
      6:if(left==0 && range_ok(src,64) && range_ok(dst,64))begin di<=0;state<=DESC;end else state<=DONE;
      5:if(sys_valid && src<=24320 && left<=24320-src && range_ok(dst,left))begin
       if(left==0)begin result<=0;state<=DONE;end else state<=RESOURCE_READ;
      end else state<=DONE;
      default:state<=DONE;
     endcase
    end
    CHUNK:begin count<=left>16?5'd16:5'(left);index<=0;state<=READ_BLOCK;end
    READ_BLOCK:mem(0,src+(backwards?left-32'(count):total-left)+32'(index),0,READ_SAVE);
    READ_SAVE:begin
     buffer[index[3:0]]<=byte_q;
     if(index+1==count)begin index<=0;state<=WRITE_BLOCK;end
     else begin index<=index+1'b1;state<=READ_BLOCK;end
    end
    WRITE_BLOCK:begin
     mem(1,dst+(backwards?left-32'(count):total-left)+32'(index),buffer[index[3:0]],WRITE_BLOCK);
     if(index+1==count)begin
      left<=left-32'(count);index<=0;
      if(left==32'(count))begin result<=total;after_mem<=DONE;end
      else after_mem<=CHUNK;
     end else index<=index+1'b1;
    end
    FILL:begin
     mem(1,src+total-left,fill_value,FILL);left<=left-1'b1;
     if(left==1)begin result<=total;after_mem<=DONE;end
    end
    DESC:mem(0,(di<64?desc_ptr:dst)+32'(di[5:0]),0,DESC_SAVE);
    DESC_SAVE:begin desc[di[6:0]]<=byte_q;
     if(cmd==6 ? di==127 : di==63)state<=cmd==6?COPY_VALIDATE:VALIDATE;
     else begin di<=di+1'b1;state<=DESC;end
    end
    VALIDATE:begin
     base<={desc[7],desc[6],desc[5],desc[4]};stride<=d16(8);sw<=d16(10);sh<=d16(12);
     sx<=d16(14);sy<=d16(16);w<=d16(18);h<=d16(20);dx<=d16(22);dy<=d16(24);
     cx<=d16(26);cy<=d16(28);cw<=d16(30);ch<=d16(32);
     fmt<=desc[1];flags<=desc[2];scale<=desc[3];fg<=desc[34];bg<=desc[35];
     extent<=32'(d16(8))*32'(d16(12));
     arena_limit<=CSTG_WORDS-{desc[7],desc[6],desc[5],desc[4]};state<=CHECK_GEOMETRY;
    end
    CHECK_GEOMETRY:begin
     // Register validation separately from the geometry/DSP path and FSM.
     geometry_ok<=desc[0]==1 && (fmt==1||fmt==4||fmt==8) &&
       (scale==1||scale==2||scale==4||scale==8) && sw!=0 && sh!=0 &&
       base<=CSTG_WORDS && extent<=arena_limit &&
       32'(stride)>=(fmt==1?((32'(sw)+7)>>3):fmt==4?((32'(sw)+1)>>1):32'(sw)) &&
       32'(sx)+32'(w)<=32'(sw) && 32'(sy)+32'(h)<=32'(sh);
     state<=GEOMETRY;
    end
    GEOMETRY:begin
     // Validate the whole surface BEFORE any write; no truncated overflow.
     if(!geometry_ok)state<=DONE;
     else if(w==0||h==0)begin result<=0;state<=DONE;end
     else begin x<=0;y<=0;row_addr<=base+32'(sy)*32'(stride);state<=PIXEL;end
    end
    PIXEL:begin
     logic [31:0] address;
     bitpos<=3'(sx+x);
     address=row_addr+(fmt==1?((32'(sx)+32'(x))>>3):fmt==4?((32'(sx)+32'(x))>>1):32'(sx)+32'(x));
     pixel_addr<=address;
     // Adjacent packed pixels share a byte. Avoid rereading DDR for each bit.
     if(cached_valid && address==cached_addr)begin byte_q<=cached_byte;state<=PIXEL_SAVE;end
     else mem(0,address,0,PIXEL_SAVE);
    end
    PIXEL_SAVE:begin
     logic [7:0] value,ink;
     cached_valid<=1;cached_addr<=pixel_addr;cached_byte<=byte_q;
     value=fmt==1?((byte_q>>(7-bitpos))&8'd1):fmt==4?(bitpos[0]?{4'd0,byte_q[3:0]}:{4'd0,byte_q[7:4]}):byte_q;
     if(cmd==4)begin
      ink=desc[{3'b101,3'(sy+y)}][7-3'(sx+x)]?fg:bg;
      if(fmt==1)begin pixel_q<=(byte_q & ~(8'h80>>bitpos)) | (ink[0]?(8'h80>>bitpos):8'd0);end
      else if(fmt==4)pixel_q<=bitpos[0]?{byte_q[7:4],ink[3:0]}:{ink[3:0],byte_q[3:0]};
      else pixel_q<=ink;
      state<=STORE_PIXEL;
     end else begin
      pixel_q<=fmt==1?(value==0?bg:fg):fmt==4?desc[{2'b11,value[3:0]}]:value;
      zx<=0;zy<=0;
      state<=flags[0]&&value==0?NEXT_PIXEL:COORD;
     end
    end
    STORE_PIXEL:begin cached_byte<=pixel_q;mem(1,pixel_addr,pixel_q,NEXT_PIXEL);end
    COORD:begin draw_x<=px;draw_y<=py;state<=DRAW;end
    DRAW:begin
     state<=COORD;
     if(draw_x>=0&&draw_x<640&&draw_y>=0&&draw_y<480&&draw_x>=32'($signed(cx))&&draw_y>=32'($signed(cy))&&
       draw_x<32'($signed(cx))+$signed({16'd0,cw})&&draw_y<32'($signed(cy))+$signed({16'd0,ch}))begin
      fb_we<=1;fb_addr<=19'(draw_y*640+draw_x);fb_data<=pixel_q;
     end
     if(zx+1==scale)begin zx<=0;if(zy+1==scale)state<=NEXT_PIXEL;else zy<=zy+1'b1;end
     else zx<=zx+1'b1;
    end
    NEXT_PIXEL:if(x+1==w)begin
     x<=0;if(y+1==h)begin result<=32'(w)*32'(h);state<=DONE;end
     else begin y<=y+1'b1;row_addr<=row_addr+32'(stride);state<=PIXEL;end
    end else begin x<=x+1'b1;state<=PIXEL;end
    // Raw 8-bit rectangle transport. Policy and richer raster modes live in
    // JavaScript. Capture BOTH descriptors before touching either surface.
    COPY_VALIDATE:begin
     base<={desc[7],desc[6],desc[5],desc[4]};stride<=d16(8);sw<=d16(10);sh<=d16(12);
     sx<=d16(14);sy<=d16(16);w<=d16(18);h<=d16(20);
     copy_base<={desc[71],desc[70],desc[69],desc[68]};
     copy_stride<=d16(72);copy_sw<=d16(74);copy_sh<=d16(76);
     copy_w<=d16(82);copy_h<=d16(84);copy_dx<=d16(86);copy_dy<=d16(88);
     copy_cx<=d16(90);copy_cy<=d16(92);copy_cw<=d16(94);copy_ch<=d16(96);
     copy_source_screen<=desc[2]==2;copy_screen<=desc[66]==2;
     extent<=32'(d16(8))*32'(d16(12));
     copy_extent<=32'(d16(72))*32'(d16(76));state<=COPY_CHECK;
    end
    COPY_CHECK:begin
     // Only raw 8-bit, unscaled srcCopy is part of this transport ABI.
     // Reject incompatible alias layouts rather than corrupting unread rows.
     copy_ok<=desc[0]==1 && desc[64]==1 && desc[1]==8 && desc[65]==8 &&
      (desc[2]==0||desc[2]==2) && (desc[66]==0||desc[66]==2) && desc[3]==1 && desc[67]==1 &&
      sw!=0 && sh!=0 && copy_sw!=0 && copy_sh!=0 && stride>=sw && copy_stride>=copy_sw &&
      32'(sx)+32'(w)<=32'(sw) && 32'(sy)+32'(h)<=32'(sh) && w==copy_w && h==copy_h &&
      (copy_source_screen?(base==0 && stride==640 && sw==640 && sh==480):range_ok(base,extent)) &&
      (copy_screen?(copy_base==0 && copy_stride==640 && copy_sw==640 && copy_sh==480):range_ok(copy_base,copy_extent)) &&
      (copy_screen!=copy_source_screen || copy_screen ||
       base+extent<=copy_base || copy_base+copy_extent<=base || stride==copy_stride);
     copy_reverse<=copy_screen==copy_source_screen &&
      $signed({1'b0,copy_base})+$signed({17'd0,copy_stride})*$signed(copy_dy)+$signed(copy_dx) >
      $signed({1'b0,base})+$signed({17'd0,stride})*$signed({1'b0,sy})+$signed({1'b0,sx});
     state<=COPY_SETUP;
    end
    COPY_SETUP:begin
     if(!copy_ok)state<=DONE;
     else if(w==0||h==0)begin result<=0;state<=DONE;end
     else begin x<=copy_reverse?w-1'b1:16'd0;y<=copy_reverse?h-1'b1:16'd0;state<=COPY_COORD;end
    end
    COPY_COORD:begin
     copy_x<=32'($signed(copy_dx))+$signed({16'd0,x});
     copy_y<=32'($signed(copy_dy))+$signed({16'd0,y});
     copy_src_addr<=base+(32'(sy)+32'(y))*32'(stride)+32'(sx)+32'(x);
     state<=COPY_READ;
    end
    COPY_READ:begin
     // Destination clipping changes neither the requested result count nor
     // source alignment. Source bounds were checked before the first write.
     if(copy_x<0 || copy_y<0 || copy_x>=$signed({16'd0,copy_sw}) || copy_y>=$signed({16'd0,copy_sh}) ||
      copy_x<32'($signed(copy_cx)) || copy_y<32'($signed(copy_cy)) ||
      copy_x>=32'($signed(copy_cx))+$signed({16'd0,copy_cw}) ||
      copy_y>=32'($signed(copy_cy))+$signed({16'd0,copy_ch}))state<=COPY_NEXT;
     else begin
      copy_dst_addr<=copy_base+32'(copy_y)*32'(copy_stride)+32'(copy_x);
      if(copy_source_screen)begin fb_req<=1;fb_raddr<=19'(copy_src_addr);state<=COPY_FB_WAIT;end
      else mem(0,copy_src_addr,0,COPY_SAVE);
     end
    end
    COPY_FB_WAIT:if(fb_ack)begin fb_req<=0;byte_q<=fb_rdata;state<=COPY_SAVE;end
    COPY_SAVE:begin pixel_q<=byte_q;state<=COPY_WRITE;end
    COPY_WRITE:begin
     if(copy_screen)begin fb_we<=1;fb_addr<=19'(copy_dst_addr);fb_data<=pixel_q;state<=COPY_NEXT;end
     else mem(1,copy_dst_addr,pixel_q,COPY_NEXT);
    end
    COPY_NEXT:begin
     if(copy_reverse)begin
      if(x==0)begin x<=w-1'b1;if(y==0)begin result<=32'(w)*32'(h);state<=DONE;end
       else begin y<=y-1'b1;state<=COPY_COORD;end end
      else begin x<=x-1'b1;state<=COPY_COORD;end
     end else begin
      if(x+1==w)begin x<=0;if(y+1==h)begin result<=32'(w)*32'(h);state<=DONE;end
       else begin y<=y+1'b1;state<=COPY_COORD;end end
      else begin x<=x+1'b1;state<=COPY_COORD;end
     end
    end
    RESOURCE_READ:begin
     // Verified boot image: packed words, read-only, outside the app arena.
     sram_req<=1;sram_we<=0;sram_addr<=22'd3565568+22'((src+total-left)>>1);
     sram_wdata<=0;read_high<=1'(src+total-left);after_mem<=RESOURCE_WRITE;state<=WAIT_MEM;
    end
    RESOURCE_WRITE:begin
     mem(1,dst+total-left,byte_q,RESOURCE_READ);left<=left-1'b1;
     if(left==1)begin result<=total;after_mem<=DONE;end
    end
    WAIT_MEM:if(sram_ack)begin byte_q<=read_high?sram_rdata[15:8]:sram_rdata[7:0];sram_req<=0;sram_we<=0;state<=GAP;end
    GAP:state<=after_mem;
    DONE:if(!req)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
