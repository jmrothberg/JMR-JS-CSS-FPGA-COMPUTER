# Toolbox software revision and hardware status

5 November 2026. **44 programs, 42 resident clients; library 8191/8191 mutable
instructions, zero spare.** This status describes the matched software revision.
Its chosen release manifest and card receipt establish publication and delivery;
a prepared image or passing model check alone does not establish either.

The one active set is **run80 RTL + root `storage/` +
`card_toolbox_examples_working.img` + the run80 `.bit` once qualified**.
The working disk has 161 files: 159 managed files and two preserved files.
Run80's bitstream is pending; the older hardware evidence below is rollback
history, not a second current release.

## Matching software identity

Frozen promotion manifest: `build/toolbox_usage_examples/revision/promotion.json`.
Final host audit: `build/toolbox_usage_examples/revision/final_audit.json`.

- Disk SHA-256: `9c7e042b86f8bdc8d27e4fda669a6ba6f02d9c4a82a3c438704571c7ec6a4381`.
- `TOOLBOX.ROM`: `f6f805c579a93a76d902cd027f420eb2e7e0b9969e2b44bf26771fca0b32e390`; fingerprint `e8e89e1b`.
- `TOOLBOX.LNK`: `0804ff9633f6b0598a375300306fa3b2dc378ce5dc82e9c9f2b580bae6381e8c`.
- GRAPHICS, DAMAGE, UIMAN and UISESS add four runnable examples to the preserved
  original/CB application set. There are 44 programs, 42 resident clients and
  eight CB variants. The final disk has 159 files; four unused internal authoring
  HTMs are excluded while their executable programs remain. SD capacity stays
  64 MiB; the machine aperture stays 8 MiB.
- The `tbPaintRect` destination-size correction adds seven instructions to the
  earlier 8184-word library. All 8191 mutable words are used; the fixed final
  jump is separate. A further library addition needs replacement/compaction or
  a hardware bank change. App-only code still has its own 21504-word capacity.
- Relink every resident client with this exact ROM/LNK, publish source/JSH and
  resources together, and cold-restart. Finder/Game Restart does not reload ROM.

Host compilation, capacity and resident-prefix identity passed for all 44 programs.
GRAPHICS passed actual full-core RTL helper-return and pixel checks, and all 8192
cold-loaded Toolbox words matched. Its scaled circle center is 118 in RTL versus
119 in the float model because 0.95 is 62259/65536 in 16.16 arithmetic. The 34 raw
pixel differences are explicitly accounted by that one-row shift; other gallery
cases match directly, and all 46,000 compared pixels match after that correction.
This is documented numeric behavior, not a zero-tolerance model-parity claim.

DAMAGE passed 13 scripted native-instruction-model reference frames covering
movement, overlap, deletion, labels, transparent-background edits, scaled bounds
and one-pixel marks. UIMAN/UISESS passed bounded model checks. They have not been
relabeled as actual full-core RTL tests. The final disk omits four internal HTMs
and expands DAMAGE's conservative bounds relative to the RTL gallery input disk;
GRAPHICS, ROM and LNK remain identical to the RTL-tested bytes. No broad game
retests or physical display/input acceptance are claimed for this new library.
Earlier b022 nine-game RTL checks remain evidence for that earlier software.

Evidence: `revision/rtl_gallery/evidence.json`, `revision/final_audit.json`,
`damage_checks.json`, `ui_model_checks_fixed.json` and `helper_fix/result.json`
under `build/toolbox_usage_examples/`. Publication/card readback is separate.

## Hardware and factory-memory evidence

Run78 remains the **strict timing-qualified baseline**: setup 0.000 ns, hold +0.027 ns,
96,097 LUTs, 364.5 BRAM tiles and 28,545 slices. Its bit SHA-256 remains
`24e0c0c25ba19030f492e5ea6a98f769519defc2c654c11fa3fa1af518b4b6d5`.

