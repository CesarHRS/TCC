`timescale 1ns/1ps

module simplex_tb;

    parameter M = 3;
    parameter N = 2;
    parameter W = 32;
    parameter Q = 16;
    parameter MAX_ITERS = 20;

    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire unbounded;
    wire infeasible;
    wire signed [W-1:0] objective;
    wire signed [W-1:0] x_0;
    wire signed [W-1:0] x_1;

    simplex #(
        .M(M),
        .N(N),
        .W(W),
        .Q(Q),
        .MAX_ITERS(MAX_ITERS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .unbounded(unbounded),
        .infeasible(infeasible),
        .objective(objective),
        .x_out_0(x_0),
        .x_out_1(x_1)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    integer obj_val;
    integer x1_val;
    integer x2_val;

    initial begin
        rst_n = 0;
        start = 0;
        #20;
        rst_n = 1;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        $display("[TB] done=%0d unbounded=%0d infeasible=%0d objective=%0d x1=%0d x2=%0d", 
            done, unbounded, infeasible, objective, x_0, x_1);

        if (unbounded || infeasible) begin
            $display("ERROR: Problema deveria estar resolvível e limitado");
            $finish;
        end

        obj_val = objective;
        x1_val  = x_0;
        x2_val  = x_1;

        if (!(obj_val > 0) || x1_val < 0 || x2_val < 0) begin
            $display("ERROR: Resultado inválido: objective=%0d x1=%0d x2=%0d", obj_val, x1_val, x2_val);
            $finish;
        end

        $display("[TB] Resultado ACK. Teste finalizado com sucesso.");
        #20;
        $finish;
    end

    // Timeout monitor
    initial begin
        #5000;
        $display("ERROR: Timeout: algoritmo simplex nao concluiu em 5us (5000ns)");
        $finish;
    end

endmodule
