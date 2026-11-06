"""Typed SYS UI font, legacy compatibility and public measurement contract."""
from pathlib import Path
import struct,zlib
import pytest
from tools.build_system_resources import pack,unpack,unpack_ui_font,UI_INFO,UI_WIDTHS,UI_GLYPHS,HEADER
from functional_model.system_resources import SystemResources
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number
ROOT=Path(__file__).resolve().parents[1]

def payload():return bytes(unpack(pack(ROOT/'resources/system/system.json')))
def container(data):return HEADER.pack(b'JMRS',1,16,len(data),zlib.crc32(data))+data

def test_normalized_font_matches_every_legacy_row_and_advance():
 data=payload();font=unpack_ui_font(data);assert len(font)==95
 resource=SystemResources(container(data))
 for c in range(32,127):
  legacy=struct.unpack_from('<16H',data,c*32)
  assert tuple(font[chr(c)]['bits'])==legacy
  assert font[chr(c)]['advance']==resource.font[chr(c)]['advance']
 assert data[UI_GLYPHS+95*32:]==bytes(24320-UI_GLYPHS-95*32)
 assert data[UI_WIDTHS+95:UI_GLYPHS]==bytes(UI_GLYPHS-UI_WIDTHS-95)

def test_legacy_sys_without_extension_still_decodes():
 data=bytearray(payload());data[UI_INFO:]=bytes(len(data)-UI_INFO)
 r=SystemResources(container(data));assert r.ui_font is None
 assert r.font['A']['advance']==8

@pytest.mark.parametrize('offset',[4,6,8,10,12])
def test_typed_host_decoder_rejects_invalid_header_after_outer_crc_recomputed(offset):
 data=bytearray(payload());data[UI_INFO+offset]^=1
 with pytest.raises(ValueError,match='normalized UI font'):SystemResources(container(data))

def test_width_before_init_and_missing_font_failure_are_observable():
 lib='\n'.join((ROOT/'resources/toolbox'/p).read_text()for p in ('toolbox.js','ui.js'))
 data=bytearray(payload());data[UI_INFO:]=bytes(len(data)-UI_INFO)
 source='''var before=tbTextWidth([65,63]);
 var c=document.querySelector("canvas").getContext("2d");
 var ready=tbUIInit(c,20000,21000,[]);tbText([65],100,100);tbUIDraw();
 var after=tbTextWidth([65,63]);'''
 vm=JsHwVm();vm._m._toolbox_sys_data=bytes(data);vm.load_image(ProgramImage.from_chunk(compile_source(lib+source),v2=True,value64=True));assert vm.error is None
 def number(name):return value_unpack_number(vm._value_vars[vm.program_image.var_names.index(name)])
 assert number('before')==number('after')==16 and number('ready')==0
 assert not any(vm._m.canvas.back[y*640+x]for y in range(100,116)for x in range(100,116))
 assert any(vm._m.canvas.back[y*640+x]for y in range(24)for x in range(34,600))
