// Algoritmo genético para o problema das N rainhas.
// Equivalente estrutural ao C++ em cpp/n_queens/genetic.cpp.
//
// Correções de sintetizabilidade aplicadas:
//   1. pack_chrom removida — escritas usam chrom_reg_flat_w (wire combinacional).
//   2. Fisher-Yates sem divisor variável — máscara de bits + rejeição.
//   3. Leituras de população com saída registrada (padrão BRAM single-port).
//      rd_addr é um wire combinacional; as quatro saídas registradas
//      (fit_a_rd, fit_b_rd, pop_a_rd, pop_b_rd) são inferidas como BRAM
//      pelo Quartus.

module n_queens_ga_core #(
    parameter int N          = 8,
    parameter int GENE_BITS  = 3,
    parameter int POP_SIZE   = 300,
    parameter int ELITE      = 30,
    parameter int TOURN_SIZE = 4,
    parameter int MUT_THRESH = 10,
    parameter int MUT_BITS   = 7,
    parameter int STAG_LIMIT = 150,
    parameter int FULL_RESET = 8,
    parameter int MAX_GENS   = 500_000,
    parameter int FIT_BITS   = 12,
    parameter int POP_BITS   = 10,
    parameter int GEN_BITS   = 20
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    start,
    output reg                     done,
    output reg                     running,
    output reg  [N*GENE_BITS-1:0]  best_solution,
    output reg  [FIT_BITS-1:0]     best_fitness,
    output reg  [GEN_BITS-1:0]     generation
);

    localparam int CHROM_W = N * GENE_BITS;

    // -------------------------------------------------------------------------
    //  Memórias de população (double-buffer)
    //  Escrita: dentro do always sequencial (padrão BRAM write-port).
    //  Leitura: saídas registradas separadas abaixo (padrão BRAM read-port).
    // -------------------------------------------------------------------------
    reg [CHROM_W-1:0]  pop_a [0:POP_SIZE-1];
    reg [CHROM_W-1:0]  pop_b [0:POP_SIZE-1];
    reg [FIT_BITS-1:0] fit_a [0:POP_SIZE-1];
    reg [FIT_BITS-1:0] fit_b [0:POP_SIZE-1];
    reg                buf_sel;  // 0: atual=a, próximo=b  |  1: atual=b, próximo=a

    // -------------------------------------------------------------------------
    //  Porta de leitura registrada — padrão inferível como BRAM pelo Quartus.
    //  rd_addr é combinacional (wire); os quatro registradores capturam
    //  os dados no flanco de subida, disponíveis um ciclo depois.
    // -------------------------------------------------------------------------
    wire [POP_BITS-1:0] rd_addr;           // definido no mux combinacional abaixo

    reg [CHROM_W-1:0]  pop_a_rd, pop_b_rd;
    reg [FIT_BITS-1:0] fit_a_rd, fit_b_rd;

    always @(posedge clk) begin
        pop_a_rd <= pop_a[rd_addr];
        pop_b_rd <= pop_b[rd_addr];
        fit_a_rd <= fit_a[rd_addr];
        fit_b_rd <= fit_b[rd_addr];
    end

    // Seleção do banco atual / próximo após leitura registrada.
    // buf_sel já atualizado → mux puramente combinacional, sem ciclo extra.
    wire [CHROM_W-1:0]  pop_cur_rd = buf_sel ? pop_b_rd : pop_a_rd;
    wire [FIT_BITS-1:0] fit_cur_rd = buf_sel ? fit_b_rd : fit_a_rd;

    // -------------------------------------------------------------------------
    //  LFSR
    // -------------------------------------------------------------------------
    reg        lfsr_en;
    wire [63:0] lfsr_state;

    lfsr64 u_lfsr (
        .clk    (clk),
        .rst_n  (rst_n),
        .enable (lfsr_en),
        .state  (lfsr_state)
    );

    // -------------------------------------------------------------------------
    //  Registradores de trabalho
    // -------------------------------------------------------------------------
    reg [GENE_BITS-1:0] chrom_reg [0:N-1];
    reg [N-1:0]         used_mask;
    reg [CHROM_W-1:0]   parent1_flat, parent2_flat;

    // Empacotamento combinacional de chrom_reg (substitui função automatic).
    wire [CHROM_W-1:0] chrom_reg_flat_w;
    genvar gpk;
    generate
        for (gpk = 0; gpk < N; gpk++) begin : g_pack
            assign chrom_reg_flat_w[gpk*GENE_BITS +: GENE_BITS] = chrom_reg[gpk];
        end
    endgenerate

    // Fitness combinacional do cromossomo em trabalho.
    wire [FIT_BITS-1:0] chrom_reg_fitness;
    fitness #(.N(N), .GENE_BITS(GENE_BITS), .FIT_BITS(FIT_BITS)) u_fit (
        .chrom_flat (chrom_reg_flat_w),
        .conflicts  (chrom_reg_fitness)
    );

    // Extração de gene por índice variável (infere mux, não divisor).
    function automatic [GENE_BITS-1:0] gene_of;
        input [CHROM_W-1:0] flat;
        input integer        idx;
        gene_of = flat[idx*GENE_BITS +: GENE_BITS];
    endfunction

    // -------------------------------------------------------------------------
    //  Máscara Fisher-Yates (Correção 2) — sem divisor variável
    // -------------------------------------------------------------------------
    reg [GENE_BITS:0]   fy_i;
    reg [GENE_BITS-1:0] fy_mask;
    always @* begin
        if      (fy_i <= 1)  fy_mask = {{(GENE_BITS-1){1'b0}}, 1'b1};
        else if (fy_i <= 3)  fy_mask = {{(GENE_BITS-2){1'b0}}, 2'b11};
        else if (fy_i <= 7)  fy_mask = {{(GENE_BITS-3){1'b0}}, 3'b111};
        else                 fy_mask = {GENE_BITS{1'b1}};
    end

    // -------------------------------------------------------------------------
    //  Contadores e flags de controle
    // -------------------------------------------------------------------------
    reg [POP_BITS:0]   init_idx;
    reg [POP_BITS:0]   elite_scan_idx;
    reg [POP_BITS-1:0] elite_best_idx;
    reg [FIT_BITS-1:0] elite_best_fit;
    reg                elite_best_valid;
    reg [POP_BITS:0]   elite_idx;
    reg [POP_SIZE-1:0] selected_mask;

    reg [POP_BITS:0]   breed_idx;

    // Torneio
    reg [$clog2(TOURN_SIZE+1)-1:0] tourn_cnt;
    reg [POP_BITS-1:0]             tourn_best_idx;
    reg [FIT_BITS-1:0]             tourn_best_fit;
    reg [POP_BITS-1:0]             tourn_rd_idx;   // índice lido neste ciclo (salvo para S_TOURN_WAIT)
    reg                            doing_p2;        // 0=torneio para parent1, 1=para parent2

    reg [POP_BITS-1:0] parent1_idx, parent2_idx;

    // Crossover OX1
    reg [GENE_BITS:0] cross_a, cross_b;
    reg [GENE_BITS:0] cross_i;
    reg [GENE_BITS:0] cross_pos;
    wire [GENE_BITS:0] cross_read_idx = (cross_b + 1 + cross_i) % N;
    wire [GENE_BITS:0] cross_pos_next = (cross_pos + 1) % N;

    // Varredura do melhor
    reg [POP_BITS:0]   scan_idx;
    reg [FIT_BITS-1:0] scan_best_fit;
    reg [POP_BITS-1:0] scan_best_idx;

    reg [FIT_BITS-1:0] best_fit_reg;
    reg [$clog2(STAG_LIMIT+1)-1:0] stagnate_cnt;
    reg [$clog2(FULL_RESET+1)-1:0] partial_reset_cnt;
    reg [GEN_BITS-1:0] gen_cnt;

    reg [POP_BITS:0]   reset_start_idx;

    // -------------------------------------------------------------------------
    //  Estados
    // -------------------------------------------------------------------------
    typedef enum logic [4:0] {
        S_IDLE,
        S_RESET_BEGIN,
        S_PERM_LOAD,
        S_PERM_STEP,
        S_PERM_WRITE,
        S_SCAN_WARM,        // 1 ciclo: aquece rd_addr=0 antes de qualquer scan
        S_INIT_FIND_BEST,   // scan sequencial após init total
        S_GEN_START,        // aquece rd_addr=0 para elite scan
        S_ELITE_SCAN,       // scan sequencial (rd_addr = idx+1 em mux)
        S_ELITE_COMMIT,     // copia elite; aquece rd_addr=0 p/ próximo scan
        S_BREED_START,
        S_TOURN,            // apresenta rd_addr = candidato LFSR; salva idx
        S_TOURN_WAIT,       // consome fit_cur_rd do candidato
        S_TOURN_DONE,       // fixa parent1 ou parent2; prepara rd_addr=parent1_idx
        S_CROSS_RD_P1,      // salva parent1_flat; apresenta rd_addr=parent2_idx
        S_CROSS_INIT,       // salva parent2_flat; sorteia a,b
        S_CROSS_PHASE1,
        S_CROSS_PHASE2,
        S_MAYBE_MUTATE,
        S_MUTATE,
        S_BREED_WRITE,
        S_SWAP_BUF,         // troca buf_sel; mux leva rd_addr=0 (warm-up new best scan)
        S_NEW_BEST_SCAN,    // scan sequencial
        S_SCAN_DONE,        // 1 ciclo: rd_addr=scan_best_idx → pop lido em CHECK_STAG
        S_CHECK_STAG,
        S_DONE
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    //  Mux combinacional de rd_addr (Correção 3 — núcleo)
    //
    //  Princípio de pipeline para scans sequenciais:
    //    • Estado anterior (S_GEN_START, S_ELITE_COMMIT, S_SWAP_BUF, S_SCAN_WARM)
    //      leva rd_addr=0 → no flanco, fit_rd captura fit[0].
    //    • No estado de scan, rd_addr = scan_idx+1 → fit_rd captura fit[scan_idx+1].
    //      No PRÓXIMO ciclo, scan_idx será scan_idx+1 e fit_rd = fit[scan_idx] ✓.
    //    • Último ciclo de S_ELITE_SCAN: overide para elite_best_idx → dados do
    //      indivíduo elite prontos em S_ELITE_COMMIT sem estado extra.
    //
    //  Leituras aleatórias (torneio, pais): 1 ciclo de espera dedicado.
    // -------------------------------------------------------------------------
    reg [POP_BITS-1:0] rd_addr_r;
    assign rd_addr = rd_addr_r;

    integer ra;
    always @* begin
        case (state)
            // Warm-up para scans sequenciais (pre-fetch fit[0])
            S_GEN_START,
            S_ELITE_COMMIT,
            S_SCAN_WARM,
            S_SWAP_BUF:      rd_addr_r = 0;

            // Scan do elite: pre-fetch próximo; último ciclo lê elite_best_idx
            S_ELITE_SCAN:    rd_addr_r = (elite_scan_idx == POP_SIZE-1)
                                          ? elite_best_idx
                                          : elite_scan_idx[POP_BITS-1:0] + 1;

            // Scans do melhor global
            S_INIT_FIND_BEST,
            S_NEW_BEST_SCAN: rd_addr_r = scan_idx[POP_BITS-1:0] + 1;

            // Leitura pop[scan_best_idx] para S_CHECK_STAG
            S_SCAN_DONE:     rd_addr_r = scan_best_idx;

            // Torneio: candidato atual do LFSR
            S_TOURN:         rd_addr_r = lfsr_state[POP_BITS-1:0] % POP_SIZE;

            // Crossover: parent1 → parent2 (pipelinado em dois estados)
            // Quando doing_p2=1: parent2 acaba de ser fixado; pre-lê pop[parent1_idx].
            // Quando doing_p2=0: volta ao S_TOURN — rd_addr irrelevante neste flanco.
            S_TOURN_DONE:    rd_addr_r = parent1_idx;
            S_CROSS_RD_P1:   rd_addr_r = parent2_idx;

            default:         rd_addr_r = 0;
        endcase
    end

    // -------------------------------------------------------------------------
    //  Processo principal
    // -------------------------------------------------------------------------
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= S_IDLE;
            done               <= 0; running <= 0;
            best_solution      <= 0; best_fitness <= {FIT_BITS{1'b1}};
            best_fit_reg       <= {FIT_BITS{1'b1}};
            generation         <= 0; gen_cnt <= 0;
            stagnate_cnt       <= 0; partial_reset_cnt <= 0;
            buf_sel            <= 0;
            init_idx           <= 0; elite_scan_idx <= 0;
            elite_best_idx     <= 0; elite_best_fit <= {FIT_BITS{1'b1}};
            elite_best_valid   <= 0; elite_idx <= 0;
            selected_mask      <= 0;
            breed_idx          <= 0;
            tourn_cnt          <= 0; tourn_best_idx <= 0; tourn_best_fit <= {FIT_BITS{1'b1}};
            tourn_rd_idx       <= 0; doing_p2 <= 0;
            parent1_idx        <= 0; parent2_idx <= 0;
            cross_a            <= 0; cross_b <= 0; cross_i <= 0; cross_pos <= 0;
            scan_idx           <= 0; scan_best_fit <= {FIT_BITS{1'b1}}; scan_best_idx <= 0;
            reset_start_idx    <= 0;
            lfsr_en            <= 0;
            used_mask          <= 0;
            fy_i               <= 0;
            for (k = 0; k < N; k++) chrom_reg[k] <= 0;
        end else begin
            lfsr_en <= 0;

            case (state)

            // ----------------------------------------------------------------
            S_IDLE: begin
                done <= 0; running <= 0;
                if (start) begin
                    running <= 1;
                    best_fit_reg <= {FIT_BITS{1'b1}};
                    stagnate_cnt <= 0; partial_reset_cnt <= 0;
                    gen_cnt <= 0; buf_sel <= 0;
                    reset_start_idx <= 0;
                    init_idx <= 0;
                    state <= S_RESET_BEGIN;
                end
            end

            // ----------------------------------------------------------------
            S_RESET_BEGIN: begin
                init_idx <= reset_start_idx;
                state    <= S_PERM_LOAD;
            end

            S_PERM_LOAD: begin
                for (k = 0; k < N; k++) chrom_reg[k] <= k[GENE_BITS-1:0];
                fy_i  <= N - 1;
                state <= S_PERM_STEP;
            end

            // Fisher-Yates com máscara + rejeição (Correção 2).
            S_PERM_STEP: begin
                lfsr_en <= 1;
                if (fy_i == 0) begin
                    state <= S_PERM_WRITE;
                end else begin
                    begin : try_swap
                        reg [GENE_BITS-1:0] j_cand;
                        j_cand = lfsr_state[GENE_BITS-1:0] & fy_mask;
                        if (j_cand <= fy_i[GENE_BITS-1:0]) begin
                            chrom_reg[fy_i]   <= chrom_reg[j_cand];
                            chrom_reg[j_cand] <= chrom_reg[fy_i];
                            fy_i <= fy_i - 1;
                        end
                    end
                end
            end

            S_PERM_WRITE: begin
                if (buf_sel) begin
                    pop_b[init_idx] <= chrom_reg_flat_w;
                    fit_b[init_idx] <= chrom_reg_fitness;
                end else begin
                    pop_a[init_idx] <= chrom_reg_flat_w;
                    fit_a[init_idx] <= chrom_reg_fitness;
                end
                if (init_idx == POP_SIZE - 1) begin
                    // Warm-up para o scan: rd_addr=0 já apresentado pelo mux
                    // (S_PERM_WRITE → S_SCAN_WARM → scan).
                    scan_idx      <= 0;
                    scan_best_fit <= {FIT_BITS{1'b1}};
                    scan_best_idx <= 0;
                    state         <= S_SCAN_WARM;
                end else begin
                    init_idx <= init_idx + 1;
                    state    <= S_PERM_LOAD;
                end
            end

            // 1 ciclo de warm-up: rd_addr=0 → fit_rd captura fit[0] no flanco.
            S_SCAN_WARM: begin
                state <= S_INIT_FIND_BEST;
            end

            // Scan sequencial após init total.
            // fit_cur_rd = fit[scan_idx] (pré-buscado pelo estado anterior / ciclo anterior).
            S_INIT_FIND_BEST: begin
                begin : ibf
                    reg [FIT_BITS-1:0] f;
                    f = fit_cur_rd;   // fit[scan_idx] registrado no ciclo anterior
                    if (f < scan_best_fit) begin
                        scan_best_fit <= f;
                        scan_best_idx <= scan_idx[POP_BITS-1:0];
                    end
                end
                if (scan_idx == POP_SIZE - 1) begin
                    state <= S_SCAN_DONE;   // scan_best_idx finalizado → lê pop
                end else begin
                    scan_idx <= scan_idx + 1;
                end
            end

            // ----------------------------------------------------------------
            S_GEN_START: begin
                if (gen_cnt == MAX_GENS) begin
                    running <= 0; done <= 1; state <= S_DONE;
                end else begin
                    selected_mask    <= 0;
                    elite_idx        <= 0;
                    elite_scan_idx   <= 0;
                    elite_best_valid <= 0;
                    elite_best_fit   <= {FIT_BITS{1'b1}};
                    // rd_addr=0 já no mux → fit_rd captura fit[0] neste flanco.
                    state <= S_ELITE_SCAN;
                end
            end

            // Scan para elitismo.
            // Último ciclo (idx==POP_SIZE-1): mux leva rd_addr=elite_best_idx
            //   → pop_rd e fit_rd do melhor ficam prontos em S_ELITE_COMMIT.
            S_ELITE_SCAN: begin
                begin : escan
                    reg [FIT_BITS-1:0] f;
                    f = fit_cur_rd;  // fit[elite_scan_idx]
                    if (!selected_mask[elite_scan_idx] &&
                        (!elite_best_valid || f < elite_best_fit)) begin
                        elite_best_idx   <= elite_scan_idx[POP_BITS-1:0];
                        elite_best_fit   <= f;
                        elite_best_valid <= 1;
                    end
                end
                if (elite_scan_idx == POP_SIZE - 1) begin
                    state <= S_ELITE_COMMIT;
                end else begin
                    elite_scan_idx <= elite_scan_idx + 1;
                end
            end

            // pop_cur_rd = pop[elite_best_idx], fit_cur_rd = fit[elite_best_idx]
            // (capturados no último ciclo de S_ELITE_SCAN via override do mux).
            S_ELITE_COMMIT: begin
                selected_mask[elite_best_idx] <= 1;
                if (buf_sel) begin
                    pop_a[elite_idx] <= pop_cur_rd;
                    fit_a[elite_idx] <= fit_cur_rd;
                end else begin
                    pop_b[elite_idx] <= pop_cur_rd;
                    fit_b[elite_idx] <= fit_cur_rd;
                end
                if (elite_idx == ELITE - 1) begin
                    breed_idx <= ELITE;
                    state     <= S_BREED_START;
                end else begin
                    elite_idx        <= elite_idx + 1;
                    elite_scan_idx   <= 0;
                    elite_best_valid <= 0;
                    elite_best_fit   <= {FIT_BITS{1'b1}};
                    // rd_addr=0 no mux → aquece fit[0] para o próximo scan
                    state <= S_ELITE_SCAN;
                end
            end

            // ----------------------------------------------------------------
            S_BREED_START: begin
                tourn_cnt      <= 0;
                tourn_best_fit <= {FIT_BITS{1'b1}};
                tourn_best_idx <= 0;
                doing_p2       <= 0;
                state          <= S_TOURN;
            end

            // Apresenta rd_addr = lfsr % POP_SIZE (divisor FIXO, sintetizável).
            // Salva o índice para S_TOURN_WAIT comparar com fit_cur_rd.
            S_TOURN: begin
                lfsr_en      <= 1;
                tourn_rd_idx <= lfsr_state[POP_BITS-1:0] % POP_SIZE;
                tourn_cnt    <= tourn_cnt + 1;
                state        <= S_TOURN_WAIT;
            end

            // fit_cur_rd = fit[tourn_rd_idx] — dado válido 1 ciclo após S_TOURN.
            S_TOURN_WAIT: begin
                begin : tw
                    reg [FIT_BITS-1:0] f;
                    f = fit_cur_rd;
                    if (tourn_cnt == 1 || f < tourn_best_fit) begin
                        tourn_best_idx <= tourn_rd_idx;
                        tourn_best_fit <= f;
                    end
                end
                if (tourn_cnt == TOURN_SIZE)
                    state <= S_TOURN_DONE;
                else
                    state <= S_TOURN;
            end

            // Fixa parent1 ou parent2. Após parent2: rd_addr=parent1_idx no mux.
            S_TOURN_DONE: begin
                if (!doing_p2) begin
                    parent1_idx    <= tourn_best_idx;
                    doing_p2       <= 1;
                    tourn_cnt      <= 0;
                    tourn_best_fit <= {FIT_BITS{1'b1}};
                    state          <= S_TOURN;
                end else begin
                    parent2_idx <= tourn_best_idx;
                    doing_p2    <= 0;
                    // rd_addr = tourn_best_idx (= parent1_idx após NBA)
                    // → pop_rd captura pop[parent1_idx] neste flanco.
                    // (mux S_TOURN_DONE leva tourn_best_idx, mas parent2 acaba de ser fixado;
                    //  parent1_idx ainda está em tourn_best_idx do ciclo anterior do torneio,
                    //  não é mais tourn_best_idx agora. Usar parent1_idx explicitamente.)
                    state <= S_CROSS_RD_P1;
                end
            end

            // pop_cur_rd = pop[parent1_idx] (capturado no flanco de S_TOURN_DONE).
            // Apresenta rd_addr = parent2_idx → pop_rd captura pop[parent2_idx].
            S_CROSS_RD_P1: begin
                parent1_flat <= pop_cur_rd;
                state        <= S_CROSS_INIT;
            end

            // pop_cur_rd = pop[parent2_idx].
            // Sorteia pontos de corte a, b.
            S_CROSS_INIT: begin
                parent2_flat <= pop_cur_rd;
                lfsr_en      <= 1;
                begin : pick_ab
                    reg [GENE_BITS-1:0] a_now, b_now;
                    a_now = lfsr_state[GENE_BITS-1:0] % N;
                    b_now = lfsr_state[2*GENE_BITS-1:GENE_BITS] % N;
                    if (a_now <= b_now) begin cross_a <= a_now; cross_b <= b_now; end
                    else               begin cross_a <= b_now; cross_b <= a_now; end
                end
                used_mask <= 0;
                for (k = 0; k < N; k++) chrom_reg[k] <= 0;
                cross_i <= 0;
                state   <= S_CROSS_PHASE1;
            end

            S_CROSS_PHASE1: begin
                begin : ph1
                    reg [GENE_BITS:0]   idx;
                    reg [GENE_BITS-1:0] gene;
                    idx  = cross_a + cross_i;
                    gene = gene_of(parent1_flat, idx);
                    chrom_reg[idx]  <= gene;
                    used_mask[gene] <= 1;
                end
                if ((cross_a + cross_i) == cross_b) begin
                    cross_i   <= 0;
                    cross_pos <= (cross_b + 1) % N;
                    state     <= S_CROSS_PHASE2;
                end else begin
                    cross_i <= cross_i + 1;
                end
            end

            S_CROSS_PHASE2: begin
                if (cross_i == N) begin
                    state <= S_MAYBE_MUTATE;
                end else begin
                    begin : ph2
                        reg [GENE_BITS-1:0] gene;
                        gene = gene_of(parent2_flat, cross_read_idx);
                        if (!used_mask[gene]) begin
                            chrom_reg[cross_pos] <= gene;
                            used_mask[gene]      <= 1;
                            cross_pos            <= cross_pos_next;
                        end
                    end
                    cross_i <= cross_i + 1;
                end
            end

            S_MAYBE_MUTATE: begin
                lfsr_en <= 1;
                state   <= (lfsr_state[MUT_BITS-1:0] < MUT_THRESH) ? S_MUTATE : S_BREED_WRITE;
            end

            S_MUTATE: begin
                lfsr_en <= 1;
                begin : do_mut
                    reg [GENE_BITS-1:0] a_now, b_now;
                    a_now = lfsr_state[GENE_BITS-1:0] % N;
                    b_now = lfsr_state[2*GENE_BITS-1:GENE_BITS] % N;
                    chrom_reg[a_now] <= chrom_reg[b_now];
                    chrom_reg[b_now] <= chrom_reg[a_now];
                end
                state <= S_BREED_WRITE;
            end

            S_BREED_WRITE: begin
                if (buf_sel) begin
                    pop_a[breed_idx] <= chrom_reg_flat_w;
                    fit_a[breed_idx] <= chrom_reg_fitness;
                end else begin
                    pop_b[breed_idx] <= chrom_reg_flat_w;
                    fit_b[breed_idx] <= chrom_reg_fitness;
                end
                if (breed_idx == POP_SIZE - 1) begin
                    state <= S_SWAP_BUF;
                end else begin
                    breed_idx <= breed_idx + 1;
                    state     <= S_BREED_START;
                end
            end

            // Troca buffers. Mux leva rd_addr=0 → aquece fit[0] do novo banco atual.
            S_SWAP_BUF: begin
                buf_sel    <= ~buf_sel;
                gen_cnt    <= gen_cnt + 1;
                generation <= gen_cnt + 1;
                scan_idx      <= 0;
                scan_best_fit <= {FIT_BITS{1'b1}};
                scan_best_idx <= 0;
                state <= S_NEW_BEST_SCAN;
            end

            // Após S_SWAP_BUF: buf_sel atualizado, fit_rd capturou fit[0] do novo banco.
            // fit_cur_rd usa o novo buf_sel → lê banco correto.
            S_NEW_BEST_SCAN: begin
                begin : nbs
                    reg [FIT_BITS-1:0] f;
                    f = fit_cur_rd;  // fit[scan_idx] do novo banco atual
                    if (f < scan_best_fit) begin
                        scan_best_fit <= f;
                        scan_best_idx <= scan_idx[POP_BITS-1:0];
                    end
                end
                if (scan_idx == POP_SIZE - 1) begin
                    state <= S_SCAN_DONE;
                end else begin
                    scan_idx <= scan_idx + 1;
                end
            end

            // 1 ciclo: rd_addr=scan_best_idx → pop_rd captura pop[scan_best_idx].
            S_SCAN_DONE: begin
                state <= S_CHECK_STAG;
            end

            // pop_cur_rd = pop[scan_best_idx] (capturado em S_SCAN_DONE).
            S_CHECK_STAG: begin
                if (scan_best_fit < best_fit_reg) begin
                    best_fit_reg      <= scan_best_fit;
                    best_solution     <= pop_cur_rd;
                    best_fitness      <= scan_best_fit;
                    stagnate_cnt      <= 0;
                    partial_reset_cnt <= 0;
                end else begin
                    stagnate_cnt <= stagnate_cnt + 1;
                end

                if (scan_best_fit == 0) begin
                    best_solution <= pop_cur_rd;
                    best_fitness  <= 0;
                    running <= 0; done <= 1;
                    state <= S_DONE;
                end else if (stagnate_cnt + 1 >= STAG_LIMIT) begin
                    // Atribui init_idx diretamente para evitar bug de NBA com reset_start_idx.
                    stagnate_cnt <= 0;
                    if (partial_reset_cnt + 1 >= FULL_RESET) begin
                        partial_reset_cnt <= 0;
                        reset_start_idx   <= 0;
                        init_idx          <= 0;
                    end else begin
                        partial_reset_cnt <= partial_reset_cnt + 1;
                        reset_start_idx   <= ELITE;
                        init_idx          <= ELITE;
                    end
                    state <= S_PERM_LOAD;
                end else begin
                    state <= S_GEN_START;
                end
            end

            S_DONE: begin
                done <= 1; running <= 0;
            end

            default: state <= S_IDLE;

            endcase
        end
    end

endmodule  // n_queens_ga_core
