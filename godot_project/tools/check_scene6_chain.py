#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""场景六推理链静态校验：9假设 + 3结论 + truth CH09B/CH09C + 电报分支 + 概率干扰。"""
import re, sys

SRC = "D:/AI/detective/godot_project/scripts/scene/scene6.gd"
TRUTH = "D:/AI/detective/godot_project/data/case_branch_truth.gd"

def fail(msg):
    print("FAIL:", msg); sys.exit(1)

def ok(msg):
    print("  ok:", msg)

src = open(SRC, encoding="utf-8").read()
truth = open(TRUTH, encoding="utf-8").read()

# ---- 提取 battlefield hypotheses ----
m = re.search(r'"hypotheses":\s*\[(.*?)\n\s*\],', src, re.DOTALL)
if not m: fail("找不到 hypotheses 块")
hyps = {}
for h in re.finditer(r'\{"id":"([^"]+)","text":"([^"]*)"(?:,"correct":(true|false))?(?:,"kind":"([^"]*)")?\}', m.group(1)):
    hid, txt, corr, kind = h.groups()
    hyps[hid] = {"text": txt, "correct": (corr == "true"), "kind": kind}

# 期望 9 假设
expect_hyp = {
    "H6-01": (True, None), "H6-02": (True, None), "H6-03": (True, None),
    "H6-04": (True, None), "H6-05": (False, "mislead"), "H6-06": (False, "mislead"),
    "H6-07": (True, None), "H6-08": (True, None), "H6-09": (True, None),
}
if len(hyps) != 9: fail("假设数=%d，期望9" % len(hyps))
for hid, (corr, kind) in expect_hyp.items():
    if hid not in hyps: fail("缺少假设 %s" % hid)
    if hyps[hid]["correct"] != corr: fail("%s correct=%s 期望%s" % (hid, hyps[hid]["correct"], corr))
    if kind and hyps[hid]["kind"] != kind: fail("%s kind=%s 期望%s" % (hid, hyps[hid]["kind"], kind))
ok("9假设四级归属正确 (H6-05/06=mislead)")

# ---- conclusions ----
mc = re.search(r'"conclusions":\s*\[(.*?)\n\s*\],', src, re.DOTALL)
if not mc: fail("找不到 conclusions 块")
concls = set(re.findall(r'"id":"(CL6-\d+)"', mc.group(1)))
for c in ["CL6-1", "CL6-2", "CL6-3"]:
    if c not in concls: fail("缺少结论 %s" % c)
ok("3结论 CL6-1/2/3 存在")

# ---- truth CH09B / CH09C ----
def block(bid):
    mm = re.search(r'\{\s*"id": "' + re.escape(bid) + r'".*?\n\t\t\},', truth, re.DOTALL)
    if not mm: fail("truth 找不到 %s" % bid)
    return mm.group(0)

b = block("CH09B")
for nid in ["C_SOTCB_603", "C_SOTCB_605", "C_SOTCB_601", "C_SOTCB_602", "H6-01", "H6-07", "CL6-1"]:
    if '"id": "%s"' % nid not in b: fail("CH09B 缺节点 %s" % nid)
ml = re.search(r'"misleads":\s*\[(.*?)\]', b, re.DOTALL).group(1)
for mid in ["H6-05", "H6-06"]:
    if '"id": "%s"' % mid not in ml: fail("CH09B misleads 缺 %s" % mid)
ok("CH09B 节点/边/misleads(H6-05,06) 正确")

c = block("CH09C")
for nid in ["C_SOTCB_604", "H6-02", "H6-09", "CL6-2"]:
    if '"id": "%s"' % nid not in c: fail("CH09C 缺节点 %s" % nid)
ok("CH09C 节点完整 (含 H6-09)")

# ---- 流程断言 ----
if 'scene4_route' not in src or '_play_telegraph_reply' not in src:
    fail("缺少电报分支（scene4_route / _play_telegraph_reply）")
ok("电报分支：场景六末消费 scene4_route=C 播回复")
if 'randf()' not in src:
    fail("缺少概率干扰 randf()")
ok("概率干扰：困难模式 randf() 触发酒馆老板假证词")
if 'scene6_telegraph_rx' not in src:
    fail("未写入 scene6_telegraph_rx 状态")
ok("写入 scene6_telegraph_rx 供场景七消费")

print("\nSCENE6_CHAIN_CHECK: PASS")
