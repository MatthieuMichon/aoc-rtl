GIT_COMMIT_SHORT := $(shell git rev-parse --short=8 HEAD)
#PART ?= xc7a12tcsg325-1
PART ?= xc7z020clg484-1
VVD_MODE ?= batch
VVD_FLAGS := -notrace -nojournal -mode $(VVD_MODE) -script ../vivado.tcl
VVD_TASK ?= all

SV_SOURCES := $(filter-out shell.sv, $(wildcard *.sv))
CPP_SOURCES := $(wildcard *.cpp)
VTR_FLAGS := -Wall -j 0 --assert --build --cc --exe --trace --timing --top user_logic_tb
INPUT_FILE ?= input.txt
USER_LOGIC ?= user_logic

obj_dir/Vuser_logic_tb: $(SV_SOURCES) $(CPP_SOURCES)
	verilator $(VTR_FLAGS) $(SV_SOURCES) $(CPP_SOURCES)

.PHONY: sim
sim: obj_dir/Vuser_logic_tb
	obj_dir/Vuser_logic_tb +INPUT_FILE=$(INPUT_FILE)

.PHONY: synth
synth:
	mkdir -p vvd_dir
	cd vvd_dir && vivado $(VVD_FLAGS) -tclargs PART=$(PART) GIT_COMMIT=$(GIT_COMMIT_SHORT) TASK=$(VVD_TASK) INPUT_FILE=$(INPUT_FILE)

.PHONY: clean
clean:
	$(RM) -r .Xil vvd_dir
	$(RM) -r obj_dir
	$(RM) wave.vcd
