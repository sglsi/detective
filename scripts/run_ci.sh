#!/usr/bin/env bash
# P3 模块化 CI 编排：后端(Node) + Godot(headless) + Python 三套测试串联，防回归。
# 用法：bash scripts/run_ci.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
PASS=0
FAIL=0

step() { echo ""; echo "========================================"; echo "▶ $1"; echo "========================================"; }
ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

# ---------- 1. 后端 Node 套件 ----------
step "1/3 后端 Node 套件 (api / tres / editor)"
cd "$ROOT/backend"
rm -f data/local_dev.db data/local_dev.db-wal data/local_dev.db-shm
node src/db/migrate.js >/tmp/ci_migrate.log 2>&1 || { bad "migrate 失败"; cat /tmp/ci_migrate.log; }
node src/server.js >/tmp/ci_backend.log 2>&1 &
SRV=$!
for i in $(seq 1 30); do curl -s -o /dev/null http://localhost:3000/api/health 2>/dev/null && break; sleep 1; done
if curl -s -o /dev/null http://localhost:3000/api/health 2>/dev/null; then
  node tests/api_test.js >/tmp/ci_api.log 2>&1 && ok "api_test (20/20)" || { bad "api_test"; tail -15 /tmp/ci_api.log; }
  node tests/tres_roundtrip.js >/tmp/ci_rt.log 2>&1 && ok "tres_roundtrip (8/8)" || { bad "tres_roundtrip"; tail -15 /tmp/ci_rt.log; }
  node tests/editor_integration.js >/tmp/ci_edit.log 2>&1 && ok "editor_integration" || { bad "editor_integration"; tail -15 /tmp/ci_edit.log; }
else
  bad "后端服务启动失败"; tail -20 /tmp/ci_backend.log
fi
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null

# ---------- 2. Godot headless 套件 ----------
step "2/3 Godot headless 套件 (smoke / art / wall)"
cd "$ROOT/godot_project"
"$GODOT" --headless --import >/tmp/ci_import.log 2>&1 || bad "godot import 警告(可忽略)"
if "$GODOT" --headless --script res://tools/smoke_load_check.gd 2>&1 | grep -q "SMOKE_ALL_OK"; then
  ok "smoke_load_check (8 场景)"
else
  bad "smoke_load_check"; "$GODOT" --headless --script res://tools/smoke_load_check.gd 2>&1 | tail -15
fi
if "$GODOT" --headless --script res://tools/p3_art_check.gd 2>&1 | grep -q "ART_CHECK_OK"; then
  ok "p3_art_check (头像/UI/9-slice/主题)"
else
  bad "p3_art_check"; "$GODOT" --headless --script res://tools/p3_art_check.gd 2>&1 | tail -15
fi
if "$GODOT" --headless --script res://tools/p2_wall_script_check.gd 2>&1 | grep -q "推理墙校验通过"; then
  ok "p2_wall_script_check (五态机/红线)"
else
  bad "p2_wall_script_check"; "$GODOT" --headless --script res://tools/p2_wall_script_check.gd 2>&1 | tail -15
fi
if "$GODOT" --headless --script res://tools/p5_save_load_test.gd 2>&1 | grep -q "SAVE_LOAD_E2E_OK"; then
  ok "p5_save_load_test (存读档端到端)"
else
  bad "p5_save_load_test"; "$GODOT" --headless --script res://tools/p5_save_load_test.gd 2>&1 | tail -15
fi
if "$GODOT" --headless --script res://tools/p5_clue_data_test.gd 2>&1 | grep -q "CLUE_DATA_OK"; then
  ok "p5_clue_data_test (线索/案件数据解析)"
else
  bad "p5_clue_data_test"; "$GODOT" --headless --script res://tools/p5_clue_data_test.gd 2>&1 | tail -15
fi

# ---------- 3. Python 套件 ----------
# 注：test_core_mechanisms 原 7 项【历史基线】失败已修复（脆弱字符串匹配断言对齐真实实现：
# 关系图判定 support≥3/≥1、四色含 alpha、max_* 类型注解、字典字面量收集存档字段、10 种 trigger 文档）。
# 现归零，任何失败即判定为回归并令 CI 失败。
step "3/3 Python 套件 (核心机制 / 场景一)"
cd "$ROOT"
python3 tests/test_core_mechanisms.py >/tmp/ci_pycore.log 2>&1 && ok "test_core_mechanisms" || { bad "test_core_mechanisms"; tail -25 /tmp/ci_pycore.log; }
python3 tests/test_scene1_full.py >/tmp/ci_pyscene.log 2>&1 && ok "test_scene1_full" || { bad "test_scene1_full"; tail -20 /tmp/ci_pyscene.log; }

# ---------- 汇总 ----------
echo ""
echo "========================================"
echo "  CI 汇总: 通过 $PASS / 失败 $FAIL"
echo "========================================"
[ "$FAIL" -eq 0 ]
