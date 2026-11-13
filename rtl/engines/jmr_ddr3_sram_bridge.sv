// MIG native UI → jmr_sram_port (32M × 16, the first 64 MB of DDR3).
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
    input  logic [24:0]  addr,
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
        S_WAIT_RD = 2'd2,
        S_WFLUSH  = 2'd3
    } st_t;

    st_t state;
    logic        wr_pend;
    logic [2:0]  slot;
    logic [15:0] wdata_q;
    logic        cmd_sent, wdf_sent;
    // Board fix: read-reissue watchdog. If a command is ever
    // lost, S_WAIT_RD re-issues instead of wedging the whole SRAM fabric
    // (the arbiter holds the owner until ack, so a silent drop blacked
    // the screen and froze every sram client).
    logic [15:0] rd_wd;
    // Single-entry BL8 read cache. The MIG UI costs ~25 ui cycles per
    // read; scanout needs 320 sequential words per 32 us line (one per
    // 100 ns), which a word-per-transaction bridge cannot sustain (the
    // 1-cycle sim model hid this). One burst serves 8 sequential words:
    // 40 bursts/line = well inside the line budget. Writes to the cached
    // burst invalidate it.
    logic         cache_valid;
    logic [21:0]  cache_base;   // addr[24:3]
    logic [127:0] cache_data;
    // Single-entry BL8 WRITE-COMBINE
    // buffer, the write-side twin of the read cache above. The present
    // engine streams 153,600 perfectly sequential words; per-word UI
    // transactions made that the dominant frame cost (768k core clk of
    // S_FB_SYNC wait, measured). Sequential writes into one BL8 block
    // merge here and ack SAME-CYCLE; the block flushes as ONE masked
    // burst on: a write to a different block, or a read touching the
    // buffered block. Demand-flush is complete — every reader goes
    // through this port, so no timeout is needed and none is a wait.
    logic         wc_valid;
    logic [21:0]  wc_base;      // addr[24:3]
    logic [127:0] wc_data;
    logic [15:0]  wc_ben;       // bytes WRITTEN (flush mask = ~wc_ben)
    // Build 96 timing: the request arrives through the core arbiter's grant
    // and address mux, so the block compares (addr vs wc_base/cache_base)
    // sit at the end of a deep cone. Only single-bit decisions (ack, state,
    // wq_valid, cache_valid) wait for the compares. Wide registers load from
    // flops or from the request without the compare in their enables:
    //   - a combined write is acknowledged as before but merged into
    //     wc_data/wc_ben one clock later from wq_* (a flush reads them at
    //     the earliest one clock after that);
    //   - rdata loads the cached word on every IDLE read request; it is
    //     only consumed with ack, and a miss overwrites it before its ack;
    //   - slot/wdata_q/wr_pend/app_addr/app_cmd load on every IDLE beat
    //     and are used only in S_ISSUE/S_WAIT_RD entered from that beat.
    // Ack timing, ordering and every MIG handshake are unchanged.
    logic         wq_valid, wq_first;
    logic [2:0]   wq_slot;
    logic [15:0]  wq_data;

    wire [2:0]  slot_now = addr[2:0];
    // app_addr is in DDR3-device-word (16-bit) units; BL8 bursts are
    // 8-word aligned. The old {addr,1'b0} byte-address mapping split one
    // aligned 8-word sram block across TWO bursts (it only round-tripped
    // because reads and writes shared the same scrambled transform) - the
    // burst cache below requires block == burst, so use the natural
    // mapping. DDR content is volatile; nothing persists across the change.
    wire [28:0] ui_addr  = {4'd0, addr[24:3], 3'b000};
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
            rd_wd     <= 16'd0;
            cache_valid <= 1'b0;
            cache_base  <= 18'd0;
            cache_data  <= 128'd0;
            wc_valid <= 1'b0;
            wc_base  <= 18'd0;
            wc_data  <= 128'd0;
            wc_ben   <= 16'd0;
            wq_valid <= 1'b0;
            wq_first <= 1'b0;
            wq_slot  <= 3'd0;
            wq_data  <= 16'd0;
        end else begin
            wq_valid <= 1'b0;
            wq_slot  <= addr[2:0];
            wq_data  <= wdata;
            wq_first <= !wc_valid;
            if (wq_valid) begin
                wc_data[{wq_slot, 4'b0000} +: 16] <= wq_data;
                if (wq_first) wc_ben <= 16'b11 << {wq_slot, 1'b0};
                else          wc_ben[{wq_slot, 1'b0} +: 2] <= 2'b11;
            end
            ack <= 1'b0;
            app_en <= 1'b0;
            app_wdf_wren <= 1'b0;
            app_wdf_end  <= 1'b0;
            unique case (state)
                S_IDLE: begin
                    cmd_sent <= 1'b0;
                    wdf_sent <= 1'b0;
                    // Compare-free loads (see wq_* above).
                    wr_pend  <= we;
                    slot     <= slot_now;
                    wdata_q  <= wdata;
                    app_addr <= ui_addr;
                    app_cmd  <= we ? CMD_WRITE : CMD_READ;
                    if (req && !ack && !we)
                        rdata <= cache_data[{addr[2:0], 4'b0000} +: 16];
`ifndef JMR_NOBURST
                    if (req && !ack && we && !wc_valid) begin
                        wc_valid <= 1'b1;
                        wc_base  <= addr[24:3];
                    end
`endif
                    if (req && !ack) begin
`ifndef JMR_NOBURST
                        if (we && (!wc_valid || addr[24:3] == wc_base)) begin
                            // write-combine: ack now, merge next clock (wq_*)
                            wq_valid <= 1'b1;
                            if (addr[24:3] == cache_base) cache_valid <= 1'b0;
                            ack <= 1'b1;
                        end else if (we) begin
                            // different block: flush the buffer first;
                            // the held req is served on return to IDLE
                            state <= S_WFLUSH;
                        end else if (wc_valid && addr[24:3] == wc_base) begin
                            // read touching the buffered block: flush first
                            state <= S_WFLUSH;
                        end else
`endif
`ifdef JMR_NOCACHE
                        if (1'b0) begin // read cache disabled (PACMAN-freeze A/B build)
`else
                        if (!we && cache_valid && addr[24:3] == cache_base) begin
`endif
                            ack   <= 1'b1;   // rdata loaded above
                        end else begin
                            state    <= S_ISSUE;
                        end
                    end
                end
                S_WFLUSH: begin
                    // one masked BL8 burst carrying the whole combined block
                    // (UG586 hold-until-accept discipline, data first)
                    logic fcmd_ok, fwdf_ok;
                    app_addr <= {4'd0, wc_base, 3'b000};
                    app_cmd  <= CMD_WRITE;
                    app_wdf_data <= wc_data;
                    app_wdf_mask <= ~wc_ben;
                    fcmd_ok = cmd_sent || (app_en && app_rdy);
                    fwdf_ok = wdf_sent || (app_wdf_wren && app_wdf_rdy);
                    app_wdf_wren <= !fwdf_ok;
                    app_wdf_end  <= !fwdf_ok;
                    wdf_sent     <= fwdf_ok;
                    app_en       <= fwdf_ok && !fcmd_ok;
                    cmd_sent     <= fcmd_ok;
                    if (fcmd_ok) begin
                        app_en       <= 1'b0;
                        app_wdf_wren <= 1'b0;
                        app_wdf_end  <= 1'b0;
                        wc_valid <= 1'b0;
                        cmd_sent <= 1'b0;
                        wdf_sent <= 1'b0;
                        state    <= S_IDLE;  // held req re-evaluated there
                    end
                end
                S_ISSUE: begin
                    // UG586 handshake: app_en / app_wdf_wren are accepted only
                    // when they OVERLAP app_rdy / app_wdf_rdy in the same
                    // cycle. The old code sampled rdy one cycle, pulsed the
                    // enable the next - any rdy dip between (each refresh
                    // window, ~7.8 us) silently dropped the command while the
                    // FSM marked it sent. A dropped read parked S_WAIT_RD
                    // forever: black FB, every sram client frozen. Hold each
                    // enable until its own accept; write data goes first
                    // (data may precede the command, must not trail it).
                    logic cmd_ok, wdf_ok;
                    app_addr <= ui_addr;
                    app_cmd  <= wr_pend ? CMD_WRITE : CMD_READ;
                    app_wdf_data <= wdf_now;
                    app_wdf_mask <= mask_now;
                    cmd_ok = cmd_sent || (app_en && app_rdy);
                    wdf_ok = wdf_sent || (app_wdf_wren && app_wdf_rdy);
                    if (!wr_pend) begin
                        app_en <= !cmd_ok;
                        if (cmd_ok) begin
                            app_en <= 1'b0;
                            rd_wd  <= 16'd0;
                            state  <= S_WAIT_RD;
                        end
                    end else begin
                        app_wdf_wren <= !wdf_ok;
                        app_wdf_end  <= !wdf_ok;
                        wdf_sent     <= wdf_ok;
                        app_en       <= wdf_ok && !cmd_ok;
                        cmd_sent     <= cmd_ok;
                        if (cmd_ok) begin
                            app_en       <= 1'b0;
                            app_wdf_wren <= 1'b0;
                            app_wdf_end  <= 1'b0;
                            if (addr[24:3] == cache_base) cache_valid <= 1'b0;
                            ack   <= 1'b1;
                            state <= S_IDLE;
                        end
                    end
                end
                S_WAIT_RD: begin
                    if (app_rd_data_valid) begin
                        rdata <= app_rd_data[bit_off +: 16];
                        cache_data  <= app_rd_data;
                        cache_base  <= addr[24:3];
                        cache_valid <= 1'b1;
                        ack   <= 1'b1;
                        state <= S_IDLE;
                    end else if (rd_wd == 16'hFFFF) begin
                        // command lost anyway (should be impossible now):
                        // re-issue rather than wedge
                        rd_wd    <= 16'd0;
                        cmd_sent <= 1'b0;
                        wdf_sent <= 1'b0;
                        state    <= S_ISSUE;
                    end else rd_wd <= rd_wd + 16'd1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
