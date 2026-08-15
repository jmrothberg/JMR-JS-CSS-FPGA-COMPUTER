"""Tiny JS subset compiler → JMR-JS bytecode.

Supports: numbers, strings, lets, arithmetic, comparisons, if/while/for,
&& / || (short-circuit), real %, compound assigns (+= etc), ++/--,
function calls to natives (console.log, fillRect, clearRect, swap, joy).
Not a full JS parser — grow from compatibility matrix only.
"""

from __future__ import annotations

import re
from typing import Any, List, Optional, Tuple

from .bytecode import Chunk, Op
from .jsb_format import NATIVE_ALIASES, NATIVE_IDS

# Bare ID( PYTHON still implements as natives (not in the JSB NATIVE_IDS table).
# Unknown ID( otherwise LOAD_VAR+CALL_VAL so RTL can call `var f = function`.
_HOST_NATIVES = frozenset({"joy", "getJoy", "clearRect", "setFillStyle"})


class CompileError(Exception):
    def __init__(self, message: str, line: int = 0) -> None:
        super().__init__(message)
        self.line = line
        self.message = message


_TOKEN = re.compile(
    r"""
    (?P<WS>\s+) |
    (?P<LINE_COMMENT>//[^\n]*) |
    (?P<BLOCK_COMMENT>/\*.*?\*/) |
    (?P<STR>"([^"\\]|\\.)*") |
    (?P<STR2>'([^'\\]|\\.)*') |
    (?P<TMPL>`(?:\\.|\$\{[^}]*\}|[^`$\\])*`) |
    (?P<NUM>\d+(\.\d+)?|\.\d+) |
    (?P<ID>[A-Za-z_$][A-Za-z0-9_$]*) |
    (?P<OP>\+\+|--|=>|\?\.|\?|===|!==|==|!=|<=|>=|&&|\|\||[+\-*/%]=|[+\-*/%<>=!();:{},.\[\]|&])
    """,
    re.VERBOSE | re.DOTALL,
)


def _tokenize(src: str) -> List[Tuple[str, str, int]]:
    tokens: List[Tuple[str, str, int]] = []
    line = 1
    pos = 0
    # NEW: after these, `/.../` is a regex literal (PACMAN rAF polyfill)
    _regex_prev = {
        "",
        "(",
        "=",
        "==",
        "===",
        "!=",
        "!==",
        ",",
        ":",
        "!",
        "[",
        "{",
        "?",
        "&&",
        "||",
        "return",
        "typeof",
    }
    while pos < len(src):
        if src[pos] == "\n":
            line += 1
            pos += 1
            continue
        # NEW: regex literal before OP `/` when prior token allows
        prev = tokens[-1][1] if tokens else ""
        if src[pos] == "/" and pos + 1 < len(src) and src[pos + 1] not in ("/", "*"):
            if prev in _regex_prev:
                j = pos + 1
                while j < len(src) and src[j] != "\n":
                    if src[j] == "\\" and j + 1 < len(src):
                        j += 2
                        continue
                    if src[j] == "/":
                        j += 1
                        while j < len(src) and src[j] in "gimsuy":
                            j += 1
                        tokens.append(("REGEX", src[pos:j], line))
                        pos = j
                        break
                    j += 1
                else:
                    m = _TOKEN.match(src, pos)
                    if not m:
                        raise CompileError(f"UNEXPECTED TOKEN near {src[pos:pos+10]!r}", line)
                    kind = m.lastgroup or ""
                    text = m.group(0)
                    pos = m.end()
                    if kind in ("WS", "LINE_COMMENT", "BLOCK_COMMENT"):
                        line += text.count("\n")
                        continue
                    tokens.append((kind, text, line))
                continue
        m = _TOKEN.match(src, pos)
        if not m:
            raise CompileError(f"UNEXPECTED TOKEN near {src[pos:pos+10]!r}", line)
        kind = m.lastgroup or ""
        text = m.group(0)
        pos = m.end()
        if kind in ("WS", "LINE_COMMENT", "BLOCK_COMMENT"):
            line += text.count("\n")
            continue
        tokens.append((kind, text, line))
    return tokens


def _isolate_iife_modules(
    tokens: List[Tuple[str, str, int]],
) -> List[Tuple[str, str, int]]:
    """NEW: lexical scoping for `X = (function(){ ... })()` module IIFEs.

    DONKEY vendors six modules that each declare their own `let img` sprite
    sheet; in the VM's flat namespace the last module clobbered the others
    (Mario drew from the Platform sheet). Rename let/var/const-declared
    names inside each such module to __mK_name. Class/function declarations
    stay global (classes are compile-time entities in this VM and module
    class names are unique).
    """
    out = list(tokens)
    n = len(out)
    depth = 0
    i = 0
    mod = 0
    while i < n:
        kind, text, _ln = out[i]
        if (
            depth == 0
            and kind == "ID"
            and i + 6 < n
            and out[i + 1][1] == "="
            and out[i + 2][1] == "("
            and out[i + 3][1] == "function"
            and out[i + 4][1] == "("
            and out[i + 5][1] == ")"
            and out[i + 6][1] == "{"
        ):
            # match the module body braces
            j = i + 6
            bd = 0
            while j < n:
                if out[j][1] == "{":
                    bd += 1
                elif out[j][1] == "}":
                    bd -= 1
                    if bd == 0:
                        break
                j += 1
            body_start, body_end = i + 7, j
            declared: set = set()
            p = body_start
            while p < body_end:
                if out[p][1] in ("let", "var", "const") and out[p + 1][0] == "ID":
                    declared.add(out[p + 1][1])
                p += 1
            if declared:
                mod += 1
                pref = f"__m{mod}_"
                p = body_start
                while p < body_end:
                    pk, pt, pln = out[p]
                    if pk == "ID" and pt in declared:
                        prev_t = out[p - 1][1] if p > 0 else ""
                        next_t = out[p + 1][1] if p + 1 < n else ""
                        # keep property access (.img) and object keys (img:)
                        if prev_t != "." and not (
                            next_t == ":" and prev_t in ("{", ",")
                        ):
                            out[p] = (pk, pref + pt, pln)
                    p += 1
            # skip the already-balanced module: `}` then `) ( )`
            i = j + 1
            if i < n and out[i][1] == ")":
                i += 1
            if i + 1 < n and out[i][1] == "(" and out[i + 1][1] == ")":
                i += 2
            continue
        if text in ("{", "("):
            depth += 1
        elif text in ("}", ")"):
            depth -= 1
        i += 1
    return out


