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
            if (busy && sclk_enable) begin
                // Determine whether this toggle is falling or rising by
                // inspecting the current SCLK value.  On a falling edge
                // (sclk_in == 1), update the output bits so they settle
                // before the upcoming rising edge.  On a rising edge
                // (sclk_in == 0), shift the registers and update the bit
                // counter.
                if (sclk) begin
                    // Falling edge: output the current MSB
                    dina <= sh_a[15];
                    dinb <= sh_b[15];
                end else begin
                    // Rising edge: shift and count
                    sh_a <= {sh_a[14:0], 1'b0};
                    sh_b <= {sh_b[14:0], 1'b0};
                    bit_cnt <= bit_cnt + 5'd1;
                    // When the last bit is shifted (bit_cnt==15), end frame
                    if (bit_cnt == 5'd15) begin
                        busy   <= 1'b0;
                        sync_n <= 1'b1;
                        // Idle bits may remain in dina/dinb; keep them
                    end
                end
            end
        end
    end

endmodule
