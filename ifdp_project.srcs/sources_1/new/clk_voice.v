`timescale 1ns / 1ps
// clk_voice.v - 20 kHz sampling window; cs LOW during shift, HIGH between frames
module clk_voice(
    input  wire CLK,     // 100 MHz
    output reg  cs = 1'b1
);
    // 100e6 / 20e3 = 5000 cycles per period; give ~24 us LOW like common templates
    localparam integer PERIOD     = 5000;   // 50 us total at 20 kHz
    localparam integer LOW_CYCLES = 2400;   // ~24 us low covers all 16 SCLK toggles

    reg [12:0] ctr = 13'd0;
    always @(posedge CLK) begin
        ctr <= (ctr==PERIOD-1) ? 13'd0 : (ctr + 1'b1);
        cs  <= (ctr < LOW_CYCLES) ? 1'b0 : 1'b1;
    end
endmodule