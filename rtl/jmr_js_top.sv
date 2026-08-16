// Minimal top for FPGA-SIM / early synth smoke.
// BRAM: palette + FB model + input FIFOs. No DDR3 controller in this stub.
module jmr_js_top (
    input  wire       clk,
    input  wire       rst,
    input  wire       key_we,
    input  wire [7:0] key_data,
    input  wire [5:0] joy_in,
    output wire [5:0] joy_out,
    input  wire        fb_we,
    input  wire [18:0] fb_addr,
    input  wire [7:0]  fb_wdata,
    output wire [7:0]  fb_rdata,
    input  wire [7:0]  pal_raddr,
    output wire [23:0] pal_rdata
);
    jmr_input_engine u_input (
        .clk(clk), .rst(rst),
        .key_we(key_we), .key_data(key_data),
        .key_empty(), .key_rdata(), .key_re(1'b0),
        .joy_in(joy_in), .joy_out(joy_out)
    );
    jmr_fb_mem u_fb (
        .clk(clk), .we(fb_we), .addr(fb_addr),
        .wdata(fb_wdata), .rdata(fb_rdata)
    );
    jmr_palette_bram u_pal (
        .wr_clk(clk), .rd_clk(clk), .we(1'b0), .waddr(8'h00), .wdata(24'h0),
        .raddr(pal_raddr), .rdata(pal_rdata)
    );
endmodule
