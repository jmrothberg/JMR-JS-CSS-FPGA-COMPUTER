// Verilator harness — tops jmr_js_core (same DUT as board PHY shell).
// Protocol: SERVICE / SERVICEPOLL / SERVICEBULK / KEY / SCREEN? / STATUS? / RUNCLK / TICK / QUIT
// Card.img SPI model (BASIC sim_main SdCard) for DIR/LOAD/SAVE.
#include "Vjmr_js_core.h"
#include "Vjmr_js_core___024root.h" // VMSTAT? probe reads public VM regs
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sstream>
#include <string>
#include <fstream>
#include <algorithm>
#include <map>
#include <utility>
#include <vector>

static Vjmr_js_core* top = nullptr;

// Typed Finder service observer. Responses are collected only on the actual
// core valid/ready handshake; no console strings stand in for completion.
static std::vector<std::string> finder_responses;
static uint32_t finder_crc(const uint8_t* p, size_t n) {
    uint32_t c = 0xffffffffu;
    for (size_t j=0; j<n; ++j) {
        c ^= p[j];
        for (unsigned i=0; i<8; ++i)
            c = (c >> 1) ^ ((c & 1u) ? 0xedb88320u : 0u);
    }
    return ~c;
}
static void finder_capture_response() {
    if (!top->rst_n || !top->host_q_valid || !top->host_q_ready) return;
    char payload[25], record[34];
    std::snprintf(payload,sizeof(payload),"%08X%08X%08X",
                  unsigned(top->host_q_payload[2]), unsigned(top->host_q_payload[1]),
                  unsigned(top->host_q_payload[0]));
    uint32_t crc = finder_crc(reinterpret_cast<const uint8_t*>(payload),24);
    std::snprintf(record,sizeof(record),"Q%s%08X",payload,unsigned(crc));
    finder_responses.emplace_back(record);
}
static void finder_print_responses() {
    std::cout << "SERVICE";
    for (const auto& r : finder_responses) std::cout << " " << r;
    finder_responses.clear();
    std::cout << std::endl;
}


// CHECKPOINT/OBJPEEK peek 1-D SRAM (not a third hardware port).
// Match rtl/engines/jmr_js_vm.sv two-tier arrays (1536×32 + 128×128).

// Persistent canvas: seventy-five separately inferred4-KiB banks.
// This observer maps linear pixels; it adds no simulated hardware activity.
// Session-1: single persistent draw bank — the canvas. FB?
// reads it directly (post-present it equals the DDR3 front image exactly).
static inline uint8_t fb_bank_pix(const Vjmr_js_core___024root* r, bool, unsigned i) {
    switch (i >> 12) {
    case 0u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__0__KET____DOT__mem[i & 4095u];
    case 1u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__1__KET____DOT__mem[i & 4095u];
    case 2u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__2__KET____DOT__mem[i & 4095u];
    case 3u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__3__KET____DOT__mem[i & 4095u];
    case 4u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__4__KET____DOT__mem[i & 4095u];
    case 5u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__5__KET____DOT__mem[i & 4095u];
    case 6u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__6__KET____DOT__mem[i & 4095u];
    case 7u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__7__KET____DOT__mem[i & 4095u];
    case 8u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__8__KET____DOT__mem[i & 4095u];
    case 9u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__9__KET____DOT__mem[i & 4095u];
    case 10u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__10__KET____DOT__mem[i & 4095u];
    case 11u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__11__KET____DOT__mem[i & 4095u];
    case 12u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__12__KET____DOT__mem[i & 4095u];
    case 13u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__13__KET____DOT__mem[i & 4095u];
    case 14u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__14__KET____DOT__mem[i & 4095u];
    case 15u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__15__KET____DOT__mem[i & 4095u];
    case 16u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__16__KET____DOT__mem[i & 4095u];
    case 17u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__17__KET____DOT__mem[i & 4095u];
    case 18u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__18__KET____DOT__mem[i & 4095u];
    case 19u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__19__KET____DOT__mem[i & 4095u];
    case 20u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__20__KET____DOT__mem[i & 4095u];
    case 21u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__21__KET____DOT__mem[i & 4095u];
    case 22u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__22__KET____DOT__mem[i & 4095u];
    case 23u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__23__KET____DOT__mem[i & 4095u];
    case 24u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__24__KET____DOT__mem[i & 4095u];
    case 25u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__25__KET____DOT__mem[i & 4095u];
    case 26u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__26__KET____DOT__mem[i & 4095u];
    case 27u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__27__KET____DOT__mem[i & 4095u];
    case 28u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__28__KET____DOT__mem[i & 4095u];
    case 29u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__29__KET____DOT__mem[i & 4095u];
    case 30u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__30__KET____DOT__mem[i & 4095u];
    case 31u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__31__KET____DOT__mem[i & 4095u];
    case 32u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__32__KET____DOT__mem[i & 4095u];
    case 33u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__33__KET____DOT__mem[i & 4095u];
    case 34u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__34__KET____DOT__mem[i & 4095u];
    case 35u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__35__KET____DOT__mem[i & 4095u];
    case 36u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__36__KET____DOT__mem[i & 4095u];
    case 37u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__37__KET____DOT__mem[i & 4095u];
    case 38u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__38__KET____DOT__mem[i & 4095u];
    case 39u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__39__KET____DOT__mem[i & 4095u];
    case 40u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__40__KET____DOT__mem[i & 4095u];
    case 41u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__41__KET____DOT__mem[i & 4095u];
    case 42u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__42__KET____DOT__mem[i & 4095u];
    case 43u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__43__KET____DOT__mem[i & 4095u];
    case 44u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__44__KET____DOT__mem[i & 4095u];
    case 45u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__45__KET____DOT__mem[i & 4095u];
    case 46u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__46__KET____DOT__mem[i & 4095u];
    case 47u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__47__KET____DOT__mem[i & 4095u];
    case 48u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__48__KET____DOT__mem[i & 4095u];
    case 49u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__49__KET____DOT__mem[i & 4095u];
    case 50u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__50__KET____DOT__mem[i & 4095u];
    case 51u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__51__KET____DOT__mem[i & 4095u];
    case 52u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__52__KET____DOT__mem[i & 4095u];
    case 53u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__53__KET____DOT__mem[i & 4095u];
    case 54u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__54__KET____DOT__mem[i & 4095u];
    case 55u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__55__KET____DOT__mem[i & 4095u];
    case 56u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__56__KET____DOT__mem[i & 4095u];
    case 57u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__57__KET____DOT__mem[i & 4095u];
    case 58u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__58__KET____DOT__mem[i & 4095u];
    case 59u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__59__KET____DOT__mem[i & 4095u];
    case 60u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__60__KET____DOT__mem[i & 4095u];
    case 61u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__61__KET____DOT__mem[i & 4095u];
    case 62u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__62__KET____DOT__mem[i & 4095u];
    case 63u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__63__KET____DOT__mem[i & 4095u];
    case 64u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__64__KET____DOT__mem[i & 4095u];
    case 65u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__65__KET____DOT__mem[i & 4095u];
    case 66u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__66__KET____DOT__mem[i & 4095u];
    case 67u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__67__KET____DOT__mem[i & 4095u];
    case 68u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__68__KET____DOT__mem[i & 4095u];
    case 69u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__69__KET____DOT__mem[i & 4095u];
    case 70u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__70__KET____DOT__mem[i & 4095u];
    case 71u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__71__KET____DOT__mem[i & 4095u];
    case 72u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__72__KET____DOT__mem[i & 4095u];
    case 73u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__73__KET____DOT__mem[i & 4095u];
    case 74u: return (uint8_t)r->jmr_js_core__DOT__u_fb__DOT__g_bank__BRA__74__KET____DOT__mem[i & 4095u];
    default: return 0;
    }
}

static const unsigned VM_MAX_OBJ = 960u;   // MUST track rtl MAX_OBJ (bug #75: stale caps here count OOB garbage)
static const unsigned VM_OBJ_SLOTS = 32u;
static const unsigned VM_MAX_ARR_SHORT = 1536u;
static const unsigned VM_ARR_SHORT_CAP = 32u;
static const unsigned VM_MAX_VARS = 1024u;   // track rtl MAX_VARS
static const unsigned VM_MAX_ARR_LONG = 16u; // track rtl
static const unsigned VM_MAX_ARR = 1552u;  // SHORT+LONG; track rtl
static const unsigned VM_ARR_CAP = 128u;
static const unsigned VM_VARR_SHORT_WORDS = VM_MAX_ARR_SHORT * VM_ARR_SHORT_CAP;
static const unsigned VM_ENV_DEPTH = 384u; // track rtl
static const unsigned VM_ENV_SLOTS = 16u;
static inline unsigned vobj_addr(unsigned h, unsigned s) {
    return (h * VM_OBJ_SLOTS) + s;
}
static inline unsigned varr_addr(Vjmr_js_core___024root* r, unsigned h, unsigned e) {
    if (h >= VM_MAX_ARR)
        h = 0;
    if (r->jmr_js_core__DOT__u_vm__DOT__varr_long[h]) {
        unsigned phys = unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_lidx[h]);
        if (phys >= VM_MAX_ARR_LONG) phys = 0;
        if (e >= VM_ARR_CAP) e = VM_ARR_CAP - 1u;
        return VM_VARR_SHORT_WORDS + (phys * VM_ARR_CAP) + e;
    }
    if (e >= VM_ARR_SHORT_CAP) e = VM_ARR_SHORT_CAP - 1u;
    return (h * VM_ARR_SHORT_CAP) + e;
}
static inline unsigned venv_addr(unsigned h, unsigned s) {
    return (h * VM_ENV_SLOTS) + s;
}

// Fit: heap slot arrays are pow2-chunked in the RTL
// (vobj 16K+8K+4K+2K, varr 32K+16K+2K, venv 4K+2K, code 16K+4K).
// These routers mirror the RTL boundaries exactly.
template <typename R>
static inline const auto& vobj_word(R* r, unsigned a) {
    if (a < 16384u) return r->jmr_js_core__DOT__u_vm__DOT__vobj_slot_c0[a];
    if (a < 24576u) return r->jmr_js_core__DOT__u_vm__DOT__vobj_slot_c1[a - 16384u];
    if (a < 28672u) return r->jmr_js_core__DOT__u_vm__DOT__vobj_slot_c2[a - 24576u];
    return r->jmr_js_core__DOT__u_vm__DOT__vobj_slot_c3[(a - 28672u) & 2047u];
}
template <typename R>
static inline uint64_t varr_word(R* r, unsigned a) {
    if (a < 32768u) return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__varr_slot_c0[a]);
    if (a < 49152u) return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__varr_slot_c1[a - 32768u]);
    return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__varr_slot_c2[(a - 49152u) & 2047u]);
}
template <typename R>
static inline const auto& venv_word(R* r, unsigned a) {
    if (a < 4096u) return r->jmr_js_core__DOT__u_vm__DOT__venv_slot_c0[a];
    return r->jmr_js_core__DOT__u_vm__DOT__venv_slot_c1[(a - 4096u) & 2047u];
}
template <typename R>
static inline uint32_t code_word(R* r, unsigned a) {
    if(r->jmr_js_core__DOT__u_vm__DOT__load_toolbox){
        unsigned base=r->jmr_js_core__DOT__u_vm__DOT__load_ops_base;
        if(a>=base && a<base+8192){ unsigned i=a-base;return i<4096?r->jmr_js_core__DOT__u_vm__DOT__toolbox_code0[i]:i<6144?r->jmr_js_core__DOT__u_vm__DOT__toolbox_code1[i-4096]:i<7168?r->jmr_js_core__DOT__u_vm__DOT__toolbox_code2[i-6144]:i<8191?r->jmr_js_core__DOT__u_vm__DOT__toolbox_code3[i-7168]:0x0020000bu; }
        if(a>=base+8192)a-=8192;
    }
    if (a < 16384u) return uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_mem_c0[a]);
    if (a < 24576u) return uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_mem_c1[a - 16384u]);
    if (a < 28672u) return uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_mem_c2[a - 24576u]);
    return uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_mem_c3[(a - 28672u) & 1023u]);
}
template <typename R>
static inline void code_poke(R* r, unsigned a, uint32_t w) {
    if(a==0){r->jmr_js_core__DOT__u_vm__DOT__load_toolbox=0;r->jmr_js_core__DOT__u_vm__DOT__load_toolbox_hash=0;}
    if(a==1)r->jmr_js_core__DOT__u_vm__DOT__load_ops_base=4+2*(w>>16);
    if(a==2){r->jmr_js_core__DOT__u_vm__DOT__load_toolbox=(w>>20)&1;if(!(w&(1u<<17)))r->jmr_js_core__DOT__u_vm__DOT__load_ops_base--;}
    if(r->jmr_js_core__DOT__u_vm__DOT__load_toolbox){
        unsigned base=r->jmr_js_core__DOT__u_vm__DOT__load_ops_base;
        if(a>=base && a<base+8192){
            uint32_t h=r->jmr_js_core__DOT__u_vm__DOT__load_toolbox_hash;
            r->jmr_js_core__DOT__u_vm__DOT__load_toolbox_hash=((h<<1)|(h>>31))^w;
            return;
        }
        if(a>=base+8192)a-=8192;
    }
    if (a < 16384u) r->jmr_js_core__DOT__u_vm__DOT__code_mem_c0[a] = w;
    else if (a < 24576u) r->jmr_js_core__DOT__u_vm__DOT__code_mem_c1[a - 16384u] = w;
    else if (a < 28672u) r->jmr_js_core__DOT__u_vm__DOT__code_mem_c2[a - 24576u] = w;
    else if (a < 29696u) r->jmr_js_core__DOT__u_vm__DOT__code_mem_c3[a - 28672u] = w;
}

// Latched jsb_flags describes the last accepted header. A refused new image
// can leave it unchanged, so inspectors also check the current physical header.
static bool inspector_value64_image(Vjmr_js_core___024root* r) {
    return (code_word(r, 0) == UINT32_C(0x3142534a) || code_word(r, 0) == UINT32_C(0x3242534a))
        && (code_word(r, 2) & (UINT32_C(8) << 16)) != 0
        && (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) != 0;
}

static uint16_t peek_vobj_key(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = vobj_word(r, vobj_addr(h, s));
    return uint16_t(w[2] & 0xFFFFu);
}
static uint64_t peek_vobj_val(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = vobj_word(r, vobj_addr(h, s));
    return uint64_t(w[0]) | (uint64_t(w[1]) << 32);
}
static uint64_t peek_varr_val(Vjmr_js_core___024root* r, unsigned h, unsigned e) {
    return varr_word(r, varr_addr(r, h, e));
}
// TOS window is CPU truth; BRAM vstack lags one write. CHECKPOINT overlays.
static uint64_t peek_vstack(Vjmr_js_core___024root* r, unsigned slot, unsigned vsp) {
    if (vsp > 0u && slot < vsp) {
        unsigned d = vsp - 1u - slot;
        if (d < 16u)
            return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[d]);
    }
    return uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vstack[slot]);
}
static uint16_t peek_venv_key(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = venv_word(r, venv_addr(h, s));
    return uint16_t(w[2] & 0x3FFu);
}
static uint64_t peek_venv_val(Vjmr_js_core___024root* r, unsigned h, unsigned s) {
    const auto& w = venv_word(r, venv_addr(h, s));
    return uint64_t(w[0]) | (uint64_t(w[1]) << 32);
}

// ---- base64 (FB? export) -----------------------------------------------
static const char B64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string b64_encode(const uint8_t* data, size_t n) {
    std::string out;
    out.reserve(((n + 2) / 3) * 4);
    for (size_t i = 0; i < n; i += 3) {
        uint32_t v = (uint32_t)data[i] << 16;
        if (i + 1 < n) v |= (uint32_t)data[i + 1] << 8;
        if (i + 2 < n) v |= (uint32_t)data[i + 2];
        out.push_back(B64[(v >> 18) & 63]);
        out.push_back(B64[(v >> 12) & 63]);
        out.push_back(i + 1 < n ? B64[(v >> 6) & 63] : '=');
        out.push_back(i + 2 < n ? B64[v & 63] : '=');
    }
    return out;
}

// ---- SD card model (from BASIC sim/sim_main.cpp) -------------------------
static const unsigned SD_SECTOR = 512;
static const unsigned SD_WRITE_BUSY_BYTES = 8;

struct SdCard {
    std::vector<uint8_t> image;
    std::vector<uint8_t> tx;
    size_t tx_head = 0;
    bool   present = false;
    bool     prev_sck = false;
    bool     prev_cs_n = true;
    unsigned bit_i = 0;
    uint8_t  tx_byte = 0xFF;
    uint8_t  rx_byte = 0;
    uint8_t  miso_hold = 1;
    int      rx_mode = 0;
    uint8_t  cmd_buf[6];
    unsigned cmd_len = 0;
    uint32_t write_lba = 0;
    std::vector<uint8_t> write_buf;
    unsigned write_crc_left = 0;
    bool app_cmd = false;
    bool idle = true;
    bool initialised = false;
    unsigned acmd41_count = 0;
    unsigned wake_clocks = 0;
    bool     dirty = false;

    void push(uint8_t b) { tx.push_back(b); }
    uint8_t pop() {
        if (tx_head < tx.size()) {
            uint8_t b = tx[tx_head++];
            if (tx_head == tx.size()) { tx.clear(); tx_head = 0; }
            return b;
        }
        return 0xFF;
    }
    void clear_tx() { tx.clear(); tx_head = 0; }

    uint8_t r1_for(unsigned index) {
        if (index == 55) { app_cmd = true; return idle ? 0x01 : 0x00; }
        if (app_cmd) {
            app_cmd = false;
            if (index == 41) {
                acmd41_count++;
                if (acmd41_count >= 2) { initialised = true; idle = false; return 0x00; }
                return 0x01;
            }
        }
        if (index == 0) return 0x01;
        if (index == 8) return 0x01;
        if (index == 58) return 0x00;
        if (index == 17 || index == 24) return initialised ? 0x00 : 0x01;
        if (index == 13) return 0x00;
        return 0x04;
    }

    void handle_command() {
        unsigned index = cmd_buf[0] & 0x3F;
        uint32_t arg = ((uint32_t)cmd_buf[1] << 24) | ((uint32_t)cmd_buf[2] << 16) |
                       ((uint32_t)cmd_buf[3] << 8) | (uint32_t)cmd_buf[4];
        uint8_t crc = cmd_buf[5];
        if (index == 0 && wake_clocks < 74) return;
        if (index == 0 && crc != 0x95) { push(0x09); return; }
        if (crc == 0x00) { push(0x09); return; }
        uint8_t r1 = r1_for(index);
        push(r1);
        if (index == 8) {
            push(0x00); push(0x00); push(0x01); push(0xAA);
        } else if (index == 58) {
            push(0x40); push(0xFF); push(0x80); push(0x00);
        } else if (index == 17 && r1 == 0x00) {
            size_t off = (size_t)arg * SD_SECTOR;
            push(0xFE);
            for (unsigned i = 0; i < SD_SECTOR; i++)
                push(off + i < image.size() ? image[off + i] : 0x00);
            push(0xFF); push(0xFF);
        } else if (index == 24 && r1 == 0x00) {
            write_lba = arg;
            rx_mode = 1;
        }
        if (index == 0) { idle = true; initialised = false; acmd41_count = 0; }
    }

    void byte_done() {
        if (rx_mode == 0) {
            if (cmd_len == 0 && rx_byte == 0xFF) return;
            cmd_buf[cmd_len++] = rx_byte;
            if (cmd_len >= 6) { handle_command(); cmd_len = 0; }
        } else if (rx_mode == 1) {
            if (rx_byte == 0xFE) { rx_mode = 2; write_buf.clear(); }
        } else if (rx_mode == 2) {
            write_buf.push_back(rx_byte);
            if (write_buf.size() >= SD_SECTOR) { rx_mode = 3; write_crc_left = 2; }
        } else {
            if (--write_crc_left == 0) {
                size_t off = (size_t)write_lba * SD_SECTOR;
                if (off + SD_SECTOR <= image.size())
                    std::memcpy(&image[off], write_buf.data(), SD_SECTOR);
                dirty = true;
                push(0x05);
                for (unsigned i = 0; i < SD_WRITE_BUSY_BYTES; i++) push(0x00);
                push(0xFF);
                rx_mode = 0;
            }
        }
    }

    bool hang = false;   // Gate: SD_HANG 1 -> the card never answers
    void step(bool cs_n, bool sck, bool mosi, uint8_t *miso_out) {
        if (!present || hang) { *miso_out = 1; return; }
        if (cs_n) {
            if (!prev_cs_n) { rx_mode = 0; cmd_len = 0; clear_tx(); }
            if (sck && !prev_sck && wake_clocks < 1000) wake_clocks++;
            bit_i = 0;
            miso_hold = 1;
            *miso_out = 1;
        } else if (sck && !prev_sck) {
            if (bit_i == 0) tx_byte = pop();
            rx_byte = (uint8_t)((rx_byte << 1) | (mosi ? 1 : 0));
            miso_hold = (uint8_t)((tx_byte >> (7 - bit_i)) & 1);
            *miso_out = miso_hold;
            if (++bit_i == 8) { bit_i = 0; byte_done(); }
        } else {
            *miso_out = miso_hold;
        }
        prev_sck  = sck;
        prev_cs_n = cs_n;
    }
};

static SdCard sd;
static std::string sd_path;

static void sd_save_image() {
    if (!sd.dirty || sd_path.empty() || sd.image.empty()) return;
    FILE *f = std::fopen(sd_path.c_str(), "wb");
    if (!f) return;
    std::fwrite(sd.image.data(), 1, sd.image.size(), f);
    std::fclose(f);
    sd.dirty = false;
}

static void sd_load_image() {
    const char *env = std::getenv("JMR_CARD_IMG");
    const char *paths[] = {env, "../card.img", "card.img", "../../card.img"};
    for (const char *p : paths) {
        if (!p) continue;
        FILE *f = std::fopen(p, "rb");
        if (!f) continue;
        std::fseek(f, 0, SEEK_END);
        long n = std::ftell(f);
        std::fseek(f, 0, SEEK_SET);
        if (n > 0) {
            sd.image.resize((size_t)n);
            size_t got = std::fread(sd.image.data(), 1, (size_t)n, f);
            sd.image.resize(got);
            sd.present = got >= SD_SECTOR;
        }
        std::fclose(f);
        if (sd.present) {
            sd_path = p;
            std::cerr << "SD image " << p << " (" << sd.image.size() << " bytes)\n";
            return;
        }
    }
    std::cerr << "WARN: no card.img — DIR will ?IO\n";
}

