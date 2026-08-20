"""Generic JS VM tests: closures, String.replace(RegExp), not title-specific."""

import math
import struct

import pytest

from functional_model.bytecode import Chunk, Op
from functional_model.compiler import compile_source
from functional_model.jsb_format import (
    FLAG_SOURCE_MAP,
    FLAG_VALUE64,
    MAGIC,
    NATIVE_IDS,
    ProgramImage,
    encode_chunk,
)
from functional_model.machine import Machine
from hardware_model import js_vm as value64
from hardware_model.js_vm import JsHwVm


def _run_js_frames(src: str, n_frames: int = 3) -> Machine:
    """Compile + run JS with rAF/timer drain (HTML bytecode path, no HTML file)."""
    m = Machine()
    chunk = compile_source(src)
    m.vm.natives = m._natives()
    m.vm.globals.clear()
    # Same seeds as HTML RUN (Object.assign / Date / document)
    m.vm.globals["Object"] = {"__class": "ObjectCtor"}
    m.vm.globals["Date"] = {"__class": "DateCtor"}
    m.vm.globals["performance"] = {"__class": "DateCtor"}
    m.vm.globals["document"] = {
        "__class": "Element",
        "addEventListener": 1,
        "removeEventListener": 1,
        "dispatchEvent": 1,
    }
    m.vm.globals["window"] = m.vm.globals["document"]
    m._html_chunk = chunk
    m._bytecode_html = True
    m._timers = []
    m._timer_seq = 1
    m._frame_no = 0
    m._raf_q = []
    m.running = True
    m.vm.run(chunk)
    assert m.vm.error is None, m.vm.error
    for _ in range(n_frames):
        m._bytecode_html_frame()
        assert m.vm.error is None, m.vm.error
    return m


def test_foreach_settimeout_captures_index():
    """Each forEach invocation must keep its own `i` when setTimeout fires."""
    m = _run_js_frames(
        """
var items = [10, 20, 30];
var hit = [];
items.forEach(function(el, i) {
  setTimeout(function() { hit.push(i); }, 0);
});
"""
    )
    hit = m.vm.globals.get("hit")
    assert hit == [0, 1, 2], hit


def test_foreach_settimeout_captures_index_arrow():
    """Arrow params are per-call slots too (HTML titles use =>)."""
    m = _run_js_frames(
        """
var items = [10, 20, 30];
var hit = [];
items.forEach((el, i) => {
  setTimeout(() => { hit.push(i); }, 0);
});
"""
    )
    hit = m.vm.globals.get("hit")
    assert hit == [0, 1, 2], hit


def test_nested_foreach_settimeout_splice_index_arrow():
    m = _run_js_frames(
        """
var grid = [10, 20, 30];
var shots = [20];
grid.forEach((inv, i) => {
  shots.forEach((p, j) => {
    if (inv === p) {
      setTimeout(() => { grid.splice(i, 1); }, 0);
    }
  });
});
"""
    )
    grid = m.vm.globals.get("grid")
    assert grid == [10, 30], grid


def test_object_identity_eq_not_deep():
    """JS === is identity: two {n:1} objects must not compare equal."""
    m = _run_js_frames(
        """
var a = {n:1};
var b = {n:1};
var same = a === b;
var id = a === a;
""",
        n_frames=0,
    )
    assert m.vm.globals.get("same") is False, m.vm.globals.get("same")
    assert m.vm.globals.get("id") is True, m.vm.globals.get("id")


def test_foreach_settimeout_splice_object_identity():
    """INVADERS-shaped: find(===) then splice(captured i), not last index."""
    m = _run_js_frames(
        """
var invaders = [{id:0},{id:1},{id:2}];
var shots = [invaders[1]];
invaders.forEach((invader, i) => {
  shots.forEach((projectile, j) => {
    if (projectile === invader) {
      setTimeout(() => {
        const found = invaders.find((inv2) => inv2 === invader);
        if (found) invaders.splice(i, 1);
      }, 0);
    }
  });
});
"""
    )
    ids = [x["id"] for x in m.vm.globals.get("invaders")]
    assert ids == [0, 2], ids


def test_for_let_in_callee_does_not_clobber_foreach_i():
    """for (let i) in a called function must not overwrite forEach's captured i.

    STORE_VAR walks the env chain, so a callee loop named `i` used to assign
    the caller's `i` (timeout splice then used the loop end, not the hit).
    """
    m = _run_js_frames(
        """
function helper() {
  for (let i = 0; i < 8; i++) {}
}
function update() {
  for (let i = 0; i < 3; i++) {}
  items.forEach((el, i) => {
    if (el.id === 1) {
      setTimeout(() => {
        helper();
        items.splice(i, 1);
      }, 0);
    }
  });
}
var items = [{id:0},{id:1},{id:2}];
update();
"""
    )
    ids = [x["id"] for x in m.vm.globals.get("items")]
    assert ids == [0, 2], ids


def test_arrow_two_params_nparam():
    """(el, i) => must compile MAKE_FN nparam=2 so forEach binds i."""
    from functional_model.bytecode import Op

    chunk = compile_source("var f = (el, i) => el;")
    makes = [c for c in chunk.code if c[0] == Op.MAKE_FN]
    assert makes, "expected MAKE_FN"
    assert int(makes[0][2]) == 2, makes[0]


def test_id_prop_postfix_dec_writes_back():
    """Bare `obj.n--` must store, not just subtract on the stack."""
    m = _run_js_frames(
        """
var item = {timeout: 5};
var i;
for (i = 0; i < 3; i++) {
  if (item.timeout) {
    item.timeout--;
  }
}
var left = item.timeout;
""",
        n_frames=0,
    )
    assert m.vm.error is None, m.vm.error
    assert m.vm.globals.get("left") == 2, m.vm.globals.get("left")


def test_json_stringify_replace_parse_nested_numbers():
    """stringify of nested number arrays + /2/g must open 'door' cells."""
    m = _run_js_frames(
        """
var data = [[1,2,1],[2,0,2]];
var n = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var door = n[0][1];
var start = n[1][0];
""",
        n_frames=0,
    )
    assert m.vm.globals.get("door") == 0, m.vm.globals.get("door")
    assert m.vm.globals.get("start") == 0, m.vm.globals.get("start")


def test_array_fill_map_mini_finder():
    """Array(n).fill(0).map(() => Array(m).fill(0)) + truthy-cell early out."""
    m = _run_js_frames(
        """
function finder(map, sy, sx, ey, ex) {
  if (map[sy][sx] || map[ey][ex]) return [];
  var steps = Array(map.length).fill(0).map(function() {
    return Array(map[0].length).fill(0);
  });
  return steps;
}
var data = [[0,2,0],[0,0,0]];
var open = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var blocked = finder(data, 0, 1, 1, 2);
var path = finder(open, 0, 1, 1, 2);
var plen = path.length;
var blen = blocked.length;
""",
        n_frames=0,
    )
    assert m.vm.globals.get("blen") == 0, m.vm.globals.get("blen")
    assert m.vm.globals.get("plen") == 2, m.vm.globals.get("plen")


def test_cell_center_mod_offset_is_zero():
    """position2coord at a cell center must yield offset 0 (pathing gate)."""
    m = _run_js_frames(
        """
var size = 14, mx = 50, my = 50, cx = 12, cy = 14;
var x = mx + cx * size + size / 2;
var y = my + cy * size + size / 2;
var fx = Math.abs(x - mx) % size - size / 2;
var fy = Math.abs(y - my) % size - size / 2;
var offset = Math.sqrt(fx * fx + fy * fy);
""",
        n_frames=0,
    )
    assert m.vm.globals.get("offset") == 0, m.vm.globals.get("offset")


def test_string_replace_regexp_global():
    m = _run_js_frames(
        """
var s = "[[2,1,2]]".replace(/2/g, 0);
""",
        n_frames=0,
    )
    assert m.vm.globals.get("s") == "[[0,1,0]]"


def test_string_replace_regexp_first_only():
    m = _run_js_frames(
        """
var s = "aaa".replace(/a/, "b");
""",
        n_frames=0,
    )
    assert m.vm.globals.get("s") == "baa"


def test_string_replace_string_first_only():
    m = _run_js_frames(
        """
var s = "aaa".replace("a", "b");
""",
        n_frames=0,
    )
    assert m.vm.globals.get("s") == "baa"


def test_var_fn_self_call_returns():
    """var rec = function(){ rec() } must CALL_VAL, not a dropped native stub."""
    m = _run_js_frames(
        """
var rec = function(n) {
  if (n >= 2) return 1;
  return rec(n + 1);
};
var finded = rec(0);
""",
        n_frames=0,
    )
    assert m.vm.globals.get("finded") == 1, m.vm.globals.get("finded")


def test_finder_opens_house_cell_and_paths():
    """stringify+replace+/2/g + real BFS from a closed (2) cell must path out.

    House tiles are truthy 2; finder returns [] unless replace opens them.
    Not a title gate — generic nested number map + Object.assign + object steps.
    """
    m = _run_js_frames(
        r"""
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
var blocked = finder({ map:data, start:{x:1,y:1}, end:{x:0,y:3} });
var path = finder({ map:opened, start:{x:1,y:1}, end:{x:0,y:3} });
var blen = blocked.length;
var plen = path.length;
var digitTwo = s.indexOf('2') >= 0 ? 1 : 0;
""",
        n_frames=0,
    )
    assert m.vm.error is None, m.vm.error
    assert m.vm.globals.get("digitTwo") == 1, m.vm.globals.get("s")
    assert m.vm.globals.get("blen") == 0, m.vm.globals.get("blen")
    assert int(m.vm.globals.get("plen") or 0) > 0, m.vm.globals.get("plen")


def test_position2coord_roundtrip_offset_falsy():
    """Cell-center round-trip must yield a falsy offset (pathing gate)."""
    m = _run_js_frames(
        """
var size = 14, mx = 50, my = 50, cx = 12, cy = 14;
var pos = { x: mx + cx * size + size / 2, y: my + cy * size + size / 2 };
var fx = Math.abs(pos.x - mx) % size - size / 2;
var fy = Math.abs(pos.y - my) % size - size / 2;
var offset = Math.sqrt(fx * fx + fy * fy);
var moved = Math.sqrt(
  (Math.abs(pos.x + 1 - mx) % size - size / 2) *
  (Math.abs(pos.x + 1 - mx) % size - size / 2)
);
var centerOk = !offset ? 1 : 0;
var movedOk = moved ? 1 : 0;
""",
        n_frames=0,
    )
    assert m.vm.globals.get("centerOk") == 1, m.vm.globals.get("offset")
    assert m.vm.globals.get("movedOk") == 1, m.vm.globals.get("moved")


def test_keydown_space_matches_case_space_char():
    """e.key for space must be U+0020, not 'Space' / undefined."""
    m = _run_js_frames(
        """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.key === " ") hit = 1;
  if (e.keyCode === 32 && e.key !== " ") hit = -1;
});
""",
        n_frames=0,
    )
    m.input.key_event(32, " ", True)
    m._bytecode_html_frame()
    assert m.vm.globals.get("hit") == 1, m.vm.globals.get("hit")


def test_push_then_burst_keeps_grid_identity():
    """Long-lived pushed objects must survive a burst of new nursery objs."""
    m = _run_js_frames(
        """
var grid = [];
grid.push({n:0});
grid.push({n:1});
var burst = [];
for (var i = 0; i < 8; i++) {
  burst.push({p:i, pos:{x:i, y:i}});
}
var still = (grid[0].n === 0 && grid[1].n === 1) ? 1 : 0;
""",
        n_frames=2,
    )
    assert m.vm.globals.get("still") == 1, m.vm.globals.get("still")


def test_nested_for_continue_skips_compound_cells():
    """Bunker-arch continue: nested for + compound &&/|| must skip cells.

    Chrome draws a stepped top because those continues fire; a no-op
    `continue` ID would push every cell (square bunker in PYTHON).
    """
    m = _run_js_frames(
        """
var cells = [];
var cols = 14, rows = 10;
for (var row = 0; row < rows; row++) {
  for (var col = 0; col < cols; col++) {
    if (row === 0 && (col < 2 || col > 11)) continue;
    if (row === 1 && (col < 1 || col > 12)) continue;
    if (row >= 6 && col >= 5 && col <= 8) continue;
    cells.push(col + row * 100);
  }
}
var n = cells.length;
var first = cells[0];
var row0last = cells[9];
""",
        n_frames=0,
    )
    # 14*10=140 minus 4 (row0 corners) minus 2 (row1 corners) minus 16 (door)
    assert m.vm.globals.get("n") == 118, m.vm.globals.get("n")
    assert m.vm.globals.get("first") == 2, m.vm.globals.get("first")
    assert m.vm.globals.get("row0last") == 11, m.vm.globals.get("row0last")


def test_array_find_identity_then_splice():
    """arr.find(cb) uses === identity so splice can drop the same object."""
    m = _run_js_frames(
        """
var grid = [{n:1}, {n:2}, {n:3}];
var a = grid[1];
var hit = grid.find(function(el) { return el === a; });
var ok = (hit === a) ? 1 : 0;
if (hit) grid.splice(1, 1);
var left = grid.length;
""",
        n_frames=0,
    )
    assert m.vm.globals.get("ok") == 1, m.vm.globals.get("ok")
    assert m.vm.globals.get("left") == 2, m.vm.globals.get("left")


def test_settimeout_delay_order_vs_zero():
    """setTimeout(fn, 1000) must not fire on the next frame; 0-delay does."""
    m = _run_js_frames(
        """
var seq = [];
setTimeout(function() { seq.push(1000); }, 1000);
setTimeout(function() { seq.push(0); }, 0);
""",
        n_frames=2,
    )
    seq = m.vm.globals.get("seq")
    assert seq == [0], seq
    for _ in range(70):
        m._bytecode_html_frame()
    seq = m.vm.globals.get("seq")
    assert seq == [0, 1000], seq


def test_setinterval_rearms_and_clear_cancels():
    m = _run_js_frames(
        """
var n = 0;
var id = setInterval(function() { n = n + 1; }, 0);
""",
        n_frames=3,
    )
    n = m.vm.globals.get("n")
    assert n >= 2, n
    tid = m.vm.globals.get("id")
    m._nat_clear_timer(tid)
    frozen = m.vm.globals.get("n")
    m._bytecode_html_frame()
    m._bytecode_html_frame()
    assert m.vm.globals.get("n") == frozen, m.vm.globals.get("n")


