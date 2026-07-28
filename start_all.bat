@echo off
echo ==========================================
echo   Sherlock Holmes - Start All Services
echo ==========================================
echo.

:: Check backend directory
if not exist "backend\src\server.js" (
    echo [ERROR] Backend files not found
    echo Please run this script from project root directory
    pause
    exit /b 1
)

:: Check Godot Web build directory
if not exist "godot_project\web_build\index.html" (
    echo [ERROR] Godot Web build not found
    echo Please export Godot project to godot_project\web_build first
    pause
    exit /b 1
)

echo [1/2] Starting Backend API...
cd backend
start "Backend API" cmd /k "set PORT=3001 && set STORAGE_MODE=local && node src/server.js"
cd ..

:: Wait for backend to start
timeout /t 3 /nobreak >nul

echo [2/2] Starting Godot Web Build...
start "Godot Web" cmd /k "python serve_web.py --directory godot_project/web_build"

:: Wait for services to start
timeout /t 2 /nobreak >nul

echo.
echo ==========================================
echo   Services Started!
echo ==========================================
echo.
echo   Backend API:     http://localhost:3001
echo   Godot Web:       http://localhost:8081
echo.
echo   Play Game:       http://localhost:8081/
echo.
echo   Press any key to close this window
echo   Services will continue running
echo   To stop: run stop_all.bat
echo ==========================================
pause >nul
