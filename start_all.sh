#!/bin/bash
# ==============================================
#  维多利亚伦敦探案 — 一键启动脚本
#  同时启动后端 API 和 Web 原型
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=============================================="
echo "  维多利亚伦敦探案 — 开发环境启动"
echo "=============================================="

# 启动后端 API（后台）
echo "📡 启动后端 API 服务 (端口 3000)..."
cd "$SCRIPT_DIR/backend"
if [ ! -d "node_modules" ]; then
    npm install
fi
nohup node src/server.js > /tmp/sherlock_backend.log 2>&1 &
BACKEND_PID=$!
echo "  后端 PID: $BACKEND_PID"
sleep 1

# 检查后端是否启动成功
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "  ✅ 后端 API 已启动: http://localhost:3000"
else
    echo "  ⚠️  后端可能未成功启动，检查日志: /tmp/sherlock_backend.log"
fi

# 启动 Web 原型（后台）
echo "🌐 启动 Web 原型 (端口 8080)..."
cd "$SCRIPT_DIR/web_prototype"
# 检查端口是否被占用
if lsof -ti:8080 > /dev/null 2>&1; then
    kill $(lsof -ti:8080) 2>/dev/null || true
    sleep 1
fi
nohup python3 -m http.server 8080 > /tmp/sherlock_web.log 2>&1 &
WEB_PID=$!
echo "  Web PID: $WEB_PID"
echo "  ✅ Web 原型已启动: http://localhost:8080"

echo ""
echo "=============================================="
echo "  服务已全部启动:"
echo ""
echo "  📡 后端 API:   http://localhost:3000"
echo "  🌐 Web 原型:   http://localhost:8080"
echo ""
echo "  停止所有服务:   kill $BACKEND_PID $WEB_PID"
echo "  后端日志:       tail -f /tmp/sherlock_backend.log"
echo "=============================================="

# 保存 PID 以便停止
echo "$BACKEND_PID" > /tmp/sherlock_backend.pid
echo "$WEB_PID" > /tmp/sherlock_web.pid

# 等待用户按 Ctrl+C
echo ""
echo "按 Ctrl+C 停止所有服务..."
trap "echo ''; echo '正在停止服务...'; kill $BACKEND_PID $WEB_PID 2>/dev/null; echo '已停止'; exit 0" INT
wait
