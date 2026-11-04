# Finder return / View correction — November 4, 2026

Includes the earlier cold-RAM initialization correction. Use with the existing
run75 .bit and SYSTEM.SYS. Copy FINDER.HTM and FINDER.JSH to the physical card
root, replacing those two files, then reboot to refresh the resident cache.

Fixes: an already-selected icon could enter rename on the first click of a
double-click; launching then parked that rename state. It reappeared on return
and swallowed View menu commands. Finder now ends rename before launch, on
new pointer gestures and on menu actions. Cold start sets the previous-click
slot to an invalid value, so the first click cannot accidentally double-click.
Ordinary icon selection is retained; the unintended text-edit cursor is not.

The name-copy helper is reused to stay within existing program limits:
148,208-byte JSH, code_end 81,896 within 81,920 bytes. No FPGA resources, clocks,
bitstream or SYS format changed. Python regression tests passed (8 tests).
Actual RTL simulation passed Note launch/resident Finder return, cleared rename
state, View changes after return, and Terminal core ASCII input. This does not
exercise the physical PS/2 connection. Evidence: rtl-note-return.log in the
investigation below. Local card.img and storage/FINDER.JSH are updated; close
and reopen the GUI before testing.

This update does not claim to repair the physical PS/2 problem. Terminal accepts
on-screen typing; the owner also found the physical keyboard fails with an older
working bitstream. JA/JC comparison using the saved multi-port probe, followed
by a keyboard/adapter comparison if needed, will isolate that hardware path.
Power off before moving the adapter; power on and reload the temporary probe
before typing. The normal full computer listens only on JA.

Old source/program and logs are preserved in
../../../build/run75_input_return_debug/. Cold-start-only update remains in
../run75-finder-cold-start-2026-11-04/. No physical card or FPGA was programmed
by this update.
