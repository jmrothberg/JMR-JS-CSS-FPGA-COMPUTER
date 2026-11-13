// The Toolbox bank's final word (8191), which the ROM loader does not write.
// tools/toolbox_linker.py pads every ROM with this JUMP. The bank itself starts
// empty and is filled from the card's TOOLBOX.ROM at boot.
package jmr_toolbox_rom_pkg;
localparam logic [31:0] PADDING=32'h0020000b;
endpackage
