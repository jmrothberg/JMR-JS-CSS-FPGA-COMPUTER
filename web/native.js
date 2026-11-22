// JMR JS Computer — native Chrome preview (web/native.html).
//
// Runs the JavaScript SOURCE of the Finder, the resident Toolbox and every
// program directly in Chrome. The machine's natives (arena, Toolbox bulk
// ops, card files, launching, sound) are JavaScript stand-ins below.
//
// This is a FAST LOCAL PREVIEW. It does not enforce board limits (heap,
// 16 slots per function, source size, compile errors). PYTHON, FPGA-SIM and
// the board do. A program that runs here can still fail there:
// check it with tools/check_port.py and the real simulators.
//
// Reference behaviour this file ports (keep them in step):
//   functional_model/machine.py  _nat_* natives, CSS -> palette index
//   functional_model/toolbox.py  execute() ops 0-12
//   functional_model/canvas_engine.py  fillRect / fillText / scissor
//   runtime/backend.py  _finder_launch, _park_finder, _resume_finder
//   tools/compile_js.py  <script> extraction, _PAL8
//   tools/toolbox_linker.py  library order
'use strict';

const W = 640, H = 480;
const CSTG = 380928;        // jsb_format.CSTG_WORDS: flat arena bytes
const CSCR = 73728;         // jsb_format.CSCR_WORDS: the half a parked Finder keeps
const TB_VERSION = 0x00010FFF;
const SOURCE_MAX = 65536;
const MARKER = 'jmr-toolbox: resident-v2';
const LIBRARY = ['toolbox.js', 'ui.js', 'session.js', 'documents.js'];
const PAL8 = [[0,0,0],[255,255,255],[255,0,0],[0,255,0],[0,0,255],[255,255,0],[0,255,255],[255,0,255]];
// functional_model/font8.py glyph(), ASCII 32..126, 8 rows each, bit7 = left.
const FONT_HEX =
  '000000000000000030303030000030006c6c0000000000006cfe6c6cfe6c0000307c60780c7c3000c4c81020404c8c00304848344c443a0030306000' +
  '00000000183060606030180060301818183060000028107c10280000003030fc303000000000000000303060000000fc000000000000000000303000' +
  '02060c183060c0007cc6ced6e6c67c00307030303030fc007cc6061c3060fe007cc6063c06c67c0018385898fe181800fec0fc0606c67c003860c0fc' +
  'c6c67c00fe060c18303030007cc6c67cc6c67c007cc6c67e060c780000303000303000000030300030306000183060c0603018000000fc00fc000000' +
  'c06030183060c0007cc6061c300030007cc6061c3000300030488484fc848400f88484f88484f8007884808080847800f88484848484f800fc8080f8' +
  '8080fc00fc8080f8808080007884809c84847800848484fc8484840078303030303078003c18181818986000848890e090888400808080808080fc00' +
  '84ccb4848484840084c4a4948c8484007884848484847800f88484f8808080007884848494887400f88484f8908884007884807804847800fc303030' +
  '3030300084848484848478008484848484483000848484b4b4cc840084844830488484008484483030303000fc0408102040fc007860606060607800' +
  'c06030180c06020078181818181878003078cc0000000000000000000000fe006030000000000000000078047c847c008080f8848484f80000007880' +
  '8080780004047c8484847c0000007884fc8078003840f0404040400000007c84847c04788080f88484848400300070303030780018001c0c0c0c8c70' +
  '80808890e090880070303030303078000000d4aaaaaaaa000000f8848484840000007884848478000000f88484f8808000007c84847c04040000bcc0' +
  '8080800000007c807804f80020702020202418000000848484847c00000084848448300000008484b4b44800000084483048840000008484847c0478' +
  '0000fc102040fc001c30306030301c0030303030303030007018180c181870000000649800000000';
const FONT = Uint8Array.from(FONT_HEX.match(/../g), h => parseInt(h, 16));

const I = v => { v = +v; return Number.isFinite(v) ? Math.trunc(v) : 0; };
const U32 = v => I(v) >>> 0;
const latin = new TextDecoder('latin1');
const utf8 = new TextDecoder('utf-8');
const enc = new TextEncoder();

// ---------------------------------------------------------------- machine
const M = {
  arena: new Uint8Array(CSTG),
  fb: new Uint8Array(W * H),
  palette: [], lut: new Uint32Array(256), palGrow: false, palUsed: 0,
  css: new Map(),
  clip: [0, 0, W, H],
  src: new Uint8Array(SOURCE_MAX), srcLen: 0, sourceName: '', unnamed: false,
  exitStatus: 0, role: 0, windowDirty: 0,
  sprites: [], sys: null, library: '',
  prog: null, parked: null, request: null, loading: false, finderRetry: false,
  keyBits: 0, sound: new Map(),
};

function setPalette(rgbList, grow, used) {
  M.palette = rgbList.map(c => c.slice());
  while (M.palette.length < 256) M.palette.push([0, 0, 0]);
  M.palGrow = grow; M.palUsed = used; M.css.clear();
  for (let i = 0; i < 256; i++) lutSet(i);
}
function lutSet(i) {
  const [r, g, b] = M.palette[i];
  M.lut[i] = (0xff000000 | (b << 16) | (g << 8) | r) >>> 0;
}
// desktop.py rgb332: the Finder (role 9) paints with these indexes.
function rgb332(v) {
  const r = (v >> 5) & 7, g = (v >> 2) & 7, b = v & 3;
  return [(r << 5) | (r << 2) | (r >> 1), (g << 5) | (g << 2) | (g >> 1), b * 85];
}
function setRole(v) {
  M.role = I(v);
  if (M.role === 9) setPalette(Array.from({ length: 256 }, (_, i) => rgb332(i)), false, 256);
}

// Chrome parses every CSS color for us; invalid strings keep the sentinel.
const probe = document.createElement('canvas').getContext('2d');
function parseCss(s) {
  probe.fillStyle = '#000'; probe.fillStyle = s; const a = probe.fillStyle;
  probe.fillStyle = '#fff'; probe.fillStyle = s; const b = probe.fillStyle;
  if (a !== b) return null;
  if (a[0] === '#') return [parseInt(a.slice(1, 3), 16), parseInt(a.slice(3, 5), 16), parseInt(a.slice(5, 7), 16)];
  const m = /rgba?\(([^)]*)\)/.exec(a);
  return m ? m[1].split(',').slice(0, 3).map(n => Math.round(+n)) : null;
}
function nearest(rgb) {
  let best = 1, bd = Infinity;
  for (let i = 1; i < 256; i++) {
    const p = M.palette[i], dr = rgb[0] - p[0], dg = rgb[1] - p[1], db = rgb[2] - p[2];
    const d = dr * dr + dg * dg + db * db;
    if (d < bd) { best = i; bd = d; if (!d) break; }
  }
  return best;
}
// machine.py: numbers are indexes, black is 0, unknown strings are 7.
// A program without art gets its source colors appended after _PAL8, the
// same entries tools/compile_js.py _build_title_palette harvests.
function colorIndex(v) {
  if (typeof v === 'number') return I(v) & 255;
  if (v && typeof v === 'object' && v._stops) v = v._stops[0] || '#000';
  const s = String(v).trim().toLowerCase();
  let idx = M.css.get(s);
  if (idx !== undefined) return idx;
  const rgb = parseCss(s);
  if (!rgb) idx = 7;
  else if (!rgb[0] && !rgb[1] && !rgb[2]) idx = 0;
  else {
    idx = nearest(rgb);
    const p = M.palette[idx];
    if ((p[0] !== rgb[0] || p[1] !== rgb[1] || p[2] !== rgb[2]) && M.palGrow && M.palUsed < 256) {
      idx = M.palUsed++; M.palette[idx] = rgb; lutSet(idx);
    }
  }
  M.css.set(s, idx);
  return idx;
}

// ---------------------------------------------------------------- card
const disk = {
  files: [],
  find(name) { name = name.toUpperCase(); return this.files.find(f => f.name === name); },
  write(name, data, append) {
    const f = this.find(name), now = new Date();
    const date = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    if (!f) { this.files.push({ name: name.toUpperCase(), data, date, attr: 0x20 }); return; }
    if (append) { const d = new Uint8Array(f.data.length + data.length); d.set(f.data); d.set(data, f.data.length); f.data = d; }
    else f.data = data;
    f.date = date;
  },
  remove(name) { const f = this.find(name); if (f) this.files.splice(this.files.indexOf(f), 1); },
};

