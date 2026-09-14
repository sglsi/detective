# -*- coding: utf-8 -*-
"""通用补丁脚本：按 <patch_json> 更新（update）与新增（add）知识库条目。
用法： python _apply_kb_patch.py _kb_gross_patch.json
"""
import json
import sys

P = r'D:/AI/detective/godot_project/data/knowledge/knowledge_base.json'
ORDER = ["id", "domain", "subdomain", "title", "keywords", "summary", "body",
         "related", "tags", "era", "source", "limitation", "case_ref"]


def fmt(e):
    keys = [k for k in ORDER if k in e]
    lines = []
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        lines.append('    %s: %s%s' % (json.dumps(k, ensure_ascii=False),
                                       json.dumps(e[k], ensure_ascii=False), comma))
    return "  {\n" + "\n".join(lines) + "\n  }"


def main():
    patch_path = sys.argv[1] if len(sys.argv) > 1 else '_kb_gross_patch.json'
    d = json.load(open(P, encoding="utf-8"))
    idx = {e["id"]: e for e in d}
    patch = json.load(open(patch_path, encoding="utf-8"))

    for u in patch.get("update", []):
        e = idx.get(u["id"])
        if not e:
            print("MISS: %s" % u["id"]); continue
        for k, v in u.items():
            if k == "id":
                continue
            e[k] = v
        print("updated: %s" % u["id"])

    for a in patch.get("add", []):
        if a["id"] in idx:
            print("SKIP_EXISTS: %s" % a["id"]); continue
        d.append(a)
        idx[a["id"]] = a
        print("added   : %s | %s" % (a["id"], a.get("title", "")))

    # related 双向补全 + 去重排序
    for e in d:
        for r in list(e.get("related", [])):
            if r in idx:
                back = idx[r].setdefault("related", [])
                if e["id"] not in back:
                    back.append(e["id"])
    for e in d:
        if "related" in e:
            e["related"] = sorted({r for r in e["related"] if r in idx and r != e["id"]})

    out = "[\n" + ",\n".join(fmt(e) for e in d) + "\n]\n"
    json.loads(out)
    open(P, "w", encoding="utf-8").write(out)
    print("TOTAL_ENTRIES=%d" % len(d))


if __name__ == "__main__":
    main()
