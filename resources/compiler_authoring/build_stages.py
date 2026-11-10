from pathlib import Path
import re,sys,json,hashlib,zlib
D=Path(__file__).resolve().parent;R=Path.cwd();J=D.parent/'json/full_string/source';sys.path[:0]=[str(D/"source"),str(R)]
# Load frozen compiler through current complete root package for capacity only;
# no newnumeric helper is present in this reachability assessment.
from tools.compile_js import compile_html_text,encode_html_chunk
from functional_model.jsb_format import ProgramImage,encode_chunk
from functional_model.compiler import _tokenize
src=(D/'numeric_unsplit.HTML').read_text();body=src.split('<script>',1)[1].split('</script>',1)[0];entries={};spans=[]
def endbrace(text,start):
 depth=0;state='';i=start
 while i<len(text):
  c=text[i];n=text[i:i+2]
  if state in ('"',"'",'`'):
   if c=='\\':i+=2;continue
   if c==state:state=''
  elif state=='//':
   if c=='\n':state=''
  elif state=='/*':
   if n=='*/':state='';i+=2;continue
  elif n in ('//','/*'):state=n;i+=2;continue
  elif c in ('"',"'",'`'):state=c
  elif c=='{':depth+=1
  elif c=='}':
   depth-=1
   if depth==0:return i+1
  i+=1
 raise ValueError(start)
for m in re.finditer(r'^function\s+(\w+)\s*\(',body,re.M):
 start=m.start();end=endbrace(body,body.index('{',m.end()));entries[m[1]]=body[start:end];spans.append((start,end))
marker=body.index('// ---- entry ---');globals=body[:marker]
for a,b in reversed(spans):
 if a<marker:globals=globals[:a]+globals[b:]
entry=body[marker:];entry=entry.replace('if (hasArt) {','if (hasArt && !retry) {',1).replace('var st = tokenize();','st = tokenize();');cut=entry.index('  layout();');error=entry.index('if (st === ST_ERR_TOKENS)')
proof=(D/'device_add_proof/device_add_proof.js').read_text()
# Proof helpers live only in the emitter reachability graph. Their exact bytes
# participate in the checked stage version, alongside the parser template.
for m in re.finditer(r'^function\s+(\w+)\s*\(',proof,re.M):
 end=endbrace(proof,proof.index('{',m.end()));entries[m[1]]=proof[m.start():end]
magic=zlib.crc32(src.encode()+b"\0"+Path(__file__).read_bytes()+b"\0"+proof.encode())
# Handoff header is private to compiler chain: 84..95. Both stages carry
# this exact version; stage1 additionally validates the complete stage2 file.
errors=entry[error:].rstrip()[:-1]
parsecut=entry.index('    buildPool();')
setup=entry[cut:entry.index('  natInit();')]
setup=setup.replace(' - GS_OFF) / 8',' - 768 - GS_OFF) / 8')
fields=['nOps','nCrec','nNames','blobLen','nFn','nCls','nNat','nFset','CALLREF','nPool','LINK_NAMES','LINK_VARS','LINK_FUNCS','LINK_BYTES','LINK_MAP','nGs','NEED_RUNTIME']
meta='(JSON_LEN?JSON_OFF:(LINK_MODE?LINK_OFF:ART_KEEP))-768'
common=f"JSON_LEN=_r16(88);if(JSON_LEN)JSON_OFF=LINK_OFF-JSON_LEN;hasArt=_gr(90);LINK_MODE=_gr(91);spanN=_r16(HDR_SPAN_N);tokN=_r32(HDR_TOK_N);if(LINK_MODE)OPS_MAX=29696;"
valid='('+' || '.join('JSON_LEN==='+str(n) for n in json.loads((D/'runtime_payload_lengths.json').read_text())['lengths'])+') &&'+f" hasArt<=1 && (LINK_MODE===0 || LINK_MODE===2) && spanN<=4096 && tokN<=TOK_MAX && TOK_OFF+tokN*TOK_STRIDE<=JSON_OFF"
entries['stageFile']='''function stageFile(mode){var path=mode===0?"COMPIL2.JSH":"COMPILER.JSH";var ptr=LINK_OFF+8176;for(var i=0;i<path.length;i++)_gw(ptr+i,strByte(path,i));_gw(ptr+path.length,0);var off=0,c=4294967295,n;while(off<262144){n=fsRead(ptr,off,stageScratch,512);if(n<0)return 0;c=crcFeed(c,stageScratch,n);off+=n;if(n<512){stageSize=off;stageCrc=4294967295-c;return 1;}}return 0;}'''
entries['stageManifest']=f"""function stageManifest(){{var path="COMPILE.LNK";var ptr=LINK_OFF+8176;for(var i=0;i<path.length;i++)_gw(ptr+i,strByte(path,i));_gw(ptr+path.length,0);if(fsRead(ptr,0,stageScratch,29)!==28)return 0;if(_r32(stageScratch)!==1129136970 || _r32(stageScratch+4)!=={magic} || linkCrc(stageScratch,24)!==_r32(stageScratch+24))return 0;stage1Bytes=_r32(stageScratch+8);stage1Crc=_r32(stageScratch+12);stage2Bytes=_r32(stageScratch+16);stage2Crc=_r32(stageScratch+20);return stage1Bytes>0&&stage1Bytes<262144&&stage2Bytes>0&&stage2Bytes<262144;}}"""
globals+='\nvar meta=0;var st=16;var stageScratch=131072;var stageSize=0;var stageCrc=0;var stage1Bytes=0;var stage1Crc=0;var stage2Bytes=0;var stage2Crc=0;\n'

