extends SceneTree
## 无根链「叶子计数触发分散」布局验证（2026-09-19 思傅定案）：
##   分散对象 = 全部无根链（结论-推断-线索 / 推断-线索，单枝或多枝的「无根森林」同属此类）。
##   两分支：
##     · 有树（person/event 根）且主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬到「树右侧新空区域」（按 >6 叶分列：每 6 叶一列、列间留 gap）、与树留清晰间隔（不递归切分）。
##     · 纯无根森林（无任何人物/事件根）且叶子 > 6 → 无根链「自身多列铺开」（按每列≤6叶切 n 列、顺序切块、列间留 gap、整体水平居中）。
##   整洁树（person/event 根）结构完全不动、永不镜像、始终主列垂直堆叠居中。
##   不触发（≤6 叶）/ 无无根链 → 全部根单主列（旧版行为）。
##   段A 纯无根森林（8 分支链·32 叶 >6·无人物根）：自身多列铺开、右向流、零重叠
##   段A2 小纯无根森林（1 分支链·4 叶 ≤6）：不分散、单主列、零重叠
##   段B 小案（人物树 2 叶 + 1 短无根链 = 3 叶 ≤6）：单主列、不搬迁、零重叠
##   段C 人物整洁树独立（无无根链）：单主列、根-干-枝-叶层展、全树右向流、零重叠
##   段D 混合（人物树 2 叶 + 8 无根链 = 10 叶 >6）：人物树主列不动；无根链搬到树右侧并按 >6 叶分 2 列（无左镜像）、零重叠

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


func _build_loose_chain(prefix: String, idx: int) -> Dictionary:
	# 单条无根链：结论 L{idx} → 线索 LC{idx}（2 节点，1 叶子）；前缀用于避免 id 冲突
	var r := "%sL%d" % [prefix, idx]
	var c := "%sLC%d" % [prefix, idx]
	var KIND := {r: "conclusion", c: "clue"}
	var LABEL := {r: "无根结论%d：独立推理链" % idx, c: "无根线索%d：支撑线索" % idx}
	var REL := [{"from": c, "to": r, "kind": "support"}]
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


