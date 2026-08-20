// LIVE JS board PHY (top_nexys_video). Not FPGA-SIM — CORE_SRCS has no I2C.
// Same-named LED-test snapshot: tools/pmod_input_test/jmr_i2c_master.sv
// Edit this file for the machine.
// 100 kHz open-drain I2C master — one register read per `go`.
// Drive 0 or Z only (never 1). Clock-stretch: wait for SCL high after release.
module jmr_i2c_master #(
    parameter int CLK_HZ = 100_000_000,
    parameter int I2C_HZ = 100_000
) (
    input  logic       clk,
    input  logic       rst_n,
    inout  wire        scl,
    inout  wire        sda,
    input  logic       go,
    input  logic [6:0] dev,
    input  logic [7:0] regn,
    output logic [7:0] rdata,
    output logic       done,
    output logic       ack_ok
);
    localparam int QCYC = CLK_HZ / (I2C_HZ * 4); // 250 @ 100 MHz / 100 kHz

    logic scl_oe, sda_oe; // 1 = pull low
    assign scl = scl_oe ? 1'b0 : 1'bz;
    assign sda = sda_oe ? 1'b0 : 1'bz;

    logic scl_i, sda_i;
    always_ff @(posedge clk) begin
        scl_i <= scl;
        sda_i <= sda;
    end

    typedef enum logic [3:0] {
        S_IDLE, S_START, S_WDEV, S_WREG, S_RSTART, S_RDEV, S_RDATA, S_STOP, S_DONE
    } state_t;
    state_t state;

    logic [15:0] qcnt;
    logic        qtick;
    logic [1:0]  qph;
    logic [3:0]  biti;
    logic [7:0]  sh;
    logic        saw_nack;
    logic [7:0]  rsh;

    wire stretch = (qph >= 2'd2) && (scl_oe == 1'b0) && (scl_i == 1'b0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qcnt <= '0;
            qtick <= 1'b0;
        end else begin
            qtick <= 1'b0;
            if (state == S_IDLE || stretch) begin
                qcnt <= '0;
            end else if (qcnt == QCYC[15:0] - 16'd1) begin
                qcnt <= '0;
                qtick <= 1'b1;
            end else begin
                qcnt <= qcnt + 16'd1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            qph <= '0;
            biti <= '0;
            sh <= '0;
            rsh <= '0;
            rdata <= '0;
            done <= 1'b0;
            ack_ok <= 1'b0;
            saw_nack <= 1'b0;
            scl_oe <= 1'b0;
            sda_oe <= 1'b0;
        end else begin
            done <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    scl_oe <= 1'b0;
                    sda_oe <= 1'b0;
                    qph <= '0;
                    biti <= '0;
                    saw_nack <= 1'b0;
                    if (go) begin
                        ack_ok <= 1'b0;
                        state <= S_START;
                    end
                end
                S_START: if (qtick) begin
                    unique case (qph)
                        2'd0: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd1; end
                        2'd1: begin scl_oe <= 1'b0; sda_oe <= 1'b1; qph <= 2'd2; end
                        2'd2: begin scl_oe <= 1'b1; sda_oe <= 1'b1; qph <= 2'd3; end
                        default: begin
                            scl_oe <= 1'b1;
                            qph <= '0;
                            biti <= '0;
                            sh <= {dev, 1'b0};
                            state <= S_WDEV;
                        end
                    endcase
                end
                S_WDEV, S_WREG, S_RDEV: if (qtick) begin
                    if (biti < 4'd8) begin
                        unique case (qph)
                            2'd0: begin scl_oe <= 1'b1; sda_oe <= ~sh[7]; qph <= 2'd1; end
                            2'd1: begin scl_oe <= 1'b1; sda_oe <= ~sh[7]; qph <= 2'd2; end
                            2'd2: begin scl_oe <= 1'b0; sda_oe <= ~sh[7]; qph <= 2'd3; end
                            default: begin
                                scl_oe <= 1'b0;
                                sh <= {sh[6:0], 1'b0};
                                biti <= biti + 4'd1;
                                qph <= '0;
                            end
                        endcase
                    end else begin
                        unique case (qph)
                            2'd0: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd1; end
                            2'd1: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd2; end
                            2'd2: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd3; end
                            default: begin
                                scl_oe <= 1'b0;
                                if (sda_i) saw_nack <= 1'b1;
                                qph <= '0;
                                biti <= '0;
                                if (state == S_WDEV) begin
                                    sh <= regn;
                                    state <= S_WREG;
                                end else if (state == S_WREG) begin
                                    state <= S_RSTART;
                                end else begin
                                    rsh <= '0;
                                    state <= S_RDATA;
                                end
                            end
                        endcase
                    end
                end
                S_RSTART: if (qtick) begin
                    unique case (qph)
                        2'd0: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd1; end
                        2'd1: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd2; end
                        2'd2: begin scl_oe <= 1'b0; sda_oe <= 1'b1; qph <= 2'd3; end
                        default: begin
                            scl_oe <= 1'b1;
                            sda_oe <= 1'b1;
                            qph <= '0;
                            biti <= '0;
                            sh <= {dev, 1'b1};
                            state <= S_RDEV;
                        end
                    endcase
                end
                S_RDATA: if (qtick) begin
                    if (biti < 4'd8) begin
                        unique case (qph)
                            2'd0: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd1; end
                            2'd1: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd2; end
                            2'd2: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd3; end
                            default: begin
                                scl_oe <= 1'b0;
                                rsh <= {rsh[6:0], sda_i};
                                biti <= biti + 4'd1;
                                qph <= '0;
                            end
                        endcase
                    end else begin
                        unique case (qph)
                            2'd0: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd1; end
                            2'd1: begin scl_oe <= 1'b1; sda_oe <= 1'b0; qph <= 2'd2; end
                            2'd2: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd3; end
                            default: begin
                                scl_oe <= 1'b0;
                                rdata <= rsh;
                                qph <= '0;
                                state <= S_STOP;
                            end
                        endcase
                    end
                end
                S_STOP: if (qtick) begin
                    unique case (qph)
                        2'd0: begin scl_oe <= 1'b1; sda_oe <= 1'b1; qph <= 2'd1; end
                        2'd1: begin scl_oe <= 1'b0; sda_oe <= 1'b1; qph <= 2'd2; end
                        2'd2: begin scl_oe <= 1'b0; sda_oe <= 1'b0; qph <= 2'd3; end
                        default: begin
                            scl_oe <= 1'b0;
                            sda_oe <= 1'b0;
                            state <= S_DONE;
                        end
                    endcase
                end
                S_DONE: begin
                    done <= 1'b1;
                    ack_ok <= ~saw_nack;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
