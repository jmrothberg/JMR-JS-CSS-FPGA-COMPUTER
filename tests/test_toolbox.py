"""Bulk service contract: independent overlap/clipping/validation examples."""
from functional_model.toolbox import VERSION
from functional_model.machine import Machine
from functional_model.jsb_format import CSTG_WORDS, NATIVE_IDS, ProgramImage
from functional_model.compiler import compile_source
from hardware_model.js_vm import JsHwVm
from hardware_model import js_vm as values


def test_native_dispatch_keeps_javascript_running():
    vm = JsHwVm()
    vm.load_image(ProgramImage.from_chunk(compile_source(
        "var version=toolbox(0,0,0,0); var count=toolbox(2,100,42,8);"
        "var copied=toolbox(1,100,104,8); var after=stgRead(111)+1;"), v2=True, value64=True))
    names = vm.program_image.var_names
    def val(name):
        return values.value_unpack_number(vm._value_vars[names.index(name)])
    assert NATIVE_IDS["toolbox"] == 64
    assert val("version") == VERSION
    assert val("count") == val("copied") == 8
    assert val("after") == 43


def test_copy_overlap_seam_and_validation():
    m = Machine()
    for i in range(64):
        m._nat_stg_write(73710 + i, i)
    assert m._nat_toolbox(1, 73710, 73713, 61) == 61
    assert [m._nat_stg_read(73713 + i) for i in range(61)] == list(range(61))
    assert m._nat_toolbox(1, 73713, 73710, 61) == 61
    assert [m._nat_stg_read(73710 + i) for i in range(61)] == list(range(61))
    assert m._nat_toolbox(2, CSTG_WORDS, 1, 0) == 0
    assert m._nat_toolbox(2, CSTG_WORDS - 1, 1, 2) == -1
    assert m._nat_toolbox(1, -1, 10, 1) == -1


def test_surface_blit_and_pattern_fill():
    m = Machine()
    d = bytearray(64)
    d[:4] = bytes([1, 4, 1, 2])
    d[4:8] = (2000).to_bytes(4, "little")
    for i, v in {8:2, 10:4, 12:1, 18:4, 20:1, 22:10, 24:10, 30:640, 32:480}.items():
        d[i:i+2] = v.to_bytes(2, "little")
    d[48:64] = bytes(i * 13 for i in range(16))
    for i, v in enumerate(d):
        m._nat_stg_write(100+i, v)
    m._nat_stg_write(2000, 0x12)
    m._nat_stg_write(2001, 0x30)
    m.canvas.back[:] = bytes([9]) * len(m.canvas.back)
    assert m._nat_toolbox(3,100,0,0) == 4
    assert m.canvas.back[6410:6418] == bytes([13,13,26,26,39,39,9,9])
    m._nat_stg_write(134,5)
    m._nat_stg_write(135,2)
    m._nat_stg_write(140,0xa0)
    assert m._nat_toolbox(4,100,0,0) == 4
    assert m._nat_stg_read(2000) == m._nat_stg_read(2001) == 0x52
    m._nat_stg_write(108,1)  # stride cannot hold the declared surface width
    assert m._nat_toolbox(4,100,0,0) == -1
    assert m._nat_stg_read(2000) == 0x52


