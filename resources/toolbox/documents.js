// File dialogs and SOURCE lifecycle policy. The native services only transfer
// bytes/metadata and continue an explicitly selected program after a save.
var _tbSDState=0,_tbSDCommand=0,_tbSAfter=0;
var _tbSFiles=[],_tbSSwitching=0,_tbSProgram="",_tbSSuffix="";
var _tbSInvalidator=0,_tbSClock=0;
function _tbSessionStop(){
 var i=0;while(i<_tbSExtras.length){removeEventListener(_tbSExtras[i],_tbSessionExtra);i=i+2;}_tbSExtras=[];
 removeEventListener("keydown",_tbSessionKey);removeEventListener("keyup",_tbSessionKeyUp);
 removeEventListener("mousedown",_tbSessionDown);removeEventListener("mousemove",_tbSessionMove);removeEventListener("mouseup",_tbSessionUp);
}
function tbSessionProgram(text){_tbSProgram=text;}
function tbSessionSuffix(ext){_tbSSuffix=ext;}
function tbSessionInvalidate(fn){_tbSInvalidator=fn;}
function _tbSessionError(){_tbSDState=0;_tbSSwitching=0;tbDialogOpen(1,tbSessionCodes("Disk operation failed"),[],[]);}
function _tbSessionWriteName(a){var i=0;while(i<16){stgWrite(96+i,i<a.length?a[i]:0);i=i+1;}}
function tbSessionNames(fn){_tbFilename=fn;}
function _tbSessionNormalize(a){
 var fn=_tbFilename;if(!fn)return 0;
 if(!fn(a,_tbSSuffix!=""?_tbSSuffix:"TXT",0))return 0;
 _tbSessionWriteName(a);return 1;
}
function _tbSessionChooseSave(command,after){
 _tbSDCommand=command;_tbSAfter=after;_tbSDState=1;
 tbDialogOpen(3,tbSessionCodes("Save document as"),[],_tbSRole==1||_tbSRole==5?_tbDocument(0,0):[]);
}
function _tbSessionSaveReady(){
 var i=0;
 if(_tbSRole==1||_tbSRole==5){
  _tbDocument(2,_tbSAfter);
 }else{tbSessionSendKey(_tbSDCommand);_tbSDState=0;}
}
function tbDocumentHeader(value){
 stgWrite(208,0);stgWrite(65,0);tbFill(32,0,21);tbU32(32,22234450);stgWrite(52,value);
}
function _tbSessionAfter(action){
 if(action==1){_tbDocument(3,0);return;}
 if(action==2){_tbSessionChooseOpen(1002);return;}
 if(action==3){stgWrite(96,0);_tbSSwitching=1;sysRun(96,8);}
}
function _tbSessionFileAllowed(a){var fn=_tbFilename;return _tbSSuffix==""?1:fn?fn(a,_tbSSuffix,1):0;}
// Reader lists MD, TXT, HTM, JS and BAS; Compile lists HTM and JS.
function _tbSessionReadable(a){
 var i=0,e=0;while(i<a.length){e=a[i]==46?0:e*256+a[i];i=i+1;}
 return e==4740173||e==19027||(_tbSDCommand!=1012&&(e==19780||e==5527636||e==4342099));
}
// One list over every fsList page, in rows of 100; the dialog scrolls it.
function _tbSessionChooseOpen(command){
 var count,p,n,i,a,c,page=0,total=0;
 _tbSDCommand=command;_tbSDState=4;_tbSFiles=[[]];
 while(1){
  count=fsList(380320,512,page);
  if(count<0){_tbSessionError();return;}
  page=tbSessionU32(380332);p=380336;
  while(count>0){
   n=stgRead(p);a=[];i=0;while(i<n){a.push(stgRead(p+1+i));i=i+1;}
   c=stgRead(p+n+7);
   if((c&24)==0&&(_tbSDCommand>1010||_tbSRole==2?_tbSessionReadable(a):_tbSessionFileAllowed(a))){if(total%100==0&&total)_tbSFiles.push([]);_tbSFiles[_tbSFiles.length-1].push(a);total=total+1;}
   p=p+n+8;count=count-1;
  }
  if(!stgRead(380330))break;
 }
 tbDialogOpen(4,tbSessionCodes("Open"),_tbSFiles,[]);_tbN=total;_tbPaged=1;
}
function tbSessionCommand(command,kind){
 if(command==255||kind==1||command==1006){_tbDocument(4,3);return;}
 if(kind==2||command==1002){
  _tbSDCommand=command;
  if(command==1002){_tbDocument(4,2);return;}
  _tbSessionChooseOpen(command);return;
 }
 if(kind==3||command==1005){_tbSessionChooseSave(kind==3?command:0,0);return;}
 if(command==1004){_tbDocument(1,0);return;}
 if(command==1001){_tbDocument(4,1);return;}
 if(command==1007){
  if(_tbSProgram==""){_tbSessionError();return;}
  _tbSessionWriteName(tbSessionCodes(_tbSProgram));_tbSSwitching=1;sysRun(96,0);return;
 }
 if(command==1010){tbDocumentHeader(1);stgWrite(64,5);_tbSSwitching=1;_tbSessionStop();cdone(128,0,0);return;}
 if(command==1011||command==1012){_tbSessionChooseOpen(command);return;}
 if(command==1013||command==1014||command==1015){_tbSessionWriteName(tbSessionCodes(command==1013?"UTILITY.HTM":command==1014?"NOTE.HTM":"HELP.MD"));_tbSSwitching=1;sysRun(96,command==1015?2:0);return;}
 if(command==1016){_tbSessionAfter(3);return;}
 tbSessionSendKey(command);
}
function tbSessionDialogResult(result){
 var state=_tbSDState,n,a;
 _tbSDState=0;
 if(_tbDocument(5,result))return;
 if(result!=1)return;
 if(state==1){
  a=tbDialogValue();
  if(!_tbSessionNormalize(a)){
   _tbSDState=1;tbDialogOpen(3,tbSessionCodes("Name: up to 8 letters, optional .EXT"),[],a);_tbNameSelect=0;return;
  }
  if(fsRead(96,0,380320,0)>=0){_tbSDState=2;tbDialogOpen(6,tbSessionCodes("Replace existing file?"),[],[]);return;}
 }
 if(state==1||state==2){
  if((_tbSRole==1||_tbSRole==5)&&sysDocument(1,96,_tbSRole)<0){_tbSessionError();return;}
  _tbSessionSaveReady();return;
 }
 if(state==4){
  n=tbDialogSelection();if(n<0||n>=_tbN)return;
  _tbSessionWriteName(_tbRow(n));
  if(_tbSDCommand==1002||_tbSDCommand==1011||_tbSDCommand==1012){
   if(_tbSDCommand==1002&&_tbSRole!=2)tbDocumentHeader(_tbSRole);
   _tbSSwitching=1;sysRun(96,_tbSDCommand==1012?3:_tbSDCommand==1011||_tbSRole==2?2:1);return;
  }
  tbSessionSendKey(_tbSDCommand);
 }
}

// SOURCE caret/save continuation belongs to the Editor client (also Note).
var _tbSDoc=0,_tbFilename=0;
function tbSessionDocument(fn){_tbSDoc=fn;}
function _tbDocument(action,value){var fn=_tbSDoc;if(fn)return fn(action,value);if(action==4)_tbSessionAfter(value);return 0;}
function tbDocumentContinue(action){_tbSessionAfter(action);}
function tbDocumentSaveAs(after){_tbSessionChooseSave(0,after);}
function tbDocumentSuspend(on){_tbSSwitching=1;if(on)_tbSessionStop();}
