`timescale 1ns / 1ps
//
// Sample Buffer RAM
// Dual-port block RAM for 256 audio samples (12-bit)
//

module sample_buffer_ram #(
    parameter integer N_SAMPLES = 256
)(
    input  wire        clk,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,
    input  wire [11:0] wr_data,
    input  wire [7:0]  rd_addr,
    output reg  [11:0] rd_data
);
    reg [11:0] mem [0:N_SAMPLES-1];
    always @(posedge clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
        rd_data <= mem[rd_addr];
    end
endmodule