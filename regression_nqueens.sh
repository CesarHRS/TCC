#!/usr/bin/env bash
# Regressão N-Queens (C++): compila e roda N=1..15, 10 runs cada.
# Saída: build/regression_nqueens.log

set -euo pipefail

RUNS=10
N_MIN=4
N_MAX=15
BUILD=build
SRC="cpp/n_queens/main.cpp cpp/n_queens/nqueens.cpp cpp/n_queens/genetic.cpp"
CXX=${CXX:-g++}
CXXFLAGS="-O3 -std=c++17 -march=native -Wall -Wextra -pipe"
LOG="$BUILD/regression_nqueens.log"

mkdir -p "$BUILD"

{
printf "=========================================\n"
printf " Regressão N-Queens GA (C++)\n"
printf " N=%d..%d | %d runs por tamanho\n" "$N_MIN" "$N_MAX" "$RUNS"
printf " Data: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf "=========================================\n\n"

printf "%-4s  %-8s  %12s  %12s  %12s  %12s  %s\n" \
       "N" "Status" "Min (µs)" "Max (µs)" "Média (µs)" "Total (µs)" "Solução (run 1)"

for N in $(seq "$N_MIN" "$N_MAX"); do
    BIN="$BUILD/nqueens_reg_${N}"

    # ── Compilação ──────────────────────────────────────────────────
    if ! $CXX $CXXFLAGS -DN="$N" -o "$BIN" $SRC 2>/tmp/cxx_err_$N; then
        printf "%-4d  %-8s  (erro de compilação)\n" "$N" "ERRO"
        cat /tmp/cxx_err_$N
        continue
    fi

    # ── Execuções ───────────────────────────────────────────────────
    min_us=9999999999
    max_us=0
    sum_us=0
    first_sol=""
    status="OK"

    for run in $(seq 1 "$RUNS"); do
        output=$("$BIN" 2>/dev/null)
        us=$(echo "$output" | awk '/Tempo/ { for(i=1;i<=NF;i++) if($i=="=") { print $(i+1); exit } }')
        sol=$(echo "$output" | awk '/Solução/ { $1=$2=""; sub(/^ +/,""); print; exit }')

        if [ -z "$us" ]; then
            status="SEM_SOL"
            us=0
        fi

        if [ "$run" -eq 1 ]; then
            first_sol="${sol:-sem solução}"
        fi

        (( us < min_us )) && min_us=$us
        (( us > max_us )) && max_us=$us
        sum_us=$(( sum_us + us ))
    done

    avg_us=$(( sum_us / RUNS ))

    printf "%-4d  %-8s  %12d  %12d  %12d  %12d  %s\n" \
           "$N" "$status" "$min_us" "$max_us" "$avg_us" "$sum_us" "$first_sol"
done

printf "\n=========================================\n"
printf " Log gerado em: %s\n" "$LOG"
printf "=========================================\n"

} 2>&1 | tee "$LOG"
