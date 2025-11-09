`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// DEBUG VERSION: top_adhavan WITHOUT FFT IPs
// 
// This version simulates FFT/IFFT behavior for testing without needing IP cores
// Use this to verify:
//   1. BRAM reading works correctly
//   2. State machine transitions properly
//   3. Data formatting is correct
//   4. Output valid signals work
//
// If this works in hardware, problem is FFT IP configuration
// If this fails, problem is in state machine or data flow
//////////////////////////////////////////////////////////////////////////////////

module top_adhavan_debug #(
    parameter integer SYS_CLK_HZ = 100_000_000,
    parameter integer FS_HZ      = 20_000
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        frame_done,
    input  wire [11:0] m2_rd_data,
    output reg  [7:0]  m2_rd_addr,

    output wire [15:0] inter_out,

    input  wire [15:0] sw,
    output reg  [15:0] fft_data = 0,
    output reg  [15:0] wave_data = 0,
    output reg  fft_data_valid = 0,
    output reg  wave_data_valid = 0,
    output wire [15:0] out_audio,
    output wire        out_valid
);

// ============================================================================
// State Machine
// ============================================================================
localparam IDLE           = 4'd0;
localparam READ_SAMPLES   = 4'd1;
localparam FAKE_FFT       = 4'd2;  // Simulate FFT processing
localparam OUTPUT_FFT_MAG = 4'd3;
localparam OUTPUT_WAVEFORM = 4'd4;

reg [3:0] state = IDLE;
reg [8:0] counter = 0;  // 9 bits for counting up to 256+

// ============================================================================
// Sample Buffer
// ============================================================================
reg [15:0] sample_buffer [0:255];

// ============================================================================
// Main State Machine
// ============================================================================
always @(posedge clk) begin
    if (reset) begin
        state           <= IDLE;
        counter         <= 0;
        m2_rd_addr      <= 0;
        fft_data_valid  <= 0;
        wave_data_valid <= 0;
    end else begin
        // Default: de-assert valid signals
        fft_data_valid  <= 0;
        wave_data_valid <= 0;

        case (state)
            IDLE: begin
                counter <= 0;
                if (frame_done) begin
                    state      <= READ_SAMPLES;
                    m2_rd_addr <= 0;
                end
            end

            // Read 256 samples from BRAM
            READ_SAMPLES: begin
                if (counter == 0) begin
                    m2_rd_addr <= 0;
                    counter    <= counter + 1;
                end else if (counter <= 256) begin
                    // Sign-extend 12-bit to 16-bit
                    sample_buffer[counter-1] <= { {4{m2_rd_data[11]}}, m2_rd_data };
                    m2_rd_addr               <= m2_rd_addr + 1;
                    counter                  <= counter + 1;

                    if (counter == 256) begin
                        state   <= FAKE_FFT;
                        counter <= 0;
                    end
                end
            end

            // Simulate FFT: just scale samples to create "magnitude"
            FAKE_FFT: begin
                counter <= counter + 1;
                
                // Simulate some processing delay (like real FFT)
                if (counter > 300) begin  // 300 cycle delay
                    state   <= OUTPUT_FFT_MAG;
                    counter <= 0;
                end
            end

            // Output "FFT magnitude" - just absolute value of samples
            OUTPUT_FFT_MAG: begin
                // Create fake FFT magnitude from sample absolute value
                wire signed [15:0] sample_signed = sample_buffer[counter];
                wire [15:0] abs_val = sample_signed[15] ? (~sample_signed + 1) : sample_signed;
                
                fft_data       <= abs_val >> 4;  // Scale down for display
                fft_data_valid <= 1'b1;

                if (counter == 255) begin
                    state   <= OUTPUT_WAVEFORM;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end

            // Output waveform - just echo input samples
            OUTPUT_WAVEFORM: begin
                wave_data       <= sample_buffer[counter];
                wave_data_valid <= 1'b1;

                if (counter == 255) begin
                    state   <= IDLE;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

// ============================================================================
// Debug Outputs
// ============================================================================
assign inter_out = sample_buffer[0];  // First sample for debug
assign out_audio = sample_buffer[counter];
assign out_valid = (state == OUTPUT_WAVEFORM);

endmodule
