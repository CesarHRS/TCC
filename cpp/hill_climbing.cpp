#include "hill_climbing.h"
#include <random>
#include <vector>

size_t calculate_fitness(const DynBits &v) {
    return v.count();
}

DynBits run_hill_climbing(size_t seed) {
    std::mt19937_64 rng(seed);
    std::uniform_int_distribution<size_t> bit_dist(0, N_BITS - 1);

    DynBits current_solution(N_BITS);
    size_t i = 0;
    while (i < N_BITS) {
        uint64_t r = rng();
        for (size_t b = 0; b < CHUNK_BITS && i < N_BITS; ++b, ++i) {
            current_solution.set_bit(i, (r >> b) & 1u);
        }
    }

    DynBits best_solution = current_solution;
    size_t current_fitness = calculate_fitness(current_solution);
    size_t best_fitness = current_fitness;

    while (best_fitness < N_BITS) {
        const size_t num_neighbors = 32;
        std::vector<size_t> neighbor_fitnesses(num_neighbors);
        std::vector<size_t> neighbor_indices(num_neighbors);

        for (size_t n = 0; n < num_neighbors; ++n) {
            size_t idx = bit_dist(rng);
            neighbor_indices[n] = idx;
            current_solution.flip(idx);
            neighbor_fitnesses[n] = calculate_fitness(current_solution);
            current_solution.flip(idx);  // flip back
        }

        // Find the best neighbor
        size_t best_neighbor_idx = 0;
        size_t best_neighbor_fitness = neighbor_fitnesses[0];
        for (size_t n = 1; n < num_neighbors; ++n) {
            if (neighbor_fitnesses[n] > best_neighbor_fitness) {
                best_neighbor_fitness = neighbor_fitnesses[n];
                best_neighbor_idx = n;
            }
        }

        if (best_neighbor_fitness >= current_fitness) {
            current_solution.flip(neighbor_indices[best_neighbor_idx]);
            current_fitness = best_neighbor_fitness;
        }

        if (current_fitness > best_fitness) {
            best_solution = current_solution;
            best_fitness = current_fitness;
        }
    }

    return best_solution;
}