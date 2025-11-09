`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 04:43:35
// Design Name: 
// Module Name: clock_divider
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//////////////////////////////////////////////////////////////////////////////////


module clock_divider(input wire clk, input wire [31:0] reqtime, output reg slow_clk = 1'b0);

integer internal_count = 0;

always @ (posedge clk) begin
    internal_count <= (internal_count >= reqtime) ? 0 : internal_count + 1;
    slow_clk <= (internal_count == 0) ? ~slow_clk : slow_clk;
end

endmodule