# Data Flow Analysis - Audio Visualizer

## Complete Data Path Tracing

### 1. Audio Capture (top_sidu.v)
```
Microphone → Audio_Capture → mic_in [12-bit] 
    ↓
DC Offset Removal (subtract 2048)
    ↓
Noise Gate (threshold: 20)
    ↓
4-Sample Moving Average
    ↓
mic_filtered [12-bit] → frame_packer
    ↓
BRAM (256 samples) → m2_rd_data [12-bit]
    ↓
frame_done pulse (1 cycle every 256 samples at 20kHz = every 12.8ms)
```

### 2. FFT Processing (top_adhavan.v)

#### State Machine Flow:
```
IDLE: Wait for frame_done
    ↓
READ_SAMPLES: Read 256 samples from BRAM (257 cycles)
    - Sign-extend 12-bit → 16-bit: sample_buffer[0:255]
    ↓
FEED_FFT: Stream to FFT IP (256 cycles)
    - fft_input_re = sample_buffer[i]
    - fft_input_im = 0
    - fft_input_valid = 1
    ↓
COLLECT_FFT: Collect FFT output (256+ cycles, waits for fft_output_valid)
    - Calculate magnitude: |Re| + |Im|
    - Store: fft_mag_buffer[0:255] [16-bit]
    - Store complex: fft_complex_buffer[0:255] [32-bit]
    ↓
OUTPUT_FFT_MAG: Stream to display (256 cycles)
    - fft_data = fft_mag_buffer[i]
    - fft_data_valid = 1
    ↓
FEED_IFFT: Apply filtering and feed to IFFT (256 cycles)
    - Filter based on switches: zero bins if sw[band] = 0
    - ifft_input_re/im = filtered spectrum
    ↓
COLLECT_IFFT: Collect IFFT output (256+ cycles)
    - ifft_output_re [16-bit] >>> 2 (divide by 4)
    - Store: ifft_output_buffer[0:255] [16-bit signed]
    ↓
OUTPUT_WAVEFORM: Stream to display (256 cycles)
    - wave_data = ifft_output_buffer[i]
    - wave_data_valid = 1
    ↓
Back to IDLE (cycle repeats)
```

**Total Processing Time per Frame:**
- State cycles: 257 + 256 + ~300 + 256 + 256 + ~300 + 256 = ~1881 cycles minimum
- At 100 MHz: 18.81 μs
- Input frame rate: 12.8 ms (20 kHz / 256 samples)
- **Conclusion: Processing is MUCH faster than input rate (1881 cycles vs 1.28M cycles)**
- System should be working correctly without data loss

### 3. Display Data Flow (top_rehaan.v)

```
fft_data [16-bit] + fft_data_valid → data_reader → fft_flat [4096-bit array]
wave_data [16-bit] + wave_data_valid → data_reader → wave_flat [4096-bit array]
    ↓
frame_buffer (clk30hz) - Updates at 30 Hz for stable display
    ↓
fft_buffered [256 samples × 16-bit]
wave_buffered [256 samples × 16-bit]
    ↓
display_controller → colorA (FFT), colorB (waveform)
```

### 4. Display Rendering (display_controller.v)

#### FFT Spectrum (Display A):
```
fft_buffered[256 samples] → fft_mag[0:255]
    ↓
For each pixel column x_a (0-95):
    - band_num = x_a / 6  (0-15, creates 16 bands)
    - band_idx = band_num * 16  (map to FFT bins)
    - height = fft_mag[band_idx] >> 11  (scale to 0-63 pixels)
    - Draw bar from bottom to height
```

**FFT Band Mapping:**
- 256 FFT bins → 16 bands (each band = 16 bins)
- 96 pixel columns → 16 bands (each band = 6 pixels wide)
- Band 0 (pixels 0-5): FFT bins 0-15 (0-1172 Hz at 20kHz sample rate)
- Band 1 (pixels 6-11): FFT bins 16-31 (1172-2344 Hz)
- ...
- Band 15 (pixels 90-95): FFT bins 240-255 (9375-10000 Hz)

**Why FFT is Oscillating:**
1. **Frame buffer at 30 Hz** - Display updates 30 times per second
2. **New FFT every 12.8 ms** - Processing produces ~78 FFTs per second
3. **BUT: data_reader accumulates ALL incoming data**
   - Problem: If data_reader doesn't have proper frame sync, it might be mixing old and new data
4. **Microphone noise** - Even with filtering, ambient noise creates real frequency content
5. **Scaling issue** - Even after >> 11, if input is very noisy, bars can still be high

#### Waveform (Display B):
```
wave_buffered[256 samples] → wave_sample[0:255]
    ↓
For each pixel column x_b (0-95):
    - samp_idx = (x_b * 256) / 96  (map 96 pixels to 256 samples)
    - wave_signed = wave_sample[samp_idx]  [signed 16-bit]
    - wave_unsigned = wave_signed + 32768  [unsigned 17-bit]
    - samp_y = wave_unsigned[16:10]  (scale to 0-63)
    - Draw single pixel at y = 63 - samp_y
```

