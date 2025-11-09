`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 21:55:06
// Design Name: 
// Module Name: adsdad
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


// seg_scan4.v - scan right?left; leftmost stays blank via d3=4'hF
module seg_scan4(
    input  wire        clk,        // 100 MHz
    input  wire [3:0]  d3,         // leftmost
    input  wire [3:0]  d2,
    input  wire [3:0]  d1,
    input  wire [3:0]  d0,         // rightmost
    input  wire [3:0]  dp_mask,    // 1=off, 0=on per digit, active low output
    output reg  [3:0]  an,         // active low
    output reg  [6:0]  seg,        // active low
    output reg         dp          // active low
);
    localparam integer DIV = 100_000_000 / 4000; // ~1 kHz per digit
    reg [$clog2(DIV)-1:0] ctr = 0;
    reg [1:0] idx = 0;

    wire [6:0] seg_d3, seg_d2, seg_d1, seg_d0;
    seven_segment U3(.val(d3), .seg(seg_d3));
    seven_segment U2(.val(d2), .seg(seg_d2));
    seven_segment U1(.val(d1), .seg(seg_d1));
    seven_segment U0(.val(d0), .seg(seg_d0));

    always @(posedge clk) begin
        ctr <= (ctr==DIV-1) ? 0 : ctr+1;
        if (ctr==0) idx <= idx + 2'd1;

        // defaults off
        an  <= 4'b1111;
        seg <= 7'b1111111;
        dp  <= 1'b1; // off

        case (idx)
            2'd0: begin an<=4'b1110; seg<=seg_d0; dp<=dp_mask[0]; end // rightmost
            2'd1: begin an<=4'b1101; seg<=seg_d1; dp<=dp_mask[1]; end
            2'd2: begin an<=4'b1011; seg<=seg_d2; dp<=dp_mask[2]; end
            2'd3: begin an<=4'b0111; seg<=seg_d3; dp<=dp_mask[3]; end // leftmost
        endcase
    end
endmodule