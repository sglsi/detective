extends SceneTree
## 验证场景二（case_wide 大墙）修复端到端：玩家推导结论后，拖动「凶手」人物节点，
## 其下游结论+推断整棵子树随动（方案A 读 conclusion.target 建父子边；场景二结论原缺 target、且无人物节点）。
## 使用场景二真实 reasoning_hypothesis()（已带 target:"person:KILLER"）。

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var sc = load("res://scripts/scene/scene2.gd")
	var hypo: Dictionary = sc.new().reasoning_hypothesis()
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame
	# case_wide=true（真实场景二大墙）；persons 直接传凶手（模拟线索 related_npcs 派生）；clues 给推导用
	gv.build({"clues":[{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true},
		{"id":"c205","name":"脚印","correct":true},{"id":"c206","name":"步幅","correct":true}],
		"hypo":hypo, "persons":[{"id":"KILLER","name":"凶手"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame

	# 开墙即应有凶手人物节点（此前场景二缺人物节点）
	if not gv._node_kind.has("KILLER"):
		ok = false; print("FAIL 0) 凶手人物节点未生成（开墙应可见）")
	else:
		log.append("0) 凶手人物节点已生成 ✓")

	# 玩家推导：CL2-1(H2-01: c201,c202) / CL2-3(H2-03: c205)
	gv._derive_hypo("c201", "H2-01"); await process_frame
	gv._derive_hypo("c202", "H2-01"); await process_frame
	gv._derive_hypo("c205", "H2-03"); await process_frame
	gv._derive_conclusion("H2-01", "CL2-1"); await process_frame
	gv._derive_conclusion("H2-03", "CL2-3"); await process_frame
	gv._rebuild_graph(); await process_frame

	if not (gv._node_kind.has("conclusion_CL2-1") and gv._node_kind.has("conclusion_CL2-3") and gv._node_kind.has("H2-01") and gv._node_kind.has("H2-03")):
		ok = false; print("FAIL 1) 推导后的结论/推断节点未生成：%s" % str(gv._node_kind.keys()))
	else:
		log.append("1) 推导后结论/推断节点已生成 ✓")

	# 树：凶手为根；推导结论挂其下；推断挂结论下
	var pf: Dictionary = gv._layout._build_parent_of()
	if pf.get("conclusion_CL2-1", "") != "KILLER":
		ok = false; print("FAIL 2) conclusion_CL2-1 父应为凶手，实际=%s" % str(pf.get("conclusion_CL2-1","")))
	if pf.get("conclusion_CL2-3", "") != "KILLER":
		ok = false; print("FAIL 2b) conclusion_CL2-3 父应为凶手，实际=%s" % str(pf.get("conclusion_CL2-3","")))
	if pf.get("H2-01", "") != "conclusion_CL2-1":
		ok = false; print("FAIL 2c) H2-01 父应为 conclusion_CL2-1，实际=%s" % str(pf.get("H2-01","")))
	if ok:
		log.append("2) 凶手→结论→推断 父子链正确 ✓")

	var desc: Array = gv._layout._descendants("KILLER")
	if not ("conclusion_CL2-1" in desc and "conclusion_CL2-3" in desc and "H2-01" in desc and "H2-03" in desc):
		ok = false; print("FAIL 3) 凶手子树未含推导结论/推断：%s" % str(desc))
	else:
		log.append("3) 凶手子树含全部推导结论与推断 ✓")

	# 拖凶手 → 整棵子树随动（平移量一致）
	var ids5 := ["KILLER","conclusion_CL2-1","conclusion_CL2-3","H2-01","H2-03"]
	var before5 := {}
	for nid in ids5: before5[nid] = gv._node_center.get(nid, Vector2.ZERO)
	var target5 := Vector2(820, 760)
	gv._node_center["KILLER"] = target5
	gv._state = gv.State.EDITABLE
	gv._commit_move("KILLER", target5)
	await process_frame
	var after5 := {}
	for nid in ids5: after5[nid] = gv._node_center.get(nid, Vector2.ZERO)
	var d0: Vector2 = after5["KILLER"] - before5["KILLER"]
	if after5["KILLER"].distance_to(target5) > 5.0:
		ok = false; print("FAIL 4) 凶手未落在落点：%s" % str(after5["KILLER"]))
	for nid in ["conclusion_CL2-1","conclusion_CL2-3","H2-01","H2-03"]:
		var dn: Vector2 = after5[nid] - before5[nid]
		if dn.distance_to(d0) > 60.0:
			ok = false; print("FAIL 4) %s 未随凶手平移(Δ=%s, 期望≈%s)" % [nid, str(dn), str(d0)])
	if ok:
		log.append("4) 拖凶手→结论+推断整棵子树随动 ✓")

	# 拖结论 → 其推断随动、上游凶手不动
	var ids6 := ["KILLER","conclusion_CL2-1","H2-01"]
	var before6 := {}
	for nid in ids6: before6[nid] = gv._node_center.get(nid, Vector2.ZERO)
	var target6 := Vector2(300, 300)
	gv._node_center["conclusion_CL2-1"] = target6
	gv._commit_move("conclusion_CL2-1", target6)
	await process_frame
	var after6 := {}
	for nid in ids6: after6[nid] = gv._node_center.get(nid, Vector2.ZERO)
	if after6["KILLER"].distance_to(before6["KILLER"]) > 60.0:
		ok = false; print("FAIL 5) 凶手随结论移动了(不该)：%s" % str(after6["KILLER"]))
	var d_c: Vector2 = after6["conclusion_CL2-1"] - before6["conclusion_CL2-1"]
	var d_h: Vector2 = after6["H2-01"] - before6["H2-01"]
	if d_c.distance_to(d_h) > 60.0:
		ok = false; print("FAIL 5) H2-01 未随结论 CL2-1 平移(Δ=%s vs %s)" % [str(d_h), str(d_c)])
	if ok:
		log.append("5) 拖结论→其推断随动、凶手不动 ✓")

	for l in log: print("  - " + l)
	print("SCENE2_TREE_FOLLOW_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
