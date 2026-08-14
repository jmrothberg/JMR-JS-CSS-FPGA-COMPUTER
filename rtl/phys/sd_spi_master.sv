// SPI-mode SD master — CMD framing + R1 wait matching sd_spi.py shape.
// Bit-bang SPI mode 0: MOSI changes before rising SCK; MISO sampled on rising.
// NEW: init ≤400 kHz (div≈256), ACMD41 retry + CMD58, strict R1, write busy poll.

module sd_spi_master #(
    // NEW: SPI half-period counts, in clocks of THIS module's clk.
    // SCK = clk / (2 * (DIV + 1)).
    // Defaults are the original 100 MHz numbers (init ~390 kHz, run 12.5 MHz) so
    // simulation and the SPI transcript vectors are unchanged. The board core now
    // runs at 4.6875 MHz, where those defaults give ~18 kHz init — below the SD
    // spec's 100–400 kHz window — so top_nexys_a7 overrides them.
    parameter int unsigned INIT_DIV = 127,
`ifdef VERILATOR
    // Sim-only: SCK = clk/2. Board keeps RUN_DIV=3 (real SPI). Fat .JSH loads
    // were minutes in Verilator at the board divider.
    parameter int unsigned RUN_DIV  = 0
`else
    parameter int unsigned RUN_DIV  = 3
