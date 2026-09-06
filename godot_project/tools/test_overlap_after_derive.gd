extends SceneTree
## 复现「推导新结论后位置重叠」：用「真实渲染高度」(结论高、推断中、线索更高) 做 AABB 碰撞，
## 暴露布局用 140 下限导致真实节点重叠的问题；同时覆盖「无人物自由推导」场景。
func _real_h(kind: String) -> float:
	match kind:
		"clue": return 200.0
		"conclusion": return 160.0
		"hypo","chain": return 120.0
		"person","event": return 110.0
		_: return 140.0

func _run_scene(tag: String, gv, relations_append: Array, derives: Array) -> bool:
	for _r in relations_append:
		gv._relations.append(_r)
	gv._rebuild_graph()
	await process_frame
	for _d in derives:
		gv._derive_conclusion(_d[0], _d[1])
		await process_frame
	gv._rebuild_graph()
	await process_frame
	var nc: Dictionary = gv._node_center
	var boxes := {}
	for _id in nc.keys():
		var sid := str(_id)
		var kind: String = gv._fold._kind_of(sid)
		var w: float = gv._layout._node_width_for_kind(kind)
		var h: float = _real_h(kind)
		var p: Vector2 = nc[sid]
		boxes[sid] = Rect2(p.x - w*0.5, p.y - h*0.5, w, h)
	var overlap := []
	var ids := boxes.keys()
	for i in range(ids.size()):
		for j in range(i+1, ids.size()):
			if boxes[ids[i]].intersects(boxes[ids[j]]):
				overlap.append(ids[i] + " ✕ " + ids[j])
	if overlap.is_empty():
		print("  [%s] 真实高度下无重叠 ✓" % tag)
	else:
		print("  [%s] FAIL 真实高度下重叠:" % tag)
		for _p in overlap:
			print("      " + _p)
	return overlap.is_empty()

func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")

	# 场景A：无人物，3个结论各自带推断+线索（自由推导场景）
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var cluesA := [{"id":"c1","name":"线索一"},{"id":"c2","name":"线索二"},{"id":"c3","name":"线索三"}]
	var hypoA := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断一","correct":true,"gate_clue_ids":["c1"]},
		{"id":"H2","text":"推断二","correct":true,"gate_clue_ids":["c2"]},
		{"id":"H3","text":"推断三","correct":true,"gate_clue_ids":["c3"]}],
		"conclusions":[
		{"id":"A1","text":"结论甲","correct":true,"gate_hypo_ids":["H1"]},
		{"id":"A2","text":"结论乙","correct":true,"gate_hypo_ids":["H2"]},
		{"id":"A3","text":"结论丙","correct":true,"gate_hypo_ids":["H3"]}]}}
	gv.build({"clues":cluesA,"hypo":hypoA,"persons":[],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	for _c in ["c1","c2","c3"]:
		gv._derive_hypo(_c, _c.replace("c","H")); await process_frame
	gv._derive_conclusion("H1","A1"); gv._derive_conclusion("H2","A2"); gv._derive_conclusion("H3","A3")
	await process_frame
	# 从结论甲推导新综合结论 B；从推断二推导新结论 D（hypo→conclusion）
	var a_ok := await _run_scene("自由推导", gv, [], [["conclusion_A1","B"],["H2","D"]])
	ok = ok and a_ok

	# 场景B：有人物，多结论挂人物；从结论甲推导 B、从推断一推导 E
	var gv2 = GV.new()
	var holder2 = Control.new(); root.add_child(holder2); holder2.add_child(gv2)
	await process_frame
	var cluesB := [{"id":"c1","name":"线索一"},{"id":"c2","name":"线索二"},{"id":"c3","name":"线索三"}]
	var hypoB := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断一","correct":true,"gate_clue_ids":["c1"]},
		{"id":"H2","text":"推断二","correct":true,"gate_clue_ids":["c2"]},
		{"id":"H3","text":"推断三","correct":true,"gate_clue_ids":["c3"]}],
		"conclusions":[
		{"id":"A1","text":"结论甲","correct":true,"gate_hypo_ids":["H1"],"target":"person:P"},
		{"id":"A2","text":"结论乙","correct":true,"gate_hypo_ids":["H2"],"target":"person:P"},
		{"id":"A3","text":"结论丙","correct":true,"gate_hypo_ids":["H3"],"target":"person:P"}]}}
	gv2.build({"clues":cluesB,"hypo":hypoB,"persons":[{"id":"P","name":"人物P"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	for _c in ["c1","c2","c3"]:
		gv2._derive_hypo(_c, _c.replace("c","H")); await process_frame
	gv2._derive_conclusion("H1","A1"); gv2._derive_conclusion("H2","A2"); gv2._derive_conclusion("H3","A3")
	await process_frame
	var b_ok := await _run_scene("人物锚定推导", gv2,
		[{"from":"conclusion_A1","to":"person_P","kind":"target"},
		 {"from":"conclusion_A2","to":"person_P","kind":"target"},
		 {"from":"conclusion_A3","to":"person_P","kind":"target"}],
		[["conclusion_A1","B"],["H1","E"]])
	ok = ok and b_ok

	print("OVERLAP_AFTER_DERIVE: %s" % ("PASS" if ok else "FAIL"))
	quit()
