bits ?= 1024
BITS = $(bits)

VERILOG_DIR := verilog
TB_SRC := $(VERILOG_DIR)/one_max_tb.sv
SV_SRCS := $(VERILOG_DIR)/display.sv \
           $(VERILOG_DIR)/hill_climbing.sv \
           $(VERILOG_DIR)/one_max.sv

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
CPP_SRC := cpp/main.cpp cpp/dynbits.cpp cpp/hill_climbing.cpp
CPP_BIN := $(BUILD)/onemax_$(THREADS)_$(BITS)

.PHONY: all verilog cpp sim wave run clean help
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

$(CPP_BIN): $(CPP_SRC) | $(BUILD)
	@echo "[make] Compiling C++ solver with bits=$(bits)"
	$(CXX) $(CXXFLAGS) -DBITS=$(bits) -o $@ $(CPP_SRC)

cpp: $(CPP_BIN)
	@echo "[make] Running C++ solver (bits=$(bits), THREADS=$(THREADS)) 10 times"
	@echo "=========================================" > $(BUILD)/cpp_$(THREADS)_$(bits).out
	@if [ $(THREADS) -eq 1 ]; then \
		echo "Teste: BITS=$(bits), MODE=SINGLE-CORE" >> $(BUILD)/cpp_$(THREADS)_$(bits).out; \
	else \
		echo "Teste: BITS=$(bits), MODE=MULTI-CORE ($(THREADS) threads)" >> $(BUILD)/cpp_$(THREADS)_$(bits).out; \
	fi
	@echo "=========================================" >> $(BUILD)/cpp_$(THREADS)_$(bits).out
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		echo "Run $$i:"; \
		$(CPP_BIN); \
	done | tee -a $(BUILD)/cpp_$(THREADS)_$(bits).out | awk '/Tempo/ {sum += $$3; count++} END {if (count > 0) print "=========================================\nMédia:", sum/count, "µs\n========================================="}' >> $(BUILD)/cpp_$(THREADS)_$(bits).out

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
	@echo "  make verilog BITS=<n>  : compile+run SystemVerilog testbench"
	@echo "  make cpp bits=<n>      : compile+run C++ solver (single-core)"
	@echo "  make cpp bits=<n> threads=1  : compile+run C++ solver (multi-core with all cores)"
	@echo "  make cpp bits=<n> threads=<num> : compile+run C++ solver (with <num> threads)"
	@echo "  make wave BITS=<n>     : run verilog and open VCD with gtkwave"
	@echo "  make clean             : remove build directory"
