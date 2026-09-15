# 知识库条目回写 · 工具与留痕

参考原典**不在此目录**——它们已统一存放于仓库根 `design_docs/reference_books/`
（书目清单、来源与去重记录见该目录的 `README.md`）。

本目录只保留知识库回写用的工具与审计留痕：

| 文件 | 用途 |
|------|------|
| `_apply_kb_patch.py` | 通用补丁脚本：按补丁 JSON 更新/新增 `data/knowledge/knowledge_base.json` 条目，并自动补 `related` 双向链接、去重排序、重写 JSON |
| `_kb_<书>_patch.json` | 每次精读一本原典后的条目补丁（`update` / `add` 两段），可追溯、可重放 |
| `_kb_fix1.json` | 一次性修正补丁 |

用法：

```bash
python _apply_kb_patch.py _kb_<书>_patch.json
```

设计文档：`godot_project/docs/02_核心设计/05_侦探学方法论知识库.md`

> ⚠️ 改了 `knowledge_base.json` 后，**必须重新导出 Web 包**（该文件在 `res://data/` 下、会被打进 pck），
> 否则浏览器端看不到新条目。详见 `godot-detective-sop` 技能。
