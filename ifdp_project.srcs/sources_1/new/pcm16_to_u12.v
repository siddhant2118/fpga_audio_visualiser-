`timescale 1ns/1ps

module pcm16_to_u12 #(
    parameter ENABLE_DITHER = 0
)(
    input  wire signed [15:0] s16,
    output reg  [11:0]        u12
);

    reg  [16:0] unsigned17;
    reg  [12:0] rounded13;
    reg  [1:0]  lfsr;

    always @* begin

        unsigned17 = s16 + 17'sd32768;

        if (ENABLE_DITHER) begin
            lfsr = {s16[1] ^ s16[0], s16[2] ^ s16[1]};
            case (lfsr)
                2'b01: unsigned17 = unsigned17 + 17'd1;
                2'b10: unsigned17 = unsigned17 - 17'd1;
                default: unsigned17 = unsigned17;
            endcase
        end
        rounded13 = (unsigned17 + 17'd8) >> 4;
        if (rounded13 > 13'd4095) begin
            u12 = 12'd4095;
        end else begin
            u12 = rounded13[11:0];
        end
    end

endmodule
