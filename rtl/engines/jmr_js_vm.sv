// JMR-JS stack VM — BRAM code (writable from FAT .JSB) + 640×480 game FB.
// ISA: functional_model/bytecode.py + jsb_format.py
//
// Section map (st_t groups — keep enum order; append new states at the end):
//   boot/load:  S_IDLE..S_TRAIL, S_FETCH_WAIT
//   raster:     S_CLEAR, S_RECT, S_CIRCLE, S_LINE, S_BLIT, S_SPR, S_PWALK..S_QPY
//   frame:      S_WAIT_FRAME, S_DONE, S_XF_MUL, S_XF_APPLY
//   strings:    S_JOIN, S_JOIN_FIND, S_CONCAT, S_REPL, S_IDXSTR,
//               S_FONTPX..S_STR_WR, S_NAMCPY (interned → json_mem)
//   numbers:    S_SQRT
//   JSON:       S_JSON_PARSE
//   ImageData:  S_IMGD_GET, S_IMGD_PUT
// Enum entries with no arm (S_EXEC, S_NAT, S_IDXOF, S_DIV.., S_GC_*, ...) only
// hold the numbering shared with jmr_js_vm_pkg::st_t and the state-name tables.
module jmr_js_vm #(
    parameter string CODE_HEX = "invaders_jsb.hex",
    // The 8x8 glyph table PYTHON draws with (functional_model/font8.py,
    // exported by tools/export_font_rom_hex.py) so ctx.fillText paints real
    // characters instead of the old 64x8 bar stub
    parameter string FONT_HEX = "font_rom.hex"
) (
    input  logic        clk,
    // div8: code loads stream at the full 100 MHz console rate
    // while the VM core runs on the /8 BUFGCE clock. The code BRAM write
    // port keeps the full-rate clock (true dual port, one clock per port).
    input  logic        clk_code_w,
    input  logic        rst_n,
    input  logic        start,
    input logic [31:0] image_code_bytes_i = 32'd0,
    input logic image_code_valid_i = 1'b0,
    output logic first_frame_o,
    // V1.5 standalone compile: the console publishes how much source it
    // parked, and reads back the compiler's exit report.
    input  logic [17:0] src_len_i,
    // srcSetLen (nid 50) -> console: a PROGRAM edited SOURCE.
    output logic [17:0] src_setlen_o,
    output logic        src_setlen_stb_o,
    output logic        cmp_done_o,
    output logic [7:0]  cmp_status_o,
    output logic [20:0] cmp_len_o,
    output logic [6:0]  cmp_msglen_o,
    input  logic        stop,
    input  logic        frame_tick,
    input  logic [5:0]  joy_in,
    // analog-joy: raw stick axes/buttons the digital joy_in doesn't carry.
    input  logic [7:0]  analog_x,
    input  logic [7:0]  analog_y,
    input  logic [4:0]  joy_btn,
    // Raw host keyboard events (GUI/board PS/2) — the HTML decides
    // bindings; no hardcoded key maps here (replaces the synthetic-Enter hack)
    input  logic        key_evt_stb,
    input  logic [7:0]  key_evt_code,
    input  logic        key_evt_down,
    input logic [7:0] key_evt_char = 8'd0,
    output logic key_evt_ready,
    output logic sysw_toggle_o,
    output logic [3:0] sysw_field_o,
    output logic [31:0] sysw_value_o,
    output logic fs_request,
    output logic [2:0] fs_command,
    output logic [127:0] fs_arguments,
    input logic fs_reply=1'b0,
    input logic [31:0] fs_result=32'hffffffff,
    output logic ui_text_toggle_o,ui_text_menu_o,ui_text_title_o,ui_text_first_o,ui_text_last_o,
    output logic [7:0] ui_text_byte_o,
    input  logic        mouse_evt_valid = 1'b0,
    input  logic [47:0] mouse_evt_data = 48'd0,
    output logic        mouse_evt_pop,
    // Console loads NAME.JSB into code BRAM before start
    input logic toolbox_code_we=0,
    input logic [12:0] toolbox_code_addr=0,
    input logic [31:0] toolbox_code_data=0,
    input  logic        code_we,
    input  logic [14:0] code_waddr,
    input  logic [31:0] code_wdata,
    output logic        busy,
    output logic        done,
    // BOARD tether VM heartbeat: flopped scalars only,
    // packed on the VM clock - the link samples a register, never the
    // FSM cone. {1'b0, st[6:0], fault[7:0], ip[15:0]}.
    output logic [31:0] vdbg_o,
    output logic        vdbg_fault_o,
    // Observability (see the LIVE OBSERVABILITY block)
    output logic [31:0] vm_hdbg,
    output logic [31:0] vm_fdbg,
    output logic        vm_fdbg_v,
    output logic [127:0] vm_ftrace,
    output logic [47:0]  vm_gdbg,   // {fault_site, fault_arg} — latch on vm_fdbg_v edge
    // sound(ch,freq,vol,frames,slide) poke -> PSG PHY (top-level leaf)
    input  logic        snd_ack, // destination captured the held sound packet
    output logic        snd_tgl,
    output logic [1:0]  snd_ch,
    output logic [15:0] snd_freq,
    output logic [3:0]  snd_vol,
    output logic [7:0]  snd_frames,
    output logic [7:0]  snd_slide,
    output logic        fb_we,
    output logic [18:0] fb_waddr,
    output logic [9:0]  fb_x, fb_y,
    output logic [7:0]  fb_wdata,
    output logic        fb_swap,
    // GetImageData reads the back bank (FM _nat_get_image_data twin).
    // Muxed onto mini_fb dump_raddr; dump_back is the non-front bank.
    input  logic        fb_present_busy, // Session-1: DDR3 present in flight
    output logic [18:0] fb_dump_addr,
    output logic        fb_dump_sel,
    input  logic [7:0]  fb_dump_back,
    // Front-bank dump read (same dump_raddr) for S_FB_SYNC copy
    input  logic [7:0]  fb_dump_front,
    // External asset SRAM read port (jmr_sram_port master, read-only) —
    // ASET sprite banks live there; blitter fetches pixels 2-per-16-bit word
    output logic        sram_req,
    output logic [21:0] sram_addr,
    // Fit: write channel added so the ImageData snapshot lives at
    // the top of the external asset bank instead of an 80-tile on-chip BRAM.
    // Console owns the bus outside RUN; the core mux keeps console priority.
    output logic        sram_we,
    output logic [15:0] sram_wdata,
    input  logic [15:0] sram_rdata,
    input  logic        sram_ack,
    // C1: full-rate raster engine handshake. The VM latches
    // the op's scalars, pulses rast_go for ONE beat, then blocks until
    // rast_busy has risen and fallen. Engine: jmr_raster_engine.sv.
    output logic        rast_go,
    output logic [1:0]  rast_mode,
    output logic signed [11:0] rast_dx,
    output logic signed [11:0] rast_dy,
    output logic [9:0]  rast_w,
    output logic [9:0]  rast_h,
    output logic [7:0]  rast_color,
    output logic [15:0] rast_sx,
    output logic [15:0] rast_sy,
    output logic [15:0] rast_qx,
    output logic [15:0] rast_rxr,
    output logic [15:0] rast_qy,
    output logic [15:0] rast_ryr,
    output logic [22:0] rast_sbase,
    output logic [15:0] rast_stride,
    output logic        rast_aset,
    // neg-xform: mirror dest column/row order (negative dWidth/dHeight or
    // ctx_sx/sy < 0); source DDA order is unchanged, see jmr_js_vm_exec64.sv
    output logic        rast_flip_x,
    output logic        rast_flip_y,
    input  logic        rast_done   // op completed (level; cleared at next go)
);
    // Code capacity in words. The largest card title (PACMAN) needs 16443;
    // the extended PACMAN test image needs 19527. The console clamps writes
    // and the tools refuse bigger images.
    localparam int CODE_WORDS = 21504;
    localparam int MAX_CONSTS = 1024;
    localparam int MAX_VARS   = 512;
    localparam int STACK_DEPTH = 1024; // RTL vspmax=71 (40-frame PACMAN attract); flat
                                       // array literals push per element, so a literal
                                       // near 1000 slots still fits; vsp>=1008 faults (8'd7).
    // Native 640×480 FB (matches PYTHON glass; no scale4)
    localparam int MW = 640;
    localparam int MH = 480;
    localparam int FB_PIXELS = MW * MH;

    localparam logic [7:0] OP_LOAD_CONST = 8'd1;
    localparam logic [7:0] OP_LOAD_VAR   = 8'd2;
    localparam logic [7:0] OP_STORE_VAR  = 8'd3;
    localparam logic [7:0] OP_ADD        = 8'd4;
    localparam logic [7:0] OP_SUB        = 8'd5;
    localparam logic [7:0] OP_MUL        = 8'd6;
    localparam logic [7:0] OP_DIV        = 8'd7;
    localparam logic [7:0] OP_LT         = 8'd8;
    localparam logic [7:0] OP_GT         = 8'd9;
    localparam logic [7:0] OP_EQ         = 8'd10;
    localparam logic [7:0] OP_JUMP       = 8'd11;
    localparam logic [7:0] OP_JIF        = 8'd12;
    localparam logic [7:0] OP_CALL       = 8'd13;
    localparam logic [7:0] OP_RETURN     = 8'd14;
    localparam logic [7:0] OP_POP        = 8'd15;
    localparam logic [7:0] OP_DUP        = 8'd16;
    localparam logic [7:0] OP_NEG        = 8'd17;
    localparam logic [7:0] OP_NOT        = 8'd18;
    localparam logic [7:0] OP_MAKE_ARR   = 8'd19;
    localparam logic [7:0] OP_ARR_GET    = 8'd20;
    localparam logic [7:0] OP_ARR_SET    = 8'd21;
    localparam logic [7:0] OP_LET_VAR    = 8'd22;
    localparam logic [7:0] OP_MOD        = 8'd23;
    localparam logic [7:0] OP_CALL_USER  = 8'd24;
    localparam logic [7:0] OP_RET_VAL    = 8'd25;
    localparam logic [7:0] OP_MAKE_OBJ   = 8'd26;
    localparam logic [7:0] OP_GET_PROP   = 8'd27;
    localparam logic [7:0] OP_SET_PROP   = 8'd28;
    localparam logic [7:0] OP_NEW_OBJ    = 8'd29;
    localparam logic [7:0] OP_CALL_METH  = 8'd30;
    localparam logic [7:0] OP_BIT_OR     = 8'd31;
    localparam logic [7:0] OP_BIT_AND    = 8'd32;
    localparam logic [7:0] OP_MAKE_FN    = 8'd33;
    localparam logic [7:0] OP_CALL_VAL   = 8'd34;

    // Fit: pow2-chunked (16K+4K = 20480 exact) - see the heap
    // slot arrays for why. The boot hex (tiny stub) loads into chunk 0.
    (* ram_style = "block" *) logic [31:0] code_mem_c0 [0:16383] /*verilator public_flat_rw*/;
    (* ram_style = "block" *) logic [31:0] code_mem_c1 [0:4095]  /*verilator public_flat_rw*/;
    // One remaining tile holds large programs' final metadata without LUT RAM.
    (* ram_style = "block" *) logic [31:0] code_mem_c2 [0:1023] /*verilator public_flat_rw*/;
    initial $readmemh(CODE_HEX, code_mem_c0);
    logic [14:0] code_raddr_ff /*verilator public_flat_rd*/;
    logic [14:0] code_raddr;
    logic [31:0] code_rdata;
    // Read port (VM fetch) + write port (FAT .JSB load) — dual-port BRAM,
    // pow2-chunked. Registered chunk select keeps the 1-beat fetch contract.
    // Out-of-range writes drop (too-big images refused loud at S_GOT_HDR2).
    // Shared software Toolbox: 8 BRAM tiles (4K+2K+1K+1K).
    // The 8K virtual prefix leaves the existing 21K application bank intact.
    (* ram_style="block" *) logic [31:0] toolbox_code0 [0:4095] /*verilator public_flat_rw*/;
    (* ram_style="block" *) logic [31:0] toolbox_code1 [0:2047] /*verilator public_flat_rw*/;
    (* ram_style="block" *) logic [31:0] toolbox_code2 [0:1023] /*verilator public_flat_rw*/;
    (* ram_style="block" *) logic [31:0] toolbox_code3 [0:1023] /*verilator public_flat_rw*/;
    initial $readmemh("toolbox_code3.hex",toolbox_code3);
    initial $readmemh("toolbox_code2.hex",toolbox_code2);
    initial $readmemh("toolbox_code0.hex",toolbox_code0);
    initial $readmemh("toolbox_code1.hex",toolbox_code1);
    logic load_toolbox /*verilator public_flat_rw*/=0;
    logic [14:0] load_ops_base /*verilator public_flat_rw*/=0;
    logic [31:0] load_toolbox_hash /*verilator public_flat_rw*/=0;
    logic [31:0] toolbox_hash /*verilator public_flat_rw*/=jmr_toolbox_rom_pkg::DEFAULT_HASH;
    // Cold-load identity: bundles are stable before START; the existing
    // header fetch sequence gives several VM beats before S_GOT_HDR2.
    // Keep the fast-domain hash comparator off the wide VM init/reset cone.
    logic toolbox_identity_match_q;
    always_ff @(posedge clk)begin
        if(!rst_n)toolbox_identity_match_q<=1'b0;
        else toolbox_identity_match_q<=(load_toolbox_hash==toolbox_hash);
    end
    wire code_is_toolbox=load_toolbox && code_raddr>=load_ops_base && code_raddr<load_ops_base+15'd8192;
    wire [14:0] code_physical=load_toolbox && code_raddr>=load_ops_base+15'd8192 ? code_raddr-15'd8192 : code_raddr;
    logic [31:0] code_r_c0,code_r_c1,code_r_c2,code_r_toolbox0,code_r_toolbox1,code_r_toolbox2,code_r_toolbox3;
    wire [12:0] toolbox_raddr=13'(code_raddr-load_ops_base);
    logic [1:0] toolbox_rbank;
    logic toolbox_final_word;
    wire [31:0] code_r_toolbox=toolbox_rbank==0?code_r_toolbox0:toolbox_rbank==1?code_r_toolbox1:toolbox_rbank==2?code_r_toolbox2:toolbox_final_word?jmr_toolbox_rom_pkg::PADDING:code_r_toolbox3;
    logic [1:0] code_rsel;
    logic code_r_is_toolbox;
    always_ff @(posedge clk) begin
        code_r_c0<=code_mem_c0[code_physical[13:0]];
        code_r_c1<=code_mem_c1[code_physical[11:0]];
        code_r_c2<=code_mem_c2[code_physical[9:0]];
        code_r_toolbox0<=toolbox_code0[toolbox_raddr[11:0]];
        code_r_toolbox1<=toolbox_code1[toolbox_raddr[10:0]];
        code_r_toolbox2<=toolbox_code2[toolbox_raddr[9:0]];
        code_r_toolbox3<=toolbox_code3[toolbox_raddr[9:0]];
        toolbox_final_word<=toolbox_raddr==13'd8191;
        toolbox_rbank<=toolbox_raddr<4096?0:toolbox_raddr<6144?1:toolbox_raddr<7168?2:3;
        code_rsel <= code_physical < 15'd16384 ? 2'd0 : code_physical < 15'd20480 ? 2'd1 : 2'd2;
        code_r_is_toolbox<=code_is_toolbox;
    end
    always_ff @(posedge clk_code_w)if(toolbox_code_we)begin
        if(toolbox_code_addr<4096)toolbox_code0[toolbox_code_addr[11:0]]<=toolbox_code_data;
        else if(toolbox_code_addr<6144)toolbox_code1[toolbox_code_addr[10:0]]<=toolbox_code_data;
        else if(toolbox_code_addr<7168)toolbox_code2[toolbox_code_addr[9:0]]<=toolbox_code_data;
        else if(toolbox_code_addr<8191)toolbox_code3[toolbox_code_addr[9:0]]<=toolbox_code_data;
        toolbox_hash<=(toolbox_code_addr==0?32'd0:{toolbox_hash[30:0],toolbox_hash[31]})^toolbox_code_data;
    end
    // Write port on the full-rate clock (console streams during load; the
    // VM is stopped then, so the domains never touch the same word live).
    // One pipeline stage before the BRAMs: the raw console strobe fanned
    // out to WEA pins across the die and was pblock36's routed head
    // (-0.261, u_cons/code_we -> code_mem WEA). code_we is fire-and-
    // forget (no handshake), so the extra cycle is invisible.
    logic        code_we_q;
    logic [14:0] code_waddr_q2;
    logic [31:0] code_wdata_q2;
    always_ff @(posedge clk_code_w) begin
        code_we_q     <= code_we;
        code_waddr_q2 <= code_waddr;
        code_wdata_q2 <= code_wdata;
        if (code_we_q) begin
            if(code_waddr_q2==0)begin load_toolbox<=0;load_toolbox_hash<=0;end
            if(code_waddr_q2==1)load_ops_base<=15'(4+2*code_wdata_q2[31:16]);
            if(code_waddr_q2==2)begin
                load_toolbox<=code_wdata_q2[20];
                if(!code_wdata_q2[17])load_ops_base<=load_ops_base-1'b1;
            end
            if(load_toolbox && code_waddr_q2>=load_ops_base && code_waddr_q2<load_ops_base+15'd8192)
                load_toolbox_hash<={load_toolbox_hash[30:0],load_toolbox_hash[31]}^code_wdata_q2;
            else begin
                if(code_write_physical<15'd16384)code_mem_c0[code_write_physical[13:0]]<=code_wdata_q2;
                else if(code_write_physical<15'd20480)code_mem_c1[code_write_physical[11:0]]<=code_wdata_q2;
                else if(code_write_physical<15'(CODE_WORDS))code_mem_c2[code_write_physical[9:0]]<=code_wdata_q2;
            end
        end
    end
    wire [14:0] code_write_physical=load_toolbox && code_waddr_q2>=load_ops_base+15'd8192 ? code_waddr_q2-15'd8192 : code_waddr_q2;
    assign code_rdata=code_r_is_toolbox?code_r_toolbox:code_rsel==0?code_r_c0:code_rsel==1?code_r_c1:code_r_c2;

    // Public for the sim server VMSTAT? probe (FPGA-SIM bring-up only)
    logic [10:0] sp /*verilator public_flat_rd*/; // 2048-deep eval stack
    logic [15:0] ip_ff;
    logic [15:0] ip /*verilator public_flat_rd*/;
    logic [15:0] n_ops, n_consts;
    logic [15:0] ops_base /*verilator public_flat_rd*/;
    logic [15:0] jsb_flags /*verilator public_flat_rd*/;
    logic        looping, running /*verilator public_flat_rd*/;
    // Value64 is a gated scalar island. It deliberately does not reuse the
    // legacy Q16/tag stack, so a FLAG_VALUE64 image cannot alias old state.
    (* ram_style = "block" *) logic [63:0] vconsts [0:MAX_CONSTS-1];
    (* ram_style = "block" *) logic [63:0] vstack [0:STACK_DEPTH-1] /*verilator public_flat_rd*/;
    // TOS window (FFs) + 1W1R BRAM. CPU combo reads vst_peek[]; writes vst_wr().
    // Vivado 8-7186: ram_style=block is ignored if the CPU always_ff also
    // combo-reads the array (LUTRAM, blows 30 MHz).
    logic [63:0] vst_win [0:15] /*verilator public_flat_rd*/;
    // Combo TOS-window peek — not a function (Vivado Synth 8-660 will not
    // resolve function automatic vst_at from the unique case). Index 0 = TOS.
    // Window only; do not combo-read vstack BRAM (vst_rdata is last beat).
    logic [63:0] vst_peek [0:15];
    logic [1023:0] vst_win_pack;
    logic        vst_we;
    logic [11:0] vst_waddr, vst_raddr;
    logic [63:0] vst_wdata, vst_rdata;
    logic [11:0] vsp_d;
    logic        vst_hold_win;
    // S_V64_WIN_FILL: sequential BRAM reload of vst_win[1..15] (win[0] is TOS).
    logic [3:0]  vst_refill_i;
    logic        vst_refill_arm;
    // ARRAY_SET win[1] (index) can be leftover after getImageData / nested
    // forEach. One BRAM refill then retry; still fault 241 if BRAM is not a
    // Number (do not no-op).
    logic        aset_win_retried;
    (* ram_style = "block" *) logic [63:0] vvars [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic        vvars_we;
    logic [8:0]  vvars_waddr;
    logic [63:0] vvars_wdata;
    logic [8:0]  vvars_raddr;
    (* ram_style = "distributed" *) logic vvar_valid [0:MAX_VARS-1] /*verilator public_flat_rd*/;
    logic [11:0] vsp_ff;
    logic [11:0] vsp /*verilator public_flat_rd*/;
    logic [7:0] vcsp_ff;
    logic [7:0] vcsp /*verilator public_flat_rd*/;
    logic [31:0] vconst_lo;
    // Value64 DIV/MOD use restoring integer datapaths, one quotient bit per
    // clock. They remain wholly separate from the legacy Q16 divider.
    logic [106:0] vdiv_num, vdiv_quot;
    logic [53:0] vdiv_rem;
    logic [52:0] vdiv_den;
    logic [7:0] vdiv_count;
    logic signed [12:0] vdiv_exp;
    logic vdiv_sign;
    logic [52:0] vmod_rem, vmod_den;
    logic [11:0] vmod_count;
    logic signed [12:0] vmod_exp;
    logic vmod_sign;
    // Stable Value64 heaps. Object and function handles share the
    // MAX_OBJ-slot index space; kind 1 is object and kind 2 is reserved
    // for a function slot. Generations never use zero.
    logic [1:0] vobj_alloc [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic        vobj_alloc_we;
    logic [9:0]  vobj_alloc_waddr;
    logic [1:0]  vobj_alloc_wdata;
    logic [12:0] vobj_alloc_raddr;
    (* ram_style = "block" *) logic [11:0] vobj_gen [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [5:0] vobj_len [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // NEW_OBJ stores the interned class name so CALL_METH can find the
    // class-table method (PYTHON _value_object_classes). 16'hFFFF = none.
    (* ram_style = "block" *) logic [15:0] vobj_cls [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // PYTHON _value_object_protos / _value_function_prototypes. `var Stage =
    // function` + Stage.prototype.createItem is not a JSB class-method table.
    (* ram_style = "block" *) logic [63:0] vobj_proto [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_proto [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // Object/array slots are 1-D SRAM after the MAX_* localparams (not 2-D
    // combo arrays — Synth 8-4556 / ASIC SRAM).
    (* ram_style = "block" *) logic [11:0] vfn_gen [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    // Function handles are their own leftover-BRAM bank (vfn_* already
    // 1024-wide). They must not occupy vobj_alloc — that shared the 1024
    // bump with objects and faulted MAKE_OBJ while function slots were
    // the ones that were full (same PYTHON lists, same split).
    (* ram_style = "distributed" *) logic vfn_valid [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic vfn_mark [0:OBJ_PHYS-1];
    logic [15:0] vfn_entry [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [5:0] vfn_nparam [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_env [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vfn_bound_this [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [2:0] vfn_flags [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic varr_valid [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [11:0] varr_gen [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] varr_len [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic        varr_len_we;
    logic [11:0] varr_len_waddr;
    logic [7:0]  varr_len_wdata;
    logic [11:0] varr_len_raddr;
    (* ram_style = "distributed" *) logic varr_long [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [7:0] varr_lidx [0:MAX_ARR-1] /*verilator public_flat_rd*/;
    logic vlong_used [0:LONG_PHYS-1];
    (* ram_style = "distributed" *) logic vobj_mark [0:OBJ_PHYS-1];
    (* ram_style = "distributed" *) logic varr_mark [0:MAX_ARR-1];
    (* ram_style = "distributed" *) logic venv_valid [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [11:0] venv_gen [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] venv_parent [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    logic [4:0] venv_len [0:ENV_PHYS-1] /*verilator public_flat_rd*/;
    // Env slots are 1-D venv_slot SRAM (not 2-D combo — Synth 8-4556).
    logic [63:0] vthis_ff;
    logic [63:0] vthis /*verilator public_flat_rd*/;
    logic [63:0] venv_ff /*verilator public_flat_rd*/;
    logic [63:0] venv /*verilator public_flat_rd*/;
    // These fields share every write/read address and enable, including GC
    // and FOREACH. Pack one28-bit word without changing the read latency.
    (* ram_style = "block" *) logic [28:0] vframe_control [0:CSTK-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vframe_this [0:CSTK-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vframe_env [0:CSTK-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vframe_fn [0:CSTK-1] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] vframe_ctor [0:CSTK-1] /*verilator public_flat_rd*/;
    // MAKE_FN in this activation captured venv; RET must not recycle it.
    logic vframe_escaped [0:CSTK-1];
    // 17-bit entries: every enqueued word is a NaN-boxed heap ref
    // ({16'h7ff9, kind[47:44], idx[12:0]}); pop rebuilds the full word.
    (* ram_style = "block" *) logic [16:0] vgc_queue [0:MAX_OBJ+MAX_ARR+ENV_DEPTH-1];
    logic [13:0] vgc_qr_ff, vgc_qw_ff, vgc_clear_i_ff;
    logic [13:0] vgc_qr /*verilator public_flat_rd*/, vgc_qw /*verilator public_flat_rd*/, vgc_clear_i;
    logic [12:0] vgc_obj_i;
    logic [11:0] vgc_arr_i;
    logic [7:0] vgc_slot_i;
    logic [63:0] vgc_cur;
    logic [11:0] vgc_root_i;
    logic [13:0] valloc_i_ff;
    logic [13:0] valloc_i /*verilator public_flat_rd*/;
    logic [13:0] vobj_next, varr_next, vfn_next;
    logic [9:0] venv_next;
    logic [1:0] valloc_kind_ff;
    logic [1:0] valloc_kind /*verilator public_flat_rd*/;
    logic valloc_retried_ff;
    logic valloc_retried /*verilator public_flat_rd*/;
    logic vgc_halt_after_ff;
    logic vgc_halt_after;
    // C4: a forced (alloc-retry) GC already collected this
    // frame; the scheduled frame-end GC is then pure re-walk of the
    // same heap (~24% of an old PACMAN frame ran 4 GCs). Scheduling
    // only: forced GCs still fire on pressure. Set at the four forced
    // entries, consumed+cleared at the S_FB_SYNC frame-end decision.
    logic gc_ran_this_frame;
    logic [1:0] gc_frame_age;
    (* ram_style = "distributed" *) logic venv_mark [0:ENV_PHYS-1];
    logic [9:0] vgc_env_i;
    logic [2:0] vgc_root_phase;
    logic vcall_value_ff;
    logic vcall_value /*verilator public_flat_rd*/;
    logic [15:0] vcall_entry_ff;
    logic [15:0] vcall_entry /*verilator public_flat_rd*/;
    logic [11:0] vcall_argc_ff;
    logic [11:0] vcall_argc;
    // CALL_METH / NEW_OBJ ctor: bind this + constructor_value like PYTHON.
    logic vcall_set_this_ff;
    logic vcall_set_this;
    logic [63:0] vcall_this_ff;
    logic [63:0] vcall_this;
    logic [63:0] vcall_ctor_val_ff;
    logic [63:0] vcall_ctor_val /*verilator public_flat_rd*/;
    // PYTHON builtin objects (ELEMENT/CONTEXT/IMAGE) + listener/key dispatch.
    logic [3:0] vobj_builtin [0:OBJ_PHYS-1] /*verilator public_flat_rd*/;
    logic [2:0] vnat_dom_ff;
    logic [2:0] vnat_dom;
    logic [63:0] vnat_style;
    // PYTHON measureText {width} — one reused object.
    logic [63:0] vmetrics;
    logic        valloc_metrics_ff;
    logic        valloc_metrics;
    logic [31:0] vmetrics_w;
    logic [63:0] vkev_event;
    logic vmouse_active;
    logic [47:0] vmouse_packet;
    logic [3:0] vmouse_prop, vmouse_slot;
    logic [15:0] vmouse_type_id;
    logic [15:0] id_mousemove, id_mousedown, id_mouseup;
    logic [15:0] id_clientX, id_clientY, id_offsetX, id_offsetY;
    logic [15:0] id_mouse_x, id_mouse_y, id_buttons, id_button, id_movementX, id_movementY;
    logic [15:0] mouse_input_type;
    always_comb case (mouse_evt_data[47:46])
        0: mouse_input_type = id_mousemove;
        1: mouse_input_type = id_mousedown;
        2: mouse_input_type = id_mouseup;
        default: mouse_input_type = id_click;
    endcase
    logic        vkey_custom;    // dispatchEvent scan: resume program, no kev pop
    logic [63:0] vkey_want_ev;   // dispatchEvent: event type string handle
    logic [15:0] vkey_ret_ip;    // dispatchEvent: program resume ip
    logic [11:0] vkey_ret_sp;    // dispatchEvent: program resume vsp
    logic [63:0] vlistener_ev [0:15] /*verilator public_flat_rd*/;
    logic [63:0] vlistener_fn [0:15] /*verilator public_flat_rd*/;
    logic [4:0] vlistener_n_ff;
    logic [4:0] vlistener_n /*verilator public_flat_rd*/;
    logic [4:0] vkey_li;
    logic v64_frame_armed;
    logic vcallback_key, vcallback_fe /*verilator public_flat_rd*/;
    logic [63:0] vfe_arr, vfe_fn;
    logic [7:0] vfe_i;
    logic [15:0] vfe_ret;
    // forEach completion must not share vnat_base with fillRect/getContext
    // inside the callback (that left two extras on animate's RET_VAL).
    logic [11:0] vfe_base;
    // Nested forEach (grids.forEach → invaders.forEach → projectiles.forEach).
    logic [63:0] vfe_arr_s [0:7];
    logic [63:0] vfe_fn_s [0:7];
    logic [7:0] vfe_i_s [0:7];
    logic [15:0] vfe_ret_s [0:7];
    logic [11:0] vfe_base_s [0:7];
    logic [3:0] vfe_sp;
    // 0=forEach 1=Array.find 2=Array.map 3=Array.filter
    logic [1:0] vfe_mode;
    logic [1:0] vfe_mode_s [0:7];
    logic [63:0] vfe_map;
    logic [63:0] vfe_map_s [0:7];
    // Length latched from varr_len_rdata on FOREACH pin (CALL_METHOD raddr).
    // Combo varr_len[vfe_arr[11:0]] / varr_valid[] in the unique case is a
    // BRAM mux that reads 0, so FOREACH took the done path with i>=0.
    logic [7:0] vfe_len;
    // Coherent asynchronous Value64 subset: rAF and timer queues use stable
    // function handles and explicit callback frames. Listener/key dispatch
    // remains an unsupported native surface until its event objects land.
    logic [63:0] vraf [0:7] /*verilator public_flat_rd*/;
    logic [3:0] vraf_n_ff /*verilator public_flat_rd*/;
    logic [3:0] vraf_n /*verilator public_flat_rd*/;
    logic [63:0] vraf_snap [0:7];
    logic [3:0] vraf_snap_n /*verilator public_flat_rd*/;
    logic [3:0] vraf_i /*verilator public_flat_rd*/;
    logic vtimer_valid [0:63] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic signed [31:0] vtimer_due [0:63] /*verilator public_flat_rd*/;
    logic signed [31:0] vtimer_id [0:63] /*verilator public_flat_rd*/;
    logic signed [63:0] vtimer_period [0:63] /*verilator public_flat_rd*/;
    logic [63:0] vtimer_fn [0:63] /*verilator public_flat_rd*/;
    logic [6:0] vtimer_n /*verilator public_flat_rd*/;
    logic [31:0] vframe_no /*verilator public_flat_rd*/;
    logic [31:0] vtimer_seq /*verilator public_flat_rd*/;
    logic [31:0] vrng;
    logic [8:0] vconsole_n;
    logic [6:0] vtimer_pick;
    logic vcallback_raf, vcallback_timer;
    logic vgc_wait_after_ff;
    logic vgc_wait_after;
    // After a mid-op collect, resume the caller instead of S_V64_ALLOC.
    // 0=alloc retry  1=re-fetch current op (map/filter dest)  2=JSON.parse
    // 3=JSON.stringify result object.
    logic [1:0] vgc_resume;
    logic [11:0] vnat_base_ff;
    logic [11:0] vnat_base;
    // Sequential find-free (S_FREE_OBJ / S_FREE_ARR) — no MAX_* combo mux.
    logic vfree_armed, vfree_ok;
    logic vfree_arr_long;
    
    // Sequential vstack copy/shift (S_V64_BIND).
    logic [1:0]  bind_mode /*verilator public_flat_rd*/;
    logic [7:0]  bind_k /*verilator public_flat_rd*/; logic [7:0] bind_n /*verilator public_flat_rd*/; logic [7:0] bind_argc;
    logic [11:0] bind_base, bind_src, bind_vsp_next;
    logic [15:0] bind_ip /*verilator public_flat_rd*/;
    logic [63:0] bind_ins;
    logic        bind_armed, bind_rd_arm /*verilator public_flat_rd*/;
    // Sticky: CTOR_ENV intern path (not combo NEW_OBJ&&bind_ins). BIND
    // then ALLOC kind 3 must still see a FUNCTION callee (PACMAN Stage).
    logic        intern_ctor_hold;
    // Latched while CTOR_ENV/VARS muxes hp_rval (tfn_rd_arm). ALLOC kind 3
    // re-sample of vfn_entry_rdata was createStage+4 on the title (PACMAN
    // LOAD_VAR stage eip=1720, Stage frame still live, venvi invalid).
    logic [15:0] intern_ctor_entry;
    logic [5:0]  intern_ctor_nparam;
    logic [2:0]  intern_ctor_flags;
    logic [63:0] intern_ctor_env;
    // Math.min/max one arg per clock (not a 256-wide vstack mux).
    logic        minmax_is_min;
    logic [7:0]  minmax_k, minmax_n;
    logic [11:0] minmax_base;
    logic [63:0] minmax_acc;
    logic [18:0] vdraw_i_ff;
    logic [18:0] vdraw_i;
    logic [9:0] vdraw_x_ff, vdraw_y_ff, vdraw_w_ff, vdraw_h_ff;
    logic [9:0] vdraw_x, vdraw_y, vdraw_w, vdraw_h;
    // Scan cursor so S_V64_RECT is adders, not /% per pixel (Verilator
    // combo divide made full-canvas fillRect feel frozen-slow).
    logic [9:0] vdraw_cx, vdraw_cy;
    // S_V64_RECT_LD: one SRAM beat per fillRect arg (addr, then vst_rdata).
    logic        rect_ld_arm;
    logic [1:0]  rect_ld_k;
    logic signed [47:0] rect_origin_x, rect_origin_y;
    logic signed [47:0] rect_scaled_q;
    logic rect_extent_positive_q;
    logic [7:0] vdraw_color_ff;
    logic [7:0] vdraw_color;
    // Slot SRAM must fit leftover T200 BRAM after dual 640×480 FB (~0.6 MB)
    // of ~1.64 MB total: leftover ~1 MB for code + heap + console. Overflow
    // loud. Same numbers in hardware_model/js_vm.py. Not title-sized.
    // PACMAN's attract-mode ghost tick (4x JSON.parse maze + BFS in one frame)
    // bursts ~330 objects over ~570 steady live: 896 faults, 960 does not.
    // 960 is safe as a non-pow2 LOGICAL cap because every side array keeps
    // OBJ_PHYS=1024 physical rows (see below) and the slot array is
    // claim-bounded.
    localparam int MAX_OBJ = 960;
    // The fn bank (vfn_*) shares this cap. Handle-range checks all compare against MAX_OBJ.
    //
    // PHYSICAL vs LOGICAL depth: the small per-handle
    // side arrays are written through FIXED-WIDTH bit slices ([9:0] obj,
    // [8:0] env, [6:0] long-arr) at the exec-write block and pokes. When the
    // caps were 1024/512/128 the slice width EQUALLED the array depth, so a
    // stray high index was architecturally in-bounds. After the cap shrink a
    // sliced write above the cap became an OUT-OF-BOUNDS write in the
    // Verilated model (INVADERS lost bunker cell #32 of every bunker after
    // the first - adjacent-state corruption at the S_ARR_PROMOTE boundary).
    // The side arrays therefore keep 2^slice-width PHYSICAL depth; the
    // LOGICAL caps above still bound allocation (and the BRAM-heavy slot
    // arrays, whose addresses are computed from claim-bounded values, keep
    // their shrunk sizes). Rows above the cap are inert: no scan reads them.
    localparam int OBJ_PHYS  = 1024; // 2^10 - e64/poke write slices are [9:0]
    localparam int ENV_PHYS  = 512;  // 2^9  - write slices are [8:0]
    localparam int LONG_PHYS = 128;  // 2^7  - write slices are [6:0]
    localparam int OBJ_RING = MAX_OBJ / 2; // wrap point: boot heap stays below
    localparam int OBJ_SLOTS = 32; // property slots per object (Object.assign)
    // Two-tier arrays, same total bits as 512×128: short 1024×32 (nested
    // number-array maps / JSON clones) plus long 256×128 (push past 32).
    // Handle stays put on promote (varr_long + varr_lidx). Overflow loud.
    // Same 65536 × 64b words as 1024×32+256×128 (leftover BRAM). More short
    // handles for nested map + JSON clones; long bank still covers push>32.
    localparam int MAX_ARR_SHORT = 1536;
    localparam int ARR_SHORT_CAP = 32;
    // Measured long-array (len>32) peak in play is 2; INVADERS bunkers use 4.
    // LONG_PHYS stays 128.
    localparam int MAX_ARR_LONG = 12;
    localparam int MAX_ARR = MAX_ARR_SHORT + MAX_ARR_LONG;
    localparam int ARR_RING = MAX_ARR / 2;
    // Per-call lexical env (FM bytecode.py env dict). LIFO frames;
    // MAKE_FN snapshots the current frame onto the Fn heap object so
    // setTimeout/rAF closures keep forEach params after the call returns.
    // Slot SRAM is 1-D venv_slot (Synth 8-4556 was 2-D venv_val). Same
    // ENV_DEPTH in hardware_model/js_vm.py. Overflow loud.
    // PACMAN's recursive BFS transiently holds ~300 live envs; at 256 they
    // were recycled mid-recursion. 384 is clean.
    localparam int ENV_DEPTH = 384;
    localparam int TAGGED_ENV_DEPTH = 32;
    localparam int ENV_SLOTS = 16;
    // Finite general timer queue. A legal JS loop can have one pending timeout
    // per frame until an older delay expires, so eight entries was not viable.
    localparam int TIMER_DEPTH = 64;
    localparam logic [15:0] CLS_FN = 16'hFFEF;
    localparam logic [15:0] CLS_REGEX = 16'hFFEE;  // packed pattern+flags in slot0
    localparam logic [15:0] CLS_DYNSTR = 16'hFFED; // JSON/replace text in json_mem
    localparam logic [15:0] CLS_IMGD = 16'hFFEC;   // one ImageData snapshot (VM cap)
    localparam logic [15:0] CLS_ENV = 16'hFFEA;    // live lexical env (FM env dict)
    localparam int JSON_CAP = 8192; // VM-capped scratch; loud overflow, not title-sized
    localparam int JSON_STK = 32;
    localparam int ARR_CAP = 128;
    // 1-D slot SRAM: two-tier concat, not MAX_ARR×ARR_CAP (that would be
    // 1280×128). Short aid*32+slot with aid[10:0] (0..1535); long
    // VARR_SHORT_WORDS+lidx*128+slot. aid[9:0] aliased 1024..1535 onto
    // 0..511 (PACMAN map[0].length undefined at arr>1024 → finder 241).
    // Object slot field is 5 bits (OBJ_SLOTS=32). Array slot field is
    // 7 bits (ARR_CAP=128). Same memories for tagged and Value64
    // (tagged val is the low 32 bits).
    localparam int VOBJ_WORDS = MAX_OBJ * OBJ_SLOTS;
    localparam int VARR_SHORT_WORDS = MAX_ARR_SHORT * ARR_SHORT_CAP;
    localparam int VARR_WORDS = VARR_SHORT_WORDS + MAX_ARR_LONG * ARR_CAP;
    localparam int VENV_WORDS = ENV_DEPTH * ENV_SLOTS;
    localparam int VOBJ_AW = $clog2(VOBJ_WORDS);
    localparam int VARR_AW = $clog2(VARR_WORDS);
    localparam int VENV_AW = $clog2(VENV_WORDS);
    // 3, was 8. With no rewind during the grace window, 8 frames of
    // per-frame temps got baked into the kept region when the watermark
    // snapshots (PACMAN sat at obj=3263), leaving too little nursery headroom —
    // a frame then allocated over its own live rAF Fn object, so the dispatcher
    // ran a stale function that never re-armed and the game froze on its first
    // drawn frame (raf=0). 3 still covers the boot rAF/click/nextStage chain.
    localparam int ARR_KEEP_DELAY = 3; // boot rAF/click/nextStage before nursery
    localparam int MAX_CLS = 16;
    localparam int MAX_CMETH = 16;
    localparam int CSTK = 128;

    /* ===== LIVE OBSERVABILITY (board debugging, zero-cost) =====
       Everything here is observation-only: dedicated async read ports on
       the valid LUTRAMs (pure fanout — the hot muxes are untouched), a
       free-running background scanner, and shadow latches on the
       machine_fault edge. No execution path reads, waits on, or gates
       against any of it; the no-slowdown proof is a digit-identical
       fclk/STATEHIST profile. Serialized by jmr_uart_link as H/F/T
       lines (see ARCH_MONITOR.md BOARD section). */
    logic [10:0] scn_i;          // walks 0..2047 (covers every pool)
    logic [10:0] scn_obj_acc, scn_arr_acc, scn_env_acc;
    logic [10:0] dbg_obj_live /*verilator public_flat_rd*/;
    logic [10:0] dbg_arr_live /*verilator public_flat_rd*/;
    logic [10:0] dbg_env_live /*verilator public_flat_rd*/;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            scn_i <= '0;
            scn_obj_acc <= '0; scn_arr_acc <= '0; scn_env_acc <= '0;
            dbg_obj_live <= '0; dbg_arr_live <= '0; dbg_env_live <= '0;
        end else begin
            scn_i <= scn_i + 11'd1;
            if (scn_i == 11'd2047) begin
                dbg_obj_live <= scn_obj_acc; dbg_arr_live <= scn_arr_acc;
                dbg_env_live <= scn_env_acc;
                scn_obj_acc <= '0; scn_arr_acc <= '0; scn_env_acc <= '0;
            end else begin
                if (scn_i < 11'(OBJ_PHYS) && vobj_alloc[scn_i[9:0]] == 2'd1)
                    scn_obj_acc <= scn_obj_acc + 11'd1;
                if (scn_i < 11'(MAX_ARR) && varr_valid[scn_i])
                    scn_arr_acc <= scn_arr_acc + 11'd1;
                if (scn_i < 11'(ENV_PHYS) && venv_valid[scn_i[8:0]])
                    scn_env_acc <= scn_env_acc + 11'd1;
            end
        end
    end
    // committed-ip ring (last 8), frozen the moment machine_fault rises
    logic [15:0] ipring [0:7] /*verilator public_flat_rd*/;
    logic [2:0]  ipring_w;
    logic [15:0] ipring_prev;
    // fault snapshot (latched once per fault edge)
    logic        fsnap_v /*verilator public_flat_rd*/;
    logic [31:0] fsnap /*verilator public_flat_rd*/;   // {kind2,retr1,state7,vcsp8,vsp12,2'b0}
    logic [31:0] fsnap_pools /*verilator public_flat_rd*/; // {2'b0,obj10,arr10,env10}
    logic        mf_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ipring_w <= '0; ipring_prev <= 16'hFFFF;
            fsnap_v <= 1'b0; fsnap <= '0; fsnap_pools <= '0; mf_q <= 1'b0;
        end else begin
            mf_q <= machine_fault;
            if (!machine_fault && ip != ipring_prev) begin
                ipring[ipring_w] <= ip;
                ipring_prev <= ip;
                ipring_w <= ipring_w + 3'd1;
            end
            if (machine_fault && !mf_q) begin
                fsnap_v <= 1'b1;
                fsnap <= {valloc_kind, valloc_retried, state, vcsp, vsp, 2'b00};
                fsnap_pools <= {dbg_env_live[9:0], dbg_arr_live, dbg_obj_live};
            end
            if (!machine_fault) fsnap_v <= 1'b0;
        end
    end
    assign vm_hdbg = {dbg_env_live[9:0], dbg_arr_live, dbg_obj_live};
    assign vm_fdbg = fsnap;
    assign vm_fdbg_v = fsnap_v;
    assign vm_gdbg = {fault_site, e64_fault_arg_q};
    assign vm_ftrace = {ipring[7], ipring[6], ipring[5], ipring[4],
                        ipring[3], ipring[2], ipring[1], ipring[0]};
    logic [15:0] n_obj /*verilator public_flat_rd*/, n_arr /*verilator public_flat_rd*/;
    logic [15:0] n_arr_keep;
    logic        arr_keep_ok;
    logic [3:0]  arr_keep_wait;
    // Per-frame object bump rewind (call envs / temps). Same policy as
    // arrays: do not wrap live slots; commit keep when a nursery obj/fn is
    // stored into the pre-frame heap or a timer/rAF queue.
    logic [15:0] n_obj_keep /*verilator public_flat_rd*/; // Debug peek (bring-up)
    logic        obj_keep_ok;
    logic [3:0]  obj_keep_wait;
    logic        frame_fire /*verilator public_flat_rd*/; // fire rAF/keys after GC or input
    // Public for the sim OBJPEEK probe (bring-up visibility only)
    // 1-D Fn metadata (not a slot mux). MAKE_FN writes these + SRAM via OSETI.
    logic [15:0] dbg_gc_n /*verilator public_flat_rd*/;
    logic [15:0] cls_name [0:MAX_CLS-1];
    logic [15:0] cls_ctor [0:MAX_CLS-1];
    logic [4:0]  cls_nmeth[0:MAX_CLS-1];
    // Flattened {class,method} tables in LUTRAM; the method scan walks
    // them one entry per beat (pipelined read), replacing the one-beat
    // 256-way comparator forest. cls_name/cls_ctor/cls_nmeth stay FFs
    // for the comb class find (tiny).
    (* ram_style = "distributed" *) logic [15:0] cls_mname [0:MAX_CLS*MAX_CMETH-1];
    (* ram_style = "distributed" *) logic [15:0] cls_mip   [0:MAX_CLS*MAX_CMETH-1];
    logic [7:0]  clsm_raddr;
    logic [15:0] clsm_name_rd, clsm_ip_rd;
    logic        cmn_we, cmi_we;
    logic [7:0]  cmn_wa, cmi_wa;
    logic [15:0] cmn_wd, cmi_wd;
    logic        cls_seq, cls_prime;
    // Class table scan: one (c) or (c,m) per clock. unique case must not CAM.
    logic cls_scan, cls_armed, cls_done, cls_ctor_mode, cls_hit;
    // exec method-lookup service: exec raises cm_req (level) with key/cls;
    // the sequential scanner runs ctor_mode=0 and the result pulses back.
    logic        e64_cm_req;
    logic [15:0] e64_cm_key, e64_cm_cls;
    logic        cm_serving, cm_served_hold, cm_res_we;
    logic [15:0] cm_res_mip;
    // exec listener-op service (add/remove): sequential walk over the
    // SINGLE parent table; result is a held level (the cm lesson).
    logic        e64_lsv_req;
    logic [1:0]  e64_lsv_op;
    logic [63:0] e64_lsv_ev, e64_lsv_fn;
    logic        lsv_serving /*verilator public_flat_rd*/, lsv_served_hold, lsv_res_we /*verilator public_flat_rd*/, lsv_arm;
    logic [2:0]  lsv_res;
    logic [4:0]  lsv_res_n_out;
    logic [4:0]  lsv_k, lsv_w, lsv_same;
    logic        lsv_dup;
    logic [3:0] cls_c, cls_m;
    logic [2:0] callref_phase;
    logic callref_pending;
    logic [15:0] cls_cls, cls_key, cls_ctor_q, cls_mip_q, cls_gip_q;
    logic [4:0]  n_cls;
    logic [6:0]  csp /*verilator public_flat_rd*/;
    logic [15:0] dbg_heap_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_to_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_stack_ovf /*verilator public_flat_rd*/;
    logic [15:0] dbg_call_ovf /*verilator public_flat_rd*/;
    logic        machine_fault /*verilator public_flat_rd*/;
    logic [15:0] fault_site /*verilator public_flat_rd*/;  // src line of the fault assignment; debug-only
    logic [7:0]  fault_code /*verilator public_flat_rd*/;
    // Timers whose queued oid no longer holds a CLS_FN at fire time.
    // Executing such a slot ran top-level code mid-game (globals reset,
    // INVADERS kill timers lost) — count and drop instead.
    logic [15:0] dbg_tmr_mis /*verilator public_flat_rd*/;
    logic [15:0] dbg_tmr_sched /*verilator public_flat_rd*/; // setTimeout accepted
    logic [15:0] dbg_tmr_fire /*verilator public_flat_rd*/;  // callbacks launched
    // Array.find hits + splice calls — play log must show whether a
    // timeout actually culled (tsch/tfire alone cannot).
    logic [15:0] dbg_find_hit /*verilator public_flat_rd*/;
    logic [15:0] dbg_splice_n /*verilator public_flat_rd*/;
    // Slow-path S_DIV entries (not the 1-cycle /2 shift). Play logs
    // show whether a frame is still paying 48 clocks per `width/2`.
    logic [15:0] dbg_div_n /*verilator public_flat_rd*/;
    logic [15:0] id_replace;
    // Interned string BYTES. jsb_format already writes every name as UTF-8
    // at the end of the trailer, but only PYTHON decoded it — RTL kept a hash +
    // length and no characters, so str[i] was undefined and str.length was
    // undefined too. Any string-row sprite therefore drew nothing (INVADERS
    // drawBitmap walks row[col] === "1"), while fillRect/drawImage art painted.
    // On-chip BRAM with a registered read: one-cycle random access on FPGA and
    // ASIC alike. The 4 MB external bank stays for art, never for code strings.
    localparam int NAME_CAP = 16384; // measured peak 3,644 bytes (PACMAN); 4.5x headroom, loud refuse past cap
    // UG901 RAM_STYLE=block (not a heuristic). Read process below matches
    // simple_dual_one_clock.v — not the 40-array mux.
    (* ram_style = "block" *) logic [7:0]  name_mem [0:NAME_CAP-1] /*verilator public_flat_rd*/;
    logic        name_we;
    logic [14:0] name_waddr;
    logic [7:0]  name_wdata;
    // Multi-port-by-replication: 4 read sites made BRAM
    // infeasible (Synth 8-6849) and the LUTRAM cost ~384 prims of SLICEM.
    // Four mirrored copies, one per read port, half a tile each.
    (* ram_style = "block" *) logic [15:0] name_off [0:1023] /*verilator public_flat_rd*/;   // intern idx -> first byte in name_mem
    (* ram_style = "block" *) logic [15:0] name_off_r1 [0:1023];
    (* ram_style = "block" *) logic [15:0] name_off_r3 [0:1023];
    // NAMB u16 byte length. Hash-table name_len_tbl is u8 (concat fold).
    // str[i] / str.length must use this or a 624-char layout literal
    // reports length 112 (624&255) and never carves tunnels.
    (* ram_style = "block" *) logic [15:0] name_blen [0:1023] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [15:0] name_blen_r1 [0:1023];
    logic [15:0] name_rdaddr;
    logic [14:0] name_mem_raddr;
    logic [7:0]  name_rdata;          // registered read (BRAM, not a mux)
    // Sequential str[i] prefetch — next GET_IDX of i+1 hits name_rdata
    logic [15:0] str_pf_id;
    logic        str_pf_ok;
    logic [15:0] dbg_str_ovf /*verilator public_flat_rd*/; // bytes past NAME_CAP
    // Ip where the last frame-level callback returned (VMSTAT cbip)
    logic [15:0] dbg_cb_ip /*verilator public_flat_rd*/;
    // Byte -> interned idx for every 1-char name, so str[i] hands back a
    // value that OP_EQ matches against a "x" literal by intern id — one lookup,
    // no scan over the name table.
    logic [15:0] char_id [0:255] /*verilator public_flat_rd*/;
    logic        char_ok [0:255] /*verilator public_flat_rd*/;
    (* ram_style = "distributed" *) logic name_has [0:1023];   // this intern id has bytes in name_mem
    logic        names_ok;            // name bytes present AND byte-aligned
    logic [15:0] nb_i, nb_len;
    logic        nb_one;              // this name is exactly 1 byte (char lookup)
    logic [15:0] nb_wp /*verilator public_flat_rd*/; // bytes loaded (VMSTAT strb)
    // Serialized byte-string builder: provisional bytes are invisible until publication.
    logic [4:0] bs_phase;
    logic bs_arena_mode, bs_pending, bs_checked;
    logic [18:0] bs_arena_base;
    logic [11:0] bs_outer;
    logic [11:0] bs_generation;
    logic [7:0] bs_pages,bs_page,bs_bytes;
    logic [15:0] bs_byte; // Arena spans use all32768 possible input bytes.
    logic [15:0] bs_len,bs_hash,bs_scan,bs_cmp,bs_off;
    logic [7:0] bs_compare_byte;
    logic [7:0] str_byte_q; // Numeric strByte capture; shares existing STRIDX reads.
    // 8x8 glyph ROM — one BRAM, registered read, same bytes as the console
    // scanout font. fillText was a filled 64x8 bar before this; every HUD in
    // every title (not just the three) now gets the PYTHON glyphs.
    (* ram_style = "block" *) logic [7:0] font_rom [0:1023];
    initial $readmemh(FONT_HEX, font_rom);
    logic [9:0]  font_raddr;
    logic [7:0]  font_rdata;          // registered read (BRAM, not a mux)
    // Text staging buffer. Interned bytes, dynstr bytes and plain numbers
    // are all expanded here, so the glyph raster (and the string concat that
    // materialises dynamic interns) has exactly one byte source.
    localparam int TXT_MAX = 64;
    (* ram_style = "distributed" *) logic [7:0] txt_buf [0:TXT_MAX-1];
    logic [6:0]  txt_len, txt_i, txt_bn;
    logic [3:0]  txt_ph;
    logic [2:0]  txt_row, txt_col;
    logic [3:0]  txt_k, txt_kx, txt_ky; // integer glyph scale + sub-pixel repeat
    logic [7:0]  txt_bits;
    logic signed [15:0] txt_px, txt_py; // pen after ctx transform (may be off-glass)
    logic signed [15:0] txt_x0, txt_y0; // aligned top-left of the first glyph
    logic [3:0]  txt_pi;                // P10 index while expanding a number
    logic [3:0]  txt_d;                 // digit being accumulated
    logic signed [31:0] txt_v;
    logic [15:0] txt_rp;                // name_mem / json_mem read cursor
    logic [31:0] txt_val;               // the text argument itself
    logic [2:0]  txt_vt;
    logic signed [47:0] txt_kp;         // font_px x ctx_sx (scale product)
    wire signed [47:0] text_scale_rounded = (txt_kp + 48'sd262144) >>> 19;
    wire [3:0] text_font_scale = text_scale_rounded < 48'sd1 ? 4'd1 :
        text_scale_rounded > 48'sd15 ? 4'd15 : text_scale_rounded[3:0];
    logic [15:0] txt_w;                 // text width in device pixels
    logic [1:0]  ctx_align;             // ctx.textAlign 0=left 1=center 2=right
    // ctx.textAlign is written by the exec that runs SET_PROP, and the
    // parent's copy is only ever reset — so the text pen always used
    // left-align for Value64 titles (DONKEY's centred title text sat
    // off to one side). Read the live exec value, like every other
    // exec-owned scalar.
    logic [1:0]  ctx_align_eff;
    logic [7:0]  ctx_font_px;           // ctx.font "NNpx ..." size (FM default 8)
    logic [7:0]  fpx_acc;               // digits seen while parsing ctx.font
    logic [7:0]  fp_left;               // bytes left in the font string
    // JSON/text scratch (stringify/parse/replace) — VM cap, sticky ovf
    (* ram_style = "block" *) logic [7:0]  json_mem [0:JSON_CAP-1];
    logic        json_we;
    logic [12:0] json_waddr;
    logic [7:0]  json_wdata;
    logic [13:0] json_wp /*verilator public_flat_rd*/, json_rp, json_src, json_srclen, json_dst;
    logic        namcpy_repl; // S_NAMCPY then S_REPL (else S_JSON_PARSE)
    logic        namcpy_v64;  // S_NAMCPY then S_V64_JSON_PARSE
    logic        namcpy_armed; // wait 1 cycle for registered name_rdata
    logic [63:0] vjs_val [0:JSON_STK-1]; // Value64 stringify/parse walk
    logic [15:0] dbg_json_ovf /*verilator public_flat_rd*/;
    logic [7:0]  js_i   [0:JSON_STK-1];
    logic [2:0]  js_ph  [0:JSON_STK-1];
    logic [5:0]  js_sp;
    logic [2:0]  json_pph; // parse substate (0=value 3=number 7=skipstr)
    logic signed [31:0] json_num;
    logic        json_neg;
    logic [7:0]  json_digs [0:9];
    logic [3:0]  json_dn, json_di;
    logic [7:0]  repl_pat0, repl_pat1, repl_nlen, repl_rch;
    logic        repl_g, repl_did;
    logic [13:0] idx_off;
    logic [7:0]  idx_needle;
    // One ImageData snapshot (FM canvas.back copy). VM cap = 1 buffer.
    // ram_style block: a 307200-entry unpacked mux in Verilator made
    // S_IMGD_GET miss its i++ NBA and spin until the 16M FRAME cap.
    // imgd_pix BRAM removed: the one ImageData snapshot now lives
    // in external SRAM words [IMGD_SRAM_BASE .. IMGD_SRAM_BASE+FB_PIXELS-1],
    // one pixel per 16-bit word (low byte). Top 600KB of the 4MB bank is
    // reserved for it - ASET art must stay below IMGD_SRAM_BASE (tools cap
    // ASET far under this; loud check lives in compile).
    localparam logic [21:0] IMGD_SRAM_BASE = 22'd3887104; // 2*1024*1024-307200
    logic [7:0] imgd_low;
    logic        imgd_pend; // one outstanding IMGD sram transfer (GET wr / PUT rd)
    logic [18:0] imgd_i /*verilator public_flat_rd*/, imgd_n /*verilator public_flat_rd*/;
    logic [9:0]  imgd_x0, imgd_y0, imgd_w /*verilator public_flat_rd*/, imgd_h /*verilator public_flat_rd*/, imgd_x, imgd_y;
    logic        imgd_armed;
    logic        imgd_v64;              // Value64 get/putImageData uses vobj not tagged n_obj
    // 16'hFFFF is the explicit JavaScript "no dynamic this" sentinel.
    // Real heap handles are below MAX_OBJ, so object 0 remains a valid receiver.
    logic [15:0] this_obj;
    logic [8:0]  var_this;   // LOAD_VAR slot for __this
    logic        this_ok;
    logic [15:0] kd_fn /*verilator public_flat_rd*/, ku_fn, click_fn; // interned MAKE_FN entries; 0xFFFF=none
    // Keydown/keyup listener table (4 slots, fire all; last-wins was a parity gap)
    logic [15:0] kd_slot [0:3], ku_slot [0:3];
    logic [2:0]  kd_n /*verilator public_flat_rd*/, ku_n /*verilator public_flat_rd*/;
    logic [1:0]  kev_li;   // which table slot is firing
    logic [15:0] kev_obj;  // event object reused for remaining listeners
    logic        kev_is_down;
    logic [15:0] kev_ret_ip; // after listener table: next op (dispatchEvent) or n_ops (KEYEVT)
    logic        boot_clr; // Clear both FB banks before first op
    logic [1:0]  boot_clr_n;
    // One index/clock parent heap wipe (S_HEAP_CLR). Do not parallel-clear
    // MAX_OBJ/MAX_ARR/ENV in S_GOT_HDR2 — that is SRAM, not FFs.
    logic        heap_clr_busy;
    logic [11:0] heap_clr_i;
    logic [15:0] id_find; // Array.find
    logic [15:0] id_findindex, id_filter; // Array.findIndex / Array.filter
    logic [15:0] id_slice; // #40 Array.slice
    logic [15:0] id_sort; // #41 Array.sort
    logic        click_fired; // HTML auto-start click once
    logic        pre_click_raf; // One rAF (Image.onload) before click
    logic [5:0]  prev_joy;
    logic [5:0]  joy_down_edge, joy_up_edge;
    logic [7:0]  fill_style_i;
    logic [7:0]  stroke_style_i; // PYTHON ctx.strokeStyle — not fillStyle
    logic [31:0] lfsr;
    // Bring-up mirrors (read-only aliases; no logic, no extra FFs).
    logic [15:0] dbg_id_keydown /*verilator public_flat_rd*/;
    logic [15:0] dbg_id_keyup /*verilator public_flat_rd*/;
    logic [15:0] id_fillrect, id_length, id_push, id_pop, id_splice, id_foreach;
    logic [15:0] id_map, id_unshift; // Array.map / Array.unshift
    logic [15:0] id_getctx, id_click, id_ael, id_key, id_keycode;
    logic [15:0] id_charcode;
    logic [7:0] kev_chars [0:31];
    logic [15:0] id_rel, id_disp; // removeEventListener / dispatchEvent
    logic [15:0] id_arrow_l, id_arrow_r, id_space, id_a, id_d, id_keydown, id_keyup;
    // DONKEY drives WASD + pause. Without these,
    // e.key is undefined for w/s/p and the handler's === test never matches.
    logic [15:0] id_w, id_s, id_p;
    // E.key for the vertical arrows. Without these the Up/Down keyCode
    // arrived with event.key = "ArrowLeft" (the old ternary default), so a
    // `switch (e.key)` game turned left on every vertical press.
    logic [15:0] id_arrow_u, id_arrow_d;
    logic [15:0] id_reduce, id_draw, id_update, id_fillstyle, id_clearrect;
    logic [15:0] id_drawimage /*verilator public_flat_rd*/;
    logic [15:0] id_this_name, id_black, id_white, id_red, id_yellow, id_cyan, id_gold;
    logic [15:0] id_src, id_onload, id_width, id_height;
    logic [15:0] id_style; // nested canvas.style for GET_PROP/SET_PROP
    logic [15:0] id_hex_fff, id_hex_3f6, id_hex_f5a, id_hex_fc0, id_hex_2ec, id_hex_000;
    logic [15:0] id_save, id_restore, id_translate, id_rotate;
    logic [15:0] id_settransform; // Ctx.setTransform(a,b,c,d,e,f)
    logic [15:0] id_assign, id_bind, id_proto, id_filltext, id_arc, id_enter;
    // Text state — ctx.font px size, ctx.textAlign and its two non-left
    // values, plus measureText (games right-align HUD text with its width)
    logic [15:0] id_font, id_textalign, id_center, id_right, id_measuretext;
    logic [15:0] id_textbaseline, id_top, id_middle, id_bottom; // #37
    logic [175:0] id_sys_window;
    logic [63:0] fs_arg_value;
    logic [2:0] fs_phase;
    logic [31:0] fs_result_q;
    (* ASYNC_REG="TRUE" *) logic [1:0] fs_reply_sync;
    always_ff @(posedge clk)begin
        if(!rst_n)fs_reply_sync<=0;else fs_reply_sync<={fs_reply_sync[0],fs_reply};
    end
    logic [2:0] ui_prop_phase;
    logic [9:0] ui_prop_name;
    logic [15:0] ui_prop_ptr,ui_prop_len,ui_prop_i;
    logic ui_prop_menu,ui_prop_title;
    logic [1:0] e64_ctx_baseline_q;
    logic [15:0] id_imgsmooth; // ctx.imageSmoothingEnabled (hash 54440)
    logic        ctx_smooth;   // 1 default; indexed blit is always nearest
    // DOM event ctors — PYTHON NEW_OBJ copies (type, options) so
    // `new KeyboardEvent("keydown", {key:"Enter",...})` has e.key (DONKEY boot)
    logic [15:0] id_kbevent, id_domevent, id_customev, id_mouseev, id_type;
    logic [15:0] id_now, id_gettime;
    logic [15:0] id_beginpath, id_fill, id_stroke, id_moveto, id_lineto, id_closepath, id_strokestyle;
    logic [15:0] id_quadcurve; // Ctx.quadraticCurveTo (PACMAN maze/ghost skirts)
    // GetImageData/putImageData — must NOT hit the fillRect argc-4
    // fallback (getImageData(0,0,640,480) painted a full-screen rect with the
    // stale wall strokeStyle: the PACMAN purple flood)
    logic [15:0] id_getimgdata, id_putimgdata;
    // Typeof result intern ids (jsb_format._name_hash of the JS strings)
    logic [15:0] id_str_undef, id_str_number, id_str_string, id_str_object, id_str_function, id_str_boolean;
    // Math.sqrt bit-serial regs — radicand Q32.32-ish (val<<16), 24-bit root
    logic [47:0] sq_rad;
    logic [25:0] sq_rem;
    logic [23:0] sq_root;
    logic [4:0]  sq_i;
    // Array.join('') + indexOf — PACMAN maze wall-shape switch does
    // neighbors.join('') == '1100'. join hashes the digits with the SAME
    // u16 hash the encoder used, then maps back to an interned name so
    // string EQ (intern id compare) just works. No dynamic string heap.
    logic [15:0] id_join, id_indexof;
    (* ram_style = "block" *) logic [15:0] name_hash_tbl [0:1023] /*verilator public_flat_rd*/; // intern idx -> encoder u16 hash
    logic        name_hash_we;
    logic [9:0]  name_hash_waddr;
    logic [15:0] name_hash_wdata;
    // Exact immutable-span concatenation. No scratch byte RAM: source strings
    // remain interned until reload; only publish a new row after copying bytes.
    logic cx_active;
    logic [4:0] cx_phase;
    logic [15:0] cx_aoff,cx_boff,cx_alen,cx_blen,cx_len,cx_pos,cx_hash,cx_scan,cx_off,cx_result;
    logic [7:0] cx_byte;
    wire [9:0] cx_meta = cx_phase < 2 ? cc_av[9:0] : cx_phase < 4 ? cc_bv[9:0] : cx_scan[9:0];
    wire [15:0] cx_source = cx_pos < cx_alen ? cx_aoff+cx_pos : cx_boff+(cx_pos-cx_alen);
    logic [9:0]  name_hash_raddr;
    (* ram_style = "block" *) logic [7:0]  name_len_tbl  [0:1023] /*verilator public_flat_rd*/; // intern idx -> byte length (concat fold)
    logic [15:0] names_n /*verilator public_flat_rd*/;
    // End of the trailer-loaded (static) names, and the byte pointer at
    // that moment. Strings built at run time (`"SCORE " + score`) intern
    // above this and are never reclaimed, so the 1024-slot table filled
    // after a few hundred frames and every later intern degraded. Recycle
    // the dynamic region as a ring instead of exhausting it: per-frame HUD
    // strings are rebuilt every frame, so an old one going stale is fine,
    // while the static names the program compares against are untouched.
    logic [15:0] names_static;
    logic [15:0] nb_static;
    logic [11:0]  jn_arr;
    logic [15:0] jn_i, jn_h;
    logic [7:0]  jn_len;
    // Last-4 intern FIND cache (VM-wide). One Port-A probe/clock via jn_i;
    // not a CAM in unique case. CONCAT/JOIN enter FIND with state already
    // FIND, so the overlay beat never plants — plant on !jn_cache_try.
    logic [15:0] jn_hit_h0, jn_hit_h1, jn_hit_h2, jn_hit_h3;
    logic [7:0]  jn_hit_l0, jn_hit_l1, jn_hit_l2, jn_hit_l3;
    logic [15:0] jn_hit_i0, jn_hit_i1, jn_hit_i2, jn_hit_i3;
    logic [3:0]  jn_hit_v;
    logic [2:0]  jn_cache_i;  // 0..3 = probe slot, 4 = linear scan this visit
    logic        jn_cache_try;
    logic [10:0] jn_res;
    logic signed [31:0] idx_v;
    logic [2:0]  idx_t;
    logic [15:0] dbg_join_miss /*verilator public_flat_rd*/; // unsupported join/indexOf shapes
    // Path bring-up latch — first 16 transformed S_PDO commands
    logic [79:0] dbg_pdo [0:15] /*verilator public_flat_rd*/;
    logic [4:0]  dbg_pdo_n /*verilator public_flat_rw*/; // rw: probe re-arms it
    // Rect bring-up latch — {color, rx, ry, rw, rh} of first 16 rects
    logic [51:0] dbg_rect [0:63] /*verilator public_flat_rd*/;
    logic [6:0]  dbg_rect_n /*verilator public_flat_rw*/;
    logic [9:0]  dbg_last_y;
    logic [7:0]  dbg_last_c;
    logic [15:0] dbg_swap_n /*verilator public_flat_rd*/; // presents since RUN
    // Raster px counters (flood hunt) — cleared by PDOCLR
    logic [31:0] dbg_line_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_circ_px /*verilator public_flat_rw*/;
    logic [31:0] dbg_rect_px /*verilator public_flat_rw*/;
    // Bring-up: key dispatch visibility (FRAME_KEY entries vs callbacks).
    logic [15:0] dbg_key_scan /*verilator public_flat_rw*/;
    logic [15:0] dbg_key_call /*verilator public_flat_rw*/;
    logic [15:0] dbg_key_alloc /*verilator public_flat_rw*/;
    logic [63:0] dbg_key_want /*verilator public_flat_rd*/;
    logic [63:0] dbg_key_lastev /*verilator public_flat_rd*/;
    logic [15:0] dbg_key_cmp /*verilator public_flat_rw*/;
    logic [7:0]  dbg_bad_state /*verilator public_flat_rd*/;
    logic [1:0]  dbg_align /*verilator public_flat_rd*/;
    logic [15:0] dbg_evkey /*verilator public_flat_rd*/;   // id planted as event.key
    logic [15:0] dbg_txtw  /*verilator public_flat_rd*/;   // last fillText pen width
    logic [15:0] dbg_txt_n /*verilator public_flat_rw*/;   // fillText calls
    // A fillText whose intern has no bytes is an unrenderable STRING,
    // not a full table. It used to bump dbg_str_ovf, which the global
    // fault sweep turns into fault 5 and halts the VM — so one HUD
    // draw of `"SCORE " + score` could kill the machine mid-game.
    // Count it loudly on its own counter and keep running.
    logic [15:0] dbg_txt_miss /*verilator public_flat_rw*/;
    // rAF dispatches vs frame ends: if these diverge, the frame loop is
    // re-dispatching callbacks instead of finishing the frame.
    logic [15:0] dbg_raf_call /*verilator public_flat_rw*/;
    logic [15:0] dbg_frame_end /*verilator public_flat_rw*/;
    // String concat ('s'+_index etc.) — operand stash + digit fold
    logic signed [31:0] cc_av, cc_bv, cc_v;
    logic [2:0]  cc_at, cc_bt, cc_t;
    logic        cc_second;
    logic [1:0]  cc_st;   // 0=classify 1=digit fold 2=copy operand bytes
    logic [15:0] cc_h;
    logic [7:0]  cc_len;
    logic [3:0]  cc_pi, cc_d;
    // The joined string also gets real BYTES (staged in txt_buf, then
    // written into name_mem when the intern is allocated). Without this a
    // concat was hash-only, so "SCORE " + n had a length but no characters
    // and fillText / str[i] / .length could not see it.
    logic [15:0] cc_cp;   // name_mem read cursor for a string operand
    logic [7:0]  cc_cn;   // bytes still to copy
    logic        cc_bok;  // every operand's bytes made it into txt_buf
    // Value64 string + reuses S_CONCAT / S_JOIN_FIND; write vstack not stack.
    logic        v64_concat;
    logic        v64_join; // arr.join('') writeback via S_JOIN_FIND → vstack
    logic        v64_sqrt; // Math.sqrt writeback via S_SQRT → vstack
    // Date.now / performance.now GET_PROP allocates a native-35 function
    // (PYTHON entry=-35). CALL_VAL sees vfn_entry 16'hfffa.
    logic        valloc_now_fn_ff;
    logic        valloc_now_fn;
    logic        valloc_regex_ff;
    logic        valloc_regex;
    // Packed pattern/flags from the const pool (same i32 as tagged CLS_REGEX).
    logic [31:0] valloc_regex_pack_ff;
    logic [31:0] valloc_regex_pack;
    // Array(n) hole count for native 34 (PYTHON length-n undefined slots).
    logic [7:0]  valloc_arr_n_ff;
    logic [7:0]  valloc_arr_n;
    // MAKE_FN entry/a1 latched at fetch. S_V64_ALLOC must not re-read
    // code_rdata — GC resume (or a JUMP-to-MAKE_FN with a skipped RET_VAL
    // a0=0 in the previous word) would store entry 0, and CALL_METHOD
    // then restarts the ProgramImage (maps IIFE nested until MAX_ARR).
    logic [15:0] valloc_fn_entry_ff;
    logic [15:0] valloc_fn_entry;
    logic [7:0]  valloc_fn_a1_ff;
    logic [7:0]  valloc_fn_a1;
    // GET_PROP .prototype on a function: alloc empty proto object (PYTHON).
    logic        valloc_proto_ff;
    logic        valloc_proto;
    logic [12:0] valloc_proto_fn_ff;
    logic [12:0] valloc_proto_fn;
    // fn.bind(this) — PYTHON copies entry/env and sets has_bound_this.
    logic        valloc_bind_ff;
    logic        valloc_bind;
    logic [12:0] valloc_bind_src_ff;
    logic [12:0] valloc_bind_src;
    logic [63:0] valloc_bind_this_ff;
    logic [63:0] valloc_bind_this;
    logic [5:0]  vctor_scan /*verilator public_flat_rd*/;
    logic        vctor_armed;
    // Class-field trampoline (compiler JUMP after param LET_VARs). Last
    // ctor LET_VAR HEAP_WR skips that JUMP so startSelect lands (DONKEY).
    logic [15:0] vctor_jmp;
    logic [5:0]  vctor_lets /*verilator public_flat_rd*/;
    logic [15:0] pow31_tbl [0:255]; // 31^i mod 2^16 (concat hash fold)
    initial begin
        pow31_tbl[0] = 16'd1;
        for (int i = 1; i < 256; i++)
            pow31_tbl[i] = 16'(32'(pow31_tbl[i - 1]) * 32'd31);
    end
    localparam int unsigned P10 [0:9] = '{1, 10, 100, 1000, 10000, 100000,
                                          1000000, 10000000, 100000000, 1000000000};
    logic [15:0] id_hex_09f, id_hex_f5f5, id_hex_ffe6, id_hex_f00, id_hex_aaa;
    logic [15:0] spr_nid [0:15] /*verilator public_flat_rd*/; // intern idx of "jmr:spr:0"..15
    // Start/stop arrive as 100 MHz latches (core) cleared on the
    // beat. Sampling them straight into the priority chain made every
    // register's CE a 10 ns cross-domain cone (WNS leader:
    // vm_stop_lat -> spr_nid CE, -0.256). One vm beat of latency on BOTH
    // keeps their relative order exactly as before.
    logic start_q, stop_q;
    always_ff @(posedge clk) begin
        start_q <= start;
        stop_q  <= stop;
    end
    // FSTY fillStyle LUT — compiler-resolved name→palette index so RTL
    // paints the exact indices the FM does (0xFF = not a color, use fallback)
    (* ram_style = "block" *) logic [7:0] fill_lut [0:1023];
    logic [15:0] fsty_n, fsty_name;
    // Pass called swapBuffers explicitly (legacy .JS) — no auto-swap
    logic        did_swap;
    // A pass (rAF/timer/key callback or top-level) finished this frame.
    // Present ONCE at the next frame tick instead of once per callback return:
    // every setTimeout callback and key listener crossed the ip>=n_ops
    // boundary and pulsed its own fb_swap, so buffers flipped mid-frame and
    // the glass interleaved two half-drawn banks (PACMAN maze mutilated on
    // keypress, INVADERS ran at half speed with vanishing draws).
    logic        present_pend;
    // A canvas is persistent: only present when this frame actually
    // drew into the back bank. Presenting unconditionally flipped a
    // title that draws once (DONKEY's title screen) to the stale
    // empty bank on the very next frame_tick — the glass went black
    // while the drawn bank sat behind it.
    logic        fb_dirty;
    // srcLen (nid 43) reads the console's src_len. That register lives in
    // the CORE clock domain while the VM runs on clk/VM_CLK_DIV, and feeding
    // it straight into exec64 put a cross-domain combinational path into the
    // vst_wdata funnel — the worst cone in the design (103 logic levels).
    // It routed at WNS -0.661 with EVERY violator on that path.
    // Two flops in the VM domain fix both problems: they break the path and
    // make the crossing a proper synchroniser. src_len is quasi-static (it
    // changes on LOAD / EDIT, never mid-compile), so the extra beat of
    // latency is invisible to the compiler reading it.
    logic [17:0] src_len_q1, src_len_q2;
    // The analog-stick natives (51/52/53) read u_i2c_joy's
    // core-clock registers straight into exec64's vst_wdata funnel —
    // 10 of the 16 misses (route 8-9 ns of a 10 ns clk->vm_clk budget).
    // Same class as src_len; same cure: two beats on vm_clk.
    logic [7:0] analog_x_q1, analog_x_q2, analog_y_q1, analog_y_q2;
    logic [4:0] joy_btn_q1, joy_btn_q2;
    logic [5:0] joy_level_q1, joy_level_q2;
    always_ff @(posedge clk) begin
        src_len_q1 <= src_len_i;
        src_len_q2 <= src_len_q1;
        analog_x_q1 <= analog_x; analog_x_q2 <= analog_x_q1;
        analog_y_q1 <= analog_y; analog_y_q2 <= analog_y_q1;
        joy_btn_q1  <= joy_btn;  joy_btn_q2  <= joy_btn_q1;
        joy_level_q1 <= joy_in; joy_level_q2 <= joy_level_q1;
    end
    logic        csr_pend;  // S_CSRAM request issued, waiting on sram_ack
    // The read byte lands in a vm_clk register at the ack and is
    // consumed the NEXT beat. Feeding sram_rdata (a clk100 register in the
    // bridge) straight into v64_int32_number -> the vst_wdata funnel gave
    // that crossing a 10 ns budget through ~100 levels: the WNS leader
    // (+0.009 / -0.077 / -0.163). One beat per CSR op.
    logic        csr_done;  // byte captured, finish next beat
    logic [7:0]  csr_rd_q;
    // S_CSRAM mode map (3 bits — was 2, widened for mode 4):
    //   0 srcByte  1 stgRead  2 stgWrite  3 artWrite2  4 srcWrite
    // WRITE modes are named explicitly rather than tested as (mode >= 2), so
    // a future READ mode above 4 cannot silently be treated as a write and
    // scribble on the framebuffer/SOURCE/WORK arenas.
    wire csr_is_write = (e64_csr_mode_q == 3'd2)
                     || (e64_csr_mode_q == 3'd3)
                     || (e64_csr_mode_q == 3'd4);
    logic        fbs_armed; // S_FB_SYNC dump-read settle beat
    // Board fix: draws must NOT race the DDR3 present. Sim measured
    // 170k clk of margin and zero fence hits — but the present's true
    // duration is SIM-INVISIBLE (bridge shared with
    // scanout). On glass, clear-first titles wiped the bank mid-copy:
    // flashing INVFAST/MISSILE/ASTEROID/FLDFAST, vanishing DNKFAST player.
    // The fence holds any fb write while a v64 frame-end present runs.
    // Boot/console presents keep their proven overlap-tolerant semantics.
    logic        fence_arm;   // set at S_FB_SYNC arm; cleared when copy ends
    logic        fence_seen;  // busy actually observed high since the arm
    logic [12:0] fence_wait;  // start-up watchdog (see below)
    // Port A write strobes (FPGA_FIT census): the FSM must not poke
    // these BRAM-attributed arrays directly (Vivado 8-7186 ignores
    // ram_style when the CPU always_ff writes them — the cause of the
    // mapping OOM). Sites set we/waddr/wdata; the read process owns
    // the single write port. Writes land one beat later; every
    // consumer reads via registered *_rdata beats later still.
    logic vgc_queue_pa_we; logic [11:0] vgc_queue_pa_waddr; logic [16:0] vgc_queue_pa_wdata;
    logic vconsts_pa_we; logic [9:0] vconsts_pa_waddr; logic [63:0] vconsts_pa_wdata;
    logic vobj_proto_pa_we; logic [12:0] vobj_proto_pa_waddr; logic [63:0] vobj_proto_pa_wdata;
    logic vfn_proto_pa_we; logic [12:0] vfn_proto_pa_waddr; logic [63:0] vfn_proto_pa_wdata;
    logic vfn_env_pa_we; logic [12:0] vfn_env_pa_waddr; logic [63:0] vfn_env_pa_wdata;
    logic vfn_bound_this_pa_we; logic [12:0] vfn_bound_this_pa_waddr; logic [63:0] vfn_bound_this_pa_wdata;
    logic venv_parent_pa_we; logic [9:0] venv_parent_pa_waddr; logic [63:0] venv_parent_pa_wdata;
    // Bring-up probes — drawImage sprite-marker hits vs misses
    logic [15:0] dbg_di_hit /*verilator public_flat_rd*/, dbg_di_miss /*verilator public_flat_rd*/;
    logic [1:0]  path_kind; // 0 none 1 arc 2 moveto 3 lineto
    logic signed [31:0] path_x0, path_y0, path_x1, path_y1, path_r;
    logic        path_stroke;
    // Multi-command path buffer (FM bytecode.py obj["_path"] twin) —
    // raw Q16.16 args recorded at dispatch, _xf transform applied at
    // fill()/stroke() raster time exactly like machine.py _raster_path.
    localparam int PATH_MAX = 16;
    logic [1:0]         pc_op  [0:PATH_MAX-1]; // 0=M 1=L 2=Q 3=A
    logic signed [31:0] pc_a1  [0:PATH_MAX-1]; // x | cx
    logic signed [31:0] pc_a2  [0:PATH_MAX-1]; // y | cy
    logic signed [31:0] pc_a3  [0:PATH_MAX-1]; // r | end x
    logic signed [31:0] pc_a4  [0:PATH_MAX-1]; // arc a0 | end y
    logic signed [31:0] pc_a5  [0:PATH_MAX-1]; // arc a1
    logic               pc_ccw [0:PATH_MAX-1];
    logic [4:0]         pc_n, pi;
    logic [15:0]        dbg_path_ovf /*verilator public_flat_rd*/; // fail-visible overflow
    logic               path_active;            // raster states return to S_PWALK
    // walk scratch (device-space ints after _xf)
    logic signed [31:0] cur_x, cur_y, p1x, p1y, p2x, p2y;
    // quadratic subdivision (FM: 8 line segments)
    logic signed [31:0] qx0, qy0, qcx, qcy, qex, qey;
    logic signed [31:0] qk1, qk2, qk3;          // u^2, u*t, t^2 (Q16.16)
    logic [3:0]         qseg;
    // arc angle sweep (per-pixel cross-product test replaces FM atan2)
    logic               arc_ang, arc_sweep_gt_pi;
    logic signed [16:0] vs_x, vs_y, ve_x, ve_y; // Q1.15 sector edge vectors
    // flatten: sin_q 256 ROM — raddr this clock, rdata next (not function peek).
    logic [15:0] sin_turn, arc_ts, arc_te;
    logic [3:0]  sin_ph;
    logic [15:0] sin_q_rdata;
    logic [7:0]  sin_raddr;
    logic [7:0]  txt_buf_rdata;
    logic [15:0] pow31_rdata;
    // signed Bresenham line (FM machine._line twin)
    logic signed [15:0] bl_x, bl_y, bl_x1, bl_y1;
    logic signed [16:0] bl_dx, bl_dy;           // dx, -dy (FM err terms)
    logic               bl_sx, bl_sy;
    logic signed [17:0] bl_err;
    logic [12:0]        bl_guard;
    localparam logic signed [31:0] FX_2PI = 32'sd411775; // 2*pi Q16.16
    localparam logic signed [31:0] FX_PI  = 32'sd205887;
    // quarter-wave sine ROM, 256 x Q1.15 (sin_q[i] = sin(i/256 * pi/2))
    logic [15:0] sin_q [0:255];
    // 262144 -> 32768: ~50 BRAM tiles back. All HTML titles are
    // aset_mode=1 (sprites blit from the external asset SRAM); spr_mem
    // only serves the .JS probe SPR1 packs, which are tiny.
    localparam int SPR_BYTES = 32768;
    // 16 ASET sprite descriptors (was 8 — silently dropped DONKEY sheets
    // beyond the clamp). obj_cls FFC0|idx encoding carries a 4-bit index;
    // compile_js.py fails loud if a title ever exceeds this.
    localparam int MAX_SPR = 16;
    localparam logic signed [31:0] FX_ONE = 32'sh0001_0000; // Q16.16 1.0
    // spr_mem moved to external SRAM (words SPR_SRAM_BASE..+32767,
    // one byte per word) - was 6k LUTRAM against the failing 46.2k cap.
    localparam logic [21:0] SPR_SRAM_BASE = 22'd3788800;
    logic        sprb_pend; // one in-flight sprite-byte write
    // ASET sprites live in the 4 MB asset SRAM — offsets are 22-bit byte
    // addresses in the payload; DONKEY sheets are 1470×750 so w/h are u16.
    logic [22:0] spr_off [0:MAX_SPR-1];
    logic [15:0] spr_ww [0:MAX_SPR-1];
    logic [15:0] spr_hh [0:MAX_SPR-1];
    logic [4:0]  n_spr /*verilator public_flat_rd*/, spr_i; // 5-bit for 16 sprites
    logic [2:0]  spr_hdr;
    logic [17:0] spr_wp, spr_left;
    logic [7:0]  blit_si;
    logic        flip_x, flip_y; // neg-xform: mirror dest column/row order
    logic [15:0] blit_sx, blit_sy, blit_sw, blit_sh;
    logic        aset_mode;   // Header flags bit1 — sprites in asset SRAM
    logic        sprd_mode;   // Trailer carries SPRD descriptors (no pixels)
    logic        blit_wait;
    logic [18:0] blit_waddr_q;
    logic        blit_inb_q;   // SRAM read handshake inside S_BLIT
    // flatten: spr_mem 256K / imgd_pix FB — raddr this clock, rdata next.
    // spr_mem_rdata retired (external SRAM)
    logic [17:0] spr_raddr;
    logic [21:0] spr_so; // ASET word addr; spr_raddr is the low 18 for spr_mem
    logic [63:0] vraf_rdata;
    logic [15:0] hdr_w;       // Header words (3, or 4 when ASET off present)
    logic [31:0] time_ms; // PACMAN Date.now / getTime — must advance or start() skips draw
    logic [8:0]  intern_var [0:1023];
    logic        intern_var_ok [0:1023];
    logic [2:0]  enter_n;
    logic [3:0]  enter_delay;
    // Raw key-event FIFO (host → keydown/keyup dispatch, one per frame)
    assign key_evt_ready=(kev_wp+5'd1)!=kev_rp;
    logic [8:0]  kev_q [0:31]; // {down, keyCode}
    logic        kev_src_joy [0:31]; // 1 = synthetic joystick edge, 0 = GUI KEYEVT
    // Dual-path dedup (JOYDEMO: the pad's buttons arrive
    // BOTH as an I2C joy bit AND as a real PS/2 key event via the pmod
    // path — every press delivered keydown(32) twice; typematic repeat
    // made it thrice). After a REAL keydown, synthetic joy edges for the
    // same keyCode are swallowed for ~8 frames (both edges of the press).
    logic [7:0]  kev_dedup_code;
    logic [3:0]  kev_dedup_ctr;
    // ...and the mirror (board: still multi-fired — the race can
    // arrive synthetic-first when a press lands just before an I2C poll
    // batch; the one-directional guard only caught real-first ordering).
    logic [7:0]  syn_dedup_code;
    logic [3:0]  syn_dedup_ctr;
    logic [4:0]  kev_wp /*verilator public_flat_rd*/, kev_rp /*verilator public_flat_rd*/;
    logic [15:0] kev_fn; // handler for S_KEYEV (event alloc + env must be 2-cycle)
    logic [15:0] id_keys_name, id_pressed, id_kspace; // keys.a.pressed table
    logic [8:0]  var_keys;
    logic        keys_ok;
    logic [15:0] keys_a_oid, keys_d_oid, keys_sp_oid;
    // Canvas 2d translate so Player.drawImage(-w/2,-h/2) lands on position
    logic signed [31:0] ctx_tx, ctx_ty, saved_tx, saved_ty;
    // SetTransform axis scale (Q16.16) — FM machine.py _xf spec:
    // ix=int(x*sx+tx), iw=max(1,int(w*sx)) (DONKEY world 1510x685 → glass)
    logic signed [31:0] ctx_sx, ctx_sy, saved_sx, saved_sy;
    // scaled-draw pipeline: latch raw args, multiply, then enter draw state
    logic signed [31:0] xf_x, xf_y, xf_w, xf_h;     // Q16.16 raw args
    logic signed [63:0] xfp_x, xfp_y, xfp_w, xfp_h; // Q32.32 products
    logic [1:0]         xf_dst; // 0=S_RECT 1=S_BLIT 2=fillText S_RECT
    // JSB v2 trailer walk (byte offset into code_mem)
    logic [31:0] image_code_limit;
    logic image_code_valid;
    logic [9:0] image_var_count;
    logic [18:0] trail_off; // PACMAN .JSH trailer sits past 64K byte
    logic [15:0] trail_n, trail_i, name_len_r, nhash, name_idx, trail_acc;
    // 6 bits — phases 32..34 stream the trailer's UTF-8 name bytes
    // (5'd31 stays the "done, go run code" sentinel and still zero-extends)
    logic [5:0]  trail_ph;
    logic [7:0]  trail_cls_i, trail_meth_i, trail_nmeth;
    logic [8:0]  trail_var_slot;
    logic [7:0]  trail_tb; // Combo byte from code_rdata (do not declare inside always_ff)
    // 20 bits — the walk now also streams the UTF-8 name bytes, so the
    // watchdog has to allow NAME_CAP bytes on top of the tables it used to cover
    logic [19:0] trail_guard; // Force FETCH if walker never hits phase 22

    typedef enum logic [6:0] {
        S_IDLE,
        S_RD,          // generic: wait 1 cycle after code_raddr change
        S_GOT_MAGIC,
        S_GOT_HDR1,
        S_GOT_HDR2,
        S_LD_CONST,
        S_TRAIL,       // JSB v2 name/class trailer
        S_FETCH_WAIT,
        S_EXEC,
        S_NAT, S_CLEAR, S_RECT, S_CIRCLE, S_LINE, S_BLIT, S_SPR, S_WAIT_FRAME, S_DONE,
        // Scaled-draw transform (setTransform sx/sy != 1): registered
        // multiply cycle then apply/clip cycle — keeps DSP mults off the
        // single-cycle dispatch path (same reason as S_MUL)
        S_XF_MUL, S_XF_APPLY,
        // Path raster walk (FM _raster_path twin): per-command transform
        // then line / quadratic-subdivision / angular-arc raster
        S_PWALK, S_PDO, S_QSEG, S_QPX, S_QPY,
        // Array natives — join('') digit-hash + reverse intern scan,
        // linear indexOf (PACMAN maze wall-shape switch); string concat fold
        S_JOIN, S_JOIN_FIND, S_IDXOF, S_CONCAT,
        S_SQRT, // Math.sqrt bit-serial (PACMAN position2coord offset)
        // Multi-cycle divide — single-cycle 32-bit '/' was the −90 ns WNS
        // critical path on the board (337 logic levels / 300 CARRY4).
        S_DIV, S_DIV_FIN,
        S_MUL, S_MUL_WR,
        S_ALU, S_ALU_WR,
        S_CALL, S_FOREACH, S_KEYEV, S_ENV_LOAD,
        // JSON.stringify/parse + String.replace/indexOf on dyn strings
        S_JSON, S_JSON_PARSE, S_REPL, S_IDXSTR,
        // Str[i] — address cycle then write-back for the registered
        // name_mem (BRAM) read
        S_STRIDX, S_STRIDX_WR,
        // Real fillText — parse ctx.font px, stage the text bytes, then
        // raster 8x8 glyphs; S_STR_WR gives a joined string its bytes
        S_FONTPX, S_TXT_LD, S_TXT_DRAW, S_STR_WR,
        // Canvas ImageData snapshot (one buffer, FM twin)
        S_IMGD_GET, S_IMGD_PUT,
        // Copy interned name_mem bytes into json_mem (parse/replace).
        // Appended so existing sname= indices stay valid.
        S_NAMCPY,
        // Depth-1 element copy for SET_PROP array-over-array
        // (map.data = JSON.parse(...) at PACMAN level start / any re-parse).
        // Ref-copying rows left nursery arr ids inside an old-space array;
        // the next frame rewind recycled those ids into draw temps
        // (code=[0,0,0,0]) so the maze read back 4-wide garbage.
        S_ARR_DCOPY,
        // Stable-handle mark/tail-sweep collector at frame safe points.
        S_GC_CLEAR, S_GC_ROOT, S_GC_POP, S_GC_OBJ, S_GC_ARR,
        // Value64 states are append-only: every legacy state keeps its number.
        S_V64_CONST_HI, S_V64_EXEC,
        S_V64_DIV, S_V64_DIV_FIN, S_V64_MOD,
        S_V64_ALLOC, S_V64_GC_CLEAR, S_V64_GC_ROOT,
        S_V64_GC_POP, S_V64_GC_OBJ, S_V64_GC_ARR,
        S_V64_GC_SWEEP_OBJ, S_V64_GC_SWEEP_ARR,
        S_V64_GC_FN, S_V64_GC_ENV, S_V64_GC_SWEEP_ENV,
        S_V64_CLEAR, S_V64_RECT, S_V64_WAIT_FRAME,
        S_V64_FRAME_RAF, S_V64_FRAME_TIMER,
        S_V64_FOREACH, S_V64_FRAME_KEY,
        // name_mem BRAM lag for Value64 "str"[i] (row[col]==="1").
        S_V64_STRIDX, S_V64_STRIDX_WR,
        // Value64 JSON.stringify/parse of nested number arrays (map.data clone).
        S_V64_JSON, S_V64_JSON_PARSE,
        // Pad missing ctor/method args to LET_VAR nparam (PYTHON bind_argv).
        S_V64_CTOR_PAD,
        // 1-D heap slot scan (registered SRAM). Append-only numbers.
        S_HEAP_WAIT, S_HEAP_CMP, S_HEAP_WR, S_HEAP_AWR, S_HEAP_FILL,
        S_V64_METH, S_V64_FE_ELEM, S_V64_FE_FILTER, S_V64_OGETI_NAT,
        S_V64_IDXSCAN,
        // Env slot scan completion (NEW_OBJ ctor lookup after S_HEAP_*).
        S_V64_CTOR_ENV,
        // Registered vvars[intern_var] ctor lookup (no combo vvars[vslot]).
        S_V64_CTOR_VARS,
        // Synth 8-3380 / unroll: walk tagged-env recycle and find-free
        // one index per clock (not a task for-loop over ENV_DEPTH/MAX_*).
        S_REL_ENV, S_FREE_OBJ, S_FREE_ARR,
        // 1W1R vstack copies (bind_argv / ctor insert) and Math.min/max.
        S_V64_BIND, S_V64_MINMAX,
        // After a vsp drop of 16+ the TOS FF window is stale; refill from BRAM.
        S_V64_WIN_FILL,
        // Short→long array promote (same handle; copy then flip varr_long).
        S_ARR_PROMOTE,
        // fillRect args from vstack SRAM (window can still be the last bar).
        S_V64_RECT_LD,
        // Sequential p_clr walk (one index/clock) before const load.
        S_HEAP_CLR,
        // #40 Array.slice element copy (append-only; keep numeric order).
        S_V64_SLICE,
        // #41 Array.sort bubble walk.
        S_V64_SORT
        // Post-present bank sync (MUST stay last: sim_main and
        // debug RPCs hardcode earlier state numbers).
        , S_FB_SYNC
        , S_V64_DISPATCH
        // V1.5 standalone compile. ONE state serves srcByte / stgRead /
        // stgWrite / artWrite2 via a mode select, so six natives cost a
        // single encoding — the scarce resource here is st_t entries
        // (112 of 128 before this), not LUTs.
        , S_CSRAM
        , S_V64_MOUSE_PROP
        , S_UI_PROP
        , S_FS
        , S_V64_KEYS
        , S_V64_BYTESTRING
        , S_V64_CALLREF
    } st_t;
    // V1 fit: one-hot the 68-state parent register — 349 state==X decodes
    // become single-FF tests; FF headroom is 8x.
    (* fsm_encoding = "one_hot" *) st_t state /*verilator public_flat_rd*/;
    st_t ret_state;
    logic vprom_done, vprom_copy, hp_prom_wr;
    logic [7:0] hp_prom_phys;
    st_t vprom_ret;

    // Packed object slot {key[15:0], val[63:0]} and array val SRAM.
    // 1W1R registered — storage_engine sbuf / jmr_video_vram Port A.
    // Dump/CHECKPOINT peeks this array (not a third hardware port).
    // Fit: Vivado pads every BRAM to 2^(address width), so the
    // non-pow2 heap arrays each wasted 5-32 tiles (utilization_hier.rpt).
    // Each is decomposed into EXACT pow2 chunks (zero padding):
    //   vobj 30720 = 16K+8K+4K+2K   varr 50688 = 32K+16K+1K+512(+256)
    //   venv 6144  = 4K+2K          (code_mem is split at its declaration)
    // Chunk selects are REGISTERED beside the data - the 1-beat read
    // contract is bit-identical. Sub-indices are masked to the pow2 chunk
    // size so no read is ever out of bounds (#76 lesson).
    (* ram_style = "block" *) logic [79:0] vobj_slot_c0 [0:16383] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c1 [0:8191]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c2 [0:4095]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] vobj_slot_c3 [0:2047]  /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c0 [0:32767] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c1 [0:16383] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [63:0] varr_slot_c2 [0:2047]  /*verilator public_flat_rd*/;
    // Packed env slot {key[8:0], val[63:0]} in low 73 of 80. 1W1R like vobj.
    (* ram_style = "block" *) logic [79:0] venv_slot_c0 [0:4095] /*verilator public_flat_rd*/;
    (* ram_style = "block" *) logic [79:0] venv_slot_c1 [0:2047] /*verilator public_flat_rd*/;
    // LUT fit: the vframe record arrays (6 of the 7; escaped is
    // 128 flat FFs and keeps its partial-field writers) live in a DEDICATED
    // write process so they infer RAM instead of ~30k FFs each dragging
    // ~10 LUTs of 112-state decode (utilization_hier.rpt: the parent held
    // 1.72M logic LUTs). Reads were ALREADY registered; the parent-side
    // writer becomes a one-beat strobe (call-write vs return-read are many
    // beats apart), the exec-side writer moves here unchanged.
    logic        vfr_we;
    logic [6:0]  vfr_wa;
    logic [15:0] vfr_rip;
    logic [11:0] vfr_bsp;
    logic [63:0] vfr_this, vfr_env, vfr_fn, vfr_ctor;
    always_ff @(posedge clk) begin
        // Single write statement per array:
        // two write branches read as two ports and make ram_style="block"
        // infeasible. Priority unchanged: vfr_we wins.
        logic vfr_do; logic [6:0] vfr_a;
        vfr_do = vfr_we || e64_vframe_we;
        vfr_a  = vfr_we ? vfr_wa : e64_vframe_waddr;
        if (vfr_do) begin
            vframe_control[vfr_a] <= vfr_we ? {vfr_setter, vfr_rip, vfr_bsp}
                                           : {1'b0, e64_vframe_rip_wdata, e64_vframe_bsp_wdata};
            vframe_this[vfr_a]      <= vfr_we ? vfr_this : e64_vframe_this_wdata;
            vframe_env[vfr_a]       <= vfr_we ? vfr_env  : e64_vframe_env_wdata;
            vframe_fn[vfr_a]        <= vfr_we ? vfr_fn   : e64_vframe_fn_wdata;
            vframe_ctor[vfr_a]      <= vfr_we ? vfr_ctor : e64_vframe_ctor_wdata;
        end
    end

    // Same LUT-fit treatment for the pure-value metadata writers. vobj_len
    // and venv_len STAY as FFs: their read-modify-write sites sit on the
    // 2-beat heap loop where a strobed (+1 beat) write could be read stale.
    // vobj_len / venv_len: strobed writes land one beat later than the old
    // direct writes; the read capture FORWARDS a same-address in-flight
    // write, restoring the exact original read-after-write timing (a
    // consumer whose raddr was armed on the write beat still sees the new
    // value on the next edge). This closes the RMW hazard that blocked the
    // first conversion attempt.
    logic        vol_we; logic vel_we /*verilator public_flat_rd*/;
    logic [12:0] vobj_len_ridx;
    logic [9:0]  venv_len_ridx /*verilator public_flat_rd*/;
    logic [12:0] vol_wa;
    logic [5:0]  vol_wd;
    logic [8:0]  vel_wa /*verilator public_flat_rd*/;
    logic [4:0]  vel_wd /*verilator public_flat_rd*/;
    always_ff @(posedge clk) begin
        if (vol_we) vobj_len[vol_wa[9:0]] <= vol_wd;
        if (vel_we) venv_len[vel_wa] <= vel_wd;
        else if (e64_venv_len_we) venv_len[e64_venv_len_waddr[8:0]] <= e64_venv_len_wdata;
    end

    logic        vom_we_cls, vom_we_bi, veg_we;
    logic [12:0] vom_wa;
    logic [15:0] vom_cls;
    logic [3:0]  vom_bi;
    logic [8:0]  veg_wa;
    logic [11:0] veg_wd;
    logic        vog_we, vfg_we, vag_we;
    logic [9:0]  vog_wa, vfg_wa;
    logic [11:0] vag_wa;
    logic [11:0] vog_wd, vfg_wd, vag_wd;
    logic        vmko_we, vmkf_we, vmka_we, vmke_we;
    logic [9:0]  vmko_wa, vmkf_wa;
    logic [11:0] vmka_wa;
    logic [8:0]  vmke_wa;
    logic        vmko_wd, vmkf_wd, vmka_wd, vmke_wd;
    logic        vfv_we, vav_we, vev_we, vvv_we, vlo_we;
    logic [9:0]  vfv_wa;
    logic [10:0] vav_wa, vlo_wa;
    logic [8:0]  vev_wa, vvv_wa;
    logic        vfv_wd, vav_wd, vev_wd, vvv_wd, vlo_wd;
    logic        vli_we;
    logic [10:0] vli_wa;
    logic [7:0]  vli_wd;
    logic        nof_we, nbl_we, nlt_we, flu_we;
    logic [9:0]  nof_wa, nbl_wa, nlt_wa, flu_wa;
    logic [15:0] nof_wd, nbl_wd;
    logic [7:0]  nlt_wd, flu_wd;
    logic        vlu_we;
    logic [6:0]  vlu_wa;
    logic        vlu_wd;
    logic        vtd_we, nh_we, txw_we;
    logic [5:0]  vtd_wa, txw_wa;
    logic signed [31:0] vtd_wd;
    logic [9:0]  nh_wa;
    logic        nh_wd;
    logic [7:0]  txw_wd;
    always_ff @(posedge clk) begin
        // 1W merges (vstack recipe) so ram_style="block" can take:
        logic voc_do; logic [9:0] voc_a; logic [15:0] voc_d;
        logic veg_do; logic [8:0] veg_a; logic [11:0] veg_d;
        voc_do = vom_we_cls || e64_vobj_cls_we;
        voc_a  = vom_we_cls ? vom_wa[9:0] : e64_vobj_cls_waddr[9:0];
        voc_d  = vom_we_cls ? vom_cls : e64_vobj_cls_wdata;
        if (voc_do) vobj_cls[voc_a] <= voc_d;
        if (vom_we_bi) vobj_builtin[vom_wa[9:0]] <= vom_bi;
        veg_do = veg_we || e64_venv_gen_we;
        veg_a  = veg_we ? veg_wa : e64_venv_gen_waddr[8:0];
        veg_d  = veg_we ? veg_wd : e64_venv_gen_wdata;
        if (veg_do) venv_gen[veg_a] <= veg_d;
        if (vog_we) vobj_gen[vog_wa] <= vog_wd;
        if (vfg_we) vfn_gen[vfg_wa] <= vfg_wd;
        if (vag_we) varr_gen[vag_wa] <= vag_wd;
        if (vmko_we) vobj_mark[vmko_wa] <= vmko_wd;
        if (vmkf_we) vfn_mark[vmkf_wa] <= vmkf_wd;
        if (vmka_we) varr_mark[vmka_wa] <= vmka_wd;
        if (vmke_we) venv_mark[vmke_wa] <= vmke_wd;
        // e64_*_we are one-shot pulses (exec clears them on its first
        // idle beat — see the exec-write region comment). The else-if
        // drops an e64 write only if a parent strobe fires the same beat;
        // parent metadata strobes fire mid-state, e64 pulses land on the
        // leave-EXEC beat, so the two never coincide today. If a state
        // ever strobes metadata on its FIRST beat, revisit this priority.
        if (vfv_we) vfn_valid[vfv_wa] <= vfv_wd;
        if (vav_we) varr_valid[vav_wa] <= vav_wd;
        else if (e64_varr_valid_we) varr_valid[e64_varr_valid_waddr[10:0]] <= e64_varr_valid_wdata;
        if (vev_we) venv_valid[vev_wa] <= vev_wd;
        else if (e64_venv_valid_we) venv_valid[e64_venv_valid_waddr[8:0]] <= e64_venv_valid_wdata;
        if (vvv_we) vvar_valid[vvv_wa] <= vvv_wd;
        else if (e64_vvar_valid_we) vvar_valid[e64_vvar_valid_waddr[8:0]] <= e64_vvar_valid_wdata;
        if (vlo_we) varr_long[vlo_wa] <= vlo_wd;
        else if (e64_varr_long_we) varr_long[e64_varr_long_waddr[10:0]] <= e64_varr_long_wdata;
        begin  // 1W merge (vstack recipe) so ram_style="block" can take
            logic vli_do; logic [10:0] vli_a; logic [7:0] vli_d;
            vli_do = vli_we || e64_varr_lidx_we;
            vli_a  = vli_we ? vli_wa : e64_varr_lidx_waddr[10:0];
            vli_d  = vli_we ? vli_wd : e64_varr_lidx_wdata;
            if (vli_do) varr_lidx[vli_a] <= vli_d;
        end
        if (nof_we) begin
            name_off[nof_wa] <= nof_wd;
            name_off_r1[nof_wa] <= nof_wd;
            name_off_r3[nof_wa] <= nof_wd;
        end
        if (nbl_we) begin
            name_blen[nbl_wa] <= nbl_wd;
            name_blen_r1[nbl_wa] <= nbl_wd;
        end
        if (nlt_we) begin
            name_len_tbl[nlt_wa] <= nlt_wd;
        end
        if (flu_we) fill_lut[flu_wa] <= flu_wd;
        if (vlu_we) vlong_used[vlu_wa] <= vlu_wd;
        if (vtd_we) vtimer_due[vtd_wa] <= vtd_wd;
        if (txw_we) txt_buf[txw_wa] <= txw_wd;
        if (cmn_we) cls_mname[cmn_wa] <= cmn_wd;
        if (cmi_we) cls_mip[cmi_wa] <= cmi_wd;
        clsm_name_rd <= cls_mname[clsm_raddr];
        clsm_ip_rd <= cls_mip[clsm_raddr];
    end

    logic vobj_we /*verilator public_flat_rd*/; logic varr_we /*verilator public_flat_rd*/; logic venv_we;
    logic [VOBJ_AW-1:0] vobj_waddr /*verilator public_flat_rd*/; logic [VOBJ_AW-1:0] vobj_raddr;
    logic [VARR_AW-1:0] varr_waddr /*verilator public_flat_rd*/; logic [VARR_AW-1:0] varr_raddr;
    logic [VENV_AW-1:0] venv_waddr, venv_raddr;
    logic [79:0] vobj_wdata, vobj_rdata;
    logic [79:0] venv_wdata, venv_rdata;
    logic [63:0] varr_wdata, varr_rdata;
    // Conservative sticky reference metadata. Every element write funnels
    // through varr_we/hp_aid below, including fill/copy/promotion/JSON paths.
    // A reference write sets this bit; only invalidation/recycle clears it.
    // The collector still marks/sweeps the ARRAY and checks generations; it
    // can skip only an element walk that cannot contain a heap reference.
    (* ram_style = "distributed" *) logic varr_may_ref [0:MAX_ARR-1];
    logic varr_may_ref_rdata;
    wire varr_ref_write = varr_we && varr_wdata[63:48] == jmr_value_pkg::V64_TAG_PREFIX &&
        (varr_wdata[47:44] == 4'd5 || varr_wdata[47:44] == 4'd6 ||
         varr_wdata[47:44] == 4'd7 || varr_wdata[47:44] == 4'd8 ||
         varr_wdata[47:44] == 4'd9);
    wire varr_ref_clear = vav_we && !vav_wd;
    wire varr_ref_we = varr_ref_clear || varr_ref_write;
    wire [10:0] varr_ref_wa = varr_ref_clear ? vav_wa : hp_aid[10:0];
    always_ff @(posedge clk) begin
        if (varr_ref_we) varr_may_ref[varr_ref_wa] <= !varr_ref_clear;
        varr_may_ref_rdata <= varr_may_ref[vgc_cur[10:0]];
    end
`ifndef SYNTHESIS
    always_ff @(posedge clk) if (rst_n && varr_ref_clear && varr_ref_write &&
        vav_wa != hp_aid[10:0])
        $error("array reference metadata has conflicting writers");
`endif

    // Two-tier array address (not MAX_ARR×128 concat). long/lidx are SRAM:
    // raddr this clock, varr_long_rdata / varr_lidx_rdata next (never peek).
    function automatic [VARR_AW-1:0] varr_slot_addr;
        input [11:0] aid;
        input [6:0] slot;
        begin
            // Linear 1-D (same as sim/sim_main.cpp varr_addr). Packed
            // {1'b0,aid[9:0],slot[4:0]} only had 1024 unique short rows.
            if (varr_long_rdata)
                varr_slot_addr = VARR_AW'(VARR_SHORT_WORDS
                    + {1'b0, varr_lidx_rdata, slot});
            else
                varr_slot_addr = VARR_AW'({aid[10:0], slot[4:0]});
        end
    endfunction

    // Heap FSM: scan stops at vobj_len / varr_len, 2 clks/slot (addr, cmp).
    localparam logic [3:0] HP_GETPROP = 4'd0;
    localparam logic [3:0] HP_SETPROP = 4'd1;
    localparam logic [3:0] HP_ARRGET  = 4'd2;
    localparam logic [3:0] HP_ARRSET  = 4'd3;
    localparam logic [3:0] HP_AFILL   = 4'd4;
    localparam logic [3:0] HP_OSETI   = 4'd5;
    localparam logic [3:0] HP_OGETI   = 4'd6;
    localparam logic [3:0] HP_LOOKFN  = 4'd7;
    localparam logic [3:0] HP_GETIDX  = 4'd8;
    localparam logic [3:0] HP_SETIDX  = 4'd9;
    localparam logic [3:0] HP_PUSH    = 4'd10;
    localparam logic [3:0] HP_UNSHIFT = 4'd11;
    localparam logic [3:0] HP_SPLICE  = 4'd12;
    localparam logic [3:0] HP_ASSIGN  = 4'd13;
    localparam logic [3:0] HP_AGETI   = 4'd14;
    localparam logic [3:0] HP_ASETI   = 4'd15;
    logic [3:0]  hp_cmd_ff;
    logic [3:0]  hp_cmd;
    logic [12:0] hp_oid_ff;
    logic [12:0] hp_oid /*verilator public_flat_rd*/;
    logic [11:0] hp_aid_ff;
    logic [11:0] hp_aid;
    logic        hp_env_ff;
    logic        hp_env; // S_HEAP_* talks to venv_slot (LOAD/STORE/LET/ctor)
    logic [9:0]  hp_eid_ff /*verilator public_flat_rd*/;
    logic [9:0]  hp_eid /*verilator public_flat_rd*/;
    logic [4:0]  hp_slot_ff;
    logic [4:0]  hp_slot;
    logic [6:0]  hp_aslot_ff;
    logic [6:0]  hp_aslot;
    logic [5:0]  hp_len_ff;
    logic [5:0]  hp_len;
    logic [7:0]  hp_alen_ff, hp_lim_ff;
    logic [7:0]  hp_alen, hp_lim;
    logic [15:0] hp_key_ff /*verilator public_flat_rd*/;
    logic [15:0] hp_key /*verilator public_flat_rd*/;
    logic [63:0] hp_wval_ff, hp_rval_ff;
    logic [63:0] hp_wval, hp_rval;
    logic        hp_hit_ff;
    logic        hp_hit;
    st_t         hp_ret_ff;
    st_t         hp_ret;
    st_t         bind_ret;
    st_t         vst_refill_ret;
    logic [2:0]  hp_phase_ff;
    logic [2:0]  hp_phase /*verilator public_flat_rd*/;
    logic [63:0] hp_proto;
    logic [15:0] hp_qk_ff [0:3];
    logic [15:0] hp_qk [0:3];
    logic [63:0] hp_qv_ff [0:3];
    logic [63:0] hp_qv [0:3];
    logic [2:0]  hp_qt_ff [0:3];
    logic [2:0]  hp_qt [0:3];
    logic [2:0]  hp_qn_ff, hp_qi_ff;
    logic [2:0]  hp_qn, hp_qi;
    logic        vgc_rd_arm, jn_rd_arm, vfe_rd_arm, vjs_rd_arm;
    // S_V64_STRIDX: name_rdata then char_id_rdata (two Port A lags).
    logic        stridx_rd_arm;
    logic        stridx_alloc_pending;
    logic [9:0]  stridx_alloc_id;
    // flatten: second beat after varr_rdata / vobj_rdata so name_hash raddr
    // can follow the intern id (stale 0 = wait, never peek).
    logic        jn_name_arm, vjs_name_arm, tfn_rd_arm;
    // flatten: long_rdata then slot raddr (JOIN/IDXOF/FOREACH/JSON/GC_ARR).
    logic        jn_slot_arm /*verilator public_flat_rd*/;
    // flatten: HEAP_WAIT / HEAP_AWR long_rdata then slot raddr/waddr.
    logic        hp_slot_arm;
    // Same-oid/eid slot++ stays in HEAP_CMP one extra clock (Port A rdata
    // + overlay latch into exec hp_slot_q). Do not combo-peek; do not
    // bounce to HEAP_WAIT (that was 3 extra beats per key).
    logic        hp_slot_pend;
    // flatten: mark_task latches the handle; next beats consume *_rdata.
    logic        vgc_mark_pend /*verilator public_flat_rd*/, vgc_mark_arm;
    logic        vgc_arr_ph;   // GC_ARR stream phase (data-lag toggle)
    logic [63:0] vgc_mark_word /*verilator public_flat_rd*/;
    // ALLOC free-scan wait. Do not reuse jn_rd_arm — JOIN after a take
    // would skip its length beat (arm stays 1).
    logic        valloc_rd_arm /*verilator public_flat_rd*/;
    // flatten: HEAP proto follow / ASSIGN nsv — raddr = hp_proto this clock.
    logic        hp_proto_arm /*verilator public_flat_rd*/;
    // venv_len_rdata is a registered read. LET_VAR picks the new slot
    // with it AND increments the length with it, so using it in the same
    // beat it is requested makes every declaration land in slot 0 and the
    // length never advance: a program whose top level runs inside an env
    // (INVADERS) lost every top-level `let`, and reads fell through to an
    // empty vvars entry. One settle beat before it is used.
    logic        env_len_arm;
    // flatten: json_mem is 8K SRAM; rdata next clock (PARSE/REPL/IDXSTR/TXT).
    logic [7:0]  json_mem_rdata, json_ch0;
    logic [12:0] json_rdaddr;
    logic        vlong_used_rdata;
    logic signed [31:0] vtimer_due_rdata;
    logic [63:0] vtimer_fn_rdata;
    logic signed [63:0] vtimer_period_rdata;
    logic [63:0] vlistener_ev_rdata, vlistener_fn_rdata;
    // FRAME_TIMER / FRAME_KEY sequential scan (not N parallel SRAM ports).
    logic        vt_found, vk_found;
    logic [6:0]  vt_pick;
    logic [4:0]  vk_pick;
    logic signed [31:0] vt_best_due, vt_best_id;
    // flatten: latch due timer/rAF handle; unique case consumes *_rdata.
    logic [13:0] gc_queue_rdata;
    logic [16:0] vgc_queue_rdata;
    logic [12:0] hp_si_ff, hp_ti;
    logic [12:0] hp_si;
    logic [4:0]  hp_ss_ff;
    logic [4:0]  hp_ss;
    logic [5:0]  hp_tn_ff;
    logic [5:0]  hp_tn;
    // Sequential array init copies stack[hp_vbase+i] (regs, not SRAM mux).
    logic        hp_from_stack_ff;
    logic        hp_from_stack;
    logic        hp_make_arr_ff;
    logic        hp_make_arr; // MAKE_ARRAY: write handle after fill (not before)
    logic [11:0] hp_vbase_ff;
    logic [11:0] hp_vbase;
    logic [15:0] hp_spr_w_ff, hp_spr_h_ff;
    logic [15:0] hp_spr_w, hp_spr_h;
    // OGETI continuation: 0 parse 1 putimg 2 meas 3 idxof 4 repl 5 regex
    logic [3:0]  hp_nat_ff;
    logic [3:0]  hp_nat;

    // #40 Array.slice scratch
    logic [11:0] sl_src, sl_dst;
    logic [7:0] sl_i, sl_end, sl_di;
    // #41 Array.sort scratch: j cursor, pass-swapped flag, the two elements.
    logic [7:0] so_j;
    logic so_swapped;
    // #60: listener-count snapshot at key-event dispatch — listeners added
    // DURING a dispatch must not run for the same event (browser defers to
    // the next event; DONKEY's title Enter also fired the character-select
    // handler it had just registered, skipping that screen).
    logic [4:0] vkey_ln;
    logic [63:0] so_a, so_b;
    logic [7:0]  dc_i;

    logic [15:0] c_i;
    // 10-bit coords for 640×480 (was 8-bit mini after scale4)
    logic [9:0]  rw, rh, x, y;
    // signed dest origin for blit (Canvas off-glass DDA); fillRect stays >=0
    logic signed [11:0] rx, ry;
    logic [7:0]  color;
    // Scaled-blit source coords: per-pixel divides replaced by an exact
    // DDA (floor((x*sw)/rw) == x*(sw/rw) + floor(x*(sw%rw)/rw), carried
    // incrementally). qx/rx_r/qy/ry_r come from the blit_div_ph setup
    // divides at S_BLIT entry; the DDA advances with the put-beat walk.
    logic [15:0] dda_sx, dda_ax, dda_sy, dda_ay;
    logic [15:0] bdiv_qx, bdiv_rx, bdiv_qy, bdiv_ry;
    logic [1:0]  blit_div_ph;   // 0 idle/done, 1 dividing sw/rw, 2 sh/rh
    logic [4:0]  bdiv_i;
    logic [15:0] bdiv_quo;
    logic [16:0] bdiv_rem;      // one bit wider than the 16-bit divisor
    logic [15:0] bdiv_num, bdiv_den;
    // spr_so multiply deleted: the per-pixel source
    // offset lives in jmr_raster_engine as an incremental DDA — the
    // 16x22 multiply left the netlist with it. spr_so/spr_raddr are
    // unread now (S_SPR uploads use spr_wp).
    always_comb begin
        spr_so = 22'd0;
        spr_raddr = 18'd0;
    end
    // flatten: sin_q raddr from sin_turn (not function peek / unique-case ROM).
    assign sin_raddr = sin_turn[14] ? (8'd255 - sin_turn[13:6]) : sin_turn[13:6];
    logic [18:0] clr_idx;
    // C1: engine-wait flags. rast_go is a STROBE (default-cleared every
    // beat); rast_wait/rast_started are STATE (rule:
    // never put a handshake flag in the default-clear block).
    logic rast_wait;
    logic [7:0]  nat_id, nat_argc;
    logic signed [31:0] a_s, b_s;

    // Registered multiply operands + product (break DSP→stack path).
    // 64-bit product: fx×fx needs the >>16 correction (Q16.16 renormalize).

    // ALU pipeline for ADD/SUB/LT/GT/EQ/NEG/NOT
    
    // Q16.16 mixed arithmetic — operands lifted to fx when either is fx;
    // ADD/SUB/NEG results stay fx, compares are plain ints.

    // Restoring-divider state (48 cycles @ core clk) — dividend is
    // |N| << 16 so the quotient lands in Q16.16 (truncate toward zero, /0 → 0)

    assign busy = running;
    assign done = (state == S_DONE);

    import jmr_value_pkg::*;
    // Number/tag helpers live in jmr_value.sv. Heap/GC tasks stay below.

    // Synthesizable integer/bit IEEE-754 binary64 add. NaNs are always
    // canonicalized to the frozen Value64 ABI word.

    // Synthesizable 53x53 integer multiply with binary64 normalization and
    // round-to-nearest-even.
    // v64_mul_task deleted: its only caller was the
    // rAF timestamp; that product is now the sequential raf engine (see
    // raf_pack_n). exec64 made the same move (fpm/nwm).

    // v64_norm_shift / v64_unbiased_exp / v64_handle: jmr_value_pkg

    // Mark one valid stable handle and enqueue it exactly once. Future frame
    // and queue roots enter through this same single-word root interface.
    task automatic v64_gc_mark_task(input logic [63:0] word);
        begin
            vgc_mark_word <= word;
            /* GC accel: numbers/undefined can never mark —
               every v64 consumer branch requires word[63:48]==16'h7ff9 (the
               handle prefix), so a non-handle word only burned the 2-beat
               arm/act machinery to discover a no-op. Skip it. PACMAN-class
               (number-heavy arrays) spent 34% of frame in GC_ARR at 5 beats
               per slot; this alone cuts that to 3. */
            vgc_mark_pend <= (word[63:48] == 16'h7ff9);
        end
    endtask

    // Env LOAD/STORE/LET walk S_HEAP_* (hp_env). Combo v64_env_lookup_task
    // was a 1024×16 mux (Synth 8-4556 on venv_val).

    // ARRAY_GET/SET use Number-to-integer truncation without modulo wrapping.
    // len<=65535 and scale<=15: exact width fits23bits. Balanced
    // shift/add avoids another multiplier beside the shared font product.
    // Intersect original signed geometry before narrowing to raster ports.
    function automatic logic [19:0] rect_clip_axis(
        input logic signed [47:0] origin,
        input logic signed [47:0] extent,
        input logic [9:0] limit);
        logic signed [48:0] finish, lo, hi, bound;
        begin
            bound = $signed({39'd0,limit});
            finish = {origin[47],origin} + {extent[47],extent};
            lo = origin < 0 ? 49'sd0 : {origin[47],origin};
            hi = finish > bound ? bound : finish;
            if (extent <= 0 || lo >= bound || hi <= lo)
                rect_clip_axis = 20'd0;
            else rect_clip_axis = {10'(lo),10'(hi-lo)};
        end
    endfunction

    function automatic logic [31:0] text_pixel_width(
        input logic [15:0] len, input logic [3:0] scale
    );
        logic [22:0] base, lo, hi;
        begin
            base = {4'd0, len, 3'd0};
            lo = (scale[0] ? base : 23'd0) +
                 (scale[1] ? base << 1 : 23'd0);
            hi = (scale[2] ? base << 2 : 23'd0) +
                 (scale[3] ? base << 3 : 23'd0);
            text_pixel_width = {9'd0, lo + hi};
        end
    endfunction

    // Native64 readU32 distinguishes a successful unsigned word from the
    // signed -1 error using the already-latched, fully validated request.
    // All other services retain the existing signed result ABI.
    function automatic logic [63:0] v64_fs_number(
        input logic [2:0] command,
        input logic [127:0] arguments,
        input logic [31:0] result
    );
        if (command == 3'd7 && arguments[31:0] == 32'd8 &&
            arguments[63:32] <= jmr_js_vm_pkg::CSTG_WORDS - 4 &&
            arguments[95:64] == 32'd0 && arguments[127:96] == 32'd0 &&
            result[31])
            // 2^31..2^32-1 all have exponent31 and are exactly representable.
            v64_fs_number = {1'b0, 11'd1054, result[30:0], 21'd0};
        else
            v64_fs_number = v64_int32_number(result);
    endfunction

    // v64_to_uint32 / v64_int32_number / v64_u32_fraction: jmr_value_pkg

    // Round a restoring-divider quotient to binary64, including gradual
    // underflow. div_rem contributes the exact sticky bit beyond quot[0].
    task automatic v64_div_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [106:0] quot,
        input logic [53:0] div_rem,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [53:0] rounded;
        logic guard, sticky;
        // Signed exponent is 13 bits. Subtracting at most one and the
        // possible rounding carry require 14 bits: [-4097,4096].
        logic signed [13:0] unbiased;
        logic [6:0] shift_minus_one;
        logic [106:0] shifted;
        logic tiny;
        begin
            unbiased = $signed({exponent[12],exponent})
                       - (quot[54] ? 14'sd0 : 14'sd1);
            // For subnormals the original shift simplifies exactly to
            // -1020-exponent, independently of quot[54]. Beyond 107 all
            // quotient bits are sticky; guard and mantissa are zero.
            tiny = (unbiased < -14'sd1022) && (exponent < -13'sd1127);
            if (unbiased < -14'sd1022 && !tiny)
                shift_minus_one = 7'(-14'sd1021-$signed({exponent[12],exponent}));
            else
                shift_minus_one = quot[54] ? 7'd1 : 7'd0;
            shifted = quot;
            sticky = |div_rem;
            // Shift one less than the mantissa shift, retaining guard in
            // bit zero. Each barrel stage folds exactly its discarded bits
            // into sticky, replacing 107 wide integer range comparisons.
            for (int stage = 0; stage < 7; stage++) begin
                if (shift_minus_one[stage]) begin
                    case (stage)
                        0: sticky = sticky | (|shifted[0:0]);
                        1: sticky = sticky | (|shifted[1:0]);
                        2: sticky = sticky | (|shifted[3:0]);
                        3: sticky = sticky | (|shifted[7:0]);
                        4: sticky = sticky | (|shifted[15:0]);
                        5: sticky = sticky | (|shifted[31:0]);
                        6: sticky = sticky | (|shifted[63:0]);
                    endcase
                    shifted = shifted >> (1 << stage);
                end
            end
            mant = tiny ? 53'd0 : shifted[53:1];
            guard = !tiny && shifted[0];
            if (tiny) sticky = sticky | (|quot);
            rounded = {1'b0, mant}
                    + (guard && (sticky || mant[0]));
            if (unbiased >= -14'sd1022) begin
                if (rounded[53]) begin
                    mant = rounded[53:1];
                    unbiased = unbiased + 14'sd1;
                end else
                    mant = rounded[52:0];
                if (unbiased > 14'sd1023)
                    result = {sign, 11'h7ff, 52'd0};
                else
                    result = {sign, 11'(unbiased + 14'sd1023), mant[51:0]};
            end else if (rounded[52]) begin
                result = {sign, 11'd1, 52'd0};
            end else if (rounded == 0) begin
                result = {sign, 63'd0};
            end else begin
                result = {sign, 11'd0, rounded[51:0]};
            end
        end
    endtask

    // MOD's integer remainder is exact at the divisor's binary scale.
    task automatic v64_mod_pack_task(
        input logic sign,
        input logic signed [12:0] exponent,
        input logic [52:0] remainder,
        output logic [63:0] result
    );
        logic [52:0] mant;
        logic [63:0] fraction;
        integer top, unbiased, shift;
        begin
            if (remainder == 0) begin
                result = {sign, 63'd0};
            end else begin
                top = 0;
                for (int k = 0; k < 53; k++)
                    if (remainder[k])
                        top = k;
                unbiased = exponent - 52 + top;
                if (unbiased >= -1022) begin
                    mant = remainder << (52 - top);
                    result = {sign, 11'(unbiased + 1023), mant[51:0]};
                end else begin
                    shift = exponent + 1022;
                    if (shift >= 0)
                        fraction = 64'(remainder) << shift;
                    else
                        fraction = 64'(remainder) >> (-shift);
                    result = {sign, 11'd0, fraction[51:0]};
                end
            end
        end
    endtask
    // Fn heap object slot0 = entry ip (tag-4 stack value is the obj idx)
    // Live heap env (FM env dict). Parent oid in slot0.
    // Restore captured env from a MAKE_FN heap object (timers / rAF / meth).
    // Fresh call env whose parent is the captured env object
    // (FM call_fn env={__par: fn.env}). STORE walks the parent chain.
    // Keydown/keyup listener table (4 slots; same (type,fn) registers once)

    // Recycle this call's env unless MAKE_FN captured it (live closure).
    // forEach/finder return leaked middle oids AND could push the same oid
    // twice (PACMAN ENVSTAT free=2296,2295,2296). Nursery oids on the free
    // list sit ABOVE n_obj_keep — the bump allocator then overwrites that
    // env as a regular object in the same frame, so forEach LOAD f misses
    // and item.times stays 0 (stale vars[]).
    
    // Combo TOS-window mux. Vivado Synth 8-660: function automatic vst_at
    // is not resolved from the giant unique case (Verilator is). Deep stack
    // copies already go through S_V64_BIND / S_HEAP_FILL (vst_rdata).
    always_comb begin
        vst_peek[0]  = vst_win[0];
        vst_peek[1]  = vst_win[1];
        vst_peek[2]  = vst_win[2];
        vst_peek[3]  = vst_win[3];
        vst_peek[4]  = vst_win[4];
        vst_peek[5]  = vst_win[5];
        vst_peek[6]  = vst_win[6];
        vst_peek[7]  = vst_win[7];
        vst_peek[8]  = vst_win[8];
        vst_peek[9]  = vst_win[9];
        vst_peek[10] = vst_win[10];
        vst_peek[11] = vst_win[11];
        vst_peek[12] = vst_win[12];
        vst_peek[13] = vst_win[13];
        vst_peek[14] = vst_win[14];
        vst_peek[15] = vst_win[15];
    end
    genvar gi_vst;
    generate
        for (gi_vst = 0; gi_vst < 16; gi_vst++) begin : g_vst_pack
            assign vst_win_pack[64*gi_vst +: 64] = vst_win[gi_vst];
        end
    endgenerate
    // Relative slot from TOS (0=TOS). Out-of-window → slot 0, not BRAM.
    // No extra parens around vst_peek[i] — `(expr)[62:52]` is illegal SV
    // (Synth 8-660 site was Math.abs `vst_at(base)[62:52]`).
    `define VST_REL(addr) (((((vsp)>(addr)) && (((vsp)-(addr)-12'd1)<12'd16))) ? 4'((vsp)-(addr)-12'd1) : 4'd0)
    `define VST_AT(addr) vst_peek[`VST_REL(addr)]
    task automatic vst_wr(input logic [11:0] addr, input logic [63:0] data);
        vst_we <= 1'b1;
        vst_waddr <= addr;
        vst_wdata <= data;
    endtask
    // Exec's vst_we_q is REGISTERED and exec freezes
    // after issuing a multi-beat parent op. The stale write request then
    // REPLAYED on the returning FETCH_WAIT beat, overwriting the parent's
    // result (join's pre-written UNDEFINED clobbered the interned handle —
    // code.join('') read undefined with joinmiss=0). An exec write is valid
    // exactly one beat after an enabled exec beat: the leave beat for
    // hand-off ops, the next fetch/exec beat for 1-beat ops.
    logic e64_wr_ok;
    always_ff @(posedge clk) begin
        if (!rst_n) e64_wr_ok <= 1'b0;
        else e64_wr_ok <= (state == S_V64_EXEC) && !e64_leave_hold;
    end

    // Full-depth TOS window push. Sites that plant a pushed value with
    // vst_hold_win must shift ALL 16 slots: hold_win suppresses the
    // automatic shift, so hand-shifting only win[1] left win[2..15] one
    // slot behind. Every value deeper than the new TOS was then read from
    // the wrong slot — `x + 6 * s` in a function lost `x` (INVADERS
    // drawCannon painted at 12,438 instead of 312,438; drawBitmap's y
    // collapsed so every sprite stacked on one row).
    task automatic vst_push_win(input logic [63:0] v);
        integer wi;
        for (wi = 15; wi > 0; wi = wi - 1)
            vst_win[wi] <= vst_win[wi - 1];
        vst_win[0] <= v;
    endtask
    task automatic name_hash_wr(input logic [9:0] addr, input logic [15:0] data);
        name_hash_we <= 1'b1;
        name_hash_waddr <= addr;
        name_hash_wdata <= data;
    endtask
    // Remember a FIND hit/alloc in slot 0 (shift). Skip if id already cached.
    /* FIND bucket: a PURE CACHE of the linear walk's answer.
       Direct-mapped 1024 x {gen8, id16} by hash[9:0], generation-tagged so
       name-table resets/recycles invalidate in O(1). A hit yields ONE
       candidate that the EXISTING jn_cache_try confirm verifies (hash+len
       via Port A); any miss/stale/collision falls back to the linear walk
       and the remember hook re-inserts the winner. Wrong contents can only
       cost cycles, never correctness. PACMAN measured JOIN_FIND at 14%;
       dynamic per-cell keys defeat the 4-way FF cache. */
    (* ram_style = "block" *) logic [23:0] jn_bucket [0:1023];
    // 1W merge (the vstack/vframe recipe). jn_cache_remember has TWO call
    // sites, so writing the array inside the task put two write statements
    // on it and Vivado refused the attribute outright — "not inferred as
    // ram due to incorrect usage" — landing the whole
    // 1024x24 bucket in fabric: ~13.8k LUTs + ~24.7k FFs on a design that
    // is already fighting the router. One registered write port fixes it.
    // The insert lands a cycle later; harmless here because the bucket is a
    // pure cache whose candidate is confirm-verified before use, and a miss
    // just falls through to the linear walk.
    logic        jnb_we;
    logic [9:0]  jnb_wa;
    logic [23:0] jnb_wd;
    logic [7:0]  jn_bucket_gen;
    logic [23:0] jn_bucket_rdata;
    logic        jn_bucket_tried;
    logic [15:0] jn_btry /*verilator public_flat_rd*/; // 5th-way fires
    logic [15:0] jn_bmiss /*verilator public_flat_rd*/; // bucket candidates that failed confirm
    task automatic jn_cache_remember(input logic [15:0] id);
        begin jnb_we <= 1'b1; jnb_wa <= jn_h[9:0];
              jnb_wd <= {jn_bucket_gen, id}; end
        if ((jn_hit_v[0] && jn_hit_i0 == id) ||
            (jn_hit_v[1] && jn_hit_i1 == id) ||
            (jn_hit_v[2] && jn_hit_i2 == id) ||
            (jn_hit_v[3] && jn_hit_i3 == id)) begin
        end else begin
            jn_hit_h3 <= jn_hit_h2; jn_hit_l3 <= jn_hit_l2; jn_hit_i3 <= jn_hit_i2;
            jn_hit_h2 <= jn_hit_h1; jn_hit_l2 <= jn_hit_l1; jn_hit_i2 <= jn_hit_i1;
            jn_hit_h1 <= jn_hit_h0; jn_hit_l1 <= jn_hit_l0; jn_hit_i1 <= jn_hit_i0;
            jn_hit_h0 <= jn_h; jn_hit_l0 <= jn_len; jn_hit_i0 <= id;
            jn_hit_v  <= {jn_hit_v[2:0], 1'b1};
        end
    endtask
    task automatic varr_len_wr(input logic [11:0] addr, input logic [7:0] data);
        varr_len_we <= 1'b1;
        varr_len_waddr <= addr;
        varr_len_wdata <= data;
    endtask
    task automatic vobj_alloc_wr(input logic [9:0] addr, input logic [1:0] data);
        vobj_alloc_we <= 1'b1;
        vobj_alloc_waddr <= addr;
        vobj_alloc_wdata <= data;
    endtask
    task automatic vvars_wr(input logic [8:0] addr, input logic [63:0] data);
        vvars_we <= 1'b1;
        vvars_waddr <= addr;
        vvars_wdata <= data;
    endtask
    // Nursery obj/fn stored into an *old-space array* (boot snapshot).
    // Callers must check dest oid < n_arr_keep. Do not use on SET_PROP —
    // item.coord = position2coord() every frame would freeze the bump
    // (PACMAN FPGA-SIM heapovf=8896 / ghosts never left the house).
    
    // Same watermark as objects — stored array oid+1, never n_arr.
    // JSON.parse / Array.fill / map temps sit above keep and rewind.
    
    // Registering a frame callback IS the end of boot. The keep watermark
    // only armed after ARR_KEEP_DELAY frames, so a loop registered from
    // top-level (PACMAN init() -> start() -> requestAnimationFrame(fn)) left its
    // Fn object in the nursery; the first rewind recycled that oid and the
    // dispatcher then ran whatever function had taken the slot over — it
    // returned without re-arming, so raf stuck at 0 and the game froze on its
    // first drawn frame (cbip landed inside the Game factory, not the loop).
    // A registered callback is live by definition, and everything allocated up
    // to it is the program's boot state, so arm both watermarks here. Only on
    // the FIRST registration: re-arming every frame would walk the bump pointer
    // up and saturate the heap.
    
    // A value stored into old space also owns whatever it points at, and a
    // constructor allocates those children AFTER the instance itself, so
    // stored_oid+1 kept the parent and rewound its contents (INVADERS:
    // grids.push(new Grid()) kept the Grid and dropped this.invaders plus every
    // Invader one frame later — the alien formation vanished and the array
    // watermark was never committed at all). Allocation is a bump pointer, so
    // "everything allocated so far" is exactly that subgraph: raise BOTH
    // watermarks to the current pointers.
    // Per-frame churn does not reach here — object/array slot overwrites copy
    // in place below and keep their old oid, so the bump cannot creep
    // (test_rtl_coord_overwrite_does_not_heapovf).


    // Clip fillRect args to FB (no wrap — was the sparse BOARD bug)
    function automatic logic [9:0] clip_u(input logic signed [31:0] v, input int unsigned lim);
        if (v < 0) clip_u = 10'd0;
        else if (v >= lim) clip_u = 10'(lim - 1);
        else clip_u = 10'(v);
    endfunction
    // 16-bit clamp for blit source coords (ASET sheets exceed 10 bits)
    
    function automatic logic [9:0] clip_sz(
        input logic signed [31:0] v,
        input logic [9:0] origin,
        input int unsigned lim
    );
        logic signed [31:0] room;
        room = lim - 32'(origin);
        if (v <= 0) clip_sz = 10'd0;
        else if (v > room) clip_sz = 10'(room);
        else clip_sz = 10'(v);
    endfunction
    
    // Float bits → Q16.16 fixed (tag 7). 0.12*width must not be 0 —
    // fractions are the FM parity gap (INVADERS ship scale, DONKEY 640/1510).
    
    // Tag-aware int read — Q16.16 (tag 7) floors to i32, others pass through
    function automatic logic signed [31:0] fxi(
        input logic signed [31:0] v, input logic [2:0] t);
        fxi = (t == 3'd7) ? (v >>> 16) : v;
    endfunction
    // Lift an int operand into Q16.16 when its partner is fx
    
    // Stack read floored to int — draw/native args must not see raw Q16.16
    // unused — never combo stack[i] (Synth 8-4767 / flatten)
    
    // unused — never combo stack[i]
    
    // IEEE binary64 → Q16.16 (path/arc args). Compare the exponent to
    // 1023/1059 directly — do not stash (exp-1023) in a signed local.
    
    // Q16.16 → IEEE. Unbiased exp is top-16; IEEE exp = top+1007
    // (1023-16). Do not stash (top-16) in a signed local.
    function automatic logic [63:0] v64_from_fx(input logic signed [31:0] fx);
        logic sign;
        logic [31:0] magnitude;
        logic [52:0] mant;
        integer top;
        begin
            sign = fx[31];
            magnitude = sign ? (~fx + 32'd1) : fx;
            if (magnitude == 0)
                v64_from_fx = 64'd0;
            else begin
                top = 0;
                for (int k = 0; k < 32; k++)
                    if (magnitude[k])
                        top = k;
                mant = 53'(magnitude) << (52 - top);
                v64_from_fx = {sign, 11'(top + 1007), mant[51:0]};
            end
        end
    endfunction
    // Q32.32 → int, truncating toward zero (Python int() spec in FM _xf)
    function automatic logic signed [31:0] trunc32(input logic signed [63:0] v);
        trunc32 = v[63] ? -32'((-v) >>> 32) : 32'(v >>> 32);
    endfunction

    // Saturate a 33-bit sum to int32 — FM floats never wrap on overflow

    // Quarter-wave sine ROM init (Q1.15) — arc angle sector vectors
    initial begin
        sin_q[0]=16'd0; sin_q[1]=16'd201; sin_q[2]=16'd402; sin_q[3]=16'd603; sin_q[4]=16'd804; sin_q[5]=16'd1005; sin_q[6]=16'd1206; sin_q[7]=16'd1407;
        sin_q[8]=16'd1608; sin_q[9]=16'd1809; sin_q[10]=16'd2009; sin_q[11]=16'd2210; sin_q[12]=16'd2410; sin_q[13]=16'd2611; sin_q[14]=16'd2811; sin_q[15]=16'd3012;
        sin_q[16]=16'd3212; sin_q[17]=16'd3412; sin_q[18]=16'd3612; sin_q[19]=16'd3811; sin_q[20]=16'd4011; sin_q[21]=16'd4210; sin_q[22]=16'd4410; sin_q[23]=16'd4609;
        sin_q[24]=16'd4808; sin_q[25]=16'd5007; sin_q[26]=16'd5205; sin_q[27]=16'd5404; sin_q[28]=16'd5602; sin_q[29]=16'd5800; sin_q[30]=16'd5998; sin_q[31]=16'd6195;
        sin_q[32]=16'd6393; sin_q[33]=16'd6590; sin_q[34]=16'd6786; sin_q[35]=16'd6983; sin_q[36]=16'd7179; sin_q[37]=16'd7375; sin_q[38]=16'd7571; sin_q[39]=16'd7767;
        sin_q[40]=16'd7962; sin_q[41]=16'd8157; sin_q[42]=16'd8351; sin_q[43]=16'd8545; sin_q[44]=16'd8739; sin_q[45]=16'd8933; sin_q[46]=16'd9126; sin_q[47]=16'd9319;
        sin_q[48]=16'd9512; sin_q[49]=16'd9704; sin_q[50]=16'd9896; sin_q[51]=16'd10087; sin_q[52]=16'd10278; sin_q[53]=16'd10469; sin_q[54]=16'd10659; sin_q[55]=16'd10849;
        sin_q[56]=16'd11039; sin_q[57]=16'd11228; sin_q[58]=16'd11417; sin_q[59]=16'd11605; sin_q[60]=16'd11793; sin_q[61]=16'd11980; sin_q[62]=16'd12167; sin_q[63]=16'd12353;
        sin_q[64]=16'd12539; sin_q[65]=16'd12725; sin_q[66]=16'd12910; sin_q[67]=16'd13094; sin_q[68]=16'd13279; sin_q[69]=16'd13462; sin_q[70]=16'd13645; sin_q[71]=16'd13828;
        sin_q[72]=16'd14010; sin_q[73]=16'd14191; sin_q[74]=16'd14372; sin_q[75]=16'd14553; sin_q[76]=16'd14732; sin_q[77]=16'd14912; sin_q[78]=16'd15090; sin_q[79]=16'd15269;
        sin_q[80]=16'd15446; sin_q[81]=16'd15623; sin_q[82]=16'd15800; sin_q[83]=16'd15976; sin_q[84]=16'd16151; sin_q[85]=16'd16325; sin_q[86]=16'd16499; sin_q[87]=16'd16673;
        sin_q[88]=16'd16846; sin_q[89]=16'd17018; sin_q[90]=16'd17189; sin_q[91]=16'd17360; sin_q[92]=16'd17530; sin_q[93]=16'd17700; sin_q[94]=16'd17869; sin_q[95]=16'd18037;
        sin_q[96]=16'd18204; sin_q[97]=16'd18371; sin_q[98]=16'd18537; sin_q[99]=16'd18703; sin_q[100]=16'd18868; sin_q[101]=16'd19032; sin_q[102]=16'd19195; sin_q[103]=16'd19357;
        sin_q[104]=16'd19519; sin_q[105]=16'd19680; sin_q[106]=16'd19841; sin_q[107]=16'd20000; sin_q[108]=16'd20159; sin_q[109]=16'd20317; sin_q[110]=16'd20475; sin_q[111]=16'd20631;
        sin_q[112]=16'd20787; sin_q[113]=16'd20942; sin_q[114]=16'd21096; sin_q[115]=16'd21250; sin_q[116]=16'd21403; sin_q[117]=16'd21554; sin_q[118]=16'd21705; sin_q[119]=16'd21856;
        sin_q[120]=16'd22005; sin_q[121]=16'd22154; sin_q[122]=16'd22301; sin_q[123]=16'd22448; sin_q[124]=16'd22594; sin_q[125]=16'd22739; sin_q[126]=16'd22884; sin_q[127]=16'd23027;
        sin_q[128]=16'd23170; sin_q[129]=16'd23311; sin_q[130]=16'd23452; sin_q[131]=16'd23592; sin_q[132]=16'd23731; sin_q[133]=16'd23870; sin_q[134]=16'd24007; sin_q[135]=16'd24143;
        sin_q[136]=16'd24279; sin_q[137]=16'd24413; sin_q[138]=16'd24547; sin_q[139]=16'd24680; sin_q[140]=16'd24811; sin_q[141]=16'd24942; sin_q[142]=16'd25072; sin_q[143]=16'd25201;
        sin_q[144]=16'd25329; sin_q[145]=16'd25456; sin_q[146]=16'd25582; sin_q[147]=16'd25708; sin_q[148]=16'd25832; sin_q[149]=16'd25955; sin_q[150]=16'd26077; sin_q[151]=16'd26198;
        sin_q[152]=16'd26319; sin_q[153]=16'd26438; sin_q[154]=16'd26556; sin_q[155]=16'd26674; sin_q[156]=16'd26790; sin_q[157]=16'd26905; sin_q[158]=16'd27019; sin_q[159]=16'd27133;
        sin_q[160]=16'd27245; sin_q[161]=16'd27356; sin_q[162]=16'd27466; sin_q[163]=16'd27575; sin_q[164]=16'd27683; sin_q[165]=16'd27790; sin_q[166]=16'd27896; sin_q[167]=16'd28001;
        sin_q[168]=16'd28105; sin_q[169]=16'd28208; sin_q[170]=16'd28310; sin_q[171]=16'd28411; sin_q[172]=16'd28510; sin_q[173]=16'd28609; sin_q[174]=16'd28706; sin_q[175]=16'd28803;
        sin_q[176]=16'd28898; sin_q[177]=16'd28992; sin_q[178]=16'd29085; sin_q[179]=16'd29177; sin_q[180]=16'd29268; sin_q[181]=16'd29358; sin_q[182]=16'd29447; sin_q[183]=16'd29534;
        sin_q[184]=16'd29621; sin_q[185]=16'd29706; sin_q[186]=16'd29791; sin_q[187]=16'd29874; sin_q[188]=16'd29956; sin_q[189]=16'd30037; sin_q[190]=16'd30117; sin_q[191]=16'd30195;
        sin_q[192]=16'd30273; sin_q[193]=16'd30349; sin_q[194]=16'd30424; sin_q[195]=16'd30498; sin_q[196]=16'd30571; sin_q[197]=16'd30643; sin_q[198]=16'd30714; sin_q[199]=16'd30783;
        sin_q[200]=16'd30852; sin_q[201]=16'd30919; sin_q[202]=16'd30985; sin_q[203]=16'd31050; sin_q[204]=16'd31113; sin_q[205]=16'd31176; sin_q[206]=16'd31237; sin_q[207]=16'd31297;
        sin_q[208]=16'd31356; sin_q[209]=16'd31414; sin_q[210]=16'd31470; sin_q[211]=16'd31526; sin_q[212]=16'd31580; sin_q[213]=16'd31633; sin_q[214]=16'd31685; sin_q[215]=16'd31736;
        sin_q[216]=16'd31785; sin_q[217]=16'd31833; sin_q[218]=16'd31880; sin_q[219]=16'd31926; sin_q[220]=16'd31971; sin_q[221]=16'd32014; sin_q[222]=16'd32057; sin_q[223]=16'd32098;
        sin_q[224]=16'd32137; sin_q[225]=16'd32176; sin_q[226]=16'd32213; sin_q[227]=16'd32250; sin_q[228]=16'd32285; sin_q[229]=16'd32318; sin_q[230]=16'd32351; sin_q[231]=16'd32382;
        sin_q[232]=16'd32412; sin_q[233]=16'd32441; sin_q[234]=16'd32469; sin_q[235]=16'd32495; sin_q[236]=16'd32521; sin_q[237]=16'd32545; sin_q[238]=16'd32567; sin_q[239]=16'd32589;
        sin_q[240]=16'd32609; sin_q[241]=16'd32628; sin_q[242]=16'd32646; sin_q[243]=16'd32663; sin_q[244]=16'd32678; sin_q[245]=16'd32692; sin_q[246]=16'd32705; sin_q[247]=16'd32717;
        sin_q[248]=16'd32728; sin_q[249]=16'd32737; sin_q[250]=16'd32745; sin_q[251]=16'd32752; sin_q[252]=16'd32757; sin_q[253]=16'd32761; sin_q[254]=16'd32765; sin_q[255]=16'd32766;
    end
    // Q16.16 radians -> 16-bit turns (natural wrap = mod 2pi)
    function automatic logic [15:0] fx_turn(input logic signed [31:0] a);
        logic signed [47:0] p;
        p = 48'(a) * 48'sd10430; // 10430 = 65536 / 2pi
        fx_turn = p[31:16];
    endfunction
    // Sin of a 16-bit turn via quarter-wave ROM (Q1.15 signed)
    // flatten: unique case consumes sin_q_rdata (raddr last beat).
    function automatic logic signed [16:0] sin_from_q(
        input logic [15:0] t, input logic [15:0] q);
        sin_from_q = t[15] ? -$signed({1'b0, q}) : $signed({1'b0, q});
    endfunction

    // (a1 - a0) mod 2pi in Q16.16 (FM sweep computation)
    function automatic logic signed [31:0] fx_mod2pi(input logic signed [31:0] d);
        logic signed [31:0] r;
        r = d;
        if (r < 0) r = r + FX_2PI;
        if (r < 0) r = r + FX_2PI;
        if (r >= FX_2PI) r = r - FX_2PI;
        if (r >= FX_2PI) r = r - FX_2PI;
        fx_mod2pi = r;
    endfunction

    task automatic hs_ip(input logic [15:0] v); ip_ff <= v; hs_m_ip <= 1'b1; endtask
    task automatic hs_code(input logic [14:0] v); code_raddr_ff <= v; hs_m_code <= 1'b1; endtask
    task automatic hs_st(input st_t s); state <= s; hs_m_state <= 1'b1; endtask
    task automatic frame_gc_schedule;
        // Collection on allocation pressure remains immediate. Amortize
        // the optional frame-safe-point pass across four frames instead
        // of marking the entire persistent heap after every picture.
        gc_ran_this_frame <= 1'b0;
        if (gc_ran_this_frame || gc_frame_age != 2'd3) begin
            gc_frame_age <= gc_ran_this_frame ? 2'd0 : gc_frame_age + 2'd1;
            hs_st(S_WAIT_FRAME);
        end else begin
            gc_frame_age <= 2'd0;
            hs_vgc_clear_i(14'd0);
            hs_vgc_qr(14'd0);
            hs_vgc_qw(14'd0);
            hs_vgc_halt_after(1'b1);
            hs_vgc_wait_after(1'b1);
            hs_st(S_V64_GC_CLEAR);
        end
    endtask
    task automatic hs_vsp(input logic [11:0] v); vsp_ff <= v; hs_m_vsp <= 1'b1; endtask
    task automatic hs_hp_cmd(input logic [3:0] v); hp_cmd_ff <= v; hs_m_hp_cmd <= 1'b1; endtask
    task automatic hs_hp_oid(input logic [12:0] v); hp_oid_ff <= v; hs_m_hp_oid <= 1'b1; endtask
    task automatic hs_hp_aid(input logic [11:0] v); hp_aid_ff <= v; hs_m_hp_aid <= 1'b1; endtask
    task automatic hs_hp_env(input logic v); hp_env_ff <= v; hs_m_hp_env <= 1'b1; endtask
    task automatic hs_hp_eid(input logic [9:0] v); hp_eid_ff <= v; hs_m_hp_eid <= 1'b1; endtask
    task automatic hs_hp_slot(input logic [4:0] v); hp_slot_ff <= v; hs_m_hp_slot <= 1'b1; endtask
    // Next key on the same object/env: one Port-A wait in HEAP_CMP.
    task automatic hp_next_slot();
        begin
            hs_hp_slot(hp_slot + 5'd1);
            hp_slot_pend <= 1'b1;
        end
    endtask
    task automatic hs_hp_aslot(input logic [6:0] v); hp_aslot_ff <= v; hs_m_hp_aslot <= 1'b1; endtask
    task automatic hs_hp_len(input logic [5:0] v); hp_len_ff <= v; hs_m_hp_len <= 1'b1; endtask
    task automatic hs_hp_alen(input logic [7:0] v); hp_alen_ff <= v; hs_m_hp_alen <= 1'b1; endtask
    task automatic hs_hp_lim(input logic [7:0] v); hp_lim_ff <= v; hs_m_hp_lim <= 1'b1; endtask
    task automatic hs_hp_key(input logic [15:0] v); hp_key_ff <= v; hs_m_hp_key <= 1'b1; endtask
    task automatic hs_hp_wval(input logic [63:0] v); hp_wval_ff <= v; hs_m_hp_wval <= 1'b1; endtask
    task automatic hs_hp_rval(input logic [63:0] v); hp_rval_ff <= v; hs_m_hp_rval <= 1'b1; endtask
    task automatic hs_hp_hit(input logic v); hp_hit_ff <= v; hs_m_hp_hit <= 1'b1; endtask
    task automatic hs_hp_ret(input st_t v); hp_ret_ff <= v; hs_m_hp_ret <= 1'b1; endtask
    task automatic hs_hp_phase(input logic [2:0] v); hp_phase_ff <= v; hs_m_hp_phase <= 1'b1; endtask
    task automatic hs_hp_qn(input logic [2:0] v); hp_qn_ff <= v; hs_m_hp_qn <= 1'b1; endtask
    task automatic hs_hp_qi(input logic [2:0] v); hp_qi_ff <= v; hs_m_hp_qi <= 1'b1; endtask
    task automatic hs_hp_si(input logic [12:0] v); hp_si_ff <= v; hs_m_hp_si <= 1'b1; endtask
    task automatic hs_hp_ss(input logic [4:0] v); hp_ss_ff <= v; hs_m_hp_ss <= 1'b1; endtask
    task automatic hs_hp_tn(input logic [5:0] v); hp_tn_ff <= v; hs_m_hp_tn <= 1'b1; endtask
    task automatic hs_hp_from_stack(input logic v); hp_from_stack_ff <= v; hs_m_hp_from_stack <= 1'b1; endtask
    task automatic hs_hp_make_arr(input logic v); hp_make_arr_ff <= v; hs_m_hp_make_arr <= 1'b1; endtask
    task automatic hs_hp_vbase(input logic [11:0] v); hp_vbase_ff <= v; hs_m_hp_vbase <= 1'b1; endtask
    task automatic hs_hp_spr_w(input logic [15:0] v); hp_spr_w_ff <= v; hs_m_hp_spr_w <= 1'b1; endtask
    task automatic hs_hp_spr_h(input logic [15:0] v); hp_spr_h_ff <= v; hs_m_hp_spr_h <= 1'b1; endtask
    task automatic hs_hp_nat(input logic [3:0] v); hp_nat_ff <= v; hs_m_hp_nat <= 1'b1; endtask
    task automatic hs_valloc_kind(input [1:0] v); valloc_kind_ff <= v; hs_m_valloc_kind <= 1'b1; endtask
    task automatic hs_valloc_i(input [13:0] v); valloc_i_ff <= v; hs_m_valloc_i <= 1'b1; endtask
    task automatic hs_valloc_arr_n(input [7:0] v); valloc_arr_n_ff <= v; hs_m_valloc_arr_n <= 1'b1; endtask
    task automatic hs_valloc_retried(input logic v); valloc_retried_ff <= v; hs_m_valloc_retried <= 1'b1; endtask
    task automatic hs_vnat_dom(input [2:0] v); vnat_dom_ff <= v; hs_m_vnat_dom <= 1'b1; endtask
    task automatic hs_vnat_base(input [11:0] v); vnat_base_ff <= v; hs_m_vnat_base <= 1'b1; endtask
    task automatic hs_valloc_now_fn(input logic v); valloc_now_fn_ff <= v; hs_m_valloc_now_fn <= 1'b1; endtask
    task automatic hs_valloc_bind(input logic v); valloc_bind_ff <= v; hs_m_valloc_bind <= 1'b1; endtask
    task automatic hs_valloc_bind_src(input [12:0] v); valloc_bind_src_ff <= v; hs_m_valloc_bind_src <= 1'b1; endtask
    task automatic hs_valloc_bind_this(input [63:0] v); valloc_bind_this_ff <= v; hs_m_valloc_bind_this <= 1'b1; endtask
    task automatic hs_valloc_fn_entry(input [15:0] v); valloc_fn_entry_ff <= v; hs_m_valloc_fn_entry <= 1'b1; endtask
    task automatic hs_valloc_fn_a1(input [7:0] v); valloc_fn_a1_ff <= v; hs_m_valloc_fn_a1 <= 1'b1; endtask
    task automatic hs_valloc_proto(input logic v); valloc_proto_ff <= v; hs_m_valloc_proto <= 1'b1; endtask
    task automatic hs_valloc_proto_fn(input [12:0] v); valloc_proto_fn_ff <= v; hs_m_valloc_proto_fn <= 1'b1; endtask
    task automatic hs_valloc_metrics(input logic v); valloc_metrics_ff <= v; hs_m_valloc_metrics <= 1'b1; endtask
    task automatic hs_valloc_regex(input logic v); valloc_regex_ff <= v; hs_m_valloc_regex <= 1'b1; endtask
    task automatic hs_valloc_regex_pack(input [31:0] v); valloc_regex_pack_ff <= v; hs_m_valloc_regex_pack <= 1'b1; endtask
    task automatic hs_vcall_value(input logic v); vcall_value_ff <= v; hs_m_vcall_value <= 1'b1; endtask
    task automatic hs_vcall_argc(input [11:0] v); vcall_argc_ff <= v; hs_m_vcall_argc <= 1'b1; endtask
    task automatic hs_vcall_entry(input [15:0] v); vcall_entry_ff <= v; hs_m_vcall_entry <= 1'b1; endtask
    task automatic hs_vcall_set_this(input logic v); vcall_set_this_ff <= v; hs_m_vcall_set_this <= 1'b1; endtask
    task automatic hs_vcall_this(input [63:0] v); vcall_this_ff <= v; hs_m_vcall_this <= 1'b1; endtask
    task automatic hs_vcall_ctor_val(input [63:0] v); vcall_ctor_val_ff <= v; hs_m_vcall_ctor_val <= 1'b1; endtask
    task automatic hs_vcsp(input [7:0] v); vcsp_ff <= v; hs_m_vcsp <= 1'b1; endtask
    task automatic hs_vthis(input [63:0] v); vthis_ff <= v; hs_m_vthis <= 1'b1; endtask
    task automatic hs_venv(input [63:0] v); venv_ff <= v; hs_m_venv <= 1'b1; endtask
    task automatic hs_vraf_n(input [3:0] v); vraf_n_ff <= v; hs_m_vraf_n <= 1'b1; endtask
    task automatic hs_vlistener_n(input [4:0] v); vlistener_n_ff <= v; hs_m_vlistener_n <= 1'b1; endtask
    task automatic hs_vgc_halt_after(input logic v); vgc_halt_after_ff <= v; hs_m_vgc_halt_after <= 1'b1; endtask
    task automatic hs_vgc_wait_after(input logic v); vgc_wait_after_ff <= v; hs_m_vgc_wait_after <= 1'b1; endtask
    task automatic hs_vgc_clear_i(input [13:0] v); vgc_clear_i_ff <= v; hs_m_vgc_clear_i <= 1'b1; endtask
    task automatic hs_vgc_qr(input [13:0] v); vgc_qr_ff <= v; hs_m_vgc_qr <= 1'b1; endtask
    task automatic hs_vgc_qw(input [13:0] v); vgc_qw_ff <= v; hs_m_vgc_qw <= 1'b1; endtask
    task automatic hs_vdraw_i(input [18:0] v); vdraw_i_ff <= v; hs_m_vdraw_i <= 1'b1; endtask
    task automatic hs_vdraw_x(input [9:0] v); vdraw_x_ff <= v; hs_m_vdraw_x <= 1'b1; endtask
    task automatic hs_vdraw_y(input [9:0] v); vdraw_y_ff <= v; hs_m_vdraw_y <= 1'b1; endtask
    task automatic hs_vdraw_w(input [9:0] v); vdraw_w_ff <= v; hs_m_vdraw_w <= 1'b1; endtask
    task automatic hs_vdraw_h(input [9:0] v); vdraw_h_ff <= v; hs_m_vdraw_h <= 1'b1; endtask
    task automatic hs_vdraw_color(input [7:0] v); vdraw_color_ff <= v; hs_m_vdraw_color <= 1'b1; endtask
        task automatic e64_poke(input logic [5:0] sel, input logic [15:0] addr,
                            input logic [63:0] data);
        e64_p_we <= 1'b1;
        e64_p_sel <= sel;
        e64_p_addr <= addr;
        // Object alloc: copy parent gen into [43:32] so exec GET_PROP
        // matches the handle (dual-copy). Call sites keep packing len/builtin.
        // FORBIDDEN: dual-copy poke is not the legal shape.
        // One physical SRAM; do not paper over gen skew here.
        if (sel == 6'd44)
            e64_p_data <= {data[63:44], vobj_gen_rdata, data[31:0]};
        else
            e64_p_data <= data;
    endtask

    // After a ctor param LET_VAR: skip the compiler JUMP to class fields.
    task automatic ctor_after_let;
        if (vctor_lets == 6'd1 && vctor_jmp != 16'hFFFF) begin
            hs_ip(vctor_jmp);
            hs_code(15'(ops_base + vctor_jmp));
            vctor_jmp <= 16'hFFFF;
            vctor_lets <= 6'd0;
        end else begin
            hs_ip(ip + 16'd1);
            hs_code(15'(ops_base + ip + 16'd1));
            if (vctor_lets != 6'd0)
                vctor_lets <= vctor_lets - 6'd1;
        end
    endtask
    // Consume one trailer byte; word wrap → S_RD (must not run on intern/done)

    // Object/array slot SRAM: 1 write + 1 registered read (VRAM Port A),
    // now pow2-chunked. Registered chunk selects keep the 1-beat contract.
    logic [79:0] vobj_r_c0, vobj_r_c1, vobj_r_c2, vobj_r_c3;
    logic [1:0]  vobj_rsel;
    logic [63:0] varr_r_c0, varr_r_c1, varr_r_c2;
    logic [1:0]  varr_rsel;
    logic [79:0] venv_r_c0, venv_r_c1;
    logic        venv_rsel;
    always_ff @(posedge clk) begin
        if (vobj_we) begin
            if (vobj_waddr < 15'd16384)
                vobj_slot_c0[vobj_waddr[13:0]] <= vobj_wdata;
            else if (vobj_waddr < 15'd24576)
                vobj_slot_c1[vobj_waddr[12:0] & 13'h1FFF] <= vobj_wdata;
            else if (vobj_waddr < 15'd28672)
                vobj_slot_c2[vobj_waddr[11:0] & 12'hFFF] <= vobj_wdata;
            else
                vobj_slot_c3[vobj_waddr[10:0] & 11'h7FF] <= vobj_wdata;
        end
        vobj_r_c0 <= vobj_slot_c0[vobj_raddr[13:0]];
        vobj_r_c1 <= vobj_slot_c1[(vobj_raddr - 15'd16384) & 15'h1FFF];
        vobj_r_c2 <= vobj_slot_c2[(vobj_raddr - 15'd24576) & 15'hFFF];
        vobj_r_c3 <= vobj_slot_c3[(vobj_raddr - 15'd28672) & 15'h7FF];
        vobj_rsel <= (vobj_raddr < 15'd16384) ? 2'd0 :
                     (vobj_raddr < 15'd24576) ? 2'd1 :
                     (vobj_raddr < 15'd28672) ? 2'd2 : 2'd3;
        if (varr_we) begin
            if (varr_waddr < 16'd32768)
                varr_slot_c0[varr_waddr[14:0]] <= varr_wdata;
            else if (varr_waddr < 16'd49152)
                varr_slot_c1[varr_waddr[13:0] & 14'h3FFF] <= varr_wdata;
            else
                varr_slot_c2[varr_waddr[10:0] & 11'h7FF] <= varr_wdata;
        end
        varr_r_c0 <= varr_slot_c0[varr_raddr[14:0]];
        varr_r_c1 <= varr_slot_c1[(varr_raddr - 16'd32768) & 16'h3FFF];
        varr_r_c2 <= varr_slot_c2[(varr_raddr - 16'd49152) & 16'h7FF];
        varr_rsel <= (varr_raddr < 16'd32768) ? 2'd0 :
                     (varr_raddr < 16'd49152) ? 2'd1 : 2'd2;
        if (venv_we) begin
            if (venv_waddr < 13'd4096)
                venv_slot_c0[venv_waddr[11:0]] <= venv_wdata;
            else
                venv_slot_c1[venv_waddr[10:0] & 11'h7FF] <= venv_wdata;
        end
        venv_r_c0 <= venv_slot_c0[venv_raddr[11:0]];
        venv_r_c1 <= venv_slot_c1[(venv_raddr - 13'd4096) & 13'h7FF];
        venv_rsel <= (venv_raddr >= 13'd4096);
    end
    assign vobj_rdata = (vobj_rsel == 2'd0) ? vobj_r_c0 :
                        (vobj_rsel == 2'd1) ? vobj_r_c1 :
                        (vobj_rsel == 2'd2) ? vobj_r_c2 : vobj_r_c3;
    assign varr_rdata = (varr_rsel == 2'd0) ? varr_r_c0 :
                        (varr_rsel == 2'd1) ? varr_r_c1 : varr_r_c2;
    assign venv_rdata = venv_rsel ? venv_r_c1 : venv_r_c0;

    // Value64 operand stack: 1 write + 1 registered read (same as vobj_slot).
    // Exec keeps priority in its own states, but the arm must be
    // `e64_vst_we_q && <state>` — not `<state>` alone. vst_we is a
    // registered pulse, so a parent vst_wr() issued the same beat as
    // hs_st(S_FETCH_WAIT) lands with state already FETCH_WAIT and used to
    // be swallowed with no writer at all: MAKE_ARRAY planted its handle
    // only in vst_win (nested [[..],[..]] read back the inner's first
    // element), STRIDX_WR / S_V64_RECT lost their result the same way.
    // Still one write port — the two arms are mutually exclusive.
    // ONE write statement so 1W is provable — the if/else
    // pair kept vstack "Infeasible attribute ram_style=block" (LUTRAM,
    // 704 RAM64M of SLICEM inside the congested cluster).
    // Same recipe that fixed name_has (census: 7.7k LUTs from a split
    // writer). Priority preserved: exec-qualified write wins, exactly
    // as the old else-if. Gate: the Final Mapping table must say
    // Block RAM — the attribute alone is not inference.
    always_ff @(posedge clk) begin
        logic        vst_do;
        logic [9:0]  vst_a;
        logic [63:0] vst_d;
        logic        e64_w;
        e64_w = e64_vst_we_q && e64_wr_ok &&
            (state == S_V64_EXEC ||
             state == S_FETCH_WAIT ||
             state == S_V64_WIN_FILL);
        vst_do = e64_w || vst_we;
        vst_a  = e64_w ? e64_vst_waddr_q[9:0] : vst_waddr[9:0];
        vst_d  = e64_w ? e64_vst_wdata_q : vst_wdata;
        if (vst_do) vstack[vst_a] <= vst_d;
        vst_rdata <= vstack[vst_raddr[9:0]];
    end

    always_comb begin
        vobj_we = (state == S_HEAP_WR) && !hp_env;
        vobj_waddr = (hp_cmd == HP_OSETI)
            ? VOBJ_AW'({hp_oid, hp_slot + {2'd0, hp_qi[2:0]}})
            : VOBJ_AW'({hp_oid, hp_slot});
        vobj_wdata = (hp_cmd == HP_OSETI)
            ? {hp_qk[hp_qi[1:0]], hp_qv[hp_qi[1:0]]}
            : {hp_key, hp_wval};
        vobj_raddr = VOBJ_AW'({hp_oid, hp_slot});
        // HEAP_AWR: first cycle muxes varr_long[hp_aid]; write when hp_slot_arm
        // (long_rdata valid). Stale 0 = wait, never peek.
        varr_we = (state == S_HEAP_AWR && hp_slot_arm) ||
            (state == S_HEAP_FILL &&
             !(hp_from_stack && hp_phase != 3'd1));
        varr_waddr = hp_prom_wr
            ? VARR_AW'(VARR_SHORT_WORDS + {1'b0, hp_prom_phys, hp_aslot})
            : varr_slot_addr(hp_aid, hp_aslot);
        varr_wdata = hp_from_stack
            ? vst_rdata
            : hp_wval;
        varr_raddr = varr_slot_addr(hp_aid, hp_aslot);
        venv_we = (state == S_HEAP_WR) && hp_env;
        venv_waddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        venv_wdata = {7'd0, hp_key[8:0], hp_wval};
        venv_raddr = VENV_AW'({hp_eid, hp_slot[3:0]});
        // Address mux only (narrow). unique is OK here; the 70 GB cone was
        // unique case (casestate) on the parent FSM, not this raddr comb.
        unique case (state)
            S_V64_GC_OBJ:
                vobj_raddr = VOBJ_AW'({vgc_cur[12:0], vgc_slot_i[4:0]});
            S_V64_GC_ARR:
                varr_raddr = varr_slot_addr(vgc_cur[11:0], vgc_slot_i[6:0]);
            S_V64_GC_ENV:
                if (vgc_slot_i != 0)
                    venv_raddr = VENV_AW'(
                        {vgc_cur[9:0], vgc_slot_i[3:0] - 4'd1}
                    );
            S_V64_FOREACH:
                varr_raddr = varr_slot_addr(e64_vfe_arr_q[11:0], e64_vfe_i_q[6:0]);
            S_JOIN:
                varr_raddr = varr_slot_addr(jn_arr, jn_i[6:0]);
            S_V64_JSON:
                if (js_sp != 0) begin
                    varr_raddr = varr_slot_addr(
                        vjs_val[js_sp - 6'd1][11:0], js_i[js_sp - 6'd1][6:0]
                    );
                    vobj_raddr = VOBJ_AW'(
                        {vjs_val[js_sp - 6'd1][12:0], js_i[js_sp - 6'd1][4:0]}
                    );
                end
            default: ;
        endcase
        if ((state == S_HEAP_WAIT || state == S_HEAP_CMP) &&
            hp_cmd == HP_ASSIGN && hp_phase == 3'd0)
            vobj_raddr = VOBJ_AW'({hp_si, hp_ss});
    end

    always_comb begin
        vst_raddr = (vsp >= 12'd16) ? (vsp - 12'd16) : 12'd0;
        // Exec-issued push enters S_HEAP_FILL with a
        // leave beat (casestate FILL, parent state still EXEC). The phase
        // 0->1 sequencer runs on casestate, but this raddr was gated on
        // parent state only, so the write beat stored vst_rdata registered
        // from the DEFAULT raddr (vsp-16 / 0) — a garbage word — into the
        // array slot. Length was right (varr_len_we in exec), elements were
        // junk: a.push(x); a[0] returned a stale stack word. Parent-issued
        // fills (MAKE_ARRAY literals via S_V64_ALLOC) have no leave beat,
        // which is why literals worked and push did not.
        // casestate_q lags one beat, so on
        // the FIRST S_V64_WIN_FILL beat after a make_arr fill this branch was
        // still taken (casestate_q==S_HEAP_FILL): raddr = hp_vbase+hp_aslot
        // (the LAST ELEMENT) instead of vsp-1-refill_i. The refill's first
        // consumed rdata was that element, so win[1] got e.g. 15.0 where the
        // receiver object should be — SET_PROP silently dropped `{m:[16+]}`
        // (PACMAN maze). Exclude the beat once state is WIN_FILL.
        // RECT's existing address beat now registers its transform. Read
        // arg0 on the leave beat, and arg(k+1) while consuming arg(k).
        if (state==S_V64_CALLREF)
            vst_raddr = vsp - {4'd0,e64_opw[31:24]} - (callref_phase<2 ? 12'd1:12'd2);
        if (e64_arg_stack_read && state!=S_V64_CALLREF) vst_raddr = e64_arg_stack_addr;
        else if ((state == S_HEAP_WAIT || state == S_HEAP_CMP) && hp_cmd == HP_ASSIGN && hp_phase == 3'd3)
            vst_raddr = assign_src_addr;
        else if (state == S_V64_RECT_LD || casestate == S_V64_RECT_LD)
            vst_raddr = vnat_base + 12'd1 +
                (state != S_V64_RECT_LD ? 12'd0 :
                 {10'd0,rect_ld_k} +
                 ((rect_ld_arm && rect_ld_k != 2'd3) ? 12'd1 : 12'd0));
        else if ((state == S_HEAP_FILL ||
             (casestate_q == S_HEAP_FILL && state != S_V64_WIN_FILL)) &&
            hp_from_stack)
            vst_raddr = hp_vbase + {5'd0, hp_aslot};
        else if (state == S_V64_BIND)
            vst_raddr = bind_src + {4'd0, bind_k};
        else if (state == S_V64_MINMAX)
            vst_raddr = minmax_base + {4'd0, minmax_k};
        else if (state == S_V64_WIN_FILL)
            vst_raddr = vsp - {8'd0, vst_refill_i} - 12'd1;
        else if (state == S_V64_GC_ROOT && vgc_root_phase == 3'd1)
            vst_raddr = vgc_root_i;
    end

    // KEYBITS poke is sequential-heap (no combo slot mux). Tagged path
    // arms HP_SETPROP from S_WAIT_FRAME; this task is a no-op stub.
    
    always_comb begin
        case (trail_off[1:0])
            2'd0: trail_tb = code_rdata[7:0];
            2'd1: trail_tb = code_rdata[15:8];
            2'd2: trail_tb = code_rdata[23:16];
            default: trail_tb = code_rdata[31:24];
        endcase
    end
    logic [8:0] e32_intern_var_rdata;
    logic e32_intern_var_ok_rdata;
    logic [15:0] e32_char_id_rdata;
    logic e32_char_ok_rdata;
    logic e32_name_has_tos;
    logic [7:0] e32_name_len_tos;
    logic [15:0] e32_name_off_tos;
    logic [7:0] fill_lut_rdata;
    logic [255:0] spr_hh_pack, spr_nid_pack, spr_ww_pack;
    logic [63:0] hp_qk_ff_pack;
    logic [11:0] hp_qt_ff_pack;
    logic [255:0] hp_qv_ff_pack;
    // HEAP/FETCH handshake: parent writes these FFs; exec applies only
    // the masked scalars (ip / hp_* / code_raddr / state). Not a full FF dump.
    logic hs64 /*verilator public_flat_rd*/; 
    logic hs_m_ip /*verilator public_flat_rd*/, hs_m_code /*verilator public_flat_rd*/, hs_m_state /*verilator public_flat_rd*/, hs_m_vsp;
    logic hs_m_hp_cmd, hs_m_hp_oid, hs_m_hp_aid, hs_m_hp_env;
    logic hs_m_hp_eid /*verilator public_flat_rd*/; logic hs_m_hp_slot, hs_m_hp_aslot, hs_m_hp_len, hs_m_hp_alen;
    logic hs_m_hp_lim, hs_m_hp_key, hs_m_hp_wval, hs_m_hp_rval, hs_m_hp_hit;
    logic hs_m_hp_ret, hs_m_hp_phase, hs_m_hp_qn, hs_m_hp_qi;
    logic hs_m_hp_si, hs_m_hp_ss, hs_m_hp_tn, hs_m_hp_from_stack, hs_m_hp_make_arr;
    logic hs_m_hp_vbase, hs_m_hp_spr_w, hs_m_hp_spr_h, hs_m_hp_nat;
    logic hs_m_hp_qk, hs_m_hp_qv, hs_m_hp_qt;
    logic hs_m_valloc_kind, hs_m_valloc_i, hs_m_valloc_arr_n, hs_m_valloc_retried, hs_m_vnat_dom, hs_m_vnat_base, hs_m_valloc_now_fn, hs_m_valloc_bind, hs_m_valloc_bind_src, hs_m_valloc_bind_this, hs_m_valloc_fn_entry, hs_m_valloc_fn_a1, hs_m_valloc_proto, hs_m_valloc_proto_fn, hs_m_valloc_metrics, hs_m_valloc_regex, hs_m_valloc_regex_pack, hs_m_vcall_value, hs_m_vcall_argc, hs_m_vcall_entry, hs_m_vcall_set_this, hs_m_vcall_this, hs_m_vcall_ctor_val, hs_m_vcsp, hs_m_vthis; logic hs_m_venv /*verilator public_flat_rd*/;
    logic hs_m_vraf_n /*verilator public_flat_rd*/;
    logic hs_m_vlistener_n, hs_m_vgc_halt_after, hs_m_vgc_wait_after, hs_m_vgc_clear_i, hs_m_vgc_qr, hs_m_vgc_qw;
    logic hs_m_vdraw_i, hs_m_vdraw_x, hs_m_vdraw_y, hs_m_vdraw_w, hs_m_vdraw_h, hs_m_vdraw_color;
    logic hs_m_vfe_i, hs_m_vfe_pop;

    logic e64_p_clr, e64_p_we;
    logic [5:0] e64_p_sel;
    logic [15:0] e64_p_addr, e64_p_addr2;
    logic [63:0] e64_p_data, e64_p_data2, e64_p_data3, e64_p_data4, e64_p_data5;
    logic e64_p_frame_we;
    logic [6:0] e64_p_frame_idx;
    logic [15:0] e64_p_frame_rip;
    logic [11:0] e64_p_frame_bsp;
    logic e64_p_frame_esc;
    logic [63:0] e64_p_frame_this, e64_p_frame_env, e64_p_frame_fnv, e64_p_frame_ctor;

    // Hierarchical jmr_js_vm_exec64: keep_hierarchy so Vivado does not flatten
    // the opcode mux back into the parent always_ff.
    logic [7:0] e64_bind_argc_q;
    logic [11:0] e64_bind_base_q;
    logic [15:0] e64_bind_ip_q;
    logic [7:0] e64_bind_k_q;
    logic [1:0] e64_bind_mode_q;
    logic [7:0] e64_bind_n_q;
    logic e64_bind_rd_arm_q;
    logic [6:0] e64_bind_ret_q;
    logic [11:0] e64_bind_src_q;
    logic [11:0] e64_bind_vsp_next_q;
    logic [15:0] e64_blit_sh_q;
    logic [7:0] e64_blit_si_q;
    logic e64_flip_x_q, e64_flip_y_q;
    logic [15:0] e64_blit_sw_q;
    logic [15:0] e64_blit_sx_q;
    logic [15:0] e64_blit_sy_q;
    logic [2:0] e64_cc_at_q;
    logic signed [31:0] e64_cc_av_q;
    logic e64_cc_bok_q;
    logic [2:0] e64_cc_bt_q;
    logic signed [31:0] e64_cc_bv_q;
    logic [3:0] e64_cc_d_q;
    logic [15:0] e64_cc_h_q;
    logic [7:0] e64_cc_len_q;
    logic e64_cc_second_q;
    logic [1:0] e64_cc_st_q;
    logic [14:0] e64_code_raddr_q;
    logic [7:0] e64_color_q;
    logic [1:0] e64_ctx_align_q;
    logic signed [31:0] e64_ctx_sx_q /*verilator public_flat_rd*/;
    logic signed [31:0] e64_ctx_sy_q;
    logic signed [31:0] e64_ctx_tx_q;
    logic signed [31:0] e64_ctx_ty_q;
    logic [15:0] e64_dbg_di_hit_q /*verilator public_flat_rd*/;
    logic [15:0] e64_dbg_di_miss_q /*verilator public_flat_rd*/;
    logic [7:0] e64_fault_code_q;
    logic [15:0] e64_fault_site_q;
    logic [31:0] e64_fault_arg_q;
    logic [18:0] e64_fb_dump_addr_q;
    logic e64_fb_swap_q;
    logic [11:0] e64_hp_aid_q;
    logic [7:0] e64_hp_alen_q;
    logic [6:0] e64_hp_aslot_q;
    logic [3:0] e64_hp_cmd_q;
    logic [9:0] e64_hp_eid_q /*verilator public_flat_rd*/;
    logic e64_hp_env_q;
    logic e64_hp_from_stack_q;
    logic e64_hp_hit_q;
    logic [15:0] e64_hp_key_q;
    logic [5:0] e64_hp_len_q;
    logic [7:0] e64_hp_lim_q;
    logic e64_hp_make_arr_q;
    logic [3:0] e64_hp_nat_q;
    logic [12:0] e64_hp_oid_q;
    logic [2:0] e64_hp_phase_q;
    logic [63:0] e64_hp_proto_q;
    logic [2:0] e64_hp_qi_q;
    logic [2:0] e64_hp_qn_q;
    logic [6:0] e64_hp_ret_q;
    logic [63:0] e64_hp_rval_q;
    logic [12:0] e64_hp_si_q;
    logic [4:0] e64_hp_slot_q;
    logic [15:0] e64_hp_spr_h_q;
    logic [15:0] e64_hp_spr_w_q;
    logic [4:0] e64_hp_ss_q;
    logic [5:0] e64_hp_tn_q;
    logic [11:0] e64_hp_vbase_q;
    logic [63:0] e64_hp_wval_q;
    logic [9:0] e64_imgd_h_q;
    logic [18:0] e64_imgd_i_q;
    logic [18:0] e64_imgd_n_q;
    logic e64_imgd_v64_q;
    logic [9:0] e64_imgd_w_q;
    logic [9:0] e64_imgd_x_q;
    logic [9:0] e64_imgd_x0_q;
    logic [9:0] e64_imgd_y_q;
    logic [9:0] e64_imgd_y0_q;
    logic [15:0] e64_ip_q;
    logic [11:0] e64_jn_arr_q;
    logic [15:0] e64_jn_h_q;
    logic [15:0] e64_jn_i_q;
    logic [10:0] e64_jn_res_q;
    logic [5:0] e64_js_sp_q;
    logic [2:0] e64_json_pph_q;
    logic [13:0] e64_json_rp_q;
    logic [13:0] e64_json_src_q;
    logic [13:0] e64_json_srclen_q;
    logic [13:0] e64_json_wp_q;
    logic e64_machine_fault_q;
    logic [63:0] e64_minmax_acc_q;
    logic [2:0]  e64_csr_mode_q;
    logic [21:0] e64_csr_addr_q;
    logic [15:0] e64_csr_wdata_q;
    logic        e64_csr_oob_q;
    logic [11:0] e64_minmax_base_q;
    logic e64_minmax_is_min_q;
    logic [7:0] e64_minmax_k_q;
    logic [7:0] e64_minmax_n_q;
    logic e64_namcpy_repl_q;
    logic e64_namcpy_v64_q;
    logic [15:0] e64_name_rdaddr_q;
    logic e64_path_stroke_q;
    logic [4:0] e64_pc_n_q;
    // #49: path-command write mirror from exec64 into the parent arrays that
    // S_PWALK actually rasters from.
    // #54: stringify seed mirror
    logic e64_js_we_q;
    logic [4:0] e64_js_waddr_q;
    logic [7:0] e64_js_i_wdata_q;
    logic [2:0] e64_js_ph_wdata_q;
    logic [63:0] e64_vjs_val_wdata_q;
    logic e64_pc_we_q;
    logic [3:0] e64_pc_waddr_q;
    logic [1:0] e64_pc_op_wdata_q;
    logic signed [31:0] e64_pc_a1_wdata_q, e64_pc_a2_wdata_q;
    logic signed [31:0] e64_pc_a3_wdata_q, e64_pc_a4_wdata_q, e64_pc_a5_wdata_q;
    logic e64_pc_ccw_wdata_q;
    logic e64_repl_g_q;
    logic [7:0] e64_repl_pat0_q;
    logic [7:0] e64_repl_rch_q;
    logic [9:0] e64_rh_q;
    logic [9:0] e64_rw_q;
    logic signed [11:0] e64_rx_q;
    logic signed [11:0] e64_ry_q;
    logic [4:0] e64_sq_i_q;
    logic [47:0] e64_sq_rad_q;
    logic [25:0] e64_sq_rem_q;
    logic [23:0] e64_sq_root_q;
    logic [6:0] e64_state_q;
    logic [6:0] e64_txt_bn_q;
    logic [3:0] e64_txt_ph_q;
    logic signed [15:0] e64_txt_px_q;
    logic signed [15:0] e64_txt_py_q;
    logic [31:0] e64_txt_val_q;
    logic [2:0] e64_txt_vt_q;
    logic e64_v64_concat_q;
    logic e64_v64_join_q;
    logic e64_v64_sqrt_q;
    logic [7:0] e64_valloc_arr_n_q;
    logic e64_valloc_bind_q;
    logic [12:0] e64_valloc_bind_src_q;
    logic [63:0] e64_valloc_bind_this_q;
    logic [7:0] e64_valloc_fn_a1_q;
    logic [15:0] e64_valloc_fn_entry_q;
    logic [13:0] e64_valloc_i_q;
    logic [1:0] e64_valloc_kind_q;
    logic e64_valloc_metrics_q;
    logic e64_valloc_now_fn_q;
    logic e64_valloc_proto_q;
    logic [12:0] e64_valloc_proto_fn_q;
    logic e64_valloc_regex_q;
    logic [31:0] e64_valloc_regex_pack_q;
    logic e64_valloc_retried_q;
    logic [11:0] e64_vcall_argc_q;
    logic [63:0] e64_vcall_ctor_val_q;
    logic [15:0] e64_vcall_entry_q;
    logic e64_vcall_set_this_q;
    logic [63:0] e64_vcall_this_q;
    logic e64_vcall_value_q;
    logic [7:0] e64_vcsp_q;
    logic [7:0] e64_vdiv_count_q;
    logic [52:0] e64_vdiv_den_q;
    logic signed [12:0] e64_vdiv_exp_q;
    logic [106:0] e64_vdiv_num_q;
    logic [106:0] e64_vdiv_quot_q;
    logic [53:0] e64_vdiv_rem_q;
    logic e64_vdiv_sign_q;
    logic [7:0] e64_vdraw_color_q;
    logic [9:0] e64_vdraw_h_q;
    logic [18:0] e64_vdraw_i_q;
    logic [9:0] e64_vdraw_w_q;
    logic [9:0] e64_vdraw_x_q;
    logic [9:0] e64_vdraw_y_q;
    logic [63:0] e64_venv_q /*verilator public_flat_rd*/;
    logic [63:0] e64_vfe_arr_q;
    logic [11:0] e64_vfe_base_q;
    logic [63:0] e64_vfe_fn_q;
    logic [7:0] e64_vfe_i_q;
    logic [7:0] e64_vfe_len_q;
    logic [63:0] e64_vfe_map_q;
    logic e64_vfe_reduce_q;
    logic e64_vfe_findidx_q;
    logic [1:0] e64_vfe_mode_q;
    logic [15:0] e64_vfe_ret_q;
    logic [3:0] e64_vfe_sp_q;
    logic [13:0] e64_vgc_clear_i_q;
    logic e64_vgc_halt_after_q;
    logic [13:0] e64_vgc_qr_q;
    logic [13:0] e64_vgc_qw_q;
    logic e64_vgc_wait_after_q;
    logic [4:0] e64_vlistener_n_q;
    logic [31:0] e64_vmetrics_w_q;
    logic [11:0] e64_vmod_count_q;
    logic [52:0] e64_vmod_den_q;
    logic signed [12:0] e64_vmod_exp_q;
    logic [52:0] e64_vmod_rem_q;
    logic e64_vmod_sign_q;
    logic [11:0] e64_vnat_base_q;
    logic [2:0] e64_vnat_dom_q;
    logic e64_vprom_copy_q;
    logic [6:0] e64_vprom_ret_q;
    logic [3:0] e64_vraf_n_q;
    logic [11:0] e64_vsp_q;
    logic e64_vst_hold_win_q;
    logic e64_vst_refill_arm_q;
    logic [3:0] e64_vst_refill_i_q;
    logic [6:0] e64_vst_refill_ret_q;
    logic [11:0] e64_vst_waddr_q;
    logic [63:0] e64_vst_wdata_q;
    logic e64_vst_we_q;
    logic [63:0] e64_vthis_q;
    logic [9:0] e64_x_q;
    logic [9:0] e64_y_q;
    logic [63:0] e64_hp_qk_pack_q;
    logic [11:0] e64_hp_qt_pack_q;
    logic [255:0] e64_hp_qv_pack_q;
    logic e64_json_mem_we;
    logic [12:0] e64_json_mem_waddr;
    logic [7:0] e64_json_mem_wdata;
    logic [9:0] e64_name_blen_raddr;
    logic e64_name_blen_we;
    logic [9:0] e64_name_blen_waddr;
    logic [15:0] e64_name_blen_wdata;
    logic [9:0] e64_name_hash_raddr;
    logic e64_name_hash_we;
    logic [9:0] e64_name_hash_waddr;
    logic [15:0] e64_name_hash_wdata;
    logic e64_name_has_we;
    logic [9:0] e64_name_has_waddr;
    logic e64_name_has_wdata;
    logic [15:0] name_blen_rdata;
    logic [15:0] name_hash_rdata;
    // Exec64 heap raddr (parent SRAM, rdata next clock).
    logic [8:0] e64_vvars_raddr;
    logic [11:0] e64_varr_raddr;
    logic [12:0] e64_vobj_raddr;
    logic [12:0] e64_vfn_raddr;
    logic [9:0] e64_name_off_raddr;
    logic [9:0] e64_fill_lut_raddr;
    logic [6:0] e64_vframe_raddr;
    logic [5:0] e64_vtimer_raddr;
    logic [9:0] e64_vconsts_raddr;
    logic [63:0] vvars_rdata;
    logic vvar_valid_rdata;
    logic [63:0] venv_parent_rdata;
    logic [4:0] venv_len_rdata /*verilator public_flat_rd*/;
    logic [11:0] venv_gen_rdata;
    logic venv_valid_rdata /*verilator public_flat_rd*/;
    logic [7:0] varr_len_rdata;
    logic varr_valid_rdata;
    logic [11:0] varr_gen_rdata;
    logic varr_long_rdata;
    logic [7:0] varr_lidx_rdata;
    logic [1:0] vobj_alloc_rdata;
    logic [11:0] vobj_gen_rdata;
    logic vobj_mark_rdata, vfn_mark_rdata, varr_mark_rdata, venv_mark_rdata;
    logic [63:0] vobj_proto_rdata;
    logic [15:0] vobj_cls_rdata;
    logic [5:0] vobj_len_rdata;
    logic [3:0] vobj_builtin_rdata;
    logic vfn_valid_rdata;
    logic [11:0] vfn_gen_rdata;
    logic [63:0] vfn_proto_rdata;
    logic [63:0] vfn_env_rdata;
    logic [5:0] vfn_nparam_rdata;
    logic [15:0] vfn_entry_rdata;
    logic [2:0] vfn_flags_rdata;
    logic [63:0] vfn_bound_this_rdata;
    logic [63:0] vconsts_rdata;
    logic [15:0] vframe_rip_rdata;
    logic [11:0] vframe_bsp_rdata;
    logic vframe_esc_rdata;
    logic vframe_setter_rdata;
    logic vfr_setter;
    logic [1:0] setter_pending;
    logic image_setters;
    logic [15:0] cls_sip_q;
    logic [63:0] vframe_this_rdata;
    logic [63:0] vframe_env_rdata;
    logic [63:0] vframe_fn_rdata;
    logic [63:0] vframe_ctor_rdata;
    logic vtimer_valid_rdata;
    logic signed [31:0] vtimer_id_rdata;
    logic [15:0] name_off_rdata;
    logic e64_varr_len_we;
    logic [11:0] e64_varr_len_waddr;
    logic [7:0] e64_varr_len_wdata;
    logic e64_varr_lidx_we;
    logic [11:0] e64_varr_lidx_waddr;
    logic [7:0] e64_varr_lidx_wdata;
    logic e64_varr_long_we;
    logic [11:0] e64_varr_long_waddr;
    logic [31:0] e64_varr_long_wdata;
    logic e64_varr_valid_we;
    logic [11:0] e64_varr_valid_waddr;
    logic [31:0] e64_varr_valid_wdata;
    logic e64_venv_gen_we;
    logic [11:0] e64_venv_gen_waddr;
    logic [11:0] e64_venv_gen_wdata;
    logic e64_venv_len_we;
    logic [11:0] e64_venv_len_waddr;
    logic [4:0] e64_venv_len_wdata;
    logic e64_venv_valid_we;
    logic [11:0] e64_venv_valid_waddr;
    logic [31:0] e64_venv_valid_wdata;
    logic e64_vobj_cls_we;
    logic [11:0] e64_vobj_cls_waddr;
    logic [15:0] e64_vobj_cls_wdata;
    logic e64_vvar_valid_we;
    logic [11:0] e64_vvar_valid_waddr;
    logic [31:0] e64_vvar_valid_wdata;
    logic e64_vvars_we;
    logic [11:0] e64_vvars_waddr;
    logic [63:0] e64_vvars_wdata;
    logic e64_vframe_we;
    logic [31:0] e64_opw;
    logic [6:0] e64_vframe_waddr;
    logic [15:0] e64_vframe_rip_wdata;
    logic [11:0] e64_vframe_bsp_wdata;
    logic e64_vframe_esc_wdata;
    logic [63:0] e64_vframe_this_wdata;
    logic [63:0] e64_vframe_env_wdata;
    logic [63:0] e64_vframe_fn_wdata;
    logic [63:0] e64_vframe_ctor_wdata;
    logic e64_p_clr_busy;
    logic e64_leave_hold /*verilator public_flat_rd*/;
    /* Skip guard: after ANY parent-flow excursion, the next op must
       take the REAL fetch-wait (its dispatch arm carries return
       bookkeeping). Armed from the PARENT's muxed state — the only vantage
       that sees excursions (exec64's internal state stays parked in EXEC
       through them; both exec64-side provenance schemes were blind).
       Cleared only by the fetch-wait dispatch arm itself. */
    logic pf_post_parent /*verilator public_flat_rd*/;
    logic e64_vraf_we;
    logic [2:0] e64_vraf_waddr;
    logic [63:0] e64_vraf_wdata;
    logic e64_vtimer_we;
    logic [5:0] e64_vtimer_waddr;
    logic e64_vtimer_valid_wdata;
    logic signed [31:0] e64_vtimer_due_wdata;
    logic [63:0] e64_vtimer_fn_wdata;
    logic signed [31:0] e64_vtimer_id_wdata;
    logic signed [63:0] e64_vtimer_period_wdata;
    logic e64_vst_win0_we;
    logic [63:0] e64_vst_win0_wdata;
    logic e64_arg_stack_read;
    logic [11:0] e64_arg_stack_addr;
    wire [11:0] assign_src_addr = hp_vbase + {4'd0,hp_alen} + 12'd1;
    wire [63:0] assign_src_value = (vsp > assign_src_addr && vsp-assign_src_addr-12'd1 < 12'd16)
        ? `VST_AT(assign_src_addr) : vst_rdata;
    (* keep_hierarchy = "yes" *)
    jmr_js_vm_exec64 u_exec64 (
        .arg_stack_read(e64_arg_stack_read), .arg_stack_addr(e64_arg_stack_addr),
        .arg_stack_data(vst_rdata),
        .clk(clk),
        .image_callref(image_setters),
        .rst_n(rst_n),
        .enable((state == S_V64_EXEC)),
        .leave_hold(e64_leave_hold),
        .hs_m_ip(hs_m_ip),
        .hs_m_code(hs_m_code),
        /* skip-suppress while the parent's ctor-LET redirect or field
           scan is armed — their between-op work lives in the fetch
           boundary the skip retires (class micro-test: fault 1 on the
           FIRST ctor skip). forEach is gated exec64-side (vfe_mode). */
        /* vctor_jmp's idle is FFFF only after a console RUN init —
           PROGSTART-launched programs left it at power-on 0, sticking
           this gate TRUE forever (cascade probes: 55 eligible ends,
           !p_pf_block=0 in a class-free micro). vctor_lets!=0 alone is
           the real ctor-scan-active condition. */
        .p_pf_block(pf_post_parent || (vctor_lets != 6'd0)),
        .hs_m_state(hs_m_state),
        .hs_m_vsp(hs_m_vsp),
        .hs_m_hp_cmd(hs_m_hp_cmd),
        .hs_m_hp_oid(hs_m_hp_oid),
        .hs_m_hp_aid(hs_m_hp_aid),
        .hs_m_hp_env(hs_m_hp_env),
        .hs_m_hp_eid(hs_m_hp_eid),
        .hs_m_hp_slot(hs_m_hp_slot),
        .hs_m_hp_aslot(hs_m_hp_aslot),
        .hs_m_hp_len(hs_m_hp_len),
        .hs_m_hp_alen(hs_m_hp_alen),
        .hs_m_hp_lim(hs_m_hp_lim),
        .hs_m_hp_key(hs_m_hp_key),
        .hs_m_hp_wval(hs_m_hp_wval),
        .hs_m_hp_rval(hs_m_hp_rval),
        .hs_m_hp_hit(hs_m_hp_hit),
        .hs_m_hp_ret(hs_m_hp_ret),
        .hs_m_hp_phase(hs_m_hp_phase),
        .hs_m_hp_qn(hs_m_hp_qn),
        .hs_m_hp_qi(hs_m_hp_qi),
        .hs_m_hp_si(hs_m_hp_si),
        .hs_m_hp_ss(hs_m_hp_ss),
        .hs_m_hp_tn(hs_m_hp_tn),
        .hs_m_hp_from_stack(hs_m_hp_from_stack),
        .hs_m_hp_make_arr(hs_m_hp_make_arr),
        .hs_m_hp_vbase(hs_m_hp_vbase),
        .hs_m_hp_spr_w(hs_m_hp_spr_w),
        .hs_m_hp_spr_h(hs_m_hp_spr_h),
        .hs_m_hp_nat(hs_m_hp_nat),
        .hs_m_hp_qk(hs_m_hp_qk),
        .hs_m_hp_qv(hs_m_hp_qv),
        .hs_m_hp_qt(hs_m_hp_qt),
        .hs_m_valloc_kind(hs_m_valloc_kind),
        .hs_m_valloc_i(hs_m_valloc_i),
        .hs_m_valloc_arr_n(hs_m_valloc_arr_n),
        .hs_m_valloc_retried(hs_m_valloc_retried),
        .hs_m_vnat_dom(hs_m_vnat_dom),
        .hs_m_vnat_base(hs_m_vnat_base),
        .hs_m_valloc_now_fn(hs_m_valloc_now_fn),
        .hs_m_valloc_bind(hs_m_valloc_bind),
        .hs_m_valloc_bind_src(hs_m_valloc_bind_src),
        .hs_m_valloc_bind_this(hs_m_valloc_bind_this),
        .hs_m_valloc_fn_entry(hs_m_valloc_fn_entry),
        .hs_m_valloc_fn_a1(hs_m_valloc_fn_a1),
        .hs_m_valloc_proto(hs_m_valloc_proto),
        .hs_m_valloc_proto_fn(hs_m_valloc_proto_fn),
        .hs_m_valloc_metrics(hs_m_valloc_metrics),
        .hs_m_valloc_regex(hs_m_valloc_regex),
        .hs_m_valloc_regex_pack(hs_m_valloc_regex_pack),
        .hs_m_vcall_value(hs_m_vcall_value),
        .hs_m_vcall_argc(hs_m_vcall_argc),
        .hs_m_vcall_entry(hs_m_vcall_entry),
        .hs_m_vcall_set_this(hs_m_vcall_set_this),
        .hs_m_vcall_this(hs_m_vcall_this),
        .hs_m_vcall_ctor_val(hs_m_vcall_ctor_val),
        .hs_m_vcsp(hs_m_vcsp),
        .hs_m_vthis(hs_m_vthis),
        .hs_m_venv(hs_m_venv),
        .hs_m_vraf_n(hs_m_vraf_n),
        .hs_m_vlistener_n(hs_m_vlistener_n),
        .hs_m_vgc_halt_after(hs_m_vgc_halt_after),
        .hs_m_vgc_wait_after(hs_m_vgc_wait_after),
        .hs_m_vgc_clear_i(hs_m_vgc_clear_i),
        .hs_m_vgc_qr(hs_m_vgc_qr),
        .hs_m_vgc_qw(hs_m_vgc_qw),
        .hs_m_vdraw_i(hs_m_vdraw_i),
        .hs_m_vdraw_x(hs_m_vdraw_x),
        .hs_m_vdraw_y(hs_m_vdraw_y),
        .hs_m_vdraw_w(hs_m_vdraw_w),
        .hs_m_vdraw_h(hs_m_vdraw_h),
        .hs_m_vdraw_color(hs_m_vdraw_color),
        .hs_m_vfe_i(hs_m_vfe_i),
        .hs_m_vfe_pop(hs_m_vfe_pop),
        .p_clr_busy_q(e64_p_clr_busy),
        .p_clr(e64_p_clr),
        .p_we(e64_p_we),
        .p_sel(e64_p_sel),
        .p_frame_we(e64_p_frame_we),
        .p_frame_idx(e64_p_frame_idx),
        .p_frame_ctor(e64_p_frame_ctor),
        .p_code_raddr(code_raddr_ff),
        .code_rdata(code_rdata),
        .opw_out(e64_opw),
        .p_hp_aid(hp_aid_ff),
        .p_hp_alen(hp_alen_ff),
        .p_hp_aslot(hp_aslot_ff),
        .p_hp_cmd(hp_cmd_ff),
        .p_hp_eid(hp_eid_ff),
        .p_hp_env(hp_env_ff),
        .p_hp_from_stack(hp_from_stack_ff),
        .p_hp_hit(hp_hit_ff),
        .p_hp_key(hp_key_ff),
        .p_hp_len(hp_len_ff),
        .p_hp_lim(hp_lim_ff),
        .p_hp_make_arr(hp_make_arr_ff),
        .p_hp_nat(hp_nat_ff),
        .p_hp_oid(hp_oid_ff),
        .p_hp_phase(hp_phase_ff),
        .p_hp_qi(hp_qi_ff),
        .p_hp_qk_pack(hp_qk_ff_pack),
        .p_hp_qn(hp_qn_ff),
        .p_hp_qt_pack(hp_qt_ff_pack),
        .p_hp_qv_pack(hp_qv_ff_pack),
        .p_hp_ret(hp_ret_ff),
        .p_hp_rval(hp_rval_ff),
        .p_hp_si(hp_si_ff),
        .p_hp_slot(hp_slot_ff),
        .p_hp_spr_h(hp_spr_h_ff),
        .p_hp_spr_w(hp_spr_w_ff),
        .p_hp_ss(hp_ss_ff),
        .p_hp_tn(hp_tn_ff),
        .p_hp_vbase(hp_vbase_ff),
        .p_hp_wval(hp_wval_ff),
        .id_ael(id_ael),
        .id_arc(id_arc),
        .id_assign(id_assign),
        .id_beginpath(id_beginpath),
        .id_bind(id_bind),
        .id_black(id_black),
        .id_center(id_center),
        .id_clearrect(id_clearrect),
        .id_closepath(id_closepath),
        .id_drawimage(id_drawimage),
        .id_fill(id_fill),
        .id_fillrect(id_fillrect),
        .id_fillstyle(id_fillstyle),
        .id_filltext(id_filltext),
        .id_filter(id_filter),
        .id_slice(id_slice),
        .id_sort(id_sort),
        .id_find(id_find),
        .id_findindex(16'hFFFF), // V1 wall: findIndex removed (no title uses it)
        .id_font(id_font),
        .id_disp(id_disp),
        .id_foreach(id_foreach),
        .id_getctx(id_getctx),
        .id_getimgdata(id_getimgdata),
        .id_gettime(id_gettime),
        .id_height(id_height),
        .id_hex_000(id_hex_000),
        .id_hex_fff(id_hex_fff),
        .id_imgsmooth(id_imgsmooth),
        .id_indexof(id_indexof),
        .id_join(id_join),
        .id_length(id_length),
        .id_lineto(id_lineto),
        .id_quadcurve(id_quadcurve),
        .id_map(id_map),
        .id_measuretext(id_measuretext),
        .id_moveto(id_moveto),
        .id_now(id_now),
        .id_onload(id_onload),
        .id_pop(id_pop),
        .id_proto(id_proto),
        .id_push(id_push),
        .id_putimgdata(id_putimgdata),
        .id_replace(id_replace),
        .id_restore(id_restore),
        .id_right(id_right),
        .id_save(id_save),
        .id_settransform(id_settransform),
        .id_splice(id_splice),
        .id_src(id_src),
        .id_str_function(id_str_function),
        .id_str_boolean(id_str_boolean),
        .id_str_number(id_str_number),
        .id_str_object(id_str_object),
        .id_str_string(id_str_string),
        .id_str_undef(id_str_undef),
        .id_stroke(id_stroke),
        .id_strokestyle(id_strokestyle),
        .id_textalign(id_textalign),
        .fs_arg_index(fs_phase[1:0]),.fs_arg_value(fs_arg_value),.id_sys_window(id_sys_window),.sysw_toggle_q(sysw_toggle_o),
        .sysw_field_q(sysw_field_o),.sysw_value_q(sysw_value_o),
        .id_textbaseline(id_textbaseline),
        .id_top(id_top),
        .id_middle(id_middle),
        .id_bottom(id_bottom),
        .ctx_baseline_q(e64_ctx_baseline_q),
        .id_translate(id_translate),
        .id_unshift(id_unshift),
        .id_white(id_white),
        .id_width(id_width),
        .p_ip(ip_ff),
        .joy_in(joy_level_q2),
        .analog_x(analog_x_q2), .analog_y(analog_y_q2), .joy_btn(joy_btn_q2),
        .cm_req_q(e64_cm_req),
        .cm_key_q(e64_cm_key),
        .cm_cls_q(e64_cm_cls),
        .cm_res_we(cm_res_we),
        .cm_res_mip(cm_res_mip),
        .lsv_req_q(e64_lsv_req),
        .lsv_op_q(e64_lsv_op),
        .lsv_ev_q(e64_lsv_ev),
        .lsv_fn_q(e64_lsv_fn),
        .lsv_res_we(lsv_res_we),
        .lsv_res(lsv_res),
        .lsv_res_n(lsv_res_n_out),
        .n_consts(n_consts),
        .n_ops(n_ops),
        .n_spr(n_spr),
        .name_blen_rdata(name_blen_rdata),
        .name_hash_rdata(name_hash_rdata),
        .name_off_rdata(name_off_rdata),
        .vvars_rdata(vvars_rdata),
        .vvar_valid_rdata(vvar_valid_rdata),
        .venv_len_rdata(venv_len_rdata),
        .venv_gen_rdata(venv_gen_rdata),
        .venv_valid_rdata(venv_valid_rdata),
        .varr_len_rdata(varr_len_rdata),
        .varr_valid_rdata(varr_valid_rdata),
        .varr_gen_rdata(varr_gen_rdata),
        .varr_long_rdata(varr_long_rdata),
        .vobj_alloc_rdata(vobj_alloc_rdata),
        .vobj_gen_rdata(vobj_gen_rdata),
        .vobj_proto_rdata(vobj_proto_rdata),
        .vobj_cls_rdata(vobj_cls_rdata),
        .vobj_len_rdata(vobj_len_rdata),
        .vobj_builtin_rdata(vobj_builtin_rdata),
        .vfn_valid_rdata(vfn_valid_rdata),
        .vfn_gen_rdata(vfn_gen_rdata),
        .vfn_proto_rdata(vfn_proto_rdata),
        .vfn_env_rdata(vfn_env_rdata),
        .vfn_nparam_rdata(vfn_nparam_rdata),
        .vfn_entry_rdata(vfn_entry_rdata),
        .vfn_flags_rdata(vfn_flags_rdata),
        .vconsts_rdata(vconsts_rdata),
        .vframe_rip_rdata(vframe_rip_rdata),
        .vframe_bsp_rdata(vframe_bsp_rdata),
        .vframe_esc_rdata(vframe_esc_rdata),
        .vframe_this_rdata(vframe_this_rdata),
        .vframe_env_rdata(vframe_env_rdata),
        .vframe_fn_rdata(vframe_fn_rdata),
        .vframe_ctor_rdata(vframe_ctor_rdata),
        .vframe_setter_rdata(vframe_setter_rdata),
        .fill_lut_rdata(fill_lut_rdata),
        .vtimer_valid_rdata(vtimer_valid_rdata),
        .vtimer_id_rdata(vtimer_id_rdata),
        .names_n(names_n),.names_ready(names_ok),
        .ops_base(ops_base),
        .spr_hh_pack(spr_hh_pack),
        .spr_nid_pack(spr_nid_pack),
        .spr_ww_pack(spr_ww_pack),
        .p_state(state),
        .this_ok(this_ok),
        .p_valloc_arr_n(valloc_arr_n_ff),
        .p_valloc_bind(valloc_bind_ff),
        .p_valloc_bind_src(valloc_bind_src_ff),
        .p_valloc_bind_this(valloc_bind_this_ff),
        .p_valloc_fn_a1(valloc_fn_a1_ff),
        .p_valloc_fn_entry(valloc_fn_entry_ff),
        .p_valloc_i(valloc_i_ff),
        .p_valloc_kind(valloc_kind_ff),
        .p_valloc_metrics(valloc_metrics_ff),
        .p_valloc_now_fn(valloc_now_fn_ff),
        .p_valloc_proto(valloc_proto_ff),
        .p_valloc_proto_fn(valloc_proto_fn_ff),
        .p_valloc_regex(valloc_regex_ff),
        .p_valloc_regex_pack(valloc_regex_pack_ff),
        .p_valloc_retried(valloc_retried_ff),
        .var_this(var_this),
        .p_vcall_argc(vcall_argc_ff),
        .p_vcall_ctor_val(vcall_ctor_val_ff),
        .p_vcall_entry(vcall_entry_ff),
        .p_vcall_set_this(vcall_set_this_ff),
        .p_vcall_this(vcall_this_ff),
        .p_vcall_value(vcall_value_ff),
        .p_vcsp(vcsp_ff),
        .p_vdraw_color(vdraw_color_ff),
        .p_vdraw_h(vdraw_h_ff),
        .p_vdraw_i(vdraw_i_ff),
        .p_vdraw_w(vdraw_w_ff),
        .p_vdraw_x(vdraw_x_ff),
        .p_vdraw_y(vdraw_y_ff),
        .p_venv(venv_ff),
        .p_vfe_i(e64_vfe_i_q + 8'd1),
        .vfn_next(vfn_next),
        .vframe_no(vframe_no),
        .vfree_ok(vfree_ok),
        .p_vgc_clear_i(vgc_clear_i_ff),
        .p_vgc_halt_after(vgc_halt_after_ff),
        .p_vgc_qr(vgc_qr_ff),
        .p_vgc_qw(vgc_qw_ff),
        .p_vgc_wait_after(vgc_wait_after_ff),
        .p_vlistener_n(vlistener_n_ff),
        .vmetrics(vmetrics),
        .text_font_scale(text_font_scale),
        .p_vnat_base(vnat_base_ff),
        .p_vnat_dom(vnat_dom_ff),
        .vobj_next(vobj_next),
        .p_vprom_done(vprom_done),
        .p_vraf_n(vraf_n_ff),
        .p_vsp(vsp_ff),
        .vst_win_pack(vst_win_pack),
        .p_vthis(vthis_ff),
        .p_vtimer_n(vtimer_n),
        .p_vtimer_seq(vtimer_seq),
        .bind_argc_q(e64_bind_argc_q),
        .bind_base_q(e64_bind_base_q),
        .bind_ip_q(e64_bind_ip_q),
        .bind_k_q(e64_bind_k_q),
        .bind_mode_q(e64_bind_mode_q),
        .bind_n_q(e64_bind_n_q),
        .bind_rd_arm_q(e64_bind_rd_arm_q),
        .bind_ret_q(e64_bind_ret_q),
        .bind_src_q(e64_bind_src_q),
        .bind_vsp_next_q(e64_bind_vsp_next_q),
        .blit_sh_q(e64_blit_sh_q),
        .blit_si_q(e64_blit_si_q),
        .flip_x_q(e64_flip_x_q),
        .flip_y_q(e64_flip_y_q),
        .blit_sw_q(e64_blit_sw_q),
        .blit_sx_q(e64_blit_sx_q),
        .blit_sy_q(e64_blit_sy_q),
        .cc_at_q(e64_cc_at_q),
        .cc_av_q(e64_cc_av_q),
        .cc_bok_q(e64_cc_bok_q),
        .cc_bt_q(e64_cc_bt_q),
        .cc_bv_q(e64_cc_bv_q),
        .cc_d_q(e64_cc_d_q),
        .cc_h_q(e64_cc_h_q),
        .cc_len_q(e64_cc_len_q),
        .cc_second_q(e64_cc_second_q),
        .cc_st_q(e64_cc_st_q),
        .code_raddr_q(e64_code_raddr_q),
        .color_q(e64_color_q),
        .ctx_align_q(e64_ctx_align_q),
        .ctx_sx_q(e64_ctx_sx_q),
        .ctx_sy_q(e64_ctx_sy_q),
        .ctx_tx_q(e64_ctx_tx_q),
        .ctx_ty_q(e64_ctx_ty_q),
        .dbg_di_hit_q(e64_dbg_di_hit_q),
        .dbg_di_miss_q(e64_dbg_di_miss_q),
        .fault_code_q(e64_fault_code_q),
        .fault_site_q(e64_fault_site_q),
        .fault_arg_q(e64_fault_arg_q),
        .fb_dump_addr_q(e64_fb_dump_addr_q),
        .fb_swap_q(e64_fb_swap_q),
        .hp_aid_q(e64_hp_aid_q),
        .hp_alen_q(e64_hp_alen_q),
        .hp_aslot_q(e64_hp_aslot_q),
        .hp_cmd_q(e64_hp_cmd_q),
        .hp_eid_q(e64_hp_eid_q),
        .hp_env_q(e64_hp_env_q),
        .hp_from_stack_q(e64_hp_from_stack_q),
        .hp_hit_q(e64_hp_hit_q),
        .hp_key_q(e64_hp_key_q),
        .hp_len_q(e64_hp_len_q),
        .hp_lim_q(e64_hp_lim_q),
        .hp_make_arr_q(e64_hp_make_arr_q),
        .hp_nat_q(e64_hp_nat_q),
        .hp_oid_q(e64_hp_oid_q),
        .hp_phase_q(e64_hp_phase_q),
        .hp_proto_q(e64_hp_proto_q),
        .hp_qi_q(e64_hp_qi_q),
        .hp_qn_q(e64_hp_qn_q),
        .hp_ret_q(e64_hp_ret_q),
        .hp_rval_q(e64_hp_rval_q),
        .hp_si_q(e64_hp_si_q),
        .hp_slot_q(e64_hp_slot_q),
        .hp_spr_h_q(e64_hp_spr_h_q),
        .hp_spr_w_q(e64_hp_spr_w_q),
        .hp_ss_q(e64_hp_ss_q),
        .hp_tn_q(e64_hp_tn_q),
        .hp_vbase_q(e64_hp_vbase_q),
        .hp_wval_q(e64_hp_wval_q),
        .imgd_h_q(e64_imgd_h_q),
        .imgd_i_q(e64_imgd_i_q),
        .imgd_n_q(e64_imgd_n_q),
        .imgd_v64_q(e64_imgd_v64_q),
        .imgd_w_q(e64_imgd_w_q),
        .imgd_x_q(e64_imgd_x_q),
        .imgd_x0_q(e64_imgd_x0_q),
        .imgd_y_q(e64_imgd_y_q),
        .imgd_y0_q(e64_imgd_y0_q),
        .ip_q(e64_ip_q),
        .jn_arr_q(e64_jn_arr_q),
        .jn_h_q(e64_jn_h_q),
        .jn_i_q(e64_jn_i_q),
        .jn_res_q(e64_jn_res_q),
        .js_sp_q(e64_js_sp_q),
        .json_pph_q(e64_json_pph_q),
        .json_rp_q(e64_json_rp_q),
        .json_src_q(e64_json_src_q),
        .json_srclen_q(e64_json_srclen_q),
        .json_wp_q(e64_json_wp_q),
        .machine_fault_q(e64_machine_fault_q),
        .minmax_acc_q(e64_minmax_acc_q),
        .src_len_i(src_len_q2),
        .cmp_done_q(cmp_done_o),
        .cmp_status_q(cmp_status_o),
        .cmp_len_q(cmp_len_o),
        .cmp_msglen_q(cmp_msglen_o),
        .csr_mode_q(e64_csr_mode_q),
        .csr_addr_q(e64_csr_addr_q),
        .csr_wdata_q(e64_csr_wdata_q),
        .src_setlen_q(src_setlen_o),
        .src_setlen_stb_q(src_setlen_stb_o),
        .csr_oob_q(e64_csr_oob_q),
        .minmax_base_q(e64_minmax_base_q),
        .minmax_is_min_q(e64_minmax_is_min_q),
        .minmax_k_q(e64_minmax_k_q),
        .minmax_n_q(e64_minmax_n_q),
        .namcpy_repl_q(e64_namcpy_repl_q),
        .namcpy_v64_q(e64_namcpy_v64_q),
        .name_rdaddr_q(e64_name_rdaddr_q),
        .path_stroke_q(e64_path_stroke_q),
        .pc_n_q(e64_pc_n_q),
        .js_we_q(e64_js_we_q),
        .js_waddr_q(e64_js_waddr_q),
        .js_i_wdata_q(e64_js_i_wdata_q),
        .js_ph_wdata_q(e64_js_ph_wdata_q),
        .vjs_val_wdata_q(e64_vjs_val_wdata_q),
        .pc_we_q(e64_pc_we_q),
        .pc_waddr_q(e64_pc_waddr_q),
        .pc_op_wdata_q(e64_pc_op_wdata_q),
        .pc_a1_wdata_q(e64_pc_a1_wdata_q),
        .pc_a2_wdata_q(e64_pc_a2_wdata_q),
        .pc_a3_wdata_q(e64_pc_a3_wdata_q),
        .pc_a4_wdata_q(e64_pc_a4_wdata_q),
        .pc_a5_wdata_q(e64_pc_a5_wdata_q),
        .pc_ccw_wdata_q(e64_pc_ccw_wdata_q),
        .repl_g_q(e64_repl_g_q),
        .repl_pat0_q(e64_repl_pat0_q),
        .repl_rch_q(e64_repl_rch_q),
        .rh_q(e64_rh_q),
        .rw_q(e64_rw_q),
        .rx_q(e64_rx_q),
        .ry_q(e64_ry_q),
        .sq_i_q(e64_sq_i_q),
        .sq_rad_q(e64_sq_rad_q),
        .sq_rem_q(e64_sq_rem_q),
        .sq_root_q(e64_sq_root_q),
        .state_q(e64_state_q),
        .txt_bn_q(e64_txt_bn_q),
        .txt_ph_q(e64_txt_ph_q),
        .txt_px_q(e64_txt_px_q),
        .txt_py_q(e64_txt_py_q),
        .txt_val_q(e64_txt_val_q),
        .txt_vt_q(e64_txt_vt_q),
        .v64_concat_q(e64_v64_concat_q),
        .v64_join_q(e64_v64_join_q),
        .v64_sqrt_q(e64_v64_sqrt_q),
        .valloc_arr_n_q(e64_valloc_arr_n_q),
        .valloc_bind_q(e64_valloc_bind_q),
        .valloc_bind_src_q(e64_valloc_bind_src_q),
        .valloc_bind_this_q(e64_valloc_bind_this_q),
        .valloc_fn_a1_q(e64_valloc_fn_a1_q),
        .valloc_fn_entry_q(e64_valloc_fn_entry_q),
        .valloc_i_q(e64_valloc_i_q),
        .valloc_kind_q(e64_valloc_kind_q),
        .valloc_metrics_q(e64_valloc_metrics_q),
        .valloc_now_fn_q(e64_valloc_now_fn_q),
        .valloc_proto_q(e64_valloc_proto_q),
        .valloc_proto_fn_q(e64_valloc_proto_fn_q),
        .valloc_regex_q(e64_valloc_regex_q),
        .valloc_regex_pack_q(e64_valloc_regex_pack_q),
        .valloc_retried_q(e64_valloc_retried_q),
        .vcall_argc_q(e64_vcall_argc_q),
        .vcall_ctor_val_q(e64_vcall_ctor_val_q),
        .vcall_entry_q(e64_vcall_entry_q),
        .vcall_set_this_q(e64_vcall_set_this_q),
        .vcall_this_q(e64_vcall_this_q),
        .vcall_value_q(e64_vcall_value_q),
        .vcsp_q(e64_vcsp_q),
        .vdiv_count_q(e64_vdiv_count_q),
        .vdiv_den_q(e64_vdiv_den_q),
        .vdiv_exp_q(e64_vdiv_exp_q),
        .vdiv_num_q(e64_vdiv_num_q),
        .vdiv_quot_q(e64_vdiv_quot_q),
        .vdiv_rem_q(e64_vdiv_rem_q),
        .vdiv_sign_q(e64_vdiv_sign_q),
        .vdraw_color_q(e64_vdraw_color_q),
        .vdraw_h_q(e64_vdraw_h_q),
        .vdraw_i_q(e64_vdraw_i_q),
        .vdraw_w_q(e64_vdraw_w_q),
        .vdraw_x_q(e64_vdraw_x_q),
        .vdraw_y_q(e64_vdraw_y_q),
        .venv_q(e64_venv_q),
        .vfe_arr_q(e64_vfe_arr_q),
        .vfe_base_q(e64_vfe_base_q),
        .vfe_fn_q(e64_vfe_fn_q),
        .vfe_i_q(e64_vfe_i_q),
        .vfe_len_q(e64_vfe_len_q),
        .vfe_map_q(e64_vfe_map_q),
        .vfe_reduce_q(e64_vfe_reduce_q),
        .vfe_findidx_q(e64_vfe_findidx_q),
        .id_reduce(id_reduce),
        .vfe_mode_q(e64_vfe_mode_q),
        .vfe_ret_q(e64_vfe_ret_q),
        .vfe_sp_q(e64_vfe_sp_q),
        .vgc_clear_i_q(e64_vgc_clear_i_q),
        .vgc_halt_after_q(e64_vgc_halt_after_q),
        .vgc_qr_q(e64_vgc_qr_q),
        .vgc_qw_q(e64_vgc_qw_q),
        .vgc_wait_after_q(e64_vgc_wait_after_q),
        .vlistener_n_q(e64_vlistener_n_q),
        .vmetrics_w_q(e64_vmetrics_w_q),
        .vmod_count_q(e64_vmod_count_q),
        .vmod_den_q(e64_vmod_den_q),
        .vmod_exp_q(e64_vmod_exp_q),
        .vmod_rem_q(e64_vmod_rem_q),
        .vmod_sign_q(e64_vmod_sign_q),
        .vnat_base_q(e64_vnat_base_q),
        .vnat_dom_q(e64_vnat_dom_q),
        .vprom_copy_q(e64_vprom_copy_q),
        .vprom_ret_q(e64_vprom_ret_q),
        .vraf_n_q(e64_vraf_n_q),
        .vsp_q(e64_vsp_q),
        .vst_hold_win_q(e64_vst_hold_win_q),
        .vst_refill_arm_q(e64_vst_refill_arm_q),
        .vst_refill_i_q(e64_vst_refill_i_q),
        .vst_refill_ret_q(e64_vst_refill_ret_q),
        .vst_waddr_q(e64_vst_waddr_q),
        .vst_wdata_q(e64_vst_wdata_q),
        .vst_we_q(e64_vst_we_q),
        .vthis_q(e64_vthis_q),
        .x_q(e64_x_q),
        .y_q(e64_y_q),
        .hp_qk_pack_q(e64_hp_qk_pack_q),
        .hp_qt_pack_q(e64_hp_qt_pack_q),
        .hp_qv_pack_q(e64_hp_qv_pack_q),
        .json_mem_we_q(e64_json_mem_we),
        .json_mem_waddr_q(e64_json_mem_waddr),
        .json_mem_wdata_q(e64_json_mem_wdata),
        .vvars_raddr_q(e64_vvars_raddr),
        .varr_raddr_q(e64_varr_raddr),
        .vobj_raddr_q(e64_vobj_raddr),
        .vfn_raddr_q(e64_vfn_raddr),
        .name_off_raddr_q(e64_name_off_raddr),
        .fill_lut_raddr_q(e64_fill_lut_raddr),
        .vframe_raddr_q(e64_vframe_raddr),
        .vtimer_raddr_q(e64_vtimer_raddr),
        .vconsts_raddr_q(e64_vconsts_raddr),
        .name_blen_raddr_q(e64_name_blen_raddr),
        .name_blen_we_q(e64_name_blen_we),
        .name_blen_waddr_q(e64_name_blen_waddr),
        .name_blen_wdata_q(e64_name_blen_wdata),
        .name_hash_raddr_q(e64_name_hash_raddr),
        .name_hash_we_q(e64_name_hash_we),
        .name_hash_waddr_q(e64_name_hash_waddr),
        .name_hash_wdata_q(e64_name_hash_wdata),
        .name_has_we_q(e64_name_has_we),
        .name_has_waddr_q(e64_name_has_waddr),
        .name_has_wdata_q(e64_name_has_wdata),
        .varr_len_we_q(e64_varr_len_we),
        .varr_len_waddr_q(e64_varr_len_waddr),
        .varr_len_wdata_q(e64_varr_len_wdata),
        .varr_lidx_we_q(e64_varr_lidx_we),
        .varr_lidx_waddr_q(e64_varr_lidx_waddr),
        .varr_lidx_wdata_q(e64_varr_lidx_wdata),
        .varr_long_we_q(e64_varr_long_we),
        .varr_long_waddr_q(e64_varr_long_waddr),
        .varr_long_wdata_q(e64_varr_long_wdata),
        .varr_valid_we_q(e64_varr_valid_we),
        .varr_valid_waddr_q(e64_varr_valid_waddr),
        .varr_valid_wdata_q(e64_varr_valid_wdata),
        .venv_gen_we_q(e64_venv_gen_we),
        .venv_gen_waddr_q(e64_venv_gen_waddr),
        .venv_gen_wdata_q(e64_venv_gen_wdata),
        .venv_len_we_q(e64_venv_len_we),
        .venv_len_waddr_q(e64_venv_len_waddr),
        .venv_len_wdata_q(e64_venv_len_wdata),
        .venv_valid_we_q(e64_venv_valid_we),
        .venv_valid_waddr_q(e64_venv_valid_waddr),
        .venv_valid_wdata_q(e64_venv_valid_wdata),
        .vobj_cls_we_q(e64_vobj_cls_we),
        .vobj_cls_waddr_q(e64_vobj_cls_waddr),
        .vobj_cls_wdata_q(e64_vobj_cls_wdata),
        .vvar_valid_we_q(e64_vvar_valid_we),
        .vvar_valid_waddr_q(e64_vvar_valid_waddr),
        .vvar_valid_wdata_q(e64_vvar_valid_wdata),
        .vvars_we_q(e64_vvars_we),
        .snd_ack(snd_ack), .snd_tgl(snd_tgl), .snd_ch(snd_ch), .snd_freq(snd_freq),
        .snd_vol(snd_vol), .snd_frames(snd_frames), .snd_slide(snd_slide),
        .vvars_waddr_q(e64_vvars_waddr),
        .vvars_wdata_q(e64_vvars_wdata),
        .vframe_we_q(e64_vframe_we),
        .vframe_waddr_q(e64_vframe_waddr),
        .vframe_rip_wdata_q(e64_vframe_rip_wdata),
        .vframe_bsp_wdata_q(e64_vframe_bsp_wdata),
        .vframe_esc_wdata_q(e64_vframe_esc_wdata),
        .vframe_this_wdata_q(e64_vframe_this_wdata),
        .vframe_env_wdata_q(e64_vframe_env_wdata),
        .vframe_fn_wdata_q(e64_vframe_fn_wdata),
        .vframe_ctor_wdata_q(e64_vframe_ctor_wdata),
        .vraf_we_q(e64_vraf_we),
        .vraf_waddr_q(e64_vraf_waddr),
        .vraf_wdata_q(e64_vraf_wdata),
        .vtimer_we_q(e64_vtimer_we),
        .vtimer_waddr_q(e64_vtimer_waddr),
        .vtimer_valid_wdata_q(e64_vtimer_valid_wdata),
        .vtimer_due_wdata_q(e64_vtimer_due_wdata),
        .vtimer_fn_wdata_q(e64_vtimer_fn_wdata),
        .vtimer_id_wdata_q(e64_vtimer_id_wdata),
        .vtimer_period_wdata_q(e64_vtimer_period_wdata),
        .vst_win0_we_q(e64_vst_win0_we),
        .vst_win0_wdata_q(e64_vst_win0_wdata)
    );

    // HEAP/FETCH use exec scalars (ip/hp_*/code_raddr/state), not a parent snapshot.
    st_t casestate;
    always_comb begin
        hs64 = ((state == S_V64_EXEC) || (state == S_FETCH_WAIT) ||
            (state == S_HEAP_WAIT) || (state == S_HEAP_CMP) || (state == S_HEAP_WR) ||
            (state == S_HEAP_AWR) || (state == S_HEAP_FILL) || (state == S_V64_ALLOC) ||
            (state == S_WAIT_FRAME) ||
            (state == S_V64_FRAME_RAF) || (state == S_V64_FRAME_TIMER) ||
            (state == S_V64_FRAME_KEY) || (state == S_V64_MOUSE_PROP) || (state == S_V64_BIND) ||
            (state == S_V64_RECT) || (state == S_V64_RECT_LD) || (state == S_V64_CLEAR) ||
            (state == S_V64_CTOR_PAD) || (state == S_V64_CTOR_ENV) ||
            (state == S_V64_CTOR_VARS) ||
            (state == S_V64_FOREACH) || (state == S_V64_FE_ELEM) ||
            (state == S_V64_FE_FILTER) || (state == S_V64_METH) || (state == S_V64_CALLREF) ||
            (state == S_V64_MINMAX) || (state == S_V64_WIN_FILL) ||
            (state == S_V64_RECT_LD) ||
            (state == S_V64_JSON) || (state == S_V64_JSON_PARSE) ||
            (state == S_V64_STRIDX) || (state == S_V64_STRIDX_WR) ||
            (state == S_V64_DIV) || (state == S_V64_DIV_FIN) ||
            (state == S_V64_MOD) || (state == S_V64_CONST_HI) ||
            (state == S_V64_IDXSCAN) || (state == S_V64_OGETI_NAT) ||
            (state == S_V64_GC_CLEAR) || (state == S_V64_GC_ROOT) ||
            (state == S_V64_GC_POP) || (state == S_V64_GC_OBJ) ||
            (state == S_V64_GC_ARR) || (state == S_V64_GC_FN) ||
            (state == S_V64_GC_ENV) || (state == S_V64_GC_SWEEP_OBJ) ||
            (state == S_V64_GC_SWEEP_ARR) || (state == S_V64_GC_SWEEP_ENV) ||
            (state == S_V64_SLICE) || // #40 exec-entered slice copy
            (state == S_V64_SORT) || // #41 exec-entered sort walk
            // Exec-entered compile-ABI memory op. Omitting this is bug
            // class #51 verbatim: it would read the PARENT ip/vsp and
            // re-dispatch the native forever.
            (state == S_CSRAM) || (state == S_FS) ||
            // Exec-entered result-array scan. Without
            // this, hp_ret (and friends) read the PARENT ffs mid-scan —
            // stale S_V64_FOREACH from the previous filter/map walk — so a
            // second filter/map in one program exited its scan INTO the
            // walk state and re-dispatched the CALL_METH per iteration.
            (state == S_FREE_ARR) ||
            (state == S_TXT_LD) || (state == S_TXT_DRAW) ||
            (state == S_CONCAT) || (state == S_JOIN) ||
            (state == S_JOIN_FIND) || (state == S_STR_WR));
        // Tagged (non-Value64) images fault at S_GOT_HDR2, so only the
        // exec64 overlay exists.
        if ((state == S_V64_EXEC) && e64_leave_hold)
            casestate = st_t'(e64_state_q);
        else
            casestate = state;
    end
    // UG901: SRAM address mux must see a flop, not combo casestate (leave_hold
    // overlay of e32/e64_state_q). That combo fanout into ~40 memories was the
    // post-8-6014 70 GB wall. FSM case (casestate) stays combo for same-cycle
    // leave_hold. Extra rdata beat on overlay is OK (wait already).
    st_t casestate_q /*verilator public_flat_rd*/;
    always_ff @(posedge clk) begin
        if (!rst_n) casestate_q <= S_IDLE;
        else casestate_q <= casestate;
    end
    always_ff @(posedge clk) begin
        vdbg_o       <= {1'b0, 7'(casestate_q), fault_code, ip};
        vdbg_fault_o <= machine_fault;

    end

    // Live HEAP/FETCH view: these clock in exec. Masked parent writes (hs_m_*)
    // overlay for the SRAM wait cycle after a poke.
    // The 69-member hs64 handshake mux family is (* dont_touch *): each is a
    // tiny two-level 2:1 selector, and ExploreArea's Retarget pass hunting
    // cross-instance sharing across a near-identical family this large is
    // the prime suspect for the 14h opt_design stall (log frozen, CPU
    // pinned, near-zero I/O — the AMD-documented pattern). Fencing them
    // costs ~nothing in area; if ExploreArea still stalls, the trigger is
    // elsewhere.
    (* dont_touch = "true" *)
    assign ip = hs64 ? (hs_m_ip ? ip_ff : e64_ip_q) :
                 ip_ff;
    (* dont_touch = "true" *)
    assign code_raddr = hs64 ? (hs_m_code ? code_raddr_ff : e64_code_raddr_q) :
                 code_raddr_ff;
    (* dont_touch = "true" *)
    assign vsp = hs64 ? (hs_m_vsp ? vsp_ff : e64_vsp_q) : vsp_ff;
    (* dont_touch = "true" *)
    assign hp_cmd = hs64 ? (hs_m_hp_cmd ? hp_cmd_ff : e64_hp_cmd_q) :
                 hp_cmd_ff;
    (* dont_touch = "true" *)
    (* dont_touch = "true" *)
    assign hp_oid = hs64 ? (hs_m_hp_oid ? hp_oid_ff : e64_hp_oid_q) :
                 hp_oid_ff;
    (* dont_touch = "true" *)
    assign hp_aid = hs64 ? (hs_m_hp_aid ? hp_aid_ff : e64_hp_aid_q) :
                 hp_aid_ff;
    (* dont_touch = "true" *)
    assign hp_env = hs64 ? (hs_m_hp_env ? hp_env_ff : e64_hp_env_q) : hp_env_ff;
    (* dont_touch = "true" *)
    assign hp_eid = hs64 ? (hs_m_hp_eid ? hp_eid_ff : e64_hp_eid_q) : hp_eid_ff;
    (* dont_touch = "true" *)
    assign hp_slot = hs64 ? (hs_m_hp_slot ? hp_slot_ff : e64_hp_slot_q) :
                 hp_slot_ff;
    (* dont_touch = "true" *)
    assign hp_aslot = hs64 ? (hs_m_hp_aslot ? hp_aslot_ff : e64_hp_aslot_q) :
                 hp_aslot_ff;
    (* dont_touch = "true" *)
    assign hp_len = hs64 ? (hs_m_hp_len ? hp_len_ff : e64_hp_len_q) :
                 hp_len_ff;
    (* dont_touch = "true" *)
    assign hp_alen = hs64 ? (hs_m_hp_alen ? hp_alen_ff : e64_hp_alen_q) :
                 hp_alen_ff;
    (* dont_touch = "true" *)
    assign hp_lim = hs64 ? (hs_m_hp_lim ? hp_lim_ff : e64_hp_lim_q) :
                 hp_lim_ff;
    (* dont_touch = "true" *)
    assign hp_key = hs64 ? (hs_m_hp_key ? hp_key_ff : e64_hp_key_q) :
                 hp_key_ff;
    (* dont_touch = "true" *)
    assign hp_wval = hs64 ? (hs_m_hp_wval ? hp_wval_ff : e64_hp_wval_q) :
                 hp_wval_ff;
    (* dont_touch = "true" *)
    assign hp_rval = hs64 ? (hs_m_hp_rval ? hp_rval_ff : e64_hp_rval_q) :
                 hp_rval_ff;
    (* dont_touch = "true" *)
    assign hp_hit = hs64 ? (hs_m_hp_hit ? hp_hit_ff : e64_hp_hit_q) :
                 hp_hit_ff;
    (* dont_touch = "true" *)
    assign hp_ret = hs64 ? (hs_m_hp_ret ? hp_ret_ff : st_t'(e64_hp_ret_q)) :
                 hp_ret_ff;
    (* dont_touch = "true" *)
    assign hp_phase = hs64 ? (hs_m_hp_phase ? hp_phase_ff : e64_hp_phase_q) :
                 hp_phase_ff;
    (* dont_touch = "true" *)
    assign hp_proto = e64_hp_proto_q;
    (* dont_touch = "true" *)
    assign hp_qn = hs64 ? (hs_m_hp_qn ? hp_qn_ff : e64_hp_qn_q) :
                 hp_qn_ff;
    (* dont_touch = "true" *)
    assign hp_qi = hs64 ? (hs_m_hp_qi ? hp_qi_ff : e64_hp_qi_q) :
                 hp_qi_ff;
    (* dont_touch = "true" *)
    assign hp_si = hs64 ? (hs_m_hp_si ? hp_si_ff : e64_hp_si_q) :
                 hp_si_ff;
    (* dont_touch = "true" *)
    assign hp_ss = hs64 ? (hs_m_hp_ss ? hp_ss_ff : e64_hp_ss_q) :
                 hp_ss_ff;
    (* dont_touch = "true" *)
    assign hp_tn = hs64 ? (hs_m_hp_tn ? hp_tn_ff : e64_hp_tn_q) :
                 hp_tn_ff;
    (* dont_touch = "true" *)
    assign hp_from_stack = hs64 ? (hs_m_hp_from_stack ? hp_from_stack_ff : e64_hp_from_stack_q) :
                 hp_from_stack_ff;
    (* dont_touch = "true" *)
    assign hp_make_arr = hs64 ? (hs_m_hp_make_arr ? hp_make_arr_ff : e64_hp_make_arr_q) :
                 hp_make_arr_ff;
    (* dont_touch = "true" *)
    assign hp_vbase = hs64 ? (hs_m_hp_vbase ? hp_vbase_ff : e64_hp_vbase_q) :
                 hp_vbase_ff;
    (* dont_touch = "true" *)
    assign hp_spr_w = hs64 ? (hs_m_hp_spr_w ? hp_spr_w_ff : e64_hp_spr_w_q) : hp_spr_w_ff;
    (* dont_touch = "true" *)
    assign hp_spr_h = hs64 ? (hs_m_hp_spr_h ? hp_spr_h_ff : e64_hp_spr_h_q) : hp_spr_h_ff;
    (* dont_touch = "true" *)
    assign hp_nat = hs64 ? (hs_m_hp_nat ? hp_nat_ff : e64_hp_nat_q) :
                 hp_nat_ff;
    (* dont_touch = "true" *)
    // ALLOC leave: read exec valloc_*/vcall_*/vnat_*/vcsp, not a dump.
    // During ALLOC the scan lives in parent *_ff. hs_m is one-shot, so
    // after the rdata wait beat the mux would snap back to frozen exec
    // valloc_i_q (always the first slot) and skip every later hole.
    assign valloc_kind = (state == S_V64_ALLOC || hs_m_valloc_kind) ? valloc_kind_ff :
                (hs64 ? e64_valloc_kind_q : valloc_kind_ff);
    assign valloc_i = (state == S_V64_ALLOC || hs_m_valloc_i) ? valloc_i_ff :
                (hs64 ? e64_valloc_i_q : valloc_i_ff);
    (* dont_touch = "true" *)
    assign valloc_arr_n = hs64 ? (hs_m_valloc_arr_n ? valloc_arr_n_ff : e64_valloc_arr_n_q) : valloc_arr_n_ff;
    (* dont_touch = "true" *)
    assign valloc_retried = hs64 ? (hs_m_valloc_retried ? valloc_retried_ff : e64_valloc_retried_q) : valloc_retried_ff;
    (* dont_touch = "true" *)
    assign vnat_dom = hs64 ? (hs_m_vnat_dom ? vnat_dom_ff : e64_vnat_dom_q) : vnat_dom_ff;
    assign ctx_align_eff = e64_ctx_align_q;
    // S_ARR_PROMOTE is requested by exec (arr.push / ARRAY_SET growing
    // past ARR_SHORT_CAP) as well as by the parent's JSON parse. Exec
    // sets its own vprom_ret (= S_V64_EXEC); the parent's copy is only
    // written by the JSON paths and otherwise still holds its reset
    // value S_IDLE — so an exec-requested promote 'returned' into a
    // silent halt with fault=0. INVADERS froze exactly there on Space
    // (startGame pushes past the short-array cap).
    // The unconditional e64_vprom_ret_q pick fixed the
    // exec-requested promote (push/ARR_SET past the short cap) but broke the
    // PARENT-requested ones: S_V64_JSON_PARSE sets the parent vprom_ret and
    // never touches exec's, whose reset value is 0 = S_IDLE — parsing an
    // array longer than 32 rows (PACMAN's maze) promoted correctly and then
    // 'returned' into a silent halt (fault=0, S_IDLE; VRING showed
    // S_ARR_PROMOTE -> S_IDLE). Track who requested the promote: the
    // first-entry guard fires only for exec entries (parent hs_st entries
    // arrive with state already S_ARR_PROMOTE).
    logic vprom_from_exec;
    st_t vprom_ret_eff;
    assign vprom_ret_eff = vprom_from_exec
                                        ? st_t'(e64_vprom_ret_q)
                                        : vprom_ret;
    assign dbg_align = ctx_align_eff;
    (* dont_touch = "true" *)
    assign vnat_base = hs64 ? (hs_m_vnat_base ? vnat_base_ff : e64_vnat_base_q) : vnat_base_ff;
    (* dont_touch = "true" *)
    assign valloc_now_fn = hs64 ? (hs_m_valloc_now_fn ? valloc_now_fn_ff : e64_valloc_now_fn_q) : valloc_now_fn_ff;
    (* dont_touch = "true" *)
    assign valloc_bind = hs64 ? (hs_m_valloc_bind ? valloc_bind_ff : e64_valloc_bind_q) : valloc_bind_ff;
    (* dont_touch = "true" *)
    assign valloc_bind_src = hs64 ? (hs_m_valloc_bind_src ? valloc_bind_src_ff : e64_valloc_bind_src_q) : valloc_bind_src_ff;
    (* dont_touch = "true" *)
    assign valloc_bind_this = hs64 ? (hs_m_valloc_bind_this ? valloc_bind_this_ff : e64_valloc_bind_this_q) : valloc_bind_this_ff;
    (* dont_touch = "true" *)
    assign valloc_fn_entry = hs64 ? (hs_m_valloc_fn_entry ? valloc_fn_entry_ff : e64_valloc_fn_entry_q) : valloc_fn_entry_ff;
    (* dont_touch = "true" *)
    assign valloc_fn_a1 = hs64 ? (hs_m_valloc_fn_a1 ? valloc_fn_a1_ff : e64_valloc_fn_a1_q) : valloc_fn_a1_ff;
    (* dont_touch = "true" *)
    assign valloc_proto = hs64 ? (hs_m_valloc_proto ? valloc_proto_ff : e64_valloc_proto_q) : valloc_proto_ff;
    (* dont_touch = "true" *)
    assign valloc_proto_fn = hs64 ? (hs_m_valloc_proto_fn ? valloc_proto_fn_ff : e64_valloc_proto_fn_q) : valloc_proto_fn_ff;
    (* dont_touch = "true" *)
    assign valloc_metrics = hs64 ? (hs_m_valloc_metrics ? valloc_metrics_ff : e64_valloc_metrics_q) : valloc_metrics_ff;
    (* dont_touch = "true" *)
    assign valloc_regex = hs64 ? (hs_m_valloc_regex ? valloc_regex_ff : e64_valloc_regex_q) : valloc_regex_ff;
    (* dont_touch = "true" *)
    assign valloc_regex_pack = hs64 ? (hs_m_valloc_regex_pack ? valloc_regex_pack_ff : e64_valloc_regex_pack_q) : valloc_regex_pack_ff;
    (* dont_touch = "true" *)
    assign vcall_value = hs64 ? (hs_m_vcall_value ? vcall_value_ff : e64_vcall_value_q) : vcall_value_ff;
    (* dont_touch = "true" *)
    assign vcall_argc = hs64 ? (hs_m_vcall_argc ? vcall_argc_ff : e64_vcall_argc_q) : vcall_argc_ff;
    (* dont_touch = "true" *)
    assign vcall_entry = hs64 ? (hs_m_vcall_entry ? vcall_entry_ff : e64_vcall_entry_q) : vcall_entry_ff;
    (* dont_touch = "true" *)
    assign vcall_set_this = hs64 ? (hs_m_vcall_set_this ? vcall_set_this_ff : e64_vcall_set_this_q) : vcall_set_this_ff;
    (* dont_touch = "true" *)
    assign vcall_this = hs64 ? (hs_m_vcall_this ? vcall_this_ff : e64_vcall_this_q) : vcall_this_ff;
    (* dont_touch = "true" *)
    assign vcall_ctor_val = hs64 ? (hs_m_vcall_ctor_val ? vcall_ctor_val_ff : e64_vcall_ctor_val_q) : vcall_ctor_val_ff;
    (* dont_touch = "true" *)
    assign vcsp = hs64 ? (hs_m_vcsp ? vcsp_ff : e64_vcsp_q) : vcsp_ff;
    (* dont_touch = "true" *)
    assign vthis = hs64 ? (hs_m_vthis ? vthis_ff : e64_vthis_q) : vthis_ff;
    (* dont_touch = "true" *)
    assign venv = hs64 ? (hs_m_venv ? venv_ff : e64_venv_q) : venv_ff;
    // rAF/GC flags: WAIT_FRAME and GC_CLEAR read exec, not parent zeros.
    (* dont_touch = "true" *)
    assign vraf_n = hs64 ? (hs_m_vraf_n ? vraf_n_ff : e64_vraf_n_q) : vraf_n_ff;
    (* dont_touch = "true" *)
    assign vlistener_n = hs64 ? (hs_m_vlistener_n ? vlistener_n_ff : e64_vlistener_n_q) : vlistener_n_ff;
    assign dbg_id_keydown = id_keydown;
    assign dbg_id_keyup = id_keyup;
    (* dont_touch = "true" *)
    assign vgc_halt_after = hs64 ? (hs_m_vgc_halt_after ? vgc_halt_after_ff : e64_vgc_halt_after_q) : vgc_halt_after_ff;
    (* dont_touch = "true" *)
    assign vgc_wait_after = hs64 ? (hs_m_vgc_wait_after ? vgc_wait_after_ff : e64_vgc_wait_after_q) : vgc_wait_after_ff;
    (* dont_touch = "true" *)
    assign vgc_clear_i = hs64 ? (hs_m_vgc_clear_i ? vgc_clear_i_ff : e64_vgc_clear_i_q) : vgc_clear_i_ff;
    (* dont_touch = "true" *)
    assign vgc_qr = hs64 ? (hs_m_vgc_qr ? vgc_qr_ff : e64_vgc_qr_q) : vgc_qr_ff;
    (* dont_touch = "true" *)
    assign vgc_qw = hs64 ? (hs_m_vgc_qw ? vgc_qw_ff : e64_vgc_qw_q) : vgc_qw_ff;
    (* dont_touch = "true" *)
    assign vdraw_i = hs64 ? (hs_m_vdraw_i ? vdraw_i_ff : e64_vdraw_i_q) : vdraw_i_ff;
    assign vdraw_x = (state == S_V64_RECT) ? vdraw_x_ff :
        (hs64 ? (hs_m_vdraw_x ? vdraw_x_ff : e64_vdraw_x_q) : vdraw_x_ff);
    assign vdraw_y = (state == S_V64_RECT) ? vdraw_y_ff :
        (hs64 ? (hs_m_vdraw_y ? vdraw_y_ff : e64_vdraw_y_q) : vdraw_y_ff);
    assign vdraw_w = (state == S_V64_RECT) ? vdraw_w_ff :
        (hs64 ? (hs_m_vdraw_w ? vdraw_w_ff : e64_vdraw_w_q) : vdraw_w_ff);
    assign vdraw_h = (state == S_V64_RECT) ? vdraw_h_ff :
        (hs64 ? (hs_m_vdraw_h ? vdraw_h_ff : e64_vdraw_h_q) : vdraw_h_ff);
    (* dont_touch = "true" *)
    assign vdraw_color = hs64 ? (hs_m_vdraw_color ? vdraw_color_ff : e64_vdraw_color_q) : vdraw_color_ff;
    genvar gi_hs;
    generate
        for (gi_hs = 0; gi_hs < 4; gi_hs++) begin : g_hp_q
            assign hp_qk[gi_hs] = hs64 ? (hs_m_hp_qk ? hp_qk_ff[gi_hs] : e64_hp_qk_pack_q[16*gi_hs +: 16]) :
                 hp_qk_ff[gi_hs];
            assign hp_qv[gi_hs] = hs64 ? (hs_m_hp_qv ? hp_qv_ff[gi_hs] : e64_hp_qv_pack_q[64*gi_hs +: 64]) :
                 hp_qv_ff[gi_hs];
            assign hp_qt[gi_hs] = hs64 ? (hs_m_hp_qt ? hp_qt_ff[gi_hs] : e64_hp_qt_pack_q[3*gi_hs +: 3]) :
                 hp_qt_ff[gi_hs];
        end
    endgenerate
    genvar gi_pack;
    generate
        for (gi_pack = 0; gi_pack < 4; gi_pack++) begin : g_hp_pack
            assign hp_qk_ff_pack[16*gi_pack +: 16] = hp_qk_ff[gi_pack];
            assign hp_qt_ff_pack[3*gi_pack +: 3] = hp_qt_ff[gi_pack];
            assign hp_qv_ff_pack[64*gi_pack +: 64] = hp_qv_ff[gi_pack];
        end
        for (gi_pack = 0; gi_pack < 16; gi_pack++) begin : g_spr_pack
            assign spr_hh_pack[16*gi_pack +: 16] = spr_hh[gi_pack];
            assign spr_nid_pack[16*gi_pack +: 16] = spr_nid[gi_pack];
            assign spr_ww_pack[16*gi_pack +: 16] = spr_ww[gi_pack];
        end
    endgenerate


    // flatten: v64_mul_task / *_pack_task inlined into unique case (casestate)
    // is a 106-bit combo mul + unrolled 53/107-bit for-loops in THAT cone
    // (14:01 bit: ~72 GB RSS, log frozen). One always_comb
    // here is one mul/pack, not one copy per case arm. Unique case only
    // consumes the wires.
    logic [63:0] vdiv_pack_n, vmod_pack_n;
    logic [53:0] vmod_shifted_n;
    logic [52:0] vmod_next_rem_n;
    assign vmod_shifted_n = {vmod_rem, 1'b0};
    assign vmod_next_rem_n = (vmod_shifted_n >= {1'b0, vmod_den})
        ? 53'(vmod_shifted_n - {1'b0, vmod_den})
        : vmod_shifted_n[52:0];
    always_comb begin
        v64_div_pack_task(vdiv_sign, vdiv_exp, vdiv_quot, vdiv_rem,
                          vdiv_pack_n);
        v64_mod_pack_task(vmod_sign, vmod_exp, vmod_next_rem_n, vmod_pack_n);
    end

    // C3: the rAF timestamp vframe_no * 50/3 was the parent's
    // ONLY combinational 53x53 double multiply (v64_mul_task, deleted)
    // and the measured worst intra-VM cone (75.3 ns
    // of the 80 ns budget, 86 levels, every worst path vframe_no ->
    // vst_wdata). Free-running engine, one beat per multiplier bit:
    // acc = vframe_no * RAF_TS_M exactly (85-bit integer product), then
    // one pack beat (leading-bit scan of the REGISTERED product, round
    // to nearest even) = bit-identical to the IEEE double product for
    // every n, since both inputs are exact. ~34 VM beats once per
    // frame; the rAF push stalls on raf_ts_rdy so a stale value is
    // unobservable by construction (covers program-start vframe_no
    // resets and the same-beat increment hazard alike).
    localparam logic [52:0] RAF_TS_M = 53'h10AAAAAAAAAAAB; // mant(50/3)
    logic [31:0] raf_n_q, raf_n_cap, raf_nsh;
    logic [84:0] raf_acc, raf_msh;
    logic [5:0]  raf_i;
    logic        raf_run, raf_pck;
    logic [63:0] raf_ts_q;
    logic        raf_ts_rdy;
    logic [63:0] raf_pack_n;
    always_comb begin
        logic [6:0]  rp;
        logic [6:0]  rsh;
        logic [52:0] rmant;
        logic        rg, rst_s;
        logic [53:0] rrnd;
        rp = 7'd0;
        for (int k = 0; k < 85; k++)
            if (raf_acc[k]) rp = 7'(k);          // fixed-bit scan (log depth)
        rsh = rp - 7'd52;                        // rp >= 52 for any n >= 1
        rmant = 53'(raf_acc >> rsh);
        rg = (rsh != 7'd0) ? raf_acc[rsh - 7'd1] : 1'b0;
        rst_s = 1'b0;
        for (int k = 0; k < 85; k++)
            if (7'(k) + 7'd1 < rsh && raf_acc[k]) rst_s = 1'b1;
        rrnd = {1'b0, rmant} + 54'(rg && (rst_s || rmant[0]));
        if (rrnd[53]) begin
            rmant = rrnd[53:1];
            rp = rp + 7'd1;
        end else rmant = rrnd[52:0];
        // value = acc * 2^-48 -> biased exponent = 1023 + rp - 48
        raf_pack_n = (raf_acc == 85'd0)
            ? 64'd0
            : {1'b0, 11'(11'd975 + 11'(rp)), rmant[51:0]};
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            raf_n_q <= 32'hFFFFFFFF;   // != any real vframe_no: recompute
            raf_ts_q <= 64'd0;
            raf_run <= 1'b0;
            raf_pck <= 1'b0;
        end else if (raf_run) begin
            if (raf_nsh[0]) raf_acc <= raf_acc + raf_msh;
            raf_msh <= raf_msh << 1;
            raf_nsh <= raf_nsh >> 1;
            raf_i <= raf_i + 6'd1;
            if (raf_i == 6'd31) begin
                raf_run <= 1'b0;
                raf_pck <= 1'b1;
            end
        end else if (raf_pck) begin
            raf_ts_q <= raf_pack_n;
            raf_n_q <= raf_n_cap;
            raf_pck <= 1'b0;
        end else if (vframe_no != raf_n_q) begin
            raf_n_cap <= vframe_no;
            raf_nsh <= vframe_no;
            raf_msh <= {32'd0, RAF_TS_M};
            raf_acc <= 85'd0;
            raf_i <= 6'd0;
            raf_run <= 1'b1;
        end
    end
    assign raf_ts_rdy = !raf_run && !raf_pck && (raf_n_q == vframe_no);

    // Intern `new Stage` (`var Stage = function`): ctor handle is bind_ins
    // (CTOR_ENV), not VST_AT. NEW_OBJ clocks vcall_value=0; CTOR_ENV
    // hs_vcall_value(1) is one-shot, so kind 3 saw is_valcall=0 and
    // CTOR_PAD entry FFFF (PACMAN LOAD_VAR stage fault 4 after LET_VAR).
    // Combo NEW_OBJ&&bind_ins also dropped after BIND (code_rdata no
    // longer NEW_OBJ / bind_ins last arg). intern_ctor_hold stays.
    wire intern_ctor_fn;
    assign intern_ctor_fn = intern_ctor_hold;

    // Read+write are their own processes (same shape as jmr_mini_fb Port A).
    // The 7k-line FSM poking ram[i] <= made Vivado build FFs (70 GB).
    // STRIDX must keep exec's byte address while casestate_q leaves EXEC
    // (second wait beat). Switching to parent name_rdaddr mid-op would
    // clobber name_rdata before char_id is captured (splash sprites gone).
    assign name_mem_raddr = (state==S_UI_PROP) ? ui_prop_ptr[14:0] : ((casestate_q == S_V64_EXEC) ||
                             (casestate_q == S_V64_STRIDX))
        ? e64_name_rdaddr_q[14:0] : name_rdaddr[14:0];
    assign json_rdaddr =
        ((casestate_q == S_REPL) && jn_name_arm) ? (json_rp[12:0] + 13'd1) :
        ((casestate_q == S_TXT_LD) && (txt_ph == 4'd4)) ? txt_rp[12:0] :
        json_rp[12:0];
    always_ff @(posedge clk) begin
        if (name_we) name_mem[name_waddr] <= name_wdata;
        name_rdata <= name_mem[name_mem_raddr];
    end
    always_ff @(posedge clk) begin
        if (json_we) json_mem[json_waddr] <= json_wdata;
        json_mem_rdata <= json_mem[json_rdaddr];
    end
    always_ff @(posedge clk) begin
        // spr_mem external - no on-chip storage
    end
    always_ff @(posedge clk) begin
        // imgd_pix array deleted - snapshot pixels stream over the external
        // SRAM port from S_IMGD_GET / S_IMGD_PUT (blit-style req/ack).
    end

    // Scalar write mux (exec we same cycle; parent *_we is the json_putc NBA).
    wire name_hash_ram_we = name_hash_we ||
        (e64_p_we && e64_p_sel == 6'd40) || e64_name_hash_we;
    wire [9:0] name_hash_ram_waddr = name_hash_we ? name_hash_waddr :
        (e64_p_we && e64_p_sel == 6'd40) ? e64_p_addr[9:0] : e64_name_hash_waddr;
    wire [15:0] name_hash_ram_wdata = name_hash_we ? name_hash_wdata :
        (e64_p_we && e64_p_sel == 6'd40) ? e64_p_data[15:0] : e64_name_hash_wdata;
    wire varr_len_ram_we = varr_len_we ||
        ((state == S_V64_EXEC) && e64_varr_len_we);
    wire [11:0] varr_len_ram_waddr = varr_len_we ? varr_len_waddr
        : e64_varr_len_waddr;
    wire [7:0] varr_len_ram_wdata = varr_len_we ? varr_len_wdata
        : e64_varr_len_wdata;
    wire vvars_ram_we = vvars_we ||
        ((state == S_V64_EXEC) && e64_vvars_we);
    wire [8:0] vvars_ram_waddr = vvars_we ? vvars_waddr : e64_vvars_waddr[8:0];
    wire [63:0] vvars_ram_wdata = vvars_we ? vvars_wdata : e64_vvars_wdata;

    // Address mux only — not forty rdata <= mem[f()] in one process (UG901).
    assign name_hash_raddr =
        (state == S_CONCAT && cx_active) ? cx_meta :
        (state == S_V64_BYTESTRING) ? bs_scan[9:0] :
        // FIND stream: while armed (comparing jn_i's row), present
        // jn_i+1 so a mismatch advances 1 beat/candidate (was 2: the old
        // walk disarmed and re-paid the read every miss).
        ((casestate_q == S_JOIN_FIND) || (state == S_JOIN_FIND)) ?
            (jn_rd_arm ? 10'(jn_i[9:0] + 10'd1) : jn_i[9:0]) :
        ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
            (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
        // jn_slot_arm, not jn_name_arm: the walk consumes hash/len one
        // beat after jn_name_arm is SET, but the nonblocking flag reads 0
        // during its own set beat — the raddr fell through to the exec
        // fallback row and the registered rdata lagged a row behind. Every
        // string-digit element then failed the len==1/digit test and
        // coerced to 0 ("1100".join gave "0000"). jn_slot_arm is already
        // high on the name-arm beat and varr_rdata holds this element.
        (((casestate_q == S_JOIN) || (state == S_JOIN)) && jn_slot_arm) ?
            varr_rdata[9:0] :
        hs64 ? e64_name_hash_raddr : 10'd0;
    assign varr_len_raddr =
        (state == S_V64_BYTESTRING) ? hp_aid :
        (casestate_q == S_JOIN || state == S_JOIN) ? jn_arr :
        (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
            vgc_cur[11:0] :
        (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
            hp_aid :
        (casestate_q == S_V64_FE_FILTER || state == S_V64_FE_FILTER) ?
            vfe_map[11:0] :
        (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
            ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
        ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
         valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr;
    assign vobj_alloc_raddr =
        (casestate_q == S_V64_KEYS || state == S_V64_KEYS) ? hp_oid :
        vgc_mark_pend ? vgc_mark_word[12:0] :
        (casestate_q == S_V64_GC_SWEEP_OBJ ||
         state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
        ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
          casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
         valloc_rd_arm && hp_cmd == HP_ASSIGN &&
         hp_phase == 3'd3) ?
            assign_src_value[12:0] :
        ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
          casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
         hp_proto_arm) ? hp_proto[12:0] :
        (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
         casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ? hp_oid :
        (casestate_q == S_FREE_OBJ || state == S_FREE_OBJ) ?
            valloc_i[12:0] :
        (casestate_q == S_V64_OGETI_NAT || state == S_V64_OGETI_NAT) ?
            vmetrics[12:0] :
        ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
         valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr;
    assign vvars_raddr =
        (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
            vgc_root_i[8:0] :
        (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
         casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
         casestate_q == S_RD && ret_state == S_V64_CTOR_VARS ||
         casestate_q == S_V64_CTOR_VARS ||
         state == S_V64_CTOR_VARS) ? hp_key[8:0] : e64_vvars_raddr;

    always_ff @(posedge clk) begin
        if (name_hash_ram_we) name_hash_tbl[name_hash_ram_waddr] <= name_hash_ram_wdata;
        name_hash_rdata <= name_hash_tbl[name_hash_raddr];
    end
    always_ff @(posedge clk) begin
        if (varr_len_ram_we) varr_len[varr_len_ram_waddr] <= varr_len_ram_wdata;
        varr_len_rdata <= varr_len[varr_len_raddr];
    end
    always_ff @(posedge clk) begin
        if (vobj_alloc_we) vobj_alloc[vobj_alloc_waddr] <= vobj_alloc_wdata;
        vobj_alloc_rdata <= vobj_alloc[vobj_alloc_raddr[9:0]];
    end
    always_ff @(posedge clk) begin
        if (vvars_ram_we) vvars[vvars_ram_waddr] <= vvars_ram_wdata;
        vvars_rdata <= vvars[vvars_raddr];
    end

    // Remaining small/metadata rdata. Heap tables above now match imgd Port A.
    always_ff @(posedge clk) begin
            vraf_rdata <= vraf[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[2:0] : bind_k[2:0]];
            sin_q_rdata <= sin_q[sin_raddr];
            txt_buf_rdata <= txt_buf[txt_i[5:0]];
            pow31_rdata <= pow31_tbl[e32_name_len_tos[7:0]];
            name_blen_rdata <= name_blen[(state==S_CONCAT && cx_active)?cx_meta:(state==S_V64_BYTESTRING)?bs_scan[9:0]:(state==S_UI_PROP)?ui_prop_name:e64_name_blen_raddr];
            // name_hash_tbl: own Port A/B processes (not this mux).
            name_off_rdata <= name_off[(state==S_CONCAT && cx_active)?cx_meta:(state==S_V64_BYTESTRING)?bs_scan[9:0]:(state==S_UI_PROP)?ui_prop_name:hs64 ? e64_name_off_raddr : 10'd0];
            if (vconsts_pa_we) vconsts[vconsts_pa_waddr] <= vconsts_pa_wdata;
        vconsts_rdata <= vconsts[e64_vconsts_raddr];
            // vvars: own Port A process (not this mux).
            vvar_valid_rdata <= vvar_valid[(casestate_q == S_V64_GC_ROOT ||
                state == S_V64_GC_ROOT) ? vgc_root_i[8:0] :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_RD && ret_state == S_V64_CTOR_VARS ||
                 casestate_q == S_V64_CTOR_VARS ||
                 state == S_V64_CTOR_VARS) ? hp_key[8:0] : e64_vvars_raddr];
            // 1W1R parent env chain (HEAP_CMP must not combo venv_parent[hp_eid]).
            // Current-env metadata follows parent venv[], not exec venv_raddr_q:
            // ALLOC freezes exec raddr (often 0). LOAD_VAR then saw
            // venv_valid_rdata=0 and faulted 4 (keep gen; extra clocks OK).
            if (venv_parent_pa_we) venv_parent[venv_parent_pa_waddr] <= venv_parent_pa_wdata;
            venv_parent_rdata <= venv_parent[
                (casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : hp_eid];
            venv_valid_rdata <= venv_valid[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? venv_parent_rdata[9:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0])];
            venv_len_ridx =
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_WR || state == S_HEAP_WR) ?
                    (hp_proto_arm ? venv_parent_rdata[9:0] : hp_eid) :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0]);
            // same-beat write-forward: restores the old direct-write timing
            venv_len_rdata <= (vel_we && vel_wa == venv_len_ridx[8:0])
                ? vel_wd : venv_len[venv_len_ridx[8:0]];
            venv_gen_rdata <= venv_gen[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? venv_parent_rdata[9:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ? valloc_i[9:0] :
                ((casestate_q == S_V64_GC_ENV || state == S_V64_GC_ENV) ?
                    vgc_cur[9:0] : venv[9:0])];
            // Length addr this clock; unique case uses varr_len_rdata next.
            // varr_len: own Port A process (not this mux).
            varr_valid_rdata <= varr_valid[
                (state == S_V64_BYTESTRING) ? hp_aid :
                vgc_mark_pend ? vgc_mark_word[11:0] :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_gen_rdata <= varr_gen[
                (state == S_V64_BYTESTRING) ? hp_aid :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_long_rdata <= varr_long[
                (state == S_V64_BYTESTRING) ? hp_aid :
                (casestate_q == S_JOIN || state == S_JOIN) ? jn_arr :
                (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
                    vgc_cur[11:0] :
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) ?
                    e64_vfe_arr_q[11:0] :
                (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
                    hp_aid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_V64_JSON_PARSE || state == S_V64_JSON_PARSE) ?
                    ((js_sp >= 6'd2 && jn_slot_arm) ?
                        vjs_val[js_sp - 6'd2][11:0] :
                     (js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_AWR || state == S_HEAP_AWR ||
                 casestate_q == S_HEAP_FILL || state == S_HEAP_FILL) ?
                    hp_aid :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            varr_lidx_rdata <= varr_lidx[
                (state == S_V64_BYTESTRING) ? hp_aid :
                (casestate_q == S_JOIN || state == S_JOIN) ? jn_arr :
                (casestate_q == S_V64_GC_ARR || state == S_V64_GC_ARR) ?
                    vgc_cur[11:0] :
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) ?
                    e64_vfe_arr_q[11:0] :
                (casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE) ?
                    hp_aid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    ((js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_V64_JSON_PARSE || state == S_V64_JSON_PARSE) ?
                    ((js_sp >= 6'd2 && jn_slot_arm) ?
                        vjs_val[js_sp - 6'd2][11:0] :
                     (js_sp != 6'd0) ? vjs_val[js_sp - 6'd1][11:0] : 12'd0) :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_AWR || state == S_HEAP_AWR ||
                 casestate_q == S_HEAP_FILL || state == S_HEAP_FILL) ?
                    hp_aid :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i :
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR) ?
                    valloc_i[11:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd1) ? valloc_i[11:0] : e64_varr_raddr];
            // vobj_alloc: own Port A process (not this mux).
            vobj_gen_rdata <= vobj_gen[
                (casestate_q == S_V64_KEYS || state == S_V64_KEYS) ? hp_oid :
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 valloc_rd_arm && hp_cmd == HP_ASSIGN &&
                 hp_phase == 3'd3) ?
                    assign_src_value[12:0] :
                ((casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                  casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) &&
                 hp_proto_arm) ? hp_proto[12:0] :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_HEAP_WR || state == S_HEAP_WR) ? hp_oid :
                (casestate_q == S_V64_JSON || state == S_V64_JSON) ?
                    valloc_i[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV ||
                 casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS ||
                 ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                  valloc_kind == 2'd0)) ? valloc_i[12:0] : e64_vobj_raddr];
            vobj_mark_rdata <= vobj_mark[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i : 13'd0];
            vfn_mark_rdata <= vfn_mark[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i : 13'd0];
            varr_mark_rdata <= varr_mark[
                vgc_mark_pend ? vgc_mark_word[11:0] :
                (casestate_q == S_V64_GC_SWEEP_ARR ||
                 state == S_V64_GC_SWEEP_ARR) ? vgc_arr_i : 12'd0];
            venv_mark_rdata <= venv_mark[
                vgc_mark_pend ? vgc_mark_word[9:0] :
                (casestate_q == S_V64_GC_SWEEP_ENV ||
                 state == S_V64_GC_SWEEP_ENV) ? vgc_env_i : 10'd0];
            if (vobj_proto_pa_we) vobj_proto[vobj_proto_pa_waddr] <= vobj_proto_pa_wdata;
            vobj_proto_rdata <= vobj_proto[
                (casestate_q == S_V64_GC_OBJ || state == S_V64_GC_OBJ) ?
                    vgc_cur[12:0] : e64_vobj_raddr];
            vobj_cls_rdata <= vobj_cls[
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ? hp_oid :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr];
            vobj_len_ridx =
                (casestate_q == S_V64_KEYS || state == S_V64_KEYS) ? hp_oid :
                (casestate_q == S_V64_GC_OBJ || state == S_V64_GC_OBJ) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_DISPATCH || state == S_V64_DISPATCH) ?
                    hp_oid :
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP) ?
                    ((hp_cmd == HP_ASSIGN && hp_phase == 3'd0) ? hp_si : hp_oid) :
                // KEYEVT's OSETI enters S_HEAP_WR
                // DIRECTLY (never through HEAP_WAIT/CMP), so the qi-loop's
                // final `vobj_len_rdata < qn+slot` gate read a STALE address
                // (exec's frozen vobj_raddr). A stale len >= 3 skipped the
                // len write: the key-event object kept n=0, e.key/e.keyCode
                // read undefined, and DONKEY's Enter gate never matched.
                (casestate_q == S_HEAP_WR || state == S_HEAP_WR) ? hp_oid :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? valloc_i[12:0] : e64_vobj_raddr;
            // same-beat write-forward (see venv_len above)
            vobj_len_rdata <= (vol_we && vol_wa[9:0] == vobj_len_ridx[9:0])
                ? vol_wd : vobj_len[vobj_len_ridx[9:0]];
            vobj_builtin_rdata <= vobj_builtin[
                (casestate_q == S_HEAP_WAIT || state == S_HEAP_WAIT ||
                 casestate_q == S_HEAP_CMP || state == S_HEAP_CMP ||
                 casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_OGETI_NAT || state == S_V64_OGETI_NAT) ?
                    hp_oid : e64_vobj_raddr];
            vfn_valid_rdata <= vfn_valid[
                vgc_mark_pend ? vgc_mark_word[12:0] :
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2) ? valloc_i[12:0] : e64_vfn_raddr];
            vfn_gen_rdata <= vfn_gen[
                (casestate_q == S_V64_GC_SWEEP_OBJ ||
                 state == S_V64_GC_SWEEP_OBJ) ? vgc_obj_i :
                (casestate_q == S_V64_METH || state == S_V64_METH ||
                 casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2) ? valloc_i[12:0] : e64_vfn_raddr];
            if (vfn_proto_pa_we) vfn_proto[vfn_proto_pa_waddr] <= vfn_proto_pa_wdata;
            vfn_proto_rdata <= vfn_proto[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] : e64_vfn_raddr];
            if (vfn_env_pa_we) vfn_env[vfn_env_pa_waddr] <= vfn_env_pa_wdata;
            vfn_env_rdata <= vfn_env[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_nparam_rdata <= vfn_nparam[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_entry_rdata <= vfn_entry[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            vfn_flags_rdata <= vfn_flags[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            if (vfn_bound_this_pa_we) vfn_bound_this[vfn_bound_this_pa_waddr] <= vfn_bound_this_pa_wdata;
            vfn_bound_this_rdata <= vfn_bound_this[
                (casestate_q == S_V64_GC_FN || state == S_V64_GC_FN) ?
                    vgc_cur[12:0] :
                (casestate_q == S_V64_CTOR_ENV || state == S_V64_CTOR_ENV) ?
                    hp_rval[12:0] :
                (casestate_q == S_V64_CTOR_VARS || state == S_V64_CTOR_VARS) ?
                    vvars_rdata[12:0] :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd3) ?
                    (vcallback_fe ? e64_vfe_fn_q[12:0] :
                     intern_ctor_fn ? bind_ins[12:0] :
                     ((vsp >= (vcall_argc + 12'd1)) ?
                        `VST_AT(vsp - vcall_argc - 12'd1)[12:0] : 13'd0)) :
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd2 && valloc_bind &&
                 valloc_bind_src != 13'h1FFF) ?
                    valloc_bind_src : e64_vfn_raddr];
            {vframe_setter_rdata, vframe_rip_rdata, vframe_bsp_rdata} <= vframe_control[
                (casestate_q == S_V64_FOREACH || state == S_V64_FOREACH) &&
                (e64_vcsp_q != 8'd0) ? (e64_vcsp_q - 8'd1) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_esc_rdata <= vframe_escaped[e64_vframe_raddr];
            vframe_this_rdata <= vframe_this[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_env_rdata <= vframe_env[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_fn_rdata <= vframe_fn[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            vframe_ctor_rdata <= vframe_ctor[
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[8:2] : e64_vframe_raddr];
            fill_lut_rdata <= fill_lut[hs64 ? e64_fill_lut_raddr : 10'd0];
            vtimer_valid_rdata <= vtimer_valid[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_id_rdata <= vtimer_id[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_due_rdata <= vtimer_due[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                e64_vtimer_raddr];
            vtimer_fn_rdata <= vtimer_fn[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[5:0] : e64_vtimer_raddr];
            vtimer_period_rdata <= vtimer_period[
                (casestate_q == S_V64_FRAME_TIMER || state == S_V64_FRAME_TIMER) ?
                    ((bind_k < 8'd64) ? bind_k[5:0] : vt_pick[5:0]) :
                e64_vtimer_raddr];
            vlistener_ev_rdata <= vlistener_ev[
                lsv_serving ? lsv_k[3:0] :
                (casestate_q == S_V64_FRAME_KEY || state == S_V64_FRAME_KEY) ?
                    ((bind_k < 8'd16) ? bind_k[3:0] : vk_pick[3:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[4:1] : 4'd0];
            vlistener_fn_rdata <= vlistener_fn[
                lsv_serving ? lsv_k[3:0] :
                (casestate_q == S_V64_FRAME_KEY || state == S_V64_FRAME_KEY) ?
                    ((bind_k < 8'd16) ? bind_k[3:0] : vk_pick[3:0]) :
                (casestate_q == S_V64_GC_ROOT || state == S_V64_GC_ROOT) ?
                    vgc_root_i[4:1] : 4'd0];
            vlong_used_rdata <= vlong_used[
                (casestate_q == S_FREE_ARR || state == S_FREE_ARR ||
                 casestate_q == S_ARR_PROMOTE || state == S_ARR_PROMOTE ||
                 ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                  valloc_kind == 2'd1)) ? valloc_i[6:0] : 7'd0];
            // Registered glyph fetch — one row of one character per cycle
            font_rdata <= font_rom[font_raddr];
            // Scalar rdata from parent 1-D arrays (no unpacked ports).
            // name_hash_tbl: own Port A/B processes (not this mux).
            e32_name_has_tos <= names_ok && name_has[
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] : 10'd0];
            if (jnb_we) jn_bucket[jnb_wa] <= jnb_wd; // the ONLY write statement
        jn_bucket_rdata <= jn_bucket[
                // pre-warm during CONCAT: jn_h updates at the handoff beat,
                // and the 5th way fires the very next beat — presenting the
                // concat's final hash here has the row ready in time.
                (casestate_q == S_CONCAT || state == S_CONCAT)
                    ? cc_h[9:0] : jn_h[9:0]];
            e32_name_len_tos <= name_len_tbl[
                ((casestate_q == S_JOIN_FIND) || (state == S_JOIN_FIND)) ?
                    (jn_rd_arm ? 10'(jn_i[9:0] + 10'd1) : jn_i[9:0]) : // FIND stream (see name_hash_raddr)
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] :
                // same jn_slot_arm timing as name_hash_raddr above
                (((casestate_q == S_JOIN) || (state == S_JOIN)) && jn_slot_arm) ?
                    varr_rdata[9:0] :
                10'd0];
            e32_name_off_tos <= name_off_r1[
                ((casestate_q == S_CONCAT) || (state == S_CONCAT)) ?
                    (cc_second ? cc_bv[9:0] : cc_av[9:0]) :
                ((casestate_q == S_TXT_LD) || (state == S_TXT_LD)) ?
                    txt_val[9:0] :
                hs64 ? e64_name_off_raddr : 10'd0];
            // During EXEC the code port already streams op N+1
            // (prefetch handover) — these reads must use the CAPTURED op
            // word, or MAKE_FN's identity interning reads a garbage row
            // (DONKEY: rAF callback identity corrupted, rafcall stuck 1).
            e32_intern_var_rdata <= intern_var[
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? vcall_entry[9:0] :
`ifdef JMR_PF_SKIP
                hs64 ? e64_opw[17:8] : 10'd0];
`else
                hs64 ? code_rdata[17:8] : 10'd0];
`endif
            e32_intern_var_ok_rdata <= intern_var_ok[
                ((casestate_q == S_V64_ALLOC || state == S_V64_ALLOC) &&
                 valloc_kind == 2'd0) ? vcall_entry[9:0] :
`ifdef JMR_PF_SKIP
                hs64 ? e64_opw[17:8] : 10'd0];
`else
                hs64 ? code_rdata[17:8] : 10'd0];
`endif
            // STRIDX_WR samples char_id_rdata. casestate_q is STRIDX_WR
            // that beat — without it the mux dropped name_rdata and WR
            // planted undefined, so row[col]==="1" never fired.
            e32_char_id_rdata <= char_id[
                ((state == S_V64_STRIDX) ||
                 (state == S_V64_STRIDX_WR) ||
                 (casestate_q == S_V64_STRIDX) ||
                 (casestate_q == S_V64_STRIDX_WR))
                ? name_rdata : 8'd0];
            e32_char_ok_rdata <= char_ok[
                ((state == S_V64_STRIDX) ||
                 (state == S_V64_STRIDX_WR) ||
                 (casestate_q == S_V64_STRIDX) ||
                 (casestate_q == S_V64_STRIDX_WR))
                ? name_rdata :
                ((state == S_STR_WR) || (casestate_q == S_STR_WR))
                ? txt_buf_rdata : 8'd0];
            if (vgc_queue_pa_we) vgc_queue[vgc_queue_pa_waddr] <= vgc_queue_pa_wdata;
        vgc_queue_rdata <= vgc_queue[vgc_qr];
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hs_st(S_IDLE);
            first_frame_o <= 0;
            running <= 1'b0;
            looping <= 1'b0;
            fb_we <= 1'b0; fb_swap <= 1'b0;
            rast_go <= 1'b0; rast_wait <= 1'b0;
            did_swap <= 1'b0; present_pend <= 1'b0; fb_dirty <= 1'b0;
            fbs_armed <= 1'b0;
            env_len_arm <= 1'b0;
            fb_waddr <= '0; fb_wdata <= '0; fb_x <= '0; fb_y <= '0;
            fb_dump_addr <= '0; fb_dump_sel <= 1'b0;
            sp <= '0; hs_ip('0);
            hs_vsp('0); hs_vcsp('0); vconst_lo <= '0;
            rect_ld_arm <= 1'b0;
            rect_ld_k <= 2'd0;
            rect_origin_x <= 48'sd0; rect_origin_y <= 48'sd0;
            rect_scaled_q <= 48'sd0; rect_extent_positive_q <= 1'b0;
            vsp_d <= '0;
            vst_we <= 1'b0;
            imgd_pend <= 1'b0;
            sprb_pend <= 1'b0;
            name_we <= 1'b0;
            json_we <= 1'b0;
            name_hash_we <= 1'b0;
            varr_len_we <= 1'b0;
            vobj_alloc_we <= 1'b0;
            vvars_we <= 1'b0;
            vst_waddr <= '0;
            vst_wdata <= '0;
            vst_hold_win <= 1'b0;
            vst_refill_i <= 4'd0;
            vst_refill_arm <= 1'b0;
            vst_refill_ret <= S_IDLE;
            aset_win_retried <= 1'b0;
            vfree_armed <= 1'b0;
            vfree_ok <= 1'b0;
            vfree_arr_long <= 1'b0;
            vprom_done <= 1'b0;
            vprom_copy <= 1'b0;
            hp_prom_wr <= 1'b0;
            hp_prom_phys <= 8'd0;
            vprom_ret <= S_IDLE;

            bind_mode <= 2'd0;
            bind_k <= '0; bind_n <= '0; bind_argc <= '0;
            bind_base <= '0; bind_src <= '0; bind_vsp_next <= '0;
            bind_ip <= '0; bind_ins <= V64_UNDEFINED;
            intern_ctor_hold <= 1'b0;
            intern_ctor_entry <= 16'd0;
            intern_ctor_nparam <= 6'd0;
            intern_ctor_flags <= 3'd0;
            intern_ctor_env <= V64_UNDEFINED;
            bind_ret <= S_IDLE;
            bind_armed <= 1'b0; bind_rd_arm <= 1'b0;
            minmax_is_min <= 1'b0;
            minmax_k <= '0; minmax_n <= '0;
            minmax_base <= '0; minmax_acc <= V64_UNDEFINED;
            vdiv_num <= '0; vdiv_quot <= '0; vdiv_rem <= '0;
            vdiv_den <= '0; vdiv_count <= '0; vdiv_exp <= '0;
            vdiv_sign <= 1'b0;
            vmod_rem <= '0; vmod_den <= '0; vmod_count <= '0;
            vmod_exp <= '0; vmod_sign <= 1'b0;
            hs_vgc_qr('0); hs_vgc_qw('0); hs_vgc_clear_i('0);
            vgc_obj_i <= '0; vgc_arr_i <= '0; vgc_slot_i <= '0;
            vgc_cur <= '0; vgc_root_i <= '0; hs_valloc_i('0);
            vobj_next <= '0; varr_next <= '0; vfn_next <= '0;
            venv_next <= '0; hs_valloc_kind(2'd0);
            hs_valloc_retried(1'b0);
            hs_vgc_halt_after(1'b0);
            gc_ran_this_frame <= 1'b0;
            gc_frame_age <= 2'd0;
            vgc_env_i <= '0; vgc_root_phase <= '0;
            cls_scan <= 1'b0; cls_armed <= 1'b0; cls_done <= 1'b0;
            cls_hit <= 1'b0;
            cls_ctor_mode <= 1'b0; cls_c <= 4'd0; cls_m <= 4'd0;
            cls_seq <= 1'b0; cls_prime <= 1'b0;
            cm_serving <= 1'b0; cm_served_hold <= 1'b0; cm_res_we <= 1'b0;
            lsv_serving <= 1'b0; lsv_served_hold <= 1'b0; lsv_res_we <= 1'b0;
            lsv_arm <= 1'b0; lsv_k <= 5'd0; lsv_w <= 5'd0; lsv_same <= 5'd0; lsv_dup <= 1'b0; lsv_res <= 3'd0;
            cls_cls <= 16'd0; cls_key <= 16'd0;
            callref_phase <= 0;callref_pending <= 0;
            cls_ctor_q <= 16'hFFFF; cls_mip_q <= 16'hFFFF; cls_gip_q <= 16'hFFFF;
            cx_active<=0;cx_phase<=0;
            cls_sip_q <= 16'hFFFF; setter_pending <= 0; vfr_setter <= 0; image_setters <= 0;
            hs_vcall_value(1'b0); hs_vcall_entry('0); hs_vcall_argc('0);
            hs_vcall_set_this(1'b0);
            hs_vcall_this(V64_UNDEFINED);
            hs_vcall_ctor_val(V64_UNDEFINED);
            imgd_v64 <= 1'b0;
            hs_vthis(V64_UNDEFINED); hs_venv(V64_UNDEFINED);
            hs_vraf_n('0); vraf_snap_n <= '0; vraf_i <= '0;
            vtimer_n <= '0; vframe_no <= '0; vtimer_seq <= 32'd1;
            vrng <= 32'h6d2b79f5; vconsole_n <= '0;
            vtimer_pick <= '0; vcallback_raf <= 1'b0;
            vcallback_timer <= 1'b0; hs_vgc_wait_after(1'b0);
            vgc_resume <= 2'd0;
            hs_vnat_base('0); hs_vdraw_i('0);
            vdraw_cx <= '0; vdraw_cy <= '0;
            hs_vnat_dom(3'd0); vnat_style <= V64_UNDEFINED;
            vmetrics <= V64_UNDEFINED;
            hs_valloc_metrics(1'b0);
            vmetrics_w <= 32'd0;
            txt_kp <= 48'sd524288;
            vkev_event <= V64_UNDEFINED; vlistener_n_ff <= 5'd0;
            vmouse_active <= 0; vmouse_packet <= 0; vmouse_prop <= 0;
            vmouse_slot <= 0; vmouse_type_id <= 16'hffff; mouse_evt_pop <= 0;
            vkey_custom <= 1'b0; vkey_want_ev <= 64'd0;
            vkey_li <= 5'd0;
            v64_frame_armed <= 1'b0;
            vcallback_key <= 1'b0; vcallback_fe <= 1'b0;
            vfe_arr <= V64_UNDEFINED; vfe_fn <= V64_UNDEFINED;
            vfe_i <= 8'd0; vfe_ret <= 16'd0; vfe_base <= '0; vfe_sp <= 4'd0;
            vfe_mode <= 2'd0;
            vfe_map <= V64_UNDEFINED;
            hs_valloc_now_fn(1'b0);
            hs_valloc_regex(1'b0);
            hs_valloc_regex_pack(32'd0);
            hs_valloc_arr_n(8'd0);
            hs_valloc_fn_entry(16'd0);
            hs_valloc_fn_a1(8'd0);
            hs_valloc_proto(1'b0);
            hs_valloc_proto_fn(13'd0);
            hs_valloc_bind(1'b0);
            hs_valloc_bind_src(13'd0);
            hs_valloc_bind_this(V64_UNDEFINED);
            vctor_scan <= '0;
            vctor_armed <= 1'b0;
            vctor_jmp <= 16'hFFFF;
            vctor_lets <= 6'd0;
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            hs_m_ip <= 1'b0; hs_m_code <= 1'b0; hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
            hs_m_hp_cmd <= 1'b0; hs_m_hp_oid <= 1'b0;
            hs_m_hp_aid <= 1'b0; hs_m_hp_env <= 1'b0; hs_m_hp_eid <= 1'b0;
            hs_m_hp_slot <= 1'b0; hs_m_hp_aslot <= 1'b0; hs_m_hp_len <= 1'b0;
            hs_m_hp_alen <= 1'b0; hs_m_hp_lim <= 1'b0; hs_m_hp_key <= 1'b0;
            hs_m_hp_wval <= 1'b0; hs_m_hp_rval <= 1'b0; hs_m_hp_hit <= 1'b0;
            hs_m_hp_ret <= 1'b0; hs_m_hp_phase <= 1'b0;
            hs_m_hp_qn <= 1'b0; hs_m_hp_qi <= 1'b0; hs_m_hp_si <= 1'b0;
            hs_m_hp_ss <= 1'b0; hs_m_hp_tn <= 1'b0; hs_m_hp_from_stack <= 1'b0;
            hs_m_hp_make_arr <= 1'b0; hs_m_hp_vbase <= 1'b0;
            hs_m_hp_spr_w <= 1'b0; hs_m_hp_spr_h <= 1'b0; hs_m_hp_nat <= 1'b0;
            hs_m_hp_qk <= 1'b0; hs_m_hp_qv <= 1'b0; hs_m_hp_qt <= 1'b0;
            hs_m_valloc_kind <= 1'b0; hs_m_valloc_i <= 1'b0; hs_m_valloc_arr_n <= 1'b0; hs_m_valloc_retried <= 1'b0; hs_m_vnat_dom <= 1'b0; hs_m_vnat_base <= 1'b0; hs_m_valloc_now_fn <= 1'b0; hs_m_valloc_bind <= 1'b0; hs_m_valloc_bind_src <= 1'b0; hs_m_valloc_bind_this <= 1'b0; hs_m_valloc_fn_entry <= 1'b0; hs_m_valloc_fn_a1 <= 1'b0; hs_m_valloc_proto <= 1'b0; hs_m_valloc_proto_fn <= 1'b0; hs_m_valloc_metrics <= 1'b0; hs_m_valloc_regex <= 1'b0; hs_m_valloc_regex_pack <= 1'b0; hs_m_vcall_value <= 1'b0; hs_m_vcall_argc <= 1'b0; hs_m_vcall_entry <= 1'b0; hs_m_vcall_set_this <= 1'b0; hs_m_vcall_this <= 1'b0; hs_m_vcall_ctor_val <= 1'b0; hs_m_vcsp <= 1'b0; hs_m_vthis <= 1'b0; hs_m_venv <= 1'b0; hs_m_vraf_n <= 1'b0; hs_m_vlistener_n <= 1'b0; hs_m_vgc_halt_after <= 1'b0; hs_m_vgc_wait_after <= 1'b0; hs_m_vgc_clear_i <= 1'b0; hs_m_vgc_qr <= 1'b0; hs_m_vgc_qw <= 1'b0; hs_m_vdraw_i <= 1'b0; hs_m_vdraw_x <= 1'b0; hs_m_vdraw_y <= 1'b0; hs_m_vdraw_w <= 1'b0; hs_m_vdraw_h <= 1'b0; hs_m_vdraw_color <= 1'b0; hs_m_vfe_i <= 1'b0; hs_m_vfe_pop <= 1'b0;
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;

            hs_hp_env(1'b0); hs_hp_eid('0);
            hs_hp_slot('0); hs_hp_aslot('0); hs_hp_len('0); hs_hp_alen('0);
            hs_hp_lim('0); hs_hp_key('0); hs_hp_wval('0); hs_hp_rval('0);
            hs_hp_hit(1'b0); hs_hp_phase('0); hs_hp_qn('0); hs_hp_qi('0);
            vgc_rd_arm <= 1'b0; jn_rd_arm <= 1'b0;
            jn_hit_v <= 4'd0; jn_cache_try <= 1'b0; jn_cache_i <= 3'd0;
            jn_name_arm <= 1'b0; vjs_name_arm <= 1'b0; tfn_rd_arm <= 1'b0;
            jn_slot_arm <= 1'b0; hp_slot_arm <= 1'b0; hp_slot_pend <= 1'b0;
            vfe_rd_arm <= 1'b0; vjs_rd_arm <= 1'b0; valloc_rd_arm <= 1'b0;
            stridx_rd_arm <= 1'b0;
            stridx_alloc_pending <= 1'b0; stridx_alloc_id <= 10'd0;
            hp_proto_arm <= 1'b0;
            json_ch0 <= 8'd0;
            vt_found <= 1'b0; vk_found <= 1'b0;
            vt_pick <= 7'd0; vk_pick <= 5'd0;
            vt_best_due <= 32'sh7fffffff; vt_best_id <= 32'sh7fffffff;
             
            vgc_mark_pend <= 1'b0; vgc_mark_arm <= 1'b0;
            vgc_mark_word <= 64'd0;
            hs_hp_from_stack(1'b0); hs_hp_make_arr(1'b0); hs_hp_vbase('0);
            hs_hp_spr_w('0); hs_hp_spr_h('0); hs_hp_nat(4'd0);
            n_ops <= '0; n_consts <= '0; ops_base <= '0;
            hs_code('0);
            nat_id <= '0; nat_argc <= '0;
            c_i <= '0;
            dbg_gc_n <= '0;
            dbg_stack_ovf <= '0; dbg_call_ovf <= '0;
            machine_fault <= 1'b0; fault_code <= 8'd0; fault_site <= 16'd6115;
            ui_text_toggle_o<=0;ui_text_menu_o<=0;ui_text_title_o<=0;ui_text_first_o<=0;ui_text_last_o<=0;ui_text_byte_o<=0;
            fs_request<=0;fs_command<=0;fs_arguments<=0;fs_phase<=0;fs_result_q<=0;
            ui_prop_phase<=0;ui_prop_name<=0;ui_prop_ptr<=0;ui_prop_len<=0;ui_prop_i<=0;ui_prop_menu<=0;ui_prop_title<=0;
            prev_joy <= 6'd0; joy_down_edge <= 6'd0; joy_up_edge <= 6'd0;
            sram_req <= 1'b0; sram_addr <= '0; blit_wait <= 1'b0;
            bs_arena_mode<=0;bs_pending<=0;bs_arena_base<=0;bs_checked<=0;
            sram_we <= 1'b0; sram_wdata <= '0;
            sin_ph <= 4'd0; sin_turn <= 16'd0;
            aset_mode <= 1'b0; sprd_mode <= 1'b0; hdr_w <= 16'd3;
            boot_clr <= 1'b0;
            heap_clr_busy <= 1'b0;
            heap_clr_i <= 12'd0;
            
        end else begin
            fb_we <= 1'b0;
            // Reuse the existing registered font product for rendering and
            // measurement. Method operand warmup lets current context settle.
            txt_kp <= 48'(ctx_font_px) * 48'(e64_ctx_sx_q);
            fb_swap <= 1'b0;
            rast_go <= 1'b0;
            vst_we <= 1'b0;
            vfr_we <= 1'b0;
            vom_we_cls <= 1'b0; vom_we_bi <= 1'b0; veg_we <= 1'b0;
            vog_we <= 1'b0; vfg_we <= 1'b0; vag_we <= 1'b0;
            vmko_we <= 1'b0; vmkf_we <= 1'b0; vmka_we <= 1'b0; vmke_we <= 1'b0;
            vfv_we <= 1'b0; vav_we <= 1'b0; vev_we <= 1'b0; vvv_we <= 1'b0; vlo_we <= 1'b0;
            vli_we <= 1'b0;
            nof_we <= 1'b0; nbl_we <= 1'b0; nlt_we <= 1'b0; flu_we <= 1'b0;
            vlu_we <= 1'b0;
            vtd_we <= 1'b0; nh_we <= 1'b0; txw_we <= 1'b0;
            cmn_we <= 1'b0; cmi_we <= 1'b0;
            vol_we <= 1'b0; vel_we <= 1'b0; jnb_we <= 1'b0;
            // imgd_pend is HANDSHAKE STATE (held across beats until sram_ack),
            // not a strobe - it must NOT be cleared here. The old imgd_we that
            // lived on this line was a one-shot BRAM write strobe.
            vgc_queue_pa_we <= 1'b0; vconsts_pa_we <= 1'b0;
            vobj_proto_pa_we <= 1'b0; vfn_proto_pa_we <= 1'b0;
            vfn_env_pa_we <= 1'b0; vfn_bound_this_pa_we <= 1'b0;
            venv_parent_pa_we <= 1'b0;
            // spr strobe retired (external SRAM)
            name_we <= 1'b0;
            json_we <= 1'b0;
            name_hash_we <= 1'b0;
            varr_len_we <= 1'b0;
            vobj_alloc_we <= 1'b0;
            vvars_we <= 1'b0;
            // TOS window follows last cycle's write + this cycle's vsp
            // (already NBA-updated from the previous op). S_V64_BIND holds
            // the window; skip one cycle after it so vsp_d can catch up.
            // Do not skip vst_we on that release cycle — GET_PROP x then
            // SET_PROP x ({x:current.x}) stored leftover NaN while the
            // object still had x=12 (PACMAN ARRAY_SET 241, change=1 wrap).
            // leave_hold: parent unique case (ALLOC/HEAP) writes vst_wr/hs_vsp
            // while state is still EXEC. Window must follow parent that beat
            // or MAKE_FN+CALL_VAL / HEAP LOAD_VAR TOS is the previous value
            // (DONKEY IIFE fault 4, inner rAF nid 27).
            begin
                logic [11:0] wvsp;
                logic wvst_we;
                logic [11:0] wvst_waddr;
                logic [63:0] wvst_wdata;
                logic use_e64_win;
                logic use_e64_wr;
                // Sticky hs_m_vsp: parent vsp_ff is truth (MAKE_FN ALLOC
                // push). Extra EXEC beat with lagged e64_vsp_q shifted the
                // TOS window (win[0]=UNDEF, Fn in win[1]) — nonempty IIFE
                // CALL_VAL fault 4. Empty IIFE had vsp_d==e64 so no shift.
                use_e64_win = (state == S_V64_EXEC) && !e64_leave_hold
                    && !hs_m_vsp;
                wvsp = use_e64_win ? e64_vsp_q : vsp;
                // The write the window follows MUST be the write the vstack
                // SRAM takes, selected the same way (see the vstack Port A
                // process). Keying it off use_e64_win instead diverged them:
                // exec's *_we_q is registered, so it lands on the leave_hold
                // / FETCH_WAIT beat when use_e64_win is already false — SRAM
                // stored exec's word while the window shifted the parent's
                // stale vst_wdata into win[0]. That is why a pushed callee
                // handle read back untagged (CALL_VAL fault 4 on any call
                // with computed args) and why fillRect saw the previous
                // rect's x/y (INVADERS score-table sprites all on one spot).
                use_e64_wr = e64_vst_we_q && e64_wr_ok &&
                    ((state == S_V64_EXEC) || (state == S_FETCH_WAIT) ||
                     (state == S_V64_WIN_FILL));
                wvst_we = use_e64_wr ? 1'b1 : vst_we;
                wvst_waddr = use_e64_wr ? e64_vst_waddr_q : vst_waddr;
                wvst_wdata = use_e64_wr ? e64_vst_wdata_q : vst_wdata;
            if (use_e64_win ? e64_vst_hold_win_q : vst_hold_win) begin
                if (state != S_V64_BIND && state != S_V64_WIN_FILL) begin
                    if (wvst_we) begin
                        integer d;
                        d = integer'(wvsp) - 1 - integer'(wvst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= wvst_wdata;
                    end
                    vst_hold_win <= 1'b0;
                end
            end else if (wvsp > vsp_d) begin
                    vst_win[15] <= vst_win[14];
                    vst_win[14] <= vst_win[13];
                    vst_win[13] <= vst_win[12];
                    vst_win[12] <= vst_win[11];
                    vst_win[11] <= vst_win[10];
                    vst_win[10] <= vst_win[9];
                    vst_win[9] <= vst_win[8];
                    vst_win[8] <= vst_win[7];
                    vst_win[7] <= vst_win[6];
                    vst_win[6] <= vst_win[5];
                    vst_win[5] <= vst_win[4];
                    vst_win[4] <= vst_win[3];
                    vst_win[3] <= vst_win[2];
                    vst_win[2] <= vst_win[1];
                    vst_win[1] <= vst_win[0];
                    vst_win[0] <= wvst_wdata;
                end else if (wvsp < vsp_d) begin
                    begin
                        integer sh, wi;
                        sh = integer'(vsp_d) - integer'(wvsp);
                        if (wvst_we && wvst_waddr == (wvsp - 12'd1))
                            vst_win[0] <= wvst_wdata;
                        else if (sh < 16)
                            vst_win[0] <= vst_win[sh[3:0]];
                        for (wi = 1; wi < 16; wi++)
                            if (wi + sh < 16)
                                vst_win[wi] <= vst_win[wi[3:0] + sh[3:0]];
                    end
                end else if (wvst_we) begin
                    begin
                        integer d;
                        d = integer'(wvsp) - 1 - integer'(wvst_waddr);
                        if (d >= 0 && d < 16)
                            vst_win[d[3:0]] <= wvst_wdata;
                    end
                end
            end
            vsp_d <= ((state == S_V64_EXEC) && !e64_leave_hold && !hs_m_vsp)
                ? e64_vsp_q : vsp;
            // Exec-owned copies: default no poke; states below may pulse.
            e64_p_clr <= 1'b0;
            e64_p_we <= 1'b0;
            // ip/vsp overlay must survive FETCH_WAIT after ALLOC/HEAP poke.
            // Clearing every cycle dropped hs_m before CALL_VAL: vsp mux was
            // e64=0 while vst_win[0] already held the Fn (IIFE fault 4).
            if ((state == S_V64_EXEC) && !e64_leave_hold) begin
                hs_m_ip <= 1'b0; hs_m_code <= 1'b0;
                hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
                hs_m_vcsp <= 1'b0; hs_m_venv <= 1'b0; hs_m_vthis <= 1'b0;
            end else if (!hs64) begin
                hs_m_ip <= 1'b0; hs_m_code <= 1'b0;
                hs_m_state <= 1'b0; hs_m_vsp <= 1'b0;
                hs_m_vcsp <= 1'b0; hs_m_venv <= 1'b0; hs_m_vthis <= 1'b0;
            end
            hs_m_hp_cmd <= 1'b0; hs_m_hp_oid <= 1'b0;
            hs_m_hp_aid <= 1'b0; hs_m_hp_env <= 1'b0; hs_m_hp_eid <= 1'b0;
            hs_m_hp_slot <= 1'b0; hs_m_hp_aslot <= 1'b0; hs_m_hp_len <= 1'b0;
            hs_m_hp_alen <= 1'b0; hs_m_hp_lim <= 1'b0; hs_m_hp_key <= 1'b0;
            hs_m_hp_wval <= 1'b0; hs_m_hp_rval <= 1'b0; hs_m_hp_hit <= 1'b0;
            hs_m_hp_ret <= 1'b0; hs_m_hp_phase <= 1'b0;
            hs_m_hp_qn <= 1'b0; hs_m_hp_qi <= 1'b0; hs_m_hp_si <= 1'b0;
            hs_m_hp_ss <= 1'b0; hs_m_hp_tn <= 1'b0; hs_m_hp_from_stack <= 1'b0;
            hs_m_hp_make_arr <= 1'b0; hs_m_hp_vbase <= 1'b0;
            hs_m_hp_spr_w <= 1'b0; hs_m_hp_spr_h <= 1'b0; hs_m_hp_nat <= 1'b0;
            hs_m_hp_qk <= 1'b0; hs_m_hp_qv <= 1'b0; hs_m_hp_qt <= 1'b0;
            hs_m_valloc_kind <= 1'b0; hs_m_valloc_i <= 1'b0; hs_m_valloc_arr_n <= 1'b0; hs_m_valloc_retried <= 1'b0; hs_m_vnat_dom <= 1'b0; hs_m_vnat_base <= 1'b0; hs_m_valloc_now_fn <= 1'b0; hs_m_valloc_bind <= 1'b0; hs_m_valloc_bind_src <= 1'b0; hs_m_valloc_bind_this <= 1'b0; hs_m_valloc_fn_entry <= 1'b0; hs_m_valloc_fn_a1 <= 1'b0; hs_m_valloc_proto <= 1'b0; hs_m_valloc_proto_fn <= 1'b0; hs_m_valloc_metrics <= 1'b0; hs_m_valloc_regex <= 1'b0; hs_m_valloc_regex_pack <= 1'b0; hs_m_vcall_value <= 1'b0; hs_m_vcall_argc <= 1'b0; hs_m_vcall_entry <= 1'b0; hs_m_vcall_set_this <= 1'b0; hs_m_vcall_this <= 1'b0; hs_m_vcall_ctor_val <= 1'b0; hs_m_vraf_n <= 1'b0; hs_m_vlistener_n <= 1'b0; hs_m_vgc_halt_after <= 1'b0; hs_m_vgc_wait_after <= 1'b0; hs_m_vgc_clear_i <= 1'b0; hs_m_vgc_qr <= 1'b0; hs_m_vgc_qw <= 1'b0; hs_m_vdraw_i <= 1'b0; hs_m_vdraw_x <= 1'b0; hs_m_vdraw_y <= 1'b0; hs_m_vdraw_w <= 1'b0; hs_m_vdraw_h <= 1'b0; hs_m_vdraw_color <= 1'b0; hs_m_vfe_i <= 1'b0; hs_m_vfe_pop <= 1'b0;
            // Mirror exec64's path-command writes into the
            // parent arrays that S_PWALK / S_PDO / S_LINE / S_CIRCLE / S_QSEG
            // raster from. exec64 fills its own copy then asks for S_PWALK,
            // but the parent's pc_* had NO writer at all — pc_n stuck at 0, so
            // the walk aborted on beat 0 and every arc / lineTo / fill /
            // stroke painted nothing (PX line=0 circ=0 in every title).
            // 16 slots of FFs, not SRAM; same shape as the #47 mirror.
            // pc_we defaults to 0 in exec64's always_comb, so this is quiet
            // whenever exec is disabled or the opcode is not a path command.
            // Mirror exec64's vjs seed writes (stringify
            // JSON.stringify(x) writes vjs_val[0]=x in exec's copy; the parent
            // S_V64_JSON walker reads the parent copy).
            if (e64_js_we_q) begin
                vjs_val[e64_js_waddr_q] <= e64_vjs_val_wdata_q;
                js_i  [e64_js_waddr_q] <= e64_js_i_wdata_q;
                js_ph [e64_js_waddr_q] <= e64_js_ph_wdata_q;
            end
            if (e64_pc_we_q) begin
                pc_op [e64_pc_waddr_q] <= e64_pc_op_wdata_q;
                pc_a1 [e64_pc_waddr_q] <= e64_pc_a1_wdata_q;
                pc_a2 [e64_pc_waddr_q] <= e64_pc_a2_wdata_q;
                pc_a3 [e64_pc_waddr_q] <= e64_pc_a3_wdata_q;
                pc_a4 [e64_pc_waddr_q] <= e64_pc_a4_wdata_q;
                pc_a5 [e64_pc_waddr_q] <= e64_pc_a5_wdata_q;
                pc_ccw[e64_pc_waddr_q] <= e64_pc_ccw_wdata_q;
            end
            e64_p_addr2 <= 16'd0;
            e64_p_data2 <= 64'd0;
            e64_p_data3 <= 64'd0;
            e64_p_data4 <= 64'd0;
            e64_p_data5 <= 64'd0;
            e64_p_frame_we <= 1'b0;

            // Parent-only name_blen / name_hash_tbl: rdata next clock, no exec copy.
            // One write port: p_clr we (exec combo) OR trail/JOIN poke 17/40
            // (parent p_we, same posedge exec consumes the poke). Combo we
            // from poke is a cycle late and missed the pulse — intern
            // lengths stayed post-p_clr zero.
            if (e64_p_we && e64_p_sel == 6'd17) begin
                begin nbl_we <= 1'b1; nbl_wa <= e64_p_addr[9:0]; nbl_wd <= e64_p_data[15:0]; end
            end else if (e64_p_we && e64_p_sel == 6'd41) begin
                // Trail phase 4 pokes 41 (u8 intern len). Same Port A as
                // poke 17 so GET_PROP .length is not a second FSM driver.
                begin nbl_we <= 1'b1; nbl_wa <= e64_p_addr[9:0]; nbl_wd <= {8'd0, e64_p_data[7:0]}; end
            end else if (e64_name_blen_we)
                begin nbl_we <= 1'b1; nbl_wa <= e64_name_blen_waddr; nbl_wd <= e64_name_blen_wdata; end
            // name_hash_tbl writes: Port A process (name_hash_we / poke 40 / exec we).
            // name_has: ONE write statement so 1W is provable (three
            // separate writes kept it FF — census: 7.7k LUTs). Priority
            // preserves the old semantics: poke17 sets the bit and used
            // to exclude name_has_we; nh (heap-clr/load) never collides.
            begin
                logic nh_do;
                logic [9:0] nh_a;
                logic nh_d;
                nh_do = 1'b0; nh_a = '0; nh_d = 1'b0;
                if (nh_we) begin
                    nh_do = 1'b1; nh_a = nh_wa; nh_d = nh_wd;
                end else if (e64_p_we && e64_p_sel == 6'd17) begin
                    nh_do = 1'b1; nh_a = e64_p_addr[9:0]; nh_d = 1'b1;
                end else if (e64_name_has_we) begin
                    nh_do = 1'b1; nh_a = e64_name_has_waddr; nh_d = e64_name_has_wdata;
                end
                if (nh_do) name_has[nh_a] <= nh_d;
            end
            kd_fn <= kd_slot[0];
            ku_fn <= ku_slot[0];
            // Skip guard set (clear lives in the FETCH_WAIT dispatch
            // arm below — same ff, single driver)
            if (state != S_V64_EXEC && state != S_FETCH_WAIT)
                pf_post_parent <= 1'b1;
            if (fb_swap || ((state == S_V64_EXEC) && e64_fb_swap_q))
                dbg_swap_n <= dbg_swap_n + 16'd1; // Present count
            // Exec nid 3 (swapBuffers) only set e64_fb_swap_q; dbg counted
            // it but mini_fb.front never flipped, so fillRect landed in the
            // back bank and HDMI/FB? stayed empty. Pulse on the leave_hold
            // beat only (one present per opcode).
            if ((state == S_V64_EXEC) && e64_leave_hold && e64_fb_swap_q) begin
                fb_swap <= 1'b1;
                fb_dirty <= 1'b0;
            end
            // Any pixel written to the back bank makes this frame presentable.
            // casestate_q term: the last copy write is registered on the
            // final S_FB_SYNC beat and SEEN one beat later (state already
            // S_V64_GC_CLEAR) — without it that drain write re-marked the
            // frame dirty and every frame re-presented forever.
            if (fb_we && state != S_FB_SYNC && casestate_q != S_FB_SYNC)
                fb_dirty <= 1'b1;
            // Fence lifecycle. busy rises a beat or two after the swap
            // pulse, so we cannot simply wait for !busy. Track whether the
            // copy was ever actually seen running:
            //   seen && !busy  -> the copy finished; release.
            //   never seen     -> this S_FB_SYNC did not start a present at
            //                     all (paths that reach it without a swap,
            //                     e.g. console/legacy). Release after a
            //                     short watchdog or the fence would block
            //                     EVERY later draw forever — that deadlock
            //                     is what the joystick gate caught, and it
            //                     would have been a black screen on glass.
            // 8191 clks ~= 82 us: orders of magnitude beyond the 1-2 clk
            // swap->busy latency, and negligible against a frame.
            if (fence_arm) begin
                if (fb_present_busy) fence_seen <= 1'b1;
                if (fence_seen && !fb_present_busy)
                    fence_arm <= 1'b0;
                else if (!fence_seen && !fb_present_busy) begin
                    if (fence_wait == 13'h1FFF) fence_arm <= 1'b0;
                    else fence_wait <= fence_wait + 13'd1;
                end
            end
            // C1: the engine draws on the VM's behalf now, so the VM's own
            // fb_we never fires for rect/clear/blit/imgd — the implicit
            // frame-end present (fb_dirty at 14423) starved and legacy .JS
            // titles stopped presenting (battery: swaps stuck at 2 across
            // 43 frames). Any engine issue marks the frame dirty. (A blit
            // of only-transparent pixels now also marks dirty — one benign
            // extra present of an unchanged FB, matching the "this frame
            // drew" intent.)
            if (rast_go)
                fb_dirty <= 1'b1;
            // S_ARR_PROMOTE completion sets vprom_done so the requester
            // stops asking. The JSON paths consume-and-clear it themselves;
            // an exec-requested promote had no such clear, and exec only ever
            // cleared its OWN copy — which the parent never set. Exec then
            // re-requested the promote every beat and the push at that ip
            // spun for the whole 64M frame (INVADERS after Space). Retire the
            // flag at the instruction boundary: exec has already re-evaluated
            // by then.
            if (state == S_FETCH_WAIT) vprom_done <= 1'b0;
            mouse_evt_pop <= 1'b0;
            // Capture raw host key events (any state; drained per frame)
            if (key_evt_stb && (kev_wp + 5'd1) != kev_rp) begin
                if (syn_dedup_ctr != 4'd0 &&
                    key_evt_code == syn_dedup_code) begin
                    // symmetric swallow: this press already arrived as a
                    // SYNTHETIC joy edge (dual-interface pad, reverse
                    // arrival order) — drop the real twin, both edges.
                end else begin
                    kev_q[kev_wp] <= {key_evt_down, key_evt_code};
                    kev_chars[kev_wp] <= key_evt_char;
                    kev_src_joy[kev_wp] <= 1'b0;
                    if (key_evt_down) begin
                        kev_dedup_code <= key_evt_code;
                        kev_dedup_ctr <= 4'd8;
                    end
                    kev_wp <= kev_wp + 5'd1;
                end
                // The
                // dispatch-time supersede only fires when the real event is
                // ALREADY queued. An edge captured while vlistener_n was
                // momentarily 0 (screen swap re-registers listeners) or
                // before this strobe's RPC landed sat armed and converted
                // into a phantom synthetic arrow seconds later. Supersede at
                // ENQUEUE too: any real key traffic invalidates captured
                // KEYBITS edges and re-baselines prev_joy, so only a real
                // joystick (KEYBITS with no KEYEVT twin) ever converts.
                // Scope (a gate caught it: reverse-order keyup
                // vanished): a SWALLOWED twin must not supersede — in
                // reverse arrival the synthetic edges are the authoritative
                // delivery; wiping/rebaselining here erased the pending
                // synthetic keyup before its capture.
                if (!(syn_dedup_ctr != 4'd0 &&
                      key_evt_code == syn_dedup_code)) begin
                    joy_down_edge <= 6'd0;
                    joy_up_edge <= 6'd0;
                    prev_joy <= joy_level_q2;
                end
            end
            // EXEC scalar we is not an else-if vs unique case: leave_hold
            // must still enter ALLOC/RECT/BIND (casestate). Apply we here.
            // RET_VAL clocks win0_we_q; next cycle is FETCH_WAIT / WIN_FILL
            // (not EXEC). Plant regardless so LET_VAR sees the instance.
            if (e64_vst_win0_we)
                vst_win[0] <= e64_vst_win0_wdata;
            // Same reason as vst_win0_we above, for every other exec write:
            // *_we_q is a registered pulse, visible the cycle AFTER exec
            // decided — by then leave_hold has already moved state to
            // ALLOC / HEAP_* / FETCH_WAIT, so gating this block on
            // `state == S_V64_EXEC` silently dropped every write that
            // coincided with leaving EXEC. venv_valid was the loudest:
            // a ctor's env lost its valid bit, so the next LOAD_VAR down
            // the env chain faulted 4 (PACMAN `new Stage()`). Exec clears
            // *_we_q on its first idle beat, so this still applies exactly
            // one write. The parent FSM case runs later in this same
            // always_ff, so a parent write to the same array still wins.
            begin
                if (e64_vraf_we) vraf[e64_vraf_waddr] <= e64_vraf_wdata;
                if (e64_vtimer_we) begin
                    vtimer_valid[e64_vtimer_waddr] <= e64_vtimer_valid_wdata;
                    // Exec setTimeout/clearTimeout only
                    // adjusted EXEC's vtimer_n copy; the parent FF (which
                    // decrements when a timer FIRES in S_V64_FRAME_TIMER)
                    // never saw the increments, and exec never saw the
                    // fire-time decrements — its copy climbed monotonically
                    // to 64 and every later setTimeout faulted 3/3816
                    // (DONKEY throws several timers per barrel). Keep the
                    // parent FF as truth here, and let the frozen exec
                    // absorb p_vtimer_n below.
                    if (e64_vtimer_valid_wdata)
                        vtimer_n <= vtimer_n + 7'd1;
                    else if (vtimer_n != 7'd0)
                        vtimer_n <= vtimer_n - 7'd1;
                    if (e64_vtimer_valid_wdata) begin
                        // Registration commits the next ID; cancellation and
                        // parent interval rescheduling do not consume IDs.
                        vtimer_seq <= 32'(e64_vtimer_id_wdata) + 32'd1;
                        begin vtd_we <= 1'b1; vtd_wa <= e64_vtimer_waddr; vtd_wd <= e64_vtimer_due_wdata; end
                        vtimer_fn[e64_vtimer_waddr] <= e64_vtimer_fn_wdata;
                        vtimer_id[e64_vtimer_waddr] <= e64_vtimer_id_wdata;
                        vtimer_period[e64_vtimer_waddr] <= e64_vtimer_period_wdata;
                    end
                end
                // listener table writes/compaction: the lsv service owns them
                // now (single table; #77's dual-copy sync is structurally gone).
                if (e64_json_mem_we) begin
                    json_we <= 1'b1;
                    json_waddr <= e64_json_mem_waddr[12:0];
                    json_wdata <= e64_json_mem_wdata;
                end
                // varr_len / vvars writes: Port A processes (not this FSM).
                // moved to Port A process (metadata evacuation)
                // moved to Port A process (metadata evacuation)
                if (e64_varr_long_we && e64_varr_long_wdata && e64_varr_lidx_we)
                    begin vlu_we <= 1'b1; vlu_wa <= e64_varr_lidx_wdata[6:0]; vlu_wd <= 1'b1; end
                // moved to Port A process (metadata evacuation)
                // e64_venv_gen_we applies in the dedicated metadata process
                // e64_venv_len_we applies in the dedicated len process
                // moved to Port A process (metadata evacuation)
                // e64_vobj_cls_we applies in the dedicated metadata process
                // moved to Port A process (metadata evacuation)
                if (e64_vframe_we)
                    // record fields write in the dedicated vframe process;
                    // escaped stays here (flat FFs, partial-field writers)
                    vframe_escaped[e64_vframe_waddr] <= e64_vframe_esc_wdata;
            end
            ;
            // Class table is 16×16 FFs (not intern SRAM). Match in one clock.
            // Sequential (c,m) was 256 clocks per GET_PROP miss — play CALL
            // paid that every method. unique-case CAM over BRAM is still
            // forbidden; this is FF equality outside the opcode case.
            if (lsv_served_hold) begin
                if (!e64_lsv_req) begin
                    lsv_served_hold <= 1'b0;
                    lsv_res_we <= 1'b0;
                end
            end else if (e64_lsv_req && !lsv_serving) begin
                lsv_serving <= 1'b1;
                lsv_k <= 5'd0;
                lsv_w <= 5'd0;
                lsv_same <= 5'd0;
                lsv_dup <= 1'b0;
                lsv_arm <= 1'b0;
            end else if (lsv_serving) begin
                if (!lsv_arm) begin
                    if (lsv_k >= vlistener_n) begin
                        lsv_serving <= 1'b0;
                        lsv_served_hold <= 1'b1;
                        lsv_res_we <= 1'b1;
                        if (e64_lsv_op == 2'd1) begin
                            lsv_res_n_out <= vlistener_n;
                            if (lsv_dup) lsv_res <= 3'd1;
                            else if (lsv_same >= 5'd4) lsv_res <= 3'd2;
                            else if (vlistener_n >= 5'd16) lsv_res <= 3'd3;
                            else begin
                                lsv_res <= 3'd0;
                                vlistener_ev[vlistener_n[3:0]] <= e64_lsv_ev;
                                vlistener_fn[vlistener_n[3:0]] <= e64_lsv_fn;
                                // the hs mask cannot land while exec is held
                                // (mask applies live in the frozen branch);
                                // the count rides the result instead.
                                lsv_res_n_out <= vlistener_n + 5'd1;
                                vlistener_n_ff <= vlistener_n + 5'd1;
                            end
                        end else begin
                            lsv_res <= 3'd0;
                            for (int t = 0; t < 16; t++)
                                if (5'(t) >= lsv_w && 5'(t) < vlistener_n) begin
                                    vlistener_ev[t] <= V64_UNDEFINED;
                                    vlistener_fn[t] <= V64_UNDEFINED;
                                end
                            lsv_res_n_out <= lsv_w;
                            vlistener_n_ff <= lsv_w;
                        end
                    end else
                        lsv_arm <= 1'b1; // rdata mux is pointed at lsv_k
                end else begin
                    lsv_arm <= 1'b0;
                    if (e64_lsv_op == 2'd1) begin
                        if (v64_equal(vlistener_ev_rdata, e64_lsv_ev)) begin
                            lsv_same <= lsv_same + 5'd1;
                            if (v64_equal(vlistener_fn_rdata, e64_lsv_fn))
                                lsv_dup <= 1'b1;
                        end
                    end else begin
                        if (!(v64_equal(vlistener_ev_rdata, e64_lsv_ev) &&
                              v64_equal(vlistener_fn_rdata, e64_lsv_fn))) begin
                            vlistener_ev[lsv_w[3:0]] <= vlistener_ev_rdata;
                            vlistener_fn[lsv_w[3:0]] <= vlistener_fn_rdata;
                            lsv_w <= lsv_w + 5'd1;
                        end
                    end
                    lsv_k <= lsv_k + 5'd1;
                end
            end
            if (cm_served_hold) begin
                // Result is LEVEL, held until exec drops the request —
                // exec's *_n consumption only lands on enable&&!leave_hold
                // beats, so a one-beat pulse could be missed (livelock).
                if (!e64_cm_req) begin
                    cm_served_hold <= 1'b0;
                    cm_res_we <= 1'b0;
                end
            end else if (e64_cm_req && !cm_serving &&
                         !cls_scan && !cls_seq) begin
                cls_cls <= e64_cm_cls;
                cls_key <= e64_cm_key;
                cls_ctor_mode <= 1'b0;
                cls_mip_q <= 16'hFFFF;
                cls_scan <= 1'b1;
                cls_armed <= 1'b0;
                cls_done <= 1'b0;
                cm_serving <= 1'b1;
            end
            if (cm_serving && cls_done) begin
                // exec's CAM matched only non-getter entries; the walk fills
                // cls_mip_q with exactly those, so hand that back.
                cm_res_we <= 1'b1;
                cm_res_mip <= cls_mip_q;
                cm_serving <= 1'b0;
                cm_served_hold <= 1'b1;
                cls_done <= 1'b0;
            end
            if (cls_scan) begin
                if (cls_ctor_mode) begin
                    for (int ci = 0; ci < MAX_CLS; ci++) begin
                        if ((5'(ci) < n_cls) && (cls_name[ci] == cls_cls)) begin
                            cls_ctor_q <= cls_ctor[ci];
                            cls_hit <= 1'b1;
                        end
                    end
                    cls_scan <= 1'b0;
                    cls_armed <= 1'b0;
                    cls_done <= 1'b1;
                end else if (!cls_seq) begin
                    // Beat 1: comb class find over the small FF arrays,
                    // then start the method walk (or finish on miss).
                    logic       f_hit;
                    logic [3:0] f_ci;
                    f_hit = 1'b0; f_ci = 4'd0;
                    for (int ci = 0; ci < MAX_CLS; ci++)
                        if ((5'(ci) < n_cls) && (cls_name[ci] == cls_cls)) begin
                            f_hit = 1'b1; f_ci = 4'(ci);
                        end
                    if (!f_hit) begin
                        cls_scan <= 1'b0;
                        cls_armed <= 1'b0;
                        cls_done <= 1'b1;
                    end else begin
                        cls_seq <= 1'b1;
                        cls_prime <= 1'b1;
                        cls_c <= f_ci;
                        cls_m <= 4'd0;
                        clsm_raddr <= {f_ci, 4'd0};
                    end
                end else if (cls_prime) begin
                    // Beat 2: first read in flight; advance the address.
                    cls_prime <= 1'b0;
                    cls_m <= 4'd1;
                    clsm_raddr <= {cls_c, 4'd1};
                end else begin
                    // One method per beat: compare the landed read for
                    // entry cls_m-1 while entry cls_m is in flight.
                    logic [3:0] mprev;
                    mprev = cls_m - 4'd1;
                    if (({1'b0, mprev} < cls_nmeth[cls_c]) &&
                        ((image_setters ? {1'b0,clsm_name_rd[13:0]} : clsm_name_rd[14:0]) == cls_key[14:0])) begin
                        if (clsm_name_rd[15])
                            cls_gip_q <= clsm_ip_rd;
                        else if (image_setters && clsm_name_rd[14])
                            cls_sip_q <= clsm_ip_rd;
                        else
                            cls_mip_q <= clsm_ip_rd;
                    end
                    if (({1'b0, mprev} + 5'd1 >= cls_nmeth[cls_c]) ||
                        (mprev == 4'(MAX_CMETH - 1))) begin
                        cls_seq <= 1'b0;
                        cls_scan <= 1'b0;
                        cls_armed <= 1'b0;
                        cls_done <= 1'b1;
                    end else begin
                        cls_m <= cls_m + 4'd1;
                        // DONKEY root cause: issuing the
                        // pre-increment index re-read the entry the
                        // prime beat already issued, lagging every
                        // later comparison by one entry - the LAST
                        // method's data landed one beat after the
                        // walk terminated and was NEVER compared. Any
                        // class with >=3 methods could not resolve
                        // its final method (Mario/DK/Barrel .update
                        // are all declared last: no player, no kong,
                        // no barrels). Issue one ahead.
                        clsm_raddr <= {cls_c, cls_m + 4'd1};
                    end
                end
            end
            if (stop_q) begin
                fs_request<=0;
                running <= 1'b0;
                looping <= 1'b0;
                sram_req <= 1'b0; sram_we <= 1'b0; blit_wait <= 1'b0; // Drop mid-blit SRAM req
                        hs_st(S_IDLE);
            end else if ((state == S_V64_EXEC) && !e64_leave_hold) begin
                // we already applied above. Skip unique case (no EXEC arm).
            end else if (vgc_mark_pend) begin
                // flatten: unique case must not peek alloc/valid from a handle.
                if (!vgc_mark_arm)
                    vgc_mark_arm <= 1'b1;
                else begin
                    begin
                        logic [3:0] mk;
                        logic [31:0] mi;
                        mk = vgc_mark_word[47:44];
                        mi = vgc_mark_word[31:0];
                        if (vgc_mark_word[63:48] == 16'h7ff9 &&
                            (mk == V64_KIND_OBJECT || mk == V64_KIND_ELEMENT) &&
                            mi < MAX_OBJ &&
                            vobj_alloc_rdata == 2'd1 &&
                            !vobj_mark_rdata) begin
                            begin vmko_we <= 1'b1; vmko_wa <= mi[9:0]; vmko_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd7 && mi < MAX_OBJ &&
                                     vfn_valid_rdata && !vfn_mark_rdata) begin
                            begin vmkf_we <= 1'b1; vmkf_wa <= mi[9:0]; vmkf_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd6 && mi < MAX_ARR &&
                                     varr_valid_rdata && !varr_mark_rdata) begin
                            begin vmka_we <= 1'b1; vmka_wa <= mi[11:0]; vmka_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end else if (vgc_mark_word[63:48] == 16'h7ff9 &&
                                     mk == 4'd9 && mi < ENV_DEPTH &&
                                     venv_valid_rdata && !venv_mark_rdata) begin
                            begin vmke_we <= 1'b1; vmke_wa <= mi[8:0]; vmke_wd <= 1'b1; end
                            vgc_queue_pa_we <= 1'b1;
                            vgc_queue_pa_waddr <= vgc_qw;
                            vgc_queue_pa_wdata <= {vgc_mark_word[47:44], vgc_mark_word[12:0]};
                            hs_vgc_qw(vgc_qw + 14'd1);
                        end
                    end
                    vgc_mark_pend <= 1'b0;
                    vgc_mark_arm <= 1'b0;
                end
            // UG901: unique case = parallel_case (every arm a mux). This FSM
            // is ~80 states × blocking temps; that was the 70 GB flatten after
            // unused-FF. Plain case sequences; SRAM still rdata<=mem[raddr].
            end else case (casestate)
                S_IDLE: if (start_q) begin
                    names_ok<=0;
                    image_code_limit <= image_code_bytes_i;
                    image_code_valid <= image_code_valid_i;
                    running <= 1'b1;
                    looping <= 1'b0;
                    sp <= '0;
                    hs_vsp('0);
                    hs_vcsp('0);
                    hs_code(15'd0);
                    hs_st(S_RD);
                    ret_state <= S_GOT_MAGIC;
                end
                S_RD: hs_st(ret_state);

                S_GOT_MAGIC: begin
                    if (!image_code_valid || image_code_limit < 32'd12 ||
                        image_code_limit > 32'(CODE_WORDS)*4+32'd32768) begin
                        machine_fault<=1;fault_code<=9;fault_site<=16'd15120;running<=0;hs_st(S_DONE);
                    end else if (code_rdata != 32'h3142534A && code_rdata != 32'h3242534A) begin
                        machine_fault<=1;fault_code<=9;fault_site<=16'd15126;
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else begin
                        image_setters <= (code_rdata == 32'h3242534A);
                        setter_pending <= 0;callref_pending <= 0;
                        hs_code(15'd1);
                        hs_st(S_RD);
                        ret_state <= S_GOT_HDR1;
                    end
                end
                S_GOT_HDR1: begin
                    n_ops    <= code_rdata[15:0];
                    n_consts <= code_rdata[31:16];
                    hs_code(15'd2);
                    hs_st(S_RD);
                    ret_state <= S_GOT_HDR2;
                end
                S_GOT_HDR2: begin
                    // An image without FLAG_VALUE64 (flags bit3 =
                    // code_rdata[19]) has no decoder any more. Fault loud.
                    if (code_rdata[15:0] > 16'd512 || n_consts > 16'd1024 ||
                        image_code_limit > (32'(CODE_WORDS)+(code_rdata[20]?32'd8192:0))*4 ||
                        (32'(code_rdata[17] ? 4 : 3) + 32'(n_consts)*2 + 32'(n_ops))*4 > image_code_limit) begin
                        machine_fault<=1;fault_code<=9;fault_site<=16'd15121;running<=0;hs_st(S_DONE);
                    end else if (!code_rdata[19] || (image_setters && (!code_rdata[16] || code_rdata[31:21] != 0)) || (code_rdata[20] && (n_ops<8192 || !toolbox_identity_match_q))) begin
                        machine_fault <= 1'b1;
                        fault_code <= 8'd9; fault_site <= 16'd6889; // 9 = tagged image refused
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else if ({16'd0, (code_rdata[17] ? 16'd4 : 16'd3)}
                               + {15'd0, (code_rdata[19] ? {n_consts, 1'b0}
                                                         : {1'b0, n_consts})}
                               + {16'd0, n_ops} > 32'(CODE_WORDS)+(code_rdata[20]?32'd8192:32'd0)) begin
                        // Fit: CODE_WORDS shrank to the measured
                        // envelope. An image whose header promises more words
                        // than code_mem holds is refused LOUD here - the
                        // write clamp above would otherwise truncate it and
                        // the VM would fetch zeros mid-program.
                        machine_fault <= 1'b1;
                        fault_code <= 8'd3; fault_site <= 16'd6902; // capacity
                        running <= 1'b0;
                        hs_st(S_DONE);
                    end else begin
                    // Flags bit1 (ASET) → u32 aset_byte_off occupies word 3,
                    aset_mode <= code_rdata[17];
                    hdr_w <= code_rdata[17] ? 16'd4 : 16'd3;
                    ops_base <= (code_rdata[17] ? 16'd4 : 16'd3)
                              + (code_rdata[19] ? (n_consts << 1) : n_consts);
                    jsb_flags <= code_rdata[31:16];
                    image_var_count<=code_rdata[9:0];
                    e64_p_clr <= 1'b1;
                    
                    heap_clr_busy <= 1'b1;
                    heap_clr_i <= 12'd0;
                    hs_vsp('0); hs_vcsp('0);
                    vsp_d <= '0;
                    vst_hold_win <= 1'b0;
                    vfree_armed <= 1'b0;
                    vfree_ok <= 1'b0;
                    vfree_arr_long <= 1'b0;
                    vprom_done <= 1'b0;
                    vprom_copy <= 1'b0;
                    hp_prom_wr <= 1'b0;
                    if (code_rdata[19]) begin
                        vobj_next <= 14'd0;
                        varr_next <= 14'd0;
                        vfn_next <= 14'd0;
                        venv_next <= 10'd0;
                        vgc_resume <= 2'd0;
                        hs_valloc_retried(1'b0);
                        hs_vthis(V64_UNDEFINED);
                        hs_venv(V64_UNDEFINED);
                        hs_vcall_set_this(1'b0);
                        hs_vcall_this(V64_UNDEFINED);
                        hs_vcall_ctor_val(V64_UNDEFINED);
                        intern_ctor_hold <= 1'b0;
                        intern_ctor_entry <= 16'd0;
                        intern_ctor_nparam <= 6'd0;
                        intern_ctor_flags <= 3'd0;
                        intern_ctor_env <= V64_UNDEFINED;
                        hs_vraf_n(4'd0);
                        vtimer_n <= 7'd0;
                        vframe_no <= 32'd0;
                        gc_ran_this_frame <= 1'b0; // C4
                        gc_frame_age <= 2'd0;
                        // Last intern coords survive RUN otherwise PACMAN
                        // SNAP shows the previous title's vdraw (INVADERS 14×5).
                        hs_vdraw_x('0); hs_vdraw_y('0);
                        hs_vdraw_w('0); hs_vdraw_h('0);
                        hs_vdraw_color('0);
                        vtimer_seq <= 32'd1;
                        vrng <= 32'h6d2b79f5;
                        vconsole_n <= 9'd0;
                        hs_vnat_dom(3'd0);
                        vnat_style <= V64_UNDEFINED;
                        vkev_event <= V64_UNDEFINED;
                        // Cached metrics belongs to this heap generation;
                        // a new program can reuse its old object index.
                        stridx_alloc_pending <= 1'b0;
                        vmetrics <= V64_UNDEFINED;
                        vmetrics_w <= 32'd0;
                        vmouse_active <= 1'b0;
                        hs_vlistener_n(5'd0);
                        vkey_li <= 5'd0;
                        v64_frame_armed <= 1'b0;
                        vcallback_key <= 1'b0;
                        vcallback_fe <= 1'b0;
                        vfe_arr <= V64_UNDEFINED;
                        vfe_fn <= V64_UNDEFINED;
                        vfe_i <= 8'd0;
                        vfe_ret <= 16'd0;
                        vfe_mode <= 2'd0;
                        vfe_map <= V64_UNDEFINED;
                        for (int i = 0; i < 16; i++) begin
                            vlistener_ev[i] <= V64_UNDEFINED;
                            vlistener_fn[i] <= V64_UNDEFINED;
                        end
                    end
                    n_obj <= 0; n_arr <= 0; n_cls <= 0; csp <= 0; 
                    
                    arr_keep_ok <= 1'b0; n_arr_keep <= 0;
                    arr_keep_wait <= ARR_KEEP_DELAY[3:0];
                    obj_keep_ok <= 1'b0; n_obj_keep <= 0;
                    obj_keep_wait <= ARR_KEEP_DELAY[3:0];
                    frame_fire <= 1'b0;
                    dbg_gc_n <= 0;
                        dbg_heap_ovf <= 0; dbg_to_ovf <= 0;
                    dbg_json_ovf <= 0; js_sp <= 0; json_wp <= 0;
                    dbg_stack_ovf <= 0; dbg_call_ovf <= 0;
                    machine_fault <= 1'b0; fault_code <= 8'd0; fault_site <= 16'd6999;
                    kd_fn <= 16'hFFFF; ku_fn <= 16'hFFFF; click_fn <= 16'hFFFF;
                    kev_dedup_ctr <= 4'd0; syn_dedup_ctr <= 4'd0;
                    kd_n <= 3'd0; ku_n <= 3'd0; kev_li <= 2'd0;
                    kd_slot[0] <= 16'hFFFF; kd_slot[1] <= 16'hFFFF;
                    kd_slot[2] <= 16'hFFFF; kd_slot[3] <= 16'hFFFF;
                    ku_slot[0] <= 16'hFFFF; ku_slot[1] <= 16'hFFFF;
                    ku_slot[2] <= 16'hFFFF; ku_slot[3] <= 16'hFFFF;
                    boot_clr <= 1'b1; boot_clr_n <= 2'd2;
                    id_find <= 16'hFFFF;
                    id_findindex <= 16'hFFFF; id_filter <= 16'hFFFF;
                    id_slice <= 16'hFFFF; // #40
                    id_sort <= 16'hFFFF; // #41
                    click_fired <= 1'b0;
                    pre_click_raf <= 1'b0;
                    prev_joy <= joy_level_q2; joy_down_edge <= 0; joy_up_edge <= 0;
                    fill_style_i <= 8'd0; stroke_style_i <= 8'd0; lfsr <= 32'hACE1; this_obj <= 16'hFFFF;
                    var_this <= 9'd0; this_ok <= 1'b0; id_this_name <= 16'hFFFF;
                    var_keys <= 9'd0; keys_ok <= 1'b0;
                    keys_a_oid <= 16'hFFFF; keys_d_oid <= 16'hFFFF; keys_sp_oid <= 16'hFFFF;
                    id_keys_name <= 16'hFFFF; id_pressed <= 16'hFFFF; id_kspace <= 16'hFFFF;
                    id_fillrect <= 16'hFFFF; id_length <= 16'hFFFF; id_push <= 16'hFFFF;
                    id_pop <= 16'hFFFF;
                    id_splice <= 16'hFFFF; id_foreach <= 16'hFFFF; id_getctx <= 16'hFFFF;
                    id_map <= 16'hFFFF; id_unshift <= 16'hFFFF;
                    id_click <= 16'hFFFF; id_ael <= 16'hFFFF; id_key <= 16'hFFFF;
                    id_rel <= 16'hFFFF; id_disp <= 16'hFFFF;
                    id_fillstyle <= 16'hFFFF; id_clearrect <= 16'hFFFF; id_drawimage <= 16'hFFFF;
                    id_reduce <= 16'hFFFF; // #39
                    id_keydown <= 16'hFFFF; id_keyup <= 16'hFFFF; id_width <= 16'hFFFF;
                    id_space <= 16'hFFFF; id_arrow_l <= 16'hFFFF; id_arrow_r <= 16'hFFFF;
                    id_w <= 16'hFFFF; id_s <= 16'hFFFF; id_p <= 16'hFFFF;
                    id_arrow_u <= 16'hFFFF; id_arrow_d <= 16'hFFFF;
                    id_a <= 16'hFFFF; id_d <= 16'hFFFF; kev_fn <= 16'hFFFF;
                    id_height <= 16'hFFFF; id_black <= 16'hFFFF; id_white <= 16'hFFFF;
                    id_style <= 16'hFFFF;
                    id_save <= 16'hFFFF; id_restore <= 16'hFFFF;
                    id_translate <= 16'hFFFF; id_rotate <= 16'hFFFF;
                    id_settransform <= 16'hFFFF;
                    id_assign <= 16'hFFFF; id_bind <= 16'hFFFF;
                    id_proto <= 16'hFFFF; id_filltext <= 16'hFFFF; id_arc <= 16'hFFFF;
                    id_font <= 16'hFFFF; id_textalign <= 16'hFFFF;
                    id_sys_window<='1;
                    id_textbaseline <= 16'hFFFF; id_top <= 16'hFFFF;
                    id_middle <= 16'hFFFF; id_bottom <= 16'hFFFF;
                    id_imgsmooth <= 16'hFFFF;
                    id_center <= 16'hFFFF; id_right <= 16'hFFFF;
                    id_measuretext <= 16'hFFFF;
                    id_enter <= 16'hFFFF; id_keycode <= 16'hFFFF;
                    id_kbevent <= 16'hFFFF; id_domevent <= 16'hFFFF;
                    id_customev <= 16'hFFFF; id_mouseev <= 16'hFFFF;
                    id_type <= 16'hFFFF;
                    id_charcode <= 16'hFFFF;
                    id_mousemove <= 16'hFFFF;
                    id_mousedown <= 16'hFFFF;
                    id_mouseup <= 16'hFFFF;
                    id_click <= 16'hFFFF;
                    id_clientX <= 16'hFFFF;
                    id_clientY <= 16'hFFFF;
                    id_offsetX <= 16'hFFFF;
                    id_offsetY <= 16'hFFFF;
                    id_mouse_x <= 16'hFFFF;
                    id_mouse_y <= 16'hFFFF;
                    id_buttons <= 16'hFFFF;
                    id_button <= 16'hFFFF;
                    id_movementX <= 16'hFFFF;
                    id_movementY <= 16'hFFFF;
                    id_now <= 16'hFFFF; id_gettime <= 16'hFFFF;
                    id_beginpath <= 16'hFFFF; id_fill <= 16'hFFFF; id_stroke <= 16'hFFFF;
                    id_moveto <= 16'hFFFF; id_lineto <= 16'hFFFF; id_closepath <= 16'hFFFF;
                    id_quadcurve <= 16'hFFFF;
                    id_getimgdata <= 16'hFFFF; id_putimgdata <= 16'hFFFF;
                    id_str_undef <= 16'hFFFF; id_str_number <= 16'hFFFF;
                    id_str_string <= 16'hFFFF; id_str_object <= 16'hFFFF;
                    id_str_function <= 16'hFFFF; id_str_boolean <= 16'hFFFF;
                    id_join <= 16'hFFFF; id_indexof <= 16'hFFFF; id_replace <= 16'hFFFF;
                    names_n <= 16'd0; dbg_join_miss <= 16'd0; dbg_pdo_n <= 5'd0;
                    jn_bucket_gen <= jn_bucket_gen + 8'd1; // O(1) bucket flush
                    jn_hit_v <= 4'd0; jn_cache_try <= 1'b0; jn_cache_i <= 3'd0;
                    v64_concat <= 1'b0;
                    v64_join <= 1'b0;
                    v64_sqrt <= 1'b0;
                    dbg_rect_n <= 7'd0; dbg_swap_n <= 16'd0;
            dbg_last_y <= 10'd0; dbg_last_c <= 8'd0;
            dbg_key_scan <= 16'd0; dbg_key_call <= 16'd0;
            dbg_key_alloc <= 16'd0; dbg_key_cmp <= 16'd0; dbg_txt_n <= 16'd0;
            dbg_txt_miss <= 16'd0; dbg_raf_call <= 16'd0;first_frame_o<=0; dbg_frame_end <= 16'd0;
            dbg_bad_state <= 8'd0;
            dbg_key_want <= 64'd0; dbg_key_lastev <= 64'd0;
                    dbg_line_px <= 32'd0; dbg_circ_px <= 32'd0; dbg_rect_px <= 32'd0;
                    pc_n <= 5'd0; pi <= 5'd0; path_active <= 1'b0; dbg_path_ovf <= 16'd0;
                    qseg <= 4'd0; arc_ang <= 1'b0;
                    id_strokestyle <= 16'hFFFF;
                    id_hex_09f <= 16'hFFFF; id_hex_f5f5 <= 16'hFFFF; id_hex_ffe6 <= 16'hFFFF;
                    id_hex_f00 <= 16'hFFFF; id_hex_aaa <= 16'hFFFF;
                    path_kind <= 2'd0; n_spr <= 5'd0; spr_wp <= 18'd0; spr_hdr <= 3'd0;
                    dbg_di_hit <= 16'd0; dbg_di_miss <= 16'd0;
                    sprd_mode <= 1'b0; blit_wait <= 1'b0; sram_req <= 1'b0; sram_we <= 1'b0;
                    time_ms <= 32'd0;
                    enter_n <= 3'd0; enter_delay <= 4'd0; // hack retired (KEYEVT)
                    kev_wp <= 3'd0; kev_rp <= 3'd0;
                    names_static <= 16'd0; nb_static <= 16'd0;
                    names_ok <= 1'b0; nb_i <= 16'd0; nb_len <= 16'd0; nb_wp <= 16'd0;
                    dbg_str_ovf <= 16'd0; name_rdaddr <= 16'd0;
                    str_pf_ok <= 1'b0; str_pf_id <= 16'd0;
                    namcpy_repl <= 1'b0; namcpy_v64 <= 1'b0; namcpy_armed <= 1'b0;
                    // FillText defaults match FM (8 px glyphs, left align)
                    ctx_align <= 2'd0; ctx_font_px <= 8'd8;
                    font_raddr <= 10'd0; txt_len <= 7'd0; txt_ph <= 4'd0;
                    dbg_cb_ip <= 16'd0; dbg_tmr_mis <= 16'd0;
                    dbg_tmr_sched <= 16'd0; dbg_tmr_fire <= 16'd0;
                    dbg_find_hit <= 16'd0; dbg_splice_n <= 16'd0;
                    dbg_div_n <= 16'd0;
                    ctx_tx <= 32'sd0; ctx_ty <= 32'sd0;
                    saved_tx <= 32'sd0; saved_ty <= 32'sd0;
                    ctx_sx <= FX_ONE; ctx_sy <= FX_ONE;   // Identity scale
                    ctx_smooth <= 1'b1; // ImageSmoothingEnabled default true
                    saved_sx <= FX_ONE; saved_sy <= FX_ONE;
                    trail_off <= 19'((code_rdata[17] ? 16'd4 : 16'd3)
                                  + (code_rdata[19] ? (n_consts << 1) : n_consts)
                                  + n_ops) << 2;
                    trail_ph <= 5'd0;
                    trail_guard <= 16'd0;
                    if (n_consts == 16'd0) begin
                        hs_ip('0);
                        if (code_rdata[16]) begin
                            hs_code(15'((code_rdata[17] ? 16'd4 : 16'd3) + n_ops));
                            ret_state <= S_TRAIL;
                        end else begin
                            hs_code(code_rdata[17] ? 15'd4 : 15'd3);
                            ret_state <= S_FETCH_WAIT;
                        end
                        hs_st(S_HEAP_CLR);
                    end else begin
                        c_i <= '0;
                        hs_code(code_rdata[17] ? 15'd4 : 15'd3);
                        ret_state <= S_LD_CONST;
                        hs_st(S_HEAP_CLR);
                    end
                    end
                end
                S_HEAP_CLR: begin
                    // One index per clock on parent 1-D banks (SRAM has no
                    // parallel clear). Walk MAX_ARR (widest). Exec p_clr
                    // still wipes its leftover copies the same way.
                    if (heap_clr_busy) begin
                        if (heap_clr_i < 12'd256)
                            char_ok[heap_clr_i[7:0]] <= 1'b0;
                        if (heap_clr_i < 12'd64)
                            vtimer_valid[heap_clr_i[5:0]] <= 1'b0;
                        if (heap_clr_i < 12'(MAX_VARS)) begin
                            begin vvv_we <= 1'b1; vvv_wa <= heap_clr_i[8:0]; vvv_wd <= 1'b0; end
                        end
                        if (heap_clr_i < 12'(MAX_OBJ)) begin
                            vobj_alloc_wr(heap_clr_i[9:0], 2'd0);
                            begin vog_we <= 1'b1; vog_wa <= heap_clr_i[9:0]; vog_wd <= 12'd1; end
                            begin vfg_we <= 1'b1; vfg_wa <= heap_clr_i[9:0]; vfg_wd <= 12'd1; end
                            begin vfv_we <= 1'b1; vfv_wa <= heap_clr_i[9:0]; vfv_wd <= 1'b0; end
                            begin vmkf_we <= 1'b1; vmkf_wa <= heap_clr_i[9:0]; vmkf_wd <= 1'b0; end
                            begin vol_we <= 1'b1; vol_wa <= {3'd0, heap_clr_i[9:0]}; vol_wd <= 6'd0; end
                            begin vmko_we <= 1'b1; vmko_wa <= heap_clr_i[9:0]; vmko_wd <= 1'b0; end
                            vom_we_bi <= 1'b1; vom_wa <= {3'd0, heap_clr_i[9:0]}; vom_bi <= 4'd0;
                        end
                        if (heap_clr_i < 12'(MAX_ARR)) begin
                            begin vav_we <= 1'b1; vav_wa <= heap_clr_i[10:0]; vav_wd <= 1'b0; end
                            begin vag_we <= 1'b1; vag_wa <= heap_clr_i[11:0]; vag_wd <= 12'd1; end
                            varr_len_wr(heap_clr_i[11:0], 8'd0);
                            begin vmka_we <= 1'b1; vmka_wa <= heap_clr_i[11:0]; vmka_wd <= 1'b0; end
                            begin vlo_we <= 1'b1; vlo_wa <= heap_clr_i[10:0]; vlo_wd <= 1'b0; end
                            begin vli_we <= 1'b1; vli_wa <= heap_clr_i[10:0]; vli_wd <= 8'd0; end
                        end
                        if (heap_clr_i < 12'(MAX_ARR_LONG))
                            begin vlu_we <= 1'b1; vlu_wa <= heap_clr_i[6:0]; vlu_wd <= 1'b0; end
                        if (heap_clr_i < 12'(ENV_DEPTH)) begin
                            begin vev_we <= 1'b1; vev_wa <= heap_clr_i[8:0]; vev_wd <= 1'b0; end
                            veg_we <= 1'b1; veg_wa <= heap_clr_i[8:0]; veg_wd <= 12'd1;
                            begin vel_we <= 1'b1; vel_wa <= heap_clr_i[8:0]; vel_wd <= 5'd0; end
                            begin vmke_we <= 1'b1; vmke_wa <= heap_clr_i[8:0]; vmke_wd <= 1'b0; end
                        end
                        if (heap_clr_i < 12'd1024) begin
                            begin flu_we <= 1'b1; flu_wa <= heap_clr_i[9:0]; flu_wd <= 8'hFF; end
                            begin nh_we <= 1'b1; nh_wa <= heap_clr_i[9:0]; nh_wd <= 1'b0; end
                            // No byte payload exists until this load publishes NAMB.
                            begin nof_we <= 1'b1; nof_wa <= heap_clr_i[9:0]; nof_wd <= 16'hffff; end
                            intern_var_ok[heap_clr_i[9:0]] <= 1'b0;
                        end
                        if (heap_clr_i + 12'd1 >= 12'(MAX_ARR))
                            heap_clr_busy <= 1'b0;
                        else
                            heap_clr_i <= heap_clr_i + 12'd1;
                    end else if (!e64_p_clr_busy) begin
                        if (ret_state == S_FETCH_WAIT) begin
                            names_ok<=1'b1;hs_st(S_FETCH_WAIT);
                        end
                        else begin
                            hs_st(S_RD);
                        end
                    end
                end
                S_LD_CONST: begin
                    begin
                        // Value64 constants are little-endian low/high u32 pairs.
                        vconst_lo <= code_rdata;
                        hs_code(15'(hdr_w + (c_i << 1) + 16'd1));
                        hs_st(S_RD);
                        ret_state <= S_V64_CONST_HI;
                    end
                end
                S_V64_CONST_HI: begin
                    vconsts_pa_we <= 1'b1;
                    vconsts_pa_waddr <= c_i[9:0];
                    vconsts_pa_wdata <= {code_rdata, vconst_lo};
                    e64_poke(6'd14, {6'd0, c_i[9:0]}, {code_rdata, vconst_lo});
                    if (c_i + 16'd1 >= n_consts) begin
                        hs_ip('0);
                        if (jsb_flags[0]) begin
                            hs_code(15'(ops_base + n_ops));
                            hs_st(S_RD);
                            ret_state <= S_TRAIL;
                        end else begin
                            names_ok<=1'b1;hs_code(15'(ops_base));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else begin
                        c_i <= c_i + 16'd1;
                        hs_code(15'(hdr_w + ((c_i + 16'd1) << 1)));
                        hs_st(S_RD);
                        ret_state <= S_LD_CONST;
                    end
                end

                S_TRAIL: begin
                    // JSB v2 trailer: names (hash intern ids) + skip vars + class table
                    trail_guard <= trail_guard + 20'd1;
                    if (trail_ph == 6'd31) begin
                        names_ok<=1'b1;
                        hs_code(15'(ops_base));hs_st(S_FETCH_WAIT);
                    end else if (trail_off == image_code_limit && names_n==0 &&
                        (trail_ph == 6'd22 || (trail_ph == 6'd35 && spr_hdr == 0))) begin
                        // Empty name table at the exact serialized boundary.
                        names_ok<=1'b1;
                        hs_code(15'(ops_base)); hs_st(S_FETCH_WAIT);
                    end else if (trail_off < image_code_limit && trail_ph==6'd29 && spr_hdr==0 && trail_tb!=8'h46) begin
                        // FSTY is optional in legacy valid images. Reuse this byte.
                        spr_hdr<=0;trail_ph<=6'd35;
                    end else if (trail_off < image_code_limit &&
                        ((trail_ph==6'd22 && image_code_limit-trail_off<4) ||
                         (trail_ph==6'd35 && spr_hdr==0 &&
                          (image_code_limit-trail_off<4 || trail_tb!=8'h4e)))) begin
                        // A zero-name table has no length bytes. At the optional
                        // post-FSTY boundary, inspect the following marker normally.
                        if(names_n==0 && trail_ph==6'd35 && image_code_limit-trail_off>=4)begin
                            trail_ph<=6'd22;
                        end else if(names_n==0)begin
                            machine_fault<=1;fault_code<=9;fault_site<=16'd15126;
                            running<=0;hs_st(S_DONE);
                        end else begin nb_i<=0;nb_wp<=0;trail_ph<=6'd32;end
                    end else if (trail_off < image_code_limit && trail_ph==6'd25 &&
                        !((trail_acc==16'h5053 && trail_n[7:0]==8'h52 && (trail_tb==8'h31 || trail_tb==8'h44)) ||
                          (trail_acc==16'h414e && trail_n[7:0]==8'h4d && trail_tb==8'h42) ||
                          (trail_acc==16'h5346 && trail_n[7:0]==8'h54 && trail_tb==8'h59))) begin
                        // Source maps are host/debug metadata, ignored after names
                        // just as on the marked-name path. Do not treat SMAP as a
                        // length when the valid legacy table has zero entries.
                        if(names_n==0 && jsb_flags[2] && trail_acc==16'h4d53 &&
                           trail_n[7:0]==8'h41 && trail_tb==8'h50)begin
                            names_ok<=1'b1;hs_code(15'(ops_base));hs_st(S_FETCH_WAIT);
                        end else if(names_n==0)begin
                            machine_fault<=1;fault_code<=9;fault_site<=16'd15126;
                            running<=0;hs_st(S_DONE);
                        end else begin
                            nb_i<=0;nb_wp<=0;trail_ph<=6'd32;trail_off<=trail_off-19'd3;
                            hs_code(15'((trail_off-19'd3)>>2));hs_st(S_RD);ret_state<=S_TRAIL;
                        end
                    end else if (trail_off < image_code_limit && trail_ph==6'd35 &&
                        ((spr_hdr==1 && trail_tb!=8'h41) || (spr_hdr==2 && trail_tb!=8'h4d) ||
                         (spr_hdr==3 && trail_tb!=8'h42))) begin
                        nb_i<=0;nb_wp<=0;trail_ph<=6'd32;trail_off<=trail_off-19'(spr_hdr);spr_hdr<=0;
                        hs_code(15'((trail_off-19'(spr_hdr))>>2));hs_st(S_RD);ret_state<=S_TRAIL;
                    end else if (trail_guard >= 20'd200000 || trail_off >= image_code_limit ||
                        (trail_ph == 6'd1 && ({trail_tb,trail_acc[7:0]} > 16'd1024 ||
                          32'({trail_tb,trail_acc[7:0]})*3+4 > image_code_limit-trail_off-1)) ||
                        (trail_ph == 6'd7 && ({trail_tb,trail_acc[7:0]} != {6'd0,image_var_count} ||
                          32'({trail_tb,trail_acc[7:0]})*2+2 > image_code_limit-trail_off-1)) ||
                        (trail_ph == 6'd9 && {trail_tb,trail_acc[7:0]}>=names_n) ||
                        (trail_ph == 6'd13 && {trail_tb,trail_acc[7:0]}>=names_n) ||
                        (trail_ph == 6'd15 && {trail_tb,trail_acc[7:0]}!=16'hffff && {trail_tb,trail_acc[7:0]}>=n_ops) ||
                        (trail_ph == 6'd19 && ((image_setters && trail_tb[7:6]==2'b11) || (image_setters ? {2'b0,trail_tb[5:0],trail_acc[7:0]} : {1'b0,trail_tb[6:0],trail_acc[7:0]})>=names_n)) ||
                        (trail_ph == 6'd21 && {trail_tb,trail_acc[7:0]}>=n_ops) ||
                        (trail_ph == 6'd11 && ({trail_tb,trail_acc[7:0]} > 16'd16 ||
                          32'({trail_tb,trail_acc[7:0]})*6 > image_code_limit-trail_off-1)) ||
                        (trail_ph == 6'd17 && ({trail_tb,trail_acc[7:0]} > 16'd16 ||
                          32'({trail_tb,trail_acc[7:0]})*4 > image_code_limit-trail_off-1)) ||
                        (trail_ph == 6'd27 && ({trail_tb,trail_acc[7:0]} > 16'd16 ||
                          (sprd_mode && 32'({trail_tb,trail_acc[7:0]})*8+6 > image_code_limit-trail_off-1))) ||
                        (trail_ph == 6'd29 && ((spr_hdr==1 && trail_tb!=8'h53) ||
                          (spr_hdr==2 && trail_tb!=8'h54) || (spr_hdr==3 && trail_tb!=8'h59))) ||
                        (trail_ph == 6'd28 && (spr_hdr==1 || spr_hdr==3) && {trail_tb,trail_acc[7:0]}==0) ||
                        (trail_ph == 6'd29 && spr_hdr == 5 &&
                          32'({trail_tb,fsty_n[7:0]})*4 > image_code_limit-trail_off-1) ||
                        (trail_ph == 6'd29 && spr_hdr == 5 && {trail_tb,fsty_n[7:0]}>16'd1024) ||
                        (trail_ph == 6'd30 && spr_hdr == 1 && {trail_tb,trail_acc[7:0]}>=names_n) ||
                        (trail_ph == 6'd30 && spr_hdr == 3 && trail_tb!=0) ||
                        (trail_ph == 6'd32 && image_code_limit-trail_off < 2) ||
                        (trail_ph == 6'd33 && (nb_i >= names_n ||
                          32'(nb_wp)+32'({trail_tb,trail_acc[7:0]}) > 32'(NAME_CAP) ||
                          32'({trail_tb,trail_acc[7:0]})+2*(32'(names_n)-32'(nb_i)-1) > image_code_limit-trail_off-1))) begin
                        // No writes from this byte occur before its declared span is valid.
                        machine_fault<=1;fault_code<=9;fault_site<=16'd15122;running<=0;hs_st(S_DONE);
                    end else begin
                        logic [7:0] tb;
                        case (trail_off[1:0])
                            2'd0: tb = code_rdata[7:0];
                            2'd1: tb = code_rdata[15:8];
                            2'd2: tb = code_rdata[23:16];
                            default: tb = code_rdata[31:24];
                        endcase
                        unique case (trail_ph)
                            5'd0: begin trail_acc[7:0] <= tb; trail_ph <= 5'd1; end
                            5'd1: begin
                                trail_n <= ({tb, trail_acc[7:0]} > 16'd1024) ? 16'd1024
                                         : {tb, trail_acc[7:0]};
                                // Keep name count for join hash->intern reverse scan
                                names_n <= ({tb, trail_acc[7:0]} > 16'd1024) ? 16'd1024
                                         : {tb, trail_acc[7:0]};
                                name_idx <= 0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd6 : 5'd2;
                            end
                            5'd2: begin trail_acc[7:0] <= tb; trail_ph <= 5'd3; end
                            5'd3: begin
                                // u16 name hash (JSB v2) — intern, then next hash or varmap
                                if ({tb, trail_acc[7:0]} == 16'd18951) id_fillrect <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd15078) id_length <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44826) id_push <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45649) id_pop <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd18044) id_splice <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54890) id_foreach <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd42332) id_map <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38281) id_unshift <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62905) id_find <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61081) id_findindex <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52088) id_filter <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd15762) id_slice <= name_idx; // #40
                                if ({tb, trail_acc[7:0]} == 16'd62878) id_sort <= name_idx; // #41
                                if ({tb, trail_acc[7:0]} == 16'd29049) id_getctx <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd50568) id_click <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58957) id_ael <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36682) id_rel <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd64064) id_disp <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd40543) id_key <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd30956) id_keycode <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31632) id_arrow_l <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd22451) id_arrow_r <= name_idx;
                                // "ArrowUp" — "ArrowDown" hash is 43, small
                                // enough to collide, so it is confirmed with
                                // the length byte in trail_ph 4 below.
                                if ({tb, trail_acc[7:0]} == 16'd14436) id_arrow_u <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32)    id_space <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd97)    id_a <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd100)   id_d <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd119)   id_w <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd115)   id_s <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd112)   id_p <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31617) id_keydown <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd37178) id_keyup <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62822) id_reduce <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11588) id_draw <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd14537) id_update <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd12782) id_fillstyle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38353) id_clearrect <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd22767) id_getimgdata <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd21846) id_putimgdata <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13943) id_drawimage <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49533) id_save <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd53902) id_restore <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61774) id_translate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd40234) id_settransform <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56667) id_rotate <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd33007) id_assign <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9277) id_bind <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd9506) id_proto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd13648) id_filltext <= name_idx;
                                // Text metrics/state names (jsb_format._name_hash)
                                if ({tb, trail_acc[7:0]} == 16'd3151)  id_font <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38360) id_textalign <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd39679) id_sys_window[0+:16] <= name_idx; // systemWindow
                                if ({tb, trail_acc[7:0]} == 16'd64221) id_sys_window[16+:16] <= name_idx; // windowScroll
                                if ({tb, trail_acc[7:0]} == 16'd24859) id_sys_window[32+:16] <= name_idx; // windowScrollX
                                if ({tb, trail_acc[7:0]} == 16'd52674) id_sys_window[48+:16] <= name_idx; // windowDirty
                                if ({tb, trail_acc[7:0]} == 16'd12277) id_sys_window[64+:16] <= name_idx; // systemViewport
                                if ({tb, trail_acc[7:0]} == 16'd14853) id_sys_window[80+:16] <= name_idx; // systemMenus
                                if ({tb, trail_acc[7:0]} == 16'd50846) id_sys_window[96+:16] <= name_idx; // systemAbout
                                if ({tb, trail_acc[7:0]} == 16'd5498) id_sys_window[128+:16] <= name_idx; // systemMenuCheck
                                if ({tb, trail_acc[7:0]} == 16'd849) id_sys_window[112+:16] <= name_idx; // systemMenuEnable
                                if ({tb, trail_acc[7:0]} == 16'd57040) id_sys_window[144+:16] <= name_idx; // windowBars
                                if ({tb, trail_acc[7:0]} == 16'd50537) id_sys_window[160+:16] <= name_idx; // systemTitle
                                if ({tb, trail_acc[7:0]} == 16'd4754) id_textbaseline <= name_idx; // #37
                                if ({tb, trail_acc[7:0]} == 16'd49493) id_top <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd55701) id_middle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd39467) id_bottom <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52309) id_center <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49692) id_right <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32683) id_measuretext <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54440) id_imgsmooth <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd31314) id_arc <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5816) id_enter <= name_idx;
                                // DOM event ctor names + "type" (jsb_format._name_hash)
                                if ({tb, trail_acc[7:0]} == 16'd38611) id_kbevent <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd33402) id_domevent <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd7561)  id_customev <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd16661) id_mouseev <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36666) id_type <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd6755) id_charcode <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd40438) id_mousemove <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd34503) id_mousedown <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd46592) id_mouseup <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd50568) id_click <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd34285) id_clientX <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd34286) id_clientY <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11813) id_offsetX <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11814) id_offsetY <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd120) id_mouse_x <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd121) id_mouse_y <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd49025) id_buttons <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd10034) id_button <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5513) id_movementX <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5514) id_movementY <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54382) id_beginpath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62851) id_fill <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd30264) id_stroke <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd38444) id_moveto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd5522)  id_quadcurve <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36239) id_lineto <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd64061) id_closepath <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd55897) id_strokestyle <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd42106) id_hex_09f <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54400) id_hex_f5f5 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61684) id_hex_ffe6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd62915) id_hex_f00 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd58654) id_hex_aaa <= name_idx;
                                // "jmr:spr:0".."9" hash 46080..46089 contiguous;
                                // "jmr:spr:10".."15" hash 52303..52308 (two digits)
                                if ({tb, trail_acc[7:0]} >= 16'd46080 && {tb, trail_acc[7:0]} <= 16'd46089)
                                    spr_nid[4'(({tb, trail_acc[7:0]}) - 16'd46080)] <= name_idx;
                                if ({tb, trail_acc[7:0]} >= 16'd52303 && {tb, trail_acc[7:0]} <= 16'd52308)
                                    spr_nid[4'(({tb, trail_acc[7:0]}) - 16'd52303 + 16'd10)] <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd43734) id_now <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd47939) id_gettime <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd27262) id_this_name <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11764) id_keys_name <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44066) id_pressed <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd61702) id_kspace <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd36863) id_black <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52265) id_white <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd47249) id_red <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd25716) id_yellow <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54051) id_cyan <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd32864) id_gold <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd48612) id_src <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd52037) id_onload <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd11718) id_width <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd37159) id_height <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd7601) id_style <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45091) id_hex_fff <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd54211) id_hex_3f6 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45411) id_hex_f5a <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd16643) id_hex_fc0 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd10674) id_hex_2ec <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd44003) id_hex_000 <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56618) id_join <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd17993) id_indexof <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd45748) id_replace <= name_idx;
                                // Typeof() result strings
                                if ({tb, trail_acc[7:0]} == 16'd24912) id_str_undef <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd56137) id_str_number <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd24593) id_str_string <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd41791) id_str_object <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd29656) id_str_function <= name_idx;
                                if ({tb, trail_acc[7:0]} == 16'd27688) id_str_boolean <= name_idx;
                                // Full hash table — join result maps back to intern id
                                name_hash_wr(name_idx[9:0], {tb, trail_acc[7:0]});
                                nhash <= {tb, trail_acc[7:0]};
                                // Poke 40 → exec name_hash_we. Indexed write
                                // above is not the SRAM we port (LOAD fill).
                                e64_poke(6'd40, {6'd0, name_idx[9:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                // u8 length byte follows each hash (concat fold)
                                trail_ph <= 5'd4;
                            end
                            5'd4: begin
                                begin nlt_we <= 1'b1; nlt_wa <= name_idx[9:0]; nlt_wd <= tb; end
                                e64_poke(6'd41, {6'd0, name_idx[9:0]}, {56'd0, tb});
                                // Space intern: hash 32 + len 1 (U+0020). Confirm
                                // here so e.key === " " matches KEYEVT payload.
                                if (nhash == 16'd32 && tb == 8'd1)
                                    id_space <= name_idx;
                                // "ArrowDown": hash 43 + len 9 (hash alone is
                                // also '+' and other short names)
                                if (nhash == 16'd43 && tb == 8'd9)
                                    id_arrow_d <= name_idx;
                                if (name_idx + 16'd1 >= trail_n) trail_ph <= 5'd6;
                                else begin
                                    name_idx <= name_idx + 16'd1;
                                    trail_ph <= 5'd2;
                                end
                            end
                            5'd6: begin trail_acc[7:0] <= tb; trail_ph <= 5'd7; end
                            5'd7: begin
                                trail_i <= {tb, trail_acc[7:0]};
                                trail_var_slot <= 9'd0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd10 : 5'd8;
                            end
                            5'd8: begin trail_acc[7:0] <= tb; trail_ph <= 5'd9; end
                            5'd9: begin
                                // var-map u16 = interned name idx; capture __this slot
                                if ({tb, trail_acc[7:0]} == id_this_name) begin
                                    var_this <= trail_var_slot;
                                    this_ok <= 1'b1;
                                end
                                if ({tb, trail_acc[7:0]} == id_keys_name) begin
                                    var_keys <= trail_var_slot;
                                    keys_ok <= 1'b1;
                                end
                                intern_var[{tb, trail_acc[7:0]}[9:0]] <= trail_var_slot;
                                intern_var_ok[{tb, trail_acc[7:0]}[9:0]] <= 1'b1;
                                if (trail_i <= 16'd1) trail_ph <= 5'd10;
                                else begin
                                    trail_i <= trail_i - 16'd1;
                                    trail_var_slot <= trail_var_slot + 9'd1;
                                    trail_ph <= 5'd8;
                                end
                            end
                            5'd10: begin trail_acc[7:0] <= tb; trail_ph <= 5'd11; end
                            5'd11: begin
                                n_cls <= {tb, trail_acc[7:0]}[4:0];
                                trail_cls_i <= 0;
                                trail_ph <= ({tb, trail_acc[7:0]} == 16'd0) ? 5'd22 : 5'd12;
                            end
                            5'd12: begin trail_acc[7:0] <= tb; trail_ph <= 5'd13; end
                            5'd13: begin
                                cls_name[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]};
                                e64_poke(6'd37, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                trail_ph <= 5'd14;
                            end
                            5'd14: begin trail_acc[7:0] <= tb; trail_ph <= 5'd15; end
                            5'd15: begin
                                cls_ctor[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]};
                                trail_ph <= 5'd16;
                            end
                            5'd16: begin trail_acc[7:0] <= tb; trail_ph <= 5'd17; end
                            5'd17: begin
                                cls_nmeth[trail_cls_i[3:0]] <= {tb, trail_acc[7:0]}[4:0];
                                e64_poke(6'd38, {12'd0, trail_cls_i[3:0]},
                                         {59'd0, {tb, trail_acc[7:0]}[4:0]});
                                trail_nmeth <= {tb, trail_acc[7:0]}[7:0];
                                trail_meth_i <= 0;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    if (trail_cls_i + 8'd1 >= {3'd0, n_cls}) trail_ph <= 5'd22;
                                    else begin
                                        trail_cls_i <= trail_cls_i + 8'd1;
                                        trail_ph <= 5'd12;
                                    end
                                end else trail_ph <= 5'd18;
                            end
                            5'd18: begin trail_acc[7:0] <= tb; trail_ph <= 5'd19; end
                            5'd19: begin
                                begin cmn_we <= 1'b1; cmn_wa <= {trail_cls_i[3:0], trail_meth_i[3:0]}; cmn_wd <= {tb, trail_acc[7:0]}; end
                                e64_poke(6'd39, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                e64_p_addr2 <= {12'd0, trail_meth_i[3:0]};
                                trail_ph <= 5'd20;
                            end
                            5'd20: begin trail_acc[7:0] <= tb; trail_ph <= 5'd21; end
                            5'd21: begin
                                begin cmi_we <= 1'b1; cmi_wa <= {trail_cls_i[3:0], trail_meth_i[3:0]}; cmi_wd <= {tb, trail_acc[7:0]}; end
                                e64_poke(6'd31, {12'd0, trail_cls_i[3:0]},
                                         {48'd0, tb, trail_acc[7:0]});
                                e64_p_addr2 <= {12'd0, trail_meth_i[3:0]};
                                if (trail_meth_i + 8'd1 >= trail_nmeth) begin
                                    if (trail_cls_i + 8'd1 >= {3'd0, n_cls}) trail_ph <= 5'd22;
                                    else begin
                                        trail_cls_i <= trail_cls_i + 8'd1;
                                        trail_ph <= 5'd12;
                                    end
                                end else begin
                                    trail_meth_i <= trail_meth_i + 8'd1;
                                    trail_ph <= 5'd18;
                                end
                            end
                            5'd22: begin
                                // peek SPR1 after class table (before UTF-8 names)
                                trail_acc[7:0] <= tb;
                                trail_ph <= 5'd23;
                            end
                            5'd23: begin trail_acc[15:8] <= tb; trail_ph <= 5'd24; end
                            5'd24: begin
                                trail_n[7:0] <= tb;
                                trail_ph <= 5'd25;
                            end
                            5'd25: begin
                                // bytes: acc[7:0], acc[15:8], trail_n[7:0], tb == "SPR1"
                                // (inline pixels) or "SPRD" (ASET descriptors)
                                if (trail_acc[7:0] == 8'h53 && trail_acc[15:8] == 8'h50 &&
                                    trail_n[7:0] == 8'h52 && (tb == 8'h31 || tb == 8'h44)) begin
                                    sprd_mode <= (tb == 8'h44);
                                    trail_ph <= 5'd26;
                                // "NAMB" — UTF-8 name bytes with no sprite
                                // block in front (plain .JS). Self-describing, so
                                // the section start never has to be inferred from
                                // where the class table happened to end.
                                end else if (trail_acc[7:0] == 8'h4E && trail_acc[15:8] == 8'h41 &&
                                             trail_n[7:0] == 8'h4D && tb == 8'h42) begin
                                    nb_i <= 16'd0;
                                    nb_wp <= 16'd0;
                                    trail_ph <= names_n==0 ? 6'd31 : 6'd32;
                                end else if (trail_acc==16'h5346 && trail_n[7:0]==8'h54 && tb==8'h59) begin
                                    spr_hdr<=3'd4;trail_ph<=6'd29;
                                end else begin
                                    machine_fault<=1;fault_code<=9;fault_site<=16'd15125;running<=0;hs_st(S_DONE);
                                end
                            end
                            5'd26: begin trail_acc[7:0] <= tb; trail_ph <= 5'd27; end
                            5'd27: begin
                                // 16 descriptors (compile_js.py fails loud past
                                // MAX_SPR, so this clamp is defensive only)
                                n_spr <= ({tb, trail_acc[7:0]} > 16'd16) ? 5'd16
                                       : {tb, trail_acc[7:0]}[4:0];
                                spr_i <= 5'd0;
                                spr_wp <= 18'd0;
                                spr_left <= 18'd0;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    // Empty SPRD (PACMAN) → FSTY follows in aset mode
                                    if (sprd_mode) begin
                                        spr_hdr <= 3'd0;
                                        trail_ph <= 5'd29;
                                    end else begin
                                        // Empty SPR1 — name bytes follow
                                        spr_hdr <= 3'd0;
                                        trail_ph <= 6'd35;
                                    end
                                end else if (sprd_mode) begin
                                    // SPRD: 8-byte descriptors (w,h u16 + u32 SRAM
                                    // offset) — no pixel copy, stay in S_TRAIL
                                    spr_hdr <= 3'd0;
                                    trail_ph <= 5'd28;
                                end else begin
                                    trail_ph <= 5'd31;
                                    spr_hdr <= 3'd0;
                                    hs_st(S_SPR);
                                end
                            end
                            5'd28: begin
                                // SPRD descriptor walk — spr_hdr counts the 8
                                // bytes; off byte 3 ignored (bank is 4 MB / 22 bits)
                                unique case (spr_hdr)
                                    3'd0: begin trail_acc[7:0] <= tb; spr_hdr <= 3'd1; end
                                    3'd1: begin spr_ww[spr_i[3:0]] <= {tb, trail_acc[7:0]}; spr_hdr <= 3'd2; end
                                    3'd2: begin trail_acc[7:0] <= tb; spr_hdr <= 3'd3; end
                                    3'd3: begin spr_hh[spr_i[3:0]] <= {tb, trail_acc[7:0]}; spr_hdr <= 3'd4; end
                                    3'd4: begin spr_off[spr_i[3:0]][7:0]   <= tb; spr_hdr <= 3'd5; end
                                    3'd5: begin spr_off[spr_i[3:0]][15:8]  <= tb; spr_hdr <= 3'd6; end
                                    3'd6: begin spr_off[spr_i[3:0]][22:16] <= tb[6:0]; spr_hdr <= 3'd7; end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (spr_i + 5'd1 >= n_spr)
                                            trail_ph <= 5'd29; // FSTY LUT follows SPRD
                                        else spr_i <= spr_i + 5'd1;
                                    end
                                endcase
                            end
                            5'd29: begin
                                // FSTY magic + u16 row count (spr_hdr = byte pos)
                                unique case (spr_hdr)
                                    3'd0: begin
                                        if (tb == 8'h46) spr_hdr <= 3'd1; // 'F'
                                        else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd1, 3'd2, 3'd3: begin
                                        // 'S','T','Y' — any mismatch bails to code
                                        if ((spr_hdr == 3'd1 && tb == 8'h53) ||
                                            (spr_hdr == 3'd2 && tb == 8'h54) ||
                                            (spr_hdr == 3'd3 && tb == 8'h59))
                                            spr_hdr <= spr_hdr + 3'd1;
                                        else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd4: begin fsty_n[7:0] <= tb; spr_hdr <= 3'd5; end
                                    default: begin
                                        fsty_n[15:8] <= tb;
                                        spr_hdr <= 3'd0;
                                        if ({tb, fsty_n[7:0]} == 16'd0) begin
                                            // Empty style tables still precede optional NAMB.
                                            // Use the same bounded magic peek as the final row.
                                            trail_ph <= 6'd35;
                                        end else trail_ph <= 5'd30;
                                    end
                                endcase
                            end
                            5'd30: begin
                                // FSTY rows (u16 name_idx, u16 palette idx)
                                unique case (spr_hdr)
                                    3'd0: begin fsty_name[7:0] <= tb; spr_hdr <= 3'd1; end
                                    3'd1: begin fsty_name[15:8] <= tb; spr_hdr <= 3'd2; end
                                    3'd2: begin
                                        trail_acc[7:0]<=tb;spr_hdr<=3'd3;
                                    end
                                    default: begin
                                        // The complete row has passed the parallel bounds guard.
                                        flu_we<=1;flu_wa<=fsty_name[9:0];flu_wd<=trail_acc[7:0];
                                        e64_poke(6'd15,{6'd0,fsty_name[9:0]},{56'd0,trail_acc[7:0]});
                                        spr_hdr <= 3'd0;
                                        if (fsty_n <= 16'd1) begin
                                            // Names follow FSTY — peek "NAMB"
                                            trail_acc <= 16'd0;
                                            trail_ph <= 6'd35;
                                        end else fsty_n <= fsty_n - 16'd1;
                                    end
                                endcase
                            end
                            // "NAMB" peek after the SPRD/FSTY blocks. Same
                            // 4-byte compare as the sprite magic; a miss just means
                            // no string bytes (names_ok stays 0) and never hangs RUN.
                            6'd35: begin
                                unique case (spr_hdr)
                                    3'd0: begin
                                        if (tb == 8'h4E) spr_hdr <= 3'd1;
                                        else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    3'd1, 3'd2: begin
                                        if ((spr_hdr == 3'd1 && tb == 8'h41) ||
                                            (spr_hdr == 3'd2 && tb == 8'h4D))
                                            spr_hdr <= spr_hdr + 3'd1;
                                        else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                    default: begin
                                        spr_hdr <= 3'd0;
                                        if (tb == 8'h42) begin
                                            nb_i <= 16'd0;
                                            nb_wp <= 16'd0;
                                            trail_ph <= names_n==0 ? 6'd31 : 6'd32;
                                        end else begin
                                            hs_code(15'(ops_base));
                                            hs_st(S_FETCH_WAIT);
                                            trail_ph <= 5'd31;
                                        end
                                    end
                                endcase
                            end
                            // Per-name u16 length, then its raw bytes. Order is
                            // the intern order, so nb_i IS the intern index and
                            // name_off[] lands a direct BRAM address for str[i].
                            6'd32: begin trail_acc[7:0] <= tb; trail_ph <= 6'd33; end
                            6'd33: begin
                                nb_len <= {tb, trail_acc[7:0]};
                                // NAMB length is the real interned byte count
                                // (hash u8 is only for concat fold).
                                e64_poke(6'd17, {6'd0, nb_i[9:0]},
                                         {32'd0, nb_wp, tb, trail_acc[7:0]});
                                // nb_len counts DOWN per byte, so it cannot tell a
                                // 1-char name from the last byte of a long one —
                                // that mixed whole-name ids into the char table.
                                nb_one <= ({tb, trail_acc[7:0]} == 16'd1);
                                begin nof_we <= 1'b1; nof_wa <= nb_i[9:0]; nof_wd <= nb_wp; end
                                // Bytes for this id are real (fillText and
                                // str[i] both refuse hash-only ids)
                                if (nb_wp + {tb, trail_acc[7:0]} <= 16'(NAME_CAP))
                                    begin nh_we <= 1'b1; nh_wa <= nb_i[9:0]; nh_wd <= 1'b1; end
                                // Name bytes remain provisional until the entire table is valid.
                                names_static <= nb_i + 16'd1;
                                nb_static <= nb_wp;
                                if ({tb, trail_acc[7:0]} == 16'd0) begin
                                    // empty name — nothing to copy
                                    if (nb_i + 16'd1 >= names_n) begin
                                        names_ok<=1'b1;
                                        hs_code(15'(ops_base));
                                        hs_st(S_FETCH_WAIT);
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else trail_ph <= 6'd34;
                            end
                            6'd34: begin
                                if (nb_wp < 16'(NAME_CAP)) begin
                                    name_we <= 1'b1;
                                    name_waddr <= nb_wp[14:0];
                                    name_wdata <= tb;
                                    e64_poke(6'd16, nb_wp, {56'd0, tb});
                                end
                                else dbg_str_ovf <= dbg_str_ovf + 16'd1;
                                nb_wp <= nb_wp + 16'd1;
                                // 1-char name → the byte→intern lookup str[i] uses
                                if (nb_one && nb_i < 16'd1024) begin
                                    char_id[tb] <= nb_i;
                                    char_ok[tb] <= 1'b1;
                                end
                                if (nb_len <= 16'd1) begin
                                    if (nb_i + 16'd1 >= names_n) begin
                                        names_ok<=1'b1;
                                        hs_code(15'(ops_base));
                                        hs_st(S_FETCH_WAIT);
                                        trail_ph <= 5'd31;
                                    end else begin
                                        nb_i <= nb_i + 16'd1;
                                        trail_ph <= 6'd32;
                                    end
                                end else nb_len <= nb_len - 16'd1;
                            end
                            default: begin
                                machine_fault<=1;fault_code<=9;fault_site<=16'd15123;
                                running<=0;hs_st(S_DONE);
                            end
                        endcase
                        if (trail_ph != 5'd31 && state != S_SPR) begin
                            if (trail_off[1:0] == 2'd3) begin
                                hs_code(15'(trail_off[16:2] + 15'd1));
                                trail_off <= trail_off + 16'd1;
                                hs_st(S_RD);
                                // SPR1 pixel copy starts this cycle when count>0.
                                // ret_state must be S_SPR — S_TRAIL + ph 31 would
                                // skip the pack (dihit with a blank FB).
                                if (trail_ph == 5'd27 && !sprd_mode &&
                                    {tb, trail_acc[7:0]} != 16'd0)
                                    ret_state <= S_SPR;
                                else
                                    ret_state <= S_TRAIL;
                            end else trail_off <= trail_off + 16'd1;
                        end
                        // FETCH only after SPR miss or empty pack
                        if (trail_ph == 5'd31 && state != S_SPR) begin
                            hs_code(15'(ops_base));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end

                S_FETCH_WAIT: begin
                    hs_hp_env(1'b0);
                    // Clear both FB banks once after header/trail, before first op
                    if (boot_clr) begin
                        color <= 8'd0;
                        clr_idx <= '0;
                        hs_st(S_CLEAR);
                    end else begin
                        hs_st(S_V64_EXEC);
                        pf_post_parent <= 1'b0; // excursion serviced
                    end
                end

                S_V64_KEYS: begin
                    // Gather only own slot keys into the existing stack, then
                    // let the ordinary array allocator/fill handle GC and bounds.
                    // No collection occurs during this bounded 32-slot walk.
                    if (state != S_V64_KEYS) begin
                        hs_st(S_V64_KEYS);
                        hs_hp_oid(e64_hp_oid_q);
                        hs_hp_rval(e64_hp_rval_q);
                        hs_hp_vbase(e64_hp_vbase_q);
                        hs_hp_slot(5'd0);
                        hs_hp_phase(3'd0);
                        hs_ip(e64_ip_q);
                        hs_code(15'(ops_base + e64_ip_q));
                    end else if (hp_phase == 3'd0) begin
                        hs_hp_phase(3'd1); // registered object metadata settles
                    end else if (hp_phase == 3'd1) begin
                        if (hp_vbase >= 12'(STACK_DEPTH)) begin
                            machine_fault <= 1'b1; fault_code <= 8'd1;
                            fault_site <= 16'd19042; running <= 1'b0; hs_st(S_DONE);
                        end else if (hp_rval[63:48] != V64_TAG_PREFIX ||
                            hp_rval[47:44] != V64_KIND_OBJECT ||
                            hp_rval[31:0] >= MAX_OBJ) begin
                            hs_hp_len(6'd0);
                            hs_vsp(hp_vbase);
                            hs_hp_phase(3'd4);
                        end else if (vobj_alloc_rdata != 2'd1 ||
                                     vobj_gen_rdata != hp_rval[43:32]) begin
                            machine_fault <= 1'b1; fault_code <= 8'd4;
                            fault_site <= 16'd19041; running <= 1'b0; hs_st(S_DONE);
                        end else if (vobj_len_rdata > 6'd32 ||
                            {1'b0,hp_vbase} + {7'd0,vobj_len_rdata} > 13'(STACK_DEPTH)) begin
                            machine_fault <= 1'b1; fault_code <= 8'd1;
                            fault_site <= 16'd19042; running <= 1'b0; hs_st(S_DONE);
                        end else begin
                            hs_hp_len(vobj_len_rdata);
                            hs_vsp(hp_vbase);
                            hs_hp_phase(vobj_len_rdata == 0 ? 3'd4 : 3'd2);
                        end
                    end else if (hp_phase == 3'd2) begin
                        vst_wr(hp_vbase + {7'd0,hp_slot},
                            {V64_TAG_PREFIX,V64_KIND_STRING,28'd0,vobj_rdata[79:64]});
                        hs_vsp(hp_vbase + {7'd0,hp_slot} + 12'd1);
                        if ({1'b0,hp_slot} + 6'd1 >= hp_len)
                            hs_hp_phase(3'd4);
                        else begin
                            hs_hp_slot(hp_slot + 5'd1);
                            hs_hp_phase(3'd3);
                        end
                    end else if (hp_phase == 3'd3) begin
                        hs_hp_phase(3'd2); // one registered slot-read beat
                    end else begin
                        hs_valloc_kind(2'd1);
                        hs_valloc_arr_n({2'd0,hp_len});
                        hs_valloc_i(14'd0);
                        hs_valloc_retried(1'b0);
                        hs_vnat_dom(3'd0);
                        hs_hp_make_arr(1'b0);
                        hs_st(S_V64_ALLOC);
                    end
                end
                S_V64_SLICE: begin
                    // #40 Array.slice(start,end): exec pushed the result
                    // handle already; this walk copies src[start..end-1] ->
                    // dst[0..] by reference. Exec passes src/start/end/dst
                    // in hp_aid/hp_aslot/hp_lim/hp_oid (hs64-muxed).
                    if (state != S_V64_SLICE) begin
                        hs_st(S_V64_SLICE);
                        sl_src <= hp_aid;
                        sl_dst <= hp_oid[11:0];
                        sl_i <= {1'b0, hp_aslot}; // src cursor (start)
                        sl_end <= hp_lim;         // src end (exclusive)
                        sl_di <= 8'd0;            // dst cursor
                        hs_hp_phase(3'd0);
                        hs_ip(e64_ip_q);
                        hs_code(15'(ops_base + e64_ip_q));
                    end else if (hp_phase == 3'd0) begin
                        if (sl_i >= sl_end) begin
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_hp_cmd(HP_AGETI);
                            hs_hp_aid(sl_src);
                            hs_hp_aslot(sl_i[6:0]);
                            hs_hp_alen(sl_end);
                            hs_hp_ret(S_V64_SLICE);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_WAIT);
                        end
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aid(sl_dst);
                        hs_hp_aslot(sl_di[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_ret(S_V64_SLICE);
                        hs_hp_phase(3'd0);
                        sl_i <= sl_i + 8'd1;
                        sl_di <= sl_di + 8'd1;
                        hs_st(S_HEAP_AWR);
                    end
                end
                S_V64_SORT: begin
                    // #41 Array.sort(cmp): bubble passes over vfe_arr.
                    // hp_phase: 0 = read a, 1 = read b, 2 = call comparator,
                    // 3 = act on cmp (exec fffc arm re-enters with phase 3
                    // and the result in vfe_map), 4 = swap writeback.
                    if (state != S_V64_SORT) begin
                        hs_st(S_V64_SORT);
                        // Same GC-root mirror as S_V64_FOREACH first-entry:
                        // a comparator-only fn/arr must survive a mid-sort
                        // GC.
                        if (e64_vfe_sp_q > vfe_sp && vfe_sp < 4'd8) begin
                            vfe_arr_s[vfe_sp[2:0]] <= vfe_arr;
                            vfe_fn_s[vfe_sp[2:0]]  <= vfe_fn;
                            vfe_map_s[vfe_sp[2:0]] <= vfe_map;
                        end
                        vfe_arr <= e64_vfe_arr_q;
                        vfe_fn <= e64_vfe_fn_q;
                        vfe_i <= e64_vfe_i_q;
                        vfe_ret <= e64_vfe_ret_q;
                        vfe_base <= e64_vfe_base_q;
                        vfe_mode <= e64_vfe_mode_q;
                        vfe_map <= e64_vfe_map_q;
                        vfe_sp <= e64_vfe_sp_q;
                        vfe_len <= e64_vfe_len_q;
                        hs_vcsp(e64_vcsp_q);
                        if (hp_phase == 3'd0) begin
                            // fresh dispatch (not a comparator return)
                            so_j <= 8'd0;
                            so_swapped <= 1'b0;
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                        end
                    end else if (hp_phase == 3'd0) begin
                        if (so_j + 8'd1 >= e64_vfe_len_q) begin
                            if (!so_swapped) begin
                                // done: sort returns the receiver.
                                vst_wr(e64_vfe_base_q, e64_vfe_arr_q);
                                hs_vsp(e64_vfe_base_q + 12'd1);
                                hs_ip(e64_vfe_ret_q);
                                hs_code(15'(ops_base + e64_vfe_ret_q));
                                if (e64_vcsp_q != 8'd0 &&
                                    vframe_rip_rdata == 16'hfffc &&
                                    vframe_bsp_rdata ==
                                        (e64_vfe_base_q + 12'd2))
                                    hs_vcsp(e64_vcsp_q - 8'd1);
                                else
                                    hs_vcsp(e64_vcsp_q);
                                if (e64_vfe_sp_q != 4'd0) begin
                                    hs_m_vfe_pop <= 1'b1;
                                    vfe_sp <= vfe_sp - 4'd1;
                                end else begin
                                    vfe_arr <= V64_UNDEFINED;
                                    vfe_fn <= V64_UNDEFINED;
                                    vfe_mode <= 2'd0;
                                    vfe_map <= V64_UNDEFINED;
                                end
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                so_j <= 8'd0;
                                so_swapped <= 1'b0;
                            end
                        end else begin
                            hs_hp_cmd(HP_AGETI);
                            hs_hp_aid(e64_vfe_arr_q[11:0]);
                            hs_hp_aslot(so_j[6:0]);
                            hs_hp_alen(e64_vfe_len_q);
                            hs_hp_ret(S_V64_SORT);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_WAIT);
                        end
                    end else if (hp_phase == 3'd1) begin
                        so_a <= hp_rval;
                        hs_hp_cmd(HP_AGETI);
                        hs_hp_aid(e64_vfe_arr_q[11:0]);
                        hs_hp_aslot(7'(so_j + 8'd1));
                        hs_hp_alen(e64_vfe_len_q);
                        hs_hp_ret(S_V64_SORT);
                        hs_hp_phase(3'd2);
                        hs_st(S_HEAP_WAIT);
                    end else if (hp_phase == 3'd2) begin
                        // push fn, a, b then call the comparator (same
                        // stack shape and ALLOC reserve as S_V64_FOREACH).
                        if (!vfe_rd_arm) begin
                            so_b <= hp_rval;
                            vst_wr(vsp, e64_vfe_fn_q);
                            hs_vsp(vsp + 12'd1);
                            vfe_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            vst_wr(vsp, so_a);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd1;
                        end else if (bind_k == 8'd1) begin
                            vst_wr(vsp, so_b);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd2;
                        end else begin
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd2);
                            vcallback_fe <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_vsp(vsp);
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            hs_hp_phase(3'd0);
                            hs_st(S_V64_ALLOC);
                        end
                    end else if (hp_phase == 3'd3) begin
                        // comparator returned; result (number) in exec
                        // vfe_map. cmp > 0 -> swap.
                        if (v64_less(64'd0, e64_vfe_map_q)) begin
                            hs_hp_cmd(HP_ASETI);
                            hs_hp_from_stack(1'b0);
                            hs_hp_aid(e64_vfe_arr_q[11:0]);
                            hs_hp_aslot(so_j[6:0]);
                            hs_hp_wval(so_b);
                            hs_hp_ret(S_V64_SORT);
                            hs_hp_phase(3'd4);
                            hs_st(S_HEAP_AWR);
                        end else begin
                            so_j <= so_j + 8'd1;
                            hs_hp_phase(3'd0);
                        end
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aid(e64_vfe_arr_q[11:0]);
                        hs_hp_aslot(7'(so_j + 8'd1));
                        hs_hp_wval(so_a);
                        hs_hp_ret(S_V64_SORT);
                        hs_hp_phase(3'd0);
                        so_swapped <= 1'b1;
                        so_j <= so_j + 8'd1;
                        hs_st(S_HEAP_AWR);
                    end
                end

                S_CLEAR: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_CLEAR) hs_code(15'(ops_base + ip));
                    if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: full-screen fill through the engine
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= 10'd0;
                        rast_dy <= 10'd0;
                        rast_w <= 10'(MW);
                        rast_h <= 10'(MH);
                        rast_color <= color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        if (boot_clr) begin
                            fb_swap <= 1'b1;
                            clr_idx <= '0;
                            if (boot_clr_n == 2'd1) begin
                                boot_clr <= 1'b0;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else
                                boot_clr_n <= boot_clr_n - 2'd1;
                        end else begin
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_FB_SYNC: begin
                    // Session-1: the two-bank copy-back is gone — the draw
                    // bank IS the persistent canvas. This state now only
                    // waits out the DDR3 present (fb_swap pulsed on entry;
                    // busy asserts the following beat, so arm one beat).
                    if (!fbs_armed) begin
                        fbs_armed <= 1'b1;
                        fence_arm <= 1'b1;
                        fence_seen <= 1'b0;
                        fence_wait <= '0;
                    end else begin
                        /* The VM
                           does not wait out the DDR3 copy. It runs behind
                           GC + S_WAIT_FRAME + the next frame's JS.
                           MEASURED (SYNCPROF, 10 titles, 288 presents): every
                           title is 100% coverable — the first draw of the next
                           frame lands 170k clocks AFTER the copy finishes, so
                           no draw ever overlaps a copy in practice (PACMAN is
                           the tightest at +1.4% margin and still never does).
                           A write fence was built and DROPPED: it never fired
                           in any workload, and by making draws wait it blew
                           the bounded tick budget of the unit gates. Writes
                           during a present were already shipping behavior
                           anyway (~1.1M at boot on the flashed tree).
                           Swap-while-busy is queued by fb_present.swap_pend. */
                        fbs_armed <= 1'b0;
                        clr_idx <= '0;
                        fb_dump_sel <= 1'b0;
                        frame_gc_schedule();
                    end
                end
                S_RECT: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_RECT) hs_code(15'(ops_base + ip));
                    if (rw == 10'd0 || rh == 10'd0) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: engine fill at 1 px/clk (dest bounds checked
                        // per pixel in the engine — the old per-pixel clip)
                        if (dbg_rect_n < 7'd64) begin
                            `ifndef SYNTHESIS
                            dbg_rect[dbg_rect_n[5:0]] <= {color, rx, ry, rw, rh};
                            `endif // sim-only probe store
                            dbg_rect_n <= dbg_rect_n + 7'd1;
                        end
                        if (color != 8'd0)
                            dbg_rect_px <= dbg_rect_px + 32'(20'(rw) * 20'(rh));
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= rx;
                        rast_dy <= ry;
                        rast_w <= rw;
                        rast_h <= rh;
                        rast_color <= color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        // draw into back; swap once at frame end (S_WAIT_FRAME)
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_CIRCLE: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_CIRCLE) hs_code(15'(ops_base + ip));
                    // rx,ry center; rw radius; x,y walk bbox; path_stroke = outline
                    // arc_ang = angular pie test (FM fill_circle a0/a1) via
                    // cross products against the sector edge vectors (no atan2)
                    if (!(fence_arm && fb_present_busy)) begin // present fence
                    begin
                        logic signed [11:0] dx, dy;
                        logic [21:0] d2, r2, r2in;
                        logic signed [31:0] c1, c2;
                        logic ang_ok;
                        dx = $signed({2'b0, x}) - $signed({2'b0, rx});
                        dy = $signed({2'b0, y}) - $signed({2'b0, ry});
                        d2 = 22'(dx * dx + dy * dy);
                        r2 = 22'(rw) * 22'(rw);
                        r2in = (rw <= 10'd1) ? 22'd0 : 22'(rw - 10'd1) * 22'(rw - 10'd1);
                        c1 = 32'(vs_x) * 32'(dy) - 32'(vs_y) * 32'(dx);
                        c2 = 32'(dx) * 32'(ve_y) - 32'(dy) * 32'(ve_x);
                        ang_ok = (!arc_ang) || (d2 == 22'd0)
                               || (arc_sweep_gt_pi ? (c1 >= 0 || c2 >= 0)
                                                   : (c1 >= 0 && c2 >= 0));
                        if (x < 10'(MW) && y < 10'(MH) && d2 <= r2 && ang_ok
                            && (!path_stroke || d2 >= r2in)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(y) * 19'(MW) + 19'(x);
                            fb_x <= x; fb_y <= y;
                            fb_wdata <= color;
                            dbg_circ_px <= dbg_circ_px + 32'd1; // flood hunt
                        end
                    end
                    if (x >= rx + rw || x == 10'(MW - 1)) begin
                        x <= clip_u($signed({22'd0, rx}) - $signed({22'd0, rw}), MW);
                        if (y >= ry + rw || y == 10'(MH - 1)) begin
                            // Chain back to the path walk
                            if (path_active) hs_st(S_PWALK);
                            else begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end
                        end else y <= y + 10'd1;
                    end else x <= x + 10'd1;
                    end // present fence
                end
                S_LINE: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_LINE) hs_code(15'(ops_base + ip));
                    // Signed Bresenham (FM machine._line twin) — endpoints
                    // may sit offscreen; per-pixel bounds check, guard bails
                    // pathological walks loudly via dbg_path_ovf
                    if (!(fence_arm && fb_present_busy)) begin // present fence
                        logic signed [17:0] e2;
                        logic signed [15:0] nx, ny;
                        logic signed [17:0] nerr;
                        if (bl_x >= 16'sd0 && bl_x < 16'(MW) &&
                            bl_y >= 16'sd0 && bl_y < 16'(MH)) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(bl_y) * 19'(MW) + 19'(bl_x);
                            fb_x <= bl_x[9:0]; fb_y <= bl_y[9:0];
                            fb_wdata <= color;
                            dbg_line_px <= dbg_line_px + 32'd1; // flood hunt
                        end
                        if ((bl_x == bl_x1 && bl_y == bl_y1) || bl_guard == 13'd4095) begin
                            if (bl_guard == 13'd4095) dbg_path_ovf <= dbg_path_ovf + 16'd1;
                            if (path_active) begin
                                if (qseg != 4'd0 && qseg <= 4'd8) hs_st(S_QSEG);
                                else begin
                                    qseg <= 4'd0;
                                    hs_st(S_PWALK);
                                end
                            end else begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            e2 = bl_err <<< 1;
                            nx = bl_x; ny = bl_y; nerr = bl_err;
                            if (e2 > -bl_dy) begin
                                nerr = nerr - 18'(bl_dy);
                                nx = bl_x + (bl_sx ? 16'sd1 : -16'sd1);
                            end
                            if (e2 < bl_dx) begin
                                nerr = nerr + 18'(bl_dx);
                                ny = bl_y + (bl_sy ? 16'sd1 : -16'sd1);
                            end
                            bl_x <= nx; bl_y <= ny; bl_err <= nerr;
                            bl_guard <= bl_guard + 13'd1;
                        end
                    end
                end
                S_PWALK: begin
                    // (mirror write for #49 is above the case — see e64_pc_we_q)
                    // Command walk (FM _raster_path) — transform each
                    // command's points with the CURRENT ctx transform
                    //
                    // First-entry latch. Same shape as
                    // S_TXT_LD (~9350): exec64 leaves state==S_V64_EXEC on the
                    // hand-off beat, so without this the very first beat
                    // compares the parent's stale pc_n (0 after RUN) and
                    // aborts before any mirrored write is visible. The raster
                    // states are NOT in hs64, so `ip` here is the last parent
                    // hs_ip (FIND/FOREACH) — pull exec's already-incremented
                    // ip/vsp across too, or the done-path hs_code(ops_base+ip)
                    // re-fetches a stale op and re-issues fill/stroke.
                    if (state != S_PWALK) begin
                        hs_st(S_PWALK);
                        path_active <= 1'b1;
                        path_stroke <= e64_path_stroke_q;
                        pc_n <= e64_pc_n_q;
                        pi <= 5'd0;
                        color <= e64_color_q;
                        ctx_sx <= e64_ctx_sx_q;
                        ctx_sy <= e64_ctx_sy_q;
                        ctx_tx <= e64_ctx_tx_q;
                        ctx_ty <= e64_ctx_ty_q;
                        // The drawImage debug counters were
                        // never absorbed from exec64 - VMSTAT reported
                        // dihit=0/dimiss=0 forever (a dead instrument that
                        // cost a night of misdirection on DONKEY).
                        dbg_di_hit  <= e64_dbg_di_hit_q;
                        dbg_di_miss <= e64_dbg_di_miss_q;
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else if (pi >= pc_n) begin
                        path_active <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (ctx_sx != FX_ONE || ctx_sy != FX_ONE) begin
                        xf_x <= pc_a1[pi[3:0]];
                        xf_y <= pc_a2[pi[3:0]];
                        xf_w <= pc_a3[pi[3:0]];
                        xf_h <= pc_a4[pi[3:0]];
                        xf_dst <= 2'd3;
                        hs_st(S_XF_MUL);
                    end else begin
                        p1x <= (pc_a1[pi[3:0]] >>> 16) + ctx_tx;
                        p1y <= (pc_a2[pi[3:0]] >>> 16) + ctx_ty;
                        // slot2: Q end point translates; arc radius must not
                        p2x <= (pc_a3[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_tx : 32'sd0);
                        p2y <= (pc_a4[pi[3:0]] >>> 16)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_ty : 32'sd0);
                        hs_st(S_PDO);
                    end
                end
                S_PDO: begin
                    // flatten: arc edges wait sin_q_rdata (4 beats). Stay in
                    // S_PDO; do not bump pi until the last beat (same as the
                    // old one-cycle leave).
                    if (sin_ph != 4'd0) begin
                        // odd = wait (mux samples sin_raddr); even = consume rdata
                        if (sin_ph[0])
                            sin_ph <= sin_ph + 4'd1;
                        else if (sin_ph == 4'd2) begin
                            vs_x <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_ts;
                            sin_ph <= 4'd3;
                        end else if (sin_ph == 4'd4) begin
                            vs_y <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_te + 16'h4000;
                            sin_ph <= 4'd5;
                        end else if (sin_ph == 4'd6) begin
                            ve_x <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_turn <= arc_te;
                            sin_ph <= 4'd7;
                        end else begin
                            ve_y <= sin_from_q(sin_turn, sin_q_rdata);
                            sin_ph <= 4'd0;
                            pi <= pi + 5'd1;
                            hs_st(S_CIRCLE);
                        end
                    end else begin
                    // Execute one transformed path command.
                    // Bring-up latch: SUSPICIOUS commands only (wall-flood hunt) —
                    // lineto far from cur, arc radius > 32, or way off-glass.
                    if (dbg_pdo_n < 5'd16 &&
                        ((pc_op[pi[3:0]] == 2'd1 &&
                          (p1x - cur_x > 32'sd64 || cur_x - p1x > 32'sd64 ||
                           p1y - cur_y > 32'sd64 || cur_y - p1y > 32'sd64)) ||
                         (pc_op[pi[3:0]] == 2'd3 && p2x > 32'sd32) ||
                         p1x < -32'sd64 || p1x > 32'sd704 ||
                         p1y < -32'sd64 || p1y > 32'sd544)) begin
                        `ifndef SYNTHESIS
                        dbg_pdo[dbg_pdo_n[3:0]] <= {14'd0, pc_op[pi[3:0]],
                            p1x[15:0], p1y[15:0], p2x[15:0], p2y[15:0]};
                        `endif // sim-only probe store
                        dbg_pdo_n <= dbg_pdo_n + 5'd1;
                    end
                    if (pc_op[pi[3:0]] == 2'd0) begin
                        pi <= pi + 5'd1;
                        cur_x <= p1x; cur_y <= p1y;
                        hs_st(S_PWALK);
                    end else if (pc_op[pi[3:0]] == 2'd1) begin
                        pi <= pi + 5'd1;
                        bl_x <= 16'(cur_x); bl_y <= 16'(cur_y);
                        bl_x1 <= 16'(p1x); bl_y1 <= 16'(p1y);
                        bl_dx <= (p1x > cur_x) ? 17'(p1x - cur_x) : 17'(cur_x - p1x);
                        bl_dy <= (p1y > cur_y) ? 17'(p1y - cur_y) : 17'(cur_y - p1y);
                        bl_sx <= (cur_x < p1x); bl_sy <= (cur_y < p1y);
                        bl_err <= 18'(((p1x > cur_x) ? (p1x - cur_x) : (cur_x - p1x))
                                    - ((p1y > cur_y) ? (p1y - cur_y) : (cur_y - p1y)));
                        bl_guard <= 13'd0;
                        qseg <= 4'd0;
                        cur_x <= p1x; cur_y <= p1y;
                        hs_st(S_LINE);
                    end else if (pc_op[pi[3:0]] == 2'd2) begin
                        // quadratic — FM subdivides into 8 line segments
                        pi <= pi + 5'd1;
                        qx0 <= cur_x; qy0 <= cur_y;
                        qcx <= p1x; qcy <= p1y;
                        qex <= p2x; qey <= p2y;
                        p2x <= cur_x; p2y <= cur_y; // prev bezier point
                        qseg <= 4'd1;
                        cur_x <= p2x; cur_y <= p2y;
                        hs_st(S_QSEG);
                    end else begin
                        // arc — FM fill_circle: full if |a1-a0| >= 2pi, skip if
                        // a0 == a1, else angular pie with the ccw sweep
                        logic signed [31:0] da_abs, sw, r_;
                        logic [15:0] t_s, t_e;
                        logic full_arc, skip_arc;
                        da_abs = pc_a5[pi[3:0]] - pc_a4[pi[3:0]];
                        if (da_abs < 0) da_abs = -da_abs;
                        full_arc = (da_abs >= 32'sd411770); // 2pi - eps
                        skip_arc = (!full_arc) && (pc_a4[pi[3:0]] == pc_a5[pi[3:0]]);
                        sw = pc_ccw[pi[3:0]]
                           ? fx_mod2pi(pc_a4[pi[3:0]] - pc_a5[pi[3:0]])
                           : fx_mod2pi(pc_a5[pi[3:0]] - pc_a4[pi[3:0]]);
                        if (sw == 32'sd0) sw = FX_2PI;
                        t_s = fx_turn(pc_ccw[pi[3:0]] ? pc_a5[pi[3:0]] : pc_a4[pi[3:0]]);
                        t_e = fx_turn(pc_ccw[pi[3:0]] ? pc_a4[pi[3:0]] : pc_a5[pi[3:0]]);
                        arc_sweep_gt_pi <= (sw > FX_PI);
                        arc_ang <= !full_arc;
                        r_ = p2x; if (r_ < 32'sd1) r_ = 32'sd1; // FM max(1, r*sx)
                        rx <= clip_u(p1x, MW); ry <= clip_u(p1y, MH);
                        rw <= clip_sz(r_, 10'd0, 512);
                        x <= clip_u(p1x - r_, MW);
                        y <= clip_u(p1y - r_, MH);
                        cur_x <= p1x; cur_y <= p1y; // FM: _path_x/_path_y = arc center
                        if (skip_arc) begin
                            pi <= pi + 5'd1;
                            hs_st(S_PWALK);
                        end else begin
                            // flatten: raddr this clock, 4× (wait + consume)
                            arc_ts <= t_s;
                            arc_te <= t_e;
                            sin_turn <= t_s + 16'h4000; // cos(start)
                            sin_ph <= 4'd1;
                        end
                    end
                    end
                end
                S_QSEG: begin
                    // Bezier weights for t = qseg/8 (Q16.16)
                    logic signed [31:0] t_, u_;
                    t_ = 32'(qseg) <<< 13;
                    u_ = FX_ONE - t_;
                    qk1 <= 32'((64'(u_) * 64'(u_)) >>> 16);
                    qk2 <= 32'((64'(u_) * 64'(t_)) >>> 16);
                    qk3 <= 32'((64'(t_) * 64'(t_)) >>> 16);
                    hs_st(S_QPX);
                end
                S_QPX: begin
                    p1x <= 32'((64'(qk1) * 64'(qx0) + 64'(qk2) * 64'(qcx) * 64'd2
                               + 64'(qk3) * 64'(qex)) >>> 16);
                    hs_st(S_QPY);
                end
                S_QPY: begin
                    logic signed [31:0] by_;
                    by_ = 32'((64'(qk1) * 64'(qy0) + 64'(qk2) * 64'(qcy) * 64'd2
                              + 64'(qk3) * 64'(qey)) >>> 16);
                    bl_x <= 16'(p2x); bl_y <= 16'(p2y);
                    bl_x1 <= 16'(p1x); bl_y1 <= 16'(by_);
                    bl_dx <= (p1x > p2x) ? 17'(p1x - p2x) : 17'(p2x - p1x);
                    bl_dy <= (by_ > p2y) ? 17'(by_ - p2y) : 17'(p2y - by_);
                    bl_sx <= (p2x < p1x); bl_sy <= (p2y < by_);
                    bl_err <= 18'(((p1x > p2x) ? (p1x - p2x) : (p2x - p1x))
                                - ((by_ > p2y) ? (by_ - p2y) : (p2y - by_)));
                    bl_guard <= 13'd0;
                    p2x <= p1x; p2y <= by_;
                    qseg <= qseg + 4'd1;
                    hs_st(S_LINE);
                end
                S_JOIN: begin
                    // BIND-style plant: parent jn_* is not muxed from exec.
                    if (state != S_JOIN) begin
                        hs_st(S_JOIN);
                        begin
                            jn_arr <= e64_jn_arr_q;
                            jn_i <= e64_jn_i_q;
                            jn_h <= e64_jn_h_q;
                            jn_res <= e64_jn_res_q;
                            v64_join <= e64_v64_join_q;
                            cc_bok <= e64_cc_bok_q;
                            txt_bn <= e64_txt_bn_q;
                            // #54 family: JOIN_FIND's result vst_wr plants the
                            // TOS window at depth (vsp-1-jn_res) using PARENT
                            // vsp, and the completion hs_code uses PARENT ip.
                            // Without these the SRAM got the joined intern but
                            // win[0] kept the pre-written UNDEFINED —
                            // code.join('') read back undefined with
                            // joinmiss=0 (PACMAN maze wall switch).
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                    end else if (!jn_rd_arm) begin
                        // Length + long/lidx share one wait (jn_arr raddr this clock).
                        jn_rd_arm <= 1'b1;
                    end else if (!jn_slot_arm) begin
                        // flatten: slot raddr from varr_long_rdata (stale 0 = wait).
                        jn_slot_arm <= 1'b1;
                    end else if (!jn_name_arm) begin
                        // flatten: name_hash raddr = varr_rdata intern id.
                        jn_name_arm <= 1'b1;
                    end else
                    // Fold single-digit elems into the encoder u16 hash
                    // (h = h*31 + '0'+d), matching jsb name interning
                    if (v64_join) begin
                        if (jn_i >= 16'({8'd0, varr_len_rdata})) begin
                            jn_i <= 16'd0;
                            jn_len <= varr_len_rdata;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            jn_name_arm <= 1'b0;
                            hs_st(S_JOIN_FIND);
                        end else begin
                            logic signed [31:0] ev;
                            logic [63:0] elem;
                            elem = varr_rdata;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            jn_name_arm <= 1'b0;
                            ev = $signed(v64_to_uint32(elem));
                            if (elem[63:48] == V64_TAG_PREFIX &&
                                elem[47:44] == 4'd4 &&
                                e32_name_len_tos == 8'd1 &&
                                name_hash_rdata[7:0] >= 8'h30 &&
                                name_hash_rdata[7:0] <= 8'h39)
                                ev = 32'(name_hash_rdata[7:0] - 8'h30);
                            if (ev < 32'sd0 || ev > 32'sd9) begin
                                dbg_join_miss <= dbg_join_miss + 16'd1;
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_join <= 1'b0;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                jn_h <= 16'(32'(jn_h) * 32'd31 + 32'd48 + 32'(ev));
                                if (jn_i < 16'(TXT_MAX)) begin
                                    begin txw_we <= 1'b1; txw_wa <= jn_i[5:0]; txw_wd <= 8'h30 + 8'(ev); end
                                    txt_bn <= 7'(jn_i) + 7'd1;
                                    cc_bok <= 1'b1;
                                end else cc_bok <= 1'b0;
                                jn_i <= jn_i + 16'd1;
                            end
                        end
                    end else begin
                        machine_fault <= 1'b1; fault_code <= 8'd9;
                        fault_site <= 16'd6889; running <= 1'b0; hs_st(S_DONE);
                    end
                end
                S_SQRT: begin
                    // Math.sqrt first-entry (PACMAN position2coord `offset`):
                    // exec enters directly with every seed (radicand, cursor,
                    // v64 flag) in ITS OWN FFs; the parent copies below were
                    // never written, so the loop ran on garbage, the
                    // completion took the 32-bit else (v64_sqrt parent FF
                    // stayed 0) and re-decoded the same CALL forever — the
                    // 64M frame cap burned at the splash. Same discipline as
                    // every other exec-entered state.
                    if (state != S_SQRT && e64_leave_hold)
                    begin
                        hs_st(S_SQRT);
                        sq_rad <= e64_sq_rad_q;
                        sq_rem <= e64_sq_rem_q;
                        sq_root <= e64_sq_root_q;
                        sq_i <= e64_sq_i_q;
                        v64_sqrt <= e64_v64_sqrt_q;
                        hs_vnat_base(e64_vnat_base_q);
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else begin
                    // Restoring bit-serial sqrt — 24 cycles, Q16.16 result
                    begin
                        logic [25:0] rem2, trial;
                        rem2 = {sq_rem[23:0], 2'((sq_rad >> ({1'b0, sq_i} * 6'd2)) & 48'd3)};
                        trial = {sq_root[23:0], 2'b01};
                        if (rem2 >= trial) begin
                            sq_rem <= rem2 - trial;
                            sq_root <= {sq_root[22:0], 1'b1};
                        end else begin
                            sq_rem <= rem2;
                            sq_root <= {sq_root[22:0], 1'b0};
                        end
                        if (sq_i == 5'd0) begin
                            if (v64_sqrt) begin
                                vst_wr(vnat_base, v64_from_fx($signed({8'd0,
                                    (rem2 >= trial) ? {sq_root[22:0], 1'b1}
                                                    : {sq_root[22:0], 1'b0}})));
                                hs_vsp(vnat_base + 12'd1);
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                v64_sqrt <= 1'b0;
                                hs_st(S_FETCH_WAIT);
                            end else begin
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                            end
                        end else sq_i <= sq_i - 5'd1;
                    end
                    end
                end
                S_JOIN_FIND: begin
                    // flatten: one intern slot/clock via name_hash_rdata (not a 16-CAM).
                    // Last-4 FF cache probes cached ids first (same Port A). Repeat
                    // concat must not walk names_n. CONCAT/JOIN enter with state
                    // already FIND, so plant on !jn_cache_try (overlay never runs).
                    // Miss allocates a NEW dynamic intern slot, so the same
                    // dynamic string ('s1i3') always resolves to the same id —
                    // object keys and EQ then work with no string heap.
                    if (state != S_JOIN_FIND) begin
                        hs_st(S_JOIN_FIND);
                        jn_cache_i <= 3'd0;
                        jn_cache_try <= 1'b0;
                        jn_bucket_tried <= 1'b0;
                    end else if (jn_cache_i < 3'd4 && !jn_cache_try) begin
                        // Next live cache slot, else linear from 0.
                        // Hash/len are FFs (not intern SRAM). Skip slots that
                        // cannot match; Port A still confirms the id.
                        if (jn_cache_i <= 3'd0 && jn_hit_v[0] &&
                            jn_hit_h0 == jn_h && jn_hit_l0 == jn_len) begin
                            jn_i <= jn_hit_i0;
                            jn_cache_i <= 3'd0;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd1 && jn_hit_v[1] &&
                            jn_hit_h1 == jn_h && jn_hit_l1 == jn_len) begin
                            jn_i <= jn_hit_i1;
                            jn_cache_i <= 3'd1;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd2 && jn_hit_v[2] &&
                            jn_hit_h2 == jn_h && jn_hit_l2 == jn_len) begin
                            jn_i <= jn_hit_i2;
                            jn_cache_i <= 3'd2;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (jn_cache_i <= 3'd3 && jn_hit_v[3] &&
                            jn_hit_h3 == jn_h && jn_hit_l3 == jn_len) begin
                            jn_i <= jn_hit_i3;
                            jn_cache_i <= 3'd3;
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else if (!jn_bucket_tried &&
                                     jn_bucket_rdata[23:16] == jn_bucket_gen &&
                                     jn_bucket_rdata[15:0] < names_n) begin
                            // 5th way: the bucket's candidate, confirmed by
                            // the same Port-A compare as the FF ways.
                            jn_bucket_tried <= 1'b1;
                            jn_btry <= jn_btry + 16'd1;
                            jn_i <= jn_bucket_rdata[15:0];
                            jn_cache_i <= 3'd3; // miss falls to linear next
                            jn_cache_try <= 1'b1;
                            jn_rd_arm <= 1'b0;
                        end else begin
                            jn_cache_i <= 3'd4;
                            jn_i <= 16'd0;
                            jn_rd_arm <= 1'b0;
                        end
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (jn_i < names_n &&
                        name_hash_rdata == jn_h &&
                        e32_name_len_tos == jn_len) begin
                        if (v64_concat || v64_join) begin
                            vst_wr(jn_res, v64_handle(
                                4'd4, 12'd0, {16'd0, jn_i}
                            ));
                            v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                        end
                        jn_cache_remember(jn_i);
                        jn_cache_try <= 1'b0;
                        jn_cache_i <= 3'd0;
                        jn_rd_arm <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (jn_cache_try) begin
                        // Cached id missed — next slot, or linear from 0.
                        if (jn_bucket_tried) jn_bmiss <= jn_bmiss + 16'd1;
                        jn_cache_try <= 1'b0;
                        jn_rd_arm <= 1'b0;
                        if (jn_cache_i >= 3'd3) begin
                            jn_cache_i <= 3'd4;
                            jn_i <= 16'd0;
                        end else
                            jn_cache_i <= jn_cache_i + 3'd1;
                    end else if (jn_i + 16'd1 >= names_n) begin
                        jn_rd_arm <= 1'b0;
                        jn_cache_try <= 1'b0;
                        jn_cache_i <= 3'd0;
                        if (names_n < 16'd1024 &&
                            ({1'b0,nb_wp}+{9'd0,jn_len}) <= 17'(NAME_CAP)) begin
                            name_hash_wr(names_n[9:0], jn_h);
                            begin nlt_we <= 1'b1; nlt_wa <= names_n[9:0]; nlt_wd <= jn_len; end
                            // Same we port as trail (poke 40 then 17 next
                            // byte-copy). Indexed writes are not the SRAM we.
                            e64_poke(6'd40, {6'd0, names_n[9:0]},
                                     {48'd0, jn_h});
                            jn_cache_remember(names_n);
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, v64_handle(
                                    4'd4, 12'd0, {16'd0, names_n}
                                ));
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end
                            // Intern handles have no reclaim generation. Keep
                            // names and bytes live until the next program load.
                            names_n <= names_n + 16'd1;
                            // And its characters, staged in txt_buf by
                            // S_CONCAT — that is what makes fillText("SCORE "+n)
                            // and str[i] on a built string work at all
                            if (cc_bok && jn_len <= 8'(TXT_MAX) &&
                                ({1'b0, nb_wp} + {9'd0, jn_len}) <= 17'(NAME_CAP)) begin
                                begin nof_we <= 1'b1; nof_wa <= names_n[9:0]; nof_wd <= nb_wp; end
                                name_has[names_n[9:0]] <= 1'b1;
                                txt_i <= 7'd0;
                                hs_st(S_STR_WR);
                            end else begin
                                // Not a full table: this one string could not
                                // stage its bytes. dbg_str_ovf feeds the global
                                // fault sweep (fault 5, running <= 0), so a
                                // single `"SCORE " + score` halted the machine
                                // mid-game. Real capacity overflow (NAME_CAP,
                                // ~7266) stays fatal; this degrades to a blank
                                // string and keeps the game alive.
                                if (!cc_bok) dbg_txt_miss <= dbg_txt_miss + 16'd1;
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end
                        end else begin
                            // Allocation exhaustion must not replace a live
                            // intern or pretend that an in-range string is absent.
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            machine_fault <= 1'b1; fault_code <= 8'd3;
                            fault_site <= 16'd9150;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else begin
                        // FIND stream: arm stays high — jn_i+1's row was
                        // presented during this compare beat (raddr mux).
                        jn_i <= jn_i + 16'd1;
                    end
                end
                S_CONCAT: begin
                    // JS string + — fold current operand into (cc_h, cc_len).
                    // Strings fold via h*31^len_b + h_b; ints fold decimal digits
                    // MSD-first (subtract powers of ten). Then find-or-alloc.
                    // Leave cycle: parent state is still EXEC. Pin like TXT
                    // or ADD has already decremented vsp / advanced ip and the
                    // next EXEC beat re-runs ADD with one operand (fault 1).
                    logic signed [31:0] v_;
                    logic [2:0] t_;
                    // BIND-style: plant exec stash first. Same-cycle FSM would
                    // fold parent cc_av=0 (never written) and sticky-fault 5.
                    if (state != S_CONCAT) begin
                        hs_st(S_CONCAT);
                        cx_active <= e64_cc_at_q==3 && e64_cc_bt_q==3;
                        cx_phase<=0;cx_scan<=0;cx_pos<=0;cx_hash<=0;
                        begin
                            cc_av <= e64_cc_av_q;
                            cc_bv <= e64_cc_bv_q;
                            cc_at <= e64_cc_at_q;
                            cc_bt <= e64_cc_bt_q;
                            cc_second <= e64_cc_second_q;
                            cc_st <= e64_cc_st_q;
                            cc_h <= e64_cc_h_q;
                            cc_len <= e64_cc_len_q;
                            cc_bok <= e64_cc_bok_q;
                            cc_d <= e64_cc_d_q;
                            txt_bn <= e64_txt_bn_q;
                            jn_res <= e64_jn_res_q;
                            v64_concat <= e64_v64_concat_q;
                        end
                    end else if(cx_active) begin
                        case(cx_phase)
                        0: cx_phase<=1;
                        1: begin
                            if(cc_av<0 || cc_av>=names_n || {1'b0,name_off_rdata}+{1'b0,name_blen_rdata}>17'(nb_wp)) begin
                                machine_fault<=1;fault_code<=4;fault_site<=15160;running<=0;hs_st(S_DONE);
                            end else begin cx_aoff<=name_off_rdata;cx_alen<=name_blen_rdata;cx_phase<=2;end
                        end
                        2: cx_phase<=3;
                        3: begin
                            if(cc_bv<0 || cc_bv>=names_n || {1'b0,name_off_rdata}+{1'b0,name_blen_rdata}>17'(nb_wp)) begin
                                machine_fault<=1;fault_code<=4;fault_site<=15161;running<=0;hs_st(S_DONE);
                            end else if({1'b0,cx_alen}+{1'b0,name_blen_rdata}>17'(NAME_CAP)) begin
                                machine_fault<=1;fault_code<=3;fault_site<=15162;running<=0;hs_st(S_DONE);
                            end else begin
                                cx_boff<=name_off_rdata;cx_blen<=name_blen_rdata;cx_len<=cx_alen+name_blen_rdata;
                                if(cx_alen==0)begin cx_result<=cc_bv[15:0];cx_phase<=20;end
                                else if(name_blen_rdata==0)begin cx_result<=cc_av[15:0];cx_phase<=20;end
                                else cx_phase<=4;
                            end
                        end
                        4: begin
                            if(cx_pos>=cx_len)begin cx_scan<=0;cx_phase<=7;end
                            else begin name_rdaddr<=cx_source;cx_phase<=5;end
                        end
                        5: cx_phase<=6;
                        6: begin cx_hash<=16'(cx_hash*16'd31+{8'd0,name_rdata});cx_pos<=cx_pos+1;cx_phase<=4;end
                        7: cx_phase<=8;
                        8: begin
                            if(cx_scan>=names_n)begin
                                if(names_n>=1024 || {1'b0,nb_wp}+{1'b0,cx_len}>17'(NAME_CAP))begin
                                    machine_fault<=1;fault_code<=3;fault_site<=15163;running<=0;hs_st(S_DONE);
                                end else begin cx_pos<=0;cx_phase<=15;end
                            end else if(name_hash_rdata==cx_hash && name_blen_rdata==cx_len) begin
                                cx_off<=name_off_rdata;cx_pos<=0;cx_phase<=9;
                            end else begin cx_scan<=cx_scan+1;cx_phase<=7;end
                        end
                        9: begin
                            if(cx_pos>=cx_len)begin cx_result<=cx_scan;cx_phase<=20;end
                            else begin name_rdaddr<=cx_off+cx_pos;cx_phase<=10;end
                        end
                        10: cx_phase<=11;
                        11: begin cx_byte<=name_rdata;name_rdaddr<=cx_source;cx_phase<=12;end
                        12: cx_phase<=13;
                        13: begin
                            if(name_rdata!=cx_byte)begin cx_scan<=cx_scan+1;cx_phase<=7;end
                            else begin cx_pos<=cx_pos+1;cx_phase<=9;end
                        end
                        15: begin
                            if(cx_pos>=cx_len)cx_phase<=18;
                            else begin name_rdaddr<=cx_source;cx_phase<=16;end
                        end
                        16: cx_phase<=17;
                        17: begin name_we<=1;name_waddr<=15'(nb_wp+cx_pos);name_wdata<=name_rdata;cx_pos<=cx_pos+1;cx_phase<=15;end
                        18: begin
                            name_hash_wr(names_n[9:0],cx_hash);
                            nlt_we<=1;nlt_wa<=names_n[9:0];nlt_wd<=cx_len[7:0];
                            nbl_we<=1;nbl_wa<=names_n[9:0];nbl_wd<=cx_len;
                            nof_we<=1;nof_wa<=names_n[9:0];nof_wd<=nb_wp;
                            e64_poke(6'd17,{6'd0,names_n[9:0]},{32'd0,nb_wp,cx_len});
                            cx_result<=names_n;names_n<=names_n+1;nb_wp<=nb_wp+cx_len;cx_phase<=20;
                        end
                        20: begin
                            vst_wr(jn_res,v64_handle(V64_KIND_STRING,12'd0,{16'd0,cx_result}));
                            cx_active<=0;v64_concat<=0;v64_join<=0;
                            hs_code(15'(ops_base+ip));hs_st(S_FETCH_WAIT);
                        end
                        default: begin machine_fault<=1;fault_code<=9;fault_site<=15164;running<=0;hs_st(S_DONE);end
                        endcase
                    end else begin
                    v_ = cc_second ? cc_bv : cc_av;
                    t_ = cc_second ? cc_bt : cc_at;
                    if (cc_st == 2'd0 && t_ == 3'd3 && !jn_rd_arm) begin
                        // flatten: name_hash / name_len raddr = intern id.
                        jn_rd_arm <= 1'b1;
                        jn_slot_arm <= 1'b0;
                    end else if (cc_st == 2'd0 && t_ == 3'd3 && !jn_slot_arm) begin
                        // flatten: pow31_rdata from e32_name_len_tos (256 ROM).
                        jn_slot_arm <= 1'b1;
                    end else if (cc_st == 2'd0) begin
                        // classify operand
                        if (t_ == 3'd3) begin
                            cc_h <= 16'(32'(cc_h) * 32'(pow31_rdata)
                                        + 32'(name_hash_rdata));
                            cc_len <= cc_len + e32_name_len_tos;
                            jn_rd_arm <= 1'b0;
                            jn_slot_arm <= 1'b0;
                            // Copy this operand's characters into txt_buf so
                            // the joined intern can be given real bytes. The
                            // hash fold above is unchanged, so ids do not move.
                            if (names_ok && e32_name_has_tos &&
                                ({1'b0, txt_bn} + {1'b0, e32_name_len_tos[6:0]})
                                    <= 8'(TXT_MAX)) begin
                                cc_cp <= e32_name_off_tos;
                                cc_cn <= e32_name_len_tos;
                                name_rdaddr <= e32_name_off_tos;
                                cc_st <= 2'd2;
                            end else begin
                                cc_bok <= 1'b0; // hash-only, as before
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'(pow31_rdata)
                                                + 32'(name_hash_rdata));
                                    jn_len <= cc_len + e32_name_len_tos;
                                    jn_i <= 16'd0;
                                    jn_rd_arm <= 1'b0;
                                    jn_cache_i <= 3'd0; jn_cache_try <= 1'b0;
                                    jn_bucket_tried <= 1'b0; // arm caches (concat handoff)
                                    hs_st(S_JOIN_FIND);
                                end else cc_second <= 1'b1;
                            end
                        end else if (t_ == 3'd0 || t_ == 3'd7) begin
                            // integer (fx floors) — fold '-' then digits
                            logic signed [31:0] iv;
                            iv = (t_ == 3'd7) ? (v_ >>> 16) : v_;
                            if (iv < 0) begin
                                cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd45); // '-'
                                cc_len <= cc_len + 8'd1;
                                if (txt_bn < 7'(TXT_MAX)) begin
                                    begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h2D; end
                                    txt_bn <= txt_bn + 7'd1;
                                end else cc_bok <= 1'b0;
                                iv = -iv;
                            end
                            cc_v <= iv;
                            cc_d <= 4'd0;
                            cc_pi <= (iv >= 32'sd1000000000) ? 4'd9
                                   : (iv >= 32'sd100000000) ? 4'd8
                                   : (iv >= 32'sd10000000) ? 4'd7
                                   : (iv >= 32'sd1000000) ? 4'd6
                                   : (iv >= 32'sd100000) ? 4'd5
                                   : (iv >= 32'sd10000) ? 4'd4
                                   : (iv >= 32'sd1000) ? 4'd3
                                   : (iv >= 32'sd100) ? 4'd2
                                   : (iv >= 32'sd10) ? 4'd1 : 4'd0;
                            cc_st <= 2'd1;
                        end else begin
                            // undefined/obj/arr/fn concat — honest miss
                            dbg_join_miss <= dbg_join_miss + 16'd1;
                            if (v64_concat || v64_join) begin
                                vst_wr(jn_res, V64_UNDEFINED);
                                v64_concat <= 1'b0;
                            v64_join <= 1'b0;
                            end
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else if (cc_st == 2'd1) begin
                        // digit loop: subtract P10[cc_pi] until below, fold digit
                        if (cc_v >= 32'(P10[cc_pi])) begin
                            cc_v <= cc_v - 32'(P10[cc_pi]);
                            cc_d <= cc_d + 4'd1;
                        end else begin
                            cc_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                            cc_len <= cc_len + 8'd1;
                            cc_d <= 4'd0;
                            // Same digit as a character
                            if (txt_bn < 7'(TXT_MAX)) begin
                                begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h30 + {4'd0, cc_d}; end
                                txt_bn <= txt_bn + 7'd1;
                            end else cc_bok <= 1'b0;
                            if (cc_pi == 4'd0) begin
                                // operand done
                                cc_st <= 2'd0;
                                if (cc_second) begin
                                    jn_h <= 16'(32'(cc_h) * 32'd31 + 32'd48 + 32'(cc_d));
                                    jn_len <= cc_len + 8'd1;
                                    jn_i <= 16'd0;
                                    jn_cache_i <= 3'd0; jn_cache_try <= 1'b0;
                                    jn_bucket_tried <= 1'b0;
                                    hs_st(S_JOIN_FIND);
                                end else cc_second <= 1'b1;
                            end else cc_pi <= cc_pi - 4'd1;
                        end
                    end else begin
                        // Copy one operand's bytes (name_mem is registered, so
                        // the first byte lands the cycle after cc_st became 2)
                        if (cc_cn == 8'd0) begin
                            cc_st <= 2'd0;
                            if (cc_second) begin
                                jn_h <= cc_h; jn_len <= cc_len; // folded already
                                jn_i <= 16'd0;
                                jn_cache_i <= 3'd0; jn_cache_try <= 1'b0;
                                jn_bucket_tried <= 1'b0;
                                hs_st(S_JOIN_FIND);
                            end else cc_second <= 1'b1;
                        end else if (name_rdaddr == cc_cp) begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 0
                        end else begin
                            begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= name_rdata; end
                            txt_bn <= txt_bn + 7'd1;
                            cc_cn <= cc_cn - 8'd1;
                            if (cc_cn > 8'd1) name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                    end
                end
                S_XF_MUL: begin
                    // Q16.16 × Q16.16 → Q32.32 products, registered so the
                    // four DSP mults never sit on the single-cycle dispatch path
                    xfp_x <= 64'(xf_x) * 64'(ctx_sx);
                    xfp_y <= 64'(xf_y) * 64'(ctx_sy);
                    xfp_w <= 64'(xf_w) * 64'(ctx_sx);
                    xfp_h <= 64'(xf_h) * 64'(ctx_sy);
                    hs_st(S_XF_APPLY);
                end
                S_XF_APPLY: begin
                    // FM machine.py _xf — ix=int(x*sx+tx), iw=max(1,int(w*sx))
                    logic signed [31:0] ix_, iy_, iw_, ih_;
                    ix_ = trunc32(xfp_x + (64'(ctx_tx) <<< 32));
                    iy_ = trunc32(xfp_y + (64'(ctx_ty) <<< 32));
                    if (xf_dst == 2'd3) begin
                        // path point pair: slot2 = Q end point (translates) or
                        // arc radius channel (no translate — S_PDO reads p2x raw)
                        p1x <= ix_; p1y <= iy_;
                        p2x <= trunc32(xfp_w)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_tx : 32'sd0);
                        p2y <= trunc32(xfp_h)
                             + ((pc_op[pi[3:0]] == 2'd2) ? ctx_ty : 32'sd0);
                        hs_st(S_PDO);
                    end else if (xf_dst == 2'd2) begin
                        // FillText pen — glyph size comes from ctx.font, and
                        // the pen may sit off-glass (centred text clips per pixel)
                        txt_px <= 16'(ix_);
                        txt_py <= 16'(iy_);
                        hs_st(S_TXT_LD);
                    end else begin
                        iw_ = trunc32(xfp_w); if (iw_ < 32'sd1) iw_ = 32'sd1;
                        ih_ = trunc32(xfp_h); if (ih_ < 32'sd1) ih_ = 32'sd1;
                        rx <= clip_u(ix_, MW); ry <= clip_u(iy_, MH);
                        rw <= clip_sz(iw_, clip_u(ix_, MW), MW);
                        rh <= clip_sz(ih_, clip_u(iy_, MH), MH);
                        x <= (xf_dst == 2'd1) ? 10'd0 : clip_u(ix_, MW);
                        y <= (xf_dst == 2'd1) ? 10'd0 : clip_u(iy_, MH);
                        hs_st((xf_dst == 2'd1) ? S_BLIT : S_RECT);
                    end
                end
                S_BLIT: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_BLIT) hs_code(15'(ops_base + ip));
                    // exec64's drawImage hit (~5838) plants
                    // rw/rh/rx/ry/blit_* in ITS OWN FFs and requests S_BLIT,
                    // but the parent copies this raster reads were never
                    // written from e64_*_q — parent rw stayed 0, so a hit was
                    // an immediate rw==0 exit with dbg_di_hit counted and zero
                    // pixels (DONKEY sheets blank, INVADERS player/explosions
                    // blank). Same overlay class as #49's S_PWALK: first-entry
                    // latch, plus hs_ip/hs_vsp because the drawImage hit does
                    // not set code_raddr_n and S_BLIT is not in hs64 — the
                    // done-path hs_code(ops_base + ip) would re-fetch a stale
                    // op otherwise.
                    if (state != S_BLIT) begin
                        // debug counters ride the blit handoff (the ctx-block
                        // sync never ran on this path - VMSTAT dihit was 0)
                        dbg_di_hit  <= e64_dbg_di_hit_q;
                        dbg_di_miss <= e64_dbg_di_miss_q;
                        hs_st(S_BLIT);
                        begin
                            rw <= e64_rw_q;
                            rh <= e64_rh_q;
                            rx <= e64_rx_q;
                            ry <= e64_ry_q;
                            x <= e64_x_q;
                            y <= e64_y_q;
                            blit_si <= e64_blit_si_q;
                            flip_x <= e64_flip_x_q;
                            flip_y <= e64_flip_y_q;
                            blit_sx <= e64_blit_sx_q;
                            blit_sy <= e64_blit_sy_q;
                            blit_sw <= e64_blit_sw_q;
                            blit_sh <= e64_blit_sh_q;
                            blit_wait <= 1'b0;
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            bdiv_num <= e64_blit_sw_q; bdiv_den <= {6'd0, e64_rw_q};
                        end
                        dda_sx <= 16'd0; dda_ax <= 16'd0;
                        dda_sy <= 16'd0; dda_ay <= 16'd0;
                        blit_div_ph <= 2'd1;
                        bdiv_i <= 5'd15; bdiv_quo <= 16'd0; bdiv_rem <= 17'd0;
                    end else if (rw == 10'd0 || rh == 10'd0) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (blit_div_ph != 2'd0) begin
                        // 16-beat restoring divide, twice (sw/rw then sh/rh).
                        logic [16:0] btry;
                        btry = {bdiv_rem[15:0], bdiv_num[bdiv_i[3:0]]};
                        if (btry >= {1'b0, bdiv_den}) begin
                            bdiv_rem <= btry - {1'b0, bdiv_den};
                            bdiv_quo[bdiv_i[3:0]] <= 1'b1;
                        end else begin
                            bdiv_rem <= btry;
                            bdiv_quo[bdiv_i[3:0]] <= 1'b0;
                        end
                        if (bdiv_i[3:0] == 4'd0) begin
                            if (blit_div_ph == 2'd1) begin
                                bdiv_qx <= (btry >= {1'b0, bdiv_den})
                                    ? (bdiv_quo | 16'd1) : (bdiv_quo & ~16'd1);
                                bdiv_rx <= 16'((btry >= {1'b0, bdiv_den})
                                    ? (btry - {1'b0, bdiv_den}) : btry);
                                blit_div_ph <= 2'd2;
                                bdiv_i <= 5'd15; bdiv_quo <= 16'd0; bdiv_rem <= 17'd0;
                                bdiv_num <= blit_sh; bdiv_den <= {6'd0, rh};
                            end else begin
                                bdiv_qy <= (btry >= {1'b0, bdiv_den})
                                    ? (bdiv_quo | 16'd1) : (bdiv_quo & ~16'd1);
                                bdiv_ry <= 16'((btry >= {1'b0, bdiv_den})
                                    ? (btry - {1'b0, bdiv_den}) : btry);
                                blit_div_ph <= 2'd0;
                            end
                        end else bdiv_i <= bdiv_i - 5'd1;
                    end else if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: the DDA walk lives in jmr_raster_engine now —
                        // one SRAM fetch per WORD (one-word cache) at core
                        // rate, ~1 clk/px instead of >=2 VM beats/px. The
                        // engine reproduces the exact floor DDA (gated by
                        // test_blit_scale_exact + the word-boundary gates).
                        rast_go <= 1'b1;
                        rast_mode <= 2'd1;
                        rast_dx <= rx;
                        rast_dy <= ry;
                        rast_w <= rw;
                        rast_h <= rh;
                        rast_sx <= blit_sx;
                        rast_sy <= blit_sy;
                        rast_qx <= bdiv_qx;
                        rast_rxr <= bdiv_rx;
                        rast_qy <= bdiv_qy;
                        rast_ryr <= bdiv_ry;
                        rast_sbase <= spr_off[blit_si[3:0]];
                        rast_stride <= spr_ww[blit_si[3:0]];
                        rast_aset <= aset_mode;
                        rast_flip_x <= flip_x;
                        rast_flip_y <= flip_y;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_SPR: begin
                    // copy sprite pack from code_mem trailer bytes (trail_tb).
                    // Parse the current byte EVERY cycle — including when
                    // trail_off[1:0]==3. Fetching the next word without
                    // consuming byte 3 skipped every 4th header/pixel (wrong
                    // stride / blank tiny sprites). S_TRAIL already parses
                    // then fetches; match that. NAMB follows the pixels.
                    //
                    // LUTRAM fit: sprite bytes go to the external
                    // SRAM (SPR_SRAM_BASE, one byte per word). While a write
                    // is in flight the WHOLE arm freezes (trail_off/trail_tb
                    // hold), so the byte-per-beat parse resumes exactly.
                    logic spr_end, spr_bad;
                    logic [31:0] spr_declared_bytes;
                    spr_declared_bytes=32'({trail_tb,trail_acc[7:0]})*32'(spr_ww[spr_i[3:0]]);
                    spr_bad=trail_off>=image_code_limit ||
                        (spr_left==0 && spr_hdr==3 &&
                         (spr_declared_bytes==0 || spr_declared_bytes>image_code_limit-trail_off-1 ||
                          spr_declared_bytes>32'(SPR_BYTES)-32'(spr_wp)));
                    spr_end = 1'b0;
                    if (sprb_pend) begin
                        if (sram_ack) begin
                            sram_req <= 1'b0;
                            sram_we  <= 1'b0;
                            sprb_pend <= 1'b0;
                        end
                    end else if (spr_bad) begin
                        machine_fault<=1;fault_code<=9;fault_site<=16'd15124;running<=0;hs_st(S_DONE);
                    end else
                    if (spr_left == 18'd0) begin
                        // header w/h via spr_hdr 0..3
                        if (spr_hdr == 3'd0) begin
                            trail_acc[7:0] <= trail_tb;
                            spr_hdr <= 3'd1;
                        end else if (spr_hdr == 3'd1) begin
                            // Full 16-bit width like the
                            // SPRD path - the [9:0] mask wrapped any sheet wider
                            // than 1023 px into a garbage row stride
                            // (tests/test_wide_sprite_sheets.py gate).
                            spr_ww[spr_i[3:0]] <= {trail_tb, trail_acc[7:0]};
                            spr_hdr <= 3'd2;
                        end else if (spr_hdr == 3'd2) begin
                            trail_acc[7:0] <= trail_tb;
                            spr_hdr <= 3'd3;
                        end else begin
                            spr_hh[spr_i[3:0]] <= {trail_tb, trail_acc[7:0]};
                            spr_off[spr_i[3:0]] <= 23'(spr_wp);
                            // 18-bit stream count bounds SPR-path sprites at
                            // 256K pixels; larger art rides ASET (unchanged).
                            spr_left <= spr_declared_bytes[17:0];
                            spr_hdr <= 3'd0;
                            if (spr_declared_bytes == 32'd0) begin
                                if (spr_i + 5'd1 >= n_spr) begin
                                    spr_hdr <= 3'd0;
                                    trail_ph <= 6'd35;
                                    spr_end = 1'b1;
                                end else spr_i <= spr_i + 5'd1;
                            end
                        end
                    end else begin
                        if ({1'b0, spr_wp} < 19'(SPR_BYTES)) begin
                            sram_req   <= 1'b1;
                            sram_we    <= 1'b1;
                            sram_addr  <= SPR_SRAM_BASE + 21'(spr_wp);
                            sram_wdata <= {8'd0, trail_tb};
                            sprb_pend  <= 1'b1;
                        end
                        spr_wp <= spr_wp + 18'd1;
                        spr_left <= spr_left - 18'd1;
                        if (spr_left == 18'd1) begin
                            if (spr_i + 5'd1 >= n_spr) begin
                                spr_hdr <= 3'd0;
                                trail_ph <= 6'd35;
                                spr_end = 1'b1;
                            end else begin
                                spr_i <= spr_i + 5'd1;
                                spr_hdr <= 3'd0;
                            end
                        end
                    end
                    if (!sprb_pend && !spr_bad) begin
                        // byte consumed this beat — advance the stream. During
                        // a write stall the whole arm (incl. this) freezes.
                        if (trail_off[1:0] == 2'd3) begin
                            hs_code(15'(trail_off[16:2] + 15'd1));
                            trail_off <= trail_off + 16'd1;
                            hs_st(S_RD);
                            ret_state <= spr_end ? S_TRAIL : S_SPR;
                        end else begin
                            trail_off <= trail_off + 16'd1;
                            if (spr_end) hs_st(S_TRAIL);
                        end
                    end
                end
                // Overlay from exec32: parent state is still EXEC while
                // casestate is WAIT_FRAME. FRAME pulses only on parent
                // state==WAIT_FRAME — latch or tagged rAF hangs in EXEC
                // (64M cap, raf=0, ip=n_ops).
                S_WAIT_FRAME: begin
                    if (state != S_WAIT_FRAME)
                        hs_st(S_WAIT_FRAME);
                    else begin
                    if (frame_tick) begin
                        v64_frame_armed <= 1'b1;
                        // KEYBITS edge capture (the tagged arm computed
                        // these; the Value64 arm never did, so a joystick
                        // press was invisible to v64 listeners).
                        // Board fix (stick jams + burst fire):
                        // ACCUMULATE edges. The old assign overwrote both
                        // vectors every tick, and dispatch cleared the WHOLE
                        // vector after sending ONE bit — any concurrent
                        // edge (fire during a turn, a release beside any
                        // press) was silently erased. A lost keyup left the
                        // game's held-flag stuck: the jam, and held-fire
                        // burst shots.
                        joy_down_edge <= joy_down_edge | (joy_level_q2 & ~prev_joy);
                        joy_up_edge   <= joy_up_edge   | (prev_joy & ~joy_level_q2);
                        prev_joy <= joy_level_q2;
                        if (kev_dedup_ctr != 4'd0)
                            kev_dedup_ctr <= kev_dedup_ctr - 4'd1;
                        if (syn_dedup_ctr != 4'd0)
                            syn_dedup_ctr <= syn_dedup_ctr - 4'd1;
                        // Per-frame callback marker. dbg_cb_ip was sticky
                        // (set at the first rAF call, cleared only at RUN),
                        // so the host FRAME rpc's "callback done" break
                        // fired the moment an EVENT dispatch returned to
                        // WAIT_FRAME — every event frame ended before its
                        // own rAF ran (events and rAF never shared a
                        // frame; player_x/title_gamestate snippets, MRDO
                        // startHeld). Browser order is events THEN rAF in
                        // the same frame.
                        dbg_cb_ip <= 16'd0;
                    end
                    if (frame_tick || v64_frame_armed) begin
                        // frame_fire is set by the 32-bit GC and cleared
                        // only in the 32-bit WAIT_FRAME arm — a Value64 title
                        // never runs that arm, so a stuck flag made the host
                        // FRAME exit predicate (!frame_continue) false
                        // forever: ~1000 presents inside one RPC and a
                        // blocked GUI. Consume it on this path too.
                        frame_fire <= 1'b0;
                        // KEYBITS edges → synthetic KEYEVT on the Value64
                        // path. The tagged arm dispatched joystick edges to
                        // S_KEYEV; the Value64 arm only drained kev_q, so a
                        // physical-joystick (KEYBITS) keydown/keyup never
                        // reached v64 listeners (found by the exec32 cut:
                        // DOWNUP snippet, keyup keyCode 40). Reuse the
                        // proven kev_q dispatch below — one edge bit per
                        // frame, guarded like the tagged arm so GUI
                        // KEYEVT+KEYBITS does not double-fire. kev_q's only
                        // other writer is the KEYEVT strobe beat, which runs
                        // in its own RPC window, never during FRAME.
                        if (kev_rp == kev_wp && vlistener_n != 5'd0 &&
                            (joy_down_edge != 6'd0 || joy_up_edge != 6'd0)) begin
                            /* One event per iteration, clearing ONLY the
                               dispatched bit — the drain loop re-enters
                               until both vectors empty, so nothing is
                               erased. A key with BOTH edges pending
                               resolves order by its CURRENT level: held
                               now means the release came first. */
                            logic [5:0] up_first;
                            logic [5:0] dn_ok;
                            logic [2:0] ki;
                            logic       is_up;
                            logic [7:0] kcode;
                            up_first = joy_up_edge &
                                       (~joy_down_edge | joy_level_q2);
                            dn_ok    = joy_down_edge &
                                       (~joy_up_edge | ~joy_level_q2);
                            is_up = (up_first != 6'd0);
                            ki = is_up ?
                                (up_first[0] ? 3'd0 : up_first[1] ? 3'd1 :
                                 up_first[2] ? 3'd2 : up_first[3] ? 3'd3 :
                                 up_first[4] ? 3'd4 : 3'd5) :
                                (dn_ok[0] ? 3'd0 : dn_ok[1] ? 3'd1 :
                                 dn_ok[2] ? 3'd2 : dn_ok[3] ? 3'd3 :
                                 dn_ok[4] ? 3'd4 : 3'd5);
                            kcode = (ki == 3'd0) ? 8'd38 :
                                    (ki == 3'd1) ? 8'd40 :
                                    (ki == 3'd2) ? 8'd37 :
                                    (ki == 3'd3) ? 8'd39 :
                                    (ki == 3'd4) ? 8'd32 : 8'd13;
                            v64_frame_armed <= 1'b1;
                            jn_slot_arm <= 1'b0; // #69: restart any pending rAF snapshot
                            if (kev_dedup_ctr != 4'd0 &&
                                kcode == kev_dedup_code) begin
                                // this press already arrived as a REAL key
                                // event (dual-interface pad): swallow the
                                // synthetic twin, both edges.
                                if (is_up) joy_up_edge[ki]   <= 1'b0;
                                else       joy_down_edge[ki] <= 1'b0;
                            end else begin
                                kev_q[kev_wp] <= {!is_up, kcode};
                                kev_chars[kev_wp] <= 0;
                                kev_src_joy[kev_wp] <= 1'b1;
                                kev_wp <= kev_wp + 5'd1;
                                if (is_up) joy_up_edge[ki]   <= 1'b0;
                                else begin
                                    joy_down_edge[ki] <= 1'b0;
                                    // arm the mirror: a real twin arriving
                                    // AFTER this synthetic press gets
                                    // swallowed by the branch above.
                                    syn_dedup_code <= kcode;
                                    syn_dedup_ctr <= 4'd8;
                                end
                            end
                        end else
                        if (kev_rp != kev_wp) begin
                            v64_frame_armed <= 1'b1;
                            // A real GUI KEYEVT supersedes the KEYBITS
                            // tether (arrows arrive BOTH ways — the DONKEY
                            // Mario->Luigi duplicate). But
                            // our OWN synthetic joystick entries must NOT
                            // wipe the accumulated edges — that erased the
                            // second edge of every multi-edge frame (fire
                            // during a turn lost; a lost keyup = the
                            // stick jam and stuck-fire burst).
                            if (!kev_src_joy[kev_rp]) begin
                                joy_down_edge <= 6'd0;
                                joy_up_edge <= 6'd0;
                            end
                            // #69: an event dispatch may interleave with a
                            // snapshot the previous FRAME rpc left half-done
                            // (jn_slot_arm=1, copy pending). The listener
                            // scan (S_V64_FRAME_KEY) reuses bind_k, so the
                            // resumed copy loop skipped and vraf_snap kept
                            // STALE fns — the walk then called the keyup
                            // listener as "the rAF callback" and the real
                            // tick entry was lost (queue already cleared):
                            // the game loop died after two event frames in a
                            // row. Restart the snapshot from phase 1 after
                            // the events drain.
                            jn_slot_arm <= 1'b0;
                            bind_rd_arm <= 1'b0;
                            vfe_rd_arm <= 1'b0;
                            dbg_key_alloc <= dbg_key_alloc + 16'd1;
                            hs_vnat_dom(3'd5);
                            hs_valloc_kind(2'd0);
                            hs_valloc_i(vobj_next);
                            hs_valloc_retried(1'b0);
                            hs_st(S_V64_ALLOC);
                        end else if (mouse_evt_pop) begin
                            // Let the producer retire the previous event, including /1 VM clocks.
                        end else if (mouse_evt_valid) begin
                            v64_frame_armed <= 1'b1;
                            if (mouse_input_type == 16'hffff) mouse_evt_pop <= 1'b1;
                            else begin
                                vmouse_active <= 1'b1;
                                vmouse_packet <= mouse_evt_data;
                                vmouse_type_id <= mouse_input_type;
                                jn_slot_arm <= 1'b0;
                                bind_rd_arm <= 1'b0;
                                vfe_rd_arm <= 1'b0;
                                hs_vnat_dom(3'd5);
                                hs_valloc_kind(2'd0);
                                hs_valloc_i(vobj_next);
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end
                        end else begin
                        // Stay armed until FRAME_RAF: a 1-cycle frame_tick
                        // (sim_frame_pulse / vsync) used to clear armed the
                        // same beat as jn_slot_arm, so the snapshot never
                        // finished and rAF never ran after the first present.
                        if (!jn_slot_arm) begin
                        vframe_no <= vframe_no + 32'd1;
                        vraf_snap_n <= vraf_n;
                        vraf_i <= 4'd0;
                        jn_slot_arm <= 1'b1;
                        bind_k <= 8'd0;
                        vfe_rd_arm <= 1'b0;
                        end else if (bind_k < {4'd0, vraf_n}) begin
                            if (!vfe_rd_arm)
                                vfe_rd_arm <= 1'b1;
                            else begin
                                vraf_snap[bind_k[2:0]] <= vraf_rdata;
                                bind_k <= bind_k + 8'd1;
                                vfe_rd_arm <= 1'b0;
                            end
                        end else begin
                        v64_frame_armed <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        bind_k <= 8'd0;
                        vfe_rd_arm <= 1'b0;
                        hs_vraf_n(4'd0);
                        hs_st(S_V64_FRAME_RAF);
                        end
                        end
                    end
                end
                end
                S_JSON_PARSE: begin
                    // V1 JSON-engine removal: the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5; fault_site <= 16'd9789;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_REPL: begin
                    if (json_rp >= json_src + json_srclen) begin
                        if (!vfree_armed) begin
                            vfree_armed <= 1'b1;
                            hs_valloc_i(14'd0);
                            hs_hp_ret(S_REPL);
                            hs_st(S_FREE_OBJ);
                        end else begin
                            vfree_armed <= 1'b0;
                            if (vfree_ok) begin
                                vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd7;
                                begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd7, 2'd0, 6'd2});
                                hs_hp_cmd(HP_OSETI);
                                hs_hp_oid(valloc_i[12:0]);
                                hs_hp_slot(5'd0);
                                hs_hp_qn(3'd2);
                                hs_hp_qi(3'd0);
                                hp_qk_ff[0] <= 16'd0;
                                hs_m_hp_qk <= 1'b1;
                                hp_qv_ff[0] <= v64_int32_number({18'd0, json_wp});
                                hs_m_hp_qv <= 1'b1;
                                hp_qt_ff[0] <= 3'd0;
                                hs_m_hp_qt <= 1'b1;
                                hp_qk_ff[1] <= 16'd1;
                                hs_m_hp_qk <= 1'b1;
                                hp_qv_ff[1] <= v64_int32_number(
                                    {18'd0, json_dst - json_wp});
                                hs_m_hp_qv <= 1'b1;
                                hp_qt_ff[1] <= 3'd0;
                                hs_m_hp_qt <= 1'b1;
                                vst_wr(vnat_base, v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                ));
                                hs_vsp(vnat_base + 12'd1);
                                vobj_next <= valloc_i + 14'd1;
                                hs_code(15'(ops_base + ip));
                                hs_hp_ret(S_FETCH_WAIT);
                                hs_st(S_HEAP_WR);
                            end else begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd3; fault_site <= 16'd9840;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end
                        end
                    end else if (!vjs_rd_arm) begin
                        vjs_rd_arm <= 1'b1;
                    end else if (repl_nlen > 8'd1 && !jn_name_arm) begin
                        json_ch0 <= json_mem_rdata;
                        jn_name_arm <= 1'b1;
                    end else begin
                        logic match;
                        logic [7:0] ch0;
                        ch0 = (repl_nlen > 8'd1) ? json_ch0 : json_mem_rdata;
                        match = (ch0 == repl_pat0) &&
                            (repl_nlen <= 8'd1 ||
                             (json_rp + 14'd1 < json_src + json_srclen &&
                              json_mem_rdata == repl_pat1));
                        vjs_rd_arm <= 1'b0;
                        jn_name_arm <= 1'b0;
                        if (match && (repl_g || !repl_did) && json_dst < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_dst[12:0];
                            json_wdata <= repl_rch;
                            json_dst <= json_dst + 14'd1;
                            json_rp <= json_rp + ((repl_nlen <= 8'd1) ? 14'd1 : 14'(repl_nlen));
                            repl_did <= 1'b1;
                        end else if (json_dst < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_dst[12:0];
                            json_wdata <= ch0;
                            json_dst <= json_dst + 14'd1;
                            json_rp <= json_rp + 14'd1;
                        end else begin
                            dbg_json_ovf <= dbg_json_ovf + 16'd1;
                            json_rp <= json_src + json_srclen;
                        end
                    end
                end
                // Str[i] result. name_rdata now holds the character. A 1-char
                // interned name has hash == its byte, so char_id turns the byte
                // straight into that intern id and OP_EQ compares it to a "x"
                // literal with no string walk. A character the program never wrote
                // as a literal cannot equal any literal, so undefined is correct.
                S_STR_WR: begin
                    if (state != S_STR_WR)
                        hs_st(S_STR_WR);
                    // Append the staged characters of a joined string to
                    // name_mem. names_n was bumped in S_JOIN_FIND, so the id
                    // being filled in is names_n-1.
                    if (txt_i >= 7'(jn_len)) begin
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!jn_rd_arm) begin
                        // flatten: txt_buf_rdata, then char_ok[txt_buf_rdata]
                        jn_rd_arm <= 1'b1;
                        jn_slot_arm <= 1'b0;
                    end else if (!jn_slot_arm) begin
                        jn_slot_arm <= 1'b1;
                    end else begin
                        jn_rd_arm <= 1'b0;
                        jn_slot_arm <= 1'b0;
                        // Cycle after JOIN_FIND poke 40: fill name_blen/off
                        // on the same we port as trail NAMB.
                        if (txt_i == 7'd0)
                            e64_poke(6'd17, {6'd0, (names_n - 16'd1)},
                                     {32'd0, nb_wp, 8'd0, jn_len});
                        name_we <= 1'b1;
                        name_waddr <= nb_wp[14:0];
                        name_wdata <= txt_buf_rdata;
                        if (jn_len == 8'd1 && !e32_char_ok_rdata) begin
                            char_id[txt_buf_rdata] <= names_n - 16'd1;
                            char_ok[txt_buf_rdata] <= 1'b1;
                        end
                        nb_wp <= nb_wp + 16'd1;
                        txt_i <= txt_i + 7'd1;
                    end
                end
                S_FONTPX: begin
                    // Ctx.font size. Walk the string for the first digit run
                    // that is followed by 'p' — the same first-match the FM regex
                    // (\d+)\s*px takes, so '12px/20px' and 'bold 24px X' agree.
                    // Value64 entry (the only live one): exec parsed nothing —
                    // it parks the font string's intern id in its hp_key copy
                    // and settles stack/ip before requesting this state.
                    // BIND-style first-entry seed from exec regs (hp_key is
                    // NOT hs64-muxed here).
                    if (state != S_FONTPX && e64_leave_hold) begin
                        hs_st(S_FONTPX);
                        name_rdaddr <= name_off_r3[e64_hp_key_q[9:0]];
                        fp_left <= name_blen_r1[e64_hp_key_q[9:0]][7:0];
                        txt_ph <= 4'd0;
                        fpx_acc <= 8'd0;
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                    end else
                    if (txt_ph == 4'd0) begin
                        name_rdaddr <= name_rdaddr + 16'd1; // prime byte 1
                        txt_ph <= 4'd1;
                    end else begin
                        logic got;
                        got = 1'b0;
                        if (name_rdata >= 8'h30 && name_rdata <= 8'h39)
                            fpx_acc <= (fpx_acc >= 8'd26) ? fpx_acc
                                     : (fpx_acc * 8'd10 + (name_rdata - 8'h30));
                        else if ((name_rdata == 8'h70 || name_rdata == 8'h50) &&
                                 fpx_acc != 8'd0) begin
                            ctx_font_px <= fpx_acc;
                            got = 1'b1;
                        end else if (name_rdata != 8'h20)
                            fpx_acc <= 8'd0; // digits not followed by px
                        if (got || fp_left <= 8'd1) begin
                            hs_code(15'(ops_base + ip));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            fp_left <= fp_left - 8'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                        end
                    end
                end
                S_TXT_LD: begin
                    // Leave cycle: parent state is still EXEC. Pin like RECT
                    // / ALLOC or exec re-issues POP (DONKEY/INVADERS fillText
                    // eip=next, fault 1, vsp already collapsed).
                    if (state != S_TXT_LD) begin
                        hs_st(S_TXT_LD);
                        // BIND-style: parent txt_* is not muxed from exec.
                        begin
                            txt_val <= e64_txt_val_q;
                            txt_vt <= e64_txt_vt_q;
                            txt_px <= e64_txt_px_q;
                            txt_py <= e64_txt_py_q;
                            txt_ph <= e64_txt_ph_q;
                            txt_bn <= e64_txt_bn_q;
                            color <= e64_color_q;
                        end
                    end else begin
                    // Stage the fillText argument into txt_buf. Interned
                    // strings come from name_mem, joined/JSON strings from
                    // json_mem, numbers are expanded to digits — after this the
                    // raster never cares where the text came from.
                    case (txt_ph)
                        4'd0: begin
                            // Shared half-up font scale, clamped to 1..15.
                            txt_ph <= 4'd1;
                        end
                        4'd1: begin
                            logic [7:0] nl;
                            txt_k <= text_font_scale;
                            txt_i <= 7'd0; txt_bn <= 7'd0; txt_d <= 4'd0;
                            if (txt_vt == 3'd3 && names_ok && e32_name_has_tos) begin
                                nl = e32_name_len_tos;
                                txt_len <= (nl > 8'(TXT_MAX)) ? 7'(TXT_MAX) : 7'(nl);
                                name_rdaddr <= e32_name_off_tos;
                                txt_ph <= (nl == 8'd0) ? 4'd6 : 4'd2;
                            end else if (txt_vt == 3'd1) begin
                                machine_fault <= 1'b1; fault_code <= 8'd9;
                                fault_site <= 16'd6889; running <= 1'b0; hs_st(S_DONE);
                            end else if (txt_vt == 3'd0 || txt_vt == 3'd7) begin
                                logic signed [31:0] iv;
                                iv = fxi(txt_val, txt_vt);
                                if (iv < 0) begin
                                    begin txw_we <= 1'b1; txw_wa <= 6'd0; txw_wd <= 8'h2D; end // '-'
                                    txt_bn <= 7'd1;
                                    iv = -iv;
                                end
                                txt_v <= iv;
                                txt_pi <= (iv >= 32'sd1000000000) ? 4'd9
                                        : (iv >= 32'sd100000000) ? 4'd8
                                        : (iv >= 32'sd10000000) ? 4'd7
                                        : (iv >= 32'sd1000000) ? 4'd6
                                        : (iv >= 32'sd100000) ? 4'd5
                                        : (iv >= 32'sd10000) ? 4'd4
                                        : (iv >= 32'sd1000) ? 4'd3
                                        : (iv >= 32'sd100) ? 4'd2
                                        : (iv >= 32'sd10) ? 4'd1 : 4'd0;
                                txt_ph <= 4'd5;
                            end else begin
                                // hash-only intern (no bytes) or undefined: draw
                                // nothing and count it — never a bar of garbage
                                txt_len <= 7'd0;
                                dbg_txt_miss <= dbg_txt_miss + 16'd1;
                                txt_ph <= 4'd6;
                            end
                        end
                        4'd2: begin
                            name_rdaddr <= name_rdaddr + 16'd1; // prime byte 1
                            txt_ph <= 4'd3;
                        end
                        4'd3: begin
                            begin txw_we <= 1'b1; txw_wa <= txt_i[5:0]; txw_wd <= name_rdata; end
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                name_rdaddr <= name_rdaddr + 16'd1;
                            end
                        end
                        4'd4: begin
                            if (!vjs_rd_arm)
                                vjs_rd_arm <= 1'b1;
                            else begin
                            begin txw_we <= 1'b1; txw_wa <= txt_i[5:0]; txw_wd <= json_mem_rdata; end
                            vjs_rd_arm <= 1'b0;
                            if (txt_i + 7'd1 >= txt_len) txt_ph <= 4'd6;
                            else begin
                                txt_i <= txt_i + 7'd1;
                                txt_rp <= txt_rp + 16'd1;
                            end
                            end
                        end
                        4'd5: begin
                            // MSD-first digits (no divider): subtract P10 and count
                            if (txt_v >= 32'(P10[txt_pi])) begin
                                txt_v <= txt_v - 32'(P10[txt_pi]);
                                txt_d <= txt_d + 4'd1;
                            end else begin
                                begin txw_we <= 1'b1; txw_wa <= txt_bn[5:0]; txw_wd <= 8'h30 + {4'd0, txt_d}; end
                                txt_bn <= txt_bn + 7'd1;
                                txt_d <= 4'd0;
                                if (txt_pi == 4'd0) begin
                                    txt_len <= txt_bn + 7'd1;
                                    txt_ph <= 4'd6;
                                end else txt_pi <= txt_pi - 4'd1;
                            end
                        end
                        default: begin
                            // FM fill_text: centre/right shift the pen by the text
                            // width, and y is a baseline (top = y - 8*scale)
                            logic [15:0] w_;
                            w_ = 16'(txt_len) * 16'd8 * 16'(txt_k);
                            dbg_txtw <= w_;
                            dbg_txt_n <= dbg_txt_n + 16'd1;
                            txt_x0 <= txt_px - ((ctx_align_eff == 2'd1) ? 16'($signed(w_) >>> 1)
                                             : (ctx_align_eff == 2'd2) ? 16'($signed(w_))
                                             : 16'sd0);
                            // #37 textBaseline: top = y; middle = y - 4k;
                            // bottom/alphabetic = y - 8k (today's default).
                            txt_y0 <= txt_py -
                                ((e64_ctx_baseline_q == 2'd1)
                                    ? 16'sd0
                                 : (e64_ctx_baseline_q == 2'd2)
                                    ? 16'(4 * {12'd0, txt_k})
                                    : 16'(8 * {12'd0, txt_k}));
                            if (txt_len == 7'd0) begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else if (txt_ph == 4'd6) begin
                                // flatten: txt_i=0 then wait txt_buf_rdata
                                txt_i <= 7'd0;
                                txt_ph <= 4'd7;
                            end else if (txt_ph == 4'd7) begin
                                txt_ph <= 4'd8;
                            end else begin
                                font_raddr <= {txt_buf_rdata[6:0], 3'd0};
                                txt_i <= 7'd0; txt_row <= 3'd0; txt_col <= 3'd0;
                                txt_kx <= 4'd0; txt_ky <= 4'd0;
                                txt_ph <= 4'd0;
                                hs_st(S_TXT_DRAW);
                            end
                        end
                    endcase
                    end
                end
                S_TXT_DRAW: begin
                    if (state != S_TXT_DRAW)
                        hs_st(S_TXT_DRAW);
                    // 8x8 glyph raster, one pixel per cycle, scaled k*k.
                    // Set bits only (transparent background, like FM fill_text).
                    if (fence_arm && fb_present_busy)
                        ; // present fence (whole-glyph-walk hold)
                    else if (txt_ph == 4'd4)
                        txt_ph <= 4'd5; // wait txt_buf_rdata of new txt_i
                    else if (txt_ph == 4'd5) begin
                        font_raddr <= {txt_buf_rdata[6:0], 3'd0};
                        txt_ph <= 4'd0;
                    end else if (txt_ph == 4'd0) txt_ph <= 4'd1; // font_rom read latency
                    else if (txt_ph == 4'd1) begin
                        txt_bits <= font_rdata;
                        txt_col <= 3'd0; txt_kx <= 4'd0; txt_ky <= 4'd0;
                        txt_ph <= 4'd2;
                    end else begin
                        logic signed [31:0] xx, yy;
                        logic on, adv;
                        logic [6:0] ni_;
                        ni_ = txt_i + 7'd1;
                        on = txt_bits[3'd7 - txt_col];
                        xx = $signed({16'd0, txt_x0})
                           + ((32'({2'd0, txt_i}) * 32'sd8 + 32'({29'd0, txt_col}))
                              * 32'({28'd0, txt_k}))
                           + 32'({28'd0, txt_kx});
                        yy = $signed({16'd0, txt_y0})
                           + (32'({29'd0, txt_row}) * 32'({28'd0, txt_k}))
                           + 32'({28'd0, txt_ky});
                        if (on && xx >= 32'sd0 && xx < $signed(32'(MW)) &&
                            yy >= 32'sd0 && yy < $signed(32'(MH))) begin
                            fb_we <= 1'b1;
                            fb_waddr <= 19'(yy) * 19'(MW) + 19'(xx);
                            fb_x <= 10'(xx); fb_y <= 10'(yy);
                            fb_wdata <= color;
                        end
                        // clear pixels cost no time: skip the whole k*k block
                        adv = 1'b0;
                        if (!on) adv = 1'b1;
                        else if (txt_kx + 4'd1 >= txt_k) begin
                            if (txt_ky + 4'd1 >= txt_k) adv = 1'b1;
                            else begin txt_ky <= txt_ky + 4'd1; txt_kx <= 4'd0; end
                        end else txt_kx <= txt_kx + 4'd1;
                        if (adv) begin
                            txt_kx <= 4'd0; txt_ky <= 4'd0;
                            if (txt_col != 3'd7) txt_col <= txt_col + 3'd1;
                            else if (txt_row != 3'd7) begin
                                txt_row <= txt_row + 3'd1;
                                font_raddr <= {txt_buf_rdata[6:0], txt_row + 3'd1};
                                txt_ph <= 4'd0;
                            end else if (txt_i + 7'd1 >= txt_len) begin
                                hs_code(15'(ops_base + ip));
                                hs_st(S_FETCH_WAIT);
                            end else begin
                                txt_i <= txt_i + 7'd1;
                                txt_row <= 3'd0;
                                txt_ph <= 4'd4;
                            end
                        end
                    end
                end
                S_NAMCPY: begin
                    // interned name_mem → json_mem via registered name_rdata
                    // (same BRAM lag as str[i]; do not combinational-read NAME_CAP).
                    //
                    // First-entry hs_st + seed copy, same
                    // class as #53. exec enters this state directly (JSON.parse
                    // of an interned string, replace, indexOf) but every seed
                    // it computed (name_rdaddr, json_src/srclen/rp/wp, pph,
                    // js_sp, namcpy_v64/repl) lives in EXEC's FFs; this arm
                    // reads the PARENT FFs, which nothing ever wrote. Parse of
                    // a constant string copied garbage and faulted 1 at the
                    // next LET_VAR (site 3423). The hs_st also stops exec
                    // re-running the CALL_NATIVE while the copy walks.
                    if (casestate_q != S_NAMCPY) begin
                        hs_st(S_NAMCPY);
                        begin
                            name_rdaddr <= e64_name_rdaddr_q;
                            json_src    <= e64_json_src_q;
                            json_srclen <= e64_json_srclen_q;
                            json_rp     <= e64_json_rp_q;
                            json_wp     <= e64_json_wp_q;
                            json_pph    <= e64_json_pph_q;
                            js_sp       <= e64_js_sp_q;
                            namcpy_v64  <= e64_namcpy_v64_q;
                            namcpy_repl <= e64_namcpy_repl_q;
                            // String.replace parent latches (PACMAN ghost
                            // AI: stringify(...).replace(/2/g,0)): repl_rch
                            // only ever lived in EXEC's FFs. repl_pat0==0 means
                            // "pattern is a RegExp object" — those fields
                            // were parent-written by the nat=5 read; do not
                            // clobber them.
                            repl_rch <= e64_repl_rch_q;
                            repl_did <= 1'b0;
                            if (e64_repl_pat0_q != 8'd0) begin
                                repl_pat0 <= e64_repl_pat0_q;
                                repl_pat1 <= 8'd0;
                                repl_nlen <= 8'd1;
                                repl_g <= e64_repl_g_q;
                            end

                            // completion branches read hp_nat (indexOf) and
                            // hp_wval (needle); NAMCPY is not in hs64 so the
                            // muxes fall back to the parent _ff copies.
                            hs_hp_nat(e64_hp_nat_q);
                            hs_hp_wval(e64_hp_wval_q);
                            hs_vnat_base(e64_vnat_base_q);
                            // completion chains end with hs_code(ops_base+ip)
                            // — parent ip must be exec's, not a stale hs_ip.
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                        namcpy_armed <= 1'b0;
                    end
                    else if (!namcpy_armed) namcpy_armed <= 1'b1;
                    else begin
                        if (json_wp < 14'(JSON_CAP)) begin
                            json_we <= 1'b1;
                            json_waddr <= json_wp[12:0];
                            json_wdata <= name_rdata;
                        end
                        if (json_wp + 14'd1 >= json_srclen || json_wp + 14'd1 >= 14'(JSON_CAP)) begin
                            json_src <= 14'd0;
                            json_rp <= 14'd0;
                            namcpy_armed <= 1'b0;
                            if (namcpy_v64) begin
                                namcpy_v64 <= 1'b0;
                                json_wp <= 14'd0;
                                hs_st(S_V64_JSON_PARSE);
                            end else if (namcpy_repl) begin
                                json_dst <= json_srclen;
                                json_wp <= json_srclen;
                                hs_st(S_REPL);
                            end else if (hp_nat == 4'd3) begin
                                // interned indexOf: name_mem was copied 1 byte/clock
                                json_src <= 14'd0;
                                json_rp <= 14'd0;
                                json_wp <= 14'd0;
                                idx_needle <= hp_wval[7:0];
                                hs_st(S_IDXSTR);
                            end else begin
                                json_wp <= 14'd0;
                                hs_st(S_JSON_PARSE);
                            end
                        end else begin
                            json_wp <= json_wp + 14'd1;
                            name_rdaddr <= name_rdaddr + 16'd1;
                            namcpy_armed <= 1'b0;
                        end
                    end
                end
                S_IDXSTR: begin
                    // Value64 dynstr indexOf writes the IEEE index.
                    // One json_mem byte/clock.
                    if (json_rp >= json_src + json_srclen) begin
                        vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (!vjs_rd_arm) begin
                        vjs_rd_arm <= 1'b1;
                    end else if (json_mem_rdata == idx_needle) begin
                        vjs_rd_arm <= 1'b0;
                        vst_wr(hp_vbase,
                            v64_int32_number(32'(json_rp - json_src)));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        vjs_rd_arm <= 1'b0;
                        json_rp <= json_rp + 14'd1;
                    end
                end
                S_IMGD_GET: begin
                    // #54: exec-direct entry (getImageData — PACMAN's maze
                    // cache). All imgd_* seeds live in exec FFs; this arm read
                    // the parent's, which nothing wrote.
                    if (casestate_q != S_IMGD_GET) begin
                        hs_st(S_IMGD_GET);
                        begin
                            imgd_x0 <= e64_imgd_x0_q;
                            imgd_y0 <= e64_imgd_y0_q;
                            imgd_w  <= e64_imgd_w_q;
                            imgd_h  <= e64_imgd_h_q;
                            imgd_x  <= e64_imgd_x_q;
                            imgd_y  <= e64_imgd_y_q;
                            imgd_i  <= e64_imgd_i_q;
                            imgd_n  <= e64_imgd_n_q;
                            imgd_v64 <= e64_imgd_v64_q;
                            fb_dump_addr <= e64_fb_dump_addr_q;
                            hs_vnat_base(e64_vnat_base_q);
                        end
                        imgd_armed <= 1'b0;
                        imgd_pend <= 1'b0;
                        fb_dump_sel <= 1'b1;
                        begin
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                        end
                    end else begin
                    casestate_imgd_body: begin end
                    // Copy back-buffer rect into the one snapshot (dump_back is
                    // registered 1 cycle after dump_raddr). S_CLEAR twin: one
                    // index, always i++ until n — 10-bit x+w wrap spun until
                    // the 16M FRAME cap. 1 px/cycle × 307200 fits; do not
                    // raise the cap. Host FB? must not walk dump_sel (GET
                    // holds it).
                    fb_we <= 1'b0;
                    fb_dump_sel <= 1'b1;
                    if (imgd_n == 19'd0) begin
                        if (imgd_v64) begin
                            // Value64 ImageData handle (same snapshot buffer).
                            if (!vfree_armed) begin
                                vfree_armed <= 1'b1;
                                hs_valloc_i(14'd0);
                                hs_hp_ret(S_IMGD_GET);
                                hs_st(S_FREE_OBJ);
                            end else begin
                                vfree_armed <= 1'b0;
                                if (vfree_ok) begin
                                    vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                    vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= CLS_IMGD;
                                    begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd0, 2'd0, 6'd2});
                                    e64_p_addr2 <= CLS_IMGD;
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number({22'd0, imgd_w});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number({22'd0, imgd_h});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd5, vobj_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    hs_vsp(vnat_base + 12'd1);
                                    vobj_next <= valloc_i + 14'd1;
                                    imgd_v64 <= 1'b0;
                                    fb_dump_sel <= 1'b0;
                                    hs_code(15'(ops_base + ip));
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd10427;
                                    running <= 1'b0; hs_st(S_DONE);
                                end
                            end
                        end
                    end else if (!imgd_armed) begin
                        // settle beat: fb_dump_back is registered one cycle
                        // after fb_dump_addr - same arm as before the SRAM move
                        imgd_armed <= 1'b1;
                    end else if (!imgd_pend) begin
                        // Two snapshot pixels per 16-bit word. The even
                        // write also clears the unused high byte of an odd
                        // tail; the odd write completes that same word.
                        sram_req   <= 1'b1;
                        sram_we    <= (imgd_i < 19'(FB_PIXELS));
                        sram_addr  <= IMGD_SRAM_BASE
                                    + ((imgd_i < 19'(FB_PIXELS)) ? 21'(imgd_i >> 1) : 21'd0);
                        if (!imgd_i[0]) imgd_low <= fb_dump_back;
                        sram_wdata <= imgd_i[0] ? {fb_dump_back, imgd_low}
                                               : {8'd0, fb_dump_back};
                        imgd_pend  <= 1'b1;
                    end else if (sram_ack) begin
                        sram_req <= 1'b0;
                        sram_we  <= 1'b0;
                        imgd_pend <= 1'b0;
                        imgd_armed <= 1'b0; // fresh settle after the addr advance
                        if (imgd_i == (imgd_n - 19'd1)) begin
                            if (imgd_v64) begin
                                if (!vfree_armed) begin
                                    vfree_armed <= 1'b1;
                                    hs_valloc_i(14'd0);
                                    hs_hp_ret(S_IMGD_GET);
                                    hs_st(S_FREE_OBJ);
                                end else begin
                                    vfree_armed <= 1'b0;
                                    if (vfree_ok) begin
                                        vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                        vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= CLS_IMGD;
                                        begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd2; end
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd0, 2'd0, 6'd2});
                                        e64_p_addr2 <= CLS_IMGD;
                                        hs_hp_cmd(HP_OSETI);
                                        hs_hp_oid(valloc_i[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_hp_qn(3'd2);
                                        hs_hp_qi(3'd0);
                                        hp_qk_ff[0] <= id_width;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[0] <= v64_int32_number({22'd0, imgd_w});
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[0] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        hp_qk_ff[1] <= id_height;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[1] <= v64_int32_number({22'd0, imgd_h});
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[1] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        vst_wr(vnat_base, v64_handle(
                                            4'd5, vobj_gen_rdata,
                                            {19'd0, valloc_i[12:0]}
                                        ));
                                        hs_vsp(vnat_base + 12'd1);
                                        vobj_next <= valloc_i + 14'd1;
                                        imgd_v64 <= 1'b0;
                                        fb_dump_sel <= 1'b0;
                                        hs_code(15'(ops_base + ip));
                                        hs_hp_ret(S_FETCH_WAIT);
                                        hs_st(S_HEAP_WR);
                                    end else begin
                                        machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd10513;
                                        running <= 1'b0; hs_st(S_DONE);
                                    end
                                end
                            end
                        end else begin
                            imgd_i <= imgd_i + 19'd1;
                            if (imgd_x >= (imgd_x0 + imgd_w - 10'd1) || imgd_x == 10'(MW - 1)) begin
                                imgd_x <= imgd_x0;
                                imgd_y <= imgd_y + 10'd1;
                                fb_dump_addr <= 19'(imgd_y + 10'd1) * 19'(MW) + 19'(imgd_x0);
                            end else begin
                                imgd_x <= imgd_x + 10'd1;
                                fb_dump_addr <= 19'(imgd_y) * 19'(MW) + 19'(imgd_x + 10'd1);
                            end
                        end
                    end
                    end // #54 guard else
                end
                S_IMGD_PUT: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_IMGD_PUT) hs_code(15'(ops_base + ip));
                    if (imgd_w == 10'd0 || imgd_h == 10'd0) begin
                        if (imgd_v64) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            imgd_v64 <= 1'b0;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end else if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: linear DMA from the external snapshot region
                        // through the engine (was one arbiter round trip
                        // per PIXEL at VM-beat pace — MRDOFAST's 63% sink).
                        rast_go <= 1'b1;
                        rast_mode <= 2'd2;
                        rast_dx <= imgd_x0;
                        rast_dy <= imgd_y0;
                        rast_w <= imgd_w;
                        rast_h <= imgd_h;
                        rast_sbase <= 22'(imgd_i);
                        // putImageData source walks linearly forward; never
                        // inherit a stale flip from a prior drawImage's
                        // neg-xform mirror (S_BLIT), or the restore would
                        // scramble columns/rows.
                        rast_flip_x <= 1'b0;
                        rast_flip_y <= 1'b0;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        if (imgd_v64) begin
                            vst_wr(vnat_base, V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            imgd_v64 <= 1'b0;
                        end
                        hs_code(15'(ops_base + ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                // S_V64_EXEC body moved to hierarchical exec (keep_hierarchy); applied above when state matches.
                S_V64_ALLOC: begin
                    // Leave cycle: parent state is still EXEC. Stay in ALLOC
                    // while the free-slot scan walks (same pin as RECT /
                    // GC_CLEAR). Without this, exec re-issues MAKE_ARR from
                    // i=0 every clock and arrays never land (INVADERS
                    // obj=1023 arr=0).
                    if (state != S_V64_ALLOC) begin
                        hs_st(S_V64_ALLOC);
                        // Latch exec start so ALLOC uses parent *_ff (hs_m
                        // is one-shot; rdata wait must not snap to e64).
                        hs_valloc_kind(e64_valloc_kind_q);
                        hs_valloc_i(e64_valloc_i_q);
                        if (state == S_V64_EXEC && e64_valloc_metrics_q)
                            vmetrics_w <= e64_vmetrics_w_q;
                        valloc_rd_arm <= 1'b0;
                        // GET_PROP / prior NEW_OBJ left cls_done+cls_ctor_q
                        // (Game ctor=1). Next nested `new Item` then
                        // re-entered Game until CSTK (PACMAN fault 2).
                        cls_done <= 1'b0;
                        cls_hit <= 1'b0;
                    end else if (casestate_q != S_V64_ALLOC)
                        // casestate_q SRAM mux: vfn_env/entry rdata is one
                        // beat after q==ALLOC. Kind 3 intern `new Stage`
                        // used BIND leftover entry (PACMAN LOAD_VAR stage
                        // fault 4; snippet NEW_OBJ Game HEAP re-issue).
                        hs_st(S_V64_ALLOC);
                    else if (cls_scan)
                        hs_st(S_V64_ALLOC);
                    else if (cls_done && cls_ctor_mode &&
                             (valloc_kind == 2'd0) &&
                             (code_rdata[7:0] == OP_NEW_OBJ)) begin
                        // Object already written; ctor_ip from class scan FF.
                        begin
                            logic [15:0] ctor_ip;
                            logic [63:0] handle;
                            logic [11:0] argc;
                            logic [8:0] vslot;
                            ctor_ip = cls_ctor_q;
                            argc = vcall_argc;
                            handle = v64_handle(
                                4'd5, vobj_gen_rdata,
                                {19'd0, valloc_i[12:0]}
                            );
                            cls_done <= 1'b0;
                            // Class table ctor wins when it has an IP.
                            // ctor_q=FFFF is miss OR `var Item = function`
                            // (PACMAN Stage/Item). PYTHON / exec32 then
                            // use intern_var even if cls_hit. Skipping
                            // that re-used leftover Game ctor=1.
                            if (cls_hit && ctor_ip != 16'hFFFF) begin
                                if (vcsp >= CSTK) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd2; fault_site <= 16'd10808;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else if (e32_intern_var_ok_rdata) begin
                                    // PYTHON NEW_OBJ links
                                    // instance.__proto__ = ctorFn.prototype on
                                    // EVERY class-table hit
                                    // (_value64_ctor_function_for_class +
                                    // _value_object_protos), not only on the
                                    // dynamic env/vars ctor paths. This inline
                                    // dispatch skipped the link, so
                                    // `function Stage(){}` +
                                    // `Stage.prototype.m = ...` + `new Stage()`
                                    // left vobj_proto UNDEFINED and every
                                    // prototype member read undefined with no
                                    // fault — PACMAN's title items were never
                                    // created (createItem/bind/draw all
                                    // prototype methods): black glass.
                                    // Route through the existing S_RD →
                                    // S_V64_CTOR_VARS machinery, which reads
                                    // vvars[slot] (hoisted fn), writes
                                    // vobj_proto[valloc_i] <= vfn_proto, and
                                    // then dispatches this same ctor_ip via
                                    // its ctor_ip != FFFF branch. All the
                                    // read-mux cases for this route already
                                    // exist (vvars_raddr, vfn_proto_rdata,
                                    // vfn_valid_rdata). Two extra clocks per
                                    // `new`, Port A legal.
                                    hs_hp_key({7'd0, e32_intern_var_rdata});
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    ret_state <= S_V64_CTOR_VARS;
                                    hs_st(S_RD);
                                end else begin
                                    // Class name is not a var (pure `class`
                                    // syntax): methods live in cls_mip, no
                                    // runtime prototype object to link.
                                    hs_vcall_value(1'b0);
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    hs_vcall_set_this(1'b1);
                                    hs_vcall_this(handle);
                                    hs_vcall_ctor_val(handle);
                                    hs_valloc_kind(2'd3);
                                    hs_valloc_i({4'd0, venv_next});
                                    hs_valloc_retried(1'b0);
                                    valloc_rd_arm <= 1'b0;
                                end
                            end else if (ctor_ip == 16'hFFFF &&
                                e32_intern_var_ok_rdata &&
                                venv[63:48] == 16'h7ff9 &&
                                venv[47:44] == 4'd9) begin
                                if (venv[31:0] >= ENV_DEPTH ||
                                    !venv_valid_rdata ||
                                    venv_gen_rdata != venv[43:32]) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd4; fault_site <= 16'd10864;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    vslot = e32_intern_var_rdata;
                                    hs_vcall_entry(ctor_ip);
                                    hs_vcall_argc(argc);
                                    hs_hp_env(1'b1);
                                    hs_hp_cmd(HP_GETPROP);
                                    hs_hp_eid(venv[9:0]);
                                    hs_hp_len({1'b0, venv_len_rdata});
                                    hs_hp_slot(5'd0);
                                    hs_hp_key({7'd0, vslot});
                                    hs_hp_phase(3'd0);
                                    hs_hp_hit(1'b0);
                                    hs_hp_ret(S_V64_CTOR_ENV);
                                    hs_st(S_HEAP_WAIT);
                                end
                            end else if (ctor_ip == 16'hFFFF &&
                                e32_intern_var_ok_rdata) begin
                                hs_hp_key({7'd0, e32_intern_var_rdata});
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                ret_state <= S_V64_CTOR_VARS;
                                hs_st(S_RD);
                            end else begin
                                vst_wr(vsp - argc, handle);
                                hs_vsp(vsp - argc + 12'd1);
                                if (e64_vcsp_q != 8'd0)
                                    hs_vcsp(e64_vcsp_q - 8'd1);
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end
                    else if (!valloc_rd_arm) begin
                        // *_valid_rdata is last beat's valloc_i. Wait
                        // after increment or kind change (holes after GC).
                        valloc_rd_arm <= 1'b1;
                        hs_st(S_V64_ALLOC);
                    end else if (valloc_kind == 2'd1) begin
                            logic [15:0] count;
                        logic need_long;
                        // Latched at OP_MAKE_ARR / Array(n). Do not use
                        // code_rdata here — GC resume would re-decode a
                        // different word as the length.
                        count = {8'd0, valloc_arr_n};
                        need_long = (count > 16'(ARR_SHORT_CAP));
                        if ((!need_long && valloc_i < MAX_ARR &&
                             !varr_valid_rdata &&
                             (valloc_i < 14'(MAX_ARR_SHORT) ||
                              !vlong_used_rdata)) ||
                            (need_long && valloc_i >= 14'(MAX_ARR_SHORT) &&
                             valloc_i < MAX_ARR &&
                             !varr_valid_rdata &&
                             !vlong_used_rdata)) begin
                            logic take_long;
                            take_long = need_long ||
                                (valloc_i >= 14'(MAX_ARR_SHORT));
                            begin vav_we <= 1'b1; vav_wa <= valloc_i[10:0]; vav_wd <= 1'b1; end
                            varr_len_wr(valloc_i[11:0], count[7:0]);
                            begin vlo_we <= 1'b1; vlo_wa <= valloc_i[10:0]; vlo_wd <= take_long; end
                            e64_poke(6'd45, {4'd0, valloc_i[11:0]},
                                     {55'd0, take_long, count[7:0]});
                            e64_p_addr2 <= {8'd0, valloc_i[7:0]};
                            if (take_long) begin
                                begin vli_we <= 1'b1; vli_wa <= valloc_i[10:0]; vli_wd <= valloc_i[7:0]; end
                                begin vlu_we <= 1'b1; vlu_wa <= valloc_i[6:0]; vlu_wd <= 1'b1; end
                            end
                            varr_next <= valloc_i + 14'd1;
                            if (vnat_dom == 3'd7) begin
                                vst_wr(vnat_base, v64_handle(
                                    4'd6, varr_gen_rdata,
                                    {20'd0, valloc_i[11:0]}
                                ));
                                hs_vsp(vnat_base + 12'd1);
                                hs_vnat_dom(3'd0);
                                hs_hp_make_arr(1'b0);
                            end else if (count == 16'd0) begin
                                vst_wr(vsp, v64_handle(
                                    4'd6, varr_gen_rdata,
                                    {20'd0, valloc_i[11:0]}
                                ));
                                hs_vsp(vsp + 12'd1);
                            end else begin
                                // Leave e0..eN-1 on the stack; S_HEAP_FILL
                                // copies them, then writes the handle at vbase.
                                hs_hp_make_arr(1'b1);
                                hs_hp_rval(v64_handle(
                                4'd6, varr_gen_rdata,
                                {20'd0, valloc_i[11:0]}
                            ));
                            hs_vsp(vsp - count + 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            if (count == 16'd0)
                            hs_st(S_FETCH_WAIT);
                            else begin
                                hs_hp_cmd(HP_AFILL);
                                hs_hp_from_stack((vnat_dom != 3'd7));
                                hs_hp_aid(valloc_i[11:0]);
                                hs_hp_aslot(7'd0);
                                hs_hp_lim(count[7:0]);
                                hs_hp_vbase((vnat_dom == 3'd7)
                                    ? 12'd0 : (vsp - count));
                                hs_hp_wval(V64_UNDEFINED);
                                hs_hp_ret(S_FETCH_WAIT);
                                hs_st(S_HEAP_FILL);
                            end
                        end else if (valloc_i + 14'd1 < MAX_ARR) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd10988;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else if (valloc_kind == 2'd3) begin
                        if (valloc_i < ENV_DEPTH &&
                            !venv_valid_rdata) begin
                            logic [11:0] base_sp;
                            logic [7:0] nparam;
                            logic [7:0] fr;
                            logic [63:0] function_handle, parent_env;
                            logic [63:0] ctor_inst;
                            logic is_valcall;
                            // Kind 0 / CTOR_ENV planted the instance in *_ff;
                            // hs_m is already clear so the mux is leftover
                            // exec UNDEF. Nested `new` inside a constructor
                            // also leaves vcall_value mux=1 (IIFE/CALL_VAL)
                            // and would BIND as a call — empty this.n=n.
                            if (vcall_ctor_val_ff[63:48] == V64_TAG_PREFIX &&
                                vcall_ctor_val_ff[47:44] == V64_KIND_OBJECT)
                                ctor_inst = vcall_ctor_val_ff;
                            else
                                ctor_inst = vcall_ctor_val;
                            is_valcall = vcallback_fe || intern_ctor_fn ||
                                (vcall_value &&
                                !(ctor_inst[63:48] == V64_TAG_PREFIX &&
                                  ctor_inst[47:44] == V64_KIND_OBJECT &&
                                  !vcall_value_ff));
                            base_sp = vsp - vcall_argc -
                                      (is_valcall ? 12'd1 : 12'd0);
                            // forEach: callee is vfe_fn. VST_AT(vsp-argc-1)
                            // misses when parent vsp/window and exec vsp
                            // disagree (LET_VAR fault 1, n stays 0).
                            // Intern NEW_OBJ: callee is bind_ins, not stack
                            // (NEW_OBJ never pushed the function).
                            function_handle = vcallback_fe
                                ? e64_vfe_fn_q
                                : intern_ctor_fn ? bind_ins
                                : (is_valcall
                                    ? `VST_AT(vsp - vcall_argc - 12'd1)
                                    : V64_UNDEFINED);
                            parent_env = intern_ctor_fn ? intern_ctor_env
                                : (is_valcall ? vfn_env_rdata : venv);
                            // ALLOC re-issue can see venv already this slot
                            // (nested CALL_USER). A self-parent makes
                            // STORE_VAR HEAP_CMP walk forever (eid=2→2).
                            if (parent_env[63:48] == V64_TAG_PREFIX &&
                                parent_env[47:44] == V64_KIND_ENV &&
                                parent_env[9:0] == valloc_i[9:0])
                                parent_env = V64_UNDEFINED;
                            nparam = intern_ctor_fn
                                ? {2'd0, intern_ctor_nparam}
                                : (is_valcall
                                ? {2'd0, vfn_nparam_rdata}
                                : vcall_argc);
                            // forEach args sit at vfe_base+2 (pushed fn)
                            // then elem. Do not use exec vsp (frozen at
                            // CALL_METHOD) — that made bind_vsp_next=0
                            // and LET_VAR fault 1.
                            if (vcallback_fe) begin
                                if (nparam == 8'd0)
                                    nparam = 8'd1;
                                base_sp = e64_vfe_base_q + 12'd2;
                            end
                            // CALL_USER/NEW_OBJ clock exec vcsp+1 before
                            // ALLOC, so the new slot is e64-1. Parent-
                            // reserve paths (FOREACH / FRAME_RAF / LOOKFN
                            // / getter) poke hs_vcsp(e64+1) the cycle
                            // before ALLOC; exec has not absorbed it, so
                            // e64 is still the caller. Using e64-1 then
                            // overwrote that caller with 0xfffc (animate
                            // RET_VAL fault 2; leftover rAF overflow).
                            if (hs_m_vcsp &&
                                (vcsp_ff == (e64_vcsp_q + 8'd1)))
                                fr = e64_vcsp_q;
                            else
                                fr = (e64_vcsp_q != 8'd0)
                                     ? (e64_vcsp_q - 8'd1) : vcsp;
                            begin vev_we <= 1'b1; vev_wa <= valloc_i[8:0]; vev_wd <= 1'b1; end
                            begin vel_we <= 1'b1; vel_wa <= valloc_i[8:0]; vel_wd <= 5'd0; end
                            e64_poke(6'd46, {6'd0, valloc_i[9:0]},
                                     {52'd0, venv_gen_rdata});
                            venv_parent_pa_we <= 1'b1;
                            venv_parent_pa_waddr <= valloc_i[9:0];
                            venv_parent_pa_wdata <= parent_env;
                            venv_next <= valloc_i[9:0] + 10'd1;
                            // CALL_USER clocks ip_n=entry before ALLOC.
                            // ip+1 was then entry+1 (INVADERS vret=1798).
                            // bind_ip holds call-site+1 from that EXEC beat.
                            vfr_we  <= 1'b1;
                            vfr_wa  <= fr[6:0];
                            vfr_rip <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc
                                : ((ip == vcall_entry) ? e64_bind_ip_q
                                                      : (ip + 16'd1));
                            vfr_bsp  <= base_sp - {10'd0,setter_pending} - {11'd0,callref_pending};
                            vfr_setter <= (setter_pending != 0);
                            vfr_this <= vthis;
                            vfr_env  <= venv;
                            vfr_fn   <= setter_pending != 0 ? `VST_AT(vsp - 12'd1) : function_handle;
                            vfr_ctor <= ctor_inst;
                            vframe_escaped[fr] <= 1'b0;
                            e64_p_frame_we <= 1'b1;
                            e64_p_frame_idx <= fr[6:0];
                            e64_p_frame_rip <= vcallback_raf
                                ? 16'hffff
                                : vcallback_timer ? 16'hfffe
                                : vcallback_key ? 16'hfffd
                                : vcallback_fe ? 16'hfffc
                                : ((ip == vcall_entry) ? e64_bind_ip_q
                                                      : (ip + 16'd1));
                            e64_p_frame_bsp <= base_sp - {10'd0,setter_pending} - {11'd0,callref_pending};
                            e64_p_frame_esc <= 1'b0;
                            e64_p_frame_this <= vthis;
                            e64_p_frame_env <= venv;
                            e64_p_frame_fnv <= setter_pending != 0 ? `VST_AT(vsp - 12'd1) : function_handle;
                            setter_pending <= 0;callref_pending <= 0;
                            e64_p_frame_ctor <= ctor_inst;
                            hs_vcsp(fr + 8'd1);
                            vcallback_raf <= 1'b0;
                            vcallback_timer <= 1'b0;
                            vcallback_key <= 1'b0;
                            vcallback_fe <= 1'b0;
                            hs_venv(v64_handle(
                                4'd9, venv_gen_rdata,
                                {22'd0, valloc_i[9:0]}
                            ));
                            if (is_valcall) begin
                                // Arrow/bound keep lexical this; CALL_METHOD
                                // own-property sets vcall_this (game.init).
                                // Nested NEW_OBJ may still see leftover
                                // vcall_value=1; keep the instance in this.
                                hs_vthis((ctor_inst[63:48] == V64_TAG_PREFIX &&
                                          ctor_inst[47:44] == V64_KIND_OBJECT)
                                       ? ctor_inst
                                       : (((intern_ctor_fn
                                            ? intern_ctor_flags[0]
                                            : vfn_flags_rdata[0]) ||
                                          (intern_ctor_fn
                                            ? intern_ctor_flags[2]
                                            : vfn_flags_rdata[2]))
                                       ? vfn_bound_this_rdata
                                       : vcall_set_this
                                       ? vcall_this : V64_UNDEFINED));
                                bind_mode <= 2'd0;
                                bind_k <= 8'd0;
                                bind_n <= nparam;
                                bind_argc <= vcall_argc[7:0];
                                bind_base <= base_sp;
                                bind_src <= vcallback_fe
                                    ? (e64_vfe_base_q + 12'd3)
                                    : (vsp - vcall_argc);
                                bind_vsp_next <= base_sp + nparam;
                                bind_ip <= intern_ctor_fn
                                    ? intern_ctor_entry : vfn_entry_rdata;
                                bind_ret <= S_FETCH_WAIT;
                                bind_rd_arm <= 1'b0;
                                intern_ctor_hold <= 1'b0;
                                hs_st(S_V64_BIND);
                            end else begin
                                hs_vthis((ctor_inst[63:48] == V64_TAG_PREFIX &&
                                          ctor_inst[47:44] == V64_KIND_OBJECT)
                                       ? ctor_inst
                                       : (vcall_set_this
                                          ? vcall_this : V64_UNDEFINED));
                                vctor_scan <= 6'd0;
                                vctor_armed <= 1'b0;
                                // CALL_USER entry lives in exec q; NEW_OBJ
                                // cls_ctor lives in vcall_entry_ff. Latch the
                                // mux into ff so CTOR_PAD (hs_m already 0)
                                // does not bind_ip=0 and skip the ctor.
                                hs_vcall_entry(vcall_entry);
                                hs_ip(vcall_entry);
                                hs_code(15'(ops_base + vcall_entry));
                                intern_ctor_hold <= 1'b0;
                                hs_st(S_V64_CTOR_PAD);
                            end
                            hs_vcall_set_this(1'b0);
                            hs_vcall_ctor_val(V64_UNDEFINED);
                        end else if (valloc_i + 14'd1 < ENV_DEPTH) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd11178;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else if (valloc_kind == 2'd2) begin
                        if (valloc_i < MAX_OBJ &&
                            !vfn_valid_rdata) begin
                            vfn_next <= valloc_i + 14'd1;
                            begin vfv_we <= 1'b1; vfv_wa <= valloc_i[9:0]; vfv_wd <= 1'b1; end
                                if (valloc_now_fn) begin
                                    vfn_entry[valloc_i[12:0]] <= 16'hfffa;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd0;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'd0;
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= V64_UNDEFINED;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0, 3'd0, 6'd0, 16'hfffa});
                                    e64_p_data2 <= V64_UNDEFINED;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= V64_UNDEFINED;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    // Same-cycle TOS: leave_hold ALLOC window
                                    // otherwise sees exec vst_we=0 (IIFE CALL_VAL).
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_now_fn(1'b0);
                                end else if (valloc_bind &&
                                             valloc_bind_src == 13'h1FFF) begin
                                    vfn_entry[valloc_i[12:0]] <= valloc_fn_entry;
                                    vfn_nparam[valloc_i[12:0]] <= 6'd1;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= V64_UNDEFINED;
                                    vfn_flags[valloc_i[12:0]] <= 3'b100;
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= valloc_bind_this;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0, 3'b100, 6'd1,
                                              valloc_fn_entry});
                                    e64_p_data2 <= V64_UNDEFINED;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_bind_this;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_bind(1'b0);
                                    hs_valloc_fn_entry(16'd0);
                                end else if (valloc_bind) begin
                                    vfn_entry[valloc_i[12:0]] <=
                                        vfn_entry_rdata;
                                    vfn_nparam[valloc_i[12:0]] <=
                                        vfn_nparam_rdata;
                                    vfn_env_pa_we <= 1'b1;
                                    vfn_env_pa_waddr <= valloc_i[12:0];
                                    vfn_env_pa_wdata <= vfn_env_rdata;
                                    // [2]=has_bound_this (PYTHON bind).
                                    vfn_flags[valloc_i[12:0]] <=
                                        {1'b1, vfn_flags_rdata[1],
                                         vfn_flags_rdata[0]};
                                    vfn_bound_this_pa_we <= 1'b1;
                                    vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                    vfn_bound_this_pa_wdata <= valloc_bind_this;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0,
                                              1'b1,
                                              vfn_flags_rdata[1],
                                              vfn_flags_rdata[0],
                                              vfn_nparam_rdata,
                                              vfn_entry_rdata});
                                    e64_p_data2 <= vfn_env_rdata;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_bind_this;
                                    vst_wr(vnat_base, v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_win[0] <= v64_handle(
                                        4'd7, vfn_gen_rdata,
                                        {19'd0, valloc_i[12:0]}
                                    );
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_bind(1'b0);
                                end else begin
                                    vfn_entry[valloc_i[12:0]] <= valloc_fn_entry;
                                    vfn_nparam[valloc_i[12:0]] <= valloc_fn_a1[5:0];
                                vfn_env_pa_we <= 1'b1;
                                vfn_env_pa_waddr <= valloc_i[12:0];
                                vfn_env_pa_wdata <= venv;
                                    // [2]=arrow [1]=IIFE (JSB a1 bit6) [0]=arrow
                                    // this-bind. CALL_VAL reads [1] for flat IIFE.
                                vfn_flags[valloc_i[12:0]] <=
                                        {valloc_fn_a1[7], valloc_fn_a1[6],
                                         valloc_fn_a1[7]};
                                vfn_bound_this_pa_we <= 1'b1;
                                vfn_bound_this_pa_waddr <= valloc_i[12:0];
                                vfn_bound_this_pa_wdata <= valloc_fn_a1[7] ? vthis : V64_UNDEFINED;
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_i[12:0];
                                    vfn_proto_pa_wdata <= V64_UNDEFINED;
                                    e64_poke(6'd47, {3'd0, valloc_i[12:0]},
                                             {39'd0,
                                              valloc_fn_a1[7],
                                              valloc_fn_a1[6],
                                              valloc_fn_a1[7],
                                              valloc_fn_a1[5:0],
                                              valloc_fn_entry});
                                    e64_p_data2 <= venv;
                                    e64_p_data3 <= V64_UNDEFINED;
                                    e64_p_data4 <= valloc_fn_a1[7]
                                        ? vthis : V64_UNDEFINED;
                                    // 16-bit poke: [15]=escaped, [6:0]=frame.
                                    // `{1'b1, 8'd0, vcsp-1}` is 17 bits; the
                                    // flag MSB was truncated so exec RET
                                    // always recycled the captured env
                                    // (PACMAN `_context` LOAD → undefined →
                                    // fillRect never interned, vdraw=0,0,0,0).
                                    if (vcsp != 8'd0)
                                        e64_p_addr2 <= {1'b1, 8'd0,
                                                        vcsp[6:0] - 7'd1};
                                    vst_wr(vsp, v64_handle(
                                    4'd7, vfn_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                    ));
                                    // Push: keep previous TOS in win[1]. Plant
                                    // win[0] alone made `this.f = (e)=>{}` a
                                    // SET_PROP on the Fn (PYTHON sloppy
                                    // no-op) so class-field arrows never
                                    // stuck (DONKEY this.startSelect).
                                    vst_push_win(v64_handle(
                                    4'd7, vfn_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                    ));
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    // Closure captured this activation's env.
                                    if (vcsp != 8'd0)
                                        vframe_escaped[vcsp - 8'd1] <= 1'b1;
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                            end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd11355;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end else begin
                        if (valloc_i < MAX_OBJ &&
                            vobj_alloc_rdata == 0) begin
                            vobj_next <= valloc_i + 14'd1;
                            if (code_rdata[7:0] == OP_NEW_OBJ) begin
                                vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd0; end
                                // Latched intern (vcall_entry), not code_rdata
                                // — HEAP between `new Game` and nested
                                // `new Item` reused Game's name.
                                vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= vcall_entry;
                                vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd0;
                                vobj_proto_pa_we <= 1'b1;
                                vobj_proto_pa_waddr <= valloc_i[12:0];
                                vobj_proto_pa_wdata <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                e64_p_addr2 <= vcall_entry;
                                // Class ctor: one c/clock (not a unique-case CAM).
                                cls_scan <= 1'b1;
                                cls_armed <= 1'b0;
                                cls_done <= 1'b0;
                                cls_hit <= 1'b0;
                                cls_ctor_mode <= 1'b1;
                                cls_c <= 4'd0;
                                cls_cls <= vcall_entry;
                                cls_ctor_q <= 16'hFFFF;
                                hs_st(S_V64_ALLOC);
                            end else begin
                                logic [63:0] handle;
                                logic [15:0] key_intern;
                                handle = v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, valloc_i[12:0]}
                                );
                                vobj_alloc_wr(valloc_i[9:0], 2'd1);
                                vom_we_cls <= 1'b1; vom_wa <= valloc_i[12:0]; vom_cls <= 16'hFFFF;
                                vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd0;
                                begin vol_we <= 1'b1; vol_wa <= valloc_i[12:0]; vol_wd <= 6'd0; end
                                vobj_proto_pa_we <= 1'b1;
                                vobj_proto_pa_waddr <= valloc_i[12:0];
                                vobj_proto_pa_wdata <= V64_UNDEFINED;
                                e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                         {52'd0, 4'd0, 2'd0, 6'd0});
                                if (valloc_proto) begin
                                    vfn_proto_pa_we <= 1'b1;
                                    vfn_proto_pa_waddr <= valloc_proto_fn;
                                    vfn_proto_pa_wdata <= handle;
                                    vst_wr(vnat_base, handle);
                                    hs_valloc_proto(1'b0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end else if (valloc_metrics) begin
                                    vmetrics <= handle;
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_valloc_metrics(1'b0);
                                    // measureText advanced before requesting
                                    // allocation; preserve the following .width.
                                    hs_code(15'(ops_base + ip));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd1);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(vmetrics_w);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd1) begin
                                    // querySelector style object
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vnat_style <= handle;
                                    hs_vnat_dom(3'd2);
                                    hs_valloc_i(valloc_i + 14'd1);
                                    valloc_rd_arm <= 1'b0;
                                end else if (vnat_dom == 3'd2) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd1;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd1, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd3);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_style;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= vnat_style;
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd640);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[2] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[2] <= v64_int32_number(32'd480);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[2] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd3) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd5;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd5, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    // Pin fillStyle@0 strokeStyle@1 so SET_PROP
                                    // writes one slot (MRDO palK).
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_fillstyle;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_strokestyle;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd4) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd2;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd2, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_height;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[1] <= v64_int32_number(32'd1);
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd5 && vmouse_active) begin
                                    vkev_event <= handle;
                                    hs_vnat_dom(3'd0);
                                    vkey_li <= 5'd0;
                                    vkey_ln <= vlistener_n;
                                    vmouse_prop <= 0;
                                    vmouse_slot <= 0;
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_st(S_V64_MOUSE_PROP);
                                end else if (vnat_dom == 3'd5) begin
                                    key_intern = (kev_q[kev_rp][7:0] == 8'd13)
                                        ? id_enter
                                        : (kev_q[kev_rp][7:0] == 8'd32)
                                        ? id_space
                                        : (kev_q[kev_rp][7:0] == 8'd37)
                                        ? id_arrow_l
                                        : (kev_q[kev_rp][7:0] == 8'd39)
                                        ? id_arrow_r
                                        : (kev_q[kev_rp][7:0] == 8'd38)
                                        ? id_arrow_u
                                        : (kev_q[kev_rp][7:0] == 8'd40)
                                        ? id_arrow_d
                                        : (kev_q[kev_rp][7:0] == 8'd65)
                                        ? id_a
                                        : (kev_q[kev_rp][7:0] == 8'd68)
                                        ? id_d
                                        : (kev_q[kev_rp][7:0] == 8'd87)
                                        ? id_w
                                        : (kev_q[kev_rp][7:0] == 8'd83)
                                        ? id_s
                                        : (kev_q[kev_rp][7:0] == 8'd80)
                                        ? id_p : 16'hFFFF;
                                    vkev_event <= handle;
                                    hs_vnat_dom(3'd0);
                                    vkey_li <= 5'd0;
                                    vkey_ln <= vlistener_n; // #60 snapshot
                                    // Seed the FRAME_KEY listener scan HERE.
                                    // Its own `state != S_V64_FRAME_KEY`
                                    // first-entry arm never runs on this path:
                                    // HEAP_WR returns with hs_st(hp_ret), so
                                    // state is already FRAME_KEY on arrival.
                                    // bind_k kept whatever the previous state
                                    // left (FRAME_TIMER counts to 64), so the
                                    // `bind_k < 16` scan was skipped and every
                                    // key event was dropped without a single
                                    // listener compare — no title responded to
                                    // Space / Enter / arrows.
                                    bind_k <= 8'd0;
                                    bind_rd_arm <= 1'b0;
                                    vk_found <= 1'b0;
                                    vk_pick <= 5'd0;
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(valloc_i[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(id_charcode!=16'hffff ? 3'd4 : 3'd3);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_type;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_handle(
                                        4'd4, 12'd0,
                                        {16'd0, kev_q[kev_rp][8]
                                            ? id_keydown : id_keyup}
                                    );
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[1] <= id_key;
                                    hs_m_hp_qk <= 1'b1;
                                    dbg_evkey <= key_intern;
                                    hp_qv_ff[1] <= (key_intern == 16'hFFFF)
                                        ? V64_UNDEFINED
                                        : v64_handle(4'd4, 12'd0,
                                                     {16'd0, key_intern});
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[1] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[2] <= id_keycode;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[2] <= v64_int32_number(
                                            {24'd0, kev_q[kev_rp][7:0]}
                                        );
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[2] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hp_qk_ff[3] <= id_charcode; hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[3] <= v64_int32_number({24'd0,kev_chars[kev_rp]}); hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[3] <= 3'd0; hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_V64_FRAME_KEY);
                                    hs_st(S_HEAP_WR);
                                end else if (vnat_dom == 3'd6) begin
                                    vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd3;
                                    e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                             {52'd0, 4'd3, 2'd0, 6'd0});
                                    vst_wr(vnat_base, handle);
                                    hs_vsp(vnat_base + 12'd1);
                                    hs_vnat_dom(3'd0);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end else begin
                                    if (valloc_regex) begin
                                        vom_we_bi <= 1'b1; vom_wa <= valloc_i[12:0]; vom_bi <= 4'd6;
                                        e64_poke(6'd44, {3'd0, valloc_i[12:0]},
                                                 {52'd0, 4'd6, 2'd0, 6'd0});
                                        hs_valloc_regex(1'b0);
                                        vst_wr(vsp, handle);
                            hs_vsp(vsp + 12'd1);
                            hs_ip(ip + 16'd1);
                                        hs_code(15'(ops_base + ip + 16'd1));
                                        hs_hp_cmd(HP_OSETI);
                                        hs_hp_oid(valloc_i[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_hp_qn(3'd1);
                                        hs_hp_qi(3'd0);
                                        hp_qk_ff[0] <= 16'd0;
                                        hs_m_hp_qk <= 1'b1;
                                        hp_qv_ff[0] <= {32'd0, valloc_regex_pack};
                                        hs_m_hp_qv <= 1'b1;
                                        hp_qt_ff[0] <= 3'd0;
                                        hs_m_hp_qt <= 1'b1;
                                        hs_hp_ret(S_FETCH_WAIT);
                                        hs_st(S_HEAP_WR);
                                    end else begin
                                    vst_wr(vsp, handle);
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                                    end
                                end
                            end
                        end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else if (!valloc_retried) begin
                            hs_vgc_clear_i(14'd0);
                            hs_vgc_qr(14'd0);
                            hs_vgc_qw(14'd0);
                            hs_vgc_halt_after(1'b0);
                            gc_ran_this_frame <= 1'b1; // C4
                            hs_st(S_V64_GC_CLEAR);
                        end else begin
                            machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd11667;
                            running <= 1'b0; hs_st(S_DONE);
                        end
                    end
                end
                S_V64_GC_CLEAR: begin
                    // Leave cycle: parent state is still EXEC. Stay in CLEAR
                    // so exec enable drops and hs_* pokes apply.
                    if (state != S_V64_GC_CLEAR)
                        hs_st(S_V64_GC_CLEAR);
                    else begin
                    if (vgc_clear_i < MAX_OBJ) begin
                        begin vmko_we <= 1'b1; vmko_wa <= vgc_clear_i[9:0]; vmko_wd <= 1'b0; end
                        begin vmkf_we <= 1'b1; vmkf_wa <= vgc_clear_i[9:0]; vmkf_wd <= 1'b0; end
                    end
                    else if (vgc_clear_i < MAX_OBJ + MAX_ARR)
                        begin vmka_we <= 1'b1; vmka_wa <= 12'(vgc_clear_i - MAX_OBJ); vmka_wd <= 1'b0; end
                    else
                        begin vmke_we <= 1'b1; vmke_wa <= 9'(vgc_clear_i - MAX_OBJ - MAX_ARR); vmke_wd <= 1'b0; end
                    if (vgc_clear_i + 14'd1 >=
                        MAX_OBJ + MAX_ARR + ENV_DEPTH) begin
                        vgc_root_i <= 12'd0;
                        vgc_root_phase <= 3'd0;
                        hs_st(S_V64_GC_ROOT);
                    end else
                        hs_vgc_clear_i(vgc_clear_i + 14'd1);
                    end
                end
                S_V64_GC_ROOT: begin
                    case (vgc_root_phase)
                        3'd0: begin
                            if (vgc_root_i < MAX_VARS) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                    if (vvar_valid_rdata)
                                        v64_gc_mark_task(vvars_rdata);
                                    vgc_root_i <= vgc_root_i + 12'd1;
                                    vgc_rd_arm <= 1'b0;
                                end
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd1;
                            end
                        end
                        3'd1: begin
                            // PYTHON marks the whole eval stack. `VST_AT` is
                            // only the TOS window — deep JSON/MAKE_ARRAY
                            // slots live in vstack BRAM.
                            if (vgc_root_i < vsp) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                    v64_gc_mark_task(vst_rdata);
                                vgc_root_i <= vgc_root_i + 12'd1;
                                    vgc_rd_arm <= 1'b0;
                                end
                            end else begin
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd2;
                            end
                        end
                        3'd2: begin
                            if (vgc_root_i == 12'd0) begin
                            v64_gc_mark_task(vthis);
                                vgc_root_i <= 12'd1;
                            end else if (vgc_root_i == 12'd1) begin
                                v64_gc_mark_task(vcall_this);
                                vgc_root_i <= 12'd2;
                            end else begin
                                v64_gc_mark_task(vcall_ctor_val);
                                vgc_root_i <= 12'd0;
                            vgc_root_phase <= 3'd3;
                            end
                        end
                        3'd3: begin
                            v64_gc_mark_task(venv);
                            vgc_root_i <= 12'd0;
                            vgc_root_phase <= 3'd4;
                        end
                        3'd4: begin
                            if ((vgc_root_i >> 2) < vcsp) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                case (vgc_root_i[1:0])
                                    2'd0: v64_gc_mark_task(
                                        vframe_this_rdata
                                    );
                                    2'd1: v64_gc_mark_task(
                                        vframe_env_rdata
                                    );
                                    2'd2: v64_gc_mark_task(
                                        vframe_fn_rdata
                                    );
                                    default: v64_gc_mark_task(
                                        vframe_ctor_rdata
                                    );
                                endcase
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd5;
                            end
                        end
                        3'd5: begin
                            if (vgc_root_i < vraf_n) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                v64_gc_mark_task(vraf_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else if (vgc_root_i < vraf_n + vraf_snap_n) begin
                                v64_gc_mark_task(
                                    vraf_snap[vgc_root_i - vraf_n]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd6;
                            end
                        end
                        3'd6: begin
                            if (vgc_root_i < 12'd64) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                if (vtimer_valid_rdata)
                                    v64_gc_mark_task(vtimer_fn_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else begin
                                vgc_root_i <= 12'd0;
                                vgc_root_phase <= 3'd7;
                            end
                        end
                        default: begin
                            if (vgc_root_i < 12'd32) begin
                                if (!vgc_rd_arm)
                                    vgc_rd_arm <= 1'b1;
                                else begin
                                if (vgc_root_i[0])
                                    v64_gc_mark_task(vlistener_fn_rdata);
                                else
                                    v64_gc_mark_task(vlistener_ev_rdata);
                                vgc_rd_arm <= 1'b0;
                                vgc_root_i <= vgc_root_i + 12'd1;
                                end
                            end else if (vgc_root_i == 12'd32) begin
                                v64_gc_mark_task(vnat_style);
                                vgc_root_i <= 12'd33;
                            end else if (vgc_root_i == 12'd33) begin
                                v64_gc_mark_task(vkev_event);
                                vgc_root_i <= 12'd34;
                            end else if (vgc_root_i == 12'd34) begin
                                v64_gc_mark_task(vfe_arr);
                                vgc_root_i <= 12'd35;
                            end else if (vgc_root_i == 12'd35) begin
                                v64_gc_mark_task(vfe_fn);
                                vgc_root_i <= 12'd36;
                            end else if (vgc_root_i == 12'd36) begin
                                v64_gc_mark_task(vmetrics);
                                vgc_root_i <= 12'd37;
                            end else if (vgc_root_i == 12'd37) begin
                                v64_gc_mark_task(vfe_map);
                                vgc_root_i <= 12'd38;
                            end else if (vgc_root_i < 12'd46) begin
                                v64_gc_mark_task(
                                    vfe_arr_s[vgc_root_i - 12'd38]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd54) begin
                                v64_gc_mark_task(
                                    vfe_fn_s[vgc_root_i - 12'd46]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd62) begin
                                v64_gc_mark_task(
                                    vfe_map_s[vgc_root_i - 12'd54]
                                );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else if (vgc_root_i < 12'd62 + 12'(JSON_STK))
                            begin
                                if ((vgc_root_i - 12'd62) < {6'd0, js_sp})
                                    v64_gc_mark_task(
                                        vjs_val[vgc_root_i - 12'd62]
                                    );
                                vgc_root_i <= vgc_root_i + 12'd1;
                            end else
                                hs_st(S_V64_GC_POP);
                        end
                    endcase
                end
                S_V64_GC_POP: begin
                    if (vgc_qr < vgc_qw) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                        vgc_cur <= {16'h7ff9, vgc_queue_rdata[16:13], 31'd0, vgc_queue_rdata[12:0]};
                        hs_vgc_qr(vgc_qr + 14'd1);
                        vgc_slot_i <= 8'd0;
                        vgc_rd_arm <= 1'b0;
                        if (vgc_queue_rdata[16:13] == V64_KIND_OBJECT ||
                            vgc_queue_rdata[16:13] == V64_KIND_ELEMENT)
                            hs_st(S_V64_GC_OBJ);
                        else if (vgc_queue_rdata[16:13] == 4'd6)
                            hs_st(S_V64_GC_ARR);
                        else if (vgc_queue_rdata[16:13] == 4'd7)
                            hs_st(S_V64_GC_FN);
                        else
                            hs_st(S_V64_GC_ENV);
                        end
                    end else begin
                        vgc_obj_i <= 13'd0;
                        hs_st(S_V64_GC_SWEEP_OBJ);
                    end
                end
                S_V64_GC_OBJ: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (vgc_slot_i < vobj_len_rdata) begin
                        v64_gc_mark_task(vobj_rdata[63:0]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == {2'b0, vobj_len_rdata})
                    begin
                        v64_gc_mark_task(vobj_proto_rdata);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                    end else
                        hs_st(S_V64_GC_POP);
                end
                S_V64_GC_ARR: begin
                    /* Streamed walk (arms held, 2-beat cadence).
                       NOTE: the 1-beat variant was tried and has a
                       pend-stall hazard — the data lag collapses during the
                       mark service and a slot's mark gets skipped (live
                       object swept). Keep 2-beat unless made stall-aware. */
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (!jn_slot_arm) begin
                        jn_slot_arm <= 1'b1;
                        vgc_arr_ph <= 1'b1;
                    end else if (!varr_may_ref_rdata) begin
                        // Two arm beats above include the registered metadata
                        // read. No slot can have held a reference in this
                        // lifetime: there is nothing to enqueue from elements.
                        jn_slot_arm <= 1'b0;
                        vgc_rd_arm <= 1'b0;
                        hs_st(S_V64_GC_POP);
                    end else if (vgc_slot_i < varr_len_rdata) begin
                        if (vgc_arr_ph)
                            vgc_arr_ph <= 1'b0;
                        else begin
                            v64_gc_mark_task(varr_rdata);
                            vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_arr_ph <= 1'b1;
                        end
                    end else begin
                        jn_slot_arm <= 1'b0;
                        vgc_rd_arm <= 1'b0;
                        hs_st(S_V64_GC_POP);
                    end
                end

                S_V64_GC_FN: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else if (vgc_slot_i == 0) begin
                        v64_gc_mark_task(vfn_env_rdata);
                        vgc_slot_i <= 8'd1;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == 1) begin
                        v64_gc_mark_task(vfn_bound_this_rdata);
                        vgc_slot_i <= 8'd2;
                        vgc_rd_arm <= 1'b0;
                    end else if (vgc_slot_i == 2) begin
                        v64_gc_mark_task(vfn_proto_rdata);
                        vgc_slot_i <= 8'd3;
                        vgc_rd_arm <= 1'b0;
                    end else
                        hs_st(S_V64_GC_POP);
                end
                S_V64_GC_ENV: begin
                    if (vgc_slot_i == 0) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(venv_parent_rdata);
                            vgc_slot_i <= 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else if (vgc_slot_i <= venv_len_rdata) begin
                        if (!vgc_rd_arm)
                            vgc_rd_arm <= 1'b1;
                        else begin
                            v64_gc_mark_task(venv_rdata[63:0]);
                        vgc_slot_i <= vgc_slot_i + 8'd1;
                            vgc_rd_arm <= 1'b0;
                        end
                    end else begin
                        vgc_rd_arm <= 1'b0;
                        hs_st(S_V64_GC_POP);
                    end
                end
                S_V64_GC_SWEEP_OBJ: begin
                    logic free_obj;
                    logic free_fn;
                    logic [11:0] new_fgen;
                    logic [11:0] new_ogen;
                    // Obj and Fn share the index space; poke 48 flags each
                    // independently so a swept object cannot clear a live fn.
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    free_obj = (vobj_alloc_rdata == 2'd1 &&
                                !vobj_mark_rdata);
                    free_fn = (vfn_valid_rdata && !vfn_mark_rdata);
                    new_fgen = (vfn_gen_rdata == 12'hfff)
                        ? 12'd1 : vfn_gen_rdata + 12'd1;
                    new_ogen = (vobj_gen_rdata == 12'hfff)
                        ? 12'd1 : vobj_gen_rdata + 12'd1;
                    if (free_obj) begin
                        vobj_alloc_wr(vgc_obj_i[9:0], 2'd0);
                        begin vol_we <= 1'b1; vol_wa <= vgc_obj_i; vol_wd <= 6'd0; end
                        begin vog_we <= 1'b1; vog_wa <= vgc_obj_i[9:0]; vog_wd <= new_ogen; end
                    end
                    if (free_fn) begin
                        begin vfv_we <= 1'b1; vfv_wa <= vgc_obj_i[9:0]; vfv_wd <= 1'b0; end
                        begin vfg_we <= 1'b1; vfg_wa <= vgc_obj_i[9:0]; vfg_wd <= new_fgen; end
                    end
                    if (free_obj || free_fn)
                        e64_poke(6'd48, {3'd0, vgc_obj_i},
                                 {20'd0, new_fgen, 30'd0, free_fn, free_obj});
                    vgc_rd_arm <= 1'b0;
                    if (vgc_obj_i + 13'd1 >= MAX_OBJ) begin
                        vgc_arr_i <= 12'd0;
                        hs_st(S_V64_GC_SWEEP_ARR);
                    end else
                        vgc_obj_i <= vgc_obj_i + 13'd1;
                    end
                end
                S_V64_GC_SWEEP_ARR: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    if (varr_valid_rdata && !varr_mark_rdata) begin
                        begin vav_we <= 1'b1; vav_wa <= vgc_arr_i[10:0]; vav_wd <= 1'b0; end
                        varr_len_wr(vgc_arr_i, 8'd0);
                        e64_poke(6'd49, {4'd0, vgc_arr_i}, 64'd0);
                        if (varr_long_rdata)
                            // #76: full-width 8-bit index into the 128-deep
                            // occupancy map - slice like every other writer.
                            begin vlu_we <= 1'b1; vlu_wa <= varr_lidx_rdata[6:0]; vlu_wd <= 1'b0; end
                        begin vlo_we <= 1'b1; vlo_wa <= vgc_arr_i[10:0]; vlo_wd <= 1'b0; end
                        begin
                            vag_we <= 1'b1; vag_wa <= vgc_arr_i;
                            vag_wd <= (varr_gen_rdata == 12'hfff)
                                ? 12'd1 : varr_gen_rdata + 12'd1;
                        end
                    end
                    vgc_rd_arm <= 1'b0;
                    if (vgc_arr_i + 12'd1 >= MAX_ARR) begin
                        vgc_env_i <= 10'd0;
                        hs_st(S_V64_GC_SWEEP_ENV);
                    end else
                        vgc_arr_i <= vgc_arr_i + 12'd1;
                    end
                end
                S_V64_GC_SWEEP_ENV: begin
                    if (!vgc_rd_arm)
                        vgc_rd_arm <= 1'b1;
                    else begin
                    if (venv_valid_rdata && !venv_mark_rdata) begin
                        begin vev_we <= 1'b1; vev_wa <= vgc_env_i[8:0]; vev_wd <= 1'b0; end
                        begin vel_we <= 1'b1; vel_wa <= vgc_env_i[8:0]; vel_wd <= 5'd0; end
                        e64_poke(6'd50, {6'd0, vgc_env_i}, 64'd0);
                        veg_we <= 1'b1; veg_wa <= vgc_env_i[8:0];
                        veg_wd <= (venv_gen_rdata == 12'hfff)
                            ? 12'd1 : venv_gen_rdata + 12'd1;
                    end
                    vgc_rd_arm <= 1'b0;
                    if (vgc_env_i + 10'd1 >= ENV_DEPTH) begin
                        // Bump cursors skip holes until MAX; rewind so the
                        // next alloc reuses swept slots (OBJ_RING leftover).
                        dbg_gc_n <= dbg_gc_n + 16'd1;
                        vobj_next <= 14'd0;
                        varr_next <= 14'd0;
                        vfn_next <= 14'd0;
                        venv_next <= 10'd0;
                        if (vgc_halt_after) begin
                            vgc_resume <= 2'd0;
                            if (vgc_wait_after) begin
                                hs_vgc_wait_after(1'b0);
                                hs_st(S_WAIT_FRAME);
                            end else begin
                                // Script-end halt: the last ops (explicit
                                // swapBuffers + POP tails) ran exec-only,
                                // so the parent ip/vsp mirrors are stale
                                // here and CHECKPOINT? hashed a leftover
                                // stack word (value64 parity tests).
                                // Absorb the exec truth before S_DONE.
                                hs_ip(e64_ip_q);
                                hs_vsp(e64_vsp_q);
                                hs_vcsp(e64_vcsp_q);
                                hs_vthis(e64_vthis_q);
                                hs_venv(e64_venv_q);
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end
                        end else begin
                            hs_valloc_retried(1'b1);
                            hs_valloc_i(14'd0);
                            // Resume re-enters S_V64_ALLOC
                            // with valloc_rd_arm still 1 from the exhausted
                            // pre-GC scan. The first scan beat then trusted
                            // *_valid_rdata whose raddr was still the sweep's
                            // vgc_env_i (casestate_q lag) — the just-freed
                            // slot, rdata 0 — and committed the new env over
                            // LIVE slot 0 (venv_next was reset to 0): len
                            // wiped, parent rewritten, gen unchanged, so all
                            // stale handles now resolved to the new occupant.
                            // PACMAN's Game closure (_stages/_index/_events)
                            // lived in e0 and died on the first mid-frame GC
                            // (black screen, frozen Date limiter). Force a
                            // fresh settle read before the scan trusts rdata.
                            valloc_rd_arm <= 1'b0;
                            if (vgc_resume == 2'd1) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_FETCH_WAIT);
                            end else if (vgc_resume == 2'd2) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_V64_JSON_PARSE);
                            end else if (vgc_resume == 2'd3) begin
                                vgc_resume <= 2'd0;
                                hs_st(S_V64_JSON);
                            end else begin
                                vgc_resume <= 2'd0;
                            hs_st(S_V64_ALLOC);
                            end
                        end
                    end else
                        vgc_env_i <= vgc_env_i + 10'd1;
                    end
                end
                S_V64_CLEAR: begin
                    // Read-only next-op prefetch is independent of the present fence.
                    // Draw/boot state and instruction retirement remain fenced below.
                    if (state == S_V64_CLEAR) hs_code(15'(ops_base + ip + 16'd1));
                    if (state != S_V64_CLEAR)
                        hs_st(S_V64_CLEAR);
                    else if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: full-screen fill through the engine
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= 10'd0;
                        rast_dy <= 10'd0;
                        rast_w <= 10'(MW);
                        rast_h <= 10'(MH);
                        rast_color <= vdraw_color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_RECT_LD: begin
                    // Same two beats per argument: transform the prefetched
                    // word on arm0; clip/commit on arm1. No extra VM cycles.
                    logic signed [31:0] raw_i, factor, translation;
                    logic signed [63:0] product;
                    logic signed [47:0] scaled, extent;
                    logic [19:0] clipped;
                    if (state != S_V64_RECT_LD) begin
                        hs_st(S_V64_RECT_LD);
                        rect_ld_arm <= 1'b0;
                        rect_ld_k <= 2'd0;
                    end else if (!rect_ld_arm) begin
                        raw_i = $signed(v64_to_int32(vst_rdata));
                        factor = rect_ld_k[0] ? e64_ctx_sy_q : e64_ctx_sx_q;
                        product = raw_i * factor;
                        rect_scaled_q <= 48'(product >>> 16);
                        rect_extent_positive_q <= raw_i > 0 && factor > 0;
                        rect_ld_arm <= 1'b1;
                        hs_st(S_V64_RECT_LD);
                    end else begin
                        translation = rect_ld_k[0] ? e64_ctx_ty_q : e64_ctx_tx_q;
                        scaled = rect_scaled_q;
                        extent = !rect_extent_positive_q ? 48'sd0 :
                                 (scaled < 1 ? 48'sd1 : scaled);
                        unique case (rect_ld_k)
                            2'd0: rect_origin_x <= scaled + 48'(translation);
                            2'd1: rect_origin_y <= scaled + 48'(translation);
                            2'd2: begin
                                clipped = rect_clip_axis(rect_origin_x,extent,10'(MW));
                                hs_vdraw_x(clipped[19:10]); hs_vdraw_w(clipped[9:0]);
                            end
                            default: begin
                                clipped = rect_clip_axis(rect_origin_y,extent,10'(MH));
                                hs_vdraw_y(clipped[19:10]); hs_vdraw_h(clipped[9:0]);
                            end
                        endcase
                        rect_ld_arm <= 1'b0;
                        if (rect_ld_k == 2'd3) begin
                            hs_vdraw_i(19'd0);
                            hs_st(S_V64_RECT);
                        end else begin
                            rect_ld_k <= rect_ld_k + 2'd1;
                            hs_st(S_V64_RECT_LD);
                        end
                    end
                end
                S_V64_RECT: begin
                    logic [19:0] total;
                    logic [9:0] px, py;
                    // Prefetch while drawing; completion still controls IP/state/stack.
                    if (state == S_V64_RECT) hs_code(15'(ops_base + ip + 16'd1));
                    if (state != S_V64_RECT) begin
                        hs_st(S_V64_RECT);
                        // Native fillRect (nid 2) latched x/y/w/h in exec.
                        // CALL_METH comes here from RECT_LD with SRAM args
                        // already in vdraw_*_ff (state is already RECT).
                        hs_vdraw_x(e64_vdraw_x_q);
                        hs_vdraw_y(e64_vdraw_y_q);
                        hs_vdraw_w(e64_vdraw_w_q);
                        hs_vdraw_h(e64_vdraw_h_q);
                    end
                    total = 20'(vdraw_w) * 20'(vdraw_h);
                    px = 10'd0; py = 10'd0; // C1: walk lives in the engine
                    if (vdraw_w == 0 || vdraw_h == 0) begin
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end else if (fence_arm && fb_present_busy) ; // present fence: HOLD ONLY.
                    // Never fold this into the !rast_wait condition: the
                    // next arm is `else if (rast_done)`, so a fenced beat
                    // would finish the op without ever issuing it and the
                    // draw vanishes (caught by the joystick gate: pixels
                    // silently missing).
                    else if (!rast_wait) begin
                        // C1: hand the clipped rect to the full-rate engine
                        // (1 px/clk instead of 1 px/beat) and block on the
                        // rise-then-fall of rast_busy.
                        if (dbg_rect_n < 7'd64) begin
                            `ifndef SYNTHESIS
                            dbg_rect[dbg_rect_n[5:0]] <=
                                {vdraw_color, vdraw_x, vdraw_y, vdraw_w, vdraw_h};
                            `endif // sim-only probe store
                            dbg_rect_n <= dbg_rect_n + 7'd1;
                        end
                        if (vdraw_color != 8'd0)
                            dbg_rect_px <= dbg_rect_px + 32'(total);
                        rast_go <= 1'b1;
                        rast_mode <= 2'd0;
                        rast_dx <= vdraw_x;
                        rast_dy <= vdraw_y;
                        rast_w <= vdraw_w;
                        rast_h <= vdraw_h;
                        rast_color <= vdraw_color;
                        rast_wait <= 1'b1;
                    end else if (rast_done) begin
                        rast_wait <= 1'b0;
                        vst_wr(vnat_base, V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_FOREACH: begin
                    // Leave cycle: parent state is still EXEC. Copy exec's
                    // CALL_METHOD plant (parent vfe_* stay UNDEF otherwise —
                    // done path hs_ip(0) re-enters until vfe_sp>=8 fault 3).
                    if (state != S_V64_FOREACH) begin
                        hs_st(S_V64_FOREACH);
                        // S_V64_GC_ROOT phase 7 marks the
                        // PARENT vfe_*_s, but the live nest stack is exec64's
                        // (vfe_s_we) and the parent copies were never written.
                        // A nested walk (INVADERS grids.forEach ->
                        // grid.invaders.forEach -> projectiles.forEach) whose
                        // inner callback triggers a mid-walk GC (ALLOC /
                        // FREE_ARR / JSON retry, vgc_halt_after=0) therefore
                        // lost the OUTER array / callback / map array: swept
                        // vfe_fn -> fault 4 on resume, swept vfe_map -> map
                        // and filter write into a recycled array. Mirror the
                        // push here: on this beat vfe_sp / vfe_arr are still
                        // the OUTER walk (exec64 saved exactly these at
                        // vfe_s_waddr = old vfe_sp), so the shadow matches
                        // slot for slot. Re-entry after a callback has
                        // e64_vfe_sp_q == vfe_sp and does not fire.
                        // Stale slots above vfe_sp are left alone on pop:
                        // between the pop and the next re-latch the shadow is
                        // the outer walk's ONLY root. Marking a stale word is
                        // conservative (v64_gc_mark_task checks tag/kind/
                        // bound/valid), never a fault.
                        if (e64_vfe_sp_q > vfe_sp && vfe_sp < 4'd8) begin
                            vfe_arr_s[vfe_sp[2:0]] <= vfe_arr;
                            vfe_fn_s[vfe_sp[2:0]]  <= vfe_fn;
                            vfe_map_s[vfe_sp[2:0]] <= vfe_map;
                        end
                        vfe_arr <= e64_vfe_arr_q;
                        vfe_fn <= e64_vfe_fn_q;
                        vfe_i <= e64_vfe_i_q;
                        vfe_ret <= e64_vfe_ret_q;
                        vfe_base <= e64_vfe_base_q;
                        vfe_mode <= e64_vfe_mode_q;
                        vfe_map <= e64_vfe_map_q;
                        vfe_sp <= e64_vfe_sp_q;
                        vfe_len <= e64_vfe_len_q;
                        // RET 0xfffc leave_hold: parent still EXEC so the
                        // EXEC !leave_hold hs_m_vcsp clear did not run.
                        // Sync exec depth (including 0) before the next
                        // EXEC opnd beat re-raises via sticky hs_m.
                        hs_vcsp(e64_vcsp_q);
                    end else if (e64_vfe_arr_q[63:48] != V64_TAG_PREFIX ||
                        e64_vfe_arr_q[47:44] != V64_KIND_ARRAY ||
                        e64_vfe_i_q >= e64_vfe_len_q) begin
                        if (!vfe_rd_arm)
                            vfe_rd_arm <= 1'b1;
                        else begin
                        vfe_rd_arm <= 1'b0;
                        vst_wr(e64_vfe_base_q,
                            e64_vfe_findidx_q ? v64_int32_number(32'hFFFFFFFF)
                            : (e64_vfe_mode_q == 2'd2 || e64_vfe_mode_q == 2'd3 ||
                             e64_vfe_reduce_q) // #39: reduce returns the acc
                            ? e64_vfe_map_q : V64_UNDEFINED);
                        hs_vsp(e64_vfe_base_q + 12'd1);
                        hs_ip(e64_vfe_ret_q);
                        hs_code(15'(ops_base + e64_vfe_ret_q));
                        // RET 0xfffc overlay can leave this callback's
                        // frame live (one_fe vret=fffc, rAF never parked).
                        // Pop only that frame: matching bsp is the ALLOC
                        // forEach slot. Nested inner done must not pop
                        // the outer callback (different base).
                        if (e64_vcsp_q != 8'd0 &&
                            vframe_rip_rdata == 16'hfffc &&
                            vframe_bsp_rdata ==
                                (e64_vfe_base_q + 12'd2))
                            hs_vcsp(e64_vcsp_q - 8'd1);
                        else
                            hs_vcsp(e64_vcsp_q);
                        if (e64_vfe_sp_q != 4'd0) begin
                            // Exec nest stack is the owner. Parent vfe_*_s
                            // is never written (CALL_METHOD saves in exec).
                            hs_m_vfe_pop <= 1'b1;
                            vfe_sp <= vfe_sp - 4'd1;
                        end else begin
                            vfe_arr <= V64_UNDEFINED;
                            vfe_fn <= V64_UNDEFINED;
                            vfe_mode <= 2'd0;
                            vfe_map <= V64_UNDEFINED;
                        end
                        hs_st(S_FETCH_WAIT);
                        end
                    end else if (e64_vfe_fn_q[63:48] != V64_TAG_PREFIX ||
                                 e64_vfe_fn_q[47:44] != V64_KIND_FUNCTION) begin
                        machine_fault <= 1'b1; fault_code <= 8'd4; fault_site <= 16'd12309;
                        running <= 1'b0; hs_st(S_DONE);
                    end else if (vcsp >= CSTK ||
                                 (!vfe_rd_arm &&
                                  vsp + 12'd4 > STACK_DEPTH) ||
                                 (vfe_rd_arm && vsp >= STACK_DEPTH)) begin
                        machine_fault <= 1'b1;
                        fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                        running <= 1'b0; hs_st(S_DONE);
                    end else begin
                        // 1W1R + TOS window only shifts ±1 per clock, and
                        // ALLOC's `VST_AT is combo on last cycle's window —
                        // idle one beat after the last push so TOS is fn.
                        if (!vfe_rd_arm) begin
                            vst_wr(vsp, e64_vfe_fn_q);
                            hs_vsp(vsp + 12'd1);
                            vfe_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            // #39 reduce: (acc, elem, i, arr) — acc first.
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? e64_vfe_map_q : varr_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd1;
                        end else if (bind_k == 8'd1) begin
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? varr_rdata
                                : v64_int32_number({24'd0, e64_vfe_i_q}));
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd2;
                        end else if (bind_k == 8'd2) begin
                            vst_wr(vsp, e64_vfe_reduce_q
                                ? v64_int32_number({24'd0, e64_vfe_i_q})
                                : e64_vfe_arr_q);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd3;
                        end else if (e64_vfe_reduce_q && bind_k == 8'd3)
                        begin
                            vst_wr(vsp, e64_vfe_arr_q);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd4;
                        end else begin
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(e64_vfe_reduce_q ? 12'd4 : 12'd3);
                            vcallback_fe <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            // Callback ALLOC writes e64-1. Exec did not +1
                            // (NEW_OBJ/CALL_USER do). Nested forEach then
                            // overwrote the live frame and never RET
                            // (INVADERS vfe_sp>=8 fault 3).
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_vsp(vsp);
                            vfe_i <= e64_vfe_i_q + 8'd1;
                            hs_m_vfe_i <= 1'b1;
                            vfe_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            hs_st(S_V64_ALLOC);
                        end
                    end
                end
                // name_rdata lags name_rdaddr 1 clock; char_id_rdata lags
                // name_rdata another. Hopping STRIDX→WR the first beat used
                // char_id[stale], so interned row[col]==="1" was never true
                // (INVADERS drawBitmap painted 0 sprite pixels). Same
                // casestate_q stay as HEAP_WAIT — extra clock, Port A, no peek.
                S_V64_STRIDX: begin
                    // name_rdata lags name_rdaddr 1 clock; char_id_rdata
                    // lags name_rdata another. One casestate stay left
                    // WR sampling char_id[stale] so row[col]==="1" never
                    // fired (INVADERS splash bars painted, sprites not).
                    if (casestate_q != S_V64_STRIDX) begin
                        stridx_rd_arm <= 1'b0;
                        hs_st(S_V64_STRIDX);
                    end else if (!stridx_rd_arm) begin
                        stridx_rd_arm <= 1'b1;
                        hs_st(S_V64_STRIDX);
                    end else begin
                        stridx_rd_arm <= 1'b0;
                        str_byte_q <= name_rdata;
                        hs_st(S_V64_STRIDX_WR);
                    end
                end
                S_V64_STRIDX_WR: begin
                    // Cached hits and numeric strByte retain their existing
                    // retirement beat. A missing singleton is a valid string,
                    // not undefined; allocate through the existing name ports.
                    if (stridx_alloc_pending) begin
                        logic [63:0] ch;
                        ch = v64_handle(4'd4,12'd0,{22'd0,stridx_alloc_id});
                        vst_wr(vsp-12'd1,ch); vst_win[0] <= ch;
                        stridx_alloc_pending <= 1'b0;
                        hs_code(15'(ops_base+ip)); hs_st(S_FETCH_WAIT);
                    end else if (hp_nat == 4'd15 || e32_char_ok_rdata) begin
                        logic [63:0] ch;
                        ch = hp_nat == 4'd15 ? v64_int32_number({24'd0,str_byte_q}) :
                            v64_handle(4'd4,12'd0,{16'd0,e32_char_id_rdata});
                        vst_wr(vsp-12'd1,ch); vst_win[0] <= ch;
                        hs_code(15'(ops_base+ip)); hs_st(S_FETCH_WAIT);
                    end else if (names_n < 16'd1024 && nb_wp < 16'(NAME_CAP)) begin
                        // Preflight both capacities before publishing any data.
                        name_hash_wr(names_n[9:0],{8'd0,str_byte_q});
                        nlt_we <= 1'b1; nlt_wa <= names_n[9:0]; nlt_wd <= 8'd1;
                        nof_we <= 1'b1; nof_wa <= names_n[9:0]; nof_wd <= nb_wp;
                        e64_poke(6'd17,{6'd0,names_n[9:0]},
                                 {32'd0,nb_wp,16'd1});
                        name_we <= 1'b1; name_waddr <= nb_wp[14:0];
                        name_wdata <= str_byte_q;
                        char_id[str_byte_q] <= names_n;
                        char_ok[str_byte_q] <= 1'b1;
                        stridx_alloc_id <= names_n[9:0];
                        stridx_alloc_pending <= 1'b1;
                        names_n <= names_n+16'd1; nb_wp <= nb_wp+16'd1;
                        hs_st(S_V64_STRIDX_WR);
                    end else begin
                        machine_fault <= 1'b1; fault_code <= 8'd3;
                        fault_site <= 16'd12960;
                        running <= 1'b0; hs_st(S_DONE);
                    end
                end
                S_V64_BYTESTRING: begin
                    if(state != S_V64_BYTESTRING) begin
                        hs_st(S_V64_BYTESTRING);bs_phase<=e64_hp_slot_q==1?24:0;
                        bs_arena_mode<=e64_hp_slot_q==1;bs_checked<=e64_hp_aslot_q==1;bs_pending<=0;bs_arena_base<=e64_hp_wval_q[18:0];bs_byte<=0;
                        bs_outer<=e64_hp_aid_q;bs_generation<=e64_hp_wval_q[43:32];
                        hs_hp_aid(e64_hp_aid_q);hs_hp_aslot(0);
                        hs_vnat_base(e64_vnat_base_q);hs_ip(e64_ip_q);
                        bs_len<=e64_hp_slot_q==1?e64_hp_wval_q[47:32]:0;bs_hash<=0;bs_page<=0;bs_scan<=0;
                    end else begin
                        case(bs_phase)
                        0: bs_phase<=1;
                        1: begin
                            if(!varr_valid_rdata || varr_gen_rdata!=bs_generation) begin
                                machine_fault<=1;fault_code<=4;fault_site<=15101;running<=0;hs_st(S_DONE);
                            end else begin bs_pages<=varr_len_rdata;bs_phase<=2;end
                        end
                        2: begin
                            if(bs_page>=bs_pages)begin bs_scan<=0;bs_phase<=12;end
                            else begin hs_hp_aid(bs_outer);hs_hp_aslot(bs_page[6:0]);bs_phase<=3;end
                        end
                        3: bs_phase<=4; // Metadata changes the short/long element address.
                        4: bs_phase<=5;
                        5: begin
                            if(varr_rdata[63:48]!=V64_TAG_PREFIX || varr_rdata[47:44]!=V64_KIND_ARRAY || varr_rdata[31:0]>=MAX_ARR)begin
                                machine_fault<=1;fault_code<=4;fault_site<=15102;running<=0;hs_st(S_DONE);
                            end else begin hs_hp_aid(varr_rdata[11:0]);hs_hp_aslot(0);bs_generation<=varr_rdata[43:32];bs_phase<=6;end
                        end
                        6: bs_phase<=7;
                        7: begin
                            if(!varr_valid_rdata || varr_gen_rdata!=bs_generation)begin
                                machine_fault<=1;fault_code<=4;fault_site<=15103;running<=0;hs_st(S_DONE);
                            end else begin bs_bytes<=varr_len_rdata;bs_byte<=0;bs_phase<=8;end
                        end
                        8: begin
                            if(bs_byte>=bs_bytes)begin bs_page<=bs_page+1;bs_phase<=2;end
                            else begin hs_hp_aslot(bs_byte[6:0]);bs_phase<=9;end
                        end
                        9: bs_phase<=10;
                        10: begin
                            logic [31:0] bv;
                            bv=v64_to_int32(varr_rdata);
                            if(!v64_is_number(varr_rdata) || bv>255 || !v64_equal(varr_rdata,v64_int32_number(bv)))begin
                                machine_fault<=1;fault_code<=4;fault_site<=15104;running<=0;hs_st(S_DONE);
                            end else if({1'b0,nb_wp}+{1'b0,bs_len}>=17'(NAME_CAP))begin
                                machine_fault<=1;fault_code<=3;fault_site<=15105;running<=0;hs_st(S_DONE);
                            end else begin
                                name_we<=1;name_waddr<=15'(nb_wp+bs_len);name_wdata<=bv[7:0];
                                bs_hash<=16'(bs_hash*16'd31+{8'd0,bv[7:0]});bs_len<=bs_len+1;
                                bs_byte<=bs_byte+1;bs_phase<=8;
                            end
                        end
                        12: bs_phase<=13;
                        13: begin
                            if(bs_scan>=names_n)begin bs_phase<=21;end
                            else if(name_hash_rdata==bs_hash && name_blen_rdata==bs_len)begin
                                bs_cmp<=0;bs_off<=name_off_rdata;bs_phase<=14;
                            end else begin bs_scan<=bs_scan+1;bs_phase<=12;end
                        end
                        14: begin
                            if(bs_cmp>=bs_len)begin bs_phase<=23;end
                            else begin name_rdaddr<=bs_off+bs_cmp;bs_phase<=bs_arena_mode?25:15;end
                        end
                        15: bs_phase<=16;
                        16: begin bs_compare_byte<=name_rdata;name_rdaddr<=nb_wp+bs_cmp;bs_phase<=17;end
                        17: bs_phase<=18;
                        18: begin
                            if(name_rdata!=bs_compare_byte)begin bs_scan<=bs_scan+1;bs_phase<=12;end
                            else begin bs_cmp<=bs_cmp+1;bs_phase<=14;end
                        end
                        21,29: begin
                            if(bs_arena_mode && bs_phase==21)begin
                                if(names_n>=1024 || {1'b0,nb_wp}+{1'b0,bs_len}>17'(NAME_CAP))begin
                                    if(bs_checked)bs_phase<=30;
                                    else begin machine_fault<=1;fault_code<=3;fault_site<=15106;running<=0;hs_st(S_DONE);end
                                end else begin bs_byte<=0;bs_phase<=28;end
                            end else if(names_n>=1024)begin machine_fault<=1;fault_code<=3;fault_site<=15106;running<=0;hs_st(S_DONE);end
                            else begin
                                bs_scan<=names_n;
                                name_hash_wr(names_n[9:0],bs_hash);
                                nlt_we<=1;nlt_wa<=names_n[9:0];nlt_wd<=bs_len[7:0];
                                nbl_we<=1;nbl_wa<=names_n[9:0];nbl_wd<=bs_len;
                                nof_we<=1;nof_wa<=names_n[9:0];nof_wd<=nb_wp;
                                e64_poke(6'd17,{6'd0,names_n[9:0]},{32'd0,nb_wp,bs_len});
                                if(bs_len==1)begin char_id[bs_hash[7:0]]<=names_n;char_ok[bs_hash[7:0]]<=1;end
                                names_n<=names_n+1;nb_wp<=nb_wp+bs_len;bs_phase<=23;
                            end
                        end
                        // Hash and compare before allocation. Existing interned values
                        // remain available even when no free name bytes/IDs remain.
                        24: begin
                            if(bs_byte>=bs_len)begin bs_scan<=0;bs_phase<=12;end
                            else if(!bs_pending)begin
                                sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(bs_arena_base)+21'(bs_byte));bs_pending<=1;
                            end else if(sram_ack)begin
                                sram_req<=0;sram_we<=0;bs_pending<=0;
                                bs_hash<=16'(bs_hash*16'd31+{8'd0,sram_rdata[7:0]});bs_byte<=bs_byte+1;
                            end
                        end
                        25: bs_phase<=26;
                        26: begin bs_compare_byte<=name_rdata;bs_phase<=27;end
                        27: begin
                            if(!bs_pending)begin
                                sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(bs_arena_base)+21'(bs_cmp));bs_pending<=1;
                            end else if(sram_ack)begin
                                sram_req<=0;sram_we<=0;bs_pending<=0;
                                if(sram_rdata[7:0]!=bs_compare_byte)begin bs_scan<=bs_scan+1;bs_phase<=12;end
                                else begin bs_cmp<=bs_cmp+1;bs_phase<=14;end
                            end
                        end
                        28: begin
                            if(bs_byte>=bs_len)bs_phase<=29;
                            else if(!bs_pending)begin
                                sram_req<=1;sram_we<=0;sram_addr<=cstg_word(21'(bs_arena_base)+21'(bs_byte));bs_pending<=1;
                            end else if(sram_ack)begin
                                sram_req<=0;sram_we<=0;bs_pending<=0;
                                name_we<=1;name_waddr<=15'(nb_wp+bs_byte);name_wdata<=sram_rdata[7:0];bs_byte<=bs_byte+1;
                            end
                        end
                        30: begin
                            vst_wr(vnat_base,V64_UNDEFINED);hs_vsp(vnat_base+1);hs_ip(ip+1);hs_code(15'(ops_base+ip+1));hs_st(S_FETCH_WAIT);
                        end
                        23: begin
                            vst_wr(vnat_base,v64_handle(V64_KIND_STRING,12'd0,{16'd0,bs_scan}));
                            hs_vsp(vnat_base+1);hs_ip(ip+1);hs_code(15'(ops_base+ip+1));hs_st(S_FETCH_WAIT);
                        end
                        default: begin machine_fault<=1;fault_code<=9;fault_site<=15107;running<=0;hs_st(S_DONE);end
                        endcase
                    end
                end
                S_V64_JSON: begin
                    // V1 JSON-engine removal: the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5; fault_site <= 16'd12422;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_V64_JSON_PARSE: begin
                    // V1 JSON-engine removal: the wall keeps
                    // compiled programs out; a stale .JSB that still carries
                    // natives 23/24 lands here and faults LOUDLY. The whole
                    // parse/stringify datapath (js_* stacks, vjs_val,
                    // json_digs walkers ~18k LUTs) is writerless now and
                    // sweeps; json_mem + json_rp/wp/putc STAY (REPL/IDXSTR/
                    // TXT dynstr pool — shared, kept features).
                    machine_fault <= 1'b1;
                    fault_code <= 8'd5; fault_site <= 16'd12435;
                    running <= 1'b0;
                    hs_st(S_DONE);
                end
                S_V64_CTOR_PAD: begin
                    // PYTHON _value64_entry_nparam: count leading LET_VAR
                    // (a1 bit0) then bind_argv (pad undefined / drop extras).
                    // vcall_entry mux is e64_q here (hs_m cleared). NEW_OBJ
                    // never clocks entry in exec — use ff (kind 3 latched).
                    if (!vctor_armed) begin
                        vctor_armed <= 1'b1;
                        // Refetch ctor+scan so stop-on-JUMP is not stale
                        // NEW_OBJ code_rdata (0-param startSelect skip).
                        hs_code(15'(ops_base + vcall_entry_ff +
                            {10'd0, vctor_scan}));
                    end
                    else if (code_rdata[7:0] == OP_LET_VAR &&
                             code_rdata[24] && vctor_scan < 6'd63) begin
                        vctor_scan <= vctor_scan + 6'd1;
                        vctor_armed <= 1'b0;
                        hs_code(15'(ops_base + vcall_entry_ff +
                            {10'd0, vctor_scan} + 16'd1));
                    end else begin
                        logic [11:0] base_sp;
                        logic [7:0] nparam;
                        logic is_fj;
                        nparam = {2'd0, vctor_scan};
                        is_fj = (code_rdata[7:0] == OP_JUMP);
                        base_sp = vsp - vcall_argc;
                        bind_mode <= 2'd0;
                        bind_k <= 8'd0;
                        bind_n <= nparam;
                        bind_argc <= vcall_argc[7:0];
                        bind_base <= base_sp;
                        bind_src <= vsp - vcall_argc;
                        bind_vsp_next <= base_sp + nparam;
                        // 0-param ctor: first op is JUMP to field inits.
                        // nparam>0: LET_VARs then that JUMP — HEAP_WR uses
                        // vctor_jmp after the last param (DONKEY startSelect).
                        vctor_jmp <= is_fj ? code_rdata[23:8] : 16'hFFFF;
                        vctor_lets <= vctor_scan;
                        bind_ip <= vcall_entry_ff;
                        bind_ret <= S_FETCH_WAIT;
                        bind_rd_arm <= 1'b0;
                        vctor_armed <= 1'b0;
                        hs_st(S_V64_BIND);
                        // CALL_USER ALLOC already hs_vcsp. Re-arm so
                        // FETCH_WAIT after BIND copies vcsp_ff into exec
                        // (RET_VAL was seeing exec vcsp=0 → fault 2).
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
                    end
                end
                S_V64_CTOR_ENV: begin
                    // NEW_OBJ after sequential env lookup (hp_rval / vcall_entry).
                    if (!tfn_rd_arm)
                        tfn_rd_arm <= 1'b1;
                    else begin
                        logic [15:0] ctor_ip;
                        logic [63:0] handle, ctor_fn;
                        logic [11:0] argc;
                        logic ctor_fn_ok;
                        ctor_ip = vcall_entry_ff;
                        argc = vcall_argc;
                        handle = v64_handle(
                            4'd5, vobj_gen_rdata,
                            {19'd0, valloc_i[12:0]}
                        );
                        ctor_fn = hp_rval;
                        ctor_fn_ok = (ctor_fn[63:48] == V64_TAG_PREFIX &&
                            ctor_fn[47:44] == V64_KIND_FUNCTION &&
                            ctor_fn[31:0] < MAX_OBJ &&
                            vfn_valid_rdata &&
                            vfn_gen_rdata == ctor_fn[43:32]);
                        hs_hp_env(1'b0);
                        tfn_rd_arm <= 1'b0;
                        if (ctor_fn_ok) begin
                            vobj_proto_pa_we <= 1'b1;
                            vobj_proto_pa_waddr <= valloc_i[12:0];
                            vobj_proto_pa_wdata <= vfn_proto_rdata;
                        end
                        if (ctor_ip != 16'hFFFF) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2; fault_site <= 16'd12519;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end
                        end else if (ctor_fn_ok) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2; fault_site <= 16'd12537;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                bind_k <= (argc == 0) ? 8'd0
                                    : (argc - 8'd1);
                                bind_n <= argc;
                                bind_argc <= argc;
                                bind_base <= vsp - argc;
                                bind_src <= vsp - argc;
                                bind_ins <= ctor_fn;
                                intern_ctor_hold <= 1'b1;
                                intern_ctor_entry <= vfn_entry_rdata;
                                intern_ctor_nparam <= vfn_nparam_rdata;
                                intern_ctor_flags <= vfn_flags_rdata;
                                intern_ctor_env <= vfn_env_rdata;
                                bind_vsp_next <= vsp + 12'd1;
                                bind_ret <= S_V64_ALLOC;
                                bind_rd_arm <= 1'b0;
                                hs_vcall_value(1'b1);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_BIND);
                            end
                        end else begin
                            vst_wr(vsp - argc, handle);
                            hs_vsp(vsp - argc + 12'd1);
                            if (e64_vcsp_q != 8'd0)
                                hs_vcsp(e64_vcsp_q - 8'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_V64_CTOR_VARS: begin
                    // NEW_OBJ varmap after registered vvars_rdata (S_RD beat).
                    if (!tfn_rd_arm)
                        tfn_rd_arm <= 1'b1;
                    else begin
                        logic [15:0] ctor_ip;
                        logic [63:0] handle, ctor_fn;
                        logic [11:0] argc;
                        logic ctor_fn_ok;
                        ctor_ip = vcall_entry_ff;
                        argc = vcall_argc;
                        handle = v64_handle(
                            4'd5, vobj_gen_rdata,
                            {19'd0, valloc_i[12:0]}
                        );
                        ctor_fn = vvar_valid_rdata
                            ? vvars_rdata : V64_UNDEFINED;
                        ctor_fn_ok = (ctor_fn[63:48] == V64_TAG_PREFIX &&
                            ctor_fn[47:44] == V64_KIND_FUNCTION &&
                            ctor_fn[31:0] < MAX_OBJ &&
                            vfn_valid_rdata &&
                            vfn_gen_rdata == ctor_fn[43:32]);
                        tfn_rd_arm <= 1'b0;
                        if (ctor_fn_ok) begin
                            vobj_proto_pa_we <= 1'b1;
                            vobj_proto_pa_waddr <= valloc_i[12:0];
                            vobj_proto_pa_wdata <= vfn_proto_rdata;
                        end
                        if (ctor_ip != 16'hFFFF) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2; fault_site <= 16'd12609;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(ctor_ip);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end
                        end else if (ctor_fn_ok) begin
                            if (vcsp >= CSTK) begin
                                machine_fault <= 1'b1;
                                fault_code <= 8'd2; fault_site <= 16'd12627;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end else begin
                                bind_mode <= (argc == 0) ? 2'd3 : 2'd2;
                                bind_k <= (argc == 0) ? 8'd0
                                    : (argc - 8'd1);
                                bind_n <= argc;
                                bind_argc <= argc;
                                bind_base <= vsp - argc;
                                bind_src <= vsp - argc;
                                bind_ins <= ctor_fn;
                                intern_ctor_hold <= 1'b1;
                                intern_ctor_entry <= vfn_entry_rdata;
                                intern_ctor_nparam <= vfn_nparam_rdata;
                                intern_ctor_flags <= vfn_flags_rdata;
                                intern_ctor_env <= vfn_env_rdata;
                                bind_vsp_next <= vsp + 12'd1;
                                bind_ret <= S_V64_ALLOC;
                                bind_rd_arm <= 1'b0;
                                hs_vcall_value(1'b1);
                                hs_vcall_argc(argc);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(handle);
                                hs_vcall_ctor_val(handle);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_BIND);
                            end
                        end else begin
                            vst_wr(vsp - argc, handle);
                            hs_vsp(vsp - argc + 12'd1);
                            if (e64_vcsp_q != 8'd0)
                                hs_vcsp(e64_vcsp_q - 8'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end
                end
                S_HEAP_WAIT: begin
                    // flatten: beat 0 muxes varr_long[hp_aid]; beat 1 slot raddr
                    // from long_rdata; HEAP_CMP sees varr_rdata.
                    // casestate_q SRAM mux (Agent 1 UG901): raddr is the flop,
                    // not combo casestate. Wait until q==WAIT so *_rdata is
                    // this HEAP, not leftover EXEC/ALLOC (intern NEW_OBJ Game
                    // re-issue hang: S_EXEC ip=NEW_OBJ hp=5 forever).
                    hp_slot_pend <= 1'b0;
                    if (casestate_q != S_HEAP_WAIT)
                        hs_st(S_HEAP_WAIT);
                    else if (!hp_slot_arm &&
                             (hp_cmd == HP_ARRGET || hp_cmd == HP_ARRSET ||
                              hp_cmd == HP_AFILL || hp_cmd == HP_PUSH ||
                              hp_cmd == HP_UNSHIFT || hp_cmd == HP_SPLICE ||
                              hp_cmd == HP_AGETI || hp_cmd == HP_ASETI))
                        hp_slot_arm <= 1'b1;
                    else begin
                        hp_slot_arm <= 1'b0;
                        hs_st(S_HEAP_CMP);
                    end
                end
                S_HEAP_CMP: begin
                    if (hp_slot_pend)
                        hp_slot_pend <= 1'b0;
                    else if (cls_scan)
                        ; // FF class match this clock (cls_done next). Not a BRAM CAM.
                    else if (cls_done) begin
                        begin
                            logic [15:0] gip;
                            logic [15:0] mip;
                            gip = cls_gip_q;
                            mip = cls_mip_q;
                            cls_done <= 1'b0;
                            if (hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX) begin
                                if (cls_sip_q != 16'hFFFF && e64_vcsp_q < CSTK) begin
                                    setter_pending <= hp_cmd == HP_SETIDX ? 2'd2 : 2'd1;
                                    hs_vcall_value(1'b0);
                                    hs_vcall_entry(cls_sip_q);
                                    hs_vcall_argc(12'd1);
                                    hs_vcall_set_this(1'b1);
                                    hs_vcall_this(v64_handle(4'd5,vobj_gen_rdata,{19'd0,hp_oid}));
                                    hs_vcall_ctor_val(V64_UNDEFINED);
                                    hs_valloc_kind(2'd3);
                                    hs_valloc_i({4'd0,venv_next});
                                    hs_valloc_retried(1'b0);
                                    hs_vcsp(e64_vcsp_q + 8'd1);
                                    hs_st(S_V64_ALLOC);
                                end else if (cls_sip_q != 16'hFFFF) begin
                                    machine_fault<=1;fault_code<=2;fault_site<=16'd15140;running<=0;hs_st(S_DONE);
                                end else if (gip != 16'hFFFF) begin
                                    // Sloppy read-only accessor: preserve RHS, do not create an own slot.
                                    vst_wr(vsp-(hp_cmd==HP_SETIDX ? 12'd3:12'd2),hp_wval);
                                    hs_vsp(vsp-(hp_cmd==HP_SETIDX ? 12'd2:12'd1));
                                    hs_ip(ip+16'd1);hs_code(15'(ops_base+ip+16'd1));hs_st(S_FETCH_WAIT);
                                end else if (vobj_len_rdata < OBJ_SLOTS[5:0]) begin
                                    hs_hp_slot(vobj_len_rdata[4:0]);
                                    vol_we<=1;vol_wa<=hp_oid;vol_wd<=vobj_len_rdata+6'd1;
                                    e64_poke(6'd2,{3'd0,hp_oid},{58'd0,vobj_len_rdata+6'd1});
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    machine_fault<=1;fault_code<=3;fault_site<=16'd15141;running<=0;hs_st(S_DONE);
                                end
                            end else if (gip != 16'hFFFF && e64_vcsp_q >= CSTK) begin
                                machine_fault<=1;fault_code<=2;fault_site<=16'd15142;running<=0;hs_st(S_DONE);
                            end else if (gip != 16'hFFFF) begin
                                hs_vsp(vsp - (hp_cmd == HP_GETIDX ? 12'd2 : 12'd1));
                                hs_vcall_value(1'b0);
                                hs_vcall_entry(gip);
                                hs_vcall_argc(12'd0);
                                hs_vcall_set_this(1'b1);
                                hs_vcall_this(v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, hp_oid}
                                ));
                                hs_vcall_ctor_val(V64_UNDEFINED);
                                hs_valloc_kind(2'd3);
                                hs_valloc_i({4'd0, venv_next});
                                hs_valloc_retried(1'b0);
                                if (e64_vcsp_q < CSTK)
                                    hs_vcsp(e64_vcsp_q + 8'd1);
                                hs_st(S_V64_ALLOC);
                            end else if (mip != 16'hFFFF) begin
                                hs_vnat_base(vsp - (hp_cmd == HP_GETIDX ? 12'd2 : 12'd1));
                                hs_valloc_kind(2'd2);
                                hs_valloc_i(vfn_next);
                                hs_valloc_fn_entry(mip);
                                hs_valloc_bind(1'b1);
                                hs_valloc_bind_src(13'h1FFF);
                                hs_valloc_bind_this(v64_handle(
                                    4'd5, vobj_gen_rdata,
                                    {19'd0, hp_oid}
                                ));
                                hs_valloc_retried(1'b0);
                                hs_st(S_V64_ALLOC);
                            end else if (hp_proto[63:48] == V64_TAG_PREFIX &&
                                hp_proto[47:44] == V64_KIND_OBJECT &&
                                hp_proto[31:0] < MAX_OBJ) begin
                                if (!hp_proto_arm) begin
                                    hp_proto_arm <= 1'b1;
                                    hs_st(S_HEAP_WAIT);
                                end else if (vobj_alloc_rdata == 2'd1 &&
                                    vobj_gen_rdata == hp_proto[43:32]) begin
                                    hp_proto_arm <= 1'b0;
                                    hs_hp_phase(3'd1);
                                    hs_hp_oid(hp_proto[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_st(S_HEAP_WAIT);
                                end else begin
                                    hp_proto_arm <= 1'b0;
                                begin
                                    vst_wr(vsp - (hp_cmd == HP_GETIDX ? 12'd2 : 12'd1), (hp_cmd==HP_GETPROP && e64_opw[31:24]==1 && vobj_builtin_rdata!=0) ? 64'h7ff900000000cafe : V64_UNDEFINED);
                                    vst_win[0] <= V64_UNDEFINED;
                                    if (hp_cmd == HP_GETIDX) hs_vsp(vsp-12'd1);
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                                end
                            end else begin
                                // PYTHON GET_PROP miss → undefined. MAKE_OBJ
                                // proto is UNDEF, so the object-proto arm
                                // above is skipped. Without this, cls_done
                                // clears and HEAP_CMP restarts cls_scan
                                // forever (`{n:1}.missing`, PACMAN options).
                                hp_proto_arm <= 1'b0;
                                begin
                                    vst_wr(vsp - (hp_cmd == HP_GETIDX ? 12'd2 : 12'd1), (hp_cmd==HP_GETPROP && e64_opw[31:24]==1 && vobj_builtin_rdata!=0) ? 64'h7ff900000000cafe : V64_UNDEFINED);
                                    vst_win[0] <= V64_UNDEFINED;
                                    if (hp_cmd == HP_GETIDX) hs_vsp(vsp-12'd1);
                                end
                                hs_ip(ip + 16'd1);
                                hs_code(15'(ops_base + ip + 16'd1));
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end else
                    // rdata valid this cycle. Stop at len, not a 32-wide mux.
                    // Object GET/SET/LOOKFN: exec copies of alloc/gen can lag.
                    // Reject stale handles here on the parent heap (keep gen).
                    // Compare the gen latched at issue (hp_spr_w[11:0]), not
                    // TOS — the window can hold a different word (false stale).
                    if (!hp_env && hp_phase == 3'd0 &&
                        hp_slot == 5'd0 &&
                        (hp_cmd == HP_GETPROP || hp_cmd == HP_SETPROP ||
                         hp_cmd == HP_LOOKFN || hp_cmd == HP_GETIDX || hp_cmd == HP_SETIDX) &&
                        (vobj_alloc_rdata != 2'd1 ||
                         vobj_gen_rdata != hp_spr_w[11:0])) begin
                        if (hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX) begin
                            vst_wr(vsp - (hp_cmd == HP_SETIDX ? 12'd3 : 12'd2), `VST_AT(vsp - 12'd1));
                            hs_vsp(vsp - (hp_cmd == HP_SETIDX ? 12'd2 : 12'd1));
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_LOOKFN) begin
                            hs_hp_rval(V64_UNDEFINED);
                            hs_hp_hit(1'b0);
                            hs_st(hp_ret);
                        end else begin
                            vst_wr(vsp - (hp_cmd == HP_GETIDX ? 12'd2 : 12'd1), (hp_cmd==HP_GETPROP && e64_opw[31:24]==1 && vobj_builtin_rdata!=0) ? 64'h7ff900000000cafe : V64_UNDEFINED);
                            if (hp_cmd == HP_GETIDX) hs_vsp(vsp-12'd1);
                            vst_win[0] <= V64_UNDEFINED;
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else if (hp_env) begin
                        if (hp_slot < hp_len[4:0] &&
                            venv_rdata[72:64] == hp_key[8:0]) begin
                            hs_hp_hit(1'b1);
                            hs_hp_rval(venv_rdata[63:0]);
                            if (hp_cmd == HP_GETPROP) begin
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    // Drop hp_env so the next GET_PROP/SET_PROP
                                    // walks the object, not this env (`x`/`y`
                                    // after LOAD_VAR current).
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, venv_rdata[63:0]);
                                    // Push: keep previous TOS in win[1]. Plant
                                    // win[0] alone + later vsp shift turned
                                    // `this.n=n` into SET_PROP on the number
                                    // (nested ctor param; P.n never stuck).
                                    vst_push_win(venv_rdata[63:0]);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                            end else if (hp_phase == 3'd1) begin
                                // LET_VAR non-local: env hit is not a write.
                                if (!vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                            end else
                                hs_st(S_HEAP_WR);
                        end else if (hp_phase == 3'd5 ||
                                     hp_phase == 3'd6) begin
                            // Verified slot-hint first guess missed (or
                            // hint >= len): restart a FULL scan from slot
                            // 0. The hint is never trusted (#55 — inliner
                            // can rebind a name at a lower slot); it only
                            // short-circuits the common case where the
                            // key really is at its compile-time slot.
                            // Phase 6 = hinted local LET_VAR; its full
                            // scan is the normal phase-2 find-or-append.
                            hs_hp_phase(hp_phase == 3'd6 ? 3'd2 : 3'd0);
                            hs_hp_slot(5'd0);
                            hp_slot_pend <= 1'b1;
                        end else if (hp_slot + 5'd1 < hp_len[4:0]) begin
                            hp_next_slot();
                        end else begin
                            if (hp_phase != 3'd2 &&
                                venv_parent_rdata[63:48] == 16'h7ff9 &&
                                venv_parent_rdata[47:44] == 4'd9 &&
                                venv_parent_rdata[31:0] < ENV_DEPTH &&
                                venv_parent_rdata[9:0] != hp_eid) begin
                                if (!hp_proto_arm) begin
                                    hp_proto_arm <= 1'b1;
                                    hs_st(S_HEAP_WAIT);
                                end else if (venv_valid_rdata &&
                                    venv_gen_rdata ==
                                        venv_parent_rdata[43:32]) begin
                                hp_proto_arm <= 1'b0;
                                // Live parent: walk. A swept/stale parent
                                // (GC of an IIFE env still named on a
                                // closure) falls through to vvars like
                                // PYTHON globals — not ERROR_HANDLE.
                                hs_hp_eid(venv_parent_rdata[9:0]);
                                hs_hp_len({1'b0, venv_len_rdata});
                                hs_hp_slot(5'd0);
                                hs_st(S_HEAP_WAIT);
                                end else begin
                                    hp_proto_arm <= 1'b0;
                                    if (hp_cmd == HP_GETPROP) begin
                                hs_hp_hit(1'b0);
                                hs_hp_rval(vvar_valid_rdata
                                    ? vvars_rdata : V64_UNDEFINED);
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_push_win(vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                                    end else if (hp_phase == 3'd2) begin
                                if (venv_len_rdata >= 5'(ENV_SLOTS)) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3; fault_site <= 16'd12902;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    hs_hp_slot(venv_len_rdata);
                                    hs_hp_hit(1'b0);
                                    hs_st(S_HEAP_WR);
                                end
                                    end else begin
                                if (hp_phase == 3'd0 ||
                                    !vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                                    end
                                end
                            end else if (hp_cmd == HP_GETPROP) begin
                                hs_hp_hit(1'b0);
                                hs_hp_rval(vvar_valid_rdata
                                    ? vvars_rdata : V64_UNDEFINED);
                                if (hp_ret == S_V64_CTOR_ENV) begin
                                    hs_hp_env(1'b0);
                                    hs_st(S_V64_CTOR_ENV);
                                end else begin
                                    hs_hp_env(1'b0);
                                    vst_wr(vsp, vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_push_win(vvar_valid_rdata
                                        ? vvars_rdata : V64_UNDEFINED);
                                    vst_hold_win <= 1'b1;
                                    hs_vsp(vsp + 12'd1);
                                    hs_ip(ip + 16'd1);
                                    hs_code(15'(ops_base + ip + 16'd1));
                                    hs_st(S_FETCH_WAIT);
                                end
                            end else if (hp_phase == 3'd2) begin
                                if (venv_len_rdata >= 5'(ENV_SLOTS)) begin
                                    machine_fault <= 1'b1;
                                    fault_code <= 8'd3; fault_site <= 16'd12945;
                                    running <= 1'b0;
                                    hs_st(S_DONE);
                                end else begin
                                    hs_hp_slot(venv_len_rdata);
                                    hs_hp_hit(1'b0);
                                    hs_st(S_HEAP_WR);
                                end
                            end else begin
                                if (hp_phase == 3'd0 ||
                                    !vvar_valid_rdata) begin
                                    vvars_wr(hp_key[8:0], hp_wval);
                                    begin vvv_we <= 1'b1; vvv_wa <= hp_key[8:0]; vvv_wd <= 1'b1; end
                                    e64_poke(6'd12, {7'd0, hp_key[8:0]}, hp_wval);
                                end
                                hs_hp_env(1'b0);
                                hs_vsp(vsp - 12'd1);
                                ctor_after_let();
                                hs_st(S_FETCH_WAIT);
                            end
                        end
                    end else if (hp_cmd == HP_OGETI) begin
                        hs_hp_rval(vobj_rdata[63:0]);
                        hs_hp_key(vobj_rdata[79:64]);
                        // PACMAN maze-cache bug: `hp_qv[...] <=` wrote into
                        // the hs64 MUX (multi-driven; the continuous assign
                        // wins), so the walk's slot reads never landed —
                        // S_V64_OGETI_NAT consumed the EXEC copy's leftovers.
                        // putImageData worked only while those leftovers were
                        // the creation's width/height pokes; the first
                        // JSON.parse (PACMAN's per-frame NPC churn) replaced
                        // them and every later putImageData saw w/h=0 (maze
                        // vanished after frame 1). Poke hp_qv_ff + mask like
                        // every other hp_q* writer so exec absorbs it.
                        hp_qv_ff[hp_qi[1:0]] <= vobj_rdata[63:0];
                        hs_m_hp_qv <= 1'b1;
                        hp_qk_ff[hp_qi[1:0]] <= vobj_rdata[79:64];
                        hs_m_hp_qk <= 1'b1;
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hp_next_slot();
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_ARRGET || hp_cmd == HP_AGETI) begin
                        hs_hp_rval((hp_aslot < hp_alen)
                            ? varr_rdata : V64_UNDEFINED);
                        if (hp_cmd == HP_ARRGET) begin
                            begin
                                vst_wr(vsp - 12'd2, (hp_aslot < hp_alen)
                                    ? varr_rdata : V64_UNDEFINED);
                                hs_vsp(vsp - 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_ret == S_FETCH_WAIT) begin
                            // Array.pop: last slot already addressed.
                            vst_wr(vnat_base, (hp_aslot < hp_alen)
                                ? varr_rdata : V64_UNDEFINED);
                            hs_vsp(vnat_base + 12'd1);
                            hs_st(S_FETCH_WAIT);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_phase == 3'd0) begin
                            hs_hp_wval(varr_rdata);
                            hs_hp_aslot(hp_aslot + 7'd1);
                            hs_hp_phase(3'd1);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_SPLICE) begin
                        hs_hp_wval(varr_rdata);
                        hs_hp_aslot(hp_aslot - hp_lim[6:0]);
                        hs_st(S_HEAP_AWR);
                    end else if (hp_cmd == HP_ASSIGN) begin
                        if (hp_phase == 3'd3) begin
                            if ({1'b0, hp_alen} + 9'd1 >= {1'b0, hp_lim}) begin
                                // Result already at hp_vbase-2; drop sources.
                                hs_vsp(hp_vbase - 12'd1);
                                hs_st(hp_ret);
                            end else begin
                                begin
                                    logic [63:0] nsv;
                                    logic src_ok;
                                    logic [12:0] nsi;
                                    nsv = assign_src_value;
                                    if (nsv[63:48] == V64_TAG_PREFIX &&
                                        (nsv[47:44] == V64_KIND_OBJECT ||
                                         nsv[47:44] == V64_KIND_ELEMENT) &&
                                        nsv[31:0] < MAX_OBJ) begin
                                        if (!valloc_rd_arm) begin
                                            valloc_rd_arm <= 1'b1;
                                            hs_st(S_HEAP_WAIT);
                                        end else begin
                                            src_ok = (vobj_alloc_rdata == 2'd1 &&
                                                vobj_gen_rdata == nsv[43:32]);
                                            nsi = nsv[12:0];
                                            valloc_rd_arm <= 1'b0;
                                            hs_hp_alen(hp_alen + 8'd1);
                                            if (src_ok) begin
                                                hs_hp_si(nsi);
                                                hs_hp_ss(5'd0);
                                                hs_hp_phase(3'd0);
                                                hs_st(S_HEAP_WAIT);
                                            end else
                                                hs_st(S_HEAP_WAIT);
                                        end
                                    end else begin
                                        hs_hp_alen(hp_alen + 8'd1);
                                        hs_st(S_HEAP_WAIT);
                                    end
                                end
                            end
                        end else if (hp_phase == 3'd4) begin
                            // settled TARGET-length read (see the exec
                            // Object.assign dispatch): raddr is hp_oid on
                            // non-phase-0 beats.
                            if (!valloc_rd_arm) begin
                                valloc_rd_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_tn(vobj_len_rdata[5:0]);
                                hs_hp_phase(hp_hit ? 3'd0 : 3'd3);
                                hs_st(S_HEAP_WAIT);
                            end
                        end else if (hp_phase == 3'd0) begin
                            // PACMAN ghosts/pacman invisible: this beat's
                            // vobj_len_rdata (source length) and vobj_rdata
                            // (source slot) are only correct one beat after
                            // the phase-0 raddr muxes engage. The FIRST
                            // Object.assign worked off lucky leftovers; every
                            // later one read a stale len (0-ish), decided
                            // `hp_ss >= len` immediately, and copied NOTHING
                            // — resetItems left the NPC/player items with no
                            // type/draw/update. One settle beat, same
                            // discipline as phase 3 below.
                            if (!valloc_rd_arm) begin
                                valloc_rd_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else if ({1'b0, hp_ss} >= vobj_len_rdata) begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_phase(3'd3);
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                valloc_rd_arm <= 1'b0;
                                hs_hp_key(vobj_rdata[79:64]);
                                hs_hp_wval(vobj_rdata[63:0]);
                                hs_hp_phase(3'd1);
                                hs_hp_slot(5'd0);
                                hs_hp_len(hp_tn);
                                hs_st(S_HEAP_WAIT);
                            end
                        end else begin
                            // phase 1: scan target for hp_key
                            if ({1'b0, hp_slot} < hp_tn &&
                                vobj_rdata[79:64] == hp_key) begin
                                hs_hp_phase(3'd2);
                                hs_st(S_HEAP_WR);
                            end else if ({1'b0, hp_slot} + 6'd1 < hp_tn) begin
                                hp_next_slot();
                            end else if (hp_tn < OBJ_SLOTS[5:0]) begin
                                hs_hp_slot(hp_tn[4:0]);
                                hs_hp_tn(hp_tn + 6'd1);
                                begin vol_we <= 1'b1; vol_wa <= hp_oid; vol_wd <= hp_tn + 6'd1; end
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, hp_tn + 6'd1});
                                hs_hp_phase(3'd2);
                                hs_st(S_HEAP_WR);
                            end else begin
                                // A new key cannot fit; never silently drop it.
                                machine_fault <= 1'b1;
                                fault_code <= 8'd3; fault_site <= 16'd19043;
                                running <= 1'b0;
                                hs_st(S_DONE);
                            end
                        end
                    end else if (hp_slot < vobj_len_rdata &&
                                 vobj_rdata[79:64] == hp_key) begin
                        hs_hp_hit(1'b1);
                        hs_hp_rval(vobj_rdata[63:0]);
                        if (hp_cmd == HP_GETPROP || hp_cmd == HP_GETIDX) begin
                            begin
                                vst_wr((hp_cmd == HP_GETIDX)
                                    ? (vsp - 12'd2) : (vsp - 12'd1), vobj_rdata[63:0]);
                                // Plant TOS now: hold_win can skip the vst_we
                                // window path for a cycle, and SET_PROP reads
                                // win[0] (PACMAN current.x=12, to.x stored NaN).
                                if (hp_cmd == HP_GETPROP)
                                    vst_win[0] <= vobj_rdata[63:0];
                            end
                            if (hp_cmd == HP_GETIDX)
                                hs_vsp(vsp - 12'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            hs_hp_key(vobj_rdata[79:64]);
                            hs_st(S_HEAP_WR);
                        end else if (hp_cmd == HP_LOOKFN) begin
                            // CALL_METHOD wants a function slot, not any key.
                            if ((vobj_rdata[63:48] != V64_TAG_PREFIX ||
                                  vobj_rdata[47:44] != 4'd7)) begin
                                if ({1'b0,hp_slot} + 6'd1 < vobj_len_rdata) begin
                                    hp_next_slot();
                                end else begin
                                    hs_hp_hit(1'b0);
                                    if (hp_phase == 3'd0 &&
                                        hp_proto[63:48] == V64_TAG_PREFIX &&
                                        hp_proto[47:44] == V64_KIND_OBJECT &&
                                        hp_proto[31:0] < MAX_OBJ) begin
                                        if (!hp_proto_arm) begin
                                            hp_proto_arm <= 1'b1;
                                            hs_st(S_HEAP_WAIT);
                                        end else if (vobj_alloc_rdata == 2'd1) begin
                                        hp_proto_arm <= 1'b0;
                                        hs_hp_phase(3'd1);
                                        hs_hp_oid(hp_proto[12:0]);
                                        hs_hp_slot(5'd0);
                                        hs_st(S_HEAP_WAIT);
                                        end else begin
                                            hp_proto_arm <= 1'b0;
                                            hs_hp_rval(V64_UNDEFINED);
                                            hs_st(hp_ret);
                                        end
                                    end else begin
                                        hs_hp_rval(V64_UNDEFINED);
                                        hs_st(hp_ret);
                                    end
                                end
                            end else begin
                                hs_hp_rval(vobj_rdata[63:0]);
                                hs_st(hp_ret);
                            end
                        end else if (hp_cmd == HP_OGETI)
                            hs_st(hp_ret);
                        else
                            hs_st(hp_ret);
                    end else if ({1'b0,hp_slot} + 6'd1 < vobj_len_rdata) begin
                        hp_next_slot();
                    end else begin
                        hs_hp_hit(1'b0);
                        if ((hp_cmd == HP_GETPROP || hp_cmd == HP_GETIDX || ((hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX) && vobj_cls_rdata != 16'hFFFF)) && hp_phase == 3'd0) begin
                            // Class getter/method: one (c,m) per clock.
                            cls_scan <= 1'b1;
                            cls_armed <= 1'b0;
                            cls_done <= 1'b0;
                            cls_ctor_mode <= 1'b0;
                            cls_c <= 4'd0;
                            cls_m <= 4'd0;
                            cls_cls <= vobj_cls_rdata;
                            cls_key <= {1'b0, hp_key[14:0]};
                            cls_mip_q <= 16'hFFFF;
                            cls_gip_q <= 16'hFFFF;
                            cls_sip_q <= 16'hFFFF;
                            // Stay HEAP_CMP: cls_scan match is FFs this clock.
                        end else if (hp_cmd == HP_LOOKFN && hp_phase == 3'd0 &&
                            hp_proto[63:48] == V64_TAG_PREFIX &&
                            hp_proto[47:44] == V64_KIND_OBJECT &&
                            hp_proto[31:0] < MAX_OBJ) begin
                            if (!hp_proto_arm) begin
                                hp_proto_arm <= 1'b1;
                                hs_st(S_HEAP_WAIT);
                            end else if (vobj_alloc_rdata == 2'd1) begin
                                hp_proto_arm <= 1'b0;
                                hs_hp_phase(3'd1);
                                hs_hp_oid(hp_proto[12:0]);
                                hs_hp_slot(5'd0);
                                hs_st(S_HEAP_WAIT);
                            end else begin
                                hp_proto_arm <= 1'b0;
                                hs_hp_rval(V64_UNDEFINED);
                                hs_hp_hit(1'b0);
                                hs_st(hp_ret);
                            end
                        end else if ((hp_cmd == HP_SETPROP ||
                                      hp_cmd == HP_SETIDX) &&
                                     vobj_len_rdata < OBJ_SLOTS[5:0]) begin
                            hs_hp_slot(vobj_len_rdata[4:0]);
                            begin vol_we <= 1'b1; vol_wa <= hp_oid; vol_wd <= vobj_len_rdata + 6'd1; end
                            e64_poke(6'd2, {3'd0, hp_oid},
                                     {58'd0, vobj_len_rdata + 6'd1});
                            hs_st(S_HEAP_WR);
                        end else if (hp_cmd == HP_SETPROP ||
                                     hp_cmd == HP_SETIDX) begin
                            machine_fault <= 1'b1; fault_code <= 8'd3; fault_site <= 16'd13277;
                            running <= 1'b0; hs_st(S_DONE);
                        end else if (hp_cmd == HP_GETIDX) begin
                            begin
                                vst_wr(vsp - 12'd2, V64_UNDEFINED);
                                hs_vsp(vsp - 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else if (hp_cmd == HP_GETPROP) begin
                            begin
                                vst_wr(vsp - 12'd1, V64_UNDEFINED);
                                vst_win[0] <= V64_UNDEFINED;
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_hp_rval(V64_UNDEFINED);
                            hs_hp_hit(1'b0);
                            hs_st(hp_ret);
                        end
                    end
                end
                S_HEAP_WR: begin
                    // Direct exec HP_OSETI requests first arrive via casestate
                    // while state is still EXEC. The RAM write enable uses
                    // actual state, so pin WR before retiring this transaction.
                    if (state != S_HEAP_WR && hp_cmd == HP_OSETI) begin
                        hs_st(S_HEAP_WR);
                    end else if (hp_env) begin
                        if (!hp_hit) begin
                            begin vel_we <= 1'b1; vel_wa <= hp_eid[8:0]; vel_wd <= venv_len_rdata + 5'd1; end
                            e64_poke(6'd10, {6'd0, hp_eid},
                                     {59'd0, venv_len_rdata + 5'd1});
                        end
                        hs_vsp(vsp - 12'd1);
                        ctor_after_let();
                        hs_hp_env(1'b0);
                        hs_st(S_FETCH_WAIT);
                    end else if (hp_cmd == HP_OSETI) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hs_st(S_HEAP_WR);
                        end else begin
                            if (vobj_len_rdata < {3'd0, hp_qn} + {1'b0, hp_slot}) begin
                                begin vol_we <= 1'b1; vol_wa <= hp_oid;
                                      vol_wd <= {3'd0, hp_qn} + {1'b0, hp_slot}; end
                                e64_poke(6'd2, {3'd0, hp_oid},
                                         {58'd0, {3'd0, hp_qn} + {1'b0, hp_slot}});
                            end
                            hs_st(hp_ret);
                        end
                    end else if (hp_cmd == HP_SETPROP || hp_cmd == HP_SETIDX)
                    begin
                        // Image.src jmr:spr:N also writes width/height
                        // (phase 3→4→5). Do not combo-walk slots for that.
                        if (hp_phase == 3'd3) begin
                            hs_hp_key(id_width);
                            hs_hp_wval(v64_int32_number({16'd0, hp_spr_w}));
                            hs_hp_slot(5'd0);
                            hs_hp_len(vobj_len_rdata);
                            hs_hp_phase(3'd4);
                            hs_hp_hit(1'b0);
                            hs_st(S_HEAP_WAIT);
                        end else if (hp_phase == 3'd4) begin
                            hs_hp_key(id_height);
                            hs_hp_wval(v64_int32_number({16'd0, hp_spr_h}));
                            hs_hp_slot(5'd0);
                            hs_hp_len(vobj_len_rdata);
                            hs_hp_phase(3'd5);
                            hs_hp_hit(1'b0);
                            hs_st(S_HEAP_WAIT);
                        end else if (hp_phase == 3'd6) begin
                            // Image.onload = fn — invoke now (title img ready).
                            vst_wr(vsp - 12'd2, `VST_AT(vsp - 12'd1));
                            hs_vsp(vsp - 12'd1);
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd0);
                            hs_vcall_set_this(1'b1);
                            hs_vcall_this(v64_handle(
                                4'd5, vobj_gen_rdata, {19'd0, hp_oid}
                            ));
                            hs_vcall_ctor_val(V64_UNDEFINED);
                            hs_valloc_kind(2'd3);
                            hs_valloc_i({4'd0, venv_next});
                            hs_valloc_retried(1'b0);
                            // Do not hs_ip(ip+1) here: kind 3 ALLOC already
                            // stores return_ip=ip+1 (after SET_PROP). Doing
                            // both skipped the next op (fillStyle / fillText).
                            // onload CALL_VAL while a constructor is live.
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_st(S_V64_ALLOC);
                        end else begin
                            if (hp_cmd == HP_SETIDX) begin
                                vst_wr(vsp - 12'd3, hp_wval);
                                hs_vsp(vsp - 12'd2);
                            end else begin
                                vst_wr(vsp - 12'd2, hp_wval);
                                hs_vsp(vsp - 12'd1);
                            end
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end
                    end else if (hp_cmd == HP_ASSIGN) begin
                        hs_hp_ss(hp_ss + 5'd1);
                        // Slot31 is the last physical slot, not a wrap to0.
                        hs_hp_phase(hp_ss == 5'd31 ? 3'd3 : 3'd0);
                        hs_st(S_HEAP_WAIT);
                    end else
                        hs_st(hp_ret);
                end
                S_HEAP_AWR: begin
                    // flatten: beat 0 muxes varr_long[hp_aid]; write when
                    // hp_slot_arm (long_rdata valid). varr_we gated on arm.
                    //
                    // First-entry hs_st, same discipline
                    // as S_HEAP_WAIT above. exec enters this state DIRECTLY
                    // (ARR_SET in-bounds, RET_VAL 0xfffc map-store), and
                    // without the hs_st the parent `state` FF never became
                    // S_HEAP_AWR — so `varr_we = (state == S_HEAP_AWR &&
                    // hp_slot_arm)` never fired and the element write was
                    // SILENTLY LOST (a[1] = 7 left the slot untouched, no
                    // fault; VARRPEEK showed the literal fill intact and the
                    // set absent). The hs_st also disables exec the next
                    // beat, stopping the leave_hold re-run. Reset slot_arm so
                    // the settle beat re-reads varr_long[hp_aid] under this
                    // state's own raddr mux.
                    if (casestate_q != S_HEAP_AWR) begin
                        hs_st(S_HEAP_AWR);
                        hp_slot_arm <= 1'b0;
                    end else if (!hp_slot_arm)
                        hp_slot_arm <= 1'b1;
                    else begin
                    hp_slot_arm <= 1'b0;
                    if (hp_cmd == HP_UNSHIFT) begin
                        if (hp_aslot > 7'd1) begin
                            hs_hp_aslot(hp_aslot - 7'd2);
                            hs_hp_phase(3'd0);
                            hs_st(S_HEAP_WAIT);
                        end else begin
                            hs_hp_aslot(7'd0);
                            hs_hp_wval(hp_rval);
                            hs_hp_cmd(HP_ASETI);
                            hs_st(S_HEAP_AWR);
                        end
                    end else if (hp_cmd == HP_SPLICE) begin
                        if (hp_aslot + hp_lim[6:0] + 7'd1 < hp_alen) begin
                            hs_hp_aslot(hp_aslot + hp_lim[6:0] + 7'd1);
                            hs_st(S_HEAP_WAIT);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_PUSH) begin
                        if (hp_qi + 3'd1 < hp_qn) begin
                            hs_hp_qi(hp_qi + 3'd1);
                            hs_hp_aslot(hp_aslot + 7'd1);
                            hs_hp_wval(hp_qv[hp_qi[1:0] + 2'd1]);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(hp_ret);
                    end else if (hp_cmd == HP_ARRSET) begin
                        vst_wr(vsp - 12'd3, hp_wval);
                        hs_vsp(vsp - 12'd2);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end else
                        hs_st(hp_ret);
                    end
                end
                S_HEAP_FILL: begin
                    // Value64 stack→array: wait one clock for vst_rdata
                    // (1W1R), then write. Combo `VST_AT(hp_vbase+i) was a
                    // second port and killed ram_style=block.
                    // Wait one clock for vst_rdata.
                    //
                    // First-entry hs_st, same discipline
                    // as S_HEAP_WAIT. exec enters DIRECTLY (push / unshift /
                    // ARR_SET grow / .length grow), and without the hs_st the
                    // parent `state` never became S_HEAP_FILL: the phase beat
                    // ran on the casestate overlay while `vst_raddr` (gated
                    // on parent state) still pointed at the DEFAULT slot, so
                    // the write stored a stale stack word — a.push(7) put the
                    // RECEIVER HANDLE (or stack[0]) in the slot. Reset the
                    // phase so the raddr settle beat runs under this state.
                    if (casestate_q != S_HEAP_FILL) begin
                        hs_st(S_HEAP_FILL);
                        if (hp_from_stack)
                            hs_hp_phase(3'd0);
                    end else if (hp_from_stack && hp_phase != 3'd1) begin
                        hs_hp_phase(3'd1);
                        hs_st(S_HEAP_FILL);
                    end else if ({1'b0, hp_aslot} + 8'd1 < hp_lim) begin
                        hs_hp_aslot(hp_aslot + 7'd1);
                        hs_hp_phase(3'd0);
                        hs_st(S_HEAP_FILL);
                    end else if (hp_cmd == HP_ARRSET) begin
                        hs_hp_aslot(hp_lim[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_phase(3'd0);
                        hs_st(S_HEAP_AWR);
                    end else begin
                        // MAKE_ARRAY handle after SRAM copy — writing it first
                        // made a[0] the array itself (PACMAN ARRAY_GET fault=255).
                        if (hp_make_arr) begin
                            vst_wr(hp_vbase, hp_rval);
                            hs_hp_make_arr(1'b0);
                            hs_hp_phase(3'd0);
                            // MAKE_ARRAY of 16+ drops vsp by >=15; the TOS
                            // window only slides ±1/clock (or FF-copy if
                            // sh<16, which still misses `this` below 16
                            // elements). SET_PROP then peeks win[1] leftover
                            // instead of the receiver. PYTHON's stack is
                            // deep; refill win[1..] from BRAM. win[0] is
                            // the handle from vst_wr above.
                            // The refill
                            // gate was `hp_lim >= 16`, but the hazard is not
                            // the array's length — it is how far vsp DROPS.
                            // MAKE_ARRAY pops hp_lim and pushes 1, so the
                            // window shifts by hp_lim-1; slots at wi where
                            // wi + (hp_lim-1) >= 16 scroll in from BELOW the
                            // 16-deep window and are simply left stale (the
                            // shift loop can only copy from win[wi+sh]).
                            // `{ m: [15 numbers] }` is the smallest failing
                            // case: MAKE_OBJ + DUP put the object at depth
                            // 16 during the pushes, so after MAKE_ARRAY the
                            // object came back as garbage, LET_VAR stored the
                            // garbage, and the object AND array were
                            // unreachable (GC freed them: arr=0, cfg.m
                            // undefined, no fault). PACMAN's maze is exactly
                            // this shape — `{'map':[31 rows of 28]}` x12 —
                            // so the maze/beans data never existed: nothing
                            // to stroke, and empty beans read as "all eaten"
                            // (instant YOU WIN). A bare 31-row literal with
                            // nothing under it was fine, which is why the
                            // isolated probes passed.
                            // Refill iff a live slot would be stale:
                            // vsp + hp_lim > 17. Costs <=15 x2 clocks.
                            if (vsp >= 12'd2 &&
                                (13'(vsp) + 13'(hp_lim) > 13'd17)) begin
                                vst_refill_i <= 4'd1;
                                vst_refill_arm <= 1'b0;
                                vst_refill_ret <= hp_ret;
                                vst_hold_win <= 1'b1;
                                // hold_win skips the vst_we window path, so
                                // plant TOS here (handle is hp_rval).
                                vst_win[0] <= hp_rval;
                                hs_st(S_V64_WIN_FILL);
                            end else
                                hs_st(hp_ret);
                        end else begin
                            hs_hp_phase(3'd0);
                            hs_st(hp_ret);
                        end
                    end
                end
                S_FREE_OBJ: begin
                    if (!valloc_rd_arm)
                        valloc_rd_arm <= 1'b1;
                    else if (valloc_i < MAX_OBJ &&
                        vobj_alloc_rdata == 2'd0) begin
                        vfree_ok <= 1'b1;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end else if (valloc_i + 14'd1 < MAX_OBJ) begin
                        hs_valloc_i(valloc_i + 14'd1);
                        valloc_rd_arm <= 1'b0;
                    end else begin
                        vfree_ok <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end
                end
                S_FREE_ARR: begin
                    // Exec enters DIRECTLY for the
                    // filter/map result-array scan (state_n = S_FREE_ARR)
                    // with hp_ret = S_FETCH_WAIT. Without the standard
                    // first-entry guard the parent state stayed S_V64_EXEC,
                    // valloc_rd_arm was stale so the scan "completed" off a
                    // stale rdata, and the completion's hs_st(S_FETCH_WAIT)
                    // fetched from the parent's STALE code_raddr — the
                    // CALL_METH was never re-decoded: filter()/map()
                    // returned the callback fn and never ran it (INVADERS
                    // leaderboard, PACMAN filter). Seed ip/code so the
                    // FETCH_WAIT return re-decodes the SAME op.
                    if (casestate_q != S_FREE_ARR && state != S_FREE_ARR) begin
                        hs_st(S_FREE_ARR);
                        valloc_rd_arm <= 1'b0;
                        if (e64_leave_hold) begin
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                        end
                    end else if (vfree_arr_long && valloc_i < 14'(MAX_ARR_SHORT)) begin
                        hs_valloc_i(14'(MAX_ARR_SHORT));
                    end else if (!valloc_rd_arm)
                        valloc_rd_arm <= 1'b1;
                    else if (valloc_i < MAX_ARR &&
                        !varr_valid_rdata &&
                        (valloc_i < 14'(MAX_ARR_SHORT) ||
                         !vlong_used_rdata) &&
                        (!vfree_arr_long ||
                         valloc_i >= 14'(MAX_ARR_SHORT))) begin
                        vfree_ok <= 1'b1;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end else if (valloc_i + 14'd1 < MAX_ARR) begin
                        hs_valloc_i(valloc_i + 14'd1);
                        valloc_rd_arm <= 1'b0;
                    end else begin
                        vfree_ok <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        hs_st(hp_ret);
                    end
                end
                S_ARR_PROMOTE: begin
                    // Same handle; copy short SRAM into a free long phys row.
                    // First-entry latch: exec requests this state directly
                    // (arr.push / ARRAY_SET past ARR_SHORT_CAP). Without it
                    // the parent's state stayed S_V64_EXEC, so exec was
                    // re-enabled after a single beat and re-requested the
                    // promote forever — INVADERS' startGame push spun for the
                    // whole 64M frame and the game appeared to hang.
                    if (state != S_ARR_PROMOTE) begin
                        hs_st(S_ARR_PROMOTE);
                        vprom_from_exec <= 1'b1; // #57: exec-entered
                        jn_rd_arm <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                        // S_ARR_PROMOTE is NOT in the hs64 list, so every
                        // muxed scalar below reads the PARENT's ff, not
                        // exec's. An exec-requested promote therefore scanned
                        // for a free long row starting from a stale valloc_i
                        // (left over from some earlier object alloc); with
                        // that >= MAX_ARR_LONG the scan fell straight through
                        // to "no free long row" and raised fault 3 with the
                        // heap almost empty (INVADERS: obj=646 of 1024,
                        // arr=25, every *ovf counter 0). Seed the parent's
                        // copies from exec here — same shape as the
                        // S_V64_WIN_FILL seed — and leave the parent's own
                        // JSON-parse entry (which sets these itself) alone.
                        if (state == S_V64_EXEC) begin
                            hs_valloc_i(e64_valloc_i_q);
                            hs_hp_aid(e64_hp_aid_q);
                            vprom_copy <= e64_vprom_copy_q;
                        end
                    end else if (casestate_q != S_ARR_PROMOTE) begin
                        // PARENT-requested entry (JSON
                        // parse). The exec guard above tests `state !=
                        // S_ARR_PROMOTE`, which is already false here, so it
                        // never fires — and jn_rd_arm / valloc_rd_arm kept
                        // whatever the previous state left them at. The very
                        // first *_rdata was then consumed a beat early:
                        //   * stale varr_long_rdata=1 -> the promote
                        //     "completed" with NO copy and without setting
                        //     varr_long[aid], so the caller's next element
                        //     wrapped into short slot (32 & 0x1F) = 0 and
                        //     overwrote element 0;
                        //   * stale vlong_used_rdata=0 -> handed out an
                        //     already-occupied long row, aliasing two arrays
                        //     onto one physical row.
                        // Both give "length correct, early slots garbage" —
                        // PACMAN's maze data AND beans data are >32 rows, so
                        // the maze drew nothing and
                        // JSON.stringify(beans.data).indexOf(0) < 0 was true
                        // on frame 1 (instant YOU WIN). exec-requested
                        // promotes (push / ARRAY_SET) were always fine
                        // because the guard above reset these.
                        // One extra beat; Port A rules unchanged.
                        jn_rd_arm <= 1'b0;
                        valloc_rd_arm <= 1'b0;
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (varr_long_rdata) begin
                        jn_rd_arm <= 1'b0;
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        if (vprom_from_exec) begin
                            // #78 (INVADERS bunker cell 32): an exec-requested
                            // promote must NOT jump straight back to
                            // S_V64_EXEC. The direct return resumed the
                            // decoder on a STALE code_rdata and a stale
                            // eval-stack window (the first promote survived
                            // only because its window happened to be
                            // coherent): CALL_METH push re-read its receiver
                            // one slot off, arr_ok failed, and the pending
                            // push fell into the generic method path and
                            // vanished - every promote after the first lost
                            // the boundary element. Resume through the
                            // standard FETCH_WAIT path: re-arm the fetch at
                            // exec's ip and re-enter EXEC with a coherent
                            // window. The re-decoded op cannot re-promote:
                            // varr_long[aid] is 1 now, which steers push /
                            // ARRAY_SET / unshift to their normal branches.
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_st(vprom_ret_eff);
                        end
                    end else if (!vprom_copy) begin
                        if (!valloc_rd_arm)
                            valloc_rd_arm <= 1'b1;
                        else if (valloc_i < 14'(MAX_ARR_LONG) &&
                            !vlong_used_rdata) begin
                            begin vlu_we <= 1'b1; vlu_wa <= valloc_i[6:0]; vlu_wd <= 1'b1; end
                            hp_prom_phys <= valloc_i[7:0];
                            vprom_copy <= 1'b1;
                            dc_i <= 8'd0;
                            hs_hp_phase(3'd0);
                            hp_prom_wr <= 1'b0;
                            jn_rd_arm <= 1'b0;
                            valloc_rd_arm <= 1'b0;
                        end else if (valloc_i + 14'd1 < 14'(MAX_ARR_LONG)) begin
                            hs_valloc_i(valloc_i + 14'd1);
                            valloc_rd_arm <= 1'b0;
                        end else begin
                            machine_fault <= 1'b1;
                            fault_code <= 8'd3; fault_site <= 16'd13766;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end
                    end else if (!jn_rd_arm) begin
                        jn_rd_arm <= 1'b1;
                    end else if (dc_i >= varr_len_rdata) begin
                        begin vlo_we <= 1'b1; vlo_wa <= hp_aid[10:0]; vlo_wd <= 1'b1; end
                        begin vli_we <= 1'b1; vli_wa <= hp_aid[10:0]; vli_wd <= hp_prom_phys; end
                        vprom_done <= 1'b1;
                        vprom_copy <= 1'b0;
                        hp_prom_wr <= 1'b0;
                        jn_rd_arm <= 1'b0;
                        if (vprom_from_exec) begin
                            // #78 (INVADERS bunker cell 32): an exec-requested
                            // promote must NOT jump straight back to
                            // S_V64_EXEC. The direct return resumed the
                            // decoder on a STALE code_rdata and a stale
                            // eval-stack window (the first promote survived
                            // only because its window happened to be
                            // coherent): CALL_METH push re-read its receiver
                            // one slot off, arr_ok failed, and the pending
                            // push fell into the generic method path and
                            // vanished - every promote after the first lost
                            // the boundary element. Resume through the
                            // standard FETCH_WAIT path: re-arm the fetch at
                            // exec's ip and re-enter EXEC with a coherent
                            // window. The re-decoded op cannot re-promote:
                            // varr_long[aid] is 1 now, which steers push /
                            // ARRAY_SET / unshift to their normal branches.
                            hs_ip(e64_ip_q);
                            hs_code(15'(ops_base + e64_ip_q));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_st(vprom_ret_eff);
                        end
                    end else if (hp_phase == 3'd0) begin
                        hs_hp_cmd(HP_AGETI);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_alen(varr_len_rdata);
                        hs_hp_ret(S_ARR_PROMOTE);
                        hs_hp_phase(3'd1);
                        hp_prom_wr <= 1'b0;
                        hs_st(S_HEAP_WAIT);
                    end else begin
                        hs_hp_cmd(HP_ASETI);
                        hs_hp_from_stack(1'b0);
                        hs_hp_aslot(dc_i[6:0]);
                        hs_hp_wval(hp_rval);
                        hs_hp_ret(S_ARR_PROMOTE);
                        hs_hp_phase(3'd0);
                        dc_i <= dc_i + 8'd1;
                        hp_prom_wr <= 1'b1;
                        hs_st(S_HEAP_AWR);
                    end
                end
                S_V64_BIND: begin
                    if (state != S_V64_BIND) begin
                        hs_st(S_V64_BIND);
                        // IIFE CALL_VAL clocks bind_* in exec then leave_hold
                        // → BIND. ALLOC/CTOR_PAD already wrote parent bind_*
                        // (state may still be EXEC on the overlay beat —
                        // only copy exec bind_* on leave_hold, else ctor
                        // field JUMP bind_ip is wiped).
                        if (e64_leave_hold) begin
                            bind_mode <= e64_bind_mode_q;
                            bind_k <= e64_bind_k_q;
                            bind_n <= e64_bind_n_q;
                            bind_argc <= e64_bind_argc_q;
                            bind_base <= e64_bind_base_q;
                            bind_src <= e64_bind_src_q;
                            bind_vsp_next <= e64_bind_vsp_next_q;
                            bind_ip <= e64_bind_ip_q;
                            bind_ret <= st_t'(e64_bind_ret_q);
                            bind_rd_arm <= e64_bind_rd_arm_q;
                            // The exec class-method hit
                            // (CALL_METH cm_mip) sets valloc_kind_n=3 and
                            // enters BIND with bind_ret=S_V64_ALLOC. But the
                            // valloc_kind/valloc_i muxes prefer the PARENT
                            // ff whenever state==S_V64_ALLOC, and this path
                            // never poked the ff — the ALLOC then ran with
                            // whatever the last exec-initiated alloc left
                            // (junk=[] left kind=1/count=0), so the method
                            // call pushed an empty array as its "result",
                            // never entered the body, and left argc args on
                            // the stack (INVADERS bunkers[bi].hitAt: vcsp
                            // climbed on every re-issue, RET warped into
                            // top-level code, vfe hit 8 → fault 3/5298).
                            // Latch exec's alloc request like ALLOC's own
                            // first-entry does.
                            hs_valloc_kind(e64_valloc_kind_q);
                            hs_valloc_i(e64_valloc_i_q);
                            hs_valloc_retried(e64_valloc_retried_q);
                            // Every BIND completion
                            // re-pokes hs_vcsp(vcsp_ff), but parent vcsp_ff
                            // only tracks parent POKES — exec-side RETs pop
                            // the exec register and leave the ff stale-HIGH
                            // (a getter dispatch inside the previous call
                            // raised it with hs_vcsp(e64+1)). The next
                            // exec-entered BIND then re-injected the stale
                            // ff: the ALLOC commit saw ff == e64+1, treated
                            // the call as parent-reserved, wrote the frame
                            // one slot high and leaked +1 vcsp per method
                            // call (DONKEY Mario.collision per platform per
                            // frame -> fault 2 at CSTK, game froze on the
                            // first game frame). Latch exec's vcsp like the
                            // rest of this block; parent-initiated BINDs
                            // never run this arm, so their fresh reserve
                            // (FOREACH / FRAME_RAF / LOOKFN) is untouched.
                            hs_vcsp(e64_vcsp_q);
                        end
                    // bind_mode 0: dest[k]=(k<argc)?src[k]:UNDEF, k=0..n-1
                    // bind_mode 1: dest[k]=dest[k+1] (drop callee), k=0..n-1
                    // bind_mode 2: dest[k+1]=src[k] downward
                    // bind_mode 3: write bind_ins at bind_base (after mode 2)
                    end else if (bind_mode == 2'd3) begin
                        vst_wr(bind_base, bind_ins);
                        begin
                            integer fd;
                            fd = integer'(bind_n);
                            if (fd >= 0 && fd < 16)
                                vst_win[fd[3:0]] <= bind_ins;
                        end
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        hs_vsp(bind_vsp_next);
                        hs_st(bind_ret);
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
                    end else if (bind_n == 8'd0) begin
                        bind_armed <= 1'b0;
                        bind_rd_arm <= 1'b0;
                        hs_vsp(bind_vsp_next);
                        if (bind_mode != 2'd1) begin
                            hs_ip(bind_ip);
                            hs_code(15'(ops_base + bind_ip));
                        end
                        hs_st(bind_ret);
                        if (vcsp_ff != 8'd0)
                            hs_vcsp(vcsp_ff);
                    end else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                        bind_armed <= 1'b1;
                        vst_hold_win <= 1'b1;
                    end else begin
                        logic [63:0] srcv;
                        logic [11:0] dst;
                        integer fd;
                        srcv = (bind_mode == 2'd0 && bind_k >= bind_argc)
                            ? V64_UNDEFINED : vst_rdata;
                        dst = (bind_mode == 2'd2)
                            ? (bind_base + {4'd0, bind_k} + 12'd1)
                            : (bind_base + {4'd0, bind_k});
                        vst_wr(dst, srcv);
                        fd = integer'(bind_vsp_next) - 1 - integer'(dst);
                        if (fd >= 0 && fd < 16)
                            vst_win[fd[3:0]] <= srcv;
                        bind_rd_arm <= 1'b0;
                        if (bind_mode == 2'd2) begin
                            if (bind_k == 8'd0)
                                bind_mode <= 2'd3;
                            else
                                bind_k <= bind_k - 8'd1;
                        end else if (bind_k + 8'd1 >= bind_n) begin
                            bind_armed <= 1'b0;
                            hs_vsp(bind_vsp_next);
                            if (bind_mode != 2'd1) begin
                                hs_ip(bind_ip);
                                hs_code(15'(ops_base + bind_ip));
                            end
                            hs_st(bind_ret);
                            if (vcsp_ff != 8'd0)
                                hs_vcsp(vcsp_ff);
                        end else
                            bind_k <= bind_k + 8'd1;
                    end
                end
                S_FS: begin
                    if(state!=S_FS)begin hs_st(S_FS);fs_phase<=0;fs_request<=0;fs_command<=e64_hp_slot_q[2:0];end
                    else if(casestate_q!=S_FS)hs_st(S_FS);
                    else if(fs_phase<4)begin
                        // One shared integer conversion per clock, outside EXEC.
                        fs_arguments[fs_phase[1:0]*32+:32]<=v64_to_int32(fs_arg_value);
                        fs_phase<=fs_phase+1'b1;
                    end else if(fs_phase==4)begin fs_request<=1;fs_phase<=5;end
                    else if(fs_phase==5 && fs_reply_sync[1])begin
                        fs_result_q<=fs_result;fs_request<=0;fs_phase<=6;
                    end else if(fs_phase==6 && !fs_reply_sync[1])begin
                        vst_wr(vnat_base,v64_fs_number(fs_command, fs_arguments, fs_result_q));
                        hs_vsp(vnat_base+12'd1);hs_ip(ip+16'd1);hs_code(15'(ops_base+ip+16'd1));
                        if(fs_command==6 && !fs_result_q[31])begin running<=0;hs_st(S_DONE);end
                        else hs_st(S_FETCH_WAIT);
                    end
                end
                S_CSRAM: begin
                    // The compile ABI's one memory state. Modes: 0 srcByte,
                    // 1 stgRead, 2 stgWrite, 3 artWrite2 (packed pair).
                    //
                    // This is the FIRST VM-side SRAM READ in the design —
                    // every other VM transaction is a write. The core's
                    // ack-hold shim accepts it for free provided the request
                    // is held stable until sram_ack, which is why the request
                    // is issued once and then frozen behind csr_pend.
                    if (state != S_CSRAM) begin
                        hs_st(S_CSRAM);
                        csr_pend <= 1'b0;
                        csr_done <= 1'b0;
                    end else if (casestate_q != S_CSRAM) begin
                        hs_st(S_CSRAM);
                    end else if (csr_done) begin
                        // beat 2: the captured byte -> value stack (writes
                        // answer undefined; reads the low byte — every arena
                        // region is one byte per word, except CART which is
                        // written packed and never read back here).
                        csr_done <= 1'b0;
                        vst_wr(vnat_base, csr_is_write
                            ? V64_UNDEFINED
                            : v64_int32_number({24'd0, csr_rd_q}));
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end else if (!csr_pend) begin
                        if (e64_csr_oob_q) begin
                            // Out of range is -1, not a fault: the tokenizer
                            // probes past the end on every token.
                            vst_wr(vnat_base, v64_int32_number(32'hFFFFFFFF));
                            hs_vsp(vnat_base + 12'd1);
                            hs_ip(ip + 16'd1);
                            hs_code(15'(ops_base + ip + 16'd1));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            sram_req   <= 1'b1;
                            sram_we    <= csr_is_write;
                            sram_addr  <= e64_csr_addr_q;
                            sram_wdata <= e64_csr_wdata_q;
                            csr_pend   <= 1'b1;
                        end
                    end else if (sram_ack) begin
                        // beat 1: capture only (the crossing is now one
                        // register deep); the stack write happens above.
                        sram_req <= 1'b0;
                        sram_we  <= 1'b0;
                        csr_pend <= 1'b0;
                        csr_rd_q <= sram_rdata[7:0];
                        csr_done <= 1'b1;
                    end
                end
                S_V64_MINMAX: begin
                    // Exec seeds minmax_*_n on CALL_NATIVE min/max then
                    // leave_hold. Parent FFs stay 0 unless copied — result
                    // wrote vsp=1 and `48+Math.min(...)*16` ADDed underflow
                    // (INVADERS Space → new Grid startY, fault 1).
                    if (state != S_V64_MINMAX) begin
                        hs_st(S_V64_MINMAX);
                        minmax_base <= e64_minmax_base_q;
                        minmax_acc <= e64_minmax_acc_q;
                        minmax_is_min <= e64_minmax_is_min_q;
                        minmax_k <= e64_minmax_k_q;
                        minmax_n <= e64_minmax_n_q;
                        bind_rd_arm <= 1'b0;
                    end else if (casestate_q != S_V64_MINMAX)
                        hs_st(S_V64_MINMAX);
                    else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                    end else if (minmax_k >= minmax_n) begin
                        vst_wr(minmax_base, minmax_acc);
                        hs_vsp(minmax_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        bind_rd_arm <= 1'b0;
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        logic [63:0] arg;
                        arg = vst_rdata;
                        if (arg[62:52] == 11'h7ff && arg[51:0] != 0)
                            minmax_acc <= V64_CANON_NAN;
                        else if (minmax_is_min
                                 ? v64_less(arg, minmax_acc)
                                 : v64_less(minmax_acc, arg))
                            minmax_acc <= arg;
                        minmax_k <= minmax_k + 8'd1;
                        bind_rd_arm <= 1'b0;
                    end
                end
                S_V64_WIN_FILL: begin
                    // Reload vst_win[i] from vstack[vsp-1-i], one slot per
                    // two clocks (addr, then vst_rdata). Starts at i=1:
                    // win[0] already has the MAKE_ARRAY/RET_VAL handle.
                    vst_hold_win <= 1'b1;
                    // Exec RET_VAL/RETURN clocks refill_* into e64_*_q and
                    // leave_hold→WIN_FILL. Parent vst_refill_ret stays
                    // reset-IDLE unless HEAP MAKE_ARRAY wrote it — then
                    // hs_st(IDLE) after ctor `push(new Particle)` (INVADERS
                    // parks before rAF(animate); IPTRACE 85 then mux ip_ff).
                    if (vst_refill_ret == S_IDLE) begin
                        vst_refill_i <= e64_vst_refill_i_q;
                        vst_refill_arm <= e64_vst_refill_arm_q;
                        vst_refill_ret <= st_t'(e64_vst_refill_ret_q);
                        vst_hold_win <= e64_vst_hold_win_q;
                        // Exec vsp is truth. Sticky hs_m_vsp can leave
                        // parent vsp_ff at 0, so raddr underflowed and
                        // fillRect y/w from GET_PROP never saw the canvas
                        // (vdraw stayed 0). HEAP-initiated refill already
                        // has parent vsp (ret != IDLE).
                        hs_vsp(e64_vsp_q);
                        hs_st(S_V64_WIN_FILL);
                    end else if (!vst_refill_arm) begin
                        vst_refill_arm <= 1'b1;
                        hs_st(S_V64_WIN_FILL);
                    end else begin
                        vst_win[vst_refill_i] <= vst_rdata;
                        // +1 fills every live slot (ARRAY_SET needs win[2]
                        // when vsp==3). +2 skipped the handle.
                        if (vst_refill_i == 4'd15 ||
                            ({8'd0, vst_refill_i} + 12'd1 >= vsp)) begin
                            vst_hold_win <= 1'b0;
                            vst_refill_arm <= 1'b0;
                            hs_st(vst_refill_ret);
                            // So the next exec-initiated refill can seed.
                            vst_refill_ret <= S_IDLE;
                        end else begin
                            vst_refill_i <= vst_refill_i + 4'd1;
                            vst_refill_arm <= 1'b0;
                            hs_st(S_V64_WIN_FILL);
                        end
                    end
                end
                S_V64_CALLREF: begin
                    if(state!=S_V64_CALLREF) begin
                        hs_st(S_V64_CALLREF);hs_vcsp(e64_vcsp_q);callref_phase<=0;callref_pending<=0;
                    end else if(callref_phase==4) begin
                        // Commit BIND's registered RAM write while executor writes remain gated.
                        vst_refill_i<=0;vst_refill_arm<=0;vst_refill_ret<=S_V64_EXEC;hs_st(S_V64_WIN_FILL);
                    end else if(callref_phase==0) callref_phase<=1;
                    else if(callref_phase==1) begin hs_hp_rval(vst_rdata);callref_phase<=2;end
                    else if(callref_phase==2) callref_phase<=3;
                    else if(hp_rval==64'h7ff900000000cafe) begin
                        // Drop only the prepared marker. Registered shared stack reads preserve wide args.
                        bind_mode<=1;bind_k<=0;bind_n<=e64_opw[31:24];bind_argc<=e64_opw[31:24];
                        bind_base<=vsp-{4'd0,e64_opw[31:24]}-1;bind_src<=vsp-{4'd0,e64_opw[31:24]};
                        bind_vsp_next<=vsp-1;bind_ret<=S_V64_CALLREF;bind_rd_arm<=0;
                        callref_phase<=4;hs_st(S_V64_BIND);
                    end else if(e64_vcsp_q>=CSTK) begin
                        machine_fault<=1;fault_code<=2;fault_site<=15145;running<=0;hs_st(S_DONE);
                    end else begin
                        hs_hp_hit(1);callref_pending<=1;tfn_rd_arm<=0;
                        hs_vnat_base(vsp-{4'd0,e64_opw[31:24]}-1);
                        hs_vcall_argc({4'd0,e64_opw[31:24]});hs_vcall_this(vst_rdata);hs_st(S_V64_METH);
                    end
                end
                S_V64_METH: begin
                    // LOOKFN finished: own/proto function or unknown method.
                        if (!tfn_rd_arm)
                            tfn_rd_arm <= 1'b1;
                        else if (hp_hit &&
                            hp_rval[63:48] == V64_TAG_PREFIX &&
                            hp_rval[47:44] == 4'd7 &&
                            hp_rval[31:0] < MAX_OBJ &&
                            vfn_valid_rdata && (!callref_pending || vfn_gen_rdata==hp_rval[43:32])) begin
                        tfn_rd_arm <= 1'b0;
                        vst_wr(vnat_base, hp_rval);
                        // Plant TOS window this cycle: S_V64_ALLOC reads
                        // VST_AT(callee) next clock. vst_we window update is
                        // one cycle later, so ALLOC would see the receiver
                        // (vfn_entry=0 → ip=0 → maps IIFE nested).
                        begin
                            integer fd;
                            fd = integer'(vcall_argc);
                            if (fd >= 0 && fd < 16)
                                vst_win[fd[3:0]] <= hp_rval;
                        end
                        hs_vcall_value(1'b1);
                        hs_vcall_set_this(1'b1);
                        hs_vcall_ctor_val(V64_UNDEFINED);
                        hs_valloc_kind(2'd3);
                        hs_valloc_i({4'd0, venv_next});
                        hs_valloc_retried(1'b0);
                        // LOOKFN method: CALL_VAL-shaped ALLOC, not NEW_OBJ.
                        if (e64_vcsp_q < CSTK)
                            hs_vcsp(e64_vcsp_q + 8'd1);
                        hs_st(S_V64_ALLOC);
                    end else if(callref_pending) begin
                        tfn_rd_arm<=0;callref_pending<=0;machine_fault<=1;fault_code<=4;fault_site<=15146;running<=0;hs_st(S_DONE);
                    end else begin
                        tfn_rd_arm <= 1'b0;
                        vst_wr(vnat_base, (vobj_builtin_rdata == 4'd6)
                            ? v64_handle(4'd3, 12'd0, 32'd0)
                            : (vobj_builtin_rdata != 4'd0)
                            ? vcall_this : V64_UNDEFINED);
                        hs_vsp(vnat_base + 12'd1);
                        hs_ip(ip + 16'd1);
                        hs_code(15'(ops_base + ip + 16'd1));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_FE_ELEM: begin
                    // findIndex: the AGETI slot IS the matched index.
                    vst_wr(vfe_base, e64_vfe_findidx_q
                        ? v64_int32_number({25'd0, hp_aslot})
                        : hp_rval);
                    hs_vsp(vfe_base + 12'd1);
                    hs_ip(vfe_ret);
                    hs_code(15'(ops_base + vfe_ret));
                    if (vfe_sp != 4'd0) begin
                        hs_m_vfe_pop <= 1'b1;
                        vfe_sp <= vfe_sp - 4'd1;
                    end else begin
                        vfe_arr <= V64_UNDEFINED;
                        vfe_fn <= V64_UNDEFINED;
                        vfe_mode <= 2'd0;
                        vfe_map <= V64_UNDEFINED;
                    end
                    hs_st(S_FETCH_WAIT);
                end
                S_V64_FE_FILTER: begin
                    if (!vfe_rd_arm) begin
                        vfe_rd_arm <= 1'b1;
                    end else begin
                        logic [7:0] fl;
                        fl = varr_len_rdata;
                        vfe_rd_arm <= 1'b0;
                        if (fl < ARR_CAP[7:0]) begin
                            varr_len_wr(vfe_map[11:0], fl + 8'd1);
                            e64_poke(6'd6, {4'd0, vfe_map[11:0]},
                                     {56'd0, fl + 8'd1});
                            hs_hp_cmd(HP_ASETI);
                            hs_hp_from_stack(1'b0);
                            hs_hp_aid(vfe_map[11:0]);
                            hs_hp_aslot(fl[6:0]);
                            hs_hp_wval(hp_rval);
                            hs_hp_ret(S_V64_FOREACH);
                            hs_st(S_HEAP_AWR);
                        end else
                            hs_st(S_V64_FOREACH);
                    end
                end
                S_V64_IDXSCAN: begin
                    if (v64_equal(hp_rval, hp_wval)) begin
                        vst_wr(hp_vbase, v64_int32_number({24'd0, hp_aslot}));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_st(S_FETCH_WAIT);
                    end else if (hp_aslot + 7'd1 < hp_alen) begin
                        hs_hp_aslot(hp_aslot + 7'd1);
                        hs_st(S_HEAP_WAIT);
                    end else begin
                        vst_wr(hp_vbase, v64_int32_number(-32'sd1));
                        hs_vsp(hp_vbase + 12'd1);
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_OGETI_NAT: begin
                    case (hp_nat)
                        4'd0: begin
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            js_sp <= 6'd0;
                            json_pph <= 3'd0;
                            hs_st(S_V64_JSON_PARSE);
                        end
                        4'd1: begin
                            imgd_w <= v64_to_uint32(hp_qv[0])[9:0];
                            imgd_h <= v64_to_uint32(hp_qv[1])[9:0];
                            imgd_x <= 10'd0; imgd_y <= 10'd0;
                            imgd_i <= 19'd0;
                            imgd_v64 <= 1'b1;
                            // The
                            // destination corner and the return ip/base were
                            // exec FFs; the parent copies were stale (x0/y0
                            // only worked because the previous GET's guard
                            // left 0,0). S_IMGD_PUT is not in hs64, so its
                            // completion vst_wr(vnat_base)/hs_code(ops_base+ip)
                            // used the parent _ff leftovers.
                            imgd_x0 <= e64_imgd_x0_q;
                            imgd_y0 <= e64_imgd_y0_q;
                            hs_vnat_base(hp_vbase);
                            hs_ip(e64_ip_q);
                            hs_st(S_IMGD_PUT);
                        end
                        4'd2: begin
                            if (!valloc_rd_arm)
                                valloc_rd_arm <= 1'b1;
                            else begin
                            begin
                                logic [15:0] tl;
                                tl = 16'(v64_to_uint32(hp_qv[1]));
                                vmetrics_w <= text_pixel_width(tl, text_font_scale);
                                valloc_rd_arm <= 1'b0;
                                if (vmetrics[63:48] == V64_TAG_PREFIX &&
                                    vmetrics[47:44] == V64_KIND_OBJECT &&
                                    vmetrics[31:0] < MAX_OBJ &&
                                    vobj_alloc_rdata == 2'd1)
                                begin
                                    hs_hp_cmd(HP_OSETI);
                                    hs_hp_oid(vmetrics[12:0]);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd1);
                                    hs_hp_qi(3'd0);
                                    hp_qk_ff[0] <= id_width;
                                    hs_m_hp_qk <= 1'b1;
                                    hp_qv_ff[0] <= v64_int32_number(text_pixel_width(tl, text_font_scale));
                                    hs_m_hp_qv <= 1'b1;
                                    hp_qt_ff[0] <= 3'd0;
                                    hs_m_hp_qt <= 1'b1;
                                    hs_hp_ret(S_FETCH_WAIT);
                                    vst_wr(hp_vbase, vmetrics);
                                    hs_vsp(hp_vbase + 12'd1);
                                    hs_st(S_HEAP_WR);
                                end else begin
                                    hs_valloc_metrics(1'b1);
                                    hs_vnat_base(hp_vbase);
                                    hs_valloc_kind(2'd0);
                                    hs_valloc_i(vobj_next);
                                    hs_valloc_retried(1'b0);
                                    hs_st(S_V64_ALLOC);
                                end
                            end
                            end
                        end
                        4'd3: begin
                            // Dynstr indexOf: same latch as replace (4'd4) then
                            // S_IDXSTR. Do not combo-for JSON_CAP (Vivado hang).
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            // OGETI overwrites hp_key with the slot name;
                            // needle was saved in hp_wval (same as tagged S_IDXSTR).
                            idx_needle <= hp_wval[7:0];
                            // The comment above said "same latch as replace"
                            // but the latches were missing: S_IDXSTR's
                            // completion reads hp_vbase/ip via the PARENT
                            // ffs (not hs64-muxed there), which were stale —
                            // r.indexOf(...) on a dynstr wrote the result
                            // nowhere and parked the program at the CALL ip
                            // (WAIT_FRAME, LETs after never ran).
                            hs_hp_vbase(e64_hp_vbase_q);
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            hs_st(S_IDXSTR);
                        end
                        4'd4: begin
                            json_src <= 14'(v64_to_uint32(hp_qv[0]));
                            json_srclen <= 14'(v64_to_uint32(hp_qv[1]));
                            json_rp <= 14'(v64_to_uint32(hp_qv[0]));
                            json_dst <= 14'(v64_to_uint32(hp_qv[0]))
                                + 14'(v64_to_uint32(hp_qv[1]));
                            json_wp <= 14'(v64_to_uint32(hp_qv[0]))
                                + 14'(v64_to_uint32(hp_qv[1]));
                            if (hp_oid != 13'd0 &&
                                vobj_builtin_rdata == 4'd6)
                                ; // regex pack already in hp_wval
                            // Dynstr-haystack leg never passes the S_NAMCPY
                            // guard: base/ip/vsp for the completion push
                            // also only lived in EXEC's FFs (the result
                            // handle was written to slot 0 instead of the
                            // receiver slot).
                            hs_vnat_base(e64_vnat_base_q);
                            hs_ip(e64_ip_q);
                            hs_vsp(e64_vsp_q);
                            // String.replace parent latches (PACMAN ghost
                            // AI: stringify(...).replace(/2/g,0)): repl_rch
                            // only ever lived in EXEC's FFs. repl_pat0==0 means
                            // "pattern is a RegExp object" — those fields
                            // were parent-written by the nat=5 read; do not
                            // clobber them.
                            repl_rch <= e64_repl_rch_q;
                            repl_did <= 1'b0;
                            if (e64_repl_pat0_q != 8'd0) begin
                                repl_pat0 <= e64_repl_pat0_q;
                                repl_pat1 <= 8'd0;
                                repl_nlen <= 8'd1;
                                repl_g <= e64_repl_g_q;
                            end
                            hs_st(S_REPL);
                        end
                        4'd5: begin
                            begin
                                logic [31:0] preg;
                                preg = hp_qv[0][31:0];
                                repl_pat0 <= preg[7:0];
                                repl_pat1 <= preg[15:8];
                                repl_nlen <= preg[23:16];
                                repl_g <= preg[24];
                                if (hp_phase == 3'd1) begin
                                    hs_hp_nat(4'd4);
                                    hs_hp_cmd(HP_OGETI);
                                    hs_hp_oid(hp_si);
                                    hs_hp_slot(5'd0);
                                    hs_hp_qn(3'd2);
                                    hs_hp_qi(3'd0);
                                    hs_hp_ret(S_V64_OGETI_NAT);
                                    hs_st(S_HEAP_WAIT);
                                end else
                                    hs_st(S_NAMCPY);
                            end
                        end
                        default: hs_st(S_FETCH_WAIT);
                    endcase
                end
                S_UI_PROP: begin
                    if(state!=S_UI_PROP && e64_leave_hold)begin
                        hs_st(S_UI_PROP);hs_ip(e64_ip_q);hs_vsp(e64_vsp_q);
                        ui_prop_name<=e64_hp_key_q[9:0];ui_prop_menu<=e64_hp_slot_q==5;ui_prop_title<=e64_hp_slot_q==10;
                        ui_prop_phase<=1;ui_prop_i<=0;
                    end else case(ui_prop_phase)
                        1:ui_prop_phase<=2;
                        2:begin
                            ui_prop_ptr<=name_off_rdata;ui_prop_len<=name_blen_rdata;ui_prop_phase<=3;
                            if(name_blen_rdata>(ui_prop_title?24:ui_prop_menu?800:512))begin machine_fault<=1;fault_code<=5;hs_st(S_DONE);end
                        end
                        3:ui_prop_phase<=4;
                        4:begin
                            ui_text_menu_o<=ui_prop_menu;ui_text_title_o<=ui_prop_title;ui_text_first_o<=ui_prop_i==0;
                            ui_text_last_o<=ui_prop_i+1>=ui_prop_len;
                            ui_text_byte_o<=ui_prop_len==0?8'd0:name_rdata;
                            ui_text_toggle_o<=!ui_text_toggle_o;
                            if(ui_prop_i+1>=ui_prop_len)begin hs_code(15'(ops_base+ip));hs_st(S_FETCH_WAIT);end
                            else begin ui_prop_i<=ui_prop_i+1'b1;ui_prop_ptr<=ui_prop_ptr+1'b1;ui_prop_phase<=3;end
                        end
                        default:ui_prop_phase<=1;
                    endcase
                end
                S_V64_MOUSE_PROP: begin
                    logic [15:0] prop_id;
                    logic [63:0] prop_value;
                    logic [31:0] prop_integer;
                    prop_id = 16'hffff;
                    prop_value = V64_UNDEFINED;prop_integer=0;
                    case (vmouse_prop)
                        0: begin prop_id = id_type; prop_value = v64_handle(4'd4,12'd0,{16'd0,vmouse_type_id}); end
                        1: begin prop_id = id_clientX; prop_integer = {22'd0,vmouse_packet[45:36]}; end
                        2: begin prop_id = id_clientY; prop_integer = {23'd0,vmouse_packet[35:27]}; end
                        3: begin prop_id = id_offsetX; prop_integer = {22'd0,vmouse_packet[45:36]}; end
                        4: begin prop_id = id_offsetY; prop_integer = {23'd0,vmouse_packet[35:27]}; end
                        5: begin prop_id = id_mouse_x; prop_integer = {22'd0,vmouse_packet[45:36]}; end
                        6: begin prop_id = id_mouse_y; prop_integer = {23'd0,vmouse_packet[35:27]}; end
                        7: begin prop_id = id_buttons; prop_integer = {29'd0,vmouse_packet[26:24]}; end
                        8: begin prop_id = id_button; prop_integer = {30'd0,vmouse_packet[23:22]}; end
                        9: begin prop_id = id_movementX; prop_integer = {{21{vmouse_packet[21]}},vmouse_packet[21:11]}; end
                        10: begin prop_id = id_movementY; prop_integer = {{21{vmouse_packet[10]}},vmouse_packet[10:0]}; end
                        default: ;
                    endcase
                    if(vmouse_prop!=0)prop_value=v64_int32_number(prop_integer);
                    if (vmouse_prop >= 11) begin
                        bind_k <= 0; bind_rd_arm <= 0; vk_found <= 0; vk_pick <= 0;
                        hs_st(S_V64_FRAME_KEY);
                    end else begin
                        vmouse_prop <= vmouse_prop + 1'b1;
                        if (prop_id != 16'hffff) begin
                            hs_hp_cmd(HP_OSETI);
                            hs_hp_slot({1'b0,vmouse_slot});
                            hs_hp_qn(3'd1); hs_hp_qi(3'd0);
                            hp_qk_ff[0] <= prop_id; hs_m_hp_qk <= 1'b1;
                            hp_qv_ff[0] <= prop_value; hs_m_hp_qv <= 1'b1;
                            hp_qt_ff[0] <= 3'd0; hs_m_hp_qt <= 1'b1;
                            vmouse_slot <= vmouse_slot + 1'b1;
                            hs_hp_ret(S_V64_MOUSE_PROP);
                            hs_st(S_HEAP_WR);
                        end
                    end
                end
                S_V64_DISPATCH: begin
                    // dispatchEvent(ev): find ev.type in the object's slots
                    // (2 beats/slot, default vobj_raddr = {hp_oid, hp_slot}),
                    // then run the FRAME_KEY listener scan in custom mode
                    // with the REAL event object (all user fields intact).
                    // No .type property = no listeners match = resume.
                    if (state != S_V64_DISPATCH &&
                        e64_leave_hold) begin
                        hs_st(S_V64_DISPATCH);
                        vkev_event <= e64_hp_wval_q;
                        hs_hp_oid(e64_hp_wval_q[12:0]);
                        hs_hp_slot(5'd0);
                        hs_ip(e64_ip_q);
                        hs_vsp(e64_vsp_q);
                        // resume point survives the listener calls (the
                        // muxed ip/vsp reflect the LISTENER's exec run by
                        // the time the scan ends).
                        vkey_ret_ip <= e64_ip_q;
                        vkey_ret_sp <= e64_vsp_q;
                        vkey_want_ev <= V64_UNDEFINED;
                        bind_rd_arm <= 1'b0;
                        bind_k <= 8'd0; vk_found <= 1'b0; vk_pick <= 5'd0;
                        vkey_custom <= 1'b0;
                    end else if (!bind_rd_arm) begin
                        bind_rd_arm <= 1'b1;
                    end else if ({1'b0, hp_slot} < vobj_len_rdata) begin
                        if (vobj_rdata[79:64] == id_type &&
                            id_type != 16'hFFFF) begin
                            vkey_want_ev <= vobj_rdata[63:0];
                            vkey_custom <= 1'b1;
                            vkey_li <= 5'd0;
                            bind_k <= 8'd0; vk_found <= 1'b0; vk_pick <= 5'd0;
                            // exec copy: the parent vlistener_n_ff is stale
                            // outside the hs64 states (registration happens
                            // in exec).
                            vkey_ln <= e64_vlistener_n_q;
                            bind_rd_arm <= 1'b0;
                            hs_st(S_V64_FRAME_KEY);
                        end else if (hp_slot == 5'd31) begin
                            // A full object with no type must terminate,
                            // not wrap the five-bit cursor back to slot0.
                            bind_rd_arm <= 1'b0;
                            hs_ip(vkey_ret_ip); hs_vsp(vkey_ret_sp);
                            hs_code(15'(ops_base + vkey_ret_ip));
                            hs_st(S_FETCH_WAIT);
                        end else begin
                            hs_hp_slot(hp_slot + 5'd1);
                            bind_rd_arm <= 1'b0;
                        end
                    end else begin
                        bind_rd_arm <= 1'b0;
                        hs_ip(vkey_ret_ip);
                        hs_vsp(vkey_ret_sp);
                        hs_code(15'(ops_base + vkey_ret_ip));
                        hs_st(S_FETCH_WAIT);
                    end
                end
                S_V64_FRAME_KEY: begin
                    logic [63:0] want;
                    want = vkey_custom ? vkey_want_ev : vmouse_active ?
                        v64_handle(4'd4, 12'd0, {16'd0, vmouse_type_id}) : v64_handle(
                        4'd4, 12'd0,
                        {16'd0, kev_q[kev_rp][8] ? id_keydown : id_keyup}
                    );
                    if (state != S_V64_FRAME_KEY) begin
                        hs_st(S_V64_FRAME_KEY);
                        dbg_key_scan <= dbg_key_scan + 16'd1;
                        bind_k <= 8'd0;
                        bind_rd_arm <= 1'b0;
                        vk_found <= 1'b0;
                        vk_pick <= 5'd0;
                    end else if (bind_k < 8'd16) begin
                        if (!bind_rd_arm)
                            bind_rd_arm <= 1'b1;
                        else begin
                            if (bind_k < {3'd0, vkey_ln}) begin
                                dbg_key_cmp <= dbg_key_cmp + 16'd1;
                                dbg_key_want <= want;
                                dbg_key_lastev <= vlistener_ev_rdata;
                            end
                            if (!vk_found && bind_k >= {3'd0, vkey_li} &&
                                bind_k < {3'd0, vkey_ln} && // #60 snapshot
                                v64_equal(vlistener_ev_rdata, want)) begin
                                vk_found <= 1'b1;
                                vk_pick <= bind_k[4:0];
                            end
                            bind_k <= bind_k + 8'd1;
                            bind_rd_arm <= 1'b0;
                        end
                    end else if (vk_found) begin
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0; hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            bind_rd_arm <= 1'b1;
                        end else if (bind_k == 8'd16) begin
                            vst_wr(vsp, vlistener_fn_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd17;
                            bind_rd_arm <= 1'b0;
                        end else if (bind_k == 8'd17) begin
                            vst_wr(vsp, vkev_event);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd18;
                        end else begin
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            vk_found <= 1'b0;
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd1);
                            dbg_key_call <= dbg_key_call + 16'd1;
                            vcallback_key <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            vkey_li <= vk_pick + 5'd1;
                            hs_st(S_V64_ALLOC);
                        end
                    end else if (vkey_custom) begin
                        // dispatchEvent: synchronous — all listeners ran;
                        // resume the program (exec already advanced ip and
                        // planted the true result). No kev entry to pop.
                        vkey_custom <= 1'b0;
                        vkey_li <= 5'd0;
                        bind_rd_arm <= 1'b0;
                        hs_ip(vkey_ret_ip);
                        hs_vsp(vkey_ret_sp);
                        hs_code(15'(ops_base + vkey_ret_ip));
                        hs_st(S_FETCH_WAIT);
                    end else begin
                        if (vmouse_active) begin
                            mouse_evt_pop <= 1'b1;
                            vmouse_active <= 1'b0;
                        end else kev_rp <= kev_rp + 5'd1;
                        vkey_li <= 5'd0;
                        bind_rd_arm <= 1'b0;
                        hs_st(S_WAIT_FRAME);
                    end
                end
                S_V64_FRAME_RAF: begin
                    // First-entry latch, same as every other multi-beat arm.
                    // Entering from S_WAIT_FRAME the parent already hs_st'd
                    // here, but a rAF callback's RET_VAL requests this state
                    // from exec: casestate is FRAME_RAF for one beat while
                    // the parent's state stays S_V64_EXEC, so exec was
                    // re-enabled and ran the same RET_VAL twice — the second
                    // pass saw vcsp already 0 and faulted 2 (PACMAN).
                    if (state != S_V64_FRAME_RAF) begin
                        hs_st(S_V64_FRAME_RAF);
                    end else if (vraf_i < vraf_snap_n) begin
                        if (vcsp >= CSTK || vsp + 12'd2 > STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            // Beat 0: push fn. Two vst_wr in one cycle kept
                            // only the timestamp; window shifts ±1 so vsp+2
                            // also desynced TOS (INVADERS rAF never re-armed).
                            vst_wr(vsp, vraf_snap[vraf_i]);
                            hs_vsp(vsp + 12'd1);
                            bind_rd_arm <= 1'b1;
                            bind_k <= 8'd0;
                        end else if (bind_k == 8'd0) begin
                            // C3: sequential raf engine (see raf_pack_n).
                            // Stall this beat until the frame's timestamp
                            // is packed (~34 beats after vframe_no moved;
                            // dispatch reaches here much later, but the
                            // guard makes it correct, not just likely).
                            if (raf_ts_rdy) begin
                                vst_wr(vsp, raf_ts_q);
                                hs_vsp(vsp + 12'd1);
                                bind_k <= 8'd1;
                            end
                        end else begin
                            // Idle: ALLOC combo-reads last cycle's TOS window.
                            bind_rd_arm <= 1'b0;
                            bind_k <= 8'd0;
                            // Mark "a frame callback ran this frame". The
                            // host FRAME rpc ends a frame on
                            // (left_wait && back in S_WAIT_FRAME && cbip != 0);
                            // dbg_cb_ip was only ever written by the 32-bit
                            // path, so for HTML/Value64 titles FRAME could
                            // only end via the 2000-clock idle fallback. That
                            // works for a static splash but never during play
                            // (the VM leaves S_WAIT_FRAME again immediately),
                            // so every play frame burned the whole 64M cap and
                            // the GUI blocked on the RPC.
                            // A function handle with
                            // oid 0 makes cb_ip 0, and the host FRAME
                            // exit tests cbip != 0. Use a plain marker.
                            dbg_cb_ip <= 16'h1;
                            dbg_raf_call <= dbg_raf_call + 16'd1;
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd1);
                            vcallback_raf <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            vraf_i <= vraf_i + 4'd1;
                            hs_st(S_V64_ALLOC);
                        end
                    end else begin
                        vraf_snap_n <= 4'd0;
                        bind_rd_arm <= 1'b0;
                        bind_k <= 8'd0;
                        vt_found <= 1'b0;
                        vt_pick <= 7'd0;
                        vt_best_due <= 32'sh7fffffff;
                        vt_best_id <= 32'sh7fffffff;
                        hs_st(S_V64_FRAME_TIMER);
                    end
                end
                S_V64_FRAME_TIMER: begin
                    // Same first-entry latch as S_V64_FRAME_RAF above.
                    if (state != S_V64_FRAME_TIMER) begin
                        hs_st(S_V64_FRAME_TIMER);
                    end else if (bind_k < 8'd64) begin
                        if (!bind_rd_arm)
                            bind_rd_arm <= 1'b1;
                        else begin
                            if (vtimer_valid_rdata &&
                                vtimer_due_rdata <= $signed(vframe_no) &&
                                (!vt_found || vtimer_due_rdata < vt_best_due ||
                                 (vtimer_due_rdata == vt_best_due &&
                                  vtimer_id_rdata < vt_best_id))) begin
                                vt_found <= 1'b1;
                                vt_pick <= bind_k[6:0];
                                vt_best_due <= vtimer_due_rdata;
                                vt_best_id <= vtimer_id_rdata;
                            end
                            bind_k <= bind_k + 8'd1;
                            bind_rd_arm <= 1'b0;
                        end
                    end else if (vt_found) begin
                        if (vcsp >= CSTK || vsp >= STACK_DEPTH) begin
                            machine_fault <= 1'b1;
                            fault_code <= (vcsp >= CSTK) ? 8'd2 : 8'd1;
                            running <= 1'b0;
                            hs_st(S_DONE);
                        end else if (!bind_rd_arm) begin
                            bind_rd_arm <= 1'b1;
                        end else if (bind_k == 8'd64) begin
                            vst_wr(vsp, vtimer_fn_rdata);
                            hs_vsp(vsp + 12'd1);
                            bind_k <= 8'd65;
                            bind_rd_arm <= 1'b0;
                        end else begin
                            bind_rd_arm <= 1'b0;
                            vt_found <= 1'b0;
                            if (vtimer_period_rdata < 64'sd0) begin
                                vtimer_valid[vt_pick[5:0]] <= 1'b0;
                                vtimer_n <= vtimer_n - 7'd1;
                            end else
                                begin vtd_we <= 1'b1; vtd_wa <= vt_pick[5:0];
                                      vtd_wd <= vtimer_due_rdata + vtimer_period_rdata[31:0]; end
                            hs_vcall_value(1'b1);
                            hs_vcall_argc(12'd0);
                            vcallback_timer <= 1'b1;
                            hs_valloc_kind(2'd3);
                            hs_valloc_i(venv_next);
                            hs_valloc_retried(1'b0);
                            if (e64_vcsp_q < CSTK)
                                hs_vcsp(e64_vcsp_q + 8'd1);
                            hs_st(S_V64_ALLOC);
                        end
                    end else begin
                        bind_rd_arm <= 1'b0;
                        // PYTHON present(): scanout the back — but only if
                        // this frame drew. See fb_dirty.
                        dbg_frame_end <= dbg_frame_end + 16'd1;
                        if(dbg_raf_call!=0)first_frame_o<=1;
                        // Swap ONLY if this frame drew. The unconditional
                        // swap alternated the two banks on every FRAME, so
                        // an event-driven screen that draws ONCE (DONKEY
                        // title, character select) flickered against the
                        // stale other bank ("flashing splash behind the
                        // menu"). A frame that drew still swaps (top-level
                        // snippets included: their writes set fb_dirty and
                        // this beat runs at that frame's end); an explicit
                        // swapBuffers already presented and cleared
                        // fb_dirty, so it is not double-swapped either.
                        if (fb_dirty) begin
                            fb_swap <= 1'b1;
                            fb_dirty <= 1'b0;
                            // Copy the presented frame into the new back
                            // bank before the next frame draws. A partial
                            // redraw (DONKEY charsel repaints only the
                            // 36x21 selector arrow) otherwise lands on the
                            // stale two-presents-ago bank and resurrects
                            // it ("old KONG splash returns on LUIGI").
                            // Browser canvas semantics: content persists.
                            clr_idx <= '0;
                            fbs_armed <= 1'b0;
                            fb_dump_sel <= 1'b1;
                            fb_dump_addr <= '0;
                            hs_st(S_FB_SYNC);
                        end else begin
                            frame_gc_schedule();
                        end
                    end
                end
                S_V64_DIV: begin
                    logic [53:0] shifted_rem, next_rem;
                    logic quotient_bit;
                    // Exec seeds vdiv_*_n on the OP_DIV leave_hold beat.
                    // Parent FFs stayed 0 after the one-heap split, so
                    // 640/1510 (and any non-2^k /) packed +0. setTransform
                    // then kept identity and fillText(x=755) clipped off glass.
                    if (vdiv_count == 8'd0) begin
                        vdiv_num <= e64_vdiv_num_q;
                        vdiv_den <= e64_vdiv_den_q;
                        vdiv_rem <= e64_vdiv_rem_q;
                        vdiv_quot <= e64_vdiv_quot_q;
                        vdiv_count <= e64_vdiv_count_q;
                        vdiv_exp <= e64_vdiv_exp_q;
                        vdiv_sign <= e64_vdiv_sign_q;
                    end else begin
                    shifted_rem = {vdiv_rem[52:0], vdiv_num[106]};
                    quotient_bit = shifted_rem >= {1'b0, vdiv_den};
                    next_rem = quotient_bit
                             ? shifted_rem - {1'b0, vdiv_den}
                             : shifted_rem;
                    vdiv_num <= {vdiv_num[105:0], 1'b0};
                    vdiv_rem <= next_rem;
                    vdiv_quot <= {vdiv_quot[105:0], quotient_bit};
                    vdiv_count <= vdiv_count - 8'd1;
                    if (vdiv_count == 8'd1)
                        hs_st(S_V64_DIV_FIN);
                    end
                end
                S_V64_DIV_FIN: begin
                    // flatten: pack is always_comb vdiv_pack_n (107-bit for
                    // must not inline into unique case).
                    vst_wr(vsp - 12'd2, vdiv_pack_n);
                    hs_vsp(vsp - 12'd1);
                    hs_ip(ip + 16'd1);
                    hs_code(15'(ops_base + ip + 16'd1));
                    hs_st(S_FETCH_WAIT);
                end
                S_V64_MOD: begin
                    logic [53:0] shifted_rem;
                    logic [52:0] next_rem;
                    // Same one-heap seed as S_V64_DIV: exec OP_MOD leaves
                    // the restoring state in *_q; parent FFs were 0.
                    if (vmod_count == 12'd0) begin
                        vmod_rem <= e64_vmod_rem_q;
                        vmod_den <= e64_vmod_den_q;
                        vmod_count <= e64_vmod_count_q;
                        vmod_exp <= e64_vmod_exp_q;
                        vmod_sign <= e64_vmod_sign_q;
                    end else begin
                    shifted_rem = {vmod_rem, 1'b0};
                    next_rem = (shifted_rem >= {1'b0, vmod_den})
                             ? 53'(shifted_rem - {1'b0, vmod_den})
                             : shifted_rem[52:0];
                    vmod_rem <= next_rem;
                    vmod_count <= vmod_count - 12'd1;
                    if (vmod_count == 12'd1) begin
                        // flatten: pack is always_comb vmod_pack_n from
                        // vmod_next_rem_n (same next_rem as this arm).
                        vst_wr(vsp - 12'd2, vmod_pack_n);
                        hs_vsp(vsp - 12'd1);
                        ctor_after_let();
                        hs_hp_env(1'b0);
                        hs_st(S_FETCH_WAIT);
                    end
                    end
                end
                S_DONE: begin
                    running <= 1'b0;
                    hs_st(S_IDLE);
                end
                default: begin
                    // No parent arm for the state exec asked for:
                    // record it instead of idling silently.
                    dbg_bad_state <= 8'(casestate);
                    hs_st(S_IDLE);
                end
            endcase
            // Exec faults lived only in e64_*_q; parent VMSTAT/FRAME saw
            // fault=0 and S_DONE→IDLE (inner rAF / JUMP looked clean).
            // Only while hs64. HEAP_CLR is not hs64; copying leftover
            // e64_fault during the next title's load made PACMAN/DONKEY
            // SNAP fault=2 and the GUI bounce to READY.
            // Also copy on the S_DONE transition itself: exec can fault
            // while the parent sits in a state that is not in the hs64 list
            // (S_ARR_PROMOTE, GC, ...), and then the machine stopped with
            // fault=0 and no evidence at all — a "silent halt". S_DONE only
            // happens when something deliberately stops, so this cannot
            // resurrect a stale exec fault during a title load (the
            // HEAP_CLR hazard the hs64 guard was protecting against).
            if (e64_machine_fault_q &&
                (hs64 || casestate == S_DONE)) begin
                machine_fault <= 1'b1;
                fault_code <= e64_fault_code_q;
                // G-line: exec64's site never reached this register before —
                // every exec64 fault reported the parent's stale fsite.
                fault_site <= e64_fault_site_q;
            end
            // vstack is 1024 deep; fault before any index wraps (measured
            // gameplay peak is 71, flat array literals push one slot per
            // element, so only a ~1000-element literal can get here).
            if (vsp >= 12'd1008 && !machine_fault) begin
                machine_fault <= 1'b1;
                fault_code <= 8'd7; fault_site <= 16'd14833;
            end
            // Capacity and stale-handle failures are architectural errors.
            // Stop once, retain a compact fault code, and never hide them by
            // resetting a stack or wrapping an allocation pointer.
            if (!machine_fault &&
                (dbg_heap_ovf != 0 || dbg_to_ovf != 0 ||
                 dbg_json_ovf != 0 || dbg_path_ovf != 0 ||
                 dbg_str_ovf != 0 || dbg_stack_ovf != 0 ||
                 dbg_call_ovf != 0 || dbg_tmr_mis != 0)) begin
                machine_fault <= 1'b1;
                if (dbg_heap_ovf != 0) begin fault_code <= 8'd1; fault_site <= 16'd14844; end
                else if (dbg_to_ovf != 0) begin fault_code <= 8'd2; fault_site <= 16'd14845; end
                else if (dbg_json_ovf != 0) begin fault_code <= 8'd3; fault_site <= 16'd14846; end
                else if (dbg_path_ovf != 0) begin fault_code <= 8'd4; fault_site <= 16'd14847; end
                else if (dbg_str_ovf != 0) begin fault_code <= 8'd5; fault_site <= 16'd14848; end
                else if (dbg_stack_ovf != 0) begin fault_code <= 8'd6; fault_site <= 16'd14849; end
                else if (dbg_call_ovf != 0) begin fault_code <= 8'd7; fault_site <= 16'd14850; end
                else begin fault_code <= 8'd8; fault_site <= 16'd14851; end
                running <= 1'b0;
                hs_st(S_DONE);
            end
        end
    end
endmodule
`undef VST_AT
`undef VST_REL
