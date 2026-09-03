#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SCENE4_CHAIN_ALIGN：校验 scene4.gd 推理链（按台词库§18 场景四 12 假设+误导重构）
与 case_branch_truth.gd 场景四分枝（CH07 主线 / CH08 证词时间线）逐项一致。

约定（本场景）：
· VERIFIED / SUPPORTED（correct:true）→ truth nodes/edges 必须有支撑边；
· INSUFFICIENT（correct:false, kind:"true"）→ 不进 truth（采纳零分、不封顶）；
· CONTRADICTORY（kind:"mislead"）→ 进 truth misleads，expect:"negate"。
用法：python tools/check_scene4_chain.py  （在 godot_project 目录下运行）
"""
import re, sys

OK = True
def fail(msg):
    global OK; OK = False; print("FAIL " + msg)

def read(p):
    with open(p, encoding="utf-8") as f: return f.read()

sc = read("scripts/scene/scene4.gd")
truth = read("data/case_branch_truth.gd")

# ── 1) 线索 id 全集（scene4 CLUES 常量）──
head = sc.split("func reasoning_hypothesis")[0]
clues = set(re.findall(r'"id":"(C_SOTCB_4\d\d)"', head))
need = {"C_SOTCB_%d" % n for n in range(401, 408)}
if not need <= clues:
    fail(f"线索缺失: {sorted(need - clues)}")

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

# ── 3) 推断全集与四级归属（台词库 §18 场景四 假设 1~12 + 误导）──
expect_hyp = {
    "H4-01": (["C_SOTCB_401"], True),                     # 案发时间约凌晨两点 VERIFIED
    "H4-02": (["C_SOTCB_401"], True),                     # 正在下雨 VERIFIED
    "H4-03": (["C_SOTCB_401"], True),                     # 门口有个醉汉 VERIFIED
    "H4-04": (["C_SOTCB_402", "C_SOTCB_403"], True),      # 高个红脸 SUPPORTED
    "H4-05": (["C_SOTCB_404"], True),                     # 棕色外衣 SUPPORTED
    "H4-06": (["C_SOTCB_405"], False),                    # 可能有马鞭 INSUFFICIENT
    "H4-07": (["C_SOTCB_401", "C_SOTCB_402", "C_SOTCB_403"], True),  # 醉汉=凶手 SUPPORTED
    "H4-08": (["C_SOTCB_401"], False),                    # 同伙 INSUFFICIENT
    "H4-09": (["C_SOTCB_401"], False),                    # 无关路过 INSUFFICIENT
    "H4-10": (["C_SOTCB_407"], True),                     # 凶手坐马车来 SUPPORTED
    "H4-11": (["C_SOTCB_405", "C_SOTCB_407"], True),      # 伪装醉汉逃走 SUPPORTED
    "H4-12": (["C_SOTCB_401"], True),                     # 兰斯错过凶手 SUPPORTED
}
MISLEAD_HYPS = {"H4-M1": ["C_SOTCB_401"]}                 # 有个女的（困难模式误导）

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
    "CL4-1": ["H4-07", "H4-05", "H4-10"],   # 醉汉=凶手·马车夫
    "CL4-2": ["H4-07", "H4-11"],            # 伪装醉汉逃走（灯下黑）
    "CL4-3": ["H4-01", "H4-02", "H4-12"],   # 证词时间线
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

# ── 5) 矛盾标记（C4-01~04）──
for cid in ["C4-01", "C4-02", "C4-03", "C4-04"]:
    if cid not in ctr_block:
        fail(f"contradictions 缺 {cid}")

# ── 6) 里程碑 ──
for kw in ["五线合一", "车夫", "灯下黑", "凌晨两点"]:
    if kw not in mil_block:
        fail(f"milestones 缺关键词「{kw}」")

# ── 7) truth CH07 / CH08 ──
def branch_block(bid):
    # 兼容块首 { 与 "id" 之间的注释行（场景四 CH07/CH08 带设计注释）
    m = re.search(r'\{\s*(?:#[^\n]*\n\s*)*"id": "%s".*?\n\t\t\},\n' % bid, truth, re.S)
    return m.group(0) if m else ""

E = {}
NODES = set()
for bid in ("CH07", "CH08"):
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
ch07 = branch_block("CH07")
if not re.search(r'\{"id": "H4-M1", "expect": "negate"\}', ch07):
    fail("CH07 misleads 缺 H4-M1")
# 7f 场景四旧 id 不应再出现（旧 CH08「凶手回来找戒指」依赖的跨场景边）
ch08 = branch_block("CH08")
for old in ("c312", "c305"):
    if old in ch08:
        fail(f"CH08 仍引用场景三线索 {old}（旧「凶手回来找戒指」结构残留）")

# ── 8) 流程改造（台词库场景四：三选一初始追问 + 概率干扰 + 五条线教学 + 动态总结 + A/B/C）──
if "_show_choice_panel" not in sc:
    fail("未使用 _show_choice_panel（DialogueManager 的 choice 触发在 SceneFramework 下不被渲染）")
for kw in ["你想从哪里问起", "案发经过", "当时街上有什么人", "醉汉的细节"]:
    if kw not in sc:
        fail(f"三选一初始追问缺「{kw}」")
if "randf() < 0.3" not in sc or "randf() < 0.5" not in sc:
    fail("普通难度概率干扰缺失（30% 时间模糊 / 50% 印度人闲聊）")
if "randf() < 0.7" not in sc:
    fail("困难难度概率干扰缺失（70% 有个女的 / 70% 瘦脸尖）")
for kw in ["第一线", "第二线", "第三线", "第四线", "第五线", "五条线，同时指向同一个人", "五条线——就是事实"]:
    if kw not in sc:
        fail(f"五条线教学缺关键词「{kw}」")
if "func _summary_lines" not in sc:
    fail("缺动态总结 _summary_lines()")
for kw in ["比命还重要", "一个士兵的荣誉", "必须拿回来的东西"]:
    if kw not in sc:
        fail(f"华生'为什么凶手要回来'扩写缺关键词「{kw}」")
for kw in ["发布失物招领", "右前蹄", "克利夫兰", "电报"]:
    if kw not in sc:
        fail(f"A/B/C 行动决策缺关键词「{kw}」")
if 'scene4_route' not in sc:
    fail("未存储 scene4_route")
# 时间设定：走访为当天下午（非深夜）
if "深夜打扰" in sc or "晚上好。福尔摩斯" in sc:
    fail("仍残留深夜版入场台词（应已改为下午版）")
if "DAY 1 下午" not in sc:
    fail("scene_time_text 应为 DAY 1 下午")

print("SCENE4_CHAIN_ALIGN: " + ("PASS" if OK else "FAIL"))
sys.exit(0 if OK else 1)
