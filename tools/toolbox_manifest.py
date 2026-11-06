"""Versioned on-device linker identities; generated alongside TOOLBOX.ROM."""
from pathlib import Path
import struct,zlib,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.toolbox_linker import compiler_with_library,build_rom,mark_linked
from functional_model.jsb_format import ProgramImage,NATIVE_IDS,NATIVE_ALIASES

def build_manifest():
 c=compiler_with_library();c.tokens=[];c.i=0
 image=ProgramImage.from_chunk(mark_linked(c.compile(),c),v2=True,value64=True)
 rom=build_rom(); words=struct.unpack('<8192I',rom[16:]);fingerprint=0
 for w in words:fingerprint=((fingerprint<<1)|(fingerprint>>31))&0xffffffff;fingerprint^=w
 names=list(image.names);body=bytearray()
 for name in names:
  b=name.encode('utf8');h=0
  for v in b:h=(h*31+v)&65535
  if len(b)>255:raise ValueError('Resident name exceeds on-device compiler limit')
  body+=struct.pack('<HH',len(b),h)+b
 body+=bytes(image)[16 if image.flags&2 else 12:][:image.n_consts*8]
 globals_=[names.index(n) for n in image.var_names]
 for i in globals_:body+=struct.pack('<H',i)
 for name,(entry,params) in c.functions.items():body+=struct.pack('<HHH',names.index(name),entry,len(params))
 if len(body)+64>8176:raise ValueError('Link manifest exceeds reserved scratch')
 header=struct.pack('<4sHHIIIIHHHHHH',b'JMTL',2,64,len(body),zlib.crc32(body),zlib.crc32(rom[16:]),fingerprint,len(names),image.n_consts,len(globals_),len(c.functions),8192,8191)
 return header.ljust(64,b'\0')+body

def write_manifest(root=None):
 root=Path(root) if root else Path(__file__).resolve().parents[1]
 blob=build_manifest();(root/'storage/TOOLBOX.LNK').write_bytes(blob);return blob
if __name__=='__main__':print('Wrote TOOLBOX.LNK',len(write_manifest()),'bytes')
