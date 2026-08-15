// J15 USB: one-shot 0xF4 (no 0xFF — reset stalled this PIC24), then RX-only.
// LD4 = any PS/2 clock fall after idle (PIC24 clocking?).
// LD5 = same ps2_rx as the working Pmod keyboard (assembled byte).
module usb_ps2_try (
    input  logic       clk,    // 100 MHz
    input  logic       rst_n,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    output logic       clk_raw,    // LD4: clock activity after idle
    output logic       byte_pulse  // LD5: ps2_rx strobe
);
    localparam int US = 100;
    localparam int T_INHIBIT = 120 * US;
    localparam int T_BIT     = 2_000 * US;
    localparam int T_HOLD    = 20_000_000;

    logic clk_oe, data_oe;
    assign ps2_clk  = clk_oe  ? 1'b0 : 1'bz;
    assign ps2_data = data_oe ? 1'b0 : 1'bz;

    logic c0, c1;
    always_ff @(posedge clk) begin
        c0 <= ps2_clk;
        c1 <= c0;
    end
    wire fall = c1 & ~c0;

    typedef enum logic [2:0] {
        S_WAIT, S_INH, S_START, S_BIT, S_ACK, S_PAUSE
    } state_t;
    state_t state;
    logic [25:0] tmr;
    logic [3:0]  bit_i;
    logic [8:0]  sh;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT;
            tmr <= 26'd20_000_000;
            clk_oe <= 1'b0;
            data_oe <= 1'b0;
            bit_i <= '0;
            sh <= '0;
        end else begin
            unique case (state)
                S_WAIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                    if (tmr == 0) begin
                        clk_oe <= 1'b1;
                        tmr <= T_INHIBIT[25:0];
                        state <= S_INH;
                    end else tmr <= tmr - 26'd1;
                end
                S_INH: begin
                    clk_oe <= 1'b1;
                    if (tmr == 0) begin
                        data_oe <= 1'b1;
                        clk_oe <= 1'b0;
                        sh <= {~^8'hF4, 8'hF4};
                        bit_i <= '0;
                        tmr <= T_BIT[25:0];
                        state <= S_START;
                    end else tmr <= tmr - 26'd1;
                end
                S_START: begin
                    data_oe <= 1'b1;
                    clk_oe <= 1'b0;
                    if (fall) begin
                        tmr <= T_BIT[25:0];
                        state <= S_BIT;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        state <= S_PAUSE;
                    end else tmr <= tmr - 26'd1;
                end
                S_BIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= ~sh[0];
                    if (fall) begin
                        tmr <= T_BIT[25:0];
                        if (bit_i == 4'd8) state <= S_ACK;
                        else begin
                            sh <= {1'b1, sh[8:1]};
                            bit_i <= bit_i + 4'd1;
                        end
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        state <= S_PAUSE;
                    end else tmr <= tmr - 26'd1;
                end
                S_ACK: begin
                    data_oe <= 1'b0;
                    clk_oe <= 1'b0;
                    if (fall) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        state <= S_PAUSE;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        state <= S_PAUSE;
                    end else tmr <= tmr - 26'd1;
                end
                default: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                end
            endcase
        end
    end

    wire idle = (state == S_PAUSE);

    logic [7:0] scancode;
    logic       strobe, parity_err;
    ps2_rx u_j15_rx (
        .clk(clk), .rst_n(rst_n),
        .ps2_clk(ps2_clk), .ps2_data(ps2_data),
        .scancode(scancode), .strobe(strobe), .parity_err(parity_err)
    );

    logic [24:0] act_hold, byte_hold;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_hold <= '0;
            byte_hold <= '0;
        end else begin
            if (idle && fall) act_hold <= T_HOLD[24:0];
            else if (act_hold != 0) act_hold <= act_hold - 25'd1;
            if (idle && strobe) byte_hold <= T_HOLD[24:0];
            else if (byte_hold != 0) byte_hold <= byte_hold - 25'd1;
        end
    end

    assign clk_raw    = (act_hold != 0);
    assign byte_pulse = (byte_hold != 0);
endmodule
