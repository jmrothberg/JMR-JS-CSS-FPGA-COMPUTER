#!/usr/bin/env python3
"""Build native RTL against the real DDR bridge and a modeled MIG application port.

Uses a private source overlay; never modifies product RTL or the board project.
The MIG model is always ready with a 25-cycle read delay. The RPC harness does
not drive live HDMI scanout, so this is latency sensitivity, not board FPS.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref', help='Use RTL from this local Git revision')
    parser.add_argument('--build', required=True, help='Unique directory name under sim/')
    args = parser.parse_args()
    if Path(args.build).name != args.build or args.build in ('.', '..'):
        parser.error('--build must be a directory name without path components')
    overlay = ROOT / 'build' / 'ddr_latency' / args.build
    overlay.mkdir(parents=True, exist_ok=True)

    def source(path):
        if args.ref:
            return subprocess.check_output(
                ['git', 'show', f'{args.ref}:{path.relative_to(ROOT)}'], cwd=ROOT)
        return path.read_bytes()

    bridge = source(ROOT / 'rtl/engines/jmr_ddr3_sram_bridge.sv')
    model = (ROOT / 'sim/jmr_sram_ddr_model.sv').read_bytes() + b'\n' + bridge
    for path in (ROOT / 'rtl').rglob('*'):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT / 'rtl')
        target = overlay / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() or target.is_symlink():
            target.unlink()
        if relative.as_posix() == 'engines/jmr_sram_model.sv':
            target.write_bytes(model)
        elif args.ref and path.suffix == '.sv':
            target.write_bytes(source(path))
        else:
            target.symlink_to(path)
    subprocess.run(['make', '-C', str(ROOT / 'sim'), 'sim_server_synth',
                    f'RTL={overlay}', f'BUILD={args.build}'], check=True)


if __name__ == '__main__':
    main()
