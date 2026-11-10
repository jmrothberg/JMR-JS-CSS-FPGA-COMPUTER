// Text VRAM → 640×480 RGB for Digilent rgb2dvi (BASIC vga_scanout method).
// game_mode paints native 640×480 FB 1:1 (was mini 160×120 ×4).
// Combo vram_addr + geom delay matches dual-clock BRAM (fixes torn glyphs).
module jmr_text_hdmi_scanout #(
    parameter string FONT_HEX = "font_rom.hex"
) (
    input  logic        pixel_clk,
    input  logic        mouse_clk,
    input  logic        rst_n,
    input  logic [7:0]  vram_rdata,
    output logic [9:0]  vram_addr,
    input  logic [9:0]  cursor_cell,
    input  logic        game_mode,
    input logic [9:0] mouse_x = 10'd320,
    input logic [8:0] mouse_y = 9'd240,
    input logic mouse_toggle = 1'b0,
    input logic mouse_show_exit = 1'b0,
    input logic system_menu=1'b0,system_keyboard=1'b0,system_about=1'b0,system_shift=1'b0,system_caps=1'b0,system_ctrl=1'b0,system_alt=1'b0,
    input logic [6:0] system_pressed=7'd127,
    input logic system_hold=1'b0,
    input logic [31:0] system_window=32'd0,
    input logic system_game_viewport=1'b0,system_ui_opaque=1'b0,
    input logic [23:0] system_ui_rgb=24'd0,
    input logic [69:0] system_held=70'd0,

    output logic [18:0] fb_raddr,
    // Raw beam position for the DDR3 line prefetcher
    // (avoids a divide-by-640 on the linear address).
    output logic [9:0]  fb_x,
    output logic [9:0]  fb_y,
    input  logic [7:0]  fb_rdata,
    // ASET palette (pixel-clk registered BRAM in the core)
    output logic [7:0]  pal_index,
    input  logic [23:0] pal_rgb,
    output logic [23:0] vid_pData,
    output logic        vid_pVDE,
    output logic        vid_pHSync,
    output logic        vid_pVSync
);
    localparam int H_VISIBLE = 640;
    localparam int H_FP = 16;
    localparam int H_SYNC = 96;
    localparam int H_BP = 48;
    localparam int H_TOTAL = 800;
    localparam int V_VISIBLE = 480;
    localparam int V_FP = 10;
    localparam int V_SYNC = 2;
    localparam int V_BP = 33;
    localparam int V_TOTAL = 525;
    // Sharp 8×8 font: 8×16 cells → 512×256 field, letterboxed
    localparam int CELL_W = 8;
    localparam int CELL_H = 16;
    localparam int TEXT_W = 64 * CELL_W; // 512
    localparam int TEXT_H = 16 * CELL_H; // 256
    localparam int ORIGIN_X = (H_VISIBLE - TEXT_W) / 2; // 64
    localparam int ORIGIN_Y = (V_VISIBLE - TEXT_H) / 2; // 112

    logic [7:0] font_rom [0:1023];
    initial $readmemh(FONT_HEX, font_rom);

    function automatic logic [23:0] pal(input logic [7:0] i);
        case (i)
            8'd0: pal = 24'h000000;
            8'd1: pal = 24'hFFFFFF;
            8'd2: pal = 24'hFF4040;
            8'd3: pal = 24'h40FF40;
            8'd4: pal = 24'h4040FF;
            8'd5: pal = 24'hFFFF40;
            default: pal = 24'h808080;
        endcase
    endfunction

    logic [9:0] hcnt, vcnt;
    logic [5:0] frame_div;
    logic [9:0] cell_d;
    logic [2:0] grow_d, gcol_d;
    logic in_text_d, visible_d, game_d;
    logic [9:0] hx_d, hy_d;
    logic [9:0] cell_q;
    logic [7:0] ch_q;
    logic [2:0] grow_q, gcol_q;
    logic in_text_q, visible_q, game_q;
    logic [7:0] fb_q;
    logic [9:0] hx_q, hy_q;
    logic [7:0] bits;
    logic on_pix;

    // Keep each pointer payload stable until the pixel domain acknowledges it.
    // The source coordinates retain the latest pending position while a prior
    // snapshot is in flight; report toggles can no longer cancel in a burst.
    localparam logic [18:0] POINTER_RESET = {10'd320,9'd240};
    logic [18:0] pointer_pixels;
    (* ASYNC_REG="TRUE" *) logic [1:0] exit_sync;
    wire [9:0] mouse_px;
    wire [8:0] mouse_py;
    logic overlay_opaque;
    logic [23:0] overlay_rgb;
    jmr_ui_snapshot #(.WIDTH(19)) u_pointer_snapshot (
        .clk(mouse_clk),.rst_n(rst_n),.pixel_clk(pixel_clk),
        .source({mouse_x,mouse_y} ^ POINTER_RESET),.pixels(pointer_pixels)
    );
    assign {mouse_px,mouse_py}=pointer_pixels ^ POINTER_RESET;
    always_ff @(posedge pixel_clk) begin
        if(!rst_n)exit_sync<=0;
        else exit_sync<={exit_sync[0],mouse_show_exit};
    end
    jmr_mouse_overlay u_pointer_overlay (
        .x(hx_q),.y(hy_q),.mouse_x(mouse_px),.mouse_y(mouse_py),
        .show_pointer(1'b1),.opaque(overlay_opaque),.rgb(overlay_rgb)
    );
    (* ASYNC_REG="TRUE" *) logic [6:0] system_sync1,system_sync2;
    (* ASYNC_REG="TRUE" *) logic [6:0] pressed_sync1,pressed_sync2;
    (* ASYNC_REG="TRUE" *) logic [70:0] held_sync1,held_sync2;
    logic system_opaque;
    logic [23:0] system_rgb;
    always_ff @(posedge pixel_clk)begin
        if(!rst_n)begin system_sync1<=0;system_sync2<=0;pressed_sync1<=127;pressed_sync2<=127;held_sync1<=0;held_sync2<=0;end
        else begin
            system_sync1<={system_about,system_menu,system_keyboard,system_shift,system_caps,system_ctrl,system_alt};
            system_sync2<=system_sync1;pressed_sync1<=system_pressed;pressed_sync2<=pressed_sync1;
            held_sync1<={system_hold,system_held};held_sync2<=held_sync1;
        end
    end
    // UI pixels are rendered by the core's two-stage pixel-clock circuit.
    // The same circuit supplies UISURFACE in Verilator; no second renderer.
    assign system_opaque=system_ui_opaque;
    assign system_rgb=system_ui_rgb;
    wire visible = (hcnt < H_VISIBLE) && (vcnt < V_VISIBLE);
    wire signed [10:0] tx = $signed({1'b0, hcnt}) - ORIGIN_X;
    wire signed [10:0] ty = $signed({1'b0, vcnt}) - ORIGIN_Y;
    wire in_text = visible && (tx >= 0) && (tx < TEXT_W) && (ty >= 0) && (ty < TEXT_H);
    wire [5:0] col = tx[9:3];
    wire [3:0] row = ty[7:4];
    wire [2:0] grow = ty[3:1];
    wire [2:0] gcol = tx[2:0];

    assign vram_addr = in_text ? {row, col} : 10'd0;
    // 1:1 FB address (native 640×480)
    assign fb_raddr = visible ? (19'(vcnt) * 19'd640 + 19'(hcnt)) : 19'd0;
    assign fb_x = 10'(hcnt);
    assign fb_y = 10'(vcnt);
    // Palette read is registered; pal_rgb lines up with fb_q (same 1-cycle delay).
    assign pal_index = fb_rdata;

    always_comb begin
        bits = font_rom[{ch_q[6:0], grow_q}];
        on_pix = bits[7 - gcol_q];
    end

    always_ff @(posedge pixel_clk) begin
        if (!rst_n) begin
            hcnt <= 0; vcnt <= 0; frame_div <= 0;
            cell_d <= 0; grow_d <= 0; gcol_d <= 0;
            in_text_d <= 0; visible_d <= 0; game_d <= 0;
            hx_d <= 0; hy_d <= 0;
            cell_q <= 0; ch_q <= 8'h20;
            grow_q <= 0; gcol_q <= 0; in_text_q <= 0; visible_q <= 0;
            game_q <= 0; fb_q <= 0; hx_q <= 0; hy_q <= 0;
            vid_pData <= 0; vid_pVDE <= 0; vid_pHSync <= 0; vid_pVSync <= 0;
        end else begin
            if (hcnt == H_TOTAL - 1) begin
                hcnt <= 0;
                if (vcnt == V_TOTAL - 1) begin
                    vcnt <= 0;
                    frame_div <= frame_div + 1'b1;
                end else vcnt <= vcnt + 1'b1;
            end else hcnt <= hcnt + 1'b1;

            cell_d <= {row, col};
            grow_d <= grow;
            gcol_d <= gcol;
            in_text_d <= in_text;
            visible_d <= visible;
            game_d <= game_mode;
            hx_d <= hcnt;
            hy_d <= vcnt;

            ch_q <= vram_rdata;
            grow_q <= grow_d;
            gcol_q <= gcol_d;
            cell_q <= cell_d;
            in_text_q <= in_text_d;
            visible_q <= visible_d;
            game_q <= game_d;
            fb_q <= fb_rdata;
            hx_q <= hx_d;
            hy_q <= hy_d;

            vid_pHSync <= (hcnt >= H_VISIBLE + H_FP) && (hcnt < H_VISIBLE + H_FP + H_SYNC);
            vid_pVSync <= (vcnt >= V_VISIBLE + V_FP) && (vcnt < V_VISIBLE + V_FP + V_SYNC);
            vid_pVDE   <= visible_q;

            if (visible_q && overlay_opaque) begin
                vid_pData <= overlay_rgb;
            end else if(visible_q && system_opaque)begin
                vid_pData<=system_rgb;
            end else if(system_game_viewport && visible_q && hy_q>=22 && hy_q<24)begin
                vid_pData<=0;
            end else if(system_window[7:0]!=0 && !game_q && visible_q)begin
                vid_pData <= (in_text_q && on_pix)?24'h000000:24'hffffff;
            end else if (game_q && visible_q && (hx_q < 10'd640) && (hy_q < 10'd480)) begin
                vid_pData <= pal_rgb;
            end else if (in_text_q) begin
                if (frame_div[5] && (cell_q == cursor_cell))
                    vid_pData <= 24'h40FFFF;
                else if (on_pix)
                    vid_pData <= 24'hFFFFFF;
                else
                    vid_pData <= 24'h000000;
            end else if (visible_q) begin
                vid_pData <= 24'h000000;
            end else begin
                vid_pData <= 24'h0;
            end
        end
    end
endmodule
