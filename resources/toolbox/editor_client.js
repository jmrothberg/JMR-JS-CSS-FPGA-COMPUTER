// Shared document callbacks: Editor and Note use the same SOURCE owner.
function editorDocument(action,value){
 var a=[],i=0,n;
 if(action==0){
  if(sysDocument(0,380320,0)<0||stgRead(380337))return a;n=stgRead(380336);
  while(i<n&&i<12){a.push(stgRead(380320+i));i=i+1;}return a;
 }
 if(action==1){
  ED.after=value;a=editorDocument(0,0);if(a.length==0)tbDocumentSaveAs(value);else editorDocument(2,value);
 }else if(action==2){
  stgWrite(208,84);stgWrite(209,66);stgWrite(210,1);stgWrite(211,value);
  stgWrite(65,0);stgWrite(64,5);tbDocumentSuspend(0);tbSessionSendKey(113);
 }else if(action==3){
  if(sysDocument(2,0,editorRole)<0){tbDialogOpen(1,tbSessionCodes("Disk operation failed"),[],[]);return 1;}
  tbDocumentHeader(editorRole);stgWrite(64,5);tbDocumentSuspend(1);cdone(128,0,0);
 }else if(action==4){
  ED.after=value;
  if(dirty){ED.confirm=1;tbDialogOpen(5,tbSessionCodes("Save changes?"),[],[]);}
  else tbDocumentContinue(value);
 }else if(action==5){
  if(!ED.confirm)return 0;ED.confirm=0;
  if(value==1)editorDocument(1,ED.after);else if(value==2)tbDocumentContinue(ED.after);
 }
 return 1;
}
tbSessionDocument(editorDocument);
function editorResume(){
 ED.resume=0;
if(stgRead(208)==84&&stgRead(209)==66&&stgRead(210)==1){
 if(stgRead(65)==1)ED.resume=stgRead(211);stgWrite(208,0);stgWrite(65,0);
}
}
editorResume();
