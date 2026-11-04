"""Mouse-first disk desktop. Behavioural counterpart of jmr_desktop.sv.

All programs and optional icons come from the mounted FAT disk. The model
returns ordinary console commands; it never executes a private JS runtime.
"""
from __future__ import annotations
import json
from pathlib import Path
from .canvas_engine import CanvasEngine
from .desktop_icons import GENERIC_PROGRAM_ICON

ROOT = Path(__file__).resolve().parents[1]
FONT = json.loads((ROOT / 'assets/desktop/chicago-12.json').read_text())['glyphs']
ARROW = json.loads((ROOT / 'assets/desktop/mac-arrow.json').read_text())
# 16x16 watch. Shown while a compile is running, until the next real screen.
WATCH = {'data':[0,2016,3120,4104,8580,8580,16770,16578,17346,16392,8208,8224,4160,3456,1920,0],
         'mask':[0,2016,4080,8184,16380,16380,32766,32766,32766,32766,16380,16380,8184,4080,2016,0]}
MENUS = ((), ('Open', 'Compile', 'Read', 'Delete...', 'Close window'),
         ('Edit source',), ('Icons', 'List', 'Refresh', 'Hidden files'),
         ('Terminal','Editor','Reader','Compile','Utility','Note','Help','Restart'))
MENU_X = (0, 30, 84, 136, 190)
PAGE_ITEMS = 15


def display_name(name):
    path=Path(name);suffix=path.suffix.upper()
    if suffix in ('.HTM','.HTML','.JS'):return path.stem[:8]
    return path.stem+{'.ARJ':'.ARTJS','.ART':'.ARTX','.ICN':'.ICON'}.get(suffix,suffix)


def text_width(text):
    """Chicago advance width, the same sum _text walks while drawing."""
    return sum(FONT.get(char, FONT['?'])['advance'] for char in text)


def _chicago(canvas, x, y, text, colour, scale=1):
    """Chicago 12 into the indexed glass. Same font as the 1984 welcome."""
    for char in text:
        g = FONT.get(char, FONT['?'])
        for row, bits in enumerate(g['rows']):
            for column, bit in enumerate(bits):
                if bit == '1':
                    canvas.fill_rect(
                        x + (g['offset'] + column) * scale, y + row * scale,
                        scale, scale, colour)
        x += g['advance'] * scale


# The startup picture is the Enterprise silhouette. '@' is black ink.
# '.' leaves the checker or the white box behind it.
_ENTERPRISE = (
    '.......................@@@@@@@@@@@@@@@@@@@@@@@@@@@@...........................@@@.......................',
    '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.......................@@@@@@......................',
    '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................@@@@@@@@@@....................',
    '.@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@....................@@@@@@@@@@@@@@@.................',
    '.@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@........@@........@@@@@@@@@@@@@@@@@@@@@@@............',
    '..@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@...@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.....',
    '....@............@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@....@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
    '........................@@@@@@@@@@@@...................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
    '..........................@@@@@@@@@@@..................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@..............',
    '............................@@@@@@@@@@................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.................',
    '..............................@@@@@@@@@@............@@@@@@@@@@@@@@@........@@@@@@@@@@...................',
    '................................@@@@@@@@@..........@@@@@@@@@@@@@@@............@@@@......................',
    '..................................@@@@@@@@........@@@@@@@@@@@@@@........................................',
    '....................................@@@@@@@@.....@@@@@@@@@@@@@@.........................................',
    '.....................................@@@@@@@@...@@@@@@@@@@@@@@@.........................................',
    '.......................................@@@@@@@@@@@@@@@@@@@@@@@@.........................................',
    '..................................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.........................................',
    '.............................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.......................................',
    '.............................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '............................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '...........................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '...........................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '.................................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '.....................................@@@@@@@@@@@@@@@@@@@@@@@@@@@@@......................................',
    '......................................@@@@@@@@@@@@@@@@@@@@@@@@@@@.......................................',
    '.......................................@@@@@@@@@@@@@@@@@@@@@@@..........................................',
    '..............................................@@@@@@@@@@@@@.............................................',
)
_REGISTRY = 'NCC-1701'
_SHIP_NAME = 'JMR Enterprises'


def _bitmap(canvas, x, y, rows, scale):
    """One cell of a startup sketch. '.' leaves the picture behind it."""
    for row_i, row in enumerate(rows):
        for col, cell in enumerate(row):
            if cell == '@':
                canvas.fill_rect(x + col * scale, y + row_i * scale, scale, scale, 0)


