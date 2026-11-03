// Desktop FAT client. Shares the existing storage engine and WORK port;
// no second FAT implementation, SD controller, JS heap or framebuffer.
module jmr_desktop_disk (
    input logic clk, rst_n,
    input logic catalog_go, icon_go,show_hidden,
    input logic [7:0] icon_index,
    output logic busy, done, disk_error,
    output logic [8:0] count,
    input logic [11:0] catalog_addr,
    output logic [7:0] catalog_data,
    output logic icon_valid,
    input logic icon_ready,
    output logic [4:0] icon_x, icon_y,
    output logic [7:0] icon_colour,
    output logic icon_opaque,
    output logic stor_open, stor_close, stor_dir, stor_next, stor_get,
    output logic [7:0] stor_name_len,
    input logic stor_busy, stor_done, stor_err, stor_eof,
    input logic [7:0] stor_line_len, stor_byte,
    input logic [31:0] stor_file_size,
    output logic mem_en, mem_we,
    output logic [15:0] mem_addr,
    output logic [7:0] mem_wdata,
    input logic [7:0] mem_rdata,
    input logic mem_gnt
);
    typedef enum logic [4:0] {IDLE, DIR_START, DIR_WAIT, NEXT, NEXT_WAIT,
        READ, READ_WAIT, PAD, NAME, NAME_WAIT, NAME_WRITE, NAME_WRITE_WAIT, OPEN, OPEN_WAIT,
        ICON_BEGIN, ICON_SETTLE, GET, GET_WAIT, DELIVER, ICON_WAIT, CLOSE, CLOSE_WAIT} state_t;
    state_t state;
    logic [4:0] char_i;
    logic [7:0] line_n;
    logic [31:0] tail;
    logic keep_entry, doc_entry, cat_we;
    logic [2:0] suffix_kind;
    logic [11:0] cat_waddr, cat_raddr;
    logic [7:0] cat_wdata, cat_rdata;
    logic [7:0] icon_index_q;
    logic [3:0] name_i;
    logic [1:0] suffix_i;
    logic suffix;
    logic [7:0] name_char;
    logic opened;
    (* ram_style="distributed" *) logic [7:0] catalog [0:4095];
    assign cat_raddr = (state == NAME || state == NAME_WAIT) ?
                      {icon_index_q, name_i} : catalog_addr;
    always_ff @(posedge clk) begin
        if (cat_we) catalog[cat_waddr] <= cat_wdata;
        cat_rdata <= catalog[cat_raddr];
    end
    assign catalog_data = cat_rdata;
    assign busy = state != IDLE;
    logic stream_start, stream_error, stream_valid, stream_ready, stream_done, stream_fallback;
    logic [7:0] stream_data;
    logic [31:0] stream_size;
    jmr_icon_stream u_icon (
        .clk(clk),.rst(!rst_n),.start(stream_start),.file_size(stream_size),
        .src_error(stream_error),.src_valid(stream_valid),.src_ready(stream_ready),.src_data(stream_data),
        .pixel_valid(icon_valid),.pixel_ready(icon_ready),.pixel_x(icon_x),.pixel_y(icon_y),
        .pixel_rgb332(icon_colour),.pixel_opaque(icon_opaque),.busy(),.done(stream_done),.fallback(stream_fallback)
    );
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; done <= 0; count <= 0; disk_error <= 0;
            stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;stor_name_len<=0;
            mem_en<=0;mem_we<=0;mem_addr<=0;mem_wdata<=0;
            cat_we<=0;cat_waddr<=0;cat_wdata<=0;char_i<=0;line_n<=0;tail<=0;keep_entry<=0;doc_entry<=0;suffix_kind<=0;
            icon_index_q<=0;name_i<=0;suffix_i<=0;suffix<=0;name_char<=0;opened<=0;
            stream_start<=0;stream_error<=0;stream_valid<=0;stream_data<=0;stream_size<=0;
        end else begin
            done<=0;stor_open<=0;stor_close<=0;stor_dir<=0;stor_next<=0;stor_get<=0;
            mem_en<=0;mem_we<=0;cat_we<=0;stream_start<=0;stream_error<=0;
            case (state)
                IDLE: begin
                    if (catalog_go) begin count<=0;disk_error<=0;state<=DIR_START;end
                    else if (icon_go) begin
                        icon_index_q<=icon_index;name_i<=0;suffix<=0;suffix_i<=0;opened<=0;state<=NAME;
                    end
                end
                DIR_START: if (!stor_busy) begin stor_dir<=1;state<=DIR_WAIT;end
                DIR_WAIT: if (stor_done) begin
                    if (stor_err) begin disk_error<=1;done<=1;state<=IDLE;end
                    else state<=NEXT;
                end
                NEXT: if (!stor_busy) begin stor_next<=1;state<=NEXT_WAIT;end
                NEXT_WAIT: if (stor_done) begin
                    if (stor_err || stor_eof || count==256) begin
                        disk_error<=stor_err;done<=1;state<=IDLE;
                    end else begin char_i<=0;line_n<=stor_line_len;tail<=0;state<=READ;end
                end
                READ: begin
                    mem_en<=1;mem_addr<=16'hbb00+16'(char_i);state<=READ_WAIT;
                end
                READ_WAIT: if (mem_gnt) begin
                    cat_we<=1;cat_waddr<={count[7:0],char_i[3:0]};cat_wdata<=mem_rdata;
                    tail<={tail[23:0],mem_rdata};
                    char_i<=char_i+1'b1;
                    if (char_i+1 >= line_n || char_i==12) begin
                        doc_entry<=!({tail[23:0],mem_rdata}==32'h2e48544d || {tail[15:0],mem_rdata}==24'h2e4a53);
                        case({tail[23:0],mem_rdata})
                            32'h2e41524a:suffix_kind<=1;
                            32'h2e415254:suffix_kind<=2;
                            32'h2e49434e:suffix_kind<=3;
                            default:suffix_kind<=0;
                        endcase
                        keep_entry<=(show_hidden || {tail[23:0],mem_rdata}==32'h2e48544d ||
                                     {tail[15:0],mem_rdata}==24'h2e4a53 ||
                                     {tail[15:0],mem_rdata}==24'h2e4d44 ||
                                     {tail[23:0],mem_rdata}==32'h2e545854);
                        state<=PAD;
                    end else state<=READ;
                end
                PAD: begin
                    cat_we<=1;cat_waddr<={count[7:0],char_i[3:0]};cat_wdata<=(char_i==15)?{4'd0,suffix_kind,doc_entry}:8'd0;
                    if (char_i==15) begin
                        if (keep_entry) count<=count+1'b1;
                        state<=NEXT;
                    end else char_i<=char_i+1'b1;
                end
                NAME: state<=NAME_WAIT;
                NAME_WAIT: begin
                    if (!suffix && cat_rdata!=0 && cat_rdata!="." && name_i<8) name_char<=cat_rdata;
                    else begin
                        suffix<=1;
                        case (suffix_i)
                            0:name_char<=".";
                            1:name_char<="I";
                            2:name_char<="C";
                            default:name_char<="N";
                        endcase
                    end
                    state<=NAME_WRITE;
                end
                NAME_WRITE: begin
                    mem_en<=1;mem_we<=1;mem_addr<=16'hb850+16'(name_i);mem_wdata<=name_char;
                    state<=NAME_WRITE_WAIT;
                end
                NAME_WRITE_WAIT: if (mem_gnt) begin
                        name_i<=name_i+1'b1;
                        if (suffix && suffix_i==3) begin stor_name_len<={4'd0,name_i}+1'b1;state<=OPEN;end
                        else begin if(suffix)suffix_i<=suffix_i+1'b1;state<=NAME;end
                end
                OPEN: if (!stor_busy) begin stor_open<=1;state<=OPEN_WAIT;end
                OPEN_WAIT: if (stor_done) begin
                    opened<=!stor_err;
                    stream_size<=stor_err ? 32'd0 : stor_file_size;
                    state<=ICON_BEGIN;
                end
                ICON_BEGIN: begin stream_start<=1;state<=ICON_SETTLE;end
                ICON_SETTLE: state<=GET;
                GET: begin
                    if (stream_fallback) state<=ICON_WAIT;
                    else if (stream_ready && !stor_busy) begin stor_get<=1;state<=GET_WAIT;end
                end
                GET_WAIT: if (stor_done) begin
                    if (stor_err || stor_eof) begin stream_error<=1;state<=ICON_WAIT;end
                    else begin stream_data<=stor_byte;stream_valid<=1;state<=DELIVER;end
                end
                DELIVER: if (stream_valid && stream_ready) begin stream_valid<=0;state<=GET;end
                ICON_WAIT: if (stream_done) state<=CLOSE;
                CLOSE: if (!opened) begin done<=1;state<=IDLE;end
                       else if (!stor_busy) begin stor_close<=1;state<=CLOSE_WAIT;end
                CLOSE_WAIT: if (stor_done) begin done<=1;state<=IDLE;end
                default: state<=IDLE;
            endcase
            // The last pixel can complete while GET waits for the next byte.
            if (stream_done && (state==GET || state==DELIVER)) begin stream_valid<=0;state<=CLOSE;end
        end
    end
endmodule
