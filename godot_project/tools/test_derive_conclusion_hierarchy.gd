extends SceneTree
## 验证第七章「结论层级判定缺陷」修复（Step1 + Step2）：
##   test_derive_conclusion_hierarchy：从结论推导下一层结论后，新结论必须是源的上一级根（非下一级叶）；
##      链路 CB → CA → H1 → c1 在布局中右向严格递增（串行结论成链、不并排、不颠倒）。
##   test_derive_edge_direction：结论→结论、推断→推断 推导边断言 from=源(前提)、to=新(综合)，
##      两函数方向一致（防回归，确保 _add_derived_conclusion 与 _derive_hypo_from_hypo 不打架）。
##   test_conclusion_chain_order：场景一风格 C-MAIN 在 W-C3 上一级、W-C3 在 W-C1/W-C2 上一级。
func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	# ---------- 段1：结论→结论 推导层级 ----------
	var clues := [{"id":"c1","name":"线索：并排车轮印","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断：轮距符合出租马车","correct":true,"gate_clue_ids":["c1"]}],
		"conclusions":[
		{"id":"CA","text":"结论A：凶手乘出租马车抵达","correct":true,"gate_hypo_ids":["H1"]},
		{"id":"CB","text":"结论B：凶手有预谋且熟悉地形","correct":true,"gate_hypo_ids":["CA"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"KILLER","name":"凶手"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("c1","H1")
	await process_frame
	gv._derive_conclusion("H1","CA")            # 推断→结论
	await process_frame
	gv._derive_conclusion("conclusion_CA","CB") # 结论→结论：CA 是源(hid)，CB 是新结论
	await process_frame
	gv._rebuild_graph()
	await process_frame

	var po: Dictionary = gv._layout._build_parent_of()
	if po.get("conclusion_CA","") != "conclusion_CB":
		ok = false; print("FAIL H1) conclusion_CA 的父应为 conclusion_CB（CB 在 CA 上一级根），实际=%s" % po.get("conclusion_CA",""))
	else:
		print("  - H1) CB 是 CA 的父（新结论为源的上一级根，非下一级叶）✓")
	if po.get("H1","") != "conclusion_CA":
		ok = false; print("FAIL H1) H1 的父应为 conclusion_CA，实际=%s" % po.get("H1",""))
	else:
		print("  - H1) H1 挂在 CA 下 ✓")

	var nc: Dictionary = gv._node_center
	var chain_ok: bool = nc.has("conclusion_CB") and nc.has("conclusion_CA") and nc.has("H1") and nc.has("c1") \
		and nc["conclusion_CB"].x < nc["conclusion_CA"].x and nc["conclusion_CA"].x < nc["H1"].x and nc["H1"].x < nc["c1"].x
	if not chain_ok:
		ok = false; print("FAIL H1) 右向链期望 CB.x<CA.x<H1.x<c1.x，实际=%s" % [nc.get("conclusion_CB",Vector2.ZERO).x, nc.get("conclusion_CA",Vector2.ZERO).x, nc.get("H1",Vector2.ZERO).x, nc.get("c1",Vector2.ZERO).x])
	else:
		print("  - H1) 右向流 CB<CA<H1<c1（串行结论成链、不并排、不颠倒）✓")

	# ---------- 段2：推导边方向一致（防回归） ----------
	var _edges: Array = gv._relations
	var _c2c := false   # 结论→结论：from=源 CA, to=新 CB
	for _r in _edges:
		if _r.get("from","") == "conclusion_CA" and _r.get("to","") == "conclusion_CB" and _r.get("kind","") == "support":
			_c2c = true
	if not _c2c:
		ok = false; print("FAIL H2) 结论→结论边方向应为 from=conclusion_CA(源) to=conclusion_CB(新)，实际=%s" % _edges)
	else:
		print("  - H2) 结论→结论边 from=源 to=新 ✓")
	# 推断→推断方向：_derive_hypo_from_hypo(src, dst) 应建 from=src to=dst
	gv._derive_hypo_from_hypo("H1","H1")  # 无意义自环会被校验拦截，仅验证不崩；换用真实组合
	# 构造两个推断：H1 已存在；再造 H2 由 H1 组合（需 gate_hypo_ids）
	var hypo2 := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断1","correct":true,"gate_clue_ids":["c1"]},
		{"id":"H2","text":"推断2=推断1组合","correct":true,"gate_hypo_ids":["H1"]}]}}
	gv.build({"clues":clues,"hypo":hypo2,"persons":[{"id":"KILLER","name":"凶手"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("c1","H1")
	await process_frame
	gv._derive_hypo_from_hypo("H1","H2")
	await process_frame
	var _h2h := false
	for _r in gv._relations:
		if _r.get("from","") == "H1" and _r.get("to","") == "H2" and _r.get("kind","") == "support":
			_h2h = true
	if not _h2h:
		ok = false; print("FAIL H2) 推断→推断边方向应为 from=H1(源) to=H2(新)，实际=%s" % gv._relations)
	else:
		print("  - H2) 推断→推断边 from=源 to=新（与结论推导一致）✓")

	# ---------- 段3：场景一风格链路层级（W-C3=W-C1+W-C2 组合；C-MAIN=共推） ----------
	var clues3 := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"arm","name":"华生左臂僵硬","correct":true},
		{"id":"face_haggard","name":"华生面容憔悴","correct":true}]
	var hypo3 := {"battlefield":{"hypotheses":[
		{"id":"W-C1","text":"华生左臂受过伤","correct":true,"gate_clue_ids":["arm"]},
		{"id":"W-C2","text":"华生久病初愈","correct":true,"gate_clue_ids":["face_haggard"]},
		{"id":"W-C3","text":"华生承受过伤痛","correct":true,"gate_hypo_ids":["W-C1","W-C2"]}],
		"conclusions":[
		{"id":"C-MAIN","text":"华生刚从阿富汗归来","correct":true,"gate_hypo_ids":["W-C3"],"target":"person:NPC_WT"}]}}
	gv.build({"clues":clues3,"hypo":hypo3,"persons":[{"id":"NPC_WT","name":"华生"}],
		"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("arm","W-C1"); gv._derive_hypo("face_haggard","W-C2")
	await process_frame
	gv._derive_hypo_from_hypo("W-C1","W-C3"); gv._derive_hypo_from_hypo("W-C2","W-C3")
	await process_frame
	gv._derive_conclusion("W-C3","C-MAIN")
	await process_frame
	gv._rebuild_graph()
	await process_frame
	var po3: Dictionary = gv._layout._build_parent_of()
	# 正确语义（修复后）：C-MAIN 由 W-C3 推导出，位于 W-C3 上一级（root 向）= C-MAIN 是 W-C3 的父；
	# W-C3 由 W-C1/W-C2 组合推得 = W-C3 是 W-C1/W-C2 的父。链路(root→leaf)：C-MAIN → W-C3 → W-C1/W-C2。
	if po3.get("W-C3","") != "conclusion_C-MAIN":
		ok = false; print("FAIL H3) W-C3 的父应为 conclusion_C-MAIN（C-MAIN 在 W-C3 上一级），实际=%s" % po3.get("W-C3",""))
	else:
		print("  - H3) C-MAIN 在 W-C3 上一级（C-MAIN 是 W-C3 的父）✓")
	if not (po3.get("W-C1","") == "W-C3" or po3.get("W-C2","") == "W-C3"):
		ok = false; print("FAIL H3) W-C1/W-C2 的父应为 W-C3（组合来源），实际 W-C1父=%s W-C2父=%s" % [po3.get("W-C1",""), po3.get("W-C2","")])
	else:
		print("  - H3) W-C3 在 W-C1/W-C2 上一级（W-C3 是组合父）✓")
	var nc3: Dictionary = gv._node_center
	var _order3: bool = nc3.has("W-C1") and nc3.has("W-C3") and nc3.has("conclusion_C-MAIN") \
		and nc3["conclusion_C-MAIN"].x < nc3["W-C3"].x and nc3["W-C3"].x < nc3["W-C1"].x
	if not _order3:
		ok = false; print("FAIL H3) 右向链期望 C-MAIN.x<W-C3.x<W-C1.x，实际 C-MAIN=%.0f W-C3=%.0f W-C1=%.0f" % [nc3.get("conclusion_C-MAIN",Vector2.ZERO).x, nc3.get("W-C3",Vector2.ZERO).x, nc3.get("W-C1",Vector2.ZERO).x])
	else:
		print("  - H3) 右向链 C-MAIN<W-C3<W-C1（串行链不并排、不颠倒）✓")

	print("DERIVE_HIERARCHY_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
