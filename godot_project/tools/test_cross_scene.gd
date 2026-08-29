extends SceneTree
## 跨场景累积（新设计，2026-08-29 修正后）集成测试：
##   ① 画布不再自动铺 battlefield 预设推断/结论（场景二/三开墙保持干净，仅显示线索+玩家已建节点）；
##   ② 玩家自建节点经 case_wall_state 跨场景携带（场景二建的 H2-01/CL2-1 在场景三仍在画布）；
##   ③ 弹窗候选 _hypo_current 仅含当前场景（场景三的 _hypo_current 不含场景二的 H2-/CL2-）。
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	var reg = load("res://data/case_reasoning_registry.gd")
	var union2: Dictionary = reg.get_hypo_union_up_to("scene2")
	var union3: Dictionary = reg.get_hypo_union_up_to("scene3")
	var s3 = load("res://scripts/scene/scene3.gd").new()
	var s3_bf: Dictionary = s3.reasoning_hypothesis().get("battlefield", {})

	# 共享 state_store（模拟 ClueSystem.case_wall_state）：场景二玩家自建的节点
	var shared := {
		"graph_nodes": [{"id": "H2-01", "kind": "hypo", "label": "凶手乘出租马车来到花园街3号", "sub": "推断", "data": {}}],
		"graph_derived_conclusions": [{"id": "CL2-1", "hid": "H2-01", "text": ""}],
	}

	# 场景二开墙
	gv.build({"clues": [{"id": "c201", "name": "c201", "correct": true}],
		"hypo": union2, "current_battlefield": union2.get("battlefield", {}),
		"persons": [], "focus_person": "", "difficulty": gv.Diff.HARD, "editable": true,
		"state_store": shared, "relations": [], "auto_fold": false, "case_wide": true})
	await process_frame
	gv._rebuild_graph()
	await process_frame
	print("[scene2] H2-01 in canvas? %s  CL2-1? %s" % [gv._node_center.has("H2-01"), gv._node_center.has("conclusion_CL2-1")])

	# 场景三开墙（同一共享 state_store）
	gv.build({"clues": [{"id": "c301", "name": "c301", "correct": true}],
		"hypo": union3, "current_battlefield": s3_bf,
		"persons": [], "focus_person": "", "difficulty": gv.Diff.HARD, "editable": true,
		"state_store": shared, "relations": [], "auto_fold": false, "case_wide": true})
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var _nl: Array = gv._node_list()

	var fails := 0
	# ① 携带：场景二自建节点在场景三仍在
	for must in ["H2-01", "conclusion_CL2-1"]:
		if not gv._node_center.has(must):
			print("FAIL 跨场景携带缺失: " + must); fails += 1
	# ② 不自动铺：场景三预设 H3-*/CL3-* 不应出现在画布（玩家没建）
	for nid in gv._node_center.keys():
		if nid.begins_with("H3-") or nid.begins_with("CL3-"):
			print("FAIL 场景三不应自动铺预设节点: " + nid); fails += 1
	# ③ 弹窗隔离：_hypo_current 仅当前场景
	for h in gv._hypo_current.get("hypotheses", []):
		if str(h.get("id", "")).begins_with("H2-"):
			print("FAIL _hypo_current 含其他场景推断: " + str(h.get("id", ""))); fails += 1
	for c in gv._hypo_current.get("conclusions", []):
		if str(c.get("id", "")).begins_with("CL2-") or str(c.get("id", "")).begins_with("C2-"):
			print("FAIL _hypo_current 含其他场景结论: " + str(c.get("id", ""))); fails += 1
	print("[scene3] node_count=%d  _hypo_current.hypo=%d  _hypo_current.concl=%d" % [
		gv._node_center.size(), gv._hypo_current.get("hypotheses", []).size(), gv._hypo_current.get("conclusions", []).size()])
	if fails == 0:
		print("CROSS_RESULT: PASS")
	else:
		print("CROSS_RESULT: FAIL(%d)" % fails)
	quit()
