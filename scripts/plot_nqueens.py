#!/usr/bin/env python3
"""
Plot N-Queens GA regression results.

Usage:
    ./regression_nqueens.sh | python3 scripts/plot_nqueens.py
    # ou, se você salvou a saída em um arquivo:
    python3 scripts/plot_nqueens.py resultados.txt
"""

import re
import sys
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# ---------------------------------------------------------------------------
# 1. Leitura dos dados
# ---------------------------------------------------------------------------

def parse_stdin_or_file():
    if len(sys.argv) > 1:
        with open(sys.argv[1], "r") as f:
            lines = f.readlines()
    else:
        lines = sys.stdin.readlines()
    return lines


def parse_results(lines):
    # Linha de dados:  N  Status  Min  Max  Média  Total  Solução
    pattern = re.compile(
        r"^\s*(\d+)\s+OK\s+([\d]+)\s+([\d]+)\s+([\d]+)\s+([\d]+)"
    )
    ns, mins_, maxs_, means_ = [], [], [], []
    for line in lines:
        m = pattern.match(line)
        if m:
            n, mn, mx, mean = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
            ns.append(n)
            mins_.append(mn)
            maxs_.append(mx)
            means_.append(mean)
    return ns, mins_, maxs_, means_


# ---------------------------------------------------------------------------
# 2. Plot
# ---------------------------------------------------------------------------

def plot(ns, mins_, maxs_, means_):
    fig, ax = plt.subplots(figsize=(12, 6))

    # Linha principal – média
    ax.plot(
        ns, means_,
        color="#d62728",
        linewidth=2.2,
        marker="o",
        markersize=5,
        label="Tempo médio"
    )

    # Eixos e rótulos
    ax.set_xlabel("N (número de rainhas)", fontsize=13)
    ax.set_ylabel("Tempo (µs)", fontsize=13)
    ax.set_title("N-Queens – Algoritmo Genético (C++)\nTempo de execução por tamanho do problema", fontsize=14)

    ax.set_xticks(ns)
    ax.tick_params(axis="x", rotation=45)

    # Escala logarítmica no eixo Y (os valores variam ~3 ordens de grandeza)
    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(
        ticker.FuncFormatter(lambda x, _: f"{x:,.0f}")
    )

    ax.legend(fontsize=11)
    ax.grid(True, which="both", linestyle="--", linewidth=0.5, alpha=0.5)
    fig.tight_layout()

    # Salva no mesmo diretório do arquivo de entrada (ou no diretório atual)
    import os
    if len(sys.argv) > 1:
        base_dir = os.path.dirname(os.path.abspath(sys.argv[1]))
        stem = os.path.splitext(os.path.basename(sys.argv[1]))[0]
        out = os.path.join(base_dir, f"{stem}_plot.png")
    else:
        out = "nqueens_regression.png"
    fig.savefig(out, dpi=150)
    print(f"Gráfico salvo em: {out}")
    plt.show()


# ---------------------------------------------------------------------------
# 3. Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    lines = parse_stdin_or_file()
    ns, mins_, maxs_, means_ = parse_results(lines)
    if not ns:
        print("Nenhum dado encontrado. Verifique o formato da entrada.", file=sys.stderr)
        sys.exit(1)
    plot(ns, mins_, maxs_, means_)
