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
    output logic fire_bd   // B or D
);
    localparam logic [6:0] DEV = 7'h5A;
    localparam logic [7:0] REG_X = 8'h10;
    localparam logic [7:0] REG_Y = 8'h11;
    localparam logic [7:0] REG_OK = 8'h20;
    localparam logic [7:0] REG_C  = 8'h21;
    localparam logic [7:0] REG_A  = 8'h22;
    localparam logic [7:0] REG_B  = 8'h23;
    localparam logic [7:0] REG_D  = 8'h24;
    localparam int WAIT_50MS = CLK_HZ / 20; // 50 ms between full polls

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
        ST_GO, ST_WAIT, ST_LATCH, ST_PAUSE
    } st_t;
    st_t st;
    logic [2:0]  step; // 0..6 register index
    logic [22:0] pause;
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
            ack_ok <= 1'b0;
            left <= 1'b0;
            up <= 1'b0;
            down <= 1'b0;
            right <= 1'b0;
            fire_ac <= 1'b0;
            fire_bd <= 1'b0;
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
                        pause <= WAIT_50MS[22:0];
                        st <= ST_PAUSE;
                    end else begin
                        step <= step + 3'd1;
                        st <= ST_GO;
                    end
                end
                ST_PAUSE: begin
                    if (pause != 0) begin
                        pause <= pause - 23'd1;
                    end else begin
                        if (batch_ok) begin
                            ack_ok <= 1'b1;
                            /* Hysteresis: engage at 96/160, release at 112/144 so analog
                               chatter on LEFT (near the 96 edge) does not flip every poll. */
                            left  <= (vx < 8'd96) || (left && vx < 8'd112);
                            right <= (vx > 8'd160) || (right && vx > 8'd144);
                            up    <= (vy < 8'd96) || (up && vy < 8'd112);
                            down  <= (vy > 8'd160) || (down && vy > 8'd144);
                            fire_ac <= btn_held(va) | btn_held(vc) | btn_held(vok);
                            fire_bd <= btn_held(vb) | btn_held(vd);
                        end else begin
                            ack_ok <= 1'b0;
                            left <= 1'b0;
                            up <= 1'b0;
                            down <= 1'b0;
                            right <= 1'b0;
                            fire_ac <= 1'b0;
                            fire_bd <= 1'b0;
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
