// Shared Value64 Number/tag helpers — Python twin: hardware_model/js_vm.py
// Frozen ABI: docs/JMR_JS_COMPATIBILITY.md
//
// This package is the Number/tag engine interface. Heap/GC and call frames
// stay in jmr_js_vm.sv until their request/response split lands.
package jmr_value_pkg;
    localparam logic [63:0] V64_CANON_NAN = 64'h7ff8000000000000;
    localparam logic [63:0] V64_UNDEFINED = 64'h7ff9100000000000;
    localparam logic [63:0] V64_NULL = 64'h7ff9200000000000;
    localparam logic [15:0] V64_TAG_PREFIX = 16'h7ff9;
    localparam logic [3:0] V64_KIND_UNDEFINED = 4'd1;
    localparam logic [3:0] V64_KIND_NULL = 4'd2;
    localparam logic [3:0] V64_KIND_BOOL = 4'd3;
    localparam logic [3:0] V64_KIND_STRING = 4'd4;
    localparam logic [3:0] V64_KIND_OBJECT = 4'd5;
    localparam logic [3:0] V64_KIND_ARRAY = 4'd6;
    localparam logic [3:0] V64_KIND_FUNCTION = 4'd7;
    localparam logic [3:0] V64_KIND_ELEMENT = 4'd8;
    localparam logic [3:0] V64_KIND_ENV = 4'd9;

    function automatic logic v64_is_number(input logic [63:0] v);
        v64_is_number = (v[63:48] != V64_TAG_PREFIX);
    endfunction

    function automatic logic v64_truthy(input logic [63:0] v);
        if (v64_is_number(v))
            v64_truthy = !((v[62:0] == 0) ||
                           (v[62:52] == 11'h7ff && v[51:0] != 0));
        else if (v[47:44] == V64_KIND_UNDEFINED || v[47:44] == V64_KIND_NULL)
            v64_truthy = 1'b0;
        else if (v[47:44] == V64_KIND_BOOL)
            v64_truthy = (v[31:0] != 0);
        else
            v64_truthy = 1'b1;
    endfunction

    function automatic logic v64_equal(
        input logic [63:0] aa,
        input logic [63:0] bb
    );
        if (v64_is_number(aa) && v64_is_number(bb)) begin
            if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
                (bb[62:52] == 11'h7ff && bb[51:0] != 0))
                v64_equal = 1'b0;
            else if (aa[62:0] == 0 && bb[62:0] == 0)
                v64_equal = 1'b1;
            else
                v64_equal = (aa == bb);
        end else
            v64_equal = (aa == bb);
    endfunction

    function automatic logic v64_less(
        input logic [63:0] aa,
        input logic [63:0] bb
    );
        if ((aa[62:52] == 11'h7ff && aa[51:0] != 0) ||
            (bb[62:52] == 11'h7ff && bb[51:0] != 0) ||
            (aa[62:0] == 0 && bb[62:0] == 0))
            v64_less = 1'b0;
        else if (aa[63] != bb[63])
            v64_less = aa[63];
        else if (aa[63])
            v64_less = (aa[62:0] > bb[62:0]);
        else
            v64_less = (aa[62:0] < bb[62:0]);
    endfunction

    function automatic logic [55:0] v64_shr_sticky(
        input logic [55:0] value,
        input integer shift
    );
        logic sticky;
        logic [55:0] shifted;
        begin
            sticky = 1'b0;
            shifted = value;
            if (shift >= 56) begin
                shifted = 56'd0;
                shifted[0] = |value;
            end else if (shift > 0) begin
                for (int k = 0; k < 56; k++)
                    if (k < shift)
                        sticky = sticky | value[k];
                shifted = value >> shift;
                shifted[0] = shifted[0] | sticky;
            end
            v64_shr_sticky = shifted;
        end
    endfunction

    function automatic logic [5:0] v64_norm_shift(input logic [52:0] mant);
        // Log-depth leading-zero count (priority scan, ~6 levels). The old
        // form was 52 loop-carried conditional shifts — the same serial-
        // chain class as the multiply's 477-CARRY4 -250ns path (2026-08-24).
        // Semantics identical: highest set bit p -> 52-p; mant==0 -> 52.
        logic [5:0] count;
        begin
            count = 6'd52;
            for (int k = 0; k <= 52; k++)
                if (mant[k]) count = 6'(52 - k);
            v64_norm_shift = count;
        end
    endfunction

    function automatic logic signed [12:0] v64_unbiased_exp(
        input logic [10:0] exponent,
        input logic [5:0] norm_shift
    );
        if (exponent == 0)
            v64_unbiased_exp = -13'sd1022 - 13'(norm_shift);
        else
            v64_unbiased_exp = 13'(exponent) - 13'sd1023;
    endfunction

    function automatic logic [63:0] v64_handle(
        input logic [3:0] kind,
        input logic [11:0] generation,
        input logic [31:0] index
    );
        v64_handle = {V64_TAG_PREFIX, kind, generation, index};
    endfunction

    function automatic logic [31:0] v64_to_uint32(input logic [63:0] value);
        logic [10:0] exponent;
        logic [52:0] mant;
        logic [31:0] magnitude;
        // Do not stash (exponent-1023) in a package-function local.
        // A named signed temp here was stuck at 0, so every finite
        // Number became 1 (mant>>52) — fillRect(1,1,2,2,5) painted a
        // 1×1 in color 1. Compare the IEEE exponent to 1023 directly
        // (same ToUint32 truncation as PYTHON).
        begin
            exponent = value[62:52];
            mant = {1'b1, value[51:0]};
            magnitude = 32'd0;
            if (exponent >= 11'd1023 && exponent < 11'd1107) begin
                if (exponent >= 11'd1075)
                    magnitude = 32'(mant << (exponent - 11'd1075));
                else
                    magnitude = 32'(mant >> (11'd1075 - exponent));
            end
            v64_to_uint32 = value[63] ? (~magnitude + 32'd1) : magnitude;
        end
    endfunction

    // ToInt32 for bitwise ops: Bool → 0/1, Number via v64_to_uint32, else +0.
    // Grouped switch cases compile to BIT_OR of EQ bools.
    function automatic logic [31:0] v64_to_int32(input logic [63:0] value);
        if (!v64_is_number(value)) begin
            if (value[47:44] == V64_KIND_BOOL)
                v64_to_int32 = {31'd0, value[0]};
            else
                v64_to_int32 = 32'd0;
        end else
            v64_to_int32 = v64_to_uint32(value);
    endfunction

    function automatic logic [63:0] v64_int32_number(input logic [31:0] raw);
        logic sign;
        logic [31:0] magnitude;
        logic [52:0] mant;
        integer top;
        begin
            sign = raw[31];
            magnitude = sign ? (~raw + 32'd1) : raw;
            if (magnitude == 0) begin
                v64_int32_number = 64'd0;
            end else begin
                top = 0;
                for (int k = 0; k < 32; k++)
                    if (magnitude[k])
                        top = k;
                mant = 53'(magnitude) << (52 - top);
                v64_int32_number = {sign, 11'(top + 1023), mant[51:0]};
            end
        end
    endfunction

    // Math.floor toward -inf. |x|>=2^31 uses ToInt32 magnitude (title
    // floors are small positives). Do not stash (exponent-1023) in a
    // named signed temp — that pattern stuck at 0 in v64_to_uint32.
    function automatic logic [63:0] v64_floor_number(input logic [63:0] value);
        logic [10:0] exponent;
        logic [51:0] frac_mask;
        logic frac;
        logic [31:0] trunc;
        begin
            exponent = value[62:52];
            frac_mask = 52'd0;
            if (exponent < 11'd1023)
                frac_mask = 52'hfffffffffffff;
            else if (exponent < 11'd1075)
                frac_mask = (52'd1 << (11'd1075 - exponent)) - 52'd1;
            frac = (exponent < 11'd1023) ? (value[62:0] != 0)
                 : (exponent < 11'd1075) && ((value[51:0] & frac_mask) != 0);
            if (!v64_is_number(value))
                v64_floor_number = 64'd0;
            else if (exponent == 11'h7ff)
                v64_floor_number = (value[51:0] != 0) ? V64_CANON_NAN : value;
            else begin
                trunc = v64_to_uint32(value);
                if (value[63] && frac)
                    trunc = trunc - 32'd1;
                v64_floor_number = v64_int32_number(trunc);
            end
        end
    endfunction

    function automatic logic [63:0] v64_u32_fraction(input logic [31:0] raw);
        logic [52:0] mant;
        integer top;
        begin
            if (raw == 0) begin
                v64_u32_fraction = 64'd0;
            end else begin
                top = 0;
                for (int k = 0; k < 32; k++)
                    if (raw[k])
                        top = k;
                mant = 53'(raw) << (52 - top);
                v64_u32_fraction =
                    {1'b0, 11'(top - 32 + 1023), mant[51:0]};
            end
        end
    endfunction
endpackage
