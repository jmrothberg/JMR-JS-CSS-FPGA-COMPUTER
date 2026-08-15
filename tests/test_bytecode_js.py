"""Generic JS VM tests: closures, String.replace(RegExp), not title-specific."""

import struct

import pytest

from functional_model.compiler import compile_source
from functional_model.jsb_format import (
    FLAG_SOURCE_MAP,
    MAGIC,
    ProgramImage,
    encode_chunk,
)
from functional_model.machine import Machine
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


def test_wall_box_neighbor_codes_are_arcs():
    """2x2 wall cells: NESW neighbor bits → join → quarter-arcs, not + spokes."""
    m = _run_js_frames(
        """
var c = document.getElementById('c').getContext('2d');
c.strokeStyle = '#09f';
c.lineWidth = 2;
var map = [[1, 1], [1, 1]];
var size = 20;
function get(i, j) {
  if (j < 0 || i < 0 || j >= 2 || i >= 2) return 0;
  return map[j][i];
}
function pos(i, j) {
  return {x: 100 + i * size, y: 100 + j * size};
}
var j, i;
function draw() {
for (j = 0; j < 2; j++) {
  for (i = 0; i < 2; i++) {
    var code = [0, 0, 0, 0];
    if (get(i + 1, j) && !(get(i + 1, j - 1) && get(i + 1, j + 1) && get(i, j - 1) && get(i, j + 1))) code[0] = 1;
    if (get(i, j + 1) && !(get(i - 1, j + 1) && get(i + 1, j + 1) && get(i - 1, j) && get(i + 1, j))) code[1] = 1;
    if (get(i - 1, j) && !(get(i - 1, j - 1) && get(i - 1, j + 1) && get(i, j - 1) && get(i, j + 1))) code[2] = 1;
    if (get(i, j - 1) && !(get(i - 1, j - 1) && get(i + 1, j - 1) && get(i - 1, j) && get(i + 1, j))) code[3] = 1;
    var p = pos(i, j);
    switch (code.join('')) {
      case '1100':
        c.beginPath();
        c.arc(p.x + size / 2, p.y + size / 2, size / 2, 3.14159265, 4.71238898, false);
        c.stroke();
        break;
      case '0110':
        c.beginPath();
        c.arc(p.x - size / 2, p.y + size / 2, size / 2, 4.71238898, 6.2831853, false);
        c.stroke();
        break;
      case '0011':
        c.beginPath();
        c.arc(p.x - size / 2, p.y - size / 2, size / 2, 0, 1.5707963, false);
        c.stroke();
        break;
      case '1001':
        c.beginPath();
        c.arc(p.x + size / 2, p.y - size / 2, size / 2, 1.5707963, 3.14159265, false);
        c.stroke();
        break;
      default:
        c.beginPath();
        c.moveTo(p.x, p.y);
        c.lineTo(p.x + 10, p.y);
        c.stroke();
    }
  }
}
}
draw();
""",
        n_frames=1,
    )
    fb = m.canvas.front
    w = 640
    assert fb[100 * w + 100] == 0, "spoke through (0,0) center"
    assert fb[100 * w + 120] == 0, "spoke through (1,0) center"
    assert fb[120 * w + 100] == 0, "spoke through (0,1) center"
    assert fb[120 * w + 120] == 0, "spoke through (1,1) center"
    assert fb[110 * w + 100] != 0, "1100 quarter-arc missing"


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


def test_hw_vm_queue_capacity_fails_loudly():
    src = "function f() {}\n" + "\n".join(
        "setTimeout(f, 1000);" for _ in range(9)
    )
    image = ProgramImage.from_chunk(compile_source(src), v2=True)

    vm = JsHwVm()
    vm.load_image(image)

    assert vm.error == "ERROR: HM CAPACITY: timer queue overflow (8 timers)"

