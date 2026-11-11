# What differs from a browser

This machine runs a subset of JavaScript and of the Canvas 2D API. It is not
a browser: no layout, no network, no CSS engine. This page lists what is
missing, what behaves differently, and every size limit.

What you *can* write, and the instructions it becomes:
[JS_COMMANDS.md](JS_COMMANDS.md). How to write a program:
[GAME_DESIGN.md](GAME_DESIGN.md).

A page that runs in Chrome is not proof it runs here. Compile it
(`python3 tools/check_port.py NAME.HTML`) and run it in the GUI.

## Language differences

| JavaScript | Here |
|---|---|
| `let`, `const` | Same as `var`: function scope, no block scope, `const` can be reassigned. |
| `==` and `===` | The same instruction. No type coercion in either. |
| `a & b == c`, `a \| b != c` | `&` and `\|` bind tighter than `==` and `!=`. Use parentheses. |
| `switch` | A case body never falls into the next body. Stacked labels (`case 1: case 2:`) share one body. Put `default` last. |
| `throw e` | Evaluates `e` and continues. There are no exceptions. |
| `try` / `catch` | The `try` body runs. The `catch` body never runs. |
| `for (x of a)` | Needs a declaration: `for (const x of a)`. Arrays only. |
| `new X(…)` | `X` must be a plain name. `new a.b.C()` does not compile. |
| `k in obj` | True when `obj[k] !== undefined`. |
| Top-level `let x = v` | Assigns only if `x` does not exist yet. |
| Top-level `(function(){…})()` with no parameters | Runs in the global scope: its variables are globals. When it is assigned (`X = (function(){…})()`), the compiler renames its variables so they stay private to it. |
| Object literal | Keys are names or quoted strings. No computed keys, numeric keys, methods, getters or spread. |
| Parameters | Plain names. `{a, b}` destructuring only in `function` declarations and class methods. No defaults, no rest. |
| Classes | Constructor, methods, `get`, `set`, arrow fields. No `extends`, `super` or `static`. |
| Numbers | IEEE-754 double. `%` truncates toward zero. `\|` and `&` use `ToInt32`. |
| Strings | Immutable, stored once in a fixed table. `str[i]`, `length`, `+`, `replace`, `indexOf`. |
| Unknown bare function `foo()` | A call through an undefined variable: fault 4 at run time, not a compile error. |

### Not in the language

These do not compile:

`**`, `??`, `^`, `~`, `<<`, `>>`, `>>>`, `&&=`, `||=`, spread `...`, array
destructuring, labels, generators, default parameters, `?.[` and `?.(`.

These compile without an error but do not work, because the compiler reads
the keyword as a variable name:

`do … while`, `instanceof`, `delete`, `void`, `async`, `await`, `finally`,
`arguments`, hex and binary number literals (`0x1F`, `0b11`), `parseInt`,
`parseFloat`.

### Names the compiler rejects

A call to any of these method names is a compile error
(`V1 WALL: .name() is not in the V1.0 chip`), on any receiver. Source:
`V1_WALL_NAMES` in `functional_model/compiler.py`.

| Kind | Names |
|---|---|
| Math | `sin` `cos` `atan2` `pow` `hypot` |
| String | `charAt` `charCodeAt` `split` `match` `exec` `substring` `toUpperCase` `toLowerCase` `toFixed` `toString` `String` `concat` `startsWith` `endsWith` `padStart` `padEnd` `repeat` |
| Array | `reverse` `shift` `findIndex` `some` `every` `values` `entries` |
| Other | `parse` and `stringify`, except as `JSON.parse(…)` and `JSON.stringify(…)` |

Use a lookup table for sine and cosine. Use `strByte(str, i)` for a
character code.

The compiler also rejects reading `width`, `height`, `complete`,
`naturalWidth` or `naturalHeight` from a variable assigned `new Image()`. On
the FPGA those read `undefined`. Draw without checking.

### Names that hide a built-in name

The machine finds names it handles itself (`keyCode`, `charCode`, `key`,
`pop`, `push`, `length`, `fillStyle` and others) by a 16-bit hash of the
name. A program name with the same hash, later in the name table, takes its
place: `viewState` hid `keyCode` in the Editor, so non-character keys did
nothing, and `r32` hid `pop`. The hash is `_name_hash` in
`functional_model/jsb_format.py`; the names are the `id_…` checks in
`rtl/engines/jmr_js_vm.sv`. Rename the program's name.

## `String.indexOf` does not agree between the models

Measured 2026-11-11 on FPGA-SIM, with a six-character constant:
`"abcdef".indexOf("c")` returns **−1 on the RTL** and **2 on the Python
model**. A variable holding the same string behaves the same way. Until that
is fixed, `indexOf` cannot be relied on to read a value out of a table:

