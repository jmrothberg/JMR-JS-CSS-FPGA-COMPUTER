# Writing an application

Menus, windows, dialogs, and files, for the
programmer. The user manual is HELP.MD.

Every program is an HTML file on the card,
compiled to native JavaScript. The resident
Toolbox draws the menu bar, windows, and
dialogs. A program does not draw them itself.

Examples on the card: MENUEX (a menu command),
GUIDEX (a windowed tool), UISESS (owned File
menu, Open, Save As), UIMAN (manual UI calls),
EDITOR and NOTE (the SOURCE document).

---

## Smallest program

The first line of the file is the comment
jmr-toolbox: resident-v2. Then, in the script:

- tbSessionProperty(ctx,2,"Title|One line")
- tbSessionProperty(ctx,0,6)
- tbSessionMenus(ctx,"Example|Add One=160")
- tbSessionListen("keydown",fn)
- tbSessionFrame(frame), and again inside frame
- tbSessionProgram("MYGAME.HTM")

A chosen menu item arrives at the keydown
listener as keyCode 160.

Use the session calls (tbSession...) or the
manual calls (tbUIInit, tbMenus, ...), never
both. The session owns addEventListener and
requestAnimationFrame.

## Session calls

- tbSessionProperty(ctx,field,value)
- tbSessionMenus(ctx,spec): one string, or an
  array of strings with one menu each
- tbSessionListen(type,fn): keydown, keyup,
  mousedown, mousemove, mouseup
- tbSessionFrame(fn): run fn next frame, once
- tbSessionInvalidate(fn): fn only redraws
- tbSessionTransform(a,b,c,d,e,f): setTransform
  that keeps the viewport or window origin
- tbSessionProgram(name): own 8.3 card name.
  Enables Game, then Restart
- tbSessionSuffix(ext): file type, such as PNT.
  Filters Open and is the Save As default
- tbSessionCodes(text): string literal, up to
  128 bytes, to the byte array dialogs take

## Properties

- 0: role. Setting it starts the session
- 1: 1 = game viewport (role 8 only)
- 2: "Title|About line", up to 100 bytes
- 4: window title, overrides field 2
- 5: enable mask for commands 160-191
- 6: check-mark mask for commands 160-191
- 7, 8: vertical, horizontal scroll, 0-255
- 9: document flags for roles 1 and 5:
  1 modified, 2 undo, 4 clipboard, 8 selection

Bit n of a mask is command 160+n. There is no
field 3.

## Roles

- 1 Editor: New, Open..., Save, Save As..., Quit
- 2 Reader: Open..., Quit
- 4 Utility: Quit
- 5 Note: as role 1
- 6 any other windowed program: Quit
- 8 game, full screen, menu bar only: Quit
- 9 Finder: no frame, owns its whole bar

Windowed roles draw only in x 24-599, y 88-431.
Callbacks run clipped to that area, and mouse
coordinates use the same numbers.

A game draws 640 by 480. The menu bar covers
rows 0-21. Lay the game out below row 24, or set
field 1 to 1 to have drawing scaled into rows
24-479. Not both. A game that calls setTransform
uses tbSessionTransform instead.

## Menus

Example: "Game|New Game=160|Pause=161;Level|
Easy=162|Hard=163", written as one string.

A semicolon separates menus. A bar separates the
heading and the items. An equals sign gives the
command number. An item that is only - is a
separator. The whole text is at most 800 bytes,
each string literal at most 255.

- No tbSessionMenus call: the role's File menu,
  Edit for roles 1 and 5, Game for role 8, then
  Special.
- First heading is not File: the role's File
  menu, your menus, then Special.
- First heading is File: exactly your menus.

Special holds Editor, Reader, Compile, Utility,
Note, Help, and Finder.

## Commands

- 160-191: delivered to the program
- Label Quit or Close, 1006, 255 (close box):
  return to Finder. Roles 1 and 5 ask first
- Label Open...: file list, name written at
  arena 96-111, then the command is delivered
- Label Save As...: name box, replace check,
  name at 96-111, then delivered. Needs
  filename_client.js
- 1001 New, 1002 Open, 1004 Save, 1005 Save As:
  documents of roles 1 and 5
- 137-142: Undo, Cut, Copy, Paste, Clear,
  Select All, delivered to the program
- 1007: Restart
- 1010-1016: Editor, Reader, Compile, Utility,
  Note, Help, Finder

Open... and Save As... only choose a name. The
program reads and writes with fsRead and fsWrite.

## Keys the system owns

- Esc: returns to Finder. Do not bind it
- 254: About, sent by the ship menu
- 113 (F2) with no character: Save, roles 1, 5
- 128, 129: scroll one line up, down
- 130, 131: scroll one page up, down
- 132, 133: scroll left, right

While a menu or dialog is open the program gets
no input. With an invalidate callback its frames
are held and the callback repaints.

## Dialogs (manual UI)

tbDialogOpen(kind,prompt,rows,value), then poll
tbDialogResult(). Return accepts.

- 1: message with OK. Result 1
- 2: OK, Cancel. Results 1, 2
- 3: name field, Save, Cancel. Results 1, 2.
  tbDialogValue() is the name
- 4: list, Open, Cancel. Results 1, 2.
  tbDialogSelection() is the row
- 5: Save, Discard, Cancel. Results 1, 2, 3
- 6: Replace, Cancel. Results 1, 2

UIMAN.HTM uses every manual call. Call tbUIDraw
last, after the content.

## Files and SOURCE

Names are 8.3, NUL-terminated, in the arena. The
card is one flat directory.

- fsList(dst,capacity,start): catalog page
- fsRead(name,offset,dst,n): bytes read, or -1
- fsWrite(name,src,n,mode): 0 replace, 1 append
- fsRemove(name), fsRename(old,new): 0, or -1
- sysRun(name,how): 0 run, 1 edit, 2 read,
  3 compile, 8 return to Finder
- srcLen(), srcByte(i), srcWrite(i,b),
  srcSetLen(n): SOURCE, at most 65536 bytes
- strByte(s,i): byte of a string literal, or -1

SOURCE is one shared buffer. Loading a document
replaces it.

## Reserved arena bytes

A session program leaves these alone. The arena
is not cleared between programs.

- 32-52: Editor resume header
- 64-65: program chain and save flag
- 96-111: file name passed to sysRun
- 208-211: pending action across a save
- 380320-380927: session catalog, descriptor,
  and glyph scratch
