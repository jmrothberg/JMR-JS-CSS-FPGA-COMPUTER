// Bounded conservative emitted-IR mixed-ADD proof. Scratch only; commit last.
// Value IDs:0 bottom,1 non-string primitive,2 string,3 unknown; others point
// into canonical {flags,count,next,sorted allocation/function atoms} records.
// Atom high16:1array,2object,3function,4DOM,5context,6event; low16 allocationIP.
var _dp=[];
function _dpTake(n){var a=_dp[4];if(n<0||a+n>_dp[5]){_dp[0]=1;return 0;}_dp[4]=a+n;return a;}
function _dpZero(a,n){for(var i=0;i<n;i++)_gw(a+i,0);}
function _dpFlags(v){return v<4?(v===3?4:v):_gr(_dp[6]+v);}
function _dpCount(v){return v<4?0:_gr(_dp[6]+v+1);}
function _dpAtom(v,i){return _r32(_dp[6]+v+4+i*4);}
function _dpIntern(f,n){
 var h=f,i=0,p=0,q=0,s=0;
 if(f&4)return 3;if(n===0)return f;
 if(n>64){_dp[0]=1;return 3;}
 for(i=0;i<n;i++)h=(h*31+_r32(_dp[32]+i*4))%512;
 p=_r16(_dp[8]+h*2);
 while(p){if(_dpFlags(p)===f&&_dpCount(p)===n){s=1;for(i=0;i<n;i++)if(_dpAtom(p,i)!==_r32(_dp[32]+i*4))s=0;if(s)return p;}p=_r16(_dp[6]+p+2);}
 p=_dp[7];q=4+n*4;if(p+q>12288){_dp[0]=1;return 3;}_dp[7]=p+q;
 _gw(_dp[6]+p,f);_gw(_dp[6]+p+1,n);_w16(_dp[6]+p+2,_r16(_dp[8]+h*2));
 for(i=0;i<n;i++)_w32(_dp[6]+p+4+i*4,_r32(_dp[32]+i*4));_w16(_dp[8]+h*2,p);return p;
}
function _dpRef(a){_w32(_dp[32],a);return _dpIntern(0,1);}
function _dpJoin(a,b){
 if(a===b||b===0)return a;if(a===0)return b;
 var f=_dpFlags(a)|_dpFlags(b),i=0,j=0,n=0,x=0,y=0,na=_dpCount(a),nb=_dpCount(b);
 if(f&4)return 3;
 while(i<na||j<nb){x=i<na?_dpAtom(a,i):999999;y=j<nb?_dpAtom(b,j):999999;if(n>=64){_dp[0]=1;return 3;}if(x<=y){_w32(_dp[32]+n*4,x);i++;if(x===y)j++;}else{_w32(_dp[32]+n*4,y);j++;}n++;}
 return _dpIntern(f,n);
}
function _dpBit(a,i){return (_gr(a+Math.floor(i/8))&_dp[48+i%8])?1:0;}
function _dpSet(a,i){var p=a+Math.floor(i/8);_gw(p,_gr(p)|_dp[48+i%8]);}
function _dpName(ip,a){if(LINK_MODE&&ip<8192){if(a>=LINK_VARS){_dp[0]=1;return 0;}a=_r16(LINK_MAP+a*2);}if(a>=nNames){_dp[0]=1;return 0;}return a;}
function _dpEq(a,s){if(a<0||a>=nNames||nLen(a)!==s.length)return 0;for(var i=0;i<s.length;i++)if(_gr(NBLOB_OFF+nBlob(a)+i)!==strByte(s,i))return 0;return 1;}
// Sparse variable rows:context,name,value,next. Context is function-entry IP.
function _dpEnv(c,n,v,w){
 var h=(c*31+n)%1024,p=_r16(_dp[11]+h*2),q=0,r=0;
 while(p){q=_dp[9]+(p-1)*8;if(_r16(q)===c&&_r16(q+2)===n){r=_r16(q+4);if(w){v=_dpJoin(r,v);if(v!==r){_w16(q+4,v);_dp[1]=1;}}return w?v:r;}p=_r16(q+6);}
 if(!w)return -1;if(_dp[10]>=2048){_dp[0]=1;return 3;}p=_dp[10]+1;_dp[10]=p;q=_dp[9]+(p-1)*8;
 _w16(q,c);_w16(q+2,n);_w16(q+4,v);_w16(q+6,_r16(_dp[11]+h*2));_w16(_dp[11]+h*2,p);_dp[1]=1;return v;
}
function _dpLoad(c,n,h){
 var v=0,i=0,p=0;
 if(h===1){v=_dpEnv(0,n,0,0);return v<0?(_gr(_dp[36]+n)&2?1:3):v;}
 if(h>=2){v=_dpEnv(c,n,0,0);return v<0?(_gr(_dp[36]+n)&1?1:3):v;}
 v=_gr(_dp[36]+n)&1?1:3;for(i=0;i<_dp[10];i++){p=_dp[9]+i*8;if(_r16(p+2)===n)v=_dpJoin(v,_r16(p+4));}return v;
}
function _dpStore(c,n,h,v,letv){
 var i=0,p=0,k=_dp[10];if(letv){_dpEnv(c,n,v,1);return;}if(h){_dpEnv(h===1?0:c,n,v,1);return;}
 _dpEnv(0,n,v,1);for(i=0;i<k;i++){p=_dp[9]+i*8;if(_r16(p+2)===n)_dpEnv(_r16(p),n,v,1);}
}
// Sparse heap rows:owner32,field16,value16,next16,pad16.
function _dpHeap(a,k,v,w){
 var h=(a*17+k)%512,p=_r16(_dp[14]+h*2),q=0,r=0;
 while(p){q=_dp[12]+(p-1)*12;if(_r32(q)===a&&_r16(q+4)===k){r=_r16(q+6);if(w){v=_dpJoin(r,v);if(v!==r){_w16(q+6,v);_dp[1]=1;}}return w?v:r;}p=_r16(q+8);}
 if(!w)return 0;if(_dp[13]>=512){_dp[0]=1;return 3;}p=_dp[13]+1;_dp[13]=p;q=_dp[12]+(p-1)*12;
 _w32(q,a);_w16(q+4,k);_w16(q+6,v);_w16(q+8,_r16(_dp[14]+h*2));_w16(_dp[14]+h*2,p);_dp[1]=1;return v;
}
function _dpWrite(v,k,x){
 if(_dpFlags(v)&4){_dp[42]=1;return;}for(var i=0;i<_dpCount(v);i++){var a=_dpAtom(v,i);var t=Math.floor(a/65536);if(t===1||t===2||t===4||t===5||t===6)_dpHeap(a,k,x,1);}
}
function _dpRead(v,k){
 var out=0,i=0,a=0,t=0,x=0,j=0,p=0,f=_dpFlags(v);
 if(f&4)return 3;if(f&1)out=1;if(f&2)out=_dpJoin(out,_dpEq(k,"length")?1:2);
 for(i=0;i<_dpCount(v);i++){
  a=_dpAtom(v,i);t=Math.floor(a/65536);x=1;
  if(t===1&&_dpEq(k,"length"))x=1;
  else if(t===1||t===2){x=_dpJoin(1,_dpHeap(a,65535,0,0));if(k===65535){for(j=0;j<_dp[13];j++){p=_dp[12]+j*12;if(_r32(p)===a)x=_dpJoin(x,_r16(p+6));}}else x=_dpJoin(x,_dpHeap(a,k,0,0));}
  else if(t===4||t===6){x=3;if(t===4&&(_dpEq(k,"width")||_dpEq(k,"height")))x=1;if(t===6&&(_dpEq(k,"x")||_dpEq(k,"y")||_dpEq(k,"clientX")||_dpEq(k,"clientY")||_dpEq(k,"offsetX")||_dpEq(k,"offsetY")||_dpEq(k,"keyCode")||_dpEq(k,"which")||_dpEq(k,"button")||_dpEq(k,"buttons")||_dpEq(k,"shiftKey")||_dpEq(k,"ctrlKey")||_dpEq(k,"altKey")||_dpEq(k,"metaKey")||_dpEq(k,"repeat")))x=1;x=_dpJoin(x,_dpHeap(a,k,0,0));x=_dpJoin(x,_dpHeap(a,65535,0,0));}
  else x=3;out=_dpJoin(out,x);
 }return out;
}
function _dpArity(e){
 var i=0,a=0;if(LINK_MODE&&e<8192){for(i=0;i<LINK_FUNCS;i++)if(fnEntry(i)===e)return _gr(FN_OFF+i*8+4);_dp[0]=1;return 0;}
 if(e>0&&opCode(e-1)===11){a=opA0(e-1);if(a<nOps&&opCode(a)===33&&opA0(a)===e)return opA1(a)&63;}
 for(i=0;i<nFn;i++)if(fnEntry(i)===e)return _gr(FN_OFF+i*8+4);
 _dp[0]=1;return 0;
}
// Function records:entry16,argc8,active8,return16,argptr16,next16,pad16.
function _dpFn(e,create){
 var h=e%512,p=_r16(_dp[17]+h*2),q=0,n=0,a=0;
 while(p){q=_dp[15]+(p-1)*12;if(_r16(q)===e)return p;p=_r16(q+8);}if(!create)return 0;
 n=e===0?0:_dpArity(e);if(n>64||_dp[16]>=384||_dp[19]+n*2>4096){_dp[0]=1;return 0;}p=_dp[16]+1;_dp[16]=p;q=_dp[15]+(p-1)*12;
 a=_dp[18]+_dp[19];_dp[19]=_dp[19]+n*2;_w16(q,e);_gw(q+2,n);_gw(q+3,1);_w16(q+4,0);_w16(q+6,a);_w16(q+8,_r16(_dp[17]+h*2));_w16(_dp[17]+h*2,p);_dpZero(a,n*2);_dp[1]=1;return p;
}
function _dpCall(e,n){
 if(e<=0||e>=nOps){_dp[0]=1;return 3;}var p=_dpFn(e,1),q=0,i=0,a=0,v=0,x=0;if(!p)return 3;q=_dp[15]+(p-1)*12;a=_r16(q+6);
 for(i=0;i<_gr(q+2);i++){v=i<n?_r16(_dp[31]+i*2):1;x=_r16(a+i*2);v=_dpJoin(x,v);if(v!==x){_w16(a+i*2,v);_dp[1]=1;}}return _r16(q+4);
}
function _dpPush(v){if(_dp[30]>=256){_dp[0]=1;return;}_w16(_dp[29]+_dp[30]*2,v);_dp[30]++;}
function _dpPop(){if(!_dp[30])return 1;_dp[30]--;return _r16(_dp[29]+_dp[30]*2);}
function _dpArgs(n){if(n>64){_dp[0]=1;return;}for(var i=n-1;i>=0;i--)_w16(_dp[31]+i*2,_dpPop());}
function _dpCallback(v,kind,x,y,z){
 if(_dpFlags(v)&4){_dp[42]=1;return;}var i=0,a=0,n=0,j=0;
 for(i=0;i<_dpCount(v);i++){a=_dpAtom(v,i);if(Math.floor(a/65536)===3){n=kind===0?_dpArity(a%65536):kind;if(n>64){_dp[0]=1;return;}for(j=0;j<n;j++)_w16(_dp[31]+j*2,kind===0?3:(j===0?x:(j===1?y:z)));_dpCall(a%65536,n);}}
}
// Block records:context16,ip16,depth16,snapshot16,generation8,pending8,next16.
function _dpQueue(p){var q=_dp[20]+(p-1)*12;if(_gr(q+9))return;if(_dp[28]>=4096){_dp[0]=1;return;}_w16(_dp[25]+_dp[27]*2,p);_dp[27]=(_dp[27]+1)%4096;_dp[28]++;_gw(q+9,1);}
function _dpState(c,ip){
 if(ip<0||ip>=nOps)return;var h=(c*31+ip)%2048,p=_r16(_dp[22]+h*2),q=0,a=0,i=0,v=0,x=0,dirty=0,fresh=0;
 while(p){q=_dp[20]+(p-1)*12;if(_r16(q)===c&&_r16(q+2)===ip)break;p=_r16(q+10);}
 if(!p){if(_dp[21]>=4096||_dp[24]+_dp[30]*2>4096){_dp[0]=1;return;}p=_dp[21]+1;_dp[21]=p;q=_dp[20]+(p-1)*12;a=_dp[24];_dp[24]=_dp[24]+_dp[30]*2;_w16(q,c);_w16(q+2,ip);_w16(q+4,_dp[30]);_w16(q+6,a);_gw(q+8,0);_gw(q+9,0);_w16(q+10,_r16(_dp[22]+h*2));_w16(_dp[22]+h*2,p);}
 if(_r16(q+4)!==_dp[30]){_dp[0]=1;return;}a=_dp[23]+_r16(q+6);fresh=_gr(q+8)!==_dp[2];dirty=fresh;
 for(i=0;i<_dp[30];i++){x=_r16(_dp[29]+i*2);v=fresh?x:_dpJoin(_r16(a+i*2),x);if(fresh||v!==_r16(a+i*2)){_w16(a+i*2,v);dirty=1;}}
 _gw(q+8,_dp[2]);if(dirty)_dpQueue(p);
}
function _dpNative(ip,a,n){
 var id=a,i=0,v=0,r=0,k=0;
 if(!(LINK_MODE&&ip<8192)){i=fnFind(a);if(i>=0)return _dpCall(fnEntry(i),n);id=natIdOf(a);}
 if(id<0){_dp[0]=1;return 3;}
 if(id===19||id===20||id===27||id===28||id===29||id===7){for(i=0;i<n;i++)v=_dpJoin(v,_r16(_dp[31]+i*2));_dpCallback(v,id===19||id===20?1:(id===27?1:0),id===27?1:_dpRef(393216),1,1);return 1;}
 if(id===16||id===17||id===18||id===26)return _dpRef(262144);
 if(id===34){r=65536+ip;v=1;for(i=0;i<n;i++)v=_dpJoin(v,_r16(_dp[31]+i*2));_dpHeap(r,65535,v,1);return _dpRef(r);}
 if(id===41){r=65536+ip;_dpHeap(r,65535,2,1);return _dpRef(r);}
 if(id===21||id===68)return _dpJoin(1,2);if(id===24||id===40)return 2;if(id===23)return 3;return 1;
}
function _dpMethod(ip,k,n,v){
 var out=0,i=0,a=0,t=0,x=0,j=0,r=0,f=_dpFlags(v),cb=0;
 if(f&4){_dp[42]=1;return 3;}
 if(f&1)out=_dpEq(k,"toString")||_dpEq(k,"toFixed")||_dpEq(k,"toPrecision")?3:1;
 if(f&2){if(_dpEq(k,"charCodeAt")||_dpEq(k,"indexOf")||_dpEq(k,"lastIndexOf")||_dpEq(k,"includes")||_dpEq(k,"startsWith")||_dpEq(k,"endsWith"))out=_dpJoin(out,1);else if(_dpEq(k,"charAt")||_dpEq(k,"slice")||_dpEq(k,"substring")||_dpEq(k,"substr")||_dpEq(k,"toLowerCase")||_dpEq(k,"toUpperCase")||_dpEq(k,"trim")||_dpEq(k,"replace"))out=_dpJoin(out,2);else{_dp[0]=1;return 3;}}
 // Save callback union before callbacks reuse argument scratch.
 for(j=0;j<n;j++)cb=_dpJoin(cb,_r16(_dp[31]+j*2));
 for(i=0;i<_dpCount(v);i++){
  a=_dpAtom(v,i);t=Math.floor(a/65536);r=_dpRef(a);x=0;
  if(t===1&&(_dpEq(k,"push")||_dpEq(k,"unshift"))){_dpWrite(r,65535,cb);x=1;}
  else if(t===1&&(_dpEq(k,"pop")||_dpEq(k,"shift")))x=_dpRead(r,65535);
  else if(t===1&&(_dpEq(k,"slice")||_dpEq(k,"splice")||_dpEq(k,"concat"))){x=_dpRead(r,65535);_dpHeap(65536+ip,65535,x,1);if(_dpEq(k,"splice")){for(j=2;j<n;j++)_dpWrite(r,65535,_r16(_dp[31]+j*2));}if(_dpEq(k,"concat")){for(j=0;j<n;j++){x=_r16(_dp[31]+j*2);_dpHeap(65536+ip,65535,_dpJoin(x,_dpRead(x,65535)),1);}}x=_dpRef(65536+ip);}
  else if(t===1&&(_dpEq(k,"indexOf")||_dpEq(k,"includes")))x=1;
  else if(t===1&&(_dpEq(k,"forEach")||_dpEq(k,"sort"))){x=_dpRead(r,65535);_dpCallback(cb,_dpEq(k,"forEach")?3:2,x,_dpEq(k,"forEach")?1:x,r);x=_dpEq(k,"sort")?r:1;}
  else if(t===4&&_dpEq(k,"getContext"))x=_dpRef(327680);
  else if(t===5&&(_dpEq(k,"fillRect")||_dpEq(k,"clearRect")||_dpEq(k,"fillText")||_dpEq(k,"drawImage")||_dpEq(k,"beginPath")||_dpEq(k,"moveTo")||_dpEq(k,"lineTo")||_dpEq(k,"stroke")||_dpEq(k,"fill")||_dpEq(k,"arc")||_dpEq(k,"save")||_dpEq(k,"restore")||_dpEq(k,"translate")||_dpEq(k,"scale")||_dpEq(k,"setTransform")||_dpEq(k,"resetTransform")||_dpEq(k,"rect")||_dpEq(k,"closePath")||_dpEq(k,"strokeRect")||_dpEq(k,"putImageData")))x=1;
  else if(t===5&&_dpEq(k,"measureText")){for(j=0;j<nNames;j++)if(_dpEq(j,"width"))_dpHeap(131072+ip,j,1,1);x=_dpRef(131072+ip);}
  else{_dp[0]=1;return 3;}out=_dpJoin(out,x);
 }return out;
}
function _dpSafe(a,b){return !((_dpFlags(a)|_dpFlags(b))&4)&&((!((_dpFlags(a)|_dpFlags(b))&2))||(a===2&&b===2));}
function _dpBinary(ip,op){
 var b=_dpPop(),a=_dpPop(),f=0,v=0;
 if(op!==4){_dpPush(1);return;}_dpSet(_dp[34],ip);if(!_dpSafe(a,b))_dpSet(_dp[35],ip);
 f=_dpFlags(a)|_dpFlags(b);if(f&4)v=3;else{if(f&2)v=2;if((_dpFlags(a)&1||_dpCount(a))&&(_dpFlags(b)&1||_dpCount(b)))v=_dpJoin(v,1);}_dpPush(v);
}
function _dpValueCall(n){
 var v=_dpPop(),out=0,i=0,a=0;if(_dpFlags(v)&4){_dp[42]=1;return 3;}if(_dpFlags(v)&3)out=1;
 for(i=0;i<_dpCount(v);i++){a=_dpAtom(v,i);out=_dpJoin(out,Math.floor(a/65536)===3?_dpCall(a%65536,n):1);}return out;
}
function _dpOther(ip,op,a,h){
 var v=0,x=0,i=0,r=0,n=0,p=0;
 if(op===19){v=1;for(i=0;i<a;i++)v=_dpJoin(v,_dpPop());r=65536+ip;_dpHeap(r,65535,v,1);_dpPush(_dpRef(r));}
 else if(op===20){_dpPop();v=_dpPop();_dpPush(_dpRead(v,65535));}
 else if(op===21){v=_dpPop();_dpPop();r=_dpPop();_dpWrite(r,65535,v);_dpPush(v);}
 else if(op===26)_dpPush(_dpRef(131072+ip));
 else if(op===27){if(h){_dp[0]=1;return;}v=_dpPop();_dpPush(_dpRead(v,a));}
 else if(op===28){v=_dpPop();r=_dpPop();_dpWrite(r,a,v);_dpPush(v);if(_dpEq(a,"onload"))_dpCallback(v,0,3,3,3);}
 else if(op===33)_dpPush(_dpRef(196608+a));
 else if(op===24){_dpArgs(h);_dpPush(_dpCall(a,h));}
 else if(op===13){_dpArgs(h);_dpPush(_dpNative(ip,a,h));}
 else if(op===34){_dpArgs(a);_dpPush(_dpValueCall(a));}
 else if(op===30){if(a&32768){_dp[0]=1;return;}_dpArgs(h);r=_dpPop();_dpPush(_dpMethod(ip,a,h,r));}
 else _dp[0]=1;
}
function _dpRun(p){
 var q=_dp[20]+(p-1)*12,c=_r16(q),ip=_r16(q+2),i=0,a=0,h=0,op=0,v=0,r=0,start=ip;
 _gw(q+9,0);_dp[30]=_r16(q+4);a=_dp[23]+_r16(q+6);for(i=0;i<_dp[30];i++)_w16(_dp[29]+i*2,_r16(a+i*2));
 while(ip<nOps&&!_dp[0]){
  if(ip!==start&&_dpBit(_dp[33],ip)){_dpState(c,ip);return;}
  _dp[41]++;if(_dp[41]>nOps*100){_dp[0]=1;return;}op=opCode(ip);a=opA0(ip);h=opA1(ip);
  if(op===1){if(LINK_MODE&&ip<8192)v=h===1?2:1;else{if(a>=nCrec){_dp[0]=1;return;}v=_gr(CREC_OFF+a*12)===1?2:1;}_dpPush(v);}
  else if(op===2){a=_dpName(ip,a);_dpPush(_dpLoad(c,a,h));}
  else if(op===3||op===22){a=_dpName(ip,a);_dpStore(c,a,h,_dpPop(),op===22);}
  else if(op===15)_dpPop();else if(op===16){v=_dpPop();_dpPush(v);_dpPush(v);}
  else if(op===17||op===18){_dpPop();_dpPush(1);}
  else if(op===4||op===5||op===6||op===7||op===8||op===9||op===10||op===23||op===31||op===32)_dpBinary(ip,op);
  else if(op===11){_dpState(c,a);return;}
  else if(op===12){_dpPop();_dpState(c,a);_dpState(c,ip+1);return;}
  else if(op===14||op===25){v=op===25?_dpPop():1;p=_dpFn(c,0);if(!p){_dp[0]=1;return;}q=_dp[15]+(p-1)*12;r=_r16(q+4);v=_dpJoin(r,v);if(v!==r){_w16(q+4,v);_dp[1]=1;}return;}
  else _dpOther(ip,op,a,h);ip++;
 }
}
function _dpDead(ip){
 var i=0,e=0,end=0,n=0,j=0,op=0,a=0,h=0,s=0;
 for(i=0;i<nFn;i++){
  e=fnEntry(i);if(e<=0||e>ip||opCode(e-1)!==11)continue;end=opA0(e-1);if(ip>=end||end>=nOps)continue;
  // Exact named declaration boundary only: trailing MAKE_FN binds this entry.
  if(opCode(end)!==33||opA0(end)!==e)continue;
  s=_gr(_dp[37]+i);if(s)return s===1?1:0;n=_r16(FN_OFF+i*8);s=1;
  for(j=0;j<nOps;j++){
   if(j>=e&&j<end)continue;op=opCode(j);a=opA0(j);h=opA1(j);
   if((op===24||op===4)&&a===e)s=2;
   if(op===33&&a===e&&j!==end)s=2;
   if(op===2&&_dpName(j,a)===n)s=2;
   if(op===13&&!(LINK_MODE&&j<8192)&&a===n)s=2;
  }_gw(_dp[37]+i,s);return s===1?1:0;
 }return 0;
}
function _dpLayout(){
 var i=0,a=1,b=Math.floor((nOps+7)/8);_dp=[];for(i=0;i<64;i++)_dp.push(0);_dp[4]=TOK_OFF;_dp[5]=OPS_OFF;
 _dp[6]=_dpTake(12288);_dp[7]=4;_dp[8]=_dpTake(1024);
 _dp[9]=_dpTake(16384);_dp[11]=_dpTake(2048);_dp[12]=_dpTake(6144);_dp[14]=_dpTake(1024);
 _dp[15]=_dpTake(4608);_dp[17]=_dpTake(1024);_dp[18]=_dpTake(4096);
 _dp[20]=_dpTake(49152);_dp[22]=_dpTake(4096);_dp[23]=_dpTake(4096);_dp[25]=_dpTake(8192);
 _dp[29]=_dpTake(512);_dp[31]=_dpTake(128);_dp[32]=_dpTake(256);
 _dp[33]=_dpTake(b);_dp[34]=_dpTake(b);_dp[35]=_dpTake(b);_dp[36]=_dpTake(1024);_dp[37]=_dpTake(384);
 if(_dp[0])return 0;for(i=0;i<8;i++){_dp[48+i]=a;a*=2;}
 _dpZero(_dp[8],1024);_dpZero(_dp[11],2048);_dpZero(_dp[14],1024);_dpZero(_dp[17],1024);_dpZero(_dp[22],4096);_dpZero(_dp[33],b);_dpZero(_dp[36],1024);_dpZero(_dp[37],384);return 1;
}
function deviceAddProof(){
 var i=0,op=0,a=0,h=0,p=0,q=0,j=0,n=0,k=0,need=0,b=0;
 if(nCls||nOps>=32768||nNames>1024||nFn>384)return 1;
 if(!_dpLayout())return 1;b=Math.floor((nOps+7)/8);_dpSet(_dp[33],0);
 for(i=0;i<nOps;i++){
  op=opCode(i);a=opA0(i);h=opA1(i);
  if(op===11||op===12||op===24||op===33){if(a>=nOps){_dp[0]=1;break;}_dpSet(_dp[33],a);}
  if(op===12&&i+1<nOps)_dpSet(_dp[33],i+1);
  if(op===3||op===22){a=_dpName(i,a);h=1|((op===22&&h===0)||(op===3&&h===1)?2:0);_gw(_dp[36]+a,_gr(_dp[36]+a)|h);}
 }
 _dpFn(0,1);
 for(n=1;n<=64&&!_dp[0];n++){
  _dp[2]=n;_dp[1]=0;_dp[26]=0;_dp[27]=0;_dp[28]=0;_dp[41]=0;_dp[42]=0;_dpZero(_dp[34],b);_dpZero(_dp[35],b);k=_dp[16];
  for(i=0;i<k;i++){p=_dp[15]+i*12;_dp[30]=_gr(p+2);a=_r16(p+6);for(j=0;j<_dp[30];j++)_w16(_dp[29]+j*2,_r16(a+j*2));_dpState(_r16(p),_r16(p));}
  while(_dp[28]&&!_dp[0]){p=_r16(_dp[25]+_dp[26]*2);_dp[26]=(_dp[26]+1)%4096;_dp[28]--;_dpRun(p);}
  if(!_dp[1])break;
 }
 if(_dp[0]||_dp[42]||n>64)return 1;
 // Assess all sites before mutating a marker; overflow/unknown means KEEP all.
 for(i=0;i<nOps;i++)if(opCode(i)===4){
  a=_dpBit(_dp[34],i)?(!_dpBit(_dp[35],i)):_dpDead(i);
  if(_dp[0])return 1;
  if(LINK_MODE&&i<8192){if(!a){over=1;return 1;}}
  else if(opA1(i)===1&&!a)need=1;
 }
 for(i=LINK_MODE?8192:0;i<nOps;i++)if(opCode(i)===4&&opA1(i)===1){if((_dpBit(_dp[34],i)&&!_dpBit(_dp[35],i))||(!_dpBit(_dp[34],i)&&_dpDead(i)))setA1(i,0);}
 return need;
}
