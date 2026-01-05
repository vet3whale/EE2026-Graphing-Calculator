`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.10.2025 14:43:10
// Design Name: 
// Module Name: labels_lut
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

module labels_lut #(parameter integer MAXLEN = 16)(
    input clk, input  [6:0] px, py,          // current pixel
    input  [6:0] sx, sy,          // text origin (top-left of first glyph)
    input  [8*MAXLEN-1:0] text,   // packed ASCII, MSB-first
    output wire on                // pixel set output
);

    (* rom_style = "distributed", ram_style = "distributed" *)
    reg [4:0] FONT5x7 [0:128*7-1];

    integer j;
    initial begin
        for (j=0; j<128*7; j=j+1) FONT5x7[j] = 5'b00000;

        // Digits '0'..'9'
        FONT5x7[{7'd48,3'd0}] = 5'b11111; FONT5x7[{7'd48,3'd1}] = 5'b10001; FONT5x7[{7'd48,3'd2}] = 5'b10001;
        FONT5x7[{7'd48,3'd3}] = 5'b10001; FONT5x7[{7'd48,3'd4}] = 5'b10001; FONT5x7[{7'd48,3'd5}] = 5'b10001;
        FONT5x7[{7'd48,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd49,3'd0}] = 5'b00100; FONT5x7[{7'd49,3'd1}] = 5'b01100; FONT5x7[{7'd49,3'd2}] = 5'b00100;
        FONT5x7[{7'd49,3'd3}] = 5'b00100; FONT5x7[{7'd49,3'd4}] = 5'b00100; FONT5x7[{7'd49,3'd5}] = 5'b00100;
        FONT5x7[{7'd49,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd50,3'd0}] = 5'b11111; FONT5x7[{7'd50,3'd1}] = 5'b00001; FONT5x7[{7'd50,3'd2}] = 5'b00001;
        FONT5x7[{7'd50,3'd3}] = 5'b11111; FONT5x7[{7'd50,3'd4}] = 5'b10000; FONT5x7[{7'd50,3'd5}] = 5'b10000;
        FONT5x7[{7'd50,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd51,3'd0}] = 5'b11111; FONT5x7[{7'd51,3'd1}] = 5'b00001; FONT5x7[{7'd51,3'd2}] = 5'b00001;
        FONT5x7[{7'd51,3'd3}] = 5'b11111; FONT5x7[{7'd51,3'd4}] = 5'b00001; FONT5x7[{7'd51,3'd5}] = 5'b00001;
        FONT5x7[{7'd51,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd52,3'd0}] = 5'b10001; FONT5x7[{7'd52,3'd1}] = 5'b10001; FONT5x7[{7'd52,3'd2}] = 5'b10001;
        FONT5x7[{7'd52,3'd3}] = 5'b11111; FONT5x7[{7'd52,3'd4}] = 5'b00001; FONT5x7[{7'd52,3'd5}] = 5'b00001;
        FONT5x7[{7'd52,3'd6}] = 5'b00001;
        
        FONT5x7[{7'd53,3'd0}] = 5'b11111; FONT5x7[{7'd53,3'd1}] = 5'b10000; FONT5x7[{7'd53,3'd2}] = 5'b10000;
        FONT5x7[{7'd53,3'd3}] = 5'b11111; FONT5x7[{7'd53,3'd4}] = 5'b00001; FONT5x7[{7'd53,3'd5}] = 5'b00001;
        FONT5x7[{7'd53,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd54,3'd0}] = 5'b11111; FONT5x7[{7'd54,3'd1}] = 5'b10000; FONT5x7[{7'd54,3'd2}] = 5'b10000;
        FONT5x7[{7'd54,3'd3}] = 5'b11111; FONT5x7[{7'd54,3'd4}] = 5'b10001; FONT5x7[{7'd54,3'd5}] = 5'b10001;
        FONT5x7[{7'd54,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd55,3'd0}] = 5'b11111; FONT5x7[{7'd55,3'd1}] = 5'b00001; FONT5x7[{7'd55,3'd2}] = 5'b00010;
        FONT5x7[{7'd55,3'd3}] = 5'b00100; FONT5x7[{7'd55,3'd4}] = 5'b01000; FONT5x7[{7'd55,3'd5}] = 5'b10000;
        FONT5x7[{7'd55,3'd6}] = 5'b10000;
        
        FONT5x7[{7'd56,3'd0}] = 5'b11111; FONT5x7[{7'd56,3'd1}] = 5'b10001; FONT5x7[{7'd56,3'd2}] = 5'b10001;
        FONT5x7[{7'd56,3'd3}] = 5'b11111; FONT5x7[{7'd56,3'd4}] = 5'b10001; FONT5x7[{7'd56,3'd5}] = 5'b10001;
        FONT5x7[{7'd56,3'd6}] = 5'b11111;
        
        FONT5x7[{7'd57,3'd0}] = 5'b11111; FONT5x7[{7'd57,3'd1}] = 5'b10001; FONT5x7[{7'd57,3'd2}] = 5'b10001;
        FONT5x7[{7'd57,3'd3}] = 5'b11111; FONT5x7[{7'd57,3'd4}] = 5'b00001; FONT5x7[{7'd57,3'd5}] = 5'b00001;
        FONT5x7[{7'd57,3'd6}] = 5'b11111;
        
        //  E
        FONT5x7[{7'd69, 3'd0}] = 5'b11111;
        FONT5x7[{7'd69, 3'd1}] = 5'b10000;
        FONT5x7[{7'd69, 3'd2}] = 5'b11110;
        FONT5x7[{7'd69, 3'd3}] = 5'b10000;
        FONT5x7[{7'd69, 3'd4}] = 5'b10000;
        FONT5x7[{7'd69, 3'd5}] = 5'b11111;
        FONT5x7[{7'd69, 3'd6}] = 5'b00000;
        //  Q
        FONT5x7[{7'd81, 3'd0}] = 5'b01110;
        FONT5x7[{7'd81, 3'd1}] = 5'b10001;
        FONT5x7[{7'd81, 3'd2}] = 5'b10001;
        FONT5x7[{7'd81, 3'd3}] = 5'b10001;
        FONT5x7[{7'd81, 3'd4}] = 5'b10011;
        FONT5x7[{7'd81, 3'd5}] = 5'b01110;
        FONT5x7[{7'd81, 3'd6}] = 5'b00001;
        //  U
        FONT5x7[{7'd85, 3'd0}] = 5'b10001;
        FONT5x7[{7'd85, 3'd1}] = 5'b10001;
        FONT5x7[{7'd85, 3'd2}] = 5'b10001;
        FONT5x7[{7'd85, 3'd3}] = 5'b10001;
        FONT5x7[{7'd85, 3'd4}] = 5'b10001;
        FONT5x7[{7'd85, 3'd5}] = 5'b01110;
        FONT5x7[{7'd85, 3'd6}] = 5'b00000;
        //  A
        FONT5x7[{7'd65, 3'd0}] = 5'b01110;
        FONT5x7[{7'd65, 3'd1}] = 5'b10001;
        FONT5x7[{7'd65, 3'd2}] = 5'b10001;
        FONT5x7[{7'd65, 3'd3}] = 5'b11111;
        FONT5x7[{7'd65, 3'd4}] = 5'b10001;
        FONT5x7[{7'd65, 3'd5}] = 5'b10001;
        FONT5x7[{7'd65, 3'd6}] = 5'b00000;
        //  I
        FONT5x7[{7'd73, 3'd0}] = 5'b11111;
        FONT5x7[{7'd73, 3'd1}] = 5'b00100;
        FONT5x7[{7'd73, 3'd2}] = 5'b00100;
        FONT5x7[{7'd73, 3'd3}] = 5'b00100;
        FONT5x7[{7'd73, 3'd4}] = 5'b00100;
        FONT5x7[{7'd73, 3'd5}] = 5'b11111;
        FONT5x7[{7'd73, 3'd6}] = 5'b00000;
        //  O
        FONT5x7[{7'd79, 3'd0}] = 5'b01110;
        FONT5x7[{7'd79, 3'd1}] = 5'b10001;
        FONT5x7[{7'd79, 3'd2}] = 5'b10001;
        FONT5x7[{7'd79, 3'd3}] = 5'b10001;
        FONT5x7[{7'd79, 3'd4}] = 5'b10001;
        FONT5x7[{7'd79, 3'd5}] = 5'b01110;
        FONT5x7[{7'd79, 3'd6}] = 5'b00000;
        //  N
        FONT5x7[{7'd78, 3'd0}] = 5'b10001;
        FONT5x7[{7'd78, 3'd1}] = 5'b11001;
        FONT5x7[{7'd78, 3'd2}] = 5'b10101;
        FONT5x7[{7'd78, 3'd3}] = 5'b10011;
        FONT5x7[{7'd78, 3'd4}] = 5'b10001;
        FONT5x7[{7'd78, 3'd5}] = 5'b10001;
        FONT5x7[{7'd78, 3'd6}] = 5'b00000;
        //  G
        FONT5x7[{7'd71, 3'd0}] = 5'b01110;
        FONT5x7[{7'd71, 3'd1}] = 5'b10001;
        FONT5x7[{7'd71, 3'd2}] = 5'b10000;
        FONT5x7[{7'd71, 3'd3}] = 5'b10111;
        FONT5x7[{7'd71, 3'd4}] = 5'b10001;
        FONT5x7[{7'd71, 3'd5}] = 5'b01110;
        FONT5x7[{7'd71, 3'd6}] = 5'b00000;
        //  R
        FONT5x7[{7'd82, 3'd0}] = 5'b11110;
        FONT5x7[{7'd82, 3'd1}] = 5'b10001;
        FONT5x7[{7'd82, 3'd2}] = 5'b11110;
        FONT5x7[{7'd82, 3'd3}] = 5'b10100;
        FONT5x7[{7'd82, 3'd4}] = 5'b10010;
        FONT5x7[{7'd82, 3'd5}] = 5'b10001;
        FONT5x7[{7'd82, 3'd6}] = 5'b00000;
        //  P
        FONT5x7[{7'd80, 3'd0}] = 5'b11110;
        FONT5x7[{7'd80, 3'd1}] = 5'b10001;
        FONT5x7[{7'd80, 3'd2}] = 5'b11110;
        FONT5x7[{7'd80, 3'd3}] = 5'b10000;
        FONT5x7[{7'd80, 3'd4}] = 5'b10000;
        FONT5x7[{7'd80, 3'd5}] = 5'b10000;
        FONT5x7[{7'd80, 3'd6}] = 5'b00000;
        //  P
        FONT5x7[{7'd80, 3'd0}] = 5'b11110;
        FONT5x7[{7'd80, 3'd1}] = 5'b10001;
        FONT5x7[{7'd80, 3'd2}] = 5'b11110;
        FONT5x7[{7'd80, 3'd3}] = 5'b10000;
        FONT5x7[{7'd80, 3'd4}] = 5'b10000;
        FONT5x7[{7'd80, 3'd5}] = 5'b10000;
        FONT5x7[{7'd80, 3'd6}] = 5'b00000;
        //  X
        FONT5x7[{7'd88, 3'd0}] = 5'b10001;
        FONT5x7[{7'd88, 3'd1}] = 5'b10001;
        FONT5x7[{7'd88, 3'd2}] = 5'b01010;
        FONT5x7[{7'd88, 3'd3}] = 5'b00100;
        FONT5x7[{7'd88, 3'd4}] = 5'b01010;
        FONT5x7[{7'd88, 3'd5}] = 5'b10001;
        FONT5x7[{7'd88, 3'd6}] = 5'b00000;
        //  L
        FONT5x7[{7'd76, 3'd0}] = 5'b10000;
        FONT5x7[{7'd76, 3'd1}] = 5'b10000;
        FONT5x7[{7'd76, 3'd2}] = 5'b10000;
        FONT5x7[{7'd76, 3'd3}] = 5'b10000;
        FONT5x7[{7'd76, 3'd4}] = 5'b10000;
        FONT5x7[{7'd76, 3'd5}] = 5'b11111;
        FONT5x7[{7'd76, 3'd6}] = 5'b00000;
        //  T
        FONT5x7[{7'd84, 3'd0}] = 5'b11111;
        FONT5x7[{7'd84, 3'd1}] = 5'b00100;
        FONT5x7[{7'd84, 3'd2}] = 5'b00100;
        FONT5x7[{7'd84, 3'd3}] = 5'b00100;
        FONT5x7[{7'd84, 3'd4}] = 5'b00100;
        FONT5x7[{7'd84, 3'd5}] = 5'b00100;
        FONT5x7[{7'd84, 3'd6}] = 5'b00000;
        //  S
        FONT5x7[{7'd83, 3'd0}] = 5'b01110;
        FONT5x7[{7'd83, 3'd1}] = 5'b10001;
        FONT5x7[{7'd83, 3'd2}] = 5'b10000;
        FONT5x7[{7'd83, 3'd3}] = 5'b01110;
        FONT5x7[{7'd83, 3'd4}] = 5'b00001;
        FONT5x7[{7'd83, 3'd5}] = 5'b10001;
        FONT5x7[{7'd83, 3'd6}] = 5'b01110;
        // +
        FONT5x7[{7'd43, 3'd0}] = 5'b00000;
        FONT5x7[{7'd43, 3'd1}] = 5'b00100;
        FONT5x7[{7'd43, 3'd2}] = 5'b00100;
        FONT5x7[{7'd43, 3'd3}] = 5'b11111;
        FONT5x7[{7'd43, 3'd4}] = 5'b00100;
        FONT5x7[{7'd43, 3'd5}] = 5'b00100;
        FONT5x7[{7'd43, 3'd6}] = 5'b00000;
        
        // -
        FONT5x7[{7'd45, 3'd0}] = 5'b00000;
        FONT5x7[{7'd45, 3'd1}] = 5'b00000;
        FONT5x7[{7'd45, 3'd2}] = 5'b00000;
        FONT5x7[{7'd45, 3'd3}] = 5'b11111;
        FONT5x7[{7'd45, 3'd4}] = 5'b00000;
        FONT5x7[{7'd45, 3'd5}] = 5'b00000;
        FONT5x7[{7'd45, 3'd6}] = 5'b00000;
        // .
        FONT5x7[{7'd46, 3'd0}] = 5'b00000;
        FONT5x7[{7'd46, 3'd1}] = 5'b00000;
        FONT5x7[{7'd46, 3'd2}] = 5'b00000;
        FONT5x7[{7'd46, 3'd3}] = 5'b00000;
        FONT5x7[{7'd46, 3'd4}] = 5'b00000;
        FONT5x7[{7'd46, 3'd5}] = 5'b00000;
        FONT5x7[{7'd46, 3'd6}] = 5'b00100;
        // Character ':', ASCII 58 decimal (7'd58)
        FONT5x7[{7'd58, 3'd0}] = 5'b00000;
        FONT5x7[{7'd58, 3'd1}] = 5'b00100;
        FONT5x7[{7'd58, 3'd2}] = 5'b00100;
        FONT5x7[{7'd58, 3'd3}] = 5'b00000;
        FONT5x7[{7'd58, 3'd4}] = 5'b00100;
        FONT5x7[{7'd58, 3'd5}] = 5'b00100;
        FONT5x7[{7'd58, 3'd6}] = 5'b00000;
        
        // Character '(', ASCII 40 decimal (7'd40)
        FONT5x7[{7'd40, 3'd0}] = 5'b00010;
        FONT5x7[{7'd40, 3'd1}] = 5'b00100;
        FONT5x7[{7'd40, 3'd2}] = 5'b01000;
        FONT5x7[{7'd40, 3'd3}] = 5'b01000;
        FONT5x7[{7'd40, 3'd4}] = 5'b01000;
        FONT5x7[{7'd40, 3'd5}] = 5'b00100;
        FONT5x7[{7'd40, 3'd6}] = 5'b00010;
        
        // Character ')', ASCII 41 decimal (7'd41)
        FONT5x7[{7'd41, 3'd0}] = 5'b01000;
        FONT5x7[{7'd41, 3'd1}] = 5'b00100;
        FONT5x7[{7'd41, 3'd2}] = 5'b00010;
        FONT5x7[{7'd41, 3'd3}] = 5'b00010;
        FONT5x7[{7'd41, 3'd4}] = 5'b00010;
        FONT5x7[{7'd41, 3'd5}] = 5'b00100;
        FONT5x7[{7'd41, 3'd6}] = 5'b01000;

        
        // Character ',', ASCII 44 decimal (7'd44)
        FONT5x7[{7'd44, 3'd0}] = 5'b00000;
        FONT5x7[{7'd44, 3'd1}] = 5'b00000;
        FONT5x7[{7'd44, 3'd2}] = 5'b00000;
        FONT5x7[{7'd44, 3'd3}] = 5'b00000;
        FONT5x7[{7'd44, 3'd4}] = 5'b00100;
        FONT5x7[{7'd44, 3'd5}] = 5'b00100;
        FONT5x7[{7'd44, 3'd6}] = 5'b01000;
        
        // Character '-', ASCII 45 decimal (7'd45)
        FONT5x7[{7'd45, 3'd0}] = 5'b00000;
        FONT5x7[{7'd45, 3'd1}] = 5'b00000;
        FONT5x7[{7'd45, 3'd2}] = 5'b00000;
        FONT5x7[{7'd45, 3'd3}] = 5'b11111;
        FONT5x7[{7'd45, 3'd4}] = 5'b00000;
        FONT5x7[{7'd45, 3'd5}] = 5'b00000;
        FONT5x7[{7'd45, 3'd6}] = 5'b00000;
        
        // Character '>', ASCII 62 decimal (7'd62)
        FONT5x7[{7'd62, 3'd0}] = 5'b10000;
        FONT5x7[{7'd62, 3'd1}] = 5'b01000;
        FONT5x7[{7'd62, 3'd2}] = 5'b00100;
        FONT5x7[{7'd62, 3'd3}] = 5'b00010;
        FONT5x7[{7'd62, 3'd4}] = 5'b00100;
        FONT5x7[{7'd62, 3'd5}] = 5'b01000;
        FONT5x7[{7'd62, 3'd6}] = 5'b10000;
        
        // Character 'm', ASCII 109 decimal (7'd109)
        FONT5x7[{7'd109, 3'd0}] = 5'b00000;
        FONT5x7[{7'd109, 3'd1}] = 5'b00000;
        FONT5x7[{7'd109, 3'd2}] = 5'b11010;
        FONT5x7[{7'd109, 3'd3}] = 5'b10101;
        FONT5x7[{7'd109, 3'd4}] = 5'b10101;
        FONT5x7[{7'd109, 3'd5}] = 5'b10001;
        FONT5x7[{7'd109, 3'd6}] = 5'b00000;
        
        // Character 'c', ASCII 99 decimal (7'd99)
        FONT5x7[{7'd99, 3'd0}] = 5'b00000;
        FONT5x7[{7'd99, 3'd1}] = 5'b00000;
        FONT5x7[{7'd99, 3'd2}] = 5'b01110;
        FONT5x7[{7'd99, 3'd3}] = 5'b10000;
        FONT5x7[{7'd99, 3'd4}] = 5'b10000;
        FONT5x7[{7'd99, 3'd5}] = 5'b01110;
        FONT5x7[{7'd99, 3'd6}] = 5'b00000;
        
        // Character '=', ASCII 61 decimal (7'd61)
        FONT5x7[{7'd61, 3'd0}] = 5'b00000;
        FONT5x7[{7'd61, 3'd1}] = 5'b00000;
        FONT5x7[{7'd61, 3'd2}] = 5'b11111;
        FONT5x7[{7'd61, 3'd3}] = 5'b00000;
        FONT5x7[{7'd61, 3'd4}] = 5'b11111;
        FONT5x7[{7'd61, 3'd5}] = 5'b00000;
        FONT5x7[{7'd61, 3'd6}] = 5'b00000;
    end

    // font index helper
    function automatic [2:0] __map_col5;
        input signed [6:0] rx; input [6:0] dW;
        begin
            if (dW==7'd5) __map_col5 = rx[2:0];
            else begin
                if (rx < (dW*1)/5) __map_col5 = 0;
                else if (rx < (dW*2)/5) __map_col5 = 1;
                else if (rx < (dW*3)/5) __map_col5 = 2;
                else if (rx < (dW*4)/5) __map_col5 = 3;
                else __map_col5 = 4;
            end
        end
    endfunction

    function automatic [2:0] __map_row7;
        input signed [5:0] ry; input [5:0] dH;
        begin
            if (dH==6'd7) __map_row7 = ry[2:0];
            else begin
                if (ry < (dH*1)/7) __map_row7 = 0;
                else if (ry < (dH*2)/7) __map_row7 = 1;
                else if (ry < (dH*3)/7) __map_row7 = 2;
                else if (ry < (dH*4)/7) __map_row7 = 3;
                else if (ry < (dH*5)/7) __map_row7 = 4;
                else if (ry < (dH*6)/7) __map_row7 = 5;
                else __map_row7 = 6;
            end
        end
    endfunction

    // ===================== text unpack (constant bounded) ======================
    reg [7:0] text_bytes [0:MAXLEN-1];
    integer k;
    always @* begin
        for (k = 0; k < MAXLEN; k = k + 1) begin
            text_bytes[k] = text[8*(MAXLEN-1 - k) +: 8];
        end
    end

    // ===================== Main font lookup function ======================
    function draw_letter;
        input [7:0] ch; input signed [6:0] rx; input signed [5:0] ry;
        input [6:0] dW; input [5:0] dH;
        input superscript;
        reg [4:0] row_bits; reg [2:0] col5, row7;
        reg [6:0] c7; reg signed [5:0] ry_shifted;
        begin
            if (superscript) begin
                rx = rx + 8;
                ry_shifted = ry + 3;
            end else
                ry_shifted = ry;
            if (rx<0 || ry_shifted<0 || rx>=$signed(dW) || ry_shifted>=$signed(dH)) begin
                draw_letter = 1'b0;
            end else begin
                c7     = ch[6:0];
                row7   = __map_row7(ry_shifted, dH);
                col5   = __map_col5(rx, dW);
                row_bits = FONT5x7[{c7, row7}];
                draw_letter = row_bits[4 - col5];
            end
         end
    endfunction

    // ===================== Hit test: any glyph match sets pixel ======================
    reg hit;
    integer i;
    reg signed [6:0] rx;
    reg signed [5:0] ry;
    reg superscript;
    always @* begin
        hit = 1'b0;
        superscript = 1'b0;
        for (i = 0; i < MAXLEN; i = i + 1) begin
            // Compute pixel position in glyph box
            if (text_bytes[i] == "^") superscript = ~superscript;
            else begin 
                rx = px - (sx+1) - i*8; // 8 px between glyphs (adjust as needed)
                ry = py - (sy+1);
            end 
            if ((text_bytes[i] != "^") && draw_letter(text_bytes[i], rx, ry, 5, 7, superscript)) hit = 1'b1;
        end
    end
    assign on = hit;

endmodule

