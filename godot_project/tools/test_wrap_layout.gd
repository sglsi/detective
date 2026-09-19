extends SceneTree
## 多列分散布局验证（2026-09-19 思傅纠正语义：分散**只针对无根零散链路**，整洁树绝不改造）：
##   段A 大 loose 森林（多条无根独立链：结论-推断-线索，总高超预算 1200）→ 按高度贪心分组横向多列：
##      A1) X 跨度显著超过单树宽（发生横向分散）
##      A2) 存在根列左侧镜像列（min_x 明显小于画布中心）
##      A3) 右列 support 边父.x < 子.x；镜像左列父.x > 子.x（镜像流）；左右均有分布
##      A4) 零重叠：所有节点 AABB 两两不相交
##   段B 小 loose 森林（总高低于预算）行为不变：单列竖排、右向流、无左镜像列、零重叠
##   段C 人物整洁树（person 根大树，总高超预算）**绝不分散**：单主列、全树右向流（根-干-枝-叶层展）
##   段D 混合场景（人物整洁树 + 大 loose 森林）：人物树独占主列右向不动；loose 链向左右分散

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("PASS " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _build_forest(n_chain: int) -> Dictionary:
	# 每条链：结论 Ri → 推断 Hi_a/Hi_b → 线索 CLi_a1/CLi_a2/CLi_b1/CLi_b2（7 节点，带分支）
	var KIND := {}
	var LABEL := {}
	var REL := []
	for i in n_chain:
		var r := "R%d" % i
		KIND[r] = "conclusion"
		LABEL[r] = "结论%d：租车人熟识马车道" % i
		for hb in ["a", "b"]:
			var h := "H%d_%s" % [i, hb]
			KIND[h] = "hypo"
			LABEL[h] = "推断%d_%s：分支推断文本" % [i, hb]
			REL.append({"from": h, "to": r, "kind": "support"})
			for k in [1, 2]:
				var c := "CL%d_%s%d" % [i, hb, k]
				KIND[c] = "clue"
				LABEL[c] = "线索%d_%s%d：支撑该推断的线索描述文本" % [i, hb, k]
				REL.append({"from": c, "to": h, "kind": "support"})
	return {"KIND": KIND, "LABEL": LABEL, "REL": REL}


func _overlap_check(gv, out: Dictionary, KIND: Dictionary, LABEL: Dictionary) -> void:
	var ids := out.keys()
	var rects := {}
	for id in ids:
		var k: String = KIND[id]
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(id, {"id": id, "kind": k, "label": LABEL[id]})
		rects[id] = Rect2(out[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var overlap := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if rects[ids[i]].grow(2.0).intersects(rects[ids[j]].grow(2.0)):
				overlap = true
				print("FAIL 重叠 %s↔%s" % [ids[i], ids[j]])
	_chk(not overlap, "零重叠：%d 节点 AABB 两两不相交" % ids.size())


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit()
		return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var center := Vector2(960.0, 540.0)

	# ---- 段A：大森林（8 条链 × 7 节点 = 56 节点，总高超预算）----
	var big := _build_forest(8)
	var nodes := []
	for id in big["KIND"]:
		nodes.append({"id": id, "kind": big["KIND"][id], "label": big["LABEL"][id]})
	gv._graph_nodes = []
	for id in big["KIND"]:
		gv._graph_nodes.append({"id": id, "kind": big["KIND"][id], "label": big["LABEL"][id], "sub": "", "data": {}})
	gv._relations = big["REL"].duplicate()
	var out := {}
	gv._layout._logic_tree_layout(nodes, center, {}, out)

	var min_x := 1e18
	var max_x := -1e18
	for id in out:
		min_x = minf(min_x, out[id].x)
		max_x = maxf(max_x, out[id].x)
	var extent := max_x - min_x
	_chk(extent > 1500.0, "A1 X 跨度 %.0f > 1500（横向多列分散生效）" % extent)
	_chk(min_x < center.x - 200.0, "A2 存在根列左侧镜像列 min_x=%.0f < %.0f" % [min_x, center.x - 200.0])
	# A3 镜像流：动态判定每链所在侧（按根→直接推断的方向），断言每链方向一致且左右均有分布
	var n_right := 0
	var n_left := 0
	var dir_ok := true
	for i in 8:
		var r := "R%d" % i
		var kids := ["H%d_a" % i, "H%d_b" % i]
		var all_right := true
		var all_left := true
		for k in kids:
			if out[r].x >= out[k].x:
				all_right = false
			if out[r].x <= out[k].x:
				all_left = false
		if all_right:
			n_right += 1
		elif all_left:
			n_left += 1
		else:
			dir_ok = false
	_chk(dir_ok, "A3 每条链方向一致（右列父<子 / 镜像左列父>子）")
	_chk(n_right >= 1 and n_left >= 1, "A3 左右两侧均有分布（右%d 链 / 左%d 链）" % [n_right, n_left])
	_overlap_check(gv, out, big["KIND"], big["LABEL"])

	# ---- 段B：小森林（1 条链，总高低于预算 1200）行为不变：单根列、右向流、无左镜像列 ----
	var small := _build_forest(1)
	var nodes2 := []
	for id in small["KIND"]:
		nodes2.append({"id": id, "kind": small["KIND"][id], "label": small["LABEL"][id]})
	gv._graph_nodes = []
	for id in small["KIND"]:
		gv._graph_nodes.append({"id": id, "kind": small["KIND"][id], "label": small["LABEL"][id], "sub": "", "data": {}})
	gv._relations = small["REL"].duplicate()
	var out2 := {}
	gv._layout._logic_tree_layout(nodes2, center, {}, out2)
	var min_x2 := 1e18
	for id in out2:
		min_x2 = minf(min_x2, out2[id].x)
	_chk(min_x2 > center.x - 300.0, "B 小森林无左镜像列 min_x=%.0f（行为不变）" % min_x2)
	var flow_ok := true
	for r in small["REL"]:
		if out2[r["to"]].x >= out2[r["from"]].x:
			flow_ok = false
	_chk(flow_ok, "B 小森林全部 support 边 右向流 父.x < 子.x")
	_overlap_check(gv, out2, small["KIND"], small["LABEL"])

	# ---- 段C：人物整洁树（person 根大树，总高超预算）绝不分散：根-干-枝-叶层展单主列 ----
	# P → 4 条干链（R）→ 各 2 推断 → 各 2 线索 = 1+4+8+16 = 29 节点
	var KINDC := {"P": "person"}
	var LABELC := {"P": "嫌疑人：神秘租车人"}
	var RELC := []
	for i in 4:
		var rc := "PR%d" % i
		KINDC[rc] = "conclusion"
		LABELC[rc] = "干结论%d：围绕人物的第一层结论" % i
		RELC.append({"from": rc, "to": "P", "kind": "support"})
		for hb in ["a", "b"]:
			var hc := "PH%d_%s" % [i, hb]
			KINDC[hc] = "hypo"
			LABELC[hc] = "枝推断%d_%s：第二层推断" % [i, hb]
			RELC.append({"from": hc, "to": rc, "kind": "support"})
			for k in [1, 2]:
				var cc := "PC%d_%s%d" % [i, hb, k]
				KINDC[cc] = "clue"
				LABELC[cc] = "叶线索%d_%s%d：支撑线索描述" % [i, hb, k]
				RELC.append({"from": cc, "to": hc, "kind": "support"})
	gv._graph_nodes = []
	for id in KINDC:
		gv._graph_nodes.append({"id": id, "kind": KINDC[id], "label": LABELC[id], "sub": "", "data": {}})
	gv._relations = RELC.duplicate()
	var out3 := {}
	var nodes3 := []
	for id in KINDC:
		nodes3.append({"id": id, "kind": KINDC[id], "label": LABELC[id]})
	gv._layout._logic_tree_layout(nodes3, center, {}, out3)
	# C1: 人物根在主列（col_x[0] = center.x）
	_chk(absf(out3["P"].x - center.x) < 1.0, "C1 人物根在主列 x=%.0f ≈ %.0f" % [out3["P"].x, center.x])
	# C2: 全树右向流（所有边父.x < 子.x）——整洁树不被镜像/拆列
	var c_flow := true
	for r in RELC:
		if out3[r["to"]].x >= out3[r["from"]].x:
			c_flow = false
	_chk(c_flow, "C2 人物整洁树全树右向流（根-干-枝-叶层展，不镜像不拆列）")
	_overlap_check(gv, out3, KINDC, LABELC)

	# ---- 段D：混合场景（人物整洁树 + 大 loose 森林）：人物树主列不动；loose 链左右分散 ----
	var KINDD := {"DP": "person"}
	var LABELD := {"DP": "嫌疑人：混合场景人物"}
	var RELD := []
	# 人物干链 1 条
	KINDD["DR0"] = "conclusion"
	LABELD["DR0"] = "人物干结论：挂在人物下的结论"
	RELD.append({"from": "DR0", "to": "DP", "kind": "support"})
	KINDD["DH0"] = "hypo"
	LABELD["DH0"] = "人物枝推断"
	RELD.append({"from": "DH0", "to": "DR0", "kind": "support"})
	KINDD["DC0"] = "clue"
	LABELD["DC0"] = "人物叶线索"
	RELD.append({"from": "DC0", "to": "DH0", "kind": "support"})
	# 大 loose 森林 8 条（无根链）
	var loose := _build_forest(8)
	for id in loose["KIND"]:
		KINDD[id] = loose["KIND"][id]
		LABELD[id] = loose["LABEL"][id]
	RELD.append_array(loose["REL"])
	gv._graph_nodes = []
	for id in KINDD:
		gv._graph_nodes.append({"id": id, "kind": KINDD[id], "label": LABELD[id], "sub": "", "data": {}})
	gv._relations = RELD.duplicate()
	var out4 := {}
	var nodes4 := []
	for id in KINDD:
		nodes4.append({"id": id, "kind": KINDD[id], "label": LABELD[id]})
	gv._layout._logic_tree_layout(nodes4, center, {}, out4)
	# D1: 人物树在主列且右向流
	_chk(absf(out4["DP"].x - center.x) < 1.0, "D1 人物根独占主列 x=%.0f" % out4["DP"].x)
	var d_flow := true
	for r in [{"from": "DR0", "to": "DP"}, {"from": "DH0", "to": "DR0"}, {"from": "DC0", "to": "DH0"}]:
		if out4[r["to"]].x >= out4[r["from"]].x:
			d_flow = false
	_chk(d_flow, "D2 人物整洁树右向流（不被分散波及）")
	# D3: loose 链左右分散：至少一条 loose 链在人物列左侧、一条在右侧
	var d_left := false
	var d_right := false
	for i in 8:
		var rr := "R%d" % i
		if out4[rr].x < center.x - 200.0:
			d_left = true
		elif out4[rr].x > center.x + 200.0:
			d_right = true
	_chk(d_left and d_right, "D3 loose 链左右两侧均有分布（左列+右列）")
	_overlap_check(gv, out4, KINDD, LABELD)

	if _ok:
		print("WRAP_RESULT: PASS — 多列分散布局全部性质验证通过")
	else:
		print("WRAP_RESULT: FAIL")
	quit()
