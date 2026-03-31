bits ?= 1024
BITS = $(bits)

VERILOG_DIR := verilog
VERILOG_ONE_MAX_DIR := $(VERILOG_DIR)/one_max
VERILOG_SIMPLEX_DIR := $(VERILOG_DIR)/simplex
TB_SRC := $(VERILOG_ONE_MAX_DIR)/one_max_tb.sv
SV_SRCS := $(VERILOG_ONE_MAX_DIR)/display.sv \
           $(VERILOG_ONE_MAX_DIR)/hill_climbing.sv \
           $(VERILOG_ONE_MAX_DIR)/one_max.sv

TOP := one_max_tb
BUILD := build
TB_BUILD := $(BUILD)/one_max_tb_$(BITS).sv
SIMV := $(BUILD)/$(TOP)_$(BITS).vvp
VCD := $(BUILD)/dump_$(BITS).vcd
IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave
IVERILOG_FLAGS ?= -g2012

CXX ?= g++
CXXFLAGS ?= -O3 -std=c++17 -march=native -Wall -Wextra -pipe
ifdef threads
CXXFLAGS += -DUSE_THREADS -DNUM_THREADS=$(THREADS)
endif
THREADS := $(if $(threads),$(if $(filter 1 yes on true,$(threads)),$(shell nproc),$(threads)),1)

# One Max C++
ONE_MAX_CPP_SRC := cpp/one_max/main.cpp cpp/one_max/dynbits.cpp cpp/one_max/hill_climbing.cpp
ONE_MAX_CPP_BIN := $(BUILD)/onemax_$(THREADS)_$(BITS)

# Simplex C++
simplex_m ?= 3
simplex_n ?= 2
SIMPLEX_M := $(simplex_m)
SIMPLEX_N := $(simplex_n)
SIMPLEX_CPP_SRC := cpp/simplex/simplex.cpp
SIMPLEX_CPP_BIN := $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N)

.PHONY: all verilog one_max simplex sim wave run clean help
all: help

$(BUILD):
	@mkdir -p $(BUILD)

$(TB_BUILD): $(TB_SRC) | $(BUILD)
	@echo "[make] Generating testbench with N_BITS=$(BITS)"
	@cp $(TB_SRC) $@

$(SIMV): $(SV_SRCS) $(TB_BUILD) | $(BUILD)
	@echo "[make] Compiling SystemVerilog sources with $(IVERILOG) (N_BITS=$(BITS))"
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ $(SV_SRCS) $(TB_BUILD)

verilog: $(SIMV)
	@echo "[make] Running Verilog simulation (output/log in $(BUILD)/)"
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out

$(ONE_MAX_CPP_BIN): $(ONE_MAX_CPP_SRC) | $(BUILD)
	@echo "[make] Compiling OneMax C++ solver with bits=$(bits)"
	$(CXX) $(CXXFLAGS) -DBITS=$(bits) -o $@ $(ONE_MAX_CPP_SRC)

one_max: $(ONE_MAX_CPP_BIN)
	@echo "[make] Running OneMax C++ solver (bits=$(bits), THREADS=$(THREADS)) 10 times"
	@echo "=========================================" > $(BUILD)/cpp_$(THREADS)_$(bits).out
	@if [ $(THREADS) -eq 1 ]; then \
		echo "Teste: BITS=$(bits), MODE=SINGLE-CORE" >> $(BUILD)/cpp_$(THREADS)_$(bits).out; \
	else \
		echo "Teste: BITS=$(bits), MODE=MULTI-CORE ($(THREADS) threads)" >> $(BUILD)/cpp_$(THREADS)_$(bits).out; \
	fi
	@echo "=========================================" >> $(BUILD)/cpp_$(THREADS)_$(bits).out
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		echo "Run $$i:"; \
		$(ONE_MAX_CPP_BIN); \
	done | tee -a $(BUILD)/cpp_$(THREADS)_$(bits).out | awk '/Tempo/ {for (j=1; j<=NF; j++) if ($$j == "=") {sum += $$(j+1); count++; break}} END {if (count > 0) print "=========================================\nMédia:", sum/count, "µs\n========================================="}' >> $(BUILD)/cpp_$(THREADS)_$(bits).out

$(SIMPLEX_CPP_BIN): $(SIMPLEX_CPP_SRC) | $(BUILD)
	@echo "[make] Compiling Simplex C++ solver (SIMPLEX_M=$(simplex_m) SIMPLEX_N=$(simplex_n))"
	$(CXX) $(CXXFLAGS) -DSIMPLEX_M=$(simplex_m) -DSIMPLEX_N=$(simplex_n) -o $@ $(SIMPLEX_CPP_SRC)

simplex: $(SIMPLEX_CPP_BIN)
	@echo "[make] Running Simplex C++ solver (M=$(simplex_m), N=$(simplex_n)) 10 times"
	@echo "=========================================" > $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N).out
	@echo "Teste: SIMPLEX_M=$(simplex_m), SIMPLEX_N=$(simplex_n)" >> $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N).out
	@echo "=========================================" >> $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N).out
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		echo "Run $$i:"; \
		$(SIMPLEX_CPP_BIN); \
	done | tee -a $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N).out | awk '/Tempo/ {for (j=1; j<=NF; j++) if ($$j == "=") {sum += $$(j+1); count++; break}} END {if (count > 0) print "=========================================\nMédia:", sum/count, "µs\n========================================="}' >> $(BUILD)/simplex_$(SIMPLEX_M)x$(SIMPLEX_N).out

run: verilog

wave: $(SIMV)
	@echo "[make] Running simulation and attempting to open waveform"
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out
	@# Move o arquivo gerado na raiz para a pasta build
	@if [ -f "one_max_waves.vcd" ]; then \
		mv one_max_waves.vcd $(VCD); \
	fi
	@if [ -f "$(VCD)" ]; then \
		if command -v $(GTKWAVE) >/dev/null 2>&1; then \
			$(GTKWAVE) $(VCD); \
		else \
			echo "[make] gtkwave not found — VCD available at $(VCD)"; \
		fi \
	else \
		echo "[make] No VCD found at $(VCD). Ensure your testbench writes to it."; \
	fi

clean:
	@echo "[make] Cleaning build artifacts"
	@rm -rf $(BUILD) one_max_waves.vcd

help:
	@echo "Makefile targets:"
	@echo "  make verilog BITS=<n>          : compile+run SystemVerilog testbench (one_max)"
	@echo "  make one_max bits=<n>          : compile+run one_max C++ solver (single-core)"
	@echo "  make one_max bits=<n> threads=1 : compile+run one_max C++ solver (multi-core (all cores))"
	@echo "  make one_max bits=<n> threads=<num> : compile+run one_max C++ solver (with <num> threads)"
	@echo "  make simplex simplex_m=<m> simplex_n=<n> : compile+run simplex C++ solver (10 runs with log)"
	@echo "  make wave BITS=<n>             : run verilog and open VCD with gtkwave"
	@echo "  make clean                     : remove build directory"
