#!/usr/bin/env python3
"""Bind successful timing/DRC gates to the exact bit and frozen source inputs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'build/a200t_d2a1'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--recipe',type=Path,required=True);a=p.parse_args()
    spec=importlib.util.spec_from_file_location('checks',Path(__file__).parent/'test.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    frozen=json.loads((WORK/'hardware_inputs.json').read_text())
    assert frozen==m.hardware_inputs(),'Sources/constraints changed after build snapshot'
    log=a.log.read_text();match=re.search(r'A200T_TIMING WNS=([-\d.]+) WHS=([-\d.]+)',log)
    assert 'A200T_BUILD_PASS' in log and match and float(match[1])>=0 and float(match[2])>=0,'Build gates did not pass'
    bit=WORK/'application/jmr_js_a200t_d2a1.bit';dcp=WORK/'application/routed.dcp'
    assert bit.is_file() and bit.stat().st_mtime>=dcp.stat().st_mtime,'No new bit for this routed design'
    reload_log=WORK/'constraint_reload.log';reload_recipe=Path(__file__).parent/'verify_routed.tcl'
    assert reload_log.is_file() and reload_log.stat().st_mtime>=bit.stat().st_mtime and 'A200T_RELOAD_PASS' in reload_log.read_text(),'Fresh constraint reload is pending'
    reports={}
    for name in ['timing.rpt','drc.rpt','route.rpt','clocks.rpt','cdc.rpt','exceptions.rpt','utilization.rpt','paths.rpt']:
        path=dcp.parent/name
        assert path.is_file() and path.stat().st_mtime>=dcp.stat().st_mtime,'Missing fresh report: '+name
        reports[name]=sha(path)
    for name in ['peripheral_paths.rpt','memory_mailbox_paths.rpt','constraint_reload_timing.rpt','constraint_reload_ports.rpt']:
        path=dcp.parent/name
        if path.is_file() and path.stat().st_mtime>=dcp.stat().st_mtime:reports[name]=sha(path)
    data={'status':'TIMING_QUALIFIED_PENDING_BOARD_TEST','hardware_inputs':frozen,
          'bit_sha256':sha(bit),'routed_checkpoint_sha256':sha(dcp),
          'reports_sha256':reports,
          'setup_wns_ns':float(match[1]),'hold_whs_ns':float(match[2]),
          'qualification_log':str(a.log.resolve()),'qualification_log_sha256':sha(a.log),
          'implementation_recipe':str(a.recipe.resolve()),'implementation_recipe_sha256':sha(a.recipe),
          'constraint_reload_log':str(reload_log.resolve()),'constraint_reload_log_sha256':sha(reload_log),
          'constraint_reload_recipe':str(reload_recipe.resolve()),'constraint_reload_recipe_sha256':sha(reload_recipe),
          'physical_board_test':'PENDING'}
    (WORK/'QUALIFIED_BUILD.json').write_text(json.dumps(data,indent=2)+'\n')
    print('QUALIFICATION_RECORDED',bit)

if __name__=='__main__':main()
