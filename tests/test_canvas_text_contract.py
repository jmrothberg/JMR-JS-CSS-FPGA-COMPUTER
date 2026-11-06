"""Serialized Canvas text values, checked against the independent glyph ROM.

These model checks do not certify RTL fractional-number text conversion.
"""
import pytest
from functional_model.compiler import compile_source
from functional_model.font8 import glyph
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm, value_unpack_number
from functional_model.machine import Machine


@pytest.mark.parametrize('expression,text', [
    ('0', '0'), ('1', '1'), ('-0.0', '0'), ('-47', '-47'),
    ('1234', '1234'), ('2147483647', '2147483647'),
    ('"0.0"', '0.0'), ('"001"', '001'), ('"SCORE"', 'SCORE'),
])
def test_integer_hud_text_and_measurement_use_javascript_conversion(expression, text):
    image = ProgramImage.from_chunk(compile_source('''
var c=document.querySelector("canvas").getContext("2d");
c.font="8px Arial";c.textBaseline="top";c.fillStyle="white";
var label=''' + expression + ''';
var measured=c.measureText(label).width;
c.fillText(label,16,24);
'''), v2=True, value64=True)
    vm=JsHwVm();vm.load_image(image)
    assert vm.error is None, vm.error
    assert value_unpack_number(vm._value_vars[image.var_names.index('measured')]) == len(text)*8
    expected=bytearray(640*480)
    for i,char in enumerate(text):
        for y,row in enumerate(glyph(char)):
            for x in range(8):
                if row & (0x80 >> x):
                    expected[(24+y)*640+16+i*8+x]=1
    assert bytes(vm.canvas.back)==expected


def test_fractional_text_model_retains_decimals_rtl_support_is_separate():
    """Do not conceal the RTL's current integer-only numeric renderer limit."""
    image=ProgramImage.from_chunk(compile_source('''
var c=document.querySelector("canvas").getContext("2d");
var width=c.measureText(1.25).width;
'''),v2=True,value64=True)
    vm=JsHwVm();vm.load_image(image)
    assert vm.error is None,vm.error
    assert value_unpack_number(vm._value_vars[image.var_names.index('width')])==32


@pytest.mark.parametrize('font,xscale,expected', [
    ('8px Arial',1,1), ('12px Arial',1,2), ('16px Arial',1,2),
    ('20px Arial',1,3), ('36px Arial',1,5), ('120px Arial',1,15),
    ('128px Arial',1,15), ('8px Arial',2,2), ('24px Arial',0.5,2),
    ('16px Arial',0.5,1), ('20px Arial',-1,1), ('20px Arial',0,3),
    ('32px Arial',0.625,3), ('32px Arial',40959/65536,2),
    ('12px/20px Foo',1,2), ('bold 24px Foo',1,3),
    ('20.5px Foo',1,1), ('259px Foo',1,1), ('999p Foo',1,12),
])
def test_bounded_font_parser_and_fixed_point_scale(font,xscale,expected):
    m=Machine();m._nat_ctx_xform(0,0,xscale,1)
    assert m._font_scale(font)==expected


def test_font_assignments_commit_before_draw_and_invalid_values_preserve_size():
    image=ProgramImage.from_chunk(compile_source('''
var c=document.querySelector("canvas").getContext("2d");
c.font="20px Arial";c.font="not a font";
var before=c.measureText("AB").width;
c.font="0px Arial";var after=c.measureText("AB").width;
'''),v2=True,value64=True)
    vm=JsHwVm();vm.load_image(image)
    assert vm.error is None,vm.error
    for name in ['before','after']:
        assert value_unpack_number(vm._value_vars[image.var_names.index(name)])==48
    next_image=ProgramImage.from_chunk(compile_source('''
var c=document.querySelector("canvas").getContext("2d");
var width=c.measureText("AB").width;
'''),v2=True,value64=True)
    vm.load_image(next_image)
    assert vm.error is None,vm.error
    assert value_unpack_number(vm._value_vars[next_image.var_names.index('width')])==16


@pytest.mark.parametrize('text,visible,measured', [
    ('©Z','B)Z',24),
    ('Â©Z','C B)Z',40),
    ('A'*70,'A'*64,560),
])
def test_utf8_byte_glyphs_draw_limit_and_full_measurement(text,visible,measured):
    import json
    image=ProgramImage.from_chunk(compile_source('''
var c=document.querySelector("canvas").getContext("2d");
c.font="8px Arial";c.textBaseline="top";c.fillStyle="white";
var value='''+json.dumps(text)+''';
var width=c.measureText(value).width;c.fillText(value,16,24);
'''),v2=True,value64=True)
    vm=JsHwVm();vm.load_image(image)
    assert vm.error is None,vm.error
    assert value_unpack_number(vm._value_vars[image.var_names.index('width')])==measured
    expected=bytearray(640*480)
    for i,char in enumerate(visible):
        for y,row in enumerate(glyph(char)):
            for x in range(8):
                if row & (0x80>>x):expected[(24+y)*640+16+i*8+x]=1
    assert bytes(vm.canvas.back)==expected
