# Re-render prompt — `jmr_js_asic_board_rev_a.png`

Paste the block below into ChatGPT (image generation) to re-render the
**JMR JS ASIC — Rev A board** poster. It folds in all seven bullets from the
"ASIC board poster errata" section of [ARCHITECTURE.md](ARCHITECTURE.md)
**plus** the drift found since that render.

**One caveat worth knowing before you run it.** Unlike the other two
posters, this one is a *schematic* — a QFN pinout ring, a board net drawing,
and a pin-budget table. Image generators do not draw netlist-accurate
schematics; expect the block layout and all the prose to come back right and
the individual pin stubs to still be decorative. That is acceptable here:
the poster already declares pin numbers illustrative, and the authoritative
budget lives in the PIN SUMMARY table, which is prose the model can copy.
If a render mangles the QFN ring badly, keep the panels and redraw the ring
by hand rather than re-rolling the whole page.

Every figure below was read out of the tree or out of the Constitution-frozen
contract, not from the old poster: `functional_model/jsb_format.py`,
`rtl/engines/jmr_console_engine.sv`, `rtl/phys/jmr_i2c_joy.sv`,
[FPGA_BRINGUP.md](FPGA_BRINGUP.md), [ARCHITECTURE.md](ARCHITECTURE.md).

Sibling prompts:
[POSTER_PROMPT_ARCHITECTURE_V1.md](POSTER_PROMPT_ARCHITECTURE_V1.md) ·
[POSTER_PROMPT_CORE_ZOOM_IN.md](POSTER_PROMPT_CORE_ZOOM_IN.md).

After a good render lands, delete the corrected bullets from the errata
section in ARCHITECTURE.md — the errata exists only to out-vote the image.

---

## The prompt

````text
Render a single-page hardware datasheet / schematic wall poster, landscape
4:3, high resolution, for a custom ASIC and its carrier board.

STYLE
- Engineering datasheet look: white background, thin rules, boxed panels
  with colored headers, small crisp sans-serif type, a schematic net drawing
  in the lower half with colored signal lines and reference designators.
- Flat 2D line art only. No 3D renders, no photographic texture.
- Dense is fine; illegible is not. Every label must be readable at 100%
  zoom.

TEXT RULES — THESE ARE THE POINT OF THIS RENDER
The previous render of this poster was ruined by garbled fine print. So:
- Reproduce every quoted string EXACTLY, character for character, including
  part numbers, "#", "[", "]", "×", "→", "µ", and case.
- Do NOT invent, translate, abbreviate, or "correct" any label. Part numbers
  and pin names especially: copy them, do not regenerate them.
- If a string will not fit, shrink the type or enlarge the panel. Never trim
  characters and never substitute a similar-looking word.
- Identifiers that must survive intact: IS61WV204816, TFP410, CH340C,
  CP2102, QFN-100, NAME.HTML, ProgramImage, CE#, OE#, WE#, UB#, LB#,
  PS2_CLK, PS2_DATA, JOY_SCL, JOY_SDA, TEST_EN, EP = GND.

PAGE LAYOUT
Upper half, three panels left to right:
  1. "JMR JS ASIC — SYSTEM RULES (Rev A)"
  2. "JMR JS ASIC — PINOUT (Top View) — QFN-100"
  3. "PACKAGE & PROCESS" stacked above "PIN SUMMARY (Indicative Budget)"
Lower half, full width: "JMR JS COMPUTER BOARD — TOP VIEW (Rev A)" schematic,
with a "BOARD NOTES (Rev A)" panel down the right edge.

BANNER NOTE — place this line prominently under the page title area:
"Rev A PROPOSAL. Frozen by the Constitution: ~30 mm² die, custom padring,
~1 MB-class on-chip SRAM, and the IS61WV204816 asset-SRAM port contract.
Everything else on this page — the QFN-100 package, the TFP410-class
transmitter, the 12-bit DDR RGB video bus, and all power-domain values — is
a Rev A proposal, not frozen."

PANEL 1 — "JMR JS ASIC — SYSTEM RULES (Rev A)"
Seven numbered sections.

"1. SYSTEM"
- "JS-native CPU (JavaScript → JMR-JS bytecode → microcoded engines)."
- "No soft CPU, no browser."
- "One decoder: exec64. Every ProgramImage is Value64."
- "~30 mm² die, custom padring, ~1 MB-class on-chip SRAM (dual 640×480×8 framebuffers + code RAM + JS heap + microcode ROM + palette)."
- "Game art lives OFF-chip in the 4 MB SRAM asset bank (never in code RAM)."
- "HDMI scans out from the on-chip front framebuffer; the external asset SRAM is blitter-source only (never in the video path)."

"2. CLOCKING"
- "25.175 MHz oscillator on CLK_IN."
- "HDMI: 640×480 @ 60 Hz pixel clock."
- "Internal clocking derives the core clock on-die."

