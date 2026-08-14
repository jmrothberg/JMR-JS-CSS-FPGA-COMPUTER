"""Tiny FPGA-SIM RTL snippets — not LOAD+RUN of the three HTML titles."""

from __future__ import annotations

import os
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def _sim():
    os.environ.pop("JMR_SIM_HOST", None)
    from runtime.sim_backend import SimBackend

    sim = SimBackend()
    if not sim.available or not sim._use_rtl:
        pytest.skip("FPGA-SIM RTL binary missing")
    for _ in range(200):
        sim._rpc("TICK")
    return sim


def _patch_js(name: str, src: str) -> None:
    from functional_model.compiler import compile_source
    from functional_model.jsb_format import encode_chunk
    from tools.make_sd_image import patch_card_file

    card = Path(os.environ.get("JMR_CARD_IMG") or (ROOT / "card.img"))
    blob = encode_chunk(compile_source(src))
    patch_card_file(card, name, src.encode("utf-8"))
    patch_card_file(card, Path(name).stem[:8] + ".JSB", blob)


def _fb_raw(sim) -> bytes:
    import base64

    fb = sim._rpc("FB?")
    if not fb.startswith("FB 640 480 "):
        return b""
    return base64.b64decode(fb.split(None, 3)[3])


def _fb_pix(raw: bytes, x: int, y: int) -> int:
    if not raw:
        return 0
    return raw[y * 640 + x]


def _fb_nz(sim) -> int:
    return sum(1 for b in _fb_raw(sim) if b)


def test_rtl_push_object_survives_frame():
    """arr.push({n:1}) after keep watermark must still be readable next frame."""
    src = """
var arr = [];
var armed = 0;
function tick() {
  if (!armed) {
    arr.push({n:1});
    armed = 1;
  } else if (arr[0] && arr[0].n == 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEEP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEEP.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "nursery obj from push was rewound"
    finally:
        sim.shutdown()


def test_rtl_id_prop_postfix_dec_writes_back():
    """Bare item.timeout-- must store (same compiler path as PACMAN engine)."""
    src = """
