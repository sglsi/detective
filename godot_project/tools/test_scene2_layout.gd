extends SceneTree
## 验证场景二（case_wide 大墙）自动排列相关三项修复：
##  1) 手动连线按 人物≥结论≥推断≥线索 层级自动归一化（from=子,to=父）；
##  2) 人物↔人物 support 边形成从属嵌套（德雷伯→斯特兰森 ⇒ 斯特兰森挂德雷伯下、随其拖动跟随）；
##  3) 场景二整树归属：凶手(人物根) → 结论 → 推断 → 线索，呈放射树。

func _build_wall(persons_arr: Array, hypo: Dictionary) -> Variant:
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	gv.build({"clues":[{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true}],
		"hypo":hypo,"persons":persons_arr,"focus_person":persons_arr[0].get("id","") if not persons_arr.is_empty() else "",
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame
	return gv

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	var hypo1 := {"battlefield":{"hypotheses":[
			{"id":"H2-01","text":"乘马车来","correct":true,"gate_clue_ids":["c201","c202"]}],
		"conclusions":[{"id":"CL2-1","text":"凶手乘出租马车抵达","correct":true,"gate_hypo_ids":["H2-01"],"target":"person:KILLER"}]}}

	# ========== 1) 手动连线层级归一化 ==========
	var gv1 = await _build_wall([{"id":"KILLER","name":"凶手"}], hypo1)

	# 1a) 推断→线索（反方向，应归为 线索→推断）
	gv1._edge._add_edge("H2-01", "c201", "support", "green", false)
	await process_frame
	var r1a: Dictionary = gv1._relations.back()
	if r1a.get("from","") != "c201" or r1a.get("to","") != "H2-01":
		ok = false; print("FAIL 1a) 推断→线索 未归一化为 线索→推断：%s→%s" % [r1a.get("from",""), r1a.get("to","")])
	else:
		log.append("1a) 推断→线索 自动归为 线索→推断 ✓")

	# 1b) 结论→推断（反方向，应归为 推断→结论）
	gv1._edge._add_edge("conclusion_CL2-1", "H2-01", "support", "green", false)
	await process_frame
	var r1b: Dictionary = gv1._relations.back()
	if r1b.get("from","") != "H2-01" or r1b.get("to","") != "conclusion_CL2-1":
		ok = false; print("FAIL 1b) 结论→推断 未归一化为 推断→结论：%s→%s" % [r1b.get("from",""), r1b.get("to","")])
	else:
		log.append("1b) 结论→推断 自动归为 推断→结论 ✓")

	# 1c) 人物→结论（人物层级高，应归为 结论→人物）
	gv1._edge._add_edge("KILLER", "conclusion_CL2-1", "support", "green", false)
	await process_frame
	var r1c: Dictionary = gv1._relations.back()
	if r1c.get("from","") != "conclusion_CL2-1" or r1c.get("to","") != "KILLER":
		ok = false; print("FAIL 1c) 人物→结论 未归一化为 结论→人物：%s→%s" % [r1c.get("from",""), r1c.get("to","")])
	else:
		log.append("1c) 人物→结论 自动归为 结论→人物 ✓")

	# 1d) 线索→推断（已正确方向，保持不变）
	gv1._edge._add_edge("c202", "H2-01", "support", "green", false)
	await process_frame
	var r1d: Dictionary = gv1._relations.back()
	if r1d.get("from","") != "c202" or r1d.get("to","") != "H2-01":
		ok = false; print("FAIL 1d) 线索→推断 正确方向被误改：%s→%s" % [r1d.get("from",""), r1d.get("to","")])
	else:
		log.append("1d) 线索→推断 正确方向保持不变 ✓")

	# ========== 2) 人物↔人物 从属嵌套 ==========
	var hypo2 := {"battlefield":{"hypotheses":[],"conclusions":[]}}
	var gv2 = await _build_wall([{"id":"DREB","name":"德雷伯"},{"id":"STRAN","name":"斯特兰森"}], hypo2)
	gv2._edge._add_edge("DREB", "STRAN", "support", "green", false)
	await process_frame
	var pf2: Dictionary = gv2._layout._build_parent_of()
	if pf2.has("DREB"):
		ok = false; print("FAIL 2a) 德雷伯(上级)不应有父(失根)：%s" % str(pf2))
	elif pf2.get("STRAN","") != "DREB":
		ok = false; print("FAIL 2b) 斯特兰森父应为德雷伯，实际 %s" % str(pf2.get("STRAN","")))
	else:
		log.append("2a/2b) 人物↔人物：德雷伯为根、斯特兰森父=德雷伯(从属嵌套) ✓")

	# 2c) 拖动德雷伯，斯特兰森应随其子树跟随
	gv2._root_anchor_pos["DREB"] = Vector2(700, 880)
	if not ("DREB" in gv2._manual_nodes):
		gv2._manual_nodes.append("DREB")
	gv2._rebuild_graph()
	await process_frame
	if not gv2._layout._descendants("DREB").has("STRAN"):
		ok = false; print("FAIL 2c) 斯特兰森不在德雷伯子树内：%s" % str(gv2._layout._descendants("DREB")))
	elif not gv2._node_center.has("STRAN"):
		ok = false; print("FAIL 2c) 斯特兰森未落位")
	elif abs(gv2._node_center["STRAN"].x - 700.0) > 700.0 or abs(gv2._node_center["STRAN"].y - 880.0) > 500.0:
		ok = false; print("FAIL 2c) 斯特兰森未随德雷伯衍生(偏离过远)：%s" % str(gv2._node_center["STRAN"]))
	else:
		log.append("2c) 拖动德雷伯后斯特兰森随其子树跟随 ✓")

	# ========== 3) 场景二整树归属（自动推导流） ==========
	var gv3 = await _build_wall([{"id":"KILLER","name":"凶手"}], hypo1)
	gv3._derive_hypo("c201", "H2-01")
	await process_frame
	gv3._derive_hypo("c202", "H2-01")
	await process_frame
	gv3._derive_conclusion("H2-01", "CL2-1")
	await process_frame
	gv3._rebuild_graph()
	await process_frame
	var pf3: Dictionary = gv3._layout._build_parent_of()
	if pf3.has("KILLER"):
		ok = false; print("FAIL 3a) 凶手(人物根)不应有父：%s" % str(pf3))
	elif pf3.get("conclusion_CL2-1","") != "KILLER":
		ok = false; print("FAIL 3b) 结论 conclusion_CL2-1 父应为凶手，实际 %s" % str(pf3.get("conclusion_CL2-1","")))
	elif pf3.get("H2-01","") != "conclusion_CL2-1":
		ok = false; print("FAIL 3c) 推断 H2-01 父应为结论 conclusion_CL2-1，实际 %s" % str(pf3.get("H2-01","")))
	elif pf3.get("c201","") != "H2-01" or pf3.get("c202","") != "H2-01":
		ok = false; print("FAIL 3d) 线索 c201/c202 父应为 H2-01，实际 %s" % str(pf3))
	else:
		log.append("3a-3d) 整树归属 凶手→conclusion_CL2-1→H2-01→{c201,c202} ✓")
	for nid in ["KILLER","conclusion_CL2-1","H2-01","c201","c202"]:
		if not gv3._node_center.has(nid):
			ok = false; print("FAIL 3e) 节点未落位：%s" % nid)
	if ok:
		log.append("3e) 全节点均已落位(放射树可视) ✓")

	for l in log: print("  - " + l)
	print("SCENE2_LAYOUT_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
