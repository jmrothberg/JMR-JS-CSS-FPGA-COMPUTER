# Session handoff — next agent start here

Last updated: **2026-08-15**.

This product is a **JavaScript-native FPGA CPU** (then ASIC). Not a browser.
Not dukpy. Not a host twin. Same ladder as the BASIC machine: **PYTHON
bytecode → real FPGA-SIM RTL → board → ASIC.**

Paste briefing: [`docs/AGENT_PASTE.md`](AGENT_PASTE.md).
ISA (done / gap / never): [`docs/JMR_JS_COMPATIBILITY.md`](JMR_JS_COMPATIBILITY.md).

---

## Goal

A standalone FPGA computer whose native language is JavaScript. The user
types `LOAD "NAME.HTML"` / `RUN`. `RUN` always compiles the loaded HTML
into a fresh internal `.JSH` (code + ASET art → external SRAM). The JMR
VM executes that bytecode on PYTHON, then the **same ISA** on Verilator
RTL, then silicon.

`INVADERS.HTML` / `PACMAN.HTML` / `DONKEY.HTML` are **acceptance tests the
USER runs**. They are not the ISA. Do not hardwire titles
(`.cursor/rules/no-game-hardwire.mdc`).

**PYTHON already plays those titles.** FPGA-SIM snippets for the overnight
language holes are green (114 pytest). **User has not F9-blessed play.**
Restart F9 after this tree’s sim rebuild so the new binary loads.

---

## How you work (copy BASIC’s method, not its ISA)

User F9s PYTHON then FPGA-SIM. You grow **language + VM + engines**.

```text
user F9 complaint
  → name the JS/VM feature (not the game)
  → smallest snippet in tests/test_rtl_snippets.py
    (PYTHON twin in tests/test_bytecode_js.py if the FM is also dark)
  → one RTL or FM patch
  → pytest that snippet
  → stop. one sentence what the user should F9. wait.
```

One hole. One snippet. One fix. Assert a boolean (rect appeared, length==2,
`raf>=1`). Never “looks like pacman.” Never pixel-count as pass.

Rebuild sim only when RTL changed: `make -C sim sim_server_synth`.
User must **restart F9** so the new binary loads.

---

## Do not

- `LOAD "INVADERS.HTML"` / `PACMAN` / `DONKEY`. No PNG diffs, no play scripts,
  no 300-FRAME loops. The user has the GUI.
- Stack features in one VM pass (that is how the maze went backward).
- Speed sim SPI (`-GSD_RUN_DIV`) — clk/4 and clk/2 → `?IO`, every snippet dies.
- Rewrite the three HTML files to “fit” the VM.
- Flash `.bit` / `.bin` / Vivado until the user F9-approves FPGA-SIM.
- Fake FPGA-SIM (`JMR_SIM_HOST=1`) or dukpy as the CPU.
- Delete files. Do not add READMEs. This file is the handoff.
- Treat battery PASS or `nz=` as play proof.

---

## Honest status

| Rung | Status |
|---|---|
| Chrome | Authoring look only — not the machine |
| PYTHON bytecode | Titles play. Control. |
| FPGA-SIM (Verilator RTL) | F9 PACMAN 2026-08-15: left maze/mouth/ghosts still wrong. Fix in tree: `arr[-1]`/`arr[len]` now undefined (left-edge `map.get`); `a[i]=` grows `length` (28-wide house finder). **Restart F9.** User has not blessed play. |
| Board | Out of scope. Last bit lags the tree. J15 USB-HID is dead — type/play from GUI tether until hardware is fixed. |

Monitor: `LOAD` / `RUN` / `LIST` / `DIR` / `EDIT`. One glass: READY letterbox,
RUN = 640×480 FB. `.JSB` = tiny `.JS` demo bytecode. `.JSH` = HTML
compile-on-RUN (code + ASET). Games only need `.JSH`.

---

## Keep (do not revert)

These are in the tree. Snippets exist. Do not re-open them unless a new
pytest fails.

