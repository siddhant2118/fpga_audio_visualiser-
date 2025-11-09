`timescale 1ns / 1ps
// slow_clock10Hz.v - compute peak (max) over a 0.1 s window for LED bar
module slow_clock10Hz(
    input  wire        CLK,        // 100 MHz
    input  wire [11:0] mic_in,     // unsigned 0..4095
    output reg  [15:0] maxvalue    // widen for threshold compares
);
    localparam integer WINDOW = 10_000_000; // 0.1 s @ 100 MHz
    reg [23:0] ctr = 24'd0;
    reg [15:0] cur_max = 16'd0;

    always @(posedge CLK) begin
        // update running max
        if ({4'b0, mic_in} > cur_max) cur_max <= {4'b0, mic_in};

        // every 0.1 s, publish and reset
        if (ctr == WINDOW-1) begin
            ctr      <= 24'd0;
            maxvalue <= cur_max;
            cur_max  <= 16'd0;
        end else begin
            ctr <= ctr + 1'b1;
        end
    end
endmodule