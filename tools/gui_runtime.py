"""Select the published root source and its single writable card.img."""
from pathlib import Path
import hashlib
import json
import os


def configure(root):
    root = Path(root).resolve()
    target = root / 'card.img'
    requested = os.environ.get('JMR_CARD_IMG')
    if requested and Path(requested).resolve() != target:
        raise RuntimeError('The GUI uses the project card.img; unset JMR_CARD_IMG to use it.')
    if not target.is_file():
        raise RuntimeError('Project card.img is missing. Restore it from GitHub with the matching source.')
    manifest = json.loads((root / 'CURRENT_SET.json').read_text())
    from tools.make_sd_image import open_volume
    from functional_model.toolbox_rom import unpack_rom
    from functional_model.jsb_format import ProgramImage, FLAG_TOOLBOX
    from tools.toolbox_linker import prefix_bytes
    volume = open_volume(target)
    for name in ('TOOLBOX.ROM', 'TOOLBOX.LNK', 'SYSTEM.SYS'):
        actual = hashlib.sha256(volume.read_file(name)).hexdigest()
        if actual != manifest['files']['storage/' + name]:
            raise RuntimeError('card.img has a different ' + name + '; update source and disk together. Existing disk preserved.')
    payload = unpack_rom(volume.read_file('TOOLBOX.ROM'))
    for name, _ in volume.list_root_info():
        if name.upper().endswith('.JSH'):
            image = ProgramImage(volume.read_file(name))
            if image.flags & FLAG_TOOLBOX and prefix_bytes(image) != payload:
                raise RuntimeError(name + ' does not match the Toolbox in card.img. Existing disk preserved.')
    os.environ['JMR_CARD_IMG'] = str(target)
    os.environ['JMR_FINDER'] = 'program'
    import runtime.backend as backend
    import runtime.sim_backend as sim
    backend.CARD_IMG = target
    return {'source': root, 'disk': target, 'simulator': sim._SYNTH}
