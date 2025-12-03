`timescale 1ns/1ps

module audio_bridge_fifo_sync #(
  parameter integer DEPTH_L2 = 10
)(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        wr_valid,
  input  wire [15:0] wr_sample,
  input  wire        ce_sample,
  output reg         sample_valid,
  output reg  [15:0] sample_l_16
);

  wire        full, empty;
  reg         rd_en, rd_en_q;
  wire [15:0] rd_data;

xpm_fifo_sync #(
  .FIFO_MEMORY_TYPE ("block"), 
  .ECC_MODE         ("no_ecc"),
  .FIFO_WRITE_DEPTH (1024),
  .WRITE_DATA_WIDTH (16),
  .READ_DATA_WIDTH  (16),
  .FIFO_READ_LATENCY(1),
  .DOUT_RESET_VALUE ("0"),
  .PROG_FULL_THRESH (900), 
  .PROG_EMPTY_THRESH(4)
) u_fifo (
  .rst     (~rst_n),             
  .wr_clk  (clk),
  .wr_en   (wr_valid),           
  .din     (wr_sample),
  .full    (full),
  .prog_full(),
  .rd_en   (rd_en),
  .dout    (rd_data),
  .empty   (empty),
  .sleep(1'b0)
);


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
      rd_en   <= ~have_prefetch & ~empty;
      rd_en_q <= rd_en;
      if (rd_en_q) begin
        prefetch      <= rd_data;
        have_prefetch <= 1'b1;
      end
      sample_valid <= 1'b0;
      if (ce_sample) begin
        if (have_prefetch) begin
          sample_l_16   <= prefetch;
          have_prefetch <= 1'b0;
          sample_valid  <= 1'b1;
        end
      end
    end
  end
endmodule