def test_real_rtl_native_service(tmp_path, monkeypatch):
    """Exercise the real VM CDC/service mux, not only the peripheral bench."""
    import shutil
    import pytest
    from pathlib import Path
    import runtime.sim_backend as module
    from runtime.backend import parse_status_kv
    root = Path(__file__).resolve().parents[1]
    if not module._SYNTH.is_file():
        pytest.skip('RTL simulator not built')
    monkeypatch.delenv('JMR_SIM_HOST', raising=False)
    disk = tmp_path / 'card.img'
    shutil.copyfile(root / 'card.img', disk)
    from tools.compile_js import compile_html_text, encode_html_chunk
    from tools.make_sd_image import patch_card_file
    utility_path = root/'storage/UTILITY.HTML'
    utility_bytes = encode_html_chunk(compile_html_text(utility_path.read_text(),source_path=utility_path))
    utility = ProgramImage(utility_bytes)
    patch_card_file(disk,'UTILITY.JSH',utility_bytes)
    patch_card_file(disk,'UTILITY.HTM',utility_path.read_bytes())
    from tools.toolbox_linker import build_rom,compile_linked
    patch_card_file(disk,'TOOLBOX.ROM',build_rom())
    monkeypatch.setenv('JMR_CARD_IMG', str(disk))
    source = ('var version=toolbox(0,0,0,0); var count=toolbox(2,73720,42,32);'
              'var copied=toolbox(1,73720,73723,29); var after=stgRead(73751)+1;'
              'var rejected=toolbox(2,380927,99,2);'
              'var c=document.querySelector("canvas").getContext("2d");'
              'c.fillStyle="#00FF00";c.fillRect(300,200,8,8);'
              'function tick(){requestAnimationFrame(tick);}requestAnimationFrame(tick);')
    # A 2x2 8-bit surface scaled to 4x4 at (300,300).
    d = bytearray(64)
    d[:4] = bytes([1,8,0,2])
    d[4:8] = (2000).to_bytes(4,"little")
    for offset, value in {8:2,10:2,12:2,18:2,20:2,22:300,24:300,30:640,32:480}.items():
        d[offset:offset+2] = value.to_bytes(2,"little")
    source += "toolbox(2,100,0,64);toolbox(2,2000,3,4);"
    source += "".join("stgWrite(%d,%d);"%(100+i,v) for i,v in enumerate(d) if v)
    source += "var blitted=toolbox(3,100,0,0);var finished=123;var resourceRead=toolbox(5,9344,800,4);"
    # Real shared-port framebuffer capture, then restore modified indexed bytes.
    source += ('tbScreen(1000);tbRect(1000,300,300,4,4);'
               'tbSurface(1064,80000,4,4,4,8);'
               'var captured=tbCopyBits(1000,1064);var savedPixel=stgRead(80015);'
               'stgWrite(80000,5);tbScreen(1000);tbRect(1000,0,0,4,4);'
               'tbPlace(1000,310,300,1);'
               'var restored=tbCopyBits(1064,1000);')
    image = ProgramImage.from_chunk(compile_linked(source), v2=True, value64=True)
    path = tmp_path / 'toolbox.jsh'
    path.write_bytes(bytes(image))
    sim = module.SimBackend()
    try:
        sim._rpc('KEYEVT 32 1 32'); sim._rpc('KEYEVT 32 0 0')
        for _ in range(180):
            sim._rpc('TICKN 1000')
            boot = parse_status_kv(sim._rpc('VMSTAT?'))
            if 'role=9 ' in sim._rpc('WINDOW?') and boot.get('raf',0)>0:
                break
        else:
            raise AssertionError('Finder failed to boot')
        assert 'rom=1' in sim._rpc('SYS?')
        sim._rpc('FRAME')
        assert sim._rpc('JSHLOAD '+str(path)).startswith('OK')
        for _ in range(4):
            sim._rpc('FRAME')
        status = parse_status_kv(sim._rpc('VMSTAT?'))
        assert status.get('fault',0)==0, status
        for name, expected in dict(version=VERSION,count=32,copied=29,after=43,rejected=-1,blitted=4,finished=123,resourceRead=4,captured=16,savedPixel=3,restored=16).items():
            response = sim._rpc('VVARPEEK '+str(image.var_names.index(name)))
            actual = values.value_unpack_number(int(response.rsplit('v=0x',1)[1],16))
            assert actual==expected, (name,response,expected)
        assert status.get('raf',0)>0, status
        sim._rpc('FB?')
        for y in range(300,304):
            assert sim._canvas.front[y*640+300:y*640+304] == bytes([3])*4
        assert sim._canvas.front[300*640+310]==5
        assert sim._canvas.front[303*640+313]==3
        ui_source=('var c=document.querySelector("canvas").getContext("2d");'
                   'var ready=tbUIInit(c,20000,21000,[84,101,115,116]);'
                   'tbMenus([[[70,105,108,101],[[[79,112,101,110],42,1,0]]]]);'
                   'tbUIPointer(42,8,1);tbUIPointer(42,8,0);'
                   'tbUIPointer(60,33,1);tbUIPointer(60,33,0);var chosen=tbMenuCommand();'
                   'tbDialogOpen(3,[78,97,109,101],[],[]);tbUIKey(65,65);'
                   'var typed=tbDialogValue()[0];tbUIDraw();'
                   'function frame(){requestAnimationFrame(frame);}requestAnimationFrame(frame);')
        ui=ProgramImage(encode_html_chunk(compile_html_text(
            '<!-- jmr-toolbox: resident-v1 --><canvas></canvas><script>'+ui_source+'</script>')))
        ui_path=tmp_path/'ui.jsh';ui_path.write_bytes(bytes(ui))
        assert sim._rpc('JSHLOAD '+str(ui_path)).startswith('OK')
        for _ in range(4):sim._rpc('FRAME')
        state=parse_status_kv(sim._rpc('VMSTAT?'))
        assert state.get('fault',0)==0,state
        for name,expected in dict(ready=1,chosen=42,typed=65).items():
            response=sim._rpc('VVARPEEK '+str(ui.var_names.index(name)))
            assert values.value_unpack_number(int(response.rsplit('v=0x',1)[1],16))==expected,(name,response)
        sim._rpc('FB?')
        assert sim._canvas.front[112*640+136]==0
        assert sim._canvas.front[120*640+145]==1
        # Real Finder/tool launch path: LOAD Utility then RUN, without a
        # hardware-only catalog-preparation/restart sequence.
        launch_source = ''.join('stgWrite(%d,%d);'%(900+i,c) for i,c in enumerate(b'UTILITY.HTM\0'))+'sysRun(900,7);'
        launch = ProgramImage.from_chunk(compile_source(launch_source),v2=True,value64=True)
        launch_path=tmp_path/'launch.jsh';launch_path.write_bytes(bytes(launch))
        assert sim._rpc('JSHLOAD '+str(launch_path)).startswith('OK')
        for _ in range(180):
            sim._rpc('TICKN 1000')
            state=parse_status_kv(sim._rpc('VMSTAT?'))
            if 'role=4 ' in sim._rpc('WINDOW?') and state.get('raf',0)>0:break
        else:raise AssertionError(('Utility launch failed',state,sim._rpc('STATUS?')))
        for name in ('haveCat','nFiles'):
            response=sim._rpc('VVARPEEK '+str(utility.var_names.index(name)))
            actual=values.value_unpack_number(int(response.rsplit('v=0x',1)[1],16))
            assert actual>0,(name,response)


    finally:
        sim.shutdown()


