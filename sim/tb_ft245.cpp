// Testbench: jmr_ft245_async — host bytes in, FPGA bytes out (PROG-cable FIFO).
#include "Vjmr_ft245_async.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <vector>

static Vjmr_ft245_async* top = nullptr;
static std::vector<uint8_t> host_rx;   // bytes FPGA wrote to "PC"
static uint8_t host_tx_byte = 0;
static bool host_tx_pending = false;

static void tick() {
    // Host (FTDI) model: drive the bus only while FPGA has OE# low (read)
    if (!top->oe_n)
        top->d = host_tx_byte;
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
    // Capture FPGA writes on WR# falling (held low this cycle, was high)
    static int wr_n_q = 1;
    if (wr_n_q && !top->wr_n)
        host_rx.push_back(uint8_t(top->d));
    wr_n_q = top->wr_n;
    // RXF# stays low while a host byte is waiting
    top->rxf_n = host_tx_pending ? 0 : 1;
    top->txe_n = 0;   // always room
}

static void send_from_host(uint8_t b) {
    host_tx_byte = b;
    host_tx_pending = true;
    for (int i = 0; i < 400 && !top->rx_ready; i++) tick();
    if (!top->rx_ready) {
        printf("FAIL host TX never became rx_ready\n");
        exit(1);
    }
    uint8_t got = top->rx_data;
    top->rx_pop = 1; tick(); top->rx_pop = 0;
    host_tx_pending = false;
    for (int i = 0; i < 40; i++) tick();
    if (got != b) {
        printf("FAIL host TX 0x%02x got 0x%02x\n", b, got);
        exit(1);
    }
}

static void send_from_fpga(uint8_t b) {
    size_t n = host_rx.size();
    for (int i = 0; i < 400 && top->tx_busy; i++) tick();
    top->wr_data = b;
    top->wr_en = 1; tick(); top->wr_en = 0;
    for (int i = 0; i < 400 && host_rx.size() == n; i++) tick();
    if (host_rx.size() != n + 1 || host_rx.back() != b) {
        printf("FAIL FPGA TX 0x%02x (got %zu bytes)\n", b, host_rx.size());
        exit(1);
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vjmr_ft245_async;
    top->rst_n = 0;
    top->rxf_n = 1;
    top->txe_n = 0;
    top->wr_en = 0;
    top->rx_pop = 0;
    top->d = 0;
    for (int i = 0; i < 8; i++) tick();
    top->rst_n = 1;
    for (int i = 0; i < 8; i++) tick();

    send_from_host('D');
    send_from_host('I');
    send_from_host('R');
    send_from_host('\n');
    printf("OK host->FPGA DIR\\n\n");

    send_from_fpga('S');
    send_from_fpga('0');
    send_from_fpga(':');
    send_from_fpga('\n');
    printf("OK FPGA->host S0:\\n\n");

    printf("PASS jmr_ft245_async\n");
    delete top;
    return 0;
}
