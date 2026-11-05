"""Decoder for the same SYSTEM.SYS loaded by the FPGA. No executable code."""
from pathlib import Path
import json, struct
from tools.build_system_resources import unpack, FONT as FONT_OFF, RECORDS, INDEX, CONFIG
from .desktop import FONT
DEFAULTS=json.loads((Path(__file__).resolve().parents[1]/'resources/system/defaults.json').read_text())
DEFAULT_LABELS={int(k):v for k,v in DEFAULTS['labels'].items()}
DIALOG_IDS={'open':0,'save_as':1,'changes':2,'replace':3,'message':4}

class SystemResources:
    def __init__(self,blob=None):
        self.labels=dict(DEFAULT_LABELS);self.font=FONT;self.offsets={k:(0,0) for k in DIALOG_IDS}
        self.buttons=DEFAULTS['dialog_buttons'];self.rounded=True;self.outline=True;self.status='builtin';self.data=None
        if blob is None:return
        data=unpack(blob);self.data=bytes(data)
        labels={}
        for ident in range(256):
            desc=struct.unpack_from('<I',data,INDEX+4*ident)[0];base=desc&2047;n=(desc>>11)&127
            if base+n>2048:raise ValueError('Invalid SYSTEM.SYS label range')
            labels[ident]=''.join(chr(struct.unpack_from('<H',data,RECORDS+(base+i)*2)[0]&127) for i in range(n))
        self.labels=labels;self.font={}
        for c in map(chr,range(32,127)):
            rows=struct.unpack_from('<16H',data,FONT_OFF+ord(c)*32)
            self.font[c]={'offset':0,'advance':FONT[c]['advance'],'rows':[f'{r:016b}' for r in rows]}
        for k,i in DIALOG_IDS.items():self.offsets[k]=struct.unpack_from('<hh',data,CONFIG+i*4)
        self.buttons={name:[struct.unpack_from('<HHH',data,CONFIG+24+(i*3+b)*6) for b in range(3)] for name,i in DIALOG_IDS.items()}
        self.rounded=bool(struct.unpack_from('<H',data,CONFIG+20)[0]);self.outline=bool(struct.unpack_from('<H',data,CONFIG+22)[0]);self.status='loaded'
    def label(self,ident):return self.labels.get(ident,DEFAULT_LABELS.get(ident,''))
    def translate(self,text):
        # Call only for system-owned captions, never user document contents.
        ids=[i for i in DEFAULT_LABELS if 120<=i<=169 and i!=122]+[i for i in DEFAULT_LABELS if not 120<=i<=169]
        for ident in ids:
            if DEFAULT_LABELS[ident]==text:return self.label(ident)
        return text
    def offset(self,dialog):return self.offsets.get(dialog,(0,0))
