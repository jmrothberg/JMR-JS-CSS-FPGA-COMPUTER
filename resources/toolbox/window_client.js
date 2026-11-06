// Shared bounded window stacking policy; IDs are0..7, back to front.
var tbClientOrder=[];
function tbWindowFocus(id){if(id<0||id>7||id!=Math.floor(id))return -1;tbWindowRemove(id);tbClientOrder.push(id);return id;}
function tbWindowRemove(id){
 var i=0,j=0;while(i<tbClientOrder.length){if(tbClientOrder[i]!=id){tbClientOrder[j]=tbClientOrder[i];j=j+1;}i=i+1;}
 tbClientOrder.length=j;return j?tbClientOrder[j-1]:255;
}
function tbWindowAt(i){return i>=0&&i<tbClientOrder.length?tbClientOrder[i]:255;}
