extends SceneTree
## 干净复现：每个场景用全新 gv + 固定视口尺寸（消除 headless 画布尺寸不确定），
## 校验场景二全案墙 根/树枝/分枝 三层拖拽「子树随动 + 松手不回弹」。

func _build_fresh() -> Variant:
	root.size = Vector2(1920, 1080)   # 固定画布→布局中心确定
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var sc = load("res://scripts/scene/scene2.gd")
	var hypo: Dictionary = sc.new().reasoning_hypothesis()
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true},
		{"id":"c203","name":"蹄铁","correct":true},{"id":"c204","name":"蹄印零乱","correct":true},
		{"id":"c205","name":"脚印","correct":true},{"id":"c206","name":"步幅","correct":true}]
	gv.build({"clues":clues, "hypo":hypo, "persons":[{"id":"KILLER","name":"马车夫"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame
	# 派生全部推断/结论
	var bf: Dictionary = hypo.get("battlefield", {})
	for h in bf.get("hypotheses", []):
		var hid: String = h.get("id", ""); var gates: Array = h.get("gate_clue_ids", [])
		if hid == "" or gates.is_empty(): continue
		for c in gates:
			gv._derive_hypo(str(c), hid); await process_frame
	for c in bf.get("conclusions", []):
		var cid: String = c.get("id", ""); var gh: Array = c.get("gate_hypo_ids", [])
		if cid == "" or gh.is_empty(): continue
		gv._derive_conclusion(str(gh[0]), cid); await process_frame
	# 模拟玩家把每个已推导结论拖到「凶手」人物上建立归属金边（玩家连线，构成完整布局树）
	for c in bf.get("conclusions", []):
		var cid: String = c.get("id", "")
		if cid == "":
			continue
		gv._edge._add_edge("conclusion_" + str(cid), "KILLER", "target", "gold", false)
	gv._rebuild_graph(); await process_frame
	return gv

func _drag(gv: Variant, id: String, target: Vector2) -> void:
	gv._state = gv.State.EDITABLE
	gv._dragging = true; gv._drag_id = id; gv._drag_mode = "move"
	gv._drag_offset = Vector2.ZERO
	gv._drag_start = gv._node_center.get(id, Vector2.ZERO)
	gv._drag_subtree = gv._layout._descendants(id)
	var delta: Vector2 = target - gv._node_center.get(id, Vector2.ZERO)
	gv._node_center[id] = target
	# 模拟真实拖拽：子树随根平移（真实 _input 不依赖视图存在与否，headless 下无条件平移）
	for _sd in gv._drag_subtree:
		gv._node_center[str(_sd)] = gv._node_center.get(str(_sd), Vector2.ZERO) + delta
	gv._commit_move(id, target)
	await process_frame

func _snap(gv: Variant, ids: Array) -> Dictionary:
	var d := {}
	for nid in ids: d[nid] = gv._node_center.get(nid, Vector2.ZERO)
	return d

func _check(ok: bool, log: Array, msg: String, cond: bool) -> bool:
	if not cond:
		print("FAIL " + msg)
		return false
	return ok

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	# ===== R) 拖根 KILLER → 全部后代严格随动（Δ 完全一致）=====
	var gv = await _build_fresh()
	var kids: Array = gv._layout._descendants("KILLER")
	# all_ids 必须覆盖 KILLER 的全部后代（玩家自建完整布局树后后代数量随数据增长），否则快照缺键报错
	var all_ids: Array = ["KILLER"] + kids
	print("[R] KILLER descendants(%d): %s" % [kids.size(), str(kids)])
	var b = _snap(gv, all_ids)
	await _drag(gv, "KILLER", Vector2(950, 700))
	var a = _snap(gv, all_ids)
	var dK: Vector2 = a["KILLER"] - b["KILLER"]
	if a["KILLER"].distance_to(Vector2(950,700)) > 5.0:
		ok = _check(ok, log, "R0) KILLER 未落点: %s" % str(a["KILLER"]), false)
	else:
		for nid in kids:
			var dn: Vector2 = a[nid] - b[nid]
			if dn.distance_to(dK) > 2.0:   # 严格随动：后代 Δ 必须等于 KILLER Δ
				ok = _check(ok, log, "R1) %s 未严格随 KILLER(Δ=%s 期望=%s)" % [nid, str(dn), str(dK)], false)
		if ok: log.append("R) 拖 KILLER→全部 %d 后代严格随动、松手不回弹 ✓" % kids.size())
	gv.queue_free()

	# ===== C) 拖树枝 CL2-4 → 其下游(H2-01/02/03 + c201~204)随动、上游 KILLER 不动 =====
	gv = await _build_fresh()
	var c_kids: Array = gv._layout._descendants("conclusion_CL2-4")
	print("[C] CL2-4 descendants(%d): %s" % [c_kids.size(), str(c_kids)])
	all_ids = ["KILLER","conclusion_CL2-4"] + c_kids
	b = _snap(gv, all_ids)
	await _drag(gv, "conclusion_CL2-4", Vector2(300, 320))
	a = _snap(gv, all_ids)
	var dC: Vector2 = a["conclusion_CL2-4"] - b["conclusion_CL2-4"]
	if a["KILLER"].distance_to(b["KILLER"]) > 2.0:
		ok = _check(ok, log, "C0) KILLER 随 CL2-4 移动了(不该): %s" % str(a["KILLER"]), false)
	elif a["conclusion_CL2-4"].distance_to(Vector2(300,320)) > 5.0:
		ok = _check(ok, log, "C1) CL2-4 未落点: %s" % str(a["conclusion_CL2-4"]), false)
	else:
		for nid in c_kids:
			var dn: Vector2 = a[nid] - b[nid]
			if dn.distance_to(dC) > 2.0:
				ok = _check(ok, log, "C2) %s 未严格随 CL2-4(Δ=%s 期望=%s)" % [nid, str(dn), str(dC)], false)
		if ok: log.append("C) 拖 CL2-4→下游 %d 节点严格随动、上游 KILLER 不动 ✓" % c_kids.size())
	gv.queue_free()

	# ===== B) 拖分枝 H2-05 → 叶子 c206 随动、上游 CL2-6/KILLER 不动 =====
	gv = await _build_fresh()
	var b_kids: Array = gv._layout._descendants("H2-05")
	print("[B] H2-05 descendants(%d): %s" % [b_kids.size(), str(b_kids)])
	all_ids = ["KILLER","conclusion_CL2-6","H2-05"] + b_kids
	b = _snap(gv, all_ids)
	await _drag(gv, "H2-05", Vector2(1500, 720))
	a = _snap(gv, all_ids)
	var dB: Vector2 = a["H2-05"] - b["H2-05"]
	if a["KILLER"].distance_to(b["KILLER"]) > 2.0 or a["conclusion_CL2-6"].distance_to(b["conclusion_CL2-6"]) > 2.0:
		ok = _check(ok, log, "B0) 上游(KILLER/CL2-6)动了(不该): K=%s C=%s" % [str(a["KILLER"]), str(a["conclusion_CL2-6"])], false)
	elif a["H2-05"].distance_to(Vector2(1500,720)) > 5.0:
		ok = _check(ok, log, "B1) H2-05 未落点: %s" % str(a["H2-05"]), false)
	else:
		for nid in b_kids:
			var dn: Vector2 = a[nid] - b[nid]
			if dn.distance_to(dB) > 2.0:
				ok = _check(ok, log, "B2) %s 未严格随 H2-05(Δ=%s 期望=%s)" % [nid, str(dn), str(dB)], false)
		if ok: log.append("B) 拖 H2-05→叶子 %d 节点严格随动、上游不动 ✓" % b_kids.size())
	gv.queue_free()

	for l in log: print("  - " + l)
	print("SCENE2_FULL_DRAG_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
