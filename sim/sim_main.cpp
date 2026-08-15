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
#include <vector>

static Vjmr_js_core* top = nullptr;

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
static std::vector<uint16_t> ip_trace;
static size_t ip_trace_cap = 0;
static uint16_t ip_trace_prev = 0xffff;
// NEW: last FRAME clocks / cap — play log showed swaps<<fb_frames with no
// clk, so a 2M-clock cap abort was invisible.
static unsigned last_fclk = 0;
static unsigned last_fcap = 0;
static unsigned fcap_n = 0;

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
    if (ip_trace.size() < ip_trace_cap) {
        uint16_t cur = uint16_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip);
        if (cur != ip_trace_prev) {
            ip_trace.push_back(cur);
            ip_trace_prev = cur;
        }
    }
}

static void ticks(int n) {
    for (int i = 0; i < n; i++) tick();
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
    ticks(8);
    top->rst_n = 1;
    ticks(200000);
    std::cout << "READY" << std::endl;

    std::string line;
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
                      << " sp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__sp)
                      << " raf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__raf_n)
                      << " obj=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj)
                      << " arr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_arr)
                      << " spr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_spr)
                      << " kd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kd_fn)
                      << " spr0=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__spr_nid[0])
                      << " dihit=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_hit)
                      << " dimiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_miss)
                      // NEW: join/path bring-up counters (PACMAN maze debug)
                      << " joinmiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_join_miss)
                      << " pathovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_path_ovf)
                      << " heapovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_heap_ovf)
                      << " toovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_to_ovf)
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
                      << std::endl;
            continue;
        }
        // NEW: OBJPEEK <oid> — dump one heap object (cls, n, key/val/tag slots)
        if (line.rfind("OBJPEEK ", 0) == 0) {
            auto* r = top->rootp;
            unsigned oid = std::stoul(line.substr(8)) & 8191;
            std::cout << "OBJ " << oid
                      << " cls=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_cls[oid])
                      << " n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_n[oid]);
            for (unsigned s = 0; s < 6; s++) {
                std::cout << " [" << s << "]k="
                          << unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_key[oid][s])
                          << " v=" << int(r->jmr_js_core__DOT__u_vm__DOT__obj_val[oid][s])
                          << " t=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__obj_tag[oid][s]);
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
            for (int i = 0; i < 16; i++) {
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
                    << unsigned(top->rootp->jmr_js_core__DOT__u_sram__DOT__mem[a + i]);
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
            unsigned before = 0;
            if (top->rootp)
                before = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n);
            const int CAP = 16000000; // one full HTML frame of pixel work
            int used = 0;
            int got = 0;
            for (; used < CAP; used++) {
                tick();
                unsigned now = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n);
                unsigned raf = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__raf_n);
                unsigned cbip = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_cb_ip);
                // Boot S_CLEAR and the first WAIT_FRAME (top-level script end)
                // pulse fb_swap with raf already queued but before tick()
                // paints. dbg_cb_ip is set when a rAF/timer callback returns.
                if (now != before && raf != 0 && cbip != 0) {
                    got = 1; used++; break;
                }
            }
            last_fclk = (unsigned)used;
            last_fcap = got ? 0u : 1u;
            if (!got) fcap_n++;
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
