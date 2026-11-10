# JavaScript you can write, and what it compiles to

The machine runs bytecode, not JavaScript text. The compiler
(`functional_model/compiler.py`) turns the `<script>` blocks of an HTML file
into 34 numbered instructions. The Python model and the FPGA execute the same
instruction words.

| Topic | Page |
|---|---|
| What is missing or differs from a browser, and all size limits | [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) |
| How to write a program | [GAME_DESIGN.md](GAME_DESIGN.md) |
| Terms | [WORDS.md](WORDS.md) |

## The instruction set

Source: `functional_model/bytecode.py` (`Op`), mirrored in
`rtl/engines/jmr_js_vm_pkg.sv`. There is no opcode 0. One instruction is a
32-bit word: opcode in bits 7:0, `arg0` in bits 23:8, `arg1` in bits 31:24.

| # | Name | What it does |
|---|---|---|
| 1 | `LOAD_CONST` | Push a number, string, `true`, `false`, `null`, `undefined`, or a regular-expression constant. |
| 2 | `LOAD_VAR` | Push a variable. |
| 3 | `STORE_VAR` | Pop into a variable. |
| 4–7 | `ADD` `SUB` `MUL` `DIV` | Arithmetic. `ADD` also joins strings. |
| 8–10 | `LT` `GT` `EQ` | Compare. |
| 11 | `JUMP` | Go to another instruction. |
| 12 | `JUMP_IF_FALSE` | Jump when the top of the stack is falsy. |
| 13 | `CALL_NATIVE` | Call a built-in. `arg0` is the [native id](#built-in-functions-call_native). |
| 14 | `RETURN` | Return with no value. The compiler always emits `RET_VAL`. |
| 15 | `POP` | Drop the top of the stack. |
| 16 | `DUP` | Duplicate the top of the stack. |
| 17 | `NEG` | `-x` |
| 18 | `NOT` | `!x` |
| 19 | `MAKE_ARRAY` | Build `[…]` from the top `arg0` values. |
| 20 | `ARRAY_GET` | `a[i]`, `obj[key]`, `str[i]` |
| 21 | `ARRAY_SET` | `a[i] = v`, `obj[key] = v` |
| 22 | `LET_VAR` | Declare a variable. In a function it writes the local. At top level it writes only if the name does not exist yet. |
| 23 | `MOD` | `%` |
| 24 | `CALL_USER` | Call a `function` declaration by its entry address. |
| 25 | `RET_VAL` | Return a value. |
| 26 | `MAKE_OBJ` | Build an empty object. |
| 27 | `GET_PROP` | `obj.name` |
| 28 | `SET_PROP` | `obj.name = v` |
| 29 | `NEW_OBJ` | `new Name(…)` |
| 30 | `CALL_METHOD` | `obj.name(…)`. `arg0` is the method name. |
| 31–32 | `BIT_OR` `BIT_AND` | `\|` `&` on 32-bit integers. |
| 33 | `MAKE_FN` | Build a function value. |
| 34 | `CALL_VAL` | Call a function value on the stack. |

`LOAD_VAR` and `STORE_VAR` carry a hint in `arg1`: 0 walks the scope chain,
1 is a known global, 2 + slot is a local. The Python model ignores the hint.

## Three kinds of call

```text
Math.floor(x)         CALL_NATIVE  id 10        a name the compiler knows
c.fillRect(0,0,8,8)   CALL_METHOD  "fillRect"   a call on a value
foo(1, 2)             CALL_USER, or CALL_VAL    a function you wrote
```

- A bare name in the native table, or `Math.` / `console.` / `document.` /
  `window.` followed by a name, is `CALL_NATIVE`. A dotted name that is not in
  the table becomes id 33 and does nothing, unless it is on the
  [rejected list](JMR_JS_COMPATIBILITY.md#names-the-compiler-rejects).
- Any other `x.name(…)` is `CALL_METHOD`, including `Date.now()`,
  `performance.now()` and `Object.assign(…)`.
- A call to a top-level `function` is `CALL_USER`. A small callee (at most 64
  instructions, no locals beyond its parameters, no `new`, no closure, no
  call to another function of yours) is copied into the caller instead. Its parameters then count as the caller's locals.
- A call through a variable, or `(function(){…})()`, is `CALL_VAL`.

Declaring your own function with a native's name (`function sound()`,
`function joy()`) replaces the native in that program.

## Examples

```javascript
let x = 3;
if (x > 1) { console.log(x); }
```

```text
LOAD_CONST 3
LET_VAR x
LOAD_VAR x
LOAD_CONST 1
GT
JUMP_IF_FALSE end
LOAD_VAR x
CALL_NATIVE console.log
POP
```

```javascript
c.fillRect(0, 0, 10, 10);
```

```text
LOAD_VAR c
LOAD_CONST 0
LOAD_CONST 0
LOAD_CONST 10
LOAD_CONST 10
CALL_METHOD fillRect (4 arguments)
POP
```

## Language to instructions

| You write | Compiles to |
|---|---|
| `42` `1.5` `2e3` `"hi"` `'hi'` `true` `false` `null` `undefined` | `LOAD_CONST` |
| `Infinity` `NaN` `Math.PI` | `LOAD_CONST` |
| `` `a ${x} b` `` | `LOAD_CONST`, the expression, `ADD` |
| `/pattern/flags` | `LOAD_CONST`. Use it as the pattern of `replace`. |
| `x` | `LOAD_VAR` |
| `this` | `LOAD_VAR __this` |
| `x = v` | `STORE_VAR` |
| `var` / `let` / `const` `a = 1, b` | `LET_VAR` |
| `const {a, b} = obj` | `GET_PROP` then `LET_VAR` for each name |
| `+ - * / %` | `ADD` `SUB` `MUL` `DIV` `MOD` |
| `-x` `+x` `!x` | `NEG`; `x - 0`; `NOT` |
| `<` `>` | `LT` `GT` |
| `<=` `>=` | `GT` `NOT`; `LT` `NOT` |
| `==` `===` | `EQ` |
| `!=` `!==` | `EQ` `NOT` |
| `\|` `&` | `BIT_OR` `BIT_AND` |
| `&&` `\|\|` `a ? b : c` | `DUP`, `JUMP_IF_FALSE`, `JUMP` |
| `a, b` | `POP` between the two |
| `x++` `--x` `x += v` (also `-=` `*=` `/=` `%=`), on a variable, property or element | load, arithmetic, store |
| `typeof x` | `CALL_NATIVE typeof` |
| `k in obj` | `obj[k] !== undefined` |
| `obj?.x` `obj?.m()` | `DUP`, `JUMP_IF_FALSE`, then the get or call |
| `[a, b]` | `MAKE_ARRAY` |
| `{a: 1, "b": 2, c}` | `MAKE_OBJ`, then `SET_PROP` per key |
| `a[i]` `a[i] = v` | `ARRAY_GET` `ARRAY_SET` |
| `obj.x` `obj.x = v` | `GET_PROP` `SET_PROP` |
| `if` / `else`, `while`, `for (;;)` | `JUMP_IF_FALSE`, `JUMP` |
| `break` `continue` | `JUMP` |
| `switch` / `case` / `default` | `EQ` per label, `JUMP_IF_FALSE`, `JUMP` |
| `for (const x of arr)` | index loop: `GET_PROP length`, `LT`, `ARRAY_GET` |
| `for (k in obj)` | `CALL_NATIVE Object.keys`, then the same index loop |
| `function f(a, {b, c}) {…}` | body, then `MAKE_FN` and a store to `f` |
| `function (a) {…}`, `a => e`, `(a, b) => {…}` | `MAKE_FN` |
| `return v` | `RET_VAL` |
| `class C { constructor(){} m(){} get p(){} set p(v){} f = () => {} }` | constructor and method bodies; the class table goes in the program image |
| `new C(…)` | `NEW_OBJ` |
| `new Date()` `new Image()` | `CALL_NATIVE` 25, 26 |
| `new KeyboardEvent(type, opts)` (also `Event`, `CustomEvent`, `MouseEvent`) | `MAKE_OBJ`, `SET_PROP type`, `CALL_METHOD assign` |
| `throw e` | evaluates `e`, then `POP`. Execution continues. |
| `try {…} catch (e) {…}` | the `try` body only |
| `JSON.parse(s)` `JSON.stringify(v)` `String(v)` | `CALL_USER` into a JavaScript library the compiler adds to the program |
| `localStorage.getItem/setItem/removeItem` | `CALL_USER` into a second added library |

`"text" + n`, where the compiler cannot prove both sides are numbers or both
are strings, is an `ADD` that carries the address of the same added library.

## Built-in functions (`CALL_NATIVE`)

Source: `functional_model/jsb_format.py` (`NATIVE_IDS`, `NATIVE_ALIASES`).
Every id has an arm in `rtl/engines/jmr_js_vm_exec64.sv`.

| Id | Name | Notes |
|---|---|---|
| 0 | `console.log`, `console.warn` | Diagnostic text for the host. |
| 1 | `clear` | Fill the canvas with one palette index. |
| 2 | `fillRect` (bare) | Raw coordinates, palette index, no transform. |
| 3 | `swapBuffers` | Present the canvas now. |
| 4–6, 8, 9 | `keyLeft` `keyRight` `keyFire` `keyUp` `keyDown` | One held direction or fire bit. |
| 7 | `startLoop` | Re-run the top-level code every frame. |
| 10–15 | `Math.floor` `abs` `min` `max` `random` `sqrt` | `random` is a seeded generator. |
| 16–18 | `document.getElementById` `querySelector` `createElement` | Return an element stub. |
| 19, 20 | `addEventListener` (bare, `document.`, `window.`) | |
| 21, 22, 32 | `localStorage.getItem` `setItem` `removeItem` | Reserved ids. The compiler emits library calls instead. |
| 23, 24 | `JSON.parse` `JSON.stringify` | Reserved ids. The compiler emits library calls instead. |
| 25 | `Date` | |
| 26 | `Image` | |
| 27 | `requestAnimationFrame` | |
| 28–31 | `setTimeout` `setInterval` `clearTimeout` `clearInterval` | |
| 33 | `_stub` | Does nothing. Unknown dotted names land here. |
| 34 | `Array` | `Array(n)` |
| 35 | `Date.now` | Milliseconds of machine frame time. |
| 36, 37 | `removeEventListener` (bare, `document.`, `window.`) | |
| 38, 39 | `document.dispatchEvent` `window.dispatchEvent` | |
| 40 | `typeof` | |
| 41 | `Object.keys` | Own keys in insertion order. |
| 42 | `sound(ch, freqHz, vol, frames, slide)` | [GAME_DESIGN.md](GAME_DESIGN.md#sound) |
| 43 | `srcLen()` | Bytes in the SOURCE document. |
| 44 | `srcByte(i)` | SOURCE byte, or −1 past the end. |
| 45 | `stgRead(i)` | Scratch-arena byte, or −1 out of range. |
| 46 | `stgWrite(i, b)` | Scratch-arena write. Out of range faults. |
| 47 | `cdone(status, len, msgLen)` | Hand a finished job back to the system. |
| 48 | `artWrite2(word, lo, hi)` | Write two art bytes. Past the art area faults. |
| 49 | `srcWrite(i, b)` | Write a SOURCE byte. |
| 50 | `srcSetLen(n)` | Set the SOURCE length. |
| 51, 52 | `joyX()` `joyY()` | Analog stick, 0..255, rest near 128. |
| 53 | `joyButtons()` | Bit 0 A, 1 B, 2 C, 3 D, 4 stick click. |
| 54, 57 | `Math.round` `Math.ceil` | `round` rounds ties toward +∞. |
| 55, 56 | `isFinite` `isNaN` | |
| 58–62 | `fsList` `fsRead` `fsWrite` `fsRemove` `fsRename` | Card files. Names are bytes in the scratch arena. |
| 63 | `sysRun(nameOffset, how)` | Leave this program and start another. |
| 64 | `toolbox(op, a, b, c)` | Bulk memory and bitmap services. [TOOLBOX_API.md](TOOLBOX_API.md) |
| 65 | `sysDocument(op, ptr, role)` | SOURCE document metadata. |
| 66 | `strByte(str, i)` | Byte of a string, or −1. |
| 67 | `Array.isArray(v)` | |
| 68 | `stringFromBytes(…)` | Build a string from bytes. |
| 69 | `runtimeFault(code)` | Stop with a fault code 1..9. |
| 70 | `joy()`, `getJoy()` | Digital stick and play keys. [GAME_DESIGN.md](GAME_DESIGN.md#input) |

Ids 43–50 and 58–69 are system services for the compiler, editor, Finder and
the Toolbox library. How to use them:
[RESIDENT_TOOLBOX.md](RESIDENT_TOOLBOX.md) and
[SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md).

## Methods (`CALL_METHOD`)

The VM looks at the receiver, then the name. These names work in both the
Python model and the FPGA.

| Receiver | Methods |
|---|---|
| Canvas element | `getContext("2d")` |
| 2D context | `fillRect` `clearRect` `drawImage` (3, 5 or 9 arguments) `beginPath` `moveTo` `lineTo` `quadraticCurveTo` `arc` `closePath` `fill` `stroke` `fillText` `measureText` `setTransform` `translate` `save` `restore` `getImageData` `putImageData` |
| Array | `push` `pop` `unshift` `splice` `slice` `indexOf` `includes` `fill` `join` `forEach` `map` `filter` `find` `reduce` `sort(compare)` |
| String | `replace` `indexOf` |
| Function | `bind` |
| `Object` | `assign` |
| `Date`, `performance` | `now`; a `Date` object has `getTime` |
| Element, `document`, `window` | `addEventListener` `removeEventListener` `dispatchEvent` `click` |
| Your class | its methods, getters and setters |

`a.includes(v)` compiles to `!(a.indexOf(v) < 0)`. `rotate` is accepted and
does nothing.

## Properties (`GET_PROP` / `SET_PROP`)

| Receiver | Properties |
|---|---|
| 2D context | `fillStyle` `strokeStyle` `lineWidth` `font` `textAlign` `textBaseline` `imageSmoothingEnabled` |
| Canvas | `width` `height` (read: 640 and 480) |
| Image | `src` `onload` |
| Array, string | `length` |
| Key event | `key` `keyCode` `type` |
| Mouse event | `type` `x` `y` `clientX` `clientY` `offsetX` `offsetY` `movementX` `movementY` `button` `buttons` |
| Element stub | `style` `hidden` |
| Your object | any name you assign |
