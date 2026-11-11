"""Drive VIGIL by keyboard headlessly and report what the hero did.

    python3 tools/vigil_probe.py                # play floor 1 to its exit door
    python3 tools/vigil_probe.py --to 6         # play all six floors

Clicks nothing and reads no private state except the game's own globals (HX,
HY, FLOOR, MODE, HEARTS, SAND) — the same numbers a player sees on the HUD.

The route is the room's zig-zag: floor lane to ladder A on the right, climb,
middle lane left to ladder B, climb, top lane right to the door. The harness
jumps when the next cell holds a spike or a hole, which is what a player does;
it does not hop blindly, because under the middle platform a jump is capped
by that platform's underside.

A harness, not a release gate: the rungs are PYTHON, then FPGA-SIM.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.jsb_format import ProgramImage  # noqa: E402
from functional_model.machine import Machine  # noqa: E402
from runtime.backend import PythonBackend  # noqa: E402
from tools.compile_js import compile_html_text, encode_html_chunk  # noqa: E402

HTML = ROOT / "storage" / "VIGIL.HTML"
LEFT, RIGHT, UP, DOWN, SPACE, SWORD = 37, 39, 38, 40, 32, 90

CELL = 32
COLS, ROWS = 20, 12
FLOOR_Y = 352       # feet on row 11's top edge
MID_Y = 224         # feet on row 7's top edge
TOP_Y = 96          # feet on row 3's top edge
LAD_A_X = 528       # col 16 centre
LAD_B_X = 176       # col 5 centre
EXIT_X = 368        # col 11 centre
LEGEND = ".#=bGgP^%WTCBDd|E"
HAZARDS = '^'
ROW_LINE = re.compile(r'^\s*"([.#=bGgP^%WTCBDd|E]{20})",?\s*$')
ROOMS_START = re.compile(r'^var ROOMS = \[')


def read_rooms() -> list[list[str]]:
    """The room literals exactly as the game holds them, straight from the file.

    Every row literal is exactly 20 legend characters long and ends with a
    comma, which is what makes this safe: nothing else in the file looks like
    that. A room is 12 rows; six rooms are expected.
    """
    rooms, block, inside = [], [], False
    for line in HTML.read_text().splitlines():
        if not inside:
            if ROOMS_START.match(line):
                inside = True
            continue
        m = ROW_LINE.match(line)
        if m:
            block.append(m.group(1))
            continue
        if line.strip() in ("]", "],", "];"):
            if len(block) == ROWS:
                rooms.append(block)
            block = []
            if line.strip() == "];":
                break
    return rooms


class Run:
    def __init__(self, rooms: list[list[str]], quiet: bool = False) -> None:
        self.rooms = rooms
        self.quiet = quiet
        src = HTML.read_text()
        image = ProgramImage(encode_html_chunk(compile_html_text(src, source_path=HTML)))
        self.b = PythonBackend(Machine(storage_root=ROOT / "storage"))
        self.b.desktop.visible = False
        self.b.machine._start_html_image(image)
        self.hw = self.b.machine._hw_vm
        for _ in range(2):
            self.b.frame_tick()

    # -- VM observation -----------------------------------------------------
    def g(self, name):
        # hw.globals builds a fresh dict per read; caching one would freeze it.
        return self.hw.globals.get(name)

    def fault(self):
        return self.hw.error

    def status(self) -> str:
        return (f"x={self.g('HX'):6.1f} y={self.g('HY'):6.1f} "
                f"floor={self.g('FLOOR') + 1:.0f} mode={self.g('MODE'):.0f} "
                f"hearts={self.g('HEARTS'):.0f} sand={self.g('SAND'):.0f}")

    # -- map questions ------------------------------------------------------
    def room(self) -> list[str]:
        return self.rooms[int(self.g("FLOOR"))]

    def lane_row(self, feet_y: float) -> int:
        """The row a body standing with its feet at feet_y occupies."""
        return int(feet_y // CELL) - 1

    def hazard_ahead(self, code: int) -> bool:
        """True when a jump begun now would clear the hazard ahead.

        Timing matters more than spotting. The arc covers about two cells
        (59px) from a standing start, so the jump has to begin while the
        hazard's near edge is still ahead but within about a cell — start too
        early and the hero lands on it, too late and it is underfoot.
        """
        room = self.room()
        feet = self.g("HY")
        lane = self.lane_row(feet)
        if lane < 0 or lane >= ROWS:
            return False
        hx = self.g("HX")
        step = 1 if code == RIGHT else -1
        start = int(hx // CELL) + step
        for c in range(start, start + step * 2, step):
            if c < 0 or c >= COLS:
                return False
            cell = room[lane][c]
            under = room[lane + 1][c] if lane + 1 < ROWS else '#'
            hole = cell == '.' and under == '.'
            if cell not in HAZARDS and not hole:
                continue
            edge = c * CELL if code == RIGHT else (c + 1) * CELL
            # Jump when the hazard's near edge is still a short step ahead:
            # the arc then carries the body clean over the far edge.
            gap = (edge - hx) if code == RIGHT else (hx - edge)
            return 4 <= gap <= 20
        return False

    # -- input -------------------------------------------------------------
    def tap(self, code: int) -> None:
        self.b.machine.input.key_event(code, "k", True)
        self.b.frame_tick()
        self.b.machine.input.key_event(code, "k", False)
        self.b.frame_tick()

    def hold(self, code: int, frames: int) -> str:
        self.b.machine.input.key_event(code, "k", True)
        for _ in range(frames):
            self.b.frame_tick()
        self.b.machine.input.key_event(code, "k", False)
        self.b.frame_tick()
        return f"hold {code:3d} {frames:3d}f"

    def guard_ahead(self) -> bool:
        """True when a live warden is within blade reach on this lane."""
        if self.g("GALIVE") != 1:
            return False
        if self.g("GSTATE") >= 5:
            return False
        d = self.g("GX") - self.g("HX")
        if d < 0:
            d = -d
        if d > 56:
            return False
        dy = self.g("GY") - self.g("HY")
        return -34 <= dy <= 34

    def fight(self, limit: int = 240) -> str:
        """Stand and use the sword until the warden is down or time runs out.

        The blade lands halfway through the thrust, so the harness presses Z
        whenever it can and waits out each recovery; it never walks forward
        into the guard's own thrust.
        """
        n = 0
        face = 0
        while n < limit:
            if self.g("GALIVE") != 1 or self.g("GSTATE") >= 5:
                break
            gy = self.g("GY") - self.g("HY")
            if gy > 34 and self.g("HGROUND") == 1:
                # step toward the guard's lane rather than swing at the air
                self.b.machine.input.key_event(UP, "k", True)
                self.b.frame_tick()
                self.b.machine.input.key_event(UP, "k", False)
            elif gy < -34 and self.g("HGROUND") == 1:
                self.b.machine.input.key_event(DOWN, "k", True)
                self.b.frame_tick()
                self.b.machine.input.key_event(DOWN, "k", False)
            else:
                if self.g("GX") < self.g("HX"):
                    face = LEFT
                else:
                    face = RIGHT
                self.b.machine.input.key_event(face, "k", True)
                self.b.frame_tick()
                self.b.machine.input.key_event(face, "k", False)
                if self.g("HATTACK") == 0 and n % 3 == 0:
                    self.b.machine.input.key_event(SWORD, "z", True)
                    self.b.frame_tick()
                    self.b.machine.input.key_event(SWORD, "z", False)
                else:
                    self.b.frame_tick()
            n += 1
        return f"fight {n:3d}f  warden={'down' if self.g('GSTATE') >= 5 else 'up'} "

    def walk_to(self, x: float, limit: int = 520) -> str:
        code = RIGHT if x > self.g("HX") else LEFT
        n, jumps, fights = 0, 0, 0
        while n < limit:
            if self.guard_ahead():
                self.fight()
                fights += 1
                if self.g("MODE") != 1:
                    break
                continue
            if self.hazard_ahead(code) and self.g("HGROUND") == 1:
                self.b.machine.input.key_event(SPACE, " ", True)
                self.b.machine.input.key_event(code, "k", True)
                self.b.frame_tick()
                self.b.machine.input.key_event(SPACE, " ", False)
                jumps += 1
            else:
                self.b.machine.input.key_event(code, "k", True)
                self.b.frame_tick()
            hx = self.g("HX")
            if (code == RIGHT and hx >= x) or (code == LEFT and hx <= x):
                break
            n += 1
        self.b.machine.input.key_event(code, "k", False)
        self.b.frame_tick()
        return (f"walk {'right' if code == RIGHT else 'left '} {n:3d}f"
                f"  jumps={jumps} fights={fights}")

    def climb_to(self, y: float, limit: int = 520) -> str:
        code = UP if y < self.g("HY") else DOWN
        n = 0
        while n < limit:
            self.b.machine.input.key_event(code, "k", True)
            self.b.frame_tick()
            hy = self.g("HY")
            if (code == UP and hy <= y) or (code == DOWN and hy >= y):
                break
            n += 1
        self.b.machine.input.key_event(code, "k", False)
        self.b.frame_tick()
        return f"climb {'up  ' if code == UP else 'down'} {n:3d}f"

    def close(self) -> None:
        self.b.shutdown()


def play_floor(r: Run) -> bool:
    start = r.g("FLOOR")
    steps = [
        r.walk_to(LAD_A_X),
        r.climb_to(MID_Y),
        r.walk_to(LAD_B_X),
        r.climb_to(TOP_Y),
        r.walk_to(EXIT_X),
        r.hold(UP, 5),
    ]
    if not r.quiet:
        for s in steps:
            print("  ", s)
    return r.g("FLOOR") != start or r.g("MODE") == 4


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--to", type=int, default=1, help="play floors 1..N")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    rooms = read_rooms()
    print(f"rooms read from source: {len(rooms)}")
    if len(rooms) != 6:
        print("FAIL: could not read the room literals")
        return 1
    r = Run(rooms, args.quiet)
    try:
        r.tap(SPACE)
        if r.g("MODE") != 1:
            print("FAIL: space did not start a run", r.status())
            return 1
        print("start", r.status())
        for n in range(args.to):
            ok = play_floor(r)
            print(f"floor {n + 1}: {'OK   ' if ok else 'STUCK'} {r.status()}")
            if not ok or r.fault() or r.g("MODE") >= 2:
                print("fault", r.fault())
                return 1
        print("done ", r.status(), "fault:", r.fault())
        return 0
    finally:
        r.close()


if __name__ == "__main__":
    raise SystemExit(main())
