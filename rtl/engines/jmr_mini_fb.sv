// Mini canvas 640×480×8 — SINGLE persistent draw bank (BRAM) + DDR3 front.
//
// JS canvas is a persistent surface; the old two-bank ping-pong emulated it
// with fb_swap + a 307k-cycle S_FB_SYNC copy-back after every present. Now
// the draw bank never flips: present = stream this bank into the DDR3 front
// image (jmr_fb_present in jmr_js_core), scanout = DDR3 line prefetch
// (jmr_fb_scanout). One bank = 75 BRAM tiles (was 150); S_FB_SYNC is gone.
//
//   Port A (wr_clk): ONE address — write-priority mux of draw writes and
//                    dump/tether reads (unchanged discipline: dump data is
//                    registered one beat behind dump_raddr).
//   Port B (wr_clk): present-copy read — sequential, core clock. The old
//                    pixel-clock scanout port moved to jmr_fb_scanout.
module jmr_mini_fb (
    input  logic        wr_clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic        address_we, // raw writer owns address even if scissor suppresses write
    input  logic [18:0] waddr,
    input  logic [7:0]  wdata,
    input  logic        dirty_clear,
    output logic [1199:0] dirty_blocks,
    // present-copy read port (core clk, sequential)
    input  logic [18:0] copy_raddr,
    output logic [7:0]  copy_rdata,
    // tether/IMGD dump port (core clk) — shares Port A with writes
    input  logic [18:0] dump_raddr,
    output logic [7:0]  dump_rdata
);
    // Seventy-five 4-KiB banks retain the exact persistent canvas capacity.
    // Register the one-hot selection beside the synchronous memory read,
    // then combine bank outputs in three balanced LUT-sized levels.
    localparam int BANKS = 75;

    function automatic logic [6:0] read_bank(input logic [18:0] a);
        if (a < 19'd262144)      return {1'b0,a[17:12]};
        if (a < 19'd294912)      return 7'd64 + {4'd0,a[14:12]};
        if (a < 19'd303104)      return 7'd72 + {6'd0,a[12]};
        return 7'd74;
    endfunction
    wire [18:0] a0 = address_we ? waddr : dump_raddr;
    (* keep = "true" *) logic [BANKS-1:0] a_bank_q,b_bank_q;
    logic [7:0] a_data[0:BANKS-1],b_data[0:BANKS-1];
    always_ff @(posedge wr_clk) begin
        a_bank_q <= 75'b1 << read_bank(a0);
        b_bank_q <= 75'b1 << read_bank(copy_raddr);
    end
    for(genvar bank=0;bank<BANKS;bank=bank+1)begin: g_bank
        (* ram_style = "block" *) logic [7:0] mem[0:4095] /*verilator public_flat_rd*/;
        wire bank_we;
        // Direct bank-local write decoding preserves the old write path;
        // read-side balancing must not insert another address mux into WEA.
        // Build 96: decode the bank from waddr, not a0. The core drives
        // we only with address_we (fb_we implies fb_raw_we), where a0 IS
        // waddr, so this drops the a0 mux from the WEA cone only.
        if(bank<64)begin: g_c0
            assign bank_we=we && waddr<19'd262144 && waddr[17:12]==6'(bank);
        end else if(bank<72)begin: g_c1
            assign bank_we=we && waddr>=19'd262144 && waddr<19'd294912 && waddr[14:12]==3'(bank-64);
        end else if(bank<74)begin: g_c2
            assign bank_we=we && waddr>=19'd294912 && waddr<19'd303104 && waddr[12]==1'(bank-72);
        end else begin: g_c3
            assign bank_we=we && waddr>=19'd303104 && waddr<19'd307200;
        end
        always_ff @(posedge wr_clk) begin
            if(bank_we)
                mem[a0[11:0]] <= wdata;
            a_data[bank] <= mem[a0[11:0]];
            b_data[bank] <= mem[copy_raddr[11:0]];
        end
    end
    // Preserve these two combinational boundaries: each first-stage bit is
    // exactly one six-input LUT; the two following ORs each fit one LUT.
    // Flattening them rebuilt a five-level, long-wire mux in the routed chip.
    (* keep = "true", dont_touch = "true" *) wire [7:0] a_first[0:24],b_first[0:24];
    for(genvar g=0;g<25;g=g+1)begin: g_first
        assign a_first[g] = (a_data[3*g] & {8{a_bank_q[3*g]}}) |
                            (a_data[3*g+1] & {8{a_bank_q[3*g+1]}}) |
                            (a_data[3*g+2] & {8{a_bank_q[3*g+2]}});
        assign b_first[g] = (b_data[3*g] & {8{b_bank_q[3*g]}}) |
                            (b_data[3*g+1] & {8{b_bank_q[3*g+1]}}) |
                            (b_data[3*g+2] & {8{b_bank_q[3*g+2]}});
    end
    (* keep = "true", dont_touch = "true" *) wire [7:0] a_second[0:4],b_second[0:4];
    for(genvar g=0;g<5;g=g+1)begin: g_second
        assign a_second[g] = a_first[5*g] | a_first[5*g+1] | a_first[5*g+2] | a_first[5*g+3] | a_first[5*g+4];
        assign b_second[g] = b_first[5*g] | b_first[5*g+1] | b_first[5*g+2] | b_first[5*g+3] | b_first[5*g+4];
    end
    assign dump_rdata = a_second[0] | a_second[1] | a_second[2] | a_second[3] | a_second[4];
    assign copy_rdata = b_second[0] | b_second[1] | b_second[2] | b_second[3] | b_second[4];

    // Read-first Port A already returns the old byte of a draw write.
    // Pipeline the selected old byte, comparison and 256-byte block mark,
    // updating only when contents changed. No additional framebuffer port or
    // image copy is introduced. The first present always transfers all.
    // Build 96: the old byte is captured after the FIRST mux level (25
    // group registers beside the banks) instead of after the full 75-bank
    // mux: the bank output no longer crosses the chip in one clock. The
    // remaining two OR levels join the byte compare in the next stage, so
    // the mark still lands three clocks after the write (jmr_fb_present
    // waits four).
    logic dirty_we_q;
    logic [18:0] dirty_addr_q;
    logic [7:0] dirty_data_q;
    logic [7:0] dirty_new_q;
    logic [7:0] dirty_first_q[0:24];
    logic [7:0] dirty_old;
    logic dirty_compare_q;
    logic [10:0] dirty_compare_block_q;
    logic dirty_changed_q;
    logic [10:0] dirty_block_q;
    always_ff @(posedge wr_clk)
        for (int g = 0; g < 25; g++) dirty_first_q[g] <= a_first[g];
    always_comb begin
        dirty_old = 8'd0;
        for (int g = 0; g < 25; g++) dirty_old = dirty_old | dirty_first_q[g];
    end
    always_ff @(posedge wr_clk) begin
        if (!rst_n) begin
            dirty_blocks <= '1;
            dirty_we_q <= 1'b0;
            dirty_changed_q <= 1'b0;
            dirty_compare_q <= 1'b0;
        end else begin
            dirty_we_q <= we;
            dirty_addr_q <= waddr;
            dirty_data_q <= wdata;
            // Keep bank selection, byte comparison and block decoding in
            // separate stages, each with an ordinary 100 MHz requirement.
            dirty_new_q <= dirty_data_q;
            dirty_compare_q <= dirty_we_q && dirty_addr_q < 19'd307200;
            dirty_compare_block_q <= dirty_addr_q[18:8];
            dirty_changed_q <= dirty_compare_q && dirty_old != dirty_new_q;
            dirty_block_q <= dirty_compare_block_q;
            if (dirty_clear) dirty_blocks <= '0;
            if (dirty_changed_q) dirty_blocks[dirty_block_q] <= 1'b1;
        end
    end

endmodule
