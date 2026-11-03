#include "Vtb_present_stream.h"
#include "verilated.h"
#include <vector>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

static Vtb_present_stream top;
static std::vector<uint8_t> canvas(307200), front(307200, 0xa7);
static void tick() { top.clk=0; top.eval(); top.clk=1; top.eval(); }
static void fail(const char* s) { std::fprintf(stderr,"FAIL %s\n",s); std::exit(1); }
static void write(unsigned a, uint8_t d) {
    top.we=1; top.waddr=a; top.wdata=d; tick(); top.we=0;
    canvas[a]=d;
}
static unsigned present(bool clear=false, bool queued=false) {
    top.swap=!clear; top.clear_go=clear; tick();
    top.swap=0; top.clear_go=0;
    bool prior_ack=false; uint32_t rng=0x42abcd; unsigned words=0, cycles=0;
    do {
        rng^=rng<<13; rng^=rng>>17; rng^=rng<<5;
        top.clk=0; top.eval();
        top.ack=top.req && !prior_ack && ((rng&3)!=0);
        prior_ack=top.ack;
        if(top.req && top.ack) {
            if(top.addr<3577856 || top.addr>=3577856+153600) fail("address bounds");
            unsigned a=2*(top.addr-3577856);
            front[a]=top.data&255; front[a+1]=top.data>>8; ++words;
        }
        top.swap=queued && cycles==10;
        top.clk=1; top.eval();
        if(++cycles>2000000) fail("completion");
        // A queued swap starts on the idle clock after the first copy.
        if(!top.busy && queued && cycles>11) { tick(); queued=false; }
    } while(top.busy);
    top.swap=0; top.ack=0; tick();
    auto expected=clear ? std::vector<uint8_t>(307200,0) : canvas;
    if(front!=expected) fail("persistent front image differs from canvas");
    std::printf("dirty present: %u words, %u clocks\n",words,cycles);
    return words;
}
int main(int argc,char**argv) {
    Verilated::commandArgs(argc,argv);
    top.rst_n=0; top.we=0; top.swap=0; top.clear_go=0; top.ack=0;
    tick(); tick(); top.rst_n=1;
    for(unsigned i=0;i<307200;++i) write(i,uint8_t(i*17+(i>>8)));
    if(present()!=153600) fail("first full copy");
    if(present()!=0) fail("unchanged canvas copied");
    for(unsigned i=0;i<307200;++i) write(i,canvas[i]);
    if(present()!=0) fail("identical redraw copied");
    write(0,canvas[0]^1); write(256+9,canvas[265]^2);
    write(307199,canvas[307199]^4);
    if(present(false,true)!=3*128) fail("sparse/queued copy word count");
    write(513,canvas[513]^16);
    if(present()!=128) fail("odd-byte update lost");
    if(present(true)!=153600) fail("clear must cover front");
    if(present()!=153600) fail("restore after clear must cover front");
    if(present()!=0) fail("restored image copied again");
    std::puts("PASS dirty present: exact persistent pixels, identical redraws, sparse blocks, queued swap, odd byte, clear");
}
