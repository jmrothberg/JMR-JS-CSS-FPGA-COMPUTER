"""V1.5 standalone compile — the ABI the self-hosted compiler runs on.

Phase 0 of the plan: the six natives (43..48), the compile arena, and the
FM/RTL parity fixes they depend on. No RTL is involved yet — these run on
the PYTHON functional model and the Value64 hardware model, which is where
the compiler itself gets authored and debugged before any bitstream.

The natives are deliberately asymmetric: reads return -1 out of range so the
tokenizer can probe cheaply, writes fault, because a stray write lands in the
framebuffer / SOURCE / WORK and corrupts the machine invisibly.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from functional_model import jsb_format  # noqa: E402
from functional_model.compiler import compile_source  # noqa: E402
from functional_model.jsb_format import NATIVE_IDS, ProgramImage  # noqa: E402
from functional_model.machine import Machine  # noqa: E402
from hardware_model.js_vm import JsHwVm  # noqa: E402


def _run(js: str) -> JsHwVm:
    """Run JS top level to completion on the hardware model."""
    hm = JsHwVm()
    hm.load_image(ProgramImage.from_chunk(compile_source(js), v2=True, value64=True))
    return hm


def _var(hm: JsHwVm, name: str) -> float:
    from hardware_model import js_vm as value64

    image = hm.program_image
    raw = hm._value_vars[image.var_names.index(name)]
    return value64.value_unpack_number(raw)


# --- ABI registration -----------------------------------------------------


def test_compile_abi_native_ids_registered():
    assert NATIVE_IDS["srcLen"] == 43
    assert NATIVE_IDS["srcByte"] == 44
    assert NATIVE_IDS["stgRead"] == 45
    assert NATIVE_IDS["stgWrite"] == 46
    assert NATIVE_IDS["cdone"] == 47
    assert NATIVE_IDS["artWrite2"] == 48


def test_compile_abi_names_emit_call_native_not_call_val():
    """compiler.py only emits CALL_NATIVE for registered names.

    A name absent from NATIVE_IDS compiles to LOAD_VAR + CALL_VAL instead,
    which is silently wrong rather than a loud error — so pin it.
    """
    from functional_model.bytecode import Op

    chunk = compile_source("var b = srcByte(0);")
    assert any(op[0] == Op.CALL_NATIVE for op in chunk.code), chunk.code


# --- source window --------------------------------------------------------


def test_src_byte_reads_staged_source_and_reports_length():
    hm = JsHwVm()
    text = "abcXYZ"
    hm._m._stage_source(text)
    hm.load_image(
        ProgramImage.from_chunk(
            compile_source(
                "var n = srcLen();"
                "var sum = 0;"
                "var i = 0;"
                "while (i < n) { sum = sum + srcByte(i); i = i + 1; }"
            ),
            v2=True,
            value64=True,
        )
    )
    assert hm.error is None, hm.error
    assert _var(hm, "n") == len(text)
    assert _var(hm, "sum") == sum(text.encode())


def test_src_byte_returns_minus_one_past_the_end():
    """The tokenizer's EOF test is `srcByte(p) < 0` — one comparison."""
    hm = JsHwVm()
    hm._m._stage_source("hi")
    hm.load_image(
        ProgramImage.from_chunk(
            compile_source("var past = srcByte(2); var neg = srcByte(-1);"),
            v2=True,
            value64=True,
        )
    )
    assert hm.error is None, hm.error
    assert _var(hm, "past") == -1
    assert _var(hm, "neg") == -1


def test_src_byte_latches_the_read_pointer():
    """src_rp is what lets the console refill the ring behind a forward reader."""
    m = Machine()
    m._stage_source("abcdef")
    m._nat_src_byte(4)
    assert m._src_rp == 4


# --- scratch arena --------------------------------------------------------


def test_stg_roundtrip_through_the_flat_arena():
    hm = JsHwVm()
    hm.load_image(
        ProgramImage.from_chunk(
            compile_source(
                "var i = 0;"
                "while (i < 256) { stgWrite(i, (i * 7) % 256); i = i + 1; }"
                "var sum = 0;"
                "i = 0;"
                "while (i < 256) { sum = sum + stgRead(i); i = i + 1; }"
            ),
            v2=True,
            value64=True,
        )
    )
    assert hm.error is None, hm.error
    assert _var(hm, "sum") == sum((i * 7) % 256 for i in range(256))


def test_stg_arena_spans_two_physical_regions():
    """CSCR and CIMG are discontiguous in SRAM but one flat space to the JS."""
    m = Machine()
    last_cscr = jsb_format.CSCR_WORDS - 1
    first_cimg = jsb_format.CSCR_WORDS
    m._nat_stg_write(last_cscr, 0xAA)
    m._nat_stg_write(first_cimg, 0xBB)
    assert m._nat_stg_read(last_cscr) == 0xAA
    assert m._nat_stg_read(first_cimg) == 0xBB
    # ...and they really are the two separate regions, not one run.
    assert jsb_format.cstg_word(last_cscr) == (
        jsb_format.CSCR_SRAM_BASE + jsb_format.CSCR_WORDS - 1
    )
    assert jsb_format.cstg_word(first_cimg) == jsb_format.CIMG_SRAM_BASE


def test_stg_read_probes_out_of_range_without_faulting():
    m = Machine()
    assert m._nat_stg_read(-1) == -1
    assert m._nat_stg_read(jsb_format.CSTG_WORDS) == -1


