`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2025 05:54:23 PM
// Design Name: 
// Module Name: aidan
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

module aidan (
    input clk,                      // 100 MHz clock
    input [4:0] pb,                 // pb[0]=C, pb[1]=U, pb[2]=L, pb[3]=R, pb[4]=D
    input [15:0] sw,                // switches (8 bits for A, 8 bits for B)
    input [12:0] pixel_index,       // pixel index from shared OLED driver
    output reg [15:0] aidan_oleddata // output color for this pixel
);

    // Screen coordinates
    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;

    //------------------------------------------------------------
    // Clock divider for button debouncing (1 kHz tick)
    //------------------------------------------------------------
    reg [16:0] ms_counter = 0;
    reg ms_tick = 0;
    always @(posedge clk) begin
        if (ms_counter == 99999) begin
            ms_counter <= 0;
            ms_tick <= 1;
        end else begin
            ms_counter <= ms_counter + 1;
            ms_tick <= 0;
        end
    end

    // Animation counter removed to save LUTs

    //------------------------------------------------------------
    // Button control logic - Simplified
    //------------------------------------------------------------
    reg [2:0] operation = 0;      // 000-101: 6 operations (removed MRG and SHL)
    reg [1:0] display_mode = 0;   // 00: Binary, 01: Octal, 10: Hexadecimal
    reg theme_mode = 0;           // 0: Classic, 1: Matrix (removed Neon)
    reg btnU_prev = 0, btnD_prev = 0, btnL_prev = 0, btnR_prev = 0;
    
    // History storage - Reduced to 2 results
    reg [8:0] history [0:1];
    reg history_ptr = 0;
    reg history_mode = 0; // 0: normal, 1: show history

    always @(posedge clk) begin
        if (pb[0]) begin  // Center button = reset
            operation <= 0;
            display_mode <= 0;
            theme_mode <= 0;
            history_mode <= 0;
            btnU_prev <= 0;
            btnD_prev <= 0;
            btnL_prev <= 0;
            btnR_prev <= 0;
            history_ptr <= 0;
        end else if (ms_tick) begin
            // pb[1] (Up) to cycle operations (6 operations)
            if (pb[1] && !btnU_prev) begin
                operation <= (operation == 5) ? 0 : operation + 1;
                // Store result in history when operation changes
                history[history_ptr] <= result;
                history_ptr <= ~history_ptr;
            end
            // pb[4] (Down) to cycle display modes
            if (pb[4] && !btnD_prev)
                display_mode <= (display_mode == 2) ? 0 : display_mode + 1;
            // pb[2] (Left) to toggle theme
            if (pb[2] && !btnL_prev)
                theme_mode <= ~theme_mode;
            // pb[3] (Right) to toggle history view
            if (pb[3] && !btnR_prev)
                history_mode <= !history_mode;
                
            btnU_prev <= pb[1];
            btnD_prev <= pb[4];
            btnL_prev <= pb[2];
            btnR_prev <= pb[3];
        end
    end

    //------------------------------------------------------------
    // Operand and Result Computation - Reduced to 6 operations
    //------------------------------------------------------------
    wire [7:0] operand_a = sw[7:0];
    wire [7:0] operand_b = sw[15:8];
    reg [8:0] result; // 9 bits to handle carry/overflow

    always @(*) begin
        case (operation)
            3'b000: result = {1'b0, operand_a & operand_b};      // AND
            3'b001: result = {1'b0, operand_a | operand_b};      // OR
            3'b010: result = {1'b0, operand_a ^ operand_b};      // XOR
            3'b011: result = operand_a + operand_b;              // ADD
            3'b100: result = {1'b0, operand_a ~^ operand_b};     // XNOR
            3'b101: result = (operand_a > operand_b) ? 9'd1 : 9'd0; // Greater Than
            default: result = 9'd0;
        endcase
    end

    // Statistics removed to save LUTs

    //------------------------------------------------------------
    // Character font (5x7) - Column major format
    //------------------------------------------------------------
    function [34:0] get_char;
        input [7:0] char;
        begin
            case (char)
                "0": get_char = {7'b0111110, 7'b1010001, 7'b1001001, 7'b1000101, 7'b0111110};
                "1": get_char = {7'b0000000, 7'b1000010, 7'b1111111, 7'b1000000, 7'b0000000};
                "2": get_char = {7'b0110010, 7'b1001001, 7'b1001001, 7'b1001001, 7'b1000110};
                "3": get_char = {7'b0100010, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0110110};
                "4": get_char = {7'b0000111, 7'b0001000, 7'b0001000, 7'b0001000, 7'b1111111};
                "5": get_char = {7'b0100111, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0111001};
                "6": get_char = {7'b0111110, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0110010};
                "7": get_char = {7'b0000001, 7'b1110001, 7'b0001001, 7'b0000101, 7'b0000011};
                "8": get_char = {7'b0110110, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0110110};
                "9": get_char = {7'b0100110, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0111110};
                "A": get_char = {7'b1111110, 7'b0001001, 7'b0001001, 7'b0001001, 7'b1111110};
                "B": get_char = {7'b1111111, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0110110};
                "C": get_char = {7'b0111110, 7'b1000001, 7'b1000001, 7'b1000001, 7'b0100010};
                "D": get_char = {7'b1111111, 7'b1000001, 7'b1000001, 7'b1000001, 7'b0111110};
                "E": get_char = {7'b1111111, 7'b1001001, 7'b1001001, 7'b1001001, 7'b1000001};
                "F": get_char = {7'b1111111, 7'b0001001, 7'b0001001, 7'b0001001, 7'b0000001};
                "G": get_char = {7'b0111110, 7'b1000001, 7'b1001001, 7'b1001001, 7'b0111010};
                "H": get_char = {7'b1111111, 7'b0001000, 7'b0001000, 7'b0001000, 7'b1111111};
                "I": get_char = {7'b0000000, 7'b1000001, 7'b1111111, 7'b1000001, 7'b0000000};
                "L": get_char = {7'b1111111, 7'b1000000, 7'b1000000, 7'b1000000, 7'b1000000};
                "M": get_char = {7'b1111111, 7'b0000010, 7'b0001100, 7'b0000010, 7'b1111111};
                "N": get_char = {7'b1111111, 7'b0000100, 7'b0001000, 7'b0010000, 7'b1111111};
                "O": get_char = {7'b0111110, 7'b1000001, 7'b1000001, 7'b1000001, 7'b0111110};
                "R": get_char = {7'b1111111, 7'b0001001, 7'b0001001, 7'b0001001, 7'b1110110};
                "S": get_char = {7'b0100110, 7'b1001001, 7'b1001001, 7'b1001001, 7'b0110010};
                "T": get_char = {7'b0000001, 7'b0000001, 7'b1111111, 7'b0000001, 7'b0000001};
                "X": get_char = {7'b1100011, 7'b0010100, 7'b0001000, 7'b0010100, 7'b1100011};
                ">": get_char = {7'b1000001, 7'b0100010, 7'b0010100, 7'b0001000, 7'b0000000};
                "<": get_char = {7'b0001000, 7'b0010100, 7'b0100010, 7'b1000001, 7'b0000000};
                "=": get_char = {7'b0010100, 7'b0010100, 7'b0010100, 7'b0010100, 7'b0010100};
                ":": get_char = {7'b0000000, 7'b0000000, 7'b0100100, 7'b0000000, 7'b0000000};
                "-": get_char = {7'b0001000, 7'b0001000, 7'b0001000, 7'b0001000, 7'b0001000};
                default: get_char = {7'b0000000, 7'b0000000, 7'b0000000, 7'b0000000, 7'b0000000};
            endcase
        end
    endfunction

    //------------------------------------------------------------
    // Pixel-in-character detection
    //------------------------------------------------------------
    function pixel_in_char;
        input [6:0] px, char_x;
        input [5:0] py, char_y;
        input [7:0] character;
        reg [34:0] char_data;
        reg [6:0] rel_x;
        reg [5:0] rel_y;
        reg [2:0] col, row;
        begin
            rel_x = px - char_x;
            rel_y = py - char_y;
            if (rel_x < 5 && rel_y < 7) begin
                char_data = get_char(character);
                col = 4 - rel_x;
                row = rel_y; 
                pixel_in_char = char_data[col * 7 + row];
            end else
                pixel_in_char = 0;
        end
    endfunction

    //------------------------------------------------------------
    // Helper to draw binary digit
    //------------------------------------------------------------
    function pixel_in_binary;
        input [6:0] px, start_x;
        input [5:0] py, start_y;
        input [8:0] value;
        input [3:0] bit_pos;
        reg bit_val;
        begin
            bit_val = value[bit_pos];
            pixel_in_binary = pixel_in_char(px, start_x + (8 - bit_pos) * 8, py, start_y, bit_val ? "1" : "0");
        end
    endfunction

    //------------------------------------------------------------
    // Helper to convert 4-bit value to hex character
    //------------------------------------------------------------
    function [7:0] nibble_to_hex;
        input [3:0] nibble;
        begin
            if (nibble < 10)
                nibble_to_hex = "0" + nibble;
            else
                nibble_to_hex = "A" + (nibble - 10);
        end
    endfunction

    //------------------------------------------------------------
    // Helper to convert 3-bit value to octal character
    //------------------------------------------------------------
    function [7:0] trio_to_oct;
        input [2:0] trio;
        begin
            trio_to_oct = "0" + trio;
        end
    endfunction

    //------------------------------------------------------------
    // Color theme selection (2 themes only)
    //------------------------------------------------------------
    wire [15:0] text_color = theme_mode ? 16'h07E0 : 16'hFFFF;      // Matrix green or Classic white
    wire [15:0] bg_color = 16'h0000;                                 // Always black
    wire [15:0] accent_color = theme_mode ? 16'h07E0 : 16'h7BEF;    // Green or light gray

    //------------------------------------------------------------
    // Pixel rendering logic
    //------------------------------------------------------------
    reg is_text_pixel;
    reg is_accent_pixel;
    
    always @(*) begin
        aidan_oleddata = bg_color;
        is_text_pixel = 0;
        is_accent_pixel = 0;

        if (!history_mode) begin
            // Normal calculator display
            
            // Display mode indicator (top right corner)
            case (display_mode)
                2'b00: is_text_pixel = pixel_in_char(x, 64, y, 2, "B") | pixel_in_char(x, 72, y, 2, "I") | 
                                       pixel_in_char(x, 80, y, 2, "N");
                2'b01: is_text_pixel = pixel_in_char(x, 64, y, 2, "O") | pixel_in_char(x, 72, y, 2, "C") | 
                                       pixel_in_char(x, 80, y, 2, "T");
                2'b10: is_text_pixel = pixel_in_char(x, 64, y, 2, "H") | pixel_in_char(x, 72, y, 2, "E") | 
                                       pixel_in_char(x, 80, y, 2, "X");
            endcase

            // Display operation label (top left) - 6 operations
            case (operation)
                3'b000: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "A") | pixel_in_char(x, 12, y, 2, "N") | pixel_in_char(x, 20, y, 2, "D");
                3'b001: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "O") | pixel_in_char(x, 12, y, 2, "R");
                3'b010: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "X") | pixel_in_char(x, 12, y, 2, "O") | pixel_in_char(x, 20, y, 2, "R");
                3'b011: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "A") | pixel_in_char(x, 12, y, 2, "D") | pixel_in_char(x, 20, y, 2, "D");
                3'b100: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "X") | pixel_in_char(x, 12, y, 2, "N") | pixel_in_char(x, 20, y, 2, "O") | pixel_in_char(x, 28, y, 2, "R");
                3'b101: is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 2, "G") | pixel_in_char(x, 12, y, 2, "T");
            endcase

            // Display based on mode
            case (display_mode)
                2'b00: begin // Binary mode
                    // Display operand A (binary)
                    is_text_pixel = is_text_pixel | 
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 7) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 6) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 5) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 4) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 3) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 2) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 1) |
                        pixel_in_binary(x, 16, y, 15, {1'b0, operand_a}, 0);

                    // Display operand B (binary)
                    is_text_pixel = is_text_pixel | 
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 7) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 6) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 5) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 4) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 3) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 2) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 1) |
                        pixel_in_binary(x, 16, y, 28, {1'b0, operand_b}, 0);

                    // Display equals sign
                    is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 41, "=");

                    // Display result (binary, 9 bits)
                    is_accent_pixel = 
                        pixel_in_binary(x, 10, y, 50, result, 8) |
                        pixel_in_binary(x, 10, y, 50, result, 7) |
                        pixel_in_binary(x, 10, y, 50, result, 6) |
                        pixel_in_binary(x, 10, y, 50, result, 5) |
                        pixel_in_binary(x, 10, y, 50, result, 4) |
                        pixel_in_binary(x, 10, y, 50, result, 3) |
                        pixel_in_binary(x, 10, y, 50, result, 2) |
                        pixel_in_binary(x, 10, y, 50, result, 1) |
                        pixel_in_binary(x, 10, y, 50, result, 0);
                end

                2'b01: begin // Octal mode
                    // Display operand A (octal)
                    is_text_pixel = is_text_pixel |
                        pixel_in_char(x, 28, y, 15, trio_to_oct(operand_a[7:6])) |
                        pixel_in_char(x, 36, y, 15, trio_to_oct(operand_a[5:3])) |
                        pixel_in_char(x, 44, y, 15, trio_to_oct(operand_a[2:0]));

                    // Display operand B (octal)
                    is_text_pixel = is_text_pixel |
                        pixel_in_char(x, 28, y, 28, trio_to_oct(operand_b[7:6])) |
                        pixel_in_char(x, 36, y, 28, trio_to_oct(operand_b[5:3])) |
                        pixel_in_char(x, 44, y, 28, trio_to_oct(operand_b[2:0]));

                    // Display equals sign
                    is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 41, "=");

                    // Display result (octal)
                    is_accent_pixel =
                        pixel_in_char(x, 28, y, 50, trio_to_oct(result[8:6])) |
                        pixel_in_char(x, 36, y, 50, trio_to_oct(result[5:3])) |
                        pixel_in_char(x, 44, y, 50, trio_to_oct(result[2:0]));
                end

                2'b10: begin // Hexadecimal mode
                    // Display operand A (hex)
                    is_text_pixel = is_text_pixel |
                        pixel_in_char(x, 36, y, 15, nibble_to_hex(operand_a[7:4])) |
                        pixel_in_char(x, 44, y, 15, nibble_to_hex(operand_a[3:0]));

                    // Display operand B (hex)
                    is_text_pixel = is_text_pixel |
                        pixel_in_char(x, 36, y, 28, nibble_to_hex(operand_b[7:4])) |
                        pixel_in_char(x, 44, y, 28, nibble_to_hex(operand_b[3:0]));

                    // Display equals sign
                    is_text_pixel = is_text_pixel | pixel_in_char(x, 4, y, 41, "=");

                    // Display result (hex)
                    is_accent_pixel =
                        pixel_in_char(x, 28, y, 50, nibble_to_hex({3'b0, result[8]})) |
                        pixel_in_char(x, 36, y, 50, nibble_to_hex(result[7:4])) |
                        pixel_in_char(x, 44, y, 50, nibble_to_hex(result[3:0]));
                end
            endcase
            
        end else begin
            // History display mode - 2 results only
            is_text_pixel = pixel_in_char(x, 24, y, 2, "H") | pixel_in_char(x, 32, y, 2, "I") | 
                           pixel_in_char(x, 40, y, 2, "S") | pixel_in_char(x, 48, y, 2, "T");
            
            // Display last 2 results
            is_text_pixel = is_text_pixel |
                pixel_in_char(x, 10, y, 20, nibble_to_hex(history[0][7:4])) |
                pixel_in_char(x, 18, y, 20, nibble_to_hex(history[0][3:0])) |
                pixel_in_char(x, 10, y, 35, nibble_to_hex(history[1][7:4])) |
                pixel_in_char(x, 18, y, 35, nibble_to_hex(history[1][3:0]));
        end

        // Apply colors
        if (is_accent_pixel)
            aidan_oleddata = accent_color;
        else if (is_text_pixel)
            aidan_oleddata = text_color;
    end

endmodule