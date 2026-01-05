`timescale 1ns / 1ps
module vetri(
    input clk, input [4:0] pb, 
    input [12:0] pixel_index, input clk6p25m, input enable,
    output [15:0] oleddata, output [15:0] led,
    input [11:0] mouse_x_pos, input [11:0] mouse_y_pos,
    input left, input middle, input right);
    
    wire mode_approx, mode_plot, menu_active;
    wire [15:0] approx_oleddata, plot_oleddata, menu_oleddata;
    wire sending_pixel, sample_pixel;
    
    assign oleddata = mode_approx ? approx_oleddata :
                       mode_plot ? plot_oleddata : 
                       menu_oleddata;

    assign led[15:13] = {left, middle, right};
    
    wire clk25m, clk12p5m, clk1hz;
    convert_clk25m md1 (clk, clk25m);
    convert_clk12p5m md2 (clk, clk12p5m);
    
    menu menumd (
        .mouse_x(mouse_x_pos), .mouse_y(mouse_y_pos), 
        .mouse_l(left), .reset(right), 
        .pixel_index(pixel_index), .menu_oleddata(menu_oleddata), 
        .enable(enable), .clk_100M(clk), 
        .mode_approx(mode_approx), .mode_plot(mode_plot)
    );
    
    mode_approx approxmd (
        .mouse_x(mouse_x_pos), .mouse_y(mouse_y_pos), .mouse_l(left), .mouse_m(middle), 
        .pb(pb), .reset(right), 
        .pixel_index(pixel_index), .appx_oleddata(approx_oleddata),
        .clk_100M(clk), .appx_enable(mode_approx), .sample_pixel(sample_pixel)
    );
    
    mode_plot plotmd (
        .mouse_x(mouse_x_pos), .mouse_y(mouse_y_pos), .mouse_l(left), .mouse_m(middle), 
        .pb(pb), .reset(right), 
        .pixel_index(pixel_index), .plot_oleddata(plot_oleddata),
        .clk_100M(clk), .plot_enable(mode_plot), .sample_pixel(sample_pixel)
    );
endmodule

module convert_clk25m (input clk, output reg clk25m = 0);
    reg [26:0] COUNT = 0;
    always @ (posedge clk) begin
        COUNT <= (COUNT == 1) ? 0: COUNT + 1;
        clk25m <= ( COUNT == 0 ) ? ~clk25m : clk25m ;
    end
endmodule
module convert_clk12p5m (input clk, output reg clk12p5m = 0);
    reg [26:0] COUNT = 0;
    always @ (posedge clk) begin
        COUNT <= (COUNT == 3) ? 0: COUNT + 1;
        clk12p5m <= ( COUNT == 0 ) ? ~clk12p5m : clk12p5m ;
    end
endmodule
