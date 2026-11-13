from pathlib import Path
from html import escape
import struct
import sys
from PIL import ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from functional_model.jsb_format import (  # noqa: E402
    CIMG_SRAM_BASE, CSCR_SRAM_BASE, CSTG_WORDS, FINDER_STATE_BASE,
    PROGRAM_CODE_WORDS, SRAM_BYTES, SRC_SRAM_BASE, SYSTEM_CACHE_BASE,
    TOOLBOX_WORDS, _FB_SRAM_BASE_BYTES,
)

# Counts read from the source tree, so the poster cannot drift from the card.
STORAGE = ROOT / 'storage'
EXT_PORT_ADDR_BITS = 25  # jmr_sram_port: 16-bit words; rtl/engines/jmr_sram_model.sv
EXT_PORT_MIB = (2 << EXT_PORT_ADDR_BITS) >> 20
MAP_MIB = SRAM_BYTES >> 20
_rom = (STORAGE / 'TOOLBOX.ROM').read_bytes()
_words = struct.unpack(f'<{TOOLBOX_WORDS}I', _rom[16:16 + 4 * TOOLBOX_WORDS])
TB_USABLE = TOOLBOX_WORDS - 1  # the last word is the fixed jump to the program
TB_USED = TB_USABLE
while TB_USED and _words[TB_USED - 1] == _words[-1]:  # linker pads with that jump
    TB_USED -= 1
N_PROGRAMS = len(list(STORAGE.glob('*.JSH')))
N_LINKED = sum('jmr-toolbox: resident-v2' in f.read_text(errors='replace')[:1024]
               for f in STORAGE.glob('*.HTM*'))
OUT = ROOT / 'docs/diagrams'
INK = '#172e3a'
MUTED = '#526775'
TEAL = '#086c68'
LINE = '#ced9de'
parts = []
measurements = []

def begin(width, height, title, desc):
    parts.clear()
    measurements.clear()
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-labelledby="title desc">')
    parts.append(f'<title id="title">{escape(title)}</title><desc id="desc">{escape(desc)}</desc>')
    parts.append('<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#526775"/></marker></defs>')
    rect(0, 0, width, height, '#f4f7f8', stroke='none', radius=0)

def rect(x, y, w, h, fill='white', stroke=LINE, radius=10):
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}"/>')

def text(x, y, value, size=20, color=INK, bold=False, mono=False, maxwidth=None):
    font = 'DejaVu Sans Mono' if mono else 'DejaVu Sans'
    weight = 'bold' if bold else 'normal'
    parts.append(f'<text x="{x}" y="{y}" font-family="{font},sans-serif" font-size="{size}" font-weight="{weight}" fill="{color}">{escape(value)}</text>')
    if maxwidth:
        path = f'/usr/share/fonts/truetype/dejavu/DejaVuSans{"Mono" if mono else ""}{"-Bold" if bold else ""}.ttf'
        length = ImageFont.truetype(path, size).getlength(value)
        measurements.append((value, length, maxwidth))

def lines(x, y, values, size=19, step=27, color=INK, mono=False, maxwidth=None):
    for i, value in enumerate(values):
        text(x, y+i*step, value, size, color, mono=mono, maxwidth=maxwidth)

def rule(x1, y1, x2, y2):
    parts.append(f'<path d="M{x1} {y1} H{x2}" stroke="{LINE}"/>' if y1 == y2 else f'<path d="M{x1} {y1} L{x2} {y2}" stroke="{LINE}"/>')

def arrow(x, top, bottom):
    parts.append(f'<path d="M{x} {top} V{bottom}" stroke="{MUTED}" stroke-width="2" marker-end="url(#arrow)"/>')

def save(name):
    bad = [(s, round(n, 1), w) for s, n, w in measurements if n > w]
    if bad:
        raise ValueError(bad)
    svg = '\n'.join(parts) + '\n</svg>\n'
    (OUT / name).write_text(svg)

begin(1600,2200,'JMR clean architecture: software Toolbox and bounded hardware services',
 'Finder and applications share compiled JavaScript Toolbox instructions, private application state and bounded hardware services. One matched release; see the release manifest for hardware qualification.')
