"""Native mouse event objects, ordering and retention, model/RTL parity."""
from pathlib import Path
import re
import pytest

from functional_model.compiler import compile_source
from functional_model.input_engine import InputEngine
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm, value_unpack_number

ROOT = Path(__file__).resolve().parents[1]
SOURCE = '''
var trace=0; var first=null; var endX=0; var endY=0; var moveX=0; var moveY=0;
var seenButtons=0; var seenButton=0; var firstX=0;
addEventListener("mousemove",function(e){
  trace=trace*10+1; if(first===null)first=e;
  endX=e.clientX;endY=e.offsetY;moveX=e.movementX;moveY=e.movementY;
});
addEventListener("mousedown",function(e){trace=trace*10+2;seenButtons=e.buttons;seenButton=e.button;});
addEventListener("mouseup",function(e){trace=trace*10+3;});
addEventListener("click",function(e){trace=trace*10+4;endX=e.x;endY=e.y;});
function tick(){if(first!==null)firstX=first.clientX;requestAnimationFrame(tick);}
requestAnimationFrame(tick);
'''


def test_queue_preserves_edges_clamps_and_has_backpressure():
    engine = InputEngine()
    assert engine.set_mouse(999, -10, 7)
    assert engine.set_mouse(639, 0, 0)
    events = engine.drain_mouse_events()
    assert [(e.type, e.button, e.buttons) for e in events] == [
        ('mousemove',0,0),('mousedown',0,7),('mousedown',2,7),('mousedown',1,7),
        ('mouseup',0,0),('click',0,0),('mouseup',2,0),('mouseup',1,0)]
    assert all((e.x,e.y) == (639,0) for e in events)
    assert (events[0].movement_x, events[0].movement_y) == (319,-240)
    for i in range(100):
        if not engine.set_mouse(i, 10, i & 1):
            break
    else:
        pytest.fail('mouse queue silently grew past the hardware queue')
    assert len(engine._mouse_events) <= 64
    last = engine.mouse_buttons
    assert not engine.set_mouse(0, 0, last ^ 1)
    assert engine.mouse_buttons == last


def _image():
    return ProgramImage(bytes(ProgramImage.from_chunk(
        compile_source(SOURCE), v2=True, value64=True)))


def _samples():
    return [(400,250,0),(400,250,1),(410,252,1),(410,252,0)]


def test_serialized_model_events_and_retained_object():
    vm = JsHwVm()
    vm.load_image(_image())
    for sample in _samples():
        assert vm.input.set_mouse(*sample)
    vm.frame_tick()
    assert vm.error is None, vm.error
    assert {n:vm.globals[n] for n in ('trace','endX','endY','moveX','moveY','seenButtons','seenButton','firstX')} == {
        'trace':12134,'endX':410,'endY':252,'moveX':10,'moveY':2,
        'seenButtons':1,'seenButton':0,'firstX':400}


def test_actual_rtl_event_properties_and_retention(tmp_path, monkeypatch):
    import runtime.sim_backend as module
    exe = ROOT / 'sim/sim_build_desktop/jmr_js_sim_server'
    if not exe.is_file():
        pytest.skip('desktop RTL simulator has not been built')
    monkeypatch.setattr(module, '_SYNTH', exe)
    monkeypatch.delenv('JMR_SIM_HOST', raising=False)
    image = _image()
    source = tmp_path / 'mouse.jsh'
    source.write_bytes(bytes(image))
    sim = module.SimBackend()
    try:
        assert sim._rpc('JSHLOAD ' + str(source)).startswith('OK')
        sim._rpc('FRAME')
        for sample in _samples():
            assert sim.set_mouse(*sample)
        for _ in range(3):
            sim._rpc('FRAME')
        status = sim._rpc('VMSTAT?')
        assert re.search(r'\bfault=0\b', status), status
        for name, expected in {'trace':12134,'endX':410,'endY':252,'moveX':10,
                               'moveY':2,'seenButtons':1,'seenButton':0,'firstX':400}.items():
            answer = sim._rpc('VVARPEEK ' + str(image.var_names.index(name)))
            word = int(answer.rsplit('v=0x',1)[1],16)
            assert value_unpack_number(word) == expected, (name,answer)
    finally:
        sim.shutdown()
