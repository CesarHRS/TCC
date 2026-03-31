module hill_climbing #(
    parameter int N_BITS = 1024
) (
    input  logic clk,
    input  logic clk_enable,
    input  logic rst_n,
    input  logic start,
    
    output logic [11:0] best_fitness, 
    output logic [N_BITS-1:0] best_solution,
    
    output logic running,
    output logic done
);

    logic [N_BITS-1:0] current_solution;
    logic [11:0] current_fitness;
    logic [9:0] random_bit_index;
    
    logic [63:0] lfsr_reg;
    logic new_bit;

    assign new_bit = lfsr_reg[63] ^ lfsr_reg[62] ^ lfsr_reg[60] ^ lfsr_reg[59];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr_reg <= 64'hDEAD_BEEF_CAFE_BABE; 
        else
            lfsr_reg <= {lfsr_reg[62:0], new_bit};
    end

    assign random_bit_index = lfsr_reg[9:0]; 

    // --- Máquina de Estados ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_solution <= '0;
            best_solution    <= '0;
            current_fitness  <= '0;
            best_fitness     <= '0;
            running          <= 1'b0;
            done             <= 1'b0;
        end else begin
            
            // Start
            if (start && !running) begin
                current_solution <= '0; 
                best_solution    <= '0;
                current_fitness  <= '0;
                best_fitness     <= '0;
                running          <= 1'b1;
                done             <= 1'b0;
            end 
            
            // Execução
            else if (running && clk_enable) begin
                
                if (current_solution[random_bit_index] == 1'b0) begin
                    current_solution[random_bit_index] <= 1'b1;
                    best_solution[random_bit_index]    <= 1'b1; 
                    
                    current_fitness <= current_fitness + 1'b1;
                    best_fitness    <= current_fitness + 1'b1;
                end
                
                // Parada
                if (best_fitness == N_BITS || current_fitness == N_BITS) begin
                    running <= 1'b0;
                    done    <= 1'b1;
                end
            end
        end
    end

endmodule
