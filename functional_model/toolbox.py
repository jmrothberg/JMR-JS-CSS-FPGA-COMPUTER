"""Version-one Toolbox primitive contract shared by Python and the RTL tests.

The native JavaScript VM remains the CPU. This module models its bounded
100 MHz bulk-service peripheral, not a replacement interpreter.

Operation 6 is CopyBits (`copy_bits` below). Operations 1–5 are unchanged.
"""
from .jsb_format import CSTG_WORDS

VERSION = 0x0001003F
DESCRIPTOR_BYTES = 64


def _u16(buf, i):
    return int.from_bytes(buf[i:i + 2], "little")


def _s16(buf, i):
    return int.from_bytes(buf[i:i + 2], "little", signed=True)


def copy_bits(machine, src_at, dst_at, mode):
    """Copy one rectangle between the glass and an 8-bit arena picture.

    `toolbox(6, srcDescriptor, dstDescriptor, 0)`. Flag byte 2 means that
    side is the drawing framebuffer (640×480 palette indices). Flag byte 0
    is an arena surface. Both rectangles are the same size. Mode 0 is
    srcCopy. The source is snapshotted first, so overlap is safe. The
    result is the pixel count, or -1.
    """
    if mode != 0:
        return -1

    def valid(p, n):
        return 0 <= p <= CSTG_WORDS and 0 <= n <= CSTG_WORDS - p

    def read(p):
        return int(machine._nat_stg_read(p))

    def write(p, v):
        machine._nat_stg_write(p, v)

    if not valid(src_at, 64) or not valid(dst_at, 64):
        return -1

    def surface(pointer):
        raw = bytes(read(pointer + i) for i in range(64))
        base = int.from_bytes(raw[4:8], "little")
        stride, width, height = _u16(raw, 8), _u16(raw, 10), _u16(raw, 12)
        screen = raw[2] == 2
        if (raw[:2] != bytes([1, 8]) or raw[2] not in (0, 2) or raw[3] != 1
                or not width or not height or stride < width
                or (screen and (base, stride, width, height) != (0, 640, 640, 480))
                or (not screen and not valid(base, stride * height))):
            return None
        return {
            "base": base, "stride": stride, "width": width, "height": height,
            "screen": screen, "sx": _u16(raw, 14), "sy": _u16(raw, 16),
            "w": _u16(raw, 18), "h": _u16(raw, 20),
            "dx": _s16(raw, 22), "dy": _s16(raw, 24),
            "cx": _s16(raw, 26), "cy": _s16(raw, 28),
            "cw": _u16(raw, 30), "ch": _u16(raw, 32),
        }

    src, dst = surface(src_at), surface(dst_at)
    if src is None or dst is None:
        return -1
    w, h = src["w"], src["h"]
    if (w != dst["w"] or h != dst["h"] or src["sx"] + w > src["width"]
            or src["sy"] + h > src["height"]):
        return -1
    if (not src["screen"] and not dst["screen"]
            and src["base"] < dst["base"] + dst["stride"] * dst["height"]
            and dst["base"] < src["base"] + src["stride"] * src["height"]
            and src["stride"] != dst["stride"]):
        return -1

    def pixel(side, x, y):
        address = side["base"] + y * side["stride"] + x
        if side["screen"]:
            return machine.canvas.back[address]
        return read(address)

    data = [[pixel(src, src["sx"] + x, src["sy"] + y) for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            xx, yy = dst["dx"] + x, dst["dy"] + y
            if (0 <= xx < dst["width"] and 0 <= yy < dst["height"]
                    and dst["cx"] <= xx < dst["cx"] + dst["cw"]
                    and dst["cy"] <= yy < dst["cy"] + dst["ch"]):
                address = dst["base"] + yy * dst["stride"] + xx
                if dst["screen"]:
                    machine.canvas.back[address] = data[y][x]
                else:
                    write(address, data[y][x])
    return w * h


def execute(machine, op, a, b, c):
    def valid(p, n):
        return 0 <= p <= CSTG_WORDS and 0 <= n <= CSTG_WORDS - p

    def read(p):
        return int(machine._nat_stg_read(p))

    def write(p, v):
        machine._nat_stg_write(p, v)

    if op == 0:
        return VERSION
    if op == 6:
        return copy_bits(machine, a, b, c)
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
