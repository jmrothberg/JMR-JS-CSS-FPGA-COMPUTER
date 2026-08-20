// NOT FPGA-SIM. Stub for rtl/jmr_js_top.sv only (not in CORE_SRCS).
// FPGA-SIM joystick is jmr_js_core.joy_in. Board stick is rtl/phys/jmr_i2c_joy.
// INPUT: keyboard FIFO (BRAM/distributed) + joystick bitfield register.
// Bits: 0=UP 1=DOWN 2=LEFT 3=RIGHT 4=FIRE1 5=FIRE2
module jmr_input_engine (
    input  wire       clk,
    input  wire       rst,
    input  wire       key_we,
    input  wire [7:0] key_data,
    output wire       key_empty,
    output reg  [7:0] key_rdata,
    input  wire       key_re,
    input  wire [5:0] joy_in,
    output reg  [5:0] joy_out
);
    (* ram_style = "distributed" *) reg [7:0] fifo [0:63];
    reg [5:0] wr, rd, count;
    assign key_empty = (count == 0);
    always @(posedge clk) begin
        if (rst) begin
            wr <= 0; rd <= 0; count <= 0; joy_out <= 0; key_rdata <= 0;
        end else begin
            joy_out <= joy_in;
            if (key_we && count < 6'd63) begin
                fifo[wr] <= key_data;
                wr <= wr + 1'b1;
                count <= count + 1'b1;
            end
            if (key_re && count != 0) begin
                key_rdata <= fifo[rd];
                rd <= rd + 1'b1;
                count <= count - 1'b1;
            end
        end
    end
endmodule