Run79 includes the Editor halt/acknowledgment correction. Actual full-core RTL
Finder → Editor → Finder checks pass, but the selected bit is **TEST**, with
setup −0.195 ns and hold +0.029 ns. It is not strictly timing-qualified. Its selected
checkpoint SHA-256 is
`7a89f2abefa0c3ae5f118fc9a2894a7d58a39b569d814f0a2c997c4605bd6521`.
Fresh actual INIT/INITP, physical tail and read/address-selector audit passed:
`build/run79_handoff_fix/init_audit/selected_pass1/result.json`. It verifies
factory ROM fd89c8…/identity d03c62a7, not the newer disk-loaded ROM, and does not
claim whole-netlist formal equivalence.

Run80 includes the pointer snapshot correction plus Editor handoff and is still
building. The sporadic large mouse jumps remain an active regression. Reproducing
a lost-report mechanism does not prove the physical root cause or acceptance.
Do not mark the pointer fixed from idle simulation alone. No agent flashing is
part of these software/documentation changes.

## Earlier release evidence

The following 40-program/b022 records are preserved history, not identities or
acceptance claims for the new 44-program software or run79/run80 hardware.

## Earlier 40-program run78 software release (historical)

5 November 2026. **Hardware strictly qualified; corrected software delivered;
physical user testing pending.** The main `storage/`, corrected disk and updated
physical card have matching Toolbox and applications. [Architecture](lastrun_ARCHITECTURE.md).

### Unchanged qualified hardware and factory evidence

Bit: `build/run78_clean_architecture/qualification_refined/run78_clean_qualified.bit`.
SHA-256: `24e0c0c25ba19030f492e5ea6a98f769519defc2c654c11fa3fa1af518b4b6d5`.
Selected checkpoint `refinement/pass_1.dcp`:
`688d044f989060fc8c866ecd2fc326ba2497dde2939c84580410c7a8ffbbb834`.

Setup **0.000 ns**, hold **+0.027 ns**; complete route, clock/pulse, DRC, input
pins, removed-controller and framebuffer-mode gates passed. Resources: 96,097
LUTs, 364.5 BRAM tiles, 28,545 slices. Clocks stay 33.333/100 MHz; memory stays 8 MiB.

The preserved `init_audit/routed_refined_pass1/result.json` audits actual
INIT/INITP and selected mux/address truth tables against **factory ROM**
`fd89c8bea5133c487d16606ded646083c0edf2afb15aca17a9b473cd6fe6ab1e`,
fingerprint `d03c62a7`. It does not claim whole-netlist formal equivalence.
This audit is intentionally unchanged and does not claim to contain the new disk ROM.

### Delivered matching software

Package: `build/run78_clean_architecture/final_corrected/README.md`.

- Base disk `final_corrected/card.img`: `8d21dd6616b1ec57841a27d2826926c0ab3e7c377203593807365e01ae1eae0c`.
- `TOOLBOX.ROM`: `b0222c546f2e0f337a4f6f8b69e77391cd9a8590052a239da0c69535e955046e`; instruction fingerprint **`3ee8511b`**.
- `TOOLBOX.LNK`: `7fd4cb450ce12fa8a7b223665d95c7d2b3fcf238e0eef41c4d279b81ee38a072`.
- **8184 of 8191 mutable instruction words, seven spare**; final word remains
  the fixed jump. Future additions may need software compaction; a larger
  configured bank requires a new bit.
- **40 programs, 38 resident clients**, including all eight CB variants. Original
  game counterparts remain on the disk while the user tests the CB versions.
- Disk builder default: **64 MiB**, so the complete assets fit. This is SD
  capacity, not an expansion of the machine's 8 MiB memory aperture.

Boot validates JMRT v2 and loads the newer disk code into the existing bank.
Its identity intentionally differs from the factory INIT. Missing/invalid ROM
leaves the older factory bank; clients linked to the newer ROM must reject that
identity. Factory-memory audits and later software validation are separate.

