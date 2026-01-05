`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/13/2025 07:47:33 PM
// Design Name: 
// Module Name: mouse_click_edge
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


module mouse_click_edge(input clk, input rst, input btn_in, output reg rising_edge);
  reg d0, d1;
  always @(posedge clk) begin
    if (rst) begin d0<=0; d1<=0; rising_edge<=0; end
    else begin
      d0 <= btn_in;
      d1 <= d0;
      rising_edge <= d0 & ~d1; // only happens when d1 = 0 and d0 = 1
    end
  end
endmodule
