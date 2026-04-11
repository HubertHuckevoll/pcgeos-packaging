@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "VERSION_FILE=%SCRIPT_DIR%basebox\version.txt"

if not exist "%VERSION_FILE%" (
    echo Error: Basebox version file not found at "%VERSION_FILE%".
    exit /b 1
)

set /p BASEBOX_VERSION=<"%VERSION_FILE%"
set "BASEBOX_VERSION=%BASEBOX_VERSION: =%"
if "%BASEBOX_VERSION%"=="" (
    echo Error: Basebox version file is empty: "%VERSION_FILE%".
    exit /b 1
)

set "VERSION_LAUNCHER=%SCRIPT_DIR%basebox\%BASEBOX_VERSION%\ensemble.cmd"
if not exist "%VERSION_LAUNCHER%" (
    echo Error: Version launcher not found at "%VERSION_LAUNCHER%".
    exit /b 1
)

call "%VERSION_LAUNCHER%" %*
exit /b %ERRORLEVEL%
