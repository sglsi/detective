@echo off
chcp 65001 >nul
echo ==========================================
echo   维多利亚伦敦探案 - 停止所有服务
echo ==========================================
echo.

echo 正在停止后端 API 服务...
taskkill /FI "WINDOWTITLE eq Backend API*" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq node.exe" /FI "WINDOWTITLE eq *server.js*" /T /F >nul 2>&1

echo 正在停止 Godot Web 服务...
taskkill /FI "WINDOWTITLE eq Godot Web*" /T /F >nul 2>&1
taskkill /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq *serve_web.py*" /T /F >nul 2>&1

echo.
echo ==========================================
echo   所有服务已停止
echo ==========================================
pause
