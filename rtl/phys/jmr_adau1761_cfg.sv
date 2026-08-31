// Live ADAU1761 init for the JS bitstream (line-out PSG phase 1).
// Verbatim from the bench-verified phase-0 snapshot in tools/audio_beep_test/
// (which stays frozen by design — fix bugs HERE and back-port explicitly).
// Write-only I2C master + ADAU1761 register init ROM (Nexys Video J5).
//
// Deliberately NOT rtl/phys/jmr_i2c_master.sv: that one is a read/write
// joystick master on a Pmod. This is write-only, 16-bit subaddress, and
// must stay a snapshot so the live PHY can never be perturbed by an
// audio experiment (same rule as tools/pmod_input_test's I2C snapshot).
//
// Codec address 0x3B (ADDR0/ADDR1 strapped on the Nexys Video), so the
// write byte is {0x3B,1'b0} = 0x76. Frame per register:
//   START, 0x76, reg[15:8], reg[7:0], data, STOP
//
// ack_fail is STICKY and per-step: if the codec never answers, the top
// lights an LED and you know the fault is I2C/wiring, not I2S/tone.
module jmr_adau1761_cfg #(
    parameter int CLK_HZ   = 100_000_000,
    parameter int I2C_HZ   = 100_000,
    // Hold off until MCLK has been running a while: the codec's control
    // port is spec'd with MCLK present, and the MMCM needs to be locked.
    parameter int START_DLY = 100_000  // 1 ms at 100 MHz
) (
    input  wire  clk,
    input  wire  rst_n,
    // Open-drain drive enables; the TOP owns the tristate pads. Keeping
    // the pads out of this leaf makes the module directly simulatable
    // (Verilator cannot resolve a 'z' driven inside a leaf), which is how
    // the I2C framing here was verified before it was ever flashed.
    output logic scl_oe,        // 1 = pull SCL low, 0 = release to pull-up
    output logic sda_oe,        // 1 = pull SDA low, 0 = release
    input  wire  sda_i,         // sampled SDA (for ACK)
    output logic done,          // init sequence finished
    output logic ack_fail,      // sticky: at least one byte was NACKed
    output logic [5:0] step_o   // which ROM entry we are on (LED debug)
);
    // ---------------------------------------------------------------
    // Register init ROM.
    //
    // *** THIS TABLE IS THE MOST LIKELY THING TO NEED A TWEAK. ***
    // The clocking, I2C framing and I2S timing in this test are
    // structural and easy to verify on a scope / with the LEDs. These
    // register VALUES are the codec's programming model and are worth
    // checking against the ADAU1761 datasheet (Rev C) register map
    // before assuming the hardware is broken.
    //
    // Intent of the sequence: MCLK direct (no codec PLL), 256*fs, codec
    // is I2S SLAVE (the FPGA drives BCLK/LRCLK), DAC -> mixer -> line
    // out at 0 dB, both channels powered.  fs = 12 MHz / 256 = 46.875 kHz.
    // ---------------------------------------------------------------
    localparam int NREG = 18;
    logic [23:0] rom [0:NREG-1];
    initial begin
        rom[0]  = {16'h4000, 8'h01}; // R0  clock ctrl: COREN, 256*fs, MCLK direct
        rom[1]  = {16'h40F9, 8'h7F}; // R65 clock enable 0 (all blocks)
        rom[2]  = {16'h40FA, 8'h03}; // R66 clock enable 1
        rom[3]  = {16'h4015, 8'h00}; // R15 serial port 0: SLAVE, I2S
        rom[4]  = {16'h4016, 8'h00}; // R16 serial port 1: 32 BCLK/chan, MSB first
        rom[5]  = {16'h4017, 8'h00}; // R17 converter 0: fs = 1x
        rom[6]  = {16'h4019, 8'h13}; // R19 ADC ctrl (ADC unused; keep defaults sane)
        rom[7]  = {16'h401C, 8'h21}; // R22 playback mixer L0: mixer on, DAC-L in
        rom[8]  = {16'h401E, 8'h41}; // R24 playback mixer R0: mixer on, DAC-R in
        rom[9]  = {16'h4020, 8'h05}; // R26 playback LR mixer L: enable, 0 dB
        rom[10] = {16'h4021, 8'h11}; // R27 playback LR mixer R: enable, 0 dB
        rom[11] = {16'h4023, 8'hE7}; // R29 HP left  vol: unmute, HPEN
        rom[12] = {16'h4024, 8'hE7}; // R30 HP right vol: unmute
        rom[13] = {16'h4025, 8'hE7}; // R31 line out left  vol: unmute
        rom[14] = {16'h4026, 8'hE7}; // R32 line out right vol: unmute
        rom[15] = {16'h4029, 8'h03}; // R35 playback power: L+R enabled
        rom[16] = {16'h402A, 8'h03}; // R36 DAC ctrl 0: both DACs on
        rom[17] = {16'h40F2, 8'h01}; // R58 serial input route -> DAC (bypass DSP)
    end

    // Sync the incoming SDA (pad is owned by the top).
    logic sda_in;
    always_ff @(posedge clk) sda_in <= sda_i;

    localparam int DIV = CLK_HZ / (I2C_HZ * 4);  // quarter-bit tick
    logic [15:0] divc;
    logic        tick;
    always_ff @(posedge clk) begin
        if (!rst_n) begin divc <= '0; tick <= 1'b0; end
        else if (divc == DIV[15:0] - 16'd1) begin divc <= '0; tick <= 1'b1; end
        else begin divc <= divc + 16'd1; tick <= 1'b0; end
    end

    typedef enum logic [3:0] {
        S_WAIT, S_START, S_BYTE, S_ACK, S_NEXT, S_STOP, S_GAP, S_DONE
    } st_t;
    st_t st;

    logic [31:0] dly;
    logic [5:0]  step;      // ROM index
    logic [1:0]  bytesel;   // 0=addr 1=reg_hi 2=reg_lo 3=data
    logic [2:0]  bitn;
    logic [1:0]  ph;        // quarter-bit phase
    logic [7:0]  shifter;

    assign step_o = step;

    function automatic logic [7:0] byte_of(input logic [1:0] sel,
                                           input logic [23:0] e);
        case (sel)
            2'd0: byte_of = 8'h76;        // 0x3B write
            2'd1: byte_of = e[23:16];
            2'd2: byte_of = e[15:8];
            default: byte_of = e[7:0];
        endcase
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            st <= S_WAIT; dly <= '0; step <= '0; bytesel <= '0;
            bitn <= '0; ph <= '0; shifter <= '0;
            scl_oe <= 1'b0; sda_oe <= 1'b0;
            done <= 1'b0; ack_fail <= 1'b0;
        end else begin
            case (st)
                // Let MCLK + the codec's own reset settle before talking.
                S_WAIT: begin
                    if (dly >= START_DLY[31:0]) begin
                        st <= S_START; ph <= '0;
                    end else dly <= dly + 32'd1;
                end
                // START: SDA falls while SCL is high.
                S_START: if (tick) begin
                    case (ph)
                        2'd0: begin sda_oe <= 1'b0; scl_oe <= 1'b0; end // both high
                        2'd1: sda_oe <= 1'b1;                          // SDA low
                        2'd3: begin
                            scl_oe  <= 1'b1;                           // SCL low
                            shifter <= byte_of(bytesel, rom[step]);
                            bitn    <= 3'd7;
                            st      <= S_BYTE;
                        end
                        default: ;
                    endcase
                    ph <= ph + 2'd1;
                end
                // 8 data bits, MSB first. SDA changes while SCL low.
                S_BYTE: if (tick) begin
                    case (ph)
                        2'd0: sda_oe <= ~shifter[7];  // drive bit (0 => pull low)
                        2'd1: scl_oe <= 1'b0;         // SCL high
                        2'd3: begin
                            scl_oe <= 1'b1;           // SCL low
                            if (bitn == 3'd0) begin
                                sda_oe <= 1'b0;       // release for ACK
                                st     <= S_ACK;
                            end else begin
                                shifter <= {shifter[6:0], 1'b0};
                                bitn    <= bitn - 3'd1;
                            end
                        end
                        default: ;
                    endcase
                    ph <= ph + 2'd1;
                end
                // ACK: codec pulls SDA low during the 9th clock.
                S_ACK: if (tick) begin
                    case (ph)
                        2'd1: scl_oe <= 1'b0;                 // SCL high
                        2'd2: if (sda_in) ack_fail <= 1'b1;   // NACK (sticky)
                        2'd3: begin scl_oe <= 1'b1; st <= S_NEXT; end
                        default: ;
                    endcase
                    ph <= ph + 2'd1;
                end
                S_NEXT: begin
                    if (bytesel == 2'd3) begin
                        st <= S_STOP; ph <= '0;
                    end else begin
                        bytesel <= bytesel + 2'd1;
                        shifter <= byte_of(bytesel + 2'd1, rom[step]);
                        bitn    <= 3'd7;
                        st      <= S_BYTE;
                        ph      <= '0;
                    end
                end
                // STOP: SDA rises while SCL is high.
                S_STOP: if (tick) begin
                    case (ph)
                        2'd0: sda_oe <= 1'b1;   // SDA low
                        2'd1: scl_oe <= 1'b0;   // SCL high
                        2'd2: sda_oe <= 1'b0;   // SDA high => STOP
                        2'd3: begin
                            bytesel <= '0;
                            dly     <= '0;
                            st      <= S_GAP;
                        end
                        default: ;
                    endcase
                    ph <= ph + 2'd1;
                end
                // Small bus-idle gap between register writes.
                S_GAP: begin
                    if (dly >= 32'd2000) begin
                        if (step == NREG[5:0] - 6'd1) begin
                            done <= 1'b1;
                            st   <= S_DONE;
                        end else begin
                            step <= step + 6'd1;
                            ph   <= '0;
                            st   <= S_START;
                        end
                    end else dly <= dly + 32'd1;
                end
                S_DONE: ;
                default: st <= S_DONE;
            endcase
        end
    end
endmodule
