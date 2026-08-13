// Set-2 scancode → ASCII (letters/digits/punctuation/CR/BS). Feeds keyboard_fifo.
// Map matches hardware_model/ps2_keyboard.py _SET2_ASCII (USB HID via Digilent PIC24).
module ps2_decode (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] scancode,
    input  logic       strobe,
    output logic [7:0] ascii,
    output logic       ascii_strobe
);
    logic shift, brk, ext;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift <= 1'b0;
            brk <= 1'b0;
            ext <= 1'b0;
            ascii <= 8'h00;
            ascii_strobe <= 1'b0;
        end else begin
            ascii_strobe <= 1'b0;
            if (strobe) begin
                if (scancode == 8'hE0) begin
                    ext <= 1'b1;
                end else if (scancode == 8'hF0) begin
                    brk <= 1'b1;
                end else begin
                    if (scancode == 8'h12 || scancode == 8'h59) begin
                        shift <= ~brk;
                    end else if (!brk && ext) begin
                        // NEW V1.6: arrow keys → private FIFO bytes for EDIT
                        unique case (scancode)
                            8'h6B: begin ascii <= 8'h11; ascii_strobe <= 1'b1; end // LEFT
                            8'h74: begin ascii <= 8'h12; ascii_strobe <= 1'b1; end // RIGHT
                            // Up/Down ignored (EDIT is single-line)
                            default: ;
                        endcase
                    end else if (!brk && !ext) begin
                        unique case (scancode)
                            8'h1C: ascii <= shift ? "A" : "a";
                            8'h32: ascii <= shift ? "B" : "b";
                            8'h21: ascii <= shift ? "C" : "c";
                            8'h23: ascii <= shift ? "D" : "d";
                            8'h24: ascii <= shift ? "E" : "e";
                            8'h2B: ascii <= shift ? "F" : "f";
                            8'h34: ascii <= shift ? "G" : "g";
                            8'h33: ascii <= shift ? "H" : "h";
                            8'h43: ascii <= shift ? "I" : "i";
                            8'h3B: ascii <= shift ? "J" : "j";
                            8'h42: ascii <= shift ? "K" : "k";
                            8'h4B: ascii <= shift ? "L" : "l";
                            8'h3A: ascii <= shift ? "M" : "m";
                            8'h31: ascii <= shift ? "N" : "n";
                            8'h44: ascii <= shift ? "O" : "o";
                            8'h4D: ascii <= shift ? "P" : "p";
                            8'h15: ascii <= shift ? "Q" : "q";
                            8'h2D: ascii <= shift ? "R" : "r";
                            8'h1B: ascii <= shift ? "S" : "s";
                            8'h2C: ascii <= shift ? "T" : "t";
                            8'h3C: ascii <= shift ? "U" : "u";
                            8'h2A: ascii <= shift ? "V" : "v";
                            8'h1D: ascii <= shift ? "W" : "w";
                            8'h22: ascii <= shift ? "X" : "x";
                            8'h35: ascii <= shift ? "Y" : "y";
                            8'h1A: ascii <= shift ? "Z" : "z";
                            8'h16: ascii <= shift ? "!" : "1";
                            8'h1E: ascii <= shift ? "@" : "2";
                            8'h26: ascii <= shift ? "#" : "3";
                            8'h25: ascii <= shift ? "$" : "4";
                            8'h2E: ascii <= shift ? "%" : "5";
                            8'h36: ascii <= shift ? "^" : "6";
                            8'h3D: ascii <= shift ? "&" : "7";
                            8'h3E: ascii <= shift ? "*" : "8";
                            8'h46: ascii <= shift ? "(" : "9";
                            8'h45: ascii <= shift ? ")" : "0";
                            8'h5A: ascii <= 8'h0D; // Enter
                            8'h66: ascii <= 8'h08; // Backspace
                            8'h29: ascii <= " ";
                            8'h76: ascii <= 8'h1B; // Esc
                            // NEW: punctuation — required for decimals (.8),
                            // strings ("…"), LOAD/SAVE names, expressions.
                            // These scancodes are all >= 0x15, so the existing
                            // strobe condition below already pulses for them;
                            // they were dead only because ascii defaulted to 0.
                            8'h4E: ascii <= shift ? "_" : "-";
                            8'h55: ascii <= shift ? "+" : "=";
                            8'h54: ascii <= shift ? "{" : "[";
                            8'h5B: ascii <= shift ? "}" : "]";
                            8'h5D: ascii <= shift ? "|" : "\\";
                            8'h4C: ascii <= shift ? ":" : ";";
                            8'h52: ascii <= shift ? "\"" : "'";
                            8'h41: ascii <= shift ? "<" : ",";
                            8'h49: ascii <= shift ? ">" : ".";
                            8'h4A: ascii <= shift ? "?" : "/";
                            default: ascii <= 8'h00;
                        endcase
                        if (scancode != 8'h12 && scancode != 8'h59)
                            // Pulse for mapped keys (do not read ascii — NBA still stale here)
                            ascii_strobe <= (scancode == 8'h5A) || (scancode == 8'h66) ||
                                (scancode == 8'h29) || (scancode == 8'h76) ||
                                (scancode >= 8'h15 && scancode != 8'hE0 && scancode != 8'hF0);

                    end
                    brk <= 1'b0;
                    ext <= 1'b0;
                end
            end
        end
    end
endmodule
