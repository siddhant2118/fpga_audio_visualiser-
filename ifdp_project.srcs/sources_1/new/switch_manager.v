`timescale 1ns / 1ps
module switch_manager(input wire clk,
                      input wire [15:0] sw,
                      input wire [16*256-1:0] fft_flat,
                      output reg [16*256-1:0] fft_suppressed);
    
    localparam integer STEP_MAG = 16'd64;
    reg [15:0] target [0:255];
    reg [15:0] current [0:255];
    integer i;                  
    always @ (*) begin
        for (i = 0; i < 256; i = i + 1) begin
            target[i] = fft_flat[i*16 +:16];
            if (sw[15 - (i / 16)]) begin
                target[i] = target[i] >> 3;
            end
        end
    end
    
    always @ (posedge clk) begin
        for (i = 0; i < 256; i = i + 1) begin
           if (current[i] < target[i]) begin
               if (target[i] - current[i] > STEP_MAG)
                   current[i] <= current[i] + STEP_MAG;
               else
                   current[i] <= target[i];
           end else if (current[i] > target[i]) begin
               if (current[i] - target[i] > STEP_MAG)
                   current[i] <= current[i] - STEP_MAG;
               else
                   current[i] <= target[i];
           end else begin
               current[i] <= current[i];
           end
        end
    end
    
    always @ (*) begin
        for (i = 0; i < 256; i = i + 1)
            fft_suppressed[i*16 +:16] = current[i];
    end
                      
endmodule
