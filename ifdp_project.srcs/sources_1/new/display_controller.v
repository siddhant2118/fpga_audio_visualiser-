`timescale 1ns/1ps
module display_controller(
    input  wire        clk,
    input  wire [16*256-1:0] fft_flat,
    input  wire [16*256-1:0] wave_flat,
    input  wire [12:0] pixel_index_a,   
    input  wire [12:0] pixel_index_b,
    
    output reg  [15:0] colorA,
    output reg  [15:0] colorB
);
    
    wire clk30hz;
    clock_div clk1(clk, 1666666, clk30hz);
    wire [16*256-1:0] fft_buffered;
    wire [16*256-1:0] wave_buffered;
    frame_buffer fft(clk30hz, fft_flat, fft_buffered);
    frame_buffer wave(clk30hz, wave_flat, wave_buffered);

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

    // Better band indexing: map 96 pixels to 16 bands (each band = 6 pixels wide)
    // Each band gets 16 FFT bins (256 bins / 16 bands = 16 bins/band)
    wire [3:0] band_num = x_a / 6;  // 0-15 (16 bands)
    wire [7:0] band_idx = {band_num, 4'b0000};  // band_num * 16
    
    // FIX: More aggressive scaling for FFT magnitude
    // Original: >> 10 (divide by 1024) - might be too much scaling
    // Try: >> 8 (divide by 256) for more visible bars
    wire [4:0] height = fft_mag[band_idx] >> 9;  // Scale to 0-63

    // Better waveform indexing: map 96 pixels to 256 samples
    wire [7:0] samp_idx = (x_b << 8) / 96;  // (x_b * 256) / 96
    
    // FIX: Convert signed 16-bit to unsigned, then scale to 0-63
    // Signed range: -32768 to +32767
    // Add 32768 to make unsigned: 0 to 65535
    // Then scale to 0-63: divide by 1024 (right shift 10)
    wire signed [15:0] wave_signed = wave_sample[samp_idx];
    wire [16:0] wave_unsigned = wave_signed + 17'd32768;  // Convert to unsigned (17 bits to avoid overflow)
    wire [5:0] samp_y = wave_unsigned[16:10];  // Scale to 0-63 (divide by 1024)


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

        if (y_b == (63 - samp_y))
            colorB = 16'h0695;    // turquoise trace
        else
            colorB = 16'h0000;    // background black
    end


endmodule
