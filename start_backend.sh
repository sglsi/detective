#!/bin/bash
# ==============================================
#  维多利亚伦敦探案 — 后端服务启动脚本
# ==============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"

echo "=============================================="
echo "  维多利亚伦敦探案 — 后端 API 服务"
echo "=============================================="

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "❌ 未找到 Node.js，请先安装 Node.js 18+"
    exit 1
fi

echo "  Node.js: $(node --version)"

# 进入后端目录
cd "$BACKEND_DIR"

# 检查 .env 文件
if [ ! -f ".env" ]; then
    echo "⚠️  未找到 .env 文件，从 .env.example 创建..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "  已创建 .env，请编辑填入 Supabase 凭据"
    else
        echo "❌ .env.example 不存在"
        exit 1
    fi
fi

# 安装依赖
if [ ! -d "node_modules" ]; then
    echo "📦 安装依赖..."
    npm install
fi

# 启动服务
echo "🚀 启动服务..."
echo "  地址: http://localhost:${PORT:-3000}"
echo "  健康检查: http://localhost:${PORT:-3000}/api/health"
echo ""
echo "  按 Ctrl+C 停止服务"
echo "=============================================="
echo ""

npm start
