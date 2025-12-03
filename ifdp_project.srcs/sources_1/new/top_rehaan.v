`timescale 1ns/1ps
module top_rehaan(
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

    data_reader fft_reader(clk, fft_data, fft_data_valid, fft_flat);
    data_reader wave_reader(clk, wave_data, wave_data_valid, wave_flat);

    wire clk6p25mhz;
    clock_div clk1(clk, 7, clk6p25mhz);


    wire clk10khz;
    clock_div clk2(clk, 4999, clk10khz);
    wire [16*256-1:0] fft_suppressed;
    switch_manager swman(clk10khz, sw, fft_flat, fft_suppressed);


    wire [12:0] pixel_index_a;
    wire [12:0] pixel_index_b;
    wire [15:0] pixel_data_a;
    wire [15:0] pixel_data_b;
    display_controller disp_ctrl(
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
