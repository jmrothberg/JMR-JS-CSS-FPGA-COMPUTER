// Toolbox v1 source helpers; native JavaScript, no alternate interpreter.
// See README.md before choosing scratch addresses. Each helper is optional.
function tbMove(src,dst,n){return toolbox(1,src,dst,n);}
function tbFill(dst,value,n){return toolbox(2,dst,value,n);}
function tbResources(p,dst,n){return toolbox(5,p,dst,n);}
// Cache ABI capabilities once per application; old FPGA images fail explicitly.
var _tbCaps=toolbox(0,0,0,0);
function tbU16(p,n){return (_tbCaps&1920)==1920?toolbox(11,p,Math.floor(n),0):-1;}
function tbU32(p,n){return (_tbCaps&1920)==1920?toolbox(9,p,Math.floor(n),0):-1;}
function tbPair32(p,a,b){return (_tbCaps&1920)==1920?toolbox(10,p,a,b):-1;}
function tbSessionU32(p){return (_tbCaps&1920)==1920?toolbox(8,p,0,0):-1;}
function tbPack16(a,b){return (Math.floor(a)&65535)+(Math.floor(b)&65535)*65536;}
// Half-open destination clip; reads and operation counts retain native semantics.
function tbPortClip(x,y,w,h){return (_tbCaps&2048)?toolbox(12,tbPack16(x,y),tbPack16(w,h),0):-1;}
function tbPortReset(){return (_tbCaps&2048)?toolbox(12,0,0,1):-1;}
function tbSurface(d,base,width,height,stride,n){
 toolbox(2,d,0,64);stgWrite(d,1);stgWrite(d+1,n);stgWrite(d+3,1);
 tbU32(d+4,base);
 tbU16(d+8,stride);tbU16(d+10,width);tbU16(d+12,height);
 tbU16(d+18,width);tbU16(d+20,height);tbU32(d+30,31457920);
}
function tbRect(d,x,y,width,height){
 tbPair32(d+14,tbPack16(x,y),tbPack16(width,height));
}
function tbPlace(d,x,y,n){tbU32(d+22,tbPack16(x,y));stgWrite(d+3,n);}
function tbClip(d,x,y,width,height){
 tbPair32(d+26,tbPack16(x,y),tbPack16(width,height));
}
function tbInk(d,a,b){stgWrite(d+34,a);stgWrite(d+35,b);}
function tbBlit(d){return toolbox(3,d,0,0);}
function tbPattern(d){return toolbox(4,d,0,0);}
// Raw indexed-color rectangle transport. Higher-level CopyBits policy can
// evolve here without changing circuits; check native capability bit 5 first.
function tbCopyBits(src,dst){
 if((_tbCaps&32)==0)return -1;
 return toolbox(6,src,dst,0);
}
function tbScreen(d){
 tbSurface(d,0,640,480,640,8);stgWrite(d+2,2);
}
// Native ABI v1 raster extension (capability bit 6). Modes act on palette-index bytes, not RGB.
// 0 copy, 1 OR, 2 XOR, 3 destination AND NOT source, 4 AND, 5 invert destination.
function tbRaster(src,dst,mode){
 if((_tbCaps&64)==0)return -1;
 stgWrite(src+36,mode);return toolbox(7,src,dst,0);
}

// Raw tbPlace remains descriptor coordinates, including arena destinations.
function tbPlaceScreen(d,x,y,n){tbPlace(d,x+_tbPortRect[4],y+_tbPortRect[5],n);}
