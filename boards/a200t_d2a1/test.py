#!/usr/bin/env python3
"""Run the board interfaces without opening USB or changing the active release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BOARD = Path(__file__).resolve().parent
WORK = ROOT / 'build/a200t_d2a1'
MODEL = Path('/home/jonathan/Macintosh/hardware/a200t_m2_hyperram_d2a1/verification/s80ks5122_address37.v')


def interface_inputs():
    files = []
    for directory in [ROOT/'rtl', ROOT/'vectors', BOARD/'rtl']:
        files.extend(p for p in directory.rglob('*') if p.suffix in ('.sv', '.v', '.vhd', '.hex'))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}


def hardware_inputs():
    data=interface_inputs()
    for p in [*BOARD.glob('*.xdc'), BOARD/'build.tcl', ROOT/'constraints/native_argument_pipeline.xdc']:
        data[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
    return data


def run(command, log, marker=None, cwd=ROOT):
    with log.open('w') as f:
        process = subprocess.run(command, cwd=cwd, stdout=f, stderr=subprocess.STDOUT)
    text = log.read_text(errors='replace')
    if process.returncode or (marker and marker not in text) or 'Fatal:' in text or 'Timing violation' in text:
        raise SystemExit(f'FAILED: {log}\n{text[-2000:]}')
    print(marker or f'PASS {log.name}', flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--core', action='store_true', help='also rerun the full shared GUI user loop')
    parser.add_argument('--model', type=Path, default=MODEL)
    args=parser.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    before=interface_inputs()
    run([str(ROOT/'.venv/bin/python'), str(ROOT/'tools/verify_current_set.py')], WORK/'current_set_check.log', 'PASS:')
    if args.core:
        run([str(ROOT/'.venv/bin/python'), str(ROOT/'sim/user_loop.py')], WORK/'shared_user_loop.log', 'USER_LOOP_PASS')
    if 'USER_LOOP_PASS' not in (WORK/'shared_user_loop.log').read_text():
        raise SystemExit('Run with --core before the first hardware build')
    run(['verilator','--binary','--timing','-j','4','--top-module','tb_input','--Mdir',str(WORK/'input_test'),'-Wno-fatal',
         *map(str,[BOARD/'rtl/jmr_c3_reports.sv', BOARD/'rtl/jmr_c3_set2_decode.sv', BOARD/'rtl/jmr_c3_input.sv',
                   ROOT/'rtl/phys/jmr_pointer_accumulator.sv', BOARD/'tests/tb_input.sv'])], WORK/'input_compile.log')
    run([str(WORK/'input_test/Vtb_input')], WORK/'input_test.log','C3_INPUT_PASS')
    vivado=Path(os.environ.get('VIVADO','/tools/Xilinx/2026.1/Vivado/bin/vivado'))
    for top,marker in [('tb_hyperram','HYPERRAM_BUS_PASS'),('tb_sram','HYPERRAM_SRAM_PASS'),('tb_missing_ram','MISSING_RAM_PASS')]:
        run([str(vivado),'-mode','batch','-source',str(BOARD/'tests/run_hyperram.tcl'),'-tclargs',str(ROOT),str(args.model),top], WORK/f'{top}.log',marker,cwd=WORK)
    if interface_inputs()!=before:
        raise SystemExit('Hardware sources changed during tests; rerun')
    data={'status':'PASS','interface_inputs':before,'hardware_inputs':hardware_inputs(),'model':str(args.model),
          'model_sha256':hashlib.sha256(args.model.read_bytes()).hexdigest(),
          'core_gate':'USER_LOOP_PASS','physical_board_test':'PENDING',
          'test_sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [*sorted((BOARD/'tests').glob('*')),Path(__file__).resolve()] if p.is_file()},
          'bist_simulation_scope':'Reduced BIST address range; full 64 MiB range is hardware default'}
    (WORK/'CHECKS.json').write_text(json.dumps(data,indent=2)+'\n')
    print('A200T_INTERFACE_CHECKS_PASS',flush=True)


if __name__=='__main__': main()
