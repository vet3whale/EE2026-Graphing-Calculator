module int_sqrt32(
  input  wire [31:0] x,
  output wire [15:0] y
);
  reg [15:0] root_internal;
  integer i;
  reg [31:0] a;
  reg [17:0] rem;
  reg [15:0] root;
  reg [17:0] trial;
  
  always @* begin
    a    = x;
    rem  = 18'd0;
    root = 16'd0;
    
    for (i = 0; i < 16; i = i + 1) begin
      rem = {rem[15:0], a[31:30]};
      a   = {a[29:0], 2'b00};
      trial = {1'b0, root, 1'b1};
      
      if (rem >= trial) begin
        rem  = rem - trial;
        root = {root[14:0], 1'b1};
      end else begin
        root = {root[14:0], 1'b0};
      end
    end
    
    // Final check: if root² > x, decrement root
    root_internal = root;
    if (root * root > x && root > 0) begin
      root_internal = root - 1;
    end
  end
  
  assign y = root_internal;
endmodule