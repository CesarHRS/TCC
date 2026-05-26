#!/usr/bin/env python3
"""
Plot comparativo N-Queens: merged C++ (média global das seeds, 100 runs)
vs merged FPGA (média global das seeds).

Usage:
    python3 scripts/plot_comparison.py results/n_queens_100_cpp.txt results/n_queens_fpga.txt
"""

import re
import sys
import os
import collections
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

N_MAX = 20


# ---------------------------------------------------------------------------
# 1. Parser CPP — média global de todas as seeds (N <= N_MAX)
# ---------------------------------------------------------------------------

def parse_cpp_merged(path):
    """
    Lê todas as seeds do arquivo CPP e retorna a média global por N.
    Retorna (ns, means) onde means[i] é a média das médias de todas as seeds
    para ns[i].
    """
    acc     = collections.defaultdict(list)
    pattern = re.compile(r'^\s*(\d+)\s+OK\s+\d+\s+\d+\s+(\d+)')

    with open(path) as f:
        for line in f:
            m = pattern.match(line)
            if m:
                n = int(m.group(1))
                if n > N_MAX:
                    continue
                acc[n].append(int(m.group(2)))

    ns    = sorted(acc)
    means = [sum(acc[n]) / len(acc[n]) for n in ns]
    return ns, means


# ---------------------------------------------------------------------------
# 2. Parser FPGA — média global de todas as seeds (N <= N_MAX)
# ---------------------------------------------------------------------------

def parse_fpga_merged(path):
    """
    Lê todas as seeds do arquivo FPGA e retorna a média global por N.
    Ignora entradas com '???'.
    """
    acc      = collections.defaultdict(list)
    in_seed  = False

    with open(path) as f:
        for raw in f:
            line = raw.strip()
            if re.match(r'^seed\s+', line, re.IGNORECASE):
                in_seed = True
                continue
            if not in_seed:
                continue
            m = re.match(r'^(\d+)\s+(\d+)$', line)
            if m:
                n = int(m.group(1))
                if n > N_MAX:
                    continue
                acc[n].append(int(m.group(2)))

    ns    = sorted(acc)
    means = [sum(acc[n]) / len(acc[n]) for n in ns]
    return ns, means


# ---------------------------------------------------------------------------
# 3. Plot
# ---------------------------------------------------------------------------

def plot_comparison(cpp_ns, cpp_means, fpga_ns, fpga_means, out_path):
    # Intersecção de N presentes nos dois conjuntos
    common   = sorted(set(cpp_ns) & set(fpga_ns))
    cpp_map  = dict(zip(cpp_ns,  cpp_means))
    fpga_map = dict(zip(fpga_ns, fpga_means))

    c_vals = [cpp_map[n]  for n in common]
    f_vals = [fpga_map[n] for n in common]

    fig, ax = plt.subplots(figsize=(13, 6))

    ax.plot(
        common, c_vals,
        color="#1f77b4",
        linewidth=2.4,
        marker="o",
        markersize=6,
        label="C++ – média global (4 seeds × 100 runs)",
    )
    ax.plot(
        common, f_vals,
        color="#2ca02c",
        linewidth=2.4,
        marker="s",
        markersize=6,
        linestyle="--",
        label="FPGA – média global (4 seeds)",
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo médio (µs)", fontsize=13)
    ax.set_title(
        "N-Queens – C++ vs FPGA\nMédia global das seeds por tamanho do problema",
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
# 4. Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            "Uso: python3 scripts/plot_comparison.py <cpp_100_file> <fpga_file>",
            file=sys.stderr,
        )
        sys.exit(1)

    cpp_path  = sys.argv[1]
    fpga_path = sys.argv[2]
    out_dir   = os.path.dirname(os.path.abspath(cpp_path))

    cpp_ns,  cpp_means  = parse_cpp_merged(cpp_path)
    fpga_ns, fpga_means = parse_fpga_merged(fpga_path)

    print(f"C++  seeds/N: {len(cpp_ns)} pontos  (N={cpp_ns[0]}..{cpp_ns[-1]})")
    print(f"FPGA seeds/N: {len(fpga_ns)} pontos  (N={fpga_ns[0]}..{fpga_ns[-1]})")

    out = os.path.join(out_dir, "comparison_cpp100_fpga_plot.png")
    plot_comparison(cpp_ns, cpp_means, fpga_ns, fpga_means, out)
