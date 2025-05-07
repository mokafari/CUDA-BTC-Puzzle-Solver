@echo off
setlocal

:: Initialize Visual Studio environment
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

:: Find CUDA installation path
for /f "delims=" %%i in ('where nvcc 2^>nul') do (
    set "NVCC_PATH=%%i"
    goto :found_nvcc
)
echo CUDA toolkit not found in PATH. Please install CUDA toolkit and add it to PATH.
exit /b 1

:found_nvcc
for %%i in ("%NVCC_PATH%") do set "CUDA_PATH=%%~dpi.."

:: Set Visual Studio paths
set "MSVC_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.38.33130"
set "WIN_SDK_PATH=C:\Program Files (x86)\Windows Kits\10"

:: Set include paths
set "INCLUDES=/I"%CUDA_PATH%\include" /I"%MSVC_PATH%\include" /I"%WIN_SDK_PATH%\Include\10.0.22621.0\ucrt""

:: Set library paths
set "LIB_PATHS=/LIBPATH:"%CUDA_PATH%\lib\x64" /LIBPATH:"%MSVC_PATH%\lib\x64" /LIBPATH:"%WIN_SDK_PATH%\Lib\10.0.22621.0\ucrt\x64" /LIBPATH:"%WIN_SDK_PATH%\Lib\10.0.22621.0\um\x64""

:: Create build directory if it doesn't exist
if not exist build mkdir build

:: Compile CUDA files
echo Compiling CUDA files...
echo Using CUDA path: %CUDA_PATH%

:: Compile SHA256
"%CUDA_PATH%\bin\nvcc" -o build\sha256_cuda.obj -c src\sha256_cuda.cu -arch=sm_75 -Xcompiler "/MD" -I src
if errorlevel 1 goto error

:: Compile RIPEMD160
"%CUDA_PATH%\bin\nvcc" -o build\ripemd160_cuda.obj -c src\ripemd160_cuda.cu -arch=sm_75 -Xcompiler "/MD" -I src
if errorlevel 1 goto error

:: Compile address generation
"%CUDA_PATH%\bin\nvcc" -o build\address_optimized.obj -c src\address_optimized.cu -arch=sm_75 -Xcompiler "/MD" -I src
if errorlevel 1 goto error

:: Compile main kernel
"%CUDA_PATH%\bin\nvcc" -o build\kernel.obj -c src\kernel.cu -arch=sm_75 -Xcompiler "/MD" -I src
if errorlevel 1 goto error

:: Compile test suite
echo Compiling test suite...
"%CUDA_PATH%\bin\nvcc" -o build\test_bitcoin_ops.obj -c tests\test_bitcoin_ops.cu -arch=sm_75 -Xcompiler "/MD" -I src
if errorlevel 1 goto error

:: Link objects into executables
echo Linking...
"%CUDA_PATH%\bin\nvcc" -o build\bitcoin_puzzle.exe build\kernel.obj build\sha256_cuda.obj build\ripemd160_cuda.obj build\address_optimized.obj -arch=sm_75 -lcudart
if errorlevel 1 goto error

"%CUDA_PATH%\bin\nvcc" -o build\test_bitcoin_ops.exe build\test_bitcoin_ops.obj build\sha256_cuda.obj build\ripemd160_cuda.obj build\address_optimized.obj -arch=sm_75 -lcudart
if errorlevel 1 goto error

echo Build completed successfully.
echo Running tests...
build\test_bitcoin_ops.exe
goto end

:error
echo Build failed with error %errorlevel%
exit /b %errorlevel%

:end
endlocal
