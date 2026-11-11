#!/usr/bin/env python3
"""Send programs and files to the board's SD card over the USB tether.

    python3 tools/tether_put.py storage/SCOTTADV.BAS
    python3 tools/tether_put.py storage/MYGAME.HTML          # + .JSH, .ICN, .ART
    python3 tools/tether_put.py storage/NOTE.HTML storage/EDITOR.HTML

Same path as the GUI's F8, without the GUI. Each file goes into the project
card.img first (an .HTML is compiled to .JSH there, and its icon and
picture sidecars come with it), then every card file that landed is written
to the board's SD card. CURRENT_SET.json is updated afterwards.

The board must be on Finder (quit the running program first). A program you
replace runs in its new version the next time you open it. Finder is kept
in memory between programs, but writing FINDER.JSH (or SYSTEM.SYS) makes
the hardware drop that copy (jmr_console_engine.sv), so Finder is read
fresh from the card when the transfer hands the board back to it.

A large file (over 64 KB, such as a sprite game's .JSH or .ART) that is
already on the board must be put in the Trash in Finder first: on the
run96 bitstream, replacing it outlasts the board's watchdog and fails
with "IO". The tool checks and says so before sending anything.

TOOLBOX.ROM and TOOLBOX.LNK cannot be sent this way: the Toolbox and every
program linked to it must match, so a Toolbox change needs a new card.
Close the GUI first; only one program can own the tether.
"""
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def big_files_already_on_board(board, paths):
    """Board files this send would replace with a large (staged-cart) copy.

    The run96 bitstream frees an existing file's whole cluster chain before
    rewriting it, and for a big file that outlasts the console watchdog
    (Finder service: IO). Sizes come from the project card.img, which holds
    the same build of each file.
    """
    import os
    from functional_model.jsb_format import SOURCE_MAX
    from tools.make_sd_image import open_volume
    on_board = {n.upper() for n in board.refresh_board_catalog()}
    vol = open_volume(Path(os.environ.get('JMR_CARD_IMG') or (ROOT / 'card.img')))
    found = []
    for p in paths:
        stem = p.name.upper().split('.')[0]
        names = [p.name.upper()] if p.suffix.upper() not in ('.HTML', '.HTM', '.JS') else \
            [stem + '.JSH', stem + '.ART']
        for name in names:
            if name not in on_board:
                continue
            try:
                size = len(vol.read_file(name))
            except FileNotFoundError:
                continue
            if size > SOURCE_MAX:
                found.append(name)
    return found


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+', help='host files, e.g. storage/NAME.HTML')
    a = ap.parse_args(argv)
    paths = [Path(p) for p in a.files]
    for p in paths:
        if not p.is_file():
            ap.error(f'no such file: {p}')
    from runtime.board_backend import BoardBackend
    board = BoardBackend()
    if board._ser is None:
        print('FAIL: no board tether found (USB cable, bitstream loaded?)')
        return 1
    try:
        deadline = time.monotonic() + 5.0
        while time.monotonic() < deadline and board._service_snapshot is None:
            board.poll()
            board._poll_service_status()
            time.sleep(0.05)
        snap = board._service_snapshot
        if snap and snap['running'] and not snap['finder_active']:
            print('FAIL: the board is running a program. Quit to Finder, then try again.')
            return 1
        big = big_files_already_on_board(board, paths)
        if big:
            print('FAIL: the board already has ' + ', '.join(big) + '. Replacing a large file '
                  'times out on this bitstream (docs/NEXT_BUILD.md). Drag '
                  + ('it' if len(big) == 1 else 'them') + ' to the Trash in Finder, then try again.')
            return 1
        sent = board.put_files_on_card(paths)
        print('Sent to the board: ' + sent)
    except Exception as error:  # report, do not leave a half-told story
        print(f'FAIL: {error}')
        return 1
    finally:
        board.shutdown()
    from tools.update_current_set import update
    update(ROOT, quiet=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