def test_two_keydown_listeners_remove_one():
    """Listener table: both fire; removeEventListener drops only that fn."""
    m = _run_js_frames(
        """
var a = 0, b = 0;
function fa(e) { if (e.key === "Enter") a = a + 1; }
function fb(e) { if (e.key === "Enter") b = b + 1; }
addEventListener("keydown", fa);
addEventListener("keydown", fb);
""",
        n_frames=0,
    )
    m.input.key_event(13, "Enter", True)
    m._bytecode_html_frame()
    assert m.vm.globals.get("a") == 1, m.vm.globals.get("a")
    assert m.vm.globals.get("b") == 1, m.vm.globals.get("b")
    fa = m.vm.globals.get("fa")
    m._nat_remove_event_listener("keydown", fa)
    m.input.key_event(13, "Enter", False)
    m._bytecode_html_frame()
    m.input.key_event(13, "Enter", True)
    m._bytecode_html_frame()
    assert m.vm.globals.get("a") == 1, m.vm.globals.get("a")
    assert m.vm.globals.get("b") == 2, m.vm.globals.get("b")


def test_dispatch_event_enter_advances_state():
    m = _run_js_frames(
        """
var st = 0;
addEventListener("keydown", function(e) {
  if (e.key === "Enter" || e.keyCode === 13) st = 1;
});
var ev = { type: "keydown", key: "Enter", keyCode: 13, which: 13 };
if (document.dispatchEvent) document.dispatchEvent(ev);
""",
        n_frames=0,
    )
    assert m.vm.globals.get("st") == 1, m.vm.globals.get("st")


def test_keyboard_event_ctor_sets_key():
    """new KeyboardEvent copies (type, options) so e.key === 'Enter' (DONKEY boot)."""
    m = _run_js_frames(
        """
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
""",
        n_frames=0,
    )
    assert m.vm.globals.get("st") == 1, m.vm.globals.get("st")


def test_join_empty_eq_case_1100():
    """Neighbor-bit join must EQ interned case labels (maze arcs vs spokes)."""
    m = _run_js_frames(
        """
var code = [1, 1, 0, 0];
var hit = 0;
var idx = code.indexOf(1);
switch (code.join('')) {
  case '1100': hit = 1; break;
  default: hit = 2;
}
""",
        n_frames=0,
    )
    assert m.vm.globals.get("idx") == 0, m.vm.globals.get("idx")
    assert m.vm.globals.get("hit") == 1, m.vm.globals.get("hit")


def test_switch_join_draws_arc_not_spokes():
    """Mini map: join '1100' strokes a quarter-arc, not four spokes from center."""
    m = _run_js_frames(
        """
var c = document.getElementById('c').getContext('2d');
c.strokeStyle = '#09f';
c.lineWidth = 2;
var code = [1, 1, 0, 0];
var size = 20;
var pos = {x: 100, y: 100};
switch (code.join('')) {
  case '1100':
    c.beginPath();
    c.arc(pos.x + size / 2, pos.y + size / 2, size / 2, 3.14159265, 4.71238898, false);
    c.stroke();
    break;
  default:
    c.beginPath();
    c.moveTo(pos.x, pos.y);
    c.lineTo(pos.x + 10, pos.y);
    c.stroke();
    c.beginPath();
    c.moveTo(pos.x, pos.y);
    c.lineTo(pos.x, pos.y + 10);
    c.stroke();
    c.beginPath();
    c.moveTo(pos.x, pos.y);
    c.lineTo(pos.x - 10, pos.y);
    c.stroke();
    c.beginPath();
    c.moveTo(pos.x, pos.y);
    c.lineTo(pos.x, pos.y - 10);
    c.stroke();
}
""",
        n_frames=1,
    )
    fb = m.canvas.front
    cx, cy, w = 100, 100, 640
    assert fb[cy * w + cx] == 0, "spoke through cell center (join missed case 1100)"
    # Arc center (110,110) r=10: left point (100,110) sits on the ring.
    assert fb[110 * w + 100] != 0, "quarter-arc occupancy missing"


def test_ghost_update_leaves_start_cell():
    """Timeout + !offset + finder + COS step must leave the start cell."""
    m = _run_js_frames(
        r"""
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
var gy = ghost.coord.y;
""",
        n_frames=0,
    )
    assert m.vm.error is None, m.vm.error
    assert m.vm.globals.get("left") == 1, (
        m.vm.globals.get("left"),
        m.vm.globals.get("gy"),
    )


def test_reverse_at_cell_center_applies_queued_dir():
    """Queued reverse takes effect only at cell center (generic, not a title)."""
    m = _run_js_frames(
        """
var size = 14;
var x = size / 2;
var dir = 1;
var queued = 1;
addEventListener("keydown", function(e) {
  if (e.keyCode === 37) queued = -1;
});
function tick() {
  var fx = Math.abs(x) % size - size / 2;
  if (!fx) dir = queued;
  x = x + dir;
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
""",
        n_frames=3,
    )
    m.input.key_event(37, "ArrowLeft", True)
    for _ in range(20):
        m._bytecode_html_frame()
    assert m.vm.globals.get("dir") == -1, m.vm.globals.get("dir")
    # Started at 7 going right for 3 frames, then reverse at next center.
    assert m.vm.globals.get("x") < 7 + 3 + 20, m.vm.globals.get("x")


def test_class_field_listener_sees_enter():
    """this.startSelect as a value must be a bound Fn (DONKEY title Enter)."""
    m = _run_js_frames(
        """
var hit = 0;
class G {
  startSelect = (e) => {
    if (e.key === "Enter") hit = 1;
  }
}
const g = new G();
addEventListener("keydown", g.startSelect);
function tick() { requestAnimationFrame(tick); }
requestAnimationFrame(tick);
""",
        n_frames=2,
    )
    m.input.key_event(13, "Enter", True)
    for _ in range(4):
        m._bytecode_html_frame()
    assert m.vm.globals.get("hit") == 1, m.vm.globals.get("hit")


def test_destructure_space_key_starts():
    """const { key } = e; key === ' ' (INVADERS start / fire)."""
    m = _run_js_frames(
        """
var hit = 0;
addEventListener("keydown", function(e) {
  const { key } = e;
  if (key === " ") hit = 1;
});
function tick() { requestAnimationFrame(tick); }
requestAnimationFrame(tick);
""",
        n_frames=2,
    )
    m.input.key_event(32, " ", True)
    for _ in range(4):
        m._bytecode_html_frame()
    assert m.vm.globals.get("hit") == 1, m.vm.globals.get("hit")


def test_click_listener_does_not_autostart():
    """addEventListener('click') must not fire without Element.click / a key."""
    m = _run_js_frames(
        """
var active = 0;
addEventListener("click", function() { active = 1; });
addEventListener("keydown", function(e) {
  const { key } = e;
  if (!active && key === " ") active = 1;
});
function tick() { requestAnimationFrame(tick); }
requestAnimationFrame(tick);
""",
        n_frames=8,
    )
    assert m.vm.globals.get("active") == 0, "click listener auto-fired"
    m.input.key_event(32, " ", True)
    for _ in range(4):
        m._bytecode_html_frame()
    assert m.vm.globals.get("active") == 1, m.vm.globals.get("active")


def test_queued_keybits_space_does_not_autostart():
    """Space while typing LOAD must not start the attract screen on RUN."""
    from functional_model.input_engine import JOY_FIRE1

    m = Machine()
    m.set_key_bits(JOY_FIRE1)
    m.set_key_bits(0)
    assert not m.input._events, "prompt KEYBITS queued JS keydown"
    # leftover path: InputEngine.set_key_bits still syncs (tests / tether)
    m.input.set_key_bits(JOY_FIRE1)
    m.input.set_key_bits(0)
    assert m.input._events
    src = """
var active = 0;
addEventListener("click", function() { active = 1; });
addEventListener("keydown", function(e) {
  const { key } = e;
  if (!active && key === " ") active = 1;
});
function tick() { requestAnimationFrame(tick); }
requestAnimationFrame(tick);
"""
    m.vm.natives = m._natives()
    m.vm.globals.clear()
    m.vm.globals["document"] = {"__class": "Element", "addEventListener": 1}
    m.vm.globals["window"] = m.vm.globals["document"]
    chunk = compile_source(src)
    m._html_chunk = chunk
    m._bytecode_html = True
    m._timers = []
    m._raf_q = []
    m._listeners = []
    m.input.discard_queued_keys()
    m.running = True
    m.vm.run(chunk)
    assert m.vm.error is None, m.vm.error
    for _ in range(8):
        m._bytecode_html_frame()
        assert m.vm.error is None, m.vm.error
    assert m.vm.globals.get("active") == 0, "prompt Space leaked into RUN"
    m.input.key_event(32, " ", True)
    for _ in range(4):
        m._bytecode_html_frame()
    assert m.vm.globals.get("active") == 1, m.vm.globals.get("active")


def test_findindex_identity():
    m = _run_js_frames(
        """
var a = [{id:1},{id:2}];
var i = a.findIndex(function(e) { return e.id == 2; });
""",
        n_frames=0,
    )
    assert m.vm.globals.get("i") == 1, m.vm.globals.get("i")


def test_typeof_number_not_undefined():
    m = _run_js_frames(
        """
var a = [0, 1];
var ok = (typeof a[0] != 'undefined') && (typeof a[1] != 'undefined');
""",
        n_frames=0,
    )
    assert m.vm.globals.get("ok") is True, m.vm.globals.get("ok")


def test_filter_keeps_truthy():
    m = _run_js_frames(
        """
var a = [0, 1, 0, 2];
var b = a.filter(function(x) { return x; });
var n = b.length;
var f = b[0];
var g = b[1];
""",
        n_frames=0,
    )
    assert m.vm.globals.get("n") == 2, m.vm.globals.get("n")
    assert m.vm.globals.get("f") == 1, m.vm.globals.get("f")
    assert m.vm.globals.get("g") == 2, m.vm.globals.get("g")


def test_for_of_sums():
    m = _run_js_frames(
        """
var s = 0;
for (const x of [1, 2, 3]) s = s + x;
""",
        n_frames=0,
    )
    assert m.vm.globals.get("s") == 6, m.vm.globals.get("s")


def test_program_image_source_map_round_trip():
    chunk = compile_source(
        """
var a = 1;
var b = a + 2;
"""
    )
    image = ProgramImage.from_chunk(chunk, v2=True)
    decoded = image.decode()
    assert image.flags & FLAG_SOURCE_MAP
    assert decoded.op_lines == chunk.op_lines
    assert len(decoded.op_lines) == len(decoded.code)


def test_program_image_source_map_tracks_compiler_rewrites():
    chunk = compile_source(
        """
class A { field = () => 1; }
var o = {n: 1};
o.n++;
({n: 2}).n++;
"""
    )
    assert len(chunk.op_lines) == len(chunk.code)
    assert ProgramImage.from_chunk(chunk, v2=True).decode().op_lines == chunk.op_lines


