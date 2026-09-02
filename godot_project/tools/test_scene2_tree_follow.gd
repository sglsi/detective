extends SceneTree
## 验证场景二（case_wide 大墙）端到端：玩家推导结论后，拖动「马车夫」人物节点，
## 其下游结论+推断整棵子树随动（方案A 读 conclusion.target 建父子边）。
## 2026-09-02 按台词库§18 六步闭环重构后：CL2-1（出租马车）为马车链观察级结论、不挂人物；
## 挂人物(target:person:KILLER)的是 CL2-4（车夫进屋·三线合一）与 CL2-6（高个体貌）。
## 本测试走 CL2-6 链：c205/c206 → H2-05/H2-06 → CL2-6 → 马车夫(KILLER)。

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
	# case_wide=true（真实场景二大墙）；persons 直接传马车夫（模拟线索 related_npcs 派生）
	gv.build({"clues":[{"id":"c201","name":"车轮印","correct":true},{"id":"c202","name":"轴距","correct":true},
		{"id":"c205","name":"脚印","correct":true},{"id":"c206","name":"步幅","correct":true}],
		"hypo":hypo, "persons":[{"id":"KILLER","name":"马车夫"}],
		"difficulty":gv.Diff.NORMAL, "editable":true, "state_store":{}, "auto_fold":false, "case_wide":true})
	await process_frame

	# 开墙即应有马车夫人物节点
	if not gv._node_kind.has("KILLER"):
		ok = false; print("FAIL 0) 马车夫人物节点未生成（开墙应可见）")
	else:
		log.append("0) 马车夫人物节点已生成 ✓")

	# 玩家推导：H2-01(c201) / H2-05(c206) / H2-06(c205) → CL2-1(H2-01) / CL2-6(H2-05)
	gv._derive_hypo("c201", "H2-01"); await process_frame
	gv._derive_hypo("c206", "H2-05"); await process_frame
	gv._derive_hypo("c205", "H2-06"); await process_frame
	gv._derive_conclusion("H2-01", "CL2-1"); await process_frame
	gv._derive_conclusion("H2-05", "CL2-6"); await process_frame
	gv._rebuild_graph(); await process_frame

	if not (gv._node_kind.has("conclusion_CL2-1") and gv._node_kind.has("conclusion_CL2-6") and gv._node_kind.has("H2-01") and gv._node_kind.has("H2-05") and gv._node_kind.has("H2-06")):
		ok = false; print("FAIL 1) 推导后的结论/推断节点未生成：%s" % str(gv._node_kind.keys()))
	else:
		log.append("1) 推导后结论/推断节点已生成 ✓")

	# 树：马车夫为根；CL2-6(target) 挂其下、H2-05/H2-06 挂 CL2-6 下；
	# CL2-1 无 target（观察级·不指认人物）→ 不应挂马车夫下
	var pf: Dictionary = gv._layout._build_parent_of()
	if pf.get("conclusion_CL2-6", "") != "KILLER":
		ok = false; print("FAIL 2) conclusion_CL2-6 父应为马车夫，实际=%s" % str(pf.get("conclusion_CL2-6","")))
	if pf.get("H2-05", "") != "conclusion_CL2-6":
		ok = false; print("FAIL 2b) H2-05 父应为 conclusion_CL2-6，实际=%s" % str(pf.get("H2-05","")))
	if pf.get("H2-06", "") != "conclusion_CL2-6":
		ok = false; print("FAIL 2c) H2-06 父应为 conclusion_CL2-6，实际=%s" % str(pf.get("H2-06","")))
	if pf.get("conclusion_CL2-1", "") == "KILLER":
		ok = false; print("FAIL 2d) conclusion_CL2-1 无 target，不应挂马车夫下")
	if ok:
		log.append("2) 马车夫→CL2-6→H2-05/H2-06 父子链正确；CL2-1 不挂人物 ✓")

	var desc: Array = gv._layout._descendants("KILLER")
	if not ("conclusion_CL2-6" in desc and "H2-05" in desc and "H2-06" in desc):
		ok = false; print("FAIL 3) 马车夫子树未含 CL2-6/H2-05/H2-06：%s" % str(desc))
	else:
		log.append("3) 马车夫子树含 CL2-6 与其推断 ✓")

	# 拖马车夫 → 整棵子树随动（平移量一致）
	var ids5 := ["KILLER","conclusion_CL2-6","H2-05","H2-06"]
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
		ok = false; print("FAIL 4) 马车夫未落在落点：%s" % str(after5["KILLER"]))
	for nid in ["conclusion_CL2-6","H2-05","H2-06"]:
		var dn: Vector2 = after5[nid] - before5[nid]
		if dn.distance_to(d0) > 60.0:
			ok = false; print("FAIL 4) %s 未随马车夫平移(Δ=%s, 期望≈%s)" % [nid, str(dn), str(d0)])
	if ok:
		log.append("4) 拖马车夫→CL2-6+推断整棵子树随动 ✓")

	# 拖结论 → 其推断随动、上游马车夫不动
	var ids6 := ["KILLER","conclusion_CL2-6","H2-05"]
	var before6 := {}
	for nid in ids6: before6[nid] = gv._node_center.get(nid, Vector2.ZERO)
	var target6 := Vector2(300, 300)
	gv._node_center["conclusion_CL2-6"] = target6
	gv._commit_move("conclusion_CL2-6", target6)
	await process_frame
	var after6 := {}
	for nid in ids6: after6[nid] = gv._node_center.get(nid, Vector2.ZERO)
	if after6["KILLER"].distance_to(before6["KILLER"]) > 60.0:
		ok = false; print("FAIL 5) 马车夫随结论移动了(不该)：%s" % str(after6["KILLER"]))
	var d_c: Vector2 = after6["conclusion_CL2-6"] - before6["conclusion_CL2-6"]
	var d_h: Vector2 = after6["H2-05"] - before6["H2-05"]
	if d_c.distance_to(d_h) > 60.0:
		ok = false; print("FAIL 5) H2-05 未随结论 CL2-6 平移(Δ=%s vs %s)" % [str(d_h), str(d_c)])
	if ok:
		log.append("5) 拖结论→其推断随动、马车夫不动 ✓")

	for l in log: print("  - " + l)
	print("SCENE2_TREE_FOLLOW_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
