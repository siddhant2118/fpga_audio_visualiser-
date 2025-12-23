# 🎵 FPGA Audio Visualizer

> Real-time audio spectrum analyzer and waveform visualizer on Basys3 FPGA with dual OLED displays

[![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7-orange?style=for-the-badge&logo=xilinx)](https://www.xilinx.com)
[![Language](https://img.shields.io/badge/Language-Verilog-blue?style=for-the-badge)](https://en.wikipedia.org/wiki/Verilog)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Hardware Requirements](#-hardware-requirements)
- [System Architecture](#-system-architecture)
- [Resource Utilization](#-resource-utilization)
- [Project Structure](#-project-structure)
- [IP Core Configuration](#-ip-core-configuration)
- [Getting Started](#-getting-started)
- [Pin Assignments](#-pin-assignments)
- [Performance Specifications](#-performance-specifications)
- [Documentation](#-documentation)

---

## 🎯 Overview

This project implements a **real-time audio spectrum analyzer** on a Xilinx Artix-7 FPGA (Basys3 board). It captures live audio through a microphone, performs **256-point FFT analysis**, displays frequency spectrum and waveform on **dual RGB OLED screens**, and outputs processed audio through a DAC. Users can interactively filter 16 frequency bands using switches.

**Developed for:** EE2026 Digital Design Project, National University of Singapore

---

## ✨ Features

### 🎨 Dual Display System
- **OLED A**: Color-coded frequency spectrum bars (16 bands, 0-10 kHz)
- **OLED B**: Time-domain waveform visualization with temporal smoothing

### 🔊 Real-Time Audio Processing
- **20 kHz sampling rate** (professional audio quality)
- **256-point FFT/IFFT** using Xilinx IP cores
- **DC blocking filter** (~5 Hz high-pass)
- **Anti-pop circuitry** with soft gain ramping
- **Switch-controlled frequency filtering** (16 independent bands)

### 📊 Visual Feedback
- **16 LED bar graph** showing audio levels
- **7-segment display** for peak level (0-999)
- **Smooth animations** with frame buffering

### 🎛️ Interactive Controls
- **16 switches**: Enable/disable individual frequency bands
- Real-time frequency filtering with IFFT reconstruction
- Live audio output through stereo DAC

---

## 🔧 Hardware Requirements

| Component | Model | Function |
|-----------|-------|----------|
| **FPGA Board** | Digilent Basys3 (Artix-7 XC7A35T) | Main processing unit |
| **Microphone** | Digilent PmodMIC3 (ADCS7476) | 12-bit audio capture, 20 kHz |
| **Audio Output** | Digilent PmodDA2 (DAC121S101) | Dual 12-bit DAC, stereo output |
| **Display #1** | Digilent Pmod OLEDrgb | 96×64 RGB OLED (spectrum bars) |
| **Display #2** | Digilent Pmod OLEDrgb | 96×64 RGB OLED (waveform) |

### 📍 Pin Assignments

| Pmod | Connector | Function | Interface |
|------|-----------|----------|-----------|
| MIC3 | **JB** | Audio capture | SPI (20 kHz sampling) |
| DA2 | **JC** | Stereo audio output | Dual SPI DAC |
| OLEDrgb #1 | **JD** | FFT spectrum display | SPI + Control |
| OLEDrgb #2 | **JA** | Waveform display | SPI + Control |

---

## 🏗️ System Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   MIC3 ADC   │────▶│  FFT Engine  │────▶│   Frequency  │────▶│  Dual OLED   │
│  (20 kHz)    │     │  (256-point) │     │   Filtering  │     │   Graphics   │
│   12-bit     │     │              │     │  (16 bands)  │     │   Engine     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                     │                      ▲
                            │                     │                      │
                            ▼                     ▼              ┌──────────────┐
                     ┌──────────────┐     ┌──────────────┐      │   LED Bar    │
                     │ IFFT Engine  │     │ Peak Detector│─────▶│   7-Segment  │
                     │ (256-point)  │     │   (100 ms)   │      │   Display    │
                     └──────────────┘     └──────────────┘      └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  DC Block +  │
                     │  Anti-Pop    │
                     │  Filtering   │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   DAC + FIFO │
                     │  (Stereo)    │
                     └──────────────┘
```

### 🔄 Processing Pipeline

1. **Audio Input Pipeline** → Microphone capture, peak detection, frame packing
2. **FFT Processor** → Forward FFT, frequency analysis, band filtering
3. **Display Pipeline** → Dual OLED rendering with temporal smoothing
4. **Audio Output Pipeline** → IFFT reconstruction, filtering, DAC output

---

## 📊 Resource Utilization

### Final Implementation Results (Post Place & Route)

| Resource | Used | Available | Utilization |
|----------|------|-----------|-------------|
| **Slice LUTs** | 19,828 | 20,800 | **95.3%** |
| **Flip-Flops** | 16,813 | 41,600 | **40.4%** |
| **DSP Blocks** | 21 | 90 | **23.3%** |
| **Block RAM (36Kb)** | 5.0 | 50 | **10.0%** |

### IP Core Resource Breakdown

| Component | LUTs | FFs | BRAM | DSPs |
|-----------|------|-----|------|------|
| **xfft_0** (Forward FFT) | 2,262 | 3,565 | 1.5 | 9 |
| **xfft_1** (Inverse FFT) | 2,262 | 3,565 | 1.5 | 9 |
| **User Logic** | 15,304 | 9,683 | 2.0 | 3 |

> ⚠️ **Note**: High LUT utilization (95%) is primarily due to dual FFT cores and graphics engines. Design successfully meets timing at 100 MHz.

---

## 📁 Project Structure

```
audio_visualiser/
├── audio_visualiser.srcs/
│   ├── sources_1/
│   │   ├── new/                    # User Verilog modules (25 files)
│   │   │   ├── top.v              # Top-level system integration
│   │   │   ├── audio_input_pipeline.v
│   │   │   ├── fft_processor.v
│   │   │   ├── display_pipeline.v
│   │   │   ├── audio_output_pipeline.v
│   │   │   └── [20 utility modules]
│   │   └── ip/                     # Xilinx IP cores
│   │       ├── xfft_0/            # Forward FFT (256-point)
│   │       └── xfft_1/            # Inverse FFT (256-point)
│   └── constrs_1/
│       └── new/
│           └── Basys3_Master.xdc  # Pin constraints
├── audio_visualiser.xpr           # Vivado project file
├── README.md                       # This file
└── MODULE_STRUCTURE.md            # Detailed module documentation
```

### 📦 Key Modules

#### **Audio Input Pipeline**
- `audio_input_pipeline.v` - Main audio capture controller
- `mic_spi_capture.v` - SPI interface for MIC3 ADC
- `mic_sample_clock.v` - 20 kHz chip select generator
- `audio_peak_detector.v` - Peak level detection (100 ms windows)
- `sample_frame_packer.v` - 256-sample frame collector
- `sample_buffer_ram.v` - Dual-port BRAM buffer

#### **FFT Processing**
- `fft_processor.v` - FFT/IFFT state machine and control
- `xfft_0` (IP) - 256-point forward FFT
- `xfft_1` (IP) - 256-point inverse FFT

#### **Display Pipeline**
- `display_pipeline.v` - Dual OLED controller
- `oled_graphics_engine.v` - Pixel-by-pixel rendering
- `display_frame_smoother.v` - Temporal filtering (reduces flicker)
- `frequency_band_filter.v` - Switch-controlled filtering
- `Oled_Display.v` - Low-level OLED driver (PmodOLEDrgb)

#### **Audio Output Pipeline**
- `audio_output_pipeline.v` - Main DAC controller
- `audio_fifo_bridge.v` - 1024-sample FIFO buffer
- `dc_block_hp.v` - DC blocking high-pass filter
- `soft_gain_ramp.v` - Anti-pop gain ramping
- `dac_controller.v` - Dual-channel DAC interface

---

## 🔬 IP Core Configuration

### Xilinx Fast Fourier Transform (xFFT v9.1)

Both `xfft_0` (forward) and `xfft_1` (inverse) use identical configurations:

| Parameter | Value |
|-----------|-------|
| **Transform Length** | 256 points |
| **Architecture** | Pipelined Streaming I/O |
| **Input Width** | 16 bits (real + imaginary) |
| **Output Width** | 25 bits (real + imaginary) |
| **Data Format** | Fixed-point |
| **Scaling** | Unscaled |
| **Rounding** | Truncation |
| **Input/Output Ordering** | Natural order |
| **Memory Type** | Block RAM |
| **Clock Frequency** | 100 MHz |
| **Transform Direction** | Runtime configurable via `s_axis_config_tdata` |

**Direction Control:**
- `s_axis_config_tdata = 8'b00000001` → Forward FFT
- `s_axis_config_tdata = 8'b00000000` → Inverse FFT

---

## 🚀 Getting Started

### Prerequisites

- **Xilinx Vivado** 2018.2 or later
- **Basys3 FPGA board** with USB cable
- Required Pmods: MIC3, DA2, 2× OLEDrgb
- **Digilent Board Files** installed in Vivado

### Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/siddhant2118/fpga_audio_visualiser-.git
   cd fpga_audio_visualiser-
   ```

2. **Open in Vivado**
   ```bash
   # Launch Vivado and open project
   vivado audio_visualiser.xpr
   ```

3. **Generate Bitstream**
   - Click "Generate Bitstream" in Vivado
   - Wait for synthesis, implementation, and bitstream generation (~10-15 minutes)

4. **Program FPGA**
   - Connect Basys3 board via USB
   - Click "Open Hardware Manager" → "Auto Connect"
   - Right-click on device → "Program Device"
   - Select `audio_visualiser.bit` from `audio_visualiser.runs/impl_1/`

5. **Connect Pmods**
   - MIC3 → JB (top row)
   - DA2 → JC (top row)
   - OLEDrgb #1 → JD (top row) - Spectrum display
   - OLEDrgb #2 → JA (top row) - Waveform display

6. **Test**
   - Power on the board
   - Speak/play audio near the microphone
   - Observe spectrum bars on OLED A and waveform on OLED B
   - Toggle switches to filter frequency bands
   - Connect speaker/headphones to DAC output

---

## ⚙️ Performance Specifications

| Specification | Value |
|---------------|-------|
| **System Clock** | 100 MHz |
| **Audio Sample Rate** | 20 kHz (input & output) |
| **FFT Size** | 256 points |
| **Frequency Resolution** | 78.125 Hz/bin |
| **Frequency Range** | 0 - 10 kHz |
| **ADC Resolution** | 12 bits |
| **DAC Resolution** | 12 bits |
| **Display Refresh Rate** | ~30 Hz (with smoothing) |
| **Peak Detector Window** | 100 ms |
| **Audio Latency** | ~25.6 ms (256 samples @ 20 kHz) |

### Frequency Band Mapping

| Switch | Band Range | Center Freq | Color |
|--------|------------|-------------|-------|
| SW0 | 0-625 Hz | 312 Hz | Red |
| SW1 | 625-1250 Hz | 938 Hz | Orange |
| SW2 | 1250-1875 Hz | 1563 Hz | Yellow |
| SW3 | 1875-2500 Hz | 2188 Hz | Green |
| ... | ... | ... | ... |
| SW15 | 9375-10000 Hz | 9688 Hz | Purple |

---

## 📚 Documentation

- **[MODULE_STRUCTURE.md](MODULE_STRUCTURE.md)** - Detailed module descriptions and signal flow
- **Vivado Project Report** - Available in `audio_visualiser.runs/impl_1/`
- **IP Core Datasheets**:
  - [Xilinx xFFT IP Core (PG109)](https://docs.xilinx.com/v/u/en-US/pg109-xfft)
  - [PmodMIC3 Reference Manual](https://digilent.com/reference/pmod/pmodmic3/reference-manual)
  - [PmodDA2 Reference Manual](https://digilent.com/reference/pmod/pmodda2/reference-manual)
  - [PmodOLEDrgb Reference Manual](https://digilent.com/reference/pmod/pmodoledrgb/reference-manual)

---

## 🎓 Project Background

This project was developed as part of **EE2026 Digital Design** coursework at the **National University of Singapore (NUS)**. It demonstrates advanced FPGA design concepts including:

- Real-time digital signal processing (FFT/IFFT)
- Complex system integration with multiple peripherals
- Memory management (Block RAM, FIFOs)
- Hardware interfaces (SPI protocols)
- Graphics rendering and display control
- Pipeline design and dataflow optimization

---

## 🤝 Contributors

**Team Members:**
- Siddhant Singh (@siddhant2118)
- Adhavan (@airboy99)
- Rehaan (@RehaanMahmood)
- Manu (@manudagur87)

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **National University of Singapore** - EE2026 Digital Design Course
- **Xilinx/AMD** - Vivado Design Suite and IP cores
- **Digilent Inc.** - Basys3 board and Pmod peripherals

---

<div align="center">

**Made with ❤️ on Xilinx Artix-7 FPGA**

⭐ Star this repo if you find it useful!

</div>
