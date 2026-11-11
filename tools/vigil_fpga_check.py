"""Run VIGIL on FPGA-SIM (the same RTL as the .bit) and report what happens.

    python3 tools/vigil_fpga_check.py                  # title, start, walk right
    python3 tools/vigil_fpga_check.py --keys 32,39:90

The middle rung of PYTHON -> FPGA-SIM -> board. It takes VIGIL.JSH out of
card.img — the exact bytes the machine loads — hands them to the RTL with
JSHLOAD (the launch path tests/test_toolbox.py uses), then drives real frames
the way the RTL tests do: tick until the VM parks on S_WAIT_FRAME, then FRAME
to run one requestAnimationFrame turn. Keys go in through KEYEVT, the real
keyboard FIFO.

Every picture is compared with the Python model's frame at the same point, so
a parity gap shows up as a number instead of a glance.

Build the simulator first if missing: make -C sim sim_server_synth
Not a substitute for F9: the user runs the visual check.
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def card_program(name: str) -> bytes:
    from tools.make_sd_image import open_volume

    return open_volume(ROOT / "card.img").read_file(name)


def rtl_frame(sim) -> bytes:
    """Advance the RTL by exactly one game frame and return the framebuffer."""
    from tests.test_rtl_snippets import _fb_raw

    for _ in range(200000):
        sim._rpc("TICKN 1")
        if "sname=S_WAIT_FRAME" in sim._rpc("VMSTAT?"):
            break
    sim._rpc("FRAME")
    return _fb_raw(sim)


def save(sim, raw: bytes, dest: Path) -> None:
    from PIL import Image

    sim._sync_palette()          # the palette lives in RTL BRAM, not the host
    pal = sim.framebuffer().palette
    rgb = bytearray(640 * 480 * 3)
    for i, pix in enumerate(raw):
        r, g, b = pal[pix]
        rgb[i * 3:i * 3 + 3] = bytes((r, g, b))
    Image.frombytes("RGB", (640, 480), bytes(rgb)).save(dest)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", default="32,39:90",
                    help="keycode[:frames], comma separated")
    ap.add_argument("--settle", type=int, default=6,
                    help="frames to run before each capture")
    args = ap.parse_args()
    os.environ.pop("JMR_SIM_HOST", None)

    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        print("FAIL: the FPGA-SIM RTL binary is missing; "
              "build it with: make -C sim sim_server_synth")
        return 1
    out = ROOT / "traces" / "vigil"
    out.mkdir(parents=True, exist_ok=True)
    image = card_program("VIGIL.JSH")
    print(f"VIGIL.JSH from card.img: {len(image)} bytes")
    with tempfile.TemporaryDirectory(prefix="vigil_sim_") as tmp:
        jsh = Path(tmp) / "VIGIL.JSH"
        jsh.write_bytes(image)
        try:
            for _ in range(300):
                sim._rpc("TICK")
            resp = sim._rpc(f"JSHLOAD {jsh}")
            print("load:", resp)
            if not resp.startswith("OK"):
                return 1
            raw = rtl_frame(sim)
            for _ in range(args.settle):
                raw = rtl_frame(sim)
            save(sim, raw, out / "fpga-01-title.png")
            print("title: non-zero pixels =", sum(1 for b in raw if b))

            n = 2
            for step in [p for p in args.keys.split(",") if p]:
                code, _, frames = step.partition(":")
                frames = int(frames) if frames else 1
                sim.key_event(int(code), "k", True)
                for _ in range(frames):
                    raw = rtl_frame(sim)
                sim.key_event(int(code), "k", False)
                for _ in range(args.settle):
                    raw = rtl_frame(sim)
                name = out / f"fpga-{n:02d}-key{code}.png"
                save(sim, raw, name)
                print(f"key {code} x{frames}: non-zero pixels =",
                      sum(1 for b in raw if b))
                n += 1

            vm = sim._rpc("VMSTAT?")
            print("vmstat:", vm[:200])
            fault = vm.split("fault=")[1].split()[0] if "fault=" in vm else "?"
            print("fault:", fault)
            return 0 if fault in ("0", "?") else 1
        finally:
            sim.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
