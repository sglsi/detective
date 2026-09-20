extends SceneTree
## 验证需求2（思傅 2026-09-20）：推理墙画布「拖动范围限制」已取消。
## 判定：① _clamp_free 对超大坐标原样返回（不再钳到画布内）；
##       ② NaN/Inf 兜底仍为 ZERO；
##       ③ 把节点拖到很远右边并落点后，重排仍保留该落点（画布随内容自由扩展）。

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv.build({"clues":[{"id":"c1","name":"线索一","correct":true}],
		"persons":[{"id":"KILLER","name":"凶手"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame

	var ok := true
	var log := []

	# ① _clamp_free 对超大坐标应原样返回（旧实现会钳到 [−slack, cv.x+slack]）
	var far := Vector2(99999.0, -88888.0)
	var cf: Vector2 = gv._layout._clamp_free(far)
	if cf.distance_to(far) > 1.0:
		ok = false; log.append("FAIL _clamp_free 仍钳制: in=%s out=%s" % [str(far), str(cf)])
	else:
		log.append("PASS _clamp_free 放开范围: %s 原样返回" % str(cf))

	# ② NaN/Inf 兜底仍为 ZERO
	var nan_cf: Vector2 = gv._layout._clamp_free(Vector2.INF)
	if nan_cf != Vector2.ZERO:
		ok = false; log.append("FAIL _clamp_free NaN 兜底失效: %s" % str(nan_cf))
	else:
		log.append("PASS _clamp_free NaN 兜底=ZERO")

	# ③ 构造无根推理链（clue→hypo→conclusion，不挂人物），把其中节点拖到很远右边落点，
	#    重排后该落点应保留（画布随内容自由扩展，不再被钳回画布内）。
	gv._state = gv.State.EDITABLE
	gv._derive.derive_hypo("c1", "H1")
	gv._derive.derive_conclusion("H1", "CL1")   # 不建 target 边 → CL1/H1/c1 为无根链
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var far2 := Vector2(50000.0, 1234.0)
	gv._node_center["H1"] = far2
	gv._root_anchor_pos["H1"] = far2
	if not ("H1" in gv._manual_nodes):
		gv._manual_nodes.append("H1")
	gv._rebuild_graph()
	await process_frame
	var after: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	if after.distance_to(far2) > 50.0:
		ok = false; log.append("FAIL 无根链落点%sc被回收: %s" % [str(far2), str(after)])
	else:
		log.append("PASS 画布扩展：无根链落点%s保留=%s" % [str(far2), str(after)])

	for l in log:
		print(l)
	print("CANVAS_FREE_EXPAND_DONE ok=%s" % str(ok))