def test_stg_write_out_of_range_faults():
    m = Machine()
    with pytest.raises(RuntimeError, match="out of compile arena"):
        m._nat_stg_write(jsb_format.CSTG_WORDS, 0)
    with pytest.raises(RuntimeError, match="out of compile arena"):
        m._nat_stg_write(-1, 0)


def test_stg_write_does_not_reach_the_framebuffer():
    """The arena must not alias FB — a silent scribble there is invisible."""
    m = Machine()
    fb_word = jsb_format._FB_SRAM_BASE_BYTES // 2
    for i in (0, jsb_format.CSCR_WORDS, jsb_format.CSTG_WORDS - 1):
        assert jsb_format.cstg_word(i) != fb_word


# --- art staging ----------------------------------------------------------


def test_art_write2_packs_two_bytes_per_word():
    """Packed 2 B/word is what makes MKBIGCPU's 2.8 MB fit under FB_SRAM_BASE."""
    m = Machine()
    m._nat_art_write2(3, 0x12, 0x34)
    base = (jsb_format.CART_SRAM_BASE + 3) * 2
    assert m.sram.mem[base] == 0x12
    assert m.sram.mem[base + 1] == 0x34


def test_art_write2_enforces_the_framebuffer_wall():
    """This bound IS the FB wall in silicon — stronger than the mint check,
    which jsb_format skips whenever JMR_SRAM_BYTES is set."""
    m = Machine()
    m._nat_art_write2(jsb_format.CART_WORDS - 1, 1, 2)  # last legal word
    with pytest.raises(RuntimeError, match="framebuffer wall"):
        m._nat_art_write2(jsb_format.CART_WORDS, 0, 0)


def test_art_wall_matches_the_mint_time_constant():
    assert jsb_format.CART_MAX_BYTES == jsb_format._FB_SRAM_BASE_BYTES
    assert jsb_format.CART_WORDS * 2 == jsb_format.CART_MAX_BYTES


def test_every_shipped_title_fits_under_the_art_wall():
    """The measurement the whole 'all titles' plan rests on. MKBIGCPU is the
    worst case at 2,801,304 bytes — 5.4% under."""
    import base64
    import io
    import re

    pytest.importorskip("PIL")
    from PIL import Image

    from functional_model.jsb_format import read_artx

    pat = re.compile(r"data:image/[a-zA-Z0-9+./;=,_-]+")
    worst = 0
    for path in sorted((ROOT / "storage").glob("*.HTML")):
        artx_path = path.with_suffix(".ARTX")
        if artx_path.is_file():
            _pal, _spr, payload = read_artx(artx_path.read_bytes())
            off = len(payload)
        else:
            uris = [
                u
                for u in pat.findall(path.read_text(errors="replace"))
                if "," in u and "base64" in u.split(",", 1)[0].lower()
            ]
            off = jsb_format.ASET_PAL_BYTES
            for uri in dict.fromkeys(uris):  # dedupe, as _extract_data_uri_sprites does
                blob = base64.b64decode(uri.split(",", 1)[1] + "===")
                try:
                    w, h = Image.open(io.BytesIO(blob)).size
                except Exception:
                    continue
                if off & 1:
                    off += 1
                off += w * h
        worst = max(worst, off)
        assert off <= jsb_format.CART_MAX_BYTES, f"{path.name} needs {off} bytes"
    assert worst > 2_000_000, "expected MK-class art in storage/; did the corpus change?"


# --- the cdone handshake --------------------------------------------------


def test_cdone_latches_status_length_and_message():
    hm = JsHwVm()
    hm.load_image(
        ProgramImage.from_chunk(
            compile_source("cdone(0, 1234, 7);"), v2=True, value64=True
        )
    )
    assert hm.error is None, hm.error
    assert hm._m._cmp_done is True
    assert hm._m._cmp_status == 0
    assert hm._m._cmp_len == 1234
    assert hm._m._cmp_msglen == 7


def test_cdone_message_reads_back_as_ascii():
    m = Machine()
    for k, ch in enumerate(b"L12 BAD"):
        m._nat_stg_write(jsb_format.CSTG_MSG_OFF + k, ch)
    m._nat_cdone(2, 0, 7)
    assert m._cmp_message() == "L12 BAD"


def test_cdone_message_length_is_capped():
    m = Machine()
    m._nat_cdone(1, 0, 9999)
    assert m._cmp_msglen == jsb_format.CSTG_MSG_MAX


def test_cmp_output_reads_the_staged_image():
    m = Machine()
    payload = b"JSB1\x01\x02\x03"
    for k, byte in enumerate(payload):
        m._nat_stg_write(jsb_format.CSTG_OUT_OFF + k, byte)
    m._nat_cdone(0, len(payload), 0)
    assert m._cmp_output() == payload


# --- FM/RTL parity fixes this ABI depends on ------------------------------


def test_remove_deletes_a_file_like_rtl(tmp_path):
    """FM REMOVE used to alias DELETE, which parses an int line number — so
    REMOVE "X.HTML" raised ValueError while the board deleted the file."""
    (tmp_path / "GONE.HTML").write_text("<html></html>\n")
    m = Machine(storage_root=tmp_path)
    assert m.execute_line('REMOVE "GONE.HTML"') == ["OK"]
    assert not (tmp_path / "GONE.HTML").exists()


