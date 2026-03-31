// Simplex sintetizável em SystemVerilog (CPLD/FPGA)
// Exemplo: max z = 3x1 + 2x2
//          s.t. 2x1 + 1x2 <= 18
//               2x1 + 3x2 <= 42
//               3x1 + 1x2 <= 24
// Este módulo opera com M constraints e N variáveis, usando fixed-point Q16.16.

module simplex #(
    parameter int M = 3,
    parameter int N = 2,
    parameter int W = 32,
    parameter int Q = 16,
    parameter int MAX_ITERS = 20
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,
    output logic unbounded,
    output logic infeasible,
    output logic signed [W-1:0] objective,
    output logic signed [W-1:0] x [0:N-1]
);

    typedef enum logic [2:0] {
        IDLE,
        INIT,
        ENTER_SELECT,
        LEAVE_SELECT,
        PIVOT_ROW,
        ELIMINATE_COL,
        DONE
    } state_t;

    state_t state_r, state_nxt;

    localparam int COLS = N + M + 1; 

    logic signed [W-1:0] tableau [0:M][0:COLS-1];
    logic signed [W-1:0] A_init [0:M-1][0:N-1];
    logic signed [W-1:0] b_init [0:M-1];
    logic signed [W-1:0] c_init [0:N-1];

    logic [$clog2(N+M)-1:0] basis_idx [0:M-1];

    int enter_col;
    int leave_row;
    int iter_count;

    logic signed [W-1:0] best_ratio;
    logic signed [W-1:0] pivot;
    logic signed [W-1:0] coef;
    logic signed [W-1:0] ratio;
    logic signed [W-1:0] factor;

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

    // Função para multiplicar em fixed point Q16.16
    function automatic logic signed [W-1:0] fx_mul (
        input logic signed [W-1:0] a,
        input logic signed [W-1:0] b);
        logic signed [2*W-1:0] prod;
        begin
            prod = a * b;
            fx_mul = prod >>> Q;
        end
    endfunction

    function automatic logic signed [W-1:0] fx_div (
        input logic signed [W-1:0] a,
        input logic signed [W-1:0] b);
        logic signed [2*W-1:0] numer;
        begin
            if (b == 0) begin
                fx_div = (a >= 0) ? {1'b0, {(W-1){1'b1}}} : {1'b1, {(W-1){1'b1}}};
            end else begin
                numer = (a <<< Q);
                fx_div = numer / b;
            end
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r <= IDLE;
            done <= 0;
            unbounded <= 0;
            infeasible <= 0;
            iter_count <= 0;
            objective <= 0;
            for (int i = 0; i < N; i++) x[i] <= 0;
        end else begin
            state_r <= state_nxt;

            case (state_r)
                IDLE: begin
                    done <= 0;
                    unbounded <= 0;
                    infeasible <= 0;
                    iter_count <= 0;
                    objective <= 0;
                end
                INIT: begin
                    done <= 0;
                    unbounded <= 0;
                    infeasible <= 0;
                    for (int i = 0; i < M; i++) begin
                        for (int j = 0; j < N; j++) tableau[i][j] = A_init[i][j];
                        for (int j = 0; j < M; j++) tableau[i][N+j] = (i==j) ? 32'd65536 : 0;
                        tableau[i][N+M] = b_init[i];
                        basis_idx[i] = N + i;
                    end
                    for (int j = 0; j < N; j++) tableau[M][j] = -c_init[j];
                    for (int j = 0; j < M; j++) tableau[M][N+j] = 0;
                    tableau[M][N+M] = 0;
                end
                ENTER_SELECT: begin
                    done <= 0;
                    enter_col = -1;
                    for (int j = 0; j < N+M; j++) begin
                        if (tableau[M][j] < 0) begin
                            if (enter_col == -1 || tableau[M][j] < tableau[M][enter_col]) begin
                                enter_col = j;
                            end
                        end
                    end
                end
                LEAVE_SELECT: begin
                    done <= 0;
                    unbounded <= 0;
                    infeasible <= 0;
                    leave_row = -1;
                    best_ratio = 0;
                    for (int i = 0; i < M; i++) begin
                        coef = tableau[i][enter_col];
                        if (coef > 0) begin
                            ratio = fx_div(tableau[i][N+M], coef);
                            if (leave_row == -1 || ratio < best_ratio) begin
                                leave_row = i;
                                best_ratio = ratio;
                            end
                        end
                    end
                    if (enter_col == -1) begin
                        ; // state transition built in always_comb
                    end else if (leave_row == -1) begin
                        unbounded <= 1;
                    end
                end
                PIVOT_ROW: begin
                    done <= 0;
                    pivot = tableau[leave_row][enter_col];
                    for (int j = 0; j < COLS; j++) begin
                        tableau[leave_row][j] = fx_div(tableau[leave_row][j], pivot);
                    end
                    basis_idx[leave_row] = enter_col;
                end
                ELIMINATE_COL: begin
                    done <= 0;
                    for (int i = 0; i <= M; i++) begin
                        if (i != leave_row) begin
                            factor = tableau[i][enter_col];
                            for (int j = 0; j < COLS; j++) begin
                                tableau[i][j] = tableau[i][j] - fx_mul(factor, tableau[leave_row][j]);
                            end
                        end
                    end
                    iter_count <= iter_count + 1;
                    if (iter_count >= MAX_ITERS) begin
                        infeasible <= 1; 
                    end
                end
                DONE: begin
                    objective <= tableau[M][N+M];
                    for (int j = 0; j < N; j++) x[j] <= 0;
                    for (int i = 0; i < M; i++) begin
                        int vid = basis_idx[i];
                        if (vid < N) x[vid] <= tableau[i][N+M];
                    end
                    done <= 1;
                end
            endcase
        end
    end

    always_comb begin
        state_nxt = state_r;
        case (state_r)
            IDLE: if (start) state_nxt = INIT;
            INIT: state_nxt = ENTER_SELECT;
            ENTER_SELECT: state_nxt = LEAVE_SELECT;
            LEAVE_SELECT: begin
                if (enter_col == -1) state_nxt = DONE;
                else if (leave_row == -1) state_nxt = DONE;
                else state_nxt = PIVOT_ROW;
            end
            PIVOT_ROW: state_nxt = ELIMINATE_COL;
            ELIMINATE_COL: begin
                if (unbounded || infeasible) state_nxt = DONE;
                else state_nxt = ENTER_SELECT;
            end
            DONE: if (!start) state_nxt = IDLE;
        endcase
    end

endmodule
