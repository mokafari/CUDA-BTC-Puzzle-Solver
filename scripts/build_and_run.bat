@echo off
cd /d "%~dp0"
cd ..

rem Initialize default values
set BUILD_TYPE=Release
set RUN_TESTS=0
set RUN_BENCHMARK=0
set VERBOSE=0
set TARGET_ADDRESS=
set KEY_RANGE=

rem Parse command line arguments
:parse_args
if "%1"=="" goto end_parse
if /i "%1"=="--debug" set BUILD_TYPE=Debug
if /i "%1"=="--release" set BUILD_TYPE=Release
if /i "%1"=="--test" set RUN_TESTS=1
if /i "%1"=="--benchmark" set RUN_BENCHMARK=1
if /i "%1"=="--verbose" set VERBOSE=1
if /i "%1"=="--target" (
    set TARGET_ADDRESS=%2
    shift
)
if /i "%1"=="--range" (
    set KEY_RANGE=%2
    shift
)
shift
goto parse_args
:end_parse

rem Build the project
call scripts\build.bat --build-type %BUILD_TYPE% %RUN_TESTS% %RUN_BENCHMARK% %VERBOSE%
if errorlevel 1 (
    echo Build failed
    exit /b %errorlevel%
)

rem Run the executable with appropriate flags
set ARGS=
if defined TARGET_ADDRESS set ARGS=%ARGS% --target %TARGET_ADDRESS%
if defined KEY_RANGE set ARGS=%ARGS% --range %KEY_RANGE%
if "%VERBOSE%"=="1" set ARGS=%ARGS% --verbose

echo Running puzzle_break.exe with arguments: %ARGS%
puzzle_break.exe %ARGS%
