"""Extract runnable JS + canvas size from a minimal HTML game container.

LLM NOTE: Not a browser. Playable titles are one HTML file (inline <script>
+ data:image sprites). External <script src> is still resolved next to the
HTML when present (browser-like), but games should not need sibling files.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import List, Optional, Tuple

_CANVAS_RE = re.compile(
    r'<canvas[^>]*\bid=["\']([^"\']+)["\'][^>]*>|'
    r'<canvas([^>]*)>',
    re.I,
)
_WIDTH_RE = re.compile(r'\bwidth=["\']?(\d+)', re.I)
_HEIGHT_RE = re.compile(r'\bheight=["\']?(\d+)', re.I)
_SCRIPT_SRC_RE = re.compile(
    r'<script([^>]*)>(.*?)</script>',
    re.I | re.S,
)
_SRC_ATTR = re.compile(r'\bsrc=["\']([^"\']+)["\']', re.I)


def extract_html_program(html_text: str, base_dir: Optional[Path] = None) -> Tuple[str, int, int, str]:
    """Return (js_source, canvas_w, canvas_h, canvas_id)."""
    w, h, cid = 640, 480, "gameCanvas"
    m = _CANVAS_RE.search(html_text)
    if m:
        chunk = m.group(0)
        mw = _WIDTH_RE.search(chunk)
        mh = _HEIGHT_RE.search(chunk)
        if mw:
            w = int(mw.group(1))
        if mh:
            h = int(mh.group(1))
        idm = re.search(r'\bid=["\']([^"\']+)["\']', chunk, re.I)
        if idm:
            cid = idm.group(1)

    parts: List[str] = []
    for attrs, body in _SCRIPT_SRC_RE.findall(html_text):
        sm = _SRC_ATTR.search(attrs or "")
        if sm:
            src = sm.group(1)
            if base_dir is not None:
                path = (base_dir / src).resolve()
                if path.is_file():
                    parts.append(path.read_text(encoding="utf-8"))
            continue
        body = body.strip()
        if body:
            # Skip type=module for V1
            if "type=" in (attrs or "").lower() and "module" in (attrs or "").lower():
                continue
            parts.append(body)

    js = "\n;\n".join(parts)
    return js, w, h, cid
