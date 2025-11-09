`timescale 1ns / 1ps
module top(
    input wire clk,
    input wire [15:0] sw,
    input  wire J_MIC3_Pin3,
    output wire J_MIC3_Pin1,
    output wire J_MIC3_Pin4,
    output wire [7:0] JA, JB, JC,
    output wire [15:0] led,
    output wire [6:0] seg,
    output wire dp,
    output wire [3:0] an
    );
    
    wire [15:0] fft_data;
    wire [15:0] wave_data;
    wire wr_valid;
    
    wire [7:0]  m2_rd_addr;
    wire [11:0] m2_rd_data;
    wire frame_done;
    
    top_rehaan rehaan(clk, sw, fft_data, wave_data, JA[0], JA[1], JA[3], JA[4], JA[5], JA[6], JA[7],  // wave_flat and fft_flat come from adhavan
                                                    JB[0], JB[1], JB[3], JB[4], JB[5], JB[6], JB[7]);    
    
    top_manu manu(clk, 1, wr_valid, wave_data, 1, 0, JC[0], JC[3], JC[1], JC[2]);
    
    top_sidu sidu(clk, J_MIC3_Pin3, J_MIC3_Pin1, J_MIC3_Pin4, led, an, seg, dp, m2_rd_addr, m2_rd_data, frame_done);
    
    top_adhavan adhavan(clk, 0, frame_done, m2_rd_data, m2_rd_addr, fft_data, sw, wave_data, wr_valid);
    
endmodule