def test_remove_missing_file_is_loud_not_a_crash(tmp_path):
    m = Machine(storage_root=tmp_path)
    assert m.execute_line('REMOVE "NOPE.HTML"') == ["?FN FILE NOT FOUND"]


def test_delete_still_removes_a_source_line(tmp_path):
    m = Machine(storage_root=tmp_path)
    m.source_lines = ["a", "b", "c"]
    assert m.execute_line("DELETE 20") == ["OK"]
    assert m.source_lines == ["a", "c"]


def test_delete_with_a_filename_says_use_remove(tmp_path):
    m = Machine(storage_root=tmp_path)
    out = m.execute_line('DELETE "X.HTML"')
    assert "REMOVE" in out[0]


# --- the COMPILE verb and the program chain -------------------------------


def _mint(js: str) -> bytes:
    """Mint a compiler-chain program the way the card sidecar path does."""
    return ProgramImage.from_chunk(
        compile_source(js), v2=True, value64=True
    ).data


def _loaded(tmp_path, html="<html><body>hi</body></html>\n"):
    (tmp_path / "BOX.HTML").write_text(html)
    m = Machine(storage_root=tmp_path)
    assert m.execute_line('LOAD "BOX.HTML"')[0].startswith("LOADED")
    return m


def test_compile_without_a_loaded_source_is_loud(tmp_path):
    m = Machine(storage_root=tmp_path)
    assert m.execute_line("COMPILE") == ["?NB"]


def test_compile_without_a_compiler_on_the_card_is_loud(tmp_path):
    m = _loaded(tmp_path)
    out = m.execute_line("COMPILE")
    assert out[0] == "COMPILING"
    assert out[1] == "?NH"


def test_compile_chain_runs_programs_in_progsel_order(tmp_path):
    """Each program gets the full code RAM; they hand off through the arena.

    ARTSCAN writes a marker and asks for MINTASM (index 4), which stages a
    minimal valid image and reports done. Proves chaining, arena
    persistence across programs, and the mint — without a real compiler.
    """
    m = _loaded(tmp_path)
    out_off = jsb_format.CSTG_OUT_OFF
    payload = _mint("var t=1;")  # a real, validatable image to hand back

    artscan = (
        f"stgWrite({jsb_format.CSTG_HDR_PROGSEL}, 4);"
        "stgWrite(1000, 77);"  # marker MINTASM must still see
        f"cdone({jsb_format.CMP_STATUS_NEXT}, 0, 0);"
    )
    emit = "".join(
        f"stgWrite({out_off + i}, {b});" for i, b in enumerate(payload)
    )
    mintasm = (
        "var seen = stgRead(1000);"
        + emit
        + f"cdone(seen === 77 ? 0 : 9, {len(payload)}, 0);"
    )
    m.storage.save_bytes("ARTSCAN.JSH", _mint(artscan))
    m.storage.save_bytes("MINTASM.JSH", _mint(mintasm))

    out = m.execute_line("COMPILE")
    assert out[0] == "COMPILING"
    assert out[-1].startswith("COMPILED BOX.JSH"), out
    assert (tmp_path / "BOX.JSH").read_bytes() == payload


def test_compile_reports_a_compiler_error_with_its_message(tmp_path):
    m = _loaded(tmp_path)
    msg = "L12 EXPECTED )"
    poke = "".join(
        f"stgWrite({jsb_format.CSTG_MSG_OFF + i}, {c});"
        for i, c in enumerate(msg.encode())
    )
    m.storage.save_bytes("ARTSCAN.JSH", _mint(poke + f"cdone(3, 0, {len(msg)});"))
    out = m.execute_line("COMPILE")
    assert out[1] == "?CE"
    assert out[2] == msg
    assert not (tmp_path / "BOX.JSH").exists(), "a failed compile must not mint"


def test_compile_refuses_to_mint_a_malformed_image(tmp_path):
    """RTL validates only magic + word count and JSB1 has no checksum, so the
    FM validator is the gate — otherwise a bad image faults at run time."""
    m = _loaded(tmp_path)
    junk = b"NOTJSB1!" * 4
    emit = "".join(
        f"stgWrite({jsb_format.CSTG_OUT_OFF + i}, {b});" for i, b in enumerate(junk)
    )
    m.storage.save_bytes("ARTSCAN.JSH", _mint(emit + f"cdone(0, {len(junk)}, 0);"))
    out = m.execute_line("COMPILE")
    assert out[1] == "?CE"
    assert "BAD IMAGE" in out[2]
    assert not (tmp_path / "BOX.JSH").exists()


def test_compile_then_run_uses_the_untouched_run_path(tmp_path):
    """The whole point: COMPILE mints, and RUN neither knows nor cares."""
    html = (
        "<html><body><canvas id=c width=640 height=480></canvas><script>"
        "var n = 0; n = n + 1;"
        "</script></body></html>\n"
    )
    m = _loaded(tmp_path, html)
    from tools.compile_js import compile_html_text

    payload = ProgramImage.from_chunk(
        compile_html_text(html), v2=True, value64=True
    ).data
    emit = "".join(
        f"stgWrite({jsb_format.CSTG_OUT_OFF + i}, {b});" for i, b in enumerate(payload)
    )
    m.storage.save_bytes("ARTSCAN.JSH", _mint(emit + f"cdone(0, {len(payload)}, 0);"))

    assert m.execute_line("COMPILE")[-1].startswith("COMPILED")
    assert (tmp_path / "BOX.JSH").exists()
    # RUN resolves BOX.JSH by the same stem rule it always has.
    assert "?NH" not in " ".join(m.execute_line("RUN"))


