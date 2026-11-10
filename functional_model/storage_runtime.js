// Shared opaque-string persistence; public ToString wrappers are linked separately.
// Internal file format v1. No application title, fixed user-document address or ROM bank.
var _jmr_store_state={ready:0,file:-1,gen:0,end:0,seq:0,count:0,dirty:0,table:[],crc:[],sizes:[]};
function _jmr_store_Name(a){return a==0?"PREFSA.SYS":"PREFSB.SYS";}
function _jmr_store_Fault(a){runtimeFault(a);return 0;}
function _jmr_store_Pages(a){var b=[],c,d=0;while(d<a){c=[];for(var e=0;e<32&&d<a;e++){c.push(0);d++;}b.push(c);}return b;}
function _jmr_store_Byte(a,b){return a[Math.floor(b/32)][b%32];}
function _jmr_store_Put(a,b,c){a[Math.floor(b/32)][b%32]=c&255;}
function _jmr_store_U32(a,b){return _jmr_store_Byte(a,b)+_jmr_store_Byte(a,b+1)*256+_jmr_store_Byte(a,b+2)*65536+_jmr_store_Byte(a,b+3)*16777216;}
function _jmr_store_Put32(a,b,c){for(var d=0;d<4;d++){_jmr_store_Put(a,b+d,c%256);c=Math.floor(c/256);}}
function _jmr_store_Table(){return _jmr_store_Pages(192);}
function _jmr_store_Word(a,b){var c=Math.floor(b/32);return a[c][b%32];}
function _jmr_store_SetWord(a,b,c){a[Math.floor(b/32)][b%32]=c;}
function _jmr_store_Xor(a,b){var c=a&b;if(c<0)c+=4294967296;return a+b-2*c;}
function _jmr_store_Crc(a,b){return _jmr_store_Xor(Math.floor(a/256),_jmr_store_Word(_jmr_store_state.crc,_jmr_store_Xor(a,b)&255));}
function _jmr_store_CrcBytes(a,b){var c=4294967295;for(var d=0;d<b;d++)c=_jmr_store_Crc(c,_jmr_store_Byte(a,d));return 4294967295-c;}
function _jmr_store_Len(a){var b=0;while(b<=16384&&strByte(a,b)>=0)b++;if(b>16384)_jmr_store_Fault(3);return b;}
function _jmr_store_Hash(a,b){var c=4294967295;for(var d=0;d<b;d++)c=_jmr_store_Crc(c,strByte(a,d));return 4294967295-c;}
// mode0 read bytes,1 append,2 replace,3 paged directory,4 checked immutable string.
// All snapshots/output pages are allocated before the first arena mutation.
function _jmr_store_IO(a,b,c,d,e){
 var f=Math.max(64,e+16),g=380928-f,h=[],i,j,k=0,l,m,n=[],o,p;
 while(k<f){i=[];while(i.length<32&&k<f){j=[];while(j.length<32&&k<f){j.push(stgRead(g+k));k++;}i.push(j);}h.push(i);}
 if(a==0||a==3)n=_jmr_store_Pages(e);
 for(k=0;k<16;k++){l=strByte(b,k);stgWrite(g+k,l<0?0:l);}
 if(a==1||a==2){for(k=0;k<e;k++)stgWrite(g+16+k,d[Math.floor(k/32)][k%32]);}
 if(a==3)o=fsList(g+16,e,c);
 else if(a==1||a==2)o=fsWrite(g,g+16,e,a==1?1:0);
 else o=fsRead(g,c,g+16,e);
 if(a==4&&o==e)p=stringFromBytes(g+16,e,1);
 if((a==0||a==3)&&o>=0){for(k=0;k<(a==3?e:o);k++)n[Math.floor(k/32)][k%32]=stgRead(g+16+k);}
 // Inline restoration: no allocating user helper, string conversion or callback.
 k=0;for(l=0;l<h.length;l++){i=h[l];for(m=0;m<i.length;m++){j=i[m];for(c=0;c<j.length;c++){stgWrite(g+k,j[c]);k++;}}}
 if(o<0||(a!=3&&o!=e))_jmr_store_Fault(5);
 if(a==4){if(typeof p!="string")_jmr_store_Fault(3);return p;}
 return {n:o,b:n};
}
function _jmr_store_Read(a,b,c){return _jmr_store_IO(0,a,b,[],c).b;}
function _jmr_store_Write(a,b,c){_jmr_store_IO(c?1:2,a,0,b,512);}
function _jmr_store_Directory(){
 var a=[-1,-1],b=0,c,d,e,f,g,h,i,j,k;
 while(true){c=_jmr_store_IO(3,"",b,[],512);d=c.b;f=_jmr_store_Byte(d,8)+_jmr_store_Byte(d,9)*256;e=16;
  for(var l=0;l<f;l++){g=_jmr_store_Byte(d,e);if(g<1||g>12||e+g+8>512)_jmr_store_Fault(5);
   for(k=0;k<2;k++){h=_jmr_store_Name(k);j=1;for(i=0;i<g;i++)if(_jmr_store_Byte(d,e+1+i)!=strByte(h,i))j=0;if(strByte(h,g)>=0)j=0;
    if(j){if(_jmr_store_Byte(d,e+g+7)&24)_jmr_store_Fault(5);a[k]=_jmr_store_U32(d,e+g+1);}}
   e+=g+8;
  }
  if(!_jmr_store_Byte(d,10))return a;i=_jmr_store_U32(d,12);if(i<=b)_jmr_store_Fault(5);b=i;
 }
}
function _jmr_store_Header(a,b){
 if(b<0)return -1;if(b<512)return -2;var c=_jmr_store_Read(_jmr_store_Name(a),0,512);
 if(_jmr_store_U32(c,0)!=1397509450||_jmr_store_Byte(c,4)!=1)return -2;
 if(_jmr_store_U32(c,12)!=_jmr_store_CrcBytes(c,12)||b>8388608)_jmr_store_Fault(5);return _jmr_store_U32(c,8);
}
function _jmr_store_EmptyHeader(a){var b=_jmr_store_Pages(512);_jmr_store_Put32(b,0,1397509450);_jmr_store_Put(b,4,1);_jmr_store_Put32(b,8,a);_jmr_store_Put32(b,12,_jmr_store_CrcBytes(b,12));return b;}
function _jmr_store_Span(a,b){return Math.ceil((48+a+b)/512)*512;}
function _jmr_store_RecordHeader(a,b,c,d,e,f){var g=_jmr_store_Pages(512);_jmr_store_Put32(g,0,1380732234);_jmr_store_Put(g,4,1);_jmr_store_Put(g,5,a);_jmr_store_Put32(g,8,b);_jmr_store_Put32(g,12,c);_jmr_store_Put(g,16,d%256);_jmr_store_Put(g,17,Math.floor(d/256));_jmr_store_Put(g,18,e%256);_jmr_store_Put(g,19,Math.floor(e/256));_jmr_store_Put32(g,20,f);_jmr_store_Put32(g,24,_jmr_store_Span(d,e));_jmr_store_Put32(g,28,_jmr_store_CrcBytes(g,28));return g;}
function _jmr_store_Record(a,b,c,d,e,f){
 if(c-b<512)return 0;var g=_jmr_store_Read(_jmr_store_Name(a),b,512),h=[_jmr_store_Byte(g,5),_jmr_store_U32(g,8),_jmr_store_U32(g,12),_jmr_store_Byte(g,16)+_jmr_store_Byte(g,17)*256,_jmr_store_Byte(g,18)+_jmr_store_Byte(g,19)*256,_jmr_store_U32(g,20),_jmr_store_U32(g,24)],i=4294967295,j=4294967295,k=g,l,m,n,o;
 if(_jmr_store_U32(g,0)!=1380732234||_jmr_store_Byte(g,4)!=1||h[0]<1||h[0]>3||h[3]>16384||h[4]>16384||h[6]!=_jmr_store_Span(h[3],h[4])||_jmr_store_U32(g,28)!=_jmr_store_CrcBytes(g,28)||(h[0]==2&&h[4])||(h[0]==3&&(h[3]||h[4]))||h[1]>d||(e&&(h[1]!=d||h[2]<=f)))_jmr_store_Fault(5);
 if(c-b<h[6])return 0;h.push(32+h[3]+h[4]);
 for(n=0;n<h[7];n+=512){if(n)k=_jmr_store_Read(_jmr_store_Name(a),b+n,512);l=Math.min(512,h[7]-n);for(m=0;m<l;m++){i=_jmr_store_Crc(i,_jmr_store_Byte(k,m));if(n+m>=32&&n+m<32+h[3])j=_jmr_store_Crc(j,_jmr_store_Byte(k,m));}}
 l=0;if(h[7]+16<=512){o=g;l=h[7];}else o=_jmr_store_Read(_jmr_store_Name(a),b+h[7],16);
 if(_jmr_store_U32(o,l)!=1129073994||_jmr_store_U32(o,l+4)!=h[1]||_jmr_store_U32(o,l+8)!=h[2]||_jmr_store_U32(o,l+12)!=(4294967295-i)||(h[0]!=3&&h[5]!=(4294967295-j)))_jmr_store_Fault(5);
 return [h[0],h[2],h[5],h[3],h[4],h[6]];
}
function _jmr_store_EqualOffsets(a,b,c,d){for(var e=0;e<d;e+=512){var f=Math.min(512,d-e),g=_jmr_store_Read(a,b+e,f),h=_jmr_store_Read(a,c+e,f);for(var i=0;i<f;i++)if(_jmr_store_Byte(g,i)!=_jmr_store_Byte(h,i))return 0;}return 1;}
function _jmr_store_FindRecord(a,b,c,d,e){for(var f=0;f<64;f++){var g=_jmr_store_Word(a,f*3+2);if(g&&_jmr_store_Word(a,f*3)==d&&_jmr_store_Word(a,f*3+1)%65536==e&&_jmr_store_EqualOffsets(b,g+32,c+32,e))return f;}return -1;}
function _jmr_store_Free(a){for(var b=0;b<64;b++)if(!_jmr_store_Word(a,b*3+2))return b;return -1;}
function _jmr_store_Scan(a,b,c){
 var d=_jmr_store_Table(),e=512,f=0,g=0,h=0,i,j;
 while(e<b){i=_jmr_store_Record(a,e,b,c,g,h);if(!i)break;
  if(i[0]==3){if(g||i[2]!=f||i[1]<h)_jmr_store_Fault(5);g=1;}
  else{j=_jmr_store_FindRecord(d,_jmr_store_Name(a),e,i[2],i[3]);if(i[0]==2){if(j>=0){_jmr_store_SetWord(d,j*3+2,0);f--;}}
   else{if(j<0){j=_jmr_store_Free(d);if(j<0)_jmr_store_Fault(3);f++;}_jmr_store_SetWord(d,j*3,i[2]);_jmr_store_SetWord(d,j*3+1,i[3]+i[4]*65536);_jmr_store_SetWord(d,j*3+2,e);}}
  if(i[1]>h)h=i[1];e+=i[5];
 }
 return {table:d,end:e,count:f,seq:h,sealed:g,dirty:e!=b};
}
function _jmr_store_Use(a,b,c){_jmr_store_state.file=a;_jmr_store_state.gen=b;_jmr_store_state.table=c.table;_jmr_store_state.end=c.end;_jmr_store_state.seq=c.seq;_jmr_store_state.count=c.count;_jmr_store_state.dirty=c.dirty;}
function _jmr_store_Open(){
 if(_jmr_store_state.ready)return;var a,b,c,d=[],e=[],f;
 for(a=0;a<256;a++){c=a;for(b=0;b<8;b++)c=_jmr_store_Xor(Math.floor(c/2),(c%2)?3988292384:0);if(a%32==0)d.push([]);d[Math.floor(a/32)].push(c);}_jmr_store_state.crc=d;
 _jmr_store_state.sizes=_jmr_store_Directory();e=[_jmr_store_Header(0,_jmr_store_state.sizes[0]),_jmr_store_Header(1,_jmr_store_state.sizes[1])];
 a=e[1]>e[0]?1:0;b=1-a;if(e[a]>=0){f=_jmr_store_Scan(a,_jmr_store_state.sizes[a],e[a]);if(f.sealed){_jmr_store_Use(a,e[a],f);_jmr_store_state.ready=1;return;}}
 if(e[b]>=0){f=_jmr_store_Scan(b,_jmr_store_state.sizes[b],e[b]);if(f.sealed){_jmr_store_Use(b,e[b],f);_jmr_store_state.ready=1;return;}}
 if(_jmr_store_state.sizes[0]>=0||_jmr_store_state.sizes[1]>=0)_jmr_store_Fault(5);_jmr_store_state.table=_jmr_store_Table();_jmr_store_state.ready=1;
}
function _jmr_store_FindText(a,b,c){
 var d=_jmr_store_state.table,e=_jmr_store_Name(_jmr_store_state.file),f,g,h,i,j,k,l;
 for(f=0;f<64;f++){g=_jmr_store_Word(d,f*3+2);if(g&&_jmr_store_Word(d,f*3)==c&&_jmr_store_Word(d,f*3+1)%65536==b){l=1;for(h=0;h<b&&l;h+=512){i=Math.min(512,b-h);j=_jmr_store_Read(e,g+32+h,i);for(k=0;k<i;k++)if(_jmr_store_Byte(j,k)!=strByte(a,h+k))l=0;}if(l)return f;}}
 return -1;
}
function _jmr_store_Footer(a,b,c,d,e,f,g){
 var h=4294967295,i=32+f+g,j=_jmr_store_Pages(16),k,l;
 for(k=0;k<i;k++){l=k<32?_jmr_store_Byte(a,k):k<32+f?strByte(d,k-32):strByte(e,k-32-f);h=_jmr_store_Crc(h,l);}
 _jmr_store_Put32(j,0,1129073994);_jmr_store_Put32(j,4,b);_jmr_store_Put32(j,8,c);_jmr_store_Put32(j,12,4294967295-h);return j;
}
function _jmr_store_AppendBlock(a,b,c,d,e,f,g,h){
 var i=_jmr_store_Pages(512),j,k,l;
 for(j=0;j<512;j++){k=f+j;if(k<32)l=_jmr_store_Byte(b,k);else if(k<32+h)l=strByte(d,k-32);else if(k<g)l=strByte(e,k-32-h);else if(k<g+16)l=_jmr_store_Byte(c,k-g);else l=0;_jmr_store_Put(i,j,l);}_jmr_store_Write(a,i,1);
}
function _jmr_store_Append(a,b,c,d,e,f,g,h){
 var i=_jmr_store_Len(e),j=_jmr_store_Len(f),k=_jmr_store_Span(i,j),l=_jmr_store_RecordHeader(b,c,d,i,j,b==3?h:g),m=_jmr_store_Footer(l,c,d,e,f,i,j),n;
 for(n=0;n<k;n+=512)_jmr_store_AppendBlock(a,l,m,e,f,n,32+i+j,i);return k;
}
function _jmr_store_Start(){var a=_jmr_store_Name(0);if(_jmr_store_state.sizes[0]>=0)_jmr_store_Fault(5);_jmr_store_Write(a,_jmr_store_EmptyHeader(0),0);_jmr_store_Append(a,3,0,0,"","",0,0);var b=_jmr_store_Scan(0,1024,0);if(!b.sealed)_jmr_store_Fault(5);_jmr_store_Use(0,0,b);}
function _jmr_store_Compact(){
 var a=1-_jmr_store_state.file,b=_jmr_store_state.gen+1,c=_jmr_store_Name(a),d=_jmr_store_Name(_jmr_store_state.file),e=512,f,g,h,i,j,k;
 if(b>4294967295)_jmr_store_Fault(3);if(_jmr_store_state.sizes[a]>=0&&_jmr_store_Header(a,_jmr_store_state.sizes[a])<0)_jmr_store_Fault(5);
 _jmr_store_Write(c,_jmr_store_EmptyHeader(b),0);
 for(f=0;f<64;f++){g=_jmr_store_Word(_jmr_store_state.table,f*3+2);if(g){j=_jmr_store_Word(_jmr_store_state.table,f*3+1);h=_jmr_store_Span(j%65536,Math.floor(j/65536));for(i=0;i<h;i+=512)_jmr_store_Write(c,_jmr_store_Read(d,g+i,512),1);e+=h;}}
 _jmr_store_Append(c,3,b,_jmr_store_state.seq,"","",0,_jmr_store_state.count);e+=512;k=_jmr_store_Scan(a,e,b);if(!k.sealed||k.dirty||k.count!=_jmr_store_state.count)_jmr_store_Fault(5);_jmr_store_Use(a,b,k);_jmr_store_state.sizes[a]=e;
}
function _jmr_store_GetText(a){if(typeof a!="string")_jmr_store_Fault(4);_jmr_store_Open();if(_jmr_store_state.file<0)return null;var b=_jmr_store_Len(a),c=_jmr_store_Hash(a,b),d=_jmr_store_FindText(a,b,c);if(d<0)return null;var e=_jmr_store_Word(_jmr_store_state.table,d*3+1),f=_jmr_store_Word(_jmr_store_state.table,d*3+2);return _jmr_store_IO(4,_jmr_store_Name(_jmr_store_state.file),f+32+e%65536,[],Math.floor(e/65536));}
function _jmr_store_SetText(a,b){
 if(typeof a!="string"||typeof b!="string")_jmr_store_Fault(4);_jmr_store_Open();var c=_jmr_store_Len(a),d=_jmr_store_Len(b),e=_jmr_store_Hash(a,c),f=_jmr_store_FindText(a,c,e),g,h;
 if(f<0&&_jmr_store_state.count>=64)_jmr_store_Fault(3);if(_jmr_store_state.seq>=4294967295)_jmr_store_Fault(3);if(_jmr_store_state.file<0)_jmr_store_Start();if(_jmr_store_state.dirty||_jmr_store_state.end+_jmr_store_Span(c,d)>8388608)_jmr_store_Compact();g=_jmr_store_state.end;
 h=_jmr_store_Append(_jmr_store_Name(_jmr_store_state.file),1,_jmr_store_state.gen,_jmr_store_state.seq+1,a,b,e,0);if(f<0){f=_jmr_store_Free(_jmr_store_state.table);_jmr_store_state.count++;}_jmr_store_SetWord(_jmr_store_state.table,f*3,e);_jmr_store_SetWord(_jmr_store_state.table,f*3+1,c+d*65536);_jmr_store_SetWord(_jmr_store_state.table,f*3+2,g);_jmr_store_state.end+=h;_jmr_store_state.seq++;_jmr_store_state.sizes[_jmr_store_state.file]=_jmr_store_state.end;
}
function _jmr_store_RemoveText(a){
 if(typeof a!="string")_jmr_store_Fault(4);_jmr_store_Open();if(_jmr_store_state.file<0)return;var b=_jmr_store_Len(a),c=_jmr_store_Hash(a,b),d=_jmr_store_FindText(a,b,c),e;
 if(d<0)return;if(_jmr_store_state.seq>=4294967295)_jmr_store_Fault(3);if(_jmr_store_state.dirty||_jmr_store_state.end+_jmr_store_Span(b,0)>8388608)_jmr_store_Compact();e=_jmr_store_Append(_jmr_store_Name(_jmr_store_state.file),2,_jmr_store_state.gen,_jmr_store_state.seq+1,a,"",c,0);_jmr_store_SetWord(_jmr_store_state.table,d*3+2,0);_jmr_store_state.count--;_jmr_store_state.end+=e;_jmr_store_state.seq++;_jmr_store_state.sizes[_jmr_store_state.file]=_jmr_store_state.end;
}

// Public coercion shares the general String software service.
function _jmr_store_getItem(a){return _jmr_store_GetText(_jmr_json_stringCoerceNative(a));}
function _jmr_store_setItem(a,b){_jmr_store_SetText(_jmr_json_stringCoerceNative(a),_jmr_json_stringCoerceNative(b));}
function _jmr_store_removeItem(a){_jmr_store_RemoveText(_jmr_json_stringCoerceNative(a));}
