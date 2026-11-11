# How to write a program for this machine

A program is one HTML file with a 640×480 `<canvas>` and inline `<script>`
blocks. The card builder compiles it to a `.JSH` program image. Finder runs
that image when you double-click the program.

| Topic | Page |
|---|---|
| The JavaScript you can use | [JS_COMMANDS.md](JS_COMMANDS.md) |
| What is missing, how Canvas and text differ, every size limit | [JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md) |
| Menus, windows, About text, roles | [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md) |
| Toolbox drawing and bitmap copies | [TOOLBOX_USAGE.md](TOOLBOX_USAGE.md), [TOOLBOX_API.md](TOOLBOX_API.md) |
| Which files go on the card | [storage/README.md](../storage/README.md) |

Rules for the machine itself: do not add a program's name to the RTL, the
compiler or a native, and do not raise a limit for one program.

## A minimal game

Copy `storage/BOXES.HTML` (no input) or `storage/MENUEX.HTML` (a menu
command).

```html
<!-- jmr-clean-ui: session-v3-explicit -->
<!-- jmr-toolbox: resident-v2 -->
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>My game</title></head>
<body>
<canvas id="c" width="640" height="480"></canvas>
<script>
var ctx = document.getElementById("c").getContext("2d");
tbSessionProperty(ctx, 0, 8);                        // role 8: a game
tbSessionProperty(ctx, 1, 1);                        // fit the picture under the menu bar
tbSessionProperty(ctx, 2, "My Game|One line for the About box.");

var x = 0;
tbSessionListen("keydown", function (e) {
  if (e.keyCode === 39) x = x + 8;                   // right arrow
});
function frame() {
  ctx.fillStyle = "#000000"; ctx.fillRect(0, 0, 640, 480);
  ctx.fillStyle = "#FF0000"; ctx.fillRect(x, 200, 32, 32);
  tbSessionFrame(frame);
}
tbSessionFrame(frame);
tbSessionProgram("MYGAME.HTM");
</script>
</body></html>
```

- The `jmr-toolbox` comment must be in the first 1024 bytes. It links the
  program to the resident Toolbox, which draws the menu bar, File → Quit and
  the About box.