// VARWATCH observes actual Value64 global valid/raw-word transitions.
// -1 disables. Minimal bring-up watchpoint (stderr, off by default).
static int watch_slot = -1;
static uint64_t watch_prev = 0;
static bool watch_valid_prev = false;
// VSTWATCH <slot|-1> — log every change of vstack BRAM slot with ip/state
static int vst_watch_slot = -1;
static uint64_t vst_watch_prev = 0;
static std::vector<std::string> vst_watch_log;
// VVWATCH <slot|-1> — log every change of vvars[slot] (Value64 global)
static int vvw_slot = -1;
static uint64_t vvw_prev = 0;
static std::vector<std::string> vvw_log;
// BEATLOG <ip> — once parent ip hits <ip>, log every beat's key signals
static int beat_ip = -1;
static std::vector<std::string> beat_log;
// ENVWATCH — log venv_valid transitions (slots 0..127)
static std::vector<std::string> gcsnap_log;
static uint64_t state_cycles[128];
static uint64_t exec_state_cycles[128];
static uint64_t heap_split[32];
static uint64_t envkey_hist[VM_MAX_VARS];
// RAFTRACE: log every change of the vraf_n parent/exec pair + mask (bug #69)
static std::vector<std::string> raf_log;
static bool raf_trace_on = false;
#include <map>
static std::map<unsigned, uint64_t> envip_hist;
static bool fw_on = false;
static uint8_t fw_vcsp_prev = 0;
static uint16_t fw_rip_prev[16];
static std::vector<std::string> fw_log;
static unsigned gcsnap_prev_state = 0;
static bool envw_on = false;
static uint8_t envw_prev[128];
static uint8_t envw_base[128];
static std::vector<std::string> envw_log;
// IPTRACE — ring of executed ip values (execution path). Arm with
// "IPTRACE <n>", dump+disarm with "IPTRACE?". Off by default.
struct VRingEnt {
    unsigned st; unsigned ip; uint64_t venv;
    unsigned vvr; unsigned vk; unsigned proto; unsigned gcp;
    unsigned vsp; uint64_t w0; uint64_t w1; uint64_t w2;
    unsigned pcsp; unsigned ecsp; unsigned flags; unsigned est;
};
static int ring_stop_ip = -1;
static VRingEnt vring[256];
static unsigned long vring_i = 0;
static bool vring_frozen = false;
static bool ring_on = false;
// Hot ips of a frame that hit the cap: the game is looping and this
// says where, so a normal GUI run yields the evidence with no extra
// steps for the user.
static unsigned loop_ip[3] = {0, 0, 0};
static unsigned loop_hits[3] = {0, 0, 0};
// Total ip changes during a capped frame: few => stuck on a handful of
// ops; many => cycling through a lot of code.
static unsigned long loop_ipn = 0;
static std::vector<unsigned> ip_hist;      // per-ip counts, whole frame
static unsigned top_ip[5] = {0,0,0,0,0};
static unsigned top_cnt[5] = {0,0,0,0,0};
// Where a capped frame spends its instructions, in 256-op regions.
static unsigned hot_lo[3] = {0, 0, 0};
static unsigned long hot_n[3] = {0, 0, 0};
static unsigned long state_prof[128] = {0};
static unsigned long prof_cycles = 0;
static bool prof_on = false;
// ENVWATCH — log every venv_valid[idx] transition with state/ip.
struct EnvEvt { unsigned st; unsigned ip; unsigned val; uint64_t venv; };
static std::vector<EnvEvt> env_evts;
static int env_watch = -1;
static unsigned env_watch_prev = 0;
static unsigned env_prev[8] = {0};
static std::vector<uint16_t> ip_trace;
static size_t ip_trace_cap = 0;
static uint16_t ip_trace_prev = 0xffff;
static std::vector<uint16_t> ip_trace_vsp; // exec vsp at each recorded ip
static bool ip_trace_user = false; // IPTRACE <n> armed by RPC: FRAME must not wipe it
// KEYEVT tap-deferral (see the KEYEVT handler): ups held to the next frame
static uint64_t key_frame_counter = 1;
static uint64_t key_last_down_frame[256] = {0};
static uint64_t key_pending_up[256] = {0}; // 0=none, else flush at this frame counter
// Last FRAME clocks / cap — play log showed swaps<<fb_frames with no
// clk, so a 2M-clock cap abort was invisible.
static unsigned last_fclk = 0;
static unsigned last_fcap = 0;
static unsigned fcap_n = 0;
// A bounded FRAME RPC is a slice of one logical frame. Retain its pulse and
// completion baseline across slices; reaching WAIT on resume must not launch
// a second callback. Reset/start/stop invalidate any suspended host operation.
struct FrameResume {
    bool pending = false;
    bool pulsed = false;
    bool left_wait = false;
    bool plain = false;
    unsigned idle_run = 0;
    unsigned swap0 = 0;
    uint64_t epoch = 0;
};
static FrameResume frame_resume;
static uint64_t frame_epoch = 0;
// Latch rAF/fn SRAM view on first fault — later IDLE ticks overwrite rdata.
static unsigned fault_snap_code = 0;
static unsigned fault_snap_raddr = 0;
static unsigned fault_snap_valid = 0;
// ENVSNAP: the faulting env, latched at the fault EDGE (pre-NBA hold), so the
// 16-slot wall's true tenant is unambiguous. VMSTAT reads live regs long after
// the fault and named the wrong env once already.
static unsigned envsnap_eid = 0, envsnap_len = 0, envsnap_key = 0, envsnap_phase = 0;
static unsigned envsnap_slots[16];
static unsigned hold_eid = 0, hold_len = 0, hold_key = 0, hold_phase = 0;
static unsigned hold_venv_ff = 0, hold_venv_q = 0, hold_m_venv = 0;
static unsigned envsnap_venv_ff = 0, envsnap_venv_q = 0, envsnap_m_venv = 0;
static unsigned fault_snap_gen = 0;
static unsigned fault_snap_akind = 0;
static unsigned fault_snap_ai = 0;
static unsigned fault_snap_vsp = 0;
static unsigned fault_snap_vcsp = 0;
static unsigned fault_snap_hvcsp = 0;
static unsigned fault_snap_opnd = 0;
static uint64_t fault_snap_w0 = 0;
static uint32_t fault_snap_cr = 0;
static unsigned fault_hold_raddr = 0;
static unsigned fault_hold_valid = 0;
static unsigned fault_hold_gen = 0;
static unsigned fault_hold_akind = 0;
static unsigned fault_hold_ai = 0;
static unsigned fault_hold_vsp = 0;
static unsigned fault_hold_vcsp = 0;
static unsigned fault_hold_hvcsp = 0;
static unsigned fault_hold_opnd = 0;
static uint64_t fault_hold_w0 = 0;
static uint32_t fault_hold_cr = 0;

// Must match jmr_js_vm.sv st_t declaration order (VMSTAT sname=).
static const char* vm_sname(unsigned s) {
    static const char* N[] = {
        "S_IDLE","S_RD","S_GOT_MAGIC","S_GOT_HDR1","S_GOT_HDR2","S_LD_CONST",
        "S_TRAIL","S_FETCH_WAIT","S_CLEAR","S_RECT","S_CIRCLE",
        "S_LINE","S_BLIT","S_SPR","S_WAIT_FRAME","S_DONE","S_XF_MUL","S_XF_APPLY",
        "S_PWALK","S_PDO","S_QSEG","S_QPX","S_QPY","S_JOIN","S_JOIN_FIND",
        "S_CONCAT","S_SQRT",
        "S_JSON_PARSE","S_REPL","S_IDXSTR",
        "S_FONTPX","S_TXT_LD","S_TXT_DRAW","S_STR_WR","S_IMGD_GET","S_IMGD_PUT",
        "S_NAMCPY",
        "S_V64_CONST_HI","S_V64_EXEC","S_V64_DIV","S_V64_DIV_FIN","S_V64_MOD",
        "S_V64_ALLOC","S_V64_GC_CLEAR","S_V64_GC_ROOT","S_V64_GC_POP",
        "S_V64_GC_OBJ","S_V64_GC_ARR","S_V64_GC_SWEEP_OBJ",
        "S_V64_GC_SWEEP_ARR","S_V64_GC_FN","S_V64_GC_ENV",
        "S_V64_GC_SWEEP_ENV","S_V64_CLEAR","S_V64_RECT",
        "S_V64_FRAME_RAF","S_V64_FRAME_TIMER",
        "S_V64_FOREACH","S_V64_FRAME_KEY","S_V64_STRIDX","S_V64_STRIDX_WR",
        "S_V64_JSON","S_V64_JSON_PARSE","S_V64_CTOR_PAD",
        "S_HEAP_WAIT","S_HEAP_CMP","S_HEAP_WR","S_HEAP_AWR","S_HEAP_FILL",
        "S_V64_METH","S_V64_FE_ELEM","S_V64_FE_FILTER","S_V64_OGETI_NAT",
        "S_V64_IDXSCAN","S_V64_CTOR_ENV","S_V64_CTOR_VARS","S_FREE_OBJ","S_FREE_ARR",
        "S_V64_BIND","S_V64_MINMAX","S_V64_WIN_FILL","S_ARR_PROMOTE",
        "S_V64_RECT_LD","S_HEAP_CLR",
        // Keep in lockstep with the parent st_t: this table indexes by
        // NUMBER. Missing entries print `sname=?` and cost debugging time.
        "S_V64_SLICE","S_V64_SORT","S_FB_SYNC","S_V64_DISPATCH",
        // V1.5 standalone compile: one state for the whole memory ABI.
        "S_CSRAM","S_V64_MOUSE_PROP","S_UI_PROP","S_FS","S_V64_KEYS","S_V64_BYTESTRING","S_V64_CALLREF"
    };
    if (s < (unsigned)(sizeof(N) / sizeof(N[0]))) return N[s];
    return "?";
}
static int vm_sidx(const char* name) {
    for (unsigned i = 0; i < 127; i++)
        if (!strcmp(vm_sname(i), name)) return (int)i;
    return -1;
}
// SYNCPROF (JMR_SYNCPROF=1): per-present, cycles of the S_FB_SYNC stall and
// the distance from sync ENTRY to the frame's first draw-state entry — the
// exact bound on a present/VM overlap win.
static FILE* syncprof_f = nullptr;
static int syncprof_gate = -1;
static uint64_t sp_clk = 0, sp_sync_entry = 0, sp_sync_exit = 0;
static uint64_t tear_count_live = 0;
static unsigned hiwater_arr = 0, hiwater_obj = 0;
static int sp_wait_draw = 0;
static unsigned sp_prev_st = 255;
static void syncprof_tick(unsigned st) {
    static int fb_sync = -2, dr[6];
    if (syncprof_gate < 0) {
        const char* g = getenv("JMR_SYNCPROF");
        syncprof_gate = (g && *g == '1') ? 1 : 0;
        if (syncprof_gate) {
            fb_sync = vm_sidx("S_FB_SYNC");
            dr[0] = vm_sidx("S_V64_RECT"); dr[1] = vm_sidx("S_V64_CLEAR");
            dr[2] = vm_sidx("S_BLIT");     dr[3] = vm_sidx("S_CLEAR");
            dr[4] = vm_sidx("S_IMGD_PUT"); dr[5] = vm_sidx("S_V64_RECT_LD");
            syncprof_f = fopen("/tmp/syncprof.log", "w");
            if (syncprof_f) fprintf(syncprof_f, "# fb_sync=%d draws=%d,%d,%d,%d,%d,%d\n",
                fb_sync, dr[0], dr[1], dr[2], dr[3], dr[4], dr[5]);
            if (syncprof_f) fflush(syncprof_f);
        }
    }
    if (!syncprof_gate) return;
    sp_clk++;
    if (st != sp_prev_st) {
        if ((int)st == fb_sync) { sp_sync_entry = sp_clk; }
        else if ((int)sp_prev_st == fb_sync) {
            sp_sync_exit = sp_clk; sp_wait_draw = 1;
        }
        if (sp_wait_draw)
            for (int k = 0; k < 6; k++)
                if ((int)st == dr[k] && dr[k] >= 0) {
                    if (syncprof_f) fprintf(syncprof_f,
                        "stall=%llu headroom=%llu exit2draw=%llu\n",
                        (unsigned long long)(sp_sync_exit - sp_sync_entry),
                        (unsigned long long)(sp_clk - sp_sync_entry),
                        (unsigned long long)(sp_clk - sp_sync_exit));
                    if (syncprof_f) fflush(syncprof_f);
                    sp_wait_draw = 0; break;
                }
        sp_prev_st = st;
    }
}

static unsigned vsp_peak = 0, gcq_peak = 0, nbwp_peak = 0, jsonwp_peak = 0;
static unsigned long long cm_cycles = 0, cm_lookups = 0, total_cycles = 0;
static unsigned long long lsv_cycles = 0, lsv_reqs = 0, lsv_serv_cycles = 0, lsv_res_cycles = 0;
static unsigned long realtick_period = 0;
static unsigned long realtick_ctr = 0;
// Board audio environment:12MHz MCLK against this100MHz simulation clock.
// This models the actual PSG request synchronizer/capture acknowledgement,
// not an immediate loopback. Full PSG phase/reset tests cover the RTL peer.
// Reset release matches top_nexys_video's two audio-clock stages.
static void audio_environment_step() {
    static unsigned phase = 0, reset_pipe = 0, request_pipe = 0;
    static bool acknowledgement = false;
    if (!top->rst_n) {
        reset_pipe = 0; request_pipe = 0; acknowledgement = false;
    }
    phase += 3;
    if (phase >= 25) {
        phase -= 25;
        const bool audio_ready = (reset_pipe & 2u) != 0;
        reset_pipe = top->rst_n ? ((reset_pipe << 1) | 1u) & 3u : 0u;
        if (!audio_ready) { request_pipe = 0; acknowledgement = false; }
        else {
            if (((request_pipe >> 2) ^ (request_pipe >> 1)) & 1u)
                acknowledgement = ((request_pipe >> 1) & 1u) != 0;
            request_pipe = ((request_pipe << 1) | unsigned(top->snd_tgl)) & 7u;
        }
    }
    top->snd_ack = acknowledgement;
}

// OPPROF: clocks per instruction by opcode (OPPROFCLR / OPPROF?).
// Sampled once per core clock; the VM clock is core/VM_CLK_DIV (3), so the
// reply divides by 3. Idle states (S_IDLE, S_DONE, S_WAIT_FRAME) are not
// counted. Each busy clock is charged to the op word exec64 holds (opw_q);
// one instruction = one change of the VM's ip, charged to the op that held
// the word just before the change (the op that retired).
static bool opprof_on = false;
static uint64_t opprof_cyc[256], opprof_n[256];
static uint64_t opprof_idle = 0, opprof_insn = 0, opprof_busy = 0;
static std::map<uint32_t, std::pair<uint64_t, uint64_t>> opprof_sub; // (op<<16|arg) -> (n,cyc)
static unsigned opprof_prev_ip = 0xffffffffu;
static uint32_t opprof_prev_w = 0;
static uint32_t opprof_subkey(uint32_t w) {
    unsigned op = w & 0xff;
    if (op == 13 || op == 30 || op == 34) return (uint32_t(op) << 16) | ((w >> 8) & 0xffff);
    // Variable ops by a1 (1 global, >=2 local slot hint, 0 generic).
    if (op == 2 || op == 3 || op == 22) return (uint32_t(op) << 16) | 0x8000u | (w >> 24);
    return 0;
}
// ITRACE (JMR_ITRACE=<file>): one line per ip change while the VM is busy:
// ip vsp win0 win1. Two builds of the same program diff to the first
// instruction whose result differs (A/B of a clock-saving change).
static FILE* itrace_f = nullptr;
static int itrace_gate = -1;
static unsigned itrace_prev_ip = 0xffffffffu;
static void itrace_tick() {
    if (itrace_gate < 0) {
        const char* p = getenv("JMR_ITRACE");
        itrace_gate = (p && *p) ? 1 : 0;
        if (itrace_gate) itrace_f = fopen(p, "w");
        if (!itrace_f) itrace_gate = 0;
    }
    if (!itrace_gate) return;
    auto* r = top->rootp;
    unsigned st = unsigned(r->jmr_js_core__DOT__u_vm__DOT__state) & 127;
    if (st == 0 || st == 15 || st == 14) return;
    unsigned ip = unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip) & 0xffff;
    if (ip == itrace_prev_ip) return;
    itrace_prev_ip = ip;
    fprintf(itrace_f, "%u %u %016llx %016llx\n", ip,
            unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp) & 0xfff,
            (unsigned long long)r->jmr_js_core__DOT__u_vm__DOT__vst_win[0],
            (unsigned long long)r->jmr_js_core__DOT__u_vm__DOT__vst_win[1]);
}

// BTRACE (JMR_BTRACE=<file>): every change of the fetch/exec beat signals,
// first 4000 lines after the VM first reaches S_V64_EXEC.
static FILE* btrace_f = nullptr;
static int btrace_gate = -1, btrace_n = 0;
static std::string btrace_prev;
static void btrace_tick() {
    if (btrace_gate < 0) {
        const char* p = getenv("JMR_BTRACE");
        btrace_gate = (p && *p) ? 1 : 0;
        if (btrace_gate) btrace_f = fopen(p, "w");
        if (!btrace_f) btrace_gate = 0;
    }
    if (!btrace_gate || btrace_n > 4000) return;
    auto* r = top->rootp;
    unsigned st = unsigned(r->jmr_js_core__DOT__u_vm__DOT__state) & 127;
    if (btrace_n == 0 && st != 38) return;
    char b[300];
    std::snprintf(b, sizeof b,
        "st=%u est=%u cs=%u lh=%u o=%u%u%u ip=%u eip=%u cra=%u ecra=%u opw=%08x crd=%08x vsp=%u w0=%016llx al=%u%u ln=%u",
        st, unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state) & 127,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__casestate_q) & 127,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_leave_hold),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd_q),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd2_q),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd3_q),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip) & 0xffff,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip) & 0xffff,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__code_raddr) & 0xffff,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__code_raddr) & 0xffff,
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opw_q),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__code_rdata),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp) & 0xfff,
        (unsigned long long)r->jmr_js_core__DOT__u_vm__DOT__vst_win[0],
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_valid_rdata),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_long_rdata),
        unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_len_rdata));
    if (btrace_prev != b) {
        fprintf(btrace_f, "%s\n", b);
        btrace_prev = b;
        btrace_n++;
        if (btrace_n > 4000) fflush(btrace_f);
    }
}

static void opprof_tick() {
    itrace_tick();
    btrace_tick();
    if (!opprof_on) return;
    auto* r = top->rootp;
    unsigned st = unsigned(r->jmr_js_core__DOT__u_vm__DOT__state) & 127;
    uint32_t w = r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opw_q;
    unsigned ip = unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip) & 0xffff;
    if (st == 0 || st == 15 || st == 14) {
        opprof_idle++; opprof_prev_ip = ip; opprof_prev_w = w; return;
    }
    opprof_busy++;
    if (opprof_prev_ip != 0xffffffffu && ip != opprof_prev_ip) {
        opprof_n[opprof_prev_w & 0xff]++; opprof_insn++;
        if (uint32_t s = opprof_subkey(opprof_prev_w)) opprof_sub[s].first++;
    }
    opprof_cyc[w & 0xff]++;
    if (uint32_t s = opprof_subkey(w)) opprof_sub[s].second++;
    opprof_prev_ip = ip; opprof_prev_w = w;
}

