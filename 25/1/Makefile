GIT_COMMIT_SHORT := $(shell git rev-parse --short=8 HEAD)
SV_SOURCES := $(filter-out shell.sv, $(wildcard *.sv))
CPP_SOURCES := $(wildcard *.cpp)
VTR_FLAGS := -Wall -j 0 --sv --cc --exe --build --trace-fst --timing --timescale 1ns/1ns --Wno-fatal --top user_logic_tb
VVD_MODE ?= batch
VVD_FLAGS := -notrace -nojournal -mode $(VVD_MODE) -script ../vivado.tcl
TASK ?= all
INPUT_FILE ?= input.txt

.PHONY: all
all:
	mkdir -p vvd_dir
	cd vvd_dir && vivado $(VVD_FLAGS) -tclargs GIT_COMMIT=$(GIT_COMMIT_SHORT) TASK=$(TASK) INPUT=$(INPUT)

.PHONY: sim
sim:
	verilator $(VTR_FLAGS) $(SV_SOURCES) $(CPP_SOURCES)
	obj_dir/Vuser_logic_tb +INPUT_FILE=$(INPUT_FILE)

.PHONY: clean
clean:
	$(RM) -r .Xil vvd_dir
	$(RM) -r obj_dir
	$(RM) wave.fst
