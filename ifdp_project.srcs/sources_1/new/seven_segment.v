`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 20:10:42
// Design Name: 
// Module Name: as
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


// sevenseg_dec_0to9.v - common-anode 7-seg decoder for 0..9
// seven_segment.v  - common-anode, active-low. 0..9 valid. 4'hF = BLANK.
module seven_segment(
    input wire [3:0] val,
    output reg [6:0] seg  // a..g, active low
);
    always @* begin
        case (val)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hF: seg = 7'b1111111; // BLANK
            default: seg = 7'b1111111;
        endcase
    end
endmodule