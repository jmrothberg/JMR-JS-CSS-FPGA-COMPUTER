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


def _num_value(text: str):
    """Value of a NUM token: decimal, or 0x / 0b / 0o integer literals."""
    if len(text) > 2 and text[0] == "0" and text[1] in "xXbBoO":
        return int(text[2:], {"x": 16, "b": 2, "o": 8}[text[1].lower()])
    return float(text) if any(c in text for c in ".eE") else int(text)


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
    (?P<NUM>0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?) |
    (?P<ID>[A-Za-z_$][A-Za-z0-9_$]*) |
    (?P<OP>\+\+|--|=>|\?\.|\?|===|!==|==|!=|<=|>=|&&|\|\||[+\-*/%]=|[+\-*/%<>=!();:{},.\[\]|&])
    """,
    re.VERBOSE | re.DOTALL,
)


def _tokenize(src: str) -> List[Tuple[str, str, int]]:
    tokens: List[Tuple[str, str, int]] = []
    line = 1
    pos = 0
    # After these, `/.../` is a regex literal (PACMAN rAF polyfill)
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
        # Regex literal before OP `/` when prior token allows
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



# V1 AUTHORING WALL: names whose silicon arms do not exist in
# the V1.0 chip (or were removed by the V1-surface cut). Verified zero hits
# across every playable title (INVADERS, PACMAN, DONKEY, ASTEROID, MRDO,
# MKPVP + AURORA/JOYDEMO/PACDBG). A program referencing one of these fails
# HERE, loudly, instead of faulting on hardware. V1.5 lifts popular
# language on this list; V2 is MK (dotted new / .call / Object.keys RTL).
V1_WALL_NAMES = frozenset([
    "sin", "cos", "atan2", "pow", "hypot",   # Ceil is native 57
    "match", "exec", "toFixed", "toString", "String",
    "concat", "reverse", "shift",
    "padStart", "padEnd", "repeat",
    "findIndex", "some", "every", "values", "entries",
])

# String operations library (functional_model/strops_runtime.js, STROPS.JS on
# the card). A call `x.m(...)` with m below and at most that many arguments
# becomes `_jmr_sop_m(x, ...)`, which runs the string version when x is a
# string and x.m(...) otherwise. Library code itself is never rewritten.
SOP_METHODS = {
    "indexOf": 2, "includes": 2, "lastIndexOf": 2, "slice": 2, "substr": 2,
    "substring": 2, "trim": 0, "replace": 2, "join": 1, "charAt": 1,
    "charCodeAt": 1, "startsWith": 2, "endsWith": 2, "toUpperCase": 0,
    "toLowerCase": 0, "split": 2, "localeCompare": 1,
}
SOP_CALLS = ("parseInt", "parseFloat", "Number")
SOP_DOTTED = {"Math.trunc": "trunc", "Math.sign": "sign", "Number.isInteger": "isInteger"}
_LIBRARY_PREFIXES = ("_jmr_json_", "_jmr_store_", "_jmr_sop_")


def sop_needs(tokens) -> Tuple[bool, bool]:
    """(library needed, join used): the token rule both compilers share."""
    need = join = False
    for i in range(len(tokens) - 2):
        a, b, c = tokens[i][1], tokens[i + 1][1], tokens[i + 2][1]
        if a in (".", "?.") and b in SOP_METHODS and c == "(":
            need = True
            join = join or b == "join"
        elif b == "(" and a in SOP_CALLS and (i == 0 or tokens[i - 1][1] not in (".", "?.")):
            need = True
        elif b == "." and f"{a}.{c}" in SOP_DOTTED and i + 3 < len(tokens) and tokens[i + 3][1] == "(":
            need = True
    return need, join

# V1 WALL EXTENSION: candidate
# silicon removals sized on a post-opt netlist. Per-arm LUTs:
# JSON engine 18,795 (REMOVAL-WORTHY); HOF find/filter/reduce/map 1,053,
# bind 601, regex replace/test 126, sort ~0 (NOT worth removing — kept).
# The extension stays off until the replacement titles (PACMAN2.HTML
# etc.) land and pass byte-identical framebuffer checks; the six current
# titles MUST keep compiling until then. Enable with JMR_V1_WALL_EXT=1
# (or =json for the JSON-only recommended line).
import os as _os

def _wall_ext_names() -> frozenset:
    # JSON wall is LIVE BY DEFAULT — the gate passed
    # (PACMAN2/INVADERS2 byte-identical, now shipping under the original
    # filenames; originals in storage/*.V2ORIG). JMR_V1_ALLOW_JSON=1 is
    # the archival escape for compiling the .V2ORIG titles.
    json_only = frozenset(["parse", "stringify"])
    if _os.environ.get("JMR_V1_ALLOW_JSON", ""):
        json_only = frozenset()
    v = _os.environ.get("JMR_V1_WALL_EXT", "")
    if v == "1":
        return json_only | frozenset(
            ["find", "filter", "reduce", "map", "sort", "bind",
             "replace", "test"])
    return json_only

class Compiler:
    def __init__(self, src: str) -> None:
        self.tokens = _isolate_iife_modules(_tokenize(src))
        self._getter_call_names = {self.tokens[k+1][1] for k in range(len(self.tokens)-2)
            if self.tokens[k][0]=='ID' and self.tokens[k][1]=='get' and self.tokens[k+1][0]=='ID' and self.tokens[k+2][1]=='('}
        self.i = 0
        self.consts: List[Any] = []
        self._null_consts = set()
        self.names: List[str] = []
        self.name_index: dict[str, int] = {}
        self.code: List[Tuple] = []
        # HTML line per emitted op (monitor follows bytecode → source)
        self.op_lines: List[int] = []
        # User functions name → (entry_ip, params)
        self.functions: dict[str, Tuple[int, List[str]]] = {}
        # Hoisted `function foo` names for LOAD_VAR a1=1. Do not plant
        # functions[foo]=(0,[]) — class methods compile before bodies and
        # CALL_USER 0 re-enters IP 0 (INVADERS star-loop / DONKEY new Game).
        self._hoisted_fn_names: set[str] = set()
        # Fname → IP after the function's last op (before MAKE_FN).
        # Used to inline tiny param-only callees at CALL_USER sites.
        self._fn_end: dict[str, int] = {}
        self._fn_compiling: Optional[str] = None
        # Classes + set of all method names (for CALL_METHOD dispatch)
        self.classes: dict[str, dict] = {}
        self.all_methods: set[str] = set()
        # Break patch lists for switch (and later loops)
        self.break_stack: List[List[int]] = []
        # Continue patch lists for for/while (bunker arch `continue`)
        self.continue_stack: List[List[int]] = []
        # >0 inside function/method/arrow → let/const must STORE (not LET_VAR).
        # Top-level keeps LET_VAR for startLoop re-entry (DONKEY.JS inited etc.).
        self._fn_depth = 0
        self._flat_module_frames = set()
        # Per-function local name → env slot 0..15 for LOAD_VAR/STORE_VAR a1.
        self._local_stack: List[dict[str, int]] = []
        # >0 inside while/for body. `var row = []` in a loop must STORE;
        # LET_VAR skips if the name exists, so every row aliases one array.
        self._loop_depth = 0
        # Uncapped shadow sets, one per enclosing function scope (the
        # 16-entry _local_stack maps drop overflow names, so they cannot
        # answer "does ANY enclosing scope declare X"). Env chains are
        # lexical: a site whose name is declared by NO enclosing function
        # scope can only ever resolve to vvars — patched to a1=1 at the
        # end of compile() (see _global_sites).
        self._scope_sets: List[set] = []
        self._global_sites: List[Tuple[int, str, tuple]] = []
        self._standard_global_bindings: set[str] = set()
        self._string_call_sites = []
        self._runtime_probe = False
        self._require_concat_helper = False
        self._needs_string_runtime = False
        self._storage_call_sites = []
        self._needs_storage_runtime = False
        # Metadata only. Resident-v2 serialization may reuse lexical leaf
        # slots without changing ordinary bytecode or captured outer names.
        self._local_serial = 0
        self._local_marks = []
        self._compact_leaf_ips = set()
        self._compact_leaf_ranges = []
        # Statement-value and condition-jump shortening, for applications and
        # the resident Toolbox bank alike.
        self.optimize = True
        # Functions with more than ENV_SLOTS (16) locals. The first pass lets
        # a frame grow past 16 and records it; compile() then reruns with a
        # plan that keeps the 16 most used names in the function's own
        # environment and the rest in enclosing wrapper environments.
        self._frame_info: List[dict] = []
        self._local_plans: dict = {}
        self._overflows: dict = {}

    def compile(self) -> Chunk:
        saved = {k: (list(v) if isinstance(v, list) else dict(v) if isinstance(v, dict)
                     else set(v) if isinstance(v, set) else v)
                 for k, v in self.__dict__.items()}
        chunk = self._compile_pass()
        if not self._overflows:
            return chunk
        plans = {key: self._overflow_plan(info) for key, info in self._overflows.items()}
        self.__dict__.clear()
        self.__dict__.update({k: (list(v) if isinstance(v, list) else dict(v) if isinstance(v, dict)
                                  else set(v) if isinstance(v, set) else v)
                              for k, v in saved.items()})
        self._local_plans = plans
        return self._compile_pass()

    @staticmethod
    def _overflow_plan(info: dict):
        """Split one frame's names: 16 most used stay, the rest go outward."""
        names = info["names"]
        prologue = info["prologue"]
        count = info["count"]
        order = {name: k for k, name in enumerate(names)}
        ranked = sorted(names, key=lambda n: (-count.get(n, 0), order[n]))
        inner = ranked[:16]
        inner_params = [p for p in prologue if p in inner]
        rest = [n for n in ranked[16:] if n not in prologue]
        room = max(0, 16 - len(prologue))
        middle = []
        while len(rest) > room:
            middle.append(rest[:16])
            rest = rest[16:]
        levels = [rest] + middle[::-1]
        return levels, inner_params, frozenset(names) - frozenset(inner)

    def _begin_body(self) -> None:
        """Start a function body; apply this frame's overflow plan if it has one."""
        info = self._frame_info[-1]
        cur = self._local_stack[-1]
        line = self.tokens[self.i][2] if self.i < len(self.tokens) else 0
        info["key"] = (self.i, line)
        info["prologue"] = list(cur)
        info["start"] = len(self.code)
        plan = self._local_plans.get(info["key"])
        if plan is None:
            return
        levels, inner_params, outer = plan
        for k, names in enumerate(levels):
            for name in names:
                self._emit(Op.LOAD_CONST, self._const(None))
                self._emit(Op.LET_VAR, self._name(name), 1)
            last = k == len(levels) - 1
            make = self._emit(Op.MAKE_FN, 0, 0, 1)
            if last:
                for p in inner_params:
                    self._emit(Op.LOAD_VAR, self._name(p))
            self._emit(Op.CALL_VAL, len(inner_params) if last else 0)
            self._emit(Op.RET_VAL)
            self._patch(make, Op.MAKE_FN, len(self.code),
                        len(inner_params) if last else 0, 1)
            self._enter_local_frame()
        for p in reversed(inner_params):
            self._emit(Op.LET_VAR, self._name(p), 1)
        self._frame_info[-1].update(outer=outer, levels=len(levels))

    def _end_body(self) -> None:
        """Leave the wrapper frames of a planned body, or record an overflow."""
        info = self._frame_info[-1]
        for _ in range(info.get("levels", 0)):
            self._leave_local_frame()
        info = self._frame_info[-1]
        cur = self._local_stack[-1]
        if len(cur) <= 16 or "key" not in info:
            return
        count: dict = {}
        index = {self.name_index[n]: n for n in cur if n in self.name_index}
        for op in self.code[info["start"]:]:
            if op[0] in (Op.LOAD_VAR, Op.STORE_VAR, Op.LET_VAR) and op[1] in index:
                name = index[op[1]]
                count[name] = count.get(name, 0) + 1
        self._overflows[info["key"]] = dict(
            names=list(cur), prologue=info["prologue"], count=count)

    def _compile_pass(self) -> Chunk:
        concat_start = len(self.code)
        self._concat_sites = []
        self._needs_concat_runtime = False
        # Hoist function + class declarations first (JS-style)
        saved_i = self.i
        self._prescan_class_names()  # so `new Foo` inside functions resolves
        self._prescan_function_names()
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
        # Retro-patch provable globals to a1=1 (skip the env walk).
        # Safe iff no lexically-enclosing function scope declares the name:
        # the runtime walk could then never hit an env slot and always fell
        # through to vvars — a1=1 reads/writes vvars directly (ENVWALK was
        # 92% of S_HEAP_CMP = ~44% of all VM cycles in INVADERS play).
        # Determine bindings after all scopes finish: forward declarations and
        # captured outer locals must shadow standard numeric globals too.
        for _idx, _nm, _scopes in self._global_sites:
            if (self.code[_idx][0] == Op.STORE_VAR and
                    not any(_nm in scope for scope in _scopes)):
                self._standard_global_bindings.add(_nm)
        for _idx, _nm, _scopes in self._global_sites:
            if any(_nm in s for s in _scopes):
                continue
            _t = self.code[_idx]
            if (len(_t) == 2 and _t[0] in (Op.LOAD_VAR, Op.STORE_VAR)
                    and isinstance(_t[1], int) and 0 <= _t[1] < len(self.names)
                    and self.names[_t[1]] == _nm):
                if (_t[0] == Op.LOAD_VAR and _nm in ("Infinity", "NaN") and
                        _nm not in self._standard_global_bindings and
                        _nm not in self.functions and _nm not in self._hoisted_fn_names):
                    self.code[_idx] = (Op.LOAD_CONST, self._const(
                        float("inf") if _nm == "Infinity" else float("nan")))
                else:
                    self.code[_idx] = (_t[0], _t[1], 1)
        # Defer builtin String decisions until forward local/global bindings
        # and captured outer scope sets are complete. Keep shadowed calls intact.
        for load_ip, call_ip, argc, scopes in self._string_call_sites:
            if (any("String" in scope for scope in scopes) or
                    "String" in self._standard_global_bindings or
                    "String" in self.functions or "String" in self.classes or
                    "String" in self._hoisted_fn_names):
                continue
            self._needs_string_runtime = True
            if self._runtime_probe:
                continue
            helper = "_jmr_json_stringEmptyNative" if argc == 0 else "_jmr_json_stringCoerceNative"
            if helper not in self.functions:
                raise CompileError("String runtime must be included through shared source preparation", 0)
            self.code[load_ip] = (Op.JUMP, load_ip + 1)
            self.code[call_ip] = (Op.CALL_USER, self.functions[helper][0], argc)
        # As with String, later declarations and captured outer bindings
        # determine whether localStorage is the shared service or a user object.
        for load_ip, prepare_ips, call_ip, argc, method, scopes in self._storage_call_sites:
            if (any("localStorage" in scope for scope in scopes) or
                    "localStorage" in self._standard_global_bindings or
                    "localStorage" in self.functions or "localStorage" in self.classes or
                    "localStorage" in self._hoisted_fn_names):
                continue
            self._needs_storage_runtime = True
            if self._runtime_probe:
                continue
            helper = "_jmr_store_" + method
            if helper not in self.functions:
                raise CompileError("storage runtime must be included through shared source preparation", 0)
            for ip in (load_ip,) + prepare_ips:
                self.code[ip] = (Op.JUMP, ip + 1)
            self.code[call_ip] = (Op.CALL_USER, self.functions[helper][0], argc)
        # Markers survive existing safe inline copies; only this compile batch
        # is rewritten, so a previously frozen resident prefix never changes.
        sites = [i for i in range(concat_start, len(self.code))
                 if self.code[i][0] == Op.ADD and len(self.code[i]) > 1 and self.code[i][1] == 0]
        if sites:
            from .add_proof import prove
            self._add_proof = prove(self, sites)
            safe = set(self._add_proof['safe'])
            for site in safe: self.code[site] = (Op.ADD,)
            sites = [site for site in sites if site not in safe]
        self._needs_concat_runtime = bool(sites)
        helper = self.functions.get("_jmr_json_addNative")
        if sites and helper is None and self._require_concat_helper and not self._runtime_probe:
            raise CompileError("mixed ADD proof changed after source preparation", 0)
        for site in sites:
            self.code[site] = (Op.ADD, helper[0]) if helper is not None else (Op.ADD,)
        chunk = Chunk(
            self.code,
            self.consts,
            self.names,
            dict(self.functions),
            dict(self.classes),
            op_lines=list(self.op_lines),
        )
        chunk.null_const_indices = set(self._null_consts)
        return chunk

    def _function_end(self, start):
        """Token after one function body; skip params/destructuring safely."""
        j=start+1
        while j<len(self.tokens) and self.tokens[j][1]!="(": j+=1
        depth=0
        while j<len(self.tokens):
            t=self.tokens[j][1]; depth += (t=="(")-(t==")"); j+=1
            if depth==0: break
        if j>=len(self.tokens) or self.tokens[j][1]!="{": return j
        depth=1; j+=1
        while j<len(self.tokens) and depth:
            t=self.tokens[j][1]; depth+=(t=="{")-(t=="}"); j+=1
        return j

    def _declarations(self, start=0, body=False):
        """Declarations in this function scope, excluding nested bodies."""
        out=[]; j=start; depth=0
        while j<len(self.tokens):
            t=self.tokens[j][1]
            if body and t=="}" and depth==0: break
            if t=="function":
                named=j+1<len(self.tokens) and self.tokens[j+1][0]=="ID"
                previous=self.tokens[j-1][1] if j else ";"
                expression_prefix={"=","(","[",",",":","?","return","throw","=>","+","-","*","/","%","!","~","&","|","^","&&","||","??","+=","-=","*=","/=","%=","void","typeof","delete","new"}
                if named and (j==start or previous not in expression_prefix):
                    out.append(j)
                j=self._function_end(j); continue
            if t=="class" or (t=="=>" and j+1<len(self.tokens) and self.tokens[j+1][1]=="{"):
                while j<len(self.tokens) and self.tokens[j][1]!="{":j+=1
                if j<len(self.tokens):
                    level=1;j+=1
                    while j<len(self.tokens) and level:
                        u=self.tokens[j][1];level+=(u=="{")-(u=="}");j+=1
                continue
            depth+=(t=="{")-(t=="}");j+=1
        return out

    def _prescan_function_names(self) -> None:
        self._global_declarations=self._declarations()
        self._hoisted_fn_names={self.tokens[i+1][1] for i in self._global_declarations}

    def _hoist_local_declarations(self):
        saved=self.i; declarations=self._declarations(saved,True)
        for i in declarations:self._note_local(self.tokens[i+1][1])
        for i in declarations:
            self.i=i;self._function_decl()
        self.i=saved

    def _lexically_bound(self,name):
        return any(name in scope for scope in self._scope_sets)

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
        for i in self._global_declarations:
            self.i=i;self._function_decl()

    def _function_decl(self) -> None:
        """NEW: function name(params) { body } → JUMP over; entry; bind; body; RET_VAL."""
        self._advance()  # function
        kind, text, line = self._advance()
        if kind != "ID":
            raise CompileError("EXPECTED FUNCTION NAME", line)
        fname = text
        # Parent can close over this name while we compile the body.
        if self._local_stack:
            self._note_local(fname)
        self._expect("(")
        params: List[Any] = []
        if self._peek_text() != ")":
            while True:
                # Object destructuring { a, b } → one arg unpacked to locals
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
        enclosing_fn = self._fn_compiling
        nested = bool(self._fn_depth)
        self._fn_compiling = fname
        self._enter_local_frame()
        self._scope_sets.append(set())
        # prologue: stack has arg0..argN-1 (last arg on top)
        # Params declare into the per-call lexical env (LET_VAR).
        # arg2=1 flags "call-frame local" for RTL (flat vars: always store;
        # only top-level LET_VAR keeps init-if-missing across frame re-runs).
        for p in reversed(params):
            if isinstance(p, tuple) and p[0] == "destruct":
                tmp = self._name("__arg")
                self._emit(Op.LET_VAR, tmp, 1)
                for key in p[1]:
                    self._note_local(key)
                    self._emit(Op.LOAD_VAR, tmp)
                    self._emit(Op.GET_PROP, self._name(key))
                    self._emit(Op.LET_VAR, self._name(key), 1)
            else:
                self._note_local(p)
                self._emit(Op.LET_VAR, self._name(p), 1)
        self._expect("{")
        self._begin_body()
        self._fn_depth += 1  # Function body locals use LET_VAR (env)
        # `if (ch === "1") return 1; ... return 0` is one obj[ch]|0
        # instead of N EQ/JUMP pairs (inner sprite loops were ~14 compares
        # per pixel × CALL_USER). Lut is stored after MAKE_FN below.
        self._hoist_local_declarations()
        ceq_lut = self._try_emit_char_eq_lookup(params)
        if not ceq_lut:
            while self._peek_text() not in ("", "}"):
                self._statement()
        self._expect("}")
        self._fn_depth -= 1
        self._end_body()
        if self._local_stack:
            self._leave_local_frame()
        if self._scope_sets:
            self._scope_sets.pop()
        if not ceq_lut:
            # implicit return undefined
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
        self._patch(jmp_over, Op.JUMP, len(self.code))
        # store flat param count for arity (destruct counts as 1)
        flat = [p if isinstance(p, str) else "__arg" for p in params]
        if not nested:
            self.functions[fname] = (entry, flat)
            self._fn_end[fname] = len(self.code)
        self._fn_compiling = enclosing_fn
        # Compiler-owned helpers used only by direct calls need no global Fn.
        # Public/user functions and any first-class helper references keep binding.
        private_direct = fname.startswith(("_jmr_json_", "_jmr_store_")) and not nested
        if private_direct:
            for ti, token in enumerate(self.tokens):
                if token[0] == "ID" and token[1] == fname:
                    if ti + 1 >= len(self.tokens) or self.tokens[ti + 1][1] != "(":
                        private_direct = False
                        break
        if private_direct and fname in self.name_index:
            ni = self.name_index[fname]
            private_direct = not any(op[0] == Op.LOAD_VAR and op[1] == ni for op in self.code)
        if private_direct and ceq_lut is None:
            return
        # Bind function name as first-class Fn (rAF(animate) / keys need LOAD_VAR)
        self._emit(Op.MAKE_FN, entry, len(flat))
        # Nested decls stay local to the enclosing call env (LET_VAR);
        # top level keeps the global STORE (hoisted call sites need it)
        if self._fn_depth:
            self._emit(Op.LET_VAR, self._name(fname), 1)  # call-frame local (RTL flag)
        else:
            self._emit(Op.STORE_VAR, self._name(fname))
        if ceq_lut is not None:
            lut_name, pairs = ceq_lut
            self._emit(Op.MAKE_OBJ)
            for ch, num in pairs:
                self._emit(Op.DUP)
                self._emit(Op.LOAD_CONST, self._const(num))
                self._emit(Op.SET_PROP, self._name(ch))
                self._emit(Op.POP)
            self._emit(Op.STORE_VAR, self._name(lut_name))


    def _try_emit_char_eq_lookup(
        self, params: List[Any]
    ) -> Optional[Tuple[str, List[Tuple[str, int]]]]:
        """If the body is `if (p === "c") return n;` × ≥4 plus `return d`, emit lut get.

        Same JS result as the if-chain. One ARRAY_GET + BIT_OR instead of a
        linear EQ cascade (sprite `ch === "1"` … `"e"` was thousands of ops
        per frame).
        """
        if len(params) != 1 or not isinstance(params[0], str):
            return None
        ident = params[0]
        saved = self.i
        pairs: List[Tuple[str, int]] = []
        while self._peek_text() == "if":
            self._advance()
            if not self._match("("):
                self.i = saved
                return None
            tok = self._peek()
            if tok is None or tok[0] != "ID" or tok[1] != ident:
                self.i = saved
                return None
            self._advance()
            if self._peek_text() not in ("===", "=="):
                self.i = saved
                return None
            self._advance()
            kt = self._peek()
            if kt is None or kt[0] not in ("STR", "STR2"):
                self.i = saved
                return None
            ch = self._advance()[1][1:-1]
            if len(ch) != 1:
                self.i = saved
                return None
            if not self._match(")"):
                self.i = saved
                return None
            if not self._match("return"):
                self.i = saved
                return None
            nt = self._peek()
            if nt is None or nt[0] != "NUM":
                self.i = saved
                return None
            num = int(_num_value(self._advance()[1]))
            self._match(";")
            pairs.append((ch, num))
        if len(pairs) < 4 or self._peek_text() != "return":
            self.i = saved
            return None
        self._advance()
        nt = self._peek()
        default = 0
        if nt is not None and nt[0] == "NUM":
            default = int(_num_value(self._advance()[1]))
        else:
            self.i = saved
            return None
        self._match(";")
        if self._peek_text() != "}":
            self.i = saved
            return None
        lut_name = f"__ceq_{ident}_{len(self.names)}"
        self._emit(Op.LOAD_VAR, self._name(lut_name))
        self._emit(Op.LOAD_VAR, self._name(ident))
        self._emit(Op.ARRAY_GET)
        if default != 0:
            # missing key is undefined; `undefined|0` is 0, so only OR when
            # the chain's fallback is not already 0.
            self._emit(Op.DUP)
            jmp_hit = self._emit(Op.JUMP_IF_FALSE, 0)
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch(jmp_hit, Op.JUMP_IF_FALSE, len(self.code))
            self._emit(Op.POP)
            self._emit(Op.LOAD_CONST, self._const(default))
            self._patch(jmp_end, Op.JUMP, len(self.code))
        else:
            self._emit(Op.LOAD_CONST, self._const(0))
            self._emit(Op.BIT_OR)
        self._emit(Op.RET_VAL)
        return lut_name, pairs

    def _fn_body_inlineable(self, entry: int, end: int) -> bool:
        """Param-only body, no nested call/alloc — safe to run in the caller."""
        if end <= entry or (end - entry) > 64:
            return False
        i = entry
        while i < end:
            op = self.code[i]
            if op[0] == Op.LET_VAR and len(op) > 2 and op[2] == 1:
                i += 1
                continue
            break
        for ip in range(i, end):
            op = self.code[ip]
            if op[0] in (Op.CALL_USER, Op.CALL_VAL, Op.MAKE_FN, Op.NEW_OBJ):
                return False
            if op[0] == Op.LET_VAR:
                return False
        return True

    def _try_inline_user_call(self, fname: str, argc: int) -> bool:
        """Splices a tiny callee at the call site (args already on the stack)."""
        if fname == self._fn_compiling or fname not in self.functions:
            return False
        # LET_VAR local flag needs a call env; top-level CALL_USER keeps one.
        if not self._fn_depth:
            return False
        if fname not in self._fn_end:
            return False
        entry, params = self.functions[fname]
        if argc != len(params):
            return False
        end = self._fn_end[fname]
        if not self._fn_body_inlineable(entry, end):
            return False
        # The spliced
        # body's LET_VAR param binds become KEYED SLOTS IN THE CALLER'S FRAME.
        # A caller already at the 16-slot wall (RTL ENV_SLOTS — animate() in
        # INVFAST sat at exactly 16) gained a 17th name on the FIRST execution
        # of the inline and the VM faulted at the S_HEAP_CMP env-slot wall —
        # invisible to _note_local's loud check, which counted only source
        # declarations. Refuse and fall back to CALL_USER (own frame, always
        # correct) when the params would not fit; also refuse on name capture
        # (a param name already keyed in the caller would alias the caller's
        # variable). When we DO inline, register the params as caller locals
        # so the 16-wall check stays loud for everything declared after this
        # call site.
        cur = self._local_stack[-1] if self._local_stack else None
        if cur is None:
            return False
        if any(p in cur for p in params):
            return False
        outer = self._frame_info[-1].get("outer") if self._frame_info else None
        if outer and any(p in outer for p in params):
            return False
        if len(cur) + len(params) > 16:
            return False
        # Copied callee slot hints are verified by raw names at runtime,
        # not rebased into caller slots. Keep this entire caller unaliased.
        self._local_serial += 1
        for p in params:
            self._note_local(p)
        delta = len(self.code) - entry
        ret_sites: List[int] = []
        for ip in range(entry, end):
            op = self.code[ip]
            line = self.op_lines[ip] if ip < len(self.op_lines) else 0
            opc = op[0]
            if opc == Op.RET_VAL:
                ret_sites.append(len(self.code))
                self.code.append((Op.JUMP, 0))
                self.op_lines.append(line)
            elif opc in (Op.JUMP, Op.JUMP_IF_FALSE):
                tgt = int(op[1])
                if entry <= tgt < end:
                    tgt = tgt + delta
                self.code.append((opc, tgt))
                self.op_lines.append(line)
            else:
                self.code.append(tuple(op))
                self.op_lines.append(line)
        after = len(self.code)
        for site in ret_sites:
            self.code[site] = (Op.JUMP, after)
        return True

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
        setters: dict[str, int] = {}
        getters: set[str] = set()  # `get name()` accessors (DONKEY marioMiddle)
        ctor_entry: Optional[int] = None
        ctor_jmp_after_params: Optional[int] = None
        ctor_body_ip: Optional[int] = None
        # Class-field arrows are own instance properties, not prototype methods.
        fields: List[Tuple[str, int, int, int]] = []
        self._expect("{")
        while self._peek_text() not in ("", "}"):
            # Get name() / set name() — body compiles like a method, but
            # getters are recorded so GET_PROP invokes them (this.marioMiddle).
            is_getter = False
            is_setter = False
            if self._peek_text() in ("get", "set") and (
                self.i + 1 < len(self.tokens) and self.tokens[self.i + 1][0] == "ID"
            ):
                is_getter = self._peek_text() == "get"
                is_setter = self._peek_text() == "set"
                self._advance()
            # Class field arrow — startSelect = (e) => {}
            mk, mname, mline = self._peek() or ("", "", 0)
            if mk == "ID" and self.i + 1 < len(self.tokens) and self.tokens[self.i + 1][1] == "=":
                self._advance()
                self._expect("=")
                self._expression()
                if self.code and self.code[-1][0] == Op.MAKE_FN:
                    mkfn = self.code[-1]
                    entry = int(mkfn[1])
                    nparam = int(mkfn[2]) if len(mkfn) > 2 else 0
                    is_arrow = int(mkfn[3]) if len(mkfn) > 3 else 1
                    self.code.pop()  # body already JUMP-guarded; ctor MAKE_FNs
                    self.op_lines.pop()  # keep ProgramImage source map aligned
                    fields.append((mname, entry, nparam, is_arrow))
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
                    # Constructor({ position, type }) destructuring
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
            self._enter_local_frame()
            self._scope_sets.append(set())
            # Method params declare into the per-call env (LET_VAR);
            # arg2=1 = call-frame local flag for RTL (always store there)
            for p in reversed(params):
                if isinstance(p, tuple) and p[0] == "destruct":
                    tmp = self._name("__arg")
                    self._emit(Op.LET_VAR, tmp, 1)
                    for key in p[1]:
                        self._note_local(key)
                        self._emit(Op.LOAD_VAR, tmp)
                        self._emit(Op.GET_PROP, self._name(key))
                        self._emit(Op.LET_VAR, self._name(key), 1)
                else:
                    self._note_local(p)
                    self._emit(Op.LET_VAR, self._name(p), 1)
            # After params so _value64_entry_nparam still sees LET_VAR
            # at constructor_ip (class-field inits jump in after binding).
            jmp_after_params = self._emit(Op.JUMP, 0)
            ctor_body = len(self.code)
            self._expect("{")
            self._begin_body()
            self._fn_depth += 1  # Class method/ctor locals use LET_VAR (env)
            self._hoist_local_declarations()
            while self._peek_text() not in ("", "}"):
                self._statement()
            self._expect("}")
            self._fn_depth -= 1
            self._end_body()
            if self._local_stack:
                self._leave_local_frame()
            if self._scope_sets:
                self._scope_sets.pop()
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
            self._patch(jmp_over, Op.JUMP, len(self.code))
            self._patch(jmp_after_params, Op.JUMP, ctor_body)
            if is_ctor:
                ctor_entry = entry
                ctor_jmp_after_params = jmp_after_params
                ctor_body_ip = ctor_body
            else:
                self.all_methods.add(mname)
                if is_setter:
                    if len(params)!=1:raise CompileError("SETTER NEEDS ONE PARAM",mline)
                    setters[mname]=entry
                    if mname not in getters:methods.pop(mname,None)
                else:
                    methods[mname]=entry
                    if is_getter:
                        if params:raise CompileError("GETTER NEEDS NO PARAMS",mline)
                        getters.add(mname)
                    else:
                        getters.discard(mname);setters.pop(mname,None)
        self._expect("}")
        if fields:
            jmp_over = self._emit(Op.JUMP, 0)
            fi_entry = len(self.code)
            for fname, entry, nparam, is_arrow in fields:
                self._emit(Op.LOAD_VAR, self._name("__this"))
                self._emit(Op.MAKE_FN, entry, nparam, is_arrow)
                self._emit(Op.SET_PROP, self._name(fname))
                self._emit(Op.POP)
            if ctor_entry is not None and ctor_jmp_after_params is not None:
                # constructor_ip stays at param LET_VARs (nparam scan / RTL).
                self._emit(Op.JUMP, int(ctor_body_ip or 0))
                self._patch(ctor_jmp_after_params, Op.JUMP, fi_entry)
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
                self._emit(Op.RET_VAL)
                ctor_entry = fi_entry
            self._patch(jmp_over, Op.JUMP, len(self.code))
        if ctor_entry is None:
            # Constructorless class - synthesize an empty
            # ctor so `new T()` stamps the instance's class. Without one
            # the RTL object never received its class field and EVERY
            # method call on it silently missed (Defect B; gate:
            # tests/test_class_method_scan.py ctorless case).
            jmp_over2 = self._emit(Op.JUMP, 0)
            ctor_entry = len(self.code)
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
            self._patch(jmp_over2, Op.JUMP, len(self.code))
        self.classes[cname] = {"ctor": ctor_entry, "methods": methods, "getters": getters, "setters": setters}

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
        args = tuple(op_args)
        if (args and args[0] == Op.LET_VAR and len(args) > 2 and args[2]
                and self._frame_info and self._frame_info[-1].get("outer")
                and self.names[int(args[1])] in self._frame_info[-1]["outer"]):
            self._note_local(self.names[int(args[1])])
            args = (Op.STORE_VAR, args[1])
        if (args and args[0] in (Op.STORE_VAR, Op.LET_VAR) and
                len(args) >= 2 and not self._scope_sets):
            self._standard_global_bindings.add(self.names[int(args[1])])
        # LOAD_VAR/STORE_VAR a1: 0=chain (global/upvalue), 1=hoisted fn
        # global (vvars), 2+slot=local. Do not pack a1=1 for every
        # non-local — that skipped env slots (bunkers/timestamp/`f`).
        if args and args[0] in (Op.LOAD_VAR, Op.STORE_VAR) and len(args) == 2:
            ni = int(args[1])
            name = self.names[ni] if 0 <= ni < len(self.names) else ""
            a1 = self._var_a1(name)
            if a1:
                args = (args[0], ni, a1)
        if args and args[0] == Op.LET_VAR and len(args) >= 2:
            ni = int(args[1])
            local = len(args) > 2 and args[2]
            if local:
                name = self.names[ni] if 0 <= ni < len(self.names) else ""
                self._note_local(name)
                # Carry the env slot as a verified hint (a1[7:1] in the
                # encoder). RTL phase-6 checks the hinted slot first and
                # falls back to a full scan on mismatch — re-`let` in loop
                # bodies was the top ENVWALK sink after loads got hints.
                slot = (self._local_stack[-1].get(name)
                        if self._local_stack else None)
                if slot is not None:
                    args = (args[0], args[1], args[2], slot)
        self.code.append(args)
        self.op_lines.append(line)
        return len(self.code) - 1

    def _enter_local_frame(self):
        self._local_serial += 1
        self._local_marks.append((self._local_serial,len(self.code)))
        self._local_stack.append({})
        self._frame_info.append({})

    def _leave_local_frame(self):
        serial,start=self._local_marks.pop()
        if serial==self._local_serial:
            self._compact_leaf_ips.update(range(start,len(self.code)))
            self._compact_leaf_ranges.append((start,len(self.code)))
        self._local_stack.pop()
        self._frame_info.pop()

    def _note_local(self, name: str) -> None:
        if not name or not self._local_stack:
            return
        if len(self._local_stack) in self._flat_module_frames:
            return
        if self._scope_sets:
            self._scope_sets[-1].add(name)
        cur = self._local_stack[-1]
        if name in cur:
            return
        outer = self._frame_info[-1].get("outer") if self._frame_info else None
        if outer and name in outer:
            return
        if len(cur) >= 16 and not self._local_plans and "key" in self._frame_info[-1]:
            cur[name] = len(cur)
            return
        # A frame holds 16 names (RTL ENV_SLOTS). Body locals past that are
        # planned out of the frame by compile(); what still lands here is a
        # parameter list longer than 16, which nothing can place elsewhere.
        if len(cur) >= 16:
            t = self._peek()
            if t is None and self.i > 0:
                t = self.tokens[self.i - 1]
            line = int(t[2]) if t is not None else 0
            fn = self._fn_compiling or "<anonymous>"
            raise CompileError(
                f"{fn}(): {len(cur) + 1} parameters (name {name!r}) — "
                f"over the 16-slot call scope (RTL ENV_SLOTS).",
                line,
            )
        cur[name] = len(cur)

    def _var_a1(self, name: str) -> int:
        """Pack LOAD_VAR/STORE_VAR a1. 0=chain, 1=hoisted fn global, 2+slot=local.

        Do not guess a1=1 for every non-local — that skipped the env where
        `const bunkers` / upvalues live. Hoisted `function tick` is a vvars
        global; inner `requestAnimationFrame(tick)` must not HEAP-walk the
        callee env (RTL TOS/gen miss → rAF fault 4).
        """
        if not name:
            return 0
        if self._local_stack:
            cur = self._local_stack[-1]
            if name in cur:
                return 2 + cur[name]
        # Candidate global: decided at end of compile() when the enclosing
        # scopes' declaration sets are complete (`var` hoisting: a use can
        # be emitted before its declaration is seen). Hold references to
        # the live set objects — they keep filling until the scope closes.
        self._global_sites.append((len(self.code), name, tuple(self._scope_sets)))
        return 0

    def _patch(self, idx: int, *op_args: Any) -> None:
        self.code[idx] = tuple(op_args)

    def _jumps_past(self, start: int, at: int) -> bool:
        """True if a jump emitted since `start` lands after op `at`."""
        for op in self.code[start:]:
            if op[0] in (Op.JUMP, Op.JUMP_IF_FALSE) and int(op[1]) > at:
                return True
        return False

    def _drop_op(self, at: int) -> None:
        """Remove one op from the tail region, keeping recorded sites aligned."""
        del self.code[at]
        del self.op_lines[at]
        sites = self._global_sites
        k = len(sites)
        while k and sites[k - 1][0] >= at:
            k -= 1
        for n in range(k, len(sites)):
            idx, name, scopes = sites[n]
            sites[n] = (idx - 1, name, scopes) if idx > at else None
        sites[k:] = [s for s in sites[k:] if s is not None]
        self._concat_sites = [s - 1 if s > at else s
                              for s in self._concat_sites if s != at]

    def _emit_discard(self, start: int) -> None:
        """Discard the value of the expression compiled from `start`.

        An assignment or ++/-- whose value is unused does not need it on the
        stack: `STORE x; LOAD x; POP` is `STORE x`, and `x++` / `++x` lose
        their DUP. Anything else gets the ordinary POP.
        """
        code = self.code
        n = len(code)
        if not self.optimize:
            self._emit(Op.POP)
            return
        if n - start >= 2:
            store, load = code[-2], code[-1]
            if (store[0] == Op.STORE_VAR and load[0] == Op.LOAD_VAR
                    and store[1:] == load[1:] and not self._jumps_past(start, n - 2)):
                self._drop_op(n - 1)
                return
        if n - start >= 5 and code[-1][0] == Op.STORE_VAR:
            # postfix: LOAD x; DUP; LOAD_CONST 1; ADD|SUB; STORE x
            # prefix:  LOAD x; LOAD_CONST 1; ADD|SUB; DUP; STORE x
            for dup in (n - 4, n - 2):
                if code[dup][0] != Op.DUP:
                    continue
                body = [code[k][0] for k in range(n - 5, n - 1) if k != dup]
                if (body == [Op.LOAD_VAR, Op.LOAD_CONST, body[2]]
                        and body[2] in (Op.ADD, Op.SUB)
                        and code[n - 5][1:] == code[-1][1:]
                        and not self._jumps_past(start, dup)):
                    self._drop_op(dup)
                    return
        self._emit(Op.POP)

    def _statement(self) -> None:
        t = self._peek()
        if t is None:
            return
        kind, text, line = t
        # Empty statement (";" script-block separators)
        if text == ";":
            self._advance()
            return
        if text == "function" and self.i+1<len(self.tokens) and self.tokens[self.i+1][0]=="ID":
            self._skip_function_decl()
            return
        if text in ("let", "var", "const"):
            self._advance()
            self._var_decl(text)
            self._match(";")
            return
        # Nested class (DONKEY IIFE) — hoisted already; skip token body
        if text == "class":
            self._skip_class_decl()
            return
        if text == "throw":
            # Soft throw (mk.js invalid-state guards). No unwind
            # machinery in the VM: evaluate the expression for its side
            # effects and drop it. A thrown-in-practice path would differ from
            # Chrome — acceptable for guards that never fire in play.
            self._advance()
            self._expression()
            self._emit(Op.POP)
            self._match(";")
            return
        if text == "if":
            self._if_stmt()
            return
        if text == "while":
            self._while_stmt()
            return
        if text == "do":
            self._do_stmt()
            return
        # For (init; cond; step) body — desugar to while
        if text == "for":
            self._for_stmt()
            return
        # Switch / case / break
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
        # Continue → jump to innermost loop's step/condition (not a no-op ID)
        if text == "continue":
            self._advance()
            if not self.continue_stack:
                raise CompileError("CONTINUE OUTSIDE LOOP", line)
            self.continue_stack[-1].append(self._emit(Op.JUMP, 0))
            self._match(";")
            return
        # Try { ... } catch (...) { ... } — run try body; skip catch tokens
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
        # Return [expr];
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
        start = len(self.code)
        self._expression()
        self._emit_discard(start)
        self._match(";")

    def _var_decl(self, kw: str = "var") -> None:
        # Const { key } = e;  object destructure
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
            # Fn locals declare into the call env (LET_VAR); top-level
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
        # Var a, b=1, c;  multi-declarator (DONKEY)
        while True:
            kind, text, line = self._advance()
            if kind != "ID":
                raise CompileError("EXPECTED IDENTIFIER", line)
            # Note the local before the initializer so `var fn = function(){ fn(); }`
            # (and rAF(animate) closures) see an upvalue, not a false global a1=1.
            if self._fn_depth:
                self._note_local(text)
            if self._match("="):
                # _ternary not _expression — `,` separates declarators
                # (PACMAN `var _CONFIG=[..], _LIFE=5, _SCORE=0` got _LIFE=0)
                self._ternary()
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
            # LET_VAR everywhere — inside a fn it declares in the call
            # env (per-call locals, closure-correct); top level keeps the
            # init-if-missing global (startLoop re-entry). arg2=1 marks
            # call-frame locals so flat-var RTL always stores those.
            # Top-level loop body: STORE so `var row = []` runs every
            # iteration (LET_VAR skips if the global exists → one shared
            # array; last write wins; one cell store clears a column).
            # Inside a function, KEEP LET_VAR local (a1 bit0): that always
            # writes the env slot. STORE_VAR of an undeclared slot falls
            # through to the GLOBAL, so two functions that both
            # `var col = 0` in a while share one cursor — the inner sprite
            # loop resets the outer column index forever (PYTHON 1M fuse /
            # FPGA-SIM freeze on a full playfield paint).
            if self._loop_depth and not self._fn_depth:
                self._emit(Op.STORE_VAR, self._name(text))
            else:
                self._emit(Op.LET_VAR, self._name(text), 1 if self._fn_depth else 0)
            if not self._match(","):
                break

    def _block(self, function_scope=False) -> None:
        self._expect("{")
        if function_scope:self._hoist_local_declarations()
        while self._peek_text() not in ("", "}"):
            self._statement()
        self._expect("}")

    def _chain_ahead(self, start: int, stop: str) -> bool:
        """True if tokens from `start` to `stop` form a plain && / || chain.

        Only then can a condition become direct jumps: a top-level ?:, comma,
        assignment or nested function keeps the ordinary value form.
        """
        depth = 0
        chain = False
        operand = False  # previous depth-0 token ends an operand
        j = start
        while j < len(self.tokens):
            kind, t = self.tokens[j][0], self.tokens[j][1]
            if kind in ("STR", "STR2", "TMPL", "REGEX", "NUM", "ID"):
                # Two operands in a row: the expression ended (ASI) or this
                # is a keyword operator form; either way not a plain chain.
                if depth == 0 and operand:
                    return False
                if t == "function":
                    return False
                operand = depth == 0
            elif t in ("(", "[", "{"):
                depth += 1
                operand = False
            elif t in (")", "]", "}"):
                if depth == 0:
                    return chain and t == stop
                depth -= 1
                operand = depth == 0
            elif depth == 0:
                operand = False
                if t == stop:
                    return chain
                if t in ("&&", "||"):
                    chain = True
                elif t in (",", ";", ":", "=>") or t.startswith("?") or (
                        t.endswith("=") and t not in ("==", "===", "!=", "!==", "<=", ">=")):
                    return False
            j += 1
        return False

    def _paren_chain(self) -> bool:
        """At `(`: a parenthesised chain that is itself a whole operand."""
        if self._peek_text() != "(" or not self._chain_ahead(self.i + 1, ")"):
            return False
        depth = 0
        j = self.i
        while j < len(self.tokens):
            t = self.tokens[j][1]
            if self.tokens[j][0] not in ("STR", "STR2", "TMPL", "REGEX", "NUM", "ID"):
                depth += (t in ("(", "[", "{")) - (t in (")", "]", "}"))
                if depth == 0:
                    break
            j += 1
        nxt = self.tokens[j + 1][1] if j + 1 < len(self.tokens) else ""
        return nxt in ("&&", "||", ")", ";", "?")

    def _cond_and(self) -> List[int]:
        """Operands joined by &&; each false operand jumps out (sites returned)."""
        false_sites: List[int] = []
        while True:
            if self._paren_chain():
                self._advance()
                false_sites += self._cond_or()
                self._expect(")")
            else:
                self._equality()
                false_sites.append(self._emit(Op.JUMP_IF_FALSE, 0))
            if not self._match("&&"):
                return false_sites

    def _cond_or(self) -> List[int]:
        """An || chain of && chains; falls through when true, else jumps."""
        true_sites: List[int] = []
        while True:
            false_sites = self._cond_and()
            if not self._match("||"):
                for site in true_sites:
                    self._patch(site, Op.JUMP, len(self.code))
                return false_sites
            true_sites.append(self._emit(Op.JUMP, 0))
            for site in false_sites:
                self._patch(site, self.code[site][0], len(self.code))

    def _condition(self, stop: str) -> List[int]:
        """Compile a test; return the jump sites to patch to its false target."""
        if self.optimize and self._chain_ahead(self.i, stop):
            return self._cond_or()
        self._expression()
        return [self._emit(Op.JUMP_IF_FALSE, 0)]

    def _patch_false(self, sites: List[int], target: int) -> None:
        for site in sites:
            self._patch(site, self.code[site][0], target)

    def _if_stmt(self) -> None:
        self._advance()  # if
        self._expect("(")
        jmp_f = self._condition(")")
        self._expect(")")
        self._statement()
        if self._match("else"):
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch_false(jmp_f, len(self.code))
            self._statement()
            self._patch(jmp_end, Op.JUMP, len(self.code))
        else:
            self._patch_false(jmp_f, len(self.code))

    def _while_stmt(self) -> None:
        self._advance()
        loop = len(self.code)
        self._expect("(")
        jmp_f = self._condition(")")
        self._expect(")")
        self.break_stack.append([])
        self.continue_stack.append([])
        self._loop_depth += 1
        self._statement()
        self._loop_depth -= 1
        self._emit(Op.JUMP, loop)
        end = len(self.code)
        self._patch_false(jmp_f, end)
        for j in self.break_stack.pop():
            self._patch(j, Op.JUMP, end)
        # While continue jumps to the condition (loop head)
        for j in self.continue_stack.pop():
            self._patch(j, Op.JUMP, loop)

    def _do_stmt(self) -> None:
        """do body while (cond); -> body; test; jump back while true."""
        line = self._advance()[2]
        loop = len(self.code)
        self.break_stack.append([])
        self.continue_stack.append([])
        self._loop_depth += 1
        self._statement()
        self._loop_depth -= 1
        test = len(self.code)
        if self._peek_text() != "while":
            raise CompileError("EXPECTED while AFTER do BODY", line)
        self._advance()
        self._expect("(")
        jmp_f = self._condition(")")
        self._expect(")")
        self._match(";")
        self._emit(Op.JUMP, loop)
        end = len(self.code)
        self._patch_false(jmp_f, end)
        for j in self.break_stack.pop():
            self._patch(j, Op.JUMP, end)
        # Continue runs the test, as in JS.
        for j in self.continue_stack.pop():
            self._patch(j, Op.JUMP, test)

    def _for_stmt(self) -> None:
        """NEW: for (init; cond; step) body → init; while(cond){ body; step }
        Also: for (const x of arr) body → index loop (DONKEY ladders).
        """
        self._advance()  # for
        self._expect("(")
        # Bare for (k in o) — no declaration keyword (mk.js shims)
        if self._peek() and self._peek()[0] == "ID":
            saved_b = self.i
            bind = self._advance()[1]
            if self._match("in"):
                self._expression()
                self._emit(Op.CALL_NATIVE, self._name("Object.keys"), 1)
                arr = self._name("__a")
                idx = self._name("__i")
                self._emit(Op.STORE_VAR, arr)
                self._emit(Op.LOAD_CONST, self._const(0))
                self._emit(Op.STORE_VAR, idx)
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
                self._emit(Op.STORE_VAR, self._name(bind))
                self.break_stack.append([])
                self.continue_stack.append([])
                self._loop_depth += 1
                self._statement()
                self._loop_depth -= 1
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
            self.i = saved_b
        # For-of — for (const x of expr)
        if self._peek_text() in ("let", "var", "const"):
            saved_i = self.i
            self._advance()  # let/var/const
            if self._peek() and self._peek()[0] == "ID":
                bind = self._advance()[1]
                if self._match("in"):
                    # For (k in o) → walk Object.keys(o) (native 41).
                    # Same temp/loop shape as for-of below.
                    self._expression()
                    self._emit(Op.CALL_NATIVE, self._name("Object.keys"), 1)
                    arr = self._name("__a")
                    idx = self._name("__i")
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
                    self._loop_depth += 1
                    self._statement()
                    self._loop_depth -= 1
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
                    self._loop_depth += 1
                    self._statement()
                    self._loop_depth -= 1
                    # For-of continue lands on idx++
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
        # Inside a call env, for (let/const i) LET_VAR first so STORE
        # for i++ hits this frame's `i`, not a caller/forEach captured `i`.
        if self._peek_text() in ("let", "var", "const"):
            _kw = self._peek_text()
            _decl = Op.STORE_VAR
            self._advance()
            kind, text, line = self._advance()
            if kind != "ID":
                raise CompileError("EXPECTED IDENTIFIER", line)
            # For (let i;;) allows missing init expr
            # #81: note the local BEFORE deciding the op — for-init names
            # never reached the scope set, so the a1=1 global retro-patch
            # mislabeled their sites.
            if self._fn_depth:
                self._note_local(text)
            if self._match("="):
                self._ternary()  # `,` = next declarator, not comma-op
            else:
                self._emit(Op.LOAD_CONST, self._const(None))
            # #81: `var` joins let/const here. Inside a function, for-init
            # STORE_VAR of an undeclared name walks OUT of the frame and
            # writes the caller's binding (method callers alias; FM == RTL
            # agreed on the wrong answer). LET_VAR a1=1 always stores in
            # THIS call env, so re-init every entry still works.
            if self._fn_depth:
                self._emit(Op.LET_VAR, self._name(text), 1)
            else:
                self._emit(_decl, self._name(text))
            # For (let i = 0, j = n; ...) extra declarators
            while self._match(","):
                kind, text, line = self._advance()
                if kind != "ID":
                    raise CompileError("EXPECTED IDENTIFIER", line)
                if self._fn_depth:
                    self._note_local(text)  # #81: same as first declarator
                if self._match("="):
                    self._ternary()
                else:
                    self._emit(Op.LOAD_CONST, self._const(None))
                if self._fn_depth:  # #81: var joins let/const (see above)
                    self._emit(Op.LET_VAR, self._name(text), 1)
                else:
                    self._emit(_decl, self._name(text))
        elif self._peek_text() != ";":
            start = len(self.code)
            self._expression()
            self._emit_discard(start)
        self._expect(";")
        loop = len(self.code)
        # cond (empty → true)
        if self._peek_text() != ";":
            jmp_f = self._condition(";")
        else:
            self._emit(Op.LOAD_CONST, self._const(True))
            jmp_f = [self._emit(Op.JUMP_IF_FALSE, 0)]
        self._expect(";")
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
        self._loop_depth += 1
        self._statement()
        self._loop_depth -= 1
        # For-continue lands on the step (must not skip col++/row++)
        cont = len(self.code)
        for j in self.continue_stack.pop():
            self._patch(j, Op.JUMP, cont)
        # emit step by replaying tokens inside a truncated view
        if step_start < step_end:
            saved_i = self.i
            saved_tokens = self.tokens
            self.tokens = saved_tokens[:step_end]
            self.i = step_start
            start = len(self.code)
            self._expression()
            self._emit_discard(start)
            self.tokens = saved_tokens
            self.i = saved_i
        self._emit(Op.JUMP, loop)
        end = len(self.code)
        self._patch_false(jmp_f, end)
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
        # Comma operator (a, b) — INVADERS ctors chain assigns with ,
        start = len(self.code)
        self._ternary()
        while self._match(","):
            self._emit_discard(start)
            start = len(self.code)
            self._ternary()

    def _ternary(self) -> None:
        if self.optimize and self._chain_ahead(self.i, "?"):
            jmp_else = self._cond_or()
            self._expect("?")
            self._ternary()
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch_false(jmp_else, len(self.code))
            self._expect(":")
            self._ternary()
            self._patch(jmp_end, Op.JUMP, len(self.code))
            return
        self._logic_or()
        if self._match("?"):
            jmp_else = self._emit(Op.JUMP_IF_FALSE, 0)
            self._ternary()
            jmp_end = self._emit(Op.JUMP, 0)
            self._patch(jmp_else, Op.JUMP_IF_FALSE, len(self.code))
            self._expect(":")
            self._ternary()
            self._patch(jmp_end, Op.JUMP, len(self.code))

    # A || b — keep a if truthy, else b (short-circuit)
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

    # A && b — keep a if falsy, else b (short-circuit)
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

    # Bitwise | &  (lower precedence than == in our subset; JS is different
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
        # `k in o` → o[k] !== undefined (mk.js). Same-key-undefined
        # property is the only divergence from Chrome; mk.js never stores
        # undefined values in the maps it tests.
        while self._peek_text() == "in":
            self._advance()
            tmp = self._name("__ink")
            self._emit(Op.STORE_VAR, tmp)
            self._term()
            self._emit(Op.LOAD_VAR, tmp)
            self._emit(Op.ARRAY_GET)
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.EQ)
            self._emit(Op.NOT)
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

    def _factor_kind(self, start: int) -> str:
        # Only guaranteed terminal producers; no assumptions about variables,
        # properties, parameters, calls, or their possible later assignments.
        if len(self.code) == start + 1 and self.code[-1][0] == Op.LOAD_CONST:
            value = self.consts[self.code[-1][1]]
            if isinstance(value, str): return "string"
            if isinstance(value, (int, float)) and not isinstance(value, bool): return "number"
        if len(self.code) > start and self.code[-1][0] in (Op.SUB, Op.MUL, Op.DIV, Op.MOD, Op.NEG):
            return "number"
        return "unknown"

    def _in_library(self) -> bool:
        return (self._fn_compiling or "").startswith(_LIBRARY_PREFIXES)

    def _sop_helper(self, name: str):
        """Library helper for a call site, or None (library absent / inside it)."""
        helper = "_jmr_sop_" + name
        if helper in self.functions and not self._in_library():
            return helper
        return None

    def _sop_method_call(self, meth: str, line: int) -> bool:
        """`recv.meth(args)` with recv on the stack; True when compiled here."""
        if meth not in SOP_METHODS or meth in self._getter_call_names:
            return False
        helper = self._sop_helper(meth)
        if helper is None:
            return False
        argc = self._arg_list()
        self._expect(")")
        if argc <= SOP_METHODS[meth]:
            self._emit(Op.CALL_USER, self.functions[helper][0], argc + 1)
        else:
            self._v1_wall(meth, line)
            self._emit_method(meth, argc)
        return True

    def _language_add(self, left="unknown", right="unknown") -> str:
        private = self._in_library()
        proven = left == right and left in ("number", "string")
        site = self._emit(Op.ADD, 0) if not private and not proven else self._emit(Op.ADD)
        if not private and not proven:
            self._concat_sites.append(site)
        return left if proven else "unknown"

    def _term(self) -> None:
        start = len(self.code)
        self._factor()
        kind = self._factor_kind(start)
        while self._peek_text() in ("+", "-"):
            op = self._advance()[1]
            start = len(self.code)
            self._factor()
            right = self._factor_kind(start)
            if op == "+": kind = self._language_add(kind, right)
            else:
                self._emit(Op.SUB)
                kind = "number"

    def _factor(self) -> None:
        self._unary()
        while self._peek_text() in ("*", "/", "%"):
            op = self._advance()[1]
            self._unary()
            if op == "*":
                self._emit(Op.MUL)
            elif op == "%":
                # Real modulo (was silently DIV — bug)
                self._emit(Op.MOD)
            else:
                self._emit(Op.DIV)

    def _compound_indexed(self) -> None:
        operation = self._advance()[1]
        # Retain the evaluated base/key on the operand stack across both getter
        # and RHS calls. Scratch slots are consumed before either can reenter.
        idx = self._name("@update_idx")
        obj = self._name("@update_obj")
        self._emit(Op.STORE_VAR, idx, 1)
        self._emit(Op.DUP)
        self._emit(Op.STORE_VAR, obj, 1)
        self._emit(Op.LOAD_VAR, idx, 1)
        self._emit(Op.LOAD_VAR, obj, 1)
        self._emit(Op.LOAD_VAR, idx, 1)
        self._emit(Op.ARRAY_GET)
        self._ternary()
        if operation == "+=": self._language_add()
        else: self._emit({"-=":Op.SUB,"*=":Op.MUL,"/=":Op.DIV,"%=":Op.MOD}[operation])
        self._emit(Op.ARRAY_SET)

    def _emit_increment(self, operation: str, prefix: bool) -> None:
        """Update one evaluated numeric lvalue, retaining its old postfix value.

        Member base/key copies stay on the operand stack across GET. All
        private temporaries are consumed before SET can invoke a setter.
        Their names cannot collide with source-language identifiers.
        """
        if not self.code:
            raise CompileError("++/-- NEEDS LVALUE", 0)
        target = self.code[-1]
        arithmetic = Op.SUB if operation == "--" else Op.ADD
        if target[0] == Op.LOAD_VAR:
            if not prefix:
                self._emit(Op.DUP)
            self._emit(Op.LOAD_CONST, self._const(1))
            self._emit(arithmetic)
            if prefix:
                self._emit(Op.DUP)
            self._emit(Op.STORE_VAR, target[1])
            return
        if target[0] not in (Op.GET_PROP, Op.ARRAY_GET):
            raise CompileError("++/-- NEEDS LVALUE", 0)
        self.code.pop()
        self.op_lines.pop()
        obj = self._name("@update_obj")
        old = self._name("@update_old")
        indexed = target[0] == Op.ARRAY_GET
        if indexed:
            idx = self._name("@update_idx")
            self._emit(Op.STORE_VAR, idx, 1)
            self._emit(Op.DUP)
            self._emit(Op.STORE_VAR, obj, 1)
            self._emit(Op.LOAD_VAR, idx, 1)
            self._emit(Op.LOAD_VAR, obj, 1)
            self._emit(Op.LOAD_VAR, idx, 1)
            self._emit(Op.ARRAY_GET)
        else:
            self._emit(Op.DUP)
            self._emit(Op.GET_PROP, target[1])
        self._emit(Op.STORE_VAR, old, 1)
        if indexed:
            self._emit(Op.STORE_VAR, idx, 1)
        self._emit(Op.STORE_VAR, obj, 1)
        if not prefix:
            self._emit(Op.LOAD_VAR, old, 1)
        self._emit(Op.LOAD_VAR, obj, 1)
        if indexed:
            self._emit(Op.LOAD_VAR, idx, 1)
        self._emit(Op.LOAD_VAR, old, 1)
        self._emit(Op.LOAD_CONST, self._const(1))
        self._emit(arithmetic)
        self._emit(Op.ARRAY_SET) if indexed else self._emit(Op.SET_PROP, target[1])
        if not prefix:
            self._emit(Op.POP)

    def _unary(self) -> None:
        if self._match("-"):
            self._unary()
            self._emit(Op.NEG)
            return
        # Unary plus (ToNumber) — mk.js `+x + 0.5`. `x - 0` has the
        # same binary64 coercion on both runtimes (strings parse, junk NaN).
        if self._match("+"):
            self._unary()
            self._emit(Op.LOAD_CONST, self._const(0))
            self._emit(Op.SUB)
            return
        if self._match("!"):
            self._unary()
            self._emit(Op.NOT)
            return
        # Typeof x → string tag (PACMAN map checks)
        if self._peek_text() == "typeof":
            self._advance()
            self._unary()
            for type_name in ("undefined", "number", "boolean", "string", "function", "object"):
                self._name(type_name)
            # lower to native typeof
            self._emit(Op.CALL_NATIVE, self._name("typeof"), 1)
            return
        # Prefix ++/-- on simple ID
        if self._peek_text() in ("++", "--"):
            op = self._advance()[1]
            self._call()
            self._emit_increment(op, True)
            return
        self._call()

    def _prepare_method(self, meth: str) -> None:
        if meth in self._getter_call_names:
            self._emit(Op.DUP)
            self._emit(Op.GET_PROP, self._name(meth), 1)

    def _emit_method(self, meth: str, argc: int) -> None:
        """CALL_METHOD, with the run-71 desugars that keep silicon unchanged:
        a.includes(v)  ->  !(a.indexOf(v) < 0)   (the chip has indexOf)."""
        if meth == "includes" and argc == 1 and meth not in self._getter_call_names:
            self._emit(Op.CALL_METHOD, self._name("indexOf"), 1)
            self._emit(Op.LOAD_CONST, self._const(0))
            self._emit(Op.LT)
            self._emit(Op.NOT)
            return
        self._emit(Op.CALL_METHOD, self._name(meth), argc, int(meth in self._getter_call_names))

    def _v1_wall(self, meth: str, line: int) -> None:
        # V1 authoring wall: a method CALL through one of these names would
        # reach a silicon arm the V1.0 chip does not have. A user-defined
        # method with the same name would shadow a builtin that does not
        # exist on V1 silicon either way — refuse at compile time, loudly.
        if meth in V1_WALL_NAMES or meth in _wall_ext_names():
            raise CompileError(
                f"V1 WALL: .{meth}() is not in the V1.0 chip "
                "(see docs/JMR_JS_COMPATIBILITY.md); V1.5 feature",
                line,
            )

    def _call(self) -> None:
        self._primary()
        while True:
            # Optional chaining ?.prop / ?.meth()
            if self._match("?."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME AFTER ?.", line2)
                # recv; DUP; JIF Lnil; <get or call>; JUMP Lend; Lnil leaves recv
                self._emit(Op.DUP)
                jmp_nil = self._emit(Op.JUMP_IF_FALSE, 0)
                if self._match("("):
                    if not self._sop_method_call(meth, line2):
                        self._prepare_method(meth)
                        argc = self._arg_list()
                        self._expect(")")
                        self._v1_wall(meth, line2)
                        self._emit_method(meth, argc)
                else:
                    self._emit(Op.GET_PROP, self._name(meth))
                jmp_end = self._emit(Op.JUMP, 0)
                self._patch(jmp_nil, Op.JUMP_IF_FALSE, len(self.code))
                self._patch(jmp_end, Op.JUMP, len(self.code))
                continue
            # Postfix property get / method / assign
            if self._match("."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME", line2)
                if self._match("("):
                    if self._sop_method_call(meth, line2):
                        continue
                    # Always CALL_METHOD — VM handles class + array/string builtins
                    self._prepare_method(meth)
                    argc = self._arg_list()
                    self._expect(")")
                    self._v1_wall(meth, line2)
                    self._emit_method(meth, argc)
                    continue
                if self._match("="):
                    self._ternary()  # `,` is not part of the RHS
                    self._emit(Op.SET_PROP, self._name(meth))
                    continue
                if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    op = self._advance()[1]
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    self._ternary()
                    if op == "+=":
                        self._language_add()
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
                # Obj.prop++ / obj.prop-- (this.moveClock++ in INVADERS)
                if self._peek_text() in ("++", "--"):
                    self._emit_increment(self._advance()[1], False)
                continue
            # Computed member obj[expr] (DONKEY rollingRight[loopIndex])
            if self._match("["):
                self._expression()
                self._expect("]")
                if self._match("="):
                    self._ternary()  # `,` is not part of the RHS
                    self._emit(Op.ARRAY_SET)
                elif self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    self._compound_indexed()
                else:
                    self._emit(Op.ARRAY_GET)
                continue
            # Call value on stack — IIFE / (fn)()
            if self._match("("):
                # Tag `(function(){...})()` — the callee MAKE_FN is the
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
                self._emit_increment(self._advance()[1], False)
                continue
            break

    def _primary(self) -> None:
        t = self._peek()
        if t is None:
            raise CompileError("UNEXPECTED EOF", 0)
        kind, text, line = t
        if kind == "NUM":
            self._advance()
            val: Any = _num_value(text)
            self._emit(Op.LOAD_CONST, self._const(val))
            return
        # /regex/ → RegExp stub (PACMAN polyfill .test)
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
        # Single-quoted strings
        if kind == "STR2":
            self._advance()
            raw = text[1:-1].encode("utf-8").decode("unicode_escape")
            self._emit(Op.LOAD_CONST, self._const(raw))
            return
        # Template literals `a ${expr} b` → concat
        if kind == "TMPL":
            self._advance()
            inner = text[1:-1]
            self._emit_template(inner)
            return
        if text in ("true", "false", "null", "undefined"):
            self._advance()
            mapping = {"true": True, "false": False, "null": None, "undefined": None}
            index = self._const(mapping[text])
            if text == "null":
                self._null_consts.add(index)
            self._emit(Op.LOAD_CONST, index)
            return
        # This → hidden __this binding (set by NEW_OBJ / CALL_METHOD)
        if text == "this":
            self._advance()
            self._emit(Op.LOAD_VAR, self._name("__this"))
            return
        # Function expression function(a){...} / function name(a){...}
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
        # New ClassName(args)
        if text == "new":
            self._advance()
            k2, cname, ln2 = self._advance()
            if k2 != "ID":
                raise CompileError("EXPECTED CLASS NAME AFTER new", ln2)
            self._expect("(")
            argc = self._arg_list()
            self._expect(")")
            # Built-in Date stub (leaderboard timestamps)
            if cname == "Date":
                self._emit(Op.CALL_NATIVE, self._name("Date"), argc)
                return
            if cname == "Image":
                self._emit(Op.CALL_NATIVE, self._name("Image"), argc)
                return
            # Synthetic event ctors desugar to an object literal +
            # Object.assign — `new KeyboardEvent(T, O)` becomes
            # `Object.assign({type: T}, O)`. The tagged RTL had a native
            # NEW_OBJ arm for these; Value64 never did (DONKEY's synthetic
            # boot Enter faulted 1 at script end). MAKE_OBJ / SET_PROP /
            # CALL_METHOD assign are proven on both runtimes.
            if cname in ("KeyboardEvent", "Event", "CustomEvent",
                         "MouseEvent"):
                t_type = self._name("__evt")
                t_opts = self._name("__evo")
                for _ in range(max(0, argc - 2)):
                    self._emit(Op.POP)
                if argc >= 2:
                    self._emit(Op.STORE_VAR, t_opts)
                if argc >= 1:
                    self._emit(Op.STORE_VAR, t_type)
                self._emit(Op.MAKE_OBJ)
                if argc >= 1:
                    self._emit(Op.DUP)
                    self._emit(Op.LOAD_VAR, t_type)
                    self._emit(Op.SET_PROP, self._name("type"))
                    self._emit(Op.POP)
                if argc >= 2:
                    self._emit(Op.DUP)
                    self._emit(Op.DUP)
                    self._emit(Op.LOAD_VAR, t_opts)
                    self._emit(Op.CALL_METHOD, self._name("assign"), 2)
                    self._emit(Op.POP)
                return
            # New Foo() when Foo is a function (PACMAN Item/Map) or unknown soft stub
            if cname not in self.classes:
                if cname in self.functions:
                    entry, _params = self.functions[cname]
                    self.classes[cname] = {"ctor": entry, "methods": {}}
                else:
                    self.classes[cname] = {"ctor": None, "methods": {}}
            self._emit(Op.NEW_OBJ, self._name(cname), argc)
            return
        if kind == "ID":
            # X => expr  (single-param arrow)
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
                if native in SOP_DOTTED and self._peek_text() == "(" and self._sop_helper(SOP_DOTTED[native]):
                    self._expect("(")
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_USER, self.functions["_jmr_sop_" + SOP_DOTTED[native]][0], argc)
                    return
                if native in ("JSON.parse", "JSON.stringify") and self._peek_text() == "(":
                    helper = "_jmr_json_jsonParseNative" if meth == "parse" else "_jmr_json_jsonStringifyNative"
                    if helper not in self.functions:
                        raise CompileError("JSON runtime must be included through compile_source", line)
                    self._expect("(")
                    argc = self._arg_list()
                    self._expect(")")
                    self._emit(Op.CALL_USER, self.functions[helper][0], argc)
                    return

                if native in ("localStorage.getItem", "localStorage.setItem", "localStorage.removeItem") and self._peek_text() == "(":
                    self._expect("(")
                    load_ip = self._emit(Op.LOAD_VAR, self._name(text))
                    prepare_start = len(self.code)
                    # Use the same getter/receiver preparation as ordinary
                    # object methods when this compiler supports CALL_REF.
                    if hasattr(self, "_prepare_method"):
                        self._prepare_method(meth)
                    prepare_ips = tuple(range(prepare_start, len(self.code)))
                    argc = self._arg_list()
                    self._expect(")")
                    call_ip = len(self.code)
                    self._emit_method(meth, argc)
                    self._storage_call_sites.append((load_ip, prepare_ips, call_ip, argc, meth, tuple(self._scope_sets)))
                    return

                # Math.PI property (no call) — HTML titles use it
                if native == "Math.PI" and self._peek_text() != "(":
                    import math

                    self._emit(Op.LOAD_CONST, self._const(math.pi))
                    return
                if self._peek_text() == "(":
                    self._expect("(")
                    # Math.* / console.* / document.* stay natives
                    if native in ("Object.keys", "Array.isArray") or text in ("Math", "console", "document", "window", "localStorage", "JSON"):
                        argc = self._arg_list()
                        self._expect(")")
                        self._v1_wall(native.split(".", 1)[-1], line)
                        self._emit(Op.CALL_NATIVE, self._name(native), argc)
                        return
                    self._emit(Op.LOAD_VAR, self._name(text))
                    if self._sop_method_call(meth, line):
                        return
                    self._prepare_method(meth)
                    argc = self._arg_list()
                    self._expect(")")
                    self._v1_wall(meth, line)
                    self._emit_method(meth, argc)
                    return
                # bare ID.prop — load var then GET_PROP (e.g. player.x)
                self._emit(Op.LOAD_VAR, self._name(text))
                if self._match("="):
                    self._ternary()  # `,` is not part of the RHS
                    self._emit(Op.SET_PROP, self._name(meth))
                    return
                # ID.prop += expr (was falling through and choking on +=)
                if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    op = self._advance()[1]
                    self._emit(Op.DUP)
                    self._emit(Op.GET_PROP, self._name(meth))
                    self._ternary()
                    if op == "+=":
                        self._language_add()
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
                # ID.prop++ / ID.prop-- must write back. Bare `item.timeout--`
                # was returning here; `_call`'s leftover GET_PROP postfix only
                # subtracted on the stack, so PACMAN's engine never ticked NPC
                # timeouts and ghosts never left the house.
                if self._peek_text() in ("++", "--"):
                    self._emit_increment(self._advance()[1], False)
                return
            if self._match("("):
                if (text in SOP_CALLS and text not in self.functions and
                        not self._lexically_bound(text) and self._sop_helper(text)):
                    argc = self._arg_list()
                    self._expect(")")
                    if text == "Number" and argc == 0:
                        self._emit(Op.LOAD_CONST, self._const(0))
                    else:
                        self._emit(Op.CALL_USER, self.functions["_jmr_sop_" + text][0], argc)
                    return
                if text == "String":
                    load_ip = self._emit(Op.LOAD_VAR, self._name(text))
                    argc = self._arg_list()
                    self._expect(")")
                    call_ip = self._emit(Op.CALL_VAL, argc)
                    self._string_call_sites.append((load_ip, call_ip, argc, tuple(self._scope_sets)))
                    return
                # Known `function foo()` → CALL_USER. Known natives stay
                # CALL_NATIVE. Anything else is a first-class Fn in a var
                # (`var rec = function(){ rec(); }` / nested `_render()`).
                # JSB CALL_NATIVE encodes a numeric id and drops the name, so
                # unknown ID( must not become stub 33 — LOAD_VAR + CALL_VAL.
                if text in self.functions and not self._lexically_bound(text):
                    argc = self._arg_list()
                    self._expect(")")
                    entry, params = self.functions[text]
                    # Tiny param-only callees run in the caller (no CALL_USER
                    # env alloc). Sprite palettes and in-bounds checks.
                    if not self._try_inline_user_call(text, argc):
                        self._emit(Op.CALL_USER, entry, argc)
                elif not self._lexically_bound(text) and (text in NATIVE_IDS or text in NATIVE_ALIASES or text in _HOST_NATIVES):
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
                    self._ternary()  # `,` is not part of the RHS
                    self._emit(Op.ARRAY_SET)
                    # ARRAY_SET already leaves the assigned value for the
                    # surrounding expression/statement to consume.
                elif self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                    self._compound_indexed()
                else:
                    self._emit(Op.ARRAY_GET)
                return
            # Compound assignment += -= *= /= %=
            if self._peek_text() in ("+=", "-=", "*=", "/=", "%="):
                op = self._advance()[1]
                ni = self._name(text)
                self._emit(Op.LOAD_VAR, ni)
                self._ternary()  # `,` is not part of the RHS
                if op == "+=":
                    self._language_add()
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
                # _ternary not _expression — assignment binds tighter
                # than the comma operator (PACMAN `_LIFE = 5, _SCORE = 0`)
                self._ternary()
                self._emit(Op.STORE_VAR, self._name(text))
                self._emit(Op.LOAD_VAR, self._name(text))
                return
            self._emit(Op.LOAD_VAR, self._name(text))
            return
        if self._match("("):
            # (a, b) => expr   vs   (expr)
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
                    # Trailing comma in arrays (DONKEY platforms)
                    if self._peek_text() == "]":
                        break
                    self._ternary()
                    n += 1
            self._expect("]")
            self._emit(Op.MAKE_ARRAY, n)
            return
        # Object literal { k: expr, ... } or shorthand { k }
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
                            # Shorthand { position } → { position: position }
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
        # Match the runtime's existing flat top-level zero-argument IIFE mode
        # before allocating local-slot hints or hoisting its declarations.
        flat_module=False
        if not is_arrow and not params and self._fn_depth==0 and self._peek_text()=="{":
            j=self.i;depth=0
            while j<len(self.tokens):
                text=self.tokens[j][1];depth+=(text=="{")-(text=="}");j+=1
                if depth==0:break
            while j<len(self.tokens) and self.tokens[j][1]==")":j+=1
            flat_module=j+1<len(self.tokens) and self.tokens[j][1]=="(" and self.tokens[j+1][1]==")"
        jmp_over = self._emit(Op.JUMP, 0)
        entry = len(self.code)
        self._enter_local_frame()
        self._scope_sets.append(set())
        if flat_module:self._flat_module_frames.add(len(self._local_stack))
        # Params declare into the per-call env (LET_VAR); arg2=1 =
        # call-frame local flag for RTL (always store there)
        for p in reversed(params):
            self._note_local(p)
            self._emit(Op.LET_VAR, self._name(p), 1)
        self._fn_depth += 0 if flat_module else 1
        if self._peek_text() == "{":
            self._expect("{")
            self._begin_body()
            self.i -= 1
            self._block(function_scope=True)
            self._emit(Op.LOAD_CONST, self._const(None))
            self._emit(Op.RET_VAL)
        else:
            # #39: an expression-bodied arrow inside an argument list must
            # stop at the argument comma — _expression's comma operator ate
            # `, 0` in `arr.reduce((t, g) => t + g.n, 0)`: the init became
            # part of the arrow body (callback returned 0, argc dropped to
            # 1). Arrow bodies parse at assignment level, like arguments.
            self._ternary()
            self._emit(Op.RET_VAL)
        self._fn_depth -= 0 if flat_module else 1
        self._flat_module_frames.discard(len(self._local_stack))
        self._end_body()
        if self._local_stack:
            self._leave_local_frame()
        if self._scope_sets:
            self._scope_sets.pop()
        self._patch(jmp_over, Op.JUMP, len(self.code))
        self._emit(Op.MAKE_FN, entry, len(params), 1 if is_arrow else 0)

    def _arg_list(self) -> int:
        # Use _ternary not _expression so ',' separates args (not comma-op)
        if self._peek_text() == ")":
            return 0
        self._ternary()
        n = 1
        while self._match(","):
            # Trailing comma in calls
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
                    self._language_add()
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
                    self._language_add()
                else:
                    first = False
        if first:
            self._emit(Op.LOAD_CONST, self._const(""))



def prepare_storage_source(src: str) -> str:
    """Append shared storage software only for supported localStorage calls.

    Call once in unified source preparation, before resident linking. The caller
    supplies the shared _jmr_json_stringCoerceNative dependency through the same
    JSON/String preparation path. Direct Compiler users must prepare explicitly.
    """
    tokens = _tokenize(src)
    needs_storage = any(tokens[i][1] == "localStorage" and tokens[i+1][1] == "." and
                        tokens[i+2][1] in ("getItem", "setItem", "removeItem")
                        for i in range(len(tokens)-2))
    if not needs_storage:
        return src
    if any(kind == "ID" and text.startswith("_jmr_store_") for kind, text, *_ in tokens):
        raise CompileError("reserved storage runtime identifier", 0)
    from pathlib import Path
    return Path(__file__).with_name("storage_runtime.js").read_text() + "\n" + src


def prepare_software_source(src: str, *, proof_compiler=None) -> str:
    """Select one shared String/JSON dependency graph before either host path."""
    tokens = _tokenize(src)
    if any(kind == "ID" and text.startswith(_LIBRARY_PREFIXES)
           for kind, text, *_ in tokens):
        raise CompileError("reserved software runtime identifier", 0)
    needs_sop, needs_join = sop_needs(tokens)
    needs_json = any(tokens[i][1] == "JSON" and tokens[i+1][1] == "." and
                     tokens[i+2][1] in ("parse", "stringify")
                     for i in range(len(tokens)-2))
    needs_storage = any(tokens[i][1] == "localStorage" and tokens[i+1][1] == "." and
                        tokens[i+2][1] in ("getItem", "setItem", "removeItem")
                        for i in range(len(tokens)-2))
    from pathlib import Path
    source = Path(__file__).parent
    # The library is part of what the mixed-ADD proof sees, exactly as it is
    # on the machine, where the proof runs over the program with it linked.
    if needs_sop:
        src = (source / "strops_runtime.js").read_text() + "\n" + src
    if proof_compiler is None:
        probe = Compiler(src)
    else:
        import copy
        probe = copy.deepcopy(proof_compiler)
        probe.tokens = _isolate_iife_modules(_tokenize(src)); probe.i = 0
        probe.optimize = True
    probe._runtime_probe = True
    for name in ("_jmr_json_jsonParseNative", "_jmr_json_jsonStringifyNative",
                 "_jmr_store_getItem", "_jmr_store_setItem", "_jmr_store_removeItem"):
        probe.functions[name] = (0, [])
    probe.compile()
    needs_storage = probe._needs_storage_runtime
    needs_concat = probe._needs_concat_runtime
    # The library's join turns non-integer numbers into text with String().
    needs_string = needs_storage or probe._needs_string_runtime or needs_concat or needs_join
    if needs_storage:
        src = prepare_storage_source(src)
    if needs_json or needs_string:
        filename = ("both_runtime.js" if needs_json and needs_string else
                    "json_runtime.js" if needs_json else "string_runtime.js")
        src = (source / filename).read_text() + "\n" + src
    return src


def compile_source(src: str) -> Chunk:
    compiler = Compiler(prepare_software_source(src))
    compiler._require_concat_helper = True
    return compiler.compile()
