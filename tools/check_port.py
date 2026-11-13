#!/usr/bin/env python3
"""Check a game's compiled size and known static porting limits without changing it.

Usage: python3 tools/check_port.py path/to/GAME.HTML [--json]
This is a compile/layout preflight, not a runtime compatibility qualification.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.bytecode import Op
from functional_model.compiler import CompileError
from functional_model.jsb_format import (
    ProgramImage, PROGRAM_CODE_WORDS, PROGRAM_MAX_CONSTS, PROGRAM_MAX_VARS,
    PROGRAM_MAX_NAMES, PROGRAM_MAX_CLASSES, PROGRAM_MAX_METHODS,
    PROGRAM_MAX_SPRITES, PROGRAM_NAME_BYTES, SOURCE_MAX, CART_MAX_BYTES,
)
from tools.compile_js import compile_html_text, encode_html_chunk


def check(path: Path) -> dict:
    report = {'file': str(path.resolve()), 'errors': [], 'warnings': []}
    raw = path.read_bytes()
    if len(raw) > SOURCE_MAX:
        report['warnings'].append(
            f'Source is {len(raw):,} bytes; the on-machine editor/compiler window is '
            f'{SOURCE_MAX:,}. Host minting can still fit if the compiled image fits.')
    chunk = compile_html_text(raw.decode('utf-8'), source_path=path)
    image = ProgramImage(encode_html_chunk(chunk))
    report['usage'] = {
        'source_bytes': len(raw), 'code_bytes_including_trailers': image.code_end,
        'instructions': image.n_ops, 'constants': image.n_consts,
        'variables': image.n_vars, 'names': len(image.names),
        'name_bytes': sum(len(n.encode('utf-8')) for n in image.names),
        'classes': len(image.classes), 'image_sheets': len(chunk.sprites or []),
        'art_pixel_bytes': sum(w*h for w, h, _ in chunk.sprites or []),
        'product_image_bytes': len(image.data),
    }
    report['limits'] = {
        'source_bytes': SOURCE_MAX, 'code_bytes_including_trailers': PROGRAM_CODE_WORDS*4,
        'constants': PROGRAM_MAX_CONSTS, 'variables': PROGRAM_MAX_VARS,
        'names': PROGRAM_MAX_NAMES, 'name_bytes': PROGRAM_NAME_BYTES,
        'classes': PROGRAM_MAX_CLASSES, 'methods_per_class': PROGRAM_MAX_METHODS,
        'image_sheets': PROGRAM_MAX_SPRITES, 'art_bank_bytes': CART_MAX_BYTES,
        'locals_per_function': 16,
        'live_objects': 960, 'properties_per_object': 32,
        'short_arrays': 1536, 'short_array_elements': 32,
        'long_arrays': 12, 'long_array_elements': 128, 'environments': 384,
    }
    if image.code_bram_overflow:
        report['errors'].append(
            f'Compiled code and trailers exceed program memory by '
            f'{image.code_bram_overflow*4:,} bytes. The board drops that tail; reduce '
            'compiled size or qualify a larger program-memory design before use.')
    for ins in chunk.code:
        if ins[0] == Op.CALL_NATIVE and chunk.names[ins[1]] == 'Object.keys':
            report['errors'].append('Object.keys / for-in compiles but lacks its FPGA execution path.')
            break
    # STORE_VAR / LET_VAR / LOAD_VAR carry a 9-bit variable slot in the RTL
    # (jmr_js_vm_exec64.sv faults 5 above it), so every variable a program
    # touches, the resident Toolbox's included, must sit in slots 0..511.
    slot = {n: i for i, n in enumerate(image.var_names)}
    used = [slot.get(chunk.names[ins[1]], -1) for ins in chunk.code
            if ins[0] in (Op.STORE_VAR, Op.LET_VAR, Op.LOAD_VAR)]
    top = max(used, default=-1)
    report['usage']['variable_slots'] = top + 1
    report['limits']['variable_slots'] = 512
    if top >= 512:
        report['errors'].append(
            f'Global variables need {top + 1} slots; the VM has 512 (with the Toolbox\'s '
            'own). Fault 5 when the program starts: merge or localize globals.')
    if len(chunk.sprites or []) > PROGRAM_MAX_SPRITES:
        report['errors'].append('More than 16 image sheets: combine related poses into atlases.')
    report['scope'] = 'Compile/layout checks only; live heap peaks and runtime APIs still need FPGA-SIM testing.'
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('html', type=Path)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        report = check(args.html)
    except (OSError, ValueError, RuntimeError, SyntaxError, CompileError) as error:
        line = getattr(error, 'line', 0)
        message = f'HTML line {line}: {error}' if line else str(error)
        report = {'file': str(args.html), 'errors': [message], 'warnings': []}
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(report['file'])
        for key, value in report.get('usage', {}).items():
            print(f'  {key}: {value:,}')
        for kind in ('errors', 'warnings'):
            for message in report[kind]:
                print(f'  {kind[:-1].upper()}: {message}')
        print(report.get('scope', 'Compilation did not complete.'))
    return int(bool(report['errors']))


if __name__ == '__main__':
    raise SystemExit(main())
