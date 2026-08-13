// Testbench: jmr_uart_link — RX bytes reach kbd_push; TX streams "S<row>:" rows.
// Built with -GCLK_HZ=1000000 -GBAUD=100000 → DIV=10 clks/bit (fast sim).
#include "Vjmr_uart_link.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

static Vjmr_uart_link* top = nullptr;
static std::vector<uint8_t> kbd_seen;
static std::string tx_seen;

// Soft UART RX decoder for the DUT's TX pin (DIV must match -GBAUD)
static const int DIV = 10;
static int tx_state = 0, tx_cnt = 0, tx_bit = 0;
static uint8_t tx_byte = 0;

static void tick() {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
    // VRAM stub: row r is 64× ('A'+r); dump_data must track dump_addr
    top->dump_data = uint8_t('A' + ((top->dump_addr >> 6) & 0xF));
    if (top->kbd_push) kbd_seen.push_back(top->kbd_data);
    // decode TX
    int rx = top->uart_tx & 1;
    switch (tx_state) {
        case 0: // idle, wait for start bit
            if (rx == 0) { tx_state = 1; tx_cnt = DIV + DIV / 2; tx_bit = 0; tx_byte = 0; }
            break;
        case 1: // sampling data bits
            if (--tx_cnt == 0) {
                tx_byte |= (rx & 1) << tx_bit;
                tx_cnt = DIV;
                if (++tx_bit == 8) tx_state = 2;
            }
            break;
        case 2: // stop bit
            if (--tx_cnt == 0) {
                tx_seen.push_back(char(tx_byte));
                tx_state = 0;
            }
            break;
    }
}

static void send_byte(uint8_t b) {
    // 8N1 LSB-first on uart_rx
    top->uart_rx = 0;                       // start
    for (int i = 0; i < DIV; i++) tick();
    for (int bit = 0; bit < 8; bit++) {
        top->uart_rx = (b >> bit) & 1;
        for (int i = 0; i < DIV; i++) tick();
    }
    top->uart_rx = 1;                       // stop
    for (int i = 0; i < DIV * 2; i++) tick();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vjmr_uart_link;
    top->rst_n = 0;
    top->uart_rx = 1;
    top->dump_data = ' ';
    for (int i = 0; i < 8; i++) tick();
    top->rst_n = 1;

    // 1) RX path: "DIR\n" → kbd D, I, R, 0x0D
    for (char c : std::string("DIR\n")) send_byte(uint8_t(c));
    if (kbd_seen.size() != 4 || kbd_seen[0] != 'D' || kbd_seen[1] != 'I' ||
        kbd_seen[2] != 'R' || kbd_seen[3] != 0x0D) {
        printf("FAIL kbd: got %zu bytes\n", kbd_seen.size());
        for (uint8_t b : kbd_seen) printf("  0x%02x\n", b);
        return 1;
    }
    printf("OK RX->kbd DIR + CR\n");

    // 2) Esc passthrough
    kbd_seen.clear();
    send_byte(0x1B);
    if (kbd_seen.size() != 1 || kbd_seen[0] != 0x1B) {
        printf("FAIL esc\n");
        return 1;
    }
    printf("OK RX->kbd ESC\n");

    // 3) TX dump: run until at least 2 full frames' worth of bytes decoded
    // Frame = 16 rows x 67 bytes = 1072. At DIV=10, each byte ~100 clks.
    for (long i = 0; i < 6'000'000 && tx_seen.size() < 2200; i++) tick();
    // Find "S0:AAAA" and "SF:PPPP" style rows
    bool row0 = tx_seen.find("S0:AAAA") != std::string::npos;
    bool rowF = tx_seen.find("SF:PPPP") != std::string::npos;
    size_t nl = tx_seen.find('\n');
    bool rowlen_ok = false;
    if (nl != std::string::npos && nl >= 66) rowlen_ok = true; // "S0:" + 64
    if (!row0 || !rowF || !rowlen_ok) {
        printf("FAIL dump: row0=%d rowF=%d len_ok=%d bytes=%zu\n",
               row0, rowF, rowlen_ok, tx_seen.size());
        printf("head: %.80s\n", tx_seen.c_str());
        return 1;
    }
    printf("OK TX dump rows 0..F, 64 chars each (%zu bytes captured)\n", tx_seen.size());
    printf("PASS jmr_uart_link\n");
    delete top;
    return 0;
}