def test_compile_chain_rom_order_is_a_contract():
    """PROGSEL indexes this ROM and the RTL name ROM alike — append only."""
    assert jsb_format.COMPILE_CHAIN[0] == "ARTSCAN.JSH"
    assert jsb_format.COMPILE_CHAIN[jsb_format.COMPILE_ENTRY] == "ARTSCAN.JSH"
    assert "COMPILER.JSH" in jsb_format.COMPILE_CHAIN
    assert "MINTASM.JSH" in jsb_format.COMPILE_CHAIN


def test_source_longer_than_the_window_is_still_fully_readable(tmp_path):
    """MK-class titles are 30x SOURCE_MAX; the ABI contract is the full
    stream, which RTL honours with a ring over the open card file."""
    big = "x" * (jsb_format.SOURCE_MAX + 5000)
    m = Machine(storage_root=tmp_path)
    m._stage_source(big)
    assert m._src_len == len(big)
    assert m._nat_src_byte(len(big) - 1) == ord("x")
    assert m._nat_src_byte(len(big)) == -1


# --- the chain programs themselves (ARTSCAN, COMPILER) --------------------
#
# These run the REAL self-hosted programs from storage/, compiled by the real
# compiler (so every wall — 16 locals, no strings, no shifts — is enforced on
# them) and executed by the Value64 model. The gate that matters is parity:
# the machine's tokenizer must agree with compiler.py's, token for token.

_STORAGE = ROOT / "storage"


def _chain_image(name):
    from tools.selfhost import mint

    if not (_STORAGE / (Path(name).stem + ".HTML")).is_file():
        pytest.skip(f"{name} not authored yet")
    return mint(name)


def _run_chain(src: str, programs=("ARTSCAN.JSH", "COMPILER.JSH"), tokens_only=False):
    """Stage source, run the chain, hand back the Machine holding the arena.

    tokens_only stops after tokenizing: a full compile writes the assembled
    image over the token array, so the tokens are gone by the time it ends.
    """
    images = [_chain_image(p) for p in programs]
    m = Machine(storage_root=_STORAGE)
    m._stage_source(src)
    # Art titles: the console pre-loads NAME.ART before ARTSCAN. Tests that
    # pass a real title's HTML should see the same flag (stem from the file
    # is not known here; callers that need art set m.source_name first).
    if m.source_name:
        m._preload_art()
    if tokens_only:
        m._nat_stg_write(jsb_format.CSTG_HDR_PHASE, 1)
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 4_000_000_000  # a compile is not a frame
    for image in images:
        m._cmp_reset()
        hw.load_image(image)
        assert hw.error is None, hw.error
        if m._cmp_status not in (jsb_format.CMP_STATUS_NEXT,):
            break
    return m


def _arena_u8(m, off):
    return m.sram.mem[jsb_format.cstg_word(off) * 2]


def _arena_uint(m, off, n):
    return sum(_arena_u8(m, off + k) << (8 * k) for k in range(n))


def _machine_tokens(m, src: str):
    raw = src.encode()
    out = []
    for i in range(_arena_uint(m, jsb_format.CSTG_HDR_TOK_N, 4)):
        b = jsb_format.CSTG_TOK_OFF + i * jsb_format.CSTG_TOK_STRIDE
        kind, sub = _arena_u8(m, b), _arena_u8(m, b + 1)
        off, ln = _arena_uint(m, b + 2, 3), _arena_u8(m, b + 5)
        if kind == jsb_format.TOK_EOF:
            break
        if kind == jsb_format.TOK_OP:
            out.append(jsb_format.OP_TOKENS[sub])
        elif kind == jsb_format.TOK_KEYWORD:
            out.append(jsb_format.KEYWORDS[sub])
        elif kind == jsb_format.TOK_STR:
            out.append('"' + raw[off : off + ln].decode("utf8", "replace") + '"')
        else:
            out.append(raw[off : off + ln].decode("utf8", "replace"))
    return out


def _host_tokens(src: str):
    """compiler.py's tokenizer over the same script extraction the mint uses."""
    import re

    from functional_model.compiler import _tokenize

    bodies = [
        mm.group(2)
        for mm in re.finditer(r"<script([^>]*)>(.*?)</script\s*>", src, re.S | re.I)
        if "chrome" not in mm.group(1).lower()
    ]
    return [
        '"' + t[1:-1] + '"' if k in ("STR", "STR2") else t
        for k, t, _ in _tokenize(";\n".join(bodies))
    ]


def test_chain_programs_fit_every_wall():
    """They are compiled by the machine's own compiler, so the walls apply."""
    from tools.selfhost import check, source_path

    for name in jsb_format.COMPILE_CHAIN:
        if not source_path(name).is_file():
            continue
        for label, used, cap in check(_chain_image(name)):
            assert used <= cap, f"{name} {label} {used} > {cap}"


