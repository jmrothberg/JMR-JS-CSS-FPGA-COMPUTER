// J15 USB: retry 0xF4 until PIC24 ACKs, then RX-only.
// One-shot F4 at 200 ms was too early (PIC24 still leaving config mode).
// LD4 = F4 ACK'd (solid). LD5 = ps2_rx scancode after that.
module usb_ps2_try (
    input  logic       clk,    // 100 MHz
    input  logic       rst_n,
    inout  wire        ps2_clk,
    inout  wire        ps2_data,
    output logic       clk_raw,    // LD4: F4 got a device ACK
    output logic       byte_pulse  // LD5: ps2_rx strobe
);
    localparam int US = 100;
    localparam int T_INHIBIT = 120 * US;
    localparam int T_BIT     = 2_000 * US;
    localparam int T_FIRST   = 100_000_000; // 1 s — PIC24 app mode after DONE
    localparam int T_RETRY   = 20_000_000;  // 200 ms between F4 tries
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
    logic [26:0] tmr;
    logic [3:0]  bit_i;
    logic [8:0]  sh;
    logic        f4_ok;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_WAIT;
            tmr <= T_FIRST[26:0];
            clk_oe <= 1'b0;
            data_oe <= 1'b0;
            bit_i <= '0;
            sh <= '0;
            f4_ok <= 1'b0;
        end else begin
            unique case (state)
                S_WAIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= 1'b0;
                    if (tmr == 0) begin
                        clk_oe <= 1'b1;
                        tmr <= T_INHIBIT[26:0];
                        state <= S_INH;
                    end else tmr <= tmr - 27'd1;
                end
                S_INH: begin
                    clk_oe <= 1'b1;
                    if (tmr == 0) begin
                        data_oe <= 1'b1;
                        clk_oe <= 1'b0;
                        sh <= {~^8'hF4, 8'hF4};
                        bit_i <= '0;
                        tmr <= T_BIT[26:0];
                        state <= S_START;
                    end else tmr <= tmr - 27'd1;
                end
                S_START: begin
                    data_oe <= 1'b1;
                    clk_oe <= 1'b0;
                    if (fall) begin
                        tmr <= T_BIT[26:0];
                        state <= S_BIT;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        tmr <= T_RETRY[26:0];
                        state <= S_WAIT;
                    end else tmr <= tmr - 27'd1;
                end
                S_BIT: begin
                    clk_oe <= 1'b0;
                    data_oe <= ~sh[0];
                    if (fall) begin
                        tmr <= T_BIT[26:0];
                        if (bit_i == 4'd8) state <= S_ACK;
                        else begin
                            sh <= {1'b1, sh[8:1]};
                            bit_i <= bit_i + 4'd1;
                        end
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        tmr <= T_RETRY[26:0];
                        state <= S_WAIT;
                    end else tmr <= tmr - 27'd1;
                end
                S_ACK: begin
                    data_oe <= 1'b0;
                    clk_oe <= 1'b0;
                    if (fall) begin
                        f4_ok <= 1'b1;
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        state <= S_PAUSE;
                    end else if (tmr == 0) begin
                        clk_oe <= 1'b0;
                        data_oe <= 1'b0;
                        tmr <= T_RETRY[26:0];
                        state <= S_WAIT;
                    end else tmr <= tmr - 27'd1;
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

    logic [24:0] byte_hold;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) byte_hold <= '0;
        else if (idle && strobe) byte_hold <= T_HOLD[24:0];
        else if (byte_hold != 0) byte_hold <= byte_hold - 25'd1;
    end

    assign clk_raw    = f4_ok;           // solid ON once PIC24 ACKed 0xF4
    assign byte_pulse = (byte_hold != 0);
endmodule
