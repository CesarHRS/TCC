# N-Queens — Algoritmo Genético

Soluciona o problema das N rainhas via algoritmo genético com codificação por
permutação. O código C++ foi escrito para ser **estruturalmente equivalente** à
implementação em hardware (SystemVerilog), de forma que as escolhas algorítmicas
possam ser replicadas em um FPGA sem exigir recursos não sintetizáveis.

---

## Representação

Cada cromossomo é uma permutação de `[0, N-1]`: a posição `col` armazena a
linha da rainha naquela coluna. Por construção, conflitos de linha e coluna são
impossíveis; o fitness conta apenas **pares com conflito diagonal**.

```
fitness(c) = número de pares (i, j) com i < j tais que |c[i] - c[j]| == j - i
```

Uma solução válida tem `fitness == 0`.

---

## Parâmetros (config.h)

| Parâmetro    | Valor   | Descrição                                      |
|--------------|---------|------------------------------------------------|
| `BOARD_SIZE` | `N`     | Tamanho do tabuleiro (definido em tempo de compilação) |
| `POP_SIZE`   | 300     | Tamanho da população                           |
| `MAX_GENS`   | 500 000 | Limite de gerações                             |
| `ELITE`      | 30      | Indivíduos preservados por elitismo            |
| `TOURN_SIZE` | 4       | Tamanho do torneio de seleção                  |
| `MUT_THRESH` | 10      | Limiar inteiro de mutação (ver abaixo)         |
| `MUT_BITS`   | 7       | Bits do LFSR usados na decisão de mutação      |
| `STAG_LIMIT` | 150     | Gerações sem melhora para acionar reset parcial|
| `FULL_RESET` | 8       | Resets parciais consecutivos para reset total  |

---

## Escolhas de implementação compatíveis com hardware

Cada decisão abaixo tem um motivo direto ligado à sintetizabilidade no FPGA.

### 1. LFSR64 no lugar de Mersenne Twister

**Problema original:** `std::mt19937` mantém um estado interno de 624 palavras
de 32 bits (~20 KB de registradores). Não é prático em hardware.

**Solução:** LFSR (*Linear Feedback Shift Register*) de 64 bits com polinômio
`x^64 + x^63 + x^61 + x^60 + 1` (taps nos bits 63, 62, 60, 59). O estado cabe
em um único registrador de 64 bits; o novo bit é gerado com quatro XORs — uma
única célula lógica no FPGA. A semente `0xDEADBEEFCAFEBABEh` é idêntica no
software e no hardware para garantir sequências comparáveis.

```
novo_bit = estado[63] ^ estado[62] ^ estado[60] ^ estado[59]
estado   = {estado[62:0], novo_bit}          // shift left
```

### 2. Probabilidade de mutação por limiar inteiro

**Problema original:** `std::uniform_real_distribution<double>` + comparação
`prob < 0.08`. Ponto flutuante consome muitos elementos lógicos e não sintetiza
eficientemente em FPGAs de baixo custo (ex.: Cyclone II do DE2).

**Solução:** Comparar os `MUT_BITS` bits menos significativos do LFSR com um
limiar inteiro fixo:

```cpp
if ((rng.next() & 0x7F) < 10)   // 10/128 ≈ 7,8% ≈ 8%
    mutate(...);
```

Em hardware: `if (lfsr[6:0] < 7'd10)` — apenas um comparador de 7 bits.

### 3. Elitismo por varredura linear em vez de `std::sort`

**Problema original:** `std::sort` com lambda usa recursão dinâmica e não é
sintetizável diretamente. Um sorter completo de 300 elementos em hardware
consumiria centenas de LEs.

**Solução:** `ELITE` passagens de busca pelo mínimo (selection scan):

```
Para e = 0 até ELITE-1:
    Percorre os POP_SIZE indivíduos não selecionados
    Guarda o índice com menor fitness
    Marca como selecionado
```

Custo: `ELITE × POP_SIZE` comparações = 30 × 300 = 9 000 ciclos de clock por
geração. Equivale diretamente a um contador e um comparador sequencial no FPGA.