def test_artscan_emits_the_script_body_span():
    src = (_STORAGE / "BOXES.HTML").read_text()
    m = _run_chain(src, ("ARTSCAN.JSH",))
    assert m._cmp_status == jsb_format.CMP_STATUS_NEXT, m._cmp_message()
    assert _arena_u8(m, jsb_format.CSTG_HDR_PROGSEL) == 2  # -> COMPILER
    assert _arena_uint(m, jsb_format.CSTG_HDR_SPAN_N, 2) == 1
    b = jsb_format.CSTG_SPAN_OFF
    kind = _arena_u8(m, b)
    off, ln = _arena_uint(m, b + 2, 4), _arena_uint(m, b + 6, 4)
    assert kind == jsb_format.SPAN_KIND_SOURCE
    raw = src.encode()
    body = raw[off : off + ln]
    # The span must be the body and nothing else — no tag either side.
    assert b"<script" not in body and b"</script" not in body
    assert raw[off - 1 : off] == b">"
    assert raw[off + ln : off + ln + 2] == b"</"


def test_artscan_skips_chrome_only_blocks():
    """SNDDEMO has two script blocks; the data-host="chrome" one is browser
    Web Audio that the card mint strips, so the machine must strip it too."""
    src = (_STORAGE / "SNDDEMO.HTML").read_text()
    assert src.count("<script") == 2 and 'data-host="chrome"' in src
    m = _run_chain(src, ("ARTSCAN.JSH",))
    assert _arena_uint(m, jsb_format.CSTG_HDR_SPAN_N, 2) == 1


def test_artscan_refuses_art_titles_loudly():
    """Compiling INVADERS without its sprites would look like a render bug."""
    html = _STORAGE / "INVADERS.HTML"
    if not html.is_file():
        pytest.skip("INVADERS.HTML missing — FAST INVF has an .ART sidecar")
    src = html.read_text()
    m = _run_chain(src, ("ARTSCAN.JSH",))
    assert m._cmp_status != jsb_format.CMP_STATUS_NEXT
    assert "ART" in m._cmp_message()


@pytest.mark.parametrize("title", ["BOXES", "JOYDEMO", "SNDDEMO", "AURORA"])
def test_machine_tokenizer_matches_the_host_token_for_token(title):
    """The Phase 1 gate. A tokenizer that agrees with compiler.py on real
    titles is the evidence that the walled-subset port is faithful."""
    src = (_STORAGE / f"{title}.HTML").read_text()
    m = _run_chain(src, tokens_only=True)
    got = _machine_tokens(m, src)
    want = _host_tokens(src)
    assert len(got) == len(want), (len(got), len(want))
    for i, (a, b) in enumerate(zip(got, want)):
        assert a == b, f"token {i}: machine {a!r} != host {b!r}"


# --- the machine compiling real titles ------------------------------------


@pytest.mark.parametrize(
    "title", ["BOXES", "JOYDEMO", "SNDDEMO", "AURORA", "MISSILE", "ASTEROID"]
)
def test_machine_compiled_title_renders_identically_to_the_host(title):
    """The gate that matters: an image the MACHINE produced, run on the VM,
    draws exactly what the host-compiled image draws.

    Byte-parity is not the bar — the machine drops the host's inlining and
    source map, so its images are smaller. Pixels are the bar.
    """
    from tools.compile_js import compile_html_text, encode_html_chunk
    from tools.selfhost import self_compile

    if not (_STORAGE / "COMPILER.HTML").is_file():
        pytest.skip("compiler not authored yet")
    src = (_STORAGE / f"{title}.HTML").read_text()
    mine = self_compile(title)
    # encode_html_chunk is the REAL card mint. Comparing against a plain
    # from_chunk() encoding hides the whole colour path, because that form
    # carries no ASET palette and no FSTY table — which is exactly how
    # machine-compiled titles came to draw every rectangle white on the
    # board while looking perfect here.
    host = encode_html_chunk(
        compile_html_text(src, source_path=_STORAGE / f"{title}.HTML")
    )

    def render_rgb(blob):
        vm = JsHwVm()
        vm.load_image(ProgramImage(blob))
        for _ in range(6):
            vm.frame_tick()
            if vm.error:
                break
        pal = vm.canvas.palette
        return vm.error, bytes(c for px in vm.canvas.back for c in pal[px])

    err_a, rgb_a = render_rgb(mine)
    err_b, rgb_b = render_rgb(host)
    assert err_a is None, err_a
    assert err_b is None, err_b
    assert any(rgb_a), "machine image drew nothing"
    # Resolved RGB, not palette indices: the machine builds its own palette,
    # so indices may legitimately differ while the picture is identical.
    diff = sum(1 for x, y in zip(rgb_a, rgb_b) if x != y)
    assert diff == 0, f"{title}: {diff} of {len(rgb_a)} RGB bytes differ"


def test_machine_image_carries_the_colour_tables_the_rtl_needs():
    """The RTL does not parse colour strings. It resolves ctx.fillStyle through
    the FSTY table and paints index 1 — WHITE — for anything missing from it.
    An image without FSTY renders perfectly on the model and all-white on
    hardware, so pin both the table and the palette that backs it."""
    import struct

    from tools.selfhost import self_compile

    if not (_STORAGE / "COMPILER.HTML").is_file():
        pytest.skip("compiler not authored yet")
    blob = self_compile("BOXES")
    flags = struct.unpack_from("<H", blob, 10)[0]
    assert flags & jsb_format.FLAG_ASET, "no ASET section: palette never loads"
    i = blob.find(b"FSTY")
    assert i > 0, "no FSTY table: every fillStyle would paint white"
    n = struct.unpack_from("<H", blob, i + 4)[0]
    names = ProgramImage(blob).names
    got = {}
    for k in range(n):
        ni, pi = struct.unpack_from("<HH", blob, i + 6 + 4 * k)
        got[names[ni]] = pi
    assert got == {"#000000": 0, "#FF0000": 2, "#0000FF": 4, "#FFFFFF": 1}, got
    # ...and the palette those indices point into is the frozen legacy 8.
    aset = struct.unpack_from("<I", blob, 12)[0]
    pal = blob[aset + 8 : aset + 8 + 24]
    assert [tuple(pal[j * 3 : j * 3 + 3]) for j in range(5)] == [
        (0, 0, 0), (255, 255, 255), (255, 0, 0), (0, 255, 0), (0, 0, 255)
    ]


