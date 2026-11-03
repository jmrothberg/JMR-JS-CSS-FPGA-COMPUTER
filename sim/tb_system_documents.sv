`timescale 1ns/1ps
// Native Save As contract: real clocked normalizer, published names, invalid
// input and cancellation. No filesystem write or host implementation is used.
module tb_system_documents;
 logic clk=0,rst_n=0,app_clear=0;
 always #5 clk=~clk;
 logic request_stb=0,key_stb=0,key_down=0,sample_valid=0;
 logic error_pulse=0,descriptor_error=0;
 logic [7:0] key_code=0,key_char=0;
 logic [9:0] x=0;logic [8:0] y=0;logic [2:0] buttons=0;
 logic command_stb,catalog_go,catalog_done=0;
 logic [3:0] command,chosen_len,name_len;
 logic [95:0] chosen_name;
 logic [2:0] dialog;
 logic [7:0] message_id;
 integer commands=0,cases_checked=0;
 jmr_system_documents dut(
  .clk(clk),.rst_n(rst_n),.app_clear(app_clear),.window_state(32'd5),
  .source_name(128'd0),.source_len(5'd0),.unnamed(1'b1),.kernel_busy(1'b0),
  .error_pulse(error_pulse),.descriptor_error(descriptor_error),.request_stb(request_stb),.request_action(4'd4),.shortcut_save(1'b0),
  .sample_valid(sample_valid),.x(x),.y(y),.buttons(buttons),.keyboard_open(1'b0),
  .key_stb(key_stb),.key_down(key_down),.key_code(key_code),.key_char(key_char),
  .command_stb(command_stb),.command(command),.chosen_name(chosen_name),.chosen_len(chosen_len),
  .dialog(dialog),.name_len(name_len),.message_id(message_id),
  .catalog_go(catalog_go),.catalog_busy(1'b0),.catalog_done(catalog_done),
  .storage_busy(1'b0),.desktop_busy(1'b0),.catalog_count(9'd0),.catalog_data(8'd0),.label_ready(1'b1),
  .consume_pointer(),.consume_keys(),.keyboard_set_stb(),.keyboard_set_on(),.after_valid(),.after_action(),.after_name(),.after_len(),.file_count(),.selected(),.file_top(),.name_selected(),.generation(),.catalog_active(),.catalog_all(),.catalog_addr(),.label_valid(),.label_row(),.label_data(),.label_col(),.label_commit()
 );
 always @(negedge clk)begin
  catalog_done=catalog_go;
  if(!rst_n)commands=0;else if(command_stb)commands=commands+1;
 end
 task pulse_key(input logic [7:0] code,ch);
  @(negedge clk);key_stb=1;key_down=1;key_code=code;key_char=ch;
  @(negedge clk);key_stb=0;key_down=0;
 endtask
 task open_name(input string text);
  rst_n=0;request_stb=0;key_stb=0;sample_valid=0;buttons=0;app_clear=0;error_pulse=0;descriptor_error=0;
  repeat(4)@(negedge clk);rst_n=1;
  @(negedge clk);request_stb=1;@(negedge clk);request_stb=0;
  if(dialog!=2)$fatal(1,"Save As did not open");
  if(text.len()>12)$fatal(1,"test exceeds input capacity");
  for(integer i=0;i<text.len();i=i+1)pulse_key(0,8'(text.getc(i)));
 endtask
 task check_name(input string text,expected,input bit valid);
  logic [95:0] packed_expected;
  integer clocks;
  begin
   open_name(text);pulse_key(13,0);clocks=0;
   while(!command_stb && message_id!=163 && clocks<500)begin @(negedge clk);clocks=clocks+1;end
   if(clocks==500)$fatal(1,"normalizer stalled: %s",text);
   if(valid)begin
    packed_expected=0;
    for(integer i=0;i<expected.len();i=i+1)packed_expected[i*8+:8]=8'(expected.getc(i));
    if(!command_stb || command!=15 || chosen_len!=4'(expected.len()) || chosen_name!=packed_expected)
     $fatal(1,"wrong Save As name: input=%s actual=%h len=%d expected=%s command=%d message=%d",text,chosen_name,chosen_len,expected,command,message_id);
   end else begin
    if(command_stb || dialog!=2 || message_id!=163 || name_len!=4'(text.len()))$fatal(1,"invalid name accepted or input lost: %s",text);
   end
   cases_checked=cases_checked+1;
  end
 endtask
 initial begin
  check_name("  demo.html ","DEMO.HTM",1);
  check_name("LONGNAME.TXT","LONGNAME.TXT",1);
  check_name("a-b_1.md","A-B_1.MD",1);
  check_name(" A ","A",1);
  check_name("x.htm","X.HTM",1);
  check_name("code.js","CODE.JS",1);
  check_name("","",0);check_name("   ","",0);check_name(".","",0);
  check_name(".HTML","",0);check_name("NAME.","",0);
  check_name("A.LONG","",0);check_name("ABCDEFGHI","",0);
  check_name("ABC.DEF.GHI","",0);check_name("BAD NAME","",0);check_name("BAD/NAME","",0);
  // A click on Cancel must abort an in-flight normalization, not save later.
  open_name("CANCEL.TXT");pulse_key(13,0);
  @(negedge clk);x=300;y=245;buttons=1;sample_valid=1;
  @(negedge clk);buttons=0;@(negedge clk);sample_valid=0;
  repeat(150)@(negedge clk);
  if(dialog!=0 || commands!=0)$fatal(1,"Cancel published a pending save");
  open_name("ESCAPE.TXT");pulse_key(13,0);pulse_key(27,0);repeat(150)@(negedge clk);
  if(dialog!=0 || commands!=0)$fatal(1,"Escape published a pending save");
  open_name("CLEAR.TXT");pulse_key(13,0);
  @(negedge clk);app_clear=1;@(negedge clk);app_clear=0;repeat(150)@(negedge clk);
  if(dialog!=0 || commands!=0)$fatal(1,"application clear published a pending save");
  open_name("ERROR.TXT");pulse_key(13,0);
  @(negedge clk);error_pulse=1;descriptor_error=1;app_clear=1;
  @(negedge clk);error_pulse=0;descriptor_error=0;app_clear=0;repeat(150)@(negedge clk);
  if(dialog!=5 || message_id!=166 || commands!=0)$fatal(1,"error did not abort pending save or remain visible");
  $display("PASS %d filename cases, Cancel, Escape, application clear and visible error",cases_checked);$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
