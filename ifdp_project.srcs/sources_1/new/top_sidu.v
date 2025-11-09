`timescale 1ns / 1ps

// top_firwer_ledbar_7seg.v - LED bar + 3-digit loudness + 256-sample BRAM handoff
module top_sidu(
    input  wire        clk,          // 100 MHz
    input  wire        J_MIC3_Pin3,  // JB3 MISO
    output wire        J_MIC3_Pin1,  // JB1 CS window
    output wire        J_MIC3_Pin4,  // JB4 SCLK
    output reg  [15:0] led,
    output wire [3:0]  an,           // active low
    output wire [6:0]  seg,          // active low
    output wire        dp,           // active low

    // New handshake to Member 2
    input  wire [7:0]  m2_rd_addr,   // Member 2 drives 0..255 after frame_done
    output wire [11:0] m2_rd_data,   // 12-bit sample at that address
    output wire        frame_done    // 1-cycle pulse when buffer 0..255 just filled
);

    // 20 kHz CS window (unchanged)
    wire cs;
    clk_voice u_cs(.CLK(clk), .cs(cs));
    assign J_MIC3_Pin1 = cs;

    // MIC3 capture (unchanged)
    wire [11:0] mic_in;
    wire        sclk;
    Audio_Capture u_cap(
        .CLK(clk),
        .cs(cs),
        .MISO(J_MIC3_Pin3),
        .clk_samp(),          // not used
        .sclk(J_MIC3_Pin4),
        .sample(mic_in)
    );
    assign J_MIC3_Pin4 = sclk;

    // Make a 1-cycle valid pulse on each new sample (rising edge of cs)
    reg cs_q = 1'b1;
    always @(posedge clk) cs_q <= cs;
    wire sample_valid = (~cs_q) & cs;  // pulse when cs rises

    // Peak detector ~0.1 s (unchanged)
    wire [15:0] maxvalue;
    slow_clock10Hz u_peak(.CLK(clk), .mic_in(mic_in), .maxvalue(maxvalue));

    // LED bar identical to before
    reg [4:0] mode = 5'd0;
    always @(posedge clk) begin
        if      (maxvalue>=2047 && maxvalue<2167) begin led<=16'h0000; mode<=0;  end
        else if (maxvalue<2287)                  begin led<=16'h0001; mode<=1;  end
        else if (maxvalue<2407)                  begin led<=16'h0003; mode<=2;  end
        else if (maxvalue<2527)                  begin led<=16'h0007; mode<=3;  end
        else if (maxvalue<2647)                  begin led<=16'h000F; mode<=4;  end
        else if (maxvalue<2767)                  begin led<=16'h001F; mode<=5;  end
        else if (maxvalue<2887)                  begin led<=16'h003F; mode<=6;  end
        else if (maxvalue<3007)                  begin led<=16'h007F; mode<=7;  end
        else if (maxvalue<3127)                  begin led<=16'h00FF; mode<=8;  end
        else if (maxvalue<3247)                  begin led<=16'h01FF; mode<=9;  end
        else if (maxvalue<3367)                  begin led<=16'h03FF; mode<=10; end
        else if (maxvalue<3487)                  begin led<=16'h07FF; mode<=11; end
        else if (maxvalue<3607)                  begin led<=16'h0FFF; mode<=12; end
        else if (maxvalue<3727)                  begin led<=16'h1FFF; mode<=13; end
        else if (maxvalue<3847)                  begin led<=16'h3FFF; mode<=14; end
        else if (maxvalue<3967)                  begin led<=16'h7FFF; mode<=15; end
        else                                      begin led<=16'hFFFF; mode<=16; end
    end

    // 0..999 on the RIGHT THREE digits, LEFTMOST blank
    wire [9:0] val_999;
    level_0_999 u_map(.level_u16(maxvalue), .val_999(val_999));
    wire [3:0] ones     =  val_999 % 10;
    wire [3:0] tens     = (val_999 / 10)  % 10;
    wire [3:0] hundreds = (val_999 / 100) % 10;

    seg_scan4 u_scan(
        .clk(clk),
        .d3(4'hF), .d2(hundreds), .d1(tens), .d0(ones),
        .dp_mask(4'b1111),
        .an(an), .seg(seg), .dp(dp)
    );

    // Frame packer + BRAM (12-bit, 256 samples)
    wire        wr_en_w;
    wire [7:0]  wr_addr_w;
    wire [11:0] wr_data_w;

    frame_packer #(.N_SAMPLES(256)) u_pack (
        .clk(clk),
        .s_valid(sample_valid),   // 1 pulse per new sample
        .s_data(mic_in),          // 12-bit sample
        .wr_en(wr_en_w),
        .wr_addr(wr_addr_w),
        .wr_data(wr_data_w),
        .frame_done(frame_done)   // exposed to Member 2
    );

    bram_frame_buffer #(.N_SAMPLES(256)) u_bram (
        .clk(clk),
        .wr_en(wr_en_w),
        .wr_addr(wr_addr_w),
        .wr_data(wr_data_w),
        .rd_addr(m2_rd_addr),     // Member 2 drives 0..255 at 100 MHz
        .rd_data(m2_rd_data)      // you return the 12-bit sample
    );

endmodule