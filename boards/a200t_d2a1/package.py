#!/usr/bin/env python3
"""Publish one complete board-test package only after implementation qualifies."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
BOARD = Path(__file__).resolve().parent
WORK = ROOT / 'build/a200t_d2a1'
APP = WORK / 'application'
OUT = ROOT / 'A200T_D2A1_BRINGUP'


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    spec = importlib.util.spec_from_file_location('checks',BOARD/'test.py')
    checks = importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
    before=json.loads((WORK/'hardware_inputs.json').read_text())
    if before!=checks.hardware_inputs(): raise SystemExit('Hardware sources changed after build; package refused')
    if not (WORK/'CHECKS.json').is_file():
        raise SystemExit('Interface checks are pending; no ready package published')
    tested=json.loads((WORK/'CHECKS.json').read_text())
    tested_rtl=tested.get('interface_inputs', {k:v for k,v in tested['hardware_inputs'].items() if k in checks.interface_inputs()})
    if tested['status']!='PASS' or tested_rtl!=checks.interface_inputs():
        raise SystemExit('Board tests do not match build inputs')
    nonzero=(WORK/'nonzero_user_loop.log').read_text()
    if 'NONZERO_SRAM_INITIALIZED' not in nonzero or 'USER_LOOP_PASS' not in nonzero:
        raise SystemExit('Nonzero-memory user loop is pending; no ready package published')
    if not (WORK/'QUALIFIED_BUILD.json').is_file():
        raise SystemExit('Build not qualified; no ready package published')
    qualified=json.loads((WORK/'QUALIFIED_BUILD.json').read_text())
    if qualified['status']!='TIMING_QUALIFIED_PENDING_BOARD_TEST' or qualified['hardware_inputs']!=before or qualified['bit_sha256']!=sha(APP/'jmr_js_a200t_d2a1.bit'):
        raise SystemExit('Qualified bit does not match this source snapshot')
    for key in ['qualification_log','implementation_recipe','constraint_reload_log','constraint_reload_recipe']:
        if sha(Path(qualified[key]))!=qualified[key+'_sha256']:
            raise SystemExit('Qualification evidence changed: '+key)
    for name,digest in qualified['reports_sha256'].items():
        if sha(APP/name)!=digest:raise SystemExit('Qualified report changed: '+name)
    original=json.loads((WORK/'build_inputs.json').read_text())
    for name in ['CURRENT_SET.json','card.img']:
        if original['files'][name]!=sha(ROOT/name):
            raise SystemExit('Software snapshot changed after preparation: '+name)
    if sha(ROOT/'releases/current/jmr_js_mac.bit')!=original['vision_bit_sha256']:
        raise SystemExit('Vision release changed during preparation; reconcile before publishing')
    if OUT.exists(): raise SystemExit('Ready folder already exists; preserve the prior tested package')
    stage=WORK/'PACKAGE_STAGING'
    stage.mkdir(exist_ok=False)
    shutil.copy2(APP/'jmr_js_a200t_d2a1.bit',stage/'jmr_js_a200t_d2a1.bit')
    for name in ['START_HERE.md','jtag.py','Start A200T Simulator.desktop']:
        shutil.copy2(BOARD/name,stage/name)
    reports=stage/'reports';reports.mkdir()
    for name in ['timing.rpt','drc.rpt','route.rpt','clocks.rpt','cdc.rpt','exceptions.rpt','utilization.rpt','paths.rpt']:
        shutil.copy2(APP/name,reports/name)
    for name in ['hardware_inputs.json','CHECKS.json','QUALIFIED_BUILD.json','build_inputs.json','shared_user_loop.log','nonzero_user_loop.log','input_test.log','tb_hyperram.log','tb_sram.log','tb_missing_ram.log','gui_profile_check.log']:
        shutil.copy2(WORK/name,reports/name)
    shutil.copy2(WORK/'pin_audit/pins.json',reports/'pins.json')
    shutil.copy2(Path(qualified['qualification_log']),reports/'qualification.log')
    shutil.copy2(Path(qualified['implementation_recipe']),reports/'implementation.tcl')
    shutil.copy2(Path(qualified['constraint_reload_log']),reports/'constraint_reload.log')
    shutil.copy2(Path(qualified['constraint_reload_recipe']),reports/'verify_routed.tcl')
    for name in ['peripheral_paths.rpt','memory_mailbox_paths.rpt','constraint_reload_timing.rpt','constraint_reload_ports.rpt']:
        if name in qualified['reports_sha256']:shutil.copy2(APP/name,reports/name)
    if sha(stage/'jmr_js_a200t_d2a1.bit')!=qualified['bit_sha256']:
        raise SystemExit('Bitstream changed while copying; ready folder withheld')
    if before!=checks.hardware_inputs() or any(sha(ROOT/name)!=original['files'][name] for name in ['CURRENT_SET.json','card.img']):
        raise SystemExit('Sources changed while packaging; ready folder withheld')
    checksums={str(p.relative_to(stage)):sha(p) for p in sorted(stage.rglob('*')) if p.is_file()}
    manifest={'status':'TIMING_QUALIFIED_PENDING_BOARD_TEST','board':'A200T D2-A1 / C3',
              'order':'Y22 / SMT026102765180','part':'xc7a200tfbg484-1','source_set':'run99-current-source',
              'rtl':'shared rtl/ plus boards/a200t_d2a1/rtl/',
              'software_image':'../card.img',
              'tested_software_image_sha256':original['files']['card.img'],
              'physical_board_test':'PENDING','sha256':checksums}
    (stage/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (stage/'SHA256SUMS').write_text(''.join(f'{digest}  {name}\n' for name,digest in checksums.items()))
    stage.rename(OUT)
    print('PACKAGE_READY',OUT)


if __name__=='__main__':main()
