#!/usr/bin/env python3
"""Mint the self-hosted compiler chain (ARTSCAN / ARTPNG / COMPILER / MINTASM).

These are ordinary titles: HTML in storage/, minted to .JSH by the same
sidecar path every game uses, and executed by the same VM. That is the point
— the compiler is dogfooded by the pipeline it replaces, and once the ABI is
in silicon, improving it is shipping a new file, never a resynthesis.

    python3 tools/selfhost.py            # report sizes against the walls
    python3 tools/selfhost.py --write    # mint .JSH beside the sources
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.jsb_format import (  # noqa: E402
    COMPILE_CHAIN,
    PROGRAM_CODE_WORDS,
    PROGRAM_MAX_CONSTS,
    PROGRAM_MAX_NAMES,
    PROGRAM_MAX_VARS,
    PROGRAM_NAME_BYTES,
    ProgramImage,
)
from tools.compile_js import compile_html_text  # noqa: E402

STORAGE = ROOT / "storage"


def source_path(jsh_name: str) -> Path:
    return STORAGE / (Path(jsh_name).stem + ".HTML")


def mint(jsh_name: str) -> ProgramImage:
    """Compile one chain program and return its validated ProgramImage."""
    path = source_path(jsh_name)
    if not path.is_file():
        raise FileNotFoundError(path)
    chunk = compile_html_text(path.read_text(encoding="utf-8"))
    return ProgramImage.from_chunk(chunk, v2=True, value64=True)


def check(image: ProgramImage) -> list:
    """Every wall a chain program has to live inside, worst offender first."""
    words = -(-image.code_end // 4)
    return [
        ("code", words, PROGRAM_CODE_WORDS),
        ("consts", image.n_consts, PROGRAM_MAX_CONSTS),
        ("vars", image.n_vars, PROGRAM_MAX_VARS),
        ("names", len(image.names), PROGRAM_MAX_NAMES),
        ("namebytes", sum(len(n.encode()) for n in image.names), PROGRAM_NAME_BYTES),
    ]


def self_compile(title: str):
    """Compile a title THE WAY THE MACHINE DOES — chain programs on the VM.

    No host compiler is involved past minting the chain itself: ARTSCAN and
    COMPILER run as ordinary programs, reading the source through srcByte()
    and writing the image through stgWrite(). Returns the raw .JSH bytes.
    """
    from functional_model import jsb_format as jf
    from functional_model.machine import Machine
    from hardware_model.js_vm import JsHwVm

    src = (STORAGE / f"{title}.HTML").read_text(encoding="utf-8")
    m = Machine(storage_root=STORAGE)
    m._stage_source(src)
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 4_000_000_000
    for name in ("ARTSCAN.JSH", "COMPILER.JSH"):
        m._cmp_reset()
        hw.load_image(mint(name))
        if hw.error:
            raise RuntimeError(f"{name}: {hw.error}")
        if name == "ARTSCAN.JSH" and m._cmp_status != jf.CMP_STATUS_NEXT:
            raise RuntimeError(f"ARTSCAN refused: {m._cmp_message()}")
    if m._cmp_status != 0:
        raise RuntimeError(f"?CE {m._cmp_message()}")
    blob = m._cmp_output()
    ProgramImage(blob)  # the strict validator is the acceptance gate
    return blob


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="mint .JSH beside the sources")
    ap.add_argument(
        "--card",
        nargs="?",
        const=str(ROOT / "card.img"),
        help="patch the minted programs onto an existing card.img. Patches in "
        "place, one file at a time — it does NOT rebuild the card, so the "
        "titles already on it are untouched.",
    )
    ap.add_argument(
        "--selfcompile",
        nargs="+",
        metavar="TITLE",
        help="compile these titles ON THE MACHINE and patch the resulting "
        ".JSH onto the card, so the board runs machine-made bytecode. "
        "Back the card up first — --card writes in place.",
    )
    args = ap.parse_args()

    if args.selfcompile:
        from tools.make_sd_image import patch_card_file

        card = Path(args.card) if args.card else (ROOT / "card.img")
        rc = 0
        for title in args.selfcompile:
            try:
                blob = self_compile(title)
            except Exception as exc:
                print(f"{title:12s} FAIL  {exc}")
                rc = 1
                continue
            note = ""
            if card.is_file():
                patch_card_file(card, f"{title}.JSH", blob)
                note = f" -> {card.name}"
            print(f"{title:12s} OK    {len(blob)} bytes, machine-compiled{note}")
        return rc

    worst = 0.0
    rc = 0
    for name in COMPILE_CHAIN:
        if not source_path(name).is_file():
            print(f"{name:14s} -- not written yet")
            continue
        try:
            image = mint(name)
        except Exception as exc:  # a wall, or a syntax error in the program
            print(f"{name:14s} FAIL {type(exc).__name__}: {exc}")
            rc = 1
            continue
        parts = []
        for label, used, cap in check(image):
            frac = used / cap
            worst = max(worst, frac)
            flag = "!!" if used > cap else ""
            parts.append(f"{label} {used}/{cap} ({frac:.0%}){flag}")
            if used > cap:
                rc = 1
        print(f"{name:14s} OK  " + "  ".join(parts))
        if args.write:
            (STORAGE / name).write_bytes(image.data)
            print(f"{'':14s}    wrote storage/{name}")
        if args.card:
            from tools.make_sd_image import patch_card_file

            card = Path(args.card)
            if not card.is_file():
                print(f"{'':14s}    no card at {card}")
                rc = 1
                continue
            src = source_path(name)
            # The .JSH is what COMPILE chain-loads; the .HTML rides along so
            # these stay ordinary titles the machine could one day recompile.
            patch_card_file(card, src.name, src.read_bytes())
            patch_card_file(card, name, image.data)
            print(f"{'':14s}    patched {src.name} + {name} onto {card.name}")

    print(f"\nworst wall usage: {worst:.0%}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
