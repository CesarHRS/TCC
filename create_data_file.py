#!/usr/bin/env python3
"""
Script para criar arquivo de dados a partir da saída manual ou permitir entrada de dados
para plotagem do N-Queens
"""

import os
import re

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(ROOT_DIR, "n_queens_1-75.out")

# Dados extraídos da saída do run_n_queens_range.py
dados_manuais = {
    1: (250, "YES"),
    4: (10153, "YES"),
    5: (4739, "YES"),
    6: (764697699, "YES"),
    7: (473711002, "YES"),
    8: (303728507, "YES"),
    9: (922532570, "YES"),
    10: (2175179324, "YES"),
    11: (2548085035, "YES"),
    12: (2521831418, "YES"),
    13: (2104873897, "YES"),
    14: (2945107420, "YES"),
    15: (3783383504, "YES"),
    16: (3741737824, "YES"),
    17: (3566073478, "YES"),
    18: (4503714040, "YES"),
    19: (5005200669, "YES"),
    20: (5448948827, "YES"),
    21: (7387737857, "YES"),
    22: (6423120641, "YES"),
    23: (8548547078, "YES"),
    24: (9190750182, "YES"),
    25: (9921926577, "YES"),
    26: (10751538085, "YES"),
    27: (11420335614, "YES"),
    28: (11356751437, "YES"),
    29: (11123877999, "YES"),
    30: (13870600188, "YES"),
    31: (13667537371, "YES"),
    32: (15134403875, "YES"),
    33: (16065719752, "YES"),
    34: (16889909759, "YES"),
    35: (18221018960, "YES"),
    36: (18579826252, "YES"),
    37: (19546915853, "YES"),
    38: (16774914326, "YES"),
    39: (22326576994, "YES"),
    40: (22858435732, "YES"),
    41: (24112984907, "YES"),
    42: (52334070458, "YES"),
    43: (24674808522, "YES"),
    44: (27810154733, "YES"),
    45: (26940806009, "YES"),
    46: (30089508213, "YES"),
    47: (31194232846, "YES"),
    48: (31235415663, "YES"),
    49: (33694943500, "YES"),
    50: (32667762606, "YES"),
    51: (36141791204, "YES"),
    52: (32617499057, "YES"),
    53: (39031525145, "YES"),
}

# Criar arquivo de saída
with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
    out.write("# N-Queens average times for N=1..75 (10 runs each)\n")
    out.write("# Format: N average_time_ns status\n")
    for n, (time_ns, status) in sorted(dados_manuais.items()):
        out.write(f"{n} {time_ns} {status}\n")

print(f"✓ Arquivo de dados criado em: {OUTPUT_FILE}")
print(f"✓ Total de pontos: {len(dados_manuais)}")