// hardware_model/fat32.py: MBR partition or superfloppy, root directory only.
function readCard(buffer) {
  const u8 = new Uint8Array(buffer), dv = new DataView(buffer);
  let part = 0;
  const type = u8[446 + 4];
  if ([0x0b, 0x0c, 0x0e].includes(type) || (type && u8[510] === 0x55 && u8[511] === 0xaa)) part = dv.getUint32(446 + 8, true);
  const b = part * 512;
  if (u8[b + 510] !== 0x55 || u8[b + 511] !== 0xaa) throw new Error('card.img has no FAT32 signature');
  const bps = dv.getUint16(b + 11, true), spc = u8[b + 13], res = dv.getUint16(b + 14, true);
  const fats = u8[b + 16], spf = dv.getUint32(b + 36, true), root = dv.getUint32(b + 44, true);
  const fat = (part + res) * bps, data = part + res + fats * spf, cbytes = spc * bps;
  const at = c => (data + (c - 2) * spc) * bps;
  const chain = c => { const out = []; while (c >= 2 && c < 0x0ffffff8 && out.length < 1 << 20) { out.push(c); c = dv.getUint32(fat + c * 4, true) & 0x0fffffff; } return out; };
  const files = [];
  outer: for (const c of chain(root)) for (let o = 0; o < cbytes; o += 32) {
    const e = at(c) + o;
    if (u8[e] === 0) break outer;
    const attr = u8[e + 11];
    if (u8[e] === 0xe5 || attr === 0x0f || attr & 0x18) continue;
    const stem = latin.decode(u8.subarray(e, e + 8)).trimEnd(), ext = latin.decode(u8.subarray(e + 8, e + 11)).trimEnd();
    const size = dv.getUint32(e + 28, true), start = dv.getUint16(e + 26, true) | (dv.getUint16(e + 20, true) << 16);
    const bytes = new Uint8Array(size);
    let got = 0;
    if (size && start >= 2) for (const k of chain(start)) {
      const n = Math.min(cbytes, size - got);
      bytes.set(u8.subarray(at(k), at(k) + n), got); got += n;
      if (got >= size) break;
    }
    files.push({ name: ext ? `${stem}.${ext}` : stem, data: bytes, date: dv.getUint16(e + 24, true), attr });
  }
  return files;
}

// ---------------------------------------------------------------- arena natives
function stgRead(i) { i = I(i); return i >= 0 && i < CSTG ? M.arena[i] : -1; }
function stgWrite(i, b) {
  i = I(i);
  if (i < 0 || i >= CSTG) throw new Error(`VM software fault 5: stgWrite(${i}) outside the arena`);
  M.arena[i] = I(b) & 255;
}
function arenaName(off, max = 16) {
  let s = '';
  for (let i = 0; i < max; i++) { const b = stgRead(I(off) + i); if (b <= 0) break; s += String.fromCharCode(b & 127); }
  return s.trim();
}
function fatName(name) {
  name = name.trim().toUpperCase();
  const parts = name.split('.');
  if (!name || parts.length > 2 || !parts[0].length || parts[0].length > 8 || (parts[1] || '').length > 3) return null;
  return name;
}

// Strings: strByte reads UTF-8 bytes; the last non-ASCII string is cached so
// a loop over a long document stays linear.
let lastStr = null, lastBytes = null;
function strByte(text, index) {
  if (typeof text !== 'string') return -1;
  index = +index;
  if (!Number.isFinite(index)) return -1;
  index = Math.trunc(index);
  if (text !== lastStr) { lastStr = text; lastBytes = /[^\x00-\x7f]/.test(text) ? enc.encode(text) : null; }
  if (lastBytes) return index >= 0 && index < lastBytes.length ? lastBytes[index] : -1;
  return index >= 0 && index < text.length ? text.charCodeAt(index) : -1;
}
function stringFromBytes(pages, byteLength, checked) {
  let raw;
  if (byteLength !== undefined) {
    const start = I(pages), n = I(byteLength);
    if (start < 0 || n < 0 || start > CSTG || n > CSTG - start) throw new Error('VM software fault 4: byte span');
    raw = M.arena.slice(start, start + n);
  } else {
    if (!Array.isArray(pages)) throw new Error('VM software fault 4: byte pages');
    raw = Uint8Array.from(pages.flat());
  }
  return utf8.decode(raw);
}
function runtimeFault(code) {
  const ok = Number.isInteger(code) && code >= 1 && code <= 9;
  throw new Error(`VM software fault ${ok ? code : 5}`);
}

