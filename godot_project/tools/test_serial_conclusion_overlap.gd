extends SceneTree
## 回归测试：串行结论链（长中文标签）在 MODE_LOGIC 布局下不重叠，且垂直间距不过大。
## 覆盖思傅 2026-09-07 反馈：① 垂直间距大；② 最上面两条串行结论文本框重叠。

func _box(_unused: Dictionary, id: String, gv) -> Rect2:
	# 2026-09-08 同步为真实高度模型（测量前置治本）：旧 _est_node_h + _kind_min_h 200 兜底与真实渲染脱节
	# （结论卡真实 ~52px 却被撑到 172px）；现消费 _real_node_height 真实尺寸。
	var kind: String = gv._fold._kind_of(id)
	var w: float = gv._layout._node_width_for_kind(kind)
	var label: String = gv._node_data.get(id, {}).get("label", "")
	var h: float = gv._layout._real_node_height(id, {"id": id, "kind": kind, "label": label})
	var c: Vector2 = gv._node_center[id]
	return Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	# 构造：人物 P ← 结论 C2 ← 结论 C1 ← 结论 C0（串行链，越长标签越容易暴露 wrap 宽度 bug）
	#        P 还有并列结论 C3（测兄弟间距）
	#        C0 下挂推断 H1 ← 线索 CL1
	var clues := [{"id":"CL1","name":"线索：现场发现一枚军用纽扣"}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断：凶手有军旅背景","correct":true,"gate_clue_ids":["CL1"]}
	],"conclusions":[
		{"id":"C0","text":"结论丁：凶手曾在阿富汗服役，熟悉沙漠地形与军用装备","correct":true,"gate_hypo_ids":["H1"]},
		{"id":"C1","text":"结论丙：手腕疤痕为旧式步枪贯穿伤，符合阿富汗战场救护记录","correct":true,"gate_hypo_ids":["C0"]},
		{"id":"C2","text":"结论乙：华生在阿富汗服务过，能够对受害者伤痕作出准确判断","correct":true,"gate_hypo_ids":["C1"],"target":"person:P"},
		{"id":"C3","text":"结论甲：本案真凶具备极强的反侦察意识与医学常识","correct":true,"gate_hypo_ids":["H1"],"target":"person:P"}
	]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"P","name":"华生"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame

	# 通过推导建立节点（_node_list 只显示已推导的推断/结论）
	gv._derive_hypo("CL1", "H1"); await process_frame
	gv._derive_conclusion("H1", "C0"); await process_frame
	gv._derive_conclusion("conclusion_C0", "C1"); await process_frame
	gv._derive_conclusion("conclusion_C1", "C2"); await process_frame
	gv._derive_conclusion("H1", "C3"); await process_frame
	gv._rebuild_graph()
	await process_frame

	# 结论节点有 conclusion_ 前缀；人物节点为裸 id（P）
	var ids := ["P", "conclusion_C2", "conclusion_C1", "conclusion_C0", "conclusion_C3", "H1", "CL1"]
	var ok := true
	for id in ids:
		if not gv._node_center.has(id):
			print("FAIL 缺少节点 %s" % id); ok = false

	if ok:
		# 1) 串行结论链 x 严格右向递增（C2 是 C1 的父，故 C2 在左）
		if not (gv._node_center["conclusion_C2"].x < gv._node_center["conclusion_C1"].x):
			print("FAIL C2.x(%.0f) 应 < C1.x(%.0f)" % [gv._node_center["conclusion_C2"].x, gv._node_center["conclusion_C1"].x]); ok = false
		if not (gv._node_center["conclusion_C1"].x < gv._node_center["conclusion_C0"].x):
			print("FAIL C1.x(%.0f) 应 < C0.x(%.0f)" % [gv._node_center["conclusion_C1"].x, gv._node_center["conclusion_C0"].x]); ok = false

		# 2) 任意两节点 AABB（留 8px 间隙）不相交
		var rects := {}
		for id in ids:
			rects[id] = _box({}, id, gv).grow(8.0)
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				if rects[ids[i]].intersects(rects[ids[j]]):
					print("FAIL 重叠 %s ↔ %s" % [ids[i], ids[j]]); ok = false

		# 3) 串行结论 C1/C0 的垂直中心偏移不应过大（避免长标签链出现对角重叠）。
		var h_c1: float = gv._layout._real_node_height("conclusion_C1", {"id":"conclusion_C1","kind":"conclusion","label":gv._node_data.get("conclusion_C1",{}).get("label","")})
		var h_c0: float = gv._layout._real_node_height("conclusion_C0", {"id":"conclusion_C0","kind":"conclusion","label":gv._node_data.get("conclusion_C0",{}).get("label","")})
		var dy_c1_c0: float = abs(gv._node_center["conclusion_C1"].y - gv._node_center["conclusion_C0"].y)
		if dy_c1_c0 > (h_c1 + h_c0) * 0.5:
			print("FAIL C1/C0 垂直偏移 %.0f 过大" % dy_c1_c0); ok = false
		else:
			print("[OK] C1/C0 垂直偏移 %.0f" % dy_c1_c0)

	if ok:
		print("SERIAL_CONCLUSION_RESULT: PASS")
	else:
		print("SERIAL_CONCLUSION_RESULT: FAIL")
	quit()