class Compiler:
    def __init__(self, src: str) -> None:
        self.tokens = _isolate_iife_modules(_tokenize(src))
        self.i = 0
        self.consts: List[Any] = []
        self.names: List[str] = []
        self.name_index: dict[str, int] = {}
        self.code: List[Tuple] = []
        # NEW: HTML line per emitted op (monitor follows bytecode → source)
        self.op_lines: List[int] = []
        # NEW: user functions name → (entry_ip, params)
        self.functions: dict[str, Tuple[int, List[str]]] = {}
        # NEW: classes + set of all method names (for CALL_METHOD dispatch)
        self.classes: dict[str, dict] = {}
        self.all_methods: set[str] = set()
        # NEW: break patch lists for switch (and later loops)
        self.break_stack: List[List[int]] = []
        # NEW: continue patch lists for for/while (bunker arch `continue`)
        self.continue_stack: List[List[int]] = []
        # NEW: >0 inside function/method/arrow → let/const must STORE (not LET_VAR).
        # Top-level keeps LET_VAR for startLoop re-entry (DONKEY.JS inited etc.).
        self._fn_depth = 0

    def compile(self) -> Chunk:
        # NEW: hoist function + class declarations first (JS-style)
        saved_i = self.i
        self._prescan_class_names()  # so `new Foo` inside functions resolves
        self._compile_all_classes()
        self.i = 0
        self._compile_all_functions()
        self.i = saved_i
        while not self._done():
            if self._peek_text() == "function":
                self._skip_function_decl()
                continue
            if self._peek_text() == "class":
                self._skip_class_decl()
                continue
            self._statement()
        return Chunk(
            self.code,
            self.consts,
            self.names,
            dict(self.functions),
            dict(self.classes),
            op_lines=list(self.op_lines),
        )

    def _prescan_class_names(self) -> None:
        """Register class names before emitting functions that `new` them."""
        i = 0
        while i < len(self.tokens) - 1:
            if self.tokens[i][1] == "class" and self.tokens[i + 1][0] == "ID":
                cname = self.tokens[i + 1][1]
                if cname not in self.classes:
                    self.classes[cname] = {"ctor": None, "methods": {}}
            i += 1

    def _skip_function_decl(self) -> None:
        """Advance past a function declaration without emitting (already hoisted)."""
        self._advance()  # function
        if self._peek() and self._peek()[0] == "ID":
            self._advance()
        self._expect("(")
        while self._peek_text() not in ("", ")"):
            self._advance()
            self._match(",")
        self._expect(")")
        self._skip_block()

    def _skip_block(self) -> None:
        self._expect("{")
        depth = 1
        while not self._done() and depth:
            t = self._peek_text()
            if t == "{":
                depth += 1
            elif t == "}":
                depth -= 1
            self._advance()

    def _skip_statement(self) -> None:
        """Advance past one statement without emitting (for skipped catch bodies)."""
        if self._peek_text() == "{":
            self._skip_block()
            return
        # expression-like: consume until ';' or block end
        depth = 0
        while not self._done():
            t = self._peek_text()
            if t == "{" :
                depth += 1
            elif t == "}":
                if depth == 0:
                    break
                depth -= 1
            elif t == ";" and depth == 0:
                self._advance()
                break
            self._advance()

    def _compile_all_functions(self) -> None:
        """Scan source for named function decls and emit them (jumped over at runtime)."""
        i = 0
        while i < len(self.tokens):
            if self.tokens[i][1] == "function":
                # NEW: skip anonymous function expressions (next token is '(')
                if i + 1 < len(self.tokens) and self.tokens[i + 1][1] == "(":
                    i += 1
                    continue
                self.i = i
                self._function_decl()
                i = self.i
            else:
                i += 1

    def _function_decl(self) -> None:
        """NEW: function name(params) { body } → JUMP over; entry; bind; body; RET_VAL."""
        self._advance()  # function
        kind, text, line = self._advance()
        if kind != "ID":
            raise CompileError("EXPECTED FUNCTION NAME", line)
        fname = text
        self._expect("(")
        params: List[Any] = []
        if self._peek_text() != ")":
            while True:
                # NEW: object destructuring { a, b } → one arg unpacked to locals
                if self._match("{"):
                    keys: List[str] = []
                    while self._peek_text() not in ("", "}"):
                        k, p, ln = self._advance()
                        if k != "ID":
                            raise CompileError("EXPECTED DESTRUCTURE KEY", ln)
                        keys.append(p)
                        if not self._match(","):
                            break
                    self._expect("}")
                    params.append(("destruct", keys))
                else:
                    k, p, ln = self._advance()
                    if k != "ID":
                        raise CompileError("EXPECTED PARAM", ln)
                    params.append(p)
                if not self._match(","):
                    break
        self._expect(")")
        jmp_over = self._emit(Op.JUMP, 0)
        entry = len(self.code)
        # prologue: stack has arg0..argN-1 (last arg on top)
        # NEW: params declare into the per-call lexical env (LET_VAR).
        # arg2=1 flags "call-frame local" for RTL (flat vars: always store;
        # only top-level LET_VAR keeps init-if-missing across frame re-runs).
        for p in reversed(params):
            if isinstance(p, tuple) and p[0] == "destruct":
                tmp = self._name("__arg")
                self._emit(Op.LET_VAR, tmp, 1)
                for key in p[1]:
                    self._emit(Op.LOAD_VAR, tmp)
                    self._emit(Op.GET_PROP, self._name(key))
                    self._emit(Op.LET_VAR, self._name(key), 1)
            else:
                self._emit(Op.LET_VAR, self._name(p), 1)
        self._expect("{")
        self._fn_depth += 1  # NEW: function body locals use LET_VAR (env)
        while self._peek_text() not in ("", "}"):
            self._statement()
        self._expect("}")
        self._fn_depth -= 1
        # implicit return undefined
        self._emit(Op.LOAD_CONST, self._const(None))
        self._emit(Op.RET_VAL)
        self._patch(jmp_over, Op.JUMP, len(self.code))
        # store flat param count for arity (destruct counts as 1)
        flat = [p if isinstance(p, str) else "__arg" for p in params]
        self.functions[fname] = (entry, flat)
        # NEW: bind function name as first-class Fn (rAF(animate) / keys need LOAD_VAR)
        self._emit(Op.MAKE_FN, entry, len(flat))
        # NEW: nested decls stay local to the enclosing call env (LET_VAR);
        # top level keeps the global STORE (hoisted call sites need it)
        if self._fn_depth:
            self._emit(Op.LET_VAR, self._name(fname), 1)  # call-frame local (RTL flag)
        else:
            self._emit(Op.STORE_VAR, self._name(fname))


    def _skip_class_decl(self) -> None:
        """Advance past a class declaration (already hoisted)."""
        self._advance()  # class
        if self._peek() and self._peek()[0] == "ID":
            self._advance()
        self._skip_block()

    def _compile_all_classes(self) -> None:
        """Scan source for class decls and emit ctor/methods."""
        # Pass 1: collect all method names so this.foo() resolves inside bodies
        i = 0
        while i < len(self.tokens):
            if self.tokens[i][1] == "class":
                j = i + 1
                if j < len(self.tokens) and self.tokens[j][0] == "ID":
                    j += 1
                if j < len(self.tokens) and self.tokens[j][1] == "{":
                    j += 1
                    depth = 1
                    while j < len(self.tokens) and depth:
                        t = self.tokens[j]
                        if t[1] == "{":
                            depth += 1
                        elif t[1] == "}":
                            depth -= 1
                        elif depth == 1 and t[0] == "ID" and t[1] != "constructor":
                            # method name at class body top level
                            if j + 1 < len(self.tokens) and self.tokens[j + 1][1] == "(":
                                self.all_methods.add(t[1])
                        j += 1
                i = j
            else:
                i += 1
        # Pass 2: emit
        i = 0
        while i < len(self.tokens):
            if self.tokens[i][1] == "class":
                self.i = i
                self._class_decl()
                i = self.i
            else:
                i += 1

    def _class_decl(self) -> None:
        """NEW: class Name { constructor(...) {} meth(...) {} } → fixed-slot objects."""
        self._advance()  # class
        kind, text, line = self._advance()
        if kind != "ID":
            raise CompileError("EXPECTED CLASS NAME", line)
        cname = text
        methods: dict[str, int] = {}
        getters: set[str] = set()  # NEW: `get name()` accessors (DONKEY marioMiddle)
        ctor_entry: Optional[int] = None
        self._expect("{")
        while self._peek_text() not in ("", "}"):
            # NEW: get name() / set name() — body compiles like a method, but
            # getters are recorded so GET_PROP invokes them (this.marioMiddle).
            is_getter = False
            if self._peek_text() in ("get", "set") and (
                self.i + 1 < len(self.tokens) and self.tokens[self.i + 1][0] == "ID"
            ):
                is_getter = self._peek_text() == "get"
                self._advance()
            # NEW: class field arrow — startSelect = (e) => {}
            mk, mname, mline = self._peek() or ("", "", 0)
            if mk == "ID" and self.i + 1 < len(self.tokens) and self.tokens[self.i + 1][1] == "=":
                self._advance()
                self._expect("=")
                self._expression()
                if self.code and self.code[-1][0] == Op.MAKE_FN:
                    entry = int(self.code[-1][1])
                    self.code.pop()  # method body already JUMP-guarded; no runtime MAKE_FN
                    self.op_lines.pop()  # keep ProgramImage source map aligned
                    methods[mname] = entry
                    self.all_methods.add(mname)
                else:
                    # non-fn field — discard (class decl skipped at runtime)
                    self._emit(Op.POP)
                self._match(";")
                continue
            # method or constructor
            mk, mname, mline = self._peek() or ("", "", 0)
            if mk != "ID":
                raise CompileError("EXPECTED METHOD NAME", mline)
            self._advance()
            is_ctor = mname == "constructor"
            self._expect("(")
            params: List[Any] = []
            if self._peek_text() != ")":
                while True:
                    # NEW: constructor({ position, type }) destructuring
                    if self._match("{"):
                        keys: List[str] = []
                        while self._peek_text() not in ("", "}"):
                            k, p, ln = self._advance()
                            if k != "ID":
                                raise CompileError("EXPECTED DESTRUCTURE KEY", ln)
                            keys.append(p)
                            if not self._match(","):
                                break
                        self._expect("}")
                        params.append(("destruct", keys))
                    else:
                        k, p, ln = self._advance()
                        if k != "ID":
                            raise CompileError("EXPECTED PARAM", ln)
                        params.append(p)
                    if not self._match(","):
                        break
            self._expect(")")
            jmp_over = self._emit(Op.JUMP, 0)
            entry = len(self.code)
            # NEW: method params declare into the per-call env (LET_VAR);
            # arg2=1 = call-frame local flag for RTL (always store there)
            for p in reversed(params):
                if isinstance(p, tuple) and p[0] == "destruct":
                    tmp = self._name("__arg")
                    self._emit(Op.LET_VAR, tmp, 1)
                    for key in p[1]:
                        self._emit(Op.LOAD_VAR, tmp)
                        self._emit(Op.GET_PROP, self._name(key))
                        self._emit(Op.LET_VAR, self._name(key), 1)
                else:
                    self._emit(Op.LET_VAR, self._name(p), 1)
            self._expect("{")
            self._fn_depth += 1  # NEW: class method/ctor locals use LET_VAR (env)
            while self._peek_text() not in ("", "}"):
                self._statement()
            self._expect("}")
            self._fn_depth -= 1
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
            self._patch(jmp_over, Op.JUMP, len(self.code))
            if is_ctor:
                ctor_entry = entry
            else:
                methods[mname] = entry
                self.all_methods.add(mname)
                if is_getter:
                    getters.add(mname)
        self._expect("}")
        self.classes[cname] = {"ctor": ctor_entry, "methods": methods, "getters": getters}

    def _done(self) -> bool:
        return self.i >= len(self.tokens)

    def _peek(self) -> Optional[Tuple[str, str, int]]:
        return None if self._done() else self.tokens[self.i]

    def _peek_text(self) -> str:
        t = self._peek()
        return "" if t is None else t[1]

    def _advance(self) -> Tuple[str, str, int]:
        t = self.tokens[self.i]
        self.i += 1
        return t

    def _match(self, text: str) -> bool:
        if self._peek_text() == text:
            self._advance()
            return True
        return False

    def _expect(self, text: str) -> None:
        if not self._match(text):
            line = self._peek()[2] if self._peek() else 0
            raise CompileError(f"EXPECTED {text!r}", line)

    def _const(self, value: Any) -> int:
        self.consts.append(value)
        return len(self.consts) - 1

    def _name(self, name: str) -> int:
        if name not in self.name_index:
            self.name_index[name] = len(self.names)
            self.names.append(name)
        return self.name_index[name]

    def _emit(self, *op_args: Any) -> int:
        t = self._peek()
        if t is None and self.i > 0:
            t = self.tokens[self.i - 1]
        line = int(t[2]) if t is not None else 0
        self.code.append(tuple(op_args))
        self.op_lines.append(line)
        return len(self.code) - 1

    def _patch(self, idx: int, *op_args: Any) -> None:
        self.code[idx] = tuple(op_args)

    def _statement(self) -> None:
        t = self._peek()
        if t is None:
            return
        kind, text, line = t
        # NEW: empty statement (";" script-block separators)
        if text == ";":
            self._advance()
            return
        if text in ("let", "var", "const"):
            self._advance()
            self._var_decl()
            self._match(";")
            return
        # NEW: nested class (DONKEY IIFE) — hoisted already; skip token body
        if text == "class":
            self._skip_class_decl()
            return
        if text == "if":
            self._if_stmt()
            return
        if text == "while":
            self._while_stmt()
            return
        # NEW: for (init; cond; step) body — desugar to while
        if text == "for":
            self._for_stmt()
            return
        # NEW: switch / case / break
        if text == "switch":
            self._switch_stmt()
            return
        if text == "break":
            self._advance()
            if not self.break_stack:
                raise CompileError("BREAK OUTSIDE SWITCH/LOOP", line)
            self.break_stack[-1].append(self._emit(Op.JUMP, 0))
            self._match(";")
            return
        # NEW: continue → jump to innermost loop's step/condition (not a no-op ID)
        if text == "continue":
            self._advance()
            if not self.continue_stack:
                raise CompileError("CONTINUE OUTSIDE LOOP", line)
            self.continue_stack[-1].append(self._emit(Op.JUMP, 0))
            self._match(";")
            return
        # NEW: try { ... } catch (...) { ... } — run try body; skip catch tokens
        if text == "try":
            self._advance()
            self._statement()  # try block
            if self._match("catch"):
                if self._match("("):
                    while self._peek_text() not in ("", ")"):
                        self._advance()
                    self._expect(")")
                self._skip_statement()
            return
        # NEW: return [expr];
        if text == "return":
            self._advance()
            if self._peek_text() not in ("", ";", "}"):
                self._expression()
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
            self._match(";")
            return
        if text == "{":
            self._block()
            return
        # expression statement
        self._expression()
        self._emit(Op.POP)
        self._match(";")

    def _var_decl(self) -> None:
        # NEW: const { key } = e;  object destructure
        if self._match("{"):
            keys: List[str] = []
            while self._peek_text() not in ("", "}"):
                k, p, ln = self._advance()
                if k != "ID":
                    raise CompileError("EXPECTED DESTRUCTURE KEY", ln)
                keys.append(p)
                if not self._match(","):
                    break
            self._expect("}")
            self._expect("=")
            self._expression()
            tmp = self._name("__arg")
            # NEW: fn locals declare into the call env (LET_VAR); top-level
            # LET_VAR keeps init-if-missing (startLoop), so tmp stays STORE
            # there (shared __arg must be re-assigned each use).
            if self._fn_depth:
                self._emit(Op.LET_VAR, tmp, 1)  # call-frame local (RTL flag)
            else:
                self._emit(Op.STORE_VAR, tmp)
            for key in keys:
                self._emit(Op.LOAD_VAR, tmp)
                self._emit(Op.GET_PROP, self._name(key))
                self._emit(Op.LET_VAR, self._name(key), 1 if self._fn_depth else 0)
            return
        # NEW: var a, b=1, c;  multi-declarator (DONKEY)
        while True:
            kind, text, line = self._advance()
            if kind != "ID":
                raise CompileError("EXPECTED IDENTIFIER", line)
            if self._match("="):
                # NEW: _ternary not _expression — `,` separates declarators
                # (PACMAN `var _CONFIG=[..], _LIFE=5, _SCORE=0` got _LIFE=0)
                self._ternary()
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
            # NEW: LET_VAR everywhere — inside a fn it declares in the call
            # env (per-call locals, closure-correct); top level keeps the
            # init-if-missing global (startLoop re-entry). arg2=1 marks
            # call-frame locals so flat-var RTL always stores those.
            self._emit(Op.LET_VAR, self._name(text), 1 if self._fn_depth else 0)
            if not self._match(","):
                break

    def _block(self) -> None:
        self._expect("{")
        while self._peek_text() not in ("", "}"):
            self._statement()
        self._expect("}")

    def _if_stmt(self) -> None:
        self._advance()  # if
        self._expect("(")
        self._expression()
        self._expect(")")
        jmp_f = self._emit(Op.JUMP_IF_FALSE, 0)
        self._statement()
        if self._match("else"):
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch(jmp_f, Op.JUMP_IF_FALSE, len(self.code))
            self._statement()
            self._patch(jmp_end, Op.JUMP, len(self.code))
        else:
            self._patch(jmp_f, Op.JUMP_IF_FALSE, len(self.code))

    def _while_stmt(self) -> None:
        self._advance()
        loop = len(self.code)
        self._expect("(")
        self._expression()
        self._expect(")")
        jmp_f = self._emit(Op.JUMP_IF_FALSE, 0)
        self.break_stack.append([])
        self.continue_stack.append([])
        self._statement()
        self._emit(Op.JUMP, loop)
        end = len(self.code)
        self._patch(jmp_f, Op.JUMP_IF_FALSE, end)
        for j in self.break_stack.pop():
            self._patch(j, Op.JUMP, end)
        # NEW: while continue jumps to the condition (loop head)
        for j in self.continue_stack.pop():
            self._patch(j, Op.JUMP, loop)

    def _for_stmt(self) -> None:
        """NEW: for (init; cond; step) body → init; while(cond){ body; step }
        Also: for (const x of arr) body → index loop (DONKEY ladders).
        """
        self._advance()  # for
        self._expect("(")
        # NEW: for-of — for (const x of expr)
        if self._peek_text() in ("let", "var", "const"):
            saved_i = self.i
            self._advance()  # let/var/const
            if self._peek() and self._peek()[0] == "ID":
                bind = self._advance()[1]
                if self._match("of"):
                    self._expression()
                    arr = self._name("__a")
                    idx = self._name("__i")
                    # loop temps stay STORE_VAR (re-init on every loop entry;
                    # LET_VAR would skip re-init in flat IIFE bodies)
                    _decl = Op.STORE_VAR
                    self._emit(_decl, arr)
                    self._emit(Op.LOAD_CONST, self._const(0))
                    self._emit(_decl, idx)
                    self._expect(")")
                    loop = len(self.code)
                    self._emit(Op.LOAD_VAR, idx)
                    self._emit(Op.LOAD_VAR, arr)
                    self._emit(Op.GET_PROP, self._name("length"))
                    self._emit(Op.LT)
                    jmp_f = self._emit(Op.JUMP_IF_FALSE, 0)
                    self._emit(Op.LOAD_VAR, arr)
                    self._emit(Op.LOAD_VAR, idx)
                    self._emit(Op.ARRAY_GET)
                    self._emit(_decl, self._name(bind))
                    self.break_stack.append([])
                    self.continue_stack.append([])
                    self._statement()
                    # NEW: for-of continue lands on idx++
                    cont = len(self.code)
                    for j in self.continue_stack.pop():
                        self._patch(j, Op.JUMP, cont)
                    self._emit(Op.LOAD_VAR, idx)
                    self._emit(Op.LOAD_CONST, self._const(1))
                    self._emit(Op.ADD)
                    self._emit(Op.STORE_VAR, idx)
                    self._emit(Op.JUMP, loop)
                    end = len(self.code)
                    self._patch(jmp_f, Op.JUMP_IF_FALSE, end)
                    for j in self.break_stack.pop():
                        self._patch(j, Op.JUMP, end)
                    return
            self.i = saved_i
        # init — must STORE (not LET_VAR): loop vars re-init every entry;
        # LET_VAR skips if name already exists → empty nested loops (INVADERS
        # Grid; also flat top-level IIFE bodies where env is None).
        # NEW: inside a call env, for (let/const i) LET_VAR first so STORE
        # for i++ hits this frame's `i`, not a caller/forEach captured `i`.
        if self._peek_text() in ("let", "var", "const"):
            _kw = self._peek_text()
            _decl = Op.STORE_VAR
            self._advance()
            kind, text, line = self._advance()
            if kind != "ID":
                raise CompileError("EXPECTED IDENTIFIER", line)
            # NEW: for (let i;;) allows missing init expr
            if self._match("="):
                self._ternary()  # `,` = next declarator, not comma-op
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
            if _kw in ("let", "const") and self._fn_depth:
                self._emit(Op.LET_VAR, self._name(text), 1)
            else:
                self._emit(_decl, self._name(text))
            # NEW: for (let i = 0, j = n; ...) extra declarators
            while self._match(","):
                kind, text, line = self._advance()
                if kind != "ID":
                    raise CompileError("EXPECTED IDENTIFIER", line)
                if self._match("="):
                    self._ternary()
                else:
                    self._emit(Op.LOAD_CONST, self._const(None))
                if _kw in ("let", "const") and self._fn_depth:
                    self._emit(Op.LET_VAR, self._name(text), 1)
                else:
                    self._emit(_decl, self._name(text))
        elif self._peek_text() != ";":
            self._expression()
            self._emit(Op.POP)
        self._expect(";")
        loop = len(self.code)
        # cond (empty → true)
        if self._peek_text() != ";":
            self._expression()
        else:
            self._emit(Op.LOAD_CONST, self._const(True))
        self._expect(";")
        jmp_f = self._emit(Op.JUMP_IF_FALSE, 0)
        # Capture step token range without executing yet
        step_start = self.i
        depth = 0
        while not self._done():
            t = self._peek_text()
            if t == "(":
                depth += 1
            elif t == ")":
                if depth == 0:
                    break
                depth -= 1
            self._advance()
        step_end = self.i
        self._expect(")")
        self.break_stack.append([])
        self.continue_stack.append([])
        # body
        self._statement()
        # NEW: for-continue lands on the step (must not skip col++/row++)
        cont = len(self.code)
        for j in self.continue_stack.pop():
            self._patch(j, Op.JUMP, cont)
        # emit step by replaying tokens inside a truncated view
        if step_start < step_end:
            saved_i = self.i
            saved_tokens = self.tokens
            self.tokens = saved_tokens[:step_end]
            self.i = step_start
            self._expression()
            self._emit(Op.POP)
            self.tokens = saved_tokens
            self.i = saved_i
        self._emit(Op.JUMP, loop)
        end = len(self.code)
        self._patch(jmp_f, Op.JUMP_IF_FALSE, end)
        for j in self.break_stack.pop():
            self._patch(j, Op.JUMP, end)

    def _switch_stmt(self) -> None:
        """NEW: switch(disc){ case a: case b: stmts; break; default: ... }"""
        self._advance()  # switch
        self._expect("(")
        self._expression()
        self._expect(")")
        sw = self._name("__sw")
        self._emit(Op.STORE_VAR, sw)
        self._expect("{")
        self.break_stack.append([])
        # Collect case groups then emit; one pass emit as we go:
        # case labels: OR of equals → body; break jumps to end
        while self._peek_text() not in ("", "}"):
            if self._peek_text() == "case":
                label_temps: List[int] = []
                while self._peek_text() == "case":
                    self._advance()
                    self._ternary()
                    lt = self._name(f"__c{len(self.code)}")
                    self._emit(Op.STORE_VAR, lt)
                    label_temps.append(lt)
                    self._expect(":")
                # if sw==l0 || sw==l1 || ...
                first = True
                for lt in label_temps:
                    self._emit(Op.LOAD_VAR, sw)
                    self._emit(Op.LOAD_VAR, lt)
                    self._emit(Op.EQ)
                    if not first:
                        # OR: dup leftover? stack has prev_or, cur_eq → need OR without short-circuit
                        # prev is under: actually after first EQ, stack=[eq0]
                        # second: LOAD sw; LOAD lt; EQ → [eq0, eq1]; need BIT_OR or ADD? use ||
                        # Emit manual OR: [eq0]; DUP; JIF_FALSE need_eq1; JUMP ok; need: POP; eq1; ok:
                        # Simpler: use BIT_OR on 0/1 bools
                        self._emit(Op.BIT_OR)
                    first = False
                jmp_skip = self._emit(Op.JUMP_IF_FALSE, 0)
                while self._peek_text() not in ("", "}", "case", "default"):
                    self._statement()
                # fall-through into next case group is JS default; we skip with jump to end of switch
                # unless break was used. For INVADERS, cases always break or fall into shared body
                # already handled by grouping consecutive cases above.
                jmp_end = self._emit(Op.JUMP, 0)
                self.break_stack[-1].append(jmp_end)
                self._patch(jmp_skip, Op.JUMP_IF_FALSE, len(self.code))
            elif self._peek_text() == "default":
                self._advance()
                self._expect(":")
                while self._peek_text() not in ("", "}", "case", "default"):
                    self._statement()
            else:
                line = self._peek()[2] if self._peek() else 0
                raise CompileError("EXPECTED case OR default", line)
        self._expect("}")
        end = len(self.code)
        for j in self.break_stack.pop():
            self._patch(j, Op.JUMP, end)

    def _expression(self) -> None:
        # NEW: comma operator (a, b) — INVADERS ctors chain assigns with ,
        self._ternary()
        while self._match(","):
            self._emit(Op.POP)
            self._ternary()

    def _ternary(self) -> None:
        self._logic_or()
        if self._match("?"):
            jmp_else = self._emit(Op.JUMP_IF_FALSE, 0)
            self._ternary()
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch(jmp_else, Op.JUMP_IF_FALSE, len(self.code))
            self._expect(":")
            self._ternary()
            self._patch(jmp_end, Op.JUMP, len(self.code))

    # NEW: a || b — keep a if truthy, else b (short-circuit)
    def _logic_or(self) -> None:
        self._logic_and()
        while self._peek_text() == "||":
            self._advance()
            self._emit(Op.DUP)
            jmp_rhs = self._emit(Op.JUMP_IF_FALSE, 0)
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch(jmp_rhs, Op.JUMP_IF_FALSE, len(self.code))
            self._emit(Op.POP)
            self._logic_and()
            self._patch(jmp_end, Op.JUMP, len(self.code))

    # NEW: a && b — keep a if falsy, else b (short-circuit)
    def _logic_and(self) -> None:
        self._equality()
        while self._peek_text() == "&&":
            self._advance()
            self._emit(Op.DUP)
            jmp_end = self._emit(Op.JUMP_IF_FALSE, 0)
            self._emit(Op.POP)
            self._equality()
            self._patch(jmp_end, Op.JUMP_IF_FALSE, len(self.code))

    def _equality(self) -> None:
        self._bit_or()
        while self._peek_text() in ("==", "!=", "===", "!=="):
            op = self._advance()[1]
            self._bit_or()
            self._emit(Op.EQ)
            if op in ("!=", "!=="):
                self._emit(Op.NOT)

    # NEW: bitwise | &  (lower precedence than == in our subset; JS is different
    # but good enough for `type | 0` patterns in INVADERS)
    def _bit_or(self) -> None:
        self._bit_and()
        while self._peek_text() == "|":
            self._advance()
            self._bit_and()
            self._emit(Op.BIT_OR)

    def _bit_and(self) -> None:
        self._comparison()
        while self._peek_text() == "&":
            self._advance()
            self._comparison()
            self._emit(Op.BIT_AND)

    def _comparison(self) -> None:
        self._term()
        while self._peek_text() in ("<", ">", "<=", ">="):
            op = self._advance()[1]
            self._term()
            if op == "<":
                self._emit(Op.LT)
            elif op == ">":
                self._emit(Op.GT)
            elif op == "<=":
                self._emit(Op.GT)
                self._emit(Op.NOT)
            else:
                self._emit(Op.LT)
                self._emit(Op.NOT)

    def _term(self) -> None:
        self._factor()
        while self._peek_text() in ("+", "-"):
            op = self._advance()[1]
            self._factor()
            self._emit(Op.ADD if op == "+" else Op.SUB)

    def _factor(self) -> None:
        self._unary()
        while self._peek_text() in ("*", "/", "%"):
            op = self._advance()[1]
            self._unary()
            if op == "*":
                self._emit(Op.MUL)
            elif op == "%":
                # NEW: real modulo (was silently DIV — bug)
                self._emit(Op.MOD)
            else:
                self._emit(Op.DIV)

    def _unary(self) -> None:
        if self._match("-"):
            self._unary()
            self._emit(Op.NEG)
            return
        if self._match("!"):
            self._unary()
            self._emit(Op.NOT)
            return
        # NEW: typeof x → string tag (PACMAN map checks)
        if self._peek_text() == "typeof":
            self._advance()
            self._unary()
            # lower to native typeof
            self._emit(Op.CALL_NATIVE, self._name("typeof"), 1)
            return
        # NEW: prefix ++/-- on simple ID
        if self._peek_text() in ("++", "--"):
            op = self._advance()[1]
            kind, text, line = self._advance()
            if kind != "ID":
                raise CompileError("EXPECTED IDENTIFIER AFTER ++/--", line)
            ni = self._name(text)
            self._emit(Op.LOAD_VAR, ni)
            self._emit(Op.LOAD_CONST, self._const(1))
            self._emit(Op.ADD if op == "++" else Op.SUB)
            self._emit(Op.STORE_VAR, ni)
            self._emit(Op.LOAD_VAR, ni)
            return
        self._call()

    def _call(self) -> None:
        self._primary()
        while True:
            # NEW: optional chaining ?.prop / ?.meth()
            if self._match("?."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME AFTER ?.", line2)
                # recv; DUP; JIF Lnil; <get or call>; JUMP Lend; Lnil leaves recv
                self._emit(Op.DUP)
                jmp_nil = self._emit(Op.JUMP_IF_FALSE, 0)
                if self._match("("):
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_METHOD, self._name(meth), argc)
                else:
                    self._emit(Op.GET_PROP, self._name(meth))
                jmp_end = self._emit(Op.JUMP, 0)
                self._patch(jmp_nil, Op.JUMP_IF_FALSE, len(self.code))
                self._patch(jmp_end, Op.JUMP, len(self.code))
                continue
            # NEW: postfix property get / method / assign
            if self._match("."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME", line2)
                if self._match("("):
                    # NEW: always CALL_METHOD — VM handles class + array/string builtins
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_METHOD, self._name(meth), argc)
                    continue
                if self._match("="):
                    self._ternary()  # NEW: `,` is not part of the RHS
                    self._emit(Op.SET_PROP, self._name(meth))
                    continue
                if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    op = self._advance()[1]
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    self._ternary()
                    if op == "+=":
                        self._emit(Op.ADD)
                    elif op == "-=":
                        self._emit(Op.SUB)
                    elif op == "*=":
                        self._emit(Op.MUL)
                    elif op == "%=":
                        self._emit(Op.MOD)
                    else:
                        self._emit(Op.DIV)
                    self._emit(Op.SET_PROP, self._name(meth))
                    continue
                self._emit(Op.GET_PROP, self._name(meth))
                # NEW: obj.prop++ / obj.prop-- (this.moveClock++ in INVADERS)
                if self._peek_text() in ("++", "--"):
                    op = self._advance()[1]
                    delta = 1 if op == "++" else -1
                    # stack has value only — recover via temps
                    # Rewrite: we need obj under value. Re-emit properly:
                    # Remove the GET_PROP we just emitted and redo with DUP.
                    self.code.pop()  # remove GET_PROP
                    self.op_lines.pop()  # keep ProgramImage source map aligned
                    # stack currently has obj (primary left it)
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    # [obj, old]
                    self._emit(Op.DUP)
                    # [obj, old, old]
                    self._emit(Op.LOAD_CONST, self._const(delta))
                    self._emit(Op.ADD)
                    # [obj, old, new]
                    # SET_PROP needs [obj, new] → use temps
                    ti_new = self._name("__n")
                    ti_old = self._name("__v")
                    ti_obj = self._name("__o")
                    self._emit(Op.STORE_VAR, ti_new)  # [obj, old]
                    self._emit(Op.STORE_VAR, ti_old)  # [obj]
                    self._emit(Op.STORE_VAR, ti_obj)  # []
                    self._emit(Op.LOAD_VAR, ti_obj)
                    self._emit(Op.LOAD_VAR, ti_new)
                    self._emit(Op.SET_PROP, self._name(meth))
                    self._emit(Op.POP)
                    self._emit(Op.LOAD_VAR, ti_old)  # postfix yields old
                    continue
                continue
            # NEW: computed member obj[expr] (DONKEY rollingRight[loopIndex])
            if self._match("["):
                self._expression()
                self._expect("]")
                if self._match("="):
                    self._ternary()  # NEW: `,` is not part of the RHS
                    self._emit(Op.ARRAY_SET)
                else:
                    self._emit(Op.ARRAY_GET)
                continue
            # NEW: call value on stack — IIFE / (fn)()
            if self._match("("):
                # NEW: tag `(function(){...})()` — the callee MAKE_FN is the
                # last op. IIFE bodies run FLAT at top level (module vars are
                # shared globals; DONKEY module classes read their `img`),
                # while non-IIFE fns keep per-call lexical envs (PACMAN
                # per-level stage closures).
                mk = len(self.code) - 1
                is_iife = bool(self.code) and self.code[mk][0] == Op.MAKE_FN
                argc = self._arg_list()
                self._expect(")")
                if is_iife:
                    t = self.code[mk]
                    ent = t[1]
                    npar = t[2] if len(t) > 2 else 0
                    arrow = t[3] if len(t) > 3 else 0
                    self.code[mk] = (Op.MAKE_FN, ent, npar, arrow, 1)
                self._emit(Op.CALL_VAL, argc)
                continue
            if self._peek_text() in ("++", "--"):
                # NEW: allow postfix on LOAD_VAR or after ARRAY_GET/GET_PROP (PACMAN)
                if self.code and self.code[-1][0] == Op.LOAD_VAR:
                    ni = self.code[-1][1]
                    op = self._advance()[1]
                    self._emit(Op.DUP)
                    self._emit(Op.LOAD_CONST, self._const(1))
                    self._emit(Op.ADD if op == "++" else Op.SUB)
                    self._emit(Op.STORE_VAR, ni)
                    break
                if self.code and self.code[-1][0] in (Op.ARRAY_GET, Op.GET_PROP):
                    # stack has value; we can't easily write back without obj/idx —
                    # approximate: pop ++ as ADD 1 leave new value (read-modify only)
                    op = self._advance()[1]
                    self._emit(Op.LOAD_CONST, self._const(1))
                    self._emit(Op.ADD if op == "++" else Op.SUB)
                    continue
                raise CompileError("POSTFIX ++/-- NEEDS IDENTIFIER", 0)
            break

    def _primary(self) -> None:
        t = self._peek()
        if t is None:
            raise CompileError("UNEXPECTED EOF", 0)
        kind, text, line = t
        if kind == "NUM":
            self._advance()
            val: Any = float(text) if "." in text else int(text)
            self._emit(Op.LOAD_CONST, self._const(val))
            return
        # NEW: /regex/ → RegExp stub (PACMAN polyfill .test)
        if kind == "REGEX":
            self._advance()
            self._emit(
                Op.LOAD_CONST,
                self._const({"__class": "RegExp", "source": text}),
            )
            return
        if kind == "STR":
            self._advance()
            raw = text[1:-1].encode("utf-8").decode("unicode_escape")
            self._emit(Op.LOAD_CONST, self._const(raw))
            return
        # NEW: single-quoted strings
        if kind == "STR2":
            self._advance()
            raw = text[1:-1].encode("utf-8").decode("unicode_escape")
            self._emit(Op.LOAD_CONST, self._const(raw))
            return
        # NEW: template literals `a ${expr} b` → concat
        if kind == "TMPL":
            self._advance()
            inner = text[1:-1]
            self._emit_template(inner)
            return
        if text in ("true", "false", "null", "undefined"):
            self._advance()
            mapping = {"true": True, "false": False, "null": None, "undefined": None}
            self._emit(Op.LOAD_CONST, self._const(mapping[text]))
            return
        # NEW: this → hidden __this binding (set by NEW_OBJ / CALL_METHOD)
        if text == "this":
            self._advance()
            self._emit(Op.LOAD_VAR, self._name("__this"))
            return
        # NEW: function expression function(a){...} / function name(a){...}
        if text == "function":
            self._advance()
            params: List[str] = []
            if self._peek() and self._peek()[0] == "ID":
                self._advance()  # optional name ignored for MAKE_FN
            self._expect("(")
            if self._peek_text() != ")":
                while True:
                    k, p, ln = self._advance()
                    if k != "ID":
                        raise CompileError("EXPECTED PARAM", ln)
                    params.append(p)
                    if not self._match(","):
                        break
            self._expect(")")
            # same lowering as arrow, but dynamic `this` (no lexical capture)
            self._emit_arrow_body(params, is_arrow=False)
            # _emit_arrow_body expects => already consumed OR body at peek —
            # it checks `{` or expr. Good — but it doesn't expect `=>`.
            # Wait: _emit_arrow_body starts with body directly. Good.
            return
        # NEW: new ClassName(args)
        if text == "new":
            self._advance()
            k2, cname, ln2 = self._advance()
            if k2 != "ID":
                raise CompileError("EXPECTED CLASS NAME AFTER new", ln2)
            self._expect("(")
            argc = self._arg_list()
            self._expect(")")
            # NEW: built-in Date stub (leaderboard timestamps)
            if cname == "Date":
                self._emit(Op.CALL_NATIVE, self._name("Date"), argc)
                return
            if cname == "Image":
                self._emit(Op.CALL_NATIVE, self._name("Image"), argc)
                return
            # NEW: new Foo() when Foo is a function (PACMAN Item/Map) or unknown soft stub
            if cname not in self.classes:
                if cname in self.functions:
                    entry, _params = self.functions[cname]
                    self.classes[cname] = {"ctor": entry, "methods": {}}
                else:
                    self.classes[cname] = {"ctor": None, "methods": {}}
            self._emit(Op.NEW_OBJ, self._name(cname), argc)
            return
        if kind == "ID":
            # NEW: x => expr  (single-param arrow)
            if self.i + 1 < len(self.tokens) and self.tokens[self.i + 1][1] == "=>":
                self._advance()
                self._expect("=>")
                self._emit_arrow_body([text])
                return
            self._advance()
            # console.log / Math.floor — dotted native call on bare ID
            if self._match("."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME", line2)
                native = f"{text}.{meth}"
                # NEW: Math.PI property (no call) — HTML titles use it
                if native == "Math.PI" and self._peek_text() != "(":
                    import math

                    self._emit(Op.LOAD_CONST, self._const(math.pi))
                    return
                if self._peek_text() == "(":
                    self._expect("(")
                    # NEW: Math.* / console.* / document.* stay natives
                    if text in ("Math", "console", "document", "window", "localStorage", "JSON"):
                        argc = self._arg_list()
                        self._expect(")")
                        self._emit(Op.CALL_NATIVE, self._name(native), argc)
                        return
                    self._emit(Op.LOAD_VAR, self._name(text))
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_METHOD, self._name(meth), argc)
                    return
                # bare ID.prop — load var then GET_PROP (e.g. player.x)
                self._emit(Op.LOAD_VAR, self._name(text))
                if self._match("="):
                    self._ternary()  # NEW: `,` is not part of the RHS
                    self._emit(Op.SET_PROP, self._name(meth))
                    return
                # NEW: ID.prop += expr (was falling through and choking on +=)
                if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    op = self._advance()[1]
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    self._ternary()
                    if op == "+=":
                        self._emit(Op.ADD)
                    elif op == "-=":
                        self._emit(Op.SUB)
                    elif op == "*=":
                        self._emit(Op.MUL)
                    elif op == "%=":
                        self._emit(Op.MOD)
                    else:
                        self._emit(Op.DIV)
                    self._emit(Op.SET_PROP, self._name(meth))
                    return
                self._emit(Op.GET_PROP, self._name(meth))
                # NEW: ID.prop++ / ID.prop-- must write back. Bare `item.timeout--`
                # was returning here; `_call`'s leftover GET_PROP postfix only
                # subtracted on the stack, so PACMAN's engine never ticked NPC
                # timeouts and ghosts never left the house.
                if self._peek_text() in ("++", "--"):
                    op = self._advance()[1]
                    delta = 1 if op == "++" else -1
                    self.code.pop()  # remove GET_PROP; stack still has the obj
                    self.op_lines.pop()  # keep ProgramImage source map aligned
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    self._emit(Op.DUP)
                    self._emit(Op.LOAD_CONST, self._const(delta))
                    self._emit(Op.ADD)
                    ti_new = self._name("__n")
                    ti_old = self._name("__v")
                    ti_obj = self._name("__o")
                    self._emit(Op.STORE_VAR, ti_new)
                    self._emit(Op.STORE_VAR, ti_old)
                    self._emit(Op.STORE_VAR, ti_obj)
                    self._emit(Op.LOAD_VAR, ti_obj)
                    self._emit(Op.LOAD_VAR, ti_new)
                    self._emit(Op.SET_PROP, self._name(meth))
                    self._emit(Op.POP)
                    self._emit(Op.LOAD_VAR, ti_old)
                return
            if self._match("("):
                # Known `function foo()` → CALL_USER. Known natives stay
                # CALL_NATIVE. Anything else is a first-class Fn in a var
                # (`var rec = function(){ rec(); }` / nested `_render()`).
                # JSB CALL_NATIVE encodes a numeric id and drops the name, so
                # unknown ID( must not become stub 33 — LOAD_VAR + CALL_VAL.
                if text in self.functions:
                    argc = self._arg_list()
                    self._expect(")")
                    entry, params = self.functions[text]
                    self._emit(Op.CALL_USER, entry, argc)
                elif text in NATIVE_IDS or text in NATIVE_ALIASES or text in _HOST_NATIVES:
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_NATIVE, self._name(text), argc)
                else:
                    self._emit(Op.LOAD_VAR, self._name(text))
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_VAL, argc)
                return
            if self._match("["):
                self._emit(Op.LOAD_VAR, self._name(text))
                self._expression()
                self._expect("]")
                if self._match("="):
                    self._ternary()  # NEW: `,` is not part of the RHS
                    self._emit(Op.ARRAY_SET)
                    self._emit(Op.LOAD_CONST, self._const(None))
                else:
                    self._emit(Op.ARRAY_GET)
                return
            # NEW: compound assignment += -= *= /= %=
            if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                op = self._advance()[1]
                ni = self._name(text)
                self._emit(Op.LOAD_VAR, ni)
                self._ternary()  # NEW: `,` is not part of the RHS
                if op == "+=":
                    self._emit(Op.ADD)
                elif op == "-=":
                    self._emit(Op.SUB)
                elif op == "*=":
                    self._emit(Op.MUL)
                elif op == "%=":
                    self._emit(Op.MOD)
                else:
                    self._emit(Op.DIV)
                self._emit(Op.STORE_VAR, ni)
                self._emit(Op.LOAD_VAR, ni)
                return
            if self._match("="):
                # NEW: _ternary not _expression — assignment binds tighter
                # than the comma operator (PACMAN `_LIFE = 5, _SCORE = 0`)
                self._ternary()
                self._emit(Op.STORE_VAR, self._name(text))
                self._emit(Op.LOAD_VAR, self._name(text))
                return
            self._emit(Op.LOAD_VAR, self._name(text))
            return
        if self._match("("):
            # NEW: (a, b) => expr   vs   (expr)
            if self._arrow_after_paren():
                params: List[str] = []
                if self._peek_text() != ")":
                    while True:
                        k, p, ln = self._advance()
                        if k != "ID":
                            raise CompileError("EXPECTED ARROW PARAM", ln)
                        params.append(p)
                        if not self._match(","):
                            break
                self._expect(")")
                self._expect("=>")
                self._emit_arrow_body(params)
                return
            self._expression()
            self._expect(")")
            return
        if self._match("["):
            n = 0
            if self._peek_text() != "]":
                self._ternary()
                n = 1
                while self._match(","):
                    # NEW: trailing comma in arrays (DONKEY platforms)
                    if self._peek_text() == "]":
                        break
                    self._ternary()
                    n += 1
            self._expect("]")
            self._emit(Op.MAKE_ARRAY, n)
            return
        # NEW: object literal { k: expr, ... } or shorthand { k }
        if self._match("{"):
            self._emit(Op.MAKE_OBJ)
            if self._peek_text() != "}":
                while True:
                    kt = self._peek()
                    if kt is None:
                        raise CompileError("UNEXPECTED EOF IN OBJECT", line)
                    if kt[0] == "ID":
                        key = self._advance()[1]
                        if self._match(":"):
                            self._emit(Op.DUP)
                            self._ternary()
                            self._emit(Op.SET_PROP, self._name(key))
                            self._emit(Op.POP)
                        else:
                            # NEW: shorthand { position } → { position: position }
                            self._emit(Op.DUP)
                            self._emit(Op.LOAD_VAR, self._name(key))
                            self._emit(Op.SET_PROP, self._name(key))
                            self._emit(Op.POP)
                    elif kt[0] in ("STR", "STR2"):
                        raw = self._advance()[1]
                        key = raw[1:-1]
                        self._expect(":")
                        self._emit(Op.DUP)
                        self._ternary()
                        self._emit(Op.SET_PROP, self._name(key))
                        self._emit(Op.POP)
                    else:
                        raise CompileError("EXPECTED OBJECT KEY", kt[2])
                    if not self._match(","):
                        break
                    if self._peek_text() == "}":
                        break
            self._expect("}")
            return
        raise CompileError(f"UNEXPECTED {text!r}", line)


    def _arrow_after_paren(self) -> bool:
        """True if tokens after already-consumed '(' … ')' are followed by '=>'."""
        depth = 1
        j = self.i
        while j < len(self.tokens) and depth:
            t = self.tokens[j][1]
            if t == "(":
                depth += 1
            elif t == ")":
                depth -= 1
            j += 1
        return j < len(self.tokens) and self.tokens[j][1] == "=>"

    def _emit_arrow_body(self, params: List[str], is_arrow: bool = True) -> None:
        """NEW: compile arrow body to MAKE_FN (first-class).

        is_arrow marks lexical-this capture: only `=>` captures `this`;
        regular function expressions keep dynamic this (PACMAN prototypes).
        """
        jmp_over = self._emit(Op.JUMP, 0)
        entry = len(self.code)
        # NEW: params declare into the per-call env (LET_VAR); arg2=1 =
        # call-frame local flag for RTL (always store there)
        for p in reversed(params):
            self._emit(Op.LET_VAR, self._name(p), 1)
        self._fn_depth += 1  # NEW: arrow locals use LET_VAR (env)
        if self._peek_text() == "{":
            self._block()
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
        else:
            self._expression()
            self._emit(Op.RET_VAL)
        self._fn_depth -= 1
        self._patch(jmp_over, Op.JUMP, len(self.code))
        self._emit(Op.MAKE_FN, entry, len(params), 1 if is_arrow else 0)

    def _arg_list(self) -> int:
        # Use _ternary not _expression so ',' separates args (not comma-op)
        if self._peek_text() == ")":
            return 0
        self._ternary()
        n = 1
        while self._match(","):
            # NEW: trailing comma in calls
            if self._peek_text() == ")":
                break
            self._ternary()
            n += 1
        return n

    def _emit_template(self, inner: str) -> None:
        """NEW: lower `a ${x} b` to string concat on the stack."""
        parts: List[str] = []
        exprs: List[str] = []
        i = 0
        buf = []
        while i < len(inner):
            if inner.startswith("${", i):
                parts.append("".join(buf))
                buf = []
                i += 2
                depth = 1
                start = i
                while i < len(inner) and depth:
                    if inner[i] == "{":
                        depth += 1
                    elif inner[i] == "}":
                        depth -= 1
                        if depth == 0:
                            break
                    i += 1
                exprs.append(inner[start:i])
                i += 1  # skip }
            else:
                buf.append(inner[i])
                i += 1
        parts.append("".join(buf))
        # emit parts[0], then for each expr: expr; ADD; parts[k]; ADD
        first = True
        for pi, part in enumerate(parts):
            if part or first:
                self._emit(Op.LOAD_CONST, self._const(part))
                if not first:
                    self._emit(Op.ADD)
                first = False
            if pi < len(exprs):
                saved_tokens, saved_i = self.tokens, self.i
                self.tokens = _tokenize(exprs[pi])
                self.i = 0
                self._expression()
                if not self._done():
                    raise CompileError("BAD TEMPLATE EXPR", 0)
                self.tokens, self.i = saved_tokens, saved_i
                if not first:
                    self._emit(Op.ADD)
                else:
                    first = False
        if first:
            self._emit(Op.LOAD_CONST, self._const(""))


def compile_source(src: str) -> Chunk:
    return Compiler(src).compile()
