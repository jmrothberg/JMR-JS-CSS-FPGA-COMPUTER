// Shared file-name policy, embedded into clients that own Save As.
function tbClientFilename(a,ext,kind){
 var i=0,c,stem=0,n=0,dot=0,j,legal,on;
 if(kind){
  if(ext=="")return 1;while(i<a.length){if(a[i]==46)dot=i+1;i=i+1;}
  if(dot==0)return 0;i=dot;while(i<a.length){if(a[i]!=strByte(ext,i-dot))return 0;i=i+1;}return strByte(ext,i-dot)<0;
 }
 while(i<a.length){
  c=a[i];if(c>=97&&c<=122)c=c-32;a[i]=c;
  if(c==46){if(dot||stem==0)return 0;dot=1;}
  else{
   on=(c>=65&&c<=90)||(c>=48&&c<=57);j=0;
   while(j<17&&!on){legal=strByte("$%'-_@~`!(){}^#&",j);if(c==legal)on=1;j=j+1;}
   if(!on)return 0;if(dot)n=n+1;else stem=stem+1;
  }i=i+1;
 }
 if(stem<1||stem>8||n>3||(dot&&n==0))return 0;
 if(!dot){
  a.push(46);i=0;
  while(i<3){c=strByte(ext,i);if(c<0)break;a.push(c);i=i+1;}
 }
 if(a.length>12)return 0;return 1;
}
tbSessionNames(tbClientFilename);
