"""Set every program's About text in one place, and check that it fits.

An About is "Title|line|line...": a title and at most five lines, each at
most 335 pixels in the system font, 400 bytes in all. Run with --write to
put the text into storage/NAME.HTML (the first tbSessionProperty(..., 2, ...)).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from functional_model.desktop import FONT  # noqa: E402

ABOUT = {
 '2DFANTA2': "Fantasy Chess|Animated chess against the computer.|Click a piece, then the square to move to.",
 'ASTEROID': "Asteroids|Shoot the rocks before they hit your ship.|Left and Right turn, Up thrusts,|Space fires.",
 'AURORA': "Aurora|A space shooter in colour.|Left and Right move, Space fires,|Enter starts.",
 'BOMBFAST': "Bomberman|Bomb a way through the maze, and keep|clear of the blast. Arrows move,|Space drops a bomb.",
 'BOXES': "Two Boxes|Two boxes bounce around the screen.|The smallest game: read its source first.",
 'BOXES2': "Sixteen Boxes|Sixteen boxes bounce at once:|a test of drawing speed.",
 'CBCENTIPED': "Centipede|Shoot the centipede before it reaches|the bottom. The mouse moves and fires.",
 'CBDNKF': "Donkey Kong|Climb the girders to the top and jump|the barrels. Arrows move and climb,|Space jumps.",
 'CBFLDF': "Field Run|Build towers to stop each wave.|Arrows move the cursor, a click places|a tower, Space sends the next wave.",
 'CBMKBA': "MK Big|Two players fight. Player 1: W A S D,|F punch, G kick. Player 2: arrows,|O punch, P kick. Enter starts.",
 'CBMKCA': "MK Big CPU|Fight the computer. W A S D move,|F punches, G kicks. Enter starts.",
 'CBMRDOF': "Mr. Do!|Dig tunnels, collect the cherries and|throw the ball at the monsters.|Arrows dig, Space throws.",
 'CBPACFAST': "Pac-Man|Eat every dot while the ghosts chase you;|a power pellet turns the tables.|Arrows steer, Enter starts.",
 'COMPILE': "Compile|Turns a program's HTML into NAME.JSH.|File, then Open..., picks the program.|The old NAME.JSH stays until the new one|is complete. Esc cancels.",
 'DOOM3DFI': "Doom 3D|Walk a maze of corridors in 3-D.|Arrows walk and turn, Space fires.",
 'GRAPHICS': "Graphics|Runs every Toolbox drawing operation|once and shows PASS or FAIL for each:|a check of the hardware.",
 'GUIDEX': "GUI Example|A sorted list and a drop target. Drag a|name onto Remove; Desk, then Restore|names, brings them back.|Source to read and copy from.",
 'INVF': "Space Invaders|Shoot the invaders before they land.|Left and Right move, Space fires.",
 'JOYDEMO': "Joystick Demo|Shows the stick and its buttons as you|move them. The joystick plugs into|Pmod JB.",
 'MACWRITE': "MacWrite|Write and style a document: fonts, sizes,|bold, italic, rulers and tabs.|File, then Save As..., names it NAME.WRT.",
 'MENUEX': "Menu Example|The smallest program with its own menu:|Example, then Add One, counts up.|Source to read and copy from.",
 'MISSILE': "Missile Command|Stop the missiles before they reach your|cities. Aim with the mouse; a click or|Space fires.",
 'PRINCEB': "Prince B|Prince moved by the original Apple II|move tables. Arrows run, jump, climb|and crouch.",
 'SNDDEMO': "Sound Demo|Plays each of the computer's sound|effects on its four voices.",
 'TANK': "Tank|Drive around the arena and shoot the|other tanks. Arrows drive, Space fires.",
 'TBDEMO': "Toolbox Tour|Every Toolbox part a program uses, in|one window: dialogs, menus, text, patterns,|CopyBits, ports, scrolling, mouse, sound.|Read the source to copy from.",
 'UISESS': "Session Example|A text viewer with its own files: New|sample, Save As..., Open..., scroll bars,|resizing and check marks.|Read the source to see how.",
}


def width(s):
    return sum(FONT.get(c, FONT['?'])['advance'] for c in s)


def check():
    bad = []
    for name, text in ABOUT.items():
        parts = text.split('|')
        if len(parts) > 6 or len(text.encode()) > 400:
            bad.append(f'{name}: too long')
        for line in parts:
            if width(line) > 335:
                bad.append(f'{name}: {width(line)} px: {line}')
    return bad


def write():
    for name, text in ABOUT.items():
        p = ROOT / 'storage' / f'{name}.HTML'
        t = p.read_text()
        js = text.replace('\\', '\\\\').replace('"', '\\"')
        new, n = re.subn(r'(tbSessionProperty\([A-Za-z_]+, *2, *)"(?:[^"\\]|\\.)*"',
                         lambda m: m.group(1) + '"' + js + '"', t, count=1)
        if n != 1:
            raise SystemExit(f'{name}: no About line')
        if new != t:
            p.write_text(new)
            print('set', name)


if __name__ == '__main__':
    problems = check()
    for line in problems:
        print(line)
    if problems:
        raise SystemExit(1)
    if '--write' in sys.argv:
        write()
    print('About texts fit')
