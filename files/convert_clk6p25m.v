`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.10.2025 14:10:48
// Design Name: 
// Module Name: convert_clk6p25m
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// =================================================
// Clock divider for 6.25 MHz (100 MHz / 16)
// =================================================
module convert_clk6p25m (input CLOCK, output reg clk6p25m = 1'b0);
  // 100 MHz / 16 -> 6.25 MHz (toggle every 8 cycles)
  reg [3:0] COUNT = 4'd0;  // <<< was [26:0]
  always @(posedge CLOCK) begin
    COUNT     <= (COUNT == 4'd7) ? 4'd0 : (COUNT + 4'd1);
    if (COUNT == 4'd7) clk6p25m <= ~clk6p25m;
  end
endmodule