def test_boot_resources_are_read_only_and_cached():
    m = Machine()
    m._toolbox_sys_data = bytes(range(256))*95
    assert m._nat_toolbox(5,1,73727,3)==3
    assert [m._nat_stg_read(73727+i) for i in range(3)]==[1,2,3]
    assert m._nat_toolbox(5,24319,73727,2)==-1
    assert m._nat_toolbox(5,24320,380928,0)==0
    m._toolbox_sys_data = None
    assert m._nat_toolbox(5,0,100,1)==-1


def test_reusable_surface_helpers_compile_and_draw():
    from pathlib import Path
    source=(Path(__file__).resolve().parents[1]/'resources/toolbox/toolbox.js').read_text()
    source+='tbSurface(100,2000,16,16,2,1);tbFill(2000,255,32);tbInk(100,2,1);tbPlace(100,80,80,2);var drawn=tbBlit(100);'
    vm=JsHwVm()
    vm.load_image(ProgramImage.from_chunk(compile_source(source),v2=True,value64=True))
    assert vm.error is None
    assert vm._m.canvas.back[80*640+80:80*640+112]==bytes([2])*32
    assert vm._m.canvas.back[111*640+80:111*640+112]==bytes([2])*32


def test_on_machine_compiler_recognizes_toolbox():
    from tests.test_self_hosted_compile import _run_chain
    source='<canvas></canvas><script>var answer=toolbox(0,0,0,0);</script>'
    machine=_run_chain(source)
    assert machine._cmp_status==0,machine._cmp_message()
    vm=JsHwVm();vm.load_image(ProgramImage(machine._cmp_output()))
    assert vm.error is None,vm.error
    slot=vm.program_image.var_names.index('answer')
    assert values.value_unpack_number(vm._value_vars[slot])==VERSION
