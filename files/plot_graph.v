`timescale 1ns / 1ps

module plot_graph(
    input [6:0] x, input [6:0] y,
    input click_rise, input reset,
    input enable, input clk_100M,
    output reg [15:0] oled, output reg done,
    
    input signed [15:0] a1, b1, c1, d1,
    input signed [15:0] a2, b2, c2, d2,
    input [4:0] pb, 
    output reg [3:0] z_num, z_den
);
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] ORANGE = 16'b11111_101001_00000;
    localparam [15:0] WHITE = 16'b11111_111111_11111;
    localparam [15:0] BLUE = 16'b00000_011110_11111;
    
    localparam X0 = 48, Y0 = 32;
    localparam PB_UP = 1, PB_DOWN = 4;
    localparam IDLE = 0, COMPUTE_POLY = 1, DISPLAY = 2;
    reg [1:0] main_state;
    
    reg [19:0] cnt; 
    always @(posedge clk_100M or posedge reset) 
        if (reset) cnt<=0; 
        else cnt<=cnt+1;
    
    wire slow_tick = (cnt[15:0]==0);
    reg [4:0] pb0, pb1, prev; 
    wire [4:0] rise = pb1 & ~prev;
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin pb0<=0; pb1<=0; prev<=0; end 
        else begin pb0 <= pb; pb1 <= pb0; if (slow_tick) prev <= pb1; end
    end
    
    reg [3:0] z_num_next, z_den_next, z_num_active, z_den_active;
    reg zoom_changed, enable_prev;
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) enable_prev <= 0;
        else enable_prev <= enable;
    end
    wire enable_start = enable && !enable_prev;

    reg signed [23:0] k1_3, k1_2, k1_1, k1_0;
    reg signed [23:0] k2_3, k2_2, k2_1, k2_0;
    // this ensures graph is smooth
    reg signed [15:0] poly1_y [0:95];
    reg signed [15:0] poly2_y [0:95];
    reg precompute_done;
    reg [6:0] compute_x;

    // DSP pipeline
    reg signed [31:0] t1, t2;
    reg signed [31:0] y1_offi, y2_offi;
    localparam Q = 14;
    reg signed [23:0] Afix, Bfix, Cfix, Dfix;
    
    reg signed [11:0] xx;
    reg [2:0] poly_state;
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            z_num <= 4'd1; z_den <= 4'd1;
            z_num_next <= 4'd1; z_den_next <= 4'd1;
            z_num_active <= 4'd1; z_den_active <= 4'd1;
            zoom_changed <= 0;
        end else begin
            if (slow_tick) begin
                if (rise[PB_UP] && z_num_next < 4'd8) begin 
                    z_num_next <= z_num_next << 1; zoom_changed <= 1;
                end
                else if (rise[PB_DOWN] && z_den_next < 4'd8) begin 
                    z_den_next <= z_den_next << 1; zoom_changed <= 1;
                end
                
                else if (z_den_next == z_num_next && z_den_next == 4'd8) begin
                    z_num_next <= 4'd1; z_den_next <= 4'd1; zoom_changed <= 1;
                end
                
                if (z_num_next == 0) z_num_next <= 4'd1;
                if (z_den_next == 0) z_den_next <= 4'd1;
            end
            
            if ((z_num_next != z_num_active) || (z_den_next != z_den_active)) begin
                zoom_changed <= 1;
                z_num <= z_num_next; z_den <= z_den_next;
                z_num_active <= z_num_next; z_den_active <= z_den_next;
            end
            if (zoom_changed) zoom_changed <= 0;
            
        end
    end
    
    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            main_state <= IDLE; poly_state <= 0; compute_x <= 0;
            precompute_done <= 0; done <= 0;
            t1 <= 0; t2 <= 0; y1_offi <= 0; y2_offi <= 0;
            k1_3<=0; k1_2<=0; k1_1<=0; k1_0<=0;
            k2_3<=0; k2_2<=0; k2_1<=0; k2_0<=0;
            Afix <= 0; Bfix <= 0; Cfix <= 0; Dfix <= 0;
        end else begin
            case (main_state)
                IDLE: begin
                    if (enable_start || (enable && !precompute_done)) begin
                        main_state <= COMPUTE_POLY;
                        compute_x <= 0; poly_state <= 0;
                        precompute_done <= 0; done <= 0;
                    end
                end
                
                COMPUTE_POLY: begin
                    if (compute_x == 0 && poly_state == 0) begin
                        case ({z_num, z_den})
                            8'h11, 8'h22, 8'h44, 8'h88: {Afix, Bfix, Cfix, Dfix} = {24'd474, 24'd2276, 24'd10923, 24'd52429};
                            8'h12, 8'h24, 8'h48: {Afix, Bfix, Cfix, Dfix} = {24'd1896, 24'd4551, 24'd10923, 24'd26214};
                            8'h14, 8'h28: {Afix, Bfix, Cfix, Dfix} = {24'd7585, 24'd9102, 24'd10923, 24'd13107};
                            8'h18: {Afix, Bfix, Cfix, Dfix} = {24'd30340, 24'd18204, 24'd10923, 24'd6554};
                            8'h21, 8'h42, 8'h84: {Afix, Bfix, Cfix, Dfix} = {24'd119, 24'd1138, 24'd10923, 24'd104858};
                            8'h41, 8'h82: {Afix, Bfix, Cfix, Dfix} = {24'd30, 24'd569, 24'd10923, 24'd209715};
                            8'h81: {Afix, Bfix, Cfix, Dfix} = {24'd7, 24'd284, 24'd10923, 24'd419430};
                            default: {Afix, Bfix, Cfix, Dfix} = {24'd474, 24'd2276, 24'd10923, 24'd52429};
                        endcase
                        
                        // DSP multiply for coefficient scaling
                        k1_3 <= a1 * Afix; k1_2 <= b1 * Bfix; 
                        k1_1 <= c1 * Cfix; k1_0 <= d1 * Dfix;
                        k2_3 <= a2 * Afix; k2_2 <= b2 * Bfix; 
                        k2_1 <= c2 * Cfix; k2_0 <= d2 * Dfix;
                    end
                    
                    xx = $signed({1'b0, compute_x}) - $signed(X0);
                    
                    case (poly_state)
                        0: begin
                            t1 <= (k1_3 * xx) + k1_2; 
                            t2 <= (k2_3 * xx) + k2_2;
                            poly_state <= 1;
                        end
                        1: begin
                            t1 <= (t1 * xx) + k1_1; 
                            t2 <= (t2 * xx) + k2_1;
                            poly_state <= 2;
                        end
                        2: begin
                            y1_offi <= (t1 * xx) + k1_0; 
                            y2_offi <= (t2 * xx) + k2_0;
                            poly_state <= 3;
                        end
                        3: begin
                            poly1_y[compute_x] <= Y0 - (y1_offi >>> Q);
                            poly2_y[compute_x] <= Y0 - (y2_offi >>> Q);
                            
                            if (compute_x == 95) begin
                                main_state <= DISPLAY;
                                precompute_done <= 1; done <= 1;
                            end else begin
                                compute_x <= compute_x + 1;
                                poly_state <= 0;
                            end
                        end
                    endcase
                end
                
                DISPLAY: begin
                    if (!enable) begin
                        main_state <= IDLE;
                        precompute_done <= 0; done <= 0;
                    end else if (zoom_changed) begin
                        main_state <= COMPUTE_POLY;
                        compute_x <= 0; poly_state <= 0;
                        precompute_done <= 0; done <= 0;
                    end
                end
            endcase
        end
    end
    
    wire signed [15:0] y1a_cmp = poly1_y[x];
    wire signed [15:0] y1b_cmp = (x > 0) ? poly1_y[x-1] : poly1_y[x];
    wire signed [15:0] y2a_cmp = poly2_y[x];
    wire signed [15:0] y2b_cmp = (x > 0) ? poly2_y[x-1] : poly2_y[x];
    
    wire signed [15:0] y1min = (y1a_cmp < y1b_cmp) ? y1a_cmp : y1b_cmp;
    wire signed [15:0] y1max = (y1a_cmp > y1b_cmp) ? y1a_cmp : y1b_cmp;
    wire signed [15:0] y2min = (y2a_cmp < y2b_cmp) ? y2a_cmp : y2b_cmp;
    wire signed [15:0] y2max = (y2a_cmp > y2b_cmp) ? y2a_cmp : y2b_cmp;
    
    wire signed [7:0] ys = $signed({1'b0, y});
    
    wire on_poly1 = (ys >= y1min) && (ys <= y1max);
    wire on_poly2 = (ys >= y2min) && (ys <= y2max);
    wire on_axes = (x == X0) || (y == Y0);
    
    always @(*) begin
        oled = BLACK;
        if (precompute_done && enable) begin
            if (on_poly1) oled = ORANGE;
            else if (on_poly2) oled = BLUE;
            if (on_axes) oled = WHITE;
        end
    end
    
endmodule