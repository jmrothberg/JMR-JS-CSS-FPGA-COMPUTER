# Re-render prompt — `jmr_js_core_zoom_in.png`

Paste the block below into ChatGPT (image generation) to re-render the
**JMR JS Processor Core — Zoom-In** poster. It folds in every item from the
"Core zoom-in poster errata" section of [ARCHITECTURE.md](ARCHITECTURE.md)
**plus** the drift found since the 2026-08-18 render (exec32 deletion, native
id 41, the I2C gamepad, the MIG/DDR3 asset port, the on-chip shrinks).

Every number below was read out of the tree, not from the old poster:
`rtl/engines/jmr_js_vm_pkg.sv`, `rtl/engines/jmr_value.sv`,
`rtl/engines/jmr_js_vm.sv`, `rtl/jmr_js_core.sv`, `rtl/top_nexys_video.sv`,
`rtl/phys/jmr_i2c_joy.sv`, `functional_model/jsb_format.py`.

After a good render lands, delete the corrected bullets from the errata
section in ARCHITECTURE.md — the errata exists only to out-vote the image.

---

## The prompt

````text
Render a single-page technical wall poster, landscape 4:3, high resolution,
titled "JMR JS PROCESSOR CORE — ZOOM-IN".

STYLE
- Clean engineering-poster look: white/near-white background, thin dark-navy
  rules, numbered rounded-rectangle blocks with pale tinted fills (blue,
  amber, teal, green), crisp sans-serif type, generous white space.
- Sibling to a classic "computer architecture wall chart": boxes, buses,
  arrows, small tables. Not painterly, not 3D, no photographic texture.
- Every label must be readable at 100% zoom. Prefer fewer words at larger
  size over cramming.

TEXT RULES — THESE ARE THE POINT OF THIS RENDER
The previous render of this poster was ruined by garbled fine print. So:
- Reproduce every quoted string EXACTLY, character for character, including
  underscores, brackets, dots, hex digits, "×", "→", and case.
- Do NOT invent, translate, abbreviate, pluralize, or "correct" any label.
- Do NOT repeat a word ("Never never"), and do NOT merge two list items into
  one line.
- If a string will not fit, shrink the type or enlarge the box. Never trim
  characters and never substitute a similar-looking word.
- Identifiers that must survive intact: exec64, Value64, JSB1, ASET, .HTML,
  .JSH, .JSB, MAX_OBJ, ENV_DEPTH, rAF, IS61WV204816, XC7A200T, 0x7FF9.

TOP BANNER
Title: "JMR JS PROCESSOR CORE — ZOOM-IN"
Subtitle: "HTML/JS-NATIVE CPU  •  JMR-JS BYTECODE IS THE INSTRUCTION SET"
Ribbon under the subtitle, single line:
"Parent SRAM owns the heap. One decoder: exec64. Extra clocks are silicon."

LAYOUT
Nine numbered blocks. Top row left-to-right: 1, 2, 3, 4, 5, 6. Middle band:
block 7 spanning the centre. Bottom row: block 8 (wide, left) and block 9
(right). A legend and a footer bar run along the very bottom.

BLOCK 1 — "PROGRAM SEQUENCER", small caption "Fetch Unit"
Stacked bars:
- "IP 16-bit"
- "32-bit op word"
- "Code BRAM 32K × 32"
- "Dual-port: VM read / loader write"
- "op = { arg1[31:24], arg0[23:8], opcode[7:0] }"
Below, an inset box headed "Magic JSB1 in RAM":
- "magic[4] = \"JSB1\""
- "n_ops u16  •  n_consts u16"
- "n_vars u16  •  flags u16"
- "if flags.ASET: aset_byte_off u32"
- "consts[] then ops[]"
- "CODE → code BRAM"
- "ASET → external 4 MB asset bank"
- "flags: v2 • ASET • source map • Value64"

BLOCK 2 — "DISPATCH", caption "Opcode → Engine"
Top note, two lines:
"ONE decoder: exec64."
"Every ProgramImage is Value64. flags[3]=0 → machine fault code 9."
(There is no exec32. Do NOT draw a second decoder, a mux, or the words
"exec32", "two decoders", or "not two CPUs" anywhere on this poster.)
Small two-column table, headers "opcode" and "mnemonic":
  "01" / "LOAD_CONST"
  "0D" / "CALL  (native id in arg0)"
  "1A" / "MAKE_OBJ"
  "21" / "MAKE_FN"
  "…"  / "…"
Footnote under the table, exactly:
"0D CALL is RTL OP_CALL = FM CALL_NATIVE — one instruction, two names."
Bottom sub-box:
"34 opcodes"
"arithmetic • compare • jump"
"arrays • objects • closures"

