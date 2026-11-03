#!/usr/bin/env python3
"""Build a separate Python menu preview disk, preserving the normal card."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
TITLES=tuple(path.stem for path in sorted((ROOT/'storage').glob('*.HTML'))
             if '.systemWindow' in path.read_text())

def publish():
    """Install only the requested apps/manuals into the normal disk, with rollback."""
    from datetime import datetime
    from tools.compile_js import compile_html_text,encode_html_chunk
    from tools.make_sd_image import open_volume,sanitize_bas_files
    folder=ROOT/'build/system_tools';folder.mkdir(parents=True,exist_ok=True)
    card=ROOT/'card.img';before=card.read_bytes()
    backup=folder/'card_before_shared_menus.img'
    if backup.exists() and backup.read_bytes()!=before:
        backup=folder/('card_before_shared_menus_'+datetime.now().strftime('%Y%m%d_%H%M%S')+'.img')
    if not backup.exists():backup.write_bytes(before)
    files={}
    for stem in TITLES:
        source=ROOT/'storage'/(stem+'.HTML')
        files[stem+'.JSH']=encode_html_chunk(compile_html_text(source.read_text(),source_path=source))
        clean,_=sanitize_bas_files([(stem+'.HTM',source.read_bytes())],squash=True)
        files.update(clean)
    files['HELP.MD']=(ROOT/'storage/HELP.MD').read_bytes()
    files['MENUS.MD']=(ROOT/'docs/SYSTEM_APPLICATIONS.md').read_bytes()
    volume=open_volume(card)
    # Read-only artifact verification can read sector bytes directly. Actual
    # publication writes and all runtime tests use the normal FAT/SPI engines.
    def hashes(v):
        read=v.card.read_block
        v.card.read_block=lambda lba:bytes(v.card.image[lba*512:(lba+1)*512])
        try:return {name:hashlib.sha256(v.read_file(name)).hexdigest() for name,size in v.list_root_info()}
        finally:v.card.read_block=read
    old=hashes(volume)
    for name,data in files.items():volume.write_file(name,data)
    new=hashes(volume)
    untouched={name:digest for name,digest in old.items() if name not in files}
    assert all(new.get(name)==digest for name,digest in untouched.items()),'Unrelated disk file changed'
    assert all(new[name]==hashlib.sha256(data).hexdigest() for name,data in files.items())
    assert card.read_bytes()==before,'Normal disk changed during preparation; refusing to replace it'
    temp=card.with_suffix('.img.tmp');temp.write_bytes(bytes(volume.card.image));temp.replace(card)
    record={'card':str(card),'backup':str(backup),'before_sha256':hashlib.sha256(before).hexdigest(),
            'after_sha256':hashlib.sha256(card.read_bytes()).hexdigest(),
            'updated':{name:new[name] for name in files},'unchanged_files_verified':len(untouched),
            'scope':'Python only; released bitstream unchanged'}
    report=folder/'main_disk_update.json'
    if report.exists():
        history=folder/('main_disk_update_before_'+datetime.now().strftime('%Y%m%d_%H%M%S')+'.json')
        shutil.copyfile(report,history)
    report.write_text(json.dumps(record,indent=2)+'\n')
    print('Updated normal card.img; preserved '+str(len(untouched))+' other files. Backup: '+str(backup))
    return card

def build(reset=False):
    from tools.compile_js import compile_html_text,encode_html_chunk
    from tools.make_sd_image import open_volume,sanitize_bas_files
    folder=ROOT/'build/system_tools';folder.mkdir(parents=True,exist_ok=True)
    card=folder/'python_card.img';stamp=folder/'python_card_sources.json'
    if reset or not card.exists():
        shutil.copyfile(ROOT/'card.img',card)
        if stamp.exists():stamp.unlink()
    previous=json.loads(stamp.read_text()) if stamp.exists() else {}
    volume=None
    for stem in TITLES:
        source=ROOT/'storage'/(stem+'.HTML')
        if not source.exists():continue
        dependencies=[source]+[p for ext in ('.ARTX','.ARTJS') if (p:=source.with_suffix(ext)).exists()]
        digest=hashlib.sha256(b''.join(p.read_bytes() for p in dependencies)).hexdigest()
        if previous.get(stem)==digest:continue
        blob=encode_html_chunk(compile_html_text(source.read_text(),source_path=source))
        if volume is None:volume=open_volume(card)
        volume.write_file(stem+'.JSH',blob)
        files,_=sanitize_bas_files([(stem+'.HTM',source.read_bytes())],squash=True)
        volume.write_file(stem+'.HTM',files[0][1])
        previous[stem]=digest
        print('Updated '+stem+' in the Python preview disk.',flush=True)
    for name,source in (('HELP.MD',ROOT/'storage/HELP.MD'),('MENUS.MD',ROOT/'docs/SYSTEM_APPLICATIONS.md')):
        digest=hashlib.sha256(source.read_bytes()).hexdigest()
        if previous.get(name)!=digest:
            if volume is None:volume=open_volume(card)
            volume.write_file(name,source.read_bytes());previous[name]=digest
    if volume is not None:
        temp=card.with_suffix('.img.tmp');temp.write_bytes(bytes(volume.card.image));temp.replace(card)
    stamp.write_text(json.dumps(previous,indent=2)+'\n')
    return card

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build-only',action='store_true')
    ap.add_argument('--publish',action='store_true',help='Install into the normal card.img, with a rollback copy.')
    ap.add_argument('--reset',action='store_true',help='Recreate preview disk from current card; replaces preview saves.')
    args=ap.parse_args();card=publish() if args.publish else build(args.reset)
    if args.build_only or args.publish:print(card)
    else:
        os.environ['JMR_CARD_IMG']=str(card);os.environ['JMR_PYTHON_ONLY']='1'
        os.chdir(ROOT)
        os.execv(sys.executable,[sys.executable,str(ROOT/'gui_jmr_js.py')])
