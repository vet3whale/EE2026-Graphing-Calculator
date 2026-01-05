`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2025 02:12:12 PM
// Design Name: 
// Module Name: cursor_crosshair
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


// ====== tiny crosshair cursor (local helper) ======
module cursor_crosshair (
  input  wire [6:0] x, input wire [6:0] y,     // current pixel
  input  wire [6:0] cx, input wire [6:0] cy,   // mouse position
  output wire on,
  output wire [15:0] pix
);
  // 3x3 plus shape centered at (cx,cy)
  localparam COLOUR = 16'hF800;
  wire dx0 = (x == cx);
  wire dy0 = (y == cy);
  wire dx1 = (x+1 == cx) || (x == cx+1);
  wire dy1 = (y+1 == cy) || (y == cy+1);
  assign on  = (dx0 && (dy0 || dy1)) || (dy0 && (dx0 || dx1));
  assign pix = COLOUR;
endmodule
