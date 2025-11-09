`timescale 1ns/1ps

module da2_stereo_top(
    input  wire               clk,
    input  wire               rst_n,
    // sample interface
    input  wire               sample_valid,
    output reg                sample_ready,
    input  wire signed [15:0] sample_l_16,
    // SPI outputs
    output wire               sync_n,
    output wire               sclk,
    output wire               dina,
    output wire               dinb
);
    // -------------------------------------------------------------------------
    // Instantiate the bit clock generator (NCO).  Produces sclk_bit and a
    // toggle enable.  The SCLK frequency is 16 � SAMPLE_RATE.
    // -------------------------------------------------------------------------
    clock_divider u_nco (
    .clk(clk),
    .reqtime(156),
    .slow_clk(sclk)
);
    reg sclk_d;          // delayed version of sclk
    reg sclk_enable;     // one-cycle pulse at every sclk toggle
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_d      <= 1'b0;
            sclk_enable <= 1'b0;
        end else begin
            sclk_d      <= sclk;               // capture previous sclk
            sclk_enable <= (sclk ^ sclk_d);    // high for one clk cycle on every toggle
        end
    end
    // -------------------------------------------------------------------------
    // Convert signed samples to unsigned 12-bit values.  Use two instances
    // operating in parallel.  No dither is applied by default.
    // -------------------------------------------------------------------------
    (* mark_debug = "true", keep = "true" *) wire [11:0] l_u12;
    (* mark_debug = "true", keep = "true" *) wire [11:0] r_u12;
    pcm16_to_u12 #(.ENABLE_DITHER(0)) u_conv_l (
        .s16(sample_l_16),
        .u12(l_u12)
    );
    /*pcm16_to_u12 #(.ENABLE_DITHER(0)) u_conv_r (
        .s16(sample_r_16),
        .u12(r_u12)
    );*/


    // Pack the 16-bit frames: top four bits zeros, followed by 12 data bits.
    // Latch the frames when we accept a sample to prevent them from changing during transmission
    (* mark_debug = "true", keep = "true" *) reg [15:0] frame_a;
    (* mark_debug = "true", keep = "true" *) reg [15:0] frame_b;
    wire [15:0] frame_a_next = {4'b0000, l_u12};
    wire [15:0] frame_b_next = {4'b0000, l_u12};

    // Signals for SPI shifter
    (* mark_debug = "true", keep = "true" *) reg  load_reg;
    (* mark_debug = "true", keep = "true" *) wire busy;

    // -------------------------------------------------------------------------
    // Instantiate the dual-channel SPI shifter.  Connect the NCO outputs.
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // Ready/valid handshake.  Accept a new sample when busy is low and
    // sample_valid is asserted.  Deassert sample_ready during an active
    // transfer.  load_reg is pulsed high for exactly one cycle when a
    // sample is accepted.
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_ready <= 1'b1;
            load_reg     <= 1'b0;
            frame_a      <= 16'd0;
            frame_b      <= 16'd0;
        end else begin
            // Default values
            load_reg <= 1'b0;
            // When idle and a valid sample arrives, capture it
            if (!busy && sample_valid && sample_ready) begin
                // Latch the frame data when accepting the sample
                frame_a      <= frame_a_next;
                frame_b      <= frame_b_next;
                // Accept sample and trigger load into SPI
                load_reg     <= 1'b1;
                sample_ready <= 1'b0;
            end else if (!busy && !sample_ready) begin
                // Once the SPI has completed, re-assert sample_ready
                sample_ready <= 1'b1;
            end
        end
    end
endmodule