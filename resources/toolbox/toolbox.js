// Toolbox v1 source helpers; native JavaScript, no alternate interpreter.
// See README.md before choosing scratch addresses. Each helper is optional.
function tbMove(src,dst,n){return toolbox(1,src,dst,n);}
function tbFill(dst,value,n){return toolbox(2,dst,value,n);}
function tbResources(offset,dst,n){return toolbox(5,offset,dst,n);}
function tbU16(p,n){
 n=Math.floor(n)%65536;if(n<0)n=n+65536;
 stgWrite(p,n%256);stgWrite(p+1,Math.floor(n/256));
}
function tbSurface(d,base,width,height,stride,bits){
 toolbox(2,d,0,64);stgWrite(d,1);stgWrite(d+1,bits);stgWrite(d+3,1);
 tbU16(d+4,base);tbU16(d+6,Math.floor(base/65536));
 tbU16(d+8,stride);tbU16(d+10,width);tbU16(d+12,height);
 tbU16(d+18,width);tbU16(d+20,height);tbU16(d+30,640);tbU16(d+32,480);
}
function tbRect(d,x,y,width,height){
 tbU16(d+14,x);tbU16(d+16,y);tbU16(d+18,width);tbU16(d+20,height);
}
function tbPlace(d,x,y,scale){tbU16(d+22,x);tbU16(d+24,y);stgWrite(d+3,scale);}
function tbClip(d,x,y,width,height){
 tbU16(d+26,x);tbU16(d+28,y);tbU16(d+30,width);tbU16(d+32,height);
}
function tbInk(d,foreground,background){stgWrite(d+34,foreground);stgWrite(d+35,background);}
function tbBlit(d){return toolbox(3,d,0,0);}
function tbPattern(d){return toolbox(4,d,0,0);}
// Raw indexed-color rectangle transport. Higher-level CopyBits policy can
// evolve here without changing circuits; check native capability bit 5 first.
function tbCopyBits(src,dst){
 if((toolbox(0,0,0,0)&32)==0)return -1;
 return toolbox(6,src,dst,0);
}
function tbScreen(d){
 tbSurface(d,0,640,480,640,8);stgWrite(d+2,2);
}
