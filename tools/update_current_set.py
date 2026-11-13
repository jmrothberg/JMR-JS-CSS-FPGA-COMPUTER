#!/usr/bin/env python3
"""Rewrite CURRENT_SET.json from the files that are actually here.

CURRENT_SET.json is the hash list the GUI (tools/gui_runtime.py) and
tools/verify_current_set.py check: source, storage and card.img must match.
Run this after you change source or storage and rebuild card.img.
`python3 tools/make_sd_image.py create card.img` runs it for you.

    python3 tools/update_current_set.py
    python3 tools/update_current_set.py --set-id run96-current-source \\
        --bit build/run96_release/jmr_js_mac_run96.bit --wns 0.005 --whs 0.022 \\
        --synthesis build/run96b --placement build/run96b_Explore

It lists every file in the manifest's strict scopes (same filter as the
verifier, minus git-ignored generated files), keeps the other listed files that still exist, and re-hashes all
of them. With --bit it also replaces the bitstream record. It never changes
any file except CURRENT_SET.json.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
_IGNORED_SUFFIX = ('.pyc', '.pyo', '.log', '.vcd')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def git_ignored(root):
    """Files git ignores (generated, not in a clone); never listed."""
    try:
        out = subprocess.run(['git', '-C', str(root), 'ls-files', '-z', '--others', '--ignored',
                              '--exclude-standard'], capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return set()
    return {n for n in out.decode().split('\0') if n}


def scope_files(root, scope, ignored=frozenset()):
    base = root / scope
    for p in base.rglob('*'):
        rel = p.relative_to(base).parts
        name = str(p.relative_to(root))
        if p.is_file() and not any(v.startswith('.') or v == '__pycache__' for v in rel) \
                and p.suffix not in _IGNORED_SUFFIX and name not in ignored:
            yield name


def update(root=ROOT, set_id=None, bit=None, quiet=False):
    root = Path(root).resolve()
    path = root / 'CURRENT_SET.json'
    manifest = json.loads(path.read_text())
    scopes = manifest['strict_scopes']
    old = set(manifest['files'])
    names = {n for n in old
             if not any(n.startswith(s + '/') for s in scopes) and (root / n).is_file()}
    ignored = git_ignored(root)
    names -= ignored
    for scope in scopes:
        names.update(scope_files(root, scope, ignored))
    manifest['files'] = {n: digest(root / n) for n in sorted(names)}
    if set_id:
        manifest['set_id'] = set_id
    if bit:
        manifest['bitstream'] = bit
    path.write_text(json.dumps(manifest, indent=2) + '\n')
    if not quiet:
        print(f"CURRENT_SET.json: {len(names)} files, {len(names - old)} added, "
              f"{len(old - names)} dropped ({manifest['set_id']})")
        for n in sorted(old - names):
            print('  dropped ' + n)
    return manifest


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--set-id', help='name for this set, e.g. run96-current-source')
    ap.add_argument('--bit', help='qualified bitstream path, relative to the project')
    ap.add_argument('--wns', type=float, help='setup WNS (ns) from qualify_routed_bit.tcl')
    ap.add_argument('--whs', type=float, help='hold WHS (ns) from qualify_routed_bit.tcl')
    ap.add_argument('--synthesis', help='synthesis folder, e.g. build/run96b')
    ap.add_argument('--placement', help='placement folder, e.g. build/run96b_Explore')
    a = ap.parse_args(argv)
    bit = None
    if a.bit:
        if a.wns is None or a.whs is None:
            ap.error('--bit needs --wns and --whs')
        if a.wns < 0 or a.whs < 0:
            ap.error('timing is not met; a failing bit is not recorded')
        p = (ROOT / a.bit).resolve()
        if not p.is_file():
            ap.error('no such bit: ' + a.bit)
        bit = {'status': 'timing_qualified_pending_board_test', 'path': a.bit,
               'sha256': digest(p), 'setup_wns_ns': a.wns, 'hold_whs_ns': a.whs,
               'release_qualified': True, 'synthesis': a.synthesis, 'placement': a.placement,
               'built_from': f'{a.synthesis} synthesis, {a.placement} placement',
               'release_manifest': 'releases/standard.json'}
    update(set_id=a.set_id, bit=bit)
    return 0


if __name__ == '__main__':
    sys.exit(main())
