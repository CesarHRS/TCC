#include "genetic.h"
#include "config.h"
#include "lfsr64.h"

#include <iostream>
#include <chrono>

int main() {
    // Semente fixa para reprodutibilidade e equivalência com o hardware.
    // O hardware inicializa o LFSR com o mesmo valor em reset.
    LFSR64 rng(0xDEADBEEFCAFEBABEULL);

    auto t0  = std::chrono::high_resolution_clock::now();
    Chrom sol = solve(rng);
    auto t1  = std::chrono::high_resolution_clock::now();

    long long us = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();

    if (!sol.empty()) {
        std::cout << "Solução N=" << BOARD_SIZE << ":";
        for (int col = 0; col < BOARD_SIZE; ++col)
            std::cout << " " << sol[col];
        std::cout << "\n";
    } else {
        std::cout << "Sem solução\n";
    }

    std::cout << "Tempo = " << us << " µs\n";
    return 0;
}
