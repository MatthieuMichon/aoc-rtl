TASK ?= all

.PHONY: all
all:
	vivado -mode batch -source vivado.tcl -tclargs TASK=$(TASK)

.PHONY: clean
clean:
	$(RM) -r .Xil/
	$(RM) vivado*.{jou,log}
	$(RM) lint.txt
