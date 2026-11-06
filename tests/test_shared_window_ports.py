"""Shared software managers execute serialized native instructions, not JS mocks."""
from pathlib import Path
import struct
import pytest
from functional_model.compiler import compile_source
from functional_model.jsb_format import ProgramImage
from hardware_model.js_vm import JsHwVm,value_unpack_number
from tools.toolbox_state import compact_state,apply_names
from tools.build_system_resources import pack,unpack
R=Path(__file__).resolve().parents[1]

def run(source,modules=(),capability=None):
    raw='\n'.join((R/'resources/toolbox'/n).read_text() for n in ('toolbox.js','ui.js','session.js','documents.js'))
    lib,names=compact_state(raw)
    lib+='\n'.join((R/'resources/toolbox'/n).read_text()for n in modules)
    p=ProgramImage.from_chunk(compile_source(lib+apply_names(source,names)),v2=True,value64=True)
    v=JsHwVm();v._m._toolbox_sys_data=bytes(unpack(pack(R/'resources/system/system.json')))
    if capability is not None:
        native=v._m._nat_toolbox
        def call(op=0,a=0,b=0,c=0):return capability if int(op)==0 else native(op,a,b,c)
        v._m._nat_toolbox=call
    v.load_image(p);assert v.error is None,v.error
    def n(name):return value_unpack_number(v._value_vars[p.var_names.index(name)])
    return v,n


def test_typed_values_floor_wrap_full_span_and_unsigned_error_distinction():
    v,n=run('''var a=tbU16(100,-1.2),b=tbU32(102,4294967295),c=tbSessionU32(102);
    var d=tbPair32(106,4294967295,2147483648),e=tbSessionU32(110);
    var invalid=tbU32(380926,5),unchanged=stgRead(380926);''')
    for name,value in dict(a=2,b=4,c=4294967295,d=8,e=2147483648,invalid=-1,unchanged=0).items():assert n(name)==value
    assert bytes(int(v._m._nat_stg_read(i))for i in range(100,102))==b'\xfe\xff'
    _,n=run('''var a=tbU16(100,1),b=tbSessionU32(100);var c=document.querySelector("canvas").getContext("2d");var ready=tbUIInit(c,20000,21000,[]);tbUIDraw();''',capability=65663)
    assert n('a')==n('b')==-1 and n('ready')==0


def test_damage_empty_offscreen_union_and_restore():
    v,n=run('''var c=document.querySelector("canvas").getContext("2d");tbUIInit(c,20000,21000,[]);
    tbDamageClear();tbDamage(-100,30,10,10);tbDamage(10,30,0,10);tbDamage(10,30,-1,10);
    tbDamageClip();c.fillRect(0,0,640,480,3);tbPortPop();
    tbDamage(10,30,5,5);tbDamage(20,40,5,5);tbDamage(630,490,50,50);
    tbDamageClip();c.fillRect(0,0,640,480,4);tbPortPop();tbDamageClear();c.fillRect(639,479,1,1,7);''')
    fb=v._m.canvas.back
    assert sum(x==4 for x in fb)==225
    assert all(fb[y*640+x]==4 for y in range(30,45)for x in range(10,25))
    assert not any(x==3 for x in fb) and fb[-1]==7


