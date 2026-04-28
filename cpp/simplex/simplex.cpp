#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>

#ifndef SIMPLEX_M
#define SIMPLEX_M 3
#endif

#ifndef SIMPLEX_N
#define SIMPLEX_N 2
#endif

static_assert(SIMPLEX_M > 0, "SIMPLEX_M must be > 0");
static_assert(SIMPLEX_N > 0, "SIMPLEX_N must be > 0");

constexpr int M = SIMPLEX_M;
constexpr int N = SIMPLEX_N;
constexpr int TAB_ROWS = M + 1;
constexpr int TAB_COLS = N + M + 1;

using Table = std::array<std::array<double, TAB_COLS>, TAB_ROWS>;

void print_tableau(const Table &tab) {
    std::cout << "Tableau:\n";
    for (int i = 0; i < TAB_ROWS; ++i) {
        for (int j = 0; j < TAB_COLS; ++j) {
            std::cout << std::setw(8) << std::setprecision(4) << tab[i][j] << " ";
        }
        std::cout << '\n';
    }
}

bool pivot(Table &tab, std::array<int, M> &basis) {
    int entering = -1;
    double best_coef = 0.0;

    for (int j = 0; j < N + M; ++j) {
        double coef = tab[TAB_ROWS - 1][j];
        // In the canonical maximization tableau with objective row as -(c),
        // choose the most negative reduced cost to improve objective.
        if (coef < best_coef) {
            best_coef = coef;
            entering = j;
        }
    }

    if (entering == -1) {
        return false; 
    }

    int leaving = -1;
    double min_ratio = std::numeric_limits<double>::infinity();

    for (int i = 0; i < M; ++i) {
        double col_val = tab[i][entering];
        if (col_val > 1e-12) {
            double ratio = tab[i][TAB_COLS - 1] / col_val;
            if (ratio < min_ratio - 1e-12) {
                min_ratio = ratio;
                leaving = i;
            }
        }
    }

    if (leaving == -1) {
        throw std::runtime_error("Problema não limitado ");
    }

    double pivot_val = tab[leaving][entering];
    for (int j = 0; j < TAB_COLS; ++j) {
        tab[leaving][j] /= pivot_val;
    }

    for (int i = 0; i < TAB_ROWS; ++i) {
        if (i == leaving) continue;
        double factor = tab[i][entering];
        for (int j = 0; j < TAB_COLS; ++j) {
            tab[i][j] -= factor * tab[leaving][j];
        }
    }

    basis[leaving] = entering;
    return true;
}

bool simplex_solve(const std::array<std::array<double, N>, M> &A, const std::array<double, M> &b,
                   const std::array<double, N> &c, std::array<double, N> &x, double &objective) {
                    
    Table tab{};
    std::array<int, M> basis{};

    for (int i = 0; i < M; ++i) {
        for (int j = 0; j < N; ++j) {
            tab[i][j] = A[i][j];
        }
    }

    for (int i = 0; i < M; ++i) {
        tab[i][N + i] = 1.0;
        tab[i][TAB_COLS - 1] = b[i];
        basis[i] = N + i;
    }

    for (int j = 0; j < N; ++j) {
        tab[TAB_ROWS - 1][j] = -c[j];
    }

    tab[TAB_ROWS - 1][TAB_COLS - 1] = 0.0;

    for (int iter = 0; iter < 1000; ++iter) {
        bool continued = pivot(tab, basis);
        if (!continued) break;
    }

    for (int i = 0; i < M; ++i) {
        int var = basis[i];
        if (var < N) {
            x[var] = tab[i][TAB_COLS - 1];
        }
    }
    for (int j = 0; j < N; ++j) {
        if (std::none_of(basis.begin(), basis.end(), [&](int bvar) { return bvar == j; })) {
            x[j] = 0.0;
        }
    }

    objective = tab[TAB_ROWS - 1][TAB_COLS - 1];

    return true;
}

int main() {
    std::cout << "Simplex solver (M=" << M << ", N=" << N << ")\n";

    std::array<std::array<double, N>, M> A;
    std::array<double, M> b;
    std::array<double, N> c;

    if constexpr (M == 3 && N == 2) {
        A = {{{2, 1}, {2, 3}, {3, 1}}};
        b = {18, 42, 24};
        c = {3, 2};
    } else if constexpr (M == 2 && N == 2) {
        A = {{{1, 1}, {3, 1}}};
        b = {4, 6};
        c = {1, 2};
    } else {
        std::cout << "Entrada padrão não configurada para M=" << M << " N=" << N << ".\n";
        return 1;
    }

    std::array<double, N> x;
    x.fill(0.0);
    double objective = 0.0;

    auto t0 = std::chrono::high_resolution_clock::now();
    try {
        simplex_solve(A, b, c, x, objective);
    } catch (const std::exception &e) {
        std::cerr << "Erro: " << e.what() << "\n";
        return 1;
    }
    auto t1 = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double, std::micro> elapsed = t1 - t0;

    std::cout << "Solução ótima:\n";
    for (int j = 0; j < N; ++j) {
        std::cout << " x" << j + 1 << " = " << x[j] << "\n";
    }
    std::cout << "Valor objetivo = " << objective << "\n";
    std::cout << "Tempo de execução = " << elapsed.count() << " µs\n";

    return 0;
}
