`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.11.2025 00:28:19
// Design Name: 
// Module Name: top_adhavan
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module top_adhavan #(
    parameter integer SYS_CLK_HZ = 100_000_000,
    parameter integer FS_HZ      = 20_000
)(
    input  wire        clk,
    input  wire        reset,
    
    input  wire        frame_done,     // from Member 1
    input  wire [11:0] m2_rd_data,      // from Member 1's BRAM
    output reg  [7:0]  m2_rd_addr,      // address to Member 1's BRAM
    
    output wire [15:0] inter_out,

    input  wire [15:0] sw,             // 16 switches for filtering control
    output reg  [15:0] fft_data = 0,        // FFT magnitude output (one bin per clock)
    output reg  [15:0] wave_data = 0,       // Waveform output (one sample per clock)
    output reg  fft_data_valid = 0,     // Valid signal for fft_data
    output reg  wave_data_valid = 0,    // Valid signal for wave_data
    output wire [15:0] out_audio,      // Final output after IFFT
    output wire        out_valid
);

// ----------------------------
// Sample buffer + read control
// ----------------------------
reg        reading_frame = 0;
reg [7:0]  sample_idx     = 0;
reg [15:0] sample_buffer_real [0:255];  // real part, 16-bit
reg        buffer_full    = 0;

always @(posedge clk) begin
    if (reset) begin
        m2_rd_addr    <= 0;
        sample_idx    <= 0;
        reading_frame <= 0;
        buffer_full   <= 0;
    end else begin
        if (frame_done && !reading_frame) begin
            reading_frame <= 1;
            m2_rd_addr    <= 0;
            sample_idx    <= 0;
            buffer_full   <= 0;
        end else if (reading_frame) begin
            // Capture sample into local buffer
            sample_buffer_real[sample_idx] <= { {4{m2_rd_data[11]}}, m2_rd_data };  // sign-extend to 16-bit
            sample_idx    <= sample_idx + 1;
            m2_rd_addr    <= m2_rd_addr + 1;

            if (sample_idx == 8'd255) begin
                reading_frame <= 0;
                buffer_full   <= 1;  // Trigger FFT processing
            end
        end else if (buffer_full && !fft_feeding) begin
            // Clear buffer_full when FFT feeding is about to start
            buffer_full <= 0;
        end
    end
end

// ----------------------------
// FFT Feeding Logic
// ----------------------------
reg [7:0] fft_idx = 0;
reg       fft_feeding = 0;
reg       fft_ce = 0;

wire [31:0] fft_in_sample = {sample_buffer_real[fft_idx], 16'd0};  // real + 0j

wire [31:0] fft_out_sample;
wire        fft_sync;

fftmain u_fft (
    .i_clk    (clk),
    .i_reset  (reset),
    .i_ce     (fft_ce),
    .i_sample (fft_in_sample),
    .o_result (fft_out_sample),
    .o_sync   (fft_sync)
);

assign inter_out = fft_out_sample[31:16];

// Feed FFT when buffer is full
always @(posedge clk) begin
    if (reset) begin
        fft_idx     <= 0;
        fft_ce      <= 0;
        fft_feeding <= 0;
    end else begin
        if (buffer_full && !fft_feeding) begin
            fft_feeding <= 1;
            fft_idx     <= 0;
            fft_ce      <= 1;
        end else if (fft_feeding) begin
            if (fft_idx == 8'd255) begin
                fft_ce      <= 0;
                fft_feeding <= 0;
            end else begin
                fft_idx <= fft_idx + 1;
            end
        end
    end
end

    // ----------------------------
    // FFT Magnitude Calculation
    // ----------------------------
    wire signed [15:0] fft_re = fft_out_sample[31:16];
    wire signed [15:0] fft_im = fft_out_sample[15:0];
    wire [15:0] fft_re_abs = fft_re[15] ? (~fft_re + 1) : fft_re;
    wire [15:0] fft_im_abs = fft_im[15] ? (~fft_im + 1) : fft_im;
    wire [15:0] fft_mag_approx = fft_re_abs + fft_im_abs;  // L1 norm approximation

    // ----------------------------
    // Frequency Domain Filtering (combine with collection)
    // ----------------------------
    wire [3:0] filt_group_sel = fft_out_idx[7:4];  // Use collection index
    wire filt_band_enable = sw[filt_group_sel];
    wire signed [15:0] filt_re = filt_band_enable ? fft_re : 16'sd0;
    wire signed [15:0] filt_im = filt_band_enable ? fft_im : 16'sd0;

  // ----------------------------
    // FFT Output Collection and Storage
    // ----------------------------
    reg [7:0] fft_out_idx = 0;
    reg [15:0] fft_magnitude_buffer [0:255];
    reg [31:0] filtered_fft_buffer [0:255];  // Store {real, imag}
    reg fft_collecting = 0;
    reg fft_output_ready = 0;
    reg [7:0] fft_output_idx = 0;
    reg fft_outputting = 0;
    reg filtering_complete = 0;
    
    always @(posedge clk) begin
        if (reset) begin
            fft_out_idx <= 0;
            fft_collecting <= 0;
            fft_output_ready <= 0;
            fft_outputting <= 0;
            filtering_complete <= 0;
            fft_data_valid <= 0;
        end else begin
            if (fft_sync) begin
                // FFT sync indicates first output is ready
                fft_collecting <= 1;
                fft_out_idx <= 0;
                fft_output_ready <= 0;
                filtering_complete <= 0;
            end else if (fft_collecting) begin
                // Collect FFT outputs (one per cycle after sync)
                fft_magnitude_buffer[fft_out_idx] <= fft_mag_approx;
                filtered_fft_buffer[fft_out_idx] <= {filt_re, filt_im};
                fft_out_idx <= fft_out_idx + 1;
                
                if (fft_out_idx == 8'd255) begin
                    fft_collecting <= 0;
                    fft_output_ready <= 1;
                    fft_output_idx <= 0;
                    fft_outputting <= 1;
                    filtering_complete <= 1;
                end
            end else if (fft_outputting) begin
                // Output FFT magnitudes sequentially
                fft_data <= fft_magnitude_buffer[fft_output_idx];
                fft_data_valid <= 1;
                fft_output_idx <= fft_output_idx + 1;
                if (fft_output_idx == 8'd255) begin
                    fft_outputting <= 0;
                    fft_output_ready <= 0;
                    fft_data_valid <= 0;
                end
            end else if (filtering_complete && !ifft_feeding) begin
                // Clear filtering_complete when IFFT feeding is about to start
                filtering_complete <= 0;
                fft_data_valid <= 0;
            end else begin
                fft_data_valid <= 0;
            end
        end
    end
    
    // ----------------------------
    // IFFT Input Control
    // ----------------------------
    reg [7:0] ifft_in_idx = 0;
    reg ifft_feeding = 0;
    reg ifft_ce = 0;
    wire [31:0] ifft_in_sample = filtered_fft_buffer[ifft_in_idx];
    
    // Feed IFFT after filtering is complete
    always @(posedge clk) begin
        if (reset) begin
            ifft_in_idx <= 0;
            ifft_ce <= 0;
            ifft_feeding <= 0;
        end else begin
            if (filtering_complete && !ifft_feeding) begin
                ifft_feeding <= 1;
                ifft_in_idx <= 0;
                ifft_ce <= 1;
            end else if (ifft_feeding) begin
                if (ifft_in_idx == 8'd255) begin
                    ifft_ce <= 0;
                    ifft_feeding <= 0;
                end else begin
                    ifft_in_idx <= ifft_in_idx + 1;
                end
            end
        end
    end
    
    // ----------------------------
    // IFFT
    // ----------------------------
    wire [31:0] ifft_out_sample;
    wire        ifft_sync;

    ifftmain u_ifft (
        .i_clk    (clk),
        .i_reset  (reset),
        .i_ce     (ifft_ce),
        .i_sample (ifft_in_sample),
        .o_result (ifft_out_sample),
        .o_sync   (ifft_sync)
    );

    // ----------------------------
    // IFFT Output Collection
    // ----------------------------
    reg [7:0] ifft_out_idx = 0;
    reg [15:0] waveform_buffer [0:255];
    reg ifft_collecting = 0;
    reg waveform_ready = 0;
    reg [7:0] waveform_output_idx = 0;
    reg waveform_outputting = 0;

    always @(posedge clk) begin
        if (reset) begin
            ifft_out_idx <= 0;
            ifft_collecting <= 0;
            waveform_ready <= 0;
            waveform_outputting <= 0;
            wave_data_valid <= 0;
        end else begin
            if (ifft_sync) begin
                ifft_collecting <= 1;
                ifft_out_idx <= 0;
                waveform_ready <= 0;
            end else if (ifft_collecting) begin
                // Collect IFFT outputs (one per cycle after sync)
                waveform_buffer[ifft_out_idx] <= ifft_out_sample[31:16];  // Real part
                ifft_out_idx <= ifft_out_idx + 1;
                if (ifft_out_idx == 8'd255) begin
                    ifft_collecting <= 0;
                    waveform_ready <= 1;
                    waveform_output_idx <= 0;
                    waveform_outputting <= 1;
                end
            end else if (waveform_outputting) begin
                // Output waveform samples sequentially
                wave_data <= waveform_buffer[waveform_output_idx];
                wave_data_valid <= 1;
                waveform_output_idx <= waveform_output_idx + 1;
                if (waveform_output_idx == 8'd255) begin
                    waveform_outputting <= 0;
                    waveform_ready <= 0;
                    wave_data_valid <= 0;
                end
            end else begin
                wave_data_valid <= 0;
            end
        end
    end

    assign out_audio = ifft_out_sample[31:16];  // Real part
    assign out_valid = ifft_ce;  // Valid when IFFT is being fed

endmodule