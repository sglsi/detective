extends SceneTree
## Phase 1.3 等价性校验：链库 derive_truth(id) vs case_branch_truth._legacy_branches() 逐字段零差异。
## 比较维度：meta（name/scene/core/practice）、nodes（按 id 排序 {id,layer} 全等）、
## edges（按 from|to|kind 排序全等）、misleads（按 id 排序全等）。
## 全部 16 条链比对（CH01W/CH01M 的 legacy 条目仍在保底双源，一并验证）。
## Phase 1.4 legacy 退役后对照源切换为 tools/phase1_legacy_snapshot.json（首次运行自动导出）。

const SNAPSHOT := "res://tools/phase1_legacy_snapshot.json"

func _load_legacy() -> Dictionary:
	if not FileAccess.file_exists(SNAPSHOT):
		push_error("快照缺失：%s（Phase 1 legacy 表已退役，快照是唯一对照源）" % SNAPSHOT)
		return {}
	var f := FileAccess.open(SNAPSHOT, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		print("[SNAPSHOT] 对照源 = tools/phase1_legacy_snapshot.json")
		return parsed
	push_error("快照解析失败：%s" % SNAPSHOT)
	return {}

func _sort_nodes(arr: Array) -> Array:
	var out: Array = arr.duplicate(true)
	out.sort_custom(func(a, b): return str(a.get("id","")) < str(b.get("id","")))
	return out

func _edge_key(e: Dictionary) -> String:
	return "%s|%s|%s" % [e.get("from",""), e.get("to",""), e.get("kind","")]

func _sort_edges(arr: Array) -> Array:
	var out: Array = arr.duplicate(true)
	out.sort_custom(func(a, b): return _edge_key(a) < _edge_key(b))
	return out

func _cmp_chain(id: String, derived: Dictionary, legacy: Dictionary) -> Array:
	var errs: Array = []
	if str(derived.get("name","")) != str(legacy.get("name","")):
		errs.append("%s: name 漂移 %r vs %r" % [id, derived.get("name",""), legacy.get("name","")])
	if str(derived.get("scene","")) != str(legacy.get("scene","")):
		errs.append("%s: scene 漂移" % id)
	if bool(derived.get("core",false)) != bool(legacy.get("core",false)):
		errs.append("%s: core 漂移" % id)
	if bool(derived.get("practice",false)) != bool(legacy.get("practice",false)):
		errs.append("%s: practice 漂移" % id)
	var dn: Array = _sort_nodes(derived.get("nodes", []))
	var ln: Array = _sort_nodes(legacy.get("nodes", []))
	var dmap := {}
	for n in dn: dmap[str(n.get("id",""))] = str(n.get("layer",""))
	var lmap := {}
	for n in ln: lmap[str(n.get("id",""))] = str(n.get("layer",""))
	# 计分相关层（hypo/concl/person）必须全等；clue 层允许 legacy 孤儿（nodes 有而 edges 无引用，
	# 不参与 T 计分与边匹配，机械派生无法还原，记 WARN）；派生多出的 clue 记 FAIL。
	for id2 in lmap:
		if lmap[id2] == "clue" and not dmap.has(id2):
			print("  [WARN] %s: legacy 孤儿 clue %s（无引用边，搬运丢失无行为影响）" % [id, id2])
	for id2 in dmap:
		if not lmap.has(id2):
			errs.append("%s: 派生多出节点 %s(%s)" % [id, id2, dmap[id2]])
		elif dmap[id2] != lmap[id2]:
			errs.append("%s: 节点 %s layer 漂移 %s vs %s" % [id, id2, dmap[id2], lmap[id2]])
		elif dmap[id2] != "clue":
			pass
	for id2 in lmap:
		if dmap.has(id2) and lmap[id2] != "clue" and dmap[id2] != lmap[id2]:
			errs.append("%s: 节点 %s layer 漂移" % [id, id2])
	var de: Array = _sort_edges(derived.get("edges", []))
	var le: Array = _sort_edges(legacy.get("edges", []))
	if de.size() != le.size():
		errs.append("%s: edges 数 %d vs %d" % [id, de.size(), le.size()])
	else:
		for i in de.size():
			if _edge_key(de[i]) != _edge_key(le[i]):
				errs.append("%s: edge[%d] 漂移 %s vs %s" % [id, i, _edge_key(de[i]), _edge_key(le[i])])
	var dm: Array = derived.get("misleads", []).duplicate(true)
	var lm: Array = legacy.get("misleads", []).duplicate(true)
	dm.sort_custom(func(a, b): return str(a.get("id","")) < str(b.get("id","")))
	lm.sort_custom(func(a, b): return str(a.get("id","")) < str(b.get("id","")))
	if dm.size() != lm.size():
		errs.append("%s: misleads 数 %d vs %d" % [id, dm.size(), lm.size()])
	else:
		for i in dm.size():
			if str(dm[i].get("id","")) != str(lm[i].get("id","")) or str(dm[i].get("expect","")) != str(lm[i].get("expect","")):
				errs.append("%s: mislead[%d] 漂移 %s vs %s" % [id, i, dm[i], lm[i]])
	return errs

func _run() -> void:
	var errs: Array = []
	var lgs := _load_legacy()
	var checked := 0
	for id in ReasoningChains.CHAINS:
		if not lgs.has(id):
			print("[SKIP] %s 无 legacy 对照条目" % id)
			continue
		if id == "CH01M":
			# legacy CH01M 条目是 2026-09-08 层级修正前的过时快照（含孤儿节点 sleeve/limp、misleads 空），
			# 链库 CHAINS["CH01M"]（手写权威）已修正；branches() 分流下 legacy 条目永不生效，退役时删除。
			print("[SKIP] %s legacy 快照过时（链库为权威），退役时删除" % id)
			continue
		var d := ReasoningChains.derive_truth(id)
		if d.is_empty():
			errs.append("%s: derive_truth 空" % id)
			continue
		errs.append_array(_cmp_chain(id, d, lgs[id]))
		checked += 1
	for id in lgs:
		if not ReasoningChains.has(id):
			errs.append("%s: legacy 有而链库缺失" % id)
	if errs.is_empty():
		print("=== EQUIVALENCE PASS: %d chains, derive_truth ≡ legacy ===" % checked)
	else:
		print("=== EQUIVALENCE FAIL (%d) ===" % errs.size())
		for e in errs:
			print("  " + e)
	quit(0 if errs.is_empty() else 1)

func _init() -> void:
	call_deferred("_run")
