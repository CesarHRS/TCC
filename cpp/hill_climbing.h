#ifndef HILL_CLIMBING_H
#define HILL_CLIMBING_H

#include "dynbits.h"

size_t calculate_fitness(const DynBits &v);
DynBits run_hill_climbing(size_t seed);

#endif // HILL_CLIMBING_H