SV_SOURCES := $(filter-out shell.sv, $(wildcard *.sv))
CPP_SOURCES := $(wildcard *.cpp)
VTR_FLAGS := -Wall -j 0 --sv --cc --exe --build --trace --timing --Wno-fatal --top user_logic_tb
INPUT_FILE ?= input.txt
USER_LOGIC ?= user_logic

obj_dir/Vuser_logic_tb: $(SV_SOURCES) $(CPP_SOURCES)
	verilator $(VTR_FLAGS) $(SV_SOURCES) $(CPP_SOURCES) -DUSER_LOGIC_DEF=$(USER_LOGIC)

.PHONY: sim
sim: obj_dir/Vuser_logic_tb
	obj_dir/Vuser_logic_tb +INPUT_FILE=$(INPUT_FILE)

.PHONY: clean
clean:
	$(RM) -r .Xil vvd_dir
	$(RM) -r obj_dir
	$(RM) wave.vcd
