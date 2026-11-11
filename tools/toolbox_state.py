"""Group private library state into normal per-application JS objects.

Source stays readable. This is a build-time transformation of the library only,
not an interpreter or app rewrite. Public calls and hot drawing handles stay
unchanged. Each state object has at most sixteen fields.
"""
import ast
import re
from functional_model.compiler import _TOKEN

# Plain globals: read often enough that a field lookup would cost bank words.
KEEP={'_tbMenu','_tbDialog','_tbSRole','_tbY','_tbPortRect','_tbX','_tbW','_tbSExtras','_tbC','_tbD','_tbFont','_tbReady','_tbWidths','_tbGlyph','_tbValue','_tbSelection','_tbChanged','_tbCaret','_tbMenus','_tbTop','_tbArmed','_tbWhite','_tbDamage','_tbSDCommand','_tbNameSelect','_tbChoices','_tbH'}

def split_declarations(text):
    parts=[];start=0;depth=0
    for match in _TOKEN.finditer(text):
        if match.lastgroup in ('STR','STR2','TMPL','LINE_COMMENT','BLOCK_COMMENT','WS'):continue
        ch=match.group()
        if ch in ('[','{','('):depth+=1
        elif ch in (']','}',')'):depth-=1
        elif ch==',' and depth==0:parts.append(text[start:match.start()].strip());start=match.end()
    parts.append(text[start:].strip())
    return parts

def apply_names(source,mapping):
    edits=[(m.start(),m.end(),mapping[m.group()]) for m in _TOKEN.finditer(source)
           if m.lastgroup=='ID' and m.group() in mapping]
    for start,end,value in reversed(edits):source=source[:start]+value+source[end:]
    return source

def compact_state(source):
    declarations=[];values={};edits=[]
    for match in re.finditer(r'^var\s+(_tb[^\n]+);\s*$',source,re.M):
        keep=[]
        for item in split_declarations(match[1]):
            name,sep,expr=item.partition('=');name=name.strip()
            if not sep or name in KEEP or not re.fullmatch(r'_tb\w+',name):keep.append(item);continue
            try:ast.literal_eval(expr.strip())
            except (ValueError,SyntaxError):keep.append(item);continue
            if name in values:raise ValueError('Duplicate Toolbox state '+name)
            declarations.append(name);values[name]=expr.strip()
        edits.append((match.start(),match.end(),'var '+','.join(keep)+';\n' if keep else ''))
    mapping={};objects=[]
    for start in range(0,len(declarations),16):
        obj='_tbState'+str(start//16);fields=[]
        for name in declarations[start:start+16]:
            field=name[3:];field=field[:1].lower()+field[1:]
            mapping[name]=obj+'.'+field;fields.append(field+':'+values[name])
        objects.append('var '+obj+'={'+','.join(fields)+'};')
    for start,end,value in reversed(edits):source=source[:start]+value+source[end:]
    return '\n'.join(objects)+'\n'+apply_names(source,mapping),mapping
