#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""场景七推理链静态校验：12假设 + 3结论 + truth CH09D/CH09E + 电报确认 + 概率干扰。"""
import re, sys

SRC = "D:/AI/detective/godot_project/scripts/scene/scene7.gd"
TRUTH = "D:/AI/detective/godot_project/data/case_branch_truth.gd"

def fail(msg):
    print("FAIL:", msg); sys.exit(1)
def ok(msg):
    print("  ok:", msg)

src = open(SRC, encoding="utf-8").read()
truth = open(TRUTH, encoding="utf-8").read()

# ---- battlefield hypotheses ----
m = re.search(r'"hypotheses":\s*\[(.*?)\n\s*\],', src, re.DOTALL)
if not m: fail("找不到 hypotheses 块")
hyps = {}
for h in re.finditer(r'\{"id":"([^"]+)","text":"([^"]*)"(?:,"correct":(true|false))?(?:,"kind":"([^"]*)")?\}', m.group(1)):
    hid, txt, corr, kind = h.groups()
    hyps[hid] = {"correct": (corr == "true"), "kind": kind}

expect_hyp = {
    "H7-01": (True, None), "H7-02": (True, None), "H7-03": (True, None), "H7-04": (True, None),
    "H7-05": (True, None), "H7-06": (True, None), "H7-07": (False, "mislead"),
    "H7-08": (False, "mislead"), "H7-09": (True, None), "H7-10": (True, None),
    "H7-11": (True, None), "H7-12": (True, None),
}
if len(hyps) != 12: fail("假设数=%d，期望12" % len(hyps))
for hid, (corr, kind) in expect_hyp.items():
    if hid not in hyps: fail("缺少假设 %s" % hid)
    if hyps[hid]["correct"] != corr: fail("%s correct=%s 期望%s" % (hid, hyps[hid]["correct"], corr))
    if kind and hyps[hid]["kind"] != kind: fail("%s kind=%s 期望%s" % (hid, hyps[hid]["kind"], kind))
ok("12假设四级归属正确 (H7-07/08=mislead)")

# ---- conclusions ----
mc = re.search(r'"conclusions":\s*\[(.*?)\n\s*\],', src, re.DOTALL)
if not mc: fail("找不到 conclusions 块")
concls = set(re.findall(r'"id":"(CL7-\d+)"', mc.group(1)))
for c in ["CL7-1", "CL7-2", "CL7-3"]:
    if c not in concls: fail("缺少结论 %s" % c)
ok("3结论 CL7-1/2/3 存在")

# ---- truth CH09D / CH09E ----
def block(bid):
    mm = re.search(r'\{\s*"id": "' + re.escape(bid) + r'".*?\n\t\t\},', truth, re.DOTALL)
    if not mm: fail("truth 找不到 %s" % bid)
    return mm.group(0)

d = block("CH09D")
for nid in ["C_SOTCB_701","C_SOTCB_702","C_SOTCB_703","C_SOTCB_706","C_SOTCB_707","C_SOTCB_708",
            "H7-01","H7-02","H7-03","H7-04","H7-05","H7-06","H7-12","CL7-1","CL7-3"]:
    if '"id": "%s"' % nid not in d: fail("CH09D 缺节点 %s" % nid)
ml = re.search(r'"misleads":\s*\[(.*?)\]', d, re.DOTALL).group(1)
if '"id": "H7-08"' not in ml: fail("CH09D misleads 缺 H7-08")
ok("CH09D 节点/边/misleads(H7-08) 正确")

e = block("CH09E")
for nid in ["C_SOTCB_704","C_SOTCB_710","H7-02","H7-11","CL7-2"]:
    if '"id": "%s"' % nid not in e: fail("CH09E 缺节点 %s" % nid)
ok("CH09E 节点完整 (含 H7-11)")

# ---- 流程断言 ----
if 'scene6_telegraph_rx' not in src and 'scene4_route' not in src:
    fail("缺少电报确认状态读取")
ok("电报确认：场景七消费 scene6_telegraph_rx / scene4_route，J.H.→霍普")
if 'randf()' not in src:
    fail("缺少概率干扰 randf()")
ok("概率干扰：困难模式 randf() 触发雷斯垂德『不同凶手论』假脚印")
if '_telegraph_confirmed' not in src:
    fail("未设置 _telegraph_confirmed 标志")
ok("_telegraph_confirmed 标志位已设置")

print("\nSCENE7_CHAIN_CHECK: PASS")
