# Run75 Finder cold-start correction — November 4, 2026
Use with the existing run75 .bit. No new FPGA build or flash is needed for this
Finder correction. Copy **FINDER.JSH and FINDER.HTM** from this folder to the
root of your physical FAT card, replacing those files; keep SYSTEM.SYS and all
other files. Power-cycle the board so the resident Finder cache is replaced.

The project card.img and storage/FINDER.JSH are already updated. Close and
reopen gui_jmr_js.py before testing Python or FPGA-SIM. The rebuilt simulator
uses bounded execution slices so a long Finder paint yields to input. Its
cosmetic startup timer is scaled for software simulation; board clocks and
game execution are unchanged. The first real RTL paint still takes time.

## Fixed and checked

Finder previously assumed external scratch RAM was zero. Cold start cleared
only its init flag, leaving window, dialog, rename/drag and icon-cache metadata
uninitialized. These could corrupt the desktop and consume keyboard input.
Finder now initializes metadata on cold start; resident returns preserve state.

Old Finder reproduced stale UI/input flags with RAM seeded to 0xA5. Final Finder
passed actual RTL dirty-RAM boot without a saved desktop file, correct window
geometry and keyboard arrow selection. Seven Python Finder tests passed.
An unattended GUI boot also checked that DDR front image equals the BRAM
canvas. The PS/2 receiver/decoder/console typing test passed separately.

Physical JA keyboard operation and the corrected picture still need board
confirmation. Open Terminal and type there as well as trying Finder arrows.
If the keyboard remains inactive, retain that as an unresolved board issue;
the simulated test is not proof of physical input operation.

## Preservation and evidence

Original qualified run75 bit and disk package remain unchanged in
../../../build/run75_program_system/. Investigation, old Finder files, test
scripts/logs/screenshots and pre-update card backup are in
../../../build/run75_boot_debug/. SHA256SUMS identifies this update's files.
The new Finder image is 148,220 bytes, within the existing 160 KiB resident cache.
