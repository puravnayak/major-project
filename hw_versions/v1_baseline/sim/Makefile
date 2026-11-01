# ============================================================================
# Makefile for SHA-256 v1.0 Baseline Simulation
# ============================================================================

SIM_EXE = sim_sha256.vvp
VCD_FILE = tb_sha256.vcd

SRC = ../src/sha256_top.v \
      ../src/sha256_datapath.v \
      ../src/sha256_w_schedule.v \
      ../src/sha256_k_rom.v

TB = ../tb/tb_sha256.v

ifeq ($(OS),Windows_NT)
    RM = del /Q /F
    SIM_EXE_RUN = sim\$(SIM_EXE)
else
    RM = rm -f
    SIM_EXE_RUN = sim/$(SIM_EXE)
endif

all: compile run

compile: $(SIM_EXE)

$(SIM_EXE): $(TB) $(SRC)
	iverilog -o $@ -s tb_sha256 $^

run: $(SIM_EXE)
	cd .. && vvp $(SIM_EXE_RUN)

clean:
	-$(RM) $(SIM_EXE) $(VCD_FILE) ..\$(VCD_FILE)
