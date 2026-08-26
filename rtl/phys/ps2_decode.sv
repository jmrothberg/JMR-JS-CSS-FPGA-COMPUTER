// One file on disk: JS board .bit AND tools/pmod_input_test compile this path.
// FPGA-SIM does not (CORE_SRCS). Edit here = next board_flow bit + pmod LED bit.
// Set-2 scancode → ASCII (letters/digits/punctuation/CR/BS). Feeds keyboard_fifo.
// Map matches hardware_model/ps2_keyboard.py _SET2_ASCII (USB HID via Digilent PIC24).
module ps2_decode (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] scancode,
    input  logic       strobe,
    output logic [7:0] ascii,
    output logic       ascii_strobe,
    // 2026-08-25: browser-keyCode game events (make AND break, so held
    // keys work). PACMAN on glass would not steer: the games' keydown
    // listeners match browser keyCodes (37-40 arrows...), which only the
    // GUI tether ever produced - the PS/2 path fed typing ASCII alone
    // and the core's key_evt ports sat at their 1'b0 defaults.
    output logic [7:0] kev_code,
    output logic       kev_down,
    output logic       kev_stb
);
    logic shift, brk, ext;

    // scancode+ext -> browser keyCode (0 = unmapped)
    function automatic logic [7:0] kmap(input logic [7:0] sc, input logic e);
        logic [7:0] k;
        k = 8'd0;
        // Dedicated arrows are E0+6B/75/74/72. Some PS/2 / PIC24 HID
        // translators drop E0 (and numpad 4/8/6/2 with NumLock off is the
        // same make), so those four codes are arrows with OR without ext.
        if (sc == 8'h6B) k = 8'd37;
        else if (sc == 8'h75) k = 8'd38;
        else if (sc == 8'h74) k = 8'd39;
        else if (sc == 8'h72) k = 8'd40;
        else if (!e) begin
            unique case (sc)
                8'h29: k = 8'd32; // Space
                8'h5A: k = 8'd13; // Enter
                8'h1C: k = 8'd65; 8'h32: k = 8'd66; 8'h21: k = 8'd67; // A B C
                8'h23: k = 8'd68; 8'h24: k = 8'd69; 8'h2B: k = 8'd70; // D E F
                8'h34: k = 8'd71; 8'h33: k = 8'd72; 8'h43: k = 8'd73; // G H I
                8'h3B: k = 8'd74; 8'h42: k = 8'd75; 8'h4B: k = 8'd76; // J K L
                8'h3A: k = 8'd77; 8'h31: k = 8'd78; 8'h44: k = 8'd79; // M N O
                8'h4D: k = 8'd80; 8'h15: k = 8'd81; 8'h2D: k = 8'd82; // P Q R
                8'h1B: k = 8'd83; 8'h2C: k = 8'd84; 8'h3C: k = 8'd85; // S T U
                8'h2A: k = 8'd86; 8'h1D: k = 8'd87; 8'h22: k = 8'd88; // V W X
                8'h35: k = 8'd89; 8'h1A: k = 8'd90;                   // Y Z
                8'h45: k = 8'd48; 8'h16: k = 8'd49; 8'h1E: k = 8'd50; // 0 1 2
                8'h26: k = 8'd51; 8'h25: k = 8'd52; 8'h2E: k = 8'd53; // 3 4 5
                8'h36: k = 8'd54; 8'h3D: k = 8'd55; 8'h3E: k = 8'd56; // 6 7 8
                8'h46: k = 8'd57;                                     // 9
                default: k = 8'd0;
            endcase
        end
        kmap = k;
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift <= 1'b0;
            brk <= 1'b0;
            ext <= 1'b0;
            ascii <= 8'h00;
            ascii_strobe <= 1'b0;
            kev_code <= 8'h00;
            kev_down <= 1'b0;
            kev_stb  <= 1'b0;
        end else begin
            ascii_strobe <= 1'b0;
            kev_stb <= 1'b0;
            if (strobe) begin
                if (scancode == 8'hE0) begin
                    ext <= 1'b1;
                end else if (scancode == 8'hF0) begin
                    brk <= 1'b1;
                end else begin
                    // game event: every make/break of a mapped key
                    if (kmap(scancode, ext) != 8'd0) begin
                        kev_code <= kmap(scancode, ext);
                        kev_down <= ~brk;
                        kev_stb  <= 1'b1;
                    end
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
