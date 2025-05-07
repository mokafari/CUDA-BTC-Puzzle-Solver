@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cd /d %~dp0\..

set CUDA_SOURCES=src/benchmark.cu src/point_ops_new.cu src/uint256_ops.cu src/secp256k1_params.cu src/address_optimized.cu src/precompute.cu src/distinguished_points.cu src/sha256_cuda.cu src/ripemd-160cuda-main/ripemd160_cuda.cu
set NVCC_FLAGS=-I src -I src/ripemd-160cuda-main -arch=sm_52 -rdc=true -lineinfo -Xcompiler "/MD"
set CUDA_LIBS=-lcudart

nvcc %NVCC_FLAGS% -o benchmark.exe %CUDA_SOURCES% %CUDA_LIBS%
