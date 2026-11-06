// Native shared menus: descriptor parsing, compact proportional text and input.
// No JS heap or framebuffer is duplicated. Text RAM has scalar write/read ports.
(* use_dsp="no" *) module jmr_classic_ui (
 input logic clk,rst_n,pixel_clk,app_clear,sys_we,
 input logic [13:0] sys_addr,
 input logic [15:0] sys_data,
 input logic [31:0] window_state,menu_enable,menu_check,
 input logic [127:0] source_name,
 input logic [4:0] source_name_len,
 input logic external_label_valid,
 input logic [5:0] external_label_row,
 input logic [26:0] external_label_data,
 input logic [5:0] external_label_col,
 input logic external_label_commit,
 output logic external_label_ready,
 input logic text_stb,text_menu,text_title,text_first,text_last,
 input logic window_bars,
 output logic custom_title,
 input logic [7:0] text_byte,
 input logic sample_valid,system_active,keyboard_open,guest_drag,cancel_menu,
 input logic [9:0] x,
 input logic [8:0] y,
 input logic [2:0] buttons,
 input logic [3:0] click_row,
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
 output logic [6:0] popup_dynamic,
 output logic popup_enabled,
 output logic [111:0] popup_static_rows,
 output logic [97:0] popup_dynamic_rows,
 output logic [13:0] popup_enabled_rows,popup_checked_rows,
 output logic [9:0] active_left,active_right,
 output logic [3:0] hover_row,
 input logic [6:0] label_raddr,
 input logic signed [11:0] label_pos,
 input logic [9:0] beam_y,
 output logic [11:0] label_glyph,
 output logic about_valid,
 output logic title_valid,
 output logic [9:0] title_width,
 // Set with action on Open... / Save As... of an owned menu. The dialog
 // then returns this command key after the shared box, instead of saving SOURCE.
 output logic [7:0] relay_key
);
 import jmr_classic_ui_pkg::*;
 (* ram_style="distributed" *) logic [15:0] sys_headings [0:39];
 initial for(integer i=0;i<40;i=i+1)sys_headings[i]={classic_char(110+i/8,(i%8)*2+1),classic_char(110+i/8,(i%8)*2)};
 always_ff @(posedge clk)if(sys_we && sys_addr>=4608 && sys_addr<4648)begin
  sys_headings[sys_addr-4608]<=sys_data;
 end
 logic record_we,length_we;
 logic [6:0] record_row,length_row;logic [5:0] record_col;
 logic [26:0] record_data;
 logic [6:0] length_data;
 logic metadata_active;
 // Predecode each metadata byte locally. One byte/clock throughput is retained;
 // only metadata publication moves by one fabric clock, never VM execution.
 logic textq_stb,textq_menu,textq_title,textq_first,textq_last;
 logic [7:0] textq_byte;
 logic textq_printable,textq_isdigit;
 logic textq_zero,textq_pipe,textq_semi,textq_equal,textq_dash;
 // Candidate: decode control characters before the parser fanout.
 wire [6:0] label_owned_row=7'(16+parse_linear);
 wire [6:0] label_legacy_row=7'(32+parse_head*8+parse_row);
 logic [3:0] textq_digit,textq_advance;
 // This 512-bit read-only table belongs in ordinary LUTs, not a RAMB18 column.
 (* rom_style="distributed" *) logic [3:0] advance_rom [0:127];
 initial for(integer i=0;i<128;i=i+1)advance_rom[i]=classic_advance(8'(i));
 always_ff @(posedge clk)begin
  if(!rst_n || app_clear)textq_stb<=0;
  else begin
   textq_stb<=text_stb;
   if(text_stb)begin
    textq_menu<=text_menu;textq_title<=text_title;textq_first<=text_first;textq_last<=text_last;
    textq_zero<=text_byte==0;textq_pipe<=text_byte=="|";
    textq_semi<=text_byte==";";textq_equal<=text_byte=="=";textq_dash<=text_byte=="-";
    textq_byte<=text_byte;textq_printable<=text_byte>=32 && text_byte<=126;
    textq_isdigit<=text_byte>=48 && text_byte<=57;
    textq_digit<=4'(text_byte-8'd48);textq_advance<=text_byte[7]?4'd8:advance_rom[text_byte[6:0]];
   end
  end
 end

 jmr_classic_labels u_labels(.clk(clk),.rst_n(rst_n),.clear(app_clear),.pixel_clk(pixel_clk),
  .finder_mode(finder),.record_we(record_we),.record_row(record_row),.record_col(record_col),.record_data(record_data),
  .length_we(length_we),.length_row(length_row),.length_data(length_data),
  .read_row(label_raddr),.read_pos(label_pos),.beam_y(beam_y),.read_glyph(label_glyph));
 logic [127:0] filename_seen;
 logic [4:0] filename_n_seen,title_char_i;
 logic title_pending,title_phase;
 logic [9:0] title_x;
 logic [6:0] text_chars,bar_chars;
 logic [9:0] text_x,bar_x;
 logic [1:0] parse_mode;logic [2:0] parse_head;logic owned;
 wire app_menus=finder || owned;logic [2:0] custom_count;
 wire finder=window_state[7:0]==9;
 logic [6:0] parse_linear;logic [41:0] menu_bases;logic [39:0] item_word;logic [4:0] item_length;
 logic [3:0] parse_row;
 logic [7:0] parse_code;
 logic parse_digit;logic [79:0] used_commands;
 logic [575:0] headings;logic [95:0] current_heading;
 logic [23:0] heading_lengths;
 logic [23:0] row_counts;
 // One local command RAM, scalar reads for both masks and dispatch.
 // [0] separator  [1] Quit/Close  [2] shared Open.../Save As...  [3] Save As...
 (* ram_style="distributed" *) logic [3:0] command_flags [0:83];
 initial for(integer i=0;i<84;i=i+1)command_flags[i]=0;
 (* ram_style="distributed" *) logic [7:0] commands [0:83];
 initial for(integer i=0;i<84;i=i+1)commands[i]=0;
 // Serialize menu-mask expansion through one command read port. This avoids
 // twelve parallel RAM reads and keeps the extra work off the VM/game path.
 logic [2:0] cached_kind;logic [31:0] cached_enable,cached_check;
 logic [3:0] mask_i;logic mask_busy;
 logic [1:0] mask_phase;logic [6:0] mask_address;logic [7:0] mask_command;
 logic [13:0] mask_enabled,mask_checked,mask_work_enabled,mask_work_checked,mask_separators,mask_work_separators;

 always_ff @(posedge clk)begin
  if(!rst_n || app_clear)begin
   cached_kind<=7;cached_enable<=0;cached_check<=0;mask_i<=0;mask_busy<=0;mask_phase<=0;mask_address<=0;mask_command<=0;
   mask_enabled<=0;mask_checked<=0;mask_separators<=0;mask_work_separators<=0;mask_work_enabled<=0;mask_work_checked<=0;
  end else if(app_menus)begin
   if(cached_kind!=menu_kind || cached_enable!=menu_enable || cached_check!=menu_check || (textq_stb && textq_last))begin
    cached_kind<=menu_kind;cached_enable<=menu_enable;cached_check<=menu_check;
    mask_i<=0;mask_busy<=1;mask_phase<=0;mask_work_enabled<=0;mask_work_checked<=0;mask_work_separators<=0;
   end else if(mask_busy)begin
    if(mask_i==14)begin mask_enabled<=mask_work_enabled;mask_checked<=mask_work_checked;mask_separators<=mask_work_separators;mask_busy<=0;end
    else case(mask_phase)
     0:begin mask_address<=7'(menu_bases[cached_kind*7+:7]+mask_i);mask_phase<=1;end
     1:begin mask_command<=commands[mask_address];mask_phase<=2;end
     2:begin
      mask_work_separators[mask_i]<=command_flags[mask_address][0];
      mask_work_enabled[mask_i]<=!command_flags[mask_address][0] && (owned || cached_enable[mask_command[4:0]]);
      mask_work_checked[mask_i]<=mask_command>=160 && mask_command<=191 && cached_check[mask_command[4:0]];mask_i<=mask_i+1'b1;mask_phase<=0;
     end
     default:mask_phase<=0;
    endcase
   end
  end
 end
 logic about_description;
 logic [7:0] old_role;
 logic bar_pending;
 logic [2:0] bar_phase,bar_slot,bar_kind,bar_count;
 logic [6:0] bar_char;
 logic [7:0] bar_c;logic [95:0] bar_heading;logic [2:0] bar_head_index;logic [3:0] bar_heading_len;
 logic [69:0] bar_lefts,bar_rights;
 logic [27:0] bar_kinds;
 logic [2:0] old_buttons;
 logic capture;
 logic [2:0] menu_kind;
 logic [7:0] selected_code;
 logic has_game;
 logic editable,click_enabled;
 // MenuSelect is a short command pipeline, independent of the VM clock.
 // Decode the latched menu, read its command RAM, then check/dispatch it.
 logic [2:0] choice_phase,choice_kind;
 logic [3:0] choice_row,choice_flags,choice_count;
 logic [7:0] choice_role,choice_builtin,choice_code;
 logic [6:0] choice_address;
 logic choice_finder,choice_owned,choice_enabled,choice_ram;
 logic [31:0] choice_mask;
 assign external_label_ready=!app_clear && !metadata_active && !text_stb && !textq_stb && bar_phase==0 && !bar_pending && !title_phase &&
  !(!custom_title && title_pending && source_name_len!=0 && (window_state[7:0]==1 || window_state[7:0]==2 || window_state[7:0]==5));
 assign editable=window_state[7:0]==1 || window_state[7:0]==5;
 always_comb begin
  has_game=0;
  for(integer h=0;h<3;h=h+1)
   if(h<custom_count && heading_lengths[h*4+:4]==4 && headings[h*96+:32]==32'h656d6147)has_game=1;
  menu_kind=active_menu==0?0:bar_kinds[(active_menu-1)*4+:3];
  popup_left=active_menu==0?0:bar_lefts[(active_menu-1)*10+:10];
  active_left=popup_left;
  active_right=active_menu==0?0:bar_rights[(active_menu-1)*10+:10];
  if(popup_left>426)popup_left=426;

  popup_static=0;popup_dynamic=127;popup_enabled=1;selected_code=0;popup_count=0;click_enabled=1;
  case(menu_kind)
   0:begin
    popup_count=window_state[7:0]==8?1:5;
    if(window_state[7:0]==8)begin popup_static=125;selected_code=0;end
    else case(popup_row)
     0:begin popup_static=120;selected_code=1;popup_enabled=editable;end
     1:begin popup_static=121;selected_code=2;popup_enabled=editable || window_state[7:0]==2;end
     2:begin popup_static=125;selected_code=0;end
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
    popup_count=row_counts[(menu_kind-5)*4+:4];popup_dynamic=7'(32+(menu_kind-5)*8+popup_row);
    selected_code=commands[5'((menu_kind-5)*8+click_row)];
   end
  endcase
  case(menu_kind)
   0:begin
    selected_code=window_state[7:0]==8?0:click_row==0?1:click_row==1?2:click_row==2?0:click_row==3?3:4;
    click_enabled=window_state[7:0]==8 || click_row==2 || (click_row==1?(editable || window_state[7:0]==2 || window_state[7:0]==3):editable);
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
  if(app_menus)begin
   popup_count=row_counts[menu_kind*4+:4];
   popup_static=0;popup_dynamic=7'd16+menu_bases[menu_kind*7+:7]+{3'd0,popup_row};
   selected_code=commands[7'(menu_bases[menu_kind*7+:7]+click_row)];
   click_enabled=selected_code>=160 && (owned || (selected_code<=191 && menu_enable[selected_code-160]));
  end
  hover_row=(x>=popup_left && x<popup_left+212 && click_row<popup_count)?click_row:4'd15;
 end
 always_comb begin
  popup_static_rows=0;popup_dynamic_rows='1;popup_enabled_rows='1;popup_checked_rows=0;
  for(integer r=0;r<14;r=r+1)begin
   case(menu_kind)
    0:begin
     popup_static_rows[r*8+:8]=window_state[7:0]==8?8'd125:8'(r==0?120:r==1?121:r==2?125:r==3?123:124);
     popup_enabled_rows[r]=window_state[7:0]==8 || r==2 || (r==1?(editable || window_state[7:0]==2 || window_state[7:0]==3):editable);
    end
    1:begin
     popup_static_rows[r*8+:8]=8'(126+r);popup_enabled_rows[r]=editable;
     if(r==0)popup_enabled_rows[r]=editable && window_state[25];
     if(r==1 || r==2 || r==4)popup_enabled_rows[r]=editable && window_state[27];
     if(r==3)popup_enabled_rows[r]=editable && window_state[26];
    end
    2:begin popup_static_rows[r*8+:8]=8'(132+r);popup_enabled_rows[r]=window_state[7:0]!=3 && window_state[7:0]!=7;end
    3:begin popup_static_rows[r*8+:8]=8'(r==7?134:135+r);popup_enabled_rows[r]=window_state[7:0]!=3;end
    4:popup_static_rows[r*8+:8]=134;
    default:popup_dynamic_rows[r*7+:7]=7'(32+(menu_kind-5)*8+r);
   endcase
   if(app_menus)begin
    popup_static_rows[r*8+:8]=0;
    popup_dynamic_rows[r*7+:7]=7'(16+menu_bases[menu_kind*7+:7]+r);
    if(mask_separators[r])begin popup_static_rows[r*8+:8]=255;popup_dynamic_rows[r*7+:7]=127;end
    popup_enabled_rows[r]=mask_enabled[r];
    popup_checked_rows[r]=mask_checked[r];
   end
  end
 end
 assign consume_pointer=window_state[7:0]!=0 && !system_active && !guest_drag &&
  !(x<30 && y<22) && !(keyboard_open && y>=296) &&
  (capture || active_menu!=0 || y<22 || (window_state[7:0]!=8 && !finder && !(x>=24 && x<600 && y>=88 && y<432)));
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   choice_phase<=0;choice_kind<=0;choice_row<=0;choice_flags<=0;choice_count<=0;
   choice_role<=0;choice_builtin<=0;choice_code<=0;choice_address<=0;choice_finder<=0;choice_owned<=0;choice_enabled<=0;choice_ram<=0;choice_mask<=0;
   record_we<=0;record_row<=0;record_col<=0;record_data<=0;length_we<=0;length_row<=0;length_data<=0;metadata_active<=0;text_chars<=0;text_x<=0;
   owned<=0;custom_title<=0;item_word<=0;item_length<=0;parse_linear<=0;menu_bases<=0;parse_digit<=0;used_commands<=0;parse_mode<=0;parse_head<=0;parse_row<=0;parse_code<=0;custom_count<=0;headings<=0;current_heading<=0;heading_lengths<=0;row_counts<=0;
   about_description<=0;about_valid<=0;old_role<=0;bar_pending<=1;bar_phase<=0;bar_slot<=0;bar_kind<=0;bar_count<=0;bar_char<=0;bar_c<=0;bar_heading<=0;bar_heading_len<=0;bar_head_index<=0;bar_x<=34;bar_chars<=0;
   bar_lefts<=0;bar_rights<=0;bar_kinds<=0;old_buttons<=0;capture<=0;active_menu<=0;
   filename_seen<=0;filename_n_seen<=0;title_pending<=0;title_phase<=0;title_x<=0;title_char_i<=0;title_valid<=0;generation<=0;descriptor_error<=0;key_stb<=0;key_code<=0;action_stb<=0;action<=0;relay_key<=0;title_width<=0;
  end else begin
   record_we<=0;length_we<=0;key_stb<=0;action_stb<=0;relay_key<=0;
   if(app_clear || old_role!=window_state[7:0])choice_phase<=0;
   else case(choice_phase)
    1:begin
     choice_enabled<=1;choice_ram<=choice_finder || choice_kind>=5;
     choice_address<=choice_finder?7'(menu_bases[choice_kind*7+:7]+choice_row):7'((choice_kind-5)*8+choice_row);
     if(choice_finder)choice_count<=row_counts[choice_kind*4+:4];
     else case(choice_kind)
      0:begin
       choice_count<=choice_role==8?1:5;
       choice_builtin<=choice_role==8?0:choice_row==0?1:choice_row==1?2:choice_row==2?0:choice_row==3?3:4;
       choice_enabled<=choice_role==8 || choice_row==2 || (choice_row==1?(choice_role==1 || choice_role==2 || choice_role==3 || choice_role==5):(choice_role==1 || choice_role==5));
      end
      1:begin
       choice_count<=6;choice_builtin<=137+choice_row;
       choice_enabled<=(choice_role==1 || choice_role==5) && (choice_row==0?choice_flags[1]:(choice_row==1 || choice_row==2 || choice_row==4)?choice_flags[3]:choice_row==3?choice_flags[2]:1'b1);
      end
      2:begin choice_count<=2;choice_builtin<=130+choice_row;choice_enabled<=choice_role!=3 && choice_role!=7;end
      3:begin choice_count<=8;choice_builtin<=6+choice_row;choice_enabled<=choice_role!=3;end
      4:begin choice_count<=1;choice_builtin<=5;end
      default:choice_count<=row_counts[(choice_kind-5)*4+:4];
     endcase
     choice_phase<=2;
    end
    2:begin choice_code<=choice_ram?commands[choice_address]:choice_builtin;choice_phase<=3;end
    3:begin
     if(choice_row<choice_count && choice_enabled && (!choice_finder || (!command_flags[choice_address][0] && (choice_owned || (choice_code>=160 && choice_code<=191 && choice_mask[choice_code[4:0]])))))begin
      if(choice_owned && command_flags[choice_address][1])begin action_stb<=1;action<=0;end
      else if(choice_owned && command_flags[choice_address][2])begin
       // Open... and Save As... use the shared boxes. The program's command
       // number is returned after the name, so the program writes the file.
       action_stb<=1;action<=command_flags[choice_address][3]?4'd4:4'd2;relay_key<=choice_code;
      end
      else if(choice_code>=128)begin key_stb<=1;key_code<=choice_code;end
      else begin action_stb<=1;action<=choice_code[3:0];end
     end
     choice_phase<=0;
    end
    default:choice_phase<=0;
   endcase
   if(source_name!=filename_seen || source_name_len!=filename_n_seen)begin
    filename_seen<=source_name;filename_n_seen<=source_name_len;title_pending<=1;
   end
   if(cancel_menu)begin active_menu<=0;generation<=generation+1'b1;end
   if(app_clear)begin
    metadata_active<=0;
    title_valid<=0;custom_title<=0;owned<=0;title_pending<=1;title_phase<=0;
    custom_count<=0;headings<=0;current_heading<=0;heading_lengths<=0;row_counts<=0;
    about_valid<=0;bar_pending<=1;bar_phase<=0;active_menu<=0;capture<=0;old_buttons<=0;descriptor_error<=0;generation<=generation+1'b1;
   end
   if(old_role!=window_state[7:0])begin
    old_role<=window_state[7:0];title_pending<=1;bar_pending<=1;active_menu<=0;capture<=0;old_buttons<=0;generation<=generation+1'b1;
   end
   if(textq_stb && !app_clear && textq_title)begin
    metadata_active<=!textq_last;
    if(!textq_printable && !(textq_first && textq_last && textq_zero))descriptor_error<=1;
    else begin
     if(!textq_zero)begin
      record_we<=1;record_row<=1;record_col<=text_chars[5:0];
      record_data<={10'(text_x+textq_advance),text_x,textq_byte[6:0]};
      text_chars<=text_chars+1'b1;text_x<=text_x+textq_advance;
     end
     if(textq_last)begin
      custom_title<=!textq_zero;title_valid<=!textq_zero;
      title_width<=textq_zero?0:text_x+textq_advance;
      length_we<=1;length_row<=1;length_data<=textq_zero?0:text_chars+1'b1;
      title_pending<=textq_zero;generation<=generation+1'b1;
     end
    end
   end
   if(textq_stb && !app_clear && !textq_title)begin
    logic [6:0] chars;
    logic [9:0] px;
    logic [1:0] mode;logic [2:0] head;logic own;logic [39:0] word_;logic [4:0] item_len;logic sep;
    logic [3:0] item;logic [6:0] linear;
    logic [7:0] number;
    logic digit,invalid,description;
    logic [79:0] used;
    logic command_write;logic [6:0] command_address;logic [7:0] command_data;
    command_write=0;command_address=0;command_data=0;own=owned;word_=item_word;item_len=item_length;sep=0;
    chars=text_chars;px=text_x;
    mode=parse_mode;head=parse_head;item=parse_row;number=parse_code;linear=parse_linear;
    digit=parse_digit;used=used_commands;invalid=textq_first?0:descriptor_error;description=about_description;
    if(textq_first)begin metadata_active<=1;bar_phase<=0;bar_pending<=1;title_phase<=0;title_pending<=1;end
    if(textq_last)metadata_active<=0;
    if(textq_first && textq_menu)begin own=0;owned<=0;custom_count<=0;row_counts<=0;heading_lengths<=0;headings<=0;end
    if(textq_first && !textq_menu)about_valid<=0;
    if(!(textq_first && textq_last && textq_zero && textq_menu) && !textq_printable)invalid=1;
    if(textq_menu && (mode==2 || (own && mode==1 && chars==1 && word_[7:0]=="-" && (textq_pipe || textq_semi))))begin
     sep=mode==1;
     if(textq_isdigit)begin
      number=(number>25 || (number==25 && textq_digit>4'd5))?8'd255:8'(number*10+textq_digit);digit=1;
     end else if(textq_pipe || textq_semi)begin
      if(!sep && (!digit || number<160 || number>(own?239:191)))invalid=1;
      else if(!sep && used[number-160])invalid=1;
      else if(!sep)used[number-160]=1;
      if(((finder || own) && linear<(own?84:32) && item<(own?14:12)) || (!finder && !own && head<3 && item<8))begin command_write=1;command_address=(finder || own)?linear:7'(head*8+item);command_data=sep?0:number;row_counts[head*4+:4]<=item+1'b1;end
      chars=0;px=0;number=0;digit=0;
      if(textq_semi)begin if(head==(own?5:finder?3:2))invalid=1;else begin head=head+1'b1;if(finder || own)menu_bases[head*7+:7]<=7'(linear+1'b1);end item=0;mode=0;end
      else begin if(item==(own?13:finder?11:7))invalid=1;else item=item+1'b1;mode=1;end
      if(finder || own)linear=linear+1'b1;
     end else invalid=1;
    end else if((textq_menu && textq_pipe && mode==0) || (textq_menu && textq_equal && mode==1) || (!textq_menu && textq_pipe))begin
     if(chars==0)invalid=1;
     if(textq_menu && mode==0)begin
      if(!finder)begin
       if(head==0 && chars==4 && current_heading[31:0]==32'h656c6946)begin own=1;owned<=1;end
       if(!own && ((chars==4 && (current_heading[31:0]==32'h656c6946 || current_heading[31:0]==32'h74696445 || current_heading[31:0]==32'h77656956)) ||
          (chars==7 && current_heading[55:0]==56'h6c616963657053)))invalid=1;
       for(integer h=0;h<6;h=h+1)if(h<head && heading_lengths[h*4+:4]==chars && headings[h*96+:96]==current_heading)invalid=1;
       if(head<6)heading_lengths[head*4+:4]<=chars[3:0];
      end
      if(finder && chars!=(head==3?7:4))invalid=1;
      custom_count<=head+1'b1;
      mode=1;
     end else begin
      if(!textq_menu && description)invalid=1;
      if(!textq_menu || ((finder || own)?linear<(own?84:32) && item<(own?14:12):head<3 && item<8))begin length_we<=1;length_row<=textq_menu?((finder || owned)?label_owned_row:label_legacy_row):7'd2;length_data<=text_chars;end
      if(textq_menu)begin item_len=chars[4:0];mode=2;digit=0;end else description=1;
     end
     chars=0;px=0;
    end else if(!textq_zero)begin
     if(chars>=64 || px+textq_advance>(textq_menu?640:335) ||
        (textq_menu && ((mode==0 && chars>=12) || (mode==1 && chars>=24))) || (!textq_menu && !description && chars>=32))invalid=1;
     else begin
      if(!textq_menu || mode==1)begin
       record_we<=1;record_row<=textq_menu?((finder || own)?7'(16+linear):7'(32+head*8+item)):description?6'd3:6'd2;record_col<=chars[5:0];
       record_data<={10'(px+textq_advance),px,textq_byte[6:0]};
      end
      if(textq_menu && mode==0 && finder && textq_byte!=classic_char(110+head,chars))invalid=1;
      if(textq_menu && mode==0 && head<6)begin
       headings[head*96+chars*8+:8]<=textq_byte;
       if(chars==0)current_heading<={88'd0,textq_byte};
       else current_heading[chars*8+:8]<=textq_byte;
      end
      if(textq_menu && mode==1 && chars==0)word_=0;
      if(textq_menu && mode==1 && chars<5)word_[chars*8+:8]=textq_byte;
      chars=chars+1'b1;px=px+textq_advance;
     end
    end
    if(textq_last)begin
     if(textq_menu)begin
      if(!(textq_first && textq_zero))begin
       sep=own && mode==1 && chars==1 && (text_chars==0?textq_dash:item_word[7:0]=="-");
       if((!sep && (mode!=2 || !digit || number<160 || number>(own?239:191))) || ((finder || own)?(linear>=(own?84:32) || item>=(own?14:12)):(head>=3 || item>=8)))invalid=1;
       else begin
        if(!sep && used[number-160])invalid=1;
        command_write=1;command_address=(finder || own)?linear:7'(head*8+item);command_data=sep?0:number;row_counts[head*4+:4]<=item+1'b1;
       end
      end
      if(finder && head!=3)invalid=1;
      bar_pending<=1;
     end else begin
      if(!description || chars==0)invalid=1;
      length_we<=1;length_row<=3;length_data<=chars;about_valid<=!invalid;
     end
     generation<=generation+1'b1;
    end
    if(command_write)begin
     commands[command_address]<=command_data;
     command_flags[command_address][0]<=sep;
     command_flags[command_address][1]<=own && ((item_len==5 && word_==40'h65736f6c43) || (item_len==4 && word_==40'h0074697551));
     // "Open." is the first five letters of Open...; "Save " is Save As...
     command_flags[command_address][2]<=own && ((item_len==7 && word_==40'h2e6e65704f) || (item_len==10 && word_==40'h2065766153));
     command_flags[command_address][3]<=own && item_len==10 && word_==40'h2065766153;
     if(sep)begin length_we<=1;length_row<=label_owned_row;length_data<=0;end
    end
    descriptor_error<=invalid;parse_digit<=digit;used_commands<=used;about_description<=description;
    item_word<=word_;item_length<=item_len;parse_linear<=linear;text_chars<=chars;text_x<=px;parse_mode<=mode;parse_head<=head;parse_row<=item;parse_code<=number;
   end
   // Packet state resets with input capture, one clock BEFORE its first byte
   // is parsed. Thus first-byte selection does not precede every parser lookup.
   // Keep descriptor_error until the registered first byte consumes it: an
   // invalid preceding packet must still produce its complete error pulse.
   if(!app_clear && text_stb && text_first)begin
    metadata_active<=1;text_chars<=0;text_x<=0;parse_mode<=0;parse_head<=0;
    item_word<=0;item_length<=0;parse_linear<=0;if(text_menu)menu_bases<=0;parse_row<=0;parse_code<=0;parse_digit<=0;used_commands<=0;about_description<=0;
   end
   // A single scalar RAM write publishes a finished proportional text row.
   // Build the menu bar after metadata/role changes, never every game frame.
   if(!app_clear && !text_stb && !textq_stb && !metadata_active)case(bar_phase)
    0:if(bar_pending)begin bar_pending<=0;bar_chars<=0;bar_x<=34;bar_slot<=0;bar_char<=0;bar_phase<=1;end
    1:begin
     logic [3:0] kind;
     if(app_menus)kind={1'b0,bar_slot};
     else if(window_state[7:0]==8)begin
      if(bar_slot==0)kind=0;
      else if(!has_game && bar_slot==1)kind=4;
      else if(bar_slot-1-(!has_game)<custom_count)kind=5+bar_slot-1-(!has_game);
      else kind=3;
     end else begin
      if(bar_slot<3)kind={1'b0,bar_slot};
      else if(bar_slot-3<custom_count)kind=5+bar_slot-3;
      else kind=3;
     end
     bar_kind<=kind[2:0];bar_kinds[bar_slot*4+:4]<=kind;bar_lefts[bar_slot*10+:10]<=bar_x-4;bar_char<=0;bar_phase<=4;
    end
    4:begin bar_head_index<=owned?bar_kind:bar_kind-3'd5;bar_phase<=5;end
    5:begin
     case(bar_head_index)
      0:begin bar_heading<=headings[0+:96];bar_heading_len<=heading_lengths[0+:4];end
      1:begin bar_heading<=headings[96+:96];bar_heading_len<=heading_lengths[4+:4];end
      2:begin bar_heading<=headings[192+:96];bar_heading_len<=heading_lengths[8+:4];end
      3:begin bar_heading<=headings[288+:96];bar_heading_len<=heading_lengths[12+:4];end
      4:begin bar_heading<=headings[384+:96];bar_heading_len<=heading_lengths[16+:4];end
      default:begin bar_heading<=headings[480+:96];bar_heading_len<=heading_lengths[20+:4];end
     endcase
     bar_phase<=2;
    end
    2:begin
     bar_c<=(owned || bar_kind>=5) ?
      (bar_char<bar_heading_len?bar_heading[bar_char[3:0]*8+:8]:8'd0):
      sys_headings[{bar_kind,3'b0}+6'(bar_char>>1)][bar_char[0]*8+:8];
     bar_phase<=3;
    end
    3:begin
     logic [7:0] c;
     c=bar_c;
     if(c==0)begin
      bar_rights[bar_slot*10+:10]<=bar_x+16;
      if(owned?(bar_slot+1'b1>=custom_count):bar_kind==3)begin length_we<=1;length_row<=0;length_data<=bar_chars;bar_count<=bar_slot+1'b1;bar_phase<=0;generation<=generation+1'b1;end
      else begin bar_x<=bar_x+20;bar_slot<=bar_slot+1'b1;bar_phase<=1;end
     end else if(bar_chars<64)begin
      record_we<=1;record_row<=0;record_col<=bar_chars[5:0];record_data<={10'(bar_x+classic_advance(c)),bar_x,c[6:0]};
      bar_chars<=bar_chars+1'b1;bar_x<=bar_x+classic_advance(c);bar_char<=bar_char+1'b1;bar_phase<=2;
     end else begin descriptor_error<=1;bar_phase<=0;end
    end
    default:bar_phase<=0;
   endcase
   if(!app_clear && !text_stb && !textq_stb && !metadata_active && bar_phase==0 && !bar_pending)begin
    if(!title_phase)begin
     if(!custom_title && title_pending && source_name_len!=0 && (window_state[7:0]==1 || window_state[7:0]==2 || window_state[7:0]==5))begin
      title_pending<=0;title_phase<=1;title_char_i<=0;title_x<=0;
     end
    end else if(title_char_i>=source_name_len || title_char_i>=16)begin
     length_we<=1;length_row<=1;length_data<={2'd0,title_char_i};title_width<=title_x;title_valid<=1;
     title_phase<=0;generation<=generation+1'b1;
    end else begin
     logic [7:0] ch;
     ch=source_name[title_char_i*8+:8];
     record_we<=1;record_row<=1;record_col<={1'b0,title_char_i};record_data<={10'(title_x+classic_advance(ch)),title_x,ch[6:0]};
     title_x<=title_x+classic_advance(ch);title_char_i<=title_char_i+1'b1;
    end
   end
   if(external_label_valid && external_label_ready)begin
    if(external_label_commit)begin length_we<=1;length_row<=external_label_row;length_data<=external_label_data[6:0];end
    else begin record_we<=1;record_row<=external_label_row;record_col<=external_label_col;record_data<=external_label_data;end
    generation<=generation+1'b1;
   end
   if(sample_valid)begin
    old_buttons<=buttons;
    if(!buttons[0])capture<=0;
    if(active_menu!=0)begin
     generation<=generation+1'b1;
     if(buttons[0] && y<22)begin
      for(integer i=0;i<7;i=i+1)if(i<bar_count && x>=bar_lefts[i*10+:10] && x<bar_rights[i*10+:10])active_menu<=4'(i+1);
     end
     if(old_buttons[0] && !buttons[0])begin
      if(x>=popup_left && x<popup_left+212 && y>=26)begin
       active_menu<=0;choice_phase<=1;choice_kind<=menu_kind;choice_row<=click_row;
       choice_role<=window_state[7:0];choice_flags<=window_state[27:24];choice_finder<=app_menus;choice_owned<=owned;choice_mask<=menu_enable;
      end else if(!(y<22 && x>=active_left && x<active_right))active_menu<=0;
     end
    end else if(!old_buttons[0] && buttons[0])begin
     if(x<30 && y<22)begin active_menu<=0;generation<=generation+1'b1;end
     else if(consume_pointer)begin
      capture<=1;generation<=generation+1'b1;
      if(y<22)begin
       for(integer i=0;i<7;i=i+1)if(i<bar_count && x>=bar_lefts[i*10+:10] && x<bar_rights[i*10+:10])active_menu<=4'(i+1);
      end else if(x>=16 && x<30 && y>=40 && y<54)begin action_stb<=1;action<=0;end
      else if(window_bars && x>=600 && x<620 && y>=88 && y<432)begin
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
