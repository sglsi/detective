#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SCENE5_CHAIN_ALIGN：校验 scene5.gd 推理链（按台词库场景五 4 决策定稿：方案甲叙事 /
观察点丙 / 跟踪决策玩家选择+困难底线 / 线索表扩充 508）与 case_branch_truth.gd 场景五
分枝（CH09A 伪装识破 core / CH09A2 北岸马车夫）逐项一致。

约定：
· correct:true（VERIFIED/SUPPORTED）→ truth nodes/edges 必须有支撑边；
· correct:false 且非 mislead（INSUFFICIENT）→ 不进 truth；
· kind:"mislead"（H5-06 不跟踪）→ 进 truth misleads，expect:"negate"。
用法：python tools/check_scene5_chain.py  （在 godot_project 目录下运行）
"""
import re, sys

OK = True
def fail(msg):
    global OK; OK = False; print("FAIL " + msg)

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

sc = read("scripts/scene/scene5.gd")
truth = read("data/case_branch_truth.gd")

# ── 1) 线索 id 全集（scene5 CLUES 常量，应含 501-508）──
head = sc.split("func reasoning_hypothesis")[0]
clues = set(re.findall(r'"id":"(C_SOTCB_5\d\d)"', head))
need = {"C_SOTCB_%d" % n for n in range(501, 509)}
if not need <= clues:
    fail(f"线索缺失: {sorted(need - clues)}")

# ── 2) reasoning_hypothesis 各块 ──
m = re.search(r'func reasoning_hypothesis.*?"hypotheses": \[(.*?)\n\t+\],\s*"conclusions"', sc, re.S)
if not m: fail("未定位 hypotheses 块"); sys.exit(1)
hyp_block = m.group(1)
m2 = re.search(r'"conclusions": \[(.*?)\n\t+\],\s*"contradictions"', sc, re.S)
if not m2: fail("未定位 conclusions 块"); sys.exit(1)
con_block = m2.group(1)
m3 = re.search(r'"contradictions": \[(.*?)\n\t+\],\s*"milestones"', sc, re.S)
ctr_block = m3.group(1) if m3 else ""
m4 = re.search(r'"milestones": \[(.*?)\n\t+\]', sc, re.S)
mil_block = m4.group(1) if m4 else ""

def entries(block):
    parts = block.split('{"id":"')[1:]
    out = {}
    for p in parts:
        eid = p.split('"')[0].strip()
        out[eid] = p
    return out

hyps = entries(hyp_block)
cons = entries(con_block)

def gates(chunk, key):
    g = re.search(key + r'":\[([^\]]*)\]', chunk)
    return [x.strip().strip('"') for x in g.group(1).split(",") if x.strip()] if g else []

def flag(chunk, key):
    m = re.search(r'"%s":(true|false)' % key, chunk)
    if not m: return None
    return m.group(1) == "true"

# ── 3) 推断全集与四级归属（H5-01~09，H5-06 mislead）──
# (gate_clue_ids, correct)
expect_hyp = {
    "H5-01": ([], False),                     # 普通失主 INSUFFICIENT
    "H5-02": ([], False),                     # 占便宜 INSUFFICIENT
    "H5-03": ([], True),                      # 和案件有关 SUPPORTED
    "H5-04": ([], True),                      # 凶手本人伪装 SUPPORTED
    "H5-05": ([], True),                      # 应该跟踪 VERIFIED（决策）
    "H5-07": ([], True),                      # 凶手是马车夫 SUPPORTED
    "H5-08": ([], True),                      # 戒指是诱饵 SUPPORTED
    "H5-09": (["C_SOTCB_508"], True),         # 北岸活动 SUPPORTED（gate 508）
}
MISLEAD_HYPS = {"H5-06": []}                  # 不用跟踪（mislead，无 gate）

for hid, (exp, corr) in expect_hyp.items():
    if hid not in hyps:
        fail(f"推断 {hid} 缺失"); continue
    got = gates(hyps[hid], "gate_clue_ids")
    if got != exp:
        fail(f"{hid} gate={got} 期望={exp}")
    for c in got:
        if c not in clues:
            fail(f"{hid} 引用非本场景线索 {c}")
    if flag(hyps[hid], "correct") is not corr:
        fail(f"{hid} correct={flag(hyps[hid], 'correct')} 应为 {corr}")
    if '"mislead"' in hyps[hid].split("gate_clue_ids")[0]:
        fail(f"{hid} 不应标为 mislead（属 INSUFFICIENT/SUPPORTED）")

for hid, exp in MISLEAD_HYPS.items():
    if hid not in hyps:
        fail(f"误导推断 {hid} 缺失"); continue
    got = gates(hyps[hid], "gate_clue_ids")
    if got != exp:
        fail(f"{hid} gate={got} 期望={exp}")
    if '"mislead"' not in hyps[hid]:
        fail(f"{hid} 未标 mislead")

# ── 4) 结论 gate_hypo_ids ──
expect_con = {
    "CL5-1": ["H5-04"],            # 伪装识破
    "CL5-2": ["H5-07", "H5-09"],   # 凶手=北岸马车夫
    "CL5-3": ["H5-08"],            # 戒指非同小可
}
for cid, exp in expect_con.items():
    if cid not in cons:
        fail(f"结论 {cid} 缺失"); continue
    got = gates(cons[cid], "gate_hypo_ids")
    if got != exp:
        fail(f"{cid} gate_hypo={got} 期望={exp}")
    for h in got:
        if h not in hyps and h not in MISLEAD_HYPS:
            fail(f"{cid} 引用不存在的推断 {h}")
    if '"mislead"' in cons[cid].split("gate_hypo_ids")[0]:
        fail(f"{cid} 不应标为 mislead")

# ── 5) 矛盾标记（C5-01~04）──
for cid in ["C5-01", "C5-02", "C5-03", "C5-04"]:
    if cid not in ctr_block:
        fail(f"contradictions 缺 {cid}")

# ── 6) 里程碑（S5-1~4）──
for kw in ["老太婆=男扮女装", "凶手=杰弗森·霍普", "凶手=马车夫", "复仇动机"]:
    if kw not in mil_block:
        fail(f"milestones 缺关键词「{kw}」")

# ── 7) truth CH09A / CH09A2 ──
def branch_block(bid):
    m = re.search(r'\{\s*(?:#[^\n]*\n\s*)*"id": "%s".*?\n\t\t\},\n' % bid, truth, re.S)
    return m.group(0) if m else ""

E = {}
NODES = set()
for bid in ("CH09A", "CH09A2"):
    blk = branch_block(bid)
    if not blk:
        fail(f"truth 缺分枝 {bid}"); continue
    for f, t, k in re.findall(r'\{"from": "([^"]+)", "to": "([^"]+)", "kind": "([^"]+)"\}', blk):
        E[(f, t)] = k
    NODES |= set(re.findall(r'\{"id": "([^"]+)", "layer"', blk))

def has(f, t, k="support"):
    if (f, t) not in E:
        fail(f"truth 缺边 {f}→{t}({k})")
    elif E[(f, t)] != k:
        fail(f"truth 边 {f}→{t} kind={E[(f,t)]} 期望 {k}")

# 7a CH09A 边（核心伪装识破）
for (f, t) in [("C_SOTCB_507","H5-03"),("C_SOTCB_503","H5-04"),("C_SOTCB_507","H5-04"),
               ("H5-03","H5-04"),("H5-04","CL5-1"),("C_SOTCB_503","H5-08"),("H5-08","CL5-3")]:
    has(f, t)
# 7b CH09A2 边（北岸马车夫）
for (f, t) in [("C_SOTCB_501","H5-07"),("C_SOTCB_508","H5-09"),("H5-07","CL5-2"),("H5-09","CL5-2")]:
    has(f, t)
# 7c 节点齐备（correct:true 推断 + 正解结论 + 相关线索）
for nid in ["H5-03","H5-04","H5-07","H5-08","H5-09","CL5-1","CL5-2","CL5-3",
            "C_SOTCB_501","C_SOTCB_503","C_SOTCB_507","C_SOTCB_508"]:
    if nid not in NODES:
        fail(f"truth 缺节点 {nid}")
# 7d INSUFFICIENT 不得进 truth
for hid, (_, corr) in expect_hyp.items():
    if not corr and hid in NODES:
        fail(f"INSUFFICIENT 推断 {hid} 不应进 truth 节点")
# 7e misleads（H5-06 negate）
ch09a = branch_block("CH09A")
if not re.search(r'\{"id": "H5-06", "expect": "negate"\}', ch09a):
    fail("CH09A misleads 缺 H5-06 negate")

# ── 8) 流程改造（4 决策）──
if "_show_choice_panel" not in sc:
    fail("未使用 _show_choice_panel")
# 决策1 方案甲：交付离开应在 Step3（_start_step3）而非 Step1（_enter_step1）
if "物归原主" not in sc:
    fail("缺交付戒指「物归原主」台词")
if "func _enter_step1" in sc and "物归原主" in sc.split("func _enter_step1")[1].split("func _start_panel")[0]:
    fail("方案甲违反：交付离开仍在 Step1（应在 Step3）")
if "func _start_step3" in sc and "物归原主" not in sc.split("func _start_step3")[1].split("func _start_step4")[0]:
    fail("方案甲违反：Step3 未含交付离开")
# 决策2 观察点丙：无独立 hotspot，观察项并入 Step3 面板
if "func hotspots() -> Array: return []" not in sc:
    fail("观察点丙违反：hotspots() 应返回空（无独立可点击观察点）")
if "观察 · 面部" not in sc:
    fail("观察点丙违反：Step3 记录面板缺观察项文字")
# 决策3 跟踪决策玩家选择 + 困难底线
for kw in ["跟不跟", "跟踪她", "不跟踪"]:
    if kw not in sc:
        fail(f"跟踪决策缺关键词「{kw}」")
if "你不觉得她哪儿不对劲吗" not in sc:
    fail("困难模式底线补救提示缺失")
if "H5-05" not in sc or "H5-06" not in sc:
    fail("跟踪决策未关联 H5-05/H5-06 假设")
# 决策4 线索表扩充 508
if "C_SOTCB_508" not in sc:
    fail("线索表扩充缺失 C_SOTCB_508")
if "铁匠铺证词" not in sc:
    fail("C_SOTCB_508 名称「铁匠铺证词」缺失")
# 路线消费
if "scene4_route" not in sc:
    fail("未消费/存储 scene4_route")

print("SCENE5_CHAIN_ALIGN: " + ("PASS" if OK else "FAIL"))
sys.exit(0 if OK else 1)