// ---------------------------------------------------------------- SOURCE
function setSource(bytes, name) {
  M.src = new Uint8Array(Math.max(SOURCE_MAX, bytes.length));
  M.src.set(bytes); M.srcLen = bytes.length; M.sourceName = name;
}
function srcLen() { return M.srcLen; }
function srcByte(i) { i = I(i); return i >= 0 && i < M.srcLen ? M.src[i] : -1; }
function srcWrite(i, b) {
  i = I(i);
  if (i < 0 || i >= SOURCE_MAX) throw new Error(`VM software fault 5: srcWrite(${i}) outside SOURCE`);
  M.src[i] = I(b) & 255;
}
function srcSetLen(n) {
  n = I(n);
  if (n < 0 || n > SOURCE_MAX) throw new Error(`VM software fault 5: srcSetLen(${n}) outside SOURCE`);
  if (n < M.srcLen) M.src.fill(0, n, M.srcLen);
  M.srcLen = n;
}
function sysDocument(op, ptr, role) {
  op = I(op); ptr = I(ptr); role = role === undefined ? 1 : I(role);
  if (op === 0) {
    if (ptr < 0 || ptr > CSTG - 20) return -1;
    const name = enc.encode(M.sourceName).slice(0, 16);
    const status = M.exitStatus & 255;
    M.exitStatus = 0;
    for (let i = 0; i < 16; i++) stgWrite(ptr + i, i < name.length ? name[i] : 0);
    stgWrite(ptr + 16, name.length); stgWrite(ptr + 17, M.unnamed ? 1 : 0);
    stgWrite(ptr + 18, M.role & 7); stgWrite(ptr + 19, status);
    return 0;
  }
  if ((op !== 1 && op !== 2) || (role !== 1 && role !== 5)) return -1;
  if (op === 1) {
    if (ptr < 0 || ptr >= CSTG) return -1;
    const raw = M.arena.subarray(ptr, Math.min(CSTG, ptr + 13));
    const end = raw.indexOf(0);
    if (end < 0) return -1;
    const parts = latin.decode(raw.subarray(0, end)).toUpperCase().split('.');
    if (parts.length === 1) parts.push(role === 5 ? 'JS' : 'HTM');
    const legal = /^[A-Z0-9$%'\-_@~`!(){}^#&]+$/;
    if (parts.length !== 2 || parts[0].length < 1 || parts[0].length > 8 || parts[1].length < 1 ||
        parts[1].length > 3 || !legal.test(parts[0]) || !legal.test(parts[1])) return -1;
    M.sourceName = parts.join('.'); M.unnamed = false;
  } else {
    srcSetLen(0);
    M.sourceName = role === 5 ? 'UNTITLED.TXT' : 'UNTITLED.HTM'; M.unnamed = true;
  }
  return 0;
}

// ---------------------------------------------------------------- files
function fsList(dst, capacity, startRecord) {
  dst = I(dst); capacity = I(capacity); startRecord = U32(startRecord);
  const rows = disk.files;
  const rec = f => { const n = enc.encode(f.name).slice(0, 12); return [n.length, ...n, ...u32b(f.data.length), f.date & 255, (f.date >> 8) & 255, f.attr & 255]; };
  if (dst) {
    if (dst < 0 || capacity < 37 || dst > CSTG || capacity > CSTG - dst) return -1;
    const page = new Array(16).fill(0);
    let count = 0, used = 0, more = 0;
    for (const f of rows.slice(startRecord)) {
      if (page.length + 21 > capacity) { more = 1; break; }
      page.push(...rec(f)); used = (used + f.data.length) >>> 0; count++;
    }
    page.push(0);
    page.splice(0, 4, ...u32b(used)); page[8] = count & 255; page[9] = (count >> 8) & 255;
    page[10] = more; page.splice(12, 4, ...u32b(startRecord + count));
    page.forEach((v, i) => stgWrite(dst + i, v));
    return count;
  }
  let off = 256, used = 0, count = 0;
  for (const f of rows) {
    const r = rec(f);
    if (off + r.length >= CSTG) break;
    r.forEach(v => stgWrite(off++, v));
    used += f.data.length; count++;
  }
  stgWrite(off, 0);
  u32b(used).forEach((v, i) => stgWrite(240 + i, v));
  for (let i = 0; i < 4; i++) stgWrite(244 + i, 0);
  stgWrite(248, count & 255); stgWrite(249, (count >> 8) & 255);
  return count;
}
function u32b(v) { v >>>= 0; return [v & 255, (v >> 8) & 255, (v >> 16) & 255, v >>> 24]; }
function fsRead(nameOff, fileOff, dstOff, n) {
  const f = disk.find(fatName(arenaName(nameOff)) || '?');
  if (!f) return -1;
  const start = Math.max(0, I(fileOff)), chunk = f.data.subarray(start, start + Math.max(0, I(n)));
  for (let i = 0; i < chunk.length; i++) stgWrite(I(dstOff) + i, chunk[i]);
  return chunk.length;
}
function fsWrite(nameOff, srcOff, n, mode) {
  const name = fatName(arenaName(nameOff));
  if (!name) return -1;
  const count = Math.max(0, I(n)), blob = new Uint8Array(count);
  for (let i = 0; i < count; i++) blob[i] = stgRead(I(srcOff) + i) & 255;
  disk.write(name, blob, I(mode) === 1);
  return count;
}
function fsRemove(nameOff) {
  const name = fatName(arenaName(nameOff));
  if (!name) return -1;
  disk.remove(name);
  return 0;
}
function fsRename(oldOff, newOff) {
  const a = fatName(arenaName(oldOff)), b = fatName(arenaName(newOff));
  if (!a || !b) return -1;
  if (a === b) return 0;
  const f = disk.find(a);
  if (!f) return -1;
  disk.write(b, f.data); disk.remove(a);
  return 0;
}

// ---------------------------------------------------------------- Toolbox ops
// Port of functional_model/toolbox.py execute(). The arena is M.arena; the
// screen is M.fb, and every screen write honours the op 12 scissor.
function screenPut(addr, v) {
  const x = addr % W, y = (addr / W) | 0, k = M.clip;
  if (x >= k[0] && x < k[2] && y >= k[1] && y < k[3]) M.fb[addr] = v;
}
function toolbox(op, a, b, c) {
  op = I(op); a = I(a); b = I(b); c = I(c);
  const A = M.arena;
  const valid = (p, n) => p >= 0 && p <= CSTG && n >= 0 && n <= CSTG - p;
  if (op === 0) return TB_VERSION;
  if (op === 12) {
    a >>>= 0; b >>>= 0; c >>>= 0;
    if (c === 1 && a === 0 && b === 0) M.clip = [0, 0, W, H];
    else if (c === 0) {
      let x = a & 65535, y = a >>> 16;
      if (x & 32768) x -= 65536;
      if (y & 32768) y -= 65536;
      const w = b & 65535, h = b >>> 16, cl = (v, m) => Math.max(0, Math.min(m, v));
      M.clip = [cl(x, W), cl(y, H), cl(x + w, W), cl(y + h, H)];
    } else return -1;
    return 1;
  }
  if (op >= 8 && op <= 11) {
    b >>>= 0; c >>>= 0;
    const n = op === 10 ? 8 : op === 11 ? 2 : 4;
    if (!valid(a, n) || (op !== 10 && c !== 0) || (op === 8 && b !== 0)) return -1;
    if (op === 8) return A[a] + A[a + 1] * 256 + A[a + 2] * 65536 + A[a + 3] * 16777216;
    for (let i = 0; i < n; i++) A[a + i] = i < 4 ? (b >>> (8 * i)) & 255 : (c >>> (8 * (i - 4))) & 255;
    return n;
  }
  if (op === 6 || op === 7) {
    if (c !== 0 || !valid(a, 64) || !valid(b, 64)) return -1;
    const surface = p => {
      const d = A.slice(p, p + 64), dv = new DataView(d.buffer);
      const u = i => dv.getUint16(i, true), s = i => dv.getInt16(i, true);
      const base = dv.getUint32(4, true), stride = u(8), width = u(10), height = u(12), screen = d[2] === 2;
      if (d[0] !== 1 || d[1] !== 8 || (d[2] !== 0 && d[2] !== 2) || d[3] !== 1 || !width || !height || stride < width ||
          (screen && (base !== 0 || stride !== W || width !== W || height !== H)) ||
          (!screen && !valid(base, stride * height))) return null;
      return { d, dv, base, stride, width, height, screen, sx: u(14), sy: u(16), w: u(18), h: u(20),
               dx: s(22), dy: s(24), cx: s(26), cy: s(28), cw: u(30), ch: u(32) };
    };
    const src = surface(a), dst = surface(b);
    if (!src || !dst) return -1;
    const w = src.w, h = src.h;
    if (w !== dst.w || h !== dst.h || src.sx + w > src.width || src.sy + h > src.height) return -1;
    if (!src.screen && !dst.screen && src.base < dst.base + dst.stride * dst.height &&
        dst.base < src.base + src.stride * src.height && src.stride !== dst.stride) return -1;
    const pixel = (s, x, y) => { const ad = s.base + y * s.stride + x; return s.screen ? M.fb[ad] : A[ad]; };
    const inside = (xx, yy) => xx >= 0 && xx < dst.width && yy >= 0 && yy < dst.height &&
      xx >= dst.cx && xx < dst.cx + dst.cw && yy >= dst.cy && yy < dst.cy + dst.ch;
    const put = (xx, yy, v) => { const ad = dst.base + yy * dst.stride + xx; if (dst.screen) screenPut(ad, v); else A[ad] = v; };
    if (op === 7) {
      const d = src.d, mode = d[36], flags = d[37];
      const maskBase = src.dv.getUint32(48, true), maskStride = src.dv.getUint16(52, true), extent = maskStride * h;
      if (mode > 5 || flags > 3) return -1;
      if (flags & 1 && (maskStride < ((w + 7) >> 3) || !valid(maskBase, extent) ||
          (!dst.screen && !(maskBase + extent <= dst.base || dst.base + dst.stride * dst.height <= maskBase)))) return -1;
      const reverse = src.screen === dst.screen &&
        dst.base + dst.dy * dst.stride + dst.dx > src.base + src.sy * src.stride + src.sx;
      for (let j = 0; j < h; j++) {
        const y = reverse ? h - 1 - j : j;
        for (let i = 0; i < w; i++) {
          const x = reverse ? w - 1 - i : i, xx = dst.dx + x, yy = dst.dy + y;
          if (!inside(xx, yy)) continue;
          if (flags & 1 && !(A[maskBase + y * maskStride + (x >> 3)] & (128 >> (x & 7)))) continue;
          let v;
          if (mode === 5) v = pixel(dst, xx, yy) ^ 255;
          else {
            v = flags & 2 ? (d[40 + (yy & 7)] & (128 >> (xx & 7)) ? d[34] : d[35]) : pixel(src, src.sx + x, src.sy + y);
            if (mode) {
              const p = pixel(dst, xx, yy);
              v = mode === 1 ? p | v : mode === 2 ? p ^ v : mode === 3 ? p & (v ^ 255) : p & v;
            }
          }
          put(xx, yy, v);
        }
      }
      return w * h;
    }
    const data = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) data[y * w + x] = pixel(src, src.sx + x, src.sy + y);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const xx = dst.dx + x, yy = dst.dy + y;
      if (inside(xx, yy)) put(xx, yy, data[y * w + x]);
    }
    return w * h;
  }
  if (op === 1) {
    if (!valid(a, c) || !valid(b, c)) return -1;
    A.copyWithin(b, a, a + c);
    return c;
  }
  if (op === 2) {
    if (!valid(a, c)) return -1;
    A.fill(b & 255, a, a + c);
    return c;
  }
  if (op === 5) {
    const d = M.sys;
    if (!d || a < 0 || a > d.length || c < 0 || c > d.length - a || !valid(b, c)) return -1;
    A.set(d.subarray(a, a + c), b);
    return c;
  }
  if ((op !== 3 && op !== 4) || !valid(a, 64)) return -1;
  const d = A.slice(a, a + 64), dv = new DataView(d.buffer);
  const u16 = i => dv.getUint16(i, true), s16 = i => dv.getInt16(i, true);
  const fmt = d[1], flags = d[2], scale = d[3], base = dv.getUint32(4, true);
  const stride = u16(8), sw = u16(10), sh = u16(12), sx = u16(14), sy = u16(16), w = u16(18), h = u16(20);
  const dx = s16(22), dy = s16(24), cx = s16(26), cy = s16(28), cw = u16(30), ch = u16(32), fg = d[34], bg = d[35];
  if (d[0] !== 1 || ![1, 4, 8].includes(fmt) || ![1, 2, 4, 8].includes(scale) || !sw || !sh ||
      !valid(base, stride * sh) || stride < ((sw * fmt + 7) >> 3) || sx + w > sw || sy + h > sh) return -1;
  const mask = (1 << fmt) - 1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const xx = sx + x, yy = sy + y, address = base + yy * stride + ((xx * fmt) >> 3);
    const byte = A[address];
    const shift = fmt === 1 ? 7 - (xx & 7) : fmt === 4 ? (xx & 1 ? 0 : 4) : 0;
    const value = (byte >> shift) & mask;
    if (op === 4) {
      const ink = d[40 + (yy & 7)] & (128 >> (xx & 7)) ? fg : bg;
      A[address] = (byte & ~(mask << shift)) | ((ink & mask) << shift);
    } else if (!(flags & 1 && value === 0)) {
      const color = fmt === 1 ? (value ? fg : bg) : fmt === 4 ? d[48 + value] : value;
      for (let zy = 0; zy < scale; zy++) for (let zx = 0; zx < scale; zx++) {
        const px = dx + x * scale + zx, py = dy + y * scale + zy;
        if (px >= 0 && px < W && py >= 0 && py < H && px >= cx && px < cx + cw && py >= cy && py < cy + ch) screenPut(py * W + px, color);
      }
    }
  }
  return w * h;
}

