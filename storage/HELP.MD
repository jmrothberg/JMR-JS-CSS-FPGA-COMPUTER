# How to use this computer

You are reading HELP.MD, the manual for this
machine. It opens from Special, then Help.

The machine starts in Finder, the desktop. You
work with the mouse, the menu bar, and the keys.

- Double-click a program to run it.
- Double-click a document to read it.
- Esc closes a menu or a dialog. Otherwise it
  leaves the program and returns to Finder.

---

## The desktop

Disk is at the upper right. Trash is at the lower
right. Click Disk to open the Disk window. It
lists the programs and documents on the card.

The line under the title shows how much of the
disk is used and how much is available.

- Click an icon to select it.
- Hold Shift and click to select more.
- Drag in empty window space to select a group.
- The arrow keys move the selection.
- Type the first letters of a name to select it.
- Drag an icon to move it. It can sit in a
  window, in a folder, or on the desktop. It
  stays where you let go, and no other icon
  moves, not even when one goes to the Trash.

Each window has a close box at the left of its
title. Drag the title to move the window. Drag
the lower right corner to change its size. The
scroll bars at the right and bottom scroll it
when there is more to see. A white bar means
everything fits.

Finder menus are File, Edit, View, and Special.
Grey items do nothing: Print, Page Setup, Eject,
and Erase Disk.

## Run a program

Double-click it, or select it and choose File,
then Open.

To leave, press Esc or choose File, then Quit.
If the document has unsaved changes, you are
asked whether to save them first. With a menu
or a dialog open, Esc only closes it. In a game,
Esc leaves at once. Games also have Game, then
Restart, to start again. A game waits while a
menu or dialog is open.

If a program stops answering, press Esc three
times to leave it.

If a program crashes, Finder comes back with a
bomb and "Sorry, a system error occurred." The ID
number says what went wrong. If a program cannot
be opened, Finder says why. Click OK, or press
Return or Esc, to go on.

A program that has not been compiled opens in
the Editor instead. See Compile.

A .BAS program opens in TRS-80 BASIC, loaded
and READY: type RUN. A .WRT document opens in
MacWrite and a .PNT picture in MacPaint.

## Read a document

Double-click a .MD, .TXT, or .JS file, or a file
with no ending. It opens in the Reader. Special,
then Reader, lists the .MD, .TXT, .HTM, .JS, and
.BAS files to choose from in one list. Up, Down,
Page Up, Page Down, and the scroll bar move
through it.

- Up and Down move one line.
- Left, Right, F3, and F4 move one page.
- Click the upper half of the page to go back a
  page. Click the lower half to go on.
- File, then Open, reads another file.

The Reader does not change the file.
Double-clicking a file that no program reads,
such as a picture or an icon, shows an alert
instead.

## Names, folders, and Get Info

Select an icon and press Enter to rename it.
Type the name, then press Enter again, or press
Esc to keep the old name. A name is letters,
digits, and a dot, up to 12 characters.

File, then New Folder, makes a folder in the
front window. Double-click a folder to open its
window. Drag icons onto a folder to put them in.

File, then Duplicate, copies the selected file.
The copy is named COPY with the same ending.

File, then Get Info, shows the kind, size, place,
and date. Click the Locked box to lock the item.
A locked item cannot be renamed or put in the
Trash. Type to write a short comment. Esc closes
the window.

Edit, then Undo, takes back the last move,
rename, new folder, or trip to the Trash.

## View

View applies to the front window: by Icon, by
Small Icon, by Name, by Size, by Kind, by Date.

Hidden files also shows the compiled programs,
picture files, and icons. Choose it again to
hide them.

Special, then Clean Up, puts the icons in the
front window on the grid, each in its nearest
place or, if that is taken, the first free one.
With no window open it lines up the desktop.

## Trash

Drag an icon onto Trash, or select it and choose
Edit, then Clear. It is not deleted yet.

