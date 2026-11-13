// String operations library (card copy: STROPS.JS). Added by both compilers
// only when a program calls one of these methods or built-ins; each method
// helper runs the string version when the receiver is a string and otherwise
// calls the receiver's own method, so arrays and objects are unchanged.
// Results are built in a borrowed, restored arena tail and made with
// stringFromBytes(addr,len,1). Strings are bytes; whitespace/case are ASCII.
function _jmr_sop_build(p,n,m){if(n<=0)return "";var w=Math.floor((n+3)/4),c=380928-w*4,v=[],i,k,g=0,h=1,o=c,b,s,e;
for(i=0;i<w;i++){if(i%32===0)v.push([]);v[v.length-1].push(toolbox(8,c+i*4,0,0));}
for(k=0;k<p.length;k+=3){s=p[k];e=p[k+1]+p[k+2];for(i=p[k+1];i<e;i++){b=strByte(s,i);if(m===1&&b>=97&&b<=122)b-=32;else if(m===2&&b>=65&&b<=90)b+=32;g+=b*h;h*=256;if(h===4294967296){toolbox(9,o,g,0);o+=4;g=0;h=1;}}}
if(h>1)toolbox(9,o,g,0);s=stringFromBytes(c,n,1);for(i=0;i<w;i++)toolbox(9,c+i*4,v[Math.floor(i/32)][i%32],0);if(typeof s!=="string")runtimeFault(3);return s;}
function _jmr_sop_part(s,a,n){if(a===0&&n===s.length)return s;return _jmr_sop_build([s,a,n],n,0);}
// Append the text of x to parts p; returns its length. u: undefined/null give "".
function _jmr_sop_add(p,s,a,n){p.push(s);p.push(a);p.push(n);return n;}
function _jmr_sop_put(p,x,u){var t=typeof x,d=[],n=0,i;if(t==="string")return _jmr_sop_add(p,x,0,x.length);
if(x===undefined||x===null){if(u)return 0;return _jmr_sop_add(p,x===null?"null":"undefined",0,x===null?4:9);}
if(t==="boolean")return x?_jmr_sop_add(p,"true",0,4):_jmr_sop_add(p,"false",0,5);
if(t==="number"){if(x!==x)return _jmr_sop_add(p,"NaN",0,3);if(x===0)return _jmr_sop_add(p,"0",0,1);if(x===Infinity)return _jmr_sop_add(p,"Infinity",0,8);if(x===-Infinity)return _jmr_sop_add(p,"-Infinity",0,9);
if((x<0?-x:x)<9007199254740992&&Math.floor(x)===x){if(x<0){n=_jmr_sop_add(p,"-",0,1);x=-x;}while(x>0){i=x%10;d.push(i);x=(x-i)/10;}for(i=d.length-1;i>=0;i--)_jmr_sop_add(p,"0123456789",d[i],1);return n+d.length;}}
x=_jmr_json_stringCoerceNative(x);return _jmr_sop_add(p,x,0,x.length);}
function _jmr_sop_text(x){if(typeof x==="string")return x;var p=[],n=_jmr_sop_put(p,x,0);return p.length===3?_jmr_sop_part(p[0],p[1],p[2]):_jmr_sop_build(p,n,0);}
function _jmr_sop_int(x){if(typeof x!=="number")x=_jmr_sop_Number(x);if(x!==x)return 0;return x<0?-Math.floor(-x):Math.floor(x);}
function _jmr_sop_clamp(x,d,n){if(x===undefined)return d;x=_jmr_sop_int(x);if(x<0)return 0;return x>n?n:x;}
function _jmr_sop_at(s,i,t){var m=t.length,j=0;if(i<0||i+m>s.length)return false;while(j<m&&strByte(s,i+j)===strByte(t,j))j++;return j===m;}
function _jmr_sop_find(s,t,i){var n=s.length-t.length;for(;i<=n;i++)if(_jmr_sop_at(s,i,t))return i;return -1;}
function _jmr_sop_space(b){return b===32||(b>=9&&b<=13);}
function _jmr_sop_indexOf(s,t,f){if(typeof s!=="string")return f===undefined?s.indexOf(t):s.indexOf(t,f);t=_jmr_sop_text(t);return _jmr_sop_find(s,t,_jmr_sop_clamp(f,0,s.length));}
function _jmr_sop_includes(s,t,f){if(typeof s!=="string")return f===undefined?!(s.indexOf(t)<0):s.includes(t,f);return _jmr_sop_indexOf(s,t,f)>=0;}
function _jmr_sop_lastIndexOf(s,t,f){if(typeof s!=="string")return f===undefined?s.lastIndexOf(t):s.lastIndexOf(t,f);t=_jmr_sop_text(t);var i=s.length-t.length;
if(f!==undefined&&(typeof f!=="number"||f===f)){f=_jmr_sop_clamp(f,0,s.length);if(f<i)i=f;}for(;i>=0;i--)if(_jmr_sop_at(s,i,t))return i;return -1;}
function _jmr_sop_slice(s,a,b){if(typeof s!=="string")return a===undefined?s.slice():(b===undefined?s.slice(a):s.slice(a,b));var n=s.length;
a=a===undefined?0:_jmr_sop_int(a);b=b===undefined?n:_jmr_sop_int(b);if(a<0)a=a+n<0?0:a+n;else if(a>n)a=n;if(b<0)b=b+n<0?0:b+n;else if(b>n)b=n;return b>a?_jmr_sop_part(s,a,b-a):"";}
function _jmr_sop_substring(s,a,b){if(typeof s!=="string")return b===undefined?s.substring(a):s.substring(a,b);var n=s.length,t;a=_jmr_sop_clamp(a,0,n);b=_jmr_sop_clamp(b,n,n);if(a>b){t=a;a=b;b=t;}return b>a?_jmr_sop_part(s,a,b-a):"";}
function _jmr_sop_substr(s,a,l){if(typeof s!=="string")return l===undefined?s.substr(a):s.substr(a,l);var n=s.length;a=a===undefined?0:_jmr_sop_int(a);if(a<0)a=a+n<0?0:a+n;else if(a>n)a=n;
l=_jmr_sop_clamp(l,n-a,n-a);return l>0?_jmr_sop_part(s,a,l):"";}
function _jmr_sop_trim(s){if(typeof s!=="string")return s.trim();var a=0,b=s.length;while(a<b&&_jmr_sop_space(strByte(s,a)))a++;while(b>a&&_jmr_sop_space(strByte(s,b-1)))b--;return _jmr_sop_part(s,a,b-a);}
function _jmr_sop_replace(s,p,q){if(typeof s!=="string"||typeof p!=="string"||typeof q==="function")return q===undefined?s.replace(p):s.replace(p,q);q=_jmr_sop_text(q);var i=_jmr_sop_find(s,p,0),n=s.length,m=p.length;
if(i<0)return s;return _jmr_sop_build([s,0,i,q,0,q.length,s,i+m,n-i-m],n-m+q.length,0);}
function _jmr_sop_join(a,sep){if(!Array.isArray(a))return sep===undefined?a.join():a.join(sep);sep=sep===undefined?",":_jmr_sop_text(sep);var p=[],n=0,i;
for(i=0;i<a.length;i++){if(i>0)n+=_jmr_sop_add(p,sep,0,sep.length);n+=_jmr_sop_put(p,a[i],1);}return _jmr_sop_build(p,n,0);}
function _jmr_sop_charAt(s,i){if(typeof s!=="string")return s.charAt(i);i=i===undefined?0:_jmr_sop_int(i);return i<0||i>=s.length?"":_jmr_sop_part(s,i,1);}
function _jmr_sop_charCodeAt(s,i){if(typeof s!=="string")return s.charCodeAt(i);i=i===undefined?0:_jmr_sop_int(i);return i<0||i>=s.length?NaN:strByte(s,i);}
function _jmr_sop_startsWith(s,t,f){if(typeof s!=="string")return f===undefined?s.startsWith(t):s.startsWith(t,f);return _jmr_sop_at(s,_jmr_sop_clamp(f,0,s.length),_jmr_sop_text(t));}
function _jmr_sop_endsWith(s,t,f){if(typeof s!=="string")return f===undefined?s.endsWith(t):s.endsWith(t,f);t=_jmr_sop_text(t);return _jmr_sop_at(s,_jmr_sop_clamp(f,s.length,s.length)-t.length,t);}
function _jmr_sop_case(s,m){var n=s.length,i,b;for(i=0;i<n;i++){b=strByte(s,i);if((m===1&&b>=97&&b<=122)||(m===2&&b>=65&&b<=90))return _jmr_sop_build([s,0,n],n,m);}return s;}
function _jmr_sop_toUpperCase(s){if(typeof s!=="string")return s.toUpperCase();return _jmr_sop_case(s,1);}
function _jmr_sop_toLowerCase(s){if(typeof s!=="string")return s.toLowerCase();return _jmr_sop_case(s,2);}
function _jmr_sop_split(s,t,l){if(typeof s!=="string")return l===undefined?s.split(t):s.split(t,l);var r=[],n=s.length,a=0,i,m;l=l===undefined?4294967295:_jmr_sop_int(l);if(l<=0)return r;
if(t===undefined){r.push(s);return r;}t=_jmr_sop_text(t);m=t.length;if(m===0){for(i=0;i<n&&r.length<l;i++)r.push(_jmr_sop_part(s,i,1));return r;}
while(r.length<l){i=_jmr_sop_find(s,t,a);if(i<0){r.push(_jmr_sop_part(s,a,n-a));break;}r.push(i>a?_jmr_sop_part(s,a,i-a):"");a=i+m;}return r;}
function _jmr_sop_localeCompare(s,t){if(typeof s!=="string")return s.localeCompare(t);t=_jmr_sop_text(t);var i=0,a,b;while(1){a=strByte(s,i);b=strByte(t,i);if(a!==b)return a<b?-1:1;if(a<0)return 0;i++;}}
// Numbers from text. Exact to 15 significant digits; 10^k scaling past +-22.
function _jmr_sop_digit(b,r){var d=b>=48&&b<=57?b-48:(b>=97&&b<=122?b-87:(b>=65&&b<=90?b-55:99));return d<r?d:-1;}
function _jmr_sop_skip(s,i){while(_jmr_sop_space(strByte(s,i)))i++;return i;}
function _jmr_sop_radix(s,i,j,r,o){var v=0,d,k=i;for(;k<j;k++){d=_jmr_sop_digit(strByte(s,k),r);if(d<0)break;v=v*r+d;}o[0]=k;return k>i?v:NaN;}
function _jmr_sop_dec(s,i,o){var m=0,e=0,x=0,es=1,dot=0,dg=0,b,p,k;while(1){b=strByte(s,i);if(b>=48&&b<=57){dg=1;if(m<900719925474099){m=m*10+b-48;if(dot)e--;}else if(!dot)e++;}else if(b===46&&!dot)dot=1;else break;i++;}
if(!dg){o[0]=-1;return NaN;}b=strByte(s,i);if(b===101||b===69){k=i+1;b=strByte(s,k);if(b===43||b===45){es=b===45?-1:1;k++;}if(_jmr_sop_digit(strByte(s,k),10)>=0){while(_jmr_sop_digit(strByte(s,k),10)>=0){if(x<100000)x=x*10+strByte(s,k)-48;k++;}i=k;}}
o[0]=i;e=e+es*x;if(m===0)return 0;while(e>22&&m!==Infinity){m=m*1e22;e-=22;}while(e<-22&&m!==0){m=m/1e22;e+=22;}p=1;for(k=e<0?-e:e;k>0;k--)p=p*10;return e<0?m/p:m*p;}
// Sign, Infinity and decimal at i; o[0] gets the end (-1: no number).
function _jmr_sop_num(s,i,o){var b=strByte(s,i),g=1;if(b===43||b===45){g=b===45?-1:1;i++;}if(_jmr_sop_at(s,i,"Infinity")){o[0]=i+8;return g*Infinity;}var v=_jmr_sop_dec(s,i,o);return g<0?-v:v;}
function _jmr_sop_parseFloat(s){if(typeof s==="number")return s;s=_jmr_sop_text(s);var o=[0];return _jmr_sop_num(s,_jmr_sop_skip(s,0),o);}
function _jmr_sop_parseInt(s,r){var i,g=1,b,v;if(typeof s==="number"&&(r===undefined||r===10)&&s===s&&(s===0||((s<0?-s:s)>=1e-6&&(s<0?-s:s)<1e21)))return _jmr_sop_int(s);
s=_jmr_sop_text(s);r=r===undefined?0:_jmr_sop_int(r);i=_jmr_sop_skip(s,0);b=strByte(s,i);if(b===43||b===45){g=b===45?-1:1;i++;}
if((r===0||r===16)&&strByte(s,i)===48&&(strByte(s,i+1)|32)===120){i+=2;r=16;}if(r===0)r=10;if(r<2||r>36)return NaN;return g*_jmr_sop_radix(s,i,s.length,r,[0]);}
function _jmr_sop_Number(x){var t=typeof x,i,j,n,b,o,v;if(t==="number")return x;if(t==="boolean")return x?1:0;if(x===null)return 0;if(t!=="string")return NaN;
n=x.length;while(n>0&&_jmr_sop_space(strByte(x,n-1)))n--;i=_jmr_sop_skip(x,0);if(i>=n)return 0;b=strByte(x,i+1)|32;
if(strByte(x,i)===48&&(b===120||b===98||b===111)){o=[0];v=_jmr_sop_radix(x,i+2,n,b===120?16:(b===98?2:8),o);return o[0]===n?v:NaN;}o=[0];v=_jmr_sop_num(x,i,o);return o[0]===n?v:NaN;}
function _jmr_sop_trunc(x){if(typeof x!=="number")x=_jmr_sop_Number(x);return x<0?-Math.floor(-x):Math.floor(x);}
function _jmr_sop_sign(x){if(typeof x!=="number")x=_jmr_sop_Number(x);return x>0?1:(x<0?-1:x);}
function _jmr_sop_isInteger(x){return typeof x==="number"&&isFinite(x)&&Math.floor(x)===x;}
