extends SceneTree
## 反向建边拖拽复现（用户场景二症状）：玩家把推断拖到线索上建边（from=推断 to=线索）
## + 正向边并存时，_build_parent_of 的父选取会把线索(3)选成推断(2)的父 → 树倒挂 → 拖拽不随动。
## 期望：修复后无论建边方向如何混合，拖推断→其线索随动、拖结论→下游推断+线索随动。

func _mk_clue(id: String, npc: String) -> Dictionary:
	return {"id": id, "name": id, "correct": true, "related_npcs": [npc]}

func _build(gv: Object) -> void:
	var clues := [
		_mk_clue("c201", "NPC_A"), _mk_clue("c202", "NPC_A"), _mk_clue("c203", "NPC_A"),
		_mk_clue("c204", "NPC_B"), _mk_clue("c205", "NPC_B"),
	]
	var hyps := [
		{"id": "H2-01", "text": "推断一", "correct": true, "gate_clue_ids": ["c201", "c202"]},
		{"id": "H2-02", "text": "推断二", "correct": true, "gate_clue_ids": ["c203"]},
		{"id": "M2-01", "text": "误导一", "correct": false, "gate_clue_ids": ["c204"]},
	]
	var cons := [
		{"id": "CL2-X", "text": "结论X", "correct": true, "gate_hypo_ids": ["H2-01", "H2-02"], "target": "person:NPC_A"},
	]
	gv.build({
		"clues": clues,
		"hypo": {"title": "t", "description": "d", "battlefield": {"hypotheses": hyps, "conclusions": cons}},
		"relations": [],
		"persons": [{"id": "NPC_A", "name": "甲"}, {"id": "NPC_B", "name": "乙"}],
		"focus_person": "NPC_A", "difficulty": 1, "editable": true, "verdict": 0,
		"state_store": {}, "auto_fold": false, "case_wide": true, "teaching": false,
		"current_battlefield": {}, "scene_clue_ids": ["c201", "c202", "c203", "c204", "c205"],
		"on_tag": Callable(), "on_relations_changed": Callable(), "on_pen_changed": Callable(),
		"on_verify": Callable(), "on_close": Callable(),
	})

func _drag_node(gv: Object, id: String, to: Vector2) -> void:
	gv._node_center[id] = to
	gv._commit_move(id, to)
	await process_frame
	await process_frame

func _report(gv: Object, tag: String, root: String, kids: Array) -> bool:
	var ok := true
	var rp: Vector2 = gv._node_center.get(root, Vector2.INF)
	var line := ["%s root=%s @%s" % [tag, root, rp]]
	for k in kids:
		var kp: Vector2 = gv._node_center.get(k, Vector2.INF)
		var moved: bool = kp.distance_to(rp) < 480.0
		if not moved:
			ok = false
		line.append("  %s @%s 随动=%s" % [k, kp, moved])
	print("\n".join(line))
	return ok

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv: Object = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	_build(gv)
	await process_frame
	# 玩家操作（场景二自由建边，方向混合）：
	gv._derive_hypo("c203", "H2-01")
	gv._derive_hypo("c203", "H2-02")
	gv._derive_conclusion("H2-02", "CL2-X")
	await process_frame
	# 1) 反向：把推断 H2-01 拖到线索 c201 上（from=推断 to=线索）
	gv._edge._add_edge("H2-01", "c201", "support", "green", false)
	# 2) 正向：把线索 c202 拖到推断 H2-01 上（from=线索 to=推断）
	gv._edge._add_edge("c202", "H2-01", "support", "green", false)
	# 3) 推断→结论（正向）：H2-02 拖到结论 CL2-X
	gv._edge._add_edge("H2-02", "CL2-X", "support", "green", false)
	# 4) 反向：把结论 CL2-X 拖到推断 H2-01 上（from=结论 to=推断）
	gv._edge._add_edge("CL2-X", "H2-01", "support", "green", false)
	await process_frame
	await process_frame

	var all_ok := true
	# 拖结论（树枝）：下游推断+线索应随动
	var before_c: Vector2 = gv._node_center["CL2-X"]
	await _drag_node(gv, "CL2-X", before_c + Vector2(180, 120))
	all_ok = _report(gv, "拖结论", "CL2-X", ["H2-01", "H2-02", "c201", "c202", "c203"]) and all_ok
	# 拖推断（分枝）：其线索应随动
	var before_h: Vector2 = gv._node_center["H2-01"]
	await _drag_node(gv, "H2-01", before_h + Vector2(160, 100))
	all_ok = _report(gv, "拖推断", "H2-01", ["c201", "c202"]) and all_ok
	# 人物根拖动：整树随动（需先连结论→人物 target 边，模拟玩家归锚）
	gv._edge._add_edge("CL2-X", "person:NPC_A", "target", "gold", false)
	await process_frame
	var before_p: Vector2 = gv._node_center["NPC_A"]
	await _drag_node(gv, "NPC_A", before_p + Vector2(120, 80))
	all_ok = _report(gv, "拖人物", "NPC_A", ["CL2-X", "H2-01", "c201"]) and all_ok
	print("  [诊断] CL2-X=", gv._node_center.get("CL2-X"), " 钉位=", gv._root_anchor_pos)
	print("  [诊断] 偏移=", gv._node_offsets, " all_pos[CL2-X]=", gv._all_positions.get("CL2-X"))
	print("  [诊断] 边表=", gv._relations)
	print("  [诊断] manual=", gv._manual_nodes)
	var out_dbg: Dictionary = gv._layout._compute_layout(gv._data.nodes)
	print("  [诊断] 布局out[CL2-X]=", out_dbg.get("CL2-X"), " out[NPC_A]=", out_dbg.get("NPC_A"))
	# 建边路径复现：拖结论落点靠近 H2-02（48px 内）→ 建边路径不清后代钉位 → 子树回弹？
	var near: Vector2 = gv._node_center["H2-02"] + Vector2(20, 10)
	await _drag_node(gv, "CL2-X", near)
	all_ok = _report(gv, "拖结论到节点旁(建边路径)", "CL2-X", ["H2-01", "H2-02", "c201", "c202", "c203"]) and all_ok

	print("DRAG_REVERSE_%s" % ("OK" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)
