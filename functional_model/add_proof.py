"""Conservative monotone whole-IR ADD proof. No application-name rules.

Unknown calls/classes conservatively disable the proof; unknown property values
retain hints. Heap allocation-site aliases and direct-call arguments/returns are
joined to a finite fixed point. This only removes dispatch hints, never code.
"""
from collections import deque
from .bytecode import Op
N=frozenset({'number'}); S=frozenset({'string'}); U=frozenset({'unknown'})
B=frozenset()
def join(*xs):
 r=frozenset().union(*xs)
 return U if 'unknown' in r else r

def prove(compiler, sites, max_rounds=64):
 code=compiler.code; names=compiler.names; consts=compiler.consts
 if compiler.classes:return {'safe':[], 'reason':'class/getter side effects unknown','sites':{}}
 from .jsb_format import NATIVE_IDS,NATIVE_ALIASES
 env={};heap={};returns={};entries={0:()};seen_sites={};unknown=[]
 declared={names[ins[1]] for ins in code if ins[0] in (Op.LET_VAR,Op.STORE_VAR)}
 globals_declared={names[ins[1]] for ins in code if (ins[0]==Op.LET_VAR and (len(ins)<3 or ins[2]==0)) or (ins[0]==Op.STORE_VAR and len(ins)>2 and ins[2]==1)}
 funcs={v[0]:len(v[1]) for v in compiler.functions.values() if v[0]}
 # Only declarations with no callable reference can be omitted as dead.
 # An unvisited anonymous callback or referenced function is never sufficient.
 dead_ranges=[]
 for name,(entry,params) in compiler.functions.items():
  end=compiler._fn_end.get(name,entry)
  if end<=entry:continue
  name_id=compiler.name_index.get(name)
  used=False
  for ip,ins in enumerate(code):
   if entry<=ip<end:continue
   if ins[0] in (Op.CALL_USER,Op.ADD) and len(ins)>1 and ins[1]==entry:used=True
   if ins[0]==Op.LOAD_VAR and ins[1]==name_id:used=True
   if ins[0]==Op.CALL_NATIVE and ins[1]==name_id:used=True
   if ins[0]==Op.MAKE_FN and ins[1]==entry and ip!=end:used=True
  if not used:dead_ranges.append((entry,end,name))
 changed=False
 def put(d,k,v):
  nonlocal changed
  w=join(d.get(k,B),v)
  if w!=d.get(k,B):d[k]=w;changed=True
 def call(e,args):
  nonlocal changed
  if not 0<=e<len(code):unknown.append(('entry',e));return U
  count=funcs.get(e,len(args));args=(args+[N]*count)[:count]
  old=entries.get(e)
  new=tuple(args) if old is None else tuple(join(a,b) for a,b in zip(old,args))
  if old!=new:entries[e]=new;changed=True
  return returns.get(e,B)
 def read(refs,key):
  vals=[]
  for r in refs:
   if r=='unknown':vals.append(U)
   elif r=='string':vals.append(N if key=='length' else S)
   elif isinstance(r,tuple):
    kind,at=r
    if key=='length' and kind=='array':vals.append(N)
    elif kind in ('array','object'):
     vals.append(join(N,*(v for (owner,field),v in heap.items() if owner==r)) if key=='*' else join(heap.get((r,key),N),heap.get((r,'*'),B)))
    elif kind=='event':vals.append(join(heap.get((r,key),B),heap.get((r,'*'),B),N if key in ('x','y','clientX','clientY','offsetX','offsetY','keyCode','which','button','buttons','shiftKey','ctrlKey','altKey','metaKey','repeat') else U))
    elif kind=='dom':vals.append(join(heap.get((r,key),B),heap.get((r,'*'),B),N if key in ('width','height') else U))
    else:vals.append(U)
   else:vals.append(N)
  return join(*vals)
 def write(refs,key,v):
  for r in refs:
   if isinstance(r,tuple) and r[0] in ('array','object','event','dom','context'):put(heap,(r,key),v)
   elif r=='unknown':unknown.append(('unknown-write',key))
 def native(n,args,ip):
  alias=NATIVE_ALIASES.get(n,n);nid=alias if isinstance(alias,int) else NATIVE_IDS.get(alias)
  if nid in (19,20,27,28,29,7):
   for a in args:
    for r in a:
     if isinstance(r,tuple) and r[0]=='fn':call(r[1],[frozenset({('event',0)})] if nid in (19,20) else ([N] if nid==27 else [U]*funcs.get(r[1],0)))
     elif r=='unknown':unknown.append(('callback-unknown',ip))
   return N
  if nid in (16,17,18,26):return frozenset({('dom',0)})
  if nid==34:
   r=('array',ip);put(heap,(r,'*'),join(N,*args));return frozenset({r})
  if nid==41:
   r=('array',ip);put(heap,(r,'*'),S);return frozenset({r})
  if nid in (21,24,40,68):return join(S,N) if nid in (21,68) else S
  if nid==23:return U
  if nid is not None:return N
  f=compiler.functions.get(n)
  if f:return call(f[0],args)
  unknown.append(('native',n));return U
 for iteration in range(max_rounds):
  changed=False; seen_sites={};unknown=[]
  for ctx,start_stack in list(entries.items()):
   states={ctx:start_stack};q=deque([ctx]);steps=0
   def push_state(ip,stack):
    if not 0<=ip<len(code):return
    old=states.get(ip)
    if old is not None and len(old)!=len(stack):unknown.append(('stack-join',ctx,ip));return
    new=tuple(stack) if old is None else tuple(join(a,b) for a,b in zip(old,stack))
    if new!=old:states[ip]=new;q.append(ip)
   while q:
    ip=q.popleft();st=list(states[ip]);op,*a=code[ip];nxt=ip+1;steps+=1
    if steps>len(code)*100:unknown.append(('cfg-bound',ctx));break
    def pop():return st.pop() if st else N
    def argv(n):return [pop() for _ in range(n)][::-1]
    if op==Op.LOAD_CONST:st.append(S if isinstance(consts[a[0]],str) else N)
    elif op==Op.LOAD_VAR:
     name=names[a[0]];hint=a[1] if len(a)>1 else 0;default=N if name in declared else U
     if hint==1:val=env.get((0,name),N if name in globals_declared else U)
     elif hint>=2:val=env.get((ctx,name),default)
     else:val=join(default,*(v for (c,n),v in env.items() if n==name))
     st.append(val)
    elif op in (Op.STORE_VAR,Op.LET_VAR):
     name=names[a[0]];v=pop();hint=a[1] if len(a)>1 else 0
     if op==Op.LET_VAR:put(env,(ctx,name),v)
     elif hint:put(env,(0 if hint==1 else ctx,name),v)
     else:
      put(env,(0,name),v)
      for c,n in list(env):
       if n==name:put(env,(c,n),v)
    elif op==Op.DUP:st.append(st[-1] if st else N)
    elif op==Op.POP:pop()
    elif op==Op.ADD:
     b=pop();a0=pop();seen_sites[ip]=tuple(join(x,y) for x,y in zip(seen_sites.get(ip,(B,B)),(a0,b)))
     st.append(U if 'unknown' in a0|b else join(S if 'string' in a0|b else B,N if a0-{'string'} and b-{'string'} else B))
    elif op in (Op.SUB,Op.MUL,Op.DIV,Op.MOD,Op.LT,Op.GT,Op.EQ,Op.BIT_OR,Op.BIT_AND):pop();pop();st.append(N)
    elif op in (Op.NEG,Op.NOT):pop();st.append(N)
    elif op==Op.JUMP:push_state(a[0],st);continue
    elif op==Op.JUMP_IF_FALSE:pop();push_state(a[0],st)
    elif op in (Op.RETURN,Op.RET_VAL):put(returns,ctx,pop() if op==Op.RET_VAL else N);continue
    elif op==Op.MAKE_ARRAY:
     vals=argv(a[0]);r=('array',ip);put(heap,(r,'*'),join(N,*vals));st.append(frozenset({r}))
    elif op==Op.MAKE_OBJ:st.append(frozenset({('object',ip)}))
    elif op==Op.MAKE_FN:st.append(frozenset({('fn',a[0])}));funcs[a[0]]=a[1]
    elif op==Op.ARRAY_GET:pop();r=pop();st.append(read(r,'*'))
    elif op==Op.ARRAY_SET:v=pop();pop();r=pop();write(r,'*',v);st.append(v)
    elif op==Op.GET_PROP:
     r=pop();v=read(r,names[a[0]]);st.append(v)
     if len(a)>1 and a[1]:unknown.append(('prepared-property',ip))
    elif op==Op.SET_PROP:
     v=pop();r=pop();key=names[a[0]];write(r,key,v);st.append(v)
     # The Value64 Image setter invokes an assigned onload function. Include
     # both its ADD sites and mutations even if no source CALL refers to it.
     if key=='onload':
      for fn in v:
       if isinstance(fn,tuple) and fn[0]=='fn':call(fn[1],[U]*funcs.get(fn[1],0))
       elif fn=='unknown':unknown.append(('onload-unknown',ip))
    elif op==Op.CALL_USER:args=argv(a[1]);st.append(call(a[0],args))
    elif op==Op.CALL_NATIVE:st.append(native(names[a[0]],argv(a[1]),ip))
    elif op==Op.CALL_VAL:
     args=argv(a[0]);f=pop();out=B
     for r in f:
      if isinstance(r,tuple) and r[0]=='fn':out=join(out,call(r[1],args))
      elif r=='unknown':unknown.append(('call-value',ip));out=U
      else:out=join(out,N)
     st.append(out)
    elif op==Op.CALL_METHOD:
     name=names[a[0]];args=argv(a[1]);r=pop();out=B
     if len(a)>2 and a[2]:unknown.append(('prepared-call',ip))
     for ref in r:
      typ=ref[0] if isinstance(ref,tuple) else ref
      one=frozenset({ref})
      if typ=='array' and name in ('push','unshift'):
       write(one,'*',join(*args));out=join(out,N)
      elif typ=='array' and name in ('pop','shift'):out=join(out,read(one,'*'))
      elif typ=='array' and name in ('slice','splice','concat'):
       new=('array',ip);put(heap,(new,'*'),read(one,'*'));out=join(out,frozenset({new}))
       if name=='splice':write(one,'*',join(*args[2:]))
       if name=='concat':
        for arg in args:put(heap,(new,'*'),join(arg,read(arg,'*')))
      elif typ=='array' and name in ('indexOf','includes'):out=join(out,N)
      elif typ=='array' and name in ('forEach','sort'):
       for arg in args:
        for f in arg:
         if isinstance(f,tuple) and f[0]=='fn':call(f[1],[read(one,'*'),N,one] if name=='forEach' else [read(one,'*'),read(one,'*')])
         elif f=='unknown':unknown.append(('callback-unknown',ip))
       out=join(out,one if name=='sort' else N)
      elif typ=='string' and name in ('charCodeAt','indexOf','lastIndexOf','includes','startsWith','endsWith'):out=join(out,N)
      elif typ=='string' and name in ('charAt','slice','substring','substr','toLowerCase','toUpperCase','trim','replace'):out=join(out,S)
      elif typ=='dom' and name=='getContext':out=join(out,frozenset({('context',0)}))
      elif typ=='context' and name in ('fillRect','clearRect','fillText','drawImage','beginPath','moveTo','lineTo','stroke','fill','arc','save','restore','translate','scale','setTransform','resetTransform','rect','closePath','strokeRect','putImageData'):out=join(out,N)
      elif typ=='context' and name=='measureText':
       rr=('object',ip);put(heap,(rr,'width'),N);out=join(out,frozenset({rr}))
      elif typ=='number':out=join(out,U if name in ('toString','toFixed','toPrecision') else N)
      else:unknown.append(('method',ip,name,typ));out=U
     st.append(out)
    else:unknown.append(('opcode',ip,str(op)));break
    push_state(nxt,st)
  if not changed:
   if unknown:return {'safe':[],'reason':'unknown semantics','unknown':list(dict.fromkeys(unknown))[:100],'sites':{}}
   safe=[];proof={}
   for ip in sites:
    dead=next((n for start,end,n in dead_ranges if start<=ip<end),None) if ip not in seen_sites else None
    aa,bb=seen_sites.get(ip,(N,N) if dead else (U,U));ok=('unknown' not in aa|bb and (('string' not in aa|bb) or aa==S and bb==S))
    if ok:safe.append(ip)
    proof[str(ip)]={'left':sorted(map(str,aa)),'right':sorted(map(str,bb)),'safe':ok,'unreferenced_declaration':dead}
   return {'safe':safe,'reason':'fixed point','rounds':iteration+1,'sites':proof}
 return {'safe':[],'reason':'fixed-point bound','sites':{}}
