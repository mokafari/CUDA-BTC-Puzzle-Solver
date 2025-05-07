@echo off
cd /d %~dp0\..

echo Running component test suite...
build\test_suite.exe
if errorlevel 1 (
    echo Component tests failed!
    exit /b 1
)

echo.
echo Running performance tests...
build\perf_test.exe
if errorlevel 1 (
    echo Performance tests failed!
    exit /b 1
)

echo.
echo All tests completed successfully!
exit /b 0