- Compile-on-RUN; ASET → 4 MB asset SRAM; no `NAME.DAT`.
- One `fb_swap` per FRAME (`present_pend`).
- Integer `/2` is a 1-cycle shift (`divs=` counts slow `S_DIV` only).
- `fillText` / `measureText` from font ROM; reserved `metrics_oid` (no heap churn).
- `NAMB` string bytes; `str[i]` / `str.length`.
- `arr.find` identity + `splice`; `setTimeout` / rAF.
- Class-field listener as Fn; `KeyboardEvent` `{key}`; Space `e.key === " "`.
- LIST 64-col wrap (line-number digits count; no extra NL after VRAM wrap).
- Monitor: `laod` → `?SN ERROR`; missing file → `?FN FILE NOT FOUND` (PYTHON+RTL).
- FAT OPEN follows the root cluster chain (new 8.3 names past cluster 1).
- **SPR1/ASET `drawImage`:** trailer must parse every byte (including
  `off[1:0]==3`) and return to `S_SPR` on a word-boundary count; NAMB follows
  SPR1 pixels. 1:1, 5-arg 2×, `setTransform(2,…)`, 9-arg source window, ASET
  SRAM path — `tests/test_rtl_snippets.py` (`test_rtl_drawimage_*`,
  `test_rtl_aset_*`). Venetian blinds were a skipped-byte pack, not “DONKEY.”

---

## Next holes (F9 play — 2026-08-15 overnight)

Snippet holes from the previous table are **pytest-green** (`tests/test_rtl_snippets.py` + `tests/test_bytecode_js.py` = 114). Do not re-open them unless a snippet fails.

Overnight play-progression (`tools/check_runtime_parity.py` `check_play_progression`, `JMR_TRACE=1`):

| Check | PYTHON | FPGA-SIM |
|---|---|---|
| INVADERS bunker arch (`continue` corners) | OK | OK |
| PACMAN ghost-color outside house | NOTE 0 | NOTE 0 (maze still drew: GET/arc/rect, `fcap=0`) |
| DONKEY boot/Enter FB change | OK | OK |

Read `traces/LATEST_FPGA-SIM.log` from the **end**. DONKEY LOAD/RUN LINE can hit the 100M-clock cap (`capped=1`) on the 2.3 MB `.JSH`; host then size-scales TICKN. **Do not retune `SD_RUN_DIV`.**

Title `LOAD`+`RUN` in the GUI is the remaining user rung. If F9 still shows a hole, add a **tiny snippet** for that JS feature — do not edit the three HTML files.

`ctx.textBaseline = 'top'` is ignored; PYTHON `fill_text` is also always
alphabetic (`y - 8*scale`). Not a PYTHON/RTL gap. SCORE miss is something
else if it still fails after F9.

Fat HTML LOAD hitting the 100M-clock cap is SPI × megabytes in Verilator,
not a mystery stall. **Do not retune `SD_RUN_DIV`.** Host LOAD wait is
size-scaled like RUN.

---

## After a green snippet

One sentence, then stop. Restart F9 so the rebuilt sim loads.

- INVADERS: Space starts; a shot **kills** an alien.
- PACMAN: maze looks like PYTHON; pacman turns; ghosts leave the house; SCORE draws.
- DONKEY: title letters readable (not Venetian blinds); Enter leaves the title.

Do not claim any of those from pytest.

---

## Commands

```bash
make -C sim sim_server_synth          # after RTL change
.venv/bin/python -m pytest tests/test_rtl_snippets.py -q --tb=line
# optional smoke, not play proof:
.venv/bin/python tools/check_runtime_parity.py
```

No Vivado until the user says FPGA-SIM play is good.

---

## Key files

| Area | Path |
|---|---|
| VM (RTL) | `rtl/engines/jmr_js_vm.sv` |
| Console / LIST / JSB+ASET load | `rtl/engines/jmr_console_engine.sv` |
| Bytecode + ASET encode | `functional_model/jsb_format.py`, `compiler.py`, `bytecode.py`, `machine.py` |
| FPGA-SIM | `sim/sim_main.cpp`, `runtime/sim_backend.py` |
| Snippets | `tests/test_rtl_snippets.py`, `tests/test_bytecode_js.py` |
| GUI | `gui_jmr_js.py` |
| ISA | `docs/JMR_JS_COMPATIBILITY.md` |
| Architecture | `CONSTITUTION.md`, `docs/ARCHITECTURE.md` |
