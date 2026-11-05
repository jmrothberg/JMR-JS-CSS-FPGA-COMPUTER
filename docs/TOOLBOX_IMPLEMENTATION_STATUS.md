# Toolbox implementation status

Active work, 2026-11-04. The complete Macintosh-style migration is **not
finished**. Native JavaScript remains the CPU, VM/fast clocks remain
33.333/100 MHz, and memory remains 8 MiB. Run77d (including CopyBits) synthesis/implementation is running from frozen inputs; no new board bit
has yet been qualified or flashed. One checkout; no branches.

## Implemented and checked

- Native 64 `toolbox(op,a,b,c)` uses the existing cold S_FS handshake, command
  7. Filesystem commands 1–6 retain their meanings. The VM resumes after a
  Toolbox call; its hot execution datapath is unchanged.
- General bounded memmove/fill, packed 1/4/8-bit surface copies, clipping,
  scale 1/2/4/8, transparency and pattern fills. Adjacent packed pixels reuse
  their source byte. No application-specific hardware.
- Read-only access to the verified boot SYSTEM.SYS payload in its existing
  DDR staging area, with matching Python boot-snapshot behavior.
- MacPaint's copyRange uses bulk memmove. Its complete undo snapshot uses two
  calls rather than 230400 byte-access calls. The user's strip/block preview,
  packed writes and docClean work is preserved. No measured speed factor is
  claimed. The new MacPaint requires a Toolbox-capable runtime.
- Shared native-JavaScript menus/dialogs and a genuine 4096-word resident
  instruction bank, boot-loaded from TOOLBOX.ROM. Per-app mutable state remains
  separate. Host linker and complete TBDEMO client: RESIDENT_TOOLBOX.md.
- Utility builds its own catalog with fsList and sorts an index in JavaScript.
  Its dedicated catalog-preparation/restart RTL and Python host preparation
  were removed. Launch still uses the established console/file path.

Focused standalone RTL tests pass bounds, overlap, arena seam, delayed SRAM,
packed surfaces, clipping, scaling, transparency, patterns, read-only resource
byte order and unavailable-resource rejection. Complete-core RTL tests passed
native dispatch, resume, invalid-write rejection, exact scaled framebuffer
pixels and resident resource access before the Utility change. The expanded
complete-core test now also exercises the real Utility tool-launch path; it passed (5 tests, 138.44 s), recorded in `build/toolbox_development/toolbox_pytest4.log`.

Python system-resource/application checks: 12 passed. They include Note,
Reader, Editor, Utility, menus, closing windows, and opening another Markdown
file. Source-helper tests compile and execute the sample packed-surface blit.

## Synthesis evidence, not board qualification

Latest isolated Toolbox: 1559 LUTs, 4 DSPs, zero BRAM, estimated setup slack
+0.606 ns at 100 MHz. Geometry/clipping was pipelined to remove the first
isolated timing failures. This is not placed/routed board timing.

Isolated lifecycle controller before/after Utility migration: 810 → 559 LUTs,
461 → 268 registers, zero BRAM/DSP. This saves 251 LUTs in that module. The new
Toolbox is larger than this first saving; no net whole-system area reduction
or higher operating clock is claimed yet.

## Current verification and remaining release work

Run77b inputs are frozen in `build/run77b_resident_toolbox/source/`; hashes are in
`source.sha256`. The build is running with the established 33.333/100 MHz clocks,
USB keyboard J15, PS/2 mice JA/JC and joystick JB. Existing run75/run76 releases
are untouched. Run77 stopped at its LUT gate (118105 versus 114000). Run77b keeps app code
in BRAM and uses three spare BRAM tiles for resident instructions; synthesis now measures 112642 LUTs, 364 BRAM tiles and 132 DSPs,
passing the synthesis gates. This is 5463 fewer LUTs than failed run77.
Placement/routing and final timing are still pending.

Complete-core RTL test passed resident-linked execution, bulk service results,
framebuffer pixels and Utility launch (142.24 seconds). Run77b passed all 18 Toolbox/resource tests, including software UI,
ROM-load and instruction-identity rejection; the separate padding test passed. Python native-VM tests pass
menu/modal events, Chicago pixels, fixed prefix linkage and identity mismatch.

Still required: inspect whole-chip resources,
complete place/route, qualify timing/DRC and publish the matched bit and disk.
The separate disk is `build/run77b_resident_toolbox/disk/card_run77b.img`.
Main card.img has not been replaced with new native-64 clients.

The standalone compiler recognizes native Toolbox calls but does not link
resident clients. Use the host compiler and marker documented in RESIDENT_TOOLBOX.
Legacy native menu/dialog controllers remain supported for unconverted apps.
No whole-system speed factor or net area reduction is claimed before measurement.


The Finder launch handoff now waits for a stable console after its delayed
keyboard-FIFO clear. Before the fix, `LOAD` became `OAD`; the full disk test now
starts TBDEMO from its FAT JSH successfully. A focused delayed-drain test passes.
The extended core test passed shared menu selection, name input and dialog
pixels (158.44 seconds). Existing system-app/menu checks: 9 passed, 1 skipped.
Run77b's updated software list dialog also has mouse-only scroll buttons.

Run77b normal disk acceptance passed: valid ROM/SYS boot, Finder startup, FAT
launch of resident-linked TBDEMO, and real mouse File/Open dispatch. Evidence:
`build/run77b_resident_toolbox/verify_disk.log` and `toolbox_tests.log`.

