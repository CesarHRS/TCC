// Simplex sintetizável em Verilog-2001 (CPLD/FPGA)
// Exemplo: max z = 3x1 + 2x2
//          s.t. 2x1 + 1x2 <= 18
//               2x1 + 3x2 <= 42
//               3x1 + 1x2 <= 24
// Este módulo opera com M constraints e N variáveis, usando fixed-point Q16.16.

module simplex #(
    parameter M = 3,
    parameter N = 2,
    parameter W = 32,
    parameter Q = 16,
    parameter MAX_ITERS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire done,
    output wire unbounded,
    output wire infeasible,
    output wire signed [W-1:0] objective,
    output wire signed [W-1:0] x_out_0,
    output wire signed [W-1:0] x_out_1
);

    // FSM states (using localparam instead of typedef enum)
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam ENTER_SELECT = 3'd2;
    localparam LEAVE_SELECT = 3'd3;
    localparam PIVOT_ROW = 3'd4;
    localparam ELIMINATE_COL = 3'd5;
    localparam STATE_DONE = 3'd6;

    reg [2:0] state_r, state_nxt;

    localparam COLS = N + M + 1; 

    reg signed [W-1:0] tableau [0:M][0:COLS-1];
    reg signed [W-1:0] A_init [0:M-1][0:N-1];
    reg signed [W-1:0] b_init [0:M-1];
    reg signed [W-1:0] c_init [0:N-1];

    reg [7:0] basis_idx [0:M-1];

    reg [31:0] enter_col;
    reg [31:0] leave_row;
    reg [31:0] iter_count;

    reg signed [W-1:0] best_ratio;
    reg signed [W-1:0] pivot;
    reg signed [W-1:0] coef;
    reg signed [W-1:0] ratio;
    reg signed [W-1:0] factor;

    reg done_r, unbounded_r, infeasible_r;
    reg signed [W-1:0] objective_r;
    reg signed [W-1:0] x_r [0:N-1];

    assign done = done_r;
    assign unbounded = unbounded_r;
    assign infeasible = infeasible_r;
    assign objective = objective_r;
    assign x_out_0 = x_r[0];
    assign x_out_1 = x_r[1];

    // Initialize parameters (in Quartus 13.0 compatible way)
    initial begin
        // A (2x +1y, ...), valores em Q16.16
        A_init[0][0] = 32'd131072; // 2.0
        A_init[0][1] = 32'd65536;  // 1.0
        A_init[1][0] = 32'd131072; // 2.0
        A_init[1][1] = 32'd196608; // 3.0
        A_init[2][0] = 32'd196608; // 3.0
        A_init[2][1] = 32'd65536;  // 1.0

        b_init[0] = 32'd1179648; // 18.0
        b_init[1] = 32'd2752512; // 42.0
        b_init[2] = 32'd1572864; // 24.0

        c_init[0] = 32'd196608;  // 3.0
        c_init[1] = 32'd131072;  // 2.0
    end

    // Fixed-point multiplication Q16.16
    function [W-1:0] fx_mul;
        input [W-1:0] a;
        input [W-1:0] b;
        reg [2*W-1:0] prod;
        begin
            prod = a * b;
            fx_mul = prod >>> Q;
        end
    endfunction

    // Fixed-point division Q16.16
    function [W-1:0] fx_div;
        input [W-1:0] a;
        input [W-1:0] b;
        reg [2*W-1:0] numer;
        begin
            if (b == 0) begin
                fx_div = (a >= 0) ? {1'b0, {(W-1){1'b1}}} : {1'b1, {(W-1){1'b1}}};
            end else begin
                numer = (a <<< Q);
                fx_div = numer / b;
            end
        end
    endfunction

    // Sequential FSM logic
    always @(posedge clk or negedge rst_n) begin
        integer i, j, vid;
        
        if (!rst_n) begin
            state_r <= IDLE;
            done_r <= 0;
            unbounded_r <= 0;
            infeasible_r <= 0;
            iter_count <= 0;
            objective_r <= 0;
            for (i = 0; i < N; i = i + 1) x_r[i] <= 0;
        end else begin
            state_r <= state_nxt;

            case (state_r)
                IDLE: begin
                    done_r <= 0;
                    unbounded_r <= 0;
                    infeasible_r <= 0;
                    iter_count <= 0;
                    objective_r <= 0;
                end
                INIT: begin
                    done_r <= 0;
                    unbounded_r <= 0;
                    infeasible_r <= 0;
                    for (i = 0; i < M; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) 
                            tableau[i][j] <= A_init[i][j];
                        for (j = 0; j < M; j = j + 1) 
                            tableau[i][N+j] <= (i==j) ? 32'd65536 : 0;
                        tableau[i][N+M] <= b_init[i];
                        basis_idx[i] <= N + i;
                    end
                    for (j = 0; j < N; j = j + 1) 
                        tableau[M][j] <= -c_init[j];
                    for (j = 0; j < M; j = j + 1) 
                        tableau[M][N+j] <= 0;
                    tableau[M][N+M] <= 0;
                end
                ENTER_SELECT: begin
                    done_r <= 0;
                    enter_col <= -1;
                    for (j = 0; j < N+M; j = j + 1) begin
                        if (tableau[M][j] < 0) begin
                            if (enter_col == -1 || tableau[M][j] < tableau[M][enter_col]) begin
                                enter_col <= j;
                            end
                        end
                    end
                end
                LEAVE_SELECT: begin
                    done_r <= 0;
                    unbounded_r <= 0;
                    infeasible_r <= 0;
                    leave_row <= -1;
                    best_ratio <= 0;
                    for (i = 0; i < M; i = i + 1) begin
                        coef <= tableau[i][enter_col];
                        if (coef > 0) begin
                            ratio <= fx_div(tableau[i][N+M], coef);
                            if (leave_row == -1 || ratio < best_ratio) begin
                                leave_row <= i;
                                best_ratio <= ratio;
                            end
                        end
                    end
                    if (enter_col == -1) begin
                        // state transition built in always_comb
                    end else if (leave_row == -1) begin
                        unbounded_r <= 1;
                    end
                end
                PIVOT_ROW: begin
                    done_r <= 0;
                    pivot <= tableau[leave_row][enter_col];
                    for (j = 0; j < COLS; j = j + 1) begin
                        tableau[leave_row][j] <= fx_div(tableau[leave_row][j], pivot);
                    end
                    basis_idx[leave_row] <= enter_col;
                end
                ELIMINATE_COL: begin
                    done_r <= 0;
                    for (i = 0; i <= M; i = i + 1) begin
                        if (i != leave_row) begin
                            factor <= tableau[i][enter_col];
                            for (j = 0; j < COLS; j = j + 1) begin
                                tableau[i][j] <= tableau[i][j] - fx_mul(factor, tableau[leave_row][j]);
                            end
                        end
                    end
                    iter_count <= iter_count + 1;
                    if (iter_count >= MAX_ITERS) begin
                        infeasible_r <= 1; 
                    end
                end
                STATE_DONE: begin
                    objective_r <= tableau[M][N+M];
                    for (j = 0; j < N; j = j + 1) x_r[j] <= 0;
                    for (i = 0; i < M; i = i + 1) begin
                        vid = basis_idx[i];
                        if (vid < N) x_r[vid] <= tableau[i][N+M];
                    end
                    done_r <= 1;
                end
            endcase
        end
    end

    // Combinational next-state logic
    always @(*) begin
        state_nxt = state_r;
        case (state_r)
            IDLE: if (start) state_nxt = INIT;
            INIT: state_nxt = ENTER_SELECT;
            ENTER_SELECT: state_nxt = LEAVE_SELECT;
            LEAVE_SELECT: begin
                if (enter_col == -1) state_nxt = STATE_DONE;
                else if (leave_row == -1) state_nxt = STATE_DONE;
                else state_nxt = PIVOT_ROW;
            end
            PIVOT_ROW: state_nxt = ELIMINATE_COL;
            ELIMINATE_COL: begin
                if (unbounded_r || infeasible_r) state_nxt = STATE_DONE;
                else state_nxt = ENTER_SELECT;
            end
            STATE_DONE: if (!start) state_nxt = IDLE;
        endcase
    end

endmodule
