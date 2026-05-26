# =============================================================================
#  Parâmetros globais
# =============================================================================
bits          ?= 1024
runs          ?= 10
n_queens_size ?= 8
n_min         ?= 4
n_max         ?= 15
threads       ?= 1
simplex_m     ?= 3
simplex_n     ?= 2

BITS          := $(bits)
RUNS          := $(runs)
N_QUEENS_SIZE := $(n_queens_size)
N_MIN         := $(n_min)
N_MAX         := $(n_max)
THREADS       := $(threads)
SIMPLEX_M     := $(simplex_m)
SIMPLEX_N     := $(simplex_n)

# =============================================================================
#  Ferramentas
# =============================================================================
CXX          ?= g++
CXXFLAGS     ?= -O3 -std=c++17 -march=native -Wall -Wextra -pipe
ifeq ($(filter 1,$(threads)),)
CXXFLAGS     += -DUSE_THREADS -DNUM_THREADS=$(THREADS)
endif

IVERILOG     ?= iverilog
VVP          ?= vvp
GTKWAVE      ?= gtkwave
IVERILOG_FLAGS ?= -g2012

# =============================================================================
#  Caminhos
# =============================================================================
BUILD        := build

VERILOG_DIR           := verilog
VERILOG_ONE_MAX_DIR   := $(VERILOG_DIR)/one_max
VERILOG_N_QUEENS_DIR  := $(VERILOG_DIR)/n_queens_ga

# --- One Max (Verilog) ---
TB_SRC       := $(VERILOG_ONE_MAX_DIR)/one_max_tb.sv
SV_SRCS      := $(VERILOG_ONE_MAX_DIR)/display.sv \
                $(VERILOG_ONE_MAX_DIR)/hill_climbing.sv \
                $(VERILOG_ONE_MAX_DIR)/one_max.sv
TOP          := one_max_tb
TB_BUILD     := $(BUILD)/one_max_tb_$(BITS).sv
SIMV         := $(BUILD)/$(TOP)_$(BITS).vvp
VCD          := $(BUILD)/dump_$(BITS).vcd

# --- One Max (C++) ---
ONE_MAX_CPP_SRC := cpp/one_max/main.cpp \
                   cpp/one_max/dynbits.cpp \
                   cpp/one_max/hill_climbing.cpp
ONE_MAX_CPP_BIN := $(BUILD)/onemax_t$(THREADS)_n$(BITS)
ONE_MAX_LOG     := $(BUILD)/onemax_n$(BITS)_r$(RUNS).log

# --- N-Queens (C++) ---
N_QUEENS_CPP_SRC := cpp/n_queens_ga/main.cpp \
                    cpp/n_queens_ga/nqueens.cpp \
                    cpp/n_queens_ga/genetic.cpp
N_QUEENS_CPP_BIN := $(BUILD)/nqueens_n$(N_QUEENS_SIZE)
N_QUEENS_LOG     := $(BUILD)/nqueens_n$(N_QUEENS_SIZE)_r$(RUNS).log
N_QUEENS_REG_LOG := $(BUILD)/nqueens_reg_n$(N_MIN)to$(N_MAX)_r$(RUNS).log

# --- N-Queens (Verilog) ---
N_QUEENS_TB_SRC  := $(VERILOG_N_QUEENS_DIR)/n_queens_tb.sv
N_QUEENS_SV_SRCS := $(VERILOG_N_QUEENS_DIR)/lfsr64.sv \
                    $(VERILOG_N_QUEENS_DIR)/fitness.sv \
                    $(VERILOG_N_QUEENS_DIR)/n_queens_ga.sv
N_QUEENS_TOP     := n_queens_tb
N_QUEENS_SIMV    := $(BUILD)/$(N_QUEENS_TOP)_n$(N_QUEENS_SIZE).vvp
N_QUEENS_VCD     := $(BUILD)/n_queens_dump_n$(N_QUEENS_SIZE).vcd

# --- Simplex (C++) ---
SIMPLEX_CPP_SRC := cpp/simplex/simplex.cpp
SIMPLEX_CPP_BIN := $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N)

