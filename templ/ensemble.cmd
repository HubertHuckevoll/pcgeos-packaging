@echo off
setlocal
rem Top-level dispatcher: this bundle is pinned to one basebox version.
set "BASEBOX_VERSION={{BASEBOX_VERSION}}"
set "SCRIPT_DIR=%~dp0"

call "%SCRIPT_DIR%basebox\%BASEBOX_VERSION%\ensemble.cmd" %*
exit /b %ERRORLEVEL%
