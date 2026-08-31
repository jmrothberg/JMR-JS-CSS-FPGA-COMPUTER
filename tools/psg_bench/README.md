# PSG gate bench

Pins the PSG's audibility contract, because a green pytest battery cannot
see a top-level pin wired to the wrong signal — run 63 shipped `mute`
driven by `ready_lit` (TRUE during gameplay, since the console engine is
disabled then and parks in C_IDLE) and was silent in every game.

    verilator --cc --exe --build -Wno-fatal --timescale 1ns/1ps \
      -I../../rtl/phys ../../rtl/phys/jmr_psg.sv tb_psg.cpp \
      -o tb_psg --top-module jmr_psg && ./obj_dir/tb_psg

Asserts: a sound() poke with enable=1/mute=0 produces I2S transitions;
steady-state muted and codec-not-ready are both silent. (A couple of
transitions right after mute asserts are the word already in the
shifter — the bench flushes before measuring.)
