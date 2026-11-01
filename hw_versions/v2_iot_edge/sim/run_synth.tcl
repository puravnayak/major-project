# ==============================================================================
# Vivado Automation & PPA Extraction TCL Script
# ==============================================================================
# Target: Xilinx Vivado (Batch Mode)
# Execution: vivado -mode batch -source run_synth.tcl
# Working Directory: hw_versions/v2_iot_edge/sim/
# Architecture: v2.0 IoT Edge (16-word On-the-Fly Sliding Window Scheduler)
#
# Flow Overview:
# 1. Project Creation & Device Targeting (xc7z020clg400-1, PYNQ-Z2)
# 2. Source Ingestion (read_verilog for ../src/*.v and ../tb/*.v)
# 3. Timing Constraints (Clock period constraint on clk port)
# 4. Behavioral Simulation & Switching Activity Extraction (xsim SAIF logging)
# 5. Out-of-Context Synthesis (sha256_top)
# 6. Post-Synthesis Reports (Utilization & Timing)
# 7. SAIF Annotation & Switching-Accurate Power Reporting (report_power)
# 8. Clean Reporting into ../reports/
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Environment & Parameter Setup
# ------------------------------------------------------------------------------
set BOARD_NAME      "PYNQ-Z2"
set BOARD_PART      "tul.com.tw:pynq-z2:part0:1.0"
set PART            "xc7z020clg400-1"   ;# Zynq-7000 SoC on PYNQ-Z2
set TOP_MODULE      "sha256_top"
set TB_MODULE       "tb_sha256"
set CLK_PERIOD      70.000             ;# ~14.28MHz clock (70.0ns period)
set PROJ_NAME       "sha256_v2_iot_edge"
set PROJ_DIR        "./vivado_project"
set REPORTS_DIR     "../reports"
set SAIF_FILE       "v2_activity.saif"

puts "========================================================================"
puts " \[Vivado Flow\] SHA-256 Accelerator v2.0 IoT Edge Synthesis & PPA Analysis"
puts " Target Board       : ${BOARD_NAME}"
puts " Target FPGA Device : ${PART}"
puts " Target Frequency   : [format "%.2f" [expr {1000.0 / $CLK_PERIOD}]] MHz (Period: ${CLK_PERIOD} ns)"
puts " Top Module         : ${TOP_MODULE}"
puts " Testbench Module   : ${TB_MODULE}"
puts " Output Directory   : ${REPORTS_DIR}"
puts "========================================================================"

# Create reports directory if it doesn't already exist
file mkdir $REPORTS_DIR

# Create or open physical Vivado project targeting the PYNQ-Z2 FPGA
if {![file exists "${PROJ_DIR}/${PROJ_NAME}.xpr"]} {
    create_project -force $PROJ_NAME $PROJ_DIR -part $PART
} else {
    open_project "${PROJ_DIR}/${PROJ_NAME}.xpr"
}

# Set board part property if PYNQ-Z2 board files are installed in Vivado
if {[catch {set_property board_part $BOARD_PART [current_project]}]} {
    puts "\[INFO\] PYNQ-Z2 board definition (${BOARD_PART}) not present in Vivado repository."
    puts "       Targeting FPGA part ${PART} directly for synthesis and PPA."
} else {
    puts "\[INFO\] Successfully targeted PYNQ-Z2 board (${BOARD_PART})."
}

# ------------------------------------------------------------------------------
# 2. Source File Ingestion using Relative Paths (read_verilog)
# ------------------------------------------------------------------------------
puts "\n\[INFO\] Ingesting Verilog source and testbench files via read_verilog..."

# Read synthesizable RTL files from ../src/
set src_files [glob -nocomplain "../src/*.v"]
if {[llength $src_files] == 0} {
    puts "\[ERROR\] No Verilog RTL files found in ../src/!"
    exit 1
}
read_verilog $src_files
puts "  -> Added [llength $src_files] RTL source file(s) from ../src/"

# Read testbench files from ../tb/
set tb_files [glob -nocomplain "../tb/*.v"]
if {[llength $tb_files] == 0} {
    puts "\[ERROR\] No Verilog testbench files found in ../tb/!"
    exit 1
}
read_verilog $tb_files
puts "  -> Added [llength $tb_files] testbench file(s) from ../tb/"

# Set top-level module properties
set_property top $TOP_MODULE [current_fileset]
set_property top $TB_MODULE [get_filesets sim_1]

# Ensure compile order is updated
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# ------------------------------------------------------------------------------
# 3. Apply Clock Constraints (XDC & In-Memory Timing)
# ------------------------------------------------------------------------------
puts "\n\[INFO\] Generating and applying clock constraint (${CLK_PERIOD}ns period)..."
set xdc_file "${PROJ_DIR}/timing_constraints.xdc"
set fp [open $xdc_file w]
puts $fp "create_clock -period ${CLK_PERIOD} -name clk -waveform {0.000 [expr {$CLK_PERIOD / 2.0}]} \[get_ports clk\]"
close $fp
read_xdc $xdc_file

# ------------------------------------------------------------------------------
# 4. Switching Activity Extraction (xsim Simulation & SAIF Logging)
# ------------------------------------------------------------------------------
puts "\n\[INFO\] Launching xsim simulation to record switching activity (.saif)..."

# Ensure test vector files from golden_model/ are copied to all potential xsim directories
set golden_src_dir [file normalize "../../../golden_model"]
if {![file exists $golden_src_dir]} {
    set golden_src_dir [file normalize "../../golden_model"]
}
set txt_files [glob -nocomplain "${golden_src_dir}/*.txt"]
puts "  -> Found [llength $txt_files] test vector file(s) in: ${golden_src_dir}"

