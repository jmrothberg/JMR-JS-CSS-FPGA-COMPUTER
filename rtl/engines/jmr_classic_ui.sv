// Native shared menus: descriptor parsing, compact proportional text and input.
// No JS heap or framebuffer is duplicated. Text RAM has scalar write/read ports.
module jmr_classic_ui (
 input logic clk,rst_n,pixel_clk,app_clear,
 input logic [31:0] window_state,
 input logic [127:0] source_name,
 input logic [4:0] source_name_len,
 input logic external_label_valid,
 input logic [5:0] external_label_row,
 input logic [1727:0] external_label_data,
 output logic external_label_ready,
 input logic text_stb,text_menu,text_first,text_last,
 input logic [7:0] text_byte,
 input logic sample_valid,system_active,keyboard_open,guest_drag,cancel_menu,
 input logic [9:0] x,
 input logic [8:0] y,
 input logic [2:0] buttons,
 output logic consume_pointer,
 output logic key_stb,
 output logic [7:0] key_code,
 output logic action_stb,
 output logic [3:0] action,
 output logic [31:0] generation,
 output logic descriptor_error,
 output logic [3:0] active_menu,
 output logic [9:0] popup_left,
 output logic [3:0] popup_count,
 input logic [3:0] popup_row,
 output logic [7:0] popup_static,
 output logic [5:0] popup_dynamic,
 output logic popup_enabled,
 input logic [5:0] label_raddr,
 output logic [1727:0] label_rdata,
 output logic about_valid,
 output logic title_valid,
 output logic [9:0] title_width
);
 import jmr_classic_ui_pkg::*;
 (* ram_style="distributed" *) logic [1727:0] labels [0:63];
 logic label_we;
 logic [5:0] label_waddr;
 logic [1727:0] label_wdata;
 always_ff @(posedge clk)if(label_we)labels[label_waddr]<=label_wdata;
 always_ff @(posedge pixel_clk)label_rdata<=labels[label_raddr];
 logic [127:0] filename_seen;
 logic [4:0] filename_n_seen,title_char_i;
 logic title_pending,title_phase;
 logic [1727:0] title_buffer;
 logic [9:0] title_x;
 logic [1727:0] text_buffer,bar_buffer;
 logic [6:0] text_chars,bar_chars;
 logic [9:0] text_x,bar_x;
 logic [1:0] parse_mode,parse_head,custom_count;
 logic [3:0] parse_row;
 logic [7:0] parse_code;
 logic [287:0] headings;
 logic [11:0] heading_lengths;
 logic [11:0] row_counts;
 logic [191:0] commands;
 logic about_description;
 logic [7:0] old_role;
 logic bar_pending;
 logic [2:0] bar_phase,bar_slot,bar_kind,bar_count;
 logic [6:0] bar_char;
 logic [69:0] bar_lefts,bar_rights;
 logic [27:0] bar_kinds;
 logic [2:0] old_buttons;
 logic capture;
 logic [2:0] menu_kind;
 logic [7:0] selected_code;
 logic has_game;
 logic editable,click_enabled;
 wire [3:0] click_row=y>=26?4'((y-26)/21):4'd15;
 assign external_label_ready=!app_clear && !text_stb && bar_phase==0 && !bar_pending && !title_phase &&
  !(title_pending && source_name_len!=0 && (window_state[7:0]==1 || window_state[7:0]==2 || window_state[7:0]==5));
 assign editable=window_state[7:0]==1 || window_state[7:0]==5;
 always_comb begin
  has_game=0;
  for(integer h=0;h<3;h=h+1)
   if(h<custom_count && heading_lengths[h*4+:4]==4 && headings[h*96+:32]==32'h656d6147)has_game=1;
  menu_kind=active_menu==0?0:bar_kinds[(active_menu-1)*4+:3];
  popup_left=active_menu==0?0:bar_lefts[(active_menu-1)*10+:10];
  if(popup_left>426)popup_left=426;
  popup_static=0;popup_dynamic=63;popup_enabled=1;selected_code=0;popup_count=0;click_enabled=1;
  case(menu_kind)
   0:begin
    popup_count=window_state[7:0]==8?1:5;
    if(window_state[7:0]==8)begin popup_static=125;selected_code=0;end
    else case(popup_row)
     0:begin popup_static=120;selected_code=1;popup_enabled=editable;end
     1:begin popup_static=121;selected_code=2;popup_enabled=editable || window_state[7:0]==2;end
     2:begin popup_static=122;selected_code=0;end
     3:begin popup_static=123;selected_code=3;popup_enabled=editable;end
     default:begin popup_static=124;selected_code=4;popup_enabled=editable;end
    endcase
   end
   1:begin
    popup_count=6;popup_static=126+popup_row;selected_code=137+click_row;popup_enabled=editable;
    if(popup_row==0)popup_enabled=editable && window_state[25];
    if(popup_row==1 || popup_row==2 || popup_row==4)popup_enabled=editable && window_state[27];
    if(popup_row==3)popup_enabled=editable && window_state[26];
   end
   2:begin popup_count=2;popup_static=132+popup_row;selected_code=130+click_row;popup_enabled=window_state[7:0]!=3 && window_state[7:0]!=7;end
   3:begin
    popup_count=8;selected_code=6+click_row;popup_enabled=window_state[7:0]!=3;
    case(popup_row)0:popup_static=135;1:popup_static=136;2:popup_static=137;3:popup_static=138;
     4:popup_static=139;5:popup_static=140;6:popup_static=141;default:popup_static=134;endcase
   end
   4:begin popup_count=1;popup_static=134;selected_code=5;end
   default:begin
    popup_count=row_counts[(menu_kind-5)*4+:4];popup_dynamic=6'(32+(menu_kind-5)*8+popup_row);
    selected_code=commands[((menu_kind-5)*8+click_row)*8+:8];
   end
  endcase
  case(menu_kind)
   0:begin
    selected_code=window_state[7:0]==8?0:click_row==0?1:click_row==1?2:click_row==2?0:click_row==3?3:4;
    click_enabled=window_state[7:0]==8 || click_row==2 || (click_row==1?(editable || window_state[7:0]==2):editable);
   end
   1:begin
    click_enabled=editable;
    if(click_row==0)click_enabled=editable && window_state[25];
    if(click_row==1 || click_row==2 || click_row==4)click_enabled=editable && window_state[27];
    if(click_row==3)click_enabled=editable && window_state[26];
   end
   2:click_enabled=window_state[7:0]!=3 && window_state[7:0]!=7;
   3:click_enabled=window_state[7:0]!=3;
   default:click_enabled=1;
  endcase
 end
 assign consume_pointer=window_state[7:0]!=0 && !system_active && !guest_drag &&
  !(x<30 && y<22) && !(keyboard_open && y>=296) &&
  (capture || active_menu!=0 || y<22 || (window_state[7:0]!=8 && !(x>=24 && x<600 && y>=88 && y<432)));
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   label_we<=0;label_waddr<=0;label_wdata<=0;text_buffer<=0;text_chars<=0;text_x<=0;
   parse_mode<=0;parse_head<=0;parse_row<=0;parse_code<=0;custom_count<=0;headings<=0;heading_lengths<=0;row_counts<=0;commands<=0;
   about_description<=0;about_valid<=0;old_role<=0;bar_pending<=1;bar_phase<=0;bar_slot<=0;bar_kind<=0;bar_count<=0;bar_char<=0;bar_x<=34;bar_chars<=0;bar_buffer<=0;
   bar_lefts<=0;bar_rights<=0;bar_kinds<=0;old_buttons<=0;capture<=0;active_menu<=0;
   filename_seen<=0;filename_n_seen<=0;title_pending<=0;title_phase<=0;title_buffer<=0;title_x<=0;title_char_i<=0;title_valid<=0;generation<=0;descriptor_error<=0;key_stb<=0;key_code<=0;action_stb<=0;action<=0;title_width<=0;
  end else begin
   label_we<=0;key_stb<=0;action_stb<=0;
   if(source_name!=filename_seen || source_name_len!=filename_n_seen)begin
    filename_seen<=source_name;filename_n_seen<=source_name_len;title_pending<=1;
   end
   if(cancel_menu)begin active_menu<=0;generation<=generation+1'b1;end
   if(app_clear)begin
    title_valid<=0;title_pending<=1;title_phase<=0;
    custom_count<=0;headings<=0;heading_lengths<=0;row_counts<=0;commands<=0;
    about_valid<=0;bar_pending<=1;bar_phase<=0;active_menu<=0;capture<=0;old_buttons<=0;descriptor_error<=0;generation<=generation+1'b1;
   end
   if(old_role!=window_state[7:0])begin
    old_role<=window_state[7:0];title_pending<=1;bar_pending<=1;active_menu<=0;capture<=0;old_buttons<=0;generation<=generation+1'b1;
   end
   if(text_stb)begin
    logic [1727:0] buffer;
    logic [6:0] chars;
    logic [9:0] px;
    logic [1:0] mode,head;
    logic [3:0] item;
    logic [7:0] number;
    buffer=text_first?'0:text_buffer;chars=text_first?0:text_chars;px=text_first?0:text_x;
    mode=text_first?0:parse_mode;head=text_first?0:parse_head;item=text_first?0:parse_row;number=text_first?0:parse_code;
    if(text_first && text_menu)begin custom_count<=0;row_counts<=0;heading_lengths<=0;headings<=0;end
    if(text_first && !text_menu)begin about_description<=0;about_valid<=0;end
    if(text_menu && mode==2)begin
     if(text_byte>=48 && text_byte<=57)number=number*10+(text_byte-48);
     else if(text_byte=="|" || text_byte==";")begin
      commands[(head*8+item)*8+:8]<=number;row_counts[head*4+:4]<=item+1'b1;
      if(number<160 || number>191)descriptor_error<=1;
      buffer=0;chars=0;px=0;number=0;
      if(text_byte==";")begin head=head+1'b1;item=0;mode=0;end
      else begin item=item+1'b1;mode=1;end
     end else descriptor_error<=1;
    end else if((text_menu && text_byte=="|" && mode==0) || (text_menu && text_byte=="=" && mode==1) || (!text_menu && text_byte=="|"))begin
     if(text_menu && mode==0)begin heading_lengths[head*4+:4]<=chars[3:0];custom_count<=head+1'b1;mode=1;end
     else begin
      label_we<=1;label_waddr<=text_menu?6'(32+head*8+item):6'd2;label_wdata<=buffer;
      if(text_menu)mode=2;else about_description<=1;
     end
     buffer=0;chars=0;px=0;
    end else if(text_byte!=0)begin
     if(chars>=64 || px+classic_advance(text_byte)>640 || (text_menu && ((mode==0 && chars>=12) || (mode==1 && chars>=24))))descriptor_error<=1;
     else begin
      buffer[chars*27+:27]={10'(px+classic_advance(text_byte)),px,text_byte[6:0]};
      if(text_menu && mode==0 && head<3)headings[head*96+chars*8+:8]<=text_byte;
      chars=chars+1'b1;px=px+classic_advance(text_byte);
     end
    end
    if(text_last)begin
     if(text_menu)begin
      if(mode==2)begin commands[(head*8+item)*8+:8]<=number;row_counts[head*4+:4]<=item+1'b1;end
      bar_pending<=1;
     end else begin label_we<=1;label_waddr<=3;label_wdata<=buffer;about_valid<=1;end
     generation<=generation+1'b1;
    end
    text_buffer<=buffer;text_chars<=chars;text_x<=px;parse_mode<=mode;parse_head<=head;parse_row<=item;parse_code<=number;
   end
   // A single scalar RAM write publishes a finished proportional text row.
   // Build the menu bar after metadata/role changes, never every game frame.
   if(!text_stb)case(bar_phase)
    0:if(bar_pending)begin bar_pending<=0;bar_buffer<=0;bar_chars<=0;bar_x<=34;bar_slot<=0;bar_char<=0;bar_phase<=1;end
    1:begin
     logic [3:0] kind;
     if(window_state[7:0]==8)begin
      if(bar_slot==0)kind=0;
      else if(!has_game && bar_slot==1)kind=4;
      else if(bar_slot-1-(!has_game)<custom_count)kind=5+bar_slot-1-(!has_game);
      else kind=3;
     end else begin
      if(bar_slot<3)kind={1'b0,bar_slot};
      else if(bar_slot-3<custom_count)kind=5+bar_slot-3;
      else kind=3;
     end
     bar_kind<=kind[2:0];bar_kinds[bar_slot*4+:4]<=kind;bar_lefts[bar_slot*10+:10]<=bar_x-4;bar_char<=0;bar_phase<=2;
    end
    2:begin
     logic [7:0] c;
     c=bar_kind>=5 ? (bar_char<heading_lengths[(bar_kind-5)*4+:4]?headings[(bar_kind-5)*96+bar_char*8+:8]:8'd0):classic_char(bar_kind==3?113:bar_kind==4?114:110+bar_kind,bar_char);
     if(c==0)begin
      bar_rights[bar_slot*10+:10]<=bar_x+16;
      if(bar_kind==3)begin label_we<=1;label_waddr<=0;label_wdata<=bar_buffer;bar_count<=bar_slot+1'b1;bar_phase<=0;generation<=generation+1'b1;end
      else begin bar_x<=bar_x+20;bar_slot<=bar_slot+1'b1;bar_phase<=1;end
     end else if(bar_chars<64)begin
      bar_buffer[bar_chars*27+:27]<={10'(bar_x+classic_advance(c)),bar_x,c[6:0]};
      bar_chars<=bar_chars+1'b1;bar_x<=bar_x+classic_advance(c);bar_char<=bar_char+1'b1;
     end else begin descriptor_error<=1;bar_phase<=0;end
    end
    default:bar_phase<=0;
   endcase
   if(!text_stb && bar_phase==0 && !bar_pending)begin
    if(!title_phase)begin
     if(title_pending && source_name_len!=0 && (window_state[7:0]==1 || window_state[7:0]==2 || window_state[7:0]==5))begin
      title_pending<=0;title_phase<=1;title_char_i<=0;title_x<=0;title_buffer<=0;
     end
    end else if(title_char_i>=source_name_len || title_char_i>=16)begin
     label_we<=1;label_waddr<=1;label_wdata<=title_buffer;title_width<=title_x;title_valid<=1;
     title_phase<=0;generation<=generation+1'b1;
    end else begin
     logic [7:0] ch;
     ch=source_name[title_char_i*8+:8];
     title_buffer[title_char_i*27+:27]<={10'(title_x+classic_advance(ch)),title_x,ch[6:0]};
     title_x<=title_x+classic_advance(ch);title_char_i<=title_char_i+1'b1;
    end
   end
   if(external_label_valid && external_label_ready)begin
    label_we<=1;label_waddr<=external_label_row;label_wdata<=external_label_data;generation<=generation+1'b1;
   end
   if(sample_valid)begin
    old_buttons<=buttons;
    if(!buttons[0])capture<=0;
    if(!old_buttons[0] && buttons[0])begin
     if(x<30 && y<22)begin active_menu<=0;generation<=generation+1'b1;end
     else if(consume_pointer)begin
      capture<=1;generation<=generation+1'b1;
      if(active_menu!=0)begin
       active_menu<=0;
       if(x>=popup_left && x<popup_left+212 && y>=26 && click_row<popup_count && click_enabled)begin
        if(selected_code>=128)begin key_stb<=1;key_code<=selected_code;end
        else begin action_stb<=1;action<=selected_code[3:0];end
       end
      end else if(y<22)begin
       for(integer i=0;i<7;i=i+1)if(i<bar_count && x>=bar_lefts[i*10+:10] && x<bar_rights[i*10+:10])active_menu<=4'(i+1);
      end else if(x>=16 && x<30 && y>=40 && y<54)begin action_stb<=1;action<=0;end
      else if(x>=600 && x<620 && y>=88 && y<432)begin
       key_stb<=1;key_code<=y<108?128:y>=414?129:y<260?130:131;
      end else if(editable && y>=434 && y<453)begin
       if(x>=10 && x<28)begin key_stb<=1;key_code<=132;end
       else if(x>=582 && x<600)begin key_stb<=1;key_code<=133;end
      end
     end
    end
   end
  end
 end
endmodule
