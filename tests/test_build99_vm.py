"""Build 99 VM changes: same answers as the Python model.

* Fewer clocks per instruction (rtl/engines/jmr_js_vm_exec64.sv beat 1, the
  fetch-beat operand read in jmr_js_vm.sv, the shorter float add): a program
  that runs every shortened op in many orders gives the model's globals.
* Math.sqrt is the IEEE root (S_SQRT), not a ~20-bit fixed-point one.
* `b=[]; b[50]=9` gives length 51 (S_ARR_PROMOTE held a stale stack head).
"""
import math
import os
import random
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import ProgramImage  # noqa: E402
from hardware_model.js_vm import JsHwVm  # noqa: E402


def _lit(x):
    return repr(x) if x == x and abs(x) != math.inf else "0"


_rng = random.Random(99)
SQRT_IN = [2.0, 3.0, 0.5, 0.1, 16.0, 1e10, 1e300, 1e-300, 1e-310, 123456.789,
           7.0e-5, 2.0 ** 52 + 1, 0.0] + [_rng.uniform(0, 1e6) for _ in range(12)] + \
    [_rng.uniform(0, 1) for _ in range(8)]

PROGRAMS = {
    "sqrt": "".join(f"var q{i}=Math.sqrt({_lit(x)});" for i, x in enumerate(SQRT_IN)) +
    "var qn=Math.sqrt(-0),qi=Math.sqrt(1/0),qm=Math.sqrt(-4);",
    "array_grow": """var b=[]; b[50]=9; var L=b.length, x=b[50], y=b[49];
var c=[1,2]; c[40]=5; var L2=c.length, z=c[1], w=c[40];
var d=[]; d[10]=3; var L3=d.length;
var e=[]; var i=0; while(i<40){e[i*3]=i;i=i+1;} var L4=e.length, e9=e[117], e1=e[1];""",
    "ops": """var s=0,i=0,k=3,t=0,u=1,f=0.5,g=-2.25,h=0,m=0,n=0,p=0,r=0,flag=true,cnt=0;
var str="ab", nul=null, und;
while(i<300){
  s=s+i*k-1; t=t-i+0.25; f=f+g; g=-g*0.5+i; h=(i|5)&(k|2);
  if(i<k){cnt=cnt+1;} if(i>200){m=m+2;} if(i==150){n=7;}
  p=-p+1; flag=!flag; if(flag){r=r+1;} else {r=r-1;}
  k=s%7; u=u+u; if(u>1000000){u=1;}
  i=i+1;
}
var a1=s,a2=t,a3=f,a4=g,a5=h,a6=cnt,a7=m,a8=n,a9=p,a10=r,a11=k,a12=u;
var c1=str+"x", c2=(nul==null), c3=(und==und);
var j=0,acc=0; for(j=0;j<50;j++){acc=acc+j; if(acc>100){acc=acc-99;}}
var sub1=5-7, sub2=0.1-0.3, add1=1e16+1, add2=-0+0, add3=0.1+0.2;""",
    # Locals at their slot hint, captured outer locals, shadowing, recursion,
    # methods with `this`, and a local read right after a call returns.
    "locals": """function f(a,b){var c=a*2; var d=b+c; var e=0; var i=0;
  while(i<20){e=e+d-a+i; i=i+1;} return e+c;}
function mk(n){var base=n*10; var cnt=0;
  return function(x){var y=x+base; cnt=cnt+1; return y*cnt;};}
function fib(n){if(n<2){return n;} var p=fib(n-1); var q=fib(n-2); return p+q;}
function sh(x){var x2=x; {let x=5; x2=x2+x;} return x2+x;}
class P{constructor(x,y){this.x=x;this.y=y;} len(){var s=this.x*this.x+this.y*this.y; return s;}}
var r1=f(3,4), r2=f(1.5,-2), r3=0, k=0;
while(k<10){r3=r3+f(k,k+1);k=k+1;}
var g=mk(3), g1=g(1), g2=g(2), g3=g(5);
var fb=fib(12), s1=sh(2), pl=new P(3,4), pv=pl.len();
function after(){var a=7; var b=f(1,1); var c=a+b; return c;}
var af=after();
function lp(n){var t=0; for(let i=0;i<n;i++){let s=i*2; var u=s+1; t=t+s+u;} return t;}
function cl(){var v=1; function inc(){v=v+1; return v;} inc(); inc(); var w=inc(); return v*100+w;}
var lp1=lp(10), lp2=lp(3), cl1=cl();""",
}


def _image(src):
    return ProgramImage(bytes(ProgramImage.from_chunk(compile_source(src), v2=True, value64=True)))


def _model(image):
    vm = JsHwVm()
    vm.load_image(image)
    assert vm.error is None, vm.error
    return {name: vm._value_vars[k] for k, name in enumerate(image.var_names)
            if not name.startswith("$")}


def test_model_sqrt_is_exact():
    got = _model(_image(PROGRAMS["sqrt"]))
    for i, x in enumerate(SQRT_IN):
        want = struct.unpack("<Q", struct.pack("<d", math.sqrt(x)))[0]
        assert got[f"q{i}"] == want, (x, hex(got[f"q{i}"]), hex(want))


def test_fpga_sim_matches_model(tmp_path):
    from runtime.sim_backend import SimBackend
    os.environ.pop("JMR_SIM_HOST", None)
    sim = SimBackend()
    try:
        for name, src in PROGRAMS.items():
            image = _image(src)
            want = _model(image)
            jsh = tmp_path / f"{name}.jsh"
            jsh.write_bytes(bytes(image))
            assert sim._rpc("JSHLOAD " + str(jsh)).startswith("OK")
            for _ in range(6):
                sim._rpc("FRAME 4000000")
            for var, value in want.items():
                reply = sim._rpc("VVARPEEK " + str(image.var_names.index(var)))
                # A name that is only a property (valid=0) reads 0 in both.
                got = 0 if "valid=0" in reply else int(reply.rsplit("v=0x", 1)[1], 16)
                if value == 0 and got >> 44 == 0x7FF97:
                    continue  # the RTL also keeps local function bindings in
                    #          the global table (rAF by name); the model does not
                assert got == value, (name, var, reply, hex(value))
    finally:
        sim.shutdown()
