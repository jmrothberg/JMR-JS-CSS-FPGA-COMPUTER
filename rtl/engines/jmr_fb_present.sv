// Persistent BRAM canvas -> DDR3 front. Pipeline the registered byte reads
// and pack them into a four-word elastic FIFO. Reads continue while the
// SRAM write is pending; accepted writes can hand off the next word without
// a request bubble. No framebuffer copy or new BRAM is introduced.
module jmr_fb_present #(
    parameter logic [20:0] FB_SRAM_BASE = 21'd1480704
) (
    input logic clk, rst_n,
    input logic swap, clear_go,
    output logic busy,
    output logic [18:0] copy_raddr,
    input logic [7:0] copy_rdata,
    output logic sram_req, sram_we,
    output logic [20:0] sram_addr,
    output logic [15:0] sram_wdata,
    input logic sram_ack
);
    localparam int PIXELS = 307200;
    localparam int WORDS = PIXELS / 2;
    logic swap_pend, clr_mode;
    logic [18:0] fetch_px;
    logic rd_valid, rd_hi;
    logic [7:0] low_byte;
    logic [15:0] fifo [0:3];
    logic [1:0] wp, rp;
    logic [2:0] count;
    logic [17:0] send_word, ack_word;
    logic issue_read, enq, deq, last_ack;
    assign copy_raddr = fetch_px;
    assign sram_we = sram_req;
    // Reserve a full word for the registered read and a possible low byte.
    // At most one more word can arrive after backpressure stops new reads.
    assign issue_read = busy && fetch_px < PIXELS && count < 3;
    assign enq = busy && rd_valid && rd_hi;
    assign last_ack = sram_req && sram_ack && ack_word == WORDS-1;
    assign deq = busy && !last_ack && (!sram_req || sram_ack) && count != 0;
    // One write statement, including this tiny FIFO: keep legal RAM shape.
    always_ff @(posedge clk)
        if (enq) fifo[wp] <= clr_mode ? 16'd0 : {copy_rdata, low_byte};

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
            rd_hi <= 1'b0;
            low_byte <= 8'd0;
            wp <= 2'd0; rp <= 2'd0; count <= 3'd0;
            send_word <= 18'd0; ack_word <= 18'd0;
        end else begin
            if (swap && busy) swap_pend <= 1'b1;
            if (!busy) begin
                sram_req <= 1'b0;
                rd_valid <= 1'b0;
                if (clear_go || swap || swap_pend) begin
                    busy <= 1'b1;
                    clr_mode <= clear_go;
                    if (!clear_go) swap_pend <= 1'b0;
                    fetch_px <= 19'd0;
                    wp <= 2'd0; rp <= 2'd0; count <= 3'd0;
                    send_word <= 18'd0; ack_word <= 18'd0;
                end
            end else begin
                // The framebuffer samples copy_raddr on this edge; consume
                // that registered result on the next edge, qualified by valid.
                rd_valid <= issue_read;
                if (issue_read) begin
                    rd_hi <= fetch_px[0];
                    fetch_px <= fetch_px + 19'd1;
                end
                if (rd_valid && !rd_hi) low_byte <= copy_rdata;
                if (enq) wp <= wp + 2'd1;
                if (deq) rp <= rp + 2'd1;
                case ({enq, deq})
                    2'b10: count <= count + 3'd1;
                    2'b01: count <= count - 3'd1;
                    default: ;
                endcase
                if (sram_req && sram_ack) begin
                    ack_word <= ack_word + 18'd1;
                    sram_req <= 1'b0;
                    if (last_ack) busy <= 1'b0;
                end
                if (deq) begin
                    sram_req <= 1'b1;
                    sram_addr <= FB_SRAM_BASE + 21'(send_word);
                    sram_wdata <= fifo[rp];
                    send_word <= send_word + 18'd1;
                end
            end
        end
    end
`ifndef SYNTHESIS
    always_ff @(posedge clk) if (rst_n && busy) begin
        if (enq && count == 4 && !deq) $error("present FIFO overflow");
        if (sram_req && !sram_we) $error("present request must be a write");
    end
`endif
endmodule
