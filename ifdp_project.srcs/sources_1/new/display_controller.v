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
    
    // FIX: More aggressive scaling for noisy/oscillating FFT bars
    // >> 9 was too sensitive, causing bars to max out and oscillate
    // >> 11 (divide by 2048) gives more stable, proportional bars
    wire [5:0] height = fft_mag[band_idx] >> 11;  // Scale to 0-63

    // Better waveform indexing: map 96 pixels to 256 samples
    wire [7:0] samp_idx_curr = (x_b << 8) / 96;  // Current sample index
    wire [7:0] samp_idx_next = ((x_b + 7'd1) << 8) / 96;  // Next column's sample index
    
    // Get current and next sample values
    wire signed [15:0] wave_curr_signed = wave_sample[samp_idx_curr];
    wire signed [15:0] wave_next_signed = (x_b < 95) ? wave_sample[samp_idx_next] : wave_curr_signed;
    
    // Convert both to unsigned and scale to 0-63 pixel range
    wire [16:0] wave_curr_unsigned = wave_curr_signed + 17'd32768;
    wire [16:0] wave_next_unsigned = wave_next_signed + 17'd32768;
    wire [5:0] samp_y_curr = wave_curr_unsigned[16:10];  // 0-63
    wire [5:0] samp_y_next = wave_next_unsigned[16:10];  // 0-63
    
    // Calculate line drawing between current and next sample
    // If samples are on same row, draw that row
    // If samples span multiple rows, draw all rows in between (vertical line segment)
    wire [5:0] y_min = (samp_y_curr < samp_y_next) ? samp_y_curr : samp_y_next;
    wire [5:0] y_max = (samp_y_curr > samp_y_next) ? samp_y_curr : samp_y_next;
    
    // Check if current pixel y-coordinate is on the line
    wire [5:0] y_b_inverted = 6'd63 - y_b;  // Invert y for comparison
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

        // Draw smooth waveform line (connects adjacent samples)
        if (on_waveform_line)
            colorB = 16'h0695;    // turquoise trace
        else
            colorB = 16'h0000;    // background black
    end


endmodule
