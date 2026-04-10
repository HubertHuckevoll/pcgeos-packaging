@echo off
setlocal
set SCRIPT_DIR=%~dp0
set BASEBOX_DIR=%SCRIPT_DIR%basebox\10
set BASEBOX_EXEC=%BASEBOX_DIR%\binnt\basebox.exe
set USER_CONFIG_FILE=%SCRIPT_DIR%basebox.conf

if not exist "%BASEBOX_EXEC%" (
    echo Error: Expected Basebox executable not found at "%BASEBOX_EXEC%".
    exit /b 1
)

pushd "%SCRIPT_DIR%" >nul
if errorlevel 1 (
    echo Error: Could not change to launcher directory "%SCRIPT_DIR%".
    exit /b 1
)

"%BASEBOX_EXEC%" -noprimaryconf -nolocalconf -conf "%USER_CONFIG_FILE%" %*
set EXIT_CODE=%ERRORLEVEL%
popd >nul
exit /b %EXIT_CODE%
