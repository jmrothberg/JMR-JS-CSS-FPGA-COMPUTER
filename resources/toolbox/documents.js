// File dialogs and SOURCE lifecycle policy. The native services only transfer
// bytes/metadata and continue an explicitly selected program after a save.
var _tbSDState=0,_tbSDCommand=0,_tbSAfter=0,_tbSPage=0,_tbSNext=0,_tbSPages=[];
var _tbSFiles=[],_tbSFileRows=[],_tbSResume=0,_tbSSwitching=0,_tbSProgram="",_tbSSuffix="";
var _tbSInvalidator=0,_tbSClock=0;
function _tbSessionStop(){
 removeEventListener("keydown",_tbSessionKey);removeEventListener("keyup",_tbSessionKeyUp);
 removeEventListener("mousedown",_tbSessionDown);removeEventListener("mousemove",_tbSessionMove);removeEventListener("mouseup",_tbSessionUp);
}
function tbSessionProgram(name){_tbSProgram=name;}
function tbSessionSuffix(ext){_tbSSuffix=ext;}
function tbSessionInvalidate(fn){_tbSInvalidator=fn;}
function tbSessionU32(p){return stgRead(p)+stgRead(p+1)*256+stgRead(p+2)*65536+stgRead(p+3)*16777216;}
function _tbSessionError(){_tbSDState=0;_tbSSwitching=0;tbDialogOpen(1,tbSessionCodes("Disk operation failed"),[],[]);}
function _tbSessionWriteName(a){var i=0;while(i<16){stgWrite(96+i,i<a.length?a[i]:0);i=i+1;}}
function _tbSessionSourceName(){
 var i=0,a=[],n;if(sysDocument(0,380320,0)<0)return a;
 if(stgRead(380337))return a;n=stgRead(380336);
 while(i<n&&i<12){a.push(stgRead(380320+i));i=i+1;}return a;
}
function _tbSessionNormalize(a){
 var i=0,c,stem=0,ext=0,dot=0,j,legal,on;
 while(i<a.length){
  c=a[i];if(c>=97&&c<=122)c=c-32;a[i]=c;
  if(c==46){if(dot||stem==0)return 0;dot=1;}
  else{
   on=(c>=65&&c<=90)||(c>=48&&c<=57);j=0;
   while(j<17&&!on){legal=strByte("$%'-_@~`!(){}^#&",j);if(c==legal)on=1;j=j+1;}
   if(!on)return 0;if(dot)ext=ext+1;else stem=stem+1;
  }i=i+1;
 }
 if(stem<1||stem>8||ext>3||(dot&&ext==0))return 0;
 if(!dot){
  a.push(46);i=0;
  if(_tbSSuffix!=""){while(i<3){c=strByte(_tbSSuffix,i);if(c<0)break;a.push(c);i=i+1;}}
  else if(_tbSRole==5){a.push(74);a.push(83);}
  else{a.push(72);a.push(84);a.push(77);}
 }
 if(a.length>12)return 0;_tbSessionWriteName(a);return 1;
}
function _tbSessionChooseSave(command,after){
 _tbSDCommand=command;_tbSAfter=after;_tbSDState=1;
 tbDialogOpen(3,tbSessionCodes("Save document as"),[],_tbSRole==1||_tbSRole==5?_tbSessionSourceName():[]);
}
function _tbSessionSaveSource(after){
 var name=_tbSessionSourceName();
 if(name.length==0){_tbSessionChooseSave(0,after);return;}
 _tbSAfter=after;_tbSessionSaveReady();
}
function _tbSessionSaveReady(){
 var i=0;
 if(_tbSRole==1||_tbSRole==5){
  // RES belongs to the Editor; it writes caret/viewport before cdone129.
  stgWrite(208,84);stgWrite(209,66);stgWrite(210,1);stgWrite(211,_tbSAfter);
  stgWrite(65,0);stgWrite(64,5);_tbSSwitching=1;tbSessionSendKey(113);
 }else{tbSessionSendKey(_tbSDCommand);_tbSDState=0;}
}
function _tbSessionHeader(role){
 stgWrite(208,0);stgWrite(65,0);tbFill(32,0,21);stgWrite(32,82);stgWrite(33,69);stgWrite(34,83);stgWrite(35,1);stgWrite(52,role);
}
function _tbSessionNew(){
 if(sysDocument(2,0,_tbSRole)<0){_tbSessionError();return;}
 _tbSessionHeader(_tbSRole);stgWrite(64,5);_tbSSwitching=1;_tbSessionStop();cdone(128,0,0);
}
function _tbSessionAfter(action){
 if(action==1){_tbSessionNew();return;}
 if(action==2){_tbSPage=0;_tbSPages=[];_tbSessionChooseOpen(1002);return;}
 if(action==3){stgWrite(96,0);_tbSSwitching=1;sysRun(96,8);}
}
function _tbSessionBefore(action){
 if((_tbSRole==1||_tbSRole==5)&&(_tbSDirty&1)){
  _tbSAfter=action;_tbSDState=3;
  tbDialogOpen(5,tbSessionCodes("Save changes?"),[],[]);
 }else _tbSessionAfter(action);
}
function _tbSessionFileAllowed(a){
 var i=0,j=0,dot=-1,c;
 if(_tbSSuffix=="")return 1;
 while(i<a.length){if(a[i]==46)dot=i;i=i+1;}
 if(dot<0)return 0;i=dot+1;
 while(i<a.length){c=strByte(_tbSSuffix,j);if(c!=a[i])return 0;i=i+1;j=j+1;}
 return strByte(_tbSSuffix,j)<0;
}
function _tbSessionChooseOpen(command){
 var count,p=380336,n,i,a,attr;
 _tbSDCommand=command;_tbSDState=4;
 count=fsList(380320,512,_tbSPage);
 if(count<0){_tbSessionError();return;}
 _tbSNext=tbSessionU32(380332);_tbSFiles=[];_tbSFileRows=[];
 if(_tbSPages.length){_tbSFiles.push(tbSessionCodes("Previous files"));_tbSFileRows.push(-2);}
 while(count>0){
  n=stgRead(p);a=[];i=0;while(i<n){a.push(stgRead(p+1+i));i=i+1;}
  attr=stgRead(p+n+7);
  if((attr&24)==0&&_tbSessionFileAllowed(a)){_tbSFileRows.push(_tbSFiles.length);_tbSFiles.push(a);}
  p=p+n+8;count=count-1;
 }
 if(stgRead(380330)){_tbSFiles.push(tbSessionCodes("More files"));_tbSFileRows.push(-1);}
 tbDialogOpen(4,tbSessionCodes("Open"),_tbSFiles,[]);
}
function tbSessionCommand(command,kind){
 if(command==255||kind==1||command==1006){_tbSessionBefore(3);return;}
 if(kind==2||command==1002){
  _tbSDCommand=command;
  if(command==1002){_tbSessionBefore(2);return;}
  _tbSPage=0;_tbSPages=[];_tbSessionChooseOpen(command);return;
 }
 if(kind==3||command==1005){_tbSessionChooseSave(kind==3?command:0,0);return;}
 if(command==1004){_tbSessionSaveSource(0);return;}
 if(command==1001){_tbSessionBefore(1);return;}
 if(command==1007){
  if(_tbSProgram==""){_tbSessionError();return;}
  _tbSessionWriteName(tbSessionCodes(_tbSProgram));_tbSSwitching=1;sysRun(96,0);return;
 }
 if(command==1009){_tbSessionWriteName(tbSessionCodes("TERMINAL"));_tbSSwitching=1;sysRun(96,4);return;}
 if(command==1010){_tbSessionHeader(1);stgWrite(64,5);_tbSSwitching=1;_tbSessionStop();cdone(128,0,0);return;}
 if(command==1011||command==1012){_tbSPage=0;_tbSPages=[];_tbSessionChooseOpen(command);return;}
 if(command==1013){_tbSessionWriteName(tbSessionCodes("UTILITY.HTM"));_tbSSwitching=1;sysRun(96,0);return;}
 if(command==1014){_tbSessionWriteName(tbSessionCodes("NOTE.HTM"));_tbSSwitching=1;sysRun(96,0);return;}
 if(command==1015){_tbSessionWriteName(tbSessionCodes("HELP.MD"));_tbSSwitching=1;sysRun(96,2);return;}
 if(command==1016){_tbSessionAfter(3);return;}
 tbSessionSendKey(command);
}
function tbSessionDialogResult(result){
 var state=_tbSDState,selection,a;
 _tbSDState=0;
 if(state==3){if(result==1)_tbSessionSaveSource(_tbSAfter);else if(result==2)_tbSessionAfter(_tbSAfter);return;}
 if(result!=1)return;
 if(state==1){
  a=tbDialogValue();
  if(!_tbSessionNormalize(a)){_tbSessionChooseSave(_tbSDCommand,_tbSAfter);return;}
  if(fsRead(96,0,380320,0)>=0){_tbSDState=2;tbDialogOpen(6,tbSessionCodes("Replace existing file?"),[],[]);return;}
 }
 if(state==1||state==2){
  if((_tbSRole==1||_tbSRole==5)&&sysDocument(1,96,_tbSRole)<0){_tbSessionError();return;}
  _tbSessionSaveReady();return;
 }
 if(state==4){
  selection=tbDialogSelection();if(selection<0||selection>=_tbSFileRows.length)return;
  if(_tbSFileRows[selection]==-1){_tbSPages.push(_tbSPage);_tbSPage=_tbSNext;_tbSessionChooseOpen(_tbSDCommand);return;}
  if(_tbSFileRows[selection]==-2){_tbSPage=_tbSPages.pop();_tbSessionChooseOpen(_tbSDCommand);return;}
  _tbSessionWriteName(_tbSFiles[selection]);
  if(_tbSDCommand==1002||_tbSDCommand==1011||_tbSDCommand==1012){
   if(_tbSDCommand==1002&&_tbSRole!=2)_tbSessionHeader(_tbSRole);
   _tbSSwitching=1;sysRun(96,_tbSDCommand==1012?3:_tbSDCommand==1011||_tbSRole==2?2:1);return;
  }
  tbSessionSendKey(_tbSDCommand);
 }
}
