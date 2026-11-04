module tb_owned_menus;
 logic clk=0,rst_n=0,app_clear=0;
 always #5 clk=~clk;
 logic text_stb=0,text_menu=0,text_title=0,text_first=0,text_last=0;
 logic [7:0] text_byte=0;logic [31:0] window_state=6;
 logic sample_valid=0;logic [9:0] x=0;logic [8:0] y=0;logic [2:0] buttons=0;
 logic [3:0] click_row=0,popup_row=0;
 logic error_,key_stb,action_stb;logic [7:0] key_code;logic [3:0] action;
 logic custom_title,title_valid;logic [9:0] title_width;
 logic [3:0] active_menu,popup_count;logic [111:0] statics;logic [97:0] dynamics;
 logic [13:0] enabled,checked;logic [9:0] left_;integer keys=0,actions=0,last_key=0,last_action=0;
 jmr_classic_ui dut(.clk,.pixel_clk(clk),.rst_n,.app_clear,.sys_we(1'b0),.sys_addr(14'd0),.sys_data(16'd0),
 .window_state,.menu_enable(32'hffffffff),.menu_check(32'h1),.source_name(128'd0),.source_name_len(5'd0),
 .external_label_valid(1'b0),.external_label_row(6'd0),.external_label_data(27'd0),.external_label_col(6'd0),.external_label_commit(1'b0),
 .text_stb,.text_menu,.text_title,.text_first,.text_last,.text_byte,.window_bars(1'b0),.custom_title,
 .sample_valid,.system_active(1'b0),.keyboard_open(1'b0),.guest_drag(1'b0),.cancel_menu(1'b0),.x,.y,.buttons,.click_row,
 .key_stb,.key_code,.action_stb,.action,.descriptor_error(error_),.active_menu,.popup_left(left_),.popup_count,.popup_row,
 .popup_static_rows(statics),.popup_dynamic_rows(dynamics),.popup_enabled_rows(enabled),.popup_checked_rows(checked),
 .label_raddr(7'd127),.label_pos(12'sd0),.beam_y(10'd0),.title_valid,.title_width);
 always @(posedge clk)begin if(key_stb)begin keys++;last_key=key_code;end if(action_stb)begin actions++;last_action=action;end end
 task automatic send_text(input string str,input integer kind);
  for(integer i=0;i<str.len();i++)begin
   @(negedge clk);text_stb=1;text_menu=kind==1;text_title=kind==2;text_first=i==0;text_last=i==str.len()-1;text_byte=str[i];
   @(negedge clk);text_stb=0;repeat(3)@(negedge clk);
  end
  repeat(1000)@(negedge clk);
  if(error_)$fatal(1,"descriptor error kind=%d text=%s",kind,str);
 endtask
 task automatic mouse(input integer px,py,b);
  @(negedge clk);x=10'(px);y=9'(py);buttons=3'(b);click_row=py>=26?4'((py-26)/21):15;sample_valid=1;
  @(negedge clk);sample_valid=0;repeat(100)@(negedge clk);
 endtask
 task automatic open_menu(input integer i);
  mouse(integer'(dut.bar_lefts[i*10+:10])+5,8,1);mouse(integer'(dut.bar_lefts[i*10+:10])+5,8,0);
  if(active_menu!=i+1)$fatal(1,"wrong menu %d",i);
 endtask
 task automatic choose(input integer row_);
  mouse(integer'(left_)+15,32+row_*21,1);mouse(integer'(left_)+15,32+row_*21,0);
 endtask
 logic [7:0] bytes_ [0:799];string spec="",menus_path;integer length_;
 initial begin
  if(!$value$plusargs("length=%d",length_))$fatal;
  if(!$value$plusargs("menus=%s",menus_path))menus_path="build/run76_usb_keyboard_pmod_mice/macpaint_menus.hex";
  $readmemh(menus_path,bytes_,0,length_-1);
  for(integer i=0;i<length_;i++)spec={spec,bytes_[i]};
  repeat(5)@(negedge clk);rst_n=1;
  send_text(spec,1);
  if(!dut.owned || dut.custom_count!=6 || dut.bar_count!=6)$fatal(1,"six owned menus not installed");
  // About and title packets must not reset menu bases or replace menu metadata.
  send_text("MacPaint|JMR Enterprises paint program.",0);
  send_text("untitled",2);
  if(!custom_title || !title_valid || title_width==0)$fatal(1,"custom title missing");
  open_menu(4);if(popup_count!=8)$fatal(1,"FontSize rows");choose(7);
  if(keys!=1 || last_key!=180)$fatal(1,"last FontSize command %d",last_key);
  open_menu(5);if(popup_count!=10 || enabled[6] || statics[6*8+:8]!=255)$fatal(1,"Style separator");choose(9);
  if(keys!=2 || last_key!=189)$fatal(1,"last Style command");
  open_menu(1);choose(11);if(last_key!=210)$fatal(1,"last Edit row");
  open_menu(2);if(!checked[0])$fatal(1,"Grid checkmark");choose(0);if(last_key!=160)$fatal;
  open_menu(0);choose(3);if(last_key!=195)$fatal(1,"Save command");
  open_menu(0);choose(8);if(actions!=1 || last_action!=0)$fatal(1,"Quit must use lifecycle");
  // Hidden scrollbar must not emit a key.
  begin integer old_keys;old_keys=keys;mouse(608,95,1);mouse(608,95,0);if(keys!=old_keys)$fatal(1,"hidden scrollbar emitted key");end
  $display("PASS exact MacPaint menus: six headings, separators, high commands, title, checks, Quit, hidden bars");$finish;
 end
endmodule
