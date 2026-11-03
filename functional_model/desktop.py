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
MENUS = ((), ('Open', 'Compile', 'Read', 'Delete...', 'Close window'),
         ('Edit source',), ('Icons', 'List', 'Refresh', 'Hidden files'),
         ('Terminal','Editor','Reader','Compile','Utility','Note','Help','Restart'))
MENU_X = (0, 30, 84, 136, 190)
PAGE_ITEMS = 15


def display_name(name):
    path=Path(name);suffix=path.suffix.upper()
    if suffix in ('.HTM','.HTML','.JS'):return path.stem[:8]
    return path.stem+{'.ARJ':'.ARTJS','.ART':'.ARTX','.ICN':'.ICON'}.get(suffix,suffix)


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


def captions(count, page, menu, window, names, selected, wx, wy, list_view, dialog, hidden=False):
    rows=[(34,3,'File',0),(88,3,'Edit',0),(140,3,'View',0),(194,3,'Special',0),
          (548,3,'',0),(572,86,'Disk',0),(575,449,'Trash',0)]
    if window:
        rows += [(wx+235,wy+4,'Storage',0),(wx+10,wy+28,f'{count:3d} items',0),
                 (wx+365,wy+28,f'Page {page+1:2d}',0),
                 (wx+532,wy+48,'^',0),(wx+532,wy+318,'v',0),
                 (wx+5,wy+337,'<',0),(wx+515,wy+337,'>',0)]
        for slot,name in enumerate(names[page*PAGE_ITEMS:(page+1)*PAGE_ITEMS]):
            i=page*PAGE_ITEMS+slot
            if list_view:
                x,y=wx+28,wy+50+slot*19
            else:
                x,y=wx+12+(slot%5)*102,wy+98+(slot//5)*86
            label=display_name(name)
            rows.append((x,y,label,255 if selected==i else 0))
    if menu:
        for i,text in enumerate(MENUS[menu]):
            rows.append((MENU_X[menu]+10,27+i*21,('* '+text) if hidden and text=='Hidden files' else text,0))
    if dialog:
        title='Delete file?' if dialog==1 else 'About JMR'
        rows += [(230,165,title,0),(158,198,'Permanently delete file?' if dialog==1 else 'Native HTML Computer',0),
                 (158,221,'This cannot be undone.' if dialog==1 else 'Mouse / keyboard / disk',0),
                 (186,267,'Delete' if dialog==1 else 'OK',0)]
        if dialog==1: rows.append((360,267,'Cancel',0))
    return rows


class Desktop:
    def __init__(self, storage):
        self.storage=storage; self.canvas=CanvasEngine()
        self.canvas.palette=[rgb332(i) for i in range(256)]
        self.visible=True; self.window=True; self.menu=0; self.dialog=0
        self.hidden=False;self._hidden_previous_view=False
        self.wx=8; self.wy=34; self.page=0; self.selected=-1; self.list_view=False
        self.names=[]; self.icons={}; self.x=320; self.y=240; self.buttons=0
        self.last_selected=-1; self.last_click=-100; self.frame=0; self.drag=None
        self.dirty=True; self.refresh()

    def refresh(self):
        self.names=[name for name,size in self.storage.list_all()
                    if self.hidden or Path(name).suffix.upper() in ('.HTM','.HTML','.JS','.MD','.TXT')]
        self.names=self.names[:256]
        self.icons={name:self.storage.program_icon(name) for name in self.names}
        self.page=min(self.page,max(0,(len(self.names)-1)//PAGE_ITEMS))
        if self.selected>=len(self.names): self.selected=-1
        self.dirty=True

    def tick(self):
        self.frame+=1
        if self.visible and self.dirty: self.render()

    def _rect(self,x,y,w,h,colour):
        self.canvas.fill_rect(x,y,w,h,colour)

    def _covered(self,x,y,layer):
        mx=MENU_X[self.menu]
        return ((layer==0 and self.menu and mx<=x<mx+162 and 22<=y<24+len(MENUS[self.menu])*21+8) or
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
                else:self._rect(self.wx+10+slot%5*102,self.wy+97+slot//5*86,88,18,0x17)
            if not self.list_view:
                for slot,name in enumerate(self.names[self.page*15:(self.page+1)*15]):
                    icon=self.icons.get(name,GENERIC_PROGRAM_ICON)
                    ix,iy=self.wx+38+(slot%5)*102,self.wy+58+(slot//5)*86
                    for y in range(32):
                        for x in range(32):
                            colour,opaque=icon.pixel(x,y)
                            if opaque:self._rect(ix+x,iy+y,1,1,colour)
        if self.menu:
            x=MENU_X[self.menu];h=len(MENUS[self.menu])*21+8
            self._rect(x+2,24,160,h,0);self._rect(x,22,160,h,0);self._rect(x+1,23,158,h-2,255)
        if self.dialog:
            self._rect(133,154,375,153,0);self._rect(135,156,371,149,255)
            self._rect(168,260,96,27,0);self._rect(170,262,92,23,0xdb)
            if self.dialog==1:
                self._rect(341,260,96,27,0);self._rect(343,262,92,23,0xdb)
        window_rows=7+(7+len(self.names[self.page*15:(self.page+1)*15]) if self.window else 0)
        menu_rows=len(MENUS[self.menu]) if self.menu else 0
        for i,(x,y,text,c) in enumerate(captions(len(self.names),self.page,self.menu,self.window,
                                   self.names,self.selected,self.wx,self.wy,self.list_view,self.dialog,self.hidden)):
            self._text(x,y,text,c,0 if i<window_rows else 1 if i<window_rows+menu_rows else 2)
        self.canvas.present();self.dirty=False

    def pointer(self,x,y,buttons):
        x,y=max(0,min(639,x)),max(0,min(479,y));down=bool(buttons&1 and not self.buttons&1)
        self.x,self.y,self.buttons=x,y,buttons
        if self.drag is not None:
            if buttons&1:
                self.wx=max(0,min(91,x-self.drag[0]));self.wy=max(22,min(126,y-self.drag[1]));self.dirty=True
            else:self.drag=None
            return None
        if not down:return None
        self.dirty=True
        if self.dialog:
            if 260<=y<287:
                if 168<=x<264:
                    dialog=self.dialog;self.dialog=0
                    if dialog==1:return self.action('Delete')
                elif 341<=x<437:self.dialog=0
            return None
        if y<22:
            self.menu=next((i for i in range(1,5) if MENU_X[i]<=x<MENU_X[i]+(74 if i==4 else 50)),0)
            return None
        if self.menu:
            menu=self.menu;self.menu=0;row=(y-26)//21
            if MENU_X[menu]<=x<MENU_X[menu]+160 and 0<=row<len(MENUS[menu]):
                return self.action(MENUS[menu][row])
            return None
        if 570<=x<=625 and 40<=y<=104:
            self.window=True;return None
        if 570<=x<=625 and y>=404:
            if self.selected>=0:self.dialog=1
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
            double=self.selected==index and self.last_selected==index and self.frame-self.last_click<=24
            self.selected=index;self.last_selected=index;self.last_click=self.frame
            if double:return self.action('Open')
        else:self.selected=-1
        return None

    def action(self,action):
        if action=='Close window':self.window=False;return None
        if action in ('Icons','List'):self.list_view=action=='List';return None
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
        if action=='Terminal':self.visible=False;return ('TERMINAL',None)
        if action in ('Help','Reader') and not (action=='Reader' and 0<=self.selected<len(self.names)):
            self.visible=False;return ('READ','HELP.MD')
        if action in ('Utility','Note') or (action=='Editor' and self.selected<0):
            self.visible=False;return ('RUN','UTILITY.HTM' if action=='Utility' else 'NOTE.HTM')
        if action=='Editor':action='Edit source'
        if action=='Reader':action='Read'
        if action=='Help':self.visible=False;return ('READ','HELP.MD')
        if not 0<=self.selected<len(self.names):return None
        name=self.names[self.selected]
        if action=='Open':action='RUN' if Path(name).suffix.upper() in ('.HTML','.HTM','.JS') else 'READ'
        elif action=='Edit source':action='EDIT'
        elif action=='Compile':action='COMPILE'
        elif action=='Read':action='READ'
        elif action=='Delete':action='REMOVE'
        self.visible=False
        return action,name


def pointer_overlays(x,y):
    """Display plane, matching jmr_mouse_overlay.sv; never touches JS pixels."""
    out=[]
    rgba=bytearray()
    for row in range(16):
        for col in range(16):
            colour=0 if ARROW['data'][row]&(0x8000>>col) else 255
            rgba.extend((colour,colour,colour,255 if ARROW['mask'][row]&(0x8000>>col) else 0))
    out.append((x-1,y-1,16,16,bytes(rgba)))
    return out
