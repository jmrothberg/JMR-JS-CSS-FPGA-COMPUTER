"""Always-on opaque menu and mouse-only keyboard, including real RTL input."""
from pathlib import Path
import re
import pytest
from functional_model.system_menu import SystemMenu,KEYS
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number
ROOT=Path(__file__).resolve().parents[1]


def _click(menu,x,y):
    consumed,events=menu.pointer(x,y,1)
    consumed_up,ups=menu.pointer(x,y,0)
    return events+ups


def _xy(index):return 16+(index%14)*44,318+(index//14)*33


def test_menu_is_opaque_and_keyboard_modifier_release():
    menu=SystemMenu()
    _click(menu,10,10)
    _,_,w,h,rgba=menu.overlays()[0]
    assert (w,h)==(190,72)
    assert all(rgba[(y*w+x)*4+3]==255 for y in range(22,72) for x in range(w))
    assert ('keyboard',True) in _click(menu,10,56)
    assert _click(menu,*_xy(15))==[('key',81,113,True),('key',81,0,False)]
    assert _click(menu,*_xy(42))==[('key',16,0,True)]
    assert _click(menu,*_xy(52))[0]==('key',191,63,True)
    assert ('key',16,0,False) in _click(menu,615,302)
    assert not menu.keyboard and not menu.shift


def test_python_backend_types_at_ready_with_mouse_only():
    from runtime.backend import PythonBackend
    from functional_model.machine import Machine
    backend=PythonBackend(Machine())
    def click(x,y):backend.set_mouse(x,y,1);backend.set_mouse(x,y,0)
    click(10,10);click(10,56)
    assert backend.system_keyboard and not backend.desktop.visible
    for letter in 'help':
        i=next(i for i,k in enumerate(KEYS) if k[2]==ord(letter))
        click(*_xy(i))
    assert backend.console_line=='help'
    click(*_xy(40)) # Enter, not a browser/editor F-key alias
    assert backend.console_line==''
    assert 'DIR LOAD' in backend.screen_text()


SOURCE='''var entered=0;var lastCode=0;var clicks=0;
addEventListener("keydown",function(e){if(e.charCode>=32)entered=entered*131+e.charCode;else lastCode=e.keyCode;});
addEventListener("mousedown",function(e){clicks=clicks+1;});
function tick(){requestAnimationFrame(tick);}requestAnimationFrame(tick);'''


def test_real_rtl_keyboard_pixels_text_and_game_quit(tmp_path,monkeypatch):
    import runtime.sim_backend as module
    exe=ROOT/'sim/sim_build_desktop/jmr_js_sim_server'
    if not exe.is_file():pytest.skip('desktop RTL not built')
    monkeypatch.setattr(module,'_SYNTH',exe)
    monkeypatch.delenv('JMR_SIM_HOST',raising=False)
    image=ProgramImage.from_chunk(compile_source(SOURCE),v2=True,value64=True)
    path=tmp_path/'key.jsh';path.write_bytes(bytes(image))
    sim=module.SimBackend();ui=SystemMenu();model=JsHwVm();model.load_image(ProgramImage(bytes(image)))
    def click(x,y):
        sim.set_mouse(x,y,1);sim.set_mouse(x,y,0)
        for event in _click(ui,x,y):
            if event[0]=='key':
                _,code,text,pressed=event
                model.input.key_event(code,chr(text) if 32<=text<127 else '',pressed)
        for _ in range(2):sim._rpc('FRAME');model.frame_tick()
    def same_overlay():
        sim._desktop_status()
        expected=ui.overlays()
        actual=sim._ui_overlays
        assert len(actual)==len(expected)
        for a,b in zip(actual,expected):
            assert a[:4]==b[:4]
            if a[4]!=b[4]:
                delta=[i for i,(x,y) in enumerate(zip(a[4],b[4])) if x!=y]
                raise AssertionError((len(delta),delta[:25]))
    try:
        assert sim._rpc('JSHLOAD '+str(path)).startswith('OK')
        sim._rpc('FRAME');same_overlay()
        click(10,10);same_overlay()
        click(10,33);same_overlay() # About is a native opaque dialog.
        assert ui.about
        click(320,280);same_overlay()
        assert not ui.about
        click(10,10);click(10,80);same_overlay()
        for index in (15,42,52,29,61):click(*_xy(index));same_overlay()
        assert model.error is None,model.error
        assert model.globals['entered']==(113*131+63)*131+65
        assert model.globals['lastCode']==113
        for name in ('entered','lastCode','clicks'):
            response=sim._rpc('VVARPEEK '+str(image.var_names.index(name)))
            actual=value_unpack_number(int(response.rsplit('v=0x',1)[1],16))
            assert actual==model.globals[name],(name,response,model.globals[name])
        # Latch direction + fire together, then release them all on hide.
        click(450,302);same_overlay()
        click(*_xy(57));click(*_xy(56));same_overlay()
        assert len(ui.latched)==2
        click(*_xy(57));same_overlay()
        assert len(ui.latched)==1
        click(615,302);same_overlay()
        assert not ui.latched and not ui.hold_keys
        assert model.globals['clicks']==0,'UI clicks leaked into the program'
        click(10,10);same_overlay()
        # Quit works while the keyboard is displayed and ends the actual VM.
        sim.set_mouse(10,55,1);sim.set_mouse(10,55,0)
        for _ in range(120):
            sim._rpc('TICKN 100')
            status=sim._rpc('STATUS?')
            desktop=sim._rpc('DESKTOP?')
            if 'running=0' in status and 'active=1' in desktop:break
        assert 'running=0' in status and 'active=1' in desktop,(status,desktop)
    finally:sim.shutdown()