text(48,54,'JMR computer architecture',36,bold=True)
text(48,88,'Macintosh-inspired organization • one native JavaScript CPU • software owns common UI policy',21,MUTED)
rect(48,110,1504,44,'#fff3db','#e3cc98',6)
text(64,138,'ONE MATCHED RELEASE · source + storage + disk + .bit · qualification recorded in the release manifest',18,'#735019',maxwidth=1472)
text(48,190,'READ TOP TO BOTTOM',15,TEAL,bold=True)
text(265,190,'Application behavior → shared software → bounded system services → FPGA mechanisms',20,MUTED)
for x in (48,816):rect(x,212,736,288)
text(72,247,'01   FINDER',23,TEAL,bold=True)
text(840,247,'01   APPLICATIONS + SYSTEM TOOLS',23,TEAL,bold=True)
text(72,277,'Ordinary compiled JavaScript program: FINDER.JSH',18,MUTED,maxwidth=688)
text(840,277,'HTML / JavaScript → JSH · same processor as Finder',18,MUTED,maxwidth=688)
for x in (72,840):rule(x,295,x+688,295)
text(72,326,'Desktop content',19,bold=True);text(400,326,'Files + persistence',19,bold=True)
lines(72,355,['Icons, selection, drag/drop','Shared Window / Control calls','Icon / name / size / kind views'],maxwidth=310)
lines(400,355,['Open, rename, duplicate, Trash','Folders / positions / comments','DESKTOP.FDR on a flat FAT root'],maxwidth=360)
text(72,461,'File / Edit / View / Special use the shared software menu system.',18,MUTED,maxwidth=688)
text(840,326,'Documents + tools',19,bold=True);text(1170,326,'Games + resources',19,bold=True)
lines(840,355,['Editor / Note / Reader / Utility','On-device compiler + tools','MacPaint: page, tools, Undo'],maxwidth=310)
lines(1170,355,['Rules, input and artwork','ART assets / PAINT.RSC tables','App-owned buffers and objects'],maxwidth=358)
text(840,461,'One active application; shared instructions, private application state.',18,MUTED,maxwidth=688)
arrow(800,504,546);text(830,533,'Normal JavaScript function calls',17,MUTED)
rect(48,556,1504,554,'#eaf4f1','#a9c9c3')
text(72,594,'02   TOOLBOX SOFTWARE · RESIDENT + SHARED CLIENT MODULES',25,TEAL,bold=True)
text(72,626,'ROM shares common instructions; inline client modules hold window stacks and app-specific document / control policy.',19,maxwidth=1456)
cols=[72,438,804,1170]
for x in (414,780,1146):rule(x,650,x,1074)
groups=[
 ('Windows / Ports / damage',['tbWindow / tbWindowPart','tbWindowAdjust / Bounds','tbWindowFocus / Remove / At','tbPortPush / Pop / Bounds','tbPlaceScreen(...)','tbDamage / Clip / Clear','tbControlPart / Value','tbScrollRect(...)','tbDrawBounds / Hit / Fill','Four Port levels; eight windows','Bounded union; exposed strips']),
 ('Menus / dialogs / text',['tbUIInit(...) / tbMenus(...)','tbMenuEnabled / Checked','tbText(...) / tbTextWidth(...)','tbBox(...) / tbUIDraw()','tbDialogOpen / Result','tbDialogValue / Selection','tbUIPointer(...) / tbUIKey(...)','tbMenuCommand / UIChanged','Save / Discard / Cancel','Open / Save As / Replace']),
 ('Memory + graphics',['tbMove(...) / tbFill(...)','tbResources / tbU16 / tbU32','tbPair32 / tbSessionU32','tbSurface(...) / tbScreen(...)','tbRect / tbPlace / tbClip','tbInk / tbBlit / tbPattern','tbCopyBits(src,dst)','tbRaster(src,dst,mode)','tbMask(...) / tbMaskOff(...)','tbPattern8 / tbPatternOff','tbPaintRect(...)']),
 ('Session + documents',['tbSessionProperty / Menus','tbSessionListen / Frame','tbSessionInvalidate(...)','tbSessionTransform(...)','tbSessionProgram / Suffix','tbSessionChrome / Names','tbSessionDocument(...)','tbDocumentContinue(...)','tbDocumentSaveAs / Header','tbDocumentSuspend(...)','One input / frame owner'])]
for x,(heading,calls) in zip(cols,groups):
 text(x,677,heading,19,bold=True,maxwidth=338)
 lines(x,710,calls,17,26,mono=True,maxwidth=338)
