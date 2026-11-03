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
        assert(top.rootp->jmr_js_core__DOT__vm_clk == 0);
        top.clk = 1; top.eval();
    };
    top.rst_n = 0;
    tick(); tick();
    top.rst_n = 1;
    constexpr unsigned period = 1666666;
    unsigned previous_vm_edge = 0, vm_edges = 0;
    for (unsigned cycle = 1; cycle <= 2 * period; ++cycle) {
        tick();
        assert(top.rootp->jmr_js_core__DOT__frame_div == cycle % period);
        if (top.rootp->jmr_js_core__DOT__vm_clk) {
            if (previous_vm_edge) assert(cycle - previous_vm_edge == 3);
            previous_vm_edge = cycle;
            ++vm_edges;
        }
    }
    assert(vm_edges >= 2 * period / 3 - 1);
    top.final();
    std::puts("PASS board cadence: two 1666666-cycle periods without early wrap");
}
