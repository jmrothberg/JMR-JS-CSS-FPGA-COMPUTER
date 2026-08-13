// PS/2 decode table + end-to-end HELP typing via real waveforms.
#include "Vtb_ps2_typing_top.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <string>

static Vtb_ps2_typing_top* top = nullptr;

static void tick() {
    top->clk = 0; top->eval();
    top->clk = 1; top->eval();
}

static void send_byte_watch(uint8_t b, int* saw, uint8_t* ascii) {
    int parity = 1;
    auto cell = [&](int d) {
        top->ps2_data = d;
        for (int i = 0; i < 80; i++) {
            tick();
            if (top->ascii_strobe_mon) { (*saw)++; *ascii = top->ascii_mon; }
        }
        top->ps2_clk = 0;
        for (int i = 0; i < 80; i++) {
            tick();
            if (top->ascii_strobe_mon) { (*saw)++; *ascii = top->ascii_mon; }
        }
        top->ps2_clk = 1;
        for (int i = 0; i < 80; i++) {
            tick();
            if (top->ascii_strobe_mon) { (*saw)++; *ascii = top->ascii_mon; }
        }
    };
    cell(0);
    for (int i = 0; i < 8; i++) {
        int d = (b >> i) & 1;
        parity ^= d;
        cell(d);
    }
    cell(parity);
    cell(1);
    top->ps2_data = 1;
    for (int i = 0; i < 200; i++) {
        tick();
        if (top->ascii_strobe_mon) { (*saw)++; *ascii = top->ascii_mon; }
    }
}

static void type_key(uint8_t code) {
    int saw = 0; uint8_t ascii = 0;
    send_byte_watch(code, &saw, &ascii);
    send_byte_watch(0xF0, &saw, &ascii);
    send_byte_watch(code, &saw, &ascii);
}

static std::string screen_text() {
    std::string out;
    for (int row = 0; row < 16; row++) {
        std::string line;
        for (int col = 0; col < 64; col++) {
            top->dump_addr = (row << 6) | col;
            tick();
            char ch = char(top->dump_data & 0xff);
            if (ch < 32 || ch > 126) ch = ' ';
            line.push_back(ch);
        }
        while (!line.empty() && line.back() == ' ') line.pop_back();
        if (!out.empty()) out.push_back('\n');
        out += line;
    }
    return out;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vtb_ps2_typing_top;
    top->rst_n = 0;
    top->ps2_clk = 1;
    top->ps2_data = 1;
    top->dump_addr = 0;
    for (int i = 0; i < 20; i++) tick();
    top->rst_n = 1;
    for (int i = 0; i < 200000; i++) tick();

    int fails = 0;
    struct { uint8_t code; uint8_t expect; } table[] = {
        {0x1C, 'a'}, {0x32, 'b'}, {0x21, 'c'}, {0x24, 'e'},
        {0x16, '1'}, {0x5A, 0x0D}, {0x66, 0x08}, {0x76, 0x1B},
        {0x29, ' '}, {0x54, '['}, {0x5B, ']'}, {0x4C, ';'},
        {0x49, '.'}, {0x4A, '/'}, {0x4E, '-'}, {0x55, '='},
    };
    for (auto& e : table) {
        int saw = 0; uint8_t ascii = 0;
        send_byte_watch(e.code, &saw, &ascii);
        if (saw < 1 || ascii != e.expect) {
            printf("FAIL code=0x%02x expect=0x%02x got=0x%02x saw=%d\n",
                   e.code, e.expect, ascii, saw);
            fails++;
        }
        send_byte_watch(0xF0, &saw, &ascii);
        send_byte_watch(e.code, &saw, &ascii);
    }
    // Shift + [ → {
    {
        int saw = 0; uint8_t ascii = 0;
        send_byte_watch(0x12, &saw, &ascii); // shift
        saw = 0; ascii = 0;
        send_byte_watch(0x54, &saw, &ascii);
        if (saw < 1 || ascii != '{') {
            printf("FAIL shift-{ got=0x%02x saw=%d\n", ascii, saw);
            fails++;
        }
        send_byte_watch(0xF0, &saw, &ascii);
        send_byte_watch(0x54, &saw, &ascii);
        send_byte_watch(0xF0, &saw, &ascii);
        send_byte_watch(0x12, &saw, &ascii);
    }
    if (!fails) printf("PASS ps2 decode table\n");

    // NEW: reset console so table-test keystrokes do not pollute the line
    top->rst_n = 0;
    for (int i = 0; i < 20; i++) tick();
    top->rst_n = 1;
    for (int i = 0; i < 200000; i++) tick();

    // Type help + Enter (case-insensitive verb)
    type_key(0x33); // h
    type_key(0x24); // e
    type_key(0x4B); // l
    type_key(0x4D); // p
    type_key(0x5A); // Enter
    for (int i = 0; i < 300000; i++) tick();

    std::string scr = screen_text();
    if (scr.find("DIR") == std::string::npos && scr.find("LOAD") == std::string::npos) {
        printf("FAIL HELP reply missing:\n%s\n", scr.c_str());
        fails++;
    } else {
        printf("PASS ps2 typing help → HELP reply\n");
    }

    if (fails) {
        printf("FAIL tb_ps2_typing (%d)\n", fails);
        delete top;
        return 1;
    }
    printf("PASS tb_ps2_typing\n");
    delete top;
    return 0;
}
