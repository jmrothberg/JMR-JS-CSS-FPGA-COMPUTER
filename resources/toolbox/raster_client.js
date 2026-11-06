// Shared optional raster policy; native CopyBits/Raster remain resident.
function tbMask(d,base,stride){
 tbU32(d+48,base);tbU16(d+52,stride);
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
 tbScreen(dst);tbRect(dst,0,0,width,height);tbPlaceScreen(dst,x,y,1);return tbRaster(src,dst,0);
}

