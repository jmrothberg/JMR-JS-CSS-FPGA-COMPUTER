"""Minimal JMR-JS bytecode + interpreter (stack machine).

LLM NOTE: Encoding not frozen — grow only for demos / compatibility matrix.
Opcodes are multi-cycle in spirit; FM runs them immediately.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Callable, Dict, List, Optional, Tuple


def _png_size_from_data_uri(src: str) -> Tuple[int, int]:
    """NEW: read IHDR width/height from data:image/png;base64,… (Image.onload path)."""
    try:
        if not isinstance(src, str) or "base64," not in src:
            return (36, 28)  # classic SI ship fallback
        import base64
        import struct

        b64 = src.split("base64,", 1)[1]
        data = base64.b64decode(b64[:256])  # IHDR is at start
        # PNG signature 8 + IHDR len 4 + type 4 + width/height
        if len(data) >= 24 and data[:4] == b"\x89PNG":
            w, h = struct.unpack(">II", data[16:24])
            if 1 <= w <= 4096 and 1 <= h <= 4096:
                return (int(w), int(h))
    except Exception:
        pass
    return (36, 28)


class Op(IntEnum):
    LOAD_CONST = 1
    LOAD_VAR = 2
    STORE_VAR = 3
    LET_VAR = 22  # init only if name missing — safe under startLoop re-entry
    ADD = 4
    SUB = 5
    MUL = 6
    DIV = 7
    LT = 8
    GT = 9
    EQ = 10
    JUMP = 11
    JUMP_IF_FALSE = 12
    CALL_NATIVE = 13
    RETURN = 14
    POP = 15
    DUP = 16
    NEG = 17
    NOT = 18
    MAKE_ARRAY = 19
    ARRAY_GET = 20
    ARRAY_SET = 21
    # NEW (compiler v2): real modulo — % used to silently emit DIV
    MOD = 23
    # NEW (compiler v2): user functions (frame = return IP on call_stack)
    CALL_USER = 24
    RET_VAL = 25
    # NEW (compiler v2): fixed-slot objects (Python dict; RTL heap later)
    MAKE_OBJ = 26
    GET_PROP = 27  # arg0 = name index
    SET_PROP = 28  # arg0 = name index
    NEW_OBJ = 29  # arg0 = class name index, arg1 = argc
    # NEW (compiler v2): class methods OR array/string builtins
    CALL_METHOD = 30
    # NEW: bitwise (INVADERS uses `type | 0`)
    BIT_OR = 31
    BIT_AND = 32
    # NEW: first-class function value (arrows / .sort callbacks)
    MAKE_FN = 33  # arg0=entry_ip, arg1=param_count
    # NEW: call Fn value on stack (IIFE / expr()) — PACMAN polyfill
    CALL_VAL = 34  # arg0 = argc; stack [fn, arg0..argN-1]


@dataclass
class Chunk:
    code: List[Tuple]  # (op, *args)
    consts: List[Any]
    names: List[str]
    # NEW: name → (entry_ip, param_names) for CALL_USER
    functions: Optional[Dict[str, Tuple[int, List[str]]]] = None
    # NEW: class_name → {"ctor": entry|None, "methods": {meth: entry}}
    classes: Optional[Dict[str, dict]] = None
    # NEW: card-build sprite pack (w, h, indexed pixels) for drawImage
    sprites: Optional[List[Tuple[int, int, bytes]]] = None
    # NEW (external SRAM asset bank): per-title 256-entry RGB888 palette.
    # Entries 0..7 stay the legacy fixed 8; 8..255 = harvested + adaptive.
    palette: Optional[List[Tuple[int, int, int]]] = None
    # NEW: HTML/JS source line per opcode (Architecture Monitor observer)
    op_lines: Optional[List[int]] = None


class VM:
    """Tiny stack VM with native hooks for console / canvas / joy."""

    def __init__(
        self,
        natives: Optional[Dict[str, Callable[..., Any]]] = None,
    ) -> None:
        self.natives = natives or {}
        self.globals: Dict[str, Any] = {}
        self.stack: List[Any] = []
        # NEW: (return_ip, saved__this, ctor_obj_or_None, saved_env)
        self.call_stack: List[Tuple[int, Any, Any, Any]] = []
        # NEW: lexical environment — dict of locals with "__par" parent link.
        # None at top level (globals). PACMAN builds 12 game stages inside
        # _COIGIG.forEach(function(config){var stage,map,player;...}); a flat
        # namespace left every closure pointing at the LAST level's player.
        self.env: Optional[dict] = None
        self.halted = False
        self.error: Optional[str] = None
        # NEW: deterministic frame clock (ms). The machine sets this every
        # frame so Date.now/getTime pace games by VM frames, not host wall
        # time (PACMAN's `now-timestamp<16` limiter skipped every draw when
        # the FM ticked faster than real time). None → wall clock fallback.
        self.time_ms: Optional[float] = None
        # NEW: last opcode the loop actually executed (Architecture Monitor)
        self.last_ip: int = 0
        self.last_op: Optional[Op] = None
        self.last_arg0: Any = None

    def _now_ms(self) -> int:
        if self.time_ms is not None:
            return int(self.time_ms)
        import time as _time

        return int(_time.time() * 1000)

    def reset_run(self) -> None:
        self.stack.clear()
        self.call_stack.clear()
        self.halted = False
        self.error = None
        self.env = None

    def run(self, chunk: Chunk, max_steps: int = 1_000_000) -> None:
        # NEW: shared opcode loop lives in _exec (also used by call_fn)
        self._exec(chunk, start_ip=0, max_steps=max_steps, reset=True)

    def call_fn(self, chunk: Chunk, fn: dict, argv: Optional[List[Any]] = None, max_steps: int = 500_000) -> Any:
        """NEW: invoke a MAKE_FN value (rAF / setTimeout / listeners).

        Reuses the main opcode loop via a sentinel call frame (ip=-1) so
        Element.click / array builtins / GET_PROP stay in sync with run().
        """
        if not isinstance(fn, dict) or fn.get("__class") != "Fn":
            return None
        # NEW: Element.click property stub → fire click listeners
        if fn.get("builtin") == "el_click":
            click_fn = self.natives.get("__fire_click")
            if click_fn:
                click_fn()
            return None
        entry = int(fn["entry"])
        if entry < 0:
            return None
        # NEW: bind exactly nparam args (JS semantics) — the prologue pops
        # one value per declared param, so extra args (forEach idx) must be
        # trimmed and missing ones padded with undefined.
        args_in = list(argv or [])
        nparam = fn.get("nparam")
        if nparam is not None:
            n = int(nparam)
            args_in = args_in[:n] + [None] * max(0, n - len(args_in))
        for a in args_in:
            self.stack.append(a)
        # NEW: fresh lexical env chained to the Fn's captured scope
        saved_env = self.env
        self.call_stack.append((-1, self.globals.get("__this"), None, saved_env))
        self.env = {"__par": fn.get("env")}
        if fn.get("bound_this") is not None:
            self.globals["__this"] = fn["bound_this"]
        # Run from entry without clearing stack/globals (nested from rAF / click)
        saved_halted = self.halted
        self.halted = False
        self._exec(chunk, start_ip=entry, max_steps=max_steps, reset=False)
        # Nested error should surface; don't leave halted stuck for outer frame_tick
        if not self.error:
            self.halted = saved_halted
        # NEW: restore caller env even if the callee errored mid-frame
        self.env = saved_env
        return self.stack.pop() if self.stack else None

    def _exec(self, chunk: Chunk, start_ip: int = 0, max_steps: int = 1_000_000, reset: bool = True) -> None:
        """Shared opcode loop for run() and call_fn() (reentrant via local ip)."""
        if reset:
            self.reset_run()
        ip = start_ip
        code = chunk.code
        steps = 0
        while not self.halted and steps < max_steps:
            steps += 1
            # NEW: call_fn sentinel return_ip=-1 ends nested invoke
            if ip < 0:
                return
            if ip >= len(code):
                return
            op, *args = code[ip]
            self.last_ip = ip
            self.last_op = op
            self.last_arg0 = args[0] if args else None
            ip += 1
            if op == Op.LOAD_CONST:
                self.stack.append(chunk.consts[args[0]])
            elif op == Op.LOAD_VAR:
                name = chunk.names[args[0]]
                # NEW: lexical env chain first, then globals
                e = self.env
                while e is not None:
                    if name in e:
                        self.stack.append(e[name])
                        break
                    e = e.get("__par")
                else:
                    self.stack.append(self.globals.get(name))
            elif op == Op.STORE_VAR:
                name = chunk.names[args[0]]
                # NEW: tolerate empty stack (partial expr compile) — undefined
                val = self.stack.pop() if self.stack else None
                # NEW: assign in the declaring scope; undeclared → global (JS)
                e = self.env
                while e is not None:
                    if name in e:
                        e[name] = val
                        break
                    e = e.get("__par")
                else:
                    self.globals[name] = val
            elif op == Op.LET_VAR:
                # LLM NOTE: let/const under startLoop — do not reset each frame
                # at TOP LEVEL. Inside a function call env, declare/assign in
                # the CURRENT env (fresh per call, so `let x = 0` re-inits).
                name = chunk.names[args[0]]
                val = self.stack.pop() if self.stack else None
                if self.env is not None:
                    self.env[name] = val
                elif name not in self.globals:
                    self.globals[name] = val
            elif op == Op.ADD:
                b, a = self.stack.pop(), self.stack.pop()
                # NEW: JS-ish concat when either side is string (templates)
                if isinstance(a, str) or isinstance(b, str):
                    self.stack.append(str(a) + str(b))
                else:
                    if a is None:
                        a = 0
                    if b is None:
                        b = 0
                    self.stack.append(a + b)
            elif op == Op.SUB:
                b, a = self.stack.pop(), self.stack.pop()
                if a is None:
                    a = 0
                if b is None:
                    b = 0
                self.stack.append(a - b)
            elif op == Op.MUL:
                b, a = self.stack.pop(), self.stack.pop()
                if a is None:
                    a = 0
                if b is None:
                    b = 0
                self.stack.append(a * b)
            elif op == Op.DIV:
                b, a = self.stack.pop(), self.stack.pop()
                if a is None:
                    a = 0
                if b is None:
                    b = 0
                self.stack.append(a / b if b else 0)
            elif op == Op.MOD:
                # NEW: real % (was silently DIV in the compiler)
                b, a = self.stack.pop(), self.stack.pop()
                if a is None:
                    a = 0
                if b is None:
                    b = 0
                if not b:
                    self.stack.append(0)
                else:
                    self.stack.append(a % b)
            elif op == Op.LT:
                b, a = self.stack.pop(), self.stack.pop()
                # NEW: coerce None→0 like ADD/SUB do. `>=` compiles to NOT LT,
                # so "None compares False" inverted into True there (DONKEY
                # `!(this.jumpHeight >= 750)` broke platform collision).
                a = 0 if a is None else a
                b = 0 if b is None else b
                self.stack.append(a < b)
            elif op == Op.GT:
                b, a = self.stack.pop(), self.stack.pop()
                a = 0 if a is None else a
                b = 0 if b is None else b
                self.stack.append(a > b)
            elif op == Op.EQ:
                b, a = self.stack.pop(), self.stack.pop()
                # NEW: JS === is identity for objects/arrays (find(x => x === obj)).
                # Python dict/list == is deep equality and would match the wrong item.
                if isinstance(a, (dict, list)) or isinstance(b, (dict, list)):
                    self.stack.append(a is b)
                elif isinstance(a, str) or isinstance(b, str):
                    # NEW: join() may yield a Python str while case '1100' is
                    # interned; compare string values so maze switch hits arcs.
                    self.stack.append(str(a) == str(b))
                else:
                    self.stack.append(a == b)
            elif op == Op.BIT_OR:
                b, a = self.stack.pop(), self.stack.pop()
                # NEW: coerce None/bool like JS ToInt32-ish for `type | 0`
                self.stack.append(int(a or 0) | int(b or 0))
            elif op == Op.BIT_AND:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(int(a or 0) & int(b or 0))
            elif op == Op.JUMP:
                ip = args[0]
            elif op == Op.JUMP_IF_FALSE:
                cond = self.stack.pop()
                if not cond:
                    ip = args[0]
            elif op == Op.CALL_NATIVE:
                name = chunk.names[args[0]]
                argc = args[1]
                argv = [self.stack.pop() for _ in range(argc)][::-1]
                fn = self.natives.get(name)
                if fn is None:
                    # NEW: forward-declared user fn — call site compiled before
                    # `function update(){}` existed (DONKEY startGame → update()).
                    fmeta = (chunk.functions or {}).get(name)
                    if fmeta is not None:
                        self.call_stack.append(
                            (ip, self.globals.get("__this"), None, self.env)
                        )
                        # direct decl call: chain to caller env (flat-compatible)
                        self.env = {"__par": self.env}
                        for a in argv:
                            self.stack.append(a)
                        ip = int(fmeta[0])
                        continue
                    # NEW: env/global holds a first-class Fn value (var f = () => ...)
                    gfn = None
                    e = self.env
                    while e is not None:
                        if name in e:
                            gfn = e[name]
                            break
                        e = e.get("__par")
                    else:
                        gfn = self.globals.get(name)
                    if isinstance(gfn, dict) and gfn.get("__class") == "Fn":
                        self.call_stack.append(
                            (ip, self.globals.get("__this"), None, self.env)
                        )
                        self.env = {"__par": gfn.get("env")}
                        if gfn.get("bound_this") is not None:
                            self.globals["__this"] = gfn["bound_this"]
                        for a in argv:
                            self.stack.append(a)
                        ip = int(gfn["entry"])
                        continue
                    have = ",".join(sorted(self.natives)) or "(none)"
                    self.error = f"ERROR: UNKNOWN NATIVE {name} (have: {have})"
                    self.halted = True
                    return
                result = fn(*argv)
                # NEW: always push (None = JS undefined) so JSON.parse(getItem()) works
                self.stack.append(result)
            elif op == Op.CALL_USER:
                entry = int(args[0])
                self.call_stack.append(
                    (ip, self.globals.get("__this"), None, self.env)
                )
                # direct decl call: chain to caller env (flat-compatible)
                self.env = {"__par": self.env}
                ip = entry
            elif op == Op.CALL_VAL:
                # NEW: call Fn on stack — (function(){...}()) IIFE
                argc = int(args[0])
                argv = [self.stack.pop() for _ in range(argc)][::-1]
                fn = self.stack.pop()
                if isinstance(fn, dict) and fn.get("__class") == "Fn":
                    self.call_stack.append(
                        (ip, self.globals.get("__this"), None, self.env)
                    )
                    # NEW: top-level IIFE runs FLAT (no env) — module locals
                    # stay global so class methods see their sprite sheets;
                    # nested closures still get a per-call env.
                    if not (fn.get("iife") and self.env is None and fn.get("env") is None):
                        self.env = {"__par": fn.get("env")}
                    # NEW: honor captured `this` on the Fn value (arrows/bind)
                    if fn.get("bound_this") is not None:
                        self.globals["__this"] = fn["bound_this"]
                    for a in argv:
                        self.stack.append(a)
                    ip = int(fn["entry"])
                else:
                    self.stack.append(None)
            elif op == Op.CALL_METHOD:
                # NEW: stack [obj, arg0..argN-1]; class methods OR array/string builtins
                meth = chunk.names[args[0]]
                argc = int(args[1])
                argv = [self.stack.pop() for _ in range(argc)][::-1]
                obj = self.stack.pop()
                # Builtins first (arrays / strings) — HTML titles use these heavily
                if isinstance(obj, list):
                    if meth == "push":
                        for a in argv:
                            obj.append(a)
                        self.stack.append(len(obj))
                        continue
                    if meth == "pop":
                        self.stack.append(obj.pop() if obj else None)
                        continue
                    if meth == "splice":
                        # splice(start, deleteCount, ...items) — minimal
                        start = int(argv[0]) if argv else 0
                        count = int(argv[1]) if len(argv) > 1 else len(obj)
                        items = argv[2:]
                        deleted = obj[start : start + count]
                        obj[start : start + count] = items
                        self.stack.append(deleted)
                        continue
                    if meth == "slice":
                        a = int(argv[0]) if argv else 0
                        b = int(argv[1]) if len(argv) > 1 else len(obj)
                        self.stack.append(obj[a:b])
                        continue
                    if meth == "indexOf":
                        self.stack.append(obj.index(argv[0]) if argv and argv[0] in obj else -1)
                        continue
                    if meth == "sort":
                        # NEW: sort([cmpFn]) — cmpFn is MAKE_FN dict
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            fn = argv[0]
                            entry = int(fn["entry"])
                            nparam = int(fn.get("nparam", 2))

                            def _cmp(a, b, _entry=entry, _np=nparam, _fenv=fn.get("env")):
                                # re-entrant mini-run of comparator
                                saved = (
                                    self.stack[:],
                                    self.call_stack[:],
                                    self.globals.get("__this"),
                                    ip,
                                    self.env,
                                )
                                self.stack.append(a)
                                self.stack.append(b)
                                # bind params like CALL_USER prologue expects args on stack
                                self.call_stack.append(
                                    (-1, self.globals.get("__this"), None, self.env)
                                )
                                # NEW: comparator params LET_VAR into a fresh env
                                self.env = {"__par": _fenv}
                                rip = _entry
                                # run until RET_VAL to our mark
                                steps2 = 0
                                while steps2 < 100000:
                                    steps2 += 1
                                    if rip < 0 or rip >= len(code):
                                        break
                                    op2, *args2 = code[rip]
                                    rip += 1
                                    if op2 == Op.RET_VAL:
                                        if self.call_stack and self.call_stack[-1][0] == -1:
                                            self.call_stack.pop()
                                            break
                                        # nested return
                                        if not self.call_stack:
                                            break
                                        rip, saved_this, ctor_obj, saved_env2 = (
                                            self.call_stack.pop()
                                        )
                                        self.globals["__this"] = saved_this
                                        self.env = saved_env2
                                        if ctor_obj is not None:
                                            if self.stack:
                                                self.stack.pop()
                                            self.stack.append(ctor_obj)
                                        continue
                                    if op2 == Op.LOAD_CONST:
                                        self.stack.append(chunk.consts[args2[0]])
                                    elif op2 == Op.LOAD_VAR:
                                        _n2 = chunk.names[args2[0]]
                                        _e2 = self.env
                                        while _e2 is not None:
                                            if _n2 in _e2:
                                                self.stack.append(_e2[_n2])
                                                break
                                            _e2 = _e2.get("__par")
                                        else:
                                            self.stack.append(self.globals.get(_n2))
                                    elif op2 == Op.STORE_VAR:
                                        _n2 = chunk.names[args2[0]]
                                        _v2 = self.stack.pop()
                                        _e2 = self.env
                                        while _e2 is not None:
                                            if _n2 in _e2:
                                                _e2[_n2] = _v2
                                                break
                                            _e2 = _e2.get("__par")
                                        else:
                                            self.globals[_n2] = _v2
                                    elif op2 == Op.LET_VAR:
                                        _n2 = chunk.names[args2[0]]
                                        _v2 = self.stack.pop()
                                        if self.env is not None:
                                            self.env[_n2] = _v2
                                        elif _n2 not in self.globals:
                                            self.globals[_n2] = _v2
                                    elif op2 == Op.GET_PROP:
                                        name = chunk.names[args2[0]]
                                        o = self.stack.pop()
                                        if isinstance(o, dict):
                                            self.stack.append(o.get(name))
                                        elif name == "length" and isinstance(o, (list, str)):
                                            self.stack.append(len(o))
                                        else:
                                            self.stack.append(None)
                                    elif op2 == Op.SUB:
                                        bb, aa = self.stack.pop(), self.stack.pop()
                                        self.stack.append(aa - bb)
                                    elif op2 == Op.ADD:
                                        bb, aa = self.stack.pop(), self.stack.pop()
                                        self.stack.append(aa + bb)
                                    elif op2 == Op.MUL:
                                        bb, aa = self.stack.pop(), self.stack.pop()
                                        self.stack.append(aa * bb)
                                    elif op2 == Op.LT:
                                        bb, aa = self.stack.pop(), self.stack.pop()
                                        self.stack.append(aa < bb)
                                    elif op2 == Op.GT:
                                        bb, aa = self.stack.pop(), self.stack.pop()
                                        self.stack.append(aa > bb)
                                    elif op2 == Op.JUMP:
                                        rip = args2[0]
                                    elif op2 == Op.JUMP_IF_FALSE:
                                        if not self.stack.pop():
                                            rip = args2[0]
                                    else:
                                        # unsupported in comparator — treat as 0
                                        break
                                result = self.stack.pop() if self.stack else 0
                                self.stack[:] = saved[0]
                                self.call_stack[:] = saved[1]
                                self.globals["__this"] = saved[2]
                                self.env = saved[4]
                                return int(result) if result is not None else 0

                            from functools import cmp_to_key

                            obj.sort(key=cmp_to_key(_cmp))
                        else:
                            obj.sort()
                        self.stack.append(obj)
                        continue
                    if meth == "forEach":
                        # NEW: forEach(fn) — call fn(el, idx) for HTML animate loops
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            fn = argv[0]
                            for idx, el in enumerate(list(obj)):
                                self.call_fn(chunk, fn, [el, idx])
                                if self.error:
                                    return
                        self.stack.append(None)
                        continue
                    if meth == "reduce":
                        # NEW: reduce(fn, init) — INVADERS checkVictory
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            fn = argv[0]
                            acc = argv[1] if len(argv) > 1 else (obj[0] if obj else None)
                            start = 0 if len(argv) > 1 else 1
                            for idx in range(start, len(obj)):
                                acc = self.call_fn(chunk, fn, [acc, obj[idx], idx])
                                if self.error:
                                    return
                            self.stack.append(acc)
                        else:
                            self.stack.append(None)
                        continue
                    # NEW (full-game builtins): fill/map/filter/join/… (PACMAN)
                    if meth == "fill":
                        v = argv[0] if argv else None
                        for i in range(len(obj)):
                            obj[i] = v
                        self.stack.append(obj)
                        continue
                    if meth == "map":
                        out = []
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            for idx, el in enumerate(list(obj)):
                                out.append(self.call_fn(chunk, argv[0], [el, idx]))
                                if self.error:
                                    return
                        self.stack.append(out)
                        continue
                    if meth == "filter":
                        out = []
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            for idx, el in enumerate(list(obj)):
                                keep = self.call_fn(chunk, argv[0], [el, idx])
                                if self.error:
                                    return
                                if keep:
                                    out.append(el)
                        self.stack.append(out)
                        continue
                    if meth == "find" or meth == "findIndex":
                        hit, hidx = None, -1
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            for idx, el in enumerate(list(obj)):
                                ok = self.call_fn(chunk, argv[0], [el, idx])
                                if self.error:
                                    return
                                if ok:
                                    hit, hidx = el, idx
                                    break
                        self.stack.append(hit if meth == "find" else hidx)
                        continue
                    if meth == "some" or meth == "every":
                        res = meth == "every"
                        if argv and isinstance(argv[0], dict) and argv[0].get("__class") == "Fn":
                            for idx, el in enumerate(list(obj)):
                                ok = self.call_fn(chunk, argv[0], [el, idx])
                                if self.error:
                                    return
                                if meth == "some" and ok:
                                    res = True
                                    break
                                if meth == "every" and not ok:
                                    res = False
                                    break
                        self.stack.append(res)
                        continue
                    if meth == "join":
                        sep = str(argv[0]) if argv and argv[0] is not None else ","
                        # NEW: JS ToString for numbers so 1+1+0+0 → '1100'
                        # not '1.0' (float elems would miss every switch case).
                        def _js_str(e):
                            if e is None:
                                return ""
                            if isinstance(e, float) and e == int(e):
                                return str(int(e))
                            return str(e)

                        self.stack.append(sep.join(_js_str(e) for e in obj))
                        continue
                    if meth == "concat":
                        out = list(obj)
                        for a in argv:
                            if isinstance(a, list):
                                out.extend(a)
                            else:
                                out.append(a)
                        self.stack.append(out)
                        continue
                    if meth == "includes":
                        self.stack.append(bool(argv) and argv[0] in obj)
                        continue
                    if meth == "shift":
                        self.stack.append(obj.pop(0) if obj else None)
                        continue
                    if meth == "unshift":
                        for a in reversed(argv):
                            obj.insert(0, a)
                        self.stack.append(len(obj))
                        continue
                    if meth == "reverse":
                        obj.reverse()
                        self.stack.append(obj)
                        continue
                if isinstance(obj, str):
                    if meth == "trim":
                        self.stack.append(obj.strip())
                        continue
                    # NEW (full-game builtins): string methods (PACMAN maze keys)
                    if meth == "replace":
                        # NEW: string pattern = first only; RegExp stub honors
                        # source+flags (`g` → all). Any HTML, not one title.
                        if len(argv) >= 2 and isinstance(argv[0], str):
                            self.stack.append(obj.replace(argv[0], str(argv[1]), 1))
                        elif (
                            len(argv) >= 2
                            and isinstance(argv[0], dict)
                            and argv[0].get("__class") == "RegExp"
                        ):
                            import re as _re

                            raw = str(argv[0].get("source") or "")
                            pat, fl = raw, ""
                            if raw.startswith("/"):
                                end = raw.rfind("/")
                                if end > 0:
                                    pat, fl = raw[1:end], raw[end + 1 :]
                            flags = 0
                            if "i" in fl:
                                flags |= _re.I
                            if "m" in fl:
                                flags |= _re.M
                            if "s" in fl:
                                flags |= _re.S
                            cnt = 0 if "g" in fl else 1
                            try:
                                self.stack.append(
                                    _re.sub(pat, str(argv[1]), obj, count=cnt, flags=flags)
                                )
                            except Exception:
                                self.stack.append(obj)
                        else:
                            self.stack.append(obj)
                        continue
                    if meth == "indexOf":
                        self.stack.append(obj.find(str(argv[0])) if argv else -1)
                        continue
                    if meth == "lastIndexOf":
                        self.stack.append(obj.rfind(str(argv[0])) if argv else -1)
                        continue
                    if meth == "includes":
                        self.stack.append(bool(argv) and str(argv[0]) in obj)
                        continue
                    if meth == "split":
                        if not argv or argv[0] is None:
                            self.stack.append([obj])
                        elif argv[0] == "":
                            self.stack.append(list(obj))
                        else:
                            self.stack.append(obj.split(str(argv[0])))
                        continue
                    if meth in ("substring", "substr", "slice"):
                        a = int(argv[0]) if argv else 0
                        if meth == "substr":
                            b = a + int(argv[1]) if len(argv) > 1 else len(obj)
                        else:
                            b = int(argv[1]) if len(argv) > 1 else len(obj)
                        if meth != "slice":
                            a, b = max(0, a), max(0, b)
                            if a > b:
                                a, b = b, a
                        self.stack.append(obj[a:b])
                        continue
                    if meth == "charAt":
                        i = int(argv[0]) if argv else 0
                        self.stack.append(obj[i] if 0 <= i < len(obj) else "")
                        continue
                    if meth == "charCodeAt":
                        i = int(argv[0]) if argv else 0
                        self.stack.append(ord(obj[i]) if 0 <= i < len(obj) else None)
                        continue
                    if meth == "toUpperCase":
                        self.stack.append(obj.upper())
                        continue
                    if meth == "toLowerCase":
                        self.stack.append(obj.lower())
                        continue
                    if meth == "padStart":
                        n = int(argv[0]) if argv else 0
                        fill = str(argv[1]) if len(argv) > 1 else " "
                        self.stack.append(obj.rjust(n, fill[:1] or " "))
                        continue
                    if meth == "repeat":
                        self.stack.append(obj * max(0, int(argv[0])) if argv else "")
                        continue
                if isinstance(obj, dict) and obj.get("__class") == "RegExp":
                    # NEW: /re/.test(s) — stub false (skip iOS6 polyfill branch)
                    if meth == "test":
                        self.stack.append(False)
                        continue
                    self.stack.append(None)
                    continue
                if isinstance(obj, dict) and obj.get("__class") == "Date":
                    if meth == "toISOString":
                        from datetime import datetime, timezone

                        self.stack.append(
                            datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
                            + "Z"
                        )
                        continue
                    if meth in ("getTime", "valueOf"):
                        self.stack.append(self._now_ms())
                        continue
                # NEW: Date.now() / performance.now() — seeded DateCtor global
                if (
                    isinstance(obj, dict)
                    and obj.get("__class") == "DateCtor"
                    and meth == "now"
                ):
                    self.stack.append(self._now_ms())
                    continue
                # NEW: Object.keys/values/entries/freeze — seeded ObjectCtor global
                if isinstance(obj, dict) and obj.get("__class") == "ObjectCtor":
                    src = argv[0] if argv else None
                    if meth == "keys":
                        self.stack.append(
                            [k for k in src if k != "__class" and not str(k).startswith("__")]
                            if isinstance(src, dict)
                            else []
                        )
                        continue
                    if meth == "values":
                        self.stack.append(
                            [v for k, v in src.items() if k != "__class" and not str(k).startswith("__")]
                            if isinstance(src, dict)
                            else []
                        )
                        continue
                    if meth == "entries":
                        self.stack.append(
                            [[k, v] for k, v in src.items() if k != "__class" and not str(k).startswith("__")]
                            if isinstance(src, dict)
                            else []
                        )
                        continue
                    if meth == "freeze" or meth == "create":
                        self.stack.append(src if src is not None else {})
                        continue
                    # NEW: Object.assign(target, ...srcs)
                    if meth == "assign" and argv:
                        target = argv[0]
                        if isinstance(target, dict):
                            for src2 in argv[1:]:
                                if isinstance(src2, dict):
                                    for k, v in src2.items():
                                        if k != "__class":
                                            target[k] = v
                        self.stack.append(target)
                        continue
                if not isinstance(obj, dict):
                    # NEW: tolerate null.method() from optional DOM
                    self.stack.append(None)
                    continue
                cls_name = obj.get("__class")
                # NEW: canvas.getContext("2d") → Canvas2D stub for HTML titles
                if cls_name == "Element" and meth == "getContext":
                    self.stack.append({"__class": "Canvas2D", "fillStyle": "#000000"})
                    continue
                if cls_name == "Element" and meth == "click":
                    # NEW: fire global "click" listeners (start button)
                    click_fn = self.natives.get("__fire_click")
                    if click_fn:
                        click_fn()
                    self.stack.append(None)
                    continue
                if cls_name == "Element" and meth == "addEventListener":
                    # NEW: el.addEventListener → same as document.addEventListener
                    fn = self.natives.get("addEventListener")
                    if fn:
                        self.stack.append(fn(*argv))
                    else:
                        self.stack.append(None)
                    continue
                if cls_name == "Element" and meth == "removeEventListener":
                    fn = self.natives.get("removeEventListener")
                    if fn:
                        self.stack.append(fn(*argv))
                    else:
                        self.stack.append(None)
                    continue
                if cls_name == "Element" and meth == "dispatchEvent":
                    fn = self.natives.get("document.dispatchEvent")
                    if fn:
                        self.stack.append(fn(*argv))
                    else:
                        self.stack.append(None)
                    continue
                if cls_name == "Fn" and meth == "bind":
                    # PACMAN callback.bind(this) — copy Fn with bound_this.
                    # NEW: keep the captured lexical env — losing it detached
                    # stage key handlers from their level's player/map.
                    bound = {
                        "__class": "Fn",
                        "entry": obj.get("entry"),
                        "nparam": obj.get("nparam", 0),
                        "bound_this": argv[0] if argv else None,
                    }
                    if obj.get("env") is not None:
                        bound["env"] = obj["env"]
                    self.stack.append(bound)
                    continue
                # NEW: Object.assign(target, ...srcs) — PACMAN Item/Map/Stage ctors
                if meth == "assign" and argv:
                    target = argv[0]
                    if isinstance(target, dict):
                        for src in argv[1:]:
                            if isinstance(src, dict):
                                for k, v in src.items():
                                    if k != "__class":
                                        target[k] = v
                    self.stack.append(target)
                    continue
                if cls_name == "Canvas2D":
                    xfn = self.natives.get("__ctx_xform")
                    if xfn:
                        xfn(
                            obj.get("_tx", 0),
                            obj.get("_ty", 0),
                            obj.get("_sx", 1) or 1,
                            obj.get("_sy", 1) or 1,
                        )
                    fn = self.natives.get(f"ctx.{meth}") or self.natives.get(meth)
                    if meth == "beginPath":
                        obj["_path"] = []
                        self.stack.append(None)
                        continue
                    if meth == "closePath":
                        obj.setdefault("_path", []).append("Z")
                        self.stack.append(None)
                        continue
                    if meth == "moveTo" and len(argv) >= 2:
                        obj.setdefault("_path", []).append(f"M,{argv[0]},{argv[1]}")
                        self.stack.append(None)
                        continue
                    if meth == "lineTo" and len(argv) >= 2:
                        obj.setdefault("_path", []).append(f"L,{argv[0]},{argv[1]}")
                        self.stack.append(None)
                        continue
                    if meth == "quadraticCurveTo" and len(argv) >= 4:
                        # NEW: real quadratic record — rasterizer subdivides
                        obj.setdefault("_path", []).append(
                            f"Q,{argv[0]},{argv[1]},{argv[2]},{argv[3]}"
                        )
                        self.stack.append(None)
                        continue
                    if meth == "arc" and len(argv) >= 3:
                        ccw = 1 if (len(argv) > 5 and argv[5]) else 0
                        a0 = argv[3] if len(argv) > 3 else 0
                        a1 = argv[4] if len(argv) > 4 else 0
                        obj.setdefault("_path", []).append(
                            f"A,{argv[0]},{argv[1]},{argv[2]},{a0},{a1},{ccw}"
                        )
                        self.stack.append(None)
                        continue
                    if meth == "fill":
                        pfn = self.natives.get("ctx.fillPath")
                        if pfn:
                            pfn(obj.get("_path"), obj.get("fillStyle") or obj.get("strokeStyle"))
                        self.stack.append(None)
                        continue
                    if meth == "stroke":
                        pfn = self.natives.get("ctx.strokePath")
                        if pfn:
                            pfn(
                                obj.get("_path"),
                                obj.get("strokeStyle") or obj.get("fillStyle"),
                            )
                        self.stack.append(None)
                        continue
                    if meth == "fillText":
                        tfn = self.natives.get("ctx.fillText")
                        if tfn and argv:
                            tfn(
                                argv[0],
                                argv[1] if len(argv) > 1 else 0,
                                argv[2] if len(argv) > 2 else 0,
                                obj.get("fillStyle"),
                                obj.get("textAlign") or "left",
                                obj.get("font"),  # NEW: px size → glyph scale
                            )
                        self.stack.append(None)
                        continue
                    if meth == "measureText":
                        # NEW: DONKEY HUD layout — width from glyph size × font
                        mfn = self.natives.get("ctx.measureText")
                        t = argv[0] if argv else ""
                        if mfn:
                            self.stack.append(mfn(t, obj.get("font")))
                        else:
                            self.stack.append({"width": len(str(t)) * 8})
                        continue
                    if meth == "strokeRect" and len(argv) >= 4:
                        # NEW: 1px rect outline (was a no-op)
                        sfn = self.natives.get("ctx.strokeRect")
                        if sfn:
                            sfn(
                                argv[0], argv[1], argv[2], argv[3],
                                obj.get("strokeStyle") or obj.get("fillStyle"),
                            )
                        self.stack.append(None)
                        continue
                    if meth == "translate" and len(argv) >= 2:
                        obj["_tx"] = (obj.get("_tx") or 0) + (argv[0] or 0)
                        obj["_ty"] = (obj.get("_ty") or 0) + (argv[1] or 0)
                        self.stack.append(None)
                        continue
                    if meth == "setTransform" and len(argv) >= 6:
                        # a,b,c,d,e,f — axis scale + translate (DONKEY world→glass)
                        obj["_sx"] = argv[0] if argv[0] else 1
                        obj["_sy"] = argv[3] if argv[3] else 1
                        obj["_tx"] = argv[4] or 0
                        obj["_ty"] = argv[5] or 0
                        self.stack.append(None)
                        continue
                    if meth == "save":
                        obj["_saved"] = (
                            obj.get("_tx") or 0,
                            obj.get("_ty") or 0,
                            obj.get("_sx") or 1,
                            obj.get("_sy") or 1,
                        )
                        self.stack.append(None)
                        continue
                    if meth == "restore":
                        sv = obj.get("_saved") or (0, 0, 1, 1)
                        obj["_tx"], obj["_ty"] = sv[0], sv[1]
                        if len(sv) >= 4:
                            obj["_sx"], obj["_sy"] = sv[2], sv[3]
                        self.stack.append(None)
                        continue
                    if fn is not None:
                        # fillRect(x,y,w,h) — color from fillStyle if 4 args
                        if meth == "fillRect" and len(argv) == 4:
                            fs = obj.get("fillStyle", 0)
                            setfs = self.natives.get("setFillStyle") or self.natives.get(
                                "ctx.setFillStyle"
                            )
                            if setfs is not None and isinstance(fs, str):
                                setfs(fs)
                            result = fn(*argv)
                        else:
                            result = fn(*argv)
                        self.stack.append(result)
                        continue
                    # remaining canvas no-ops (clip / rotate / scale)
                    if meth in (
                        "clip",
                        "rotate",
                        "scale",
                    ):
                        self.stack.append(None)
                        continue
                    self.stack.append(None)
                    continue
                meta = (chunk.classes or {}).get(cls_name) if cls_name else None
                entry = (meta.get("methods") or {}).get(meth) if meta else None
                if entry is None:
                    # instance / prototype Fn (PACMAN this.createStage / Item.prototype.get)
                    fn = obj.get(meth) if isinstance(obj, dict) else None
                    if not (isinstance(fn, dict) and fn.get("__class") == "Fn"):
                        proto = obj.get("__proto__") if isinstance(obj, dict) else None
                        if isinstance(proto, dict):
                            fn = proto.get(meth)
                    if isinstance(fn, dict) and fn.get("__class") == "Fn":
                        self.call_stack.append(
                            (ip, self.globals.get("__this"), None, self.env)
                        )
                        self.env = {"__par": fn.get("env")}
                        self.globals["__this"] = (
                            fn["bound_this"] if fn.get("bound_this") is not None else obj
                        )
                        for a in argv:
                            self.stack.append(a)
                        ip = int(fn["entry"])
                        continue
                    # NEW: no-op stub for unknown Element methods (DOM chrome)
                    if cls_name in ("Element", "Image", "Date", "Audio", None):
                        self.stack.append(None)
                        continue
                    self.error = f"ERROR: NO METHOD {cls_name}.{meth}"
                    self.halted = True
                    return
                self.call_stack.append(
                    (ip, self.globals.get("__this"), None, self.env)
                )
                self.env = {"__par": None}  # class methods close over nothing
                self.globals["__this"] = obj
                for a in argv:
                    self.stack.append(a)
                ip = int(entry)
            elif op == Op.NEW_OBJ:
                # NEW: create dict with __class, call ctor if any, leave obj
                cls_name = chunk.names[args[0]]
                argc = int(args[1])
                argv = [self.stack.pop() for _ in range(argc)][::-1]
                meta = (chunk.classes or {}).get(cls_name)
                obj: dict = {"__class": cls_name}
                # NEW: resolve the ctor Fn through the env chain then globals
                # (PACMAN's Stage/Item/Map are locals of the Game function now)
                e = self.env
                while e is not None:
                    if cls_name in e:
                        ctor_fn = e[cls_name]
                        break
                    e = e.get("__par")
                else:
                    ctor_fn = self.globals.get(cls_name)
                if isinstance(ctor_fn, dict) and ctor_fn.get("__class") == "Fn":
                    proto = ctor_fn.get("prototype")
                    if proto is None:
                        proto = {}
                        ctor_fn["prototype"] = proto
                    obj["__proto__"] = proto
                ctor = meta.get("ctor") if meta else None
                # NEW: var Item = function(){} — ctor is Fn value
                if ctor is None:
                    fn = ctor_fn
                    if isinstance(fn, dict) and fn.get("__class") == "Fn":
                        self.call_stack.append(
                            (ip, self.globals.get("__this"), obj, self.env)
                        )
                        self.env = {"__par": fn.get("env")}
                        self.globals["__this"] = obj
                        for a in argv:
                            self.stack.append(a)
                        ip = int(fn["entry"])
                        continue
                    # NEW: DOM event ctors — copy (type, options) into the
                    # instance so dispatchEvent handlers see ev.key/keyCode
                    # (DONKEY boot script's new KeyboardEvent("keydown", {...}))
                    if cls_name in ("KeyboardEvent", "Event", "CustomEvent", "MouseEvent"):
                        if argv and isinstance(argv[0], str):
                            obj["type"] = argv[0]
                        if len(argv) > 1 and isinstance(argv[1], dict):
                            for _k, _v in argv[1].items():
                                if _k != "__class":
                                    obj[_k] = _v
                    self.stack.append(obj)
                else:
                    self.call_stack.append(
                        (ip, self.globals.get("__this"), obj, self.env)
                    )
                    self.env = {"__par": None}  # class ctor closes over nothing
                    self.globals["__this"] = obj
                    for a in argv:
                        self.stack.append(a)
                    ip = int(ctor)
            elif op == Op.RET_VAL:
                if not self.call_stack:
                    self.halted = True
                    return
                ip, saved_this, ctor_obj, saved_env = self.call_stack.pop()
                self.globals["__this"] = saved_this
                self.env = saved_env
                # NEW: constructor → discard return value, leave the instance
                if ctor_obj is not None:
                    if self.stack:
                        self.stack.pop()
                    self.stack.append(ctor_obj)
            elif op == Op.RETURN:
                self.halted = True
                return
            elif op == Op.POP:
                if self.stack:
                    self.stack.pop()
            elif op == Op.DUP:
                self.stack.append(self.stack[-1])
            elif op == Op.NEG:
                self.stack.append(-self.stack.pop())
            elif op == Op.NOT:
                self.stack.append(not self.stack.pop())
            elif op == Op.MAKE_ARRAY:
                n = args[0]
                items = [self.stack.pop() for _ in range(n)][::-1]
                self.stack.append(items)
            elif op == Op.ARRAY_GET:
                idx = self.stack.pop()
                arr = self.stack.pop()
                # NEW: JS-ish — list index OR dict/string key (PACMAN window[name])
                if isinstance(arr, list):
                    try:
                        i = int(idx)
                        self.stack.append(arr[i] if 0 <= i < len(arr) else None)
                    except Exception:
                        self.stack.append(None)
                elif isinstance(arr, dict):
                    self.stack.append(arr.get(idx))
                elif isinstance(arr, str):
                    try:
                        i = int(idx)
                        self.stack.append(arr[i] if 0 <= i < len(arr) else None)
                    except Exception:
                        self.stack.append(None)
                else:
                    self.stack.append(None)
            elif op == Op.ARRAY_SET:
                val = self.stack.pop()
                idx = self.stack.pop()
                arr = self.stack.pop()
                if isinstance(arr, list):
                    try:
                        i = int(idx)
                        # NEW: a[i]= grows length (JS). Twin of RTL ARR_SET.
                        if i >= len(arr) and i < 128:
                            arr.extend([None] * (i - len(arr) + 1))
                        if 0 <= i < len(arr):
                            arr[i] = val
                    except Exception:
                        pass
                elif isinstance(arr, dict):
                    arr[idx] = val
                self.stack.append(val)
            elif op == Op.MAKE_OBJ:
                self.stack.append({})
            elif op == Op.MAKE_FN:
                # NEW: push first-class function {__class:Fn, entry, nparam}
                entry = int(args[0])
                nparam = int(args[1]) if len(args) > 1 else 0
                fn_val: dict = {"__class": "Fn", "entry": entry, "nparam": nparam}
                # NEW: capture the lexical environment (closures) — PACMAN's
                # per-level stage/map/player closures need their own iteration
                # scope, not whatever the flat globals held last.
                if self.env is not None:
                    fn_val["env"] = self.env
                # NEW: only arrows (arg2=1) capture lexical `this` — DONKEY's
                # (e)=>this.startGame(e) — regular function expressions keep
                # dynamic this (PACMAN Stage.prototype.* set inside ctors).
                if len(args) > 2 and args[2]:
                    cur_this = self.globals.get("__this")
                    if cur_this is not None:
                        fn_val["bound_this"] = cur_this
                # NEW: arg3=1 → immediately-invoked (IIFE). Top-level IIFEs
                # run FLAT (locals stay global) so module classes/functions
                # keep seeing their module vars (DONKEY sprite sheets).
                if len(args) > 3 and args[3]:
                    fn_val["iife"] = True
                self.stack.append(fn_val)
            elif op == Op.GET_PROP:
                name = chunk.names[args[0]]
                obj = self.stack.pop()
                if obj is None:
                    self.stack.append(None)
                elif name == "length" and isinstance(obj, (list, str)):
                    # NEW: arr.length / str.length
                    self.stack.append(len(obj))
                elif (
                    isinstance(obj, dict)
                    and obj.get("__class") == "Element"
                    and name == "click"
                ):
                    # NEW: truthy click handle so `if (b && b.click) b.click()` works
                    self.stack.append(
                        {"__class": "Fn", "entry": -2, "nparam": 0, "builtin": "el_click"}
                    )
                elif isinstance(obj, dict) and name == "prototype":
                    # PACMAN Item.prototype.foo = fn
                    proto = obj.get("prototype")
                    if proto is None:
                        proto = {}
                        obj["prototype"] = proto
                    self.stack.append(proto)
                elif isinstance(obj, dict):
                    val = obj.get(name)
                    # NEW: this.method / this.arrowField as a VALUE (DONKEY
                    # passes this.startSelect to addEventListener). Materialize
                    # the class method as a bound Fn and cache it on the
                    # instance so identity is stable (add/remove listener).
                    if val is None and obj.get("__class"):
                        meta = (chunk.classes or {}).get(obj["__class"])
                        entry = (meta.get("methods") or {}).get(name) if meta else None
                        if entry is not None:
                            # NEW: `get name()` accessor — CALL it now (argc 0)
                            # instead of materializing a Fn (DONKEY marioMiddle).
                            if name in (meta.get("getters") or ()):
                                self.call_stack.append(
                                    (ip, self.globals.get("__this"), None, self.env)
                                )
                                self.env = {"__par": None}
                                self.globals["__this"] = obj
                                ip = int(entry)
                                continue
                            val = {
                                "__class": "Fn",
                                "entry": int(entry),
                                "bound_this": obj,
                            }
                            obj[name] = val
                    self.stack.append(val)
                else:
                    self.stack.append(getattr(obj, name, None))
            elif op == Op.SET_PROP:
                name = chunk.names[args[0]]
                val = self.stack.pop()
                obj = self.stack.pop()
                if obj is None:
                    self.stack.append(val)
                elif isinstance(obj, list) and name == "length":
                    # NEW: arr.length = n truncates (INVADERS start reset)
                    n = max(0, int(val))
                    del obj[n:]
                    self.stack.append(n)
                elif isinstance(obj, dict):
                    obj[name] = val
                    # NEW: Image.src = data:… → size from PNG + fire onload (Player ship)
                    if (
                        obj.get("__class") == "Image"
                        and name == "src"
                        and isinstance(val, str)
                    ):
                        w, h = _png_size_from_data_uri(val)
                        obj["width"] = w
                        obj["height"] = h
                        # jmr:spr:N sprite handle from compile-on-RUN
                        if val.startswith("jmr:spr:"):
                            try:
                                si = int(val.split(":")[-1])
                            except ValueError:
                                si = -1
                            pack = getattr(self, "_sprites", None) or []
                            if 0 <= si < len(pack):
                                sw, sh, third = pack[si]
                                obj["width"] = sw
                                obj["height"] = sh
                                obj["_spr"] = si
                                # legacy SPR1 pack carries bytes; ASET path
                                # carries an SRAM offset — pixels stay in the
                                # asset bank (drawImage resolves via _spr)
                                if isinstance(third, (bytes, bytearray)):
                                    obj["_pix"] = third
                        onload = obj.get("onload")
                        if isinstance(onload, dict) and onload.get("__class") == "Fn":
                            # NEW: don't let nested call_fn disturb ctor stack
                            depth = len(self.stack)
                            self.call_fn(chunk, onload, [])
                            while len(self.stack) > depth:
                                self.stack.pop()
                    # NEW: Image.onload = fn after src already set (INVADERS order)
                    elif (
                        obj.get("__class") == "Image"
                        and name == "onload"
                        and isinstance(val, dict)
                        and val.get("__class") == "Fn"
                        and obj.get("src")
                    ):
                        depth = len(self.stack)
                        self.call_fn(chunk, val, [])
                        while len(self.stack) > depth:
                            self.stack.pop()
                    self.stack.append(val)
                else:
                    try:
                        setattr(obj, name, val)
                    except Exception:
                        pass
                    self.stack.append(val)
            else:
                self.error = f"ERROR: BAD OPCODE {op}"
                self.halted = True
                return
        if steps >= max_steps:
            self.error = "ERROR: STEP LIMIT"
            self.halted = True
