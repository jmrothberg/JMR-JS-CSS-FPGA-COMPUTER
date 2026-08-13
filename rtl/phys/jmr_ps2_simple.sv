// Minimal PS/2 byte → ASCII (subset). Pattern cite: BASIC ps2_rx/ps2_decode.
// Make codes only; ignores breaks. Enough for READY typing on Nexys Video HID.
module jmr_ps2_simple (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    output logic       strobe,
    output logic [7:0] ascii
);
    // Synchronize PS/2 clock
    logic [2:0] clk_sync;
    logic [10:0] shift;
    logic [3:0]  bit_cnt;
    logic        seeing_break;

    always_ff @(posedge clk) begin
        if (!rst_n) clk_sync <= 3'b111;
        else clk_sync <= {clk_sync[1:0], ps2_clk};
    end
    wire fall = clk_sync[2] & ~clk_sync[1];

    function automatic logic [7:0] map_scancode(input logic [7:0] s);
        case (s)
            8'h1C: map_scancode = "A"; 8'h32: map_scancode = "B"; 8'h21: map_scancode = "C";
            8'h23: map_scancode = "D"; 8'h24: map_scancode = "E"; 8'h2B: map_scancode = "F";
            8'h34: map_scancode = "G"; 8'h33: map_scancode = "H"; 8'h43: map_scancode = "I";
            8'h3B: map_scancode = "J"; 8'h42: map_scancode = "K"; 8'h4B: map_scancode = "L";
            8'h3A: map_scancode = "M"; 8'h31: map_scancode = "N"; 8'h44: map_scancode = "O";
            8'h4D: map_scancode = "P"; 8'h15: map_scancode = "Q"; 8'h2D: map_scancode = "R";
            8'h1B: map_scancode = "S"; 8'h2C: map_scancode = "T"; 8'h3C: map_scancode = "U";
            8'h2A: map_scancode = "V"; 8'h1D: map_scancode = "W"; 8'h22: map_scancode = "X";
            8'h35: map_scancode = "Y"; 8'h1A: map_scancode = "Z";
            8'h45: map_scancode = "0"; 8'h16: map_scancode = "1"; 8'h1E: map_scancode = "2";
            8'h26: map_scancode = "3"; 8'h25: map_scancode = "4"; 8'h2E: map_scancode = "5";
            8'h36: map_scancode = "6"; 8'h3D: map_scancode = "7"; 8'h3E: map_scancode = "8";
            8'h46: map_scancode = "9";
            8'h29: map_scancode = " "; 8'h5A: map_scancode = 8'h0D; // Enter
            8'h66: map_scancode = 8'h08; // Backspace
            8'h76: map_scancode = 8'h1B; // Esc
            default: map_scancode = 8'h00;
        endcase
    endfunction

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            shift <= 0; bit_cnt <= 0; strobe <= 0; ascii <= 0; seeing_break <= 0;
        end else begin
            strobe <= 0;
            if (fall) begin
                shift <= {ps2_data, shift[10:1]};
                if (bit_cnt == 10) begin
                    bit_cnt <= 0;
                    if (shift[9:2] == 8'hF0) begin
                        seeing_break <= 1'b1;
                    end else if (seeing_break) begin
                        seeing_break <= 1'b0;
                    end else begin
                        ascii <= map_scancode(shift[9:2]);
                        if (map_scancode(shift[9:2]) != 8'h00)
                            strobe <= 1'b1;
                    end
                end else bit_cnt <= bit_cnt + 1'b1;
            end
        end
    end
endmodule
