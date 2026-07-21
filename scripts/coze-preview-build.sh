#!/usr/bin/env bash
set -euo pipefail

# 基于脚本位置定位项目根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "[coze-preview-build] 安装后端依赖..."
cd backend
if [ ! -d "node_modules" ]; then
    pnpm install
fi

echo "[coze-preview-build] 构建完成"
