// PS/2 host (open-drain) — Nexys Video PIC24 USB-HID emulator.
// After reset: idle, then 0xFF (reset) and 0xF4 (enable scanning).
// If the device never clocks, we time out and release both lines so we
// cannot leave CLOCK held low (that inhibits the keyboard forever).
module jmr_ps2_host (
    input  logic clk,
    input  logic rst_n,
    inout  wire  ps2_clk,
    inout  wire  ps2_data,
    output logic clk_level,
    output logic data_level
);
    localparam int US = 100;                 // ticks per µs @ 100 MHz
    localparam int T_INHIBIT = 120 * US;     // >100 µs clock-low before TX
    localparam int T_IDLE    = 20_000 * US;  // 20 ms after reset
    localparam int T_GAP     = 40_000 * US;  // 40 ms between commands (fits 22-bit tmr)
    localparam int T_BIT     = 2_000 * US;   // 2 ms wait for a device clock

    logic clk_oe, data_oe;                   // 1 = pull low
    assign ps2_clk  = clk_oe  ? 1'b0 : 1'bz;
    assign ps2_data = data_oe ? 1'b0 : 1'bz;

    logic c0, c1, d0;
    always_ff @(posedge clk) begin
        c0 <= ps2_clk; c1 <= c0;
        d0 <= ps2_data;
        clk_level  <= c0;
        data_level <= d0;
    end
    wire fall = c1 & ~c0;

    typedef enum logic [3:0] {
        S_WAIT, S_INH, S_START, S_BIT, S_ACK, S_GAP, S_IDLE
    } state_t;
    state_t state;
    logic [21:0] tmr;
    logic [3:0]  bit_i;
    logic [8:0]  sh;          // {parity, d7..d0} LSB first on the wire
    logic        cmd_is_f4;   // 0 = send FF first, then F4

    function automatic logic oddpar(input logic [7:0] b);
        oddpar = ~^b;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT;
            tmr <= T_IDLE[21:0];
            clk_oe <= 1'b0;
            data_oe <= 1'b0;
            bit_i <= '0;
            sh <= '0;
            cmd_is_f4 <= 1'b0;
        end else begin
            unique case (state)
                S_WAIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                    if (tmr == 0) begin
                        clk_oe <= 1'b1;          // inhibit
                        tmr <= T_INHIBIT[21:0];
                        state <= S_INH;
                    end else tmr <= tmr - 1'b1;
                end
                S_INH: begin
                    clk_oe <= 1'b1;
                    if (tmr == 0) begin
                        data_oe <= 1'b1;         // start bit
                        clk_oe <= 1'b0;          // release clock, device clocks us
                        sh <= {oddpar(cmd_is_f4 ? 8'hF4 : 8'hFF),
                               cmd_is_f4 ? 8'hF4 : 8'hFF};
                        bit_i <= '0;
                        tmr <= T_BIT[21:0];
                        state <= S_START;
                    end else tmr <= tmr - 1'b1;
                end
                S_START: begin
                    data_oe <= 1'b1;
                    clk_oe <= 1'b0;
                    if (fall) begin
                        tmr <= T_BIT[21:0];
                        state <= S_BIT;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0; data_oe <= 1'b0; state <= S_IDLE;
                    end else tmr <= tmr - 1'b1;
                end
                S_BIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= ~sh[0];
                    // Device samples on falling edge; then we shift the next bit.
                    if (fall) begin
                        tmr <= T_BIT[21:0];
                        if (bit_i == 4'd8) state <= S_ACK; // parity just sampled
                        else begin
                            sh <= {1'b1, sh[8:1]};
                            bit_i <= bit_i + 1'b1;
                        end
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0; data_oe <= 1'b0; state <= S_IDLE;
                    end else tmr <= tmr - 1'b1;
                end
                S_ACK: begin
                    data_oe <= 1'b0;             // release for device ACK
                    clk_oe <= 1'b0;
                    if (fall) begin
                        tmr <= T_GAP[21:0];
                        state <= S_GAP;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0; data_oe <= 1'b0; state <= S_IDLE;
                    end else tmr <= tmr - 1'b1;
                end
                S_GAP: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                    if (tmr == 0) begin
                        if (!cmd_is_f4) begin
                            cmd_is_f4 <= 1'b1;
                            clk_oe <= 1'b1;
                            tmr <= T_INHIBIT[21:0];
                            state <= S_INH;
                        end else state <= S_IDLE;
                    end else tmr <= tmr - 1'b1;
                end
                default: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                end
            endcase
        end
    end
endmodule
