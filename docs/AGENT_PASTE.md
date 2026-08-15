# Paste this to the next agent

Read first: `docs/SESSION_HANDOFF.md`, `docs/JMR_JS_COMPATIBILITY.md`,
`CONSTITUTION.md`, `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`,
`.cursor/rules/python-first-parity.mdc`,
`.cursor/rules/never-fake-fpga-sim.mdc`,
`.cursor/rules/no-game-hardwire.mdc`,
`.cursor/rules/use-existing-traces.mdc`.

This is a **JavaScript-native FPGA CPU** (then ASIC). Same ladder as BASIC:
PYTHON bytecode → real FPGA-SIM RTL → board. Not a browser. Not dukpy.

**You do not play the games.** I F9 `LOAD "NAME.HTML"` / `RUN`. You grow the
language + VM with small snippets (`tests/test_rtl_snippets.py`, PYTHON twin
in `tests/test_bytecode_js.py` if needed). One hole, one test, one patch.
Stop and I F9.

Do not LOAD INVADERS/PACMAN/DONKEY. Do not PNG-diff. Do not use pixel counts
as pass. Do not stack features. Do not speed SPI. Do not flash `.bit`. Do
not rewrite the HTML titles. Do not delete files.

PYTHON already plays. FPGA-SIM is the live rung. Next snippet-proven holes
are in SESSION_HANDOFF: `JSON.parse`/`stringify`, `String.replace` /g,
`join` of string digits, `findIndex`, first-rAF/`S_STRIDX`. `drawImage` /
ASET scale snippets are already green — do not re-open unless they fail.
