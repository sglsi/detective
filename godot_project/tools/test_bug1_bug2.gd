extends SceneTree

static func _gcenter(gv, nid: String) -> Vector2:
	var n = gv._node_views.get(nid)
	if n == null or not is_instance_valid(n): return Vector2.ZERO
	return gv._canvas.get_global_transform() * (n.position + n.size * 0.5)

## 复现两个 BUG：
##  BUG1：把结论拖到人物（反向拖：人物→结论）时，_add_edge 只交换端点、不修正 kind，
##        结论→人物边被记成 support/relate，验证器按 kind=="target" 比对失败 → 误报"未连接到华生"。
##  BUG2：结论由结论推导（conclusion→conclusion，同 ring_depth）时，_direct_outer_neighbors 用 ring 深度过滤，
##        子节点同 ring(rd1) 不算外层邻居 → 该结论无折叠控件、不能折叠其下子树。
func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	# scene1 CH01W 结构（6 结论，C-MAIN 由结论 C-A2/C-B1/C-C2 共推，且锚华生）
	var clues := [
		{"id":"wrist","name":"手腕晒痕"},{"id":"face_dark","name":"脸色黝黑"},
		{"id":"pose","name":"军人站姿"},{"id":"medical","name":"消毒液气味"},
		{"id":"arm","name":"左臂旧伤"},{"id":"face_haggard","name":"面容憔悴"},
	]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"热带生活过","correct":true,"gate_clue_ids":["wrist","face_dark"]},
		{"id":"W-B1","text":"军人气质","correct":true,"gate_clue_ids":["pose"]},
		{"id":"W-B2","text":"医疗行业","correct":true,"gate_clue_ids":["medical"]},
		{"id":"W-C1","text":"左臂受伤","correct":true,"gate_clue_ids":["arm"]},
		{"id":"W-C2","text":"久病初愈","correct":true,"gate_clue_ids":["face_haggard"]},
	],"conclusions":[
		{"id":"C-A1","text":"在热带生活过","correct":true,"gate_hypo_ids":["W-A1"]},
		{"id":"C-A2","text":"殖民地是阿富汗","correct":true,"gate_hypo_ids":["conclusion_C-A1"]},
		{"id":"C-B1","text":"是名军医","correct":true,"gate_hypo_ids":["W-B1","W-B2"]},
		{"id":"C-C1","text":"承受伤痛","correct":true,"gate_hypo_ids":["W-C1","W-C2"]},
		{"id":"C-C2","text":"伤害来自军事任务","correct":true,"gate_hypo_ids":["conclusion_C-C1"]},
		{"id":"C-MAIN","text":"在阿富汗服役过","correct":true,"gate_hypo_ids":["conclusion_C-A2","conclusion_C-B1","conclusion_C-C2"],"target":"person:NPC_WT"},
	]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false,"scene_id":"scene1"})
	await process_frame

	# 玩家推导 6 条结论（生成 conclusion_* 节点 + support 父边）
	for _cid in ["C-A1","C-A2","C-B1","C-C1","C-C2"]:
		var _src := ""
		match _cid:
			"C-A1": _src = "W-A1"
			"C-A2": _src = "conclusion_C-A1"
			"C-B1": _src = "W-B1"
			"C-C1": _src = "W-C1"
			"C-C2": _src = "conclusion_C-C1"
		gv._derive_conclusion(_src, _cid)
		await process_frame
	# C-MAIN 由结论 C-A2/C-B1/C-C2 三线共推（与真相表同源）→ C-MAIN 为三者之父、可折叠其下整棵子树
	for _src2 in ["conclusion_C-A2", "conclusion_C-B1", "conclusion_C-C2"]:
		gv._derive_conclusion(_src2, "C-MAIN")
		await process_frame
	gv._rebuild_graph()
	await process_frame

	# ===== BUG2 复现（先测，保全图 support 边）：C-MAIN 由结论推导，应有折叠控件 =====
	print("=== BUG2: conclusion_C-MAIN 折叠控件 ===")
	var _po: Dictionary = gv._layout._build_parent_of()
	print("  DEBUG parent_of: C-A2=%s C-B1=%s C-C1=%s C-C2=%s C-MAIN=%s" % [
		_po.get("conclusion_C-A2", "?"), _po.get("conclusion_C-B1", "?"),
		_po.get("conclusion_C-C1", "?"), _po.get("conclusion_C-C2", "?"), _po.get("conclusion_C-MAIN", "?")])
	print("  DEBUG relations count=%d" % gv._relations.size())
	var _don: Array = gv._fold._direct_outer_neighbors("conclusion_C-MAIN")
	print("  _direct_outer_neighbors(conclusion_C-MAIN) = " + str(_don))
	if _don.is_empty():
		ok = false
		print("  FAIL BUG2) conclusion_C-MAIN 无外层邻居 → 没有折叠控件，不能折叠其下子树")
	else:
		print("  - BUG2 修复后外层邻居=%s ✓" % _don)
	var _has_fc: bool = gv._fold_controls.has("conclusion_C-MAIN")
	print("  _fold_controls.has(conclusion_C-MAIN) = " + str(_has_fc))
	if not _has_fc and not _don.is_empty():
		ok = false
		print("  FAIL BUG2) 有外层邻居但折叠控件未创建")

	# ===== BUG1 复现：用真实拖拽路径 _commit_move 驱动（正向：结论→人物；反向：人物→结论）=====
	# 旧 bug：反向拖（人物→结论）时 _commit_move 走 drop_kind=="conclusion" 分支，
	# _edge._add_edge(person, conclusion, _drag_kind) → 交换端点但 kind 不变 → 记成 support，验证器误报。

	print("=== BUG1: 反向拖（人物 NPC_WT → 结论 C-MAIN）===")
	gv._relations = []
	gv._rebuild_graph()
	await process_frame
	var _cm_g: Vector2 = _gcenter(gv, "conclusion_C-MAIN")
	gv._drag_start = Vector2(5, 5)
	gv._commit_move("NPC_WT", _cm_g)
	await process_frame
	var _rel_rev := {}
	for _r in gv._relations:
		if "C-MAIN" in str(_r.from) + str(_r.to) and "NPC_WT" in str(_r.from) + str(_r.to):
			_rel_rev = _r
	print("  反向 关系: " + str(_rel_rev))
	if str(_rel_rev.get("kind","")) != "target":
		ok = false
		print("  FAIL BUG1-反向) kind=%s（应为 target），验证器按 target 比对会判定为未连接" % str(_rel_rev.get("kind","")))
	else:
		print("  - 反向 kind=target ✓（修复后不论拖拽方向都强制 target 金边）")

	print("=== BUG1: 正向拖（结论 C-MAIN → 人物 NPC_WT）===")
	gv._relations = []
	gv._rebuild_graph()
	await process_frame
	var _person_g: Vector2 = _gcenter(gv, "NPC_WT")
	gv._drag_start = Vector2(5, 5)
	gv._commit_move("conclusion_C-MAIN", _person_g)
	await process_frame
	var _rel_fwd := {}
	for _r in gv._relations:
		if "C-MAIN" in str(_r.from) + str(_r.to) and "NPC_WT" in str(_r.from) + str(_r.to):
			_rel_fwd = _r
	print("  正向 关系: " + str(_rel_fwd))
	if str(_rel_fwd.get("kind","")) != "target":
		ok = false
		print("  FAIL BUG1-正向) kind=%s（应为 target）" % str(_rel_fwd.get("kind","")))
	else:
		print("  - 正向 kind=target ✓")

	# 验证器判定：snapshot + evaluate，看 missing_edges 是否含 C-MAIN→NPC_WT target 边
	gv._relations = []
	gv._rebuild_graph()
	await process_frame
	gv._drag_start = Vector2(5, 5)
	gv._commit_move("NPC_WT", _gcenter(gv, "conclusion_C-MAIN"))
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var snap: Dictionary = gv.snapshot_player_work()
	var ev = load("res://scripts/clue/wall_branch_evaluator.gd")
	var res: Dictionary = ev.evaluate(snap.get("relations",[]), snap.get("graph_nodes",[]), snap.get("derived_conclusions",[]), "scene1", true)
	var _missing_target := false
	for _b in res.get("per_branch", []):
		for _e in _b.get("missing_edges", []):
			if "C-MAIN" in str(_e.get("from","")) + str(_e.get("to","")) and "NPC_WT" in str(_e.get("from","")) + str(_e.get("to","")) and str(_e.get("kind","")) == "target":
				_missing_target = true
	if _missing_target:
		ok = false
		print("  FAIL BUG1) 验证器 missing_edges 含 C-MAIN→NPC_WT(target)，即误报'未连接到华生'")
	else:
		print("  - BUG1 验证器未误报 ✓")

	print("BUG1_BUG2_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
