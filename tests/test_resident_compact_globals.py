"""NAMB literal IDs and per-client VAR slots have separate stable namespaces."""
from pathlib import Path
import pytest
import tools.toolbox_linker as linker
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number

ROOT=Path(__file__).resolve().parents[1]

@pytest.fixture
def library(monkeypatch):
    text='\n'.join((ROOT/'resources/toolbox'/n).read_text() for n in ('toolbox.js','ui.js','session.js','documents.js'))
    monkeypatch.setattr(linker,'library_source',lambda:text)
    return linker.build_rom()

@pytest.mark.parametrize('source,answer',[
    ('var File=7;var answer=File+tbTextWidth([65]);',15),
    ('var clientX=12;var answer=clientX;',12),
    ('function own(x){var y=x+2;return y;}var answer=own(5);',7),
    ('class Counter {constructor(v){this.x=v;}get(){return this.x;}}var c=new Counter(17);var answer=c.get();',17),
    ('function factory(x){var z=x+1;return function(y){return z+y;};}var f=factory(3);var answer=f(5);',9),
    ('function outer(a){var f=function(a){return function(b){return a+b;};};return f(a);}var f=outer(10);var answer=f(7);',17),
    ('function factorial(n){if(n<2)return 1;return n*factorial(n-1);}var answer=factorial(5);',120),
    ('function g(other){return other+4;}function f(value){var saved=value;var v=g(7);return saved+v;}var answer=f(3);',14),
    ('function add(a){return a+1;}function f(){var x=10;return add(5)+x;}var answer=f();',16),
    ('function f(){var total=0;for(var i=0;i<3;i=i+1){if(i>0)total=total+x;var x=i+1;}return total;}var answer=f();',3),
])
def test_stable_code_prefix_with_literal_property_local_and_class_names(library,source,answer):
    image=ProgramImage.from_chunk(linker.compile_linked(source),v2=True,value64=True)
    assert linker.prefix_bytes(image)==library[16:]
    assert 'File|Quit=1006' not in image.var_names
    vm=JsHwVm();vm._m._toolbox_code=library[16:];vm.load_image(image)
    assert vm.error is None,vm.error
    assert value_unpack_number(vm._value_vars[image.var_names.index('answer')])==answer

def test_library_native_shadow_is_rejected_before_serializing(library):
    with pytest.raises(ValueError,match='redefines'):
        linker.compile_linked('function strByte(s,i){return 0;}var answer=1;')