text(72,1090,'Cooperative events + frames. Pausing an app does not remove the independent keyboard / emergency recovery path.',18,TEAL,maxwidth=1456)
arrow(800,1114,1150);text(830,1139,'Versioned native services; no browser or extra CPU',17,MUTED)
rect(48,1160,1008,380);rect(1080,1160,472,380,'#f2f0e9','#d4cec0')
text(72,1198,'03   SYSTEM SERVICES',24,TEAL,bold=True)
text(72,1227,'Hardware transfers bytes and performs explicit operations; software chooses the policy.',18,MUTED,maxwidth=960)
text(72,1263,'Boot + program lifecycle',20,bold=True)
lines(72,1293,['Cold start: TOOLBOX.ROM from card (?TB)','Validate SYS / JSH; LOAD / RUN; chain','sysDocument: SOURCE metadata / names','Save → successful close → continuation'],17,25,maxwidth=458)
text(568,1263,'File + string services',20,bold=True)
lines(568,1293,['fsList: bounded catalog pages','fsRead / fsWrite / fsRemove / fsRename','sysRun: explicit app / tool launch','strByte: stored interned UTF-8 bytes'],17,25,maxwidth=464)
rule(72,1390,1032,1390)
text(72,1424,'Input + essential recovery',20,bold=True)
lines(72,1454,['Keyboard / pointer events; frame scheduling','Boot artwork + Terminal + ship keyboard','Escape exit; About key 254 → software UI'],17,25,maxwidth=458)
text(568,1424,'Native 64: toolbox(op,a,b,c)',20,bold=True)
lines(568,1454,['0 capabilities · 1 move · 2 fill · 5 SYS read','3 packed blit · 4 packed pattern fill','6 CopyBits · 7 Boolean / mask / pattern','8–11 typed memory · 12 destination scissor'],17,25,maxwidth=464)
text(1104,1198,'RESOURCES · DATA',23,'#655b3e',bold=True)
lines(1104,1235,['SYSTEM.SYS: boot-validated appearance','Legacy + normalized glyphs and advances','Typed TBF1 data, read through Toolbox'],17,28,maxwidth=424)
rule(1104,1322,1528,1322)
lines(1104,1353,['PAINT.RSC: MacPaint fonts / icons / patterns','ART: application artwork + font sprites','Data loads into app-owned memory','LNK: compiler names / constants / identity','Objects / globals / mutable data stay private'],17,28,maxwidth=424)
arrow(800,1544,1580);text(830,1569,'Reusable mechanisms execute the work',17,MUTED)
rect(48,1590,1504,280,'#edf1f5')
text(72,1628,'04   FPGA EXECUTION + I/O',24,TEAL,bold=True)
text(72,1658,'The .bit defines the circuits. Replaced classic menu / dialog / document / system-action controllers are removed.',19,maxwidth=1456)
for x in (414,780,1146):rule(x,1680,x,1848)
hardware=[
 ('Native JavaScript CPU',['Stack, heap, globals; most ops 3 clocks',f'{TOOLBOX_WORDS}-word Toolbox bank, from card',f'{PROGRAM_CODE_WORDS} program words (code + data)','VM 33.333 MHz; services 100 MHz']),
 ('Graphics + presentation',['Bounded copy / Boolean mask engine','Rasterizer → BRAM draw canvas','Dirty blocks → DDR front image','Palette / recovery → HDMI scanout']),
 ('Storage + physical I/O',['FAT storage / microSD interface','USB keyboard J15; PS/2 JA + JC','Joystick JB; input FIFOs / events','Audio synthesis + physical output']),
 ('Memory + board interface',[f'{EXT_PORT_MIB} MiB port; map uses {MAP_MIB} MiB','Nexys Video DDR3 bridge','On-chip instruction + data banks','One VM and one drawing canvas'])]
for x,(heading,items) in zip(cols,hardware):
 text(x,1710,heading,19,bold=True,maxwidth=338);lines(x,1742,items,17,28,maxwidth=338)
rect(48,1910,1504,184)
text(72,1946,'WHAT CAN CHANGE WITHOUT A NEW .bit?',22,TEAL,bold=True)
lines(72,1982,['Software algorithms / menus / dialogs: update ROM + LNK + matching apps, then cold machine restart.',
 'New hardware access / formats / instruction capacity / clocks: edit RTL → Vivado → qualify a new .bit.',
 f'Toolbox bank: {TB_USED} / {TB_USABLE} instructions used, {TB_USABLE - TB_USED} spare; the .bit holds no copy, the card does.',
 'CopyBits uses general bounded copy/raster hardware; its software composition can change with a matched disk.'],18,29,maxwidth=1456)
text(48,2140,f'{N_PROGRAMS} compiled programs, {N_LINKED} linked to the Toolbox. One matched ROM + linker + disk. Timing and board tests are separate.',17,MUTED,maxwidth=1504)
text(48,2172,'Sources: Toolbox / Finder JavaScript and RTL. Read CURRENT_SET.json and the release manifest for exact identities and status.',16,MUTED,maxwidth=1504)
save('architecture.svg')
# Keep byte-level memory detail available without obscuring the layer diagram.
begin(1600, 990, f'JMR {MAP_MIB} MiB physical memory map',
      f'Physical byte offsets, exclusive ends; not drawn to scale. The port reaches {EXT_PORT_MIB} MiB; the map uses the first {MAP_MIB} MiB. On-chip memory is separate.')
