// Verilator harness — tops jmr_js_core (same DUT as board PHY shell).
// Protocol: KEY / LINE / SCREEN? / STATUS? / RUNCLK / TICK / QUIT
// NEW: card.img SPI model (BASIC sim_main SdCard) for DIR/LOAD/SAVE.
#include "Vjmr_js_core.h"
#include "Vjmr_js_core___024root.h" // NEW: VMSTAT? probe reads public VM regs
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>
#include <string>
#include <fstream>
#include <algorithm>
#include <utility>
#include <vector>

static Vjmr_js_core* top = nullptr;

// CHECKPOINT/OBJPEEK peek 1-D SRAM (not a third hardware port).
// Match rtl/engines/jmr_js_vm.sv two-tier arrays (1536×32 + 128×128).
static const unsigned VM_MAX_OBJ = 1024u;
static const unsigned VM_OBJ_SLOTS = 32u;
static const unsigned VM_MAX_ARR_SHORT = 1536u;
static const unsigned VM_ARR_SHORT_CAP = 32u;
static const unsigned VM_MAX_ARR_LONG = 128u;
static const unsigned VM_MAX_ARR = 1664u;
static const unsigned VM_ARR_CAP = 128u;
static const unsigned VM_VARR_SHORT_WORDS = VM_MAX_ARR_SHORT * VM_ARR_SHORT_CAP;
static const unsigned VM_ENV_DEPTH = 512u;
static const unsigned VM_ENV_SLOTS = 16u;
static inline unsigned vobj_addr(unsigned h, unsigned s) {
    return (h * VM_OBJ_SLOTS) + s;
}
static inline unsigned varr_addr(Vjmr_js_core___024root* r, unsigned h, unsigned e) {
    if (h >= VM_MAX_ARR)
        h = 0;
    if (r->jmr_js_core__DOT__u_vm__DOT__varr_long[h]) {
        unsigned phys = unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_lidx[h]);
        if (phys >= VM_MAX_ARR_LONG) phys = 0;
        if (e >= VM_ARR_CAP) e = VM_ARR_CAP - 1u;
        return VM_VARR_SHORT_WORDS + (phys * VM_ARR_CAP) + e;
    }
    if (e >= VM_ARR_SHORT_CAP) e = VM_ARR_SHORT_CAP - 1u;
    return (h * VM_ARR_SHORT_CAP) + e;
}
static inline unsigned venv_addr(unsigned h, unsigned s) {
    return (h * VM_ENV_SLOTS) + s;
}
static uint16_t peek_vobj_key(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = r->jmr_js_core__DOT__u_vm__DOT__vobj_slot[vobj_addr(h, s)];
    return uint16_t(w[2] & 0xFFFFu);
}
static uint64_t peek_vobj_val(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = r->jmr_js_core__DOT__u_vm__DOT__vobj_slot[vobj_addr(h, s)];
    return uint64_t(w[0]) | (uint64_t(w[1]) << 32);
}
static uint8_t peek_vobj_tag(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    return uint8_t(r->jmr_js_core__DOT__u_vm__DOT__vobj_tmem[vobj_addr(h, s)]);
}
static uint64_t peek_varr_val(Vjmr_js_core___024root* r, unsigned h, unsigned e) {
    return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__varr_slot[varr_addr(r, h, e)]);
}
// TOS window is CPU truth; BRAM vstack lags one write. CHECKPOINT overlays.
static uint64_t peek_vstack(Vjmr_js_core___024root* r, unsigned slot, unsigned vsp) {
    if (vsp > 0u && slot < vsp) {
        unsigned d = vsp - 1u - slot;
        if (d < 16u)
            return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[d]);
    }
    return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vstack[slot]);
}
static uint8_t peek_varr_tag(Vjmr_js_core___024root* r, unsigned h, unsigned e) {
    return uint8_t(r->jmr_js_core__DOT__u_vm__DOT__varr_tmem[varr_addr(r, h, e)]);
}
static uint16_t peek_venv_key(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = r->jmr_js_core__DOT__u_vm__DOT__venv_slot[venv_addr(h, s)];
    return uint16_t(w[2] & 0x1FFu);
}
static uint64_t peek_venv_val(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = r->jmr_js_core__DOT__u_vm__DOT__venv_slot[venv_addr(h, s)];
    return uint64_t(w[0]) | (uint64_t(w[1]) << 32);
}

// ---- base64 (FB? export) -----------------------------------------------
static const char B64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string b64_encode(const uint8_t* data, size_t n) {
    std::string out;
    out.reserve(((n + 2) / 3) * 4);
    for (size_t i = 0; i < n; i += 3) {
        uint32_t v = (uint32_t)data[i] << 16;
        if (i + 1 < n) v |= (uint32_t)data[i + 1] << 8;
        if (i + 2 < n) v |= (uint32_t)data[i + 2];
        out.push_back(B64[(v >> 18) & 63]);
        out.push_back(B64[(v >> 12) & 63]);
        out.push_back(i + 1 < n ? B64[(v >> 6) & 63] : '=');
        out.push_back(i + 2 < n ? B64[v & 63] : '=');
    }
    return out;
}

// ---- SD card model (from BASIC sim/sim_main.cpp) -------------------------
static const unsigned SD_SECTOR = 512;
static const unsigned SD_WRITE_BUSY_BYTES = 8;

struct SdCard {
    std::vector<uint8_t> image;
    std::vector<uint8_t> tx;
    size_t tx_head = 0;
    bool   present = false;
    bool     prev_sck = false;
    bool     prev_cs_n = true;
    unsigned bit_i = 0;
    uint8_t  tx_byte = 0xFF;
    uint8_t  rx_byte = 0;
    uint8_t  miso_hold = 1;
    int      rx_mode = 0;
    uint8_t  cmd_buf[6];
    unsigned cmd_len = 0;
    uint32_t write_lba = 0;
    std::vector<uint8_t> write_buf;
    unsigned write_crc_left = 0;
    bool app_cmd = false;
    bool idle = true;
    bool initialised = false;
    unsigned acmd41_count = 0;
    unsigned wake_clocks = 0;
    bool     dirty = false;

    void push(uint8_t b) { tx.push_back(b); }
    uint8_t pop() {
        if (tx_head < tx.size()) {
            uint8_t b = tx[tx_head++];
            if (tx_head == tx.size()) { tx.clear(); tx_head = 0; }
            return b;
        }
        return 0xFF;
    }
    void clear_tx() { tx.clear(); tx_head = 0; }

    uint8_t r1_for(unsigned index) {
        if (index == 55) { app_cmd = true; return idle ? 0x01 : 0x00; }
        if (app_cmd) {
            app_cmd = false;
            if (index == 41) {
                acmd41_count++;
                if (acmd41_count >= 2) { initialised = true; idle = false; return 0x00; }
                return 0x01;
            }
        }
        if (index == 0) return 0x01;
        if (index == 8) return 0x01;
        if (index == 58) return 0x00;
        if (index == 17 || index == 24) return initialised ? 0x00 : 0x01;
        if (index == 13) return 0x00;
        return 0x04;
    }

    void handle_command() {
        unsigned index = cmd_buf[0] & 0x3F;
        uint32_t arg = ((uint32_t)cmd_buf[1] << 24) | ((uint32_t)cmd_buf[2] << 16) |
                       ((uint32_t)cmd_buf[3] << 8) | (uint32_t)cmd_buf[4];
        uint8_t crc = cmd_buf[5];
        if (index == 0 && wake_clocks < 74) return;
        if (index == 0 && crc != 0x95) { push(0x09); return; }
        if (crc == 0x00) { push(0x09); return; }
        uint8_t r1 = r1_for(index);
        push(r1);
        if (index == 8) {
            push(0x00); push(0x00); push(0x01); push(0xAA);
        } else if (index == 58) {
            push(0x40); push(0xFF); push(0x80); push(0x00);
        } else if (index == 17 && r1 == 0x00) {
            size_t off = (size_t)arg * SD_SECTOR;
            push(0xFE);
            for (unsigned i = 0; i < SD_SECTOR; i++)
                push(off + i < image.size() ? image[off + i] : 0x00);
            push(0xFF); push(0xFF);
        } else if (index == 24 && r1 == 0x00) {
            write_lba = arg;
            rx_mode = 1;
        }
        if (index == 0) { idle = true; initialised = false; acmd41_count = 0; }
    }

    void byte_done() {
        if (rx_mode == 0) {
            if (cmd_len == 0 && rx_byte == 0xFF) return;
            cmd_buf[cmd_len++] = rx_byte;
            if (cmd_len >= 6) { handle_command(); cmd_len = 0; }
        } else if (rx_mode == 1) {
            if (rx_byte == 0xFE) { rx_mode = 2; write_buf.clear(); }
        } else if (rx_mode == 2) {
            write_buf.push_back(rx_byte);
            if (write_buf.size() >= SD_SECTOR) { rx_mode = 3; write_crc_left = 2; }
        } else {
            if (--write_crc_left == 0) {
                size_t off = (size_t)write_lba * SD_SECTOR;
                if (off + SD_SECTOR <= image.size())
                    std::memcpy(&image[off], write_buf.data(), SD_SECTOR);
                dirty = true;
                push(0x05);
                for (unsigned i = 0; i < SD_WRITE_BUSY_BYTES; i++) push(0x00);
                push(0xFF);
                rx_mode = 0;
            }
        }
    }

