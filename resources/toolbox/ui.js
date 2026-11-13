// Shared, cooperative JavaScript UI. Labels are arrays of ASCII codes because
// the native machine does not implement browser string methods.
// Caller owns scratch: 64 descriptor bytes + 32 glyph bytes, disjoint from
// application buffers and fsList's output. Redraw the app before tbUIDraw().
var _tbC=0,_tbD=0,_tbFont=0,_tbReady=0,_tbMenus=[],_tbMenu=-1;
var _tbErase=1;
var _tbDown=0,_tbArmed=-1,_tbCommand=0,_tbChanged=1,_tbDialog=0,_tbFlash=0,_tbFlashRow=0;
// Frames a list's scroll arrow or gray track has been held (_tbArmed 10-13).
var _tbHold=0;
var _tbPrompt=[],_tbChoices=[],_tbValue=[],_tbSelection=0,_tbTop=0,_tbResult=0;
// A kind 4 list over 128 rows (the array limit) is paged: rows of 100.
var _tbN=0,_tbPaged=0;
var _tbWhite=1,_tbSelect=6;
var _tbGlyph=-1,_tbChromeWindow=1,_tbCaret=0,_tbNameSelect=0,_tbCaretOn=1;
var _tbDragRect=[0,0,0,0],_tbDragX=0,_tbDragY=0;
var _tbTitle=[],_tbX=40,_tbY=48,_tbW=560,_tbH=392;
// Generated from canonical SYSTEM font advances; the linker verifies it.
// Decode before any public UI call, preserving pre-init tbTextWidth behavior.
var _tbWidths=[];
function _tbInitWidths(){
 var i=0;while(i<95){_tbWidths.push(strByte("DFGJGKJCEEGGDGDGHHHHHHHHHHDDFHFHKHHHHGGHHFGIGLIHHHHGFHHLHHHEGEHHFHHGHHFHHDFHDLHHHHFGFHHLHHHEEEH",i)-64);i=i+1;}
}
_tbInitWidths();
function tbUIInit(ctx,d,p,title){
 while(_tbPort>0)tbPortPop();tbPortReset();
 _tbC=ctx;_tbD=d;_tbFont=p;_tbTitle=title;
 _tbWhite=_tbSRole==9?255:1;_tbSelect=_tbSRole==9?31:6;
 _tbMenus=[];_tbMenu=-1;_tbDialog=0;_tbDown=0;_tbArmed=-1;_tbCommand=0;_tbResult=0;
 _tbC.systemWindow=0;
 _tbGlyph=-1;
 // TBF1 schema1: printable ASCII32..126,16rows; glyph bytes already MSB-first.
 _tbReady=(_tbCaps&3968)==3968&&tbResources(20608,p,8)==8&&tbSessionU32(p)==826688084&&tbSessionU32(p+4)==274669569;
 if(!_tbReady){_tbChanged=1;return 0;}
 tbSurface(d,p,16,16,2,1);stgWrite(d+2,1);tbInk(d,0,1);
 _tbChanged=1;return _tbReady?1:0;
}
// Text is a string or an array of codes (DrawString): a string is read in
// place, so drawing it makes no array.
function tbText(codes,x,y){
 var i=0,c,w,s=typeof codes==="string";
 if(!_tbReady)return;
 while(1){
  c=s?strByte(codes,i):i<codes.length?codes[i]:-1;if(c<0)return;if(c<32||c>126)c=63;
  if(_tbGlyph!=c){
   if(tbResources(20736+(c-32)*32,_tbFont,32)!=32)return;
   _tbGlyph=c;
  }
  w=_tbWidths[c-32];tbRect(_tbD,0,0,w,16);tbPlaceScreen(_tbD,x,y,1);tbBlit(_tbD);
  x=x+w;i=i+1;
 }
}
function tbTextWidth(codes){var i=0,w=0,c,s=typeof codes==="string";while(1){c=s?strByte(codes,i):i<codes.length?codes[i]:-1;if(c<0)return w;if(c<32||c>126)c=63;w=w+_tbWidths[c-32];i=i+1;}return w;}
function tbBox(x,y,w,h,value){
 _tbC.fillStyle=value;_tbC.fillRect(x,y,w,h);_tbC.fillStyle="#000";
 _tbC.fillRect(x,y,w,1);_tbC.fillRect(x,y+h-1,w,1);_tbC.fillRect(x,y,1,h);_tbC.fillRect(x+w-1,y,1,h);
}
// Window policy is software. Rectangles are caller-owned [x,y,width,height].
var _tbDamage=[640,480,0,0],_tbPort=0,_tbPortRect=[0,0,640,480,0,0],_tbPortStack=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
function tbDamage(x,y,w,h){
 var a=Math.max(0,x),b=Math.max(22,y);w=Math.min(640,x+w);h=Math.min(480,y+h);
 if(w<=a||h<=b)return;
 _tbDamage[0]=Math.min(_tbDamage[0],a);_tbDamage[1]=Math.min(_tbDamage[1],b);
 _tbDamage[2]=Math.max(_tbDamage[2],w);_tbDamage[3]=Math.max(_tbDamage[3],h);
}
function tbDamageClear(){var i;_tbDamage[0]=640;_tbDamage[1]=480;_tbDamage[2]=0;_tbDamage[3]=0;}
function tbDamageClip(){return tbPortPush(_tbDamage[0],_tbDamage[1],Math.max(0,_tbDamage[2]-_tbDamage[0]),Math.max(0,_tbDamage[3]-_tbDamage[1]),0,0);}
function tbWindowPart(x,y,a,b,w,h){
 if(x<a||y<b||x>=a+w||y>=b+h)return 0;
 if(x>=a+5&&x<a+20&&y>=b+5&&y<b+20)return 2;
 if(x>=a+w-16&&y>=b+h-16)return 3;
 return y<b+24?1:6;
}
function tbWindowAdjust(codes,x,y,kind){
 _tbErase=1;
 tbDamage(codes[0],codes[1],codes[2],codes[3]);
 if(kind){codes[2]=Math.max(180,Math.min(612,codes[2]+x));codes[3]=Math.max(120,Math.min(420,codes[3]+y));}
 else{codes[0]=Math.max(0,Math.min(460,codes[0]+x));codes[1]=Math.max(22,Math.min(360,codes[1]+y));}
 tbDamage(codes[0],codes[1],codes[2],codes[3]);_tbChanged=1;
}
// Axis-independent scrollbar parts: arrows, thumb, page before/after.
function tbControlPart(p,x,w,h,y,n){
 if(p<x||p>=x+w)return 0;
 if(p<x+h)return 4;if(p>=x+w-h)return 5;
 return p<y?8:p<y+n?7:9;
}
function tbControlValue(value,n,w){return Math.max(0,Math.min(w,value+n));}
// In tbWindow, tbMenus, tbDamageClear and tbDialogOpen the unused `var i`
// stops the compiler copying the body into every caller: bank words.
function tbWindow(x,y,w,h,title){var i;_tbX=x;_tbY=y;_tbW=w;_tbH=h;_tbTitle=title;_tbDragRect[0]=x;_tbDragRect[1]=y;_tbDragRect[2]=w;_tbDragRect[3]=h;_tbChanged=1;}
function _tbMenuLeft(item){var i=0,x=34;while(i<item){x=x+tbTextWidth(_tbMenus[i][0])+20;i=i+1;}return Math.min(420,x);}
function _tbButton(x,w,codes,on){if(on)tbBox(x-3,269,w+6,32,_tbWhite);tbBox(x,272,w,26,_tbWhite);tbText(codes,x+(w-tbTextWidth(codes))/2,277);}
function tbMenus(menus){var i;_tbMenus=menus;_tbMenu=-1;_tbArmed=-1;_tbChanged=1;}
function tbMenuEnabled(menu,item,on){_tbMenus[menu][1][item][2]=on;_tbChanged=1;}
function tbMenuChecked(menu,item,on){_tbMenus[menu][1][item][3]=on;_tbChanged=1;}
function tbDialogOpen(kind,a,rows,value){
 var i;_tbErase=1;
 _tbDialog=kind;_tbPrompt=a;_tbChoices=rows;_tbValue=value;_tbN=rows.length;_tbPaged=0;
 _tbSelection=0;_tbTop=0;_tbResult=0;_tbMenu=-1;_tbArmed=-1;_tbCaret=value.length;_tbNameSelect=value.length>0;_tbChanged=1;
}
function tbDialogValue(){return _tbValue;}
function _tbRow(r){return _tbPaged?_tbChoices[Math.floor(r/100)][r%100]:_tbChoices[r];}
function tbDialogSelection(){return _tbSelection;}
function tbDialogResult(){var r=_tbResult;_tbResult=0;return r;}
// Polled once a frame: steps the chosen item's blink, then hands out its command.
function tbMenuCommand(){var r;tbUIFlash();r=_tbCommand;_tbCommand=0;return r;}
function tbUIChanged(){var r=_tbChanged;_tbChanged=0;return r;}
// One frame of the chosen menu item's blink; the command goes out after it.
// The blink redraws only the open menu; the content under it is repainted
// once, when the menu closes.
// Also steps a held list scroll arrow or gray track: once, then repeating.
function tbUIFlash(){
 var j,d;
 if(_tbDialog==4&&_tbDown&&_tbArmed>=10&&_tbArmed<14){
  if(_tbHold==0||(_tbHold>12&&_tbHold%3==0)){
   j=_tbN-5;d=_tbArmed==10?-1:_tbArmed==11?1:_tbArmed==12?-5:5;
   if(j>0){_tbTop=Math.max(0,Math.min(j,_tbTop+d));_tbSelection=Math.max(_tbTop,Math.min(_tbTop+4,_tbSelection));_tbChanged=1;}
  }
  _tbHold=_tbHold+1;
 }
 if(_tbFlash){_tbFlash=_tbFlash-1;_tbChanged=1;if(!_tbFlash){_tbCommand=_tbFlashRow;_tbMenu=-1;_tbArmed=-1;_tbErase=1;}}return _tbFlash;
}
function tbUIKey(code,ch){
 if(!_tbDialog)return 0;_tbErase=1;
 if(code==27){_tbResult=_tbDialog==5?3:2;_tbDialog=0;}
 else if(code==13){_tbDialog=0;_tbResult=1;}
 else if(_tbDialog==3){
  var i;
  if(code==37){if(_tbCaret>0)_tbCaret=_tbCaret-1;_tbNameSelect=0;}
  else if(code==39){if(_tbCaret<_tbValue.length)_tbCaret=_tbCaret+1;_tbNameSelect=0;}
  else if(code==36){_tbCaret=0;_tbNameSelect=0;}
  else if(code==35){_tbCaret=_tbValue.length;_tbNameSelect=0;}
  else if(code==8){
   if(_tbNameSelect){_tbValue=[];_tbCaret=0;_tbNameSelect=0;}
   else if(_tbCaret>0){i=_tbCaret;while(i<_tbValue.length){_tbValue[i-1]=_tbValue[i];i=i+1;}_tbValue.length=_tbValue.length-1;_tbCaret=_tbCaret-1;}
  }else if(ch>=32&&ch<=126){
   if(_tbNameSelect){_tbValue=[];_tbCaret=0;_tbNameSelect=0;}
   // 8.3: no ninth character before the dot.
   i=0;while(i<_tbValue.length&&_tbValue[i]!=46)i=i+1;
   if(_tbValue.length<12&&(ch==46||i<8||_tbCaret>i)){i=_tbValue.length;while(i>_tbCaret){_tbValue[i]=_tbValue[i-1];i=i-1;}_tbValue[_tbCaret]=ch;_tbCaret=_tbCaret+1;}
  }
 }else if(_tbDialog==4){
  // Up/Down a row, Page Up/Page Down five rows, over the whole list.
  var j=code==38?-1:code==40?1:code==33?-5:code==34?5:0;
  _tbSelection=Math.max(0,Math.min(_tbN-1,_tbSelection+j));
  if(_tbSelection<_tbTop)_tbTop=_tbSelection;
  if(_tbSelection>=_tbTop+5)_tbTop=_tbSelection-4;
 }
 _tbChanged=1;return 1;
}
function tbUIPointer(x,y,buttons){
 var down=buttons==1 && !_tbDown,up=buttons==0 && _tbDown;
 var i=0,left=34,w,row,hit=-1,items,j,c;
 if(_tbFlash)return 1;
 _tbDown=buttons==1;
 if(_tbDialog){
  if(y>=272 && y<298){
   if(_tbDialog==5){if(x>=152&&x<244)hit=1;else if(x>=252&&x<344)hit=2;else if(x>=352&&x<444)hit=3;}
   else if(x>=340 && x<432)hit=1;else if(_tbDialog!=1 && x>=220 && x<320)hit=2;
  }
  if(_tbDialog==3&&down&&x>=156&&x<484&&y>=158&&y<188){
   i=0;left=162;while(i<_tbValue.length&&x>left+_tbWidths[_tbValue[i]-32]/2){left=left+_tbWidths[_tbValue[i]-32];i=i+1;}_tbCaret=i;_tbNameSelect=0;
  }
  if(down)_tbArmed=hit;
  j=_tbN-5;
  if(_tbDialog==4 && down){
   // Scroll bar, as the Mac: an arrow moves a row and the gray track a page,
   // repeating while held (tbUIFlash); the thumb is dragged.
   if(x>=468 && x<484 && y>=160 && y<260){
    c=j>0?180+Math.floor(_tbTop*40/j):180;
    _tbArmed=y<180?10:y>=240?11:y<c?12:y>=c+20?13:14;_tbHold=0;
    if(_tbArmed<14)tbUIFlash(); // the first step at once, as the Mac
   }
   else if(x>=160 && x<468 && y>=160 && y<260){
    row=_tbTop+Math.floor((y-160)/20);if(row<_tbN)_tbSelection=row;
   }
  }
  if(_tbDialog==4 && _tbDown && _tbArmed==14 && j>0){
   _tbTop=Math.max(0,Math.min(j,Math.round((y-190)*j/40)));_tbSelection=Math.max(_tbTop,Math.min(_tbTop+4,_tbSelection));
  }
  // The dialog covers the same box until it closes; only then is the content
  // under it repainted.
  if(up){if(hit>0 && hit==_tbArmed){_tbResult=hit;_tbDialog=0;_tbErase=1;}_tbArmed=-1;}
  _tbChanged=1;return 1;
 }
 if(y<22 && x>=30){
  while(i<_tbMenus.length){w=tbTextWidth(_tbMenus[i][0])+20;if(x>=left&&x<left+w)hit=i;left=left+w;i=i+1;}
  // Content under a menu is repainted only when that menu goes away.
  if(down || (_tbDown && _tbMenu>=0)){if(hit!=_tbMenu&&_tbMenu>=0)_tbErase=1;_tbMenu=hit;_tbArmed=-1;_tbChanged=1;}
  return 1;
 }
 if(_tbMenu>=0){
  left=_tbMenuLeft(_tbMenu);
  items=_tbMenus[_tbMenu][1];row=Math.floor((y-24)/21);
  if(x>=left&&x<left+212&&row>=0&&row<items.length&&items[row][0].length>0&&items[row][2])hit=row;
  _tbArmed=hit;
  // As the Mac, the chosen item blinks before its command is sent.
  if(up){if(hit>=0){_tbFlash=6;_tbFlashRow=items[hit][1];}else{_tbMenu=-1;_tbArmed=-1;_tbErase=1;}}
  _tbChanged=1;return 1;
 }
 if(_tbChromeWindow){
  hit=tbWindowPart(x,y,_tbX,_tbY,_tbW,_tbH);
  if(down&&hit>0&&hit<4){_tbArmed=hit;_tbDragX=x;_tbDragY=y;_tbDragRect[0]=_tbX;_tbDragRect[1]=_tbY;_tbDragRect[2]=_tbW;_tbDragRect[3]=_tbH;return 1;}
  if(_tbArmed>0&&_tbArmed<4){
   if(_tbDown&&_tbArmed!=2){tbWindowAdjust(_tbDragRect,x-_tbDragX,y-_tbDragY,_tbArmed==3);_tbX=_tbDragRect[0];_tbY=_tbDragRect[1];_tbW=_tbDragRect[2];_tbH=_tbDragRect[3];if(_tbSChrome){var fn=_tbSChrome;fn(2,_tbW-36,_tbH-76);}_tbDragX=x;_tbDragY=y;}
   if(up){if(_tbArmed==2&&hit==2)_tbCommand=255;_tbArmed=-1;}_tbChanged=1;return 1;
  }
 }
 return 0;
}
function tbUIDraw(){
 tbPortReset();
 var i,left=34,w,items,row,caret,j,lit;
 if(!_tbReady){
  _tbC.fillStyle=0;_tbC.fillRect(30,0,610,22);
  _tbC.fillStyle=_tbWhite;_tbC.fillText((_tbCaps&3968)!=3968?"Toolbox needs matching FPGA":"SYSTEM.SYS UI font unavailable",34,16);return;
 }
 // The ship/keyboard recovery area at x<30 stays owned by the system.
 _tbC.fillStyle=_tbWhite;_tbC.fillRect(30,0,610,22);_tbC.fillRect(30,21,610,1,0);
 i=0;while(i<_tbMenus.length){w=tbTextWidth(_tbMenus[i][0])+20;
  if(i==_tbMenu){_tbC.fillRect(left,0,w,21,0);tbInk(_tbD,_tbWhite,1);}
  tbText(_tbMenus[i][0],left+8,3);tbInk(_tbD,0,1);left=left+w;i=i+1;}
 if(_tbChromeWindow){
 tbBox(_tbX,_tbY,_tbW,24,_tbWhite);tbBox(_tbX+5,_tbY+5,15,15,_tbWhite);tbText(_tbTitle,_tbX+(_tbW-tbTextWidth(_tbTitle))/2,_tbY+4);
 _tbC.fillStyle="#000";_tbC.fillRect(_tbX,_tbY+24,1,_tbH-24);_tbC.fillRect(_tbX+_tbW-1,_tbY+24,1,_tbH-24);_tbC.fillRect(_tbX,_tbY+_tbH-1,_tbW,1);
 }
 if(_tbMenu>=0){
  left=_tbMenuLeft(_tbMenu);items=_tbMenus[_tbMenu][1];tbBox(left,22,212,items.length*21+4,_tbWhite);
  i=0;while(i<items.length){
   if(items[i][0].length==0){_tbC.fillStyle=_tbSRole==9?146:"#888";_tbC.fillRect(left+5,34+i*21,202,1);}
   else{
    lit=i==_tbArmed&&items[i][2]&&!(_tbFlash&1);
    if(lit){_tbC.fillRect(left+1,24+i*21,210,21,0);tbInk(_tbD,_tbWhite,1);}
    tbText(items[i][0],left+20,26+i*21);
    if(items[i][3])_tbC.fillRect(left+6,31+i*21,6,6,lit?_tbWhite:0);
    if(!items[i][2]){j=0;while(j<16){_tbC.fillRect(left+20,26+i*21+j,180,1,_tbWhite);j=j+2;}}
    tbInk(_tbD,0,1);
   }
   i=i+1;
  }
 }
 if(_tbDialog){
  tbBox(136,112,356,200,_tbWhite);tbBox(139,115,350,194,_tbWhite);tbText(_tbPrompt,152,132);
  if(_tbDialog==3){
   tbBox(156,158,328,30,_tbWhite);
   if(_tbNameSelect){_tbC.fillStyle=_tbSelect;_tbC.fillRect(160,161,tbTextWidth(_tbValue)+4,21);}
   tbText(_tbValue,162,164);caret=162;i=0;while(i<_tbCaret){caret=caret+_tbWidths[_tbValue[i]-32];i=i+1;}
   if(_tbCaretOn&&!_tbNameSelect){_tbC.fillStyle="#000";_tbC.fillRect(caret,162,1,20);}
  }
  if(_tbDialog==1){i=0;while(i<_tbChoices.length&&i<5){tbText(_tbChoices[i],152,160+i*20);i=i+1;}}
  if(_tbDialog==4){
   i=0;while(i<5 && _tbTop+i<_tbN){row=_tbTop+i;if(row==_tbSelection){_tbC.fillStyle=_tbSelect;_tbC.fillRect(160,160+i*20,300,20);}tbText(_tbRow(row),164,162+i*20);i=i+1;}
  }
  if(_tbDialog==4){
   // The bar stays at either end and with a short list (white, no box).
   j=_tbN-5;
   tbBox(468,160,16,100,j>0?"#CCC":_tbWhite);tbBox(468,160,16,20,_tbWhite);tbBox(468,240,16,20,_tbWhite);
   _tbArrow(471,167,0);_tbArrow(471,247,1);
   if(j>0)tbBox(468,180+Math.floor(_tbTop*40/j),16,20,_tbWhite);
  }
  if(_tbDialog==5){
   _tbButton(152,92,tbSessionCodes("Save"),1);_tbButton(252,92,tbSessionCodes("Discard"),0);_tbButton(352,92,tbSessionCodes("Cancel"),0);
  }else{
   _tbButton(340,92,tbSessionCodes(_tbDialog==3?"Save":_tbDialog==4?"Open":_tbDialog==6?"Replace":"OK"),1);
   if(_tbDialog!=1)_tbButton(220,100,tbSessionCodes("Cancel"),0);
  }
 }
}

