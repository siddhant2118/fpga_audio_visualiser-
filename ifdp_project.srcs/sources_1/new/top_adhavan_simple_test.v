`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ULTRA SIMPLE TEST MODULE
// Just outputs known patterns to verify displays work
//////////////////////////////////////////////////////////////////////////////////

module top_adhavan_simple_test (
    input  wire        clk,
    input  wire        reset,
    input  wire        frame_done,
    input  wire [11:0] m2_rd_data,
    output reg  [7:0]  m2_rd_addr,
    output wire [15:0] inter_out,
    input  wire [15:0] sw,
    output reg  [15:0] fft_data = 0,
    output reg  [15:0] wave_data = 0,
    output reg  fft_data_valid = 0,
    output reg  wave_data_valid = 0,
    output wire [15:0] out_audio,
    output wire        out_valid
);

// Counter for generating test patterns
reg [15:0] counter = 0;
reg [1:0] state = 0;

localparam IDLE = 0;
localparam OUTPUT_FFT = 1;
localparam OUTPUT_WAVE = 2;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        counter <= 0;
        fft_data_valid <= 0;
        wave_data_valid <= 0;
    end else begin
        fft_data_valid <= 0;
        wave_data_valid <= 0;
        
        case (state)
            IDLE: begin
                if (frame_done) begin
                    state <= OUTPUT_FFT;
                    counter <= 0;
                end
            end
            
            OUTPUT_FFT: begin
                // Output triangle wave pattern: 0, 1024, 2048, 3072, 4096...
                // This should create visible bars
                fft_data <= counter << 8;  // 0, 256, 512, 768...
                fft_data_valid <= 1;
                
                if (counter == 255) begin
                    state <= OUTPUT_WAVE;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
            
            OUTPUT_WAVE: begin
                // Output sawtooth pattern centered at 32768
                // This should create diagonal line on display
                wave_data <= 32768 + (counter << 7);  // 32768 + 0, 128, 256...
                wave_data_valid <= 1;
                
                if (counter == 255) begin
                    state <= IDLE;
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
        endcase
    end
end

assign inter_out = counter;
assign out_audio = wave_data;
assign out_valid = wave_data_valid;

endmodule
