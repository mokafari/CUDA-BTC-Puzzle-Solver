@echo off
setlocal

echo === Running Bitcoin Puzzle Solver ===

REM Set path to executable
set PUZZLE_SOLVER=c:\Users\GustavLiljesten\CUDA_PUZZLE_BREAK\build\puzzle_solver.exe

REM Check for test mode
if "%1"=="--test" (
    echo Running in test mode...
    "%PUZZLE_SOLVER%" --test
    goto :eof
)

REM Run the puzzle solver with parameters - increased range to 0x100000000 (4 billion keys)
"%PUZZLE_SOLVER%" 0x0 0x100000000 1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH

endlocal