"3. POWER  (proposed values)"
- "Core: VDD 1.8 V.  I/O: VDD_IO 3.3 V."
- "Exposed pad EP = GND."
- "Process and domain values TBD — Rev A proposal."

"4. INTERFACES  (Rev A carrier board)"
- "External asset SRAM: 4M × 20, 1.8 V — A[20:0] + DQ[15:0] + CE#/OE#/WE#/UB#/LB# (async SRAM bus)"
- "Video: 12-bit DDR RGB + HSYNC/VSYNC/DE + PCLK → external HDMI/DVI transmitter → HDMI Type-A  (proposal)"
- "Keyboard: USB-HID → PS/2 converter MCU → PS2_CLK / PS2_DATA (RX-only)"
- "Joystick: Mini I2C gamepad @ 0x5A — JOY_SCL / JOY_SDA (open-drain, board-side pull-ups). Same master as the FPGA prototype."
- "microSD SPI (CS/SCK/MOSI/MISO), FAT32: NAME.HTML titles; ProgramImage is regenerated in memory"
- "Console UART via CH340/CP2102 micro-USB (debug/tether only)"
- "Audio PWM → amp → 3.5 mm jack (V1-later)"

"5. RESET / STARTUP"
- "Power-on reset holds RESET_N low for > 10 ms; boots to JS READY."

"6. ENVIRONMENT"
- "Operating: 0° to 70° C"
- "Storage: −20° to 85° C"
- "90% max, non-condensing"

"7. TEST"
- "Boundary scan via TEST_EN pin."

PANEL 2 — "JMR JS ASIC — PINOUT (Top View) — QFN-100"
A square dark QFN package drawing seen from the top, with pin stubs around
all four edges and small pin-name labels running outward, pin numbers
1–100 around the ring.
Centre of the package, four stacked lines:
"JMR JS ASIC"
"Rev A / JS Arch V1"
"QFN-100"
"(Top View)"
A dashed inner square labelled "EP = GND".
Colored legend strip below the drawing, seven keys:
"Power (1.8 V)" · "Power (3.3 V)" · "SRAM Addr" · "SRAM Data" ·
"SRAM Ctrl" · "Video DDR" · "Video Sync/Clk"
Second legend row, five keys:
"Peripheral" · "I2C (open-drain)" · "Clock / Reset / Test" · "GND" · "NC"
Caption under the legends, exactly:
"Pin numbers on this drawing are illustrative placement only."

PANEL 3a — "PACKAGE & PROCESS"
Small line-art drawing of a QFN package labelled
"JMR JS ASIC / Rev A / JS Arch V1 / QFN-100".
Beside it:
- "Package:  100-pin QFN (proposal)"
- "12.0 mm × 12.0 mm, 0.4 mm pitch"
- "Exposed pad (EP): GND"
- "Process:  TBD (custom padring)"
- "Die area: ~30 mm² (frozen)"
- "~1 MB-class on-chip SRAM (frozen)"
Small amber tag beneath: "Rev A / JS Arch V1"
Caption: "compile-on-RUN bytecode machine"

PANEL 3b — "PIN SUMMARY (Indicative Budget)"
(The heading reads exactly "(Indicative Budget)".)
A table with columns "Category", "Signal", "Count", "Power (Pins)",
"Description". Fourteen rows, in this order, with these exact counts:

  "SRAM Address"      / "A[20:0]"                      / "21" / "—"  / "4 MB asset bank addr"
  "SRAM Data"         / "DQ[15:0]"                     / "16" / "—"  / "16-bit data bus"
  "SRAM Control"      / "CE#/OE#/WE#/UB#/LB#"          / "5"  / "—"  / "async SRAM bus"
  "Video Bus (DDR)"   / "R[3:0], G[3:0], B[3:0]"       / "12" / "—"  / "12-bit DDR RGB"
  "Video Sync / Clk"  / "HSYNC, VSYNC, DE, PCLK"       / "4"  / "—"  / "video timing"
  "PS/2 Keyboard"     / "PS2_CLK, PS2_DATA"            / "2"  / "—"  / "RX-only (do not drive clk)"
  "Joystick (I2C)"    / "JOY_SCL, JOY_SDA"             / "2"  / "—"  / "Mini I2C gamepad @ 0x5A (open-drain)"
  "microSD (SPI)"     / "CS/SCK/MOSI/MISO"             / "4"  / "—"  / "FAT32 file system"
  "UART (Console)"    / "TX, RX"                       / "2"  / "—"  / "debug/tether only"
  "Audio (PWM)"       / "PWM_L, PWM_R"                 / "2"  / "—"  / "to audio amp"
  "Clock / Reset / Test" / "CLK_IN, RESET_N, TEST_EN"  / "3"  / "—"  / "clock, reset, scan enable"
  "Status (LEDs)"     / "ALIVE, READY, GAME"           / "3"  / "—"  / "chip status outputs"
  "Spare / NC"        / "reserved"                     / "4"  / "—"  / "headroom freed by the I2C stick"
  "Power / Ground"    / "VDD_CORE, VDD_IO, GND"        / "—"  / "20" / "supply and ground"

