`timescale 1ns / 1ps
//
// FFT/IFFT Processor
// 256-point FFT for frequency analysis, switch-based filtering, IFFT reconstruction
//

module fft_processor #(
    parameter integer SYS_CLK_HZ = 100_000_000,
    parameter integer FS_HZ      = 20_000
)(
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

localparam IDLE             = 4'd0;
localparam READ_SAMPLES     = 4'd1;
localparam WAIT_FFT_READY   = 4'd2;
localparam FEED_FFT         = 4'd3;
localparam COLLECT_FFT      = 4'd4;
localparam OUTPUT_FFT_MAG   = 4'd5;
localparam FEED_IFFT        = 4'd6;
localparam COLLECT_IFFT     = 4'd7;
localparam OUTPUT_WAVEFORM  = 4'd8;

reg [3:0] state = IDLE;
reg [8:0] counter = 0;
reg [15:0] timeout_counter = 0;
reg [15:0] sample_buffer [0:255];

reg [15:0] fft_input_re;
reg [15:0] fft_input_im;
reg        fft_input_valid;
reg        fft_input_last;

wire [15:0] fft_output_re;
wire [15:0] fft_output_im;
wire        fft_output_valid;
wire        fft_output_last;
wire        fft_output_ready;

reg [15:0] fft_mag_buffer [0:255];
reg [31:0] fft_complex_buffer [0:255];

reg [15:0] ifft_input_re;
reg [15:0] ifft_input_im;
reg        ifft_input_valid;
reg        ifft_input_last;

wire [15:0] ifft_output_re;
wire [15:0] ifft_output_im;
wire        ifft_output_valid;
wire        ifft_output_last;
wire        ifft_output_ready;

reg [15:0] ifft_output_buffer [0:255];

reg signed [15:0] re_signed, im_signed;
reg [15:0] re_abs, im_abs, magnitude;
reg [3:0] band_num;
reg band_enabled;
reg [15:0] filtered_re, filtered_im;
reg signed [15:0] ifft_real_signed;
reg signed [15:0] scaled_ifft_output;

wire [31:0] fft_input_tdata  = {fft_input_im, fft_input_re};
wire [63:0] fft_output_tdata;
wire        fft_input_tready;

assign fft_output_re = fft_output_tdata[15:0];
assign fft_output_im = fft_output_tdata[31:16];

assign fft_output_ready = 1'b1;

xfft_0 forward_fft (
    .aclk                   (clk),
    .aclken                 (1'b1),
    .aresetn                (~reset),
    .s_axis_config_tdata    (8'b00000001),
    .s_axis_config_tvalid   (1'b1),
    .s_axis_config_tready   (),
    .s_axis_data_tdata      (fft_input_tdata),
    .s_axis_data_tvalid     (fft_input_valid),
    .s_axis_data_tready     (fft_input_tready),
    .s_axis_data_tlast      (fft_input_last),
    .m_axis_data_tdata      (fft_output_tdata),
    .m_axis_data_tvalid     (fft_output_valid),
    .m_axis_data_tready     (fft_output_ready),
    .m_axis_data_tlast      (fft_output_last),
    .event_frame_started    (),
    .event_tlast_unexpected (),
    .event_tlast_missing    (),
    .event_status_channel_halt(),
    .event_data_in_channel_halt (),
    .event_data_out_channel_halt()
);

wire [31:0] ifft_input_tdata  = {ifft_input_im, ifft_input_re};
wire [63:0] ifft_output_tdata;
wire        ifft_input_tready;

assign ifft_output_re = ifft_output_tdata[15:0];
assign ifft_output_im = ifft_output_tdata[31:16];

assign ifft_output_ready = 1'b1;

xfft_1 inverse_fft (
    .aclk                   (clk),
    .aclken                 (1'b1),
    .aresetn                (~reset),
    .s_axis_config_tdata    (8'b00000000),
    .s_axis_config_tvalid   (1'b1),
    .s_axis_config_tready   (),
    .s_axis_data_tdata      (ifft_input_tdata),
    .s_axis_data_tvalid     (ifft_input_valid),
    .s_axis_data_tready     (ifft_input_tready),
    .s_axis_data_tlast      (ifft_input_last),
    .m_axis_data_tdata      (ifft_output_tdata),
    .m_axis_data_tvalid     (ifft_output_valid),
    .m_axis_data_tready     (ifft_output_ready),
    .m_axis_data_tlast      (ifft_output_last),
    .event_frame_started    (),
    .event_tlast_unexpected (),
    .event_tlast_missing    (),
    .event_status_channel_halt(),
    .event_data_in_channel_halt (),
    .event_data_out_channel_halt()
);

always @(posedge clk) begin
    if (reset) begin
        state             <= IDLE;
        counter           <= 0;
        timeout_counter   <= 0;
        m2_rd_addr        <= 0;
        fft_input_valid   <= 0;
        fft_input_last    <= 0;
        ifft_input_valid  <= 0;
        ifft_input_last   <= 0;
        fft_data_valid    <= 0;
        wave_data_valid   <= 0;
    end else begin
        fft_input_valid  <= 0;
        fft_input_last   <= 0;
        ifft_input_valid <= 0;
        ifft_input_last  <= 0;
        fft_data_valid   <= 0;
        wave_data_valid  <= 0;
        timeout_counter <= timeout_counter + 1;

        case (state)
            IDLE: begin
                counter <= 0;
                timeout_counter <= 0;
                if (frame_done) begin
                    state      <= READ_SAMPLES;
                    m2_rd_addr <= 0;
                end
            end
            READ_SAMPLES: begin
                if (counter == 0) begin
                    m2_rd_addr <= 0;
                    counter    <= counter + 1;
                end else if (counter <= 256) begin
                    sample_buffer[counter-1] <= { {4{m2_rd_data[11]}}, m2_rd_data }; 
                    m2_rd_addr <= m2_rd_addr + 1;
                    counter <= counter + 1;
                    if (counter == 256) begin
                        state   <= FEED_FFT;
                        counter <= 0;
                    end
                end
            end
            FEED_FFT: begin
                if (fft_input_tready) begin 
                    fft_input_re    <= sample_buffer[counter];
                    fft_input_im    <= 16'd0; 
                    fft_input_valid <= 1'b1;
                    fft_input_last  <= (counter == 255);
                    if (counter == 255) begin
                        state   <= COLLECT_FFT;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end
            COLLECT_FFT: begin
                if (fft_output_valid) begin
                    timeout_counter <= 0;
                    re_signed = fft_output_re;
                    im_signed = fft_output_im;
                    re_abs = re_signed[15] ? (~re_signed + 1) : re_signed;
                    im_abs = im_signed[15] ? (~im_signed + 1) : im_signed;
                    magnitude = re_abs + im_abs;
                    fft_mag_buffer[counter]     <= magnitude;
                    fft_complex_buffer[counter] <= {fft_output_re, fft_output_im};

                    if (fft_output_last || counter == 255) begin
                        state   <= OUTPUT_FFT_MAG;
                        counter <= 0;
                        timeout_counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end else begin
                    if (timeout_counter > 5000) begin
                        fft_mag_buffer[counter] <= sample_buffer[counter][15] ? 
                                                   (~sample_buffer[counter] + 1) : 
                                                   sample_buffer[counter];
                        
                        if (counter == 255) begin
                            state   <= OUTPUT_FFT_MAG;
                            counter <= 0;
                            timeout_counter <= 0;
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end
            end
            OUTPUT_FFT_MAG: begin
                fft_data       <= fft_mag_buffer[counter];
                fft_data_valid <= 1'b1;

                if (counter == 255) begin
                    state   <= FEED_IFFT;
                    counter <= 0;
                    timeout_counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
            FEED_IFFT: begin
                if (ifft_input_tready) begin
                    band_num = counter[7:4]; 
                    band_enabled = sw[band_num];
                    filtered_re = band_enabled ? fft_complex_buffer[counter][15:0]  : 16'd0;
                    filtered_im = band_enabled ? fft_complex_buffer[counter][31:16] : 16'd0;
                    ifft_input_re    <= filtered_re;
                    ifft_input_im    <= filtered_im;
                    ifft_input_valid <= 1'b1;
                    ifft_input_last  <= (counter == 255);
                    if (counter == 255) begin
                        state   <= COLLECT_IFFT;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            end
            COLLECT_IFFT: begin
                if (ifft_output_valid) begin
                    timeout_counter <= 0;
                    ifft_real_signed = ifft_output_re;
                    scaled_ifft_output = ifft_real_signed >>> 2;
                    ifft_output_buffer[counter] <= scaled_ifft_output;

                    if (ifft_output_last || counter == 255) begin
                        state   <= OUTPUT_WAVEFORM;
                        counter <= 0;
                        timeout_counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end else begin
                    if (timeout_counter > 5000) begin
                        ifft_output_buffer[counter] <= sample_buffer[counter] << 6;
                        if (counter == 255) begin
                            state   <= OUTPUT_WAVEFORM;
                            counter <= 0;
                            timeout_counter <= 0;
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end
            end
            OUTPUT_WAVEFORM: begin
                wave_data       <= ifft_output_buffer[counter];
                wave_data_valid <= 1'b1;
                if (counter == 255) begin
                    state   <= IDLE;
                    counter <= 0;
                    timeout_counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

assign inter_out = {12'b0, state};
assign out_audio = timeout_counter[15] ? 16'hFFFF : 16'h0000;
assign out_valid = (state == OUTPUT_WAVEFORM);

endmodule