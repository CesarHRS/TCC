#!/usr/bin/env python3
"""
Plota os resultados da FPGA para todas as seeds, individualmente e em merged.

Usage:
    python3 scripts/plot_fpga_all.py results/n_queens_fpga.txt
"""

import re
import sys
import os
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ---------------------------------------------------------------------------
# 1. Paleta de cores por seed
# ---------------------------------------------------------------------------

COLORS = [
    "#2ca02c",  # verde  – seed inicial
    "#1f77b4",  # azul   – seed 1
    "#ff7f0e",  # laranja– seed 2
    "#9467bd",  # roxo   – seed 3
]


# ---------------------------------------------------------------------------
# 2. Parser: lê todas as seeds do arquivo
# ---------------------------------------------------------------------------

def parse_all_seeds(path):
    """
    Retorna lista de dicts: [{"label": str, "ns": [...], "times": [...]}, ...]
    Ignores entradas com '???'.
    """
    seeds = []
    current = None

    with open(path) as f:
        for raw in f:
            line = raw.strip()

            # Detecta cabeçalho de seed
            m_seed = re.match(r'^seed\s+(.+)', line, re.IGNORECASE)
            if m_seed:
                current = {"label": m_seed.group(1).strip(), "ns": [], "times": []}
                seeds.append(current)
                continue

            # Detecta linha de dado:  N <tab> valor
            if current is None:
                continue
            m_data = re.match(r'^(\d+)\s+([\d]+)$', line)
            if m_data:
                current["ns"].append(int(m_data.group(1)))
                current["times"].append(int(m_data.group(2)))

    return seeds


# ---------------------------------------------------------------------------
# 3. Plot individual por seed
# ---------------------------------------------------------------------------

def plot_single(seed, color, out_path):
    ns    = seed["ns"]
    times = seed["times"]
    label = seed["label"]

    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(
        ns, times,
        color=color,
        linewidth=2.2,
        marker="o",
        markersize=5,
        label=f"Seed {label}",
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title(
        f"N-Queens – FPGA\nSeed: {label}",
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
# 4. Plot merged (todas as seeds juntas)
# ---------------------------------------------------------------------------

def plot_merged(seeds, out_path):
    fig, ax = plt.subplots(figsize=(13, 7))

    for seed, color in zip(seeds, COLORS):
        ax.plot(
            seed["ns"], seed["times"],
            color=color,
            linewidth=2.2,
            marker="o",
            markersize=5,
            label=f"Seed {seed['label']}",
        )

    # Eixo X: união de todos os N presentes
    all_ns = sorted(set(n for s in seeds for n in s["ns"]))

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title(
        "N-Queens – FPGA\nTempo de execução por seed (todas as seeds)",
        fontsize=14,
    )

    ax.set_xticks(all_ns)
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
    if len(sys.argv) < 2:
        print("Uso: python3 scripts/plot_fpga_all.py <arquivo>", file=sys.stderr)
        sys.exit(1)

    path     = sys.argv[1]
    base_dir = os.path.dirname(os.path.abspath(path))

    seeds = parse_all_seeds(path)
    if not seeds:
        print("Nenhum dado encontrado.", file=sys.stderr)
        sys.exit(1)

    print(f"Seeds encontradas: {len(seeds)}")

    # --- Gráficos individuais ---
    for seed, color in zip(seeds, COLORS):
        # Nome de arquivo seguro: remove espaços e aspas
        safe = re.sub(r"[^A-Za-z0-9_]", "_", seed["label"])
        out  = os.path.join(base_dir, f"n_queens_fpga_{safe}_plot.png")
        plot_single(seed, color, out)

    # --- Gráfico merged ---
    out_merged = os.path.join(base_dir, "n_queens_fpga_merged_plot.png")
    plot_merged(seeds, out_merged)