Final bold row: "TOTAL PINS" / "" / "80" / "20" / "100 pins"
Caption under the table, exactly:
"21 + 16 + 5 + 12 + 4 + 2 + 2 + 4 + 2 + 2 + 3 + 3 = 76 signal, + 4 spare/NC = 80, plus 20 power/ground = 100."
(There is NO "RRAM_CTRL" row. Do not add one. The counts above sum to
exactly 100 — do not alter any number.)
Blue note box below the table:
"Video = 12-bit DDR RGB into an HDMI transmitter — true 24-bit color,
640×480 @ 60 Hz. Use a standard HDMI cable.  (Rev A proposal.)"

LOWER HALF — "JMR JS COMPUTER BOARD — TOP VIEW (Rev A)"
A flat schematic-style board drawing, left to right, with colored nets and
reference designators. Blocks, in rough left-to-right order:

Power entry, top left:
- "J1  USB-C  5 V ONLY, Power IN (no data)" → "F1 Polyfuse 500 mA" → "U1 Buck Regulator 3.3 V" → "U2 LDO 1.8 V (Core)"
- decoupling caps "C6", "C11"
- rails labelled "5 V BUS", "3.3 V (I/O)", "1.8 V (Core)"

Input, left edge:
- "J2  USB-A  Keyboard Host" → "U3  USB-HID → PS/2 Converter MCU (Optional)" → nets "PS2_CLK", "PS2_DATA"
  with a red warning note: "Do NOT drive ps2_clk"
- "J4  Console UART (Tether / Debug)" → "U4  CH340C / CP2102 USB-UART Bridge" → nets "TXD", "RXD"
- "SW1  RESET_N (active low)" with "R4 10K" pull-up

Centre — the chip:
- Large box "U5  JMR JS ASIC  (Rev A / Arch V1)  100-PIN QFN"
- Buses leaving the right side toward U8: "A[20:0]  (21)", "DQ[15:0]  (16)", and control "CE# (1)", "OE# (1)", "WE# (1)", "UB# (1)", "LB# (1)"
- Buses leaving the top-right toward U9: "RGB_DDR[11:0]  (12)", "HSYNC / VSYNC / DE / PCLK  (4)"
- Other nets: "SPI_CS/SCK/MOSI/MISO  (4)", "UART_TX / UART_RX  (2)", "AUDIO_PWM  (2)", "JOY_SCL / JOY_SDA  (2)", "ALIVE / READY / GAME  (3)", "CLK_IN / RESET_N / TEST_EN  (3)"

Right of the chip:
- Box "U8  ISSI IS61WV204816  4 MB SRAM  (2M × 16)  ASSET BANK"
- Italic caption beneath U8, exactly:
  "Asset bank feeds the blitter only — HDMI scans out from the ON-CHIP dual framebuffers (VBlank swap)."

Top right:
- Box "U9  HDMI Transmitter (TFP410-class)  — Rev A proposal"
- Nets to "J8  HDMI OUT (Type-A)": "TMDS D2+/D2−", "TMDS D1+/D1−", "TMDS D0+/D0−", "TMDS CLK+/CLK−", "+5 V", "HPD", "DDC_SCL", "DDC_SDA"

Bottom row of small blocks:
- "X1  25.175 MHz Crystal Oscillator"
- "J5  TEST HDR (2×5)": pins "1 3.3 V", "2 TEST_EN", "3 TMS", "4 TCK", "5 nRESET", "6 GND", "7 TDI", "8 TDO", "9 TRST_N", "10 NC"
- "J6  STAT LEDs": "ALIVE", "READY", "GAME" with "R2 330Ω", "R3 330Ω", "R5 330Ω", caption "(active high)"
- "U7  Audio Amp (Class-D)" fed by "PWM_L" and "PWM_R", with "3.3 V" rail
- "J9  microSD Card Socket (SD Card Out)": pins "SC", "CS", "SCK", "MOSI", "MISO", "CD", "GND (0V)"
- "J7  JOYSTICK HEADER (PH2.0, 4-pin)": pins "1 G (GND)", "2 V (+3.3 V)", "3 SDA", "4 SCL", with pull-ups "R6 4.7 kΩ" and "R7 4.7 kΩ" to 3.3 V on SDA and SCL, and the caption "Match the labels on the stick (G V SDA SCL), not wire colors."

