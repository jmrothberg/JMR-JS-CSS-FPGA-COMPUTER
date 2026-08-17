# storage/

Seeds for the machine disk image.

## Product UX (Chrome-like)

You only ever:

```text
LOAD "NAME.HTML"
RUN
```

Same `.HTML` should open in Chrome (authoring) and run on PYTHON → FPGA-SIM →
BOARD → ASIC via the **JMR bytecode VM** — **not dukpy**.

| Game | Source (LOAD) |
|---|---|
| Space Invaders | `INVADERS.HTML` |
| Pac-Man | `PACMAN.HTML` |
| Donkey Kong | `DONKEY.HTML` |
| Asteroids (vector) | `ASTEROID.HTML` |
| Aurora | `AURORA.HTML` |
| Joystick | `JOYDEMO.HTML` |
| Mr. Do! | `MRDO.HTML` |

Authoring rules for new titles: [docs/GAME_DESIGN.md](../docs/GAME_DESIGN.md).

### Compile-on-RUN (hard rule)

```text
LOAD "NAME.HTML"   # edit this; line numbers = this file
RUN                # ALWAYS compile current HTML → in-memory ProgramImage → VM
```

- **Source of truth = `.HTML`**.
- **`RUN` always recompiles** so editor line numbers match compile errors.
- No sidecar compile file on disk or on the card. Graphics ride the
  ProgramImage **ASET section** into the external 4 MB SRAM asset bank at RUN
  (full quality; per-title 256-entry palette). There is **no `NAME.DAT` file**.

## Not product titles

- Same-stem `NAME.JS` / `NAME.JSB` — legacy demos, not twins of the HTML games.
- Prefer library HTML smoke: `JOYDEMO.HTML`.

## Upstream only (not DIR / not card)

`games_donkey/`, `games_pacman/`, `games_spinv/`, `games_invaders*` —
vendor trees used to build the inlined `.HTML`. Not playable LOAD names.

**Rules:** `CONSTITUTION.md`, `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`,
`docs/SESSION_HANDOFF.md`.
