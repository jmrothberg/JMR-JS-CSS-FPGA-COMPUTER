# Write graphics that restore correctly

Use GRAPHICS.HTML as an operations gallery and DAMAGE.HTML as a small moving
scene. These are native JavaScript resident-v2 clients, not browser emulation.
Run them with the matching Toolbox ROM/LNK and supported bit. The revision package supplies ROM/LNK and freshly linked JSH files together.
Do not run those new clients against the earlier b022 library.
Compile with `tools.compile_js.compile_html_text` / `encode_html_chunk` after
changing source. Never paste the resident library into a marked client.

## Choose the layer

Use Canvas fillRect for solid rectangles and its existing path/circle operations
for shapes. Use Toolbox op3 for packed1/4/8-bit sprites, integer enlargement and
transparent-zero drawing. Use op6 for raw indexed rectangle capture, scrolling,
and restoration. Use op7 for Boolean byte operations, masks and8×8 patterns.
Menus, dialogs, brush policy, regions and document actions remain shared
JavaScript. They are not separate RTL engines. See UI_USAGE.md for the two
separate UI approaches; do not install both event/RAF owners in one program.

## Two coordinate spaces

Canvas transforms affect Canvas calls. They do NOT affect raw Toolbox descriptors.
For `setTransform(1,0,0,0.95,0,24)`, a logical rectangle becomes:

- left=floor(x), right=ceil(x+w)
- top=floor(24+0.95*y), bottom=ceil(24+0.95*(y+h))

The RTL stores scale as16.16 fixed-point and truncates transformed coordinates.
At0.95 and y100, the RTL center is118 after+24, while the floating-point model
places it at119. For exact positive integer coordinates use
`floor(y*62259/65536)+24`; for conservative cleanup using the floating formula,
expand top/bottom by at least1 physical pixel. DAMAGE does that and keeps circle
damage in physical radius units with a2pixel guard.

Clip these physical edges to the screen/cache before forming width and height.
Use the same transformed edges for capture and restoration; transforming a
position while leaving height unchanged creates trails. The DAMAGE example
handles this positive axis-aligned transform only. Rotation, negative scaling
and shear require transforming all corners and preserving appropriate clipping.
Expand dirty bounds for strokes, text ascent/descent and other raster coverage.
For a guaranteed physical pixel, switch temporarily to identity transform and
draw fillRect(physicalX,physicalY,1,1), then restore the prior transform. A logical
height1 under0.95 scaling can truncate to0 and disappear. For tiled borders, map
shared endpoints and enforce at least1 physical pixel when that is the intended
UI rule. Do not independently truncate each tile height: that leaves gaps.

The implemented native arc transforms the center but does not shrink the radius
with the game viewport Y scale0.95. Do not assume browser elliptical scaling.
Conservative damage must cover the actual physical radius around that transformed
center, plus stroke coverage; mapping only a logical diameter can under-erase.
See the corrected MISSILE explosion bounds. The Python path model additionally
applies X scale to radius, so arbitrary non-unit X scales need explicit RTL
qualification; these examples use X scale1. A radius1 circle is not one pixel.

## Own the background and previous damage

1. Reserve descriptors, masks and surfaces in an explicit, disjoint memory map.
   Do not assume that spare-looking MacPaint document/Undo bytes are free.
2. Draw static background, then capture it BEFORE drawing moving objects.
3. Keep the rectangles actually drawn last frame. Store them independently of
   actor objects so deletion of an actor cannot delete its cleanup record.
4. Restore ALL old rectangles before drawing ANY current object. Interleaving
   restoration and drawing lets a later restore erase an earlier new sprite.
5. Draw current actors, labels, particles, selection borders and transient UI;
   record every region they touched. Overlapping dirty rectangles are valid.
6. When static terrain changes, first restore old actors. Clear the old tile's
   entire opaque bounds, draw its replacement, then refresh that cache region.
   Transparent pixels do not erase the old tile by themselves.

DAMAGE.HTML uses this sequence, including deleted circles/text and a transparent
tile becoming empty. It copies small dirty rectangles on ordinary frames; it
does not silently replace damage tracking with a full-screen transfer.
A full redraw is appropriate when the background/transform/palette globally
changes. Invalidate the cache in that case, rather than restoring stale indices.

## Descriptor rules that matter

Both op6/op7 descriptors must specify the SAME rectangle width and height.
`tbScreen` initializes640×480, so always follow it with `tbRect` for a small
request, including the DESTINATION descriptor. Destination source x/y fields
are ignored; destination placement uses `tbPlace`. Source must fit completely;
only destination is clipped. A successful clipped request returns requested
area, not visible pixel count. Check for−1 and do not treat errors as empty draws.

All staging addresses are logical bytes, not physical SRAM words. Pixel data is
palette INDEX bytes, not RGB. Finder white255 and ordinary PAL white1 are not
interchangeable. Boolean modes operate on those index bits. XOR255 is not a
promise of visual RGB inversion. Do not reuse a cache after changing palette.

Mask rows are high-bit-first and request-relative. Reserve ceil(width/8) bytes
per row; mask storage cannot overlap an arena destination allocation. Pattern
phase for op7 follows physical destination coordinates; op4 follows source
surface coordinates. Geometry is required even when pattern/invert needs no
source pixel value. Use tbMaskOff/tbPatternOff before reusing a descriptor, or
initialize it anew. Op6 does not accept op3 transparency/packed formats.

The previously installed tbPaintRect helper has a destination-size omission.
The final revision GRAPHICS invokes the fixed public helper. The reviewed helper correction adds destination `tbRect`
and independent pixel/capacity evidence:8191/8191 resident words, zero spare.
Do not distribute that ROM alone: every resident client and LNK must match it.
The corrected helper must be installed together with its matching ROM/LNK and
relinked clients.

## Verification and limits

`check.py` compiles and executes the actual gallery through the native-instruction
model, checks return values and operation/mode coverage. `check_damage.py`
compares13 scripted frames against a fresh-background reference pixel-for-pixel.
`check_helper.py` proves the old helper rejects small rectangles and the fixed
helper draws exact phase/clipped pixels and rejects invalid source geometry.
The GRAPHICS example also passed the run79 full RTL simulator after cold-loading
and reading back all8192 words of the new resident bank. Its packed/raster/mask/
pattern/copy/clipping pixels match the model; the scaled circle matches after
the explicit16.16 one-row correction described above. DAMAGE and UI/session
checks are native-instruction model checks, not RTL coverage of those programs.
No FPS/game benchmark or physical acceptance is claimed. Evidence is retained
in `build/toolbox_usage_examples/revision/rtl_gallery/evidence.json`,
`build/toolbox_usage_examples/damage_checks.json` and
`build/toolbox_usage_examples/ui_model_checks_fixed.json`.

Stay within compiler/runtime limits:16 locals including parameters,128 array
items,32 object properties, and actual image/variable capacities. Use explicit
functions rather than assuming arbitrary prototype-method dispatch. Reserve
shared session scratch380320..380927 and document continuation fields if using
the high-level UI; neither graphics example writes there. SYSTEM.SYS resource
reads require the cold-boot snapshot and return−1 when unavailable.
