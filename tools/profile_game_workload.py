#!/usr/bin/env python3
"""Count game work in the serialized Value64 model; these are NOT RTL cycles.

Uses the product HTML mint and executes its words in JsHwVm. Does not modify
storage, card.img, game source, or RTL. Opcode source locations are translated
from the joined script bodies back to HTML lines. Run from any directory:

  python3 tools/profile_game_workload.py --output /tmp/game-workload.json

PACFAST auto-starts after two rAFs; Enter would PAUSE the measurement.
DNKF needs two separate Enter presses (title, then character selection).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.bytecode import Op
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm, value_is_number, value_unpack_number
from tools.compile_js import _js_line_to_html, compile_html_text, encode_html_chunk


class InstructionReads(list):
    """Observe only the interpreter's opcode fetch, excluding metadata reads."""

    def __init__(self, words, hw, names):
        super().__init__(words)
        self.hw, self.names = hw, names
        self.clear_counts()

    def clear_counts(self):
        self.ops, self.ips = Counter(), Counter()
        self.methods, self.arithmetic = Counter(), Counter()

    def __getitem__(self, index):
        word = super().__getitem__(index)
        hw = self.hw
        if (not isinstance(index, int)
                or not hw.ops_base <= index < hw.ops_base + hw.n_ops
                or sys._getframe(1).f_code.co_name != '_execute_value64_words'):
            return word
        op = Op(word & 255)
        self.ops[op.name] += 1
        self.ips[index - hw.ops_base] += 1
        if op == Op.CALL_METHOD:
            self.methods[self.names[(word >> 8) & 65535]] += 1
        if op in (Op.MUL, Op.DIV, Op.MOD) and len(hw._value_stack) >= 2:
            aa, bb = hw._value_stack[-2:]
            if value_is_number(aa) and value_is_number(bb):
                a, b = value_unpack_number(aa), value_unpack_number(bb)
                self.arithmetic[op.name + '_numeric'] += 1
                if a and b and math.isfinite(a) and math.isfinite(b):
                    self.arithmetic[op.name + '_finite_nonzero'] += 1
                    if math.frexp(abs(a))[0] == 0.5:
                        self.arithmetic[op.name + '_lhs_power2'] += 1
                    if math.frexp(abs(b))[0] == 0.5:
                        self.arithmetic[op.name + '_rhs_power2'] += 1
                    if (a.is_integer() and b.is_integer()
                            and abs(a) < 2**24 and abs(b) < 2**24):
                        self.arithmetic[op.name + '_small_int_pair'] += 1
        return word


def profile(stem):
    path = ROOT / 'storage' / (stem + '.HTML')
    html = path.read_text()
    chunk = compile_html_text(html, source_path=path)
    image = ProgramImage(encode_html_chunk(chunk))
    spans = []
    for match in re.finditer(r'<script([^>]*)>(.*?)</script>', html, re.S | re.I):
        if re.search(r'''data-host\s*=\s*["']chrome["']''', match.group(1), re.I):
            continue
        spans.append((html[:match.start(2)].count('\n') + 1,
                      match.group(2).count('\n') + 1))
    hw = JsHwVm()
    hw.load_image(image)
    memory = InstructionReads(hw.code_mem, hw, chunk.names)
    hw.code_mem = memory
    result = {
        'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'program_sha256': hashlib.sha256(bytes(image)).hexdigest(),
        'n_ops': image.n_ops, 'image_bytes': len(bytes(image)),
        'code_bytes': image.code_end,
        'code_bram_overflow_words': image.code_bram_overflow,
        'initialization_error': hw.error, 'phases': [],
    }

    def phase(label, frames, enter=False):
        memory.clear_counts()
        per_frame = []
        original_collect = hw._value64_collect
        gc_calls = 0

        def collect(*args, **kwargs):
            nonlocal gc_calls
            gc_calls += 1
            return original_collect(*args, **kwargs)

        hw._value64_collect = collect
        try:
            for frame in range(frames):
                if hw.error:
                    break
                if enter and frame == 0:
                    hw.input.key_event(13, 'Enter', True)
                if enter and frame == 1:
                    hw.input.key_event(13, 'Enter', False)
                before = sum(memory.ops.values())
                hw.frame_tick()
                per_frame.append(sum(memory.ops.values()) - before)
        finally:
            hw._value64_collect = original_collect
        lines = Counter()
        for ip, count in memory.ips.items():
            if chunk.op_lines:
                lines[_js_line_to_html(spans, chunk.op_lines[ip])] += count
        r = {
            'label': label, 'frames': len(per_frame),
            'total_ops': sum(memory.ops.values()), 'ops_per_frame': per_frame,
            'ops': dict(memory.ops), 'methods': dict(memory.methods),
            'arithmetic': dict(memory.arithmetic),
            'html_line_ops': dict(sorted(lines.items())),
            'gc_calls': gc_calls, 'error': hw.error,
            'raf_pending': len(hw._value_raf),
            'objects_live': sum(x is not None for x in hw._value_objects),
            'arrays_live': sum(x is not None for x in hw._value_arrays),
        }
        result['phases'].append(r)
        mean = r['total_ops'] / max(1, len(per_frame))
        print(f'{stem} {label}: {mean:.1f} ops/frame, error={hw.error}', flush=True)

    phase('startup_auto_start_for_pacman', 3)
    if stem == 'DNKF':
        phase('enter_title', 4, enter=True)
        phase('enter_character', 4, enter=True)
    phase('early_play_no_held_input', 30)
    phase('later_play_no_held_input', 90)
    if stem == 'DNKF':
        phase('first_barrel_window_no_held_input', 150)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    revision = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    report = {
        'revision': revision,
        'measurement': 'Serialized Value64 instruction counts, not RTL cycles or FPS',
        'limitations': [
            'Fresh product mint from HTML/ARTX; profiling bypasses the card delivery path.',
            'No held movement inputs; longer sessions and dense barrels need separate replay.',
            'Python GC calls are model behavior, not measurements of RTL GC scheduling.',
            'Only bytecode MUL is counted; Canvas transforms/raster math are separate.',
        ],
        'titles': {stem: profile(stem) for stem in ('PACFAST', 'DNKF')},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
