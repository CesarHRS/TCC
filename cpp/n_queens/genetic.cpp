#include "genetic.h"
#include "config.h"
#include "nqueens.h"

#include <cstdint>
#include <vector>

// Fisher-Yates explícito com LFSR.
// Hardware: loop de N-1 ciclos, índice j = lfsr % (i+1) a cada passo.
Chrom rand_perm(LFSR64& rng) {
    Chrom c(BOARD_SIZE);
    for (int i = 0; i < BOARD_SIZE; ++i) c[i] = i;
    for (int i = BOARD_SIZE - 1; i > 0; --i) {
        int j = (int)rng.range((uint64_t)i + 1);
        int tmp = c[i]; c[i] = c[j]; c[j] = tmp;
    }
    return c;
}

// OX1 com bitmask uint64_t em vez de vector<bool>.
// Hardware: registrador de N bits; cada bit indica se o gene já foi colocado.
// Funciona para BOARD_SIZE ≤ 64.
Chrom crossover(const Chrom& p1, const Chrom& p2, LFSR64& rng) {
    int a = (int)rng.range(BOARD_SIZE);
    int b = (int)rng.range(BOARD_SIZE);
    if (a > b) { int t = a; a = b; b = t; }

    Chrom child(BOARD_SIZE, -1);
    uint64_t used = 0;

    // Fase 1: copia segmento [a, b] de p1.
    for (int i = a; i <= b; ++i) {
        child[i] = p1[i];
        used |= (1ULL << p1[i]);
    }

    // Fase 2: preenche posições restantes em ordem circular a partir de p2.
    int pos = (b + 1) % BOARD_SIZE;
    for (int i = 0; i < BOARD_SIZE; ++i) {
        int idx  = (b + 1 + i) % BOARD_SIZE;
        int gene = p2[idx];
        if (!(used & (1ULL << gene))) {
            child[pos] = gene;
            used |= (1ULL << gene);
            pos = (pos + 1) % BOARD_SIZE;
        }
    }
    return child;
}

// Swap de dois índices aleatórios — um ciclo de clock no hardware.
void mutate(Chrom& c, LFSR64& rng) {
    int a = (int)rng.range(BOARD_SIZE);
    int b = (int)rng.range(BOARD_SIZE);
    int tmp = c[a]; c[a] = c[b]; c[b] = tmp;
}

// Torneio: TOURN_SIZE candidatos aleatórios, retorna o de menor fitness.
// Hardware: TOURN_SIZE leituras sequenciais da população com índice do LFSR.
int tournament(const std::vector<int>& fits, LFSR64& rng) {
    int best = (int)rng.range(POP_SIZE);
    for (int i = 1; i < TOURN_SIZE; ++i) {
        int idx = (int)rng.range(POP_SIZE);
        if (fits[idx] < fits[best]) best = idx;
    }
    return best;
}

Chrom solve(LFSR64& rng) {
    std::vector<Chrom> pop(POP_SIZE);
    std::vector<int>   fits(POP_SIZE);
    for (int i = 0; i < POP_SIZE; ++i) {
        pop[i]  = rand_perm(rng);
        fits[i] = fitness(pop[i]);
    }

    // Busca linear do melhor — hardware: varredura sequencial da população.
    int best_fit = fits[0];
    for (int i = 1; i < POP_SIZE; ++i)
        if (fits[i] < best_fit) best_fit = fits[i];

    int stagnate      = 0;
    int partial_resets = 0;

    for (int gen = 0; gen < MAX_GENS && best_fit > 0; ++gen) {
        std::vector<Chrom> next(POP_SIZE);
        std::vector<int>   nfits(POP_SIZE);

        // Elitismo: ELITE varreduras lineares para encontrar os mínimos.
        // Hardware: ELITE × POP_SIZE ciclos de comparação, sem sort.
        std::vector<bool> selected(POP_SIZE, false);
        for (int e = 0; e < ELITE; ++e) {
            int best_idx = -1;
            for (int i = 0; i < POP_SIZE; ++i) {
                if (!selected[i] && (best_idx < 0 || fits[i] < fits[best_idx]))
                    best_idx = i;
            }
            selected[best_idx] = true;
            next[e]  = pop[best_idx];
            nfits[e] = fits[best_idx];
        }

        // Geração dos filhos via torneio + OX1 + mutação.
        for (int i = ELITE; i < POP_SIZE; ++i) {
            next[i]  = crossover(pop[tournament(fits, rng)],
                                 pop[tournament(fits, rng)], rng);
            // Probabilidade inteira: MUT_THRESH / 2^MUT_BITS ≈ 8%.
            // Hardware: if (lfsr[MUT_BITS-1:0] < MUT_THRESH).
            if ((rng.next() & ((1ULL << MUT_BITS) - 1)) < (uint64_t)MUT_THRESH)
                mutate(next[i], rng);
            nfits[i] = fitness(next[i]);
        }

        // Troca explícita — hardware: double-buffer com bit de seleção.
        for (int i = 0; i < POP_SIZE; ++i) {
            pop[i]  = next[i];
            fits[i] = nfits[i];
        }

        // Busca linear do novo melhor.
        int new_best = fits[0];
        for (int i = 1; i < POP_SIZE; ++i)
            if (fits[i] < new_best) new_best = fits[i];

        if (new_best < best_fit) { best_fit = new_best; stagnate = 0; partial_resets = 0; }
        else ++stagnate;

        if (stagnate >= STAG_LIMIT) {
            stagnate = 0;
            ++partial_resets;

            if (partial_resets >= FULL_RESET) {
                partial_resets = 0;
                for (int i = 0; i < POP_SIZE; ++i) {
                    pop[i]  = rand_perm(rng);
                    fits[i] = fitness(pop[i]);
                }
            } else {
                for (int i = ELITE; i < POP_SIZE; ++i) {
                    pop[i]  = rand_perm(rng);
                    fits[i] = fitness(pop[i]);
                }
            }

            best_fit = fits[0];
            for (int i = 1; i < POP_SIZE; ++i)
                if (fits[i] < best_fit) best_fit = fits[i];
        }
    }

    if (best_fit > 0) return {};

    for (int i = 0; i < POP_SIZE; ++i)
        if (fits[i] == 0) return pop[i];
    return {};
}
