# Shared native JavaScript Toolbox

The run81 candidate has one resident instruction bank and ordinary shared client
modules. `toolbox.js`, `ui.js`, `session.js` and `documents.js` supply the resident
implementation. Its 8096/8191 mutable words leave 95 spare; the fixed final jump
is separate. Per-app physical code+metadata stays limited to 21504 words and
512 bindings. No instruction or memory bank grows.

The `*_client.js` files are shared sources with exact copies embedded into the
shipping HTML. Both standalone COMPILE and host mint therefore execute the same
software. Run `python3 tools/sync_toolbox_clients.py` to check or add `--write` to
refresh. Window stacks/raster constructors and bounded draw emission are optional modules; document chrome,
filename policy and Editor/Note SOURCE callbacks live with their clients.

The native64 ABI remains version1, now operations1–12 (capabilities0x10fff).
Typed-memory mask0x780 plus destination-clip bit0x800 are required by this matched
candidate. Existing older bits cannot run this software correctly. `tbUIInit`
fails explicitly and draws a matching-FPGA diagnostic when these services are
missing. No new native ID or second event/frame owner is introduced.

Once the required interface is in a qualified bit, software policy can be
updated through matched ROM/LNK/relinked clients/resources and cold restart.
Changing circuits still needs RTL, Vivado and a qualified replacement bit.
No FPGA build, media write or physical qualification is claimed here.

Shared Windows/Controls/Ports/Damage, typed transport, raw versus local graphics
coordinates, ownership, clipping/scrolling and callback contracts are documented
in [TOOLBOX_API.md](../../docs/TOOLBOX_API.md). The typed normalized TBF1 font still
preserves legacy SYS bytes0..20607, per-app64-byte descriptor and32-byte scratch;
95 canonical widths remain available before UI initialization. See the candidate
software manifest for the one matching disk and exact evidence.
