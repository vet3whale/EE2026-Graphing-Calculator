`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.10.2025 14:22:23
// Design Name: 
// Module Name: font5x7_bram
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


// ----------------------------------------------------------
// 5x7 ASCII font ROM (BRAM): addr = char[6:0]*7 + row7[2:0]
// returns row_bits[4:0] for that row. One-cycle synchronous.
// ----------------------------------------------------------
module font5x7_bram (
  input  wire        clk,
  input  wire [6:0]  ch,     // 0..127 (we only use '0'..'9', 'A'..'Z', etc.)
  input  wire [2:0]  row7,   // 0..6
  output reg  [4:0]  row_bits
);
  localparam DEPTH = 128*7;  // 896 rows
  (* rom_style="block", ram_style="block" *) reg [4:0] mem [0:DEPTH-1];
  wire [9:0] addr = {ch, row7}; // ch*7 + row7 (since 7 is not power of 2, pack as concat)
  integer i;

  initial begin
    // Default all zeros
    for (i=0; i<DEPTH; i=i+1) mem[i] = 5'b00000;

    // ---- Fill only the glyphs you actually use ----
    // Digits '0'..'9' (0x30..0x39)
    // Each row is 5 bits, MSB = leftmost pixel of 5
    // 0
    mem[{7'h30,3'd0}] = 5'b11111; mem[{7'h30,3'd1}] = 5'b10001; mem[{7'h30,3'd2}] = 5'b10001;
    mem[{7'h30,3'd3}] = 5'b10001; mem[{7'h30,3'd4}] = 5'b10001; mem[{7'h30,3'd5}] = 5'b10001;
    mem[{7'h30,3'd6}] = 5'b11111;
    // 1
    mem[{7'h31,3'd0}] = 5'b00100; mem[{7'h31,3'd1}] = 5'b01100; mem[{7'h31,3'd2}] = 5'b00100;
    mem[{7'h31,3'd3}] = 5'b00100; mem[{7'h31,3'd4}] = 5'b00100; mem[{7'h31,3'd5}] = 5'b00100;
    mem[{7'h31,3'd6}] = 5'b11111;
    // ... (fill 2..9 same patterns as your current case)

    // Letters you use: A,B,C,D,E,H,I,J,K,L,M,N,O,P,R,S,T,U,V,X (add more if needed)
    // Example: 'D' (0x44)
    mem[{7'h44,3'd0}] = 5'b11110; mem[{7'h44,3'd1}] = 5'b10001; mem[{7'h44,3'd2}] = 5'b10001;
    mem[{7'h44,3'd3}] = 5'b10001; mem[{7'h44,3'd4}] = 5'b10001; mem[{7'h44,3'd5}] = 5'b10001;
    mem[{7'h44,3'd6}] = 5'b11110;

    // 'E' (0x45)
    mem[{7'h45,3'd0}] = 5'b11111; mem[{7'h45,3'd1}] = 5'b10000; mem[{7'h45,3'd2}] = 5'b10000;
    mem[{7'h45,3'd3}] = 5'b11111; mem[{7'h45,3'd4}] = 5'b10000; mem[{7'h45,3'd5}] = 5'b10000;
    mem[{7'h45,3'd6}] = 5'b11111;

    // 'L' (0x4C)
    mem[{7'h4C,3'd0}] = 5'b10000; mem[{7'h4C,3'd1}] = 5'b10000; mem[{7'h4C,3'd2}] = 5'b10000;
    mem[{7'h4C,3'd3}] = 5'b10000; mem[{7'h4C,3'd4}] = 5'b10000; mem[{7'h4C,3'd5}] = 5'b10000;
    mem[{7'h4C,3'd6}] = 5'b11111;

    // 'N' (0x4E), 'X' (0x58), 'T' (0x54), etc.
    // Fill out using the same 5x7 you already coded in draw_letter case.
  end

  always @(posedge clk)
    row_bits <= mem[addr];
endmodule
