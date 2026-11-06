"""Pack exact MacPaint artwork into a versioned app resource, outside code."""
from pathlib import Path
import json
import struct

ROOT=Path(__file__).resolve().parents[1]
RESOURCE_BASE=373504
DESCRIPTOR_BASE=375168

def build(tables):
    fonts=sum((tables[n] for n in ('FA','FB','FC')),[])
    assert len(fonts)==95 and all(0<=n<2**35 for n in fonts)
    font=b''.join(n.to_bytes(5,'little') for n in fonts)
    widths=tables['GW'];assert len(widths)==16 and all(1<=n<=24 for n in widths)
    icons=bytearray()
    for i,w in enumerate(widths):
        rows=tables['G'+str(i)];assert len(rows)==16
        for row in rows:
            assert 0<=row<2**24
            icons.extend(((row&((1<<w)-1))<<(24-w)).to_bytes(3,'big'))
    patterns=bytes(sum((tables['P'+str(i)] for i in range(10)),[]));assert len(patterns)==304
    tones=bytes(tables['TONE']);assert len(tones)==16 and all(n<=15 for n in tones)
    payload=font+icons+bytes(widths)+patterns+tones
    header=struct.pack('<4sBBHIIHHHHH',b'JMRP',1,32,95,len(payload),sum(payload),0,475,1243,1259,1563).ljust(32,b'\0')
    assert len(payload)==1579 and RESOURCE_BASE+32+len(payload)<=DESCRIPTOR_BASE
    return header+payload

if __name__=='__main__':
    data=build(json.loads((ROOT/'resources/macpaint/tables.json').read_text()))
    (ROOT/'storage/PAINT.RSC').write_bytes(data)
    print('Wrote PAINT.RSC',len(data),'bytes; runtime',RESOURCE_BASE,'..',RESOURCE_BASE+len(data)-1)
