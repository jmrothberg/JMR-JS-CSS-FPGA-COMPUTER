# Resident Toolbox: files, linking, updating

The Toolbox is a JavaScript library compiled once and loaded into its own
instruction bank at boot. Programs call it like ordinary functions. It runs
on the same native JavaScript processor as the program.

Only the **instructions** are shared. Constants, globals, objects and arena
bytes belong to the running program. One program runs at a time.

| For | Read |
|---|---|
| Memory and graphics calls | [TOOLBOX_API.md](TOOLBOX_API.md) |
| Menu, window, dialog, document and file calls | [SYSTEM_APPLICATIONS.md](SYSTEM_APPLICATIONS.md) |
| Which bitstream to load | [FPGA_FIT.md](FPGA_FIT.md) |

## Files

| File | What it is | Made by |
|---|---|---|
| `resources/toolbox/toolbox.js`, `ui.js`, `session.js`, `documents.js` | Library source, compiled in that order | hand |
| `resources/toolbox/*_client.js` | Optional modules copied into programs. Not in the bank | hand, `tools/sync_toolbox_clients.py` |
| `storage/TOOLBOX.ROM` | The compiled library, loaded at boot | `tools/toolbox_linker.py` |
| `storage/TOOLBOX.LNK` | Link table for the on-device compiler: names, constants, globals, function entries, and the identity of the ROM it matches | `tools/toolbox_linker.py` |
| `vectors/toolbox_code.hex` | The same library for the Python model | `tools/toolbox_linker.py` |
| `storage/SYSTEM.SYS` | Appearance data, including the UI font. Not code. See [SYSTEM_RESOURCES.md](SYSTEM_RESOURCES.md) | `tools/build_system_resources.py` |

`TOOLBOX.ROM`, `TOOLBOX.LNK` and every linked program on a card must come
from the same link. The host file transfer refuses to replace `TOOLBOX.ROM`
or `TOOLBOX.LNK` alone.

### TOOLBOX.ROM format

Little-endian, 32784 bytes.

| Bytes | Field |
|---|---|
| 0–3 | `JMRT` |
| 4–5 | version 2 |
| 6–7 | header length 16 |
| 8–11 | payload length 32768 |
| 12–15 | CRC-32 of the payload |
| 16– | 8192 instruction words, u32 each |

The last word must be `0x0020000b`, a jump to address 8192.

`TOOLBOX.LNK` starts with `JMTL`, version 2, and a 64-byte header that holds
its own CRC, the ROM payload CRC and the ROM fingerprint.

## The instruction bank

| Addresses | Holds | Limit |
|---|---|---|
| 0–8190 | Toolbox library | 8191 words. The linker fails if the library is larger |
| 8191 | Fixed jump to 8192 | not usable |
| 8192– | The program | 29696 words of code and metadata, 1024 global bindings |

## Boot

At cold start the machine reads `TOOLBOX.ROM` from the card. It checks the
header, length, CRC and last word, then copies the words into the bank. The
bitstream holds no copy of the library: the bank starts empty. If the file is
missing or fails a check, Finder does not start and the recovery display
shows `?TB`. The ROM is staged in the SOURCE region while it loads.

The bank is loaded only at cold start. Finder's Restart and a game's Restart
reopen a program; they do not reload the library.

## Linking a program

Put this comment in the first 1024 bytes of the HTML:

```html
<!-- jmr-toolbox: resident-v2 -->
```

The compiler then compiles the library first and the program after it, so the
program's calls resolve to bank addresses. Without the comment the program is
compiled standalone and has no Toolbox functions.

- Do not paste library source into a marked program.
- A program may not define a function whose name is a Toolbox function or
  starts with `_tb`.
- `resident-v1` programs are rejected. Relink them.
- `<script src>` is not supported. Shared modules are inline copies.
- Keep each string literal within 255 UTF-8 bytes. The on-device compiler
  rejects longer ones.

Host compile: `tools.compile_js.compile_html_text` then `encode_html_chunk`.
`python3 tools/make_sd_image.py create card.img` compiles every program in
`storage/` and builds the card. `python3 tools/check_port.py storage/NAME.HTML`
reports compiled size against the limits. On the machine, Compile uses
`TOOLBOX.LNK`.

## Updating the library

1. Edit `resources/toolbox/*.js`.
2. `python3 -m tools.toolbox_linker` writes `TOOLBOX.ROM`, `TOOLBOX.LNK`
   and the Python model's `vectors/toolbox_code.hex`.
3. If a `*_client.js` changed: `python3 tools/sync_toolbox_clients.py --write`.
4. `python3 tools/make_sd_image.py create card.img` relinks every program.
5. Cold-start the machine.

This needs no FPGA build as long as the library fits the bank and uses only
existing native calls. A larger bank, a new `toolbox()` operation, a new
pixel format or a new memory range is a hardware change: RTL, a build, and a
new bitstream ([FPGA_FIT.md](FPGA_FIT.md)).

The linker fails if the glyph-width string in `ui.js` differs from the font
advances in `resources/system/system.json`.

## Private state

Library variables named `_tb…` are private. At link time
`tools/toolbox_state.py` groups them into per-program objects of at most 16
fields. Programs must not read or write them.
