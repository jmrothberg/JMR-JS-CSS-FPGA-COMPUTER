# JMR JS compatibility matrix (V1)

Target games drive the language/API set. Do **not** implement browser
features that no target game needs. **Not a full web browser** — no CSS
layout, Fetch/XHR, WebGL, or DOM outside the Canvas game shell.

## Reference title: Space Invaders (dwmkerr)

| Item | Path / note |
|---|---|
| Upstream | https://github.com/dwmkerr/spaceinvaders (MIT) |
| Vendored | `storage/games_invaders/` |
| Boot file | `storage/INVADERS_FULL.HTML` — `LOAD` + `RUN` |
| FM engine | `functional_model/js_host.py` via **dukpy** (host only; not soft-CPU on FPGA) |
| FPGA-SIM (default) | **Real RTL** — bytecode VM / RECTDEMO / console. Not dukpy. |
| Host twin (opt-in) | `JMR_SIM_HOST=1` → `sim/host_sim_server.py` (HTML/dukpy). **Never** the F9 default. |
| Silicon | JMR bytecode + engines + Digilent HDMI — dukpy does **not** ship on the board |
| Subset on RTL today | `INVADERS.JS` → `.JSB` via `tools/compile_js.py` / `jmr_js_vm.sv` |

### APIs used by INVADERS_FULL (inventory)

| API | Status on PYTHON / host twin (not default FPGA-SIM) |
|---|---|
| constructors / `prototype` | yes (dukpy) |
| `canvas.getContext('2d')` | yes |
| `fillRect` / `clearRect` / `strokeRect` | yes → indexed FB |
| `fillText` | yes (approx glyph bars; score/HUD readable enough) |
| `setInterval` / `clearInterval` / `setTimeout` | yes |
| `requestAnimationFrame` | stubbed (queue drained each frame) |
| `window.onload` / `addEventListener` keydown/keyup | yes |
| `document.getElementById` (canvas) | yes |
| keyboard 37/39/32 | yes (GUI arrows/space → KEYBITS) |
| Web Audio / `XMLHttpRequest` / sounds | **stubbed** (silent) |
| CSS / starfield DOM / touch | **out of scope** (stripped in INVADERS_FULL) |
| `drawImage` | stub no-op (this title draws with rects) |

## Feature matrix (planning — other titles TBD)

| Feature | Invaders | Pac-Man | Donkey | Breakout | Extra | Implement |
|---|---|---|---|---|---|---|
| numbers / bool / strings | yes | yes | yes | yes | yes | V1 |
| arrays / objects / prototypes | yes | yes | yes | yes | yes | V1 (FM dukpy; bytecode grows) |
| functions | yes | yes | yes | yes | yes | V1 |
| setInterval / rAF | yes | yes | yes | yes | yes | V1 |
| fillRect / clearRect | yes | yes | yes | yes | yes | V1 |
| fillText | yes | often | often | often | — | V1 (approx) |
| drawImage | optional | yes | yes | often | — | V1 later |
| keyboard events | yes | yes | yes | yes | yes | V1 |
| joystick / gamepad | often | often | often | often | — | V1 (Pmod; mouse in sim) |
| Audio | stub | later | later | later | — | later |
| WebGL | no | no | no | no | no | NO |
| Fetch / XHR | no | no | no | no | no | NO |
| general CSS layout | no | no | no | no | no | NO |

## Regression seeds (repo)

| File | Covers |
|---|---|
| `storage/RECTDEMO.JS` | bytecode: console.log, clear, fillRect, swapBuffers |
| `storage/JOYDEMO.JS` | joy-readable demo rectangle |
| `storage/INVADERS.JS` | subset bytecode invaders |
| `storage/INVADERS_FULL.HTML` | full HTML Canvas game via dukpy host |

```text
LOAD INVADERS_FULL.HTML
RUN
# arrows + space; ESC quit
```
