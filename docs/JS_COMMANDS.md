# JavaScript you can write — and the instructions it becomes

Words: [README.md — Words used](../README.md#words-used-in-this-project).

This is the page to **learn the machine**.  
Title status and version-2.0 holes live in [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md).  
Block diagram: [ARCHITECTURE.md](ARCHITECTURE.md).

On the BASIC sibling, every keyword **is** one instruction (`PRINT` = `0x81`).  
Here JavaScript **source** is compiled into a smaller numbered
**instruction set architecture** (ISA). **V1.0:** compile when you **make
the card** (`NAME.JSH` on `card.img`); PYTHON / FPGA-SIM / BOARD all `RUN`
that image. The chip fetches bytecode. **V1.5 compile is live:** `LOAD` →
`EDIT` → **`COMPILE`** → `RUN`. `RUN` still loads `.JSH`. Same idea: the
language **is** the processor.

---

## Words used on this page

| Phrase | Meaning |
|---|---|
| **JavaScript-native CPU** | This computer. You write JavaScript. The chip runs JavaScript. No hidden Z80, RISC-V, V8, or browser. |
| **Instruction set architecture (ISA)** | The 34 numbered instructions the processor fetches. Same numbers in Python and on the chip. |
| **Opcode** | One instruction number (1–34). There is no opcode 0. |
| **Functional model** | The Python program that is the truth for “what this instruction does.” |
| **Native** | A built-in function the compiler already knows (`Math.floor`, `console.log`). It becomes instruction 13 plus an **id**. |
| **Method** | A call on a value (`c.fillRect(…)`, `arr.push(…)`). It becomes instruction 30 plus the method **name**. |
| **Program image** | The compiled program sitting in memory after `RUN` (code + **ASET** art). Not a file you type. |
| **READY console** | The `>` prompt: `LOAD`, `RUN`, `LIST`. Those are **not** JavaScript. |
| **FPGA-SIM** | The same chip RTL simulated (not a browser, not Python pretending). |

---

## What happens when you type RUN

**V1.0 (PYTHON / FPGA-SIM / BOARD — same `card.img`):**

```
storage/NAME.HTML  (seed — author here)
    →  make_sd_image.py create card.img   (compiler mints NAME.JSH)
    →  LOAD "NAME.HTML"   (FAT HTML for LIST)
    →  RUN                (minted NAME.JSH → JMR VM)
```

The chip has no compiler. Rebuild `card.img` after you edit `storage/`.

**V1.5 compile is live:** `LOAD` → `EDIT` → **`COMPILE`** → `RUN`. `RUN`
still loads `.JSH` from the card. Compiler/editor are ordinary card
programs, not a new ISA. Typed-at-READY numbered authoring of *new*
programs, and popular JS V1.0 does not have, are leftover — see
[JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).

You never type opcode numbers. You type JavaScript. The compiler emits the numbers.

---

## The whole instruction set (34)

Source of the numbers: `functional_model/bytecode.py` (`Op`).

| # | Name | What it does in one line |
|---|---|---|
| 1 | `LOAD_CONST` | Push a number, string, `true` / `false` / `null` / `undefined`. |
| 2 | `LOAD_VAR` | Push the value of a variable. |
| 3 | `STORE_VAR` | Pop a value and write it to a variable. |
| 4 | `ADD` | Pop two values; push `a + b` (numbers or string concat). |
| 5 | `SUB` | Subtract. |
| 6 | `MUL` | Multiply. |
| 7 | `DIV` | Divide. |
| 8 | `LT` | Less than. |
| 9 | `GT` | Greater than. |
| 10 | `EQ` | Equal (`==` and `===` both become this). |
| 11 | `JUMP` | Go to another instruction (unconditional). |
| 12 | `JUMP_IF_FALSE` | If the top of stack is falsey, jump. Used by `if`, `while`, `for`, `&&`, `\|\|`. |
| 13 | `CALL_NATIVE` | Call a built-in function. The **id** is in the instruction (table below). |
| 14 | `RETURN` | Return from a function with no value. |
| 15 | `POP` | Throw away the top of stack. |
| 16 | `DUP` | Duplicate the top of stack. |
| 17 | `NEG` | Negate (`-x`). |
| 18 | `NOT` | Logical not (`!x`). |
| 19 | `MAKE_ARRAY` | Create `[…]`. |
| 20 | `ARRAY_GET` | Read `arr[i]` or `obj[expr]`. |
| 21 | `ARRAY_SET` | Write `arr[i] = …`. |
| 22 | `LET_VAR` | First write of `let` / `var` / `const`. |
| 23 | `MOD` | Remainder (`%`). |
| 24 | `CALL_USER` | Call a function you wrote (`function foo()`). |
| 25 | `RET_VAL` | Return a value. |
| 26 | `MAKE_OBJ` | Create `{…}`. |
| 27 | `GET_PROP` | Read `obj.x`. |
| 28 | `SET_PROP` | Write `obj.x = …`. |
| 29 | `NEW_OBJ` | `new Foo(…)`. |
| 30 | `CALL_METHOD` | `obj.method(…)`. |
| 31 | `BIT_OR` | Bitwise `\|`. |
| 32 | `BIT_AND` | Bitwise `&`. |
| 33 | `MAKE_FN` | Create a function value (`function`, `=>`). |
| 34 | `CALL_VAL` | Call a function sitting on the stack (`fn()`, immediately-invoked function). |

That is the entire instruction set. Everything you can write is one of these, or a short sequence of these.

---

## Learn by example

### Example 1 — variable, compare, print

```javascript
let x = 3;
if (x > 1) {
  console.log(x);
}
```

becomes:

```
LOAD_CONST      3
LET_VAR         x
LOAD_VAR        x
LOAD_CONST      1
GT
JUMP_IF_FALSE   (skip the log)
LOAD_VAR        x
CALL_NATIVE     console.log     (id 0)
POP
```

`if` is not its own opcode. It is `JUMP_IF_FALSE`.

### Example 2 — built-in function

```javascript
Math.floor(3.7)
```

becomes:

```
LOAD_CONST      3.7
CALL_NATIVE     Math.floor      (id 10)
```

### Example 3 — method on a canvas

```javascript
c.fillRect(0, 0, 10, 10);
```

becomes:

```
LOAD_VAR        c
LOAD_CONST      0
LOAD_CONST      0
LOAD_CONST      10
LOAD_CONST      10
CALL_METHOD     fillRect        (4 arguments)
```

Same JavaScript name (`fillRect`). Different instruction: **method** (30), not **native** (13), because it is `c.fillRect`, not a bare `fillRect(…)`.

### Example 4 — your own function

```javascript
function add(a, b) { return a + b; }
add(1, 2);
```

becomes `MAKE_FN` for the body, then `CALL_USER` at the call site, then `ADD` and `RET_VAL` inside.

---

## Language → instructions

| You write | Instructions |
|---|---|
| `42` / `"hi"` / `true` / `false` / `null` / `undefined` | `LOAD_CONST` (1) |
| `/regex/` | `LOAD_CONST` (1) — regular-expression stub |
| `` `a ${x} b` `` | `LOAD_CONST` + `LOAD_VAR` + `ADD` (concat) |
| `x` | `LOAD_VAR` (2) |
| `this` | `LOAD_VAR` of hidden `__this` |
| `x = …` | `STORE_VAR` (3) |
| `let` / `var` / `const` `x = …` | `LET_VAR` (22) |
| `+` `-` `*` `/` `%` | `ADD` `SUB` `MUL` `DIV` `MOD` (4–7, 23) |
| `<` `>` `==` `===` `!=` `!==` | `LT` `GT` `EQ` (8–10); not-equal is `EQ` then `NOT` |
| `<=` `>=` | `GT`/`LT` then `NOT` (or the compare the compiler emits) |
| `\|` `&` | `BIT_OR` (31) `BIT_AND` (32) |
| `-x` `!x` | `NEG` (17) `NOT` (18) |
| `x++` / `++x` / `+=` `-=` `*=` `/=` `%=` | load, arithmetic, store |
| `if` / `else` / `while` / `for (;;)` | `JUMP` (11) `JUMP_IF_FALSE` (12) |
| `&&` / `\|\|` | `JUMP_IF_FALSE` / `JUMP` (short-circuit) |
| `break` / `continue` | `JUMP` (11) |
| `for (k in obj)` | `CALL_NATIVE` `Object.keys` (id 41) + an index loop |
| `for (x of arr)` | index loop: `GET_PROP` `length`, `LT`, `ARRAY_GET`, jumps |
| `[a, b]` | `MAKE_ARRAY` (19) |
| `arr[i]` / `arr[i] = …` / `obj[expr]` | `ARRAY_GET` (20) / `ARRAY_SET` (21) |
| `{a: 1}` | `MAKE_OBJ` (26) + `SET_PROP` (28) |
| `obj.x` / `obj.x = …` | `GET_PROP` (27) / `SET_PROP` (28) |
| `obj?.x` / `obj?.m()` | `DUP` + `JUMP_IF_FALSE` + get or `CALL_METHOD` |
| `function` / `=>` | `MAKE_FN` (33) |
| `foo()` when you wrote `function foo` | `CALL_USER` (24) |
| `fn()` when `fn` is a value | `CALL_VAL` (34) |
| `return` | `RET_VAL` (25) or `RETURN` (14) |
| `new Foo(…)` | `NEW_OBJ` (29) |
| `new Date(…)` / `new Image(…)` | `CALL_NATIVE` ids 25 / 26 |
| `new KeyboardEvent(…)` (and Event / CustomEvent / MouseEvent) | `MAKE_OBJ` + `SET_PROP` + `CALL_METHOD` `assign` |
| `typeof x` | `CALL_NATIVE` id 40 |
| `class` / `import` / `export` | flattened into the same instructions (not extra opcodes) |

---

## Built-in functions → `CALL_NATIVE` (13) + id

Bare names the compiler already knows. Source of the ids: `functional_model/jsb_format.py` (`NATIVE_IDS`).

| You write | Id |
|---|---|
| `console.log` / `console.warn` | 0 |
| `clear` | 1 |
| `fillRect` (bare call, not `c.fillRect`) | 2 |
| `swapBuffers` | 3 |
| `keyLeft` | 4 |
| `keyRight` | 5 |
| `keyFire` | 6 |
| `startLoop` | 7 |
| `keyUp` | 8 |
| `keyDown` | 9 |
| `Math.floor` | 10 |
| `Math.abs` | 11 |
| `Math.min` | 12 |
| `Math.max` | 13 |
| `Math.random` | 14 |
| `Math.sqrt` | 15 |
| `document.getElementById` | 16 |
| `document.querySelector` | 17 |
| `document.createElement` | 18 |
| `document.addEventListener` / bare `addEventListener` | 19 |
| `window.addEventListener` | 20 |
| `localStorage.getItem` | 21 |
| `localStorage.setItem` | 22 |
| `JSON.parse` | 23 |
| `JSON.stringify` | 24 |
| `Date` / `new Date` | 25 |
| `Image` / `new Image` | 26 |
| `requestAnimationFrame` | 27 |
| `setTimeout` | 28 |
| `setInterval` | 29 |
| `clearTimeout` | 30 |
| `clearInterval` | 31 |
| `localStorage.removeItem` | 32 |
| unknown name / `window.open` | 33 (does nothing) |
| `Array` | 34 |
| `Date.now` | 35 |
| `document.removeEventListener` / bare `removeEventListener` | 36 |
| `window.removeEventListener` | 37 |
| `document.dispatchEvent` | 38 |
| `window.dispatchEvent` | 39 |
| `typeof` | 40 |
| `Object.keys` | 41 |
| `sound` | 42 |
| `srcLen` | 43 |
| `srcByte` | 44 |
| `stgRead` | 45 |
| `stgWrite` | 46 |
| `cdone` | 47 |
| `artWrite2` | 48 |
| `srcWrite` | 49 |
| `srcSetLen` | 50 |
| `joyX` | 51 |
| `joyY` | 52 |
| `joyButtons` | 53 |
| `Math.round` | 54 |

**Ids 51–53 (`analog-joy`, V2.0).** Raw Pmod stick axes/buttons the digital
`joy()`/`keyLeft()` bits above don't carry. `joyX()`/`joyY()` return 0..255
(rest ~128; `joyY()` 0 = top). `joyButtons()` returns 5 bits: `1`=A `2`=B
`4`=C `8`=D `16`=stick-click. Board wires `rtl/phys/jmr_i2c_joy.sv` directly;
FPGA-SIM/PYTHON have no I2C model, so tests/GUI feed them via a debug RPC
(`ANALOG x y btn`, same shape as `JOY`/`KEYBITS`). See
[GAME_DESIGN.md](GAME_DESIGN.md) Input section.

`Math.PI` is **not** a call. It is `LOAD_CONST` of 3.14159…

**Id 41 note:** `Object.keys` (and therefore `for (k in obj)`) runs on the Python functional model. The chip does not have that native yet — it faults instead of guessing. Version 1.0 titles use a literal key list or an index loop. See [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#version-10-15-and-20).

**Ids 43–50 note — the V1.5 compile ABI.** These are not for games. Memory
map: [ARCHITECTURE.md](ARCHITECTURE.md) (standalone compile). This page lists
the native ids. They are the window through which the **self-hosted compiler**
(an ordinary program on the card) reaches the outside world:
`LOAD "X.HTML"` → `COMPILE` → `RUN`.

| Id | Call | Meaning |
|---|---|---|
| 43 | `srcLen()` | bytes of HTML source `LOAD` made available |
| 44 | `srcByte(i)` | source byte `i`, or **−1** past the end |
| 45 | `stgRead(i)` | scratch-arena byte `i`, or **−1** out of range |
| 46 | `stgWrite(i, b)` | scratch-arena write; out of range **faults** |
| 47 | `cdone(status, len, msgLen)` | report: 0 = mint, 0x80 = run the next chained program, else error |
| 48 | `artWrite2(word, lo, hi)` | packed art staging; past the framebuffer wall **faults** |
| 49 | `srcWrite(i, b)` | write a SOURCE byte — this is what makes an editor a PROGRAM |
| 50 | `srcSetLen(n)` | set the SOURCE length after an insert or delete |

Reads return −1 so a tokenizer can probe cheaply; **writes fault**, because a
stray write lands in the framebuffer / SOURCE / WORK and corrupts the machine
invisibly. Ids 44/45/46/48/49 are **one** RTL state (`S_CSRAM`) with a mode
select, so eight natives cost a single FSM encoding — encodings are the scarce
resource on this chip, not LUTs.

`cdone(status, …)` is also how a program asks the console for a file
operation, since the console owns storage: `0x00` mint the staged image (or,
with length 0, just return to READY), `0x80` chain-load the next program,
`0x81` save SOURCE, `0x82` delete, `0x83` load, `0x84` mint under a given
name. That table is why an editor needs no storage natives of its own.

The compiler never builds a JS string — there are no string methods — so
everything it does is byte offsets through these calls. A program that must
DRAW text indexes a table of one-character string literals (`G[code - 32]`),
because there is no `String.fromCharCode` either.

**Id 42 note:** `sound(ch, freqHz, vol0_15, frames, slideHzPerFrame)` always succeeds. Channel 0–2 square, 3 noise. The PHY owns the envelope (no per-frame JS mixer). PYTHON / FPGA-SIM with no jack are silent no-ops. Chrome titles call `playSfx(packed)` and keep Web Audio in `<script data-host="chrome">` (card mint strips that tag). Do **not** write `function sound()` — that compiles as a user stub and steals the native. Catalog: `storage/SNDDEMO.HTML`. Authoring: [GAME_DESIGN.md](GAME_DESIGN.md) Sound. Card mint: default on; `make_sd_image.py create -soundoff` stubs nid 42 for old bits.

---

## Methods → `CALL_METHOD` (30)

`obj.name(…)` always becomes instruction 30 plus the name. The processor then looks at what `obj` is (canvas, array, string, your class).

### Canvas (`getContext("2d")`)

| You write | Runs today |
|---|---|
| `getContext` | yes |
| `fillRect` `clearRect` | yes |
| `beginPath` `moveTo` `lineTo` `closePath` `arc` `fill` `stroke` | yes |
| `quadraticCurveTo` | Python yes; chip no |
| `fillText` `measureText` | yes (`font` size on the chip is still incomplete) |
| `drawImage` (3, 5, or 9 arguments) | yes |
| `setTransform` `translate` `save` `restore` | yes |
| `getImageData` `putImageData` | yes |
| `rotate` | compiles; both sides treat it as a no-op today |

### Array

| You write | Runs today |
|---|---|
| `push` `pop` `shift` `unshift` `splice` | yes |
| `forEach` `map` `filter` `find` | yes |
| `join` `indexOf` `fill` | yes |
| `slice` `sort` `reduce` `findIndex` | Python yes; chip no (do not use in a title you want on the chip) |

### String and other

| You write | Runs today |
|---|---|
| `replace` (plus a small regular-expression stub) | yes |
| `split` | Python yes; chip no |
| `Object.assign` / `Function.bind` | yes |
| `Date` `.getTime` / `.now` | yes |
| `addEventListener` `removeEventListener` `dispatchEvent` | yes |

---

## Properties → `GET_PROP` (27) / `SET_PROP` (28)

Not calls. Assignments and reads:

`fillStyle` `strokeStyle` `lineWidth` `font` `textAlign` `textBaseline` `imageSmoothingEnabled` `globalAlpha` `width` `height` `src` `length` `key` `keyCode` `hidden` `style` — plus any field you put on your own objects (`player.x = 1`).

---

## What this machine does not do

These are not missing by accident. They are not in the instruction set:

| You write | Why not |
|---|---|
| `eval` / `Function("code")` | Would be a second compiler inside the game |
| `async` / `await` / `fetch` / Promises | Network browser |
| `Math.sin` `Math.cos` | Version 2.0 (not version 1.0) |
| CSS layout, WebGL, Workers, Node `require` | Different product |

Version 1.0 games: `INVADERS.HTML` `PACMAN.HTML` `DONKEY.HTML` (and the other playable titles). How to author inside these walls: [GAME_DESIGN.md](GAME_DESIGN.md).

---

## READY console (not JavaScript)

Typed at the `>` prompt, same idea as BASIC `LOAD` / `RUN`:

**V1.5 (live on glass since run 67 + the 2026-09-01 card):** `DIR`
`LOAD "NAME.HTML"` `LIST` `EDIT` `COMPILE` `SAVE` `RUN` `NEW` `CLS` `HELP`
`MEM` `REMOVE "NAME.EXT"` — quotes optional on filenames; the delete verb
is **REMOVE**, not DELETE. `DIR` is titles; `DIR *` also shows `.JSH` / `.ART`.
**Run 71:** `STATUS` prints the loaded title, its byte length, TRUNC if the
file exceeded the 64 KB window, HTML/JS, and the last fault's site + value.
`EDIT n` and typed numbered lines are gone — the editor is EDITOR.JSH via
bare `EDIT`. A tether transfer whose CRC-32 fails prints `?CK` and is
discarded (the host resends). A silent SD card now answers `?IO` instead of
wedging the console until power-cycle.
`ESC` is machine BREAK (games must not steal it). F8 in the host GUI puts
a file on the card (host `storage/` or `card.img`).

**The self-hosted loop** — no PC anywhere in it:

    LOAD "BOXES.HTML"   → source into the machine
    EDIT                → full-screen editor (a GAME on the card:
                          EDITOR.JSH). F2 = save ("SAVED."), F3 = quit
                          without saving, arrows/Backspace edit.
    COMPILE             → chain-runs ARTSCAN.JSH then COMPILER.JSH from
                          the card; a title with a .ART sidecar gets its
                          art appended. Success mints NAME.JSH beside the
                          HTML → "COMPILED". Errors print a REAL message
                          after ?CE (TOKN / SYNTAX / OOB with numbers —
                          the message area is arena byte 128).
    RUN                 → plays the freshly minted .JSH.

**Do not delete** `storage/EDITOR.HTML`, `storage/ARTSCAN.HTML`, or
`storage/COMPILER.HTML`. They are the machine programs behind `EDIT` /
`COMPILE`, not titles. `DIR` hides those stems on purpose. Authoring note:
[GAME_DESIGN.md](GAME_DESIGN.md#machine-programs-in-storage--do-not-delete).

`RUN` always prefers the card's `.JSH`, so a FAILED compile leaves the old
version playable — REMOVE the stale `.JSH` if that would mislead. On-device
SAVE writes the HTML back to the card under the loaded title's name.

**Leftover (not the shipped loop):** type/paste numbered HTML at `>` for
*new* programs, and popular JS V1 lacks (`Array.shift`, `Math.sin`/`round`,
`isFinite`, …). Detail:
[JMR_JS_COMPATIBILITY.md § V1.5](JMR_JS_COMPATIBILITY.md#v15--type-paste-compile-edit-html-at-ready-no-card-required).

---

## How to remember the two call instructions

```
Math.floor(x)        →  CALL_NATIVE   (13)  + id 10     compiler already knows the name
c.fillRect(0,0,8,8)  →  CALL_METHOD   (30)  + "fillRect"  call on a value
foo(1, 2)            →  CALL_USER     (24)  or CALL_VAL (34)   a function you wrote
```

That is the whole calling convention.

---

## Related pages

| Page | Use it for |
|---|---|
| This file | Learn: what you type, what instruction it becomes |
| [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) | Title checklist, version 1.0 vs 2.0, silicon holes |
| [GAME_DESIGN.md](GAME_DESIGN.md) | How to write an HTML title that fits version 1.0 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Blocks and memories |
