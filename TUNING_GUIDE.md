# Audio Visualizer Tuning Guide

## Overview
This guide helps you adjust the audio visualizer behavior for optimal display and noise handling.

---

## Issue 1: FFT Spectrum Bars Behavior

### Symptoms:
- Bars too high / maxed out
- Bars oscillating/flickering rapidly
- All bars moving together

### Solution Applied:
Changed FFT magnitude scaling in `display_controller.v` from `>> 9` to `>> 11`

### Tuning Parameters:
```verilog
// In display_controller.v, line ~44
wire [5:0] height = fft_mag[band_idx] >> 11;  // Current: divide by 2048
```

**Adjustment Guide:**
- **Bars still too high?** Increase shift: `>> 12` (divide by 4096)
- **Bars too small?** Decrease shift: `>> 10` (divide by 1024)
- **Formula:** `>> N` divides by `2^N`

| Shift Value | Division Factor | Use Case |
|-------------|----------------|----------|
| >> 9 | ÷512 | Very loud environments |
| >> 10 | ÷1024 | Loud environments |
| >> 11 | ÷2048 | **Normal (current)** |
| >> 12 | ÷4096 | Quiet environments |
| >> 13 | ÷8192 | Very quiet |

---

## Issue 2: Waveform Visibility

### Symptoms:
- Waveform barely visible
- Looks like flat line
- No noticeable movement

### Solution Applied:
Changed IFFT output scaling in `top_adhavan.v` from `>>> 4` to `>>> 2`

### Tuning Parameters:
```verilog
// In top_adhavan.v, COLLECT_IFFT state, line ~416
scaled_ifft_output = ifft_real_signed >>> 2;  // Current: divide by 4
```

**Adjustment Guide:**
- **Still too small?** Use `>>> 1` (divide by 2) or `>>> 0` (no scaling)
- **Too large/clipping?** Use `>>> 3` (divide by 8)
- **Distorted?** Use `>>> 4` (divide by 16)

| Shift Value | Division Factor | Amplitude | Use Case |
|-------------|----------------|-----------|----------|
| >>> 0 | ÷1 | Maximum | May clip/distort |
| >>> 1 | ÷2 | Very high | Loud signals |
| >>> 2 | ÷4 | **High (current)** | Normal |
| >>> 3 | ÷8 | Medium | Quiet signals |
| >>> 4 | ÷16 | Low | Very quiet |

**Also adjust timeout fallback (same file, line ~432):**
```verilog
ifft_output_buffer[counter] <= sample_buffer[counter] << 6;  // Current: multiply by 64
```
Keep this 4× larger than IFFT scaling (if `>>> 2`, use `<< 6`)

---

## Issue 3: Microphone Noise

### Symptoms:
- Picking up background noise
- Visualizer reacts to room sounds
- FFT shows activity when silent

### Solutions Applied:
Three-stage noise filtering in `top_sidu.v`:

#### 1. DC Offset Removal
```verilog
parameter DC_OFFSET = 12'd2048;  // MIC3 centers around 2048
```
**Adjustment:** If waveform looks shifted up/down, adjust this value (typical range: 2000-2100)

#### 2. Noise Gate
```verilog
parameter NOISE_THRESHOLD = 12'd20;  // Suppress signals below 20 ADC units
```
**Adjustment Guide:**
- **Still too sensitive?** Increase threshold: `12'd30` or `12'd40`
- **Missing quiet sounds?** Decrease threshold: `12'd10` or `12'd15`

| Threshold | Sensitivity | Use Case |
|-----------|-------------|----------|
| 10 | Very sensitive | Capture everything |
| 15 | Sensitive | Slight noise reduction |
| 20 | **Normal (current)** | Good noise rejection |
| 30 | Less sensitive | Noisy environments |
| 40 | Minimal | Only loud sounds |

#### 3. Moving Average Filter
```verilog
// 4-sample moving average
reg [11:0] mic_history [0:3];
```
**Adjustment:** Change array size for different smoothing:
- `[0:1]` = 2-sample average (less smoothing, faster response)
- `[0:3]` = 4-sample average (current)
- `[0:7]` = 8-sample average (more smoothing, slower response)

If you change the array size, update the division:
- 2 samples: `mic_sum[12:1]` (divide by 2)
- 4 samples: `mic_sum[13:2]` (divide by 4) **[current]**
- 8 samples: `mic_sum[14:3]` (divide by 8)

---

## Quick Tuning Workflow

### If FFT bars are unstable:
1. Start with `>> 11` (current setting)
2. If still too high, try `>> 12`
3. If too small, try `>> 10`

### If waveform is invisible:
1. Start with `>>> 2` (current setting)
2. If still invisible, try `>>> 1` or `>>> 0`
3. Update timeout fallback accordingly

### If too much noise:
1. Increase `NOISE_THRESHOLD` to 30 or 40
2. Consider increasing average window to 8 samples
3. Check physical microphone placement (away from board)

### If missing real audio:
1. Decrease `NOISE_THRESHOLD` to 10 or 15
2. Decrease average window to 2 samples
3. Adjust `DC_OFFSET` if waveform looks shifted

---

## Testing Procedure

1. **Synthesize and program board** after each change
2. **Test in quiet room** first - FFT should be mostly flat, waveform near center
3. **Test with music/voice** - FFT should show distinct bars, waveform should be clearly visible
4. **Test sensitivity** - whistle or snap fingers at different distances

---

## Mathematical Background

### FFT Scaling
- Unscaled 256-point FFT outputs magnitudes 0-65535
- Display needs 0-63 pixel range
- Formula: `height = magnitude >> N` where `N = log2(65536/64) ≈ 10-12`

### IFFT Scaling
- Unscaled FFT→IFFT multiplies by N (256)
- Mathematically correct: `>>> 8` (divide by 256)
- Practically visible: `>>> 2` to `>>> 4` (compromise)

### Noise Threshold
- MIC3 ADC: 12-bit (0-4095 range)
- After DC removal: -2048 to +2047
- Threshold of 20 = ~1% of full range (catches room noise)

---

## Current Configuration Summary

| Parameter | File | Line | Value | Purpose |
|-----------|------|------|-------|---------|
| FFT magnitude scaling | display_controller.v | ~44 | `>> 11` | Scale bars to 0-63 |
| IFFT output scaling | top_adhavan.v | ~416 | `>>> 2` | Make waveform visible |
| Timeout fallback | top_adhavan.v | ~432 | `<< 6` | Match IFFT scaling |
| DC offset | top_sidu.v | ~42 | `2048` | Remove MIC3 bias |
| Noise threshold | top_sidu.v | ~43 | `20` | Reject background noise |
| Moving average | top_sidu.v | ~51 | 4 samples | Smooth signal |

---

## Advanced: Switch-Based Tuning

Consider exposing these parameters to switches for real-time tuning:

```verilog
// Example: Use switches 12-15 for FFT scaling
wire [3:0] fft_scale_ctrl = sw[15:12];
wire [5:0] height = fft_mag[band_idx] >> (9 + fft_scale_ctrl);  // Dynamic >> 9 to >> 24
```

This allows adjustment without re-synthesis!
