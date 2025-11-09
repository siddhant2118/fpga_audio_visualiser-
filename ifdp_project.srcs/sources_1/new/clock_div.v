module clock_div (input wire clk,
                  input wire [63:0] number,
                  output reg slow_clk = 0);
    reg [63:0] count = 0;     
    always @ (posedge clk) begin
        count <= (count == number) ? 0 : count + 1;
        slow_clk <= (count == number) ? ~slow_clk : slow_clk;
    end          
endmodule