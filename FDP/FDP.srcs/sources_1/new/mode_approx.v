`timescale 1ns / 1ps
module mode_approx(input  [11:0] mouse_x, input [11:0] mouse_y, input mouse_l, input mouse_m, input [4:0] pb, input reset, 
                   input  [12:0] pixel_index, input sample_pixel,
                   output reg [15:0] appx_oleddata,  // This is now a registered output
                   input clk_100M, input appx_enable);
    
    localparam RED = 16'b11111_000000_00000;
    localparam BLACK = 16'b0;
    localparam WHITE  = 16'b11111_111111_11111;
    
    wire [6:0] x = pixel_index % 96;
    wire [6:0] y = pixel_index / 96;

    wire [6:0] mx, my;
    wire l_sync, click_rise, click_fall;
    mouse_io plot_mouse(.mouse_x(mouse_x), .mouse_y(mouse_y), .mouse_l(mouse_l), .reset(reset), .clk(clk_100M),
                        .mx(mx), .my(my), .l_sync(l_sync), .click_rise(click_rise), .click_fall(click_fall));
    // mouse pointer
    wire pointer = ((x == mx) || (x+1 == mx) || (mx+1 == x)) &&
                   ((y == my) || (y+1 == my) || (my+1 == y));
        
    reg m_sync0, m_sync1; reg m_prev; // for rising edge
    wire m_click_rise;
    // middle button goes to prev page
    always @(posedge clk_100M or posedge reset) begin
      if (reset) begin
        m_sync0 <= 1'b0; m_sync1 <= 1'b0; m_prev <= 1'b0;
      end else begin
        m_sync0 <= mouse_m; // synchronize
        m_sync1 <= m_sync0;
        m_prev  <= m_sync1; // delay for edge detect
      end
    end
    assign m_click_rise = m_sync1 & ~m_prev;
        
    wire [15:0] points_oled, plot_oled;
    wire signed [4:0] x0, y0, x1, y1, x2, y2;
    wire linreg_enable;
        
    userdata_module point_editor (
        .px(x), .py(y), .mx(mx), .my(my),
        .click_rise(click_rise), .middle_rise(m_click_rise),
        .clk_100M(clk_100M), .reset(reset), .pb(pb & ~linreg_enable),
        .enable(appx_enable), 
        .oled(points_oled), 
        .done(linreg_enable),
        
        .x0(x0), .y0(y0), .x1(x1), .y1(y1),
        .x2(x2), .y2(y2)
    );
    linear_regression_plot linreg_plot (
        .clk_100M(clk_100M), .x(x), .y(y),
        .reset(reset),
        .enable(linreg_enable),
        .pixel_index(pixel_index),
        .x0(x0), .y0(y0), .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .plot_oleddata(plot_oled)
    );

    reg [15:0] appx_oleddata_comb;

    always @(*) begin
        if (pointer) appx_oleddata_comb = WHITE;
        if (!appx_enable)
            appx_oleddata_comb = BLACK;
        else if (!linreg_enable)
            appx_oleddata_comb = points_oled;
        else
            appx_oleddata_comb = plot_oled;
    end

    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            appx_oleddata <= BLACK;
        end else begin
            appx_oleddata <= appx_oleddata_comb;
        end
    end
    
endmodule
