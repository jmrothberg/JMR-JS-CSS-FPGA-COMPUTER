"""Select one matched GUI model, RTL simulator and writable disk.

This adapter deliberately lives outside the frozen FPGA source tree.
"""
from pathlib import Path
import hashlib,json,os,runpy,shutil,sys

def configure(root, work=None):
    root=Path(root).resolve()
    cfg=json.loads((root/'runtime/active_gui.json').read_text())
    base=root/cfg['candidate']; source=base/'source'
    manifest=json.loads((base/'software_work/final_software_manifest.json').read_text())
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    for group in ('generated','runtime_sources','shipping_sources'):
        for name,digest in manifest[group].items():
            if sha(source/name)!=digest:raise RuntimeError('GUI source version mismatch: '+name)
    for name,digest in cfg['python_files'].items():
        if sha(source/name)!=digest:raise RuntimeError('GUI Python model version mismatch: '+name)
    disk=base/'card.img'
    if sha(disk)!=manifest['disk_sha256']:raise RuntimeError('GUI disk version mismatch')
    work=Path(work).resolve() if work else base/'gui_working'
    work.mkdir(parents=True,exist_ok=True)
    default_disk=(root/cfg['working_disk']) if cfg.get('working_disk') and work==base/'gui_working' else work/'card.img'
    target=Path(os.environ.get('JMR_CARD_IMG') or default_disk).resolve()
    if not target.exists():
        if 'JMR_CARD_IMG' in os.environ:raise RuntimeError('Requested GUI disk does not exist')
        shutil.copyfile(disk,target)
    # Keep user saves; never replace an existing working disk automatically.
    sys.path.insert(0,str(source))
    from tools.make_sd_image import open_volume
    volume=open_volume(target)
    for name in ('TOOLBOX.ROM','TOOLBOX.LNK','SYSTEM.SYS'):
        if hashlib.sha256(volume.read_file(name)).hexdigest()!=manifest['generated']['storage/'+name]:
            raise RuntimeError('Working GUI disk needs the matching '+name+'; existing disk preserved')
    os.environ['JMR_CARD_IMG']=str(target)
    os.environ['JMR_FINDER']='program'
    os.environ.pop('JMR_SIM_HOST',None)
    import functional_model.trace as trace
    trace.TRACES_DIR=work/'traces'
    import runtime.backend as backend
    import runtime.sim_backend as sim
    backend.CARD_IMG=target
    simdir=base/cfg.get('simulator_directory','simulator_completion')
    sim.SIM_DIR=simdir/'work'
    sim._SYNTH=simdir/'jmr_js_sim_server'
    built=json.loads((simdir/'build_result.json').read_text())
    if sha(sim._SYNTH)!=built['sha256']:raise RuntimeError('GUI RTL simulator version mismatch')
    return {'source':source,'disk':target,'simulator':sim._SYNTH,'candidate':cfg['candidate']}

def launch(root):
    selected=configure(root)
    runpy.run_path(str(selected['source']/'gui_jmr_js.py'),run_name='__main__')
