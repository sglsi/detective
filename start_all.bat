@echo off
chcp 65001 >nul
echo ==========================================
echo   维多利亚伦敦探案 - 一键启动脚本
echo ==========================================
echo.

:: 检查后端目录
if not exist "backend\src\server.js" (
    echo [错误] 未找到后端文件，请确保在项目根目录运行此脚本
    pause
    exit /b 1
)

:: 检查 Godot Web 构建目录
if not exist "godot_project\web_build\index.html" (
    echo [错误] 未找到 Godot Web 构建文件
    echo [提示] 请先导出 Godot 项目到 godot_project\web_build
    pause
    exit /b 1
)

echo [1/2] 启动后端 API 服务...
cd backend
start "Backend API" cmd /k "set PORT=3001 && set STORAGE_MODE=local && node src/server.js"
cd ..

:: 等待后端启动
timeout /t 3 /nobreak >nul

echo [2/2] 启动 Godot Web 构建服务...
start "Godot Web" cmd /k "python serve_web.py --directory godot_project/web_build"

:: 等待服务启动
timeout /t 2 /nobreak >nul

echo.
echo ==========================================
echo   服务已启动！
echo ==========================================
echo.
echo   后端 API:     http://localhost:3001
echo   Godot Web:    http://localhost:8081
echo.
echo   访问游戏:     http://localhost:8081/
echo.
echo   按任意键关闭此窗口（服务将继续运行）
echo   要停止服务，请运行 stop_all.bat
echo ==========================================
pause >nul
