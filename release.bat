@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Build failed with error code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)
pause