def test_short_circuit_keeps_its_value():
    """JUMP_IF_FALSE consumes its operand, so && and || must DUP first.
    Without it the taken branch underflows and the untaken one loses the
    result — it cost JOYDEMO, SNDDEMO and AURORA all at once."""
    from tools.selfhost import self_compile

    if not (_STORAGE / "COMPILER.HTML").is_file():
        pytest.skip("compiler not authored yet")
    blob = self_compile("JOYDEMO")
    vm = JsHwVm()
    vm.load_image(ProgramImage(blob))
    for _ in range(6):
        vm.frame_tick()
    assert vm.error is None


def _drive_compiler_source(driver_js: str, source_text: str = ""):
    """Run COMPILER.HTML's own code with a test driver appended.

    This is the CTEST shape from the plan: the functions under test are the
    real shipped ones, not a copy that can drift. The driver replaces the
    entry block at the end, so the tokenizer does not run.
    """
    import re

    html = (_STORAGE / "COMPILER.HTML").read_text()
    body = re.search(r"<script>(.*?)</script>", html, re.S).group(1)
    body = body.split("// ---- entry ---")[0]
    m = Machine(storage_root=_STORAGE)
    m._stage_source(source_text)
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 4_000_000_000
    hw.load_image(
        ProgramImage.from_chunk(
            compile_source(body + "\n" + driver_js), v2=True, value64=True
        )
    )
    assert hw.error is None, hw.error
    return m, hw


@pytest.mark.parametrize(
    "value",
    [0.0, 1.0, 2.0, 0.5, -1.0, -0.5, 640.0, 480.0, 3.14159, 1e-3, 255.0,
     65536.0, 4503599627370496.0, 0.1, 1.5, -3.75, 1234567.0],
)
def test_binary64_packer_is_bit_exact(value):
    """The most parity-fragile function in the port: one wrong bit and the
    compiled title runs with a different constant. Gate is struct.pack."""
    import struct

    m, _ = _drive_compiler_source(f"w64(2048, {value!r});")
    got = bytes(_arena_u8(m, 2048 + k) for k in range(8))
    assert got == struct.pack("<d", value), (got.hex(), struct.pack("<d", value).hex())


@pytest.mark.parametrize("text", ["0", "1", "640", "480", "3.14159", "0.5", "255", "1000000"])
def test_numeric_literal_parse_matches_python(text):
    """Digits in the source must become the same double the host produces."""
    import struct

    m, _ = _drive_compiler_source(f"w64(2048, numAt(0, {len(text)}));", text)
    got = bytes(_arena_u8(m, 2048 + k) for k in range(8))
    assert got == struct.pack("<d", float(text)), text


def test_run_reports_a_malformed_image_instead_of_crashing(tmp_path):
    """A malformed minted image used to raise out of RUN as a Python
    traceback. With COMPILE writing images on-device, a bad one is routine."""
    html = "<html><body><canvas id=c></canvas><script>var a=1;</script></body></html>"
    (tmp_path / "BAD.HTML").write_text(html)
    (tmp_path / "BAD.JSH").write_bytes(b"JSB1" + b"\x00" * 32)  # valid magic, junk body
    m = Machine(storage_root=tmp_path)
    m.execute_line('LOAD "BAD.HTML"')
    out = m.execute_line("RUN")
    assert out[0] == "?NB", out


# --- the model must reject exactly what silicon rejects -------------------


def test_code_words_check_measures_the_executable_not_the_trailer():
    """PACFAST is the case that proved this wrong. Its executable is 17,604
    words (2,876 spare) but its whole pre-ASET stream is 20,631 — and the FM
    used to refuse on the second number, so PYTHON alone could not run a
    title that plays on the board. jmr_js_vm.sv:6942 faults only on
    ops_base + n_ops, so that is what the model may refuse on."""
    import struct

    m = Machine()
    if not m.storage.card_img or not m.storage.card_img.is_file():
        pytest.skip("no card.img")
    blob = m.storage.load_bytes("PACFAST.JSH")
    n_ops, n_consts = struct.unpack_from("<HH", blob, 4)
    flags = struct.unpack_from("<H", blob, 10)[0]
    ops_base = (4 if flags & 2 else 3) + n_consts * (2 if flags & 8 else 1)
    assert ops_base + n_ops <= jsb_format.PROGRAM_CODE_WORDS  # silicon's rule
    img = jsb_format.ProgramImage(blob)  # must NOT raise
    assert img.code_bram_overflow == 151  # trailer tail the loader drops


