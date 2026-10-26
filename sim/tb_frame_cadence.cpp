#include "Vjmr_js_core.h"
#include "Vjmr_js_core___024root.h"
#include "verilated.h"
#include <cassert>
#include <cstdio>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vjmr_js_core top;
    auto tick = [&]() {
        top.clk = 0; top.eval();
        top.clk = 1; top.eval();
    };
    top.rst_n = 0;
    tick(); tick();
    top.rst_n = 1;
    constexpr unsigned period = 1666666;
    for (unsigned cycle = 1; cycle <= 2 * period; ++cycle) {
        tick();
        assert(top.rootp->jmr_js_core__DOT__frame_div == cycle % period);
    }
    top.final();
    std::puts("PASS board cadence: two 1666666-cycle periods without early wrap");
}
