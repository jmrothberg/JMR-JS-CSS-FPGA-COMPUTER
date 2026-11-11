#!/usr/bin/env python3
"""Mint the self-hosted compiler chain (ARTSCAN / ARTPNG / COMPILER / MINTASM).

These are ordinary titles: HTML in storage/, minted to .JSH by the same
sidecar path every game uses, and executed by the same VM. That is the point
— the compiler is dogfooded by the pipeline it replaces, and once the ABI is
in silicon, improving it is shipping a new file, never a resynthesis.

    python3 tools/selfhost.py            # report sizes against the walls
    python3 tools/selfhost.py --write    # mint .JSH beside the sources + COMPILE.LNK
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
    chunk = compile_html_text(path.read_text(encoding="utf-8"), source_path=path)
    return ProgramImage.from_chunk(chunk, v2=True, value64=True)


def card_image(jsh_name: str) -> bytes:
    """The .JSH bytes tools/make_sd_image.py mints for this chain program."""
    from tools.compile_js import encode_html_chunk

    path = source_path(jsh_name)
    return encode_html_chunk(
        compile_html_text(path.read_text(encoding="utf-8"), sound=True, source_path=path))


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


STAGE_MAGIC = 1129136970  # "JLNC": COMPILE.LNK, the chain's stage manifest


def stage_manifest(compiler: bytes, compil2: bytes) -> bytes:
    """COMPILE.LNK for these two stage images.

    COMPILER checks both stage files against it before tokenizing and again
    before emitting, so a re-minted stage without a matching manifest fails
    every machine compile with ?CE STAGE2. The version word is the one both
    stage sources test for.
    """
    import re
    import struct
    import zlib

    text = (STORAGE / "COMPIL2.HTML").read_text(encoding="utf-8")
    version = int(re.search(r"_r32\(stageScratch\+4\)!==(\d+)", text).group(1))
    body = struct.pack("<6I", STAGE_MAGIC, version, len(compiler), zlib.crc32(compiler),
                       len(compil2), zlib.crc32(compil2))
    return body + struct.pack("<I", zlib.crc32(body))


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
    m.source_name = f"{title}.HTML"
    m._stage_source(src)
    m._preload_art()
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 4_000_000_000
    # The console runs the program PROGSEL names until one stops asking for
    # the next: ARTSCAN -> COMPILER -> COMPIL2 -> COMPILER.
    sel = jf.COMPILE_ENTRY
    images = {}
    for _ in range(len(COMPILE_CHAIN) * 4):
        name = COMPILE_CHAIN[sel]
        if name not in images:
            images[name] = mint(name)
        m._cmp_reset()
        hw.load_image(images[name])
        if hw.error:
            raise RuntimeError(f"{name}: {hw.error}")
        if name == "ARTSCAN.JSH" and m._cmp_status != jf.CMP_STATUS_NEXT:
            raise RuntimeError(f"ARTSCAN refused: {m._cmp_message()}")
        if m._cmp_status != jf.CMP_STATUS_NEXT:
            break
        sel = int(m.sram.mem[jf.cstg_word(jf.CSTG_HDR_PROGSEL) * 2])
        if sel >= len(COMPILE_CHAIN):
            raise RuntimeError(f"PROGSEL {sel} out of range")
    else:
        raise RuntimeError("compile chain did not terminate")
    if m._cmp_status not in (0, jf.CMP_STATUS_MINT_ART):
        raise RuntimeError(f"?CE {m._cmp_message()}")
    blob = m._cmp_output()
    if m._cmp_status == jf.CMP_STATUS_MINT_ART:
        blob = m._append_artx(blob)
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
    minted = {}
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
        if args.write or args.card:
            # The card builder's bytes: COMPILE.LNK must describe exactly the
            # stage images a card carries.
            minted[name] = card_image(name)
        if args.write:
            (STORAGE / name).write_bytes(minted[name])
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
            patch_card_file(card, name, minted[name])
            print(f"{'':14s}    patched {src.name} + {name} onto {card.name}")

    if "COMPILER.JSH" in minted and "COMPIL2.JSH" in minted:
        lnk = stage_manifest(minted["COMPILER.JSH"], minted["COMPIL2.JSH"])
        if args.write:
            (STORAGE / "COMPILE.LNK").write_bytes(lnk)
            print(f"{'':14s}    wrote storage/COMPILE.LNK")
        if args.card:
            from tools.make_sd_image import patch_card_file

            patch_card_file(Path(args.card), "COMPILE.LNK", lnk)

    print(f"\nworst wall usage: {worst:.0%}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
