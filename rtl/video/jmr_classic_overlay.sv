// Two-pixel-clock native UI renderer. A registered label read followed by a
// registered font read; variable text never becomes a combinational RAM peek.
module jmr_classic_overlay (
 input logic pixel_clk,
 input logic [9:0] x,y,
 input logic [31:0] window_state,
 input logic [3:0] active_menu,popup_count,
 input logic [9:0] popup_left,
 output logic [3:0] popup_row,
 input logic [7:0] popup_static,
 input logic [5:0] popup_dynamic,
 input logic popup_enabled,about_open,about_valid,title_valid,
 input logic [9:0] title_width,
 input logic [2:0] dialog,
 input logic [8:0] file_count,selected,
 input logic [7:0] file_top,message_id,
 input logic [3:0] name_len,
 input logic name_selected,
 output logic [5:0] label_raddr,
 input logic [1727:0] label_rdata,
 output logic opaque,modal_opaque,
 output logic [23:0] rgb
);
 import jmr_system_menu_pkg::*;
 import jmr_classic_ui_pkg::*;
 (* rom_style="distributed" *) logic [15:0] font [0:2047];
 initial $readmemh("desktop_font.hex",font);
 logic op,modal,dynamic;
 logic [23:0] bg,fg;
 logic [11:0] static_glyph;
 logic [7:0] static_id;
 logic signed [11:0] pos;
 logic [3:0] font_row;
 logic q_op,q_modal,q_dynamic;
 logic [23:0] q_bg,q_fg;
 logic [11:0] q_static_glyph;
 logic signed [11:0] q_pos;
 logic [3:0] q_font_row;
 logic [11:0] glyph;
 logic r_op,r_modal;
 logic [23:0] r_bg,r_fg;
 logic [3:0] r_col;
 logic [15:0] font_data;
 assign popup_row=y>=26?4'((y-26)/21):15;
 always_comb begin
  integer role,sy,sx,flags,thumb,tx,title_id,title_x,title_w,hint_id,lx,ly,bx,by,bw,bid,bi,row_index;
  role=window_state[7:0];sy=window_state[15:8];sx=window_state[23:16];flags=window_state[31:24];
  op=0;modal=0;bg=0;fg=0;static_id=0;static_glyph=0;dynamic=0;label_raddr=63;pos=0;font_row=0;
  thumb=109+(sy*280/256);tx=29+(sx*520/256);title_id=80+role;title_w=0;title_x=240;hint_id=96;lx=0;ly=0;bx=0;by=0;bw=0;bid=0;bi=0;row_index=0;
  if(role!=0)begin
   if(role!=8)begin
    op=1;bg=24'h55ddff;
    if(x>=8 && x<620 && y>=34 && y<454)bg=0;
    if(x>=9 && x<619 && y>=35 && y<453)bg=24'hffffff;
    if(((x>=32 && x<238)||(x>=402 && x<613)) && y>=40 && y<56 && ((y-40)%3)==0)bg=0;
    if(x>=10 && x<618 && y==60)bg=0;
    if(x>=16 && x<30 && y>=40 && y<54)bg=(x==16||x==29||y==40||y==53)?24'h000000:24'hffffff;
    if(x>=24 && x<600 && y>=88 && y<432)op=0;
    if(x==600 && y>=88 && y<432)bg=0;
    if(x>=601 && x<618 && y>=108 && y<414)bg=24'hdddddd;
    if(x>=601 && x<618 && (y==107 || y==414))bg=0;
    if(x>=601 && x<618 && y>=thumb && y<thumb+18)bg=(x==601 || x==617 || y==thumb || y==thumb+17)?24'h000000:24'hffffff;
    if(x>=10 && x<618 && y==433)bg=0;
    if(role==1 || role==5)begin
     if(x>=28 && x<582 && y>=434 && y<453)bg=24'hdddddd;
     if((x==27 || x==582) && y>=434 && y<453)bg=0;
     if(x>=tx && x<tx+32 && y>=434 && y<453)bg=(x==tx || x==tx+31 || y==434 || y==452)?24'h000000:24'hffffff;
    end
    // Static system captions use the same Chicago ROM as the desktop.
    title_w=classic_width(title_id);
    title_x=(640-title_w)/2;if(title_x<240)title_x=240;
    if(y>=38 && y<54)begin static_id=8'(title_id);pos=12'(integer'(x)-title_x);font_row=4'(y-38);end
    if(title_valid && (role==1 || role==2 || role==5) && y>=38 && y<54)begin
     title_x=(640-integer'(title_width))/2;if(title_x<240)title_x=240;
     static_id=0;dynamic=1;label_raddr=1;pos=12'(integer'(x)-title_x);font_row=4'(y-38);
    end
    case(role)
     1,5:hint_id=89;2:hint_id=91;3:case((flags>>4)&7)1:hint_id=103;2:hint_id=93;3:hint_id=104;4:hint_id=94;default:hint_id=92;endcase
     4:hint_id=95;7:hint_id=97;default:hint_id=96;
    endcase
    if(y>=66 && y<82)begin dynamic=0;static_id=8'(hint_id);pos=12'(integer'(x)-24);font_row=4'(y-66);end
    if((role==1 || role==5) && flags[0] && y>=66 && y<82 && x>=480)begin static_id=90;pos=12'(x-480);font_row=4'(y-66);end
    if(y>=90 && y<106 && x>=604)begin static_id=98;pos=12'(x-604);font_row=4'(y-90);end
    if(y>=415 && y<431 && x>=604)begin static_id=99;pos=12'(x-604);font_row=4'(y-415);end
    if(y>=435 && y<451)begin
     if(role==1 || role==5)begin
      if(x>=13 && x<28)begin static_id=100;pos=12'(x-13);font_row=4'(y-435);end
      else if(x>=586 && x<600)begin static_id=101;pos=12'(x-586);font_row=4'(y-435);end
     end else begin static_id=102;pos=12'(integer'(x)-24);font_row=4'(y-435);end
    end
   end
   if(y<22)begin
    op=1;bg=y==21?24'h000000:24'hffffff;static_id=0;
    if(y>=3 && y<19)begin dynamic=1;label_raddr=0;pos=12'(x);font_row=4'(y-3);end
   end
   if(active_menu!=0 && ((x>=popup_left+2 && x<popup_left+214 && y>=24 && y<24+popup_count*21+8) || (x>=popup_left && x<popup_left+212 && y>=22 && y<22+popup_count*21+8)))begin
    static_id=0;dynamic=0;label_raddr=63;op=1;bg=0;fg=0;
    if(x<popup_left+212 && y<22+popup_count*21+8)begin
     bg=(x==popup_left || x==popup_left+211 || y==22 || y==22+popup_count*21+7)?24'h000000:24'hffffff;
     if(y>=27 && ((y-27)%21)<16 && popup_row<popup_count)begin
      pos=12'(integer'(x)-integer'(popup_left)-10);font_row=4'((y-27)%21);fg=popup_enabled?24'h000000:24'h919191;
      if(popup_dynamic!=63)begin dynamic=1;label_raddr=popup_dynamic;end
      else static_id=popup_static;
     end
    end
   end
  end
  if(dialog!=0)begin
   if(dialog==1 && x>=110 && x<530 && y>=76 && y<276)begin
    op=1;modal=1;bg=(x<112 || x>=528 || y<78 || y>=274)?24'h000000:24'hffffff;
    fg=0;static_id=0;dynamic=0;label_raddr=63;
    if(y>=84 && y<100)begin static_id=143;pos=12'(integer'(x)-280);font_row=4'(y-84);end
    if(x>=132 && x<510 && y>=110 && y<226)begin
     bg=(x<134 || x>=508 || y<112 || y>=224)?24'h000000:24'hffffff;
     static_id=0;dynamic=0;
     if(y>=112 && y<224 && x>=134 && x<508)begin
      row_index=(y-112)/16;
      if(x<484 && integer'(selected)==integer'(file_top)+row_index)bg=24'h1771ff;
      if(integer'(file_top)+row_index<integer'(file_count))begin
       dynamic=1;label_raddr=6'(6+row_index);pos=12'(integer'(x)-142);font_row=4'((y-112)%16);
       fg=(integer'(selected)==integer'(file_top)+row_index)?24'hffffff:24'h000000;
      end
      if(file_count==0 && y>=144 && y<160)begin static_id=150;dynamic=0;pos=12'(integer'(x)-142);font_row=4'(y-144);fg=24'h646464;end
      if(x>=490 && y>=116 && y<132)begin static_id=98;dynamic=0;pos=12'(x-490);font_row=4'(y-116);fg=0;end
      if(x>=490 && y>=204 && y<220)begin static_id=99;dynamic=0;pos=12'(x-490);font_row=4'(y-204);fg=0;end
     end
    end
   end else if(dialog!=1 && x>=132 && x<508 && y>=112 && y<276)begin
    op=1;modal=1;bg=(x<134 || x>=506 || y<114 || y>=274)?24'h000000:24'hffffff;
    fg=0;static_id=0;dynamic=0;label_raddr=63;
    if(dialog==2)begin
     if(y>=124 && y<140)begin static_id=147;pos=12'(integer'(x)-154);font_row=4'(y-124);end
     if(x>=150 && x<489 && y>=156 && y<185)begin
      bg=(x<152 || x>=487 || y<158 || y>=183)?24'h000000:24'hffffff;
      if(name_selected && x>=154 && x<154+((name_len*9<8)?8:(name_len*9>330)?330:name_len*9) && y>=161 && y<179)bg=24'h1771ff;
      if(y>=160 && y<176)begin dynamic=1;label_raddr=4;pos=12'(integer'(x)-156);font_row=4'(y-160);fg=name_selected?24'hffffff:24'h000000;end
     end
     if(y>=194 && y<210)begin static_id=message_id;dynamic=0;pos=12'(integer'(x)-154);font_row=4'(y-194);fg=24'h646464;end
    end else if(dialog==3 || dialog==4)begin
     if(y>=136 && y<152)begin static_id=dialog==3?146:149;pos=12'(integer'(x)-154);font_row=4'(y-136);end
     if(y>=166 && y<182)begin dynamic=1;label_raddr=dialog==3?1:4;pos=12'(integer'(x)-154);font_row=4'(y-166);end
    end else if(y>=136 && y<152)begin static_id=message_id;pos=12'(integer'(x)-154);font_row=4'(y-136);end
   end
   for(integer button=0;button<3;button=button+1)begin
    bx=0;by=234;bw=0;bid=0;
    case(dialog)
     1:begin by=244;bw=112;if(button==0)begin bx=386;bid=143;end else if(button==1)begin bx=260;bid=142;end end
     2,4:begin bw=110;if(button==0)begin bx=376;bid=dialog==2?123:144;end else if(button==1)begin bx=250;bid=142;end end
     3:begin bw=100;if(button==0)begin bx=144;bid=123;end else if(button==1)begin bx=266;bid=165;end else begin bx=388;bid=142;end end
     5:if(button==0)begin bw=100;bx=270;bid=145;end
     default:;
    endcase
    if(bid!=0 && x>=bx && x<bx+bw && y>=by && y<by+26)begin
     op=1;modal=1;bg=(x==bx || x==bx+bw-1 || y==by || y==by+25)?24'h000000:24'hffffff;
     fg=0;dynamic=0;static_id=0;
     if(y>=by+4 && y<by+20)begin
      static_id=8'(bid);bi=(bw-integer'(classic_width(bid)))/2;if(bi<5)bi=5;
      pos=12'(integer'(x)-bx-bi);font_row=4'(integer'(y)-by-4);
     end
    end
   end
  end
  if(about_open && x>=133 && x<508 && y>=154 && y<307)begin
   op=1;modal=1;bg=24'hffffff;fg=0;static_id=0;dynamic=0;label_raddr=63;lx=x-133;ly=y-154;
   if(lx<2 || lx>=373 || ly<2 || ly>=151)bg=0;
   else if(lx>=140 && lx<236 && ly>=115 && ly<142)bg=(lx==140||lx==235||ly==115||ly==141)?24'h000000:24'hdbdbdb;
   if(ly>=12 && ly<28)begin static_id=160;pos=12'(lx-20);font_row=4'(ly-12);end
   if(ly>=44 && ly<60)begin
    pos=12'(lx-20);font_row=4'(ly-44);
    if(about_valid)begin dynamic=1;label_raddr=2;end
    else static_id=role==0?151:role==1?136:role==2?137:role==3?138:role==4?139:role==5?140:role==7?135:96;
   end
   if(ly>=70 && ly<86)begin
    pos=12'(lx-20);font_row=4'(ly-70);
    if(about_valid)begin dynamic=1;label_raddr=3;end
    else static_id=role==0?152:role==1?153:role==2?154:role==3?155:role==4?156:role==5?157:role==7?159:158;
   end
   if(ly>=121 && ly<137)begin static_id=145;pos=12'(lx-175);font_row=4'(ly-121);end
  end
  static_glyph=static_id==0?12'd0:static_id>=110?classic_glyph(static_id,pos):ui_glyph(static_id,pos,1'b0);
 end
 always_ff @(posedge pixel_clk)begin
  q_op<=op;q_modal<=modal;q_bg<=bg;q_fg<=fg;q_dynamic<=dynamic;q_static_glyph<=static_glyph;q_pos<=pos;q_font_row<=font_row;
 end
 always_comb begin
  glyph=q_static_glyph;
  if(q_dynamic)begin
   glyph=0;
   for(integer i=0;i<64;i=i+1)begin
    if(label_rdata[i*27+:7]!=0 && q_pos>=0 && q_pos>=12'({2'd0,label_rdata[i*27+7+:10]}) && q_pos<12'({2'd0,label_rdata[i*27+17+:10]}))
     glyph={1'b1,label_rdata[i*27+:7],4'(q_pos-12'({2'd0,label_rdata[i*27+7+:10]}))};
   end
  end
 end
 always_ff @(posedge pixel_clk)begin
  font_data<=font[{glyph[10:4],q_font_row}];r_col<=glyph[3:0];r_op<=q_op;r_modal<=q_modal;r_bg<=q_bg;r_fg<=q_fg;
  // A missing glyph must not use a stale character's ink.
  if(!glyph[11])font_data<=0;
 end
 assign opaque=r_op;
 assign modal_opaque=r_modal;
 assign rgb=font_data[15-r_col]?r_fg:r_bg;
endmodule
