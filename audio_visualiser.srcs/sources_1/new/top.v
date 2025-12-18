`timescale 1ns / 1ps
//
// FPGA Audio Visualizer - Top Level
// Basys3 + MIC3 + Dual OLEDrgb + DA2
// 256-point FFT, 20 kHz sampling, 16-band visualization
//

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
    wire fft_data_valid;
    wire [15:0] wave_data;
    wire wave_data_valid;

    wire [7:0]  m2_rd_addr;
    wire [11:0] m2_rd_data;
    wire frame_done;

    display_pipeline display(
        .clk(clk), 
        .sw(sw), 
        .fft_data(fft_data), 
        .fft_data_valid(fft_data_valid), 
        .wave_data(wave_data), 
        .wave_data_valid(wave_data_valid),
        .cs_a(JA[0]), .sdin_a(JA[1]), .sclk_a(JA[3]), 
        .d_cn_a(JA[4]), .resn_a(JA[5]), .vccen_a(JA[6]), .pmoden_a(JA[7]),
        .cs_b(JB[0]), .sdin_b(JB[1]), .sclk_b(JB[3]), 
        .d_cn_b(JB[4]), .resn_b(JB[5]), .vccen_b(JB[6]), .pmoden_b(JB[7])
    );

    audio_output_pipeline output_dac(
        .clk(clk), 
        .rst_n(1'b1),
        .wr_valid(wave_data_valid), 
        .wr_data(wave_data), 
        .ramp_up(1'b1),      // Always ramp up (anti-pop)
        .ramp_down(1'b0),    // Never ramp down
        .sync_n(JC[0]), 
        .sclk(JC[3]), 
        .dina(JC[1]), 
        .dinb(JC[2])
    );

    audio_input_pipeline input_mic(
        .clk(clk), 
        .J_MIC3_Pin3(J_MIC3_Pin3), 
        .J_MIC3_Pin1(J_MIC3_Pin1), 
        .J_MIC3_Pin4(J_MIC3_Pin4), 
        .led(led), 
        .an(an), 
        .seg(seg), 
        .dp(dp), 
        .m2_rd_addr(m2_rd_addr), 
        .m2_rd_data(m2_rd_data), 
        .frame_done(frame_done)
    );

    wire [15:0] inter_out;
    wire [15:0] out_audio;
    wire out_valid;

    fft_processor fft_engine(
        .clk(clk), 
        .reset(1'b0), 
        .frame_done(frame_done), 
        .m2_rd_data(m2_rd_data), 
        .m2_rd_addr(m2_rd_addr), 
        .inter_out(inter_out), 
        .sw(sw),
        .fft_data(fft_data), 
        .wave_data(wave_data), 
        .fft_data_valid(fft_data_valid), 
        .wave_data_valid(wave_data_valid), 
        .out_audio(out_audio), 
        .out_valid(out_valid)
    );
    
endmodule