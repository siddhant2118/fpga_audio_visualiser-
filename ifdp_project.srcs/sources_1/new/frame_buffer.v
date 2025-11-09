`timescale 1ns / 1ps
module frame_buffer(
        input wire clk,
        input wire [16*256-1:0] array,
        output reg [16*256-1:0] buffered_array 
    );
    
    // Temporal smoothing to reduce oscillation/flicker
    // Use exponential moving average: new_val = (old_val * 7 + new_val) / 8
    // This gives 87.5% weight to history, 12.5% to new data
    // Creates smooth transitions and reduces rapid fluctuations
    
    integer i;
    always @ (posedge clk) begin
        for (i = 0; i < 256; i = i + 1) begin
            // Extract 16-bit samples
            buffered_array[i*16 +:16] <= (buffered_array[i*16 +:16] * 7 + array[i*16 +:16]) / 8;
        end
    end
    
endmodule
