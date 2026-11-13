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
 output logic [24:0] sram_addr,
 output logic [15:0] sram_wdata,
 input logic sram_ack,input logic [15:0] sram_rdata,
 output logic fb_we,output logic [18:0] fb_addr,output logic [7:0] fb_data,
 // Scissor test of (fb_x,fb_y) against clip_*, registered with fb_we.
 output logic fb_clip_in,
 output logic fb_req,output logic [18:0] fb_raddr,
 input logic fb_ack,input logic [7:0] fb_rdata
);
 import jmr_js_vm_pkg::*;
 typedef enum logic [5:0] {IDLE,DISPATCH,READ_BLOCK,READ_SAVE,WRITE_BLOCK,
 FILL,CHUNK,DESC,VALIDATE,CHECK_GEOMETRY,GEOMETRY,PIXEL,PIXEL_SAVE,COORD,DRAW,
 NEXT_PIXEL,STORE_PIXEL,RESOURCE_READ,RESOURCE_WRITE,COPY_VALIDATE,COPY_CHECK,COPY_SETUP,COPY_RECT,COPY_SPAN,COPY_MUL,COPY_BASE,COPY_LOAD,WAIT_MEM,GAP,DONE,COPY_RUN,PRECHECK,TYPED_READ,TYPED_SAVE,TYPED_WRITE} state_t;
 state_t state,after_mem;
 logic [3:0] cmd;
 logic [31:0] src,dst,left,total,desc_ptr;
 logic last_column,last_row;
 // Shared only by validated arena byte operations 1, 2, 5 and 8-11.
 logic [18:0] arena_src_cursor,arena_dst_cursor;
 logic backwards;
 logic chk_src,chk_dst,chk_back,chk_res,chk_src64,chk_dst64,chk_typed;
 logic [4:0] count,index;
 logic [7:0] buffer[0:15];
 logic [7:0] desc[0:127];
 logic [31:0] copy_base,copy_extent;
 // Descriptor-only bounds computed in the existing validation beat.
 logic [18:0] copy_src_limit,copy_dst_limit,copy_mask_limit;
 logic [15:0] copy_clip_x0,copy_clip_x1,copy_clip_y0,copy_clip_y1;
 logic [15:0] copy_stride,copy_sw,copy_sh,copy_w,copy_h;
 logic signed [15:0] copy_dx,copy_dy;
 logic copy_screen,copy_source_screen,copy_reverse,copy_ok;
 logic copy_ext_ok;
 logic [2:0] copy_mode;
 logic copy_mask,copy_pattern;
 logic [31:0] mask_base,mask_extent;
 logic [15:0] mask_stride;
 logic signed [32:0] copy_src_product,copy_dst_product,copy_src_start,copy_dst_start;
 // Operations 6/7 stream only the visible destination rectangle. Setup
 // beats compute its first pixel and row jumps; per pixel every address is
 // one add of a registered step, never a multiply.
 logic signed [17:0] vis_x0,vis_x1,vis_y0,vis_y1;
 logic [31:0] copy_area;
 logic [15:0] run_x0,run_y0,run_cols,run_rows,copy_x0,copy_y0;
 logic [15:0] mul_a,mul_b;
 logic [18:0] mul_q;
 logic [1:0] mul_beat;
 logic [18:0] p_src,p_dst,p_msk,ps_src,ps_dst,ps_msk;
 logic [16:0] qs_src;
 logic [12:0] qs_msk;
 logic [18:0] j_src,j_dst,j_msk;
 // Walker (G0): logical cursors of the next pixel to stage.
 logic g_valid,g_eol,g_eor,g_mnew,g_eol0;
 logic [18:0] g_src,g_dst,g_msk;
 logic [15:0] g_cols,g_rows;
 logic [2:0] g_xb,g_px,g_py,c_xb0,c_px0;
 logic [9:0] g_fbx,g_fby,c_fbx0;
 // Staged pixel (G1): physical addresses ready for the request registers.
 logic i_valid;
 logic [18:0] i_src,i_dst;
 logic [21:0] i_src_phys,i_dst_phys,i_msk_phys;
 logic [2:0] i_xb;
 logic [7:0] i_pat;
 logic [9:0] i_fbx,i_fby;
 // Fetch sequencer for the staged pixel.
 typedef enum logic [2:0] {Q_MASK,Q_TEST,Q_SRC,Q_LAST,Q_HAND} qstep_t;
 qstep_t q_step,q_after_mask;
 logic q_iss;
 logic need_dst,last_fb;
 logic [7:0] mask_byte,f_s;
 // Retire slot (R): the pixel whose last read is in flight or whose value
 // waits for the arena write slot (W).
 typedef enum logic [1:0] {R_EMPTY,R_WAIT,R_FULL} rstate_t;
 rstate_t r_st;
 logic [18:0] r_dst;
 logic [21:0] r_dst_phys;
 logic [9:0] r_fbx,r_fby;
 logic [7:0] r_s,r_val;
 logic w_valid,w_out;
 logic [21:0] w_phys;
 logic [7:0] w_val;
 // One SRAM transaction and one framebuffer read in flight, each tagged.
 localparam logic [1:0] T_SEQ=2'd0,T_R=2'd1,T_W=2'd2;
 logic s_out,rf_out,rf_fresh,fq_v;
 logic [1:0] s_tag,rf_tag,fq_tag;
 logic [7:0] fbq;
 wire signed [17:0] dx18={{2{copy_dx[15]}},copy_dx};
 wire signed [17:0] dy18={{2{copy_dy[15]}},copy_dy};
 wire signed [17:0] vis_x0_raw=$signed({2'b0,copy_clip_x0})-dx18;
 wire signed [17:0] vis_x1_raw=$signed({2'b0,copy_clip_x1})-dx18;
 wire signed [17:0] vis_y0_raw=$signed({2'b0,copy_clip_y0})-dy18;
 wire signed [17:0] vis_y1_raw=$signed({2'b0,copy_clip_y1})-dy18;
 // Mask bytes between the first and last visible column of a row.
 wire [15:0] span8=(16'(vis_x1-18'sd1)>>3)-(16'(vis_x0)>>3);
 logic [7:0] di;
 logic [18:0] desc_cur;
 logic [21:0] desc_dst_word;
 logic [7:0] byte_q,fill_value,pixel_q;
 // DRAW geometry sums staged in VALIDATE (operands come straight from desc).
 logic geo_stride_ok,geo_x_ok,geo_y_ok;
 logic [31:0] row_addr,extent;
 logic [$clog2(CSTG_WORDS)-1:0] pixel_addr;
 logic packed_mono,packed_nibble;
 logic [15:0] x,y,w,h,stride,sx,sy,sw,sh;
 logic signed [15:0] dx,dy,cx,cy;
 logic [9:0] draw_clip_x0,draw_clip_y0,draw_clip_x1,draw_clip_y1;
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
 // op5 validates its entire <=24320-byte span before starting.
 // Keep the packed-word cache comparison independent of absolute SRAM addressing.
 logic [14:0] resource_cursor;
 logic [14:0] resource_span_limit;
 logic signed [31:0] draw_x,draw_y;
 wire [1:0] zoom_shift=scale==8?2'd3:scale==4?2'd2:scale==2?2'd1:2'd0;
 wire signed [31:0] px=32'($signed(dx))+($signed({16'd0,x})<<<zoom_shift)+$signed({28'd0,zx});
 wire signed [31:0] py=32'($signed(dy))+($signed({16'd0,y})<<<zoom_shift)+$signed({28'd0,zy});
 function automatic logic [15:0] d16(input integer i);return {desc[i+1],desc[i]};endfunction
 task automatic mem(input logic wr,input logic [31:0] p,input logic [7:0] v,input state_t ret);
  read_high<=0;sram_req<=1;sram_we<=wr;sram_addr<=cstg_word(p[20:0]);sram_wdata<={8'd0,v};after_mem<=ret;state<=WAIT_MEM;
 endtask
 function automatic logic [9:0] clip_bound(input logic signed [17:0] v,input logic [9:0] limit);
  if(v<0)return 0;
  if(v>$signed({8'd0,limit}))return limit;
  return v[9:0];
 endfunction
 function automatic logic [15:0] copy_clip_bound(input logic signed [17:0] v,input logic [15:0] limit);
  if(v<0)return 0;
  if(v>$signed({2'b0,limit}))return limit;
  return v[15:0];
 endfunction
 // Stream control for one clock, from registers only. It is evaluated for
 // both values of the SRAM acknowledgement and selected by it last, so the
 // acknowledgement reaches the request and enable registers through one mux.
 typedef struct packed {
  logic s_ack,w_done,r_in,r_ret,issue_w,s_iss,f_iss,f_dst,q_iss_set,mask_in,src_in,q_after,r_wait,r_full,adv;
  logic [1:0] s_sel,tag;
 } run_t;
 wire run_f_ack=rf_out && !rf_fresh && fb_ack;
 function automatic run_t run_decide(input logic ack);
  run_t d;
  logic s_free,f_free,r_free,seq_s_in,seq_f_in;
  d='0;
  d.s_ack=s_out && ack;
  d.w_done=d.s_ack && s_tag==T_W;
  d.r_in=r_st==R_WAIT && (last_fb?(fq_v && fq_tag==T_R):(d.s_ack && s_tag==T_R));
  d.r_ret=(d.r_in || r_st==R_FULL) && (copy_screen || !w_valid || d.w_done);
  r_free=r_st==R_EMPTY || d.r_ret;
  // Port grants. A stop issues nothing new; the bus then drains.
  s_free=req && (!s_out || d.s_ack);
  f_free=req && (!rf_out || run_f_ack);
  d.issue_w=s_free && w_valid && !w_out;
  seq_s_in=q_iss && d.s_ack && s_tag==T_SEQ;
  seq_f_in=q_iss && fq_v && fq_tag==T_SEQ;
  if(i_valid)begin
   case(q_step)
    Q_MASK:begin
     if(!q_iss)begin
      if(s_free && !d.issue_w)begin d.s_iss=1;d.s_sel=2'd1;d.tag=T_SEQ;d.q_iss_set=1;end
     end else if(seq_s_in)d.mask_in=1;
    end
    // Mask bits are request-relative, left pixel in bit 7.
    Q_TEST:if(mask_byte[~i_xb])d.q_after=1;else d.adv=1;
    Q_SRC:begin
     if(!q_iss)begin
      if(copy_source_screen)begin
       if(f_free)begin d.f_iss=1;d.tag=T_SEQ;d.q_iss_set=1;end
      end else if(s_free && !d.issue_w)begin d.s_iss=1;d.s_sel=2'd0;d.tag=T_SEQ;d.q_iss_set=1;end
     end else if(copy_source_screen?seq_f_in:seq_s_in)d.src_in=1;
    end
    Q_LAST:if(r_free)begin
     if(last_fb)begin
      if(f_free)begin d.f_iss=1;d.f_dst=need_dst;d.tag=T_R;d.r_wait=1;d.adv=1;end
     end else if(s_free && !d.issue_w)begin
      d.s_iss=1;d.s_sel=need_dst?2'd2:2'd0;d.tag=T_R;d.r_wait=1;d.adv=1;
     end
    end
    default:if(r_free)begin d.r_full=1;d.adv=1;end // Q_HAND: pattern, nothing to read
   endcase
  end else if(g_valid)d.adv=1; // first pixel
  return d;
 endfunction
 run_t run_ack0,run_ack1,run;
 always_comb begin
  run_ack0=run_decide(1'b0);
  run_ack1=run_decide(1'b1);
  run=sram_ack?run_ack1:run_ack0;
 end
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
    IDLE:if(req)begin resource_span_limit<=15'(32'd24320-a);copy_src_limit<=19'(32'(CSTG_WORDS)-a);copy_dst_limit<=19'(32'(CSTG_WORDS)-b);cmd<=(op<=32'd12) ? op[3:0] : 4'd15;src<=a;dst<=b;left<=c;total<=c;fill_value<=b[7:0];desc_ptr<=a;state<=PRECHECK;end
    // Span checks in their own beat; DISPATCH decodes registered flags only.
    PRECHECK:begin
     chk_src<=src<=CSTG_WORDS && left<=CSTG_WORDS && left<=copy_src_limit;
     chk_dst<=dst<=CSTG_WORDS && left<=CSTG_WORDS && left<=copy_dst_limit;
     chk_back<=dst>src && dst-src<left;
     chk_res<=sys_valid && src<=32'd24320 && left<=32'd24320 && left<=32'(resource_span_limit);
     chk_src64<=src<=CSTG_WORDS && 64<=copy_src_limit;
     chk_dst64<=dst<=CSTG_WORDS && 64<=copy_dst_limit;
     chk_typed<=src<=CSTG_WORDS && (cmd==10?19'd8:cmd==11?19'd2:19'd4)<=copy_src_limit;
     state<=DISPATCH;
    end
    DISPATCH:begin
     cached_valid<=0;
     desc_dst_word<=cstg_word(21'(dst));
     result<=32'hffffffff;
     case(cmd)
      0:begin result<=32'h00010fff;state<=DONE;end // v1 descriptors + operations 1 through 12
      1:if(chk_src && chk_dst)begin
       backwards<=chk_back;
       if(left==0)begin result<=0;state<=DONE;end else state<=CHUNK;
      end else state<=DONE;
      2:if(chk_src)begin
       if(left==0)begin result<=0;state<=DONE;end else begin arena_src_cursor<=src[18:0];state<=FILL;end
      end else state<=DONE;
      3,4:if(chk_src64)begin di<=0;state<=DESC;end else state<=DONE;
      6,7:if(left==0 && chk_src64 && chk_dst64)begin di<=0;state<=DESC;end else state<=DONE;
      5:if(chk_res && chk_dst)begin
       if(left==0)begin result<=0;state<=DONE;end
       else begin resource_cursor<=src[14:0];arena_dst_cursor<=dst[18:0];state<=RESOURCE_READ;end
      end else state<=DONE;
      12:begin
       if(total==0 || (total==1 && src==0 && dst==0))result<=1;
       state<=DONE;
      end
      // Typed staging services: validate the entire span before any transfer.
      8:if(dst==0 && total==0 && chk_typed)begin
       index<=0;result<=0;arena_src_cursor<=src[18:0];state<=TYPED_READ;
      end else state<=DONE;
      9,10,11:if((cmd==10 || total==0) && chk_typed)begin
       index<=0;count<=cmd==10?5'd8:cmd==11?5'd2:5'd4;arena_src_cursor<=src[18:0];state<=TYPED_WRITE;
      end else state<=DONE;
      default:state<=DONE;
     endcase
    end
    TYPED_READ:mem(0,32'(arena_src_cursor),0,TYPED_SAVE);
    TYPED_SAVE:begin
     result<={byte_q,result[31:8]};
     if(index==3)state<=DONE;
     else begin index<=index+1'b1;arena_src_cursor<=arena_src_cursor+19'd1;state<=TYPED_READ;end
    end
    TYPED_WRITE:begin
     mem(1,32'(arena_src_cursor),dst[7:0],TYPED_WRITE);
     arena_src_cursor<=arena_src_cursor+19'd1;
     dst<=index==3?total:{8'd0,dst[31:8]};
     if(index+1==count)begin result<=32'(count);after_mem<=DONE;end
     else index<=index+1'b1;
    end
    CHUNK:begin
     count<=left>16?5'd16:5'(left);index<=0;
     arena_src_cursor<=19'(src+(backwards?left-(left>16?32'd16:left):total-left));
     arena_dst_cursor<=19'(dst+(backwards?left-(left>16?32'd16:left):total-left));
     state<=READ_BLOCK;
    end
    READ_BLOCK:mem(0,32'(19'(arena_src_cursor+19'(index))),0,READ_SAVE);
    READ_SAVE:begin
     buffer[index[3:0]]<=byte_q;
     if(index+1==count)begin index<=0;state<=WRITE_BLOCK;end
     else begin index<=index+1'b1;state<=READ_BLOCK;end
    end
    WRITE_BLOCK:begin
     mem(1,32'(19'(arena_dst_cursor+19'(index))),buffer[index[3:0]],WRITE_BLOCK);
     if(index+1==count)begin
      left<=left-32'(count);index<=0;
      if(left==32'(count))begin result<=total;after_mem<=DONE;end
      else after_mem<=CHUNK;
     end else index<=index+1'b1;
    end
    FILL:begin
     mem(1,32'(arena_src_cursor),fill_value,FILL);left<=left-1'b1;
     arena_src_cursor<=arena_src_cursor+19'd1;
     if(left==1)begin result<=total;after_mem<=DONE;end
    end
    // Two clocks per byte: the request stays up through each acknowledgement
    // with the next word address, stepped from the current one.
    DESC:begin
     if(!sram_req)begin
      sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(desc_ptr));desc_cur<=19'(desc_ptr);
     end else if(sram_ack)begin
      desc[di[6:0]]<=sram_rdata[7:0];
      if((cmd==6||cmd==7) ? di==127 : di==63)begin
       sram_req<=0;state<=(cmd==6||cmd==7)?COPY_VALIDATE:VALIDATE;
      end else if(!req)sram_req<=0; // stopped: let the bus drain
      else begin
       di<=di+1'b1;
       if(di==63)begin sram_addr<=desc_dst_word;desc_cur<=19'(dst);end
       else begin
        sram_addr<=desc_cur==19'(CSCR_WORDS-1)?CIMG_SRAM_BASE:sram_addr+1'b1;
        desc_cur<=desc_cur+1'b1;
       end
      end
     end
    end
    VALIDATE:begin
     base<={desc[7],desc[6],desc[5],desc[4]};stride<=d16(8);sw<=d16(10);sh<=d16(12);
     sx<=d16(14);sy<=d16(16);w<=d16(18);h<=d16(20);dx<=d16(22);dy<=d16(24);
     cx<=d16(26);cy<=d16(28);
     // Intersect invariant descriptor bounds with the physical screen once.
     // A valid destination must have zero bits above bit9; the pixel beat
     // then needs only unsigned10 comparisons, not signed32 carry chains.
     draw_clip_x0<=clip_bound($signed({{2{desc[27][7]}},d16(26)}),640);
     draw_clip_y0<=clip_bound($signed({{2{desc[29][7]}},d16(28)}),480);
     draw_clip_x1<=clip_bound($signed({{2{desc[27][7]}},d16(26)})+$signed({2'b0,d16(30)}),640);
     draw_clip_y1<=clip_bound($signed({{2{desc[29][7]}},d16(28)})+$signed({2'b0,d16(32)}),480);
     packed_mono<=desc[1]==1;packed_nibble<=desc[1]==4;
     // Pre-stage base + first packed column; invalid descriptors never use it.
     pixel_addr<=$clog2(CSTG_WORDS)'({desc[7],desc[6],desc[5],desc[4]}+
      (desc[1]==1?(32'(d16(14))>>3):desc[1]==4?(32'(d16(14))>>1):32'(d16(14))));
     fmt<=desc[1];flags<=desc[2];scale<=desc[3];fg<=desc[34];bg<=desc[35];
     extent<=32'(d16(8))*32'(d16(12));
     arena_limit<=CSTG_WORDS-{desc[7],desc[6],desc[5],desc[4]};state<=CHECK_GEOMETRY;
     // Same tests CHECK_GEOMETRY made on the registered copies of these fields.
     geo_stride_ok<=32'(d16(8))>=(desc[1]==1?((32'(d16(10))+7)>>3):desc[1]==4?((32'(d16(10))+1)>>1):32'(d16(10)));
     geo_x_ok<=32'(d16(14))+32'(d16(18))<=32'(d16(10));
     geo_y_ok<=32'(d16(16))+32'(d16(20))<=32'(d16(12));
    end
    CHECK_GEOMETRY:begin
     // Keep the row product in a different beat from extent's product.
     row_addr<=32'(sy)*32'(stride);
     // Register validation separately from the geometry/DSP path and FSM.
     geometry_ok<=desc[0]==1 && (fmt==1||fmt==4||fmt==8) &&
       (scale==1||scale==2||scale==4||scale==8) && sw!=0 && sh!=0 &&
       base<=CSTG_WORDS && extent<=arena_limit &&
       geo_stride_ok && geo_x_ok && geo_y_ok;
     state<=GEOMETRY;
    end
    GEOMETRY:begin
     // Validate the whole surface BEFORE any write; no truncated overflow.
     if(!geometry_ok)state<=DONE;
     else if(w==0||h==0)begin result<=0;state<=DONE;end
     else begin
      x<=0;y<=0;
      // row_addr becomes the first source BYTE of this source row.
      row_addr<=row_addr+32'(pixel_addr);
      pixel_addr<=$clog2(CSTG_WORDS)'(row_addr+32'(pixel_addr));
      state<=PIXEL;
     end
    end
    PIXEL:begin
     last_column<=x+1==w;last_row<=y+1==h;
     // Setup/NEXT_PIXEL prepare the address; no format mux plus row
     // addition feeds this cache comparison and SRAM request enable.
     sram_we<=0;
     bitpos<=3'(sx+x);
     if(cached_valid && pixel_addr==cached_addr)begin byte_q<=cached_byte;state<=PIXEL_SAVE;end
     else mem(0,32'(pixel_addr),0,PIXEL_SAVE);
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
     if(draw_x[31:10]==0&&draw_y[31:10]==0&&
       draw_x[9:0]>=draw_clip_x0&&draw_y[9:0]>=draw_clip_y0&&
       draw_x[9:0]<draw_clip_x1&&draw_y[9:0]<draw_clip_y1)begin
      fb_we<=1;fb_x<=10'(draw_x);fb_y<=10'(draw_y);fb_addr<=19'(draw_y*640+draw_x);fb_data<=pixel_q;
      fb_clip_in<=10'(draw_x)>=clip_x0 && 10'(draw_x)<clip_x1 && 10'(draw_y)>=clip_y0 && 10'(draw_y)<clip_y1;
     end
     if(zx+1==scale)begin zx<=0;if(zy+1==scale)state<=NEXT_PIXEL;else zy<=zy+1'b1;end
     else zx<=zx+1'b1;
    end
    NEXT_PIXEL:if(last_column)begin
     x<=0;if(last_row)begin result<=32'(w)*32'(h);state<=DONE;end
     else begin y<=y+1'b1;row_addr<=row_addr+32'(stride);pixel_addr<=$clog2(CSTG_WORDS)'(row_addr+32'(stride));state<=PIXEL;end
    end else begin
     x<=x+1'b1;
     // Advance the source byte only at the packed-byte boundary.
     if(packed_mono ? bitpos==7 : packed_nibble ? bitpos[0] : 1'b1)
      pixel_addr<=pixel_addr+1'b1;
     state<=PIXEL;
    end
    // Raw 8-bit rectangle transport. Policy and richer raster modes live in
    // JavaScript. Capture BOTH descriptors before touching either surface.
    COPY_VALIDATE:begin
     copy_src_limit<=19'(32'(CSTG_WORDS)-{desc[7],desc[6],desc[5],desc[4]});
     copy_dst_limit<=19'(32'(CSTG_WORDS)-{desc[71],desc[70],desc[69],desc[68]});
     copy_mask_limit<=19'(32'(CSTG_WORDS)-{desc[51],desc[50],desc[49],desc[48]});
     copy_clip_x0<=copy_clip_bound(18'($signed(d16(90))),d16(74));
     copy_clip_y0<=copy_clip_bound(18'($signed(d16(92))),d16(76));
     copy_clip_x1<=copy_clip_bound(18'($signed(d16(90)))+$signed({2'b0,d16(94)}),d16(74));
     copy_clip_y1<=copy_clip_bound(18'($signed(d16(92)))+$signed({2'b0,d16(96)}),d16(76));
     base<={desc[7],desc[6],desc[5],desc[4]};stride<=d16(8);sw<=d16(10);sh<=d16(12);
     sx<=d16(14);sy<=d16(16);w<=d16(18);h<=d16(20);
     copy_base<={desc[71],desc[70],desc[69],desc[68]};
     copy_stride<=d16(72);copy_sw<=d16(74);copy_sh<=d16(76);
     copy_w<=d16(82);copy_h<=d16(84);copy_dx<=d16(86);copy_dy<=d16(88);
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
      (!copy_mask || (32'(mask_stride)>=((32'(w)+7)>>3) && (mask_base<=CSTG_WORDS && mask_extent<=CSTG_WORDS && mask_extent<=copy_mask_limit) &&
       (copy_screen || mask_base+mask_extent<=copy_base || copy_base+copy_extent<=mask_base))));
     // Reject incompatible alias layouts rather than corrupting unread rows.
     copy_ok<=desc[0]==1 && desc[64]==1 && desc[1]==8 && desc[65]==8 &&
      (desc[2]==0||desc[2]==2) && (desc[66]==0||desc[66]==2) && desc[3]==1 && desc[67]==1 &&
      sw!=0 && sh!=0 && copy_sw!=0 && copy_sh!=0 && stride>=sw && copy_stride>=copy_sw &&
      32'(sx)+32'(w)<=32'(sw) && 32'(sy)+32'(h)<=32'(sh) && w==copy_w && h==copy_h &&
      (copy_source_screen?(base==0 && stride==640 && sw==640 && sh==480):(base<=CSTG_WORDS && extent<=CSTG_WORDS && extent<=copy_src_limit)) &&
      (copy_screen?(copy_base==0 && copy_stride==640 && copy_sw==640 && copy_sh==480):(copy_base<=CSTG_WORDS && copy_extent<=CSTG_WORDS && copy_extent<=copy_dst_limit)) &&
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
     // Visible request columns/rows: clip and surface bounds hold for the
     // whole span, so the walk never tests a pixel against them.
     vis_x0<=vis_x0_raw<0?18'sd0:vis_x0_raw;
     vis_x1<=vis_x1_raw>$signed({2'b0,w})?$signed({2'b0,w}):vis_x1_raw;
     vis_y0<=vis_y0_raw<0?18'sd0:vis_y0_raw;
     vis_y1<=vis_y1_raw>$signed({2'b0,h})?$signed({2'b0,h}):vis_y1_raw;
     copy_area<=32'(w)*32'(h);
     if(!copy_ok || !copy_ext_ok)state<=DONE;
     else if(w==0||h==0)begin result<=0;state<=DONE;end
     else state<=COPY_RECT;
    end
    COPY_RECT:begin
     // First pixel of the walk; reverse order starts at the last one.
     run_x0<=copy_reverse?16'(vis_x1-18'sd1):16'(vis_x0);
     run_y0<=copy_reverse?16'(vis_y1-18'sd1):16'(vis_y0);
     run_cols<=16'(vis_x1-vis_x0-18'sd1);
     run_rows<=16'(vis_y1-vis_y0-18'sd1);
     if(vis_x1<=vis_x0 || vis_y1<=vis_y0)begin result<=copy_area;state<=DONE;end
     else state<=COPY_SPAN;
    end
    COPY_SPAN:begin
     // Row jumps from the last pixel of a row to the first of the next.
     j_src<=copy_reverse?19'(run_cols)-19'(stride):19'(stride)-19'(run_cols);
     j_dst<=copy_reverse?19'(run_cols)-19'(copy_stride):19'(copy_stride)-19'(run_cols);
     j_msk<=copy_reverse?19'(span8)-19'(mask_stride):19'(mask_stride)-19'(span8);
     copy_x0<=16'(copy_dx)+run_x0;
     copy_y0<=16'(copy_dy)+run_y0;
     mul_a<=sy+run_y0;mul_b<=stride;mul_beat<=0;
     state<=COPY_MUL;
    end
    COPY_MUL:begin
     // One registered multiplier, three beats: source, destination and
     // mask offsets of the first visible row.
     mul_q<=19'(32'(mul_a)*32'(mul_b));
     mul_beat<=mul_beat+1'b1;
     case(mul_beat)
      0:begin mul_a<=copy_y0;mul_b<=copy_stride;end
      1:begin p_src<=mul_q;mul_a<=run_y0;mul_b<=mask_stride;end
      2:p_dst<=mul_q;
      default:begin p_msk<=mul_q;state<=COPY_BASE;end
     endcase
    end
    COPY_BASE:begin
     ps_src<=19'(base)+p_src;ps_dst<=19'(copy_base)+p_dst;ps_msk<=19'(mask_base)+p_msk;
     qs_src<=17'(sx)+17'(run_x0);qs_msk<=13'(run_x0>>3);
     state<=COPY_LOAD;
    end
    COPY_LOAD:begin
     g_src<=ps_src+19'(qs_src);g_dst<=ps_dst+19'(copy_x0);g_msk<=ps_msk+19'(qs_msk);
     g_cols<=run_cols;g_rows<=run_rows;g_eol<=run_cols==0;g_eol0<=run_cols==0;g_eor<=run_rows==0;
     g_xb<=run_x0[2:0];g_px<=copy_x0[2:0];g_py<=copy_y0[2:0];
     g_fbx<=copy_x0[9:0];g_fby<=copy_y0[9:0];
     c_xb0<=run_x0[2:0];c_px0<=copy_x0[2:0];c_fbx0<=copy_x0[9:0];
     g_mnew<=1;g_valid<=1;i_valid<=0;
     need_dst<=copy_mode!=0;
     last_fb<=copy_mode!=0?copy_screen:copy_source_screen;
     q_after_mask<=(!copy_pattern && copy_mode!=5 && copy_mode!=0)?Q_SRC:
      (!copy_pattern || copy_mode!=0)?Q_LAST:Q_HAND;
     q_iss<=0;r_st<=R_EMPTY;w_valid<=0;w_out<=0;s_out<=0;rf_out<=0;rf_fresh<=0;fq_v<=0;
     state<=COPY_RUN;
    end
    COPY_RUN:begin
     // Overlapped pixel stream. The sequencer stages reads for pixel n+1
     // while R retires pixel n; W writes an arena destination. Reading ahead
     // is safe: the walk direction chosen above never reads a source byte
     // that an earlier pixel still has to write, the mask never aliases an
     // arena destination, and distinct pixels have distinct destinations.
     logic [7:0] r_data,r_v;
     rf_fresh<=0;
     // Capture framebuffer bytes in a plain register; consume next clock.
     fq_v<=run_f_ack;
     if(run_f_ack)begin fbq<=fb_rdata;fq_tag<=rf_tag;rf_out<=0;fb_req<=0;end
     if(run.s_ack)begin s_out<=0;sram_req<=0;sram_we<=0;end
     if(run.w_done)begin w_valid<=0;w_out<=0;end
     r_data=last_fb?fbq:sram_rdata[7:0];
     // Palette-index byte operations, not RGB composition.
     case(copy_mode)
      1:r_v=r_data|r_s;
      2:r_v=r_data^r_s;
      3:r_v=r_data&~r_s;
      4:r_v=r_data&r_s;
      5:r_v=~r_data;
      default:r_v=r_data;
     endcase
     if(r_st==R_FULL)r_v=r_val;
     if(run.r_ret)begin
      if(copy_screen)begin fb_we<=1;fb_addr<=r_dst;fb_x<=r_fbx;fb_y<=r_fby;fb_data<=r_v;
       fb_clip_in<=r_fbx>=clip_x0 && r_fbx<clip_x1 && r_fby>=clip_y0 && r_fby<clip_y1;end
      else begin w_valid<=1;w_phys<=r_dst_phys;w_val<=r_v;end
      r_st<=R_EMPTY;
     end else if(run.r_in)begin r_st<=R_FULL;r_val<=r_v;end
     if(run.issue_w)begin
      sram_req<=1;sram_we<=1;sram_addr<=w_phys;sram_wdata<={8'd0,w_val};
      s_out<=1;s_tag<=T_W;w_out<=1;
     end
     if(run.s_iss)begin
      sram_req<=1;sram_we<=0;s_out<=1;s_tag<=run.tag;
      case(run.s_sel)
       2'd1:sram_addr<=i_msk_phys;
       2'd2:sram_addr<=i_dst_phys;
       default:sram_addr<=i_src_phys;
      endcase
     end
     if(run.f_iss)begin
      fb_req<=1;fb_raddr<=run.f_dst?i_dst:i_src;rf_out<=1;rf_fresh<=1;rf_tag<=run.tag;
     end
     if(run.q_iss_set)q_iss<=1;
     if(run.mask_in)begin mask_byte<=sram_rdata[7:0];q_iss<=0;q_step<=Q_TEST;end
     if(run.src_in)begin f_s<=copy_source_screen?fbq:sram_rdata[7:0];q_iss<=0;q_step<=Q_LAST;end
     if(run.q_after)q_step<=q_after_mask;
     if(run.r_wait || run.r_full)begin
      r_st<=run.r_wait?R_WAIT:R_FULL;r_s<=copy_pattern?i_pat:f_s;r_val<=i_pat;
      r_dst<=i_dst;r_dst_phys<=i_dst_phys;r_fbx<=i_fbx;r_fby<=i_fby;
     end
     // Stage the next pixel and step the walker by one registered add.
     if(run.adv)begin
      i_valid<=g_valid;
      i_src<=g_src;i_dst<=g_dst;
      i_src_phys<=cstg_word(21'(g_src));i_dst_phys<=cstg_word(21'(g_dst));i_msk_phys<=cstg_word(21'(g_msk));
      i_xb<=g_xb;i_fbx<=g_fbx;i_fby<=g_fby;
      i_pat<=desc[{3'b101,g_py}][~g_px]?desc[34]:desc[35];
      q_step<=copy_mask?(g_mnew?Q_MASK:Q_TEST):q_after_mask;q_iss<=0;
      g_src<=g_src+(g_eol?j_src:copy_reverse?19'h7ffff:19'd1);
      g_dst<=g_dst+(g_eol?j_dst:copy_reverse?19'h7ffff:19'd1);
      if(g_eol)g_msk<=g_msk+j_msk;
      else if(copy_reverse?g_xb==0:g_xb==7)g_msk<=g_msk+(copy_reverse?19'h7ffff:19'd1);
      if(g_eol)begin
       if(g_eor)g_valid<=0;
       g_rows<=g_rows-1'b1;g_eor<=g_rows==1;
       g_cols<=run_cols;g_eol<=g_eol0;
       g_xb<=c_xb0;g_px<=c_px0;g_fbx<=c_fbx0;
       g_py<=copy_reverse?g_py-1'b1:g_py+1'b1;
       g_fby<=copy_reverse?g_fby-1'b1:g_fby+1'b1;
       g_mnew<=1;
      end else begin
       g_cols<=g_cols-1'b1;g_eol<=g_cols==1;
       g_xb<=copy_reverse?g_xb-1'b1:g_xb+1'b1;
       g_px<=copy_reverse?g_px-1'b1:g_px+1'b1;
       g_fbx<=copy_reverse?g_fbx-1'b1:g_fbx+1'b1;
       g_mnew<=copy_reverse?g_xb==0:g_xb==7;
      end
     end
     if(!i_valid && !g_valid && r_st==R_EMPTY && !w_valid && !s_out && !rf_out && !fq_v)begin
      result<=copy_area;state<=DONE;
     end
    end
    RESOURCE_READ:begin
     // Verified boot image: packed words, read-only, outside the app arena.
     logic [21:0] resource_address;
     resource_address=22'd3565568+22'(resource_cursor[14:1]);
     if(cached_valid && cached_addr[13:0]==resource_cursor[14:1])begin
      byte_q<=resource_cursor[0]?resource_high_byte:cached_byte;
      state<=RESOURCE_WRITE;
     end else begin
      sram_req<=1;sram_we<=0;sram_addr<=resource_address;
      sram_wdata<=0;read_high<=resource_cursor[0];after_mem<=RESOURCE_WRITE;state<=WAIT_MEM;
     end
    end
    RESOURCE_WRITE:begin
     mem(1,32'(arena_dst_cursor),byte_q,RESOURCE_READ);left<=left-1'b1;
     arena_dst_cursor<=arena_dst_cursor+19'd1;
     resource_cursor<=resource_cursor+15'd1;
     if(left==1)begin result<=total;after_mem<=DONE;end
    end
    WAIT_MEM:if(sram_ack)begin
     byte_q<=read_high?sram_rdata[15:8]:sram_rdata[7:0];
     if(cmd==5 && !sram_we && after_mem==RESOURCE_WRITE)begin
      cached_valid<=1;cached_addr<={18'd0,resource_cursor[14:1]};
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
