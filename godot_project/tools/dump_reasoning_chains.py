#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""抽取全案推理链（场景一~八）为 Markdown：线索 -> 推断 -> 结论 -> 人物/事件。
直接解析各场景 scripts/scene/sceneN.gd 源文件，不依赖 Godot 运行时。
用法：python tools/dump_reasoning_chains.py
输出：data/reasoning_chains_all_scenes.md
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "reasoning_chains_all_scenes.md")
SCENE_DIR = os.path.join(ROOT, "scripts", "scene")


def read(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def strip_trailing_commas(s):
    return re.sub(r",(\s*[}\]])", r"\1", s)


def to_json(s):
    return json.loads(strip_trailing_commas(s))


def extract_balanced(text, open_idx):
    """从 open_idx（应为 '{' 或 '['）起，提取配平的子串。"""
    opener = text[open_idx]
    closer = "}" if opener == "{" else "]"
    depth = 0
    for i in range(open_idx, len(text)):
        c = text[i]
        if c == opener:
            depth += 1
        elif c == closer:
            depth -= 1
            if depth == 0:
                return text[open_idx:i + 1]
    return text[open_idx:]


def extract_dict_after(text, marker):
    """找 marker 之后第一个 '{'，返回配平 dict 字符串。"""
    idx = text.find(marker)
    if idx < 0:
        return None
    bi = text.find("{", idx)
    if bi < 0:
        return None
    return extract_balanced(text, bi)


def extract_array_after(text, marker):
    idx = text.find(marker)
    if idx < 0:
        return None
    bi = text.find("[", idx)
    if bi < 0:
        return None
    return extract_balanced(text, bi)


def clue_labels(text):
    """从场景源文件抽取 线索id -> 标签（label 或 name）。"""
    pat = r'"id"\s*:\s*"([^"]+)"[^}]*?(?:"label"|"name")\s*:\s*"([^"]+)"'
    m = re.findall(pat, text, re.DOTALL)
    return {k: v for k, v in m}


def kind_mark(d):
    if d.get("kind") == "mislead":
        return "（❌误导）"
    if d.get("correct") is False:
        return "（❌误导）"
    return "（✅真）"


def clue_str(cid, cmap):
    if cid in cmap:
        return "%s(%s)" % (cmap[cid], cid)
    return cid


def emit_hypothesis(lines, h, cmap, hyp_by_id, depth, hyp_to_clue=None):
    pad = "    " if depth <= 0 else "      "
    hid = h.get("id", "")
    lines.append('%s- %s %s %s' % (pad, hid, h.get("text", ""), kind_mark(h)))
    gclues = h.get("gate_clue_ids", []) or []
    if (not gclues) and hyp_to_clue and hid in hyp_to_clue:
        gclues = [hyp_to_clue[hid]]
    if gclues:
        lines.append("%s  - 线索：%s" % (pad, ", ".join(clue_str(c, cmap) for c in gclues)))
    if h.get("adopt_desc"):
        lines.append("%s  - 推导：%s" % (pad, h["adopt_desc"]))
    ghypo = h.get("gate_hypo_ids", []) or []
    if ghypo:
        lines.append("%s  - ← 推断：%s" % (pad, ", ".join(str(x) for x in ghypo)))


def emit_conclusion(lines, c, hyp_by_id, cmap, hyp_to_clue=None):
    cid = c.get("id", "")
    lines.append("- **结论 %s**：%s %s" % (cid, c.get("text", ""), kind_mark(c)))
    pe = ""
    if c.get("target"):
        pe = c["target"]
    else:
        parts = list(c.get("subject", [])) + list(c.get("object", []))
        pe = ", ".join(str(x) for x in parts)
    if pe:
        lines.append("  - 人物/事件：%s" % pe)
    if c.get("adopt_desc"):
        lines.append("  - 推导：%s" % c["adopt_desc"])
    gate = c.get("gate_hypo_ids", []) or []
    if gate:
        lines.append("  - 依据推断：")
        for hid in gate:
            h = hyp_by_id.get(str(hid))
            if h is None:
                lines.append("    - %s（未找到）" % hid)
                continue
            emit_hypothesis(lines, h, cmap, hyp_by_id, 1, hyp_to_clue)
    else:
        lines.append("  - （无前置推断）")
    if c.get("kind") == "mislead" and c.get("reject_desc"):
        lines.append("  - 排除说明：%s" % c["reject_desc"])
    lines.append("")


def dump_scene(lines, sid):
    path = os.path.join(SCENE_DIR, sid + ".gd")
    text = read(path)
    # battlefield
    bf_txt = extract_dict_after(text, "battlefield")
    if bf_txt is None:
        lines.append("## %s（未找到 battlefield）" % sid)
        lines.append("")
        return
    bf = to_json(bf_txt)
    # title 在 reasoning_hypothesis() 的 return 外层 dict 中
    rh_txt = extract_dict_after(text, "func reasoning_hypothesis")
    title_m = re.search(r'"title"\s*:\s*"([^"]*)"', rh_txt) if rh_txt else None
    title = title_m.group(1) if title_m else sid
    hyps = bf.get("hypotheses", []) or []
    cons = bf.get("conclusions", []) or []
    contrad = bf.get("contradictions", []) or []
    cmap = clue_labels(text)
    hyp_by_id = {str(h.get("id", "")): h for h in hyps}
    lines.append("## %s · %s" % (sid, title))
    lines.append("")
    if cons:
        lines.append("### 结论（含误导项）")
        lines.append("")
        for c in cons:
            emit_conclusion(lines, c, hyp_by_id, cmap)
        lines.append("")
    gated = set()
    for c in cons:
        for hid in c.get("gate_hypo_ids", []) or []:
            gated.add(str(hid))
    for h in hyps:
        for hid in h.get("gate_hypo_ids", []) or []:
            gated.add(str(hid))
    standalone = [h for h in hyps if str(h.get("id", "")) not in gated]
    if standalone:
        lines.append("### 未闭合 / 独立推断（无结论直接依赖）")
        lines.append("")
        for h in standalone:
            emit_hypothesis(lines, h, cmap, hyp_by_id, 0)
        lines.append("")
    if contrad:
        lines.append("### 矛盾标记")
        lines.append("")
        for ct in contrad:
            lines.append("- **%s**：%s %s" % (ct.get("id", ""), ct.get("text", ""), kind_mark(ct)))
        lines.append("")
    lines.append("---")
    lines.append("")


def dump_scene1(lines):
    path = os.path.join(SCENE_DIR, "scene1.gd")
    text = read(path)
    cmap = clue_labels(text)
    # 华生墙：var hypo := { ... } 中的 battlefield
    w_txt = extract_dict_after(text, 'var hypo := {')
    w = to_json(w_txt)
    w_bf = w.get("battlefield", {})
    w_hyps = w_bf.get("hypotheses", []) or []
    w_cons = w_bf.get("conclusions", []) or []
    # 信使墙：_messenger_hypotheses 的 arr
    m_arr = extract_array_after(text, "var arr := [")
    m_hyps = to_json(m_arr)
    m_hypo_clue = {
        "M-01": "tattoo", "M-02": "beard", "M-03": "posture",
        "M-04": "manner", "M-05": "sleeve", "M-06": "limp",
    }
    m_cons = [{
        "id": "MM-1", "text": "信使是海军陆战队军士", "correct": True,
        "gate_hypo_ids": ["M-01", "M-02", "M-03", "M-04"], "target": "person:NPC_MSG",
    }]

    lines.append("## 场景一 · 华生 / 信使 身份推理（教学墙）")
    lines.append("")
    lines.append("### 华生墙：华生刚从阿富汗回来？")
    lines.append("")
    _emit_block(lines, w_hyps, w_cons, cmap, {})
    lines.append("")
    lines.append("### 信使墙：信使是海军陆战队军士？")
    lines.append("")
    _emit_block(lines, m_hyps, m_cons, cmap, m_hypo_clue)
    lines.append("")
    lines.append("---")
    lines.append("")


def _emit_block(lines, hyps, cons, cmap, hyp_to_clue):
    hyp_by_id = {str(h.get("id", "")): h for h in hyps}
    lines.append("#### 结论")
    lines.append("")
    for c in cons:
        emit_conclusion(lines, c, hyp_by_id, cmap, hyp_to_clue)
    lines.append("")
    gated = set()
    for c in cons:
        for hid in c.get("gate_hypo_ids", []) or []:
            gated.add(str(hid))
    for h in hyps:
        for hid in h.get("gate_hypo_ids", []) or []:
            gated.add(str(hid))
    standalone = [h for h in hyps if str(h.get("id", "")) not in gated]
    if standalone:
        lines.append("#### 干扰 / 独立推断")
        lines.append("")
        for h in standalone:
            emit_hypothesis(lines, h, cmap, hyp_by_id, 0, hyp_to_clue)
        lines.append("")


def main():
    lines = []
    lines.append("# 全案推理链总表（场景一 ~ 场景八）")
    lines.append("")
    lines.append("> 结构：**线索 → 推断 → 结论 → 人物/事件**")
    lines.append("> 数据来源：各场景 `reasoning_hypothesis()`（场景二~八）与教学墙内联数据（场景一），由工具解析源文件自动抽取并生成。")
    lines.append("> 标记：`✅真` = 正确推断/结论；`❌误导` = 干扰项（mislead / correct=false）。")
    lines.append("> 线索后的括号为其场景内短 id（如 c201），便于回查 `HOTSPOTS` 热点定义。")
    lines.append("")
    lines.append("---")
    lines.append("")

    dump_scene1(lines)
    for sid in ["scene2", "scene3", "scene4", "scene5", "scene6", "scene7", "scene8"]:
        dump_scene(lines, sid)

    txt = "\n".join(lines)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(txt)
    print("WROTE_MD_BYTES=%d -> %s" % (len(txt.encode("utf-8")), OUT))


if __name__ == "__main__":
    main()
