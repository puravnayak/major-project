@echo off
REM ============================================================================
REM Vivado Automation Batch Runner for SHA-256 v3.0 High-Throughput
REM ============================================================================

set VIVADO_CMD=vivado
where vivado >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    if exist "C:\Xilinx\Vivado\2024.2\bin\vivado.bat" (
        set VIVADO_CMD="C:\Xilinx\Vivado\2024.2\bin\vivado.bat"
    ) else if exist "C:\Xilinx\Vivado\2024.1\bin\vivado.bat" (
        set VIVADO_CMD="C:\Xilinx\Vivado\2024.1\bin\vivado.bat"
    )
)

echo [VIVADO] Launching Vivado Synthesis, Simulation, and PPA Extraction for v3.0 High-Throughput...
call %VIVADO_CMD% -mode batch -source run_synth.tcl

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Vivado flow failed with error code %ERRORLEVEL%!
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] Flow completed! Check reports in ..\reports\
