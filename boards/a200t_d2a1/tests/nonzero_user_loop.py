#!/usr/bin/env python3
"""Exercise the shared computer after nonzero external-memory initialization."""
from pathlib import Path
import runpy
import sys

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT))
from runtime.sim_backend import SimBackend

original=SimBackend._rpc
filled=False


def rpc(self,command,*args,**kwargs):
    global filled
    if not filled:
        filled=True
        reply=original(self,'SRAMFILL 0 4194304 42330')
        if reply!='OK':raise RuntimeError(reply)
        print('NONZERO_SRAM_INITIALIZED lower 8 MiB = A55A',flush=True)
    return original(self,command,*args,**kwargs)


SimBackend._rpc=rpc
runpy.run_path(str(ROOT/'sim/user_loop.py'),run_name='__main__')
