#include "hill_climbing.h"
#include <vector>

class LFSR {
    uint64_t reg;
public:
    LFSR(uint64_t seed) : reg(seed) {}
    uint64_t next() {
        uint64_t bit = ((reg >> 63) & 1) ^ ((reg >> 62) & 1) ^ ((reg >> 60) & 1) ^ ((reg >> 59) & 1);
        reg = (reg << 1) | bit;
        return reg;
    }
};

size_t calculate_fitness(const DynBits &v) {
    return v.count();
}

DynBits run_hill_climbing() {
    LFSR lfsr(0xDEADBEEFCAFEBABEULL);

    DynBits current_solution(N_BITS); // starts with all zeros
    size_t current_fitness = 0;

    while (current_fitness < N_BITS) {
        size_t idx = lfsr.next() & 0x3FF;
        
        if (!current_solution.test(idx)) {
            current_solution.flip(idx);
            current_fitness++;
        }
    }

    return current_solution;
}