text(48, 56, f'Memory detail · the {MAP_MIB} MiB external map', 32, bold=True)
text(48, 91, f'{EXT_PORT_ADDR_BITS}-bit word port = {EXT_PORT_MIB} MiB (DDR3 on the board) · the map uses its first {MAP_MIB} MiB', 20, MUTED, maxwidth=1504)
rect(48, 120, 1504, 565)
text(72, 158, 'PHYSICAL RANGE', 17, TEAL, bold=True)
text(470, 158, 'OWNER / PURPOSE', 17, TEAL, bold=True)
text(1200, 158, 'SIZE / STORAGE', 17, TEAL, bold=True)
rows = [
 ('0 – 6,860,800', 'Artwork / compile-time artwork staging', '6,860,800 bytes'),
 ('6,860,800 – 7,057,408', 'Finder executable cache', '192 KiB packed'),
 ('7,057,408 – 7,131,136', 'Parked Finder arena', '72 KiB packed'),
 ('7,131,136 – 7,155,712', 'Retained SYS payload; ROM stages in SOURCE', '24 KiB reserved'),
 ('7,155,712 – 7,462,912', 'Display front image · 640 × 480 indexed pixels', '300 KiB'),
 ('7,462,912 – 7,495,680', 'Work / storage area + reserved gap', '32 KiB'),
 ('7,495,680 – 7,643,136', 'Active compiler / shared arena', '73,728 logical bytes'),
 ('7,643,136 – 7,774,208', 'SOURCE', '65,536 logical bytes'),
 ('7,774,208 – 8,388,608', 'Image / compile staging', '307,200 logical bytes'),
]
# Boundaries that Python mirrors must agree with the rows (RTL word addresses × 2).
_bounds = {int(span.split(' – ')[0].replace(',', '')) for span, _, _ in rows}
_bounds |= {int(span.split(' – ')[1].replace(',', '')) for span, _, _ in rows}
for _b in (SYSTEM_CACHE_BASE * 2, FINDER_STATE_BASE * 2, _FB_SRAM_BASE_BYTES,
           CSCR_SRAM_BASE * 2, SRC_SRAM_BASE * 2, CIMG_SRAM_BASE * 2, SRAM_BYTES):
    if _b not in _bounds:
        raise ValueError(f'memory-map rows are stale: no boundary at {_b:,}')
for i, (span, owner, size) in enumerate(rows):
    y = 204 + i*54
    rule(72, y-22, 1528, y-22)
    text(72, y+8, span, 19, mono=True, maxwidth=374)
    text(470, y+8, owner, 20, maxwidth=706)
    text(1200, y+8, size, 19, maxwidth=328)
text(48, 729, 'Logical addresses are a different view', 23, TEAL, bold=True)
lines(48, 766, [
 f'Toolbox addresses 0–{CSTG_WORDS - 1:,} select arena bytes. The service maps across the physical gap; do not multiply them by two.',
 'The last three physical regions store one logical byte per 16-bit word. The parked Finder copy is packed instead.',
 'RTL aperture constants are 16-bit word addresses; multiply those constants by two to compare with this physical map.',
], 19, 31, maxwidth=1504)
text(48, 884, 'On-chip BRAM is separate from this map', 23, TEAL, bold=True)
lines(48, 919, [
 'Application code, VM execution state, drawing canvas, fonts/captions and buffers consume scarce on-chip memory.',
 f'Code: Toolbox bank 0–{TOOLBOX_WORDS - 1} (from TOOLBOX.ROM at cold start), program bank {TOOLBOX_WORDS}–{TOOLBOX_WORDS + PROGRAM_CODE_WORDS - 1}.',
], 19, 30, maxwidth=1504)
text(48, 978, 'Sources: jmr_js_vm_pkg.sv, jmr_console_engine.sv, jmr_js_core.sv; docs/ARCHITECTURE.md.', 16, MUTED)
save('memory-map.svg')


def svg_to_png(source, scale=2):
    """2x PNG beside the SVG: cairosvg if installed, else librsvg through GdkPixbuf."""
    try:
        import cairosvg
    except ImportError:
        import re
        import gi
        gi.require_version('GdkPixbuf', '2.0')
        from gi.repository import GdkPixbuf
        w, h = map(int, re.search(r'width="(\d+)" height="(\d+)"', source.read_text()).groups())
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(source), w * scale, h * scale, True)
        png = source.with_suffix('.png')
        pixbuf.savev(str(png), 'png', [], [])
        from PIL import Image
        Image.open(png).convert('RGB').save(png, optimize=True)
        return
    cairosvg.svg2png(url=str(source), write_to=str(source.with_suffix('.png')), scale=scale, background_color='#f4f7f8')

for source in [OUT / 'architecture.svg', OUT / 'memory-map.svg']:
    svg_to_png(source)
print('Generated architecture + memory sources and 2x PNG exports for all diagrams; measured text fits its column.')
