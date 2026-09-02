extends SceneTree
## 端到端验证「真实拖拽路径」(graph_view_controller._commit_move) 的子树跟随：
## 模拟一次拖动（先把节点位置移到落点，再调 _commit_move），确认其全部后代随上属节点重排。

func _build_wall(persons_arr: Array, hypo: Dictionary) -> Variant:
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv.build({"clues":[{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true}],
		"hypo":hypo,"persons":persons_arr,"focus_person":persons_arr[0].get("id","") if not persons_arr.is_empty() else "",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	return gv

func _drag_node(gv: Variant, id: String, to: Vector2) -> void:
	# 模拟：拖拽期间节点已跟随光标移动到 to；释放时 _commit_move 以 _node_center[id] 为锚。
	gv._node_center[id] = to
	gv._state = gv.State.EDITABLE
	gv._commit_move(id, to)
	await process_frame

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	var hypo1 := {"battlefield":{"hypotheses":[
			{"id":"H2-01","text":"乘马车来","correct":true,"gate_clue_ids":["c201","c202"]}],
		"conclusions":[{"id":"CL2-1","text":"凶手乘出租马车抵达","correct":true,"gate_hypo_ids":["H2-01"],"target":"person:KILLER"}]}}

	# ===== 场景A：拖动人物根(凶手)，其整棵子树(结论→推断→线索)应随动 =====
	var gvA = await _build_wall([{"id":"KILLER","name":"凶手"}], hypo1)
	gvA._derive_hypo("c201", "H2-01"); await process_frame
	gvA._derive_hypo("c202", "H2-01"); await process_frame
	gvA._derive_conclusion("H2-01", "CL2-1"); await process_frame
	gvA._rebuild_graph(); await process_frame

	var before := {}
	for nid in ["KILLER","conclusion_CL2-1","H2-01","c201","c202"]:
		before[nid] = gvA._node_center.get(nid, Vector2.ZERO)
	var target := Vector2(820, 760)
	await _drag_node(gvA, "KILLER", target)
	var after := {}
	for nid in ["KILLER","conclusion_CL2-1","H2-01","c201","c202"]:
		after[nid] = gvA._node_center.get(nid, Vector2.ZERO)
	# 根应落在落点
	if after["KILLER"].distance_to(target) > 5.0:
		ok = false; print("FAIL A0) 凶手未落在落点：%s" % str(after["KILLER"]))
	# 所有后代应随根移动（相对偏移保持一致，整体平移）
	var d0: Vector2 = after["KILLER"] - before["KILLER"]
	for nid in ["conclusion_CL2-1","H2-01","c201","c202"]:
		var dn: Vector2 = after[nid] - before[nid]
		if dn.distance_to(d0) > 60.0:
			ok = false; print("FAIL A1) 后代 %s 未随凶手平移(Δ=%s, 期望≈%s)" % [nid, str(dn), str(d0)])
	if ok:
		log.append("A) 拖动人物根→整棵子树随动(平移量一致) ✓")

	# ===== 场景B：拖动中间节点(结论)，其下游(推断→线索)随动，上游(人物根)不动 =====
	var gvB = await _build_wall([{"id":"KILLER","name":"凶手"}], hypo1)
	gvB._derive_hypo("c201", "H2-01"); await process_frame
	gvB._derive_hypo("c202", "H2-01"); await process_frame
	gvB._derive_conclusion("H2-01", "CL2-1"); await process_frame
	gvB._rebuild_graph(); await process_frame
	var b_before := {}
	for nid in ["KILLER","conclusion_CL2-1","H2-01","c201","c202"]:
		b_before[nid] = gvB._node_center.get(nid, Vector2.ZERO)
	var tgtB := Vector2(900, 300)
	await _drag_node(gvB, "conclusion_CL2-1", tgtB)
	var b_after := {}
	for nid in ["KILLER","conclusion_CL2-1","H2-01","c201","c202"]:
		b_after[nid] = gvB._node_center.get(nid, Vector2.ZERO)
	# 根不动
	if b_after["KILLER"].distance_to(b_before["KILLER"]) > 60.0:
		ok = false; print("FAIL B0) 人物根随结论移动了(不该)：%s" % str(b_after["KILLER"]))
	# 结论落在落点
	if b_after["conclusion_CL2-1"].distance_to(tgtB) > 5.0:
		ok = false; print("FAIL B1) 结论未落在落点：%s" % str(b_after["conclusion_CL2-1"]))
	# 下游(推断+线索)随结论平移
	var d1: Vector2 = b_after["conclusion_CL2-1"] - b_before["conclusion_CL2-1"]
	for nid in ["H2-01","c201","c202"]:
		var dn: Vector2 = b_after[nid] - b_before[nid]
		if dn.distance_to(d1) > 60.0:
			ok = false; print("FAIL B2) 下游 %s 未随结论平移(Δ=%s, 期望≈%s)" % [nid, str(dn), str(d1)])
	if ok:
		log.append("B) 拖动结论→下游随动、上游人物根不动 ✓")

	for l in log: print("  - " + l)
	print("DRAG_FOLLOW_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
