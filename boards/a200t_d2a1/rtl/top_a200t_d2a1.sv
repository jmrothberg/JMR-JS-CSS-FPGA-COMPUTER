// A200T D2-A1/C3 board shell. Shared build-99 JS RTL is not forked.
module top_a200t_d2a1 (
    input  logic SYS_CLK,
    input  logic RESET_N,
    input  logic DIV_SEL0,
    input  logic DIV_SEL1,
    input  logic UART_RX,
    output logic UART_TX,
    output logic VGA_R0,
    output logic VGA_R1,
    output logic VGA_R2,
    output logic VGA_R3,
    output logic VGA_G0,
    output logic VGA_G1,
    output logic VGA_G2,
    output logic VGA_G3,
    output logic VGA_B0,
    output logic VGA_B1,
    output logic VGA_B2,
    output logic VGA_B3,
    output logic VGA_HSYNC,
    output logic VGA_VSYNC,
    output logic PIXEL_CLK,
    output logic VIDEO_DE,
    output logic AUD_PWM,
    output logic AUD_SD,
    inout  tri1  I2C_SCL,
    inout  tri1  I2C_SDA,
    output logic GPIO_OUT0,
    output logic GPIO_OUT1,
    output logic GPIO_OUT2,
    output logic GPIO_OUT3,
    output logic GPIO_OUT4,
    output logic GPIO_OUT5,
    output logic GPIO_OUT6,
    output logic GPIO_OUT7,
    input  logic GPIO_IN0,
    input  logic GPIO_IN1,
    input  logic GPIO_IN2,
    input  logic GPIO_IN3,
    output logic SD_SCK,
    output logic SD_MOSI,
    input  logic SD_MISO,
    output logic SD_CS_N,
    output logic STAT0,
    output logic STAT1,
    output logic STAT2,
    inout wire [7:0] HR_DQ,
    inout wire HR_RWDS,
    output wire HR_CK_P_SRC, HR_CK_N_SRC, HR_CS_N, HR_RESET_N
);
wire core_clk,pixel_clk,ramclk,ck90,ref200,mclk,locked;
wire fbraw,fb,cr,pr,rr,kr,dr,mr;
MMCME2_BASE #(.CLKIN1_PERIOD(40.0),.CLKFBOUT_MULT_F(24.0),
 .CLKOUT0_DIVIDE_F(6.0),.CLKOUT1_DIVIDE(24),.CLKOUT2_DIVIDE(12),
 .CLKOUT3_DIVIDE(12),.CLKOUT3_PHASE(90.0),.CLKOUT4_DIVIDE(3),
 .CLKOUT5_DIVIDE(50)) clocks(.CLKIN1(SYS_CLK),.CLKFBIN(fb),.CLKFBOUT(fbraw),
 .CLKOUT0(cr),.CLKOUT1(pr),.CLKOUT2(rr),.CLKOUT3(kr),.CLKOUT4(dr),.CLKOUT5(mr),
 .LOCKED(locked),.RST(!RESET_N),.PWRDWN(1'b0));
BUFG bfb(.I(fbraw),.O(fb)); BUFG bc(.I(cr),.O(core_clk));
BUFG bp(.I(pr),.O(pixel_clk));BUFG br(.I(rr),.O(ramclk));
BUFG bk(.I(kr),.O(ck90));BUFG bd(.I(dr),.O(ref200));BUFG bm(.I(mr),.O(mclk));
wire clock_reset_n=RESET_N && locked;
(* ASYNC_REG="TRUE" *) reg [2:0] clock_release;
always @(posedge core_clk or negedge clock_reset_n)
 if(!clock_reset_n)clock_release<=0;else clock_release<={clock_release[1:0],1'b1};
wire ram_rst_n=clock_release[2];
wire ram_ready,ram_fault;
wire reset_request_n=ram_rst_n && ram_ready && !ram_fault;
(* ASYNC_REG="TRUE" *) reg [1:0] core_reset_release;
always @(posedge core_clk or negedge reset_request_n)
 if(!reset_request_n)core_reset_release<=0;else core_reset_release<={core_reset_release[0],1'b1};
(* max_fanout=400 *) reg core_rst_n_fan;
always @(posedge core_clk or negedge reset_request_n)
 if(!reset_request_n)core_rst_n_fan<=0;else core_rst_n_fan<=core_reset_release[1];
wire rst_n=core_rst_n_fan;
wire snd_tgl,snd_ack;wire [1:0] snd_ch;wire [15:0] snd_freq;
wire [3:0] snd_vol;wire [7:0] snd_frames,snd_slide;
wire kbd_push,kev_stb,kev_down,key_fault,mouse_sample_valid,mouse_core_ready;
wire [7:0] kbd_ascii,kev_code;wire [9:0] mouse_x;wire [8:0] mouse_y;wire [2:0] mouse_buttons;
jmr_c3_input input_devices(.clk(core_clk),.rst_n(rst_n),.rx(UART_RX),
 .kbd_push(kbd_push),.kbd_ascii(kbd_ascii),.kev_stb(kev_stb),.kev_down(kev_down),.kev_code(kev_code),
 .mouse_valid(mouse_sample_valid),.mouse_ready(mouse_core_ready),
 .mouse_x(mouse_x),.mouse_y(mouse_y),.mouse_buttons(mouse_buttons),.fault(key_fault));
assign UART_TX=1'b1;
wire [9:0] pointer_x;wire [8:0] pointer_y;wire pointer_toggle;
wire desktop_keyboard_mode;
wire system_menu,system_keyboard,system_about,system_shift,system_caps,system_ctrl,system_alt,system_hold;
wire [6:0] system_pressed;wire [69:0] system_held;
wire [31:0] system_window,system_window_pixels;
wire system_game_viewport,system_viewport_pixels,system_ui_opaque;wire [23:0] system_ui_rgb;
jmr_ui_snapshot #(.WIDTH(33)) u_scan_ui_state(.clk(core_clk),.rst_n(rst_n),.pixel_clk(pixel_clk),
 .source({system_window,system_game_viewport}),.pixels({system_window_pixels,system_viewport_pixels}));
wire ack_ok,joy_left,joy_up,joy_down,joy_right,fire_ac,fire_bd;
wire [7:0] i2c_analog_x,i2c_analog_y;wire [4:0] i2c_joy_btn;
jmr_i2c_joy u_i2c_joy(.clk(core_clk),.rst_n(rst_n),.scl(I2C_SCL),.sda(I2C_SDA),
 .ack_ok(ack_ok),.left(joy_left),.up(joy_up),.down(joy_down),.right(joy_right),
 .fire_ac(fire_ac),.fire_bd(fire_bd),.analog_x(i2c_analog_x),.analog_y(i2c_analog_y),.buttons(i2c_joy_btn));
wire [5:0] i2c_joy_bits={fire_bd,fire_ac,joy_right,joy_left,joy_up,joy_down};
    logic [9:0] scan_addr, cursor;
    logic [7:0] scan_data, dump_data;
    logic       ready_lit, game_mode, game_view;
    logic [31:0] vm_vdbg;
    logic [31:0] vm_hdbg, vm_fdbg;
    logic        vm_fdbg_v;
    logic [127:0] vm_ftrace;
    logic [47:0]  vm_gdbg;
    logic        vm_vdbg_fault;
    logic [6:0] stor_dbg_state;
    logic [15:0] stor_dbg_op_clk;
    logic [6:0] cons_dbg_state;
    logic [5:0] joy_out;
    logic [18:0] fb_raddr;
    logic [9:0]  fb_x, fb_y;
    logic [7:0]  fb_rdata;
    logic [7:0]  pal_index;
    logic [23:0] pal_rgb;
    // SPI from core storage_engine
    logic sd_sck, sd_mosi, sd_miso, sd_cs_n;
    // Asset SRAM port (core master → MIG bridge)
    logic        sram_req, sram_we, sram_ack;
    logic [24:0] sram_addr;
    logic [15:0] sram_wdata, sram_rdata;
    jmr_js_core #(.SRAM_INTERNAL(0), .FRAME_DIV(1666665)) u_core (
        .clk(core_clk), .pixel_clk(pixel_clk), .rst_n(rst_n),
        .standalone_mode(1'b1),
        .sd_card_present(1'b1),
        .stor_dbg_state_o(stor_dbg_state),
        .stor_dbg_op_clk_o(stor_dbg_op_clk),
        .cons_dbg_state_o(cons_dbg_state),
        .game_view_o(game_view),
        .mouse_stb(mouse_sample_valid),.mouse_ready(mouse_core_ready),
        .mouse_x(mouse_x),.mouse_y(mouse_y),.mouse_buttons(mouse_buttons),
        .desktop_keyboard_mode_o(desktop_keyboard_mode),
        .pointer_x_o(pointer_x),.pointer_y_o(pointer_y),.pointer_toggle_o(pointer_toggle),
        .system_status_o(),.system_window_o(system_window),.system_viewport_o(system_game_viewport),.game_source_y_o(),
        .system_overlay_opaque_o(system_ui_opaque),.system_overlay_rgb_o(system_ui_rgb),.system_menu_o(system_menu),.system_keyboard_o(system_keyboard),.system_about_o(system_about),.system_shift_o(system_shift),.system_caps_o(system_caps),
        .system_ctrl_o(system_ctrl),.system_alt_o(system_alt),.system_pressed_o(system_pressed),.system_hold_o(system_hold),.system_held_o(system_held),
        .key_evt_char(kbd_push && kbd_ascii>=32 && kbd_ascii<127?kbd_ascii:8'd0),

        .vdbg_o(vm_vdbg), .vdbg_fault_o(vm_vdbg_fault),
        .vm_hdbg(vm_hdbg), .vm_fdbg(vm_fdbg), .vm_fdbg_v(vm_fdbg_v),
        .vm_ftrace(vm_ftrace), .vm_gdbg(vm_gdbg),
        // both PS/2 keyboards feed the game-event path (main wins a tie)
        .key_evt_stb(kev_stb),
        .key_evt_code(kev_code),
        .key_evt_down(kev_down),
        .kbd_push(kbd_push), .kbd_data(kbd_ascii),
        // Tether KEYBITS OR I2C stick (same 6-bit field as PYTHON)
        .joy_in(i2c_joy_bits), .joy_out(joy_out),
        .analog_x(i2c_analog_x), .analog_y(i2c_analog_y), .joy_btn(i2c_joy_btn),
        .dump_addr(10'd0), .dump_data(dump_data),
        .cursor(cursor), .ready_lit(ready_lit),
        .snd_ack(snd_ack), .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .scan_addr(scan_addr), .scan_data(scan_data),
        .game_mode(game_mode),
        .fb_raddr(fb_raddr), .fb_x(fb_x), .fb_y(fb_y), .fb_rdata(fb_rdata),
        .pal_raddr(pal_index), .pal_rdata(pal_rgb),
        .sd_sck(sd_sck), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
        .sram_ext_req(sram_req), .sram_ext_we(sram_we),
        .sram_ext_addr(sram_addr), .sram_ext_wdata(sram_wdata),
        .sram_ext_rdata(sram_rdata), .sram_ext_ack(sram_ack)
    );

jmr_hyperram_sram memory(.clk(core_clk),.ramclk(ramclk),.ck90(ck90),.ref200(ref200),.rst_n(ram_rst_n),
 .req(sram_req),.we(sram_we),.addr(sram_addr),.wdata(sram_wdata),.rdata(sram_rdata),.ack(sram_ack),
 .ready(ram_ready),.fault(ram_fault),.HR_DQ(HR_DQ),.HR_RWDS(HR_RWDS),
 .HR_CK_P_SRC(HR_CK_P_SRC),.HR_CK_N_SRC(HR_CK_N_SRC),.HR_CS_N(HR_CS_N),.HR_RESET_N(HR_RESET_N));
assign SD_SCK=sd_sck;assign SD_MOSI=sd_mosi;assign SD_CS_N=sd_cs_n;assign sd_miso=SD_MISO;
    logic [23:0] vid_pData;
    logic        vid_pVDE, vid_pHSync, vid_pVSync;
    jmr_text_hdmi_scanout #(.FONT_HEX("font_rom.hex")) u_scan (
        .pixel_clk(pixel_clk), .mouse_clk(core_clk), .rst_n(rst_n),
        .vram_rdata(scan_data), .vram_addr(scan_addr),
        .cursor_cell(cursor),
        .mouse_x(pointer_x),.mouse_y(pointer_y),.mouse_toggle(pointer_toggle),.mouse_show_exit(1'b0),
        .system_window(system_window_pixels),.system_game_viewport(system_viewport_pixels),.system_ui_opaque(system_ui_opaque),.system_ui_rgb(system_ui_rgb),
        .system_menu(system_menu),.system_keyboard(system_keyboard),.system_about(system_about),.system_shift(system_shift),.system_caps(system_caps),
        .system_ctrl(system_ctrl),.system_alt(system_alt),.system_pressed(system_pressed),.system_hold(system_hold),.system_held(system_held),

        .game_mode(game_view),
        .fb_raddr(fb_raddr), .fb_x(fb_x), .fb_y(fb_y), .fb_rdata(fb_rdata),
        .pal_index(pal_index), .pal_rgb(pal_rgb),
        .vid_pData(vid_pData), .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync), .vid_pVSync(vid_pVSync)
    );

// C3 has parallel RGB444/VGA. Positive internal syncs become VGA active-low.
assign {VGA_R3,VGA_R2,VGA_R1,VGA_R0}=vid_pData[23:20];
assign {VGA_G3,VGA_G2,VGA_G1,VGA_G0}=vid_pData[15:12];
assign {VGA_B3,VGA_B2,VGA_B1,VGA_B0}=vid_pData[7:4];
assign VGA_HSYNC=~vid_pHSync;assign VGA_VSYNC=~vid_pVSync;
assign VIDEO_DE=vid_pVDE;assign PIXEL_CLK=pixel_clk;
assign {GPIO_OUT7,GPIO_OUT6,GPIO_OUT5,GPIO_OUT4,GPIO_OUT3,GPIO_OUT2,GPIO_OUT1,GPIO_OUT0}=0;
assign STAT0=locked;assign STAT1=ram_ready && rst_n;assign STAT2=ram_fault || key_fault || vm_vdbg_fault;
(* ASYNC_REG="TRUE" *) reg [1:0] audio_reset,game_sync;
always @(posedge mclk or negedge reset_request_n)
 if(!reset_request_n)begin audio_reset<=0;game_sync<=0;end
 else begin audio_reset<={audio_reset[0],core_reset_release[1]};game_sync<={game_sync[0],game_mode};end
wire bclk,lrclk,sdata;
jmr_psg sound(.mclk(mclk),.rst_n(audio_reset[1]),.enable(1'b1),.mute(!game_sync[1]),
 .snd_tgl(snd_tgl),.snd_ack(snd_ack),.snd_ch(snd_ch),.snd_freq(snd_freq),
 .snd_vol(snd_vol),.snd_frames(snd_frames),.snd_slide(snd_slide),
 .bclk(bclk),.lrclk(lrclk),.dac_sdata(sdata));
// Recover the common PSG sample in the same MCLK domain, then PWM to C3.
reg bq,lq;reg [5:0] bitcount;reg [23:0] sample_shift;reg [7:0] amplitude;
reg [8:0] sigma;
always @(posedge mclk)begin
 if(!audio_reset[1])begin bq<=0;lq<=0;bitcount<=0;sample_shift<=0;amplitude<=128;sigma<=0;end
 else begin
  bq<=bclk;lq<=lrclk;
  if(lq!=lrclk)bitcount<=0;
  else if(bclk && !bq)begin
   bitcount<=bitcount+1'b1;
   if(bitcount>=1 && bitcount<=24)sample_shift<={sample_shift[22:0],sdata};
   if(bitcount==25)amplitude<={~sample_shift[23],sample_shift[22:16]};
  end
  sigma<={1'b0,sigma[7:0]}+{1'b0,amplitude};
 end
end
assign AUD_PWM=sigma[8];assign AUD_SD=audio_reset[1];
endmodule
