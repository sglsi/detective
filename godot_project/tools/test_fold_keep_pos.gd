extends SceneTree
## 回归：折叠/展开**保持位置**（思傅 2026-09-22 需求）。
## 需求：折叠后链路留在原位（折叠后占位变小，位置一变就难找；展开又得变回来，来回变动不利查阅）。
## 用真实华生教学墙（CH01W）验证三种场景：
##   A 折叠后：其余可见节点位置**逐点不变**；折叠根仍可见、位置不变
##   B 展开后：全部节点位置**逐点还原**、零重叠
##   C 折叠态移动人物后再展开：恢复子树相对折叠根的**偏移与折叠前一致**（形状保持，链随人物走）
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)


func _snap(gv: Object) -> Dictionary:
	var out := {}
	for k in gv._node_center.keys():
		out[str(k)] = gv._node_center[k]
	return out


## 返回偏移超过 tol 的节点（{id: 偏移量}）
func _dev(a: Dictionary, b: Dictionary, tol: float = 0.5) -> Dictionary:
	var out := {}
	for k in a.keys():
		if not b.has(k):
			out[k] = Vector2(9999, 9999)
			continue
		if a[k].distance_to(b[k]) > tol:
			out[k] = a[k] - b[k]
	return out


func _overlaps(gv: Object) -> Array:
	var ids: Array = gv._node_center.keys()
	ids.sort()
	var ov := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var pa: Vector2 = gv._node_center[ids[i]]
			var pb: Vector2 = gv._node_center[ids[j]]
			if absf(pa.x - pb.x) < 260.0 and absf(pa.y - pb.y) < 400.0:
				ov.append("%s×%s" % [ids[i], ids[j]])
	return ov


var _gv: Object
var _fold_id := "conclusion_C-B1"


func _build_wall() -> void:
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var RC = load("res://data/reasoning_chains.gd")
	_gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(_gv)
	await process_frame

	var wall: Dictionary = RC.build_wall_dict("CH01W")
	var bf: Dictionary = wall.get("battlefield", {})
	var persons := [{"id": "NPC_WT", "name": "华生"}]
	var conclusions: Array = bf.get("conclusions", [])
	var hypos: Array = bf.get("hypotheses", [])
	var clues := [
		{"id": "wrist", "name": "手腕肤色分界"},
		{"id": "face_dark", "name": "面色黝黑"},
		{"id": "pose", "name": "军人站姿"},
		{"id": "medical", "name": "医疗行业痕迹"},
		{"id": "arm", "name": "左臂旧伤"},
		{"id": "face_haggard", "name": "面容憔悴"},
	]
	var relations := []
	for h in hypos:
		var hid: String = str(h.get("id", ""))
		for cstr in h.get("gate_clue_ids", []):
			relations.append({"from": str(cstr), "to": hid, "kind": "support"})
	for c in conclusions:
		var cid: String = str(c.get("id", ""))
		var nid: String = "conclusion_" + cid
		for g in c.get("gate_hypo_ids", []):
			var gstr: String = str(g)
			relations.append({"from": gstr, "to": nid, "kind": "support"})
		var tgt: String = str(c.get("target", ""))
		if tgt.begins_with("person:"):
			relations.append({"from": nid, "to": "NPC_WT", "kind": "target"})

	_gv.build({
		"clues": clues,
		"hypo": {"title": "", "persons": persons, "battlefield": bf},
		"persons": persons,
		"focus_person": "NPC_WT",
		"difficulty": _gv.Diff.NORMAL,
		"editable": true,
		"state_store": {},
		"relations": relations,
		"auto_fold": false,
		"case_wide": false,
		"teaching": true,
	})
	var dcs := []
	for cid in conclusions:
		dcs.append({"id": str(cid.get("id", ""))})
	_gv._derived_conclusions = dcs
	for h in hypos:
		_gv._graph_nodes.append({"id": str(h.get("id", "")), "kind": "hypo", "label": str(h.get("id", "")), "sub": "推断", "data": {}})
	_gv._rebuild_graph()
	await process_frame


