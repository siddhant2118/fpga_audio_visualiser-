`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.11.2025 18:52:46
// Design Name: 
// Module Name: j
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


// frame_packer.v : collects streaming samples into a frame.
// When it fills N_SAMPLES, pulses frame_done and wraps.
`timescale 1ns / 1ps
// frame_packer.v - collects 256 samples, asserts frame_done when full
module frame_packer #(
    parameter integer N_SAMPLES = 256
)(
    input  wire        clk,
    input  wire        s_valid,           // 1-cycle pulse per new sample
    input  wire [11:0] s_data,            // 12-bit mic sample
    output reg         wr_en = 1'b0,
    output reg  [7:0]  wr_addr = 8'd0,
    output reg  [11:0] wr_data = 12'd0,
    output reg         frame_done = 1'b0  // 1-cycle pulse when buffer wraps
);
    always @(posedge clk) begin
        wr_en      <= 1'b0;
        frame_done <= 1'b0;

        if (s_valid) begin
            wr_en   <= 1'b1;
            wr_data <= s_data;

            if (wr_addr == N_SAMPLES-1) begin
                wr_addr    <= 8'd0;
                frame_done <= 1'b1;       // full frame written
            end else begin
                wr_addr <= wr_addr + 1'b1;
            end
        end
    end
endmodule