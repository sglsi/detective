extends SceneTree

## test_knowledge_extend.gd — 阶段1 回归测试
## 验证 KB-H~L（侦探学方法论扩展域）已接入且可检索/浏览，且既有 KB-A~G 条目不受影响。
## 运行： godot --headless --script res://tools/test_knowledge_extend.gd --path <project>
## 退出码 0 = PASS。

func _initialize() -> void:
	var KB = load("res://autoload/knowledge_base_system.gd").new()
	KB._load_external()

	var ok := true
	print("ENTRIES_TOTAL: ", KB.entries.size())

	# 1) 五个新域必须已在 DOMAINS 中定义且有条目
	var new_domains := ["KB-H", "KB-I", "KB-J", "KB-K", "KB-L"]
	for d in new_domains:
		if not KB.DOMAINS.has(d):
			print("MISSING_DOMAIN: ", d); ok = false; continue
		var lst: Array = KB.browse_domain(d)
		print("BROWSE %s (%s) -> %d 条" % [d, KB.domain_name(d), lst.size()])
		if lst.is_empty():
			print("EMPTY_DOMAIN: ", d); ok = false

	# 2) 既有域仍完好（条目数不为 0）
	for d in ["KB-A", "KB-B", "KB-C", "KB-D", "KB-E", "KB-F", "KB-G"]:
		var lst: Array = KB.browse_domain(d)
		if lst.is_empty():
			print("LEGACY_EMPTY: ", d); ok = false
	print("LEGACY_OK: ", ok)

	# 3) 检索命中（普通模式）
	for q in ["指纹", "枪伤", "天生犯罪人", "证词", "苏格兰场", "死亡时间"]:
		var res: Array = KB.search(q, 1)
		print("SEARCH 「%s」 -> %d 条" % [q, res.size()])
		if res.is_empty():
			print("SEARCH_MISS: ", q); ok = false

	# 4) 每条新条目必须有 source（可溯源）
	for d in new_domains:
		for e in KB.browse_domain(d):
			var src: String = str(e.get("source", ""))
			if src == "":
				print("NO_SOURCE: ", e.get("id", "?")); ok = false

	# 4b) related 双向性 + 无悬空引用（全库）
	var by_id: Dictionary = {}
	for e in KB.entries:
		by_id[str(e.get("id", ""))] = e
	var broken: int = 0
	for e in KB.entries:
		var eid: String = str(e.get("id", ""))
		for r in e.get("related", []):
			var rid: String = str(r)
			if not by_id.has(rid):
				print("DANGLING_RELATED: %s -> %s" % [eid, rid]); broken += 1; continue
			var back: Array = by_id[rid].get("related", [])
			if not back.has(eid):
				print("NOT_BIDIRECTIONAL: %s -> %s" % [eid, rid]); broken += 1
	print("RELATED_BROKEN: ", broken)
	if broken > 0:
		ok = false

	# 4c) 新域条目元数据覆盖（case_ref 必须齐全；limitation 统计）
	var cr: int = 0
	var lim: int = 0
	var total_new: int = 0
	for d in new_domains:
		for e in KB.browse_domain(d):
			total_new += 1
			if str(e.get("case_ref", "")) != "": cr += 1
			if str(e.get("limitation", "")) != "": lim += 1
	print("NEW_META: total=%d, case_ref=%d, limitation=%d" % [total_new, cr, lim])
	if cr < total_new:
		print("CASE_REF_INCOMPLETE"); ok = false

	# 5) 域计数
	print("DOMAIN_COUNT: ", KB.DOMAINS.size())
	if KB.DOMAINS.size() < 12:
		print("DOMAIN_COUNT_TOO_LOW"); ok = false

	print("KB_EXTEND_RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
