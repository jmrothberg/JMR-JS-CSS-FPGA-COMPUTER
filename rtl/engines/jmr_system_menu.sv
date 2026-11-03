// Always-on menu and on-screen keyboard controller. No framebuffer/heap.
// Generated key events pass through the same FIFO and VM as physical keys.
module jmr_system_menu (
 input logic clk,rst_n,
 input logic sample_valid,
 input logic inject_stb,leave_app,
 input logic force_keyboard_stb,force_keyboard_on,dismiss_about,dismiss_menu,
 input logic [7:0] inject_code,
 output logic guest_drag_o,
 input logic emit_enable,
 input logic [9:0] x,
 input logic [8:0] y,
 input logic [2:0] buttons,
 input logic [7:0] key_hit,
 output logic consume_pointer,
 output logic menu_open,keyboard_open,about_open,shift_on,caps_on,ctrl_on,alt_on,
 output logic [6:0] pressed_index,
 output logic hold_keys,
 output logic [69:0] held_keys,
 output logic [31:0] generation,
 output logic quit_pulse,terminal_pulse,
 output logic key_stb,key_down,
 output logic [7:0] key_code_o,key_char_o,
 output logic ascii_stb,
 output logic [7:0] ascii_data
);
 import jmr_system_menu_pkg::*;
 // Compact, read-only key tables stay in ordinary LUTs near their consumers.
 // A RAMB18 address mux must not include the entire mouse/control decision.
 (* rom_style="distributed" *) logic [7:0] code_plain [0:127],code_shift [0:127];
 (* rom_style="distributed" *) logic [7:0] text_plain [0:127],text_shift [0:127],text_caps [0:127],text_both [0:127];
 initial for(integer i=0;i<128;i=i+1)begin
  code_plain[i]=key_code(i,1'b0);code_shift[i]=key_code(i,1'b1);
  text_plain[i]=key_text(i,1'b0,1'b0);text_shift[i]=key_text(i,1'b1,1'b0);
  text_caps[i]=key_text(i,1'b0,1'b1);text_both[i]=key_text(i,1'b1,1'b1);
 end
 function automatic logic [7:0] local_key_code(input logic [6:0] index,input logic shifted);
  local_key_code=shifted?code_shift[index]:code_plain[index];
 endfunction
 function automatic logic [7:0] local_key_text(input logic [6:0] index,input logic shifted,caps);
  case({caps,shifted})
   0:local_key_text=text_plain[index];1:local_key_text=text_shift[index];
   2:local_key_text=text_caps[index];default:local_key_text=text_both[index];
  endcase
 endfunction

 logic inject_release;
 logic [7:0] inject_release_code;
 assign guest_drag_o=guest_drag;
 logic [2:0] old_buttons;
 logic guest_drag,held;
 logic [7:0] held_code;
 logic [6:0] wp,rp;
 logic [7:0] count;
 logic put;
 logic [16:0] put_data;
 logic [3:0] cooldown;
 logic [1:0] release_mods;
 logic [6:0] release_walk;
 logic [7:0] held_f9,held_f10;
 (* ram_style="distributed" *)logic [16:0] keys [0:127];
 wire pop=count!=0 && cooldown==0 && emit_enable;
 wire [16:0] head=keys[rp];
 assign consume_pointer=!guest_drag && (about_open || menu_open || (x<30 && y<22) || (keyboard_open && y>=296) || held);
 always_ff @(posedge clk)if(put)keys[wp]<=put_data;
 always_ff @(posedge clk)begin
  if(!rst_n)begin
   inject_release<=0;inject_release_code<=0;old_buttons<=0;guest_drag<=0;held<=0;held_code<=0;
   menu_open<=0;keyboard_open<=0;about_open<=0;shift_on<=0;caps_on<=0;ctrl_on<=0;alt_on<=0;pressed_index<=127;generation<=0;hold_keys<=0;held_keys<=0;release_walk<=127;held_f9<=120;held_f10<=121;
   quit_pulse<=0;terminal_pulse<=0;key_stb<=0;key_down<=0;key_code_o<=0;key_char_o<=0;
   ascii_stb<=0;ascii_data<=0;wp<=0;rp<=0;count<=0;put<=0;put_data<=0;cooldown<=0;release_mods<=0;
  end else begin
   put<=0;key_stb<=0;ascii_stb<=0;quit_pulse<=0;terminal_pulse<=0;
   case({put,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
   if(put)wp<=wp+1'b1;
   if(cooldown!=0)cooldown<=cooldown-1'b1;
   if(pop)begin
    rp<=rp+1'b1;cooldown<=12;
    key_stb<=1;key_code_o<=head[8:1];key_down<=head[0];
    key_char_o<=(head[16:9]>=32 && head[16:9]<127)?head[16:9]:8'd0;
    if(head[0] && head[16:9]!=0)begin ascii_stb<=1;ascii_data<=head[16:9];end
   end
   if(release_mods!=0 && !put && count<126)begin
    case(release_mods)
     1:begin if(shift_on)begin put<=1;put_data<={8'd0,8'd16,1'b0};end shift_on<=0;release_mods<=2;end
     2:begin if(ctrl_on)begin put<=1;put_data<={8'd0,8'd17,1'b0};end ctrl_on<=0;release_mods<=3;end
     3:begin if(alt_on)begin put<=1;put_data<={8'd0,8'd18,1'b0};end alt_on<=0;release_mods<=0;end
     default:;
    endcase
   end
   if(release_walk!=127 && release_mods==0 && !put && count<126)begin
    if(release_walk<70)begin
     if(held_keys[release_walk])begin
      put<=1;put_data<={8'd0,(release_walk==68?held_f9:release_walk==69?held_f10:local_key_code(release_walk,1'b0)),1'b0};
      held_keys[release_walk]<=0;generation<=generation+1'b1;
     end
     release_walk<=release_walk+1'b1;
    end else release_walk<=127;
   end
   if(force_keyboard_stb)begin keyboard_open<=force_keyboard_on;generation<=generation+1'b1;end
   if(dismiss_about)begin about_open<=0;generation<=generation+1'b1;end
   if(dismiss_menu)begin menu_open<=0;generation<=generation+1'b1;end
   if(leave_app)begin release_mods<=1;release_walk<=0;hold_keys<=0;keyboard_open<=0;menu_open<=0;about_open<=0;guest_drag<=0;end
   if(inject_stb && !put && count<124 && !inject_release)begin
    put<=1;put_data<={8'd0,inject_code,1'b1};inject_release<=1;inject_release_code<=inject_code;
   end else if(inject_release && !put && count<126)begin put<=1;put_data<={8'd0,inject_release_code,1'b0};inject_release<=0;end
   if(sample_valid)begin
    old_buttons<=buttons;
    if(!old_buttons[0] && buttons[0] && !consume_pointer)guest_drag<=1;
    if(old_buttons[0] && !buttons[0])begin
     guest_drag<=0;
     if(held)begin put<=1;put_data<={8'd0,held_code,1'b0};held<=0;pressed_index<=127;generation<=generation+1'b1;end
    end
    if(consume_pointer && !old_buttons[0] && buttons[0])begin
     generation<=generation+1'b1;
     if(about_open)begin
      if(x>=273 && x<369 && y>=269 && y<296)about_open<=0;
     end else if(menu_open)begin
      menu_open<=0;
      if(x<190 && y>=26 && y<68)begin
       if(y<47)about_open<=1;
       else begin keyboard_open<=!keyboard_open;if(!keyboard_open)terminal_pulse<=1;else begin release_mods<=1;release_walk<=0;hold_keys<=0;end end
      end
     end else if(x<30 && y<22)menu_open<=1;
     else if(keyboard_open && y>=296)begin
      if(x>=600 && y<313)begin keyboard_open<=0;release_mods<=1;release_walk<=0;hold_keys<=0;end
      else if(x>=420 && x<585 && y<313)begin hold_keys<=!hold_keys;if(hold_keys)release_walk<=0;end
      else if(key_hit[7] && count<126 && release_walk==127 && release_mods==0)begin
       integer index;
       logic [7:0] code,text;
       index=integer'(key_hit[6:0]);
       code=local_key_code(7'(index),shift_on);text=local_key_text(7'(index),shift_on,caps_on);
       if(index==42 || index==54 || index==55)begin
        put<=1;put_data<={8'd0,code,index==42?!shift_on:index==54?!ctrl_on:!alt_on};
        if(index==42)shift_on<=!shift_on;
        if(index==54)ctrl_on<=!ctrl_on;
        if(index==55)alt_on<=!alt_on;
       end else if(hold_keys && index!=28)begin
        held_keys[index]<=!held_keys[index];put<=1;
        put_data<={held_keys[index]?8'd0:text,
                   (held_keys[index] && index==68)?held_f9:(held_keys[index] && index==69)?held_f10:code,
                   !held_keys[index]};
        if(!held_keys[index] && index==68)held_f9<=code;
        if(!held_keys[index] && index==69)held_f10<=code;
       end else begin
        if(index==28)caps_on<=!caps_on;
        held<=1;held_code<=code;pressed_index<=7'(index);
        put<=1;put_data<={text,code,1'b1};
       end
      end
     end
    end
   end
  end
 end
endmodule
