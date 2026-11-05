"""Shared classic-Mac menus and file dialogs for system applications.

Programs declare a window; this system component owns menus, picking files,
Save As names, and closing. It never interprets program JavaScript.
"""
from .desktop import FONT

def parse_about(spec):
    """Small application-owned title/description, rendered by the system."""
    if not isinstance(spec,str) or spec.count('|')!=1 or any(ord(c)<32 or ord(c)>126 for c in spec):
        raise ValueError('systemAbout needs Title|One line about the program')
    title,description=spec.split('|')
    if not 1<=len(title)<=32 or not 1<=len(description)<=64:
        raise ValueError('systemAbout title/description exceeds its limit')
    if any(sum(FONT.get(c,FONT['?'])['advance'] for c in line)>335 for line in (title,description)):
        raise ValueError('systemAbout text exceeds the dialog width')
    return title,description

def parse_menus(spec):
    """Bounded on-disk contract: Menu|Item=160|Item=161;Other|Item=162."""
    if not isinstance(spec,str) or len(spec)>512 or any(ord(c)<32 or ord(c)>126 for c in spec):
        raise ValueError('systemMenus needs at most 512 printable ASCII bytes')
    result=[];seen=set()
    if not spec:return result
    for menu in spec.split(';'):
        parts=menu.split('|');label=parts[0]
        if label in ('File','Edit','View','Special') or label in [title for title,rows in result] or not 1<=len(label)<=12 or len(parts)<2 or len(parts)>9:
            raise ValueError('systemMenus: use a menu title and 1-8 items')
        rows=[]
        for item in parts[1:]:
            title,sep,code=item.rpartition('=')
            if not sep or not code.isdigit() or not 160<=int(code)<=191 or not 1<=len(title)<=24 or int(code) in seen:
                raise ValueError('systemMenus: unique commands 160-191, labels 1-24 bytes')
            seen.add(int(code));rows.append((title,'app:'+code,True))
        result.append((label,rows))
    if len(result)>3:raise ValueError('systemMenus: at most three application menus')
    width=sum(sum(FONT.get(c,FONT['?'])['advance'] for c in label)+20 for label in ['File','Edit','View','Special']+[m[0] for m in result])
    if width>610:raise ValueError('systemMenus: menu headings exceed the screen width')
    return result

def parse_owned_menus(spec):
    """A document program owns its whole menu bar, including File and Edit.

    The descriptor starts with File|. Up to six menus, 14 items each.
    A lone "-" is a separator. Quit and Close leave the program.
    Commands are 160-239. Checks still use the first 32 of those.
    """
    if not isinstance(spec,str) or len(spec)>800 or any(ord(c)<32 or ord(c)>126 for c in spec):
        raise ValueError('systemMenus needs at most 800 printable ASCII bytes')
    result=[];seen=set()
    menus=spec.split(';')
    if not 1<=len(menus)<=6:raise ValueError('systemMenus: at most six menus')
    for menu in menus:
        parts=menu.split('|');label=parts[0]
        if label in [title for title,_rows in result] or not 1<=len(label)<=12 or len(parts)<2 or len(parts)>15:
            raise ValueError('systemMenus: use a menu title and 1-14 items')
        rows=[]
        for item in parts[1:]:
            if item=='-':
                rows.append(('-','',False));continue
            title,sep,code=item.rpartition('=')
            if not sep or not code.isdigit() or not 160<=int(code)<=239 or not 1<=len(title)<=24 or int(code) in seen:
                raise ValueError('systemMenus: unique commands 160-239, labels 1-24 bytes')
            seen.add(int(code))
            # Open... and Save As... are the shared boxes. Save stays a
            # command: the program already has a name and writes the file.
            if title in ('Quit','Close'):action='close'
            elif title=='Open...':action='open:'+code
            elif title=='Save As...':action='save_as:'+code
            else:action='app:'+code
            rows.append((title,action,True))
        result.append((label,rows))
    width=sum(sum(FONT.get(c,FONT['?'])['advance'] for c in label)+20 for label,_rows in result)
    if width>580:raise ValueError('systemMenus: menu headings exceed the screen width')
    return result