    void step(bool cs_n, bool sck, bool mosi, uint8_t *miso_out) {
        if (!present) { *miso_out = 1; return; }
        if (cs_n) {
            if (!prev_cs_n) { rx_mode = 0; cmd_len = 0; clear_tx(); }
            if (sck && !prev_sck && wake_clocks < 1000) wake_clocks++;
            bit_i = 0;
            miso_hold = 1;
            *miso_out = 1;
        } else if (sck && !prev_sck) {
            if (bit_i == 0) tx_byte = pop();
            rx_byte = (uint8_t)((rx_byte << 1) | (mosi ? 1 : 0));
            miso_hold = (uint8_t)((tx_byte >> (7 - bit_i)) & 1);
            *miso_out = miso_hold;
            if (++bit_i == 8) { bit_i = 0; byte_done(); }
        } else {
            *miso_out = miso_hold;
        }
        prev_sck  = sck;
        prev_cs_n = cs_n;
    }
};

static SdCard sd;
static std::string sd_path;

static void sd_save_image() {
    if (!sd.dirty || sd_path.empty() || sd.image.empty()) return;
    FILE *f = std::fopen(sd_path.c_str(), "wb");
    if (!f) return;
    std::fwrite(sd.image.data(), 1, sd.image.size(), f);
    std::fclose(f);
    sd.dirty = false;
}

static void sd_load_image() {
    const char *env = std::getenv("JMR_CARD_IMG");
    const char *paths[] = {env, "../card.img", "card.img", "../../card.img"};
    for (const char *p : paths) {
        if (!p) continue;
        FILE *f = std::fopen(p, "rb");
        if (!f) continue;
        std::fseek(f, 0, SEEK_END);
        long n = std::ftell(f);
        std::fseek(f, 0, SEEK_SET);
        if (n > 0) {
            sd.image.resize((size_t)n);
            size_t got = std::fread(sd.image.data(), 1, (size_t)n, f);
            sd.image.resize(got);
            sd.present = got >= SD_SECTOR;
        }
        std::fclose(f);
        if (sd.present) {
            sd_path = p;
            std::cerr << "SD image " << p << " (" << sd.image.size() << " bytes)\n";
            return;
        }
    }
    std::cerr << "WARN: no card.img — DIR will ?IO\n";
}

// NEW: VARWATCH <slot> — log every write to vars[slot] with the VM ip.
// -1 disables. Minimal bring-up watchpoint (stderr, off by default).
static int watch_slot = -1;
static int32_t watch_prev = 0;
// NEW: IPTRACE — ring of executed ip values (execution path). Arm with
// "IPTRACE <n>", dump+disarm with "IPTRACE?". Off by default.
struct VRingEnt {
    unsigned st; unsigned ip; uint64_t venv;
    unsigned vvr; unsigned vk; unsigned proto; unsigned gcp;
    unsigned vsp; uint64_t w0; uint64_t w1; uint64_t w2;
    unsigned pcsp; unsigned ecsp; unsigned flags; unsigned est;
};
static int ring_stop_ip = -1;
static VRingEnt vring[256];
static unsigned long vring_i = 0;
static bool vring_frozen = false;
static unsigned long state_prof[128] = {0};
static unsigned long prof_cycles = 0;
// NEW: ENVWATCH — log every venv_valid[idx] transition with state/ip.
struct EnvEvt { unsigned st; unsigned ip; unsigned val; uint64_t venv; };
static std::vector<EnvEvt> env_evts;
static int env_watch = -1;
static unsigned env_watch_prev = 0;
static unsigned env_prev[8] = {0};
static std::vector<uint16_t> ip_trace;
static size_t ip_trace_cap = 0;
static uint16_t ip_trace_prev = 0xffff;
// NEW: last FRAME clocks / cap — play log showed swaps<<fb_frames with no
// clk, so a 2M-clock cap abort was invisible.
static unsigned last_fclk = 0;
static unsigned last_fcap = 0;
static unsigned fcap_n = 0;
// Latch rAF/fn SRAM view on first fault — later IDLE ticks overwrite rdata.
static unsigned fault_snap_code = 0;
static unsigned fault_snap_raddr = 0;
static unsigned fault_snap_valid = 0;
static unsigned fault_snap_gen = 0;
static unsigned fault_snap_akind = 0;
static unsigned fault_snap_ai = 0;
static unsigned fault_snap_vsp = 0;
static unsigned fault_snap_vcsp = 0;
static unsigned fault_snap_hvcsp = 0;
static unsigned fault_snap_opnd = 0;
static uint64_t fault_snap_w0 = 0;
static uint32_t fault_snap_cr = 0;
static unsigned fault_hold_raddr = 0;
static unsigned fault_hold_valid = 0;
static unsigned fault_hold_gen = 0;
static unsigned fault_hold_akind = 0;
static unsigned fault_hold_ai = 0;
static unsigned fault_hold_vsp = 0;
static unsigned fault_hold_vcsp = 0;
static unsigned fault_hold_hvcsp = 0;
static unsigned fault_hold_opnd = 0;
static uint64_t fault_hold_w0 = 0;
static uint32_t fault_hold_cr = 0;

// Must match jmr_js_vm.sv st_t declaration order (VMSTAT sname=).
static const char* vm_sname(unsigned s) {
    static const char* N[] = {
        "S_IDLE","S_RD","S_GOT_MAGIC","S_GOT_HDR1","S_GOT_HDR2","S_LD_CONST",
        "S_TRAIL","S_FETCH_WAIT","S_EXEC","S_NAT","S_CLEAR","S_RECT","S_CIRCLE",
        "S_LINE","S_BLIT","S_SPR","S_WAIT_FRAME","S_DONE","S_XF_MUL","S_XF_APPLY",
        "S_PWALK","S_PDO","S_QSEG","S_QPX","S_QPY","S_JOIN","S_JOIN_FIND",
        "S_IDXOF","S_CONCAT","S_SQRT","S_DIV","S_DIV_FIN","S_MUL","S_MUL_WR",
        "S_ALU","S_ALU_WR","S_CALL","S_FOREACH","S_KEYEV","S_ENV_LOAD",
        "S_JSON","S_JSON_PARSE","S_REPL","S_IDXSTR","S_STRIDX","S_STRIDX_WR",
        "S_FONTPX","S_TXT_LD","S_TXT_DRAW","S_STR_WR","S_IMGD_GET","S_IMGD_PUT",
        "S_NAMCPY","S_ARR_DCOPY"
        ,"S_GC_CLEAR","S_GC_ROOT","S_GC_POP","S_GC_OBJ","S_GC_ARR",
        "S_V64_CONST_HI","S_V64_EXEC","S_V64_DIV","S_V64_DIV_FIN","S_V64_MOD",
        "S_V64_ALLOC","S_V64_GC_CLEAR","S_V64_GC_ROOT","S_V64_GC_POP",
        "S_V64_GC_OBJ","S_V64_GC_ARR","S_V64_GC_SWEEP_OBJ",
        "S_V64_GC_SWEEP_ARR","S_V64_GC_FN","S_V64_GC_ENV",
        "S_V64_GC_SWEEP_ENV","S_V64_CLEAR","S_V64_RECT",
        "S_V64_WAIT_FRAME","S_V64_FRAME_RAF","S_V64_FRAME_TIMER",
        "S_V64_FOREACH","S_V64_FRAME_KEY","S_V64_STRIDX","S_V64_STRIDX_WR",
        "S_V64_JSON","S_V64_JSON_PARSE","S_V64_CTOR_PAD",
        "S_HEAP_WAIT","S_HEAP_CMP","S_HEAP_WR","S_HEAP_AWR","S_HEAP_FILL",
        "S_V64_METH","S_V64_FE_ELEM","S_V64_FE_FILTER","S_V64_OGETI_NAT",
        "S_V64_IDXSCAN","S_V64_CTOR_ENV","S_V64_CTOR_VARS","S_REL_ENV","S_FREE_OBJ","S_FREE_ARR",
        "S_V64_BIND","S_V64_MINMAX","S_V64_WIN_FILL","S_ARR_PROMOTE",
        "S_V64_RECT_LD","S_HEAP_CLR"
    };
    if (s < (unsigned)(sizeof(N) / sizeof(N[0]))) return N[s];
    return "?";
}