`endif
) (
    input  logic        clk,
    input  logic        rst_n,
    // MMIO
    input  logic [7:0]  cmd,       // 0 idle 1 init 2 read 3 write
    input  logic [31:0] lba,
    output logic [7:0]  status,    // bit0 present bit1 busy bit2 err bit3 init
    output logic        ack_done,
    // SPI pins
    output logic        spi_sck,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs_n,
    // Sector buffer port
    output logic [8:0]  buf_addr,
    output logic [7:0]  buf_wdata,
    input  logic [7:0]  buf_rdata,
    output logic        buf_we
);
    typedef enum logic [4:0] {
        ST_IDLE,
        ST_XFER,
        ST_INIT_WAKE,     // NEW: ≥74 clocks with CS HIGH (SD power-up requirement)
        ST_INIT_LEAD,     // 2× 0xFF
        ST_INIT_FRAME,    // send 6-byte CMD from frame[]
        ST_INIT_R1,       // wait R1
        ST_INIT_NEXT,     // advance init_step after R1
        ST_INIT_DRAIN,    // drain R7 (CMD8) or OCR (CMD58)
        ST_RW_FRAME,
        ST_RW_R1,
        ST_READ_DATA,
        ST_READ_PAYLOAD,
        ST_READ_CRC,
        ST_WRITE_DATA,
        ST_WRITE_PAYLOAD,
        ST_WRITE_CRC,
        ST_WRITE_RESP,
        ST_WRITE_BUSY,    // NEW: poll MISO until 0xFF after data response
        ST_DONE,
        ST_ERR
    } state_t;

    state_t state, ret_state;

    // init_step: 0=CMD0 1=CMD8 2=CMD55 3=ACMD41 4=CMD58
    logic [2:0]  init_step;
    logic [7:0]  cmd_idx;
    logic [31:0] cmd_arg;
    logic [7:0]  shift_tx, shift_rx, rx_byte;
    logic [2:0]  bit_i;
    logic [9:0]  byte_i;
    // NEW: every one of these waits used to be a handful of byte-times, which a
    // simulated card always answered inside. A real card is far slower and the
    // spec says so, so each budget below is the spec's worst case with margin.
    // Timeouts still exist — the point is to fail on a broken card, not on a
    // healthy one that simply took its documented time.
    localparam int unsigned R1_TRIES   = 64;    // Ncr is ≤8 bytes; be generous
    localparam int unsigned TOKEN_WAIT = 20000; // read access time up to 100 ms
    localparam int unsigned ACMD_TRIES = 3000;  // ACMD41 may need ~1 s to leave idle
    logic [15:0] r1_tries;
    logic        busy_r, init_r, err_r;
    logic        sck_hi;
    logic        spi_active;
    logic [7:0]  frame [0:5];
    logic [2:0]  frame_i;
    // NEW: SPI clock divider — half-period count-1, now from INIT_DIV/RUN_DIV.
    logic [7:0]  spi_div;
    logic [7:0]  clk_cnt;
    // NEW: ACMD41 retry counter (see ACMD_TRIES)
    logic [11:0] acmd_tries;
    // NEW: "MOSI has been presented, next tick raises SCK" (see ST_XFER). Always
    // 0 on entry to and exit from ST_XFER, so it needs no per-transfer clearing.
    logic        mosi_rdy;
    // NEW: write-busy poll timeout
    logic [15:0] busy_cnt;
    // NEW: start only on 0→nonzero cmd edge (avoids ST_DONE→IDLE re-fire)
    logic [7:0]  cmd_d;

    assign status  = {4'b0, init_r, err_r, busy_r, 1'b1};
    assign spi_sck = (spi_active && sck_hi) ? 1'b1 : 1'b0;

    // NEW: spi_miso comes from the card and is asynchronous to this clock, so it
    // goes through two flops before it is used. Sampling an async pin directly
    // can go metastable and corrupt a bit anywhere in a 512-byte sector -- a
    // fault simulation can never show, because there every pin is settled.
    logic [1:0] miso_sync;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) miso_sync <= 2'b11;
        else        miso_sync <= {miso_sync[0], spi_miso};
    end
    wire miso_s = miso_sync[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            ret_state <= ST_IDLE;
            busy_r <= 1'b0;
            init_r <= 1'b0;
            err_r <= 1'b0;
            ack_done <= 1'b0;
            spi_cs_n <= 1'b1;
            spi_mosi <= 1'b1;
            spi_active <= 1'b0;
            sck_hi <= 1'b0;
            buf_we <= 1'b0;
            buf_addr <= '0;
            buf_wdata <= '0;
            cmd_idx <= '0;
            cmd_arg <= '0;
            bit_i <= '0;
            byte_i <= '0;
            frame_i <= '0;
            shift_tx <= 8'hFF;
            shift_rx <= '0;
            rx_byte <= 8'hFF;
            r1_tries <= '0;
            init_step <= '0;
            spi_div <= 8'(INIT_DIV);   // NEW: slow clock until init succeeds
            clk_cnt <= '0;
            acmd_tries <= '0;
            mosi_rdy <= 1'b0;
            busy_cnt <= '0;
            cmd_d <= 8'h0;
        end else begin
            ack_done <= 1'b0;
            buf_we <= 1'b0;
            cmd_d <= cmd;

            unique case (state)
                ST_IDLE: begin
                    busy_r <= 1'b0;
                    spi_cs_n <= 1'b1;
                    spi_active <= 1'b0;
                    sck_hi <= 1'b0;
                    spi_mosi <= 1'b1;
                    // NEW: 0→cmd edge only (ST_DONE→IDLE must not re-fire)
                    if (cmd != 8'h0 && cmd_d == 8'h0) begin
                    // NEW: status[2] reports how THIS command went, so clear it
                    // when one starts. Only init used to clear it, which made the
                    // flag sticky for the rest of the session: one hiccup during
                    // SAVE and storage_engine's S_SD_CLR then flagged every later
                    // read as failed even though the bytes arrived intact, so
                    // after any SAVE no LOAD worked again until a board reset.
                    err_r <= 1'b0;
                    if (cmd == 8'd1) begin
                        busy_r <= 1'b1;
                        err_r <= 1'b0;
                        // NEW: CS stays HIGH for the wake-up clocks (ST_INIT_WAKE);
                        // ST_INIT_LEAD selects the card just before CMD0.
                        spi_cs_n <= 1'b1;
                        byte_i <= '0;
                        frame_i <= '0;
                        init_step <= 3'd0;
                        acmd_tries <= '0;
                        spi_div <= 8'(INIT_DIV); // NEW: ≤400 kHz for init
                        clk_cnt <= '0;
                        // CMD0
                        frame[0] <= 8'h40;
                        frame[1] <= 8'h00;
                        frame[2] <= 8'h00;
                        frame[3] <= 8'h00;
                        frame[4] <= 8'h00;
                        frame[5] <= 8'h95;
                        state <= ST_INIT_WAKE;
                    end else if (cmd == 8'd2) begin
                        busy_r <= 1'b1;
                        cmd_idx <= 8'd17;
                        cmd_arg <= lba;
                        spi_cs_n <= 1'b0;
                        frame_i <= '0;
                        clk_cnt <= '0;
                        frame[0] <= 8'h51; // 0x40|17
                        frame[1] <= lba[31:24];
                        frame[2] <= lba[23:16];
                        frame[3] <= lba[15:8];
                        frame[4] <= lba[7:0];
                        frame[5] <= 8'h01;
                        state <= ST_RW_FRAME;
                    end else if (cmd == 8'd3) begin
                        busy_r <= 1'b1;
                        cmd_idx <= 8'd24;
                        cmd_arg <= lba;
                        spi_cs_n <= 1'b0;
                        frame_i <= '0;
                        clk_cnt <= '0;
                        frame[0] <= 8'h58; // 0x40|24
                        frame[1] <= lba[31:24];
                        frame[2] <= lba[23:16];
                        frame[3] <= lba[15:8];
                        frame[4] <= lba[7:0];
                        frame[5] <= 8'h01;
                        state <= ST_RW_FRAME;
                    end
                    end // NEW: edge-trigger wrapper
                end

                // SPI byte: spi_div+1 sysclks per half-period (mode 0)
                ST_XFER: begin
                    spi_active <= 1'b1;
                    // NEW: hold phase until divider elapses
                    if (clk_cnt < spi_div) begin
                        clk_cnt <= clk_cnt + 8'd1;
                    end else begin
                        clk_cnt <= '0;
                        // NEW: the low phase now takes two divider intervals --
                        // present MOSI on the first, raise SCK on the second.
                        // MOSI and sck_hi used to be assigned on the SAME clock
                        // edge, so SCK rose at the instant MOSI changed: zero
                        // setup against a card that samples MOSI on the rising
                        // edge (SPI mode 0). The C++ card model reads settled pin
                        // values once per simulated clock and so cannot see this,
                        // which is why every simulation passed while the real
                        // card never answered a single command. MOSI is now
                        // stable for a full half-period before each rising edge.
                        if (!sck_hi) begin
                            if (!mosi_rdy) begin
                                spi_mosi <= shift_tx[7];
                                mosi_rdy <= 1'b1;
                            end else begin
                                sck_hi   <= 1'b1;
                                mosi_rdy <= 1'b0;
                            end
                        end else begin
                            shift_rx <= {shift_rx[6:0], miso_s};
                            shift_tx <= {shift_tx[6:0], 1'b1};
                            sck_hi <= 1'b0;
                            if (bit_i == 3'd7) begin
                                rx_byte <= {shift_rx[6:0], miso_s};
                                spi_active <= 1'b0;
                                bit_i <= '0;
                                state <= ret_state;
                            end else
                                bit_i <= bit_i + 3'd1;
                        end
                    end
                end

                // NEW: 80 clocks (10 bytes of 0xFF) with CS de-asserted. A real
                // card ignores every command until it has seen ≥74 such clocks —
                // this is the card's internal power-up window. The old code went
                // straight to two lead-in bytes with CS already low, which the
                // simulated card in sim/ happily answered but hardware did not:
                // init failed, storage_engine raised its error, and the console
                // printed ?SN ERROR for every LOAD on the board.
                ST_INIT_WAKE: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    spi_cs_n <= 1'b1;
                    if (byte_i == 10'd9) begin
                        byte_i <= '0;
                        ret_state <= ST_INIT_LEAD;
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_INIT_WAKE;
                    end
                    state <= ST_XFER;
                end

                ST_INIT_LEAD: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    spi_cs_n <= 1'b0;   // NEW: select the card now that it is awake
                    if (byte_i == 10'd1) begin
                        byte_i <= '0;
                        frame_i <= '0;
                        ret_state <= ST_INIT_FRAME;
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_INIT_LEAD;
                    end
                    state <= ST_XFER;
                end

                ST_INIT_FRAME: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= frame[frame_i];
                    if (frame_i == 3'd5) begin
                        frame_i <= '0;
                        r1_tries <= '0;
                        ret_state <= ST_INIT_R1;
                    end else begin
                        frame_i <= frame_i + 3'd1;
                        ret_state <= ST_INIT_FRAME;
                    end
                    state <= ST_XFER;
                end

                ST_INIT_R1: begin
                    if (rx_byte == 8'hFF) begin
                        if (r1_tries >= 16'(R1_TRIES)) begin
                            state <= ST_ERR;
                        end else begin
                            r1_tries <= r1_tries + 16'd1;
                            bit_i <= '0;
                            sck_hi <= 1'b0;
                            clk_cnt <= '0;
                            shift_tx <= 8'hFF;
                            ret_state <= ST_INIT_R1;
                            state <= ST_XFER;
                        end
                    end else begin
                        // NEW: decode R1 — only 0x00, or 0x01 while idle (CMD0/8/55/ACMD41)
                        unique case (init_step)
                            3'd0, 3'd1: begin
                                if (rx_byte == 8'h01) state <= ST_INIT_NEXT;
                                else state <= ST_ERR;
                            end
                            3'd2: begin
                                if (rx_byte == 8'h01 || rx_byte == 8'h00)
                                    state <= ST_INIT_NEXT;
                                else state <= ST_ERR;
                            end
                            3'd3: begin
                                if (rx_byte == 8'h01 || rx_byte == 8'h00)
                                    state <= ST_INIT_NEXT;
                                else state <= ST_ERR;
                            end
                            default: begin // CMD58
                                if (rx_byte == 8'h00) state <= ST_INIT_NEXT;
                                else state <= ST_ERR;
                            end
                        endcase
                    end
                end

                ST_INIT_NEXT: begin
                    unique case (init_step)
                        3'd0: begin
                            // After CMD0 → CMD8
                            init_step <= 3'd1;
                            frame[0] <= 8'h48;
                            frame[1] <= 8'h00;
                            frame[2] <= 8'h00;
                            frame[3] <= 8'h01;
                            frame[4] <= 8'hAA;
                            frame[5] <= 8'h87;
                            frame_i <= '0;
                            state <= ST_INIT_FRAME;
                        end
                        3'd1: begin
                            // After CMD8 R1 → drain R7 then CMD55
                            byte_i <= '0;
                            state <= ST_INIT_DRAIN;
                        end
                        3'd2: begin
                            // After CMD55 → ACMD41
                            init_step <= 3'd3;
                            frame[0] <= 8'h69;
                            frame[1] <= 8'h40;
                            frame[2] <= 8'h00;
                            frame[3] <= 8'h00;
                            frame[4] <= 8'h00;
                            frame[5] <= 8'h77;
                            frame_i <= '0;
                            state <= ST_INIT_FRAME;
                        end
                        3'd3: begin
                            // NEW: After ACMD41 — retry while idle, else CMD58
                            if (rx_byte == 8'h01) begin
                                if (acmd_tries >= 12'(ACMD_TRIES)) begin
                                    state <= ST_ERR;
                                end else begin
                                    acmd_tries <= acmd_tries + 12'd1;
                                    init_step <= 3'd2;
                                    frame[0] <= 8'h77; // CMD55
                                    frame[1] <= 8'h00;
                                    frame[2] <= 8'h00;
                                    frame[3] <= 8'h00;
                                    frame[4] <= 8'h00;
                                    frame[5] <= 8'h65;
                                    frame_i <= '0;
                                    state <= ST_INIT_FRAME;
                                end
                            end else begin
                                // R1==0x00 → CMD58
                                init_step <= 3'd4;
                                frame[0] <= 8'h7A; // 0x40|58
                                frame[1] <= 8'h00;
                                frame[2] <= 8'h00;
                                frame[3] <= 8'h00;
                                frame[4] <= 8'h00;
                                frame[5] <= 8'hFD;
                                frame_i <= '0;
                                state <= ST_INIT_FRAME;
                            end
                        end
                        default: begin
                            // After CMD58 R1 → drain OCR
                            byte_i <= '0;
                            state <= ST_INIT_DRAIN;
                        end
                    endcase
                end

                ST_INIT_DRAIN: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    if (byte_i == 10'd3) begin
                        if (init_step == 3'd4) begin
                            // NEW: last OCR byte (still slow), then ST_DONE switches to fast SPI
                            init_r <= 1'b1;
                            ret_state <= ST_DONE;
                        end else begin
                            init_step <= 3'd2;
                            frame[0] <= 8'h77; // CMD55
                            frame[1] <= 8'h00;
                            frame[2] <= 8'h00;
                            frame[3] <= 8'h00;
                            frame[4] <= 8'h00;
                            frame[5] <= 8'h65;
                            frame_i <= '0;
                            byte_i <= '0;
                            ret_state <= ST_INIT_FRAME;
                        end
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_INIT_DRAIN;
                    end
                    state <= ST_XFER;
                end

                ST_RW_FRAME: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= frame[frame_i];
                    if (frame_i == 3'd5) begin
                        frame_i <= '0;
                        r1_tries <= '0;
                        ret_state <= ST_RW_R1;
                    end else begin
                        frame_i <= frame_i + 3'd1;
                        ret_state <= ST_RW_FRAME;
                    end
                    state <= ST_XFER;
                end

                ST_RW_R1: begin
                    // NEW: accept only R1==0x00 for read/write
                    if (rx_byte != 8'hFF) begin
                        if (rx_byte != 8'h00) begin
                            state <= ST_ERR;
                        end else begin
                            byte_i <= '0;
                            if (cmd_idx == 8'd17)
                                state <= ST_READ_DATA;
                            else if (cmd_idx == 8'd24)
                                state <= ST_WRITE_DATA;
                            else
                                state <= ST_DONE;
                        end
                    end else if (r1_tries >= 16'(R1_TRIES)) begin
                        state <= ST_ERR;
                    end else begin
                        r1_tries <= r1_tries + 16'd1;
                        bit_i <= '0;
                        sck_hi <= 1'b0;
                        clk_cnt <= '0;
                        shift_tx <= 8'hFF;
                        ret_state <= ST_RW_R1;
                        state <= ST_XFER;
                    end
                end

                ST_READ_DATA: begin
                    // Wait for data token 0xFE then clock 512 bytes + 2 CRC
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    if (rx_byte == 8'hFE) begin
                        byte_i <= '0;
                        ret_state <= ST_READ_PAYLOAD;
                    end else if (r1_tries >= 16'(TOKEN_WAIT)) begin
                        state <= ST_ERR;
                    end else begin
                        r1_tries <= r1_tries + 16'd1;
                        ret_state <= ST_READ_DATA;
                    end
                    state <= ST_XFER;
                end

                ST_READ_PAYLOAD: begin
                    buf_we <= 1'b1;
                    buf_addr <= byte_i[8:0];
                    buf_wdata <= rx_byte;
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    if (byte_i == 10'd511) begin
                        byte_i <= '0;
                        ret_state <= ST_READ_CRC;
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_READ_PAYLOAD;
                    end
                    state <= ST_XFER;
                end

                ST_READ_CRC: begin
                    // Discard 2 CRC bytes
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    if (byte_i == 10'd1) state <= ST_DONE;
                    else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_READ_CRC;
                        state <= ST_XFER;
                    end
                end

                ST_WRITE_DATA: begin
                    // Send token 0xFE then 512 payload bytes from buf + CRC 0xFFFF
                    if (byte_i == 10'd0) begin
                        bit_i <= '0;
                        sck_hi <= 1'b0;
                        clk_cnt <= '0;
                        shift_tx <= 8'hFE;
                        // NEW Phase6: pre-point the buffer at byte 0 so the first
                        // payload cycle latches buf[0] (was one byte late, and
                        // buf[511] was never sent).
                        buf_addr <= 9'd0;
                        ret_state <= ST_WRITE_PAYLOAD;
                        state <= ST_XFER;
                        byte_i <= 10'd1;
                    end else begin
                        state <= ST_WRITE_PAYLOAD;
                    end
                end

                ST_WRITE_PAYLOAD: begin
                    // NEW Phase6: byte_i counts 1..512 while buf_addr pre-fetches
                    // the *next* byte; shift_tx below takes the current one.
                    buf_addr <= byte_i[8:0];
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= buf_rdata;
                    if (byte_i == 10'd512) begin
                        byte_i <= '0;
                        ret_state <= ST_WRITE_CRC;
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_WRITE_PAYLOAD;
                    end
                    state <= ST_XFER;
                end

                ST_WRITE_CRC: begin
                    bit_i <= '0;
                    sck_hi <= 1'b0;
                    clk_cnt <= '0;
                    shift_tx <= 8'hFF;
                    if (byte_i == 10'd1) begin
                        ret_state <= ST_WRITE_RESP;
                        byte_i <= '0;
                        r1_tries <= '0;   // NEW: budget for the response poll below
                    end else begin
                        byte_i <= byte_i + 10'd1;
                        ret_state <= ST_WRITE_CRC;
                    end
                    state <= ST_XFER;
                end

                ST_WRITE_RESP: begin
                    // NEW: the data response does NOT share the last CRC byte --
                    // the card holds MISO at 0xFF until the token is ready, a few
                    // byte times later. This used to judge the byte received while
                    // the second CRC byte went out, which is always 0xFF, so every
                    // single sector write reported failure even though the data
                    // landed intact. Combined with the error flag being sticky,
                    // that is why one SAVE poisoned every later LOAD.
                    if (rx_byte == 8'hFF) begin
                        if (r1_tries >= 16'(R1_TRIES)) begin
                            state <= ST_ERR;
                        end else begin
                            r1_tries <= r1_tries + 16'd1;
                            bit_i <= '0;
                            sck_hi <= 1'b0;
                            clk_cnt <= '0;
                            shift_tx <= 8'hFF;
                            ret_state <= ST_WRITE_RESP;
                            state <= ST_XFER;
                        end
                    // data response must be xxx00101; then busy-poll
                    end else if ((rx_byte & 8'h1F) != 8'h05) begin
                        state <= ST_ERR;
                    end else begin
                        busy_cnt <= '0;
                        bit_i <= '0;
                        sck_hi <= 1'b0;
                        clk_cnt <= '0;
                        shift_tx <= 8'hFF;
                        ret_state <= ST_WRITE_BUSY;
                        state <= ST_XFER;
                    end
                end

                // NEW: clock 0xFF until MISO returns 0xFF (card not busy)
                ST_WRITE_BUSY: begin
                    if (rx_byte == 8'hFF) begin
                        state <= ST_DONE;
                    end else if (busy_cnt == 16'hFFFF) begin
                        state <= ST_ERR;
                    end else begin
                        busy_cnt <= busy_cnt + 16'd1;
                        bit_i <= '0;
                        sck_hi <= 1'b0;
                        clk_cnt <= '0;
                        shift_tx <= 8'hFF;
                        ret_state <= ST_WRITE_BUSY;
                        state <= ST_XFER;
                    end
                end

                ST_DONE: begin
                    busy_r <= 1'b0;
                    ack_done <= 1'b1;
                    spi_cs_n <= 1'b1;
                    spi_active <= 1'b0;
                    // NEW: after successful init, switch to the faster run rate
                    if (init_r)
                        spi_div <= 8'(RUN_DIV);
                    // NEW: always return to IDLE.  Holding until cmd==0 raced the
                    // next sd_go (cmd still 3 → duplicate CMD24; cmd already 2 →
                    // stuck in DONE).  Storage clears cmd on ack before re-issue.
                    state <= ST_IDLE;
                end

                ST_ERR: begin
                    err_r <= 1'b1;
                    busy_r <= 1'b0;
                    ack_done <= 1'b1;
                    spi_cs_n <= 1'b1;
                    spi_active <= 1'b0;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
