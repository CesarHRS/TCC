#pragma once
#include <cstdint>

// LFSR de 64 bits com polinômio x^64 + x^63 + x^61 + x^60 + 1
// Taps nos bits 63, 62, 60, 59 — idêntico ao hardware (verilog/n_queens_ga/lfsr64.sv).
// Shift para a esquerda: novo bit entra no LSB.
class LFSR64 {
    uint64_t st;
public:
    explicit LFSR64(uint64_t seed = 0xDEADBEEFCAFEBABEULL) : st(seed) {}

    uint64_t next() {
        uint64_t bit = ((st >> 63) ^ (st >> 62) ^ (st >> 60) ^ (st >> 59)) & 1ULL;
        st = (st << 1) | bit;
        return st;
    }

    // Retorna valor em [0, n). Equivalente a mascarar bits no hardware.
    uint64_t range(uint64_t n) { return next() % n; }
};
