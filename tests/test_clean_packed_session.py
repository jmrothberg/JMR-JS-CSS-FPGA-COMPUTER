"""Run the shipped packed state and event code in the native word VM."""
from pathlib import Path
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number
from tools.build_system_resources import pack,unpack
from tools.toolbox_state import compact_state,apply_names
from tools.materialize_software_ui import materialize

ROOT=Path(__file__).resolve().parents[1]

def run(source):
    raw='\n'.join((ROOT/'resources/toolbox'/n).read_text() for n in ('toolbox.js','ui.js','session.js','documents.js'))
    lib,mapping=compact_state(raw)
    lib+='var ED={after:0,confirm:0,resume:0};var dirty=0,editorRole=1;\n'
    lib+=(ROOT/'resources/toolbox/editor_client.js').read_text()
    lib+=(ROOT/'resources/toolbox/filename_client.js').read_text()
    p=ProgramImage.from_chunk(compile_source(lib+apply_names(source,mapping)),v2=True,value64=True)
    vm=JsHwVm();vm._m._toolbox_sys_data=bytes(unpack(pack(ROOT/'resources/system/system.json')))
    vm.load_image(p)
    assert vm.error is None,vm.error
    def get(name):return value_unpack_number(vm._value_vars[p.var_names.index(name)])
    return vm,get

def test_packed_callbacks_modal_pause_and_resume_keep_reference_semantics():
    vm,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    tbSessionProperty(ctx,0,1);var paints=0,keys=0,invalid=0;
    tbSessionInvalidate(function(){invalid=invalid+1;});
    tbSessionListen("keydown",function(e){keys=keys+1;});
    function frame(t){paints=paints+1;tbSessionFrame(frame);}
    tbSessionFrame(frame);_tbSessionFrame(1);
    var first=paints;tbDialogOpen(3,[78,97,109,101],[],[]);_tbSessionFrame(2);
    var paused=paints;_tbSessionKey({keyCode:65,charCode:97});
    var nameByte=tbDialogValue()[0];var consumed=keys;
    _tbSessionKey({keyCode:13,charCode:13});_tbSessionFrame(3);
    var resumed=paints;_tbSessionKey({keyCode:65,charCode:97});var delivered=keys;
    var invalidated=invalid>0?1:0;''')
    for name,value in dict(first=1,paused=1,resumed=2,nameByte=97,consumed=0,delivered=1,invalidated=1).items():
        assert get(name)==value,name

def test_dirty_prompt_cancel_discard_and_save_commit_marker():
    _,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    editorRole=5;tbSessionProperty(ctx,0,5);dirty=1;
    tbSessionCommand(1001,0);var prompt=_tbDialog;tbSessionDialogResult(3);var cancelled=_tbSSwitching;
    tbSessionCommand(1001,0);tbSessionDialogResult(2);var discarded=_tbSSwitching;
    var role=stgRead(52);var marker=stgRead(65);
    _tbSSwitching=0;stgWrite(208,84);stgWrite(209,66);stgWrite(210,1);stgWrite(211,3);stgWrite(65,0);
    editorResume();var stale=ED.resume;
    stgWrite(208,84);stgWrite(209,66);stgWrite(210,1);stgWrite(211,2);stgWrite(65,1);
    editorResume();var committed=ED.resume;var consumed=stgRead(65);''')
    for name,value in dict(prompt=5,cancelled=0,discarded=1,role=5,marker=0,stale=0,committed=2,consumed=0).items():
        assert get(name)==value,name

def test_explicit_client_migration_is_idempotent_and_public():
    html='<!-- jmr-clean-ui: session-v2 --><script>var c=document.querySelector("canvas").getContext("2d");c.systemWindow=1;addEventListener("keydown",key);requestAnimationFrame(frame);</script>'
    out=materialize(html,Path('EDITOR.HTML'))
    assert 'session-v3-explicit' in out and 'tbSessionProperty(c,0,1)' in out
    assert 'tbSessionListen(' in out and 'tbSessionFrame(frame)' in out
    assert 'tbSessionProgram(' in out and 'tbSessionInvalidate(' in out
    assert materialize(out,Path('EDITOR.HTML'))==out


