`timescale 1ns/1ps

module top_manu #(
    parameter integer RAMP_STEPS     = 256, //CHANGE
    parameter integer FIFO_DEPTH_L2  = 10
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               wr_valid,
    input  wire [15:0]        wr_data,
    input  wire               ramp_up,
    input  wire               ramp_down,
    output wire               sync_n,
    output wire               sclk,
    output wire               dina,
    output wire               dinb
);

    (* mark_debug = "true" *) wire        src_sample_valid;
    wire        src_sample_ready;
    wire signed [15:0] src_sample_l;

    wire        hp_valid;
    wire signed [15:0] hp_sample_l;

    wire        ramp_valid;
    wire signed [15:0] ramp_sample_l;

    /*(* mark_debug = "true" *) wire dina_debug;
    (* mark_debug = "true" *) wire sclk_debug;
    (* mark_debug = "true" *) wire sync_n_debug;
    assign dina_debug = dina;
    assign sclk_debug = sclk;
    assign sync_n_debug = sync_n;*/
    generate
        audio_bridge_fifo_sync #(
                .DEPTH_L2(FIFO_DEPTH_L2)
            ) u_bridge (
                .clk(clk),
                .rst_n(rst_n),
                .wr_valid(wr_valid),
                .wr_sample(wr_data),
                .ce_sample(src_sample_ready),
                .sample_valid(src_sample_valid),
                .sample_l_16(src_sample_l)
            );
    endgenerate

    dc_block_hp u_dc_l (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(src_sample_valid),
        .sample_in(src_sample_l),
        .sample_valid_out(hp_valid),
        .sample_out(hp_sample_l)
    );
    /*dc_block_hp u_dc_r (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(src_sample_valid),
        .sample_in(src_sample_r),
        .sample_valid_out( unused ),
        .sample_out(hp_sample_r)
    );*/
    
    soft_gain_ramp #(
        .RAMP_STEPS(RAMP_STEPS)
    ) u_ramp_l (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(hp_valid),
        .sample_in(hp_sample_l),
        .ramp_up(1'b1),
        .ramp_down(1'b0),
        .sample_valid_out(ramp_valid),
        .sample_out(ramp_sample_l)
    );
    /*soft_gain_ramp #(
        .RAMP_STEPS(RAMP_STEPS)
    ) u_ramp_r (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(hp_valid),
        .sample_in(hp_sample_r),
        .ramp_up(1'b1),
        .ramp_down(1'b0),
        .sample_valid_out( unused ),
        .sample_out(ramp_sample_r)
    );*/

    da2_stereo_top u_da2 (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(ramp_valid),
        .sample_ready(src_sample_ready),
        .sample_l_16(ramp_sample_l),
        .sync_n(sync_n),
        .sclk(sclk),
        .dina(dina),
        .dinb(dinb)
    );

endmodule
