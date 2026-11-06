from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage, NATIVE_IDS
from hardware_model.js_vm import JsHwVm, value_unpack_number

def test_tagged_native66_operands_and_bytes():
    assert NATIVE_IDS['strByte']==66
    src='''var a=strByte("File|");var b=strByte("File|",4);var c=strByte("File|",5);
    var d=strByte("File|",-1);var e=strByte("File|",2.9);var f=strByte("File|",-0.5);
    var g=strByte(17,0);var h=strByte("File|",isFinite(1));var i=strByte("File|",0/0);
    var j=strByte("File|",1/0);var k=strByte("File|",4294967296);'''
    vm=JsHwVm();p=ProgramImage.from_chunk(compile_source(src),v2=True,value64=True);vm.load_image(p)
    assert vm.error is None,vm.error
    for name,n in dict(a=70,b=124,c=-1,d=-1,e=108,f=70,g=-1,h=-1,i=-1,j=-1,k=-1).items():
        assert value_unpack_number(vm._value_vars[p.var_names.index(name)])==n,name

def test_lowering_keeps_menu_string_compact_and_preserves_comments():
    from tools.software_ui import lower
    source='''// ctx.systemWindow=0 must remain a comment
var ctx=make();ctx.systemWindow=6;
ctx.systemMenus="File|Open...=192|Save As...=193|Quit=194";
ctx.systemAbout="Tool|Test tool";ctx.systemMenuCheck=3;
window.addEventListener("keydown",handler);requestAnimationFrame(frame);'''
    result=lower(source)
    assert '// ctx.systemWindow=0 must remain a comment' in result
    assert 'tbSessionMenus(ctx,"File|Open...=192|Save As...=193|Quit=194")' in result
    assert 'tbSessionListen("keydown",handler)' in result
    assert 'tbSessionFrame(frame)' in result
    assert '[70,105' not in result
