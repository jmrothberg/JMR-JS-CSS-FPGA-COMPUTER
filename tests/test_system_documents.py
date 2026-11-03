"""Real manual viewing and mouse-only source editing on the shared machine."""
from pathlib import Path
import pytest
from functional_model.machine import Machine
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text,encode_html_chunk
from tools.make_sd_image import create_image,open_volume

ROOT=Path(__file__).resolve().parents[1]


def test_manual_pixels_and_mouse_keyboard_save(tmp_path,monkeypatch):
    import runtime.sim_backend as module
    exe=ROOT/'sim/sim_build_desktop/jmr_js_sim_server'
    if not exe.is_file():pytest.skip('desktop RTL not built')
    monkeypatch.setattr(module,'_SYNTH',exe)
    monkeypatch.delenv('JMR_SIM_HOST',raising=False)
    manual=(ROOT/'storage/HELP.MD').read_bytes()
    files=[('HELP.MD',manual)]
    for title in ('READ','EDITOR'):
        path=ROOT/'storage'/f'{title}.HTML'
        files.append((title+'.JSH',encode_html_chunk(compile_html_text(path.read_text(),source_path=path))))
    base=create_image(tmp_path/'base.img',include_storage=False,files=files,size_bytes=4*1024*1024).read_bytes()
    screens=[]
    for kind in ('PYTHON','RTL'):
        card=tmp_path/(kind+'.img');card.write_bytes(base)
        monkeypatch.setenv('JMR_CARD_IMG',str(card))
        backend=PythonBackend(Machine()) if kind=='PYTHON' else module.SimBackend()
        def click(x,y):
            backend.set_mouse(x,y,1);backend.set_mouse(x,y,0)
            for _ in range(2):backend.frame_tick()
        try:
            backend.type_line('LOAD "HELP.MD"');backend.type_line('READ')
            if kind=='RTL':
                for _ in range(120):
                    backend.frame_tick()
                    if 'vm_busy=1' in backend._rpc('STATUS?'):break
            for _ in range(6):backend.frame_tick()
            assert backend.running,(kind,backend.screen_text(),backend._rpc('VMSTAT?') if kind=='RTL' else '')
            screens.append(backend.framebuffer().front_rgb_preview())
            assert sum(backend.framebuffer().front)>100000,'document window was blank'
            click(22,45) # The Mac close box ends READ without modifying its file.
            for _ in range(40):
                if kind=='RTL':backend._rpc('TICKN 100')
                backend.frame_tick()
                if not backend.running:break
            assert not backend.running
            assert open_volume(card).read_file('HELP.MD')==manual
            backend.type_line('LOAD "HELP.MD"');backend.type_line('EDIT')
            for _ in range(5):backend.frame_tick()
            click(12,10);click(12,80) # Ship > Keyboard
            click(60,351) # q: charCode 113, distinct from F2/keyCode 113.
            assert backend.running
            assert open_volume(card).read_file('HELP.MD')==manual
            click(236,450) # F2, save and leave.
            for _ in range(140):
                if kind=='RTL':backend._rpc('TICKN 100')
                backend.frame_tick()
                if not backend.running:break
            assert not backend.running
            volume=open_volume(card)
            assert volume.read_file('HELP.MD')==b'q'+manual
            # The save must replace this file, with no malformed new name.
            assert set(n for n,size in volume.list_root_info())=={'HELP.MD','EDITOR.JSH','READ.JSH'}
        finally:backend.shutdown()
    assert screens[0]==screens[1]
