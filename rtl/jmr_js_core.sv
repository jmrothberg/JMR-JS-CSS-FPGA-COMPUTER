// Shared JS-native core — Verilator tops this; board top is PHY shell only.
// Pattern cite: BASIC jmr_core + standalone_mode.
// NEW: storage_engine + work/source BRAM for DIR/LOAD/SAVE/REMOVE.
module jmr_js_core #(
    parameter int unsigned SD_INIT_DIV = 127,
    parameter int unsigned SD_RUN_DIV  = 3,
    // Short default for simulator/debug; the board explicitly selects 60 Hz.
    parameter int unsigned FRAME_DIV   = 65535,
    // NEW: 1 = behavioral 4 MB SRAM (FPGA-SIM). 0 = ports for board MIG / ASIC.
    // Not `ifdef SYNTHESIS` — same RTL, board instantiates #(.SRAM_INTERNAL(0)).
    parameter bit SRAM_INTERNAL = 1,
    // 2026-08-25 div8 timing rescue: u_vm runs on clk/VM_CLK_DIV. Run-30
    // post-route measurement: all 6,000 worst failing paths start AND end
    // inside u_vm (WNS -58.737 at 10 ns -> +11.26 ns at 80 ns); nothing
    // outside the VM fails, and jmr_fb_scanout needs the full 100 MHz (one
    // SRAM fetch per 100 ns sustains 640x480). 1 = passthrough (battery
    // speed); board default 8.
    parameter int unsigned VM_CLK_DIV = 3
) (
    input  logic        clk,
    input  logic        pixel_clk,   // mini-FB read domain (board HDMI)
    input  logic        rst_n,
    input  logic        standalone_mode,
    input  logic        kbd_push,
    input  logic [7:0]  kbd_data,
    input  logic [5:0]  joy_in,
    output logic [5:0]  joy_out,
    // analog-joy: raw Pmod stick axes + 5 discrete buttons (A,B,C,D,click).
    // Board top wires these from jmr_i2c_joy; FPGA-SIM/PYTHON drive them
    // over a debug RPC. digital joy_in/joy_out above are unchanged — this
    // is extra axes a title can poll, not a mouse (analog-joy).
    input  logic [7:0]  analog_x,
    input  logic [7:0]  analog_y,
    input  logic [4:0]  joy_btn,
    output logic [6:0]  stor_dbg_state_o,
    output logic [15:0] stor_dbg_op_clk_o,   // run 71
    output logic [6:0]  cons_dbg_state_o,
    output logic        game_view_o,
    output logic [31:0] vdbg_o,
    output logic        vdbg_fault_o,
    output logic [31:0] vm_hdbg,
    output logic [31:0] vm_fdbg,
    output logic        vm_fdbg_v,
    output logic [127:0] vm_ftrace,
    output logic [47:0]  vm_gdbg,
    // sound-native poke (core clock; PSG leaf + CDC live in the top)
    output logic        snd_tgl,
    output logic [1:0]  snd_ch,
    output logic [15:0] snd_freq,
    output logic [3:0]  snd_vol,
    output logic [7:0]  snd_frames,
    output logic [7:0]  snd_slide,
    // FPGA-SIM keyboard/joystick ARE these ports (GUI KEYEVT / KEYBITS).
    // No PS/2 or I2C in this module. Board PHY is top_nexys_video only.
    // LED proofs: tools/pmod_input_test + tools/hid_led_blink — not this file.
    // NEW: raw keyboard events for games (sim KEYEVT / board PS/2 decode)
    input  logic        sd_card_present = 1'b1,
    input  logic        key_evt_stb = 1'b0,
    input  logic [7:0]  key_evt_code = 8'd0,
    input  logic        key_evt_down = 1'b0,
    input logic [7:0] key_evt_char = 8'd0,
    input  logic        mouse_stb = 1'b0,
    input  logic [9:0]  mouse_x = 10'd320,
    input  logic [8:0]  mouse_y = 9'd240,
    input  logic [2:0]  mouse_buttons = 3'd0,
    output logic        mouse_ready,
    input logic desktop_control_stb = 1'b0,
    input logic desktop_control_on = 1'b1,
    output logic desktop_visible_o,
    output logic desktop_busy_o,
    output logic [8:0] desktop_count_o,
    output logic [8:0] desktop_selected_o,
    output logic [4:0] desktop_page_o,
    output logic [2:0] desktop_menu_o,
    output logic desktop_keyboard_mode_o,
    output logic [9:0] pointer_x_o,
    output logic [8:0] pointer_y_o,
    output logic pointer_toggle_o,
    output logic overlay_opaque_o,
    output logic [23:0] overlay_rgb_o,
    output logic system_menu_o,system_keyboard_o,system_about_o,system_shift_o,system_caps_o,system_ctrl_o,system_alt_o,
    output logic [6:0] system_pressed_o,
    output logic system_hold_o,
    output logic [69:0] system_held_o,
    output logic [31:0] system_generation_o,
    output logic [31:0] system_window_o,
    output logic [15:0] system_status_o,
    output logic system_viewport_o,
    output logic [8:0] game_source_y_o,
    output logic system_overlay_opaque_o,
    output logic [23:0] system_overlay_rgb_o,
    input  logic [9:0]  dump_addr,
    output logic [7:0]  dump_data,
    output logic [9:0]  cursor,
    output logic        ready_lit,
    input  logic [9:0]  scan_addr,
    output logic [7:0]  scan_data,
    // Mini-canvas scanout (game mode) — native 640×480
    output logic        game_mode,
    input  logic [18:0] fb_raddr, // Session-1: unused (scanout is DDR3-side)
    input  logic [9:0]  fb_x,
    input  logic [9:0]  fb_y,
    output logic [7:0]  fb_rdata,
    // NEW: tether FB dump (core clk)
    input  logic [18:0] dump_fb_raddr = 19'd0,
    output logic [7:0]  dump_fb_rdata,
    // NEW: title palette readout (ASET 256×RGB888) — HDMI top + sim PAL? dump
    input  logic [7:0]  pal_raddr = 8'd0,
    output logic [23:0] pal_rdata,
    // NEW: µSD SPI (storage_engine owns the master)
    output logic        sd_sck,
    output logic        sd_mosi,
    input  logic        sd_miso,
    output logic        sd_cs_n,
    // NEW: FPGA-SIM JSHLOAD pulse (tied 0 on the board)
    input  logic        sim_vm_start = 1'b0,
    // NEW: FPGA-SIM FRAME — pulse one frame_tick when already in S_WAIT_FRAME
    input  logic        sim_frame_pulse = 1'b0,
    // NEW: PROG FT245 .JSH stream (HTML RUN). Sim leaves these at default 0.
    input  logic        jsb_tether_stb = 1'b0,
    input  logic [7:0]  jsb_tether_data = 8'd0,
    input  logic        jsb_tether_eof = 1'b0,
    input  logic        jsb_tether_src = 1'b0,
    input  logic        jsb_tether_big = 1'b0,   // run 71: 0xFB CART big put
    input  logic        jsb_tether_crc_err = 1'b0, // run 71: trailer CRC mismatch (with eof)
    output logic        jsb_tether_rdy,
    // NEW: FPGA-SIM RAM LOAD — SOURCE poked by the host, LOAD skips FAT open
    input  logic        sim_src_bypass = 1'b0,
    input  logic [15:0] sim_src_lines = 16'd0,
    // NEW: asset SRAM port when SRAM_INTERNAL=0 (board MIG). Sim leaves defaults.
    output logic        sram_ext_req,
    output logic        sram_ext_we,
    output logic [21:0] sram_ext_addr,
    output logic [15:0] sram_ext_wdata,
    input  logic [15:0] sram_ext_rdata = 16'd0,
    input  logic        sram_ext_ack = 1'b0
);
    // Register the absolute report before menu hit testing and guest delivery.
    // One report per clock is retained; the USB/PS2 devices and wiring stay in
    // the board top. This separates FIFO read/clamp from the 100MHz UI logic.
    logic input_mouse_stb;
    logic [9:0] input_mouse_x;
    logic [8:0] input_mouse_y;
    logic [8:0] input_game_mouse_y;
    logic [2:0] input_mouse_buttons;
    logic [3:0] input_mouse_row;
    logic [7:0] input_key_hit;
    logic report_mouse_stb;
    logic [9:0] report_mouse_x;
    logic [8:0] report_mouse_y;
    logic [2:0] report_mouse_buttons;
    always_ff @(posedge clk)begin
        if(!rst_n)begin
            report_mouse_stb<=0;report_mouse_x<=320;report_mouse_y<=240;report_mouse_buttons<=0;
            input_mouse_stb<=0;input_mouse_x<=320;input_mouse_y<=240;input_game_mouse_y<=240;input_mouse_buttons<=0;input_mouse_row<=15;input_key_hit<=0;
        end
        else begin
            report_mouse_stb<=mouse_stb;
            if(mouse_stb)begin report_mouse_x<=mouse_x;report_mouse_y<=mouse_y;report_mouse_buttons<=mouse_buttons;end
            input_mouse_stb<=report_mouse_stb;
            if(report_mouse_stb)begin
                input_mouse_x<=report_mouse_x;input_mouse_y<=report_mouse_y;input_mouse_buttons<=report_mouse_buttons;
                input_game_mouse_y<=jmr_classic_ui_pkg::classic_game_y({1'b0,report_mouse_y});
                input_mouse_row<=jmr_classic_ui_pkg::classic_click_row(report_mouse_y);
                input_key_hit<=jmr_system_menu_pkg::system_key_hit(report_mouse_x,report_mouse_y);
            end
        end
    end

    logic kbd_empty, kbd_full, kbd_pop, kbd_clear;
    logic [7:0] kbd_q;
    logic video_busy;
    logic cls, put_en, print_nl;
    logic [7:0] put_char;
    logic run_pulse;
    logic vm_start;
    logic halt_pulse;
    logic demo_busy, demo_done;
    logic vm_busy, vm_done;
    always_ff @(posedge clk) begin
        if(!rst_n) begin pointer_x_o<=320;pointer_y_o<=240;pointer_toggle_o<=0;end
        else if(input_mouse_stb && mouse_ready) begin
            pointer_x_o<=input_mouse_x>639?10'd639:input_mouse_x;
            pointer_y_o<=input_mouse_y>479?9'd479:input_mouse_y;
            pointer_toggle_o<=~pointer_toggle_o;
        end
    end
    jmr_mouse_overlay u_mouse_overlay (
        .x(fb_x),.y(fb_y),.mouse_x(pointer_x_o),.mouse_y(pointer_y_o),
        .show_pointer(1'b1),.opaque(overlay_opaque_o),.rgb(overlay_rgb_o)
    );
    logic mouse_queue_ready, mouse_event_valid, mouse_event_pop;
    logic vm_key_evt_ready;
    logic [47:0] mouse_event_data;
    // The system menu remains responsive even if a program stops draining
    // input. Normal reports use the event FIFO; an overloaded VM gets the
    // latest pending absolute position/button state after it catches up.
    logic mouse_pending;
    logic [9:0] pending_mouse_x;
    logic [8:0] pending_mouse_y;
    logic [2:0] pending_mouse_buttons;
    logic ui_consume,ui_quit,ui_terminal,ui_key_stb,ui_key_down,ui_ascii_stb;
    logic [7:0] ui_key_code,ui_key_char,ui_ascii_data;
    logic ship_consume,ship_quit,ship_guest;
    logic docs_consume,docs_keys,docs_keyboard_stb,docs_keyboard_on,docs_command_stb,docs_after_valid;
    logic [3:0] docs_command,docs_chosen_len,docs_after_action,docs_after_len,docs_name_len;
    logic [95:0] docs_chosen_name,docs_after_name;
    logic [2:0] docs_dialog;
    logic [8:0] docs_file_count,docs_selected;
    logic [7:0] docs_file_top,docs_message;
    logic docs_name_selected;
    logic [31:0] docs_generation,last_docs_generation;
    logic docs_catalog_go,docs_catalog_active,docs_catalog_all;
    logic [11:0] docs_catalog_addr;
    logic docs_label_valid,docs_label_ready;
    logic [5:0] docs_label_row;
    logic [26:0] docs_label_data;
    logic [5:0] docs_label_col;logic docs_label_commit;logic signed [11:0] classic_label_pos;logic [11:0] classic_label_glyph;
    wire owned_keys=docs_keys || classic_menu!=0 || system_about_o || system_menu_o;
    wire dialog_key_stb=ui_key_stb || key_evt_stb || kbd_push;
    wire [7:0] dialog_key_code=ui_key_stb?ui_key_code:key_evt_stb?key_evt_code:kbd_data;
    wire [7:0] dialog_key_char=ui_key_stb?ui_key_char:(key_evt_stb && key_evt_char!=0)?key_evt_char:
                              (kbd_push && kbd_data>=32 && kbd_data<127)?kbd_data:8'd0;
    wire dialog_key_down=ui_key_stb?ui_key_down:key_evt_stb?key_evt_down:1'b1;
    wire save_shortcut=dialog_key_stb && dialog_key_down && dialog_key_code==113 && dialog_key_char==0 &&
                       !owned_keys && !actions_busy && (system_window_o[7:0]==1 || system_window_o[7:0]==5);
    logic actions_busy,actions_quit,actions_halt,actions_desk_stb,actions_desk_on,actions_key_push,actions_inject;
    logic actions_doc_start,actions_doc_new,actions_set_name,actions_error;
    logic [7:0] actions_key_data,actions_inject_code;
    logic [2:0] actions_doc_role,con_system_role,con_system_stage;
    logic [95:0] actions_target_name;
    logic [3:0] actions_target_len;
    logic [127:0] con_source_name;
    logic [4:0] con_source_name_len;
    logic con_unnamed,note_entry_seen;
    logic catalog_entry_seen,catalog_skip_start,actions_catalog_prepared,actions_restart;
    wire new_catalog_entry=system_window_o[7:0]==4 && !actions_busy && !catalog_entry_seen;
    always_ff @(posedge clk)begin
      if(!rst_n)begin catalog_entry_seen<=0;catalog_skip_start<=0;end
      else if(app_clear)begin catalog_entry_seen<=catalog_skip_start || actions_catalog_prepared;catalog_skip_start<=0;end
      else begin if(new_catalog_entry)catalog_entry_seen<=1;if(actions_catalog_prepared)catalog_skip_start<=1;end
    end
    wire new_note_entry=system_window_o[7:0]==5 && !con_interactive && !actions_busy && !note_entry_seen;
    logic actions_catalog_go,actions_catalog_active,actions_stage_valid,actions_stage_ready;
    logic [11:0] actions_catalog_addr;logic [12:0] actions_stage_addr;logic [7:0] actions_stage_data;logic [31:0] desk_catalog_size;
    logic classic_error_seen;wire classic_error_pulse=classic_error && !classic_error_seen;
    always_ff @(posedge clk)if(!rst_n || app_clear)classic_error_seen<=0;else if(classic_error)classic_error_seen<=1;
    logic classic_consume,classic_key_stb,classic_action_stb,classic_error,classic_about_valid,classic_title_valid;
    logic [7:0] classic_key_code;
    logic [3:0] classic_action,classic_menu,classic_popup_count,classic_popup_row;
    logic [9:0] classic_popup_left,classic_title_width;
    logic [7:0] classic_popup_static;
    logic [5:0] classic_popup_dynamic,classic_label_raddr;
    logic classic_popup_enabled;
    logic [63:0] classic_static_rows;logic [47:0] classic_dynamic_rows;logic [7:0] classic_enabled_rows;

    logic [31:0] ship_generation,classic_generation,app_window;
    logic [31:0] last_ship_generation,last_classic_generation,last_system_window;
    logic vm_sysw_toggle,sysw_seen,vm_text_toggle,text_seen,vm_text_menu,vm_text_first,vm_text_last;
    logic [2:0] vm_sysw_field;
    logic [7:0] vm_sysw_value,vm_text_byte;
    logic [1:0] restart_phase;
    logic classic_vm_start,classic_restart_halt;
    wire app_clear=vm_start || sim_vm_start || classic_vm_start || actions_restart;
    wire [8:0] pointer_source_y=(system_viewport_o && system_window_o[7:0]==8)?input_game_mouse_y:input_mouse_y;
    function automatic logic [8:0] map_game_y(input logic [9:0] py);
        map_game_y=jmr_classic_ui_pkg::classic_game_y(py);
    endfunction
    always_comb begin
        system_status_o=0;system_status_o[2:0]=docs_dialog;system_status_o[3]=docs_catalog_active;
        system_status_o[4]=actions_busy;system_status_o[5]=classic_error;system_status_o[9:6]=classic_menu;
    end
    assign game_source_y_o=map_game_y(fb_y);
    assign ui_consume=ship_consume || classic_consume || docs_consume;
    assign ui_quit=ship_quit || actions_quit;
    // Capture the native text event as a bundle before descriptor parsing.
    // The VM holds each event for at least three core clocks.
    logic classic_text_stb,classic_text_menu,classic_text_first,classic_text_last;
    logic [7:0] classic_text_byte;
    logic [31:0] classic_window_q;
    always_ff @(posedge clk)begin
        if(!rst_n || app_clear)begin
            classic_text_stb<=0;classic_text_menu<=0;classic_text_first<=0;classic_text_last<=0;classic_text_byte<=0;
        end else begin
            classic_text_stb<=text_seen!=vm_text_toggle;
            if(text_seen!=vm_text_toggle)begin
                classic_text_menu<=vm_text_menu;classic_text_first<=vm_text_first;
                classic_text_last<=vm_text_last;classic_text_byte<=vm_text_byte;
            end
        end
        if(!rst_n)classic_window_q<=0;
        else classic_window_q<=system_window_o;
    end
    always_ff @(posedge clk)begin
        if(!rst_n || app_clear)begin app_window<=0;system_viewport_o<=0;sysw_seen<=0;text_seen<=vm_text_toggle;end
        else begin
            if(!vm_busy)begin app_window<=0;system_viewport_o<=0;end
            if(sysw_seen!=vm_sysw_toggle)begin
                sysw_seen<=vm_sysw_toggle;
                if(vm_sysw_field<4)app_window[vm_sysw_field*8+:8]<=vm_sysw_value;
                else if(vm_sysw_field==4)system_viewport_o<=vm_sysw_value!=0;
            end
            if(text_seen!=vm_text_toggle)text_seen<=vm_text_toggle;
        end
    end
    always_comb begin
        system_window_o=app_window;
        if(desk_visible)system_window_o[7:0]=0;
        else if(con_system_role==3)begin system_window_o[7:0]=3;system_window_o[31:24]={1'b0,con_system_stage,4'd0};end
        else if(!vm_busy)system_window_o[7:0]=7;
        else if(app_window[7:0]==0 && con_interactive)system_window_o[7:0]={5'd0,con_system_role};
    end
    always_ff @(posedge clk)begin
        if(!rst_n)begin system_generation_o<=0;last_ship_generation<=0;last_classic_generation<=0;last_system_window<=0;last_docs_generation<=0;end
        else if(last_ship_generation!=ship_generation || last_classic_generation!=classic_generation || last_system_window!=system_window_o || last_docs_generation!=docs_generation)begin
            system_generation_o<=system_generation_o+1'b1;last_ship_generation<=ship_generation;
            last_classic_generation<=classic_generation;last_system_window<=system_window_o;last_docs_generation<=docs_generation;
        end
    end
    always_ff @(posedge clk)begin
        if(!rst_n)begin restart_phase<=0;classic_vm_start<=0;classic_restart_halt<=0;end
        else begin
            classic_vm_start<=0;classic_restart_halt<=0;
            if(docs_command_stb && docs_command==5)begin restart_phase<=1;classic_restart_halt<=1;end
            else if(restart_phase==1 && !vm_busy)restart_phase<=2;
            else if(restart_phase==2)begin classic_vm_start<=1;restart_phase<=0;end
        end
    end
    always_ff @(posedge clk)begin
        if(!rst_n || app_clear)note_entry_seen<=0;
        else if(new_note_entry)note_entry_seen<=1;
    end
    jmr_system_actions u_system_actions (
        .clk(clk),.rst_n(rst_n),.action_stb((docs_command_stb && docs_command!=5) || new_note_entry || new_catalog_entry),.action(new_note_entry?4'd11:new_catalog_entry?4'd4:docs_command),
        .role(system_window_o[7:0]),.chosen_name(docs_chosen_name),.chosen_len(docs_chosen_len),.after_valid(docs_after_valid),.after_action(docs_after_action),.after_name(docs_after_name),.after_len(docs_after_len),
        .source_name(con_source_name),.source_len(con_source_name_len),.source_unnamed(con_unnamed),
        .catalog_go(actions_catalog_go),.catalog_active(actions_catalog_active),.catalog_addr(actions_catalog_addr),
        .catalog_done(disk_done),.catalog_error(disk_error),.catalog_count(desk_count),.catalog_data(desk_catalog_data),.catalog_size(desk_catalog_size),
        .stage_valid(actions_stage_valid),.stage_addr(actions_stage_addr),.stage_data(actions_stage_data),.stage_ready(actions_stage_ready),
        .console_ready(ready_lit),.console_failed(con_command_failed),.console_clear(kbd_clear),.keyboard_empty(kbd_empty),.keyboard_full(kbd_full),
        .vm_busy(vm_busy),.storage_busy(stor_busy),.disk_busy(disk_busy),.desktop_busy(desk_busy),.busy(actions_busy),.quit_pulse(actions_quit),.halt_pulse(actions_halt),
        .desktop_stb(actions_desk_stb),.desktop_on(actions_desk_on),.key_push(actions_key_push),.key_data(actions_key_data),
        .inject_stb(actions_inject),.inject_code(actions_inject_code),.doc_start(actions_doc_start),.doc_new(actions_doc_new),.doc_role(actions_doc_role),
        .set_name(actions_set_name),.target_name(actions_target_name),.target_len(actions_target_len),.catalog_prepared(actions_catalog_prepared),.restart_pulse(actions_restart),.error_pulse(actions_error)
    );
    assign mouse_ready = 1'b1;
    always_ff @(posedge clk)begin
        if(!rst_n || !vm_busy)begin mouse_pending<=0;pending_mouse_x<=320;pending_mouse_y<=240;pending_mouse_buttons<=0;end
        else begin
            if(mouse_pending && mouse_queue_ready)mouse_pending<=0;
            if(input_mouse_stb && !ui_consume && (mouse_pending || !mouse_queue_ready))begin
                mouse_pending<=1;pending_mouse_x<=input_mouse_x;pending_mouse_y<=pointer_source_y;pending_mouse_buttons<=input_mouse_buttons;
            end
        end
    end
    jmr_system_menu u_system_menu (
        .clk(clk),.rst_n(rst_n),.sample_valid(input_mouse_stb && !classic_consume && !docs_consume),.x(input_mouse_x),.y(input_mouse_y),.buttons(input_mouse_buttons),
        .key_hit(input_key_hit),
        .emit_enable(owned_keys ? 1'b1 : vm_busy ? (vm_key_evt_ready && !vm_kev_lat) : (!desk_busy && !disk_busy && !kbd_clear && ready_lit && !stor_busy)),
        .force_keyboard_stb(docs_keyboard_stb),.force_keyboard_on(docs_keyboard_on),
        .dismiss_about(system_about_o && dialog_key_stb && dialog_key_down && (dialog_key_code==13 || dialog_key_code==27)),
        .dismiss_menu(system_menu_o && dialog_key_stb && dialog_key_down && dialog_key_code==27),
        .inject_stb(classic_key_stb || actions_inject),.inject_code(actions_inject?actions_inject_code:classic_key_code),.leave_app(ui_quit || classic_restart_halt || actions_halt || classic_error_pulse),.guest_drag_o(ship_guest),
        .consume_pointer(ship_consume),.menu_open(system_menu_o),.keyboard_open(system_keyboard_o),.about_open(system_about_o),
        .shift_on(system_shift_o),.caps_on(system_caps_o),.ctrl_on(system_ctrl_o),.alt_on(system_alt_o),
        .pressed_index(system_pressed_o),.hold_keys(system_hold_o),.held_keys(system_held_o),.generation(ship_generation),.quit_pulse(ship_quit),.terminal_pulse(ui_terminal),
        .key_stb(ui_key_stb),.key_down(ui_key_down),.key_code_o(ui_key_code),.key_char_o(ui_key_char),
        .ascii_stb(ui_ascii_stb),.ascii_data(ui_ascii_data)
    );
    logic ship_op,ship_op_q,classic_op,classic_modal;
    logic [23:0] ship_rgb,ship_rgb_q,classic_rgb;
    jmr_system_documents u_documents (
        .clk(clk),.rst_n(rst_n),.app_clear(app_clear),.window_state(system_window_o),.source_name(con_source_name),.source_len(con_source_name_len),
        .unnamed(con_unnamed),.kernel_busy(actions_busy),.error_pulse(actions_error || classic_error_pulse),.descriptor_error(classic_error_pulse),.request_stb(classic_action_stb),.request_action(classic_action),.shortcut_save(save_shortcut),
        .sample_valid(input_mouse_stb),.x(input_mouse_x),.y(input_mouse_y),.buttons(input_mouse_buttons),.keyboard_open(system_keyboard_o),
        .key_stb(dialog_key_stb),.key_down(dialog_key_down),.key_code(dialog_key_code),.key_char(dialog_key_char),
        .consume_pointer(docs_consume),.consume_keys(docs_keys),.keyboard_set_stb(docs_keyboard_stb),.keyboard_set_on(docs_keyboard_on),
        .command_stb(docs_command_stb),.command(docs_command),.chosen_name(docs_chosen_name),.chosen_len(docs_chosen_len),
        .after_valid(docs_after_valid),.after_action(docs_after_action),.after_name(docs_after_name),.after_len(docs_after_len),
        .dialog(docs_dialog),.file_count(docs_file_count),.selected(docs_selected),.file_top(docs_file_top),.name_len(docs_name_len),.name_selected(docs_name_selected),.message_id(docs_message),
        .generation(docs_generation),.catalog_go(docs_catalog_go),.catalog_active(docs_catalog_active),.catalog_all(docs_catalog_all),.catalog_addr(docs_catalog_addr),
        .catalog_busy(disk_busy),.catalog_done(disk_done),.storage_busy(stor_busy),.desktop_busy(desk_busy),.catalog_count(desk_count),.catalog_data(desk_catalog_data),
        .label_valid(docs_label_valid),.label_row(docs_label_row),.label_data(docs_label_data),.label_col(docs_label_col),.label_commit(docs_label_commit),.label_ready(docs_label_ready)
    );
    jmr_classic_ui u_classic (
        .clk(clk),.rst_n(rst_n),.pixel_clk(pixel_clk),.app_clear(app_clear),.window_state(classic_window_q),.source_name(con_source_name),.source_name_len(con_source_name_len),
        .external_label_valid(docs_label_valid),.external_label_row(docs_label_row),.external_label_data(docs_label_data),.external_label_col(docs_label_col),.external_label_commit(docs_label_commit),.external_label_ready(docs_label_ready),
        .text_stb(classic_text_stb && !app_clear),.text_menu(classic_text_menu),.text_first(classic_text_first),.text_last(classic_text_last),.text_byte(classic_text_byte),
        .sample_valid(input_mouse_stb),.system_active(system_menu_o || system_about_o || docs_dialog!=0),.keyboard_open(system_keyboard_o),.guest_drag(ship_guest),.cancel_menu(classic_menu!=0 && dialog_key_stb && dialog_key_down && dialog_key_code==27),
        .x(input_mouse_x),.y(input_mouse_y),.buttons(input_mouse_buttons),.click_row(input_mouse_row),.consume_pointer(classic_consume),
        .key_stb(classic_key_stb),.key_code(classic_key_code),.action_stb(classic_action_stb),.action(classic_action),
        .generation(classic_generation),.descriptor_error(classic_error),.active_menu(classic_menu),
        .popup_left(classic_popup_left),.popup_count(classic_popup_count),.popup_row(classic_popup_row),
        .popup_static(classic_popup_static),.popup_dynamic(classic_popup_dynamic),.popup_enabled(classic_popup_enabled),
        .popup_static_rows(classic_static_rows),.popup_dynamic_rows(classic_dynamic_rows),.popup_enabled_rows(classic_enabled_rows),
        .label_raddr(classic_label_raddr),.label_pos(classic_label_pos),.beam_y(fb_y),.label_glyph(classic_label_glyph),.about_valid(classic_about_valid),.title_valid(classic_title_valid),.title_width(classic_title_width)
    );
    typedef struct packed {
        logic [31:0] window_state;
        logic [3:0] menu,count;
        logic [9:0] left_edge,title_width;
        logic [63:0] static_rows;logic [47:0] dynamic_rows;logic [7:0] enabled_rows;
        logic about_open,about_valid,title_valid;
        logic [2:0] dialog;
        logic [8:0] files,selected;
        logic [7:0] file_top,message_id;
        logic [3:0] name_len;logic name_selected;
        logic ship_menu,keyboard,shift_on,caps_on,ctrl_on,alt_on,hold_keys;
        logic [6:0] pressed;logic [69:0] held;
    } ui_snapshot_t;
    ui_snapshot_t ui_source,ui_pixels;
    always_comb begin
        ui_source.window_state=system_window_o;ui_source.menu=classic_menu;ui_source.count=classic_popup_count;
        ui_source.left_edge=classic_popup_left;ui_source.title_width=classic_title_width;
        ui_source.static_rows=classic_static_rows;ui_source.dynamic_rows=classic_dynamic_rows;ui_source.enabled_rows=classic_enabled_rows;
        ui_source.about_open=system_about_o;ui_source.about_valid=classic_about_valid && vm_busy && system_window_o[7:0]!=0 && system_window_o[7:0]!=3;
        ui_source.title_valid=classic_title_valid;ui_source.dialog=docs_dialog;ui_source.files=docs_file_count;ui_source.selected=docs_selected;
        ui_source.file_top=docs_file_top;ui_source.message_id=docs_message;ui_source.name_len=docs_name_len;ui_source.name_selected=docs_name_selected;
        ui_source.ship_menu=system_menu_o;ui_source.keyboard=system_keyboard_o;ui_source.shift_on=system_shift_o;ui_source.caps_on=system_caps_o;
        ui_source.ctrl_on=system_ctrl_o;ui_source.alt_on=system_alt_o;ui_source.hold_keys=system_hold_o;ui_source.pressed=system_pressed_o;ui_source.held=system_held_o;
    end
    jmr_ui_snapshot #(.WIDTH($bits(ui_snapshot_t))) u_ui_snapshot(.clk(clk),.rst_n(rst_n),.pixel_clk(pixel_clk),.source(ui_source),.pixels(ui_pixels));
    jmr_classic_overlay u_classic_overlay (
        .rst_n(rst_n),
        .pixel_clk(pixel_clk),.x(fb_x),.y(fb_y),.window_state(ui_pixels.window_state),
        .active_menu(ui_pixels.menu),.popup_count(ui_pixels.count),.popup_left(ui_pixels.left_edge),.popup_row(classic_popup_row),
        .popup_static_rows(ui_pixels.static_rows),.popup_dynamic_rows(ui_pixels.dynamic_rows),.popup_enabled_rows(ui_pixels.enabled_rows),
        .about_open(ui_pixels.about_open),.about_valid(ui_pixels.about_valid),.title_valid(ui_pixels.title_valid),.title_width(ui_pixels.title_width),
        .dialog(ui_pixels.dialog),.file_count(ui_pixels.files),.selected(ui_pixels.selected),.file_top(ui_pixels.file_top),.message_id(ui_pixels.message_id),
        .name_len(ui_pixels.name_len),.name_selected(ui_pixels.name_selected),.label_raddr(classic_label_raddr),.label_pos(classic_label_pos),.label_glyph(classic_label_glyph),
        .opaque(classic_op),.modal_opaque(classic_modal),.rgb(classic_rgb)
    );
    jmr_system_overlay u_system_overlay (
        .pixel_clk(pixel_clk),.x(fb_x),.y(fb_y),
        .menu_open(ui_pixels.ship_menu),.keyboard_open(ui_pixels.keyboard),.about_open(1'b0),.shift_on(ui_pixels.shift_on),.caps_on(ui_pixels.caps_on),
        .ctrl_on(ui_pixels.ctrl_on),.alt_on(ui_pixels.alt_on),.pressed_index(ui_pixels.pressed),.hold_keys(ui_pixels.hold_keys),.held_keys(ui_pixels.held),
        .opaque(ship_op),.rgb(ship_rgb)
    );
    always_ff @(posedge pixel_clk)begin ship_op_q<=ship_op;ship_rgb_q<=ship_rgb;end
    assign system_overlay_opaque_o=classic_modal || ship_op_q || classic_op;
    assign system_overlay_rgb_o=classic_modal?classic_rgb:ship_op_q?ship_rgb_q:classic_rgb;
    jmr_mouse_events u_mouse_events (
        .clk(clk), .rst_n(rst_n && vm_busy),
        .sample_valid(vm_busy && (mouse_pending || (input_mouse_stb && !ui_consume))), .sample_ready(mouse_queue_ready),
        .sample_x(mouse_pending?pending_mouse_x:input_mouse_x),.sample_y(mouse_pending?pending_mouse_y:pointer_source_y),
        .sample_buttons(mouse_pending?pending_mouse_buttons:input_mouse_buttons),
        .event_valid(mouse_event_valid), .event_data(mouse_event_data),
        .event_pop(mouse_event_pop)
    );
    logic fb_we /*verilator public_flat_rd*/; logic fb_swap, demo_fb_we, demo_fb_swap, vm_fb_we, vm_fb_swap;
    logic [18:0] fb_waddr, demo_fb_waddr, vm_fb_waddr;
    logic [7:0]  fb_wdata, demo_fb_wdata, vm_fb_wdata;
    logic frame_tick;
    localparam int FRAME_COUNT_W = (FRAME_DIV < 1) ? 1 : $clog2(FRAME_DIV + 1);
    logic [FRAME_COUNT_W-1:0] frame_div /*verilator public_flat_rw*/;
    // NEW: console loads .JSB into VM code BRAM
    logic        code_we /*verilator public_flat_rd*/;
    logic [14:0]  code_waddr /*verilator public_flat_rd*/;
    logic [31:0] code_wdata /*verilator public_flat_rd*/;
    logic        stor_get_byte, stor_nl_scan;
    logic [7:0]  stor_get_data;
    logic [15:0] stor_nl_count;
    // NEW: 4 MB external asset SRAM (jmr_sram_port) — console writes the ASET
    // payload during RUN load; the VM blitter reads sprite pixels while running.
    // The two masters never overlap (load completes before vm_start).
    logic [6:0]  stor_dbg_state;
    logic [15:0] stor_dbg_op_clk;
    logic [17:0] vm_src_setlen;
    logic        vm_src_setlen_stb;
    logic        cons_sram_req, cons_sram_we, vm_sram_req, vm_sram_we;
    logic [21:0] cons_sram_addr, vm_sram_addr;
    logic [15:0] cons_sram_wdata, vm_sram_wdata, sram_rdata;
    logic        sram_ack, sram_req, sram_we;
    logic [21:0] sram_addr;
    logic [15:0] sram_wdata;
    // NEW: ASET palette load (console) → palette BRAM (read by scanout/dump)
    logic        pal_we;
    logic [7:0]  pal_waddr;
    logic [23:0] pal_wdata;
    // NEW: VM getImageData reads the back bank (PYTHON canvas.back twin)
    logic [18:0] vm_dump_addr;
    logic        vm_dump_sel;
    logic [7:0]  dump_back_rdata;

    // Console ↔ storage
    logic        stor_open, stor_close, stor_readline, stor_putc;
    logic        stor_dir, stor_dir_next, stor_dir_all, stor_delete;
    logic [7:0]  stor_mode, stor_chan, stor_name_len, stor_putc_data;
    logic [15:0] stor_name_addr;
    logic        stor_busy, stor_done, stor_err, stor_eof;
    logic [7:0]  stor_line_len;

    // Native desktop shares FAT, WORK RAM, canvas and console with programs.
    logic desk_visible, desk_busy, desk_hold, desk_key_push;
    logic [7:0] desk_key_data;
    logic disk_busy, disk_done, disk_error, desk_catalog_go, desk_icon_go;
    logic [8:0] desk_count;
    logic [7:0] desk_icon_index, desk_catalog_data;
    logic [11:0] desk_catalog_addr;
    logic desk_icon_valid, desk_icon_ready, desk_icon_opaque;
    logic [4:0] desk_icon_x,desk_icon_y;
    logic [7:0] desk_icon_colour;
    logic desk_fb_we,desk_fb_swap;
    logic [18:0] desk_fb_addr;
    logic [7:0] desk_fb_data;
    logic desk_sram_req,desk_sram_we;
    logic [21:0] desk_sram_addr;
    logic [15:0] desk_sram_data;
    logic desk_stor_open,desk_stor_close,desk_stor_dir,desk_stor_next,desk_stor_get;
    logic [7:0] desk_stor_name_len;
    logic [31:0] stor_file_size,stor_dir_size;
    logic desk_mem_en,desk_mem_we;
    logic [15:0] desk_mem_addr;
    logic [7:0] desk_mem_wdata;
    logic con_mem_en,con_mem_we;
    logic [15:0] con_mem_addr;
    logic [7:0] con_mem_wdata;
    logic con_stor_open,con_stor_close,con_stor_readline,con_stor_get_byte,con_stor_nl_scan;
    logic con_stor_putc,con_stor_dir,con_stor_dir_next,con_stor_dir_all,con_stor_delete;
    logic [7:0] con_stor_mode,con_stor_chan,con_stor_name_len,con_stor_putc_data;
    logic [15:0] con_stor_name_addr;
    logic con_command_failed;
    logic con_interactive;
    logic desk_hidden;
    wire keyboard_feed_push=(kbd_push && !owned_keys && !save_shortcut)||desk_key_push||actions_key_push||(ui_ascii_stb && !owned_keys && !save_shortcut)||ui_quit;
    wire [7:0] keyboard_feed_data=ui_quit?8'd27:actions_key_push?actions_key_data:desk_key_push?desk_key_data:ui_ascii_stb?ui_ascii_data:kbd_data;
    assign desktop_visible_o=desk_visible;
    assign desktop_busy_o=desk_busy;
    assign desktop_count_o=desk_count;
    assign stor_open=disk_busy?desk_stor_open:con_stor_open;
    assign stor_close=disk_busy?desk_stor_close:con_stor_close;
    assign stor_dir=disk_busy?desk_stor_dir:con_stor_dir;
    assign stor_dir_next=disk_busy?desk_stor_next:con_stor_dir_next;
    assign stor_get_byte=disk_busy?desk_stor_get:con_stor_get_byte;
    assign stor_readline=!disk_busy&&con_stor_readline;
    assign stor_nl_scan=!disk_busy&&con_stor_nl_scan;
    assign stor_putc=!disk_busy&&con_stor_putc;
    assign stor_delete=!disk_busy&&con_stor_delete;
    assign stor_dir_all=disk_busy?(actions_catalog_active || (docs_catalog_active?docs_catalog_all:desk_hidden)):con_stor_dir_all;
    assign stor_mode=disk_busy?8'h49:con_stor_mode;
    assign stor_chan=disk_busy?8'd1:con_stor_chan;
    assign stor_name_addr=disk_busy?16'hb850:con_stor_name_addr;
    assign stor_name_len=disk_busy?desk_stor_name_len:con_stor_name_len;
    assign stor_putc_data=con_stor_putc_data;
    assign c_mem_en=disk_busy?desk_mem_en:con_mem_en;
    assign c_mem_we=disk_busy?desk_mem_we:con_mem_we;
    assign c_mem_addr=disk_busy?desk_mem_addr:con_mem_addr;
    assign c_mem_wdata=disk_busy?desk_mem_wdata:con_mem_wdata;
    // Mem masters
    logic        c_mem_en, c_mem_we, c_mem_gnt;
    logic [15:0] c_mem_addr;
    logic [7:0]  c_mem_wdata, c_mem_rdata;
    logic        s_mem_en, s_mem_we, s_mem_gnt;
    logic [15:0] s_mem_addr;
    logic [7:0]  s_mem_wdata, s_mem_rdata;

    assign joy_out = joy_in;

    // ---- work RAM 0xB000-0xDFFF (12 KB) — NAME/STORAGE only -------------
    // 2026-08-22: array moved to external SRAM (WORK_SRAM_BASE, 1 byte per
    // 16-bit word). Both masters already stall on gnt, so the variable
    // req/ack latency is safe by construction.
    localparam logic [21:0] WORK_SRAM_BASE = 22'd3731456;
    logic        ram_we;
    logic [13:0] ram_addr;
    logic [7:0]  ram_wdata, ram_rdata;
    logic        ram_req;
    logic        ram_sel_stor; // 1 = storage master won
    logic        work_req, work_we_l, work_ack, work_sel_stor;
    // 2026-08-27 DIR wedge (board E-telemetry: console stuck C_DIR_CH,
    // storage idle, 21.5s ?IO): the work-RAM request latch waits on the
    // sram fabric (DDR3 bridge on board) with no reissue protection — a
    // lost/misattributed ack starves it forever. Same class the VM port
    // already guards against (vm_ack_hold). Reissue after 2^12 idle-held
    // cycles (41us >> any legit bridge latency); work ops are idempotent
    // (byte reads / same-value writes) so reissue is safe.
    logic [11:0] work_wd;
    logic        work_pause;
    logic [13:0] work_addr_l;
    logic [7:0]  work_wdata_l;
    logic work_retire;

    wire in_work_c = (c_mem_addr >= 16'hB000) && (c_mem_addr < 16'hE000);
    wire in_work_s = (s_mem_addr >= 16'hB000) && (s_mem_addr < 16'hE000);

    // Storage has priority when requesting (FAT walks cannot stall)
    always_comb begin
        ram_req = 1'b0;
        ram_we = 1'b0;
        ram_addr = 14'h0;
        ram_wdata = 8'h0;
        ram_sel_stor = 1'b0;
        if (s_mem_en && in_work_s) begin
            ram_req = 1'b1;
            ram_sel_stor = 1'b1;
            ram_we = s_mem_we;
            ram_addr = 14'(s_mem_addr - 16'hB000);
            ram_wdata = s_mem_wdata;
        end else if (c_mem_en && in_work_c) begin
            ram_req = 1'b1;
            ram_we = c_mem_we;
            ram_addr = 14'(c_mem_addr - 16'hB000);
            ram_wdata = c_mem_wdata;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ram_rdata <= 8'h00;
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            work_req <= 1'b0;
            work_wd <= 12'd0;
            work_pause <= 1'b0;
            work_we_l <= 1'b0;
            work_sel_stor <= 1'b0;
            work_addr_l <= '0;
            work_wdata_l <= '0;
            work_retire <= 1'b0;
        end else begin
            s_mem_gnt <= 1'b0;
            c_mem_gnt <= 1'b0;
            if (work_retire) begin
                // A level-requesting client observes gnt on this beat.
                // Let it withdraw mem_en before accepting another request;
                // otherwise its completed read is submitted a second time.
                work_retire <= 1'b0;
            end else if (work_pause) begin
                // one-cycle gap: fabric sees req fall, then the same latched
                // request re-presents (addr/data/sel untouched)
                work_pause <= 1'b0;
                work_req   <= 1'b1;
            end else if (work_req) begin
                if (work_ack) begin
                    work_req <= 1'b0;
                    work_retire <= 1'b1;
                    work_wd  <= 12'd0;
                    ram_rdata <= work_we_l ? work_wdata_l : sram_rdata[7:0];
                    if (work_sel_stor) s_mem_gnt <= 1'b1;
                    else c_mem_gnt <= 1'b1;
                end else begin
                    work_wd <= work_wd + 12'd1;
                    if (&work_wd) begin
                        // ack lost: withdraw for one cycle and reissue
                        work_req   <= 1'b0;
                        work_pause <= 1'b1;
                        work_wd    <= 12'd0;
                    end
                end
            end else if (ram_req) begin
                work_req <= 1'b1;
                work_we_l <= ram_we;
                work_addr_l <= ram_addr;
                work_wdata_l <= ram_wdata;
                work_sel_stor <= ram_sel_stor;
            end
        end
    end
    assign s_mem_rdata = ram_rdata;
    assign c_mem_rdata = ram_rdata;

    jmr_keyboard_fifo u_kbd (
        .clk(clk), .rst_n(rst_n),
        .push(keyboard_feed_push), .push_data(keyboard_feed_data),
        .pop(kbd_pop), .clear(kbd_clear),
        .data(kbd_q), .empty(kbd_empty), .full(kbd_full)
    );

    jmr_video_vram u_vid (
        .clk(clk), .scan_clk(pixel_clk), .rst_n(rst_n),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .busy(video_busy), .cursor(cursor),
        .scan_addr(scan_addr), .scan_data(scan_data),
        .dump_addr(dump_addr), .dump_data(dump_data)
    );

    // Compile handshake: the console owns storage and the SOURCE window,
    // the VM runs the compiler as an ordinary program.
    logic [17:0] cons_src_len;
    logic        cmp_arm;

    jmr_console_engine u_cons (
        .clk(clk), .rst_n(rst_n),
        .enable(standalone_mode && !game_mode && !desk_visible && !desk_hold && !disk_busy),
        .kbd_empty(kbd_empty), .kbd_data(kbd_q),
        .kbd_pop(kbd_pop), .kbd_clear(kbd_clear),
        .video_busy(video_busy),
        .cls(cls), .put_en(put_en), .put_char(put_char), .print_nl(print_nl),
        .ready_lit(ready_lit), .command_failed_o(con_command_failed), .interactive_o(con_interactive),.system_role_o(con_system_role),.system_stage_o(con_system_stage),
        .ui_source_name_o(con_source_name),.ui_source_len_o(con_source_name_len),.ui_unnamed_o(con_unnamed),
        .ui_doc_start(actions_doc_start),.ui_doc_new(actions_doc_new),.ui_doc_role(actions_doc_role),
        .ui_stage_valid(actions_stage_valid),.ui_stage_addr(actions_stage_addr),.ui_stage_data(actions_stage_data),.ui_stage_ready(actions_stage_ready),
        .ui_set_name(actions_set_name),.ui_name(actions_target_name),.ui_name_len(actions_target_len),
        .src_len_o(cons_src_len),
        .src_setlen_i(vm_src_setlen),
        .src_setlen_stb_i(vm_src_setlen_stb),
        .cmp_done_i(vm_cmp_done),
        .cmp_status_i(vm_cmp_status),
        .cmp_msglen_i(vm_cmp_msglen),
        .cmp_len_i(vm_cmp_len),
        .vm_busy_i(vm_busy),
        .cmp_arm_o(cmp_arm),
        .dbg_state(cons_dbg_state_o),
        .run_pulse(run_pulse),
        .vm_start(vm_start),
        .halt_pulse(halt_pulse),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .sram_req(cons_sram_req), .sram_we(cons_sram_we),
        .sram_addr(cons_sram_addr), .sram_wdata(cons_sram_wdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd2)),
        .sram_rdata(sram_rdata),
        .pal_we(pal_we), .pal_waddr(pal_waddr), .pal_wdata(pal_wdata),
        .stor_open(con_stor_open), .stor_mode(con_stor_mode), .stor_chan(con_stor_chan),
        .stor_name_addr(con_stor_name_addr), .stor_name_len(con_stor_name_len),
        .stor_close(con_stor_close), .stor_readline(con_stor_readline),
        .stor_get_byte(con_stor_get_byte), .stor_get_data(stor_get_data),
        .stor_nl_scan(con_stor_nl_scan), .stor_nl_count(stor_nl_count),
        .stor_putc(con_stor_putc), .stor_putc_data(con_stor_putc_data),
        .stor_dir(con_stor_dir), .stor_dir_next(con_stor_dir_next),
        .stor_dir_all(con_stor_dir_all), .stor_delete(con_stor_delete),
        .stor_busy(stor_busy), .stor_done(stor_done && !disk_busy),
        .stor_err(stor_err), .stor_eof(stor_eof), .stor_line_len(stor_line_len),
        .mem_en(con_mem_en), .mem_we(con_mem_we), .mem_addr(con_mem_addr),
        .mem_wdata(con_mem_wdata), .mem_rdata(c_mem_rdata), .mem_gnt(c_mem_gnt && !disk_busy),
        .jsb_tether_stb(jsb_tether_stb), .jsb_tether_data(jsb_tether_data),
        .jsb_tether_eof(jsb_tether_eof), .jsb_tether_src(jsb_tether_src),
        .jsb_tether_big(jsb_tether_big),
        .jsb_tether_crc_err(jsb_tether_crc_err),
        .vm_gdbg_i(vm_gdbg),
        .jsb_tether_rdy(jsb_tether_rdy),
        .sim_src_bypass(sim_src_bypass), .sim_src_lines(sim_src_lines)
    );

    storage_engine #(
        .SD_INIT_DIV(SD_INIT_DIV),
        .SD_RUN_DIV(SD_RUN_DIV)
    ) u_stor (
        .clk(clk), .rst_n(rst_n),
        .start_open(stor_open), .mode_in(stor_mode), .chan_in(stor_chan),
        .name_addr(stor_name_addr), .name_len(stor_name_len),
        .start_close(stor_close), .start_readline(stor_readline),
        .start_readfield(1'b0), .start_get_byte(stor_get_byte), .get_byte(stor_get_data),
        .start_nl_scan(stor_nl_scan), .nl_count(stor_nl_count),
        .start_putc(stor_putc), .putc_data(stor_putc_data),
        .start_dir(stor_dir), .start_dir_next(stor_dir_next),
        .dir_show_all(stor_dir_all), .dir_show_system(disk_busy), .dir_raw_names(disk_busy), .file_size_o(stor_file_size),.dir_size_o(stor_dir_size),
        .start_delete(stor_delete),
        .card_present(sd_card_present),
        .dbg_state(stor_dbg_state), .dbg_op_clk(stor_dbg_op_clk),
        .line_len(stor_line_len), .eof(stor_eof), .err(stor_err),
        .done(stor_done), .busy(stor_busy),
        .sink_wr_en(1'b0), .sink_wr_char(8'h0), .sink_busy(),
        .mem_en(s_mem_en), .mem_we(s_mem_we), .mem_addr(s_mem_addr),
        .mem_wdata(s_mem_wdata), .mem_rdata(s_mem_rdata), .mem_gnt(s_mem_gnt),
        .spi_sck(sd_sck), .spi_mosi(sd_mosi), .spi_miso(sd_miso), .spi_cs_n(sd_cs_n)
    );

    // Session-1 (2026-08-23): single persistent draw bank; present engine
    // streams it to the DDR3 front; scanout prefetches lines back.
    logic [18:0] fbp_copy_raddr;
    logic [7:0]  fbp_copy_rdata;
    logic [1199:0] fb_dirty_blocks;
    logic fb_dirty_clear;
    logic        fb_present_busy /*verilator public_flat_rd*/;
    logic        fbp_sram_req, fbp_sram_we;
    logic [21:0] fbp_sram_addr;
    logic [15:0] fbp_sram_wdata;
    logic        scan_sram_req;
    logic [21:0] scan_sram_addr;
    // C1 (run 50/51): full-rate raster/blit/imgd engine — the VM hands
    // per-op scalars over a go/busy handshake; the engine writes the FB
    // port at core rate and reads sprites/ImageData as arbiter owner 6.
    logic        rast_go, rast_busy, rast_aset;
    logic [1:0]  rast_mode;
    logic [9:0]  rast_w, rast_h;
    logic signed [11:0] rast_dx, rast_dy;
    logic [7:0]  rast_color;
    logic [15:0] rast_sx, rast_sy, rast_qx, rast_rxr, rast_qy, rast_ryr;
    logic [22:0] rast_sbase;
    logic [15:0] rast_stride;
    logic        rast_flip_x, rast_flip_y; // neg-xform: mirror dest col/row
    logic        rast_fb_we;
    logic [18:0] rast_fb_waddr;
    logic [7:0]  rast_fb_wdata;
    logic        rast_sram_req;
    logic [21:0] rast_sram_addr;
    // rast_done: busy can rise AND fall between two VM beats (a 1x1
    // fill is ~2 clk) — a level the VM samples at beat rate, set on the
    // falling edge of busy, cleared at the next op's go edge (the
    // latch-until-beat pattern from TIMING_WALL Class A).
    logic rast_go_q, rast_busy_q, rast_done;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rast_go_q <= 1'b0;
            rast_busy_q <= 1'b0;
            rast_done <= 1'b0;
        end else begin
            rast_go_q <= rast_go;
            rast_busy_q <= rast_busy;
            if (rast_go && !rast_go_q) rast_done <= 1'b0;
            else if (rast_busy_q && !rast_busy) rast_done <= 1'b1;
        end
    end
    jmr_raster_engine u_rast (
        .clk(clk), .rst_n(rst_n),
        .go(rast_go), .mode(rast_mode),
        .dx(rast_dx), .dy(rast_dy), .w(rast_w), .h(rast_h),
        .color(rast_color),
        .sx(rast_sx), .sy(rast_sy),
        .qx(rast_qx), .rxr(rast_rxr), .qy(rast_qy), .ryr(rast_ryr),
        .sbase(rast_sbase), .stride(rast_stride), .aset(rast_aset),
        .flip_x(rast_flip_x), .flip_y(rast_flip_y),
        .busy(rast_busy),
        .fb_we(rast_fb_we), .fb_waddr(rast_fb_waddr), .fb_wdata(rast_fb_wdata),
        .sram_req(rast_sram_req), .sram_addr(rast_sram_addr),
        .sram_rdata(sram_rdata), .sram_ack(sram_ack && (sram_owner_q == 3'd6))
    );
    jmr_mini_fb u_fb (
        .wr_clk(clk), .rst_n(rst_n),
        .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
        .copy_raddr(fbp_copy_raddr), .copy_rdata(fbp_copy_rdata),
        .dirty_blocks(fb_dirty_blocks), .dirty_clear(fb_dirty_clear),
        .dump_raddr(vm_dump_sel ? vm_dump_addr : dump_fb_raddr),
        .dump_rdata(dump_fb_rdata)
    );
    // canvas is single-surface now: back/front dumps are the same data
    assign dump_back_rdata = dump_fb_rdata;
    assign stor_dbg_state_o = stor_dbg_state;
    assign stor_dbg_op_clk_o = stor_dbg_op_clk;
    assign game_view_o = game_view || desk_visible;
    wire canvas_program_mode=game_mode || (con_interactive && vm_busy);
    logic game_mode_q2;
    always_ff @(posedge clk) game_mode_q2 <= canvas_program_mode;
    // Board 2026-08-26: the run-44 FB zero-fill ran, but scan switched
    // to the FB view immediately on game entry and showed the OLD DDR3
    // content during the ~10ms clear (the "previous game flash"). Hold
    // the view on the console until the clear pass completes.
    logic game_view;
    always_ff @(posedge clk) begin
        if (!rst_n || !canvas_program_mode) game_view <= 1'b0;
        else if (canvas_program_mode && game_mode_q2 && !fb_present_busy) game_view <= 1'b1;
    end
    jmr_fb_present u_fbpres (
        .clk(clk), .rst_n(rst_n),
        .clear_go(canvas_program_mode && !game_mode_q2), // scrub old FB on program entry
        .swap(fb_swap), .busy(fb_present_busy),
        .dirty_blocks(fb_dirty_blocks), .dirty_clear(fb_dirty_clear),
        .copy_raddr(fbp_copy_raddr), .copy_rdata(fbp_copy_rdata),
        .sram_req(fbp_sram_req), .sram_we(fbp_sram_we),
        .sram_addr(fbp_sram_addr), .sram_wdata(fbp_sram_wdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd4))
    );
    jmr_fb_scanout u_fbscan (
        .clk(clk), .rst_n(rst_n),
        .sram_req(scan_sram_req), .sram_addr(scan_sram_addr),
        .sram_rdata(sram_rdata),
        .sram_ack(sram_ack && (sram_owner_q == 3'd1)),
        .game_viewport(system_viewport_o && system_window_o[7:0]==8),.pixel_clk(pixel_clk),
        .fb_x(fb_x), .fb_y(fb_y),
        .fb_rdata(fb_rdata)
    );

    jmr_rectdemo_engine u_demo (
        .clk(clk), .rst_n(rst_n),
        .start(run_pulse),
        .busy(demo_busy), .done(demo_done),
        .fb_we(demo_fb_we), .fb_waddr(demo_fb_waddr),
        .fb_wdata(demo_fb_wdata), .fb_swap(demo_fb_swap)
    );

    // ~60 Hz frame tick for startLoop (100e6/60 ≈ 1.67e6)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            frame_div <= '0;
            frame_tick <= 1'b0;
        end else begin
            frame_tick <= 1'b0;
            if (frame_div == FRAME_COUNT_W'(FRAME_DIV)) begin
                frame_div <= '0;
                frame_tick <= 1'b1;
            end else frame_div <= frame_div + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // div8 VM clock. BUFGCE keeps vm_clk rising edges a subset of clk
    // rising edges, so clk<->vm_clk boundary paths are ordinary same-tree
    // 10 ns paths (constraints/nexys_video.xdc adds the generated clock).
    // The Verilator branch has the same contract: vm_clk rises exactly at
    // clk edges where the registered vm_ce is high, so sim and silicon
    // sample identically at the boundary.
    logic vm_ce;
    logic vm_clk;
    generate if (VM_CLK_DIV == 1) begin : g_vmclk_pass
        assign vm_ce  = 1'b1;
        assign vm_clk = clk;
    end else begin : g_vmclk_div
        logic [$clog2(VM_CLK_DIV)-1:0] vmdiv_cnt;
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                vmdiv_cnt <= '0;
                vm_ce     <= 1'b0;
            end else begin
                vmdiv_cnt <= (vmdiv_cnt == VM_CLK_DIV - 1) ? '0 : vmdiv_cnt + 1'b1;
                vm_ce     <= (vmdiv_cnt == VM_CLK_DIV - 2);
            end
        end
`ifdef VERILATOR
        // BUFGCE latches CE while clk is LOW; gating with the raw vm_ce
        // glitches (vm_ce rises just after a posedge while clk is still
        // high -> spurious vm_clk edge mid-window, VM clocks twice per
        // beat: the event latch was consumed at the glitch edge AND the
        // real edge, double-enqueuing every key event). Register the
        // gate on negedge = exact BUFGCE semantics.
        logic vm_ce_n;
        always_ff @(negedge clk) vm_ce_n <= vm_ce;
        assign vm_clk = clk & vm_ce_n;
`else
        BUFGCE u_vm_bufgce (.I(clk), .CE(vm_ce), .O(vm_clk));
`endif
    end endgenerate

    // Assert immediately, then release on VM edges. The divided clock is
    // stopped during board reset, so retain reset for two actual VM edges.
    // This also keeps the board-wide fast reset out of the VM's data funnels.
    (* ASYNC_REG="TRUE" *) logic [1:0] vm_reset_release;
    always_ff @(posedge vm_clk or negedge rst_n)begin
        if(!rst_n)vm_reset_release<=0;
        else vm_reset_release<={vm_reset_release[0],1'b1};
    end

    // 100 MHz strobes last one clk cycle; the VM samples only on vm_ce
    // beats. Latch each until the beat that consumes it. Set wins over
    // clear: a strobe landing ON a beat is held for the next one (the
    // sampling edge reads the pre-edge value, so nothing is lost).
    logic       vm_start_lat, vm_stop_lat, vm_ftick_lat, vm_kev_lat;
    logic ui_quit_pending;
    always_ff @(posedge clk)begin
        if(!rst_n)ui_quit_pending<=0;
        else if(ui_quit)ui_quit_pending<=1;
        else if(ready_lit && !vm_busy && !stor_busy && !disk_busy)ui_quit_pending<=0;
    end

    logic [7:0] vm_kev_code_lat,vm_kev_char_lat;
    logic       vm_kev_down_lat;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vm_start_lat <= 1'b0; vm_stop_lat <= 1'b0;
            vm_ftick_lat <= 1'b0; vm_kev_lat  <= 1'b0;
            vm_kev_code_lat <= 8'd0; vm_kev_char_lat<=0; vm_kev_down_lat <= 1'b0;
        end else begin
            if ((vm_start | sim_vm_start | classic_vm_start | actions_restart) && !ui_quit_pending && !ui_quit) vm_start_lat <= 1'b1;
            else if (vm_ce)               vm_start_lat <= 1'b0;
            if ((keyboard_feed_push && keyboard_feed_data == 8'h1B) || ui_quit || halt_pulse || classic_restart_halt || actions_halt || classic_error_pulse)
                                          vm_stop_lat <= 1'b1;
            else if (vm_ce)               vm_stop_lat <= 1'b0;
            if (frame_tick | sim_frame_pulse) vm_ftick_lat <= 1'b1;
            else if (vm_ce)               vm_ftick_lat <= 1'b0;
            if ((key_evt_stb || ui_key_stb) && !owned_keys && !save_shortcut) begin
                vm_kev_lat      <= 1'b1;
                vm_kev_code_lat <= ui_key_stb?ui_key_code:key_evt_code;
                vm_kev_char_lat <= ui_key_stb?ui_key_char:key_evt_char;
                vm_kev_down_lat <= ui_key_stb?ui_key_down:key_evt_down;
            end else if (vm_ce)           vm_kev_lat <= 1'b0;
        end
    end

    // sram ack shim. The arbiter ack is one clk cycle; the VM samples on
    // vm_ce beats only, and its FSM does not obey either simple contract:
    // some seams re-arm sram_req for the NEXT transaction on the very
    // consume beat (sprite demand-load -> first blit fetch), and some
    // sites issue a request but sample the ack several beats later. So
    // the hold is MATCH-based: latch the served request (addr/we/wdata)
    // with the ack, deliver the ack only while the VM's live request
    // still equals the held one, and clear only at a beat where it no
    // longer matches (transaction consumed or superseded). A same-request
    // re-delivery is idempotent (same-addr read returns the same data; a
    // same-addr/wdata write already committed); a changed request drops
    // the orphan and is re-served one beat later. The arbiter's VM grant
    // is blocked while anything is held, so at most one serve is in
    // flight per beat window and an ack can never race a consume.
    logic        vm_ack_hold;
    logic [15:0] vm_rdata_hold;
    logic [21:0] vm_held_addr;
    logic        vm_held_we;
    logic [15:0] vm_held_wdata;
    logic        vm_req_match;

    // Compile handshake between the console (which owns storage and the
    // SOURCE window) and the VM (which runs the compiler as a program).
    logic        vm_cmp_done;
    logic [7:0]  vm_cmp_status;
    logic [20:0] vm_cmp_len;
    logic [6:0]  vm_cmp_msglen;

    jmr_js_vm #(.CODE_HEX("invaders_jsb.hex")) u_vm (
        .clk(vm_clk), .clk_code_w(clk), .rst_n(vm_reset_release[1]),
        .start(vm_start_lat),
        // V1.5 standalone compile: source length in, exit report out.
        .src_len_i(cons_src_len),
        .src_setlen_o(vm_src_setlen),
        .src_setlen_stb_o(vm_src_setlen_stb),
        .cmp_done_o(vm_cmp_done),
        .cmp_status_o(vm_cmp_status),
        .cmp_len_o(vm_cmp_len),
        .cmp_msglen_o(vm_cmp_msglen),
        .stop(vm_stop_lat),
        .frame_tick(vm_ftick_lat),
        .joy_in(joy_in),
        .analog_x(analog_x), .analog_y(analog_y), .joy_btn(joy_btn),
        .key_evt_stb(vm_kev_lat),
        .key_evt_code(vm_kev_code_lat),
        .key_evt_down(vm_kev_down_lat),.key_evt_char(vm_kev_char_lat),.key_evt_ready(vm_key_evt_ready),
        .sysw_toggle_o(vm_sysw_toggle),.sysw_field_o(vm_sysw_field),.sysw_value_o(vm_sysw_value),
        .ui_text_toggle_o(vm_text_toggle),.ui_text_menu_o(vm_text_menu),.ui_text_first_o(vm_text_first),.ui_text_last_o(vm_text_last),.ui_text_byte_o(vm_text_byte),
        .mouse_evt_valid(mouse_event_valid), .mouse_evt_data(mouse_event_data),
        .mouse_evt_pop(mouse_event_pop),
        .code_we(code_we), .code_waddr(code_waddr), .code_wdata(code_wdata),
        .busy(vm_busy), .done(vm_done),
        .vdbg_o(vdbg_o), .vdbg_fault_o(vdbg_fault_o),
        .vm_hdbg(vm_hdbg), .vm_fdbg(vm_fdbg), .vm_fdbg_v(vm_fdbg_v),
        .vm_ftrace(vm_ftrace), .vm_gdbg(vm_gdbg),
        .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .fb_we(vm_fb_we), .fb_waddr(vm_fb_waddr),
        .fb_wdata(vm_fb_wdata), .fb_swap(vm_fb_swap),
        .fb_present_busy(fb_present_busy),
        .fb_dump_addr(vm_dump_addr), .fb_dump_sel(vm_dump_sel),
        .fb_dump_back(dump_back_rdata),
        .fb_dump_front(dump_fb_rdata),
        .sram_req(vm_sram_req), .sram_addr(vm_sram_addr),
        .sram_we(vm_sram_we), .sram_wdata(vm_sram_wdata),
        .sram_rdata(vm_ack_hold ? vm_rdata_hold : sram_rdata),
        .sram_ack(vm_ack_hold && vm_req_match_q),
        .rast_go(rast_go), .rast_mode(rast_mode),
        .rast_dx(rast_dx), .rast_dy(rast_dy),
        .rast_w(rast_w), .rast_h(rast_h),
        .rast_color(rast_color),
        .rast_sx(rast_sx), .rast_sy(rast_sy),
        .rast_qx(rast_qx), .rast_rxr(rast_rxr),
        .rast_qy(rast_qy), .rast_ryr(rast_ryr),
        .rast_sbase(rast_sbase), .rast_stride(rast_stride),
        .rast_aset(rast_aset),
        .rast_flip_x(rast_flip_x), .rast_flip_y(rast_flip_y),
        .rast_done(rast_done)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vm_ack_hold   <= 1'b0;
            vm_rdata_hold <= 16'd0;
        end else if (sram_ack && (sram_owner_q == 3'd5)) begin
            vm_ack_hold   <= 1'b1;
            vm_rdata_hold <= sram_rdata;
            vm_held_addr  <= sram_addr;
            vm_held_we    <= sram_we;
            vm_held_wdata <= sram_wdata;
        end else if (vm_ce && !vm_req_match) begin
            vm_ack_hold   <= 1'b0;
        end
    end
    assign vm_req_match = vm_sram_req
        && (vm_held_addr == vm_sram_addr)
        && (vm_held_we == vm_sram_we)
        && (!vm_sram_we || (vm_held_wdata == vm_sram_wdata));
    // Registered copy for the DELIVERY side only (run-32: the comb
    // compare fed VM clock-enables at -0.13). Both compare operands are
    // stable from the ack to the beat that consumes it (the VM holds its
    // request while waiting; held_* freeze at the ack), so the one-clk
    // lag never changes the delivered value: an ack at clk j is
    // consumable at the beat >= j+1, exactly as before. The hold-clear
    // keeps the comb match (core-internal, short).
    logic vm_req_match_q;
    always_ff @(posedge clk) vm_req_match_q <= vm_req_match;

    // Asset-SRAM arbiter — console (load) wins; the VM reads sprite pixels
    // and, since 2026-08-21, also streams the ImageData snapshot (read AND
    // write) at the top of the bank. The two masters still never overlap
    // (load completes before vm_start).
    // Owner is latched per transaction so a request that arrives mid-flight
    // cannot steal the address/ack. Priority (Session-1): scanout line
    // prefetch is TOP (a starved line buffer is visible glass) > console
    // (load) > work RAM > FB present > VM.
    // Run 55 (-0.270 family, run 54): per-client ACK gates use the
    // REGISTERED owner. The comb sram_owner resolves the next grant from
    // live requests (incl. vm_sram_req on vm_clk), so gating acks with
    // it dragged the whole request cone into every client's clock-enable
    // (worst: vm_sram_req -> fbscan linebuf CE, 8 levels). Logically a
    // false path — an ack implies the owner was latched — but the tools
    // cannot see that. Every ack source (sim model, bridge cache/merge/
    // read) is registered >=1 cycle after grant, so sram_owner_q is
    // always valid at ack time. Request-side muxes stay comb (they must
    // present the request at grant).
    logic [2:0] sram_owner_q;
    logic [2:0] sram_owner;
    always_comb begin
        sram_owner = sram_owner_q;
        if (sram_owner_q == 3'd0) begin
            if (scan_sram_req)      sram_owner = 3'd1;
            else if (cons_sram_req) sram_owner = 3'd2;
            else if (work_req)      sram_owner = 3'd3;
            else if (fbp_sram_req)  sram_owner = 3'd4;
            else if (rast_sram_req) sram_owner = 3'd6;
            else if (desk_sram_req) sram_owner = 3'd7;
            else if (vm_sram_req && !vm_ack_hold) sram_owner = 3'd5;
        end
    end
    always_ff @(posedge clk) begin
        if (!rst_n) sram_owner_q <= 3'd0;
        else        sram_owner_q <= sram_ack ? 3'd0 : sram_owner;
    end
    assign sram_req   = (sram_owner == 3'd1) ? scan_sram_req :
                        (sram_owner == 3'd2) ? cons_sram_req :
                        (sram_owner == 3'd3) ? work_req :
                        (sram_owner == 3'd4) ? fbp_sram_req :
                        (sram_owner == 3'd6) ? rast_sram_req :
                        (sram_owner == 3'd7) ? desk_sram_req :
                        (sram_owner == 3'd5) ? vm_sram_req : 1'b0;
    assign sram_we    = (sram_owner == 3'd2) ? cons_sram_we :
                        (sram_owner == 3'd3) ? work_we_l :
                        (sram_owner == 3'd4) ? fbp_sram_we :
                        (sram_owner == 3'd7) ? desk_sram_we :
                        (sram_owner == 3'd5) ? vm_sram_we : 1'b0; // 6: read-only
    assign sram_addr  = (sram_owner == 3'd1) ? scan_sram_addr :
                        (sram_owner == 3'd2) ? cons_sram_addr :
                        (sram_owner == 3'd3) ? (WORK_SRAM_BASE + 21'(work_addr_l)) :
                        (sram_owner == 3'd4) ? fbp_sram_addr :
                        (sram_owner == 3'd6) ? rast_sram_addr :
                        (sram_owner == 3'd7) ? desk_sram_addr :
                                               vm_sram_addr;
    assign sram_wdata = (sram_owner == 3'd2) ? cons_sram_wdata :
                        (sram_owner == 3'd3) ? {8'd0, work_wdata_l} :
                        (sram_owner == 3'd4) ? fbp_sram_wdata :
                        (sram_owner == 3'd7) ? desk_sram_data : vm_sram_wdata;
    assign work_ack   = sram_ack && (sram_owner_q == 3'd3);

    // NEW: behavioral 4 MB SRAM (FPGA-SIM, SRAM_INTERNAL=1). Board uses
    // #(.SRAM_INTERNAL(0)) and the MIG DDR3 bridge on these ports.
    generate
        if (SRAM_INTERNAL) begin : g_sram
            jmr_sram_model u_sram (
                .clk(clk), .rst_n(rst_n),
                .req(sram_req), .we(sram_we), .addr(sram_addr),
                .wdata(sram_wdata), .rdata(sram_rdata), .ack(sram_ack)
            );
            assign sram_ext_req   = 1'b0;
            assign sram_ext_we    = 1'b0;
            assign sram_ext_addr  = 21'd0;
            assign sram_ext_wdata = 16'd0;
        end else begin : g_ext
            assign sram_ext_req   = sram_req;
            assign sram_ext_we    = sram_we;
            assign sram_ext_addr  = sram_addr;
            assign sram_ext_wdata = sram_wdata;
            assign sram_rdata     = sram_ext_rdata;
            assign sram_ack       = sram_ext_ack;
        end
    endgenerate

    // NEW: per-title 256-entry palette (loaded from the ASET section on RUN)
    logic [23:0] title_pal_rdata, desktop_pal_rdata;
    logic [1:0] desk_visible_pix;
    always_ff @(posedge pixel_clk) begin
        desk_visible_pix <= {desk_visible_pix[0],desk_visible};
        desktop_pal_rdata <= {{pal_raddr[7:5],pal_raddr[7:5],pal_raddr[7:6]},
                             {pal_raddr[4:2],pal_raddr[4:2],pal_raddr[4:3]},
                             {pal_raddr[1:0],pal_raddr[1:0],pal_raddr[1:0],pal_raddr[1:0]}};
    end
    assign pal_rdata=desk_visible_pix[1]?desktop_pal_rdata:title_pal_rdata;
    jmr_palette_bram u_palette (
        .wr_clk(clk), .rd_clk(pixel_clk),
        .we(pal_we), .waddr(pal_waddr), .wdata(pal_wdata),
        .raddr(pal_raddr), .rdata(title_pal_rdata)
    );

    // Mux FB writers — VM preferred while busy
    // C1: the raster engine owns the FB write port while busy — the VM
    // is blocked on rast_busy then, so the paths are mutually exclusive
    // by the handshake, and the mux only arbitrates the idle default.
    // Select on busy OR the write itself: the engine's LAST pixel write
    // asserts one clk after busy falls (registered fb_we), and a 1x1 op
    // IS its last pixel — keying on busy alone dropped it.
    assign fb_we    = desk_fb_we ? desk_fb_we : (rast_busy || rast_fb_we) ? rast_fb_we    : vm_busy ? vm_fb_we    : demo_fb_we;
    assign fb_waddr = desk_fb_we ? desk_fb_addr : (rast_busy || rast_fb_we) ? rast_fb_waddr : vm_busy ? vm_fb_waddr : demo_fb_waddr;
    assign fb_wdata = desk_fb_we ? desk_fb_data : (rast_busy || rast_fb_we) ? rast_fb_wdata : vm_busy ? vm_fb_wdata : demo_fb_wdata;
    // vm_fb_swap is a vm_clk-wide pulse (= VM_CLK_DIV clk cycles); the
    // present engine consumes edges at 100 MHz, so pass only the rise.
    logic vm_fb_swap_q;
    always_ff @(posedge clk) vm_fb_swap_q <= vm_fb_swap;
    assign fb_swap  = desk_fb_swap || (vm_busy ? (vm_fb_swap && !vm_fb_swap_q) : demo_fb_swap);

    always_ff @(posedge clk) begin
        if (!rst_n) game_mode <= 1'b0;
        else if ((keyboard_feed_push && keyboard_feed_data == 8'h1B) || ui_quit || halt_pulse || classic_restart_halt || actions_halt || classic_error_pulse) game_mode <= 1'b0;
        // Enter on RUN/vm_start only. demo_busy/vm_busy must not retrigger
        // after ESC — console enable is !game_mode, so LIST after RUN died.
        // cmp_arm: a compile runs the VM without becoming a GAME. The text
        // screen stays up, READY stays dark, and the RUN path is untouched.
        // Cheaper and safer than consuming vm_done to undo a game_mode we
        // never needed to enter — that edge would touch every title.
        else if ((run_pulse || vm_start || sim_vm_start || classic_vm_start) && !cmp_arm && !ui_quit_pending && !ui_quit)
            game_mode <= 1'b1;
    end

    jmr_desktop u_desktop (
        .clk(clk),.rst_n(rst_n),
        .system_hold(actions_busy),.control_stb(desktop_control_stb || actions_desk_stb || ui_quit || (ui_terminal && desk_visible) ||
                      (keyboard_feed_push && keyboard_feed_data==27 && !game_mode)),
        .control_on(desktop_control_stb?desktop_control_on:actions_desk_stb?actions_desk_on:(ui_terminal && desk_visible)?1'b0:1'b1),
        .console_ready(ready_lit),.console_failed(con_command_failed),.console_clear(kbd_clear),
        .keyboard_empty(kbd_empty),.keyboard_full(kbd_full),.vm_busy(vm_busy),.game_mode(game_mode),
        .storage_busy(stor_busy),.present_busy(fb_present_busy),.card_present(sd_card_present),
        .mouse_stb(input_mouse_stb && !ui_consume),.mouse_x(input_mouse_x),.mouse_y(input_mouse_y),.mouse_buttons(input_mouse_buttons),
        .system_menu_active(system_menu_o || system_about_o),
        .visible(desk_visible),.busy(desk_busy),.console_hold(desk_hold),
        .keyboard_mode(desktop_keyboard_mode_o),.show_hidden(desk_hidden),
        .selected_o(desktop_selected_o),.page_o(desktop_page_o),.menu_o(desktop_menu_o),
        .key_push(desk_key_push),.key_data(desk_key_data),
        .catalog_go(desk_catalog_go),.icon_go(desk_icon_go),.icon_index(desk_icon_index),
        .disk_busy(disk_busy),.disk_done(disk_done),.disk_error(disk_error),.catalog_count(desk_count),
        .catalog_addr(desk_catalog_addr),.catalog_data(desk_catalog_data),
        .icon_valid(desk_icon_valid),.icon_ready(desk_icon_ready),.icon_x(desk_icon_x),.icon_y(desk_icon_y),
        .icon_colour(desk_icon_colour),.icon_opaque(desk_icon_opaque),
        .fb_we(desk_fb_we),.fb_swap(desk_fb_swap),.fb_addr(desk_fb_addr),.fb_data(desk_fb_data),
        .sram_req(desk_sram_req),.sram_we(desk_sram_we),.sram_addr(desk_sram_addr),.sram_data(desk_sram_data),
        .sram_ack(sram_ack && sram_owner_q==3'd7),.sram_rdata(sram_rdata)
    );
    jmr_desktop_disk u_desktop_disk (
        .clk(clk),.rst_n(rst_n),.catalog_go(desk_catalog_go || docs_catalog_go || actions_catalog_go),.icon_go(desk_icon_go),.show_hidden(actions_catalog_active || (docs_catalog_active?docs_catalog_all:desk_hidden)),.icon_index(desk_icon_index),
        .busy(disk_busy),.done(disk_done),.disk_error(disk_error),.count(desk_count),
        .catalog_addr(actions_catalog_active?actions_catalog_addr:docs_catalog_active?docs_catalog_addr:desk_catalog_addr),.catalog_data(desk_catalog_data),.catalog_size(desk_catalog_size),
        .icon_valid(desk_icon_valid),.icon_ready(desk_icon_ready),.icon_x(desk_icon_x),.icon_y(desk_icon_y),
        .icon_colour(desk_icon_colour),.icon_opaque(desk_icon_opaque),
        .stor_open(desk_stor_open),.stor_close(desk_stor_close),.stor_dir(desk_stor_dir),.stor_next(desk_stor_next),.stor_get(desk_stor_get),
        .stor_name_len(desk_stor_name_len),.stor_busy(stor_busy),.stor_done(stor_done),.stor_err(stor_err),.stor_eof(stor_eof),
        .stor_line_len(stor_line_len),.stor_byte(stor_get_data),.stor_file_size(stor_file_size),.stor_dir_size(stor_dir_size),
        .mem_en(desk_mem_en),.mem_we(desk_mem_we),.mem_addr(desk_mem_addr),.mem_wdata(desk_mem_wdata),
        .mem_rdata(c_mem_rdata),.mem_gnt(c_mem_gnt && disk_busy)
    );
endmodule
