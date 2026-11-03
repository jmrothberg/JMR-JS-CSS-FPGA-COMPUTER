// Optional 32x32 JIC1 disk icon -> framebuffer pixel stream.
// The disk reader supplies bytes in file order with valid/ready. It may
// stall freely and signals src_error on I/O failure. Missing/wrong-size files
// use file_size=0. No frame buffer or JS heap is duplicated here.
// Emit ALL coordinates: pixel_opaque=0 means restore the desktop background.
// This also erases any partial custom icon if an I/O failure needs fallback.
module jmr_icon_stream (
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [31:0] file_size,
    input  logic        src_error,
    input  logic        src_valid,
    output logic        src_ready,
    input  logic [7:0]  src_data,
    output logic        pixel_valid,
    input  logic        pixel_ready,
    output logic [4:0]  pixel_x,
    output logic [4:0]  pixel_y,
    output logic [7:0]  pixel_rgb332,
    output logic        pixel_opaque,
    output logic        busy,
    output logic        done,
    output logic        fallback
);
    typedef enum logic [2:0] {IDLE, HEADER, MASK, PIXEL, EMIT, GENERIC} state_t;
    state_t state;
    logic [2:0] header_i;
    logic [6:0] mask_i;
    logic [9:0] pixel_i;
    logic [7:0] colour;
    logic [7:0] mask_rdata;
    logic [6:0] mask_addr;
    logic mask_we;
    // Tiny legal single-address RAM process; never reset the memory array.
    (* ram_style = "distributed" *) logic [7:0] mask_mem [0:127];
    assign mask_addr = (state == MASK) ? mask_i : pixel_i[9:3];
    assign mask_we = (state == MASK) && src_valid && src_ready && !src_error && !rst;
    always_ff @(posedge clk) begin
        if (mask_we) mask_mem[mask_addr] <= src_data;
        mask_rdata <= mask_mem[mask_addr];
    end

    function automatic logic [7:0] header_byte(input logic [2:0] i);
        case (i)
            0: header_byte = "J";
            1: header_byte = "I";
            2: header_byte = "C";
            3: header_byte = "1";
            4, 5: header_byte = 8'd32;
            6: header_byte = 8'd1;
            default: header_byte = 8'd0;
        endcase
    endfunction

    // Same generic application window as functional_model/desktop_icons.py.
    function automatic logic [8:0] generic_pixel(input logic [4:0] x, y);
        if (x < 3 || x > 28 || y < 3 || y > 28)
            generic_pixel = 9'h000;
        else if (x == 3 || x == 28 || y == 3 || y == 28 || y == 9)
            generic_pixel = {1'b1, 8'h00};
        else if (y <= 8)
            generic_pixel = {1'b1, 8'h17};
        else if (x >= 7 && x <= 24 && y >= 14 && y <= 23)
            generic_pixel = {1'b1, (x == 7 || x == 24 || y == 14 || y == 23) ? 8'h00 : 8'hFC};
        else
            generic_pixel = {1'b1, 8'hFF};
    endfunction

    logic [8:0] generic_value;
    assign generic_value = generic_pixel(pixel_i[4:0], pixel_i[9:5]);
    assign src_ready = (state == HEADER || state == MASK || state == PIXEL) && !src_error && !rst;
    assign pixel_valid = (state == EMIT || state == GENERIC) && !src_error && !rst;
    assign pixel_x = pixel_i[4:0];
    assign pixel_y = pixel_i[9:5];
    assign pixel_rgb332 = (state == GENERIC) ? generic_value[7:0] : colour;
    assign pixel_opaque = (state == GENERIC) ? generic_value[8] : mask_rdata[7-pixel_i[2:0]];
    assign busy = state != IDLE;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 1'b0;
            fallback <= 1'b0;
            header_i <= 0;
            mask_i <= 0;
            pixel_i <= 0;
            colour <= 0;
        end else begin
            done <= 1'b0;
            if (src_error && busy) begin
                state <= GENERIC;
                pixel_i <= 0;
                fallback <= 1'b1;
            end else case (state)
                IDLE: if (start) begin
                    header_i <= 0;
                    mask_i <= 0;
                    pixel_i <= 0;
                    fallback <= file_size != 32'd1160;
                    state <= (file_size == 32'd1160) ? HEADER : GENERIC;
                end
                HEADER: if (src_valid && src_ready) begin
                    if (src_data != header_byte(header_i)) begin
                        fallback <= 1'b1;
                        state <= GENERIC;
                    end else if (header_i == 7) state <= MASK;
                    else header_i <= header_i + 1'b1;
                end
                MASK: if (src_valid && src_ready) begin
                    if (mask_i == 127) state <= PIXEL;
                    else mask_i <= mask_i + 1'b1;
                end
                PIXEL: if (src_valid && src_ready) begin
                    colour <= src_data;
                    state <= EMIT;
                end
                EMIT, GENERIC: if (pixel_valid && pixel_ready) begin
                    if (pixel_i == 1023) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        pixel_i <= pixel_i + 1'b1;
                        if (state == EMIT) state <= PIXEL;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