def parse_finder_menus(spec):
    """Finder program menus. File, Edit, View, and Special, up to 12 items.

    The built-in desktop does not use this. Role 9 owns those four titles
    the way the Macintosh Finder owned them and the ROM drew them.
    """
    if not isinstance(spec,str) or len(spec)>512 or any(ord(c)<32 or ord(c)>126 for c in spec):
        raise ValueError('Finder menus need at most 512 printable ASCII bytes')
    want=('File','Edit','View','Special')
    parts=spec.split(';')
    if len(parts)!=4:raise ValueError('Finder menus need File, Edit, View, and Special')
    result=[];seen=set()
    for menu,title in zip(parts,want):
        items=menu.split('|')
        if items[0]!=title or not 2<=len(items)<=13:
            raise ValueError('Finder menus: '+title+' with 1 to 12 items')
        rows=[]
        for item in items[1:]:
            label,sep,code=item.rpartition('=')
            if not sep or not code.isdigit() or not 160<=int(code)<=191 or not 1<=len(label)<=24 or int(code) in seen:
                raise ValueError('Finder menus: unique commands 160-191')
            seen.add(int(code));rows.append((label,int(code)))
        result.append(rows)
    return result

class ClassicUI:
    def __init__(self):
        self.resources=None
        self.menu=0;self.menu_item=-1;self.dialog=None;self.files=[];self.file_top=0;self.selected=-1
        self.name='';self.name_selected=False;self.message='';self.buttons=0
        self.caret=0;self.caret_on=False;self.caret_hold=0;self.flash=0
        self.capture=False;self.drag=False;self.role=0;self.dirty=False
        self.hot=-1;self.armed=-1
        self.document='';self.can_undo=False;self.can_paste=False
        self.has_selection=False
        self.spec='';self.custom=[];self.finder=[];self.owned=False
        self.menu_enable=0xFFFFFFFF;self.menu_check=0
        self.bars=True
    def configure(self,role,spec):
        if role!=self.role:
            self.buttons=0;self.capture=False;self.drag=False;self.menu=0;self.menu_item=-1;self.dialog=None
            self.hot=-1;self.armed=-1
        self.role=role
        if spec!=self.spec:
            self.owned=False
            if role==9:
                self.finder=parse_finder_menus(spec) if spec else []
                self.custom=[]
            elif isinstance(spec,str) and spec.startswith('File|'):
                self.custom=parse_owned_menus(spec);self.finder=[];self.owned=True
            else:
                self.custom=parse_menus(spec);self.finder=[]
            self.spec=spec;self.menu=0;self.menu_item=-1
    def bar(self):
        extra=[m[0] for m in self.custom]
        if self.role==8 and 'Game' not in extra:extra.insert(0,'Game')
        if self.owned:
            labels=extra
        elif self.role==9:
            labels=['File','Edit','View','Special']
        else:
            labels=['File']+([] if self.role==8 else ['Edit','View'])+extra+['Special']
        x=30;out=[]
        for label in labels:
            shown=self.resources.translate(label) if self.resources and label in ('File','Edit','View','Special','Game') else label
            w=sum(FONT.get(c,FONT['?'])['advance'] for c in shown)+20
            out.append((x,x+w,label));x+=w
        return out
    @property
    def signature(self):
        return (self.menu,self.menu_item,self.dialog,tuple(self.files),self.file_top,self.selected,self.name,
                self.name_selected,self.caret,self.caret_on,self.flash,self.message,self.document,self.can_undo,self.can_paste,self.has_selection,self.role,self.spec,self.menu_enable,self.menu_check,self.hot)
    def _finder_rows(self,index):
        out=[]
        for label,code in self.finder[index]:
            bit=code-160
            enabled=bool((self.menu_enable>>bit)&1)
            shown=('* '+label) if (self.menu_check>>bit)&1 else label
            out.append((shown,'app:'+str(code),enabled))
        return out
    def rows(self,menu):
        if self.role==9 and self.finder and 1<=menu<=4:
            return self._finder_rows(menu-1)
        if self.owned:
            label=self.bar()[menu-1][2]
            for title,rows in self.custom:
                if label==title:return rows
            return []
        editable=self.role in (1,5)
        # Compile can save the opened program, or save it under a new name.
        can_save=editable or self.role==3
        label=self.bar()[menu-1][2]
        if label=='File':
            if self.role==8:return [('Quit','close',True)]
            # Every application leaves with Quit. The Finder's own File
            # menu (role 9) is not this list; it still says Close Window.
            return [('New','new',editable),('Open...','open',self.role in (1,2,3,5)),
                    ('Quit','close',True),('Save','save',can_save),('Save As...','save_as',can_save)]
        if label=='Edit':
            return [('Undo','undo',editable and self.can_undo),('Cut','cut',editable and self.has_selection),
                    ('Copy','copy',editable and self.has_selection),('Paste','paste',editable and self.can_paste),
                    ('Clear','clear',editable and self.has_selection),('Select All','select_all',editable)]
        if label=='View':return [('Page Up','page_up',self.role not in (3,7)),('Page Down','page_down',self.role not in (3,7))]
        for title,rows in self.custom:
            if label==title:return rows
        if label=='Game':return [('Restart','restart_app',True)]
        return [(x,'tool:'+x,self.role!=3) for x in ('Terminal','Editor','Reader','Compile','Utility','Note','Help','Restart')]
    def show_files(self,names):
        self.menu=0;self.dialog='open';self.files=list(names);self.file_top=0;self.selected=0 if names else -1
        self.hot=-1;self.armed=-1
    def show_name(self,name):
        # A made-up UNTITLED name is not a document. Leave the field empty
        # so the first keystroke is the name, not a character appended to
        # a placeholder. A real name stays, unselected, so Backspace
        # deletes one character. Selecting the whole name made every
        # keystroke erase it.
        shown=str(name or '').strip()
        if shown.upper() in ('UNTITLED.TXT','UNTITLED.HTM','UNTITLED.JS','UNTITLED'):
            shown=''
        self.menu=0;self.dialog='save_as';self.name=shown[:12];self.name_selected=False;self.message=''
        # The line is visible the moment the box opens, then it blinks.
        self.caret=len(self.name);self.caret_on=True;self.caret_hold=2
        self.hot=-1;self.armed=-1
    def tick(self):
        """One GUI frame. The caret blinks twice a second, like the Macintosh."""
        import time
        if self.flash:self.flash-=1
        if self.caret_hold:
            self.caret_hold-=1;self.caret_on=True;return
        self.caret_on=self.dialog=='save_as' and (int(time.monotonic()*2)&1)==0
    def _caret_from_x(self,x):
        """Nearest gap between letters. A click lands the caret there."""
        pen=158
        for i,ch in enumerate(self.name):
            adv=FONT.get(ch,FONT['?'])['advance']
            if x<pen+adv/2:return i
            pen+=adv
        return len(self.name)
    def _dialog_bounds(self):
        if self.dialog=='open':return (110,76,420,200)
        return (132,112,376,164)
    def _default_kind(self):
        """The button Return presses. It is the one with the extra outline."""
        return {'save_as':'save','open':'open','changes':'save','replace':'replace','message':'ok'}.get(self.dialog)
    def _dialog_buttons(self):
        rows=self._base_dialog_buttons()
        if self.resources:
            return [(*self.resources.buttons[self.dialog][i],label,kind) for i,(_,_,_,label,kind) in enumerate(rows)]
        return rows
    def _base_dialog_buttons(self):
        d=self.dialog
        if d=='open':return [(386,244,112,'Open','open'),(260,244,112,'Cancel','cancel')]
        if d=='save_as':return [(152,214,84,'Save','save'),(252,214,96,'Cancel','cancel')]
        if d=='replace':return [(376,234,110,'Replace','replace'),(250,234,110,'Cancel','cancel')]
        if d=='changes':return [(144,234,100,'Save','save'),(266,234,100,'Discard','discard'),(388,234,100,'Cancel','cancel')]
        if d=='message':return [(270,234,100,'OK','ok')]
        return []
    def _press_button(self,kind):
        """A dialog button runs when the pointer is still on it at mouse-up."""
        if kind in ('cancel','ok'):
            self.dialog=None;return []
        if self.dialog=='open' and kind=='open' and self.selected>=0:
            return [('open_file',self.files[self.selected])]
        if self.dialog=='save_as' and kind=='save':return [('save_name',self.name)]
        if self.dialog=='replace' and kind=='replace':return [('replace',)]
        if self.dialog=='changes' and kind=='save':return [('changes','save')]
        if self.dialog=='changes' and kind=='discard':return [('changes','discard')]
        return []
    def text_key(self,code,text):
        if self.dialog!='save_as':return []
        if code==27:self.dialog=None;return []
        if code==13:return [('save_name',self.name)]
        n=self.name;i=max(0,min(self.caret,len(n)))
        if code in (8,127):
            if i>0:self.name=n[:i-1]+n[i:];self.caret=i-1
        elif code==46 and len(text)!=1:
            if i<len(n):self.name=n[:i]+n[i+1:]
        elif code==37:self.caret=max(0,i-1)
        elif code==39:self.caret=min(len(n),i+1)
        elif len(text)==1 and 32<=ord(text)<127 and len(n)<12:
            self.name=n[:i]+text+n[i:];self.caret=i+1
        self.name_selected=False;self.caret_on=True;self.caret_hold=2
        return []
    def pointer(self,x,y,buttons,role,dirty):
        self.role=role;self.dirty=dirty;down=bool(buttons&1 and not self.buttons&1);up=bool(self.buttons&1 and not buttons&1)
        self.buttons=buttons;events=[]
        if self.drag:
            if up:self.drag=False
            return False,events
        # Ship menu and on-screen keyboard are handled by SystemMenu.
        if not self.dialog and x<30 and y<22:return False,events
        if self.dialog:
            # A button inverts while the pointer is held on it, and runs on release.
            # Letting go off the button does nothing. The name field is not a button.
            if self.dialog=='save_as' and y>=296:
                self.hot=-1;self.armed=-1;return False,events
            if self.resources:
                dx,dy=self.resources.offset(self.dialog);x-=dx;y-=dy
            specs=self._dialog_buttons()
            hit=next((i for i,(bx,by,bw,label,kind) in enumerate(specs) if bx<=x<bx+bw and by<=y<by+26),-1)
            if down:
                self.armed=hit
                if self.dialog=='open':
                    if 134<=x<484 and 112<=y<224:
                        i=self.file_top+(y-112)//16
                        if i<len(self.files):self.selected=i
                    elif 486<=x<508 and 112<=y<224:
                        self.file_top=max(0,self.file_top-1) if y<168 else min(max(0,len(self.files)-7),self.file_top+1)
                elif self.dialog=='save_as' and 154<=x<364 and 150<=y<172:
                    # Land the caret between letters. Do not select the name.
                    self.caret=self._caret_from_x(x);self.caret_on=True;self.caret_hold=2
                bx,by,bw,bh=self._dialog_bounds()
                if not (bx<=x<bx+bw and by<=y<by+bh):
                    # A click outside a modal box flashes the default button.
                    self.flash=8
            self.hot=hit if buttons&1 and hit>=0 and hit==self.armed else -1
            if up and self.armed>=0 and hit==self.armed:
                events=self._press_button(specs[hit][4]);self.armed=-1;self.hot=-1
            elif up:self.armed=-1
            return True,events
        if self.capture:
            if up:self.capture=False
            if not down:return True,events
        if self.menu:
            # Macintosh MenuSelect: the title stays inverted, the row under
            # the pointer inverts, and dragging across the bar switches menus.
            # The command runs when the button is released on an enabled row.
            bar=self.bar()
            if buttons&1 and y<22:
                hit=next((i+1 for i,(a,b,label) in enumerate(bar) if a<=x<b),0)
                if hit and hit!=self.menu:self.menu=hit;self.menu_item=-1
            mx=min(426,bar[self.menu-1][0]);rows=self.rows(self.menu)
            if 26<=y and mx<=x<mx+212:
                row=(y-26)//21
                self.menu_item=row if 0<=row<len(rows) and rows[row][2] else -1
            elif self.menu_item!=-1:self.menu_item=-1
            if up:
                if self.menu_item>=0:
                    events=[('menu',rows[self.menu_item][1])]
                    self.menu=0;self.menu_item=-1
                elif not (y<22 and bar[self.menu-1][0]<=x<bar[self.menu-1][1]):
                    self.menu=0;self.menu_item=-1
            return True,events
        if y<22:
            if down:self.menu=next((i+1 for i,(a,b,label) in enumerate(self.bar()) if a<=x<b),0)
            return True,events
        if role in (8,9):return False,events
        body=24<=x<600 and 88<=y<432
        if down and body:self.drag=True;return False,events
        if body:return False,events
        if down:
            self.capture=True
            if 16<=x<30 and 40<=y<54:events=[('menu','close')]
            elif self.bars and 600<=x<620 and 88<=y<432:
                code=128 if y<108 else 129 if y>=414 else 130 if y<260 else 131
                events=[('key',code,0,True),('key',code,0,False)]
            elif role in (1,5) and 434<=y<453:
                code=132 if 10<=x<28 else 133 if 582<=x<600 else 0
                if code:events=[('key',code,0,True),('key',code,0,False)]
        return True,events
    def decorate(self,rgba,paint_text):
        dx=dy=0
        def rect(x,y,w,h,c):
            x+=dx;y+=dy
            if w<=0 or h<=0:return
            row=bytes((*c,255))*w
            for py in range(y,y+h):rgba[(py*640+x)*4:(py*640+x+w)*4]=row
        def rfill(x,y,w,h,c):
            # Round rectangle. Corner inset matches a Macintosh button.
            cut=(5,3,2,1,1) if not self.resources or self.resources.rounded else ()
            for py in range(h):
                edge=py if py<h-1-py else h-1-py
                inset=cut[edge] if edge<len(cut) else 0
                if inset*2<w:rect(x+inset,y+py,w-2*inset,1,c)
        def text(x,y,s,c=(0,0,0),literal=False):
            if self.resources and not literal:s=self.resources.translate(s)
            paint_text(rgba,640,x+dx,y+dy,s,c)
        white=(255,255,255);black=(0,0,0);grey=(219,219,219)
        rect(30,0,610,21,white)
        for i,(x,end,label) in enumerate(self.bar(),1):
            own=self.owned or label not in ('File','Edit','View','Special','Game')
            if self.menu==i:
                rect(x,0,end-x,21,(0,0,0));text(x+4,3,label,(255,255,255),literal=own)
            else:text(x+4,3,label,literal=own)
        if self.menu:
            mx=min(426,self.bar()[self.menu-1][0]);rows=self.rows(self.menu);h=len(rows)*21+8
            rect(mx+2,24,212,h,black);rect(mx,22,212,h,black);rect(mx+1,23,210,h-2,white)
            for i,(label,action,enabled) in enumerate(rows):
                hot=i==self.menu_item and enabled
                ink=white if hot else black if enabled else (145,145,145)
                if hot:rect(mx+2,26+i*21,208,20,black)
                if label=='-':
                    rect(mx+8,26+i*21+10,190,1,ink);continue
                checked=False
                if isinstance(action,str) and action.startswith('app:'):
                    bit=int(action[4:])-160
                    if 0<=bit<31 and (self.menu_check>>bit)&1:checked=True
                if checked:
                    # A small check, the mark MacPaint puts on the current choice.
                    cx,cy=mx+8,30+i*21
                    rect(cx,cy+3,1,2,ink);rect(cx+1,cy+4,1,2,ink);rect(cx+2,cy+5,1,2,ink)
                    rect(cx+3,cy+4,1,2,ink);rect(cx+4,cy+3,1,2,ink);rect(cx+5,cy+2,1,2,ink);rect(cx+6,cy+1,1,2,ink)
                text(mx+(20 if checked else 10),27+i*21,label,ink,literal=self.owned or self.role==9 or str(action).startswith("app:"))
        if not self.dialog:return
        if self.resources:dx,dy=self.resources.offset(self.dialog)
        if self.dialog=='open':
            rect(110,76,420,200,black);rect(112,78,416,196,white);text(280,84,'Open')
            rect(132,110,378,116,black);rect(134,112,374,112,white)
            for row,name in enumerate(self.files[self.file_top:self.file_top+7]):
                selected=self.selected==self.file_top+row
                if selected:rect(134,112+row*16,350,16,(23,113,255))
                text(142,112+row*16,name,white if selected else black,literal=True)
            if not self.files:text(142,144,'No matching files on disk.',(100,100,100))
            text(490,116,'^');text(490,204,'v')
        elif self.dialog=='save_as':
            # Macintosh save box: double frame, name on the left, Save then Cancel.
            # No Eject, Drive, or radio buttons. This machine has one disk.
            rect(136,116,376,164,black)
            rect(132,112,376,164,black);rect(133,113,374,162,white)
            rect(135,115,370,158,black);rect(136,116,368,156,white)
            text(152,124,'Save document as:')
            rect(152,148,214,26,black);rect(154,150,210,22,white)
            text(158,152,self.name,black,literal=True)
            if self.caret_on:
                # One-pixel insertion line, after the letters before the caret.
                cx=158+sum(FONT.get(ch,FONT['?'])['advance'] for ch in self.name[:self.caret])
                rect(min(360,cx),154,1,12,black)
            text(152,182,self.message or 'Use a short disk filename.',(100,100,100))
        else:
            rect(132,112,376,164,black);rect(134,114,372,160,white)
            if self.dialog=='replace':
                text(154,136,'Replace the existing file?');text(154,166,self.name,literal=True)
            elif self.dialog=='changes':
                text(154,136,'Save changes before closing?');text(154,166,self.document,literal=True)
            else:
                text(154,136,self.message)
        default=self._default_kind()
        for i,(x,y,w,label,kind) in enumerate(self._dialog_buttons()):
            # Held button inverts. Return's button has the extra outline.
            hot=i==self.hot or (kind==default and self.flash)
            if kind==default and (not self.resources or self.resources.outline):
                rfill(x-4,y-4,w+8,34,black);rfill(x-2,y-2,w+4,30,white)
            rfill(x,y,w,26,black);rfill(x+1,y+1,w-2,24,black if hot else white)
            shown=self.resources.translate(label) if self.resources else label
            text(x+max(5,(w-sum(FONT[c]['advance'] for c in shown))//2),y+4,label,white if hot else black)
