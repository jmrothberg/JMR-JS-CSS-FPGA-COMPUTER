from types import SimpleNamespace
from functional_model.machine import Machine
from functional_model.jsb_format import FLAG_TOOLBOX,CMP_STATUS_SAVE,CMP_STATUS_NEXT
from runtime.backend import PythonBackend


def test_adapter_forwards_f2_and_disables_duplicate_frame_and_viewport(tmp_path):
    m=Machine(tmp_path);backend=PythonBackend(m)
    m.running=True;m.system_window=[8,0,0,0];m.system_viewport=True
    m._hw_vm=SimpleNamespace(program_image=SimpleNamespace(flags=FLAG_TOOLBOX))
    events=[];m.input.key_event=lambda *a:events.append(a)
    backend.key_event(113,'',True)
    assert events==[(113,'',True)]
    backend.framebuffer()
    assert backend.system_menu.window[0]==0
    assert backend.system_menu.classic.role==0
    assert not m.canvas.display_game_viewport


def test_raw_save_commit_and_continuation_and_failure(tmp_path):
    m=Machine(tmp_path);m.source_name='SAVED.JS';m._stage_source('abc\n')
    chains=[];m._continue_program=lambda selector:chains.append(selector) or []
    m._nat_stg_write(64,5);m._nat_stg_write(65,0)
    assert m._finish_program_op(CMP_STATUS_SAVE,'')==['SAVED SAVED.JS']
    assert m.storage.load_bytes('SAVED.JS')==b'abc\n'
    assert m._nat_stg_read(65)==1 and chains==[5]
    m._nat_stg_write(65,0);chains.clear()
    def fail(*a):raise OSError('disk failed')
    m.storage.save_text=fail
    assert m._finish_program_op(CMP_STATUS_SAVE,'')==['?IO']
    assert m._nat_stg_read(65)==0 and not chains
    m._nat_stg_write(64,255)
    assert m._finish_program_op(CMP_STATUS_SAVE,'')==['?CE']
    m._continue_program=Machine._continue_program.__get__(m)
    assert m._finish_program_op(CMP_STATUS_NEXT,'')==['?CE']


def test_thin_note_explicitly_chains_editor_without_native_role_trigger(tmp_path):
    from pathlib import Path
    from tools.compile_js import compile_html_text,encode_html_chunk
    from tools.toolbox_linker import build_rom
    from tools.build_system_resources import pack,unpack
    from functional_model.jsb_format import ProgramImage
    root=Path(__file__).resolve().parents[1]
    m=Machine(tmp_path);m._toolbox_code=build_rom()[16:]
    m._toolbox_sys_data=bytes(unpack(pack(root/'resources/system/system.json')))
    p=root/'storage/EDITOR.HTML'
    m.storage.save_bytes('EDITOR.JSH',encode_html_chunk(compile_html_text(p.read_text(),source_path=p)))
    p=root/'storage/NOTE.HTML'
    image=ProgramImage(encode_html_chunk(compile_html_text(p.read_text(),source_path=p)))
    m._start_html_image(image,share_machine=True)
    assert m._cmp_done and m._cmp_status==CMP_STATUS_NEXT
    assert m._nat_stg_read(64)==5 and m._nat_stg_read(52)==5
    m.frame_tick()
    assert m.running and m.system_window[0]==5
    assert m.source_name=='UNTITLED.TXT' and m.unnamed_document
    assert not any(str(s).startswith('?') for s in m.console_log)
