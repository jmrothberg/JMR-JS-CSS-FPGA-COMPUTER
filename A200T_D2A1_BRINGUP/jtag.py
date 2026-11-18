#!/usr/bin/env python3
"""Use the owner's FT2232 channel B; verify identity before SRAM loading."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def require_single_adapter(usb_root=Path('/sys/bus/usb/devices')):
    # Separate USB adapters can each expose a one-device A200T chain, so the
    # JTAG ID alone cannot distinguish this card from the owner's Vision.
    if not usb_root.is_dir():
        raise SystemExit('USB inventory unavailable. Use this loader on the prepared Linux computer.')
    adapters = []
    for device in usb_root.iterdir():
        try:
            identity = ((device/'idVendor').read_text().strip().lower(),
                        (device/'idProduct').read_text().strip().lower())
        except OSError:
            continue
        if identity == ('0403', '6010'):
            adapters.append(device)
    if len(adapters) != 1:
        raise SystemExit('Connect only the external FT2232 adapter for this card; disconnect other FT2232 USB data cables. Nothing loaded.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["check", "detect", "load"])
    args = parser.parse_args()
    base = Path(__file__).resolve().parent
    command = ["openFPGALoader", "-c", "ft2232", "--ftdi-channel", "1", "--freq", "1000000"]
    if args.action != "check":
        require_single_adapter()
        detected = subprocess.run(command + ["--detect"], text=True, capture_output=True)
        output = detected.stdout + detected.stderr
        print(output, end="")
        ids = re.findall(r"(?:idcode|id code)\s*(?:[:=]\s*)?(?:0x)?([0-9a-fA-F]{7,8})\b", output, re.I)
        if detected.returncode or len(ids) != 1 or int(ids[0], 16) & 0x0FFFFFFF != 0x03636093:
            raise SystemExit("Expected exactly one XC7A200T (ID 03636093). Nothing loaded.")
        if args.action == "detect":
            return
    manifest = json.loads((base / "MANIFEST.json").read_text())
    if manifest["status"] != "TIMING_QUALIFIED_PENDING_BOARD_TEST":
        raise SystemExit("This package is not ready for SRAM loading.")
    for name, digest in manifest["sha256"].items():
        path = base / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Package file missing or changed: {name}. Nothing loaded.")
    print("Package checksums match; target XC7A200T-FBG484, C3 motherboard.")
    if args.action == "load":
        subprocess.run(command + ["--fpga-part", "xc7a200tfbg484", str(base / "jmr_js_a200t_d2a1.bit")], check=True)


if __name__ == "__main__":
    main()
