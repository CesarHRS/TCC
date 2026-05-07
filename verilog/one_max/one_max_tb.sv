`timescale 1ns/1ps

module one_max_tb; 

    wire CLOCK_50_wire;
    reg [17:0] SW;

    wire [6:0] HEX0, HEX1, HEX2, HEX3;
    wire [6:0] HEX4, HEX5, HEX6, HEX7;
    wire [8:0] LEDG;
    wire [17:0] LEDR;

    reg clk_gen;
    assign CLOCK_50_wire = clk_gen;

    one_max dut (
        .CLOCK_50(CLOCK_50_wire),
        .SW(SW),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3),
        .HEX4(HEX4), .HEX5(HEX5), .HEX6(HEX6), .HEX7(HEX7),
        .LEDG(LEDG),
        .LEDR(LEDR)
    );

    initial begin
        clk_gen = 0;
        forever #10 clk_gen = ~clk_gen;
    end

    initial begin

        $dumpfile("one_max_waves.vcd");

        $dumpvars(0, one_max_tb);

        SW = 18'b0;
        
        SW[17] = 0; 
        #200;       
        SW[17] = 1; 
        #200;

        SW[0] = 1;
        #1000;      
        SW[0] = 0;

        #20000000; 

        $display("Simulação concluída.");
        $finish;
    end

endmodule