static void tick() {
    top->clk = 0; top->pixel_clk = 0; top->eval();
    uint8_t miso = 1;
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
    top->clk = 1; top->pixel_clk = 1; top->eval();
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
    if (watch_slot >= 0) {
        int32_t v = int32_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__vars[watch_slot]);
        if (v != watch_prev) {
            std::cerr << "VARW slot=" << watch_slot << " " << watch_prev << "->" << v
                      << " ip=" << unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip)
                      << " state=" << unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state)
                      << "\n";
            watch_prev = v;
        }
    }
    {
        unsigned st_ = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state);
        if (st_ < 128) state_prof[st_]++;
        prof_cycles++;
    }
    if (env_watch >= 0) {
        // Watch slots 0..7 so a re-alloc into a neighbour is visible too.
        auto* rr = top->rootp;
        for (int sl = 0; sl < 8; sl++) {
            unsigned v = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
            if (v != env_prev[sl]) {
                if (env_evts.size() < 64)
                    env_evts.push_back({unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state),
                                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip),
                                        (v << 8) | unsigned(sl),
                                        uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__venv)});
                env_prev[sl] = v;
            }
        }
    }
    {
        // NEW: rolling cycle ring for fault forensics (VRING?). Freezes the
        // instant fault_code goes nonzero so the ring holds the run-up.
        auto* rr = top->rootp;
        static unsigned run_prev = 0;
        unsigned run_now = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__running);
        if (!vring_frozen && rr->jmr_js_core__DOT__u_vm__DOT__fault_code)
            vring_frozen = true;
        // Also freeze on the running 1->0 edge: a clean halt (no fault code)
        // otherwise leaves no evidence of what stopped the machine.
        if (!vring_frozen && run_prev && !run_now)
            vring_frozen = true;
        run_prev = run_now;
        if (!vring_frozen)
        vring[vring_i & 255] = {
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__venv),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_valid_rdata),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__valloc_kind),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_proto_arm),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vsp),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[0]),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[1]),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[2]),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcsp),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vcsp),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd_q)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd2_q) << 1)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd3_q) << 2)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hash2_q) << 3)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__cm_win) << 4),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state)};
        if (ring_stop_ip >= 0 &&
            int(rr->jmr_js_core__DOT__u_vm__DOT__ip) == ring_stop_ip)
            vring_frozen = true;
        if (!vring_frozen) vring_i++;
    }
    if (ip_trace.size() < ip_trace_cap) {
        uint16_t cur = uint16_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip);
        if (cur != ip_trace_prev) {
            ip_trace.push_back(cur);
            ip_trace_prev = cur;
        }
    }
    {
        auto* r = top->rootp;
        unsigned fc = unsigned(r->jmr_js_core__DOT__u_vm__DOT__fault_code);
        if (fc == 0)
            fault_snap_code = 0;
        else if (fault_snap_code == 0) {
            // Use pre-NBA hold: opcode comb saw last cycle's rdata/raddr.
            fault_snap_code = fc;
            fault_snap_raddr = fault_hold_raddr;
            fault_snap_valid = fault_hold_valid;
            fault_snap_gen = fault_hold_gen;
            fault_snap_akind = fault_hold_akind;
            fault_snap_ai = fault_hold_ai;
            fault_snap_vsp = fault_hold_vsp;
            fault_snap_vcsp = fault_hold_vcsp;
            fault_snap_hvcsp = fault_hold_hvcsp;
            fault_snap_opnd = fault_hold_opnd;
            fault_snap_w0 = fault_hold_w0;
            fault_snap_cr = fault_hold_cr;
        }
        fault_hold_raddr = unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_vfn_raddr);
        fault_hold_valid = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid_rdata);
        fault_hold_gen = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen_rdata);
        fault_hold_akind = unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_kind);
        fault_hold_ai = unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_i);
        fault_hold_vsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
        fault_hold_vcsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vcsp);
        fault_hold_hvcsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hs_m_vcsp);
        fault_hold_opnd =
            (unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd_q) << 1) |
            unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd2_q);
        fault_hold_w0 = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[0]);
        fault_hold_cr = uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_rdata);
    }
}

static void ticks(int n) {
    for (int i = 0; i < n; i++) tick();
}

static int read_whole_file(const std::string& path, std::vector<uint8_t>& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return -1;
    f.seekg(0, std::ios::end);
    std::streamoff n = f.tellg();
    if (n < 0) return -1;
    f.seekg(0, std::ios::beg);
    out.resize((size_t)n);
    if (n && !f.read(reinterpret_cast<char*>(out.data()), n)) return -1;
    return 0;
}

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static uint64_t fnv_byte(uint64_t hash, uint8_t value) {
    return (hash ^ value) * UINT64_C(0x100000001B3);
}

static uint64_t fnv_u16(uint64_t hash, uint16_t value) {
    hash = fnv_byte(hash, (uint8_t)value);
    return fnv_byte(hash, (uint8_t)(value >> 8));
}

static uint64_t fnv_u32(uint64_t hash, uint32_t value) {
    hash = fnv_u16(hash, (uint16_t)value);
    return fnv_u16(hash, (uint16_t)(value >> 16));
}

static uint64_t fnv_u64(uint64_t hash, uint64_t value) {
    hash = fnv_u32(hash, (uint32_t)value);
    return fnv_u32(hash, (uint32_t)(value >> 32));
}

// NEW: poke compiled .JSH into code BRAM + asset SRAM (no simulated SPI).
static int jsh_load_mem(const std::vector<uint8_t>& b) {
    if (b.size() < 12 || b[0] != 'J' || b[1] != 'S' || b[2] != 'B' || b[3] != '1')
        return -1;
    uint16_t flags = (uint16_t)b[10] | ((uint16_t)b[11] << 8);
    uint32_t aset_off = 0;
    bool has_aset = (flags & 2) != 0;
    if (has_aset) {
        if (b.size() < 16) return -1;
        aset_off = (uint32_t)b[12] | ((uint32_t)b[13] << 8)
                 | ((uint32_t)b[14] << 16) | ((uint32_t)b[15] << 24);
    }
    size_t code_len = has_aset && aset_off > 0 && aset_off <= b.size()
                    ? (size_t)aset_off : b.size();
    auto* rp = top->rootp;
    const size_t CODE_WORDS = 32768;
    for (size_t w = 0; w < CODE_WORDS; w++) {
        size_t i = w * 4;
        uint32_t word = 0;
        if (i < code_len) {
            word = b[i];
            if (i + 1 < code_len) word |= (uint32_t)b[i + 1] << 8;
            if (i + 2 < code_len) word |= (uint32_t)b[i + 2] << 16;
            if (i + 3 < code_len) word |= (uint32_t)b[i + 3] << 24;
        }
        rp->jmr_js_core__DOT__u_vm__DOT__code_mem[w] = word;
    }
    if (has_aset && aset_off + 8 <= b.size()
        && b[aset_off] == 'A' && b[aset_off + 1] == 'S'
        && b[aset_off + 2] == 'E' && b[aset_off + 3] == 'T') {
        uint32_t plen = (uint32_t)b[aset_off + 4]
                      | ((uint32_t)b[aset_off + 5] << 8)
                      | ((uint32_t)b[aset_off + 6] << 16)
                      | ((uint32_t)b[aset_off + 7] << 24);
        size_t poff = aset_off + 8;
        if (plen > b.size() - poff) plen = (uint32_t)(b.size() - poff);
        if (plen > 4u * 1024u * 1024u) plen = 4u * 1024u * 1024u;
        for (uint32_t i = 0; i + 1 < plen; i += 2) {
            uint16_t w = (uint16_t)b[poff + i]
                       | ((uint16_t)b[poff + i + 1] << 8);
            rp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[i / 2] = w;
        }
        if (plen & 1u)
            rp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[plen / 2] =
                (uint16_t)b[poff + plen - 1];
        uint32_t pal_n = plen < 768u ? plen : 768u;
        for (uint32_t pi = 0; pi + 2 < pal_n; pi += 3) {
            uint32_t rgb = ((uint32_t)b[poff + pi] << 16)
                         | ((uint32_t)b[poff + pi + 1] << 8)
                         | (uint32_t)b[poff + pi + 2];
            rp->jmr_js_core__DOT__u_palette__DOT__mem[pi / 3] = rgb;
        }
    }
    return 0;
}

static void push_key(uint8_t b) {
    top->kbd_data = b;
    top->kbd_push = 1;
    tick();
    top->kbd_push = 0;
    tick();
}

static std::string screen_text() {
    std::ostringstream oss;
    for (int row = 0; row < 16; row++) {
        std::string line;
        line.reserve(64);
        for (int col = 0; col < 64; col++) {
            top->dump_addr = (row << 6) | col;
            tick();
            char ch = char(top->dump_data & 0xff);
            if (ch < 32 || ch > 126) ch = ' ';
            line.push_back(ch);
        }
        while (!line.empty() && line.back() == ' ') line.pop_back();
        oss << line;
        if (row != 15) oss << "\\n";
    }
    return oss.str();
}

