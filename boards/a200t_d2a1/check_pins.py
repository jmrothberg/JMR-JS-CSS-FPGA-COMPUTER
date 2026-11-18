#!/usr/bin/python3
"""Compare every XDC assignment with the ordered KiCad archive's U1 pads."""
import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

import pcbnew

root = Path(__file__).resolve().parents[2]
archive = Path(sys.argv[1])
out = root / "build/a200t_d2a1/pin_audit"
out.mkdir(parents=True, exist_ok=True)
native = "jmr_a200t_hyperram_d2.kicad_pcb"
with zipfile.ZipFile(archive) as z:
    (out / native).write_bytes(z.read(native))
board = pcbnew.LoadBoard(str(out / native))
footprints = {f.GetReference(): f for f in board.GetFootprints()}
assert footprints["U1"].GetValue() == "XC7A200T-1FBG484I"
assert footprints["U6"].GetValue() == "S80KS5122GABHI020"
pads = {p.GetNumber(): p.GetNetname() for p in footprints["U1"].Pads()}
xdc = (Path(__file__).parent / "pins.xdc").read_text()
assignments = re.findall(r"set_property PACKAGE_PIN (\S+) \[get_ports \{([^}]+)\}\]", xdc)
assert len(assignments) == 58, len(assignments)
records = []
for ball, port in assignments:
    net = re.sub(r"HR_DQ\[(\d)\]", r"HR_DQ\1", port)
    assert pads[ball] == net, (port, ball, pads[ball], net)
    standard = "LVCMOS18" if port.startswith("HR_") else "LVCMOS33"
    assert f"set_property IOSTANDARD {standard} [get_ports {{{port}}}]" in xdc
    records.append({"port": port, "fpga_ball": ball, "ordered_net": net, "standard": standard})
jtag = {p.GetNumber(): p.GetNetname() for p in footprints["J3"].Pads()}
assert jtag == {"1": "FPGA_3V3", "2": "GND", "3": "TCK", "4": "TMS", "5": "TDI", "6": "TDO"}
report = {"status": "PASS", "ordered_archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
          "pcb_sha256": hashlib.sha256((out / native).read_bytes()).hexdigest(),
          "fpga": footprints["U1"].GetValue(), "ram": footprints["U6"].GetValue(),
          "ports": records, "J3": jtag,
          "scope": "Firmware pin/net and voltage assignments; not a new PCB footprint qualification"}
(out / "pins.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"PIN_AUDIT_PASS {len(records)} FPGA ports and all six JTAG pins match the frozen ordered PCB")