Click Trash to see what it holds. To get an item
back, select it and choose File, then Put Back,
or drag it onto Disk.

Special, then Empty Trash, asks first. OK, or
Return, deletes the files for good; Cancel, or
Esc, keeps them. Locked items stay.

## The Editor

In Finder, Special, then Editor, opens the
selected .HTM, .MD, or .TXT file. With nothing
like that selected, it opens a new untitled
document. File, then Open, picks another file.

- Arrows move. Typing inserts.
- Enter starts a new line. Backspace deletes.
- F3 and F4 move a page.
- Click to place the cursor. Drag to select.
- F2 saves.

File has New, Open, Save, Save As, and Quit.
Save As asks for a name and asks again before it
replaces a file. A name has up to 8 letters or
digits, then an optional dot and up to 3 more.
The box takes no 9th character before the dot.
A name it cannot use comes back with the rule,
so you can fix it. With no ending typed, the
name gets .TXT.

New, Open, and Quit ask about unsaved changes:
Save, Discard, or Cancel.

Edit has Undo, Cut, Copy, Paste, Clear, and
Select All. Ctrl with Z, X, C, V, and A does the
same. Cut and Copy hold up to 4096 characters.
Undo takes back one change.

A document can be up to 65536 characters.

The window's title is the document's name, or
untitled until it has one.

Save As a new name for a program (.HTM or .JS)
also copies its icon (NAME.ICN) and sprite art
(NAME.ART) to the new name, so the new program
gets the same icon and its sprites after you
compile it. Files the new name already has are
kept.

## Note

Special, then Note, opens the Editor on a new,
empty document, titled untitled. Save asks for
a name. With no ending typed, the name gets .TXT.

## Compile

A program is an HTML file. The machine runs the
compiled copy, NAME.JSH. Compile after you
change the HTML.

In Finder, select the program and choose
Special, then Compile. With nothing selected,
Special, then Compile, opens the Compile window:
File, then Open..., picks a program and
compiles it. Compiling takes several minutes.
A window shows the program's name, the step (1
to 4), and a bar; Esc cancels. Finder comes back
when it is done; double-click the program to run
it.

Compiling again replaces the old NAME.JSH. The
new one is written under another name first and
takes the old one's place only when it is
complete, so a failed compile keeps the old
program. A program with sprites needs its
NAME.ART on the card.

The HTML can be up to 65,536 bytes. The compiled
program can be up to 29,696 words of code,
constants and names, besides the Toolbox.

## Utility

Special, then Utility, lists every file on the
card with its size in bytes, and counts them.
Up and Down, or W and S, scroll the list.
Show picks one file type, such as .HTM or .MD;
All Files lists everything again. A check marks
the current choice.

## Icon Editor

Double-click ICONEDIT. Click a name on the left
to open an icon: a .ICN file, or the System bomb
and caution alert icons. A program with no icon
yet is listed too, as NAME.ICN; it starts as the
generic icon and Save creates it. Click or drag in the big
grid to paint; clicking a pixel that already has
the colour erases it. Pick a colour on the right.
Edit has Undo, Fill All, Clear and Invert. File,
then Save, writes the icon. A System icon is saved
into SYSTEM.SYS and shows after a restart.

## Graphics and Toolbox Demo

GRAPHICS runs every Toolbox drawing operation
once on a full screen and shows PASS or FAIL.
Esc leaves it.

TBDEMO is the Toolbox Tour. Dialogs opens each
kind of dialog. Draw fills a pattern, copies it
with Copy Bits, scrolls the copy, and Show Grid
puts a check by itself. Drag the box with the
mouse or move it with the arrow keys.

## Restart

Special, then Restart, reloads Finder.

## MacPaint

Double-click MacPaint. The window says untitled
until the picture is saved or opened; then it
shows the picture's name.

The mouse draws. The arrow keys move a pen, and
Space draws with the current tool. The hand
moves the page. Shift keeps lines straight and
boxes square.

