INPUT_FILE ?= input.txt
PART ?= xc7z020clg484-1
VIVADO_MODE ?= batch
VIVADO_TASK ?= all
TB ?= user_logic_tb

IS_REUSE_BUILD_TASK := $(filter $(VIVADO_TASK),program run)
TIMESTAMP := $(shell date -u +"%y%m%dT%H%M%SZ")
GIT_COMMIT_SHORT := $(shell git rev-parse --short=8 HEAD)
CPP_SOURCES := $(wildcard *.cpp)
SV_SOURCES := $(filter-out shell.sv, $(wildcard *.sv))

IVERILOG_BUILD_DIR := sim_iverilog__$(GIT_COMMIT_SHORT)
IVERILOG_FLAGS := -g2012 -Wall

VERILATOR_BUILD_DIR := sim_verilator__$(GIT_COMMIT_SHORT)
VERILATOR_FLAGS := --binary --trace -j 0 -Wall --Mdir $(VERILATOR_BUILD_DIR)

XSIM_BUILD_DIR := sim_xsim__$(GIT_COMMIT_SHORT)
XSIM_FLAGS := -sv

ifeq ($(IS_REUSE_BUILD_TASK),)
	VIVADO_BUILD_DIR := synth__$(TIMESTAMP)__$(GIT_COMMIT_SHORT)
else
	VIVADO_BUILD_DIR := $(shell ls -dt synth__* 2>/dev/null | head -n 1)
endif
VIVADO_FLAGS := -notrace -nojournal -mode $(VIVADO_MODE) -script ../vivado.tcl

all: synth_vivado sim_verilator sim_iverilog

.PHONY: synth_vivado
synth_vivado:
ifeq ($(IS_HW_TASK),)
	mkdir -p $(VIVADO_BUILD_DIR)
else
	@if [ -z "$(VIVADO_BUILD_DIR)" ]; then \
		echo "Error: No existing build directory found for $(VIVADO_TASK)!"; exit 1; \
	fi
	@echo "Using existing build directory: $(VIVADO_BUILD_DIR)"endif
endif
	cd $(VIVADO_BUILD_DIR) && vivado $(VIVADO_FLAGS) \
	    -tclargs PART=$(PART) GIT_COMMIT=$(GIT_COMMIT_SHORT) \
		TASK=$(VIVADO_TASK) INPUT_FILE=$(INPUT_FILE)

.PHONY: sim_verilator
sim_verilator: $(VERILATOR_BUILD_DIR)/V$(TB)
	$< +INPUT_FILE=$(INPUT_FILE)

$(VERILATOR_BUILD_DIR)/V$(TB): $(SV_SOURCES)
	verilator $(VERILATOR_FLAGS) $(SV_SOURCES) --top-module $(TB)

.PHONY: sim_iverilog
sim_iverilog: $(IVERILOG_BUILD_DIR)
$(IVERILOG_BUILD_DIR): $(SV_SOURCES)
	mkdir -p $@
	iverilog -o $@/a.out $(IVERILOG_FLAGS) $(SV_SOURCES)
	$@/a.out +INPUT_FILE=$(INPUT_FILE)

.PHONY: sim_xsim
sim_xsim: $(XSIM_BUILD_DIR)
$(XSIM_BUILD_DIR): $(SV_SOURCES)
	mkdir -p $@
	cd $@ && \
    	xvlog --nolog -sv $(addprefix ../, $^) && \
    	xelab --nolog $(TB) -debug wave -snapshot $(TB) && \
    	xsim -nolog $(TB) -testplusarg INPUT_FILE=../$(INPUT_FILE) -R && \
     	mv wave.vcd ../

.PHONY: clean
clean:
	$(RM) -r synth__* sim_* __pycache__
	$(RM) a.out wave.vcd *.jou *.wdb *.pb
