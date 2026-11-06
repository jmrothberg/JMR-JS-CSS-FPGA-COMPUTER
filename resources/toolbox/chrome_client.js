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

   tbBox(a[0]+a[2]-19,a[1]+54,18,a[3]-76,"#CCC");tbBox(a[0]+a[2]-19,a[1]+54,18,20,"#FFF");tbText([94],a[0]+a[2]-14,a[1]+56);
   tbBox(a[0]+a[2]-19,a[1]+a[3]-40,18,18,"#FFF");tbText([118],a[0]+a[2]-14,a[1]+a[3]-40);
   tbBox(a[0]+a[2]-17,a[1]+76+Math.floor(Math.max(0,a[3]-140)*scroll/255),14,Math.min(20,Math.max(0,a[3]-116)),"#FFF");
   tbBox(a[0]+2,a[1]+a[3]-20,a[2]-22,19,"#CCC");tbBox(a[0]+2,a[1]+a[3]-20,18,19,"#FFF");tbText([60],a[0]+6,a[1]+a[3]-19);
   tbBox(a[0]+a[2]-38,a[1]+a[3]-20,18,19,"#FFF");tbText([62],a[0]+a[2]-33,a[1]+a[3]-19);
  
 return 0;
}
tbSessionChrome(tbClientChrome);
