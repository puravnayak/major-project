@echo off
REM ============================================================================
REM Icarus Verilog Quick Simulation Runner for SHA-256 v5.0 16-Core Mega-Array
REM ============================================================================

echo [SIM] Compiling Verilog RTL and Testbench for v5.0 16-Core...
iverilog -g2001 -o tb_sha256_v5.vvp ../src/*.v ../tb/tb_sha256_16core.v

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [SIM] Running simulation...
vvp tb_sha256_v5.vvp

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation execution failed!
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] Simulation completed successfully!
