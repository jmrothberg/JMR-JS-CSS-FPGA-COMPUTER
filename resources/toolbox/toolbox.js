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
// Native ABI v1 raster extension (capability bit 6). Modes act on palette-index bytes, not RGB.
// 0 copy, 1 OR, 2 XOR, 3 destination AND NOT source, 4 AND, 5 invert destination.
function tbRaster(src,dst,mode){
 if((toolbox(0,0,0,0)&64)==0)return -1;
 stgWrite(src+36,mode);return toolbox(7,src,dst,0);
}
function tbMask(d,base,stride){
 tbU16(d+48,base);tbU16(d+50,Math.floor(base/65536));tbU16(d+52,stride);
 stgWrite(d+37,(stgRead(d+37)&2)+1);
}
function tbMaskOff(d){stgWrite(d+37,stgRead(d+37)&2);}
function tbPattern8(d,rows,foreground,background){
 var i=0;while(i<8){stgWrite(d+40+i,rows[i]);i=i+1;}
 tbInk(d,foreground,background);stgWrite(d+37,(stgRead(d+37)&1)+2);
}
function tbPatternOff(d){stgWrite(d+37,stgRead(d+37)&1);}
// Compose a screen pattern rectangle from the general transport; no separate
// line, polygon, brush or window hardware is needed. Descriptors are caller-owned.
function tbPaintRect(src,dst,x,y,width,height,rows,foreground,background){
 tbScreen(src);tbRect(src,0,0,width,height);tbPattern8(src,rows,foreground,background);
 tbScreen(dst);tbRect(dst,0,0,width,height);tbPlace(dst,x,y,1);return tbRaster(src,dst,0);
}
