#!/usr/bin/env python3
"""Use the owner's FT2232 channel B; verify identity before programming."""
import argparse
from datetime import datetime
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
    parser.add_argument("action", choices=["check", "detect", "load", "flash"])
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
        raise SystemExit("This package is not ready for programming.")
    for name, digest in manifest["sha256"].items():
        path = base / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f"Package file missing or changed: {name}. Nothing loaded.")
    print("Package checksums match; target XC7A200T-FBG484, C3 motherboard.")
    command += ["--fpga-part", "xc7a200tfbg484"]
    bitstream = str(base / "jmr_js_a200t_d2a1.bit")
    if args.action == "load":
        subprocess.run(command + [bitstream], check=True)
    elif args.action == "flash":
        flash_size = 16 * 1024 * 1024
        backup = Path.cwd() / f"a200t-flash-backup-{datetime.now():%Y%m%d-%H%M%S-%f}.bin"
        subprocess.run(command + ["--dump-flash", "--file-size", str(flash_size), str(backup)], check=True)
        if not backup.is_file() or backup.stat().st_size != flash_size:
            raise SystemExit("Incomplete flash backup. Boot flash was not written.")
        print(f"Saved original boot flash to {backup}", flush=True)
        subprocess.run(command + ["--write-flash", "--offset", "0", "--verify", bitstream], check=True)
        print("Boot flash write verified. Power-cycle with JTAG disconnected to confirm standalone boot.")


if __name__ == "__main__":
    main()
