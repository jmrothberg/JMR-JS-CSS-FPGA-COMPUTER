// Shared document scroll controls, using the common Window and Control geometry.
var tbClientScroll=0;
function tbClientChrome(mode,x,y){
 var a=tbWindowBounds(),code=0,scroll=tbClientScroll;
 if(mode==2){tbClientResize(x,y);return 0;}
 if(mode==1){

  if(x>=a[0]+a[2]-19&&x<a[0]+a[2]-1&&y>=a[1]+54&&y<a[1]+a[3]-22){code=tbControlPart(y,a[1]+54,a[3]-76,20,a[1]+76+Math.floor(Math.max(0,a[3]-140)*scroll/255),Math.min(20,Math.max(0,a[3]-116)));code=code==4?128:code==5?129:code==8?130:131;}
  if(y>=a[1]+a[3]-20&&y<a[1]+a[3]-1){if(x>=a[0]+2&&x<a[0]+20)code=132;else if(x>=a[0]+a[2]-38&&x<a[0]+a[2]-20)code=133;}
 
 return code;
 }
 tbClientScroll=x;scroll=x;

   tbBox(a[0]+a[2]-19,a[1]+54,18,a[3]-76,"#CCC");tbBox(a[0]+a[2]-19,a[1]+54,18,20,"#FFF");tbClientArrow(a[0]+a[2]-14,a[1]+61,0);
   tbBox(a[0]+a[2]-19,a[1]+a[3]-40,18,18,"#FFF");tbClientArrow(a[0]+a[2]-14,a[1]+a[3]-34,1);
   tbBox(a[0]+a[2]-17,a[1]+76+Math.floor(Math.max(0,a[3]-140)*scroll/255),14,Math.min(20,Math.max(0,a[3]-116)),"#FFF");
   tbBox(a[0]+2,a[1]+a[3]-20,a[2]-22,19,"#CCC");tbBox(a[0]+2,a[1]+a[3]-20,18,19,"#FFF");tbClientArrow(a[0]+9,a[1]+a[3]-15,2);
   tbBox(a[0]+a[2]-38,a[1]+a[3]-20,18,19,"#FFF");tbClientArrow(a[0]+a[2]-31,a[1]+a[3]-15,3);
   // Grow box: two overlapping squares in the corner between the bars.
   tbBox(a[0]+a[2]-20,a[1]+a[3]-22,20,22,"#FFF");tbBox(a[0]+a[2]-16,a[1]+a[3]-18,8,8,"#FFF");tbBox(a[0]+a[2]-13,a[1]+a[3]-15,9,9,"#FFF");
  
 return 0;
}
// A filled arrow, 9 by 5 pixels (up 0, down 1) or 5 by 9 (left 2, right 3).
function tbClientArrow(x,y,d){
 var i=0;
 while(i<5){
  if(d==0)tbBox(x+4-i,y+i,1+2*i,1,"#000");else if(d==1)tbBox(x+i,y+i,9-2*i,1,"#000");
  else if(d==2)tbBox(x+i,y+4-i,1,1+2*i,"#000");else tbBox(x+i,y+i,1,9-2*i,"#000");
  i=i+1;
 }
}
tbSessionChrome(tbClientChrome);
