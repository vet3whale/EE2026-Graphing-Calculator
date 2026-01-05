`timescale 1ns / 1ps

module mainmenu ( input CLOCK, input reset, input [12:0] pixel_index,
                  input [6:0] mx, input [5:0] my, input click_rise, input click_fall, 
                  output reg en_vetri = 0, output reg en_nic = 0, output reg en_ryan = 0, output reg en_aidan = 0,
                  output [15:0] mainmenu_oleddata);

    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;
        
    localparam [6:0] W = 7'd22;
    localparam [5:0] H = 6'd20;
        
    localparam [6:0] CX = 7'd48;
    localparam [6:0] X_MARGIN = 7'd8;
    localparam [6:0] X_LFT = X_MARGIN;
    localparam [6:0] X_RGT = 7'd96 - X_MARGIN - W;
    localparam [6:0] X_CEN = CX - (W>>1);
    
    localparam [5:0] Y_TOP = 6'd0;
    localparam [5:0] Y_MID = Y_TOP + H + 6'd2;
    localparam [5:0] Y_BOT = Y_MID + H + 6'd2;
    
    // Target zone in center for activation (middle square area)
    localparam [6:0] TARGET_X_MIN = CX - (W>>1);     // 48 - (22/2) = 37
    localparam [6:0] TARGET_X_MAX = CX + (W>>1) - 1; // 48 + (22/2) - 1 = 58
    localparam [5:0] TARGET_Y_MIN = 32 - (H>>1);     // 32 - (20/2) = 22
    localparam [5:0] TARGET_Y_MAX = 32 + (H>>1) - 1; // 32 + (20/2) - 1 = 41
    
    // Colors
    localparam [15:0] BLACK = 16'h0000;
    localparam [15:0] WHITE = 16'hFFFF;
    localparam [15:0] GREEN = 16'h07E0;
    localparam [15:0] PINK  = 16'hF81F;
    localparam [15:0] RED   = 16'hF800;
    localparam [15:0] BLUE  = 16'h001F;
    
    // make it look sick
    parameter METALLIC_GRAY = 16'b10110_101101_10110;
    parameter CURSOR_CYAN = 16'b00000_111111_11111;
    parameter HOVER_TEAL = 16'b00111_110110_10111;
    
    reg [2:0] drag_state = 0;
    reg [2:0] selected_box = 0;
    // Box positions: [0]=vetri(top), [1]=nic(left), [2]=ryan(right), [3]=aidan(bottom)
    reg [6:0] box_x [0:3];
    reg [5:0] box_y [0:3];
    reg dragging = 0;
    reg [5:0] drag_offset_y = 0;
    reg [6:0] drag_offset_x = 0;

    // Initialize box positions
    initial begin
        box_x[0] = X_CEN; box_y[0] = Y_TOP;  // Mode 1 (vetri) - top
        box_x[1] = X_LFT; box_y[1] = Y_MID;  // Mode 2 (nic) - left
        box_x[2] = X_RGT; box_y[2] = Y_MID;  // Mode 3 (ryan) - right
        box_x[3] = X_CEN; box_y[3] = Y_BOT;  // Mode 4 (aidan) - bottom
    end

    // Rectangle hit test function
    function in_rect;
        input [6:0] xq; input [5:0] yq;
        input [6:0] left; input [5:0] top;
        input [6:0] w; input [5:0] h;
        reg [7:0] xq8, right_x, left_x;
        reg [7:0] yq8, bottom_y, top_y;
        begin
            left_x = {1'b0, left}; right_x  = {1'b0, left} + {1'b0, w};
            top_y = {2'b00, top}; bottom_y = {2'b00, top} + {2'b00, h};
            xq8 = {1'b0, xq}; yq8      = {2'b00, yq};
            in_rect = (xq8 >= left_x) && (xq8 < right_x) &&
                       (yq8 >= top_y) && (yq8 < bottom_y);
        end
    endfunction

    // Box rendering
    wire [3:0] in_box, box_border, box_fill;
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : box_gen
            assign in_box[i] = in_rect(x, y, box_x[i], box_y[i], W, H);
            assign box_border[i] = in_box[i] && 
                                   ((x == box_x[i]) || (x == box_x[i] + W - 1) || 
                                    (y == box_y[i]) || (y == box_y[i] + H - 1));
            assign box_fill[i] = in_box[i] && !box_border[i];
        end
    endgenerate
    
    // Dotted Line Box
    wire in_target_x_range = (x >= TARGET_X_MIN) && (x <= TARGET_X_MAX);
    wire in_target_y_range = (y >= TARGET_Y_MIN) && (y <= TARGET_Y_MAX);
       
    // Check if pixel is on the border
    wire on_target_top_bottom = (y == TARGET_Y_MIN || y == TARGET_Y_MAX) && in_target_x_range;
    wire on_target_left_right = (x == TARGET_X_MAX || x == TARGET_X_MIN) && in_target_y_range;
    
    // Create the "dotted" effect (2px on, 2px off)
    wire horizontal_dash = (x[1] == 0); // (x % 4 < 2)
    wire vertical_dash   = (y[1] == 0); // (y % 4 < 2)
    
    wire target_box_on = (on_target_top_bottom && horizontal_dash) || (on_target_left_right && vertical_dash);
    
    // Cursor rendering (3x3 pink square)
    wire [6:0] cur_left = (mx == 0) ? 7'd0 : (mx - 1);
    wire [5:0] cur_top  = (my == 0) ? 6'd0 : (my - 1);
    wire cursor_on = in_rect(x, y, cur_left, cur_top, 7'd3, 6'd3);

    // Digit rendering (5x7 scaled to 10x14)
    function draw_digit1to4;
        input [2:0] d;
        input signed [6:0] rx;
        input signed [5:0] ry;
        reg [4:0] row;
        begin
            case (d)
                3'd1: case(ry) // G --> vetri
                        0:   row = 5'b01110; 
                        1:   row = 5'b10001; 
                        2:   row = 5'b10000; 
                        3:   row = 5'b10111; 
                        4,5: row = 5'b10001; 
                        6:   row = 5'b01110; 
                        default: row = 0; 
                    endcase
                3'd2: case(ry) // M --> nic
                        0,4,5,6: row = 5'b10001; 
                        1: row = 5'b11011; 
                        2: row = 5'b10101; 
                        3: row = 5'b10001; 
                        default: row = 0; 
                      endcase
                3'd3: case(ry) // P --> ryan
                            0: row = 5'b11110; 
                            1,2: row = 5'b10001; 
                            3: row = 5'b11110; 
                            4,5,6: row = 5'b10000; 
                            default: row = 0; 
                      endcase
                3'd4: case(ry) // B --> Aidan
                            0,3,6: row = 5'b11110; 
                            1,2,4,5: row = 5'b10001; 
                            default: row = 0; 
                      endcase
                default: row = 5'b00000;
            endcase
            draw_digit1to4 = row[4-rx[2:0]];
        end
    endfunction

    function draw_center_digit;
        input [6:0] X0; 
        input [5:0] Y0;
        input [2:0] d;
        reg signed [6:0] rx; 
        reg signed [5:0] ry;
        begin
            rx = x - (X0 + (W-10)/2);
            ry = y - (Y0 + (H-14)/2);
            if (rx>=0 && rx<10 && ry>=0 && ry<14) begin
                draw_center_digit = draw_digit1to4(d, rx[6:0]>>1, ry[5:0]>>1);
            end else draw_center_digit = 1'b0;
        end
    endfunction

    wire d1 = draw_center_digit(box_x[0], box_y[0], 3'd1);
    wire d2 = draw_center_digit(box_x[1], box_y[1], 3'd2);
    wire d3 = draw_center_digit(box_x[2], box_y[2], 3'd3);
    wire d4 = draw_center_digit(box_x[3], box_y[3], 3'd4);

    // Hover detection
    wire h1 = in_rect(mx, my, box_x[0], box_y[0], W, H);
    wire h2 = in_rect(mx, my, box_x[1], box_y[1], W, H);
    wire h3 = in_rect(mx, my, box_x[2], box_y[2], W, H);
    wire h4 = in_rect(mx, my, box_x[3], box_y[3], W, H);
    // make it look sick
    localparam STEEL_BLUE   = 16'h5ACB;
    localparam NEON_CYAN    = 16'h07FF;
    localparam ORANGE_FLARE = 16'hFD20;
    
    // Main menu rendering with fill colors
    assign mainmenu_oleddata = cursor_on ? ORANGE_FLARE :
                               (box_border[0] || d1) ? BLACK :
                               (box_fill[0] && h1) ? NEON_CYAN : box_fill[0] ? STEEL_BLUE :
                               (box_border[1] || d2) ? BLACK :
                               (box_fill[1] && h2) ? NEON_CYAN : box_fill[1] ? STEEL_BLUE :
                               (box_border[2] || d3) ? BLACK :
                               (box_fill[2] && h3) ? NEON_CYAN : box_fill[2] ? STEEL_BLUE :
                               (box_border[3] || d4) ? BLACK :
                               (box_fill[3] && h4) ? NEON_CYAN : box_fill[3] ? STEEL_BLUE :
                               (target_box_on) ? WHITE :
                               BLACK;
    reg [15:0] midptx, midpty;
    // Drag box state machine
    always @(posedge CLOCK) begin
        if (reset) begin 
            drag_state <= 0; 
            en_vetri <= 0; en_nic <= 0; en_ryan <= 0; en_aidan <= 0;
            box_x[0] <= X_CEN; box_y[0] <= Y_TOP; box_x[1] <= X_LFT; box_y[1] <= Y_MID;
            box_x[2] <= X_RGT; box_y[2] <= Y_MID; box_x[3] <= X_CEN; box_y[3] <= Y_BOT;
            dragging <= 0; drag_offset_y <= 0; drag_offset_x <= 0;
        end else begin
            case (drag_state)
                3'd0: begin // idle state
                    en_vetri <= 0; en_nic <= 0; en_ryan <= 0; en_aidan <= 0;
                    dragging <= 0;
                    if (click_rise) begin
                        if (in_rect(mx, my, box_x[0], box_y[0], W, H)) 
                            selected_box = 0;
                        else if (in_rect(mx, my, box_x[1], box_y[1], W, H))
                            selected_box = 1; 
                        else if (in_rect(mx, my, box_x[2], box_y[2], W, H))
                            selected_box = 2; 
                        else if (in_rect(mx, my, box_x[3], box_y[3], W, H))
                            selected_box = 3; 
                        if (in_rect(mx, my, box_x[selected_box], box_y[selected_box], W, H)) begin    
                            drag_state <= 3'd1; 
                            dragging <= 1;
                            drag_offset_y <= my - box_y[selected_box];
                            drag_offset_x <= mx - box_x[selected_box];
                        end
                    end
                end
                
                3'd1: begin  // Dragging
                    if (click_fall) begin
                        // Mouse released - check if in target zone
                        midptx = box_x[selected_box] + (W>>2);
                        midpty = box_y[selected_box] + (H>>2);
                        if (midptx >= TARGET_X_MIN && midptx <= TARGET_X_MAX &&
                            midpty >= TARGET_Y_MIN && midpty <= TARGET_Y_MAX)
                            drag_state <= 3'd2;  // Activate module
                        else 
                            drag_state <= 3'd3;  // Bounce back
                        
                        dragging <= 0;
                    end else begin
                        // Continue dragging - update position every cycle
                        if (selected_box == 0) begin
                            box_x[0] <= X_CEN;
                            if (my >= drag_offset_y) begin
                                if ((my - drag_offset_y) >= Y_TOP) box_y[0] <= my - drag_offset_y;
                                else box_y[0] <= Y_TOP;
                            end 
                            else box_y[0] <= Y_TOP;
                        end
                        else if (selected_box == 3) begin
                            box_x[3] <= X_CEN;
                            if (my >= drag_offset_y) begin
                                if ((my - drag_offset_y) <= Y_BOT) box_y[3] <= my - drag_offset_y;
                                else box_y[3] <= Y_BOT;
                            end 
                            else box_y[3] <= 0;
                        end
                        else if (selected_box == 1) begin
                            box_y[1] <= Y_MID;
                            if (mx >= drag_offset_x) begin
                                if ((mx - drag_offset_x) >= X_LFT) box_x[1] <= mx - drag_offset_x;
                                else box_x[1] <= X_LFT;
                            end 
                            else box_x[1] <= X_LFT;
                        end
                        else if (selected_box == 2) begin
                            box_y[2] <= Y_MID;
                            if (mx >= drag_offset_x) begin
                                if ((mx - drag_offset_x) <= X_RGT) box_x[2] <= mx - drag_offset_x;
                                else box_x[2] <= X_RGT;
                            end 
                            else box_x[2] <= 0;
                        end
                    end
                end
                
                3'd2: begin
                    dragging <= 0;
                    case (selected_box)
                        3'd0: en_vetri <= 1;
                        3'd1: en_nic <= 1;
                        3'd2: en_ryan <= 1;
                        3'd3: en_aidan <= 1;
                    endcase
                end
                
                3'd3: begin  // Bounce back to origin
                    box_x[0] <= X_CEN; box_y[0] <= Y_TOP;
                    box_x[1] <= X_LFT; box_y[1] <= Y_MID;
                    box_x[2] <= X_RGT; box_y[2] <= Y_MID;
                    box_x[3] <= X_CEN; box_y[3] <= Y_BOT;
                    drag_state <= 3'd0; // go back idle
                end

            endcase
        end
    end

endmodule