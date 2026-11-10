"""Lower declarative UI into resident software calls, never copied renderers.

This pass preserves the original text outside exact token spans. It is enabled
only for explicitly migrated clients, not the library or standalone compiler.
"""
import ast
import json
from functional_model.compiler import _TOKEN, CompileError
from functional_model.classic_ui import parse_menus, parse_owned_menus, parse_about

FIELDS = {name: i for i, name in enumerate((
    'systemWindow', 'systemViewport', 'systemAbout', 'systemMenus', 'systemTitle',
    'systemMenuEnable', 'systemMenuCheck', 'windowScroll', 'windowScrollX', 'windowDirty'))}

def codes(text):
    if any(not 32 <= ord(c) <= 126 for c in text):
        raise ValueError('Software UI labels require printable ASCII')
    return [ord(c) for c in text]

def lower(source):
    tokens=[m for m in _TOKEN.finditer(source) if m.lastgroup not in ('WS','LINE_COMMENT','BLOCK_COMMENT')]
    edits=[];i=0
    while i<len(tokens):
        t=tokens[i];name=t.group()
        if (i+3<len(tokens) and t.lastgroup=='ID' and tokens[i+1].group()=='.'
                and tokens[i+2].group() in FIELDS and tokens[i+3].group()=='='):
            prop=tokens[i+2].group();j=i+4;depth=0;end=j
            while end<len(tokens):
                text=tokens[end].group()
                if depth==0 and (text in (';',')','}') or
                        (end>j and '\n' in source[tokens[end-1].end():tokens[end].start()])):
                    break
                if text in ('(','[','{'):depth+=1
                if text in (')',']','}'):depth-=1
                end+=1
            if end==j:raise CompileError('Missing UI property value')
            raw=source[tokens[j].start():tokens[end-1].end()]
            field=FIELDS[prop]
            if prop in ('systemAbout','systemMenus','systemTitle'):
                if end == j+1 and tokens[j].lastgroup in ('STR','STR2'):
                    value=ast.literal_eval(raw)
                    if prop=='systemAbout':parse_about(value)
                    if prop=='systemTitle':codes(value)
                    if prop=='systemMenus':
                        (parse_owned_menus if value.startswith('File|') else parse_menus)(value)
                if prop=='systemMenus':replacement=f'tbSessionMenus({name},{raw})'
                else:replacement=f'tbSessionProperty({name},{field},{raw})'
            else:
                replacement=f'tbSessionProperty({name},{field},{raw})'
            edits.append((t.start(),tokens[end-1].end(),replacement));i=end;continue
        if name in ('addEventListener','requestAnimationFrame') and i+1<len(tokens) and tokens[i+1].group()=='(':
            start=t.start()
            if i>=2 and tokens[i-1].group()=='.' and tokens[i-2].lastgroup=='ID':start=tokens[i-2].start()
            edits.append((start,t.end(),'tbSessionListen' if name=='addEventListener' else 'tbSessionFrame'))
        if name=='setTransform' and i>=2 and tokens[i-1].group()=='.' and tokens[i-2].lastgroup=='ID':
            edits.append((tokens[i-2].start(),t.end(),'tbSessionTransform'))
        i+=1
    for start,end,replacement in sorted(edits,reverse=True):
        source=source[:start]+replacement+source[end:]
    return bounded_menu_specs(source)


def bounded_menu_specs(source):
    """Keep each interned menu string within the device token's 255 bytes."""
    tokens=[m for m in _TOKEN.finditer(source) if m.lastgroup not in ('WS','LINE_COMMENT','BLOCK_COMMENT')]
    edits=[]
    for i,t in enumerate(tokens):
        if i<4 or t.lastgroup not in ('STR','STR2'):continue
        if [x.group() for x in tokens[i-4:i-1]]!=['tbSessionMenus','(',tokens[i-2].group()]:continue
        if tokens[i-1].group()!=',':continue
        value=ast.literal_eval(t.group())
        if len(value.encode('utf8'))<=255:continue
        pieces=value.split(';')
        if any(len(v.encode('utf8'))>255 for v in pieces):
            raise CompileError('Each session menu must fit a 255-byte interned string')
        edits.append((t.start(),t.end(),json.dumps(pieces)))
    for start,end,value in reversed(edits):source=source[:start]+value+source[end:]
    return source
