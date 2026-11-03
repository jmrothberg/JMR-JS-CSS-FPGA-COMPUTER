// Native tool/file lifecycle. Commands use the real console keyboard/FAT path;
// document creation and naming use explicit console handshakes, never host I/O.
module jmr_system_actions (
 input logic clk,rst_n,
 input logic action_stb,
 input logic [3:0] action,
 input logic [7:0] role,
 input logic [95:0] chosen_name,
 input logic [3:0] chosen_len,
 input logic after_valid,
 input logic [3:0] after_action,
 input logic [95:0] after_name,
 input logic [3:0] after_len,
 input logic [127:0] source_name,
 input logic [4:0] source_len,
 input logic source_unnamed,
 output logic catalog_go,catalog_active,
 output logic [11:0] catalog_addr,
 input logic catalog_done,catalog_error,
 input logic [8:0] catalog_count,
 input logic [7:0] catalog_data,
 input logic [31:0] catalog_size,
 output logic stage_valid,
 output logic [12:0] stage_addr,
 output logic [7:0] stage_data,
 input logic stage_ready,
 input logic console_ready,console_failed,console_clear,keyboard_empty,keyboard_full,
 input logic vm_busy,storage_busy,disk_busy,desktop_busy,
 output logic busy,quit_pulse,halt_pulse,
 output logic desktop_stb,desktop_on,
 output logic key_push,
 output logic [7:0] key_data,
 output logic inject_stb,
 output logic [7:0] inject_code,
 output logic doc_start,doc_new,
 output logic [2:0] doc_role,
 output logic set_name,
 output logic [95:0] target_name,
 output logic [3:0] target_len,
 output logic catalog_prepared,restart_pulse,
 output logic error_pulse
);
 typedef enum logic [4:0] {IDLE,STOP,DISPATCH,SEND_WAIT,SEND,FINISH,SAVE_NAME,SAVE_KEY,SAVE_WAIT,DOC_WAIT,CAT_START,CAT_WAIT,CAT_READ,CAT_SETTLE,CAT_CAPTURE,CAT_EMIT} state_t;
 state_t state;
 logic [3:0] operation,return_action;
 logic [8:0] cat_count,cat_index;
 logic [3:0] cat_char,cat_len;
 logic [95:0] cat_name;
 logic [31:0] cat_size;
 logic [4:0] emit_i;
 logic [1:0] emit_kind;
 assign catalog_addr={cat_index[7:0],cat_char};
 logic [95:0] return_name;logic [3:0] return_len;
 logic [7:0] old_role;
 logic [2:0] command_mode;
 logic [5:0] char_i;
 logic [7:0] ready_age;
 logic need_after,return_desktop,app_seen,defer_close;
 wire idle_console=console_ready && keyboard_empty && !storage_busy && !disk_busy && !desktop_busy && !console_clear;
 function automatic logic [7:0] word_char(input integer which,i);
  case(which)
   1:case(i)0:word_char="E";1:word_char="D";2:word_char="I";3:word_char="T";default:word_char=13;endcase
   2:case(i)0:word_char="R";1:word_char="E";2:word_char="A";3:word_char="D";default:word_char=13;endcase
   3:case(i)0:word_char="R";1:word_char="U";2:word_char="N";default:word_char=13;endcase
   default:case(i)0:word_char="C";1:word_char="O";2:word_char="M";3:word_char="P";4:word_char="I";5:word_char="L";6:word_char="E";default:word_char=13;endcase
  endcase
 endfunction
 function automatic logic [7:0] load_char(input integer i);
  if(i<6)case(i)0:load_char="L";1:load_char="O";2:load_char="A";3:load_char="D";4:load_char=32;default:load_char=34;endcase
  else if(i<6+target_len)load_char=target_name[(i-6)*8+:8];
  else load_char=i==6+target_len?34:13;
 endfunction
 function automatic logic document_name(input logic [127:0] name,input logic [4:0] n);
  document_name=(n>=3 && name[(n-3)*8+:24]==24'h444d2e) || (n>=4 && name[(n-4)*8+:32]==32'h5458542e);
 endfunction
 assign busy=state!=IDLE;
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   catalog_prepared<=0;restart_pulse<=0;catalog_go<=0;catalog_active<=0;stage_valid<=0;stage_addr<=0;stage_data<=0;cat_count<=0;cat_index<=0;cat_char<=0;cat_len<=0;cat_name<=0;cat_size<=0;emit_i<=0;emit_kind<=0;return_name<=0;return_len<=0;state<=IDLE;operation<=0;return_action<=0;old_role<=0;command_mode<=0;char_i<=0;ready_age<=0;
   need_after<=0;return_desktop<=0;app_seen<=0;defer_close<=0;quit_pulse<=0;halt_pulse<=0;
   desktop_stb<=0;desktop_on<=0;key_push<=0;key_data<=0;inject_stb<=0;inject_code<=0;
   doc_start<=0;doc_new<=0;doc_role<=1;set_name<=0;target_name<=0;target_len<=0;error_pulse<=0;
  end else begin
   quit_pulse<=0;halt_pulse<=0;desktop_stb<=0;key_push<=0;inject_stb<=0;doc_start<=0;set_name<=0;error_pulse<=0;catalog_go<=0;catalog_prepared<=0;restart_pulse<=0;
   if(busy && action_stb && action==0)defer_close<=1;
   case(state)
    IDLE:begin
     if(defer_close && role!=3 && !vm_busy && idle_console)begin quit_pulse<=1;defer_close<=0;end
     if(return_desktop && vm_busy)app_seen<=1;
     if(return_desktop && app_seen && !vm_busy && idle_console)begin
      desktop_stb<=1;desktop_on<=1;return_desktop<=0;app_seen<=0;
     end
     if(action_stb)begin
      operation<=action;old_role<=role;ready_age<=0;return_desktop<=0;app_seen<=0;defer_close<=0;
      need_after<=after_valid;return_action<=after_action;return_name<=after_name;return_len<=after_len;
      if((action==0 || action==13) && role==3)begin defer_close<=1;state<=IDLE;end
      else if(action==0 || action==13)begin quit_pulse<=1;state<=IDLE;end
      else if(action==3)state<=SAVE_KEY;
      else if(action==15)begin target_name<=chosen_name;target_len<=chosen_len;state<=SAVE_NAME;end
      else begin halt_pulse<=1;state<=STOP;
       if(action==14)begin target_name<=chosen_name;target_len<=chosen_len;end
       else if(action==10)begin target_name<=96'h004d54482e5954494c495455;target_len<=11;end
       else if(action==12 || (action==8 && !document_name(source_name,source_len)))begin target_name<=96'h0000000000444d2e504c4548;target_len<=7;end
       else if(action==8 || (action==7 && !source_unnamed && source_len!=0))begin target_name<=source_name[95:0];target_len<=source_len[3:0];end
       else target_len<=0;
      end
     end
    end
    STOP:begin
     if(!vm_busy && idle_console)begin
      if(ready_age==100)begin desktop_stb<=1;desktop_on<=0;state<=DISPATCH;end
      else ready_age<=ready_age+1'b1;
     end else ready_age<=0;
    end
    DISPATCH:begin
     char_i<=0;ready_age<=0;
     if(operation==6)state<=IDLE;
     else if(operation==4)state<=CAT_START;
     else if(operation==1 || operation==11 || (operation==7 && target_len==0))begin
      doc_start<=1;doc_new<=operation!=7 || source_len==0;
      doc_role<=(operation==11 || (operation==1 && old_role==5))?3'd5:3'd1;state<=DOC_WAIT;
     end else begin
      command_mode<=operation==9?4:target_len!=0?0:2;state<=SEND_WAIT;
     end
    end
    SEND_WAIT:if(idle_console)state<=SEND;
    SEND:if(!keyboard_full)begin
     logic [7:0] ch;
     ch=command_mode==0?load_char(char_i):word_char(command_mode,char_i);
     key_push<=1;key_data<=ch;
     if(ch==13)begin ready_age<=0;state<=FINISH;end
     else begin char_i<=char_i+1'b1;state<=SEND_WAIT;end
    end
    FINISH:begin
     if(command_mode!=0 && command_mode!=4 && vm_busy)begin return_desktop<=1;app_seen<=1;state<=IDLE;end
     else if(idle_console)begin
      if(ready_age==100)begin
       ready_age<=0;
       if(console_failed)begin error_pulse<=1;state<=IDLE;end
       else if(command_mode==0)begin
        if((operation==14 && (old_role==1 || old_role==5)) || operation==7)begin
         doc_start<=1;doc_new<=0;doc_role<=operation==7?3'd1:old_role==5?3'd5:3'd1;state<=DOC_WAIT;
        end else if(operation==10)state<=CAT_START;
        else begin command_mode<=2;char_i<=0;state<=SEND_WAIT;end
       end else if(command_mode==4)begin
        if(defer_close)quit_pulse<=1;
        state<=IDLE;
       end else state<=IDLE;
      end else ready_age<=ready_age+1'b1;
     end else ready_age<=0;
    end
    CAT_START:if(idle_console)begin catalog_active<=1;catalog_go<=1;state<=CAT_WAIT;end
    CAT_WAIT:if(catalog_done)begin
     if(catalog_error)begin catalog_active<=0;error_pulse<=1;state<=IDLE;end
     else begin cat_count<=catalog_count;cat_index<=0;cat_char<=0;cat_len<=0;cat_name<=0;emit_kind<=0;emit_i<=0;stage_addr<=0;stage_valid<=0;state<=CAT_EMIT;end
    end
    CAT_READ:state<=CAT_SETTLE;
    CAT_SETTLE:state<=CAT_CAPTURE;
    CAT_CAPTURE:begin
     cat_size<=catalog_size;
     if(catalog_data==0 || cat_char==12)begin cat_len<=cat_char;emit_i<=0;emit_kind<=1;state<=CAT_EMIT;end
     else begin cat_name[cat_char*8+:8]<=catalog_data;cat_char<=cat_char+1'b1;state<=CAT_READ;end
    end
    CAT_EMIT:begin
     if(!stage_valid)begin
      stage_valid<=1;
      if(emit_kind==0)case(emit_i)0:stage_data<=85;1:stage_data<=84;2:stage_data<=76;default:stage_data<=1;endcase
      else if(emit_kind==2)stage_data<=0;
      else if(emit_i==0)stage_data<={4'd0,cat_len};
      else if(emit_i<=cat_len)stage_data<=cat_name[(emit_i-1)*8+:8];
      else stage_data<=cat_size[(emit_i-cat_len-1)*8+:8];
     end else if(stage_ready)begin
      stage_valid<=0;stage_addr<=stage_addr+1'b1;
      if(emit_kind==2)begin catalog_active<=0;catalog_prepared<=1;
       if(operation==4)begin restart_pulse<=1;state<=IDLE;end
       else begin command_mode<=3;char_i<=0;state<=SEND_WAIT;end
      end
      else if((emit_kind==0 && emit_i==3) || (emit_kind==1 && emit_i=={1'b0,cat_len}+4))begin
       emit_i<=0;cat_char<=0;cat_name<=0;
       if(emit_kind==1)cat_index<=cat_index+1'b1;
       if((emit_kind==0 && cat_count==0) || (emit_kind==1 && cat_index+1'b1>=cat_count))emit_kind<=2;
       else state<=CAT_READ;
      end else emit_i<=emit_i+1'b1;
     end
    end
    DOC_WAIT:if(vm_busy)begin return_desktop<=1;app_seen<=1;state<=IDLE;end
    SAVE_NAME:begin set_name<=1;state<=SAVE_KEY;end
    SAVE_KEY:begin inject_stb<=1;inject_code<=113;ready_age<=0;state<=SAVE_WAIT;end
    SAVE_WAIT:begin
     if(!vm_busy && idle_console)begin
      if(ready_age==100)begin
       ready_age<=0;
       if(need_after && !console_failed)begin
        operation<=return_action;need_after<=0;target_name<=return_name;target_len<=return_len;
        if(return_action==0 || return_action==13)begin quit_pulse<=1;state<=IDLE;end
        else state<=DISPATCH;
       end else begin command_mode<=1;char_i<=0;state<=SEND_WAIT;if(console_failed)error_pulse<=1;end
      end else ready_age<=ready_age+1'b1;
     end else ready_age<=0;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
