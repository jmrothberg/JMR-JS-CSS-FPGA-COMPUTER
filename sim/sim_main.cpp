// Verilator harness — tops jmr_js_core (same DUT as board PHY shell).
// Protocol: KEY / LINE / SCREEN? / STATUS? / RUNCLK / TICK / QUIT
// NEW: card.img SPI model (BASIC sim_main SdCard) for DIR/LOAD/SAVE.
#include "Vjmr_js_core.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
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
            std::cerr << "SD image " << p << " (" << sd.image.size() << " bytes)\n";
            return;
        }
    }
    std::cerr << "WARN: no card.img — DIR will ?IO\n";
}

static void tick() {
    top->clk = 0; top->pixel_clk = 0; top->eval();
    uint8_t miso = 1;
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
    top->clk = 1; top->pixel_clk = 1; top->eval();
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
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
    for (int i = 0; i < W * H; i++) {
        top->dump_fb_raddr = (uint32_t)i;
        tick(); // BRAM dump port is registered — settle
        tick();
        full[(size_t)i] = (uint8_t)(top->dump_fb_rdata & 0xff);
    }
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
        if (line == "SDRELOAD") {
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
            // FAT mount + DIR walk needs many SPI bit times
            ticks(5'000'000);
            std::cout << "OK" << std::endl;
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
        if (line.rfind("PROMPT ", 0) == 0) {
            std::cout << "OK" << std::endl;
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
        std::cout << "ERR" << std::endl;
    }
    delete top;
    return 0;
}
