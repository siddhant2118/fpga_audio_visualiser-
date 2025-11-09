`timescale 1ns / 1ps
module frame_buffer(
        input wire clk,
        input wire [16*256-1:0] array,
        output reg [16*256-1:0] buffered_array 
    );
    
    always @ (posedge clk)
        buffered_array <= array;
    
endmodule
