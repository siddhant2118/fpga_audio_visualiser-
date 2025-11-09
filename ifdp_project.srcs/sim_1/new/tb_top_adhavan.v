`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for top_adhavan - FFT Audio Processor
// 
// This testbench simulates:
//   1. Generating test audio samples (sine wave at known frequency)
//   2. Feeding to top_adhavan via BRAM interface
//   3. Monitoring FFT output (should show peak at test frequency)
//   4. Checking IFFT waveform output
//
// Expected Results:
//   - FFT magnitude should show peak at bin corresponding to test frequency
//   - For 1 kHz sine at 20 kHz sampling: peak at bin 256/20 = ~13
//   - IFFT output should reconstruct the sine wave
//
//////////////////////////////////////////////////////////////////////////////////

module tb_top_adhavan;

// ============================================================================
// Clock and Reset
// ============================================================================
reg clk = 0;
reg reset = 1;

// 100 MHz clock (10 ns period)
always #5 clk = ~clk;

// ============================================================================
// DUT (Device Under Test) Signals
// ============================================================================
reg         frame_done = 0;
reg  [11:0] m2_rd_data;
wire [7:0]  m2_rd_addr;
wire [15:0] inter_out;
reg  [15:0] sw = 16'hFFFF;  // All switches ON (no filtering)
wire [15:0] fft_data;
wire [15:0] wave_data;
wire        fft_data_valid;
wire        wave_data_valid;
wire [15:0] out_audio;
wire        out_valid;

// ============================================================================
// Test Audio Data Storage (256 samples)
// ============================================================================
reg [11:0] test_samples [0:255];
integer i;

// Generate test sine wave: 1 kHz at 20 kHz sampling rate
// Frequency bin = (1000 Hz / 20000 Hz) * 256 = 12.8 ≈ bin 13
initial begin
    for (i = 0; i < 256; i = i + 1) begin
        // Generate 12-bit sine wave: amplitude = 2047 (max for 12-bit signed)
        // Frequency: 1 kHz, Sampling rate: 20 kHz
        // Phase increment per sample: 2*pi*1000/20000 = pi/10
        real phase = 2.0 * 3.14159265359 * 1000.0 * i / 20000.0;
        real sine_val = 1500.0 * $sin(phase);  // Amplitude 1500 for visibility
        test_samples[i] = $rtoi(sine_val) + 2048;  // Offset to unsigned 12-bit
    end
    $display("[TB] Generated 256 samples of 1 kHz sine wave");
end

// ============================================================================
// BRAM Read Interface Emulation
// ============================================================================
// Respond to read address with test data
always @(*) begin
    if (m2_rd_addr < 256)
        m2_rd_data = test_samples[m2_rd_addr];
    else
        m2_rd_data = 12'd2048;  // Default mid-scale
end

// ============================================================================
// DUT Instantiation (WITHOUT FFT IPs - for syntax checking)
// ============================================================================
// NOTE: This will show 'x' outputs since FFT IPs aren't simulated
// To fully test, you'd need to use Vivado's FFT IP behavioral models

top_adhavan #(
    .SYS_CLK_HZ(100_000_000),
    .FS_HZ(20_000)
) dut (
    .clk(clk),
    .reset(reset),
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

// ============================================================================
// Monitor FFT Output
// ============================================================================
integer fft_output_count = 0;
integer max_fft_magnitude = 0;
integer max_fft_bin = 0;

always @(posedge clk) begin
    if (fft_data_valid) begin
        $display("[TB] FFT Output: Bin %0d = %0d (0x%h)", 
                 fft_output_count, fft_data, fft_data);
        
        // Track maximum magnitude and its bin
        if (fft_data > max_fft_magnitude) begin
            max_fft_magnitude = fft_data;
            max_fft_bin = fft_output_count;
        end
        
        fft_output_count = fft_output_count + 1;
        
        if (fft_output_count == 256) begin
            $display("[TB] ===================================");
            $display("[TB] FFT Complete!");
            $display("[TB] Maximum magnitude: %0d at bin %0d", 
                     max_fft_magnitude, max_fft_bin);
            $display("[TB] Expected peak at bin ~13 for 1 kHz");
            $display("[TB] ===================================");
            fft_output_count = 0;
            max_fft_magnitude = 0;
        end
    end
end

// ============================================================================
// Monitor Waveform Output
// ============================================================================
integer wave_output_count = 0;

always @(posedge clk) begin
    if (wave_data_valid) begin
        if (wave_output_count < 10)  // Show first 10 samples
            $display("[TB] Waveform Output[%0d] = %0d", wave_output_count, wave_data);
        
        wave_output_count = wave_output_count + 1;
        
        if (wave_output_count == 256) begin
            $display("[TB] ===================================");
            $display("[TB] Waveform Output Complete (256 samples)");
            $display("[TB] ===================================");
            wave_output_count = 0;
        end
    end
end

// ============================================================================
// Monitor State Machine
// ============================================================================
reg [3:0] prev_state = 4'd0;
always @(posedge clk) begin
    if (dut.state != prev_state) begin
        case (dut.state)
            4'd0: $display("[TB] State: IDLE");
            4'd1: $display("[TB] State: READ_SAMPLES");
            4'd2: $display("[TB] State: WAIT_FFT_READY");
            4'd3: $display("[TB] State: FEED_FFT");
            4'd4: $display("[TB] State: COLLECT_FFT");
            4'd5: $display("[TB] State: OUTPUT_FFT_MAG");
            4'd6: $display("[TB] State: FEED_IFFT");
            4'd7: $display("[TB] State: COLLECT_IFFT");
            4'd8: $display("[TB] State: OUTPUT_WAVEFORM");
            default: $display("[TB] State: UNKNOWN (%0d)", dut.state);
        endcase
        prev_state = dut.state;
    end
end

// ============================================================================
// Test Stimulus
// ============================================================================
initial begin
    $display("========================================");
    $display("Testbench for top_adhavan FFT Processor");
    $display("========================================");
    
    // Initialize waveform dump
    $dumpfile("tb_top_adhavan.vcd");
    $dumpvars(0, tb_top_adhavan);
    
    // Reset sequence
    reset = 1;
    frame_done = 0;
    #100;
    reset = 0;
    #100;
    
    $display("[TB] Reset released, waiting for IDLE state...");
    
    // Wait a bit
    #200;
    
    // Trigger frame processing
    $display("[TB] Asserting frame_done to start processing...");
    @(posedge clk);
    frame_done = 1;
    @(posedge clk);
    frame_done = 0;
    
    // Wait for processing to complete
    // Expected time: ~2000-3000 cycles depending on FFT latency
    $display("[TB] Waiting for processing to complete...");
    
    // Monitor for timeout (if stuck in a state)
    fork
        begin
            // Wait for return to IDLE (max 50000 cycles = 500 us)
            repeat(50000) @(posedge clk);
            $display("[TB] ERROR: Timeout - module did not return to IDLE");
            $display("[TB] Stuck in state: %0d", dut.state);
            $finish;
        end
        begin
            // Wait for module to return to IDLE
            wait(dut.state == 4'd0 && prev_state != 4'd0);
            $display("[TB] Module returned to IDLE - processing complete!");
        end
    join_any
    disable fork;
    
    // Run a bit more to see final outputs
    #1000;
    
    // Summary
    $display("========================================");
    $display("Simulation Complete");
    $display("========================================");
    $display("Check results:");
    $display("  1. Did FFT output 256 valid samples?");
    $display("  2. Was peak magnitude at expected bin (~13)?");
    $display("  3. Did waveform output 256 valid samples?");
    $display("========================================");
    
    $finish;
end

// Timeout watchdog (kill simulation after 1ms)
initial begin
    #1_000_000;  // 1 ms
    $display("[TB] FATAL: Simulation timeout after 1 ms");
    $finish;
end

endmodule