BLOCK 3 — "EVAL STACK"
Left: a vertical stack graphic with "TOS" arrow at the top.
Right, stacked bars:
- "SRAM 2048 deep"
- "1 write + 1–2 reads"
- "rdata next clock"
- "16 TOS window FFs (64-bit)"
- "Always Value64 — never tagged"
Tag sub-box headed "Value64 kinds (NaN-boxed, prefix 0x7FF9)":
- "undefined • null • bool • string"
- "object • array • function • element • env"
- "Numbers are IEEE-754 doubles — there is no int tag"
Two sibling boxes drawn INSIDE the eval-stack block, each captioned
"parent SRAM":
- "VARS 512"
- "CONSTS 1024"

BLOCK 4 — "OBJECT / HEAP"
Stacked bars:
- "MAX_OBJ = 1024 × 32 props"
- "Arrays = 1536×32 + 128×128"
- "ENV_DEPTH = 512"
- "Parent-owned 1-D SRAM"
- "Overflow is loud"
Sub-box headed "Handles / GC":
- "handle = { 0x7FF9, kind[3:0], generation[11:0], index[31:0] }"
- "mark / sweep at frame safe points"
- "stale generation is reported, never reused silently"
Sub-box:
- "MAKE_FN snapshots env"
- "Closures survive return"
- "setTimeout / rAF"

BLOCK 5 — "NATIVE CALL", caption "CALL id table"
Two-column table, headers "id" and "function":
  "0"  / "console.log"
  "2"  / "fillRect"
  "3"  / "swapBuffers"
  "10" / "Math.floor"
  "19" / "addEventListener"
  "27" / "requestAnimationFrame"
  "40" / "typeof"
  "41" / "Object.keys"
Footer strip under the table, two lines, exactly:
"42 native ids — the ABI is 0–41"
"41 Object.keys is PYTHON-first; silicon faults loud, never fakes it"

BLOCK 6 — "SHARED ENGINES", caption "never merged"
Eight small stacked boxes:
- "Expression / ALU"
- "Object / Heap"
- "Canvas 2D"  with fine print "fillRect • fillText (8×8 font ROM) • getImageData"
- "Blitter"     with fine print "drawImage streams 8-bpp from asset SRAM, 2 px / 16-bit word"
- "String"
- "Event / Timer / rAF"   (rAF = requestAnimationFrame — never write "IAF")
- "Console"     with fine print "READY • LOAD • RUN • DIR • EDIT"
- "Storage"     with fine print "µSD SPI FAT32"

BLOCK 7 — "COMPILE-ON-RUN" (wide, centred)
A left-to-right chain of three boxes joined by arrows:
"Lexer" → "Parser" → "Bytecode in RAM"
Large line beneath:
"LOAD \"NAME.HTML\"  →  EDIT (optional)  →  RUN"
Two smaller lines:
"RUN always compiles the current HTML"
"fresh in-memory ProgramImage"
Then:
"CODE → code BRAM        ASET → asset SRAM"
Four small footer boxes across the bottom of the block:
- "NAME.HTML is truth"
- "Line numbers = HTML"
- "Missing path → fail loud ?NH"
- "Never writes .JSH or .JSB to the card"

BLOCK 8 — "THREE ROOMS", caption "no fake 64K map" (wide, bottom left)
Three lettered sub-panels side by side.

A) "On-chip BRAM (~1 MB-class after FB)"
- "dual 640×480 framebuffers"
- "8-bpp indexed"
- "code BRAM 32K × 32"
- "JS heap"
- "256-entry RGB888 palette"
- "string / name heap 32 KB"
- "sprite scratch 32 KB"
- "microcode ROM"
- "FIFOs"
- "font ROM"
(microcode ROM and FIFOs are SEPARATE items — never one label.)
Highlighted note inside panel A:
"HDMI scans out FROM the on-chip FRONT framebuffer, never from asset SRAM."

B) "External 4 MB SRAM = ASET art only"
Draw a DIP/SOJ chip labelled "IS61WV204816" with "2M × 16" beneath it.
Port contract on one line:
"addr[20:0] • wdata[15:0] • rdata[15:0] • req • we • ack"
Address map, two rows:
- "0x000000–0x0002FF   palette, 256 × RGB888 = 768 B"
- "0x000300+           8-bpp sprite banks"
(Exactly six hex digits. No extra zeros.)
Notes:
- "FPGA: DDR3 through the MIG behind this same port"
- "FPGA-SIM: model behind the same port"
- "ASET art only — not the JS heap"
- "HDMI does not scan from here"
Green call-out at the bottom of panel B, two lines:
"Blitter reads pixels here."
"Pixels never enter code BRAM."

C) "µSD FAT32"
- "NAME.HTML titles only"
- "No compile cache"
- "No .JSH / .JSB on disk"
Small microSD card icon.