var item = {timeout: 5};
var i;
for (i = 0; i < 3; i++) {
  if (item.timeout) item.timeout--;
}
function tick() {
  if (item.timeout == 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TDEC.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TDEC.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "item.timeout-- did not write back"
    finally:
        sim.shutdown()


def test_rtl_coord_overwrite_does_not_heapovf():
    """item.coord = {x,y} every frame must rewind, not freeze keep."""
    src = """
var item = {coord: {x: 0, y: 0}};
var n = 0;
function tick() {
  item.coord = {x: n, y: n};
  n = n + 1;
  fillRect(10, 10, 30, 30, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("COORD.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "COORD.JS"')
        sim.type_line("RUN")
        for _ in range(400):
            sim._rpc("TICK")
        st = sim._rpc("VMSTAT?")
        import re as _re

        hm = _re.search(r"heapovf=(\d+)", st or "")
        assert hm and int(hm.group(1)) == 0, st
        assert _fb_nz(sim) >= 50, "coord overwrite stopped drawing"
    finally:
        sim.shutdown()


def test_rtl_keyevt_space_keycode():
    """KEYEVT 32 must reach addEventListener (e.keyCode)."""
    src = """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.keyCode == 32) hit = 1;
});
function tick() {
  if (hit) {
    fillRect(40, 10, 30, 30, 4);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEYSP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEYSP.JS"')
        sim.type_line("RUN")
        for _ in range(40):
            sim._rpc("TICK")
        sim.key_event(32, " ", True)
        # frame_tick is 65536 clk; TICK is 1000 — need >1 frame after KEYEVT
        for _ in range(200):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "KEYEVT 32 did not fire listener"
    finally:
        sim.shutdown()


def test_rtl_keyevt_space_e_key_char():
    """KEYEVT 32 must deliver e.key === ' ' (U+0020), not keyCode-only."""
    src = """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.key === " ") hit = 1;
});
function tick() {
  if (hit) {
    fillRect(50, 10, 30, 30, 5);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KEYCH.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KEYCH.JS"')
        sim.type_line("RUN")
        for _ in range(40):
            sim._rpc("TICK")
        sim.key_event(32, " ", True)
        # frame_tick is 65536 clk; TICK is 1000 — need >1 frame after KEYEVT
        for _ in range(200):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "e.key === ' ' did not match"
    finally:
        sim.shutdown()


def test_rtl_push_survives_particle_burst():
    """grid.push then a burst of new objs — grid[0] still readable next frame."""
    src = """
var grid = [];
var burst = [];
var armed = 0;
function tick() {
  if (armed == 0) {
    grid.push({n:1});
    armed = 1;
  } else if (armed == 1) {
    for (var i = 0; i < 8; i++) burst.push({p:i});
    armed = 2;
  } else if (grid[0] && grid[0].n == 1) {
    fillRect(20, 10, 30, 30, 3);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("BURST.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "BURST.JS"')
        sim.type_line("RUN")
        for _ in range(120):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "grid obj died after nursery burst"
    finally:
        sim.shutdown()


def test_rtl_dir_hides_jsb_shows_html():
    # Snippet patches dirty the FAT; rebuild so HTML titles are on the card.
    from tools.make_sd_image import create_image

    create_image(ROOT / "card.img", force=True)
    sim = _sim()
    try:
        sim._rpc("SDRELOAD")
        sim.type_line("DIR")
        pages = []
        for _ in range(8):
            st = sim.screen_text().replace("\\n", "\n")
            pages.append(st)
            for ln in st.splitlines():
                t = ln.strip().upper()
                assert not t.endswith(".JSB"), ln
                assert not t.endswith(".JSH"), ln
            if "INVADERS" in st.upper():
                break
            if "-- MORE" in st:
                sim.push_key(" ")
            else:
                break
        blob = "\n".join(pages)
        assert "INVADERS" in blob.upper(), blob[-400:]
    finally:
        sim.shutdown()


def test_rtl_list_pages_more():
    """LIST of a multi-page HTML must park on MORE, not prompt at ~230."""
    sim = _sim()
    try:
        sim.type_line('LOAD "INVADERS.HTML"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "-- MORE" in st, st[-400:]
        assert not st.rstrip().endswith(">"), st[-200:]
    finally:
        sim.shutdown()


def test_rtl_load_html_line_count():
    """LOADED NAME (N LINES) must count past the 8K SOURCE prefix."""
    sim = _sim()
    try:
        sim.type_line('LOAD "INVADERS.HTML"')
        st = sim.screen_text().replace("\\n", "\n")
        assert "LOADED" in st, st[-300:]
        assert "LINES" in st, st[-300:]
        assert "INVADERS" in st.upper(), st[-300:]
        n = 0
        for tok in st.replace("(", " ").replace(")", " ").split():
            if tok.isdigit() and int(tok) > n:
                n = int(tok)
        assert n > 230, (n, st[-300:])
    finally:
        sim.shutdown()


def test_rtl_list_after_run_is_source():
    """LIST after RUN still shows source text, not .JSB/.JSH bytes."""
    sim = _sim()
    try:
        sim.type_line('LOAD "RECTDEMO.JS"')
        sim.type_line("RUN")
        sim.hard_break()
        for _ in range(30):
            sim._rpc("TICK")
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "fillRect" in st or "HELLO" in st, st[-400:]
    finally:
        sim.shutdown()


def test_rtl_finder_paths_out_of_house():
    """Same mini-BFS as PYTHON: stringify/replace opens a 2-cell, then path."""
    src = r"""
var data = [
  [1,1,1,1],
  [1,2,2,1],
  [1,2,2,1],
  [0,0,0,0]
];
var s = JSON.stringify(data);
var opened = JSON.parse(s.replace(/2/g, 0));
function finder(params) {
  var defaults = { map:null, start:{}, end:{}, type:'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
function tick() {
  if (path.length) {
    fillRect(60, 10, 30, 30, 6);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FINDER.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FINDER.JS"')
        sim.type_line("RUN")
        for _ in range(200):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "finder BFS did not path out of a 2-cell"
    finally:
        sim.shutdown()


def test_rtl_nested_for_continue_skips_cells():
    """RTL twin of bunker-arch continue: skipped corners must not paint."""
    src = """
var n = 0;
for (var row = 0; row < 10; row++) {
  for (var col = 0; col < 14; col++) {
    if (row === 0 && (col < 2 || col > 11)) continue;
    if (row === 1 && (col < 1 || col > 12)) continue;
    if (row >= 6 && col >= 5 && col <= 8) continue;
    n = n + 1;
  }
}
function tick() {
  if (n === 118) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("CONT.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "CONT.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "nested for continue did not skip 22 cells"
    finally:
        sim.shutdown()


def test_rtl_array_find_identity_splice():
    """arr.find(el => el === obj) then splice — INVADERS bullet path."""
    src = """
var grid = [{n:1}, {n:2}, {n:3}];
var a = grid[1];
var hit = grid.find(function(el) { return el === a; });
if (hit === a) grid.splice(1, 1);
function tick() {
  if (grid.length === 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FIND.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FIND.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "Array.find identity splice did not drop the object"
    finally:
        sim.shutdown()


def test_rtl_settimeout_delay_keeps_drawing():
    """setTimeout(fn, 1000) must not fire on the next few frames."""
    src = """
var n = 0;
setTimeout(function() { n = 1; }, 1000);
function tick() {
  if (n === 0) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("TDELAY.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "TDELAY.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "setTimeout(1000) fired immediately (stopped drawing)"
    finally:
        sim.shutdown()


def test_rtl_list_space_pages_past_230():
    """LIST MORE Space must pump clocks so later HTML lines appear."""
    sim = _sim()
    try:
        sim.type_line('LOAD "INVADERS.HTML"')
        sim.type_line("LIST")
        st = sim.screen_text().replace("\\n", "\n")
        assert "-- MORE" in st, st[-400:]
        nums0 = []
        for ln in st.splitlines():
            tok = ln.strip().split(None, 1)
            if tok and tok[0].isdigit():
                nums0.append(int(tok[0]))
        sim.push_key(" ")
        st2 = sim.screen_text().replace("\\n", "\n")
        nums = []
        for ln in st2.splitlines():
            tok = ln.strip().split(None, 1)
            if tok and tok[0].isdigit():
                nums.append(int(tok[0]))
        prev = max(nums0) if nums0 else 0
        assert nums and max(nums) > prev, (prev, max(nums) if nums else None, st2[-400:])
    finally:
        sim.shutdown()


def test_rtl_two_keydown_listeners_and_remove():
    src = """
var n = 0;
function fa(e) { if (e.keyCode === 13) n = n + 1; }
function fb(e) { if (e.keyCode === 13) n = n + 10; }
addEventListener("keydown", fa);
addEventListener("keydown", fb);
function tick() {
  if (n === 11) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("LISN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "LISN.JS"')
        sim.type_line("RUN")
        for _ in range(40):
            sim._rpc("TICK")
        sim._rpc("KEYEVT 13 1")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "both keydown listeners did not fire"
    finally:
        sim.shutdown()


def test_rtl_dispatch_event_enter():
    src = """
var st = 0;
addEventListener("keydown", function(e) {
  if (e.keyCode === 13) st = 1;
});
var ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
if (document.dispatchEvent) document.dispatchEvent(ev);
function tick() {
  if (st === 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("DISP.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "DISP.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "dispatchEvent Enter did not reach keydown"
    finally:
        sim.shutdown()


def test_rtl_keyboard_event_ctor_sets_key():
    """new KeyboardEvent must copy options.key so e.key === 'Enter' (DONKEY boot)."""
    src = """
var st = 0;
addEventListener("keydown", function(e) {
  if (e.key === "Enter") st = 1;
});
var ev;
try {
  ev = new KeyboardEvent("keydown", { key: "Enter", keyCode: 13, which: 13 });
} catch (e) {
  ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
}
if (document.dispatchEvent) document.dispatchEvent(ev);
function tick() {
  if (st === 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("KBEV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "KBEV.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "new KeyboardEvent did not set e.key"
    finally:
        sim.shutdown()


def test_rtl_position2coord_offset_center():
    """Generic cell-center offset: falsy at center, truthy ±2 px."""
    src = """
var size = 14, mx = 50, my = 50, cx = 12, cy = 14;
var posx = mx + cx * size + size / 2;
var posy = my + cy * size + size / 2;
var fx = Math.abs(posx - mx) % size - size / 2;
var fy = Math.abs(posy - my) % size - size / 2;
var offset = Math.sqrt(fx * fx + fy * fy);
var moved = Math.sqrt(
  (Math.abs(posx + 2 - mx) % size - size / 2) *
  (Math.abs(posx + 2 - mx) % size - size / 2)
);
var ok = (!offset && moved) ? 1 : 0;
function tick() {
  if (ok) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("OFFS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "OFFS.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "position2coord offset not falsy at cell center"
    finally:
        sim.shutdown()


def test_rtl_join_empty_eq_case_1100():
    """RTL twin: join('') === '1100' and indexOf(1) > -1."""
    src = """
var code = [1, 1, 0, 0];
var hit = 0;
switch (code.join('')) {
  case '1100':
    if (code.indexOf(1) > -1) hit = 1;
    break;
  default:
    hit = 2;
}
function tick() {
  if (hit == 1) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("JOIN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "JOIN.JS"')
        sim.type_line("RUN")
        for _ in range(80):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "join('') did not EQ case 1100"
    finally:
        sim.shutdown()


def test_rtl_switch_join_draws_arc_not_spokes():
    """RTL twin: 1100 paints a quarter-arc, not a spoke through the cell center."""
    src = """
var c = document.getElementById('c').getContext('2d');
c.strokeStyle = '#09f';
c.lineWidth = 2;
var code = [1, 1, 0, 0];
var size = 20;
var posx = 100, posy = 100;
function tick() {
  switch (code.join('')) {
    case '1100':
      c.beginPath();
      c.arc(posx + size / 2, posy + size / 2, size / 2, 3.14159265, 4.71238898, false);
      c.stroke();
      break;
    default:
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx + 10, posy);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx, posy + 10);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx - 10, posy);
      c.stroke();
      c.beginPath();
      c.moveTo(posx, posy);
      c.lineTo(posx, posy - 10);
      c.stroke();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("ARCS.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "ARCS.JS"')
        sim.type_line("RUN")
        for _ in range(200):
            sim._rpc("TICK")
        raw = _fb_raw(sim)
        assert _fb_pix(raw, 100, 100) == 0, "spoke through cell center (join missed case)"
        assert _fb_pix(raw, 100, 110) != 0, "quarter-arc occupancy missing"
    finally:
        sim.shutdown()


def test_rtl_ghost_update_leaves_start_cell():
    """RTL twin: ghost-update snippet leaves the start cell (finder + COS)."""
    src = r"""
var size = 14, mx = 0, my = 0;
var _COS = [1, 0, -1, 0], _SIN = [0, 1, 0, -1];
function position2coord(x, y) {
  var fx = Math.abs(x - mx) % size - size / 2;
  var fy = Math.abs(y - my) % size - size / 2;
  return {
    x: Math.floor((x - mx) / size),
    y: Math.floor((y - my) / size),
    offset: Math.sqrt(fx * fx + fy * fy)
  };
}
function finder(params) {
  var options = Object.assign({}, {map: null, start: {}, end: {}}, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var data = [
  [1, 1, 1, 1],
  [1, 2, 2, 1],
  [1, 0, 0, 1],
  [1, 0, 0, 1]
];
var ghost = {
  x: mx + 1 * size + size / 2,
  y: my + 1 * size + size / 2,
  speed: 1,
  orientation: 3,
  status: 1,
  timeout: 0,
  coord: {x: 1, y: 1, offset: 0},
  vector: {x: 1, y: 1},
  path: []
};
var player = {coord: {x: 1, y: 3}};
var startx = ghost.x, starty = ghost.y;
var i;
for (i = 0; i < 40; i++) {
  ghost.coord = position2coord(ghost.x, ghost.y);
  if (ghost.timeout) ghost.timeout--;
  if (!ghost.coord.offset) {
    if (ghost.status == 1 && !ghost.timeout) {
      var new_map = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
      ghost.path = finder({map: new_map, start: ghost.coord, end: player.coord});
      if (ghost.path.length) {
        ghost.vector = ghost.path[0];
      }
      if (ghost.vector.x > ghost.coord.x) ghost.orientation = 0;
      else if (ghost.vector.x < ghost.coord.x) ghost.orientation = 2;
      else if (ghost.vector.y > ghost.coord.y) ghost.orientation = 1;
      else if (ghost.vector.y < ghost.coord.y) ghost.orientation = 3;
    }
  }
  ghost.x += ghost.speed * _COS[ghost.orientation];
  ghost.y += ghost.speed * _SIN[ghost.orientation];
}
var left = (ghost.x != startx || ghost.y != starty) ? 1 : 0;
function tick() {
  if (left) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("GHOST.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "GHOST.JS"')
        sim.type_line("RUN")
        for _ in range(200):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "ghost-update snippet did not leave start cell"
    finally:
        sim.shutdown()


def test_rtl_finder_many_frames_still_paths():
    """Array nursery rewind: finder JSON/steps temps must not pin n_arr."""
    src = r"""
var data = [
  [1,1,1,1],
  [1,2,2,1],
  [1,2,2,1],
  [0,0,0,0]
];
function finder(params) {
  var defaults = { map:null, start:{}, end:{}, type:'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(function() {
    return Array(x_length).fill(0);
  });
  var _getValue = function(x, y) {
    if (options.map[y] && typeof options.map[y][x] != 'undefined') {
      return options.map[y][x];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value == 0) {
        if (to.x == options.end.x && to.y == options.end.y) {
          steps[to.y][to.x] = from;
          finded = true;
        } else if (!steps[to.y][to.x]) {
          steps[to.y][to.x] = from;
          new_list.push(to);
        }
      }
    };
    list.forEach(function(current) {
      next(current, {y: current.y + 1, x: current.x});
      next(current, {y: current.y, x: current.x + 1});
      next(current, {y: current.y - 1, x: current.x});
      next(current, {y: current.y, x: current.x - 1});
    });
    if (!finded && new_list.length) {
      _render(new_list);
    }
  };
  _render([options.start]);
  if (finded) {
    var current = options.end;
    while (current.x != options.start.x || current.y != options.start.y) {
      result.unshift(current);
      current = steps[current.y][current.x];
    }
  }
  return result;
}
var n = 0;
function tick() {
  var opened = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
  var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
  if (path.length) n = n + 1;
  if (n >= 2) {
    fillRect(60, 10, 30, 30, 6);
    swapBuffers();
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("FINDN.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "FINDN.JS"')
        sim.type_line("RUN")
        for _ in range(2000):
            sim._rpc("TICK")
        assert _fb_nz(sim) >= 50, "finder temps pinned n_arr; later frames returned []"
    finally:
        sim.shutdown()


def test_rtl_setinterval_rearms():
    """setInterval must fire more than once (PYTHON twin test_setinterval_rearms_and_clear_cancels)."""
    src = """
var n = 0;
setInterval(function() {
  n = n + 1;
  if (n >= 2) {
    fillRect(10, 10, 30, 30, 2);
    swapBuffers();
  }
}, 0);
"""
    sim = _sim()
    try:
        _patch_js("INTV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "INTV.JS"')
        sim.type_line("RUN")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "setInterval did not rearm"
    finally:
        sim.shutdown()


def test_rtl_reverse_at_cell_center():
    """KEYEVT reverse is applied at the next cell center (PACMAN reverse stall)."""
    src = """
var size = 14;
var x = size / 2;
var dir = 1;
var queued = 1;
addEventListener("keydown", function(e) {
  if (e.keyCode === 37) queued = -1;
  if (e.keyCode === 39) queued = 1;
});
function tick() {
  var fx = Math.abs(x) % size - size / 2;
  if (!fx) dir = queued;
  x = x + dir;
  if (dir === -1) {
    fillRect(10, 10, 30, 30, 2);
  }
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    sim = _sim()
    try:
        _patch_js("REV.JS", src)
        sim._rpc("SDRELOAD")
        sim.type_line('LOAD "REV.JS"')
        sim.type_line("RUN")
        for _ in range(4):
            sim._rpc("FRAME")
        sim._rpc("KEYEVT 37 1")
        for _ in range(8):
            sim._rpc("FRAME")
        assert _fb_nz(sim) >= 50, "KEYEVT reverse did not apply at cell center"
    finally:
        sim.shutdown()

