#!/usr/bin/env python3
"""
milestone_gate_suggester.py — 里程碑 gate 半自动派生工具

从链库 (reasoning_chains.gd) 的 battlefield 数据出发，
为每条链自动生成建议 gate 节点列表，辅助人工标注。

派生规则（按优先级）：
  1. 第一层结论（gate_hypo_ids 为单条真假设）—— 对应"建立一个浅层结论"
  2. 最终结论（target 指向 person 或 gate 依赖多个结论的汇总结论）
  3. target 指向的 person 节点
  4. 关键矛盾项（correct=true 且文本含"vs"的 contradictions）

输出：
  - 每条链的 id、name、建议 gate 列表
  - 与场景脚本中已有 milestone 的对照表（scene2 已有 gate 作为参考基线）

用法：
  python3 tools/milestone_gate_suggester.py [--chain CH02] [--format table|json]
"""
import re
import json
import argparse
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
CHAINS_FILE = PROJECT / "data" / "reasoning_chains.gd"


def extract_chains_dict(gd_text: str) -> dict:
    """
    粗糙但够用的 GDScript 字典提取：
    找到 CHAINS = { ... } 块，用大括号计数定位，
    再做最小化的 GDScript→JSON 转换（去掉尾逗号、字符串化键）。
    """
    # 找到 CHAINS = { 的位置
    m = re.search(r'const\s+CHAINS\s*:?=\s*\{', gd_text)
    if not m:
        raise ValueError("未找到 CHAINS 常量")
    start = m.end() - 1  # '{' 的位置

    # 大括号计数找到结束
    depth = 0
    end = start
    for i in range(start, len(gd_text)):
        if gd_text[i] == '{':
            depth += 1
        elif gd_text[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break

    block = gd_text[start:end]
    # 去掉 GDScript 注释（# 到行尾，不在字符串内的）
    block_no_comments = re.sub(r'(?m)(?<!")#[^\n]*$', '', block)
    # 去掉字符串外的尾逗号（}, 或 ], 后紧跟 } 或 ] 或换行）
    # 简单处理：所有 }, 替换为 }，], 替换为 ] —— 字符串里不会出现 },
    # 但字符串里可能有 }, 吗？在文本里不太可能，先这么处理
    # 更稳妥：逐字符扫描，跟踪字符串状态
    out = []
    in_str = False
    i = 0
    while i < len(block_no_comments):
        c = block_no_comments[i]
        if c == '"' and (i == 0 or block_no_comments[i-1] != '\\'):
            in_str = not in_str
            out.append(c)
        elif not in_str and c in (' ', '\t', '\n', '\r'):
            # 保留换行有助于调试，但 JSON 不要求——先去掉空白压缩
            i += 1
            continue
        elif not in_str and c == ',' and i + 1 < len(block_no_comments) and block_no_comments[i+1] in ('}', ']'):
            # 尾逗号跳过
            i += 1
            continue
        else:
            out.append(c)
        i += 1
    json_str = ''.join(out)
    return json.loads(json_str)


def analyze_chain(chain_id: str, data: dict) -> dict:
    """分析单条链，返回建议 gate 列表"""
    wall = data.get("wall", {}).get("battlefield", {})
    hypos = wall.get("hypotheses", [])
    concls = wall.get("conclusions", [])
    contradictions = wall.get("contradictions", [])
    persons = data.get("persons", [])

    # 真节点 id 集合
    true_hypo_ids = {h["id"] for h in hypos if h.get("kind") == "true" or h.get("correct", False)}
    true_concl_ids = {c["id"] for c in concls if c.get("kind") == "true"}

    # 第一层结论：gate_hypo_ids 长度为 1 且为真假设（浅层结论）
    first_layer_concls = []
    for c in concls:
        ghs = c.get("gate_hypo_ids", [])
        gcs = c.get("gate_clue_ids", [])
        if c.get("kind") != "true":
            continue
        # 第一层：只依赖假设（不依赖其他结论）且依赖 1~2 个真假设
        depends_on_concl = any(g.startswith("conclusion_") or g in true_concl_ids for g in ghs)
        if not depends_on_concl and len(ghs) <= 2 and all(h in true_hypo_ids for h in ghs):
            first_layer_concls.append(c["id"])

    # 最终结论：有 target 指向 person 或依赖 3+ 个结论的汇总结论
    final_concls = []
    for c in concls:
        if c.get("kind") != "true":
            continue
        has_target = c.get("target", "")
        if has_target:
            final_concls.append(c["id"])
            continue
        # 或依赖多个结论节点（conclusion_ 前缀）
        ghs = c.get("gate_hypo_ids", [])
        concl_deps = [g for g in ghs if g.startswith("conclusion_") or g in true_concl_ids]
        if len(concl_deps) >= 2:
            final_concls.append(c["id"])

    # 目标人物
    target_persons = []
    for c in concls:
        t = c.get("target", "")
        if t.startswith("person:"):
            pid = t[len("person:"):]
            target_persons.append(pid)

    # 关键矛盾（correct=true 且文本有"vs"）
    key_contradictions = []
    for ct in contradictions:
        if ct.get("correct", False) and "vs" in ct.get("text", ""):
            key_contradictions.append(ct["id"])

    # 建议 gate = 第一层结论 id + 最终结论 id + target person id + 关键矛盾 id
    suggested_gates = list(dict.fromkeys(
        first_layer_concls + final_concls + target_persons + key_contradictions
    ))

    return {
        "chain_id": chain_id,
        "name": data.get("name", ""),
        "scene": data.get("scene", ""),
        "core": data.get("core", False),
        "num_hypotheses_true": sum(1 for h in hypos if h.get("kind") == "true"),
        "num_hypotheses_mislead": sum(1 for h in hypos if h.get("kind") == "mislead"),
        "num_conclusions_true": sum(1 for c in concls if c.get("kind") == "true"),
        "num_conclusions_mislead": sum(1 for c in concls if c.get("kind") == "mislead"),
        "first_layer_conclusions": first_layer_concls,
        "final_conclusions": final_concls,
        "target_persons": target_persons,
        "key_contradictions": key_contradictions,
        "suggested_gates": suggested_gates,
        "num_suggested": len(suggested_gates),
    }


def main():
    parser = argparse.ArgumentParser(description="里程碑 gate 半自动派生工具")
    parser.add_argument("--chain", default="", help="只分析指定链（如 CH02）")
    parser.add_argument("--format", choices=["table", "json", "report"], default="table", help="输出格式")
    args = parser.parse_args()

    gd_text = CHAINS_FILE.read_text(encoding="utf-8")
    chains = extract_chains_dict(gd_text)

    if args.chain:
        if args.chain not in chains:
            print(f"错误：未找到链 {args.chain}", file=sys.stderr)
            sys.exit(1)
        chain_ids = [args.chain]
    else:
        chain_ids = list(chains.keys())

    results = []
    for cid in chain_ids:
        results.append(analyze_chain(cid, chains[cid]))

    if args.format == "json":
        print(json.dumps(results, ensure_ascii=False, indent=2))
    elif args.format == "report":
        print_report(results, chains)
    else:
        print_table(results)


def print_table(results):
    header = f"{'链ID':<8} {'场景':<8} {'名称':<25} {'真假设':>4} {'真结论':>4} {'建议gate数':>5}  建议gate列表"
    print(header)
    print("-" * len(header))
    for r in results:
        gates = ", ".join(r["suggested_gates"][:8])
        if len(r["suggested_gates"]) > 8:
            gates += f" ...(+{len(r['suggested_gates'])-8})"
        print(f"{r['chain_id']:<8} {r['scene']:<8} {r['name'][:24]:<25} {r['num_hypotheses_true']:>4} {r['num_conclusions_true']:>4} {r['num_suggested']:>5}  {gates}")


def print_report(results, chains):
    """详细报告：每条链的分析 + 建议 milestone 模板"""
    for r in results:
        print(f"\n{'='*60}")
        print(f"【{r['chain_id']}】{r['name']}  ({r['scene']}, {'core' if r['core'] else 'optional'})")
        print(f"{'='*60}")
        print(f"  规模：{r['num_hypotheses_true']} 真假设 + {r['num_hypotheses_mislead']} 误导假设 / "
              f"{r['num_conclusions_true']} 真结论 + {r['num_conclusions_mislead']} 误导结论")
        print(f"  第一层结论（建议作为独立 milestone）：")
        for cid in r["first_layer_conclusions"]:
            cdata = _find_concl(chains, r["chain_id"], cid)
            text = cdata.get("text", "?") if cdata else "?"
            print(f"    - {cid}: {text}")
        print(f"  最终结论（建议作为关键 milestone）：")
        for cid in r["final_conclusions"]:
            cdata = _find_concl(chains, r["chain_id"], cid)
            text = cdata.get("text", "?") if cdata else "?"
            print(f"    - {cid}: {text}")
        if r["target_persons"]:
            print(f"  目标人物：{', '.join(r['target_persons'])}")
        if r["key_contradictions"]:
            print(f"  关键矛盾点：{', '.join(r['key_contradictions'])}")
        print(f"  → 建议 gate 数：{r['num_suggested']}")
        print(f"  → 建议 milestones（可直接复制进场景脚本）：")
        # 生成建议的 milestone 数组
        for i, gid in enumerate(r["first_layer_conclusions"], 1):
            cdata = _find_concl(chains, r["chain_id"], gid)
            text = cdata.get("text", "?") if cdata else "?"
            # 取结论 id 的场景前缀作为 milestone id 前缀
            prefix = _scene_prefix(r["scene"])
            ms_id = f"{prefix}-{i}G"  # G = generated 标记
            print(f'    {{"id":"{ms_id}","text":"{text[:30]}","gate":["{gid}"]}},')


def _find_concl(chains, chain_id, concl_id):
    wall = chains[chain_id].get("wall", {}).get("battlefield", {})
    for c in wall.get("conclusions", []):
        if c["id"] == concl_id:
            return c
    for h in wall.get("hypotheses", []):
        if h["id"] == concl_id:
            return h
    return None


def _scene_prefix(scene: str) -> str:
    # scene2 → S2, scene3 → S3, etc.
    m = re.search(r'scene(\d+)', scene)
    if m:
        return f"S{m.group(1)}"
    return "S?"


if __name__ == "__main__":
    main()
