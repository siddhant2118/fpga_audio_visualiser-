`timescale 1ns/1ps
module top_rehaan(
    input  wire clk,       
    input wire [15:0] sw,
    
    input wire [15:0] fft_data,
    input wire [15:0] wave_data,

    output wire cs_a,
    output wire sdin_a,
    output wire sclk_a,
    output wire d_cn_a,
    output wire resn_a,
    output wire vccen_a,
    output wire pmoden_a,

    output wire cs_b,
    output wire sdin_b,
    output wire sclk_b,
    output wire d_cn_b,
    output wire resn_b,
    output wire vccen_b,
    output wire pmoden_b
);

    wire [16*256-1:0] fft_flat;
    wire [16*256-1:0] wave_flat;

    data_reader fft_reader(clk, fft_data, fft_flat);
    data_reader wave_reader(clk, wave_data, wave_flat);

    wire clk6p25mhz;
    clock_div clk1(clk, 7, clk6p25mhz);

    // =======================================
    // DUMMY FFT AND WAVEFORM FOR NOW
    // REPLACE WITH ACTUAL DATA FROM TEAMMATES
    // =======================================
//    wire [16*16-1:0] fft_flat = {
//        16'h7F91, 16'hF00F, 16'hFFFF, 16'h0000,
//        16'hF00F, 16'hFFF1, 16'h5F1F, 16'hFEFF,
//        16'h9FFF, 16'hFFFF, 16'hF00F, 16'hFAFF,
//        16'hFF3F, 16'h7FFF, 16'h16FF, 16'hFFCF
//    };
    
//    reg [16*128-1:0] wave_flat_reg;
//    integer j;
//    always @ (*) begin
//        for (j=0; j<128; j=j+1) begin
//            if (j < 64) wave_flat_reg[j*16 +:16] = 65535 - j*512; // scale to 16-bit, max 65535
//            else wave_flat_reg[j*16 +:16] = j*512;
//        end
//    end
//    wire [16*128-1:0] wave_flat = wave_flat_reg;

    
//    reg [15:0] sine_lut [0:127];

//    initial begin
//        sine_lut[0] = 16'h7FFF;  sine_lut[1] = 16'h8647;  sine_lut[2] = 16'h8C8B;  sine_lut[3] = 16'h92C7;
//        sine_lut[4] = 16'h98F8;  sine_lut[5] = 16'h9F19;  sine_lut[6] = 16'hA527;  sine_lut[7] = 16'hAB1E;
//        sine_lut[8] = 16'hB0FB;  sine_lut[9] = 16'hB6B9;  sine_lut[10] = 16'hBC55; sine_lut[11] = 16'hC1CA;
//        sine_lut[12] = 16'hC717; sine_lut[13] = 16'hCC35; sine_lut[14] = 16'hD122; sine_lut[15] = 16'hD5DB;
//        sine_lut[16] = 16'hDA5D; sine_lut[17] = 16'hDEA8; sine_lut[18] = 16'hE2BB; sine_lut[19] = 16'hE694;
//        sine_lut[20] = 16'hEA33; sine_lut[21] = 16'hED97; sine_lut[22] = 16'hF0BF; sine_lut[23] = 16'hF3A9;
//        sine_lut[24] = 16'hF655; sine_lut[25] = 16'hF8C2; sine_lut[26] = 16'hFAF0; sine_lut[27] = 16'hFCDD;
//        sine_lut[28] = 16'hFE89; sine_lut[29] = 16'hFFF4; sine_lut[30] = 16'h011C; sine_lut[31] = 16'h0201;
//        sine_lut[32] = 16'h02A3; sine_lut[33] = 16'h0301; sine_lut[34] = 16'h031B; sine_lut[35] = 16'h02F1;
//        sine_lut[36] = 16'h0283; sine_lut[37] = 16'h01D2; sine_lut[38] = 16'h00DE; sine_lut[39] = 16'hFFAA;
//        sine_lut[40] = 16'hFE36; sine_lut[41] = 16'hFC86; sine_lut[42] = 16'hFA9A; sine_lut[43] = 16'hF874;
//        sine_lut[44] = 16'hF61A; sine_lut[45] = 16'hF38F; sine_lut[46] = 16'hF0D6; sine_lut[47] = 16'hEDEF;
//        sine_lut[48] = 16'hEADE; sine_lut[49] = 16'hE7A7; sine_lut[50] = 16'hE44D; sine_lut[51] = 16'hE0D5;
//        sine_lut[52] = 16'hDD45; sine_lut[53] = 16'hD99F; sine_lut[54] = 16'hD5E8; sine_lut[55] = 16'hD222;
//        sine_lut[56] = 16'hCE52; sine_lut[57] = 16'hCA7C; sine_lut[58] = 16'hC6A4; sine_lut[59] = 16'hC2CE;
//        sine_lut[60] = 16'hBF00; sine_lut[61] = 16'hBB3D; sine_lut[62] = 16'hB78A; sine_lut[63] = 16'hB3EB;
//        sine_lut[64] = 16'hB064; sine_lut[65] = 16'hACF9; sine_lut[66] = 16'hA9AE; sine_lut[67] = 16'hA686;
//        sine_lut[68] = 16'hA385; sine_lut[69] = 16'hA0AD; sine_lut[70] = 16'h9E00; sine_lut[71] = 16'h9B82;
//        sine_lut[72] = 16'h9935; sine_lut[73] = 16'h971B; sine_lut[74] = 16'h9538; sine_lut[75] = 16'h938D;
//        sine_lut[76] = 16'h921B; sine_lut[77] = 16'h90E4; sine_lut[78] = 16'h8FED; sine_lut[79] = 16'h8F34;
//        sine_lut[80] = 16'h8EC0; sine_lut[81] = 16'h8E93; sine_lut[82] = 16'h8EB0; sine_lut[83] = 16'h8F19;
//        sine_lut[84] = 16'h8FCF; sine_lut[85] = 16'h90D4; sine_lut[86] = 16'h9229; sine_lut[87] = 16'h93D0;
//        sine_lut[88] = 16'h95C9; sine_lut[89] = 16'h9817; sine_lut[90] = 16'h9ABB; sine_lut[91] = 16'h9DB4;
//        sine_lut[92] = 16'hA104; sine_lut[93] = 16'hA4AC; sine_lut[94] = 16'hA8AC; sine_lut[95] = 16'hAC03;
//        sine_lut[96] = 16'hAFB2; sine_lut[97] = 16'hB2B9; sine_lut[98] = 16'hB610; sine_lut[99] = 16'hB9BD;
//        sine_lut[100]= 16'hBDBF; sine_lut[101]= 16'hC214; sine_lut[102]= 16'hC6BA; sine_lut[103]= 16'hCBB0;
//        sine_lut[104]= 16'hD0F2; sine_lut[105]= 16'hD67D; sine_lut[106]= 16'hDC4F; sine_lut[107]= 16'hE266;
//        sine_lut[108]= 16'hE8C0; sine_lut[109]= 16'hEF58; sine_lut[110]= 16'hF628; sine_lut[111]= 16'hFD2A;
//        sine_lut[112]= 16'h0457; sine_lut[113]= 16'h0BA9; sine_lut[114]= 16'h1320; sine_lut[115]= 16'h1AB2;
//        sine_lut[116]= 16'h225E; sine_lut[117]= 16'h2A1B; sine_lut[118]= 16'h31E8; sine_lut[119]= 16'h39BC;
//        sine_lut[120]= 16'h4197; sine_lut[121]= 16'h4978; sine_lut[122]= 16'h5160; sine_lut[123]= 16'h594F;
//        sine_lut[124]= 16'h6144; sine_lut[125]= 16'h693F; sine_lut[126]= 16'h7142; sine_lut[127]= 16'h794C;
//    end
    
//    reg [16*128-1:0] wave_flat_reg;
//    integer k;
//    always @* begin
//        for (k=0; k<128; k=k+1)
//            wave_flat_reg[k*16 +:16] = sine_lut[k];
//    end
    
//    wire [16*128-1:0] wave_flat = wave_flat_reg;


    wire clk10khz;
    clock_div clk2(clk, 4999, clk10khz);
    wire [16*256-1:0] fft_suppressed;
    switch_manager swman(clk10khz, sw, fft_flat, fft_suppressed);


    wire [12:0] pixel_index_a;
    wire [12:0] pixel_index_b;
    wire [15:0] pixel_data_a;
    wire [15:0] pixel_data_b;
    display_controller disp_ctrl(
        .clk(clk),
        .fft_flat(fft_suppressed),
        .wave_flat(wave_flat),
        .pixel_index_a(pixel_index_a),
        .pixel_index_b(pixel_index_b),
        .colorA(pixel_data_a),
        .colorB(pixel_data_b)
    );
  
    Oled_Display oledA(.clk(clk6p25mhz),
                       .pixel_data(pixel_data_a),
                       .cs(cs_a),
                       .sdin(sdin_a),
                       .sclk(sclk_a),
                       .d_cn(d_cn_a),
                       .resn(resn_a),
                       .vccen(vccen_a),
                       .pmoden(pmoden_a),
                       .reset(0),
                       .frame_begin(),
                       .sending_pixels(),
                       .sample_pixel(),
                       .pixel_index(pixel_index_a));
              
    Oled_Display oledB(.clk(clk6p25mhz),
                       .pixel_data(pixel_data_b),
                       .cs(cs_b),
                       .sdin(sdin_b),
                       .sclk(sclk_b),
                       .d_cn(d_cn_b),
                       .resn(resn_b),
                       .vccen(vccen_b),
                       .pmoden(pmoden_b),
                       .reset(0),
                       .frame_begin(),
                       .sending_pixels(),
                       .sample_pixel(),
                       .pixel_index(pixel_index_b));
    
endmodule
