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


class VM:
    """Tiny stack VM with native hooks for console / canvas / joy."""

    def __init__(
        self,
        natives: Optional[Dict[str, Callable[..., Any]]] = None,
    ) -> None:
        self.natives = natives or {}
        self.globals: Dict[str, Any] = {}
        self.stack: List[Any] = []
        # NEW: (return_ip, saved__this, ctor_obj_or_None)
        self.call_stack: List[Tuple[int, Any, Any]] = []
        self.halted = False
        self.error: Optional[str] = None

    def reset_run(self) -> None:
        self.stack.clear()
        self.call_stack.clear()
        self.halted = False
        self.error = None

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
        for a in argv or []:
            self.stack.append(a)
        self.call_stack.append((-1, self.globals.get("__this"), None))
        if fn.get("bound_this") is not None:
            self.globals["__this"] = fn["bound_this"]
        # Run from entry without clearing stack/globals (nested from rAF / click)
        saved_halted = self.halted
        self.halted = False
        self._exec(chunk, start_ip=entry, max_steps=max_steps, reset=False)
        # Nested error should surface; don't leave halted stuck for outer frame_tick
        if not self.error:
            self.halted = saved_halted
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
            ip += 1
            if op == Op.LOAD_CONST:
                self.stack.append(chunk.consts[args[0]])
            elif op == Op.LOAD_VAR:
                name = chunk.names[args[0]]
                self.stack.append(self.globals.get(name))
            elif op == Op.STORE_VAR:
                name = chunk.names[args[0]]
                # NEW: tolerate empty stack (partial expr compile) — undefined
                self.globals[name] = self.stack.pop() if self.stack else None
            elif op == Op.LET_VAR:
                # LLM NOTE: let/const under startLoop — do not reset each frame.
                name = chunk.names[args[0]]
                val = self.stack.pop() if self.stack else None
                if name not in self.globals:
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
                if a is None or b is None:
                    self.stack.append(False)
                else:
                    self.stack.append(a < b)
            elif op == Op.GT:
                b, a = self.stack.pop(), self.stack.pop()
                if a is None or b is None:
                    self.stack.append(False)
                else:
                    self.stack.append(a > b)
            elif op == Op.EQ:
                b, a = self.stack.pop(), self.stack.pop()
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
                    have = ",".join(sorted(self.natives)) or "(none)"
                    self.error = f"ERROR: UNKNOWN NATIVE {name} (have: {have})"
                    self.halted = True
                    return
                result = fn(*argv)
                # NEW: always push (None = JS undefined) so JSON.parse(getItem()) works
                self.stack.append(result)
            elif op == Op.CALL_USER:
                entry = int(args[0])
                self.call_stack.append((ip, self.globals.get("__this"), None))
                ip = entry
            elif op == Op.CALL_VAL:
                # NEW: call Fn on stack — (function(){...}()) IIFE
                argc = int(args[0])
                argv = [self.stack.pop() for _ in range(argc)][::-1]
                fn = self.stack.pop()
                if isinstance(fn, dict) and fn.get("__class") == "Fn":
                    self.call_stack.append((ip, self.globals.get("__this"), None))
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

                            def _cmp(a, b, _entry=entry, _np=nparam):
                                # re-entrant mini-run of comparator
                                saved = (
                                    self.stack[:],
                                    self.call_stack[:],
                                    self.globals.get("__this"),
                                    ip,
                                )
                                self.stack.append(a)
                                self.stack.append(b)
                                # bind params like CALL_USER prologue expects args on stack
                                self.call_stack.append((-1, self.globals.get("__this"), None))
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
                                        rip, saved_this, ctor_obj = self.call_stack.pop()
                                        self.globals["__this"] = saved_this
                                        if ctor_obj is not None:
                                            if self.stack:
                                                self.stack.pop()
                                            self.stack.append(ctor_obj)
                                        continue
                                    if op2 == Op.LOAD_CONST:
                                        self.stack.append(chunk.consts[args2[0]])
                                    elif op2 == Op.LOAD_VAR:
                                        self.stack.append(self.globals.get(chunk.names[args2[0]]))
                                    elif op2 == Op.STORE_VAR:
                                        self.globals[chunk.names[args2[0]]] = self.stack.pop()
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
                if isinstance(obj, str):
                    if meth == "trim":
                        self.stack.append(obj.strip())
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
                if cls_name == "Fn" and meth == "bind":
                    # PACMAN callback.bind(this) — copy Fn with bound_this
                    bound = {
                        "__class": "Fn",
                        "entry": obj.get("entry"),
                        "nparam": obj.get("nparam", 0),
                        "bound_this": argv[0] if argv else None,
                    }
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
                        obj.setdefault("_path", []).append(f"L,{argv[2]},{argv[3]}")
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
                        "strokeRect",
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
                        self.call_stack.append((ip, self.globals.get("__this"), None))
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
                self.call_stack.append((ip, self.globals.get("__this"), None))
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
                ctor_fn = self.globals.get(cls_name)
                if isinstance(ctor_fn, dict) and ctor_fn.get("__class") == "Fn":
                    proto = ctor_fn.get("prototype")
                    if proto is None:
                        proto = {}
                        ctor_fn["prototype"] = proto
                    obj["__proto__"] = proto
                ctor = meta.get("ctor") if meta else None
                # NEW: var Item = function(){} — ctor is Fn in globals
                if ctor is None:
                    fn = self.globals.get(cls_name)
                    if isinstance(fn, dict) and fn.get("__class") == "Fn":
                        self.call_stack.append((ip, self.globals.get("__this"), obj))
                        self.globals["__this"] = obj
                        for a in argv:
                            self.stack.append(a)
                        ip = int(fn["entry"])
                        continue
                    self.stack.append(obj)
                else:
                    self.call_stack.append((ip, self.globals.get("__this"), obj))
                    self.globals["__this"] = obj
                    for a in argv:
                        self.stack.append(a)
                    ip = int(ctor)
            elif op == Op.RET_VAL:
                if not self.call_stack:
                    self.halted = True
                    return
                ip, saved_this, ctor_obj = self.call_stack.pop()
                self.globals["__this"] = saved_this
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
                self.stack.append({"__class": "Fn", "entry": entry, "nparam": nparam})
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
                    self.stack.append(obj.get(name))
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
                        # jmr:spr:N from card-build pack
                        if val.startswith("jmr:spr:"):
                            try:
                                si = int(val.split(":")[-1])
                            except ValueError:
                                si = -1
                            pack = getattr(self, "_sprites", None) or []
                            if 0 <= si < len(pack):
                                sw, sh, pix = pack[si]
                                obj["width"] = sw
                                obj["height"] = sh
                                obj["_pix"] = pix
                                obj["_spr"] = si
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
