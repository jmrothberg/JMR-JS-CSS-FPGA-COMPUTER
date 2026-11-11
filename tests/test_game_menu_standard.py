"""A game viewport keeps its top and bottom rows and maps the pointer into the picture."""
from functional_model.machine import Machine
from functional_model.jsb_format import ProgramImage
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text,encode_html_chunk


def frames(b,n=1):
    for _ in range(n):b.frame_tick()
    assert b.machine._hw_vm is None or not b.machine._hw_vm.error
    b.framebuffer()

def click(b,x,y):
    b.set_mouse(x,y,1);b.set_mouse(x,y,0);frames(b)

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
    finally:b.shutdown()