// ---------------------------------------------------------------- sound
let audio = null, psg = null;
function sound(ch, freq, vol, frames, slide) {
  ch = I(ch) & 3;
  M.sound.set(ch, [ch, I(freq) & 65535, I(vol) & 15, I(frames) & 255, ((I(slide) + 128) & 255) - 128]);
}
function flushSound() {
  if (!M.sound.size) return;
  if (psg && audio.state === 'running') {
    const out = new Uint8Array(M.sound.size * 6), dv = new DataView(out.buffer);
    let o = 0;
    for (const [ch, f, v, fr, sl] of M.sound.values()) {
      dv.setUint8(o, ch); dv.setUint16(o + 1, f, true); dv.setUint8(o + 3, v); dv.setUint8(o + 4, fr); dv.setInt8(o + 5, sl); o += 6;
    }
    psg.port.postMessage({ payload: out });
  }
  M.sound.clear();
}

// ---------------------------------------------------------------- canvas
// An indexed 640x480 surface with the machine's Canvas subset. Colors are
// palette indexes; index 0 is transparent for drawImage.
class Ctx {
  constructor(buf, w, h, screen) {
    this._b = buf; this._w = w; this._h = h; this._screen = screen; this.canvas = null;
    this._fi = 1; this._fv = '#fff'; this._si = 1; this._sv = '#fff';
    this._px = 8; this._align = 'left'; this._base = 0; this._lw = 1;
    this._sx = 1; this._sy = 1; this._tx = 0; this._ty = 0; this._stack = []; this._path = []; this._cur = null;
    this.globalAlpha = 1; this.imageSmoothingEnabled = false; this.globalCompositeOperation = 'source-over';
    this.systemViewport = 0;
  }
  get fillStyle() { return this._fv; }
  set fillStyle(v) { this._fv = v; this._fi = colorIndex(v); }
  get strokeStyle() { return this._sv; }
  set strokeStyle(v) { this._sv = v; this._si = colorIndex(v); }
  get font() { return `${this._px}px`; }
  set font(v) { const m = /(\d+(?:\.\d+)?)px/.exec(String(v)); if (m) this._px = +m[1]; }
  get textAlign() { return this._align; }
  set textAlign(v) { this._align = String(v); }
  get textBaseline() { return ['alphabetic', 'top', 'middle', 'bottom'][this._base] || 'alphabetic'; }
  // machine.py _note_baseline: only top / middle / bottom change it.
  set textBaseline(v) { const n = String(v).trim().toLowerCase(); if (n === 'top') this._base = 1; else if (n === 'middle') this._base = 2; else if (n === 'bottom') this._base = 3; }
  get lineWidth() { return this._lw; }
  set lineWidth(v) { if (+v > 0) this._lw = +v; }
  get systemWindow() { return this._screen ? M.role : 0; }
  set systemWindow(v) { if (this._screen) setRole(v); }
  get windowDirty() { return this._screen ? M.windowDirty : 0; }
  set windowDirty(v) { if (this._screen) M.windowDirty = I(v); }

