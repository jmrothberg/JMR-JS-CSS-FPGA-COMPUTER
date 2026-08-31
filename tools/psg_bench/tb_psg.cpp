// PSG gate: a poke with mute LOW must produce I2S transitions; with mute
// HIGH (or enable LOW) the line must be dead. Run-63 shipped mute wired to
// the wrong signal and was silent in every game — a green battery cannot
// see an inverted top-level pin, so this bench exists to pin the contract.
#include "Vjmr_psg.h"
#include "verilated.h"
#include <cstdio>
static long run(Vjmr_psg* d, int enable, int mute, int poke, long n) {
    long edges = 0; int prev = 0;
    d->enable = enable; d->mute = mute;
    if (poke) { d->snd_tgl = !d->snd_tgl; d->snd_ch = 0; d->snd_freq = 440;
                d->snd_vol = 12; d->snd_frames = 200; d->snd_slide = 0; }
    for (long i = 0; i < n; i++) {
        d->mclk = 0; d->eval(); d->mclk = 1; d->eval();
        if (d->dac_sdata != prev) { edges++; prev = d->dac_sdata; }
    }
    return edges;
}
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vjmr_psg* d = new Vjmr_psg;
    d->rst_n = 0; d->mclk = 0; d->eval();
    for (int i = 0; i < 8; i++) { d->mclk = 0; d->eval(); d->mclk = 1; d->eval(); }
    d->rst_n = 1;
    long playing = run(d, 1, 0, 1, 400000);
    run(d, 1, 1, 1, 2000);              // flush the word already in flight
    long muted   = run(d, 1, 1, 0, 400000); // steady-state muted
    run(d, 0, 0, 1, 2000);
    long nocodec = run(d, 0, 0, 0, 400000);
    printf("playing=%ld muted=%ld nocodec=%ld\n", playing, muted, nocodec);
    int ok = (playing > 1000) && (muted == 0) && (nocodec == 0);
    printf("%s\n", ok ? "PSG-GATE PASS" : "PSG-GATE FAIL");
    return ok ? 0 : 1;
}
