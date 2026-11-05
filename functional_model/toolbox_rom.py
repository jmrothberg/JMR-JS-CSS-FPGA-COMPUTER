"""Resident Toolbox format and instruction identity shared by Python tools."""
from pathlib import Path
import struct
import zlib

WORDS=4096

def unpack_rom(blob):
    if len(blob)!=16+WORDS*4:
        raise ValueError('Toolbox ROM length')
    magic,version,header,size,crc=struct.unpack('<4sHHII',blob[:16])
    payload=blob[16:]
    if (magic,version,header,size)!=(b'JMRT',1,16,WORDS*4) or zlib.crc32(payload)!=crc:
        raise ValueError('Toolbox ROM header or CRC')
    if payload[3072*4:]!=struct.pack("<I",0x0010000b)*1024:
        raise ValueError("Toolbox ROM padding exceeds the resident bank")
    return payload

def default_code():
    path=Path(__file__).resolve().parents[1]/'vectors/toolbox_code.hex'
    words=[int(line,16) for line in path.read_text().splitlines()]
    if len(words)!=WORDS:raise ValueError('Toolbox factory bank length')
    return struct.pack('<4096I',*words)

def fingerprint(payload):
    result=0
    for (word,) in struct.iter_unpack('<I',payload):
        result=(((result<<1)|(result>>31))&0xffffffff)^word
    return result
