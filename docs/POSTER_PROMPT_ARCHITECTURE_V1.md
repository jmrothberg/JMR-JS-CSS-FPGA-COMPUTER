# Re-render prompt — `jmr_js_architecture_v1.png`

Paste the block below into ChatGPT (image generation) to re-render the
**JMR JS Computer — Architecture V1** poster. It folds in all eight bullets
from the "Architecture V1 poster errata" section of
[ARCHITECTURE.md](ARCHITECTURE.md) **plus** the drift found since that
render — most importantly that **`.JSH` no longer exists anywhere**. The
current poster tells the `.JSH` story in five separate places; every one of
them is wrong.

Every figure below was read out of the tree, not from the old poster:
`rtl/engines/jmr_js_vm_pkg.sv`, `rtl/engines/jmr_value.sv`,
`rtl/engines/jmr_js_vm.sv`, `rtl/engines/jmr_console_engine.sv`,
`rtl/jmr_js_core.sv`, `rtl/top_nexys_video.sv`, `rtl/phys/jmr_i2c_joy.sv`,
`functional_model/jsb_format.py`, `storage/`.

Sibling prompt for the core zoom-in poster:
[POSTER_PROMPT_CORE_ZOOM_IN.md](POSTER_PROMPT_CORE_ZOOM_IN.md).

After a good render lands, delete the corrected bullets from the errata
section in ARCHITECTURE.md — the errata exists only to out-vote the image.

---

## The prompt

````text
Render a single-page technical wall poster, landscape 4:3, high resolution,
titled "JMR JS COMPUTER — Architecture V1".

STYLE
- Clean engineering-poster look: white background, thin dark-navy rules,
  rounded-rectangle panels with pale tinted fills and colored headers (blue,
  green, red, amber, teal), crisp sans-serif type, generous white space.
- Simple flat line-art icons only (PC tower, keyboard, joystick, monitor,
  microSD card, chip package, shield, gears). No 3D, no photographic
  texture, no painterly rendering.
- Every label must be readable at 100% zoom. Prefer fewer words at larger
  size over cramming.

TEXT RULES — THESE ARE THE POINT OF THIS RENDER
The previous render of this poster was ruined by garbled fine print. So:
- Reproduce every quoted string EXACTLY, character for character, including
  underscores, brackets, dots, hex digits, "×", "→", and case.
- Do NOT invent, translate, abbreviate, pluralize, or "correct" any label.
- Do NOT repeat a word ("Never never"), and do NOT merge two list items into
  one line. Do NOT split a word across a space ("SRA M").
- If a string will not fit, shrink the type or enlarge the panel. Never trim
  characters and never substitute a similar-looking word.
- Identifiers that must survive intact: JMR-JS, exec64, Value64, JSB1, ASET,
  NAME.HTML, ProgramImage, rAF, ?NH, IS61WV204816, XC7A200T-1SBG484C,
  rgb2dvi, FT245, PS/2.

TOP BANNER
Title: "JMR JS COMPUTER — Architecture V1"
Four subtitle lines, centred:
"JavaScript-native CPU  •  HTML5/Canvas games  •  Language IS the ISA (no soft CPU, no browser, no dukpy)"
"LOAD \"NAME.HTML\"  →  EDIT (optional)  →  RUN always compiles  →  ephemeral in-memory ProgramImage (JSB1)"
"Memory = on-chip BRAM working set + external 4 MB SRAM asset bank + µSD FAT32 disk"
"Nothing is ever written back to the card. There is no compile cache."
Pale amber ribbon below, two lines:
"The machine boots to a JS READY prompt (early-PC feel: HELP / DIR / LIST / EDIT / NEW / MEM / LOAD / SAVE / REMOVE / RUN / CLS)."
"JS source compiles to compact JMR-JS bytecode; Canvas drawing is hardware-accelerated. Chrome is for authoring only — it is never the machine."

LAYOUT
Top band, four panels left to right: "TWO MODES", "JS PROCESSOR CORE",
"COMPILE-ON-RUN", "EXTERNAL SRAM ASSET BANK (4 MB)".
Bottom band, four panels left to right: "MEMORY", "PROOF LADDER / F9 RUNTIMES",
"OUTPUT / PHY", and a full-width footer row of three numbered law cards.

