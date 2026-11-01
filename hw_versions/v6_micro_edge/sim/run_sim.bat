@echo off
REM ============================================================================
REM Icarus Verilog Quick Simulation Runner for SHA-256 v6.0 Micro-Edge
REM ============================================================================

echo [SIM] Compiling Verilog RTL and Testbench for v6.0 Micro-Edge...
iverilog -g2001 -o tb_sha256_v6.vvp ../src/*.v ../tb/tb_sha256_8bit.v

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo [SIM] Running simulation...
vvp tb_sha256_v6.vvp

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation execution failed!
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] Simulation completed successfully!
