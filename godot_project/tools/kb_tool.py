#!/usr/bin/env python3
"""kb_tool.py — 推理知识库「分层」维护工具

设计目标（见《05_侦探学方法论知识库.md》与知识库外部化方案）：
把知识库拆成**按域的小文件**，使其脱离 pck —— 更新知识库时只需改 kb/KB-*.json
并刷新 manifest 版本号，重新上传即可生效，**无需重导出 pck、无需玩家重下 170MB 包**。

目录约定：
  data/knowledge/knowledge_base.json   # 内置基线（随 pck 打包，离线兜底）
  data/knowledge/kb/manifest.json      # 版本 + 各域文件清单/校验
  data/knowledge/kb/KB-A.json ...      # 各域条目数组（权威源，可直接编辑）

命令：
  split  —— knowledge_base.json → kb/（首次拆分，或从基线重建）
  merge  —— kb/ → knowledge_base.json（重导出 pck 前刷新内置基线）
  bump   —— 仅刷新 manifest.version（手工编辑 kb/KB-*.json 后调用）
  check  —— 校验两层一致性（域、条目数、id 集合、sha1）
"""
import argparse
import hashlib
import json
import os
import re
import sys
import datetime

# 仅匹配「单个字符串字面量（可带尾逗号）」的行——用于把扁平字符串数组塌缩回单行
# （仓库既有的 knowledge_base.json 采用内联风格；不塌缩会产生上千行纯格式 diff）。
_ELEM_RE = re.compile(r'^\s*"(?:[^"\\]|\\.)*"\s*,?\s*$')


def _collapse_flat_arrays(text):
    """把仅含字符串元素的多行数组塌缩为单行，其余内容原样保留。"""
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.rstrip()
        if s.endswith("[") and ":" in s:
            items = []
            closing = None
            j = i + 1
            while j < len(lines):
                t = lines[j]
                ts = t.strip()
                if ts in ("]", "],"):
                    closing = "," if ts.endswith(",") else ""
                    break
                if not _ELEM_RE.match(t):
                    items = None
                    break
                items.append(ts.rstrip(",").strip())
                j += 1
            if items is not None and closing is not None:
                # s 自带缩进，勿再前置 indent（否则双缩进）
                out.append(s[:-1].rstrip() + " [" + ", ".join(items) + "]" + closing)
                i = j + 1
                continue
        out.append(line)
        i += 1
    return "\n".join(out)

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.dirname(TOOLS_DIR)
DATA_DIR = os.path.join(PROJ_DIR, "data", "knowledge")
MONO = os.path.join(DATA_DIR, "knowledge_base.json")
KBDIR = os.path.join(DATA_DIR, "kb")
MANIFEST = os.path.join(KBDIR, "manifest.json")

SCHEMA = 1

# 域顺序与显示名（必须与 autoload/knowledge_base_system.gd 的 DOMAINS 一致）
DOMAIN_ORDER = [
    ("KB-A", "人体观察与社会身份"),
    ("KB-B", "交通工具与工程测量"),
    ("KB-C", "化学与毒物学"),
    ("KB-D", "语言与书写文化"),
    ("KB-E", "侦查方法与证词分析"),
    ("KB-F", "维多利亚时代社会背景"),
    ("KB-G", "伦敦城市交通与城市环境"),
    ("KB-H", "侦查学总纲与现场勘查"),
    ("KB-I", "身份识别技术"),
    ("KB-J", "犯罪学理论与时代观念"),
    ("KB-K", "侦探职业与警务实务"),
    ("KB-L", "法医学与尸体检验"),
]
DOMAIN_NAMES = dict(DOMAIN_ORDER)


def _read_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _write_json(path, obj, crlf=False, collapse=False):
    text = json.dumps(obj, ensure_ascii=False, indent=2)
    if collapse:
        text = _collapse_flat_arrays(text)
    if crlf:
        text = text.replace("\r\n", "\n").replace("\n", "\r\n")
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)
    return text


def _sha1_short(path, n=12):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:n]


def _now_version():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S")


def _domain_file(dom):
    return "%s.json" % dom


def cmd_split(args):
    """knowledge_base.json → kb/（按域拆分 + 生成 manifest）"""
    if not os.path.isfile(MONO):
        print("[ERR] 找不到 %s" % MONO)
        return 1
    entries = _read_json(MONO)
    if not isinstance(entries, list):
        print("[ERR] 内置 JSON 顶层不是数组")
        return 1

    os.makedirs(KBDIR, exist_ok=True)
    by_dom = {}
    for e in entries:
        by_dom.setdefault(e.get("domain", ""), []).append(e)

    unknown = sorted(d for d in by_dom if d not in DOMAIN_NAMES)
    if unknown:
        print("[WARN] 未知域（将保留在 manifest 末尾）：%s" % ", ".join(unknown))

    domains = []
    for dom, name in DOMAIN_ORDER + [(d, d) for d in unknown]:
        items = by_dom.get(dom, [])
        path = os.path.join(KBDIR, _domain_file(dom))
        _write_json(path, items)
        domains.append({
            "id": dom,
            "name": name,
            "file": _domain_file(dom),
            "count": len(items),
            "hash": _sha1_short(path),
        })
        print("  %-5s %-5d entries  ->  %s" % (dom, len(items), _domain_file(dom)))

    manifest = {
        "schema": SCHEMA,
        "version": args.version or _now_version(),
        "domain_count": len(domains),
        "entry_count": len(entries),
        "domains": domains,
    }
    _write_json(MANIFEST, manifest)
    print("[OK] split: %d 域 / %d 条  version=%s" % (len(domains), len(entries), manifest["version"]))
    return 0


