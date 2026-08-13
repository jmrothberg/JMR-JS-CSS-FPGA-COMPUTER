"""HTML5 Canvas game host for the PYTHON FM (and FPGA-SIM host twin).

Uses dukpy (Duktape) as the FM JavaScript engine — same role CPython plays for
BASIC in the sibling repo. This is NOT a soft CPU on the FPGA; RTL still targets
JMR bytecode + engines. Host twin FPGA-SIM shares this FM until the RTL JS core
catches up.

Provides a minimal DOM/Canvas/timer surface so ordinary .HTML+.JS Canvas games
can run without a browser (no Fetch, no CSS layout, no WebGL).
"""

from __future__ import annotations

import base64
import json
import math
import time
from io import BytesIO
from pathlib import Path
from typing import TYPE_CHECKING, Any, Dict, List, Optional, Tuple

from .canvas_engine import HEIGHT, WIDTH, CanvasEngine
from .html_loader import extract_html_program
from .input_engine import InputEngine, KEY_DOWN, KEY_FIRE, KEY_LEFT, KEY_RIGHT, KEY_UP

if TYPE_CHECKING:
    import dukpy as _dukpy_mod


_PREAMBLE = r"""
var __jmr_rafs = [];
var __jmr_intervals = [];
var __jmr_interval_seq = 1;
var __jmr_listeners = { keydown: [], keyup: [], click: [] };
var __jmr_onload = null;
var __jmr_nodes = {};
var __jmr_time = 0;

var console = { log: function () {}, warn: function () {}, error: function () {} };
var location = { href: "", hostname: "jmr.local", protocol: "file:" };
var navigator = { userAgent: "JMR", platform: "JMR" };

function requestAnimationFrame(fn) {
  __jmr_rafs.push(fn);
  return __jmr_rafs.length;
}
function cancelAnimationFrame() {}

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
function clearTimeout(id) { clearInterval(id); }

var __jmr_storage = {};
var localStorage = {
  getItem: function (k) {
    k = String(k);
    return Object.prototype.hasOwnProperty.call(__jmr_storage, k) ? __jmr_storage[k] : null;
  },
  setItem: function (k, v) { __jmr_storage[String(k)] = String(v); },
  removeItem: function (k) { delete __jmr_storage[String(k)]; }
};

function __jmr_add_listener(type, fn) {
  if (type === "load") { __jmr_onload = fn; return; }
  if (type === "keydown" || type === "keyup" || type === "click") {
    __jmr_listeners[type] = __jmr_listeners[type] || [];
    __jmr_listeners[type].push(fn);
  }
}

function KeyboardEvent(type, init) {
  init = init || {};
  this.type = type;
  this.key = init.key || "";
  this.keyCode = init.keyCode || 0;
  this.which = init.which || init.keyCode || 0;
  this.preventDefault = function () {};
}
function __jmr_dispatchEvent(ev) {
  if (!ev || !ev.type) return false;
  var list = __jmr_listeners[ev.type] || [];
  for (var i = 0; i < list.length; i++) list[i](ev);
  return true;
}
function __jmr_remove_listener(type, fn) {
  var list = __jmr_listeners[type] || [];
  var out = [];
  for (var i = 0; i < list.length; i++) {
    if (list[i] !== fn) out.push(list[i]);
  }
  __jmr_listeners[type] = out;
}

function __jmr_stub_node(id) {
  if (__jmr_nodes[id]) return __jmr_nodes[id];
  var node = {
    id: id,
    style: {},
    textContent: "",
    innerHTML: "",
    value: "",
    width: __jmr_width,
    height: __jmr_height,
    currentTime: 0,
    volume: 1,
    _listeners: {},
    focus: function () {},
    play: function () { return { catch: function () {} }; },
    pause: function () {},
    click: function () {
      var list = this._listeners.click || [];
      for (var i = 0; i < list.length; i++) list[i]({ preventDefault: function () {} });
    },
    addEventListener: function (type, fn) {
      this._listeners[type] = this._listeners[type] || [];
      this._listeners[type].push(fn);
    },
    removeEventListener: function () {},
    getContext: function (t) { return __jmr_canvas.getContext(t); }
  };
  __jmr_nodes[id] = node;
  return node;
}

function __jmr_is_canvas_id(id) {
  return id === __jmr_canvas_id || id === "game" || id === "gameCanvas" ||
         id === "board" || id === "canvas" || id === "myCanvas" || id === "stairs";
}

var document = {
  fonts: { add: function () {} },
  getElementById: function (id) {
    if (__jmr_is_canvas_id(id)) return __jmr_canvas;
    return __jmr_stub_node(String(id));
  },
  querySelector: function (sel) {
    sel = String(sel || "");
    if (sel.indexOf("canvas") >= 0) return __jmr_canvas;
    if (sel.charAt(0) === "#") return document.getElementById(sel.slice(1));
    return __jmr_stub_node(sel);
  },
  querySelectorAll: function () { return []; },
  createElement: function (tag) {
    if (String(tag).toLowerCase() === "canvas") return __jmr_canvas;
    return __jmr_stub_node("el-" + String(tag));
  },
  addEventListener: __jmr_add_listener,
  removeEventListener: __jmr_remove_listener,
  dispatchEvent: __jmr_dispatchEvent
};

// LLM NOTE: do not `var window = this` — dukpy JSON-bridges eval results and
// circular globals throw TypeError: circular reference.
var window = {
  document: document,
  location: location,
  localStorage: localStorage,
  navigator: navigator,
  innerWidth: __jmr_width,
  innerHeight: __jmr_height,
  AudioContext: undefined,
  webkitAudioContext: undefined,
  requestAnimationFrame: requestAnimationFrame,
  cancelAnimationFrame: cancelAnimationFrame,
  addEventListener: __jmr_add_listener,
  removeEventListener: __jmr_remove_listener,
  dispatchEvent: __jmr_dispatchEvent
};
Object.defineProperty(window, "onload", {
  configurable: true,
  set: function (fn) { __jmr_onload = fn; },
  get: function () { return __jmr_onload; }
});
function addEventListener(type, fn) { window.addEventListener(type, fn); }

function FontFace(name, src) {
  this.family = name;
  this.load = function () {
    var self = this;
    return { then: function (fn) { if (fn) fn(self); return { catch: function () {} }; } };
  };
}

function Image() {
  this.width = 0; this.height = 0; this.onload = null; this._src = ""; this._id = 0;
}
Object.defineProperty(Image.prototype, "src", {
  set: function (v) {
    this._src = v;
    var info = call_python("jmr_loadImage", String(v));
    if (info && info.length) {
      this._id = info[0];
      this.width = info[1];
      this.height = info[2];
    }
    var self = this;
    setTimeout(function () { if (self.onload) self.onload(); }, 0);
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
    _path: [],
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
    measureText: function (t) {
      return { width: String(t).length * 8 };
    },
    beginPath: function () { this._path = []; },
    moveTo: function (x, y) { this._path.push("M," + x + "," + y); },
    lineTo: function (x, y) { this._path.push("L," + x + "," + y); },
    closePath: function () { this._path.push("Z"); },
    arc: function (x, y, r, a0, a1, ccw) {
      this._path.push("A," + x + "," + y + "," + r + "," + a0 + "," + a1 + "," + (ccw ? 1 : 0));
    },
    fill: function () {
      call_python("jmr_fillPath", this._path.join("|"), String(this.fillStyle));
    },
    stroke: function () {
      call_python("jmr_strokePath", this._path.join("|"), String(this.strokeStyle));
    },
    save: function () { call_python("jmr_save"); },
    restore: function () { call_python("jmr_restore"); },
    translate: function (x, y) { call_python("jmr_translate", +x, +y); },
    rotate: function (a) { call_python("jmr_rotate", +a); },
    scale: function (x, y) { call_python("jmr_scale", +x, +y); },
    setTransform: function (a, b, c, d, e, f) {
      call_python("jmr_setTransform", +a, +b, +c, +d, +e, +f);
    },
    getImageData: function () {
      return { _id: call_python("jmr_getImageData") };
    },
    putImageData: function (data) {
      if (data && data._id) call_python("jmr_putImageData", data._id);
    },
    quadraticCurveTo: function (cpx, cpy, x, y) {
      this._path.push("L," + x + "," + y);
    },
    drawImage: function (img) {
      if (!img || !img._id) return;
      var a = arguments;
      if (a.length === 3) {
        call_python("jmr_drawImage", img._id, 0, 0, img.width, img.height, +a[1], +a[2], img.width, img.height);
      } else if (a.length === 5) {
        call_python("jmr_drawImage", img._id, 0, 0, img.width, img.height, +a[1], +a[2], +a[3], +a[4]);
      } else if (a.length >= 9) {
        call_python("jmr_drawImage", img._id, +a[1], +a[2], +a[3], +a[4], +a[5], +a[6], +a[7], +a[8]);
      }
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
  },
  getBoundingClientRect: function () {
    return { left: 0, top: 0, width: __jmr_width, height: __jmr_height };
  },
  addEventListener: __jmr_add_listener,
  removeEventListener: __jmr_remove_listener
};

function __jmr_dispatch(type, keyCode, key) {
  var ev = { which: keyCode, keyCode: keyCode, key: key || "", preventDefault: function () {} };
  var list = __jmr_listeners[type] || [];
  for (var i = 0; i < list.length; i++) list[i](ev);
}

function __jmr_tick(dt_ms) {
  __jmr_time += dt_ms;
  var rafs = __jmr_rafs;
  __jmr_rafs = [];
  for (var i = 0; i < rafs.length; i++) rafs[i](__jmr_time);
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


def _rgb(style: str) -> Tuple[int, int, int]:
    """Parse a CSS color to RGB (host maps onto the 256-entry palette)."""
    s = (style or "").strip().lower()
    if s.startswith("rgba") or s.startswith("rgb"):
        try:
            inner = s[s.index("(") + 1 : s.rindex(")")]
            parts = [p.strip() for p in inner.split(",")]
            return int(float(parts[0])), int(float(parts[1])), int(float(parts[2]))
        except Exception:
            return (0, 0, 0)
    if s.startswith("#"):
        hx = s[1:]
        if len(hx) == 3:
            hx = hx[0] * 2 + hx[1] * 2 + hx[2] * 2
        if len(hx) >= 6:
            return int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16)
    named = {
        "white": (255, 255, 255),
        "black": (0, 0, 0),
        "red": (255, 0, 0),
        "green": (0, 255, 0),
        "lime": (0, 255, 0),
        "blue": (0, 0, 255),
        "yellow": (255, 255, 0),
        "cyan": (0, 255, 255),
        "magenta": (255, 0, 255),
        "orange": (255, 136, 0),
        "pink": (255, 153, 204),
        "purple": (153, 102, 204),
    }
    return named.get(s, (255, 255, 255))


def _parse_css_color(style: str) -> int:
    """Legacy 8-slot map (INVADARC / older titles). Prefer HtmlJsHost._pal."""
    r, g, b = _rgb(style)
    if r < 40 and g < 40 and b < 40:
        return 0
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
    return 1


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
        self._base_dir: Optional[Path] = None
        self._gw = float(WIDTH)
        self._gh = float(HEIGHT)
        self._tf = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        self._tf_stack: List[List[float]] = []
        self._pal_next = 8
        self._pal_cache: Dict[Tuple[int, int, int], int] = {
            (0, 0, 0): 0,
            (255, 255, 255): 1,
            (255, 0, 0): 2,
            (0, 255, 0): 3,
            (0, 0, 255): 4,
            (255, 255, 0): 5,
            (0, 255, 255): 6,
            (255, 0, 255): 7,
        }
        self._images: Dict[int, Tuple[int, int, bytearray]] = {}
        self._image_by_path: Dict[str, int] = {}
        self._image_seq = 1
        self._snapshots: Dict[int, bytes] = {}
        self._snap_seq = 1
        # HTML files start themselves (Chrome file:// same as LOAD+RUN).
        self._enter_left = 0
        self._enter_delay = 4
        self._export_host()

    def _pal(self, style: str) -> int:
        rgb = _rgb(style)
        if rgb in self._pal_cache:
            return self._pal_cache[rgb]
        idx = self._pal_next
        if idx > 255:
            idx = 8 + (self._pal_next % 248)
        else:
            self._pal_next += 1
        self.canvas.palette[idx] = rgb
        self._pal_cache[rgb] = idx
        return idx

    def _xf(self, x: float, y: float) -> Tuple[float, float]:
        a, b, c, d, e, f = self._tf
        return a * x + b * y + c, d * x + e * y + f

    def _to_fb(self, x: float, y: float) -> Tuple[int, int]:
        gx, gy = self._xf(x, y)
        return int(gx * WIDTH / self._gw), int(gy * HEIGHT / self._gh)

    def _to_fb_size(self, w: float, h: float) -> Tuple[int, int]:
        sx = abs(self._tf[0]) * WIDTH / self._gw
        sy = abs(self._tf[4]) * HEIGHT / self._gh
        return max(1, int(w * sx)), max(1, int(h * sy))

    def _export_host(self) -> None:
        def fill_rect(x, y, w, h, style):
            c = self._pal(style)
            x0, y0 = self._to_fb(x, y)
            ww, hh = self._to_fb_size(w, h)
            self.canvas.fill_rect(x0, y0, ww, hh, c)

        def clear_rect(x, y, w, h):
            x0, y0 = self._to_fb(x, y)
            ww, hh = self._to_fb_size(w, h)
            self.canvas.clear_rect(x0, y0, ww, hh)

        def stroke_rect(x, y, w, h, style):
            c = self._pal(style)
            x0, y0 = self._to_fb(x, y)
            ww, hh = self._to_fb_size(w, h)
            self.canvas.fill_rect(x0, y0, ww, 1, c)
            self.canvas.fill_rect(x0, y0 + hh - 1, ww, 1, c)
            self.canvas.fill_rect(x0, y0, 1, hh, c)
            self.canvas.fill_rect(x0 + ww - 1, y0, 1, hh, c)

        def fill_text(t, x, y, style, font, align):
            from .font8 import CHAR_W

            c = self._pal(style)
            text = str(t)
            px, py = self._to_fb(x, y)
            if align == "center":
                px -= (len(text) * CHAR_W) // 2
            elif align == "right":
                px -= len(text) * CHAR_W
            py -= 8
            for i, _ch in enumerate(text):
                self.canvas.fill_rect(px + i * CHAR_W, py, CHAR_W - 1, 8, c)

        def load_image(src: str):
            return self._load_image(str(src))

        def draw_image(img_id, sx, sy, sw, sh, dx, dy, dw, dh):
            self._draw_image(int(img_id), sx, sy, sw, sh, dx, dy, dw, dh)

        def fill_path(spec, style):
            self._fill_path(str(spec), self._pal(style), stroke=False)

        def stroke_path(spec, style):
            self._fill_path(str(spec), self._pal(style), stroke=True)

        def save():
            self._tf_stack.append(list(self._tf))

        def restore():
            if self._tf_stack:
                self._tf = self._tf_stack.pop()

        def translate(x, y):
            a, b, c, d, e, f = self._tf
            self._tf[2] = a * x + b * y + c
            self._tf[5] = d * x + e * y + f

        def rotate(ang):
            # compose rotation on the right
            ca, sa = math.cos(ang), math.sin(ang)
            a, b, c, d, e, f = self._tf
            self._tf = [a * ca + b * sa, -a * sa + b * ca, c, d * ca + e * sa, -d * sa + e * ca, f]

        def scale(sx, sy):
            a, b, c, d, e, f = self._tf
            self._tf = [a * sx, b * sy, c, d * sx, e * sy, f]

        def get_image_data():
            sid = self._snap_seq
            self._snap_seq += 1
            self._snapshots[sid] = bytes(self.canvas.back)
            return sid

        def put_image_data(sid):
            raw = self._snapshots.get(int(sid))
            if raw is not None and len(raw) == len(self.canvas.back):
                self.canvas.back[:] = raw

        def set_transform(a, b, c, d, e, f):
            # Canvas: x' = a*x + c*y + e ; y' = b*x + d*y + f
            self._tf = [float(a), float(c), float(e), float(b), float(d), float(f)]

        self.interp.export_function("jmr_fillRect", fill_rect)
        self.interp.export_function("jmr_setTransform", set_transform)
        self.interp.export_function("jmr_getImageData", get_image_data)
        self.interp.export_function("jmr_putImageData", put_image_data)
        self.interp.export_function("jmr_clearRect", clear_rect)
        self.interp.export_function("jmr_strokeRect", stroke_rect)
        self.interp.export_function("jmr_fillText", fill_text)
        self.interp.export_function("jmr_loadImage", load_image)
        self.interp.export_function("jmr_drawImage", draw_image)
        self.interp.export_function("jmr_fillPath", fill_path)
        self.interp.export_function("jmr_strokePath", stroke_path)
        self.interp.export_function("jmr_save", save)
        self.interp.export_function("jmr_restore", restore)
        self.interp.export_function("jmr_translate", translate)
        self.interp.export_function("jmr_rotate", rotate)
        self.interp.export_function("jmr_scale", scale)

    def _load_image(self, src: str) -> List[int]:
        src = src.split("?")[0]
        if src in self._image_by_path:
            iid = self._image_by_path[src]
            w, h, _ = self._images[iid]
            return [iid, w, h]
        path = None
        blob = None
        # Single-file games embed sprites as data:image/png;base64,... (browser-standard).
        if src.startswith("data:") and "," in src:
            header, b64 = src.split(",", 1)
            if ";base64" in header.lower():
                try:
                    blob = base64.b64decode(b64)
                except Exception:
                    blob = None
        elif self._base_dir is not None and src:
            cand = (self._base_dir / src.lstrip("./")).resolve()
            try:
                cand.relative_to(self._base_dir.resolve())
            except ValueError:
                cand = None
            if cand is not None and cand.is_file():
                path = cand
        if path is None and blob is None:
            iid = self._image_seq
            self._image_seq += 1
            self._images[iid] = (1, 1, bytearray([0]))
            self._image_by_path[src] = iid
            return [iid, 1, 1]
        try:
            from PIL import Image as PILImage

            if blob is not None:
                im = PILImage.open(BytesIO(blob)).convert("RGBA")
            else:
                im = PILImage.open(path).convert("RGBA")
        except Exception:
            iid = self._image_seq
            self._image_seq += 1
            self._images[iid] = (1, 1, bytearray([0]))
            self._image_by_path[src] = iid
            return [iid, 1, 1]
        w, h = im.size
        pix = bytearray(w * h)
        px = im.load()
        for yy in range(h):
            row = yy * w
            for xx in range(w):
                r, g, b, a = px[xx, yy]
                pix[row + xx] = 0 if a < 16 else self._pal(f"#{r:02x}{g:02x}{b:02x}")
        iid = self._image_seq
        self._image_seq += 1
        self._images[iid] = (w, h, pix)
        self._image_by_path[src] = iid
        return [iid, w, h]

    def _draw_image(self, img_id, sx, sy, sw, sh, dx, dy, dw, dh) -> None:
        rec = self._images.get(int(img_id))
        if rec is None:
            return
        iw, ih, pix = rec
        sx, sy, sw, sh = int(sx), int(sy), int(sw), int(sh)
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0:
            return
        x0, y0 = self._to_fb(dx, dy)
        dwb, dhb = self._to_fb_size(dw, dh)
        back = self.canvas.back
        for yy in range(dhb):
            fy = y0 + yy
            if fy < 0 or fy >= HEIGHT:
                continue
            src_y = sy + yy * sh // dhb
            if src_y < 0 or src_y >= ih:
                continue
            row = fy * WIDTH
            src_row = src_y * iw
            for xx in range(dwb):
                fx = x0 + xx
                if fx < 0 or fx >= WIDTH:
                    continue
                src_x = sx + xx * sw // dwb
                if src_x < 0 or src_x >= iw:
                    continue
                c = pix[src_row + src_x]
                if c:
                    back[row + fx] = c

    def _path_points(self, spec: str) -> List[Tuple[float, float]]:
        pts: List[Tuple[float, float]] = []
        start: Optional[Tuple[float, float]] = None
        cur = (0.0, 0.0)
        for cmd in spec.split("|"):
            if not cmd:
                continue
            parts = cmd.split(",")
            op = parts[0]
            if op == "M":
                cur = (float(parts[1]), float(parts[2]))
                start = cur
                pts.append(cur)
            elif op == "L":
                cur = (float(parts[1]), float(parts[2]))
                pts.append(cur)
            elif op == "Z":
                if start is not None:
                    pts.append(start)
                    cur = start
            elif op == "A":
                cx, cy, r = float(parts[1]), float(parts[2]), float(parts[3])
                a0, a1 = float(parts[4]), float(parts[5])
                ccw = int(float(parts[6])) if len(parts) > 6 else 0
                # sample pie/arc. Full-circle (energizer beans: 0→2π ccw)
                # must not wrap a1-=2π into a zero sweep.
                if abs(a1 - a0) >= (2 * math.pi - 1e-6):
                    a1 = a0 - 2 * math.pi if ccw else a0 + 2 * math.pi
                elif ccw:
                    if a1 > a0:
                        a1 -= 2 * math.pi
                else:
                    if a1 < a0:
                        a1 += 2 * math.pi
                n = max(8, int(abs(a1 - a0) / 0.25))
                for i in range(n + 1):
                    t = a0 + (a1 - a0) * i / n
                    pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
                cur = pts[-1] if pts else cur
        return pts

    def _fill_path(self, spec: str, color: int, stroke: bool) -> None:
        pts = self._path_points(spec)
        if len(pts) < 2:
            return
        fb = [self._to_fb(x, y) for x, y in pts]
        if stroke or len(fb) < 3:
            for i in range(len(fb) - 1):
                x0, y0 = fb[i]
                x1, y1 = fb[i + 1]
                self._line(x0, y0, x1, y1, color)
            return
        ys = [p[1] for p in fb]
        y0, y1 = max(0, min(ys)), min(HEIGHT - 1, max(ys))
        n = len(fb)
        back = self.canvas.back
        for y in range(y0, y1 + 1):
            xs = []
            for i in range(n):
                x1, y1p = fb[i]
                x2, y2p = fb[(i + 1) % n]
                if y1p == y2p:
                    continue
                if (y1p <= y < y2p) or (y2p <= y < y1p):
                    t = (y - y1p) / (y2p - y1p)
                    xs.append(int(x1 + t * (x2 - x1)))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                xa, xb = xs[i], xs[i + 1]
                if xa > xb:
                    xa, xb = xb, xa
                xa = max(0, xa)
                xb = min(WIDTH - 1, xb)
                row = y * WIDTH
                for x in range(xa, xb + 1):
                    back[row + x] = color

    def _line(self, x0, y0, x1, y1, c) -> None:
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        back = self.canvas.back
        while True:
            if 0 <= x0 < WIDTH and 0 <= y0 < HEIGHT:
                back[y0 * WIDTH + x0] = c
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def load_html(self, html: str, base_dir=None, width: int = 640, height: int = 480) -> None:
        js, w, h, cid = extract_html_program(html, base_dir)
        if w:
            width = w
        if h:
            height = h
        # Keep game-native canvas size; blit scales onto 640×480 FB.
        self._gw = float(max(1, width))
        self._gh = float(max(1, height))
        self._base_dir = Path(base_dir) if base_dir is not None else None
        self._tf = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
        self._tf_stack = []
        self._enter_left = 0
        self._enter_delay = 4
        self.canvas.clear(0)
        self.canvas.swap()
        self.canvas.clear(0)
        boot = (
            f"var __jmr_width = {int(self._gw)}; var __jmr_height = {int(self._gh)}; "
            f"var __jmr_canvas_id = {cid!r};\n"
        )
        # LLM NOTE: dukpy bridges the last eval result to Python — always end with null
        # so functions/objects never get marshalled (Invalid Result Value / circular).
        self.interp.evaljs(boot + _PREAMBLE + "\nnull;")
        # Eval each <script> separately so one file's 'use strict' does not
        # poison implicit globals in the next (mumuy pacman index.js).
        for chunk in js.split("\n;\n"):
            if chunk.strip():
                self.interp.evaljs(chunk + "\nnull;")
        self.interp.evaljs("__jmr_boot(); null;")
        self.alive = True
        self._last_t = time.time()

    def _dispatch(self, kind: str, code: int, key: str) -> None:
        key_js = json.dumps(key)
        self.interp.evaljs(f"__jmr_dispatch({kind!r}, {code}, {key_js}); null;")

    def frame(self, dt_ms: Optional[float] = None) -> None:
        if not self.alive:
            return
        if dt_ms is None:
            now = time.time()
            dt_ms = max(1.0, (now - self._last_t) * 1000.0)
            self._last_t = now
        bits = self.input.play_bits()
        mapping = [
            (KEY_LEFT, 37, "ArrowLeft", "a", 65),
            (KEY_UP, 38, "ArrowUp", "w", 87),
            (KEY_RIGHT, 39, "ArrowRight", "d", 68),
            (KEY_DOWN, 40, "ArrowDown", "s", 83),
            (KEY_FIRE, 32, " ", None, 0),
        ]
        for mask, code, name, alias, acode in mapping:
            down = bool(bits & mask)
            was = bool(self._key_prev & mask)
            if down and not was:
                self._dispatch("keydown", code, name)
                if alias:
                    self._dispatch("keydown", acode, alias)
            if not down and was:
                self._dispatch("keyup", code, name)
                if alias:
                    self._dispatch("keyup", acode, alias)
        self._key_prev = bits
        self.interp.evaljs(f"__jmr_tick({float(dt_ms)}); null;")
        # After rAF so title screens have bound their keydown listeners.
        if self._enter_left > 0:
            self._enter_delay -= 1
            if self._enter_delay <= 0:
                self._dispatch("keydown", 13, "Enter")
                self._dispatch("keyup", 13, "Enter")
                self._enter_left -= 1
                self._enter_delay = 8
        self.canvas.swap()

    def stop(self) -> None:
        self.alive = False
        try:
            self.interp.evaljs("__jmr_intervals = []; __jmr_rafs = []; null;")
        except Exception:
            pass
