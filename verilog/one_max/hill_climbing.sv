module hill_climbing #(
    parameter N_BITS = 1024
) (
    input  wire clk,
    input  wire clk_enable,
    input  wire rst_n,
    input  wire start,
    
    output wire [11:0] best_fitness, 
    output wire [N_BITS-1:0] best_solution,
    
    output wire running,
    output wire done
);

    reg [N_BITS-1:0] current_solution;
    reg [11:0] current_fitness;
    wire [9:0] random_bit_index;
    
    reg [63:0] lfsr_reg;
    wire new_bit;

    assign new_bit = lfsr_reg[63] ^ lfsr_reg[62] ^ lfsr_reg[60] ^ lfsr_reg[59];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr_reg <= 64'hDEAD_BEEF_CAFE_BABE; 
        else
            lfsr_reg <= {lfsr_reg[62:0], new_bit};
    end

    assign random_bit_index = lfsr_reg[9:0];
    assign best_solution = current_solution;
    assign best_fitness = current_fitness;
    
    reg running_r, done_r;
    assign running = running_r;
    assign done = done_r; 

    // --- Máquina de Estados ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_solution <= {N_BITS{1'b0}};
            current_fitness  <= 12'b0;
            running_r        <= 1'b0;
            done_r           <= 1'b0;
        end else begin
            
            // Start
            if (start && !running_r) begin
                current_solution <= {N_BITS{1'b0}};
                current_fitness  <= 12'b0;
                running_r        <= 1'b1;
                done_r           <= 1'b0;
            end 
            
            // Execução
            else if (running_r && clk_enable) begin
                
                if (current_solution[random_bit_index] == 1'b0) begin
                    current_solution[random_bit_index] <= 1'b1;
                    current_fitness <= current_fitness + 12'd1;
                end
                
                // Parada
                if (current_fitness == N_BITS[11:0]) begin
                    running_r <= 1'b0;
                    done_r    <= 1'b1;
                end
            end
        end
    end

endmodule
