
`timescale 1ns/1ps
//
// PCM16 to U12 Converter
// Signed 16-bit PCM to unsigned 12-bit DAC format
//

module pcm16_to_u12(
    input  wire signed [15:0] s16,
    output reg  [11:0]        u12
);

    reg [16:0] unsigned17;
    reg [12:0] rounded13;

    always @* begin
        unsigned17 = s16 + 17'sd32768;
        
        // Round: add 0.5 LSB (8) then shift right by 4 bits
        rounded13 = (unsigned17 + 17'd8) >> 4;
        
        // Saturate to 12-bit range (0-4095)
        if (rounded13 > 13'd4095) begin
            u12 = 12'd4095;
        end else begin
            u12 = rounded13[11:0];
        end
    end

endmodule
