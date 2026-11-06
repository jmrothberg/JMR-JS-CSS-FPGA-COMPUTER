"""Inventory actual shipped consumers before removing their hardware services."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def inventory(release_audit):
    programs = json.loads(Path(release_audit).read_text())["programs"]
    result = []
    for program in programs:
        path = ROOT / program["frozen_source"]
        source = path.read_text()
        properties = sorted(set(re.findall(
            r"\.(systemWindow|systemViewport|systemAbout|systemMenus|systemTitle|"
            r"systemMenuEnable|systemMenuCheck|windowDirty|windowScrollX|windowScroll)\b", source)))
        roles = re.findall(r"\.systemWindow\s*=\s*([^;\n]+)", source)
        result.append({
            "disk_program": program["name"], "source": program["frozen_source"],
            "roles": roles, "legacy_properties": properties,
            "resident_before_migration": "jmr-toolbox: resident-v1" in source,
            "source_document": bool(re.search(r"\bsrc(Byte|Write|Len|SetLen)\s*\(", source)),
            "completion_handoff": bool(re.search(r"\bcdone\s*\(", source)),
            "uses_canvas_transform": bool(re.search(r"\.(setTransform|translate|save|restore)\s*\(", source)),
            "migration_status": "pending" if properties else "inspect bootstrap/tool lifecycle",
        })
    return {"baseline": str(release_audit), "program_count": len(result),
            "hardware_ui_consumers": sum(bool(p["legacy_properties"]) for p in result),
            "resident_before_migration": sum(p["resident_before_migration"] for p in result),
            "programs": result}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-audit", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result = inventory(args.release_audit)
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print({k: v for k, v in result.items() if k != "programs"})
