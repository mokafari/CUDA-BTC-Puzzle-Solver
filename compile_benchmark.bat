@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
nvcc -o benchmark src/benchmark.cu src/uint256_ops.cu src/point_ops_optimized.cu src/address_optimized.cu -I src -arch=sm_75
if %ERRORLEVEL% EQU 0 (
    echo Compilation successful. Running benchmark...
    benchmark.exe
) else (
    echo Compilation failed with error code %ERRORLEVEL%
)
