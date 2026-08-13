"""Minimal JMR-JS bytecode + interpreter (stack machine).

LLM NOTE: Encoding not frozen — grow only for demos / compatibility matrix.
Opcodes are multi-cycle in spirit; FM runs them immediately.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Any, Callable, Dict, List, Optional, Tuple


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


@dataclass
class Chunk:
    code: List[Tuple]  # (op, *args)
    consts: List[Any]
    names: List[str]


class VM:
    """Tiny stack VM with native hooks for console / canvas / joy."""

    def __init__(
        self,
        natives: Optional[Dict[str, Callable[..., Any]]] = None,
    ) -> None:
        self.natives = natives or {}
        self.globals: Dict[str, Any] = {}
        self.stack: List[Any] = []
        self.halted = False
        self.error: Optional[str] = None

    def reset_run(self) -> None:
        self.stack.clear()
        self.halted = False
        self.error = None

    def run(self, chunk: Chunk, max_steps: int = 1_000_000) -> None:
        self.reset_run()
        ip = 0
        code = chunk.code
        steps = 0
        while ip < len(code) and not self.halted and steps < max_steps:
            steps += 1
            op, *args = code[ip]
            ip += 1
            if op == Op.LOAD_CONST:
                self.stack.append(chunk.consts[args[0]])
            elif op == Op.LOAD_VAR:
                name = chunk.names[args[0]]
                self.stack.append(self.globals.get(name))
            elif op == Op.STORE_VAR:
                name = chunk.names[args[0]]
                self.globals[name] = self.stack.pop()
            elif op == Op.LET_VAR:
                # LLM NOTE: let/const under startLoop — do not reset each frame.
                name = chunk.names[args[0]]
                val = self.stack.pop()
                if name not in self.globals:
                    self.globals[name] = val
            elif op == Op.ADD:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a + b)
            elif op == Op.SUB:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a - b)
            elif op == Op.MUL:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a * b)
            elif op == Op.DIV:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a / b if b else 0)
            elif op == Op.LT:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a < b)
            elif op == Op.GT:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a > b)
            elif op == Op.EQ:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append(a == b)
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
                    # Help stale-process debugging — list what this VM actually has.
                    have = ",".join(sorted(self.natives)) or "(none)"
                    self.error = f"ERROR: UNKNOWN NATIVE {name} (have: {have})"
                    self.halted = True
                    return
                result = fn(*argv)
                if result is not None:
                    self.stack.append(result)
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
                idx = int(self.stack.pop())
                arr = self.stack.pop()
                self.stack.append(arr[idx])
            elif op == Op.ARRAY_SET:
                val = self.stack.pop()
                idx = int(self.stack.pop())
                arr = self.stack.pop()
                arr[idx] = val
            else:
                self.error = f"ERROR: BAD OPCODE {op}"
                self.halted = True
                return
        if steps >= max_steps:
            self.error = "ERROR: STEP LIMIT"
            self.halted = True
