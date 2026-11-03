// Native mouse-first disk monitor. Draws into the machine's EXISTING draw
// framebuffer and launches the EXISTING console commands through its FIFO.
// Icon cache is in external CART RAM while applications are stopped.
(* use_dsp="no" *) module jmr_desktop (
    input logic clk, rst_n,
    input logic control_stb, control_on,
    input logic console_ready, console_failed, console_clear, keyboard_empty, keyboard_full,
    input logic vm_busy, game_mode, storage_busy, present_busy, card_present,
    input logic mouse_stb,
    input logic system_menu_active,
    input logic system_hold=1'b0,
    input logic [9:0] mouse_x,
    input logic [8:0] mouse_y,
    input logic [2:0] mouse_buttons,
    output logic visible,
    output logic busy,
    output logic console_hold,
    output logic keyboard_mode,
    output logic show_hidden,
    output logic [8:0] selected_o,
    output logic [4:0] page_o,
    output logic [2:0] menu_o,
    output logic key_push,
    output logic [7:0] key_data,
    output logic catalog_go, icon_go,
    output logic [7:0] icon_index,
    input logic disk_busy, disk_done, disk_error,
    input logic [8:0] catalog_count,
    output logic [11:0] catalog_addr,
    input logic [7:0] catalog_data,
    input logic icon_valid,
    output logic icon_ready,
    input logic [4:0] icon_x, icon_y,
    input logic [7:0] icon_colour,
    input logic icon_opaque,
    output logic fb_we, fb_swap,
    output logic [18:0] fb_addr,
    output logic [7:0] fb_data,
    output logic sram_req, sram_we,
    output logic [21:0] sram_addr,
    output logic [15:0] sram_data,
    input logic sram_ack,
    input logic [15:0] sram_rdata
);
    // Catalogue size changes during enumeration. Capture it locally before
    // page/selection calculations; the catalogue handshake already waits.
    logic [8:0] catalog_count_q;
    always_ff @(posedge clk)begin
        if(!rst_n)catalog_count_q<=0;
        else catalog_count_q<=catalog_count;
    end
    import jmr_desktop_layout_pkg::*;
    import jmr_classic_ui_pkg::classic_click_row;
    typedef enum logic [4:0] {BOOT,CATALOG,CATALOG_WAIT,IDLE,BASE,ICON,
        ICON_STREAM,ICON_READ,ICON_READ_WAIT,CAPTION,CHAR_REQ,CHAR_WAIT,
        FONT_WAIT,GLYPH,PRESENT,PRESENT_WAIT,CMD_BUILD,CMD_NAME_WAIT,
        CMD_SEND_WAIT,CMD_SEND,CMD_FINISH,CMD_NEXT,WAIT_APP,META_REQ,META_WAIT,FLUSH1,FLUSH2} state_t;
    state_t state;
    logic enabled, window_on, list_view, dirty, refresh_pending;
    logic [9:0] wx, draw_wx;
    logic [8:0] wy, draw_wy, selected, draw_selected;
    logic [4:0] page, draw_page;
    logic [8:0] draw_page_base;
    // Snapshot caption formatting once, away from the character/FSM path.
    logic [7:0] draw_count_hundreds,draw_count_tens,draw_count_ones;
    logic [7:0] draw_page_tens,draw_page_ones;
    logic [2:0] menu, draw_menu;
    logic [1:0] dialog, draw_dialog;
    logic draw_window,draw_list,doc_label,draw_hidden,hidden_previous_view;
    logic [2:0] label_suffix;
    logic [4:0] dot_i;
    logic [2:0] buttons_q;
    logic drag;
    logic [9:0] drag_x;
    logic [8:0] drag_y;
    logic [25:0] click_age;
    logic [8:0] last_selected;
    logic [255:0] cache_valid;
    logic [9:0] px;
    logic [8:0] py;
    logic [18:0] linear;
    logic [3:0] icon_slot;
    logic [9:0] icon_pixel;
    logic [9:0] icon_origin_x;
    logic [8:0] icon_origin_y;
    logic [5:0] cap;
    logic [4:0] char_i;
    logic [9:0] text_x,text_y;
    logic [6:0] char_code;
    logic [3:0] glyph_x,glyph_y;
    logic [7:0] text_colour;
    logic [15:0] font_data;
    logic [7:0] advance_data,label_data;
    logic [10:0] label_addr;
    (* rom_style="distributed" *) logic [15:0] font [0:2047];
    (* rom_style="distributed" *) logic [7:0] advances [0:127];
    (* rom_style="distributed" *) logic [7:0] labels [0:2047];
    initial begin
        $readmemh("desktop_font.hex",font);
        $readmemh("desktop_advance.hex",advances);
        $readmemh("desktop_labels.hex",labels);
    end
    always_ff @(posedge clk) begin
        font_data <= font[{char_code,glyph_y}];
        advance_data <= advances[char_code];
        label_data <= labels[label_addr];
    end
    logic [3:0] pending_action,action;
    logic [1:0] pending_system_file,system_file;
    logic [7:0] command_name_byte;
    function automatic logic [7:0] system_name(input logic [1:0] file_id,input logic [4:0] i);
        case(file_id)
            1:case(i)0:system_name="H";1:system_name="E";2:system_name="L";3:system_name="P";4:system_name=".";5:system_name="M";6:system_name="D";default:system_name=0;endcase
            2:case(i)0:system_name="U";1:system_name="T";2:system_name="I";3:system_name="L";4:system_name="I";5:system_name="T";6:system_name="Y";7:system_name=".";8:system_name="H";9:system_name="T";10:system_name="M";default:system_name=0;endcase
            default:case(i)0:system_name="N";1:system_name="O";2:system_name="T";3:system_name="E";4:system_name=".";5:system_name="H";6:system_name="T";7:system_name="M";default:system_name=0;endcase
        endcase
    endfunction
    assign command_name_byte=(system_file!=0)?system_name(system_file,name_i):catalog_data;
    localparam logic [3:0] A_NONE=0,A_OPEN=1,A_EDIT=2,A_COMPILE=3,A_READ=4,A_REMOVE=5,A_HELP=6;
    logic [7:0] action_index;
    logic [4:0] cmd_i,cmd_len,name_i,prefix_len;
    logic cmd_second, app_seen;
    logic [6:0] ready_age;
    logic [31:0] name_tail;
    logic cmd_we;
    logic [5:0] cmd_wa;
    logic [7:0] cmd_wd,cmd_rd;
    (* ram_style="distributed" *) logic [7:0] command [0:63];
    always_ff @(posedge clk) begin
        if(cmd_we) command[cmd_wa]<=cmd_wd;
        cmd_rd<=command[{1'b0,cmd_i}];
    end
    wire [3:0] count_hundreds=4'(catalog_count_q/9'd100);
    wire [5:0] count_tens=6'(catalog_count_q/9'd10);
    wire [3:0] count_tens_digit=4'(count_tens%6'd10);
    wire [3:0] count_ones=4'(catalog_count_q%9'd10);
    wire [5:0] page_number={1'b0,page}+6'd1;
    wire [2:0] page_tens=3'(page_number/6'd10);
    wire [3:0] page_ones=4'(page_number%6'd10);
    assign visible=enabled && !vm_busy && !game_mode;
    assign busy=(state!=IDLE && state!=WAIT_APP) ||
                (visible && (dirty || refresh_pending)) || pending_action!=A_NONE;
    assign console_hold=(state<=PRESENT_WAIT && state!=IDLE) || state==META_REQ || state==META_WAIT;
    assign selected_o=selected;
    assign page_o=page;
    assign menu_o=menu;
    assign icon_index=8'(draw_page_base+{5'd0,icon_slot});
    assign icon_ready=state==ICON_STREAM && !sram_req;
    wire [8:0] caption_file_index=draw_page_base+{5'd0,4'(cap-6'd14)};
    assign catalog_addr=(state==CMD_BUILD || state==CMD_NAME_WAIT)?
                       {action_index,name_i[3:0]}:
                       {8'(caption_file_index),(state==META_REQ || state==META_WAIT)?4'hf:char_i[3:0]};
    assign label_addr=11'(caption_label(cap,draw_wx,draw_wy,draw_menu,draw_dialog,
                           draw_page_base,catalog_count_q,draw_window,draw_list,disk_error,draw_hidden)*32+char_i);

    function automatic logic covered(input integer x,y,layer);
        integer mx,mh;
        begin
            mx=menu_x(draw_menu);mh=menu_count(draw_menu)*21+8;
            covered=(layer==0 && draw_menu!=0 && x>=mx && x<mx+162 && y>=22 && y<24+mh) ||
                    (layer<2 && draw_dialog!=0 && x>=133 && x<508 && y>=154 && y<307);
        end
    endfunction
    function automatic logic [7:0] load_prefix(input integer i,input logic remove_file);
        if(remove_file)case(i)
            0:load_prefix="R";1:load_prefix="E";2:load_prefix="M";3:load_prefix="O";
            4:load_prefix="V";5:load_prefix="E";6:load_prefix=" ";default:load_prefix="\"";
        endcase
        else case(i)
            0:load_prefix="L";1:load_prefix="O";2:load_prefix="A";3:load_prefix="D";
            4:load_prefix=" ";default:load_prefix="\"";
        endcase
    endfunction
    function automatic logic [7:0] follow_char(input integer i,input logic [3:0] which);
        case(which)
            A_OPEN:case(i) 0:follow_char="R";1:follow_char="U";2:follow_char="N";default:follow_char=13;endcase
            A_EDIT:case(i) 0:follow_char="E";1:follow_char="D";2:follow_char="I";3:follow_char="T";default:follow_char=13;endcase
            A_COMPILE:case(i) 0:follow_char="C";1:follow_char="O";2:follow_char="M";3:follow_char="P";
                4:follow_char="I";5:follow_char="L";6:follow_char="E";default:follow_char=13;endcase
            default:case(i) 0:follow_char="R";1:follow_char="E";2:follow_char="A";3:follow_char="D";default:follow_char=13;endcase
        endcase
    endfunction
    function automatic logic [7:0] help_char(input integer i);
        case(i)
            0:help_char="R";1:help_char="E";2:help_char="A";3:help_char="D";4:help_char=" ";
            5:help_char="\"";6:help_char="H";7:help_char="E";8:help_char="L";9:help_char="P";
            10:help_char=".";11:help_char="M";12:help_char="D";13:help_char="\"";default:help_char=13;
        endcase
    endfunction

    // A one-report-per-clock hit-test stage separates coordinate arithmetic
    // from selection/launch control. Both view modes are decoded so a preceding
    // menu event can change the view/page without making the queued hit stale.
    logic mouse_pipe_valid;
    logic [9:0] event_x;
    logic [8:0] event_y;
    logic [2:0] event_buttons;
    logic signed [10:0] event_rx,event_ry;
    logic [3:0] event_icon_slot,event_list_slot,event_menu_row;
    logic event_icon_valid,event_list_valid;
    always_ff @(posedge clk)begin
        if(!rst_n)begin
            mouse_pipe_valid<=0;event_x<=0;event_y<=0;event_buttons<=0;
            event_rx<=0;event_ry<=0;event_icon_slot<=0;event_list_slot<=0;event_menu_row<=15;
            event_icon_valid<=0;event_list_valid<=0;
        end else begin
            mouse_pipe_valid<=mouse_stb;
            if(mouse_stb)begin
                logic signed [10:0] rx,ry;
                logic [9:0] dx;
                logic [8:0] dy,ly;
                logic [3:0] column;
                rx=$signed({1'b0,mouse_x})-$signed({1'b0,wx});
                ry=$signed({2'b0,mouse_y})-$signed({2'b0,wy});
                dx=10'(rx-11'sd10);dy=9'(ry-11'sd50);ly=9'(ry-11'sd49);
                column=desktop_icon_column(dx);
                event_x<=mouse_x;event_y<=mouse_y;event_buttons<=mouse_buttons;
                event_rx<=rx;event_ry<=ry;event_menu_row<=classic_click_row(mouse_y);
                event_icon_slot<=4'(desktop_icon_row(dy)*4'd5+column);
                event_list_slot<=desktop_list_row(ly);
                event_icon_valid<=rx>=10 && rx<520 && ry>=50 && ry<308 && column<4'd5;
                event_list_valid<=rx>=24 && rx<520 && ry>=49 && ry<334;
            end
        end
    end

    // Coordinate/color stage, followed by one shared registered address stage.
    // Explicit shift/add stays in LUT carry chains; no unregistered DSP cascade.
    logic pixel_we;
    logic [9:0] pixel_x;
    logic [8:0] pixel_y;
    logic [7:0] pixel_data;
    function automatic logic [18:0] screen_address(input logic [9:0] x,input logic [8:0] y);
        logic [18:0] row;
        begin row={10'd0,y};screen_address=(row<<9)+(row<<7)+{9'd0,x};end
    endfunction
    always_ff @(posedge clk)begin
        if(!rst_n)begin fb_we<=0;fb_addr<=0;fb_data<=0;end
        else begin fb_we<=pixel_we;fb_addr<=screen_address(pixel_x,pixel_y);fb_data<=pixel_data;end
    end

    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state<=BOOT;enabled<=1;window_on<=1;list_view<=0;dirty<=1;refresh_pending<=1;keyboard_mode<=0;show_hidden<=0;draw_hidden<=0;hidden_previous_view<=0;
            wx<=8;wy<=34;page<=0;selected<=511;menu<=0;dialog<=0;buttons_q<=0;drag<=0;drag_x<=0;drag_y<=0;
            last_selected<=511;click_age<='1;cache_valid<=0;
            draw_count_hundreds<=32;draw_count_tens<=32;draw_count_ones<=48;draw_page_tens<=32;draw_page_ones<=49;
            draw_wx<=8;draw_wy<=34;draw_page<=0;draw_page_base<=0;draw_selected<=511;draw_menu<=0;draw_dialog<=0;draw_window<=1;draw_list<=0;
            px<=0;py<=0;linear<=0;icon_slot<=0;icon_pixel<=0;icon_origin_x<=0;icon_origin_y<=0;cap<=0;char_i<=0;text_x<=0;text_y<=0;
            doc_label<=0;label_suffix<=0;dot_i<=31;char_code<=32;glyph_x<=0;glyph_y<=0;text_colour<=0;
            catalog_go<=0;icon_go<=0;pixel_we<=0;fb_swap<=0;pixel_x<=0;pixel_y<=0;pixel_data<=0;
            sram_req<=0;sram_we<=0;sram_addr<=0;sram_data<=0;key_push<=0;key_data<=0;
            pending_action<=A_NONE;action<=A_NONE;pending_system_file<=0;system_file<=0;action_index<=0;cmd_i<=0;cmd_len<=0;name_i<=0;
            prefix_len<=6;cmd_second<=0;ready_age<=0;name_tail<=0;cmd_we<=0;cmd_wa<=0;cmd_wd<=0;app_seen<=0;
        end else begin
            catalog_go<=0;icon_go<=0;pixel_we<=0;fb_swap<=0;key_push<=0;cmd_we<=0;
            if(sram_ack)sram_req<=0;
            if(click_age!=26'h3ffffff)click_age<=click_age+1'b1;
            if(vm_busy || game_mode)cache_valid<=0;
            case(state)
                BOOT: if(console_ready && !storage_busy && !vm_busy)state<=CATALOG;
                CATALOG: if(!disk_busy && !storage_busy && console_ready)begin
                    catalog_go<=1;refresh_pending<=0;cache_valid<=0;state<=CATALOG_WAIT;
                end
                CATALOG_WAIT: if(disk_done)begin
                    if(page*15>=catalog_count_q)page<=0;
                    if(selected>=catalog_count_q)selected<=511;
                    dirty<=1;state<=IDLE;
                end
                IDLE: begin
                    if(enabled && refresh_pending)state<=CATALOG;
                    else if(pending_action!=A_NONE && console_ready && !disk_busy && !storage_busy)begin
                        action<=pending_action;system_file<=pending_system_file;pending_system_file<=0;pending_action<=A_NONE;enabled<=0;menu<=0;dialog<=0;
                        keyboard_mode<=0;
                        cmd_i<=0;name_i<=0;cmd_second<=0;name_tail<=0;prefix_len<=pending_action==A_REMOVE?8:6;
                        cmd_len<=0;state<=CMD_BUILD;
                    end else if(visible && dirty && !present_busy && !disk_busy)begin
                        draw_count_hundreds<=catalog_count_q<100?8'd32:8'(48+count_hundreds);
                        draw_count_tens<=catalog_count_q<10?8'd32:8'(48+count_tens_digit);
                        draw_count_ones<=8'(48+count_ones);
                        draw_page_tens<=page>=9?8'(48+page_tens):8'd32;
                        draw_page_ones<=8'(48+page_ones);
                        dirty<=0;draw_wx<=wx;draw_wy<=wy;draw_page<=page;draw_page_base<={4'd0,page}*9'd15;draw_selected<=selected;
                        draw_menu<=menu;draw_dialog<=dialog;draw_window<=window_on;draw_list<=list_view;draw_hidden<=show_hidden;
                        px<=0;py<=0;linear<=0;state<=BASE;
                    end
                end
                BASE: begin
                    pixel_we<=1;pixel_x<=px;pixel_y<=py;
                    pixel_data<=desktop_base(px,py,draw_wx,draw_wy,draw_selected,draw_page_base,draw_window,draw_list,draw_menu,draw_dialog);
                    linear<=linear+1'b1;
                    if(px==639)begin px<=0;py<=py+1'b1;end else px<=px+1'b1;
                    if(linear==307199)begin icon_slot<=0;state<=ICON;end
                end
                ICON: begin
                    icon_origin_x<=draw_wx+10'd38+10'(desktop_column(icon_slot)*10'd102);
                    icon_origin_y<=draw_wy+9'd58+9'(desktop_row(icon_slot)*9'd86);
                    if(!draw_window || draw_list || icon_slot>=15 || draw_page_base+{5'd0,icon_slot}>=catalog_count_q)begin cap<=0;state<=CAPTION;end
                    else if(cache_valid[icon_index])begin icon_pixel<=0;state<=ICON_READ;end
                    else if(!disk_busy && !storage_busy)begin icon_go<=1;state<=ICON_STREAM;end
                end
                ICON_STREAM: begin
                    if(icon_valid && icon_ready)begin
                        sram_req<=1;sram_we<=1;sram_addr<={4'd0,icon_index,icon_y,icon_x};
                        sram_data<={7'd0,icon_opaque,icon_colour};
                        if(!covered(icon_origin_x+icon_x,icon_origin_y+icon_y,0))begin
                            pixel_we<=1;pixel_x<=10'(icon_origin_x+icon_x);pixel_y<=9'(icon_origin_y+icon_y);
                            pixel_data<=icon_opaque?icon_colour:8'd255;
                        end
                    end
                    if(disk_done && !sram_req)begin cache_valid[icon_index]<=1;icon_slot<=icon_slot+1'b1;state<=ICON;end
                end
                ICON_READ: if(!sram_req)begin
                    sram_req<=1;sram_we<=0;sram_addr<={4'd0,icon_index,icon_pixel};state<=ICON_READ_WAIT;
                end
                ICON_READ_WAIT: if(sram_ack)begin
                    if(!covered(icon_origin_x+icon_pixel[4:0],icon_origin_y+icon_pixel[9:5],0))begin
                        pixel_we<=1;pixel_x<=10'(icon_origin_x+icon_pixel[4:0]);pixel_y<=9'(icon_origin_y+icon_pixel[9:5]);
                        pixel_data<=sram_rdata[8]?sram_rdata[7:0]:8'd255;
                    end
                    if(icon_pixel==1023)begin icon_slot<=icon_slot+1'b1;state<=ICON;end
                    else begin icon_pixel<=icon_pixel+1'b1;state<=ICON_READ;end
                end
                CAPTION: begin
                    if(cap>=44)state<=FLUSH1;
                    else if(!caption_visible(cap,draw_wx,draw_wy,draw_menu,draw_dialog,draw_page_base,catalog_count_q,draw_window,draw_list,disk_error,draw_hidden))cap<=cap+1'b1;
                    else begin
                        text_x<=10'(caption_x(cap,draw_wx,draw_wy,draw_menu,draw_dialog,draw_page_base,catalog_count_q,draw_window,draw_list,disk_error,draw_hidden));
                        text_y<=10'(caption_y(cap,draw_wx,draw_wy,draw_menu,draw_dialog,draw_page_base,catalog_count_q,draw_window,draw_list,disk_error,draw_hidden));
                        text_colour<=(cap>=14 && cap<29 && draw_selected==caption_file_index)?8'd255:8'd0;
                        char_i<=0;dot_i<=31;state<=(cap>=14 && cap<29)?META_REQ:CHAR_REQ;
                    end
                end
                META_REQ:state<=META_WAIT;
                META_WAIT:begin doc_label<=catalog_data[0];label_suffix<=catalog_data[3:1];state<=CHAR_REQ;end
                CHAR_REQ: state<=CHAR_WAIT;
                CHAR_WAIT: begin
                    logic [7:0] ch;
                    ch=(cap>=14 && cap<29)?catalog_data:label_data;
                    if(cap>=14 && cap<29)begin
                        if(ch=="." && dot_i==31)dot_i<=char_i;
                        if(dot_i!=31 && char_i>dot_i && label_suffix!=0)begin
                            case(char_i-dot_i)
                                1:ch=label_suffix==3?"I":"A";
                                2:ch=label_suffix==3?"C":"R";
                                3:ch=label_suffix==3?"O":"T";
                                4:ch=label_suffix==1?"J":label_suffix==2?"X":"N";
                                5:ch=label_suffix==1?"S":8'd0;
                                default:ch=0;
                            endcase
                        end
                    end
                    if(cap==8 && !disk_error && char_i<3)begin
                        case(char_i)
                            0:ch=draw_count_hundreds;
                            1:ch=draw_count_tens;
                            default:ch=draw_count_ones;
                        endcase
                    end
                    if(cap==9 && char_i==5)ch=draw_page_tens;
                    if(cap==9 && char_i==6)ch=draw_page_ones;
                    if(ch==0 || char_i==31 || (cap>=14 && cap<29 && (doc_label ? char_i==15 : (ch=="." || char_i==8))))begin cap<=cap+1'b1;state<=CAPTION;end
                    else begin char_code<=ch<128?ch[6:0]:7'd63;glyph_x<=0;glyph_y<=0;state<=FONT_WAIT;end
                end
                FONT_WAIT: state<=GLYPH;
                GLYPH: begin
                    if(font_data[15-glyph_x] && text_x+glyph_x<640 && text_y+glyph_y<480 &&
                       !covered(text_x+glyph_x,text_y+glyph_y,cap<29?0:cap<39?1:2))begin
                        pixel_we<=1;pixel_x<=10'(text_x+glyph_x);pixel_y<=9'(text_y+glyph_y);pixel_data<=text_colour;
                    end
                    if(glyph_x==15)begin
                        glyph_x<=0;
                        if(glyph_y==15)begin text_x<=text_x+10'(advance_data);char_i<=char_i+1'b1;state<=CHAR_REQ;end
                        else begin glyph_y<=glyph_y+1'b1;state<=FONT_WAIT;end
                    end else glyph_x<=glyph_x+1'b1;
                end
                FLUSH1:state<=FLUSH2;
                FLUSH2:state<=PRESENT;
                PRESENT: if(!present_busy)begin fb_swap<=1;state<=PRESENT_WAIT;ready_age<=0;end
                PRESENT_WAIT: begin
                    if(present_busy)ready_age<=1;
                    else if(ready_age!=0)state<=IDLE;
                end
                CMD_BUILD: begin
                    if(cmd_second)begin
                        cmd_we<=1;cmd_wa<={1'b0,cmd_i};cmd_wd<=follow_char(cmd_i,action);cmd_i<=cmd_i+1'b1;
                        if(follow_char(cmd_i,action)==13)begin cmd_len<=cmd_i+1'b1;cmd_i<=0;state<=CMD_SEND_WAIT;end
                    end else if(cmd_i<prefix_len)begin
                        cmd_we<=1;cmd_wa<={1'b0,cmd_i};cmd_wd<=load_prefix(cmd_i,action==A_REMOVE);cmd_i<=cmd_i+1'b1;
                    end else state<=CMD_NAME_WAIT;
                end
                CMD_NAME_WAIT: begin
                    if(command_name_byte!=0 && name_i<12)begin
                        cmd_we<=1;cmd_wa<={1'b0,cmd_i};cmd_wd<=command_name_byte;cmd_i<=cmd_i+1'b1;
                        name_i<=name_i+1'b1;name_tail<={name_tail[23:0],command_name_byte};state<=CMD_BUILD;
                    end else begin
                        cmd_we<=1;cmd_wa<={1'b0,cmd_i};cmd_wd<=34;cmd_i<=cmd_i+1'b1;state<=CMD_NEXT;
                    end
                end
                CMD_NEXT: begin
                    cmd_we<=1;cmd_wa<={1'b0,cmd_i};cmd_wd<=13;cmd_len<=cmd_i+1'b1;cmd_i<=0;
                    if(action==A_OPEN && name_tail!=32'h2e48544d && name_tail[23:0]!=24'h2e4a53)action<=A_READ;
                    state<=CMD_SEND_WAIT;
                end
                CMD_SEND_WAIT: if(!console_clear && console_ready && !storage_busy && !disk_busy)begin ready_age<=0;state<=CMD_SEND;end
                CMD_SEND: if(!keyboard_full)begin
                    key_push<=1;key_data<=cmd_rd;
                    if(cmd_i+1>=cmd_len)begin ready_age<=0;state<=CMD_FINISH;end
                    else begin cmd_i<=cmd_i+1'b1;state<=CMD_SEND_WAIT;end
                end
                CMD_FINISH: begin
                    if((cmd_second || action==A_HELP) && (action==A_OPEN || action==A_EDIT || action==A_READ || action==A_HELP) && (vm_busy || game_mode))begin app_seen<=1;state<=WAIT_APP;end
                    else if(console_ready && keyboard_empty && !storage_busy && !disk_busy && !console_clear)begin
                        if(ready_age==100)begin
                            if(console_failed)begin state<=WAIT_APP;app_seen<=1;end
                            else if(action==A_REMOVE || (cmd_second && action==A_COMPILE))begin enabled<=1;refresh_pending<=1;state<=IDLE;end
                            else if(!cmd_second && action!=A_HELP)begin cmd_second<=1;cmd_i<=0;state<=CMD_BUILD;end
                            else begin app_seen<=1;state<=WAIT_APP;end
                        end else ready_age<=ready_age+1'b1;
                    end else ready_age<=0;
                end
                WAIT_APP: if(!system_hold && app_seen && !vm_busy && !game_mode && console_ready && !storage_busy && !console_failed)begin
                    enabled<=1;keyboard_mode<=0;refresh_pending<=1;state<=IDLE;app_seen<=0;
                end
                default:state<=IDLE;
            endcase
            // Requests to show the desktop wait for in-flight disk/draw work.
            if(control_stb)begin
                enabled<=control_on;dirty<=1;
                keyboard_mode<=0;
                if(control_on)begin refresh_pending<=1;if(state==WAIT_APP)state<=IDLE;end
            end
            if(mouse_pipe_valid)begin
                buttons_q<=event_buttons;
                if(visible)begin
                    logic signed [10:0] rx,ry;
                    logic [3:0] slot,row;
                    logic [8:0] index;
                    logic slot_valid;
                    logic [2:0] m;
                    rx=event_rx;ry=event_ry;
                    if(drag)begin
                        if(event_buttons[0])begin
                            wx<=10'((event_x<drag_x)?0:(event_x-drag_x>91)?91:event_x-drag_x);
                            wy<=9'((event_y<drag_y+22)?22:(event_y-drag_y>126)?126:event_y-drag_y);
                            dirty<=1;
                        end else drag<=0;
                    end else if(event_buttons[0] && !buttons_q[0])begin
                        dirty<=1;
                        if(dialog!=0)begin
                            if(event_y>=260 && event_y<287)begin
                                if(event_x>=168 && event_x<264)begin
                                    if(dialog==1 && selected<catalog_count_q)begin pending_action<=A_REMOVE;action_index<=selected[7:0];end
                                    dialog<=0;
                                end else if(event_x>=341 && event_x<437)dialog<=0;
                            end
                        end else if(event_y<22)begin
                            m=0;
                            if(event_x>=30 && event_x<80)m=1;
                            else if(event_x>=84 && event_x<134)m=2;
                            else if(event_x>=136 && event_x<186)m=3;
                            else if(event_x>=190 && event_x<264)m=4;
                            menu<=m;
                        end else if(menu!=0)begin
                            row=event_menu_row;
                            if(event_y>=26 && event_x>=menu_x(menu) && event_x<menu_x(menu)+160 && row<menu_count(menu))begin
                                action_index<=selected[7:0];
                                case(menu)
                                    1:case(row)
                                        0:if(selected<catalog_count_q)pending_action<=A_OPEN;
                                        1:if(selected<catalog_count_q)pending_action<=A_COMPILE;
                                        2:if(selected<catalog_count_q)pending_action<=A_READ;
                                        3:if(selected<catalog_count_q)dialog<=1;
                                        4:window_on<=0;
                                        default:;
                                    endcase
                                    2:if(row==0)begin if(selected<catalog_count_q)pending_action<=A_EDIT;end
                                    3:case(row)
                                        0:list_view<=0;1:list_view<=1;2:refresh_pending<=1;
                                        3:begin
                                            if(!show_hidden)begin hidden_previous_view<=list_view;list_view<=1;end
                                            else list_view<=hidden_previous_view;
                                            show_hidden<=!show_hidden;page<=0;selected<=511;refresh_pending<=1;
                                        end default:;
                                    endcase
                                    4:case(row)
                                        0:begin enabled<=0;keyboard_mode<=0;end
                                        1:begin
                                            if(selected<catalog_count_q)pending_action<=A_EDIT;
                                            else begin pending_action<=A_OPEN;pending_system_file<=3;end
                                        end
                                        2:begin pending_action<=A_READ;if(selected>=catalog_count_q)pending_system_file<=1;end
                                        3:if(selected<catalog_count_q)pending_action<=A_COMPILE;
                                        4:begin pending_action<=A_OPEN;pending_system_file<=2;end
                                        5:begin pending_action<=A_OPEN;pending_system_file<=3;end
                                        6:begin pending_action<=A_READ;pending_system_file<=1;end
                                        7:begin page<=0;selected<=511;window_on<=1;refresh_pending<=1;end
                                        default:;
                                    endcase
                                    default:;
                                endcase
                            end
                            menu<=0;
                        end else if(event_x>=570 && event_x<=625 && event_y>=40 && event_y<=104)window_on<=1;
                        else if(event_x>=570 && event_x<=625 && event_y>=404)begin if(selected<catalog_count_q)dialog<=1;end
                        else if(window_on)begin
                            if(rx>=6 && rx<20 && ry>=5 && ry<19)window_on<=0;
                            else if(rx>=22 && rx<546 && ry>=2 && ry<24)begin drag<=1;drag_x<=10'(rx);drag_y<=9'(ry);end
                            else if((rx>=529 && rx<547 && ry>=318 && ry<336)||(rx>=511 && rx<529 && ry>=337 && ry<353))begin if((page+1)*15<catalog_count_q)page<=page+1'b1;end
                            else if((rx>=529 && rx<547 && ry>=48 && ry<65)||(rx>=2 && rx<20 && ry>=337 && ry<353))begin if(page!=0)page<=page-1'b1;end
                            else begin
                                slot=list_view?event_list_slot:event_icon_slot;
                                slot_valid=list_view?event_list_valid:event_icon_valid;
                                index={4'd0,page}*9'd15+{5'd0,slot};
                                if(slot_valid && index<catalog_count_q)begin
                                    if(selected==index && last_selected==index && click_age<=26'd40000000)begin pending_action<=A_OPEN;action_index<=8'(index);end
                                    selected<=9'(index);last_selected<=9'(index);click_age<=0;
                                end else selected<=511;
                            end
                        end
                    end
                end
            end
            if(system_menu_active && menu!=0)begin menu<=0;dirty<=1;end
        end
    end
endmodule