  _clip() { return this._screen ? M.clip : [0, 0, this._w, this._h]; }
  _span(x0, y0, x1, y1, c) {
    const k = this._clip();
    x0 = Math.max(x0, k[0]); y0 = Math.max(y0, k[1]); x1 = Math.min(x1, k[2]); y1 = Math.min(y1, k[3]);
    if (x0 >= x1) return;
    for (let y = y0; y < y1; y++) this._b.fill(c, y * this._w + x0, y * this._w + x1);
  }
  _rect(x, y, w, h, c) {
    let X0 = x * this._sx + this._tx, Y0 = y * this._sy + this._ty, X1 = X0 + w * this._sx, Y1 = Y0 + h * this._sy;
    if (X1 < X0) [X0, X1] = [X1, X0];
    if (Y1 < Y0) [Y0, Y1] = [Y1, Y0];
    this._span(Math.floor(X0), Math.floor(Y0), Math.floor(X1), Math.floor(Y1), c);
  }
  _put(x, y, c) {
    const k = this._clip();
    if (x >= k[0] && x < k[2] && y >= k[1] && y < k[3]) this._b[y * this._w + x] = c;
  }
  fillRect(x, y, w, h, c) { this._rect(+x, +y, +w, +h, c === undefined ? this._fi : I(c) & 255); }
  clearRect(x, y, w, h) { this._rect(+x, +y, +w, +h, 0); }
  strokeRect(x, y, w, h) {
    const l = this._lw;
    x = +x; y = +y; w = +w; h = +h;
    this._rect(x, y, w, l, this._si); this._rect(x, y + h - l, w, l, this._si);
    this._rect(x, y, l, h, this._si); this._rect(x + w - l, y, l, h, this._si);
  }
  // machine.py _font_scale: px * x-scale / 8, half up, 1..15.
  _scale() { return Math.max(1, Math.min(15, Math.floor(this._px * (this._sx || 1) / 8 + 0.5))); }
  _text(text, x, y, c) {
    const s = String(text), k = this._scale(), cw = 8 * k;
    let px = Math.floor(+x * this._sx + this._tx), py = Math.floor(+y * this._sy + this._ty);
    if (this._align === 'center') px -= (s.length * cw) >> 1;
    else if (this._align === 'right' || this._align === 'end') px -= s.length * cw;
    py -= this._base === 1 ? 0 : this._base === 2 ? 4 * k : 8 * k;
    for (let i = 0; i < s.length; i++) {
      let g = s.charCodeAt(i);
      g = (g < 32 || g > 126 ? 63 : g) - 32;
      const x0 = px + i * cw;
      for (let dy = 0; dy < 8; dy++) {
        const bits = FONT[g * 8 + dy];
        if (!bits) continue;
        for (let dx = 0; dx < 8; dx++) if (bits & (128 >> dx))
          for (let ry = 0; ry < k; ry++) for (let rx = 0; rx < k; rx++) this._put(x0 + dx * k + rx, py + dy * k + ry, c);
      }
    }
  }
  fillText(t, x, y) { this._text(t, x, y, this._fi); }
  strokeText(t, x, y) { this._text(t, x, y, this._si); }
  measureText(t) { return { width: String(t).length * 8 * this._scale() }; }
  drawImage(img, ...a) {
    const s = img && (img._s || (img._ctx && { w: img._ctx._w, h: img._ctx._h, pix: img._ctx._b }));
    if (!s || !s.w || !s.h) return;
    let sx = 0, sy = 0, sw = s.w, sh = s.h, dx, dy, dw = s.w, dh = s.h;
    if (a.length >= 8) [sx, sy, sw, sh, dx, dy, dw, dh] = a.map(Number);
    else if (a.length >= 4) [dx, dy, dw, dh] = a.map(Number);
    else [dx, dy] = a.map(Number);
    const X0 = Math.floor(dx * this._sx + this._tx), Y0 = Math.floor(dy * this._sy + this._ty);
    const X1 = Math.floor((dx + dw) * this._sx + this._tx), Y1 = Math.floor((dy + dh) * this._sy + this._ty);
    if (X1 <= X0 || Y1 <= Y0 || sw <= 0 || sh <= 0) return;
    const k = this._clip(), xa = Math.max(X0, k[0]), xb = Math.min(X1, k[2]), ya = Math.max(Y0, k[1]), yb = Math.min(Y1, k[3]);
    const fx = sw / (X1 - X0), fy = sh / (Y1 - Y0), pix = s.pix, b = this._b;
    for (let y = ya; y < yb; y++) {
      const v = Math.floor(sy + (y - Y0) * fy);
      if (v < 0 || v >= s.h) continue;
      const row = v * s.w, out = y * this._w;
      for (let x = xa; x < xb; x++) {
        const u = Math.floor(sx + (x - X0) * fx);
        if (u < 0 || u >= s.w) continue;
        const p = pix[row + u];
        if (p) b[out + x] = p;
      }
    }
  }
  save() { this._stack.push([this._fi, this._fv, this._si, this._sv, this._px, this._align, this._base, this._lw, this._sx, this._sy, this._tx, this._ty]); }
  restore() { const s = this._stack.pop(); if (s) [this._fi, this._fv, this._si, this._sv, this._px, this._align, this._base, this._lw, this._sx, this._sy, this._tx, this._ty] = s; }
  setTransform(a, b, c, d, e, f) {
    if (a && typeof a === 'object') ({ a, d, e, f } = a);
    this._sx = +a || 1; this._sy = +d || 1; this._tx = +e || 0; this._ty = +f || 0;
  }
  resetTransform() { this.setTransform(1, 0, 0, 1, 0, 0); }
  getTransform() { return { a: this._sx, b: 0, c: 0, d: this._sy, e: this._tx, f: this._ty }; }
  translate(x, y) { this._tx += +x * this._sx; this._ty += +y * this._sy; }
  scale(x, y) { this._sx *= +x; this._sy *= +y; }
  rotate() {}
  transform() {}
  clip() {}
  setLineDash() {}
  createLinearGradient() { const g = { _stops: [], addColorStop(_o, c) { this._stops.push(c); } }; return g; }
  createRadialGradient() { return this.createLinearGradient(); }
  createPattern() { return '#888'; }
  // Paths: points are stored transformed; fill is nonzero scanline.
  _T(x, y) { return [+x * this._sx + this._tx, +y * this._sy + this._ty]; }
  beginPath() { this._path = []; this._cur = null; }
  moveTo(x, y) { this._cur = [this._T(x, y)]; this._path.push(this._cur); }
  lineTo(x, y) { if (!this._cur) this.moveTo(x, y); else this._cur.push(this._T(x, y)); }
  closePath() { if (this._cur && this._cur.length) { this._cur.closed = true; this._cur = [this._cur[0]]; this._path.push(this._cur); } }
  rect(x, y, w, h) { this.moveTo(x, y); this.lineTo(+x + +w, y); this.lineTo(+x + +w, +y + +h); this.lineTo(x, +y + +h); this.closePath(); }
  ellipse(x, y, rx, ry, _rot, a0, a1, ccw) {
    let sweep = a1 - a0;
    if (!ccw && sweep < 0) sweep = sweep % (2 * Math.PI) + 2 * Math.PI;
    if (ccw && sweep > 0) sweep = sweep % (2 * Math.PI) - 2 * Math.PI;
    if (Math.abs(sweep) >= 2 * Math.PI) sweep = ccw ? -2 * Math.PI : 2 * Math.PI;
    const r = Math.max(rx, ry) * Math.max(Math.abs(this._sx), Math.abs(this._sy));
    const n = Math.max(8, Math.min(256, Math.ceil(Math.abs(sweep) * r / 2)));
    for (let i = 0; i <= n; i++) { const t = a0 + sweep * i / n; this.lineTo(+x + rx * Math.cos(t), +y + ry * Math.sin(t)); }
  }
  arc(x, y, r, a0, a1, ccw) { this.ellipse(x, y, r, r, 0, a0, a1, ccw); }
  arcTo(_x1, _y1, x2, y2) { this.lineTo(x2, y2); }
  quadraticCurveTo(cx, cy, x, y) { this.bezierCurveTo(cx, cy, cx, cy, x, y); }
  bezierCurveTo(c1x, c1y, c2x, c2y, x, y) {
    if (!this._cur) this.moveTo(c1x, c1y);
    const [p0x, p0y] = this._cur[this._cur.length - 1];
    const ox = (p0x - this._tx) / this._sx, oy = (p0y - this._ty) / this._sy;
    for (let i = 1; i <= 16; i++) {
      const t = i / 16, u = 1 - t;
      this.lineTo(u * u * u * ox + 3 * u * u * t * c1x + 3 * u * t * t * c2x + t * t * t * x,
                  u * u * u * oy + 3 * u * u * t * c1y + 3 * u * t * t * c2y + t * t * t * y);
    }
  }
  fill() {
    const edges = [];
    let minY = Infinity, maxY = -Infinity;
    for (const p of this._path) for (let i = 0; i < p.length; i++) {
      const a = p[i], b = p[(i + 1) % p.length];
      if (p.length < 2 || a[1] === b[1]) continue;
      edges.push(a[1] < b[1] ? [a[0], a[1], b[0], b[1], 1] : [b[0], b[1], a[0], a[1], -1]);
      minY = Math.min(minY, a[1], b[1]); maxY = Math.max(maxY, a[1], b[1]);
    }
    if (!edges.length) return;
    const k = this._clip(), c = this._fi;
    for (let y = Math.max(k[1], Math.floor(minY)); y < Math.min(k[3], Math.ceil(maxY)); y++) {
      const sy = y + 0.5, xs = [];
      for (const e of edges) if (sy >= e[1] && sy < e[3]) xs.push([e[0] + (sy - e[1]) * (e[2] - e[0]) / (e[3] - e[1]), e[4]]);
      xs.sort((p, q) => p[0] - q[0]);
      let wind = 0;
      for (let i = 0; i < xs.length - 1; i++) {
        wind += xs[i][1];
        if (wind) this._span(Math.ceil(xs[i][0] - 0.5), y, Math.ceil(xs[i + 1][0] - 0.5), y + 1, c);
      }
    }
  }
  stroke() {
    const l = Math.max(1, Math.round(this._lw * Math.abs(this._sx))), c = this._si;
    for (const p of this._path) {
      const n = p.closed ? p.length : p.length - 1;
      for (let i = 0; i < n; i++) this._line(p[i], p[(i + 1) % p.length], l, c);
    }
  }
  _line(a, b, l, c) {
    let x0 = Math.round(a[0]), y0 = Math.round(a[1]);
    const x1 = Math.round(b[0]), y1 = Math.round(b[1]), dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0);
    const sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, o = (l - 1) >> 1;
    let err = dx + dy;
    for (let guard = 0; guard < 4096; guard++) {
      if (l === 1) this._put(x0, y0, c); else this._span(x0 - o, y0 - o, x0 - o + l, y0 - o + l, c);
      if (x0 === x1 && y0 === y1) break;
      const e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }
  createImageData(w, h) { return { width: I(w), height: I(h), data: new Uint8ClampedArray(I(w) * I(h) * 4) }; }
  getImageData(x, y, w, h) {
    const img = this.createImageData(w, h);
    x = I(x); y = I(y);
    for (let j = 0; j < img.height; j++) for (let i = 0; i < img.width; i++) {
      const xx = x + i, yy = y + j, o = (j * img.width + i) * 4;
      if (xx < 0 || yy < 0 || xx >= this._w || yy >= this._h) continue;
      const p = M.palette[this._b[yy * this._w + xx]];
      img.data[o] = p[0]; img.data[o + 1] = p[1]; img.data[o + 2] = p[2]; img.data[o + 3] = 255;
    }
    return img;
  }
  putImageData(img, x, y) {
    const cache = new Map();
    x = I(x); y = I(y);
    for (let j = 0; j < img.height; j++) for (let i = 0; i < img.width; i++) {
      const o = (j * img.width + i) * 4, d = img.data;
      let v = 0;
      if (d[o + 3] >= 16) {
        const key = (d[o] << 16) | (d[o + 1] << 8) | d[o + 2];
        v = cache.get(key);
        if (v === undefined) { v = key ? nearest([d[o], d[o + 1], d[o + 2]]) : 0; cache.set(key, v); }
      }
      this._put(x + i, y + j, v);
    }
  }
}

