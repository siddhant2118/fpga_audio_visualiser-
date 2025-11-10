`timescale 1ns / 1ps


module frame_packer #(
    parameter integer N_SAMPLES = 256
)(
    input  wire        clk,
    input  wire        s_valid,           
    input  wire [11:0] s_data,            
    output reg         wr_en = 1'b0,
    output reg  [7:0]  wr_addr = 8'd0,
    output reg  [11:0] wr_data = 12'd0,
    output reg         frame_done = 1'b0  
    always @(posedge clk) begin
        wr_en      <= 1'b0;
        frame_done <= 1'b0;

        if (s_valid) begin
            wr_en   <= 1'b1;
            wr_data <= s_data;

            if (wr_addr == N_SAMPLES-1) begin
                wr_addr    <= 8'd0;
                frame_done <= 1'b1;       
            end else begin
                wr_addr <= wr_addr + 1'b1;
            end
        end
    end
endmodule