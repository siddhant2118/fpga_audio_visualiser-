`timescale 1ns / 1ps
//module data_reader(
//        input wire clk,
//        input wire [15:0] data,
//        output reg [16*256-1:0] flat
//    );
    
//    integer i = 0;
//    always @ (posedge clk) begin
//        flat[i*16+:16] <= data;
//        if (i >= 16) i <= 0;
//    end
    
//endmodule
module data_reader(
        input wire clk,
        input wire [15:0] data,
        output reg [16*256-1:0] flat
    );
    
    reg [7:0] i = 0;
    always @ (posedge clk) begin
        flat[i*16+:16] <= data;
        if (i == 8'd255) 
            i <= 0;
        else
            i <= i + 1;
    end
    
endmodule
