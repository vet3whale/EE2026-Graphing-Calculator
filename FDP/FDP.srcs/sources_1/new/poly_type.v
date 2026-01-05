module poly_type#(
    parameter integer STRLEN = 10,
    parameter [8*STRLEN-1:0] EQUATION = "EQUATION 1",
    parameter [16:0] COLOUR = 16'b11111_111111_11111
)(
    input  [6:0] x, input [6:0] y, // current pixel
    input  [6:0] mx, input [6:0] my, // mouse pixel
    input click_rise, input reset, input enable, input clk_100M,
    output reg [15:0] oled,
    output reg active, // 1 when this module wants to drive the OLED
    output reg [2:0] degree, output reg done
);
    localparam [15:0] WHITE  = 16'b11111_111111_11111;
    localparam [15:0] BLACK  = 16'b00000_000000_00000;
    localparam [15:0] GREEN  = 16'b00000_011000_00000;
    localparam [15:0] BLUE   = 16'b00000_000000_11111;
    localparam [15:0] GREY   = 16'b10010_100101_10010;

    // three option buttons
    localparam integer BTN_W = 22;
    localparam integer BTN_H = 14;

    // x button box
    localparam integer X1L = 8;   localparam integer X1T = 18;
    localparam integer X1R = X1L + BTN_W - 1;
    localparam integer X1B = X1T + BTN_H - 1;

    // x^2 button box
    localparam integer X2L = 36;  localparam integer X2T = 18;
    localparam integer X2R = X2L + BTN_W - 1;
    localparam integer X2B = X2T + BTN_H - 1;

    // x^3 button box
    localparam integer X3L = 64;  localparam integer X3T = 18;
    localparam integer X3R = X3L + BTN_W - 1;
    localparam integer X3B = X3T + BTN_H - 1;

    // NEXT button
    localparam integer NXL = 60;  localparam integer NXT = 50;
    localparam integer NXR = 92;  localparam integer NXB = 60;

    // Title text origin
    localparam integer TTLX = 6;
    localparam integer TTLY = 4;
    localparam integer OLED_W = 96;
    
    wire in_x1 = (x >= X1L) && (x <= X1R) && (y >= X1T) && (y <= X1B);
    wire in_x2 = (x >= X2L) && (x <= X2R) && (y >= X2T) && (y <= X2B);
    wire in_x3 = (x >= X3L) && (x <= X3R) && (y >= X3T) && (y <= X3B);
    wire in_nx = (x >= NXL) && (x <= NXR) && (y >= NXT) && (y <= NXB);

    wire mh_x1 = (mx >= X1L) && (mx <= X1R) && (my >= X1T) && (my <= X1B);
    wire mh_x2 = (mx >= X2L) && (mx <= X2R) && (my >= X2T) && (my <= X2B);
    wire mh_x3 = (mx >= X3L) && (mx <= X3R) && (my >= X3T) && (my <= X3B);
    wire mh_nx = (mx >= NXL) && (mx <= NXR) && (my >= NXT) && (my <= NXB);

    reg [1:0] sel; // 0 none, 1 x, 2 x^2, 3 x^3

    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            sel    <= 2'd0;
            degree <= 2'd0;
            done   <= 1'b0;
        end else begin
            if (click_rise && enable) begin
                if (mh_x1) sel <= (sel == 2'd1) ? 2'd0 : 2'd1;
                else if (mh_x2) sel <= (sel == 2'd2) ? 2'd0 : 2'd2;
                else if (mh_x3) sel <= (sel == 2'd3) ? 2'd0 : 2'd3;
                // confirm on NEXT
                if (enable && mh_nx && (sel != 2'd0)) begin
                    degree <= sel;
                    done   <= 1'b1;
                end
            end
        end
    end

    wire ttl_on;
    labels_lut ttl(
      .clk(clk_100M), .px(x), .py(y), .sx(TTLX), .sy(TTLY),
      .text({ EQUATION, {(16-10){8'h00}} }), .on(ttl_on)
    );

    // ===== Button captions (centered inside each button box) =====
    wire x1_text_on, x2_text_on, x3_text_on, nx_text_on;

    labels_lut lab_x(
      .clk(clk_100M), .px(x), .py(y), .sx(X1L[6:0] + 5), .sy(X1T[6:0] + 5),
      .text({ "X", {(16-1){8'h00}} }), .on(x1_text_on)
    );
    
    labels_lut lab_x2(
      .clk(clk_100M), .px(x), .py(y), .sx(X2L[6:0] + 5), .sy(X2T[6:0] + 5),
      .text({ "X^2", {(16-3){8'h00}} }), .on(x2_text_on)
    );
    
    labels_lut lab_x3(
      .clk(clk_100M), .px(x), .py(y), .sx(X3L[6:0] + 5), .sy(X3T[6:0] + 5),
      .text({ "X^3", {(16-3){8'h00}} }), .on(x3_text_on)
    );
    
    labels_lut lab_next(
      .clk(clk_100M), .px(x), .py(y), .sx(NXL[6:0]), .sy(NXT[6:0]),
      .text({ "NEXT", {(16-4){8'h00}} }), .on(nx_text_on)
    );

    // button skins
    wire x1_border = in_x1 && ((x==X1L)||(x==X1R)||(y==X1T)||(y==X1B));
    wire x2_border = in_x2 && ((x==X2L)||(x==X2R)||(y==X2T)||(y==X2B));
    wire x3_border = in_x3 && ((x==X3L)||(x==X3R)||(y==X3T)||(y==X3B));
    wire nx_border = in_nx && ((x==NXL)||(x==NXR)||(y==NXT)||(y==NXB));

    wire x1_fill = in_x1 && !x1_border;
    wire x2_fill = in_x2 && !x2_border;
    wire x3_fill = in_x3 && !x3_border;
    wire nx_fill = in_nx && !nx_border;

    // hover highlight
    wire x1_hover = x1_fill && mh_x1;
    wire x2_hover = x2_fill && mh_x2;
    wire x3_hover = x3_fill && mh_x3;
    wire nx_hover = nx_fill && mh_nx;

    // selected fill
    wire x1_sel = x1_fill && (sel == 2'd1);
    wire x2_sel = x2_fill && (sel == 2'd2);
    wire x3_sel = x3_fill && (sel == 2'd3);

    always @(*) begin
        active = enable;
        oled   = BLACK;
        if (!enable) begin
            active = 1'b0;
        end else begin
            // title
            if (ttl_on) oled = COLOUR;

            // borders
            if (x1_border) oled = WHITE;
            if (x2_border) oled = WHITE;
            if (x3_border) oled = WHITE;
            if (nx_border) oled = WHITE;

            // fills
            if (x1_sel) oled = GREEN;
            else if (x1_hover) oled = GREY;
            else if (x1_fill && (oled==BLACK)) oled = 16'b00001_000001_00001;

            if (x2_sel) oled = GREEN;
            else if (x2_hover && (oled==BLACK)) oled = GREY;
            else if (x2_fill && (oled==BLACK)) oled = 16'b00001_000001_00001;

            if (x3_sel)   oled = GREEN;
            else if (x3_hover && (oled==BLACK)) oled = GREY;
            else if (x3_fill && (oled==BLACK)) oled = 16'b00001_000001_00001;

            if (nx_hover) oled = BLUE;
            else if (nx_fill && (oled==BLACK)) oled = 16'b00001_000001_01000;

            // Text
            if (x1_text_on) oled = WHITE;
            if (x2_text_on) oled = WHITE;
            if (x3_text_on) oled = WHITE;
            if (nx_text_on) oled = WHITE;
        end
    end
endmodule