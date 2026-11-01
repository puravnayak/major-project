@echo off
REM ============================================================================
REM SHA-256 v1.0 Baseline Simulation Script
REM ============================================================================

echo [SIM] Compiling SHA-256 v1.0 RTL and Testbench with Icarus Verilog...
iverilog -o sim_sha256.vvp -s tb_sha256 ..\tb\tb_sha256.v ..\src\sha256_top.v ..\src\sha256_datapath.v ..\src\sha256_w_schedule.v ..\src\sha256_k_rom.v

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Verilog compilation failed!
    exit /b %ERRORLEVEL%
)

echo [SIM] Running simulation...
pushd ..
vvp sim\sim_sha256.vvp
popd
