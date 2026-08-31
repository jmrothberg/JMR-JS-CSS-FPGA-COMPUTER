// Nexys Video board top — PHY shell around jmr_js_core (BASIC top_nexys_a7 method).
// Standalone: HDMI text console + USB-HID PS/2 (J15) + Pmod PS/2 (JA) +
// I2C joystick 0x5A (JB) + µSD. Same JA/JB wiring as tools/pmod_input_test.
module top_nexys_video (
    input  wire       clk100,
    input  wire       cpu_resetn,
    // NEW: BTNC (B22) = user reset, same as the BASIC A7 board habit
    input  wire       btnc,
    // NEW: DPTI on PROG jack J12 (FT2232 ch B) — same USB cable as JTAG, like T100
    inout  wire [7:0] prog_d,
    input  wire       prog_rxen,
    input  wire       prog_txen,
    output wire       prog_rdn,
    output wire       prog_wrn,
    output wire       prog_oen,
    output wire       prog_siwun,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    input  wire       hdmi_tx_hpd,
    inout  wire       hdmi_tx_cec,
    inout  wire       hdmi_tx_rscl,
    inout  wire       hdmi_tx_rsda,
    // NEW: input-only like BASIC T100 — PIC24 is the PS/2 device; do not drive
    input  wire       ps2_clk,
    input  wire       ps2_data,
    // NEW: Pmod PS/2 on JA (pin1=Data pin3=Clock) — RX-only, same as J15
    input  wire       pmod_ps2_clk,
    input  wire       pmod_ps2_data,
    // NEW: Mini I2C joystick @ 0x5A on JB (SCL=JB1 SDA=JB2)
    inout  wire       joy_scl,
    inout  wire       joy_sda,
    // ADAU1761 audio codec (J5 line-out) — line-out PSG plan phase 1
    output wire       ac_mclk,
    output wire       ac_bclk,
    output wire       ac_lrclk,
    output wire       ac_dac_sdata,
    inout  wire       ac_scl,
    inout  wire       ac_sda,
    // µSD SPI
    output wire       sd_reset,
    output wire       sd_cclk,
    inout  wire       sd_cmd,
    inout  wire [3:0] sd_d,
    input  wire       sd_cd,
    // NEW: Nexys Video DDR3 (asset SRAM = first 4 MB behind jmr_sram_port)
    inout  wire [15:0] ddr3_dq,
    inout  wire [1:0]  ddr3_dqs_n,
    inout  wire [1:0]  ddr3_dqs_p,
    output wire [14:0] ddr3_addr,
    output wire [2:0]  ddr3_ba,
    output wire        ddr3_ras_n,
    output wire        ddr3_cas_n,
    output wire        ddr3_we_n,
    output wire        ddr3_reset_n,
    output wire [0:0]  ddr3_ck_p,
    output wire [0:0]  ddr3_ck_n,
    output wire [0:0]  ddr3_cke,
    output wire [1:0]  ddr3_dm,
    output wire [0:0]  ddr3_odt,
    output wire [7:0] led
);
    assign hdmi_tx_cec  = 1'bz;
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    // Digilent: after config the PIC24 leaves the µSD unpowered; drive
    // SD_RESET low to power the slot. Hold low for the whole run.
    assign sd_reset = 1'b0;

    wire core_clk, pixel_clk, mmcm_locked, clkfb, clk200;
    wire mclk_raw, mclk;
    // sound-native poke bus, core -> PSG (see the audio block at the bottom)
    logic snd_tgl;
    logic [1:0]  snd_ch;
    logic [15:0] snd_freq;
    logic [3:0]  snd_vol;
    logic [7:0]  snd_frames;
    logic [7:0]  snd_slide;
    wire rst_n;
    wire ui_clk, ui_clk_sync_rst, init_calib_complete;
    wire mig_sys_rst_n;

