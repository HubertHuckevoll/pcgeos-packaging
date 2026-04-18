@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
if "%BASEBOX_VERSION%"=="" set "BASEBOX_VERSION={{BASEBOX_VERSION}}"

set "ARCH=%PROCESSOR_ARCHITECTURE%"
if defined PROCESSOR_ARCHITEW6432 set "ARCH=%PROCESSOR_ARCHITEW6432%"

set "BASEBOX_BIN_DIR=binnt"
if /I "%ARCH%"=="AMD64" set "BASEBOX_BIN_DIR=binnt64"
if /I "%ARCH%"=="IA64" set "BASEBOX_BIN_DIR=binnt64"
if /I "%ARCH%"=="ARM64" set "BASEBOX_BIN_DIR=binnt64"

for %%I in ("%SCRIPT_DIR%.") do set "ENSEMBLE_DIR=%%~fI"
set "BASEBOX_EXEC=%ENSEMBLE_DIR%\basebox\%BASEBOX_VERSION%\%BASEBOX_BIN_DIR%\basebox.exe"
set "USER_CONFIG_FILE=%ENSEMBLE_DIR%\basebox.conf"
set "LOG_FILE=%ENSEMBLE_DIR%\ensemble.log"
> "%LOG_FILE%" echo [%DATE% %TIME%] start: %~nx0 %*
>> "%LOG_FILE%" echo basebox: "%BASEBOX_EXEC%"

if not exist "%BASEBOX_EXEC%" (
    >> "%LOG_FILE%" echo error: missing executable "%BASEBOX_EXEC%"
    echo Error: Expected Basebox executable not found at "%BASEBOX_EXEC%".
    exit /b 1
)

pushd "%ENSEMBLE_DIR%" >nul
if errorlevel 1 (
    >> "%LOG_FILE%" echo error: could not change to launcher directory "%ENSEMBLE_DIR%"
    echo Error: Could not change to launcher directory "%ENSEMBLE_DIR%".
    exit /b 1
)

>> "%LOG_FILE%" echo launch: request submitted
"%BASEBOX_EXEC%" -noconsole -noprimaryconf -nolocalconf -conf "%USER_CONFIG_FILE%" %* >> "%LOG_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"
>> "%LOG_FILE%" echo launcher: exit code %EXIT_CODE%
popd >nul
exit /b %EXIT_CODE%
