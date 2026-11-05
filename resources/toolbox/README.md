# Shared Toolbox sources

`toolbox.js` wraps hardware bulk memory and surface operations. `ui.js` implements
shared menus, windows and dialogs in native JavaScript. Both execute on the
existing VM. The resident linker builds their shared 16 KiB instruction bank.

Start with `docs/RESIDENT_TOOLBOX.md` for calls, memory ownership and rebuilding.
`storage/TBDEMO.HTML` is the complete client example. Primitive details are in
`docs/TOOLBOX_API.md`; application migration guidance is in
`docs/TOOLBOX_MIGRATION_GUIDE.md`.

Host compilation links HTML marked `<!-- jmr-toolbox: resident-v1 -->`.
The standalone compiler supports native Toolbox calls, but not resident linking.
Never publish a newly linked client without its matching `TOOLBOX.ROM`.
