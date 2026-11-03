// Persistent BRAM canvas -> DDR3 front. Pipeline the registered byte reads
// and pack them into a eight-word elastic FIFO. Reads continue while the
// SRAM write is pending; accepted writes can hand off the next word without
// a request bubble. No framebuffer copy or new BRAM is introduced.
module jmr_fb_present #(
    parameter logic [21:0] FB_SRAM_BASE = 22'd3577856,
    parameter bit DIRTY_COPY = 1
) (
    input logic clk, rst_n,
    input logic swap, clear_go,
    input logic [1199:0] dirty_blocks,
    output logic dirty_clear,
    output logic busy,
    output logic [18:0] copy_raddr,
    input logic [7:0] copy_rdata,
    output logic sram_req, sram_we,
    output logic [21:0] sram_addr,
    output logic [15:0] sram_wdata,
    input logic sram_ack
);
    localparam int PIXELS = 307200;
    localparam int WORDS = PIXELS / 2;
    logic swap_pend, clr_mode;
    logic [18:0] fetch_px;
    logic rd_valid, rd_hi;
    logic pixel_valid, pixel_hi;
    logic [17:0] pixel_word;
    logic [7:0] pixel_data;
    logic [7:0] low_byte;
    logic [15:0] fifo [0:7];
    logic [17:0] fifo_addr [0:7];
    logic [17:0] rd_word;
    logic [1199:0] dirty_snapshot;
    logic [31:0] dirty_group;
    logic [5:0] dirty_group_tag;
    logic dirty_group_valid, dirty_group_ready;
    // One flag capture per 256-byte block removes lookup from the
    // address-increment feedback path.
    logic block_dirty, block_dirty_valid;
    wire [1215:0] dirty_padded = {16'd0, dirty_snapshot};
    logic [2:0] start_wait;
    logic force_full;
    logic [2:0] wp, rp;
    logic [3:0] count;
    logic [17:0] send_word, ack_word;
    logic issue_read, enq, deq, skip_block, finished;
    assign copy_raddr = fetch_px;
    assign sram_we = sram_req;
    // Reserve two FIFO words for both registered read stages and a
    // possible low byte after backpressure stops new reads.
    // Cache 32 change flags at a time. A group spans 8192 pixels, so
    // only 38 group loads are needed per full canvas. The fast feedback
    // path selects from 32 registered bits instead of all 1200 flags.
    assign dirty_group_ready = dirty_group_valid && dirty_group_tag == fetch_px[18:13];
    assign skip_block = DIRTY_COPY && !clr_mode && fetch_px < PIXELS &&
        block_dirty_valid && fetch_px[7:0] == 0 && !block_dirty;
    assign issue_read = busy && start_wait == 0 && fetch_px < PIXELS &&
        count < 6 && (!DIRTY_COPY || clr_mode || block_dirty_valid) && !skip_block;
    assign enq = busy && pixel_valid && pixel_hi;
    assign finished = busy && start_wait == 0 && fetch_px >= PIXELS &&
        !rd_valid && !pixel_valid && count == 0 && (!sram_req || sram_ack);
    assign deq = busy && (!sram_req || sram_ack) && count != 0;
    // Wait four clocks at launch so the final draw's registered read-first
    // comparison reaches the mask before we snapshot and clear it.
    assign dirty_clear = busy && start_wait == 1 && !clr_mode;
    // One write statement, including this tiny FIFO: keep legal RAM shape.
    always_ff @(posedge clk)
        if (enq) begin
            fifo[wp] <= clr_mode ? 16'd0 : {pixel_data, low_byte};
            fifo_addr[wp] <= pixel_word;
        end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            swap_pend <= 1'b0;
            clr_mode <= 1'b0;
            sram_req <= 1'b0;
            sram_addr <= FB_SRAM_BASE;
            sram_wdata <= 16'd0;
            fetch_px <= 19'd0;
            rd_valid <= 1'b0;
            pixel_valid <= 1'b0;
            rd_hi <= 1'b0;
            low_byte <= 8'd0;
            wp <= 3'd0; rp <= 3'd0; count <= 4'd0;
            send_word <= 18'd0; ack_word <= 18'd0;
            start_wait <= 3'd0;
            force_full <= 1'b1;
            dirty_group_valid <= 1'b0;
            block_dirty_valid <= 1'b0;
        end else begin
            if (swap && busy) swap_pend <= 1'b1;
            if (!busy) begin
                sram_req <= 1'b0;
                rd_valid <= 1'b0;
            pixel_valid <= 1'b0;
                if (clear_go || swap || swap_pend) begin
                    busy <= 1'b1;
                    clr_mode <= clear_go;
                    if (clear_go) force_full <= 1'b1;
                    if (!clear_go) swap_pend <= 1'b0;
                    fetch_px <= 19'd0;
                    wp <= 3'd0; rp <= 3'd0; count <= 4'd0;
                    send_word <= 18'd0; ack_word <= 18'd0;
                    start_wait <= 3'd4;
                    dirty_group_valid <= 1'b0;
                    block_dirty_valid <= 1'b0;
                end
            end else begin
                // The framebuffer samples copy_raddr on this edge; consume
                // that registered result on the next edge, qualified by valid.
                if (start_wait != 0) begin
                    start_wait <= start_wait - 3'd1;
                    if (start_wait == 1) begin
                        dirty_snapshot <= force_full ? '1 : dirty_blocks;
                        if (!clr_mode) force_full <= 1'b0;
                    end
                end
                rd_valid <= issue_read;
                pixel_data <= copy_rdata;
                pixel_valid <= rd_valid;
                pixel_hi <= rd_hi;
                pixel_word <= rd_word;
                if (DIRTY_COPY && !clr_mode && start_wait == 0 &&
                    fetch_px < PIXELS && dirty_group_ready && !block_dirty_valid) begin
                    block_dirty <= dirty_group[fetch_px[12:8]];
                    block_dirty_valid <= 1'b1;
                end
                if (skip_block || (issue_read && fetch_px[7:0] == 8'hff))
                    block_dirty_valid <= 1'b0;
                if (DIRTY_COPY && !clr_mode && start_wait == 0 &&
                    fetch_px < PIXELS && !dirty_group_ready) begin
                    dirty_group <= dirty_padded[{fetch_px[18:13], 5'd0} +: 32];
                    dirty_group_tag <= fetch_px[18:13];
                    dirty_group_valid <= 1'b1;
                end
                if (start_wait == 0 && skip_block) fetch_px <= fetch_px + 19'd256;
                if (issue_read) begin
                    rd_hi <= fetch_px[0];
                    rd_word <= fetch_px[18:1];
                    fetch_px <= fetch_px + 19'd1;
                end
                if (pixel_valid && !pixel_hi) low_byte <= pixel_data;
                if (enq) wp <= wp + 3'd1;
                if (deq) rp <= rp + 3'd1;
                case ({enq, deq})
                    2'b10: count <= count + 4'd1;
                    2'b01: count <= count - 4'd1;
                    default: ;
                endcase
                if (sram_req && sram_ack) begin
                    ack_word <= ack_word + 18'd1;
                    sram_req <= 1'b0;
                end
                if (finished) busy <= 1'b0;
                if (deq) begin
                    sram_req <= 1'b1;
                    sram_addr <= FB_SRAM_BASE + 21'(fifo_addr[rp]);
                    sram_wdata <= fifo[rp];
                    send_word <= send_word + 18'd1;
                end
            end
        end
    end
`ifndef SYNTHESIS
    always_ff @(posedge clk) if (rst_n && busy) begin
        if (enq && count == 8 && !deq) $error("present FIFO overflow");
        if (sram_req && !sram_we) $error("present request must be a write");
    end
`endif
endmodule
