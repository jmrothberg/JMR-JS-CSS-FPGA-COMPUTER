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

### Compile-on-RUN (hard rule)

```text
LOAD "NAME.HTML"   # edit this; line numbers = this file
RUN                # ALWAYS compile current HTML → fresh internal .JSH → VM
```

- **Source of truth = `.HTML`**, never a leftover `.JSH`.
- **`RUN` always recompiles** so editor line numbers match compile errors.
- **`.JSH`** = invisible compile *output* (overwrite/write fresh). Not a LOAD
  name. Not a second game. Stale `.JSH` may be deleted; do not prefer it over
  compiling.

## Not product titles

- Same-stem `NAME.JS` / `NAME.JSB` — legacy demos, not twins of the HTML games.
- Prefer differently named smoke: `RECTDEMO.JS`, `JOYDEMO.JS`, `CLIMB.JS`.

## Upstream only (not DIR / not card)

`games_donkey/`, `games_pacman/`, `games_spinv/`, `games_invaders*` —
vendor trees used to build the inlined `.HTML`. Not playable LOAD names.

**Rules:** `CONSTITUTION.md`, `.cursor/rules/no-dukpy-cheat-native-cpu.mdc`,
`docs/SESSION_HANDOFF.md`.
