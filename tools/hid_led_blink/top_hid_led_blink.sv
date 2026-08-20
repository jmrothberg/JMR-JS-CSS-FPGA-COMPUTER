// NOT FPGA-SIM. NOT the JS .bit / jmr_js_core. LED-only J15 proof.
// Build: make -C tools/hid_led_blink → build/hid_led_blink/
// Never add this file to sim/Makefile CORE_SRCS or tools/board_flow.
// Standalone J15 HID proof — no console, no HDMI, no VM.
// PIC24 USB-HID → PS/2 on W17/N13; FPGA is RX-only (do not drive clk low).
// LED map matches the JS top so the same glance works:
//   LD7 = scancode strobe toggle   LD6 = raw ps2_clk (idle high)
//   LD5 = raw ps2_data             LD4 = PS/2 clock activity (~170 ms flicker)
//   LD3:1 = received-byte counter  LD0 = heartbeat (design alive)
module top_hid_led_blink (
    input  wire       clk100,
    input  wire       cpu_resetn,
    input  wire       btnc,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output logic [7:0] led
);
    logic rst_n;
    always_ff @(posedge clk100)
        rst_n <= cpu_resetn & ~btnc;

    logic [7:0] scancode;
    logic       strobe;
    logic       parity_err;
    ps2_rx u_rx (
        .clk(clk100), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .scancode(scancode), .strobe(strobe), .parity_err(parity_err)
    );

    logic [26:0] hb;
    always_ff @(posedge clk100)
        if (!rst_n) hb <= '0;
        else        hb <= hb + 1'b1;

    logic key_blink;
    logic ps2_clk_q;
    // NEW: LD4 was a one-shot latch (it proved edges once, then stuck on).
    // Now every clock fall reloads a ~170 ms timer so live traffic flickers.
    // LD3:1 count decoded bytes — one key press+release = 3 bytes.
    logic [23:0] act_timer;
    logic [2:0]  byte_cnt;
    always_ff @(posedge clk100) begin
        if (!rst_n) begin
            key_blink <= 1'b0;
            ps2_clk_q <= 1'b1;
            act_timer <= '0;
            byte_cnt  <= '0;
        end else begin
            ps2_clk_q <= ps2_clk;
            if (strobe) begin
                key_blink <= ~key_blink;
                byte_cnt  <= byte_cnt + 1'b1;
            end
            if (ps2_clk_q & ~ps2_clk)
                act_timer <= '1;
            else if (act_timer != 0)
                act_timer <= act_timer - 1'b1;
        end
    end

    assign led = {key_blink, ps2_clk, ps2_data, (act_timer != 0), byte_cnt, hb[26]};
endmodule
