@echo off
echo Organizing project structure...

REM Move source files
move ..\*.cu ..\src\
move ..\*.cpp ..\src\

REM Move header files
move ..\*.h ..\include\

REM Move documentation
move ..\*.md ..\docs\
move ..\readme.txt ..\docs\
move ..\prompts.txt ..\docs\

REM Move build artifacts
move ..\*.o ..\build\
move ..\*.lib ..\build\
move ..\*.ptx ..\build\
move ..\*.json ..\build\

REM Move logs
move ..\*.log ..\logs\

REM Move scripts
move ..\*.bat ..\scripts\
move organize.bat ..\

REM Clean up empty directories
rd /s /q ..\OLD
rd /s /q ..\OLD_BAK
rd /s /q ..\__pycache__

echo Project structure organized!
pause
