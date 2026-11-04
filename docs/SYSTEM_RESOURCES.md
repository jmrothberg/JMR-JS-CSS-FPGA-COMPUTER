# SYSTEM.SYS: disk-updatable shared appearance

[Memory map](lastrun_ARCHITECTURE.md). Which bit: [FPGA_FIT.md](FPGA_FIT.md).

## Use it

`SYSTEM.SYS` is a resource bundle, not an executable or another programming
language. Its editable source is JSON. The Python packer checks the source and
produces the small binary that RTL reads sequentially. Application behavior
continues to use JavaScript. FPGA primitives continue to use SystemVerilog.

Edit `resources/system/system.json`, then, from the project root:

```sh
.venv/bin/python tools/build_system_resources.py --image card.img
```

That writes `storage/SYSTEM.SYS` and replaces **only SYSTEM.SYS** in the existing
image. Existing documents, applications and desktop positions stay on disk.
Quit and reopen `gui_jmr_js.py`, select FPGA-SIM with F9, and test. Python uses
the same binary from its mounted disk. Editing the JSON without packing and
publishing it does not change either runtime. No simulator or bitstream rebuild
is necessary for supported resource edits.

To prepare a file without touching an image:

```sh
.venv/bin/python tools/build_system_resources.py --output storage/SYSTEM.SYS
```

Normal disk-image creation includes `.SYS`; the GUI's card-file transfer list
also includes it. The run75 hardware build includes this loader; its build/qualification status is
recorded in `build/run75_program_system/README.md`. No physical card has been
written by this update. With a board release containing the loader, copy SYSTEM.SYS to that
board's disk and power-cycle it to load the update.

## What can change

- The shared 16-row monochrome font: menu bars, native captions/dialogs, and
  keyboard legends. `font` names a Chicago-format glyph JSON file relative to
  the source JSON. `glyph_overrides` changes individual glyphs without replacing
  the whole file. A glyph has `offset`, `advance`, and up to 16 strings of `0`/`1`
  in `rows`. **V1 keeps the original advance for every printable character.**
  You can change glyph shapes/family within those cells, not font size or spacing.
- Fixed menu headings: label IDs 110 File, 111 Edit, 112 View, 113 Special,
  114 Game. Displayed headings can change; their semantic identity stays fixed.
- Native menu and dialog captions: IDs 120–171, plus window captions 81–104.
  Examples: 123 Save, 125 Quit, 142 Cancel, 143 Open, 144 Replace, 145 OK,
  146 Save-changes prompt, 147 Save-name prompt, 149 Replace prompt, 165 Discard.
  The JSON contains the full list. Single-glyph navigation marks and the clipped
  Modified marker keep their fixed text selector; their glyph shapes still use
  the loaded font. Ship-menu labels and keyboard layout keep their existing text
  and commands; keyboard bitmaps are rebuilt with the chosen font.
- `dialog_offsets`: move each entire native document dialog, including its
  text, list/name field, buttons and mouse hit regions. Coordinates are offsets
  from the built-in position: x −60..60, y −40..16. The dialog types are `open`,
  `save_as`, `changes`, `replace`, `message`. About is not a document dialog.
- `dialog_buttons`: three `[x, y, width]` slots per dialog, in unshifted screen
  coordinates. The entire-dialog offset is added afterwards. Existing button
  actions/order stay fixed; unused slots must be `[0,0,0]`. Buttons remain 26 px
  tall, below the fields, inside their dialog, and separated by the default-ring
  margin. The packer checks bounds, overlap, and caption fit.
- `rounded_buttons` and `default_button_outline` select native button styling.

The default `save_as` buttons are Save `[152,214,84]`, Cancel `[252,214,96]`, and
an unused slot. For example, changing the Save x to 160 and Cancel x to 270
moves both controls and their clickable areas. Changing label 147 to
`Save your document:` changes the prompt. Use `dialog_offsets.save_as: [20,8]`
to move the whole dialog right 20 and down 8 pixels.

Application-owned menu rows, About descriptions and Finder desktop behavior
remain in each HTML/JavaScript program using `ctx.systemMenus` and
`ctx.systemAbout`. Update/re-mint its JSH for those edits; this also needs no new
`.bit`. SYSTEM.SYS does not create new application actions or change the
keyboard's key codes. Finder's desktop lettering is currently an embedded image
inside FINDER.JSH, independent of the native menu font. Game artwork/fonts and
VM canvas `fillText` are likewise not silently replaced. Use program updates
for those. This separation prevents a system font edit from altering game art.

Document dialog box dimensions and field arrangement remain fixed in V1; this
is a resource loader for the listed controls, not an arbitrary widget language.
New primitives, font metrics, dialog types or menu-action machinery need RTL.
Resource edits avoid future hardware builds; they do not promise faster routing
when a hardware build is actually needed.

## Instructions to give an agent

> Update the shared appearance by editing resources/system/system.json. Read
> docs/SYSTEM_RESOURCES.md first. Keep resource format 1, the original glyph
> advances and native action identities. Change only the requested captions,
> glyphs, dialog offsets or button placements. Do not edit generated RTL,
> defaults.json, or start Vivado. Run the packer with --image card.img, run
> tests/test_system_resources.py, and restart gui_jmr_js.py for testing. If the
> requested change is application behavior or an application-owned menu, edit
> its HTML and publish the matching JSH instead. Report precisely which files
> were updated and which visible changes were checked.

