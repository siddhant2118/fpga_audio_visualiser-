`timescale 1ns / 1ps




module level_0_999(
    input  wire [15:0] level_u16, // 0..4095 in [11:0]
    output reg  [9:0]  val_999    // 0..999 fits in 10 bits
);
    wire [15:0] mid  = 16'd2048;
    wire [15:0] diff = (level_u16 >= mid) ? (level_u16 - mid) : (mid - level_u16);
    
    wire [31:0] prod = diff * 16'd1000;
    wire [20:0] q    = prod[31:11];
    always @* val_999 = (q > 21'd999) ? 10'd999 : q[9:0];
endmodule