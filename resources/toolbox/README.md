# Shared native-JavaScript Toolbox

`toolbox.js` wraps the small RTL memory/graphics engines. `ui.js`, `session.js`
and `documents.js` implement shared UI and document policy on the existing VM.
The resident virtual prefix is8192 instructions (32KiB), with8191 mutable words
and one fixed final jump. Mark clients `<!-- jmr-toolbox: resident-v2 -->`.
Host and standalone compilers support the matching v2 ROM/LNK contract.

The factory ROM is embedded in the qualified bit. The matching disk ROM replaces
it at cold startup; a software library change requires matching ROM/LNK and
relinked clients, not an automatic factory-bit rebuild. Never mix client/ROM IDs.
The corrected helper revision occupies8191/8191 words, with no spare instructions.
It must be installed with all matching relinked clients and its linker manifest.
See TOOLBOX_USAGE.md, TOOLBOX_API.md and RESIDENT_TOOLBOX.md for ownership and API.