```javascript
// BAD — the RTL says -1, Python says 1, so the two machines draw differently
var t = ".#=".indexOf(ch);

// GOOD — a property table; the same lookup on both machines
var CODE = { ".": 0, "#": 1, "=": 2 };
var t = CODE[ch];
if (t === undefined) { t = 0; }
```

The *negative* result is still right on both machines, so the shape
`if (a.indexOf(v) < 0)` tests "not found" correctly. That is why the
compiler's `includes` → `!(indexOf < 0)` rewrite is unaffected and why
shipped titles that only ask a yes/no question kept working: only the
returned *index* is wrong. Do not build a lookup on it until the RTL arm
agrees; `storage/VIGIL.HTML` uses a table for its tile legend.

### Library code the compiler adds

`JSON.parse`, `JSON.stringify`, `String(v)`, `localStorage`, and a `+` whose
operands might be a string and a number are implemented in JavaScript. The
compiler adds that code to the program: about 2,450 instructions for
`String` or a mixed `+`, about 4,270 for `JSON`, measured on a stand-alone
program. Keep `+` between two numbers or two string literals to avoid it.

## Browser features that are absent

| Feature | Status |
|---|---|
| HTML layout, CSS, fonts, `innerHTML`, forms, `<iframe>`, SVG, video | Absent. Tags other than `<canvas>` and `<script>` are ignored. |
| External `.js` and `.css` files, ES modules, `import`, `export` | Absent. One program is one HTML file. |
| `fetch`, XHR, WebSocket, Workers, WebGL, `eval`, `Function("code")` | Absent. |
| Promises, `async` / `await` | Absent. |
| `<audio>`, `Audio`, Web Audio | Absent. Use `sound()`. |
| Typed arrays, `Map`, `Set`, `Symbol`, `Proxy`, `BigInt` | Absent. |
| `<script data-host="chrome">` | Skipped by the compiler. For browser-only code. |
| `document.getElementById`, `querySelector`, `createElement` | Return a stub. Use them to reach the canvas. |
| `window.open` and other unknown `window.` / `document.` / `console.` calls | Compile to a native that does nothing. |

## Canvas differences

The canvas is 640×480, 8 bits per pixel, with one 256-colour palette per
program.

| Item | Here |
|---|---|
| Size | Fixed. Assigning `canvas.width` or `height` does not resize the display. |
| Colours | Palette entries 0–7 are black, white, red, green, blue, yellow, cyan, magenta. The compiler fills the rest from colour string literals in the source (up to 120) and from the art. Write colours as literals: `"#rgb"`, `"#rrggbb"`, `"rgb(…)"` or a CSS name. |
| Transparency | Palette index 0 in a sprite is transparent. No `globalAlpha`, no `rgba()` blending, no `globalCompositeOperation`. |
| `drawImage` | Nearest-neighbour scaling. A negative scale in `setTransform` mirrors the sprite. |
| Transform | `setTransform` scale and translate, `translate`, `save`, `restore`. `rotate` does nothing. No `scale()`. |
| Paths | `moveTo`, `lineTo`, `quadraticCurveTo`, `arc`, `closePath`, `fill`, `stroke`. The FPGA buffers at most 16 commands per path. No `bezierCurveTo`, `ellipse`, `clip`, `strokeRect`. |
| Gradients, patterns, shadows, filters | Absent. |
| `getImageData` / `putImageData` | One saved image at a time. |
| `Image` | `img.src = "jmr:spr:N"` selects art sheet N. The string must be a literal. There is no loading delay. |

### Rectangles

`fillRect` and `clearRect` convert coordinates and sizes to 32-bit integers,
apply the `setTransform` scale and translation, then clip to the canvas. A
zero or negative width or height draws nothing. A positive size keeps at
least one pixel after scaling. The bare native `fillRect(x, y, w, h, index)`
ignores the transform and style and defaults to palette index 1.

### Text

| Item | Here |
|---|---|
| Font | One 8×8 bitmap, ASCII 32–126. Family and weight are ignored. |
| `ctx.font = "NNpx …"` | Only the integer `NN` is used. It starts at 8. An assignment that does not parse keeps the previous size. |
| Glyph size | `k = clamp(round(NN × sx / 8), 1, 15)`, where `sx` is the `setTransform` x scale. Each character is 8k × 8k pixels. |
| `fillText` | Draws at most 64 bytes. Each UTF-8 byte selects a glyph by its low 7 bits, so non-ASCII text draws wrong characters. |
| `fillText(number, x, y)` | Draws an integer without creating a string. Fractions are not drawn reliably on the FPGA. |
| `measureText(s).width` | `8 × k ×` the UTF-8 byte count. |

The Toolbox library draws the proportional system font instead:
[TOOLBOX_API.md](TOOLBOX_API.md).

