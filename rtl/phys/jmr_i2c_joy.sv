// LIVE JS board PHY (top_nexys_video). Not FPGA-SIM — CORE_SRCS has no I2C.
// Same-named LED-test snapshot: tools/pmod_input_test/jmr_i2c_joy.sv
// Edit this file for the machine. Do not copy usb_ps2_try TX here.
// Poll Mini I2C joystick @ 0x5A (NullLab / PH2.0 handle). NACK → bits off.
// Analog 0..255 center 128, deadzone ±32. Y 0 = top. Idle button = 8.
module jmr_i2c_joy #(
    parameter int CLK_HZ = 100_000_000
) (
    input  logic clk,
    input  logic rst_n,
    inout  wire  scl,
    inout  wire  sda,
    output logic ack_ok,
    output logic left,
    output logic up,
    output logic down,
    output logic right,
    output logic fire_ac,  // A, C, or stick-click
    output logic fire_bd,  // B or D
    output logic [7:0] analog_x,  // raw pot 0..255 (rest ~cx)
    output logic [7:0] analog_y,
    output logic [4:0] buttons    // {click, D, C, B, A}
);
    localparam logic [6:0] DEV = 7'h5A;
    localparam logic [7:0] REG_X = 8'h10;
    localparam logic [7:0] REG_Y = 8'h11;
    localparam logic [7:0] REG_OK = 8'h20;
    localparam logic [7:0] REG_C  = 8'h21;
    localparam logic [7:0] REG_A  = 8'h22;
    localparam logic [7:0] REG_B  = 8'h23;
    localparam logic [7:0] REG_D  = 8'h24;
    // Run 54 (board-verified regression fix): 10 ms polls KILLED the
    // stick — the peripheral's firmware needs the idle gap (50 ms was
    // empirical device tolerance, not laziness), and the old failure
    // branch forced all directions OFF on any bad batch, so a starved
    // device played dead. Two layers now:
    //   1) 25 ms polls (40 Hz; worst staleness ~28 ms — still ~2x
    //      better than the original 55 ms ASTEROID lag).
    //   2) HOLD last state on a transient bad batch; only 8 consecutive
    //      failures (~0.2 s = genuine unplug) clear the outputs.
    localparam int WAIT_POLL = CLK_HZ / 25;  // 40 ms between full polls
    // Run 55 (board: works-then-JAMS at 25 ms, jam holds the last pushed
    // direction = the device MCU wedged and repeats its last sample):
    // the burst of 7 back-to-back register reads is the real stressor —
    // give the device firmware breathing room BETWEEN reads too.
    localparam int READ_GAP  = CLK_HZ / 4000; // 250 us between registers

    logic        go, done, rd_ack;
    logic [7:0]  regn, rdata;
    jmr_i2c_master #(.CLK_HZ(CLK_HZ)) u_i2c (
        .clk(clk), .rst_n(rst_n),
        .scl(scl), .sda(sda),
        .go(go), .dev(DEV), .regn(regn),
        .rdata(rdata), .done(done), .ack_ok(rd_ack)
    );

    function automatic logic btn_held(input logic [7:0] v);
        btn_held = (v != 8'd8) && (v != 8'hFF);
    endfunction

    typedef enum logic [3:0] {
        ST_GO, ST_WAIT, ST_LATCH, ST_GAP, ST_PAUSE
    } st_t;
    st_t st;
    logic [2:0]  step; // 0..6 register index
    logic [22:0] pause;
    logic [2:0]  fail_n;   // consecutive failed batches
    // Run 55 (board JOYDEMO forensics): live L1 while R1 stuck 20 s =
    // the pot RESTS right of nominal center (~145-155), and absolute
    // thresholds (release at 144) never release at rest. Capture the
    // true rest position on the first good batch (stick untouched at
    // power-on) and threshold RELATIVE to it — tolerant of any worn or
    // mis-centered stick. Same +-32 engage / +-16 release geometry.
    logic       cal;
    logic [7:0] cx, cy;
    logic [2:0] good_n;   // consecutive good batches; outputs muted until 7
    logic       ac_p, bd_p; // previous raw button samples (release filter)
    logic [4:0] stkx_n, stky_n; // stuck-release watchdog counters
    logic        batch_ok;
    logic [7:0]  vx, vy, vok, vc, va, vb, vd;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= ST_GO;
            step <= '0;
            go <= 1'b0;
            regn <= REG_X;
            pause <= '0;
            batch_ok <= 1'b1;
            fail_n <= 3'd0;
            cal <= 1'b0;
            cx <= 8'd128;
            cy <= 8'd128;
            good_n <= 3'd0;
            ac_p <= 1'b0;
            bd_p <= 1'b0;
            stkx_n <= 5'd0;
            stky_n <= 5'd0;
            ack_ok <= 1'b0;
            left <= 1'b0;
            up <= 1'b0;
            down <= 1'b0;
            right <= 1'b0;
            fire_ac <= 1'b0;
            fire_bd <= 1'b0;
            analog_x <= 8'd128;
            analog_y <= 8'd128;
            buttons <= 5'd0;
            vx <= 8'd128;
            vy <= 8'd128;
            vok <= 8'd8;
            vc <= 8'd8;
            va <= 8'd8;
            vb <= 8'd8;
            vd <= 8'd8;
        end else begin
            go <= 1'b0;
            unique case (st)
                ST_GO: begin
                    unique case (step)
                        3'd0: regn <= REG_X;
                        3'd1: regn <= REG_Y;
                        3'd2: regn <= REG_OK;
                        3'd3: regn <= REG_C;
                        3'd4: regn <= REG_A;
                        3'd5: regn <= REG_B;
                        default: regn <= REG_D;
                    endcase
                    go <= 1'b1;
                    st <= ST_WAIT;
                end
                ST_WAIT: if (done) st <= ST_LATCH;
                ST_LATCH: begin
                    if (!rd_ack) batch_ok <= 1'b0;
                    unique case (step)
                        3'd0: vx <= rdata;
                        3'd1: vy <= rdata;
                        3'd2: vok <= rdata;
                        3'd3: vc <= rdata;
                        3'd4: va <= rdata;
                        3'd5: vb <= rdata;
                        default: vd <= rdata;
                    endcase
                    if (step == 3'd6 || !rd_ack) begin
                        step <= '0;
                        pause <= WAIT_POLL[22:0];
                        st <= ST_PAUSE;
                    end else begin
                        step <= step + 3'd1;
                        pause <= READ_GAP[22:0];
                        st <= ST_GAP;
                    end
                end
                ST_GAP: begin
                    // inter-register breathing room for the device MCU
                    if (pause != 0) pause <= pause - 23'd1;
                    else st <= ST_GO;
                end
                ST_PAUSE: begin
                    if (pause != 0) begin
                        pause <= pause - 23'd1;
                    end else begin
                        if (batch_ok) begin
                            ack_ok <= 1'b1;
                            fail_n <= 3'd0;
                            if (good_n != 3'd7) begin
                                /* SETTLE WINDOW (board 2026-08-29: buttons
                                   double-fired and directions mislatched at
                                   power-on — early batches glitch). Outputs
                                   stay 0 for the first 8 consecutive good
                                   batches (~320 ms) and the rest position is
                                   re-captured through the whole window, so
                                   calibration is the SETTLED rest, not the
                                   first reading. A bad batch restarts it. */
                                good_n <= good_n + 3'd1;
                                cal <= 1'b1;
                                cx <= vx;
                                cy <= vy;
                                left <= 1'b0; right <= 1'b0;
                                up <= 1'b0; down <= 1'b0;
                                fire_ac <= 1'b0; fire_bd <= 1'b0;
                                ac_p <= 1'b0; bd_p <= 1'b0;
                            end else begin
                                /* Hysteresis relative to the captured rest:
                                   engage at rest+-32, release at rest+-16 —
                                   a pot resting off nominal center can
                                   never latch a direction it is not held
                                   in. 9-bit signed math avoids wrap. */
                                logic signed [9:0] dx9, dy9;
                                logic ac_now, bd_now;
                                dx9 = $signed({2'b0, vx}) - $signed({2'b0, cx});
                                dy9 = $signed({2'b0, vy}) - $signed({2'b0, cy});
                                left  <= (dx9 < -10'sd32) || (left  && dx9 < -10'sd16);
                                right <= (dx9 >  10'sd32) || (right && dx9 >  10'sd16);
                                up    <= (dy9 < -10'sd32) || (up    && dy9 < -10'sd16);
                                down  <= (dy9 >  10'sd32) || (down  && dy9 >  10'sd16);
                                /* DRIFT RE-CENTER (board 2026-08-29: stick
                                   held Left/Right "for a while" — the pot
                                   rest drifts, the one-shot boot center went
                                   stale, and the +-16 release band could no
                                   longer be reached). When an axis is idle
                                   and near rest, slew its center 1 LSB/batch
                                   (~25 LSB/s ceiling) toward the reading. A
                                   real hold (engaged or far from rest) never
                                   re-centers. */
                                if (!left && !right && dx9 > -10'sd28 && dx9 < 10'sd28 && dx9 != 10'sd0)
                                    cx <= (dx9 > 10'sd0) ? cx + 8'd1 : cx - 8'd1;
                                if (!up && !down && dy9 > -10'sd28 && dy9 < 10'sd28 && dy9 != 10'sd0)
                                    cy <= (dy9 > 10'sd0) ? cy + 8'd1 : cy - 8'd1;
                                /* STUCK-RELEASE WATCHDOG (board 2026-08-29:
                                   MISSILE/ASTEROIDS jammed right after a
                                   flick — the pot RETURNED to a rest shifted
                                   past the +-16 release band, and idle
                                   re-centering never runs while engaged, so
                                   the jam self-sustained). A real hold sits
                                   near full deflection, far past engage; a
                                   direction that stays engaged for ~1 s
                                   while |delta| is BELOW the engage
                                   threshold is a stuck return, not a hold:
                                   snap the center to the reading — the
                                   compare releases next batch. */
                                if ((left || right) && dx9 > -10'sd32 && dx9 < 10'sd32) begin
                                    if (stkx_n == 5'd24) begin
                                        cx <= vx; stkx_n <= 5'd0;
                                        left <= 1'b0; right <= 1'b0;
                                    end else stkx_n <= stkx_n + 5'd1;
                                end else stkx_n <= 5'd0;
                                if ((up || down) && dy9 > -10'sd32 && dy9 < 10'sd32) begin
                                    if (stky_n == 5'd24) begin
                                        cy <= vy; stky_n <= 5'd0;
                                        up <= 1'b0; down <= 1'b0;
                                    end else stky_n <= stky_n + 5'd1;
                                end else stky_n <= 5'd0;
                                /* PHANTOM-RELEASE FILTER (double-fire fix):
                                   press passes immediately; release needs
                                   TWO consecutive released batches, so a
                                   one-batch glitch can't mint a new press
                                   edge. Zero added press latency. */
                                ac_now = btn_held(va) | btn_held(vc) | btn_held(vok);
                                bd_now = btn_held(vb) | btn_held(vd);
                                fire_ac <= ac_now || (fire_ac && ac_p);
                                /* v3c (board on run 58: fire 2-3x per press,
                                   game-dependent): the old VM edge bug ERASED
                                   concurrent edges and masked the device
                                   twitching a second button register during
                                   one press. Primary fire stays instant;
                                   the SECONDARY group's press now needs two
                                   consecutive held batches, so a one-batch
                                   crosstalk twitch can't mint an extra
                                   keydown(13) beside every keydown(32). */
                                fire_bd <= (bd_now && bd_p) || (fire_bd && bd_p);
                                ac_p <= ac_now;
                                bd_p <= bd_now;
                                analog_x <= vx;
                                analog_y <= vy;
                                buttons <= {btn_held(vok), btn_held(vd),
                                            btn_held(vc), btn_held(vb),
                                            btn_held(va)};
                            end
                        end else if (fail_n != 3'd7) begin
                            // transient NACK/garbage batch: HOLD last state
                            fail_n <= fail_n + 3'd1;
                            // NOTE: good_n deliberately NOT reset here — a
                            // transient fail after settle must hold-last-
                            // state, not re-mute the stick for 320 ms.
                        end else begin
                            // ~8 consecutive bad batches (~0.2 s): real
                            // disconnect — release everything, loudly off
                            ack_ok <= 1'b0;
                            good_n <= 3'd0; // real disconnect: full resettle+recal on return
                            cal <= 1'b0;
                            left <= 1'b0;
                            up <= 1'b0;
                            down <= 1'b0;
                            right <= 1'b0;
                            fire_ac <= 1'b0;
                            fire_bd <= 1'b0;
                            analog_x <= 8'd128;
                            analog_y <= 8'd128;
                            buttons <= 5'd0;
                        end
                        batch_ok <= 1'b1;
                        st <= ST_GO;
                    end
                end
                default: st <= ST_GO;
            endcase
        end
    end
endmodule