PANEL — "TWO MODES"
Two sub-columns.
Left, headed "Tethered", with a PC-tower icon:
- "PC GUI via PROG FT245 tether (FT2232 channel A)"
- "mirrors the HDMI glass"
- "sends typing + play KEYBITS"
- "Debug mirror only — not the product path"
Right, headed "Standalone", with keyboard + joystick + microSD icons:
- "USB HOST keyboard (J15, PIC24 → PS/2)"
- "Pmod PS/2 on JA as fallback"
- "Mini I2C gamepad on Pmod JB"
- "HDMI monitor + µSD. No PC required."
Caption across the bottom of the panel:
"Same JS core / same INPUT FIFO either way."

PANEL — "JS PROCESSOR CORE"
Stacked boxes, top to bottom:
- "Program Sequencer / Micro-sequencer"
- "Dispatch: ONE decoder, exec64"
- "Microcode ROM (BRAM, architectural — the programmer never sees it)"
- "Lexer / Parser / Bytecode generator  (compile-on-RUN; shares hardware)"
Note line under those, exactly:
"Every ProgramImage is Value64. A non-Value64 image faults, code 9."
(There is no exec32 and no decoder mux. Do NOT draw a second decoder or
write the word "exec32" anywhere on this poster.)
Sub-box headed "Independent Hardware Engines (never merged)":
- "Expression / ALU  •  Object / Heap  •  String"
- "Canvas 2D  •  Blitter  •  Paint / Video (HDMI scanout)"
- "Event / Timer / rAF"
- "Keyboard / Console / INPUT  •  I2C Joystick"
- "Storage  •  Audio (later)"
(The engine is rAF = requestAnimationFrame. Never write "IAF".)
Bottom box: "Memory Arbiter" with fine print
"BRAM ports + external SRAM port"

PANEL — "COMPILE-ON-RUN"
A vertical flow of boxes joined by downward arrows:
"RESET"
→ "boot to the \"JMR JS READY\" prompt"
→ "LOAD \"NAME.HTML\" from µSD   (HTML is the ONLY user-typed file; editor line numbers = HTML)"
→ "EDIT (optional)"
→ "RUN: ALWAYS recompile the current HTML   (never reuse a stale image)"
→ "fresh ProgramImage IN RAM ONLY:  code section + ASET art section"
→ split into two side-by-side boxes: "CODE → code BRAM"  and  "ASET (palette + full-res sprite banks) → external SRAM asset bank"
→ "bytecode VM executes  (microcode drives engines)"
→ "Canvas → framebuffer → HDMI"   (spell it "framebuffer" — not "framebueffer")
→ "ESC hard-breaks any game back to READY"
Three red call-out boxes down the right edge of this panel:
- "Nothing is written back to the card. RUN recompiles every time."
- "Compile errors report line numbers from the loaded HTML"
- "Missing compile path → fail loud ?NH, never fake output"

PANEL — "EXTERNAL SRAM ASSET BANK (4 MB)"
(The heading is one word "SRAM" — never "SRA M".)
Box 1, headed "Contract":
- "2M × 16 SRAM — ISSI IS61WV204816"
- "behind ONE simple synchronous port:"
- "addr[20:0], wdata[15:0], rdata[15:0],"
- "we, req, ack — at core clock"
(The signal is "req". Never "rge".)
Box 2, headed "Same port, three implementations":
- "FPGA-SIM = behavioral 4 MB model"
- "FPGA board = Nexys Video DDR3 behind a MIG bridge (first 4 MB)"
- "ASIC / final PCB = the real SRAM chip"
Box 3:
- "The loader streams ASET → asset SRAM at offset 0; the palette block also loads into the on-chip palette BRAM."
Box 4, headed "4 MB map":
- "0x000000–0x0002FF   title palette (256 × RGB888 = 768 B)"
- "0x000300+           8-bpp indexed sprite banks"
- "top reserved"
(Exactly six hex digits on each address. No extra zeros.)
Box 5, green, headed "Art never enters code BRAM":
- "Bytecode holds handles only (w, h, SRAM offset)."
- "The blitter streams pixels straight from asset SRAM."
- "Pixels never enter code BRAM."
- "Never downscale or pack game art into code BRAM."

