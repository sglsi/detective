extends SceneTree
## 方案B 华生推理链 headless 验证：完整复现「线索→推断→结论→人物」三层 + 多 gate 共推 + 推断组合推推断。
## 覆盖：
##   1) 线索→推断（列出本场景全部可见预设推断，玩家任选其一；gate 仅作后台触发口径）
##   2) 推断→推断（W-C1+W-C2→W-C3，gate_hypo_ids，方案B 新增）
##   3) 推断→结论（单 gate，如 W-A1→C-A1）
##   4) 结论由多推断共推（C-MAIN 由 W-A1+W-B1+W-C3 共推，_sync_conclusion_gate_edges 自动闭合三线）
##   5) 结论→人物 target 金边（方案A/B 归属连线）
## 运行：godot --headless --script res://tools/test_watson_chain.gd

func _initialize() -> void:
	await process_frame
	var ok := true
	var log := []

	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit(); return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame   # 触发 _ready + 首帧，子控制器就绪

	var clues := [
		{"id":"wrist","name":"华生手腕肤色分界","correct":true},
		{"id":"arm","name":"华生左臂僵硬","correct":true},
		{"id":"face_dark","name":"华生脸色黝黑","correct":true},
		{"id":"face_haggard","name":"华生面容憔悴","correct":true},
		{"id":"pose","name":"华生军人站姿","correct":true},
		{"id":"medical","name":"医务工作者风度","correct":true},
	]
	var hypo := {
		"battlefield": {
			"hypotheses": [
				{"id":"W-A1","text":"华生不是原来的肤色（热带晒痕）","correct":true,"gate_clue_ids":["wrist","face_dark"]},
				{"id":"W-B1","text":"华生是名军医","correct":true,"gate_clue_ids":["pose","medical"]},
				{"id":"W-C1","text":"华生久病初愈","correct":true,"gate_clue_ids":["face_haggard"]},
				{"id":"W-C2","text":"华生左臂受过伤","correct":true,"gate_clue_ids":["arm"]},
				{"id":"W-C3","text":"华生承受过不该有的伤痛","correct":true,"gate_hypo_ids":["W-C1","W-C2"]},
			],
			"conclusions": [
				{"id":"C-A1","text":"华生曾在热带长期生活","correct":true,"gate_hypo_ids":["W-A1"],"target":"person:NPC_WT"},
				{"id":"C-MAIN","text":"华生刚从阿富汗服役归来","correct":true,"gate_hypo_ids":["W-A1","W-B1","W-C3"],"target":"person:NPC_WT"},
				{"id":"C-C1","text":"华生参加过战争","correct":true,"gate_hypo_ids":["W-C3"],"target":"person:NPC_WT"},
			]
		}
	}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"NPC_WT","name":"华生"}],"focus_person":"NPC_WT","difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	log.append("build 完成")

	# ---- 断言 a) 线索→推断候选列出本场景全部可见预设推断（不再按 gate_clue_ids 过滤）----
	var cand_wrist: Array = gv._dockctl._derive_candidates()
	var cand_ids := cand_wrist.map(func(c): return c.get("id",""))
	var expect_a := ["W-A1","W-B1","W-C1","W-C2","W-C3"]
	if cand_ids != expect_a:
		ok = false; print("FAIL a) wrist 候选=%s 期望全部可见推断%s" % [str(cand_ids), str(expect_a)])
	else:
		log.append("a) 线索推导候选列出全部 5 条预设推断（含组合推断 W-C3），玩家任选其一")

	# ---- 正向推导全部 5 条推断 ----
	gv._derive_hypo("wrist", "W-A1")
	gv._derive_hypo("face_dark", "W-A1")
	gv._derive_hypo("pose", "W-B1")
	gv._derive_hypo("medical", "W-B1")
	gv._derive_hypo("face_haggard", "W-C1")
	gv._derive_hypo("arm", "W-C2")
	await process_frame

	# ---- 断言 b) 推断节点齐全 + 线索→推断边 ----
	for hid in ["W-A1","W-B1","W-C1","W-C2"]:
		if not gv._node_kind.has(hid):
			ok = false; print("FAIL b) 推断节点 %s 未上墙" % hid)
	if not gv._relations.any(func(r): return r.get("from","")=="wrist" and r.get("to","")=="W-A1"):
		ok = false; print("FAIL b) 缺 wrist→W-A1 边")
	if not gv._relations.any(func(r): return r.get("from","")=="face_dark" and r.get("to","")=="W-A1"):
		ok = false; print("FAIL b) 缺 face_dark→W-A1 边")
	if not gv._relations.any(func(r): return r.get("from","")=="pose" and r.get("to","")=="W-B1"):
		ok = false; print("FAIL b) 缺 pose→W-B1 边")
	if not gv._relations.any(func(r): return r.get("from","")=="medical" and r.get("to","")=="W-B1"):
		ok = false; print("FAIL b) 缺 medical→W-B1 边")
	if not gv._relations.any(func(r): return r.get("from","")=="face_haggard" and r.get("to","")=="W-C1"):
		ok = false; print("FAIL b) 缺 face_haggard→W-C1 边")
	if not gv._relations.any(func(r): return r.get("from","")=="arm" and r.get("to","")=="W-C2"):
		ok = false; print("FAIL b) 缺 arm→W-C2 边")
	else:
		log.append("b) 4 条线索→推断边均建立（含 左臂/脸色黝黑/面容憔悴/医务工作者风度）")

	# ---- 方案B：推断→推断（W-C1+W-C2→W-C3）----
	gv._derive_hypo_from_hypo("W-C1", "W-C3")
	gv._derive_hypo_from_hypo("W-C2", "W-C3")
	await process_frame

	# ---- 断言 c) W-C3 由两条推断共推 ----
	if not gv._node_kind.has("W-C3"):
		ok = false; print("FAIL c) W-C3 节点未上墙")
	if not gv._relations.any(func(r): return r.get("from","")=="W-C1" and r.get("to","")=="W-C3"):
		ok = false; print("FAIL c) 缺 W-C1→W-C3 边（推断组合推推断）")
	if not gv._relations.any(func(r): return r.get("from","")=="W-C2" and r.get("to","")=="W-C3"):
		ok = false; print("FAIL c) 缺 W-C2→W-C3 边（推断组合推推断）")
	else:
		log.append("c) W-C3 由 W-C1+W-C2 共推（方案B 推断组合生效）")

	# ---- 推导 3 条结论 ----
	gv._derive_conclusion("W-A1", "C-A1")
	gv._derive_conclusion("W-C3", "C-MAIN")
	gv._derive_conclusion("W-C3", "C-C1")
	await process_frame

	# ---- 断言 d) 单 gate 结论边 ----
	if not gv._relations.any(func(r): return r.get("from","")=="W-A1" and r.get("to","")=="conclusion_C-A1"):
		ok = false; print("FAIL d) 缺 W-A1→conclusion_C-A1")
	if not gv._relations.any(func(r): return r.get("from","")=="W-C3" and r.get("to","")=="conclusion_C-C1"):
		ok = false; print("FAIL d) 缺 W-C3→conclusion_C-C1")
	else:
		log.append("d) 单 gate 结论边 C-A1/C-C1 建立")

	# ---- 断言 e) 多 gate 共推：C-MAIN 必须同时连 W-A1 + W-B1 + W-C3 ----
	var cm_gates := []
	for r in gv._relations:
		if r.get("to","") == "conclusion_C-MAIN":
			cm_gates.append(r.get("from",""))
	if not ("W-A1" in cm_gates and "W-B1" in cm_gates and "W-C3" in cm_gates):
		ok = false; print("FAIL e) C-MAIN gate 边=%s 期望含[W-A1,W-B1,W-C3]" % cm_gates)
	else:
		log.append("e) C-MAIN 由 W-A1+W-B1+W-C3 共推三线闭合（方案B 多 gate 共推生效）")

	# ---- 断言 f) 结论→人物 target 金边（每条结论恰 1 条 →NPC_WT）----
	for cid in ["C-A1","C-MAIN","C-C1"]:
		var nid: String = "conclusion_" + str(cid)
		var has := false
		for e in gv._edge_list:
			if e.get("from","") == nid and e.get("kind","") == "target" and e.get("to","") == "NPC_WT":
				has = true; break
		if not has:
			ok = false; print("FAIL f) 缺 %s→NPC_WT 的 target 金边" % nid)
	if ok:
		log.append("f) 三条结论均有→NPC_WT 的 target 金边（归属连线显示）")

	# ---- 断言 g) 无违规自动边（不应出现 imply / 不应出现重复 gate 边）----
	var imply := 0
	for e in gv._edge_list:
		if e.get("kind","") == "imply": imply += 1
	if imply > 0:
		ok = false; print("FAIL g) 存在 %d 条 imply 自动边" % imply)
	else:
		log.append("g) 无 imply 自动边（结论链仅由玩家/派生 support + target 构成）")

	for l in log:
		print("[WATSON]", l)
	if ok:
		print("WATSON_RESULT: PASS — 方案B 华生推理链（多gate共推 + 推断组合推推断）全部验证通过")
	else:
		print("WATSON_RESULT: FAIL")
	quit()
