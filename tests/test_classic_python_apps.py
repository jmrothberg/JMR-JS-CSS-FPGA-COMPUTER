"""Python-first acceptance of the shared menu contract on real serialized apps.

RTL is deliberately excluded until the owner approves the Python interface.
"""
from pathlib import Path
import pytest
from functional_model.machine import Machine
from functional_model.classic_ui import parse_menus
from runtime.backend import PythonBackend
from tools.compile_js import compile_html_text,encode_html_chunk

ROOT=Path(__file__).resolve().parents[1]

@pytest.fixture(scope='module')
def images():
    result={}
    for stem in ('EDITOR','READ','NOTE','UTILITY','2DFANTA2','DNKF','MENUEX'):
        path=ROOT/'storage'/(stem+'.HTML')
        result[stem]=encode_html_chunk(compile_html_text(path.read_text(),source_path=path))
    return result

@pytest.fixture
def app(tmp_path,images):
    for stem,blob in images.items():
        (tmp_path/(stem+'.JSH')).write_bytes(blob)
        (tmp_path/(stem+'.HTM')).write_bytes((ROOT/'storage'/(stem+'.HTML')).read_bytes())
    (tmp_path/'HELP.MD').write_text('# Help\nRead this document.\n')
    (tmp_path/'OTHER.MD').write_text('# Other\nDifferent document.\n')
    b=PythonBackend(Machine(storage_root=tmp_path))
    yield b
    b.shutdown()

def frames(b,n=2):
    for _ in range(n):b.frame_tick()
    hw=b.machine._hw_vm
    assert hw is None or not hw.error,hw.error
    b.framebuffer()

def click(b,x,y):
    b.set_mouse(x,y,1);b.set_mouse(x,y,0);frames(b)

def menu(b,label,item,far_right=False):
    b.framebuffer();ui=b.system_menu.classic
    i=next(i for i,(x,end,name) in enumerate(ui.bar()) if name==label)
    x=ui.bar()[i][0]+6
    rows=ui.rows(i+1);j=next(j for j,(name,cmd,enabled) in enumerate(rows) if name==item)
    assert rows[j][2],(label,item,'disabled')
    click(b,x,8)
    click(b,min(426,x-6)+(180 if far_right else 12),32+j*21)

def key(b,code,text=''):
    b.key_event(code,text,True);b.key_event(code,text,False)

def text(b,value):
    for c in value:key(b,190 if c=='.' else ord(c.upper()),c)
    frames(b)

def run(b,name):
    b.hard_break(quiet=True);b.type_line('LOAD "'+name+'"');b.type_line('RUN');frames(b)
    assert b.machine.running,b.screen_text()

def observe(b,name):
    hw=b.machine._hw_vm
    return hw._value64_json_host(hw._value_vars[hw.program_image.var_names.index(name)],set())

def test_chess_menu_and_mouse_input_are_independent(app):
    b=app;run(b,'2DFANTA2.HTM')
    assert b.machine.system_window[0]==8
    assert len(b.machine._hw_vm.program_image.decode().sprites)==12
    menu(b,'Level','Ply 3',far_right=True)
    s=observe(b,'state');assert s['searchDepth']==3 and s['selected'] is None
    # Real board coordinates, selected by the existing game mouse handler.
    click(b,200+4*54+27,28+6*54+27)
    s=observe(b,'state');assert s['selected']==[6,4]
    menu(b,'Game','New Game')
    s=observe(b,'state');assert s['selected'] is None and s['searchDepth']==3
    assert s['board'][6][4]==1 and s['turn']==1
    # Ship menu remains available and opaque above the game.
    click(b,12,10);assert b.system_menu.open
    click(b,12,56);assert b.system_keyboard and b.machine.running
    click(b,615,302)
    menu(b,'File','Quit');assert b.desktop.visible and not b.machine.running

def test_donkey_menu_restarts_keep_one_animation_loop(app):
    b=app;run(b,'DNKF.HTM')
    assert len(b.machine._hw_vm.program_image.decode().sprites)==6
    menu(b,'Game','New Game - Mario')
    assert b.machine._hw_vm.globals['gameState']=='game'
    menu(b,'Game','Pause / Resume');assert b.machine._hw_vm.globals['paused']
    menu(b,'Game','Pause / Resume');assert not b.machine._hw_vm.globals['paused']
    for _ in range(3):
        for who in ('Luigi','Mario'):
            menu(b,'Game','New Game - '+who)
            hw=b.machine._hw_vm
            assert hw.globals['character']==who and hw.globals['gameState']=='game'
            assert len(hw._value_raf)==1
            assert len([row for row in hw._value_listeners if row[0]=='keydown'])<=4
    menu(b,'File','Quit');assert b.desktop.visible and not b.machine.running

def test_note_save_stays_editor_and_dirty_close_choices(app):
    b=app;run(b,'NOTE.HTM');text(b,'A note')
    assert b.machine.system_window[0]==5
    menu(b,'File','Save');assert b.system_menu.classic.dialog=='save_as'
    text(b,'NOTES.TXT');key(b,13,'Enter');frames(b,5)
    assert b.machine.running and b.machine.storage.load_bytes('NOTES.TXT')==b'A note'
    assert b.machine._src_bytes==b'A note' # Save/resume must not add a newline.
    text(b,'!');click(b,22,46)
    assert b.system_menu.classic.dialog=='changes'
    key(b,65,'x');frames(b);assert b.machine._src_bytes==b'A note!'
    click(b,430,245);assert b.machine.running # Cancel.
    click(b,22,46);click(b,180,245);frames(b,5) # Save and close.
    assert b.desktop.visible and b.machine.storage.load_bytes('NOTES.TXT')==b'A note!'
    run(b,'NOTE.HTM');text(b,'discard me');click(b,22,46);click(b,300,245)
    assert b.desktop.visible and b.machine.storage.load_bytes('NOTES.TXT')==b'A note!'

