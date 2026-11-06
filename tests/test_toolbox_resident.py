"""Resident instruction identity, linkage and native execution."""
import struct,zlib
import pytest
from tools.toolbox_linker import compile_linked,build_rom,prefix_bytes
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number

def image(source):
    return ProgramImage.from_chunk(compile_linked(source),v2=True,value64=True)

def test_fixed_prefix_and_rom_crc():
    rom=build_rom()
    magic,version,header,size,crc=struct.unpack('<4sHHII',rom[:16])
    assert (magic,version,header,size)==(b'JMRT',2,16,32768)
    assert crc==zlib.crc32(rom[16:])
    for source in ('var answer=17;','function app(){return 23;} var answer=app();','function x(v){return v+1;}var answer=x(16);'):
        program=image(source)
        assert program.flags&16
        assert prefix_bytes(program)==rom[16:]
        vm=JsHwVm();vm.load_image(program)
        assert vm.error is None,vm.error
        assert value_unpack_number(vm._value_vars[program.var_names.index('answer')]) in (17,23)

def test_reserved_functions_and_html_link_marker():
    with pytest.raises(ValueError,match='redefines'):
        compile_linked('function tbFill(){return 1;}')
    from tools.compile_js import compile_html_text,encode_html_chunk
    program=ProgramImage(encode_html_chunk(compile_html_text('<!-- jmr-toolbox: resident-v2 --><script>var answer=tbFill(100,42,4);</script>')))
    assert program.flags&16
    assert prefix_bytes(program)==build_rom()[16:]

def test_mismatched_rom_is_rejected():
    vm=JsHwVm()
    vm._m._toolbox_code=b'\0'*32768
    with pytest.raises(ValueError,match='identity mismatch'):
        vm.load_image(image('var answer=17;'))

def test_rtl_rejects_mismatched_instruction_prefix(tmp_path,monkeypatch):
    import runtime.sim_backend as module
    from runtime.backend import parse_status_kv
    if not module._SYNTH.is_file():pytest.skip('RTL simulator not built')
    monkeypatch.delenv('JMR_SIM_HOST',raising=False)
    monkeypatch.setenv('JMR_STANDALONE','0')
    data=bytearray(bytes(image('var answer=17;')))
    # Corrupt padding, not executable app code: the loader must still refuse
    # the mismatch rather than silently run different resident instructions.
    program=ProgramImage(bytes(data))
    offset=(16 if program.flags&2 else 12)+program.n_consts*8
    data[offset+8191*4]^=1
    path=tmp_path/'mismatch.jsh';path.write_bytes(data)
    sim=module.SimBackend()
    try:
        assert sim._rpc('JSHLOAD '+str(path)).startswith('OK')
        sim._rpc('TICKN 1000')
        status=parse_status_kv(sim._rpc('VMSTAT?'))
        assert status.get('fault')==9,status
    finally:sim.shutdown()

def test_rom_rejects_nonpadding_outside_physical_bank():
    from functional_model.toolbox_rom import unpack_rom
    rom=bytearray(build_rom())
    assert unpack_rom(bytes(rom))==bytes(rom[16:])
    rom[16+8191*4]^=1
    struct.pack_into('<I',rom,12,zlib.crc32(rom[16:]))
    with pytest.raises(ValueError,match='padding'):
        unpack_rom(bytes(rom))

def test_rom_is_included_in_disk_seed_and_transfer(tmp_path):
    from tools.make_sd_image import collect_storage_files,_PUT_EXTS
    payload=build_rom()
    (tmp_path/'TOOLBOX.ROM').write_bytes(payload)
    assert ('TOOLBOX.ROM',payload) in collect_storage_files(tmp_path)
    assert '.ROM' in _PUT_EXTS

def test_standalone_compile_refuses_unlinked_resident_client():
    from tests.test_self_hosted_compile import _run_chain
    m=_run_chain('<!-- jmr-toolbox: resident-v2 --><script>tbMenuCommand();</script>')
    assert m._cmp_status==15
    assert m._cmp_message()=='ROMLINK'

def test_marker_must_fit_header_bytes():
    from tools.compile_js import compile_html_text
    from functional_model.compiler import CompileError
    with pytest.raises(CompileError,match='first 1024 bytes'):
        compile_html_text('<!--'+'🚀'*300+' jmr-toolbox: resident-v2 --><script>var a=1;</script>')
