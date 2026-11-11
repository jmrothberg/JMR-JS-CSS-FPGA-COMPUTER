// Resident cooperative application session. Only migrated clients call these
// entry points; native boot/recovery does not depend on this code running.
var _tbSRole=0,_tbSViewport=0,_tbSInstalled=0,_tbSHeld=0,_tbSCapture=0;
var _tbSCallbacks=[[],[],[],[],[]],_tbSFrames=[],_tbSPending=0;
var _tbSAbout=[],_tbSAboutTitle=[],_tbSOwned=0,_tbSEnable=4294967295,_tbSCheck=0;
var _tbSConfigured=0,_tbSExtras=[],_tbSClickBlock=0;
var _tbSScrollY=0,_tbSScrollX=0,_tbSDirty=0;
function tbSessionProperty(ctx,field,value){
 if(field==0){
  _tbSRole=value;
  if(_tbSAboutTitle.length==0){
   _tbSAboutTitle=tbSessionCodes(value==1?"Editor":value==2?"Reader":value==3?"Compile":value==4?"Utility":value==5?"Note":"Application");
   _tbSAbout=tbSessionCodes("Shared software Toolbox");
  }
  if(value){
   tbUIInit(ctx,380832,380896,_tbSAboutTitle);ctx.systemWindow=value;ctx.systemViewport=0;
   // Any role but a game asks the machine to deliver Esc as a key.
   if(value!=8)ctx.windowDirty=128;
   tbWindow(8,34,612,420,_tbSAboutTitle);_tbChromeWindow=value!=8&&value!=9;
   if(_tbChromeWindow)_tbSessionBack();
   _tbSConfigured=0;
   if(!_tbSInstalled){
    addEventListener("keydown",_tbSessionKey);addEventListener("keyup",_tbSessionKeyUp);
    addEventListener("mousedown",_tbSessionDown);addEventListener("mousemove",_tbSessionMove);addEventListener("mouseup",_tbSessionUp);
    _tbSInstalled=1;
   }
  }
 }else if(field==1){_tbSViewport=value;if(value&&_tbSRole==8)ctx.setTransform(1,0,0,0.9501,0,24);}
 else if(field==2){
  _tbSAboutTitle=[];_tbSAbout=[];
  var i=0,c,part=0;
  while(i<100){c=strByte(value,i);if(c<0)break;if(c==124)part=1;else if(part)_tbSAbout.push(c);else _tbSAboutTitle.push(c);i=i+1;}
  _tbTitle=_tbSAboutTitle;_tbChanged=1;
 }
 else if(field==4){_tbTitle=tbSessionCodes(value);_tbChanged=1;}
 else if(field==5){if(_tbSEnable!=value){_tbSEnable=value;tbSessionMasks();}}
 else if(field==6){if(_tbSCheck!=value){_tbSCheck=value;tbSessionMasks();}}
 else if(field==7){if(_tbSScrollY!=value)_tbChanged=1;_tbSScrollY=value;}
 else if(field==8){if(_tbSScrollX!=value)_tbChanged=1;_tbSScrollX=value;}
 else if(field==9){if(_tbSDirty!=value){_tbSDirty=value;tbSessionMasks();}}
 return value;
}
function tbSessionDefaults(){
 var menus=tbSessionParse(_tbSRole==1||_tbSRole==5?"File|New=1001|Open...=1002|Save=1004|Save As...=1005|Quit=1006;Edit|Undo=137|Cut=138|Copy=139|Paste=140|Clear=141|Select All=142":
  _tbSRole==2?"File|Open...=1002|Quit=1006":_tbSRole==3?"File|Compile...=1012|Quit=1006":_tbSRole==8?"File|Quit=1006;Game|Restart=1007":"File|Quit=1006");
 menus.push(tbSessionParse("Special|Editor=1010|Reader=1011|Compile=1012|Utility=1013|Note=1014|Help=1015|Finder=1016")[0]);
 return menus;
}
function tbSessionCodes(text){var a=[],i=0,c;while(i<128){c=strByte(text,i);if(c<0)break;a.push(c);i=i+1;}return a;}
function tbSessionEquals(a,text){var i=0;while(i<a.length){if(a[i]!=strByte(text,i))return 0;i=i+1;}return strByte(text,i)<0;}
function tbSessionParse(value){
 var menus=[],title=[],rows=[],text=[],code=0,number=0,heading=1,i=0,c,kind,on;
 while(i<=800){
  c=strByte(value,i);i=i+1;
  if(heading){
   if(c==124)heading=0;else if(c<0)break;else title.push(c);
  }else if(c==61){number=1;code=0;}
  else if(c==124||c==59||c<0){
   on=1;kind=0;
   if(text.length==1&&text[0]==45){text=[];on=0;}
   if(_tbSRole!=9){
    if(tbSessionEquals(text,"Quit")||tbSessionEquals(text,"Close"))kind=1;
    else if(tbSessionEquals(text,"Open..."))kind=2;
    else if(tbSessionEquals(text,"Save As..."))kind=3;
   }
   rows.push([text,code,on,0,kind]);text=[];code=0;number=0;
   if(c==59||c<0){menus.push([title,rows]);title=[];rows=[];heading=1;}
   if(c<0)break;
  }else if(number){code=code*10+c-48;}
  else text.push(c);
 }
 return menus;
}
function tbSessionMenus(ctx,value){
 var menus=[],i=0,j=0,base,result=[],part;
 if(strByte(value,0)>=0)menus=tbSessionParse(value);
 else{while(i<value.length){part=tbSessionParse(value[i]);j=0;while(j<part.length){menus.push(part[j]);j=j+1;}i=i+1;}}
 i=0;
 _tbSOwned=menus.length>0&&tbSessionEquals(menus[0][0],"File");
 if(!_tbSOwned){
  base=tbSessionDefaults();result.push(base[0]);
  while(i<menus.length){result.push(menus[i]);i=i+1;}
  result.push(base[base.length-1]);menus=result;
 }
 tbMenus(menus);_tbSConfigured=1;tbSessionMasks();
}
function tbSessionBit(n){var b=1;while(n>0){b=b*2;n=n-1;}return b;}
function tbSessionMasks(){
 var i=0,j,c,item,b;
 while(i<_tbMenus.length){j=0;while(j<_tbMenus[i][1].length){
  item=_tbMenus[i][1][j];c=item[1];
  if(c>=160&&c<192){b=tbSessionBit(c-160);item[2]=Math.floor(_tbSEnable/b)%2;item[3]=Math.floor(_tbSCheck/b)%2;}
  if(c==1007)item[2]=_tbSProgram!="";
  if(_tbSRole==1||_tbSRole==5){
   if(c==137)item[2]=(_tbSDirty&2)!=0;
   if(c==138||c==139||c==141)item[2]=(_tbSDirty&8)!=0;
   if(c==140)item[2]=(_tbSDirty&4)!=0;
   if(c==142)item[2]=srcLen()>0;
  }
  j=j+1;
 }i=i+1;}_tbChanged=1;
}
function tbSessionListen(text,fn){_tbSessionList(text,fn,1);}
function tbSessionUnlisten(text,fn){_tbSessionList(text,fn,0);}
// A changed list is a new array, so a key being dispatched reaches only the
// handlers that were registered when it arrived.
function _tbSessionList(text,fn,add){
 var k=text=="keydown"?0:text=="keyup"?1:text=="mousedown"?2:text=="mousemove"?3:text=="mouseup"?4:-1,i=0,a=[],list;
 if(k<0){if(add){while(i<_tbSExtras.length){if(_tbSExtras[i]==text&&_tbSExtras[i+1]==fn)return;i=i+2;}_tbSExtras.push(text,fn);addEventListener(text,_tbSessionExtra);}return;}
 list=_tbSCallbacks[k];
 while(i<list.length){if(list[i]==fn){if(add)return;}else a.push(list[i]);i=i+1;}
 if(add)a.push(fn);_tbSCallbacks[k]=a;
}
function _tbSessionSend(kind,e){var i=0,list=_tbSCallbacks[kind],fn;while(i<list.length){fn=list[i];_tbSessionDraw(fn,e);i=i+1;}}
function tbSessionSendKey(code){_tbSessionSend(0,{keyCode:code,charCode:0});}
function _tbSessionKey(e){
 if(e.keyCode==255&&_tbSRole==9){_tbSessionSend(0,e);return;}
 if(e.keyCode==254){tbDialogOpen(1,_tbSAboutTitle,[_tbSAbout],[]);return;}
 if(tbUIKey(e.keyCode,e.charCode))return;
 if(_tbMenu>=0){if(e.keyCode==27){_tbErase=1;_tbMenu=-1;_tbArmed=-1;_tbChanged=1;}return;}
 if((_tbSRole==1||_tbSRole==5)&&e.keyCode==113&&!e.charCode){tbSessionCommand(1004,0);return;}
 if(e.keyCode==27&&_tbSRole!=9){tbSessionCommand(1006,1);return;}
 _tbSessionSend(0,e);
}
function _tbSessionKeyUp(e){if(e.keyCode!=254)_tbSessionSend(1,e);}
function _tbSessionPointer(kind,e){
 var consumed,old=_tbSCapture,y=e.clientY,code=0,x=e.clientX;
 if(kind==2&&e.button==0)_tbSHeld=1;if(kind==4&&e.button==0)_tbSHeld=0;
 if(kind==2&&e.button==0&&!_tbDialog&&_tbMenu<0&&_tbSChrome){var fn=_tbSChrome;code=fn(1,x,y);}
 consumed=code?1:old<0?0:tbUIPointer(x,y,_tbSHeld);
 if(code)tbSessionSendKey(code);
 if(kind==2)_tbSCapture=consumed?1:-1;
 if(kind==4){_tbSClickBlock=consumed||old>0;_tbSCapture=0;if(old<0)_tbDown=0;}
 if(consumed||old>0)return;
 _tbSessionSend(kind,_tbSessionMap(e));
}
// Game viewport and document window coordinates for the program's handlers.
function _tbSessionMap(e){
 var y=e.clientY,x=e.clientX;
 if(_tbSRole==8&&_tbSViewport)e={type:e.type,clientX:x,clientY:(y-24)*480/456,offsetX:e.offsetX,offsetY:(e.offsetY-24)*480/456,button:e.button,buttons:e.buttons,movementX:e.movementX,movementY:e.movementY*480/456};
 if(_tbChromeWindow){e.clientX=x-_tbX+8;e.clientY=y-_tbY+34;e.offsetX=e.clientX;e.offsetY=e.clientY;}
 return e;
}
// Extra input retains browser adapters, but obeys session ownership.
function _tbSessionExtra(e){
 var i=0,fn;
 if(_tbSSwitching)return;
 if(e.type=="click"||e.type=="contextmenu"){
  if(e.type=="click"&&_tbSClickBlock){_tbSClickBlock=0;return;}
  if(_tbDialog||_tbMenu>=0)return;
  e=_tbSessionMap(e);
 }
 while(i<_tbSExtras.length){if(e.type==_tbSExtras[i]){fn=_tbSExtras[i+1];_tbSessionDraw(fn,e);}i=i+2;}
}
function _tbSessionDown(e){_tbSessionPointer(2,e);}
function _tbSessionMove(e){_tbSessionPointer(3,e);}
function _tbSessionUp(e){_tbSessionPointer(4,e);}
function tbSessionTransform(a,b,c,d,e,f){
 if(_tbSRole==8&&_tbSViewport)_tbC.setTransform(a,b*0.9501,c,d*0.9501,e,f*0.9501+24);
 else _tbC.setTransform(a,b,c,d,e+_tbPortRect[4],f+_tbPortRect[5]);
}
function tbSessionFrame(fn){
 _tbSFrames.push(fn);if(!_tbSPending){_tbSPending=1;requestAnimationFrame(_tbSessionFrame);}
}
function _tbSessionFrame(t){
 var jobs=_tbSFrames,i=0,fn,command,result,kind=0,j,dirty;
 _tbSFrames=[];_tbSPending=0;_tbSClock=_tbSClock+1;
 if(!_tbSConfigured){tbMenus(tbSessionDefaults());tbSessionMasks();_tbSConfigured=1;}
 command=tbMenuCommand();result=tbDialogResult();
 if(command){
  j=0;while(j<_tbMenus.length){i=0;while(i<_tbMenus[j][1].length){if(_tbMenus[j][1][i][1]==command)kind=_tbMenus[j][1][i][4];i=i+1;}j=j+1;}
  tbSessionCommand(command,kind);
 }
 if(result)tbSessionDialogResult(result);
 if(_tbSSwitching)return;
 if(_tbDialog==3&&_tbSClock%30==0){_tbCaretOn=1-_tbCaretOn;_tbChanged=1;}
 dirty=tbUIChanged();if(dirty&&_tbErase&&_tbSInvalidator){
  if(_tbChromeWindow){
   if(_tbDamage[2]<=_tbDamage[0])tbDamage(0,22,640,458);
   tbDamageClip();_tbSessionBack();tbPortPop();
  }
  fn=_tbSInvalidator;_tbSessionDraw(fn,0);tbDamageClear();_tbErase=0;
 }
 if(_tbSRole==8&&!_tbSInvalidator){
  i=_tbDialog?-1:_tbMenu+1;
  if(i!=_tbSUnder){if(_tbSUnder)_tbSessionCopy(_tbSUnder,1);_tbSUnder=i;if(i)_tbSessionCopy(i,0);}
 }
 if((_tbMenu>=0||_tbDialog)&&(_tbSInvalidator||_tbSRole==8)){
  _tbSFrames=jobs;if(!_tbSPending){_tbSPending=1;requestAnimationFrame(_tbSessionFrame);}
 }else{i=0;while(i<jobs.length){fn=jobs[i];_tbSessionDraw(fn,t);i=i+1;}}
 dirty=tbUIChanged()||dirty;
 if(_tbSRole&&(dirty||(_tbSRole==8&&(_tbMenu>=0||_tbDialog)))){
  _tbC.save();_tbC.setTransform(1,0,0,1,0,0);if(_tbSChrome){fn=_tbSChrome;fn(0,_tbSScrollY,_tbSScrollX);}
  tbUIDraw();_tbC.restore();
 }
}