// Scroll arrow as in the window scroll bars: 9 by 5, up (0) or down (1).
function _tbArrow(x,y,d){var i=0;while(i<5){_tbC.fillRect(d?x+i:x+4-i,y+i,d?9-2*i:1+2*i,1);i=i+1;}}

// Four nested drawing ports; no framebuffer backing store or per-frame allocation.
function tbPortPush(x,y,w,h,a,b){
 var i=0;if(_tbPort>=4||(_tbCaps&2048)==0)return -1;
 while(i<6){_tbPortStack[_tbPort*6+i]=_tbPortRect[i];i=i+1;}
 _tbPortRect[0]=Math.max(_tbPortRect[0],x);_tbPortRect[1]=Math.max(_tbPortRect[1],y);
 _tbPortRect[2]=Math.min(_tbPortRect[2],x+w);_tbPortRect[3]=Math.min(_tbPortRect[3],y+h);
 _tbPortRect[4]=_tbPortRect[4]+a;_tbPortRect[5]=_tbPortRect[5]+b;_tbPort=_tbPort+1;
 _tbC.save();_tbC.setTransform(1,0,0,1,_tbPortRect[4],_tbPortRect[5]);
 return tbPortClip(_tbPortRect[0],_tbPortRect[1],Math.max(0,_tbPortRect[2]-_tbPortRect[0]),Math.max(0,_tbPortRect[3]-_tbPortRect[1]));
}
function tbPortPop(){
 var i=0;if(!_tbPort)return -1;_tbPort=_tbPort-1;
 while(i<6){_tbPortRect[i]=_tbPortStack[_tbPort*6+i];i=i+1;}_tbC.restore();
 return tbPortClip(_tbPortRect[0],_tbPortRect[1],Math.max(0,_tbPortRect[2]-_tbPortRect[0]),Math.max(0,_tbPortRect[3]-_tbPortRect[1]));
}

function tbWindowBounds(){return _tbDragRect;}

function tbPortBounds(){return _tbPortRect;}
