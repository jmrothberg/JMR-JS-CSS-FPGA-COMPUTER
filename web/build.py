#!/usr/bin/env python3
"""Assemble a static browser release from the verified project disk and model."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'
PYODIDE = '0.29.4'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def model_files():
    for folder in ('functional_model', 'hardware_model'):
        yield from (p for p in (ROOT / folder).glob('*') if p.suffix in ('.py', '.js'))
    for name in (
        'runtime/__init__.py', 'runtime/backend.py',
        'tools/build_system_resources.py', 'tools/compile_js.py', 'tools/toolbox_linker.py',
        'assets/desktop/chicago-12.json', 'assets/desktop/mac-arrow.json',
        'assets/desktop/enterprise-menu.json', 'resources/system/defaults.json',
        'vectors/toolbox_code.hex',
    ):
        yield ROOT / name


def build(out, origin):
    sys.path.insert(0, str(ROOT))
    from tools.verify_current_set import verify

    errors, manifest = verify(ROOT)
    if errors:
        raise ValueError('Match the source and disk first:\n' + '\n'.join(errors))
    card = ROOT / 'card.img'
    if digest(card) != manifest['files']['card.img']:
        raise ValueError('card.img differs from CURRENT_SET.json. Match the source and disk first.')
    build_number = manifest['set_id'].split('-', 1)[0].removeprefix('run')
    out.mkdir(parents=True, exist_ok=True)
    for name in ('app.js', 'worker.js', 'disk-store.js', 'psg.js', 'style.css', 'social.png', 'apple-touch-icon.png'):
        shutil.copyfile(WEB / name, out / name)
    shutil.copyfile(ROOT / 'assets/desktop/enterprise.webp', out / 'icon.webp')
    html = (WEB / 'index.html').read_text()
    (out / 'index.html').write_text(html.replace('__SITE_ORIGIN__', origin.rstrip('/')).replace('__BUILD__', build_number))
    with zipfile.ZipFile(out / 'computer.zip', 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
        for file in sorted(model_files()):
            bundle.write(file, file.relative_to(ROOT))
        bundle.write(WEB / 'browser-computer.py', 'browser_computer.py')
    with card.open('rb') as original, (out / 'card.img.gz').open('wb') as compressed:
        with gzip.GzipFile(fileobj=compressed, filename='', mode='wb', mtime=0) as stream:
            shutil.copyfileobj(original, stream)
    metadata = {
        'build': build_number,
        'pyodide': PYODIDE,
        'cardBytes': card.stat().st_size,
        'cardSHA256': manifest['files']['card.img'],
        'modelSHA256': digest(out / 'computer.zip'),
    }
    (out / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(f'Browser build {metadata["build"]} assembled in {out}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT / 'build' / 'browser-preview')
    parser.add_argument('--origin', default='http://127.0.0.1:8783')
    args = parser.parse_args()
    build(args.out.resolve(), args.origin)
