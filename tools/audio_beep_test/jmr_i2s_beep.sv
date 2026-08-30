// NOT FPGA-SIM. NOT the JS .bit. Standalone beep-test only.
// I2S master + square-wave tone for the ADAU1761 on the Nexys Video.
//
// Everything here runs on MCLK (12 MHz from the MMCM), so the audio
// clocking is a pure divide chain with no CDC to get wrong:
//   BCLK  = MCLK / 4   = 3.000 MHz
//   LRCLK = MCLK / 256 = 46.875 kHz  = fs
//   -> 64 BCLK per LRCLK period = 32 bits per channel (standard I2S slot)
//
// I2S framing: LRCLK low = left. Data is MSB first and delayed ONE BCLK
// after the LRCLK edge, changing on the falling BCLK so the codec samples
// it cleanly on the rising edge.
//
// The tone deliberately beeps (on/off) rather than droning: a steady tone
// is easy to confuse with hum or a ground loop, while 440 Hz gated at
// ~2 Hz is unmistakably a digital source doing what it was told.
module jmr_i2s_beep #(
    parameter int MCLK_HZ  = 12_000_000,
    parameter int TONE_HZ  = 440,
    parameter int AMPL     = 24'h180000  // ~ -6 dBFS of a 24-bit range
) (
    input  wire  mclk,
    input  wire  rst_n,
    input  wire  enable,        // gate: mute unless the codec is configured
    output logic bclk,
    output logic lrclk,
    output logic dac_sdata,
    output logic beep_on,       // LED: tone gate currently open
    output logic lr_toggle      // LED: slow divide of LRCLK => "I2S is alive"
);
    // ---- clock chain -------------------------------------------------
    // cnt[1] is MCLK/4 = BCLK; cnt[7] is MCLK/256 = LRCLK.
    logic [7:0] cnt;
    always_ff @(posedge mclk)
        if (!rst_n) cnt <= '0;
        else        cnt <= cnt + 8'd1;

    assign bclk  = cnt[1];
    assign lrclk = cnt[7];

    // ---- tone: square wave, gated on/off ----------------------------
    // Half-period in fs ticks: fs / (2 * TONE_HZ).
    localparam int FS_HZ    = MCLK_HZ / 256;
    localparam int HALF_TCK = FS_HZ / (2 * TONE_HZ);
    localparam int GATE_TCK = FS_HZ / 4;   // ~250 ms on, 250 ms off

    logic fs_tick;                          // one pulse per LRCLK period
    logic lrclk_q;
    always_ff @(posedge mclk) begin
        lrclk_q <= lrclk;
        fs_tick <= (~lrclk_q & lrclk);      // rising edge of LRCLK
    end

    logic [15:0] half_c;
    logic        sq;
    logic [15:0] gate_c;
    always_ff @(posedge mclk) begin
        if (!rst_n) begin
            half_c <= '0; sq <= 1'b0; gate_c <= '0; beep_on <= 1'b0;
        end else if (fs_tick) begin
            if (half_c >= HALF_TCK[15:0] - 16'd1) begin
                half_c <= '0;
                sq     <= ~sq;
            end else half_c <= half_c + 16'd1;

            if (gate_c >= GATE_TCK[15:0] - 16'd1) begin
                gate_c  <= '0;
                beep_on <= ~beep_on;
            end else gate_c <= gate_c + 16'd1;
        end
    end

    logic signed [23:0] sample;
    always_comb begin
        if (!enable || !beep_on) sample = 24'sd0;
        else                     sample = sq ?  $signed(AMPL)
                                             : -$signed(AMPL);
    end

    // ---- I2S shift ---------------------------------------------------
    // Load the sample one BCLK after each LRCLK edge, then shift MSB
    // first on every falling BCLK.
    logic [23:0] shreg;
    logic [5:0]  bitc;
    logic        bclk_q, lr_q2;
    always_ff @(posedge mclk) begin
        if (!rst_n) begin
            shreg <= '0; bitc <= '0; dac_sdata <= 1'b0;
            bclk_q <= 1'b0; lr_q2 <= 1'b0;
        end else begin
            bclk_q <= bclk;
            lr_q2  <= lrclk;
            // LRCLK edge (either direction) starts a new 32-bit slot
            if (lr_q2 != lrclk) begin
                shreg <= sample;
                bitc  <= 6'd0;
            end else if (bclk_q & ~bclk) begin   // falling BCLK
                if (bitc == 6'd0) begin
                    dac_sdata <= 1'b0;           // one-BCLK I2S delay
                    bitc      <= 6'd1;
                end else if (bitc <= 6'd24) begin
                    dac_sdata <= shreg[23];
                    shreg     <= {shreg[22:0], 1'b0};
                    bitc      <= bitc + 6'd1;
                end else begin
                    dac_sdata <= 1'b0;           // pad the 32-bit slot
                    bitc      <= bitc + 6'd1;
                end
            end
        end
    end

    // Visible proof the frame clock is running (46.875 kHz / 2^15 ~ 1.4 Hz).
    logic [14:0] lrdiv;
    always_ff @(posedge mclk)
        if (!rst_n) begin lrdiv <= '0; lr_toggle <= 1'b0; end
        else if (fs_tick) begin
            lrdiv <= lrdiv + 15'd1;
            if (lrdiv == 15'd0) lr_toggle <= ~lr_toggle;
        end
endmodule