## Events and time

| Item | Here |
|---|---|
| Frame | One frame advances the clock by 1000/60 ms. `Date.now()`, `performance.now()` and the `requestAnimationFrame` timestamp are frame time, not wall time. |
| Order in a frame | Key events, mouse events, `requestAnimationFrame` callbacks, then due timers. A callback queued during a frame runs in a later frame. |
| Keyboard | `keydown`, `keyup` with `key` and `keyCode`. No `code`. |
| Mouse | `mousemove`, `mousedown`, `mouseup`, `click`. Coordinates are canvas pixels. |
| `Math.random` | A seeded generator. The same run repeats. |
| Escape | Leaves the program. A program cannot intercept it. |

## Limits

Reaching a run-time limit runs the garbage collector where that can help,
then stops the program with a fault. Nothing is silently truncated.
`tools/check_port.py` reports the compile-time numbers for one file.

| Compile time | Limit |
|---|---|
| HTML source the on-machine editor and compiler can hold | 65,536 bytes |
| Instructions, constants and name tables together | 21,504 words (86,016 bytes) |
| Constants | 1,024 |
| Global variables | 1,024 |
| Names and strings | 1,024 entries, 16,384 bytes |
| Classes; methods per class | 16; 16 |
| Parameters in one function | 16 |
| Art sheets | 16 |
| Art (palette plus pixels) | 6,860,800 bytes |

| Run time | Limit |
|---|---|
| Value stack | 1,024 |
| Call depth | 128 |
| Live objects; properties per object | 960; 32 |
| Live function values | 960 |
| Arrays of up to 32 elements | 1,536 |
| Arrays of 33 to 128 elements | 16 |
| Elements in one array | 128 |
| Live scopes (one per active call or closure) | 384 |
| Timers | 64 |
| Pending `requestAnimationFrame` callbacks | 8 |
| Listeners per event type | 4 |
| Strings created at run time | share the 1,024-entry name table and are never released |

A call's own scope has 16 slots. A function with more parameters and
`var`/`let`/`const` names than that still compiles: both compilers keep its
16 most used names in its own scope and declare the rest in enclosing scopes
the function creates on entry (one extra closure call per 16 names). Those
names are found by name lookup, which is slower than a slot, and closures see
them as usual. Parameters alone still have to fit in 16. Small functions the
compiler copies in add their parameters to the caller's scope
([JS_COMMANDS.md](JS_COMMANDS.md#three-kinds-of-call)).

`Object.keys` and `for (k in obj)` run on the Python model and the FPGA.
`tools/check_port.py` still reports them as an error.

## Fault codes

A fault stops the program. The Architecture Monitor shows the code and the
instruction address ([ARCH_MONITOR.md](ARCH_MONITOR.md)).

| Code | Meaning |
|---|---|
| 1 | Value stack overflow or underflow |
| 2 | Call stack or frame error |
| 3 | A limit above was reached |
| 4 | Bad handle: a call of something that is not a function, or a stale object |
| 5 | Unsupported instruction or native |
| 6 | Bad string, JSON or regular-expression data |
| 9 | The image is not in the 64-bit value format, or a retired state was entered |

## Machine contract

The Python hardware model (`hardware_model/js_vm.py`) and the RTL execute the
same serialized program image and must give the same results.

### Program image (`.JSH`)

Source: `functional_model/jsb_format.py`.

- Magic `JSB1` (`JSB2` when the image carries class setters), then counts and flags.
- Sections: constants, instructions, names, classes, sprite descriptors,
  fill-style table, optional source-line map, then the `ASET` art section
  (768-byte palette plus 8-bit pixels).
- Flags: 1 name and class tables, 2 art section, 4 source map, 8 64-bit
  values, 16 linked to the resident Toolbox. Flag 8 is required.
- A bad magic, unknown flag, overlap, truncation or exceeded limit is
  refused before execution.

### Values

Every value is one 64-bit word.

- A word without the prefix `0x7FF9` in bits 63:48 is a number. Every NaN is
  stored as `0x7FF8000000000000`.
- A tagged word has a kind in bits 47:44, a generation in bits 43:32 and a
  payload in bits 31:0.
- Kinds: 1 undefined, 2 null, 3 boolean, 4 string, 5 object, 6 array,
  7 function, 8 element, 9 scope, 10 record (internal).
- A handle is (generation, index). Using a handle whose generation does not
  match the slot is a fault.

### Memory

- Objects, arrays, scopes and functions live in fixed tables with a
  generation counter and a mark bit per slot.
- Collection is mark and sweep at safe points. Roots are globals, the value
  stack, call frames, scopes, listeners, pending callbacks and timers.
  Freeing a slot increments its generation.
- An array starts in the short table and moves to the long table when it
  grows past 32 elements. Its handle does not change.
