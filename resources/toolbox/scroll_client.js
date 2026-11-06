// Shared bitmap scrolling. Two caller-owned descriptors; no saved screen image.
// Coordinates are local to the active Port; exposed strips enter bounded damage.
function tbScrollRect(src,dst,x,y,w,h,dx,dy){
 var a=Math.abs(dx),b=Math.abs(dy),p=tbPortBounds(),n;
 if(a>=w||b>=h){tbDamage(x+p[4],y+p[5],w,h);return 0;}
 tbScreen(src);tbScreen(dst);
 tbRect(src,x+p[4]+(dx<0?a:0),y+p[5]+(dy<0?b:0),w-a,h-b);
 tbRect(dst,0,0,w-a,h-b);tbPlaceScreen(dst,x+(dx>0?a:0),y+(dy>0?b:0),1);
 n=tbCopyBits(src,dst);if(n<0)return n;
 if(a)tbDamage(x+p[4]+(dx<0?w-a:0),y+p[5],a,h);
 if(b)tbDamage(x+p[4],y+p[5]+(dy<0?h-b:0),w,b);
 return n;
}
