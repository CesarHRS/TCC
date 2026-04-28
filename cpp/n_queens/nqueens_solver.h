#ifndef NQUEENS_SOLVER_H
#define NQUEENS_SOLVER_H

#include "lfsr64.h"
#include <cstdint>

class NQueensSolver {
private:
    uint32_t n;              
    uint32_t* board;         
    uint32_t iterations;
    LFSR64 rng;

    uint32_t countConflicts(uint32_t col, uint32_t row) const {
        uint32_t conflicts = 0;

        for (uint32_t c = 0; c < n; c++) {
            if (c == col) continue; 

            uint32_t otherRow = board[c];

            if (otherRow == row) {
                conflicts++;
            } else if ((otherRow + c) == (row + col) || (otherRow - c) == (row - col)) {
                conflicts++;
            }
        }

        return conflicts;
    }

    void findMinConflictRows(uint32_t col, uint32_t* minRows, uint32_t& count) const {
        uint32_t minConflicts = n; // Maximum possible conflicts
        count = 0;

        // Find minimum conflicts
        for (uint32_t row = 0; row < n; row++) {
            uint32_t conflicts = countConflicts(col, row);
            if (conflicts < minConflicts) {
                minConflicts = conflicts;
                count = 1;
                minRows[0] = row;
            } else if (conflicts == minConflicts) {
                minRows[count++] = row;
            }
        }
    }

    // Count total conflicts in the current board configuration
    uint32_t countTotalConflicts() const {
        uint32_t total = 0;

        for (uint32_t col = 0; col < n; col++) {
            uint32_t row = board[col];

            // Check conflicts with all other columns
            for (uint32_t c = col + 1; c < n; c++) {
                uint32_t otherRow = board[c];

                // Check if queens are on same row
                if (otherRow == row) {
                    total++;
                }
                // Check if queens are on same diagonals
                else if ((otherRow + c) == (row + col) || (otherRow - c) == (row - col)) {
                    total++;
                }
            }
        }

        return total;
    }

    // Find columns with maximum number of conflicts
    uint32_t findMostConflictedColumn() {
        uint32_t maxConflicts = 0;
        uint32_t conflictCols[256];
        uint32_t count = 0;

        // Find all columns and their conflict counts
        for (uint32_t col = 0; col < n; col++) {
            uint32_t row = board[col];
            uint32_t conflicts = countConflicts(col, row);
            
            if (conflicts > maxConflicts) {
                maxConflicts = conflicts;
                count = 1;
                conflictCols[0] = col;
            } else if (conflicts > 0 && conflicts == maxConflicts) {
                conflictCols[count++] = col;
            }
        }

        if (count == 0) {
            return n; // No conflicts found
        }

        // Use LFSR to randomly select among most-conflicted columns (tie-breaking)
        if (count == 1) {
            return conflictCols[0];
        } else {
            uint32_t idx = rng.nextRange(count);
            return conflictCols[idx];
        }
    }

public:
    NQueensSolver(uint32_t boardSize, uint64_t seed = 0x123456789ABCDEFULL)
        : n(boardSize), iterations(0), rng(seed) {
        board = new uint32_t[n];
    }

    ~NQueensSolver() {
        delete[] board;
    }

    // Initialize board with random placement (one queen per column)
    void initializeRandom() {
        for (uint32_t col = 0; col < n; col++) {
            board[col] = rng.nextRange(n);
        }
    }

    // Solve using Min-Conflicts algorithm with random walk and restart
    bool solve(uint32_t maxIterations = 1000000) {
        const uint32_t MAX_RESTARTS = 10;
        
        for (uint32_t restart = 0; restart < MAX_RESTARTS; restart++) {
            // Reinitialize with new seed each restart
            if (restart > 0) {
                rng.setState(rng.getState() * 6364136223846793005ULL + 1442695040888963407ULL);
                for (uint32_t col = 0; col < n; col++) {
                    board[col] = rng.nextRange(n);
                }
            }

            iterations = 0;
            uint32_t noImprovementCount = 0;
            uint32_t previousConflictCount = countTotalConflicts();
            uint32_t walkSteps = 0;
            const uint32_t MAX_NO_IMPROVE = 500;
            const uint32_t ITER_PER_RESTART = maxIterations / MAX_RESTARTS;

            while (iterations < ITER_PER_RESTART) {
                // Find column with most conflicts
                uint32_t conflictCol = findMostConflictedColumn();

                if (conflictCol == n) {
                    // No conflicts found - solution is complete
                    return true;
                }

                // Determine if we should do a random walk
                uint32_t currentConflictCount = countTotalConflicts();
                if (currentConflictCount >= previousConflictCount) {
                    noImprovementCount++;
                } else {
                    noImprovementCount = 0;
                }
                previousConflictCount = currentConflictCount;

                // Random walk to escape local optima
                if (noImprovementCount > MAX_NO_IMPROVE && walkSteps < 100) {
                    uint32_t randomCol = rng.nextRange(n);
                    uint32_t randomRow = rng.nextRange(n);
                    board[randomCol] = randomRow;
                    walkSteps++;
                } else {
                    walkSteps = 0;
                    
                    // Min-Conflicts move
                    uint32_t minRows[256];
                    uint32_t count = 0;
                    findMinConflictRows(conflictCol, minRows, count);

                    uint32_t selectedRow;
                    if (count == 1) {
                        selectedRow = minRows[0];
                    } else {
                        uint32_t idx = rng.nextRange(count);
                        selectedRow = minRows[idx];
                    }

                    board[conflictCol] = selectedRow;
                }

                iterations++;
            }
        }

        return false; // Max iterations reached
    }

    uint32_t getIterations() const {
        return iterations;
    }

    const uint32_t* getBoard() const {
        return board;
    }

    uint32_t getBoardSize() const {
        return n;
    }


};

#endif // NQUEENS_SOLVER_H
