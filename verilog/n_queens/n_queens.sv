`ifndef N_QUEENS_SV
`define N_QUEENS_SV

module n_queens #(
    parameter N = 50,
    parameter MAX_ITERATIONS = 1000000
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg done,
    output reg [7:0] board_row [0:49],
    output reg [31:0] iterations,
    output reg [31:0] conflicts
);

    // FSM states
    localparam ST_IDLE = 4'd0;
    localparam ST_INIT = 4'd1;
    localparam ST_FIND_CONFLICT_COL = 4'd2;
    localparam ST_SCAN_COLUMN = 4'd3;
    localparam ST_SELECT_COL = 4'd4;
    localparam ST_DECIDE_MOVE = 4'd5;
    localparam ST_EVAL_ROW = 4'd6;
    localparam ST_SELECT_ROW = 4'd7;
    localparam ST_MOVE = 4'd8;
    localparam ST_CHECK_DONE = 4'd9;
    localparam ST_RESTART = 4'd10;
    localparam ST_DONE = 4'd11;

    reg [3:0] current_state, next_state;

    // Internal signals
    reg [63:0] lfsr_state;
    reg lfsr_enable;
    reg [7:0] board_reg [0:49];
    reg [31:0] iter_count;
    reg [31:0] conflict_count;
    reg [7:0] selected_col;
    reg [7:0] test_row;
    reg [31:0] min_conflicts;
    reg [7:0] best_row;
    reg [31:0] max_conflicts;
    reg [3:0] restart_count;
    reg [31:0] no_improve_count;
    reg [31:0] previous_conflict_count;
    reg [31:0] walk_steps;
    reg [7:0] init_counter;
    reg [7:0] scan_col;
    reg [7:0] col_candidate_count;
    reg [7:0] conflict_cols [0:49];
    reg [7:0] row_candidate_count;
    reg [7:0] row_candidates [0:49];
    reg [31:0] current_col_conflicts;
    reg [31:0] current_row_conflicts;
    reg [31:0] iter_per_restart;

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
    function count_conflicts;
        input [7:0] row;
        input [7:0] col;
        reg [31:0] conflicts;
        reg [7:0] other_row;
        integer i;
        begin
            conflicts = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (i != col) begin
                    other_row = board_reg[i];
                    if (other_row == row) begin
                        conflicts = conflicts + 1;
                    end else if (((other_row + i) == (row + col)) || ((other_row - i) == (row - col))) begin
                        conflicts = conflicts + 1;
                    end
                end
            end
            count_conflicts = conflicts;
        end
    endfunction

    // Calculate total pairwise conflicts
    always @(*) begin
        integer total_conflicts;
        integer row_i;
        integer row_j;
        integer i;
        integer j;
        total_conflicts = 0;
        for (i = 0; i < N; i = i + 1) begin
            row_i = board_reg[i];
            for (j = i + 1; j < N; j = j + 1) begin
                row_j = board_reg[j];
                if (row_i == row_j) begin
                    total_conflicts = total_conflicts + 1;
                end else if (((row_i + i) == (row_j + j)) || ((row_i - i) == (row_j - j))) begin
                    total_conflicts = total_conflicts + 1;
                end
            end
        end
        conflict_count = total_conflicts;
    end

    // FSM sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= ST_IDLE;
            for (i = 0; i < N; i = i + 1) begin
                board_reg[i] <= 8'b0;
                conflict_cols[i] <= 8'b0;
                row_candidates[i] <= 8'b0;
            end
            iter_count <= 32'b0;
            selected_col <= 8'b0;
            test_row <= 8'b0;
            min_conflicts <= 32'hFFFFFFFF;
            best_row <= 8'b0;
            restart_count <= 4'b0;
            no_improve_count <= 32'b0;
            previous_conflict_count <= 32'b0;
            walk_steps <= 32'b0;
            init_counter <= 8'b0;
            scan_col <= 8'b0;
            col_candidate_count <= 8'b0;
            row_candidate_count <= 8'b0;
            current_col_conflicts <= 32'b0;
            current_row_conflicts <= 32'b0;
            iter_per_restart <= MAX_ITERATIONS / 10;
            lfsr_enable <= 1'b0;
        end else begin
            current_state <= next_state;
            lfsr_enable <= 1'b0;

            case (current_state)
                ST_IDLE: begin
                    if (start) begin
                        iter_count <= 32'b0;
                        restart_count <= 4'b0;
                        no_improve_count <= 32'b0;
                        previous_conflict_count <= 32'b0;
                        walk_steps <= 32'b0;
                        init_counter <= 8'b0;
                        scan_col <= 8'b0;
                        col_candidate_count <= 8'b0;
                        row_candidate_count <= 8'b0;
                    end
                end

                ST_INIT: begin
                    board_reg[init_counter] <= (lfsr_state[7:0] % N);
                    lfsr_enable <= 1'b1;
                    if (init_counter < (N - 1)) begin
                        init_counter <= init_counter + 1;
                    end else begin
                        init_counter <= 8'b0;
                    end
                end

                ST_FIND_CONFLICT_COL: begin
                    scan_col <= 8'b0;
                    max_conflicts <= 32'b0;
                    col_candidate_count <= 8'b0;
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
                        selected_col <= 8'b0;
                    end else if (col_candidate_count == 1) begin
                        selected_col <= conflict_cols[0];
                    end else begin
                        reg [7:0] random_index;
                        random_index = (lfsr_state[7:0] % col_candidate_count);
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
                        selected_col <= (lfsr_state[7:0] % N);
                        best_row <= (lfsr_state[7:0] % N);
                        walk_steps <= walk_steps + 1;
                        lfsr_enable <= 1'b1;
                    end else begin
                        test_row <= 8'b0;
                        min_conflicts <= 32'hFFFFFFFF;
                        row_candidate_count <= 8'b0;
                        if (no_improve_count > MAX_NO_IMPROVE) begin
                            walk_steps <= walk_steps + 1;
                        end else begin
                            walk_steps <= 32'b0;
                        end
                    end
                end

                ST_EVAL_ROW: begin
                    current_row_conflicts <= count_conflicts(test_row, selected_col);
                    if (current_row_conflicts < min_conflicts) begin
                        min_conflicts <= current_row_conflicts;
                        row_candidate_count <= 8'b1;
                        row_candidates[0] <= test_row;
                    end else if (current_row_conflicts == min_conflicts) begin
                        row_candidates[row_candidate_count] <= test_row;
                        row_candidate_count <= row_candidate_count + 1;
                    end
                    if (test_row < (N - 1)) begin
                        test_row <= test_row + 1;
                    end
                end

                ST_SELECT_ROW: begin
                    if (row_candidate_count == 1) begin
                        best_row <= row_candidates[0];
                    end else begin
                        reg [7:0] random_index;
                        random_index = (lfsr_state[7:0] % row_candidate_count);
                        best_row <= random_index;
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
                    iter_count <= 32'b0;
                    no_improve_count <= 32'b0;
                    walk_steps <= 32'b0;
                    init_counter <= 8'b0;
                    scan_col <= 8'b0;
                    col_candidate_count <= 8'b0;
                end

                ST_DONE: begin
                    // stay in done state
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: begin
                if (start) next_state = ST_INIT;
            end

            ST_INIT: begin
                if (init_counter >= (N - 1)) begin
                    next_state = ST_FIND_CONFLICT_COL;
                end
            end

            ST_FIND_CONFLICT_COL: begin
                next_state = ST_SCAN_COLUMN;
            end

            ST_SCAN_COLUMN: begin
                if (scan_col == (N - 1)) begin
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
                if (test_row == (N - 1)) begin
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

    assign iterations = iter_count;
    assign conflicts = conflict_count;
    assign done = (current_state == ST_DONE);

    integer i;
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            board_row[i] = board_reg[i];
        end
    end

endmodule

`endif // N_QUEENS_SV
