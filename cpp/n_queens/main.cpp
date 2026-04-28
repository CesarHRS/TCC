#include <iostream>
#include <cstdint>
#include "lfsr64.h"
#include "nqueens_solver.h"

// Default board size if not provided by compiler
#ifndef N
    #define N 8
#endif

int main() {
    // Create solver with board size N
    NQueensSolver solver(N, 0x123456789ABCDEFULL);

    // Initialize board with random placement
    solver.initializeRandom();

    // Solve using Min-Conflicts algorithm
    bool found = solver.solve(10000000); // 10 million max iterations

    // Display results
    std::cout << "\n========== N-Queens Min-Conflicts Solution ==========\n";
    std::cout << "Board Size (N): " << N << "\n";
    std::cout << "Iterations: " << solver.getIterations() << "\n";

    // Verify solution and count conflicts
    const uint32_t* board = solver.getBoard();
    uint32_t totalConflicts = 0;

    // Count diagonal and row conflicts
    for (uint32_t col = 0; col < N; col++) {
        for (uint32_t c = col + 1; c < N; c++) {
            uint32_t row1 = board[col];
            uint32_t row2 = board[c];

            // Same row
            if (row1 == row2) {
                totalConflicts++;
            }
            // Same diagonal
            else if ((row1 + col) == (row2 + c) || (row1 - col) == (row2 - c)) {
                totalConflicts++;
            }
        }
    }

    std::cout << "Total Conflicts: " << totalConflicts << "\n";
    std::cout << "Solution Found: " << (found ? "YES" : "NO (max iterations exceeded)") << "\n";

    // Display board configuration
    std::cout << "\nBoard Configuration:\n";
    for (uint32_t row = 0; row < N; row++) {
        for (uint32_t col = 0; col < N; col++) {
            if (board[col] == row) {
                std::cout << "Q ";
            } else {
                std::cout << ". ";
            }
        }
        std::cout << "\n";
    }

    // Display queen positions
    std::cout << "\nQueen Positions (column -> row):\n";
    for (uint32_t col = 0; col < N; col++) {
        std::cout << "Col " << col << " -> Row " << board[col] << "\n";
    }

    std::cout << "===================================================\n";

    return found ? 0 : 1;
}
