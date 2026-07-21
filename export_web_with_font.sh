#!/usr/bin/env bash
# 重新导出 Godot Web 版（已内置中文字体，修复乱码）
#
# 前置条件（本机当前缺失，需先安装）：
#   1) Godot 4.7 引擎本体（编辑器）
#   2) 对应版本的 Web 导出模板（编辑器内 "编辑器 > 管理导出模板 > 下载并安装"）
#
# 用法：
#   GODOT=/path/to/Godot_v4.7-stable_win64.exe bash export_web_with_font.sh
#   或把引擎路径作为第一个参数：
#   bash export_web_with_font.sh "/c/Program Files/Godot/Godot_v4.7-stable_win64.exe"

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/godot_project"

# 在 Git Bash 下调用 Windows 版 Godot 时，必须把路径转成 Windows 风格
# （Godot.exe 不认 /c/Users/... 这种 Unix 路径，否则报 "Invalid project path"）
if command -v cygpath >/dev/null 2>&1; then
  PROJ="$(cygpath -w "$PROJ")"
fi

GODOT="${1:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
  echo "❌ 未指定 Godot 引擎路径。"
  echo "   请用：GODOT=/path/to/godot.exe bash export_web_with_font.sh"
  exit 1
fi
if [ ! -x "$GODOT" ] && [ ! -f "$GODOT" ]; then
  echo "❌ 找不到 Godot 引擎：$GODOT"
  exit 1
fi

echo "==> 1/2 导入资源（生成字体 .import 缓存）"
"$GODOT" --headless --path "$PROJ" --import

echo "==> 2/2 导出 Web（含中文字体）"
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/web_build/index.html"

echo "✅ 导出完成：$PROJ/web_build/"
echo "   现在重启 serve_web.py 即可在 8081 看到中文正常的版本："
echo "   python serve_web.py --port 8081 --directory godot_project/web_build"