def _enterprise_box(scale):
    """Width and height of the ship plus the two Chicago lines under it."""
    ship_w = len(_ENTERPRISE[0]) * scale
    caption = max(text_width(_REGISTRY), text_width(_SHIP_NAME)) * scale
    width = max(ship_w, caption)
    height = len(_ENTERPRISE) * scale + 8 * scale + 15 * scale + 4 * scale + 15 * scale
    return width, height


def _enterprise(canvas, x, y, scale):
    """The silhouette, then NCC-1701, then JMR Enterprises. Both lines are Chicago."""
    box_w, _box_h = _enterprise_box(scale)
    ship_w = len(_ENTERPRISE[0]) * scale
    _bitmap(canvas, x + (box_w - ship_w) // 2, y, _ENTERPRISE, scale)
    y_text = y + len(_ENTERPRISE) * scale + 8 * scale
    _chicago(canvas, x + (box_w - text_width(_REGISTRY) * scale) // 2, y_text, _REGISTRY, 0, scale)
    _chicago(canvas, x + (box_w - text_width(_SHIP_NAME) * scale) // 2,
             y_text + 19 * scale, _SHIP_NAME, 0, scale)


def paint_javatosh_boot(canvas, stage):
    """Startup glass. stage 0 is the ship. stage 1 is the welcome box.

    The checker uses the desktop's two colours (0x5B and 0x7B). With the
    rgb332 palette those are this machine's blue, not the 1984 gray.
    The ship is the Enterprise silhouette. Under it, Chicago reads
    NCC-1701 and JMR Enterprises. The welcome box has the Macintosh
    shadow: a one-pixel black edge, then black only on the right and
    the bottom.
    """
    width, height = canvas.width, canvas.height
    light, dark = 0x7B, 0x5B
    pair_a = bytes((light, light, dark, dark))
    pair_b = bytes((dark, dark, light, light))
    row_a = pair_a * (width // 4)
    row_b = pair_b * (width // 4)
    picture = bytearray()
    for y in range(height):
        picture += row_a if (y // 2) % 2 == 0 else row_b
    canvas.back[:] = picture
    if stage == 0:
        scale = 2
        box_w, box_h = _enterprise_box(scale)
        _enterprise(canvas, (width - box_w) // 2, (height - box_h) // 2, scale)
    else:
        # Same proportions as the 1984 box, shadow stepped in from the
        # top-left the way a Macintosh window shadow is.
        bw, bh, shadow = 560, 168, 6
        bx, by = (width - bw) // 2, (height - bh) // 2 - 16
        canvas.fill_rect(bx + shadow, by + shadow, bw, bh, 0)
        canvas.fill_rect(bx, by, bw, bh, 0)
        canvas.fill_rect(bx + 1, by + 1, bw - 2, bh - 2, 255)
        message = 'Welcome to Javatosh.'
        tw = text_width(message)
        icon_h = _enterprise_box(1)[1]
        _enterprise(canvas, bx + 16, by + (bh - icon_h) // 2, 1)
        _chicago(canvas, bx + (bw - tw) // 2, by + (bh - 15) // 2, message, 0)
    canvas.front[:] = canvas.back
    canvas.dirty = False


def centered_x(center, text):
    """Left edge that puts the caption's advance width on center."""
    return center - text_width(text) // 2


def rgb332(value):
    r,g,b = (value >> 5)&7, (value >> 2)&7, value&3
    return ((r<<5)|(r<<2)|(r>>1), (g<<5)|(g<<2)|(g>>1), b*85)


# Rectangles are generated into the RTL by tools/export_desktop.py.
# Coordinates are relative to the disk window unless absolute=True.
# Each record: x,y,width,height,colour,condition,absolute.
RECTS = [
    (0,0,640,22,255,'always',True), (0,21,640,1,0,'always',True),
    (0,0,548,354,0,'window',False), (1,1,546,352,255,'window',False),
    (2,2,544,22,0x77,'window',False),
    (2,24,544,1,0,'window',False), (2,47,544,1,0,'window',False),
    (2,336,544,1,0,'window',False), (528,48,1,288,0,'window',False),
    (529,48,17,288,0xdb,'window',False),
    (529,48,17,17,255,'window',False), (529,319,17,17,255,'window',False),
    (529,64,17,1,0,'window',False), (529,318,17,1,0,'window',False),
    (2,337,17,15,255,'window',False), (19,337,1,15,0,'window',False),
    (511,337,1,15,0,'window',False), (512,337,16,15,255,'window',False),
    (529,337,17,15,0x77,'window',False),
    (6,5,14,14,0,'window',False), (7,6,12,12,255,'window',False),
    (204,3,140,19,255,'window',False),
    (579,44,34,39,0,'always',True), (581,46,30,35,255,'always',True),
    (585,50,22,15,0,'always',True), (587,52,18,11,0x37,'always',True),
    (587,72,16,2,0,'always',True),
    (582,413,29,34,0,'always',True), (584,415,25,30,255,'always',True),
    (580,410,33,3,0,'always',True), (591,407,11,3,0,'always',True),
    (588,419,1,23,0,'always',True), (594,419,1,23,0,'always',True),
    (600,419,1,23,0,'always',True), (606,419,1,23,0,'always',True),
]


def captions(count, page, menu, window, names, selected, wx, wy, list_view, dialog, hidden=False, menu_row=-1, extra=(), trash_open=False):
    # Disk picture is x=579, width 34. Trash picture is x=580, width 33.
    # Both centers are 596. A fixed left edge sat the words left of the picture.
    # An open menu title is white on black, same as the item under the pointer.
    rows=[(34,3,'File',255 if menu==1 else 0),(88,3,'Edit',255 if menu==2 else 0),
          (140,3,'View',255 if menu==3 else 0),(194,3,'Special',255 if menu==4 else 0),
          (548,3,'',0),(centered_x(596,'Disk'),86,'Disk',0),(centered_x(596,'Trash'),449,'Trash',0)]
    if window:
        rows += [(wx+235,wy+4,'Trash' if trash_open else 'Storage',0),(wx+10,wy+28,f'{count:3d} items',0),
                 (wx+365,wy+28,f'Page {page+1:2d}',0),
                 (wx+532,wy+48,'^',0),(wx+532,wy+318,'v',0),
                 (wx+5,wy+337,'<',0),(wx+515,wy+337,'>',0)]
        for slot,name in enumerate(names[page*PAGE_ITEMS:(page+1)*PAGE_ITEMS]):
            i=page*PAGE_ITEMS+slot
            label=display_name(name)
            if list_view:
                x,y=wx+28,wy+50+slot*19
            else:
                # Icon is 32px at wx+38. Center the name on that picture, not the cell's left edge.
                x,y=centered_x(wx+54+(slot%5)*102,label),wy+98+(slot//5)*86
            rows.append((x,y,label,255 if selected==i else 0))
    if menu:
        items=MENUS[menu]+tuple(extra)
        for i,text in enumerate(items):
            label=('* '+text) if hidden and text=='Hidden files' else text
            rows.append((MENU_X[menu]+10,27+i*21,label,255 if i==menu_row else 0))
    if dialog:
        if dialog==3:
            title,question,detail,button='Empty Trash?','Permanently delete these files?','This cannot be undone.','Empty'
        elif dialog==1:
            title,question,detail,button='Delete file?','Permanently delete file?','This cannot be undone.','Delete'
        else:
            title,question,detail,button='About JMR','Native HTML Computer','Mouse / keyboard / disk','OK'
        rows += [(230,165,title,0),(158,198,question,0),(158,221,detail,0),(186,267,button,0)]
        if dialog in (1,3): rows.append((360,267,'Cancel',0))
    return rows


class Desktop:
    def __init__(self, storage):
        self.storage=storage; self.canvas=CanvasEngine()
        self.canvas.palette=[rgb332(i) for i in range(256)]
        self.visible=True; self.window=True; self.menu=0; self.menu_row=-1; self.dialog=0
        self.hidden=False;self._hidden_previous_view=False
        self.wx=8; self.wy=34; self.page=0; self.selected=-1; self.list_view=False
        self.names=[]; self.icons={}; self.x=320; self.y=240; self.buttons=0
        self.trash=[]; self.trash_open=False; self.file_drag=None; self.press=None
        self.last_selected=-1; self.last_click=-100; self.frame=0; self.drag=None
        self.dirty=True; self.refresh()

    def menu_items(self, menu):
        items=MENUS[menu]
        # Empty Trash appears only once a file is held, so a closed trash
        # still matches the desktop the RTL draws.
        if menu==4 and self.trash: return items+('Empty Trash',)
        return items

    def refresh(self):
        # List view is alphabetical, like Finder's View by Name.
        # Icon view stays in disk order. Trash holds names until Empty Trash.
        keep=self.names[self.selected] if 0<=self.selected<len(self.names) else None
        on_disk=[]
        visible=[]
        for name,size in self.storage.list_all():
            on_disk.append(name)
            if self.hidden or Path(name).suffix.upper() in ('.HTM','.HTML','.JS','.MD','.TXT'):
                visible.append(name)
        visible=visible[:256]
        present=set(on_disk)
        self.trash=[name for name in self.trash if name in present]
        held=set(self.trash)
        if self.trash_open: self.names=[name for name in self.trash if name in held]
        else: self.names=[name for name in visible if name not in held]
        if self.list_view: self.names.sort(key=lambda name: name.upper())
        self.icons={name:self.storage.program_icon(name) for name in self.names}
        self.page=min(self.page,max(0,(len(self.names)-1)//PAGE_ITEMS))
        self.selected=self.names.index(keep) if keep in self.names else -1
        self.dirty=True

    def tick(self):
        self.frame+=1
        if self.visible and self.dirty: self.render()

    def _rect(self,x,y,w,h,colour):
        self.canvas.fill_rect(x,y,w,h,colour)

    def _covered(self,x,y,layer):
        mx=MENU_X[self.menu]
        return ((layer==0 and self.menu and mx<=x<mx+162 and 22<=y<24+len(self.menu_items(self.menu))*21+8) or
                (layer<2 and self.dialog and 133<=x<508 and 154<=y<307))

    def _text(self,x,y,text,colour,layer=0):
        for char in text:
            g=FONT.get(char,FONT['?'])
            for row,bits in enumerate(g['rows']):
                for column,bit in enumerate(bits):
                    if bit=='1' and not self._covered(x+g['offset']+column,y+row,layer):
                        self._rect(x+g['offset']+column,y+row,1,1,colour)
            x+=g['advance']

    def render(self):
        back=self.canvas.back
        for y in range(22,480):
            back[y*640:(y+1)*640]=bytes([0x5b,0x7b] if y&1 else [0x7b,0x5b])*320
        for x,y,w,h,c,condition,absolute in RECTS:
            if condition=='window' and not self.window: continue
            self._rect(x+(0 if absolute else self.wx),y+(0 if absolute else self.wy),w,h,c)
        if self.window:
            for y in range(self.wy+5,self.wy+22,3):
                self._rect(self.wx+24,y,180,1,0);self._rect(self.wx+344,y,198,1,0)
            if self.page*15<=self.selected<(self.page+1)*15:
                slot=self.selected-self.page*15
                if self.list_view:self._rect(self.wx+24,self.wy+49+slot*19,490,18,0x17)
                else:
                    label=display_name(self.names[self.selected])
                    tw=text_width(label)
                    cx=self.wx+54+(slot%5)*102
                    self._rect(cx-tw//2-3,self.wy+97+(slot//5)*86,tw+6,18,0x17)
            if not self.list_view:
                for slot,name in enumerate(self.names[self.page*15:(self.page+1)*15]):
                    icon=self.icons.get(name,GENERIC_PROGRAM_ICON)
                    ix,iy=self.wx+38+(slot%5)*102,self.wy+58+(slot//5)*86
                    for y in range(32):
                        for x in range(32):
                            colour,opaque=icon.pixel(x,y)
                            if opaque:self._rect(ix+x,iy+y,1,1,colour)
        if self.menu:
            items=self.menu_items(self.menu)
            x=MENU_X[self.menu];h=len(items)*21+8
            self._rect(x+2,24,160,h,0);self._rect(x,22,160,h,0);self._rect(x+1,23,158,h-2,255)
            # Open title, and the item under the pointer, invert like a Mac menu.
            self._rect(x,0,74 if self.menu==4 else 50,21,0)
            if 0<=self.menu_row<len(items):
                self._rect(x+2,26+self.menu_row*21,154,20,0)
        if self.dialog:
            self._rect(133,154,375,153,0);self._rect(135,156,371,149,255)
            self._rect(168,260,96,27,0);self._rect(170,262,92,23,0xdb)
            if self.dialog==1:
                self._rect(341,260,96,27,0);self._rect(343,262,92,23,0xdb)
        window_rows=7+(7+len(self.names[self.page*15:(self.page+1)*15]) if self.window else 0)
        menu_rows=len(self.menu_items(self.menu)) if self.menu else 0
        extra=('Empty Trash',) if self.menu==4 and self.trash else ()
        for i,(x,y,text,c) in enumerate(captions(len(self.names),self.page,self.menu,self.window,
                                   self.names,self.selected,self.wx,self.wy,self.list_view,self.dialog,self.hidden,self.menu_row,extra,self.trash_open)):
            self._text(x,y,text,c,0 if i<window_rows else 1 if i<window_rows+menu_rows else 2)
        if self.file_drag:
            self._text(self.x+14,self.y,self.file_drag,0,2)
        self.canvas.present();self.dirty=False

    def pointer(self,x,y,buttons):
        x,y=max(0,min(639,x)),max(0,min(479,y));down=bool(buttons&1 and not self.buttons&1)
        self.x,self.y,self.buttons=x,y,buttons
        if self.drag is not None:
            if buttons&1:
                self.wx=max(0,min(91,x-self.drag[0]));self.wy=max(22,min(126,y-self.drag[1]));self.dirty=True
            else:self.drag=None
            return None
        # A small move turns a click into a drag. Drop on Trash holds the
        # file. Drop on Disk, while the Trash window is open, puts it back.
        if self.press is not None and buttons&1 and self.file_drag is None:
            if abs(x-self.press[1])>4 or abs(y-self.press[2])>4:
                ix=self.press[0]
                if 0<=ix<len(self.names):
                    self.file_drag=self.names[ix];self.last_click=-100;self.dirty=True
        if self.file_drag is not None:
            self.dirty=True
            if buttons&1:return None
            name=self.file_drag;self.file_drag=None;self.press=None
            if 570<=x<=625 and y>=404 and name not in self.trash:
                self.trash.append(name)
                if 0<=self.selected<len(self.names) and self.names[self.selected]==name:self.selected=-1
                self.refresh()
            elif self.trash_open and 570<=x<=625 and 40<=y<=104 and name in self.trash:
                self.trash.remove(name);self.trash_open=False;self.refresh()
            return None
        if self.press is not None and not buttons&1:self.press=None
        if self.menu and not self.dialog:
            if y<22:
                if self.menu_row!=-1:
                    self.menu_row=-1;self.dirty=True
            else:
                row=(y-26)//21
                over=MENU_X[self.menu]<=x<MENU_X[self.menu]+160 and 26<=y and 0<=row<len(self.menu_items(self.menu))
                new=row if over else -1
                if new!=self.menu_row:
                    self.menu_row=new;self.dirty=True
        if not down:return None
        self.dirty=True
        self.menu_row=-1
        if self.dialog:
            if 260<=y<287:
                if 168<=x<264:
                    dialog=self.dialog;self.dialog=0
                    if dialog==1:return self.action('Delete')
                    if dialog==3:return ('EMPTY',None)
                elif 341<=x<437:self.dialog=0
            return None
        if y<22:
            self.menu=next((i for i in range(1,5) if MENU_X[i]<=x<MENU_X[i]+(74 if i==4 else 50)),0)
            return None
        if self.menu:
            menu=self.menu;self.menu=0;row=(y-26)//21
            items=self.menu_items(menu)
            if MENU_X[menu]<=x<MENU_X[menu]+160 and 0<=row<len(items):
                return self.action(items[row])
            return None
        if 570<=x<=625 and 40<=y<=104:
            if self.trash_open:
                self.trash_open=False;self.selected=-1;self.page=0;self.refresh()
            self.window=True;return None
        if 570<=x<=625 and y>=404:
            self.trash_open=not self.trash_open;self.selected=-1;self.page=0;self.window=True;self.refresh()
            return None
        if not self.window:return None
        rx,ry=x-self.wx,y-self.wy
        if 6<=rx<20 and 5<=ry<19:self.window=False;return None
        if 22<=rx<546 and 2<=ry<24:self.drag=(rx,ry);return None
        if (529<=rx<547 and 318<=ry<336) or (511<=rx<529 and 337<=ry<353):
            self.page=min(self.page+1,max(0,(len(self.names)-1)//15));return None
        if (529<=rx<547 and 48<=ry<65) or (2<=rx<20 and 337<=ry<353):
            self.page=max(0,self.page-1);return None
        slot=-1
        if self.list_view and 24<=rx<520 and 49<=ry<334:slot=(ry-49)//19
        elif 10<=rx<520 and 50<=ry<320:
            col=(rx-10)//102;row=(ry-50)//86
            if col<5 and row<3:slot=row*5+col
        index=self.page*15+slot
        if slot>=0 and index<len(self.names):
            self.press=(index,x,y)
            double=self.selected==index and self.last_selected==index and self.frame-self.last_click<=24
            self.selected=index;self.last_selected=index;self.last_click=self.frame
            if double and not self.trash_open:return self.action('Open')
        else:self.selected=-1
        return None

    def action(self,action):
        if action=='Close window':self.window=False;return None
        if action in ('Icons','List'):self.list_view=action=='List';self.refresh();return None
        if action=='Hidden files':
            if not self.hidden:
                self._hidden_previous_view=self.list_view;self.list_view=True
            else:self.list_view=self._hidden_previous_view
            self.hidden=not self.hidden;self.page=0;self.selected=-1;self.refresh();return None
        if action=='Refresh':self.refresh();return None
        if action=='About':self.dialog=2;return None
        if action=='Restart':self.window=True;self.page=0;self.selected=-1;self.refresh();return None
        if action=='Delete...':
            if self.selected>=0:self.dialog=1
            return None
        if action=='Empty Trash':
            if self.trash:self.dialog=3
            return None
        if action=='Terminal':self.visible=False;return ('TERMINAL',None)
        if action in ('Help','Reader') and not (action=='Reader' and 0<=self.selected<len(self.names)):
            self.visible=False;return ('READ','HELP.MD')
        # Compile with nothing selected opens the Compile program, the way
        # Editor with nothing selected opens Note. A selected HTML still compiles.
        if action=='Compile' and self.selected<0:
            self.visible=False;return ('RUN','COMPILE.HTM')
        if action in ('Utility','Note') or (action=='Editor' and self.selected<0):
            self.visible=False;return ('RUN','UTILITY.HTM' if action=='Utility' else 'NOTE.HTM')
        if action=='Editor':action='Edit source'
        if action=='Reader':action='Read'
        if action=='Help':self.visible=False;return ('READ','HELP.MD')
        if not 0<=self.selected<len(self.names):return None
        name=self.names[self.selected]
        if action=='Open':action='RUN' if Path(name).suffix.upper() in ('.HTML','.HTM','.JS') else 'READ'
        elif action=='Edit source':action='EDIT'
        elif action=='Compile':action='RUN' if Path(name).stem.upper()=='COMPILE' else 'COMPILE'
        elif action=='Read':action='READ'
        elif action=='Delete':
            if name in self.trash:self.trash.remove(name)
            action='REMOVE'
        self.visible=False
        return action,name


def _ibeam_glyph():
    """16×16 I-beam. Hot spot is the middle of the stem, (7, 7)."""
    rows=(
        '0001110001110000',
        '0001110001110000',
        '0000010001000000',
        '0000010001000000',
        '0000001110000000',
        '0000001110000000',
        '0000001110000000',
        '0000001110000000',
        '0000001110000000',
        '0000001110000000',
        '0000010001000000',
        '0000010001000000',
        '0001110001110000',
        '0001110001110000',
        '0000000000000000',
        '0000000000000000',
    )
    data=[];mask=[]
    bits=[int(row,2) for row in rows]
    for i,word in enumerate(bits):
        around=word
        if i:around|=bits[i-1]
        if i+1<len(bits):around|=bits[i+1]
        around|=(word<<1)&0xFFFF
        around|=word>>1
        data.append(word)
        mask.append(around)
    return {'data':data,'mask':mask}


IBEAM=_ibeam_glyph()


def pointer_overlays(x,y,watch=False,ibeam=False):
    """Display plane, matching jmr_mouse_overlay.sv; never touches JS pixels.

    watch=True is the Macintosh wristwatch, used until the screen updates.
    ibeam=True is the text cursor, used over the name field.
    """
    out=[]
    rgba=bytearray()
    glyph=WATCH if watch else IBEAM if ibeam else ARROW
    for row in range(16):
        for col in range(16):
            colour=0 if glyph['data'][row]&(0x8000>>col) else 255
            rgba.extend((colour,colour,colour,255 if glyph['mask'][row]&(0x8000>>col) else 0))
    # The arrow's hot spot is (1, 1). The I-beam's is the stem.
    hx,hy=(7,7) if ibeam and not watch else (1,1)
    out.append((x-hx,y-hy,16,16,bytes(rgba)))
    return out
