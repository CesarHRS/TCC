`timescale 1ns/1ps

module simplex_tb;

    parameter int M = 3;
    parameter int N = 2;
    parameter int W = 32;
    parameter int Q = 16;
    parameter int MAX_ITERS = 20;

    logic clk;
    logic rst_n;
    logic start;
    logic done;
    logic unbounded;
    logic infeasible;
    logic signed [W-1:0] objective;
    logic signed [W-1:0] x [0:N-1];

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
        .x(x)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz
    end

    real obj_val;
    real x1_val;
    real x2_val;
    real scale;

    initial begin
        scale = 2.0**Q;
        rst_n = 0;
        start = 0;
        #20;
        rst_n = 1;

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done == 1);
        $display("[TB] done=%0d unbounded=%0d infeasible=%0d objective=%0f x1=%0f x2=%0f", done, unbounded, infeasible,
            $itor(objective)/2.0**Q,
            $itor(x[0]) / 2.0**Q,
            $itor(x[1]) / 2.0**Q);

        if (unbounded || infeasible) begin
            $error("Problema deveria estar resolvível e limitado");
            $finish;
        end

        obj_val = $itor(objective) / scale;
        x1_val  = $itor(x[0]) / scale;
        x2_val  = $itor(x[1]) / scale;

        if (!(obj_val > 0.0) || x1_val < 0.0 || x2_val < 0.0) begin
            $error("Resultado inválido: objective=%f x1=%f x2=%f", obj_val, x1_val, x2_val);
            $finish;
        end

        $display("[TB] Resultado ACK. Teste finalizado com sucesso.");
        #20;
        $finish;
    end

    // Timeout monitor
    initial begin
        #5000;
        $error("Timeout: algoritmo simplex nao concluiu em 5us (5000ns)");
        $finish;
    end

endmodule
