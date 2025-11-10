`timescale 1ns / 1ps

module clk_voice(
    input  wire CLK,     
    output reg  cs = 1'b1
);
    
    localparam integer PERIOD     = 5000;   
    localparam integer LOW_CYCLES = 2400;   

    reg [12:0] ctr = 13'd0;
    always @(posedge CLK) begin
        ctr <= (ctr==PERIOD-1) ? 13'd0 : (ctr + 1'b1);
        cs  <= (ctr < LOW_CYCLES) ? 1'b0 : 1'b1;
    end
endmodule