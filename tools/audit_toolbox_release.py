#!/usr/bin/env python3
"""Read-only audit of the actual FAT disk against a frozen Toolbox build."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from functional_model.jsb_format import ProgramImage, FLAG_TOOLBOX, TOOLBOX_WORDS
from functional_model.toolbox_rom import unpack_rom, fingerprint
from tools.make_sd_image import open_volume, card_name_83, squash_long_html_lines
from tools.toolbox_linker import prefix_bytes
from tools.compile_js import compile_html_text, encode_html_chunk
from tools.build_system_resources import unpack as unpack_sys


def required_code_words(image):
    """Include the entire runtime name table; exclude only validated debug map.

    The RTL consumes through NAMB, then stops. ProgramImage.code_end includes
    the optional SMAP and alignment bytes that the runtime never accesses.
    Reconstruct the canonical map from validated entries and match its exact
    bytes at the tail, rather than trusting a marker search in executable data.
    """
    raw=bytes(image)
    end=image.code_end
    if image.op_lines is not None:
        runs=[]
        for line in image.op_lines:
            if runs and runs[-1][0]==line and runs[-1][1]<65535:
                runs[-1]=(line,runs[-1][1]+1)
            else:
                runs.append((line,1))
        payload=struct.pack('<HHH',1,image.n_ops,len(runs))
        payload+=b''.join(struct.pack('<IH',line,count) for line,count in runs)
        section=b'SMAP'+struct.pack('<I',len(payload))+payload
        offsets=[end-pad-len(section) for pad in range(4)
                 if raw[end-pad-len(section):end-pad]==section
                 and raw[end-pad:end]==bytes(pad)]
        if len(offsets)!=1:
            raise ValueError('cannot identify exact validated trailing source map')
        end=offsets[0]
    return (end+3)//4-(TOOLBOX_WORDS if image.flags&FLAG_TOOLBOX else 0)

def audit(source_root, disk):
    source_root, disk = Path(source_root), Path(disk)
    vol = open_volume(disk)
    names = {name.upper(): name for name, _ in vol.list_root_info()}
    errors, programs = [], []
    def require(condition, message):
        if not condition:
            errors.append(message)
    def digest(data): return hashlib.sha256(data).hexdigest()
    require(ROOT.resolve()==source_root.resolve(), 'run the audit script from the frozen source/tools directory')
    sources={card_name_83(p.name).rsplit('.',1)[0]:p
             for p in (source_root/'storage').glob('*')
             if p.suffix.upper() in ('.HTML','.HTM')}
    rom = vol.read_file(names['TOOLBOX.ROM'])
    payload = unpack_rom(rom)
    require(rom == (source_root/'storage/TOOLBOX.ROM').read_bytes(), 'disk ROM differs from frozen seed')
    factory = b''.join(struct.pack('<I', int(v,16)) for v in (source_root/'vectors/toolbox_code.hex').read_text().split())
    require(factory == payload, 'ROM differs from frozen full factory instructions')
    for name, expected in [('toolbox_code0.hex',payload[:16384]), ('toolbox_code1.hex',payload[16384:24576]), ('toolbox_code2.hex',payload[24576:28672]), ('toolbox_code3.hex',payload[28672:32768])]:
        actual=b''.join(struct.pack('<I',int(v,16)) for v in (source_root/'vectors'/name).read_text().split())
        require(actual==expected, f'{name} differs from ROM physical bank')
    identity_text=(source_root/'rtl/engines/jmr_toolbox_rom_pkg.sv').read_text()
    require(int(re.search(r"DEFAULT_HASH=32'h([0-9a-fA-F]+)",identity_text)[1],16)==fingerprint(payload), 'factory identity differs from ROM')
    rtl=(source_root/'rtl/engines/jmr_toolbox.sv').read_text()
    from functional_model.toolbox import VERSION
    require(f"32'h{VERSION:08x}" in rtl and 'COPY_FB_WAIT' in rtl, 'frozen hardware lacks bitmap capability/read service')
    core=(source_root/'rtl/jmr_js_core.sv').read_text()
    require('.fb_req(tb_fb_req)' in core and '.fb_ack(tb_fb_ack)' in core, 'bitmap framebuffer read port is not wired')
    vm=(source_root/'rtl/engines/jmr_js_vm.sv').read_text()
    require('21504' in vm or '21_504' in vm, 'expected 21504-word application capacity missing')
    from tools.toolbox_manifest import build_manifest
    for resource in ('TOOLBOX.LNK','PAINT.RSC'):
        require(resource in names,f'required resource missing: {resource}')
        if resource in names:
            require(vol.read_file(names[resource])==(source_root/'storage'/resource).read_bytes(),
                    f'disk {resource} differs from source')
    if 'TOOLBOX.LNK' in names:
        require(vol.read_file(names['TOOLBOX.LNK'])==build_manifest(),'link manifest differs from current ROM/library bindings')
    sysdata=vol.read_file(names['SYSTEM.SYS'])
    unpack_sys(sysdata)
    require(sysdata==(source_root/'storage/SYSTEM.SYS').read_bytes(), 'disk SYS differs from frozen seed')
    for name in sorted(names):
        if not name.endswith('.JSH'):
            continue
        raw=vol.read_file(names[name])
        try:
            image=ProgramImage(raw)
        except ValueError as exc:
            errors.append(f'{name}: invalid ProgramImage: {exc}')
            continue
        resident=bool(image.flags & FLAG_TOOLBOX)
        require(not resident or prefix_bytes(image)==payload, f'{name}: resident instruction identity mismatch')
        physical_words=required_code_words(image)
        require(physical_words<=21504, f'{name}: code/metadata requires {physical_words} physical words')
        htmlname=name[:-4]+'.HTM'
        source=sources.get(name[:-4])
        require(htmlname in names or source is not None, f'{name}: source missing from disk and frozen package')
        source_hash=None
        card_source_hash=None
        if htmlname in names:
            html=vol.read_file(names[htmlname])
            card_source_hash=digest(html)
        if source is not None or htmlname in names:
            html=source.read_bytes() if source is not None else vol.read_file(names[htmlname])
            source_hash=digest(html)
            marked=b'jmr-toolbox: resident-v2' in html[:1024]
            require(marked==resident,f'{name}: source marker / resident image disagree')
            if htmlname in names and source is not None:
                cardhtml=vol.read_file(names[htmlname])
                require(cardhtml in (html,squash_long_html_lines(htmlname,html)[0]),
                        f'{name}: disk HTML differs from frozen authoring source')
            try:
                artname=name[:-4]+'.ART'
                art=vol.read_file(names[artname]) if artname in names else None
                rebuilt=encode_html_chunk(compile_html_text(html.decode('utf-8','replace'),
                                                           source_path=source,artx=art))
                require(rebuilt==raw,f'{name}: JSH differs from exact frozen-source compilation')
            except Exception as exc:
                errors.append(f'{name}: source recompilation failed: {exc}')
        programs.append(dict(name=name,sha256=digest(raw),source=htmlname,
                             source_sha256=source_hash,card_source_sha256=card_source_hash,
                             frozen_source=str(source.relative_to(source_root)) if source else None,resident=resident,
                             physical_code_words=physical_words,ops=image.n_ops))
    for name in ['FINDER.JSH','MACPAINT.JSH','COMPILER.JSH','UTILITY.JSH','TBDEMO.JSH','COPYDEMO.JSH']:
        require(name in names,f'required program missing: {name}')
    return dict(passed=not errors, disk=str(disk.resolve()),disk_sha256=digest(disk.read_bytes()),
                source_root=str(source_root.resolve()),rom_sha256=digest(rom),
                rom_identity=f'{fingerprint(payload):08x}',capabilities=VERSION,
                system_sha256=digest(sysdata),programs=programs,errors=errors)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root',type=Path,required=True)
    parser.add_argument('--disk',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    result=audit(args.source_root,args.disk)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(('PASS' if result['passed'] else 'FAIL'),len(result['programs']),'disk programs;',
          sum(p['resident'] for p in result['programs']),'resident clients; ROM',result['rom_identity'])
    for error in result['errors']:
        print(error)
    return 0 if result['passed'] else 1


if __name__=='__main__':
    raise SystemExit(main())
