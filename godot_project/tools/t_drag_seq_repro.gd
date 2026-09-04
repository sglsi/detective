extends SceneTree
# 复现场景二拖拽回弹：完整用户操作序列（正/反向建边 → 逐层拖动 → 结论锚人物 → 自动排列 → 再拖）
# 每步断言：拖动节点钉住 + 子树随动。输出 [SEQ] 行。

var gv: Node = null
var holder: Control = null
var fails: int = 0

func _initialize() -> void:
	holder = Control.new()
	holder.size = Vector2(1600, 900)
	root.add_child(holder)
	await process_frame
	var scr := load("res://scripts/clue/graph_view_controller.gd")
	gv = scr.new()
	holder.add_child(gv)
	await process_frame

	var clues := [
		{"id": "c201", "name": "表", "kind": "clue", "correct": true, "related_npcs": [], "pos": Vector2.ZERO},
		{"id": "c202", "name": "桌", "kind": "clue", "correct": true, "related_npcs": [], "pos": Vector2.ZERO},
		{"id": "c203", "name": "窗", "kind": "clue", "correct": true, "related_npcs": [], "pos": Vector2.ZERO},
	]
	var hypotheses := [
		{"id": "H2-01", "text": "推断一", "correct": true, "gate_clue_ids": ["c201", "c202"], "mislead": false, "delay": 0},
		{"id": "H2-02", "text": "推断二", "correct": true, "gate_clue_ids": ["c203"], "mislead": false, "delay": 0},
	]
	var conclusions := [
		{"id": "CL2-X", "text": "结论X", "correct": true, "gate_hypo_ids": ["H2-01", "H2-02"]},
	]
	var persons := [{"id": "person:NPC_A", "name": "甲先生", "related_npcs": ["NPC_A"], "pos": Vector2.ZERO}]

	gv.build({
		"clues": clues, "hypo": {"title": "测试", "persons": [{"id": "NPC_A"}], "battlefield": {"hypotheses": [
			{"id": "H2-01", "text": "推断一", "correct": true, "gate_clue_ids": ["c201", "c202"]},
			{"id": "H2-02", "text": "推断二", "correct": true, "gate_clue_ids": ["c203"]}
		], "conclusions": [
			{"id": "CL2-X", "text": "结论X", "correct": true, "gate_hypo_ids": ["H2-01", "H2-02"]}
		]}},
		"current_battlefield": {"hypotheses": [{"id": "H2-01", "text": "推断一", "correct": true, "gate_clue_ids": ["c201", "c202"]}, {"id": "H2-02", "text": "推断二", "correct": true, "gate_clue_ids": ["c203"]}], "conclusions": [{"id": "CL2-X", "text": "结论X", "correct": true, "gate_hypo_ids": ["H2-01", "H2-02"]}]},
		"relations": [], "persons": persons, "focus_person": "person:NPC_A",
		"difficulty": 0, "editable": true, "state_store": {},
	})
	await process_frame
	await process_frame

	# --- 派生两个推断 + 结论（结论节点 id = conclusion_CL2-X）---
	gv._derive_hypo("c201", "H2-01")
	await process_frame
	gv._derive_hypo("c203", "H2-02")
	await process_frame
	gv._derive_conclusion("H2-01", "CL2-X")
	await process_frame
	var cid := "conclusion_CL2-X"
	print("[SEQ] derive 完成, 结论节点在表: ", gv._node_center.has(cid))

	# --- 玩家建边（混合方向）：正向支撑 + 反向（拖结论到推断上）---
	gv._edge._add_edge("c202", "H2-01", "support", "gold", false)
	gv._edge._add_edge(cid, "H2-02", "support", "gold", false)
	await process_frame
	gv._rebuild_graph()
	await process_frame

	# --- 步骤1：拖结论 ---
	await _drag_and_check(cid, Vector2(500, 300), "1 拖结论")
	# --- 步骤2：拖推断（其子树=c201/c202）---
	await _drag_and_check("H2-01", Vector2(700, 500), "2 拖推断")
	# --- 步骤3：拖结论到人物上（target 归锚，正确节点 id）---
	var npa: Vector2 = gv._node_center.get("person:NPC_A", Vector2.ZERO)
	await _drag_and_check(cid, npa + Vector2(10, 6), "3 拖结论到人物(归锚)")
	print("[SEQ] 归锚边存在: ", _has_edge(cid, "person:NPC_A"))
	# --- 步骤4：拖人物（树=NPC_A→结论→推断→线索 应整体随动）---
	await _drag_and_check("person:NPC_A", Vector2(1100, 700), "4 拖人物")
	# --- 步骤5：自动排列后再拖 ---
	gv._use_rank_layout = true
	gv._rebuild_graph()
	await process_frame
	await _drag_and_check("H2-01", Vector2(400, 400), "5 自动排列后拖推断")
	gv._use_rank_layout = false
	gv._rebuild_graph()
	await process_frame
	# --- 步骤6：再拖结论 ---
	await _drag_and_check(cid, Vector2(600, 200), "6 最后拖结论")

	print("[SEQ] RESULT fails=", fails)
	quit(1 if fails > 0 else 0)

func _has_edge(f: String, t: String) -> bool:
	for r in gv._relations:
		if str(r.get("from", "")) == f and str(r.get("to", "")) == t:
			return true
	return false

func _drag_and_check(id: String, to: Vector2, tag: String) -> void:
	gv._node_center[id] = to
	gv._commit_move(id, to)
	await process_frame
	await process_frame
	print("[SEQ] [", tag, "] 钉位表: ", gv._root_anchor_pos)
	var ok := true
	var p: Variant = gv._node_center.get(id)
	if typeof(p) != TYPE_VECTOR2:
		print("[SEQ] [", tag, "] 节点 ", id, " 位置异常(不在表): ", p, " ←←← BUG")
		fails += 1
		return
	elif p.distance_to(to) > 2.0:
		print("[SEQ] [", tag, "] 节点 ", id, " 回弹: ", p, " 期望 ", to, " ←←← BUG")
		fails += 1
		ok = false
	var desc: Array = gv._layout._descendants(id)
	for d in desc:
		var dp: Variant = gv._node_center.get(d)
		if typeof(dp) != TYPE_VECTOR2:
			print("[SEQ] [", tag, "]   后代 ", d, " 位置异常: ", dp, " ←←← BUG")
			fails += 1
			continue
		var pos_o: Variant = gv._all_positions.get(d, dp)
		if (dp as Vector2).distance_to(pos_o as Vector2) > 480.0:
			print("[SEQ] [", tag, "]   后代 ", d, " 跳变过大: ", dp, " vs 缓存 ", pos_o, " ←←← 可疑")
	print("[SEQ] [", tag, "] done ok=", ok, " 随动后代数=", desc.size())
