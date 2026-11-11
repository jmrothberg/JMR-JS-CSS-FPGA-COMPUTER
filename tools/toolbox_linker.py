"""Compile the fixed resident JavaScript prelude before application symbols.

The instruction bank is shared; globals/heap/constant/name bindings are per
application. A changed library requires relinking clients and rebuilding its
ROM image, not rebuilding FPGA logic once the bank interface is installed.
"""
from pathlib import Path
import struct,zlib,re
from functional_model.compiler import Compiler,_tokenize,_isolate_iife_modules,prepare_software_source
from functional_model.bytecode import Op
from functional_model.jsb_format import ProgramImage,FLAG_ASET
ROOT=Path(__file__).resolve().parents[1]
WORDS=8192
PHYSICAL_WORDS=8191  # mutable physical instructions; WORDS includes fixed final jump
MUTABLE_WORDS=8191

def local_aliases(c):
    aliases={}
    for start,end in c._compact_leaf_ranges:
        candidates={};blocked=set()
        for ip in range(start,end):
            ins=c.code[ip];slot=None
            if ins[0] not in (Op.LOAD_VAR,Op.STORE_VAR,Op.LET_VAR):continue
            name=c.names[ins[1]]
            if ins[0] in (Op.LOAD_VAR,Op.STORE_VAR) and len(ins)>2 and 2<=ins[2]<18:
                slot=ins[2]-2
            elif ins[0]==Op.LET_VAR and len(ins)>3 and ins[2] and 0<=ins[3]<16:
                slot=ins[3]
            if slot is None:blocked.add(name)
            elif name in candidates and candidates[name]!=slot:blocked.add(name)
            else:candidates[name]=slot
        for ip in range(start,end):
            ins=c.code[ip]
            if ins[0] in (Op.LOAD_VAR,Op.STORE_VAR,Op.LET_VAR):
                name=c.names[ins[1]]
                if name in candidates and name not in blocked:aliases[ip]='@local'+str(candidates[name])
    return aliases

def mark_linked(chunk,c):
    chunk.toolbox_resident=True
    chunk.resident_global_names=list(c._resident_global_names)
    # Leaf alias optimization is preserved separately, not enabled for release.
    return chunk

def library_source():
    from tools.toolbox_state import compact_state
    raw='\n'.join((ROOT/'resources/toolbox'/n).read_text()
                  for n in ('toolbox.js','ui.js','session.js','documents.js'))
    from tools.build_system_resources import ui_width_codes
    expected=ui_width_codes(ROOT/'resources/system/system.json')
    match=re.search(r'_tbWidths.push\(strByte\("([A-Z]+)",i\)-64\)',raw)
    if match is None or match[1]!=expected:
        raise ValueError('Toolbox generated advances differ from canonical SYSTEM font')
    return compact_state(raw)[0]

def compiler_with_library():
    c=Compiler(library_source());c.optimize=False;c.compile()
    # The encoder interns string literals after symbols. Reserve their names
    # before app symbols so library operands stay identical across clients.
    for value in c.consts:
        if isinstance(value,str):c._name(value)
    refs={c.names[ins[1]] for ins in c.code if ins[0] in (Op.LOAD_VAR,Op.STORE_VAR,Op.LET_VAR)}
    c._resident_global_names=[name for name in c.names if name in refs]
    if len(c.code)>MUTABLE_WORDS:raise ValueError('Toolbox exceeds its resident instruction bank')
    while len(c.code)<WORDS:
        c.code.append((Op.JUMP,WORDS));c.op_lines.append(0)
    return c

def compile_linked(source):
    c=compiler_with_library()
    source=prepare_software_source(source, proof_compiler=c)
    protected=set(c._hoisted_fn_names) | {name for name in c.names if name.startswith("_tb")}
    protected|={c.names[ins[1]] for ins in c.code if ins[0]==Op.CALL_NATIVE}
    probe=Compiler(source);probe._prescan_function_names()
    if protected & probe._hoisted_fn_names:
        raise ValueError('Application redefines a Toolbox function')
    c.tokens=_isolate_iife_modules(_tokenize(source));c.i=0;c.optimize=True
    c._require_concat_helper=True
    return mark_linked(c.compile(),c)

def prefix_bytes(image):
    off=(16 if image.flags&FLAG_ASET else 12)+image.n_consts*8
    return bytes(image)[off:off+WORDS*4]

def build_rom():
    c=compiler_with_library();c.tokens=[];c.i=0
    chunk=mark_linked(c.compile(),c)
    image=ProgramImage.from_chunk(chunk,v2=True,value64=True)
    payload=prefix_bytes(image)
    return struct.pack('<4sHHII',b'JMRT',2,16,len(payload),zlib.crc32(payload))+payload

if __name__=='__main__':
    blob=build_rom()
    (ROOT/'storage/TOOLBOX.ROM').write_bytes(blob)
    words=struct.unpack('<8192I',blob[16:])
    (ROOT/'vectors/toolbox_code.hex').write_text(''.join(f'{w:08x}\n' for w in words))
    (ROOT/'vectors/toolbox_code0.hex').write_text(''.join(f'{w:08x}\n' for w in words[:4096]))
    (ROOT/'vectors/toolbox_code1.hex').write_text(''.join(f'{w:08x}\n' for w in words[4096:6144]))
    (ROOT/'vectors/toolbox_code2.hex').write_text(''.join(f'{w:08x}\n' for w in words[6144:7168]))
    (ROOT/'vectors/toolbox_code3.hex').write_text(''.join(f'{w:08x}\n' for w in words[7168:8192]))
    fingerprint=0
    for word in words:fingerprint=((fingerprint<<1)|(fingerprint>>31))&0xffffffff;fingerprint^=word
    (ROOT/'rtl/engines/jmr_toolbox_rom_pkg.sv').write_text(
        '// Generated by tools/toolbox_linker.py; code identity, not a security hash.\n'
        'package jmr_toolbox_rom_pkg;\n'
        f'localparam logic [31:0] DEFAULT_HASH=32\'h{fingerprint:08x};\n'
        f'localparam logic [31:0] PADDING=32\'h{words[MUTABLE_WORDS]:08x};\n'
        'endpackage\n')
    print('Wrote TOOLBOX.ROM and default instruction hex:',len(blob),'bytes')
    from tools.toolbox_manifest import write_manifest
    print('Wrote matching TOOLBOX.LNK:',len(write_manifest(ROOT)),'bytes')