// A game pauses while a menu or dialog is open. Without an invalidator the
// pixels under it wait in arena 308992-380319 and come back when it closes.
var _tbSUnder=0;
function _tbSessionCopy(s,back){
 var x=136,y=112,w=356,h=200;
 if(s>0){x=_tbMenuLeft(s-1);y=22;w=212;h=Math.min(335,_tbMenus[s-1][1].length*21+4);}
 tbScreen(308992);tbRect(308992,x,y,w,h);tbPlace(308992,x,y,1);
 tbSurface(309056,309120,w,h,w,8);tbPortReset();
 tbCopyBits(back?309056:308992,back?308992:309056);
}
// Desktop blue around the document window, white inside it.
function _tbSessionBack(){_tbC.fillStyle="#55CCFF";_tbC.fillRect(0,0,640,480);_tbC.fillRect(_tbX+1,_tbY+24,_tbW-2,_tbH-25,_tbWhite);}
function _tbSessionDraw(fn,e){
 if(_tbChromeWindow){if(tbPortPush(_tbX+16,_tbY+54,_tbW-36,_tbH-76,_tbX-8,_tbY-34)<0)return -1;fn(e);tbPortPop();}
 else fn(e);
}

var _tbSChrome=0;
function tbSessionChrome(fn){_tbSChrome=fn;}
