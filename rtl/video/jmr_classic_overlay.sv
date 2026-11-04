// Two-pixel-clock native UI renderer. A registered label read followed by a
// registered font read; variable text never becomes a combinational RAM peek.
(* use_dsp="no" *) module jmr_classic_overlay (
 input logic pixel_clk,rst_n,clk,sys_we,
 input logic [13:0] sys_addr,
 input logic [15:0] sys_data,
 input logic [911:0] sys_config,
 input logic [9:0] x,y,
 input logic [31:0] window_state,
 input logic [3:0] active_menu,popup_count,
 input logic [9:0] popup_left,
 output logic [3:0] popup_row,
 input logic [111:0] popup_static_rows,
 input logic [97:0] popup_dynamic_rows,
 input logic [13:0] popup_enabled_rows,popup_checked_rows,
 input logic [9:0] active_left,active_right,
 input logic [3:0] hover_row,
 input logic about_open,about_valid,title_valid,custom_title,window_bars,
 input logic [9:0] title_width,
 input logic [2:0] dialog,
 input logic [8:0] file_count,selected,
 input logic [7:0] file_top,message_id,
 input logic [3:0] name_len,
 input logic name_selected,caret_on,flash_default,about_hot,
 input logic [9:0] caret_px,
 input logic [1:0] hot_button,
 output logic [6:0] label_raddr,
 output logic signed [11:0] label_pos,
 input logic [11:0] label_glyph,
 output logic opaque,modal_opaque,
 output logic [23:0] rgb
);
 wire [7:0] popup_static=popup_row<14?popup_static_rows[popup_row*8+:8]:8'd0;
 wire [6:0] popup_dynamic=popup_row<14?popup_dynamic_rows[popup_row*7+:7]:7'd127;
 wire popup_enabled=popup_row<14 && popup_enabled_rows[popup_row];
 import jmr_system_menu_pkg::*;
 import jmr_classic_ui_pkg::*;
 (* ram_style="block" *) logic [15:0] font [0:2047];
 initial $readmemh("desktop_font.hex",font);
 (* ram_style="distributed" *) logic [9:0] widths [0:255];
 initial for(integer i=0;i<256;i=i+1)widths[i]=classic_width(i);
 always_ff @(posedge clk)begin
  if(sys_we && sys_addr<2048)font[sys_addr[10:0]]<=sys_data;
  if(sys_we && sys_addr>=4096 && sys_addr<4608 && sys_addr[0])widths[8'((sys_addr-4096)>>1)]<=sys_data[11:2];
 end
 logic signed [11:0] dx,dy;
 always_comb begin
  dx=0;dy=0;
  if(dialog>=1 && dialog<=5)begin dx=12'(sys_config[(dialog-1)*32+:16]);dy=12'(sys_config[(dialog-1)*32+16+:16]);end
 end
 wire signed [11:0] dialog_x=12'({2'b0,x})-dx,dialog_y=12'({2'b0,y})-dy;
 function automatic logic round_inside(input integer px,py,w,h,input logic rounded);
  integer corner_row,cut;begin corner_row=py<h-1-py?py:h-1-py;cut=0;
   if(rounded)case(corner_row)0:cut=5;1:cut=3;2:cut=2;3,4:cut=1;default:;endcase
   round_inside=py>=0 && py<h && px>=cut && px<w-cut;
  end
 endfunction
 logic op,modal,dynamic;
 logic [23:0] bg,fg;
 logic [11:0] static_glyph,cached_static_glyph;
 logic direct_static,q_direct_static,check_prefix;
 logic [7:0] static_id;
 logic signed [11:0] pos;
 logic [3:0] font_row;
 logic q_op,q_modal,q_dynamic;
 logic [23:0] q_bg,q_fg;
 logic [11:0] q_static_glyph;

 logic [3:0] q_font_row;
 logic [11:0] glyph;
 logic r_op,r_modal;
 logic [23:0] r_bg,r_fg;
 logic [3:0] r_col;
 logic [15:0] font_data;
 wire [9:0] stripe_y=y-10'd40;
 wire [1:0] stripe_phase=2'(stripe_y%10'd3);
 wire [9:0] popup_y=y-10'd27;
 wire [4:0] popup_line=5'(popup_y%10'd21);
 assign popup_row=y>=26?4'((y-10'd26)/10'd21):15;
 always_comb begin
  integer role,sy,sx,flags,thumb,tx,title_id,title_x,title_w,hint_id,lx,ly,bx,by,bw,bid,bi,row_index;
  role=window_state[7:0];sy=window_state[15:8];sx=window_state[23:16];flags=window_state[31:24];
  check_prefix=0;op=0;modal=0;bg=0;fg=0;static_id=0;static_glyph=0;dynamic=0;label_raddr=127;pos=0;font_row=0;
  thumb=109+(sy*280/256);tx=29+(sx*520/256);title_id=role>=1 && role<=7?80+role:86;title_w=0;title_x=240;hint_id=96;lx=0;ly=0;bx=0;by=0;bw=0;bid=0;bi=0;row_index=0;
  if(role!=0)begin
   if(role!=8 && role!=9)begin
    op=1;bg=24'h55ddff;
    if(x>=8 && x<620 && y>=34 && y<454)bg=0;
    if(x>=9 && x<619 && y>=35 && y<453)bg=24'hffffff;
    if(((x>=32 && x<238)||(x>=402 && x<613)) && y>=40 && y<56 && stripe_phase==2'd0)bg=0;
    if(x>=10 && x<618 && y==60)bg=0;
    if(x>=16 && x<30 && y>=40 && y<54)bg=(x==16||x==29||y==40||y==53)?24'h000000:24'hffffff;
    if(x>=24 && x<600 && y>=88 && y<432)op=0;
    if(x==600 && y>=88 && y<432)bg=0;
    if(window_bars && x>=601 && x<618 && y>=108 && y<414)bg=24'hdddddd;
    if(window_bars && x>=601 && x<618 && (y==107 || y==414))bg=0;
    if(window_bars && x>=601 && x<618 && y>=thumb && y<thumb+18)bg=(x==601 || x==617 || y==thumb || y==thumb+17)?24'h000000:24'hffffff;
    if(x>=10 && x<618 && y==433)bg=0;
    if(role==1 || role==5)begin
     if(x>=28 && x<582 && y>=434 && y<453)bg=24'hdddddd;
     if((x==27 || x==582) && y>=434 && y<453)bg=0;
     if(x>=tx && x<tx+32 && y>=434 && y<453)bg=(x==tx || x==tx+31 || y==434 || y==452)?24'h000000:24'hffffff;
    end
    // Static system captions use the same Chicago ROM as the desktop.
    title_w=widths[8'(title_id)];
    title_x=(640-title_w)/2;if(title_x<240)title_x=240;
    if(y>=38 && y<54)begin static_id=8'(title_id);pos=12'(integer'(x)-title_x);font_row=4'(y-38);end
    if(title_valid && (custom_title || role==1 || role==2 || role==5) && y>=38 && y<54)begin
     title_x=(640-integer'(title_width))/2;if(title_x<240)title_x=240;
     static_id=0;dynamic=1;label_raddr=1;pos=12'(integer'(x)-title_x);font_row=4'(y-38);
    end
    case(role)
     1,5:hint_id=89;2:hint_id=91;3:case((flags>>4)&7)1:hint_id=103;2:hint_id=93;3:hint_id=104;4:hint_id=94;default:hint_id=92;endcase
     4:hint_id=95;7:hint_id=97;default:hint_id=96;
    endcase
    if(!custom_title && y>=66 && y<82)begin dynamic=0;static_id=8'(hint_id);pos=12'(integer'(x)-24);font_row=4'(y-66);end
    if((role==1 || role==5) && flags[0] && y>=66 && y<82 && x>=480)begin static_id=90;pos=12'(x-480);font_row=4'(y-66);end
    if(window_bars && y>=90 && y<106 && x>=604)begin static_id=98;pos=12'(x-604);font_row=4'(y-90);end
    if(window_bars && y>=415 && y<431 && x>=604)begin static_id=99;pos=12'(x-604);font_row=4'(y-415);end
    if(y>=435 && y<451)begin
     if(role==1 || role==5)begin
      if(x>=13 && x<28)begin static_id=100;pos=12'(x-13);font_row=4'(y-435);end
      else if(x>=586 && x<600)begin static_id=101;pos=12'(x-586);font_row=4'(y-435);end
     end else if(!custom_title)begin static_id=102;pos=12'(integer'(x)-24);font_row=4'(y-435);end
    end
   end
   if(y<22)begin
    op=1;bg=y==21?24'h000000:24'hffffff;static_id=0;
    if(active_menu!=0 && x>=active_left && x<active_right && y<21)begin bg=0;fg=24'hffffff;end
    if(y>=3 && y<19)begin dynamic=1;label_raddr=0;pos=12'(x);font_row=4'(y-3);end
   end
   if(active_menu!=0 && ((x>=popup_left+2 && x<popup_left+214 && y>=24 && y<24+popup_count*21+8) || (x>=popup_left && x<popup_left+212 && y>=22 && y<22+popup_count*21+8)))begin
    static_id=0;dynamic=0;label_raddr=127;op=1;bg=0;fg=0;
    if(x<popup_left+212 && y<22+popup_count*21+8)begin
     bg=(x==popup_left || x==popup_left+211 || y==22 || y==22+popup_count*21+7)?24'h000000:24'hffffff;
     if(popup_row==hover_row && popup_row<popup_count && popup_enabled && x>popup_left && x<popup_left+211 && y>=26)bg=0;
     if(y>=27 && popup_line<5'd16 && popup_row<popup_count)begin
      pos=12'(integer'(x)-integer'(popup_left)-10);font_row=popup_line[3:0];fg=popup_enabled?(popup_row==hover_row?24'hffffff:24'h000000):24'h919191;
      if(popup_checked_rows[popup_row])begin
       if(x>=popup_left+8 && x<popup_left+20)check_prefix=1;pos=pos-12'd10;
      end
      if(popup_static==255)begin
       dynamic=0;static_id=0;
       if(popup_line==9 && x>=popup_left+8 && x<popup_left+198)bg=24'h919191;
      end else if(popup_dynamic!=127)begin dynamic=1;label_raddr=popup_dynamic;end
      else static_id=popup_static;
     end
    end
   end
  end
  if(role==10)begin : boot_picture
   logic [103:0] ship;
   logic [6:0] sx;logic [4:0] sy;
   ship=0;sx=0;sy=0;
   op=1;modal=0;bg=(x[1]^y[1])?24'h49dbff:24'h6ddbff;fg=0;dynamic=0;static_id=0;label_raddr=127;
   if(flags[0])begin
    if(x>=46 && x<606 && y>=146 && y<314)bg=0;
    if(x>=40 && x<600 && y>=140 && y<308)bg=0;
    if(x>=41 && x<599 && y>=141 && y<307)bg=24'hffffff;
    sx=7'(x-57);sy=5'(y-189);ship=javatosh_ship(sy);
    if(x>=57 && x<161 && y>=189 && y<216 && ship[103-sx])bg=0;
    if(y>=224 && y<239)begin static_id=170;pos=x<77?-12'sd1:12'(x-77);font_row=4'(y-224);end
    if(y>=243 && y<258)begin static_id=160;pos=x<56?-12'sd1:12'(x-56);font_row=4'(y-243);end
    if(y>=216 && y<231 && x>=192)begin static_id=171;pos=12'(integer'(x)-247);font_row=4'(y-216);end
   end else begin
    // Two fixed sizes: constant shifts, never a hardware divider/scaler.
    sx=7'((x-216)>>1);sy=5'((y-171)>>1);ship=javatosh_ship(sy);
    if(x>=216 && x<424 && y>=171 && y<225 && ship[103-sx])bg=0;
    if(y>=241 && y<271)begin static_id=170;pos=x<256?-12'sd1:12'((x-256)>>1);font_row=4'((y-241)>>1);end
    if(y>=279 && y<309)begin static_id=160;pos=x<214?-12'sd1:12'((x-214)>>1);font_row=4'((y-279)>>1);end
   end
  end
  if(dialog==2 && dialog_x>=136 && dialog_x<512 && dialog_y>=116 && dialog_y<280)begin op=1;modal=1;bg=0;dynamic=0;static_id=0;end
  if(dialog!=0)begin
   if(dialog==1 && dialog_x>=110 && dialog_x<530 && dialog_y>=76 && dialog_y<276)begin
    op=1;modal=1;bg=(dialog_x<112 || dialog_x>=528 || dialog_y<78 || dialog_y>=274)?24'h000000:24'hffffff;
    fg=0;static_id=0;dynamic=0;label_raddr=127;
    if(dialog_y>=84 && dialog_y<100)begin static_id=143;pos=12'(integer'(dialog_x)-280);font_row=4'(dialog_y-84);end
    if(dialog_x>=132 && dialog_x<510 && dialog_y>=110 && dialog_y<226)begin
     bg=(dialog_x<134 || dialog_x>=508 || dialog_y<112 || dialog_y>=224)?24'h000000:24'hffffff;
     static_id=0;dynamic=0;
     if(dialog_y>=112 && dialog_y<224 && dialog_x>=134 && dialog_x<508)begin
      row_index=(dialog_y-112)/16;
      if(dialog_x<484 && integer'(selected)==integer'(file_top)+row_index)bg=24'h1771ff;
      if(integer'(file_top)+row_index<integer'(file_count))begin
       dynamic=1;label_raddr=6'(6+row_index);pos=12'(integer'(dialog_x)-142);font_row=4'((dialog_y-112)%16);
       fg=(integer'(selected)==integer'(file_top)+row_index)?24'hffffff:24'h000000;
      end
      if(file_count==0 && dialog_y>=144 && dialog_y<160)begin static_id=150;dynamic=0;pos=12'(integer'(dialog_x)-142);font_row=4'(dialog_y-144);fg=24'h646464;end
      if(dialog_x>=490 && dialog_y>=116 && dialog_y<132)begin static_id=98;dynamic=0;pos=12'(dialog_x-490);font_row=4'(dialog_y-116);fg=0;end
      if(dialog_x>=490 && dialog_y>=204 && dialog_y<220)begin static_id=99;dynamic=0;pos=12'(dialog_x-490);font_row=4'(dialog_y-204);fg=0;end
     end
    end
   end else if(dialog!=1 && dialog_x>=132 && dialog_x<508 && dialog_y>=112 && dialog_y<276)begin
    op=1;modal=1;bg=(dialog_x<134 || dialog_x>=506 || dialog_y<114 || dialog_y>=274)?24'h000000:24'hffffff;
    fg=0;static_id=0;dynamic=0;label_raddr=127;
    if(dialog==2)begin
     // Same double frame and shadow as Python's Save As box.
     if(dialog_x>=133 && dialog_x<507 && dialog_y>=113 && dialog_y<275)bg=24'hffffff;
     if(dialog_x>=135 && dialog_x<505 && dialog_y>=115 && dialog_y<273)bg=0;
     if(dialog_x>=136 && dialog_x<504 && dialog_y>=116 && dialog_y<272)bg=24'hffffff;
     if(dialog_y>=124 && dialog_y<140)begin static_id=147;pos=12'(integer'(dialog_x)-152);font_row=4'(dialog_y-124);end
     if(dialog_x>=152 && dialog_x<366 && dialog_y>=148 && dialog_y<174)begin
      bg=(dialog_x<154 || dialog_x>=364 || dialog_y<150 || dialog_y>=172)?24'h000000:24'hffffff;
      if(name_selected && dialog_x>=156 && dialog_x<156+((name_len*9<8)?8:(name_len*9>206)?206:name_len*9) && dialog_y>=152 && dialog_y<170)bg=24'h1771ff;
      if(dialog_y>=152 && dialog_y<168)begin dynamic=1;label_raddr=4;pos=12'(integer'(dialog_x)-158);font_row=4'(dialog_y-152);fg=name_selected?24'hffffff:24'h000000;end
     end
     if(caret_on && dialog_y>=154 && dialog_y<166 && dialog_x==(caret_px>202?360:158+integer'(caret_px)))begin bg=0;dynamic=0;static_id=0;end
     if(dialog_y>=182 && dialog_y<198)begin static_id=message_id;dynamic=0;pos=12'(integer'(dialog_x)-152);font_row=4'(dialog_y-182);fg=24'h646464;end
    end else if(dialog==3 || dialog==4)begin
     if(dialog_y>=136 && dialog_y<152)begin static_id=dialog==3?146:149;pos=12'(integer'(dialog_x)-154);font_row=4'(dialog_y-136);end
     if(dialog_y>=166 && dialog_y<182)begin dynamic=1;label_raddr=dialog==3?1:4;pos=12'(integer'(dialog_x)-154);font_row=4'(dialog_y-166);end
    end else if(dialog_y>=136 && dialog_y<152)begin static_id=message_id;pos=12'(integer'(dialog_x)-154);font_row=4'(dialog_y-136);end
   end
   for(integer button=0;button<3;button=button+1)begin
    bx=0;by=234;bw=0;bid=0;
    case(dialog)
     1:begin by=244;bw=112;if(button==0)begin bx=386;bid=143;end else if(button==1)begin bx=260;bid=142;end end
     2:begin by=214;if(button==0)begin bx=152;bw=84;bid=123;end else if(button==1)begin bx=252;bw=96;bid=142;end end
     4:begin bw=110;if(button==0)begin bx=376;bid=144;end else if(button==1)begin bx=250;bid=142;end end
     3:begin bw=100;if(button==0)begin bx=144;bid=123;end else if(button==1)begin bx=266;bid=165;end else begin bx=388;bid=142;end end
     5:if(button==0)begin bw=100;bx=270;bid=145;end
     default:;
    endcase
    bx=integer'(sys_config[(12+(integer'(dialog)-1)*9+button*3)*16+:16]);
    by=integer'(sys_config[(13+(integer'(dialog)-1)*9+button*3)*16+:16]);
    bw=integer'(sys_config[(14+(integer'(dialog)-1)*9+button*3)*16+:16]);
    if(bid!=0 && button==0 && sys_config[176] && round_inside(dialog_x-bx+4,dialog_y-by+4,bw+8,34,sys_config[160]))begin
     op=1;modal=1;bg=round_inside(dialog_x-bx+2,dialog_y-by+2,bw+4,30,sys_config[160])?24'hffffff:24'h000000;dynamic=0;static_id=0;
    end
    if(bid!=0 && round_inside(dialog_x-bx,dialog_y-by,bw,26,sys_config[160]))begin
     op=1;modal=1;bg=0;
     if(round_inside(dialog_x-bx-1,dialog_y-by-1,bw-2,24,sys_config[160]) && !(hot_button==button || (button==0 && flash_default)))bg=24'hffffff;
     fg=(hot_button==button || (button==0 && flash_default))?24'hffffff:24'h000000;dynamic=0;static_id=0;
     if(dialog_y>=by+4 && dialog_y<by+20)begin
      static_id=8'(bid);bi=(bw-integer'(widths[8'(bid)]))/2;if(bi<5)bi=5;
      pos=12'(integer'(dialog_x)-bx-bi);font_row=4'(integer'(dialog_y)-by-4);
     end
    end
   end
  end
  if(about_open && x>=133 && x<508 && y>=154 && y<307)begin
   op=1;modal=1;bg=24'hffffff;fg=0;static_id=0;dynamic=0;label_raddr=127;lx=x-133;ly=y-154;
   if(lx<2 || lx>=373 || ly<2 || ly>=151)bg=0;
   else if(lx>=140 && lx<236 && ly>=115 && ly<142)bg=(lx==140||lx==235||ly==115||ly==141||about_hot)?24'h000000:24'hdbdbdb;
   if(ly>=12 && ly<28)begin static_id=160;pos=12'(lx-20);font_row=4'(ly-12);end
   if(ly>=44 && ly<60)begin
    pos=12'(lx-20);font_row=4'(ly-44);
    if(about_valid)begin dynamic=1;label_raddr=2;end
    else static_id=role==0?151:role==1?136:role==2?137:role==3?83:role==4?139:role==5?140:role==7?135:role==8?167:86;
   end
   if(ly>=70 && ly<86)begin
    pos=12'(lx-20);font_row=4'(ly-70);
    if(about_valid)begin dynamic=1;label_raddr=3;end
    else static_id=role==0?152:role==1?153:role==2?154:role==3?155:role==4?156:role==5?157:role==7?159:role==8?168:158;
   end
   if(ly>=121 && ly<137)begin if(about_hot)fg=24'hffffff;static_id=145;pos=12'(lx-175);font_row=4'(ly-121);end
  end
  // Fixed labels use their existing ROM; application rows may reuse that RAM.
  // Single-character arrows and the clipped dirty marker need no prefetch.
  direct_static=static_id==90 || (static_id>=98 && static_id<=101);
  static_glyph=direct_static?classic_direct_glyph(static_id,pos):12'd0;
  if(check_prefix)begin
   dynamic=0;direct_static=1;static_glyph=0;
   // Same seven-column checkmark as the shared Python menu renderer.
   case(x-popup_left-10'd8)
    0,4:if(popup_line==6 || popup_line==7)bg=fg;
    1,3:if(popup_line==7 || popup_line==8)bg=fg;
    2:if(popup_line==8 || popup_line==9)bg=fg;
    5:if(popup_line==5 || popup_line==6)bg=fg;
    6:if(popup_line==4 || popup_line==5)bg=fg;
    default:;
   endcase
  end
 end
 always_ff @(posedge pixel_clk)begin
  q_direct_static<=direct_static;q_op<=op;q_modal<=modal;q_bg<=bg;q_fg<=fg;q_dynamic<=dynamic;q_static_glyph<=static_glyph;q_font_row<=font_row;
 end
 assign label_pos=pos;
 jmr_classic_static_labels u_static_labels(.pixel_clk(pixel_clk),.rst_n(rst_n),.clk(clk),.sys_we(sys_we),.sys_addr(sys_addr),.sys_data(sys_data),
  .label_id(direct_static?8'd0:static_id),.read_pos(pos),.beam_y(y),.read_glyph(cached_static_glyph));
 assign glyph=q_dynamic?label_glyph:q_direct_static?q_static_glyph:cached_static_glyph;
 always_ff @(posedge pixel_clk)begin
  font_data<=font[{glyph[10:4],q_font_row}];r_col<=glyph[3:0];r_op<=q_op;r_modal<=q_modal;r_bg<=q_bg;r_fg<=q_fg;
  // A missing glyph must not use a stale character's ink.
  if(!glyph[11])font_data<=0;
 end
 assign opaque=r_op;
 assign modal_opaque=r_modal;
 assign rgb=font_data[15-r_col]?r_fg:r_bg;
endmodule
