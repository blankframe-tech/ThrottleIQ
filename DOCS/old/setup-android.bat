@echo off
REM ThrottleIQ Android Setup - Run as Administrator
REM This batch file launches the PowerShell setup script

setlocal enabledelayedexpansion

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)

echo ========================================
echo ThrottleIQ Android Setup
echo ========================================
echo.

REM Run the PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-android.ps1"

pause