def test_bounded_menu_array_keeps_all_menus_and_command_kinds():
    _,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    tbSessionProperty(ctx,0,6);
    tbSessionMenus(ctx,["File|Open...=193|Save As...=196|Quit=200","Edit|Copy=201","Goodies|Grid=202","Font|Chicago=203","Style|Bold=204","Size|Large=205"]);
    var menus=_tbMenus.length;var last=_tbMenus[5][1][0][1];var openKind=_tbMenus[0][1][0][4];''')
    assert get('menus')==6 and get('last')==205 and get('openKind')==2
    from tools.software_ui import bounded_menu_specs
    spec='File|'+'A'*121+'=1;Edit|'+'B'*121+'=2'
    source='tbSessionMenus(ctx,'+repr(spec)+');'
    lowered=bounded_menu_specs(source)
    assert '[' in lowered and bounded_menu_specs(lowered)==lowered


def test_file_popup_pixels_are_restored_before_save_dialog():
    _,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    sysDocument(2,0,1);tbSessionProperty(ctx,0,1);var frames=0;
    tbSessionInvalidate(function(){ctx.fillStyle="#FFF";ctx.fillRect(24,88,576,344);});
    function frame(t){frames=frames+1;tbSessionFrame(frame);}
    tbSessionFrame(frame);_tbSessionFrame(1);
    tbScreen(100);tbRect(100,34,24,100,88);tbSurface(164,20000,100,88,100,8);tbCopyBits(100,164);
    tbUIPointer(50,8,1);tbUIPointer(50,8,0);_tbSessionFrame(2);
    tbUIPointer(60,77,1);tbUIPointer(60,77,0);_tbSessionFrame(3);
    var dialog=_tbDialog;tbSurface(164,30000,100,88,100,8);tbCopyBits(100,164);
    var i=0,pixelDifferences=0;while(i<8800){if(stgRead(20000+i)!=stgRead(30000+i))pixelDifferences=pixelDifferences+1;i=i+1;}
    var paused=frames;''')
    assert get('dialog')==3
    assert get('pixelDifferences')==0
    assert get('paused')==1


def test_game_pauses_beneath_software_ui_but_gets_key_releases():
    _,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    tbSessionProperty(ctx,0,8);var frames=0,releases=0;
    function frame(t){frames=frames+1;tbSessionFrame(frame);}
    tbSessionListen("keyup",function(e){releases=releases+1;});
    tbSessionFrame(frame);_tbSessionFrame(1);tbDialogOpen(1,[65],[],[]);
    _tbSessionFrame(2);_tbSessionKeyUp({keyCode:32,charCode:0});
    var advanced=frames,releaseCount=releases;
    tbUIPointer(14,40,1);tbUIPointer(14,40,0);var invisibleClose=tbMenuCommand();''')
    assert get('advanced')==1 and get('releaseCount')==1 and get('invisibleClose')==0


def test_application_drag_keeps_release_when_crossing_menu_bar():
    _,get=run('''var ctx=document.querySelector("canvas").getContext("2d");
    tbSessionProperty(ctx,0,1);var downs=0,moves=0,ups=0;
    tbSessionListen("mousedown",function(e){downs=downs+1;});
    tbSessionListen("mousemove",function(e){moves=moves+1;});
    tbSessionListen("mouseup",function(e){ups=ups+1;});
    _tbSessionPointer(2,{clientX:100,clientY:200,button:0});
    _tbSessionPointer(3,{clientX:50,clientY:8,button:0});
    _tbSessionPointer(4,{clientX:50,clientY:8,button:0});
    var menu=_tbMenu,held=_tbDown;''')
    assert get('downs')==1 and get('moves')==1 and get('ups')==1
    assert get('menu')==-1 and get('held')==0