set xsim_dir "${PROJ_DIR}/${PROJ_NAME}.sim/sim_1/behav/xsim"
set sim_copy_dirs [list \
    "${PROJ_DIR}/${PROJ_NAME}.sim/sim_1/golden_model" \
    "${PROJ_DIR}/${PROJ_NAME}.sim/golden_model" \
    "${PROJ_DIR}/golden_model" \
    "./golden_model" \
    "${xsim_dir}" \
    "${xsim_dir}/golden_model" \
    "../golden_model" \
    "../../golden_model" \
]

foreach dir $sim_copy_dirs {
    file mkdir $dir
    foreach f $txt_files {
        file copy -force $f $dir
    }
}

# Stop at time 0 to initialize SAIF logging before test vectors are simulated
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

# Launch behavioral simulation session
launch_simulation -mode behavioral -simset sim_1

# Open SAIF file for activity recording
puts "\n\[INFO\] Initializing SAIF activity logging on /${TB_MODULE}/u_dut..."
open_saif $SAIF_FILE

# Log switching activity recursively on the DUT instance
log_saif [get_objects -r /${TB_MODULE}/u_dut/*]

# Run simulation testbench to completion (processes test vectors)
puts "\n\[INFO\] Running simulation vectors to completion..."
run all

# Finalize and close the SAIF activity file
close_saif
puts "  \[SAIF\] Switching activity successfully dumped to: ${SAIF_FILE}"

# Close the simulation session
close_sim

# ------------------------------------------------------------------------------
# 5. RTL Synthesis / Checkpoint Recovery (Out-Of-Context Mode)
# ------------------------------------------------------------------------------
set dcp_file "${PROJ_DIR}/post_synth.dcp"
if {[file exists $dcp_file]} {
    puts "\n\[INFO\] Found existing post-synthesis checkpoint. Opening ${dcp_file}..."
    open_checkpoint $dcp_file

    # Re-apply clock constraint to the active checkpoint
    create_clock -period $CLK_PERIOD -name clk -waveform [list 0.000 [expr {$CLK_PERIOD / 2.0}]] [get_ports clk]
} else {
    puts "\n\[INFO\] Running Out-of-Context Synthesis for ${TOP_MODULE}..."
    synth_design -top $TOP_MODULE -part $PART -mode out_of_context

    # Re-affirm clock constraint on the synthesized netlist
    create_clock -period $CLK_PERIOD -name clk -waveform [list 0.000 [expr {$CLK_PERIOD / 2.0}]] [get_ports clk]

    # Save post-synthesis design checkpoint for robust state recovery
    write_checkpoint -force $dcp_file
}

puts "\n\[INFO\] Synthesis design active in memory."

# ------------------------------------------------------------------------------
# 6. Generate Area (Utilization) & Timing (WNS / Fmax) Reports
# ------------------------------------------------------------------------------
puts "\n\[INFO\] Generating Post-Synthesis Utilization & Timing Reports..."

# 1. Utilization Report (Slice LUTs, Registers, BRAMs, DSPs)
set util_rpt "${REPORTS_DIR}/post_synth_utilization.rpt"
report_utilization -file $util_rpt
puts "  \[REPORT\] Utilization report generated: ${util_rpt}"

# 2. Timing Summary Report (Worst Negative Slack, Setup/Hold paths)
set timing_rpt "${REPORTS_DIR}/post_synth_timing.rpt"
report_timing_summary -delay_type min_max \
                      -report_unconstrained \
                      -check_timing_verbose \
                      -max_paths 10 \
                      -input_pins \
                      -routable_nets \
                      -file $timing_rpt
puts "  \[REPORT\] Timing summary report generated: ${timing_rpt}"

# ------------------------------------------------------------------------------
# 7. Apply SAIF Switching Activity & Report Accurate Power
# ------------------------------------------------------------------------------
puts "\n\[INFO\] Reading SAIF activity back into synthesized design..."

# Resolve SAIF file path
set saif_target $SAIF_FILE
if {![file exists $saif_target]} {
    if {[file exists "${xsim_dir}/${SAIF_FILE}"]} {
        set saif_target "${xsim_dir}/${SAIF_FILE}"
    } elseif {[file exists "${PROJ_DIR}/${SAIF_FILE}"]} {
        set saif_target "${PROJ_DIR}/${SAIF_FILE}"
    }
}
puts "  \[SAIF\] Applying activity file from: ${saif_target}"

# Apply switching activity directly to the synthesized netlist
read_saif -strip_path "${TB_MODULE}/u_dut" $saif_target

# Generate final post-synthesis switching-accurate power report
set power_rpt "${REPORTS_DIR}/post_synth_power.rpt"
puts "\n\[INFO\] Generating Post-Synthesis Power Report based on actual toggle rates..."
report_power -file $power_rpt
puts "  \[REPORT\] Power report generated: ${power_rpt}"

# ------------------------------------------------------------------------------
# 8. Execution Summary
# ------------------------------------------------------------------------------
puts "\n========================================================================"
puts " Vivado Automation Flow Completed Successfully!"
puts " Output Reports Generated in: ${REPORTS_DIR}/"
puts "   - Area/Utilization : ${util_rpt}"
puts "   - Timing Analysis  : ${timing_rpt}"
puts "   - Switching Power  : ${power_rpt}"
puts " Activity File        : ${saif_target}"
puts "========================================================================"

exit
