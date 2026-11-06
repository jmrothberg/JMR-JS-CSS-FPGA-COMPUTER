"""Version-one Toolbox primitive contract shared by Python and the RTL tests.

The native JavaScript VM remains the CPU. This module models its bounded
100 MHz bulk-service peripheral, not a replacement interpreter.
"""
from .jsb_format import CSTG_WORDS

VERSION = 0x00010FFF
DESCRIPTOR_BYTES = 64


def execute(machine, op, a, b, c):
    def valid(p, n):
        return 0 <= p <= CSTG_WORDS and 0 <= n <= CSTG_WORDS - p

    def read(p):
        return int(machine._nat_stg_read(p))

    def write(p, v):
        machine._nat_stg_write(p, v)

    if op == 0:
        return VERSION
    if op == 12:
        a, b, c = a & 0xffffffff, b & 0xffffffff, c & 0xffffffff
        if c == 1 and a == 0 and b == 0:
            machine.canvas.reset_scissor()
        elif c == 0:
            x, y = a & 65535, a >> 16
            machine.canvas.set_scissor(x-65536 if x & 32768 else x,
                                       y-65536 if y & 32768 else y,
                                       b & 65535, b >> 16)
        else:
            return -1
        return 1
    if op in (8, 9, 10, 11):
        # Native integer operands carry their low32 bits, including negative
        # values used to encode unsigned data. Addresses still require bounds.
        b, c = b & 0xffffffff, c & 0xffffffff
        n = 8 if op == 10 else 2 if op == 11 else 4
        if not valid(a, n) or (op != 10 and c != 0) or (op == 8 and b != 0):
            return -1
        if op == 8:
            return sum(read(a+i) << (8*i) for i in range(4))
        value = b | ((c << 32) if op == 10 else 0)
        for i in range(n):
            write(a+i, (value >> (8*i)) & 255)
        return n
    if op in (6, 7):
        if c != 0 or not valid(a, 64) or not valid(b, 64):
            return -1
        # Snapshot both descriptors before any writes (including self-overlap).
        def surface(pointer):
            d = bytes(read(pointer+i) for i in range(64))
            def u(i): return int.from_bytes(d[i:i+2], 'little')
            def s(i): return int.from_bytes(d[i:i+2], 'little', signed=True)
            base = int.from_bytes(d[4:8], 'little')
            stride, width, height = u(8), u(10), u(12)
            screen = d[2] == 2
            if (d[:2] != bytes([1, 8]) or d[2] not in (0, 2) or d[3] != 1
                    or not width or not height or stride < width
                    or (screen and (base, stride, width, height) != (0, 640, 640, 480))
                    or (not screen and not valid(base, stride*height))):
                return None
            return dict(descriptor=d, base=base, stride=stride, width=width, height=height,
                        screen=screen, sx=u(14), sy=u(16), w=u(18), h=u(20),
                        dx=s(22), dy=s(24), cx=s(26), cy=s(28), cw=u(30), ch=u(32))
        src, dst = surface(a), surface(b)
        if src is None or dst is None:
            return -1
        w, h = src['w'], src['h']
        if (w != dst['w'] or h != dst['h'] or src['sx']+w > src['width']
                or src['sy']+h > src['height']):
            return -1
        if (not src['screen'] and not dst['screen']
                and src['base'] < dst['base']+dst['stride']*dst['height']
                and dst['base'] < src['base']+src['stride']*src['height']
                and src['stride'] != dst['stride']):
            return -1
        # Independent reference: snapshot source, rather than model RTL order.
        def pixel(s, x, y):
            address = s['base']+y*s['stride']+x
            return machine.canvas.back[address] if s['screen'] else read(address)
        if op == 7:
            d = src['descriptor']
            mode, flags = d[36:38]
            mask_base = int.from_bytes(d[48:52], 'little')
            mask_stride = int.from_bytes(d[52:54], 'little')
            mask_extent = mask_stride*h
            if mode > 5 or flags > 3:
                return -1
            if flags & 1:
                if (mask_stride < (w+7)//8 or not valid(mask_base, mask_extent)
                        or (not dst['screen']
                            and not (mask_base+mask_extent <= dst['base']
                                     or dst['base']+dst['stride']*dst['height'] <= mask_base))):
                    return -1
            # Match the shared hardware traversal, including aliased surfaces.
            # Descriptors are already latched; mask storage cannot alias dst.
            reverse = (src['screen'] == dst['screen']
                       and dst['base']+dst['dy']*dst['stride']+dst['dx']
                       > src['base']+src['sy']*src['stride']+src['sx'])
            rows = range(h-1, -1, -1) if reverse else range(h)
            columns = range(w-1, -1, -1) if reverse else range(w)
            for y in rows:
                for x in columns:
                    xx, yy = dst['dx']+x, dst['dy']+y
                    if not (0 <= xx < dst['width'] and 0 <= yy < dst['height']
                            and dst['cx'] <= xx < dst['cx']+dst['cw']
                            and dst['cy'] <= yy < dst['cy']+dst['ch']):
                        continue
                    if flags & 1 and not read(mask_base+y*mask_stride+x//8) & (128 >> (x%8)):
                        continue
                    if mode == 5:
                        value = pixel(dst, xx, yy) ^ 255
                    else:
                        value = (d[34] if d[40+yy%8] & (128 >> (xx%8)) else d[35]) if flags & 2 else pixel(src, src['sx']+x, src['sy']+y)
                        if mode:
                            previous = pixel(dst, xx, yy)
                            value = (previous | value if mode == 1 else
                                     previous ^ value if mode == 2 else
                                     previous & (value ^ 255) if mode == 3 else
                                     previous & value)
                    address = dst['base']+yy*dst['stride']+xx
                    if dst['screen']:
                        machine.canvas.back[address] = value
                    else:
                        write(address, value)
            return w*h
        data = [[pixel(src, src['sx']+x, src['sy']+y) for x in range(w)] for y in range(h)]
        for y in range(h):
            for x in range(w):
                xx, yy = dst['dx']+x, dst['dy']+y
                if (0 <= xx < dst['width'] and 0 <= yy < dst['height']
                        and dst['cx'] <= xx < dst['cx']+dst['cw']
                        and dst['cy'] <= yy < dst['cy']+dst['ch']):
                    address = dst['base']+yy*dst['stride']+xx
                    if dst['screen']:
                        machine.canvas.back[address] = data[y][x]
                    else:
                        write(address, data[y][x])
        return w*h
    if op == 1:
        if not valid(a, c) or not valid(b, c):
            return -1
        # Snapshot semantics are memmove, including overlap and arena seams.
        data = bytes(read(a + i) for i in range(c))
        for i, value in enumerate(data):
            write(b + i, value)
        return c
    if op == 2:
        if not valid(a, c):
            return -1
        for i in range(c):
            write(a + i, b & 255)
        return c
    if op == 5:
        if not hasattr(machine, "_toolbox_sys_data"):
            from tools.build_system_resources import unpack
            try:
                machine._toolbox_sys_data = bytes(unpack(machine.storage.load_bytes("SYSTEM.SYS")))
            except (FileNotFoundError, ValueError):
                machine._toolbox_sys_data = None
        data = machine._toolbox_sys_data
        if data is None or not 0 <= a <= len(data) or not 0 <= c <= len(data)-a or not valid(b,c):
            return -1
        for i,value in enumerate(data[a:a+c]):
            write(b+i,value)
        return c
    if op not in (3, 4) or not valid(a, DESCRIPTOR_BYTES):
        return -1
    d = bytes(read(a + i) for i in range(DESCRIPTOR_BYTES))

    def u16(i):
        return int.from_bytes(d[i:i + 2], "little")

    def s16(i):
        return int.from_bytes(d[i:i + 2], "little", signed=True)

    fmt, flags, scale = d[1:4]
    base = int.from_bytes(d[4:8], "little")
    stride, sw, sh = u16(8), u16(10), u16(12)
    sx, sy, w, h = u16(14), u16(16), u16(18), u16(20)
    dx, dy, cx, cy = s16(22), s16(24), s16(26), s16(28)
    cw, ch, fg, bg = u16(30), u16(32), d[34], d[35]
    if (d[0] != 1 or fmt not in (1, 4, 8) or scale not in (1, 2, 4, 8)
            or not sw or not sh or not valid(base, stride * sh)
            or stride < (sw * fmt + 7) // 8 or sx + w > sw or sy + h > sh):
        return -1
    for y in range(h):
        for x in range(w):
            xx, yy = sx + x, sy + y
            address = base + yy * stride + xx * fmt // 8
            byte = read(address)
            shift = 7 - xx % 8 if fmt == 1 else (0 if xx % 2 else 4) if fmt == 4 else 0
            mask = (1 << fmt) - 1
            value = (byte >> shift) & mask
            if op == 4:
                ink = fg if d[40 + yy % 8] & (128 >> (xx % 8)) else bg
                write(address, (byte & ~(mask << shift)) | ((ink & mask) << shift))
            elif not (flags & 1 and value == 0):
                color = (fg if value else bg) if fmt == 1 else d[48 + value] if fmt == 4 else value
                for zy in range(scale):
                    for zx in range(scale):
                        px, py = dx + x * scale + zx, dy + y * scale + zy
                        if 0 <= px < 640 and 0 <= py < 480 and cx <= px < cx + cw and cy <= py < cy + ch:
                            machine.canvas.back[py * 640 + px] = color
    return w * h