"BOARD NOTES (Rev A)" panel down the right edge, bulleted:
- "USB-C = power only (5 V). No data."
- "Machine is STANDALONE: HDMI + USB keyboard + joystick + microSD. No PC required."
- "UART = debug/tether only."
- "microSD FAT32 holds NAME.HTML titles — user titles only."
- "No compile cache. Nothing generated is ever written back to the card; the ProgramImage is rebuilt in memory on every RUN."
- "Asset SRAM holds full-quality game art, streamed on every RUN."
- "All supplies well decoupled."
- "Solid GND plane (top and bottom)."
- "Place decoupling caps as close as possible to device pins."
- "STAT LED: ALIVE / READY / GAME (on pins 40 / 41 / 42)."
- "TEST_EN for boundary scan."
- "Joystick is a Mini I2C gamepad @ 0x5A on JOY_SCL / JOY_SDA — the same part and the same master the FPGA prototype uses."
- "I2C is open-drain: R6 / R7 (4.7 kΩ to 3.3 V) are required. The ASIC does not drive either line high."
- "The stick costs 2 pins instead of 6, and the bus is shared — further I2C peripherals can hang off the same two pins with no new package pins."

DO NOT PLACE ANYWHERE ON THIS POSTER
- ".JSH", ".JSB", ".JSlf", or any "compile cache" of any kind — there is no
  compile cache and nothing is ever written to the card
- "NAME.FMT" or "NAME.DAT" (the only file type is NAME.HTML)
- "debug/therm" (it is "debug/tether")
- "RRAM_CTRL" (no such pin group)
- "(Unclad Busted)" or any other mangling of "(Indicative Budget)"
- "exec32"
- a 6-pin GPIO joystick header, "Joystick (GPIO)", or "GP[5:0]" — the
  stick is I2C on both the FPGA prototype and the ASIC
- a pin-count table whose rows do not sum to 100
- any claim that the QFN-100 package, the TFP410-class transmitter, the
  12-bit DDR RGB bus, or the power values are frozen — they are proposals
````

---

## What changed vs. the current render

### The errata bullet that is itself now wrong

`ARCHITECTURE.md` currently says to fix BOARD NOTES `".JSlf" → ".JSH"`. That
guidance predates the compile-cache removal. **The whole line must go** —
there is no `.JSH`, no `.JSB`, and no cache. Same drift as the Architecture
V1 poster. Corrected in this commit.

### From the existing errata

| # | Item | Old poster | Correct now |
|---|---|---|---|
| 1 | Frozen vs. proposed | unmarked | QFN-100, TFP410-class, 12-bit DDR RGB, power values are **Rev A proposals**; only the die target and the IS61WV204816 port contract are frozen |
| 2 | U8 part | garbled | "ISSI IS61WV204816 (2M × 16, 4 MB)" |
| 3 | SYSTEM RULES §1 | "Game run 100% OFF-chip … (never in video RAM)" | "Game **art lives** OFF-chip in the 4 MB SRAM asset bank (never in **code** RAM)" |
| 4 | SYSTEM RULES §4 | SRAM/microSD/UART/audio bullets garbled | full replacement text, quoted in the prompt |
| 5 | PIN SUMMARY | title "(Unclad Busted)", spurious "RRAM_CTRL" row, Audio count 1, rows do not sum | "(Indicative Budget)", no RRAM_CTRL, Audio **2**, rows sum to exactly 100 |
| 6 | BOARD NOTES | "debug/therm", "NAME.FMT tiles", ".JSlf" | "debug/**tether**", "NAME.HTML titles", and the cache line **deleted** |
| 7 | QFN pin numbers | implied real | "illustrative placement only" |

### New

| Item | Old poster | Correct now | Source |
|---|---|---|---|
| Compile cache | "invisible, JSH compile cache" in BOARD NOTES | no cache exists — line removed, replaced with "the ProgramImage is rebuilt in memory on every RUN" | `ARCHITECTURE.md:223`, `:310` |
| µSD contents | "NAME.FMT tiles" | "NAME.HTML titles — user titles only" | `jmr_console_engine.sv`, `storage/` |
| Dispatch | absent | SYSTEM RULES §1 gains "One decoder: exec64. Every ProgramImage is Value64." | `jmr_js_vm.sv:6035` |
| Joystick | 6-pin GPIO header, "Joystick (GPIO)", `GP[5:0]` | **Mini I2C gamepad @ `0x5A`** on `JOY_SCL` / `JOY_SDA` — 2 pins, open-drain, board pull-ups. Same part and master as the FPGA prototype; the 4 freed pins become spare/NC | `rtl/phys/jmr_i2c_joy.sv`, user decision 2026-08-21 |
| Pin total | rows did not sum | explicit "80 signal + 20 power/ground = 100" caption so a reader can check the arithmetic | errata |
