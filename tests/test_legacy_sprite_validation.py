"""Validate legacy sprite dimensions from serialized program bytes."""
import struct
import pytest

from functional_model.compiler import compile_source
from functional_model.jsb_format import encode_chunk
import functional_model.jsb_format as candidate

def valid():
    return encode_chunk(compile_source('var x=1;'),v2=True,value64=True,
                        sprites=[(2,2,bytes([1,2,3,4]))],aset=False)

def test_valid_legacy_sprite_image_is_validated_and_decoded():
    image=candidate.ProgramImage(valid())
    decoded=image.decode()
    assert decoded.sprites==[(2,2,bytes([1,2,3,4]))]

@pytest.mark.parametrize('width,height',[(0,2),(2,0),(512,512),(65535,65535)])
def test_decoded_zero_or_overflowing_dimensions_are_rejected(width,height):
    raw=bytearray(valid());p=raw.index(b'SPR1')+6
    struct.pack_into('<HH',raw,p,width,height)
    message='non-zero' if not width or not height else 'stream bound'
    with pytest.raises(ValueError,match=message):candidate.ProgramImage(raw)

def test_excessive_sprite_count_is_rejected():
    raw=bytearray(valid());p=raw.index(b'SPR1')+4;struct.pack_into('<H',raw,p,65535)
    with pytest.raises(ValueError,match='sprite count'):candidate.ProgramImage(raw)

def test_truncated_pixel_payload_is_rejected():
    raw=valid();end=raw.index(b'SPR1')+6+4+3
    with pytest.raises(ValueError,match='truncated.*SPR1 pixels'):candidate.ProgramImage(raw[:end])