PANEL — "MEMORY", caption "three rooms — no fake 64K map"
Three lettered sub-panels side by side.
A) "On-chip BRAM working set"
- "dual framebuffer 640×480×8 (front / back, VBlank swap)"
- "code BRAM 32K × 32 (live bytecode)"
- "JS heap (objects / arrays / strings)"
- "editor / source buffer 64 KB"
- "string / name heap 32 KB"
- "sprite scratch 32 KB"
- "microcode ROM"
- "FIFOs"
- "256-entry RGB888 palette"
(microcode ROM and FIFOs are SEPARATE items — never one label.)
B) "External 4 MB SRAM asset bank"  with a chip icon
- "see the asset-bank panel"
- "game art at full quality"
C) "µSD FAT32 disk"  with a microSD icon
- "NAME.HTML user titles only"
- "INVADERS.HTML, PACMAN.HTML, DONKEY.HTML, MRDO.HTML, MK.HTML, … (sample)"
- "NO compile cache — nothing generated is ever stored"
Caption across the bottom of the panel:
"BRAM is RAM  •  µSD is disk  •  external SRAM is the asset bank."

PANEL — "PROOF LADDER / F9 RUNTIMES"
Four numbered rungs, each with a small icon:
1. "PYTHON bytecode VM"  fine print "(functional model = behavioral truth)"
2. "FPGA-SIM"            fine print "(real Verilator RTL — never a host twin)"
3. "BOARD"               fine print "(Nexys Video, Artix-7 XC7A200T, core clock ≈100 MHz = MIG ui_clk)"
4. "ASIC"                fine print "(~30 mm² die, custom padring, ~1 MB-class on-chip SRAM)"
Caption under the ladder, two lines:
"Same typed glass on every rung. The HTML decides the keys"
"(raw keycodes; game keydown/keyup handlers bind them — no hardcoded key maps in RTL)."

PANEL — "OUTPUT / PHY"
Four rows, each with a line-art icon:
- Monitor icon: "HDMI Source (J8): native 640×480 @ ~60 Hz, ~25.175 MHz pixel clock",
  "8-bpp indexed: 256 simultaneous colours from a 24-bit RGB888 palette, double-buffered",
  "scanout → Digilent rgb2dvi TMDS IP",
  "One glass: READY monitor = 64×16 text letterbox inside the same 640×480 field; RUN = full-field game framebuffer."
- Keyboard icon: "USB HOST keyboard (J15): PIC24 → PS/2 → keyboard PHY → INPUT FIFO",
  "Pmod PS/2 on JA as fallback"
- Gamepad icon: "Mini I2C gamepad @ 0x5A on Pmod JB (SCL = JB1, SDA = JB2)",
  "left / up / down / right / fire A-C / fire B-D → same INPUT FIFO"
- microSD icon: "µSD SPI / FAT32: HTML titles only"
- Cable icon: "PROG FT245 tether: flash + debug mirror + KEYBITS (debug only, not the product path)"
Small note at the bottom of this panel:
"This is the BOARD video path. On the ASIC, HDMI is parallel RGB out of the chip through an external transmitter. Neither path scans out of the asset SRAM."

FOOTER — three numbered law cards across the full width
1. Shield icon. "Language is the ISA: JavaScript → compact JMR-JS bytecode → microcoded engines. No Z80/6502/RISC-V soft CPU, no V8/dukpy/browser, ever."
2. Gears icon. "Same .HTML title must LOAD + RUN identically in PYTHON → FPGA-SIM → BOARD (then ASIC). Never fake a rung."
3. Chip icon. "V1 = Canvas game computer (no general CSS/browser engine). Board: Digilent Nexys Video, XC7A200T-1SBG484C."

DO NOT PLACE ANYWHERE ON THIS POSTER
- ".JSH" or ".JSB" in any form — no "fresh .JSH", no ".JSH container",
  no ".JSH compile cache", no "stale .JSH", no ".JSH cache" on the µSD row.
  The compile product is an ephemeral in-memory ProgramImage and is never
  written to the card.
