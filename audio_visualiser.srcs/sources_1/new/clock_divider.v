
`timescale 1ns / 1ps
//
// Clock Divider
// Parameterized clock divider - toggles output every 'divisor' cycles
//

module clock_divider #(
    parameter integer WIDTH = 32
)(
    input wire clk,
    input wire [WIDTH-1:0] divisor,
    output reg slow_clk = 1'b0
);
    reg [WIDTH-1:0] counter = 0;
    
    always @(posedge clk) begin
        if (counter >= divisor) begin
            counter <= 0;
            slow_clk <= ~slow_clk;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule
