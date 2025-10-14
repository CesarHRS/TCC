
# Size in bits (override on make command line):
BITS ?= 1024

# Verilog settings
VERILOG_DIR := verilog
TB_SRC := $(VERILOG_DIR)/tb_one_max.sv
SV_SRCS := $(VERILOG_DIR)/one_max_solver.sv
TOP := tb_one_max
BUILD := build
TB_BUILD := $(BUILD)/tb_one_max_$(BITS).sv
SIMV := $(BUILD)/$(TOP)_$(BITS).vvp
VCD := $(BUILD)/dump_$(BITS).vcd
IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave
IVERILOG_FLAGS ?= -g2012

# C++ settings
CXX ?= g++
CXXFLAGS ?= -O3 -std=c++17 -march=native -Wall -Wextra -pipe
CPP_SRC := cpp/main.cpp
CPP_BIN := $(BUILD)/onemax_$(BITS)

.PHONY: all verilog cpp sim wave run clean help
all: help

$(BUILD):
	@mkdir -p $(BUILD)

# create a copy of the testbench with the requested BITS value
$(TB_BUILD): $(TB_SRC) | $(BUILD)
	@echo "[make] Generating testbench with N_BITS=$(BITS)"
	@sed -E 's/(localparam[[:space:]]+N_BITS[[:space:]]*=[[:space:]]*)[0-9]+;/\1$(BITS);/g' $(TB_SRC) > $@

$(SIMV): $(SV_SRCS) $(TB_BUILD) | $(BUILD)
	@echo "[make] Compiling SystemVerilog sources with $(IVERILOG) (N_BITS=$(BITS))"
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ $(SV_SRCS) $(TB_BUILD)

verilog: $(SIMV)
	@echo "[make] Running Verilog simulation (output/log in $(BUILD)/)"
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out

# Build C++ binary with BITS as compile-time macro
$(CPP_BIN): $(CPP_SRC) | $(BUILD)
	@echo "[make] Compiling C++ solver with BITS=$(BITS)"
	$(CXX) $(CXXFLAGS) -DBITS=$(BITS) -o $@ $(CPP_SRC)

cpp: $(CPP_BIN)
	@echo "[make] Running C++ solver (BITS=$(BITS))"
	$(CPP_BIN) | tee $(BUILD)/cpp_sim_$(BITS).out

run: verilog

wave: $(SIMV)
	@echo "[make] Running simulation and attempting to open waveform"
	$(VVP) $(SIMV) | tee $(BUILD)/sim_$(BITS).out
	@if [ -f "$(VCD)" ]; then \
		if command -v $(GTKWAVE) >/dev/null 2>&1; then \
			$(GTKWAVE) $(VCD); \
		else \
			echo "[make] gtkwave not found — VCD available at $(VCD)"; \
		fi \
	else \
		echo "[make] No VCD found at $(VCD). Ensure your testbench writes $$(VCD) via $$(dumpfile) / $$(dumpvars)."; \
	fi

clean:
	@echo "[make] Cleaning build artifacts"
	@rm -rf $(BUILD)

help:
	@echo "Makefile targets:"
	@echo "  make verilog BITS=<n>  : compile+run SystemVerilog testbench with N_BITS=<n>"
	@echo "  make cpp BITS=<n>      : compile+run C++ solver with BITS=<n>"
	@echo "  make wave BITS=<n>     : run verilog and open VCD with gtkwave (if present)"
	@echo "  make clean             : remove $(BUILD) directory"
	@echo "Defaults: BITS=$(BITS). Override on command line, e.g., 'make cpp BITS=512'"

