`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: MatrixPages
//////////////////////////////////////////////////////////////////////////////////
// 16-bit Fibonacci LFSR (maximal): taps 16,14,13,11
module lfsr16 (
  input  wire clk,
  input  wire rst_n,       // active-low
  input  wire enable,
  input  wire [15:0] seed, // ignored if zero
  output reg  [15:0] q
);
  wire fb = q[15] ^ q[13] ^ q[12] ^ q[10];
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= (seed!=16'h0000) ? seed : 16'hACE1;
    else if (enable) q <= {q[14:0], fb};
  end
endmodule


// =================================================
// MatrixPages: menus + arithmetic (add/sub/mul),
// multi-digit math; 2-digit result renderer
// =================================================
module MatrixPages(
    input clk,
    input clk_pix,
    input sw1, sw3,
    input [11:0] mouse_x, mouse_y,
    input mouse_l,
    input mouse_r,
    output reg [15:0] oled_data,
    input [12:0] pixel_index
);
    // ===== RNG core =====
    wire [15:0] rng_q;
    reg rng_init = 1'b1;
    always @(posedge clk) begin
      if (rng_init) rng_init <= 1'b0;  // deassert after 1 cycle
    end
    
    lfsr16 u_lfsr (
      .clk(clk),
      .rst_n(~rng_init),
      .enable(1'b1),        // always spin; cheap
      .seed(16'hD431),
      .q(rng_q)
    );
    
    // ---------- temps ----------
    integer i,m,n;
    reg prev_mouse_l = 1'b0, mouse_armed = 1'b1;

    // ---------- cursor (unsigned, safe range) ----------
    reg [6:0] cursor_x = 7'd48;   // 0..95
    reg [5:0] cursor_y = 6'd32;   // 0..63

    // ---------- raster ----------
    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;
    


    // ---------- UI states ----------
    localparam [4:0]
        ST_MENU        = 5'd0,
        ST_AR_MENU     = 5'd1,

        ST_AR_ADD_A    = 5'd2,
        ST_AR_ADD_B    = 5'd3,
        ST_AR_ADD_SUM  = 5'd4,

        ST_AR_SUB_A    = 5'd5,
        ST_AR_SUB_B    = 5'd6,
        ST_AR_SUB_RES  = 5'd7,

        ST_AR_MUL_A    = 5'd8,
        ST_AR_MUL_B    = 5'd9,
        ST_AR_MUL_RES  = 5'd10,
        
        // det and inv states
        ST_DET_MENU  = 5'd11,
        ST_DET_EDIT  = 5'd12,
        ST_DET_RES   = 5'd13,
        ST_ADJ_EDIT    = 5'd14,
        ST_ADJ_RES     = 5'd15,
    
        // keep INV placeholder if you still want it later:
        ST_INV_EDIT    = 5'd16,
        ST_INV_RES     = 5'd17;

    reg [4:0] ui_state = ST_MENU;
    

    
    wire add_flow_active = (ui_state==ST_AR_ADD_A || ui_state==ST_AR_ADD_B || ui_state==ST_AR_ADD_SUM);
    wire sub_flow_active = (ui_state==ST_AR_SUB_A || ui_state==ST_AR_SUB_B || ui_state==ST_AR_SUB_RES);
    wire mul_flow_active = (ui_state==ST_AR_MUL_A || ui_state==ST_AR_MUL_B || ui_state==ST_AR_MUL_RES);
    wire any_edit_A = (ui_state==ST_AR_ADD_A || ui_state==ST_AR_SUB_A || ui_state==ST_AR_MUL_A);
    wire any_edit_B = (ui_state==ST_AR_ADD_B || ui_state==ST_AR_SUB_B || ui_state==ST_AR_MUL_B);
    
    // flows
    wire det_flow_active = (ui_state==ST_DET_EDIT || ui_state==ST_DET_RES);
    wire adj_flow_active = (ui_state==ST_ADJ_EDIT || ui_state==ST_ADJ_RES);
    wire inv_flow_active  = (ui_state==ST_INV_EDIT || ui_state==ST_INV_RES);
    
    // treat DET/ADJ edit screens like editing A
    wire any_edit_DETADJ = (ui_state==ST_DET_EDIT || ui_state==ST_ADJ_EDIT || ui_state==ST_INV_EDIT);
    
    // one flag to gate keypad & edit UIs (saves repeated compares in pixel hot path)
    wire any_edit = any_edit_A | any_edit_B | any_edit_DETADJ;

    // RNG
    // ===== RNG button geometry (top bar) =====
    localparam [6:0] RNG_W = 7'd22;
    localparam [5:0] RNG_H = 6'd10;
    localparam [6:0] RNG_X = 7'd62;   // centered-ish above edit area
    localparam [5:0] RNG_Y = 6'd1;
    
    // cursor-space hit test (clicking)
    wire hover_rng_cur =
      (any_edit) &&
      (cursor_x >= RNG_X && cursor_x < (RNG_X + RNG_W)) &&
      (cursor_y >= RNG_Y && cursor_y < (RNG_Y + RNG_H));
    
    // pixel-space draw for the button rectangle
    wire rng_on =
      (any_edit_A || any_edit_B || any_edit_DETADJ) &&
      (y >= RNG_Y && y < RNG_Y + RNG_H) &&
      (x >= RNG_X && x < RNG_X + RNG_W);
    
    wire rng_label_on =
      (any_edit_A || any_edit_B || any_edit_DETADJ) && (
        draw_letter("R", x-(RNG_X+2),  y-(RNG_Y+2), 5,7) ||
        draw_letter("N", x-(RNG_X+8), y-(RNG_Y+2), 5,7) ||
        draw_letter("G", x-(RNG_X+14), y-(RNG_Y+2), 5,7)
      );
    
    wire [15:0] pix_rng_rect = 16'h7BEF; // mid grey (C_BTN vibe)

    // results
    reg  signed [15:0] det_val;               // scalar determinant
    reg  signed [15:0] adj[0:1][0:1];         // adjugate matrix

    // ---------- matrices ----------
    // inputs are digits 0..9 from keypad
    reg signed [7:0] matA[0:1][0:1];
    reg signed [7:0] matA_saved[0:1][0:1];
    reg signed [7:0] matB[0:1][0:1];

    // ======= tens/ones ROM (0..99) =======
    wire [3:0] bcd_tens, bcd_ones;
    reg  [6:0] bcd_idx;      // abs(value) clamped to 0..99
    dec_bcd_rom u_bcd (.clk(clk_pix), .idx(bcd_idx), .tens(bcd_tens), .ones(bcd_ones));


    // results (signed, wide enough; rendering clamps to [-99..99])
    reg signed [7:0] matAdd[0:1][0:1]; // -99..99 shown; real sum is 0..18
    reg signed [7:0] matSub[0:1][0:1]; // -9..9
    reg signed [7:0] matMul[0:1][0:1]; // up to 19602 w 99s

    // temps
    reg  signed [8:0] sum_s, diff_s;
    reg  signed [15:0] p00,p01,p10,p11;
    
    // two-digit entry buffer
    reg [6:0] acc_mag = 7'd0;   // 0..99
    reg       acc_neg = 1'b0; // 1=> negative
    reg [1:0] acc_cnt = 2'd0;   // how many digits typed (0..2)
    // Signed view of the buffer (0..99 with optional minus)
    wire signed [7:0] acc_signed =
      acc_neg ? -$signed({1'b0, acc_mag}) : $signed({1'b0, acc_mag});

    // === determinant partial products (DSP-friendly) ===
    (* use_dsp = "yes" *) wire signed [21:0] det_p0 =
        $signed(matA[0][0]) * $signed(matA[1][1]);
    (* use_dsp = "yes" *) wire signed [21:0] det_p1 =
        $signed(matA[0][1]) * $signed(matA[1][0]);

    
    reg [1:0] row = 2'd0, col = 2'd0;

    // ---------- layout (edit screens) ----------
    localparam [6:0] DIGIT_W=7'd9;   
    localparam [5:0] DIGIT_H=6'd12;
    
    // --- Small font for EDIT preview (on the right) ---
    localparam [6:0] E_DIGIT_W = 7'd6;  // was 8
    localparam [5:0] E_DIGIT_H = 6'd9;  // was 12
    localparam [6:0] E_KERN    = 7'd1;  // spacing between tens/ones
    localparam [6:0] E_SIGN_W  = 7'd4;  // no sign slot in edit view
    localparam [6:0] E_COL_STEP= 7'd14; // keep 14

    
    // ======= Pretty Keypad (rounded corners vibes) =======
    localparam [2:0] KPAD = 3'd2;
    localparam [6:0] KEY_W = DIGIT_W + (KPAD<<1);
    localparam [5:0] KEY_H = DIGIT_H + (KPAD<<1);
    
    localparam [6:0] COL_STEP = 7'd16;
    localparam [6:0] GAP_X  = 7'd3;  
    localparam [5:0] GAP_Y  = 6'd2;
    localparam [2:0] STEP   = 3'd2;

    // NEXT button
    localparam [6:0] BTN_X = 7'd48, BTN_W = 7'd25;
    localparam [5:0] BTN_Y = 6'd45, BTN_H = 6'd10;
    
    localparam [6:0] GAP_R = 7'd2;      // right margin
    localparam [6:0] GAP_BETWEEN = 7'd4;
    
    // NEW: dynamic X for NEXT (far right) and DEL (to its left)
    wire [6:0] BTN_NEXT_X = 7'd96 - GAP_R - BTN_W;
    wire [6:0] BTN_DEL_X_CUR = BTN_NEXT_X - GAP_BETWEEN - (BTN_W - 7'd3); // uses your BTN_DEL_W

    localparam [6:0] BTN_NEXT_X2  = BTN_X + BTN_W; // push NEXT right by ~4 px
    localparam [5:0] BTN_NEXT_Y2  = BTN_Y;
    localparam [6:0] BTN_NEXT_W2  = BTN_W;
    localparam [5:0] BTN_NEXT_H2  = BTN_H;

    // DELETE bar (same size as NEXT, placed on its left)
    localparam [6:0] BTN_DEL_W = BTN_W - 7'd1;
    localparam [5:0] BTN_DEL_H = BTN_H;
    wire [6:0] BTN_DEL_X = BTN_NEXT_X - GAP_BETWEEN - BTN_DEL_W;
    localparam [5:0] BTN_DEL_Y = BTN_Y;
    localparam [15:0] C_RED = 16'hF800;
    localparam [15:0] C_YELLOW = 16'hFFE0; // del


    // --- dynamic NEXT x: during edit screens, push NEXT right by +3+BTN_W ---
    wire [6:0] NEXT_X_ACTIVE = (any_edit_A || any_edit_B || any_edit_DETADJ)
              ? (BTN_X + BTN_W + 7'd3) : BTN_X;
    

    // keypad positions (1..9 then 0)
    wire [6:0] pos_x [0:9];
    wire [5:0] pos_y [0:9];
    assign pos_x[1]=7'd3; assign pos_y[1]=6'd2;
    assign pos_x[2]=7'd3+DIGIT_W+GAP_X; assign pos_y[2]=6'd2;
    assign pos_x[3]=7'd3+2*(DIGIT_W+GAP_X); assign pos_y[3]=6'd2;
    assign pos_x[4]=pos_x[1]; assign pos_y[4]=6'd2+DIGIT_H+GAP_Y;
    assign pos_x[5]=pos_x[2]; assign pos_y[5]=6'd2+DIGIT_H+GAP_Y;
    assign pos_x[6]=pos_x[3]; assign pos_y[6]=6'd2+DIGIT_H+GAP_Y;
    assign pos_x[7]=pos_x[1]; assign pos_y[7]=6'd2+2*(DIGIT_H+GAP_Y);
    assign pos_x[8]=pos_x[2]; assign pos_y[8]=6'd2+2*(DIGIT_H+GAP_Y);
    assign pos_x[9]=pos_x[3]; assign pos_y[9]=6'd2+2*(DIGIT_H+GAP_Y);
    assign pos_x[0]=pos_x[1]; assign pos_y[0]=6'd2+3*(DIGIT_H+GAP_Y);
    
    
    // Unified bottom row (0, -, OK)
    localparam [6:0] BOTTOM_KEY_W = KEY_W;
    localparam [5:0] BOTTOM_KEY_H = KEY_H;
    
    // 0 key already at pos_x[1]
    wire [6:0] pos_x_NEG = pos_x[2];
    wire [6:0] pos_x_OK  = pos_x[3];
    
    wire [5:0] pos_y_NEG = pos_y[0];
    wire [5:0] pos_y_OK  = pos_y[0];
    
    localparam [6:0] NEG_W = BOTTOM_KEY_W;
    localparam [5:0] NEG_H = BOTTOM_KEY_H;
    localparam [6:0] OK_W  = BOTTOM_KEY_W;
    localparam [5:0] OK_H  = BOTTOM_KEY_H; 

    // DET/ADJ submenu (two rows)
    localparam [6:0] DAM_W = 7'd30;
    localparam [5:0] DAM_H = 6'd10;
    localparam [6:0] DAM_X = 7'd6;
    localparam [5:0] DAM_Y1 = 6'd22; // DET
    localparam [5:0] DAM_Y2 = 6'd36; // ADJ

    // Back button (reuse the same top-right size/pos as arithmetic back)
    localparam [6:0] DAM_BACK_W = 7'd28;
    localparam [5:0] DAM_BACK_H = 6'd10;
    localparam [6:0] DAM_BACK_X = 7'd96 - DAM_BACK_W - 7'd2;
    localparam [5:0] DAM_BACK_Y = 6'd27;
    
    wire dam_row1_cur = (cursor_x>=DAM_X && cursor_x<DAM_X+DAM_W+7'd20 && cursor_y>=DAM_Y1 && cursor_y<DAM_Y1+DAM_H);
    wire dam_row2_cur = (cursor_x>=DAM_X && cursor_x<DAM_X+DAM_W+7'd20 && cursor_y>=DAM_Y2 && cursor_y<DAM_Y2+DAM_H);
    
    // --- INV determinant label placement (top band, out of the way) ---
    localparam [6:0] INV_DET_X      = 7'd2;   // left margin for "DET="
    localparam [5:0] INV_DET_Y      = 6'd6;   // near the top so it never overlaps the adj matrix
    localparam [6:0] INV_DET_VAL_X  = 7'd30;  // where the number begins (after "DET=")
    localparam [5:0] INV_DET_VAL_Y  = 6'd5;   // align the value nicely with the label
    
    // compact but readable digits
    localparam [6:0] INV_DET_DW     = 7'd4;   // digit width
    localparam [5:0] INV_DET_DH     = 6'd8;  // digit height
    localparam [6:0] INV_DET_KERN   = 7'd1;   // gap between tens/ones
    localparam [6:0] INV_DET_SIGNW  = 7'd5;   // sign "slot" width (clear minus bar)
    
    // === RNG: exact ±63 from LFSR (no mul/shift) ===
    // use high LFSR bits for better distribution
    wire        rng_sign    = rng_q[13];
    wire [5:0]  rng_mag_u6  = rng_q[12:7];       // 0..63
    wire signed [6:0] rng_pm63 =
      rng_sign ? -$signed({1'b0, rng_mag_u6}) : $signed({1'b0, rng_mag_u6});


    // ---------- helpers ----------
    function [6:0] clamp_x; input [6:0] v;
        begin clamp_x = (v > 7'd95) ? 7'd95 : v; end
    endfunction
    function [5:0] clamp_y; input [5:0] v;
        begin clamp_y = (v > 6'd63) ? 6'd63 : v; end
    endfunction

    // =================================================
    // FONT HELPERS
    // =================================================
    // ======= DIVIDER-FREE 5x7 DIGIT (scaled to fixed box) =======
    // rx: 0..dW-1, ry: 0..dH-1. pick dW=7, dH=12 (matches your R_DIGIT_W/H)
    // rx,ry can be negative (x - origin), so take signed and guard bounds
    function draw_digit5x7;
      input signed [6:0] rx; input signed [5:0] ry;
      input [6:0] dW; input [5:0] dH;
      input [3:0] dig;
      reg [2:0] row7, col5; reg [4:0] row_bits;
    begin
      // default
      draw_digit5x7 = 1'b0;
    
      // guard bounds
      if (!(rx < 0 || ry < 0 || rx >= $signed(dW) || ry >= $signed(dH))) begin
        // map ry -> 0..6
        if      (ry < 2)  row7 = 0;
        else if (ry < 4)  row7 = 1;
        else if (ry < 6)  row7 = 2;
        else if (ry < 8)  row7 = 3;
        else if (ry < 10) row7 = 4;
        else if (ry < 11) row7 = 5;
        else              row7 = 6;
    
        // map rx -> 0..4
        if      (rx < 1)  col5 = 0;
        else if (rx < 3)  col5 = 1;
        else if (rx < 4)  col5 = 2;
        else if (rx < 6)  col5 = 3;
        else              col5 = 4;
    
        case (dig)
          0: case(row7) 0,6:row_bits=5'b11111; 1,2,3,4,5:row_bits=5'b10001; default: row_bits=0; endcase
          1: case(row7) 0,6:row_bits=5'b00100; 1,2,3,4,5:row_bits=5'b01100; default: row_bits=0; endcase
          2: case(row7) 0,3,6:row_bits=5'b11111; 1,2:row_bits=5'b00001; 4,5:row_bits=5'b10000; default: row_bits=0; endcase
          3: case(row7) 0,3,6:row_bits=5'b11111; 1,2,4,5:row_bits=5'b00001; default: row_bits=0; endcase
          4: case(row7) 0,1:row_bits=5'b10001; 2:row_bits=5'b11111; 3,4,5,6:row_bits=5'b00001; default: row_bits=0; endcase
          5: case(row7) 0,3,6:row_bits=5'b11111; 1,2:row_bits=5'b10000; 4,5:row_bits=5'b00001; default: row_bits=0; endcase
          6: case(row7) 0,3,6:row_bits=5'b11111; 1,2:row_bits=5'b10000; 4,5:row_bits=5'b10001; default: row_bits=0; endcase
          7: case(row7) 0:row_bits=5'b11111; 1,2,3,4,5,6:row_bits=5'b00001; default: row_bits=0; endcase
          8: case(row7) 0,3,6:row_bits=5'b11111; 1,2,4,5:row_bits=5'b10001; default: row_bits=0; endcase
          9: case(row7) 0,3,6:row_bits=5'b11111; 1,2:row_bits=5'b10001; 4,5:row_bits=5'b00001; default: row_bits=0; endcase
          default: row_bits = 5'b00000;
        endcase
    
        draw_digit5x7 = row_bits[4-col5];
      end
    end
    endfunction


    function draw_number;
        input [3:0] number; input [6:0] rel_x; input [5:0] rel_y;
        input [6:0] width;  input [5:0] height;
        reg [4:0] row_pattern; integer t, scale_y;
        begin
            draw_number=0;
            if(rel_x<width && rel_y<height) begin
                scale_y=(rel_y*7)/height;
                case(number)
                    0: case(scale_y) 0,6:row_pattern=5'b11111;1,2,3,4,5:row_pattern=5'b10001;default:row_pattern=5'b00000;endcase
                    1: case(scale_y) 0,6:row_pattern=5'b00100;1,2,3,4,5:row_pattern=5'b01100;default:row_pattern=5'b00000;endcase
                    2: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2:row_pattern=5'b00001;4,5:row_pattern=5'b10000;default:row_pattern=5'b00000;endcase
                    3: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2,4,5:row_pattern=5'b00001;default:row_pattern=5'b00000;endcase
                    4: case(scale_y) 0,1:row_pattern=5'b10001;2:row_pattern=5'b11111;3,4,5,6:row_pattern=5'b00001;default:row_pattern=5'b00000;endcase
                    5: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2:row_pattern=5'b10000;4,5:row_pattern=5'b00001;default:row_pattern=5'b00000;endcase
                    6: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2:row_pattern=5'b10000;4,5:row_pattern=5'b10001;default:row_pattern=5'b00000;endcase
                    7: case(scale_y) 0:row_pattern=5'b11111;1,2,3,4,5,6:row_pattern=5'b00001;default:row_pattern=5'b00000;endcase
                    8: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2,4,5:row_pattern=5'b10001;default:row_pattern=5'b00000;endcase
                    9: case(scale_y) 0,3,6:row_pattern=5'b11111;1,2:row_pattern=5'b10001;4,5:row_pattern=5'b00001;default:row_pattern=5'b00000;endcase
                    default: row_pattern=5'b00000;
                endcase
                t=(rel_x*5)/width;
                if(t<5 && row_pattern[4-t]) draw_number=1;
            end
        end
    endfunction
    
    // ============================================================
    // 5x7 ASCII FONT (Distributed ROM) + drop-in draw_letter()
    // Keeps the same call sites: draw_letter("X", rx, ry, dW, dH)
    // ============================================================
    
    // 896 rows (128 chars * 7 rows), each row = 5 bits
    // Using distributed ROM keeps it combinational (no pipeline).
    (* rom_style = "distributed", ram_style = "distributed" *)
    reg [4:0] FONT5x7 [0:128*7-1];
    
    // -------- init only the glyphs you actually use --------
    integer __fi;
    initial begin
      for (__fi=0; __fi<128*7; __fi=__fi+1) FONT5x7[__fi] = 5'b00000;
    
      // Digits '0'..'9' (0x30..0x39)  - simple bold-ish 5x7
      // 0
      FONT5x7[{7'h30,3'd0}] = 5'b11111; FONT5x7[{7'h30,3'd1}] = 5'b10001; FONT5x7[{7'h30,3'd2}] = 5'b10001;
      FONT5x7[{7'h30,3'd3}] = 5'b10001; FONT5x7[{7'h30,3'd4}] = 5'b10001; FONT5x7[{7'h30,3'd5}] = 5'b10001;
      FONT5x7[{7'h30,3'd6}] = 5'b11111;
      // 1
      FONT5x7[{7'h31,3'd0}] = 5'b00100; FONT5x7[{7'h31,3'd1}] = 5'b01100; FONT5x7[{7'h31,3'd2}] = 5'b00100;
      FONT5x7[{7'h31,3'd3}] = 5'b00100; FONT5x7[{7'h31,3'd4}] = 5'b00100; FONT5x7[{7'h31,3'd5}] = 5'b00100;
      FONT5x7[{7'h31,3'd6}] = 5'b11111;
      // 2
      FONT5x7[{7'h32,3'd0}] = 5'b11111; FONT5x7[{7'h32,3'd1}] = 5'b00001; FONT5x7[{7'h32,3'd2}] = 5'b00001;
      FONT5x7[{7'h32,3'd3}] = 5'b11111; FONT5x7[{7'h32,3'd4}] = 5'b10000; FONT5x7[{7'h32,3'd5}] = 5'b10000;
      FONT5x7[{7'h32,3'd6}] = 5'b11111;
      // 3
      FONT5x7[{7'h33,3'd0}] = 5'b11111; FONT5x7[{7'h33,3'd1}] = 5'b00001; FONT5x7[{7'h33,3'd2}] = 5'b00001;
      FONT5x7[{7'h33,3'd3}] = 5'b11111; FONT5x7[{7'h33,3'd4}] = 5'b00001; FONT5x7[{7'h33,3'd5}] = 5'b00001;
      FONT5x7[{7'h33,3'd6}] = 5'b11111;
      // 4
      FONT5x7[{7'h34,3'd0}] = 5'b10001; FONT5x7[{7'h34,3'd1}] = 5'b10001; FONT5x7[{7'h34,3'd2}] = 5'b10001;
      FONT5x7[{7'h34,3'd3}] = 5'b11111; FONT5x7[{7'h34,3'd4}] = 5'b00001; FONT5x7[{7'h34,3'd5}] = 5'b00001;
      FONT5x7[{7'h34,3'd6}] = 5'b00001;
      // 5
      FONT5x7[{7'h35,3'd0}] = 5'b11111; FONT5x7[{7'h35,3'd1}] = 5'b10000; FONT5x7[{7'h35,3'd2}] = 5'b10000;
      FONT5x7[{7'h35,3'd3}] = 5'b11111; FONT5x7[{7'h35,3'd4}] = 5'b00001; FONT5x7[{7'h35,3'd5}] = 5'b00001;
      FONT5x7[{7'h35,3'd6}] = 5'b11111;
      // 6
      FONT5x7[{7'h36,3'd0}] = 5'b11111; FONT5x7[{7'h36,3'd1}] = 5'b10000; FONT5x7[{7'h36,3'd2}] = 5'b10000;
      FONT5x7[{7'h36,3'd3}] = 5'b11111; FONT5x7[{7'h36,3'd4}] = 5'b10001; FONT5x7[{7'h36,3'd5}] = 5'b10001;
      FONT5x7[{7'h36,3'd6}] = 5'b11111;
      // 7
      FONT5x7[{7'h37,3'd0}] = 5'b11111; FONT5x7[{7'h37,3'd1}] = 5'b00001; FONT5x7[{7'h37,3'd2}] = 5'b00010;
      FONT5x7[{7'h37,3'd3}] = 5'b00100; FONT5x7[{7'h37,3'd4}] = 5'b01000; FONT5x7[{7'h37,3'd5}] = 5'b10000;
      FONT5x7[{7'h37,3'd6}] = 5'b10000;
      // 8
      FONT5x7[{7'h38,3'd0}] = 5'b11111; FONT5x7[{7'h38,3'd1}] = 5'b10001; FONT5x7[{7'h38,3'd2}] = 5'b10001;
      FONT5x7[{7'h38,3'd3}] = 5'b11111; FONT5x7[{7'h38,3'd4}] = 5'b10001; FONT5x7[{7'h38,3'd5}] = 5'b10001;
      FONT5x7[{7'h38,3'd6}] = 5'b11111;
      // 9
      FONT5x7[{7'h39,3'd0}] = 5'b11111; FONT5x7[{7'h39,3'd1}] = 5'b10001; FONT5x7[{7'h39,3'd2}] = 5'b10001;
      FONT5x7[{7'h39,3'd3}] = 5'b11111; FONT5x7[{7'h39,3'd4}] = 5'b00001; FONT5x7[{7'h39,3'd5}] = 5'b00001;
      FONT5x7[{7'h39,3'd6}] = 5'b11111;
    
      // Letters you use for labels: B C D E I J K L M N O P R S T U V X
      // 'A' (0x41)
      FONT5x7[{7'h41,3'd0}] = 5'b01110;
      FONT5x7[{7'h41,3'd1}] = 5'b10001;
      FONT5x7[{7'h41,3'd2}] = 5'b10001;
      FONT5x7[{7'h41,3'd3}] = 5'b11111;
      FONT5x7[{7'h41,3'd4}] = 5'b10001;
      FONT5x7[{7'h41,3'd5}] = 5'b10001;
      FONT5x7[{7'h41,3'd6}] = 5'b10001;
      // B (0x42)
      FONT5x7[{7'h42,3'd0}] = 5'b11110; FONT5x7[{7'h42,3'd1}] = 5'b10001; FONT5x7[{7'h42,3'd2}] = 5'b10001;
      FONT5x7[{7'h42,3'd3}] = 5'b11110; FONT5x7[{7'h42,3'd4}] = 5'b10001; FONT5x7[{7'h42,3'd5}] = 5'b10001;
      FONT5x7[{7'h42,3'd6}] = 5'b11110;
      // C (0x43)
      FONT5x7[{7'h43,3'd0}] = 5'b11111; FONT5x7[{7'h43,3'd1}] = 5'b10000; FONT5x7[{7'h43,3'd2}] = 5'b10000;
      FONT5x7[{7'h43,3'd3}] = 5'b10000; FONT5x7[{7'h43,3'd4}] = 5'b10000; FONT5x7[{7'h43,3'd5}] = 5'b10000;
      FONT5x7[{7'h43,3'd6}] = 5'b11111;
      // D (0x44)
      FONT5x7[{7'h44,3'd0}] = 5'b11110; FONT5x7[{7'h44,3'd1}] = 5'b10001; FONT5x7[{7'h44,3'd2}] = 5'b10001;
      FONT5x7[{7'h44,3'd3}] = 5'b10001; FONT5x7[{7'h44,3'd4}] = 5'b10001; FONT5x7[{7'h44,3'd5}] = 5'b10001;
      FONT5x7[{7'h44,3'd6}] = 5'b11110;
      // E (0x45)
      FONT5x7[{7'h45,3'd0}] = 5'b11111; FONT5x7[{7'h45,3'd1}] = 5'b10000; FONT5x7[{7'h45,3'd2}] = 5'b10000;
      FONT5x7[{7'h45,3'd3}] = 5'b11111; FONT5x7[{7'h45,3'd4}] = 5'b10000; FONT5x7[{7'h45,3'd5}] = 5'b10000;
      FONT5x7[{7'h45,3'd6}] = 5'b11111;
      // G (0x47)
      FONT5x7[{7'h47,3'd0}] = 5'b01110;
      FONT5x7[{7'h47,3'd1}] = 5'b10001;
      FONT5x7[{7'h47,3'd2}] = 5'b10000;
      FONT5x7[{7'h47,3'd3}] = 5'b10111;
      FONT5x7[{7'h47,3'd4}] = 5'b10001;
      FONT5x7[{7'h47,3'd5}] = 5'b10001;
      FONT5x7[{7'h47,3'd6}] = 5'b01111;
      // 'H' (0x48)
      FONT5x7[{7'h48,3'd0}] = 5'b10001;
      FONT5x7[{7'h48,3'd1}] = 5'b10001;
      FONT5x7[{7'h48,3'd2}] = 5'b10001;
      FONT5x7[{7'h48,3'd3}] = 5'b11111;
      FONT5x7[{7'h48,3'd4}] = 5'b10001;
      FONT5x7[{7'h48,3'd5}] = 5'b10001;
      FONT5x7[{7'h48,3'd6}] = 5'b10001;
      // I (0x49)
      FONT5x7[{7'h49,3'd0}] = 5'b11111; FONT5x7[{7'h49,3'd1}] = 5'b00100; FONT5x7[{7'h49,3'd2}] = 5'b00100;
      FONT5x7[{7'h49,3'd3}] = 5'b00100; FONT5x7[{7'h49,3'd4}] = 5'b00100; FONT5x7[{7'h49,3'd5}] = 5'b00100;
      FONT5x7[{7'h49,3'd6}] = 5'b11111;
      // J (0x4A)
      FONT5x7[{7'h4A,3'd0}] = 5'b00111; FONT5x7[{7'h4A,3'd1}] = 5'b00010; FONT5x7[{7'h4A,3'd2}] = 5'b00010;
      FONT5x7[{7'h4A,3'd3}] = 5'b00010; FONT5x7[{7'h4A,3'd4}] = 5'b10010; FONT5x7[{7'h4A,3'd5}] = 5'b10010;
      FONT5x7[{7'h4A,3'd6}] = 5'b01100;
      // K (0x4B)
      FONT5x7[{7'h4B,3'd0}] = 5'b10001; FONT5x7[{7'h4B,3'd1}] = 5'b10010; FONT5x7[{7'h4B,3'd2}] = 5'b10100;
      FONT5x7[{7'h4B,3'd3}] = 5'b11000; FONT5x7[{7'h4B,3'd4}] = 5'b10100; FONT5x7[{7'h4B,3'd5}] = 5'b10010;
      FONT5x7[{7'h4B,3'd6}] = 5'b10001;
      // L (0x4C)
      FONT5x7[{7'h4C,3'd0}] = 5'b10000; FONT5x7[{7'h4C,3'd1}] = 5'b10000; FONT5x7[{7'h4C,3'd2}] = 5'b10000;
      FONT5x7[{7'h4C,3'd3}] = 5'b10000; FONT5x7[{7'h4C,3'd4}] = 5'b10000; FONT5x7[{7'h4C,3'd5}] = 5'b10000;
      FONT5x7[{7'h4C,3'd6}] = 5'b11111;
      // M (0x4D)
      FONT5x7[{7'h4D,3'd0}] = 5'b10001; FONT5x7[{7'h4D,3'd1}] = 5'b11011; FONT5x7[{7'h4D,3'd2}] = 5'b10101;
      FONT5x7[{7'h4D,3'd3}] = 5'b10001; FONT5x7[{7'h4D,3'd4}] = 5'b10001; FONT5x7[{7'h4D,3'd5}] = 5'b10001;
      FONT5x7[{7'h4D,3'd6}] = 5'b10001;
      // N (0x4E)
      FONT5x7[{7'h4E,3'd0}] = 5'b10001; FONT5x7[{7'h4E,3'd1}] = 5'b11001; FONT5x7[{7'h4E,3'd2}] = 5'b10101;
      FONT5x7[{7'h4E,3'd3}] = 5'b10011; FONT5x7[{7'h4E,3'd4}] = 5'b10001; FONT5x7[{7'h4E,3'd5}] = 5'b10001;
      FONT5x7[{7'h4E,3'd6}] = 5'b10001;
      // O (0x4F)
      FONT5x7[{7'h4F,3'd0}] = 5'b01110; FONT5x7[{7'h4F,3'd1}] = 5'b10001; FONT5x7[{7'h4F,3'd2}] = 5'b10001;
      FONT5x7[{7'h4F,3'd3}] = 5'b10001; FONT5x7[{7'h4F,3'd4}] = 5'b10001; FONT5x7[{7'h4F,3'd5}] = 5'b10001;
      FONT5x7[{7'h4F,3'd6}] = 5'b01110;
      // P (0x50)
      FONT5x7[{7'h50,3'd0}] = 5'b11110; FONT5x7[{7'h50,3'd1}] = 5'b10001; FONT5x7[{7'h50,3'd2}] = 5'b10001;
      FONT5x7[{7'h50,3'd3}] = 5'b11110; FONT5x7[{7'h50,3'd4}] = 5'b10000; FONT5x7[{7'h50,3'd5}] = 5'b10000;
      FONT5x7[{7'h50,3'd6}] = 5'b10000;
      // R (0x52)
      FONT5x7[{7'h52,3'd0}] = 5'b11110; FONT5x7[{7'h52,3'd1}] = 5'b10001; FONT5x7[{7'h52,3'd2}] = 5'b10001;
      FONT5x7[{7'h52,3'd3}] = 5'b11110; FONT5x7[{7'h52,3'd4}] = 5'b10100; FONT5x7[{7'h52,3'd5}] = 5'b10010;
      FONT5x7[{7'h52,3'd6}] = 5'b10001;
      // S (0x53)
      FONT5x7[{7'h53,3'd0}] = 5'b11111; FONT5x7[{7'h53,3'd1}] = 5'b10000; FONT5x7[{7'h53,3'd2}] = 5'b10000;
      FONT5x7[{7'h53,3'd3}] = 5'b11111; FONT5x7[{7'h53,3'd4}] = 5'b00001; FONT5x7[{7'h53,3'd5}] = 5'b00001;
      FONT5x7[{7'h53,3'd6}] = 5'b11111;
      // T (0x54)
      FONT5x7[{7'h54,3'd0}] = 5'b11111; FONT5x7[{7'h54,3'd1}] = 5'b00100; FONT5x7[{7'h54,3'd2}] = 5'b00100;
      FONT5x7[{7'h54,3'd3}] = 5'b00100; FONT5x7[{7'h54,3'd4}] = 5'b00100; FONT5x7[{7'h54,3'd5}] = 5'b00100;
      FONT5x7[{7'h54,3'd6}] = 5'b00100;
      // U (0x55)
      FONT5x7[{7'h55,3'd0}] = 5'b10001; FONT5x7[{7'h55,3'd1}] = 5'b10001; FONT5x7[{7'h55,3'd2}] = 5'b10001;
      FONT5x7[{7'h55,3'd3}] = 5'b10001; FONT5x7[{7'h55,3'd4}] = 5'b10001; FONT5x7[{7'h55,3'd5}] = 5'b10001;
      FONT5x7[{7'h55,3'd6}] = 5'b01110;
      // V (0x56)
      FONT5x7[{7'h56,3'd0}] = 5'b10001; FONT5x7[{7'h56,3'd1}] = 5'b10001; FONT5x7[{7'h56,3'd2}] = 5'b10001;
      FONT5x7[{7'h56,3'd3}] = 5'b10001; FONT5x7[{7'h56,3'd4}] = 5'b01010; FONT5x7[{7'h56,3'd5}] = 5'b00100;
      FONT5x7[{7'h56,3'd6}] = 5'b00100;
      // X (0x58)
      FONT5x7[{7'h58,3'd0}] = 5'b10001; FONT5x7[{7'h58,3'd1}] = 5'b01010; FONT5x7[{7'h58,3'd2}] = 5'b00100;
      FONT5x7[{7'h58,3'd3}] = 5'b00100; FONT5x7[{7'h58,3'd4}] = 5'b00100; FONT5x7[{7'h58,3'd5}] = 5'b01010;
      FONT5x7[{7'h58,3'd6}] = 5'b10001;
      // '/' (0x2F)
      FONT5x7[{7'h2F,3'd0}] = 5'b00001;
      FONT5x7[{7'h2F,3'd1}] = 5'b00010;
      FONT5x7[{7'h2F,3'd2}] = 5'b00100;
      FONT5x7[{7'h2F,3'd3}] = 5'b01000;
      FONT5x7[{7'h2F,3'd4}] = 5'b10000;
      FONT5x7[{7'h2F,3'd5}] = 5'b00000;
      FONT5x7[{7'h2F,3'd6}] = 5'b00000;
      // Add any other letters you show (e.g., 'A','H','O','/' etc.) using your current shapes.
    end
    
    // ===== helper: map scaled rx,ry into 5x7 grid WITHOUT divides =====
    function automatic [2:0] __map_col5;
      input signed [6:0] rx; input [6:0] dW;
    begin
      // fast path for dW==5 (most of your labels)
      if (dW==7'd5) __map_col5 = rx[2:0];
      else begin
        // coarse banding (avoids /) - tweak if you use other widths
        if      (rx < (dW*1)/5) __map_col5 = 0;
        else if (rx < (dW*2)/5) __map_col5 = 1;
        else if (rx < (dW*3)/5) __map_col5 = 2;
        else if (rx < (dW*4)/5) __map_col5 = 3;
        else                    __map_col5 = 4;
      end
    end endfunction
    
    function automatic [2:0] __map_row7;
      input signed [5:0] ry; input [5:0] dH;
    begin
      if (dH==6'd7) __map_row7 = ry[2:0];
      else begin
        if      (ry < (dH*1)/7) __map_row7 = 0;
        else if (ry < (dH*2)/7) __map_row7 = 1;
        else if (ry < (dH*3)/7) __map_row7 = 2;
        else if (ry < (dH*4)/7) __map_row7 = 3;
        else if (ry < (dH*5)/7) __map_row7 = 4;
        else if (ry < (dH*6)/7) __map_row7 = 5;
        else                    __map_row7 = 6;
      end
    end endfunction
    
    // ----------------- DROP-IN draw_letter -----------------
    function draw_letter;
      input      [7:0] ch;     // ASCII, e.g. "D"
      input signed [6:0] rx;   // x - left_of_glyph
      input signed [5:0] ry;   // y - top_of_glyph
      input      [6:0] dW;     // glyph width  (usually 5)
      input      [5:0] dH;     // glyph height (usually 7)
      reg [4:0] row_bits;
      reg [2:0] col5, row7;
      reg [6:0] c7;
    begin
      if (rx<0 || ry<0 || rx>=$signed(dW) || ry>=$signed(dH)) begin
        draw_letter = 1'b0;
      end else begin
        c7     = ch[6:0];                 // 0..127
        row7   = __map_row7(ry, dH);      // 0..6
        col5   = __map_col5(rx, dW);      // 0..4
        row_bits = FONT5x7[{c7, row7}];   // 5 bits for that scanline
        draw_letter = row_bits[4 - col5]; // MSB is leftmost pixel
      end
    end
    endfunction
    
    // symbols
    function draw_plus;
        input signed [6:0] rel_x; input signed [5:0] rel_y;
        input [6:0] width; input [5:0] height; integer sx,sy;
        begin
            draw_plus=0;
            if(rel_x>=0 && rel_x<width && rel_y>=0 && rel_y<height) begin
                sx=(rel_x*5)/width; sy=(rel_y*7)/height;
                if (sx==2 || sy==3) draw_plus=1;
            end
        end
    endfunction
    function draw_minus;
        input signed [6:0] rel_x; input signed [5:0] rel_y;
        input [6:0] width; input [5:0] height; integer sy;
        begin
            draw_minus=0;
            if(rel_x>=0 && rel_x<width && rel_y>=0 && rel_y<height) begin
                sy=(rel_y*7)/height;
                if (sy==3) draw_minus=1;
            end
        end
    endfunction
    function draw_times; // '×' like an X
        input signed [6:0] rel_x; input signed [5:0] rel_y;
        input [6:0] width; input [5:0] height; integer sx,sy;
        begin
            draw_times=0;
            if(rel_x>=0 && rel_x<width && rel_y>=0 && rel_y<height) begin
                sx=(rel_x*5)/width; sy=(rel_y*7)/height;
                if (sx==sy || sx+sy==6) draw_times=1;
            end
        end
    endfunction
    function draw_equal; // '=' two lines
        input signed [6:0] rel_x; input signed [5:0] rel_y;
        input [6:0] width; input [5:0] height; integer sy;
        begin
            draw_equal=0;
            if(rel_x>=0 && rel_x<width && rel_y>=0 && rel_y<height) begin
                sy=(rel_y*7)/height;
                if (sy==2 || sy==5) draw_equal=1;
            end
        end
    endfunction
    

    // === FIXED-CELL 2-digit renderer (uses 5x7 digit), no divides ===
    function draw_int2_fixed;
      input signed [6:0] rx; 
      input signed [5:0] ry;
      input      [6:0] dW; 
      input      [5:0] dH;
      input      [6:0] kern; 
      input      [6:0] signw;
      input             is_neg;
      input      [3:0]  tens, ones;
      integer x_tens, x_ones;
      reg hit;
    begin
      draw_int2_fixed = 1'b0;
      if (rx < 0 || ry < 0 || ry >= $signed(dH)) begin end
      else begin
        hit    = 1'b0;
        x_tens = signw;
        x_ones = signw + dW + kern;
    
        // sign slot (tiny horizontal bar)
        if (is_neg && rx >= 0 && rx < $signed(signw)) begin
          if (ry >= ($signed(dH)>>1)-1 && ry <= ($signed(dH)>>1)+1) hit = 1'b1;
        end
        // tens (skip when zero)
        if (tens!=0 && rx >= x_tens && rx < x_tens + $signed(dW))
          if (draw_digit5x7(rx - x_tens, ry, dW, dH, tens)) hit = 1'b1;
        // ones
        if (rx >= x_ones && rx < x_ones + $signed(dW))
          if (draw_digit5x7(rx - x_ones, ry, dW, dH, ones)) hit = 1'b1;
    
        draw_int2_fixed = hit;
      end
    end
    endfunction
    
    // === OLD convenience renderer for small edit preview (uses divides) ===
    function draw_int2_val;
      input [6:0] rel_x; input [5:0] rel_y;
      input [6:0] dW;    input [5:0] dH;
      input [6:0] kern;  input [6:0] sign_w;
      input signed [7:0] value_in;
      integer v, absv, tens, ones;
      integer x_sign, x_tens, x_ones;
      reg hit;
    begin
      // clamp
      if (value_in >  99) v =  99;
      else if (value_in < -99) v = -99;
      else v = value_in;
    
      absv = (v<0)? -v : v;
      tens = absv/10;
      ones = absv%10;
    
      x_sign = 0;
      x_tens = sign_w;
      x_ones = sign_w + dW + kern;
    
      hit = 0;
      if (v<0 && rel_x>=x_sign && rel_x<x_sign+sign_w)
        if (draw_minus(rel_x - x_sign, rel_y, sign_w, dH)) hit = 1;
    
      if (tens>0 && rel_x>=x_tens && rel_x<x_tens+dW)
        if (draw_number(tens[3:0], rel_x-x_tens, rel_y, dW, dH)) hit = 1;
    
      if (rel_x>=x_ones && rel_x<x_ones+dW)
        if (draw_number(ones[3:0], rel_x-x_ones, rel_y, dW, dH)) hit = 1;
    
      draw_int2_val = hit;
    end
    endfunction
    
    // === draw 'X' exactly in the ONES slot for a 2-digit field ===
    // layout matches draw_int2_fixed positioning (sign | tens | ones)
    function draw_x_ones_fixed;
      input  signed [6:0] rel_x;
      input  signed [5:0] rel_y;
      input         [6:0] dW;
      input         [5:0] dH;
      input         [6:0] kern;
      input         [6:0] sign_w;
      integer x_ones;
      reg hit;
    begin
      draw_x_ones_fixed = 1'b0;
      if (rel_y < 0 || rel_y >= $signed(dH)) begin
        // out of vertical bounds
      end else begin
        // positions mirror draw_int2_fixed
        // tens starts at x_tens = sign_w
        // ones starts at x_ones = sign_w + dW + kern
        x_ones = sign_w + dW + kern;
    
        hit = 1'b0;
        // draw the 'X' only within the ones digit box (same width/height)
        if (rel_x >= x_ones && rel_x < x_ones + $signed(dW)) begin
          if (draw_letter("X", rel_x - x_ones, rel_y, dW, dH)) hit = 1'b1;
        end
        draw_x_ones_fixed = hit;
      end
    end
    endfunction

        // ======= Result layout (full-width, 4 tidy rows) =======
    localparam [6:0] R_DIGIT_W = 7'd7;  // big per-digit
    localparam [5:0] R_DIGIT_H = 6'd12;
    localparam [6:0] R_KERN    = 7'd3;
    localparam [6:0] R_SIGN_W  = 7'd3;
    localparam [6:0] R_CELL_W  = R_SIGN_W + R_DIGIT_W + R_KERN + R_DIGIT_W + 7'd2; // 24 px
    localparam [5:0] R_ROW_STEP= 6'd15;
    
    localparam [6:0] MARGIN_X  = 7'd2;
    localparam [6:0] OP_GAP    = 7'd6;    // space around operator
    localparam [6:0] EQ_GAP    = 7'd8;    // space after '='
    
    localparam [6:0] A_LEFT_X  = MARGIN_X;
    localparam [6:0] OP_X      = A_LEFT_X + (2*R_CELL_W) + 7'd3;
    localparam [6:0] B_LEFT_X  = OP_X + OP_GAP;
    
    localparam [6:0] EQ_X      = MARGIN_X;
    localparam [6:0] RES_LEFT_X= EQ_X + EQ_GAP + 7'd5;
    
    // Four tidy baselines
    localparam [5:0] RY0 = 6'd6;                   // A row 0 + op + B row 0
    localparam [5:0] RY1 = RY0 + R_ROW_STEP;       // A row 1 + op + B row 1
    localparam [5:0] RY2 = RY1 + 6'd14;             // small gap then "= result row 0"
    localparam [5:0] RY3 = RY2 + R_ROW_STEP;       // "= result row 1"

    // --- ADD THIS for the results screen BACK button (top-right) ---
    localparam [6:0] RES_BTN_W = 7'd28;
    localparam [5:0] RES_BTN_H = 6'd10;
    // beside result matrix instead of top-right corner
    localparam [6:0] RES_BTN_X = RES_LEFT_X + (2*R_CELL_W) + 7'd8; // move to right of result matrix
    localparam [5:0] RES_BTN_Y = 6'd27; 
    
    // --- Small text for bar labels (fits in 10px bar height) ---
    localparam [6:0] BAR_TXT_W = 7'd5;
    localparam [5:0] BAR_TXT_H = 6'd7;
    
    // Centered text anchors inside each bar
    wire [6:0] DEL_TX = BTN_DEL_X_CUR + (BTN_DEL_W - (3*BAR_TXT_W) - 2)/2;
    wire [5:0] DEL_TY = BTN_Y + (BTN_H - BAR_TXT_H)/2;
    
    
    wire [6:0] NXT_TX = BTN_NEXT_X + (BTN_W - (3*BAR_TXT_W) - 2)/2;
    wire [5:0] NXT_TY = BTN_Y + (BTN_H - BAR_TXT_H)/2;

    // Middle-line result baselines (align to BACK button row)
    localparam [5:0] MID_RY0 = RES_BTN_Y;                  // 27
    localparam [5:0] MID_RY1 = RES_BTN_Y + R_ROW_STEP;     // 27 + 15 = 42
        
    // Hover for the back button (cursor-space)
    wire hover_back_cur =
        (cursor_x >= RES_BTN_X && cursor_x < (RES_BTN_X + RES_BTN_W) &&
         cursor_y >= RES_BTN_Y && cursor_y < (RES_BTN_Y + RES_BTN_H));

    // symbol sizes inside rows
    localparam [6:0] R_SYM_W = 7'd8;
    localparam [5:0] R_SYM_H = 6'd12;
    
    // ---------- ADD result digits ----------
    wire signed [7:0] add00 = (matAdd[0][0] >  99) ?  99 : (matAdd[0][0] < -99 ? -99 : matAdd[0][0]);
    wire signed [7:0] add01 = (matAdd[0][1] >  99) ?  99 : (matAdd[0][1] < -99 ? -99 : matAdd[0][1]);
    wire signed [7:0] add10 = (matAdd[1][0] >  99) ?  99 : (matAdd[1][0] < -99 ? -99 : matAdd[1][0]);
    wire signed [7:0] add11 = (matAdd[1][1] >  99) ?  99 : (matAdd[1][1] < -99 ? -99 : matAdd[1][1]);
    
    wire [6:0] add_idx00 = (add00 < 0) ? -add00 : add00;
    wire [6:0] add_idx01 = (add01 < 0) ? -add01 : add01;
    wire [6:0] add_idx10 = (add10 < 0) ? -add10 : add10;
    wire [6:0] add_idx11 = (add11 < 0) ? -add11 : add11;

    
    wire [3:0] add_t00, add_o00, add_t01, add_o01, add_t10, add_o10, add_t11, add_o11;
    dec_bcd_rom add_bcd00(.clk(clk_pix), .idx(add_idx00), .tens(add_t00), .ones(add_o00));
    dec_bcd_rom add_bcd01(.clk(clk_pix), .idx(add_idx01), .tens(add_t01), .ones(add_o01));
    dec_bcd_rom add_bcd10(.clk(clk_pix), .idx(add_idx10), .tens(add_t10), .ones(add_o10));
    dec_bcd_rom add_bcd11(.clk(clk_pix), .idx(add_idx11), .tens(add_t11), .ones(add_o11));

    
    // ---------- SUB result digits ----------
    wire signed [7:0] sub00 = (matSub[0][0] >  99) ?  99 : (matSub[0][0] < -99 ? -99 : matSub[0][0]);
    wire signed [7:0] sub01 = (matSub[0][1] >  99) ?  99 : (matSub[0][1] < -99 ? -99 : matSub[0][1]);
    wire signed [7:0] sub10 = (matSub[1][0] >  99) ?  99 : (matSub[1][0] < -99 ? -99 : matSub[1][0]);
    wire signed [7:0] sub11 = (matSub[1][1] >  99) ?  99 : (matSub[1][1] < -99 ? -99 : matSub[1][1]);
    
    wire [6:0] sub_idx00 = (sub00 < 0) ? -sub00 : sub00;
    wire [6:0] sub_idx01 = (sub01 < 0) ? -sub01 : sub01;
    wire [6:0] sub_idx10 = (sub10 < 0) ? -sub10 : sub10;
    wire [6:0] sub_idx11 = (sub11 < 0) ? -sub11 : sub11;

    wire [3:0] sub_t00, sub_o00, sub_t01, sub_o01, sub_t10, sub_o10, sub_t11, sub_o11;
    dec_bcd_rom sub_bcd00(.clk(clk_pix), .idx(sub_idx00), .tens(sub_t00), .ones(sub_o00));
    dec_bcd_rom sub_bcd01(.clk(clk_pix), .idx(sub_idx01), .tens(sub_t01), .ones(sub_o01));
    dec_bcd_rom sub_bcd10(.clk(clk_pix), .idx(sub_idx10), .tens(sub_t10), .ones(sub_o10));
    dec_bcd_rom sub_bcd11(.clk(clk_pix), .idx(sub_idx11), .tens(sub_t11), .ones(sub_o11));

    
    // ---------- MUL result digits ----------
    wire signed [7:0] mul00 = (matMul[0][0] >  99) ?  99 : (matMul[0][0] < -99 ? -99 : matMul[0][0]);
    wire signed [7:0] mul01 = (matMul[0][1] >  99) ?  99 : (matMul[0][1] < -99 ? -99 : matMul[0][1]);
    wire signed [7:0] mul10 = (matMul[1][0] >  99) ?  99 : (matMul[1][0] < -99 ? -99 : matMul[1][0]);
    wire signed [7:0] mul11 = (matMul[1][1] >  99) ?  99 : (matMul[1][1] < -99 ? -99 : matMul[1][1]);
    
    wire [6:0] mul_idx00 = (mul00 < 0) ? -mul00 : mul00;
    wire [6:0] mul_idx01 = (mul01 < 0) ? -mul01 : mul01;
    wire [6:0] mul_idx10 = (mul10 < 0) ? -mul10 : mul10;
    wire [6:0] mul_idx11 = (mul11 < 0) ? -mul11 : mul11;

    wire [3:0] mul_t00, mul_o00, mul_t01, mul_o01, mul_t10, mul_o10, mul_t11, mul_o11;
    dec_bcd_rom mul_bcd00(.clk(clk_pix), .idx(mul_idx00), .tens(mul_t00), .ones(mul_o00));
    dec_bcd_rom mul_bcd01(.clk(clk_pix), .idx(mul_idx01), .tens(mul_t01), .ones(mul_o01));
    dec_bcd_rom mul_bcd10(.clk(clk_pix), .idx(mul_idx10), .tens(mul_t10), .ones(mul_o10));
    dec_bcd_rom mul_bcd11(.clk(clk_pix), .idx(mul_idx11), .tens(mul_t11), .ones(mul_o11));
    
    // ---------- DET scalar digits ----------
    wire signed [7:0] detv      = (det_val >  99) ?  99 :
                                   (det_val < -99 ? -99 : det_val);
    wire        [6:0]  det_mag11 = detv[7] ? -detv : detv; // absolute value (11-bit signed abs)
    // detv is already clamped to -99..99
    wire [6:0] det_idx = (detv < 0) ? -detv : detv;
    wire [3:0] det_t, det_o;
    dec_bcd_rom det_bcd(.clk(clk_pix), .idx(det_idx), .tens(det_t), .ones(det_o));

    // ---------- ADJ matrix digits ----------
    wire signed [7:0] adj00 = (adj[0][0] >  99) ?  99 : (adj[0][0] < -99 ? -99 : adj[0][0]);
    wire signed [7:0] adj01 = (adj[0][1] >  99) ?  99 : (adj[0][1] < -99 ? -99 : adj[0][1]);
    wire signed [7:0] adj10 = (adj[1][0] >  99) ?  99 : (adj[1][0] < -99 ? -99 : adj[1][0]);
    wire signed [7:0] adj11 = (adj[1][1] >  99) ?  99 : (adj[1][1] < -99 ? -99 : adj[1][1]);
    
    wire [6:0] adj_idx00 = (adj00 < 0) ? -adj00 : adj00;
    wire [6:0] adj_idx01 = (adj01 < 0) ? -adj01 : adj01;
    wire [6:0] adj_idx10 = (adj10 < 0) ? -adj10 : adj10;
    wire [6:0] adj_idx11 = (adj11 < 0) ? -adj11 : adj11;
    
    wire [3:0] adj_t00, adj_o00, adj_t01, adj_o01, adj_t10, adj_o10, adj_t11, adj_o11;
    dec_bcd_rom adj_bcd00(.clk(clk_pix), .idx(adj_idx00), .tens(adj_t00), .ones(adj_o00));
    dec_bcd_rom adj_bcd01(.clk(clk_pix), .idx(adj_idx01), .tens(adj_t01), .ones(adj_o01));
    dec_bcd_rom adj_bcd10(.clk(clk_pix), .idx(adj_idx10), .tens(adj_t10), .ones(adj_o10));
    dec_bcd_rom adj_bcd11(.clk(clk_pix), .idx(adj_idx11), .tens(adj_t11), .ones(adj_o11));

    // ===== OVERFLOW FLAGS (>99 or <-99) =====
wire add_ov00 = (matAdd[0][0] >  99) || (matAdd[0][0] < -99);
wire add_ov01 = (matAdd[0][1] >  99) || (matAdd[0][1] < -99);
wire add_ov10 = (matAdd[1][0] >  99) || (matAdd[1][0] < -99);
wire add_ov11 = (matAdd[1][1] >  99) || (matAdd[1][1] < -99);

wire sub_ov00 = (matSub[0][0] >  99) || (matSub[0][0] < -99);
wire sub_ov01 = (matSub[0][1] >  99) || (matSub[0][1] < -99);
wire sub_ov10 = (matSub[1][0] >  99) || (matSub[1][0] < -99);
wire sub_ov11 = (matSub[1][1] >  99) || (matSub[1][1] < -99);

wire mul_ov00 = (matMul[0][0] >  99) || (matMul[0][0] < -99);
wire mul_ov01 = (matMul[0][1] >  99) || (matMul[0][1] < -99);
wire mul_ov10 = (matMul[1][0] >  99) || (matMul[1][0] < -99);
wire mul_ov11 = (matMul[1][1] >  99) || (matMul[1][1] < -99);

wire det_ov   = (det_val       >  99) || (det_val       < -99);

wire adj_ov00 = (adj[0][0]     >  99) || (adj[0][0]     < -99);
wire adj_ov01 = (adj[0][1]     >  99) || (adj[0][1]     < -99);
wire adj_ov10 = (adj[1][0]     >  99) || (adj[1][0]     < -99);
wire adj_ov11 = (adj[1][1]     >  99) || (adj[1][1]     < -99);


    // =================================================
    // INPUT + STATE TRANSITIONS
    // =================================================
    wire in_ui_area = 1'b1;
    wire click_edge = (mouse_l && !prev_mouse_l && mouse_armed);

    // safe scale mouse to 96x64
    wire [6:0] mouse_x_7_pre = mouse_x[9:3];
    wire [8:0] mouse_x_9     = mouse_x[11:3];
    wire [6:0] mouse_x_7     = (mouse_x_9 >= 9'd96) ? 7'd95 : mouse_x_7_pre;

    wire [5:0] mouse_y_6_pre = mouse_y[8:3];
    wire [8:0] mouse_y_9     = mouse_y[11:3];
    wire [5:0] mouse_y_6     = (mouse_y_9 >= 9'd64) ? 6'd63 : mouse_y_6_pre;

// --- hover regions now gated to edit screens only ---
    wire hover_next_cur =
  (any_edit_A || any_edit_B || any_edit_DETADJ) &&
  (cursor_y >= BTN_Y && cursor_y < BTN_Y + BTN_H) &&
  (cursor_x >= BTN_NEXT_X && cursor_x < BTN_NEXT_X + BTN_W);
    wire hover_ok_curr;
    wire hover_neg_curr;
    
    // hover region (cursor space). No fancy hover tint; just hit-test.
    wire hover_del_cur =
      (any_edit_A || any_edit_B || any_edit_DETADJ) &&
      (cursor_y >= BTN_Y && cursor_y < BTN_Y + BTN_H) &&
      (cursor_x >= BTN_DEL_X && cursor_x < BTN_DEL_X + BTN_DEL_W);
    
    // simple draw predicate for DEL (matches your next_on style)
    wire del_on =
      (any_edit_A || any_edit_B || any_edit_DETADJ) &&
      (y >= BTN_Y && y < BTN_Y + BTN_H) &&
      (x >= BTN_DEL_X && x < BTN_DEL_X + BTN_DEL_W);
    wire [15:0] pix_del_rect = C_YELLOW;
    
    // Small centered "DEL" label
    wire del_label_on =
      (any_edit_A || any_edit_B || any_edit_DETADJ) &&
      (draw_letter("D",
        x-(BTN_DEL_X + ((BTN_DEL_W - (3*BAR_TXT_W) - 2)/2) + 7'd2),
        y-(BTN_Y     + ((BTN_H     -  BAR_TXT_H)     /2)),
        BAR_TXT_W, BAR_TXT_H) ||
       draw_letter("E",
        x-(BTN_DEL_X + ((BTN_DEL_W - (3*BAR_TXT_W) - 2)/2) + (BAR_TXT_W+1) + 7'd2),
        y-(BTN_Y     + ((BTN_H     -  BAR_TXT_H)     /2)),
        BAR_TXT_W, BAR_TXT_H) ||
       draw_letter("L",
        x-(BTN_DEL_X + ((BTN_DEL_W - (3*BAR_TXT_W) - 2)/2) + 2*(BAR_TXT_W+1) + 7'd2),
        y-(BTN_Y     + ((BTN_H     -  BAR_TXT_H)     /2)),
        BAR_TXT_W, BAR_TXT_H));
    
    // MAIN MENU rectangles
    localparam [6:0] MENU_W = 7'd84;
    localparam [5:0] MENU_H = 6'd10;
    localparam [6:0] MENU_X = 7'd6;
    localparam [5:0] MENU_Y1 = 6'd18; // ARITHMETIC
    localparam [5:0] MENU_Y2 = 6'd34; // (unused slot now)
    localparam [5:0] MENU_Y3 = 6'd50; // (unused slot now)
    
    // colors
    localparam [15:0] C_WHITE = 16'hFFFF;
    localparam [15:0] C_BLACK = 16'h0000;
    localparam [15:0] C_GREY  = 16'h7BEF;
    localparam [15:0] C_GREEN = 16'h07E0; //next

    // ARITHMETIC SUBMENU rectangles
    localparam [6:0] ARM_W = 7'd30;
    localparam [5:0] ARM_H = 6'd10;
    localparam [6:0] ARM_X = 7'd6;
    localparam [5:0] ARM_Y1 = 6'd18; // ADD
    localparam [5:0] ARM_Y2 = 6'd32; // SUB
    localparam [5:0] ARM_Y3 = 6'd46; // MUL
    
    
    // BACK button (for arithmetic mode ? main menu)
    localparam [6:0] ARM_BACK_W = 7'd28;
    localparam [5:0] ARM_BACK_H = 6'd10;
    localparam [6:0] ARM_BACK_X = 7'd96 - ARM_BACK_W - 7'd2;
    localparam [5:0] ARM_BACK_Y = 6'd27;

    // menu hovers
    wire menu_row1_cur = (cursor_x>=MENU_X && cursor_x<MENU_X+MENU_W && cursor_y>=MENU_Y1 && cursor_y<MENU_Y1+MENU_H);
    wire menu_row2_cur = (cursor_x>=MENU_X && cursor_x<MENU_X+MENU_W &&
                          cursor_y>=MENU_Y2 && cursor_y<MENU_Y2+MENU_H);
    wire menu_row3_cur = (cursor_x>=MENU_X && cursor_x<MENU_X+MENU_W &&
                          cursor_y>=MENU_Y3 && cursor_y<MENU_Y3+MENU_H);
    
    // hover effect                      
    wire arm_row1_cur  = (cursor_x>=ARM_X && cursor_x<ARM_X+ARM_W+7'd20 && cursor_y>=ARM_Y1 && cursor_y<ARM_Y1+ARM_H);
    wire arm_row2_cur  = (cursor_x>=ARM_X && cursor_x<ARM_X+ARM_W+7'd20 && cursor_y>=ARM_Y2 && cursor_y<ARM_Y2+ARM_H);
    wire arm_row3_cur  = (cursor_x>=ARM_X && cursor_x<ARM_X+ARM_W+7'd20 && cursor_y>=ARM_Y3 && cursor_y<ARM_Y3+ARM_H);

    // cursor + input
    always @(posedge clk) begin

        // mouse dominates
        cursor_x <= mouse_x_7;
        cursor_y <= mouse_y_6;
        
        // simple edge-detects
      prev_mouse_l <= mouse_l;

        // MAIN MENU clicks
        if (ui_state==ST_MENU && click_edge) begin
            if (menu_row1_cur) begin                // ARITHMETIC
                ui_state <= ST_AR_MENU; mouse_armed <= 0;
            end else if (menu_row2_cur) begin       // DET/ADJ submenu
                ui_state <= ST_DET_MENU; mouse_armed <= 0;
            end else if (menu_row3_cur) begin       // INV placeholder
                ui_state <= ST_INV_EDIT; mouse_armed <= 0;
                row <= 0; col <= 0; acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;
                for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                    matA[m][n] <= 0; matA_saved[m][n] <= 0;
                    adj[m][n]  <= 0;
                    end
                    det_val <= 0;
            end
        end

        
        // BACK click ? return to main menu
        if (ui_state==ST_AR_MENU && click_edge &&
            cursor_x>=ARM_BACK_X && cursor_x<ARM_BACK_X+ARM_BACK_W &&
            cursor_y>=ARM_BACK_Y && cursor_y<ARM_BACK_Y+ARM_BACK_H) begin
            ui_state <= ST_MENU;
            mouse_armed <= 0;
        end
        
        // ----- DET/ADJ SUBMENU clicks -----
        if (ui_state==ST_DET_MENU && click_edge) begin
          // back to AR menu
          if (cursor_x>=DAM_BACK_X && cursor_x<DAM_BACK_X+DAM_BACK_W &&
              cursor_y>=DAM_BACK_Y && cursor_y<DAM_BACK_Y+DAM_BACK_H) begin
            ui_state <= ST_MENU; mouse_armed <= 0;
          end
        
          // DET
          if (dam_row1_cur) begin
            ui_state <= ST_DET_EDIT; row <= 0; col <= 0;
            acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;
            for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
              matA[m][n] <= 0; matA_saved[m][n] <= 0;
            end
            mouse_armed <= 0;
          end
        
          // ADJ
          if (dam_row2_cur) begin
            ui_state <= ST_ADJ_EDIT; row <= 0; col <= 0;
            acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;
            for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
              matA[m][n] <= 0; matA_saved[m][n] <= 0;
              adj[m][n]  <= 0;
            end
            mouse_armed <= 0;
          end
        end
        // ARITHMETIC SUBMENU clicks
        if (ui_state==ST_AR_MENU && click_edge) begin
            if (arm_row1_cur) begin // ADD
                ui_state <= ST_AR_ADD_A; row <= 0; col <= 0;
                acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;// <--- Patch A here
                for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                    matA[m][n] <= 0; matA_saved[m][n] <= 0; matB[m][n] <= 0;
                    matAdd[m][n] <= 0; matSub[m][n] <= 0; matMul[m][n] <= 0;
                end
                mouse_armed <= 0;
            end else if (arm_row2_cur) begin // SUB
                ui_state <= ST_AR_SUB_A; row <= 0; col <= 0;
                acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;// <--- Patch A here
                for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                    matA[m][n] <= 0; matA_saved[m][n] <= 0; matB[m][n] <= 0;
                    matAdd[m][n] <= 0; matSub[m][n] <= 0; matMul[m][n] <= 0;
                end
                mouse_armed <= 0;
            end else if (arm_row3_cur) begin // MUL
                ui_state <= ST_AR_MUL_A; row <= 0; col <= 0;
                acc_mag <= 0; acc_cnt <= 0; acc_neg <=0;// <--- Patch A here
                for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                    matA[m][n] <= 0; matA_saved[m][n] <= 0; matB[m][n] <= 0;
                    matAdd[m][n] <= 0; matSub[m][n] <= 0; matMul[m][n] <= 0;
                end
                mouse_armed <= 0;
            end
        end


        // keypad entry in edit A/B: accumulate up to 2 digits
        if ((any_edit_A || any_edit_B || any_edit_DETADJ) && click_edge) begin
          for(i=0;i<=9;i=i+1) begin
            if (cursor_x>=pos_x[i] && cursor_x<pos_x[i]+DIGIT_W &&
                cursor_y>=pos_y[i] && cursor_y<pos_y[i]+DIGIT_H) begin
              if (acc_cnt < 2) begin
                  acc_mag <= (acc_cnt == 0) ? i[6:0]
                           : (((acc_mag*10)+i[6:0]) > 7'd99 ? 7'd99 : (acc_mag*10 + i[6:0]));
                  acc_cnt <= acc_cnt + 1;
                end
            end
          end
          mouse_armed <= 0;
        end
        
        // RNG click -> write into focused cell (no preview buffer writes)
        // RNG click -> write into focused cell (no preview buffer writes)
        if (click_edge && hover_rng_cur) begin
          if (any_edit_A || any_edit_DETADJ) matA[row][col] <= $signed(rng_pm63);
          else if (any_edit_B)               matB[row][col] <= $signed(rng_pm63);
        
          // preview buffer mirrors the RNG value
          acc_mag <= (rng_pm63 < 0) ? -rng_pm63[6:0] : rng_pm63[6:0];
          acc_neg <= (rng_pm63 < 0);
          acc_cnt <= 2'd2;  // treat as a full 2-digit entry
          mouse_armed <= 1'b0;
        end

        
        // NEG click: toggle sign in the buffer
        if (click_edge && hover_neg_curr && (any_edit_A || any_edit_B || any_edit_DETADJ)) begin
          acc_neg     <= ~acc_neg;
          mouse_armed <= 1'b0;
        end
       
        
        // OK commit (mouse)
        if (click_edge && hover_ok_curr && (any_edit_A || any_edit_B || any_edit_DETADJ)) begin
            // Only write if user actually typed something in the buffer
            if (acc_cnt != 0) begin
                if (any_edit_B) matB[row][col] <= acc_signed;
                else            matA[row][col] <= acc_signed;
            end
            // advance focus
            if (col==1) begin
                col <= 0;
                row <= (row==1) ? 0 : (row + 1);
            end else begin
                col <= col + 1;
            end
            // clear buffer for next cell
            acc_mag <= 0; acc_cnt <= 0; acc_neg <= 0;
            mouse_armed <= 0;
        end

        
        // delete bar
        if (click_edge && hover_del_cur && (any_edit_A || any_edit_B || any_edit_DETADJ)) begin
            if (any_edit_B)
                matB[row][col] <= 0;
            else
                matA[row][col] <= 0;
        
            acc_mag <= 0;
            acc_cnt <= 0;
            acc_neg <= 0;
            mouse_armed <= 1'b0;
        end

        // NEXT transitions (mouse) - only when hovering NEXT
        if (click_edge && hover_next_cur) begin
            case (ui_state)
                // ---------- A -> B ----------
                ST_AR_ADD_A: begin
                    // commit buffered A[row][col] if needed
                    if (acc_cnt != 0) matA[row][col] <= acc_signed;
        
                    // copy A to A_saved, but *use acc_val* for the focused cell in this cycle
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                        matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
        
                    ui_state <= ST_AR_ADD_B; row <= 0; col <= 0;
                    acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;     // reset buffer for B
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) matB[m][n] <= 0;
                end
        
                // ---------- B -> Result (ADD) ----------
                ST_AR_ADD_B: begin
                    // commit buffered B[row][col] if needed
                    if (acc_cnt != 0) matB[row][col] <= acc_signed;
        
                    // compute sum, but pick acc_val for focused B cell in this cycle
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                        sum_s = matA_saved[m][n]
                                + ((m==row && n==col && acc_cnt!=0) ? acc_signed : matB[m][n]);
                        matAdd[m][n] <= sum_s;
                    end
                    ui_state <= ST_AR_ADD_SUM;
                    acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;      // clear buffer after use
                end
        
                ST_AR_ADD_SUM: ui_state <= ST_AR_MENU;
        
                // ---------- SUB ----------
                ST_AR_SUB_A: begin
                    if (acc_cnt != 0) matA[row][col] <= acc_signed;
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                        matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
                    ui_state <= ST_AR_SUB_B; row <= 0; col <= 0;
                    acc_neg <= 0; acc_cnt <= 0; acc_neg<=0;
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) matB[m][n] <= 0;
                end
                ST_AR_SUB_B: begin
                    if (acc_cnt != 0) matB[row][col] <= acc_signed;
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) begin
                        diff_s = $signed({1'b0, matA_saved[m][n]})
                               - $signed({1'b0, ((m==row && n==col && acc_cnt!=0) ? acc_signed : matB[m][n])});
                        matSub[m][n] <= diff_s;
                    end
                    ui_state <= ST_AR_SUB_RES;
                    acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;
                end
                ST_AR_SUB_RES: ui_state <= ST_AR_MENU;
        
                // ---------- MUL ----------
                ST_AR_MUL_A: begin
                    if (acc_cnt != 0) matA[row][col] <= acc_signed;
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                        matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
                    ui_state <= ST_AR_MUL_B; row <= 0; col <= 0;
                    acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;
                    for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1) matB[m][n] <= 0;
                end
                ST_AR_MUL_B: begin
                    if (acc_cnt != 0) matB[row][col] <= acc_signed;
        
                    // Use acc_val for the focused B cell(s) on this cycle
                    p00 = matA_saved[0][0] * (((0==row)&&(0==col)&&acc_cnt!=0) ? acc_signed : matB[0][0])
                       + matA_saved[0][1] * (((1==row)&&(0==col)&&acc_cnt!=0) ? acc_signed : matB[1][0]);
                    p01 = matA_saved[0][0] * (((0==row)&&(1==col)&&acc_cnt!=0) ? acc_signed : matB[0][1])
                       + matA_saved[0][1] * (((1==row)&&(1==col)&&acc_cnt!=0) ? acc_signed : matB[1][1]);
                    p10 = matA_saved[1][0] * (((0==row)&&(0==col)&&acc_cnt!=0) ? acc_signed : matB[0][0])
                       + matA_saved[1][1] * (((1==row)&&(0==col)&&acc_cnt!=0) ? acc_signed : matB[1][0]);
                    p11 = matA_saved[1][0] * (((0==row)&&(1==col)&&acc_cnt!=0) ? acc_signed : matB[0][1])
                       + matA_saved[1][1] * (((1==row)&&(1==col)&&acc_cnt!=0) ? acc_signed : matB[1][1]);
        
                    matMul[0][0] <= p00; matMul[0][1] <= p01;
                    matMul[1][0] <= p10; matMul[1][1] <= p11;
                    ui_state <= ST_AR_MUL_RES;
                    acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;
                end
                ST_AR_MUL_RES: ui_state <= ST_AR_MENU;
                
                // ----- DET: EDIT -> RESULT -----
                ST_DET_EDIT: begin
                  if (acc_cnt != 0) matA[row][col] <= acc_signed;
                
                  // freeze A for this cycle
                  for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                    matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
                
                  // det = a*d - b*c
                  // [ANCHOR A] det = a*d - b*c  (keep sign; no zero-extension)
                  det_val <=
                    $signed((row==0&&col==0&&acc_cnt!=0)?acc_signed:matA[0][0]) *
                    $signed((row==1&&col==1&&acc_cnt!=0)?acc_signed:matA[1][1])
                  - $signed((row==0&&col==1&&acc_cnt!=0)?acc_signed:matA[0][1]) *
                    $signed((row==1&&col==0&&acc_cnt!=0)?acc_signed:matA[1][0]);

                  ui_state <= ST_DET_RES;
                  acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;
                end
                
                // ----- ADJ: EDIT -> RESULT -----
                ST_ADJ_EDIT: begin
                  if (acc_cnt != 0) matA[row][col] <= acc_signed;
                
                  // keep your "freeze" copy if you like (it doesn't drive the calc now)
                  for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                    matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
                
                  // adj([[a,b],[c,d]]) = [[ d, -b], [-c, a]]
                  // compute from *current* A, substituting acc_val for the focused cell this cycle
                  // [ANCHOR B] adj([[a,b],[c,d]]) = [[ d, -b], [-c, a]]
                  adj[0][0] <= $signed((row==1&&col==1&&acc_cnt!=0)?acc_signed:matA[1][1]);
                  adj[0][1] <= -$signed((row==0&&col==1&&acc_cnt!=0)?acc_signed:matA[0][1]);
                  adj[1][0] <= -$signed((row==1&&col==0&&acc_cnt!=0)?acc_signed:matA[1][0]);
                  adj[1][1] <=  $signed((row==0&&col==0&&acc_cnt!=0)?acc_signed:matA[0][0]);

                
                  ui_state <= ST_ADJ_RES;
                  acc_mag <= 0; acc_cnt <= 0; acc_neg <= 0;
                end

                
                // results -> submenu
                ST_DET_RES: ui_state <= ST_DET_MENU;
                ST_ADJ_RES: ui_state <= ST_DET_MENU;
                
                // ----- INV: EDIT -> RESULT -----
                ST_INV_EDIT: begin
                  if (acc_cnt != 0) matA[row][col] <= acc_signed;
                
                  // freeze A this cycle
                  for(m=0;m<2;m=m+1) for(n=0;n<2;n=n+1)
                    matA_saved[m][n] <= ((m==row && n==col && acc_cnt!=0) ? acc_signed : matA[m][n]);
                
                  // compute det(A) = a*d - b*c
                  det_val <=
                          $signed((row==0&&col==0&&acc_cnt!=0)?acc_signed:matA[0][0]) *
                          $signed((row==1&&col==1&&acc_cnt!=0)?acc_signed:matA[1][1])
                        - $signed((row==0&&col==1&&acc_cnt!=0)?acc_signed:matA[0][1]) *
                          $signed((row==1&&col==0&&acc_cnt!=0)?acc_signed:matA[1][0]);
                  
                  // compute adj(A) = [[ d, -b], [-c, a]]  (lightweight assigns)
                  // [ANCHOR B] adj([[a,b],[c,d]]) = [[ d, -b], [-c, a]]
                  adj[0][0] <= $signed((row==1&&col==1&&acc_cnt!=0)?acc_signed:matA[1][1]);
                  adj[0][1] <= -$signed((row==0&&col==1&&acc_cnt!=0)?acc_signed:matA[0][1]);
                  adj[1][0] <= -$signed((row==1&&col==0&&acc_cnt!=0)?acc_signed:matA[1][0]);
                  adj[1][1] <=  $signed((row==0&&col==0&&acc_cnt!=0)?acc_signed:matA[0][0]);

                
                  ui_state <= ST_INV_RES;
                  acc_mag <= 0; acc_cnt <= 0; acc_neg<=0;
                end
                
                // results -> submenu or main (choose where you want to land)
                ST_INV_RES: ui_state <= ST_MENU;

                default: ;
            endcase
            mouse_armed <= 0;
        end
        
        // BACK transitions (mouse) - only on results screens
        if (click_edge && hover_back_cur &&
            (ui_state==ST_AR_ADD_SUM || ui_state==ST_AR_SUB_RES || ui_state==ST_AR_MUL_RES
          || ui_state==ST_DET_RES    || ui_state==ST_ADJ_RES || ui_state==ST_INV_RES)) begin
          ui_state <= ST_MENU;
          mouse_armed <= 0;
        end

        // edge book-keeping
        prev_mouse_l <= mouse_l;
        if(!mouse_l)   mouse_armed <= 1'b1;
    end

    // =================================================
    // RENDER LAYERS
    // =================================================
    // -------- MAIN MENU layer --------
    reg menu_on; reg [15:0] pix_menu;
    always @(*) begin
        menu_on = 1'b0; pix_menu = 16'h0000;
        if (ui_state==ST_MENU) begin
            if (x>=MENU_X && x<MENU_X+MENU_W && y>=MENU_Y1 && y<MENU_Y1+MENU_H) begin
                menu_on = 1'b1; pix_menu = menu_row1_cur ? C_GREEN : C_GREY; // ARITHMETIC
            end
            if (x>=MENU_X && x<MENU_X+MENU_W && y>=MENU_Y2 && y<MENU_Y2+MENU_H) begin
                menu_on = 1'b1; pix_menu = menu_row2_cur ? C_GREEN : C_GREY; // DET/ADJ
            end
            if (x>=MENU_X && x<MENU_X+MENU_W && y>=MENU_Y3 && y<MENU_Y3+MENU_H) begin
                menu_on = 1'b1; pix_menu = menu_row3_cur ? C_GREEN : C_GREY; // INV
            end
        end
    end


    // main menu heading: "MATRIX MODE"
    wire menu_title_on =
        (ui_state==ST_MENU) && (
            draw_letter("M",x-10,y-5,5,7) ||
            draw_letter("A",x-16,y-5,5,7) ||
            draw_letter("T",x-22,y-5,5,7) ||
            draw_letter("R",x-28,y-5,5,7) ||
            draw_letter("I",x-34,y-5,5,7) ||
            draw_letter("X",x-40,y-5,5,7) ||
            draw_letter("M",x-52,y-5,5,7) ||
            draw_letter("O",x-58,y-5,5,7) ||
            draw_letter("D",x-64,y-5,5,7) ||
            draw_letter("E",x-70,y-5,5,7)
        );

    // main menu row label "ARITHMETIC"
    wire lbl_menu_arith = (ui_state==ST_MENU) && (
        draw_letter("A",x-(MENU_X+6), y-(MENU_Y1+2),5,7) ||
        draw_letter("R",x-(MENU_X+12),y-(MENU_Y1+2),5,7) ||
        draw_letter("I",x-(MENU_X+18),y-(MENU_Y1+2),5,7) ||
        draw_letter("T",x-(MENU_X+24),y-(MENU_Y1+2),5,7) ||
        draw_letter("H",x-(MENU_X+30),y-(MENU_Y1+2),5,7) ||
        draw_letter("M",x-(MENU_X+36),y-(MENU_Y1+2),5,7) ||
        draw_letter("E",x-(MENU_X+42),y-(MENU_Y1+2),5,7) ||
        draw_letter("T",x-(MENU_X+48),y-(MENU_Y1+2),5,7) ||
        draw_letter("I",x-(MENU_X+54),y-(MENU_Y1+2),5,7) ||
        draw_letter("C",x-(MENU_X+60),y-(MENU_Y1+2),5,7)
    );
    
    // "DET/ADJ" on row2
    wire lbl_menu_detadj_row = (ui_state==ST_MENU) && (
        draw_letter("D",x-(MENU_X+6),  y-(MENU_Y2+2),5,7) ||
        draw_letter("E",x-(MENU_X+12), y-(MENU_Y2+2),5,7) ||
        draw_letter("T",x-(MENU_X+18), y-(MENU_Y2+2),5,7) ||
        draw_letter("/",x-(MENU_X+24), y-(MENU_Y2+2),5,7) ||
        draw_letter("A",x-(MENU_X+30), y-(MENU_Y2+2),5,7) ||
        draw_letter("D",x-(MENU_X+36), y-(MENU_Y2+2),5,7) ||
        draw_letter("J",x-(MENU_X+42), y-(MENU_Y2+2),5,7)
    );
    
    // "INV" on row3
    wire lbl_menu_inv_row = (ui_state==ST_MENU) && (
        // INVERSE (5x7, +1px spacing ? +6 per char)
        draw_letter("I", x-(MENU_X+ 6), y-(MENU_Y3+2), 5,7) ||
        draw_letter("N", x-(MENU_X+12), y-(MENU_Y3+2), 5,7) ||
        draw_letter("V", x-(MENU_X+18), y-(MENU_Y3+2), 5,7) ||
        draw_letter("E", x-(MENU_X+24), y-(MENU_Y3+2), 5,7) ||
        draw_letter("R", x-(MENU_X+30), y-(MENU_Y3+2), 5,7) ||
        draw_letter("S", x-(MENU_X+36), y-(MENU_Y3+2), 5,7) ||
        draw_letter("E", x-(MENU_X+42), y-(MENU_Y3+2), 5,7)
    );


    // -------- ARITHMETIC SUBMENU layer --------
    reg armenu_on; reg [15:0] pix_armenu;
    always @(*) begin
        armenu_on = 1'b0; pix_armenu = 16'h0000;
        if (ui_state==ST_AR_MENU) begin
            if (x>=ARM_X && x<ARM_X+ARM_W+7'd20 && y>=ARM_Y1 && y<ARM_Y1+ARM_H) begin
                armenu_on = 1'b1; pix_armenu = arm_row1_cur ? C_GREEN : C_GREY; // ADD
            end
            if (x>=ARM_X && x<ARM_X+ARM_W+7'd20 && y>=ARM_Y2 && y<ARM_Y2+ARM_H) begin
                armenu_on = 1'b1; pix_armenu = arm_row2_cur ? C_GREEN : C_GREY; // SUB
            end
            if (x>=ARM_X && x<ARM_X+ARM_W+7'd20 && y>=ARM_Y3 && y<ARM_Y3+ARM_H) begin
                armenu_on = 1'b1; pix_armenu = arm_row3_cur ? C_GREEN : C_GREY; // MUL
            end
        end
    end
    
    
    // DET/ADJ submenu rectangles
    reg damenu_on; reg [15:0] pix_damenu;
    always @(*) begin
      damenu_on = 1'b0; pix_damenu = 16'h0000;
      if (ui_state==ST_DET_MENU) begin
        if (x>=DAM_X && x<DAM_X+DAM_W+7'd20 && y>=DAM_Y1 && y<DAM_Y1+DAM_H) begin
          damenu_on = 1'b1; pix_damenu = dam_row1_cur ? C_GREEN : C_GREY; // DET
        end
        if (x>=DAM_X && x<DAM_X+DAM_W+7'd20 && y>=DAM_Y2 && y<DAM_Y2+DAM_H) begin
          damenu_on = 1'b1; pix_damenu = dam_row2_cur ? C_GREEN : C_GREY; // ADJ
        end
      end
    end
    
    wire damenu_title_on = (ui_state==ST_DET_MENU) &&
      ( draw_letter("D",x-16,y-5,5,7) || draw_letter("E",x-22,y-5,5,7) || draw_letter("T",x-28,y-5,5,7)
     || draw_letter("/",x-34,y-5,5,7) || draw_letter("A",x-40,y-5,5,7) || draw_letter("D",x-46,y-5,5,7) || draw_letter("J",x-52,y-5,5,7));
    
    wire dam_lbl_det = (ui_state==ST_DET_MENU) &&
      (draw_letter("D",x-(DAM_X+18),y-(DAM_Y1+2),5,7) ||
       draw_letter("E",x-(DAM_X+24),y-(DAM_Y1+2),5,7) ||
       draw_letter("T",x-(DAM_X+30),y-(DAM_Y1+2),5,7));
    
    wire dam_lbl_adj = (ui_state==ST_DET_MENU) &&
      (draw_letter("A",x-(DAM_X+18),y-(DAM_Y2+2),5,7) ||
       draw_letter("D",x-(DAM_X+24),y-(DAM_Y2+2),5,7) ||
       draw_letter("J",x-(DAM_X+30),y-(DAM_Y2+2),5,7));
    
    wire dam_back_on =
      (ui_state==ST_DET_MENU) &&
      (x>=DAM_BACK_X && x<DAM_BACK_X+DAM_BACK_W && y>=DAM_BACK_Y && y<DAM_BACK_Y+DAM_BACK_H);
    wire dam_back_hover_cur =
        (ui_state==ST_DET_MENU) &&
        (cursor_x>=DAM_BACK_X && cursor_x<DAM_BACK_X+DAM_BACK_W) &&
        (cursor_y>=DAM_BACK_Y && cursor_y<DAM_BACK_Y+DAM_BACK_H);
    wire [15:0] pix_dam_back = dam_back_hover_cur ? C_GREEN: C_GREY;
    wire dam_back_label_on =
      (ui_state==ST_DET_MENU) &&
      (draw_letter("B",x-(DAM_BACK_X+7),y-(DAM_BACK_Y+2),5,7) ||
       draw_letter("A",x-(DAM_BACK_X+13),y-(DAM_BACK_Y+2),5,7) ||
       draw_letter("C",x-(DAM_BACK_X+19),y-(DAM_BACK_Y+2),5,7) ||
       draw_letter("K",x-(DAM_BACK_X+25),y-(DAM_BACK_Y+2),5,7));

         
    // BACK button drawing
     wire arm_back_on =
        (ui_state==ST_AR_MENU) &&
        (x>=ARM_BACK_X && x<ARM_BACK_X+ARM_BACK_W &&
         y>=ARM_BACK_Y && y<ARM_BACK_Y+ARM_BACK_H);
    wire arm_back_hover_cur =
           (ui_state==ST_AR_MENU) &&
           (cursor_x>=ARM_BACK_X && cursor_x<ARM_BACK_X+ARM_BACK_W) &&
           (cursor_y>=ARM_BACK_Y && cursor_y<ARM_BACK_Y+ARM_BACK_H);

    wire [15:0] pix_arm_back = arm_back_hover_cur ? C_GREEN: C_GREY;
    
    wire arm_back_label_on =
        (ui_state==ST_AR_MENU) &&
        (draw_letter("B",x-(ARM_BACK_X+7),y-(ARM_BACK_Y+2),5,7) ||
         draw_letter("A",x-(ARM_BACK_X+13),y-(ARM_BACK_Y+2),5,7) ||
         draw_letter("C",x-(ARM_BACK_X+19),y-(ARM_BACK_Y+2),5,7) ||
         draw_letter("K",x-(ARM_BACK_X+25),y-(ARM_BACK_Y+2),5,7)); 
    
    // arithmetic title
    wire armenu_title_on =
        (ui_state==ST_AR_MENU) && (
            draw_letter("A",x-16,y-5,5,7) ||
            draw_letter("R",x-22,y-5,5,7) ||
            draw_letter("I",x-28,y-5,5,7) ||
            draw_letter("T",x-34,y-5,5,7) ||
            draw_letter("H",x-40,y-5,5,7) ||
            draw_letter("M",x-46,y-5,5,7) ||
            draw_letter("E",x-52,y-5,5,7) ||
            draw_letter("T",x-58,y-5,5,7) ||
            draw_letter("I",x-64,y-5,5,7) ||
            draw_letter("C",x-70,y-5,5,7)
        );

    // submenu labels: "ADD", "SUB", "MUL"
    wire lbl_add = (ui_state==ST_AR_MENU) && (
        draw_letter("A",x-(ARM_X+18), y-(ARM_Y1+2),5,7) ||
        draw_letter("D",x-(ARM_X+24),y-(ARM_Y1+2),5,7) ||
        draw_letter("D",x-(ARM_X+30),y-(ARM_Y1+2),5,7)
    );
    wire lbl_sub = (ui_state==ST_AR_MENU) && (
        draw_letter("S",x-(ARM_X+18), y-(ARM_Y2+2),5,7) ||
        draw_letter("U",x-(ARM_X+24),y-(ARM_Y2+2),5,7) ||
        draw_letter("B",x-(ARM_X+30),y-(ARM_Y2+2),5,7)
    );
    wire lbl_mul = (ui_state==ST_AR_MENU) && (
        draw_letter("M",x-(ARM_X+18), y-(ARM_Y3+2),5,7) ||
        draw_letter("U",x-(ARM_X+24),y-(ARM_Y3+2),5,7) ||
        draw_letter("L",x-(ARM_X+30),y-(ARM_Y3+2),5,7)
    );

    wire is_result_screen =
    (ui_state==ST_AR_ADD_SUM) | (ui_state==ST_AR_SUB_RES) | (ui_state==ST_AR_MUL_RES) |
    (ui_state==ST_DET_RES)    | (ui_state==ST_ADJ_RES)    | (ui_state==ST_INV_RES);

    // ---- BACK button (top-right, grey) ----
    wire back_btn_on = is_result_screen &&
        (x>=RES_BTN_X && x<RES_BTN_X+RES_BTN_W && y>=RES_BTN_Y && y<RES_BTN_Y+RES_BTN_H);

    
    wire [15:0] pix_back_rect = hover_back_cur ? C_GREEN : C_GREY;  // grey fill for back button
    wire back_label_on =
        (ui_state==ST_AR_MENU || ui_state==ST_DET_MENU || is_result_screen) &&
        (
          // start at centered origin for 3 chars (3*BAR_TXT_W + 2 gaps)
          // startX = RES_BTN_X + ((RES_BTN_W - (3*BAR_TXT_W) - 2)/2)
          // startY = RES_BTN_Y + ((RES_BTN_H -  BAR_TXT_H)    /2)
          draw_letter("B",
            x-( RES_BTN_X + ((RES_BTN_W - (3*BAR_TXT_W) - 2)/2) ),
            y-( RES_BTN_Y + ((RES_BTN_H -  BAR_TXT_H)    /2) ),
            BAR_TXT_W, BAR_TXT_H) ||
      
          draw_letter("C",
            x-( RES_BTN_X + ((RES_BTN_W - (3*BAR_TXT_W) - 2)/2) + (BAR_TXT_W+1) ),
            y-( RES_BTN_Y + ((RES_BTN_H -  BAR_TXT_H)    /2) ),
            BAR_TXT_W, BAR_TXT_H) ||
      
          draw_letter("K",
            x-( RES_BTN_X + ((RES_BTN_W - (3*BAR_TXT_W) - 2)/2) + 2*(BAR_TXT_W+1) ),
            y-( RES_BTN_Y + ((RES_BTN_H -  BAR_TXT_H)    /2) ),
            BAR_TXT_W, BAR_TXT_H)
        );



    // -------- NEXT button visibility --------
    // use NEXT_X_ACTIVE for drawing
    wire next_on =
      (any_edit_A || any_edit_B || any_edit_DETADJ) &&
      (y >= BTN_Y && y < BTN_Y + BTN_H) &&
      (x >= BTN_NEXT_X && x < BTN_NEXT_X + BTN_W);
    
    wire [15:0] pix_next_rect = C_GREEN;
    
    wire next_label_on =
  (any_edit_A || any_edit_B || any_edit_DETADJ) &&
  ( draw_letter("N",
      x-(BTN_NEXT_X + ((BTN_W - (3*BAR_TXT_W) - 2)/2)),
      y-(BTN_Y      + ((BTN_H -  BAR_TXT_H)    /2)),
      BAR_TXT_W, BAR_TXT_H) ||
    draw_letter("X",
      x-(BTN_NEXT_X + ((BTN_W - (3*BAR_TXT_W) - 2)/2) + (BAR_TXT_W+1)),
      y-(BTN_Y      + ((BTN_H -  BAR_TXT_H)    /2)),
      BAR_TXT_W, BAR_TXT_H) ||
    draw_letter("T",
      x-(BTN_NEXT_X + ((BTN_W - (3*BAR_TXT_W) - 2)/2) + 2*(BAR_TXT_W+1)),
      y-(BTN_Y      + ((BTN_H -  BAR_TXT_H)    /2)),
      BAR_TXT_W, BAR_TXT_H) );
    

    
    // OK hover (cursor-space)
    assign hover_ok_curr = (cursor_x >= (pos_x_OK - KPAD) &&
         cursor_x <  (pos_x_OK - KPAD + OK_W) &&
         cursor_y >= (pos_y_OK - KPAD) &&
         cursor_y <  (pos_y_OK - KPAD + OK_H));
    // NEG hover (cursor-space)
    assign hover_neg_curr =
       (cursor_x >= (pos_x_NEG - KPAD) && cursor_x < (pos_x_NEG - KPAD + NEG_W) &&
        cursor_y >= (pos_y_NEG - KPAD) && cursor_y < (pos_y_NEG - KPAD + NEG_H));

                                  
    // unified light-blue keypad
    localparam [15:0] C_BASE   = 16'h7D9F;  // ? light blue (base)
    localparam [15:0] C_HOVER  = 16'hBDF7;  // hover highlight
    localparam [15:0] C_PRESS  = 16'h5C9F;  // darker when pressed
    localparam [15:0] C_BORDER = 16'h318C;  // border outline

    
    function [15:0] tint;
        input [15:0] base; input is_hover; input is_press;
        begin
            tint = base;
            if (is_hover) tint = C_HOVER;
            if (is_press) tint = C_PRESS;
        end
    endfunction

    function corner_cut;
        input [6:0] x_rel; input [5:0] y_rel; input [6:0] w; input [5:0] h;
        begin
            corner_cut = ((x_rel==0 && (y_rel==0 || y_rel==h-1)) ||
                          (x_rel==w-1 && (y_rel==0 || y_rel==h-1)));
        end
    endfunction

    reg keys_on; reg [15:0] pix_keys;
    reg [6:0] kx_l, kx_r; reg [5:0] ky_t, ky_b;
    reg hover, press, on_border, cut_corner_flag;
    reg [15:0] base_col;

    always @(*) begin
        keys_on = 1'b0; pix_keys = 16'h0000;

        if (any_edit) begin
            for(i=0;i<=9;i=i+1) begin
                kx_l = pos_x[i] - KPAD;
                ky_t = pos_y[i] - KPAD;
                kx_r = kx_l + KEY_W;
                ky_b = ky_t + KEY_H;

                hover = (cursor_x>=kx_l && cursor_x<kx_r && cursor_y>=ky_t && cursor_y<ky_b);
                press = hover && mouse_l;
                
                if (x>=kx_l && x<kx_r && y>=ky_t && y<ky_b) begin

                    base_col = C_BASE;

                    on_border = (x==kx_l || x==kx_r-1 || y==ky_t || y==ky_b-1);
                    cut_corner_flag = corner_cut(x-kx_l, y-ky_t, KEY_W, KEY_H);

                    keys_on = 1'b1;
                    if (!cut_corner_flag) begin
                        pix_keys = tint(base_col, hover, press);
                        if (on_border && !press) pix_keys = C_BORDER;
                    end else begin
                        pix_keys = 16'h0000;
                    end

                    if (draw_number(i[3:0],
                        x - (pos_x[i] + 1),
                        y - (pos_y[i] + 1),
                        DIGIT_W - 2, DIGIT_H - 2)) begin
                        pix_keys = C_WHITE;
                    end
               end
            end
            // --- OK button (single key, below '9') ---
            kx_l = pos_x_OK - KPAD;
            ky_t = pos_y_OK - KPAD;
            kx_r = kx_l + KEY_W;   // single-key width
            ky_b = ky_t + KEY_H;   // single-key height
            
            hover = (cursor_x>=kx_l && cursor_x<kx_r && cursor_y>=ky_t && cursor_y<ky_b);
            press = hover && mouse_l;
            
            if (x>=kx_l && x<kx_r && y>=ky_t && y<ky_b) begin
                base_col = C_BASE;
            
                on_border       = (x==kx_l || x==kx_r-1 || y==ky_t || y==ky_b-1);
                cut_corner_flag = corner_cut(x-kx_l, y-ky_t, KEY_W, KEY_H);
            
                keys_on = 1'b1;
                if (!cut_corner_flag) begin
                    pix_keys = tint(base_col, hover, press);
                    if (on_border && !press) pix_keys = C_BORDER;
                end else begin
                    pix_keys = 16'h0000;
                end 
            end
            
            // centered "OK" label inside button
            if (draw_letter("O", x-(pos_x_OK),  y-(pos_y_OK+3), 5,7) ||
                draw_letter("K", x-(pos_x_OK+6), y-(pos_y_OK+3), 5,7))
                pix_keys = C_WHITE;

            
            // --- NEG key (single key, below '8') ---
            kx_l = pos_x_NEG - KPAD;
            ky_t = pos_y_NEG - (KPAD-1);
            kx_r = kx_l + KEY_W;
            ky_b = ky_t + KEY_H-1;
            
            hover = (cursor_x>=kx_l && cursor_x<kx_r && cursor_y>=ky_t && cursor_y<ky_b);
            press = hover && mouse_l;
            
            if (x>=kx_l && x<kx_r && y>=ky_t && y<ky_b) begin
                base_col = C_BASE;
            
                on_border       = (x==kx_l || x==kx_r-1 || y==ky_t || y==ky_b-1);
                cut_corner_flag = corner_cut(x-kx_l, y-ky_t, KEY_W, KEY_H);
            
                keys_on = 1'b1;
                if (!cut_corner_flag) begin
                    pix_keys = tint(base_col, hover, press);
                    if (on_border && !press) pix_keys = C_BORDER;
                end else begin
                    pix_keys = 16'h0000;
                end
            
                // centered minus; small box so it looks crisp
                if (draw_minus(
                      x-(pos_x_NEG + ((DIGIT_W-6)>>1)),
                      y-(pos_y_NEG + ((DIGIT_H-6)>>1)),
                      6, 6)) begin
                    pix_keys = C_WHITE;
                end
            end
        end
    end
    
    // ======= matrix / result layer (results page only changed) =======
    reg matrix_on; reg [15:0] pix_matrix;
    reg signed [7:0] val_show;
    
    always @(*) begin
        matrix_on = 1'b0; pix_matrix = 16'h0000;
    
        // --- EDIT screens (unchanged) ---
        if (any_edit) begin
            for (m=0;m<2;m=m+1) begin
                for (n=0;n<2;n=n+1) begin
                    // B uses matB; A and DET/ADJ both use matA
                    if (any_edit_B)
                      val_show = ((row==m)&&(col==n)&& (acc_cnt!=0)) ? acc_signed : matB[m][n];
                    else
                      val_show = ((row==m)&&(col==n)&& (acc_cnt!=0)) ? acc_signed : matA[m][n];

                    if (draw_int2_val(x-(52+n*COL_STEP), y-(15+m*12), E_DIGIT_W, E_DIGIT_H, E_KERN, E_SIGN_W, val_show)) begin
                        matrix_on = 1'b1;
                        pix_matrix = ((row==m)&&(col==n)) ? 16'h07E0 : 16'hFFFF;
                    end
                end
            end
        end
    
        // --- ADD results: A,B operands + '+' + "= result" ---
        else if (ui_state==ST_AR_ADD_SUM) begin
        
          // '=' and result rows (middle line)
        if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin matrix_on=1; pix_matrix=C_WHITE; end
        
        // ADD result: show 'X' at ones slot when |value|>99, else 2-digit
        
        // row 0, col 0
        if ( (add_ov00 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!add_ov00 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                add00[7], add_t00, add_o00)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 0, col 1
        if ( (add_ov01 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!add_ov01 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                add01[7], add_t01, add_o01)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 0
        if ( (add_ov10 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!add_ov10 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                add10[7], add_t10, add_o10)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 1
        if ( (add_ov11 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!add_ov11 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                add11[7], add_t11, add_o11)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        end

        // --- SUB results: A,B operands + '-' + "= result" ---
        else if (ui_state==ST_AR_SUB_RES) begin
        
          // '= result' in middle
        if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin matrix_on=1; pix_matrix=C_WHITE; end
        
        // SUB result: show 'X' at ones slot when |value|>99, else 2-digit
        
        // row 0, col 0
        if ( (sub_ov00 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!sub_ov00 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                sub00[7], sub_t00, sub_o00)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 0, col 1
        if ( (sub_ov01 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!sub_ov01 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                sub01[7], sub_t01, sub_o01)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 0
        if ( (sub_ov10 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!sub_ov10 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                sub10[7], sub_t10, sub_o10)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 1
        if ( (sub_ov11 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!sub_ov11 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                sub11[7], sub_t11, sub_o11)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        end

    
        // --- MUL results: A,B operands + '×' + "= result" ---
        else if (ui_state==ST_AR_MUL_RES) begin
        
          // '= result' in middle
        if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin matrix_on=1; pix_matrix=C_WHITE; end
        
        // MUL result: show 'X' at ones slot when |value|>99, else 2-digit
        
        // row 0, col 0
        if ( (mul_ov00 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!mul_ov00 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                mul00[7], mul_t00, mul_o00)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 0, col 1
        if ( (mul_ov01 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!mul_ov01 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                mul01[7], mul_t01, mul_o01)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 0
        if ( (mul_ov10 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!mul_ov10 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                mul10[7], mul_t10, mul_o10)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 1
        if ( (mul_ov11 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!mul_ov11 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                mul11[7], mul_t11, mul_o11)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        end
        
        // --- DET result: scalar on middle line (same row as BACK) ---
        else if (ui_state==ST_DET_RES) begin
          // '=' on middle baseline
          if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin
            matrix_on = 1'b1; pix_matrix = C_WHITE;
          end
        
          // DET scalar: 'X' at ones slot when |det|>99, else 2-digit number
          if ( (det_ov && draw_x_ones_fixed(
                  $signed(x)-$signed(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
               (!det_ov && draw_int2_fixed(
                  $signed(x)-$signed(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                  detv[7], det_t, det_o)) ) begin
            matrix_on = 1'b1; pix_matrix = C_WHITE;
          end
        end

        // --- ADJ result: 2×2 matrix on rows RY2, RY3 ---
        else if (ui_state==ST_ADJ_RES) begin
          // '= adj' in middle two rows
        if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin matrix_on=1; pix_matrix=C_WHITE; end
        
        // ADJ result: 'X' at ones slot when |value|>99, else 2-digit
        
        // row 0, col 0
        if ( (adj_ov00 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!adj_ov00 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                adj00[7], adj_t00, adj_o00)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 0, col 1
        if ( (adj_ov01 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!adj_ov01 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY0),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                adj01[7], adj_t01, adj_o01)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 0
        if ( (adj_ov10 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!adj_ov10 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                adj10[7], adj_t10, adj_o10)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        
        // row 1, col 1
        if ( (adj_ov11 && draw_x_ones_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
             (!adj_ov11 && draw_int2_fixed(
                $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                $signed(y)-$signed(MID_RY1),
                R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                adj11[7], adj_t11, adj_o11)) ) begin
          matrix_on=1; pix_matrix=C_WHITE;
        end
        end
        
        // --- INV result: handle both invertible and non-invertible cases ---
        else if (ui_state==ST_INV_RES) begin
        
          // "=" baseline always drawn
          if (draw_equal(x-EQ_X, y-MID_RY0, R_SYM_W, R_SYM_H)) begin
            matrix_on = 1; pix_matrix = C_WHITE;
          end
        
          // --- Case 1: determinant == 0 (not invertible) ---
          if (det_val == 0) begin
            // Show "det = 0" slightly above
            if (draw_letter("D", x-(RES_LEFT_X+5),  y-(MID_RY0-16), 7,12) ||
                draw_letter("E", x-(RES_LEFT_X+12),  y-(MID_RY0-16), 7,12) ||
                draw_letter("T", x-(RES_LEFT_X+19), y-(MID_RY0-16), 7,12) ||
                draw_equal(     x-(RES_LEFT_X+26),  y-(MID_RY0-16), 7,12) ||
                draw_int2_fixed($signed(x)-(RES_LEFT_X+24),
                                $signed(y)-(MID_RY0-16),
                                7'd7,6'd12,7'd2,7'd5, 1'b0, 4'd0, 4'd0)) begin
              matrix_on = 1; pix_matrix = C_WHITE;
            end
        
            // show "= X" on the middle line to indicate not invertible
            if (draw_letter("X", x-(RES_LEFT_X+5), y-MID_RY0-2, 6,9)) begin
              matrix_on = 1; pix_matrix = C_WHITE;
            end
        
          end
          // --- Case 2: normal invertible matrix ---
          else begin
            // ADJ result: 'X' at ones slot when |value|>99, else 2-digit
          
          // row 0, col 0
          if ( (adj_ov00 && draw_x_ones_fixed(
                  $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
               (!adj_ov00 && draw_int2_fixed(
                  $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                  adj00[7], adj_t00, adj_o00)) ) begin
            matrix_on=1; pix_matrix=C_WHITE;
          end
          
          // row 0, col 1
          if ( (adj_ov01 && draw_x_ones_fixed(
                  $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
               (!adj_ov01 && draw_int2_fixed(
                  $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                  $signed(y)-$signed(MID_RY0),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                  adj01[7], adj_t01, adj_o01)) ) begin
            matrix_on=1; pix_matrix=C_WHITE;
          end
          
          // row 1, col 0
          if ( (adj_ov10 && draw_x_ones_fixed(
                  $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY1),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
               (!adj_ov10 && draw_int2_fixed(
                  $signed(x)-(RES_LEFT_X + 0*R_CELL_W),
                  $signed(y)-$signed(MID_RY1),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                  adj10[7], adj_t10, adj_o10)) ) begin
            matrix_on=1; pix_matrix=C_WHITE;
          end
          
          // row 1, col 1
          if ( (adj_ov11 && draw_x_ones_fixed(
                  $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                  $signed(y)-$signed(MID_RY1),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
               (!adj_ov11 && draw_int2_fixed(
                  $signed(x)-(RES_LEFT_X + 1*R_CELL_W),
                  $signed(y)-$signed(MID_RY1),
                  R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                  adj11[7], adj_t11, adj_o11)) ) begin
            matrix_on=1; pix_matrix=C_WHITE;
          end
        
            // "det = value" label above
            if (draw_letter("D", x-(RES_LEFT_X+5),  y-(MID_RY0-16), 7,11) ||
                draw_letter("E", x-(RES_LEFT_X+14),  y-(MID_RY0-16), 7,11) ||
                draw_letter("T", x-(RES_LEFT_X+23), y-(MID_RY0-16), 7,11) ||
                draw_equal(     x-(RES_LEFT_X+32),  y-(MID_RY0-16), 7,11)) begin
              matrix_on=1; pix_matrix=C_WHITE;
            end
            // DET scalar: 'X' at ones slot when |det|>99, else 2-digit number
            if ( (det_ov && draw_x_ones_fixed(
                    $signed(x)-$signed(RES_LEFT_X + 7'd41),
                    $signed(y)-$signed(MID_RY0-16),
                    R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W)) ||
                 (!det_ov && draw_int2_fixed(
                    $signed(x)-$signed(RES_LEFT_X + 7'd41),
                    $signed(y)-$signed(MID_RY0-16),
                    R_DIGIT_W, R_DIGIT_H, R_KERN, R_SIGN_W,
                    detv[7], det_t, det_o)) ) begin
              matrix_on = 1'b1; pix_matrix = C_WHITE;
            end
          end
        end
    end

    // cursor dot (always on top)
    wire cur_on = (x>=cursor_x-1 && x<=cursor_x+1 && y>=cursor_y-1 && y<=cursor_y+1);
    wire [15:0] pix_cur = 16'hF81F;


    // =================================================
    // FINAL BLEND (clocked to pixel clock to save LUTs)
    // =================================================
    reg [15:0] pix_out;
    
    always @(posedge clk_pix) begin
      // default
      pix_out <= 16'h0000;
    
      // remove the old blue-screen line:
      // if (ui_state==ST_INV_MODE) pix_out <= 16'h001F;
      
      
      if (cur_on)                                         pix_out <= 16'hF81F;
      
      else if (del_label_on) begin
        pix_out <= C_BLACK;   // black text on yellow DEL
      end
      else if (next_label_on) begin
        pix_out <= C_BLACK;   // black text on green NEXT
      end
      else if (back_label_on) begin
        pix_out <= C_BLACK;   // black on grey BACK
      end

      // MAIN MENU
      else if (menu_title_on)                             pix_out <= C_WHITE;
      else if (lbl_menu_arith)                            pix_out <= C_BLACK;
      else if (lbl_menu_detadj_row)                       pix_out <= C_BLACK;
      else if (lbl_menu_inv_row)                          pix_out <= C_BLACK;
      else if (menu_on)                                   pix_out <= pix_menu;
    
      // ARITH SUBMENU
      else if (armenu_title_on)                           pix_out <= C_WHITE;
      else if (lbl_add || lbl_sub || lbl_mul)             pix_out <= C_BLACK;
      else if (armenu_on)                                 pix_out <= pix_armenu;
      else if (arm_back_on)                               pix_out <= pix_arm_back;
      else if (arm_back_label_on)                         pix_out <= C_BLACK;
    
      // DET/ADJ SUBMENU
      else if (damenu_title_on)                           pix_out <= C_WHITE;
      else if (dam_lbl_det || dam_lbl_adj)                pix_out <= C_BLACK;
      else if (damenu_on)                                 pix_out <= pix_damenu;
      else if (dam_back_on)                               pix_out <= pix_dam_back;
      else if (dam_back_label_on)                         pix_out <= C_BLACK;
    
      // --- draw bars and bar labels BEFORE keypad so they are visible ---
      else if (del_on)                 pix_out <= hover_del_cur ? C_GREY: C_YELLOW;
     
      
      else if (next_on)                pix_out <= hover_next_cur ? C_GREY: C_GREEN;
      
      // RNG - draw label first so it isn't hidden by the button fill
      else if (rng_label_on)                 pix_out <= C_WHITE;      // "RNG" text on top
      else if (rng_on && hover_rng_cur)      pix_out <= C_GREEN;      // hover fill
      else if (rng_on)                       pix_out <= pix_rng_rect; // idle fill
      
      // now the keypad
      else if ((any_edit_A || any_edit_B || any_edit_DETADJ) && keys_on)
        pix_out <= pix_keys;

      // existing back/labels/matrix/next
      else if (back_btn_on)                      pix_out <= hover_back_cur ? C_GREEN : C_GREY;
      
      else if (matrix_on)                        pix_out <= pix_matrix;
      oled_data = pix_out; // update output reg every pixel clock
    end  
   
endmodule