function makeCanvas(w, h, screen) {
  const buf = screen ? M.fb : new Uint8Array(w * h);
  const ctx = new Ctx(buf, w, h, screen);
  const el = {
    _ctx: ctx, width: w, height: h, style: {}, tabIndex: 0,
    getContext: () => ctx,
    getBoundingClientRect: () => ({ left: 0, top: 0, x: 0, y: 0, right: w, bottom: h, width: w, height: h }),
    addEventListener: (t, f) => M.prog && M.prog.listen(t, f),
    removeEventListener: (t, f) => M.prog && M.prog.unlisten(t, f),
    focus() {}, blur() {}, setAttribute() {}, getAttribute() { return null; },
  };
  ctx.canvas = el;
  return el;
}

class SprImage {
  constructor() { this.width = 0; this.height = 0; this.naturalWidth = 0; this.naturalHeight = 0; this.complete = false; this.onload = null; this.onerror = null; this._s = null; this._src = ''; }
  get src() { return this._src; }
  set src(v) {
    this._src = String(v);
    const m = /^jmr:spr:(\d+)$/.exec(this._src), s = m && M.sprites[+m[1]];
    if (s) { this._s = s; this.width = this.naturalWidth = s.w; this.height = this.naturalHeight = s.h; this.complete = true; }
    const prog = M.prog;
    // The machine runs Image.onload after the current script.
    setTimeout(() => { const f = s ? this.onload : this.onerror; if (f && prog === M.prog) prog.call(f, [{ type: s ? 'load' : 'error' }]); }, 0);
  }
  addEventListener(t, f) { if (t === 'load') this.onload = f; else if (t === 'error') this.onerror = f; }
  removeEventListener() {}
  decode() { return Promise.resolve(); }
}

// ---------------------------------------------------------------- programs
// Each program gets a fresh same-origin iframe as its global scope, so its
// globals, timers and listeners all disappear when it stops.
class Program {
  constructor(name, code) {
    this.name = name; this.code = code; this.raf = []; this.rafId = 0;
    this.listeners = new Map(); this.halted = false;
  }
  listen(t, f) { if (typeof f !== 'function') return; const l = this.listeners.get(t) || []; if (!l.includes(f)) l.push(f); this.listeners.set(t, l); }
  unlisten(t, f) { const l = this.listeners.get(t); if (l) { const i = l.indexOf(f); if (i >= 0) l.splice(i, 1); } }
  call(fn, args) {
    if (this.halted || M.prog !== this) return;
    try { fn.apply(undefined, args); } catch (e) { fault(this, e); }
  }
  dispatch(type, event) { for (const f of (this.listeners.get(type) || []).slice()) this.call(f, [event]); }
  start() {
    const frame = document.createElement('iframe');
    frame.style.display = 'none';
    document.body.appendChild(frame);
    this.frame = frame;
    const win = frame.contentWindow, doc = win.document, self = this;
    const canvas = makeCanvas(W, H, true);
    this.ctx = canvas._ctx;
    const natives = { stgRead, stgWrite, toolbox, strByte, srcLen, srcByte, srcWrite, srcSetLen, sysDocument,
      fsList, fsRead, fsWrite, fsRemove, fsRename, sound, stringFromBytes, runtimeFault,
      sysRun: (off, how) => sysRun(self, off, how),
      joy: () => M.keyBits, getJoy: () => M.keyBits, joyX: () => 128, joyY: () => 128, joyButtons: () => 0,
      cdone: (s, n) => cdone(self, s, n), artWrite2: () => undefined,
      // machine.py _natives: key polls read the same joy bits as joy().
      keyUp: () => M.keyBits & 1 ? 1 : 0, keyDown: () => M.keyBits & 2 ? 1 : 0, keyLeft: () => M.keyBits & 4 ? 1 : 0,
      keyRight: () => M.keyBits & 8 ? 1 : 0, keyFire: () => M.keyBits & 16 ? 1 : 0,
      // Legacy raw indexed drawing, independent of Canvas state.
      fillRect: (x, y, w, h, c = 1) => this.ctx._span(I(x), I(y), I(x) + I(w), I(y) + I(h), I(c) & 255),
      clear: (c = 0) => this.ctx._span(0, 0, W, H, I(c) & 255),
      setFillStyle: idx => { this.ctx._fi = I(idx) & 255; },
      swapBuffers: () => undefined, startLoop: () => undefined };
    Object.assign(win, natives);
    const st = win.setTimeout.bind(win), si = win.setInterval.bind(win);
    win.setTimeout = (fn, ms, ...a) => st(() => typeof fn === 'function' && self.call(fn, a), ms);
    win.setInterval = (fn, ms, ...a) => si(() => typeof fn === 'function' && self.call(fn, a), ms);
    win.requestAnimationFrame = fn => { const id = ++self.rafId; self.raf.push({ id, fn }); return id; };
    win.cancelAnimationFrame = id => { self.raf = self.raf.filter(r => r.id !== id); };
    win.addEventListener = (t, f) => self.listen(t, f);
    win.removeEventListener = (t, f) => self.unlisten(t, f);
    // Synthetic events go to the program's listeners (DONKEY boots with Enter).
    win.dispatchEvent = ev => { if (ev && ev.type) self.dispatch(String(ev.type), ev); return true; };
    win.Image = SprImage;
    win.onerror = (_m, _s, _l, _c, err) => { fault(self, err || new Error(String(_m))); return true; };
    doc.getElementById = () => canvas;
    doc.querySelector = sel => /canvas|#/.test(String(sel)) ? canvas : null;
    doc.createElement = tag => String(tag).toLowerCase() === 'canvas' ? makeCanvas(W, H, false) : { style: {}, appendChild() {}, addEventListener() {}, setAttribute() {} };
    doc.addEventListener = (t, f) => self.listen(t, f);
    doc.removeEventListener = (t, f) => self.unlisten(t, f);
    doc.dispatchEvent = win.dispatchEvent;
    try { win.eval(`${this.code}\n//# sourceURL=jmr/${this.name}`); } catch (e) { fault(this, e); }
  }
  stop() { this.halted = true; if (this.frame) this.frame.remove(); this.frame = null; }
}