# =============================================================================
#  Macro: loop de execuções com min/max/média
#  Uso: $(call run_bench, BINARY, LOG, LABEL)
# =============================================================================
define run_bench
	@{ \
	  printf "=========================================\n"; \
	  printf " %s\n" "$(3)"; \
	  printf " Runs: $(RUNS)\n"; \
	  printf " Data: %s\n" "$$(date '+%Y-%m-%d %H:%M:%S')"; \
	  printf "=========================================\n\n"; \
	  printf "%-6s  %14s\n" "Run" "Tempo (µs)"; \
	  printf "%-6s  %14s\n" "------" "--------------"; \
	  min_us=9999999999; max_us=0; sum_us=0; ok=0; \
	  for i in $$(seq 1 $(RUNS)); do \
	    output=$$($(1) 2>/dev/null); \
	    us=$$(echo "$$output" | awk '/Tempo/ { for(j=1;j<=NF;j++) if($$j=="="){print $$(j+1);exit} }'); \
	    if [ -z "$$us" ]; then \
	      printf "%-6d  %14s\n" "$$i" "SEM_SOL"; \
	      continue; \
	    fi; \
	    printf "%-6d  %14d\n" "$$i" "$$us"; \
	    [ "$$us" -lt "$$min_us" ] && min_us=$$us; \
	    [ "$$us" -gt "$$max_us" ] && max_us=$$us; \
	    sum_us=$$((sum_us + us)); \
	    ok=$$((ok + 1)); \
	  done; \
	  if [ "$$ok" -gt 0 ]; then \
	    avg_us=$$((sum_us / ok)); \
	    printf "\n%-20s  %14s\n" "--------------------" "--------------"; \
	    printf "%-20s  %14d\n" "Mínimo (µs)" "$$min_us"; \
	    printf "%-20s  %14d\n" "Máximo (µs)" "$$max_us"; \
	    printf "%-20s  %14d\n" "Média  (µs)" "$$avg_us"; \
	    printf "%-20s  %14d\n" "Total  (µs)" "$$sum_us"; \
	  fi; \
	  printf "\n=========================================\n"; \
	  printf " Log salvo em: $(2)\n"; \
	  printf "=========================================\n"; \
	} 2>&1 | tee $(2)
endef

# =============================================================================
#  Targets
# =============================================================================
.PHONY: all one_max n_queens n_queens_regression n_queens_sv verilog simplex wave run clean help
all: help

$(BUILD):
	@mkdir -p $(BUILD)

# --- One Max: simulação Verilog ------------------------------------------
$(TB_BUILD): $(TB_SRC) | $(BUILD)
	@echo "[make] Preparando testbench (N_BITS=$(BITS))"
	@cp $(TB_SRC) $@

$(SIMV): $(SV_SRCS) $(TB_BUILD) | $(BUILD)
	@echo "[make] Compilando SystemVerilog OneMax (N_BITS=$(BITS))"
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ $(SV_SRCS) $(TB_BUILD)

verilog: $(SIMV)
	@echo "[make] Simulando OneMax Verilog (N_BITS=$(BITS))"
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out

wave: $(SIMV)
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out
	@if [ -f "one_max_waves.vcd" ]; then mv one_max_waves.vcd $(VCD); fi
	@if [ -f "$(VCD)" ] && command -v $(GTKWAVE) >/dev/null 2>&1; then \
	  $(GTKWAVE) $(VCD); \
	else \
	  echo "[make] VCD disponível em $(VCD)"; \
	fi

# --- One Max: C++ -----------------------------------------------------------
$(ONE_MAX_CPP_BIN): $(ONE_MAX_CPP_SRC) | $(BUILD)
	@echo "[make] Compilando OneMax C++ (bits=$(BITS), threads=$(THREADS))"
	$(CXX) $(CXXFLAGS) -DBITS=$(BITS) -o $@ $(ONE_MAX_CPP_SRC)

one_max: $(ONE_MAX_CPP_BIN)
	$(call run_bench,$(ONE_MAX_CPP_BIN),$(ONE_MAX_LOG),OneMax Hill Climbing (C++) — bits=$(BITS))

# --- N-Queens: C++ ----------------------------------------------------------
$(N_QUEENS_CPP_BIN): $(N_QUEENS_CPP_SRC) | $(BUILD)
	@echo "[make] Compilando N-Queens C++ (N=$(N_QUEENS_SIZE))"
	$(CXX) $(CXXFLAGS) -DN=$(N_QUEENS_SIZE) -o $@ $(N_QUEENS_CPP_SRC)

n_queens: $(N_QUEENS_CPP_BIN)
	$(call run_bench,$(N_QUEENS_CPP_BIN),$(N_QUEENS_LOG),N-Queens GA (C++) — N=$(N_QUEENS_SIZE))

n_queens_regression: | $(BUILD)
	@{ \
	  printf "=========================================\n"; \
	  printf " Regressão N-Queens GA (C++)\n"; \
	  printf " N=%d..%d | %d runs por tamanho\n" "$(N_MIN)" "$(N_MAX)" "$(RUNS)"; \
	  printf " Data: %s\n" "$$(date '+%Y-%m-%d %H:%M:%S')"; \
	  printf "=========================================\n\n"; \
	  printf "%-4s  %-8s  %12s  %12s  %12s\n" \
	         "N" "Status" "Mín (µs)" "Máx (µs)" "Média (µs)"; \
	  printf "%-4s  %-8s  %12s  %12s  %12s\n" \
	         "----" "--------" "------------" "------------" "------------"; \
	  for n in $$(seq $(N_MIN) $(N_MAX)); do \
	    bin="$(BUILD)/nqueens_reg_$$n"; \
	    if ! $(CXX) $(CXXFLAGS) -DN=$$n -o "$$bin" $(N_QUEENS_CPP_SRC) 2>/tmp/nq_err_$$n; then \
	      printf "%-4d  %-8s  (erro de compilação)\n" "$$n" "ERRO"; \
	      continue; \
	    fi; \
	    min_us=9999999999; max_us=0; sum_us=0; ok=0; status="OK"; \
	    for i in $$(seq 1 $(RUNS)); do \
	      output=$$($$bin 2>/dev/null); \
	      us=$$(echo "$$output" | awk '/Tempo/ { for(j=1;j<=NF;j++) if($$j=="="){print $$(j+1);exit} }'); \
	      if [ -z "$$us" ]; then status="SEM_SOL"; continue; fi; \
	      [ "$$us" -lt "$$min_us" ] && min_us=$$us; \
	      [ "$$us" -gt "$$max_us" ] && max_us=$$us; \
	      sum_us=$$((sum_us + us)); \
	      ok=$$((ok + 1)); \
	    done; \
	    if [ "$$ok" -gt 0 ]; then \
	      avg_us=$$((sum_us / ok)); \
	      printf "%-4d  %-8s  %12d  %12d  %12d\n" \
	             "$$n" "$$status" "$$min_us" "$$max_us" "$$avg_us"; \
	    else \
	      printf "%-4d  %-8s  (sem solução em $(RUNS) runs)\n" "$$n" "$$status"; \
	    fi; \
	  done; \
	  printf "\n=========================================\n"; \
	  printf " Log salvo em: $(N_QUEENS_REG_LOG)\n"; \
	  printf "=========================================\n"; \
	} 2>&1 | tee $(N_QUEENS_REG_LOG)

