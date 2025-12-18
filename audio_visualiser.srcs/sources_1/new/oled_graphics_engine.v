`timescale 1ns/1ps
//
// OLED Graphics Engine
// Pixel-by-pixel rendering for FFT bars and waveform display
//

module oled_graphics_engine(
    input  wire        clk,
    input  wire [16*256-1:0] fft_flat,
    input  wire [16*256-1:0] wave_flat,
    input  wire [12:0] pixel_index_a,   
    input  wire [12:0] pixel_index_b,
    
    output reg  [15:0] colorA,
    output reg  [15:0] colorB
);
    
    wire clk30hz;
    clock_divider #(.WIDTH(64)) clk1(.clk(clk), .divisor(64'd1666666), .slow_clk(clk30hz));
    wire [16*256-1:0] fft_buffered;
    wire [16*256-1:0] wave_buffered;
    display_frame_smoother fft(clk30hz, fft_flat, fft_buffered);
    display_frame_smoother wave(clk30hz, wave_flat, wave_buffered);

    wire [5:0] y_a = 63 - (pixel_index_a / 96);
    wire [6:0] x_a = 95 - (pixel_index_a % 96);
    wire [5:0] y_b = pixel_index_b / 96;
    wire [6:0] x_b = pixel_index_b % 96;

    integer i;
    reg [15:0] fft_mag [0:255];
    reg [15:0] wave_sample [0:255];

    always @ (*) begin
        for (i = 0; i < 256; i = i + 1)
            fft_mag[i] = fft_buffered[i*16 +:16];
        for (i = 0; i < 256; i = i + 1)
            wave_sample[i] = wave_buffered[i*16 +:16];
    end

    wire [3:0] band_num = x_a / 6;
    wire [7:0] band_idx = {band_num, 4'b0000};
    
    wire [8:0] height = fft_mag[band_idx] >> 8;

    wire [7:0] samp_idx_curr = (x_b << 8) / 96;
    wire [7:0] samp_idx_next = ((x_b + 7'd1) << 8) / 96;
    
    wire signed [15:0] wave_curr_signed = wave_sample[samp_idx_curr];
    wire signed [15:0] wave_next_signed = (x_b < 95) ? wave_sample[samp_idx_next] : wave_curr_signed;
    
    wire [16:0] wave_curr_unsigned = wave_curr_signed + 17'd32768;
    wire [16:0] wave_next_unsigned = wave_next_signed + 17'd32768;
    wire [5:0] samp_y_curr = wave_curr_unsigned[16:10];
    wire [5:0] samp_y_next = wave_next_unsigned[16:10];
    
    wire [5:0] y_min = (samp_y_curr < samp_y_next) ? samp_y_curr : samp_y_next;
    wire [5:0] y_max = (samp_y_curr > samp_y_next) ? samp_y_curr : samp_y_next;
    
    wire [5:0] y_b_inverted = 6'd63 - y_b;
    wire on_waveform_line = (y_b_inverted >= y_min) && (y_b_inverted <= y_max);


    always @ (*) begin
        if ((63 - y_a) < height) begin
//            if (y_a <= 31)
//                colorA = {5'b11111, y_a << 1, 5'b00000};    // red-yellow gradient
//            else
//                colorA = {63 - y_a, 6'b111111, 5'b00000};   // yellow-green gradient
            colorA = {63 - y_a >> 1, 6'b000000, 5'b11111};    // blue-magenta gradient
            if (x_a % 6 == 5) colorA = 16'h0000;            // 1px wide gap between the bars
            if ((x_a % 6 == 0 || x_a % 6 == 4) && (64 - y_a == height)) colorA = 16'h0000;    // rounded corners
        end else
            colorA = 16'h0000;    // background black

        
        if (on_waveform_line)
            colorB = 16'h0695;    // turquoise trace
        else
            colorB = 16'h0000;    // background black
    end


endmodule