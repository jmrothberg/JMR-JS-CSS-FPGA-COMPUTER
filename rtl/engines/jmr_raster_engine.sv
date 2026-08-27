// Full-rate raster/blit/ImageData engine — run-50 C1.
//
// The framebuffer write port and the asset SRAM already run at the core
// clock; only the VM's /VM_CLK_DIV beat rate limited every paint loop to
// one pixel per beat (8 core clocks at div8), and the blit/ImageData
// walks additionally paid one arbiter round trip per PIXEL. This engine
// runs the three per-pixel walks at core rate on the VM's behalf:
//
//   FILL : dest walk, constant colour, no fetch        (was 8  clk/px)
//   BLIT : DDA source walk, SRAM fetch, colorkey 0     (was >=16 clk/px)
//   IMGD : linear source walk from IMGD_SRAM_BASE      (was >=16 clk/px)
//
// Contract with the VM (same shape as jmr_fb_present, proven on glass):
// the VM latches the op's scalars, pulses `go` for one VM beat, then
// blocks until `busy` falls. `go` is edge-detected here in the fast
// domain (the vm_fb_swap pattern); `busy` back to the VM is a level.
// The engine owns NO arrays (RTL_DESIGN_PRINCIPLES 3.2) beyond a
// one-WORD blit source cache, which is invalidated at every `go` so a
// stale word across sprite re-uploads is impossible by construction —
// a cache hit can only be served within a single blit walk.
//
// Exact-semantics notes (gated by tests/test_engine_gates.py +
// test_blit_scale_exact.py, green on the pre-engine tree):
//  - BLIT reproduces the VM's DDA floor semantics: per-pixel source =
//    base + (blit_sy+dda_sy)*stride + (blit_sx+dda_sx), dda advancing
//    by q with remainder accumulation against rw/rh. The per-pixel
//    multiply is gone: row_base advances by stride*qy (+stride on the
//    remainder carry) — stride*qy and the row-0 base are two 16-bit
//    DSP products latched once at `go`.
//  - BLIT skips pix==0 (transparent) and out-of-bounds dest pixels;
//    ASET packs 2 px per 16-bit word (so[0] selects the byte lane),
//    legacy .JS sprites are one byte per word at SPR_SRAM_BASE+so.
//  - IMGD writes EVERY pixel (0 included), bounds-checked, linear
//    source index capped at FB_PIXELS.
//  - FILL writes every in-bounds pixel including colour 0.
module jmr_raster_engine #(
    parameter int MW = 640,
    parameter int MH = 480,
    parameter logic [20:0] SPR_SRAM_BASE  = 21'd1691648,
    parameter logic [20:0] IMGD_SRAM_BASE = 21'd1789952
) (
    input  logic        clk,
    input  logic        rst_n,
    // VM handshake (go is a VM-beat-wide pulse; edge-detected here)
    input  logic        go,
    input  logic [1:0]  mode,      // 0 FILL, 1 BLIT, 2 IMGD
    input  logic [9:0]  dx, dy, w, h,
    input  logic [7:0]  color,
    input  logic [15:0] sx, sy,          // blit_sx / blit_sy
    input  logic [15:0] qx, rxr, qy, ryr, // DDA quotient/remainder pairs
    input  logic [21:0] sbase,     // spr_off[si] (blit) / imgd_i (imgd)
    input  logic [15:0] stride,    // spr_ww[si]
    input  logic        aset,
    output logic        busy,
    // framebuffer write port (100 MHz side of jmr_mini_fb)
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [7:0]  fb_wdata,
    // asset SRAM read client (hold-req-until-ack, arbiter owner 6)
    output logic        sram_req,
    output logic [20:0] sram_addr,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack
);
    localparam int FB_PIXELS = MW * MH;

    typedef enum logic [1:0] { M_FILL = 2'd0, M_BLIT = 2'd1, M_IMGD = 2'd2 } mode_t;

    logic        go_q, go_edge;
    always_ff @(posedge clk) go_q <= go;
    assign go_edge = go && !go_q;

    // latched op
    logic [1:0]  m_q;
    logic [9:0]  dx_q, dy_q, w_q, h_q;
    logic [7:0]  color_q;
    logic [15:0] qx_q, rxr_q, qy_q, ryr_q, stride_q;
    logic        aset_q;
    // walk state
    logic [9:0]  x, y;
    logic [15:0] ax, ay;          // DDA remainder accumulators
    logic [21:0] so, row_so;      // blit source offsets (byte index)
    logic [21:0] row_step;        // stride*qy, latched at go
    logic [18:0] imgd_i;          // linear imgd source index
    logic        fetch_wait;
    // one-word source cache (blit): tag is the WORD address
    logic        cw_valid;
    logic [20:0] cw_tag;
    logic [15:0] cw_word;

    // per-pixel source word address + byte lane
    logic [20:0] px_word;
    logic        px_hi;
    always_comb begin
        if (m_q == M_IMGD) begin
            px_word = IMGD_SRAM_BASE + 21'(imgd_i);
            px_hi   = 1'b0;
        end else if (aset_q) begin
            px_word = 21'(so[21:1]);
            px_hi   = so[0];
        end else begin
            px_word = SPR_SRAM_BASE + 21'(so[17:0]);
            px_hi   = 1'b0;
        end
    end

    logic [9:0] pxx, pxy;
    assign pxx = dx_q + x;
    assign pxy = dy_q + y;
    logic inb;
    assign inb = (pxx < 10'(MW)) && (pxy < 10'(MH));

    // advance to the next dest pixel; returns via updated x/y/so/row_so/
    // ax/ay/imgd_i registers. Shared by all three modes.
    logic last_px;
    assign last_px = (x == w_q - 10'd1) && (y == h_q - 10'd1);

    task automatic adv();
        if (x == w_q - 10'd1) begin
            x  <= 10'd0;
            ax <= 16'd0;
            y  <= y + 10'd1;
            // row DDA: row_so += stride*qy (+stride on carry)
            if (16'(ay + ryr_q) >= {6'd0, h_q}) begin
                row_so <= row_so + row_step + 22'(stride_q);
                so     <= row_so + row_step + 22'(stride_q);
                ay     <= 16'(ay + ryr_q) - {6'd0, h_q};
            end else begin
                row_so <= row_so + row_step;
                so     <= row_so + row_step;
                ay     <= ay + ryr_q;
            end
        end else begin
            x <= x + 10'd1;
            if (16'(ax + rxr_q) >= {6'd0, w_q}) begin
                so <= so + 22'(qx_q) + 22'd1;
                ax <= 16'(ax + rxr_q) - {6'd0, w_q};
            end else begin
                so <= so + 22'(qx_q);
                ax <= ax + rxr_q;
            end
        end
        imgd_i <= imgd_i + 19'd1;
    endtask

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            fb_we <= 1'b0;
            sram_req <= 1'b0;
            fetch_wait <= 1'b0;
            cw_valid <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            if (!busy) begin
                if (go_edge) begin
                    m_q <= mode;
                    dx_q <= dx; dy_q <= dy; w_q <= w; h_q <= h;
                    color_q <= color;
                    qx_q <= qx; rxr_q <= rxr; qy_q <= qy; ryr_q <= ryr;
                    stride_q <= stride;
                    aset_q <= aset;
                    x <= 10'd0; y <= 10'd0;
                    ax <= 16'd0; ay <= 16'd0;
                    // row-0 source base: two 16-bit DSP products, once per op
                    so     <= sbase + 22'(sy) * 22'(stride) + 22'(sx);
                    row_so <= sbase + 22'(sy) * 22'(stride) + 22'(sx);
                    row_step <= 22'(qy) * 22'(stride);
                    imgd_i <= 19'(sbase[18:0]);
                    fetch_wait <= 1'b0;
                    cw_valid <= 1'b0;   // never serve across ops (re-uploads)
                    // busy always rises, even for a degenerate op, so the
                    // VM's rise-then-fall wait can never hang; the first
                    // walk beat retires a zero-size op immediately.
                    busy <= 1'b1;
                end
            end else if (w_q == 10'd0 || h_q == 10'd0) begin
                busy <= 1'b0;
            end else begin
                unique case (m_q)
                    M_FILL: begin
                        // 1 px/clk, unconditional colour
                        if (inb) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(pxy) * 19'(MW) + 19'(pxx);
                            fb_wdata <= color_q;
                        end
                        if (last_px) busy <= 1'b0;
                        else adv();
                    end
                    M_BLIT: begin
                        if (cw_valid && cw_tag == px_word) begin
                            // cache hit: serve, write, advance — 1 clk/px
                            logic [7:0] pix;
                            pix = px_hi ? cw_word[15:8] : cw_word[7:0];
                            if (pix != 8'd0 && inb) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(pxy) * 19'(MW) + 19'(pxx);
                                fb_wdata <= pix;
                            end
                            if (last_px) busy <= 1'b0;
                            else adv();
                        end else if (!fetch_wait) begin
                            sram_req <= 1'b1;
                            sram_addr <= px_word;
                            fetch_wait <= 1'b1;
                        end else if (sram_ack) begin
                            logic [7:0] pix;
                            sram_req <= 1'b0;
                            fetch_wait <= 1'b0;
                            cw_valid <= 1'b1;
                            cw_tag <= px_word;
                            cw_word <= sram_rdata;
                            pix = px_hi ? sram_rdata[15:8] : sram_rdata[7:0];
                            if (pix != 8'd0 && inb) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(pxy) * 19'(MW) + 19'(pxx);
                                fb_wdata <= pix;
                            end
                            if (last_px) busy <= 1'b0;
                            else adv();
                        end
                    end
                    default: begin // M_IMGD
                        if (!fetch_wait) begin
                            if (imgd_i < 19'(FB_PIXELS)) begin
                                sram_req <= 1'b1;
                                sram_addr <= px_word;
                                fetch_wait <= 1'b1;
                            end else begin
                                // source ran off the snapshot: no write
                                if (last_px) busy <= 1'b0;
                                else adv();
                            end
                        end else if (sram_ack) begin
                            sram_req <= 1'b0;
                            fetch_wait <= 1'b0;
                            if (inb) begin
                                fb_we <= 1'b1;
                                fb_waddr <= 19'(pxy) * 19'(MW) + 19'(pxx);
                                fb_wdata <= sram_rdata[7:0];
                            end
                            if (last_px) busy <= 1'b0;
                            else adv();
                        end
                    end
                endcase
            end
        end
    end
endmodule
