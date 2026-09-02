#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SCENE2_CHAIN_ALIGN：校验 scene2.gd 推理链（按台词库§18 六步闭环重构）与
case_branch_truth.gd 场景二分枝（CH02/CH03）逐项一致，且门控引用均为场景二本地热点。
用法：python tools/check_scene2_chain.py  （在 godot_project 目录下运行）"""
import re, sys

OK = True
def fail(msg):
    global OK; OK = False; print("FAIL " + msg)

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

sc = read("scripts/scene/scene2.gd")
truth = read("data/case_branch_truth.gd")
gvc = read("scripts/clue/graph_view_controller.gd")
rw = read("scripts/clue/reasoning_wall.gd")
sc3 = read("scripts/scene/scene3.gd")

# ── 1) 热点 id 全集（STREET/PATH 两 const，至 STAGE_STREET 为止）──
head = sc.split("const STAGE_STREET")[0]
hotspots = set(re.findall(r'\{"id":"(c\d{3})"', head))
need = {f"c{n}" for n in range(201, 209)}
if not need <= hotspots:
    fail(f"热点缺失: {sorted(need - hotspots)}")

# ── 2) reasoning_hypothesis 块 ──
m = re.search(r'func reasoning_hypothesis.*?"hypotheses": \[(.*?)\n\t\t\],\s*"contradictions"', sc, re.S)
if not m: fail("未定位 hypotheses 块"); sys.exit(1)
hyp_block = m.group(1)
m2 = re.search(r'"conclusions": \[(.*?)\n\t\t\],\s*"milestones"', sc, re.S)
if not m2: fail("未定位 conclusions 块"); sys.exit(1)
con_block = m2.group(1)
m3 = re.search(r'"milestones": \[(.*?)\n\t\t\]', sc, re.S)
mil_block = m3.group(1) if m3 else ""

def entries(block):
    """按 '{"id":"' 切分块内条目"""
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

# ── 3) 推断 gate 期望（台词库§18：A 车轮印→出租马车；B 蹄铁新/蹄印乱；C 两人/身高/方头靴）──
expect_gate = {
    "H2-01": ["c201", "c202"],   # 轴距3.8+碾轧花草 → 出租马车
    "H2-02": ["c203"],           # 右前蹄铁新换
    "H2-03": ["c204"],           # 蹄印零乱→马无人看管
    "H2-04": ["c205", "c206"],   # 两组脚印+步幅 → 现场两人
    "H2-05": ["c206"],           # 步幅4.5→身高约6英尺
    "H2-06": ["c205"],           # 方头靴
    "H2-07": ["c206"],           # 高个强壮（manual 可选）
    "H2-M1": ["c205"],
    "H2-M2": ["c202"],
}
for hid, exp in expect_gate.items():
    if hid not in hyps:
        fail(f"推断 {hid} 缺失"); continue
    got = gates(hyps[hid], "gate_clue_ids")
    if got != exp:
        fail(f"{hid} gate={got} 期望={exp}")
    for c in got:
        if c not in hotspots:
            fail(f"{hid} 引用非场景二热点 {c}")
    if '"mislead"' in hyps[hid].split("gate_clue_ids")[0] and hid not in ("H2-M1", "H2-M2"):
        fail(f"{hid} 意外标为 mislead")

# ── 4) 结论 gate_hypo_ids / target 期望 ──
expect_con = {
    "CL2-1": (["H2-01"], None),                       # 出租马车（观察级，不指认人物）
    "CL2-2": (["H2-02"], None),                       # 马被特别关照
    "CL2-3": (["H2-03"], None),                       # 赶车人下车
    "CL2-4": (["H2-01", "H2-02", "H2-03"], "person:KILLER"),  # 三线合一·假设级
    "CL2-5": (["H2-04"], None),                       # 夜间来客两人
    "CL2-6": (["H2-05", "H2-06"], "person:KILLER"),   # 高个体貌（范围估计）
    "CL2-M1": (["H2-M1"], None),
    "CL2-1M": (["H2-M2"], None),
    "CL2-2M": (["H2-05"], None),
    "CL2-3M": (["H2-06"], None),
}
for cid, (exp, tgt) in expect_con.items():
    if cid not in cons:
        fail(f"结论 {cid} 缺失"); continue
    got = gates(cons[cid], "gate_hypo_ids")
    if got != exp:
        fail(f"{cid} gate_hypo={got} 期望={exp}")
    for h in got:
        if h not in hyps:
            fail(f"{cid} 引用不存在的推断 {h}")
    t = re.search(r'target":"([^"]*)"', cons[cid])
    tv = t.group(1) if t else None
    if tv != tgt:
        fail(f"{cid} target={tv} 期望={tgt}")

# ── 5) 里程碑（台词库场景末三线合一总结）──
for kw in ["出租马车", "特别关照", "赶车人不在车上", "空房子", "一高一矮"]:
    if kw not in mil_block:
        fail(f"milestones 缺台词库关键词「{kw}」")

# ── 6) case_branch_truth CH02/CH03 与推理链一致 ──
def branch_block(bid):
    m = re.search(r'\{\s*"id": "%s".*?\n\t\t\},\n' % bid, truth, re.S)
    return m.group(0) if m else ""

edges2 = re.findall(r'\{"from": "([^"]+)", "to": "([^"]+)", "kind": "([^"]+)"\}', branch_block("CH02"))
edges3 = re.findall(r'\{"from": "([^"]+)", "to": "([^"]+)", "kind": "([^"]+)"\}', branch_block("CH03"))
E = {(f, t): k for f, t, k in edges2 + edges3}

def has(f, t, k="support"):
    if (f, t) not in E:
        fail(f"truth 缺边 {f}→{t}({k})")
    elif E[(f, t)] != k:
        fail(f"truth 边 {f}→{t} kind={E[(f,t)]} 期望 {k}")

# CH02: 线索→推断 与 gate 一致
for hid, exp in expect_gate.items():
    if hid.startswith("H2-M"): continue
    for c in exp:
        if hid in ("H2-04", "H2-05", "H2-06", "H2-07"): continue  # CH03 域
        has(c, hid)
# CH02: H→CL（误导结论不建 support 边，只进 misleads 列表）
MISLEAD_CONS = {"CL2-M1", "CL2-1M", "CL2-2M", "CL2-3M"}
for cid, (exp, _) in expect_con.items():
    if cid in ("CL2-5", "CL2-6") or cid in MISLEAD_CONS: continue
    for h in exp:
        if h.startswith("H2-M"): continue
        has(h, cid)
# CH03: 线索→推断（本地+跨场景）
for c, hid in [("c205", "H2-04"), ("c206", "H2-04"), ("c206", "H2-05"), ("c309", "H2-05"),
               ("C_SOTCB_402", "H2-05"), ("c205", "H2-06"), ("c311", "H2-06"), ("c206", "H2-07"),
               ("c309", "H3-04")]:
    has(c, hid)
# CH03: H→CL
for cid in ("CL2-5", "CL2-6"):
    for h in expect_con[cid][0]:
        has(h, cid)
# misleads
for bid, exp_m in [("CH02", ["H2-M2"]), ("CH03", ["H2-M1", "CL2-M1", "CL2-2M", "CL2-3M"])]:
    blk = branch_block(bid)
    for mm in exp_m:
        if not re.search(r'\{"id": "%s", "expect": "negate"\}' % mm, blk):
            fail(f"{bid} misleads 缺 {mm}")

# ── 7) 人物显示名 + 评分器 person 前缀归一 + 跨场景引用 ──
if '"KILLER": "马车夫"' not in gvc: fail("graph_view_controller KILLER 显示名未改为马车夫")
if '"KILLER": "马车夫"' not in rw: fail("reasoning_wall KILLER 显示名未改为马车夫")
if "PERSON_PREFIX" not in read("scripts/clue/wall_branch_evaluator.gd"):
    fail("评分器缺 PERSON_PREFIX")
nbr = re.search(r'if nid\.begins_with\(PERSON_PREFIX\):\s*\n\s*return nid\.substr\(PERSON_PREFIX\.length\(\)\)', read("scripts/clue/wall_branch_evaluator.gd"))
if not nbr: fail("评分器 norm() 未剥 person: 前缀")
if '"relation_tags":["H2-05","H2-06"]' not in sc3: fail("scene3 c311 relation_tags 未对齐 H2-05/H2-06")

print("SCENE2_CHAIN_ALIGN: " + ("PASS" if OK else "FAIL"))
sys.exit(0 if OK else 1)
