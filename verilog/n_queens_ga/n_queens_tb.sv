// Testbench mínimo para n_queens_ga.
// Instancia o core diretamente (sem o wrapper da placa) e roda até `done`.
// Imprime a solução encontrada e o número de gerações gastas.

`timescale 1ns/1ps

module n_queens_tb;

    localparam int N         = 8;
    localparam int GENE_BITS = 3;
    // POP_SIZE menor para a simulação ser viável em tempo razoável.
    localparam int POP_SIZE  = 64;
    localparam int ELITE     = 8;

    reg                       clk;
    reg                       rst_n;
    reg                       start;

    wire                      done;
    wire                      running;
    wire [N*GENE_BITS-1:0]    best_solution;
    wire [11:0]               best_fitness;
    wire [19:0]               generation;

    n_queens_ga_core #(
        .N         (N),
        .GENE_BITS (GENE_BITS),
        .POP_SIZE  (POP_SIZE),
        .ELITE     (ELITE),
        .POP_BITS  (7),         // $clog2(64) = 6, usamos 7 para folga
        .MAX_GENS  (50_000)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .done          (done),
        .running       (running),
        .best_solution (best_solution),
        .best_fitness  (best_fitness),
        .generation    (generation)
    );

    // Clock 50 MHz (20 ns).
    initial clk = 0;
    always  #10 clk = ~clk;

    integer col;
    integer cycles;

    initial begin
        $dumpfile("n_queens_waves.vcd");
        $dumpvars(0, n_queens_tb);

        rst_n = 0;
        start = 0;
        #100;
        rst_n = 1;
        #100;

        // Pulso de start
        start = 1;
        #40;
        start = 0;

        cycles = 0;
        while (!done && cycles < 200_000_000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (done) begin
            $display("== N-Queens GA concluído ==");
            $display("Geração final = %0d", generation);
            $display("Fitness final = %0d", best_fitness);
            $write  ("Solução: ");
            for (col = 0; col < N; col = col + 1)
                $write("%0d ", best_solution[col*GENE_BITS +: GENE_BITS]);
            $write("\n");
        end else begin
            $display("Timeout — sem convergência em %0d ciclos.", cycles);
        end

        $finish;
    end

endmodule
