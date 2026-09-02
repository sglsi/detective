#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SCENE3_CHAIN_ALIGN：校验 scene3.gd 推理链（按台词库§18 场景三 A/B/C 三组六步闭环重构）
与 case_branch_truth.gd 场景三分枝（CH04 A 组 / CH05 C 组 / CH06 B 组）逐项一致。

约定（本场景）：
· VERIFIED / SUPPORTED（correct:true）→ truth nodes/edges 必须有支撑边；
· INSUFFICIENT（correct:false, kind:"true"）→ 不进 truth（采纳零分、不封顶）；
· CONTRADICTORY（kind:"mislead"）→ 进 truth misleads，expect:"negate"。
用法：python tools/check_scene3_chain.py  （在 godot_project 目录下运行）
"""
import re, sys

OK = True
def fail(msg):
    global OK; OK = False; print("FAIL " + msg)

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

sc = read("scripts/scene/scene3.gd")
truth = read("data/case_branch_truth.gd")

# ── 1) 热点 id 全集 ──
head = sc.split("func reasoning_hypothesis")[0]
hotspots = set(re.findall(r'\{"id":"(c\d{3})"', head))
need = {f"c{n}" for n in range(301, 313)}
if not need <= hotspots:
    fail(f"热点缺失: {sorted(need - hotspots)}")

# ── 2) reasoning_hypothesis 块 ──
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

# ── 3) 推断全集与四级归属（台词库 §18 场景三）──
#   gate 期望：线索→推断；correct 期望：True=VERIFIED/SUPPORTED，False=INSUFFICIENT
expect_hyp = {
    # A 组 尸体检验
    "H3-A1": (["c302", "c301"], True),   # 无外伤 VERIFIED
    "H3-A2": (["c302", "c301"], True),   # 毒杀 SUPPORTED
    "H3-A3": (["c301"], False),          # 心脏病 INSUFFICIENT
    "H3-A4": (["c301"], False),          # 被吓死 INSUFFICIENT
    "H3-A5": (["c301"], True),           # 剧烈挣扎 VERIFIED
    "H3-A6": (["c301"], True),           # 约四十多岁 SUPPORTED
    "H3-A7": (["c303"], True),           # 身份不低 SUPPORTED
    # B 组 随身物品
    "H3-B1": (["c304"], True),           # 德雷伯 VERIFIED
    "H3-B2": (["c304"], True),           # 克利夫兰 VERIFIED
    "H3-B3": (["c306"], True),           # 共济会 SUPPORTED
    "H3-B4": (["c305"], True),           # 经济良好 SUPPORTED
    "H3-B5": (["c304"], True),           # 回纽约 SUPPORTED
    "H3-B6": (["c307", "c304"], True),   # 斯特兰森同伴 SUPPORTED
    "H3-B7": (["c307"], False),          # 斯特兰森涉案 INSUFFICIENT
    "H3-B8": (["c306", "c312"], False),  # 与女人有关 INSUFFICIENT
    "H3-B9": (["c304"], False),          # 仇杀 INSUFFICIENT
    # C 组 现场痕迹
    "H3-C1": (["c309"], True),           # 血字是 RACHE VERIFIED
    "H3-C2": (["c309"], True),           # 德语复仇 SUPPORTED
    "H3-C3": (["c309", "c311"], True),   # 书写者六英尺 SUPPORTED
    "H3-C4": (["c309", "c301"], True),   # 指甲未修剪 SUPPORTED
    "H3-C5": (["c311"], True),           # 现场两人 VERIFIED
    "H3-C6": (["c311"], True),           # 方头靴/漆皮靴 VERIFIED
    "H3-C7": (["c311", "c309"], True),   # 方头靴者较高 SUPPORTED
    "H3-C8": (["c310"], False),          # 印度雪茄 INSUFFICIENT
    "H3-C9": (["c309"], False),          # 复仇性质 INSUFFICIENT
}
MISLEAD_HYPS = {"H3-C10": ["c309", "c312"]}   # CONTRADICTORY

for hid, (exp, corr) in expect_hyp.items():
    if hid not in hyps:
        fail(f"推断 {hid} 缺失"); continue
    got = gates(hyps[hid], "gate_clue_ids")
    if got != exp:
        fail(f"{hid} gate={got} 期望={exp}")
    for c in got:
        if c not in hotspots:
            fail(f"{hid} 引用非本场景热点 {c}")
    if flag(hyps[hid], "correct") is not corr:
        fail(f"{hid} correct={flag(hyps[hid], 'correct')} 应为 {corr}")
    if '"mislead"' in hyps[hid].split("gate_clue_ids")[0]:
        fail(f"{hid} 不应标为 mislead（属 INSUFFICIENT）")

for hid, exp in MISLEAD_HYPS.items():
    if hid not in hyps:
        fail(f"误导推断 {hid} 缺失"); continue
    got = gates(hyps[hid], "gate_clue_ids")
    if got != exp:
        fail(f"{hid} gate={got} 期望={exp}")
    if '"mislead"' not in hyps[hid].split("gate_clue_ids")[0]:
        fail(f"{hid} 未标 mislead")

# ── 4) 结论 gate_hypo_ids ──
expect_con = {
    "CL3-1": ["H3-B1", "H3-B2"],                          # 德雷伯·克利夫兰
    "CL3-2": ["H3-A1", "H3-A2", "H3-A5"],                 # 毒杀（四线合一）
    "CL3-3": ["H3-C1", "H3-C2", "H3-C3", "H3-C4"],        # 血字复仇+六英尺+指甲
    "CL3-4": ["H3-C5", "H3-C6", "H3-C7"],                 # 现场两人·靴子
    "CL3-5": ["H3-B5", "H3-B6"],                          # 斯特兰森同伴·回纽约
}
MISLEAD_CONS = {"CL3-M1": ["H3-C10"]}

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

for cid, exp in MISLEAD_CONS.items():
    if cid not in cons:
        fail(f"误导结论 {cid} 缺失"); continue
    got = gates(cons[cid], "gate_hypo_ids")
    if got != exp:
        fail(f"{cid} gate_hypo={got} 期望={exp}")
    if '"mislead"' not in cons[cid].split("gate_hypo_ids")[0]:
        fail(f"{cid} 未标 mislead")

# ── 5) 矛盾标记（台词库 C3-01~05 + C-06）──
cb = ctr_block
for cid in ["C3-01", "C3-02", "C3-03", "C3-04", "C3-05", "C-06"]:
    if cid not in cb:
        fail(f"contradictions 缺 {cid}")

# ── 6) 里程碑 ──
for kw in ["德雷伯", "无外伤", "服毒", "RACHE", "现场两人", "指甲", "斯特兰森"]:
    if kw not in mil_block:
        fail(f"milestones 缺台词库关键词「{kw}」")

# ── 7) truth CH04 / CH05 / CH06 ──
def branch_block(bid):
    m = re.search(r'\{\s*"id": "%s".*?\n\t\t\},\n' % bid, truth, re.S)
    return m.group(0) if m else ""

E = {}
NODES = set()
for bid in ("CH04", "CH05", "CH06"):
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

# 7a 线索→推断：correct:true 的推断必须有全部 gate 边
for hid, (exp, corr) in expect_hyp.items():
    if not corr: continue
    for c in exp:
        has(c, hid)
# 7b 推断→结论
for cid, exp in expect_con.items():
    for h in exp:
        has(h, cid)
# 7c 节点齐备（仅 correct:true 的推断 + 正解结论）
for hid, (_, corr) in expect_hyp.items():
    if corr and hid not in NODES:
        fail(f"truth 缺节点 {hid}")
for cid in expect_con:
    if cid not in NODES:
        fail(f"truth 缺节点 {cid}")
# 7d INSUFFICIENT 不得进 truth（否则会误加分）
for hid, (_, corr) in expect_hyp.items():
    if not corr and hid in NODES:
        fail(f"INSUFFICIENT 推断 {hid} 不应进 truth 节点")
# 7e misleads
ch05 = branch_block("CH05")
for mm in ("H3-C10", "CL3-M1"):
    if not re.search(r'\{"id": "%s", "expect": "negate"\}' % mm, ch05):
        fail(f"CH05 misleads 缺 {mm}")
# 7f 场景三旧 id 不应再出现
for old in ("H3-01", "H3-02", "H3-03", "H3-04"):
    if old in truth or old in sc:
        fail(f"旧推理 id {old} 仍被引用")

# ── 8) 流程改造（台词库场景三：自由选序 + 读尸体教学 + 维金斯）──
if "_show_choice_panel" not in sc:
    fail("未使用 _show_choice_panel（DialogueManager 的 choice 触发在 SceneFramework 下不被渲染）")
for kw in ["先从哪一条线开始", "尸体", "随身物品", "现场痕迹"]:
    if kw not in sc:
        fail(f"勘查顺序选择面板缺「{kw}」")
for kw in ["恐怖", "忿恨", "被迫服毒", "暗紫", "泡沫", "生物碱", "双拳", "挣扎"]:
    if kw not in sc:
        fail(f"读尸体教学缺关键词「{kw}」")
for kw in ["维金斯", "贝克街", "一先令", "看人，永远比看证据难"]:
    if kw not in sc:
        fail(f"维金斯段落缺关键词「{kw}」")
if "我不怀疑" not in sc or "有疑问" not in sc:
    fail("缺台词库名句「我不怀疑……我只是有疑问」")
if "def _summary_lines" not in sc and "func _summary_lines" not in sc:
    fail("缺动态总结 _summary_lines()")

print("SCENE3_CHAIN_ALIGN: " + ("PASS" if OK else "FAIL"))
sys.exit(0 if OK else 1)
