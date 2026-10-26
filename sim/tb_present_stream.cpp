#include "Vtb_present_stream.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static Vtb_present_stream top;
static uint8_t pixel(unsigned i) { return uint8_t(i*17+(i>>8)); }
static void tick() { top.clk=0; top.eval(); top.clk=1; top.eval(); }
static void fail(const char* what, unsigned i) {
    std::fprintf(stderr, "FAIL %s at word %u\n", what, i); std::exit(1);
}
static unsigned run(bool stalled, bool clear, unsigned copies) {
    constexpr unsigned words=153600, base=1480704;
    top.swap=!clear; top.clear_go=clear; tick();
    top.swap=0; top.clear_go=0;
    bool prior_ack=false;
    uint32_t rng=0x12345678;
    unsigned n=0, clocks=0;
    for (; clocks<8000000 && (n<copies*words || top.busy); ++clocks) {
        rng^=rng<<13; rng^=rng>>17; rng^=rng<<5;
        top.clk=0; top.eval();
        top.ack=top.req && !prior_ack && (!stalled || (rng&7)==0);
        prior_ack=top.ack;
        if (top.req && top.ack) {
            unsigned i=n%words;
            if (top.addr!=base+i) fail("address/duplicate/drop", n);
            unsigned expected=clear ? 0 : unsigned(pixel(2*i)) | (unsigned(pixel(2*i+1))<<8);
            if (top.data!=expected) fail("registered BRAM read / byte pairing", n);
            ++n;
        }
        top.swap=(copies==2 && clocks==100);
        top.clk=1; top.eval();
    }
    top.swap=0; top.ack=0; tick();
    if (n!=copies*words || top.busy) fail("completion/queued swap", n);
    return clocks;
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc,argv);
    top.rst_n=0; top.swap=0; top.clear_go=0; top.ack=0; top.we=0;
    tick(); tick(); top.rst_n=1;
    top.we=1;
    for (unsigned i=0;i<307200;++i) { top.waddr=i; top.wdata=pixel(i); tick(); }
    top.we=0;
    unsigned fast=run(false,false,1);
    if (fast>310000) fail("stream throughput regressed", fast);
    run(true,false,1);
    run(true,false,2);
    run(true,true,1);
    std::printf("PASS present: exact 768000 words, random backpressure, queued swap, clear; fast=%u clocks\n",fast);
}
