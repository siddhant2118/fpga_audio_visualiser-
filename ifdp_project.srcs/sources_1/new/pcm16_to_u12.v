// -----------------------------------------------------------------------------
// pcm16_to_u12.v
//
// Purpose : Convert a signed 16-bit PCM sample into an unsigned 12-bit
//            representation suitable for driving the DAC121S101 on the Pmod DA2.
//            The conversion adds a fixed offset to map the signed range
//            (-32768..+32767) into an unsigned 0..65535 range, then rounds to
//            12 bits by discarding the lower four bits.  Saturation limits the
//            result to the range 0..4095.  Optionally, triangular probability
//            density function (TPDF) dither may be added to suppress
//            quantization spurs.
//
// Parameters :
//   ENABLE_DITHER - when set to 1, adds ±0.5 LSB (12-bit domain) dither before
//                   rounding.  The dither uses a simple 2-bit LFSR.  Default
//                   is 0 (no dither).
//
// I/O :
//   s16  - signed 16-bit PCM input sample
//   u12  - unsigned 12-bit output sample (0..4095)
//
// Coding style : purely combinational; no flip-flops.  Use blocking
// assignments inside the always @* block.
//
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module pcm16_to_u12 #(
    parameter ENABLE_DITHER = 0
)(
    input  wire signed [15:0] s16,
    output reg  [11:0]        u12
);
    // Local wires for intermediate values
    reg  [16:0] unsigned17;
    reg  [12:0] rounded13;
    reg  [1:0]  lfsr;

    always @* begin
        // Convert signed to unsigned by adding 32768.  Use 17 bits to catch
        // overflow.
        unsigned17 = s16 + 17'sd32768;
        // Optional dither: simple 2-bit LFSR.  The phase of the dither
        // generator depends only on the LSBs of the input to avoid state.
        if (ENABLE_DITHER) begin
            // Seed with some bits of the input to decorrelate between
            // channels; note this is purely combinational.
            lfsr = {s16[1] ^ s16[0], s16[2] ^ s16[1]};
            // Form ±0.5 LSB in 12-bit domain: lfsr[1:0] ? {00,01,10,11} ?
            // values {0, +1, -1, 0}.  This approximates TPDF dither.
            case (lfsr)
                2'b01: unsigned17 = unsigned17 + 17'd1;
                2'b10: unsigned17 = unsigned17 - 17'd1;
                default: /* no offset */;
            endcase
        end
        // Round: add 8 (half of 16) then drop 4 LSBs.  Keep 13 bits to
        // facilitate saturation.
        rounded13 = (unsigned17 + 17'd8) >> 4;
        // Saturate to 0..4095 (12 bits).  If value exceeds 4095, clamp it.
        if (rounded13 > 13'd4095) begin
            u12 = 12'd4095;
        end else begin
            u12 = rounded13[11:0];
        end
    end

endmodule