- The `tbSession…` calls, roles and menus are specified in
  [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md#session-calls).
- A browser does not define the `tbSession…` calls, so this file does not
  run in Chrome as written.

## Build and run

```sh
python3 tools/check_port.py storage/MYGAME.HTML    # compile, print sizes against the limits
python3 tools/make_artx.py MYGAME                  # only if the program has art
python3 tools/make_sd_image.py create card.img     # rebuild the card, compile every program
JMR_CARD_IMG=card.img .venv/bin/python gui_jmr_js.py
```

In the GUI, F9 cycles the Python model, FPGA-SIM and the board. Test in
Python first, then FPGA-SIM. A compile error names the HTML line. A program
that fails to compile gets no `.JSH` and will not start.

`create` replaces `card.img`, including documents saved on it.

The machine can also edit and compile a program by itself. Finder's Special
menu starts the Editor and Compile. In Compile, File → Open picks an HTML
program and File → Save compiles it. The source must be under 65,536 bytes.

`python3 tools/prepare_port.py GAME.HTML --out NEW_DIR` moves pictures
embedded in an HTML file into an art file. It leaves the original untouched
and refuses to write unless the compiled program is byte-identical.

## Screen

- Declare `<canvas width="640" height="480">` and fill it. Do not assign
  `canvas.width` or `canvas.height` later.
- The canvas is persistent. What you do not redraw stays.
- At the end of each frame the machine copies the changed 16×16 blocks to
  the display. Redrawing less means copying less.
- Draw the score and all text on the canvas. HTML elements outside the
  canvas are not shown.
- To scale a larger world onto the canvas, call `tbSessionTransform` with
  the arguments of `setTransform`. `rotate` and `scale()` are not available.
- A game shares the top rows with the menu bar:
  [where to draw](SYSTEM_APPLICATIONS.md#where-to-draw).

## Art

Draw PNG sheets. Tools convert them. Do not paste `data:image` base64 into
the HTML, and do not write `.ARTX` or `.ARTJS` by hand.

| You make | Tool | Result |
|---|---|---|
| `MYGAME-0.png`, `MYGAME-1.png`, … | `python3 tools/make_artx.py MYGAME` | `MYGAME.ARTX`: the palette and 8-bit pixels the machine uses |
| | same command | `MYGAME.ARTJS`: the same pixels for a browser preview |
| `MYGAME.HTML` | `tools/make_sd_image.py create card.img` | `MYGAME.JSH` on the card: code plus that art |

List the sheets in a browser-only block before the game script. The index
in this list is the sheet number:

```html
<script data-host="chrome">
window.JMR_SPR = ["MYGAME-0.png", "MYGAME-1.png"];
</script>
```

Use a sheet by its number:

```javascript
var img = new Image();
img.src = "jmr:spr:0";
ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
```

| Rule | Reason |
|---|---|
| `"jmr:spr:N"` must be a quoted literal | The FPGA binds the handle from the literal. A string built at run time draws nothing there. |
| Only append to `JMR_SPR` | The order is the numbering. Reordering makes every handle draw the wrong sheet. |
| At most 16 sheets | Pack related frames into one sheet and draw with the 9-argument `drawImage`. |
| Palette index 0 is transparent | The blitter skips it. |
| Do not test `img.width`, `img.complete` or wait for `onload` | The art is in memory before the program starts. The compiler rejects those reads. |
| Rerun `make_artx.py`, then rebuild the card, after changing a PNG | The card holds the converted art, not the PNG. |

`make_artx.py /path/to/game.html` copies a file from elsewhere into
`storage/` under an 8-character name and converts its sheets.

## Text

The Canvas font is one 8×8 bitmap, ASCII only. The exact rules are in
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#text). In practice:

- With no transform, `"8px"` gives 8-pixel characters and `"16px"` gives 16.
  Sizes between round to one of those.
- After a `setTransform` that shrinks the world, raise the size so
  `NN × scale / 8` still rounds to the size you want.
- Draw a label and its number as two calls:
  `fillText("SCORE", x, y)` then `fillText(score, x + 48, y)`.
- Use `textAlign = "left"` and place by character width for a row of items.
- Draw lives as `*`, rectangles or a sprite. Symbols such as ♥ draw as
  wrong characters.

## Input

Bind keys in the program. The machine delivers raw events only.

| Source | How to read it |
|---|---|
| Keyboard | `keydown` / `keyup`. Test `e.keyCode` (37 left, 38 up, 39 right, 40 down, 32 space, 13 Enter); `e.key` is also set. |
| Stick and play keys | `joy()` each frame. Bits: 1 up, 2 down, 4 left, 8 right, 16 fire 1, 32 fire 2. Arrow keys and space set the same bits. |
| Stick buttons | A, C and the stick click are fire 1. B and D are fire 2. |
| Analog stick | `joyX()`, `joyY()`: 0..255, rest near 128, `joyY()` 0 is up. `joyButtons()`: bit 0 A, 1 B, 2 C, 3 D, 4 click. |
| Mouse | `mousemove`, `mousedown`, `mouseup`, `click`. `e.x`, `e.y` are canvas pixels; `e.movementX/Y`, `e.button`, `e.buttons`. |
| Menu command | A `keydown` whose `keyCode` is the number you gave the menu item. |

- Escape leaves the program. Do not bind it.
- The machine runs with no stick and with no mouse. Make every action
  reachable from the keyboard.
- Do not declare your own `function joy()`. It replaces the native.
- `storage/JOYDEMO.HTML` shows stick and keys together.

### Fire needs a cooldown

A tap stays held for several frames. A program that fires whenever fire is
held shoots two or three times per tap. Gate the handler with a frame
counter, as `playerShoot()` in `storage/INVF.HTML` does:

```javascript
if (frames < canShootAt) return;
canShootAt = frames + 6;
```

Rate-limit only. Do not require a release, or hold-to-repeat stops working.

## Sound

The machine has four voices: channels 0–2 are square waves, channel 3 is
noise. All four take a pitch. One call starts a note; the hardware runs its
envelope and stops it.

```javascript
sound(ch, freqHz, vol, frames, slide);
```

| Argument | Meaning |
|---|---|
| `ch` | 0, 1, 2 square; 3 noise |
| `freqHz` | Pitch |
| `vol` | 0–15. 0 is silent. |
| `frames` | Length in 1/60 s. 0 is silent. |
| `slide` | Hz added per frame. Negative falls. |

A call on a channel that is still sounding restarts it. Use two channels
for two sounds at once.

Keep effects as number arrays and play them with one helper. `playSfx` is
the helper every shipped program uses; `storage/SNDDEMO.HTML` is the
catalogue.

```javascript
/* freqHz, vol, frames, slide, ch — repeated per voice */
var sfxFire    = [1200, 10, 4, -120, 0];
var sfxExplode = [70, 12, 14, 0, 3,  90, 8, 10, -6, 1];

function playSfx(r) {
  var i;
  if (!r) return;
  if (typeof _chromePlay === "function") { _chromePlay(r); return; }
  i = 0;
  while (i + 4 < r.length) {
    sound(r[i + 4], r[i], r[i + 1], r[i + 2], r[i + 3]);
    i = i + 5;
  }
}
```

| Do not | Reason |
|---|---|
| Declare `function sound()` | It replaces the native and the program is silent. |
| Mix or step sounds in the frame loop | The hardware already does it. |
| Use `<audio>` or Web Audio in the game script | Absent. Browser-only audio goes in a `<script data-host="chrome">` block that defines `_chromePlay`; copy it from `SNDDEMO.HTML`. |

`make_sd_image.py create card.img -soundoff` compiles every `sound()` call
to a no-op.

## Speed

The VM runs at 33.333 MHz: about 555,000 VM clocks per 1/60 s. The paint
engine runs at 100 MHz and writes about one pixel per clock. So drawing
through `fillRect`, `drawImage` and `putImageData` is cheap, and JavaScript
instructions are the cost.

| Do | Instead of |
|---|---|
| Draw sprites with `drawImage` | Loops of 1×1 `fillRect`. Every native call has a fixed cost. |
| Draw a wall or a map in large pieces | Hundreds of small rectangles or one-pixel columns per frame |
| Redraw what changed | Clearing and repainting the whole screen every frame |
| Read `obj.prop` into a local before a hot loop | Reading the property on every pass |
| Move one step toward a target each tick | A maze search or a grid copy every tick. A frame that does not finish freezes the picture with no error. |
| Do a full search once, on the event that needs it | Repeating it per frame |
| Hide a destroyed sprite and play a sound | A long particle effect in JavaScript |

## Memory

The limits are in
[JMR_JS_COMPATIBILITY.md](JMR_JS_COMPATIBILITY.md#limits). The ones that
shape a program:

| Limit | What to do |
|---|---|
| 16 slots in a call's own scope | Keep hot functions within 16 parameters plus locals. Past 16 the compiler moves the least used names to an enclosing scope, where each use is a name lookup; more than 16 parameters do not compile. |
| 960 live objects | Keep one object and write its fields. Do not build a new `{x, y}` every frame. |
| 128 elements per array; only 16 arrays may exceed 32 | Store a grid as one array per row. Split a long queue. |
| 1,536 arrays | Do not keep per-frame scratch arrays alive. Temporaries are collected; permanent ones are not. |
| 1,024 strings, never released | Do not build strings from changing numbers (`"" + score`). Pass the number to `fillText`. Strings from a fixed set are fine. |
| 8 pending frame callbacks, 64 timers | One frame chain. Do not start a timer per event. |

### Removing items from a list

Do not `splice` an array while a loop is walking it. Mark the item and
compact once after the loop:

```javascript
invader.dead = true;

function sweep(list) {
  var i, w = 0;
  for (i = 0; i < list.length; i++) {
    if (!list[i].dead) { list[w] = list[i]; w = w + 1; }
  }
  list.length = w;
}
```

`sweepGridInvaders` and `sweepProjectiles` in `storage/INVF.HTML` are the
reference.

## Checklist

1. One `storage/NAME.HTML`, name of 8 characters or fewer, 640×480 canvas.
2. The two marker comments, role, About text and `tbSessionProgram`.
3. `python3 tools/check_port.py storage/NAME.HTML` reports no error.
4. Every action works from the keyboard. Escape is not bound.
5. Art handles are literals. At most 16 sheets.
6. Hot functions within 16 locals (more work, but past 16 the extra names are
   found by lookup). No strings built from changing numbers.
7. `python3 tools/make_sd_image.py create card.img` lists `NAME.JSH`.
8. It plays in the GUI on Python, then on FPGA-SIM.
