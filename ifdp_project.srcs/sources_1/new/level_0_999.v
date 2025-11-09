`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 21:54:41
// Design Name: 
// Module Name: asdasd
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
// 
//////////////////////////////////////////////////////////////////////////////////


// level_0_999.v - map unsigned 12-bit level around mid (2048) to 0..999
module level_0_999(
    input  wire [15:0] level_u16, // 0..4095 in [11:0]
    output reg  [9:0]  val_999    // 0..999 fits in 10 bits
);
    wire [15:0] mid  = 16'd2048;
    wire [15:0] diff = (level_u16 >= mid) ? (level_u16 - mid) : (mid - level_u16);
    // 0..2047 ? 0..999 using multiply then >>11 (since 2048 = 2^11)
    wire [31:0] prod = diff * 16'd1000;
    wire [20:0] q    = prod[31:11];
    always @* val_999 = (q > 21'd999) ? 10'd999 : q[9:0];
endmodule