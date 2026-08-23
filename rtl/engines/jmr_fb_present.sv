// Present engine: on a swap pulse, stream the persistent BRAM draw bank
// into the DDR3 front image (FB_SRAM_BASE, 2 px per 16-bit word).
//
// Session-1 (2026-08-23): replaces both the front-bit flip AND the VM's
// S_FB_SYNC copy-back (canvas persistence now comes free — the draw bank
// never flips). Serves the VM and the console demo alike: either pulses
// `swap`; `busy` holds the VM's present state (and any further swap) until
// the copy lands. ~154k words at held-until-ack pace = a few ms per
// present — inside the accepted half-frame-rate budget.
module jmr_fb_present #(
    parameter logic [20:0] FB_SRAM_BASE = 21'd1480704
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        swap,
    output logic        busy,
    // draw-bank copy read port (1-beat registered read)
    output logic [18:0] copy_raddr,
    input  logic [7:0]  copy_rdata,
    // sram write channel
    output logic        sram_req,
    output logic        sram_we,
    output logic [20:0] sram_addr,
    output logic [15:0] sram_wdata,
    input  logic        sram_ack
);
    localparam int WORDS = 153600; // 640*480/2

    typedef enum logic [2:0] { P_IDLE, P_A0, P_A1, P_L0, P_L1, P_WR } pst_t;
    pst_t pst;
    logic [17:0] w;      // word index
    logic [7:0]  px0;
    logic        swap_pend; // explicit swapBuffers can land mid-present

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pst <= P_IDLE;
            busy <= 1'b0;
            sram_req <= 1'b0;
            sram_we <= 1'b0;
            w <= '0;
            copy_raddr <= '0;
            swap_pend <= 1'b0;
        end else begin
            if (swap && busy) swap_pend <= 1'b1;
            unique case (pst)
                P_IDLE: if (swap || swap_pend) begin
                    swap_pend <= 1'b0;
                    busy <= 1'b1;
                    w <= '0;
                    copy_raddr <= 19'd0;
                    pst <= P_A0;
                end
                P_A0: begin // px0 address presented; move to px1
                    copy_raddr <= {w, 1'b1};
                    pst <= P_L0;
                end
                P_L0: begin // copy_rdata = px0 (1-beat lag)
                    px0 <= copy_rdata;
                    pst <= P_L1;
                end
                P_L1: begin // copy_rdata = px1: issue the word write
                    sram_req <= 1'b1;
                    sram_we <= 1'b1;
                    sram_addr <= FB_SRAM_BASE + 21'(w);
                    sram_wdata <= {copy_rdata, px0};
                    pst <= P_WR;
                end
                P_WR: if (sram_ack) begin
                    sram_req <= 1'b0;
                    sram_we <= 1'b0;
                    if (w == 18'(WORDS - 1)) begin
                        busy <= 1'b0;
                        pst <= P_IDLE;
                    end else begin
                        w <= w + 18'd1;
                        copy_raddr <= {w + 18'd1, 1'b0};
                        pst <= P_A0;
                    end
                end
                default: pst <= P_IDLE;
            endcase
        end
    end
endmodule
