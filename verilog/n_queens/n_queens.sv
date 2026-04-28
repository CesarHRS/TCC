`ifndef N_QUEENS_SV
`define N_QUEENS_SV

module n_queens #(
    parameter int N = 8,
    parameter int MAX_ITERATIONS = 1000000
)(
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    start,
    output logic                    done,
    output logic [$clog2(N)-1:0]    board [N-1:0],
    output logic [31:0]             iterations,
    output logic [31:0]             conflicts
);

    // FSM states
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_INIT,
        ST_FIND_CONFLICT_COL,
        ST_EVAL_ROW,
        ST_MOVE,
        ST_DONE
    } state_t;

    state_t current_state, next_state;

    // Internal signals
    logic [63:0] lfsr_state;
    logic lfsr_enable;
    logic [$clog2(N)-1:0] board_reg [N-1:0];
    logic [31:0] iter_count;
    logic [31:0] conflict_count;
    logic [$clog2(N)-1:0] selected_col;
    logic [$clog2(N)-1:0] test_row;
    logic [31:0] min_conflicts;
    logic [$clog2(N)-1:0] best_row;
    logic [3:0] restart_count;
    logic [31:0] no_improve_count;
    logic [$clog2(N)-1:0] init_counter;

    // LFSR instance
    lfsr64 lfsr_inst (
        .clk(clk),
        .rst(rst),
        .enable(lfsr_enable),
        .state(lfsr_state)
    );

    // Function to count conflicts for a position (unrolled for N=8)
    function automatic logic [31:0] count_conflicts(
        input logic [2:0] row,
        input logic [2:0] col
    );
        logic [31:0] conflicts = 0;
        if (col != 0) begin
            if (board_reg[0] == row) conflicts++;
            else if ((board_reg[0] + 0) == (row + col) || (board_reg[0] - 0) == (row - col)) conflicts++;
        end
        if (col != 1) begin
            if (board_reg[1] == row) conflicts++;
            else if ((board_reg[1] + 1) == (row + col) || (board_reg[1] - 1) == (row - col)) conflicts++;
        end
        if (col != 2) begin
            if (board_reg[2] == row) conflicts++;
            else if ((board_reg[2] + 2) == (row + col) || (board_reg[2] - 2) == (row - col)) conflicts++;
        end
        if (col != 3) begin
            if (board_reg[3] == row) conflicts++;
            else if ((board_reg[3] + 3) == (row + col) || (board_reg[3] - 3) == (row - col)) conflicts++;
        end
        if (col != 4) begin
            if (board_reg[4] == row) conflicts++;
            else if ((board_reg[4] + 4) == (row + col) || (board_reg[4] - 4) == (row - col)) conflicts++;
        end
        if (col != 5) begin
            if (board_reg[5] == row) conflicts++;
            else if ((board_reg[5] + 5) == (row + col) || (board_reg[5] - 5) == (row - col)) conflicts++;
        end
        if (col != 6) begin
            if (board_reg[6] == row) conflicts++;
            else if ((board_reg[6] + 6) == (row + col) || (board_reg[6] - 6) == (row - col)) conflicts++;
        end
        if (col != 7) begin
            if (board_reg[7] == row) conflicts++;
            else if ((board_reg[7] + 7) == (row + col) || (board_reg[7] - 7) == (row - col)) conflicts++;
        end
        return conflicts;
    endfunction

    // Calculate total conflicts (unrolled for N=8)
    always_comb begin
        conflict_count = 0;
        // Check all pairs
        if (board_reg[0] == board_reg[1]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[1] + 1) || (board_reg[0] - 0) == (board_reg[1] - 1)) conflict_count++;
        
        if (board_reg[0] == board_reg[2]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[2] + 2) || (board_reg[0] - 0) == (board_reg[2] - 2)) conflict_count++;
        
        if (board_reg[0] == board_reg[3]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[3] + 3) || (board_reg[0] - 0) == (board_reg[3] - 3)) conflict_count++;
        
        if (board_reg[0] == board_reg[4]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[4] + 4) || (board_reg[0] - 0) == (board_reg[4] - 4)) conflict_count++;
        
        if (board_reg[0] == board_reg[5]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[5] + 5) || (board_reg[0] - 0) == (board_reg[5] - 5)) conflict_count++;
        
        if (board_reg[0] == board_reg[6]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[6] + 6) || (board_reg[0] - 0) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[0] == board_reg[7]) conflict_count++;
        else if ((board_reg[0] + 0) == (board_reg[7] + 7) || (board_reg[0] - 0) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[1] == board_reg[2]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[2] + 2) || (board_reg[1] - 1) == (board_reg[2] - 2)) conflict_count++;
        
        if (board_reg[1] == board_reg[3]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[3] + 3) || (board_reg[1] - 1) == (board_reg[3] - 3)) conflict_count++;
        
        if (board_reg[1] == board_reg[4]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[4] + 4) || (board_reg[1] - 1) == (board_reg[4] - 4)) conflict_count++;
        
        if (board_reg[1] == board_reg[5]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[5] + 5) || (board_reg[1] - 1) == (board_reg[5] - 5)) conflict_count++;
        
        if (board_reg[1] == board_reg[6]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[6] + 6) || (board_reg[1] - 1) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[1] == board_reg[7]) conflict_count++;
        else if ((board_reg[1] + 1) == (board_reg[7] + 7) || (board_reg[1] - 1) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[2] == board_reg[3]) conflict_count++;
        else if ((board_reg[2] + 2) == (board_reg[3] + 3) || (board_reg[2] - 2) == (board_reg[3] - 3)) conflict_count++;
        
        if (board_reg[2] == board_reg[4]) conflict_count++;
        else if ((board_reg[2] + 2) == (board_reg[4] + 4) || (board_reg[2] - 2) == (board_reg[4] - 4)) conflict_count++;
        
        if (board_reg[2] == board_reg[5]) conflict_count++;
        else if ((board_reg[2] + 2) == (board_reg[5] + 5) || (board_reg[2] - 2) == (board_reg[5] - 5)) conflict_count++;
        
        if (board_reg[2] == board_reg[6]) conflict_count++;
        else if ((board_reg[2] + 2) == (board_reg[6] + 6) || (board_reg[2] - 2) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[2] == board_reg[7]) conflict_count++;
        else if ((board_reg[2] + 2) == (board_reg[7] + 7) || (board_reg[2] - 2) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[3] == board_reg[4]) conflict_count++;
        else if ((board_reg[3] + 3) == (board_reg[4] + 4) || (board_reg[3] - 3) == (board_reg[4] - 4)) conflict_count++;
        
        if (board_reg[3] == board_reg[5]) conflict_count++;
        else if ((board_reg[3] + 3) == (board_reg[5] + 5) || (board_reg[3] - 3) == (board_reg[5] - 5)) conflict_count++;
        
        if (board_reg[3] == board_reg[6]) conflict_count++;
        else if ((board_reg[3] + 3) == (board_reg[6] + 6) || (board_reg[3] - 3) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[3] == board_reg[7]) conflict_count++;
        else if ((board_reg[3] + 3) == (board_reg[7] + 7) || (board_reg[3] - 3) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[4] == board_reg[5]) conflict_count++;
        else if ((board_reg[4] + 4) == (board_reg[5] + 5) || (board_reg[4] - 4) == (board_reg[5] - 5)) conflict_count++;
        
        if (board_reg[4] == board_reg[6]) conflict_count++;
        else if ((board_reg[4] + 4) == (board_reg[6] + 6) || (board_reg[4] - 4) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[4] == board_reg[7]) conflict_count++;
        else if ((board_reg[4] + 4) == (board_reg[7] + 7) || (board_reg[4] - 4) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[5] == board_reg[6]) conflict_count++;
        else if ((board_reg[5] + 5) == (board_reg[6] + 6) || (board_reg[5] - 5) == (board_reg[6] - 6)) conflict_count++;
        
        if (board_reg[5] == board_reg[7]) conflict_count++;
        else if ((board_reg[5] + 5) == (board_reg[7] + 7) || (board_reg[5] - 5) == (board_reg[7] - 7)) conflict_count++;
        
        if (board_reg[6] == board_reg[7]) conflict_count++;
        else if ((board_reg[6] + 6) == (board_reg[7] + 7) || (board_reg[6] - 6) == (board_reg[7] - 7)) conflict_count++;
    end

    // FSM logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= ST_IDLE;
            for (int i = 0; i < N; i++) begin
                board_reg[i] <= 0;
            end
            iter_count <= 0;
            selected_col <= 0;
            test_row <= 0;
            min_conflicts <= 32'hFFFFFFFF;
            best_row <= 0;
            restart_count <= 0;
            no_improve_count <= 0;
            init_counter <= 0;
            lfsr_enable <= 0;
        end else begin
            current_state <= next_state;
            lfsr_enable <= 0;

            case (current_state)
                ST_IDLE: begin
                    if (start) begin
                        iter_count <= 0;
                        restart_count <= 0;
                        no_improve_count <= 0;
                        test_row <= 0;
                        min_conflicts <= 32'hFFFFFFFF;
                        best_row <= 0;
                    end
                end

                ST_INIT: begin
                    // Initialize board with random values, one per cycle
                    board_reg[init_counter] <= lfsr_state[$clog2(N)-1:0];
                    lfsr_enable <= 1;
                    if (init_counter < N-1) begin
                        init_counter <= init_counter + 1;
                    end else begin
                        init_counter <= 0;
                    end
                end

                ST_FIND_CONFLICT_COL: begin
                    // Select a random column
                    selected_col <= lfsr_state[$clog2(N)-1:0];
                    lfsr_enable <= 1;
                    test_row <= 0;
                    min_conflicts <= 32'hFFFFFFFF;
                    best_row <= board_reg[lfsr_state[$clog2(N)-1:0]];
                end

                ST_EVAL_ROW: begin
                    // Evaluate current test_row for selected_col
                    logic [31:0] conflicts = count_conflicts(test_row, selected_col);
                    if (conflicts < min_conflicts) begin
                        min_conflicts <= conflicts;
                        best_row <= test_row;
                    end else if (conflicts == min_conflicts) begin
                        // Tie-breaking with LFSR
                        if (lfsr_state[0]) begin
                            best_row <= test_row;
                        end
                        lfsr_enable <= 1;
                    end

                    if (test_row < N-1) begin
                        test_row <= test_row + 1;
                    end
                end

                ST_MOVE: begin
                    // Move queen to best position
                    board_reg[selected_col] <= best_row;
                    iter_count <= iter_count + 1;

                    // Check for improvement
                    if (conflict_count == 0) begin
                        // Solution found
                    end else if (iter_count >= MAX_ITERATIONS) begin
                        // Restart
                        if (restart_count < 10) begin
                            restart_count <= restart_count + 1;
                            current_state <= ST_INIT;
                            lfsr_enable <= 1;
                        end
                    end
                end

                ST_DONE: begin
                    // Stay in done state
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: begin
                if (start) next_state = ST_INIT;
            end
            ST_INIT: begin
                if (init_counter >= N-1) begin
                    next_state = ST_FIND_CONFLICT_COL;
                end
            end
            ST_FIND_CONFLICT_COL: begin
                next_state = ST_EVAL_ROW;
            end
            ST_EVAL_ROW: begin
                if (test_row >= N-1) begin
                    next_state = ST_MOVE;
                end
            end
            ST_MOVE: begin
                if (conflict_count == 0) begin
                    next_state = ST_DONE;
                end else if (iter_count >= MAX_ITERATIONS && restart_count >= 10) begin
                    next_state = ST_DONE;
                end else begin
                    next_state = ST_FIND_CONFLICT_COL;
                end
            end
            ST_DONE: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // Output assignments
    assign board = board_reg;
    assign iterations = iter_count;
    assign conflicts = conflict_count;
    assign done = (current_state == ST_DONE);

endmodule

`endif // N_QUEENS_SV
