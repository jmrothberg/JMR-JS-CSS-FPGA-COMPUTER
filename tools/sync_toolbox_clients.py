"""Keep shared Toolbox client modules identical in ordinary, on-device HTML.

These are real inline scripts: both the host compiler and standalone compiler
read them. No host-only include or hidden preprocessor is required at runtime.
"""
from pathlib import Path
import argparse
ROOT=Path(__file__).resolve().parents[1]
CLIENTS={
 'draw':['EDITOR','READ','UTILITY','FINDER'],
 'filename':['EDITOR','MACPAINT','UISESS'],
 'editor':['EDITOR'],
 'chrome':['EDITOR','READ','UTILITY','UISESS'],
 'window':['FINDER','UISESS'],
 'raster':['GRAPHICS','TBDEMO'],
 'scroll':['FINDER','EDITOR','READ','UISESS','TBDEMO'],
}

def sync(write=False):
    errors=[]
    for module,clients in CLIENTS.items():
        name=module+'_client.js';body=(ROOT/'resources/toolbox'/name).read_text()
        begin='// BEGIN shared '+name+'\n';end='// END shared '+name
        for client in clients:
            p=ROOT/'storage'/(client+'.HTML');s=p.read_text()
            if s.count(begin)!=1 or s.count(end)!=1:raise ValueError(f'{p}: missing/duplicate module {name}')
            a=s.index(begin)+len(begin);b=s.index(end,a)
            if s[a:b]!=body:
                errors.append(f'{client}: {name}')
                if write:p.write_text(s[:a]+body+s[b:])
    return errors

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--write',action='store_true');args=ap.parse_args()
    errors=sync(args.write)
    if errors and not args.write:raise SystemExit('Outdated inline modules: '+', '.join(errors))
    print('Shared inline Toolbox modules match'+(' (updated '+str(len(errors))+')'if args.write else ''))
