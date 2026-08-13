// HDMI scanout stub: 640×480 timing → Digilent rgb2dvi video bus.
// LLM NOTE: Do NOT invent TMDS. Instantiate Digilent rgb2dvi from
// third_party/digilent_rgb2dvi (vivado-library ip/rgb2dvi) in the Vivado
// board top. This module only produces RGB + sync at PixelClk.
//
// Pattern cite: Digilent Nexys Video HDMI demos — method only.
module jmr_hdmi_scanout (
    input  wire        pixel_clk,   // ~25.175 MHz for 640x480@60
    input  wire        rst,
    // Framebuffer read (BRAM/DDR port — sim uses FB model)
    output reg  [18:0] fb_addr,
    input  wire [7:0]  fb_index,
    // Palette lookup (BRAM)
    output wire [7:0]  pal_index,
    input  wire [23:0] pal_rgb,
    // Digilent rgb2dvi video-in
    output reg  [23:0] vid_pData,
    output reg         vid_pVDE,
    output reg         vid_pHSync,
    output reg         vid_pVSync
);
    // 640x480@60 CEA-ish counters (simplified)
    localparam H_VISIBLE = 640;
    localparam H_FP      = 16;
    localparam H_SYNC    = 96;
    localparam H_BP      = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FP + H_SYNC + H_BP; // 800
    localparam V_VISIBLE = 480;
    localparam V_FP      = 10;
    localparam V_SYNC    = 2;
    localparam V_BP      = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FP + V_SYNC + V_BP; // 525

    reg [9:0] hcnt, vcnt;
    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

    assign pal_index = fb_index;

    always @(posedge pixel_clk) begin
        if (rst) begin
            hcnt <= 0; vcnt <= 0;
            fb_addr <= 0;
            vid_pData <= 0; vid_pVDE <= 0; vid_pHSync <= 0; vid_pVSync <= 0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL - 1) vcnt <= 0;
                else vcnt <= vcnt + 1'b1;
            end else hcnt <= hcnt + 1'b1;

            vid_pHSync <= (hcnt >= H_VISIBLE + H_FP) && (hcnt < H_VISIBLE + H_FP + H_SYNC);
            vid_pVSync <= (vcnt >= V_VISIBLE + V_FP) && (vcnt < V_VISIBLE + V_FP + V_SYNC);
            vid_pVDE   <= visible;
            if (visible) begin
                fb_addr  <= vcnt * H_VISIBLE + hcnt;
                vid_pData <= pal_rgb;
            end else begin
                vid_pData <= 24'h0;
            end
        end
    end
endmodule
