# Two ways to own Toolbox UI

Use **one** of these ownership patterns per application. `UIMAN` owns raw
`requestAnimationFrame` and forwards input to the manual UI. `UISESS` lets the
session own input routing, menus/dialogs, and the raw frame callback. Combining
both patterns duplicates drawing and event delivery.

Run these examples on a **private copy** of the matched demo disk. Their linked
JSH files require the exact matching Toolbox ROM/link manifest. Copy each HTML
to its 8.3 name (`UIMAN.HTM`, `UISESS.HTM`) with its matching JSH. Do not compile
against a different ROM or substitute an old binary by filename alone.

## Manual UI: UIMAN

Open the Demo menu. Message shows an alert; Confirm accepts or cancels; Edit name
returns an ASCII array; Choose row returns a zero-based index. Save choices has
Save/Discard/Cancel; Replace prompt has accept/cancel. Toggle check visibly marks
its menu item. Guarded action starts disabled and must not run until Enable
action enables it. Closing the example reports the request without exiting.

The example uses all 17 public manual UI calls:

- `tbUIInit(ctx, descriptor, glyphScratch, titleCodes)` initializes resources and
  returns success. Descriptor 20000..20063 and glyph scratch 21000..21031 belong
  exclusively to this example. Initialization failure displays an error.
- `tbWindow`, `tbMenus`, `tbMenuEnabled`, `tbMenuChecked` define the window and
  menu model. Menu rows are `[ASCIIlabel, command, enabled, checked]`. An empty
  label is a separator. Command 255 means close requested.
- `tbText`, `tbTextWidth`, `tbBox` draw content. Labels are ASCII byte arrays;
  `strByte` reads interned ASCII literals, not general UTF-16 strings.
- `tbDialogOpen` supports kinds 1 alert, 2 confirm, 3 name, 4 list,
  5 Save/Discard/Cancel, 6 replacement confirmation. `tbDialogValue` and
  `tbDialogSelection` retrieve accepted data. No disk operation is implied.
- `tbUIKey` and `tbUIPointer` receive input; true means consumed. Pointer buttons
  are 1 while primary is held, 0 when released. Always forward release events.
- `tbMenuCommand`, `tbDialogResult`, `tbUIChanged` consume their pending value.
  Poll each once and keep the result. Ordinary dialog results are 1 accept,
  2 cancel; kind 5 uses 1 Save, 2 Discard, 3 Cancel. Zero means nothing pending.
- `tbUIDraw` draws UI last, after content, so closing overlays reveals clean
  application pixels. Do not overwrite glyph scratch behind the UI cache.

## Session and document bytes: UISESS

Choose **File → New sample**, then **Save As...**, enter `UITEST`, and accept.
The suffix policy produces `UITEST.TXT`. Choosing an existing name asks before
replacement. Cancel produces no file operation. Open... lists TXT files; choose
UITEST.TXT to read the exact sample back into SOURCE. The example intentionally
accepts only files shorter than 128 bytes and reports read/write errors instead
of claiming success. This is a small byte-document client, not an editor.

**SOURCE is shared machine memory. New sample and successful Open replace it.**
Use only a disposable simulator session/private disk, with no unsaved document.
No document is modified until those explicit commands; Save As writes only the
chosen filename after acceptance. This demonstration uses public raw SOURCE
services (`sysDocument`, `srcWrite`, `srcSetLen`, `srcByte`, `srcLen`) plus
`fsRead`/`fsWrite`. The session provides name/open/replacement dialogs; the client
owns byte serialization. Reserved Editor/Note lifecycle commands are not a
shortcut for saving an arbitrary application's private format.

Move/click in the content area and press/release keys to see the five event
counters. Menu and dialog input is consumed by the session. Mark toggles a check;
Disabled cannot run. The example has exactly one `tbSessionFrame(frame)` chain,
no raw RAF or manual input pump. `tbSessionInvalidate(draw)` restores exposed
content before UI overlays; avoid painting from a second loop.

Public session calls demonstrated: `tbSessionProperty`, `tbSessionMenus`,
`tbSessionListen`, `tbSessionFrame`, `tbSessionTransform`, `tbSessionCodes`,
`tbSessionProgram`, `tbSessionSuffix`, `tbSessionInvalidate`.

Property fields are 0 role, 1 viewport, 2 `Title|About text`, 4 title,
5 enabled-mask, 6 checked-mask, 7 vertical scroll indicator, 8 horizontal
indicator, 9 document flags. There is no field 3 contract. Mask bit0 controls
command160, bit31 command191; other command numbers do not use these masks.
For Editor/Note, field9 bits1/2/4/8 mean dirty/undo/clipboard/selection and drive
standard edit items. This utility-role example uses its own serialization.
Role4 provides a window without claiming Editor continuation semantics.
Role8's viewport scales Y by0.95 and offsets it24 pixels; damage bounds must
cover actual primitive output (see the graphics damage example).

A menu specification starting with `File|` owns its whole menu bar; otherwise
the session adds default File/Special menus. `Open...` and `Save As...` labels
select session picker behavior, forwarding the custom command only after
acceptance. Session owns Quit. Register five supported event types through
`tbSessionListen`: keydown, keyup, mousedown, mousemove, mouseup.

Use a distinct application context name such as `demoCtx`. The current native
compiler can inline parameter bindings from small helpers; a generic global
named `c` collides with the `c` argument of `tbSessionTransform`. These examples
avoid that existing compiler limitation rather than claiming it fixed.

## Internal plumbing is not another application API

`tbSessionDefaults`, `Equals`, `Parse`, `Bit`, `Masks`, `SendKey`, `U32`,
`Command`, and `DialogResult` are session plumbing. Exported names do not make
them extra calls every app must issue. The session handles command routing and
dialog results. `_tb*` variables and underscore helpers are private state.
Manual UI callers use the manual polling API; session callers should not also
consume those queues. Editor continuation scratch/`cdone` belongs to the
existing Editor integration; use NOTE/EDITOR as its reference, not copied magic
numbers in ordinary apps.

## What was checked

Both examples pass native compile capacity limits. Manual UI has static coverage
of all17 public calls and a bounded native-model test for disabled/enabled menu
selection, check mutation, kinds1–6, list selection, name editing, cancellation,
and consuming result polls. The session's real model frame pump accepts Save As
and verifies exact28 saved SOURCE bytes in temporary storage. Event counters,
Open navigation, error displays and physical input remain interactive checks;
those are not claimed RTL/board tested. `ui_compile.json` and
`ui_model_checks.json` record evidence. No game benchmarks or broad suites ran.
