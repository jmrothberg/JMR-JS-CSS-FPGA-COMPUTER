"""Resident Toolbox format and instruction identity shared by Python tools."""
from pathlib import Path
import struct
import zlib

WORDS=8192
PHYSICAL_WORDS=8191  # mutable physical instructions; WORDS includes fixed final jump
MUTABLE_WORDS=8191
ROM_VERSION=2

def unpack_rom(blob):
    if len(blob)!=16+WORDS*4:
        raise ValueError('Toolbox ROM length')
    magic,version,header,size,crc=struct.unpack('<4sHHII',blob[:16])
    payload=blob[16:]
    if (magic,version,header,size)!=(b'JMRT',ROM_VERSION,16,WORDS*4) or zlib.crc32(payload)!=crc:
        raise ValueError('Toolbox ROM header or CRC')
    if payload[MUTABLE_WORDS*4:]!=struct.pack("<I",0x0020000b):
        raise ValueError("Toolbox ROM padding exceeds the resident bank")
    return payload

def default_code():
    path=Path(__file__).resolve().parents[1]/'vectors/toolbox_code.hex'
    words=[int(line,16) for line in path.read_text().splitlines()]
    if len(words)!=WORDS:raise ValueError('Toolbox factory bank length')
    return struct.pack('<8192I',*words)

def fingerprint(payload):
    result=0
    for (word,) in struct.iter_unpack('<I',payload):
        result=(((result<<1)|(result>>31))&0xffffffff)^word
    return result
