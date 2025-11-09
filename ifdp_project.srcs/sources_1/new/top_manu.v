`timescale 1ns/1ps

module top_manu #(
    parameter integer MODE           = 1,    // 0=tone, 1=fifo
    parameter integer GENERATOR      = 2,    // 0=triangle, 1=sine (tone mode)
    parameter integer RAMP_STEPS     = 256, //CHANGE
    // Tone parameters (default A4/E5)
    parameter integer TONE_FREQ_L_HZ = 444, //ALL CHANGE
    parameter integer TONE_FREQ_R_HZ = 444,
    parameter integer TONE_AMP_L     = 28000,
    parameter integer TONE_AMP_R     = 28000,
    // FIFO parameters
    parameter integer FIFO_DEPTH_L2  = 10
)(
    // Global clock/reset
    input  wire               clk,
    input  wire               rst_n,
    // FIFO write port (ignored in tone mode)
    input  wire               wr_valid,
    input  wire [15:0]        wr_data,
    // Tone ramp control (optional)
    input  wire               ramp_up,
    input  wire               ramp_down,
    // Outputs to Pmod-DA2
    output wire               sync_n,
    output wire               sclk,
    output wire               dina,
    output wire               dinb
);
    //assign rst_n = 1'b1;
    // -------------------------------------------------------------------------
    // Signals for sample flow.  sample_valid_X indicate when data is valid; all
    // modules propagate valid but do not apply backpressure except at the
    // generator/bridge which use ready/valid handshake.
    // -------------------------------------------------------------------------
    (* mark_debug = "true" *) wire        src_sample_valid;
    wire        src_sample_ready;
    wire signed [15:0] src_sample_l;
    wire signed [15:0] src_sample_r;

    // Signals after DC block
    wire        hp_valid;
    wire signed [15:0] hp_sample_l;
    wire signed [15:0] hp_sample_r;

    // Signals after gain ramp
    wire        ramp_valid;
    wire signed [15:0] ramp_sample_l;
    wire signed [15:0] ramp_sample_r;

    // DA2 interface handshake
    wire        da2_ready;
        // Mark these signals for debug
    (* mark_debug = "true" *) wire sample_ready_debug;
    (* mark_debug = "true" *) wire sample_valid_debug;
    (* mark_debug = "true" *) wire [15:0] sample_left_debug;
    (* mark_debug = "true" *) wire [15:0] sample_right_debug;
    assign sample_ready_debug = src_sample_ready;
    assign sample_valid_debug = ramp_valid;
    assign sample_left_debug = ramp_sample_l;
    assign sample_right_debug = ramp_sample_r;
    /*(* mark_debug = "true" *) wire dina_debug;
    (* mark_debug = "true" *) wire sclk_debug;
    (* mark_debug = "true" *) wire sync_n_debug;
    

    assign dina_debug = dina;
    assign sclk_debug = sclk;
    assign sync_n_debug = sync_n;*/

    // -------------------------------------------------------------------------
    // Source selection: tone generator or FIFO bridge.  When MODE=0, the tone
    // generator drives the audio.  When MODE=1, the FIFO bridge consumes
    // wr_data and outputs samples at a constant rate.  Only one source is
    // instantiated at synthesis time.
    // -------------------------------------------------------------------------
    generate
        if (MODE == 0) begin : g_tone
            if (GENERATOR == 0) begin : g_tri
            tone_gen_triangle #(
                .SAMPLE_RATE(20_000),
                .FREQ_L_HZ(TONE_FREQ_L_HZ),
                .FREQ_R_HZ(TONE_FREQ_R_HZ),
                .AMP_L(TONE_AMP_L),
                .AMP_R(TONE_AMP_R)
            ) u_tone (
                .clk(clk),
                .rst_n(rst_n),
                .sample_ready(src_sample_ready),
                .sample_valid(src_sample_valid),
                .sample_l_16(src_sample_l),
                .sample_r_16(src_sample_r)
            );
        end else if (GENERATOR == 1) begin : g_sin
            tone_gen_sine #(
                .SAMPLE_RATE(20_000),
                .FREQ_L_HZ(TONE_FREQ_L_HZ),
                .FREQ_R_HZ(TONE_FREQ_R_HZ),
                .AMP_L(TONE_AMP_L),
                .AMP_R(TONE_AMP_R)
            ) u_tone (
                .clk(clk),
                .rst_n(rst_n),
                .sample_ready(src_sample_ready),
                .sample_valid(src_sample_valid),
                .sample_l_16(src_sample_l),
                .sample_r_16(src_sample_r)
            );
        end else begin
            simple_square_handshake u_tone (
            .clk(clk),
            .rst_n(rst_n),
            .sample_ready(src_sample_ready),
            .sample_valid(src_sample_valid),
            .sample_out_l(src_sample_l),
            .sample_out_r(src_sample_r)
        );
        end
        end else begin : g_fifo
            // Instantiate audio bridge FIFO
            audio_bridge_fifo_sync #(
                .DEPTH_L2(FIFO_DEPTH_L2)
            ) u_bridge (
                .clk(clk),
                .rst_n(rst_n),
                .wr_valid(wr_valid),
                .wr_sample(wr_data),
                .ce_sample(src_sample_ready),
                .sample_valid(src_sample_valid),
                .sample_l_16(src_sample_l),
                .sample_r_16(src_sample_r)
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Optional DC blocking filter applied to both channels.  Always present.
    // -------------------------------------------------------------------------
    dc_block_hp u_dc_l (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(src_sample_valid),
        .sample_in(src_sample_l),
        .sample_valid_out(hp_valid),
        .sample_out(hp_sample_l)
    );
    dc_block_hp u_dc_r (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(src_sample_valid),
        .sample_in(src_sample_r),
        .sample_valid_out(/* unused */),
        .sample_out(hp_sample_r)
    );

    // -------------------------------------------------------------------------
    // Soft gain ramp.  Applied to both channels.  Ramp commands come from
    // external inputs.  Always present.
    // -------------------------------------------------------------------------
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
    soft_gain_ramp #(
        .RAMP_STEPS(RAMP_STEPS)
    ) u_ramp_r (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid_in(hp_valid),
        .sample_in(hp_sample_r),
        .ramp_up(1'b1),
        .ramp_down(1'b0),
        .sample_valid_out(/* unused */),
        .sample_out(ramp_sample_r)
    );

    // -------------------------------------------------------------------------
    // Connect to DA2 wrapper.  sample_valid comes from ramp; sample_ready
    // returns from the DA2 wrapper; this handshake controls the sample flow.
    // -------------------------------------------------------------------------
    da2_stereo_top u_da2 (
        .clk(clk),
        .rst_n(rst_n),
        .sample_valid(ramp_valid),
        .sample_ready(src_sample_ready),
        .sample_l_16(ramp_sample_l),
        .sample_r_16(ramp_sample_r),
        .sync_n(sync_n),
        .sclk(sclk),
        .dina(dina),
        .dinb(dinb)
    );

endmodule