static void tick() {
    // REALTICK: board-faithful async frame_tick — pulses on a free-running
    // divider REGARDLESS of VM state (the FRAME rpc's pulse is gated on
    // S_WAIT_FRAME and can never land mid-JS; the real 60 Hz vsync can).
    if (realtick_period) {
        if (++realtick_ctr >= realtick_period) {
            realtick_ctr = 0;
            top->sim_frame_pulse = 1;
        }
    }
    audio_environment_step();
    top->host_q_ready = finder_responses.size() < 1024;
    top->clk = 0; top->pixel_clk = 0; top->eval();
    finder_capture_response();
    if (!top->rst_n || top->rootp->jmr_js_core__DOT__vm_start_lat
        || top->rootp->jmr_js_core__DOT__vm_stop_lat) {
        frame_resume = FrameResume{};
        ++frame_epoch;
    }
    uint8_t miso = 1;
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
    top->clk = 1; top->pixel_clk = 1; top->eval();
    sd.step(top->sd_cs_n != 0, top->sd_sck != 0, top->sd_mosi != 0, &miso);
    top->sd_miso = miso;
    if (realtick_period && realtick_ctr == 0) top->sim_frame_pulse = 0; // end REALTICK pulse
    {   // per-clock peak trackers (transient-safe, unlike frame sampling)
        unsigned v = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__vsp);
        if (v > vsp_peak) vsp_peak = v;
        {
            static bool prev_lsv = false;
            bool lv = top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__lsv_scan;
            if (lv) lsv_cycles++;
            if (lv && !prev_lsv) lsv_reqs++;
            prev_lsv = lv;
            if (top->rootp->jmr_js_core__DOT__u_vm__DOT__lsv_serving) lsv_serv_cycles++;
            if (top->rootp->jmr_js_core__DOT__u_vm__DOT__lsv_res_we) lsv_res_cycles++;
        }
        {
            static bool prev_cm = false;
            bool cm = top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__cm_scan;
            if (cm) cm_cycles++;
            if (cm && !prev_cm) cm_lookups++;
            prev_cm = cm;
            total_cycles++;
        }
        unsigned nb = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__nb_wp);
        if (nb > nbwp_peak) nbwp_peak = nb;
        unsigned jw = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__json_wp);
        if (jw > jsonwp_peak) jsonwp_peak = jw;
        unsigned qr = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__vgc_qr);
        unsigned qw = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__vgc_qw);
        unsigned occ = (qw - qr) & 0x3FFFu;
        if (occ > gcq_peak) gcq_peak = occ;
    }
    if (watch_slot >= 0) {
        auto* r = top->rootp;
        const bool valid = r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[watch_slot];
        const uint64_t word = valid
            ? uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vvars[watch_slot]) : 0u;
        if (valid != watch_valid_prev || (valid && word != watch_prev)) {
            std::cerr << "VARW64 slot=" << watch_slot << " valid=" << valid;
            if (valid) std::cerr << " raw=0x" << std::hex << word << std::dec;
            std::cerr << " ip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip)
                      << " state=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__state)
                      << "\n";
            watch_valid_prev = valid;
            watch_prev = word;
        }
    }
    opprof_tick();
    if (prof_on) {
        unsigned st_ = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state);
        if (st_ < 128) state_prof[st_]++;
        prof_cycles++;
    }
    if (env_watch >= 0) {
        // Watch slots 0..7 so a re-alloc into a neighbour is visible too.
        auto* rr = top->rootp;
        for (int sl = 0; sl < 8; sl++) {
            unsigned v = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
            if (v != env_prev[sl]) {
                if (env_evts.size() < 64)
                    env_evts.push_back({unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state),
                                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip),
                                        (v << 8) | unsigned(sl),
                                        uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__venv)});
                env_prev[sl] = v;
            }
        }
    }
    if (ring_on) {
        // Rolling cycle ring for fault forensics (VRING?). Freezes the
        // instant fault_code goes nonzero so the ring holds the run-up.
        auto* rr = top->rootp;
        static unsigned run_prev = 0;
        unsigned run_now = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__running);
        if (!vring_frozen && rr->jmr_js_core__DOT__u_vm__DOT__fault_code)
            vring_frozen = true;
        // Also freeze on the running 1->0 edge: a clean halt (no fault code)
        // otherwise leaves no evidence of what stopped the machine.
        if (!vring_frozen && run_prev && !run_now)
            vring_frozen = true;
        run_prev = run_now;
        if (!vring_frozen)
        vring[vring_i & 255] = {
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__venv),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_valid_rdata),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__valloc_kind),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_proto_arm),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vsp),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[0]),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[1]),
            uint64_t(rr->jmr_js_core__DOT__u_vm__DOT__vst_win[2]),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcsp),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vsp),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd_q)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd2_q) << 1)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd3_q) << 2)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hash2_q) << 3)
              | (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__cm_win) << 4),
            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state)};
        if (ring_stop_ip >= 0 &&
            int(rr->jmr_js_core__DOT__u_vm__DOT__ip) == ring_stop_ip)
            vring_frozen = true;
        if (!vring_frozen) vring_i++;
    }
    if (vst_watch_slot >= 0 && vst_watch_log.size() < 64) {
        uint64_t v = uint64_t(
            top->rootp->jmr_js_core__DOT__u_vm__DOT__vstack[vst_watch_slot]);
        if (v != vst_watch_prev) {
            char b[160];
            std::snprintf(b, sizeof b,
                "[ip=%u st=%u est=%u esp=%u waddr=%u v=%016llx->%016llx]",
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vsp),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vst_waddr),
                (unsigned long long)vst_watch_prev, (unsigned long long)v);
            vst_watch_log.push_back(b);
            vst_watch_prev = v;
        }
    }
    if (fw_on) {
        auto* rf = top->rootp;
        static bool fw_frozen = false;
        unsigned curip = unsigned(rf->jmr_js_core__DOT__u_vm__DOT__ip);
        if (fw_log.size() == 0) fw_frozen = false;
        if (!fw_frozen &&
            unsigned(rf->jmr_js_core__DOT__u_vm__DOT__vcsp) > 12) {
            fw_frozen = true;
            fw_log.push_back("[WARP]");
        }
        if (!fw_frozen) {
        uint8_t vc = uint8_t(rf->jmr_js_core__DOT__u_vm__DOT__vcsp);
        if (fw_log.size() > 60) fw_log.erase(fw_log.begin(), fw_log.begin()+20);
        if (vc != fw_vcsp_prev) {
            char b[100];
            std::snprintf(b, sizeof b, "[csp %u->%u ip=%u st=%u]",
                fw_vcsp_prev, vc,
                unsigned(rf->jmr_js_core__DOT__u_vm__DOT__ip),
                unsigned(rf->jmr_js_core__DOT__u_vm__DOT__state));
            fw_log.push_back(b);
            fw_vcsp_prev = vc;
        }
        for (int k = 0; k < 12; k++) {
            uint16_t rip = uint16_t(((rf->jmr_js_core__DOT__u_vm__DOT__vframe_control[k] >> 12) & 0xffffu));
            if (rip != fw_rip_prev[k]) {
                char b[100];
                std::snprintf(b, sizeof b, "[rip%d=%u ip=%u st=%u]",
                    k, unsigned(rip),
                    unsigned(rf->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(rf->jmr_js_core__DOT__u_vm__DOT__state));
                fw_log.push_back(b);
                fw_rip_prev[k] = rip;
            }
        }
        }
    }
    if (raf_trace_on && raf_log.size() < 3000) {
        auto* rr = top->rootp;
        static unsigned prev = 0xffffffff;
        unsigned cur =
            (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vraf_n_ff) & 15) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vraf_n) & 15) << 4) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hs_m_vraf_n) & 1) << 8) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vraf_snap_n) & 15) << 9) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vraf_i) & 15) << 13) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__jn_slot_arm) & 1) << 17) |
            ((unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state) & 127) << 18);
        if (cur != prev) {
            char b[160];
            std::snprintf(b, sizeof b,
                "[st=%u cst=%u ip=%u ff=%u eq=%u m=%u snap=%u i=%u jn=%u]",
                unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state),
                unsigned(rr->jmr_js_core__DOT__u_vm__DOT__casestate_q),
                unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip),
                cur & 15, (cur >> 4) & 15, (cur >> 8) & 1,
                (cur >> 9) & 15, (cur >> 13) & 15, (cur >> 17) & 1);
            raf_log.push_back(b);
            prev = cur;
        }
    }
    {
        unsigned sc = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state) & 127;
        state_cycles[sc]++;
        syncprof_tick(sc);
        // HIWATER: max slot-store addresses ever written — the truth about
        // how much of the 100-tile varr / 73-tile vobj stores titles touch.
        {
            static unsigned hw_arr = 0, hw_obj = 0;
            auto* rr3 = top->rootp;
            if (unsigned(rr3->jmr_js_core__DOT__u_vm__DOT__varr_we)) {
                unsigned a = unsigned(rr3->jmr_js_core__DOT__u_vm__DOT__varr_waddr);
                if (a > hw_arr) hw_arr = a;
            }
            if (unsigned(rr3->jmr_js_core__DOT__u_vm__DOT__vobj_we)) {
                unsigned a = unsigned(rr3->jmr_js_core__DOT__u_vm__DOT__vobj_waddr);
                if (a > hw_obj) hw_obj = a;
            }
            hiwater_arr = hw_arr; hiwater_obj = hw_obj;
        }
        // TEARCHECK: any fb write while the DDR3 present is copying = the
        // display-tear window. Counted always; JMR_TEARLOG=1 logs first 32.
        {
            static uint64_t tear_n = 0; static int tgate = -1; static FILE* tf = nullptr;
            auto* rr2 = top->rootp;
            if (unsigned(rr2->jmr_js_core__DOT__fb_we) &&
                unsigned(rr2->jmr_js_core__DOT__fb_present_busy)) {
                tear_n++;
                if (tgate < 0) { const char* g = getenv("JMR_TEARLOG"); tgate = (g && *g == '1') ? 1 : 0; }
                if (tgate == 1 && tear_n <= 32) {
                    if (!tf) tf = fopen("/tmp/tear.log", "w");
                    if (tf) { fprintf(tf, "tear#%llu st=%u ip=%u\n",
                        (unsigned long long)tear_n, sc,
                        unsigned(rr2->jmr_js_core__DOT__u_vm__DOT__ip)); fflush(tf); }
                }
            }
            tear_count_live = tear_n;
        }
        // Piece-1 checker: during EXEC the op word register must
        // equal code memory at the executing ip — a stale or mis-invalidated
        // prefetch dies loudly on the FIRST wrong op, across every test.
        unsigned esc = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state) & 127;
        // env-alloc scan trace: ring of the last 4096 clks inside
        // S_V64_ALLOC kind=3, dumped at machine_fault rise.
        {
            static uint64_t ring[4096]; static unsigned rw = 0; static bool dumped = false;
            auto* rr = top->rootp;
            unsigned st = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state) & 127;
            // venv_len lifecycle log (JMR_LENLOG=1): every len write + context.
            {
                static FILE* lf = nullptr; static int lgate = -1;
                if (lgate < 0) { const char* g = getenv("JMR_LENLOG"); lgate = (g && *g == '1') ? 1 : 0; }
                static unsigned lx_ip = 0, lx_opw = 0;
                // GENUINE exec beat: BOTH the parent and exec64 sit in S_V64_EXEC.
                // (exec64 parks in EXEC during parent flows — gating only on it
                // made this tracker chase parent fetches. That burned hours.)
                if (lgate == 1 &&
                    (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state) & 127) == 38 &&
                    (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state) & 127) == 38) {
                    lx_ip = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip);
                    lx_opw = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opw_q);
                }
                static FILE* cwf = nullptr;
                static uint32_t w4360_prev = 0xdeadbeef;
                {
                    uint32_t w = unsigned(rr->jmr_js_core__DOT__u_vm__DOT__code_mem_c0[4360]);
                    if (w != w4360_prev) {
                        if (!cwf) cwf = fopen("/tmp/codewe.log", "w");
                        if (cwf) fprintf(cwf, "CLK-CHANGE 4360: %08x -> %08x st=%u ip=%u\n",
                            w4360_prev, w,
                            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__state) & 127,
                            unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip));
                        if (cwf) fflush(cwf);
                        w4360_prev = w;
                    }
                }
                if (lgate == 1 && unsigned(rr->jmr_js_core__DOT__code_we)) {
                    if (!cwf) cwf = fopen("/tmp/codewe.log", "w");
                    if (cwf) fprintf(cwf, "waddr=%u wdata=%08x\n",
                        unsigned(rr->jmr_js_core__DOT__code_waddr),
                        unsigned(rr->jmr_js_core__DOT__code_wdata));
                }
                if (lgate == 1 && unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vel_we)) {
                    if (!lf) lf = fopen("/tmp/lenlife.log", "w");
                    if (lf) fprintf(lf, "wa=%u wd=%u st=%u cs=%u eid=%u key=%u ip=%u\n",
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vel_wa),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vel_wd),
                        st, unsigned(rr->jmr_js_core__DOT__u_vm__DOT__casestate_q) & 127,
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_eid_ff),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_key_ff),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ip));
                    if (lf) fprintf(lf, "  eip=%u eopw=%08x eeid=%u ekey=%u ephase=%u\n",
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opw_q),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hp_eid),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hp_key),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_phase));
                    if (lf) fprintf(lf, "  lastexec ip=%u opw=%08x\n", lx_ip, lx_opw);
                    if (lf) fprintf(lf, "  bind k=%u n=%u ip=%u ent=%u lets=%u scan=%u\n",
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__bind_k),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__bind_n),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__bind_ip),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcall_entry_ff),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vctor_lets),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vctor_scan));
                    if (lf) fprintf(lf, "  hs64=%u meid=%u\n",
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hs64),
                        unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hs_m_hp_eid));
                    if (lf && rr->jmr_js_core__DOT__u_vm__DOT__machine_fault) fflush(lf);
                }
                if (lgate == 1 && lf && rr->jmr_js_core__DOT__u_vm__DOT__machine_fault) fflush(lf);
            }
            if (st == 42 && (unsigned(rr->jmr_js_core__DOT__u_vm__DOT__valloc_kind) & 3) == 3) {
                uint64_t e = 0;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__valloc_i) & 0x3fff);
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_valid_rdata) & 1) << 14;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hp_proto_arm) & 1) << 15;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend) & 1) << 16;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__casestate_q) & 127) << 17;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__venv_next) & 0x3ff) << 24;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcall_value) & 1) << 34;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcallback_fe) & 1) << 35;
                {
                    uint64_t ve = 0;
                    ve = (uint64_t)rr->jmr_js_core__DOT__u_vm__DOT__venv;
                    e |= (uint64_t)(((ve >> 48) == 0x7ff9ull && ((ve >> 44) & 0xf) == 9) ? 1 : 0) << 36;
                    uint64_t cv = (uint64_t)rr->jmr_js_core__DOT__u_vm__DOT__vcall_ctor_val;
                    e |= (uint64_t)(((cv >> 48) == 0x7ff9ull && ((cv >> 44) & 0xf) == 4) ? 1 : 0) << 37;
                }
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__vcall_entry) & 0xff) << 38;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__valloc_rd_arm) & 1) << 46;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__bind_rd_arm) & 1) << 47;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hs_m_state) & 1) << 48;
                e |= (uint64_t)(unsigned(rr->jmr_js_core__DOT__u_vm__DOT__hs_m_ip) & 1) << 49;
                ring[rw++ & 4095] = e | (1ull << 63);
            }
            if (!dumped && rr->jmr_js_core__DOT__u_vm__DOT__machine_fault) {
                dumped = true;
                FILE* f = fopen("/tmp/envscan.log", "w");
                if (f) {
                    for (unsigned i = 0; i < 4096; i++) {
                        uint64_t e = ring[(rw + i) & 4095];
                        if (!(e >> 63)) continue;
                        fprintf(f, "vi=%llu ok=%llu proto=%llu pend=%llu cs=%llu nx=%llu cv=%llu fe=%llu envh=%llu ctoro=%llu ent=%llu ra=%llu ba=%llu mS=%llu mI=%llu\n",
                            (unsigned long long)(e & 0x3fff),
                            (unsigned long long)((e >> 14) & 1),
                            (unsigned long long)((e >> 15) & 1),
                            (unsigned long long)((e >> 16) & 1),
                            (unsigned long long)((e >> 17) & 127),
                            (unsigned long long)((e >> 24) & 0x3ff),
                            (unsigned long long)((e >> 34) & 1),
                            (unsigned long long)((e >> 35) & 1),
                            (unsigned long long)((e >> 36) & 1),
                            (unsigned long long)((e >> 37) & 1),
                            (unsigned long long)((e >> 38) & 0xff),
                            (unsigned long long)((e >> 46) & 1),
                            (unsigned long long)((e >> 47) & 1),
                            (unsigned long long)((e >> 48) & 1),
                            (unsigned long long)((e >> 49) & 1));
                    }
                    fclose(f);
                }
            }
        }
        // Handshake trace: log every core clk around fetch-wait/EXEC
        // transitions for the first 400 interesting clks after RUN.
        {
            static int hst_n = 0;
            static FILE* hst = nullptr;
            unsigned psc = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state) & 127;
            if (hst_n < 400 && (psc == 38 || psc == 7 || esc == 38 || esc == 7)) {
                if (!hst) hst = fopen("/tmp/hs_trace.log", "w");
                if (hst) {
                    fprintf(hst,
                        "clk p=%u e=%u mS=%u mC=%u ff=%u eCR=%u lh=%u ip=%u en?\n",
                        psc, esc,
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hs_m_state),
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hs_m_code),
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__code_raddr_ff),
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__code_raddr),
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__e64_leave_hold),
                        unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip));
                    hst_n++;
                    if (hst_n == 400) fclose(hst);
                }
            }
        }
        if (sc == 38 && esc == 38) {
            // both the parent view AND exec64's own state must say EXEC —
            // the parent lags exec64 by a handshake beat around
            // transitions (first version false-fired on that lag beat,
            // reading the advanced ip against the not-yet-captured word).
            unsigned eip = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip);
            unsigned ob = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__ops_base);
            unsigned ca = (ob + eip) & 0xffff;
            uint32_t want = code_word(top->rootp,ca);
            uint32_t got = top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opw_q;
            if (got != want) {
                FILE* pf = fopen("/tmp/pf_check.log", "a");
                if (pf) {
                    fprintf(pf, "PF-CHECK FAIL ip=%u opw_q=%08x code=%08x ops_base=%u\n",
                            eip, got, want, ob);
                    fclose(pf);
                }
                fprintf(stderr, "PF-CHECK FAIL ip=%u opw_q=%08x code=%08x\n", eip, got, want);
                abort();
            }
        }
        if (sc == 38) { // S_V64_EXEC: split by exec unit state
            unsigned ec = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state) & 127;
            exec_state_cycles[ec]++;
        }
        if (sc == 64 || sc == 65) { // HEAP_WAIT/CMP: split env vs hp_cmd
            unsigned env = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hp_env) & 1;
            unsigned cmd = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hp_cmd) & 15;
            unsigned ph = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hp_phase) & 7;
            heap_split[env ? (16 + ph * 2 + (cmd == 0 ? 0 : 1)) : cmd]++;
        }
        { // env-walk entry histogram by var key (LOAD/STORE name id)
            static unsigned prev_sc = 0;
            if ((sc == 64) && prev_sc != 64 && prev_sc != 65 &&
                (unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hp_env) & 1)) {
                unsigned key = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__hp_key) & (VM_MAX_VARS - 1u);
                envkey_hist[key]++;
                unsigned wip = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip) & 0xFFFF;
                if (envip_hist.size() < 200) envip_hist[wip]++;
                else { auto it = envip_hist.find(wip); if (it != envip_hist.end()) it->second++; }
            }
            prev_sc = sc;
        }
    }
    if (envw_on && gcsnap_log.size() < 1200) {
        auto* rc = top->rootp;
        static uint16_t cls_prev[4] = {0};
        static unsigned imgd_prev_st = 0;
        {
            unsigned stg = unsigned(rc->jmr_js_core__DOT__u_vm__DOT__state);
            if (stg != imgd_prev_st &&
                (stg == 34 || stg == 35 || stg == 72 || stg == 28 || stg == 36 || stg == 76 || stg == 66 ||
                 imgd_prev_st == 34 || imgd_prev_st == 35 || imgd_prev_st == 72 ||
                 imgd_prev_st == 28 || imgd_prev_st == 36 || imgd_prev_st == 76 || imgd_prev_st == 66)) {
                char b[160];
                std::snprintf(b, sizeof b, "[I %u->%u ip=%u nb=%u vi=%u sp=%u]",
                    imgd_prev_st, stg,
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__vnat_base_ff),
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__valloc_i_ff),
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__vsp_ff));
                gcsnap_log.push_back(b);
            }
            imgd_prev_st = stg;
        }
        for (int k = 0; k < 4; k++) {
            uint16_t v = uint16_t(rc->jmr_js_core__DOT__u_vm__DOT__vobj_cls[k]);
            if (v != cls_prev[k]) {
                char b[120];
                std::snprintf(b, sizeof b, "[C%d %x->%x ip=%u st=%u]",
                    k, cls_prev[k], v,
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(rc->jmr_js_core__DOT__u_vm__DOT__state));
                gcsnap_log.push_back(b);
                cls_prev[k] = v;
            }
        }
    }
    if (envw_on && gcsnap_log.size() < 1200) {
        auto* rt = top->rootp;
        static uint8_t tw_prev[8] = {0};
        for (int k = 0; k < 8; k++) {
            uint8_t v = uint8_t(rt->jmr_js_core__DOT__u_vm__DOT__vtimer_valid[k]);
            if (v != tw_prev[k]) {
                char b[120];
                std::snprintf(b, sizeof b, "[T%d %d->%d ip=%u st=%u n=%u]",
                    k, tw_prev[k], v,
                    unsigned(rt->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(rt->jmr_js_core__DOT__u_vm__DOT__state),
                    unsigned(rt->jmr_js_core__DOT__u_vm__DOT__vtimer_n));
                gcsnap_log.push_back(b);
                tw_prev[k] = v;
            }
        }
    }
    if (envw_on && gcsnap_log.size() < 1200) {
        auto* rg2 = top->rootp;
        unsigned st2 = unsigned(rg2->jmr_js_core__DOT__u_vm__DOT__state);
        static unsigned fa_prev = 999;
        if (st2 != fa_prev) {
            if (st2 == 77 || fa_prev == 77) { // S_FREE_ARR transitions
                char b[160];
                std::snprintf(b, sizeof b, "[FA %u->%u vi_ff=%u vi_e=%u ok=%u ip=%u]",
                    fa_prev, st2,
                    unsigned(rg2->jmr_js_core__DOT__u_vm__DOT__valloc_i_ff),
                    unsigned(rg2->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__valloc_i),
                    unsigned(rg2->jmr_js_core__DOT__u_vm__DOT__vfree_ok),
                    unsigned(rg2->jmr_js_core__DOT__u_vm__DOT__ip));
                gcsnap_log.push_back(b);
            }
            fa_prev = st2;
        }
    }
    if (envw_on && gcsnap_log.size() < 1200) {
        auto* rg = top->rootp;
        unsigned stt = unsigned(rg->jmr_js_core__DOT__u_vm__DOT__state);
        if (stt != gcsnap_prev_state) {
            if (stt == 43) { // S_V64_GC_CLEAR
                char b[420];
                std::snprintf(b, sizeof b,
                    "[GCSTART ip=%u vcsp=%u rafn=%u snapn=%u venv=%llx snap0=%llx "
                    "fenv=%llx,%llx,%llx,%llx ffn=%llx,%llx,%llx,%llx]",
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__vcsp),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__vraf_n),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__vraf_snap_n),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__venv_ff),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vraf_snap[0]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_env[0]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_env[1]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_env[2]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_env[3]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_fn[0]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_fn[1]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_fn[2]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vframe_fn[3]));
                gcsnap_log.push_back(b);
            }
            if (stt == 48) { // S_V64_GC_SWEEP_OBJ — mark phase done
                char b[220];
                std::snprintf(b, sizeof b,
                    "[MARKDONE e30=%u e39=%u e1=%u e465=%u f541=%u "
                    "p1=%llx p465=%llx fe541=%llx]",
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__venv_mark[30]),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__venv_mark[39]),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__venv_mark[1]),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__venv_mark[465]),
                    unsigned(rg->jmr_js_core__DOT__u_vm__DOT__vfn_mark[541]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__venv_parent[1]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__venv_parent[465]),
                    (unsigned long long)uint64_t(rg->jmr_js_core__DOT__u_vm__DOT__vfn_env[541]));
                gcsnap_log.push_back(b);
            }
            gcsnap_prev_state = stt;
        }
    }
    if (envw_on && envw_log.size() < 96) {
        auto* re = top->rootp;
        for (int sl = 0; sl < 128; sl++) {
            uint8_t v = uint8_t(re->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
            if (v != envw_prev[sl] && envw_base[sl]) {
                char b[120];
                std::snprintf(b, sizeof b, "[e%d %d->%d ip=%u st=%u gen=%u]",
                    sl, envw_prev[sl], v,
                    unsigned(re->jmr_js_core__DOT__u_vm__DOT__ip),
                    unsigned(re->jmr_js_core__DOT__u_vm__DOT__state),
                    unsigned(re->jmr_js_core__DOT__u_vm__DOT__venv_gen[sl]));
                envw_log.push_back(b);
                envw_prev[sl] = v;
            }
        }
    }
    if (beat_ip >= 0 && beat_log.size() < 900) {
        auto* rb = top->rootp;
        if (int(rb->jmr_js_core__DOT__u_vm__DOT__ip) == beat_ip || !beat_log.empty()) {
            char b[260];
            std::snprintf(b, sizeof b,
                "[ip=%u st=%u ph=%u ss=%u si=%u qi=%u tn=%u len=%u oid=%u]",
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__ip),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__state),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_phase),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_ss),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_si),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_qi),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_tn),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__vobj_len_rdata),
                unsigned(rb->jmr_js_core__DOT__u_vm__DOT__hp_oid));
            beat_log.push_back(b);
        }
    }
    if (beat_ip >= 0 && vvw_log.size() < 64) {
        auto* rw = top->rootp;
        if (unsigned(rw->jmr_js_core__DOT__u_vm__DOT__e64_vvars_we)) {
            char b[200];
            std::snprintf(b, sizeof b,
                "[WEQ ip=%u st=%u waddr=%u wdata=%016llx pvw=%u]",
                unsigned(rw->jmr_js_core__DOT__u_vm__DOT__ip),
                unsigned(rw->jmr_js_core__DOT__u_vm__DOT__state),
                unsigned(rw->jmr_js_core__DOT__u_vm__DOT__e64_vvars_waddr),
                (unsigned long long)uint64_t(rw->jmr_js_core__DOT__u_vm__DOT__e64_vvars_wdata),
                unsigned(rw->jmr_js_core__DOT__u_vm__DOT__vvars_we));
            vvw_log.push_back(b);
        }
    }
    if (vvw_slot >= 0 && vvw_log.size() < 64) {
        uint64_t v = uint64_t(
            top->rootp->jmr_js_core__DOT__u_vm__DOT__vvars[vvw_slot]);
        if (v != vvw_prev) {
            char b[200];
            std::snprintf(b, sizeof b,
                "[ip=%u st=%u est=%u esp=%u w0=%016llx w1=%016llx v=%016llx->%016llx]",
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__state),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__state),
                unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vsp),
                (unsigned long long)uint64_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__vst_win[0]),
                (unsigned long long)uint64_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__vst_win[1]),
                (unsigned long long)vvw_prev, (unsigned long long)v);
            vvw_log.push_back(b);
            vvw_prev = v;
        }
    }
    if (ip_trace.size() < ip_trace_cap) {
        uint16_t cur = uint16_t(top->rootp->jmr_js_core__DOT__u_vm__DOT__ip);
        if (cur != ip_trace_prev) {
            ip_trace.push_back(cur);
            ip_trace_prev = cur;
            ip_trace_vsp.push_back(uint16_t(
                top->rootp->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vsp));
        }
    }
    {
        auto* r = top->rootp;
        unsigned fc = unsigned(r->jmr_js_core__DOT__u_vm__DOT__fault_code);
        if (fc == 0)
            fault_snap_code = 0;
        else if (fault_snap_code == 0) {
            // Use pre-NBA hold: opcode comb saw last cycle's rdata/raddr.
            fault_snap_code = fc;
            fault_snap_raddr = fault_hold_raddr;
            fault_snap_valid = fault_hold_valid;
            fault_snap_gen = fault_hold_gen;
            fault_snap_akind = fault_hold_akind;
            fault_snap_ai = fault_hold_ai;
            fault_snap_vsp = fault_hold_vsp;
            fault_snap_vcsp = fault_hold_vcsp;
            fault_snap_hvcsp = fault_hold_hvcsp;
            fault_snap_opnd = fault_hold_opnd;
            fault_snap_w0 = fault_hold_w0;
            fault_snap_cr = fault_hold_cr;
            envsnap_venv_ff = hold_venv_ff; envsnap_venv_q = hold_venv_q;
            envsnap_m_venv = hold_m_venv;
            envsnap_eid = hold_eid; envsnap_len = hold_len;
            envsnap_key = hold_key; envsnap_phase = hold_phase;
            for (int sl = 0; sl < 16; sl++) {
                unsigned a = hold_eid * 16 + sl;
                envsnap_slots[sl] = (a < 4096)
                    ? (unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_slot_c0[a][2]) & 0xffff)
                    : (unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_slot_c1[(a - 4096) & 0x7ff][2]) & 0xffff);
            }
        }
        fault_hold_raddr = unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_vfn_raddr);
        fault_hold_valid = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid_rdata);
        fault_hold_gen = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen_rdata);
        fault_hold_akind = unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_kind);
        fault_hold_ai = unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_i);
        hold_eid = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid) & 0x1ff;
        hold_len = unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[hold_eid]);
        hold_key = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_key);
        hold_phase = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_phase);
        hold_venv_ff = unsigned(uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv_ff) & 0x3ff);
        hold_venv_q = unsigned(uint64_t(r->jmr_js_core__DOT__u_vm__DOT__e64_venv_q) & 0x3ff);
        hold_m_venv = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hs_m_venv);
        fault_hold_vsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
        fault_hold_vcsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vcsp);
        fault_hold_hvcsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__hs_m_vcsp);
        fault_hold_opnd =
            (unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd_q) << 1) |
            unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__opnd2_q);
        fault_hold_w0 = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[0]);
        fault_hold_cr = uint32_t(r->jmr_js_core__DOT__u_vm__DOT__code_rdata);
    }
}

