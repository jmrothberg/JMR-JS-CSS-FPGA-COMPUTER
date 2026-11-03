// One registered distributed-ROM read per display pixel. All UI backgrounds
// are opaque, including zero font bits: games cannot show through a menu.
module jmr_system_overlay (
 input logic pixel_clk,
 input logic [9:0] x,y,
 input logic menu_open,keyboard_open,about_open,shift_on,caps_on,ctrl_on,alt_on,
 input logic [6:0] pressed_index,
 input logic hold_keys,
 input logic [69:0] held_keys,
 output logic opaque,
 output logic [23:0] rgb
);
 import jmr_system_menu_pkg::*;
 (* rom_style="distributed" *)logic [15:0] font [0:2047];
 initial $readmemh("desktop_font.hex",font);
 logic op,ink,q_op,q_ink;
 logic [27:0] ship_bits;
 logic [23:0] bg,fg,q_bg,q_fg;
 logic [11:0] glyph;
 logic [3:0] row,q_col;
 logic [15:0] font_data;
 always_comb begin
  integer index,local_x,local_y;
  logic active;
  op=0;bg=0;fg=0;glyph=0;row=0;index=0;local_x=0;local_y=0;active=0;
  ship_bits=enterprise_row(integer'(y)-7);
  if(x<30 && y<22)begin
   op=1;bg=(y==21)?24'h000000:24'hffffff;
   if(x>=1 && x<29 && y>=7 && y<15 && ship_bits[28-x])bg=24'h000000;
  end else if(menu_open && x<190 && y>=22 && y<72)begin
   op=1;bg=(x==0 || x==189 || y==22 || y==71)?24'h000000:24'hffffff;
   if(y>=26 && y<42)begin glyph=ui_glyph(75,integer'(x)-8,shift_on);row=4'(y-26);end
   else if(y>=47 && y<63)begin glyph=ui_glyph(72,integer'(x)-8,shift_on);row=4'(y-47);end
  end
  if(keyboard_open && y>=296 && y<480)begin
   op=1;bg=24'hdbdbdb;fg=0;glyph=0;row=0;
   if(y>=297 && y<313)begin
    row=4'(y-297);
    glyph=(x>=600)?ui_glyph(73,integer'(x)-607,shift_on):ui_glyph(72,integer'(x)-12,shift_on);
   end
   if(y>=297 && y<313 && x>=448 && x<585)begin
    glyph=ui_glyph(74,integer'(x)-448,shift_on);row=4'(y-297);
   end
   if(x>=428 && x<439 && y>=299 && y<310)begin
    bg=(x==428 || x==438 || y==299 || y==309 || hold_keys)?24'h000000:24'hffffff;
   end
   if(x>=12 && x<628 && y>=314 && y<479)begin
    local_x=(x-12)%44;local_y=(y-314)%33;index=((y-314)/33)*14+(x-12)/44;
    active=(index==pressed_index)||held_keys[index]||(index==42 && shift_on)||(index==28 && caps_on)||(index==54 && ctrl_on)||(index==55 && alt_on);
    if(local_x<40 && local_y<29)begin
     bg=(local_x==0 || local_x==39 || local_y==0 || local_y==28)?24'h000000:active?24'h1771ff:24'hffffff;
     fg=active?24'hffffff:24'h000000;
     if(local_y>=6 && local_y<22)begin glyph=ui_glyph(index,local_x-3,shift_on);row=4'(local_y-6);end
    end
   end
  end
  if(about_open && x>=133 && x<508 && y>=154 && y<307)begin
   local_x=x-133;local_y=y-154;op=1;bg=24'hffffff;fg=0;glyph=0;row=0;
   if(local_x<2 || local_x>=373 || local_y<2 || local_y>=151)bg=0;
   else if(local_x>=140 && local_x<236 && local_y>=115 && local_y<142)
    bg=(local_x==140 || local_x==235 || local_y==115 || local_y==141)?24'h000000:24'hdbdbdb;
   if(local_y>=12 && local_y<28)begin glyph=ui_glyph(76,local_x-20,shift_on);row=4'(local_y-12);end
   else if(local_y>=44 && local_y<60)begin glyph=ui_glyph(77,local_x-20,shift_on);row=4'(local_y-44);end
   else if(local_y>=65 && local_y<81)begin glyph=ui_glyph(78,local_x-20,shift_on);row=4'(local_y-65);end
   else if(local_y>=86 && local_y<102)begin glyph=ui_glyph(79,local_x-20,shift_on);row=4'(local_y-86);end
   else if(local_y>=121 && local_y<137)begin glyph=ui_glyph(80,local_x-175,shift_on);row=4'(local_y-121);end
  end
  ink=glyph[11];
 end
 always_ff @(posedge pixel_clk)begin
  font_data<=font[{glyph[10:4],row}];
  q_op<=op;q_bg<=bg;q_fg<=fg;q_ink<=ink;q_col<=glyph[3:0];
 end
 assign opaque=q_op;
 assign rgb=(q_ink && font_data[15-q_col])?q_fg:q_bg;
endmodule
