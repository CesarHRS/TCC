#pragma once

#ifndef N
#define N 8
#endif

static constexpr int BOARD_SIZE  = N;
static constexpr int POP_SIZE    = 300;
static constexpr int MAX_GENS    = 500000;
// Mutação: probabilidade ≈ MUT_THRESH / 2^MUT_BITS = 10/128 ≈ 7,8%
// Equivalente hardware: if (lfsr[MUT_BITS-1:0] < MUT_THRESH)
static constexpr int MUT_THRESH  = 10;
static constexpr int MUT_BITS    = 7;
static constexpr int TOURN_SIZE  = 4;
static constexpr int ELITE       = 30;
static constexpr int STAG_LIMIT  = 150;
static constexpr int FULL_RESET  = 8;
