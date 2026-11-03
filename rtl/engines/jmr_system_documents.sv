// Shared native document dialogs. Reuses the existing FAT catalog client and
// compile/source save path; only UI filenames and proportional labels live here.
module jmr_system_documents (
 input logic clk,rst_n,app_clear,
 input logic [31:0] window_state,
 input logic [127:0] source_name,
 input logic [4:0] source_len,
 input logic unnamed,kernel_busy,error_pulse,descriptor_error,
 input logic request_stb,
 input logic [3:0] request_action,
 input logic shortcut_save,
 input logic sample_valid,
 input logic [9:0] x,
 input logic [8:0] y,
 input logic [2:0] buttons,
 input logic keyboard_open,key_stb,key_down,
 input logic [7:0] key_code,key_char,
 output logic consume_pointer,consume_keys,
 output logic keyboard_set_stb,keyboard_set_on,
 output logic command_stb,
 output logic [3:0] command,
 output logic [95:0] chosen_name,
 output logic [3:0] chosen_len,
 output logic after_valid,
 output logic [3:0] after_action,
 output logic [95:0] after_name,
 output logic [3:0] after_len,
 output logic [2:0] dialog,
 output logic [8:0] file_count,selected,
 output logic [7:0] file_top,
 output logic [3:0] name_len,
 output logic name_selected,
 output logic [7:0] message_id,
 output logic [31:0] generation,
 output logic catalog_go,catalog_active,catalog_all,
 output logic [11:0] catalog_addr,
 input logic catalog_busy,catalog_done,storage_busy,desktop_busy,
 input logic [8:0] catalog_count,
 input logic [7:0] catalog_data,
 output logic label_valid,
 output logic [5:0] label_row,
 output logic [26:0] label_data,
 output logic [5:0] label_col,
 output logic label_commit,
 input logic label_ready
);
 import jmr_classic_ui_pkg::*;
 localparam logic [2:0] D_OPEN=1,D_NAME=2,D_CHANGES=3,D_REPLACE=4,D_MESSAGE=5;
 logic [95:0] edit_name,candidate_name,pending_name;
 logic [3:0] candidate_len,pending_len,pending_action;
 logic keyboard_saved,keyboard_forced;
 logic [2:0] old_buttons;
 logic [1:0] old_notice;
 logic name_dirty,list_dirty;
 logic [3:0] cat_phase;
 logic [8:0] cat_index,filtered_count,raw_count;
 logic [3:0] cat_char,cat_name_len;
 logic [95:0] cat_name;
 logic [31:0] cat_tail;
 logic cat_all;
 logic file_we;
 logic [7:0] file_waddr,file_raddr;
 logic [99:0] file_wdata,file_rdata;
 (* ram_style="distributed" *) logic [99:0] filenames [0:255];
 always_ff @(posedge clk)begin
  if(file_we)filenames[file_waddr]<=file_wdata;
  file_rdata<=filenames[file_raddr];
 end
 logic [3:0] op_phase;
 // Filename normalization runs a byte per clock. Trimming, case conversion,
 // suffix handling and validation must not form one long 100MHz logic path.
 logic [3:0] norm_index,norm_first,norm_last,norm_dot;
 logic norm_found,norm_valid;
 logic [39:0] norm_tail;
 logic [8:0] verify_index;
 logic [2:0] build_phase,build_row;
 logic build_list;
 logic [95:0] build_name;
 logic [3:0] build_len,build_char;
 logic [9:0] build_x;
 wire editable=window_state[7:0]==1 || window_state[7:0]==5;
 wire dirty=editable && window_state[24];
 assign consume_keys=dialog!=0;
 assign consume_pointer=dialog!=0 && !(dialog==D_NAME && y>=296);
 assign catalog_all=cat_all;
 assign catalog_addr={cat_index[7:0],cat_char};
 function automatic logic [7:0] upper(input logic [7:0] c);
  upper=(c>=97 && c<=122)?c-32:c;
 endfunction
 function automatic logic name_char(input logic [7:0] ch);
  case(ch)
   36,37,39,45,95,64,126,96,33,40,41,123,125,94,35,38:name_char=1;
   default:name_char=(ch>=65 && ch<=90) || (ch>=48 && ch<=57);
  endcase
 endfunction
 task automatic restore_keyboard;
  begin
   if(keyboard_forced)begin keyboard_set_stb<=1;keyboard_set_on<=keyboard_saved;keyboard_forced<=0;end
  end
 endtask
 task automatic show_name;
  begin
   dialog<=D_NAME;edit_name<=source_name[95:0];name_len<=source_len>12?4'd12:source_len[3:0];
   name_selected<=1;name_dirty<=1;message_id<=148;
   if(!keyboard_forced)keyboard_saved<=keyboard_open;
   keyboard_forced<=1;keyboard_set_stb<=1;keyboard_set_on<=1;
   cat_phase<=1;cat_all<=1;file_count<=0;
   generation<=generation+1'b1;
  end
 endtask
 task automatic pass_command(input logic [3:0] value);
  begin command_stb<=1;command<=value;dialog<=0;generation<=generation+1'b1;end
 endtask
 task automatic request(input logic [3:0] value);
  begin
   after_valid<=0;
   if(value==2)begin
    dialog<=D_OPEN;cat_phase<=1;cat_all<=0;file_count<=0;selected<=511;file_top<=0;generation<=generation+1'b1;
   end else if(value==3)begin if(unnamed)show_name();else pass_command(3);end
   else if(value==4)show_name();
   else if(dirty && value!=5)begin pending_action<=value;dialog<=D_CHANGES;generation<=generation+1'b1;end
   else pass_command(value);
  end
 endtask
 task automatic save_name_request;
  begin
   if(op_phase==0)begin
    candidate_name<=0;candidate_len<=0;norm_index<=0;norm_first<=0;norm_last<=0;
    norm_found<=0;norm_valid<=0;norm_tail<=0;norm_dot<=15;op_phase<=7;
   end
  end
 endtask
 task automatic send_save_name;
  begin
   chosen_name<=candidate_name;chosen_len<=candidate_len;pass_command(15);restore_keyboard();op_phase<=0;
  end
 endtask
 task automatic dirty_choice(input logic save);
  begin
   if(save)begin
    after_valid<=1;after_action<=pending_action;after_name<=pending_name;after_len<=pending_len;
    if(unnamed)show_name();else pass_command(3);
   end else begin chosen_name<=pending_name;chosen_len<=pending_len;after_valid<=0;pass_command(pending_action);end
  end
 endtask
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   dialog<=0;generation<=0;command_stb<=0;command<=0;chosen_name<=0;chosen_len<=0;
   after_valid<=0;after_action<=0;after_name<=0;after_len<=0;
   edit_name<=0;candidate_name<=0;candidate_len<=0;pending_name<=0;pending_len<=0;pending_action<=0;
   keyboard_saved<=0;keyboard_forced<=0;keyboard_set_stb<=0;keyboard_set_on<=0;
   old_buttons<=0;old_notice<=0;name_dirty<=0;list_dirty<=0;name_len<=0;name_selected<=0;message_id<=0;
   catalog_go<=0;catalog_active<=0;cat_phase<=0;cat_index<=0;cat_char<=0;cat_name_len<=0;cat_name<=0;cat_tail<=0;cat_all<=0;
   filtered_count<=0;raw_count<=0;file_count<=0;file_top<=0;selected<=511;file_we<=0;file_waddr<=0;file_wdata<=0;file_raddr<=0;
   norm_index<=0;norm_first<=0;norm_last<=0;norm_dot<=15;norm_found<=0;norm_valid<=0;norm_tail<=0;
   op_phase<=0;verify_index<=0;build_phase<=0;build_row<=0;build_list<=0;build_name<=0;build_len<=0;build_char<=0;build_x<=0;
   label_valid<=0;label_row<=0;label_data<=0;label_col<=0;label_commit<=0;
  end else begin
   command_stb<=0;keyboard_set_stb<=0;catalog_go<=0;file_we<=0;
   if(label_valid && label_ready)begin label_valid<=0;generation<=generation+1'b1;end
   if(app_clear)begin dialog<=0;after_valid<=0;old_buttons<=0;op_phase<=0;generation<=generation+1'b1;end
   if(request_stb && (!kernel_busy || (window_state[7:0]==3 && request_action==0)))request(request_action);
   if(shortcut_save && dialog==0 && !kernel_busy)request(3);
   if(error_pulse)begin op_phase<=0;dialog<=D_MESSAGE;message_id<=descriptor_error?166:164;generation<=generation+1'b1;end
   old_notice<=window_state[29:28];
   if(editable && window_state[29:28]!=0 && old_notice!=window_state[29:28])begin
    dialog<=D_MESSAGE;message_id<=window_state[29:28]==1?161:162;generation<=generation+1'b1;
   end
   // Serialize the existing directory client's registered catalog port.
   case(cat_phase)
    0:;
    1:if(!catalog_busy && !storage_busy && !desktop_busy)begin catalog_go<=1;catalog_active<=1;cat_phase<=2;end
    2:if(catalog_done)begin raw_count<=catalog_count;cat_index<=0;cat_char<=0;cat_name<=0;cat_name_len<=0;cat_tail<=0;filtered_count<=0;cat_phase<=3;end
    3:begin
     if(cat_index>=raw_count)begin
      file_count<=filtered_count;selected<=filtered_count==0?9'd511:9'd0;file_top<=0;list_dirty<=1;catalog_active<=0;cat_phase<=0;
     end else cat_phase<=4;
    end
    4:cat_phase<=5;
    5:begin
     logic [95:0] name;
     logic [3:0] n;
     logic [31:0] tail;
     logic keep;
     name=cat_name;n=cat_name_len;tail=cat_tail;
     if(catalog_data!=0 && cat_char<12)begin name[cat_char*8+:8]=catalog_data;n=n+1'b1;tail={tail[23:0],catalog_data};end
     if(catalog_data==0 || cat_char==11)begin
      keep=cat_all || tail[23:0]==24'h2e4d44 || tail==32'h2e545854 ||
            (window_state[7:0]!=2 && (tail==32'h2e48544d || tail[23:0]==24'h2e4a53));
      if(keep && filtered_count<256)begin file_we<=1;file_waddr<=filtered_count[7:0];file_wdata<={n,name};filtered_count<=filtered_count+1'b1;end
      cat_index<=cat_index+1'b1;cat_char<=0;cat_name<=0;cat_name_len<=0;cat_tail<=0;cat_phase<=3;
     end else begin cat_name<=name;cat_name_len<=n;cat_tail<=tail;cat_char<=cat_char+1'b1;cat_phase<=4;end
    end
    default:cat_phase<=0;
   endcase
   // One small text builder supplies labels for the shared pixel renderer.
   if(!label_valid && (op_phase==0 || build_phase!=0))case(build_phase)
    0:begin
     if(name_dirty && (dialog==D_NAME || dialog==D_REPLACE))begin
      name_dirty<=0;build_list<=0;build_name<=edit_name;build_len<=name_len;build_char<=0;build_x<=0;build_phase<=3;
     end else if(list_dirty && dialog==D_OPEN && cat_phase==0)begin
      list_dirty<=0;build_list<=1;build_row<=0;file_raddr<=file_top;build_phase<=1;
     end
    end
    1:build_phase<=2;
    2:begin
     build_name<=file_rdata[95:0];build_len<=({1'b0,file_top}+{6'd0,build_row})<file_count?file_rdata[99:96]:4'd0;
     build_char<=0;build_x<=0;build_phase<=3;
    end
    3:begin
     logic [7:0] ch;
     if(!label_valid)begin
      label_valid<=1;label_row<=build_list?6'd6+{3'd0,build_row}:6'd4;label_col<={2'd0,build_char};
      if(build_char>=build_len)begin label_commit<=1;label_data<={23'd0,build_len};build_phase<=4;end
      else begin
       ch=build_name[build_char*8+:8];label_commit<=0;label_data<={10'(build_x+classic_advance(ch)),build_x,ch[6:0]};
       build_x<=build_x+classic_advance(ch);build_char<=build_char+1'b1;
      end
     end
    end
    4:if(!label_valid)begin
     if(build_list && build_row<6)begin build_row<=build_row+1'b1;file_raddr<=file_top+{5'd0,build_row}+1'b1;build_phase<=1;end
     else build_phase<=0;
    end
    default:build_phase<=0;
   endcase
   // Open a selected real file, or check the Save As target for overwrite.
   if(!app_clear && !error_pulse)case(op_phase)
    0:;
    1:if(build_phase==0 && !label_valid)begin file_raddr<=selected[7:0];op_phase<=2;end
    2:op_phase<=3;
    3:begin
     pending_name<=file_rdata[95:0];pending_len<=file_rdata[99:96];pending_action<=14;op_phase<=0;
     if(dirty)begin dialog<=D_CHANGES;generation<=generation+1'b1;end
     else begin chosen_name<=file_rdata[95:0];chosen_len<=file_rdata[99:96];pass_command(14);end
    end
    4:if(cat_phase==0 && build_phase==0 && !label_valid)begin
     if((candidate_name==source_name[95:0] && candidate_len==source_len) || verify_index>=file_count)send_save_name();
     else begin file_raddr<=verify_index[7:0];op_phase<=5;end
    end
    5:op_phase<=6;
    6:begin
     if(file_rdata[95:0]==candidate_name && file_rdata[99:96]==candidate_len)begin dialog<=D_REPLACE;op_phase<=0;generation<=generation+1'b1;end
     else begin verify_index<=verify_index+1'b1;op_phase<=4;end
    end
    7:begin
     // Find the first and last non-space bytes in the original input.
     if(norm_index<name_len && edit_name[norm_index*8+:8]!=8'd32)begin
      if(!norm_found)begin norm_first<=norm_index;norm_found<=1;end
      norm_last<=norm_index+1'b1;
     end
     if(norm_index==11)begin norm_index<=0;op_phase<=8;end
     else norm_index<=norm_index+1'b1;
    end
    8:begin candidate_len<=norm_found?norm_last-norm_first:4'd0;norm_index<=0;op_phase<=9;end
    9:begin
     logic [7:0] ch;
     ch=upper(edit_name[4'(norm_first+norm_index)*8+:8]);
     if(norm_index<candidate_len)begin
      candidate_name[norm_index*8+:8]<=ch;norm_tail<={norm_tail[31:0],ch};
      if(norm_index+1'b1>=candidate_len)op_phase<=10;
      else norm_index<=norm_index+1'b1;
     end else op_phase<=10;
    end
    10:begin
     // FAT short names use .HTM; the rolling tail avoids a variable wide mux.
     if(candidate_len>=5 && norm_tail==40'h2e48544d4c)begin
      candidate_name[4'(candidate_len-4'd1)*8+:8]<=0;candidate_len<=candidate_len-1'b1;
     end
     norm_index<=0;norm_dot<=15;norm_valid<=candidate_len!=0;op_phase<=11;
    end
    11:begin
     logic [7:0] ch;
     ch=candidate_name[norm_index*8+:8];
     if(norm_index<candidate_len)begin
      if(ch==8'd46)begin if(norm_dot!=15)norm_valid<=0;norm_dot<=norm_index;end
      else if(!name_char(ch))norm_valid<=0;
     end
     if(norm_index==11)op_phase<=12;else norm_index<=norm_index+1'b1;
    end
    12:begin
     if(!norm_valid || candidate_len==0 || norm_dot==0 ||
        (norm_dot==15 && candidate_len>8) ||
        (norm_dot!=15 && (norm_dot>8 || {1'b0,candidate_len}=={1'b0,norm_dot}+5'd1 ||
         ({1'b0,candidate_len}-{1'b0,norm_dot}-5'd1)>5'd3)))begin
      message_id<=163;generation<=generation+1'b1;op_phase<=0;
     end else begin verify_index<=0;op_phase<=4;end
    end
    default:op_phase<=0;
   endcase
   if(sample_valid)begin
    old_buttons<=buttons;
    if(!old_buttons[0] && buttons[0] && dialog!=0)begin
     generation<=generation+1'b1;
     case(dialog)
      D_OPEN:begin
       if(x>=134 && x<484 && y>=112 && y<224)begin
        if({1'b0,file_top}+9'((y-112)/16)<file_count)selected<={1'b0,file_top}+9'((y-112)/16);
       end else if(x>=486 && x<508 && y>=112 && y<224)begin
        if(y<168 && file_top!=0)file_top<=file_top-1'b1;
        else if(y>=168 && file_count>7 && {1'b0,file_top}<file_count-7)file_top<=file_top+1'b1;
        list_dirty<=1;
       end else if(x>=386 && x<498 && y>=244 && y<268 && selected<file_count)op_phase<=1;
       else if(x>=260 && x<372 && y>=244 && y<268)dialog<=0;
      end
      D_NAME:begin
       if(x>=376 && x<486 && y>=234 && y<260)save_name_request();
       else if(x>=250 && x<360 && y>=234 && y<260)begin dialog<=0;after_valid<=0;op_phase<=0;restore_keyboard();end
       else if(x>=152 && x<487 && y>=158 && y<183)name_selected<=1;
      end
      D_CHANGES:begin
       if(x>=144 && x<244 && y>=234 && y<260)dirty_choice(1);
       else if(x>=266 && x<366 && y>=234 && y<260)dirty_choice(0);
       else if(x>=388 && x<488 && y>=234 && y<260)begin dialog<=0;after_valid<=0;end
      end
      D_REPLACE:begin
       if(x>=376 && x<486 && y>=234 && y<260)send_save_name();
       else if(x>=250 && x<360 && y>=234 && y<260)begin dialog<=0;after_valid<=0;op_phase<=0;restore_keyboard();end
      end
      D_MESSAGE:if(x>=270 && x<370 && y>=234 && y<260)dialog<=0;
      default:;
     endcase
    end
   end
   if(key_stb && key_down && dialog!=0)begin
    generation<=generation+1'b1;
    if(key_code==27)begin dialog<=0;after_valid<=0;op_phase<=0;restore_keyboard();end
    else if(dialog==D_NAME && op_phase==0)begin
     if(key_code==13)save_name_request();
     else if(key_code==8 || key_code==127 || (key_code==46 && key_char==0))begin
      if(name_selected)begin name_len<=0;edit_name<=0;end
      else if(name_len!=0)begin name_len<=name_len-1'b1;edit_name[(name_len-1)*8+:8]<=0;end
      name_selected<=0;name_dirty<=1;
     end else if(key_char>=32 && key_char<127)begin
      if(name_selected)begin edit_name<={88'd0,key_char};name_len<=1;end
      else if(name_len<12)begin edit_name[name_len*8+:8]<=key_char;name_len<=name_len+1'b1;end
      name_selected<=0;name_dirty<=1;
     end
    end else if(dialog==D_OPEN)begin
     if(key_code==13 && selected<file_count)op_phase<=1;
     else if(key_code==38 && selected>0 && selected<file_count)begin selected<=selected-1'b1;if(selected=={1'b0,file_top})begin file_top<=file_top-1'b1;list_dirty<=1;end end
     else if(key_code==40 && selected+1<file_count)begin selected<=selected+1'b1;if(selected>={1'b0,file_top}+6)begin file_top<=file_top+1'b1;list_dirty<=1;end end
    end else if(key_code==13)begin
     if(dialog==D_CHANGES)dirty_choice(1);
     else if(dialog==D_REPLACE)send_save_name();
     else if(dialog==D_MESSAGE)dialog<=0;
    end
   end
  end
 end
endmodule
