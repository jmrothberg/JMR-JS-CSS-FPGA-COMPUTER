// NOT FPGA-SIM. NOT the JS .bit / jmr_js_core. LED-only board proof.
// Build: make -C tools/pmod_input_test → build/pmod_input_test/
// Never add this file to sim/Makefile CORE_SRCS or tools/board_flow.
// Standalone Pmod + J15 USB proof — no console, no HDMI, no VM.
//   JA  Pmod PS/2  (RX-only)  → LD7 character pulse
//   JB  Mini I2C joystick 0x5A → LD0..LD3, LD6
//   J15 USB: retry 0xF4 until ACK. LD4=F4 ok (solid)  LD5=scancode.
// LED row, LD0 on the left:
//   LD0 LEFT  LD1 UP  LD2 DOWN  LD3 RIGHT
//   LD4 USB F4 ACK (solid)  LD5 USB scancode (ps2_rx)
//   LD6 stick OK (solid=ACK, slow blink=alive but no stick)
//   LD7 Pmod keyboard (~200 ms pulse per decoded character)
module top_pmod_input_test (
    input  wire        clk100,
    input  wire        cpu_resetn,
    input  wire        btnc,
    // J15 USB Host — inout: retry 0xF4 until ACK, then ps2_rx.
    input  wire        pmod_ps2_clk,
    input  wire        pmod_ps2_data,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    inout  wire        joy_scl,
    inout  wire        joy_sda,
    output logic [7:0] led
);
    logic rst_n;
    always_ff @(posedge clk100)
        rst_n <= cpu_resetn & ~btnc;

    logic [7:0] scancode;
    logic       strobe, parity_err;
    ps2_rx u_rx (
        .clk(clk100), .rst_n(rst_n),
        .ps2_clk(pmod_ps2_clk), .ps2_data(pmod_ps2_data),
        .scancode(scancode), .strobe(strobe), .parity_err(parity_err)
    );
    logic [7:0] ascii;
    logic       ascii_strobe;
    ps2_decode u_dec (
        .clk(clk100), .rst_n(rst_n),
        .scancode(scancode), .strobe(strobe),
        .ascii(ascii), .ascii_strobe(ascii_strobe)
    );

    // ~200 ms hold so a tap is visible (100 MHz → 20_000_000)
    logic [24:0] key_hold;
    always_ff @(posedge clk100) begin
        if (!rst_n)
            key_hold <= '0;
        else if (ascii_strobe)
            key_hold <= 25'd20_000_000;
        else if (key_hold != 0)
            key_hold <= key_hold - 25'd1;
    end

    // NEW: retry 0xF4 until ACK (one-shot was too early). LD4=f4_ok LD5=byte.
    logic usb_clk_raw, usb_byte;
    usb_ps2_try u_usb (
        .clk(clk100), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .clk_raw(usb_clk_raw), .byte_pulse(usb_byte)
    );

    logic ack_ok, left, up, down, right, fire_ac, fire_bd;
    jmr_i2c_joy u_joy (
        .clk(clk100), .rst_n(rst_n),
        .scl(joy_scl), .sda(joy_sda),
        .ack_ok(ack_ok),
        .left(left), .up(up), .down(down), .right(right),
        .fire_ac(fire_ac), .fire_bd(fire_bd)
    );

    logic [26:0] hb;
    always_ff @(posedge clk100)
        if (!rst_n) hb <= '0;
        else        hb <= hb + 1'b1;

    assign led = {
        (key_hold != 0),                 // LD7 Pmod keyboard
        ack_ok ? 1'b1 : hb[26],          // LD6 stick OK / alive blink
        usb_byte,                        // LD5 USB scancode (ps2_rx)
        usb_clk_raw,                     // LD4 USB F4 ACK (solid)
        right,                           // LD3 RIGHT
        down,                            // LD2 DOWN
        up,                              // LD1 UP
        left                             // LD0 LEFT
    };
endmodule
