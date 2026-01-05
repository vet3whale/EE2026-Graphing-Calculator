`timescale 1ns / 1ps
module data_page(
    input [6:0] x, input [6:0] y,
    input [6:0] mx, input [6:0] my,
    input click_rise, input reset,
    input enable, input clk_100M,
    output reg [15:0] oled,

    input [47:0] eq_xi_bus, input [47:0] eq_yi_bus,
    input [3:0] z_num, input [3:0] z_den
);
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] GREEN = 16'b00000_111111_00000;
    localparam integer X0 = 48;
    localparam integer Y0 = 32;

    wire signed [31:0] eq_xi_arr [0:2];
    wire signed [31:0] eq_yi_arr [0:2];
    assign eq_xi_arr[0] = eq_xi_bus[47:32];
    assign eq_xi_arr[1] = eq_xi_bus[31:16];
    assign eq_xi_arr[2] = eq_xi_bus[15:0];
    assign eq_yi_arr[0] = eq_yi_bus[47:32];
    assign eq_yi_arr[1] = eq_yi_bus[31:16];
    assign eq_yi_arr[2] = eq_yi_bus[15:0];

    localparam integer Q = 8; 
    wire signed [15:0] x_disp_arr [0:2], y_disp_arr [0:2];
    generate
        genvar i;
        for (i = 0; i < 3; i = i + 1) begin : raw_display
            assign x_disp_arr[i] = eq_xi_arr[i][15:0];
            assign y_disp_arr[i] = eq_yi_arr[i][15:0];
        end
    endgenerate

    // Display logic/formatting
    function [11:0] to2digits;
        input signed [7:0] val_in;
        reg [8:0] absval, rem;
        reg [3:0] tens;
        reg signbit;
        begin
            signbit = (val_in < 0);
            absval = signbit ? -val_in : val_in;
            rem = 4'd0;
            tens = 4'd0;
            if (absval >= 7'd80) begin tens = 8; rem = absval - 80; end
            else if (absval >= 7'd70) begin tens = 7; rem = absval - 70; end
            else if (absval >= 7'd60) begin tens = 6; rem = absval - 60; end
            else if (absval >= 7'd50) begin tens = 5; rem = absval - 50; end
            else if (absval >= 7'd40) begin tens = 4; rem = absval - 40; end
            else if (absval >= 7'd30) begin tens = 3; rem = absval - 30; end
            else if (absval >= 7'd20) begin tens = 2; rem = absval - 20; end
            else if (absval >= 7'd10) begin tens = 1; rem = absval - 10; end
            else begin tens = 0; rem = absval; end
            to2digits = { signbit ? 8'd45 : 4'h0, tens, rem[3:0] };
        end
    endfunction

    localparam ZERO_PAD = 1;
    wire [9:0] text_on_vec;
    generate
        for (i = 0; i < 3; i = i + 1) begin : print_rows
            wire signed [7:0] xval = (x_disp_arr[i] > 99)  ? 8'd99  :
                              (x_disp_arr[i] < -99) ? -8'd99 : x_disp_arr[i][7:0];
            wire signed [7:0] yval = (y_disp_arr[i] > 99)  ? 8'd99  :
                              (y_disp_arr[i] < -99) ? -8'd99 : y_disp_arr[i][7:0];

            wire [11:0] x_digits = to2digits(xval);
            wire [11:0] y_digits = to2digits(yval);

            wire sign_x = x_digits[11:8] != 0;
            wire sign_y = y_digits[11:8] != 0;
            wire [3:0] x_t = x_digits[7:4];
            wire [3:0] x_o = x_digits[3:0];
            wire [3:0] y_t = y_digits[7:4];
            wire [3:0] y_o = y_digits[3:0];

            // ASCII for tens with optional leading space
            wire [7:0] sign_x_ascii = sign_x ? "-" : " ";
            wire [7:0] sign_y_ascii = sign_y ? "-" : " ";
            wire [7:0] x_t_ascii = x_t + "0";
            wire [7:0] y_t_ascii = y_t + "0";
            wire [7:0] x_o_ascii = x_o + "0";
            wire [7:0] y_o_ascii = y_o + "0";

            // Build tiny strings: "XX" and "YY"
            wire [23:0] line_x = {sign_x_ascii, x_t_ascii, x_o_ascii};
            wire [23:0] line_y = {sign_y_ascii, y_t_ascii, y_o_ascii};

            // Place both on the same row; keep within 96x64
            localparam [6:0] BASE_Y = 7'd6;
            wire on_x, on_y;

            labels_lut show_x (
                .clk(clk_100M),
                .px(x), .py(y),
                .sx(7'd4), .sy(BASE_Y + (12*i)),
                .text({line_x, {(16-3){8'h00}}}),
                .on(on_x)
            );
            labels_lut show_y (
                .clk(clk_100M),
                .px(x), .py(y),
                .sx(7'd48), .sy(BASE_Y + (12*i)),
                .text({line_y, {(16-3){8'h00}}}),
                .on(on_y)
            );

            assign text_on_vec[2*i]   = on_x;
            assign text_on_vec[2*i+1] = on_y;
        end
    endgenerate

    wire text_on = |text_on_vec;

    always @(*) begin
        oled = (!enable) ? 16'b0 : (text_on ? GREEN : BLACK);
    end
endmodule
