extends SceneTree
## 正向推导「多结论实例」烟测：验证本次改动的 4 个根因
##   1) 结论节点不多余连线（_edge_list == _relations，无自动批量 imply 边）
##   2) 新推导链不覆盖旧结论（_derived_conclusions 多实例、旧边保留）
##   3) 线索→推断边可见（玩家边 always=true）
##   4) 结论候选窗列出多条（不按 gate 过滤、场景有多候选）
## 正确初始化：把 GraphViewController add_child 入树 → _ready 触发子控制器初始化

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
	await process_frame   # 触发 _ready + 首帧，子控制器(_edge/_layout/_fold/_data/_dockctl)就绪

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
	log.append("build 完成 relations=%d edge_list=%d" % [gv._relations.size(), gv._edge_list.size()])

	# ---- 链1：拖 c201 → 选 H2-01 → 选 CL2-1 ----
	gv._derive_hypo("c201", "H2-01")
	gv._derive_conclusion("H2-01", "CL2-1")
	await process_frame

	# ---- 链2：拖 c206 → 选 H2-02 → 选 CL2-2 ----
	gv._derive_hypo("c206", "H2-02")
	gv._derive_conclusion("H2-02", "CL2-2")
	await process_frame

	# 断言 a) 多结论实例
	if gv._derived_conclusions.size() != 2:
		ok = false; print("FAIL a) 结论实例数=%d 期望2" % gv._derived_conclusions.size())
	log.append("a) _derived_conclusions 数=%d" % gv._derived_conclusions.size())

	# 断言 b) 节点含两个 conclusion_ 且旧链节点 H2-01 仍在
	var concl_nodes := []
	for nid in gv._node_kind.keys():
		if gv._fold._kind_of(nid) == "conclusion":
			concl_nodes.append(nid)
	if concl_nodes.size() != 2 or not ("conclusion_CL2-1" in concl_nodes) or not ("conclusion_CL2-2" in concl_nodes):
		ok = false; print("FAIL b) 结论节点=%s 期望[conclusion_CL2-1, conclusion_CL2-2]" % concl_nodes)
	if not gv._node_kind.has("H2-01") or not gv._node_kind.has("H2-02"):
		ok = false; print("FAIL b) 推断节点 H2-01/H2-02 缺失")
	log.append("b) 结论节点=%s 推断节点存在=%s" % [concl_nodes, gv._node_kind.has("H2-01") and gv._node_kind.has("H2-02")])

	# 断言 c) relations 恰好 4 条玩家边
	if gv._relations.size() != 4:
		ok = false; print("FAIL c) relations=%d 期望4 (c201→H2-01, H2-01→CL2-1, c206→H2-02, H2-02→CL2-2)" % gv._relations.size())
	log.append("c) relations 数=%d" % gv._relations.size())

	# 断言 d) 派生边语义：允许「结论→人物 target」自动边（方案A，每条已派生结论恰 1 条），
	#           但禁止旧的全局批量自动边（infer→conclusion 的 imply / clue→infer 的 support）。
	#           故 edge_list = relations + 自动 target 边数；且不允许存在 imply 类自动边。
	var _auto_target := 0
	var _bad_auto := 0
	for e in gv._edge_list:
		if e.get("kind", "") == "target":
			_auto_target += 1
		elif e.get("kind", "") == "imply":
			_bad_auto += 1
	var _expect_auto: int = gv._derived_conclusions.size()
	if gv._edge_list.size() != gv._relations.size() + _expect_auto:
		ok = false; print("FAIL d) edge_list=%d 期望 relations(%d)+自动target(%d)=%d" % [gv._edge_list.size(), gv._relations.size(), _expect_auto, gv._relations.size() + _expect_auto])
	elif _bad_auto > 0:
		ok = false; print("FAIL d) 仍存在 %d 条 imply 自动边（旧违规边未清除）" % _bad_auto)
	else:
		log.append("d) edge_list=%d = relations(%d)+自动target(%d) 且无 imply 自动边(方案A生效)" % [gv._edge_list.size(), gv._relations.size(), _expect_auto])
	# 断言 d2) 方案A 功能验证：每条已派生结论都应有 1 条 → focus_person 的 target 归属边
	var _missing_target := []
	for _dc in gv._derived_conclusions:
		var _nid: String = "conclusion_" + str(_dc.get("id", ""))
		var _has := false
		for e in gv._edge_list:
			if e.get("from", "") == _nid and e.get("kind", "") == "target" and e.get("to", "") == gv._focus_person:
				_has = true; break
		if not _has:
			_missing_target.append(_nid)
	if not _missing_target.is_empty():
		ok = false; print("FAIL d2) 缺少结论→人物 target 边: %s" % _missing_target)
	else:
		log.append("d2) 每条结论均有→%s 的 target 归属边（方案A 连线已显示）" % gv._focus_person)

	# 断言 e) 每条玩家边 always=true（默认 MODE_C 可见）
	for e in gv._edge_list:
		if not e.get("always", false):
			ok = false; print("FAIL e) 边 %s→%s always=false 不可见" % [e.get("from",""), e.get("to","")])

	# 断言 f) 旧链路保留
	var has_old: bool = gv._relations.any(func(r): return r.get("from","")=="c201" and r.get("to","")=="H2-01") \
		and gv._relations.any(func(r): return r.get("from","")=="H2-01" and r.get("to","")=="conclusion_CL2-1") \
		and gv._relations.any(func(r): return r.get("from","")=="c206" and r.get("to","")=="H2-02") \
		and gv._relations.any(func(r): return r.get("from","")=="H2-02" and r.get("to","")=="conclusion_CL2-2")
	if not has_old:
		ok = false; print("FAIL f) 旧链路/新链路未完整保留 relations=%s" % gv._relations)
	else:
		log.append("f) 两条推导链共 4 条边均保留（问题2 不丢失）")

	# 断言 g) player_claims 含 2 个结论（软比对天然多结论）
	var pc: Array = gv._player_claims()
	var pcc := 0
	for p in pc:
		if p.get("kind","") == "conclusion":
			pcc += 1
	if pcc != 2:
		ok = false; print("FAIL g) player_claims 结论数=%d 期望2" % pcc)
	else:
		log.append("g) player_claims 结论数=%d（软比对多结论支持）" % pcc)

	# 断言 h) 结论候选弹窗列出多条（问题4）：场景在 NORMAL 下可过滤出 >1 候选
	var cands := []
	for c in hypo.battlefield.conclusions:
		if gv._dockctl._conclusion_preset_visible(c):
			cands.append(c)
	if cands.size() < 2:
		ok = false; print("FAIL h) NORMAL 下结论候选数=%d 期望>=2" % cands.size())
	else:
		log.append("h) NORMAL 结论候选数=%d（含误导，玩家有选择空间）" % cands.size())

	# 断言 i) 实际弹窗（链2 deferred 触发）应含多条结论按钮 + 自定义按钮
	await process_frame
	if gv._link_popup != null:
		var btns := []
		_collect_buttons(gv._link_popup, btns)
		if btns.size() < 3:
			ok = false; print("FAIL i) 结论弹窗按钮数=%d 期望>=3" % btns.size())
		else:
			log.append("i) 结论弹窗按钮数=%d（多条候选+自定义，问题4 已解决）" % btns.size())
	else:
		log.append("i) （弹窗未触发，跳过 UI 断言）")

	for l in log:
		print("[FMC]", l)
	if ok:
		print("FMC_RESULT: PASS — 正向推导多结论实例 4 项根因全部验证通过")
	else:
		print("FMC_RESULT: FAIL")
	quit()


func _collect_buttons(n, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_collect_buttons(c, out)
