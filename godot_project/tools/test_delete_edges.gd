extends SceneTree
## 验证 2026-08-28 两项改动：
##  需求2：删除「推断→结论」的 support 边后，该推断成为关系树根，但整体布局仍零重叠（不叠其它文本框）
##  需求1：删除「结论→人物」的 target 金边后，该边不再自动回生（可删除、可持久）
func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var clues := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"arm","name":"华生左臂僵硬","correct":true},
		{"id":"face_dark","name":"华生脸色黝黑","correct":true},
		{"id":"face_haggard","name":"华生面容憔悴","correct":true},
		{"id":"pose","name":"华生军人站姿","correct":true},
		{"id":"medical","name":"医务工作者风度","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"W-A1","text":"华生不是原来的肤色","correct":true,"gate_clue_ids":["wrist","face_dark"]},
		{"id":"W-B1","text":"华生是名军医","correct":true,"gate_clue_ids":["pose","medical"]},
		{"id":"W-C1","text":"华生久病初愈","correct":true,"gate_clue_ids":["face_haggard"]},
		{"id":"W-C2","text":"华生左臂受过伤","correct":true,"gate_clue_ids":["arm"]},
		{"id":"W-C3","text":"华生承受过不该有的伤痛","correct":true,"gate_hypo_ids":["W-C1","W-C2"]}],
		"conclusions":[
		{"id":"C-A1","text":"华生曾在热带长期生活","correct":true,"gate_hypo_ids":["W-A1"],"target":"person:NPC_WT"},
		{"id":"C-MAIN","text":"华生刚从阿富汗服役归来","correct":true,"gate_hypo_ids":["W-A1","W-B1","W-C3"],"target":"person:NPC_WT"},
		{"id":"C-C1","text":"华生参加过战争","correct":true,"gate_hypo_ids":["W-C3"],"target":"person:NPC_WT"}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],
		"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("wrist","W-A1"); gv._derive_hypo("face_dark","W-A1")
	gv._derive_hypo("pose","W-B1"); gv._derive_hypo("medical","W-B1")
	gv._derive_hypo("face_haggard","W-C1"); gv._derive_hypo("arm","W-C2")
	await process_frame
	gv._derive_hypo_from_hypo("W-C1","W-C3"); gv._derive_hypo_from_hypo("W-C2","W-C3")
	await process_frame
	gv._derive_conclusion("W-A1","C-A1"); gv._derive_conclusion("W-C3","C-MAIN"); gv._derive_conclusion("W-C3","C-C1")
	await process_frame
	gv._rebuild_graph()
	await process_frame

	# ---- 需求2：删除「W-A1 → conclusion_C-A1」support 边，W-A1 失去父(结论)成为根 ----
	gv._relations = gv._relations.filter(func(r): return not (
		r.get("from","") == "W-A1" and r.get("to","") == "conclusion_C-A1" and r.get("kind","") == "support"))
	gv._rebuild_graph()
	await process_frame
	if not gv._node_center.has("W-A1"):
		ok = false; print("FAIL D2) W-A1 节点丢失")
	else:
		print("  - D2) 删「推断→结论」边后 W-A1 仍在画布 ✓")
	if not _no_overlap(gv):
		ok = false; print("FAIL D2) 删除边后节点矩形重叠")
	else:
		print("  - D2) 删「推断→结论」边后整体零重叠 ✓")
	# 极端：删掉指向 W-A1 的全部父边，使其彻底成为孤立根，验证不重叠（需求2 核心：根节点也不叠加）
	gv._relations = gv._relations.filter(func(r): return r.get("to","") != "W-A1")
	gv._rebuild_graph()
	await process_frame
	var _has_parent_edge := false
	for _r in gv._relations:
		if _r.get("kind","") in ["support","target"] and _r.get("to","") == "W-A1":
			_has_parent_edge = true
	if _has_parent_edge:
		ok = false; print("FAIL D2) 孤立后 W-A1 仍有父边（未真正成为根）")
	else:
		print("  - D2) 删全部父边后 W-A1 无父（成为布局根节点）✓")
	if not _no_overlap(gv):
		ok = false; print("FAIL D2) 孤立根与节点矩形重叠")
	else:
		print("  - D2) 孤立根节点零重叠 ✓")

	# ---- 需求1（2026-09-05 适配）：系统不再自动派生结论→人物金边；改为玩家手动建边后可删、可持久 ----
	# 玩家手动拖 conclusion_C-MAIN 到 NPC_WT 头像建归属金边
	gv._edge._add_edge("conclusion_C-MAIN", "NPC_WT", "target", "gold", false)
	await process_frame
	var manual_cnt := 0
	for e in gv._edge_list:
		if e.get("from","") == "conclusion_C-MAIN" and e.get("to","") == "NPC_WT" and e.get("kind","") == "target":
			manual_cnt += 1
	if manual_cnt != 1:
		ok = false; print("FAIL D1) 玩家手动建的 target 金边未显示")
	else:
		print("  - D1) 玩家手动建「结论→人物」金边显示 ✓")
	# 玩家删除该边（右键删除→走正常删边路径，从 _relations 移除；手动 target 边不再走自动派生删除）
	gv._edge._remove_edge("conclusion_C-MAIN", "NPC_WT", "target")
	await process_frame
	var still_there := false
	for e in gv._edge_list:
		if e.get("from","") == "conclusion_C-MAIN" and e.get("to","") == "NPC_WT" and e.get("kind","") == "target":
			still_there = true
	if still_there:
		ok = false; print("FAIL D1) conclusion_C-MAIN→NPC_WT 边仍显示（删除未生效/自动回生）")
	else:
		print("  - D1) 删「结论→人物」边后不再自动回生 ✓")
	if not _no_overlap(gv):
		ok = false; print("FAIL D1) 删除后节点矩形重叠")
	else:
		print("  - D1) 删除后整体零重叠 ✓")
	# 系统不再自动派生任何结论→人物金边（2026-09-05 改动）：渲染边应只有玩家建的
	var auto_target := 0
	for e in gv._edge_list:
		if e.get("kind","") == "target":
			auto_target += 1
	if auto_target != 0:
		ok = false; print("FAIL D1) 仍有 %d 条系统自动金边（应为 0）" % auto_target)
	else:
		print("  - D1) 无系统自动金边 ✓")

	print("DELETE_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()


func _no_overlap(gv) -> bool:
	var ids: Array = gv._node_center.keys()
	var rects := {}
	for a in ids:
		var w: float = gv._layout._node_width_for_kind(gv._node_kind.get(a, "hypo"))
		var nd := {"label": gv._node_label(a)}
		var h: float = gv._layout._est_node_h(nd)
		var p: Vector2 = gv._node_center[a]
		rects[a] = Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].intersects(rects[ids[j]]):
				return false
	return true