BLOCK 9 — "I/O" (bottom right)
Three rows, each with a simple line-art icon:
- Keyboard icon: "USB HOST (J15) → PIC24 → PS/2", "Pmod PS/2 on JA as fallback",
  "raw keycodes → INPUT FIFO — the HTML binds the keys"
- Gamepad icon: "Mini I2C gamepad @ 0x5A on Pmod JB", "SCL = JB1, SDA = JB2",
  "left / up / down / right / fire A-C / fire B-D"
- Monitor icon: "HDMI 640×480 from the on-chip front framebuffer",
  "palette → RGB888"

LEGEND (bottom centre), three keyed lines:
- solid black arrow — "Control / Address Flow"
- solid blue arrow — "Data Flow"
- dashed blue arrow — "Compile / Load Path"

FOOTER BAR (full width, dark navy, reversed type)
Left, large: "SIMPLE. DIRECT. NATIVE. JAVASCRIPT IN — PIXELS OUT."
Right, two lines: "FPGA: Nexys Video XC7A200T" / "Core clock ~30 MHz (MIG ui_clk)"

DO NOT PLACE ANYWHERE ON THIS POSTER
- "exec32", any decoder mux, or "two opcode decoders"
- "Value64 when flags[3]" (Value64 is unconditional now)
- "IAF" (the engine is rAF)
- "~30 mm²" (that is the ASIC die target and belongs on the ASIC board
  poster, not in an on-chip BRAM box)
- "NAME.DAT", "NAME.FMT", ".JSlf", "rge", "Never never"
- an "int" tag in the Value64 kind list
````

---

## What changed vs. the 2026-08-18 render

| # | Item | Old poster | Correct now | Source |
|---|---|---|---|---|
| 1 | Dispatch | `exec32 \| exec64` mux on `flags[3]`; "two opcode decoders … not two CPUs" | one decoder, `exec64`; non-Value64 image faults **code 9** at `S_GOT_HDR2` | `jmr_js_vm.sv:6035`, [REMOVING_EXEC32.md](REMOVING_EXEC32.md) |
| 2 | Eval stack | "Value64 when flags[3]" | always Value64 | same |
| 3 | Tag strip | `int / obj / arr / str / fn / undef / elem` | 9 kinds: `undefined null bool string object array function element env`, NaN-boxed under prefix `0x7FF9`; Numbers are IEEE-754, no `int` tag | `jmr_value.sv:7-19` |
| 4 | Handles | "handle = generation + index" | `{0x7FF9, kind[3:0], generation[11:0], index[31:0]}` | `jmr_value.sv:118-124` |
| 5 | Native ids | "~40 native IDs" | 42 ids, ABI **0–41**; 40 `typeof`, 41 `Object.keys` (PYTHON-first, RTL faults loud) | `jsb_format.py:33-90` |
| 6 | `0D CALL` | unannotated | RTL `OP_CALL` = FM `CALL_NATIVE`; 34 opcodes (1–34) | `jmr_js_vm_pkg.sv:4-37` |
| 7 | Joystick | "Pmod joystick (6-bit)" | Mini **I2C** gamepad @ `0x5A` on Pmod **JB** (SCL=JB1, SDA=JB2), 6 buttons | `rtl/phys/jmr_i2c_joy.sv`, `top_nexys_video.sv:31-33` |
| 8 | Keyboard | "USB / PS2 keyboard" | USB HOST J15 → PIC24 → PS/2, Pmod PS/2 on **JA** as fallback | [FPGA_BRINGUP.md](FPGA_BRINGUP.md) |
| 9 | Asset port | "FPGA = DDR3 behind this port" | keep, and say core clock **is** the MIG `ui_clk` | `top_nexys_video.sv:88` |
| 10 | On-chip list | "microcode ROM FIFOs" jammed | separate items; add string/name heap **32 KB** and sprite scratch **32 KB** (was 256 KB) | `jmr_js_vm.sv:566,978`, [FPGA_FIT.md](FPGA_FIT.md) |
| 11 | `~30 mm²` | inside the on-chip BRAM box | that is the whole ASIC die — drop it from this poster | errata |
| 12 | `LOAD → EDIT → RUN` | EDIT looked mandatory | EDIT is optional | errata |
| 13 | VARS / CONSTS | ambiguous | sibling **parent SRAMs**, drawn inside the eval-stack box | errata |
| 14 | SRAM contract | partial | `addr[20:0] • wdata[15:0] • rdata[15:0] • req • we • ack` | `jmr_js_core.sv:94-99` |
| 15 | Asset map | extra zeros in hex | `0x000000–0x0002FF` palette 768 B; `0x000300+` sprite banks | `jsb_format.py:115` |
