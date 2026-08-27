extends SceneTree
## 节点去重叠验证：分两层
##   层A（确定性单元测试）：直接调用 _find_non_overlapping_position，给定锚点与若干已占节点，
##        连续请求 8 个新结论位置，断言两两 AABB（含间隙）均不相交——验证螺旋碰撞算法本身正确。
##   层B（集成）：拖 2 条推断链各 2 结论，断言「任意两结论节点不重合(中心距>20)」「结论不压在父推断上」，
##        即用户截图那种「结论-推断糊成一团」的核心问题已解决。
## 正确初始化：把 GraphViewController add_child 入树 → _ready 触发子控制器初始化。

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
	await process_frame

	# ---------- 层A：螺旋算法确定性单元测试 ----------
	var fake := {}
	fake["anchor"] = Vector2(500.0, 500.0)
	var got := []
	for k in 8:
		gv._node_kind["t%d" % k] = "conclusion"  # 登记真实 kind，让落点算法按 conclusion 尺寸判定碰撞（与生产一致）
		var p: Vector2 = gv._layout._find_non_overlapping_position(Vector2(500.0, 500.0), "t%d" % k, "conclusion", fake)
		got.append(p)
		fake["t%d" % k] = p
	# 用落点算法自身的碰撞模型（结论尺寸 + clearance）校验最终 8 点两两不重叠——与算法同模型，避免假阳性
	var cw: float = gv._layout._node_width_for_kind("conclusion")
	var ch: float = maxf(gv._layout._view_height("t0"), 110.0)
	var a_ok := true
	for k in 8:
		var id: String = "t%d" % k
		var rect := Rect2(got[k] - Vector2(cw, ch) * 0.5, Vector2(cw, ch))
		if gv._layout._intersects_any(rect, fake, id, 20.0):
			a_ok = false
			ok = false
			print("FAIL 螺旋最终配置中 %s 仍与某节点重叠 (pos=%s)" % [id, got[k]])
	if a_ok:
		log.append("层A 螺旋单元测试：连续 8 位置两两不重叠 ✓")

	# ---------- 层B：集成推导链 ----------
	var clues := [
		{"id":"c201","name":"车轮印与并行车轮印","correct":true,"relation_tags":["H2-01"]},
		{"id":"c206","name":"大步幅脚印","correct":true,"relation_tags":["H2-02"]},
	]
	var hypo := {
		"battlefield": {
			"hypotheses": [
				{"id":"H2-01","text":"凶手乘出租马车来到花园街3号","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["出租马车","马车"],"gate_clue_ids":["c201"]},
				{"id":"H2-02","text":"凶手身高六英尺以上","kind":"true","correct":true,"dir":"affirm","subject":["凶手"],"object":["六英尺","高个"],"gate_clue_ids":["c206"]},
			],
			"conclusions": [
				{"id":"CL2-1","text":"凶手乘出租马车抵达现场","kind":"true","dir":"affirm","subject":["凶手"],"object":["出租马车"],"gate_hypo_ids":["H2-01"]},
				{"id":"CL2-2","text":"凶手是高大强壮的成年男性","kind":"true","dir":"affirm","subject":["凶手"],"object":["高大","强壮"],"gate_hypo_ids":["H2-02"]},
				{"id":"CL2-1M","text":"凶手徒步踏泥大步进入花园","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["徒步"],"gate_hypo_ids":["H2-01"]},
				{"id":"CL2-2M","text":"凶手身材矮小、体格瘦弱","kind":"mislead","dir":"affirm","subject":["凶手"],"object":["矮小"],"gate_hypo_ids":["H2-02"]},
			]
		}
	}
	gv.build({"clues":clues,"hypo":hypo,"persons":[],"difficulty":gv.Diff.NORMAL,"editable":true,"state_store":{},"auto_fold":false})
	await process_frame

	gv._derive_hypo("c201", "H2-01")
	gv._derive_conclusion("H2-01", "CL2-1")
	await process_frame
	gv._derive_conclusion("H2-01", "CL2-1M")
	await process_frame
	gv._derive_hypo("c206", "H2-02")
	gv._derive_conclusion("H2-02", "CL2-2")
	await process_frame
	gv._derive_conclusion("H2-02", "CL2-2M")
	await process_frame

	var ids: Array = gv._node_center.keys()
	var concl := []
	for nid in ids:
		if gv._fold._kind_of(nid) == "conclusion":
			concl.append(nid)

	# 断言1：任意两结论节点中心不重合（<20px 视为糊在一起）
	var dup := false
	for i in concl.size():
		for j in range(i + 1, concl.size()):
			if gv._node_center[concl[i]].distance_to(gv._node_center[concl[j]]) < 20.0:
				dup = true
	if dup:
		ok = false; print("FAIL 存在中心几乎重合的结论节点=%s" % concl)
	else:
		log.append("层B 断言1：%d 个结论节点互不重合 ✓" % concl.size())

	# 断言2：每个结论不压在其父推断上（中心距>20，排除正好叠在父节点）
	var on_parent := false
	for cid in concl:
		var hid: String = cid.replace("conclusion_", "")
		# hid 可能为 CL2-1 等结论 id；父推断需反查：结论由哪条推断推出=其 support 边 from
		for r in gv._relations:
			if r.get("to","") == cid:
				var ph: String = r.get("from","")
				if gv._node_center.has(ph) and gv._node_center[cid].distance_to(gv._node_center[ph]) < 20.0:
					on_parent = true
	if on_parent:
		ok = false; print("FAIL 存在结论节点压在父推断上")
	else:
		log.append("层B 断言2：结论均未压在父推断上 ✓")

	for l in log:
		print("[NOVLAP]", l)
	if ok:
		print("NOVLAP_RESULT: PASS — 螺旋落点去重叠验证通过")
	else:
		print("NOVLAP_RESULT: FAIL")
	quit()
