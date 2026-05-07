`ifndef N_QUEENS_TB_SV
`define N_QUEENS_TB_SV

`timescale 1ns / 1ps

module n_queens_tb;

    wire CLOCK_50;
    reg [17:0] SW;
    wire [6:0] HEX0, HEX1, HEX2, HEX3;
    wire [6:0] HEX4, HEX5, HEX6, HEX7;
    wire [8:0] LEDG;
    wire [17:0] LEDR;

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

    reg clk_gen;
    assign CLOCK_50 = clk_gen;
    
    always #5 clk_gen = ~clk_gen;

    initial begin
        clk_gen = 0;
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
