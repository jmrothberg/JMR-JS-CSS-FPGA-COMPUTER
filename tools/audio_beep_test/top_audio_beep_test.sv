// NOT FPGA-SIM. NOT the JS .bit / jmr_js_core. Standalone audio proof.
// Build: make -C tools/audio_beep_test bit flash  -> build/audio_beep_test/
// Never add these .sv files to sim/Makefile CORE_SRCS or tools/board_flow.
//
// Phase 0 of docs plan "FPGA line-out PSG": prove the ADAU1761 line-out
// path (J5) with the smallest possible design. No VM, no HDMI, no DDR3,
// no SD -- if this is silent, the problem is the codec/clock/wiring and
// NOT the console, which is exactly what a phase-0 test is for.
//
// LED map (LD0 leftmost):
//   LD0 solid  MMCM locked (12 MHz MCLK exists)
//   LD1 solid  I2C init sequence finished
//   LD2 solid  every I2C byte was ACKed  -> codec is present and talking
//   LD3 solid  at least one NACK (sticky) -> I2C/wiring fault, not audio
//   LD4 blink  LRCLK alive (~1.4 Hz) -> I2S frame clock is running
//   LD5 blink  tone gate (~2 Hz) -> the beep should be audible NOW
//   LD6..LD7   I2C ROM step counter (high bits) -- shows where it stalled
//
// Reading the LEDs when you hear nothing:
//   LD0 dark            -> MMCM/clock problem; nothing else is valid
//   LD0 on, LD3 on      -> codec never ACKed: address/pins/pull-ups
//   LD2 on, LD4 dark    -> codec configured but no I2S frame clock
//   LD2+LD4+LD5 all on  -> plumbing is correct; suspect the register
//                          VALUES in jmr_adau1761_cfg.sv (see its header)
module top_audio_beep_test (
    input  wire        clk100,
    input  wire        cpu_resetn,
    input  wire        btnc,
    // ADAU1761 (Nexys Video J5 line-out)
    output wire        ac_mclk,
    output wire        ac_bclk,
    output wire        ac_lrclk,
    output wire        ac_dac_sdata,
    inout  wire        ac_scl,
    inout  wire        ac_sda,
    output logic [7:0] led
);
    // ---- MMCM: 100 MHz -> 12 MHz MCLK --------------------------------
    // VCO = 100 * 12 = 1200 MHz (inside the -1 speed grade range with
    // DIVCLK 1), CLKOUT0 = 1200 / 100 = 12 MHz.  The main design's plan
    // reuses an unused CLKOUT of the existing MMCM instead; this test is
    // standalone so it owns a private one.
    logic mclk_raw, mclk_bufg, locked, clkfb;
    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(12.0),
        .CLKIN1_PERIOD(10.0),
        .CLKOUT0_DIVIDE_F(100.0),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKOUT0(mclk_raw), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .CLKFBOUT(clkfb), .CLKFBOUTB(),
        .LOCKED(locked), .CLKIN1(clk100),
        .PWRDWN(1'b0), .RST(~cpu_resetn), .CLKFBIN(clkfb)
    );
    BUFG u_mclk_bufg (.I(mclk_raw), .O(mclk_bufg));
    assign ac_mclk = mclk_bufg;

    // ---- resets ------------------------------------------------------
    logic rst100_n;
    always_ff @(posedge clk100)
        rst100_n <= cpu_resetn & locked & ~btnc;

    logic [1:0] rstm_sync;
    logic       rstm_n;
    always_ff @(posedge mclk_bufg) begin
        rstm_sync <= {rstm_sync[0], (cpu_resetn & locked & ~btnc)};
        rstm_n    <= rstm_sync[1];
    end

    // ---- codec register init (I2C, on clk100) ------------------------
    logic       cfg_done, cfg_nack;
    logic [5:0] cfg_step;
    logic       scl_oe, sda_oe;
    jmr_adau1761_cfg #(
        .CLK_HZ(100_000_000), .I2C_HZ(100_000), .START_DLY(100_000)
    ) u_cfg (
        .clk(clk100), .rst_n(rst100_n),
        .scl_oe(scl_oe), .sda_oe(sda_oe), .sda_i(ac_sda),
        .done(cfg_done), .ack_fail(cfg_nack), .step_o(cfg_step)
    );

    // Open-drain pads live here, not in the leaf: drive low or release to
    // the board's pull-ups. Never drive high — this is a shared bus.
    assign ac_scl = scl_oe ? 1'b0 : 1'bz;
    assign ac_sda = sda_oe ? 1'b0 : 1'bz;

    // Cross the two status bits into the MCLK domain to gate the tone.
    logic [1:0] done_sync;
    always_ff @(posedge mclk_bufg) done_sync <= {done_sync[0], cfg_done};

    // ---- I2S + tone (on MCLK) ----------------------------------------
    logic beep_on, lr_toggle;
    jmr_i2s_beep #(
        .MCLK_HZ(12_000_000), .TONE_HZ(440)
    ) u_i2s (
        .mclk(mclk_bufg), .rst_n(rstm_n),
        .enable(done_sync[1]),
        .bclk(ac_bclk), .lrclk(ac_lrclk), .dac_sdata(ac_dac_sdata),
        .beep_on(beep_on), .lr_toggle(lr_toggle)
    );

    always_ff @(posedge clk100) begin
        led[0] <= locked;
        led[1] <= cfg_done;
        led[2] <= cfg_done & ~cfg_nack;
        led[3] <= cfg_nack;
        led[4] <= lr_toggle;
        led[5] <= beep_on;
        led[6] <= cfg_step[4];
        led[7] <= cfg_step[5];
    end
endmodule
