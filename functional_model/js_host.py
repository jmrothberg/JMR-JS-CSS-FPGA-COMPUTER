"""HTML5 Canvas game host for the PYTHON FM (and FPGA-SIM host twin).

Uses dukpy (Duktape) as the FM JavaScript engine — same role CPython plays for
BASIC in the sibling repo. This is NOT a soft CPU on the FPGA; RTL still targets
JMR bytecode + engines. Host twin FPGA-SIM shares this FM until the RTL JS core
catches up.

Provides a minimal DOM/Canvas/timer surface so ordinary .HTML+.JS Canvas games
can run without a browser (no Fetch, no CSS layout, no WebGL).
"""

from __future__ import annotations

import time
from typing import TYPE_CHECKING, Any, Callable, Dict, List, Optional

from .canvas_engine import HEIGHT, WIDTH, CanvasEngine
from .html_loader import extract_html_program
from .input_engine import InputEngine, KEY_FIRE, KEY_LEFT, KEY_RIGHT

if TYPE_CHECKING:
    import dukpy as _dukpy_mod


_PREAMBLE = r"""
var __jmr_rafs = [];
var __jmr_intervals = [];
var __jmr_interval_seq = 1;
var __jmr_listeners = { keydown: [], keyup: [] };
var __jmr_onload = null;
var game = null;

var console = { log: function () {}, warn: function () {}, error: function () {} };
var location = { href: "" };

function requestAnimationFrame(fn) {
  __jmr_rafs.push(fn);
  return __jmr_rafs.length;
}

function setInterval(fn, ms) {
  var id = __jmr_interval_seq++;
  __jmr_intervals.push({ id: id, fn: fn, ms: ms || 16, acc: 0 });
  return id;
}

function clearInterval(id) {
  __jmr_intervals = __jmr_intervals.filter(function (x) { return x.id !== id; });
}

function setTimeout(fn, ms) {
  var fired = false;
  var id = setInterval(function () {
    if (fired) return;
    fired = true;
    clearInterval(id);
    fn();
  }, ms || 0);
  return id;
}

var document = {
  getElementById: function (id) {
    if (id === __jmr_canvas_id || id === "game" || id === "gameCanvas") {
      return __jmr_canvas;
    }
    return null;
  },
  createElement: function (tag) {
    if (String(tag).toLowerCase() === "canvas") {
      return {
        width: 640,
        height: 480,
        getContext: function (t) { return __jmr_canvas.getContext(t); },
        style: {}
      };
    }
    return { style: {}, appendChild: function () {} };
  }
};

// LLM NOTE: do not `var window = this` — dukpy JSON-bridges eval results and
// circular globals throw TypeError: circular reference.
var window = {
  document: document,
  location: location,
  AudioContext: undefined,
  webkitAudioContext: undefined,
  addEventListener: function (type, fn) {
    if (type === "load") { __jmr_onload = fn; return; }
    if (type === "keydown" || type === "keyup") {
      __jmr_listeners[type].push(fn);
    }
  }
};
Object.defineProperty(window, "onload", {
  configurable: true,
  set: function (fn) { __jmr_onload = fn; },
  get: function () { return __jmr_onload; }
});

function Image() {
  this.width = 0; this.height = 0; this.onload = null; this._src = "";
}
Object.defineProperty(Image.prototype, "src", {
  set: function (v) {
    this._src = v;
    var self = this;
    if (self.onload) setTimeout(function () { self.onload(); }, 0);
  },
  get: function () { return this._src; }
});

function __jmr_make_ctx() {
  return {
    fillStyle: "#ffffff",
    strokeStyle: "#ffffff",
    font: "10px sans-serif",
    textAlign: "left",
    textBaseline: "alphabetic",
    globalAlpha: 1,
    fillRect: function (x, y, w, h) {
      call_python("jmr_fillRect", +x, +y, +w, +h, String(this.fillStyle));
    },
    clearRect: function (x, y, w, h) {
      call_python("jmr_clearRect", +x, +y, +w, +h);
    },
    strokeRect: function (x, y, w, h) {
      call_python("jmr_strokeRect", +x, +y, +w, +h, String(this.strokeStyle));
    },
    fillText: function (t, x, y) {
      call_python("jmr_fillText", String(t), +x, +y, String(this.fillStyle), String(this.font), String(this.textAlign));
    },
    beginPath: function () {},
    moveTo: function () {},
    lineTo: function () {},
    arc: function () {},
    fill: function () {},
    stroke: function () {},
    save: function () {},
    restore: function () {},
    translate: function () {},
    rotate: function () {},
    scale: function () {},
    drawImage: function () {
      // V1: images optional — ignore until asset loader lands
    }
  };
}

var __jmr_canvas = {
  width: __jmr_width,
  height: __jmr_height,
  style: {},
  getContext: function (t) {
    if (String(t) === "2d") return __jmr_make_ctx();
    return null;
  }
};

function __jmr_dispatch(type, keyCode) {
  var ev = { which: keyCode, keyCode: keyCode, preventDefault: function () {} };
  var list = __jmr_listeners[type] || [];
  for (var i = 0; i < list.length; i++) list[i](ev);
}

function __jmr_tick(dt_ms) {
  var rafs = __jmr_rafs;
  __jmr_rafs = [];
  for (var i = 0; i < rafs.length; i++) rafs[i](dt_ms);
  for (var j = 0; j < __jmr_intervals.length; j++) {
    var it = __jmr_intervals[j];
    it.acc += dt_ms;
    while (it.acc >= it.ms) {
      it.acc -= it.ms;
      it.fn();
    }
  }
}

function __jmr_boot() {
  if (__jmr_onload) __jmr_onload();
}
"""


