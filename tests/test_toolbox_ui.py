"""The shared JavaScript UI runs on the existing native value64 engine."""
from pathlib import Path
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number
from tools.build_system_resources import pack,unpack
ROOT=Path(__file__).resolve().parents[1]
# ui.js draws dialog button labels with session.js's tbSessionCodes.
LIB=''.join((ROOT/'resources/toolbox'/n).read_text() for n in ('toolbox.js','session.js','ui.js'))
def run(source):
 vm=JsHwVm();vm._m._toolbox_sys_data=bytes(unpack(pack(ROOT/'resources/system/system.json')))
 vm.load_image(ProgramImage.from_chunk(compile_source(LIB+source),v2=True,value64=True))
 assert vm.error is None,vm.error
 return vm
def number(vm,name):return value_unpack_number(vm._value_vars[vm.program_image.var_names.index(name)])

def test_software_menu_dialog_events_and_chicago_pixels():
 vm=run('''var c=document.querySelector("canvas").getContext("2d");
 var ready=tbUIInit(c,20000,21000,[84,101,115,116]);
 tbMenus([[[70,105,108,101],[[[79,112,101,110],42,1,0],[[83,97,118,101],43,0,0]]]]);
 tbUIPointer(42,8,1);tbUIPointer(42,8,0);tbUIPointer(60,33,1);tbUIPointer(60,33,0);
 var chosen=tbMenuCommand();var cleared=tbMenuCommand();
 tbUIPointer(42,8,1);tbUIPointer(42,8,0);tbUIPointer(60,55,1);tbUIPointer(60,55,0);
 var disabled=tbMenuCommand();
 tbDialogOpen(3,[78,97,109,101],[],[]);tbUIKey(65,65);tbUIKey(66,66);tbUIKey(8,0);
 var typed=tbDialogValue()[0];var typedLen=tbDialogValue().length;
 tbUIDraw();tbUIPointer(360,280,1);tbUIPointer(360,280,0);
 var accepted=tbDialogResult();var clearResult=tbDialogResult();
 tbDialogOpen(2,[83,97,118,101],[],[]);tbUIKey(27,0);var cancelled=tbDialogResult();
 tbUIPointer(48,55,1);tbUIPointer(48,55,0);var closed=tbMenuCommand();''')
 for name,value in dict(ready=1,chosen=42,cleared=0,disabled=0,typed=65,typedLen=1,accepted=1,clearResult=0,cancelled=2,closed=255).items():
  assert number(vm,name)==value,(name,number(vm,name))
 fb=vm._m.canvas.back
 assert fb[112*640+136]==0 and fb[120*640+145]==1
 assert any(fb[y*640+x]==0 for y in range(132,148) for x in range(152,190))

def test_modal_list_keyboard_and_release_outside_do_not_accept():
 vm=run('''var c=document.querySelector("canvas").getContext("2d");tbUIInit(c,20000,21000,[84]);
 tbDialogOpen(4,[79,112,101,110],[[65],[66],[67],[68],[69],[70]],[]);
 tbUIKey(40,0);tbUIKey(40,0);var selection=tbDialogSelection();
 tbUIPointer(360,280,1);tbUIPointer(0,0,0);var outside=tbDialogResult();
 tbUIKey(13,0);var enter=tbDialogResult();''')
 assert number(vm,'selection')==2
 assert number(vm,'outside')==0
 assert number(vm,'enter')==1


def test_list_scroll_with_mouse_only():
 vm=run('''var c=document.querySelector("canvas").getContext("2d");tbUIInit(c,20000,21000,[84]);
 tbDialogOpen(4,[79],[[65],[66],[67],[68],[69],[70],[71]],[]);
 tbUIPointer(475,250,1);tbUIPointer(475,250,0);
 tbUIPointer(475,250,1);tbUIPointer(475,250,0);
 tbUIPointer(180,250,1);tbUIPointer(180,250,0);var selected=tbDialogSelection();
 tbUIPointer(360,280,1);tbUIPointer(360,280,0);var result=tbDialogResult();''')
 assert number(vm,'selected')==6
 assert number(vm,'result')==1
