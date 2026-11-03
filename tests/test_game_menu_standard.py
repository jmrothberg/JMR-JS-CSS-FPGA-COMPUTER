"""All real games use shared File/Quit, application About, and safe viewport input."""
from pathlib import Path
import re
import pytest
from functional_model.machine import Machine
from functional_model.jsb_format import ProgramImage,PROGRAM_CODE_WORDS
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text,encode_html_chunk

ROOT=Path(__file__).resolve().parents[1]
GAMES=tuple(p for p in sorted((ROOT/'storage').glob('*.HTML')) if re.search(r'\.systemWindow\s*=\s*8\b',p.read_text()))

@pytest.fixture(scope='module')
def images():
    return {p.stem:encode_html_chunk(compile_html_text(p.read_text(),source_path=p)) for p in GAMES}

def frames(b,n=1):
    for _ in range(n):b.frame_tick()
    assert b.machine._hw_vm is None or not b.machine._hw_vm.error
    b.framebuffer()

def click(b,x,y):
    b.set_mouse(x,y,1);b.set_mouse(x,y,0);frames(b)

def command(b,label,item):
    u=b.system_menu.classic
    index=next(i for i,(_,_,title) in enumerate(u.bar()) if title==label)
    x=u.bar()[index][0]
    row=next(i for i,(title,_,_) in enumerate(u.rows(index+1)) if title==item)
    click(b,x+6,8);click(b,min(426,x)+12,32+21*row)

@pytest.mark.parametrize('path',GAMES,ids=lambda p:p.stem)
def test_each_real_game_about_quit_restart_and_program_fit(path,images,tmp_path):
    image=ProgramImage(images[path.stem]);assert image.code_end<=PROGRAM_CODE_WORDS*4
    b=PythonBackend(Machine(storage_root=tmp_path))
    try:
        b.desktop.visible=False;b.machine.source_name=path.stem+'.HTM'
        b.machine._start_html_image(image);frames(b,3)
        assert b.machine.running and b.machine.system_window[0]==8
        title,description=b.machine.system_about
        assert title and description and '|' not in description
        # About must render the app's metadata, not just store it unused.
        rendered=[];paint=b.system_menu._text
        def record(rgba,width,x,y,text,colour):
            rendered.append(text);return paint(rgba,width,x,y,text,colour)
        b.system_menu._text=record
        click(b,12,10);click(b,12,33)
        assert b.system_menu.about
        assert all(text in rendered for text in ('JMR Enterprises',title,description))
        click(b,320,280)
        click(b,12,10);click(b,12,56)
        assert b.system_keyboard and b.machine.running
        click(b,615,302)
        if b.machine.system_viewport:
            command(b,'Game','Restart');frames(b)
            assert b.machine.running and b.machine.system_about==(title,description)
        command(b,'File','Quit')
        assert b.desktop.visible and not b.machine.running
        b.framebuffer();assert b.system_menu.application_title=='Finder'
    finally:b.shutdown()


def test_auto_viewport_preserves_top_bottom_and_logical_mouse(tmp_path):
    # Two rows at the exact image edges ensure that neither the score row
    # nor the last picture row disappears behind/outside the system bar.
    source='''<canvas id="c" width="640" height="480"></canvas><script>
var ctx=document.getElementById("c").getContext("2d");
ctx.systemWindow=8;ctx.systemViewport=1;
ctx.systemAbout="Pointer test|A full-picture input test.";
var py=-1,dy=0,clicks=0,ups=0;
ctx.fillStyle="#ff0000";ctx.fillRect(0,0,640,1);
ctx.fillStyle="#00ff00";ctx.fillRect(0,479,640,1);
addEventListener("mousemove",function(e){py=e.clientY;dy=e.movementY;});
addEventListener("mousedown",function(e){clicks=clicks+1;});
addEventListener("mouseup",function(e){ups=ups+1;});
function frame(){requestAnimationFrame(frame);}requestAnimationFrame(frame);
</script>'''
    b=PythonBackend(Machine(storage_root=tmp_path));b.desktop.visible=False
    try:
        b.machine._start_html_image(ProgramImage(encode_html_chunk(compile_html_text(source))))
        frames(b);canvas=b.framebuffer();rgb=canvas.front_rgb_preview()
        assert rgb[(24*640+100)*3:(24*640+100)*3+3]==b'\xff\x00\x00'
        assert rgb[(479*640+100)*3:(479*640+100)*3+3]==b'\x00\xff\x00'
        b.set_mouse(400,24,0);frames(b);assert b.machine._hw_vm.globals['py']==0
        b.set_mouse(400,479,0);frames(b)
        assert b.machine._hw_vm.globals['py']==479 and b.machine._hw_vm.globals['dy']==479
        b.set_mouse(400,300,1);frames(b)
        b.set_mouse(12,10,0);frames(b) # Drag release over chrome still reaches the app.
        assert b.machine._hw_vm.globals['ups']==1
        assert not b.system_menu.guest_drag and not b.system_menu.classic.drag
        click(b,12,10);click(b,12,33);assert b.system_menu.about
        click(b,320,280)
        click(b,40,8);click(b,42,32) # File > Quit. Menu clicks are never app clicks.
        assert not b.machine.running
    finally:b.shutdown()
