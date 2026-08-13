// Testbench: Digilent-style debounced ps2_rx — clean + glitchy 0x1C.
#include "Vps2_rx.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>

static Vps2_rx* top = nullptr;
static int got = 0;
static uint8_t last = 0;

static void tick() {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
    if (top->strobe) { got++; last = top->scancode; }
}

static void bit_cell(int data, int glitch) {
    top->ps2_data = data;
    for (int i = 0; i < 80; i++) tick();
    top->ps2_clk = 0;
    if (glitch) {
        for (int i = 0; i < 2; i++) tick();
        top->ps2_clk = 1;
        for (int i = 0; i < 2; i++) tick();
        top->ps2_clk = 0;
    }
    for (int i = 0; i < 80; i++) tick();
    top->ps2_clk = 1;
    for (int i = 0; i < 80; i++) tick();
}

static void send_byte(uint8_t b, int glitch) {
    int parity = 1;
    bit_cell(0, glitch);
    for (int i = 0; i < 8; i++) {
        int d = (b >> i) & 1;
        parity ^= d;
        bit_cell(d, 0);
    }
    bit_cell(parity, 0);
    bit_cell(1, 0);
    top->ps2_data = 1;
    for (int i = 0; i < 200; i++) tick();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vps2_rx;
    top->rst_n = 0;
    top->ps2_clk = 1;
    top->ps2_data = 1;
    for (int i = 0; i < 16; i++) tick();
    top->rst_n = 1;
    for (int i = 0; i < 80; i++) tick();

    got = 0; last = 0;
    send_byte(0x1C, 1);
    if (got != 1 || last != 0x1C) {
        printf("FAIL got=%d last=0x%02x\n", got, last);
        return 1;
    }
    printf("PASS ps2_rx (debounced)\n");
    delete top;
    return 0;
}
