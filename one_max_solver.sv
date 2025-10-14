module solver #(
    parameter int N_BITS = 1024
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic [N_BITS-1:0] best_solution,
    output logic [$clog2(N_BITS)+1:0] best_fitness,
    output logic done
);

    logic [N_BITS-1:0] current_solution;
    logic [$clog2(N_BITS)+1:0] current_fitness;
    logic [N_BITS-1:0] neighbor_solution;
    logic [$clog2(N_BITS)+1:0] neighbor_fitness;
    logic [$clog2(N_BITS)-1:0] random_bit_index;
    logic running;

    function automatic logic [$clog2(N_BITS)+1:0] calculate_fitness(logic [N_BITS-1:0] vector);
        return $countones(vector);
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_solution <= '0;
            best_solution    <= '0;
            current_fitness  <= '0;
            best_fitness     <= '0;
            running          <= 1'b0;
            done             <= 1'b0;
        end else begin
            if (start && !running) begin
                current_solution <= $urandom();
                best_solution    <= current_solution;
                current_fitness  <= calculate_fitness(current_solution);
                best_fitness     <= current_fitness;
                running          <= 1'b1;
                done             <= 1'b0;
            end else if (running) begin
                random_bit_index  = $urandom_range(0, N_BITS - 1);
                neighbor_solution = current_solution;
                neighbor_solution[random_bit_index] = ~neighbor_solution[random_bit_index];
                neighbor_fitness  = calculate_fitness(neighbor_solution);

                // Algoritmo Hill Climbing
                if (neighbor_fitness >= current_fitness) begin
                    current_solution <= neighbor_solution;
                    current_fitness  <= neighbor_fitness;
                end

                if (current_fitness > best_fitness) begin
                    best_solution <= current_solution;
                    best_fitness  <= current_fitness;
                end

                if (best_fitness == N_BITS) begin
                    running <= 1'b0;
                    done    <= 1'b1;
                end
            end
        end
    end

endmodule