## Loading, memory and recovery

The existing 8 MiB address map is unchanged. The previous 256 KiB system
reservation still holds the 160 KiB Finder image cache, 72 KiB parked arena,
and 24 KiB resource staging area. The resource payload is 24,320 bytes;
its 16-byte header is checked in registers. It fits the 24,576-byte staging
area at SRAM word 3,565,568, immediately below framebuffer word 3,577,856.
Artwork remains limited to 6,893,568 bytes. No second framebuffer or VM is added.

Before first loading Finder, the console opens SYSTEM.SYS through the real FAT
engine. It verifies magic/version/length and CRC-32, closes the file, then copies
validated words to the UI memories. Missing or rejected files on a cold start
leave the initialized built-in resources intact. No partially read or bad-CRC
file is applied. The loader runs at boot; it does not read the disk during game
frames. Close/reopen the simulator or power-cycle the board when changing files;
this version does not offer a live resource-reload command or a transactional
rollback for reset during the short RAM-commit phase.

Rollback: restore the previous SYSTEM.SYS and restart, or remove it and cold-start
with built-in resources. `resources/system/defaults.json` is also a source for a
known-default bundle. Build it with the same packer and `--image card.img`.

UI font, fixed-caption and keyboard bitmap memories now have boot write ports;
scalar writes and clocked display reads avoid per-pixel filesystem work.
Display-memory writes cross through an acknowledged transfer into the pixel
clock; the loader waits for each committed word before resuming Finder. Menu
action lookup uses staged reads, adding only a few cycles to a click. Actual
FPGA utilization and timing come from synthesis/place-and-route reports. The run75 build measures these; see its build record. Game clock settings
were not changed.

## Binary format 1 (for maintainers)

All numbers/bitmap words are little-endian. Header: `JMRS`, u16 version 1,
u16 header length 16, u32 payload length 24320, u32 standard CRC-32 of payload
(zlib/IEEE reflected polynomial 0xEDB88320). Exact length is required, including
no trailing bytes. The boot receiver uses the same CRC convention as Python.

Payload byte offsets:

- 0: 2048 u16 font rows (128 glyphs × 16 rows, bit 15 is the left pixel).
- 4096: 2048 u16 caption records (ASCII in bits 6:0, advance in bits 10:7).
- 8192: 256 u32 caption indexes: base bits 10:0, count bits 17:11, pixel width
  bits 27:18. Unused bits are zero. Total text capacity is 2048 characters.
- 9216: five 16-byte NUL-padded menu headings; remaining bytes through 9343 zero.
- 9344: five signed i16 x/y offset pairs, u16 rounded flag, u16 outline flag,
  then fifteen u16 x/y/width button triples in dialog and slot order. Remaining
  bytes through 9471 are zero.
- 9472: 2048 packed five-byte keyboard bitmap rows, using existing key IDs.
- 19712: 64 u64 ship/keyboard caption bitmap rows.
- 20224: 48 u64 rows for the Finder ship-menu Note, Help and Utility captions
  (16 rows each). The rest of this old About region is reserved and emitted as zero; current About
  text uses native captions. The total payload size stays unchanged.

Do not hand-edit the binary. The compiler performs text-fit and geometry checks
that raw byte editing would bypass. The RTL bounds physical writes and validates
file integrity, but CRC is not a substitute for the source compiler's UI checks.

The simulator's read-only `SYS?` reports 0 pending, 1 loaded, 2 unavailable,
3 rejected. `SYSBYTES?` reads actual consumer memories for test comparison;
it does not return a copy of the staging buffer.

## Checked in this handoff

The rebuilt RTL simulator booted the published disk into a painted Finder.
Default and edited bundles matched all live consumer bytes. CRC corruption,
truncation, unsupported version and missing-file cases retained cold defaults.
Native Save As tests checked normal filenames, cancellation, and a moved button
inside a moved dialog. Six focused Python resource/menu tests passed. Python
also loaded the published SYSTEM.SYS from the disk. See
[verification files](../build/system_resources/README.md).

The run75 parity work adds both Python startup pictures, filename insertion
caret and I-beam, mouse-up menu actions, held-button feedback and Finder ship
accessories. Startup and Save As normal/held pixels match Python exactly in the
standalone RTL renderer check. See `build/run75_program_system/tests/` for the
remaining integration results and the run75 build record for hardware status.

Startup typography also reads SYSTEM.SYS in Python and RTL. Caption IDs 160
(JMR Enterprises), 170 (NCC-1701), and 171 (Welcome to Javatosh.) are resource
text; their original positions and scale are fixed. Preserve those caption
widths when editing startup text. The Enterprise silhouette and checker layout
are compact fixed drawing primitives, not a bitmap framebuffer in BRAM.

The old ship-menu About bitmap RAM has been removed; native About uses the
shared caption/font renderer. Fixed dialog configuration loads once through the
pixel resource bridge instead of being copied with each live UI snapshot.
