"""Session components; full application migration is a separate acceptance gate."""
from pathlib import Path
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm, value_unpack_number
from tools.build_system_resources import pack,unpack

ROOT=Path(__file__).resolve().parents[1]

def test_compact_descriptor_parsing_uses_existing_command_numbers():
    lib='\n'.join((ROOT/'resources/toolbox'/n).read_text() for n in ('toolbox.js','ui.js','session.js'))
    source='''var ctx=document.querySelector("canvas").getContext("2d");
    tbSessionProperty(ctx,0,6);tbSessionProperty(ctx,2,"Paint|Draw a picture");
    tbSessionMenus(ctx,"File|New=192|Open...=193|Save As...=196|Quit=200;Edit|Undo=201|-|Invert=206");
    var menuCount=_tbMenus.length;var rowCount=_tbMenus[0][1].length;
    var openKind=_tbMenus[0][1][1][4];var openCode=_tbMenus[0][1][1][1];
    var quitKind=_tbMenus[0][1][3][4];var separator=_tbMenus[1][1][1][2];
    tbUIPointer(42,8,1);tbUIPointer(42,8,0);tbUIPointer(60,55,1);tbUIPointer(60,55,0);
    var chosen=0,polls=0;while(!chosen&&polls<20){chosen=tbMenuCommand();polls=polls+1;}'''  # the item blinks first, as on the Mac
    vm=JsHwVm();vm._m._toolbox_sys_data=bytes(unpack(pack(ROOT/'resources/system/system.json')))
    p=ProgramImage.from_chunk(compile_source(lib+source),v2=True,value64=True);vm.load_image(p)
    assert vm.error is None,vm.error
    for name,n in dict(menuCount=2,rowCount=4,openKind=2,openCode=193,quitKind=1,separator=0,chosen=193,polls=6).items():
        assert value_unpack_number(vm._value_vars[p.var_names.index(name)])==n,name