main1=entry[:cut]+f"meta={meta};stageScratch=meta+128;if(!stageManifest()){{st=15;}}else{{_w32(meta+112,stage1Bytes);_w32(meta+116,stage1Crc);_w16(88,JSON_LEN);_gw(90,hasArt);_gw(91,LINK_MODE);_w32(92,linkCrc(TOK_OFF,tokN*TOK_STRIDE));_w32(84,{magic});_gw(HDR_PROGSEL,3);cdone(128,0,0);}}\n}}\n"+entry[error:]
main1=main1.replace('LINK_MODE=needsRomLink();','_w32(84,0);LINK_MODE=needsRomLink();',1)
main1=main1.replace('kwInit();','stageScratch=131072;if(!stageManifest()||!stageFile(1)||stageSize!==stage1Bytes||stageCrc!==stage1Crc||!stageFile(0)||stageSize!==stage2Bytes||stageCrc!==stage2Crc){_fail(15,83,84,65,71,69,50,0);}else{\nkwInit();',1)+'\n}'
main2=f"st=16;var hand=_r32(84);_w32(84,0);{common}\nif(hand==={magic} && {valid} && linkCrc(TOK_OFF,tokN*TOK_STRIDE)===_r32(92)){{st=0;\n"
main2+=setup+entry[entry.index('  natInit();'):parsecut]
main2+=f"meta={meta};stageScratch=meta+128;if(!stageManifest()||stage1Bytes!==_r32(meta+112)||stage1Crc!==_r32(meta+116)||!stageFile(1)||stageSize!==stage1Bytes||stageCrc!==stage1Crc){{st=15;}}else{{\n"
main2+=''.join(f'_w32(meta+{i*4},{name});' for i,name in enumerate(fields))
main2+=f"_w32(meta+120,linkCrc(OPS_OFF,GS_OFF-OPS_OFF));_w32(92,linkCrc(meta,124));_w32(84,{magic^0x50415253});_gw(HDR_PROGSEL,2);cdone(128,0,0);}}\n}}\n}}\n"+errors
emitter=f"st=16;_w32(84,0);{common}\nif({valid}){{\n"+setup+f"meta={meta};stageScratch=meta+128;if(stageManifest()&&linkCrc(meta,124)===_r32(92)&&linkCrc(OPS_OFF,GS_OFF-OPS_OFF)===_r32(meta+120)){{\n"
emitter+=''.join(f'{name}=_r32(meta+{i*4});' for i,name in enumerate(fields))
emitter+='st=0;\nif(NEED_RUNTIME||mixedResolve()){var bits=(JSON_LEN===18459||JSON_LEN===20308?1:0)|NEED_RUNTIME;if(!NEED_RUNTIME)bits=bits|2;if(!jsonLoad(bits))st=15;else{retry=1;tokN=0;tokOver=0;cSpan=-1;}}else{\n'+entry[parsecut:entry.index('\n  }\n}',parsecut)]+"\n}\n}\n}\n"+errors
main1=f"var retry=0;var phase=_r32(84);if(phase==={magic^0x50415253}){{\n"+emitter+f"\n}}if(phase!=={magic^0x50415253} || retry){{\n"+main1+"\n}"
main1=main1.replace('else if (st === 15)','else if(st===16){_fail(15,83,84,65,71,69,50,0);}else if (st === 15)')
main2=main2.replace('else if (st === 15)','else if(st===16){_fail(15,83,84,65,71,69,50,0);}else if (st === 15)')
def reachable(main):
 todo=set(re.findall(r'\b(\w+)\s*\(',main))&entries.keys();found=set()
 while todo:
  x=todo.pop()
  if x in found:continue
  found.add(x);todo|=(set(re.findall(r'\b(\w+)\s*\(',entries[x]))&entries.keys())-found
 return found
