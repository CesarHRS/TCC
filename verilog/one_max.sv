module one_max(
    input  logic CLOCK_50,
    input  logic [17:0] SW,    // SW[17]=Reset, SW[0]=Start
    
    output logic [6:0] HEX0, HEX1, HEX2, HEX3,
    output logic [6:0] HEX4, HEX5, HEX6, HEX7,
    
    output logic [8:0] LEDG,   
    output logic [17:0] LEDR );

    logic rst_n;
    logic start_pulse;
    logic sw0_reg, sw0_reg_prev;

    assign rst_n = SW[17];

    logic [17:0] clk_div_counter;
    logic slow_clk_enable;

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_counter <= '0;
            slow_clk_enable <= 1'b0;
        end else begin
            if (clk_div_counter >= 250000) begin 
                clk_div_counter <= '0;
                slow_clk_enable <= 1'b1; 
            end else begin
                clk_div_counter <= clk_div_counter + 1;
                slow_clk_enable <= 1'b0;
            end
        end
    end

    // --- Detector de Start ---
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            sw0_reg      <= 1'b0;
            sw0_reg_prev <= 1'b0;
        end else begin
            sw0_reg      <= SW[0];   
            sw0_reg_prev <= sw0_reg;  
        end
    end
    assign start_pulse = (sw0_reg == 1'b1) && (sw0_reg_prev == 1'b0);


    // --- Sinais Internos ---
    logic [1023:0] s_best_solution;
    logic [11:0]   s_best_fitness;
    logic          s_running;        
    logic          s_done;           

    // --- LEDs ---
    assign LEDG[8] = s_done;       
    assign LEDG[0] = s_running;    
    assign LEDG[7:1] = 7'b0;
    assign LEDR = s_best_solution[17:0];


    // --- Hill Climbing ---
    hill_climbing #(
        .N_BITS(1024)
    ) hc_inst (
        .clk(CLOCK_50),
        .clk_enable(slow_clk_enable),
        .rst_n(rst_n),
        .start(start_pulse),
        .best_solution(s_best_solution),
        .best_fitness(s_best_fitness),
        .running(s_running),
        .done(s_done)
    );


    // --- TIMER (MS) ---
    localparam int CYCLES_PER_MS = 50_000;
    reg [15:0] prescaler_count; 
    
    reg [3:0] ms_dig0, ms_dig1, ms_dig2; 
    reg [3:0] s_dig0, s_dig1, s_dig2, s_dig3, s_dig4; 

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            prescaler_count <= '0;
            ms_dig0 <= '0; ms_dig1 <= '0; ms_dig2 <= '0;
            s_dig0  <= '0; s_dig1  <= '0; s_dig2  <= '0; s_dig3 <= '0; s_dig4 <= '0;
        end 
        else if (start_pulse) begin
            prescaler_count <= '0;
            ms_dig0 <= '0; ms_dig1 <= '0; ms_dig2 <= '0;
            s_dig0  <= '0; s_dig1  <= '0; s_dig2  <= '0; s_dig3 <= '0; s_dig4 <= '0;
        end
        else if (s_running && !s_done) begin
            if (prescaler_count == CYCLES_PER_MS - 1) begin
                prescaler_count <= '0;
                
                ms_dig0 <= ms_dig0 + 1;
                if (ms_dig0 == 9) begin
                    ms_dig0 <= 0;
                    ms_dig1 <= ms_dig1 + 1;
                    if (ms_dig1 == 9) begin
                        ms_dig1 <= 0;
                        ms_dig2 <= ms_dig2 + 1;
                        if (ms_dig2 == 9) begin
                            ms_dig2 <= 0;
                            s_dig0 <= s_dig0 + 1; 
                            if (s_dig0 == 9) begin
                                s_dig0 <= 0;
                                s_dig1 <= s_dig1 + 1;
                                if (s_dig1 == 9) begin
                                    s_dig1 <= 0;
                                    s_dig2 <= s_dig2 + 1;
                                    if (s_dig2 == 9) begin
                                        s_dig2 <= 0;
                                        s_dig3 <= s_dig3 + 1;
                                        if (s_dig3 == 9) begin
                                            s_dig3 <= 0;
                                            s_dig4 <= s_dig4 + 1;
                                            if (s_dig4 == 9) s_dig4 <= 0;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end else begin
                prescaler_count <= prescaler_count + 1;
            end
        end
    end

    // --- Display ---
    display d0 ( .hex_digit(ms_dig0), .segments(HEX0) );
    display d1 ( .hex_digit(ms_dig1), .segments(HEX1) );
    display d2 ( .hex_digit(ms_dig2), .segments(HEX2) );
    display d3 ( .hex_digit(s_dig0),  .segments(HEX3) );
    display d4 ( .hex_digit(s_dig1),  .segments(HEX4) );
    display d5 ( .hex_digit(s_dig2),  .segments(HEX5) );
    display d6 ( .hex_digit(s_dig3),  .segments(HEX6) );
    display d7 ( .hex_digit(s_dig4),  .segments(HEX7) );

endmodule