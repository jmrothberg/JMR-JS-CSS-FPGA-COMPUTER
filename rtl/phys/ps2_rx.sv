// PS/2 receiver — Digilent Nexys-Video-Keyboard method (debounce + fall sample).
// NEW: input-only (no host TX). Video PIC24 edges are noisy; BASIC A7 2-flop
// alone can miss frames on this board. Debounce matches Digilent COUNT_MAX=19
// @ 50 MHz → ~40 @ 100 MHz.
module ps2_rx (
    input  logic       clk,      // 100 MHz system clock
    input  logic       rst_n,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    output logic [7:0] scancode,
    output logic       strobe,   // 1-cycle pulse when byte ready
    output logic       parity_err
);
    // ~400 ns stable (Digilent COUNT_MAX=19 @ 50 MHz → 39 @ 100 MHz)
    localparam int DB_MAX = 39;
    logic [5:0] db_c, db_d;
    logic       clk_i, clk_q, dat_i, dat_f;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            db_c <= '0; db_d <= '0;
            clk_i <= 1'b1; clk_q <= 1'b1;
            dat_i <= 1'b1; dat_f <= 1'b1;
        end else begin
            if (ps2_clk == clk_i) begin
                if (db_c == DB_MAX[5:0]) clk_q <= clk_i;
                else db_c <= db_c + 1'b1;
            end else begin
                db_c <= '0;
                clk_i <= ps2_clk;
            end
            if (ps2_data == dat_i) begin
                if (db_d == DB_MAX[5:0]) dat_f <= dat_i;
                else db_d <= db_d + 1'b1;
            end else begin
                db_d <= '0;
                dat_i <= ps2_data;
            end
        end
    end

    logic c1, c2;
    always_ff @(posedge clk) begin
        c1 <= clk_q;
        c2 <= c1;
    end
    wire fall = c2 & ~c1;

    logic [3:0] bit_cnt;
    logic [10:0] shift;
    logic collecting;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= '0;
            shift <= '0;
            collecting <= 1'b0;
            strobe <= 1'b0;
            scancode <= 8'h00;
            parity_err <= 1'b0;
        end else begin
            strobe <= 1'b0;
            if (fall) begin
                if (!collecting) begin
                    if (dat_f == 1'b0) begin // start bit
                        collecting <= 1'b1;
                        bit_cnt <= 4'd0;
                        shift <= '0;
                    end
                end else begin
                    if (bit_cnt == 4'd9) begin
                        collecting <= 1'b0;
                        bit_cnt <= '0;
                        scancode <= shift[9:2];
                        parity_err <= ^{shift[10], shift[9:2]};
                        strobe <= 1'b1;
                    end else begin
                        shift <= {dat_f, shift[10:1]};
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                end
            end
        end
    end
endmodule