The menus are File, Edit, Goodies, Font,
FontSize, and Style. File, then Save As, asks
for a name and writes NAME.PNT; Save on an
untitled picture asks too. File, then Open,
loads a picture back, and so does
double-clicking a .PNT file in Finder. Revert
reloads the saved picture.

Edit, then Undo, or Z, takes back the last
operation; choose it again to redo. Goodies,
then Brush Shape, picks one of 12 brushes;
Brush Mirrors paints a mirror copy across the
page. Goodies, then Short Cuts, lists the keys.

Double-click a tool: pencil for FatBits, eraser
erases the window, hand shows the whole page,
selection selects the window, brush picks a
shape.

Quit does not ask. Save before you leave.

## MacWrite

Double-click MacWrite and type. Words wrap at
the right margin; Return ends a paragraph.
Click to place the insertion point. Drag or
Shift-click to select; double-click a word.
The arrow keys move and Delete erases.

The ruler at the top sets the paragraphs under
it. Drag the margin triangles and the indent
mark. Drag a tab from the box at the left onto
the ruler; drag it off to remove it. Click the
spacing and alignment boxes. Format, then
Insert Ruler, gives a paragraph its own ruler.
Show Rulers hides and shows them.

Style sets bold, italic, underline, outline,
shadow, superscript, subscript, and the size.
Font has Chicago (12, 24, 48 point) and Monaco
(9, 18, 36); picking a size picks its font.
With nothing selected, the style is for what
you type next.

Edit has Undo (choose it again to redo), Cut,
Copy, Paste, Clear, and Show Clipboard.
Search, then Find or Change, opens a box at the
bottom of the window. Tab moves between its
fields; Return finds the next match. Ctrl with
Z, X, C, V, A, B, I, U, F, or S is a short cut.

File, then Save As, writes NAME.WRT. A name
ending in .TXT is saved as plain text. Open
lists .WRT and .TXT files. Double-click a .WRT
file in Finder to open it. Esc or Quit asks to
save a changed document.

Not in this MacWrite: headers, footers, the
title page, page breaks, printing, and fonts
other than Chicago and Monaco.

## Pictures

A program's pictures live in a second file, so
the HTML stays small enough to edit. NAME.ART
is the one this computer uses; keep it with its
program. It is hidden until View, then Hidden
files. It is not written by hand.

## The ship menu and the keyboard

The ship at the left of the menu bar is always
there, over any program. Its menu has About and
Keyboard.

About shows the name of the program and one line
about it. Finder's About also shows the
Enterprise and the build the card was made for,
such as Build 99 and the date. If it names a
different build than the loaded bitstream, make
a new card.

Keyboard shows a keyboard on the screen. Click
its keys with the mouse. Check the Hold keys box
and a clicked key stays down. Use that for game
controls.

## TRS-80 BASIC

TRS-80 BASIC is the Level II BASIC of a 1978
TRS-80 Model I, in a green 64 by 16 window.
Type a line and press Return. A line that starts
with a number goes into the program; any other
line runs at once.

- RUN runs the program, LIST shows it, NEW
  clears it.
- SAVE "NAME" writes NAME.BAS. LOAD "NAME" reads
  it back. KILL "NAME" deletes it. DIR lists the
  .BAS and .DAT files.
- BREAK stops a program: F1 or the Pause key.
  CONT carries on.
- Esc leaves TRS-80 BASIC.

Double-click a .BAS file in Finder, or select it
and choose File, then Open: TRS-80 BASIC starts
with that program loaded.

A program reads the cassette with INPUT#-1. Here
the cassette is a file on the card: type
TAPE "ADV01.DAT", or choose Tape, then Open...

Programs to try: STARTREK, GUESS, SINE, PRIMES
and BENCH. For the Scott Adams adventures,
double-click SCOTTADV, type RUN, then type a
number from the list: 1 Adventureland,
2 Pirate Adventure, 3 Mission Impossible,
4 Voodoo Castle, 5 The Count.
