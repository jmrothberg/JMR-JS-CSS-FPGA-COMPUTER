#!/usr/bin/env python3
"""Start a local web server for both browser versions of the JMR JS Computer.

  python3 web/serve.py            serve, then open either link it prints
  python3 web/serve.py --build    rebuild the full machine first (web/build.py)

Fast version: web/native.html runs the Finder, Toolbox and program source
directly in Chrome. It reads card.img, storage/ and resources/toolbox/ from
this checkout, so it needs no build.

Full machine: build/browser-preview runs the Python hardware model in
WebAssembly, the same .JSH instructions as the boards. It needs web/build.py.

Pages are sent with Cache-Control: no-store, so a reload always picks up
edited files.
"""
import argparse
import functools
import http.server
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--port', type=int, default=8790)
    ap.add_argument('--build', action='store_true', help='rebuild build/browser-preview with web/build.py first')
    args = ap.parse_args()
    if args.build:
        subprocess.run([sys.executable, str(ROOT / 'web/build.py')], cwd=ROOT, check=True)
    base = f'http://127.0.0.1:{args.port}'
    print(f'Fast version (native Chrome):  {base}/web/native.html')
    if (ROOT / 'build/browser-preview/index.html').is_file():
        print(f'Full machine (Python model):   {base}/build/browser-preview/')
    else:
        print('Full machine (Python model):   not built yet; run  python3 web/serve.py --build')
    print('Ctrl+C stops the server.', flush=True)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', args.port), functools.partial(NoCache, directory=str(ROOT)))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
