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
    wire fft_data_valid;        // NEW: valid signal from adhavan
    wire [15:0] wave_data;
    wire wave_data_valid;       // NEW: valid signal from adhavan

    wire [7:0]  m2_rd_addr;
    wire [11:0] m2_rd_data;
    wire frame_done;

    top_rehaan rehaan(clk, sw, fft_data, fft_data_valid, wave_data, wave_data_valid,
                      JA[0], JA[1], JA[3], JA[4], JA[5], JA[6], JA[7],
                      JB[0], JB[1], JB[3], JB[4], JB[5], JB[6], JB[7]);

    // Use wave_data_valid as wr_valid for audio output
    top_manu manu(clk, 1, wave_data_valid, wave_data, 1, 0, JC[0], JC[3], JC[1], JC[2]);

    top_sidu sidu(clk, J_MIC3_Pin3, J_MIC3_Pin1, J_MIC3_Pin4, led, an, seg, dp, m2_rd_addr, m2_rd_data, frame_done);

    // Port order: clk, reset, frame_done, m2_rd_data, m2_rd_addr, inter_out, sw,
    //             fft_data, wave_data, fft_data_valid, wave_data_valid, out_audio, out_valid
    wire [15:0] inter_out;  // unused debug output
    wire [15:0] out_audio;  // unused audio output
    wire out_valid;         // unused valid signal

    // FIXED: Now using real FFT with correct 64-bit port connections
    top_adhavan adhavan(clk, 0, frame_done, m2_rd_data, m2_rd_addr, inter_out, sw,
                        fft_data, wave_data, fft_data_valid, wave_data_valid, out_audio, out_valid);
    
endmodule
