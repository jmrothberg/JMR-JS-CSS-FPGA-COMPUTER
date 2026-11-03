"""Full native disk desktop: FAT, pixels, controls and console program launch."""
from pathlib import Path
import re
import pytest
from functional_model.desktop import Desktop
from functional_model.desktop_icons import GENERIC_PROGRAM_ICON
from functional_model.storage_engine import StorageEngine
from tools.make_sd_image import create_image

ROOT=Path(__file__).resolve().parents[1]


def _state(sim):
    from runtime.backend import parse_status_kv
    return parse_status_kv(sim._rpc('DESKTOP?'))


def _settle(sim, limit=240):
    for _ in range(limit):
        st=_state(sim)
        if not st['busy']:return st
        sim._rpc('TICKN 100')
    raise AssertionError(('desktop did not finish',st,sim._rpc('STATUS?')))


def _click(sim,model,x,y):
    assert sim.set_mouse(x,y,1)
    result=model.pointer(x,y,1)
    assert sim.set_mouse(x,y,0)
    model.pointer(x,y,0)
    model.tick()
    return result


def _same_pixels(sim,model):
    model.tick();sim._rpc('FB?')
    actual=bytes(sim._canvas.front);expected=bytes(model.canvas.front)
    if actual!=expected:
        different=[i for i,(a,b) in enumerate(zip(actual,expected)) if a!=b]
        raise AssertionError((len(different),[(i%640,i//640,actual[i],expected[i]) for i in different[:20]]))


def test_native_desktop_pixels_controls_and_launch(tmp_path,monkeypatch):
    import runtime.sim_backend as module
    exe=module._SYNTH
    if not exe.is_file():pytest.skip('desktop RTL not built')
    monkeypatch.setattr(module,'_SYNTH',exe)
    monkeypatch.delenv('JMR_SIM_HOST',raising=False)
    html=b'''<canvas id="c" width="640" height="480"></canvas><script>
var c=document.getElementById("c").getContext("2d");
c.systemWindow=8;c.systemViewport=1;c.systemAbout="Menu test|A test application.";
c.fillStyle="#ffffff";c.fillRect(10,10,20,20);
function frame(){requestAnimationFrame(frame);}requestAnimationFrame(frame);
</script>'''
    files=[(f'APP{i:02d}.HTM',html) for i in range(18)]
    files += [('HELP.MD',b'# Help\nRead me with File > Read.\n'),('README.TXT',b'Plain text manual'),('APP00.ICN',GENERIC_PROGRAM_ICON.encode()),('APP01.ICN',b'broken icon'),('APP00.ARJ',b'original source artwork'),('APP00.ART',b'binary artwork')]
    image=create_image(tmp_path/'desktop.img',include_storage=False,files=files,size_bytes=4*1024*1024)
    monkeypatch.setenv('JMR_CARD_IMG',str(image))
    model=Desktop(StorageEngine());sim=module.SimBackend()
    try:
        st=_settle(sim);assert st['count']==20,st
        _same_pixels(sim,model)
        _click(sim,model,50,100);_settle(sim);_same_pixels(sim,model)
        assert _state(sim)['selected']==0
        for x in (45,100,210):
            _click(sim,model,x,8);_settle(sim);_same_pixels(sim,model)
            _click(sim,model,610,240);_settle(sim);_same_pixels(sim,model)
        # Hidden view includes actual artwork/icon/compiled files. Its
        # logical suffixes (.ARTJS/.ARTX/.ICON) never change launch filenames.
        _click(sim,model,150,8);_settle(sim)
        _click(sim,model,150,98);_settle(sim);_same_pixels(sim,model)
        assert model.hidden and model.list_view and _state(sim)['count']==42
        _click(sim,model,150,8);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,150,98);_settle(sim);_same_pixels(sim,model)
        assert not model.hidden and not model.list_view and _state(sim)['count']==20
        # Pulldown menu, list mode, and a second icon page.
        _click(sim,model,150,8);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,150,53);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,545,360);_settle(sim);_same_pixels(sim,model)
        assert _state(sim)['page']==1
        _click(sim,model,150,8);_settle(sim)
        _click(sim,model,150,33);_settle(sim);_same_pixels(sim,model)
        # Drag the window, then close/reopen it using the disk icon.
        sim.set_mouse(100,45,1);model.pointer(100,45,1)
        sim.set_mouse(130,65,1);model.pointer(130,65,1)
        sim.set_mouse(130,65,0);model.pointer(130,65,0)
        model.tick();_settle(sim);_same_pixels(sim,model)
        _click(sim,model,model.wx+12,model.wy+12);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,590,60);_settle(sim);_same_pixels(sim,model)
        # Real confirmation dialog, cancel, then launch the selected app
        # through the actual LOAD/RUN console and native FAT sidecar loader.
        _click(sim,model,model.wx+50,model.wy+65);_settle(sim)
        _click(sim,model,590,425);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,380,275);_settle(sim);_same_pixels(sim,model)
        _click(sim,model,45,8);_settle(sim)
        action=_click(sim,model,45,33)
        assert action==('RUN','APP15.HTM')
        for _ in range(240):
            sim._rpc('TICKN 100')
            status=sim._rpc('STATUS?')
            if 'running=1' in status:break
        assert 'running=1' in status,(status,_state(sim),sim._rpc('SCREEN?'))
        sim._rpc('FRAME');sim._rpc('FB?')
        assert sim._canvas.front[35*640+11]!=0
        # The old corner is ordinary program space. Quit is in File.
        assert sim.set_mouse(630,10,1);assert sim.set_mouse(630,10,0)
        sim._rpc('FRAME');assert 'running=1' in sim._rpc('STATUS?')
        assert sim.set_mouse(40,10,1);assert sim.set_mouse(40,10,0)
        assert sim.set_mouse(45,32,1);assert sim.set_mouse(45,32,0)
        st=_settle(sim)
        for _ in range(100):
            if st['active']:break
            sim._rpc('TICKN 100');st=_state(sim)
        assert st['active'],(st,sim._rpc('STATUS?'))
    finally:sim.shutdown()
