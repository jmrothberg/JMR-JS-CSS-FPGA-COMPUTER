#!/usr/bin/env python3
"""Replay old/new serialized native-JS games and require identical pixels/state.

No browser or host JavaScript engine. Source comes from the requested Git
baseline and storage/, art comes from the unchanged product asset banks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from hardware_model.js_vm import JsHwVm, value_kind, value_payload, value_is_number
from functional_model.jsb_format import ProgramImage
from tools.compile_js import compile_html_text, encode_html_chunk


def field(hw, handle, key):
    names = hw._value_strings
    if key not in names:
        return None
    if value_kind(handle) not in (5, 8):
        return None
    obj = hw._value_objects[value_payload(handle)]
    return obj.get(names.index(key)) if obj is not None else None


def array(hw, handle):
    if handle is None or value_kind(handle) != 6:
        return []
    return hw._value_arrays[value_payload(handle)] or []


def scalar(hw, value):
    return None if value is None else hw._value64_host_value(value)


def fields(hw, handle, keys):
    return {key: scalar(hw, field(hw, handle, key)) for key in keys}


def global_value(hw, key):
    names = hw.program_image.var_names
    return hw._value_vars[names.index(key)] if key in names else None


def pac_stages(hw):
    names = hw._value_strings
    keys = [names.index(k) for k in ('_params', '_settings', 'maps', 'items', 'index')]
    found = []
    for index, obj in enumerate(hw._value_objects):
        if obj is not None and all(key in obj for key in keys):
            found.append((int(scalar(hw, obj[keys[-1]])), obj))
    return sorted(found, key=lambda entry: entry[0])


def pac_state(hw, all_maps=False):
    names = hw._value_strings
    result = {'globals': {k: scalar(hw, global_value(hw, k))
                          for k in ('_SCORE', '_LIFE', '_LEVEL')}, 'stages': []}
    for index, obj in pac_stages(hw):
        status = scalar(hw, obj[names.index('status')])
        if not all_maps and not status:
            continue
        stage = {'index': index, 'status': status, 'maps': [], 'actors': []}
        for handle in array(hw, obj[names.index('maps')]):
            data = [[scalar(hw, cell) for cell in array(hw, row)]
                    for row in array(hw, field(hw, handle, 'data'))]
            stage['maps'].append(data)
        for handle in array(hw, obj[names.index('items')]):
            actor = fields(hw, handle, ('x', 'y', 'status', 'orientation', 'timeout', 'times'))
            # Handles can change allocation identities; compare semantic fields.
            for key in ('coord', 'vector'):
                nested = field(hw, handle, key)
                if nested is not None and value_kind(nested) == 5:
                    actor[key] = fields(hw, nested, ('x', 'y', 'offset', 'change'))
            stage['actors'].append(actor)
        result['stages'].append(stage)
    return result


def donkey_state(hw):
    game = global_value(hw, 'game')
    result = {'globals': {k: scalar(hw, global_value(hw, k))
                          for k in ('gameState', 'character', 'paused')},
              'game': fields(hw, game, ('score', 'lives', 'highScore'))}
    for key in ('mario', 'dk'):
        result[key] = fields(hw, field(hw, game, key),
                             ('x', 'y', 'force', 'speed', 'isJumping',
                              'isClimbingDown', 'jumpHeight', 'isThrowing'))
    result['barrels'] = [fields(hw, b, ('x', 'y', 'force', 'left', 'right',
                                       'scored', 'hasScored', 'dead'))
                         for b in array(hw, field(hw, game, 'barrels'))]
    return result


def verify(stem, baseline, frames, pac_levels=False):
    path = ROOT / 'storage' / (stem + '.HTML')
    before = subprocess.check_output(
        ['git', 'show', f'{baseline}:storage/{stem}.HTML'], cwd=ROOT, text=True)
    sources = (before, path.read_text())
    if pac_levels:
        assert stem == 'PACFAST'
        # Exercise the game's real reset/transition methods on every maze,
        # then its final screen and Enter restart. Identical native JS driver
        # is inserted into both versions; product source remains untouched.
        driver = '''
var _verifyFrame=0;
function _verifyLevels(){
    if(_verifyFrame<480&&_verifyFrame%40===10)
        game.setStage(1+Math.floor(_verifyFrame/40));
    if(_verifyFrame===490) game.setStage(13);
    _verifyFrame=_verifyFrame+1;
    requestAnimationFrame(_verifyLevels);
}
requestAnimationFrame(_verifyLevels);
'''
        sources = tuple(s.replace('\tgame.init();', '\tgame.init();\n'+driver, 1)
                        for s in sources)
    vms = []
    for source in sources:
        image = ProgramImage(encode_html_chunk(compile_html_text(source, source_path=path)))
        hw = JsHwVm()
        hw.load_image(image)
        assert not hw.error, (stem, hw.error)
        vms.append(hw)
    state = pac_state if stem == 'PACFAST' else donkey_state
    initial = [state(hw, all_maps=True) if stem == 'PACFAST' else state(hw) for hw in vms]
    assert initial[0] == initial[1], (stem, 'initial game/level geometry differs')
    digest = hashlib.sha256()
    # Physical key events, including held movement, jump/climb, pause/resume.
    events = ({5: (39, 'ArrowRight', True), 40: (39, 'ArrowRight', False),
               41: (38, 'ArrowUp', True), 80: (38, 'ArrowUp', False),
               90: (13, 'Enter', True), 91: (13, 'Enter', False),
               94: (13, 'Enter', True), 95: (13, 'Enter', False),
               100: (37, 'ArrowLeft', True), 140: (37, 'ArrowLeft', False)}
              if stem == 'PACFAST' else
              {3: (13, 'Enter', True), 4: (13, 'Enter', False),
               7: (13, 'Enter', True), 8: (13, 'Enter', False),
               15: (68, 'd', True), 55: (32, ' ', True), 56: (32, ' ', False),
               85: (68, 'd', False), 90: (65, 'a', True), 125: (65, 'a', False),
               140: (87, 'w', True), 160: (87, 'w', False),
               180: (80, 'p', True), 181: (80, 'p', False),
               190: (80, 'p', True), 191: (80, 'p', False)})
    if pac_levels:
        events = {520: (13, 'Enter', True), 521: (13, 'Enter', False)}
    for frame in range(frames):
        for hw in vms:
            if frame in events:
                hw.input.key_event(*events[frame])
            hw.frame_tick()
            assert not hw.error, (stem, frame, hw.error)
        images = [bytes(hw.canvas.back) for hw in vms]
        assert images[0] == images[1], (stem, frame, 'framebuffer mismatch',
                                      sum(a != b for a, b in zip(*images)))
        snapshots = [state(hw) for hw in vms]
        assert snapshots[0] == snapshots[1], (stem, frame, 'game-state mismatch')
        digest.update(images[1])
        if frame % 60 == 0:
            print(f'{stem}: frame {frame} pixels and state identical', flush=True)
    return {'frames': frames, 'pixel_state_parity': True,
            'scenario': 'all_12_levels_final_screen_restart' if pac_levels else 'input_replay',
            'framebuffer_sequence_sha256': digest.hexdigest(),
            'all_initial_levels_equal': True,
            'source_sha256': hashlib.sha256(sources[1].encode()).hexdigest(),
            'baseline_source_sha256': hashlib.sha256(sources[0].encode()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-ref', default='38b6da1')
    parser.add_argument('--frames', type=int, default=300)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pac-levels', action='store_true',
                        help='Drive all 12 Pac-Man levels, final screen, and restart (>=540 frames)')
    args = parser.parse_args()
    if args.pac_levels:
        assert args.frames >= 540, 'all-level scenario needs at least 540 frames'
    results = {stem: verify(stem, args.baseline_ref, args.frames, args.pac_levels)
               for stem in (('PACFAST',) if args.pac_levels else ('PACFAST', 'DNKF', 'DNKFAST'))}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'baseline': args.baseline_ref, 'titles': results}, indent=2)+'\n')


if __name__ == '__main__':
    main()
