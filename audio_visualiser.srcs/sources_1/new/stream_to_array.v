`timescale 1ns / 1ps
//
// Stream to Array Converter
// Collects 256 streaming samples into packed array
//

module stream_to_array(
        input wire clk,
        input wire [15:0] data,
        input wire data_valid,       
        output reg [16*256-1:0] flat
    );

    reg [7:0] i = 0;
    always @ (posedge clk) begin
        if (data_valid) begin       
            flat[i*16+:16] <= data;
            if (i == 8'd255)
                i <= 0;
            else
                i <= i + 1;
        end
    end

endmodule