def _parse_css_color(style: str) -> int:
    """Map CSS color string to palette index (rough)."""
    s = (style or "").strip().lower()
    if s.startswith("#") and len(s) >= 7:
        r = int(s[1:3], 16)
        g = int(s[3:5], 16)
        b = int(s[5:7], 16)
        # Map to a few fixed slots + gray
        if r > 200 and g > 200 and b > 200:
            return 1
        if r > 200 and g < 80 and b < 80:
            return 2
        if r < 80 and g > 200 and b < 80:
            return 3
        if r < 80 and g < 80 and b > 200:
            return 4
        if r > 200 and g > 200 and b < 80:
            return 5
        if r > 200 and g < 100 and b < 100:
            return 2
        return 1
    named = {
        "white": 1,
        "#fff": 1,
        "#ffffff": 1,
        "black": 0,
        "red": 2,
        "green": 3,
        "lime": 3,
        "blue": 4,
        "yellow": 5,
    }
    return named.get(s, 1)


class HtmlJsHost:
    """Run one HTML Canvas game inside the FM."""

    def __init__(self, canvas: CanvasEngine, input_engine: InputEngine) -> None:
        try:
            import dukpy
        except ImportError as e:
            raise ImportError(
                "dukpy required for .HTML games — "
                "run: source .venv/bin/activate && pip install -r requirements.txt"
            ) from e
        self.canvas = canvas
        self.input = input_engine
        self.interp = dukpy.JSInterpreter()
        self.alive = False
        self._last_t = time.time()
        self._key_prev = 0
        self._export_host()

    def _export_host(self) -> None:
        def fill_rect(x, y, w, h, style):
            c = _parse_css_color(style)
            self.canvas.fill_rect(int(x), int(y), int(w), int(h), c)

        def clear_rect(x, y, w, h):
            self.canvas.clear_rect(int(x), int(y), int(w), int(h))

        def stroke_rect(x, y, w, h, style):
            c = _parse_css_color(style)
            # cheap stroke = inset rect outline
            xi, yi, wi, hi = int(x), int(y), int(w), int(h)
            self.canvas.fill_rect(xi, yi, wi, 1, c)
            self.canvas.fill_rect(xi, yi + hi - 1, wi, 1, c)
            self.canvas.fill_rect(xi, yi, 1, hi, c)
            self.canvas.fill_rect(xi + wi - 1, yi, 1, hi, c)

        def fill_text(t, x, y, style, font, align):
            # Approximate text as small rects via font blit on BACK buffer
            from .canvas_engine import COLS
            from .font8 import CHAR_W

            c = _parse_css_color(style)
            text = str(t)
            # draw onto back buffer using front helper pattern
            px = int(x)
            if align == "center":
                px -= (len(text) * CHAR_W) // 2
            elif align == "right":
                px -= len(text) * CHAR_W
            py = int(y) - 8
            # Blit onto BACK: temporary use fill_rect blocks per glyph footprint
            for i, ch in enumerate(text):
                # simple 6x8 bar per char — readable enough for scores
                self.canvas.fill_rect(px + i * CHAR_W, py, CHAR_W - 1, 8, c)

        self.interp.export_function("jmr_fillRect", fill_rect)
        self.interp.export_function("jmr_clearRect", clear_rect)
        self.interp.export_function("jmr_strokeRect", stroke_rect)
        self.interp.export_function("jmr_fillText", fill_text)

    def load_html(self, html: str, base_dir=None, width: int = 640, height: int = 480) -> None:
        js, w, h, cid = extract_html_program(html, base_dir)
        if w:
            width = w
        if h:
            height = h
        # Clamp draw surface to our FB
        width = min(width, WIDTH)
        height = min(height, HEIGHT)
        self.canvas.clear(0)
        self.canvas.swap()
        self.canvas.clear(0)
        boot = (
            f"var __jmr_width = {width}; var __jmr_height = {height}; "
            f"var __jmr_canvas_id = {cid!r};\n"
        )
        # LLM NOTE: dukpy bridges the last eval result to Python — always end with null
        # so functions/objects never get marshalled (Invalid Result Value / circular).
        self.interp.evaljs(boot + _PREAMBLE + "\nnull;")
        self.interp.evaljs(js + "\nnull;")
        self.interp.evaljs("__jmr_boot(); null;")
        self.alive = True
        self._last_t = time.time()

    def frame(self, dt_ms: Optional[float] = None) -> None:
        if not self.alive:
            return
        if dt_ms is None:
            now = time.time()
            dt_ms = max(1.0, (now - self._last_t) * 1000.0)
            self._last_t = now
        # Sync arrow/space into JS key events (keydown edge + held via game.pressedKeys)
        bits = self.input.play_bits()
        mapping = [
            (KEY_LEFT, 37),
            (KEY_RIGHT, 39),
            (KEY_FIRE, 32),
        ]
        for mask, code in mapping:
            down = bool(bits & mask)
            was = bool(self._key_prev & mask)
            if down and not was:
                self.interp.evaljs(f"__jmr_dispatch('keydown', {code}); null;")
            if not down and was:
                self.interp.evaljs(f"__jmr_dispatch('keyup', {code}); null;")
        self._key_prev = bits
        self.interp.evaljs(f"__jmr_tick({float(dt_ms)}); null;")
        # Present back buffer
        self.canvas.swap()

    def stop(self) -> None:
        self.alive = False
        try:
            self.interp.evaljs("__jmr_intervals = []; __jmr_rafs = []; null;")
        except Exception:
            pass
