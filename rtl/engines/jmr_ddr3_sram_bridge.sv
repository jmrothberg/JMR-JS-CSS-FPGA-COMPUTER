// MIG native UI → jmr_sram_port (2M × 16, first 4 MB of DDR3).
// FPGA-SIM keeps jmr_sram_model; this module is board-only (not in Verilator).
// Native UI is 128-bit (16-bit DDR3, 4:1). One SRAM word is two bytes in a
// burst; writes use the byte mask so we do not RMW.
module jmr_ddr3_sram_bridge (
    input  logic         clk,       // MIG ui_clk
    input  logic         rst_n,     // ~ui_clk_sync_rst & calib
    input  logic         calib_done,
    // jmr_sram_port slave
    input  logic         req,
    input  logic         we,
    input  logic [20:0]  addr,
    input  logic [15:0]  wdata,
    output logic [15:0]  rdata,
    output logic         ack,
    // MIG 7-series native UI
    output logic [28:0]  app_addr,
    output logic [2:0]   app_cmd,
    output logic         app_en,
    output logic [127:0] app_wdf_data,
    output logic         app_wdf_end,
    output logic [15:0]  app_wdf_mask,
    output logic         app_wdf_wren,
    input  logic [127:0] app_rd_data,
    input  logic         app_rd_data_valid,
    input  logic         app_rdy,
    input  logic         app_wdf_rdy
);
    localparam logic [2:0] CMD_WRITE = 3'd0;
    localparam logic [2:0] CMD_READ  = 3'd1;

    typedef enum logic [1:0] {
        S_IDLE    = 2'd0,
        S_ISSUE   = 2'd1,
        S_WAIT_RD = 2'd2
    } st_t;

    st_t state;
    logic        wr_pend;
    logic [2:0]  slot;
    logic [15:0] wdata_q;
    logic        cmd_sent, wdf_sent;

    wire [2:0]  slot_now = addr[2:0];
    wire [28:0] ui_addr  = {7'd0, addr, 1'b0}; // byte addr; MIG ignores [3:0]
    wire [6:0]  bit_off  = {slot, 4'b0000};
    wire [4:0]  byte_lo  = {slot, 1'b0};

    logic [15:0] mask_now;
    logic [127:0] wdf_now;
    integer bi;
    always_comb begin
        mask_now = 16'hFFFF;
        mask_now[byte_lo]     = 1'b0;
        mask_now[byte_lo+5'd1] = 1'b0;
        wdf_now = 128'd0;
        for (bi = 0; bi < 8; bi = bi + 1)
            if (bi[2:0] == slot)
                wdf_now[bi*16 +: 16] = wdata_q;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || !calib_done) begin
            state     <= S_IDLE;
            ack       <= 1'b0;
            rdata     <= 16'd0;
            app_en    <= 1'b0;
            app_wdf_wren <= 1'b0;
            app_wdf_end  <= 1'b0;
            app_cmd   <= CMD_READ;
            app_addr  <= 28'd0;
            app_wdf_data <= 128'd0;
            app_wdf_mask <= 16'hFFFF;
            wr_pend   <= 1'b0;
            slot      <= 3'd0;
            wdata_q   <= 16'd0;
            cmd_sent  <= 1'b0;
            wdf_sent  <= 1'b0;
        end else begin
            ack <= 1'b0;
            app_en <= 1'b0;
            app_wdf_wren <= 1'b0;
            app_wdf_end  <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    cmd_sent <= 1'b0;
                    wdf_sent <= 1'b0;
                    if (req && !ack) begin
                        wr_pend <= we;
                        slot    <= slot_now;
                        wdata_q <= wdata;
                        app_addr <= ui_addr;
                        app_cmd  <= we ? CMD_WRITE : CMD_READ;
                        state    <= S_ISSUE;
                    end
                end
                S_ISSUE: begin
                    app_addr <= ui_addr;
                    app_cmd  <= wr_pend ? CMD_WRITE : CMD_READ;
                    app_wdf_data <= wdf_now;
                    app_wdf_mask <= mask_now;
                    if (!wr_pend) begin
                        if (app_rdy) begin
                            app_en <= 1'b1;
                            state  <= S_WAIT_RD;
                        end
                    end else begin
                        if (!cmd_sent && app_rdy) begin
                            app_en   <= 1'b1;
                            cmd_sent <= 1'b1;
                        end
                        if (!wdf_sent && app_wdf_rdy) begin
                            app_wdf_wren <= 1'b1;
                            app_wdf_end  <= 1'b1;
                            wdf_sent     <= 1'b1;
                        end
                        // Command + write-data both accepted (same cycle or split)
                        if ((cmd_sent || app_rdy) && (wdf_sent || app_wdf_rdy)) begin
                            ack   <= 1'b1;
                            state <= S_IDLE;
                        end
                    end
                end
                S_WAIT_RD: begin
                    if (app_rd_data_valid) begin
                        rdata <= app_rd_data[bit_off +: 16];
                        ack   <= 1'b1;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
