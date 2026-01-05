`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2025 14:14:54
// Design Name: 
// Module Name: menu
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
module menu(
    input  [11:0] mouse_x,input [11:0] mouse_y, input mouse_l, input reset, input [12:0] pixel_index,
    output reg [15:0] menu_oleddata, input enable,
    input clk_100M, output reg mode_approx, output reg mode_plot
);
    // Colors
    localparam [15:0] WHITE  = 16'b11111_111111_11111;
    localparam [15:0] BLACK  = 16'b00000_000000_00000;
    localparam [15:0] GREEN  = 16'b00000_011000_00000;

    wire [6:0] x = pixel_index % 96;
    wire [6:0] y = pixel_index / 96;
    
    // sub-parts buttons 
    localparam integer BTN_W = 84; 
    localparam integer BTN_H = 16; 
    localparam integer BTN_X0 = (96 - BTN_W)/2;
    localparam integer BTN1_Y0 = 12; // top button = Approx 
    localparam integer BTN2_Y0 = 36; // bottom button = Plot
    
    // engage mouse
    wire [6:0] mx, my;
    wire l_sync, click_rise, click_fall;
    mouse_io menu_mouse(.mouse_x(mouse_x), .mouse_y(mouse_y), .mouse_l(mouse_l), .reset(reset), .clk(clk_100M),
                        .mx(mx), .my(my), .l_sync(l_sync), .click_rise(click_rise), .click_fall(click_fall));

    function automatic in_rect;
      input integer X0, Y0, W, H; input [6:0] px, py;
      begin in_rect = (px >= X0) && (px < X0+W) && (py >= Y0) && (py < Y0+H); end
    endfunction
    
    function automatic on_border;
      input integer X0, Y0, W, H; input [6:0] px, py;
      begin on_border = in_rect(X0,Y0,W,H,px,py) && (px==X0 || px==X0+W-1 || py==Y0 || py==Y0+H-1); end
    endfunction

    wire over_btn1 = in_rect(BTN_X0, BTN1_Y0, BTN_W, BTN_H, mx, my);
    wire over_btn2 = in_rect(BTN_X0, BTN2_Y0, BTN_W, BTN_H, mx, my);

    // menu selection --> 3 states
    localparam [1:0] MENU_IDLE = 2'b00,
                     SEL_APPROX = 2'b01,
                     SEL_PLOT = 2'b10;
    reg [1:0] menu_state = MENU_IDLE;

    always @(posedge clk_100M) begin
        if (reset) begin
            menu_state <= MENU_IDLE;
            mode_approx <= 1'b0;
            mode_plot <= 1'b0;
        end else begin
            case (menu_state)
                MENU_IDLE: begin
                    mode_approx <= 1'b0; mode_plot   <= 1'b0;
                    if (enable && click_rise) begin
                        if (over_btn1) begin
                            menu_state <= SEL_APPROX;
                        end else if (over_btn2) begin
                            menu_state <= SEL_PLOT; 
                        end
                    end
                end
                SEL_APPROX: begin
                    mode_approx <= 1'b1; mode_plot   <= 1'b0;
                end
                SEL_PLOT: begin
                    mode_approx <= 1'b0; mode_plot   <= 1'b1;
                end
                default: begin
                    menu_state <= MENU_IDLE;
                    mode_approx <= 1'b0; mode_plot <= 1'b0;
                end
            endcase
        end
    end
    
    // text for menu (8 chars * 6px = 48px; centered in 84px ? +18)
    localparam [6:0] STR_X  = BTN_X0 + (BTN_W - 64)/2; // center (84-64)/2 = 10
    localparam [6:0] STR1_Y = BTN1_Y0 + (BTN_H - 5)/2; // center (16-5)/2 = 5  -> 12+5=17
    localparam [6:0] STR2_Y = BTN2_Y0 + (BTN_H - 5)/2; // 36+5=41

    // text pixels from separate module
    wire txt1_on, txt2_on;
    labels_lut label1_inst (
        .clk(clk_100M),
        .px(x), .py(y),
        .sx(STR_X[6:0]), .sy(STR1_Y[6:0]),
        .text({"GR. APPX", {(16-8){8'h00}} }),
        .on(txt1_on)
    );
    labels_lut label2_inst (
        .clk(clk_100M),
        .px(x), .py(y),
        .sx(STR_X[6:0]+3), .sy(STR2_Y[6:0]),
        .text({"GR. PLT", {(16-7){8'h00}} }),
        .on(txt2_on)
    );
    // draw boxes for subparts
    wire in_btn1 = in_rect(BTN_X0, BTN1_Y0, BTN_W, BTN_H, x, y);
    wire in_btn2 = in_rect(BTN_X0, BTN2_Y0, BTN_W, BTN_H, x, y);
    wire brd1 = on_border(BTN_X0, BTN1_Y0, BTN_W, BTN_H, x, y);
    wire brd2 = on_border(BTN_X0, BTN2_Y0, BTN_W, BTN_H, x, y);

    // mouse pointer
    wire pointer = ((x == mx) || (x+1 == mx) || (mx+1 == x)) &&
                   ((y == my) || (y+1 == my) || (my+1 == y));

    // oleddata
    always @(*) begin
        if (!enable) begin
            menu_oleddata = WHITE;
        end else begin
            // base
            menu_oleddata = BLACK;
            if (in_btn1) menu_oleddata = BLACK;
            if (in_btn2) menu_oleddata = BLACK;
            // hovering
            if (over_btn1 && in_btn1) menu_oleddata = WHITE;
            if (over_btn2 && in_btn2) menu_oleddata = WHITE;
            // green outline
            if (brd1 || brd2) menu_oleddata = GREEN;
            //text
            if (txt1_on || txt2_on) menu_oleddata = GREEN;
            // pointer
            if (pointer) menu_oleddata = WHITE;
        end
    end
endmodule