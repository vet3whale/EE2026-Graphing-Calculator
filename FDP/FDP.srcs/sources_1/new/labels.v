`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2025 21:13:23
// Design Name: 
// Module Name: labels
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

module menu_labels(
    input  [6:0] px, py,             // current pixel
    input  [6:0] str1_x, str1_y,     // top label origin
    input  [6:0] str2_x, str2_y,     // bottom label origin
    output wire txt1_on, txt2_on
);
    // 5x7 font (columns top->bottom in bit[6:0])
    function [6:0] row_bits;
      input [7:0] ch; input [2:0] cx;  // cx in [0..4]
      begin
        row_bits = 7'b0000000;
        case (ch)
          "A": case (cx)
                 0: row_bits = 7'b0011100;
                 1: row_bits = 7'b0100010;
                 2: row_bits = 7'b0111110;
                 3: row_bits = 7'b0100010;
                 4: row_bits = 7'b0100010;
                 default: row_bits = 7'b0000000;
               endcase
          "G": case (cx)
                 0: row_bits = 7'b0011100;
                 1: row_bits = 7'b0100000;
                 2: row_bits = 7'b0101110;
                 3: row_bits = 7'b0100010;
                 4: row_bits = 7'b0011110;
                 default: row_bits = 7'b0000000;
               endcase
          "P": case (cx)
                 0: row_bits = 7'b0111100;
                 1: row_bits = 7'b0100010;
                 2: row_bits = 7'b0111100;
                 3: row_bits = 7'b0100000;
                 4: row_bits = 7'b0100000;
                 default: row_bits = 7'b0000000;
               endcase
          "p": case (cx)
                 0: row_bits = 7'b0111100;
                 1: row_bits = 7'b0100010;
                 2: row_bits = 7'b0111100;
                 3: row_bits = 7'b0100000;
                 4: row_bits = 7'b0100000;
                 default: row_bits = 7'b0000000;
               endcase
          "r": case (cx)
                 0: row_bits = 7'b0011100;
                 1: row_bits = 7'b0100000;
                 2: row_bits = 7'b0100000;
                 3: row_bits = 7'b0100000;
                 4: row_bits = 7'b0100000;
                 default: row_bits = 7'b0000000;
               endcase
          "l": case (cx)
                 0: row_bits = 7'b0010000;
                 1: row_bits = 7'b0010000;
                 2: row_bits = 7'b0010000;
                 3: row_bits = 7'b0010000;
                 4: row_bits = 7'b0011100;
                 default: row_bits = 7'b0000000;
               endcase
          "t": case (cx)
                 0: row_bits = 7'b0010000;
                 1: row_bits = 7'b0111000;
                 2: row_bits = 7'b0010000;
                 3: row_bits = 7'b0010000;
                 4: row_bits = 7'b0001100;
                 default: row_bits = 7'b0000000;
               endcase
          "x": case (cx)
                 0: row_bits = 7'b0100010;
                 1: row_bits = 7'b0010100;
                 2: row_bits = 7'b0001000;
                 3: row_bits = 7'b0010100;
                 4: row_bits = 7'b0100010;
                 default: row_bits = 7'b0000000;
               endcase
          ".": case (cx)
                 0: row_bits = 7'b0000000;
                 1: row_bits = 7'b0000000;
                 2: row_bits = 7'b0000000;
                 3: row_bits = 7'b0000000;
                 4: row_bits = 7'b1000000;
                 default: row_bits = 7'b0000000;
               endcase
          " ": row_bits = 7'b0000000;
          default: row_bits = 7'b0000000;
        endcase
      end
    endfunction

    // glyph pixel on? (horizontal, not rotated)
    function glyph_on;
        input [7:0] ch; input [6:0] px, py; input [6:0] sx, sy;
        integer cx, cy;
        reg [6:0] bits;
        begin
            glyph_on = 1'b0;
            if (px >= sx && py >= sy) begin
                cy = py - sy; // row in glyph
                cx = px - sx; // column in glyph
                if (cy < 5 && cx < 7) begin
                    bits = row_bits(ch, cy[2:0]);
                    glyph_on = bits[7 - cx]; // leftmost column is MSB
                end
            end
        end
    endfunction

    // 8-char string at (sx,sy); which=0 -> "Gr. Appx.", which=1 -> "Gr. Plt."
    function str8_on;
      input [6:0] sx, sy; input [6:0] px, py; input which;
      integer i; reg hit; reg [7:0] ch;
      begin
        hit = 1'b0;
        for (i=0; i<8; i=i+1) begin
          if (!which) begin
            // "Gr. Appx."
            case (i)
              0:ch="G"; 1:ch="r"; 2:ch="."; 3:ch=" ";
              4:ch="A"; 5:ch="p"; 6:ch="p"; 7:ch="x";
              default: ch=" ";
            endcase
          end else begin
            // "Gr. Plt."
            case (i)
              0:ch="G"; 1:ch="r"; 2:ch="."; 3:ch=" ";
              4:ch="P"; 5:ch="l"; 6:ch="t"; 7:ch=".";
              default: ch=" ";
            endcase
          end
          if (glyph_on(ch, px, py, sx + i*8, sy)) // 5px glyph + 3px gap
            hit = 1'b1;
        end
        str8_on = hit;
      end
    endfunction

    assign txt1_on = str8_on(str1_x, str1_y, px, py, 1'b0); // "Gr. Appx."
    assign txt2_on = str8_on(str2_x, str2_y, px, py, 1'b1); // "Gr. Plt."
endmodule

