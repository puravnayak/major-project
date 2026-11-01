@echo off
REM ============================================================================
REM Icarus Verilog Quick Simulation Runner for SHA-256 v4.0 Multicore
REM ============================================================================

echo [SIM] Compiling Verilog RTL and Testbench for v4.0 Multicore...
iverilog -g2001 -o tb_sha256_v4.vvp ../src/*.v ../tb/tb_sha256_multicore.v

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [SIM] Running simulation...
vvp tb_sha256_v4.vvp

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation execution failed!
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] Simulation completed successfully!
