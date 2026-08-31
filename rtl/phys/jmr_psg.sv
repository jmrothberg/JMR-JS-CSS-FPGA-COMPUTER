// 4-voice PSG + I2S master for the ADAU1761 line-out (Nexys Video J5).
// Phase 1 of the line-out PSG plan (~/.cursor/plans/fpga_line-out_psg_*).
//
// Everything runs on MCLK (12 MHz, main MMCM CLKOUT1 /50). The clock chain
// and I2S framing are byte-for-byte the shape proven by the phase-0 beep
// test (tools/audio_beep_test — bench-verified framing, do not "improve"):
//   BCLK = MCLK/4 = 3 MHz, LRCLK = MCLK/256 -> fs = 46.875 kHz,
//   64 BCLK/frame = 32-bit slots, data MSB-first delayed one BCLK.
//
// Voices: 0-2 square (phase-accumulator MSB), 3 noise (LFSR16 stepped by
// its own phase MSB, so the noise is pitched by freq like the squares).
// Envelope: `frames` counts down at ~60 Hz (fs/781 = 60.02 Hz) and `slide`
// (signed Hz/frame) walks freq each tick — enough for arcade laser/boom
// shapes without any per-frame JS mixing.
//
// Fit contract (plan "do not violate"): 0 BRAM, 0 DSP, no extra MMCM.
// freq->phase-increment is a 5-term shift-add (x358 ~= 2^24/46875, i.e.
// phase[23] toggles at ~freq Hz); vol is amp = vol<<13, so the 4-voice sum
// peaks at 491,520 — inside 24-bit signed with no clamp needed.
//
// Trigger CDC: exec64 latches (ch,freq,vol,frames,slide) on the core clock
// and flips snd_tgl. Here a 2FF sync + edge detect samples the args one
// mclk later — the args are stable for milliseconds around a poke (JS
// cannot re-poke within 83 ns), so a plain level sync of the bus is safe.
(* keep_hierarchy = "yes" *)
module jmr_psg (
    input  wire         mclk,
    input  wire         rst_n,
    input  wire         enable,      // codec configured (cfg_done, synced)
    input  wire         mute,        // ready_lit: console prompt = silence
    // poke interface (core-clock registers, held stable; see CDC note)
    input  wire         snd_tgl,
    input  wire  [1:0]  snd_ch,
    input  wire  [15:0] snd_freq,
    input  wire  [3:0]  snd_vol,
    input  wire  [7:0]  snd_frames,
    input  wire  [7:0]  snd_slide,   // signed Hz per 60 Hz frame
    // I2S out
    output logic        bclk,
    output logic        lrclk,
    output logic        dac_sdata
);
    // ---- clock chain (beep-test shape, proven) -----------------------
    logic [7:0] cnt;
    always_ff @(posedge mclk)
        if (!rst_n) cnt <= '0;
        else        cnt <= cnt + 8'd1;
    assign bclk  = cnt[1];
    assign lrclk = cnt[7];
    wire sample_tick = (cnt == 8'hFF); // one per LRCLK period (fs)

    // ---- ~60 Hz envelope tick ---------------------------------------
    logic [9:0] ftdiv;
    logic       frame_tick;
    always_ff @(posedge mclk) begin
        frame_tick <= 1'b0;
        if (!rst_n) ftdiv <= '0;
        else if (sample_tick) begin
            if (ftdiv == 10'd780) begin ftdiv <= '0; frame_tick <= 1'b1; end
            else ftdiv <= ftdiv + 10'd1;
        end
    end

    // ---- poke CDC (toggle -> pulse) ---------------------------------
    logic [2:0] tgl_sync;
    always_ff @(posedge mclk)
        if (!rst_n) tgl_sync <= '0;
        else        tgl_sync <= {tgl_sync[1:0], snd_tgl};
    wire poke = tgl_sync[2] ^ tgl_sync[1];

    // ---- voices ------------------------------------------------------
    logic [15:0] vfreq   [0:3];
    logic [3:0]  vvol    [0:3];
    logic [7:0]  vframes [0:3];
    logic [7:0]  vslide  [0:3];
    logic [23:0] vphase  [0:3];
    logic [15:0] lfsr;

    // freq * 358 = freq*(256+64+32+4+2): phase[23] toggles at ~freq Hz.
    function automatic logic [23:0] incr_of(input logic [15:0] f);
        incr_of = ({8'd0, f} << 8) + ({8'd0, f} << 6) + ({8'd0, f} << 5)
                + ({8'd0, f} << 2) + ({8'd0, f} << 1);
    endfunction

    logic [3:0] ph23_q; // per-voice phase MSB history (noise stepping)

    always_ff @(posedge mclk) begin
        if (!rst_n) begin
            for (int v = 0; v < 4; v++) begin
                vfreq[v] <= '0; vvol[v] <= '0; vframes[v] <= '0;
                vslide[v] <= '0; vphase[v] <= '0;
            end
            lfsr <= 16'hACE1;
            ph23_q <= '0;
        end else begin
            // retrigger: fresh phase makes repeated pokes attack cleanly
            if (poke) begin
                vfreq[snd_ch]   <= snd_freq;
                vvol[snd_ch]    <= snd_vol;
                vframes[snd_ch] <= snd_frames;
                vslide[snd_ch]  <= snd_slide;
                vphase[snd_ch]  <= '0;
            end
            if (frame_tick)
                for (int v = 0; v < 4; v++)
                    if (vframes[v] != 8'd0) begin
                        vframes[v] <= vframes[v] - 8'd1;
                        vfreq[v]   <= 16'($signed(vfreq[v])
                                          + 16'($signed(vslide[v])));
                    end
            if (sample_tick)
                for (int v = 0; v < 4; v++) begin
                    vphase[v] <= vphase[v] + incr_of(vfreq[v]);
                    ph23_q[v] <= vphase[v][23];
                end
            // noise: step the LFSR on voice 3's phase-MSB rise
            if (sample_tick && vphase[3][23] && !ph23_q[3])
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end

    // ---- mix (registered once per sample) ----------------------------
    logic signed [23:0] sample;
    always_ff @(posedge mclk)
        if (!rst_n) sample <= '0;
        else if (sample_tick) begin
            logic signed [23:0] acc;
            acc = '0;
            for (int v = 0; v < 4; v++)
                if (vframes[v] != 8'd0 && vvol[v] != 4'd0) begin
                    logic hi;
                    hi = (v == 3) ? lfsr[0] : vphase[v][23];
                    acc = hi ? (acc + 24'(signed'({1'b0, vvol[v], 13'd0})))
                             : (acc - 24'(signed'({1'b0, vvol[v], 13'd0})));
                end
            sample <= (enable && !mute) ? acc : 24'sd0;
        end

    // ---- I2S shifter (beep-test shape: 1-BCLK delay, MSB first) ------
    logic [4:0]  bitc;
    logic [23:0] sh;
    always_ff @(posedge mclk) begin
        if (!rst_n) begin
            bitc <= '0; sh <= '0; dac_sdata <= 1'b0;
        end else if (cnt[1:0] == 2'b11) begin      // falling BCLK
            if (cnt[6:2] == 5'd0) begin            // slot start (each half-frame)
                bitc <= 5'd0;
                sh   <= sample;                    // same sample both slots
                dac_sdata <= 1'b0;                 // the one-BCLK delay
            end else if (bitc < 5'd24) begin
                dac_sdata <= sh[23];
                sh   <= {sh[22:0], 1'b0};
                bitc <= bitc + 5'd1;
            end else
                dac_sdata <= 1'b0;                 // zero-pad to 32
        end
    end
endmodule