def test_hw_value64_loop_var_array_is_new_each_iteration():
    """while { var row = []; rows.push(row) } must not alias every row."""
    src = (
        "var rows = [];\n"
        "var r = 0;\n"
        "while (r < 3) {\n"
        "  var row = [];\n"
        "  row.push(r);\n"
        "  rows.push(row);\n"
        "  r = r + 1;\n"
        "}\n"
        "var hit = 0;\n"
        "if (rows[0][0] === 0 && rows[1][0] === 1 && rows[2][0] === 2) hit = 1;\n"
        "rows[1][0] = 9;\n"
        "if (hit === 1 && rows[0][0] === 0 && rows[2][0] === 2) hit = 2;\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 2.0


def test_hw_value64_nested_fn_loop_var_is_local():
    """Inner `var col = 0` must not reset an outer function's column cursor.

    STORE_VAR of an undeclared env slot writes the GLOBAL — two functions
    that both `var col` in a while then share one index and never finish.
    """
    src = (
        "var hit = 0;\n"
        "function inner() {\n"
        "  var col = 0;\n"
        "  while (col < 16) { col = col + 1; }\n"
        "}\n"
        "function outer() {\n"
        "  var col = 0;\n"
        "  var n = 0;\n"
        "  while (col < 24) {\n"
        "    if (col === 1 || col === 17) inner();\n"
        "    n = n + 1;\n"
        "    if (n > 200) { hit = -1; return; }\n"
        "    col = col + 1;\n"
        "  }\n"
        "  hit = n;\n"
        "}\n"
        "outer();\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 24.0


def test_hw_value64_fn_loop_var_array_is_new_each_iteration():
    """Same row-identity rule inside a function (LET_VAR local, not global)."""
    src = (
        "var hit = 0;\n"
        "function build() {\n"
        "  var rows = [];\n"
        "  var r = 0;\n"
        "  while (r < 3) {\n"
        "    var row = [];\n"
        "    row.push(r);\n"
        "    rows.push(row);\n"
        "    r = r + 1;\n"
        "  }\n"
        "  if (rows[0][0] === 0 && rows[1][0] === 1 && rows[2][0] === 2) hit = 1;\n"
        "  rows[1][0] = 9;\n"
        "  if (hit === 1 && rows[0][0] === 0 && rows[2][0] === 2) hit = 2;\n"
        "}\n"
        "build();\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 2.0


def test_hw_value64_leaf_calls_reuse_env():
    """CALL_USER of a param-only function must recycle env (no mid-run GC).

    600 leaf calls > ENV_DEPTH=512. Leaking until GC made a 24×26 sprite
    paint look frozen (one GC storm per frame).
    """
    src = (
        "function leaf(n) { var t = n + 1; return t; }\n"
        "var i = 0;\n"
        "var s = 0;\n"
        "while (i < 600) { s = s + leaf(1); i = i + 1; }\n"
        "var hit = (s === 1200) ? 1 : 0;\n"
    )
    vm = JsHwVm()
    collects = [0]
    orig = vm._value64_collect.__func__

    def wrapped(self, extra_roots=None):
        collects[0] += 1
        return orig(self, extra_roots)

    vm._value64_collect = wrapped.__get__(vm, JsHwVm)
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 1.0
    # One collect at end of execute; alloc_env must not GC mid-loop.
    assert collects[0] == 1, collects[0]


def test_hw_value64_char_eq_return_chain_lookup():
    """if (ch === "1") return 1; … must match a one-char object lookup."""
    src = (
        "function pal(ch) {\n"
        "  if (ch === '1') return 1;\n"
        "  if (ch === '2') return 2;\n"
        "  if (ch === '3') return 3;\n"
        "  if (ch === 'a') return 10;\n"
        "  return 0;\n"
        "}\n"
        "var hit = pal('2') + pal('a') + pal('0') + pal('z');\n"
    )
    chunk = compile_source(src)
    entry, _params = chunk.functions["pal"]
    body_eq = sum(1 for op in chunk.code if op[0] == Op.EQ)
    # The if-chain would emit ≥4 EQ; lookup uses ARRAY_GET + BIT_OR.
    assert body_eq == 0, body_eq
    vm = JsHwVm()
    vm.load_blob(encode_chunk(chunk, v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 12.0


def test_hw_value64_leaf_call_inlined_into_nested_loop():
    """Param-only callee at a CALL_USER site is copied, not a heap env."""
    src = (
        "function pal(ch) {\n"
        "  if (ch === '1') return 1;\n"
        "  if (ch === '2') return 2;\n"
        "  if (ch === '3') return 3;\n"
        "  if (ch === 'a') return 10;\n"
        "  return 0;\n"
        "}\n"
        "function walk(rows) {\n"
        "  var r = 0;\n"
        "  var s = 0;\n"
        "  while (r < rows.length) {\n"
        "    var c = 0;\n"
        "    var row = rows[r];\n"
        "    while (c < row.length) {\n"
        "      s = s + pal(row[c]);\n"
        "      c = c + 1;\n"
        "    }\n"
        "    r = r + 1;\n"
        "  }\n"
        "  return s;\n"
        "}\n"
        "var hit = walk(['12', 'a0']);\n"
    )
    chunk = compile_source(src)
    pal_entry, _ = chunk.functions["pal"]
    assert not any(
        op[0] == Op.CALL_USER and len(op) > 1 and op[1] == pal_entry
        for op in chunk.code
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(chunk, v2=True, value64=True))
    assert vm.error is None, vm.error
    # '1'+'2'+'a'+'0' → 1+2+10+0
    assert vm.globals.get("hit") == 13.0


def test_hw_value64_closure_survives_outer_return():
    """MAKE_FN must keep the captured env after the outer function returns."""
    src = (
        "function outer() {\n"
        "  var n = 7;\n"
        "  return function inner() { return n; };\n"
        "}\n"
        "var f = outer();\n"
        "var hit = f();\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 7.0


def test_encode_keeps_long_layout_string_stubs_only_data_uri():
    """NAMB must keep 624-char layout literals; only fat data: URIs stub."""
    layout = "#" * 624
    fat = "data:image/png;base64," + ("A" * 600)
    chunk = compile_source("var lay = '" + layout + "'; var img = '" + fat + "';")
    names = ProgramImage(encode_chunk(chunk, v2=True, value64=True)).decode().names
    assert layout in names
    assert "data:stub" in names
    assert fat not in names


def test_hw_value64_long_string_index_strict_eq():
    """cellCh pattern: interned s[i] === '.' past the old 512 stub cap."""
    lit = ("#" * 10) + ("." * 8) + ("#" * 606)
    src = (
        "var s = '" + lit + "';\n"
        "var hit = 0;\n"
        "if (s.length === 624 && s[10] === '.' && s[500] === '#') hit = 1;\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 1.0


def test_program_image_rejects_corrupt_trailer_and_truncated_aset():
    chunk = compile_source("var answer = 7;")
    corrupt = bytearray(encode_chunk(chunk, v2=True))
    smap = corrupt.index(b"SMAP")
    corrupt[smap : smap + 4] = b"XMAP"
    with pytest.raises(ValueError, match="SMAP"):
        ProgramImage(corrupt)

    aset_blob = encode_chunk(
        chunk, v2=True, sprites=[(2, 2, b"\x01\x02\x03\x04")], aset=True
    )
    with pytest.raises(ValueError, match="ASET.*length|ProgramImage size"):
        ProgramImage(aset_blob[:-1])


def test_program_image_rejects_rtl_capacity_excess():
    # Header rejection must happen before the absent constant body is read.
    blob = bytearray(MAGIC + struct.pack("<HHHH", 0, 1025, 0, 0))
    with pytest.raises(ValueError, match=r"n_consts 1025 > MAX_CONSTS 1024"):
        ProgramImage(blob)


def test_hw_vm_executes_serialized_program_image_not_compiler_chunk():
    chunk = compile_source("var answer = 7;")
    image = ProgramImage.from_chunk(chunk, v2=True)
    chunk.consts[:] = [99 for _ in chunk.consts]

    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals.get("answer") == 7
    assert vm._m._html_chunk is not chunk
    checkpoint = vm.checkpoint()
    assert "frames" in checkpoint
    assert "queues" in checkpoint
    assert checkpoint["error_code"] == value64.ERROR_NONE


def test_hw_vm_queue_capacity_fails_loudly():
    src = "function f() {}\n" + "\n".join(
        "setTimeout(f, 1000);" for _ in range(65)
    )
    image = ProgramImage.from_chunk(compile_source(src), v2=True)

    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error == "ERROR: HM VALUE64: timer queue overflow (65 > 64) at IP 263"


def test_value64_layout_and_nan_canonicalization():
    undefined = value64.value_pack_tagged(value64.VALUE_KIND_UNDEFINED)
    boolean = value64.value_pack_tagged(value64.VALUE_KIND_BOOL, payload=1)

    assert undefined == 0x7FF9100000000000
    assert boolean == 0x7FF9300000000001
    assert value64.value_kind(undefined) == value64.VALUE_KIND_UNDEFINED
    assert value64.value_payload(boolean) == 1
    assert value64.value_is_number(value64.value_pack_number(3.5))
    assert value64.value_pack_number(float("nan")) == value64.VALUE_CANON_NAN


def test_value64_binary64_division_remainder_and_bitwise_contract():
    number = value64.value_pack_number
    unpack = value64.value_unpack_number

    assert unpack(value64.value_add(number(0.1), number(0.2))) == pytest.approx(0.3)
    assert unpack(value64.value_mod(number(-7), number(3))) == -1
    assert unpack(value64.value_mod(number(7), number(-3))) == 1
    assert math.isinf(unpack(value64.value_div(number(1), number(0))))
    assert math.isnan(unpack(value64.value_div(number(0), number(0))))
    assert unpack(value64.value_bit_or(number(1.9), number(0))) == 1
    assert unpack(value64.value_bit_or(number(float("nan")), number(0))) == 0
    assert unpack(value64.value_bit_or(number(2**40), number(0))) == 0
    assert unpack(value64.value_bit_and(number(-1), number(3))) == 3
    true_b = value64.value_pack_tagged(value64.VALUE_KIND_BOOL, payload=1)
    false_b = value64.value_pack_tagged(value64.VALUE_KIND_BOOL, payload=0)
    # Grouped switch cases OR EQ bools; true|false must be 1, not 0.
    assert unpack(value64.value_bit_or(true_b, false_b)) == 1
    assert unpack(value64.value_bit_or(false_b, false_b)) == 0


def test_program_image_value64_constant_pool_round_trip():
    image = ProgramImage.from_chunk(
        compile_source("var x=0.1; var y=7;"), v2=True, value64=True
    )
    decoded = image.decode()

    assert image.version == 2
    assert image.flags & FLAG_VALUE64
    assert any(
        isinstance(value, float) and value == pytest.approx(0.1)
        for value in decoded.consts
    )
    assert 7.0 in decoded.consts

    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error
    assert vm.globals["x"] == pytest.approx(0.1)
    assert vm.globals["y"] == 7.0


def test_program_image_value64_preserves_distinct_binary64_literals():
    first = 1.0000000000000002
    second = 1.0000000000000004
    image = ProgramImage.from_chunk(
        compile_source(f"var a={first!r}; var b={second!r};"),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["a"] == first
    assert vm.globals["b"] == second
    assert vm.globals["a"] != vm.globals["b"]


def test_hw_value64_executes_code_mem_not_decoded_chunk(monkeypatch):
    image = ProgramImage.from_chunk(
        compile_source(
            """
var x = 2;
if (x < 3) x = (x + 5) * 2;
else x = 0;
var rem = x % 3;
var bits = (7.9 | 0) & 3;
"""
        ),
        v2=True,
        value64=True,
    )
    decoded = image.decode()
    decoded.consts[:] = [99 for _ in decoded.consts]
    decoded.code[:] = [(Op.RETURN,)]

    def fail_if_decoded(_image):
        raise AssertionError("Value64 execution decoded a Chunk")

    monkeypatch.setattr(ProgramImage, "decode", fail_if_decoded)
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["x"] == 14.0
    assert vm.globals["rem"] == 2.0
    assert vm.globals["bits"] == 3.0
    assert vm._m._html_chunk is None


def test_hw_value64_binary64_edges_execute_from_words():
    image = ProgramImage.from_chunk(
        compile_source(
            "var pos=1/0; var neg=-1/0; var nan=0/0; var rem=-7%3;"
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert math.isinf(vm.globals["pos"]) and vm.globals["pos"] > 0
    assert math.isinf(vm.globals["neg"]) and vm.globals["neg"] < 0
    assert math.isnan(vm.globals["nan"])
    assert vm.globals["rem"] == -1.0


def test_hw_value64_nested_array_object_identity_and_cycles():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var inner = [1, 2];
var obj = {items: [inner, {n: 3}]};
var got = obj.items[1].n;
obj.self = obj;
var same = obj.self === obj;
inner[1] = 9;
var changed = obj.items[0][1];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["got"] == 3.0
    assert vm.globals["same"] is True
    assert vm.globals["changed"] == 9.0


def test_hw_value64_gc_reclaims_churn_before_slot_capacity_fault():
    arrays = ProgramImage.from_chunk(
        Chunk(
            [(Op.MAKE_ARRAY, 0), (Op.POP,)] * (value64.MAX_ARRAYS + 1),
            [],
            [],
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(arrays)
    assert vm.error is None, vm.error
    assert not any(slot is not None for slot in vm._value_arrays)

    objects = ProgramImage.from_chunk(
        Chunk(
            [(Op.MAKE_OBJ,), (Op.POP,)] * (value64.MAX_OBJECTS + 1),
            [],
            [],
        ),
        v2=True,
        value64=True,
    )
    vm.load_image(objects)
    assert vm.error is None, vm.error
    assert not any(slot is not None for slot in vm._value_objects)

    properties = ",".join(
        f"p{index}:{index}" for index in range(value64.OBJECT_SLOTS + 1)
    )
    vm.load_image(
        ProgramImage.from_chunk(
            compile_source(f"var o={{{properties}}};"), v2=True, value64=True
        )
    )
    assert vm.error is not None
    assert (
        f"object slots {value64.OBJECT_SLOTS + 1} > {value64.OBJECT_SLOTS}"
        in vm.error
    )


def test_hw_value64_rooted_cycle_survives_allocator_gc():
    code = [
        (Op.MAKE_OBJ,),
        (Op.DUP,),
        (Op.DUP,),
        (Op.SET_PROP, 1),
        (Op.POP,),
        (Op.STORE_VAR, 0),
    ]
    code.extend([(Op.MAKE_OBJ,), (Op.POP,)] * value64.MAX_OBJECTS)
    image = ProgramImage.from_chunk(
        Chunk(code, [], ["root", "self"]), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    root = vm._value_vars[0]
    obj = vm._value64_resolve_object(root, 0, Op.GET_PROP)
    assert obj is not None
    assert obj[1] == root
    assert sum(slot is not None for slot in vm._value_objects) == 1


def test_hw_value64_collected_handle_faults_stale_then_free():
    image = ProgramImage.from_chunk(
        compile_source("var a=[];"), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(image)
    handle = vm._value_vars[0]
    slot = value64.value_payload(handle)
    old_generation = value64.value_generation(handle)

    vm._value_var_valid[0] = False
    vm._value64_collect()
    new_generation = vm._value_array_generations[slot]
    assert new_generation != old_generation

    vm.error = None
    assert vm._value64_resolve_array(handle, 0, Op.ARRAY_GET) is None
    assert vm.error == (
        "ERROR: HM VALUE64: stale array handle at IP 0 "
        f"(slot {slot} generation {old_generation} != {new_generation})"
    )

    vm.error = None
    free_handle = value64.value_pack_tagged(
        value64.VALUE_KIND_ARRAY, new_generation, slot
    )
    assert vm._value64_resolve_array(free_handle, 0, Op.ARRAY_GET) is None
    assert vm.error == f"ERROR: HM VALUE64: free array handle at IP 0 (slot {slot})"


def test_hw_value64_serialized_strings_console_and_numeric_natives():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var s = "hello";
console.log(s);
var expectedType = "number";
var typeName = typeof 3;
var floorValue = Math.floor(3.75);
var rootValue = Math.sqrt(81);
var nowValue = Date.now();
clear(0);
fillRect(1, 1, 2, 2, 5);
swapBuffers();
"""
        ),
        v2=True,
        value64=True,
    )
    assert "hello" in image.names
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["s"] == "hello"
    assert vm.console_log == [("hello",)]
    assert vm.globals["typeName"] == "number"
    assert vm.globals["floorValue"] == 3.0
    assert vm.globals["rootValue"] == 9.0
    assert vm.globals["nowValue"] == 0.0
    assert vm.canvas.front[1 * vm.canvas.width + 1] == 5


def test_hw_value64_frame_order_input_then_raf_then_timer():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var order = 0;
function onKey() { order = order * 10 + 3; }
function onRaf() { order = order * 10 + 1; }
function onTimer() { order = order * 10 + 2; }
addEventListener("keydown", onKey);
requestAnimationFrame(onRaf);
setTimeout(onTimer, 0);
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error
    assert vm.running

    vm.input.key_event(13, "Enter", True)
    vm.frame_tick()

    assert vm.error is None, vm.error
    assert vm.globals["order"] == 312.0
    assert not vm._value_raf
    assert not vm._value_timers


def test_hw_value64_remove_listener_and_clear_timers():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var count = 0;
function callback() { count = count + 1; }
addEventListener("keydown", callback);
removeEventListener("keydown", callback);
var timeoutId = setTimeout(callback, 0);
clearTimeout(timeoutId);
var intervalId = setInterval(callback, 0);
clearInterval(intervalId);
requestAnimationFrame(callback);
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error

    vm.input.key_event(13, "Enter", True)
    vm.frame_tick()

    assert vm.error is None, vm.error
    assert vm.globals["count"] == 1.0
    assert not vm._value_listeners
    assert not vm._value_timers


def test_hw_value64_async_queue_overflows_fail_loudly():
    raf_source = "function f(){}" + "requestAnimationFrame(f);" * (
        value64.RAF_QUEUE_DEPTH + 1
    )
    vm = JsHwVm()
    vm.load_image(
        ProgramImage.from_chunk(
            compile_source(raf_source), v2=True, value64=True
        )
    )
    assert vm.error is not None
    assert (
        f"rAF queue overflow ({value64.RAF_QUEUE_DEPTH + 1} > "
        f"{value64.RAF_QUEUE_DEPTH})"
    ) in vm.error

    timer_source = "function f(){}" + "setTimeout(f,0);" * (
        value64.TIMER_QUEUE_DEPTH + 1
    )
    vm.load_image(
        ProgramImage.from_chunk(
            compile_source(timer_source), v2=True, value64=True
        )
    )
    assert vm.error is not None
    assert (
        f"timer queue overflow ({value64.TIMER_QUEUE_DEPTH + 1} > "
        f"{value64.TIMER_QUEUE_DEPTH})"
    ) in vm.error

    listener_source = "".join(
        f"function f{index}(){{}}"
        for index in range(value64.LISTENERS_PER_EVENT + 1)
    ) + "".join(
        f'addEventListener("keydown",f{index});'
        for index in range(value64.LISTENERS_PER_EVENT + 1)
    )
    vm.load_image(
        ProgramImage.from_chunk(
            compile_source(listener_source), v2=True, value64=True
        )
    )
    assert vm.error is not None
    assert (
        f"listener overflow ({value64.LISTENERS_PER_EVENT + 1} > "
        f"{value64.LISTENERS_PER_EVENT})"
    ) in vm.error


def test_hw_value64_functions_share_object_heap_capacity():
    image = ProgramImage.from_chunk(
        compile_source("var f=()=>1; var root={};"), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error

    function_slot = value64.value_payload(
        vm._value_vars[image.var_names.index("f")]
    )
    root_handle = vm._value_vars[image.var_names.index("root")]
    root_slot = value64.value_payload(root_handle)
    # Functions and objects are separate 1024-slot banks (same leftover-BRAM
    # width). Both may occupy index 0; filling the object bank must not skip
    # a function index as if it were an object hole.
    assert value64.value_kind(vm._value_vars[image.var_names.index("f")]) == (
        value64.VALUE_KIND_FUNCTION
    )
    assert value64.value_kind(root_handle) == value64.VALUE_KIND_OBJECT

    previous = root_slot
    for slot in range(value64.MAX_OBJECTS):
        if slot == root_slot:
            continue
        vm._value_objects[slot] = {}
        vm._value_objects[previous][0] = value64.value_pack_tagged(
            value64.VALUE_KIND_OBJECT,
            vm._value_object_generations[slot],
            slot,
        )
        previous = slot
    vm.error = None
    assert vm._value64_alloc_object(0) is None
    assert vm.error == (
        "ERROR: HM VALUE64: object heap overflow "
        f"({value64.MAX_OBJECTS + 1} > {value64.MAX_OBJECTS}) at IP 0"
    )


def test_hw_value64_class_constructor_method_and_this():
    image = ProgramImage.from_chunk(
        compile_source(
            """
class Counter {
  constructor(value) { this.value = value; }
  add(delta) { return this.value + delta; }
  get current() { return this.value; }
}
var counter = new Counter(2);
var result = counter.add(3);
var boundAdd = counter.add;
var boundResult = boundAdd(4);
var getterResult = counter.current;
"""
        ),
        v2=True,
        value64=True,
    )
    assert image.classes
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["result"] == 5.0
    assert vm.globals["boundResult"] == 6.0
    assert vm.globals["getterResult"] == 2.0


def test_hw_value64_array_map_and_foreach_closures():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var input = [1, 2, 3];
var mapped = input.map(function(value) { return value + 1; });
var sum = 0;
mapped.forEach(function(value) { sum = sum + value; });
var second = mapped[1];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["sum"] == 9.0
    assert vm.globals["second"] == 3.0


def test_hw_value64_json_round_trip_and_cycle_failure():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var source = {x: 7, values: [1, 2]};
var text = JSON.stringify(source);
var parsed = JSON.parse(text);
var result = parsed.x + parsed.values[1];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["result"] == 9.0

    cyclic = ProgramImage.from_chunk(
        compile_source(
            "var value={}; value.self=value; var text=JSON.stringify(value);"
        ),
        v2=True,
        value64=True,
    )
    vm.load_image(cyclic)
    assert vm.error is not None
    assert "JSON.stringify" in vm.error
    assert "cyclic object" in vm.error


def test_hw_value64_string_replace_and_split():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var changed = "a-b-a".replace("a", "x");
var pieces = changed.split("-");
var first = pieces[0];
var last = pieces[2];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["changed"] == "x-b-a"
    assert vm.globals["first"] == "x"
    assert vm.globals["last"] == "a"


def test_hw_value64_number_concat_js_tostring_object_key():
    """JS ToString: 1+','+3 is '1,3' so obj['1,3'] hits the literal key."""
    image = ProgramImage.from_chunk(
        compile_source(
            """
var goods = {'1,3': 1};
var i = 1;
var j = 3;
var key = i + ',' + j;
var hit = goods[key];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error
    assert vm.globals["key"] == "1,3"
    assert vm.globals["hit"] == 1.0


def test_hw_value64_regex_replace_flags_and_comparator_sort():
    image = ProgramImage.from_chunk(
        compile_source(
            """
var changed = "A-a-A".replace(/a/gi, "x");
var values = [3, 1, 2];
values.sort(function(a, b) { return a - b; });
var first = values[0];
var last = values[2];
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["changed"] == "x-x-x"
    assert vm.globals["first"] == 1.0
    assert vm.globals["last"] == 3.0


def test_hw_value64_storage_dom_image_array_and_dispatch():
    image = ProgramImage.from_chunk(
        compile_source(
            """
localStorage.setItem("score", "7");
var stored = localStorage.getItem("score");
localStorage.removeItem("score");
var removed = localStorage.getItem("score");
var element = document.createElement("div");
element.value = 9;
var elementValue = element.value;
var image = Image();
image.src = "asset";
var imageWidth = image.width;
var list = Array(3);
var listLength = list.length;
var hit = 0;
function onKey(event) { hit = event.keyCode; }
addEventListener("keydown", onKey);
var event = {type: "keydown", keyCode: 13};
document.dispatchEvent(event);
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["stored"] == "7"
    assert vm.globals["removed"] is None
    assert vm.globals["elementValue"] == 9.0
    assert vm.globals["imageWidth"] == 1.0
    assert vm.globals["listLength"] == 3.0
    assert vm.globals["hit"] == 13.0


@pytest.mark.parametrize("native_id", sorted(set(NATIVE_IDS.values())))
def test_hw_value64_every_registered_native_has_dispatch(native_id):
    image = ProgramImage.from_chunk(
        compile_source(
            'var f=function(){}; var key="score"; var value="0"; '
            'var eventName="keydown"; var typeName="type";'
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error

    function = vm._value_vars[image.var_names.index("f")]
    key = vm._value_vars[image.var_names.index("key")]
    value = vm._value_vars[image.var_names.index("value")]
    event_name = vm._value_vars[image.var_names.index("eventName")]
    event = vm._value64_alloc_object(0)
    assert event is not None
    event_obj = vm._value_objects[value64.value_payload(event)]
    type_index = vm._value_strings.index("type")
    event_obj[type_index] = event_name

    args_by_id = {
        19: [event_name, function],
        20: [event_name, function],
        21: [key],
        22: [key, value],
        23: [value],
        24: [value64.value_pack_number(0)],
        27: [function],
        28: [function, value64.value_pack_number(0)],
        29: [function, value64.value_pack_number(0)],
        30: [value64.value_pack_number(1)],
        31: [value64.value_pack_number(1)],
        32: [key],
        34: [value64.value_pack_number(1)],
        36: [event_name, function],
        37: [event_name, function],
        38: [event],
        39: [event],
        40: [value64.value_pack_number(1)],
    }
    vm.error = None
    vm._value64_native(native_id, args_by_id.get(native_id, []), 0)
    assert vm.error is None or "unsupported native ID" not in vm.error


def test_hw_value64_declares_every_opcode_supported():
    assert value64.VALUE64_SUPPORTED_OPS == frozenset(Op)


def test_hw_value64_checkpoint_is_raw_and_deterministic():
    image = ProgramImage.from_chunk(
        compile_source("var zero=0; var cycle={}; cycle.self=cycle;"),
        v2=True,
        value64=True,
    )
    first = JsHwVm()
    second = JsHwVm()
    first.load_image(image)
    second.load_image(image)

    checkpoint = first.checkpoint()
    assert checkpoint == second.checkpoint()
    assert checkpoint == first.checkpoint()
    assert checkpoint["error_code"] == value64.ERROR_NONE

    zero_slot = image.var_names.index("zero")
    first._value_vars[zero_slot] = value64.value_pack_number(-0.0)
    assert first.globals["zero"] == 0.0
    assert first.checkpoint()["vars"] != checkpoint["vars"]

    before_uninitialized = first.checkpoint()["vars"]
    first._value_vars[value64.MAX_VARS - 1] = value64.value_pack_number(99)
    assert first.checkpoint()["vars"] == before_uninitialized
    first._value_var_valid[value64.MAX_VARS - 1] = True
    assert first.checkpoint()["vars"] != before_uninitialized


def test_hw_value64_checkpoint_heap_cycles_and_mutations():
    image = ProgramImage.from_chunk(
        compile_source(
            "var object={n:1}; object.self=object; "
            "var array=[object]; object.array=array;"
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    before = vm.checkpoint()
    assert before["heap"] == vm.checkpoint()["heap"]

    object_handle = vm._value_vars[image.var_names.index("object")]
    object_slot = value64.value_payload(object_handle)
    name_index = image.names.index("n")
    vm._value_objects[object_slot][name_index] = value64.value_pack_number(2)
    after = vm.checkpoint()

    assert after["heap"] != before["heap"]
    assert after["vars"] == before["vars"]


def test_hw_value64_checkpoint_queue_and_frame_sensitivity():
    image = ProgramImage.from_chunk(
        compile_source(
            """
function first() {}
function second() {}
requestAnimationFrame(first);
requestAnimationFrame(second);
setTimeout(first, 100);
addEventListener("keydown", second);
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    before = vm.checkpoint()
    assert before["raf"] == 2
    assert before["timers"] == 1
    assert before["listeners"] == 1

    vm._value_raf.reverse()
    reordered = vm.checkpoint()
    assert reordered["queues"] != before["queues"]
    assert reordered["raf"] == before["raf"]

    undefined = value64.value_pack_tagged(value64.VALUE_KIND_UNDEFINED)
    vm._value_calls.append(
        value64._ValueCallFrame(
            return_ip=7,
            base_sp=len(vm._value_stack),
            this_value=undefined,
            lexical_env=undefined,
            function_handle=undefined,
            constructor_value=undefined,
        )
    )
    framed = vm.checkpoint()
    assert framed["frames"] != reordered["frames"]
    assert framed["csp"] == reordered["csp"] + 1

    canvas_before = framed["canvas"]
    vm.canvas.front[0] ^= 1
    assert vm.checkpoint()["canvas"] != canvas_before


def test_hw_value64_checkpoint_numeric_error_code():
    image = ProgramImage.from_chunk(
        Chunk([(Op.NEW_OBJ, 0, 0)], [], ["Missing"]),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)
    checkpoint = vm.checkpoint()

    assert checkpoint["error_code"] == value64.ERROR_UNSUPPORTED
    assert checkpoint["error"] == vm.error


def test_hw_value64_unknown_class_fails_without_legacy_delegate():
    image = ProgramImage.from_chunk(
        Chunk([(Op.NEW_OBJ, 0, 0)], [], ["C"]),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error == "ERROR: HM VALUE64: unknown class name index 0 at IP 0"
    assert vm._m._html_chunk is None


def test_hw_value64_call_frame_returns_balanced():
    image = ProgramImage.from_chunk(
        Chunk(
            [
                (Op.LOAD_CONST, 0),
                (Op.CALL_USER, 4, 1),
                (Op.STORE_VAR, 1),
                (Op.JUMP, 9),
                (Op.LET_VAR, 0, 1),
                (Op.LOAD_VAR, 0),
                (Op.LOAD_CONST, 1),
                (Op.ADD,),
                (Op.RET_VAL,),
            ],
            [2, 1],
            ["x", "result"],
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["result"] == 3.0
    assert vm.checkpoint()["csp"] == 0


def test_hw_value64_nested_closure_capture():
    image = ProgramImage.from_chunk(
        compile_source(
            """
function make(x) {
  return function(y) { return x + y; };
}
var add2 = make(2);
var result = add2(3);
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["result"] == 5.0
    add2_slot = image.var_names.index("add2")
    assert (
        value64.value_kind(vm._value_vars[add2_slot])
        == value64.VALUE_KIND_FUNCTION
    )


def test_hw_value64_closure_instances_keep_independent_environments():
    image = ProgramImage.from_chunk(
        compile_source(
            """
function make(x) {
  return function() {
    x = x + 1;
    return x;
  };
}
var a = make(1);
var b = make(10);
var a1 = a();
var b1 = b();
var a2 = a();
"""
        ),
        v2=True,
        value64=True,
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["a1"] == 2.0
    assert vm.globals["b1"] == 11.0
    assert vm.globals["a2"] == 3.0


def test_hw_value64_closure_environment_survives_allocator_gc():
    source = (
        "function make(x){return function(){return x;};}"
        "var f=make(7);"
        + "({});" * value64.MAX_OBJECTS
        + "var result=f();"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is None, vm.error
    assert vm.globals["result"] == 7.0
    assert sum(env is not None for env in vm._value_envs) == 1


def test_hw_value64_environment_depth_overflow_fails_loudly():
    n = value64.ENV_DEPTH + 1
    source = (
        "function make(x){return function(){return x;};}"
        "var head = null;"
        f"for (var i = 0; i < {n}; i = i + 1) {{"
        "head = {f: make(1), next: head};"
        "}"
    )
    image = ProgramImage.from_chunk(
        compile_source(source), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error is not None
    assert (
        f"environment heap overflow ({value64.ENV_DEPTH + 1} > "
        f"{value64.ENV_DEPTH})"
    ) in vm.error


def test_hw_value64_stack_and_call_bounds_fail_loudly():
    underflow = ProgramImage.from_chunk(
        Chunk([(Op.DUP,)], [], []), v2=True, value64=True
    )
    vm = JsHwVm()
    vm.load_image(underflow)
    assert vm.error == "ERROR: HM VALUE64: eval stack underflow at IP 0 (DUP)"

    overflow = ProgramImage.from_chunk(
        Chunk([(Op.LOAD_CONST, 0)] * (value64.STACK_DEPTH + 1), [1], []),
        v2=True,
        value64=True,
    )
    vm.load_image(overflow)
    assert vm.error == (
        "ERROR: HM VALUE64: eval stack overflow "
        f"({value64.STACK_DEPTH + 1} > {value64.STACK_DEPTH})"
    )

    call_overflow = ProgramImage.from_chunk(
        Chunk([(Op.CALL_USER, 0, 0)], [], []), v2=True, value64=True
    )
    vm.load_image(call_overflow)
    # CALL_USER at IP 0 calls itself; call-stack cap trips before env heap.
    assert vm.error == (
        "ERROR: HM VALUE64: call stack overflow "
        f"({value64.CALL_DEPTH + 1} > {value64.CALL_DEPTH})"
    )

    unbalanced_return = ProgramImage.from_chunk(
        Chunk(
            [
                (Op.CALL_USER, 2, 0),
                (Op.JUMP, 5),
                (Op.LOAD_CONST, 0),
                (Op.LOAD_CONST, 0),
                (Op.RET_VAL,),
            ],
            [1],
            [],
        ),
        v2=True,
        value64=True,
    )
    vm.load_image(unbalanced_return)
    assert vm.error == (
        "ERROR: HM VALUE64: call stack imbalance at IP 4 (sp 1 != base 0)"
    )

    unbalanced_halt = ProgramImage.from_chunk(
        Chunk([(Op.LOAD_CONST, 0), (Op.RETURN,)], [1], []),
        v2=True,
        value64=True,
    )
    vm.load_image(unbalanced_halt)
    assert vm.error == (
        "ERROR: HM VALUE64: eval stack imbalance at IP 1 (sp 1 != 0)"
    )


def test_html_program_image_is_value64_and_machine_uses_hw_vm():
    """Product HTML compile emits Value64; PYTHON RUN executes those words."""
    from pathlib import Path

    from tools.compile_js import compile_html_text, encode_html_chunk

    html = (
        "<html><body><canvas></canvas><script>\n"
        "var hits = 0;\n"
        "function tick() { hits = hits + 1; requestAnimationFrame(tick); }\n"
        "requestAnimationFrame(tick);\n"
        "</script></body></html>\n"
    )
    image = ProgramImage(encode_html_chunk(compile_html_text(html)))
    assert image.flags & FLAG_VALUE64

    machine = Machine()
    machine.source_name = "TICK.HTML"
    out = machine._run_html_bytecode(html)
    assert machine._hw_vm is not None
    assert machine._hw_vm.error is None, machine._hw_vm.error
    assert "ERROR" not in out[0]
    machine.frame_tick()
    assert machine._hw_vm.globals.get("hits") == 1

    invaders = Path(__file__).resolve().parents[1] / "storage" / "INVADERS.HTML"
    if invaders.is_file():
        title = invaders.read_text(encoding="utf-8")
        title_image = ProgramImage(encode_html_chunk(compile_html_text(title)))
        assert title_image.flags & FLAG_VALUE64
        assert title_image.flags & 2  # FLAG_ASET


def test_hw_value64_grouped_switch_cases_or_bools():
    """Compiler BIT_OR of EQ bools must take grouped switch cases."""
    from hardware_model.js_vm import JsHwVm

    source = (
        "var hit = 0;\n"
        "var k = 'ArrowRight';\n"
        "switch (k) {\n"
        "  case 'd':\n"
        "  case 'ArrowRight':\n"
        "    hit = 1;\n"
        "    break;\n"
        "}\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 1.0


def test_hw_value64_date_now_get_prop_call():
    """Date.now compiles as GET_PROP + CALL_VAL on the interned constructor name."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source("var t = Date.now();"),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("t") == 0.0


def test_hw_value64_array_push_70():
    """ARRAY_ELEMENTS=128: a 70-brick bunker list must not capacity-fault."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source(
                "var cells=[]; var i=0; while(i<70){cells.push(i); i=i+1;} "
                "var n=cells.length;"
            ),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("n") == 70.0


def test_hw_value64_array_pop():
    """Array.pop must shrink length (clearArr / any HTML while-pop loop)."""
    vm = _hw_v64(
        "var a=[1,2,3]; var x=a.pop(); var n=a.length; var e=[].pop();"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("x") == 3.0
    assert vm.globals.get("n") == 2.0
    assert vm.globals.get("e") is None


def test_hw_value64_index_non_array_is_undefined():
    """1[0] is undefined (JS), not a machine fault. Stale handles still fault."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source("var missing=1[0]; var ok=[9][0];"),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("missing") is None
    assert vm.globals.get("ok") == 9.0


def test_hw_value64_set_prop_on_primitive_is_noop():
    """x.foo = 1 when x is a Number must not halt (sloppy JS / Chunk VM)."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source("var n=1; n.foo=2; var ok=n;"),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("ok") == 1.0


def test_hw_value64_computed_object_index_get_set():
    """obj[key] is ARRAY_GET/SET on objects, not arrays-only."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source(
                "var o={}; var k='hits'; o[k]=3; var got=o[k];"
            ),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("got") == 3.0


def test_hw_value64_missing_function_args_are_undefined():
    """f(a,b) called as f(1) binds b=undefined; new Ctor(one) is the same."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source(
                "function f(a,b){ return b; }\n"
                "var missing = f(1);\n"
                "function G(id, params){ this.id = id; this.params = params; }\n"
                "var g = new G('canvas');\n"
                "var pid = g.id;\n"
                "var p = g.params;\n"
            ),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("missing") is None
    assert vm.globals.get("pid") == "canvas"
    assert vm.globals.get("p") is None


def test_hw_value64_function_prototype_methods():
    """new Ctor() instances see methods assigned on Ctor.prototype."""
    vm = JsHwVm()
    vm.load_blob(
        encode_chunk(
            compile_source(
                "function Box(n){ this.n = n; }\n"
                "Box.prototype.get = function(){ return this.n; };\n"
                "var b = new Box(7);\n"
                "var x = b.get();\n"
            ),
            v2=True,
            value64=True,
        )
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("x") == 7.0


def test_hw_value64_image_src_fires_onload():
    """Image.src must run onload so sprite size/position setup can complete."""
    from hardware_model.js_vm import JsHwVm

    source = (
        "var w = 0;\n"
        "var img = new Image();\n"
        "img.onload = function() { w = img.width; };\n"
        'img.src = "asset";\n'
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("w") == 1.0

    # INVADERS-style: src is assigned before onload.
    source_late = (
        "var w = 0;\n"
        "var img = new Image();\n"
        'img.src = "asset";\n'
        "img.onload = function() { w = img.width; };\n"
    )
    late = JsHwVm()
    late.load_blob(encode_chunk(compile_source(source_late), v2=True, value64=True))
    assert late.error is None, late.error
    assert late.globals.get("w") == 1.0

    # Pending Image must survive allocator GC before the deferred onload flush.
    churn = (
        "var w = 0;\n"
        "var img = new Image();\n"
        'img.src = "asset";\n'
        "img.onload = function() { w = img.width; };\n"
        "var i = 0;\n"
        "while (i < 9000) { var t = {}; i = i + 1; }\n"
    )
    churn_vm = JsHwVm()
    churn_vm.load_blob(encode_chunk(compile_source(churn), v2=True, value64=True))
    assert churn_vm.error is None, churn_vm.error
    assert churn_vm.globals.get("w") == 1.0


def test_hw_value64_arrow_onload_captures_constructor_this():
    """Arrow in a constructor must keep lexical this across deferred Image.onload."""
    from hardware_model.js_vm import JsHwVm, value_kind, value_payload

    source = (
        "class Player {\n"
        "  constructor() {\n"
        "    this.width = 0;\n"
        "    this.image = null;\n"
        "    const image = new Image();\n"
        '    image.src = "asset";\n'
        "    image.onload = () => {\n"
        "      this.image = image;\n"
        "      this.width = image.width * 0.12;\n"
        "    };\n"
        "  }\n"
        "}\n"
        "var player = new Player();\n"
        "var i = 0;\n"
        "while (i < 9000) { var t = {}; i = i + 1; }\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    handle = vm._value_vars[list(vm.program_image.var_names).index("player")]
    obj = vm._value_objects[value_payload(handle)]
    names = vm.program_image.names
    assert vm._value64_host_value(obj.get(names.index("width"))) == pytest.approx(0.12)
    assert value_kind(obj.get(names.index("image"))) == 5


def test_hw_value64_raf_method_onload_reads_global():
    """Image.onload in a method must still LOAD_VAR globals after the rAF caller returns.

    The onload arrow captures the method env; that env's parent is the rAF
    frame. RET must not recycle the parent or `ctx` walks a stale handle.
    """
    from hardware_model.js_vm import JsHwVm

    source = (
        "var ctx = 7;\n"
        "var hits = 0;\n"
        "class G {\n"
        "  show() {\n"
        "    var img = new Image();\n"
        "    img.src = 'asset';\n"
        "    img.onload = () => { hits = ctx; };\n"
        "  }\n"
        "}\n"
        "function tick() {\n"
        "  new G().show();\n"
        "}\n"
        "requestAnimationFrame(tick);\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("hits") == 7.0


def test_invaders_hm_held_left_changes_framebuffer():
    """INVADERS: start, then held left must change live game state."""
    from pathlib import Path

    from hardware_model.js_vm import (
        VALUE_KIND_RECORD,
        record_unpack,
        value_kind,
        value_payload,
    )

    invaders = Path(__file__).resolve().parents[1] / "storage" / "INVADERS.HTML"
    if not invaders.is_file():
        pytest.skip("INVADERS.HTML missing")
    machine = Machine()
    machine.source_name = "INVADERS.HTML"
    out = machine._run_html_bytecode(invaders.read_text(encoding="utf-8"))
    hw = machine._hw_vm
    assert hw is not None
    assert hw.error is None, hw.error
    assert "ERROR" not in out[0]
    names = hw.program_image.names
    game_handle = hw._value_vars[list(hw.program_image.var_names).index("game")]
    player_handle = hw._value_vars[list(hw.program_image.var_names).index("player")]

    def prop(handle, name):
        obj = hw._value_objects[value_payload(handle)]
        return hw._value64_host_value(obj.get(names.index(name)))

    machine.input.key_event(32, " ", True)
    machine.frame_tick()
    machine.input.key_event(32, " ", False)
    for _ in range(3):
        machine.frame_tick()
        assert hw.error is None, hw.error
    assert prop(game_handle, "active")

    def player_x():
        # GC may compact {x,y} to a RECORD immediate; SET_PROP boxes it back.
        word = hw._value_objects[value_payload(player_handle)][
            names.index("position")
        ]
        followed = hw._value64_record_follow(word)
        if value_kind(followed) == VALUE_KIND_RECORD:
            return float(record_unpack(followed)[3])
        obj = hw._value_objects[value_payload(followed)]
        return hw._value64_host_value(obj.get(names.index("x")))

    before = player_x()
    machine.input.key_event(39, "ArrowRight", True)
    for _ in range(4):
        machine.frame_tick()
        assert hw.error is None, hw.error
    after = player_x()
    assert after != before, (before, after)
    assert hw.checkpoint()["raf"] >= 1
    # Glass: splash must paint more than one palette index (not solid white).
    uniq = set(hw.canvas.front[::17])
    assert len(uniq) >= 2, uniq


def test_donkey_hm_enter_keeps_raf_armed():
    """DONKEY: Enter must leave rAF live (title → next screen)."""
    from pathlib import Path

    donkey = Path(__file__).resolve().parents[1] / "storage" / "DONKEY.HTML"
    if not donkey.is_file():
        pytest.skip("DONKEY.HTML missing")
    machine = Machine()
    machine.source_name = "DONKEY.HTML"
    out = machine._run_html_bytecode(donkey.read_text(encoding="utf-8"))
    hw = machine._hw_vm
    assert hw is not None
    assert hw.error is None, hw.error
    assert "ERROR" not in out[0]
    for _ in range(4):
        machine.frame_tick()
        assert hw.error is None, hw.error
    machine.input.key_event(13, "Enter", True)
    machine.frame_tick()
    machine.input.key_event(13, "Enter", False)
    machine.frame_tick()
    # HTML: first Enter → character select; second Enter → game + update() rAF.
    machine.input.key_event(13, "Enter", True)
    machine.frame_tick()
    machine.input.key_event(13, "Enter", False)
    for _ in range(6):
        machine.frame_tick()
        assert hw.error is None, hw.error
    assert hw.checkpoint()["raf"] >= 1
    # Glass: title art must blit from ASET (not a black clearRect-only frame).
    uniq = set(hw.canvas.front[::17])
    assert len(uniq) >= 2, uniq


def test_pacman_hm_raf_stays_armed():
    """PACMAN: RUN must leave rAF live (title auto-advances via nested rAF)."""
    from pathlib import Path

    pacman = Path(__file__).resolve().parents[1] / "storage" / "PACMAN.HTML"
    if not pacman.is_file():
        pytest.skip("PACMAN.HTML missing")
    machine = Machine()
    machine.source_name = "PACMAN.HTML"
    out = machine._run_html_bytecode(pacman.read_text(encoding="utf-8"))
    hw = machine._hw_vm
    assert hw is not None, out
    assert hw.error is None, hw.error
    assert "ERROR" not in out[0]
    for _ in range(8):
        machine.frame_tick()
        assert hw.error is None, hw.error
    assert hw.checkpoint()["raf"] >= 1
    # Glass: maze/HUD must paint more than a solid fillStyle-white frame.
    uniq = set(hw.canvas.front[::17])
    assert len(uniq) >= 2, uniq
    # Power pellets: goods['1,3'] draws arc r=3..4, not the 4×4 fillRect.
    from functional_model.canvas_engine import nearest_palette_index

    beige = nearest_palette_index(hw.canvas.palette, (245, 245, 220), lo=1)
    w = hw.canvas.width
    cx, cy = 16 + 1 * 14 + 7, 8 + 3 * 14 + 7
    blob = 0
    for yy in range(cy - 5, cy + 6):
        row = yy * w
        for xx in range(cx - 5, cx + 6):
            if hw.canvas.front[row + xx] == beige:
                blob += 1
    assert blob > 16, blob


def test_html_run_clears_leftover_monitor_pixels():
    """HTML RUN wipes both FBs so leftover READY/WORKING cannot show through."""
    html = (
        "<html><body><canvas></canvas><script>\n"
        'var c = document.querySelector("canvas").getContext("2d");\n'
        'c.fillStyle = "#ffffff";\n'
        "c.fillRect(8, 8, 4, 4);\n"
        "</script></body></html>\n"
    )
    machine = Machine()
    machine.source_name = "WIPE.HTML"
    machine.canvas.front[:] = bytes([3]) * len(machine.canvas.front)
    machine.canvas.back[:] = bytes([3]) * len(machine.canvas.back)
    out = machine._run_html_bytecode(html)
    assert "ERROR" not in out[0]
    assert machine.canvas.front[0] != 3
    assert machine.canvas.back[0] != 3


def test_hw_value64_p0_raf_callback_rearms():
    """rAF callback must run on frame_tick and re-arm if it calls rAF."""
    source = (
        "var hits = 0;\n"
        "function tick() {\n"
        "  hits = hits + 1;\n"
        "  requestAnimationFrame(tick);\n"
        "}\n"
        "requestAnimationFrame(tick);\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    assert vm.globals.get("hits") == 0.0
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("hits") == 1.0
    assert vm._value_raf, "rAF did not re-arm"
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("hits") == 2.0
    assert vm._value_raf, "rAF dropped after second frame"


def test_hw_value64_p0_getcontext_fillrect_paints():
    """querySelector('canvas').getContext('2d') + fillRect + swapBuffers paints."""
    source = (
        'var c = document.querySelector("canvas").getContext("2d");\n'
        'c.fillStyle = "#ffffff";\n'
        "c.fillRect(8, 8, 4, 4);\n"
        "swapBuffers();\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    pixel = vm.canvas.front[8 * vm.canvas.width + 8]
    assert pixel != 0, pixel


def test_hw_value64_p0_keydown_key_and_keycode():
    """keydown listener must see e.key and e.keyCode from input.key_event."""
    source = (
        'var seenKey = "";\n'
        "var seenCode = 0;\n"
        'addEventListener("keydown", function(e) {\n'
        "  seenKey = e.key;\n"
        "  seenCode = e.keyCode;\n"
        "});\n"
    )
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(source), v2=True, value64=True))
    assert vm.error is None, vm.error
    vm.input.key_event(13, "Enter", True)
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("seenKey") == "Enter", vm.globals.get("seenKey")
    assert vm.globals.get("seenCode") == 13.0, vm.globals.get("seenCode")


def _hw_v64(src: str) -> JsHwVm:
    vm = JsHwVm()
    vm.load_blob(encode_chunk(compile_source(src), v2=True, value64=True))
    return vm


def _hw_html(html: str) -> JsHwVm:
    from tools.compile_js import compile_html_text, encode_html_chunk

    vm = JsHwVm()
    vm.load_blob(encode_html_chunk(compile_html_text(html)))
    return vm


def test_hw_value64_p0_getelementbyid_canvas():
    """document.getElementById must return a node that getContext can paint."""
    vm = _hw_v64(
        'var c = document.getElementById("c").getContext("2d");\n'
        "c.fillRect(4, 4, 2, 2);\n"
        "swapBuffers();\n"
    )
    assert vm.error is None, vm.error
    assert vm.canvas.front[4 * vm.canvas.width + 4] != 0


def test_hw_value64_p0_html_overlay_ignored():
    """Hidden overlay markup must not block canvas script (HUD is Canvas)."""
    vm = _hw_html(
        "<html><body>"
        '<div id="start" hidden>START</div>'
        '<canvas id="c" width="640" height="480"></canvas>'
        "<script>var ok = 1;</script>"
        "</body></html>"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("ok") == 1.0


def test_hw_value64_p1_multiple_scripts_share_globals():
    """Multiple <script> blocks concatenate; later script sees earlier vars."""
    vm = _hw_html(
        "<html><body><canvas></canvas>"
        "<script>var a = 1;</script>"
        "<script>var b = a + 2;</script>"
        "</body></html>"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("b") == 3.0


def test_hw_value64_p1_array_splice_filter_join_find():
    """Array push/splice/filter/fill/join/indexOf/find must work on JsHwVm."""
    vm = _hw_v64(
        """
var grid = [1, 2, 3];
grid.push(4);
grid.splice(1, 1);
var filled = [0, 0, 0].fill(9);
var kept = [0, 7, 0].filter(function(v) { return v; });
var joined = [1, 1, 0, 0].join("");
var idx = [9, 8, 7].indexOf(8);
var obj = {n: 2};
var found = [{n: 1}, obj].find(function(el) { return el === obj; });
var foundN = found.n;
var g0 = grid[0];
var g1 = grid[1];
var f0 = filled[0];
var k0 = kept[0];
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("joined") == "1100"
    assert vm.globals.get("idx") == 1.0
    assert vm.globals.get("foundN") == 2.0
    assert vm.globals.get("g0") == 1.0
    assert vm.globals.get("g1") == 3.0
    assert vm.globals.get("f0") == 9.0
    assert vm.globals.get("k0") == 7.0


def test_hw_value64_p1_object_assign():
    """Object.assign copies enumerable fields onto the target."""
    vm = _hw_v64(
        """
var t = {a: 1};
Object.assign(t, {b: 2});
var sum = t.a + t.b;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("sum") == 3.0


def test_hw_value64_object_assign_second_source():
    """Object.assign(target, a, b) must copy b (PACMAN Item settings+params)."""
    vm = _hw_v64(
        """
var t = {times: 0};
Object.assign(t, {times: 0, orientation: 0}, {orientation: 3});
var ok = (t.times == 0 && t.orientation == 3) ? 1 : 0;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("ok") == 1.0


# Nested forEach → finder (Object.assign coord objects + JSON 28-wide clone).
# Same source as tests/test_rtl_snippets.py test_rtl_value64_nested_foreach_finder.
_NESTED_FOREACH_FINDER_JS = r"""
var data = [];
var y, x;
for (y = 0; y < 8; y++) {
  data[y] = [];
  for (x = 0; x < 28; x++) data[y][x] = 1;
}
for (x = 0; x < 28; x++) { data[0][x] = 1; data[7][x] = 1; }
for (y = 1; y < 7; y++) { data[y][0] = 1; data[y][27] = 1; }
for (x = 1; x < 27; x++) data[6][x] = 0;
data[5][12] = 2; data[5][13] = 2; data[5][14] = 2; data[5][15] = 2;
data[4][12] = 1; data[4][13] = 2; data[4][14] = 2; data[4][15] = 1;
data[3][13] = 0; data[3][14] = 0;
function finder(params) {
  var defaults = { map: null, start: {}, end: {}, type: 'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(() => Array(x_length).fill(0));
  var _getValue = function(gx, gy) {
    if (options.map[gy] && typeof options.map[gy][gx] != 'undefined') {
      return options.map[gy][gx];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value < 1) {
        if (value == -1) {
          to.x = (to.x + x_length) % x_length;
          to.y = (to.y + y_length) % y_length;
          to.change = 1;
        }
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
    if (!finded && new_list.length) _render(new_list);
  };
  _render([options.start]);
  if (finded) {
    var cur = options.end;
    while (cur.x != options.start.x || cur.y != options.start.y) {
      result.unshift(cur);
      cur = steps[cur.y][cur.x];
    }
  }
  return result;
}
var opened = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var actor = { coord: {x: 13, y: 5, offset: 0}, path: [] };
var goal = { coord: {x: 2, y: 6, offset: 0} };
function update(item) {
  item.path = finder({ map: opened, start: item.coord, end: goal.coord });
}
var items = [actor];
items.forEach(function(item) {
  update(item);
});
var plen = actor.path.length;
if (plen) fillRect(10, 10, 20, 20, 2);
swapBuffers();
function tick() {
  if (plen) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""


def test_hw_value64_nested_foreach_finder_paths():
    """Outer forEach → finder ARRAY_SET of to.x must path a JSON-cloned 28-wide map."""
    vm = _hw_v64(_NESTED_FOREACH_FINDER_JS)
    assert vm.error is None, vm.error
    assert int(vm.globals.get("plen") or 0) > 0, vm.globals.get("plen")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


# Play-frame composition the house-only finder snippet never ran: Map.prototype
# coord2position/position2coord/finder (CALL_METHOD + this.size), Object.assign
# of pixel x/y onto the actor (createItem/resetItems), full-canvas getImageData,
# then finder ARRAY_SET of to.x. Glass 241 is that ARRAY_SET (IP 818); divs=2
# is position2coord /size, not finder wrap.
_PROTO_COORD_FINDER_JS = r"""
var data = [];
var y, x;
for (y = 0; y < 8; y++) {
  data[y] = [];
  for (x = 0; x < 28; x++) data[y][x] = 1;
}
for (x = 0; x < 28; x++) { data[0][x] = 1; data[7][x] = 1; }
for (y = 1; y < 7; y++) { data[y][0] = 1; data[y][27] = 1; }
for (x = 1; x < 27; x++) data[6][x] = 0;
data[5][12] = 2; data[5][13] = 2; data[5][14] = 2; data[5][15] = 2;
data[4][12] = 1; data[4][13] = 2; data[4][14] = 2; data[4][15] = 1;
data[3][13] = 0; data[3][14] = 0;
function Map() {
  this.x = 16;
  this.y = 8;
  this.size = 14;
}
Map.prototype.coord2position = function(cx, cy) {
  return {
    x: this.x + cx * this.size + this.size / 2,
    y: this.y + cy * this.size + this.size / 2
  };
};
Map.prototype.position2coord = function(px, py) {
  var fx = Math.abs(px - this.x) % this.size - this.size / 2;
  var fy = Math.abs(py - this.y) % this.size - this.size / 2;
  return {
    x: Math.floor((px - this.x) / this.size),
    y: Math.floor((py - this.y) / this.size),
    offset: Math.sqrt(fx * fx + fy * fy)
  };
};
Map.prototype.finder = function(params) {
  var defaults = { map: null, start: {}, end: {}, type: 'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(() => Array(x_length).fill(0));
  var _getValue = function(gx, gy) {
    if (options.map[gy] && typeof options.map[gy][gx] != 'undefined') {
      return options.map[gy][gx];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value < 1) {
        if (value == -1) {
          to.x = (to.x + x_length) % x_length;
          to.y = (to.y + y_length) % y_length;
          to.change = 1;
        }
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
    if (!finded && new_list.length) _render(new_list);
  };
  _render([options.start]);
  if (finded) {
    var cur = options.end;
    while (cur.x != options.start.x || cur.y != options.start.y) {
      result.unshift(cur);
      cur = steps[cur.y][cur.x];
    }
  }
  return result;
};
var map = new Map();
var opened = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var actor = { coord: {x: 13, y: 5, offset: 0}, path: [], location: map, x: 0, y: 0 };
Object.assign(actor, map.coord2position(actor.coord.x, actor.coord.y));
var c = document.getElementById('c').getContext('2d');
c.getImageData(0, 0, 640, 480);
actor.coord = map.position2coord(actor.x, actor.y);
function update(item) {
  item.path = map.finder({ map: opened, start: item.coord, end: {x: 2, y: 6} });
}
var items = [actor];
items.forEach(function(item) {
  update(item);
});
var plen = actor.path.length;
var pxok = (actor.x > 100) ? 1 : 0;
if (plen) fillRect(10, 10, 20, 20, 2);
if (pxok) fillRect(40, 10, 20, 20, 3);
swapBuffers();
function tick() {
  if (plen) fillRect(10, 10, 20, 20, 2);
  if (pxok) fillRect(40, 10, 20, 20, 3);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""


def test_hw_value64_proto_coord_finder_after_getimagedata():
    """Map proto coord round-trip + getImageData then finder ARRAY_SET must path."""
    vm = _hw_v64(_PROTO_COORD_FINDER_JS)
    assert vm.error is None, vm.error
    assert int(vm.globals.get("pxok") or 0) == 1, vm.globals.get("pxok")
    assert int(vm.globals.get("plen") or 0) > 0, vm.globals.get("plen")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


# Glass play FRAME: maps.forEach → getImageData, then items.forEach → finder.
# Natives inside a forEach callback used to share vnat_base with the iterator
# (comment on vfe_base). House finder + getImageData *outside* forEach is green;
# this is the order Enter actually runs.
_FOREACH_GETIMG_FINDER_JS = r"""
var data = [];
var y, x;
for (y = 0; y < 8; y++) {
  data[y] = [];
  for (x = 0; x < 28; x++) data[y][x] = 1;
}
for (x = 0; x < 28; x++) { data[0][x] = 1; data[7][x] = 1; }
for (y = 1; y < 7; y++) { data[y][0] = 1; data[y][27] = 1; }
for (x = 1; x < 27; x++) data[6][x] = 0;
data[5][12] = 2; data[5][13] = 2; data[5][14] = 2; data[5][15] = 2;
data[4][12] = 1; data[4][13] = 2; data[4][14] = 2; data[4][15] = 1;
data[3][13] = 0; data[3][14] = 0;
function finder(params) {
  var defaults = { map: null, start: {}, end: {}, type: 'path' };
  var options = Object.assign({}, defaults, params);
  if (options.map[options.start.y][options.start.x] ||
      options.map[options.end.y][options.end.x]) {
    return [];
  }
  var finded = false;
  var result = [];
  var y_length = options.map.length;
  var x_length = options.map[0].length;
  var steps = Array(y_length).fill(0).map(() => Array(x_length).fill(0));
  var _getValue = function(gx, gy) {
    if (options.map[gy] && typeof options.map[gy][gx] != 'undefined') {
      return options.map[gy][gx];
    }
    return -1;
  };
  var _render = function(list) {
    var new_list = [];
    var next = function(from, to) {
      var value = _getValue(to.x, to.y);
      if (value < 1) {
        if (value == -1) {
          to.x = (to.x + x_length) % x_length;
          to.y = (to.y + y_length) % y_length;
          to.change = 1;
        }
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
    if (!finded && new_list.length) _render(new_list);
  };
  _render([options.start]);
  if (finded) {
    var cur = options.end;
    while (cur.x != options.start.x || cur.y != options.start.y) {
      result.unshift(cur);
      cur = steps[cur.y][cur.x];
    }
  }
  return result;
}
var opened = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var actor = { coord: {x: 13, y: 5, offset: 0}, path: [] };
function update(item) {
  item.path = finder({ map: opened, start: item.coord, end: {x: 2, y: 6} });
}
var c = document.getElementById('c').getContext('2d');
var maps = [0];
var items = [actor];
maps.forEach(function() {
  c.getImageData(0, 0, 640, 480);
});
items.forEach(function(item) {
  update(item);
});
var plen = actor.path.length;
if (plen) fillRect(10, 10, 20, 20, 2);
swapBuffers();
function tick() {
  if (plen) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""


def test_hw_value64_foreach_getimagedata_then_finder():
    """getImageData inside forEach then a second forEach finder must still path."""
    vm = _hw_v64(_FOREACH_GETIMG_FINDER_JS)
    assert vm.error is None, vm.error
    assert int(vm.globals.get("plen") or 0) > 0, vm.globals.get("plen")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


# PACMAN position2coord params are `x`,`y` — same intern ids as the returned
# keys. The proto snippet above used px/py and stayed green; this is the HTML.
_PARAM_X_COORD_SET_JS = r"""
function Map() { this.x = 16; this.y = 8; this.size = 14; }
Map.prototype.position2coord = function(x, y) {
  return {
    x: Math.floor((x - this.x) / this.size),
    y: Math.floor((y - this.y) / this.size),
    offset: 0
  };
};
var map = new Map();
var c = map.position2coord(205, 85);
var steps = Array(8).fill(0).map(function() { return Array(28).fill(0); });
var to = {y: c.y + 1, x: c.x};
steps[to.y][to.x] = c;
var ok = (to.x == 13 && steps[6][13]) ? 1 : 0;
if (ok) fillRect(10, 10, 20, 20, 2);
swapBuffers();
function tick() {
  if (ok) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""


def test_hw_value64_param_x_coord_array_set():
    """position2coord(x,y) return keys must ARRAY_SET steps[to.y][to.x]."""
    vm = _hw_v64(_PARAM_X_COORD_SET_JS)
    assert vm.error is None, vm.error
    assert int(vm.globals.get("ok") or 0) == 1, vm.globals.get("ok")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


def _maze31_neighbor_set_js():
    """31×28 JSON clone + forEach {y:current.y+1,x:current.x} ARRAY_SET."""
    from test_rtl_snippets import _MAZE31

    return (
        "var data = [" + _MAZE31 + "];\n"
        + r"""
var opened = JSON.parse(JSON.stringify(data).replace(/2/g, 0));
var steps = Array(opened.length).fill(0).map(function() {
  return Array(opened[0].length).fill(0);
});
var start = {x: 12, y: 14};
[start].forEach(function(current) {
  var to = {y: current.y + 1, x: current.x};
  if (opened[to.y][to.x] < 1) steps[to.y][to.x] = current;
});
var ok = steps[15][12] ? 1 : 0;
if (ok) fillRect(10, 10, 20, 20, 2);
swapBuffers();
function tick() {
  if (ok) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""
    )


def test_hw_value64_maze31_neighbor_array_set():
    """JSON 31×28 house cell neighbor ARRAY_SET must store to.x."""
    vm = _hw_v64(_maze31_neighbor_set_js())
    assert vm.error is None, vm.error
    assert int(vm.globals.get("ok") or 0) == 1, vm.globals.get("ok")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


# 12× new Ctor(Object.assign this, settings, params-with-fn) inside forEach.
# PACMAN glass fault=2 vcsp=128 was new Stage during _COIGIG.forEach, not finder.
_FOREACH_CTOR_ASSIGN_JS = r"""
function Ctor(params) {
  this._params = params || {};
  this._settings = { index: 0, items: [], update: function() {} };
  Object.assign(this, this._settings, this._params);
}
var n = 0;
var configs = [0,1,2,3,4,5,6,7,8,9,10,11];
configs.forEach(function(c) {
  var obj = new Ctor({
    update: function() { n = n + 100; }
  });
  if (obj.items && obj.index == 0) n = n + 1;
});
if (n == 12) fillRect(10, 10, 20, 20, 2);
swapBuffers();
function tick() {
  if (n == 12) fillRect(10, 10, 20, 20, 2);
  swapBuffers();
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
"""


def test_hw_value64_foreach_ctor_assign_function_prop():
    """forEach + new Ctor + Object.assign function prop must not overflow the call stack."""
    vm = _hw_v64(_FOREACH_CTOR_ASSIGN_JS)
    assert vm.error is None, vm.error
    assert int(vm.globals.get("n") or 0) == 12, vm.globals.get("n")
    assert vm.canvas.front[10 * vm.canvas.width + 10] != 0


def test_hw_value64_p1_function_bind():
    """Function.bind must fix this for a later call."""
    vm = _hw_v64(
        """
var obj = {n: 3};
function add(x) { return this.n + x; }
var bound = add.bind(obj);
var got = bound(4);
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("got") == 7.0


def test_hw_value64_p1_dispatch_keyboardevent():
    """new KeyboardEvent + dispatchEvent must deliver e.key to a listener."""
    vm = _hw_v64(
        """
var hit = 0;
addEventListener("keydown", function(e) {
  if (e.key === "Enter" && e.keyCode === 13) hit = 1;
});
var ev = new KeyboardEvent("keydown", {key: "Enter", keyCode: 13, which: 13});
document.dispatchEvent(ev);
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 1.0


def test_hw_value64_class_field_arrow_is_own_property():
    """Class-field arrows are instance functions (addEventListener identity)."""
    vm = _hw_v64(
        """
var hit = 0;
class G {
  startSelect = (e) => {
    if (e.key === "Enter") hit = 1;
  }
}
var g = new G();
addEventListener("keydown", g.startSelect);
"""
    )
    assert vm.error is None, vm.error
    vm.input.key_event(13, "Enter", True)
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("hit") == 1.0


def test_hw_value64_iife_module_let_is_visible_to_class_method():
    """Top-level IIFE lets are globals; class methods LOAD_VAR them."""
    vm = _hw_v64(
        """
var P = (function(){
  let sheet = 7;
  class P {
    read() { return sheet; }
  }
  return P;
})();
var p = new P();
var v = p.read();
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("v") == 7.0


def test_hw_value64_console_log_rings():
    """console.log is a diagnostic ring; overflow must not abort."""
    vm = _hw_v64(
        "for (var i = 0; i < 300; i = i + 1) console.log(i);\nvar ok = 1;\n"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("ok") == 1.0
    assert len(vm.console_log) == 256
    assert vm.console_log[0] == (44.0,)
    assert vm.console_log[-1] == (299.0,)


def test_hw_value64_array_get_non_number_is_undefined():
    """arr[undefined] is undefined, not a machine halt."""
    vm = _hw_v64(
        """
var a = [1, 0, -1, 0];
var miss = a[undefined];
var ok = 1;
if (miss === undefined) ok = 2;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("ok") == 2.0


def test_hw_value64_clear_timeout_null_is_noop():
    """clearTimeout(null|undefined) is Web IDL long, not a Number-tag fault."""
    vm = _hw_v64(
        """
var n = 0;
function bump() { n = n + 1; }
clearTimeout(null);
clearTimeout(undefined);
clearTimeout();
var id = setTimeout(bump, 0);
"""
    )
    assert vm.error is None, vm.error
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("n") == 1.0


def test_hw_value64_class_field_keeps_constructor_params():
    """Field inits must not steal constructor_ip from param LET_VARs."""
    vm = _hw_v64(
        """
class G {
  startSelect = (e) => { this.armed = e; }
  constructor(width, height) {
    this.width = width;
    this.height = height;
  }
}
var g = new G(1510, 685);
var w = g.width;
var h = g.height;
var fn = g.startSelect;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("w") == 1510.0
    assert vm.globals.get("h") == 685.0
    from hardware_model.js_vm import VALUE_KIND_FUNCTION, value_kind

    fn = vm._value_vars[list(vm.program_image.var_names).index("fn")]
    assert value_kind(fn) == VALUE_KIND_FUNCTION


def test_hw_value64_present_keeps_draw_buffer():
    """HTML present copies BACK→FRONT so onload paints the same bitmap."""
    html = (
        "<html><body><canvas></canvas><script>\n"
        'var c = document.querySelector("canvas").getContext("2d");\n'
        "function tick() {\n"
        '  c.fillStyle = "#ffffff";\n'
        "  c.fillRect(0, 0, 8, 8);\n"
        "  var img = new Image();\n"
        "  img.onload = function() {\n"
        '    c.fillStyle = "#ff0000";\n'
        "    c.fillRect(20, 20, 8, 8);\n"
        "  };\n"
        '  img.src = "asset";\n'
        "}\n"
        "requestAnimationFrame(tick);\n"
        "</script></body></html>\n"
    )
    machine = Machine()
    machine.source_name = "PRESENT.HTML"
    out = machine._run_html_bytecode(html)
    assert "ERROR" not in out[0], out
    machine.frame_tick()
    assert machine._hw_vm is not None and machine._hw_vm.error is None, (
        machine._hw_vm.error if machine._hw_vm else out
    )
    w = machine.canvas.width
    assert machine.canvas.front[0] != 0
    assert machine.canvas.front[20 * w + 20] != 0


def test_hw_value64_p0_fillstyle_named_hex_rgb():
    """Canvas fillStyle named/hex/rgb strings must map to distinct paint."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillStyle = "red";
c.fillRect(0, 0, 2, 2);
c.fillStyle = "#ffffff";
c.fillRect(10, 0, 2, 2);
c.fillStyle = "rgb(0, 0, 255)";
c.fillRect(20, 0, 2, 2);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    red, white, blue = vm.canvas.front[0], vm.canvas.front[10], vm.canvas.front[20]
    assert red != 0 and white != 0 and blue != 0, (red, white, blue)
    assert len({red, white, blue}) == 3, (red, white, blue)


def test_hw_value64_p1_style_display_stub():
    """el.style.display none/block is a DOM property stub, not CSS layout."""
    vm = _hw_v64(
        """
var el = document.createElement("div");
el.style.display = "none";
var hidden = el.style.display;
el.style.display = "block";
var shown = el.style.display;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("hidden") == "none"
    assert vm.globals.get("shown") == "block"


def test_hw_value64_p0_clearrect():
    """clearRect must erase pixels previously painted by fillRect."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillRect(6, 6, 4, 4);
c.clearRect(6, 6, 4, 4);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    assert vm.canvas.front[6 * vm.canvas.width + 6] == 0


def test_hw_value64_p0_canvas_width_height():
    """canvas.width / height stay 640×480 glass, not a JS resize of HDMI."""
    vm = _hw_v64(
        """
var el = document.querySelector("canvas");
var w = el.width;
var h = el.height;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("w") == 640.0
    assert vm.globals.get("h") == 480.0


def test_hw_value64_p0_filltext():
    """fillText must paint HUD glyphs into the framebuffer."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillStyle = "white";
c.fillText("A", 16, 24);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    # fillText baseline is y; 8×8 glyph occupies y-8 .. y-1.
    row = 16 * vm.canvas.width
    assert any(vm.canvas.front[row + x] != 0 for x in range(16, 24))


def test_hw_value64_p1_measuretext_font_align():
    """measureText width follows font scale; textAlign/textBaseline are stored."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.font = "16px sans-serif";
c.textAlign = "center";
c.textBaseline = "top";
var w = c.measureText("AB").width;
var align = c.textAlign;
var base = c.textBaseline;
"""
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("w") == 32.0
    assert vm.globals.get("align") == "center"
    assert vm.globals.get("base") == "top"


def test_hw_value64_p1_path_stroke_line():
    """beginPath/moveTo/lineTo/stroke with strokeStyle must paint a line."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.strokeStyle = "#ffffff";
c.lineWidth = 2;
c.beginPath();
c.moveTo(30, 40);
c.lineTo(50, 40);
c.stroke();
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    assert vm.canvas.front[40 * vm.canvas.width + 40] != 0


def test_hw_value64_p1_arc_fill_and_quadratic():
    """arc + fill and quadraticCurveTo + stroke must occupy pixels."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillStyle = "white";
c.beginPath();
c.arc(80, 80, 10, 0, 6.283185, false);
c.fill();
c.strokeStyle = "white";
c.beginPath();
c.moveTo(100, 100);
c.quadraticCurveTo(120, 80, 140, 100);
c.stroke();
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    assert vm.canvas.front[80 * w + 80] != 0
    assert any(vm.canvas.front[90 * w + x] != 0 for x in range(100, 141))


def test_hw_value64_p1_settransform():
    """setTransform must map fillRect into device pixels (world→glass)."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.setTransform(1, 0, 0, 1, 50, 0);
c.fillRect(0, 2, 2, 2);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    assert vm.canvas.front[2 * w + 50] != 0
    assert vm.canvas.front[2 * w + 0] == 0


def test_hw_value64_p1_save_restore():
    """save/restore must pop transform so later fillRect uses the saved one."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.setTransform(1, 0, 0, 1, 60, 0);
c.save();
c.setTransform(1, 0, 0, 1, 0, 0);
c.restore();
c.fillRect(0, 3, 2, 2);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    assert vm.canvas.front[3 * w + 60] != 0
    assert vm.canvas.front[3 * w + 0] == 0


def test_hw_value64_p1_translate_rotate():
    """translate + rotate must move fillRect off the untransformed origin."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.translate(20, 20);
c.rotate(1.570796);
c.fillRect(0, 0, 8, 2);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    origin = vm.canvas.front[0]
    moved = any(
        vm.canvas.front[y * w + x] != 0
        for y in range(12, 29)
        for x in range(12, 29)
    )
    assert origin == 0
    assert moved


def test_hw_value64_p1_global_alpha():
    """globalAlpha 0 must skip a later fillRect (a no-op stub is not enough)."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillRect(0, 5, 4, 4);
c.globalAlpha = 0;
c.fillRect(20, 5, 4, 4);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    assert vm.canvas.front[5 * w + 0] != 0
    assert vm.canvas.front[5 * w + 20] == 0


def test_hw_value64_p1_get_put_imagedata():
    """getImageData snapshot + putImageData must copy pixels to a new origin."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
c.fillRect(1, 1, 2, 2);
var d = c.getImageData(1, 1, 2, 2);
c.putImageData(d, 12, 12);
swapBuffers();
"""
    )
    assert vm.error is None, vm.error
    w = vm.canvas.width
    assert vm.canvas.front[1 * w + 1] != 0
    assert vm.canvas.front[12 * w + 12] != 0


def test_hw_value64_p0_drawimage_3arg():
    """drawImage(img, x, y) must blit Image pixels after src/onload."""
    vm = _hw_v64(
        """
var c = document.querySelector("canvas").getContext("2d");
var img = new Image();
img.src = "asset";
img.onload = function() { c.drawImage(img, 7, 7); swapBuffers(); };
"""
    )
    assert vm.error is None, vm.error
    assert vm.canvas.front[7 * vm.canvas.width + 7] != 0


def test_hw_value64_p0_aset_data_image_html():
    """HTML data:image must land in ASET and drawImage from that bank."""
    from functional_model.jsb_format import FLAG_ASET
    from tools.compile_js import compile_html_text, encode_html_chunk

    png = (
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE"
        "hQGAhKmMIQAAAABJRU5ErkJggg=="
    )
    html = (
        '<html><body><canvas></canvas><script>\n'
        "var c = document.querySelector('canvas').getContext('2d');\n"
        "var img = new Image();\n"
        f'img.src = "data:image/png;base64,{png}";\n'
        "img.onload = function() { c.drawImage(img, 9, 9); swapBuffers(); };\n"
        "</script></body></html>"
    )
    blob = encode_html_chunk(compile_html_text(html))
    image = ProgramImage(blob)
    assert image.flags & FLAG_ASET
    vm = JsHwVm()
    vm.load_blob(blob)
    assert vm.error is None, vm.error
    assert vm.canvas.front[9 * vm.canvas.width + 9] != 0


def test_hw_value64_p1_joystick_bits():
    """Joystick / KEYBITS natives must see set_key_bits on the hardware model."""
    from functional_model.input_engine import KEY_LEFT

    vm = _hw_v64(
        """
var left = 0;
function tick() { if (keyLeft()) left = 1; }
requestAnimationFrame(tick);
"""
    )
    assert vm.error is None, vm.error
    vm.set_key_bits(KEY_LEFT)
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("left") == 1.0


def test_hw_value64_p0_keyup_key_and_keycode():
    """keyup listener must see e.key and e.keyCode from input.key_event release."""
    vm = _hw_v64(
        """
var seenKey = "";
var seenCode = 0;
addEventListener("keyup", function(e) {
  seenKey = e.key;
  seenCode = e.keyCode;
});
"""
    )
    assert vm.error is None, vm.error
    vm.input.key_event(13, "Enter", True)
    vm.frame_tick()
    vm.input.key_event(13, "Enter", False)
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("seenKey") == "Enter", vm.globals.get("seenKey")
    assert vm.globals.get("seenCode") == 13.0, vm.globals.get("seenCode")


def test_load_store_var_a1_global_and_local():
    """Compiler packs local LOAD/STORE a1>=2; provable globals get a1=1.

    Speed pass 2026-08-20: a site whose name is declared by NO enclosing
    function scope can only resolve to vvars, so the compiler retro-patches
    it to a1=1 (direct global, no env walk). `g` inside `f` qualifies.
    """
    from functional_model.bytecode import Op

    chunk = compile_source(
        "var g = 1;\n"
        "function f() {\n"
        "  var loc = 2;\n"
        "  g = loc;\n"
        "  return g;\n"
        "}\n"
        "var r = f();\n"
    )
    names = chunk.names
    loc_i = names.index("loc") if "loc" in names else -1
    g_i = names.index("g") if "g" in names else -1
    local_a1 = [
        op[2]
        for op in chunk.code
        if op[0] in (Op.LOAD_VAR, Op.STORE_VAR)
        and len(op) > 2
        and op[1] == loc_i
    ]
    global_packed = [
        op
        for op in chunk.code
        if op[0] in (Op.LOAD_VAR, Op.STORE_VAR)
        and len(op) > 2
        and op[1] == g_i
        and op[2] == 1
    ]
    assert any(a >= 2 for a in local_a1), (chunk.code, names)
    assert global_packed, (chunk.code, names)
    vm = _hw_v64(
        "var g = 1;\n"
        "function f() {\n"
        "  var loc = 2;\n"
        "  g = loc;\n"
        "  return g;\n"
        "}\n"
        "var r = f();\n"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("r") == 2.0


def test_hw_value64_finder_temps_reclaimed():
    """Nested coord literals must not pin the 1024-object heap after return."""
    src = (
        "function next() { return {x: 1, y: 2}; }\n"
        "function finder() {\n"
        "  var i = 0;\n"
        "  while (i < 2000) { next(); i = i + 1; }\n"
        "}\n"
        "finder();\n"
        "var live = 1;\n"
    )
    vm = _hw_v64(src)
    assert vm.error is None, vm.error
    nobj = sum(1 for slot in vm._value_objects if slot is not None)
    nfn = sum(1 for slot in vm._value_functions if slot is not None)
    assert nobj + nfn < 1024, (nobj, nfn)
    assert vm.globals.get("live") == 1.0


def test_hw_value64_stored_finder_paths_fit_object_heap():
    """BFS `{x,y}` stored in steps/path must compact so 1024 objects still fit."""
    src = (
        "var head = {n: 0};\n"
        "var cur = head;\n"
        "var i = 1;\n"
        "while (i < 700) {\n"
        "  var node = {n: i};\n"
        "  cur.next = node;\n"
        "  cur = node;\n"
        "  i = i + 1;\n"
        "}\n"
        "function finder() {\n"
        "  var steps = [];\n"
        "  var k = 0;\n"
        "  while (k < 120) {\n"
        "    var cell = {x: k, y: k};\n"
        "    steps.push(cell);\n"
        "    k = k + 1;\n"
        "  }\n"
        "  return steps;\n"
        "}\n"
        "var path = finder();\n"
        "path = finder();\n"
        "path = finder();\n"
        "path = finder();\n"
        "var live = path[0].x;\n"
    )
    vm = _hw_v64(src)
    assert vm.error is None, vm.error
    nobj = sum(1 for slot in vm._value_objects if slot is not None)
    assert nobj <= 1024, nobj
    assert vm.globals.get("live") == 0.0


def test_hw_value64_foreach_compact_does_not_stale():
    """forEach must re-read live `{x,y}` after GC compact (not a handle snapshot)."""
    src = (
        "var head = {n: 0};\n"
        "var cur = head;\n"
        "var i = 1;\n"
        "while (i < 980) {\n"
        "  var node = {n: i};\n"
        "  cur.next = node;\n"
        "  cur = node;\n"
        "  i = i + 1;\n"
        "}\n"
        "var cells = [];\n"
        "var k = 0;\n"
        "while (k < 40) { cells.push({x: k, y: k}); k = k + 1; }\n"
        "var acc = 0;\n"
        "cells.forEach(function(current) {\n"
        "  var tmp = {x: current.x, y: current.y};\n"
        "  acc = acc + current.y;\n"
        "});\n"
        "var live = acc;\n"
    )
    vm = _hw_v64(src)
    assert vm.error is None, vm.error
    nobj = sum(1 for slot in vm._value_objects if slot is not None)
    assert nobj <= 1024, nobj
    assert vm.globals.get("live") == 39.0 * 40.0 / 2.0


def test_canvas_fill_rect_row_slice():
    """fill_rect writes clipped row slices, not a per-pixel Python loop."""
    from functional_model.canvas_engine import CanvasEngine

    c = CanvasEngine()
    c.fill_style = 5
    c.fill_rect(10, 20, 8, 3)
    w = c.width
    for y in range(20, 23):
        row = c.back[y * w + 10 : y * w + 18]
        assert bytes(row) == bytes([5] * 8)
    assert c.back[19 * w + 10] != 5
    assert c.back[20 * w + 9] != 5


def test_hw_value64_palk_global_fillstyle_loop():
    """palK-like: global PAL/c load + fillStyle + tiny fillRect stays correct."""
    src = (
        "var PAL = [0, 1, 2, 3];\n"
        "var c = document.querySelector('canvas').getContext('2d');\n"
        "function palK(k) {\n"
        "  c.fillStyle = PAL[k];\n"
        "  c.fillRect(0, 0, 2, 2);\n"
        "}\n"
        "palK(1);\n"
        "swapBuffers();\n"
    )
    vm = _hw_v64(src)
    assert vm.error is None, vm.error
    assert vm.canvas.front[0] != 0


def test_hw_value64_keydown_letter_w():
    """DONKEY WASD: e.key === 'w' then one fillRect (potential bugs.md 15)."""
    html = (
        '<!DOCTYPE html><canvas id="c" width="640" height="480"></canvas>\n'
        "<script>\n"
        'var c = document.getElementById("c").getContext("2d");\n'
        'addEventListener("keydown", function(e) {\n'
        '  if (e.key === "w") {\n'
        '    c.fillStyle = "#fff";\n'
        "    c.fillRect(10, 10, 4, 4);\n"
        "  }\n"
        "});\n"
        "function tick() { requestAnimationFrame(tick); }\n"
        "requestAnimationFrame(tick);\n"
        "</script>\n"
    )
    vm = _hw_html(html)
    assert vm.error is None, vm.error
    vm.input.key_event(87, "w", True)
    vm.frame_tick()
    assert vm.error is None, vm.error
    w = vm.canvas.width
    # Present is a frame-end swap; this test checks the back the VM painted.
    assert vm.canvas.back[11 * w + 11] != 0, "e.key === 'w' did not paint"


def test_hw_value64_foreach_then_raf_paints():
    """forEach (no return) then rAF still paints (potential bugs.md 6)."""
    vm = _hw_html(
        "<!DOCTYPE html><canvas id=\"c\" width=\"640\" height=\"480\"></canvas>\n"
        "<script>\n"
        "var c = document.getElementById('c').getContext('2d');\n"
        "c.fillStyle = '#fff';\n"
        "[1, 2].forEach(function(x) { c.fillRect(10 * x, 10, 4, 4); });\n"
        "function tick() {\n"
        "  c.fillRect(100, 10, 4, 4);\n"
        "  requestAnimationFrame(tick);\n"
        "}\n"
        "requestAnimationFrame(tick);\n"
        "</script>\n"
    )
    assert vm.error is None, vm.error
    vm.frame_tick()
    assert vm.error is None, vm.error
    w = vm.canvas.width
    # Present is a frame-end swap; this test checks the back the VM painted.
    back = vm.canvas.back
    assert back[10 * w + 11] != 0 or back[10 * w + 21] != 0, "forEach did not paint"
    assert back[10 * w + 101] != 0, "rAF after forEach did not paint"


def test_hw_value64_date_now_advances_on_frame():
    """Date.now after a rAF frame must move (potential bugs.md 14)."""
    vm = _hw_v64(
        "var t0 = Date.now();\n"
        "var t1 = 0;\n"
        "function tick() { t1 = Date.now(); requestAnimationFrame(tick); }\n"
        "requestAnimationFrame(tick);\n"
    )
    assert vm.error is None, vm.error
    assert vm.globals.get("t0") == 0.0
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert vm.globals.get("t1") != 0.0, vm.globals.get("t1")


def test_mrdo_hm_enter_paints_without_hang():
    """MRDO PYTHON bytecode: Enter starts; a couple of paints finish."""
    import time
    from pathlib import Path

    mrdo = Path(__file__).resolve().parents[1] / "storage" / "MRDO.HTML"
    if not mrdo.is_file():
        pytest.skip("MRDO.HTML missing")
    machine = Machine()
    machine.source_name = "MRDO.HTML"
    t0 = time.perf_counter()
    out = machine._run_html_bytecode(mrdo.read_text(encoding="utf-8"))
    hw = machine._hw_vm
    assert hw is not None, out
    assert hw.error is None, hw.error
    assert "ERROR" not in out[0]
    machine.input.key_event(13, "Enter", True)
    machine.frame_tick()
    machine.input.key_event(13, "Enter", False)
    t1 = time.perf_counter()
    for _ in range(2):
        machine.frame_tick()
        assert hw.error is None, hw.error
    elapsed = time.perf_counter() - t1
    assert hw.checkpoint()["raf"] >= 1
    # Was ~1 fps (1s+/frame). Row-slice blit + a1 globals should be well under that.
    assert elapsed < 8.0, elapsed
    assert (time.perf_counter() - t0) < 30.0



def test_encode_chunk_tagged_request_raises():
    """The tagged (non-Value64) encoding is retired with exec32: loud refusal.

    This is the ONE place value64=False may appear in-tree
    (docs/REMOVING_EXEC32.md Phase 1).
    """
    import pytest as _pytest

    from functional_model.compiler import compile_source
    from functional_model.jsb_format import ProgramImage, encode_chunk

    chunk = compile_source("var x = 1;")
    with _pytest.raises(ValueError, match="FLAG_VALUE64"):
        encode_chunk(chunk, value64=False)
    with _pytest.raises(ValueError, match="FLAG_VALUE64"):
        ProgramImage.from_chunk(chunk, value64=False)
