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
  .FIFO_WRITE_DEPTH (1024),      // 2^DEPTH_L2
  .WRITE_DATA_WIDTH (16),
  .READ_DATA_WIDTH  (16),
  .FIFO_READ_LATENCY(1),         // rd_en -> dout next cycle
  .DOUT_RESET_VALUE ("0"),
  .PROG_FULL_THRESH (900),       // optional
  .PROG_EMPTY_THRESH(4)
) u_fifo (
  .rst     (~rst_n),             // XPM reset is active-high
  .wr_clk  (clk),
  .wr_en   (wr_valid),           // XPM handles 'full'
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

  // Prefetch buffer
  reg        have_prefetch;
  reg [15:0] prefetch;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_en          <= 1'b0;
      rd_en_q        <= 1'b0;
      have_prefetch  <= 1'b0;
      prefetch       <= 16'd0;
      sample_valid   <= 1'b0;
      sample_l_16    <= 16'sd0;
    end else begin
      // keep FIFO primed - request new data when we don't have prefetch and FIFO is not empty
      rd_en   <= ~have_prefetch & ~empty;
      rd_en_q <= rd_en;
      
      // Capture data from FIFO when read enable was asserted
      if (rd_en_q) begin
        prefetch      <= rd_data;
        have_prefetch <= 1'b1;
      end

      // Output logic: only assert valid when we have data available
      sample_valid <= 1'b0;
      if (ce_sample) begin
        if (have_prefetch) begin
          sample_l_16   <= prefetch;
          have_prefetch <= 1'b0;
          sample_valid  <= 1'b1;  // Only valid when we actually have data
        end
        // else: do NOT assert sample_valid - wait for data to be available
        // This prevents noise from repeating stale samples
      end
    end
  end
endmodule