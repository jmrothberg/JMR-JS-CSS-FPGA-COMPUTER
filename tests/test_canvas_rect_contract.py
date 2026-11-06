"""Independent pixel-intersection cases for raw and scoped rectangle calls."""
import pytest
from functional_model.canvas_engine import CanvasEngine
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from functional_model.machine import Machine
from hardware_model.js_vm import JsHwVm


@pytest.mark.parametrize('x,y,w,h', [
    (-5,10,10,3), (10,-2,3,5), (-5,-2,10,5),
    (638,478,10,5), (640,10,8,3), (10,480,3,8),
    (-10,10,5,3), (10,-10,3,5), (10,10,0,3), (10,10,3,0),
    (10,10,-3,3), (10,10,3,-3),
    (1024,10,8,3), (-2147483648,10,2147483647,3),
])
def test_rectangle_intersects_original_signed_geometry(x,y,w,h):
    c=CanvasEngine();c.fill_rect(x,y,w,h,7)
    expected=bytes(7 if w>0 and h>0 and x<=xx<x+w and y<=yy<y+h else 0
                   for yy in range(480) for xx in range(640))
    assert bytes(c.back)==expected


def test_clipping_and_scissor_intersect_without_shifting_source_rectangle():
    c=CanvasEngine();c.set_scissor(2,11,3,1);c.fill_rect(-5,10,10,3,7)
    expected=bytearray(640*480);expected[11*640+2:11*640+5]=bytes([7])*3
    assert bytes(c.back)==expected


def execute(source):
    image=ProgramImage.from_chunk(compile_source(source),v2=True,value64=True)
    vm=JsHwVm();vm.load_image(image);assert vm.error is None,vm.error
    return vm


def test_global_native_rectangle_is_raw_default_white_and_does_not_wrap_10bits():
    vm=execute('''var c=document.querySelector("canvas").getContext("2d");
c.fillStyle=3;c.setTransform(2,0,0,2,100,100);
fillRect(5,7,3,2);c.fillRect(5,7,3,2);
fillRect(-5,30,10,3,9);fillRect(1024,40,3,2,9);''')
    expected=bytearray(640*480)
    for y in range(7,9):expected[y*640+5:y*640+8]=bytes([1])*3
    for y in range(114,118):expected[y*640+110:y*640+116]=bytes([3])*6
    for y in range(30,33):expected[y*640:y*640+5]=bytes([9])*5
    assert bytes(vm.canvas.back)==expected


def test_scoped_positive_thin_rectangles_keep_one_pixel_after_q16_scale():
    vm=execute('''var c=document.querySelector("canvas").getContext("2d");
c.setTransform(0.95,0,0,0.95,0,24);c.fillRect(20,30,1,1,7);
c.fillRect(30,30,0,3,7);c.fillRect(40,30,-1,3,7);
c.setTransform(-1,0,0,1,100,0);c.fillRect(1,2,3,4,7);''')
    expected=bytearray(640*480);expected[52*640+18]=7
    assert bytes(vm.canvas.back)==expected


@pytest.mark.parametrize('x,y,sx,sy,tx,ty,expected', [
    (16,240,1,0.95,0,24,(16,251)),
    (-1.9,-1.9,0.5,0.5,10,10,(9,9)),
    (2.9,2.9,2,2,0,0,(4,4)),
    (5,6,0,0,0,0,(5,6)),
    (3,4,-1,1,10,20,(7,24)),
    (4294967308,0,1,1,0,0,(12,0)),
])
def test_integer_consumers_quantize_input_scale_and_translation(x,y,sx,sy,tx,ty,expected):
    m=Machine();m._nat_ctx_xform(tx,ty,sx,sy)
    assert m._xf(x,y)==expected


def test_path_coordinates_retain_fraction_before_their_separate_q32_transform():
    m=Machine();m._nat_ctx_xform(10,10,2,2)
    assert m._path_point(1.75,-1.75)==(13,6)
    assert m._xf(1.75,-1.75)==(12,8)


def test_extreme_scaled_rectangle_has_wide_endpoints_and_stays_offscreen():
    m=Machine();m._nat_ctx_xform(0,0,32767,1)
    m._nat_fill_rect(2147483647,10,4,3,7)
    assert not any(m.canvas.back)
    assert m._xf(2147483647,10,4,3)[0] > 2**32


def test_translate_quantizes_each_call_instead_of_accumulating_fractions():
    vm=execute('''var c=document.querySelector("canvas").getContext("2d");
c.translate(0.75,0.75);c.translate(0.75,0.75);c.fillRect(1,1,2,2,7);''')
    expected=bytearray(640*480)
    for y in range(1,3):expected[y*640+1:y*640+3]=bytes([7])*2
    assert bytes(vm.canvas.back)==expected
