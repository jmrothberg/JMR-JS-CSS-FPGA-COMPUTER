"""Tiny JS subset compiler → JMR-JS bytecode.

Supports: numbers, strings, lets, arithmetic, comparisons, if/while,
function calls to natives (console.log, fillRect, clearRect, swap, joy).
Not a full JS parser — grow from compatibility matrix only.
"""

from __future__ import annotations

import re
from typing import Any, List, Optional, Tuple

from .bytecode import Chunk, Op


class CompileError(Exception):
    def __init__(self, message: str, line: int = 0) -> None:
        super().__init__(message)
        self.line = line
        self.message = message


_TOKEN = re.compile(
    r"""
    (?P<WS>\s+) |
    (?P<LINE_COMMENT>//[^\n]*) |
    (?P<STR>"([^"\\]|\\.)*") |
    (?P<NUM>\d+(\.\d+)?) |
    (?P<ID>[A-Za-z_][A-Za-z0-9_]*) |
    (?P<OP>==|!=|<=|>=|&&|\|\||[+\-*/%<>=!();{},.\[\]])
    """,
    re.VERBOSE,
)


def _tokenize(src: str) -> List[Tuple[str, str, int]]:
    tokens: List[Tuple[str, str, int]] = []
    line = 1
    pos = 0
    while pos < len(src):
        if src[pos] == "\n":
            line += 1
            pos += 1
            continue
        m = _TOKEN.match(src, pos)
        if not m:
            raise CompileError(f"UNEXPECTED TOKEN near {src[pos:pos+10]!r}", line)
        kind = m.lastgroup or ""
        text = m.group(0)
        pos = m.end()
        if kind in ("WS", "LINE_COMMENT"):
            line += text.count("\n")
            continue
        tokens.append((kind, text, line))
    return tokens


class Compiler:
    def __init__(self, src: str) -> None:
        self.tokens = _tokenize(src)
        self.i = 0
        self.consts: List[Any] = []
        self.names: List[str] = []
        self.name_index: dict[str, int] = {}
        self.code: List[Tuple] = []

    def compile(self) -> Chunk:
        while not self._done():
            self._statement()
        return Chunk(self.code, self.consts, self.names)

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
        self.code.append(tuple(op_args))
        return len(self.code) - 1

    def _patch(self, idx: int, *op_args: Any) -> None:
        self.code[idx] = tuple(op_args)

    def _statement(self) -> None:
        t = self._peek()
        if t is None:
            return
        kind, text, line = t
        if text in ("let", "var", "const"):
            self._advance()
            self._var_decl()
            self._match(";")
            return
        if text == "if":
            self._if_stmt()
            return
        if text == "while":
            self._while_stmt()
            return
        if text == "{":
            self._block()
            return
        # expression statement
        self._expression()
        self._emit(Op.POP)
        self._match(";")

    def _var_decl(self) -> None:
        kind, text, line = self._advance()
        if kind != "ID":
            raise CompileError("EXPECTED IDENTIFIER", line)
        self._expect("=")
        self._expression()
        self._emit(Op.LET_VAR, self._name(text))

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
        self._statement()
        self._emit(Op.JUMP, loop)
        self._patch(jmp_f, Op.JUMP_IF_FALSE, len(self.code))

    def _expression(self) -> None:
        self._equality()

    def _equality(self) -> None:
        self._comparison()
        while self._peek_text() in ("==", "!="):
            op = self._advance()[1]
            self._comparison()
            self._emit(Op.EQ)
            if op == "!=":
                self._emit(Op.NOT)

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
        self._call()

    def _call(self) -> None:
        self._primary()

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
        if kind == "STR":
            self._advance()
            raw = text[1:-1].encode("utf-8").decode("unicode_escape")
            self._emit(Op.LOAD_CONST, self._const(raw))
            return
        if text in ("true", "false", "null", "undefined"):
            self._advance()
            mapping = {"true": True, "false": False, "null": None, "undefined": None}
            self._emit(Op.LOAD_CONST, self._const(mapping[text]))
            return
        if kind == "ID":
            self._advance()
            # console.log / Math.floor / fillRect / joy / swapBuffers
            if self._match("."):
                kind2, meth, line2 = self._advance()
                if kind2 != "ID":
                    raise CompileError("EXPECTED NAME", line2)
                native = f"{text}.{meth}"
                self._expect("(")
                argc = self._arg_list()
                self._expect(")")
                self._emit(Op.CALL_NATIVE, self._name(native), argc)
                return
            if self._match("("):
                native = text
                argc = self._arg_list()
                self._expect(")")
                self._emit(Op.CALL_NATIVE, self._name(native), argc)
                return
            if self._match("["):
                self._emit(Op.LOAD_VAR, self._name(text))
                self._expression()
                self._expect("]")
                if self._match("="):
                    self._expression()
                    self._emit(Op.ARRAY_SET)
                    # ARRAY_SET consumes arr,idx,val — leave undefined
                    self._emit(Op.LOAD_CONST, self._const(None))
                else:
                    self._emit(Op.ARRAY_GET)
                return
            if self._match("="):
                self._expression()
                self._emit(Op.STORE_VAR, self._name(text))
                self._emit(Op.LOAD_VAR, self._name(text))
                return
            self._emit(Op.LOAD_VAR, self._name(text))
            return
        if self._match("("):
            self._expression()
            self._expect(")")
            return
        if self._match("["):
            n = 0
            if self._peek_text() != "]":
                self._expression()
                n = 1
                while self._match(","):
                    self._expression()
                    n += 1
            self._expect("]")
            self._emit(Op.MAKE_ARRAY, n)
            return
        raise CompileError(f"UNEXPECTED {text!r}", line)

    def _arg_list(self) -> int:
        if self._peek_text() == ")":
            return 0
        self._expression()
        n = 1
        while self._match(","):
            self._expression()
            n += 1
        return n


def compile_source(src: str) -> Chunk:
    return Compiler(src).compile()
