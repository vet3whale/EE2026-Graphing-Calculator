module mode_plot(
    input  [11:0] mouse_x, input [11:0] mouse_y, input mouse_l, input mouse_m, input [4:0] pb, input reset, input [12:0] pixel_index, input sample_pixel,
    output reg [15:0] plot_oleddata,
    input clk_100M, input plot_enable);
    // Colors
    localparam [15:0] WHITE = 16'b11111_111111_11111;
    localparam [15:0] BLACK = 16'b00000_000000_00000;
    localparam [15:0] GREEN = 16'b00000_011000_00000;

    wire [6:0] x = pixel_index % 96;
    wire [6:0] y = pixel_index / 96;
        
    // engage mouse
    wire [6:0] mx, my;
    wire l_sync, click_rise, click_fall;
    mouse_io plot_mouse(.mouse_x(mouse_x), .mouse_y(mouse_y), .mouse_l(mouse_l), .reset(reset), .clk(clk_100M),
                        .mx(mx), .my(my), .l_sync(l_sync), .click_rise(click_rise), .click_fall(click_fall));
    // mouse pointer
    wire pointer = ((x == mx) || (x+1 == mx) || (mx+1 == x)) &&
                   ((y == my) || (y+1 == my) || (my+1 == y));
    
    wire [15:0] eqn1_type_oled, eqn1_coef_oled, eqn2_type_oled, eqn2_coef_oled, graph_oled, data_oled;
    reg eqn1_coef_enable, eqn2_type_enable, eqn2_coef_enable, graph_enable;
    wire eqn1_coef_pulse, eqn2_type_pulse, eqn2_coef_pulse, graph_pulse;
    reg m_sync0, m_sync1; reg m_prev; // for rising edge
    wire m_click_rise;
    // middle button goes to prev page
    always @(posedge clk_100M or posedge reset) begin
      if (reset) begin
        m_sync0 <= 1'b0; m_sync1 <= 1'b0; m_prev <= 1'b0;
      end else begin
        m_sync0 <= mouse_m; // synchronize
        m_sync1 <= m_sync0;
        m_prev  <= m_sync1; // delay for edge detect
      end
    end
    assign m_click_rise = m_sync1 & ~m_prev;

    always @(posedge clk_100M or posedge reset) begin
        if (reset) begin 
            eqn1_coef_enable <= 0; eqn2_type_enable <= 0; eqn2_coef_enable <= 0; graph_enable <= 0;
        end
        else if (m_click_rise) begin
            if (graph_enable) graph_enable <= 1'b0;
            else if (eqn2_coef_enable) eqn2_coef_enable <= 1'b0;
            else if (eqn2_type_enable) eqn2_type_enable <= 1'b0;
            else if (eqn1_coef_enable) eqn1_coef_enable <= 1'b0;
        end
        else if (graph_pulse) graph_enable <= 1'b1;
        else if (eqn2_coef_pulse) eqn2_coef_enable <= 1'b1;
        else if (eqn2_type_pulse) eqn2_type_enable <= 1'b1;
        else if (eqn1_coef_pulse) eqn1_coef_enable <= 1'b1;
    end
    wire [2:0] eqn1_choice, eqn2_choice;
    wire eqn1_dummy_active, eqn2_dummy_active;
    
    wire eqn1_coef_enL = ~eqn2_type_enable & eqn1_coef_enable;
    wire eqn2_coef_enL =  (eqn2_type_enable & eqn2_coef_enable) & ~graph_enable;
    wire graph_enL = graph_enable;
    
    wire [4:0] pb_eq1 = eqn1_coef_enL ? pb : 5'b0;
    wire [4:0] pb_eq2 = eqn2_coef_enL ? pb : 5'b0;
    wire [4:0] pb_graph = graph_enL ? pb : 5'b0;
    
    wire signed [15:0] eq1_a, eq1_b, eq1_c, eq1_d;
    wire signed [15:0] eq2_a, eq2_b, eq2_c, eq2_d;
    
    // latching to ensure coef values are not overwritten
    reg signed [15:0] eq1_a_L, eq1_b_L, eq1_c_L, eq1_d_L;
    reg signed [15:0] eq2_a_L, eq2_b_L, eq2_c_L, eq2_d_L;
    reg eqn1_done_q, eqn2_done_q;          // edge detectors
    wire eqn1_done = eqn2_type_enable;     // eqn1_coef -> next stage signal
    wire eqn2_done = graph_enable;         // eqn2_coef -> next stage signal
    wire eqn1_done_rise =  eqn1_done & ~eqn1_done_q;
    wire eqn2_done_rise =  eqn2_done & ~eqn2_done_q;
    
    always @(posedge clk_100M or posedge reset) begin
      if (reset) begin
        eqn1_done_q <= 1'b0; eqn2_done_q <= 1'b0;
        eq1_a_L <= 0; eq1_b_L <= 0; eq1_c_L <= 0; eq1_d_L <= 0;
        eq2_a_L <= 0; eq2_b_L <= 0; eq2_c_L <= 0; eq2_d_L <= 0;
      end else begin
        eqn1_done_q <= eqn1_done; eqn2_done_q <= eqn2_done;
        if (eqn1_done_rise) begin
          eq1_a_L <= eq1_a; eq1_b_L <= eq1_b; eq1_c_L <= eq1_c; eq1_d_L <= eq1_d;
        end
        if (eqn2_done_rise) begin
          eq2_a_L <= eq2_a; eq2_b_L <= eq2_b; eq2_c_L <= eq2_c; eq2_d_L <= eq2_d;
        end
      end
    end
    
    reg graph_en_q;
    always @(posedge clk_100M or posedge reset) begin
      if (reset) graph_en_q <= 1'b0;
      else graph_en_q <= graph_enable;
    end
    wire graph_en_rise = graph_enable & ~graph_en_q;
    wire [3:0] z_den, z_num;
    
    // equation 1: enter which polynomial type
    poly_type #(.EQUATION("EQUATION 1"), .COLOUR(16'b11111_101001_00000)) eqn1_type (.x(x), .y(y), .mx(mx), .my(my), .click_rise(click_rise), .reset(reset), 
                         .enable(plot_enable), .clk_100M(clk_100M),
                         .oled(eqn1_type_oled), .active(eqn1_dummy_active), 
                         .degree(eqn1_choice), .done(eqn1_coef_pulse));
    // equation 1: what are the a, b, c for the respective equation
    poly_coef #(.EQUATION("EQUATION 1"), .COLOUR(16'b11111_101001_00000)) eqn1_coef (.x(x), .y(y), .mx(mx), .my(my), .click_rise(click_rise), .reset(reset), .pb(pb_eq1),
                          .enable(eqn1_coef_enL), .clk_100M(clk_100M),
                          .oled(eqn1_coef_oled), .degree(eqn1_choice), .done(eqn2_type_pulse),
                          .a(eq1_a), .b(eq1_b), .c(eq1_c), .d(eq1_d));
     // equation 2: enter which polynomial type
    poly_type #(.EQUATION("EQUATION 2"), .COLOUR(16'b00000_011110_11111)) eqn2_type (.x(x), .y(y), .mx(mx), .my(my), .click_rise(click_rise), .reset(reset), 
                      .enable(eqn2_type_enable), .clk_100M(clk_100M),
                      .oled(eqn2_type_oled), .active(eqn2_dummy_active), 
                      .degree(eqn2_choice), .done(eqn2_coef_pulse));
    // equation 2: what are the a, b, c for the respective equation
    poly_coef #(.EQUATION("EQUATION 2"), .COLOUR(16'b00000_011110_11111)) eqn2_coef (.x(x), .y(y), .mx(mx), .my(my), .click_rise(click_rise), .reset(reset), .pb(pb_eq2),
                      .enable(eqn2_coef_enL), .clk_100M(clk_100M),
                      .oled(eqn2_coef_oled), .degree(eqn2_choice), .done(graph_pulse),
                      .a(eq2_a), .b(eq2_b), .c(eq2_c), .d(eq2_d));
                      
    plot_graph graph_mod (.x(x), .y(y), .click_rise(click_rise), .reset(reset),
                            .enable(graph_enL), .clk_100M(clk_100M),
                            .oled(graph_oled),
                            .a1(eq1_a_L), .b1(eq1_b_L), .c1(eq1_c_L), .d1(eq1_d_L),
                            .a2(eq2_a_L), .b2(eq2_b_L), .c2(eq2_c_L), .d2(eq2_d_L), .pb(pb_graph),
                            .z_den(z_den), .z_num(z_num));      
    always @(*) begin
        plot_oleddata = BLACK;
        if (plot_enable) begin 
            if (pointer) plot_oleddata = WHITE;
            else if (graph_enable) plot_oleddata = graph_oled;
            else if (eqn2_coef_enable) plot_oleddata = eqn2_coef_oled;
            else if (eqn2_type_enable) plot_oleddata = eqn2_type_oled;
            else if (eqn1_coef_enable) plot_oleddata = eqn1_coef_oled;
            else plot_oleddata = eqn1_type_oled;
        end
    end
endmodule
