`timescale 1ns / 1ps

module userdata_module(
    input  [6:0] px, input [6:0] py, 
    input  [6:0] mx, input [6:0] my, 
    input  click_rise, input  middle_rise,
    input  clk_100M, input reset,
    input  [4:0] pb, input  enable, output reg [15:0] oled, output reg done,
    
    output reg signed [4:0] x0, output reg signed [4:0] y0,
    output reg signed [4:0] x1, output reg signed [4:0] y1,
    output reg signed [4:0] x2, output reg signed [4:0] y2
);

    localparam [15:0] WHITE = 16'b11111_111111_11111;
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] GREEN = 16'b00000_111111_00000;
    localparam [15:0] ORANGE = 16'b11111_101000_00000;

    localparam PB_UP = 1;
    localparam PB_DOWN = 4;
    localparam PB_RIGHT = 3;
    localparam PB_LEFT = 2;
    
    localparam [6:0] ORGX = 1, ORGY = 10, Y_STEP = 10;
    localparam [6:0] GW=6, GH=8;

    localparam [6:0] P0_Y = ORGY + 0*Y_STEP;
    localparam [6:0] P1_Y = ORGY + 1*Y_STEP;
    localparam [6:0] P2_Y = ORGY + 2*Y_STEP;

    // X positions for text fields, 8px per char
    localparam [6:0] LBL_X = ORGX; // "P0:("
    localparam [6:0] S_X_X = LBL_X + 4*8; // Sign of X
    localparam [6:0] M_X_X = S_X_X + 1*8; // Mag of X
    localparam [6:0] COM_X = M_X_X + 1*8; // ","
    localparam [6:0] S_Y_X = COM_X + 1*8; // Sign of Y
    localparam [6:0] M_Y_X = S_Y_X + 1*8; // Mag of Y

    reg [19:0] cnt; always @(posedge clk_100M or posedge reset) if (reset) cnt<=0; else cnt<=cnt+1;
    wire slow_tick = (cnt[17:0]==0);
    reg  [4:0] pb0,pb1,prev; wire [4:0] rise = pb1 & ~prev;
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin pb0<=0; pb1<=0; prev<=0; end
        else begin pb0 <= pb; pb1 <= pb0; if (slow_tick) prev <= pb1; end
    end

    reg s_x0, s_y0, s_x1, s_y1, s_x2, s_y2;
    reg [3:0] mag_x0, mag_y0, mag_x1, mag_y1, mag_x2, mag_y2;

    reg [4:0] sel; // 0..11

    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            s_x0 <= 0; s_y0 <= 0; s_x1 <= 0; s_y1 <= 0; s_x2 <= 0; s_y2 <= 0;
            mag_x0 <= 0; mag_y0 <= 0; mag_x1 <= 0; mag_y1 <= 0; mag_x2 <= 0; mag_y2 <= 0;
            sel <= 0;
        end else if (slow_tick) begin
            // Left/Right selection
            if (rise[PB_RIGHT]) sel <= (sel == 11) ? 0 : sel + 1;
            if (rise[PB_LEFT])  sel <= (sel == 0) ? 11 : sel - 1;

            // Up/Down editing
            if (rise[PB_UP] || rise[PB_DOWN]) begin
                case (sel)
                    0:  s_x0 <= ~s_x0;
                    2:  s_y0 <= ~s_y0;
                    4:  s_x1 <= ~s_x1;
                    6:  s_y1 <= ~s_y1;
                    8:  s_x2 <= ~s_x2;
                    10: s_y2 <= ~s_y2;
                    default: ;
                endcase
            end
            
            if (rise[PB_UP]) begin
                case (sel)
                    1:  mag_x0 <= (mag_x0 == 9) ? 0 : mag_x0 + 1;
                    3:  mag_y0 <= (mag_y0 == 9) ? 0 : mag_y0 + 1;
                    5:  mag_x1 <= (mag_x1 == 9) ? 0 : mag_x1 + 1;
                    7:  mag_y1 <= (mag_y1 == 9) ? 0 : mag_y1 + 1;
                    9:  mag_x2 <= (mag_x2 == 9) ? 0 : mag_x2 + 1;
                    11: mag_y2 <= (mag_y2 == 9) ? 0 : mag_y2 + 1;
                    default: ;
                endcase
            end
            
            if (rise[PB_DOWN]) begin
                case (sel)
                    1:  mag_x0 <= (mag_x0 == 0) ? 9 : mag_x0 - 1;
                    3:  mag_y0 <= (mag_y0 == 0) ? 9 : mag_y0 - 1;
                    5:  mag_x1 <= (mag_x1 == 0) ? 9 : mag_x1 - 1;
                    7:  mag_y1 <= (mag_y1 == 0) ? 9 : mag_y1 - 1;
                    9:  mag_x2 <= (mag_x2 == 0) ? 9 : mag_x2 - 1;
                    11: mag_y2 <= (mag_y2 == 0) ? 9 : mag_y2 - 1;
                    default: ;
                endcase
            end
        end
    end
    
    localparam integer NXL = 80; 
    localparam integer NXT = 55;
    localparam integer NXR = 95;
    localparam integer NXB = 63;
    wire in_nx = (px >= NXL) && (px <= NXR) && (py >= NXT) && (py <= NXB);
    wire mh_nx = (mx >= NXL) && (mx <= NXR) && (my >= NXT) && (my <= NXB);
    wire nx_border = in_nx && ((px==NXL)||(px==NXR)||(py==NXT)||(py==NXB));
    wire nx_fill = in_nx && !nx_border;
    wire nx_hover = nx_fill && mh_nx;

    always @(posedge clk_100M or posedge reset) begin
      if (reset) done <= 0;
      else if ((enable && click_rise && mh_nx) || done) done <= 1;
      else done <= 0;
    end
    
    wire cursor_on = enable && (
        (px == mx && py >= my-1 && py <= my+1) ||
        (py == my && px >= mx-1 && px <= mx+1)
    );
    
    wire [7:0] x0_ch="0"+mag_x0, y0_ch="0"+mag_y0;
    wire [7:0] x1_ch="0"+mag_x1, y1_ch="0"+mag_y1;
    wire [7:0] x2_ch="0"+mag_x2, y2_ch="0"+mag_y2;
    
    wire on_p0, on_p1, on_p2, on_p3, on_p4, on_next_txt, on_title;
    
    labels_lut #(.MAXLEN(16)) ttl(
      .clk(clk_100M), .px(px), .py(py), .sx(1), .sy(1),
      .text({ "ENTER 3 PTS", {(16-11){8'h00}} }), .on(on_title)
    );
    labels_lut #(.MAXLEN(16)) lab_p0(
      .clk(clk_100M), .px(px),.py(py),.sx(LBL_X), .sy(P0_Y), 
      .text({ "P0:(", s_x0 ? "-" : "+", x0_ch, ",", s_y0 ? "-" : "+", y0_ch, ")", {(16-10){8'h00}}}), .on(on_p0)
    );
    labels_lut #(.MAXLEN(16)) lab_p1(
      .clk(clk_100M), .px(px),.py(py),.sx(LBL_X), .sy(P1_Y), 
      .text({ "P1:(", s_x1 ? "-" : "+", x1_ch, ",", s_y1 ? "-" : "+", y1_ch, ")", {(16-10){8'h00}}}), .on(on_p1)
    );
    labels_lut #(.MAXLEN(16)) lab_p2(
      .clk(clk_100M), .px(px),.py(py),.sx(LBL_X), .sy(P2_Y), 
      .text({ "P2:(", s_x2 ? "-" : "+", x2_ch, ",", s_y2 ? "-" : "+", y2_ch, ")", {(16-10){8'h00}}}), .on(on_p2)
    );
    labels_lut #(.MAXLEN(16)) lab_next(
      .clk(clk_100M), .px(px), .py(py), .sx(NXL), .sy(NXT),
      .text({ "->", {(16-2){8'h00}}}), .on(on_next_txt)
    );

    function border_on; input [6:0] x,y,gx,gy; begin
        border_on = (x>=gx-1 && x<=gx+GW && y>=gy-1 && y<=gy+GH) &&
                    (x==gx-1 || x==gx+GW || y==gy-1 || y==gy+GH);
    end endfunction

    wire b_s_x0 = (sel ==  0) && border_on(px, py, S_X_X, P0_Y);
    wire b_m_x0 = (sel ==  1) && border_on(px, py, M_X_X, P0_Y);
    wire b_s_y0 = (sel ==  2) && border_on(px, py, S_Y_X, P0_Y);
    wire b_m_y0 = (sel ==  3) && border_on(px, py, M_Y_X, P0_Y);
    
    wire b_s_x1 = (sel ==  4) && border_on(px, py, S_X_X, P1_Y);
    wire b_m_x1 = (sel ==  5) && border_on(px, py, M_X_X, P1_Y);
    wire b_s_y1 = (sel ==  6) && border_on(px, py, S_Y_X, P1_Y);
    wire b_m_y1 = (sel ==  7) && border_on(px, py, M_Y_X, P1_Y);
    
    wire b_s_x2 = (sel ==  8) && border_on(px, py, S_X_X, P2_Y);
    wire b_m_x2 = (sel ==  9) && border_on(px, py, M_X_X, P2_Y);
    wire b_s_y2 = (sel == 10) && border_on(px, py, S_Y_X, P2_Y);
    wire b_m_y2 = (sel == 11) && border_on(px, py, M_Y_X, P2_Y);
    

    wire all_borders = b_s_x0 | b_m_x0 | b_s_y0 | b_m_y0 |
                       b_s_x1 | b_m_x1 | b_s_y1 | b_m_y1 |
                       b_s_x2 | b_m_x2 | b_s_y2 | b_m_y2;
                       
    wire all_text = on_p0 | on_p1 | on_p2;
    
    always @(*) begin
        if (!enable) oled = BLACK;
        else if (cursor_on) oled = ORANGE;
        else if (all_borders) oled = GREEN;
        else if (nx_border) oled = WHITE;
        else if (on_next_txt) oled = WHITE;
        else if (nx_hover) oled = GREEN;
        else if (nx_fill) oled = 16'b00001_000001_01000;
        else if (on_title) oled = ORANGE;
        else if (all_text) oled = WHITE;
        else oled = BLACK;
    end
    
    function signed [4:0] mag_to_signed; 
        input s; input [3:0] m; 
    begin
        mag_to_signed = s ? -$signed({1'b0, m}) : $signed({1'b0, m}); 
    end 
    endfunction
    
    always @(*) begin
        x0 = mag_to_signed(s_x0, mag_x0);
        y0 = mag_to_signed(s_y0, mag_y0);
        x1 = mag_to_signed(s_x1, mag_x1);
        y1 = mag_to_signed(s_y1, mag_y1);
        x2 = mag_to_signed(s_x2, mag_x2);
        y2 = mag_to_signed(s_y2, mag_y2);
    end

endmodule
