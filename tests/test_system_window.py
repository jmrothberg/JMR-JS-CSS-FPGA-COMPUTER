"""A system application declares its window through normal context properties."""
from pathlib import Path
import base64
import pytest
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from functional_model.system_menu import SystemMenu
from hardware_model.js_vm import JsHwVm,value_unpack_number
ROOT=Path(__file__).resolve().parents[1]
SOURCE='''var c=document.querySelector("canvas").getContext("2d");
c.systemWindow=4;c.windowScroll=123;c.windowScrollX=45;c.windowDirty=1;
var last=0,clicks=0;
addEventListener("keydown",function(e){last=e.keyCode;});
addEventListener("mousedown",function(e){clicks=clicks+1;});
function frame(){requestAnimationFrame(frame);}requestAnimationFrame(frame);'''

def test_context_properties_and_shared_window_pixels(tmp_path,monkeypatch):
    import runtime.sim_backend as module
    exe=ROOT/'sim/sim_build_system/jmr_js_sim_server'
    if not exe.is_file():pytest.skip('system-window RTL not built')
    monkeypatch.setattr(module,'_SYNTH',exe)
    image=ProgramImage.from_chunk(compile_source(SOURCE),v2=True,value64=True)
    path=tmp_path/'tool.jsh';path.write_bytes(bytes(image))
    model=JsHwVm();model.load_image(ProgramImage(bytes(image)))
    assert model.error is None,model.error
    assert model._m.system_window==[4,123,45,1]
    ui=SystemMenu();ui.window=tuple(model._m.system_window)
    sim=module.SimBackend()
    try:
        assert sim._rpc('JSHLOAD '+str(path)).startswith('OK')
        sim._rpc('FRAME')
        assert sim._rpc('WINDOW?')=='WINDOW role=4 scroll=123 scrollx=45 flags=1'
        sim._desktop_status()
        expected=ui.overlays();actual=sim._ui_overlays
        assert len(actual)==len(expected)==1
        assert actual[0][:4]==expected[0][:4]
        if actual[0][4]!=expected[0][4]:
            delta=[i for i,(a,b) in enumerate(zip(actual[0][4],expected[0][4])) if a!=b]
            raise AssertionError((len(delta),[(i//4%640,i//4//640,i%4,actual[0][4][i],expected[0][4][i]) for i in delta[:20]]))
        # Scroll controls produce ordinary keys; frame/background clicks do
        # not leak into the program. Body clicks remain normal mouse input.
        for x,y in ((608,94),(5,150),(100,150)):
            sim.set_mouse(x,y,1);sim.set_mouse(x,y,0);sim._rpc('FRAME')
        for name,want in (('last',128),('clicks',1)):
            response=sim._rpc('VVARPEEK '+str(image.var_names.index(name)))
            assert value_unpack_number(int(response.rsplit('v=0x',1)[1],16))==want
    finally:sim.shutdown()
