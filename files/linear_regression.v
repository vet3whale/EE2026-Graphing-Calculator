`timescale 1ns / 1ps

module linear_regression_plot(
    input clk_100M, input reset, input enable,
    input [12:0] pixel_index,
    input signed [4:0] x0, input signed [4:0] y0,
    input signed [4:0] x1, input signed [4:0] y1,
    input signed [4:0] x2, input signed [4:0] y2,
    input [6:0] x, input [6:0] y,    
    output reg [15:0] plot_oleddata, output reg done
);

    localparam [15:0] BLACK  = 16'b00000_000000_00000;
    localparam [15:0] WHITE  = 16'b11111_111111_11111;
    localparam [15:0] RED    = 16'b11111_000000_00000;
    localparam [15:0] BLUE   = 16'b00000_000000_11111;
    localparam [15:0] GREEN  = 16'b00000_011000_00000;
    localparam MAXLEN = 8;
    
    localparam signed [6:0] X0 = 48; 
    localparam signed [6:0] Y0 = 32;
    localparam Q = 10;
    
    localparam CALC_REGRESSION = 0, CONVERT_START = 1, CONVERTING = 2, DISPLAY = 3;
    reg [1:0] main_state;
    
    (* FSM_ENCODING = "ONE_HOT" *) reg [11:0] calc_state;
    localparam S_IDLE         = 12'b000000000001;
    localparam S_SUM_0        = 12'b000000000010;
    localparam S_SUM_1        = 12'b000000000100;
    localparam S_SUM_2        = 12'b000000001000;
    localparam S_WAIT_SUMS    = 12'b000000010000;
    localparam S_CALC_TEMPS   = 12'b000000100000;
    localparam S_WAIT_TEMPS   = 12'b000001000000;
    localparam S_SLOPE        = 12'b000010000000;
    localparam S_WAIT_SLOPE   = 12'b000100000000;
    localparam S_INTER        = 12'b001000000000;
    localparam S_WAIT_INTER   = 12'b010000000000;
    localparam S_DONE         = 12'b100000000000;

    // arithmetic registers
    reg signed [6:0] sum_x, sum_y;
    reg signed [10:0] sum_xy, sum_x2;
    reg signed [12:0] temp1, temp2;
    reg signed [23:0] temp1_wide;
    reg signed [21:0] slope, intercept;
    reg signed [21:0] temp_inter;

    reg calc_done, enable_prev, temp2_zero_flag;
    reg precompute_done;
    
    reg start_slope_conv, start_intercept_conv;
    wire slope_conv_done, intercept_conv_done;
    wire bcd_slope_sign, bcd_intercept_sign;
    wire [3:0] bcd_slope_int, bcd_slope_frac1, bcd_slope_frac2;
    wire [3:0] bcd_intercept_int, bcd_intercept_frac1, bcd_intercept_frac2;

    wire [8*MAXLEN-1:0] slope_text;
    wire [8*MAXLEN-1:0] intercept_text;
    wire slope_text_on, intercept_text_on;
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) enable_prev <= 0;
        else enable_prev <= enable;
    end
    wire enable_start = enable && !enable_prev;
    reg signed [37:0] temp_intercept_calc;
    reg signed [6:0] px0, py0, px1, py1, px2, py2;
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            main_state <= CALC_REGRESSION; calc_state <= S_IDLE;
            precompute_done <= 0;
            sum_x <= 0; sum_y <= 0; sum_xy <= 0; sum_x2 <= 0;
            slope <= 0; intercept <= 0;
            temp1 <= 0; temp2 <= 0;
            temp1_wide <= 0; temp_inter <= 0;
            calc_done <= 0; temp2_zero_flag <= 0; temp_intercept_calc <= 0;
            done <= 0;
        end else begin
            if(start_slope_conv) start_slope_conv <= 0;
            if(start_intercept_conv) start_intercept_conv <= 0;
            case (main_state)
                CALC_REGRESSION: begin
                    case (calc_state)
                        S_IDLE: begin
                            if (enable_start) begin
                                calc_done <= 0; precompute_done <= 0;
                                sum_x <= 0; sum_y <= 0; sum_xy <= 0; sum_x2 <= 0;
                                calc_state <= S_SUM_0;
                                px0 <= X0 + 3*x0; py0 <= Y0 - 3*y0;
                                px1 <= X0 + 3*x1; py1 <= Y0 - 3*y1;
                                px2 <= X0 + 3*x2; py2 <= Y0 - 3*y2;
                            end
                        end

                        S_SUM_0: begin
                            sum_x <= x0; sum_y <= y0;
                            sum_xy <= x0*y0;
                            sum_x2 <= x0*x0;
                            calc_state <= S_SUM_1;
                        end
                        
                        S_SUM_1: begin
                            sum_x <= sum_x + x1; sum_y <= sum_y + y1;
                            sum_xy <= sum_xy + (x1*y1); 
                            sum_x2 <= sum_x2 + (x1*x1);
                            calc_state <= S_SUM_2;
                        end
                        
                        S_SUM_2: begin
                            sum_x <= sum_x + x2; sum_y <= sum_y + y2;
                            sum_xy <= sum_xy + (x2*y2);
                            sum_x2 <= sum_x2 + (x2*x2);
                            calc_state <= S_WAIT_SUMS;
                        end

                        S_WAIT_SUMS: calc_state <= S_CALC_TEMPS;

                        S_CALC_TEMPS: begin
                            temp1 <= (3 * $signed(sum_xy)) - ($signed(sum_x) * $signed(sum_y));
                            temp2 <= (3 * $signed(sum_x2)) - ($signed(sum_x) * $signed(sum_x));
                            calc_state <= S_WAIT_TEMPS;
                        end

                        S_WAIT_TEMPS: calc_state <= S_SLOPE;

                        S_SLOPE: begin
                            if (temp2 != 0) begin
                                temp1_wide <= $signed(temp1) <<< Q;
                                temp2_zero_flag <= 0;
                            end else begin
                                slope <= 0;
                                temp2_zero_flag <= 1;
                            end
                            calc_state <= S_WAIT_SLOPE;
                        end

                        S_WAIT_SLOPE: begin
                            if (!temp2_zero_flag) slope <= temp1_wide / $signed(temp2);
                            calc_state <= S_INTER;
                        end

                        S_INTER: begin
                            temp_intercept_calc = ((($signed(sum_y) <<< Q) - ($signed(slope) * $signed(sum_x))) * 341) >>> 10;
                            intercept <= temp_intercept_calc * 3;
                            calc_state <= S_WAIT_INTER;
                        end

                        S_WAIT_INTER: calc_state <= S_DONE;

                        S_DONE: begin
                            calc_done <= 1;
                            calc_state <= S_IDLE;
                            main_state <= CONVERT_START;
                            done <= 1;
                        end
                    endcase
                end
                CONVERT_START: begin
                    start_slope_conv <= 1;
                    start_intercept_conv <= 1;
                    main_state <= CONVERTING;
                end
                
                CONVERTING: begin
                    //if (slope_conv_done && intercept_conv_done) begin
                    precompute_done <= 1;
                    done <= 1;
                    main_state <= DISPLAY;
                    //end
                end
                DISPLAY: begin
                    if (!enable) begin
                        main_state <= CALC_REGRESSION;
                        calc_state <= S_IDLE;
                        precompute_done <= 0;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Compute line y-values combinationally for current and previous x
    wire signed [7:0] xx_curr = $signed({1'b0, x}) - $signed(X0);
    wire signed [7:0] xx_prev = (x > 0) ? ($signed({1'b0, x}) - $signed(X0) - 1) : xx_curr;
    
    wire signed [29:0] t_curr = $signed(slope) * xx_curr;
    wire signed [29:0] t_prev = $signed(slope) * xx_prev;
    
    wire signed [30:0] y_offi_curr = t_curr + $signed(intercept);
    wire signed [30:0] y_offi_prev = t_prev + $signed(intercept);
    
    wire signed [8:0] y_curr = Y0 - $signed(y_offi_curr >>> Q);
    wire signed [8:0] y_prev = Y0 - $signed(y_offi_prev >>> Q);

    // pixel logic
    wire [6:0] y1min_cmp = (y_curr < y_prev) ? y_curr[6:0] : y_prev[6:0];
    wire [6:0] y1max_cmp = (y_curr > y_prev) ? y_curr[6:0] : y_prev[6:0];
    
    wire [7:0] xi = {1'b0, x};
    wire [7:0] yi = {1'b0, y};
    
    wire in_p0 = (xi >= px0-1) && (xi <= px0+1) && (yi >= py0-1) && (yi <= py0+1);
    wire in_p1 = (xi >= px1-1) && (xi <= px1+1) && (yi >= py1-1) && (yi <= py1+1);
    wire in_p2 = (xi >= px2-1) && (xi <= px2+1) && (yi >= py2-1) && (yi <= py2+1);
    wire near_point = in_p0 | in_p1 | in_p2;
//    fixed_to_bcd_converter #(.Q(Q)) slope_bcd_converter (
//        .clk(clk_100M), .reset(reset), .start_conversion(start_slope_conv),
//        .fixed_val(slope),
//        .bcd_sign(bcd_slope_sign), .bcd_int(bcd_slope_int), .bcd_frac1(bcd_slope_frac1), .bcd_frac2(bcd_slope_frac2),
//        .conversion_done(slope_conv_done)
//    );
//    fixed_to_bcd_converter #(.Q(Q)) intercept_bcd_converter (
//        .clk(clk_100M), .reset(reset), .start_conversion(start_intercept_conv),
//        .fixed_val(temp_intercept_calc),
//        .bcd_sign(bcd_intercept_sign), .bcd_int(bcd_intercept_int), .bcd_frac1(bcd_intercept_frac1), .bcd_frac2(bcd_intercept_frac2),
//        .conversion_done(intercept_conv_done)
//    );
//    bcd_to_ascii_assembler #(.MAXLEN(MAXLEN)) slope_ascii_assembler (
//        .bcd_sign(bcd_slope_sign), .bcd_int(bcd_slope_int), .bcd_frac1(bcd_slope_frac1), .bcd_frac2(bcd_slope_frac2),
//        .label_char("m"), .ascii_text(slope_text)
//    );
//    bcd_to_ascii_assembler #(.MAXLEN(MAXLEN)) intercept_ascii_assembler (
//        .bcd_sign(bcd_intercept_sign), .bcd_int(bcd_intercept_int), .bcd_frac1(bcd_intercept_frac1), .bcd_frac2(bcd_intercept_frac2),
//        .label_char("c"), .ascii_text(intercept_text)
//    );
//    labels_lut #(.MAXLEN(MAXLEN)) slope_label (
//        .clk(clk_100M), .px(x), .py(y), 
//        .sx(2), .sy(2),
//        .text(slope_text), .on(slope_text_on)
//    );
//    labels_lut #(.MAXLEN(MAXLEN)) intercept_label (
//        .clk(clk_100M), .px(x), .py(y), 
//        .sx(2), .sy(12),
//        .text(intercept_text), .on(intercept_text_on)
//    );
    always @(*) begin
        plot_oleddata = BLACK;
        if (precompute_done && enable) begin
            if ((y >= y1min_cmp) && (y <= y1max_cmp)) plot_oleddata = BLUE;
            if ((x == X0) || (y == Y0)) plot_oleddata = WHITE;
            if (near_point) plot_oleddata = RED;
        end
//        if (precompute_done && (slope_text_on || intercept_text_on))
//             plot_oleddata = WHITE;
    end
    
endmodule

module fixed_to_bcd_converter #(parameter integer Q = 10)(
    input clk, input reset,
    input start_conversion, input signed [21:0] fixed_val,
    output reg [3:0] bcd_int, output reg [3:0] bcd_frac1,
    output reg [3:0] bcd_frac2, output reg bcd_sign,
    output reg conversion_done
);
    reg [1:0] state;
    localparam S_IDLE = 0, S_CONVERT_FRAC = 1, S_DONE = 2;

    reg [14:0] shifter;
    reg [3:0] bit_counter;

    wire [3:0] tens_col = shifter[14:11];
    wire [3:0] ones_col = shifter[10:7];
    
    wire [3:0] corrected_tens = (tens_col >= 5) ? tens_col + 3 : tens_col;
    wire [3:0] corrected_ones = (ones_col >= 5) ? ones_col + 3 : ones_col;

    wire signed [21:0] abs_val = fixed_val[21] ? -fixed_val : fixed_val;
    wire [11:0] int_part = abs_val >>> Q;
    wire [6:0] frac_as_int = ((abs_val & ((1'b1 << Q) - 1)) * 100) >>> Q;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE; conversion_done <= 0;
            bcd_int <= 0; bcd_frac1 <= 0; bcd_frac2 <= 0; bcd_sign <= 0;
            shifter <= 0; bit_counter <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    conversion_done <= 0;
                    if (start_conversion) begin
                        bcd_sign <= fixed_val[21];
                        bcd_int <= (int_part > 9) ? 9 : int_part[3:0];
                        shifter <= {8'b0, frac_as_int};
                        bit_counter <= 7;
                        state <= S_CONVERT_FRAC;
                    end
                end

                S_CONVERT_FRAC: begin
                    shifter <= {corrected_tens, corrected_ones, shifter[6:0]} << 1;
                    bit_counter <= bit_counter - 1;
                    if (bit_counter == 1) begin
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    bcd_frac1 <= shifter[14:11];
                    bcd_frac2 <= shifter[10:7];
                    conversion_done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule


module bcd_to_ascii_assembler #(parameter integer MAXLEN = 8)(
    input bcd_sign, input [3:0] bcd_int,
    input [3:0] bcd_frac1, input [3:0] bcd_frac2,
    input [7:0] label_char, output reg [8*MAXLEN-1:0] ascii_text
);
    always @(*) begin
        ascii_text = {MAXLEN{8'h20}}; 
        ascii_text[8*(MAXLEN-1 - 0) +: 8] = label_char;
        ascii_text[8*(MAXLEN-1 - 1) +: 8] = "=";
        ascii_text[8*(MAXLEN-1 - 2) +: 8] = bcd_sign ? "-" : "+";
        
        ascii_text[8*(MAXLEN-1 - 3) +: 8] = (bcd_int > 9) ? "0" : (bcd_int + 48);
        ascii_text[8*(MAXLEN-1 - 4) +: 8] = ".";
        
        ascii_text[8*(MAXLEN-1 - 5) +: 8] = (bcd_frac1 > 9) ? "0" : (bcd_frac1 + 48);
        ascii_text[8*(MAXLEN-1 - 6) +: 8] = (bcd_frac2 > 9) ? "0" : (bcd_frac2 + 48);
    end
endmodule