// NEW: export native 640×480 game FB (no ×4 upsample — FB is glass size)
static std::string fb_export_b64() {
    constexpr int W = 640, H = 480;
    std::vector<uint8_t> full((size_t)W * H, 0);
    // Direct front-bank read. S_IMGD_GET holds dump_sel for up to 307200
    // cycles, so walking dump_fb_raddr sampled GET's address (and 614k extra
    // ticks ran the VM past the FRAME swap — full-canvas fillRect looked
    // black). FBBANK? already reads mem0/mem1 this way.
    auto* r = top->rootp;
    unsigned front = unsigned(r->jmr_js_core__DOT__u_fb__DOT__front);
    for (int i = 0; i < W * H; i++)
        full[(size_t)i] = front
            ? (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__mem0[i]
            : (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__mem1[i];
    return b64_encode(full.data(), full.size());
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    sd_load_image();
    top = new Vjmr_js_core;
    top->rst_n = 0;
    top->standalone_mode = 1;
    top->pixel_clk = 0;
    top->kbd_push = 0;
    top->kbd_data = 0;
    top->joy_in = 0;
    top->dump_addr = 0;
    top->scan_addr = 0;
    top->fb_raddr = 0;
    top->pal_raddr = 0;
    top->sd_miso = 1;
    top->sim_vm_start = 0;
    top->sim_frame_pulse = 0;
    top->jsb_tether_stb = 0;
    top->jsb_tether_data = 0;
    top->jsb_tether_eof = 0;
    top->sim_src_bypass = 0;
    top->sim_src_lines = 0;
    ticks(8);
    top->rst_n = 1;
    ticks(200000);
    std::cout << "READY" << std::endl;

    std::string line;
    // ProgramImage is streamed over the existing line RPC. It never becomes a
    // host-side .JSB/.JSH file; RUN's source of truth remains the loaded HTML.
    std::vector<uint8_t> program_image;
    size_t program_expected = 0;
    while (std::getline(std::cin, line)) {
        if (line == "QUIT") {
            std::cout << "BYE" << std::endl;
            break;
        }
        // Compile-on-RUN: host rewrote card.img .JSH; reload SPI image before FAT OPEN
        // Compile-on-RUN: host rewrote card.img; reload SPI image before FAT OPEN.
        // Do not sd_save_image first — boot/mount may have set dirty, and that
        // flush would overwrite the host patch (new 8.3 names vanished: ?FN).
        if (line == "SDRELOAD") {
            sd.dirty = false;
            sd_load_image();
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROGBEGIN ", 0) == 0) {
            program_expected = (size_t)std::strtoull(line.c_str() + 10, nullptr, 10);
            if (program_expected < 12 || program_expected > (4u * 1024u * 1024u + 256u * 1024u)) {
                program_expected = 0;
                program_image.clear();
                std::cout << "ERR size" << std::endl;
                continue;
            }
            program_image.clear();
            program_image.reserve(program_expected);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROGDATA ", 0) == 0) {
            const std::string hex = line.substr(9);
            if (!program_expected || (hex.size() & 1u)
                || program_image.size() + hex.size() / 2 > program_expected) {
                std::cout << "ERR data" << std::endl;
                continue;
            }
            bool good = true;
            for (size_t i = 0; i < hex.size(); i += 2) {
                int hi = hex_nibble(hex[i]);
                int lo = hex_nibble(hex[i + 1]);
                if (hi < 0 || lo < 0) {
                    good = false;
                    break;
                }
                program_image.push_back((uint8_t)((hi << 4) | lo));
            }
            if (!good) {
                program_image.clear();
                program_expected = 0;
                std::cout << "ERR hex" << std::endl;
                continue;
            }
            std::cout << "OK bytes=" << program_image.size() << std::endl;
            continue;
        }
        if (line == "PROGSTART") {
            if (!program_expected || program_image.size() != program_expected
                || jsh_load_mem(program_image) != 0) {
                std::cout << "ERR image" << std::endl;
                continue;
            }
            push_key(0x1B);
            ticks(8);
            top->sim_vm_start = 1;
            tick();
            top->sim_vm_start = 0;
            ticks(64);
            std::cout << "OK bytes=" << program_image.size() << std::endl;
            continue;
        }
        // NEW: RAM-load compiled .JSH (code BRAM + ASET SRAM). No FAT SPI.
        if (line.rfind("JSHLOAD ", 0) == 0) {
            std::vector<uint8_t> blob;
            if (read_whole_file(line.substr(8), blob) != 0 || jsh_load_mem(blob) != 0) {
                std::cout << "ERR" << std::endl;
                continue;
            }
            push_key(0x1B);
            ticks(8);
            top->sim_vm_start = 1;
            tick();
            top->sim_vm_start = 0;
            ticks(64);
            std::cout << "OK bytes=" << blob.size() << std::endl;
            continue;
        }
        // NEW: FPGA-SIM LOAD of host HTML → source BRAM (no SPI of fat files).
        if (line.rfind("SRCLOAD ", 0) == 0) {
            std::vector<uint8_t> html;
            std::string path = line.substr(8);
            if (read_whole_file(path, html) != 0) {
                std::cout << "ERR" << std::endl;
                continue;
            }
            auto* rp = top->rootp;
            const size_t SRC_MAX = 131072;
            size_t n = html.size() < SRC_MAX ? html.size() : SRC_MAX;
            for (size_t i = 0; i < n; i++)
                rp->jmr_js_core__DOT__u_cons__DOT__source_mem[i] = html[i];
            rp->jmr_js_core__DOT__u_cons__DOT__src_len = (uint32_t)n;
            std::string base = path;
            auto slash = base.find_last_of("/\\");
            if (slash != std::string::npos) base = base.substr(slash + 1);
            for (char& c : base)
                if (c >= 'a' && c <= 'z') c = (char)(c - 32);
            size_t nlen = base.size() < 16 ? base.size() : 16;
            rp->jmr_js_core__DOT__u_cons__DOT__src_name_len = (uint8_t)nlen;
            for (size_t i = 0; i < 16; i++)
                rp->jmr_js_core__DOT__u_cons__DOT__src_name[i] =
                    (i < nlen) ? (uint8_t)base[i] : (uint8_t)0;
            unsigned nlines = 0;
            for (uint8_t c : html)
                if (c == '\n') nlines++;
            if (html.empty() || html.back() != '\n') nlines++;
            // NEW: do NOT paint the glass here. Arm the console bypass and let
            // the host send the normal `LINE LOAD "NAME"` — the console echoes
            // the typed line and prints LOADED at the cursor (no row hopping,
            // no swallowed command line).
            top->sim_src_lines = (uint16_t)nlines;
            top->sim_src_bypass = 1;
            ticks(2);
            std::cout << "OK bytes=" << html.size() << " lines=" << nlines << std::endl;
            continue;
        }
        if (line.rfind("KEY ", 0) == 0) {
            unsigned v = std::stoul(line.substr(4), nullptr, 16);
            push_key(uint8_t(v));
            ticks(5000);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("LINE ", 0) == 0) {
            std::string text = line.substr(5);
            for (char c : text) push_key(uint8_t(c));
            push_key(0x0D);
            // Tick until prompt, game_mode (RUN started), or -- MORE --.
            // Missing game_mode burned the full 100M-clock cap after RUN.
            unsigned clk = 0;
            int capped = 1;
            int game_slices = 0;
            for (int i = 0; i < 400; ++i) {
                ticks(250000);
                clk += 250000;
                if (top->ready_lit) { capped = 0; break; }
                // RUN: stop shortly after game_mode (not another 100M clocks).
                // A few extra slices let boot rAF (DONKEY Enter at frames 4/12) run.
                if (top->game_mode) {
                    game_slices++;
                    if (game_slices >= 16) { capped = 0; break; }
                }
                if ((i & 3) == 3) {
                    std::string s = screen_text();
                    if (s.find("-- MORE") != std::string::npos) { capped = 0; break; }
                }
            }
            sd_save_image();
            // NEW: SRCLOAD's LOAD-without-FAT arm is one command long.
            top->sim_src_bypass = 0;
            std::cout << "OK clk=" << clk << " capped=" << capped << std::endl;
            continue;
        }
        if (line.rfind("JOY ", 0) == 0) {
            unsigned v = std::stoul(line.substr(4), nullptr, 0);
            top->joy_in = v & 0x3f;
            ticks(2);
            std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: KEYBITS = play bits (Left=4 Right=8 Fire=16). Assign joy_in;
        // GUI must not follow with JOY 0 (that wiped arrows/Space).
        if (line.rfind("KEYBITS ", 0) == 0) {
            unsigned v = std::stoul(line.substr(8), nullptr, 0);
            top->joy_in = v & 0x3f;
            ticks(2);
            std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: KEYEVT <keyCode> <down> — raw keyboard event for games
        // (GUI forwards real keys; the HTML decides bindings)
        if (line.rfind("KEYEVT ", 0) == 0) {
            unsigned code = 0, down = 0;
            std::sscanf(line.c_str() + 7, "%u %u", &code, &down);
            top->key_evt_code = code & 0xFF;
            top->key_evt_down = down ? 1 : 0;
            top->key_evt_stb = 1;
            ticks(1);
            top->key_evt_stb = 0;
            ticks(1);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "SCREEN?") {
            std::cout << "SCREEN " << screen_text() << std::endl;
            continue;
        }
        if (line == "STATUS?") {
            std::cout << "STATUS running=" << unsigned(top->game_mode)
                      << " ready=" << unsigned(top->ready_lit)
                      << " joy=" << unsigned(top->joy_out) << std::endl;
            continue;
        }
        if (line == "RUNCLK" || line == "TICK") {
            ticks(1000);
            if (line == "TICK") std::cout << "FB SAME" << std::endl;
            else std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: TICKN <n> — n×1000 clocks in one RPC (DONKEY's 2.4 MB .JSH
        // FAT+SRAM stream needs millions of clocks; per-TICK RPC is too slow)
        if (line.rfind("TICKN ", 0) == 0) {
            unsigned n = 1;
            std::sscanf(line.c_str() + 6, "%u", &n);
            if (n > 100000u) n = 100000u;
            ticks(1000u * n);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROMPT ", 0) == 0) {
            std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: minimal VM probe for RTL bring-up (state/ip/raf/heap counters)
        if (line == "VMSTAT?") {
            auto* r = top->rootp;
            unsigned stn = unsigned(r->jmr_js_core__DOT__u_vm__DOT__state);
            std::cout << "VMSTAT state=" << stn
                      << " sname=" << vm_sname(stn)
                      << " ip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip)
                      << " nops=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_ops)
                      << " eip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip)
                      << " sp=" << ((unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u)
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__sp))
                      << " vcsp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp)
                      << " vret=";
            {
                unsigned nfr = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp);
                if (nfr > 16u) nfr = 16u;
                for (unsigned i = 0; i < nfr; i++) {
                    if (i) std::cout << ",";
                    std::cout << unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vframe_return_ip[i]);
                }
            }
            std::cout << " vdraw="
                      << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_x)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_y)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_w)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_h)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_color)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_i)
                      << " raf=" << ((unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u)
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__raf_n))
                      << " obj=";
            if (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) {
                unsigned nlive = 0;
                for (unsigned i = 0; i < VM_MAX_OBJ; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[i] == 1)
                        nlive++;
                std::cout << nlive;
            } else
                std::cout << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj);
            std::cout
                      << " arr=";
            if (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) {
                unsigned narr = 0;
                for (unsigned i = 0; i < VM_MAX_ARR; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__varr_valid[i])
                        narr++;
                std::cout << narr;
            } else
                std::cout << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_arr);
            std::cout
                      << " spr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_spr)
                      << " kd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kd_fn)
                      << " lsn=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                      << " kscan=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_scan)
                      << " kcall=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_call)
                      << " kalloc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_alloc)
                      << " fsite=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__fault_site)
                      << " badst=" << vm_sname(unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_bad_state))
                      << " align=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_align)
                      << " evkey=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_evkey)
                      << " txtw=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_txtw)
                      << " fontpx=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__ctx_font_px)
                      << " kcmp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_cmp)
                      << " efault=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__machine_fault)
                      << " ecode=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__fault_code)
                      << " kevq=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kev_rp)
                      << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kev_wp)
                      << " idkd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_id_keydown)
                      << " idku=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_id_keyup)
                      << " spr0=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__spr_nid[0])
                      << " dihit=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_hit)
                      << " dimiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_miss)
                      // NEW: join/path bring-up counters (PACMAN maze debug)
                      << " joinmiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_join_miss)
                      << " pathovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_path_ovf)
                      << " heapovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_heap_ovf)
                      << " toovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_to_ovf)
                      << " spovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_stack_ovf)
                      << " cspovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_call_ovf)
                      << " fault=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__fault_code)
                      << " gc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_gc_n)
                      << " jsonovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_json_ovf)
                      << " swaps=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n)
                      // NEW: interned string bytes loaded from the trailer (str[i])
                      << " strb=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__nb_wp)
                      << " strovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_str_ovf)
                      // NEW: ip where the last frame callback returned (dead loop)
                      << " cbip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_cb_ip)
                      // NEW: timers dropped because the queued oid was no longer a Fn
                      << " tmis=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_mis)
                      << " tsch=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_sched)
                      << " tfire=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_fire)
                      << " ton=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__to_n)
                      << " esp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_sp)
                      << " efree=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_free_n)
                      << " findh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_find_hit)
                      << " spln=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_splice_n)
                      << " divs=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_div_n)
                      << " fclk=" << last_fclk
                      << " fcap=" << last_fcap
                      << " fcaps=" << fcap_n
                      << " imgd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_i)
                      << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_n)
                      << " imgwh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_w)
                      << "x" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_h)
                      // Compact HEAP/env peek: nested STORE_VAR hung in HEAP_CMP.
                      << " hp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_cmd)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_env)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_slot)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_len)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_phase)
                      << " venvk=" << unsigned(
                            (r->jmr_js_core__DOT__u_vm__DOT__venv >> 44) & 0xF)
                      << " venvi=" << unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv & 0x3FF)
                      << " vp=" << unsigned(
                            (r->jmr_js_core__DOT__u_vm__DOT__venv_parent[
                                unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid) & 511u] >> 44) & 0xF)
                      << "," << unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv_parent[
                                unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid) & 511u] & 0x3FF)
                      << " lh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_leave_hold)
                      << std::endl;
            continue;
        }
        // Canonical safe-point checkpoint for Python/RTL differential tests.
        // Keep this one compact: detailed OBJPEEK/VARPEEK remain opt-in.
        if (line == "CHECKPOINT?") {
            auto* r = top->rootp;
            const uint64_t FNV0 = UINT64_C(0xCBF29CE484222325);
            const bool value64 =
                (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) != 0;
            uint64_t vars_hash = FNV0;
            if (value64) {
                const uint64_t uninitialized = UINT64_C(0x7FF9F00000000000);
                for (unsigned i = 0; i < 512u; i++) {
                    uint64_t word =
                        r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[i]
                        ? (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vvars[i]
                        : uninitialized;
                    vars_hash = fnv_u64(vars_hash, word);
                }
            } else {
                for (unsigned i = 0; i < 512u; i++) {
                    vars_hash = fnv_u32(
                        vars_hash,
                        (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vars[i]
                    );
                    vars_hash = fnv_byte(
                        vars_hash,
                        (uint8_t)r->jmr_js_core__DOT__u_vm__DOT__var_tag[i]
                    );
                }
            }
            uint64_t heap_hash = FNV0;
            if (value64) {
                heap_hash = fnv_byte(heap_hash, 'H');
                heap_hash = fnv_byte(heap_hash, '6');
                heap_hash = fnv_byte(heap_hash, '4');
                heap_hash = fnv_byte(heap_hash, 1);
                bool marked_strings[1024] = {};
                auto mark_string = [&](uint64_t word) {
                    if ((word >> 48) == UINT64_C(0x7ff9)
                        && ((word >> 44) & 0xfu) == 4u
                        && (uint32_t)word < 1024u)
                        marked_strings[(uint32_t)word] = true;
                };
                for (unsigned i = 0; i < 512u; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[i])
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vvars[i]);
                unsigned checkpoint_sp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
                for (unsigned i = 0; i < checkpoint_sp; i++)
                    mark_string(peek_vstack(r, i, checkpoint_sp));
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    unsigned kind = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[index]
                    );
                    if (kind == 1u) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_len[index]
                        );
                        if (length > VM_OBJ_SLOTS) length = VM_OBJ_SLOTS;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_vobj_val(r, index, slot));
                    }
                    if (r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[index]) {
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vfn_env[index]);
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vfn_bound_this[index]);
                    }
                }
                for (unsigned index = 0; index < VM_MAX_ARR; index++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__varr_valid[index]) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__varr_len[index]
                        );
                        if (length > VM_ARR_CAP) length = VM_ARR_CAP;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_varr_val(r, index, slot));
                    }
                for (unsigned index = 0; index < VM_ENV_DEPTH; index++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__venv_valid[index]) {
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__venv_parent[index]);
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv_len[index]
                        );
                        if (length > VM_ENV_SLOTS) length = VM_ENV_SLOTS;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_venv_val(r, index, slot));
                    }
                for (unsigned index = 0; index < 1024u; index++)
                    if (marked_strings[index]) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__name_len_tbl[index]
                        );
                        unsigned offset = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__name_off[index]
                        );
                        heap_hash = fnv_byte(heap_hash, 'S');
                        heap_hash = fnv_u32(heap_hash, index);
                        heap_hash = fnv_u32(heap_hash, length);
                        for (unsigned byte = 0; byte < length; byte++)
                            heap_hash = fnv_byte(
                                heap_hash,
                                (uint8_t)r->jmr_js_core__DOT__u_vm__DOT__name_mem[
                                    offset + byte
                                ]
                            );
                    }
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    if (unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[index]
                        ) != 1u)
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vobj_len[index]
                    );
                    if (length > VM_OBJ_SLOTS) length = VM_OBJ_SLOTS;
                    heap_hash = fnv_byte(heap_hash, 'O');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vobj_gen[index]
                    );
                    heap_hash = fnv_u32(heap_hash, length);
                    {
                        // PYTHON checkpoint packs class name index or -1.
                        uint16_t cls = (uint16_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_cls[index];
                        heap_hash = fnv_u32(
                        heap_hash,
                        cls == 0xFFFFu ? UINT32_C(0xFFFFFFFF)
                                       : (uint32_t)cls
                    );
                    }
                    {
                        uint8_t builtin = (uint8_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_builtin[index];
                        heap_hash = fnv_u32(
                            heap_hash,
                            builtin == 0u ? UINT32_C(0xFFFFFFFF)
                                          : (uint32_t)builtin
                        );
                    }
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    std::vector<std::pair<uint32_t, uint64_t>> fields;
                    fields.reserve(length);
                    for (unsigned slot = 0; slot < length; slot++) {
                        fields.emplace_back(
                            (uint32_t)peek_vobj_key(r, index, slot),
                            peek_vobj_val(r, index, slot)
                        );
                    }
                    std::sort(fields.begin(), fields.end());
                    for (const auto& field : fields) {
                        heap_hash = fnv_u32(heap_hash, field.first);
                        heap_hash = fnv_u64(heap_hash, field.second);
                    }
                }
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[index])
                        continue;
                    heap_hash = fnv_byte(heap_hash, 'F');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[index]
                    );
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_nparam[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_env[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_bound_this[index]
                    );
                    unsigned flags = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vfn_flags[index]
                    );
                    heap_hash = fnv_byte(heap_hash, flags & 1u);
                    heap_hash = fnv_byte(heap_hash, (flags >> 1) & 1u);
                    heap_hash = fnv_byte(heap_hash, (flags >> 2) & 1u);
                    heap_hash = fnv_u32(
                        heap_hash,
                        (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[index]
                    );
                }
                for (unsigned index = 0; index < VM_MAX_ARR; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__varr_valid[index])
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__varr_len[index]
                    );
                    if (length > VM_ARR_CAP) length = VM_ARR_CAP;
                    heap_hash = fnv_byte(heap_hash, 'A');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__varr_gen[index]
                    );
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    for (unsigned element = 0; element < length; element++) {
                        heap_hash = fnv_u64(
                            heap_hash,
                            peek_varr_val(r, index, element)
                        );
                    }
                }
                for (unsigned index = 0; index < VM_ENV_DEPTH; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__venv_valid[index])
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__venv_len[index]
                    );
                    if (length > VM_ENV_SLOTS) length = VM_ENV_SLOTS;
                    heap_hash = fnv_byte(heap_hash, 'E');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__venv_gen[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__venv_parent[index]
                    );
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    std::vector<std::pair<uint16_t, uint64_t>> slots;
                    slots.reserve(length);
                    for (unsigned slot = 0; slot < length; slot++) {
                        slots.emplace_back(
                            peek_venv_key(r, index, slot),
                            peek_venv_val(r, index, slot)
                        );
                    }
                    std::sort(slots.begin(), slots.end());
                    for (const auto& slot : slots) {
                        heap_hash = fnv_u16(heap_hash, slot.first);
                        heap_hash = fnv_u64(heap_hash, slot.second);
                    }
                }
            } else {
                unsigned nobj = unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj);
                if (nobj > VM_MAX_OBJ) nobj = VM_MAX_OBJ;
                for (unsigned oid = 0; oid < nobj; oid++) {
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__obj_cls[oid]
                    );
                    unsigned ns = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__obj_n[oid]
                    );
                    if (ns > VM_OBJ_SLOTS) ns = VM_OBJ_SLOTS;
                    heap_hash = fnv_byte(heap_hash, (uint8_t)ns);
                    for (unsigned slot = 0; slot < ns; slot++) {
                        heap_hash = fnv_u16(
                            heap_hash,
                            (uint16_t)peek_vobj_key(r, oid, slot)
                        );
                        heap_hash = fnv_u32(
                            heap_hash,
                            (uint32_t)peek_vobj_val(r, oid, slot)
                        );
                        heap_hash = fnv_byte(
                            heap_hash,
                            peek_vobj_tag(r, oid, slot)
                        );
                    }
                }
                unsigned narr = unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_arr);
                if (narr > VM_MAX_ARR) narr = VM_MAX_ARR;
                for (unsigned aid = 0; aid < narr; aid++) {
                    unsigned len = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__arr_len[aid]
                    );
                    if (len > VM_ARR_CAP) len = VM_ARR_CAP;
                    heap_hash = fnv_byte(heap_hash, (uint8_t)len);
                    for (unsigned elem = 0; elem < len; elem++) {
                        heap_hash = fnv_u32(
                            heap_hash,
                            (uint32_t)peek_varr_val(r, aid, elem)
                        );
                        heap_hash = fnv_byte(
                            heap_hash,
                            peek_varr_tag(r, aid, elem)
                        );
                    }
                }
            }
            uint64_t canvas_hash = FNV0;
            unsigned front = unsigned(r->jmr_js_core__DOT__u_fb__DOT__front);
            for (unsigned i = 0; i < 307200u; i++) {
                uint8_t px = front
                    ? (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__mem0[i]
                    : (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__mem1[i];
                canvas_hash = fnv_byte(canvas_hash, px);
            }
            uint64_t frames_hash = FNV0;
            uint64_t queues_hash = FNV0;
            if (value64) {
                frames_hash = fnv_byte(frames_hash, 'F');
                frames_hash = fnv_byte(frames_hash, '6');
                frames_hash = fnv_byte(frames_hash, '4');
                frames_hash = fnv_byte(frames_hash, 1);
                frames_hash = fnv_u64(
                    frames_hash,
                    (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vthis
                );
                frames_hash = fnv_u64(
                    frames_hash,
                    (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__venv
                );
                unsigned value_sp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
                unsigned value_csp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp);
                frames_hash = fnv_u16(frames_hash, (uint16_t)value_sp);
                for (unsigned slot = 0; slot < value_sp; slot++) {
                    frames_hash = fnv_u64(
                        frames_hash,
                        peek_vstack(r, slot, value_sp)
                    );
                }
                frames_hash = fnv_u16(frames_hash, (uint16_t)value_csp);
                for (unsigned frame = 0; frame < value_csp; frame++) {
                    frames_hash = fnv_u32(
                        frames_hash,
                        (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_return_ip[frame]
                    );
                    frames_hash = fnv_u16(
                        frames_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_base_sp[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_this[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_env[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_fn[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_ctor[frame]
                    );
                }
                queues_hash = fnv_byte(queues_hash, 'Q');
                queues_hash = fnv_byte(queues_hash, '6');
                queues_hash = fnv_byte(queues_hash, '4');
                queues_hash = fnv_byte(queues_hash, 1);
                queues_hash = fnv_u32(
                    queues_hash,
                    (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_no
                );
                queues_hash = fnv_u32(
                    queues_hash,
                    (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_seq
                );
                queues_hash = fnv_byte(queues_hash, 0); // startLoop
                unsigned value_raf =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n);
                queues_hash = fnv_u16(queues_hash, (uint16_t)value_raf);
                for (unsigned slot = 0; slot < value_raf; slot++)
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vraf[slot]
                    );
                struct TimerCheckpoint {
                    int32_t due;
                    int32_t sequence;
                    int64_t period;
                    uint64_t function;
                };
                std::vector<TimerCheckpoint> timers;
                for (unsigned slot = 0; slot < 64u; slot++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vtimer_valid[slot])
                        timers.push_back({
                            (int32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_due[slot],
                            (int32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_id[slot],
                            (int64_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_period[slot],
                            (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_fn[slot],
                        });
                std::sort(
                    timers.begin(), timers.end(),
                    [](const TimerCheckpoint& a, const TimerCheckpoint& b) {
                        return a.sequence < b.sequence;
                    }
                );
                queues_hash = fnv_u16(
                    queues_hash, (uint16_t)timers.size()
                );
                for (const auto& timer : timers) {
                    queues_hash = fnv_u32(
                        queues_hash, (uint32_t)timer.due
                    );
                    queues_hash = fnv_u32(
                        queues_hash, (uint32_t)timer.sequence
                    );
                    queues_hash = fnv_u64(
                        queues_hash, (uint64_t)timer.period
                    );
                    queues_hash = fnv_u64(
                        queues_hash, timer.function
                    );
                }
                unsigned nlisten = unsigned(
                    r->jmr_js_core__DOT__u_vm__DOT__vlistener_n
                );
                if (nlisten > 16u) nlisten = 16u;
                queues_hash = fnv_u16(queues_hash, (uint16_t)nlisten);
                for (unsigned slot = 0; slot < nlisten; slot++) {
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vlistener_ev[slot]
                    );
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vlistener_fn[slot]
                    );
                }
            }
            unsigned ip = unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip);
            unsigned ops_base = unsigned(
                r->jmr_js_core__DOT__u_vm__DOT__ops_base
            );
            unsigned op = (ops_base + ip < 32768u)
                ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__code_mem[ops_base + ip] & 0xFFu)
                : 0u;
            unsigned error = unsigned(
                r->jmr_js_core__DOT__u_vm__DOT__fault_code
            );
            std::cout << "CHECKPOINT"
                      << " ip=" << ip
                      << " op=" << op
                      << " sp=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__sp))
                      << " csp=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__csp))
                      << " vars=" << std::hex << vars_hash
                      << " heap=" << heap_hash
                      << " canvas=" << canvas_hash << std::dec;
            if (value64) {
                std::cout << " ops_base=" << ops_base
                          << " frames=" << std::hex << frames_hash
                          << " queues=" << queues_hash << std::dec;
            }
            std::cout << " raf=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__raf_n))
                      << " timers=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vtimer_n)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__to_n))
                      << " listeners="
                      << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__kd_n
                                     + r->jmr_js_core__DOT__u_vm__DOT__ku_n))
                      << " error=" << error
                      << std::endl;
            continue;
        }
        // Opt-in TOS window (CPU truth). ARRAY_SET index is win[1].
        if (line == "STK?") {
            auto* r = top->rootp;
            unsigned vsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
            std::cout << "STK vsp=" << vsp << std::hex;
            for (unsigned i = 0; i < 8u; i++)
                std::cout << " w" << i << "="
                          << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[i]);
            // ctor0: NEW_OBJ frame[0].constructor_value (RET_VAL instance).
            std::cout << " ctor0="
                      << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vframe_ctor[0]);
            // rAF fault 4: is TOS Fn slot actually valid?
            std::cout << std::dec
                      << " vf0=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[0])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[0])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[0])
                      << " vf1=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[1])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[1])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[1]);
            std::cout << " fs=" << fault_snap_code
                      << ",ra=" << fault_snap_raddr
                      << ",rd=" << fault_snap_valid
                      << ",rg=" << fault_snap_gen
                      << ",ak=" << fault_snap_akind
                      << ",ai=" << fault_snap_ai
                      << ",sp=" << fault_snap_vsp
                      << ",ev=" << fault_snap_vcsp
                      << ",hv=" << fault_snap_hvcsp
                      << ",op=" << fault_snap_opnd
                      << std::hex
                      << ",w0=" << fault_snap_w0
                      << ",cr=" << fault_snap_cr
                      << std::dec;
            std::cout << std::endl;
            continue;
        }
        // NEW: OBJPEEK <oid> — dump one heap object (cls, n, key/val/tag slots)
        if (line.rfind("OBJPEEK ", 0) == 0) {
            auto* r = top->rootp;
            unsigned oid = std::stoul(line.substr(8)) & (VM_MAX_OBJ - 1);
            const bool value64 =
                (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) != 0;
            unsigned ns = value64
                ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vobj_len[oid])
                : unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_n[oid]);
            std::cout << "OBJ " << oid
                      << " cls=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_cls[oid])
                      << " n=" << ns
                      << " alloc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[oid]);
            // NEW: dump every live slot (was 6) — item objects carry ~20 props
            if (ns > VM_OBJ_SLOTS) ns = VM_OBJ_SLOTS;
            for (unsigned s = 0; s < ns; s++) {
                std::cout << " [" << s << "]k="
                          << unsigned(peek_vobj_key(r, oid, s))
                          << " v=" << std::hex
                          << peek_vobj_val(r, oid, s)
                          << std::dec
                          << " t=" << unsigned(peek_vobj_tag(r, oid, s));
            }
            std::cout << std::endl;
            continue;
        }
        // NEW: ENVSTAT? — env free list + keep watermark (bring-up only)
        if (line == "ENVSTAT?") {
            auto* r = top->rootp;
            std::cout << "ENVSTAT keep=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj_keep)
                      << " nobj=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj)
                      << " esp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_sp)
                      << " free_n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_free_n)
                      << " free=";
            unsigned fn2 = unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_free_n);
            for (unsigned i = 0; i < fn2 && i < 64; i++)
                std::cout << (i ? "," : "") << unsigned(r->jmr_js_core__DOT__u_vm__DOT__env_free[i]);
            std::cout << std::endl;
            continue;
        }
        // NEW: RAFPEEK? — queued rAF fn oids (bring-up only)
        if (line == "RAFPEEK?") {
            auto* r = top->rootp;
            std::cout << "RAF";
            for (unsigned i = 0; i < 8; i++)
                std::cout << " " << unsigned(r->jmr_js_core__DOT__u_vm__DOT__raf_fn[i]);
            std::cout << std::endl;
            continue;
        }
        // NEW: ARRPEEK <aid> — dump array len + elements (bring-up only)
        if (line.rfind("ARRPEEK ", 0) == 0) {
            auto* r = top->rootp;
            unsigned aid = std::stoul(line.substr(8));
            if (aid >= VM_MAX_ARR) aid = 0;
            unsigned len = unsigned(r->jmr_js_core__DOT__u_vm__DOT__arr_len[aid]);
            std::cout << "ARR " << aid << " len=" << len;
            if (len > VM_ARR_CAP) len = VM_ARR_CAP;
            for (unsigned s = 0; s < len; s++) {
                std::cout << " [" << s << "]v="
                          << int(peek_varr_val(r, aid, s))
                          << " t=" << unsigned(peek_varr_tag(r, aid, s));
            }
            std::cout << std::endl;
            continue;
        }
        // NEW: IPTRACE <n> arms; IPTRACE? dumps the executed-ip path
        if (line.rfind("IPTRACE ", 0) == 0) {
            ip_trace.clear();
            ip_trace_cap = std::stoul(line.substr(8));
            ip_trace_prev = 0xffff;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "IPTRACE?") {
            std::ostringstream oss;
            oss << "IPS";
            for (uint16_t v : ip_trace) oss << " " << v;
            ip_trace_cap = 0;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: VARWATCH <slot|-1> — arm/disarm the vars[] write watchpoint
        if (line.rfind("VARWATCH ", 0) == 0) {
            watch_slot = std::stoi(line.substr(9));
            if (watch_slot >= 0)
                watch_prev = int32_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__vars[watch_slot]);
            std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: VARPEEK <i> <n> — dump VM vars (bring-up only)
        if (line.rfind("VARPEEK ", 0) == 0) {
            unsigned a = 0, n = 8;
            std::sscanf(line.c_str() + 8, "%u %u", &a, &n);
            std::ostringstream oss;
            oss << "VARS";
            for (unsigned i = 0; i < n && (a + i) < 512u; i++)
                oss << " " << int32_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__vars[a + i]);
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: FBRAW? — nonzero counts of both FB banks + front bit (bring-up)
        // NEW: LSNPEEK? — key listener table (ev/fn handles) as registered
        if (line == "LSNPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "LSN n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                << " cmp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_cmp)
                << std::hex
                << " want=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_want)
                << " lastev=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_lastev);
            for (int i = 0; i < 8; i++)
                oss << " [" << std::dec << i << std::hex
                    << " ev=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vlistener_ev[i])
                    << " fn=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vlistener_fn[i]) << "]";
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: CHARPEEK? — byte -> 1-char intern id table (string index path)
        if (line == "CHARPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "CHAR";
            const char* probe = "01 abAB";
            for (const char* q = probe; *q; q++) {
                unsigned b = (unsigned char)*q;
                oss << " '" << *q << "'=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__char_ok[b])
                    << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__char_id[b]);
            }
            unsigned nok = 0;
            for (unsigned b = 0; b < 256; b++)
                if (r->jmr_js_core__DOT__u_vm__DOT__char_ok[b]) nok++;
            oss << " total_ok=" << nok;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: VENVPEEK? — current env handle vs the venv_valid/gen table
        if (line == "VENVPEEK?") {
            auto* r = top->rootp;
            uint64_t venv = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv);
            unsigned idx = unsigned(venv & 0x3FFu);
            std::ostringstream oss;
            oss << "VENV h=" << std::hex << venv << std::dec
                << " idx=" << idx
                << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[idx])
                << " gen=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_gen[idx])
                << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[idx])
                << " hgen=" << unsigned((venv >> 32) & 0xFFFu)
                << " gcpend=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend)
                << " gcword=" << std::hex << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vgc_mark_word) << std::dec
                << " bits=";
            for (unsigned i = 0; i < 24; i++)
                oss << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[i]);
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: VRING? — last 48 cycles of state/ip/venv/venv_valid_rdata
        if (line == "VRING?") {
            std::ostringstream oss;
            oss << "VRING";
            unsigned long n = vring_i < 48 ? vring_i : 48;
            for (unsigned long k = vring_i - n; k < vring_i; k++) {
                const VRingEnt& e = vring[k & 255];
                oss << " [" << vm_sname(e.st) << ">" << vm_sname(e.est)
                    << ":" << e.ip << " sp=" << e.vsp
                    << " f=" << e.flags << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line.rfind("ENVWATCH ", 0) == 0) {
            env_watch = std::stoi(line.substr(9));
            env_evts.clear();
            for (int sl = 0; sl < 8; sl++)
                env_prev[sl] = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "ENVWATCH?") {
            std::ostringstream oss;
            oss << "ENVW n=" << env_evts.size();
            for (const EnvEvt& e : env_evts)
                oss << " [" << vm_sname(e.st) << ":" << e.ip
                    << " slot" << (e.val & 0xFF) << "->" << (e.val >> 8)
                    << " cur=" << std::hex << (e.venv & 0x3FF) << std::dec << "]";
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line.rfind("RINGSTOP ", 0) == 0) {
            ring_stop_ip = std::stoi(line.substr(9));
            vring_frozen = false;
            vring_i = 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "PROFCLR") {
            for (int i = 0; i < 128; i++) state_prof[i] = 0;
            prof_cycles = 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "PROF?") {
            std::vector<std::pair<unsigned long, int>> v;
            for (int i = 0; i < 128; i++)
                if (state_prof[i]) v.push_back({state_prof[i], i});
            std::sort(v.rbegin(), v.rend());
            std::ostringstream oss;
            oss << "PROF cycles=" << prof_cycles;
            for (size_t k = 0; k < v.size() && k < 12; k++)
                oss << " " << vm_sname(unsigned(v[k].second)) << "="
                    << v[k].first
                    << "(" << (prof_cycles ? v[k].first * 100 / prof_cycles : 0) << "%)";
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "FBRAW?") {
            unsigned nz0 = 0, nz1 = 0;
            for (unsigned i = 0; i < 307200u; i++) {
                if (top->rootp->jmr_js_core__DOT__u_fb__DOT__mem0[i]) nz0++;
                if (top->rootp->jmr_js_core__DOT__u_fb__DOT__mem1[i]) nz1++;
            }
            std::cout << "FBRAW nz0=" << nz0 << " nz1=" << nz1
                      << " front=" << unsigned(top->rootp->jmr_js_core__DOT__u_fb__DOT__front)
                      << std::endl;
            continue;
        }
        // NEW: PDOPEEK? — first 16 latched path commands (op, p1x, p1y, p2x, p2y);
        // PDOCLR re-arms the latch (bring-up only)
        if (line == "PDOPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "PDO n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_pdo_n);
            for (int i = 0; i < 16; i++) {
                auto& w = r->jmr_js_core__DOT__u_vm__DOT__dbg_pdo[i];
                unsigned op = (unsigned)((w[2] >> 0) & 0x3);
                int16_t p1x = (int16_t)((w[1] >> 16) & 0xFFFF);
                int16_t p1y = (int16_t)(w[1] & 0xFFFF);
                int16_t p2x = (int16_t)((w[0] >> 16) & 0xFFFF);
                int16_t p2y = (int16_t)(w[0] & 0xFFFF);
                oss << " [" << op << ":" << p1x << "," << p1y << "," << p2x << "," << p2y << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "PDOCLR") {
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_pdo_n = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_rect_n = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_line_px = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_circ_px = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_rect_px = 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        // NEW: PXCNT? — raster px counters since PDOCLR (flood hunt)
        if (line == "PXCNT?") {
            auto* r = top->rootp;
            std::cout << "PX line=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_line_px)
                      << " circ=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_circ_px)
                      << " rect=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_rect_px)
                      << std::endl;
            continue;
        }
        // NEW: RECTPEEK? — first 16 latched rect rasterizations
        if (line == "RECTPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "RECT n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_rect_n);
            for (int i = 0; i < 64; i++) {
                uint64_t w = r->jmr_js_core__DOT__u_vm__DOT__dbg_rect[i];
                unsigned c  = (unsigned)((w >> 40) & 0xFF);
                unsigned rx = (unsigned)((w >> 30) & 0x3FF);
                unsigned ry = (unsigned)((w >> 20) & 0x3FF);
                unsigned rw = (unsigned)((w >> 10) & 0x3FF);
                unsigned rh = (unsigned)(w & 0x3FF);
                oss << " [c" << c << ":" << rx << "," << ry << " " << rw << "x" << rh << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: FBBANK? <0|1> — dump one FB bank directly (bring-up: see what the
        // BACK buffer holds when the front never swaps in)
        if (line.rfind("FBBANK? ", 0) == 0) {
            unsigned b = 0;
            std::sscanf(line.c_str() + 8, "%u", &b);
            std::vector<uint8_t> full(307200u, 0);
            for (unsigned i = 0; i < 307200u; i++)
                full[i] = b ? (uint8_t)top->rootp->jmr_js_core__DOT__u_fb__DOT__mem1[i]
                            : (uint8_t)top->rootp->jmr_js_core__DOT__u_fb__DOT__mem0[i];
            std::cout << "FB 640 480 " << b64_encode(full.data(), full.size()) << std::endl;
            continue;
        }
        // NEW: SRAMPEEK <word_addr> <n> — dump asset-SRAM words (bring-up only)
        if (line.rfind("SRAMPEEK ", 0) == 0) {
            unsigned a = 0, n = 8;
            std::sscanf(line.c_str() + 9, "%u %u", &a, &n);
            std::ostringstream oss;
            oss << "SRAM";
            for (unsigned i = 0; i < n && (a + i) < 2097152u; i++)
                oss << " " << std::hex
                    << unsigned(top->rootp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[a + i]);
            std::cout << oss.str() << std::endl;
            continue;
        }
        // NEW: title palette dump (ASET 256×RGB888 loaded by the console on RUN)
        // — GUI mirror colors FB indices exactly like the HDMI field would.
        if (line == "PAL?") {
            uint8_t pal[768];
            for (int i = 0; i < 256; i++) {
                top->pal_raddr = (uint8_t)i;
                tick(); // registered BRAM read — settle
                tick();
                uint32_t v = top->pal_rdata;
                pal[i * 3 + 0] = (uint8_t)(v >> 16);
                pal[i * 3 + 1] = (uint8_t)(v >> 8);
                pal[i * 3 + 2] = (uint8_t)(v);
            }
            std::cout << "PAL " << b64_encode(pal, sizeof(pal)) << std::endl;
            continue;
        }
        if (line == "FB?") {
            // NEW: real mini-FB pixels when game_mode (RECTDEMO / VM)
            if (top->game_mode) {
                std::cout << "FB 640 480 " << fb_export_b64() << std::endl;
            } else {
                std::cout << "FB SAME" << std::endl;
            }
            continue;
        }
        // NEW: one VM frame — tick until fb swap (dbg_swap_n) or cap.
        // GUI TICK=1000 was << frame_div 65536, so PACMAN ghosts never left.
        // 2M was too small once string-row sprites actually painted: INVADERS
        // drawBitmap is per-pixel str[i]+fillRect, so FRAME capped mid-rAF
        // (~1 swap per 5 GUI frames) and the wave crawled. Cap is not SPI.
        if (line == "FRAME") {
            const int CAP = 64000000; // sequential GET_PROP is real silicon at ~30 MHz
            int used = 0;
            int got = 0;
            int pulsed = 0;
            int left_wait = 0;
            int idle_run = 0;   // NEW: clocks parked in S_WAIT_FRAME after the pulse
            int dead = 0;       // NEW: VM already halted — do not burn the cap
            auto* rframe = top->rootp;
            for (; used < CAP; used++) {
                // FPGA-SIM: one frame_tick when already in S_WAIT_FRAME, then
                // drop it so `else if (frame_fire)` can dispatch rAF. Do not
                // treat the same-cycle present_pend swap as a finished frame
                // (that starved the callback — KEEP.JS needed a second rAF).
                unsigned st0 = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__state);
                // ARRAY_GET fault=255 (and any machine_fault) used to leave
                // game_mode up while FRAME spun 64M clocks — GUI stuck on
                // COMPILE, queued LIST keys landed as garbage after ESC.
                if (rframe->jmr_js_core__DOT__u_vm__DOT__machine_fault
                    || st0 == 17u /* S_DONE */
                    || (st0 == 0u /* S_IDLE */ && used > 64 && !pulsed)) {
                    dead = 1;
                    break;
                }
                if (st0 == 16u && !pulsed) {
                    top->sim_frame_pulse = 1;
                    pulsed = 1;
                }
                tick();
                top->sim_frame_pulse = 0;
                unsigned cbip = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__dbg_cb_ip);
                unsigned st = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__state);
                if (rframe->jmr_js_core__DOT__u_vm__DOT__machine_fault
                    || st == 17u || st == 0u) {
                    if (st != 16u) {
                        dead = 1;
                        used++;
                        break;
                    }
                }
                // GC temporarily leaves S_WAIT_FRAME before the callback.
                // Do not mistake collector completion for callback completion.
                if (pulsed && st != 16u && !(st >= 54u && st <= 58u))
                    left_wait = 1;
                // Present after the rAF has run (back in S_WAIT_FRAME), not on
                // the present_pend swap that shares the pulse cycle.
                bool due_timer =
                    unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__to_n) != 0
                    && unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__to_delay[0]) == 0;
                bool frame_continue =
                    unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__frame_fire) != 0;
                if (left_wait && st == 16u && cbip != 0 &&
                    !due_timer && !frame_continue) {
                    got = 1; used++; break;
                }
                // NEW: one-shot screen (title with no rAF re-arm, or a frame
                // whose only work was the present) never leaves S_WAIT_FRAME.
                // Burning the 16M cap there froze the GUI for seconds per
                // frame and delayed the next KEYEVT dispatch (DONKEY Enter).
                idle_run = (pulsed && st == 16u) ? (idle_run + 1) : 0;
                if (idle_run > 2000) { got = 1; used++; break; }
            }
            last_fclk = (unsigned)used;
            last_fcap = (got || dead) ? 0u : 1u;
            if (!got && !dead) fcap_n++;
            if (top->game_mode) {
                // Capped FRAME has not presented — skip the 640×480 dump
                // (was ~5 wasted FB encodes per visual frame).
                if (got)
                    std::cout << "FB 640 480 " << fb_export_b64() << std::endl;
                else
                    std::cout << "FB SAME" << std::endl;
            } else {
                std::cout << "FB SAME" << std::endl;
            }
            continue;
        }
        std::cout << "ERR" << std::endl;
    }
    delete top;
    return 0;
}
