# GUI / tooling bugs — host-side only

Words: [README.md — Words used](../README.md#words-used-in-this-project).

**What this is.** Defects in the **host** GUI, tether, and build tooling —
things that never reach the `.bit`. Kept separate from
[potential bugs.md](potential%20bugs.md) (RTL / JS-semantic bugs) so a
board-bring-up session isn't distracted by cosmetic host issues.

**Rule of thumb for filing here:** if the board and HDMI output stay
correct and only the host-side view misbehaves, it belongs in this file.

---

### #G1 OPEN — GUI mirror hangs on `NEW`+`RUN` (rectdemo) and needs a restart (board report 2026-08-25)

**Glass:** on run-38's bitstream, `NEW` then `RUN` starts the RTL
rectdemo (`u_demo`). The two boxes draw **correctly on the HDMI screen**,
but the GUI window stops updating and has to be restarted. Reproducible
from either the GUI console or the FPGA keyboard.

**Not the bandwidth limit** (see #G2). Falling *behind* is expected;
requiring a restart is not. Shape suggests a protocol desync or a
blocking read with no timeout on the dump path — mechanism unconfirmed.

**Why the rectdemo triggers it:** `u_demo` redraws continuously and never
idles, so every frame is fully dirty with no gap for the mirror to catch
up in. A game at least pauses between frames. It is the harshest case for
the dump protocol, not a special diagnostic mode.

**Impact:** debug-window only. Board, VM and HDMI stay correct throughout.

**Suspects:** the `dump_addr`/`dump_data` request loop in the GUI backend;
whether a partial frame can leave the protocol mid-transfer.

---

### #G2 NOT A BUG — the GUI framebuffer mirror cannot sustain game frame rates

The GUI mirrors the screen by pulling the whole framebuffer over the PROG
(FT245) cable at one byte per pixel:

- 640 × 480 = **307,200 bytes = 300 KB per frame**
- 60 fps would need **18.4 MB/s**
- FT245 realistically delivers a few MB/s → roughly **3–26 fps**

So the mirror stuttering during a running game is a link-bandwidth limit,
not a defect. **HDMI is the real output** — it reads DDR3 directly and
never touches the cable, which is why the board looks correct while the
GUI lags.

Filed so this is not re-diagnosed as a board fault. If a faster mirror is
ever wanted, the lever is sending deltas or a reduced-resolution preview
rather than full frames.

---

## Related

- [potential bugs.md](potential%20bugs.md) — RTL and JS-semantic bugs (the main ledger)
- [TIMING_WALL.md](TIMING_WALL.md) — timing/congestion measurements
- [CONSTITUTION.md](../CONSTITUTION.md) — what the machine is; wins on conflict