def test_editor_edit_menu_and_clipboard_limit(app):
    b=app;run(b,'NOTE.HTM');text(b,'abc')
    menu(b,'Edit','Select All');menu(b,'Edit','Copy');menu(b,'Edit','Clear')
    assert b.machine._src_bytes==b''
    menu(b,'Edit','Paste');assert b.machine._src_bytes==b'abc'
    menu(b,'Edit','Undo');assert b.machine._src_bytes==b''
    # A larger selection is refused before deletion and is not truncated.
    b.machine._stage_source('x'*4200);b.machine._editor_resume=(0,0,0,0,5)
    b.machine._editor_keep_source=True;b.machine.type_line('EDIT');frames(b)
    menu(b,'Edit','Select All');menu(b,'Edit','Cut')
    assert b.machine._src_bytes==b'x'*4200
    assert b.system_menu.classic.dialog=='message'
    assert '4K' in b.system_menu.classic.message

def test_reader_can_open_another_markdown_and_utility_closes(app):
    b=app;b.type_line('READ "HELP.MD"');frames(b)
    menu(b,'File','Open...');u=b.system_menu.classic
    assert {'HELP.MD','OTHER.MD'}<=set(u.files)
    row=u.files.index('OTHER.MD');click(b,180,116+row*16);click(b,430,254)
    assert b.machine.source_name=='OTHER.MD' and b.machine.system_window[0]==2
    assert b'Different document' in b.machine._src_bytes
    click(b,22,46);assert b.desktop.visible
    run(b,'UTILITY.HTM');assert b.machine.system_window[0]==4
    assert b.machine._nat_stg_read(0)==85 # Actual disk catalog, not blank private memory.
    click(b,22,46);assert b.desktop.visible and not b.machine.running

def test_porting_example_uses_same_system_actions(app):
    b=app;run(b,'MENUEX.HTM');menu(b,'Example','Add One')
    assert b.machine._hw_vm.globals['count']==1
    menu(b,'Example','Reset');assert b.machine._hw_vm.globals['count']==0
    menu(b,'File','Quit');assert b.desktop.visible
    for spec in ('Game|Bad=159','Game|A=160|B=160','File|Copy=160','x'*513):
        with pytest.raises(ValueError):parse_menus(spec)

def test_compiler_uses_common_window_without_changing_compiler(app):
    from tools.make_sd_image import open_volume
    from functional_model.jsb_format import COMPILE_CHAIN,ProgramImage
    b=app;volume=open_volume(ROOT/'card.img')
    available={name for name,size in volume.list_root_info()}
    assert {'ARTSCAN.JSH','COMPILER.JSH'}<=available
    # Read real compiler programs from the current disk. The compiler is unchanged.
    for name in COMPILE_CHAIN:
        if name not in available:continue # This release combines optional stages.
        blob=volume.read_file(name)
        b.machine.storage.save_bytes(name,blob)
    b.machine.storage.save_text('CMTEST.HTM','<canvas id="c" width="640" height="480"></canvas>\n<script>var c=document.getElementById("c").getContext("2d");c.fillRect(40,100,10,10);</script>\n')
    stages=[]
    def progress():
        b._system_progress();stages.append(b.system_menu.window[0])
    b.machine.system_progress=progress
    b.type_line('LOAD "CMTEST.HTM"');b._perform_change(('tool','Compile'))
    assert stages and set(stages)=={3}
    image=ProgramImage(b.machine.storage.load_bytes('CMTEST.JSH'))
    assert image.n_ops>0 and 'COMPILED CMTEST.JSH' in b.screen_text()
    b.framebuffer();assert b.system_menu.window[0]==7
    menu(b,'File','Quit');assert b.desktop.visible

def test_mouse_only_filename_and_replace_confirmation(app):
    b=app;run(b,'NOTE.HTM');text(b,'mouse save')
    menu(b,'File','Save');assert b.system_menu.classic.dialog=='save_as'
    assert not b.system_keyboard
    # A new note has no real name. The field is empty, not a blue UNTITLED.
    assert b.system_menu.classic.name=='' and not b.system_menu.classic.name_selected
    text(b,'mouse.txt');assert b.system_menu.classic.name=='mouse.txt'
    assert b.system_menu.classic.caret==len('mouse.txt')
    key(b,13,'Enter') # The real keyboard. The on-screen keyboard stays closed.
    frames(b,4)
    assert b.machine.storage.load_bytes('MOUSE.TXT')==b'mouse save'
    assert b.machine.running and not b.system_keyboard
    menu(b,'File','Save As...')
    # The real name is kept, one character at a time. Typing does not wipe it.
    assert b.system_menu.classic.name=='MOUSE.TXT' and not b.system_menu.classic.name_selected
    for _ in range(9):key(b,8,'Backspace')
    text(b,'OTHER.MD');key(b,13,'Enter');frames(b)
    assert b.system_menu.classic.dialog=='replace'
    assert b.machine.storage.load_bytes('OTHER.MD')==b'# Other\nDifferent document.\n'
    click(b,300,245) # Cancel overwrite; leave file and working document alone.
    assert b.machine.source_name=='MOUSE.TXT' and b.machine._src_bytes==b'mouse save'
