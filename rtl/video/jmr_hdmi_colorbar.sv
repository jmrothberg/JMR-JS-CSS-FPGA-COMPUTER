// Standalone HDMI color bars — no host UART required after config/QSPI boot.
// LLM NOTE: First silicon smoke for Nexys Video. Full JS monitor/games come
// later; this proves Digilent rgb2dvi + pinout work untethered.
module jmr_hdmi_colorbar (
    input  wire        pixel_clk,
    input  wire        rst,
    output reg  [23:0] vid_pData,
    output reg         vid_pVDE,
    output reg         vid_pHSync,
    output reg         vid_pVSync
);
    localparam H_VISIBLE = 640;
    localparam H_FP      = 16;
    localparam H_SYNC    = 96;
    localparam H_BP      = 48;
    localparam H_TOTAL   = 800;
    localparam V_VISIBLE = 480;
    localparam V_FP      = 10;
    localparam V_SYNC    = 2;
    localparam V_BP      = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] hcnt, vcnt;
    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);

    always @(posedge pixel_clk) begin
        if (rst) begin
            hcnt <= 0; vcnt <= 0;
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
                // 8 vertical color bars + green "alive" stripe at top
                if (vcnt < 10'h20)
                    vid_pData <= 24'h00_C0_40; // brand-ish green header
                else begin
                    case (hcnt[9:7])
                        3'd0: vid_pData <= 24'hFF0000;
                        3'd1: vid_pData <= 24'h00FF00;
                        3'd2: vid_pData <= 24'h0000FF;
                        3'd3: vid_pData <= 24'hFFFF00;
                        3'd4: vid_pData <= 24'h00FFFF;
                        3'd5: vid_pData <= 24'hFF00FF;
                        3'd6: vid_pData <= 24'hFFFFFF;
                        default: vid_pData <= 24'h404040;
                    endcase
                end
            end else vid_pData <= 24'h0;
        end
    end
endmodule
