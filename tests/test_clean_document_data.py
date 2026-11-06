"""Raw document/page services do not make UI decisions or overwrite app data."""
import pytest
from functional_model.machine import Machine
from functional_model.jsb_format import CSTG_WORDS, ProgramImage, NATIVE_IDS
from functional_model.compiler import compile_source
from hardware_model.js_vm import JsHwVm, value_unpack_number

@pytest.fixture
def machine(tmp_path):
    return Machine(tmp_path)

def put(m, p, blob):
    for i, value in enumerate(blob):m._nat_stg_write(p+i, value)

def read(m, p, n):return bytes(int(m._nat_stg_read(p+i)) for i in range(n))

def test_document_metadata_name_new_and_no_launch(machine):
    m=machine;m.running=True;m.system_window[0]=5
    put(m,100,b'nsave\0')
    assert m._nat_sys_document(1,100,5)==0
    assert m.source_name=='NSAVE.JS'
    assert m._nat_sys_document(0,200,0)==0
    assert read(m,200,20)==b'NSAVE.JS'+b'\0'*8+bytes((8,0,5,0))
    m._nat_src_write(0,65);m._nat_src_setlen(1)
    assert m._nat_sys_document(2,0,5)==0
    assert m._src_len==0 and m.source_name=='UNTITLED.TXT' and m.unnamed_document
    assert m.running

@pytest.mark.parametrize('name',[b'',b'.JS',b'A.',b'ABCDEFGHI.JS',b'A.HTML',b'A..JS',b'A B',b'A/B',b'\xff',b'A'*16])
def test_bad_names_do_not_update(machine,name):
    m=machine;before=(m.source_name,m.unnamed_document)
    put(m,100,(name+b'\0')[:16])
    assert m._nat_sys_document(1,100,5)==-1
    assert (m.source_name,m.unnamed_document)==before

def test_document_bounds_and_short_name_at_arena_end(machine):
    m=machine;put(m,CSTG_WORDS-2,b'A\0')
    assert m._nat_sys_document(1,CSTG_WORDS-2,1)==0
    assert m.source_name=='A.HTM'
    assert m._nat_sys_document(0,CSTG_WORDS-19,0)==-1
    assert m._nat_sys_document(1,CSTG_WORDS,1)==-1
    assert m._nat_sys_document(2,0,6)==-1

def test_paged_catalog_keeps_sentinels_and_covers_every_record(machine):
    m=machine
    rows=[('F%07d.JS'%i,i+1,0x5821,0) for i in range(7)]
    m.storage.list_finder_info=lambda:rows
    put(m,999,b'\xa5'+b'\xcc'*57+b'\x5a')
    start=0;names=[]
    while True:
        count=m._nat_fs_list(1000,57,start)
        assert 1<=count<=2
        assert read(m,999,1)==b'\xa5' and read(m,1057,1)==b'\x5a'
        header=read(m,1000,16);p=1016
        for _ in range(int(count)):
            n=int(m._nat_stg_read(p));names.append(read(m,p+1,n).decode());p+=n+8
        assert m._nat_stg_read(p)==0
        start=int.from_bytes(header[12:16],'little')
        if not header[10]:break
    assert names==[r[0] for r in rows]
    put(m,1000,b'\xcc'*37)
    assert m._nat_fs_list(1000,36,0)==-1 and read(m,1000,37)==b'\xcc'*37
    assert m._nat_fs_list(CSTG_WORDS-36,37,0)==-1

def test_native65_dispatch_and_compiler_mapping():
    assert NATIVE_IDS['sysDocument']==65
    vm=JsHwVm()
    program=ProgramImage.from_chunk(compile_source('var answer=sysDocument(2,0,5);'),v2=True,value64=True)
    vm.load_image(program)
    assert vm.error is None
    assert value_unpack_number(vm._value_vars[program.var_names.index('answer')])==0
    assert vm._m.unnamed_document
