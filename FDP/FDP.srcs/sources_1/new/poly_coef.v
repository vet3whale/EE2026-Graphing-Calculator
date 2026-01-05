`timescale 1ns / 1ps

module poly_coef#(
    parameter integer STRLEN = 10,
    parameter [8*STRLEN-1:0] EQUATION = "EQUATION 1",
    parameter [16:0] COLOUR = 16'b11111_111111_11111
)(
    input  [6:0] x, input [6:0] y,
    input  [6:0] mx, input [6:0] my,
    input click_rise, input reset, input [4:0] pb,
    input enable,
    input clk_100M,
    input [2:0] degree,                    // 0: const, 1: linear, 2: quadratic, 3: cubic
    output reg [15:0] oled,
    output reg done,
    output reg signed [15:0] a, output reg signed [15:0] b,
    output reg signed [15:0] c, output reg signed [15:0] d
);
    localparam [15:0] WHITE = 16'b11111_111111_11111;
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] GREEN = 16'b00000_111111_00000;

    localparam PB_UP    = 1;
    localparam PB_DOWN  = 4;
    localparam PB_RIGHT = 3;
    localparam PB_LEFT  = 2;
    
    // NEXT button
    localparam integer NXL = 60;  localparam integer NXT = 50;
    localparam integer NXR = 92;  localparam integer NXB = 60;
    wire in_nx = (x >= NXL) && (x <= NXR) && (y >= NXT) && (y <= NXB);
    wire mh_nx = (mx >= NXL) && (mx <= NXR) && (my >= NXT) && (my <= NXB);
    wire nx_border = in_nx && ((x==NXL)||(x==NXR)||(y==NXT)||(y==NXB));
    wire nx_fill = in_nx && !nx_border;
    wire nx_hover = nx_fill && mh_nx;
    
    // Title text origin
    localparam integer TTLX = 6;
    localparam integer TTLY = 4;
    localparam integer OLED_W = 96;
    
    always @(posedge clk_100M or posedge reset) begin
      if (reset) done <= 1'b0;
      else if (enable && click_rise && mh_nx) done <= 1'b1; // only on click while over NEXT
    end

    wire ttl_on;
    labels_lut ttl(
      .clk(clk_100M), .px(x), .py(y), .sx(TTLX), .sy(TTLY),
      .text({ EQUATION, {(16-10){8'h00}} }), .on(ttl_on)
    );
    wire nx_text_on;
    labels_lut lab_next(
      .clk(clk_100M), .px(x), .py(y), .sx(NXL[6:0]), .sy(NXT[6:0]),
      .text({ "NEXT", {(16-4){8'h00}}}), .on(nx_text_on)
    );
    
    wire compute_x = (degree == 1);
    wire compute_x2 = (degree == 2);
    wire compute_x3 = (degree == 3);
    wire [15:0] x_oled, x2_oled, x3_oled;
    wire [3:0] x_c,  x_d;
    wire [3:0] x2_b, x2_c, x2_d;
    wire [3:0] x3_a, x3_b, x3_c, x3_d;
    wire x_sc, x_sd;                  // signs from module_x
    wire x2_sb, x2_sc, x2_sd;          // signs from module_x2
    wire x3_sa, x3_sb, x3_sc, x3_sd;   // signs from module_x3
    module_x xmod (.px(x), .py(y), .clk_100M(clk_100M), .reset(reset), .pb(pb),
                      .enable(compute_x), .oled(x_oled), .c(x_c), .d(x_d),
                      .s_c(x_sc), .s_d(x_sd));
    
    module_x2 x2mod ( .px(x), .py(y), .clk_100M(clk_100M), .reset(reset), .pb(pb),
                      .enable(compute_x2), .oled(x2_oled), .b(x2_b), .c(x2_c), .d(x2_d),
                      .s_b(x2_sb), .s_c(x2_sc), .s_d(x2_sd));
    
    module_x3 x3mod ( .px(x), .py(y), .clk_100M(clk_100M), .reset(reset), .pb(pb),
                      .enable(compute_x3), .oled(x3_oled), .a(x3_a), .b(x3_b), .c(x3_c), .d(x3_d),
                      .s_a(x3_sa), .s_b(x3_sb), .s_c(x3_sc), .s_d(x3_sd));
    function signed [15:0] mag16; input [3:0] m; begin mag16 = $signed({12'd0, m}); end endfunction                  
    always @(*) begin
        a = 16'sd0; b = 16'sd0; c = 16'sd0; d = 16'sd0;
        
        if (compute_x) begin
          c = x_sc ? -mag16(x_c) : mag16(x_c);
          d = x_sd ? -mag16(x_d) : mag16(x_d);
        end
        if (compute_x2) begin
          b = x2_sb ? -mag16(x2_b) : mag16(x2_b);
          c = x2_sc ? -mag16(x2_c) : mag16(x2_c);
          d = x2_sd ? -mag16(x2_d) : mag16(x2_d);
        end
        if (compute_x3) begin
          a = x3_sa ? -mag16(x3_a) : mag16(x3_a);
          b = x3_sb ? -mag16(x3_b) : mag16(x3_b);
          c = x3_sc ? -mag16(x3_c) : mag16(x3_c);
          d = x3_sd ? -mag16(x3_d) : mag16(x3_d);
        end
    end
    always @(*) begin
        oled = BLACK;
        if (enable) begin
            // equations
            if (compute_x) oled = x_oled;
            if (compute_x2) oled = x2_oled;
            if (compute_x3) oled = x3_oled;
            
            // title
            if (ttl_on) oled = COLOUR;

            // borders
            if (nx_border) oled = WHITE;

            if (nx_hover) oled = GREEN;
            else if (nx_fill && (oled==BLACK)) oled = 16'b00001_000001_01000;

            // text
            if (nx_text_on) oled = WHITE;
            
        end
    end
endmodule

module module_x (
    input  [6:0] px, input [6:0] py,
    input clk_100M, input reset,
    input [4:0] pb,
    input enable,
    output reg [15:0] oled,
    output reg [3:0] c, output reg [3:0] d,
    output reg s_c, output reg s_d
);
    // Colors
    localparam [15:0] WHITE = 16'b11111_111111_11111;
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] GREEN = 16'b00000_111111_00000;

    // PB mapping
    localparam PB_UP    = 1;
    localparam PB_DOWN  = 4;
    localparam PB_RIGHT = 3;
    localparam PB_LEFT  = 2;

    // Layout
    localparam [6:0] ORGX=1, ORGY=30, ADV=8, GW=6, GH=8;
    // positions: a,"x^3"," + ", b,"x^2"," + ", c,"x"," + ", d
    localparam [6:0] CX=ORGX+3;
    localparam [6:0] XX=CX+ADV;
    localparam [6:0] P3 =XX+ADV;
    localparam [6:0] DX=P3+ADV;

    // safe minus positions (clamped to screen left)
    localparam integer SHIFT = 6;
    localparam [6:0] CXM = (CX > SHIFT) ? (CX - SHIFT) : 7'd0;
    localparam [6:0] DXM = (DX > SHIFT) ? (DX - SHIFT) : 7'd0;

    // Debounce / one-pulse
    reg [19:0] cnt; always @(posedge clk_100M or posedge reset) if (reset) cnt<=0; else cnt<=cnt+1;
    wire slow_tick = (cnt[17:0]==0);
    reg  [4:0] pb0,pb1,prev; wire [4:0] rise = pb1 & ~prev;
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin pb0<=0; pb1<=0; prev<=0; end
        else begin pb0 <= pb; pb1 <= pb0; if (slow_tick) prev <= pb1; end
    end

    // selection: 0->sign(c), 1->c, 2->sign(d), 3->d
    reg [1:0] sel;

    always @(posedge clk_100M or posedge reset) begin
      if (reset) begin c<=0; d<=0; s_c<=1'b0; s_d<=1'b0; sel<=0; end
      else if (slow_tick) begin
        if (rise[PB_RIGHT]) sel <= sel + 1;
        if (rise[PB_LEFT])  sel <= sel - 1;

        // toggle sign on sign cells
        if (sel==0 && (rise[PB_UP] || rise[PB_DOWN])) s_c <= ~s_c;
        if (sel==2 && (rise[PB_UP] || rise[PB_DOWN])) s_d <= ~s_d;

        // edit digits on digit cells
        if (sel==1) begin
          if (rise[PB_UP])   c <= (c==9)?0:c+1;
          if (rise[PB_DOWN]) c <= (c==0)?9:c-1;
        end
        if (sel==3) begin
          if (rise[PB_UP])   d <= (d==9)?0:d+1;
          if (rise[PB_DOWN]) d <= (d==0)?9:d-1;
        end
      end
    end

    // glyphs
    wire [7:0] c_ch = "0"+c, d_ch = "0"+d;
    wire on_c, on_x, on_d;

    // signs, change based on +ve or -ve
    wire on_c_minus, on_d_minus;
    labels_lut lc  (.clk(clk_100M), .px(px),.py(py),.sx(CXM), .sy(ORGY), .text({s_c ? "-" : " ", c_ch, "X", {(16-3){8'h00}}}), .on(on_c));
    labels_lut ld  (.clk(clk_100M), .px(px),.py(py),.sx(DXM), .sy(ORGY), .text({s_d ? "-" : "+", d_ch, {(16-2){8'h00}}}), .on(on_d));
    // borders
    function border_on; input [6:0] x,y,gx,gy; begin
        border_on = (x>=gx-1 && x<=gx+GW && y>=gy-1 && y<=gy+GH) &&
                    (x==gx-1 || x==gx+GW || y==gy-1 || y==gy+GH);
    end endfunction

    wire c_border      = (sel==1) && border_on(px,py,CX+2, ORGY);
    wire d_border      = (sel==3) && border_on(px,py,DX, ORGY);
    wire c_sign_border = (sel==0) && border_on(px,py,CXM,ORGY);
    wire d_sign_border = (sel==2) && border_on(px,py,DXM,ORGY);

    always @(*) begin
        if (!enable) oled = BLACK;
        else if (c_border || d_border || c_sign_border || d_sign_border) oled = GREEN;
        else if (on_c || on_x || on_d || on_c_minus || on_d_minus) oled = WHITE;
        else oled = BLACK;
    end
endmodule

module module_x2 (
    input  [6:0] px, input [6:0] py,
    input clk_100M, input reset,
    input  [4:0] pb,
    input enable,
    output reg [15:0] oled,
    output reg [3:0] b, output reg [3:0] c, output reg [3:0] d,
    output reg s_b, output reg s_c, output reg s_d
);
    localparam [15:0] WHITE=16'b11111_111111_11111, BLACK=16'b00000_000000_00000, GREEN=16'b00000_111111_00000;
    localparam PB_UP    = 1;
    localparam PB_DOWN  = 4;
    localparam PB_RIGHT = 3;
    localparam PB_LEFT  = 2;
    localparam [6:0] ORGX=1, ORGY=30, ADV=8, GW=6, GH=8;

    // positions: a,"x^3"," + ", b,"x^2"," + ", c,"x"," + ", d
    localparam [6:0] BX=ORGX+3;
    localparam [6:0] X2X=BX+ADV;
    localparam [6:0] P2 =X2X+(2*ADV);
    localparam [6:0] CX=P2+ADV;
    localparam [6:0] XX=CX+ADV;
    localparam [6:0] P3 =XX+ADV;
    localparam [6:0] DX=P3+ADV;

    // safe minus positions (clamped to screen left)
    localparam integer SHIFT = 6;
    localparam [6:0] BXM = (BX > SHIFT) ? (BX - SHIFT) : 7'd0;
    localparam [6:0] CXM = (CX > SHIFT) ? (CX - SHIFT) : 7'd0;
    localparam [6:0] DXM = (DX > SHIFT) ? (DX - SHIFT) : 7'd0;

    // debounce
    reg [19:0] cnt; always @(posedge clk_100M or posedge reset) if (reset) cnt<=0; else cnt<=cnt+1;
    wire slow_tick=(cnt[17:0]==0);
    reg [4:0] pb0,pb1,prev; wire [4:0] rise = pb1 & ~prev;
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin pb0<=0; pb1<=0; prev<=0; end
        else begin pb0<=pb; pb1<=pb0; if (slow_tick) prev<=pb1; end
    end

    // selection: 0->sign(b), 1->b, 2->sign(c), 3->c, 4->sign(d), 5->d
    reg [2:0] sel;

    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            b<=0; c<=0; d<=0;
            s_b<=1'b0; s_c<=1'b0; s_d<=1'b0;
            sel<=3'd0;
        end else if (slow_tick) begin
            // wrap over 0..5
            if (rise[PB_RIGHT]) sel <= (sel==3'd5) ? 3'd0 : sel + 3'd1;
            if (rise[PB_LEFT])  sel <= (sel==3'd0) ? 3'd5 : sel - 3'd1;

            // toggle signs
            if ((sel==3'd0) && (rise[PB_UP] || rise[PB_DOWN])) s_b <= ~s_b;
            if ((sel==3'd2) && (rise[PB_UP] || rise[PB_DOWN])) s_c <= ~s_c;
            if ((sel==3'd4) && (rise[PB_UP] || rise[PB_DOWN])) s_d <= ~s_d;

            // edit digits
            if (sel==3'd1) begin
                if (rise[PB_UP])   b <= (b==9)? 0 : b+1;
                if (rise[PB_DOWN]) b <= (b==0)? 9 : b-1;
            end
            if (sel==3'd3) begin
                if (rise[PB_UP])   c <= (c==9)? 0 : c+1;
                if (rise[PB_DOWN]) c <= (c==0)? 9 : c-1;
            end
            if (sel==3'd5) begin
                if (rise[PB_UP])   d <= (d==9)? 0 : d+1;
                if (rise[PB_DOWN]) d <= (d==0)? 9 : d-1;
            end
        end
    end

    // glyphs
    wire [7:0] b_ch="0"+b, c_ch="0"+c, d_ch="0"+d;
    wire on_b, on_x2, on_c, on_x, on_d;
    
    wire on_b_minus, on_c_minus, on_d_minus;
    labels_lut lb  (.clk(clk_100M), .px(px),.py(py),.sx(BXM), .sy(ORGY), .text({s_b ? "-" : " ", b_ch, "X^2", {(16-5){8'h00}}}), .on(on_b));
    labels_lut lc  (.clk(clk_100M), .px(px),.py(py),.sx(CXM), .sy(ORGY), .text({s_c ? "-" : "+", c_ch, "X", {(16-3){8'h00}}}), .on(on_c));
    labels_lut ld  (.clk(clk_100M), .px(px),.py(py),.sx(DXM), .sy(ORGY), .text({s_d ? "-" : "+", d_ch, {(16-2){8'h00}}}), .on(on_d));
    // borders
    function border_on; input [6:0] x,y,gx,gy; begin
        border_on = (x>=gx-1 && x<=gx+GW && y>=gy-1 && y<=gy+GH) &&
                    (x==gx-1 || x==gx+GW || y==gy-1 || y==gy+GH);
    end endfunction

    wire b_border = (sel==3'd1) && border_on(px,py, BX+2, ORGY);
    wire c_border = (sel==3'd3) && border_on(px,py, CX, ORGY);
    wire d_border = (sel==3'd5) && border_on(px,py, DX, ORGY);

    wire b_sign_border = (sel==3'd0) && border_on(px,py,BXM, ORGY);
    wire c_sign_border = (sel==3'd2) && border_on(px,py,CXM, ORGY);
    wire d_sign_border = (sel==3'd4) && border_on(px,py,DXM, ORGY);

    always @(*) begin
        if (!enable) oled = BLACK;
        else if (b_border || c_border || d_border || b_sign_border || c_sign_border || d_sign_border) oled = GREEN;
        else if (on_b || on_x2 || on_c || on_x || on_d || on_b_minus || on_c_minus || on_d_minus) oled = WHITE;
        else oled = BLACK;
    end
endmodule

module module_x3 (
    input  [6:0] px, input [6:0] py,
    input        clk_100M, input reset,
    input  [4:0] pb,
    input        enable,
    output reg [15:0] oled,
    output reg [3:0] a, output reg [3:0] b,
    output reg [3:0] c, output reg [3:0] d,
    output reg s_a, output reg s_b, output reg s_c, output reg s_d
);
    localparam [15:0] WHITE=16'b11111_111111_11111, BLACK=16'b00000_000000_00000, GREEN=16'b00000_111111_00000;
    localparam PB_UP    = 1;
    localparam PB_DOWN  = 4;
    localparam PB_RIGHT = 3;
    localparam PB_LEFT  = 2;
    localparam [6:0] ORGX=1, ORGY=30, ADV=8, GW=6, GH=8;

    // positions: a,"x^3"," + ", b,"x^2"," + ", c,"x"," + ", d
    localparam [6:0] AX=ORGX+3;
    localparam [6:0] X3X=AX+ADV;
    localparam [6:0] P1 =X3X+(2*ADV)-2;
    localparam [6:0] BX=P1+ADV;
    localparam [6:0] X2X=BX+ADV;
    localparam [6:0] P2 =X2X+(2*ADV)-2;
    localparam [6:0] CX=P2+ADV;
    localparam [6:0] XX=CX+ADV;
    localparam [6:0] P3 =XX+ADV-2;
    localparam [6:0] DX=P3+ADV;

    // safe minus positions (clamped to screen left)
    localparam integer SHIFT = 6;
    localparam [6:0] AXM = (AX > SHIFT) ? (AX - SHIFT) : 7'd0;
    localparam [6:0] BXM = (BX > SHIFT) ? (BX - SHIFT) : 7'd0;
    localparam [6:0] CXM = (CX > SHIFT) ? (CX - SHIFT) : 7'd0;
    localparam [6:0] DXM = (DX > SHIFT) ? (DX - SHIFT) : 7'd0;

    // debounce
    reg [19:0] cnt; always @(posedge clk_100M or posedge reset) if (reset) cnt<=0; else cnt<=cnt+1;
    wire slow_tick=(cnt[17:0]==0);
    reg [4:0] pb0,pb1,prev; wire [4:0] rise = pb1 & ~prev;
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin pb0<=0; pb1<=0; prev<=0; end
        else begin pb0<=pb; pb1<=pb0; if (slow_tick) prev<=pb1; end
    end

    reg [2:0] sel;
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            a<=0; b<=0; c<=0; d<=0;
            s_a<=1'b0; s_b<=1'b0; s_c<=1'b0; s_d<=1'b0;
            sel<=3'd0;
        end else if (slow_tick) begin
            if (rise[PB_RIGHT]) sel <= sel + 3'd1;
            if (rise[PB_LEFT])  sel <= sel - 3'd1;

            // toggle signs when focused on sign cells
            if ((sel==3'd0) && (rise[PB_UP] || rise[PB_DOWN])) s_a <= ~s_a;
            if ((sel==3'd2) && (rise[PB_UP] || rise[PB_DOWN])) s_b <= ~s_b;
            if ((sel==3'd4) && (rise[PB_UP] || rise[PB_DOWN])) s_c <= ~s_c;
            if ((sel==3'd6) && (rise[PB_UP] || rise[PB_DOWN])) s_d <= ~s_d;

            // change digits when focused on digit cells
            if (sel==3'd1) begin
                if (rise[PB_UP])   a <= (a==9)? 0 : a+1;
                if (rise[PB_DOWN]) a <= (a==0)? 9 : a-1;
            end
            if (sel==3'd3) begin
                if (rise[PB_UP])   b <= (b==9)? 0 : b+1;
                if (rise[PB_DOWN]) b <= (b==0)? 9 : b-1;
            end
            if (sel==3'd5) begin
                if (rise[PB_UP])   c <= (c==9)? 0 : c+1;
                if (rise[PB_DOWN]) c <= (c==0)? 9 : c-1;
            end
            if (sel==3'd7) begin
                if (rise[PB_UP])   d <= (d==9)? 0 : d+1;
                if (rise[PB_DOWN]) d <= (d==0)? 9 : d-1;
            end
        end
    end

    // chars
    wire [7:0] a_ch="0"+a, b_ch="0"+b, c_ch="0"+c, d_ch="0"+d;
    wire on_a,on_x3,on_p1,on_b,on_x2,on_p2,on_c,on_x,on_p3,on_d;

    labels_lut la  (.clk(clk_100M), .px(px),.py(py),.sx(AXM), .sy(ORGY), .text({s_a ? "-" : " ", a_ch, "X^3", {(16-5){8'h00}}}), .on(on_a));
    labels_lut lb  (.clk(clk_100M), .px(px),.py(py),.sx(BXM), .sy(ORGY), .text({s_b ? "-" : "+", b_ch, "X^2", {(16-5){8'h00}}}), .on(on_b));
    labels_lut lc  (.clk(clk_100M), .px(px),.py(py),.sx(CXM), .sy(ORGY), .text({s_c ? "-" : "+", c_ch, "X", {(16-3){8'h00}}}), .on(on_c));
    labels_lut ld  (.clk(clk_100M), .px(px),.py(py),.sx(DXM), .sy(ORGY), .text({s_d ? "-" : "+", d_ch, {(16-2){8'h00}}}), .on(on_d));

    wire on_a_minus, on_b_minus, on_c_minus, on_d_minus;


    function border_on; input [6:0] x,y,gx,gy; begin
        border_on = (x>=gx-1 && x<=gx+GW && y>=gy-1 && y<=gy+GH) &&
                    (x==gx-1 || x==gx+GW || y==gy-1 || y==gy+GH);
    end endfunction

    // borders for digit cells and sign cells
    wire a_border=(sel==3'd1)&&border_on(px,py,AX+2, ORGY);
    wire b_border=(sel==3'd3)&&border_on(px,py,BX, ORGY);
    wire c_border=(sel==3'd5)&&border_on(px,py,CX, ORGY);
    wire d_border=(sel==3'd7)&&border_on(px,py,DX, ORGY);

    wire a_sign_border=(sel==3'd0)&&border_on(px,py,AXM,ORGY);
    wire b_sign_border=(sel==3'd2)&&border_on(px,py,BXM,ORGY);
    wire c_sign_border=(sel==3'd4)&&border_on(px,py,CXM,ORGY);
    wire d_sign_border=(sel==3'd6)&&border_on(px,py,DXM,ORGY);

    always @(*) begin
        if (!enable) oled = BLACK;
        else if (a_border||b_border||c_border||d_border||a_sign_border||b_sign_border||c_sign_border||d_sign_border) oled = GREEN;
        else if (on_a||on_x3||on_p1||on_b||on_x2||on_p2||on_c||on_x||on_p3||on_d||
                 on_a_minus||on_b_minus||on_c_minus||on_d_minus) oled = WHITE;
        else oled = BLACK;
    end
endmodule

