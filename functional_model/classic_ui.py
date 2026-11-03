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

class ClassicUI:
    def __init__(self):
        self.menu=0;self.dialog=None;self.files=[];self.file_top=0;self.selected=-1
        self.name='';self.name_selected=True;self.message='';self.buttons=0
        self.capture=False;self.drag=False;self.role=0;self.dirty=False
        self.document='';self.can_undo=False;self.can_paste=False
        self.has_selection=False
        self.spec='';self.custom=[]
    def configure(self,role,spec):
        if role!=self.role:
            self.buttons=0;self.capture=False;self.drag=False;self.menu=0;self.dialog=None
        self.role=role
        if spec!=self.spec:
            self.custom=parse_menus(spec);self.spec=spec;self.menu=0
    def bar(self):
        extra=[m[0] for m in self.custom]
        if self.role==8 and 'Game' not in extra:extra.insert(0,'Game')
        labels=['File']+([] if self.role==8 else ['Edit','View'])+extra+['Special']
        x=30;out=[]
        for label in labels:
            w=sum(FONT.get(c,FONT['?'])['advance'] for c in label)+20
            out.append((x,x+w,label));x+=w
        return out
    @property
    def signature(self):
        return (self.menu,self.dialog,tuple(self.files),self.file_top,self.selected,self.name,
                self.name_selected,self.message,self.document,self.can_undo,self.can_paste,self.has_selection,self.role,self.spec)
    def rows(self,menu):
        editable=self.role in (1,5)
        label=self.bar()[menu-1][2]
        if label=='File':
            if self.role==8:return [('Quit','close',True)]
            return [('New','new',editable),('Open...','open',self.role in (1,2,5)),
                    ('Close','close',True),('Save','save',editable),('Save As...','save_as',editable)]
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
    def show_name(self,name):
        self.menu=0;self.dialog='save_as';self.name=name;self.name_selected=True;self.message=''
    def text_key(self,code,text):
        if self.dialog!='save_as':return []
        if code==27:self.dialog=None;return []
        if code==13:return [('save_name',self.name)]
        if code in (8,127) or (code==46 and len(text)!=1):
            self.name='' if self.name_selected else self.name[:-1];self.name_selected=False
        elif len(text)==1 and 32<=ord(text)<127:
            if self.name_selected:self.name=''
            if len(self.name)<12:self.name+=text
            self.name_selected=False
        return []
    def pointer(self,x,y,buttons,role,dirty):
        self.role=role;self.dirty=dirty;down=bool(buttons&1 and not self.buttons&1);up=bool(self.buttons&1 and not buttons&1)
        self.buttons=buttons;events=[]
        if self.drag:
            if up:self.drag=False
            return False,events
        if self.capture:
            if up:self.capture=False
            if not down:return True,events
        # Ship menu and on-screen keyboard are handled by SystemMenu.
        if not self.dialog and x<30 and y<22:return False,events
        if self.dialog:
            # Let the keyboard receive pointer samples under a Save As dialog.
            if self.dialog=='save_as' and y>=296:return False,events
            if not down:return True,events
            self.capture=True
            if self.dialog=='open':
                if 134<=x<484 and 112<=y<224:
                    i=self.file_top+(y-112)//16
                    if i<len(self.files):self.selected=i
                elif 486<=x<508 and 112<=y<224:
                    self.file_top=max(0,self.file_top-1) if y<168 else min(max(0,len(self.files)-7),self.file_top+1)
                elif 386<=x<498 and 244<=y<268 and self.selected>=0:events=[('open_file',self.files[self.selected])]
                elif 260<=x<372 and 244<=y<268:self.dialog=None
            elif self.dialog=='save_as':
                if 376<=x<486 and 234<=y<260:events=[('save_name',self.name)]
                elif 250<=x<360 and 234<=y<260:self.dialog=None
                elif 152<=x<487 and 158<=y<183:self.name_selected=True
            elif self.dialog=='replace':
                if 376<=x<486 and 234<=y<260:events=[('replace',)]
                elif 250<=x<360 and 234<=y<260:self.dialog=None
            elif self.dialog=='changes':
                if 144<=x<244 and 234<=y<260:events=[('changes','save')]
                elif 266<=x<366 and 234<=y<260:events=[('changes','discard')]
                elif 388<=x<488 and 234<=y<260:self.dialog=None
            elif self.dialog=='message':
                if 270<=x<370 and 234<=y<260:self.dialog=None
            return True,events
        if self.menu:
            if down:
                self.capture=True;m=self.menu;self.menu=0;mx=min(426,self.bar()[m-1][0])
                row=(y-26)//21;rows=self.rows(m)
                if 26<=y and mx<=x<mx+212 and 0<=row<len(rows) and rows[row][2]:events=[('menu',rows[row][1])]
            return True,events
        if y<22:
            if down:
                self.capture=True
                self.menu=next((i+1 for i,(a,b,label) in enumerate(self.bar()) if a<=x<b),0)
            return True,events
        if role==8:return False,events
        body=24<=x<600 and 88<=y<432
        if down and body:self.drag=True;return False,events
        if body:return False,events
        if down:
            self.capture=True
            if 16<=x<30 and 40<=y<54:events=[('menu','close')]
            elif 600<=x<620 and 88<=y<432:
                code=128 if y<108 else 129 if y>=414 else 130 if y<260 else 131
                events=[('key',code,0,True),('key',code,0,False)]
            elif role in (1,5) and 434<=y<453:
                code=132 if 10<=x<28 else 133 if 582<=x<600 else 0
                if code:events=[('key',code,0,True),('key',code,0,False)]
        return True,events
    def decorate(self,rgba,paint_text):
        def rect(x,y,w,h,c):
            row=bytes((*c,255))*w
            for py in range(y,y+h):rgba[(py*640+x)*4:(py*640+x+w)*4]=row
        def text(x,y,s,c=(0,0,0)):paint_text(rgba,640,x,y,s,c)
        white=(255,255,255);black=(0,0,0);grey=(219,219,219)
        rect(30,0,610,21,white)
        for x,end,label in self.bar():text(x+4,3,label)
        if self.menu:
            mx=min(426,self.bar()[self.menu-1][0]);rows=self.rows(self.menu);h=len(rows)*21+8
            rect(mx+2,24,212,h,black);rect(mx,22,212,h,black);rect(mx+1,23,210,h-2,white)
            for i,(label,action,enabled) in enumerate(rows):text(mx+10,27+i*21,label,black if enabled else (145,145,145))
        if not self.dialog:return
        if self.dialog=='open':
            rect(110,76,420,200,black);rect(112,78,416,196,white);text(280,84,'Open')
            rect(132,110,378,116,black);rect(134,112,374,112,white)
            for row,name in enumerate(self.files[self.file_top:self.file_top+7]):
                selected=self.selected==self.file_top+row
                if selected:rect(134,112+row*16,350,16,(23,113,255))
                text(142,112+row*16,name,white if selected else black)
            if not self.files:text(142,144,'No matching files on disk.',(100,100,100))
            text(490,116,'^');text(490,204,'v')
            buttons=((386,244,112,'Open'),(260,244,112,'Cancel'))
        else:
            rect(132,112,376,164,black);rect(134,114,372,160,white)
            if self.dialog=='save_as':
                text(154,124,'Save document as:');rect(150,156,339,29,black);rect(152,158,335,25,white)
                if self.name_selected:rect(154,161,min(330,max(8,len(self.name)*9)),18,(23,113,255))
                text(156,160,self.name,white if self.name_selected else black)
                text(154,194,self.message or 'Use a short disk filename.',(100,100,100))
                buttons=((376,234,110,'Save'),(250,234,110,'Cancel'))
            elif self.dialog=='replace':
                text(154,136,'Replace the existing file?');text(154,166,self.name)
                buttons=((376,234,110,'Replace'),(250,234,110,'Cancel'))
            elif self.dialog=='changes':
                text(154,136,'Save changes before closing?');text(154,166,self.document)
                buttons=((144,234,100,'Save'),(266,234,100,'Discard'),(388,234,100,'Cancel'))
            else:
                text(154,136,self.message);buttons=((270,234,100,'OK'),)
        for x,y,w,label in buttons:
            rect(x,y,w,26,black);rect(x+1,y+1,w-2,24,white)
            text(x+max(5,(w-sum(FONT[c]['advance'] for c in label))//2),y+4,label)
