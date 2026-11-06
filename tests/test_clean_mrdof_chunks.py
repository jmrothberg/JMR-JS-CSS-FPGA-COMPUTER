import ast,json,re
from pathlib import Path
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number

def test_all_cells_match_original_long_interned_level_strings():
    root=Path(__file__).resolve().parents[1]
    original=json.loads((root.parent/'mrdof_bounded_maps.json').read_text())['original']
    source=(root/'storage/MRDOF.HTML').read_text()
    chunks=ast.literal_eval(re.search(r'var LAY = (\[.*?\]);',source,re.S)[1])
    assert [''.join(v) for v in chunks]==original
    assert all(len(v)==208 for row in chunks for v in row)
    a=source.index('function cellCh(');end=source.index('\n}',a)+2
    code='var COLS=26,scene=1,LAY='+json.dumps(chunks)+';var gold='+json.dumps(original)+';function layI(){return (scene-1)%10;}'+source[a:end]+'''
    var bad=0,idx,got,expected;while(scene<=10){idx=-1;while(idx<=624){got=cellCh(idx%26,Math.floor(idx/26));expected=idx<0||idx>=624?"#":gold[scene-1][idx];if(got!=expected)bad=bad+1;idx=idx+1;}scene=scene+1;}'''
    vm=JsHwVm();vm.step_budget=20_000_000
    p=ProgramImage.from_chunk(compile_source(code),v2=True,value64=True);vm.load_image(p)
    assert not vm.error,vm.error
    assert value_unpack_number(vm._value_vars[p.var_names.index('bad')])==0
