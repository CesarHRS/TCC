`ifndef N_QUEENS_TB_SV
`define N_QUEENS_TB_SV

`timescale 1ns / 1ps

module n_queens_tb;

    parameter int N = 8;
    parameter int MAX_ITERATIONS = 1000000;

    // DUT signals
    logic                    clk;
    logic                    rst;
    logic                    start;
    logic                    done;
    logic [$clog2(N)-1:0]    board [N-1:0];
    logic [31:0]             iterations;
    logic [31:0]             conflicts;

    // DUT instance
    n_queens #(
        .N(N),
        .MAX_ITERATIONS(MAX_ITERATIONS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .board(board),
        .iterations(iterations),
        .conflicts(conflicts)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        start = 0;

        // Reset
        #10 rst = 0;

        // Start the solver
        #10 start = 1;
        #10 start = 0;

        // Wait for completion or timeout
        wait(done || iterations >= MAX_ITERATIONS);

        // Display results
        $display("N-Queens Solution (N=%0d)", N);
        $display("Iterations: %0d", iterations);
        $display("Final Conflicts: %0d", conflicts);
        $display("Solution Found: %s", (conflicts == 0) ? "YES" : "NO");

        // Display board
        $display("Board Configuration:");
        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                if (board[col] == row) begin
                    $write("Q ");
                end else begin
                    $write(". ");
                end
            end
            $write("\n");
        end

        // Display queen positions
        $display("Queen Positions (column -> row):");
        for (int col = 0; col < N; col++) begin
            $display("Col %0d -> Row %0d", col, board[col]);
        end

        $finish;
    end

endmodule

`endif // N_QUEENS_TB_SV
