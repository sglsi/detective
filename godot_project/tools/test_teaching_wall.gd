extends SceneTree
## 教学墙专项测试（华生/信使，teaching=true）：
## 验证问题1修复——玩家从某推断推导一条「推断→结论」关系时，只产生该一条边，
## 不再因 _sync_conclusion_gate_edges 自动把同一结论的其它 gate 推断也连上（如 W-A1 同时 gate C-A1/C-MAIN，
## 从 W-B1 推导 C-MAIN 不应自动补出 W-A1→C-MAIN / W-C3→C-MAIN）。
## 同时验证 _teaching 标志正确透传到 graph_view_controller。
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")

	# 华生式假设：W-A1 同时 gate 住 C-A1 与 C-MAIN（正是"推断1→结论1/结论2"重复边的来源）
	var hypo := {
		"title": "教学墙测试",
		"persons": [{"id": "NPC_WT"}],
		"battlefield": {
			"hypotheses": [
				{"id": "W-A1", "text": "热带晒痕", "correct": true},
				{"id": "W-B1", "text": "军医", "correct": true},
				{"id": "W-C3", "text": "战火伤痛", "correct": true},
			],
			"conclusions": [
				{"id": "C-A1", "text": "热带生活", "correct": true, "gate_hypo_ids": ["W-A1"], "target": "person:NPC_WT", "adopt_desc": "x"},
				{"id": "C-MAIN", "text": "阿富汗归来", "correct": true, "gate_hypo_ids": ["W-A1", "W-B1", "W-C3"], "target": "person:NPC_WT", "adopt_desc": "y"},
			],
			"contradictions": [],
		},
	}
	var persons := [{"id": "NPC_WT", "name": "华生"}]

	# ---- 教学墙（teaching=true）：推导 C-MAIN 仅产一条边 ----
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv.build({"clues": [], "hypo": hypo, "persons": persons, "focus_person": "NPC_WT",
		"difficulty": gv.Diff.NORMAL, "editable": true, "state_store": {}, "relations": [],
		"auto_fold": false, "case_wide": false, "teaching": true})
	await process_frame
	gv._rebuild_graph()
	await process_frame

	var fails := 0
	if not gv._teaching:
		print("TEACH FAIL _teaching 标志未透传"); fails += 1
	if not gv._node_center.has("W-B1"):
		print("TEACH FAIL 节点 W-B1 未上画布"); fails += 1
	if not gv._node_center.has("conclusion_C-MAIN"):
		print("TEACH FAIL 结论节点 conclusion_C-MAIN 未上画布"); fails += 1

	# 模拟玩家唯一选择：从 W-B1 推导 C-MAIN（仅一条边）
	gv._add_derived_conclusion("W-B1", "C-MAIN")
	await process_frame

	var has := func(f: String, t: String) -> bool:
		for r in gv._relations:
			if str(r.get("from", "")) == f and str(r.get("to", "")) == t:
				return true
		return false

	if not has.call("W-B1", "conclusion_C-MAIN"):
		print("TEACH FAIL 玩家选择的 W-B1→C-MAIN 边未生成"); fails += 1
	if has.call("W-A1", "conclusion_C-MAIN"):
		print("TEACH FAIL 教学墙自动补出多余边 W-A1→C-MAIN（重复边 bug 未修）"); fails += 1
	if has.call("W-C3", "conclusion_C-MAIN"):
		print("TEACH FAIL 教学墙自动补出多余边 W-C3→C-MAIN（重复边 bug 未修）"); fails += 1
	print("[teaching=true] 关系数=%d 含 W-B1→C-MAIN=%s 含 W-A1→C-MAIN=%s 含 W-C3→C-MAIN=%s" % [
		gv._relations.size(), has.call("W-B1", "conclusion_C-MAIN"),
		has.call("W-A1", "conclusion_C-MAIN"), has.call("W-C3", "conclusion_C-MAIN")])

	# ---- 对照（teaching=false 案件墙）：推导 C-MAIN 应自动补全部 gate 边（验证 guard 是差异点）----
	var gv2 = GV.new()
	var holder2 = Control.new(); root.add_child(holder2); holder2.add_child(gv2)
	await process_frame
	gv2.build({"clues": [], "hypo": hypo, "persons": persons, "focus_person": "NPC_WT",
		"difficulty": gv2.Diff.NORMAL, "editable": true, "state_store": {}, "relations": [],
		"auto_fold": false, "case_wide": false, "teaching": false})
	await process_frame
	gv2._rebuild_graph()
	await process_frame
	gv2._add_derived_conclusion("W-B1", "C-MAIN")
	await process_frame
	var has2 := func(f: String, t: String) -> bool:
		for r in gv2._relations:
			if str(r.get("from", "")) == f and str(r.get("to", "")) == t:
				return true
		return false
	if not has2.call("W-A1", "conclusion_C-MAIN") or not has2.call("W-C3", "conclusion_C-MAIN"):
		print("TEACH FAIL 对照(teaching=false)未自动补 gate 边，guard 逻辑异常"); fails += 1
	else:
		print("[teaching=false 对照] 关系数=%d（含 W-A1/W-B1/W-C3→C-MAIN 自动闭合）" % gv2._relations.size())

	if fails == 0:
		print("TEACH_RESULT: PASS")
	else:
		print("TEACH_RESULT: FAIL(%d)" % fails)
	quit()
