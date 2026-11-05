"""Raw indexed rectangle transport: independent snapshot expectations."""
import pytest
from functional_model.machine import Machine
from functional_model.jsb_format import CSTG_WORDS


def descriptor(m, ptr, *, screen=False, base=2000, stride=8, width=8,
               height=4, sx=0, sy=0, w=4, h=2, dx=0, dy=0, clip=None):
    if screen:
        base, stride, width, height = 0, 640, 640, 480
    d = bytearray(64)
    d[:4] = bytes([1, 8, 2 if screen else 0, 1])
    d[4:8] = base.to_bytes(4, 'little')
    if clip is None:
        clip = (0, 0, width, height)
    for offset, value in {8:stride, 10:width, 12:height, 14:sx, 16:sy,
                          18:w, 20:h, 22:dx, 24:dy,
                          26:clip[0], 28:clip[1], 30:clip[2], 32:clip[3]}.items():
        d[offset:offset+2] = (value & 65535).to_bytes(2, 'little')
    for i, v in enumerate(d):
        m._nat_stg_write(ptr+i, v)


@pytest.mark.parametrize('src_screen,dst_screen', [(False,False),(False,True),(True,False),(True,True)])
def test_all_directions_clipping_and_palette_indices(src_screen, dst_screen):
    m = Machine()
    descriptor(m, 100, screen=src_screen, base=2000, sx=1, sy=1)
    descriptor(m, 164, screen=dst_screen, base=73724, dx=-1, dy=1,
               clip=(0, 2, 2, 1))
    for y in range(4):
        for x in range(8):
            value = 128+y*8+x
            if src_screen:
                m.canvas.back[y*640+x] = value
            else:
                m._nat_stg_write(2000+y*8+x, value)
    before = bytes(m.canvas.back) if dst_screen else bytes(int(m._nat_stg_read(73724+i)) for i in range(32))
    expected = bytearray(before)
    for x in range(2):
        expected[2*(640 if dst_screen else 8)+x] = 128+2*8+(x+2)
    assert m._nat_toolbox(6,100,164,0) == 8
    actual = bytes(m.canvas.back) if dst_screen else bytes(int(m._nat_stg_read(73724+i)) for i in range(32))
    assert actual == expected


@pytest.mark.parametrize('screen', [False, True])
@pytest.mark.parametrize('sx,sy,dx,dy', [(0,0,1,1),(1,1,0,0),(0,0,1,0),(1,0,0,0)])
def test_overlapping_rows_have_snapshot_semantics(screen,sx,sy,dx,dy):
    m = Machine()
    descriptor(m,100,screen=screen,sx=sx,sy=sy,w=6,h=3)
    descriptor(m,164,screen=screen,dx=dx,dy=dy,w=6,h=3)
    stride = 640 if screen else 8
    for y in range(4):
        for x in range(8):
            if screen:
                m.canvas.back[y*stride+x] = y*8+x
            else:
                m._nat_stg_write(2000+y*stride+x,y*8+x)
    before = bytes(m.canvas.back) if screen else bytes(int(m._nat_stg_read(2000+i)) for i in range(32))
    expected = bytearray(before)
    for y in range(3):
        for x in range(6):
            expected[(dy+y)*stride+dx+x] = before[(sy+y)*stride+sx+x]
    assert m._nat_toolbox(6,100,164,0) == 18
    actual = bytes(m.canvas.back) if screen else bytes(int(m._nat_stg_read(2000+i)) for i in range(32))
    assert actual == expected


def test_validation_is_atomic_and_descriptors_are_snapshotted():
    m = Machine()
    descriptor(m,100)
    descriptor(m,164,base=3000)
    for i in range(32):
        m._nat_stg_write(3000+i,199)
    def unchanged():
        assert [m._nat_stg_read(3000+i) for i in range(32)] == [199]*32
    for offset,value in [(0,2),(1,4),(2,1),(3,2),(18,5)]:
        old=m._nat_stg_read(164+offset)
        m._nat_stg_write(164+offset,value)
        assert m._nat_toolbox(6,100,164,0) == -1
        unchanged()
        m._nat_stg_write(164+offset,old)
    assert m._nat_toolbox(6,100,164,1) == -1
    assert m._nat_toolbox(6,CSTG_WORDS-63,164,0) == -1
    descriptor(m,164,base=CSTG_WORDS-1)
    assert m._nat_toolbox(6,100,164,0) == -1
    descriptor(m,164,base=2000,stride=9) # ambiguous alias layout
    assert m._nat_toolbox(6,100,164,0) == -1
    descriptor(m,100,w=0)
    descriptor(m,164,w=0)
    assert m._nat_toolbox(6,100,164,0) == 0
    # Overwrite the destination descriptor itself after both are captured.
    descriptor(m,100,width=64,stride=64,height=1,w=64,h=1)
    descriptor(m,164,base=164,width=64,stride=64,height=1,w=64,h=1)
    for i in range(64):
        m._nat_stg_write(2000+i,255-i)
    assert m._nat_toolbox(6,100,164,0) == 64
    assert [m._nat_stg_read(164+i) for i in range(64)] == list(range(255,191,-1))
