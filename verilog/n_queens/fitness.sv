// Fitness para o problema das N rainhas com codificação por permutação.
// Conta pares (i, j) com i < j tais que |c[i] - c[j]| == j - i (conflitos diagonais).
//
// Equivalente direto a:
//   for (i=0; i<N; i++)
//     for (j=i+1; j<N; j++)
//       if (|c[i]-c[j]| == j-i) ++conf;
//
// Implementação puramente combinacional: N*(N-1)/2 comparadores em paralelo.
// Para N pequeno (≤ 16) o custo em LEs é baixo.

module fitness #(
    parameter int N         = 8,
    parameter int GENE_BITS = 3,     // = $clog2(N)
    parameter int FIT_BITS  = 12     // suficiente para C(64,2) = 2016
)(
    input  wire [N*GENE_BITS-1:0] chrom_flat,
    output wire [FIT_BITS-1:0]    conflicts
);

    // Reorganiza o vetor plano em array de genes.
    wire [GENE_BITS-1:0] gene [0:N-1];
    genvar gi;
    generate
        for (gi = 0; gi < N; gi = gi + 1) begin : g_unpack
            assign gene[gi] = chrom_flat[gi*GENE_BITS +: GENE_BITS];
        end
    endgenerate

    // Soma de todos os pares com colisão diagonal.
    integer i, j, diff_rc;
    reg signed [GENE_BITS+1:0] diff;
    reg [FIT_BITS-1:0] acc;

    always @* begin
        acc = {FIT_BITS{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            for (j = i + 1; j < N; j = j + 1) begin
                diff    = $signed({2'b00, gene[i]}) - $signed({2'b00, gene[j]});
                diff_rc = (diff < 0) ? -diff : diff;
                if (diff_rc == (j - i))
                    acc = acc + 1'b1;
            end
        end
    end

    assign conflicts = acc;

endmodule
