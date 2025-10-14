module tb_one_max;

    localparam N_BITS = 1024;
    localparam CLK_PERIOD = 10; 

    logic clk;
    logic rst_n;
    logic start;
    logic [N_BITS-1:0] best_solution;
    logic [$clog2(N_BITS)+1:0] best_fitness;
    logic done;

    solver #(.N_BITS(N_BITS)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .best_solution(best_solution),
        .best_fitness(best_fitness),
        .done(done)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    initial begin
        $display("Iniciando simulação...");
        rst_n = 1'b0; 
        start = 1'b0;
        repeat(2) @(posedge clk);
        rst_n = 1'b1; 

        @(posedge clk);
            $display("Iniciando busca...");
            start = 1'b1; 
        @(posedge clk);
            start = 1'b0;
            wait(done);
        
        @(posedge clk);
            $display("Solução ótima encontrada: %b", best_solution);
            $display("Aptidão final: %d", best_fitness);

        $finish;
    end

endmodule