The build owner applied 51 exact-hash changes to the main working source.
The physical card received 80 file writes; all **153 files verified**, with
user files and card geometry preserved, then the card was safely unmounted.
`card_menu_working.img` contains that preserved working set. The base disk and
working disk differ intentionally by user files. The original main `card.img`
was preserved and is not the new matching disk.

### Corrections and bounded verification

Finder RGB332 white is index 255; title-palette white is index 1. Shared UI
now uses the correct palette mode. Active menu titles and enabled hovered rows
draw inverse text. Disabled labels are stippled and cannot highlight or activate;
a disabled checked item retains a black marker. This is not identical Macintosh styling.
Selected Finder names use white SYS glyphs on black. About key 254 is handled
by application software. Focused checks retain reverse selection after About
closes and after cached Finder return.

Earlier Editor NEXT software removed five session listeners and scheduled no
new frame before `cdone(128,…)`. This model-level result was insufficient in
actual run78 RTL; the console halt/acknowledgment fix described above is required.
The bounded native-instruction proof preserves SOURCE on Editor launch and
clears it only for explicit New. The previous failing full-core check reached
role 1 while Finder code was still running; it was a handoff failure, not proof
of an Editor menu crash.

Final checks cover compilation/capacity, all matching resident prefixes and
exact file identities. The final 40-program software did **not** rerun broad
full-core suites; physical display, input, all application paths and CB behavior
remain for user testing. Earlier full-core/readback results describe earlier
software identities and must not be relabeled as evidence for this final ROM.

Evidence: `final_corrected/result.json`, `ui_asset_fix/result.json`,
`ui_asset_fix/cb_visibility.json`, `chain_stop_fix/stop_result.json`, root-promotion
and physical-card receipts. The GUI Finder-return adapter remains the previously
checked implementation. Chess keeps its tested 5% vertical viewport compression.
Cache remains 192 KiB with 32 KiB taken from artwork; SYS/frame/SOURCE stay fixed.
No whole-system speedup or complete physical acceptance is claimed.


## Historical implementation log

The preserved notes below describe earlier builds and their then-current limits.
Use the delivered status above for run78; these entries are not current release claims.

---

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

## Run77g: measured CopyBits timing repair (2026-11-04)

F routed at WNS -2.588 ns / WHS +0.050 ns, outside release and TEST limits.
Its actual routed Toolbox INIT/INITP audit passed. Physical refinement is active.
The worst F path is the CopyBits overlap-direction calculation. G stages its
products, start sums and comparison across three existing setup states, with
no added execution cycles or pixel-path changes. Original/candidate comparison
passed 487177 cycles including 515 signed-edge cases. Isolated reverse-path
delay fell from 9.023 to 3.290 ns, at +168 LUTs and unchanged DSP/BRAM.
These are module estimates, not whole-board timing claims. G synthesis is
active, isolated full-core simulator built, disk audit passed; application
acceptance and board qualification remain pending. G source differs from F
only in rtl/engines/jmr_toolbox.sv. Root RTL and working bits are preserved.

## Run77h: cycle-equivalent memory-owner control (2026-11-05)

H is frozen G plus an independent registered Toolbox busy flag. Its state
machine, handshakes and execution cycles remain unchanged. Isolated comparison
passed 489993 cycles,515 edge cases and reset/abort/drain/held-request cases.
Full-core menu launch, MacPaint return, bare-name Note save and all 8192 CopyBits
pixels pass. A changed valid ROM plus relinked clients boots on the same
simulator binary. Exact32-program disk audit passes. See H/functional_acceptance.json.
H synthesis/implementation and G routing remain active; hardware is unqualified.
E physical refinement plateaued at -0.562/+0.050; repeated and pin-routing passes
made no further progress. F remains -2.588; D timed out. All old bits preserved.