### 4. OX1 com bitmask inteiro (uint64_t)

**Problema original:** `std::vector<bool> used(N, false)` — vetor de tamanho
dinâmico, incompatível com hardware estático.

**Solução:** Registrador de N bits (`uint64_t` em software, `reg [N-1:0]` em
hardware). Cada bit indica se aquele gene já foi inserido no filho.

```cpp
uint64_t used = 0;
used |= (1ULL << gene);          // marcar gene como usado
if (!(used & (1ULL << gene)))    // verificar se gene está livre
```

Em hardware: operações de shift e AND em um registrador de largura fixa — zero
custo adicional de memória. Limita o algoritmo a `N ≤ 64`, suficiente para o
escopo do projeto.

### 5. Fisher-Yates explícito

**Problema original:** `std::shuffle` oculta internamente uma sequência de
operações com módulo variável. Para equivalência com o hardware, o algoritmo
precisa ser visível e determinístico.

**Solução:** Fisher-Yates com LFSR explícito:

```
Para i = N-1 até 1:
    j = lfsr.range(i+1)     // j ∈ [0, i]
    swap(c[i], c[j])
```

Em hardware: um contador `i` decrescente, um índice `j` lido do LFSR módulo
`i+1`, e uma troca de dois elementos do array. O divisor `i+1` é variável, mas
sintetizável para N pequeno (Quartus infere um divisor combinacional com N-1
configurações possíveis).

### 6. Troca de populações por cópia explícita

**Problema original:** `pop = std::move(next)` — semântica de ponteiro, custo
zero em C++. Em hardware não existe "mover" um array: é preciso copiar ou usar
double-buffer.

**Solução:** Cópia explícita elemento a elemento:

```cpp
for (int i = 0; i < POP_SIZE; ++i) { pop[i] = next[i]; fits[i] = nfits[i]; }
```

Em hardware: dois bancos de memória (double-buffer) alternados por um bit de
seleção. O banco de escrita da geração atual torna-se o banco de leitura da
próxima.

### 7. Busca do melhor por varredura linear

**Problema original:** `std::min_element` — ocultado pela STL, mas equivalente
a uma varredura linear. Aqui apenas tornamos isso explícito.

**Solução:**

```cpp
int best = fits[0];
for (int i = 1; i < POP_SIZE; ++i)
    if (fits[i] < best) best = fits[i];
```

Em hardware: um registrador `best_fit` atualizado a cada leitura da memória de
fitness. Custo: POP_SIZE ciclos de clock.

---

## Compilação

```bash
# N padrão = 8
make

# N arbitrário
make N=16
```

---

## Diferenças C++ × SystemVerilog

A tabela abaixo resume as diferenças entre as duas implementações. Os parâmetros
algorítmicos são idênticos; as diferenças são exclusivamente de mecanismo de
execução impostas pela natureza do hardware.

### Parâmetros — idênticos

| Parâmetro | C++ | SV |
|---|---|---|
| N, POP_SIZE, ELITE, TOURN_SIZE | config.h | `parameter` do módulo |
| MUT_THRESH / MUT_BITS | 10 / 7 | 10 / 7 |
| STAG_LIMIT / FULL_RESET | 150 / 8 | 150 / 8 |
| MAX_GENS | 500 000 | 500 000 |
| GENE_BITS, FIT_BITS, POP_BITS | implícitos | parâmetros explícitos (larguras de bus) |

### LFSR

Mesmo polinômio, mesma semente, mesmo shift. O SV adiciona um sinal `enable`:
o LFSR só avança quando explicitamente habilitado para não desperdiçar bits de
aleatoriedade em ciclos de espera de pipeline.

### Fitness

| | C++ | SV |
|---|---|---|
| Implementação | Loop serial O(N²) | N(N-1)/2 comparadores em **paralelo** |
| Latência | ~28 iterações (N=8) | **1 ciclo de clock** (combinacional) |

Maior ganho de paralelismo da implementação. O fitness do filho recém-gerado
está disponível instantaneamente via wire combinacional.

### Memória de população

