// Top-level para a DE2 (Cyclone IV GX) — N-Rainhas via algoritmo genético.
//
// SW[17]   : reset_n (deve ser aplicado antes de cada start)
// SW[0]    : start (borda de subida; só funciona após reset)
// LEDG[8]  : done
// LEDG[0]  : running
// LEDR     : N inferiores da solução (concatenação dos genes)
// HEX0-HEX7: tempo total em microssegundos (8 dígitos BCD, até 99.999.999 µs ≈ 100 s)

module n_queens_top #(
    parameter int N         = 8,
    parameter int GENE_BITS = 3
)(
    input  wire        CLOCK_50,
    input  wire [17:0] SW,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [6:0]  HEX4, HEX5, HEX6, HEX7,
    output wire [8:0]  LEDG,
    output wire [17:0] LEDR
);

    wire rst_n = SW[17];

    // --- Detector de borda em SW[0] ---
    reg sw0_r, sw0_rr;
    wire start_pulse = sw0_r & ~sw0_rr;

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            sw0_r  <= 1'b0;
            sw0_rr <= 1'b0;
        end else begin
            sw0_r  <= SW[0];
            sw0_rr <= sw0_r;
        end
    end

    // --- Garante reset antes do start ---
    // reset_seen é setado em cada ciclo com rst_n=0 e limpo quando start dispara.
    // start_gated só pulsa se um reset foi aplicado desde o último start.
    reg reset_seen;
    always @(posedge CLOCK_50) begin
        if (!rst_n)
            reset_seen <= 1'b1;
        else if (start_pulse)
            reset_seen <= 1'b0;
    end

    wire start_gated = start_pulse & reset_seen;

    // --- GA core ---
    wire                   s_done, s_running;
    wire [N*GENE_BITS-1:0] s_best_solution;
    wire [11:0]            s_best_fitness;
    wire [19:0]            s_generation;

    n_queens_ga_core #(
        .N         (N),
        .GENE_BITS (GENE_BITS)
    ) u_ga (
        .clk           (CLOCK_50),
        .rst_n         (rst_n),
        .start         (start_gated),
        .done          (s_done),
        .running       (s_running),
        .best_solution (s_best_solution),
        .best_fitness  (s_best_fitness),
        .generation    (s_generation)
    );

    // --- LEDs ---
    assign LEDG[8]   = s_done;
    assign LEDG[0]   = s_running;
    assign LEDG[7:1] = 7'b0;

    generate
        if (N*GENE_BITS >= 18) begin : g_ledr_trim
            assign LEDR = s_best_solution[17:0];
        end else begin : g_ledr_pad
            assign LEDR = { {(18 - N*GENE_BITS){1'b0}}, s_best_solution };
        end
    endgenerate

    // --- Cronômetro: conta de start_gated até done, congela ao terminar ---
    // 8 dígitos BCD em microssegundos: HEX0=unidades, HEX7=dezenas de milhão
    // A 50 MHz: 1 µs = 50 ciclos de clock.
    localparam int CYCLES_PER_US = 50;
    reg [5:0] presc;
    reg [3:0] us0, us1, us2, us3, us4, us5, us6, us7;

    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            presc <= 0;
            us0 <= 0; us1 <= 0; us2 <= 0; us3 <= 0;
            us4 <= 0; us5 <= 0; us6 <= 0; us7 <= 0;
        end else if (start_gated) begin
            presc <= 0;
            us0 <= 0; us1 <= 0; us2 <= 0; us3 <= 0;
            us4 <= 0; us5 <= 0; us6 <= 0; us7 <= 0;
        end else if (s_running && !s_done) begin
            if (presc == CYCLES_PER_US - 1) begin
                presc <= 0;
                if (us0 == 9) begin us0 <= 0;
                    if (us1 == 9) begin us1 <= 0;
                        if (us2 == 9) begin us2 <= 0;
                            if (us3 == 9) begin us3 <= 0;
                                if (us4 == 9) begin us4 <= 0;
                                    if (us5 == 9) begin us5 <= 0;
                                        if (us6 == 9) begin us6 <= 0;
                                            if (us7 != 9) us7 <= us7 + 4'd1;
                                        end else us6 <= us6 + 4'd1;
                                    end else us5 <= us5 + 4'd1;
                                end else us4 <= us4 + 4'd1;
                            end else us3 <= us3 + 4'd1;
                        end else us2 <= us2 + 4'd1;
                    end else us1 <= us1 + 4'd1;
                end else us0 <= us0 + 4'd1;
            end else begin
                presc <= presc + 6'd1;
            end
        end
    end

    // --- Displays: HEX0–HEX7 mostram tempo em µs (8 dígitos BCD) ---
    display d0 ( .hex_digit(us0), .segments(HEX0) );
    display d1 ( .hex_digit(us1), .segments(HEX1) );
    display d2 ( .hex_digit(us2), .segments(HEX2) );
    display d3 ( .hex_digit(us3), .segments(HEX3) );
    display d4 ( .hex_digit(us4), .segments(HEX4) );
    display d5 ( .hex_digit(us5), .segments(HEX5) );
    display d6 ( .hex_digit(us6), .segments(HEX6) );
    display d7 ( .hex_digit(us7), .segments(HEX7) );

endmodule  // n_queens_top
