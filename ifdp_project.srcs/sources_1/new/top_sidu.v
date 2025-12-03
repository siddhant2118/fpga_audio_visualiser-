`timescale 1ns / 1ps


module top_sidu(
    input  wire        clk,          
    input  wire        J_MIC3_Pin3,  // JB3 MISO
    output wire        J_MIC3_Pin1,  // JB1 CS 
    output wire        J_MIC3_Pin4,  // JB4 SCLK
    output reg  [15:0] led,
    output wire [3:0]  an,           
    output wire [6:0]  seg,          
    output wire        dp,           
    input  wire [7:0]  m2_rd_addr,   
    output wire [11:0] m2_rd_data,   
    output wire        frame_done    
);

    
    wire cs;
    clk_voice u_cs(.CLK(clk), .cs(cs));
    assign J_MIC3_Pin1 = cs;

    
    wire [11:0] mic_in;
    wire        sclk;
    Audio_Capture u_cap(
        .CLK(clk),
        .cs(cs),
        .MISO(J_MIC3_Pin3),
        .clk_samp(),         
        .sclk(J_MIC3_Pin4),
        .sample(mic_in)
    );
    assign J_MIC3_Pin4 = sclk;

    
    
    parameter DC_OFFSET = 12'd2048;     
    parameter NOISE_THRESHOLD = 12'd40; 
    
    
    wire signed [12:0] mic_centered = {1'b0, mic_in} - {1'b0, DC_OFFSET};  
    wire signed [11:0] mic_offset_removed = mic_centered[11:0];  
    
    
    wire [11:0] mic_abs = mic_offset_removed[11] ? (~mic_offset_removed + 1) : mic_offset_removed;
    wire [11:0] mic_gated = (mic_abs < NOISE_THRESHOLD) ? 12'd0 : mic_offset_removed;
    
    
    reg [11:0] mic_history [0:3];
    reg [1:0] hist_idx = 0;
    reg signed [13:0] mic_sum = 0;  
    wire [11:0] mic_filtered = mic_sum[13:2];  
    
    always @(posedge clk) begin
        if (sample_valid) begin
            
            mic_history[hist_idx] <= mic_gated;
            hist_idx <= hist_idx + 1;
            
            
            mic_sum <= mic_history[0] + mic_history[1] + mic_history[2] + mic_history[3];
        end
    end

    
    reg cs_q = 1'b1;
    always @(posedge clk) cs_q <= cs;
    wire sample_valid = (~cs_q) & cs;  

    
    wire [15:0] maxvalue;
    slow_clock10Hz u_peak(.CLK(clk), .mic_in(mic_in), .maxvalue(maxvalue));

    
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

   
    wire        wr_en_w;
    wire [7:0]  wr_addr_w;
    wire [11:0] wr_data_w;

    frame_packer #(.N_SAMPLES(256)) u_pack (
        .clk(clk),
        .s_valid(sample_valid),   
        .s_data(mic_filtered),    
        .wr_en(wr_en_w),
        .wr_addr(wr_addr_w),
        .wr_data(wr_data_w),
        .frame_done(frame_done)   
    );

    bram_frame_buffer #(.N_SAMPLES(256)) u_bram (
        .clk(clk),
        .wr_en(wr_en_w),
        .wr_addr(wr_addr_w),
        .wr_data(wr_data_w),
        .rd_addr(m2_rd_addr),     
        .rd_data(m2_rd_data)      
    );

endmodule