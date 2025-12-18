# 📐 FPGA Audio Visualizer - Module Structure

> Comprehensive technical documentation of all Verilog modules and their interconnections

---

## 📋 Table of Contents

- [System Overview](#system-overview)
- [Top-Level Module](#top-level-module)
- [Audio Input Pipeline](#audio-input-pipeline)
- [FFT Processing Pipeline](#fft-processing-pipeline)
- [Display Pipeline](#display-pipeline)
- [Audio Output Pipeline](#audio-output-pipeline)
- [Utility Modules](#utility-modules)
- [Signal Flow Diagram](#signal-flow-diagram)
- [Hardware Configuration](#hardware-configuration)

---

## System Overview

The FPGA Audio Visualizer is organized into **four main processing pipelines** that operate concurrently:

1. **Audio Input Pipeline** - Captures and preprocesses audio from MIC3 Pmod
2. **FFT Processing Pipeline** - Performs frequency analysis and filtering
3. **Display Pipeline** - Renders visualizations on dual OLED displays
4. **Audio Output Pipeline** - Reconstructs and outputs audio to DAC

**Total Module Count:** 25 Verilog modules + 2 Xilinx IP cores

---

## Top-Level Module

### `top.v`
**Main system integration module**

**Purpose:** Connects all four processing pipelines and manages global signals.

**Key Responsibilities:**
- Clock distribution (100 MHz system clock)
- Reset signal management
- Inter-pipeline signal routing
- Hardware interface instantiation

**Instantiated Pipelines:**
```verilog
audio_input_pipeline    // MIC3 capture → BRAM buffer
fft_processor          // FFT/IFFT processing
display_pipeline       // Dual OLED graphics
audio_output_pipeline  // DAC stereo output
```

**External Interfaces:**
- 16 switches (frequency band control)
- 16 LEDs (audio level bar graph)
- 7-segment display (peak level 0-999)
- 4× Pmod connectors (JA, JB, JC, JD)

---

## Audio Input Pipeline

### 📥 `audio_input_pipeline.v`
**Main controller for audio capture and preprocessing**

**Inputs:**
- `clk` - 100 MHz system clock
- `reset` - Asynchronous reset
- Microphone SPI signals (MISO, CS, SCLK)

**Outputs:**
- `frame_done` - Indicates 256 samples collected
- `m2_rd_data[11:0]` - Audio sample to FFT processor
- `m2_rd_addr[7:0]` - BRAM read address for FFT
- `led[15:0]` - Audio level bar graph
- `seg[6:0]`, `an[3:0]` - 7-segment display (peak level)

**Sub-modules:**
- `mic_spi_capture` - SPI interface to ADC
- `mic_sample_clock` - 20 kHz sampling clock
- `audio_peak_detector` - Peak level detection
- `sample_frame_packer` - 256-sample frame collector
- `sample_buffer_ram` - Dual-port BRAM buffer

---

### 🎤 `mic_spi_capture.v`
**SPI interface for ADCS7476 12-bit ADC**

**Specifications:**
- SPI Mode: CPOL=0, CPHA=0
- Data format: MSB first, 16-bit frame (12 data bits + 4 leading zeros)
- Sample triggered on CS falling edge

**Timing:**
```
CS:     ‾‾‾‾‾‾\______/‾‾‾‾‾‾
SCLK:   ______/‾\_/‾\_/‾\_...
MISO:   ------< D11 >< D10 >...
```

**Operation:**
1. Wait for `cs_signal` falling edge
2. Generate 16 SCLK pulses
3. Shift in MISO data on SCLK rising edges
4. Output 12-bit sample when complete

---

### ⏱️ `mic_sample_clock.v`
**20 kHz chip select generator**

**Purpose:** Generates 20 kHz sampling clock for ADC chip select.

**Implementation:**
```verilog
// Divides 100 MHz → 20 kHz
// Counter threshold: 100_000_000 / 20_000 = 5000
```

**Output:** 50% duty cycle 20 kHz square wave on `cs_signal`

---

### 📊 `audio_peak_detector.v`
**Peak level detection with 100 ms windows**

**Purpose:** Tracks maximum audio level for LED display and 7-segment output.

**Operation:**
1. Samples audio at 20 kHz
2. Maintains running maximum over 100 ms window
3. Updates every 100 ms with new peak value
4. Converts to 0-999 range for 7-segment display

**Update Rate:** 10 Hz (100 ms windows)

---

### 📦 `sample_frame_packer.v`
**Collects 256 samples into frames for FFT**

**Purpose:** Buffers individual audio samples into complete frames.

**Operation:**
1. Accumulates samples at 20 kHz rate
2. Writes to dual-port BRAM via port 1
3. Asserts `frame_done` after 256 samples
4. Circular buffer addressing (0-255)

**Frame Rate:** 20,000 / 256 = **78.125 frames/sec**

---

### 💾 `sample_buffer_ram.v`
**Dual-port Block RAM buffer (256 × 12-bit)**

**Configuration:**
- **Port 1 (Write):** Audio input pipeline writes samples
- **Port 2 (Read):** FFT processor reads samples

**Technology:** Inferred Block RAM (BRAM)

**Addressing:**
- 8-bit address (256 locations)
- 12-bit data width (audio sample resolution)

---

## FFT Processing Pipeline

### 🔬 `fft_processor.v`
**FFT/IFFT state machine and processing controller**

**State Machine:**
```
IDLE → READ_SAMPLES → WAIT_FFT_READY → FEED_FFT → COLLECT_FFT 
  ↓                                                        ↓
OUTPUT_WAVEFORM ← COLLECT_IFFT ← FEED_IFFT ← OUTPUT_FFT_MAG
```

**Key Operations:**
1. **Read samples** from BRAM buffer
2. **Feed FFT** with 256 time-domain samples
3. **Collect FFT** output (complex frequency bins)
4. **Calculate magnitude** for display
5. **Apply frequency filtering** based on switches
6. **Feed IFFT** with filtered frequency data
7. **Collect IFFT** output (reconstructed time-domain)
8. **Output** to display and audio pipelines

**Interfaces:**
- Xilinx xFFT IP cores (AXI4-Stream)
- 16 switches for frequency band control
- Display pipeline (FFT magnitude + waveform data)
- Audio output pipeline (reconstructed audio)

---

### 🧮 `xfft_0` (Xilinx IP Core)
**256-point Forward FFT**

**Configuration:**
- Transform length: 256 points
- Architecture: Pipelined Streaming I/O
- Input: 16-bit real + 16-bit imaginary
- Output: 25-bit real + 25-bit imaginary
- Transform direction: Forward (`s_axis_config_tdata = 8'b00000001`)
- Latency: ~300 clock cycles @ 100 MHz

**Resources:**
- LUTs: 2,262
- FFs: 3,565
- BRAM: 1.5 tiles
- DSPs: 9

---

### 🔄 `xfft_1` (Xilinx IP Core)
**256-point Inverse FFT**

**Configuration:** Identical to xfft_0, except:
- Transform direction: Inverse (`s_axis_config_tdata = 8'b00000000`)

**Purpose:** Reconstructs time-domain audio from filtered frequency data.

**Resources:** Same as xfft_0 (2262 LUT, 3565 FF, 1.5 BRAM, 9 DSP)

---

## Display Pipeline

### 🖼️ `display_pipeline.v`
**Dual OLED controller and graphics coordinator**

**Purpose:** Manages rendering for both OLED displays simultaneously.

**Display A (Spectrum):**
- 16 frequency bars (0-63 pixels height)
- Color-coded by frequency range
- Real-time FFT magnitude visualization

**Display B (Waveform):**
- Time-domain waveform (256 samples)
- Scrolling display
- 64-pixel height scaling

**Sub-modules:**
- `oled_graphics_engine` - Pixel rendering logic
- `stream_to_array` - Data format conversion
- `display_frame_smoother` - Temporal filtering
- `frequency_band_filter` - Switch-based filtering
- `Oled_Display` - Low-level OLED driver (2 instances)

---

### 🎨 `oled_graphics_engine.v`
**Pixel-by-pixel rendering engine**

**Purpose:** Generates RGB pixel values for both displays.

**Operation:**
1. Receives pixel coordinates (x, y) from OLED driver
2. Determines pixel type (spectrum bar, waveform, background)
3. Calculates appropriate color value
4. Outputs 16-bit RGB (5:6:5 format)

**Color Mapping (Spectrum):**
- Low frequencies (0-2 kHz): Red → Orange → Yellow
- Mid frequencies (2-6 kHz): Green → Cyan
- High frequencies (6-10 kHz): Blue → Purple

---

### 🔄 `stream_to_array.v`
**Streaming data to flat array converter**

**Purpose:** Converts serial FFT output to parallel array for random access.

**Operation:**
- Input: Streaming FFT data (1 sample/cycle)
- Output: 256-element flat array `[16*256-1:0]`
- Allows graphics engine to access any frequency bin instantly

---

### 🎬 `display_frame_smoother.v`
**Temporal filtering for flicker reduction**

**Purpose:** Smooths rapid changes in display data to reduce visual flicker.

**Algorithm:**
```verilog
// Low-pass filter
smoothed[i] = (3 * previous[i] + 1 * current[i]) / 4
```

**Update Rate:** 30 Hz (synchronized with OLED refresh)

**Benefit:** Reduces flickering while maintaining responsiveness

---

### 🎚️ `frequency_band_filter.v`
**Switch-controlled 16-band frequency filtering**

**Purpose:** Enables/disables frequency bands based on switch positions.

**Band Mapping:**
- Each switch controls 16 adjacent FFT bins
- SW0: Bins 0-15 (0-1172 Hz)
- SW1: Bins 16-31 (1172-2344 Hz)
- ...
- SW15: Bins 240-255 (18750-20000 Hz, aliased)

**Filtering:**
```verilog
if (sw[band] == 0)
    filtered_output[bin] = 0;  // Mute this band
else
    filtered_output[bin] = fft_data[bin];  // Pass through
```

**Smooth Ramping:** Gradual gain changes prevent audio clicks.

---

### 📺 `Oled_Display.v`
**Low-level PmodOLEDrgb driver**

**Interface:** SPI + DC/RES/VCCEN/PMODEN control signals

**Initialization Sequence:**
1. Power on (VCCEN, PMODEN)
2. Reset pulse (RES)
3. Send configuration commands
4. Enable display controller

**Pixel Transfer:**
- 96×64 = 6144 pixels
- 16-bit RGB565 format per pixel
- ~2 ms per full frame @ 6.25 MHz SPI

---

## Audio Output Pipeline

### 🔊 `audio_output_pipeline.v`
**Main controller for audio output**

**Purpose:** Processes reconstructed IFFT audio and drives stereo DAC.

**Signal Flow:**
```
IFFT output → FIFO buffer → DC block → Gain ramp → Format convert → DAC
```

**Sub-modules:**
- `audio_fifo_bridge` - Async FIFO for smooth playback
- `dc_block_hp` - DC blocking high-pass filter
- `soft_gain_ramp` - Anti-pop gain control
- `pcm16_to_u12` - Format conversion
- `dac_controller` - Dual-channel DAC SPI driver

---

### 📮 `audio_fifo_bridge.v`
**1024-sample FIFO buffer using XPM FIFO**

**Purpose:** Buffers bursty FFT output for smooth continuous DAC playback.

**Configuration:**
- Depth: 1024 samples
- Width: 16 bits
- Write clock: 100 MHz (FFT output)
- Read clock: 20 kHz (DAC sample rate)

**Technology:** Xilinx XPM (Parameterized Macro) FIFO

**Benefit:** Absorbs timing variations between FFT bursts and constant DAC rate.

---

### 🔇 `dc_block_hp.v`
**DC blocking high-pass filter (~5 Hz)**

**Purpose:** Removes DC offset that can accumulate during FFT/IFFT processing.

**Implementation:**
```verilog
// Simple 1st-order IIR high-pass filter
y[n] = α * (y[n-1] + x[n] - x[n-1])
where α ≈ 0.9997 (corner frequency ~5 Hz @ 20 kHz)
```

**Design Rationale:** IFFT can introduce DC drift even if input is DC-free.

---

### 🎚️ `soft_gain_ramp.v`
**Anti-pop gain ramping**

**Purpose:** Prevents audible clicks/pops during audio start/stop or level changes.

**Operation:**
1. Detects sudden amplitude changes
2. Applies gradual gain envelope
3. Ramps up/down over ~10 ms

**Algorithm:**
```verilog
// Exponential ramp
if (target_gain > current_gain)
    current_gain += step;
else
    current_gain -= step;
    
output = input * current_gain;
```

---

### 🔢 `pcm16_to_u12.v`
**Audio format converter (signed 16-bit → unsigned 12-bit)**

**Purpose:** Converts signed PCM audio to unsigned DAC format.

**Conversion:**
```verilog
// Signed 16-bit input: -32768 to +32767
// Unsigned 12-bit output: 0 to 4095
u12_output = (s16_input >> 4) + 2048;
```

**Scaling:** Divides by 16 (>>4) and adds 2048 (mid-scale bias).

---

### 🔌 `dac_controller.v`
**Dual-channel SPI DAC driver for PmodDA2**

**Configuration:**
- 2× DAC121S101 12-bit DACs
- SPI frequency: ~6.25 MHz
- Update rate: 20 kHz per channel

**Frame Format (16 bits):**
```
[15:12] = Command (0000)
[11:0]  = 12-bit data
```

**Sub-module:**
- `spi16_dual_da2` - Low-level dual SPI transmitter

---

### 📡 `spi16_dual_da2.v`
**Dual-channel 16-bit SPI transmitter**

**Purpose:** Sends parallel data to two SPI DACs simultaneously.

**Operation:**
1. Load 16-bit data for both channels
2. Generate SCLK (6.25 MHz)
3. Shift out data MSB first
4. Assert CS for entire transaction
5. Synchronize both channels

---

## Utility Modules

### ⏲️ `clock_divider.v`
**Parameterized clock divider**

**Purpose:** Generates lower-frequency clocks from 100 MHz system clock.

**Features:**
- Configurable division ratio
- Supports 32-bit and 64-bit counters
- 50% duty cycle output

**Usage Examples:**
- 100 MHz → 6.25 MHz (SPI clock)
- 100 MHz → 20 kHz (audio sample rate)
- 100 MHz → 30 Hz (display refresh)

---

### 🔢 `seg_scan4.v`
**4-digit 7-segment multiplexer**

**Purpose:** Time-multiplexes 4 digits onto shared 7-segment display.

**Scan Rate:** 1 kHz (250 Hz per digit, flicker-free)

**Operation:**
1. Activate digit 0, display value, wait 1 ms
2. Activate digit 1, display value, wait 1 ms
3. Activate digit 2, display value, wait 1 ms
4. Activate digit 3, display value, wait 1 ms
5. Repeat

---

### 🔠 `seven_segment.v`
**Hex to 7-segment decoder**

**Input:** 4-bit hex value (0-F)
**Output:** 7-bit segment pattern (a-g)

**Encoding:**
```
  a
f   b
  g
e   c
  d
```

**Supports:** 0-9, A-F hexadecimal display

---

### 📏 `level_0_999.v`
**Audio level scaler (0-999 for 7-segment display)**

**Purpose:** Scales 12-bit audio level (0-4095) to 3-digit decimal (0-999).

**Operation:**
```verilog
scaled = (audio_level * 1000) / 4096;
```

**Output Format:** 3 BCD digits for 7-segment display

---

## Signal Flow Diagram

### Complete System Dataflow

```
                           ┌─────────────┐
                           │   System    │
                           │  Clock      │
                           │  100 MHz    │
                           └──────┬──────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        ▼                         ▼                         ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│  Audio Input  │         │      FFT      │         │   Display     │
│   Pipeline    │────────▶│   Processor   │────────▶│   Pipeline    │
│               │ samples │               │ FFT mag │               │
│ • MIC3 SPI    │         │ • xfft_0 IP   │         │ • Dual OLED   │
│ • Peak Detect │         │ • Filtering   │         │ • Graphics    │
│ • Frame Pack  │         │ • xfft_1 IP   │         │ • Smoothing   │
│ • BRAM Buffer │         │               │         │               │
└───────┬───────┘         └───────┬───────┘         └───────────────┘
        │                         │
        │ peak level              │ IFFT audio
        ▼                         ▼
┌───────────────┐         ┌───────────────┐
│  LED Display  │         │ Audio Output  │
│  7-Segment    │         │   Pipeline    │
│               │         │               │
│ • LED[15:0]   │         │ • FIFO Buffer │
│ • seg[6:0]    │         │ • DC Block    │
│ • an[3:0]     │         │ • Gain Ramp   │
│               │         │ • DAC (DA2)   │
└───────────────┘         └───────────────┘
```

---

## Hardware Configuration

### Clock Domains

| Clock | Frequency | Purpose |
|-------|-----------|---------|
| `clk` | 100 MHz | System clock (all modules) |
| `clk_20khz` | 20 kHz | Audio sample rate |
| `clk_spi` | 6.25 MHz | SPI communication |
| `clk_30hz` | 30 Hz | Display refresh |

### Memory Usage

| Memory | Size | Type | Purpose |
|--------|------|------|---------|
| Sample Buffer | 256 × 12-bit | BRAM | Audio frame storage |
| FFT Internal | Various | BRAM | Twiddle factors, reordering |
| FIFO Buffer | 1024 × 16-bit | BRAM | Audio output smoothing |

### Signal Processing Chain

```
ADC (12-bit) → BRAM → FFT (16-bit) → Magnitude (16-bit) → Display
                  ↓
                 IFFT (16-bit) → DC Block → Gain Ramp → DAC (12-bit)
```

---

## Module Dependencies

```
top.v
├── audio_input_pipeline.v
│   ├── mic_spi_capture.v
│   ├── mic_sample_clock.v
│   │   └── clock_divider.v
│   ├── audio_peak_detector.v
│   │   └── clock_divider.v
│   ├── sample_frame_packer.v
│   ├── sample_buffer_ram.v
│   ├── level_0_999.v
│   ├── seg_scan4.v
│   │   └── clock_divider.v
│   └── seven_segment.v
├── fft_processor.v
│   ├── xfft_0 (IP Core)
│   └── xfft_1 (IP Core)
├── display_pipeline.v
│   ├── oled_graphics_engine.v
│   │   ├── display_frame_smoother.v
│   │   └── stream_to_array.v
│   ├── frequency_band_filter.v
│   ├── Oled_Display.v (×2 instances)
│   └── clock_divider.v
└── audio_output_pipeline.v
    ├── audio_fifo_bridge.v
    ├── dc_block_hp.v
    ├── soft_gain_ramp.v
    ├── pcm16_to_u12.v
    └── dac_controller.v
        └── spi16_dual_da2.v
```

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| **End-to-End Latency** | ~25.6 ms (256 samples @ 20 kHz) |
| **FFT Processing Time** | ~3 µs (300 cycles @ 100 MHz) |
| **Display Frame Rate** | 30 Hz (33.3 ms/frame) |
| **Audio Frame Rate** | 78.125 Hz (12.8 ms/frame) |
| **Maximum Throughput** | 20,000 samples/sec (audio I/O) |

---

<div align="center">

**For detailed IP core specifications, refer to [README.md](README.md)**

</div>
