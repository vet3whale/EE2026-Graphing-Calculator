`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.10.2025 10:10:19
// Design Name: 
// Module Name: mouse_io
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

module mouse_io(
    input [11:0] mouse_x, input [11:0] mouse_y, input mouse_l,
    input reset, input clk,
    output reg [6:0] mx, output reg [6:0] my,
    output reg l_sync, output reg click_rise, output reg click_fall
);
    // --- clamp mouse coordinates to 96x64 OLED ---
    always @(*) begin
        if (mouse_x > 12'd95) mx = 7'd95;
        else mx = mouse_x[6:0];

        if (mouse_y > 12'd63) my = 7'd63;
        else my = mouse_y[6:0];
    end

    // --- synchronize and edge detect for mouse_l ---
    reg l_meta, l_sync_d;

    always @(posedge clk) begin
        if (reset) begin
            l_meta <= 0;
            l_sync <= 0;
            l_sync_d <= 0;
        end else begin
            l_meta <= mouse_l;
            l_sync <= l_meta;       // 2-FF synchronizer
            l_sync_d <= l_sync;     // delayed version for edge detect
        end
    end

    always @(*) begin
        click_rise =  l_sync & ~l_sync_d;
        click_fall = ~l_sync &  l_sync_d;
    end

endmodule