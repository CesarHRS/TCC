#!/usr/bin/env python3
"""
Plota os resultados do C++ (100 runs) para todas as seeds:
  - Um gráfico por seed (apenas média, sem banda min/max)
  - Um gráfico merged com todas as seeds + linha de média global

Usage:
    python3 scripts/plot_cpp_100.py results/n_queens_100_cpp.txt
"""

import re
import sys
import os
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker


# ---------------------------------------------------------------------------
# 1. Paleta de cores (mesma do plot_fpga_all.py)
# ---------------------------------------------------------------------------

COLORS = [
    "#2ca02c",  # verde   – seed DEADBEEFCAFEBABE
    "#1f77b4",  # azul    – seed 2D0070EA_E49E7A8C
    "#ff7f0e",  # laranja – seed 711F8A0B_846FFFB0
    "#9467bd",  # roxo    – seed C2F7A5DE_772DF504
]


# ---------------------------------------------------------------------------
# 2. Parser
# ---------------------------------------------------------------------------

def parse_cpp_all_seeds(path):
    """
    Lê o arquivo de regressão CPP e retorna:
        [{"label": str, "ns": [...], "mins": [...], "maxs": [...], "means": [...]}, ...]

    Formato esperado por bloco de seed:
        seed <LABEL>
        ...cabeçalho...
        N     Status   Min (µs)   Max (µs)   Média (µs)   Total (µs)   Solução
        4     OK       147        205        153           15377        1 3 0 2
        ...
    """
    seeds = []
    current = None

    with open(path) as f:
        for raw in f:
            line = raw.strip()

            # Detecta linha de seed
            m_seed = re.match(r'^seed\s+(.+)', line, re.IGNORECASE)
            if m_seed:
                current = {
                    "label":  m_seed.group(1).strip(),
                    "ns":     [],
                    "mins":   [],
                    "maxs":   [],
                    "means":  [],
                }
                seeds.append(current)
                continue

            if current is None:
                continue

            # Detecta linha de dado:  N  OK  min  max  média  ...
            m_data = re.match(r'^(\d+)\s+OK\s+(\d+)\s+(\d+)\s+(\d+)', line)
            if m_data:
                n = int(m_data.group(1))
                if n > 20:          # limita a N <= 20
                    continue
                current["ns"].append(n)
                current["mins"].append(int(m_data.group(2)))
                current["maxs"].append(int(m_data.group(3)))
                current["means"].append(int(m_data.group(4)))

    return seeds


# ---------------------------------------------------------------------------
# 3. Plot individual por seed  (apenas média)
# ---------------------------------------------------------------------------

def plot_single(seed, color, out_path):
    ns    = seed["ns"]
    means = seed["means"]
    label = seed["label"]

    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(
        ns, means,
        color=color,
        linewidth=2.2,
        marker="o",
        markersize=5,
        label=f"Seed {label}",
    )

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo médio (µs)", fontsize=13)
    ax.set_title(
        f"N-Queens – C++ (100 runs)\nSeed: {label}",
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
# 4. Plot merged (todas as seeds + linha de média global)
# ---------------------------------------------------------------------------

def plot_merged(seeds, out_path):
    import collections

    fig, ax = plt.subplots(figsize=(13, 7))

    # --- linhas individuais por seed ---
    for seed, color in zip(seeds, COLORS):
        ax.plot(
            seed["ns"], seed["means"],
            color=color,
            linewidth=1.8,
            marker="o",
            markersize=4,
            alpha=0.7,
            label=f"Seed {seed['label']}",
        )

    # --- média global: para cada N, média das médias de todas as seeds ---
    acc = collections.defaultdict(list)
    for seed in seeds:
        for n, m in zip(seed["ns"], seed["means"]):
            acc[n].append(m)

    global_ns    = sorted(acc.keys())
    global_means = [sum(acc[n]) / len(acc[n]) for n in global_ns]

    ax.plot(
        global_ns, global_means,
        color="#d62728",        # vermelho – destaque
        linewidth=2.8,
        marker="D",
        markersize=6,
        linestyle="--",
        label="Média global (todas as seeds)",
        zorder=5,
    )

    all_ns = sorted(set(n for s in seeds for n in s["ns"]))

    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo médio (µs)", fontsize=13)
    ax.set_title(
        "N-Queens – C++ (100 runs)\nTempo médio por seed + média global",
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
        print("Uso: python3 scripts/plot_cpp_100.py <arquivo>", file=sys.stderr)
        sys.exit(1)

    path     = sys.argv[1]
    base_dir = os.path.dirname(os.path.abspath(path))

    seeds = parse_cpp_all_seeds(path)
    if not seeds:
        print("Nenhum dado encontrado.", file=sys.stderr)
        sys.exit(1)

    print(f"Seeds encontradas: {len(seeds)}")
    for s in seeds:
        print(f"  {s['label']}: N = {s['ns'][0]}..{s['ns'][-1]} ({len(s['ns'])} pontos)")

    # --- Gráficos individuais ---
    for seed, color in zip(seeds, COLORS):
        safe = re.sub(r"[^A-Za-z0-9_]", "_", seed["label"])
        out  = os.path.join(base_dir, f"n_queens_100_cpp_{safe}_plot.png")
        plot_single(seed, color, out)

    # --- Gráfico merged ---
    out_merged = os.path.join(base_dir, "n_queens_100_cpp_merged_plot.png")
    plot_merged(seeds, out_merged)
