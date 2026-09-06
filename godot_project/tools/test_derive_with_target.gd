extends SceneTree
## 复现 + 验证「带人物锚定的结论 A + 玩家从 A 推导新结论 B」的层级：
##   期望：B 必须是 A 的父（B 在 A 上一级根），且 B 应接在 A 的父链（人物 P）之下，
##        形成 P ← B ← A 紧凑三段（A 经 B 仍挂在人物链上，拖动 P 带动下游）。
##   旧 bug：A 父候选 = {P(person_anchored), B(support)}，选父时 person_anchored 权重压过 B，
##        A 选 P、B 落空成孤立 root 与 P 并列 → 新结论没升到 A 上一级（思傅报的"层级不对"）。
func _initialize() -> void:
	await process_frame
	var ok := true
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new(); root.add_child(holder); holder.add_child(gv)
	await process_frame

	var clues := [{"id":"c1","name":"线索1","correct":true}]
	var hypo := {"battlefield":{"hypotheses":[
		{"id":"H1","text":"推断1","correct":true,"gate_clue_ids":["c1"]}],
		"conclusions":[
		{"id":"A","text":"结论A（带人物锚定）","correct":true,"gate_hypo_ids":["H1"],"target":"person:P"},
		{"id":"B","text":"结论B（从A推导的综合结论）","correct":true,"gate_hypo_ids":["H1"]}]}}
	gv.build({"clues":clues,"hypo":hypo,"persons":[{"id":"P","name":"人物P"}],
		"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	gv._derive_hypo("c1","H1")
	await process_frame
	gv._derive_conclusion("H1","A")            # 生成 conclusion_A
	await process_frame
	# 模拟玩家把结论 A 拖到人物 P（建 target 金边）→ A 挂 P 下（这也是思傅看到「人物→结论」跟随树的前提）
	gv._relations.append({"from":"conclusion_A","to":"person_P","kind":"target"})
	gv._rebuild_graph()
	await process_frame
	gv._derive_conclusion("conclusion_A","B")  # 玩家从 A 推导 B：A→B support（B 应为 A 的父）
	await process_frame
	gv._rebuild_graph()
	await process_frame

	var po: Dictionary = gv._layout._build_parent_of()
	print("DEBUG relations:")
	for _r in gv._relations:
		print("  " + str(_r.get("from","")) + " -> " + str(_r.get("to","")) + " (" + str(_r.get("kind","")) + ")")
	print("DEBUG parent_of=" + str(po))
	# T1：B 必须是 A 的父（B 在 A 上一级）
	if po.get("conclusion_A","") != "conclusion_B":
		ok = false
		print("FAIL T1) conclusion_A 的父应为 conclusion_B（B 在 A 上一级根），实际=%s" % po.get("conclusion_A",""))
	else:
		print("  - T1) B 是 A 的父（新结论为源的上一级）✓")
	# T2：B 应接在 A 的父链（人物 P）之下，形成 P←B←A（而非 B 孤立 root）
	if po.get("conclusion_B","") != "person_P":
		ok = false
		print("FAIL T2) conclusion_B 的父应为 person_P（接在 A 的父链上，P←B←A 紧凑三段），实际=" + str(po.get("conclusion_B","")))
	else:
		print("  - T2) B 接在 person_P 下（P←B←A，A 经 B 仍挂人物链）✓")
	# T3：从 parent_of 推导层级深度（root→leaf 递增），验证 B 在 A 上一级且链 P←B←A 紧凑
	# 不依赖 _node_center 读取时机（headless 下布局坐标持久化不稳定），直接验证关系树层级。
	var is_child := {}
	for _k in po.keys():
		is_child[_k] = true
	var roots := []
	for _v in po.values():
		if not is_child.has(_v):
			roots.append(_v)
	var depth_of := {}
	for _r in roots:
		depth_of[_r] = 0
		var qq := [_r]
		while qq.size() > 0:
			var u = qq.pop_front()
			for _c in po.keys():
				if po[_c] == u:
					depth_of[_c] = depth_of[u] + 1
					qq.append(_c)
	var _dB: int = depth_of.get("conclusion_B", 99)
	var _dA: int = depth_of.get("conclusion_A", 99)
	var _dH: int = depth_of.get("H1", 99)
	var _dc: int = depth_of.get("c1", 99)
	if _dB < _dA and _dA < _dH and _dH < _dc:
		print("  - T3) 层级深度 P(%d)<B(%d)<A(%d)<H1(%d)<c1(%d)（新结论 B 在 A 上一级、沿 root→leaf 递增）✓" % [depth_of.get("person_P",0), _dB, _dA, _dH, _dc])
	else:
		ok = false
		print("FAIL T3) 层级深度错（期望 P<B<A<H1<c1）：" + str(depth_of))
	print("DERIVE_TARGET_RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit()
