#include <bitset>
#include <chrono>
#include <iostream>
#include <random>
#include <string>

#ifndef BITS
#define BITS 1024
#endif

static constexpr size_t N_BITS = BITS;

#include <vector>

using chunk_t = uint64_t;
static constexpr size_t CHUNK_BITS = sizeof(chunk_t) * 8;

struct DynBits {
    std::vector<chunk_t> data;
    DynBits(size_t nbits = N_BITS) : data((nbits + CHUNK_BITS - 1) / CHUNK_BITS) {}
    void set_bit(size_t i, bool v) {
        size_t idx = i / CHUNK_BITS;
        size_t off = i % CHUNK_BITS;
        if (v) data[idx] |= (chunk_t(1) << off);
        else data[idx] &= ~(chunk_t(1) << off);
    }
    void flip(size_t i) {
        size_t idx = i / CHUNK_BITS;
        size_t off = i % CHUNK_BITS;
        data[idx] ^= (chunk_t(1) << off);
    }
    bool test(size_t i) const {
        size_t idx = i / CHUNK_BITS;
        size_t off = i % CHUNK_BITS;
        return (data[idx] >> off) & 1u;
    }
    size_t count() const {
        size_t s = 0;
        for (chunk_t v : data) s += __builtin_popcountll(v);
        return s;
    }
    std::string to_string(size_t nbits = N_BITS) const {
        std::string out;
        out.reserve(nbits);
        for (size_t i = 0; i < nbits; ++i) out.push_back(test(i) ? '1' : '0');
        return out;
    }
};

size_t calculate_fitness(const DynBits &v) {
    return v.count();
}

int main(int argc, char **argv) {
    //std::cout << "Iniciando simulação..." << std::endl;

    std::random_device rd;
    std::mt19937_64 rng(rd());
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

    //std::cout << "Iniciando busca..." << std::endl;

    auto start_time = std::chrono::high_resolution_clock::now();
    uint64_t iterations = 0;

    while (best_fitness < N_BITS) {
        ++iterations;
    size_t idx = bit_dist(rng);

    DynBits neighbor = current_solution;
    neighbor.flip(idx);
    size_t neighbor_fitness = calculate_fitness(neighbor);

        if (neighbor_fitness >= current_fitness) {
            current_solution = neighbor;
            current_fitness = neighbor_fitness;
        }

        if (current_fitness > best_fitness) {
            best_solution = current_solution;
            best_fitness = current_fitness;
        }
    }

    auto end_time = std::chrono::high_resolution_clock::now();
std::chrono::duration<double, std::milli> elapsed = end_time - start_time;
    //std::cout << "Solução ótima encontrada: " << best_solution.to_string(N_BITS) << std::endl;
    //std::cout << "Aptidão final: " << best_fitness << std::endl;
    //std::cout << "Iterações: " << iterations << std::endl;
    std::cout << "Tempo (s): " << elapsed.count() << std::endl;

    return 0;
}
