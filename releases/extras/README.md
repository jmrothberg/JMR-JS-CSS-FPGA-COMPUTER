# Optional porting example — not needed to load the FPGA

`portable_DNKFAST.zip` is a transport container. The FPGA does not load ZIP files. Your existing card and `.HTML` games work with run73o without this package.
Inside are a 43,847-byte `DNKFAST.HTML`, its separate artwork bank (`.ARTX`), browser-preview helper (`.ARTJS`), all six PNG sheets and `CHECK.json`. Moving embedded pictures out of the original 1,388,598-byte HTML made the HTML smaller; the pictures still take space separately. Unzipping itself does not shrink the game.
The compiled program and artwork were verified byte-for-byte identical. On-machine compilation of this rearranged source is not yet qualified; this is an optional preparation example, not a replacement for your working disk.
Use [tools/prepare_port.py](../../tools/prepare_port.py) to prepare other embedded-image programs in a new directory, and [tools/check_port.py](../../tools/check_port.py) to check size/API limits. No original game is overwritten.
