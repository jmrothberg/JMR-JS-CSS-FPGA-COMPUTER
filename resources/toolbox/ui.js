// Shared, cooperative JavaScript UI. Labels are arrays of ASCII codes because
// the native machine does not implement browser string methods.
// Caller owns scratch: 64 descriptor bytes + 32 glyph bytes, disjoint from
// application buffers and fsList's output. Redraw the app before tbUIDraw().
var _tbC=0,_tbD=0,_tbFont=0,_tbReady=0,_tbMenus=[],_tbMenu=-1;
var _tbDown=0,_tbArmed=-1,_tbCommand=0,_tbChanged=1,_tbDialog=0;
var _tbPrompt=[],_tbChoices=[],_tbValue=[],_tbSelection=0,_tbTop=0,_tbResult=0;
var _tbWhite=1,_tbLight="#CCC",_tbSelect=6;
var _tbGlyph=-1,_tbChromeWindow=1,_tbCaret=0,_tbNameSelect=0,_tbCaretOn=1;
var _tbTitle=[],_tbX=40,_tbY=48,_tbW=560,_tbH=392;
var _tbWidths=[4,6,7,10,7,11,10,3,5,5,7,7,4,7,4,7,8,8,8,8,8,8,8,8,8,8,4,4,6,8,6,8,11,8,8,8,8,7,7,8,8,6,7,9,7,12,9,8,8,8,8,7,6,8,8,12,8,8,8,5,7,5,8,8,6,8,8,7,8,8,6,8,8,4,6,8,4,12,8,8,8,8,6,7,6,8,8,12,8,8,8,5,5,5,8];
function tbUIInit(ctx,descriptor,font,title){
 _tbC=ctx;_tbD=descriptor;_tbFont=font;_tbTitle=title;
 _tbWhite=_tbSRole==9?255:1;_tbLight=_tbSRole==9?218:"#CCC";_tbSelect=_tbSRole==9?31:6;
 _tbMenus=[];_tbMenu=-1;_tbDialog=0;_tbDown=0;_tbArmed=-1;_tbCommand=0;_tbResult=0;
 _tbC.systemWindow=0;
 _tbGlyph=-1;_tbReady=toolbox(5,0,font,32)==32;
 tbSurface(descriptor,font,16,16,2,1);stgWrite(descriptor+2,1);tbInk(descriptor,0,1);
 _tbChanged=1;return _tbReady?1:0;
}
function tbText(codes,x,y){
 var i=0,c,w,j,a,b;
 if(!_tbReady)return;
 while(i<codes.length){
  c=codes[i];if(c<32||c>126)c=63;
  if(_tbGlyph!=c){
   if(tbResources(c*32,_tbFont,32)!=32)return;
   j=0;while(j<32){a=stgRead(_tbFont+j);b=stgRead(_tbFont+j+1);stgWrite(_tbFont+j,b);stgWrite(_tbFont+j+1,a);j=j+2;}
   _tbGlyph=c;
  }
  w=_tbWidths[c-32];tbRect(_tbD,0,0,w,16);tbPlace(_tbD,x,y,1);tbBlit(_tbD);
  x=x+w;i=i+1;
 }
}
function tbTextWidth(codes){var i=0,w=0,c;while(i<codes.length){c=codes[i];if(c<32||c>126)c=63;w=w+_tbWidths[c-32];i=i+1;}return w;}
function tbBox(x,y,w,h,fill){
 _tbC.fillStyle=fill;_tbC.fillRect(x,y,w,h);_tbC.fillStyle="#000";
 _tbC.fillRect(x,y,w,1);_tbC.fillRect(x,y+h-1,w,1);_tbC.fillRect(x,y,1,h);_tbC.fillRect(x+w-1,y,1,h);
}
function tbWindow(x,y,w,h,title){_tbX=x;_tbY=y;_tbW=w;_tbH=h;_tbTitle=title;_tbChanged=1;}
function tbMenus(menus){_tbMenus=menus;_tbMenu=-1;_tbArmed=-1;_tbChanged=1;}
function tbMenuEnabled(menu,item,on){_tbMenus[menu][1][item][2]=on;_tbChanged=1;}
function tbMenuChecked(menu,item,on){_tbMenus[menu][1][item][3]=on;_tbChanged=1;}
function tbDialogOpen(kind,prompt,choices,value){
 _tbDialog=kind;_tbPrompt=prompt;_tbChoices=choices;_tbValue=value;
 _tbSelection=0;_tbTop=0;_tbResult=0;_tbMenu=-1;_tbArmed=-1;_tbCaret=value.length;_tbNameSelect=value.length>0;_tbChanged=1;
}
function tbDialogValue(){return _tbValue;}
function tbDialogSelection(){return _tbSelection;}
function tbDialogResult(){var r=_tbResult;_tbResult=0;return r;}
function tbMenuCommand(){var r=_tbCommand;_tbCommand=0;return r;}
function tbUIChanged(){var r=_tbChanged;_tbChanged=0;return r;}
function tbUIKey(code,ch){
 if(!_tbDialog)return 0;
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
   if(_tbValue.length<12){i=_tbValue.length;while(i>_tbCaret){_tbValue[i]=_tbValue[i-1];i=i-1;}_tbValue[_tbCaret]=ch;_tbCaret=_tbCaret+1;}
  }
 }else if(_tbDialog==4){
  if(code==38 && _tbSelection>0)_tbSelection=_tbSelection-1;
  if(code==40 && _tbSelection+1<_tbChoices.length)_tbSelection=_tbSelection+1;
  if(_tbSelection<_tbTop)_tbTop=_tbSelection;
  if(_tbSelection>=_tbTop+5)_tbTop=_tbSelection-4;
 }
 _tbChanged=1;return 1;
}
function tbUIPointer(x,y,buttons){
 var down=buttons==1 && !_tbDown,up=buttons==0 && _tbDown;
 var i=0,left=34,w,row,hit=-1,items;
 _tbDown=buttons==1;
 if(_tbDialog){
  if(y>=272 && y<298){
   if(_tbDialog==5){if(x>=152&&x<244)hit=1;else if(x>=252&&x<344)hit=2;else if(x>=352&&x<444)hit=3;}
   else if(x>=340 && x<432)hit=1;else if(_tbDialog!=1 && x>=220 && x<320)hit=2;
  }
  if(_tbDialog==3&&down&&x>=156&&x<484&&y>=158&&y<188){
   i=0;left=162;while(i<_tbValue.length&&x>left+_tbWidths[_tbValue[i]-32]/2){left=left+_tbWidths[_tbValue[i]-32];i=i+1;}_tbCaret=i;_tbNameSelect=0;
  }
  if(_tbDialog==4 && down){
   if(x>=468 && x<484 && y>=160 && y<180 && _tbTop>0){_tbTop=_tbTop-1;_tbSelection=_tbTop;}
   else if(x>=468 && x<484 && y>=240 && y<260 && _tbTop+5<_tbChoices.length){_tbTop=_tbTop+1;_tbSelection=_tbTop;}
   else if(x>=160 && x<468 && y>=160 && y<260){
    row=_tbTop+Math.floor((y-160)/20);if(row<_tbChoices.length)_tbSelection=row;
   }
  }
  if(down)_tbArmed=hit;
  if(up){if(hit>0 && hit==_tbArmed){_tbResult=hit;_tbDialog=0;}_tbArmed=-1;}
  _tbChanged=1;return 1;
 }
 if(y<22 && x>=30){
  while(i<_tbMenus.length){w=tbTextWidth(_tbMenus[i][0])+20;if(x>=left&&x<left+w)hit=i;left=left+w;i=i+1;}
  if(down || (_tbDown && _tbMenu>=0)){_tbMenu=hit;_tbArmed=-1;_tbChanged=1;}
  return 1;
 }
 if(_tbMenu>=0){
  i=0;left=34;while(i<_tbMenu){left=left+tbTextWidth(_tbMenus[i][0])+20;i=i+1;}
  if(left>420)left=420;
  items=_tbMenus[_tbMenu][1];row=Math.floor((y-24)/21);
  if(x>=left&&x<left+212&&row>=0&&row<items.length&&items[row][0].length>0&&items[row][2])hit=row;
  _tbArmed=hit;
  if(up){if(hit>=0)_tbCommand=items[hit][1];_tbMenu=-1;_tbArmed=-1;}
  _tbChanged=1;return 1;
 }
 // Standard upper-left close box. Command 255 is reserved for window close.
 if(_tbChromeWindow && down && x>=_tbX+5 && x<_tbX+20 && y>=_tbY+5 && y<_tbY+20){_tbArmed=255;return 1;}
 if(up && _tbArmed==255){if(x>=_tbX+5&&x<_tbX+20&&y>=_tbY+5&&y<_tbY+20)_tbCommand=255;_tbArmed=-1;return 1;}
 return 0;
}
function tbUIDraw(){
 var i,left=34,w,items,row,caret,j;
 // The ship/keyboard recovery area at x<30 stays owned by the system.
 _tbC.fillStyle=_tbWhite;_tbC.fillRect(30,0,610,24);_tbC.fillRect(30,21,610,1,0);
 i=0;while(i<_tbMenus.length){w=tbTextWidth(_tbMenus[i][0])+20;
  if(i==_tbMenu){_tbC.fillRect(left,0,w,21,0);tbInk(_tbD,_tbWhite,1);}
  tbText(_tbMenus[i][0],left+8,3);tbInk(_tbD,0,1);left=left+w;i=i+1;}
 if(_tbChromeWindow){
 tbBox(_tbX,_tbY,_tbW,24,_tbWhite);tbBox(_tbX+5,_tbY+5,15,15,_tbWhite);tbText(_tbTitle,_tbX+(_tbW-tbTextWidth(_tbTitle))/2,_tbY+4);
 _tbC.fillStyle="#000";_tbC.fillRect(_tbX,_tbY+24,1,_tbH-24);_tbC.fillRect(_tbX+_tbW-1,_tbY+24,1,_tbH-24);_tbC.fillRect(_tbX,_tbY+_tbH-1,_tbW,1);
 }
 if(_tbMenu>=0){
  left=34;i=0;while(i<_tbMenu){left=left+tbTextWidth(_tbMenus[i][0])+20;i=i+1;}
  if(left>420)left=420;items=_tbMenus[_tbMenu][1];tbBox(left,22,212,items.length*21+4,_tbWhite);
  i=0;while(i<items.length){
   if(items[i][0].length==0){_tbC.fillStyle=_tbSRole==9?146:"#888";_tbC.fillRect(left+5,34+i*21,202,1);}
   else{
    if(i==_tbArmed&&items[i][2]){_tbC.fillRect(left+1,24+i*21,210,21,0);tbInk(_tbD,_tbWhite,1);}
    tbText(items[i][0],left+20,26+i*21);
    if(items[i][3])_tbC.fillRect(left+6,31+i*21,6,6,i==_tbArmed?_tbWhite:0);
    if(!items[i][2]){j=0;while(j<16){_tbC.fillRect(left+20,26+i*21+j,180,1,_tbWhite);j=j+2;}}
    tbInk(_tbD,0,1);
   }
   i=i+1;
  }
 }
 if(_tbDialog){
  tbBox(136,112,368,200,_tbWhite);tbBox(139,115,362,194,_tbWhite);tbText(_tbPrompt,152,132);
  if(_tbDialog==3){
   tbBox(156,158,328,30,_tbWhite);
   if(_tbNameSelect){_tbC.fillStyle=_tbSelect;_tbC.fillRect(160,161,tbTextWidth(_tbValue)+4,21);}
   tbText(_tbValue,162,164);caret=162;i=0;while(i<_tbCaret){caret=caret+_tbWidths[_tbValue[i]-32];i=i+1;}
   if(_tbCaretOn&&!_tbNameSelect){_tbC.fillStyle="#000";_tbC.fillRect(caret,162,1,20);}
  }
  if(_tbDialog==1&&_tbChoices.length>0)tbText(_tbChoices[0],152,164);
  if(_tbDialog==4){
   i=0;while(i<5 && _tbTop+i<_tbChoices.length){row=_tbTop+i;if(row==_tbSelection){_tbC.fillStyle=_tbSelect;_tbC.fillRect(160,160+i*20,300,20);}tbText(_tbChoices[row],164,162+i*20);i=i+1;}
  }
  if(_tbDialog==4 && _tbChoices.length>5){tbBox(468,160,16,20,_tbWhite);tbText([94],472,162);tbBox(468,240,16,20,_tbWhite);tbText([118],472,242);}
  if(_tbDialog==5){
   tbBox(149,269,98,32,_tbWhite);tbBox(152,272,92,26,_tbWhite);tbText([83,97,118,101],178,277);
   tbBox(252,272,92,26,_tbWhite);tbText([68,105,115,99,97,114,100],266,277);
   tbBox(352,272,92,26,_tbWhite);tbText([67,97,110,99,101,108],366,277);
  }else{
  tbBox(337,269,98,32,_tbWhite);tbBox(340,272,92,26,_tbWhite);tbText(_tbDialog==3?[83,97,118,101]:_tbDialog==4?[79,112,101,110]:_tbDialog==6?[82,101,112,108,97,99,101]:[79,75],_tbDialog==6?353:362,277);
  if(_tbDialog!=1){tbBox(220,272,100,26,_tbWhite);tbText([67,97,110,99,101,108],244,277);}
  }
 }
}
