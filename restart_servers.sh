#!/bin/bash
# ==============================================
#  维多利亚伦敦探案 — 重启开发服务器
#  用途：电脑重启后，手动运行本脚本恢复三个服务。
#  启动：后端 API(3001) + 代理网页原型(8080) + Godot Web(8081)
# ==============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="python3"
NODE="node"

# 释放已占用端口（避免 Address already in use）
free_port() {
  local port="$1"
  local pid
  pid=$(netstat -ano 2>/dev/null | grep -E "[:.]$port " | awk '{print $5}' | head -1)
  if [ -n "$pid" ] && [ "$pid" != "0" ]; then
    echo "  🔧 释放端口 $port (PID $pid)..."
    taskkill //F //PID "$pid" >/dev/null 2>&1 || true
    sleep 1
  fi
}
free_port 3001
free_port 8080
free_port 8081

echo "▶ 启动后端 API (端口 3001)..."
cd "$SCRIPT_DIR/backend"
nohup "$NODE" src/server.js > /tmp/detective_backend.log 2>&1 &
echo $! > /tmp/detective_backend.pid

echo "▶ 启动代理网页原型 (端口 8080)..."
cd "$SCRIPT_DIR"
nohup "$PYTHON" proxy_server.py --port 8080 --directory web_prototype > /tmp/detective_web.log 2>&1 &
echo $! > /tmp/detective_web.pid

echo "▶ 启动 Godot Web (端口 8081)..."
nohup "$PYTHON" serve_web.py --port 8081 --directory godot_project/web_build > /tmp/detective_godot.log 2>&1 &
echo $! > /tmp/detective_godot.pid

sleep 3
echo ""
echo "=============================================="
echo "  ✅ 服务已启动:"
echo "     🌐 Web 原型:   http://localhost:8080"
echo "     🎮 Godot Web:  http://localhost:8081"
echo "     📡 后端 API:   http://localhost:3001/api/health"
echo ""
echo "  停止全部: kill \$(cat /tmp/detective_*.pid)"
echo "  后端日志: tail -f /tmp/detective_backend.log"
echo "=============================================="
