module n_queens_top #(
    parameter int N = 50,
    parameter int MAX_ITERATIONS = 1000000
)(
    input  logic        CLOCK_50,
    input  logic [17:0] SW,       // SW[17]=Reset, SW[0]=Start
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    output logic [6:0]  HEX4, HEX5, HEX6, HEX7,
    output logic [8:0]  LEDG,
    output logic [17:0] LEDR
);

    logic rst_n;
    logic start_pulse;
    logic sw0_reg, sw0_reg_prev;

    assign rst_n = SW[17];

    // --- Start pulse detector ---
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

    // --- N-Queens DUT ---
    logic done;
    logic [$clog2(N)-1:0] board [N-1:0];
    logic [31:0] iterations;
    logic [31:0] conflicts;
    logic start_run;

    n_queens #(
        .N(N),
        .MAX_ITERATIONS(MAX_ITERATIONS)
    ) dut (
        .clk(CLOCK_50),
        .rst(~rst_n),
        .start(start_run),
        .done(done),
        .board(board),
        .iterations(iterations),
        .conflicts(conflicts)
    );

    // --- Run controller ---
    typedef enum logic [1:0] {
        IDLE,
        RUNNING,
        DONE_STATE
    } run_state_t;

    run_state_t run_state;
    logic [3:0] run_index;
    logic [63:0] cycle_counter;
    logic [63:0] sum_cycles;
    logic avg_ready;

    logic [63:0] display_cycles;
    logic [63:0] display_ms;
    logic [3:0] digit [7:0];

    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            run_state    <= IDLE;
            run_index    <= 0;
            cycle_counter<= 0;
            sum_cycles   <= 0;
            avg_ready    <= 1'b0;
            start_run    <= 1'b0;
        end else begin
            start_run <= 1'b0;

            if (start_pulse) begin
                run_state    <= RUNNING;
                run_index    <= 0;
                sum_cycles   <= 0;
                cycle_counter<= 0;
                avg_ready    <= 1'b0;
                start_run    <= 1'b1;
            end else begin
                case (run_state)
                    IDLE: begin
                        // wait for start_pulse
                    end

                    RUNNING: begin
                        if (cycle_counter != 64'hFFFFFFFFFFFFFFFF && !done) begin
                            cycle_counter <= cycle_counter + 1;
                        end

                        if (done) begin
                            sum_cycles <= sum_cycles + cycle_counter;
                            if (run_index == 4'd9) begin
                                run_state <= DONE_STATE;
                                avg_ready <= 1'b1;
                            end else begin
                                run_index <= run_index + 1;
                                cycle_counter <= 0;
                                start_run <= 1'b1;
                            end
                        end
                    end

                    DONE_STATE: begin
                        // wait for the next start_pulse to begin a new batch
                    end
                endcase
            end
        end
    end

    always_comb begin
        display_cycles = sum_cycles + cycle_counter;
        display_ms = display_cycles / 50000; // 50 MHz clock => 20 ns per cycle
    end

    always_comb begin
        int unsigned tmp = display_ms;
        for (int i = 0; i < 8; i++) begin
            digit[i] = tmp % 10;
            tmp = tmp / 10;
        end
    end

    // --- LEDs ---
    assign LEDG[8] = avg_ready;
    assign LEDG[0] = (run_state == RUNNING);
    assign LEDG[7:1] = 7'b0;
    assign LEDR = {14'b0, run_index, 2'b0};

    // --- 7-seg display (total time in ms) ---
    display d0 (.hex_digit(digit[0]), .segments(HEX0));
    display d1 (.hex_digit(digit[1]), .segments(HEX1));
    display d2 (.hex_digit(digit[2]), .segments(HEX2));
    display d3 (.hex_digit(digit[3]), .segments(HEX3));
    display d4 (.hex_digit(digit[4]), .segments(HEX4));
    display d5 (.hex_digit(digit[5]), .segments(HEX5));
    display d6 (.hex_digit(digit[6]), .segments(HEX6));
    display d7 (.hex_digit(digit[7]), .segments(HEX7));

endmodule
