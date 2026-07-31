#!/usr/bin/env bash
# 固化 headless 回归测试入口（离线，无需后端）
# 用法: bash tools/run_headless_tests.sh
# 对应: docs/设计文档/架构比对与修正建议.md §5
set -u

GODOT="/d/AI/godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe"
PROJ="/d/AI/detective/godot_project"
cd "$PROJ" || exit 1

run_script() {
  echo "=================================================="
  echo "▶ $1"
  echo "--------------------------------------------------"
  "$GODOT" --headless --script "$2" 2>&1 | tail -12
}

echo "########## 1/3 工具系统回归 ##########"
run_script "test_tool_system" "tools/test_tool_system.gd"

echo "########## 2/3 账号隔离回归（须 PASS=15 FAIL=0）##########"
echo "--------------------------------------------------"
"$GODOT" --headless "res://scenes/test_user_isolation.tscn" --quit 2>&1 | tail -12

echo "########## 3/3 存/读档端到端 ##########"
run_script "test_save_load" "tests/test_save_load.gd"

echo "=================================================="
echo "完成。"
echo "注: tests/test_api_integration.gd 需后端(3001)运行，已跳过；详见 tests/README.md"
