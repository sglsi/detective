extends Control

## test_kb_remote.gd — 验证知识库「外部化 · 按域按需加载」链路（完整项目环境，含 autoload）。
##
## 覆盖：
##   ① 内置基线可用（91 条）—— 离线兜底不退化
##   ② 远端 /kb/manifest.json 可拉取
##   ③ ensure_domain / ensure_all_domains 按域并入且**不重复**、计数与 manifest 对齐
##   ④ 结果落盘 user://kb_cache（下次命中缓存免流量）
##   ⑤ 远端不可达时回落内置基线
##
## 运行（需先在 8099 起 serve_web.py 提供 /kb/）：
##   godot --headless --path <project> res://scenes/test_kb_remote.tscn
## 退出码 0 = PASS。

const REMOTE_PORT := 8099

var _fails: Array[String] = []

func _ready() -> void:
	# 运行期覆盖远端基地址（代码读取的是 ProjectSettings，故可在测试中改写指向临时端口）
	ProjectSettings.set_setting("knowledge/remote_base", "http://127.0.0.1:%d" % REMOTE_PORT)

	var kb = get_node_or_null("/root/KnowledgeBaseSystem")
	if kb == null:
		print("KB_SYS_MISSING")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.5).timeout

	# ① 内置基线
	var base_n: int = kb.entries.size()
	_check(base_n == 91, "基线条目数 == 91（实际 %d）" % base_n)

	# ② 远端 manifest
	var ok: bool = await kb.refresh_manifest(true)
	_check(ok, "远端 manifest 拉取成功（127.0.0.1:%d）" % REMOTE_PORT)
	if ok:
		_check(str(kb.manifest_version()) != "", "manifest.version = %s" % kb.manifest_version())

	# ③ 单域按需拉取
	var ok_l: bool = await kb.ensure_domain("KB-L")
	var n_l: int = kb.browse_domain("KB-L").size()
	_check(ok_l, "ensure_domain(KB-L) 成功")
	_check(n_l == 21, "KB-L 条目数 == 21（实际 %d）" % n_l)

	# ③b 全量同步：总数不变、无重复、幂等
	await kb.ensure_all_domains()
	var n_all: int = kb.entries.size()
	_check(n_all == 91, "ensure_all 后总数仍 == 91（实际 %d）" % n_all)
	_check(_count_duplicates(kb.entries) == 0, "条目 id 无重复")

	await kb.ensure_all_domains()
	_check(kb.entries.size() == 91, "二次 ensure_all 幂等，总数仍 == 91（实际 %d）" % kb.entries.size())

	if ok:
		var bad: Array[String] = []
		for d in kb.manifest.get("domains", []):
			var did: String = str(d.get("id", ""))
			var want: int = int(d.get("count", -1))
			var got: int = kb.browse_domain(did).size()
			if got != want:
				bad.append("%s(%d!=%d)" % [did, got, want])
		_check(bad.is_empty(), "各域计数与 manifest 对齐%s" % ("" if bad.is_empty() else "：" + ", ".join(PackedStringArray(bad))))

	# ④ 缓存落盘
	_check(FileAccess.file_exists("user://kb_cache/manifest.json"), "manifest 已缓存到 user://kb_cache")
	_check(FileAccess.file_exists("user://kb_cache/KB-L.json"), "KB-L 已缓存到 user://kb_cache")

	# ⑤ 远端不可达 → 回落基线
	kb.reset_to_baseline()
	_check(kb.entries.size() == 91, "reset_to_baseline 恢复 91 条（实际 %d）" % kb.entries.size())
	ProjectSettings.set_setting("knowledge/remote_base", "http://127.0.0.1:59999")
	var off_ok: bool = await kb.refresh_manifest(true)
	_check(not off_ok, "远端不可达时 refresh_manifest 返回 false")
	_check(kb.entries.size() >= 91, "离线时基线仍完整（实际 %d）" % kb.entries.size())

	print("KB_REMOTE_FAILS: %d" % _fails.size())
	for f in _fails:
		print("   FAIL: " + f)
	print("KB_REMOTE_RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _count_duplicates(arr: Array) -> int:
	var seen: Dictionary = {}
	var dup: int = 0
	for e in arr:
		var eid: String = str(e.get("id", ""))
		if seen.has(eid):
			dup += 1
		else:
			seen[eid] = true
	return dup

func _check(cond: bool, label: String) -> void:
	print(("   ok  " if cond else "  FAIL ") + label)
	if not cond:
		_fails.append(label)