def test_over_long_image_loads_by_dropping_the_tail_like_the_write_port():
    """jmr_js_vm.sv:194-196 guards the code-BRAM write with
    `code_waddr_q2 < CODE_WORDS`, so surplus words are dropped, not wrapped.
    The model has to do the same or it crashes where silicon shrugs."""
    m = Machine()
    if not m.storage.card_img or not m.storage.card_img.is_file():
        pytest.skip("no card.img")
    blob = m.storage.load_bytes("PACFAST.JSH")
    hw = JsHwVm()
    hw.load_image(jsb_format.ProgramImage(blob))  # must not raise
    assert hw.error is None or "instruction limit" in hw.error


def test_dir_hides_the_compiler_chain_programs():
    """DIR is the catalog of TITLES. The chain programs live on the card as
    ordinary .HTML/.JSH pairs, but listing them buries the games."""
    m = Machine()
    if not m.storage.card_img or not m.storage.card_img.is_file():
        pytest.skip("no card.img")
    listed = {Path(n).stem.upper() for n in m.storage.catalog()}
    assert not (listed & {"ARTSCAN", "COMPILER", "ARTPNG", "COMPIL2", "MINTASM"})
    # ...but they are still loadable by name, which is how COMPILE finds them.
    m.storage.load_bytes("ARTSCAN.JSH")


def test_dir_lists_only_titles(tmp_path):
    (tmp_path / "GAME.HTML").write_text("<html></html>")
    (tmp_path / "ARTSCAN.HTML").write_text("<html></html>")
    (tmp_path / "GAME.JSH").write_bytes(b"x")
    m = Machine(storage_root=tmp_path)
    assert m.storage.catalog() == ["GAME.HTML"]


def test_list_all_includes_jsh_and_catalog_dump(tmp_path):
    """UTILITY needs every FAT file (DIR still hides .JSH)."""
    (tmp_path / "GAME.HTML").write_text("<html></html>")
    (tmp_path / "GAME.JSH").write_bytes(b"abcd")
    m = Machine(storage_root=tmp_path)
    info = {n: s for n, s in m.storage.list_all()}
    assert info["GAME.HTML"] == 13
    assert info["GAME.JSH"] == 4
    assert m.storage.catalog() == ["GAME.HTML"]
    m._stage_card_catalog()
    assert int(m._nat_stg_read(0)) == 0x55
    assert int(m._nat_stg_read(1)) == 0x54
    assert int(m._nat_stg_read(2)) == 0x4C
    assert int(m._nat_stg_read(3)) == 1
    nlen = int(m._nat_stg_read(4))
    name = "".join(chr(int(m._nat_stg_read(5 + i))) for i in range(nlen))
    assert name in ("GAME.HTML", "GAME.JSH")


# --- the editor -----------------------------------------------------------


def _drive_editor(driver_js: str, source_text: str):
    """Run EDITOR.HTML's own code with a driver appended.

    Same CTEST shape as the compiler tests: the functions under test are the
    shipped ones, so they cannot drift from a copy.
    """
    import re

    if not (_STORAGE / "EDITOR.HTML").is_file():
        pytest.skip("editor not authored yet")
    html = (_STORAGE / "EDITOR.HTML").read_text()
    body = re.search(r"<script>(.*?)</script>", html, re.S).group(1)
    body = body.split("reindex();\naddEventListener")[0]
    m = Machine(storage_root=_STORAGE)
    m._stage_source(source_text)
    hw = JsHwVm()
    hw._m = m
    hw.step_budget = 2_000_000_000
    hw.load_image(
        ProgramImage.from_chunk(
            compile_source(body + "\n" + driver_js), v2=True, value64=True
        )
    )
    assert hw.error is None, hw.error
    return m, m._src_bytes[: m._src_len].decode("utf8", "replace")


_ED_SRC = "one\ntwo\nthree\n"


@pytest.mark.parametrize(
    "driver,want",
    [
        ("reindex(); curLine = 1; curCol = 0; typeChar(88);", "one\nXtwo\nthree\n"),
        ("reindex(); curLine = 0; curCol = 1; pressEnter();", "o\nne\ntwo\nthree\n"),
        ("reindex(); curLine = 1; curCol = 2; pressBack();", "one\nto\nthree\n"),
        # backspace at column 0 joins to the line above
        ("reindex(); curLine = 1; curCol = 0; pressBack();", "onetwo\nthree\n"),
    ],
)
def test_editor_edits_the_source_in_place(driver, want):
    _, got = _drive_editor(driver, _ED_SRC)
    assert got == want


def test_editor_key_handler_moves_and_types():
    """The real listener path: an event object into onKey, as the browser
    style listener delivers it."""
    drv = "reindex(); var e = {};\n" + "".join(
        f"e.keyCode = {k}; onKey(e);\n" for k in (40, 39, 39, 88)
    )
    _, got = _drive_editor(drv, _ED_SRC)
    assert got == "one\ntwXo\nthree\n"


def test_editor_save_and_quit_report_distinct_statuses():
    """F2 asks the console to save; F3 must report a status the console will
    NOT mint on — minting a zero-length image would truncate-open the title's
    .JSH and destroy a working compiled title. Esc is machine BREAK, not quit."""
    m, _ = _drive_editor("reindex(); var e = {}; e.keyCode = 113; onKey(e);", _ED_SRC)
    assert m._cmp_status == jsb_format.CMP_STATUS_SAVE
    m, _ = _drive_editor("reindex(); var e = {}; e.keyCode = 114; onKey(e);", _ED_SRC)
    assert m._cmp_status == jsb_format.CMP_STATUS_DONE and m._cmp_len == 0


