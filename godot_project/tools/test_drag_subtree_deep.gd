extends SceneTree
## 复现场景二推理墙「拖动跟随 / 松手回弹」：模拟真实交互的 _on_node_gui 按下 + _commit_move 松手，
## 覆盖 person(根)→conclusion(树枝)→hypo(分枝)→clue(叶子) 四层，以及多层连续钉位。

func _drag(gv: Variant, id: String, target: Vector2) -> void:
	gv._state = gv.State.EDITABLE
	gv._dragging = true
	gv._drag_id = id
	gv._drag_mode = "move"
	gv._drag_subtree = gv._layout._descendants(id)
	gv._drag_start = gv._node_center.get(id, Vector2.ZERO)
	# 等价模拟 _input MouseMotion：把 id 与整棵子树一并平移 delta（保持拖动中相对偏移）
	var delta: Vector2 = target - gv._node_center.get(id, Vector2.ZERO)
	gv._node_center[id] = target
	for _sd in gv._drag_subtree:
		if gv._node_views.has(str(_sd)):
			gv._node_center[str(_sd)] = gv._node_center.get(str(_sd), Vector2.ZERO) + delta
	gv._commit_move(id)
	await process_frame

func _reset(gv: Variant) -> void:
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	gv._node_offsets = {}
	gv._rebuild_graph()
	await process_frame

func _snap(gv: Variant, ids: Array) -> Dictionary:
	var d := {}
	for nid in ids:
		d[nid] = gv._node_center.get(nid, Vector2.ZERO)
	return d

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var sc = load("res://scripts/scene/scene2.gd")
	var hypo: Dictionary = sc.new().reasoning_hypothesis()
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv.build({"clues":[{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true},
		{"id":"c205","name":"脚印","correct":true},{"id":"c206","name":"步幅","correct":true}],
		"hypo":hypo, "persons":[{"id":"KILLER","name":"马车夫"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame
	gv._derive_hypo("c201", "H2-01"); await process_frame
	gv._derive_hypo("c206", "H2-05"); await process_frame
	gv._derive_hypo("c205", "H2-06"); await process_frame
	gv._derive_conclusion("H2-01", "CL2-1"); await process_frame
	gv._derive_conclusion("H2-05", "CL2-6"); await process_frame
	gv._rebuild_graph(); await process_frame

	# ===== 单拖：根(人物 KILLER) → 整树跟随 =====
	var ids := ["KILLER","conclusion_CL2-6","H2-05","H2-06","c206","c205"]
	var b := _snap(gv, ids)
	await _drag(gv, "KILLER", Vector2(900, 700))
	var a := _snap(gv, ids)
	var d0: Vector2 = a["KILLER"] - b["KILLER"]
	if a["KILLER"].distance_to(Vector2(900,700)) > 5.0:
		ok = false; print("FAIL R0) KILLER 未落点: %s" % str(a["KILLER"]))
	for nid in ["conclusion_CL2-6","H2-05","H2-06","c206","c205"]:
		var dn: Vector2 = a[nid] - b[nid]
		if dn.distance_to(d0) > 60.0:
			ok = false; print("FAIL R1) %s 未随 KILLER 平移(Δ=%s 期望≈%s)" % [nid, str(dn), str(d0)])
	if ok: log.append("R) 拖人物根→整树跟随 ✓")

	# ===== 单拖：树枝(conclusion_CL2-6) → 下游跟随、上游不动 =====
	await _reset(gv)
	b = _snap(gv, ids)
	await _drag(gv, "conclusion_CL2-6", Vector2(300, 300))
	a = _snap(gv, ids)
	if a["KILLER"].distance_to(b["KILLER"]) > 60.0:
		ok = false; print("FAIL C0) KILLER 随结论移动了(不该): %s" % str(a["KILLER"]))
	if a["conclusion_CL2-6"].distance_to(Vector2(300,300)) > 5.0:
		ok = false; print("FAIL C1) CL2-6 未落点: %s" % str(a["conclusion_CL2-6"]))
	var dc: Vector2 = a["conclusion_CL2-6"] - b["conclusion_CL2-6"]
	for nid in ["H2-05","H2-06","c206","c205"]:
		var dn: Vector2 = a[nid] - b[nid]
		if dn.distance_to(dc) > 90.0:
			ok = false; print("FAIL C2) %s 未随 CL2-6 平移(Δ=%s 期望≈%s)" % [nid, str(dn), str(dc)])
	if ok: log.append("C) 拖结论→下游跟随、上游人物不动 ✓")

	# ===== 单拖：分枝(hypo H2-05) → 叶子跟随、上游不动 =====
	await _reset(gv)
	b = _snap(gv, ids)
	await _drag(gv, "H2-05", Vector2(500, 520))
	a = _snap(gv, ids)
	if a["KILLER"].distance_to(b["KILLER"]) > 60.0 or a["conclusion_CL2-6"].distance_to(b["conclusion_CL2-6"]) > 60.0:
		ok = false; print("FAIL B0) 上游(KILLER/CL2-6)动了(不该): K=%s C=%s" % [str(a["KILLER"]), str(a["conclusion_CL2-6"])])
	if a["H2-05"].distance_to(Vector2(500,520)) > 5.0:
		ok = false; print("FAIL B1) H2-05 未落点: %s" % str(a["H2-05"]))
	var dh: Vector2 = a["H2-05"] - b["H2-05"]
	var dl: Vector2 = a["c206"] - b["c206"]
	if dl.distance_to(dh) > 90.0:
		ok = false; print("FAIL B2) 叶子 c206 未随 H2-05 平移(Δ=%s 期望≈%s)" % [str(dl), str(dh)])
	if ok: log.append("B) 拖分枝 H2-05→叶子 c206 跟随、上游不动 ✓")

	# ===== 连续拖：根 KILLER 钉位后，再拖分枝 H2-05（多层钉位顺序） =====
	await _reset(gv)
	b = _snap(gv, ids)
	await _drag(gv, "KILLER", Vector2(880, 680))
	await _drag(gv, "H2-05", Vector2(480, 540))
	a = _snap(gv, ids)
	# H2-05 必须钉在最后落点（不被 KILLER 的 delta 二次移动）
	if a["H2-05"].distance_to(Vector2(480,540)) > 90.0:
		ok = false; print("FAIL M0) H2-05 未停在最后落点(被祖先污染？): %s" % str(a["H2-05"]))
	# c206 应随 H2-05（相对 H2-05 有固定偏移，不因 KILLER 移动而错位）
	var dh2: Vector2 = a["H2-05"] - b["H2-05"]
	var dl2: Vector2 = a["c206"] - b["c206"]
	if dl2.distance_to(dh2) > 120.0:
		ok = false; print("FAIL M1) c206 未随 H2-05 平移(Δ=%s 期望≈%s)" % [str(dl2), str(dh2)])
	# KILLER 在首次落点
	if a["KILLER"].distance_to(Vector2(880,680)) > 5.0:
		ok = false; print("FAIL M2) KILLER 未停在首次落点: %s" % str(a["KILLER"]))
	if ok: log.append("M) 连续拖(根→分枝)多层钉位互不污染 ✓")

	for l in log: print("  - " + l)
	print("SCENE2_DRAG_DEEP_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