def test_nested_port_origin_glyph_raw_arena_copy_and_overflow_restore():
    v,n=run('''var c=document.querySelector("canvas").getContext("2d");tbUIInit(c,20000,21000,[]);
    c.fillRect(0,0,640,480,3);tbPortPush(100,100,30,30,100,100);tbText([65],0,0);
    tbScreen(1000);tbRect(1000,100,100,8,16);tbSurface(1064,30000,8,16,8,8);tbPlace(1064,0,0,1);
    var saved=tbCopyBits(1000,1064);
    tbPortPush(110,110,30,30,5,5);c.fillRect(0,0,50,50,5);tbPortPop();
    tbPortPush(120,120,0,0,0,0);c.fillRect(0,0,640,480,6);tbPortPop();tbPortPop();
    tbPortPush(10,30,10,10,0,0);tbPortPush(10,30,10,10,0,0);tbPortPush(10,30,10,10,0,0);tbPortPush(10,30,10,10,0,0);
    var fail=tbPortPush(0,0,640,480,10,10);var depth=_tbPort;
    tbPortPop();tbPortPop();tbPortPop();tbPortPop();var under=tbPortPop();tbUIDraw();c.fillRect(639,479,1,1,7);''')
    assert n('saved')==128 and n('fail')==-1 and n('depth')==4 and n('under')==-1
    data=bytes(unpack(pack(R/'resources/system/system.json')));rows=struct.unpack_from('<16H',data,65*32)
    captured=bytes(int(v._m._nat_stg_read(30000+i))for i in range(128))
    assert captured==bytes(0 if rows[y]&(0x8000>>x)else 3 for y in range(16)for x in range(8))
    fb=v._m.canvas.back
    assert all(fb[y*640+x]==5 for y in range(110,130)for x in range(110,130))
    assert not any(p==6 for p in fb) and fb[-1]==7 and fb[35]==1


def test_shared_window_stacking_geometry_and_scroll_parts():
    _,n=run('''tbWindowFocus(0);tbWindowFocus(1);tbWindowFocus(2);tbWindowFocus(0);
    var first=tbWindowAt(0),front=tbWindowAt(2),invalid=tbWindowFocus(8),after=tbWindowRemove(0),outside=tbWindowAt(7);
    var close=tbWindowPart(18,44,8,34,612,420),title=tbWindowPart(100,44,8,34,612,420),grow=tbWindowPart(615,450,8,34,612,420);
    var r=[8,34,612,420];tbWindowAdjust(r,-999,-999,0);var x=r[0],y=r[1];tbWindowAdjust(r,-999,-999,1);var w=r[2],h=r[3];
    var up=tbControlPart(90,88,344,20,150,20),thumb=tbControlPart(155,88,344,20,150,20),page=tbControlPart(200,88,344,20,150,20);
    var clamped=tbControlValue(4,100,8);''',modules=('window_client.js',))
    expected=dict(first=1,front=0,invalid=-1,after=2,outside=255,close=2,title=1,grow=3,x=0,y=22,w=180,h=120,up=4,thumb=7,page=9,clamped=8)
    assert {k:n(k)for k in expected}==expected


def test_overlap_scroll_copies_retained_pixels_and_only_exposed_strip_is_repainted():
    v,n=run('''var c=document.querySelector("canvas").getContext("2d");tbUIInit(c,20000,21000,[]);var y=0;
    while(y<20){c.fillRect(100,100+y,20,1,y+1);y=y+1;}
    tbPortPush(100,100,20,20,100,100);tbDamageClear();var count=tbScrollRect(1000,1064,0,0,20,20,0,-4);
    tbDamageClip();c.fillRect(0,0,640,480,9);tbPortPop();tbDamageClear();tbPortPop();''',modules=('scroll_client.js',))
    assert n('count')==320
    fb=v._m.canvas.back
    for y in range(20):assert all(fb[(100+y)*640+x]==(y+5 if y<16 else 9)for x in range(100,120))
    assert fb[99*640+100]==0 and fb[120*640+100]==0


def test_document_session_moves_grows_maps_pointer_and_restores_chrome():
    v,n=run('''var c=document.querySelector("canvas").getContext("2d");tbSessionProperty(c,0,1);
    var resized=0,mouseX=0,offsetX=0;
    function tbClientResize(w,h){resized=w*1000+h;}
    function content(){c.fillRect(24,88,576,344,3);tbText([65],30,100);}
    tbSessionInvalidate(content);tbSessionListen("mousedown",function(e){mouseX=e.clientX;offsetX=e.offsetX;});
    _tbSessionFrame(1);_tbSessionPointer(2,{clientX:100,clientY:44,button:0});
    _tbSessionPointer(3,{clientX:120,clientY:64,button:0});_tbSessionPointer(4,{clientX:120,clientY:64,button:0});_tbSessionFrame(2);
    _tbSessionPointer(2,{clientX:100,clientY:150,button:0});_tbSessionPointer(4,{clientX:100,clientY:150,button:0});
    var movedX=tbWindowBounds()[0],movedY=tbWindowBounds()[1],portDepth=_tbPort;
    _tbSessionPointer(2,{clientX:635,clientY:469,button:0});_tbSessionPointer(3,{clientX:600,clientY:430,button:0});_tbSessionPointer(4,{clientX:600,clientY:430,button:0});_tbSessionFrame(3);
    var width=tbWindowBounds()[2],height=tbWindowBounds()[3];
    tbUIPointer(38,64,1);tbUIPointer(38,64,0);var closed=tbMenuCommand();''',modules=('chrome_client.js',))
    for k,val in dict(movedX=28,movedY=54,mouseX=80,offsetX=80,portDepth=0,width=577,height=381,resized=541305,closed=255).items():assert n(k)==val,(k,n(k))
    fb=v._m.canvas.back
    assert fb[108*640+44]==3 and fb[88*640+24]!=3 and fb[35]==1

