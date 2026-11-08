extends SceneTree
# L02 实测：无人物单链（persons 传空），应线索最左(d0)→推断→结论最右
# 受影响：上一轮 _has_anchor 补了 focus_person/_persons 判定后，build 兜底 __case__ 会误判为锚点
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	# 场景二~七风格的无人物单链：仅 clue→infer→conclusion support 边
	var clues := [
		{"id":"c1","name":"线索1","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断","correct":true,"gate_clue_ids":["c1"]}],
		"conclusions":[
		{"id":"CL1","text":"结论","correct":true,"gate_hypo_ids":["H1"]}]}}
	gv._canvas = Control.new()  # 占位，build 会重建？
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	# 派生建边：线索→推断→结论（仅 support 边，无 person 边）
	gv._derive.derive_hypo("c1","H1")
	await process_frame
	gv._derive.derive_conclusion("H1","CL1")
	await process_frame
	# 走真实后处理链路
	gv._rebuild_graph()
	await process_frame

	# build 兜底后状态
	print("[L02] build 后 _persons.size=%d _focus_person='%s'" % [gv._persons.size(), gv._focus_person])
	# _has_anchor / _reverse_mode 判定：直接用 _build_parent_of 的输入观察
	var rels: Array = gv._relations
	var has_person_edge := false
	for r in rels:
		var fk: String = gv._fold._kind_of(str(r.get("from","")))
		var tk: String = gv._fold._kind_of(str(r.get("to","")))
		if fk == "person" or fk == "event" or tk == "person" or tk == "event":
			has_person_edge = true; break
	var fp: String = gv._focus_person
	var ps: Array = gv._persons
	# 与 _build_parent_of 现行判定一致：排除兜底 __case__，否则无人物单链恒判有锚点
	var has_anchor: bool = has_person_edge
	if not has_anchor and fp != "" and fp != "__case__":
		has_anchor = true
	if not has_anchor:
		for _pp in ps:
			if typeof(_pp) == TYPE_DICTIONARY:
				var _pid2 := str((_pp as Dictionary).get("id",""))
				if _pid2 != "" and _pid2 != "__case__":
					has_anchor = true; break
	print("[L02] has_person_edge=%s fp='%s' ps=%s → has_anchor=%s reverse_mode=%s"
		% [has_person_edge, fp, str(ps), has_anchor, not has_anchor])

	# 各节点 x
	for id in ["c1","H1","conclusion_CL1"]:
		print("[L02] %-14s %s" % [id, str(gv._node_center.get(id, "MISS"))])
	var ok: bool = true
	if not gv._node_center.has("c1") or not gv._node_center.has("conclusion_CL1"):
		ok = false; print("[L02] FAIL: 节点缺失")
	elif gv._node_center["c1"].x > gv._node_center["conclusion_CL1"].x:
		ok = false; print("[L02] FAIL: 结论x(%s) < 线索x(%s)——reverse 未触发，L02 被改坏"
			% [gv._node_center["conclusion_CL1"].x, gv._node_center["c1"].x])
	else:
		print("[L02] L02_PASS: 线索x=%.0f ≤ 结论x=%.0f（线索最左→推断→结论最右）"
			% [gv._node_center["c1"].x, gv._node_center["conclusion_CL1"].x])
	print("[L02] RESULT=%s" % ("PASS" if ok else "FAIL"))
	quit()