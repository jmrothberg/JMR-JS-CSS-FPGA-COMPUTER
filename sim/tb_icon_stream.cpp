#include "Vjmr_icon_stream.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <vector>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    if (argc != 6) return 2;
    std::ifstream in(argv[1], std::ios::binary);
    std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(in)), {});
    const unsigned declared_size = std::strtoul(argv[2], nullptr, 10);
    const long abort_after = std::strtol(argv[3], nullptr, 10);
    Vjmr_icon_stream top;
    top.clk = 0; top.rst = 1; top.start = 0;
    top.src_error = 0; top.src_valid = 0; top.pixel_ready = 0;
    top.eval(); top.clk = 1; top.eval();
    top.rst = 0; top.start = 1; top.file_size = declared_size;
    top.clk = 0; top.eval(); top.clk = 1; top.eval();
    top.start = 0;
    size_t pos = 0;
    bool aborted = false, held = false;
    unsigned held_value = 0, count = 0;
    std::array<uint8_t, 2048> pixels{};
    for (unsigned cycle = 0; cycle < 50000; ++cycle) {
        top.clk = 0;
        top.src_valid = pos < bytes.size() && cycle % 7 != 0;
        top.src_data = pos < bytes.size() ? bytes[pos] : 0;
        top.pixel_ready = cycle % 5 != 0 && cycle % 5 != 1;
        top.src_error = !aborted && abort_after >= 0 && pos >= size_t(abort_after);
        if (top.src_error) { aborted = true; held = false; }
        top.eval();
        const unsigned value = (unsigned(top.pixel_y) << 14) |
            (unsigned(top.pixel_x) << 9) | (unsigned(top.pixel_opaque) << 8) |
            top.pixel_rgb332;
        if (held && (!top.pixel_valid || value != held_value)) {
            std::fprintf(stderr, "pixel changed under backpressure\n"); return 3;
        }
        held = top.pixel_valid && !top.pixel_ready;
        held_value = value;
        if (top.src_valid && top.src_ready) ++pos;
        if (top.pixel_valid && top.pixel_ready) {
            const unsigned i = top.pixel_y * 32 + top.pixel_x;
            pixels[i * 2] = top.pixel_rgb332;
            pixels[i * 2 + 1] = top.pixel_opaque;
            ++count;
        }
        top.clk = 1; top.eval();
        if (top.done) {
            std::ofstream out(argv[4], std::ios::binary);
            out.write(reinterpret_cast<char*>(pixels.data()), pixels.size());
            const bool expected_fallback = std::atoi(argv[5]) != 0;
            if (bool(top.fallback) != expected_fallback || count < 1024) return 4;
            std::printf("PASS icon stream: %u pixels, %zu bytes, fallback=%u\n",
                        count, pos, unsigned(top.fallback));
            return 0;
        }
    }
    std::fprintf(stderr, "icon stream timed out at byte %zu\n", pos);
    return 5;
}
