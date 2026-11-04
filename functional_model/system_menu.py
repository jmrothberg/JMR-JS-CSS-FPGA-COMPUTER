"""Always available system menu and mouse-operated US keyboard.

Reference for jmr_system_menu and the registered RTL overlay renderer.
Only UI geometry consumes pointer input; program input remains ordinary
keyboard/mouse events through the shared machine engines.
"""
from .desktop import FONT,ROOT
import json
SHIP=json.loads((ROOT/"assets/desktop/enterprise-menu.json").read_text())
# legend, browser keyCode, plain ASCII, shifted ASCII
KEYS=[]
def _key(legend,code,plain=0,shifted=None):
    if isinstance(plain,str):plain=ord(plain)
    if isinstance(shifted,str):shifted=ord(shifted)
    KEYS.append((legend,code,plain,plain if shifted is None else shifted))
_key('Esc',27,27)
for i,(a,b) in enumerate(zip('1234567890','!@#$%^&*()')):_key(a,49+i if i<9 else 48,a,b)
_key('-',189,'-','_');_key('=',187,'=','+');_key('Back',8,8)
_key('Tab',9,9)
for a in 'QWERTYUIOP':_key(a,ord(a),a.lower(),a)
_key('[',219,'[','{');_key(']',221,']','}');_key('\\',220,'\\','|')
_key('Caps',20)
for a in 'ASDFGHJKL':_key(a,ord(a),a.lower(),a)
_key(';',186,';',':');_key("'",222,"'",'"');_key('Enter',13,13);_key('Del',46,127)
_key('Shift',16)
for a in 'ZXCVBNM':_key(a,ord(a),a.lower(),a)
_key(',',188,',','<');_key('.',190,'.','>');_key('/',191,'/','?')
_key('Up',38);_key('Ctrl',17);_key('Alt',18)
_key('Space',32,' ');_key('Left',37,17);_key('Down',40);_key('Right',39,18)
for i in range(10):_key('F'+str(i+1),112+i)
assert len(KEYS)==70


def key_value(index,shift=False,caps=False):
    legend,code,plain,upper=KEYS[index]
    text=upper if shift else plain
    if 65<=code<=90:text=upper if bool(shift)^bool(caps) else plain
    if shift and len(legend)==1 and not 65<=code<=90 and 32<=plain<127:
        legend=chr(upper)
    if shift and index>=68:code+=2;legend='F'+str(code-111)
    return legend,code,text


