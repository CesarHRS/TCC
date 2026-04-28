#include <chrono>
#include <iostream>
#include <cstdint>
#include "lfsr64.h"
#include "nqueens_solver.h"

// Default board size if not provided by compiler
#ifndef N
    #define N 8
#endif

int main() {
    const uint32_t RUNS = 10;
    const uint64_t baseSeed = 0x123456789ABCDEFULL;
    uint64_t totalTimeNs = 0;
    bool allFound = true;

    std::cout << "N-Queens Min-Conflicts benchmark (N=" << N << ", runs=" << RUNS << ")\n";

    for (uint32_t run = 0; run < RUNS; ++run) {
        NQueensSolver solver(N, baseSeed + run);
        solver.initializeRandom();

        auto start = std::chrono::high_resolution_clock::now();
        bool found = solver.solve(10000000); // 10 million max iterations
        auto end = std::chrono::high_resolution_clock::now();

        auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
        totalTimeNs += duration;
        allFound &= found;

        std::cout << "Run " << (run + 1) << ": " << duration << " ns";
        if (!found) {
            std::cout << " (solution not found)";
        }
        std::cout << "\n";
    }

    uint64_t averageTimeNs = totalTimeNs / RUNS;

    std::cout << "Average time: " << averageTimeNs << " ns\n";
    std::cout << "Overall result: " << (allFound ? "YES" : "NO (some runs failed)") << "\n";

    return allFound ? 0 : 1;
}