- "exec32" or any decoder mux
- "IAF" (the engine is rAF)
- "rge" (the signal is req)
- "Never never" (say "Pixels never enter code BRAM")
- "NAME.DAT" (no such file exists)
- "SRA M" split across a space
- "Joystick GPIO" or "Pmod digital joystick → GPIO reader" (it is I2C)
- "QFN-100" (that is a Rev A package proposal and belongs on the ASIC
  board poster, not this one)
- extra zeros in the 4 MB map ("0x00000000", "0x0003000+")
````

---

## What changed vs. the current render

### The big one: `.JSH` is gone

The poster tells the `.JSH` story in five places. All five are wrong — RUN
compiles to an **ephemeral in-memory ProgramImage** and the card is never
written to (`ARCHITECTURE.md:223`, `:310`).

| Where on the poster | Says | Should say |
|---|---|---|
| Subtitle line 2 | "RUN always compiles → fresh .JSH (code + ASET art)" | "→ ephemeral in-memory ProgramImage (JSB1)" |
| Compile-on-RUN flow | "fresh internal .JSH container" | "fresh ProgramImage IN RAM ONLY" |
| Compile-on-RUN call-out | "Never prefer a stale .JSH — RUN recompiles every time" | "Nothing is written back to the card. RUN recompiles every time." |
| MEMORY panel C | "+ invisible .JSH compile cache (code + ASET in one file)" | "NO compile cache — nothing generated is ever stored" |
| OUTPUT / PHY | "µSD SPI / FAT32: HTML titles + .JSH cache" | "µSD SPI / FAT32: HTML titles only" |

### Everything else

| # | Item | Old poster | Correct now | Source |
|---|---|---|---|---|
| 1 | SRAM port | "we, rge, ack" | "we, req, ack" | `jmr_js_core.sv:94-99` |
| 2 | 4 MB map | `0x00000000` / `0x0003000+` | `0x000000–0x0002FF` / `0x000300+` | `jsb_format.py:115` |
| 3 | Engines | "Event / Timer / IAF" | "Event / Timer / rAF" | errata |
| 4 | Fail-loud | "fail loud (RUN), never fake output" | "fail loud **?NH**" | errata |
| 5 | Blitter note | "Never never enter code BRAM" + "NO NAME.DAT file" | "Pixels never enter code BRAM"; drop NAME.DAT | errata |
| 6 | On-chip list | "microcode ROM FIFOs" jammed | separate items | errata |
| 7 | HDMI PHY | unqualified | this is the **board** path; ASIC is parallel RGB via external transmitter | errata |
| 8 | ASIC rung | mixed with package | `~30 mm²` / padring / ~1 MB SRAM only; QFN-100 belongs on the ASIC board poster | errata |
| 9 | Asset panel title | "EXTERNAL SRA M ASET BANK" | "EXTERNAL SRAM ASSET BANK (4 MB)" | garbled render |
| 10 | Dispatch | "Dispatch Table" | "ONE decoder, exec64"; non-Value64 → fault code 9 | `jmr_js_vm.sv:6035` |
| 11 | Joystick | "Pmod digital joystick → GPIO reader", "Joystick GPIO" | Mini **I2C** gamepad @ `0x5A` on Pmod **JB** | `rtl/phys/jmr_i2c_joy.sv` |
| 12 | Keyboard | USB HOST only | add Pmod PS/2 on **JA** fallback | `FPGA_BRINGUP.md:131` |
| 13 | Console verbs | "DIR / LOAD / EDIT / RUN / ESC" | HELP, DIR, CLS, LIST, EDIT, MEM, NEW, RUN, LOAD, SAVE, REMOVE | `jmr_console_engine.sv:500-600` |
| 14 | On-chip sizes | unsized | code BRAM 32K×32, source buffer **64 KB**, string/name heap **32 KB**, sprite scratch **32 KB** | `jmr_console_engine.sv:97`, `jmr_js_vm.sv:566,978` |
| 15 | Board rung | "XC7A200T" | core clock **≈100 MHz = MIG `ui_clk`** (not an old 30 MHz wish) | `top_nexys_video.sv` `core_clk=ui_clk`, `mig_a.prj`, `FPGA_FIT.md` |
| 16 | Card titles | 3 named | 10 on the card — name a handful and mark it a sample | `storage/` |
