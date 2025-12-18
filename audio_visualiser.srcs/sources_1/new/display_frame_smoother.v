`timescale 1ns / 1ps
//
// Display Frame Smoother
// Exponential moving average filter (87.5% history, 12.5% new) to reduce flicker
//

module display_frame_smoother(
        input wire clk,
        input wire [16*256-1:0] array,
        output reg [16*256-1:0] buffered_array 
    );
    
    integer i;
    always @ (posedge clk) begin
        for (i = 0; i < 256; i = i + 1) begin
            buffered_array[i*16 +:16] <= (buffered_array[i*16 +:16] * 7 + array[i*16 +:16]) / 8;
        end
    end
    
endmodule