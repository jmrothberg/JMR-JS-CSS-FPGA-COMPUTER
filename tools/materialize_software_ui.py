"""Migrate legacy declarations once to the public resident session API.

Released HTML carries these calls explicitly so host and on-device compilers
compile the same source. Never paste the shared library into an application.
"""
from pathlib import Path
import re
from tools.software_ui import lower,bounded_menu_specs
from tools.make_sd_image import card_name_83

OLD = 'jmr-clean-ui: session-v2'
NEW = 'jmr-clean-ui: session-v3-explicit'
INVALIDATORS = {'EDITOR': 'redraw();needDraw=0;', 'READ': 'draw();needDraw=0;', 'UTILITY': 'draw();needDraw=0;', 'FINDER': 'if(stgRead(16384))paint();', 'MACPAINT': 'need=1;if(PC.ready&&booted){paintAll();need=0;}'}

def materialize(html, path):
    if OLD not in html:
        return bounded_menu_specs(html) if NEW in html else html
    scripts = list(re.finditer(r'<script([^>]*)>(.*?)</script>', html, re.S|re.I))
    scripts = [m for m in scripts if not re.search(r'data-host\s*=\s*["\']chrome["\']',m.group(1),re.I)]
    if not scripts:
        raise ValueError('No application script')
    path = Path(path)
    tail = '\ntbSessionProgram('+repr(card_name_83(path.name))+');'
    stem = path.stem.upper()
    if stem in INVALIDATORS:
        tail += '\ntbSessionInvalidate(function(){'+INVALIDATORS[stem]+'});'
    if stem == 'MACPAINT':
        tail += '\ntbSessionSuffix("PNT");'
    last = scripts[-1]
    for m in reversed(scripts):
        html=html[:m.start(2)]+lower(m.group(2))+(tail if m is last else '')+'\n'+html[m.end(2):]
    return html.replace(OLD,NEW)

if __name__ == '__main__':
    root=Path(__file__).resolve().parents[1]
    for path in sorted((root/'storage').glob('*.HTML')):
        before=path.read_text()
        after=materialize(before,path)
        if after!=before:
            path.write_text(after)
            print(path.name)