def _load_kb_dir():
    """读取 manifest + 各域文件，返回 (manifest, {dom: [entries]})"""
    if not os.path.isfile(MANIFEST):
        return None, {}
    manifest = _read_json(MANIFEST)
    by_dom = {}
    for d in manifest.get("domains", []):
        path = os.path.join(KBDIR, d["file"])
        by_dom[d["id"]] = _read_json(path) if os.path.isfile(path) else []
    return manifest, by_dom


def cmd_merge(args):
    """kb/ → knowledge_base.json（按 manifest 域顺序拼接）"""
    manifest, by_dom = _load_kb_dir()
    if manifest is None:
        print("[ERR] 找不到 %s，先跑 split" % MANIFEST)
        return 1
    out = []
    for d in manifest.get("domains", []):
        out.extend(by_dom.get(d["id"], []))

    # 保持既有文件中的条目顺序（新条目按域序追加）：避免每次 merge 都把跨域交错的
    # 历史顺序重排成域序，产生数百行无意义 diff。游戏侧会按域自行排序，不依赖文件序。
    prev_order = {}
    if os.path.isfile(MONO):
        try:
            for i, e in enumerate(_read_json(MONO)):
                prev_order[e.get("id")] = i
        except Exception:
            prev_order = {}
    if prev_order:
        for idx, e in enumerate(out):
            e["__ord"] = prev_order.get(e.get("id"), 10 ** 6 + idx)
        out.sort(key=lambda e: e["__ord"])
        for e in out:
            e.pop("__ord", None)

    _write_json(MONO, out, crlf=args.crlf, collapse=True)
    print("[OK] merge: %d 条 -> knowledge_base.json (version=%s)" % (len(out), manifest.get("version")))
    return 0


def cmd_bump(args):
    """仅刷新 manifest.version，并重算各域 hash/count（配合手工编辑 kb/KB-*.json）"""
    manifest, _ = _load_kb_dir()
    if manifest is None:
        print("[ERR] 找不到 %s" % MANIFEST)
        return 1
    for d in manifest.get("domains", []):
        path = os.path.join(KBDIR, d["file"])
        if not os.path.isfile(path):
            print("[WARN] 缺文件 %s" % d["file"])
            continue
        d["count"] = len(_read_json(path))
        d["hash"] = _sha1_short(path)
    manifest["entry_count"] = sum(d.get("count", 0) for d in manifest.get("domains", []))
    manifest["version"] = args.version or _now_version()
    _write_json(MANIFEST, manifest)
    print("[OK] bump: version=%s, entry_count=%d" % (manifest["version"], manifest["entry_count"]))
    return 0


def cmd_check(args):
    """校验 kb/ 与 knowledge_base.json 两层一致性"""
    manifest, by_dom = _load_kb_dir()
    if manifest is None:
        print("[ERR] 找不到 kb/manifest.json")
        return 1
    ok = True

    kb_ids, kb_doms = [], {}
    for d in manifest.get("domains", []):
        items = by_dom.get(d["id"], [])
        kb_doms[d["id"]] = len(items)
        for e in items:
            if e.get("domain") != d["id"]:
                print("[ERR] 域错配：%s 出现在 %s.json" % (e.get("id"), d["id"]))
                ok = False
            kb_ids.append(e.get("id"))
        path = os.path.join(KBDIR, d["file"])
        if os.path.isfile(path):
            h = _sha1_short(path)
            if h != d.get("hash"):
                print("[ERR] hash 过期：%s（manifest=%s 实际=%s）→ 跑 bump" % (d["id"], d.get("hash"), h))
                ok = False
        if len(items) != d.get("count"):
            print("[ERR] 条目数不符：%s（manifest=%s 实际=%d）" % (d["id"], d.get("count"), len(items)))
            ok = False

    duplicates = sorted({i for i in kb_ids if kb_ids.count(i) > 1})
    if duplicates:
        print("[ERR] 重复 id：%s" % ", ".join(duplicates))
        ok = False

    if os.path.isfile(MONO):
        mono = _read_json(MONO)
        m_ids = [e.get("id") for e in mono]
        if sorted(m_ids) != sorted(kb_ids):
            only_mono = sorted(set(m_ids) - set(kb_ids))
            only_kb = sorted(set(kb_ids) - set(m_ids))
            print("[WARN] 内置基线与 kb/ 不一致（基线为导出快照，属正常）")
            if only_mono:
                print("       仅基线有：%s" % ", ".join(only_mono[:12]))
            if only_kb:
                print("       仅 kb/ 有：%s" % ", ".join(only_kb[:12]))
        else:
            print("[OK] 内置基线与 kb/ 条目集合一致（%d 条）" % len(m_ids))

    print("[%s] check: %d 域 / %d 条  version=%s"
          % ("PASS" if ok else "FAIL", len(manifest.get("domains", [])), len(kb_ids), manifest.get("version")))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description="推理知识库分层维护工具")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("split", help="knowledge_base.json → kb/")
    p.add_argument("--version", default="", help="指定 manifest 版本号（默认 UTC 时间戳）")
    p.set_defaults(func=cmd_split)
    p = sub.add_parser("merge", help="kb/ → knowledge_base.json")
    p.add_argument("--crlf", action="store_true", help="输出 CRLF（保持仓库既有行尾风格）")
    p.set_defaults(func=cmd_merge)
    p = sub.add_parser("bump", help="刷新 manifest 版本号与 hash/count")
    p.add_argument("--version", default="", help="指定版本号（默认 UTC 时间戳）")
    p.set_defaults(func=cmd_bump)
    p = sub.add_parser("check", help="校验两层一致性")
    p.set_defaults(func=cmd_check)
    args = ap.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
