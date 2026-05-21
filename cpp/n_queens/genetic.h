#pragma once

#include "lfsr64.h"
#include "nqueens.h"

#include <vector>

Chrom crossover(const Chrom& p1, const Chrom& p2, LFSR64& rng);
void  mutate(Chrom& c, LFSR64& rng);
int   tournament(const std::vector<int>& fits, LFSR64& rng);
Chrom rand_perm(LFSR64& rng);

// Executa o algoritmo genético. Retorna a solução ou Chrom vazio se MAX_GENS
// se esgotarem sem convergência.
Chrom solve(LFSR64& rng);
