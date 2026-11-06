// Disk-program Toolbox primitives. No application-specific state or code.
// Same held req/reply and SRAM handshake as the file services (100 MHz).
// Logical arena addresses preserve the existing byte-per-word ABI.
module jmr_toolbox (
 input logic clk,rst_n,req,sys_valid,
 input logic clip_reset,
 output logic clip_enabled,
 output logic [9:0] clip_x0,clip_y0,clip_x1,clip_y1,fb_x,fb_y,
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
 NEXT_PIXEL,STORE_PIXEL,RESOURCE_READ,RESOURCE_WRITE,COPY_VALIDATE,COPY_CHECK,COPY_SETUP,COPY_COORD,COPY_READ,COPY_FB_WAIT,COPY_SAVE,COPY_WRITE,COPY_NEXT,WAIT_MEM,GAP,DONE,COPY_MASK,COPY_MASK_SAVE,COPY_SOURCE,COPY_DEST,COPY_DEST_FB_WAIT,COPY_BLEND,TYPED_READ,TYPED_SAVE,TYPED_WRITE} state_t;
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
 logic copy_ext_ok;
 logic [2:0] copy_mode;
 logic copy_mask,copy_pattern;
 logic [31:0] mask_base,mask_extent;
 logic [15:0] mask_stride;
 logic [$clog2(CSTG_WORDS)-1:0] mask_row,mask_addr;
 logic signed [32:0] copy_src_product,copy_dst_product,copy_src_start,copy_dst_start;
 logic [31:0] copy_src_addr,copy_dst_addr;
 logic signed [31:0] copy_x,copy_y;
 logic [7:0] di;
 logic [7:0] byte_q,fill_value,pixel_q;
 logic [31:0] row_addr,pixel_addr,extent;
 logic [15:0] x,y,w,h,stride,sx,sy,sw,sh;
 logic signed [15:0] dx,dy,cx,cy;
 logic signed [17:0] draw_clip_x1,draw_clip_y1;
 logic [7:0] fmt,flags,scale,fg,bg;
 logic [3:0] zx,zy;
 logic [2:0] bitpos;
 
 logic [31:0] base,arena_limit;
 logic geometry_ok;
 logic cached_valid,read_high;
 logic [31:0] cached_addr;
 logic [7:0] cached_byte;
 // The packed-pixel, op7 mask and op5 resource caches are mutually exclusive
 // commands, so share the existing tag/valid/low byte. Only SYS needs high byte.
 logic [7:0] resource_high_byte;
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
 function automatic logic [9:0] clip_bound(input logic signed [17:0] v,input logic [9:0] limit);
  if(v<0)return 0;
  if(v>$signed({8'd0,limit}))return limit;
  return v[9:0];
 endfunction
 // Independent configuration register: application boundary reset dominates.
 always_ff @(posedge clk)begin
  if(!rst_n || clip_reset)begin
   clip_enabled<=0;clip_x0<=0;clip_y0<=0;clip_x1<=640;clip_y1<=480;
  end else if(state==DISPATCH && req && cmd==12)begin
   if(total==1 && src==0 && dst==0)begin
    clip_enabled<=0;clip_x0<=0;clip_y0<=0;clip_x1<=640;clip_y1<=480;
   end else if(total==0)begin
    clip_enabled<=1;
    clip_x0<=clip_bound($signed({{2{src[15]}},src[15:0]}),640);
    clip_y0<=clip_bound($signed({{2{src[31]}},src[31:16]}),480);
    clip_x1<=clip_bound($signed({{2{src[15]}},src[15:0]})+$signed({2'b0,dst[15:0]}),640);
    clip_y1<=clip_bound($signed({{2{src[31]}},src[31:16]})+$signed({2'b0,dst[31:16]}),480);
   end
  end
 end
 logic busy_q;
 assign busy=busy_q;
 assign reply=state==DONE;
 // Compute whether the existing FSM's NEXT state is non-IDLE. The FSM
 // itself and every request/reply/memory beat remain unchanged.
 always_ff @(posedge clk)begin
  if(!rst_n)busy_q<=0;
  else if(!req && !sram_req && !fb_req && state!=IDLE)busy_q<=0;
  else case(state)
   IDLE:busy_q<=req;
   GAP:busy_q<=after_mem!=IDLE;
   DONE:busy_q<=req;
   default:busy_q<=(state<=TYPED_WRITE);
  endcase
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;sram_req<=0;sram_we<=0;fb_we<=0;fb_req<=0;result<=0;cached_valid<=0;end
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
      0:begin result<=32'h00010fff;state<=DONE;end // v1 descriptors + operations 1 through 12
      1:if(range_ok(src,left)&&range_ok(dst,left))begin
       backwards<=dst>src && dst-src<left;
       if(left==0)begin result<=0;state<=DONE;end else state<=CHUNK;
      end else state<=DONE;
      2:if(range_ok(src,left))begin
       if(left==0)begin result<=0;state<=DONE;end else state<=FILL;
      end else state<=DONE;
      3,4:if(range_ok(desc_ptr,64))begin di<=0;state<=DESC;end else state<=DONE;
      6,7:if(left==0 && range_ok(src,64) && range_ok(dst,64))begin di<=0;state<=DESC;end else state<=DONE;
      5:if(sys_valid && src<=24320 && left<=24320-src && range_ok(dst,left))begin
       if(left==0)begin result<=0;state<=DONE;end else state<=RESOURCE_READ;
      end else state<=DONE;
      12:begin
       if(total==0 || (total==1 && src==0 && dst==0))result<=1;
       state<=DONE;
      end
      // Typed staging services: validate the entire span before any transfer.
      8:if(dst==0 && total==0 && range_ok(src,4))begin
       index<=0;result<=0;state<=TYPED_READ;
      end else state<=DONE;
      9,10,11:if((cmd==10 || total==0) && range_ok(src,cmd==10?8:cmd==11?2:4))begin
       index<=0;count<=cmd==10?5'd8:cmd==11?5'd2:5'd4;state<=TYPED_WRITE;
      end else state<=DONE;
      default:state<=DONE;
     endcase
    end
    TYPED_READ:mem(0,src+32'(index),0,TYPED_SAVE);
    TYPED_SAVE:begin
     result<={byte_q,result[31:8]};
     if(index==3)state<=DONE;
     else begin index<=index+1'b1;state<=TYPED_READ;end
    end
    TYPED_WRITE:begin
     mem(1,src+32'(index),dst[7:0],TYPED_WRITE);
     dst<=index==3?total:{8'd0,dst[31:8]};
     if(index+1==count)begin result<=32'(count);after_mem<=DONE;end
     else index<=index+1'b1;
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
     if((cmd==6||cmd==7) ? di==127 : di==63)state<=(cmd==6||cmd==7)?COPY_VALIDATE:VALIDATE;
     else begin di<=di+1'b1;state<=DESC;end
    end
    VALIDATE:begin
     base<={desc[7],desc[6],desc[5],desc[4]};stride<=d16(8);sw<=d16(10);sh<=d16(12);
     sx<=d16(14);sy<=d16(16);w<=d16(18);h<=d16(20);dx<=d16(22);dy<=d16(24);
     cx<=d16(26);cy<=d16(28);
     // Signed16 origin + unsigned16 extent is exactly signed18. Snapshot
     // once in the existing descriptor setup beat, not on every pixel CE.
     draw_clip_x1<=$signed({{2{desc[27][7]}},d16(26)})+$signed({2'b0,d16(30)});
     draw_clip_y1<=$signed({{2{desc[29][7]}},d16(28)})+$signed({2'b0,d16(32)});
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
     // GEOMETRY proves base + stride*sh <= CSTG_WORDS, sy+y < sh,
     // and the packed byte offset < stride. Thus every PIXEL address is
     // below CSTG_WORDS, including the last byte of the arena. Keep the
     // addition at that proven width before cache comparison.
     logic [$clog2(CSTG_WORDS)-1:0] address;
     // Every predecessor completed a read or drained a write: WE is already zero.
     sram_we<=0;
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
       draw_x<$signed(draw_clip_x1)&&draw_y<$signed(draw_clip_y1))begin
      fb_we<=1;fb_x<=10'(draw_x);fb_y<=10'(draw_y);fb_addr<=19'(draw_y*640+draw_x);fb_data<=pixel_q;
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
     copy_mode<=cmd==7?desc[36][2:0]:3'd0;
     copy_mask<=cmd==7 && desc[37][0];copy_pattern<=cmd==7 && desc[37][1];
     mask_base<={desc[51],desc[50],desc[49],desc[48]};mask_stride<=d16(52);
     mask_extent<=32'(d16(52))*32'(d16(20));
     extent<=32'(d16(8))*32'(d16(12));
     copy_extent<=32'(d16(72))*32'(d16(76));
     // Snapshot descriptors are complete. Stage overlap arithmetic through
     // existing setup beats; no native reply or per-pixel cycle is added.
     copy_src_product<=$signed({17'd0,d16(8)})*$signed({17'd0,d16(16)});
     copy_dst_product<=$signed({17'd0,d16(72)})*$signed(d16(88));
     state<=COPY_CHECK;
    end
    COPY_CHECK:begin
     // Raw 8-bit unscaled transfer; operation 7 shares the transport loop.
     // Snapshot and validate optional mask before any framebuffer/arena write.
     copy_ext_ok<=cmd==6 || (desc[36]<=5 && desc[37]<=3 &&
      (!copy_mask || (32'(mask_stride)>=((32'(w)+7)>>3) && range_ok(mask_base,mask_extent) &&
       (copy_screen || mask_base+mask_extent<=copy_base || copy_base+copy_extent<=mask_base))));
     // Reject incompatible alias layouts rather than corrupting unread rows.
     copy_ok<=desc[0]==1 && desc[64]==1 && desc[1]==8 && desc[65]==8 &&
      (desc[2]==0||desc[2]==2) && (desc[66]==0||desc[66]==2) && desc[3]==1 && desc[67]==1 &&
      sw!=0 && sh!=0 && copy_sw!=0 && copy_sh!=0 && stride>=sw && copy_stride>=copy_sw &&
      32'(sx)+32'(w)<=32'(sw) && 32'(sy)+32'(h)<=32'(sh) && w==copy_w && h==copy_h &&
      (copy_source_screen?(base==0 && stride==640 && sw==640 && sh==480):range_ok(base,extent)) &&
      (copy_screen?(copy_base==0 && copy_stride==640 && copy_sw==640 && copy_sh==480):range_ok(copy_base,copy_extent)) &&
      (copy_screen!=copy_source_screen || copy_screen ||
       base+extent<=copy_base || copy_base+copy_extent<=base || stride==copy_stride);
     copy_dst_start<=$signed({1'b0,copy_base})+copy_dst_product+$signed(copy_dx);
     copy_src_start<=$signed({1'b0,base})+copy_src_product+$signed({1'b0,sx});
     state<=COPY_SETUP;
    end
    COPY_SETUP:begin
     logic reverse_now;
     reverse_now=copy_screen==copy_source_screen && copy_dst_start>copy_src_start;
     copy_reverse<=reverse_now;
     // Valid masks fit the arena. Walk rows instead of multiplying on the
     // memory-request path; op6 never consumes this state.
     mask_row<=reverse_now?$clog2(CSTG_WORDS)'(mask_base+mask_extent-32'(mask_stride)):$clog2(CSTG_WORDS)'(mask_base);
     if(!copy_ok || !copy_ext_ok)state<=DONE;
     else if(w==0||h==0)begin result<=0;state<=DONE;end
     else begin x<=reverse_now?w-1'b1:16'd0;y<=reverse_now?h-1'b1:16'd0;state<=COPY_COORD;end
    end
    COPY_COORD:begin
     mask_addr<=mask_row+$clog2(CSTG_WORDS)'(x>>3);
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
      if(cmd==7)state<=copy_mask?COPY_MASK:COPY_SOURCE;
      else if(copy_source_screen)begin fb_req<=1;fb_raddr<=19'(copy_src_addr);state<=COPY_FB_WAIT;end
      else mem(0,copy_src_addr,0,COPY_SAVE);
     end
    end
    COPY_FB_WAIT:if(fb_ack)begin fb_req<=0;byte_q<=fb_rdata;state<=COPY_SAVE;end
    COPY_SAVE:begin pixel_q<=byte_q;state<=copy_mode==0?COPY_WRITE:COPY_DEST;end
    // Mask bytes use request-relative coordinates; destination clipping has
    // already happened. Aliasing the writable destination is rejected above.
    COPY_MASK:begin
     if(cached_valid && cached_addr==32'(mask_addr))begin byte_q<=cached_byte;state<=COPY_MASK_SAVE;end
     else mem(0,32'(mask_addr),0,COPY_MASK_SAVE);
    end
    COPY_MASK_SAVE:begin
     cached_valid<=1;cached_addr<=32'(mask_addr);cached_byte<=byte_q;
     state<=byte_q[7-x[2:0]]?COPY_SOURCE:COPY_NEXT;
    end
    COPY_SOURCE:begin
     if(copy_mode==5)state<=COPY_DEST;
     else if(copy_pattern)begin
      pixel_q<=desc[{3'b101,copy_y[2:0]}][7-copy_x[2:0]]?desc[34]:desc[35];
      state<=copy_mode==0?COPY_WRITE:COPY_DEST;
     end else if(copy_source_screen)begin fb_req<=1;fb_raddr<=19'(copy_src_addr);state<=COPY_FB_WAIT;end
     else mem(0,copy_src_addr,0,COPY_SAVE);
    end
    COPY_DEST:begin
     if(copy_screen)begin fb_req<=1;fb_raddr<=19'(copy_dst_addr);state<=COPY_DEST_FB_WAIT;end
     else mem(0,copy_dst_addr,0,COPY_BLEND);
    end
    COPY_DEST_FB_WAIT:if(fb_ack)begin fb_req<=0;byte_q<=fb_rdata;state<=COPY_BLEND;end
    COPY_BLEND:begin
     // These are palette-index byte operations, not RGB alpha composition.
     case(copy_mode)
      1:pixel_q<=byte_q|pixel_q;
      2:pixel_q<=byte_q^pixel_q;
      3:pixel_q<=byte_q&~pixel_q;
      4:pixel_q<=byte_q&pixel_q;
      5:pixel_q<=~byte_q;
      default:pixel_q<=pixel_q;
     endcase
     state<=COPY_WRITE;
    end
    COPY_WRITE:begin
     if(copy_screen)begin fb_we<=1;fb_x<=10'(copy_x);fb_y<=10'(copy_y);fb_addr<=19'(copy_dst_addr);fb_data<=pixel_q;state<=COPY_NEXT;end
     else mem(1,copy_dst_addr,pixel_q,COPY_NEXT);
    end
    COPY_NEXT:begin
     if(copy_reverse)begin
      if(x==0)begin x<=w-1'b1;if(y==0)begin result<=32'(w)*32'(h);state<=DONE;end
       else begin y<=y-1'b1;mask_row<=mask_row-$clog2(CSTG_WORDS)'(mask_stride);state<=COPY_COORD;end end
      else begin x<=x-1'b1;state<=COPY_COORD;end
     end else begin
      if(x+1==w)begin x<=0;if(y+1==h)begin result<=32'(w)*32'(h);state<=DONE;end
       else begin y<=y+1'b1;mask_row<=mask_row+$clog2(CSTG_WORDS)'(mask_stride);state<=COPY_COORD;end end
      else begin x<=x+1'b1;state<=COPY_COORD;end
     end
    end
    RESOURCE_READ:begin
     // Verified boot image: packed words, read-only, outside the app arena.
     logic [21:0] resource_address;
     resource_address=22'd3565568+22'((src+total-left)>>1);
     if(cached_valid && cached_addr==32'(resource_address))begin
      byte_q<=1'(src+total-left)?resource_high_byte:cached_byte;
      state<=RESOURCE_WRITE;
     end else begin
      sram_req<=1;sram_we<=0;sram_addr<=resource_address;
      sram_wdata<=0;read_high<=1'(src+total-left);after_mem<=RESOURCE_WRITE;state<=WAIT_MEM;
     end
    end
    RESOURCE_WRITE:begin
     mem(1,dst+total-left,byte_q,RESOURCE_READ);left<=left-1'b1;
     if(left==1)begin result<=total;after_mem<=DONE;end
    end
    WAIT_MEM:if(sram_ack)begin
     byte_q<=read_high?sram_rdata[15:8]:sram_rdata[7:0];
     if(cmd==5 && !sram_we && after_mem==RESOURCE_WRITE)begin
      cached_valid<=1;cached_addr<=32'(sram_addr);
      cached_byte<=sram_rdata[7:0];resource_high_byte<=sram_rdata[15:8];
     end
     sram_req<=0;sram_we<=0;state<=GAP;
    end
    GAP:state<=after_mem;
    DONE:if(!req)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