@pytest.mark.parametrize('name,redraw',[('EDITOR','redraw'),('READ','draw'),('UTILITY','draw')])
@pytest.mark.parametrize('moved',[False,True])
def test_shipped_document_scroll_matches_full_redraw_pixels(name,redraw,moved,tmp_path):
    from tools.compile_js import compile_html_text,encode_html_chunk
    source='\n'.join(('# Header '+str(i) if name=='READ' and (i==19 or i>=26 and i%7==0) else 'Line '+str(i)+' abcdefghijklmnopqrstuvwxyz '*5)for i in range(100))
    p=R/'storage'/f'{name}.HTML'
    if name=='UTILITY':
        for i in range(64):(tmp_path/f'F{i:03d}.TXT').write_text('data'+str(i))
    def execute(force):
        html=p.read_text();at=html.rindex('</script>')
        commands='function testStep(k){_tbSessionKey({keyCode:k,charCode:0});}'
        commands+='function testRedraw(){_tbSessionDraw('+redraw+',0);}'
        commands+='function testMove(){_tbSessionPointer(2,{clientX:100,clientY:44,button:0});_tbSessionPointer(3,{clientX:120,clientY:64,button:0});_tbSessionPointer(4,{clientX:120,clientY:64,button:0});}'
        html=html[:at]+commands+html[at:]
        v=JsHwVm();v._m._toolbox_sys_data=bytes(unpack(pack(R/'resources/system/system.json')));v._m._stage_source(source)
        from tools.toolbox_linker import build_rom
        from hardware_model.js_vm import value_pack_number
        v._m._toolbox_code=build_rom()[16:]
        if name=='UTILITY':
            from functional_model.storage_engine import StorageEngine
            v._m.storage=StorageEngine(tmp_path)
        im=ProgramImage(encode_html_chunk(compile_html_text(html,source_path=p)));v.load_image(im);assert v.error is None,v.error
        def invoke(name,args=()):
            v._value64_invoke_function(v._value_vars[im.var_names.index(name)],[value_pack_number(a)for a in args]);assert v.error is None,v.error
        v.frame_tick();assert v.error is None,v.error
        if moved:invoke('testMove');v.frame_tick()
        frames=[]
        for k in [129,129,128,131,130,133,132]:
            invoke('testStep',[k]);v.frame_tick();assert v.error is None,v.error
            if force:invoke('testRedraw')
            frames.append(bytes(v._m.canvas.back))
        return frames
    actual,expected=execute(False),execute(True)
    for step,(a,b)in enumerate(zip(actual,expected)):
        differences=[i for i,(x,y)in enumerate(zip(a,b))if x!=y]
        assert not differences,(name,moved,step,len(differences),[(i%640,i//640,a[i],b[i])for i in differences[:8]])


def test_shipping_inline_modules_equal_their_shared_sources():
    from tools.sync_toolbox_clients import sync
    assert sync()==[]


@pytest.mark.parametrize('view',[0,2])
def test_shipped_finder_overlap_focus_move_resize_close_and_scroll_match_full_repaint(tmp_path,view):
    from tools.compile_js import compile_html_text,encode_html_chunk
    from tools.toolbox_linker import build_rom
    from functional_model.storage_engine import StorageEngine
    from hardware_model.js_vm import value_pack_number
    for i in range(50):(tmp_path/f'F{i:03d}.TXT').write_text('file'+str(i))
    p=R/'storage/FINDER.HTML';html=p.read_text();at=html.rindex('</script>')
    html=html[:at]+'''function testFinder(k){
    if(k==-1)setView(VIEW);
    if(k==0)openWin(0,1,100,100,300,200,0);
    if(k==1)openWin(1,0,200,140,300,220,0);
    if(k==2)focusWin(0);if(k==3)focusWin(1);
    if(k==4){stgWrite(16393,1);moveWin(25,15);stgWrite(16385,1);}
    if(k==5){stgWrite(16393,1);sizeWin(-20,40);stgWrite(16385,1);}
    if(k==6)closeWin(1);if(k==7)scrollWin(0,1);if(k==8)scrollWin(0,-1);
    }
    function testFull(){WM.bounded=0;paint();tbUIDraw();}'''.replace('VIEW',str(view))+html[at:]
    im=ProgramImage(encode_html_chunk(compile_html_text(html,source_path=p)))
    def execute(force):
        v=JsHwVm();v._m.storage=StorageEngine(tmp_path);v._m._toolbox_sys_data=bytes(unpack(pack(R/'resources/system/system.json')));v._m._toolbox_code=build_rom()[16:]
        v.load_image(im);assert v.error is None,v.error
        v.frame_tick();v.frame_tick();assert v.error is None,v.error
        v._value64_invoke_function(v._value_vars[im.var_names.index('testFinder')],[value_pack_number(-1)]);v.frame_tick();assert v.error is None,v.error
        assert v._m.canvas.back[34*640+8]==0,"cold Finder disk frame missing"
        results=[]
        for i in range(9):
            v._value64_invoke_function(v._value_vars[im.var_names.index('testFinder')],[value_pack_number(i)]);v.frame_tick();assert v.error is None,v.error
            if force:v._value64_invoke_function(v._value_vars[im.var_names.index('testFull')],[])
            assert v.error is None,v.error
            results.append(bytes(v._m.canvas.back))
        return results
    actual,expected=execute(False),execute(True)
    for step,(a,b)in enumerate(zip(actual,expected)):
        diff=[i for i,(x,y)in enumerate(zip(a,b))if x!=y]
        assert not diff,(step,len(diff),[(i%640,i//640,a[i],b[i])for i in diff[:8]])

@pytest.mark.parametrize('moved',[False,True])
def test_shipping_session_example_clips_and_scrolls_panel_at_window_origin(moved):
    from tools.compile_js import compile_html_text,encode_html_chunk
    from tools.toolbox_linker import build_rom
    from hardware_model.js_vm import value_pack_number
    p=R/'storage/UISESS.HTML';html=p.read_text();at=html.rindex('</script>')
    html=html[:at]+'''function testPanel(){_tbSessionKey({keyCode:166,charCode:0});}
    function testMove(){_tbSessionPointer(2,{clientX:100,clientY:44,button:0});_tbSessionPointer(3,{clientX:120,clientY:64,button:0});_tbSessionPointer(4,{clientX:120,clientY:64,button:0});}'''+html[at:]
    im=ProgramImage(encode_html_chunk(compile_html_text(html,source_path=p)));v=JsHwVm();v._m._toolbox_code=build_rom()[16:];v._m._toolbox_sys_data=bytes(unpack(pack(R/'resources/system/system.json')))
    v.load_image(im);v.frame_tick();assert v.error is None,v.error
    if moved:v._value64_invoke_function(v._value_vars[im.var_names.index('testMove')],[]);v.frame_tick()
    v._value64_invoke_function(v._value_vars[im.var_names.index('testPanel')],[]);v.frame_tick();assert v.error is None,v.error
    ox=oy=20 if moved else 0;fb=v._m.canvas.back
    for y in range(96):
        expected=3 if (y//8+1)%2 else 4
        assert all(fb[(256+oy+y)*640+x]==expected for x in range(340+ox,520+ox))
    assert fb[(260+oy)*640+520+ox]not in(3,4)