rows=[]
pending={}
stage_bytes=0;stage_crc=0
for name,main in [('COMPIL2',main2),('COMPILER',main1)]:
 keep=reachable(main);html='<script>\n'+globals+('\nvar _dp=[];\n' if name=='COMPILER' else '')+'\n'+'\n'.join(entries[n] for n in entries if n in keep)+'\n'+main+'\n</script>'
 html=html.replace('STAGE_BYTES',str(stage_bytes)).replace('STAGE_CRC',str(stage_crc))
 # Generated card sources stay inside SOURCE's64KiB bound; authoring comments
 # remain in numeric_unsplit.HTML and the separate proof source.
 compact='\n'.join(line for line in html.splitlines() if line.strip() and not line.lstrip().startswith('//'))+'\n'
 token_keys=lambda text:[t[:2] for t in _tokenize(text.split('<script>',1)[1].split('</script>',1)[0])]
 assert token_keys(compact)==token_keys(html),'source compaction changed tokens'
 assert len(compact.encode())<=65536,'generated source exceeds64KiB'
 html=compact
 p=D/'source/storage'/(name+'.HTML');pending[name+'.HTML']=html.encode()
 try:
  c=compile_html_text(html,source_path=p);c.op_lines=None;im=ProgramImage(encode_html_chunk(c));blob=bytes(im.data) if hasattr(im,'data') else im.to_bytes();pending[name+'.JSH']=blob;stage_bytes=len(blob);stage_crc=zlib.crc32(blob);row={'name':name,'functions':len(keep),'kept':sorted(keep),'ops':len(c.code),'bytes':im.code_end,'words':(im.code_end+3)//4,'vars':im.n_vars}
 except Exception as e:row={'name':name,'error':str(e),'kept':sorted(keep)}
 rows.append(row)
(D/'numeric_capacity.json').write_text(json.dumps({'status':'STAGED_SPLIT_NOT_YET_QUALIFIED','compiler_baseline_sha':hashlib.sha256((D.parent/'json/source/storage/COMPILER.HTML').read_bytes()).hexdigest(),'stages':rows},indent=2));print(json.dumps(rows,indent=2))

assert all('error' not in row for row in rows), rows
# Publish matching source/images only after both stages compile successfully.
for filename,data in pending.items():(D/'source/storage'/filename).write_bytes(data)
import struct
a=(D/'source/storage/COMPILER.JSH').read_bytes();b=(D/'source/storage/COMPIL2.JSH').read_bytes()
manifest=struct.pack('<6I',1129136970,magic,len(a),zlib.crc32(a),len(b),zlib.crc32(b))
manifest+=struct.pack('<I',zlib.crc32(manifest))
(D/'source/storage/COMPILE.LNK').write_bytes(manifest)
