`ifndef N_QUEENS_SV
`define N_QUEENS_SV

module n_queens #(
    parameter int N = 50,
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
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_INIT,
        ST_FIND_CONFLICT_COL,
        ST_SCAN_COLUMN,
        ST_SELECT_COL,
        ST_DECIDE_MOVE,
        ST_EVAL_ROW,
        ST_SELECT_ROW,
        ST_MOVE,
        ST_CHECK_DONE,
        ST_RESTART,
        ST_DONE
    } state_t;

    state_t current_state, next_state;

    // Internal signals
    logic [63:0] lfsr_state;
    logic        lfsr_enable;
    logic [$clog2(N)-1:0] board_reg [N-1:0];
    logic [31:0] iter_count;
    logic [31:0] conflict_count;
    logic [$clog2(N)-1:0] selected_col;
    logic [$clog2(N)-1:0] test_row;
    logic [31:0] min_conflicts;
    logic [$clog2(N)-1:0] best_row;
    logic [31:0] max_conflicts;
    logic [3:0] restart_count;
    logic [31:0] no_improve_count;
    logic [31:0] previous_conflict_count;
    logic [31:0] walk_steps;
    logic [$clog2(N)-1:0] init_counter;
    logic [$clog2(N)-1:0] scan_col;
    logic [$clog2(N)-1:0] col_candidate_count;
    logic [$clog2(N)-1:0] conflict_cols [N-1:0];
    logic [$clog2(N)-1:0] row_candidate_count;
    logic [$clog2(N)-1:0] row_candidates [N-1:0];
    logic [31:0] current_col_conflicts;
    logic [31:0] current_row_conflicts;
    logic [31:0] iter_per_restart;

    localparam int MAX_NO_IMPROVE = 500;
    localparam int MAX_WALK_STEPS = 100;

    // LFSR instance
    lfsr64 lfsr_inst (
        .clk(clk),
        .rst(rst),
        .enable(lfsr_enable),
        .state(lfsr_state)
    );

    // Count conflicts in a column position for the chosen row
    function automatic int count_conflicts(
        input int row,
        input int col
    );
        int conflicts = 0;
        int other_row;
        for (int i = 0; i < N; i++) begin
            if (i != col) begin
                other_row = board_reg[i];
                if (other_row == row) begin
                    conflicts++;
                end else if ((other_row + i) == (row + col) || (other_row - i) == (row - col)) begin
                    conflicts++;
                end
            end
        end
        return conflicts;
    endfunction

    // Calculate total pairwise conflicts
    always_comb begin
        int total_conflicts = 0;
        int row_i;
        int row_j;
        for (int i = 0; i < N; i++) begin
            row_i = board_reg[i];
            for (int j = i + 1; j < N; j++) begin
                row_j = board_reg[j];
                if (row_i == row_j) begin
                    total_conflicts++;
                end else if ((row_i + i) == (row_j + j) || (row_i - i) == (row_j - j)) begin
                    total_conflicts++;
                end
            end
        end
        conflict_count = total_conflicts;
    end

    // FSM sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= ST_IDLE;
            for (int i = 0; i < N; i++) begin
                board_reg[i] <= '0;
                conflict_cols[i] <= '0;
                row_candidates[i] <= '0;
            end
            iter_count <= 0;
            selected_col <= '0;
            test_row <= '0;
            min_conflicts <= 32'hFFFFFFFF;
            best_row <= '0;
            restart_count <= 0;
            no_improve_count <= 0;
            previous_conflict_count <= 0;
            walk_steps <= 0;
            init_counter <= '0;
            scan_col <= '0;
            col_candidate_count <= '0;
            row_candidate_count <= '0;
            current_col_conflicts <= 0;
            current_row_conflicts <= 0;
            iter_per_restart <= MAX_ITERATIONS / 10;
            lfsr_enable <= 1'b0;
        end else begin
            current_state <= next_state;
            lfsr_enable <= 1'b0;

            case (current_state)
                ST_IDLE: begin
                    if (start) begin
                        iter_count <= 0;
                        restart_count <= 0;
                        no_improve_count <= 0;
                        previous_conflict_count <= 0;
                        walk_steps <= 0;
                        init_counter <= '0;
                        scan_col <= '0;
                        col_candidate_count <= '0;
                        row_candidate_count <= '0;
                    end
                end

                ST_INIT: begin
                    board_reg[init_counter] <= lfsr_state[$clog2(N)-1:0];
                    lfsr_enable <= 1'b1;
                    if (init_counter < N - 1) begin
                        init_counter <= init_counter + 1;
                    end else begin
                        init_counter <= '0;
                    end
                end

                ST_FIND_CONFLICT_COL: begin
                    scan_col <= '0;
                    max_conflicts <= 0;
                    col_candidate_count <= 0;
                    lfsr_enable <= 1'b1;
                end

                ST_SCAN_COLUMN: begin
                    current_col_conflicts <= count_conflicts(board_reg[scan_col], scan_col);
                    if (scan_col == 0) begin
                        max_conflicts <= current_col_conflicts;
                        col_candidate_count <= 1;
                        conflict_cols[0] <= scan_col;
                    end else if (current_col_conflicts > max_conflicts) begin
                        max_conflicts <= current_col_conflicts;
                        col_candidate_count <= 1;
                        conflict_cols[0] <= scan_col;
                    end else if (current_col_conflicts == max_conflicts && current_col_conflicts > 0) begin
                        conflict_cols[col_candidate_count] <= scan_col;
                        col_candidate_count <= col_candidate_count + 1;
                    end
                    if (scan_col < N - 1) begin
                        scan_col <= scan_col + 1;
                    end
                end

                ST_SELECT_COL: begin
                    if (max_conflicts == 0) begin
                        selected_col <= '0;
                    end else if (col_candidate_count == 1) begin
                        selected_col <= conflict_cols[0];
                    end else begin
                        logic [$clog2(N)-1:0] random_index;
                        random_index = lfsr_state[$clog2(N)-1:0] % col_candidate_count;
                        selected_col <= conflict_cols[random_index];
                        lfsr_enable <= 1'b1;
                    end
                end

                ST_DECIDE_MOVE: begin
                    if (conflict_count >= previous_conflict_count) begin
                        no_improve_count <= no_improve_count + 1;
                    end else begin
                        no_improve_count <= 0;
                    end

                    if (no_improve_count > MAX_NO_IMPROVE && walk_steps < MAX_WALK_STEPS) begin
                        selected_col <= lfsr_state[$clog2(N)-1:0];
                        best_row <= lfsr_state[$clog2(N)-1:0];
                        walk_steps <= walk_steps + 1;
                        lfsr_enable <= 1'b1;
                    end else begin
                        test_row <= '0;
                        min_conflicts <= 32'hFFFFFFFF;
                        row_candidate_count <= 0;
                        if (no_improve_count > MAX_NO_IMPROVE) begin
                            walk_steps <= walk_steps + 1;
                        end else begin
                            walk_steps <= 0;
                        end
                    end
                end

                ST_EVAL_ROW: begin
                    current_row_conflicts <= count_conflicts(test_row, selected_col);
                    if (current_row_conflicts < min_conflicts) begin
                        min_conflicts <= current_row_conflicts;
                        row_candidate_count <= 1;
                        row_candidates[0] <= test_row;
                    end else if (current_row_conflicts == min_conflicts) begin
                        row_candidates[row_candidate_count] <= test_row;
                        row_candidate_count <= row_candidate_count + 1;
                    end
                    if (test_row < N - 1) begin
                        test_row <= test_row + 1;
                    end
                end

                ST_SELECT_ROW: begin
                    if (row_candidate_count == 1) begin
                        best_row <= row_candidates[0];
                    end else begin
                        logic [$clog2(N)-1:0] random_index;
                        random_index = lfsr_state[$clog2(N)-1:0] % row_candidate_count;
                        best_row <= row_candidates[random_index];
                        lfsr_enable <= 1'b1;
                    end
                end

                ST_MOVE: begin
                    board_reg[selected_col] <= best_row;
                    iter_count <= iter_count + 1;
                end

                ST_CHECK_DONE: begin
                    previous_conflict_count <= conflict_count;
                end

                ST_RESTART: begin
                    restart_count <= restart_count + 1;
                    iter_count <= 0;
                    no_improve_count <= 0;
                    walk_steps <= 0;
                    init_counter <= '0;
                    scan_col <= '0;
                    col_candidate_count <= '0;
                end

                ST_DONE: begin
                    // stay in done state
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
                if (init_counter >= N - 1) begin
                    next_state = ST_FIND_CONFLICT_COL;
                end
            end

            ST_FIND_CONFLICT_COL: begin
                next_state = ST_SCAN_COLUMN;
            end

            ST_SCAN_COLUMN: begin
                if (scan_col == N - 1) begin
                    next_state = ST_SELECT_COL;
                end
            end

            ST_SELECT_COL: begin
                if (max_conflicts == 0) begin
                    next_state = ST_DONE;
                end else begin
                    next_state = ST_DECIDE_MOVE;
                end
            end

            ST_DECIDE_MOVE: begin
                if (no_improve_count > MAX_NO_IMPROVE && walk_steps < MAX_WALK_STEPS) begin
                    next_state = ST_MOVE;
                end else begin
                    next_state = ST_EVAL_ROW;
                end
            end

            ST_EVAL_ROW: begin
                if (test_row == N - 1) begin
                    next_state = ST_SELECT_ROW;
                end
            end

            ST_SELECT_ROW: begin
                next_state = ST_MOVE;
            end

            ST_MOVE: begin
                next_state = ST_CHECK_DONE;
            end

            ST_CHECK_DONE: begin
                if (conflict_count == 0) begin
                    next_state = ST_DONE;
                end else if (iter_count >= iter_per_restart && restart_count < 10) begin
                    next_state = ST_RESTART;
                end else if (iter_count >= iter_per_restart) begin
                    next_state = ST_DONE;
                end else begin
                    next_state = ST_FIND_CONFLICT_COL;
                end
            end

            ST_RESTART: begin
                next_state = ST_INIT;
            end

            ST_DONE: begin
                next_state = ST_DONE;
            end
        endcase
    end

    assign board = board_reg;
    assign iterations = iter_count;
    assign conflicts = conflict_count;
    assign done = (current_state == ST_DONE);

endmodule

`endif // N_QUEENS_SV
