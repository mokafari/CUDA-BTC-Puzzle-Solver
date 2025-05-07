@echo off
cd /d "%~dp0"
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

rem First compile all source files into object files
nvcc -c src/secp256k1_params.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math
nvcc -c src/uint256_ops.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math
nvcc -c src/point_ops_optimized.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math
nvcc -c src/warp_ops.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math
nvcc -c src/address_optimized.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math
nvcc -c src/benchmark.cu -I. -Iinclude -arch=sm_89 -O3 --use_fast_math

rem Then link all object files into the final executable
nvcc -o benchmark.exe secp256k1_params.obj uint256_ops.obj point_ops_optimized.obj warp_ops.obj address_optimized.obj benchmark.obj -arch=sm_89

if %ERRORLEVEL% EQU 0 (
    echo Compilation successful. Running benchmark...
    benchmark.exe
) else (
    echo Compilation failed with error code %ERRORLEVEL%
)