func _rightmost_of(out: Dictionary, id_set: Array) -> float:
	var mx := -1e18
	for id in id_set:
		if out.has(id):
			mx = maxf(mx, out[id].x)
	return mx


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

	# ---- 段A：纯无根森林（8 条分支链·32 叶 >6·无人物根）→ 自身多列铺开 ----
	var big := _build_forest(8)
	var kindA := {}
	var labelA := {}
	var relA := []
	for id in big["KIND"]:
		kindA[id] = big["KIND"][id]
		labelA[id] = big["LABEL"][id]
	relA.append_array(big["REL"])
	gv._graph_nodes = []
	for id in kindA:
		gv._graph_nodes.append({"id": id, "kind": kindA[id], "label": labelA[id], "sub": "", "data": {}})
	gv._relations = relA.duplicate()
	var nodesA := []
	for id in kindA:
		nodesA.append({"id": id, "kind": kindA[id], "label": labelA[id]})
	var outA := {}
	gv._layout._logic_tree_layout(nodesA, center, {}, outA)
	# A1: 多列 → 结论根 R0..R7 应落在 ≥2 个不同 x 列
	var root_xs := {}
	for i in 8:
		root_xs[outA["R%d" % i].x] = true
	_chk(root_xs.size() >= 2, "A1 纯无根森林 32 叶 >6 → 自身多列铺开（结论根占 %d 个 x 列 ≥2）" % root_xs.size())
	# A2/A3: 多列整体相对画布中心水平居中（向两侧铺开）
	var minAx := 1e18
	var maxAx := -1e18
	for id in outA:
		minAx = minf(minAx, outA[id].x)
		maxAx = maxf(maxAx, outA[id].x)
	_chk(minAx < center.x - 200.0, "A2 多列向左铺开（最左 x=%.0f < 中心-200）" % minAx)
	_chk(maxAx > center.x + 200.0, "A3 多列向右铺开（最右 x=%.0f > 中心+200）" % maxAx)
	var flowA := true
	for r in relA:
		if outA[r["to"]].x >= outA[r["from"]].x:
			flowA = false
	_chk(flowA, "A4 纯无根森林全部 support 边右向流 父.x < 子.x")
	_overlap_check(gv, outA, kindA, labelA)

	# ---- 段A2：小纯无根森林（1 条分支链·4 叶 ≤6·无人物根）→ 不分散、单主列 ----
	var small := _build_forest(1)
	var kindA2 := {}
	var labelA2 := {}
	var relA2 := []
	for id in small["KIND"]:
		kindA2[id] = small["KIND"][id]
		labelA2[id] = small["LABEL"][id]
	relA2.append_array(small["REL"])
	gv._graph_nodes = []
	for id in kindA2:
		gv._graph_nodes.append({"id": id, "kind": kindA2[id], "label": labelA2[id], "sub": "", "data": {}})
	gv._relations = relA2.duplicate()
	var nodesA2 := []
	for id in kindA2:
		nodesA2.append({"id": id, "kind": kindA2[id], "label": labelA2[id]})
	var outA2 := {}
	gv._layout._logic_tree_layout(nodesA2, center, {}, outA2)
	var rootA2_xs := {}
	for i in 1:
		rootA2_xs[outA2["R%d" % i].x] = true
	_chk(rootA2_xs.size() == 1, "A2-1 小纯无根森林 4 叶 ≤6 → 不分散（结论根仅 1 个 x 列）")
	_chk(absf(outA2["R0"].x - center.x) < 1.0, "A2-2 结论根在主列 x=%.0f" % outA2["R0"].x)
	_overlap_check(gv, outA2, kindA2, labelA2)

	# ---- 段B：小案（人物树 2 叶 + 1 条短无根链 = 3 叶 ≤6）→ 单主列、不搬迁 ----
	var kindB := {"BP": "person", "BDR0": "conclusion", "BDH0": "hypo", "BDC0": "clue"}
	var labelB := {"BP": "嫌疑人：小案人物", "BDR0": "干结论", "BDH0": "枝推断", "BDC0": "叶线索"}
	var relB := [{"from": "BDR0", "to": "BP", "kind": "support"},
		{"from": "BDH0", "to": "BDR0", "kind": "support"},
		{"from": "BDC0", "to": "BDH0", "kind": "support"}]
	var lc := _build_loose_chain("B", 0)
	for id in lc["KIND"]:
		kindB[id] = lc["KIND"][id]
		labelB[id] = lc["LABEL"][id]
	relB.append_array(lc["REL"])
	gv._graph_nodes = []
	for id in kindB:
		gv._graph_nodes.append({"id": id, "kind": kindB[id], "label": labelB[id], "sub": "", "data": {}})
	gv._relations = relB.duplicate()
	var nodesB := []
	for id in kindB:
		nodesB.append({"id": id, "kind": kindB[id], "label": labelB[id]})
	var outB := {}
	gv._layout._logic_tree_layout(nodesB, center, {}, outB)
	_chk(absf(outB["BP"].x - center.x) < 1.0, "B1 小案人物根在主列 x=%.0f ≈ %.0f" % [outB["BP"].x, center.x])
	# 无根链根 BL0 仍在主列附近（与人物同列、未搬走）：距中心不超过 1 个 level_sep
	var bl0: String = lc["KIND"].keys()[0]
	_chk(absf(outB[bl0].x - center.x) < 400.0, "B2 小案无根链未搬迁（仍在主列附近 x=%.0f）" % outB[bl0].x)
	var flowB := true
	for r in relB:
		if outB[r["to"]].x >= outB[r["from"]].x:
			flowB = false
	_chk(flowB, "B3 小案全部 support 边右向流")
	_overlap_check(gv, outB, kindB, labelB)

	# ---- 段C：人物整洁树独立（无无根链）绝不分散：根-干-枝-叶层展单主列 ----
	# P → 4 条干链（R）→ 各 2 推断 → 各 2 线索 = 1+4+8+16 = 29 节点
	var KINDC := {"CP": "person"}
	var LABELC := {"CP": "嫌疑人：神秘租车人"}
	var RELC := []
	for i in 4:
		var rc := "CPR%d" % i
		KINDC[rc] = "conclusion"
		LABELC[rc] = "干结论%d：围绕人物的第一层结论" % i
		RELC.append({"from": rc, "to": "CP", "kind": "support"})
		for hb in ["a", "b"]:
			var hc := "CPH%d_%s" % [i, hb]
			KINDC[hc] = "hypo"
			LABELC[hc] = "枝推断%d_%s：第二层推断" % [i, hb]
			RELC.append({"from": hc, "to": rc, "kind": "support"})
			for k in [1, 2]:
				var cc := "CPC%d_%s%d" % [i, hb, k]
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
	_chk(absf(out3["CP"].x - center.x) < 1.0, "C1 人物根在主列 x=%.0f ≈ %.0f" % [out3["CP"].x, center.x])
	var c_flow := true
	for r in RELC:
		if out3[r["to"]].x >= out3[r["from"]].x:
			c_flow = false
	_chk(c_flow, "C2 人物整洁树全树右向流（根-干-枝-叶层展，不镜像不拆列）")
	_overlap_check(gv, out3, KINDC, LABELC)

	# ---- 段D：混合（人物树 2 叶 + 8 无根链 = 10 叶 >6）→ 无根链搬到树右侧并按 >6 叶分列 ----
	var KINDD := {"DP": "person"}
	var LABELD := {"DP": "嫌疑人：混合场景人物"}
	var RELD := []
	# 人物树：DP → 2 干结论 → 各 1 推断 → 各 1 线索（2 叶）
	for i in 2:
		var dr := "DDR%d" % i
		KINDD[dr] = "conclusion"
		LABELD[dr] = "人物干结论%d" % i
		RELD.append({"from": dr, "to": "DP", "kind": "support"})
		var dh := "DDH%d" % i
		KINDD[dh] = "hypo"
		LABELD[dh] = "人物枝推断%d" % i
		RELD.append({"from": dh, "to": dr, "kind": "support"})
		var dc := "DDC%d" % i
		KINDD[dc] = "clue"
		LABELD[dc] = "人物叶线索%d" % i
		RELD.append({"from": dc, "to": dh, "kind": "support"})
	# 8 条无根链（每条 1 叶）→ 合计 2+8=10 > 6 触发搬迁；无根叶 8 > 6 → 分 2 列
	var loose_ids := []
	for i in 8:
		var lc2 := _build_loose_chain("D", i)
		for id in lc2["KIND"]:
			KINDD[id] = lc2["KIND"][id]
			LABELD[id] = lc2["LABEL"][id]
			if lc2["KIND"][id] == "conclusion":
				loose_ids.append(id)
		RELD.append_array(lc2["REL"])
	gv._graph_nodes = []
	for id in KINDD:
		gv._graph_nodes.append({"id": id, "kind": KINDD[id], "label": LABELD[id], "sub": "", "data": {}})
	gv._relations = RELD.duplicate()
	var out4 := {}
	var nodes4 := []
	for id in KINDD:
		nodes4.append({"id": id, "kind": KINDD[id], "label": LABELD[id]})
	gv._layout._logic_tree_layout(nodes4, center, {}, out4)
	# D1: 人物根在主列
	_chk(absf(out4["DP"].x - center.x) < 1.0, "D1 人物根独占主列 x=%.0f" % out4["DP"].x)
	# D2: 人物树右向流（不被搬迁波及）
	var d_parent := {"DDR0": "DP", "DDR1": "DP", "DDH0": "DDR0", "DDH1": "DDR1", "DDC0": "DDH0", "DDC1": "DDH1"}
	var d_flow := true
	for id in d_parent.keys():
		if out4[id].x <= out4[d_parent[id]].x:
			d_flow = false
	_chk(d_flow, "D2 人物整洁树右向流（不被搬迁波及）")
	# D3: 树最右沿
	var tree_ids := ["DP", "DDR0", "DDR1", "DDH0", "DDH1", "DDC0", "DDC1"]
	var tree_right := _rightmost_of(out4, tree_ids)
	# D4: 无根链按 >6 叶分列 → 结论根应落在 ≥2 个不同 x 列
	var loose_root_xs := []
	for id in loose_ids:
		loose_root_xs.append(out4[id].x)
	var lcolset := {}
	for v in loose_root_xs:
		lcolset[v] = true
	_chk(lcolset.size() >= 2, "D3 无根链 8 叶 >6 → 分 ≥2 列（结论根占 %d 个 x 列）" % lcolset.size())
	# D5: 所有无根链整体在树右侧，且与树留清晰间隔（≥120，明显非同一整体）
	var min_lr := 1e18
	for v in loose_root_xs:
		min_lr = minf(min_lr, v)
	_chk(min_lr > tree_right + 120.0, "D4 无根链整体搬到树右侧且留清晰间隔（min_x=%.0f > 树最右沿 %.0f + 120）" % [min_lr, tree_right])
	_chk(min_lr > center.x, "D5 无根链无左镜像列（全部在中心右侧）")
	_overlap_check(gv, out4, KINDD, LABELD)

	# ---- 段E：视觉相连的无根链（同一连通分量的多个根）不得被别的树分隔 ----
	# 拓扑：分量1 = {E1→EH1→(EC1..EC3)} 与 {E3→EH3→(EC4..EC6)}，两者以 relate（弱关联）边相连——
	#   布局树只认 support/target，故 E1/E3 是两个独立根，但玩家视觉上是一棵树；
	#   分量2 = {E2→EH2→(EC7..EC9)} 另一棵无关的树。
	# 叶数 9 > 6 → 触发「无根森林多列铺开」；若按根顺序切块，E1 与 E3 会被 E2 隔开并分到两列
	# （思傅 2026-09-21 截图现象：同一棵无根树的两个树枝被另一棵无根树分隔）。
	var kindE := {}
	var labelE := {}
	var relE := []
	for spec in [["E1", "EH1", ["EC1", "EC2", "EC3"]], ["E2", "EH2", ["EC7", "EC8", "EC9"]], ["E3", "EH3", ["EC4", "EC5", "EC6"]]]:
		var re: String = spec[0]
		var he: String = spec[1]
		kindE[re] = "conclusion"
		labelE[re] = "结论%s：该链的顶层结论" % re
		kindE[he] = "hypo"
		labelE[he] = "推断%s：支撑结论的推断" % he
		relE.append({"from": he, "to": re, "kind": "support"})
		for ce in spec[2]:
			kindE[ce] = "clue"
			labelE[ce] = "线索%s：该推断的支撑线索" % ce
			relE.append({"from": ce, "to": he, "kind": "support"})
	relE.append({"from": "EH1", "to": "EH3", "kind": "relate"})
	gv._graph_nodes = []
	for ide in kindE:
		gv._graph_nodes.append({"id": ide, "kind": kindE[ide], "label": labelE[ide], "sub": "", "data": {}})
	gv._relations = relE.duplicate()
	var nodes5 := []
	for ide in kindE:
		nodes5.append({"id": ide, "kind": kindE[ide], "label": labelE[ide]})
	var out5 := {}
	gv._layout._logic_tree_layout(nodes5, center, {}, out5)
	var e1x: float = out5["E1"].x
	var e3x: float = out5["E3"].x
	_chk(absf(e1x - e3x) < 1.0,
		"E1 同一连通分量的两个根同列（E1.x=%.0f, E3.x=%.0f）" % [e1x, e3x])
	var e1y: float = out5["E1"].y
	var e2y: float = out5["E2"].y
	var e3y: float = out5["E3"].y
	var e2x: float = out5["E2"].x
	# 仅在「另一棵树与同分量根落在同一列」时才构成视觉分隔；不同列各自垂直居中不算
	var same_col := absf(e2x - e1x) < 1.0
	var between := same_col and (e2y - e1y) * (e2y - e3y) < 0.0
	_chk(not between,
		"E2 另一棵树不在同列插进同分量的两根之间（E1.x=%.0f / E2.x=%.0f / E3.x=%.0f；y=%.0f/%.0f/%.0f）" % [e1x, e2x, e3x, e1y, e2y, e3y])
	_overlap_check(gv, out5, kindE, labelE)

	if _ok:
		print("WRAP_RESULT: PASS — 叶子计数触发搬迁布局全部性质验证通过")
	else:
		print("WRAP_RESULT: FAIL")
	quit()
