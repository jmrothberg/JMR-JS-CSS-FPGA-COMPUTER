#!/usr/bin/env python3
"""Measure native RTL frame cycles from a serialized product JSH.

Uses the real Verilator binary with its behavioral external-memory model.
Cycle-derived FPS is a simulation estimate, not a board/MIG measurement.
"""
from __future__ import annotations
import argparse
import base64
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import runtime.sim_backend as backend
from runtime.backend import parse_status_kv


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    parser.add_argument('--family', choices=('pacman', 'donkey'), required=True)
    parser.add_argument('--sim-bin', type=Path)
    parser.add_argument('--memory-model', default='SRAM_INTERNAL=1; no real MIG latency',
                        help='Describe the memory model compiled into this binary')
    parser.add_argument('--frames', type=int, default=12)
    parser.add_argument('--warmup', type=int, help='Override startup frames for sustained-play measurements')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--screenshot', type=Path, help='Export the final native RTL framebuffer')
    args = parser.parse_args()
    if args.sim_bin:
        backend._SYNTH = args.sim_bin.resolve()
    sim = backend.SimBackend()
    assert sim.available and sim._use_rtl
    rows = []
    try:
        assert sim._rpc('JSHLOAD ' + str(args.image.resolve())).startswith('OK')
        warmup = args.warmup if args.warmup is not None else (5 if args.family == 'pacman' else 10)
        for frame in range(warmup + args.frames):
            if args.family == 'donkey' and frame in (3, 7):
                sim._rpc('KEYEVT 13 1')
            if args.family == 'donkey' and frame in (4, 8):
                sim._rpc('KEYEVT 13 0')
            sim._rpc('FRAME')
            raw = sim._rpc('VMSTAT?')
            status = parse_status_kv(raw)
            assert status.get('fault') == 0, raw
            assert status.get('fcap') == 0, raw
            print(f'frame {frame}: {status.get("fclk")} fabric cycles, '
                  f'GC={status.get("gc")}', flush=True)
            if frame == warmup - 1:
                sim._rpc('STATEHIST?')
            if frame >= warmup:
                rows.append({k: status.get(k) for k in
                             ('fclk', 'gc', 'obj', 'arr', 'rafcall', 'swaps', 'fault', 'fcap')})
        hist = sim._rpc('STATEHIST?')
        if args.screenshot:
            from PIL import Image
            raw = sim._rpc('FB?')
            assert raw.startswith('FB 640 480 '), raw[:80]
            pixels = base64.b64decode(raw.split(None, 3)[3])
            palette = base64.b64decode(sim._rpc('PAL?')[4:])
            shot = Image.frombytes('P', (640, 480), pixels)
            shot.putpalette(palette)
            args.screenshot.parent.mkdir(parents=True, exist_ok=True)
            shot.convert('RGB').save(args.screenshot)
    finally:
        sim.shutdown()
    cycles = [row['fclk'] for row in rows]
    report = {
        'image': str(args.image), 'sim_binary': str(backend._SYNTH),
        'memory_model': args.memory_model,
        # Keep the existing *_core_cycles keys for campaign readers; fclk
        # counts the 100 MHz fabric, including the divided native VM.
        'cycle_domain': '100 MHz fabric',
        'core_hz': 100_000_000, 'vm_divisor': 7,
        'frames': rows, 'state_histogram': hist,
        'median_core_cycles': statistics.median(cycles),
        'p95_core_cycles': sorted(cycles)[max(0, int(len(cycles)*0.95)-1)],
        'max_core_cycles': max(cycles),
        'estimated_fps_from_median': 100_000_000 / statistics.median(cycles),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(f'median {report["median_core_cycles"]} fabric cycles; '
          f'{report["estimated_fps_from_median"]:.2f} FPS estimate', flush=True)


if __name__ == '__main__':
    main()
