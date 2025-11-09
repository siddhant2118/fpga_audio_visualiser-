`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top_adhavan
// Description: FFT-based audio processor using Vivado FFT IP Core
//
// Architecture:
//   1. Read 256 samples from Member 1's BRAM
//   2. Feed to Vivado FFT IP (256-point, streaming)
//   3. Calculate magnitude and apply switch-based filtering
//   4. Feed filtered spectrum to Vivado IFFT IP
//   5. Output magnitude data and waveform data to displays
//
// IMPORTANT: You must add TWO Vivado IP cores to this project:
//   1. FFT IP Core (xfft_0) - for forward FFT
//   2. FFT IP Core (xfft_1) - for inverse FFT (IFFT)
//
// To add FFT IP in Vivado:
//   1. IP Catalog -> Math Functions -> Transforms -> Fast Fourier Transform
//   2. Configuration:
//      - Transform Length: 256
//      - Target Clock Frequency: 100 MHz
//      - Implementation: Pipelined, Streaming I/O
//      - Input Data Width: 16 bits
//      - Phase Factor Width: 16 bits
//      - Scaling: Unscaled
//      - CORDIC Algorithm: Unscaled
//      - Output Ordering: Natural Order
//      - Control Signals: Optional TLAST and optional TREADY
//   3. For IFFT (xfft_1): Same config but check "IFFT" checkbox
//
// Resource Estimate (per FFT IP):
//   - LUTs: ~2000-3000
//   - FFs: ~1500-2500
//   - DSPs: 3-5
//   - BRAMs: 2-4
//   Total for both FFTs + control logic: ~6000 LUTs, ~5000 FFs (well within Basys3 limits)
//
//////////////////////////////////////////////////////////////////////////////////

module top_adhavan #(
    parameter integer SYS_CLK_HZ = 100_000_000,
    parameter integer FS_HZ      = 20_000
)(
    input  wire        clk,
    input  wire        reset,

    input  wire        frame_done,      // from Member 1
    input  wire [11:0] m2_rd_data,      // from Member 1's BRAM
    output reg  [7:0]  m2_rd_addr,      // address to Member 1's BRAM

    output wire [15:0] inter_out,       // debug output (FFT real part)

    input  wire [15:0] sw,              // 16 switches for filtering control
    output reg  [15:0] fft_data = 0,    // FFT magnitude output (one bin per clock)
    output reg  [15:0] wave_data = 0,   // Waveform output (one sample per clock)
    output reg  fft_data_valid = 0,     // Valid signal for fft_data
    output reg  wave_data_valid = 0,    // Valid signal for wave_data
    output wire [15:0] out_audio,       // Final output after IFFT
    output wire        out_valid
);

// ============================================================================
// State Machine for Overall Control
// ============================================================================
localparam IDLE             = 4'd0;
localparam READ_SAMPLES     = 4'd1;
localparam WAIT_FFT_READY   = 4'd2;
localparam FEED_FFT         = 4'd3;
localparam COLLECT_FFT      = 4'd4;
localparam OUTPUT_FFT_MAG   = 4'd5;
localparam FEED_IFFT        = 4'd6;
localparam COLLECT_IFFT     = 4'd7;
localparam OUTPUT_WAVEFORM  = 4'd8;

reg [3:0] state = IDLE;
reg [7:0] counter = 0;

// ============================================================================
// Sample Buffer (256 samples from BRAM)
// ============================================================================
reg [15:0] sample_buffer [0:255];  // Sign-extended 12->16 bit samples

// ============================================================================
// FFT Input/Output Buffers
// ============================================================================
reg [15:0] fft_input_re;
reg [15:0] fft_input_im;
reg        fft_input_valid;
reg        fft_input_last;

wire [15:0] fft_output_re;
wire [15:0] fft_output_im;
wire        fft_output_valid;
wire        fft_output_last;
wire        fft_output_ready;

// FFT spectrum storage (magnitude and complex)
reg [15:0] fft_mag_buffer [0:255];     // Magnitude for display
reg [31:0] fft_complex_buffer [0:255]; // {real[15:0], imag[15:0]} for filtering

// ============================================================================
// IFFT Input/Output Buffers
// ============================================================================
reg [15:0] ifft_input_re;
reg [15:0] ifft_input_im;
reg        ifft_input_valid;
reg        ifft_input_last;

wire [15:0] ifft_output_re;
wire [15:0] ifft_output_im;
wire        ifft_output_valid;
wire        ifft_output_last;
wire        ifft_output_ready;

// IFFT output storage
reg [15:0] ifft_output_buffer [0:255];  // Time-domain waveform

// ============================================================================
// Helper signals for magnitude calculation and filtering
// ============================================================================
reg signed [15:0] re_signed, im_signed;
reg [15:0] re_abs, im_abs, magnitude;
reg [3:0] band_num;
reg band_enabled;
reg [15:0] filtered_re, filtered_im;

// ============================================================================
// Vivado FFT IP Core Instantiation (FORWARD FFT)
// ============================================================================
// NOTE: Replace this with actual IP instantiation template from Vivado
// After adding the IP, right-click -> "Open IP Example Design" to see template
//
// The IP uses AXI4-Stream interface:
//   s_axis_data_tdata[31:0] = {imag[15:0], real[15:0]}
//   s_axis_data_tvalid
//   s_axis_data_tready
//   s_axis_data_tlast
//   m_axis_data_tdata[31:0] = {imag[15:0], real[15:0]}
//   m_axis_data_tvalid
//   m_axis_data_tready
//   m_axis_data_tlast

wire [31:0] fft_input_tdata  = {fft_input_im, fft_input_re};
wire [31:0] fft_output_tdata;
wire        fft_input_tready;

assign fft_output_re = fft_output_tdata[15:0];
assign fft_output_im = fft_output_tdata[31:16];

// FFT IP instantiation - ACTIVE
xfft_0 forward_fft (
    .aclk                   (clk),
    .aresetn                (~reset),
    .s_axis_config_tdata    (8'b00000001),  // Forward FFT, natural order output
    .s_axis_config_tvalid   (1'b1),
    .s_axis_config_tready   (),
    .s_axis_data_tdata      (fft_input_tdata),
    .s_axis_data_tvalid     (fft_input_valid),
    .s_axis_data_tready     (fft_input_tready),
    .s_axis_data_tlast      (fft_input_last),
    .m_axis_data_tdata      (fft_output_tdata),
    .m_axis_data_tvalid     (fft_output_valid),
    .m_axis_data_tready     (fft_output_ready),
    .m_axis_data_tlast      (fft_output_last),
    .event_frame_started    (),
    .event_tlast_unexpected (),
    .event_tlast_missing    (),
    .event_data_in_channel_halt ()
);

// ============================================================================
// Vivado FFT IP Core Instantiation (INVERSE FFT)
// ============================================================================
wire [31:0] ifft_input_tdata  = {ifft_input_im, ifft_input_re};
wire [31:0] ifft_output_tdata;
wire        ifft_input_tready;

assign ifft_output_re = ifft_output_tdata[15:0];
assign ifft_output_im = ifft_output_tdata[31:16];

// IFFT IP instantiation - ACTIVE
xfft_1 inverse_fft (
    .aclk                   (clk),
    .aresetn                (~reset),
    .s_axis_config_tdata    (8'b00000000),  // Inverse FFT (bit 0 = 0)
    .s_axis_config_tvalid   (1'b1),
    .s_axis_config_tready   (),
    .s_axis_data_tdata      (ifft_input_tdata),
    .s_axis_data_tvalid     (ifft_input_valid),
    .s_axis_data_tready     (ifft_input_tready),
    .s_axis_data_tlast      (ifft_input_last),
    .m_axis_data_tdata      (ifft_output_tdata),
    .m_axis_data_tvalid     (ifft_output_valid),
    .m_axis_data_tready     (ifft_output_ready),
    .m_axis_data_tlast      (ifft_output_last),
    .event_frame_started    (),
    .event_tlast_unexpected (),
    .event_tlast_missing    (),
    .event_data_in_channel_halt ()
);

// ============================================================================
// Main State Machine
// ============================================================================
always @(posedge clk) begin
    if (reset) begin
        state             <= IDLE;
        counter           <= 0;
        m2_rd_addr        <= 0;
        fft_input_valid   <= 0;
        fft_input_last    <= 0;
        ifft_input_valid  <= 0;
        ifft_input_last   <= 0;
        fft_data_valid    <= 0;
        wave_data_valid   <= 0;
    end else begin
        // Default: de-assert valid signals
        fft_input_valid  <= 0;
        fft_input_last   <= 0;
        ifft_input_valid <= 0;
        ifft_input_last  <= 0;
        fft_data_valid   <= 0;
        wave_data_valid  <= 0;

        case (state)
            // ================================================================
            // IDLE: Wait for frame_done signal from Member 1
            // ================================================================
            IDLE: begin
                counter <= 0;
                if (frame_done) begin
                    state      <= READ_SAMPLES;
                    m2_rd_addr <= 0;
                end
            end

            // ================================================================
            // READ_SAMPLES: Read 256 samples from Member 1's BRAM
            // Takes 257 cycles (1 cycle latency + 256 reads)
            // ================================================================
            READ_SAMPLES: begin
                if (counter == 0) begin
                    // First cycle: just set address
                    m2_rd_addr <= 0;
                    counter    <= counter + 1;
                end else if (counter <= 256) begin
                    // Cycles 1-256: capture data and advance address
                    sample_buffer[counter-1] <= { {4{m2_rd_data[11]}}, m2_rd_data };  // Sign-extend 12->16
                    m2_rd_addr               <= m2_rd_addr + 1;
                    counter                  <= counter + 1;

                    if (counter == 256) begin
                        state   <= FEED_FFT;
                        counter <= 0;
                    end
                end
            end

            // ================================================================
            // FEED_FFT: Feed 256 samples to FFT IP (streaming)
            // Takes 256 cycles
            // ================================================================
            FEED_FFT: begin
                if (fft_input_tready) begin  // Wait for FFT to be ready
                    fft_input_re    <= sample_buffer[counter];
                    fft_input_im    <= 16'd0;  // Imaginary part is zero
                    fft_input_valid <= 1'b1;
                    fft_input_last  <= (counter == 255);

                    if (counter == 255) begin
                        state   <= COLLECT_FFT;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end

            // ================================================================
            // COLLECT_FFT: Collect FFT output and calculate magnitude
            // FFT IP outputs in natural order (no bit-reversal needed!)
            // Takes 256 cycles
            // ================================================================
            COLLECT_FFT: begin
                if (fft_output_valid) begin
                    // Calculate magnitude using L1 norm: |Re| + |Im|
                    re_signed = fft_output_re;
                    im_signed = fft_output_im;
                    re_abs = re_signed[15] ? (~re_signed + 1) : re_signed;
                    im_abs = im_signed[15] ? (~im_signed + 1) : im_signed;
                    magnitude = re_abs + im_abs;

                    // Store magnitude and complex data
                    fft_mag_buffer[counter]     <= magnitude;
                    fft_complex_buffer[counter] <= {fft_output_re, fft_output_im};

                    if (fft_output_last || counter == 255) begin
                        state   <= OUTPUT_FFT_MAG;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end

            // ================================================================
            // OUTPUT_FFT_MAG: Stream FFT magnitudes to display (Member 3)
            // Takes 256 cycles
            // ================================================================
            OUTPUT_FFT_MAG: begin
                fft_data       <= fft_mag_buffer[counter];
                fft_data_valid <= 1'b1;

                if (counter == 255) begin
                    state   <= FEED_IFFT;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end

            // ================================================================
            // FEED_IFFT: Apply filtering and feed to IFFT
            // Filtering: zero out frequency bins based on switch settings
            // Each switch controls 16 bins (256 bins / 16 switches)
            // Takes 256 cycles
            // ================================================================
            FEED_IFFT: begin
                if (ifft_input_tready) begin
                    // Determine which frequency band this bin belongs to
                    band_num = counter[7:4];  // counter / 16
                    band_enabled = sw[band_num];

                    // Apply filtering: zero out if band is disabled
                    filtered_re = band_enabled ? fft_complex_buffer[counter][15:0]  : 16'd0;
                    filtered_im = band_enabled ? fft_complex_buffer[counter][31:16] : 16'd0;

                    ifft_input_re    <= filtered_re;
                    ifft_input_im    <= filtered_im;
                    ifft_input_valid <= 1'b1;
                    ifft_input_last  <= (counter == 255);

                    if (counter == 255) begin
                        state   <= COLLECT_IFFT;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end

            // ================================================================
            // COLLECT_IFFT: Collect IFFT output (time-domain waveform)
            // Takes 256 cycles
            // ================================================================
            COLLECT_IFFT: begin
                if (ifft_output_valid) begin
                    // Store real part (ignore imaginary, should be ~0)
                    // Scale down by 256 (divide by FFT size) to normalize
                    ifft_output_buffer[counter] <= ifft_output_re >>> 8;

                    if (ifft_output_last || counter == 255) begin
                        state   <= OUTPUT_WAVEFORM;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end

            // ================================================================
            // OUTPUT_WAVEFORM: Stream waveform to display (Member 3)
            // Takes 256 cycles, then return to IDLE
            // ================================================================
            OUTPUT_WAVEFORM: begin
                wave_data       <= ifft_output_buffer[counter];
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
assign inter_out = fft_output_re;  // Debug: monitor FFT real output
assign out_audio = ifft_output_re; // Audio output (for Member 4)
assign out_valid = ifft_output_valid;

endmodule
