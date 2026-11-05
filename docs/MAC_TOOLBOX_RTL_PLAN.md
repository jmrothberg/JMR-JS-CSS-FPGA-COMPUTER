> Update: raw 8-bit bitmap transport (operation 6) is now implemented in
> working source and simulator checks. Its authoritative contract is
> [TOOLBOX_API.md](TOOLBOX_API.md#general-bitmap-transport-and-software-copybits).
> The broader packed-format CopyBits proposal below remains historical design
> scope, not the implemented ABI. Frozen run77b/run77c builds predate this service.

# Macintosh-style Toolbox and graphics: RTL review

2026-11-04 research baseline. Implementation is now underway; see
[implementation status](TOOLBOX_IMPLEMENTATION_STATUS.md) and
[actual primitive API](TOOLBOX_API.md). The analysis below describes the
pre-implementation source; the user has since improved MacPaint previews.
Basis: run76 frozen RTL and synthesis hierarchy, its experimental test-bit
reports, and the current `storage/MACPAINT.HTML`. Savings below are candidate
scope, not measured savings. No new performance benchmark was run.

## Current implementation versus next work

Run77b now implements native operations 0–5, shared software menus/dialogs,
and a genuine resident JavaScript instruction bank. The bank uses three spare
BRAM tiles (3072 stored words), with fixed jump padding in the 4096-word virtual
window. All application code remains in BRAM; external memory remains 8 MiB.
The earlier run77 LUT-RAM attempt failed its synthesis budget and is preserved.
Run77b is building; do not treat it as a qualified board release yet.

Finder disk launch now waits for the console input drain. Full RTL disk tests
pass boot, resident-linked loading and live mouse menu/dialog interaction.
See [the software call/linking guide](RESIDENT_TOOLBOX.md) and
[primitive ABI](TOOLBOX_API.md). Existing programs keep their native UI until
converted; the full 10,233-LUT UI scope below has not been removed.

CopyBits (operation 6) below is the next proposed graphics extension, **not an
implemented call**. Finish and qualify the current Toolbox baseline first, then
add/test CopyBits without mixing its framebuffer-readback work into this build.

## Recommendation

Keep a small, fast graphics/memory engine in hardware. Move interaction policy
and system applications into shared software; move appearance and layout into
versioned resources. Give that software bulk operations so it does not interpret
JavaScript for each pixel or byte. Keep 8 MiB and current clocks initially.

The best first change is a reusable block-copy and bitmap-surface interface,
followed by removing per-pixel MacPaint preview loops. A higher clock alone
would accelerate a very inefficient algorithm rather than remove the problem.

## What the original Macintosh teaches

The Macintosh ROM contained executable software, including QuickDraw, not a
separate hardware circuit for each menu or drawing operation. QuickDraw was
68000 assembly; MacPaint combined Pascal application logic with assembly for
performance-sensitive work. That separation is the useful model for our
JavaScript application layer and small RTL graphics engine.
[Computer History Museum, original source and implementation](https://computerhistory.org/blog/macpaint-and-quickdraw-source-code/).

MacPaint used offscreen current/previous document buffers for drawing and Undo,
then copied completed output to the display. A temporary mask supported complex
selections; FatBits scaled the copied image. We should borrow the buffer and
bulk-operation design, rather than copy the historical memory restrictions.
The later 128K-ROM seed-fill addition must not be confused with the original
128K-RAM machine's 64K ROM.
[Andy Hertzfeld, MacPaint Evolution](https://www.folklore.org/MacPaint_Evolution.html).

QuickDraw regions represented boundaries compactly using inversion points.
Rectangular clipping and lists of changed spans are a practical first step;
we do not need a general region algebra implemented as FPGA logic.
[Hertzfeld, I Still Remember Regions](https://folklore.org/I_Still_Remember_Regions.html?sort=date).

The early Inside Macintosh describes QuickDraw calls through an indirection
table in RAM. Our equivalent should be stable service numbers, validated
arguments and a versioned interface: applications should not depend on internal
addresses. The same manual gives 21,888 bytes for the original screen; our
640×480×8-bit image is 307,200 bytes, about 14 times as much data. Color and
resolution make efficient copying more important, not less.
[Apple, Inside Macintosh Volume I](https://bitsavers.org/pdf/apple/mac/Inside_Macintosh_Vol_1_1984.pdf).

## Why this MacPaint rectangle is expensive

Code evidence from the pre-Toolbox MacPaint snapshot (the current source now
uses bulk Undo copying and newer preview algorithms):

- `beginDoc()` calls `copyDocToUndo()` before a shape. It copies 23,040 logical
  bitmap bytes plus 92,160 logical color bytes. `copyRange()` calls `stgRead`
  and `stgWrite` for every byte: **230,400 native calls**, plus JavaScript loop
  work, before the drag begins. These are logical bytes; the staging ABI stores
  one logical byte per 16-bit memory word.
- `previewShape()` calls `restoreBox()` for the previous bounding rectangle,
  padded by four pixels. `restoreBox()` visits every pixel, calls `shown()`, then
  `paintDot()`. The latter selects a color and issues a separate `fillRect`.
  A fully visible 200×200 previous box therefore restores 208×208 = **43,264
  pixels/calls** per update, before drawing the new outline. This is a source-
  derived work count, not a measured frame time.
- `frameBox()`, `hline()` and `vline()` also iterate pixel by pixel. Packed
  bits/nibbles are unpacked with JavaScript arithmetic and memory calls.
- `drawDoc()` already groups some runs, but the drag restoration path does not.

`jmr_raster_engine.sv` already fills at one pixel per 100 MHz clock once an
operation starts. It costs about 690 synthesized LUTs and five DSPs. A 200×200
fill has an ideal raster walk of 0.4 ms; this excludes native-call setup,
presentation, arbitration and memory work and is NOT an observed latency.
The slow algorithm repeatedly pays setup instead of submitting a bulk fill.

`jmr_fb_present.sv` already copies only dirty 256-byte blocks. The DDR bridge
already has a one-line read cache and write combining in the default build.
Adding these again is not a fix. New bulk operations should use and preserve
them, including read-after-write ordering and fair scanout access. FPGA-SIM's
simple SRAM model does not reproduce all board DDR delays.

## Where the hardware resources are

The published run76 experimental bit uses **104,218 LUTs, 30,433 slices,
361.5/365 BRAM tiles, and 128/740 DSPs**. Setup WNS is −0.355 ns; it is not a
timing-qualified release. Spare DSPs do not replace arbitrary control logic or
BRAM. Spare board DDR is not equivalent to spare on-chip RAM.

The following are *synthesis hierarchy* attribution figures from
`build/run76_usb_keyboard_pmod_mice/utilization_synth_hier.rpt`; do not add these
to the routed total or treat them as a savings estimate:

- VM including exec64: 76,682 LUTs and 264 BRAM tiles. The dominant cost.
- Framebuffer: 1,337 LUTs and 86 BRAM tiles. Keep the deterministic draw buffer
  initially. Comments claiming 75 tiles are not the measured run76 result.
- Classic UI and its label storage: 3,350 LUTs; document dialogs: 2,862;
  UI snapshot: 2,033; actions/menu: 1,197; classic/system overlays: 791.
  These disjoint blocks total **10,233 LUTs of candidate scope**. Software
  replacements still need hardware transport/rendering, so net savings are lower.
- Console engine: 4,826 LUTs, only partly movable. It also owns boot/loading
  and resident Finder transitions; deleting it would break the computer.
- Storage engine: 3,653 LUTs; desktop directory/icon service: 1,495; Finder
  filesystem service: 1,102. Keep low-level I/O and migrate policy later.

## What belongs where

Finder, Editor, Read, Note, Utility and the compiler already have HTML/JavaScript
programs in storage. Moving those names to disk again saves nothing. The next
target is the substantial native dialog/menu/lifecycle machinery underneath
them, while retaining the essential loader and service interface.

**Programs/shared Toolbox software:** open/save/replace dialogs, filename
editing, document prompts, menu tracking/dispatch, window dragging/resizing,
directory filtering/sorting, icon choice, editor/reader/utility behavior,
high-level drawing tools and complex effects. Convert incrementally, starting
with one document dialog. Keep input queues, emergency break/quit recovery and
boot fallback operational if an application hangs.

**SYSTEM.SYS resources:** fonts including future advance/metric tables, menu
and dialog templates, controls, icons, patterns, colors and theme dimensions.
V1 currently changes a fixed subset of appearance; it cannot define new dialog
behavior or execute code. Resource files do not free logic unless the hardware
behavior they replace is actually removed. Avoid duplicating the same font in
every consumer; consider a shared sequential glyph service with small caches.

**Small RTL primitives:** framebuffer access, fill/span, clipped bitmap copy,
memory block move/fill, packed-pixel expansion, input/event transport, scanout,
audio and physical storage interfaces. Extend the existing raster/address
walker instead of creating a dedicated MacPaint accelerator.

**Later VM work:** shared microcoded execution for infrequent language helpers,
and selectively DDR-backed cold metadata behind small caches. Preserve hot
instructions, stack/heap semantics and fast operand access. Do not move the
entire VM heap to uncached DDR, shrink program limits, or delete language
features to claim savings. A microcode store costs memory and can add cycles;
only synthesis plus instruction-level checks can establish its benefit.

## Proposed service boundary

Disk supplies FINDER.JSH, application JSH files, SYSTEM.SYS and TOOLBOX.ROM.
The ROM code loads into its dedicated BRAM bank. Its boot staging temporarily
uses the existing SYS staging region, which SYSTEM.SYS subsequently replaces.
The 8 MiB allocation and artwork limits do not change. The existing 256 KiB
system reservation is already allocated; it is not free space.

Applications call a versioned service interface. Software handles policy and
queues compact graphics commands; the hardware executes spans/copies and
publishes completed dirty regions. UI descriptions should be read sequentially
or rasterized into a small reusable overlay, avoiding a huge combinational
menu-state bundle feeding every pixel. Do not allocate another full-screen
BRAM overlay. Preserve click/draw geometry consistency and overlay restoration.

The one graphics call still missing is QuickDraw **CopyBits** (Inside Macintosh
Volume I, 1984). Native 64 does not implement it yet. `toolbox(6, …)` returns -1. Do not ship
a title that calls it. No second call is needed for the current games:
ScrollRect, SeedFill, ovals, polygons, and region algebra are not their cost.
Rectangular clipping is the grafPort clip the 128K already applied around
CopyBits. A general region stays out of the FPGA.

```javascript
// srcCopy between two bitmaps. Screen bitmaps use flag bit 1.
// Same width and height. Returns the pixel count, or -1.
toolbox(6, srcDescriptor, dstDescriptor, 0);
```

A bitmap is the existing 64-byte descriptor. Flag bit 0 remains transparent
zero. Flag bit 1 means this side is the drawing framebuffer: 640×480 palette
indices, one byte each, the pixels scanout already shows. The 128K screen was
1 bit. This screen is already 8-bit indices, so the copy stores those indices.
A 1-bit copy cannot put a colored girder back. This is not a PixMap, a color
table, or a new palette.

The other side is an arena surface at 1, 4, or 8 bits, as operation 3 already
addresses it. Source rectangle is descriptor bytes 14–21. Destination
rectangle is bytes 22–25 for the origin and bytes 18–21 for the size. The two
rectangles match in size. Scaling, `srcOr`, `srcXor`, and `srcBic` were part
of the same 128K call and are not required by the games below. A non-zero mode
returns -1. The destination clip is bytes 26–33. Overlap of two arena bitmaps
is memmove order. The call does not flip the screen.

Game pattern, glass pixels, after the still picture is already drawn:

```javascript
function tbCopy(src, dst) { return toolbox(6, src, dst, 0); }
// Once: screen rect (0,24,640,456) into arena byte 0.
// Each actor: copy that rectangle from the arena back onto the screen,
// then drawImage the actor. A changed cell is drawn, then copied back
// into the arena. Donkey Kong's 0.42 world scale is converted to glass
// pixels before the rectangle is stored.
```

Implemented residency uses a canonical instruction prefix and a separate bank
on the existing native JavaScript engine. The host linker checks code identity;
library changes require the matching ROM and relinked clients. Constants, names,
globals and heap state remain per application. The standalone compiler supports
native primitives but does not perform this linking. A resident-marked source
must use a host-linked JSH. Keep the hardware recovery menu available.

For more capability, fonts should draw into document surfaces as well as the
screen. The same primitives support window scrolling, selections, clipping,
real styled text, Undo and image transforms across applications.

## Order of work and proof required

1. Add bounded memory block copy/fill and a surface blit supporting the current
   one-byte-per-word staging layout and packed 1/4-bit document formats. Handle
   overlap, clipping, transparency and bounds explicitly. Use burst-friendly
   buffered chunks; do not starve scanout or event handling.
2. Use these in MacPaint Undo, preview restore and rectangle spans. For solid
   outlines, four strips are sufficient. Restore only damaged borders/regions
   where appropriate; filled/patterned previews need their actual damaged area.
   Coalesce obsolete mouse-motion previews but retain every down/up edge.
3. Move one native dialog into the shared software layer. Establish reusable
   window/menu/font services and event handling before removing the old RTL.
   Keep menu responsiveness when application code is busy; one VM cannot run
   a service magically without scheduling or a bounded yield mechanism.
4. Replace additional UI policy and the wide UI snapshot with compact staged
   commands/state. Extend SYS to a versioned template/metric format. Re-synthesize
   to measure **net** savings, including the replacement service machinery.
5. Only then target the dominant VM cost: bank/cache code or cold metadata and
   serialise infrequent control paths. More RAM can lift limits, but access
   latency and locality determine speed. Keep 8 MiB for this sequence.

Focused acceptance: exact pixels for clipped/patterned rectangles and Undo;
copy-overlap and pending-write coherence; one drag's cycles/native-call count;
bounded mouse/keyboard latency; retained game instruction timing; simulator
and real-board parity. No broad game benchmark campaign is needed. Claim no
2× overall speedup or LUT/BRAM savings before those measurements exist.

The expected first win is far fewer VM calls and memory transactions at the
same clock. Freed UI logic may improve placement and allow later clock gains,
but a smaller netlist does not guarantee a faster clock or a quicker build.