func _initialize() -> void:
	await process_frame
	await _build_wall()
	var p0: Dictionary = _snap(_gv)
	var restored: Array = []
	for d in _gv._layout._descendants(_fold_id):
		restored.append(str(d))
	print("可见节点 %d 个；折叠根=%s，其下游 %d 个：%s" % [p0.size(), _fold_id, restored.size(), str(restored)])

	# ---- A 折叠：其余可见节点位置不变 ----
	_gv.toggle_fold(_fold_id)
	await process_frame
	var p1: Dictionary = _snap(_gv)
	var d1: Dictionary = _dev(p1, p0)
	_chk(d1.is_empty(), "A 折叠后其余可见节点位置逐点不变（可见 %d；偏移者 %s）" % [p1.size(), str(d1.keys())])
	_chk(p1.has(_fold_id), "A 折叠根仍可见且有位置")
	_chk(p1.size() < p0.size(), "A 折叠确实隐藏了下游（%d → %d）" % [p0.size(), p1.size()])
	var hid_ok := true
	for rid in restored:
		if not _gv._all_positions.has(rid):
			hid_ok = false
	_chk(hid_ok, "A 隐藏节点位置已缓存（展开可还原）")

	# ---- B 展开：位置逐点还原 ----
	_gv.toggle_fold(_fold_id)
	await process_frame
	var p2: Dictionary = _snap(_gv)
	var d2: Dictionary = _dev(p2, p0)
	_chk(d2.is_empty(), "B 展开后全部节点位置逐点还原%s" % ("" if d2.is_empty() else "；偏移：" + str(d2)))
	_chk(_overlaps(_gv).is_empty(), "B 展开后零重叠%s" % ("" if _overlaps(_gv).is_empty() else "；" + str(_overlaps(_gv))))

	# ---- C 折叠态移动人物 → 展开：子树相对折叠根的偏移不变 ----
	_gv.toggle_fold(_fold_id)
	await process_frame
	var person0: Vector2 = _gv._all_positions.get("NPC_WT", Vector2.ZERO)
	_gv._root_anchor_pos["NPC_WT"] = person0 + Vector2(-900.0, 520.0)   # 模拟玩家把人物拖走
	if not _gv._manual_nodes.has("NPC_WT"):
		_gv._manual_nodes.append("NPC_WT")
	_gv._rebuild_graph()
	await process_frame
	_gv.toggle_fold(_fold_id)
	await process_frame
	var p3: Dictionary = _snap(_gv)
	var moved_root: bool = p3.has(_fold_id) and p0.has(_fold_id) and p3[_fold_id].distance_to(p0[_fold_id]) > 100.0
	_chk(moved_root, "C 折叠态移动人物后，折叠根确实随人物移动（%.0f px）" %
		(p3[_fold_id].distance_to(p0[_fold_id]) if (p3.has(_fold_id) and p0.has(_fold_id)) else 0.0))
	var bad_rel := []
	for rid in restored:
		if not (p3.has(rid) and p0.has(rid)):
			bad_rel.append("%s 缺失" % rid)
			continue
		var rel_new: Vector2 = p3[rid] - p3[_fold_id]
		var rel_old: Vector2 = p0[rid] - p0[_fold_id]
		if rel_new.distance_to(rel_old) > 0.5:
			bad_rel.append("%s(Δ%.0f)" % [rid, rel_new.distance_to(rel_old)])
	_chk(bad_rel.is_empty(), "C 恢复子树相对折叠根的偏移与折叠前一致（形状保持）%s" % ("" if bad_rel.is_empty() else "；" + str(bad_rel.slice(0, 6))))
	_chk(_overlaps(_gv).is_empty(), "C 零重叠%s" % ("" if _overlaps(_gv).is_empty() else "；" + str(_overlaps(_gv))))

	print("FOLD_KEEP_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