# --- N-Queens: simulação Verilog --------------------------------------------
$(N_QUEENS_SIMV): $(N_QUEENS_SV_SRCS) $(N_QUEENS_TB_SRC) | $(BUILD)
	@echo "[make] Compilando N-Queens SystemVerilog (N=$(N_QUEENS_SIZE))"
	$(IVERILOG) $(IVERILOG_FLAGS) -DN=$(N_QUEENS_SIZE) -o $@ $(N_QUEENS_SV_SRCS) $(N_QUEENS_TB_SRC)

n_queens_sv: $(N_QUEENS_SIMV)
	@echo "[make] Simulando N-Queens Verilog (N=$(N_QUEENS_SIZE))"
	$(VVP) $(N_QUEENS_SIMV) | tee $(BUILD)/n_queens_sim_n$(N_QUEENS_SIZE).out
	@if [ -f "n_queens_waves.vcd" ]; then mv n_queens_waves.vcd $(N_QUEENS_VCD); fi

# --- Simplex: C++ -----------------------------------------------------------
$(SIMPLEX_CPP_BIN): $(SIMPLEX_CPP_SRC) | $(BUILD)
	@echo "[make] Compilando Simplex C++ (M=$(SIMPLEX_M), N=$(SIMPLEX_N))"
	$(CXX) $(CXXFLAGS) -DSIMPLEX_M=$(SIMPLEX_M) -DSIMPLEX_N=$(SIMPLEX_N) -o $@ $(SIMPLEX_CPP_SRC)

simplex: $(SIMPLEX_CPP_BIN)
	$(call run_bench,$(SIMPLEX_CPP_BIN),$(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N)_r$(RUNS).log,Simplex (C++) — M=$(SIMPLEX_M) N=$(SIMPLEX_N))

run: verilog

# --- Limpeza ----------------------------------------------------------------
clean:
	@echo "[make] Removendo artefatos de build"
	@rm -rf $(BUILD) one_max_waves.vcd n_queens_waves.vcd

# --- Ajuda ------------------------------------------------------------------
help:
	@echo ""
	@echo "Uso: make <target> [parâmetros]"
	@echo ""
	@echo "Parâmetros disponíveis:"
	@echo "  bits=<N>             Tamanho do vetor OneMax       (padrão: 1024)"
	@echo "  runs=<N>             Número de execuções           (padrão: 10)"
	@echo "  n_queens_size=<N>    Tabuleiro N-Queens            (padrão: 8)"
	@echo "  n_min=<N>            N mínimo da regressão         (padrão: 4)"
	@echo "  n_max=<N>            N máximo da regressão         (padrão: 15)"
	@echo "  threads=<N>          Threads para OneMax           (padrão: 1)"
	@echo "  simplex_m=<M>        Linhas do Simplex             (padrão: 3)"
	@echo "  simplex_n=<N>        Colunas do Simplex            (padrão: 2)"
	@echo ""
	@echo "Targets:"
	@echo "  one_max              Compila e roda OneMax C++"
	@echo "  n_queens             Compila e roda N-Queens GA C++ (um N)"
	@echo "  n_queens_regression  Roda N-Queens para N=n_min..n_max (todos os tamanhos)"
	@echo "  n_queens_sv          Simula N-Queens em SystemVerilog"
	@echo "  verilog              Simula OneMax em SystemVerilog"
	@echo "  wave                 Simula OneMax e abre GTKWave"
	@echo "  simplex              Compila e roda Simplex C++"
	@echo "  clean                Remove o diretório build/"
	@echo ""
	@echo "Exemplos:"
	@echo "  make one_max bits=1024 runs=20"
	@echo "  make n_queens n_queens_size=12 runs=5"
	@echo "  make n_queens_regression n_min=4 n_max=12 runs=10"
	@echo "  make n_queens_sv n_queens_size=8"
