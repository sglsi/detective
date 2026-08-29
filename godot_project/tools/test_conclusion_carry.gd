extends SceneTree
## 聚焦验证问题3：场景二推导的结论带入场景三后，文本应保持场景二所选内容（不应回退「说得通」）。
## 同时顺带验证 _add_derived_conclusion 是否把预设结论文本回填进 _derived_conclusions 持久化。
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	var reg = load("res://data/case_reasoning_registry.gd")
	var union2: Dictionary = reg.get_hypo_union_up_to("scene2")
	var union3: Dictionary = reg.get_hypo_union_up_to("scene3")
	var s2 = load("res://scripts/scene/scene2.gd").new()
	var s2_bf: Dictionary = s2.reasoning_hypothesis().get("battlefield", {})
	var s3 = load("res://scripts/scene/scene3.gd").new()
	var s3_bf: Dictionary = s3.reasoning_hypothesis().get("battlefield", {})

	var shared := {"graph_nodes": [], "graph_derived_conclusions": []}

	# === 场景二：推导预设结论 CL2-1（con_id 预设，text 留空，由 _add_derived_conclusion 回填）===
	gv.build({"clues": [{"id": "c201", "name": "c201", "correct": true}],
		"hypo": union2, "current_battlefield": s2_bf,
		"persons": [], "focus_person": "", "difficulty": gv.Diff.HARD, "editable": true,
		"state_store": shared, "relations": [], "auto_fold": false, "case_wide": true})
	await process_frame
	gv._add_derived_conclusion("H2-01", "CL2-1", "")
	await process_frame
	var _t2: String = gv._conclusion_text("CL2-1")
	print("[scene2] CL2-1 文本 = " + _t2)
	# 持久化后的 _derived_conclusions 文本是否回填
	var _stored: String = ""
	for _d in shared.get("graph_derived_conclusions", []):
		if str(_d.get("id", "")) == "CL2-1":
			_stored = str(_d.get("text", ""))
	print("[persist] CL2-1 持久化文本 = " + _stored)

	# === 场景三：用同一共享 state_store 开墙（模拟跨场景携带）===
	gv.build({"clues": [{"id": "c301", "name": "c301", "correct": true}],
		"hypo": union3, "current_battlefield": s3_bf,
		"persons": [], "focus_person": "", "difficulty": gv.Diff.HARD, "editable": true,
		"state_store": shared, "relations": [], "auto_fold": false, "case_wide": true})
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var _t3: String = gv._conclusion_text("CL2-1")
	print("[scene3] CL2-1 文本 = " + _t3)
	# 问题3 详情卡：点开结论节点时「当前结论：」标题与「编辑内容」默认文本应取实际内容，而非 verdict「说得通」
	var _detail: String = gv._detail_title_text("conclusion_CL2-1", "conclusion")
	print("[scene3] 详情卡默认文本 = " + _detail)

	# 断言
	var fails := 0
	if _t2 != "凶手乘出租马车抵达现场":
		print("FAIL 场景二结论文本错误: " + _t2); fails += 1
	if _stored != "凶手乘出租马车抵达现场":
		print("FAIL 预设结论文本未回填持久化: " + _stored); fails += 1
	if _t3 != "凶手乘出租马车抵达现场":
		print("FAIL 场景三结论文本回退为: " + _t3); fails += 1
	if _detail != "凶手乘出租马车抵达现场":
		print("FAIL 详情卡默认文本回退为: " + _detail); fails += 1
	if not gv._node_center.has("conclusion_CL2-1"):
		print("FAIL 场景三结论节点缺失"); fails += 1

	if fails == 0:
		print("CONCL_CARRY: PASS")
	else:
		print("CONCL_CARRY: FAIL(%d)" % fails)
	quit()