def test_editor_paste_mode_types_q_without_saving():
    """F6…F7: ASCII 113 is 'q', not F2. GUI paste uses this wrap because
    KEYEVT is only an 8-bit keyCode and 113 is both F2 and 'q'."""
    drv = (
        "reindex(); var e = {};\n"
        "e.keyCode = 117; onKey(e);\n"
        "e.keyCode = 113; onKey(e);\n"
        "e.keyCode = 118; onKey(e);\n"
    )
    m, got = _drive_editor(drv, _ED_SRC)
    assert got.startswith("q"), got
    assert m._cmp_status != jsb_format.CMP_STATUS_SAVE


def test_editor_f2_still_saves_after_paste_window():
    drv = (
        "reindex(); var e = {};\n"
        "e.keyCode = 117; onKey(e);\n"
        "e.keyCode = 97; onKey(e);\n"
        "e.keyCode = 118; onKey(e);\n"
        "e.keyCode = 113; onKey(e);\n"
    )
    m, got = _drive_editor(drv, _ED_SRC)
    assert got.startswith("a"), got
    assert m._cmp_status == jsb_format.CMP_STATUS_SAVE


def test_editor_round_trips_a_real_title_untouched():
    src = (_STORAGE / "BOXES.HTML").read_text()
    _, got = _drive_editor("reindex();", src)
    assert got == src


def test_edit_verb_refuses_with_nothing_loaded(tmp_path):
    assert Machine(storage_root=tmp_path).execute_line("EDIT") == ["?NB"]


def test_edit_verb_paints_the_loaded_title(tmp_path):
    """Bare EDIT must share the console Machine so srcByte sees LOAD's SOURCE.

    A fresh JsHwVm has srcLen=0; the editor then fillRects black and the glass
    looks like a hang. Same share as the COMPILE chain (hw._m = self).
    """
    from tools.selfhost import mint, source_path

    if not source_path("EDITOR.JSH").is_file():
        pytest.skip("editor not authored yet")
    (tmp_path / "EDITOR.JSH").write_bytes(mint("EDITOR.JSH").data)
    (tmp_path / "BOXES.HTML").write_text((_STORAGE / "BOXES.HTML").read_text())
    m = Machine(storage_root=tmp_path)
    m.execute_line("LOAD BOXES.HTML")
    out = m.execute_line("EDIT")
    assert m.running, out
    assert m._hw_vm._m is m
    # GUI pumps frame_tick; present() used to copy an empty BACK over a
    # swapped FRONT and wipe the glyphs. One tick must still show SOURCE.
    m.frame_tick()
    # Palette 1 is #FFFFFF — the editor's body glyphs. Cursor/status alone
    # are blue/red (4/2); white means SOURCE text actually landed.
    assert any(p == 1 for p in m.canvas.front), "editor painted no source glyphs"


def test_edit_verb_f2_save_updates_list(tmp_path):
    """F2 must write SOURCE back so LIST shows the edit. Esc is BREAK, not save."""
    from tools.selfhost import mint, source_path

    if not source_path("EDITOR.JSH").is_file():
        pytest.skip("editor not authored yet")
    (tmp_path / "EDITOR.JSH").write_bytes(mint("EDITOR.JSH").data)
    (tmp_path / "BOXES.HTML").write_text((_STORAGE / "BOXES.HTML").read_text())
    m = Machine(storage_root=tmp_path)
    m.execute_line("LOAD BOXES.HTML")
    before = list(m.source_lines)
    m.execute_line("EDIT")
    m.input.key_event(88, "X", True)   # insert 'X' at the cursor
    m.frame_tick()
    m.input.key_event(113, "F2", True)  # save
    m.frame_tick()
    m.frame_tick()  # console acts on cdone the tick after the key
    assert not m.running
    assert m.source_lines[0].startswith("X"), m.source_lines[0][:40]
    assert m.source_lines[0] != before[0]


def test_edit_verb_still_leaves_edit_n_as_the_line_editor(tmp_path):
    """Bare EDIT runs the program; `EDIT n` stays the numbered-line editor."""
    m = Machine(storage_root=tmp_path)
    m.source_lines = ["a", "b", "c"]
    out = m.execute_line("EDIT 20")
    assert "20" in " ".join(out)


def test_editor_fits_the_code_ram_wall():
    from tools.selfhost import check, mint, source_path

    if not source_path("EDITOR.JSH").is_file():
        pytest.skip("editor not authored yet")
    for label, used, cap in check(mint("EDITOR.JSH")):
        assert used <= cap, f"EDITOR {label} {used} > {cap}"


def test_token_record_stays_six_bytes():
    """Carrying a line number would cost 63KB on PACFAST to serve an error
    path that runs once. If this grows, re-justify it against the arena."""
    assert jsb_format.CSTG_TOK_STRIDE == 6


def test_save_bytes_does_not_delete_the_jsh_sidecar(tmp_path):
    """save_text deletes STEM.JSH on an HTML save — a mint must not."""
    m = Machine(storage_root=tmp_path)
    m.storage.save_bytes("BOX.JSH", b"JSB1binary\x00\xff")
    assert (tmp_path / "BOX.JSH").read_bytes() == b"JSB1binary\x00\xff"
    m.storage.save_bytes("BOX.JSH", b"again")
    assert (tmp_path / "BOX.JSH").read_bytes() == b"again"
