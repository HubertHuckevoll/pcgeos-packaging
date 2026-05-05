@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%ensemble.ps1"

if not exist "%PS1_FILE%" (
    echo Error: Missing PowerShell launcher at "%PS1_FILE%".
    exit /b 1
)

start "" powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS1_FILE%" %*
exit /b 0
