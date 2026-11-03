# How to use this computer

You are reading HELP.MD. This is the manual
for the machine. Headings are large. Lists are
indented. The file itself is not changed.

- LOAD "HELP.MD"
- READ

Up and Down move one line. Left, Right, F3, and F4
move one page. Esc returns to READY.

On the desktop, select HELP.MD and choose File,
then Read. Other .MD and .TXT files open the same
way. At the prompt, LOAD "NAME.MD", then READ.

If READ prints ?SN, this bitstream is older than
the reader. The file is still loaded. Type LIST.
Space or Enter shows the next page. Esc stops.

---

## The desktop

The Enterprise ship menu has About and Keyboard.
It stays available over programs. To quit any
game, choose File, then Quit. Simpler games have
Game, then Restart to start again.

About says JMR Enterprises, the game title and
one line describing it. Finder and system tools
have their own About descriptions.

The keyboard's Hold keys box holds game controls.
Click a key again, hide the keyboard, or quit to
release it. Programs have no red X at the top right.

Terminal is in Special. Edit source is in Edit.
That Edit command is the EDIT verb below.

A document window shows any .MD or .TXT file.
Click the scroll arrows for one line. Click the
upper or lower part of the page for one page.
The small square at the left of the title closes
the window.

View, then Hidden files, shows the picture files
and icons that ordinary DIR hides. Choose it
again to hide them.

## DIR and DIR *

DIR lists what you can LOAD: HTML programs and MD
documents. It shows 14 names, then -- MORE --.
Space or Enter continues. Esc stops.

On the Python simulator, READY replaces
-- MORE -- and the first name stays. The run73o
board scrolls that top name off and leaves
-- MORE -- on the glass. The next bitstream
matches the simulator.

DIR hides compiled JSH files, picture files, and
the machine programs READ, EDITOR, ARTSCAN, and
COMPILER. Those files stay on the card. READ,
EDIT, and COMPILE need them. Do not REMOVE them.

DIR * also lists the JSH and picture files. The
machine programs stay hidden. A numbered LOAD
follows bare DIR, not DIR *.

## Play a program

- LOAD "NAME.HTML"
- RUN

LOAD reads the HTML and remembers the name.
Nothing starts yet. RUN plays NAME.JSH, the
compiled program stored next to the HTML.
RUN does not compile. A missing JSH prints ?NH.

If you did not change the HTML, LOAD and RUN
are enough.

## Pictures: ARTX and ARTJS

The HTML is the program. Its pictures live in a
second file, so the HTML stays small enough to
edit.

ARTX is the picture file this computer runs.
The card only allows three letters after the
dot, so NAME.ARTX is stored as NAME.ART. DIR
hides it. DIR * shows NAME.ART. COMPILE and RUN
read that file and put the pictures into the
program.

ARTJS is the same pictures for Chrome on the
PC. Open the HTML in the browser and Chrome
loads NAME.ARTJS. This computer does not run
that script. A copy is kept on the card so
Hidden files can show it. DIR hides that copy.

One file cannot serve both. This computer needs
a packed picture bank. Chrome needs a script it
can load. Both are built from the same PNG
sheets, so the pictures match. You do not write
ARTX or ARTJS by hand.

## The editor

EDIT is a verb. It runs the editor program,
EDITOR, on the file LOAD already parked. Do not
LOAD "EDITOR.HTML" and RUN it. That would put
the editor's own text in the buffer, and it
would edit itself.

- LOAD "NAME.HTML"
- EDIT

Arrows move. Typing inserts. Letters come out as
capitals, because this editor stores key codes.
Enter starts a new line. Backspace deletes.
F3 and F4 move a page.

F2 saves that same file and returns to READY.
Then type COMPILE, then RUN.

F5 leaves without saving. Esc is BREAK. It
leaves, and it does not save.

EDIT with nothing loaded prints ?NB.

NOTE is not this editor. NOTE is a separate
typing program. It is described under A new
program.

## Compile

COMPILE builds a new NAME.JSH from the HTML that
LOAD parked. Do not type a filename. LOAD already
chose the name.

Success prints COMPILED. The program is still
stopped. Type RUN to play the new file.

A failed compile prints ?CE and a line message.
The previous JSH stays, so RUN still plays the
old program. REMOVE "NAME.JSH" deletes that old
file when you want it gone.

COMPILE with nothing loaded prints ?NB.
COMPILE when the compiler programs are missing
prints ?NH.

Compile after you change the HTML on this
machine.

## A new program

NEW only clears the text window. It does not
open a blank page. EDIT after NEW prints ?NB.
Numbered lines at READY print ?SN.

Copy a program that is already on the card,
then edit the copy. The name fits in eight
characters plus .HTM.

- LOAD "BOXES.HTML"
- SAVE "MYGAME.HTM"
- EDIT

F2 saves MYGAME.HTM. COMPILE, then RUN, play
that new name. BOXES.HTML stays as it was.

NOTE.HTML is only an easier page for typing.
It is not the EDIT verb.

- LOAD "NOTE.HTML"
- RUN

Letters are lowercase. Hold Shift for capitals.
Enter starts a new line. Backspace deletes.
Tab inserts two spaces. F1 lists the keys.
F3 and F4 move a page.

In Python and FPGA-SIM, choose File, then Save.
A new note asks for a short disk filename.
Save and Save As keep the note open. F2 also
saves. Close asks about unsaved changes.

These menus need the new mouse/desktop bit on
the board; the preserved run73o uses its older
keyboard interface.

## Send a file from the PC

You do not rebuild the whole card to add one file.
In the PC window, at READY, press F8.

F8 asks where the file is.

- Host file picks a file on the PC. It is copied
  onto the PC card image. If the window says
  BOARD, that same file is also written to the
  card in the slot.
- card.img picks a file already on the PC card
  image and writes it to the card in the slot.

A game must not be running. Esc back to READY
first. F8 while a game is playing is a game key.

Files bigger than 64 KB, such as a picture bank,
take longer. A 2.8 MB picture is about four
minutes, then the card write.

## Other words at READY

- LIST pages the loaded file.
- SAVE writes that file back to the card.
- REMOVE "NAME" deletes a file.
- STATUS shows the name, the size, and the last fault.
- HELP is a short list. CLS clears the glass.
- MEM shows how much memory is in use.
