"""Shared system-owned window chrome. Four bytes; no document/framebuffer copy.

Context properties select role, normalized vertical/horizontal scroll, and
modified flag. Content stays in the existing application or console surface.
"""
from .desktop import FONT
WINDOW_FIELDS=('systemWindow','windowScroll','windowScrollX','windowDirty')
WINDOW_LABELS={81:'Editor',82:'Reader',83:'Compiler',84:'Utility',85:'Note',86:'System Tool',87:'Terminal',
 88:'Save',89:'Click to place cursor',90:'Modified',91:'Click page or arrows to scroll',
 92:'Reading source / artwork',93:'Compiling',94:'Writing program',95:'Files on disk',
 96:'System application',97:'Type a command',98:'^',99:'v',100:'<',101:'>',102:'Close window to return',103:'Decoding artwork',104:'Linking'}

def toolbar_label(role,flags):
    if role in (1,5):return 89
    if role==2:return 91
    if role==3:return {1:103,2:93,3:104,4:94}.get((flags>>4)&7,92)
    return {4:95,6:96,7:97}.get(role,96)

def window_pixels(state,paint_text,title="",lines=(),resources=None):
    def label(i):return resources.label(i) if resources else WINDOW_LABELS.get(i,'System Tool')
    role,sy,sx,flags=state
    rgba=bytearray(bytes((85,221,255,255))*640*480)
    def rect(x,y,w,h,c):
        row=bytes(c)*w
        for py in range(y,y+h):rgba[(py*640+x)*4:(py*640+x+w)*4]=row
    black=(0,0,0,255);white=(255,255,255,255);grey=(221,221,221,255)
    rect(0,0,640,22,white);rect(0,21,640,1,black)
    rect(8,34,612,420,black);rect(9,35,610,418,white)
    for y in range(40,56,3):rect(32,y,206,1,black);rect(402,y,211,1,black)
    rect(10,60,608,1,black);rect(16,40,14,14,black);rect(17,41,12,12,white)
    # Role 3 shows the program that was opened. A clear hole was a black box
    # because the compiler canvas behind it is empty.
    if role==3:
        rect(24,88,576,344,white)
        shown=list(lines or [])
        if not shown:paint_text(rgba,640,32,96,'Open an HTML program.',black)
        else:
            for row,line in enumerate(shown[:20]):
                paint_text(rgba,640,32,96+row*16,(line or '')[:72],black)
    else:rect(24,88,576,344,(0,0,0,0))
    rect(600,88,1,344,black);rect(601,108,17,306,grey)
    rect(601,107,17,1,black);rect(601,414,17,1,black)
    thumb=109+(sy*280//256);rect(601,thumb,17,18,black);rect(602,thumb+1,15,16,white)
    rect(10,433,608,1,black)
    paint_text(rgba,640,34,3,label(80+role),(0,0,0))
    caption=title if title and role in (1,2,5) else label(80+role)
    caption=caption[:24]
    cx=max(240,(640-sum(FONT.get(c,FONT['?'])['advance'] for c in caption))//2)
    paint_text(rgba,640,cx,38,caption,(0,0,0))
    paint_text(rgba,640,24,66,label(toolbar_label(role,flags)),(0,0,0))
    paint_text(rgba,640,604,90,'^',(0,0,0));paint_text(rgba,640,604,415,'v',(0,0,0))
    if role in (1,5):
        if flags&1:paint_text(rgba,640,480,66,'Modified',(0,0,0))
        rect(28,434,554,19,grey);rect(27,434,1,19,black);rect(582,434,1,19,black)
        tx=29+(sx*520//256);rect(tx,434,32,19,black);rect(tx+1,435,30,17,white)
        paint_text(rgba,640,13,435,'<',(0,0,0));paint_text(rgba,640,586,435,'>',(0,0,0))
    else:paint_text(rgba,640,24,435,'Close window to return',(0,0,0))
    return rgba
