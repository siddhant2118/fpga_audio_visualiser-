// audio_bridge_fifo_sync.v
`timescale 1ns/1ps

module audio_bridge_fifo_sync #(
  parameter integer DEPTH_L2 = 10
)(
  input  wire        clk,
  input  wire        rst_n,

  // producer: iFFT sample
  input  wire        wr_valid,
  input  wire [15:0] wr_sample,

  // sample clock-enable (20 kHz)
  input  wire        ce_sample,

  // consumer: DAC
  output reg         sample_valid,
  output reg  [15:0] sample_l_16
);
  // FIFO: stores 32-bit words {L,R} = {sample,sample}
  wire        full, empty;
  reg         rd_en, rd_en_q;
  wire [15:0] rd_data;

xpm_fifo_sync #(
  .FIFO_MEMORY_TYPE ("block"),   // force BRAM
  .ECC_MODE         ("no_ecc"),
  .FIFO_WRITE_DEPTH (2048),      // Increased from 1024 to 2048 for better buffering
  .WRITE_DATA_WIDTH (16),
  .READ_DATA_WIDTH  (16),
  .FIFO_READ_LATENCY(1),         // rd_en -> dout next cycle
  .DOUT_RESET_VALUE ("0"),
  .PROG_FULL_THRESH (1800),      // Increased threshold
  .PROG_EMPTY_THRESH(128)        // Increased from 4 to 128 for safety margin
) u_fifo (
  .rst     (~rst_n),             // XPM reset is active-high
  .wr_clk  (clk),
  .wr_en   (wr_valid & ~full),   // Only write if not full (prevent overflow)
  .din     (wr_sample),
  .full    (full),
  .prog_full(),                  // unused
  .rd_en   (rd_en),
  .dout    (rd_data),
  .empty   (empty),
  .prog_empty(),                 // unused
  .data_valid(),                 // unused (you're prefetching)
  .almost_full(),
  .almost_empty(),
  .wr_data_count(),
  .rd_data_count(),
  .sleep(1'b0)
);

  // Prefetch buffer with improved underrun handling
  reg        have_prefetch;
  reg [15:0] prefetch;
  reg [15:0] last_valid_sample;  // Hold last valid sample to prevent clicks on underrun

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_en             <= 1'b0;
      rd_en_q           <= 1'b0;
      have_prefetch     <= 1'b0;
      prefetch          <= 16'd0;
      last_valid_sample <= 16'd0;
      sample_valid      <= 1'b0;
      sample_l_16       <= 16'd0;
    end else begin
      // keep FIFO primed - request new data when we don't have prefetch and FIFO is not empty
      rd_en   <= ~have_prefetch & ~empty;
      rd_en_q <= rd_en;
      
      // Capture data from FIFO when read enable was asserted
      if (rd_en_q) begin
        prefetch      <= rd_data;
        have_prefetch <= 1'b1;
      end

      // Output logic: always assert valid, but use last sample if FIFO is empty
      sample_valid <= 1'b0;
      if (ce_sample) begin
        if (have_prefetch) begin
          sample_l_16       <= prefetch;
          last_valid_sample <= prefetch;  // Save for underrun protection
          have_prefetch     <= 1'b0;
          sample_valid      <= 1'b1;
        end else if (!empty) begin
          // FIFO has data but prefetch isn't ready - output last sample and stay valid
          sample_l_16  <= last_valid_sample;
          sample_valid <= 1'b1;
        end else begin
          // FIFO empty - output zeros to prevent noise (better than repeating)
          sample_l_16  <= 16'd0;
          sample_valid <= 1'b1;  // Keep DAC running to prevent sync issues
        end
      end
    end
  end
endmodule