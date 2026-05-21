#include "nqueens.h"
#include "config.h"

#include <cstdlib>

int fitness(const Chrom& c) {
    int conf = 0;
    for (int i = 0; i < BOARD_SIZE; ++i)
        for (int j = i + 1; j < BOARD_SIZE; ++j)
            if (std::abs(c[i] - c[j]) == j - i)
                ++conf;
    return conf;
}
