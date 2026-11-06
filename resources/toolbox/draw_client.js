// Shared bounded draw emission. The result is temporary, reused storage.
var tbClientClip=[0,0,640,480];
function tbDrawBounds(x,y,w,h){
 var p=tbPortBounds();
 tbClientClip[0]=Math.max(x,p[0]-p[4]);tbClientClip[1]=Math.max(y,p[1]-p[5]);
 tbClientClip[2]=Math.min(x+w,p[2]-p[4]);tbClientClip[3]=Math.min(y+h,p[3]-p[5]);
 return tbClientClip;
}
function tbDrawHit(x,y,w,h){
 var p=tbPortBounds();return p[2]>p[0]&&p[3]>p[1]&&x+w>p[0]-p[4]&&x<p[2]-p[4]&&y+h>p[1]-p[5]&&y<p[3]-p[5];
}
function tbDrawFill(ctx,x,y,w,h,c){
 var p=tbDrawBounds(x,y,w,h);if(p[2]>p[0]&&p[3]>p[1])ctx.fillRect(p[0],p[1],p[2]-p[0],p[3]-p[1],c);
}
