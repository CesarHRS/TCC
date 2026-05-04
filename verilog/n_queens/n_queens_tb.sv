`ifndef N_QUEENS_TB_SV
`define N_QUEENS_TB_SV

`timescale 1ns / 1ps

module n_queens_tb;

    logic CLOCK_50;
    logic [17:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3;
    logic [6:0] HEX4, HEX5, HEX6, HEX7;
    logic [8:0] LEDG;
    logic [17:0] LEDR;

    n_queens_top dut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7),
        .LEDG(LEDG),
        .LEDR(LEDR)
    );

    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        CLOCK_50 = 0;
        SW = 18'b0;

        $dumpfile("n_queens_waves.vcd");
        $dumpvars(0, n_queens_tb);

        #20;
        SW[17] = 1; // release reset
        #20;

        SW[0] = 1;
        #10;
        SW[0] = 0;

        wait (LEDG[8]);

        $display("N-Queens top-level finished 10 runs.");
        $display("Average time ready on HEX displays.");
        $finish;
    end

endmodule

`endif // N_QUEENS_TB_SV