Extended disk acceptance also passed mouse Cancel, software File/Quit, and
return to Finder (`verify_disk_final.log`). Ordinary RUN applications must use
`sysRun(pointer,8)` with an empty staged name for explicit Finder reload;
`cdone()` only reports completion to the system-tool/compiler chain. The demo
and resident API guide now show this distinction. The displayed dialog was
visually checked from the RTL framebuffer with its actual palette.

## Run77c fixes after owner testing

Run77b passed placement (103980 LUTs, 364 BRAM), and is retained while routing.
The newer MacPaint image requires 21144 words through the end of its name table,
but run77b stored only 20480. Its instruction body fit; truncated names caused
a startup fault. Run77c adds one 1024-word BRAM bank, for 21504 application
words, using the remaining tile. No program features are removed and clocks
are unchanged. Debug source-map bytes after the name table are not executed.

Run77c also latches initial Finder completion so subsequent Finder loads do not
show the startup overlay. SYSTEM.SYS and the fallback label now say “Welcome”.
Both changes are in the new frozen source; run77b does not contain them.

Note File Save passed a real disk test with CHKNOTE.TXT: saved bytes are exactly
`hi`, and the editor resumed. The owner's reported error is still under
investigation; an extensionless filename is being tested separately.

Run77c RTL acceptance passed current MacPaint FAT launch and a rendered frame
without fault. Note extensionless Save and Save using Return both passed;
the current console's extensionless default is .JS, and TESTNOTE.JS contains
exactly `hi`. No Note code change or unproven save-error fix is claimed.
Shared Toolbox disk test passed File/Open, Cancel, File/Quit and Finder return
with `BOOT intro=0 finished=1 glass=0` throughout return. Evidence lives in
`build/run77c_toolbox_fixes/bugcheck/` and `verify_disk.log`.

## Separate CopyBits source work (not run77c)

The coordinated architecture chat added raw 8-bit rectangle transport as native
operation 6, capability 65599, with new tbCopyBits/tbScreen wrappers. It owns
that current-checkout API/diagram work. Its reported verification: 30 Python
checks, real framebuffer standalone RTL, and full-core capture/restore passed.
Isolated service synthesis: 2219 LUTs, 15 DSPs, zero BRAM; estimated +0.115 ns
at 100 MHz. This is not whole-chip timing qualification. Evidence is under
`build/bitmap_copy_interface/`. It requires a later hardware build.

Run77c remains capability 65567 and uses its frozen ROM, clients, simulator and
Python runtime. Run `build/run77c_toolbox_fixes/test_gui.sh` for matched testing.
Do not rebuild its clients against the checkout's newer Toolbox ROM.

## Run77d: owner-requested complete CopyBits package

The owner requested inclusion of the new bitmap interface in the next bit,
so run77d is now the target. Frozen source is
`build/run77d_copybits_toolbox/source/`; native capability 65599 includes
operation 6. It retains the 21504-word application bank and boot-only Welcome
fixes. The resident ROM SHA256 is
`b62a499b5a7240467b1dd98f45579b50e0fd6a40670eb00948cc85d2402f5925`.

Vivado synthesis/implementation has started. A matched disk with all resident
clients relinked and COPYDEMO is being audited against that frozen source.
The simulator is isolated from both earlier builds and the working checkout.
No run77d bit is qualified or flashed yet. Run77b/c evidence is preserved.

Run77d matched-disk audit passes all 32 compiled programs and both resident
clients. Its full-machine CopyBits test verifies 8192 source/destination indexed
pixels, including a software-modified pixel. Shared menus/dialogs and MacPaint
launch/render/return pass without replaying Welcome. Routed qualification is
still pending; these are simulator results, not board acceptance.

Run77d Note File/Save with extensionless NSAVE also passes: the editor resumes,
no dialog error is reported, and the saved FAT file NSAVE.JS contains the exact
text `hi`. The earlier reported Disk error remains unreproduced.

The run77d alternate-ROM acceptance also passes: changed Toolbox software and
matching relinked clients boot and execute on the same unchanged RTL simulator
executable. This verifies software update flexibility within the existing
ABI and resident bank capacity. It does not make arbitrary RTL changes possible
without Vivado. See run77d/flexibility_acceptance.log.

## Run77e measured timing contingency

Run77b routed at -1.522ns on the existing menu parser text-byte→label-length
path. Run77d retains that parser. While D continues, run77e independently builds
a measured repair: predecoded control flags and old-state row/count selection.
Cycle-by-cycle comparison passes34564cycles; isolated estimated path improves
1.95ns at54LUT/5registers and no extraRAM. This is not board timing qualification.

E's only RTL/vector/constraint difference from D is jmr_classic_ui.sv;
source_comparison.json verifies the exact tested candidate. ROM and disk are
byte-identical, native CopyBits and JavaScript clocks unchanged. E full-machine
regressions and whole-board build are running. Neither D nor E is a qualified
release yet. The earlier B bit failed timing; C stopped at its preliminary
synthesis guard with a complete checkpoint.

## Run77f combines the two measured control-path repairs

B's second worst routed path was -1.509ns from the fast-clock Toolbox hash
to thousands of VM initialization/reset endpoints. F adds one VM-clock
identity-comparison register to E's parser repair. The existing header-read
sequence provides settling cycles before the comparison is consumed.
Actual side-by-side original/candidate VMs pass11valid/invalid/changed-ROM
load cases at3clock phases, including immediate START, with the same8header
beats and identical fault decisions. Native JavaScript game execution and
clocks are unchanged. See F/identity_evidence/.

Run77f builds independently from frozen sources; D and E are preserved and
continue. ROM/clients/disk are identical. Full-system F acceptance and routed
qualification remain pending. No candidate is yet timing-qualified.