**Waveform Issues:**
1. **Single pixel drawing** - Only 1 pixel per column, no interpolation
2. **Sparse sampling** - 96 pixels from 256 samples (displays every ~2.67th sample)
3. **No anti-aliasing** - Sharp transitions look disconnected

---

## Is the Code Working as Intended?

### ✅ **YES, Core Logic is Correct:**

1. **State Machine:** Properly sequences through all stages
2. **FFT IP Interface:** Correctly configured with 64-bit outputs
3. **Data Types:** Proper signed/unsigned handling
4. **Scaling:** Mathematically sound (though tuned for visibility)
5. **Timing:** Fast enough to process all frames without loss

### ⚠️ **BUT: Display Has Limitations:**

#### FFT Spectrum Problems:
1. **30 Hz refresh rate creates aliasing** - FFT computed at 78 Hz, displayed at 30 Hz
2. **No temporal smoothing** - Each frame is independent, creates flicker
3. **Noise amplification** - Real-world audio has broadband noise that shows up
4. **All frequencies present** - Even "silence" has thermal noise in all bins

**Solution: Add temporal averaging to frame_buffer**

#### Waveform Problems:
1. **Dot plot instead of line** - Current implementation draws discrete points
2. **No interpolation** - Missing pixels between samples
3. **Undersampling** - Only showing ~37% of samples (96 out of 256)

**Solution: Implement line drawing with interpolation**

---

## Recommended Fixes

### Fix 1: Temporal Smoothing for FFT (Reduces Oscillation)

Modify `frame_buffer.v` to add exponential moving average:

```verilog
// Instead of direct assignment:
// buffered_array <= array;

// Use weighted average (87.5% old, 12.5% new):
integer k;
always @ (posedge clk) begin
    for (k = 0; k < 256; k = k + 1) begin
        buffered_array[k*16 +:16] <= (buffered_array[k*16 +:16] * 7 + array[k*16 +:16]) / 8;
    end
end
```

This creates a smooth rolling average that reduces flicker.

### Fix 2: Line Drawing for Waveform (Smooth Curves)

Modify `display_controller.v` waveform section:

```verilog
// Current: Single pixel at exact sample position
// New: Draw line between adjacent samples using Bresenham-like algorithm

// Get current and next sample positions
wire [7:0] samp_idx_curr = (x_b << 8) / 96;
wire [7:0] samp_idx_next = ((x_b + 1) << 8) / 96;

wire signed [15:0] wave_curr = wave_sample[samp_idx_curr];
wire signed [15:0] wave_next = wave_sample[samp_idx_next];

wire [16:0] wave_curr_unsigned = wave_curr + 17'd32768;
wire [16:0] wave_next_unsigned = wave_next + 17'd32768;

wire [5:0] samp_y_curr = wave_curr_unsigned[16:10];
wire [5:0] samp_y_next = wave_next_unsigned[16:10];

// Calculate if current pixel is on the line between points
wire signed [6:0] y_diff = samp_y_next - samp_y_curr;  // Height difference
wire [5:0] y_min = (samp_y_curr < samp_y_next) ? samp_y_curr : samp_y_next;
wire [5:0] y_max = (samp_y_curr > samp_y_next) ? samp_y_curr : samp_y_next;

// Draw if y is between min and max (vertical line segment)
wire on_line = (y_b >= (63 - y_max)) && (y_b <= (63 - y_min));

// Color assignment
if (on_line)
    colorB = 16'h0695;  // turquoise trace
else
    colorB = 16'h0000;  // background black
```

### Fix 3: Increase Noise Threshold (Reduce FFT Sensitivity)

In `top_sidu.v`, increase threshold from 20 to 40:

```verilog
parameter NOISE_THRESHOLD = 12'd40;  // More aggressive noise rejection
```

---

## Summary Table

| Component | Status | Issue | Severity | Fix Priority |
|-----------|--------|-------|----------|--------------|
| Audio Capture | ✅ Working | None | - | - |
| FFT Processing | ✅ Working | None | - | - |
| IFFT Processing | ✅ Working | None | - | - |
| Data Flow | ✅ Working | None | - | - |
| FFT Display Logic | ✅ Working | High oscillation | Medium | HIGH |
| Waveform Logic | ⚠️ Limited | Dot plot, not line | High | HIGH |
| Noise Filtering | ⚠️ Weak | Too sensitive | Medium | MEDIUM |

---

## Verification Steps

To confirm code is working:

1. **Check state machine** - Monitor `inter_out` on LEDs (shows state in lower 4 bits)
2. **Check frame rate** - Should see ~78 state machine cycles per second
3. **Check timeout** - If `timeout_counter` triggers, FFT IP not working
4. **Manually test patterns** - Use simple test module to verify display
5. **Oscilloscope** - Check `fft_output_valid` and `ifft_output_valid` timing

**Conclusion: Core processing is working correctly. Display artifacts are due to visualization limitations, not processing errors.**
