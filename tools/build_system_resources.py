#!/usr/bin/env python3
"""Pack editable JSON into SYSTEM.SYS. Does not invoke synthesis or edit RTL.
Use --image card.img to replace only SYSTEM.SYS in an existing simulator disk.
"""
from pathlib import Path
import argparse, copy, json, struct, sys, zlib
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
# Byte ranges: font, text records, label index, headings, configuration,
# keyboard legends, ship labels, legacy About bitmap.
FONT=0; RECORDS=4096; INDEX=8192; HEADINGS=9216; CONFIG=9344
KEYS=9472; SHIP=19712; ABOUT=20224; SIZE=24320
HEADER=struct.Struct('<4sHHII')

def pack(source):
 source=Path(source); spec=json.loads(source.read_text())
 if spec.get('format')!=1:raise ValueError('Expected resource source format 1')
 font=json.loads((source.parent/spec['font']).resolve().read_text())['glyphs']
 original=json.loads((ROOT/'assets/desktop/chicago-12.json').read_text())['glyphs']
 font=copy.deepcopy(font)
 for char, glyph in spec.get('glyph_overrides',{}).items():font[char].update(glyph)
 # V1 retains proportional advances so all native hit/text geometry agrees.
 for c in map(chr,range(32,127)):
  g=font[c]
  if g['advance']!=original[c]['advance']:raise ValueError(f'V1 requires the original advance for {c!r}')
  if len(g['rows'])>16 or not 0<=g['offset']<=15 or any(not isinstance(r,str) or set(r)-{'0','1'} or len(r)+g['offset']>16 for r in g['rows']):raise ValueError(f'Invalid glyph {c!r}')
  g['bits']=[int((('0'*g['offset'])+r).ljust(16,'0'),2) for r in g['rows']]+[0]*(16-len(g['rows']))
 data=bytearray(SIZE)
 for c in range(128):
  rows=font.get(chr(c),{}).get('bits',[0]*16)
  for y,r in enumerate(rows):struct.pack_into('<H',data,FONT+2*(c*16+y),r)
 cursor=0
 labels={int(k):v for k,v in spec['labels'].items()}
 def width(s):return sum(font[c]['advance'] for c in s)
 for ident,s in sorted(labels.items()):
  if not 0<=ident<256 or not isinstance(s,str) or len(s)>127 or any(not 32<=ord(c)<=126 for c in s):raise ValueError(f'Invalid label {ident}')
  if width(s)>600:raise ValueError(f'Label {ident} exceeds 600 pixels')
  if cursor+len(s)>2048:raise ValueError('Labels exceed 2048 character records')
  struct.pack_into('<I',data,INDEX+4*ident,cursor|(len(s)<<11)|(width(s)<<18))
  for c in s:
   struct.pack_into('<H',data,RECORDS+cursor*2,(font[c]['advance']<<7)|ord(c));cursor+=1
 for ident,limit in {123:74,142:86,143:102,144:100,145:90,165:90,147:330,146:330,149:330}.items():
  if ident not in labels or width(labels[ident])>limit:raise ValueError(f'Label {ident} exceeds its {limit}-pixel control')
 if sum(len(labels[i]) for i in (110,111,112,113))>28 or sum(len(labels[i]) for i in (110,113,114))>28:
  raise ValueError('Menu headings leave too little room for application menus')
 for i in range(5):
  s=labels[110+i]
  if not 1<=len(s)<=12:raise ValueError('Menu headings must contain 1–12 characters')
  data[HEADINGS+i*16:HEADINGS+i*16+len(s)]=s.encode('ascii')
 for i,name in enumerate(('open','save_as','changes','replace','message')):
  dx,dy=spec['dialog_offsets'][name]
  if not isinstance(dx,int) or not isinstance(dy,int) or not -60<=dx<=60 or not -40<=dy<=16:raise ValueError('Dialog offsets require x -60..60 and y -40..16 (above keyboard)')
  struct.pack_into('<hh',data,CONFIG+i*4,dx,dy)
 struct.pack_into('<HH',data,CONFIG+20,int(bool(spec['rounded_buttons'])),int(bool(spec['default_button_outline'])))
 button_ids=((143,142,0),(123,142,0),(123,165,142),(144,142,0),(145,0,0))
 for d,name in enumerate(('open','save_as','changes','replace','message')):
  boxes=spec['dialog_buttons'][name]
  if len(boxes)!=3:raise ValueError('Each dialog requires three button slots (unused slots are zero)')
  for b,(x,y,w) in enumerate(boxes):
   ident=button_ids[d][b]
   if not ident:
    if [x,y,w]!=[0,0,0]:raise ValueError('Unused button slots must be zero')
   elif not all(isinstance(v,int) for v in (x,y,w)) or not (width(labels[ident])+10<=w<=180 and (110 if d==0 else 132)<=x and x+w<=(530 if d==0 else 508) and 202<=y<=246):
    raise ValueError(f'Button {name}/{b} must fit its text and dialog, below the fields')
   struct.pack_into('<HHH',data,CONFIG+24+(d*3+b)*6,x,y,w)
  for b,(x,y,w) in enumerate(boxes):
   for xx,yy,ww in boxes[b+1:]:
    if w and ww and x<xx+ww+8 and xx<x+w+8 and y<yy+34 and yy<y+34:raise ValueError(f'Overlapping buttons in {name}')
 # Preserve the established deduplicated key bitmap IDs.
 from functional_model.system_menu import KEYS as key_defs
 texts=[]
 for i,(legend,code,plain,upper) in enumerate(key_defs):
  other=chr(upper) if 32<=plain<127 and not 65<=code<=90 and len(legend)==1 else legend
  if i>=68:other='F'+str(code+2-111)
  for s in (legend,other):
   if s not in texts:texts.append(s)
 def bitmap(s,y,w):
  bits=0;pen=0
  for c in s:
   for x in range(16):
    if pen+x<w and font[c]['bits'][y]&(1<<(15-x)):bits|=1<<(w-1-pen-x)
   pen+=font[c]['advance']
  return bits
 for off,strings,w,depth in [(KEYS,texts,40,2048),(SHIP,['Keyboard','X','Hold keys','About'],64,64),(ABOUT,['Note','Help','Utility','Memory: 8 MiB','OK'],256,128)]:
  for i,s in enumerate(strings):
   for y in range(16):
    at=off+(i*16+y)*(w//8);data[at:at+w//8]=bitmap(s,y,w).to_bytes(w//8,'little')
 for i,s in enumerate(('Note','Help','Utility')):
  for y in range(16):data[ABOUT+(i*16+y)*8:ABOUT+(i*16+y+1)*8]=bitmap(s,y,64).to_bytes(8,'little')
 return HEADER.pack(b'JMRS',1,16,SIZE,zlib.crc32(data))+data

def unpack(blob):
 if len(blob)!=16+SIZE:raise ValueError('SYSTEM.SYS length mismatch')
 magic,version,head,n,crc=HEADER.unpack_from(blob)
 if (magic,version,head,n)!=(b'JMRS',1,16,SIZE):raise ValueError('SYSTEM.SYS header/version mismatch')
 if zlib.crc32(blob[16:])!=crc:raise ValueError('SYSTEM.SYS CRC mismatch')
 return blob[16:]

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('source',nargs='?',type=Path,default=ROOT/'resources/system/system.json');ap.add_argument('--output',type=Path,default=ROOT/'storage/SYSTEM.SYS');ap.add_argument('--image',type=Path);args=ap.parse_args()
 blob=pack(args.source);unpack(blob);args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(blob)
 if args.image:
  from tools.make_sd_image import patch_card_file
  patch_card_file(args.image,'SYSTEM.SYS',blob)
 print(f'{args.output}: {len(blob)} bytes, CRC {zlib.crc32(blob[16:]):08x}'+(f'; updated {args.image}' if args.image else ''))
if __name__=='__main__':main()
