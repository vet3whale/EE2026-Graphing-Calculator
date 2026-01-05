`timescale 1ns / 1ps

//FINAL OPTIMIZED VERSION - Coefficient Input UI (No Keypad)
//Key: Single font ROM + functions, BRAM buffers, optimized hex conversion

module ryanmodule(
  input  wire        CLOCK,           // 100 MHz
  input  wire        clk6p25m,        // 6.25 MHz pixel clock (provided externally)
  input  wire [12:0] pixel_index,     // Pixel index from OLED controller
  input  wire [11:0] mouse_x_pos,     // Mouse X position (12-bit)
  input  wire [11:0] mouse_y_pos,     // Mouse Y position (12-bit)
  input  wire        left,            // Left mouse button
  input  wire        right,           // Right mouse button (for reset/back)
  input  wire        enable,          // Enable signal from main menu
  output wire [15:0] oled_data_out    // OLED pixel data output
);

  // Convert mouse positions to 7-bit for internal use
  wire [11:0] mouse_x = mouse_x_pos;
  wire [11:0] mouse_y = mouse_y_pos;
  
  // =================================================
  // OPTIMIZED: SINGLE FONT ROM
  // =================================================
  (* rom_style = "distributed", ram_style = "distributed" *)
  reg [4:0] FONT_ROM [0:127*7-1];
  
  integer _i;
  initial begin
    for (_i=0; _i<128*7; _i=_i+1) FONT_ROM[_i] = 5'b00000;
    
    // Digits 0-9
    FONT_ROM[{"0",3'd0}]=5'b01110; FONT_ROM[{"0",3'd1}]=5'b10001; FONT_ROM[{"0",3'd2}]=5'b10001;
    FONT_ROM[{"0",3'd3}]=5'b10001; FONT_ROM[{"0",3'd4}]=5'b10001; FONT_ROM[{"0",3'd5}]=5'b10001;
    FONT_ROM[{"0",3'd6}]=5'b01110;
    
    FONT_ROM[{"1",3'd0}]=5'b00100; FONT_ROM[{"1",3'd1}]=5'b01100; FONT_ROM[{"1",3'd2}]=5'b00100;
    FONT_ROM[{"1",3'd3}]=5'b00100; FONT_ROM[{"1",3'd4}]=5'b00100; FONT_ROM[{"1",3'd5}]=5'b00100;
    FONT_ROM[{"1",3'd6}]=5'b01110;
    
    FONT_ROM[{"2",3'd0}]=5'b01110; FONT_ROM[{"2",3'd1}]=5'b10001; FONT_ROM[{"2",3'd2}]=5'b00001;
    FONT_ROM[{"2",3'd3}]=5'b00010; FONT_ROM[{"2",3'd4}]=5'b00100; FONT_ROM[{"2",3'd5}]=5'b01000;
    FONT_ROM[{"2",3'd6}]=5'b11111;
    
    FONT_ROM[{"3",3'd0}]=5'b11110; FONT_ROM[{"3",3'd1}]=5'b00001; FONT_ROM[{"3",3'd2}]=5'b00001;
    FONT_ROM[{"3",3'd3}]=5'b01110; FONT_ROM[{"3",3'd4}]=5'b00001; FONT_ROM[{"3",3'd5}]=5'b00001;
    FONT_ROM[{"3",3'd6}]=5'b11110;
    
    FONT_ROM[{"4",3'd0}]=5'b00010; FONT_ROM[{"4",3'd1}]=5'b00110; FONT_ROM[{"4",3'd2}]=5'b01010;
    FONT_ROM[{"4",3'd3}]=5'b10010; FONT_ROM[{"4",3'd4}]=5'b11111; FONT_ROM[{"4",3'd5}]=5'b00010;
    FONT_ROM[{"4",3'd6}]=5'b00010;
    
    FONT_ROM[{"5",3'd0}]=5'b11111; FONT_ROM[{"5",3'd1}]=5'b10000; FONT_ROM[{"5",3'd2}]=5'b10000;
    FONT_ROM[{"5",3'd3}]=5'b11110; FONT_ROM[{"5",3'd4}]=5'b00001; FONT_ROM[{"5",3'd5}]=5'b00001;
    FONT_ROM[{"5",3'd6}]=5'b01110;
    
    FONT_ROM[{"6",3'd0}]=5'b00110; FONT_ROM[{"6",3'd1}]=5'b01000; FONT_ROM[{"6",3'd2}]=5'b10000;
    FONT_ROM[{"6",3'd3}]=5'b11110; FONT_ROM[{"6",3'd4}]=5'b10001; FONT_ROM[{"6",3'd5}]=5'b10001;
    FONT_ROM[{"6",3'd6}]=5'b01110;
    
    FONT_ROM[{"7",3'd0}]=5'b11111; FONT_ROM[{"7",3'd1}]=5'b00001; FONT_ROM[{"7",3'd2}]=5'b00010;
    FONT_ROM[{"7",3'd3}]=5'b00100; FONT_ROM[{"7",3'd4}]=5'b01000; FONT_ROM[{"7",3'd5}]=5'b01000;
    FONT_ROM[{"7",3'd6}]=5'b01000;
    
    FONT_ROM[{"8",3'd0}]=5'b01110; FONT_ROM[{"8",3'd1}]=5'b10001; FONT_ROM[{"8",3'd2}]=5'b10001;
    FONT_ROM[{"8",3'd3}]=5'b01110; FONT_ROM[{"8",3'd4}]=5'b10001; FONT_ROM[{"8",3'd5}]=5'b10001;
    FONT_ROM[{"8",3'd6}]=5'b01110;
    
    FONT_ROM[{"9",3'd0}]=5'b01110; FONT_ROM[{"9",3'd1}]=5'b10001; FONT_ROM[{"9",3'd2}]=5'b10001;
    FONT_ROM[{"9",3'd3}]=5'b01111; FONT_ROM[{"9",3'd4}]=5'b00001; FONT_ROM[{"9",3'd5}]=5'b00010;
    FONT_ROM[{"9",3'd6}]=5'b11100;
    
    // Uppercase letters
    FONT_ROM[{"A",3'd0}]=5'b01110; FONT_ROM[{"A",3'd1}]=5'b10001; FONT_ROM[{"A",3'd2}]=5'b10001;
    FONT_ROM[{"A",3'd3}]=5'b11111; FONT_ROM[{"A",3'd4}]=5'b10001; FONT_ROM[{"A",3'd5}]=5'b10001;
    FONT_ROM[{"A",3'd6}]=5'b10001;
    
    FONT_ROM[{"B",3'd0}]=5'b11110; FONT_ROM[{"B",3'd1}]=5'b10001; FONT_ROM[{"B",3'd2}]=5'b10001;
    FONT_ROM[{"B",3'd3}]=5'b11110; FONT_ROM[{"B",3'd4}]=5'b10001; FONT_ROM[{"B",3'd5}]=5'b10001;
    FONT_ROM[{"B",3'd6}]=5'b11110;
    
    FONT_ROM[{"C",3'd0}]=5'b01110; FONT_ROM[{"C",3'd1}]=5'b10001; FONT_ROM[{"C",3'd2}]=5'b10000;
    FONT_ROM[{"C",3'd3}]=5'b10000; FONT_ROM[{"C",3'd4}]=5'b10000; FONT_ROM[{"C",3'd5}]=5'b10001;
    FONT_ROM[{"C",3'd6}]=5'b01110;
    
    FONT_ROM[{"D",3'd0}]=5'b11100; FONT_ROM[{"D",3'd1}]=5'b10010; FONT_ROM[{"D",3'd2}]=5'b10001;
    FONT_ROM[{"D",3'd3}]=5'b10001; FONT_ROM[{"D",3'd4}]=5'b10001; FONT_ROM[{"D",3'd5}]=5'b10010;
    FONT_ROM[{"D",3'd6}]=5'b11100;
    
    FONT_ROM[{"E",3'd0}]=5'b11111; FONT_ROM[{"E",3'd1}]=5'b10000; FONT_ROM[{"E",3'd2}]=5'b10000;
    FONT_ROM[{"E",3'd3}]=5'b11110; FONT_ROM[{"E",3'd4}]=5'b10000; FONT_ROM[{"E",3'd5}]=5'b10000;
    FONT_ROM[{"E",3'd6}]=5'b11111;
    
    FONT_ROM[{"F",3'd0}]=5'b11111; FONT_ROM[{"F",3'd1}]=5'b10000; FONT_ROM[{"F",3'd2}]=5'b10000;
    FONT_ROM[{"F",3'd3}]=5'b11110; FONT_ROM[{"F",3'd4}]=5'b10000; FONT_ROM[{"F",3'd5}]=5'b10000;
    FONT_ROM[{"F",3'd6}]=5'b10000;
    
    FONT_ROM[{"G",3'd0}]=5'b01110; FONT_ROM[{"G",3'd1}]=5'b10001; FONT_ROM[{"G",3'd2}]=5'b10000;
    FONT_ROM[{"G",3'd3}]=5'b10111; FONT_ROM[{"G",3'd4}]=5'b10001; FONT_ROM[{"G",3'd5}]=5'b10001;
    FONT_ROM[{"G",3'd6}]=5'b01110;
    
    FONT_ROM[{"M",3'd0}]=5'b10001; FONT_ROM[{"M",3'd1}]=5'b11011; FONT_ROM[{"M",3'd2}]=5'b10101;
    FONT_ROM[{"M",3'd3}]=5'b10101; FONT_ROM[{"M",3'd4}]=5'b10001; FONT_ROM[{"M",3'd5}]=5'b10001;
    FONT_ROM[{"M",3'd6}]=5'b10001;
    
    FONT_ROM[{"N",3'd0}]=5'b10001; FONT_ROM[{"N",3'd1}]=5'b11001; FONT_ROM[{"N",3'd2}]=5'b10101;
    FONT_ROM[{"N",3'd3}]=5'b10101; FONT_ROM[{"N",3'd4}]=5'b10011; FONT_ROM[{"N",3'd5}]=5'b10011;
    FONT_ROM[{"N",3'd6}]=5'b10001;
    
    FONT_ROM[{"O",3'd0}]=5'b01110; FONT_ROM[{"O",3'd1}]=5'b10001; FONT_ROM[{"O",3'd2}]=5'b10001;
    FONT_ROM[{"O",3'd3}]=5'b10001; FONT_ROM[{"O",3'd4}]=5'b10001; FONT_ROM[{"O",3'd5}]=5'b10001;
    FONT_ROM[{"O",3'd6}]=5'b01110;
    
    FONT_ROM[{"P",3'd0}]=5'b11110; FONT_ROM[{"P",3'd1}]=5'b10001; FONT_ROM[{"P",3'd2}]=5'b10001;
    FONT_ROM[{"P",3'd3}]=5'b11110; FONT_ROM[{"P",3'd4}]=5'b10000; FONT_ROM[{"P",3'd5}]=5'b10000;
    FONT_ROM[{"P",3'd6}]=5'b10000;
    
    FONT_ROM[{"R",3'd0}]=5'b11110; FONT_ROM[{"R",3'd1}]=5'b10001; FONT_ROM[{"R",3'd2}]=5'b10001;
    FONT_ROM[{"R",3'd3}]=5'b11110; FONT_ROM[{"R",3'd4}]=5'b10100; FONT_ROM[{"R",3'd5}]=5'b10010;
    FONT_ROM[{"R",3'd6}]=5'b10001;
    
    FONT_ROM[{"S",3'd0}]=5'b01111; FONT_ROM[{"S",3'd1}]=5'b10000; FONT_ROM[{"S",3'd2}]=5'b10000;
    FONT_ROM[{"S",3'd3}]=5'b01110; FONT_ROM[{"S",3'd4}]=5'b00001; FONT_ROM[{"S",3'd5}]=5'b00001;
    FONT_ROM[{"S",3'd6}]=5'b11110;
    
    FONT_ROM[{"T",3'd0}]=5'b11111; FONT_ROM[{"T",3'd1}]=5'b00100; FONT_ROM[{"T",3'd2}]=5'b00100;
    FONT_ROM[{"T",3'd3}]=5'b00100; FONT_ROM[{"T",3'd4}]=5'b00100; FONT_ROM[{"T",3'd5}]=5'b00100;
    FONT_ROM[{"T",3'd6}]=5'b00100;
    
    FONT_ROM[{"U",3'd0}]=5'b10001; FONT_ROM[{"U",3'd1}]=5'b10001; FONT_ROM[{"U",3'd2}]=5'b10001;
    FONT_ROM[{"U",3'd3}]=5'b10001; FONT_ROM[{"U",3'd4}]=5'b10001; FONT_ROM[{"U",3'd5}]=5'b10001;
    FONT_ROM[{"U",3'd6}]=5'b01110;
    
    FONT_ROM[{"V",3'd0}]=5'b10001; FONT_ROM[{"V",3'd1}]=5'b10001; FONT_ROM[{"V",3'd2}]=5'b10001;
    FONT_ROM[{"V",3'd3}]=5'b10001; FONT_ROM[{"V",3'd4}]=5'b10001; FONT_ROM[{"V",3'd5}]=5'b01010;
    FONT_ROM[{"V",3'd6}]=5'b00100;
    
    // Lowercase letters
    FONT_ROM[{"a",3'd0}]=5'b00000; FONT_ROM[{"a",3'd1}]=5'b00000; FONT_ROM[{"a",3'd2}]=5'b01110;
    FONT_ROM[{"a",3'd3}]=5'b00001; FONT_ROM[{"a",3'd4}]=5'b01111; FONT_ROM[{"a",3'd5}]=5'b10001;
    FONT_ROM[{"a",3'd6}]=5'b01111;
    
    FONT_ROM[{"d",3'd0}]=5'b00001; FONT_ROM[{"d",3'd1}]=5'b00001; FONT_ROM[{"d",3'd2}]=5'b01101;
    FONT_ROM[{"d",3'd3}]=5'b10011; FONT_ROM[{"d",3'd4}]=5'b10001; FONT_ROM[{"d",3'd5}]=5'b10001;
    FONT_ROM[{"d",3'd6}]=5'b01111;
    
    FONT_ROM[{"e",3'd0}]=5'b00000; FONT_ROM[{"e",3'd1}]=5'b00000; FONT_ROM[{"e",3'd2}]=5'b01110;
    FONT_ROM[{"e",3'd3}]=5'b10001; FONT_ROM[{"e",3'd4}]=5'b11111; FONT_ROM[{"e",3'd5}]=5'b10000;
    FONT_ROM[{"e",3'd6}]=5'b01110;
    
    FONT_ROM[{"g",3'd0}]=5'b00000; FONT_ROM[{"g",3'd1}]=5'b00000; FONT_ROM[{"g",3'd2}]=5'b01111;
    FONT_ROM[{"g",3'd3}]=5'b10001; FONT_ROM[{"g",3'd4}]=5'b10001; FONT_ROM[{"g",3'd5}]=5'b01111;
    FONT_ROM[{"g",3'd6}]=5'b00001;
    
    FONT_ROM[{"i",3'd0}]=5'b00100; FONT_ROM[{"i",3'd1}]=5'b00000; FONT_ROM[{"i",3'd2}]=5'b00100;
    FONT_ROM[{"i",3'd3}]=5'b00100; FONT_ROM[{"i",3'd4}]=5'b00100; FONT_ROM[{"i",3'd5}]=5'b00100;
    FONT_ROM[{"i",3'd6}]=5'b01110;
    
    FONT_ROM[{"l",3'd0}]=5'b00100; FONT_ROM[{"l",3'd1}]=5'b00100; FONT_ROM[{"l",3'd2}]=5'b00100;
    FONT_ROM[{"l",3'd3}]=5'b00100; FONT_ROM[{"l",3'd4}]=5'b00100; FONT_ROM[{"l",3'd5}]=5'b00100;
    FONT_ROM[{"l",3'd6}]=5'b00100;
    
    FONT_ROM[{"m",3'd0}]=5'b00000; FONT_ROM[{"m",3'd1}]=5'b00000; FONT_ROM[{"m",3'd2}]=5'b11010;
    FONT_ROM[{"m",3'd3}]=5'b10101; FONT_ROM[{"m",3'd4}]=5'b10101; FONT_ROM[{"m",3'd5}]=5'b10101;
    FONT_ROM[{"m",3'd6}]=5'b10101;
    
    FONT_ROM[{"n",3'd0}]=5'b00000; FONT_ROM[{"n",3'd1}]=5'b00000; FONT_ROM[{"n",3'd2}]=5'b10110;
    FONT_ROM[{"n",3'd3}]=5'b11001; FONT_ROM[{"n",3'd4}]=5'b10001; FONT_ROM[{"n",3'd5}]=5'b10001;
    FONT_ROM[{"n",3'd6}]=5'b10001;
    
    FONT_ROM[{"o",3'd0}]=5'b00000; FONT_ROM[{"o",3'd1}]=5'b00000; FONT_ROM[{"o",3'd2}]=5'b01110;
    FONT_ROM[{"o",3'd3}]=5'b10001; FONT_ROM[{"o",3'd4}]=5'b10001; FONT_ROM[{"o",3'd5}]=5'b10001;
    FONT_ROM[{"o",3'd6}]=5'b01110;
    
    FONT_ROM[{"r",3'd0}]=5'b00000; FONT_ROM[{"r",3'd1}]=5'b00000; FONT_ROM[{"r",3'd2}]=5'b10110;
    FONT_ROM[{"r",3'd3}]=5'b11001; FONT_ROM[{"r",3'd4}]=5'b10000; FONT_ROM[{"r",3'd5}]=5'b10000;
    FONT_ROM[{"r",3'd6}]=5'b10000;
    
    FONT_ROM[{"t",3'd0}]=5'b00100; FONT_ROM[{"t",3'd1}]=5'b00100; FONT_ROM[{"t",3'd2}]=5'b01110;
    FONT_ROM[{"t",3'd3}]=5'b00100; FONT_ROM[{"t",3'd4}]=5'b00100; FONT_ROM[{"t",3'd5}]=5'b00100;
    FONT_ROM[{"t",3'd6}]=5'b00010;
    
    FONT_ROM[{"x",3'd0}]=5'b00000; FONT_ROM[{"x",3'd1}]=5'b10001; FONT_ROM[{"x",3'd2}]=5'b01010;
    FONT_ROM[{"x",3'd3}]=5'b00100; FONT_ROM[{"x",3'd4}]=5'b01010; FONT_ROM[{"x",3'd5}]=5'b10001;
    FONT_ROM[{"x",3'd6}]=5'b00000;
    
    FONT_ROM[{"y",3'd0}]=5'b00000; FONT_ROM[{"y",3'd1}]=5'b10001; FONT_ROM[{"y",3'd2}]=5'b10001;
    FONT_ROM[{"y",3'd3}]=5'b01111; FONT_ROM[{"y",3'd4}]=5'b00001; FONT_ROM[{"y",3'd5}]=5'b00010;
    FONT_ROM[{"y",3'd6}]=5'b11100;
    
    // Symbols
    FONT_ROM[{" ",3'd0}]=5'b00000; FONT_ROM[{" ",3'd1}]=5'b00000; FONT_ROM[{" ",3'd2}]=5'b00000;
    FONT_ROM[{" ",3'd3}]=5'b00000; FONT_ROM[{" ",3'd4}]=5'b00000; FONT_ROM[{" ",3'd5}]=5'b00000;
    FONT_ROM[{" ",3'd6}]=5'b00000;
    
    FONT_ROM[{":",3'd0}]=5'b00000; FONT_ROM[{":",3'd1}]=5'b00100; FONT_ROM[{":",3'd2}]=5'b00000;
    FONT_ROM[{":",3'd3}]=5'b00000; FONT_ROM[{":",3'd4}]=5'b00000; FONT_ROM[{":",3'd5}]=5'b00100;
    FONT_ROM[{":",3'd6}]=5'b00000;
    
    FONT_ROM[{"+",3'd0}]=5'b00000; FONT_ROM[{"+",3'd1}]=5'b00100; FONT_ROM[{"+",3'd2}]=5'b00100;
    FONT_ROM[{"+",3'd3}]=5'b11111; FONT_ROM[{"+",3'd4}]=5'b00100; FONT_ROM[{"+",3'd5}]=5'b00100;
    FONT_ROM[{"+",3'd6}]=5'b00000;
    
    FONT_ROM[{"-",3'd0}]=5'b00000; FONT_ROM[{"-",3'd1}]=5'b00000; FONT_ROM[{"-",3'd2}]=5'b00000;
    FONT_ROM[{"-",3'd3}]=5'b11111; FONT_ROM[{"-",3'd4}]=5'b00000; FONT_ROM[{"-",3'd5}]=5'b00000;
    FONT_ROM[{"-",3'd6}]=5'b00000;
    
    FONT_ROM[{"=",3'd0}]=5'b00000; FONT_ROM[{"=",3'd1}]=5'b00000; FONT_ROM[{"=",3'd2}]=5'b11111;
    FONT_ROM[{"=",3'd3}]=5'b00000; FONT_ROM[{"=",3'd4}]=5'b11111; FONT_ROM[{"=",3'd5}]=5'b00000;
    FONT_ROM[{"=",3'd6}]=5'b00000;
    
    FONT_ROM[{"^",3'd0}]=5'b00100; FONT_ROM[{"^",3'd1}]=5'b01010; FONT_ROM[{"^",3'd2}]=5'b10001;
    FONT_ROM[{"^",3'd3}]=5'b00000; FONT_ROM[{"^",3'd4}]=5'b00000; FONT_ROM[{"^",3'd5}]=5'b00000;
    FONT_ROM[{"^",3'd6}]=5'b00000;
    
    FONT_ROM[{"/",3'd0}]=5'b00001; FONT_ROM[{"/",3'd1}]=5'b00010; FONT_ROM[{"/",3'd2}]=5'b00100;
    FONT_ROM[{"/",3'd3}]=5'b01000; FONT_ROM[{"/",3'd4}]=5'b10000; FONT_ROM[{"/",3'd5}]=5'b00000;
    FONT_ROM[{"/",3'd6}]=5'b00000;
    
    FONT_ROM[{"*",3'd0}]=5'b00000; FONT_ROM[{"*",3'd1}]=5'b00100; FONT_ROM[{"*",3'd2}]=5'b10101;
    FONT_ROM[{"*",3'd3}]=5'b01110; FONT_ROM[{"*",3'd4}]=5'b10101; FONT_ROM[{"*",3'd5}]=5'b00100;
    FONT_ROM[{"*",3'd6}]=5'b00000;
    
    FONT_ROM[{".",3'd0}]=5'b00000; FONT_ROM[{".",3'd1}]=5'b00000; FONT_ROM[{".",3'd2}]=5'b00000;
    FONT_ROM[{".",3'd3}]=5'b00000; FONT_ROM[{".",3'd4}]=5'b00000; FONT_ROM[{".",3'd5}]=5'b00100;
    FONT_ROM[{".",3'd6}]=5'b00100;
    
    FONT_ROM[{"(",3'd0}]=5'b00010; FONT_ROM[{"(",3'd1}]=5'b00100; FONT_ROM[{"(",3'd2}]=5'b01000;
    FONT_ROM[{"(",3'd3}]=5'b01000; FONT_ROM[{"(",3'd4}]=5'b01000; FONT_ROM[{"(",3'd5}]=5'b00100;
    FONT_ROM[{"(",3'd6}]=5'b00010;
    
    FONT_ROM[{")",3'd0}]=5'b01000; FONT_ROM[{")",3'd1}]=5'b00100; FONT_ROM[{")",3'd2}]=5'b00010;
    FONT_ROM[{")",3'd3}]=5'b00010; FONT_ROM[{")",3'd4}]=5'b00010; FONT_ROM[{")",3'd5}]=5'b00100;
    FONT_ROM[{")",3'd6}]=5'b01000;
    
    FONT_ROM[{"!",3'd0}]=5'b00100; FONT_ROM[{"!",3'd1}]=5'b00100; FONT_ROM[{"!",3'd2}]=5'b00100;
    FONT_ROM[{"!",3'd3}]=5'b00100; FONT_ROM[{"!",3'd4}]=5'b00000; FONT_ROM[{"!",3'd5}]=5'b00100;
    FONT_ROM[{"!",3'd6}]=5'b00000;
  end
  
  // =================================================
  // SINGLE DRAW_FONT FUNCTION
  // =================================================
  function draw_font;
    input [7:0] ch; input [2:0] gx; input [2:0] gy;
    reg [4:0] row_bits;
  begin
    row_bits = FONT_ROM[{ch[6:0], gy}];
    draw_font = (gx < 5) && (gy < 7) && row_bits[4 - gx];
  end
  endfunction
  
  // =================================================
  // HEX CONVERTER FUNCTION
  // =================================================
  function [7:0] nib2hex; input [3:0] n; begin
    case (n)
      4'h0: nib2hex="0"; 4'h1: nib2hex="1"; 4'h2: nib2hex="2"; 4'h3: nib2hex="3";
      4'h4: nib2hex="4"; 4'h5: nib2hex="5"; 4'h6: nib2hex="6"; 4'h7: nib2hex="7";
      4'h8: nib2hex="8"; 4'h9: nib2hex="9"; 4'hA: nib2hex="A"; 4'hB: nib2hex="B";
      4'hC: nib2hex="C"; 4'hD: nib2hex="D"; 4'hE: nib2hex="E"; 4'hF: nib2hex="F";
    endcase
  end endfunction
  
  // =======================
  // App state
  // =======================
  localparam APP_SPLASH = 2'd0;
  localparam APP_POLY   = 2'd1;
  localparam APP_ARGAND = 2'd2;
  localparam APP_GRAPH  = 2'd3;
  
  reg [1:0] app_state = APP_SPLASH;
  
  localparam BTN_W  = 80;
  localparam BTN_H  = 18;
  localparam BTN1_X = (96-BTN_W)/2;
  localparam BTN1_Y = 16;
  localparam BTN2_X = (96-BTN_W)/2;
  localparam BTN2_Y = 16 + BTN_H + 10;
  
  wire hover_btn1 = (mouse_x[6:0] >= BTN1_X) && (mouse_x[6:0] < BTN1_X+BTN_W) &&
                    (mouse_y[6:0] >= BTN1_Y) && (mouse_y[6:0] < BTN1_Y+BTN_H);
  wire hover_btn2 = (mouse_x[6:0] >= BTN2_X) && (mouse_x[6:0] < BTN2_X+BTN_W) &&
                    (mouse_y[6:0] >= BTN2_Y) && (mouse_y[6:0] < BTN2_Y+BTN_H);

  // =======================
  // Pixel coords from pixel_index
  // =======================
  reg [6:0] px_x = 0, px_y = 0;
  always @(posedge clk6p25m) begin
    px_x <= pixel_index % 96;
    px_y <= pixel_index / 96;
  end

  wire click_edge, right_edge;
  mouse_click_edge u_click (.clk(CLOCK), .rst(1'b0), .btn_in(left), .rising_edge(click_edge));
  mouse_click_edge u_click_r (.clk(CLOCK), .rst(1'b0), .btn_in(right), .rising_edge(right_edge));

  wire        cur_on;
  wire [15:0] pix_cur;
  cursor_crosshair u_cur (
    .x(px_x), .y(px_y), .cx(mouse_x[6:0]), .cy(mouse_y[6:0]),
    .on(cur_on), .pix(pix_cur)
  );
  
  // =============================
  // Splash renderer
  // =============================
  wire in_btn1 = (px_x >= BTN1_X) && (px_x < BTN1_X+BTN_W) &&
                 (px_y >= BTN1_Y) && (px_y < BTN1_Y+BTN_H);
  wire in_btn2 = (px_x >= BTN2_X) && (px_x < BTN2_X+BTN_W) &&
                 (px_y >= BTN2_Y) && (px_y < BTN2_Y+BTN_H);
  
  wire on_border_btn1 = in_btn1 && ((px_x==BTN1_X) || (px_x==BTN1_X+BTN_W-1) || 
                                     (px_y==BTN1_Y) || (px_y==BTN1_Y+BTN_H-1));
  wire on_border_btn2 = in_btn2 && ((px_x==BTN2_X) || (px_x==BTN2_X+BTN_W-1) || 
                                     (px_y==BTN2_Y) || (px_y==BTN2_Y+BTN_H-1));
  
  localparam [6:0] L1_X = BTN1_X + 3;
  localparam [6:0] L1_Y = BTN1_Y + 5;
  localparam [6:0] L2_X = BTN2_X + 8;
  localparam [6:0] L2_Y = BTN2_Y + 5;
  
  reg [7:0] str_poly [0:14];
  reg [7:0] str_argand [0:10];
  initial begin
    str_poly[0]="P"; str_poly[1]="o"; str_poly[2]="l"; str_poly[3]="y"; str_poly[4]="n";
    str_poly[5]="o"; str_poly[6]="m"; str_poly[7]="i"; str_poly[8]="a"; str_poly[9]="l";
    str_poly[10]=" "; str_poly[11]="M"; str_poly[12]="o"; str_poly[13]="d"; str_poly[14]="e";
    
    str_argand[0]="A"; str_argand[1]="r"; str_argand[2]="g"; str_argand[3]="a"; str_argand[4]="n";
    str_argand[5]="d"; str_argand[6]=" "; str_argand[7]="M"; str_argand[8]="o";
    str_argand[9]="d"; str_argand[10]="e";
  end
  
  reg splash_label_on;
  reg [6:0] lbl_ci;
  reg [7:0] lbl_ch;
  always @* begin
    splash_label_on = 1'b0;
    lbl_ch = " ";
    
    if ((px_y >= L1_Y) && (px_y < L1_Y+7) && (px_x >= L1_X) && (px_x < L1_X+75)) begin
      lbl_ci = (px_x - L1_X) / 5;
      if (lbl_ci < 15) begin
        lbl_ch = str_poly[lbl_ci];
        splash_label_on = draw_font(lbl_ch, (px_x - L1_X) % 5, px_y - L1_Y);
      end
    end else if ((px_y >= L2_Y) && (px_y < L2_Y+7) && (px_x >= L2_X) && (px_x < L2_X+55)) begin
      lbl_ci = (px_x - L2_X) / 5;
      if (lbl_ci < 11) begin
        lbl_ch = str_argand[lbl_ci];
        splash_label_on = draw_font(lbl_ch, (px_x - L2_X) % 5, px_y - L2_Y);
      end
    end
  end

  reg        splash_pix_on;
  reg [15:0] splash_rgb;
  always @* begin
    splash_pix_on = 1'b0;
    splash_rgb    = 16'h0000;

    if (app_state == APP_SPLASH) begin
      if ((px_x[0]^px_y[0]) && px_y>2 && px_y<62) begin
        splash_pix_on = 1'b1; splash_rgb = 16'h0841;
      end

      if (in_btn1) begin
        splash_pix_on = 1'b1;
        splash_rgb = hover_btn1 ? 16'h4A9F : 16'h39E7;
        if (on_border_btn1) splash_rgb = 16'hFFFF;
      end
      
      if (in_btn2) begin
        splash_pix_on = 1'b1;
        splash_rgb = hover_btn2 ? 16'h4A9F : 16'h39E7;
        if (on_border_btn2) splash_rgb = 16'hFFFF;
      end

      if (splash_label_on) begin
        splash_pix_on = 1'b1; 
        splash_rgb = 16'h0000;
      end
    end
  end

  wire splash_on  = (app_state==APP_SPLASH) && splash_pix_on;
  wire [15:0] pix_splash = splash_rgb;
  
  wire argand_on = (app_state==APP_ARGAND);

  // =============================
  // POLYNOMIAL INPUT (new UI similar to Argand)
  // =============================
  localparam POLY_Y = 32;
  
  // Arrow vertical placement parameters
  localparam integer ARW_UP_T0 = POLY_Y - 20; // top row of UP arrow
  localparam integer ARW_UP_T1 = POLY_Y - 19;
  localparam integer ARW_UP_T2 = POLY_Y - 18; // bottom row of UP arrow
  
  localparam integer ARW_DN_T0 = POLY_Y + 10; // top row of DOWN arrow
  localparam integer ARW_DN_T1 = POLY_Y + 11;
  localparam integer ARW_DN_T2 = POLY_Y + 12; // bottom row of DOWN arrow
  
  // Arrow positions aligned with coefficient display in equation
  // Equation shows: " -01x^2 + 00x + 00"
  //    Sign+Digits:   6-21    44-54   67-77
  //    Arrow center:   13      46      69
  localparam COEF_A_X = 13;  // Center of first coefficient digits
  localparam COEF_B_X = 46;  // Center of second coefficient digits
  localparam COEF_C_X = 69;  // Center of third coefficient digits
  
  localparam ENTER_X = 70;
  localparam ENTER_Y = 50;
  localparam ENTER_W = 26;
  localparam ENTER_H = 16;
  
  reg signed [5:0] coef_a = 6'sd1;  // Range -31 to 31
  reg signed [5:0] coef_b = 6'sd0;
  reg signed [5:0] coef_c = 6'sd0;
  
  localparam signed [5:0] COEF_MIN = -6'sd31;
  localparam signed [5:0] COEF_MAX =  6'sd31;
  
  wire hit_a_up   = (mouse_x[6:0] >= COEF_A_X-4) && (mouse_x[6:0] < COEF_A_X+12) &&
                    (mouse_y[6:0] >= POLY_Y-24) && (mouse_y[6:0] < POLY_Y-16);
  wire hit_a_down = (mouse_x[6:0] >= COEF_A_X-4) && (mouse_x[6:0] < COEF_A_X+12) &&
                    (mouse_y[6:0] >= POLY_Y+4) && (mouse_y[6:0] < POLY_Y+12);
  wire hit_b_up   = (mouse_x[6:0] >= COEF_B_X-4) && (mouse_x[6:0] < COEF_B_X+12) &&
                    (mouse_y[6:0] >= POLY_Y-24) && (mouse_y[6:0] < POLY_Y-16);
  wire hit_b_down = (mouse_x[6:0] >= COEF_B_X-4) && (mouse_x[6:0] < COEF_B_X+12) &&
                    (mouse_y[6:0] >= POLY_Y+4) && (mouse_y[6:0] < POLY_Y+12);
  wire hit_c_up   = (mouse_x[6:0] >= COEF_C_X-4) && (mouse_x[6:0] < COEF_C_X+12) &&
                    (mouse_y[6:0] >= POLY_Y-24) && (mouse_y[6:0] < POLY_Y-16);
  wire hit_c_down = (mouse_x[6:0] >= COEF_C_X-4) && (mouse_x[6:0] < COEF_C_X+12) &&
                    (mouse_y[6:0] >= POLY_Y+4) && (mouse_y[6:0] < POLY_Y+12);
  
  wire hit_enter = (mouse_x[6:0] >= ENTER_X) && (mouse_x[6:0] < ENTER_X+ENTER_W) &&
                   (mouse_y[6:0] >= ENTER_Y) && (mouse_y[6:0] < ENTER_Y+ENTER_H);

  // =============================
  // BRAM buffers (for parser compatibility)
  // =============================
  localparam integer MAXLEN = 48;
  (* ram_style = "block" *) reg [7:0] eq1 [0:MAXLEN-1];
  reg [5:0] eq1_len = 0;

  integer i;
  reg ui_state = 1'b0;  // 0 = input mode, 1 = results mode
  reg e1_req = 1'b0;
  
  reg signed [5:0] saved_coef_a = 6'sd0;
  reg signed [5:0] saved_coef_b = 6'sd0;
  reg signed [5:0] saved_coef_c = 6'sd0;
  
  reg signed [4:0] argand_real = 5'sd0;
  reg signed [4:0] argand_imag = 5'sd0;
  reg signed [4:0] saved_argand_real = 5'sd0;
  reg signed [4:0] saved_argand_imag = 5'sd0;
  localparam signed [4:0] ARG_MIN = -5'sd9;
  localparam signed [4:0] ARG_MAX =  5'sd9;

  // Click handler
  always @(posedge CLOCK) begin
    if (right_edge) begin
      app_state <= APP_SPLASH;
      ui_state  <= 1'b0;
    end
    else if (app_state == APP_SPLASH) begin
      if (click_edge && enable) begin  // Only respond when enabled
        if (hover_btn1) begin app_state <= APP_POLY; ui_state <= 1'b0; end
        else if (hover_btn2) begin app_state <= APP_ARGAND; end
      end
    end
    else if (app_state == APP_POLY) begin
      if (click_edge && enable) begin
        if (hit_a_up   && coef_a < COEF_MAX) coef_a <= coef_a + 6'sd1;
        else if (hit_a_down && coef_a > COEF_MIN) coef_a <= coef_a - 6'sd1;
        else if (hit_b_up   && coef_b < COEF_MAX) coef_b <= coef_b + 6'sd1;
        else if (hit_b_down && coef_b > COEF_MIN) coef_b <= coef_b - 6'sd1;
        else if (hit_c_up   && coef_c < COEF_MAX) coef_c <= coef_c + 6'sd1;
        else if (hit_c_down && coef_c > COEF_MIN) coef_c <= coef_c - 6'sd1;
        else if (hit_enter) begin
          saved_coef_a <= coef_a;
          saved_coef_b <= coef_b;
          saved_coef_c <= coef_c;
          ui_state <= 1'b1;
          e1_req   <= ~e1_req;
        end
      end
    end
    else if (app_state == APP_ARGAND) begin
      if (click_edge && enable) begin
        if (hit_a_up   && argand_real < ARG_MAX) argand_real <= argand_real + 5'sd1;
        else if (hit_a_down && argand_real > ARG_MIN) argand_real <= argand_real - 5'sd1;
        else if (hit_b_up   && argand_imag < ARG_MAX) argand_imag <= argand_imag + 5'sd1;
        else if (hit_b_down && argand_imag > ARG_MIN) argand_imag <= argand_imag - 5'sd1;
        else if (hit_enter) begin
          saved_argand_real <= argand_real;
          saved_argand_imag <= argand_imag;
          app_state <= APP_GRAPH;
        end
      end
    end
  end

  // ===================================================================
  // PARSER + ROOTS
  // ===================================================================
 /* wire signed [31:0] a1,b1,c1;
  wire [1:0]         degree_eq1;
  wire p1_done;
  reg  p1_start = 1'b0;
  reg  ready1   = 1'b0;
  wire [5:0] p1_addr;
  wire [7:0] p1_din = (p1_addr < eq1_len) ? eq1[p1_addr] : 8'h00;

  parse_ax2_bx_c #(.MAXLEN(MAXLEN)) P1 (
    .clk(CLOCK), .rst(1'b0), .start(p1_start),
    .len(eq1_len), .addr(p1_addr), .din(p1_din),
    .a(a1), .b(b1), .c(c1), .degree(degree_eq1), .done(p1_done)
  );

  reg e1_req_q = 1'b0;
  always @(posedge CLOCK) begin
    p1_start <= 1'b0;
    e1_req_q <= e1_req;
    if (e1_req ^ e1_req_q) begin 
      p1_start <= 1'b1; 
      ready1 <= 1'b0;
    end
    if (p1_done) ready1 <= 1'b1;
  end
  */
  // Use saved coefficients directly instead of parsing
  wire signed [31:0] a1_direct = {{26{saved_coef_a[5]}}, saved_coef_a};
  wire signed [31:0] b1_direct = {{26{saved_coef_b[5]}}, saved_coef_b};
  wire signed [31:0] c1_direct = {{26{saved_coef_c[5]}}, saved_coef_c};

  wire signed [63:0] D1 = (b1_direct*b1_direct) - (4*$signed(a1_direct)*$signed(c1_direct));
  wire [31:0] D1_abs_u = D1[63] ? (~D1[31:0] + 32'd1) : D1[31:0];
  wire [15:0] sqrtD1;
  int_sqrt32 u_sq1(.x(D1_abs_u), .y(sqrtD1));

  wire signed [31:0] r1_1 = (a1_direct!=0 && D1>=0) ? ($signed(-b1_direct) + $signed(sqrtD1)) / (2*$signed(a1_direct)) : 32'sd0;
  wire signed [31:0] r2_1 = (a1_direct!=0 && D1>=0) ? ($signed(-b1_direct) - $signed(sqrtD1)) / (2*$signed(a1_direct)) : 32'sd0;
  
  wire lin_has_root1        = ui_state && (a1_direct==0 && b1_direct!=0);
  wire signed [31:0] lin1   = (lin_has_root1) ? (-c1_direct)/b1_direct : 32'sd0;
  wire quad_real1           = ui_state && (a1_direct!=0) && (D1>=0);
  wire quad_imag1 = ui_state && (a1_direct!=0) && (D1<0);
  
  wire signed [31:0] denom2    = $signed(a1_direct) <<< 1;
  wire        [31:0] denom2_abs= denom2[31] ? (~denom2 + 32'd1) : denom2;
  wire signed [31:0] real_part = (a1_direct!=0) ? ($signed(-b1_direct) / denom2) : 32'sd0;
  wire        [31:0] imag_mag  = (a1_direct!=0 && denom2_abs!=0) ? ( {16'd0, sqrtD1} / denom2_abs ) : 32'd0;

  wire [15:0] r1_1h = r1_1[15:0], r2_1h = r2_1[15:0], lin1h = lin1[15:0];
  wire r1_1_neg = r1_1[31], r2_1_neg = r2_1[31], lin1_neg = lin1[31];
  wire [15:0] r1_1_abs = r1_1_neg ? (~r1_1h + 16'h1) : r1_1h;
  wire [15:0] r2_1_abs = r2_1_neg ? (~r2_1h + 16'h1) : r2_1h;
  wire [15:0] lin1_abs = lin1_neg ? (~lin1h + 16'h1) : lin1h;
  wire        real_neg     = real_part[31];
  wire [31:0] real_abs32   = real_neg ? (~real_part + 32'd1) : real_part;
  wire [31:0] imag_abs32   = imag_mag;
  wire [15:0] real_abs16   = real_abs32[15:0];
  wire [15:0] imag_abs16   = imag_abs32[15:0];
  
  wire [1:0] degree_calc = (a1_direct != 0) ? 2'd2 : (b1_direct != 0) ? 2'd1 : 2'd0;

  // ===================================================================
  // POLYNOMIAL INPUT UI RENDERING
  // ===================================================================
  wire in_a_up_btn   = (px_x >= COEF_A_X-4) && (px_x < COEF_A_X+12) && (px_y >= POLY_Y-24) && (px_y < POLY_Y-16);
  wire in_a_down_btn = (px_x >= COEF_A_X-4) && (px_x < COEF_A_X+12) && (px_y >= POLY_Y+8) && (px_y < POLY_Y+16);
  wire in_b_up_btn   = (px_x >= COEF_B_X-4) && (px_x < COEF_B_X+12) && (px_y >= POLY_Y-24) && (px_y < POLY_Y-16);
  wire in_b_down_btn = (px_x >= COEF_B_X-4) && (px_x < COEF_B_X+12) && (px_y >= POLY_Y+8) && (px_y < POLY_Y+16);
  wire in_c_up_btn   = (px_x >= COEF_C_X-4) && (px_x < COEF_C_X+12) && (px_y >= POLY_Y-24) && (px_y < POLY_Y-16);
  wire in_c_down_btn = (px_x >= COEF_C_X-4) && (px_x < COEF_C_X+12) && (px_y >= POLY_Y+8) && (px_y < POLY_Y+16);
  wire in_enter_btn = (px_x >= ENTER_X) && (px_x < ENTER_X+ENTER_W) && (px_y >= ENTER_Y) && (px_y < ENTER_Y+ENTER_H);
  wire on_enter_border = in_enter_btn && ((px_x == ENTER_X) || (px_x == ENTER_X+ENTER_W-1) ||
                         (px_y == ENTER_Y) || (px_y == ENTER_Y+ENTER_H-1));

  wire is_arrow_pixel = 
    (in_a_up_btn && px_y == ARW_UP_T2 && px_x >= COEF_A_X && px_x < COEF_A_X+8) ||
    (in_a_up_btn && px_y == ARW_UP_T1 && px_x >= COEF_A_X+2 && px_x < COEF_A_X+6) ||
    (in_a_up_btn && px_y == ARW_UP_T0 && px_x >= COEF_A_X+3 && px_x < COEF_A_X+5) ||
    (in_a_down_btn && px_y == ARW_DN_T0 && px_x >= COEF_A_X && px_x < COEF_A_X+8) ||
    (in_a_down_btn && px_y == ARW_DN_T1 && px_x >= COEF_A_X+2 && px_x < COEF_A_X+6) ||
    (in_a_down_btn && px_y == ARW_DN_T2 && px_x >= COEF_A_X+3 && px_x < COEF_A_X+5) ||
    (in_b_up_btn && px_y == ARW_UP_T2 && px_x >= COEF_B_X && px_x < COEF_B_X+8) ||
    (in_b_up_btn && px_y == ARW_UP_T1 && px_x >= COEF_B_X+2 && px_x < COEF_B_X+6) ||
    (in_b_up_btn && px_y == ARW_UP_T0 && px_x >= COEF_B_X+3 && px_x < COEF_B_X+5) ||
    (in_b_down_btn && px_y == ARW_DN_T0 && px_x >= COEF_B_X && px_x < COEF_B_X+8) ||
    (in_b_down_btn && px_y == ARW_DN_T1 && px_x >= COEF_B_X+2 && px_x < COEF_B_X+6) ||
    (in_b_down_btn && px_y == ARW_DN_T2 && px_x >= COEF_B_X+3 && px_x < COEF_B_X+5) ||
    (in_c_up_btn && px_y == ARW_UP_T2 && px_x >= COEF_C_X && px_x < COEF_C_X+8) ||
    (in_c_up_btn && px_y == ARW_UP_T1 && px_x >= COEF_C_X+2 && px_x < COEF_C_X+6) ||
    (in_c_up_btn && px_y == ARW_UP_T0 && px_x >= COEF_C_X+3 && px_x < COEF_C_X+5) ||
    (in_c_down_btn && px_y == ARW_DN_T0 && px_x >= COEF_C_X && px_x < COEF_C_X+8) ||
    (in_c_down_btn && px_y == ARW_DN_T1 && px_x >= COEF_C_X+2 && px_x < COEF_C_X+6) ||
    (in_c_down_btn && px_y == ARW_DN_T2 && px_x >= COEF_C_X+3 && px_x < COEF_C_X+5) ||
    on_enter_border;
  
  wire [5:0] a_abs = coef_a[5] ? -coef_a : coef_a;
  wire [5:0] b_abs = coef_b[5] ? -coef_b : coef_b;
  wire [5:0] c_abs = coef_c[5] ? -coef_c : coef_c;
  
  reg poly_text_on;
  reg [7:0] poly_ch;
  reg [6:0] poly_rel_x;
  reg [5:0] poly_rel_y;
  
  always @* begin
    poly_text_on = 1'b0;
    poly_ch = " ";
    poly_rel_x = 0;
    poly_rel_y = 0;
    
    if (app_state == APP_POLY && ui_state == 1'b0) begin
      // Display equation: _x^2 + _x + _ (with better spacing)
      // Line at Y=20 (above coefficients) - moved up for more space
      if ((px_y >= 20) && (px_y < 27)) begin
        poly_rel_y = px_y - 20;
        
        // Coefficient a with sign (starting at x=6)
        if ((px_x >= 6) && (px_x < 11)) begin
          poly_ch = (coef_a < 0) ? "-" : " "; poly_rel_x = px_x - 6;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end else if (px_x >= 11 && px_x < 16) begin
          poly_ch = "0" + (a_abs / 10); poly_rel_x = px_x - 11;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end else if (px_x >= 16 && px_x < 21) begin
          poly_ch = "0" + (a_abs % 10); poly_rel_x = px_x - 16;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end
        // "x"
        else if (px_x >= 21 && px_x < 26) begin
          poly_ch = "x"; poly_rel_x = px_x - 21;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // "^"
        else if (px_x >= 26 && px_x < 31) begin
          poly_ch = "^"; poly_rel_x = px_x - 26;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // "2"
        else if (px_x >= 31 && px_x < 36) begin
          poly_ch = "2"; poly_rel_x = px_x - 31;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end
        
        // "+" or "-" for b coefficient
        else if (px_x >= 38 && px_x < 43) begin
          poly_ch = (coef_b >= 0) ? "+" : "-"; poly_rel_x = px_x - 38;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // b coefficient tens digit
        else if (px_x >= 44 && px_x < 49) begin
          poly_ch = "0" + (b_abs / 10); poly_rel_x = px_x - 44;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // b coefficient ones digit
        else if (px_x >= 49 && px_x < 54) begin
          poly_ch = "0" + (b_abs % 10); poly_rel_x = px_x - 49;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end
        // "x"
        else if (px_x >= 54 && px_x < 59) begin
          poly_ch = "x"; poly_rel_x = px_x - 54;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end
        
        // "+" or "-" for c coefficient
        else if (px_x >= 61 && px_x < 66) begin
          poly_ch = (coef_c >= 0) ? "+" : "-"; poly_rel_x = px_x - 61;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // c coefficient tens digit
        else if (px_x >= 67 && px_x < 72) begin
          poly_ch = "0" + (c_abs / 10); poly_rel_x = px_x - 67;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end 
        // c coefficient ones digit
        else if (px_x >= 72 && px_x < 77) begin
          poly_ch = "0" + (c_abs % 10); poly_rel_x = px_x - 72;
          poly_text_on = draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]);
        end
      end
      
      // ENTER button text
      if (px_y >= ENTER_Y+5 && px_y < ENTER_Y+12) begin
        poly_rel_y = px_y - ENTER_Y - 5;
        if      (px_x >= ENTER_X+5  && px_x < ENTER_X+10) begin poly_ch="E"; poly_rel_x=px_x-ENTER_X-5;  poly_text_on=draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]); end
        else if (px_x >= ENTER_X+10 && px_x < ENTER_X+15) begin poly_ch="N"; poly_rel_x=px_x-ENTER_X-10; poly_text_on=draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]); end
        else if (px_x >= ENTER_X+15 && px_x < ENTER_X+20) begin poly_ch="T"; poly_rel_x=px_x-ENTER_X-15; poly_text_on=draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]); end
        else if (px_x >= ENTER_X+20 && px_x < ENTER_X+25) begin poly_ch="R"; poly_rel_x=px_x-ENTER_X-20; poly_text_on=draw_font(poly_ch, poly_rel_x[2:0], poly_rel_y[2:0]); end
      end
    end
  end

  wire poly_input_pix_on = (app_state == APP_POLY) && (ui_state == 1'b0) && (poly_text_on || is_arrow_pixel);
  wire [15:0] poly_input_rgb = (is_arrow_pixel && (hit_a_up || hit_a_down || hit_b_up || hit_b_down || hit_c_up || hit_c_down)) ? 16'h4A9F : 
                               (on_enter_border && hit_enter) ? 16'h07FF : 16'hFFFF;

  // ===================================================================
  // RESULTS RENDER
  // ===================================================================
  wire in_results = (app_state==APP_POLY) && (ui_state==1'b1);
  wire [2:0] line_r = px_y / 8;
  wire [6:0] ci_r = px_x / 6;
  wire [2:0] gx_r = px_x % 6;
  wire [2:0] gy_r = px_y % 8;
  
  reg [7:0] res_ch;
  always @* begin
    res_ch = " ";
    
    if (in_results) begin
      case (line_r)
        3'd0: case (ci_r)
          0: res_ch="D"; 1: res_ch="E"; 2: res_ch="G"; 3: res_ch=":"; 
          5: res_ch = "0" + degree_calc;
          default: res_ch=" "; endcase
        
        3'd1: case (ci_r)
          0: res_ch="R"; 1: res_ch="O"; 2: res_ch="O"; 3: res_ch="T"; 4: res_ch="S"; 5: res_ch=":";
          default: res_ch=" "; endcase
        
        3'd2: begin
          if (degree_calc==2 && quad_real1) case (ci_r)
            0: res_ch="r"; 1: res_ch="1"; 2: res_ch="="; 3: res_ch=r1_1_neg?"-":" "; 4: res_ch="0"; 5: res_ch="x";
            6:  res_ch=nib2hex(r1_1_abs[15:12]); 7: res_ch=nib2hex(r1_1_abs[11:8]);
            8: res_ch=nib2hex(r1_1_abs[7:4]);   9: res_ch=nib2hex(r1_1_abs[3:0]);
            default: res_ch=" "; endcase
          else if (degree_calc==1 && lin_has_root1) case (ci_r)
            0: res_ch="x"; 1: res_ch="="; 2: res_ch=lin1_neg?"-":" "; 3: res_ch="0"; 4: res_ch="x";
            5:  res_ch=nib2hex(lin1_abs[15:12]); 6:  res_ch=nib2hex(lin1_abs[11:8]);
            7: res_ch=nib2hex(lin1_abs[7:4]);   8: res_ch=nib2hex(lin1_abs[3:0]);
            default: res_ch=" "; endcase
          else if (degree_calc==2 && quad_imag1) case (ci_r)
            0: res_ch="r"; 1: res_ch="1"; 2: res_ch=":"; 3: res_ch=" "; 4: res_ch=real_neg?"-":" ";
            5: res_ch="0"; 6: res_ch="x";
            7: res_ch=nib2hex(real_abs16[15:12]); 8: res_ch=nib2hex(real_abs16[11:8]);
            9: res_ch=nib2hex(real_abs16[7:4]);   10: res_ch=nib2hex(real_abs16[3:0]);
            default: res_ch=" "; endcase
          else case (ci_r) 0: res_ch="N"; 1: res_ch="/"; 2: res_ch="A"; default: res_ch=" "; endcase
        end
        
        3'd3: begin
          if (degree_calc==2 && quad_imag1) case (ci_r)
            3: res_ch="+"; 4: res_ch=" "; 5: res_ch="0"; 6: res_ch="x";
            7: res_ch=nib2hex(imag_abs16[15:12]); 8: res_ch=nib2hex(imag_abs16[11:8]);
            9: res_ch=nib2hex(imag_abs16[7:4]);   10: res_ch=nib2hex(imag_abs16[3:0]);
            11: res_ch=" "; 12: res_ch="i"; default: res_ch=" "; endcase
          else if (degree_calc==2 && quad_real1) case (ci_r)
            0: res_ch="r"; 1: res_ch="2"; 2: res_ch="="; 3: res_ch=r2_1_neg?"-":" "; 4: res_ch="0"; 5: res_ch="x";
            6:  res_ch=nib2hex(r2_1_abs[15:12]); 7: res_ch=nib2hex(r2_1_abs[11:8]);
            8: res_ch=nib2hex(r2_1_abs[7:4]);   9: res_ch=nib2hex(r2_1_abs[3:0]);
            default: res_ch=" "; endcase
        end
        
        3'd4: if (degree_calc==2 && quad_imag1) case (ci_r)
          0: res_ch="r"; 1: res_ch="2"; 2: res_ch=":"; 3: res_ch=" "; 4: res_ch=real_neg?"-":" ";
          5: res_ch="0"; 6: res_ch="x";
          7: res_ch=nib2hex(real_abs16[15:12]); 8: res_ch=nib2hex(real_abs16[11:8]);
          9: res_ch=nib2hex(real_abs16[7:4]);   10: res_ch=nib2hex(real_abs16[3:0]);
          default: res_ch=" "; endcase
        
        3'd5: if (degree_calc==2 && quad_imag1) case (ci_r)
          3: res_ch="-"; 4: res_ch=" "; 5: res_ch="0"; 6: res_ch="x";
          7: res_ch=nib2hex(imag_abs16[15:12]); 8: res_ch=nib2hex(imag_abs16[11:8]);
          9: res_ch=nib2hex(imag_abs16[7:4]);   10: res_ch=nib2hex(imag_abs16[3:0]);
          11: res_ch=" "; 12: res_ch="i"; default: res_ch=" "; endcase
        
        default: ;
      endcase
    end
  end

  wire results_on = (app_state==APP_POLY) && in_results && draw_font(res_ch, gx_r, gy_r);
  wire [15:0] pix_results = 16'hFFFF;
  
  // =============================
  // Argand + Graph
  // =============================
  wire graph_on;
  wire [15:0] graph_rgb;
  argand_graph u_graph(
    .px_x(px_x), .px_y(px_y),
    .real_val(saved_argand_real), .imag_val(saved_argand_imag),
    .pixel_on(graph_on), .pixel_rgb(graph_rgb)
  );

  wire [4:0] real_abs = argand_real[4] ? -argand_real : argand_real;
  wire [4:0] imag_abs = argand_imag[4] ? -argand_imag : argand_imag;

  // Argand hitboxes aligned with polynomial arrows
  wire in_real_up_btn   = (px_x >= COEF_A_X-4) && (px_x < COEF_A_X+12) && (px_y >= POLY_Y-24) && (px_y < POLY_Y-16);
  wire in_real_down_btn = (px_x >= COEF_A_X-4) && (px_x < COEF_A_X+12) && (px_y >= POLY_Y+8) && (px_y < POLY_Y+16);
  wire in_imag_up_btn   = (px_x >= COEF_B_X-4) && (px_x < COEF_B_X+12) && (px_y >= POLY_Y-24) && (px_y < POLY_Y-16);
  wire in_imag_down_btn = (px_x >= COEF_B_X-4) && (px_x < COEF_B_X+12) && (px_y >= POLY_Y+8) && (px_y < POLY_Y+16);

  wire is_argand_arrow_pixel = 
    (in_real_up_btn && px_y == ARW_UP_T2 && px_x >= COEF_A_X && px_x < COEF_A_X+8) ||
    (in_real_up_btn && px_y == ARW_UP_T1 && px_x >= COEF_A_X+2 && px_x < COEF_A_X+6) ||
    (in_real_up_btn && px_y == ARW_UP_T0 && px_x >= COEF_A_X+3 && px_x < COEF_A_X+5) ||
    (in_real_down_btn && px_y == ARW_DN_T0 && px_x >= COEF_A_X && px_x < COEF_A_X+8) ||
    (in_real_down_btn && px_y == ARW_DN_T1 && px_x >= COEF_A_X+2 && px_x < COEF_A_X+6) ||
    (in_real_down_btn && px_y == ARW_DN_T2 && px_x >= COEF_A_X+3 && px_x < COEF_A_X+5) ||
    (in_imag_up_btn && px_y == ARW_UP_T2 && px_x >= COEF_B_X && px_x < COEF_B_X+8) ||
    (in_imag_up_btn && px_y == ARW_UP_T1 && px_x >= COEF_B_X+2 && px_x < COEF_B_X+6) ||
    (in_imag_up_btn && px_y == ARW_UP_T0 && px_x >= COEF_B_X+3 && px_x < COEF_B_X+5) ||
    (in_imag_down_btn && px_y == ARW_DN_T0 && px_x >= COEF_B_X && px_x < COEF_B_X+8) ||
    (in_imag_down_btn && px_y == ARW_DN_T1 && px_x >= COEF_B_X+2 && px_x < COEF_B_X+6) ||
    (in_imag_down_btn && px_y == ARW_DN_T2 && px_x >= COEF_B_X+3 && px_x < COEF_B_X+5) ||
    on_enter_border;
  
  // Argand text using draw_font
  reg argand_text_on;
  reg [7:0] arg_ch;
  reg [6:0] arg_rel_x;
  reg [5:0] arg_rel_y;
  always @* begin
    argand_text_on = 1'b0;
    arg_ch = " ";
    arg_rel_x = 0;
    arg_rel_y = 0;
    
    if (app_state == APP_ARGAND) begin
      // Number display at Y=20 (same as poly equation)
      if ((px_y >= 20) && (px_y < 27)) begin
        arg_rel_y = px_y - 20;
        // Real number sign at X=6-11
        if ((px_x >= 6) && (px_x < 11)) begin
          arg_ch = (argand_real < 0) ? "-" : " "; arg_rel_x = px_x - 6;
          argand_text_on = draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]);
        end 
        // Real number at X=11-16
        else if (px_x >= 11 && px_x < 16) begin
          arg_ch = "0" + real_abs; arg_rel_x = px_x - 11;
          argand_text_on = draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]);
        end
        // + or - sign at X=28-33
        else if (px_x >= 28 && px_x < 33) begin
          arg_ch = (argand_imag >= 0) ? "+" : "-"; arg_rel_x = px_x - 28;
          argand_text_on = draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]);
        end
        // Imaginary number at X=44-49
        else if (px_x >= 44 && px_x < 49) begin
          arg_ch = "0" + imag_abs; arg_rel_x = px_x - 44;
          argand_text_on = draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]);
        end
        // "i" at X=49-54
        else if (px_x >= 49 && px_x < 54) begin
          arg_ch = "i"; arg_rel_x = px_x - 49;
          argand_text_on = draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]);
        end
      end
      
      // ENTER button text
      if (px_y >= ENTER_Y+5 && px_y < ENTER_Y+12) begin
        arg_rel_y = px_y - ENTER_Y - 5;
        if      (px_x >= ENTER_X+5  && px_x < ENTER_X+10) begin arg_ch="E"; arg_rel_x=px_x-ENTER_X-5;  argand_text_on=draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]); end
        else if (px_x >= ENTER_X+10 && px_x < ENTER_X+15) begin arg_ch="N"; arg_rel_x=px_x-ENTER_X-10; argand_text_on=draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]); end
        else if (px_x >= ENTER_X+15 && px_x < ENTER_X+20) begin arg_ch="T"; arg_rel_x=px_x-ENTER_X-15; argand_text_on=draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]); end
        else if (px_x >= ENTER_X+20 && px_x < ENTER_X+25) begin arg_ch="R"; arg_rel_x=px_x-ENTER_X-20; argand_text_on=draw_font(arg_ch, arg_rel_x[2:0], arg_rel_y[2:0]); end
      end
    end
  end

  wire argand_pix_on = (app_state == APP_ARGAND) && (argand_text_on || is_argand_arrow_pixel);
  wire [15:0] argand_rgb = (is_argand_arrow_pixel && (hit_a_up || hit_a_down || hit_b_up || hit_b_down)) ? 16'h4A9F : 
                           (on_enter_border && hit_enter) ? 16'h07FF : 16'hFFFF;

  // Final blend
  wire [15:0] pixel_data;
  assign pixel_data = cur_on ? pix_cur :
                      (app_state==APP_SPLASH && splash_on) ? pix_splash :
                      (app_state==APP_POLY && ui_state==0 && poly_input_pix_on) ? poly_input_rgb :
                      (app_state==APP_POLY && ui_state==1 && results_on) ? pix_results :
                      (app_state==APP_ARGAND && argand_pix_on) ? argand_rgb :
                      (app_state==APP_GRAPH && graph_on) ? graph_rgb : 
                      16'h0000;
                      
  assign oled_data_out = pixel_data;
    
endmodule

// ====== Argand Graph ======
module argand_graph(
  input [6:0] px_x, px_y,
  input signed [4:0] real_val, imag_val,
  output reg pixel_on,
  output reg [15:0] pixel_rgb
);
  localparam GRID_SIZE = 5, CENTER_X = 48, CENTER_Y = 32;
  
  wire signed [7:0] point_x_signed = CENTER_X + (real_val * GRID_SIZE);
  wire signed [7:0] point_y_signed = CENTER_Y - (imag_val * GRID_SIZE);
  wire [6:0] point_x = (point_x_signed < 0) ? 7'd0 : (point_x_signed > 95) ? 7'd95 : point_x_signed[6:0];
  wire [6:0] point_y = (point_y_signed < 0) ? 7'd0 : (point_y_signed > 63) ? 7'd63 : point_y_signed[6:0];
  
  wire signed [7:0] curr_dx = $signed({1'b0, px_x}) - CENTER_X;
  wire signed [7:0] curr_dy = $signed({1'b0, px_y}) - CENTER_Y;
  wire signed [7:0] dx = $signed({1'b0, point_x}) - CENTER_X;
  wire signed [7:0] dy = $signed({1'b0, point_y}) - CENTER_Y;
  
  wire signed [15:0] cross_prod = dx * curr_dy - dy * curr_dx;
  wire [15:0] abs_cross = cross_prod[15] ? (~cross_prod + 16'd1) : cross_prod;
  wire on_seg_x = (dx >= 0) ? (curr_dx >= 0 && curr_dx <= dx) : (curr_dx <= 0 && curr_dx >= dx);
  wire on_seg_y = (dy >= 0) ? (curr_dy >= 0 && curr_dy <= dy) : (curr_dy <= 0 && curr_dy >= dy);
  wire on_segment = on_seg_x && on_seg_y;

  always @* begin
    pixel_on = 1'b0; pixel_rgb = 16'h0000;
    if (px_x == CENTER_X || px_y == CENTER_Y) begin pixel_on = 1'b1; pixel_rgb = 16'h39E7; end
    if (((px_x - CENTER_X) % GRID_SIZE == 0) && ((px_y - CENTER_Y) % GRID_SIZE == 0) && (px_x[0] == 0) && (px_y[0] == 0)) begin
      pixel_on = 1'b1; pixel_rgb = 16'h2104;
    end
    if ((px_x >= point_x - 2) && (px_x <= point_x + 2) && (px_y >= point_y - 2) && (px_y <= point_y + 2)) begin
      if ((px_x == point_x) || (px_y == point_y)) begin pixel_on = 1'b1; pixel_rgb = 16'hF800; end
    end
    if ((dx != 0 || dy != 0) && (abs_cross < 16'd50) && on_segment) begin pixel_on = 1'b1; pixel_rgb = 16'h07E0; end
  end
endmodule