class SystemMenu:
    def __init__(self):
        self.open=False;self.apple_row=-1;self.keyboard=False;self.about=False;self.about_hot=False;self.shift=False;self.caps=False
        self.ctrl=False;self.alt=False;self.pressed=127;self.buttons=0
        self.held=None;self.guest_drag=False;self.x=320;self.y=240
        self.hold_keys=False;self.latched={}
        self.window=(0,0,0,0)
        from .classic_ui import ClassicUI
        self.classic=ClassicUI()
        self.document_name=""
        self.source_lines=()
        self.application_title='Finder'
        self.application_description='Manage programs and documents.'

    def release_keys(self):
        """Release OSK state when leaving any app through File/close controls."""
        events=[]
        for code,text in self.latched.values():events.append(('key',code,0,False))
        self.latched.clear();self.hold_keys=False
        if self.held is not None:
            events.append(('key',self.held[0],0,False));self.held=None;self.pressed=127
        for attr,code in (('shift',16),('ctrl',17),('alt',18)):
            if getattr(self,attr):events.append(('key',code,0,False));setattr(self,attr,False)
        return events

    def pointer(self,x,y,buttons):
        # A drag belongs to the app until its release, even above the bar.
        # Otherwise chrome could swallow mouseup and leave fire/selection held.
        if self.guest_drag:
            self.classic.buttons=buttons
            if not buttons&1:self.classic.drag=False
        if self.window[0] and not self.open and not self.about and not self.guest_drag:
            if x<30 and y<22 and buttons&1:self.classic.menu=0
            if not (self.keyboard and y>=296 and not self.classic.dialog):
                consumed,actions=self.classic.pointer(x,y,buttons,self.window[0],bool(self.window[3]&1))
                if consumed:
                    self.x,self.y=x,y;self.buttons=buttons
                    return True,actions
        down=bool(buttons&1 and not self.buttons&1)
        up=bool(self.buttons&1 and not buttons&1)
        self.x,self.y=x,y
        # About is the top row, Keyboard the bottom. Same invert as the other menus.
        labels=self._apple_labels()
        if self.open and 0<=x<190 and 26<=y<26+len(labels)*21:
            self.apple_row=(y-26)//21
        else:self.apple_row=-1
        actions=[]
        role=self.window[0]
        chrome=role not in (0,8,9) and not (24<=x<600 and 88<=y<432)
        consumed=(chrome or self.about or self.open or (x<30 and y<22) or (self.keyboard and y>=296) or self.held is not None)
        if self.guest_drag:consumed=False
        if down and not consumed:self.guest_drag=True
        if up:self.guest_drag=False
        if self.held is not None and up:
            code,text=self.held;actions.append(('key',code,0,False));self.held=None;self.pressed=127
        if self.about:
            inside=273<=x<369 and 269<=y<296
            self.about_hot=bool(inside and buttons&1)
            if up and inside:
                self.about=False;self.about_hot=False
        if consumed and up and self.open:
            labels=self._apple_labels()
            row=(y-26)//21
            if x<190 and 0<=row<len(labels):
                self.open=False
                name=labels[row]
                if name=='About':self.about=True
                elif name=='Keyboard':
                    self.keyboard=not self.keyboard
                    actions.append(('keyboard',self.keyboard))
                else:actions.append(('menu','tool:'+name))
            elif not (x<30 and y<22):self.open=False
        if consumed and down:
            if self.open and x<30 and y<22:self.open=False
            elif not self.open and x<30 and y<22:self.open=True
            elif self.keyboard and y>=296:
                if x>=600 and y<313:self.keyboard=False;actions.append(('keyboard',False))
                elif 420<=x<585 and y<313:
                    self.hold_keys=not self.hold_keys
                    if not self.hold_keys:
                        for code,text in self.latched.values():actions.append(('key',code,0,False))
                        self.latched.clear()
                elif 12<=x<628 and 314<=y<479:
                    row=(y-314)//33;col=(x-12)//44
                    if row<5 and (y-314)%33<29:
                        index=row*14+col;legend,code,text=key_value(index,self.shift,self.caps)
                        if index in (42,54,55):
                            attr={42:'shift',54:'ctrl',55:'alt'}[index]
                            value=not getattr(self,attr);setattr(self,attr,value)
                            actions.append(('key',code,0,value))
                        elif self.hold_keys and index!=28:
                            if index in self.latched:
                                code,text=self.latched.pop(index);actions.append(('key',code,0,False))
                            else:
                                self.latched[index]=(code,text);actions.append(('key',code,text,True))
                        else:
                            if index==28:self.caps=not self.caps
                            self.held=(code,text);self.pressed=index
                            actions.append(('key',code,text,True))
        self.buttons=buttons
        if any(action[0]=='quit' or (action[0]=='keyboard' and not action[1]) for action in actions):
            for code,text in self.latched.values():actions.append(('key',code,0,False))
            self.latched.clear();self.hold_keys=False
            for attr,code in (('shift',16),('ctrl',17),('alt',18)):
                if getattr(self,attr):actions.append(('key',code,0,False));setattr(self,attr,False)
        if self.classic.dialog=='save_as':
            filtered=[]
            for action in actions:
                if action[0]=='key':
                    if action[3]:filtered+=self.classic.text_key(action[1],chr(action[2]) if 32<=action[2]<127 else '')
                else:filtered.append(action)
            actions=filtered
        return bool(consumed),actions

    def _text(self,rgba,width,x,y,text,colour):
        for char in text:
            font=getattr(getattr(self,'resources',None),'font',FONT)
            g=font.get(char,font['?'])
            for row,bits in enumerate(g['rows']):
                for col,bit in enumerate(bits):
                    if bit=='1':
                        px=x+col+g['offset'];py=y+row
                        if 0<=px<width and 0<=py<len(rgba)//(width*4):
                            i=(py*width+px)*4;rgba[i:i+4]=bytes((*colour,255))
            x+=g['advance']

    def _apple_labels(self):
        # Role 9 is the Finder program. Desk accessories hang off the
        # apple menu, the way they did on the original Macintosh.
        if self.window[0]==9:return ('About','Keyboard','Note','Help','Utility')
        return ('About','Keyboard')

    def overlays(self):
        signature=(self.open,self.apple_row,self.keyboard,self.about,self.about_hot,self.shift,self.caps,self.ctrl,self.alt,self.pressed,self.hold_keys,tuple(sorted(self.latched)),self.window,self.document_name,getattr(self,'document_title',''),len(getattr(self,'source_lines',())),self.application_title,self.application_description,self.classic.signature)
        if getattr(self,'_overlay_signature',None)==signature:return self._overlay_cache
        apple_n=len(self._apple_labels())
        width,height=190,(26+apple_n*21+8 if self.open and self.window[0]==9 else 72 if self.open else 22)
        rgba=bytearray(width*height*4)
        for y in range(height):
            for x in range(width):
                if x<30 and y<22:
                    c=(0,0,0) if y==21 else (255,255,255)
                elif self.open and y>=22:
                    c=(0,0,0) if x in (0,189) or y in (22,height-1) else (255,255,255)
                else:continue
                rgba[(y*width+x)*4:(y*width+x+1)*4]=bytes((*c,255))
        for sy,bits in enumerate(SHIP['rows']):
            for sx in range(SHIP['width']):
                if bits&(1<<(SHIP['width']-1-sx)):
                    i=((SHIP['y']+sy)*width+SHIP['x']+sx)*4;rgba[i:i+4]=bytes((0,0,0,255))
        if self.open:
            labels=self._apple_labels()
            if self.window[0]==9:
                if 0<=self.apple_row<len(labels):
                    y0=24+self.apple_row*21
                    for py in range(y0,y0+20):
                        rgba[(py*width+1)*4:((py*width)+189)*4]=bytes((0,0,0,255))*188
                for i,label in enumerate(labels):
                    self._text(rgba,width,8,26+i*21,label,(255,255,255) if self.apple_row==i else (0,0,0))
            else:
                if self.apple_row==0:
                    for py in range(24,46):
                        rgba[(py*width+1)*4:((py*width)+189)*4]=bytes((0,0,0,255))*188
                elif self.apple_row==1:
                    for py in range(47,70):
                        rgba[(py*width+1)*4:((py*width)+189)*4]=bytes((0,0,0,255))*188
                self._text(rgba,width,8,26,'About',(255,255,255) if self.apple_row==0 else (0,0,0))
                self._text(rgba,width,8,47,'Keyboard',(255,255,255) if self.apple_row==1 else (0,0,0))
        out=[(0,0,width,height,bytes(rgba))]
        if self.keyboard:
            rgba=bytearray(bytes((219,219,219,255))*640*184)
            self._text(rgba,640,12,1,'Keyboard',(0,0,0));self._text(rgba,640,607,1,'X',(0,0,0))
            self._text(rgba,640,448,1,'Hold keys',(0,0,0))
            for py in range(3,14):
                for px in range(428,439):
                    colour=0 if px in (428,438) or py in (3,13) or self.hold_keys else 255
                    at=(py*640+px)*4;rgba[at:at+4]=bytes((colour,colour,colour,255))
            for i in range(70):
                bx,by=12+(i%14)*44,18+(i//14)*33
                active=i==self.pressed or i in self.latched or (i==42 and self.shift) or (i==28 and self.caps) or (i==54 and self.ctrl) or (i==55 and self.alt)
                for row in range(29):
                    for col in range(40):
                        c=(0,0,0) if row in (0,28) or col in (0,39) else (23,113,255) if active else (255,255,255)
                        p=((by+row)*640+bx+col)*4;rgba[p:p+4]=bytes((*c,255))
                legend,_,_=key_value(i,self.shift,self.caps)
                # Five-letter legends fit at native size in the 40px keys.
                self._text(rgba,640,bx+3,by+6,legend,(255,255,255) if active else (0,0,0))
            out.append((0,296,640,184,bytes(rgba)))
        if self.about:
            rgba=bytearray(bytes((255,255,255,255))*375*153)
            for y in range(153):
                for x in range(375):
                    colour=None
                    if x<2 or x>=373 or y<2 or y>=151:colour=(0,0,0)
                    elif 140<=x<236 and 115<=y<142:
                        edge=x in (140,235) or y in (115,141)
                        colour=(0,0,0) if edge or self.about_hot else (219,219,219)
                    if colour is not None:
                        i=(y*375+x)*4;rgba[i:i+4]=bytes((*colour,255))
            for x,y,text in [(20,12,'JMR Enterprises'),(20,44,self.application_title),
                             (20,70,self.application_description),(175,121,'OK')]:
                ink=(255,255,255) if self.about_hot and text=='OK' else (0,0,0)
                if getattr(self,'resources',None) and y in (12,121):text=self.resources.label(160 if y==12 else 145)
                self._text(rgba,375,x,y,text,ink)
            out.append((133,154,375,153,bytes(rgba)))
        if self.window[0]:
            from .system_window import window_pixels
            # Role 9 draws its own windows. The toolbox keeps the menu bar.
            if self.window[0]==9:
                full=bytearray(640*480*4)
                full[:640*22*4]=bytes((255,255,255,255))*640*22
                full[640*21*4:640*22*4]=bytes((0,0,0,255))*640
            elif self.window[0]==8:
                full=bytearray(640*480*4)
            else:
                full=window_pixels(self.window,self._text,self.document_name,getattr(self,'source_lines',()),getattr(self,'resources',None),getattr(self,'document_title',''),getattr(self,'scroll_bars',True))
            if self.window[0]==8:
                full[:640*22*4]=bytes((255,255,255,255))*640*22
                full[640*21*4:640*22*4]=bytes((0,0,0,255))*640
            self.classic.document=self.document_name
            self.classic.role=self.window[0]
            self.classic.decorate(full,self._text)
            for ox,oy,w,h,pixels in out:
                for py in range(h):
                    for px in range(w):
                        src=(py*w+px)*4
                        if pixels[src+3]:
                            dst=((oy+py)*640+ox+px)*4;full[dst:dst+4]=pixels[src:src+4]
            out=[(0,0,640,480,bytes(full))]
        self._overlay_signature=signature;self._overlay_cache=out
        return out
