#!/usr/bin/env python3
"""
Plota o tempo de execução de N-Queens baseado nos pontos fornecidos.
O gráfico é salvo em n_queens_plot_fpga.png.
"""

import os
import matplotlib.pyplot as plt

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(ROOT_DIR, "n_queens_plot_fpga.png")

# Dados fornecidos pelo usuário
# Formato: (N, tempo_ns)
# Seed usada: h123456789ABCDEF
DATA = [
    (30, 45126282),
    (29, 40428540),
    (28, 35704522),
    (27, 29764928),
    (26, 26788886),
    (25, 23086172),
    (24, 18305450),
    (23, 14347632),
    (22, 9949814),
    (21, 5551996),
    (20, 1154178),
    (19, 96756360),
    (18, 92358542),
    (17, 87960724),
    (16, 83562906),
    (15, 79165088),
    (14, 74767270),
    (13, 70369452),
    (12, 65963990),
    (11, 61573816),
    (10, 57175998),
    (9, 52778220),
    (8, 48380398),
    (7, 43982576),
    (6, 39584754),
    (5, 35186932),
]

# Ordenar por N para garantir a sequência correta no gráfico
DATA.sort(key=lambda item: item[0])

# Preparar dados para plotagem
n_values = [n for n, _ in DATA]
time_ms_values = [time_ns / 1e6 for _, time_ns in DATA]

plt.figure(figsize=(12, 7))
plt.plot(n_values, time_ms_values, marker='o', linestyle='-', color='#1f77b4', linewidth=2, markersize=6)
plt.scatter(n_values, time_ms_values, c='#ff7f0e', s=60, zorder=5)

plt.xlabel('Tamanho do N', fontsize=12, fontweight='bold')
plt.ylabel('Tempo de Execução (ms)', fontsize=12, fontweight='bold')
plt.title('N-Queens FPGA: Tempo de Execução vs Tamanho do N', fontsize=14, fontweight='bold')
plt.grid(True, alpha=0.3, linestyle='--')

ax = plt.gca()
ax.set_xticks(range(5, 31))
ax.set_xticklabels(range(5, 31), rotation=45)

plt.tight_layout()
plt.savefig(OUTPUT_FILE, dpi=300, bbox_inches='tight')
print(f"✓ Gráfico salvo em: {OUTPUT_FILE}")
plt.show()