`ifdef SYNTHESIS
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .CLKFBOUT_MULT_F(6.0),
        .CLKOUT0_DIVIDE_F(24.0),
        .CLKOUT1_DIVIDE(50),  // 600 MHz VCO / 50 = 12 MHz audio MCLK (was unused /6)
        .CLKOUT2_DIVIDE(3)
    ) u_mmcm (
        .CLKIN1(clk100),
        .CLKFBIN(clkfb),
        .CLKFBOUT(clkfb),
        .CLKOUT0(pixel_clk),
        .CLKOUT1(mclk_raw),
        .CLKOUT2(clk200),
        .LOCKED(mmcm_locked),
        .PWRDWN(1'b0),
        .RST(~cpu_resetn)
    );
    // NEW: BTNC also resets (matches the T100/BASIC board habit)
    assign mig_sys_rst_n = cpu_resetn & mmcm_locked & ~btnc;
    assign core_clk = ui_clk;
    assign rst_n = mig_sys_rst_n & init_calib_complete & ~ui_clk_sync_rst;
`else
    assign core_clk = clk100;
    assign mmcm_locked = 1'b1;
    assign clk200 = clk100;
    assign ui_clk = clk100;
    assign ui_clk_sync_rst = 1'b0;
    assign init_calib_complete = 1'b1;
    assign mig_sys_rst_n = cpu_resetn & ~btnc;
    assign rst_n = cpu_resetn & ~btnc;
    reg [1:0] pix_div;
    assign pixel_clk = pix_div[1];
    always @(posedge clk100 or negedge cpu_resetn) begin
        if (!cpu_resetn) pix_div <= 0;
        else pix_div <= pix_div + 1'b1;
    end
