#!/usr/bin/env python3
"""
1. Plota a média das seeds da FPGA como uma única linha.
2. Compara essa média com a regressão C++ (média de 10 runs).

Usage:
    python3 scripts/plot_fpga_avg_vs_cpp.py \
        results/n_queens_fpga.txt \
        build/regression_nqueens.log
"""

import re
import sys
import os
from collections import defaultdict
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ---------------------------------------------------------------------------
# 1. Parser FPGA — todas as seeds
# ---------------------------------------------------------------------------

def parse_fpga(path):
    """Retorna dict {N: [t1, t2, ...]} com os tempos de todas as seeds."""
    times_by_n = defaultdict(list)
    current_active = False

    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if re.match(r'^seed\s+', line, re.IGNORECASE):
                current_active = True
                continue
            if not current_active:
                continue
            m = re.match(r'^(\d+)\s+(\d+)$', line)
            if m:
                times_by_n[int(m.group(1))].append(int(m.group(2)))

    return times_by_n


def compute_average(times_by_n):
    """Retorna listas (ns, avg) ordenadas por N."""
    ns   = sorted(times_by_n)
    avgs = [sum(times_by_n[n]) / len(times_by_n[n]) for n in ns]
    return ns, avgs


# ---------------------------------------------------------------------------
# 2. Parser C++ regression
# ---------------------------------------------------------------------------

def parse_regression(path):
    """Extrai N e Média (µs) do log de regressão."""
    ns, means = [], []
    pattern = re.compile(
        r'^\s*(\d+)\s+OK\s+\d+\s+\d+\s+(\d+)'
    )
    with open(path) as f:
        for line in f:
            m = pattern.match(line)
            if m:
                ns.append(int(m.group(1)))
                means.append(int(m.group(2)))
    return ns, means


# ---------------------------------------------------------------------------
# 3. Plot: média FPGA (linha única)
# ---------------------------------------------------------------------------

def plot_fpga_avg(ns, avgs, out_path):
    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(
        ns, avgs,
        color="#2ca02c",
        linewidth=2.5,
        marker="o",
        markersize=6,
        label="Média FPGA (4 seeds)",
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title(
        "N-Queens – FPGA\nMédia do tempo de execução (todas as seeds)",
        fontsize=14,
    )
    ax.set_xticks(ns)
    ax.tick_params(axis="x", rotation=45)
    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(
        ticker.FuncFormatter(lambda x, _: f"{x:,.0f}")
    )
    ax.legend(fontsize=11)
    ax.grid(True, which="both", linestyle="--", linewidth=0.5, alpha=0.5)
    fig.tight_layout()

    fig.savefig(out_path, dpi=150)
    print(f"Salvo: {out_path}")
    plt.close(fig)


# ---------------------------------------------------------------------------
# 4. Plot: FPGA média vs C++ regressão
# ---------------------------------------------------------------------------

def plot_comparison(fpga_ns, fpga_avgs, cpp_ns, cpp_means, out_path):
    # Só compara N presentes nos dois conjuntos
    common = sorted(set(fpga_ns) & set(cpp_ns))
    fpga_map = dict(zip(fpga_ns, fpga_avgs))
    cpp_map  = dict(zip(cpp_ns,  cpp_means))

    f_vals = [fpga_map[n] for n in common]
    c_vals = [cpp_map[n]  for n in common]

    fig, ax = plt.subplots(figsize=(13, 7))

    ax.plot(
        common, f_vals,
        color="#2ca02c",
        linewidth=2.5,
        marker="o",
        markersize=6,
        label="FPGA – média das seeds (µs)",
    )
    ax.plot(
        common, c_vals,
        color="#d62728",
        linewidth=2.5,
        marker="s",
        markersize=6,
        linestyle="--",
        label="C++ – média de 10 runs (µs)",
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title(
        "N-Queens – FPGA vs C++\nMédia do tempo de execução por tamanho do problema",
        fontsize=14,
    )
    ax.set_xticks(common)
    ax.tick_params(axis="x", rotation=45)
    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(
        ticker.FuncFormatter(lambda x, _: f"{x:,.0f}")
    )
    ax.legend(fontsize=11)
    ax.grid(True, which="both", linestyle="--", linewidth=0.5, alpha=0.5)
    fig.tight_layout()

    fig.savefig(out_path, dpi=150)
    print(f"Salvo: {out_path}")
    plt.close(fig)


# ---------------------------------------------------------------------------
# 5. Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Uso: python3 scripts/plot_fpga_avg_vs_cpp.py "
            "<fpga.txt> <regression.log>",
            file=sys.stderr,
        )
        sys.exit(1)

    fpga_path = sys.argv[1]
    reg_path  = sys.argv[2]
    out_dir   = os.path.dirname(os.path.abspath(fpga_path))

    # FPGA
    times_by_n      = parse_fpga(fpga_path)
    fpga_ns, fpga_avgs = compute_average(times_by_n)
    print(f"FPGA: N={fpga_ns}, seeds por N={[len(times_by_n[n]) for n in fpga_ns]}")

    # C++
    cpp_ns, cpp_means = parse_regression(reg_path)
    print(f"C++:  N={cpp_ns}")

    # Gráfico 1 — média FPGA isolada
    plot_fpga_avg(
        fpga_ns, fpga_avgs,
        os.path.join(out_dir, "n_queens_fpga_avg_plot.png"),
    )

    # Gráfico 2 — comparação
    plot_comparison(
        fpga_ns, fpga_avgs,
        cpp_ns,  cpp_means,
        os.path.join(out_dir, "n_queens_fpga_vs_cpp_plot.png"),
    )
