#!/usr/bin/env python3
"""
Plot N-Queens FPGA results.

Usage:
    python3 scripts/plot_fpga.py results/n_queens_fpga.txt
"""

import re
import sys
import os
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ---------------------------------------------------------------------------
# 1. Leitura dos dados
# ---------------------------------------------------------------------------

def parse_fpga(path):
    ns, times = [], []
    with open(path) as f:
        for line in f:
            line = line.strip()
            m = re.match(r'^(\d+)\s+([\d]+)', line)
            if m:
                ns.append(int(m.group(1)))
                times.append(int(m.group(2)))
    return ns, times


# ---------------------------------------------------------------------------
# 2. Plot
# ---------------------------------------------------------------------------

def plot(ns, times, out_path):
    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(
        ns, times,
        color="#2ca02c",
        linewidth=2.2,
        marker="o",
        markersize=5,
        label="Tempo (FPGA)"
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title("N-Queens – FPGA\nTempo de execução por tamanho do problema", fontsize=14)

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
    print(f"Gráfico salvo em: {out_path}")
    plt.show()


# ---------------------------------------------------------------------------
# 3. Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 scripts/plot_fpga.py <arquivo>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    ns, times = parse_fpga(path)
    if not ns:
        print("Nenhum dado encontrado.", file=sys.stderr)
        sys.exit(1)

    base_dir = os.path.dirname(os.path.abspath(path))
    stem = os.path.splitext(os.path.basename(path))[0]
    out = os.path.join(base_dir, f"{stem}_plot.png")

    plot(ns, times, out)
