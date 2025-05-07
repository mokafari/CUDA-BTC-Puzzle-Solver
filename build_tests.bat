@echo off
set VS2022_PATH="C:\Program Files\Microsoft Visual Studio\2022\Community"
if exist %VS2022_PATH% (
    call %VS2022_PATH%\VC\Auxiliary\Build\vcvars64.bat
) else (
    echo Visual Studio 2022 not found at %VS2022_PATH%
    exit /b 1
)

nvcc -o bitcoin_tests tests/test_bitcoin_ops.cu tests/test_kernels.cu -I src -arch=sm_75
if %ERRORLEVEL% NEQ 0 (
    echo Build failed with error %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Build successful!
bitcoin_tests.exe
