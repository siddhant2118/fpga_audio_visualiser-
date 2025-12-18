`timescale 1ns / 1ps
//
// DAC Controller
// Stereo 12-bit DA2 SPI interface at 48 kHz
//

module dac_controller(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_valid,
    output reg                sample_ready,
    input  wire signed [15:0] sample_l_16,
    output wire               sync_n,
    output wire               sclk,
    output wire               dina,
    output wire               dinb
);
    clock_divider #(.WIDTH(32)) u_nco (
    .clk(clk),
    .divisor(32'd156),
    .slow_clk(sclk)
);
    reg sclk_d;          
    reg sclk_enable;     
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_d      <= 1'b0;
            sclk_enable <= 1'b0;
        end else begin
            sclk_d      <= sclk;               
            sclk_enable <= (sclk ^ sclk_d);    
        end
    end
    
    (* mark_debug = "true", keep = "true" *) wire [11:0] l_u12;
    (* mark_debug = "true", keep = "true" *) wire [11:0] r_u12;
    pcm16_to_u12 u_conv_l (
        .s16(sample_l_16),
        .u12(l_u12)
    );
    /*pcm16_to_u12 #(.ENABLE_DITHER(0)) u_conv_r (
        .s16(sample_r_16),
        .u12(r_u12)
    );*/


    (* mark_debug = "true", keep = "true" *) reg [15:0] frame_a;
    (* mark_debug = "true", keep = "true" *) reg [15:0] frame_b;
    wire [15:0] frame_a_next = {4'b0000, l_u12};
    wire [15:0] frame_b_next = {4'b0000, l_u12};


    (* mark_debug = "true", keep = "true" *) reg  load_reg;
    (* mark_debug = "true", keep = "true" *) wire busy;


    spi16_dual_da2 u_spi (
        .clk(clk),
        .rst_n(rst_n),
        .load(load_reg),
        .frame_a(frame_a),
        .frame_b(frame_b),
        .busy(busy),
        .sclk_enable(sclk_enable),
        .sync_n(sync_n),
        .sclk(sclk),
        .dina(dina),
        .dinb(dinb)
    );

    //ready/valid handsake
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_ready <= 1'b1;
            load_reg     <= 1'b0;
            frame_a      <= 16'd0;
            frame_b      <= 16'd0;
        end else begin
            load_reg <= 1'b0;
            if (!busy && sample_valid && sample_ready) begin
                frame_a      <= frame_a_next;
                frame_b      <= frame_b_next;
                load_reg     <= 1'b1;
                sample_ready <= 1'b0;
            end else if (!busy && !sample_ready) begin
                sample_ready <= 1'b1;
            end
        end
    end
endmodule