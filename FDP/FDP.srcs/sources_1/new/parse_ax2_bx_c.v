// Optimized parser - targets <40% LUT usage
module parse_ax2_bx_c #(
  parameter MAXLEN = 48
)(
  input  wire        clk,
  input  wire        rst,
  input  wire        start,
  input  wire [5:0]  len,
  output reg  [5:0]  addr,
  input  wire [7:0]  din,
  output reg  signed [31:0] a = 0,
  output reg  signed [31:0] b = 0,
  output reg  signed [31:0] c = 0,
  output reg  [1:0]  degree = 0,
  output reg         done = 0
);

  reg        busy = 0;
  reg  [5:0] i = 0;
  reg        phase = 1'b0;

  // OPTIMIZATION 1: Reduce accumulator from 32-bit to 16-bit
  // Most user inputs won't exceed 16-bit range
  reg signed [15:0] acc = 0;
  
  reg        seen_digit = 0;
  reg        sign_neg   = 0;
  reg        term_is_x  = 0;
  reg        pow2       = 0;
  reg        caret      = 0;

  // OPTIMIZATION 2: Use wire instead of reg for temporary values where possible
  wire [7:0] chr = (i < len) ? din : 8'h00;
  wire is_digit = (chr >= "0" && chr <= "9");
  wire is_var = (chr == "x" || chr == "X" || chr == "y" || chr == "Y");
  wire is_term_end = (i == len || chr == "+" || chr == "-");
  
  // OPTIMIZATION 3: Simplify coefficient calculation
  wire signed [15:0] acc_eff = (term_is_x && !seen_digit) ? 16'sd1 : 
                                (sign_neg ? -acc : acc);

  always @(posedge clk) begin
    if (rst) begin
      a<=0; b<=0; c<=0; degree<=0; done<=0;
      busy<=0; i<=0; phase<=1'b0; addr<=0;
      acc<=0; seen_digit<=0; sign_neg<=0; term_is_x<=0; pow2<=0; caret<=0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        a<=0; b<=0; c<=0; degree<=0;
        busy<=1'b1; i<=0; phase<=1'b0; addr<=0;
        acc<=0; seen_digit<=0; sign_neg<=0; term_is_x<=0; pow2<=0; caret<=0;
      end
      else if (busy) begin
        if (phase == 1'b0) begin
          addr  <= i;
          phase <= 1'b1;
        end else begin
          phase <= 1'b0;
          
          // OPTIMIZATION 4: Simplified term finalization
          if (is_term_end) begin
            // Commit coefficient
            if (term_is_x && pow2) begin
              a <= a + {{16{acc_eff[15]}}, acc_eff}; // sign-extend 16->32
              if (degree < 2) degree <= 2;
            end else if (term_is_x) begin
              b <= b + {{16{acc_eff[15]}}, acc_eff};
              if (degree < 1) degree <= 1;
            end else begin
              c <= c + {{16{acc_eff[15]}}, acc_eff};
            end

            // Reset for next term
            acc        <= 0;
            seen_digit <= 0;
            term_is_x  <= 0;
            pow2       <= 0;
            caret      <= 0;
            sign_neg   <= (chr == "-");

            if (i == len) begin
              busy <= 1'b0; 
              done <= 1'b1;
            end else begin
              i <= i + 1;
            end
          end else begin
            // OPTIMIZATION 5: Simplified character processing
            if (caret) begin
              if (chr == "2") begin 
                pow2 <= 1'b1; 
                if (degree < 2) degree <= 2; 
              end else if (chr == "3") begin
                degree <= 3;
              end
              caret <= 1'b0;
            end else if (is_digit) begin
              // OPTIMIZATION 6: Saturate instead of overflow
              // Prevents large multiplier
              acc <= (acc < 16'sd3276) ? (acc * 4'd10 + {12'd0, chr[3:0]}) : acc;
              seen_digit <= 1'b1;
            end else if (is_var) begin
              term_is_x <= 1'b1;
              if (degree < 1) degree <= 1;
            end else if (chr == "^") begin
              caret <= 1'b1;
            end
            
            i <= i + 1;
          end
        end
      end
    end
  end

endmodule