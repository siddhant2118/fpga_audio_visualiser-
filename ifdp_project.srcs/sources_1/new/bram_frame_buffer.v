`timescale 1ns / 1ps
// bram_frame_buffer.v : simple 1-port write, 1-port async read (same clock)
`timescale 1ns / 1ps
// bram_frame_buffer.v - 256 x 12, single-clock, sync read
module bram_frame_buffer #(
    parameter integer N_SAMPLES = 256
)(
    input  wire        clk,
    input  wire        wr_en,
    input  wire [7:0]  wr_addr,   // 0..255
    input  wire [11:0] wr_data,
    input  wire [7:0]  rd_addr,   // Member 2 will read 0..255
    output reg  [11:0] rd_data
);
    reg [11:0] mem [0:N_SAMPLES-1];
    always @(posedge clk) begin
        if (wr_en) mem[wr_addr] <= wr_data;
        rd_data <= mem[rd_addr];
    end
endmodule