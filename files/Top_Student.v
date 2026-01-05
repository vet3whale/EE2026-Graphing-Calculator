`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
//
//  FILL IN THE FOLLOWING INFORMATION:
//  STUDENT A NAME: 
//  STUDENT B NAME:
//  STUDENT C NAME: 
//  STUDENT D NAME:  
//
//////////////////////////////////////////////////////////////////////////////////
 
module Top_Student (
    input CLOCK, output [7:0] JC, input [4:0] pb, 
    input [15:0] sw, inout PS2Clk, inout PS2Data, output [15:0] LED
); 

    wire clk6p25m;
    wire [15:0] vetri_oled, nic_oleddata, 
                ryan_oleddata, aidan_oleddata, mainmenu_oleddata, oleddata;
    wire sending_pixel, sample_pixel, fb;
    wire left, middle, right;
    wire [11:0] mouse_x_pos, mouse_y_pos;
    wire [12:0] pixel_index;
    wire [6:0] mx, my;
    wire l_sync, click_rise, click_fall;
    
    wire en_vetri, en_nic, en_ryan, en_aidan; 

    assign oleddata = en_vetri ? vetri_oled : 
                      en_nic ? nic_oleddata :
                      en_ryan ? ryan_oleddata :
                      en_aidan ? aidan_oleddata : mainmenu_oleddata;

    // Instantiate the new MainMenu module
    mainmenu main_menu_inst ( .CLOCK(CLOCK), .reset(right), .pixel_index(pixel_index),
                                .mx(mx), .my(my), .click_rise(click_rise), .click_fall(click_fall),
                                .en_vetri(en_vetri), .en_nic(en_nic), .en_ryan(en_ryan), .en_aidan(en_aidan),
                                .mainmenu_oleddata(mainmenu_oleddata) );

    convert_clk6p25m md0 (.CLOCK(CLOCK), .clk6p25m(clk6p25m));

    mouse_io main_mouse (
        .mouse_x(mouse_x_pos), .mouse_y(mouse_y_pos), 
        .mouse_l(left), .reset(right), .clk(CLOCK),
        .mx(mx), .my(my), 
        .l_sync(l_sync), .click_rise(click_rise), .click_fall(click_fall)
    );

    MouseCtl msemd (
        .clk(CLOCK), .ps2_clk(PS2Clk), .ps2_data(PS2Data), 
        .left(left), .middle(middle), .right(right), 
        .xpos(mouse_x_pos), .ypos(mouse_y_pos)
    );

    vetri vetrimodule (
      .clk(CLOCK), .pb(pb), .pixel_index(pixel_index),
      .clk6p25m(clk6p25m), .oleddata(vetri_oled), .led(LED),
      .mouse_x_pos(mouse_x_pos), .mouse_y_pos(mouse_y_pos),
      .left(left), .middle(middle), .right(right), .enable(en_vetri)
    );
    
    MatrixPages nicmodule (
      .clk(CLOCK), .clk_pix(clk6p25m),
      .mouse_l(left), .mouse_r(right), 
      .mouse_x(mouse_x_pos), .mouse_y(mouse_y_pos),
      .oled_data(nic_oleddata), .pixel_index(pixel_index)
    );
    
    ryanmodule ryanmodule (
        .CLOCK(CLOCK), .clk6p25m(clk6p25m), .pixel_index(pixel_index), 
        .mouse_x_pos(mouse_x_pos), .mouse_y_pos(mouse_y_pos), .left(left), .right(right), 
        .enable(en_ryan), .oled_data_out(ryan_oleddata)
    );
    
    aidan aidanmodule(
        .clk(CLOCK), .pb(pb), .sw(sw), .pixel_index(pixel_index), 
        .aidan_oleddata(aidan_oleddata)
    );
    
    Oled_Display oledmd (
        .clk(clk6p25m), .reset(right), 
        .cs(JC[0]), .sdin(JC[1]), .frame_begin(fb),
        .sending_pixels(sending_pixel), .sample_pixel(sample_pixel), 
        .sclk(JC[3]), .d_cn(JC[4]), .resn(JC[5]), 
        .vccen(JC[6]), .pmoden(JC[7]), 
        .pixel_data(oleddata), .pixel_index(pixel_index)
    );

endmodule