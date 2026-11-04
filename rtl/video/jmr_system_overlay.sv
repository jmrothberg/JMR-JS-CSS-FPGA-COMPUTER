// Opaque ship menu and mouse keyboard. Shared label bitmaps keep the display
// small: one registered ROM read, with identical key legends sharing a row.
// About is drawn by jmr_classic_overlay; the old bitmap bank is intentionally absent.
module jmr_system_overlay (
 input logic pixel_clk,clk,sys_we,
 input logic [13:0] sys_addr,
 input logic [15:0] sys_data,
 input logic [9:0] x,y,
 input logic menu_open,keyboard_open,about_open,shift_on,caps_on,ctrl_on,alt_on,
 input logic [2:0] hover_row,
 input logic finder_mode,
 input logic [6:0] pressed_index,
 input logic hold_keys,
 input logic [69:0] held_keys,
 output logic opaque,
 output logic [23:0] rgb
);
 import jmr_system_menu_pkg::*;
 (* ram_style="block" *) logic [39:0] key_rows [0:2047];
 (* ram_style="distributed" *) logic [63:0] label_rows [0:127];
 initial begin
  $readmemh("system_keys.hex",key_rows);$readmemh("system_labels.hex",label_rows);
 end
 // 40-bit keyboard rows are packed into a byte stream. A shift register
 // assembles one row; only a complete row writes the display RAM.
 logic [47:0] resource_label_shift;
 logic [47:0] resource_key_shift;
 logic [2:0] resource_key_phase;
 logic [10:0] resource_key_index;
 initial begin resource_key_shift=0;resource_key_phase=0;resource_key_index=0;end
 always_ff @(posedge clk)if(sys_we)begin
  if(sys_addr>=4736 && sys_addr<9856)begin
   if(sys_addr==4736)begin resource_key_index<=0;resource_key_shift[15:0]<=sys_data;resource_key_phase<=1;end
   else case(resource_key_phase)
    0:begin resource_key_shift[15:0]<=sys_data;resource_key_phase<=1;end
    1:begin resource_key_shift[31:16]<=sys_data;resource_key_phase<=2;end
    2:begin key_rows[resource_key_index]<={sys_data[7:0],resource_key_shift[31:0]};resource_key_shift[7:0]<=sys_data[15:8];resource_key_phase<=3;resource_key_index<=resource_key_index+1'b1;end
    3:begin resource_key_shift[23:8]<=sys_data;resource_key_phase<=4;end
    4:begin key_rows[resource_key_index]<={sys_data,resource_key_shift[23:0]};resource_key_phase<=0;resource_key_index<=resource_key_index+1'b1;end
    default:resource_key_phase<=0;
   endcase
  end
  // Both caption ranges are contiguous; one write port preserves BRAM inference.
  if(sys_addr>=9856 && sys_addr<10304)begin
   if(sys_addr[1:0]==3)label_rows[7'((sys_addr-9856)>>2)]<={sys_data,resource_label_shift};
   else resource_label_shift[sys_addr[1:0]*16+:16]<=sys_data;
  end

 end
 logic op,ink,q_op,q_ink;
 logic [27:0] ship_bits;
 logic [23:0] bg,fg,q_bg,q_fg;
 logic [1:0] paint_kind,q_kind;logic [2:0] label_id;
 logic [2:0] about_id;
 logic [3:0] row;
 logic [7:0] q_col;
 logic signed [10:0] column;
 logic [39:0] key_data;logic [63:0] label_data;
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
  end else if(menu_open && x<190 && y>=22 && y<(finder_mode?139:72))begin
   op=1;bg=(x==0 || x==189 || y==22 || y==(finder_mode?138:71))?24'h000000:24'hffffff;
   if(x>0 && x<189 && hover_row!=0 && (finder_mode ? (y>=24+(hover_row-1)*21 && y<44+(hover_row-1)*21) : (hover_row==1 ? (y>=24 && y<46) : (y>=47 && y<70))))begin bg=0;fg=24'hffffff;end
   for(integer r=0;r<5;r=r+1)if((finder_mode || r<2) && y>=26+r*21 && y<42+r*21)begin
    paint_kind=2;label_id=r==0?3'd3:r==1?3'd0:3'(r+2);column=11'(x)-11'd8;row=4'(y-26-r*21);
   end
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
  ink=column>=0 && ((paint_kind==1 && column<40) || (paint_kind==2 && column<64) || (paint_kind==3 && column<256));
 end
 always_ff @(posedge pixel_clk)begin
  key_data<=key_rows[{bitmap_id,row}];label_data<=label_rows[{label_id,row}];
  q_op<=op;q_bg<=bg;q_fg<=fg;q_ink<=ink;q_col<=column[7:0];q_kind<=paint_kind;
 end
 assign opaque=q_op;
 logic pixel_ink;
 always_comb begin
  pixel_ink=0;
  case(q_kind)1:pixel_ink=key_data[39-q_col[5:0]];2:pixel_ink=label_data[63-q_col[5:0]];default:;endcase
 end
 assign rgb=(q_ink && pixel_ink)?q_fg:q_bg;
endmodule
