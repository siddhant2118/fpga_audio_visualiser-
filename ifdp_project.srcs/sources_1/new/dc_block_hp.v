`timescale 1ns/1ps

module dc_block_hp #(
    parameter signed [15:0] A_COEFF = 16'h7F00
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_valid_in,
    input  wire signed [15:0] sample_in,
    output reg                sample_valid_out,
    output reg  signed [15:0] sample_out
);
    // Previous input sample and previous output sample (Q1.15 format)
    reg signed [15:0] x_prev;
    reg signed [15:0] y_prev;

    // Intermediate 32-bit product for multiply
    reg signed [31:0] mult;
    reg signed [16:0] diff;
    reg signed [16:0] acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prev          <= 16'sd0;
            y_prev          <= 16'sd0;
            sample_out      <= 16'sd0;
            sample_valid_out<= 1'b0;
        end else begin
            sample_valid_out <= sample_valid_in;
            // Compute difference x[n] - x[n-1]
            if (sample_valid_in) begin
            diff = sample_in - x_prev;
            // Multiply previous output by coefficient a (Q1.15 × Q1.15 -> Q2.30)
            mult = y_prev * A_COEFF;
            // Sum difference and scaled y_prev; shift back to Q1.15
            acc = diff + (mult >>> 15);
            // Saturate to 16 bits
            if (acc > 17'sd32767) begin
                sample_out <= 16'sd32767;
            end else if (acc < -17'sd32768) begin
                sample_out <= -16'sd32768;
            end else begin
                sample_out <= acc[15:0];
            end
            // Update state
            x_prev <= sample_in;
            y_prev <= sample_out;
            end else begin
                sample_out <= sample_out;
            end
        end
    end

endmodule