`endif

    logic       kbd_push;
    logic [7:0] kbd_ascii;
    logic [7:0] ps2_scancode;
    logic       ps2_strobe;
    logic       ps2_parity_err;
    // NEW: no jmr_ps2_host — host TX of 0xFF/0xF4 killed PIC24 scanning
    ps2_rx u_ps2_rx (
        .clk(core_clk), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .scancode(ps2_scancode), .strobe(ps2_strobe), .parity_err(ps2_parity_err)
    );
    logic [7:0] kev_code, pmod_kev_code;
    logic       kev_down, kev_stb, pmod_kev_down, pmod_kev_stb;
    ps2_decode u_ps2_dec (
        .clk(core_clk), .rst_n(rst_n),
        .scancode(ps2_scancode), .strobe(ps2_strobe),
        .ascii(kbd_ascii), .ascii_strobe(kbd_push),
        .kev_code(kev_code), .kev_down(kev_down), .kev_stb(kev_stb)
    );
    // NEW: second PS/2 RX on JA — do not attach jmr_ps2_host (J15 clk-low trap)
    logic       pmod_kbd_push;
    logic [7:0] pmod_ascii;
    logic [7:0] pmod_scancode;
    logic       pmod_ps2_strobe;
    logic       pmod_ps2_parity_err;
    ps2_rx u_pmod_ps2_rx (
        .clk(core_clk), .rst_n(rst_n),
        .ps2_clk(pmod_ps2_clk), .ps2_data(pmod_ps2_data),
        .scancode(pmod_scancode), .strobe(pmod_ps2_strobe),
        .parity_err(pmod_ps2_parity_err)
    );
    ps2_decode u_pmod_ps2_dec (
        .clk(core_clk), .rst_n(rst_n),
        .scancode(pmod_scancode), .strobe(pmod_ps2_strobe),
        .ascii(pmod_ascii), .ascii_strobe(pmod_kbd_push),
        .kev_code(pmod_kev_code), .kev_down(pmod_kev_down), .kev_stb(pmod_kev_stb)
    );
    // NEW: I2C stick @ 0x5A — NACK leaves bits 0 so GUI KEYBITS still work
    logic ack_ok, joy_left, joy_up, joy_down, joy_right, fire_ac, fire_bd;
    jmr_i2c_joy u_i2c_joy (
        .clk(core_clk), .rst_n(rst_n),
        .scl(joy_scl), .sda(joy_sda),
        .ack_ok(ack_ok),
        .left(joy_left), .up(joy_up), .down(joy_down), .right(joy_right),
        .fire_ac(fire_ac), .fire_bd(fire_bd)
    );
    // Board 2026-08-26: this stick's electrical DOWN is physical forward
    // (ASTEROID hand-compensated; every other title read Y reversed).
    // Invert once here; ASTEROID's compensation removed in the same
    // change so it is not doubly inverted.
    wire [5:0] i2c_joy_bits = {fire_bd, fire_ac, joy_right, joy_left, joy_up, joy_down};

    logic [9:0] scan_addr, cursor;
    logic [7:0] scan_data, dump_data;
    logic       ready_lit, game_mode, game_view;
    logic [31:0] vm_vdbg;
    logic [31:0] vm_hdbg, vm_fdbg;
    logic        vm_fdbg_v;
    logic [127:0] vm_ftrace;
    logic        vm_vdbg_fault;
    logic [6:0] stor_dbg_state;
    logic [6:0] cons_dbg_state;
    logic [5:0] joy_out;
    logic [18:0] fb_raddr;
    logic [9:0]  fb_x, fb_y;
    logic [7:0]  fb_rdata;
    logic [7:0]  pal_index;
    logic [23:0] pal_rgb;
    logic [18:0] dump_fb_raddr;
    logic [7:0]  dump_fb_rdata;
    // NEW: SPI from core storage_engine
    logic sd_sck, sd_mosi, sd_miso, sd_cs_n;
    // NEW: asset SRAM port (core master → MIG bridge)
    logic        sram_req, sram_we, sram_ack;
    logic [20:0] sram_addr;
    logic [15:0] sram_wdata, sram_rdata;
    logic [28:0]  app_addr;
    logic [2:0]   app_cmd;
    logic         app_en, app_wdf_end, app_wdf_wren;
    logic [127:0] app_wdf_data, app_rd_data;
    logic [15:0]  app_wdf_mask;
    logic         app_rd_data_valid, app_rdy, app_wdf_rdy;
    logic         app_rd_data_end, app_sr_active, app_ref_ack, app_zq_ack;

    // NEW: PROG-cable tether — FT245 FIFO on FT2232 ch A (T100-style one cable)
    logic       uart_kbd_push;
    logic [7:0] uart_kbd_data;
    logic [5:0] uart_joy_bits;  // NEW: GUI KEYBITS ORed with JB stick; optional tether
    logic [9:0] uart_dump_addr;
    logic        uart_jsb_stb;
    logic [7:0]  uart_jsb_data;
    logic        uart_jsb_eof;
    logic        uart_jsb_rdy;
    jmr_uart_link #(.CLK_HZ(100_000_000), .USE_DPTI(1)) u_link (
        .clk(core_clk), .rst_n(rst_n),
        .uart_rx(1'b1), .uart_tx(),
        .prog_d(prog_d), .prog_rxen(prog_rxen), .prog_txen(prog_txen),
        .prog_rdn(prog_rdn), .prog_wrn(prog_wrn),
        .prog_oen(prog_oen), .prog_siwun(prog_siwun),
        .kbd_push(uart_kbd_push), .kbd_data(uart_kbd_data),
        .joy_bits(uart_joy_bits),
        .dump_addr(uart_dump_addr), .dump_data(dump_data),
        .dump_fb_raddr(dump_fb_raddr), .dump_fb_rdata(dump_fb_rdata),
        .game_mode(game_mode),
        .ps2_strobe(ps2_strobe),
        .ps2_code(ps2_scancode),
        .stor_state(stor_dbg_state),
        .cons_state(cons_dbg_state),
        .vm_vdbg(vm_vdbg), .vm_vdbg_fault(vm_vdbg_fault),
        .vm_hdbg(vm_hdbg), .vm_fdbg(vm_fdbg), .vm_fdbg_v(vm_fdbg_v),
        .vm_ftrace(vm_ftrace),
        .jsb_tether_stb(uart_jsb_stb), .jsb_tether_data(uart_jsb_data),
        .jsb_tether_eof(uart_jsb_eof), .jsb_tether_rdy(uart_jsb_rdy)
    );
    // Merge J15 + Pmod JA + UART (all slow; J15 wins, then Pmod, then tether)
    wire        core_kbd_push = kbd_push | pmod_kbd_push | uart_kbd_push;
    wire [7:0]  core_kbd_data = kbd_push ? kbd_ascii :
                                pmod_kbd_push ? pmod_ascii : uart_kbd_data;

    jmr_js_core #(.SRAM_INTERNAL(0)) u_core (
        .clk(core_clk), .pixel_clk(pixel_clk), .rst_n(rst_n),
        .standalone_mode(1'b1),
        .sd_card_present(~sd_cd),
        .stor_dbg_state_o(stor_dbg_state),
        .cons_dbg_state_o(cons_dbg_state),
        .game_view_o(game_view),
        .vdbg_o(vm_vdbg), .vdbg_fault_o(vm_vdbg_fault),
        .vm_hdbg(vm_hdbg), .vm_fdbg(vm_fdbg), .vm_fdbg_v(vm_fdbg_v),
        .vm_ftrace(vm_ftrace),
        // both PS/2 keyboards feed the game-event path (main wins a tie)
        .key_evt_stb(kev_stb | pmod_kev_stb),
        .key_evt_code(kev_stb ? kev_code : pmod_kev_code),
        .key_evt_down(kev_stb ? kev_down : pmod_kev_down),
        .kbd_push(core_kbd_push), .kbd_data(core_kbd_data),
        // NEW: tether KEYBITS OR I2C stick (same 6-bit field as PYTHON)
        .joy_in(uart_joy_bits | i2c_joy_bits), .joy_out(joy_out),
        .dump_addr(uart_dump_addr), .dump_data(dump_data),
        .cursor(cursor), .ready_lit(ready_lit),
        .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .scan_addr(scan_addr), .scan_data(scan_data),
        .game_mode(game_mode),
        .fb_raddr(fb_raddr), .fb_x(fb_x), .fb_y(fb_y), .fb_rdata(fb_rdata),
        .dump_fb_raddr(dump_fb_raddr), .dump_fb_rdata(dump_fb_rdata),
        .pal_raddr(pal_index), .pal_rdata(pal_rgb),
        .sd_sck(sd_sck), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n),
        .jsb_tether_stb(uart_jsb_stb), .jsb_tether_data(uart_jsb_data),
        .jsb_tether_eof(uart_jsb_eof), .jsb_tether_rdy(uart_jsb_rdy),
        .sram_ext_req(sram_req), .sram_ext_we(sram_we),
        .sram_ext_addr(sram_addr), .sram_ext_wdata(sram_wdata),
        .sram_ext_rdata(sram_rdata), .sram_ext_ack(sram_ack)
    );

    // NEW: first 4 MB of DDR3 = asset SRAM. FPGA-SIM uses jmr_sram_model
    // inside the core (SRAM_INTERNAL=1); board is this MIG + bridge.
`ifdef SYNTHESIS
    mig_7series_0 u_mig (
        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),
        .sys_clk_i(clk200),
        .sys_rst(mig_sys_rst_n),
        .ui_clk(ui_clk),
        .ui_clk_sync_rst(ui_clk_sync_rst),
        .init_calib_complete(init_calib_complete),
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_wdf_data(app_wdf_data),
        .app_wdf_end(app_wdf_end),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),
        .app_rd_data(app_rd_data),
        .app_rd_data_end(app_rd_data_end),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rdy(app_rdy),
        .app_wdf_rdy(app_wdf_rdy),
        .app_sr_req(1'b0),
        .app_ref_req(1'b0),
        .app_zq_req(1'b0),
        .app_sr_active(app_sr_active),
        .app_ref_ack(app_ref_ack),
        .app_zq_ack(app_zq_ack),
        .device_temp()
    );
    jmr_ddr3_sram_bridge u_sram_br (
        .clk(ui_clk),
        .rst_n(rst_n),
        .calib_done(init_calib_complete),
        .req(sram_req), .we(sram_we), .addr(sram_addr),
        .wdata(sram_wdata), .rdata(sram_rdata), .ack(sram_ack),
        .app_addr(app_addr), .app_cmd(app_cmd), .app_en(app_en),
        .app_wdf_data(app_wdf_data), .app_wdf_end(app_wdf_end),
        .app_wdf_mask(app_wdf_mask), .app_wdf_wren(app_wdf_wren),
        .app_rd_data(app_rd_data), .app_rd_data_valid(app_rd_data_valid),
        .app_rdy(app_rdy), .app_wdf_rdy(app_wdf_rdy)
    );
`else
    jmr_sram_model u_sram (
        .clk(core_clk), .rst_n(rst_n),
        .req(sram_req), .we(sram_we), .addr(sram_addr),
        .wdata(sram_wdata), .rdata(sram_rdata), .ack(sram_ack)
    );
`endif

    // µSD SPI — Nexys Video pinout (LiteX/Digilent):
    //   SCK=sd_cclk, MOSI=sd_cmd, MISO=sd_d[0], CS=sd_d[3]
    // NEW: CS was left floating (d[3] Z) → every DIR returned ?IO with card present.
    assign sd_cclk = sd_sck;
    assign sd_cmd  = sd_mosi;
    assign sd_d[3] = sd_cs_n;
    assign sd_miso = sd_d[0];
    assign sd_d[0] = 1'bz;
    assign sd_d[2:1] = 2'bzz;

    logic [23:0] vid_pData;
    logic        vid_pVDE, vid_pHSync, vid_pVSync;
    jmr_text_hdmi_scanout #(.FONT_HEX("font_rom.hex")) u_scan (
        .pixel_clk(pixel_clk), .rst_n(rst_n),
        .vram_rdata(scan_data), .vram_addr(scan_addr),
        .cursor_cell(cursor),
        .game_mode(game_view),
        .fb_raddr(fb_raddr), .fb_x(fb_x), .fb_y(fb_y), .fb_rdata(fb_rdata),
        .pal_index(pal_index), .pal_rgb(pal_rgb),
        .vid_pData(vid_pData), .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync), .vid_pVSync(vid_pVSync)
    );

    jmr_rgb2dvi_wrap u_tmds (
        .TMDS_Clk_p(hdmi_tx_clk_p),
        .TMDS_Clk_n(hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_p),
        .TMDS_Data_n(hdmi_tx_n),
        .aRst(~rst_n),
        // rgb2dvi convention (third_party .../rgb2dvi.vhd:215-217): pData is
        // R[23:16], BLUE[15:8], GREEN[7:0]. The scanout drives honest RGB;
        // swap at the boundary. Board evidence: blue rendered green, red
        // fine, console text (white/gray = channel-invariant) never showed it.
        .vid_pData({vid_pData[23:16], vid_pData[7:0], vid_pData[15:8]}),
        .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync),
        .vid_pVSync(vid_pVSync),
        .PixelClk(pixel_clk)
    );

    // FROZEN LED meanings (do not reshuffle):
    //   LD7 = ps2_strobe blink (USB Host J15 scancode)
    //   LD6 = raw ps2_clk (idle high)
    //   LD5 = raw ps2_data
    //   LD4 = ~sd_cd (card present)
    //   LD3 = MMCM locked
    //   LD2 = READY
    //   LD1 = game_mode
    //   LD0 = alive
    // JP4 is boot source only — NOT a keyboard enable. Leave JP4 alone.
    logic key_blink;
    always_ff @(posedge core_clk) begin
        if (!rst_n) key_blink <= 1'b0;
        else if (ps2_strobe) key_blink <= ~key_blink;
    end
    // sd_cd is active-low on Digilent boards (0 = card present)
    assign led = {key_blink, ps2_clk, ps2_data, ~sd_cd, mmcm_locked, ready_lit, game_mode, 1'b1};

    // ================= audio: ADAU1761 line-out PSG =================
    // Leaf modules only — nothing here touches the VM/core datapaths.
    // MCLK = MMCM CLKOUT1 (12 MHz); codec init on core_clk (~100 MHz I2C
    // master); PSG + I2S on mclk. CDC: snd_tgl toggle-sync inside the PSG;
    // cfg_done/ready_lit are quasi-static levels, 2FF each.
    BUFG u_mclk_bufg (.I(mclk_raw), .O(mclk));
    assign ac_mclk = mclk;

    logic [1:0] mrst_sync;
    logic       mrst_n;
    always_ff @(posedge mclk) begin
        mrst_sync <= {mrst_sync[0], (cpu_resetn & mmcm_locked)};
        mrst_n    <= mrst_sync[1];
    end

    logic cfg_scl_oe, cfg_sda_oe, cfg_done, cfg_nack;
    logic [5:0] cfg_step;
    jmr_adau1761_cfg #(
        .CLK_HZ(100_000_000), .I2C_HZ(100_000), .START_DLY(1_000_000)
    ) u_ac_cfg (
        .clk(core_clk), .rst_n(rst_n),
        .scl_oe(cfg_scl_oe), .sda_oe(cfg_sda_oe), .sda_i(ac_sda),
        .done(cfg_done), .ack_fail(cfg_nack), .step_o(cfg_step)
    );
    assign ac_scl = cfg_scl_oe ? 1'b0 : 1'bz;
    assign ac_sda = cfg_sda_oe ? 1'b0 : 1'bz;

    logic [1:0] acfg_sync, mute_sync;
    always_ff @(posedge mclk) begin
        acfg_sync <= {acfg_sync[0], cfg_done};
        // MUTE = "no program is running", i.e. ~game_mode.
        // Do NOT use ready_lit here (run 63 shipped that and was silent in
        // every game): ready_lit means "console FSM is in C_IDLE/C_PROMPT",
        // and the console is DISABLED during game_mode
        // (jmr_js_core .enable(standalone_mode && !game_mode)), so its FSM
        // parks in C_IDLE and ready_lit reads TRUE for the whole of a game —
        // muting exactly when sound is wanted. game_mode clears on ESC and
        // on halt_pulse, so BREAK->READY still silences a lingering note,
        // and a halted program is silenced too (ready_lit would not).
        mute_sync <= {mute_sync[0], ~game_mode};
    end

    jmr_psg u_psg (
        .mclk(mclk), .rst_n(mrst_n),
        .enable(acfg_sync[1]), .mute(mute_sync[1]),
        .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .bclk(ac_bclk), .lrclk(ac_lrclk), .dac_sdata(ac_dac_sdata)
    );
endmodule