| | C++ | SV |
|---|---|---|
| Estrutura | `vector<Chrom>` + `vector<int>` | 4 arrays BRAM (`pop_a/b`, `fit_a/b`) |
| Acesso | Aleatório, latência 0 | Registered read — **1 ciclo de latência** |
| Double-buffer | `next[]` local, copiado ao fim | `buf_sel` alterna entre bancos `a` e `b` |

A latência do BRAM gerou estados extras de pipeline (`S_SCAN_WARM`,
`S_TOURN_WAIT`, `S_CROSS_RD_P1`, `S_SCAN_DONE`).

### Fisher-Yates

| | C++ | SV |
|---|---|---|
| Sorteio de `j` | `rng.range(i+1)` → `% (i+1)` (divisor variável) | **máscara de bits + rejeição** |
| Ciclos por troca | 1 | ≥ 1 (rejeição adiciona tentativas) |

As duas abordagens são conceitualmente equivalentes: ambas produzem `j` uniforme
em `[0, i]`. O C++ usa divisor variável (simples em software); o SV usa a máscara
da potência de 2 mais próxima e descarta candidatos fora do intervalo:

```
j_cand = lfsr[GENE_BITS-1:0] & fy_mask   // fy_mask = 2^ceil(log2(i+2)) - 1
aceita se j_cand <= i
```

Para N=8 (GENE_BITS=3) a máscara é sempre `3'b111`; a rejeição sozinha garante
a uniformidade.

### Torneio

| | C++ | SV |
|---|---|---|
| Candidatos | TOURN_SIZE chamadas a `rng.range(POP_SIZE)` | TOURN_SIZE pares `S_TOURN` + `S_TOURN_WAIT` |
| Divisor | variável (`% POP_SIZE`) | fixo (constante de parâmetro → sintetizável) |
| Ciclos por torneio | — | `2 × TOURN_SIZE` ciclos |

`POP_SIZE` é uma constante em tempo de elaboração, então `% POP_SIZE` no SV
infere um divisor combinacional fixo — diferente do Fisher-Yates onde o divisor
muda a cada iteração.

### Elitismo

Estruturalmente idêntico: `ELITE` varreduras lineares de `POP_SIZE` elementos,
sem sort. O SV usa `selected_mask[POP_SIZE-1:0]` (registrador de bits) no lugar
do `vector<bool> selected` do C++.

### Estagnação / Reset

Lógica idêntica. A única diferença de implementação é o cuidado com timing de
atribuição não-bloqueante no SV: `init_idx` é atribuído diretamente (não
depende de `reset_start_idx` atualizado na mesma borda de clock).

### Resumo

| Aspecto | C++ | SV | Motivo |
|---|---|---|---|
| Fitness | Serial | Paralelo (1 ciclo) | Hardware permite N² comparadores simultâneos |
| Acesso à memória | O(1) imediato | 1 ciclo de latência (BRAM) | Inferência de Block RAM no Quartus |
| Divisor de módulo | Variável (`% n`) | Fixo ou máscara + rejeição | Divisor variável caro em hardware |
| Estrutura de controle | Funções + loops | FSM com 26 estados | Hardware tem execução sequencial single-thread |
| LFSR | Avança sempre | Controlado por `enable` | Evita desperdício de bits em ciclos ociosos |
| Double-buffer | Alocação local `next[]` | `buf_sel` com 4 arrays | Sem alocação dinâmica em hardware |

---

## Limitações conhecidas e decisões em aberto

| Item | Situação |
|---|---|
| `N ≤ 64` | Limitação da bitmask `uint64_t`; hardware também usa registrador de N bits |
| Semente fixa | Software e hardware usam `0xDEADBEEFCAFEBABEh`; sequências de LFSR não são idênticas devido à diferença de timing de leitura |
| `std::vector` | Mantido em C++ por conveniência; hardware usa arrays estáticos de tamanho `N × GENE_BITS` bits |
| Fisher-Yates | C++ usa `% (i+1)` (divisor variável); SV usa máscara de bits + rejeição para evitar divisor variável |
