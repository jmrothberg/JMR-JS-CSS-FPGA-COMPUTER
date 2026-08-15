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
    // µSD SPI
    output wire       sd_reset,
    output wire       sd_cclk,
    inout  wire       sd_cmd,
    inout  wire [3:0] sd_d,
    input  wire       sd_cd,
    output wire [7:0] led
);
    assign hdmi_tx_cec  = 1'bz;
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    // Digilent: after config the PIC24 leaves the µSD unpowered; drive
    // SD_RESET low to power the slot. Hold low for the whole run.
    assign sd_reset = 1'b0;

    wire core_clk, pixel_clk, mmcm_locked, clkfb;
    wire rst_n;

`ifdef SYNTHESIS
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .CLKFBOUT_MULT_F(6.0),
        .CLKOUT0_DIVIDE_F(24.0),
        .CLKOUT1_DIVIDE(6)
    ) u_mmcm (
        .CLKIN1(clk100),
        .CLKFBIN(clkfb),
        .CLKFBOUT(clkfb),
        .CLKOUT0(pixel_clk),
        .CLKOUT1(core_clk),
        .LOCKED(mmcm_locked),
        .PWRDWN(1'b0),
        .RST(~cpu_resetn)
    );
    // NEW: BTNC also resets (matches the T100/BASIC board habit)
    assign rst_n = cpu_resetn & mmcm_locked & ~btnc;
`else
    assign core_clk = clk100;
    assign mmcm_locked = 1'b1;
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
    ps2_decode u_ps2_dec (
        .clk(core_clk), .rst_n(rst_n),
        .scancode(ps2_scancode), .strobe(ps2_strobe),
        .ascii(kbd_ascii), .ascii_strobe(kbd_push)
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
        .ascii(pmod_ascii), .ascii_strobe(pmod_kbd_push)
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
    wire [5:0] i2c_joy_bits = {fire_bd, fire_ac, joy_right, joy_left, joy_down, joy_up};

    logic [9:0] scan_addr, cursor;
    logic [7:0] scan_data, dump_data;
    logic       ready_lit, game_mode;
    logic [5:0] joy_out;
    logic [18:0] fb_raddr;
    logic [7:0]  fb_rdata;
    logic [18:0] dump_fb_raddr;
    logic [7:0]  dump_fb_rdata;
    // NEW: SPI from core storage_engine
    logic sd_sck, sd_mosi, sd_miso, sd_cs_n;

    // NEW: PROG-cable tether — FT245 FIFO on FT2232 ch A (T100-style one cable)
    logic       uart_kbd_push;
    logic [7:0] uart_kbd_data;
    logic [5:0] uart_joy_bits;  // NEW: GUI KEYBITS while J15 USB host is dead
    logic [9:0] uart_dump_addr;
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
        .ps2_strobe(ps2_strobe)
    );
    // Merge J15 + Pmod JA + UART (all slow; J15 wins, then Pmod, then tether)
    wire        core_kbd_push = kbd_push | pmod_kbd_push | uart_kbd_push;
    wire [7:0]  core_kbd_data = kbd_push ? kbd_ascii :
                                pmod_kbd_push ? pmod_ascii : uart_kbd_data;

    jmr_js_core u_core (
        .clk(core_clk), .pixel_clk(pixel_clk), .rst_n(rst_n),
        .standalone_mode(1'b1),
        .kbd_push(core_kbd_push), .kbd_data(core_kbd_data),
        // NEW: tether KEYBITS OR I2C stick (same 6-bit field as PYTHON)
        .joy_in(uart_joy_bits | i2c_joy_bits), .joy_out(joy_out),
        .dump_addr(uart_dump_addr), .dump_data(dump_data),
        .cursor(cursor), .ready_lit(ready_lit),
        .scan_addr(scan_addr), .scan_data(scan_data),
        .game_mode(game_mode),
        .fb_raddr(fb_raddr), .fb_rdata(fb_rdata),
        .dump_fb_raddr(dump_fb_raddr), .dump_fb_rdata(dump_fb_rdata),
        .sd_sck(sd_sck), .sd_mosi(sd_mosi), .sd_miso(sd_miso), .sd_cs_n(sd_cs_n)
    );

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
        .game_mode(game_mode),
        .fb_raddr(fb_raddr), .fb_rdata(fb_rdata),
        .vid_pData(vid_pData), .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync), .vid_pVSync(vid_pVSync)
    );

    jmr_rgb2dvi_wrap u_tmds (
        .TMDS_Clk_p(hdmi_tx_clk_p),
        .TMDS_Clk_n(hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_p),
        .TMDS_Data_n(hdmi_tx_n),
        .aRst(~rst_n),
        .vid_pData(vid_pData),
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
endmodule
