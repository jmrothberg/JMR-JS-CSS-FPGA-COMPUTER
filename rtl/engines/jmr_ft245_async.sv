// FT245 asynchronous FIFO PHY — Nexys Video PROG jack (FT2232 ch B / DPTI).
// Same byte interface as uart_simple so the GUI tether uses ONE USB cable
// (J12 PROG), matching the T100/A7 habit. Baud is ignored on the host VCP.
//
// Digilent names: prog_d=D[7:0], prog_rxen=RXF#, prog_txen=TXE#,
// prog_rdn=RD#, prog_wrn=WR#, prog_oen=OE#, prog_siwun=SIWU#.
module jmr_ft245_async (
    input  logic       clk,
    input  logic       rst_n,
    inout  wire  [7:0] d,
    input  logic       rxf_n,
    input  logic       txe_n,
    output logic       rd_n,
    output logic       wr_n,
    output logic       oe_n,
    output logic       siwu_n,
    input  logic       wr_en,
    input  logic [7:0] wr_data,
    output logic       tx_busy,
    output logic       rx_ready,
    input  logic       rx_pop,
    output logic [7:0] rx_data
);
    // 8 cycles @ 100 MHz = 80 ns — covers FT2232H async strobe minima (~50 ns)
    localparam int WAIT = 8;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_RD_OE, ST_RD_STRB, ST_RD_WAIT,
        ST_WR_DRV, ST_WR_STRB, ST_WR_WAIT
    } state_t;
    state_t state;
    logic [3:0] wait_ctr;
    logic [7:0] wr_hold, rd_hold;
    logic       pending_wr, drive_bus;
    logic       rxf_q, rxf_qq, txe_q, txe_qq;
    logic       rx_ready_r;

    assign d = drive_bus ? wr_hold : 8'hzz;
    assign rx_ready = rx_ready_r;
    assign rx_data  = rd_hold;
    assign tx_busy  = pending_wr | wr_en | (state != ST_IDLE);
    assign siwu_n   = 1'b1;   // idle-high; USB latency timer flushes small pkts

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxf_q <= 1'b1; rxf_qq <= 1'b1;
            txe_q <= 1'b1; txe_qq <= 1'b1;
        end else begin
            rxf_q <= rxf_n; rxf_qq <= rxf_q;
            txe_q <= txe_n; txe_qq <= txe_q;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            wait_ctr <= '0;
            wr_hold <= 8'h00;
            rd_hold <= 8'h00;
            pending_wr <= 1'b0;
            drive_bus <= 1'b0;
            rd_n <= 1'b1;
            wr_n <= 1'b1;
            oe_n <= 1'b1;
            rx_ready_r <= 1'b0;
        end else begin
            if (rx_pop)
                rx_ready_r <= 1'b0;
            if (wr_en) begin
                wr_hold <= wr_data;
                pending_wr <= 1'b1;
            end

            unique case (state)
                ST_IDLE: begin
                    rd_n <= 1'b1;
                    wr_n <= 1'b1;
                    oe_n <= 1'b1;
                    drive_bus <= 1'b0;
                    wait_ctr <= WAIT[3:0];
                    // RX first so typing is not starved by the screen dump
                    if (!rxf_qq && !rx_ready_r) begin
                        oe_n <= 1'b0;
                        state <= ST_RD_OE;
                    end else if (pending_wr && !txe_qq) begin
                        drive_bus <= 1'b1;
                        oe_n <= 1'b1;
                        state <= ST_WR_DRV;
                    end
                end
                ST_RD_OE: begin
                    oe_n <= 1'b0;
                    if (wait_ctr == 0) begin
                        rd_n <= 1'b0;
                        wait_ctr <= WAIT[3:0];
                        state <= ST_RD_STRB;
                    end else wait_ctr <= wait_ctr - 1'b1;
                end
                ST_RD_STRB: begin
                    rd_n <= 1'b0;
                    oe_n <= 1'b0;
                    if (wait_ctr == 0) begin
                        rd_hold <= d;
                        rx_ready_r <= 1'b1;
                        rd_n <= 1'b1;
                        wait_ctr <= WAIT[3:0];
                        state <= ST_RD_WAIT;
                    end else wait_ctr <= wait_ctr - 1'b1;
                end
                ST_RD_WAIT: begin
                    rd_n <= 1'b1;
                    oe_n <= 1'b1;
                    if (wait_ctr == 0) state <= ST_IDLE;
                    else wait_ctr <= wait_ctr - 1'b1;
                end
                ST_WR_DRV: begin
                    drive_bus <= 1'b1;
                    oe_n <= 1'b1;
                    wr_n <= 1'b1;
                    if (wait_ctr == 0) begin
                        wr_n <= 1'b0;          // falling edge clocks FTDI Tx FIFO
                        wait_ctr <= WAIT[3:0];
                        state <= ST_WR_STRB;
                    end else wait_ctr <= wait_ctr - 1'b1;
                end
                ST_WR_STRB: begin
                    drive_bus <= 1'b1;
                    wr_n <= 1'b0;
                    if (wait_ctr == 0) begin
                        wr_n <= 1'b1;
                        // Keep pending if a new wr_en landed this cycle (dump FSM
                        // waits for !tx_busy; the TB might not).
                        if (!wr_en) pending_wr <= 1'b0;
                        wait_ctr <= WAIT[3:0];
                        state <= ST_WR_WAIT;
                    end else wait_ctr <= wait_ctr - 1'b1;
                end
                ST_WR_WAIT: begin
                    wr_n <= 1'b1;
                    drive_bus <= 1'b0;
                    if (wait_ctr == 0) state <= ST_IDLE;
                    else wait_ctr <= wait_ctr - 1'b1;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
