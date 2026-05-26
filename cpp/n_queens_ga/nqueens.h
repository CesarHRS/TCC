#pragma once

#include <vector>

using Chrom = std::vector<int>;

// Returns number of diagonally attacking queen pairs (0 = valid solution)
int fitness(const Chrom& c);
