`timescale 1ns / 1ps
// Audio_Capture.v  - replicate class repo behavior
module Audio_Capture(
    input wire CLK,               // 100 MHz
    input  wire cs,                // sampling "chip-select" window (~20 kHz), LOW during shift
    input wire MISO,              // JB3, serial data out of MIC3
    output wire clk_samp,          // JB1, feed-through of 'cs'
    output reg sclk,          // JB4, MIC3 serial clock (~2 MHz)
    output reg [11:0] sample  // 12-bit parallel sample
);
    reg [11:0] count2 = 0;
    reg [11:0] temp   = 0;

    initial sclk = 1'b0;
    assign clk_samp = cs;

    // Generate SCLK only while cs==0 (active window), like the reference
    always @(posedge CLK) begin
        count2 <= (cs == 1'b0) ? (count2 + 1'b1) : 12'd0;
        sclk   <= (count2==50 ||  count2==100 || count2==150 || count2==200 
                 ||  count2==250 || count2==300 || count2==350 || count2==400 
                 ||  count2==450 || count2==500 || count2==550 || count2==600 
                 ||  count2==650 || count2==700 || count2==750 || count2==800 
                  || count2==850 || count2==900 ||  count2==950 || count2==1000
                 ||  count2==1050|| count2==1100|| count2==1150|| count2==1200||
                   count2==1250|| count2==1300|| count2==1350|| count2==1400||
                   count2==1450|| count2==1500|| count2==1550|| count2==1600)
                   ? ~sclk : sclk;
    end

    // Shift on SCLK negedge
    always @(negedge sclk) begin
        temp <= {temp[10:0], MISO};
    end

    // Latch 12-bit on cs rising edge (end of frame)
    always @(posedge cs) begin
        sample <= temp[11:0];
    end
endmodule
