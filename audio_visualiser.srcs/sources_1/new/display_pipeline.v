`timescale 1ns/1ps
//
// Display Pipeline
// Dual OLED controller - FFT bars (OLED A) and waveform (OLED B)
//

module display_pipeline(
    input  wire clk,
    input wire [15:0] sw,

    input wire [15:0] fft_data,
    input wire fft_data_valid,      
    input wire [15:0] wave_data,
    input wire wave_data_valid,     

    output wire cs_a,
    output wire sdin_a,
    output wire sclk_a,
    output wire d_cn_a,
    output wire resn_a,
    output wire vccen_a,
    output wire pmoden_a,

    output wire cs_b,
    output wire sdin_b,
    output wire sclk_b,
    output wire d_cn_b,
    output wire resn_b,
    output wire vccen_b,
    output wire pmoden_b
);

    wire [16*256-1:0] fft_flat;
    wire [16*256-1:0] wave_flat;

    stream_to_array fft_reader(clk, fft_data, fft_data_valid, fft_flat);
    stream_to_array wave_reader(clk, wave_data, wave_data_valid, wave_flat);

    wire clk6p25mhz;
    clock_divider #(.WIDTH(32)) clk1(.clk(clk), .divisor(32'd7), .slow_clk(clk6p25mhz));

    wire clk10khz;
    clock_divider #(.WIDTH(32)) clk2(.clk(clk), .divisor(32'd4999), .slow_clk(clk10khz));
    wire [16*256-1:0] fft_suppressed;
    frequency_band_filter swman(clk10khz, sw, fft_flat, fft_suppressed);


    wire [12:0] pixel_index_a;
    wire [12:0] pixel_index_b;
    wire [15:0] pixel_data_a;
    wire [15:0] pixel_data_b;
    oled_graphics_engine disp_ctrl(
        .clk(clk),
        .fft_flat(fft_suppressed),
        .wave_flat(wave_flat),
        .pixel_index_a(pixel_index_a),
        .pixel_index_b(pixel_index_b),
        .colorA(pixel_data_a),
        .colorB(pixel_data_b)
    );
  
    Oled_Display oledA(.clk(clk6p25mhz),
                       .pixel_data(pixel_data_a),
                       .cs(cs_a),
                       .sdin(sdin_a),
                       .sclk(sclk_a),
                       .d_cn(d_cn_a),
                       .resn(resn_a),
                       .vccen(vccen_a),
                       .pmoden(pmoden_a),
                       .reset(0),
                       .frame_begin(),
                       .sending_pixels(),
                       .sample_pixel(),
                       .pixel_index(pixel_index_a));
              
    Oled_Display oledB(.clk(clk6p25mhz),
                       .pixel_data(pixel_data_b),
                       .cs(cs_b),
                       .sdin(sdin_b),
                       .sclk(sclk_b),
                       .d_cn(d_cn_b),
                       .resn(resn_b),
                       .vccen(vccen_b),
                       .pmoden(pmoden_b),
                       .reset(0),
                       .frame_begin(),
                       .sending_pixels(),
                       .sample_pixel(),
                       .pixel_index(pixel_index_b));
    
endmodule