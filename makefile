# Makefile for Questa Sim simulator

# Compiler and simulator settings
VLOG = vlog
VSIM = vsim
VLOG_FLAGS = -sv 						# +define+DEBUG_ON
VSIM_FLAGS = -c             #-voptargs=+acc


# Source files
SRC_FILE = mips2_interface_version.sv top.sv interface.sv

# Makefile targets
all: compile simulate

compile:
	$(VLOG) $(VLOG_FLAGS) $(SRC_FILE)

simulate:
	$(VSIM) $(VSIM_FLAGS) +MODE=$(mode) +INPUT=$(input_file) top -do "run -all; quit"

#clean:
#	rm -rf work transcript *.log vsim.wlf $(OUTPUT_FILE)

#.PHONY: all compile simulate clean