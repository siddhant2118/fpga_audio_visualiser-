# Debug Guide for FFT Audio Processor

## 🔍 Problem: No frequency bars, straight line on waveform OLED

### Possible Causes:
1. FFT IP not configured correctly
2. FFT IP not receiving/outputting data
3. State machine stuck or skipping states
4. Valid signals not working
5. Data formatting issue

---

## 🧪 Testing Strategy

### Test 1: Hardware Test with Debug Version (QUICKEST)

**Goal:** Bypass FFT IPs to test if basic data flow works

**Steps:**
1. Open `top.v`
2. Replace the instantiation:
   ```verilog
   // Change this:
   top_adhavan member_2 (
   
   // To this:
   top_adhavan_debug member_2 (
   ```
3. Synthesize and program Basys3
4. Test:
   - **If OLEDs now work:** Problem is FFT IP configuration
   - **If OLEDs still don't work:** Problem is state machine or data flow

---

### Test 2: Simulation Test (MOST THOROUGH)

**Goal:** See exactly what's happening in waveforms

**Steps:**

1. **Add simulation sources in Vivado:**
   - Sources → Add Sources → Add or create simulation sources
   - Add: `tb_top_adhavan.v`

2. **Configure simulation:**
   - Simulation Settings → Simulation → Set simulation time to `1 ms`

3. **Run simulation:**
   ```
   Flow Navigator → Simulation → Run Behavioral Simulation
   ```

4. **What to look for in waveform viewer:**
   - Does `state` transition through all states?
   - Does `fft_input_valid` go high during FEED_FFT?
   - Does `fft_output_valid` ever go high during COLLECT_FFT?
   - Does `fft_data_valid` go high 256 times during OUTPUT_FFT_MAG?
   - Does `wave_data_valid` go high 256 times during OUTPUT_WAVEFORM?

5. **Interpret results:**
   - **State stuck at IDLE:** `frame_done` not triggering
   - **State stuck at READ_SAMPLES:** BRAM interface issue
   - **State stuck at FEED_FFT:** FFT IP not accepting data (check `fft_input_tready`)
   - **State stuck at COLLECT_FFT:** FFT IP not outputting data (check `fft_output_valid`)
   - **State progresses but no valid outputs:** Valid signal logic issue

---

### Test 3: ILA (Integrated Logic Analyzer) - Hardware Debug

**Goal:** See real-time signals on actual FPGA

**Steps:**

1. **Add ILA IP to project:**
   - IP Catalog → Debug & Verification → ILA (Integrated Logic Analyzer)
   - Number of Probes: 8
   - Probe Width: Varies per signal

2. **Add to top_adhavan.v (after module declarations):**
   ```verilog
   // ILA for debugging
   ila_0 debug_ila (
       .clk(clk),
       .probe0(state),              // 4 bits
       .probe1(counter),            // 8 bits
       .probe2(fft_input_valid),    // 1 bit
       .probe3(fft_output_valid),   // 1 bit
       .probe4(fft_data_valid),     // 1 bit
       .probe5(wave_data_valid),    // 1 bit
       .probe6(frame_done),         // 1 bit
       .probe7(fft_data)            // 16 bits
   );
   ```

3. **Program FPGA and open Hardware Manager**
4. **Trigger on `frame_done` rising edge**
5. **Capture and analyze waveforms**

---

## 🔧 Quick Checks Before Deep Debugging

### Check 1: Verify FFT IP Generated
```
Sources → IP Sources → Should see:
  - xfft_0
  - xfft_1
```
If missing, regenerate IPs!

### Check 2: Check Synthesis Warnings
Look for:
- ❌ "Port 'xxx' is unconnected" for FFT IPs
- ❌ "Signal 'xxx' is always 0"
- ❌ "Timing constraints not met"

### Check 3: Verify Switch Settings
- Try with ALL switches ON (up position): `sw = 16'hFFFF`
- This disables filtering, all frequencies should pass

### Check 4: Check Member 1 Output
Add debug to verify Member 1 is providing data:
```verilog
// In top.v, add temporary LED output
assign led[7:0] = m2_rd_addr;  // Should count 0-255 when frame_done
```

---

## 🐛 Common Issues & Fixes

### Issue: FFT IP ports don't match code

**Symptom:** Synthesis error "Port 'xxx' not found in module xfft_0"

**Cause:** Your FFT IP version has different port names

**Fix:** Check generated IP instantiation template:
```
Sources → IP Sources → xfft_0 → right-click → 
  Open IP Example Design → check .veo file for port names
```

### Issue: FFT output always 'x' or 0

**Symptom:** In simulation, `fft_output_tdata` is 'x'

**Cause:** FFT IP behavioral model not in simulation

**Fix:** 
1. IP Sources → xfft_0 → right-click → Re-customize IP
2. Other → Generate Instantiation Template: Check
3. Regenerate → Include all output products

### Issue: State machine stuck at COLLECT_FFT

**Symptom:** `state = 4` forever, no progress

**Cause:** `fft_output_valid` never goes high

**Possible fixes:**
1. Check `aresetn` is connected correctly: `aresetn = ~reset`
2. Check `s_axis_config_tvalid = 1'b1` (always asserted)
3. Verify FFT IP configured for "Streaming I/O" mode
4. Check `fft_input_last` was asserted on last sample

### Issue: Waveform shows zeros

**Symptom:** `wave_data_valid` goes high but `wave_data = 0`

**Cause:** IFFT output scaling issue or all frequencies filtered

**Fix:**
1. Set all switches ON: `sw = 16'hFFFF`
2. Check scaling in COLLECT_IFFT: `>>> 8` might be too much
3. Try `>>> 4` or `>>> 2` instead

---

## 📊 Expected Simulation Results

For 1 kHz sine wave test (testbench):

```
[TB] State: IDLE
[TB] State: READ_SAMPLES
[TB] State: FEED_FFT
[TB] State: COLLECT_FFT
[TB] FFT Output: Bin 0 = 45
[TB] FFT Output: Bin 1 = 67
...
[TB] FFT Output: Bin 13 = 15234  ← PEAK HERE (1 kHz)
...
[TB] FFT Output: Bin 255 = 52
[TB] FFT Complete!
[TB] Maximum magnitude: 15234 at bin 13
[TB] Expected peak at bin ~13 for 1 kHz  ← PASS!
[TB] State: OUTPUT_FFT_MAG
[TB] State: FEED_IFFT
[TB] State: COLLECT_IFFT
[TB] State: OUTPUT_WAVEFORM
[TB] Waveform Output[0] = 2048
[TB] Waveform Output[1] = 2567
...
```

---

## 🚀 Next Steps

1. **Start with Test 1 (Debug Version)** - Fastest way to isolate issue
2. If that fails, check Member 1 is outputting data correctly
3. If that works, problem is definitely FFT IP - check configuration
4. Use Test 2 (Simulation) to see exact signal timing
5. If desperate, use Test 3 (ILA) to debug on hardware

---

## 📝 Report Back With:

1. Which test you tried
2. What you observed (state machine behavior, valid signals, etc.)
3. Any error messages from synthesis/simulation
4. Waveform screenshots if running simulation

This will help narrow down the exact issue!
