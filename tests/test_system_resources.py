from pathlib import Path
import json, struct
import pytest
from tools.build_system_resources import pack,unpack,SIZE,CONFIG
from functional_model.system_resources import SystemResources
from functional_model.classic_ui import ClassicUI

ROOT=Path(__file__).resolve().parents[1]

def custom(tmp_path):
    spec=json.loads((ROOT/'resources/system/system.json').read_text())
    spec['font']=str(ROOT/'assets/desktop/chicago-12.json')
    spec['labels']['110']='Files'
    spec['labels']['147']='Save your document:'
    spec['labels']['123']='Store'
    spec['dialog_offsets']['save_as']=[20,8]
    spec['dialog_buttons']['save_as'][1]=[300,214,100]
    spec['glyph_overrides']={'F':{'offset':0,'rows':['1111111']*15}}
    path=tmp_path/'custom.json';path.write_text(json.dumps(spec));return path,spec

def test_pack_decode_and_edit_without_rtl(tmp_path):
    path,_=custom(tmp_path);blob=pack(path);data=unpack(blob)
    assert len(data)==SIZE and SIZE<=24*1024
    r=SystemResources(blob)
    assert r.translate('Save')=='Store'
    assert r.label(110)=='Files' and r.label(147)=='Save your document:'
    assert r.offset('save_as')==(20,8)
    assert r.font['F']['rows'][0].startswith('1111111')

def test_corrupt_truncated_and_version_are_rejected():
    good=pack(ROOT/'resources/system/system.json')
    for bad in (good[:-1],good+b'X',good[:4]+b'\x02'+good[5:],good[:100]+bytes([good[100]^1])+good[101:]):
        with pytest.raises(ValueError):SystemResources(bad)

def test_validate_font_metrics_and_resource_bounds(tmp_path):
    path,spec=custom(tmp_path);spec['glyph_overrides']['F']['advance']=14;path.write_text(json.dumps(spec))
    with pytest.raises(ValueError,match='advance'):pack(path)
    path,spec=custom(tmp_path);spec['dialog_offsets']['save_as']=[500,0];path.write_text(json.dumps(spec))
    with pytest.raises(ValueError,match='offsets'):pack(path)

def test_moved_dialog_draw_and_hit_agree(tmp_path):
    path,_=custom(tmp_path);r=SystemResources(pack(path));ui=ClassicUI();ui.resources=r
    ui.show_name('TEST.TXT');pixels=bytearray(640*480*4);calls=[]
    ui.decorate(pixels,lambda buf,w,x,y,text,col:calls.append((x,y,text)))
    assert (172,132,'Save your document:') in calls
    # Save follows the translated rectangle. Releasing outside cancels the click.
    ui.pointer(180,230,1,5,False)
    _,events=ui.pointer(180,230,0,5,False)
    assert events==[('save_name','TEST.TXT')]
    ui.show_name('TEST.TXT');ui.pointer(180,230,1,5,False)
    _,events=ui.pointer(130,230,0,5,False)
    assert not events and ui.dialog=='save_as'
    ui.pointer(390,230,1,5,False);ui.pointer(390,230,0,5,False)
    assert ui.dialog is None, 'Moved Cancel must follow its resource rectangle'
