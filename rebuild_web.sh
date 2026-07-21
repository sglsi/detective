#!/usr/bin/env bash
# 用本地 Godot 4.7 引擎重新导出 Web（含中文字体 fix），用于修复 8081 乱码。
# 前置：export_presets.cfg 已配置 Web 预设 (export_path=web_build/index.html)，
#       且已通过 export_templates/4.7.stable/web/ 安装 Web 导出模板。
set -e
GODOT="/d/AI/godot/Godot_v4.7-stable_win64/Godot_v4.7-stable_win64.exe"
PROJ="/c/Users/sglsi/WorkBuddy/Claw/detective/godot_project"

echo "==> [1/2] 导入工程资源（生成 .godot 缓存）"
"$GODOT" --headless --path "$PROJ" --import 2>&1 | tail -20

echo "==> [2/2] 导出 Web (release) -> godot_project/web_build/"
"$GODOT" --headless --path "$PROJ" --export-release "Web" 2>&1 | tail -40

echo "==> 完成。产物："
ls -la "$PROJ/web_build/" | grep -E "index\.(html|wasm|pck|js)"
