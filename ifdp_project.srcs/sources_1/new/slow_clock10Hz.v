`timescale 1ns / 1ps

module slow_clock10Hz(
    input  wire        CLK,        
    input  wire [11:0] mic_in,     
    output reg  [15:0] maxvalue    
);
    localparam integer WINDOW = 10_000_000; 
    reg [23:0] ctr = 24'd0;
    reg [15:0] cur_max = 16'd0;

    always @(posedge CLK) begin
        
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