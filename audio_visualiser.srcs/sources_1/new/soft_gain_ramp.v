`timescale 1ns/1ps
//
// Soft Gain Ramp
// Anti-pop gain ramping to prevent clicks when audio starts/stops
// Design rationale: Currently always-on, but infrastructure supports dynamic muting
//

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
    reg [15:0] gain;
    localparam integer STEP_SIZE = (RAMP_STEPS > 0) ? (32767 / RAMP_STEPS) : 32767;
    reg [15:0] target_gain;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gain            <= 16'd0;
            target_gain     <= 16'd0;
            sample_out      <= 16'sd0;
            sample_valid_out<= 1'b0;
        end else begin
            sample_valid_out <= sample_valid_in;
            if (ramp_down) begin
                target_gain <= 16'd0;
            end else if (ramp_up) begin
                target_gain <= 16'd32767;
            end
            if (gain != target_gain) begin
                if (gain < target_gain) begin
                    if (gain + STEP_SIZE >= target_gain)
                        gain <= target_gain;
                    else
                        gain <= gain + STEP_SIZE;
                end else begin
                    if (gain <= STEP_SIZE)
                        gain <= 16'd0;
                    else
                        gain <= gain - STEP_SIZE;
                end
            end
            begin : mult_block
                reg signed [31:0] prod;
                reg  signed [31:0] scaled;
                prod = sample_in * $signed(gain);
                scaled = prod >>> 15;
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