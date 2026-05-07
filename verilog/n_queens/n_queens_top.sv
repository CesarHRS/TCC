module n_queens_top #(
    parameter N = 50,
    parameter MAX_ITERATIONS = 1000000
)(
    input  wire        CLOCK_50,
    input  wire [17:0] SW,       // SW[17]=Reset, SW[0]=Start
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [6:0]  HEX4, HEX5, HEX6, HEX7,
    output wire [8:0]  LEDG,
    output wire [17:0] LEDR
);

    wire rst_n;
    wire start_pulse;
    reg sw0_reg, sw0_reg_prev;

    assign rst_n = SW[17];

    // --- Start pulse detector ---
    always @(posedge CLOCK_50 or negedge rst_n) begin
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
    wire done;
    wire [7:0] board [0:49];
    wire [31:0] iterations;
    wire [31:0] conflicts;
    reg start_run;

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
    localparam IDLE = 2'd0;
    localparam RUNNING = 2'd1;
    localparam DONE_STATE = 2'd2;

    reg [1:0] run_state;
    reg [3:0] run_index;
    reg [63:0] cycle_counter;
    reg [63:0] sum_cycles;
    reg avg_ready;

    wire [63:0] display_cycles;
    wire [63:0] display_ms;
    reg [3:0] digit [0:7];

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            run_state    <= IDLE;
            run_index    <= 4'd0;
            cycle_counter<= 64'd0;
            sum_cycles   <= 64'd0;
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

    always @(*) begin
        integer unsigned tmp;
        integer i;
        tmp = display_ms;
        for (i = 0; i < 8; i = i + 1) begin
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