// tools/compile_js.py: every <script> except data-host="chrome", joined
// with ';'. A resident-v2 client gets the Toolbox library in front.
function programCode(text, name) {
  if (/\.JS$/i.test(name)) return text;
  const bodies = [];
  for (const m of text.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/gi)) {
    if (/data-host\s*=\s*["']chrome["']/i.test(m[1])) continue;
    bodies.push(m[2]);
  }
  const src = bodies.join(';\n');
  return text.slice(0, 1024 + MARKER.length).includes(MARKER) ? `${M.library};\n${src}` : src;
}

function sysRun(prog, off, how) {
  if (prog.halted || M.prog !== prog) return 0;
  M.clip = [0, 0, W, H];
  M.request = { name: arenaName(off), how: I(how) };
  prog.halted = true;
  return 0;
}

// machine.py _finish_program_op / _continue_program: a program ends by
// asking for file work and the next program. Arena byte 64 selects it:
// 0-4 are the compiler stages (not run by this preview), then Editor,
// Reader, Compile, Finder. SOURCE and the arena carry over.
const CHAIN = ['', '', '', '', '', 'EDITOR.HTM', 'READ.HTM', 'COMPILE.HTM', 'FINDER.HTM'];
function cdone(prog, code, outLen) {
  if (prog.halted || M.prog !== prog) return;
  code = I(code) & 255;
  if (code === 0x86) {
    let name = '';
    for (let i = 0; i < 16 && M.arena[i] && M.arena[i] !== 32; i++) name += String.fromCharCode(M.arena[i]);
    if (name) { M.sourceName = name; code = 0x81; }
  }
  let next = '';
  if (code === 0x81 && M.arena[64] <= 8) {
    const name = fatName(M.sourceName);
    if (name) disk.write(name, M.src.slice(0, M.srcLen));
    M.arena[65] = 1;
    next = CHAIN[M.arena[64]];
  } else if (code === 0x80) next = CHAIN[M.arena[64]] || '';
  // A quit is 0 with no output; anything else is compiler output or a stage.
  if (!next && !(code === 0x00 && !I(outLen))) status(`${prog.name}: the compiler chain does not run in this preview`, true);
  prog.halted = true;
  M.clip = [0, 0, W, H];
  M.request = next && next !== 'FINDER.HTM' ? { cont: next } : { name: '', how: 8 };
}

function fault(prog, e) {
  if (prog.halted) return;
  prog.halted = true;
  const m = /software fault (\d+)/.exec(String(e && e.message));
  console.error(`${prog.name}:`, e);
  status(`${prog.name} stopped: ${e && e.message ? e.message : e}`, true);
  const finder = M.role === 9;
  if (finder && M.finderRetry) return;
  M.finderRetry = finder;
  if (finder) M.parked = null;
  M.request = { name: '', how: 8, exit: 0x80 | (m ? +m[1] : 5) };
}

function stopProgram() {
  if (M.prog) M.prog.stop();
  M.prog = null;
}

async function programText(name) {
  const f = disk.find(name);
  if (f) return utf8.decode(f.data);
  const stem = name.replace(/\.[^.]*$/, '');
  const r = await fetch(`../storage/${stem}.HTML`);
  return r.ok ? r.text() : null;
}
async function programArt(stem) {
  let data = disk.find(`${stem}.ART`)?.data;
  if (!data) { const r = await fetch(`../storage/${stem}.ARTX`); if (r.ok) data = new Uint8Array(await r.arrayBuffer()); }
  if (!data || data.length < 12 || latin.decode(data.subarray(0, 4)) !== 'ARTX') return null;
  const dv = new DataView(data.buffer, data.byteOffset, data.byteLength), n = dv.getUint16(6, true);
  const descs = [];
  let o = 8;
  for (let i = 0; i < n; i++, o += 8) descs.push([dv.getUint16(o, true), dv.getUint16(o + 2, true), dv.getUint32(o + 4, true)]);
  const plen = dv.getUint32(o, true), payload = data.subarray(o + 4, o + 4 + plen);
  const palette = Array.from({ length: 256 }, (_, i) => [payload[i * 3], payload[i * 3 + 1], payload[i * 3 + 2]]);
  return { palette, sprites: descs.map(([w, h, s]) => ({ w, h, pix: payload.subarray(s, s + w * h) })) };
}

async function runProgram(name) {
  const text = await programText(name);
  if (text == null) return false;
  const art = await programArt(name.replace(/\.[^.]*$/, ''));
  M.clip = [0, 0, W, H]; M.role = 0; M.windowDirty = 0;
  M.sprites = art ? art.sprites : [];
  if (art) setPalette(art.palette, false, 256); else setPalette(PAL8, true, 8);
  const prog = new Program(name, programCode(text, name));
  M.prog = prog;
  status(`Running ${name}`);
  prog.start();
  return true;
}

async function startFinder() {
  if (M.parked) {
    // backend._resume_finder: arena back, drop the half-finished click and
    // the icon cache flags, clear the glass, then a fresh Finder resumes.
    M.arena.set(M.parked, 0); M.parked = null;
    M.arena.fill(0, 48000, 48256); M.arena[16392] = 0; M.arena[16395] = 0;
    M.fb.fill(0); M.arena[16385] = 1;
  } else {
    M.arena[16384] = 0; M.arena[16600] = 0;
  }
  if (!await runProgram('FINDER.HTM')) status('FINDER.HTM is missing from the card and storage/', true);
}

// A cdone handoff: the Finder stays parked, SOURCE and the arena carry over.
async function continueProgram(name) {
  M.exitStatus = 0;
  stopProgram();
  if (!await runProgram(name)) { M.exitStatus = 9; return startFinder(); }
}

// runtime/backend.py _finder_launch.
async function launch(name, how, exit) {
  M.exitStatus = exit || 0;
  const fromFinder = M.role === 9;
  if (how === 8 || !name) { if (fromFinder) M.parked = null; }
  else if (fromFinder) { M.parked = M.arena.slice(0, CSCR); M.finderRetry = false; }
  stopProgram();
  if (how === 8 || !name || how === 4) return startFinder();
  if (how >= 5 && how <= 7) [how, name] = { 5: [0, 'NOTE.HTM'], 6: [2, 'HELP.MD'], 7: [0, 'UTILITY.HTM'] }[how];
  M.unnamed = false;
  let doc = disk.find(name)?.data;
  if (!doc && /\.HTML?$/i.test(name)) { const t = await programText(name); if (t != null) doc = enc.encode(t); }
  if (!doc) { M.exitStatus = 6; return startFinder(); }
  setSource(doc, name.toUpperCase());
  const suffix = (name.split('.')[1] || '').toUpperCase();
  let prog = name.toUpperCase();
  if (how === 1) prog = 'EDITOR.HTM';
  else if (how === 2 || (how === 0 && !['HTM', 'HTML', 'JS'].includes(suffix))) prog = 'READ.HTM';
  else if (how === 3) prog = 'COMPILE.HTM';
  if (!await runProgram(prog)) { M.exitStatus = 9; return startFinder(); }
}

// ---------------------------------------------------------------- input + loop
const screen = document.getElementById('screen');
const out = screen.getContext('2d');
const image = out.createImageData(W, H);
const pixels = new Uint32Array(image.data.buffer);
const statusLine = document.getElementById('status');
function status(text, error) { statusLine.textContent = text; statusLine.classList.toggle('error', !!error); }

// web/app.js codeFor: the same keyCodes the other simulators deliver.
function codeFor(e) {
  const codes = { Backspace: 8, Tab: 9, Enter: 13, Shift: 16, Control: 17, Alt: 18, Escape: 27, ' ': 32, End: 35, Home: 36,
    ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39, ArrowDown: 40, Delete: 46, Meta: 91 };
  const punctuation = { Semicolon: 186, Equal: 187, Comma: 188, Minus: 189, Period: 190, Slash: 191, Backquote: 192,
    BracketLeft: 219, Backslash: 220, BracketRight: 221, Quote: 222, NumpadDecimal: 190 };
  if (codes[e.key]) return codes[e.key];
  if (punctuation[e.code]) return punctuation[e.code];
  if (/^F(?:[1-9]|1[0-2])$/.test(e.key)) return 111 + Number(e.key.slice(1));
  if (/^Key[A-Z]$/.test(e.code)) return e.code.charCodeAt(3);
  if (/^Digit[0-9]$/.test(e.code)) return e.code.charCodeAt(5);
  if (e.key.length === 1 && e.key.charCodeAt(0) < 128) return e.key.toUpperCase().charCodeAt(0);
  return 0;
}
// input_engine.py JOY_* bits for joy(): arrows and space.
const JOY = { 38: 1, 40: 2, 37: 4, 39: 8, 32: 16 };
function sendKey(type, code, key) {
  const p = M.prog;
  if (JOY[code]) M.keyBits = type === 'keydown' ? M.keyBits | JOY[code] : M.keyBits & ~JOY[code];
  if (!p || p.halted) return;
  const charCode = type === 'keydown' && key.length === 1 && key.charCodeAt(0) >= 32 && key.charCodeAt(0) < 127 ? key.charCodeAt(0) : 0;
  p.dispatch(type, { type, key, code: key, keyCode: code, which: code, charCode, preventDefault() {}, stopPropagation() {} });
}
document.addEventListener('keydown', e => {
  const code = codeFor(e), role = M.role;
  if (!code || (e.key === 'Tab' && role !== 1 && role !== 5)) return;
  if (e.ctrlKey || e.metaKey) {
    const shortcut = { a: 142, c: 139, x: 138, z: 137 }[e.key.toLowerCase()];
    if (role === 1 && shortcut) { e.preventDefault(); if (!e.repeat) { sendKey('keydown', shortcut, ''); sendKey('keyup', shortcut, ''); } }
    if (e.key.length === 1) return;
  }
  e.preventDefault();
  if (e.repeat) return;
  // Esc is the machine's BREAK unless the program asked for it as a key.
  if (code === 27 && !(M.windowDirty & 128) && M.prog && !M.prog.halted) { M.prog.halted = true; M.request = { name: '', how: 8 }; return; }
  sendKey('keydown', code, e.key);
});
document.addEventListener('keyup', e => {
  const code = codeFor(e);
  if (!code) return;
  e.preventDefault();
  sendKey('keyup', code, e.key);
});

let mouseX = 320, mouseY = 240, mouseButtons = 0;
function mouseEvent(type, x, y, buttons, button, mx = 0, my = 0) {
  const p = M.prog;
  if (!p || p.halted) return;
  p.dispatch(type, { type, clientX: x, clientY: y, offsetX: x, offsetY: y, x, y, buttons, button,
    movementX: mx, movementY: my, preventDefault() {}, stopPropagation() {} });
}
// input_engine.py set_mouse: move first, then button edges, click after a left release.
function pointer(e) {
  const r = screen.getBoundingClientRect();
  const x = Math.max(0, Math.min(639, Math.floor((e.clientX - r.left) * W / r.width)));
  const y = Math.max(0, Math.min(479, Math.floor((e.clientY - r.top) * H / r.height)));
  const buttons = e.buttons & 7, old = mouseButtons;
  if (systemPointer(x, y, buttons)) { mouseX = x; mouseY = y; mouseButtons = buttons; return; }
  if (x !== mouseX || y !== mouseY) mouseEvent('mousemove', x, y, old, 0, x - mouseX, y - mouseY);
  for (const [mask, button] of [[1, 0], [2, 2], [4, 1]]) {
    if (!((buttons ^ old) & mask)) continue;
    const down = !!(buttons & mask);
    mouseEvent(down ? 'mousedown' : 'mouseup', x, y, buttons, button);
    if (!down && button === 0) mouseEvent('click', x, y, buttons, 0);
  }
  mouseX = x; mouseY = y; mouseButtons = buttons;
}

// The system area left of x=30 on the menu bar belongs to the machine, not
// the Toolbox (functional_model/system_menu.py): the Enterprise logo and its
// menu. About sends key 254 to the program, which opens its own About box.
// The Finder's menu also launches Note, Help and Utility. The on-screen
// Keyboard item is not in this preview.
const SHIP_ROWS = [0xfffc0c0, 0xfffdffe, 0x1c3fff, 0xe7c40, 0x3f800, 0x1ffc00, 0xffc00, 0x1f800];
const SM = { open: false, row: -1, buttons: 0, drag: false };
const smLabels = () => M.role === 9 ? ['About', 'Note', 'Help', 'Utility'] : ['About'];
function systemPointer(x, y, buttons) {
  const down = buttons & 1 && !(SM.buttons & 1), up = SM.buttons & 1 && !(buttons & 1);
  const ship = x < 30 && y < 22, labels = smLabels(), row = Math.floor((y - 26) / 21);
  SM.buttons = buttons;
  SM.row = SM.open && x < 190 && row >= 0 && row < labels.length ? row : -1;
  // A drag that started in the program stays the program's until release.
  if (SM.drag) { if (up) SM.drag = false; return false; }
  if (!SM.open && !ship) { if (down) SM.drag = true; return false; }
  if (up && SM.open) {
    if (x < 190 && row >= 0 && row < labels.length) { SM.open = false; SM.row = -1; systemPick(labels[row]); }
    else if (!ship) SM.open = false;
  }
  if (down && ship) SM.open = !SM.open;
  return true;
}
function systemPick(name) {
  if (name === 'About') { sendKey('keydown', 254, ''); sendKey('keyup', 254, ''); return; }
  if (M.prog) M.prog.halted = true;
  M.request = { Note: { name: 'NOTE.HTM', how: 0 }, Help: { name: 'HELP.MD', how: 2 }, Utility: { name: 'UTILITY.HTM', how: 0 } }[name];
}
// SYSTEM.SYS UI font (the Toolbox's tbText font): advances at 20624,
// 16x16 MSB-first glyphs at 20736.
function systemText(x, y, text, color) {
  const sys = M.sys;
  if (!sys) return;
  for (const ch of text) {
    let g = ch.charCodeAt(0) - 32;
    if (g < 0 || g > 94) g = 31;
    for (let r = 0; r < 16; r++) {
      const bits = (sys[20736 + g * 32 + r * 2] << 8) | sys[20736 + g * 32 + r * 2 + 1];
      for (let c = 0; c < 16; c++) if (bits & (0x8000 >> c)) pixels[(y + r) * W + x + c] = color;
    }
    x += sys[20624 + g];
  }
}
function drawSystem() {
  const white = 0xffffffff, black = 0xff000000, labels = smLabels();
  for (let y = 0; y < 22; y++) for (let x = 0; x < 30; x++) pixels[y * W + x] = y === 21 ? black : white;
  for (let sy = 0; sy < 8; sy++) for (let sx = 0; sx < 28; sx++)
    if (SHIP_ROWS[sy] & (1 << (27 - sx))) pixels[(7 + sy) * W + 1 + sx] = black;
  if (!SM.open) return;
  const h = 28 + labels.length * 21;
  for (let y = 22; y < 22 + h; y++) for (let x = 0; x < 190; x++)
    pixels[y * W + x] = x === 0 || x === 189 || y === 22 || y === 21 + h ? black : white;
  if (SM.row >= 0) for (let y = 24 + SM.row * 21; y < 44 + SM.row * 21; y++) pixels.fill(black, y * W + 1, y * W + 189);
  labels.forEach((label, i) => systemText(8, 26 + i * 21, label, i === SM.row ? white : black));
}
for (const t of ['pointerdown', 'pointermove', 'pointerup']) screen.addEventListener(t, e => { e.preventDefault(); if (t === 'pointerdown') try { screen.setPointerCapture(e.pointerId); } catch (_) {} pointer(e); });
screen.addEventListener('contextmenu', e => e.preventDefault());

const soundButton = document.getElementById('sound');
soundButton.addEventListener('click', async () => {
  if (!audio) {
    audio = new AudioContext();
    await audio.audioWorklet.addModule('./psg.js');
    psg = new AudioWorkletNode(audio, 'jmr-psg', { numberOfInputs: 0, outputChannelCount: [1] });
    psg.connect(audio.destination);
  } else if (audio.state === 'running') { await audio.suspend(); psg.port.postMessage({ clear: true }); }
  else await audio.resume();
  soundButton.textContent = audio.state === 'running' ? 'Sound on' : 'Sound off';
});

let last = 0, frames = 0, second = 0;
function loop(t) {
  requestAnimationFrame(loop);
  if (M.request && !M.loading) {
    const r = M.request;
    M.request = null; M.loading = true;
    (r.cont ? continueProgram(r.cont) : launch(r.name, r.how, r.exit)).catch(e => status(String(e), true)).finally(() => { M.loading = false; });
  }
  // The machine paints at 60 Hz; faster displays wait.
  if (t - last < 15) return;
  last = t;
  const p = M.prog;
  if (p && !p.halted) {
    const q = p.raf;
    p.raf = [];
    for (const r of q) p.call(r.fn, [t]);
  }
  flushSound();
  const lut = M.lut, fb = M.fb;
  for (let i = 0; i < fb.length; i++) pixels[i] = lut[fb[i]];
  drawSystem();
  out.putImageData(image, 0, 0);
  frames++;
  if (t - second >= 1000) {
    if (M.prog && !statusLine.classList.contains('error')) status(`${M.prog.name} · ${frames} fps`);
    frames = 0; second = t;
  }
}

async function boot() {
  const params = new URLSearchParams(location.search);
  const cardUrl = params.get('card') || '../card.img';
  status(`Loading ${cardUrl}…`);
  const [card, ...library] = await Promise.all([
    fetch(cardUrl).then(r => { if (!r.ok) throw new Error(`${cardUrl}: ${r.status}`); return r.arrayBuffer(); }),
    ...LIBRARY.map(n => fetch(`../resources/toolbox/${n}`).then(r => { if (!r.ok) throw new Error(`${n}: ${r.status}`); return r.text(); })),
  ]);
  disk.files = readCard(card);
  M.library = library.join('\n');
  const sys = disk.find('SYSTEM.SYS');
  M.sys = sys && sys.data.length > 16 ? sys.data.subarray(16) : null;
  setPalette(PAL8, true, 8);
  requestAnimationFrame(loop);
  M.loading = true;
  try { await startFinder(); } finally { M.loading = false; }
  screen.focus();
}
boot().catch(e => { console.error(e); status(`Boot failed: ${e.message}`, true); });
// DevTools: (await import('./native.js')).M.request = {name: 'MACPAINT.HTM', how: 0}
export { M };