static void ticks(int n) {
    for (int i = 0; i < n; i++) tick();
}

// strobe one key event into the RTL FIFO (see KEYEVT handler)
static void key_strobe(unsigned code, unsigned down, unsigned text = 0) {
    top->key_evt_char = text & 255;
    top->key_evt_code = code & 0xFF;
    top->key_evt_down = down ? 1 : 0;
    top->key_evt_stb = 1;
    ticks(1);
    top->key_evt_stb = 0;
    // div8: the VM samples events on its /8 beat via the core's latch; a
    // second strobe within 8 clks would overwrite it. 9 clks guarantees a
    // beat between strobes (board PS/2 cannot burst this fast anyway).
    ticks(9);
}

static void hide_desktop() {
    top->desktop_control_on=0; top->desktop_control_stb=1; ticks(1);
    top->desktop_control_stb=0;
    for (unsigned i=0;i<1000 && top->desktop_busy_o;i++) ticks(20000);
    ticks(140000); // console enable drains old keyboard input before a command
}

static int read_whole_file(const std::string& path, std::vector<uint8_t>& out) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return -1;
    f.seekg(0, std::ios::end);
    std::streamoff n = f.tellg();
    if (n < 0) return -1;
    f.seekg(0, std::ios::beg);
    out.resize((size_t)n);
    if (n && !f.read(reinterpret_cast<char*>(out.data()), n)) return -1;
    return 0;
}

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

// gui-put BOARD path in FPGA-SIM: same console SOURCE pump as uart 0xFC.
static int src_tether_pump(const std::vector<uint8_t>& blob, bool big = false, bool program = false) {
    // Big=true streams as an 0xFB CART put (jsb_tether_big)
    top->jsb_tether_src = (big || program) ? 0 : 1;
    top->jsb_tether_big = big ? 1 : 0;
    top->jsb_tether_stb = 0;
    top->jsb_tether_eof = 0;
    // (jsb_tether_crc_err is left as the TETHER_CRCERR rpc set it — the
    //  gate arms it before the stream, like uart_link would at the trailer)
    int wait = 0;
    while (!top->jsb_tether_rdy && wait < 200000) { ticks(1); wait++; }
    if (!top->jsb_tether_rdy) {
        top->jsb_tether_src = 0;
        return -1;
    }
    for (uint8_t b : blob) {
        wait = 0;
        while (!top->jsb_tether_rdy && wait < 20000) { ticks(1); wait++; }
        if (!top->jsb_tether_rdy) {
            top->jsb_tether_src = 0;
            top->jsb_tether_stb = 0;
            return -2;
        }
        top->jsb_tether_data = b;
        top->jsb_tether_stb = 1;
        tick();
        top->jsb_tether_stb = 0;
    }
    wait = 0;
    while (!top->jsb_tether_rdy && wait < 20000) { ticks(1); wait++; }
    if (!top->jsb_tether_rdy) {
        top->jsb_tether_src = 0;
        top->jsb_tether_big = 0;
        return -3;
    }
    // Drop src with eof so C_IDLE does not re-arm an empty stream.
    // Hold eof until TETHER samples it (uart_link jsh_eof_hold).
    top->jsb_tether_src = 0;
    top->jsb_tether_big = 0;
    top->jsb_tether_eof = 1;
    wait = 0;
    while (!top->jsb_tether_rdy && wait < 20000) { ticks(1); wait++; }
    if (!top->jsb_tether_rdy) {
        top->jsb_tether_eof = 0;
        return -4;
    }
    ticks(8);
    top->jsb_tether_eof = 0;
    ticks(16);
    return 0;
}

static uint64_t fnv_byte(uint64_t hash, uint8_t value) {
    return (hash ^ value) * UINT64_C(0x100000001B3);
}

static uint64_t fnv_u16(uint64_t hash, uint16_t value) {
    hash = fnv_byte(hash, (uint8_t)value);
    return fnv_byte(hash, (uint8_t)(value >> 8));
}

static uint64_t fnv_u32(uint64_t hash, uint32_t value) {
    hash = fnv_u16(hash, (uint16_t)value);
    return fnv_u16(hash, (uint16_t)(value >> 16));
}

static uint64_t fnv_u64(uint64_t hash, uint64_t value) {
    hash = fnv_u32(hash, (uint32_t)value);
    return fnv_u32(hash, (uint32_t)(value >> 32));
}

// Poke compiled .JSH into code BRAM + asset SRAM (no simulated SPI).
static int jsh_load_mem(const std::vector<uint8_t>& b) {
    if (b.size() < 12 || b[0] != 'J' || b[1] != 'S' || b[2] != 'B' || (b[3] != '1' && b[3] != '2'))
        return -1;
    uint16_t flags = (uint16_t)b[10] | ((uint16_t)b[11] << 8);
    uint32_t aset_off = 0;
    bool has_aset = (flags & 2) != 0;
    if (has_aset) {
        if (b.size() < 16) return -1;
        aset_off = (uint32_t)b[12] | ((uint32_t)b[13] << 8)
                 | ((uint32_t)b[14] << 16) | ((uint32_t)b[15] << 24);
    }
    // Match jmr_js_vm_pkg::CART_WORDS. Validate before any code/SRAM writes;
    // truncating an asset silently can corrupt system-owned cache memory.
    constexpr uint32_t CART_MAX_BYTES = 3430400u * 2u;
    if (has_aset) {
        if (aset_off < 16 || (size_t)aset_off > b.size() || b.size() - aset_off < 8)
            return -1;
        if (b[aset_off] != 'A' || b[aset_off + 1] != 'S' ||
            b[aset_off + 2] != 'E' || b[aset_off + 3] != 'T') return -1;
        uint32_t plen = (uint32_t)b[aset_off + 4]
                      | ((uint32_t)b[aset_off + 5] << 8)
                      | ((uint32_t)b[aset_off + 6] << 16)
                      | ((uint32_t)b[aset_off + 7] << 24);
        if (plen < 768u || plen > CART_MAX_BYTES || plen != b.size() - aset_off - 8)
            return -1;
    }
    size_t code_len = has_aset ? (size_t)aset_off : b.size();
    top->sim_image_code_bytes = uint32_t(code_len);
    top->sim_image_code_valid = 1;
    auto* rp = top->rootp;
    const size_t CODE_WORDS = 8192 + 29696;  // Toolbox prefix + application bank
    for (size_t w = 0; w < CODE_WORDS; w++) {
        size_t i = w * 4;
        uint32_t word = 0;
        if (i < code_len) {
            word = b[i];
            if (i + 1 < code_len) word |= (uint32_t)b[i + 1] << 8;
            if (i + 2 < code_len) word |= (uint32_t)b[i + 2] << 16;
            if (i + 3 < code_len) word |= (uint32_t)b[i + 3] << 24;
        }
        code_poke(rp, w, word);
    }
    if (has_aset && aset_off + 8 <= b.size()
        && b[aset_off] == 'A' && b[aset_off + 1] == 'S'
        && b[aset_off + 2] == 'E' && b[aset_off + 3] == 'T') {
        uint32_t plen = (uint32_t)b[aset_off + 4]
                      | ((uint32_t)b[aset_off + 5] << 8)
                      | ((uint32_t)b[aset_off + 6] << 16)
                      | ((uint32_t)b[aset_off + 7] << 24);
        size_t poff = aset_off + 8;
        for (uint32_t i = 0; i + 1 < plen; i += 2) {
            uint16_t w = (uint16_t)b[poff + i]
                       | ((uint16_t)b[poff + i + 1] << 8);
            rp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[i / 2] = w;
        }
        if (plen & 1u)
            rp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[plen / 2] =
                (uint16_t)b[poff + plen - 1];
        uint32_t pal_n = plen < 768u ? plen : 768u;
        for (uint32_t pi = 0; pi + 2 < pal_n; pi += 3) {
            uint32_t rgb = ((uint32_t)b[poff + pi] << 16)
                         | ((uint32_t)b[poff + pi + 1] << 8)
                         | (uint32_t)b[poff + pi + 2];
            rp->jmr_js_core__DOT__u_palette__DOT__mem[pi / 3] = rgb;
        }
    }
    return 0;
}

static void push_key(uint8_t b) {
    top->kbd_data = b;
    top->kbd_push = 1;
    tick();
    top->kbd_push = 0;
    tick();
}

// Direct test/GUI injection must acquire the same idle console ownership as
// LOAD/RUN. ESC after code_poke raced the disk Finder supervisor: its pending
// Home load replaced the live program underneath the VM's old header/PC.
// Use public recovery controls; never patch RTL state or suppress normal boot.
static bool prepare_direct_vm_load() {
    hide_desktop();
    push_key(0x1B);
    unsigned quiet = 0;
    // Cold ROM/resources plus a large Finder image can exceed 16M clocks.
    // Bound the drain at approximately 96M clocks; never inject on timeout.
    for (unsigned attempt = 0; attempt < 3000000; ++attempt) {
        // Keep Terminal selected while an already-started disk load drains.
        // The 32-clock cadence also cancels a delayed ESC/Home request before
        // the shell's 100-clock idle debounce can start a new Finder load.
        top->desktop_control_on = 0;
        top->desktop_control_stb = 1;
        tick();
        top->desktop_control_stb = 0;
        if (top->rootp->jmr_js_core__DOT__u_vm__DOT__running || top->game_mode)
            push_key(0x1B);
        ticks(31);
        const bool idle = top->ready_lit && top->stor_dbg_state_o == 0 &&
            !top->desktop_busy_o && !top->game_mode &&
            !top->rootp->jmr_js_core__DOT__u_vm__DOT__running;
        quiet = idle ? quiet + 1 : 0;
        if (quiet >= 8) return true;
    }
    return false;
}

static std::string screen_text() {
    std::ostringstream oss;
    for (int row = 0; row < 16; row++) {
        std::string line;
        line.reserve(64);
        for (int col = 0; col < 64; col++) {
            top->dump_addr = (row << 6) | col;
            tick();
            char ch = char(top->dump_data & 0xff);
            if (ch < 32 || ch > 126) ch = ' ';
            line.push_back(ch);
        }
        while (!line.empty() && line.back() == ' ') line.pop_back();
        oss << line;
        if (row != 15) oss << "\\n";
    }
    return oss.str();
}

