`timescale 1ns/1ps

module spi16_dual_da2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load,
    input  wire [15:0] frame_a,
    input  wire [15:0] frame_b,
    output reg         busy,
    output reg         sync_n,
    input  wire        sclk_enable,
    input wire        sclk,
    output reg         dina,
    output reg         dinb
);
    // Shift registers for channel A and B.  Loaded when a new frame begins.
    reg [15:0] sh_a;
    reg [15:0] sh_b;
    // Bit counter: counts the number of rising edges seen (0-15).
    reg [4:0]  bit_cnt;

    // Control state machine.  busy is high once a load request is accepted
    // until 16 rising edges of SCLK have occurred.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy   <= 1'b0;
            sync_n <= 1'b1;
            dina   <= 1'b0;
            dinb   <= 1'b0;
            sh_a   <= 16'd0;
            sh_b   <= 16'd0;
            bit_cnt<= 5'd0;
        end else begin
            // Accept a load when idle
            if (!busy && load) begin
                busy    <= 1'b1;
                sync_n  <= 1'b0;      // assert frame
                sh_a    <= frame_a;
                sh_b    <= frame_b;
                bit_cnt <= 5'd0;
                // Present MSBs prior to first rising edge
                dina    <= frame_a[15];
                dinb    <= frame_b[15];
            end
            // During an active transfer, respond to SCLK toggles
            // sclk_enable pulses for one cycle on every sclk toggle
            // When sclk is high, we just had a rising edge (shift and sample)
            // When sclk is low, we just had a falling edge (output next bit)
            if (busy && sclk_enable) begin
                if (sclk) begin
                    // Rising edge: shift registers and count bits
                    // Check if this is the last bit (bit_cnt==15 means we've shifted 15 times,
                    // and after this shift we'll have shifted 16 times total)
                    if (bit_cnt == 5'd15) begin
                        // Last shift: shift out bit 0, then end frame
                        sh_a <= {sh_a[14:0], 1'b0};
                        sh_b <= {sh_b[14:0], 1'b0};
                        bit_cnt <= bit_cnt + 5'd1;
                        busy   <= 1'b0;
                        sync_n <= 1'b1;
                        // Idle bits may remain in dina/dinb; keep them
                    end else begin
                        // Normal shift
                        sh_a <= {sh_a[14:0], 1'b0};
                        sh_b <= {sh_b[14:0], 1'b0};
                        bit_cnt <= bit_cnt + 5'd1;
                    end
                end else begin
                    // Falling edge: output the current MSB so it's stable for next rising edge
                    dina <= sh_a[15];
                    dinb <= sh_b[15];
                end
            end
        end
    end

endmodule