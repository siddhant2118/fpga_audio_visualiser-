`timescale 1ns/1ps

module soft_gain_ramp #(
    parameter integer RAMP_STEPS = 256
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_valid_in,
    input  wire signed [15:0] sample_in,
    input  wire               ramp_up,
    input  wire               ramp_down,
    output reg                sample_valid_out,
    output reg  signed [15:0] sample_out
);
    // Gain in Q1.15 format.  0x7FFF corresponds to unity.
    reg [15:0] gain;
    
    // Step increment/decrement.  Computed at elaboration time.
    localparam integer STEP_SIZE = (RAMP_STEPS > 0) ? (32767 / RAMP_STEPS) : 32767;

    // Target gain: 0 for ramp down, 32767 for ramp up
    reg [15:0] target_gain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gain            <= 16'd0;
            target_gain     <= 16'd0;
            sample_out      <= 16'sd0;
            sample_valid_out<= 1'b0;
        end else begin
            sample_valid_out <= sample_valid_in;
            // Update target based on ramp commands
            if (ramp_down) begin
                target_gain <= 16'd0;
            end else if (ramp_up) begin
                target_gain <= 16'd32767;
            end
            // Update gain towards target
            if (gain != target_gain) begin
                if (gain < target_gain) begin
                    // Attack: increase gain by step size, saturate at target
                    if (gain + STEP_SIZE >= target_gain)
                        gain <= target_gain;
                    else
                        gain <= gain + STEP_SIZE;
                end else begin
                    // Release: decrease gain by step size
                    if (gain <= STEP_SIZE)
                        gain <= 16'd0;
                    else
                        gain <= gain - STEP_SIZE;
                end
            end
            // Multiply input sample by gain (Q1.15 × Q1.15 -> Q2.30) and
            // shift back to Q1.15
            begin : mult_block
                reg signed [31:0] prod;
                reg  signed [31:0] scaled;
                prod = sample_in * $signed(gain);
                scaled = prod >>> 15;
                // Shift right by 15 for Q1.15 result
                // Saturate to 16 bits
                if (sample_valid_in) begin
                    if (scaled > 32'sd32767)
                        sample_out <= 16'sd32767;
                    else if (scaled < -32'sd32768)
                        sample_out <= -16'sd32768;
                    else
                        sample_out <= scaled[15:0];
                end else begin
                    sample_out <= sample_out;
                end
            end
        end
    end

endmodule
