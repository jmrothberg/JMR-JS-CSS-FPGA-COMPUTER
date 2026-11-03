// Opaque ship menu and mouse keyboard. Shared label bitmaps keep the display
// small: one registered ROM read, with identical key legends sharing a row.
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
 (* rom_style="distributed" *) logic [39:0] key_rows [0:2047];
 (* rom_style="distributed" *) logic [63:0] label_rows [0:63];
 (* rom_style="distributed" *) logic [255:0] about_rows [0:127];
 initial begin
  $readmemh("system_keys.hex",key_rows);$readmemh("system_labels.hex",label_rows);$readmemh("system_about.hex",about_rows);
 end
 logic op,ink,q_op,q_ink;
 logic [27:0] ship_bits;
 logic [23:0] bg,fg,q_bg,q_fg;
 logic [1:0] paint_kind,q_kind,label_id;
 logic [2:0] about_id;
 logic [3:0] row;
 logic [7:0] q_col;
 logic signed [10:0] column;
 logic [39:0] key_data;logic [63:0] label_data;logic [255:0] about_data;
 wire [9:0] key_x=x-10'd12,key_y=y-10'd314;
 wire [3:0] key_col=4'(key_x/10'd44);
 wire [2:0] key_row=3'(key_y/10'd33);
 wire [5:0] local_x=6'(key_x%10'd44),local_y=6'(key_y%10'd33);
 wire [6:0] key_index=7'(key_row)*7'd14+7'(key_col);
 wire [6:0] bitmap_id=key_bitmap_id(key_index,shift_on);
 always_comb begin
  integer lx,ly;
  logic active;
  op=0;bg=0;fg=0;row=0;paint_kind=0;column=0;label_id=0;about_id=0;active=0;lx=0;ly=0;
  ship_bits=enterprise_row(integer'(y)-7);
  if(x<30 && y<22)begin
   op=1;bg=(y==21)?24'h000000:24'hffffff;
   if(x>=1 && x<29 && y>=7 && y<15 && ship_bits[28-x])bg=24'h000000;
  end else if(menu_open && x<190 && y>=22 && y<72)begin
   op=1;bg=(x==0 || x==189 || y==22 || y==71)?24'h000000:24'hffffff;
   if(y>=26 && y<42)begin paint_kind=2;label_id=3;column=11'(x)-11'd8;row=4'(y-26);end
   else if(y>=47 && y<63)begin paint_kind=2;label_id=0;column=11'(x)-11'd8;row=4'(y-47);end
  end
  if(keyboard_open && y>=296 && y<480)begin
   op=1;bg=24'hdbdbdb;fg=0;paint_kind=0;row=0;
   if(y>=297 && y<313)begin
    paint_kind=2;row=4'(y-297);label_id=x>=600?2'd1:2'd0;column=11'(x)-(x>=600?11'd607:11'd12);
   end
   if(y>=297 && y<313 && x>=448 && x<585)begin paint_kind=2;label_id=2;column=11'(x)-11'd448;row=4'(y-297);end
   if(x>=428 && x<439 && y>=299 && y<310)bg=(x==428 || x==438 || y==299 || y==309 || hold_keys)?24'h000000:24'hffffff;
   if(x>=12 && x<628 && y>=314 && y<479)begin
    active=(key_index==pressed_index)||held_keys[key_index]||(key_index==42 && shift_on)||(key_index==28 && caps_on)||(key_index==54 && ctrl_on)||(key_index==55 && alt_on);
    if(local_x<40 && local_y<29)begin
     bg=(local_x==0 || local_x==39 || local_y==0 || local_y==28)?24'h000000:active?24'h1771ff:24'hffffff;
     fg=active?24'hffffff:24'h000000;
     if(local_y>=6 && local_y<22)begin paint_kind=1;column=11'(local_x)-11'd3;row=4'(local_y-6);end
    end
   end
  end
  if(about_open && x>=133 && x<508 && y>=154 && y<307)begin
   lx=x-133;ly=y-154;op=1;bg=24'hffffff;fg=0;paint_kind=0;row=0;
   if(lx<2 || lx>=373 || ly<2 || ly>=151)bg=0;
   else if(lx>=140 && lx<236 && ly>=115 && ly<142)bg=(lx==140 || lx==235 || ly==115 || ly==141)?24'h000000:24'hdbdbdb;
   if(ly>=12 && ly<28)begin paint_kind=3;about_id=0;column=11'(lx-20);row=4'(ly-12);end
   else if(ly>=44 && ly<60)begin paint_kind=3;about_id=1;column=11'(lx-20);row=4'(ly-44);end
   else if(ly>=65 && ly<81)begin paint_kind=3;about_id=2;column=11'(lx-20);row=4'(ly-65);end
   else if(ly>=86 && ly<102)begin paint_kind=3;about_id=3;column=11'(lx-20);row=4'(ly-86);end
   else if(ly>=121 && ly<137)begin paint_kind=3;about_id=4;column=11'(lx-175);row=4'(ly-121);end
  end
  ink=column>=0 && ((paint_kind==1 && column<40) || (paint_kind==2 && column<64) || (paint_kind==3 && column<256));
 end
 always_ff @(posedge pixel_clk)begin
  key_data<=key_rows[{bitmap_id,row}];label_data<=label_rows[{label_id,row}];about_data<=about_rows[{about_id,row}];
  q_op<=op;q_bg<=bg;q_fg<=fg;q_ink<=ink;q_col<=column[7:0];q_kind<=paint_kind;
 end
 assign opaque=q_op;
 logic pixel_ink;
 always_comb begin
  pixel_ink=0;
  case(q_kind)1:pixel_ink=key_data[39-q_col[5:0]];2:pixel_ink=label_data[63-q_col[5:0]];3:pixel_ink=about_data[255-q_col];default:;endcase
 end
 assign rgb=(q_ink && pixel_ink)?q_fg:q_bg;
endmodule