// Export native 640×480 game FB (no ×4 upsample — FB is glass size)
static std::string fb_export_b64() {
    constexpr int W = 640, H = 480;
    std::vector<uint8_t> full((size_t)W * H, 0);
    // Direct front-bank read. S_IMGD_GET holds dump_sel for up to 307200
    // cycles, so walking the core's old dump_fb_raddr port sampled GET's
    // address (and 614k extra ticks ran the VM past the FRAME swap —
    // full-canvas fillRect looked black). FBBANK? already reads mem0/mem1
    // this way. That port (the board tether's pixel dump) was removed in
    // build 96; this host-side export never used it.
    auto* r = top->rootp;
    unsigned front = 1u; // single-bank canvas
    if(top->system_viewport_o && (top->system_window_o & 255u)==8u && !top->desktop_visible_o) {
        // Address mapping comes from the DUT and is the same function used
        // by the hardware line prefetcher, not a host UI reconstruction.
        const unsigned saved_y=top->fb_y;
        for(unsigned y=24;y<480;y++) {
            top->fb_y=y;top->eval();const unsigned source_y=top->game_source_y_o;
            for(unsigned x=0;x<640;x++)full[y*640+x]=fb_bank_pix(r,front,source_y*640+x);
        }
        top->fb_y=saved_y;top->eval();
    } else for (int i = 0; i < W * H; i++)
        full[(size_t)i] = fb_bank_pix(r, front, (unsigned)i);
    return b64_encode(full.data(), full.size());
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    sd_load_image();
    top = new Vjmr_js_core;
    top->rst_n = 0;
    top->standalone_mode = 1;
    top->pixel_clk = 0;
    top->kbd_push = 0;
    top->kbd_data = 0;
    top->joy_in = 0;
    top->key_evt_char = 0;
    top->mouse_stb = 0;
    top->desktop_control_stb = 0; top->desktop_control_on = 1;
    top->mouse_x = 320; top->mouse_y = 240; top->mouse_buttons = 0;
    // analog-joy: rest position (matches jmr_i2c_joy.sv power-on default).
    top->analog_x = 128;
    top->analog_y = 128;
    top->joy_btn = 0;
    top->dump_addr = 0;
    top->scan_addr = 0;
    top->fb_raddr = 0;
    top->pal_raddr = 0;
    top->sd_miso = 1;
    top->sim_vm_start = 0;
    top->sim_frame_pulse = 0;
    top->host_req_valid = 0;
    top->host_req_crc_ok = 0;
    for (unsigned i=0; i<6; ++i) top->host_req_body[i] = 0;
    top->host_q_ready = 1;
    top->jsb_tether_stb = 0;
    top->jsb_tether_data = 0;
    top->jsb_tether_eof = 0;
    top->jsb_tether_crc_err = 0;
    top->jsb_tether_big = 0;
    top->jsb_tether_src = 0;
    ticks(8);
    top->rst_n = 1;
    ticks(200000);
    std::cout << "READY" << std::endl;

    std::string line;
    // ProgramImage is streamed over the existing line RPC. It never becomes a
    // host-side .JSB/.JSH file; RUN's source of truth remains the loaded HTML.
    std::vector<uint8_t> program_image;
    size_t program_expected = 0;
    while (std::getline(std::cin, line)) {
        if (line.rfind("SERVICE ",0)==0) {
            const std::string hex=line.substr(8);
            std::vector<uint8_t> bytes;
            bool valid=(hex.size()==56);
            for(size_t i=0; valid && i<hex.size(); i+=2) {
                int a=hex_nibble(hex[i]), b=hex_nibble(hex[i+1]);
                if(a<0 || b<0) { valid=false; break; }
                bytes.push_back(uint8_t((a<<4)|b));
            }
            if(!valid || bytes[0]!=0xfa || top->host_req_valid) {
                std::cout << "ERR SERVICE_PACKET" << std::endl; continue;
            }
            for(unsigned i=0;i<6;++i) top->host_req_body[i]=0;
            for(unsigned i=0;i<23;++i)
                top->host_req_body[i/4] |= uint32_t(bytes[1+i]) << ((i%4)*8);
            uint32_t supplied=uint32_t(bytes[24]) | (uint32_t(bytes[25])<<8)
                | (uint32_t(bytes[26])<<16) | (uint32_t(bytes[27])<<24);
            top->host_req_crc_ok = finder_crc(bytes.data()+1,23)==supplied;
            top->host_req_valid=1;
            bool accepted=false;
            for(unsigned wait=0;wait<200000;++wait) {
                top->eval();
                if(top->host_req_ready) { tick(); accepted=true; break; }
                tick();
            }
            top->host_req_valid=0;
            if(!accepted) std::cout << "ERR SERVICE_ACCEPT_TIMEOUT" << std::endl;
            else finder_print_responses();
            continue;
        }
        if (line=="SERVICEPOLL") {
            // Bounded forward progress through the real service controller.
            // Stop at a response; bulk streams are driven by SERVICEBULK.
            for(unsigned i=0;i<200000 && finder_responses.empty();++i) tick();
            finder_print_responses();
            continue;
        }
        if (line.rfind("SERVICEBULK ",0)==0) {
            std::vector<uint8_t> blob;
            bool valid=line.size()>15 && line[14]==' ' && line[12]=='F'
                && (line[13]=='B' || line[13]=='C' || line[13]=='D');
            if(!valid || read_whole_file(line.substr(15),blob)!=0) {
                std::cout << "ERR SERVICE_BULK_FILE" << std::endl; continue;
            }
            top->jsb_tether_crc_err=0;
            if(src_tether_pump(blob,line[13]=='B',line[13]=='D')!=0)
                std::cout << "ERR SERVICE_BULK_STALL" << std::endl;
            else finder_print_responses();
            continue;
        }
        if (line == "QUIT") {
            std::cout << "BYE" << std::endl;
            break;
        }
        // Compile-on-RUN: host rewrote card.img .JSH; reload SPI image before FAT OPEN
        // Compile-on-RUN: host rewrote card.img; reload SPI image before FAT OPEN.
        // Do not sd_save_image first — boot/mount may have set dirty, and that
        // flush would overwrite the host patch (new 8.3 names vanished: ?FN).
        if (line == "SDRELOAD") {
            sd.dirty = false;
            sd_load_image();
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROGBEGIN ", 0) == 0) {
            program_expected = (size_t)std::strtoull(line.c_str() + 10, nullptr, 10);
            if (program_expected < 12 || program_expected > (4u * 1024u * 1024u + 256u * 1024u)) {
                program_expected = 0;
                program_image.clear();
                std::cout << "ERR size" << std::endl;
                continue;
            }
            program_image.clear();
            program_image.reserve(program_expected);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROGDATA ", 0) == 0) {
            const std::string hex = line.substr(9);
            if (!program_expected || (hex.size() & 1u)
                || program_image.size() + hex.size() / 2 > program_expected) {
                std::cout << "ERR data" << std::endl;
                continue;
            }
            bool good = true;
            for (size_t i = 0; i < hex.size(); i += 2) {
                int hi = hex_nibble(hex[i]);
                int lo = hex_nibble(hex[i + 1]);
                if (hi < 0 || lo < 0) {
                    good = false;
                    break;
                }
                program_image.push_back((uint8_t)((hi << 4) | lo));
            }
            if (!good) {
                program_image.clear();
                program_expected = 0;
                std::cout << "ERR hex" << std::endl;
                continue;
            }
            std::cout << "OK bytes=" << program_image.size() << std::endl;
            continue;
        }
        if (line == "PROGSTART") {
            if (!program_expected || program_image.size() != program_expected
                || jsh_load_mem(program_image) != 0) {
                std::cout << "ERR image" << std::endl;
                continue;
            }
            // Three Escs: a program that owns Esc gets no key event here,
            // so the third stops it.
            for (int i = 0; i < 3; ++i) { push_key(0x1B); ticks(8); }
            top->sim_vm_start = 1;
            tick();
            top->sim_vm_start = 0;
            ticks(64);
            std::cout << "OK bytes=" << program_image.size() << std::endl;
            continue;
        }
        // RAM-load compiled .JSH (code BRAM + ASET SRAM). No FAT SPI.
        // Gate hook — pretend the UART trailer CRC mismatched.
        // The flag rides with the next stream's eof exactly like uart_link's.
        // Gate: SD_HANG <0|1> — the SD model stops answering so the
        // storage watchdog (S_SD_WAIT) must fire and report ?IO.
        if (line.rfind("SD_HANG ", 0) == 0) {
            sd.hang = (line[8] == '1');
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("TETHER_CRCERR ", 0) == 0) {
            top->jsb_tether_crc_err = (line[14] == '1') ? 1 : 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("JSHLOAD ", 0) == 0) {
            std::vector<uint8_t> blob;
            if (read_whole_file(line.substr(8), blob) != 0 ||
                !prepare_direct_vm_load() || jsh_load_mem(blob) != 0) {
                std::cout << "ERR" << std::endl;
                continue;
            }
            top->sim_vm_start = 1;
            tick();
            top->sim_vm_start = 0;
            ticks(64);
            std::cout << "OK bytes=" << blob.size() << std::endl;
            continue;
        }
        // FPGA-SIM LOAD of host HTML → source BRAM (no SPI of fat files).
        // Diagnostic bulk staging: live file imports use SERVICEBULK and typed commit.
        // BIGFILE <path> — stream a whole host file as an 0xFB CART put
        if (line.rfind("BIGFILE ", 0) == 0) {
            std::vector<uint8_t> blob;
            if (read_whole_file(line.substr(8), blob) != 0) { std::cout << "ERR read" << std::endl; continue; }
            int rc = src_tether_pump(blob, true);
            std::cout << (rc == 0 ? "OK bytes=" : "ERR pump=") << (rc == 0 ? (long)blob.size() : (long)rc) << std::endl;
            continue;
        }
        if (line.rfind("SRCSTREAM ", 0) == 0) {
            const std::string hex = line.substr(10);
            if (hex.size() & 1u) {
                std::cout << "ERR hex" << std::endl;
                continue;
            }
            std::vector<uint8_t> blob;
            blob.reserve(hex.size() / 2);
            bool good = true;
            for (size_t i = 0; i < hex.size(); i += 2) {
                int hi = hex_nibble(hex[i]);
                int lo = hex_nibble(hex[i + 1]);
                if (hi < 0 || lo < 0) { good = false; break; }
                blob.push_back((uint8_t)((hi << 4) | lo));
            }
            if (!good) {
                std::cout << "ERR hex" << std::endl;
                continue;
            }
            int rc = src_tether_pump(blob);
            if (rc != 0) {
                std::cout << "ERR pump=" << rc << std::endl;
                continue;
            }
            std::cout << "OK bytes=" << blob.size() << std::endl;
            continue;
        }
        if (line.rfind("KEY ", 0) == 0) {
            unsigned v = std::stoul(line.substr(4), nullptr, 16);
            push_key(uint8_t(v));
            // A real keyboard's Esc also arrives as key event 27, which is
            // how a Toolbox program that owns Esc receives it.
            if (v == 0x1B) { key_strobe(27, 1); key_strobe(27, 0); }
            ticks(5000);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("JOY ", 0) == 0) {
            unsigned v = std::stoul(line.substr(4), nullptr, 0);
            top->joy_in = v & 0x3f;
            ticks(2);
            std::cout << "OK" << std::endl;
            continue;
        }
        // KEYBITS = play bits (Left=4 Right=8 Fire=16). Assign joy_in;
        // GUI must not follow with JOY 0 (that wiped arrows/Space).
        if (line.rfind("KEYBITS ", 0) == 0) {
            unsigned v = std::stoul(line.substr(8), nullptr, 0);
            top->joy_in = v & 0x3f;
            ticks(2);
            std::cout << "OK" << std::endl;
            continue;
        }
        // analog-joy: debug feed for the Pmod stick's raw axes/buttons
        // (board wires jmr_i2c_joy directly; FPGA-SIM/PYTHON has no I2C
        // model, so tests/GUI set it here). Digital JOY/KEYBITS above are
        // unchanged — this is extra axes a title can poll, not a mouse.
        if (line.rfind("ANALOG ", 0) == 0) {
            std::istringstream iss(line.substr(7));
            unsigned x = 128, y = 128, b = 0;
            iss >> x >> y >> b;
            top->analog_x = x & 0xff;
            top->analog_y = y & 0xff;
            top->joy_btn = b & 0x1f;
            ticks(2);
            std::cout << "OK" << std::endl;
            continue;
        }
        if(line=="SOURCE?") {
            auto* r=top->rootp;
            std::cout<<"SOURCE name=";
            for(unsigned i=0;i<r->jmr_js_core__DOT__u_cons__DOT__src_name_len && i<16;i++)std::cout<<char(r->jmr_js_core__DOT__u_cons__DOT__src_name[i]);
            std::cout<<" bytes="<<unsigned(r->jmr_js_core__DOT__u_cons__DOT__src_len)<<std::endl;continue;
        }
        if(line=="UISTATE?") {
            const unsigned s=top->system_status_o;
            std::cout<<"UISTATE dialog="<<(s&7)<<" catalog="<<((s>>3)&1)<<" action="<<((s>>4)&1)<<" error="<<((s>>5)&1)<<" menu="<<((s>>6)&15)<<std::endl;continue;
        }
        if(line=="FINDER?") {
            auto* r=top->rootp;
            std::cout<<"FINDER cached="<<unsigned(r->jmr_js_core__DOT__u_cons__DOT__finder_cache_valid)
                     <<" bytes="<<unsigned(r->jmr_js_core__DOT__u_cons__DOT__finder_cache_length)
                     <<" state_saved="<<unsigned(r->jmr_js_core__DOT__u_cons__DOT__finder_state_valid)
                     <<" hits="<<unsigned(r->jmr_js_core__DOT__u_cons__DOT__finder_cache_hits)<<std::endl;continue;
        }
        if(line=="BOOT?") {
            auto* r=top->rootp;
            std::cout << "BOOT intro=" << unsigned(r->jmr_js_core__DOT__boot_intro)
                      << " finished=" << unsigned(r->jmr_js_core__DOT__boot_finished)
                      << " glass=" << unsigned(r->jmr_js_core__DOT__boot_glass) << std::endl;
            continue;
        }
        if(line=="WINDOW?") {
            const uint32_t w=top->system_window_o;
            std::cout<<"WINDOW role="<<(w&255)<<" scroll="<<((w>>8)&255)<<" scrollx="<<((w>>16)&255)<<" flags="<<(w>>24)<<std::endl;continue;
        }
        if (line.rfind("UISURFACE",0)==0) {
            long long seen=-1;std::sscanf(line.c_str()+9,"%lld",&seen);
            const unsigned generation=top->system_generation_o;
            if(seen==generation) {
                std::cout<<"UI SAME "<<generation<<" "<<unsigned(top->system_menu_o)<<" "<<unsigned(top->system_keyboard_o)<<std::endl;continue;
            }
            const unsigned old_x=top->fb_x,old_y=top->fb_y,old_clock=top->pixel_clk;
            auto fragment=[&](unsigned x,unsigned y,unsigned w,unsigned h) {
                std::vector<uint8_t> rgba(w*h*4,0);
                auto cycle=[&](unsigned sx,unsigned sy) {
                    top->pixel_clk=0;top->fb_x=sx;top->fb_y=sy;top->eval();top->pixel_clk=1;top->eval();
                };
                auto save=[&](unsigned i) {
                    const unsigned rgb=top->system_overlay_opaque_o?top->system_overlay_rgb_o:0;
                    rgba[i*4]=rgb>>16;rgba[i*4+1]=rgb>>8;rgba[i*4+2]=rgb;
                    rgba[i*4+3]=top->system_overlay_opaque_o?255:0;
                };
                // One registered label read, then one registered font read.
                for(unsigned i=0;i<w*h;i++) {
                    cycle(x+i%w,y+i/w);
                    if(i)save(i-1);
                }
                cycle(x+w-1,y+h-1);save(w*h-1);
                return b64_encode(rgba.data(),rgba.size());
            };
            const std::string pixels=fragment(0,0,640,480);
            top->fb_x=old_x;top->fb_y=old_y;top->pixel_clk=old_clock;top->eval();
            std::cout<<"UI "<<generation<<" "<<unsigned(top->system_menu_o)<<" "<<unsigned(top->system_keyboard_o)
                     <<" 1 0 0 640 480 "<<pixels<<std::endl;continue;
        }
        if (line == "OVERLAY?") {
            const unsigned old_x=top->fb_x,old_y=top->fb_y;
            const int mx=top->pointer_x_o,my=top->pointer_y_o;
            const int hot=(top->rootp->jmr_js_core__DOT____Vcellinp__u_mouse_overlay__ibeam && (top->system_window_o&255)!=3)?7:1;
            auto fragment=[&](int x,int y,unsigned w,unsigned h) {
                std::vector<uint8_t> rgba(w*h*4,0);
                for(unsigned row=0;row<h;row++)for(unsigned col=0;col<w;col++) {
                    const int sx=x+int(col),sy=y+int(row);
                    if(sx<0 || sx>=640 || sy<0 || sy>=480)continue;
                    top->fb_x=sx;top->fb_y=sy;top->eval();
                    const unsigned i=(row*w+col)*4,rgb=top->overlay_rgb_o;
                    rgba[i]=rgb>>16;rgba[i+1]=rgb>>8;rgba[i+2]=rgb;
                    rgba[i+3]=top->overlay_opaque_o?255:0;
                }
                return b64_encode(rgba.data(),rgba.size());
            };
            const std::string exit=fragment(620,0,20,22);
            const std::string arrow=fragment(mx-hot,my-hot,16,16);
            top->fb_x=old_x;top->fb_y=old_y;top->eval();
            std::cout<<"OVERLAY "<<mx-hot<<" "<<my-hot<<" "<<exit<<" "<<arrow<<std::endl;
            continue;
        }
        if (line == "DESKTOP?") {
            std::cout << "DESKTOP active=" << unsigned(top->desktop_visible_o)
                      << " busy=" << unsigned(top->desktop_busy_o)
                      << " count=" << unsigned(top->desktop_count_o)
                      << " selected=" << unsigned(top->desktop_selected_o)
                      << " page=" << unsigned(top->desktop_page_o)
                      << " menu=" << unsigned(top->desktop_menu_o)
                      << " desktop_busy=" << unsigned(top->desktop_busy_o)
                      << " error=" << unsigned(top->rootp->jmr_js_core__DOT__disk_error)
                      << std::endl;
            continue;
        }
        if (line.rfind("DESKTOP ", 0) == 0) {
            top->desktop_control_on = line.substr(8) != "0";
            top->desktop_control_stb = 1; ticks(1);
            top->desktop_control_stb = 0; ticks(8);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "MOUSE?") {
            std::cout << "MOUSE 1" << std::endl;
            continue;
        }
        if (line.rfind("MOUSE ", 0) == 0) {
            int x, y, buttons;
            if (std::sscanf(line.c_str() + 6, "%d %d %d", &x, &y, &buttons) != 3) {
                std::cout << "ERR" << std::endl;
                continue;
            }
            if (!top->mouse_ready) {
                std::cout << "BUSY" << std::endl;
                continue;
            }
            top->mouse_x = std::max(0, std::min(639, x));
            top->mouse_y = std::max(0, std::min(479, y));
            top->mouse_buttons = buttons & 7;
            top->mouse_stb = 1; ticks(1);
            top->mouse_stb = 0; ticks(8);
            std::cout << "OK" << std::endl;
            continue;
        }
        // KEYEVT <keyCode> <down> — raw keyboard event for games
        // (GUI forwards real keys; the HTML decides bindings)
        // Sim frames take seconds of wall time, so a human tap's down+up
        // both land in ONE frame's dispatch batch — a held-flag pattern
        // (MRDO startHeld) then never observes the key as held. Defer an
        // up that arrives in the same inter-frame window as its down to
        // the start of the NEXT frame: the down dispatches at frame N's
        // event phase, frame N+1's rAF callback reads held=1, and the up
        // dispatches at frame N+1's event phase. Real hardware runs
        // frames in real time and never batches a whole tap.
        if (line.rfind("KEYEVT ", 0) == 0) {
            unsigned code = 0, down = 0, text = 0;
            std::sscanf(line.c_str() + 7, "%u %u %u", &code, &down, &text);
            code &= 0xFF;
            if (down) {
                key_last_down_frame[code] = key_frame_counter;
                key_strobe(code, 1, text);
            } else if (key_last_down_frame[code] == key_frame_counter) {
                // A frame that dispatches a key event does NOT run the
                // rAF callback (the listener returns to n_ops, ending the
                // frame). So the tap needs: frame A = down dispatch (no
                // rAF), frame B = rAF sees held=1, frame C = up dispatch.
                // Flush the deferred up two FRAMEs out, not one.
                key_pending_up[code] = key_frame_counter + 2;
            } else {
                key_strobe(code, 0);
            }
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "SCREEN?") {
            std::cout << "SCREEN " << screen_text() << std::endl;
            continue;
        }
        if (line == "STATUS?") {
            std::cout << "STATUS running=" << unsigned(top->game_mode)
                      << " vm_busy=" << unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__running)
                      << " text_app=" << unsigned(top->rootp->jmr_js_core__DOT__u_cons__DOT__cmp_interactive)
                      << " ready=" << unsigned(top->ready_lit)
                      << " joy=" << unsigned(top->joy_out) << " cstate=" << (int)top->cons_dbg_state_o << " sstate=" << (int)top->stor_dbg_state_o << std::endl;
            continue;
        }
        if (line == "RUNCLK" || line == "TICK") {
            ticks(1000);
            if (line == "TICK") std::cout << "FB SAME" << std::endl;
            else std::cout << "OK" << std::endl;
            continue;
        }
        // TICKN <n> — n×1000 clocks in one RPC (DONKEY's 2.4 MB .JSH
        // FAT+SRAM stream needs millions of clocks; per-TICK RPC is too slow)
        if (line.rfind("TICKN ", 0) == 0) {
            unsigned n = 1;
            std::sscanf(line.c_str() + 6, "%u", &n);
            if (n > 100000u) n = 100000u;
            ticks(1000u * n);
            // On-machine COMPILE mints NAME.JSH during TICKN
            // pumping (not LINE), and RUN reads the .JSH from DISK — flush
            // here too or the machine's own mint is invisible to RUN.
            // sd_save_image() is a no-op unless the machine wrote the card.
            sd_save_image();
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line.rfind("PROMPT ", 0) == 0) {
            std::cout << "OK" << std::endl;
            continue;
        }
        // Minimal VM probe for RTL bring-up (state/ip/raf/heap counters)
        // DIR-wedge probe — storage FSM (port), console FSM, handshake
        if (line == "STOR?") {
            auto* r = top->rootp;
            std::cout << "STOR st=" << unsigned(top->stor_dbg_state_o)
                      << " cons=" << unsigned(r->jmr_js_core__DOT__u_cons__DOT__state)
                      << " eof=" << unsigned(r->jmr_js_core__DOT__u_stor__DOT__eof_r)
                      << " err=" << unsigned(r->jmr_js_core__DOT__u_stor__DOT__err_r)
                      << " cat=" << unsigned(r->jmr_js_core__DOT__u_stor__DOT__cat_on)
                      << " src_len=" << unsigned(r->jmr_js_core__DOT__u_cons__DOT__src_len)
                      << " srcname=";
            for(unsigned i=0;i<r->jmr_js_core__DOT__u_cons__DOT__src_name_len && i<16;i++)
                std::cout<<char(r->jmr_js_core__DOT__u_cons__DOT__src_name[i]);
            std::cout << " cur=" << unsigned(r->jmr_js_core__DOT__u_vid__DOT__cur) << " vst=" << unsigned(r->jmr_js_core__DOT__u_vid__DOT__state) << " pc=" << unsigned(r->jmr_js_core__DOT__u_vid__DOT__put_cnt) << " nc=" << unsigned(r->jmr_js_core__DOT__u_vid__DOT__nl_cnt)
                      << std::endl;
            continue;
        }
        if (line.rfind("ENVKEYS", 0) == 0) {
            unsigned oid = std::stoul(line.substr(8));
            auto* rr = top->rootp;
            std::cout << "ENVKEYS oid=" << oid;
            for (int sl = 0; sl < 16; sl++) {
                unsigned a = oid * 16 + sl;
                unsigned k, vhi;
                if (a < 4096) { k = (rr->jmr_js_core__DOT__u_vm__DOT__venv_slot_c0[a][2]) & 0xffff;
                                vhi = rr->jmr_js_core__DOT__u_vm__DOT__venv_slot_c0[a][1]; }
                else { unsigned b = (a - 4096) & 0x7ff;
                       k = (rr->jmr_js_core__DOT__u_vm__DOT__venv_slot_c1[b][2]) & 0xffff;
                       vhi = rr->jmr_js_core__DOT__u_vm__DOT__venv_slot_c1[b][1]; }
                std::cout << " s" << sl << "=" << k << ":" << std::hex << vhi << std::dec;
            }
            std::cout << "\n" << std::flush;
            continue;
        }
        if (line.rfind("CODEPEEK", 0) == 0) {
            unsigned a = std::stoul(line.substr(9));
            auto* rr = top->rootp;
            std::cout << "CODEPEEK";
            for (unsigned i = a; i < a + 16; i++) {
                unsigned w = code_word(rr,i);
                std::cout << " " << std::hex << w << std::dec;
            }
            std::cout << " opsbase=" << unsigned(rr->jmr_js_core__DOT__u_vm__DOT__ops_base) << "\n" << std::flush;
            continue;
        }
        if (line == "VMSTAT?") {
            auto* r = top->rootp;
            unsigned stn = unsigned(r->jmr_js_core__DOT__u_vm__DOT__state);
            std::cout << "VMSTAT state=" << stn
                      << " vspmax=" << vsp_peak
                      << " gcqmax=" << gcq_peak
                      << " nbmax=" << nbwp_peak
                      << " jsonmax=" << jsonwp_peak
                      << " lsvreq=" << lsv_reqs
                      << " lsvcyc=" << lsv_cycles
                      << " lsvserv=" << lsv_serv_cycles
                      << " lsvres=" << lsv_res_cycles
                      << " cmcyc=" << cm_cycles
                      << " cmlkp=" << cm_lookups
                      << " totcyc=" << total_cycles
                      << " sname=" << vm_sname(stn)
                      << " ip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip)
                      << " nops=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_ops)
                      << " eip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__ip)
                      << " sp=" << ((unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u)
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__sp))
                      << " vcsp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp)
                      << " vret=";
            {
                unsigned nfr = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp);
                if (nfr > 16u) nfr = 16u;
                for (unsigned i = 0; i < nfr; i++) {
                    if (i) std::cout << ",";
                    std::cout << unsigned(
                        ((r->jmr_js_core__DOT__u_vm__DOT__vframe_control[i] >> 12) & 0xffffu));
                }
            }
            std::cout << " vdraw="
                      << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_x)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_y)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_w)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_h)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vdraw_color)
                      << ",0" // vdraw_i: walk moved to jmr_raster_engine (C1)
                      << " raf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n)
                      << " obj=";
            if (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) {
                unsigned nlive = 0;
                for (unsigned i = 0; i < VM_MAX_OBJ; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[i] == 1)
                        nlive++;
                std::cout << nlive;
            } else
                std::cout << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_obj);
            std::cout
                      << " arr=";
            if (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) {
                unsigned narr = 0;
                for (unsigned i = 0; i < VM_MAX_ARR; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__varr_valid[i])
                        narr++;
                std::cout << narr;
            } else
                std::cout << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_arr);
            // Live env count — ENV_DEPTH shrank to 256 and the
            // titles' env peaks were measured on splash-biased data; this
            // makes the real in-play margin visible in every VMSTAT.
            {
                unsigned nenv = 0;
                for (unsigned i = 0; i < VM_ENV_DEPTH; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__venv_valid[i])
                        nenv++;
                std::cout << " envl=" << nenv;
            }
            std::cout
                      << " spr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__n_spr)
                      << " venvnx=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_next)
                      << " venvfree=" << [&]{ unsigned f=0; for (int i=0;i<512;i++)
                            if (!r->jmr_js_core__DOT__u_vm__DOT__venv_valid[i]) f++; return f; }()
                      << " vkind=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_kind)
                      << " vretr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_retried)
                      << " vali=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__valloc_i)
                      << " fsite=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__fault_site)
                      << " tear=" << tear_count_live
                      << " hwarr=" << hiwater_arr << " hwobj=" << hiwater_obj
                      << " fenv=" << envsnap_eid
                      << " flen=" << envsnap_len
                      << " fkey=" << envsnap_key
                      << " fphase=" << envsnap_phase
                      << " fvff=" << envsnap_venv_ff
                      << " fvq=" << envsnap_venv_q
                      << " fmv=" << envsnap_m_venv
                      << " fslots=" << [&]{ std::string o; for (int i = 0; i < 16; i++) { o += std::to_string(envsnap_slots[i]); if (i < 15) o += ","; } return o; }()
                      << " hpoid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_oid)
                      << " eidff=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid_ff)
                      << " eidq=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hp_eid)
                      << " meid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hs_m_hp_eid)
                      << " lenff=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[r->jmr_js_core__DOT__u_vm__DOT__hp_eid_ff & 0x1ff])
                      << " keyff=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_key_ff)
                      << " keyq=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__hp_key)
                      << " ridx=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len_ridx)
                      << " lrd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len_rdata)
                      << " mkpend=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend)
                      << " pfn=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__dbg_pf_n)
                      << " pflip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__dbg_pf_last_ip)
                      << " btry=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__jn_btry)
                      << " bmiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__jn_bmiss)
                      << " kd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kd_fn)
                      << " lsn=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                      << " kscan=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_scan)
                      << " kcall=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_call)
                      << " kalloc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_alloc)
                      << " fsite=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__fault_site)
                      << " badst=" << vm_sname(unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_bad_state))
                      << " align=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_align)
                      << " evkey=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_evkey)
                      << " txtw=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_txtw)
                      << " txtn=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_txt_n)
                      << " txtmiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_txt_miss)
                      << " rafcall=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_raf_call)
                      << " frend=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_frame_end)
                      << " ipn=" << loop_ipn
                      << " topip=" << top_ip[0] << "x" << top_cnt[0]
                      << "," << top_ip[1] << "x" << top_cnt[1]
                      << "," << top_ip[2] << "x" << top_cnt[2]
                      << "," << top_ip[3] << "x" << top_cnt[3]
                      << "," << top_ip[4] << "x" << top_cnt[4]
                      << " hot=" << hot_lo[0] << "x" << hot_n[0]
                      << "," << hot_lo[1] << "x" << hot_n[1]
                      << "," << hot_lo[2] << "x" << hot_n[2]
                      << " loop=" << loop_ip[0] << "x" << loop_hits[0]
                      << "," << loop_ip[1] << "x" << loop_hits[1]
                      << "," << loop_ip[2] << "x" << loop_hits[2]
                      << " fontpx=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__ctx_font_px)
                      << " kcmp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_cmp)
                      << " efault=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__machine_fault)
                      << " ecode=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__fault_code)
                      << " kevq=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kev_rp)
                      << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__kev_wp)
                      << " idkd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_id_keydown)
                      << " idku=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_id_keyup)
                      << " spr0=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__spr_nid[0])
                      << " dihit=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_hit)
                      << " dimiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_di_miss)
                      // Join/path bring-up counters (PACMAN maze debug)
                      << " joinmiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_join_miss)
                      << " pathovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_path_ovf)
                      << " heapovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_heap_ovf)
                      << " toovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_to_ovf)
                      << " spovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_stack_ovf)
                      << " cspovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_call_ovf)
                      << " fault=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__fault_code)
                      << " gc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_gc_n)
                      << " jsonovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_json_ovf)
                      << " swaps=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n)
                      // Interned string bytes loaded from the trailer (str[i])
                      << " namesready=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__names_ok)
                      << " strb=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__nb_wp)
                      << " strovf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_str_ovf)
                      // Ip where the last frame callback returned (dead loop)
                      << " cbip=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_cb_ip)
                      // Timers dropped because the queued oid was no longer a Fn
                      << " tmis=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_mis)
                      << " tsch=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_sched)
                      << " tfire=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_tmr_fire)
                      << " findh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_find_hit)
                      << " spln=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_splice_n)
                      << " divs=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_div_n)
                      << " fclk=" << last_fclk
                      << " fcap=" << last_fcap
                      << " fcaps=" << fcap_n
                      << " imgd=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_i)
                      << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_n)
                      << " imgwh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_w)
                      << "x" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__imgd_h)
                      // Compact HEAP/env peek: nested STORE_VAR hung in HEAP_CMP.
                      << " hp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_cmd)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_env)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_slot)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_len)
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_phase)
                      << " venvk=" << unsigned(
                            (r->jmr_js_core__DOT__u_vm__DOT__venv >> 44) & 0xF)
                      << " venvi=" << unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv & 0x3FF)
                      << " vp=" << unsigned(
                            (r->jmr_js_core__DOT__u_vm__DOT__venv_parent[
                                unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid) & 511u] >> 44) & 0xF)
                      << "," << unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv_parent[
                                unsigned(r->jmr_js_core__DOT__u_vm__DOT__hp_eid) & 511u] & 0x3FF)
                      << " lh=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_leave_hold)
                      << std::endl;
            continue;
        }
        // Canonical safe-point checkpoint for Python/RTL differential tests.
        if (line.rfind("REALTICK ", 0) == 0) {
            realtick_period = std::stoul(line.substr(9));
            realtick_ctr = 0;
            std::cout << "OK realtick=" << realtick_period << std::endl;
            continue;
        }
        // Keep this one compact: detailed OBJPEEK/VARPEEK remain opt-in.
        if (line.rfind("VARPEEK ", 0) == 0) {
            unsigned i = std::stoul(line.substr(8)) & (VM_MAX_VARS - 1u);
            auto* r = top->rootp;
            std::cout << "VAR " << i
                      << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[i])
                      << " val=" << std::hex << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vvars[i])
                      << std::dec << std::endl;
            continue;
        }
        if (line == "CHECKPOINT?") {
            auto* r = top->rootp;
            const uint64_t FNV0 = UINT64_C(0xCBF29CE484222325);
            const bool value64 =
                (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) != 0;
            if (!value64 || !inspector_value64_image(r)) {
                std::cout << "ERR CHECKPOINT requires a Value64 image" << std::endl;
                continue;
            }
            uint64_t vars_hash = FNV0;
            if (value64) {
                const uint64_t uninitialized = UINT64_C(0x7FF9F00000000000);
                for (unsigned i = 0; i < VM_MAX_VARS; i++) {
                    uint64_t word =
                        r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[i]
                        ? (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vvars[i]
                        : uninitialized;
                    vars_hash = fnv_u64(vars_hash, word);
                }
            }
            uint64_t heap_hash = FNV0;
            if (value64) {
                heap_hash = fnv_byte(heap_hash, 'H');
                heap_hash = fnv_byte(heap_hash, '6');
                heap_hash = fnv_byte(heap_hash, '4');
                heap_hash = fnv_byte(heap_hash, 1);
                bool marked_strings[1024] = {};
                auto mark_string = [&](uint64_t word) {
                    if ((word >> 48) == UINT64_C(0x7ff9)
                        && ((word >> 44) & 0xfu) == 4u
                        && (uint32_t)word < 1024u)
                        marked_strings[(uint32_t)word] = true;
                };
                for (unsigned i = 0; i < VM_MAX_VARS; i++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[i])
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vvars[i]);
                unsigned checkpoint_sp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
                for (unsigned i = 0; i < checkpoint_sp; i++)
                    mark_string(peek_vstack(r, i, checkpoint_sp));
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    unsigned kind = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[index]
                    );
                    if (kind == 1u) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_len[index]
                        );
                        if (length > VM_OBJ_SLOTS) length = VM_OBJ_SLOTS;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_vobj_val(r, index, slot));
                    }
                    if (r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[index]) {
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vfn_env[index]);
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vfn_bound_this[index]);
                    }
                }
                for (unsigned index = 0; index < VM_MAX_ARR; index++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__varr_valid[index]) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__varr_len[index]
                        );
                        if (length > VM_ARR_CAP) length = VM_ARR_CAP;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_varr_val(r, index, slot));
                    }
                for (unsigned index = 0; index < VM_ENV_DEPTH; index++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__venv_valid[index]) {
                        mark_string((uint64_t)
                            r->jmr_js_core__DOT__u_vm__DOT__venv_parent[index]);
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__venv_len[index]
                        );
                        if (length > VM_ENV_SLOTS) length = VM_ENV_SLOTS;
                        for (unsigned slot = 0; slot < length; slot++)
                            mark_string(peek_venv_val(r, index, slot));
                    }
                for (unsigned index = 0; index < 1024u; index++)
                    if (marked_strings[index]) {
                        unsigned length = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__name_len_tbl[index]
                        );
                        unsigned offset = unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__name_off[index]
                        );
                        heap_hash = fnv_byte(heap_hash, 'S');
                        heap_hash = fnv_u32(heap_hash, index);
                        heap_hash = fnv_u32(heap_hash, length);
                        for (unsigned byte = 0; byte < length; byte++)
                            heap_hash = fnv_byte(
                                heap_hash,
                                (uint8_t)r->jmr_js_core__DOT__u_vm__DOT__name_mem[
                                    offset + byte
                                ]
                            );
                    }
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    if (unsigned(
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[index]
                        ) != 1u)
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vobj_len[index]
                    );
                    if (length > VM_OBJ_SLOTS) length = VM_OBJ_SLOTS;
                    heap_hash = fnv_byte(heap_hash, 'O');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vobj_gen[index]
                    );
                    heap_hash = fnv_u32(heap_hash, length);
                    {
                        // PYTHON checkpoint packs class name index or -1.
                        uint16_t cls = (uint16_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_cls[index];
                        heap_hash = fnv_u32(
                        heap_hash,
                        cls == 0xFFFFu ? UINT32_C(0xFFFFFFFF)
                                       : (uint32_t)cls
                    );
                    }
                    {
                        uint8_t builtin = (uint8_t)
                            r->jmr_js_core__DOT__u_vm__DOT__vobj_builtin[index];
                        heap_hash = fnv_u32(
                            heap_hash,
                            builtin == 0u ? UINT32_C(0xFFFFFFFF)
                                          : (uint32_t)builtin
                        );
                    }
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    std::vector<std::pair<uint32_t, uint64_t>> fields;
                    fields.reserve(length);
                    for (unsigned slot = 0; slot < length; slot++) {
                        fields.emplace_back(
                            (uint32_t)peek_vobj_key(r, index, slot),
                            peek_vobj_val(r, index, slot)
                        );
                    }
                    std::sort(fields.begin(), fields.end());
                    for (const auto& field : fields) {
                        heap_hash = fnv_u32(heap_hash, field.first);
                        heap_hash = fnv_u64(heap_hash, field.second);
                    }
                }
                for (unsigned index = 0; index < VM_MAX_OBJ; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[index])
                        continue;
                    heap_hash = fnv_byte(heap_hash, 'F');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[index]
                    );
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_nparam[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_env[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_bound_this[index]
                    );
                    unsigned flags = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__vfn_flags[index]
                    );
                    heap_hash = fnv_byte(heap_hash, flags & 1u);
                    heap_hash = fnv_byte(heap_hash, (flags >> 1) & 1u);
                    heap_hash = fnv_byte(heap_hash, (flags >> 2) & 1u);
                    heap_hash = fnv_u32(
                        heap_hash,
                        (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[index]
                    );
                }
                for (unsigned index = 0; index < VM_MAX_ARR; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__varr_valid[index])
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__varr_len[index]
                    );
                    if (length > VM_ARR_CAP) length = VM_ARR_CAP;
                    heap_hash = fnv_byte(heap_hash, 'A');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__varr_gen[index]
                    );
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    for (unsigned element = 0; element < length; element++) {
                        heap_hash = fnv_u64(
                            heap_hash,
                            peek_varr_val(r, index, element)
                        );
                    }
                }
                for (unsigned index = 0; index < VM_ENV_DEPTH; index++) {
                    if (!r->jmr_js_core__DOT__u_vm__DOT__venv_valid[index])
                        continue;
                    unsigned length = unsigned(
                        r->jmr_js_core__DOT__u_vm__DOT__venv_len[index]
                    );
                    if (length > VM_ENV_SLOTS) length = VM_ENV_SLOTS;
                    heap_hash = fnv_byte(heap_hash, 'E');
                    heap_hash = fnv_u32(heap_hash, index);
                    heap_hash = fnv_u16(
                        heap_hash,
                        (uint16_t)r->jmr_js_core__DOT__u_vm__DOT__venv_gen[index]
                    );
                    heap_hash = fnv_u64(
                        heap_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__venv_parent[index]
                    );
                    heap_hash = fnv_u16(heap_hash, (uint16_t)length);
                    std::vector<std::pair<uint16_t, uint64_t>> slots;
                    slots.reserve(length);
                    for (unsigned slot = 0; slot < length; slot++) {
                        slots.emplace_back(
                            peek_venv_key(r, index, slot),
                            peek_venv_val(r, index, slot)
                        );
                    }
                    std::sort(slots.begin(), slots.end());
                    for (const auto& slot : slots) {
                        heap_hash = fnv_u16(heap_hash, slot.first);
                        heap_hash = fnv_u64(heap_hash, slot.second);
                    }
                }
            }
            uint64_t canvas_hash = FNV0;
            unsigned front = 1u; // single-bank canvas
            for (unsigned i = 0; i < 307200u; i++) {
                uint8_t px = fb_bank_pix(r, front, i);
                canvas_hash = fnv_byte(canvas_hash, px);
            }
            uint64_t frames_hash = FNV0;
            uint64_t queues_hash = FNV0;
            if (value64) {
                frames_hash = fnv_byte(frames_hash, 'F');
                frames_hash = fnv_byte(frames_hash, '6');
                frames_hash = fnv_byte(frames_hash, '4');
                frames_hash = fnv_byte(frames_hash, 1);
                frames_hash = fnv_u64(
                    frames_hash,
                    (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vthis
                );
                frames_hash = fnv_u64(
                    frames_hash,
                    (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__venv
                );
                unsigned value_sp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
                unsigned value_csp =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp);
                frames_hash = fnv_u16(frames_hash, (uint16_t)value_sp);
                for (unsigned slot = 0; slot < value_sp; slot++) {
                    frames_hash = fnv_u64(
                        frames_hash,
                        peek_vstack(r, slot, value_sp)
                    );
                }
                frames_hash = fnv_u16(frames_hash, (uint16_t)value_csp);
                for (unsigned frame = 0; frame < value_csp; frame++) {
                    frames_hash = fnv_u32(
                        frames_hash,
                        (uint32_t)((r->jmr_js_core__DOT__u_vm__DOT__vframe_control[frame] >> 12) & 0xffffu)
                    );
                    frames_hash = fnv_u16(
                        frames_hash,
                        (uint16_t)(r->jmr_js_core__DOT__u_vm__DOT__vframe_control[frame] & 0xfffu)
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_this[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_env[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_fn[frame]
                    );
                    frames_hash = fnv_u64(
                        frames_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_ctor[frame]
                    );
                }
                queues_hash = fnv_byte(queues_hash, 'Q');
                queues_hash = fnv_byte(queues_hash, '6');
                queues_hash = fnv_byte(queues_hash, '4');
                queues_hash = fnv_byte(queues_hash, 1);
                queues_hash = fnv_u32(
                    queues_hash,
                    (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vframe_no
                );
                queues_hash = fnv_u32(
                    queues_hash,
                    (uint32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_seq
                );
                queues_hash = fnv_byte(queues_hash, 0); // startLoop
                unsigned value_raf =
                    unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n);
                queues_hash = fnv_u16(queues_hash, (uint16_t)value_raf);
                for (unsigned slot = 0; slot < value_raf; slot++)
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vraf[slot]
                    );
                struct TimerCheckpoint {
                    int32_t due;
                    int32_t sequence;
                    int64_t period;
                    uint64_t function;
                };
                std::vector<TimerCheckpoint> timers;
                for (unsigned slot = 0; slot < 64u; slot++)
                    if (r->jmr_js_core__DOT__u_vm__DOT__vtimer_valid[slot])
                        timers.push_back({
                            (int32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_due[slot],
                            (int32_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_id[slot],
                            (int64_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_period[slot],
                            (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vtimer_fn[slot],
                        });
                std::sort(
                    timers.begin(), timers.end(),
                    [](const TimerCheckpoint& a, const TimerCheckpoint& b) {
                        return a.sequence < b.sequence;
                    }
                );
                queues_hash = fnv_u16(
                    queues_hash, (uint16_t)timers.size()
                );
                for (const auto& timer : timers) {
                    queues_hash = fnv_u32(
                        queues_hash, (uint32_t)timer.due
                    );
                    queues_hash = fnv_u32(
                        queues_hash, (uint32_t)timer.sequence
                    );
                    queues_hash = fnv_u64(
                        queues_hash, (uint64_t)timer.period
                    );
                    queues_hash = fnv_u64(
                        queues_hash, timer.function
                    );
                }
                unsigned nlisten = unsigned(
                    r->jmr_js_core__DOT__u_vm__DOT__vlistener_n
                );
                if (nlisten > 16u) nlisten = 16u;
                queues_hash = fnv_u16(queues_hash, (uint16_t)nlisten);
                for (unsigned slot = 0; slot < nlisten; slot++) {
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vlistener_ev[slot]
                    );
                    queues_hash = fnv_u64(
                        queues_hash,
                        (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vlistener_fn[slot]
                    );
                }
            }
            unsigned ip = unsigned(r->jmr_js_core__DOT__u_vm__DOT__ip);
            unsigned ops_base = unsigned(
                r->jmr_js_core__DOT__u_vm__DOT__ops_base
            );
            unsigned op = (ops_base + ip < 20480u)
                ? (code_word(r, ops_base + ip) & 0xFFu)
                : 0u;
            unsigned error = unsigned(
                r->jmr_js_core__DOT__u_vm__DOT__fault_code
            );
            std::cout << "CHECKPOINT"
                      << " ip=" << ip
                      << " op=" << op
                      << " sp=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__sp))
                      << " csp=" << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vcsp)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__csp))
                      << " vars=" << std::hex << vars_hash
                      << " heap=" << heap_hash
                      << " canvas=" << canvas_hash << std::dec;
            if (value64) {
                std::cout << " ops_base=" << ops_base
                          << " frames=" << std::hex << frames_hash
                          << " queues=" << queues_hash << std::dec;
            }
            std::cout << " raf=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vraf_n)
                      << " timers=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vtimer_n)
                      << " listeners="
                      << (value64
                          ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                          : unsigned(r->jmr_js_core__DOT__u_vm__DOT__kd_n
                                     + r->jmr_js_core__DOT__u_vm__DOT__ku_n))
                      << " error=" << error
                      << std::endl;
            continue;
        }
        // Opt-in TOS window (CPU truth). ARRAY_SET index is win[1].
        if (line == "STK?") {
            auto* r = top->rootp;
            unsigned vsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
            std::cout << "STK vsp=" << vsp << std::hex;
            for (unsigned i = 0; i < 8u; i++)
                std::cout << " w" << i << "="
                          << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[i]);
            // ctor0: NEW_OBJ frame[0].constructor_value (RET_VAL instance).
            std::cout << " ctor0="
                      << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vframe_ctor[0]);
            // rAF fault 4: is TOS Fn slot actually valid?
            std::cout << std::dec
                      << " vf0=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[0])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[0])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[0])
                      << " vf1=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[1])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_gen[1])
                      << "," << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[1]);
            std::cout << " fs=" << fault_snap_code
                      << ",ra=" << fault_snap_raddr
                      << ",rd=" << fault_snap_valid
                      << ",rg=" << fault_snap_gen
                      << ",ak=" << fault_snap_akind
                      << ",ai=" << fault_snap_ai
                      << ",sp=" << fault_snap_vsp
                      << ",ev=" << fault_snap_vcsp
                      << ",hv=" << fault_snap_hvcsp
                      << ",op=" << fault_snap_opnd
                      << std::hex
                      << ",w0=" << fault_snap_w0
                      << ",cr=" << fault_snap_cr
                      << std::dec;
            std::cout << std::endl;
            continue;
        }
        // OBJPEEK <oid> — dump one heap object (cls, n, key/val/tag slots)
        if (line.rfind("OBJPEEK ", 0) == 0) {
            auto* r = top->rootp;
            // VM_MAX_OBJ is not necessarily a power of two: masking aliases IDs.
            const auto requested_oid = std::stoul(line.substr(8));
            if (requested_oid >= VM_MAX_OBJ) {
                std::cout << "ERR OBJPEEK object id out of range" << std::endl;
                continue;
            }
            const unsigned oid = static_cast<unsigned>(requested_oid);
            const bool value64 =
                (unsigned(r->jmr_js_core__DOT__u_vm__DOT__jsb_flags) & 8u) != 0;
            if (!value64 || !inspector_value64_image(r)) {
                std::cout << "ERR OBJPEEK requires a Value64 image" << std::endl;
                continue;
            }
            unsigned ns = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vobj_len[oid]);
            std::cout << "OBJ " << oid
                      << " cls=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vobj_cls[oid])
                      << " n=" << ns
                      << " alloc=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vobj_alloc[oid])
                      << " format=Value64";
            // Dump every live slot (was 6) — item objects carry ~20 props
            if (ns > VM_OBJ_SLOTS) ns = VM_OBJ_SLOTS;
            for (unsigned s = 0; s < ns; s++) {
                std::cout << " [" << s << "]k="
                          << unsigned(peek_vobj_key(r, oid, s))
                          << " v=" << std::hex
                          << peek_vobj_val(r, oid, s)
                          << std::dec;
            }
            std::cout << std::endl;
            continue;
        }
        // ENVSTAT inspected the retired tagged-format environment free list.
        if (line == "ENVSTAT?") {
            std::cout << "ERR ENVSTAT retired tagged environment free list; use VENVPEEK? for Value64 state"
                      << std::endl;
            continue;
        }
        // RAFPEEK inspected the retired tagged-format callback queue.
        if (line == "RAFPEEK?") {
            std::cout << "ERR RAFPEEK retired tagged callback queue; use RAFTRACE/RAFTRACE? for Value64 tracing"
                      << std::endl;
            continue;
        }
        // ARRPEEK <aid> — dump array len + elements (bring-up only)
        if (line.rfind("ARRPEEK ", 0) == 0) {
            auto* r = top->rootp;
            const auto requested_aid = std::stoul(line.substr(8));
            if (requested_aid >= VM_MAX_ARR) {
                std::cout << "ERR ARRPEEK array id out of range" << std::endl;
                continue;
            }
            if (!inspector_value64_image(r)) {
                std::cout << "ERR ARRPEEK requires a Value64 image" << std::endl;
                continue;
            }
            const unsigned aid = static_cast<unsigned>(requested_aid);
            const bool valid = r->jmr_js_core__DOT__u_vm__DOT__varr_valid[aid];
            const unsigned len = valid
                ? unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_len[aid]) : 0u;
            std::cout << "ARR " << aid << " format=Value64 valid=" << valid
                      << " len=" << len;
            const unsigned cap = r->jmr_js_core__DOT__u_vm__DOT__varr_long[aid]
                ? VM_ARR_CAP : VM_ARR_SHORT_CAP;
            for (unsigned slot = 0; slot < len && slot < cap; slot++)
                std::cout << " [" << slot << "]v=" << std::hex
                          << peek_varr_val(r, aid, slot) << std::dec;
            std::cout << std::endl;
            continue;
        }
        // VRING2? — last 8 ring entries with the captured win[0..2]
        if (line == "VRING2?") {
            std::ostringstream oss;
            oss << "VRING2" << std::hex;
            unsigned long n = vring_i < 96 ? vring_i : 96;
            for (unsigned long k = vring_i - n; k < vring_i; k++) {
                const VRingEnt& e = vring[k & 255];
                oss << " [" << vm_sname(e.st) << ":" << std::dec << e.ip
                    << " sp=" << e.vsp << " esp=" << e.ecsp << std::hex
                    << " w0=" << e.w0 << " w1=" << e.w1 << " w2=" << e.w2 << "]";
            }
            std::cout << oss.str() << std::dec << std::endl;
            continue;
        }
        // STKPEEK — vsp, TOS window[0..3] and vstack[0..3] side by side
        if (line == "STKPEEK?") {
            auto* r = top->rootp;
            unsigned vsp = unsigned(r->jmr_js_core__DOT__u_vm__DOT__vsp);
            std::ostringstream oss;
            oss << "STK vsp=" << vsp << std::hex;
            for (int i = 0; i < 4; i++)
                oss << " win[" << i << "]=0x"
                    << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vst_win[i]);
            for (int i = 0; i < 4; i++)
                oss << " mem[" << i << "]=0x"
                    << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vstack[i]);
            std::cout << oss.str() << std::dec << std::endl;
            continue;
        }
        // VVARPEEK <slot> — one Value64 global (vvars) + valid bit
        if (line.rfind("VVARPEEK ", 0) == 0) {
            unsigned slot = std::stoul(line.substr(9)) & (VM_MAX_VARS - 1u);
            auto* r = top->rootp;
            std::cout << "VVAR " << slot
                      << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[slot])
                      << " v=0x" << std::hex
                      << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vvars[slot])
                      << std::dec << std::endl;
            continue;
        }
        // IDS? — method-intern id registers (join debugging)
        if (line == "IDS?") {
            auto* r = top->rootp;
            std::cout << "IDS join=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_join)
                      << " indexof=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_indexof)
                      << " push=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_push)
                      << " fill=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_fill)
                      << " names_n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__names_n)
                      << " filter=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_filter)
                      << " map=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_map)
                      << " find=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_find)
                      << " foreach=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_foreach)
                      << " replace=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_replace)
                      << " drawimage=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__id_drawimage)
                      << " ctxsx=" << int(r->jmr_js_core__DOT__u_vm__DOT__e64_ctx_sx_q)
                      << " e64dihit=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_dbg_di_hit_q)
                      << " e64dimiss=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__e64_dbg_di_miss_q)
                      << std::endl;
            continue;
        }
        // VARRPEEK <aid> — Value64 array tables + first 8 raw slots
        if (line.rfind("VARRPEEK ", 0) == 0) {
            auto* r = top->rootp;
            unsigned aid = std::stoul(line.substr(9));
            if (aid >= VM_MAX_ARR) aid = 0;
            std::ostringstream oss;
            oss << "VARR " << aid
                << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_valid[aid])
                << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_len[aid])
                << " gen=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_gen[aid])
                << " long=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_long[aid])
                << " lidx=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__varr_lidx[aid])
                << std::hex;
            for (unsigned e = 0; e < 8; e++)
                oss << " [" << e << "]=0x" << peek_varr_val(r, aid, e);
            std::cout << oss.str() << std::dec << std::endl;
            continue;
        }
        // IPTRACE <n> arms; IPTRACE? dumps the executed-ip path
        if (line.rfind("IPTRACE ", 0) == 0) {
            ip_trace.clear();
            ip_trace_vsp.clear();
            ip_trace_cap = std::stoul(line.substr(8));
            ip_trace_prev = 0xffff;
            ip_trace_user = true;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "IPTRACE?") {
            std::ostringstream oss;
            oss << "IPS";
            for (size_t i = 0; i < ip_trace.size(); i++) {
                oss << " " << ip_trace[i];
                if (i < ip_trace_vsp.size()) oss << ":" << ip_trace_vsp[i];
            }
            ip_trace_cap = 0;
            ip_trace_user = false;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // FNPEEK <id> — one vfn record
        if (line.rfind("FNPEEK ", 0) == 0) {
            unsigned fi = std::stoul(line.substr(7)) & 0x1fff;
            auto* r = top->rootp;
            std::cout << "FN " << fi
                << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[fi])
                << " entry=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[fi])
                << " flags=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_flags[fi])
                << " env=" << std::hex << (unsigned long long)uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vfn_env[fi])
                << " bthis=" << (unsigned long long)uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vfn_bound_this[fi]) << std::dec
                << std::endl;
            continue;
        }
        // FBBOX <idx> — bounding box + count of one palette index (front)
        if (line.rfind("FBBOX ", 0) == 0) {
            auto* r = top->rootp;
            unsigned want = std::stoul(line.substr(6)) & 0xff;
            unsigned front = 1u; // single-bank canvas
            int minx = 9999, miny = 9999, maxx = -1, maxy = -1; long cnt = 0;
            for (int y = 0; y < 480; y++)
                for (int x = 0; x < 640; x++) {
                    int i = y * 640 + x;
                    uint8_t px = fb_bank_pix(r, front, (unsigned)i);
                    if (px == want) {
                        cnt++;
                        if (x < minx) minx = x;
                        if (x > maxx) maxx = x;
                        if (y < miny) miny = y;
                        if (y > maxy) maxy = y;
                    }
                }
            std::cout << "BOX idx=" << want << " n=" << cnt
                      << " x=" << minx << ".." << maxx
                      << " y=" << miny << ".." << maxy << std::endl;
            continue;
        }
        // FBHIST? — front-buffer palette-index histogram (nonzero bins)
        if (line == "FBHIST?") {
            auto* r = top->rootp;
            unsigned front = 1u; // single-bank canvas
            static uint32_t bins[256];
            for (int i = 0; i < 256; i++) bins[i] = 0;
            for (int i = 0; i < 640*480; i++) {
                uint8_t px = fb_bank_pix(r, front, (unsigned)i);
                bins[px]++;
            }
            std::ostringstream oss;
            oss << "HIST";
            for (int i = 1; i < 256; i++)
                if (bins[i]) oss << " " << i << ":" << bins[i]
                    << "#" << std::hex
                    << (unsigned long)top->rootp->jmr_js_core__DOT__u_palette__DOT__mem[i]
                    << std::dec;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // STATEHIST? — cumulative clocks per parent state (then reset)
        // NAMEPEEK <id>: intern table entry — hash, len, first bytes
        if (line.rfind("NAMEPEEK ", 0) == 0) {
            auto* r = top->rootp;
            unsigned id = std::stoul(line.substr(9));
            std::ostringstream oss;
            oss << "NAME " << id
                << " n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__names_n)
                << " hash=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__name_hash_tbl[id & 1023])
                << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__name_len_tbl[id & 1023])
                << " off=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__name_off[id & 1023])
                << " txt=";
            unsigned off = unsigned(r->jmr_js_core__DOT__u_vm__DOT__name_off[id & 1023]);
            unsigned len = unsigned(r->jmr_js_core__DOT__u_vm__DOT__name_len_tbl[id & 1023]);
            for (unsigned k = 0; k < len && k < 24; k++) {
                char ch = (char)r->jmr_js_core__DOT__u_vm__DOT__name_mem[(off + k) & 32767];
                oss << (ch >= 32 && ch < 127 ? ch : '?');
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "RAFTRACE") {
            raf_trace_on = true;
            raf_log.clear();
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "RAFTRACE?") {
            std::ostringstream oss;
            oss << "RT";
            for (auto& e : raf_log) oss << " " << e;
            raf_trace_on = false;
            raf_log.clear();
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "STATEHIST?") {
            std::ostringstream oss;
            oss << "SH";
            for (int i = 0; i < 128; i++)
                if (state_cycles[i]) oss << " " << i << ":" << (unsigned long long)state_cycles[i];
            oss << " | EXEC";
            for (int i = 0; i < 128; i++)
                if (exec_state_cycles[i]) oss << " " << i << ":" << (unsigned long long)exec_state_cycles[i];
            oss << " | HP";
            for (int i = 0; i < 32; i++)
                if (heap_split[i]) oss << " " << i << ":" << (unsigned long long)heap_split[i];
            for (int i = 0; i < 32; i++) heap_split[i] = 0;
            oss << " | EK";
            for (unsigned i = 0; i < VM_MAX_VARS; i++)
                if (envkey_hist[i]) oss << " " << i << ":" << (unsigned long long)envkey_hist[i];
            for (unsigned i = 0; i < VM_MAX_VARS; i++) envkey_hist[i] = 0;
            oss << " | EIP";
            for (auto& kv : envip_hist) oss << " " << kv.first << ":" << (unsigned long long)kv.second;
            envip_hist.clear();
            for (int i = 0; i < 128; i++) { state_cycles[i] = 0; exec_state_cycles[i] = 0; }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // JSONMEM <off> <n> — dump json_mem bytes as chars
        if (line.rfind("JSONMEM ", 0) == 0) {
            unsigned off = 0, n = 64;
            std::sscanf(line.c_str() + 8, "%u %u", &off, &n);
            if (n > 128) n = 128;
            std::ostringstream oss;
            oss << "JM \"";
            for (unsigned i = 0; i < n; i++) {
                uint8_t c = (uint8_t)top->rootp->jmr_js_core__DOT__u_vm__DOT__json_mem[(off + i) & 0x1fff];
                oss << (char)((c >= 32 && c < 127) ? c : '.');
            }
            oss << "\"";
            std::cout << oss.str() << std::endl;
            continue;
        }
        // TMR? — vtimer table slots 0..7
        if (line == "TMR?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "TMR n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vtimer_n);
            for (int k = 0; k < 8; k++) {
                oss << " [" << k << "]v=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vtimer_valid[k])
                    << " due=" << (long long)int64_t(r->jmr_js_core__DOT__u_vm__DOT__vtimer_due[k])
                    << " fn=" << std::hex << (unsigned long long)uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vtimer_fn[k]) << std::dec;
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VFE? — forEach nest pointers + stack (parent + exec)
        if (line == "VFE?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "VFE p=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfe_sp)
                << " e=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_sp);
            for (int k = 0; k < 8; k++) {
                oss << " [" << k << "]arr=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_arr_s[k])
                    << " i=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_i_s[k])
                    << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_len_s[k])
                    << " fn=" << std::hex << (unsigned long long)uint64_t(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_fn_s[k]) << std::dec
                    << " ent=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vfn_entry[
                        uint64_t(r->jmr_js_core__DOT__u_vm__DOT__u_exec64__DOT__vfe_fn_s[k]) & 0x1fff]);
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // ESLOTS <eid> — dump one env's bindings (name-id:value pairs)
        if (line.rfind("ESLOTS ", 0) == 0) {
            unsigned eid = std::stoul(line.substr(7)) & 0x1ff;
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "ESL e" << eid
                << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[eid])
                << " gen=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_gen[eid])
                << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[eid]);
            unsigned n = unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[eid]);
            if (n > 16) n = 16;
            for (unsigned k = 0; k < n; k++) {
                // venv_slot word: [79:64] name-id, [63:0] value
                unsigned long long w_hi = 0; unsigned long long w_lo = 0;
                {
                    const auto& word = venv_word(r, eid*16 + k);
                    w_lo = (unsigned long long)word.at(0) | ((unsigned long long)word.at(1) << 32);
                    w_hi = (unsigned long long)word.at(2);
                }
                oss << " [" << k << "]n" << (w_hi & 0xffff) << "=0x" << std::hex << w_lo << std::dec;
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // ENVDUMP — env slots 0..79: valid/gen/parent; fns referencing them
        if (line == "ENVDUMP") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "ENVD";
            static const int slv[] = {0,1,13,30,39,50,465,466,467,468,469,470,471,472};
            for (int si = 0; si < 14; si++) {
                int sl = slv[si];
                if (!r->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]) continue;
                uint64_t par = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv_parent[sl]);
                oss << " e" << sl << ":g" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_gen[sl]);
                if ((par >> 48) == 0x7ff9 && ((par >> 44) & 0xf) == 9)
                    oss << ">e" << unsigned(par & 0x3ff) << ":g" << unsigned((par >> 32) & 0xfff);
                else if (par != 0x7ff9100000000000ULL && par != 0)
                    oss << ">?" << std::hex << par << std::dec;
            }
            oss << " |FN";
            for (int fi = 0; fi < 256; fi++) {
                if (!r->jmr_js_core__DOT__u_vm__DOT__vfn_valid[fi]) continue;
                uint64_t fe = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vfn_env[fi]);
                if ((fe >> 48) == 0x7ff9 && ((fe >> 44) & 0xf) == 9 && (fe & 0x3ff) < 80)
                    oss << " f" << fi << ">e" << unsigned(fe & 0x3ff) << ":g" << unsigned((fe >> 32) & 0xfff);
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // ENVWATCH arm / ENVWATCH? dump venv_valid transition log
        if (line == "ENVWATCH") {
            envw_on = true;
            envw_log.clear();
            for (int sl = 0; sl < 128; sl++) {
                envw_prev[sl] = uint8_t(
                    top->rootp->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
                envw_base[sl] = envw_prev[sl];
            }
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "FWATCH") {
            fw_on = true; fw_log.clear();
            auto* rf = top->rootp;
            fw_vcsp_prev = uint8_t(rf->jmr_js_core__DOT__u_vm__DOT__vcsp);
            for (int k = 0; k < 12; k++)
                fw_rip_prev[k] = uint16_t(((rf->jmr_js_core__DOT__u_vm__DOT__vframe_control[k] >> 12) & 0xffffu));
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "FWATCH?") {
            std::ostringstream oss;
            oss << "FW n=" << fw_log.size();
            for (auto& e : fw_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "GCSNAP?") {
            std::ostringstream oss;
            oss << "GCS";
            for (auto& e : gcsnap_log) oss << " " << e;
            gcsnap_log.clear();
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "ENVWATCH?") {
            std::ostringstream oss;
            oss << "ENVW n=" << envw_log.size();
            for (auto& e : envw_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // BEATLOG <ip|-1> arm; BEATLOG? dump per-beat signal log
        if (line.rfind("BEATLOG ", 0) == 0 && line[8] != '?') {
            beat_ip = std::stoi(line.substr(8));
            beat_log.clear();
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "BEATLOG?") {
            std::ostringstream oss;
            oss << "BEAT";
            for (auto& e : beat_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VVWATCH <slot|-1> arm; VVWATCH? dump change log
        if (line.rfind("VVWATCH ", 0) == 0 && line[8] != '?') {
            vvw_slot = std::stoi(line.substr(8));
            vvw_log.clear();
            if (vvw_slot >= 0)
                vvw_prev = uint64_t(
                    top->rootp->jmr_js_core__DOT__u_vm__DOT__vvars[vvw_slot]);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "VVWATCH?") {
            std::ostringstream oss;
            oss << "VVW";
            for (auto& e : vvw_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VSTWATCH <slot|-1> arm; VSTWATCH? dump change log
        if (line.rfind("VSTWATCH ", 0) == 0 && line[9] != '?') {
            vst_watch_slot = std::stoi(line.substr(9));
            vst_watch_log.clear();
            if (vst_watch_slot >= 0)
                vst_watch_prev = uint64_t(
                    top->rootp->jmr_js_core__DOT__u_vm__DOT__vstack[vst_watch_slot]);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "VSTWATCH?") {
            std::ostringstream oss;
            oss << "VSTW";
            for (auto& e : vst_watch_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VARWATCH <slot|-1>: actual Value64 valid/raw-word changes.
        if (line.rfind("VARWATCH ", 0) == 0) {
            const int requested = std::stoi(line.substr(9));
            if (requested < -1 || requested >= int(VM_MAX_VARS)) {
                std::cout << "ERR VARWATCH slot out of range" << std::endl;
                continue;
            }
            watch_slot = requested;
            if (watch_slot >= 0) {
                auto* r = top->rootp;
                watch_valid_prev = r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[watch_slot];
                watch_prev = watch_valid_prev
                    ? uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vvars[watch_slot]) : 0u;
            }
            std::cout << "OK format=Value64" << std::endl;
            continue;
        }
        // FBRAW? — nonzero counts of both FB banks + front bit (bring-up)
        // LSNPEEK? — key listener table (ev/fn handles) as registered
        if (line == "LSNPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "LSN n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vlistener_n)
                << " cmp=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_cmp)
                << std::hex
                << " want=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_want)
                << " lastev=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__dbg_key_lastev);
            for (int i = 0; i < 8; i++)
                oss << " [" << std::dec << i << std::hex
                    << " ev=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vlistener_ev[i])
                    << " fn=" << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vlistener_fn[i]) << "]";
            std::cout << oss.str() << std::endl;
            continue;
        }
        // CHARPEEK? — byte -> 1-char intern id table (string index path)
        if (line == "CHARPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "CHAR";
            const char* probe = "01 abAB";
            for (const char* q = probe; *q; q++) {
                unsigned b = (unsigned char)*q;
                oss << " '" << *q << "'=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__char_ok[b])
                    << "/" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__char_id[b]);
            }
            unsigned nok = 0;
            for (unsigned b = 0; b < 256; b++)
                if (r->jmr_js_core__DOT__u_vm__DOT__char_ok[b]) nok++;
            oss << " total_ok=" << nok;
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VENVPEEK? — current env handle vs the venv_valid/gen table
        if (line == "VENVPEEK?") {
            auto* r = top->rootp;
            uint64_t venv = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv);
            unsigned idx = unsigned(venv & 0x3FFu);
            std::ostringstream oss;
            oss << "VENV h=" << std::hex << venv << std::dec
                << " idx=" << idx
                << " valid=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[idx])
                << " gen=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_gen[idx])
                << " len=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[idx])
                << " hgen=" << unsigned((venv >> 32) & 0xFFFu)
                << " gcpend=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vgc_mark_pend)
                << " gcword=" << std::hex << uint64_t(r->jmr_js_core__DOT__u_vm__DOT__vgc_mark_word) << std::dec
                << " bits=";
            for (unsigned i = 0; i < 24; i++)
                oss << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[i]);
            std::cout << oss.str() << std::endl;
            continue;
        }
        // VRING? — last 48 cycles of state/ip/venv/venv_valid_rdata
        if (line == "VRING?") {
            std::ostringstream oss;
            oss << "VRING";
            unsigned long n = vring_i < 48 ? vring_i : 48;
            for (unsigned long k = vring_i - n; k < vring_i; k++) {
                const VRingEnt& e = vring[k & 255];
                oss << " [" << vm_sname(e.st) << ">" << vm_sname(e.est)
                    << ":" << e.ip << " sp=" << e.vsp
                    << " f=" << e.flags << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line.rfind("ENVWATCH ", 0) == 0) {
            env_watch = std::stoi(line.substr(9));
            env_evts.clear();
            for (int sl = 0; sl < 8; sl++)
                env_prev[sl] = unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__venv_valid[sl]);
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "FWATCH") {
            fw_on = true; fw_log.clear();
            auto* rf = top->rootp;
            fw_vcsp_prev = uint8_t(rf->jmr_js_core__DOT__u_vm__DOT__vcsp);
            for (int k = 0; k < 12; k++)
                fw_rip_prev[k] = uint16_t(((rf->jmr_js_core__DOT__u_vm__DOT__vframe_control[k] >> 12) & 0xffffu));
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "FWATCH?") {
            std::ostringstream oss;
            oss << "FW n=" << fw_log.size();
            for (auto& e : fw_log) oss << " " << e;
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "GCSNAP?") {
            std::ostringstream oss;
            oss << "GCS";
            for (auto& e : gcsnap_log) oss << " " << e;
            gcsnap_log.clear();
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "ENVWATCH?") {
            std::ostringstream oss;
            oss << "ENVW n=" << env_evts.size();
            for (const EnvEvt& e : env_evts)
                oss << " [" << vm_sname(e.st) << ":" << e.ip
                    << " slot" << (e.val & 0xFF) << "->" << (e.val >> 8)
                    << " cur=" << std::hex << (e.venv & 0x3FF) << std::dec << "]";
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line.rfind("RINGSTOP ", 0) == 0) {
            ring_stop_ip = std::stoi(line.substr(9));
            ring_on = true;
            vring_frozen = false;
            vring_i = 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "OPPROFCLR") {
            for (int i = 0; i < 256; i++) { opprof_cyc[i] = 0; opprof_n[i] = 0; }
            opprof_sub.clear();
            opprof_idle = opprof_insn = opprof_busy = 0; opprof_prev_ip = 0xffffffffu;
            opprof_on = true;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "OPPROF?") {
            // VM clocks (core/3). insn busy idle, then op:n:clk for every op,
            // then | op.arg:n:clk for CALL/CALL_METH/CALL_VAL.
            std::ostringstream oss;
            oss << "OPPROF insn=" << opprof_insn << " busy=" << opprof_busy / 3
                << " idle=" << opprof_idle / 3;
            for (int i = 0; i < 256; i++)
                if (opprof_n[i] || opprof_cyc[i])
                    oss << " " << i << ":" << opprof_n[i] << ":" << opprof_cyc[i] / 3;
            oss << " |";
            for (auto& kv : opprof_sub)
                oss << " " << (kv.first >> 16) << "." << (kv.first & 0xffff) << ":"
                    << kv.second.first << ":" << kv.second.second / 3;
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "PROFCLR") {
            for (int i = 0; i < 128; i++) state_prof[i] = 0;
            prof_cycles = 0;
            prof_on = true;
            std::cout << "OK" << std::endl;
            continue;
        }
        if (line == "PROF?") {
            std::vector<std::pair<unsigned long, int>> v;
            for (int i = 0; i < 128; i++)
                if (state_prof[i]) v.push_back({state_prof[i], i});
            std::sort(v.rbegin(), v.rend());
            std::ostringstream oss;
            oss << "PROF cycles=" << prof_cycles;
            for (size_t k = 0; k < v.size() && k < 12; k++)
                oss << " " << vm_sname(unsigned(v[k].second)) << "="
                    << v[k].first
                    << "(" << (prof_cycles ? v[k].first * 100 / prof_cycles : 0) << "%)";
            std::cout << oss.str() << std::endl;
            continue;
        }
        // ENVDUMP <key> — walk the current env chain and report every
        // slot, flagging the ones whose key matches. Answers "what does this
        // variable actually resolve to" without guessing.
        if (line.rfind("ENVDUMP ", 0) == 0) {
            unsigned want = (unsigned)std::stoul(line.substr(8));
            auto* r = top->rootp;
            uint64_t venv = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv);
            std::ostringstream oss;
            oss << "ENVD want=" << want;
            {   // the global table entry this name should fall back to
                uint64_t gv =
                    (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vvars[want & (VM_MAX_VARS - 1u)];
                oss << " vvars[" << want << "]=";
                if ((gv >> 48) == 0x7ff9ull) oss << "handle";
                else { double d; std::memcpy(&d, &gv, 8); oss << d; }
                oss << " valid="
                    << unsigned(r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[want & (VM_MAX_VARS - 1u)]);
                oss << " near:";
                for (int d = -3; d <= 3; d++) {
                    unsigned ix = (want + d) & (VM_MAX_VARS - 1u);
                    if (!r->jmr_js_core__DOT__u_vm__DOT__vvar_valid[ix]) continue;
                    uint64_t nv = (uint64_t)r->jmr_js_core__DOT__u_vm__DOT__vvars[ix];
                    oss << " " << ix << "=";
                    if ((nv >> 48) == 0x7ff9ull) oss << "h";
                    else { double dd; std::memcpy(&dd, &nv, 8); oss << dd; }
                }
            }
            unsigned eid = unsigned(venv & 0x3FF);
            for (int depth = 0; depth < 8; depth++) {
                unsigned len = unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_len[eid]);
                oss << " | e" << eid << " len=" << len << " valid="
                    << unsigned(r->jmr_js_core__DOT__u_vm__DOT__venv_valid[eid]) << ":";
                for (unsigned sl = 0; sl < 16; sl++) {
                    // venv_slot is {key[9:0], val[63:0]} packed in low 74 bits
                    auto w = venv_word(r, eid * 16 + sl);
                    uint64_t val = (uint64_t)w[0] | ((uint64_t)w[1] << 32);
                    unsigned key = (unsigned)(w[2] & 0x3FF);
                    oss << " " << (key == want ? "*" : "") << key << "=";
                    if ((val >> 48) == 0x7ff9ull) oss << "h" << std::hex << (val & 0xFFFF) << std::dec;
                    else {
                        double d; std::memcpy(&d, &val, 8);
                        oss << d;
                    }
                }
                uint64_t par = uint64_t(r->jmr_js_core__DOT__u_vm__DOT__venv_parent[eid]);
                unsigned pe = unsigned(par & 0x3FF);
                if ((par >> 48) != 0x7ff9ull || pe == eid) break;
                eid = pe;
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "FBRAW?") {
            unsigned nz0 = 0, nz1 = 0;
            for (unsigned i = 0; i < 307200u; i++) {
                if (fb_bank_pix(top->rootp, true,  i)) nz0++;
                if (fb_bank_pix(top->rootp, false, i)) nz1++;
            }
            std::cout << "FBRAW nz0=" << nz0 << " nz1=" << nz1
                      << " front=" << 1u /* single-bank canvas */
                      << std::endl;
            continue;
        }
        // PDOPEEK? — first 16 latched path commands (op, p1x, p1y, p2x, p2y);
        // PDOCLR re-arms the latch (bring-up only)
        if (line == "PDOPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "PDO n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_pdo_n);
            for (int i = 0; i < 16; i++) {
                auto& w = r->jmr_js_core__DOT__u_vm__DOT__dbg_pdo[i];
                unsigned op = (unsigned)((w[2] >> 0) & 0x3);
                int16_t p1x = (int16_t)((w[1] >> 16) & 0xFFFF);
                int16_t p1y = (int16_t)(w[1] & 0xFFFF);
                int16_t p2x = (int16_t)((w[0] >> 16) & 0xFFFF);
                int16_t p2y = (int16_t)(w[0] & 0xFFFF);
                oss << " [" << op << ":" << p1x << "," << p1y << "," << p2x << "," << p2y << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        if (line == "PDOCLR") {
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_pdo_n = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_rect_n = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_line_px = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_circ_px = 0;
            top->rootp->jmr_js_core__DOT__u_vm__DOT__dbg_rect_px = 0;
            std::cout << "OK" << std::endl;
            continue;
        }
        // PXCNT? — raster px counters since PDOCLR (flood hunt)
        if (line == "PXCNT?") {
            auto* r = top->rootp;
            std::cout << "PX line=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_line_px)
                      << " circ=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_circ_px)
                      << " rect=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_rect_px)
                      << std::endl;
            continue;
        }
        // RECTPEEK? — first 16 latched rect rasterizations
        if (line == "RECTPEEK?") {
            auto* r = top->rootp;
            std::ostringstream oss;
            oss << "RECT n=" << unsigned(r->jmr_js_core__DOT__u_vm__DOT__dbg_rect_n);
            for (int i = 0; i < 64; i++) {
                uint64_t w = r->jmr_js_core__DOT__u_vm__DOT__dbg_rect[i];
                unsigned c  = (unsigned)((w >> 40) & 0xFF);
                unsigned rx = (unsigned)((w >> 30) & 0x3FF);
                unsigned ry = (unsigned)((w >> 20) & 0x3FF);
                unsigned rw = (unsigned)((w >> 10) & 0x3FF);
                unsigned rh = (unsigned)(w & 0x3FF);
                oss << " [c" << c << ":" << rx << "," << ry << " " << rw << "x" << rh << "]";
            }
            std::cout << oss.str() << std::endl;
            continue;
        }
        // FBBANK? <0|1> — dump one FB bank directly (bring-up: see what the
        // BACK buffer holds when the front never swaps in)
        if (line.rfind("FBBANK? ", 0) == 0) {
            unsigned b = 0;
            std::sscanf(line.c_str() + 8, "%u", &b);
            std::vector<uint8_t> full(307200u, 0);
            for (unsigned i = 0; i < 307200u; i++)
                full[i] = fb_bank_pix(top->rootp, b == 0, i);
            std::cout << "FB 640 480 " << b64_encode(full.data(), full.size()) << std::endl;
            continue;
        }
        // SRAMDUMP <word> <n> — bulk arena read as base64 (byte-comparing a
        // minted image against the host mint needs thousands of bytes, which
        // SRAMPEEK's hex-per-word output cannot carry). Sim-only: no fabric.
        // Returns the LOW byte of each word — how every 1 B/word arena
        // region (CSCR / SRC / CIMG) is stored.
        if (line.rfind("SRAMDUMP ", 0) == 0) {
            unsigned a = 0, n = 0;
            if (std::sscanf(line.c_str() + 9, "%u %u", &a, &n) != 2 || n == 0) {
                std::cout << "ERR args" << std::endl;
                continue;
            }
            if (n > (1u << 20)) n = 1u << 20;
            std::vector<uint8_t> b;
            b.reserve(n);
            for (unsigned i = 0; i < n && (a + i) < 4194304u; i++)
                b.push_back((uint8_t)(
                    top->rootp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[a + i]
                    & 0xFFu));
            std::cout << "SRAMDUMP " << a << " " << b.size() << " "
                      << b64_encode(b.data(), b.size()) << std::endl;
            continue;
        }
        // Test-only external RAM initialization: expose power-on assumptions.
        if (line.rfind("SRAMFILL ", 0) == 0) {
            unsigned a=0,n=0,v=0;
            if (std::sscanf(line.c_str()+9,"%u %u %u",&a,&n,&v)!=3 ||
                a>=4194304u || n>4194304u-a || v>65535u) {
                std::cout<<"ERR args"<<std::endl;continue;
            }
            for(unsigned i=0;i<n;i++)
                top->rootp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[a+i]=uint16_t(v);
            std::cout<<"OK"<<std::endl;continue;
        }
        // SRAMPEEK <word_addr> <n> — dump asset-SRAM words (bring-up only)
        if (line.rfind("SRAMPEEK ", 0) == 0) {
            unsigned a = 0, n = 8;
            std::sscanf(line.c_str() + 9, "%u %u", &a, &n);
            std::ostringstream oss;
            oss << "SRAM";
            for (unsigned i = 0; i < n && (a + i) < 4194304u; i++)
                oss << " " << std::hex
                    << unsigned(top->rootp->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[a + i]);
            std::cout << oss.str() << std::endl;
            continue;
        }
        // Title palette dump (ASET 256×RGB888 loaded by the console on RUN)
        // — GUI mirror colors FB indices exactly like the HDMI field would.
        // Test-only readback of the live resource consumers, not the staging copy.
        if (line == "SYSBYTES?") {
            std::vector<uint8_t> b(24320,0);
            auto put=[&](unsigned at,uint64_t v,unsigned n){for(unsigned i=0;i<n;i++)b[at+i]=uint8_t(v>>(8*i));};
            auto *r=top->rootp;
            for(unsigned i=0;i<2048;i++) {
                put(i*2,r->jmr_js_core__DOT__u_classic_overlay__DOT__font[i],2);
                put(4096+i*2,r->jmr_js_core__DOT__u_classic_overlay__DOT__u_static_labels__DOT__records[i],2);
                put(9472+i*5,r->jmr_js_core__DOT__u_system_overlay__DOT__key_rows[i],5);
            }
            for(unsigned i=0;i<256;i++)put(8192+i*4,r->jmr_js_core__DOT__u_classic_overlay__DOT__u_static_labels__DOT__layouts[i] |
                (uint32_t(r->jmr_js_core__DOT__u_classic_overlay__DOT__widths[i])<<18),4);
            // Menu headings are software resources; read their validated SYS cache.
            for(unsigned i=0;i<80;i++)b[9216+i]=uint8_t(r->jmr_js_core__DOT__g_sram__DOT__u_sram__DOT__mem[3565568+(9216+i)/2]>>(((9216+i)&1)*8));
            for(unsigned i=0;i<28;i++)put(9344+i*4,r->jmr_js_core__DOT__pixel_sys_config[i],4);
            put(9456,r->jmr_js_core__DOT__pixel_sys_config[28]&65535,2);
            for(unsigned i=0;i<64;i++)put(19712+i*8,r->jmr_js_core__DOT__u_system_overlay__DOT__label_rows[i],8);
            for(unsigned i=0;i<48;i++)put(20224+i*8,r->jmr_js_core__DOT__u_system_overlay__DOT__label_rows[64+i],8);
            std::cout << "SYSBYTES " << b64_encode(b.data(),b.size()) << std::endl;
            continue;
        }
        if (line == "SYSPIX?") {
            std::vector<uint8_t> b(114,0);
            for(unsigned i=0;i<114;i++)b[i]=uint8_t(top->rootp->jmr_js_core__DOT__pixel_sys_config[i/4]>>((i%4)*8));
            std::cout << "SYSPIX " << b64_encode(b.data(),b.size()) << std::endl;
            continue;
        }
        if (line == "SYS?") {
            std::cout << "SYS status=" << unsigned(top->rootp->jmr_js_core__DOT__sys_status) << " rom=" << unsigned(top->rootp->jmr_js_core__DOT__u_cons__DOT__rom_status) << std::endl;
            continue;
        }
        if (line == "PAL?") {
            uint8_t pal[768];
            for (int i = 0; i < 256; i++) {
                top->pal_raddr = (uint8_t)i;
                tick(); // registered BRAM read — settle
                tick();
                uint32_t v = top->pal_rdata;
                pal[i * 3 + 0] = (uint8_t)(v >> 16);
                pal[i * 3 + 1] = (uint8_t)(v >> 8);
                pal[i * 3 + 2] = (uint8_t)(v);
            }
            std::cout << "PAL " << b64_encode(pal, sizeof(pal)) << std::endl;
            continue;
        }
        if (line == "FB?") {
            // Real mini-FB pixels when game_mode (RECTDEMO / VM)
            // game_mode OR a chained program (EDIT: cmp_arm holds game_mode
            // off). Without this, FB? is always SAME during EDIT and the
            // GUI letterboxes READY over the editor.
            if (top->game_mode || top->desktop_visible_o ||
                (top->rootp->jmr_js_core__DOT__u_cons__DOT__cmp_interactive && top->rootp->jmr_js_core__DOT__u_vm__DOT__running)) {
                std::cout << "FB 640 480 " << fb_export_b64() << std::endl;
            } else {
                std::cout << "FB SAME" << std::endl;
            }
            continue;
        }
        // One VM frame — tick until fb swap (dbg_swap_n) or cap.
        // GUI TICK=1000 was << frame_div 65536, so PACMAN ghosts never left.
        // 2M was too small once string-row sprites actually painted: INVADERS
        // drawBitmap is per-pixel str[i]+fillRect, so FRAME capped mid-rAF
        // (~1 swap per 5 GUI frames) and the wave crawled. Cap is not SPI.
        if (line == "FRAME" || line.rfind("FRAME ", 0) == 0) {
            if (frame_resume.pending && frame_resume.epoch != frame_epoch)
                frame_resume = FrameResume{};
            const bool resuming = frame_resume.pending;
            const bool plain_frame = resuming ? frame_resume.plain : line == "FRAME";
            const uint64_t epoch0 = frame_epoch;
            // flush taps deferred by the KEYEVT handler: these ups enter
            // the FIFO now and dispatch at THIS frame's event phase,
            // after the rAF callback has seen the key held once.
            for (int kc = 0; kc < 256; kc++)
                if (!resuming && key_pending_up[kc] &&
                    key_pending_up[kc] <= key_frame_counter) {
                    key_pending_up[kc] = 0;
                    key_strobe((unsigned)kc, 0);
                }
            if (!resuming && plain_frame) key_frame_counter++;
            // Debug ergonomics: a frame that never presents used to burn
            // 64M clocks (~30 s of wall time) with the server inside this
            // RPC, so the GUI ignored ESC and had to be restarted. The
            // cap is a HOST-side responsiveness limit, not the VM's frame
            // budget; a capped frame still reports FB SAME exactly as
            // before, just sooner. Raise it back once frames complete.
            // A real INVADERS play frame is ~500k instructions at ~15
            // clocks each (~8-10M clocks): drawBitmap paints every sprite
            // pixel as its own fillRect. An 8M cap truncated every play
            // frame, which looked exactly like a freeze. 32M fits a real
            // frame with margin and still bounds a stuck frame.
            // Measured: an INVADERS play frame is ~2.2M+ instructions at
            // ~14.5 clocks each (per-pixel fillRect sprites + nested
            // collision loops) => 40M+ clocks. 32M truncated it. 64M is
            // the documented cap and is not exceeded.
            // div8: the VM pays 8x clocks per frame; the cap is a HOST
            // responsiveness bound and scales with it.
            // GUI system applications use a bounded slice so Tk can service input
            // during a long first paint. Plain FRAME retains the existing game cap.
            const int CAP = line == "FRAME" ? 512000000 :
                int(std::max(1000ul, std::min(512000000ul, std::stoul(line.substr(6)))));
            int used = 0;
            int got = 0;
            int pulsed = resuming && frame_resume.pulsed;
            int left_wait = resuming && frame_resume.left_wait;
            int idle_run = resuming ? int(frame_resume.idle_run) : 0;
            int dead = 0;       // VM already halted — do not burn the cap
            auto* rframe = top->rootp;
            // A frame is finished when the VM PRESENTS. The older test
            // (left_wait && back in S_WAIT_FRAME && cbip != 0) depended on
            // dbg_cb_ip, which only the 32-bit path ever wrote, so an
            // HTML/Value64 title could only end a frame via the 2000-clock
            // idle fallback — fine for a static splash, never true during
            // play. Every play frame therefore burned the whole 64M cap and
            // the GUI blocked on this RPC (INVADERS "locked the terminal",
            // PACMAN black, ASTEROID score-only). Watch the present counter.
            unsigned swap0 = resuming ? frame_resume.swap0 :
                unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n);
            unsigned long frame_ipn = 0;
            unsigned ip_prev_f = 0xffff;
            static unsigned long region[256];
            for (int k = 0; k < 256; k++) region[k] = 0;
            if (ip_hist.size() < 65536) ip_hist.assign(65536, 0);
            else std::fill(ip_hist.begin(), ip_hist.end(), 0u);
            for (; used < CAP; used++) {
                // FPGA-SIM: one frame_tick when already in S_WAIT_FRAME, then
                // drop it so `else if (frame_fire)` can dispatch rAF. Do not
                // treat the same-cycle present_pend swap as a finished frame
                // (that starved the callback — KEEP.JS needed a second rAF).
                unsigned st0 = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__state);
                // ARRAY_GET fault=255 (and any machine_fault) used to leave
                // game_mode up while FRAME spun 64M clocks — GUI stuck on
                // COMPILE, queued LIST keys landed as garbage after ESC.
                if (rframe->jmr_js_core__DOT__u_vm__DOT__machine_fault
                    || st0 == 15u /* S_DONE */
                    || (st0 == 0u /* S_IDLE */ && used > 64 && !pulsed)) {
                    dead = 1;
                    break;
                }
                if (st0 == 14u && !pulsed) {
                    top->sim_frame_pulse = 1;
                    pulsed = 1;
                }
                tick();
                top->sim_frame_pulse = 0;
                unsigned cbip = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__dbg_cb_ip);
                {
                    unsigned ipc = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__ip);
                    if (ipc != ip_prev_f) {
                        frame_ipn++; ip_prev_f = ipc;
                        region[(ipc >> 8) & 0xFF]++;
                        ip_hist[ipc & 0xFFFF]++;
                    }
                }
                unsigned st = unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__state);
                if (rframe->jmr_js_core__DOT__u_vm__DOT__machine_fault
                    || st == 15u || st == 0u) {
                    if (st != 14u) {
                        dead = 1;
                        used++;
                        break;
                    }
                }
                if (pulsed && st != 14u)
                    left_wait = 1;
                // Present after the rAF has run (back in S_WAIT_FRAME), not on
                // the present_pend swap that shares the pulse cycle.
                bool frame_continue =
                    unsigned(top->rootp->jmr_js_core__DOT__u_vm__DOT__frame_fire) != 0;
                if (left_wait && st == 14u && cbip != 0 &&
                    !frame_continue) {
                    got = 1; used++; break;
                }
                // The Value64 scheduler drains this frame's callbacks before
                // returning to WAIT_FRAME. Preserve the state/present guards:
                // a mid-callback swap is not a completed logical frame.
                // The retired tagged queue count was always zero for accepted
                // programs; removing that predicate adds no new due-timer test.
                if (pulsed && left_wait && st == 14u &&
                    unsigned(rframe->jmr_js_core__DOT__u_vm__DOT__dbg_swap_n)
                        != swap0) {
                    got = 1; used++; break;
                }
                // One-shot screen (title with no rAF re-arm, or a frame
                // whose only work was the present) never leaves S_WAIT_FRAME.
                // Burning the 16M cap there froze the GUI for seconds per
                // frame and delayed the next KEYEVT dispatch (DONKEY Enter).
                idle_run = (pulsed && st == 14u) ? (idle_run + 1) : 0;
                if (idle_run > 2000) { got = 1; used++; break; }
                // Halfway to the cap this frame is clearly not finishing:
                // start recording ips so the cap summary has something to show.
                if (used == CAP / 2 && !ip_trace_user) {
                    ip_trace.clear();
                    ip_trace_cap = 4000;
                    ip_trace_prev = 0xffff;
                }
            }
            last_fclk = (unsigned)used;
            last_fcap = (got || dead) ? 0u : 1u;
            if (last_fcap) {
                loop_ipn = frame_ipn;
                for (int k = 0; k < 5; k++) { top_ip[k] = 0; top_cnt[k] = 0; }
                for (unsigned i2 = 0; i2 < ip_hist.size(); i2++) {
                    unsigned c2 = ip_hist[i2];
                    if (!c2) continue;
                    for (int k = 0; k < 5; k++) {
                        if (c2 > top_cnt[k]) {
                            for (int j = 4; j > k; j--) {
                                top_cnt[j] = top_cnt[j-1]; top_ip[j] = top_ip[j-1];
                            }
                            top_cnt[k] = c2; top_ip[k] = i2;
                            break;
                        }
                    }
                }
                for (int k = 0; k < 3; k++) { hot_lo[k] = 0; hot_n[k] = 0; }
                for (int r = 0; r < 256; r++) {
                    for (int k = 0; k < 3; k++) {
                        if (region[r] > hot_n[k]) {
                            for (int j = 2; j > k; j--) {
                                hot_n[j] = hot_n[j - 1]; hot_lo[j] = hot_lo[j - 1];
                            }
                            hot_n[k] = region[r]; hot_lo[k] = unsigned(r) << 8;
                            break;
                        }
                    }
                }
                // Capped: summarise the ip ring into the three hottest ips.
                std::map<unsigned, unsigned> hist;
                for (uint16_t v : ip_trace) hist[v]++;
                for (int k = 0; k < 3; k++) { loop_ip[k] = 0; loop_hits[k] = 0; }
                for (auto& kv : hist) {
                    for (int k = 0; k < 3; k++) {
                        if (kv.second > loop_hits[k]) {
                            for (int j = 2; j > k; j--) {
                                loop_hits[j] = loop_hits[j - 1];
                                loop_ip[j] = loop_ip[j - 1];
                            }
                            loop_hits[k] = kv.second;
                            loop_ip[k] = kv.first;
                            break;
                        }
                    }
                }
            }
            if (!ip_trace_user) {
                ip_trace.clear();
                ip_trace_cap = 0;
            }
            if (!plain_frame && got) key_frame_counter++;
            if (!got && !dead) fcap_n++;
            if (!got && !dead && epoch0 == frame_epoch) {
                frame_resume.pending = true;
                frame_resume.pulsed = pulsed != 0;
                frame_resume.left_wait = left_wait != 0;
                frame_resume.plain = plain_frame;
                frame_resume.idle_run = unsigned(idle_run);
                frame_resume.swap0 = swap0;
                frame_resume.epoch = epoch0;
            } else {
                frame_resume = FrameResume{};
            }
            // Same reason as the TICKN flush — the editor's F2
            // save and the compile mint land during FRAME pumping; RUN and
            // the GUI read card.img from disk. No-op unless the card is dirty.
            sd_save_image();
            // game_mode OR canvas editor (cmp_arm holds game_mode off).
            if (top->game_mode || !top->ready_lit) {
                // Capped FRAME has not presented — skip the 640×480 dump
                // (was ~5 wasted FB encodes per visual frame).
                if (got)
                    std::cout << "FB 640 480 " << fb_export_b64() << std::endl;
                else
                    std::cout << "FB SAME" << std::endl;
            } else {
                std::cout << "FB SAME" << std::endl;
            }
            continue;
        }
        std::cout << "ERR" << std::endl;
    }
    delete top;
    return 0;
}
