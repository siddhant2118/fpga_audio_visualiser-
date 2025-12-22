
`timescale 1ns/1ps
//
// Dual-Channel SPI DA2 Driver
// 16-bit SPI transmitter for dual DA2 DACs with SYNC framing
// Design rationale: Stereo infrastructure kept for future use (currently mono)
//

module spi16_dual_da2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load,
    input  wire [15:0] frame_a,
    input  wire [15:0] frame_b,
    output reg         busyread,
    output reg         sync_n,
    input  wire        sclk_enable,
    input wire        sclk,
    output reg         dina,
    output reg         dinb
);
    reg [15:0] sh_a;
    reg [15:0] sh_b;
    reg [4:0]  bit_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busyread   <= 1'b0;
            sync_n <= 1'b1;
            dina   <= 1'b0;
            dinb   <= 1'b0;
            sh_a   <= 16'd0;
            sh_b   <= 16'd0;
            bit_cnt<= 5'd0;
        end else begin
            if (!busyread && load) begin
                busyread    <= 1'b1;
                sync_n  <= 1'b0;
                sh_a    <= frame_a;
                sh_b    <= frame_b;
                bit_cnt <= 5'd0;
                dina    <= frame_a[15];
                dinb    <= frame_b[15];
            end
            if (busyread && sclk_enable) begin
                if (sclk) begin
                    if (bit_cnt == 5'd15) begin
                        sh_a <= {sh_a[14:0], 1'b0};
                        sh_b <= {sh_b[14:0], 1'b0};
                        bit_cnt <= bit_cnt + 5'd1;
                        busyread   <= 1'b0;
                        sync_n <= 1'b1;
                    end else begin
                        sh_a <= {sh_a[14:0], 1'b0};
                        sh_b <= {sh_b[14:0], 1'b0};
                        bit_cnt <= bit_cnt + 5'd1;
                    end
                end else begin
                    dina <= sh_a[15];
                    dinb <= sh_b[15];
                end
            end
        end
    end

endmodule
