#!/usr/bin/env bash
set -euo pipefail

# 基于脚本位置定位项目根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# 显式声明关键环境变量
export PORT=3000

# 清理 5000 端口残留进程（绝不碰 9000）
fuser -k 5000/tcp 2>/dev/null || true
sleep 1

# 启动后端 API（后台）
echo "[coze-preview-run] 启动后端 API 服务 (端口 3000)..."
cd backend
if [ ! -d "node_modules" ]; then
    pnpm install
fi
nohup node src/server.js > /tmp/coze-backend.log 2>&1 &
BACKEND_PID=$!
echo "[coze-preview-run] 后端 PID: $BACKEND_PID"
sleep 2

# 检查后端是否启动成功
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "[coze-preview-run] 后端 API 已启动"
else
    echo "[coze-preview-run] 后端可能未成功启动，检查日志: /tmp/coze-backend.log"
fi

# 回到项目根目录，启动代理服务器（支持 API 转发）
cd "$PROJECT_DIR"
echo "[coze-preview-run] 启动代理服务器 (端口 5000)..."

# 使用代理服务器，将 /api/* 请求转发到后端
exec python3 proxy_server.py --port 5000 --directory godot_project/web_build
