#!/usr/bin/env python3
"""Move embedded game pictures into the existing art bank without changing the program.

Usage: python3 tools/prepare_port.py GAME.HTML --out NEW_DIRECTORY
Creates a new directory only. The original files are never overwritten.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import CompileError
from functional_model.jsb_format import ProgramImage, SOURCE_MAX, build_artx
from tools.compile_js import compile_html_text, encode_html_chunk, _extract_data_uri_sprites
from tools.make_artx import _source_sheets
from tools.make_artjs import artjs_for, shim_for


def prepare(source: Path, destination: Path, name: str | None = None) -> dict:
    if destination.exists():
        raise ValueError('Choose a new output directory; existing files will not be overwritten.')
    stem = (name or source.stem).upper()[:8]
    if not re.fullmatch(r'[A-Z0-9_]{1,8}', stem):
        raise ValueError('The card name must contain 1–8 ASCII letters, digits or underscores.')
    original = source.read_bytes().decode('utf-8')
    chunk = compile_html_text(original, source_path=source)
    gold = encode_html_chunk(chunk)
    if ProgramImage(gold).code_bram_overflow:
        raise ValueError('Compiled code/trailers already overflow program memory; extraction cannot fix that.')
    images = _source_sheets(original)
    if not images or len(images) != len(chunk.sprites or []) or any(im is None for im in images):
        raise ValueError('This helper needs decodable embedded game images; external art already uses the bank.')
    artx = build_artx(chunk.palette, chunk.sprites)
    rewritten, _ = _extract_data_uri_sprites(original)
    # Keep the preview and editable PNG manifest outside the native compiler.
    names = [f'{stem}-{i}.png' for i in range(len(images))]
    manifest = '<script data-host="chrome">window.JMR_SPR=' + json.dumps(names) + ';</script>\n'
    for match in re.finditer(r'<script([^>]*)>', rewritten, re.I):
        if re.search(r'data-host\s*=\s*["\x27]chrome["\x27]', match[1], re.I):
            continue
        rewritten = rewritten[:match.start()] + manifest + shim_for(stem) + rewritten[match.start():]
        break
    after = encode_html_chunk(compile_html_text(rewritten, artx=artx))
    if after != gold:
        raise ValueError('Extraction changes the compiled program or art; no output was written.')
    report = {
        'original': str(source.resolve()), 'output_name': stem,
        'original_source_bytes': len(original.encode('utf-8')),
        'prepared_source_bytes': len(rewritten.encode('utf-8')),
        'source_window_bytes': SOURCE_MAX,
        'prepared_source_fits_window': len(rewritten.encode('utf-8')) <= SOURCE_MAX,
        'image_sheets': len(images), 'art_bank_file_bytes': len(artx),
        'compiled_program_and_art_byte_identical': True,
        'program_sha256': hashlib.sha256(gold).hexdigest(),
        'scope': 'Asset extraction only. Language/runtime limits remain; on-machine compilation is not qualified by this check.',
    }
    destination.mkdir(parents=True)
    (destination/f'{stem}.HTML').write_text(rewritten, encoding='utf-8')
    (destination/f'{stem}.ARTX').write_bytes(artx)
    (destination/f'{stem}.ARTJS').write_text(artjs_for(artx), encoding='utf-8')
    for image, filename in zip(images, names):
        image.save(destination/filename, format='PNG')
    (destination/'CHECK.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--name')
    args = parser.parse_args()
    try:
        report = prepare(args.html, args.out, args.name)
    except (OSError, ValueError, CompileError) as error:
        parser.exit(1, f'{error}\n')
    print(f'Ready: {args.out.resolve()}')
    print(f'Source: {report["original_source_bytes"]:,} → {report["prepared_source_bytes"]:,} bytes; '
          f'{report["image_sheets"]} image sheets retained.')
    print('Compiled program and artwork are byte-for-byte identical to the original.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
