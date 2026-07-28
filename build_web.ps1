# 维多利亚伦敦探案 - Web 构建工具
# 使用方法：.\build_web.ps1 [-Restart]

param(
    [switch]$Restart  # 是否重启服务
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  维多利亚伦敦探案 - Web 构建工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 检查 Godot 是否安装
$godotPath = "D:\AI\godot\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe"
if (-not (Test-Path $godotPath)) {
    Write-Host "❌ Godot 未找到：$godotPath" -ForegroundColor Red
    exit 1
}

# 2. 导出 Web 版本
Write-Host "`n📦 正在导出 Web 版本..." -ForegroundColor Yellow
& $godotPath --headless --export-release "Web" "D:\AI\detective\godot_project\web_build\index.html"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 导出失败" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 导出成功" -ForegroundColor Green

# 3. 重启服务（如果需要）
if ($Restart) {
    Write-Host "`n🔄 正在重启服务..." -ForegroundColor Yellow
    
    # 停止服务
    Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*serve_web*" } | Stop-Process -Force
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*server.js*" } | Stop-Process -Force
    }
    Start-Sleep -Seconds 2
    
    # 启动后端
    $env:PORT = "3001"
    $env:STORAGE_MODE = "local"
    Start-Process -FilePath "node" -ArgumentList "src/server.js" -WorkingDirectory "D:\AI\detective\backend" -WindowStyle Normal
    
    # 启动前端
    Start-Process -FilePath "python" -ArgumentList "serve_web.py --directory godot_project/web_build" -WorkingDirectory "D:\AI\detective" -WindowStyle Normal
    
    Start-Sleep -Seconds 3
    
    Write-Host "✅ 服务已重启" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  访问地址：http://localhost:8081/" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
