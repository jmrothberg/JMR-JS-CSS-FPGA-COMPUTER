// Full-rate raster/blit/ImageData engine.
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
    parameter logic [21:0] SPR_SRAM_BASE  = 22'd3788800,
    parameter logic [21:0] IMGD_SRAM_BASE = 22'd3887104
) (
    input  logic        clk,
    input  logic        rst_n,
    // VM handshake (go is a VM-beat-wide pulse; edge-detected here)
    input  logic        go,
    input  logic [1:0]  mode,      // 0 FILL, 1 BLIT, 2 IMGD
    // signed dest origin: Canvas drawImage keeps DDA in source while dest
    // hangs off-glass (clip_u to 0 smeared sheet-left onto x=0 — RUN 69 #5).
    input  logic signed [11:0] dx, dy,
    input  logic [9:0]  w, h,
    input  logic [7:0]  color,
    input  logic [15:0] sx, sy,          // blit_sx / blit_sy
    input  logic [15:0] qx, rxr, qy, ryr, // DDA quotient/remainder pairs
    input  logic [22:0] sbase,     // spr_off[si] (blit) / imgd_i (imgd)
    input  logic [15:0] stride,    // spr_ww[si]
    input  logic        aset,
    // neg-xform: negative dWidth/dHeight (or ctx_sx/sy<0) mirrors the dest
    // rect; the source DDA (so/row_so/ax/ay below) walks forward exactly as
    // before — only which dest column/row each step paints is reversed.
    input  logic        flip_x,
    input  logic        flip_y,
    output logic        busy,
    // framebuffer write port (100 MHz side of jmr_mini_fb)
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [9:0]  fb_x, fb_y,
    output logic [7:0]  fb_wdata,
    // Scissor rectangle (Toolbox clip_*); fb_clip_in is the test of
    // (fb_x,fb_y) against it, registered with fb_we (build 96: the compare
    // moved here from the core write-enable cone, like the Toolbox's).
    input  logic [9:0]  clip_x0, clip_y0, clip_x1, clip_y1,
    output logic        fb_clip_in,
    // asset SRAM read client (hold-req-until-ack, arbiter owner 6)
    output logic        sram_req,
    output logic [24:0] sram_addr,
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
    logic signed [11:0] dx_q, dy_q;
    logic [9:0]  w_q, h_q;
    logic [7:0]  color_q;
    logic [15:0] qx_q, rxr_q, qy_q, ryr_q, stride_q;
    logic        aset_q;
    logic        flip_x_q, flip_y_q;
    // walk state
    logic [9:0]  x, y;
    logic [15:0] ax, ay;          // DDA remainder accumulators
    logic [22:0] so, row_so;      // blit source offsets (byte index)
    logic [22:0] row_step;        // stride*qy, latched at go
    logic [22:0] row_step_s;      // stride*(qy+1), latched at go
    logic [18:0] imgd_i;          // linear imgd source index
    logic imgd_in_range; // advanced with imgd_i; no compare on write enable
    logic        fetch_wait;
    // dest address, incremental: fb_row is the
    // current row's first pixel, fb_addr the current pixel. One constant
    // multiply per OP at go; per pixel the address is an incrementer,
    // not a 3-level multiply-add replicated in four case arms. Advanced
    // in adv() UNCONDITIONALLY (OOB pixels skip the write but still
    // step), and re-anchored to fb_row+MW at every row wrap so OOB
    // drift never carries across rows.
    logic [18:0] fb_row, fb_addr;
    // Post-route fix: the row-wrap DDA (ay+ryr>=h compare
    // selecting row_so + row_step (+stride)) was the worst routed family
    // (-0.53, 9 levels). Precompute the next row's so/ay into registers
    // every clk; the wrap consumes registers only. nxt_ok guards the one
    // stale beat right after a wrap (or go): a wrap that arrives before
    // the precompute settles simply holds one beat — the pixel beat
    // re-runs idempotently (same fetch, same write). Only 1-px-wide
    // rows ever hit the hold (covered by the 1-px-wide exact gate).
    // Build 96: both next-row candidates are registered separately from the
    // wrap compare (ay+ryr>=h), and the wrap picks between registers. The
    // compare no longer selects an adder input (was ryr_q -> nxt_row_so,
    // 7 levels). Same settle rule: valid one clock after the row registers.
    logic [22:0] nxt_so_n, nxt_so_w;   // row_so + row_step (+stride)
    logic [15:0] nxt_ay_n, nxt_ay_w;   // ay + ryr (- h)
    logic        nxt_wrap;
    wire  [22:0] nxt_row_so = nxt_wrap ? nxt_so_w : nxt_so_n;
    wire  [15:0] nxt_ay     = nxt_wrap ? nxt_ay_w : nxt_ay_n;
    logic        nxt_ok;
    // One-word source cache: tag is relative to the fixed per-operation base.
    // Compare before base addition; request addresses retain their original form.
    logic        cw_valid;
    logic [21:0] cw_tag;
    logic [21:0] issued_key; // relative key paired with the outstanding SRAM address
    logic [15:0] cw_word;

    // Blit source cache: two 8-word lines of the sprite sheet, aligned like
    // the DDR3 bridge burst, least recently used replaced. A miss fetches
    // the needed word, then the rest of its line while pixels are drawn from
    // the cache. Two lines keep a source row that straddles a burst boundary
    // for the next destination rows of an enlarged sprite. Cleared at every
    // `go`, like the one-word cache below.
    logic [15:0] lc_data [0:1][0:7];
    logic [18:0] lc_tag [0:1];
    logic [7:0]  lc_v [0:1];
    logic        lc_lru, lc_fill, lc_fway, fetch_way, blit_end;
    logic [2:0]  lc_fidx, fetch_idx;
    logic [18:0] lc_fline;   // physical line of the line being streamed

    // per-pixel source word address + byte lane
    logic [21:0] px_word;
    logic [21:0] px_key;
    logic        px_hi;
    always_comb begin
        if (m_q == M_IMGD) begin
            px_key  = 22'(imgd_i >> 1);
            px_word = IMGD_SRAM_BASE + 21'(imgd_i >> 1);
            px_hi   = imgd_i[0];
        end else if (aset_q) begin
            px_key  = so[22:1];
            px_word = 23'(so[22:1]);
            px_hi   = so[0];
        end else begin
            px_key  = {4'd0, so[17:0]};
            px_word = SPR_SRAM_BASE + 21'(so[17:0]);
            px_hi   = 1'b0;
        end
    end

    wire [18:0] px_line = px_key[21:3];
    wire [2:0]  px_wi = px_key[2:0];
    wire lc_t0 = lc_tag[0] == px_line;
    wire lc_t1 = lc_tag[1] == px_line;
    wire lc_h0 = lc_t0 && lc_v[0][px_wi];
    wire lc_h1 = lc_t1 && lc_v[1][px_wi];
    wire [15:0] lc_word = lc_h0 ? lc_data[0][px_wi] : lc_data[1][px_wi];
    wire [7:0]  blit_pix = px_hi ? lc_word[15:8] : lc_word[7:0];

    // effective dest x/y for this walk step: mirrored under flip_x/flip_y so
    // the source DDA order above is untouched (neg-xform).
    logic [9:0] xe, ye;
    assign xe = flip_x_q ? (w_q - 10'd1 - x) : x;
    assign ye = flip_y_q ? (h_q - 10'd1 - y) : y;
    logic signed [12:0] pxx, pxy;
    assign pxx = dx_q + $signed({2'b0, xe});
    assign pxy = dy_q + $signed({2'b0, ye});
    logic inb;
    assign inb = (pxx >= 0) && (pxx < $signed(13'(MW)))
              && (pxy >= 0) && (pxy < $signed(13'(MH)));
    // Write addr from visible dest (not incremental from a possibly
    // off-glass start — negative dx used to wrap unsigned fb_addr).
    logic [18:0] pix_addr;
    assign pix_addr = 19'(pxy[9:0]) * 19'(MW) + 19'(pxx[9:0]);

    // advance to the next dest pixel; returns via updated x/y/so/row_so/
    // ax/ay/imgd_i registers. Shared by all three modes.
    logic last_px;
    assign last_px = (x == w_q - 10'd1) && (y == h_q - 10'd1);

    task automatic adv();
        logic held;
        held = (x == w_q - 10'd1) && !nxt_ok;
        if (x == w_q - 10'd1) begin
            if (!nxt_ok) begin
                // precompute not settled (wrap right after wrap/go, i.e.
                // w==1): hold this beat; the caller's pixel beat re-runs
                // idempotently and the wrap proceeds next clk.
            end else begin
                x  <= 10'd0;
                ax <= 16'd0;
                y  <= y + 10'd1;
                fb_row  <= fb_row + 19'(MW);
                fb_addr <= fb_row + 19'(MW);
                row_so <= nxt_row_so;
                so     <= nxt_row_so;
                ay     <= nxt_ay;
                nxt_ok <= 1'b0;
            end
        end else begin
            x <= x + 10'd1;
            fb_addr <= fb_addr + 19'd1;
            if (16'(ax + rxr_q) >= {6'd0, w_q}) begin
                so <= so + 23'(qx_q) + 22'd1;
                ax <= 16'(ax + rxr_q) - {6'd0, w_q};
            end else begin
                so <= so + 23'(qx_q);
                ax <= ax + rxr_q;
            end
        end
        if (!held) begin
            imgd_i <= imgd_i + 19'd1;
            imgd_in_range <= (imgd_i < 19'(FB_PIXELS-1)) || (&imgd_i);
        end
    endtask

    // Fill and ImageData walk consecutive destination/source pixels;
    // they do not consume the scaled-sprite DDA or its next-row result.
    // Keep their handshake/cache controls out of the DDA register enables.
    task automatic adv_linear();
        if (x == w_q - 10'd1) begin
            x <= 10'd0;
            y <= y + 10'd1;
            fb_row <= fb_row + 19'(MW);
            fb_addr <= fb_row + 19'(MW);
        end else begin
            x <= x + 10'd1;
            fb_addr <= fb_addr + 19'd1;
        end
        imgd_i <= imgd_i + 19'd1;
        imgd_in_range <= (imgd_i < 19'(FB_PIXELS-1)) || (&imgd_i);
    endtask

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            fb_x <= '0; fb_y <= '0;
            fb_we <= 1'b0;
            sram_req <= 1'b0;
            fetch_wait <= 1'b0;
            cw_valid <= 1'b0;
        end else begin
            fb_we <= 1'b0;
            // Build 96: the write address/coordinates/data load every clock;
            // only fb_we carries the per-pixel decision, so the blit hit
            // cone no longer fans out into ~50 clock enables. Consumers use
            // them only with fb_we (jmr_js_core write mux and scissor).
            fb_waddr <= pix_addr;
            fb_x <= pxx[9:0]; fb_y <= pxy[9:0];
            fb_clip_in <= pxx[9:0] >= clip_x0 && pxx[9:0] < clip_x1 &&
                          pxy[9:0] >= clip_y0 && pxy[9:0] < clip_y1;
            fb_wdata <= (m_q == M_FILL) ? color_q :
                        (m_q == M_BLIT) ? blit_pix :
                        fetch_wait ? (px_hi ? sram_rdata[15:8] : sram_rdata[7:0])
                                   : (px_hi ? cw_word[15:8] : cw_word[7:0]);
            // continuous next-row precompute (valid 1 clk after row regs settle)
            nxt_wrap <= 16'(ay + ryr_q) >= {6'd0, h_q};
            nxt_so_w <= row_so + row_step_s;
            nxt_so_n <= row_so + row_step;
            nxt_ay_w <= 16'(ay + ryr_q) - {6'd0, h_q};
            nxt_ay_n <= ay + ryr_q;
            nxt_ok <= 1'b1;
            if (!busy) begin
                if (go_edge) begin
                    m_q <= mode;
                    dx_q <= dx; dy_q <= dy; w_q <= w; h_q <= h;
                    color_q <= color;
                    qx_q <= qx; rxr_q <= rxr; qy_q <= qy; ryr_q <= ryr;
                    stride_q <= stride;
                    aset_q <= aset;
                    flip_x_q <= flip_x;
                    flip_y_q <= flip_y;
                    x <= 10'd0; y <= 10'd0;
                    ax <= 16'd0; ay <= 16'd0;
                    // row-0 source base: two 16-bit DSP products, once per op
                    fb_row  <= 19'(dy) * 19'(MW) + 19'(dx);
                    fb_addr <= 19'(dy) * 19'(MW) + 19'(dx);
                    so     <= sbase + 23'(sy) * 23'(stride) + 23'(sx);
                    row_so <= sbase + 23'(sy) * 23'(stride) + 23'(sx);
                    row_step <= 23'(qy) * 23'(stride);
                    row_step_s <= 23'({1'b0, qy} + 17'd1) * 23'(stride);
                    imgd_i <= 19'(sbase[18:0]);
                    imgd_in_range <= sbase[18:0] < 19'(FB_PIXELS);
                    fetch_wait <= 1'b0;
                    nxt_ok <= 1'b0;     // precompute settles next clk
                    cw_valid <= 1'b0;   // never serve across ops (re-uploads)
                    lc_v[0] <= 8'd0; lc_v[1] <= 8'd0;
                    lc_fill <= 1'b0; lc_lru <= 1'b0; blit_end <= 1'b0;
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
                        if (inb) fb_we <= 1'b1;
                        if (last_px) busy <= 1'b0;
                        else adv_linear();
                    end
                    M_BLIT: begin
                        if (fetch_wait && sram_ack) begin
                            lc_data[fetch_way][fetch_idx] <= sram_rdata;
                            lc_v[fetch_way][fetch_idx] <= 1'b1;
                            if (lc_fill && !blit_end && !lc_v[lc_fway][lc_fidx] &&
                                (lc_h0 || lc_h1 || (lc_fway ? lc_t1 : lc_t0))) begin
                                // next word of the streamed line, back to back
                                sram_addr <= {lc_fline, lc_fidx};
                                fetch_way <= lc_fway;
                                fetch_idx <= lc_fidx;
                                lc_fidx <= lc_fidx + 3'd1;
                                lc_fill <= lc_fidx != 3'd7;
                            end else begin
                                sram_req <= 1'b0;
                                fetch_wait <= 1'b0;
                            end
                        end
                        if (blit_end) begin
                            // last pixel written; finish a streaming fetch
                            if (!fetch_wait || sram_ack) busy <= 1'b0;
                        end else begin
                            if (lc_h0 || lc_h1) begin
                                // cache hit: write and advance, 1 clk/px
                                if (blit_pix != 8'd0 && inb) fb_we <= 1'b1;
                                lc_lru <= lc_h0;
                                if (last_px) begin
                                    blit_end <= 1'b1;
                                    if (!fetch_wait) busy <= 1'b0;
                                end else adv();
                            end
                            if (!fetch_wait) begin
                                if (!(lc_h0 || lc_h1)) begin
                                    // demand: this pixel's word
                                    sram_req <= 1'b1;
                                    sram_addr <= px_word;
                                    fetch_wait <= 1'b1;
                                    fetch_idx <= px_wi;
                                    if (lc_t0 || lc_t1) fetch_way <= !lc_t0;
                                    else begin
                                        fetch_way <= lc_lru;
                                        lc_tag[lc_lru] <= px_line;
                                        lc_v[lc_lru] <= 8'd0;
                                        lc_fway <= lc_lru;
                                        lc_fline <= px_word[21:3];
                                        lc_fidx <= px_wi + 3'd1;
                                        lc_fill <= px_wi != 3'd7;
                                    end
                                end else if (lc_fill) begin
                                    // rest of the line, in order
                                    if (!lc_v[lc_fway][lc_fidx]) begin
                                        sram_req <= 1'b1;
                                        sram_addr <= {lc_fline, lc_fidx};
                                        fetch_wait <= 1'b1;
                                        fetch_way <= lc_fway;
                                        fetch_idx <= lc_fidx;
                                    end
                                    lc_fidx <= lc_fidx + 3'd1;
                                    lc_fill <= lc_fidx != 3'd7;
                                end
                            end
                        end
                    end
                    default: begin // M_IMGD
                        if (!fetch_wait && cw_valid && cw_tag == px_key &&
                            imgd_in_range) begin
                            if (inb) fb_we <= 1'b1;
                            if (last_px) begin
                                busy <= 1'b0;
                                sram_req <= 1'b0;
                            end else begin
                                adv_linear();
                                // The high byte finishes this word. Start
                                // the next read while that pixel is written.
                                if (imgd_i[0] && imgd_i < 19'(FB_PIXELS-1)) begin
                                    sram_addr <= px_word + 21'd1;
                                    issued_key <= px_key + 22'd1;
                                    sram_req <= 1'b1;
                                    fetch_wait <= 1'b1;
                                end
                            end
                        end else if (!fetch_wait) begin
                            if (imgd_in_range) begin
                                sram_req <= 1'b1;
                                sram_addr <= px_word;
                            issued_key <= px_key;
                                fetch_wait <= 1'b1;
                            end else begin
                                // source ran off the snapshot: no write
                                if (last_px) busy <= 1'b0;
                                else adv_linear();
                            end
                        end else if (sram_ack) begin
                            cw_valid <= 1'b1;
                            cw_tag <= issued_key;
                            cw_word <= sram_rdata;
                            if (inb) fb_we <= 1'b1;
                            if (last_px) begin
                                busy <= 1'b0;
                                sram_req <= 1'b0;
                                fetch_wait <= 1'b0;
                            end else begin
                                adv_linear();
                                // A low byte is followed by its cached high
                                // byte; a high byte hands off the next word.
                                // Arbitration can preempt at every ack.
                                if (imgd_i[0] && imgd_i < 19'(FB_PIXELS-1)) begin
                                    sram_addr <= sram_addr + 21'd1;
                                    // Use the OLD issued key, matching the old address,
                                    // including mode 3's existing default-arm behavior.
                                    issued_key <= issued_key + 22'd1;
                                    sram_req <= 1'b1;
                                    fetch_wait <= 1'b1;
                                end else begin
                                    sram_req <= 1'b0;
                                    fetch_wait <= 1'b0;
                                end
                            end
                        end
                    end
                endcase
            end
        end
    end
endmodule
