#!/usr/bin/env python3
"""
Script para plotar o tempo de execução do N-Queens em função de N (5-50)
Tempo é exibido em milissegundos (ms)
"""

import os
import re
import matplotlib.pyplot as plt
import numpy as np

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(ROOT_DIR, "n_queens_1-75.out")

# Dicionários para armazenar dados
n_values = []
time_ms_values = []

# Ler arquivo de saída
if not os.path.exists(OUTPUT_FILE):
    print(f"Erro: Arquivo {OUTPUT_FILE} não encontrado.")
    print("Execute 'python run_n_queens_range.py' primeiro para gerar os dados.")
    exit(1)

with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
    for line in f:
        # Ignorar linhas de comentário
        if line.startswith("#"):
            continue
        
        # Processar linhas com dados
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        
        try:
            n = int(parts[0])
            # Considerar apenas valores de 5 a 50
            if 5 <= n <= 50:
                time_ns = int(parts[1])
                status = parts[2] if len(parts) > 2 else "UNKNOWN"
                
                # Considerar apenas execuções bem-sucedidas (status = YES)
                if status == "YES":
                    n_values.append(n)
                    # Converter nanosegundos para milissegundos (1 ms = 1e6 ns)
                    time_ms = time_ns / 1e6
                    time_ms_values.append(time_ms)
        except (ValueError, IndexError):
            continue

if not n_values:
    print("Nenhum dato válido encontrado para N entre 5 e 50.")
    exit(1)

# Criar gráfico
plt.figure(figsize=(12, 7))
plt.plot(n_values, time_ms_values, 'bo-', linewidth=2, markersize=6, label='Tempo de execução')
plt.scatter(n_values, time_ms_values, s=60, c='red', alpha=0.6, zorder=5)

# Configurar eixos e rótulos
plt.xlabel('Tamanho do N', fontsize=12, fontweight='bold')
plt.ylabel('Tempo de Execução (ms)', fontsize=12, fontweight='bold')
plt.title('N-Queens: Tempo de Execução vs Tamanho do N', fontsize=14, fontweight='bold')
plt.grid(True, alpha=0.3, linestyle='--')
plt.legend(fontsize=11)

# Formatar os eixos
ax = plt.gca()
# Mostrar todos os valores de N no eixo X
ax.set_xticks(range(5, 51, 1))
ax.tick_params(axis='x', rotation=45)

plt.tight_layout()

# Salvar figura
output_plot = os.path.join(ROOT_DIR, "n_queens_plot.png")
plt.savefig(output_plot, dpi=300, bbox_inches='tight')
print(f"✓ Gráfico salvo em: {output_plot}")

# Exibir gráfico
plt.show()

# Imprimir resumo
print(f"\nResumo dos dados (N = 5 a 50):")
print(f"  Quantidade de pontos: {len(n_values)}")
print(f"  Tempo mínimo: {min(time_ms_values):.4f} ms (N={n_values[time_ms_values.index(min(time_ms_values))]})")
print(f"  Tempo máximo: {max(time_ms_values):.4f} ms (N={n_values[time_ms_values.index(max(time_ms_values))]})")
print(f"  Tempo médio: {np.mean(time_ms_values):.4f} ms")
