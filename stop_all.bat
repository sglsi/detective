@echo off
echo ==========================================
echo   Sherlock Holmes - Stop All Services
echo ==========================================
echo.

echo Stopping Backend API...
taskkill /FI "WINDOWTITLE eq Backend API*" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq node.exe" /FI "WINDOWTITLE eq *server.js*" /T /F >nul 2>&1

echo Stopping Godot Web...
taskkill /FI "WINDOWTITLE eq Godot Web*" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq *serve_web.py*" /T /F >nul 2>&1

echo.
echo ==========================================
echo   All services stopped
echo ==========================================
pause
