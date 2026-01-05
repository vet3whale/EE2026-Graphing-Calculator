`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.10.2025 14:12:14
// Design Name: 
// Module Name: dec_bcd_rom
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


module dec_bcd_rom(
  input  wire        clk,   // <<< NEW
  input  wire [6:0]  idx,   // 0..99
  output reg  [3:0]  tens,
  output reg  [3:0]  ones
);
  // Force block RAM
  (* rom_style="block", ram_style="block" *) reg [7:0] tbl [0:127]; // padded to 128

  integer i;
  integer t, o;

  initial begin
    // init 0..99
    for (i = 0; i < 100; i = i + 1) begin
      t = i / 10;
      o = i % 10;
      tbl[i] = {t[3:0], o[3:0]};
    end
    // pad 100..127 safely
    for (i = 100; i < 128; i = i + 1) begin
      tbl[i] = 8'h00;
    end
  end

  // 1-cycle synchronous read (synth to BRAM)
  reg [7:0] q;
  always @(posedge clk) begin
    q    <= tbl[idx];       // idx 0..127
    tens <= q[7:4];
    ones <= q[3:0];
  end
  endmodule
