#!/usr/bin/env bash
# Godot 4.7.1 工具链幂等播种：编辑器 + Web 导出模板（分片并行下载）
# 用法：bash tools/godot/setup_godot.sh  （缺料自动下载，已有则解压+软链，不联网）
set -e
GODOT_DIR="$(cd "$(dirname "$0")" && pwd)"
V="4.7.1-stable"
BASE="https://gh.ddlc.top/github.com/godotengine/godot/releases/download/${V}"
ED_ZIP="$GODOT_DIR/Godot_v${V}_linux.x86_64.zip"
ED_SIZE=76056717
TPZ="$GODOT_DIR/Godot_v${V}_export_templates.tpz"
TPZ_SIZE=1280486955
TMPL_DIR="$HOME/.local/share/godot/export_templates/4.7.1.stable"
WEB_ZIPS="web_release web_nothreads_release web_nothreads_debug web_debug"

dl() {
  local url="$1" out="$2" total="$3" chunk=$((16*1024*1024)) s e i parts psz
  if [ -f "$out" ]; then echo "SKIP $out"; return; fi
  parts=$(( (total + chunk - 1) / chunk ))
  : > "$out"
  for i in $(seq 0 $((parts-1))); do
    s=$(( i * chunk )); e=$(( s + chunk - 1 )); [ $e -ge $total ] && e=$(( total - 1 ))
    curl -s --max-time 600 -r $s-$e -w "HTTP=%{http_code} sz=%{size_download}" "$url" -o "$out.p$i" > "$out.hdr" 2>&1
    psz=$(stat -c%s "$out.p$i" 2>/dev/null || echo 0)
    if [ $(( e - s + 1 )) != "$psz" ]; then echo "PART_FAIL i=$i got=$psz want=$(( e - s + 1 ))"; rm -f "$out".p* "$out"; return 1; fi
    cat "$out.p$i" >> "$out" && rm -f "$out.p$i"
    sleep 1
  done
  echo "DONE $(basename "$out") $(stat -c%s "$out")"
}

if [ ! -x "$GODOT_DIR/editor_extract/Godot_v${V}_linux.x86_64" ]; then
  dl "${BASE}/Godot_v${V}_linux.x86_64.zip" "$ED_ZIP" $ED_SIZE
  mkdir -p "$GODOT_DIR/editor_extract"
  unzip -o -q "$ED_ZIP" -d "$GODOT_DIR/editor_extract"
fi

NEED_TPZ=0
for z in $WEB_ZIPS; do [ -f "$GODOT_DIR/${z}.zip" ] || NEED_TPZ=1; done
if [ "$NEED_TPZ" = "1" ]; then
  dl "${BASE}/Godot_v${V}_export_templates.tpz" "$TPZ" $TPZ_SIZE
  unzip -o -q -j "$TPZ" "templates/web_*.zip" -d "$GODOT_DIR"
  rm -f "$TPZ"
fi

mkdir -p "$TMPL_DIR"
for z in $WEB_ZIPS; do
  [ -f "$GODOT_DIR/${z}.zip" ] && ln -sf "$GODOT_DIR/${z}.zip" "$TMPL_DIR/${z}.zip"
done
echo "GODOT_TOOLCHAIN_OK"
