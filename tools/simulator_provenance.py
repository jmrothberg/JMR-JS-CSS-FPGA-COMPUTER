"""Fail closed when the default RTL simulator no longer matches its inputs."""
from pathlib import Path
import hashlib
import json
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs(root):
    paths = {root / 'sim/sim_main.cpp', root / 'sim/Makefile'}
    paths.update(p for p in (root / 'rtl').rglob('*') if p.suffix in ('.sv', '.v', '.vh', '.svh'))
    paths.update((root / 'vectors').glob('*.hex'))
    paths.update((root / 'sim').glob('*.hex'))
    return {str(p.relative_to(root)): digest(p) for p in sorted(paths)}


def verify(root, binary):
    root, binary = Path(root).resolve(), Path(binary).resolve()
    try:
        receipt = json.loads(binary.with_suffix('.provenance.json').read_text())
        if receipt['sha256'] != digest(binary):
            raise ValueError('binary differs from its build receipt')
        current = inputs(root)
        if receipt['inputs'] != current:
            changed = sorted(k for k in set(current) | set(receipt['inputs'])
                             if current.get(k) != receipt['inputs'].get(k))
            raise ValueError('changed inputs: ' + ', '.join(changed[:5]))
    except (OSError, ValueError, KeyError) as error:
        raise RuntimeError('FPGA-SIM is missing or stale: ' + str(error) +
                           '. Rebuild with make -C sim sim_server_synth -B.') from error
    return receipt


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    mode, filename = sys.argv[1:3]
    binary = Path(filename).resolve()
    pending = binary.with_suffix('.inputs.json')
    if mode == 'begin':
        pending.write_text(json.dumps(inputs(root), indent=2) + '\n')
    elif mode == 'finish':
        before = json.loads(pending.read_text())
        if before != inputs(root):
            raise SystemExit('Simulator inputs changed during compilation; refusing receipt.')
        binary.with_suffix('.provenance.json').write_text(json.dumps({
            'schema': 1, 'sha256': digest(binary), 'inputs': before,
            'origin': 'canonical Verilator build'}, indent=2) + '\n')
    elif mode == 'verify':
        verify(root, binary)
        print('PASS: simulator binary, root RTL and startup hex match.')
    else:
        raise SystemExit('Expected begin, finish or verify')
