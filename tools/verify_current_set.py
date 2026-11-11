#!/usr/bin/env python3
"""Verify the current portable RTL, storage and disk set without modifying it."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def digest(path):
    h=hashlib.sha256()
    with path.open('rb')as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()

def verify(root=ROOT):
    root=Path(root).resolve();path=root/'CURRENT_SET.json'
    if not path.is_file():return ['CURRENT_SET.json is missing; this folder has no verified current set.'],None
    manifest=json.loads(path.read_text());errors=[]
    if manifest.get('schema')!=1:return ['Unsupported CURRENT_SET.json schema.'],manifest
    for name,expected in manifest['files'].items():
        p=(root/name).resolve()
        if not p.is_relative_to(root):errors.append('Invalid relative path: '+name);continue
        if not p.is_file():errors.append('Missing: '+name)
        elif digest(p)!=expected:errors.append('Different version: '+name)
    import sys;sys.path.insert(0,str(ROOT));from tools.update_current_set import git_ignored
    ignored=git_ignored(root)  # generated, git-ignored files are not part of the set
    for scope in manifest.get('strict_scopes',[]):
        base=root/scope;expected={n for n in manifest['files']if n.startswith(scope+'/')}
        actual={str(p.relative_to(root))for p in base.rglob('*')if p.is_file()and not any(v.startswith('.')or v=='__pycache__'for v in p.relative_to(base).parts)and p.suffix not in('.pyc','.pyo','.log','.vcd')and str(p.relative_to(root))not in ignored}
        for name in sorted(actual-expected):errors.append('Unlisted source: '+name)
    return errors,manifest

if __name__=='__main__':
    try:errors,m=verify()
    except (OSError,ValueError,KeyError)as e:raise SystemExit('FAIL: '+str(e))
    if errors:
        print('FAIL: source/storage/disk set is not matched.')
        for error in errors:print(' - '+error)
        raise SystemExit(1)
    print('PASS: '+m['set_id']+' RTL, storage, Toolbox and card.img match.')
    print('Compile source: rtl/; storage: storage/; disk: card.img.')
    if m.get('bitstream',{}).get('status')!='qualified':print('Bitstream qualification is still pending; this verifies the source set.')
