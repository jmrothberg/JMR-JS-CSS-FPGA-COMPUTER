"""Capture VIGIL frames to traces/vigil/ from a scripted keyboard run.

    python3 tools/vigil_shots.py

Uses the same driver as tools/vigil_probe.py, so what it captures is what the
Python model actually renders — not a browser preview. The frames are the
proof-of-work pictures: title, floor 1, mid-climb, a duel, the win screen.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import tools.vigil_probe as vp  # noqa: E402

OUT = ROOT / "traces" / "vigil"


def shot(b, name: str) -> Path:
    from PIL import Image

    dest = OUT / name
    rgb = b.framebuffer().front_rgb_preview()
    Image.frombytes("RGB", (640, 480), rgb).save(dest)
    print("wrote", dest.relative_to(ROOT))
    return dest


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    r = vp.Run(vp.read_rooms(), quiet=True)
    try:
        for _ in range(30):
            r.b.frame_tick()
        shot(r.b, "01-title.png")

        r.tap(vp.SPACE)
        for _ in range(20):
            r.b.frame_tick()
        shot(r.b, "02-floor1-start.png")

        r.walk_to(vp.LAD_A_X)
        r.climb_to(vp.MID_Y - 40)
        shot(r.b, "03-climbing.png")
        r.climb_to(vp.MID_Y)

        r.walk_to(vp.LAD_B_X)
        r.climb_to(vp.TOP_Y)
        r.walk_to(vp.EXIT_X)
        shot(r.b, "04-floor1-exit.png")

        # floors 2 and 3, then a warden duel on floor 5
        for _ in range(2):
            vp.play_floor(r)
        shot(r.b, "05-floor3.png")

        for _ in range(2):
            vp.play_floor(r)
        r.walk_to(vp.LAD_A_X)
        r.climb_to(vp.MID_Y)
        r.walk_to(vp.LAD_B_X)
        r.climb_to(vp.TOP_Y)
        r.b.machine.input.key_event(vp.RIGHT, "k", True)
        for _ in range(90):
            r.b.frame_tick()
            if r.guard_ahead():
                break
        r.b.machine.input.key_event(vp.RIGHT, "k", False)
        shot(r.b, "06-duel.png")

        vp.play_floor(r)
        for _ in range(4):
            r.b.frame_tick()
        shot(r.b, "07-won.png")
        print("final", r.status(), "fault", r.fault())
        return 0 if not r.fault() else 1
    finally:
        r.close()


if __name__ == "__main__":
    raise SystemExit(main())
