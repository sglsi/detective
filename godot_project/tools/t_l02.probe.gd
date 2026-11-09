extends SceneTree
# L02 实测：无人物锚点单链（场景二~七风格），应线索最左(d0)→推断→结论最右
# 用真实场景二数据：c201~c202 带 related_npcs=["KILLER"]（scene2.gd:20），
# persons 由 WallState._derive_persons() 语义真实派生（遍历 related_npcs），
# relations 只建玩家真实会建的边 c201→H2-01→CL2-1（无 person 端点的边）。
# 回归确认：_has_anchor 只看 relations 是否存在 person/event 端点边，
# 绝不用 _focus_person/_persons 存在性（人物由 related_npcs 自动派生，人物≠锚点）。
func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	# 真实场景二线索（scene2.gd）：c201 带 related_npcs=["KILLER"]
	var clues := [
		{"id":"c201","name":"碾轧的花草","correct":true,"relation_tags":["H2-01"],"related_npcs":["KILLER"]},
		{"id":"c202","name":"平行车轮印","correct":true,"relation_tags":["H2-01"]},
	]
	# persons 由 related_npcs 派生（WallState._derive_persons 语义），非手写 []
	var persons := []
	var seen := {}
	for c in clues:
		for p in c.get("related_npcs", []):
			if not seen.has(p): seen[p]=true; persons.append({"id":p,"name":p})
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H2-01","text":"推断","correct":true,"gate_clue_ids":["c201","c202"]}],
		"conclusions":[
		{"id":"CL2-1","text":"结论","correct":true,"gate_hypo_ids":["H2-01"]}]}}
	gv._canvas = Control.new()
	gv.build({"clues":clues,"hypo":hypo,"persons":persons,"focus_person":"",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	# 派生建边：仅 c201→H2-01→CL2-1（无 person 端点边）
	gv._derive.derive_hypo("c201","H2-01")
	await process_frame
	gv._derive.derive_conclusion("H2-01","CL2-1")
	await process_frame
	gv._rebuild_graph()
	await process_frame

	print("[L02] build 后 _persons.size=%d _persons[0].id='%s' _focus_person='%s'"
		% [gv._persons.size(), gv._persons[0].get("id","") if gv._persons.size()>0 else "", gv._focus_person])
	# _has_anchor 现行判定：只看 relations 是否存在 person/event 端点边
	var has_person_edge := false
	for r in gv._relations:
		var fk: String = gv._fold._kind_of(str(r.get("from","")))
		var tk: String = gv._fold._kind_of(str(r.get("to","")))
		if fk == "person" or fk == "event" or tk == "person" or tk == "event":
			has_person_edge = true; break
	var has_anchor: bool = has_person_edge
	print("[L02] has_person_edge=%s → has_anchor=%s reverse_mode=%s"
		% [has_person_edge, has_anchor, not has_anchor])

	for id in ["c201","H2-01","conclusion_CL2-1"]:
		print("[L02] %-14s %s" % [id, str(gv._node_center.get(id, "MISS"))])
	var ok: bool = true
	if not gv._node_center.has("c201") or not gv._node_center.has("conclusion_CL2-1"):
		ok = false; print("[L02] FAIL: 节点缺失")
	elif gv._node_center["c201"].x > gv._node_center["conclusion_CL2-1"].x:
		ok = false; print("[L02] FAIL: 结论x(%s) < 线索x(%s)——reverse 未触发，L02 被改坏"
			% [gv._node_center["conclusion_CL2-1"].x, gv._node_center["c201"].x])
	else:
		print("[L02] L02_PASS: 线索x=%.0f ≤ 结论x=%.0f（线索最左→推断→结论最右）"
			% [gv._node_center["c201"].x, gv._node_center["conclusion_CL2-1"].x])
	print("[L02] RESULT=%s" % ("PASS" if ok else "FAIL"))
	quit()