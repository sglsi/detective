extends SceneTree
## 无根链布局验证（2026-09-19 思傅定案；2026-09-21 修订：纯无根森林**永不拆列**）：
##   有树（person/event 根）且主列叶子(树叶+同列无根叶) > 6 → 无根链整体搬到「树右侧新空区域」
##   （按 >6 叶分列：每 6 叶一列、列间留 gap）、与树留清晰间隔（不递归切分）。
##   纯无根森林（无任何人物/事件根）**任意叶数一律单主列垂直堆叠**——2026-09-21 思傅 图1/图3 根治：
##   旧「>6 叶自身多列铺开」把树切进不同 x 列、各列独立垂直居中 → 整树横向甩飞（图3）、树带交错起伏
##   （图1）；图2 证明单主列带状堆叠才是正确形态。
##   整洁树（person/event 根）结构完全不动、永不镜像、始终主列垂直堆叠居中。
##   段A 纯无根森林（8 分支链·32 叶 >6·无人物根）：**永不拆列**、单主列垂直堆叠、右向流、零重叠（2026-09-21 修订）
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
	# A1: 2026-09-21 修订：纯无根森林永不拆列 → 8 个结论根全部落单主列（x=center）
	var root_xs := {}
	for i in 8:
		root_xs[outA["R%d" % i].x] = true
	_chk(root_xs.size() == 1 and absf(outA["R0"].x - center.x) < 1.0,
		"A1 纯无根森林 32 叶 → 永不拆列，8 结论根全部单主列 x=%.0f（占 %d 列）" % [outA["R0"].x, root_xs.size()])
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
	var min_lr := 1e18
	for v in loose_root_xs:
		lcolset[v] = true
		min_lr = minf(min_lr, v)
	# D3~D5（2026-09-22 更新）：原「无根链 8 叶 >6 → 分 ≥2 列 + 整体搬树右侧」机制**已退役**
	# （存档：docs/backup/layout_leaf6_relocate_backup.md）。新契约 = 全部根**并入单主列垂直堆叠**；
	# 宽屏横向排布由 R3 组件装箱承担（目标 = 最小化整墙适配屏幕所需缩放）。
	_chk(lcolset.size() == 1 and absf(min_lr - center.x) < 1.0,
		"D3 无根链并入单主列（x=%.0f = 主列 %.0f；不再按叶数分列）" % [min_lr, center.x])
	_chk(absf(min_lr - out4["DP"].x) < 1.0, "D4 无根链与人物根同列（x=%.0f）" % min_lr)
	var right_roots := 0
	for id in loose_ids:
		if out4[id].x > tree_right + 1.0:
			right_roots += 1
	_chk(right_roots == 0, "D5 不再有「搬树右侧」的独立列（右侧根数=%d）" % right_roots)
	_overlap_check(gv, out4, KINDD, LABELD)

	# ---- 段E：视觉相连的无根链（同一连通分量的多个根）不得被别的树分隔 ----
	# 拓扑：分量1 = {E1→EH1→(EC1..EC3)} 与 {E3→EH3→(EC4..EC6)}，两者以 relate（弱关联）边相连——
	#   布局树只认 support/target，故 E1/E3 是两个独立根，但玩家视觉上是一棵树；
	#   分量2 = {E2→EH2→(EC7..EC9)} 另一棵无关的树。
	# 叶数 9（2026-09-21 修订前 >6 会触发「无根森林多列铺开」；修订后永不拆列，本段仍验证
	# 同分量根同列不被分隔）。
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

	# ---- 段G：弱连线视觉树应按「一棵树」排（思傅 2026-09-21 图1：三棵无根树水平起伏）----
	# 每棵视觉树：线索 -support-> 推断；推断 -relate(弱关联)-> 结论（结论/推断在布局树各为根）
	var kindG := {}
	var labelG := {}
	var relG := []
	for i in 3:
		var gc := "GC%d" % i
		var gh := "GH%d" % i
		var gr := "GR%d" % i
		kindG[gc] = "clue"
		kindG[gh] = "hypo"
		kindG[gr] = "conclusion"
		labelG[gc] = "线索%d：支撑线索描述文本" % i
		labelG[gh] = "推断%d：中间推断描述文本" % i
		labelG[gr] = "结论%d：链式结论描述文本" % i
		relG.append({"from": gc, "to": gh, "kind": "support"})
		relG.append({"from": gh, "to": gr, "kind": "relate"})
	gv._graph_nodes = []
	for idg in kindG:
		gv._graph_nodes.append({"id": idg, "kind": kindG[idg], "label": labelG[idg], "sub": "", "data": {}})
	gv._relations = relG.duplicate()
	var nodesG := []
	for idg in kindG:
		nodesG.append({"id": idg, "kind": kindG[idg], "label": labelG[idg]})
	# G1 逻辑图布局：每棵视觉树的 线索/推断/结论 应同 y（水平平整）
	var outG := {}
	gv._layout._logic_tree_layout(nodesG, center, {}, outG)
	for i in 3:
		var yc: float = outG["GC%d" % i].y
		var yh: float = outG["GH%d" % i].y
		var yr: float = outG["GR%d" % i].y
		var dev: float = maxf(absf(yc - yh), absf(yh - yr))
		_chk(dev < 1.0, "G1 视觉树%d 三节点同 y（dev=%.0fpx，线索/推断/结论 y=%.0f/%.0f/%.0f）" % [i, dev, yc, yh, yr])
	_overlap_check(gv, outG, kindG, labelG)
	# G2 平衡布局同口径
	var outG2 := {}
	gv._layout._balanced_tree_layout(nodesG, center, {}, outG2)
	for i in 3:
		var yc2: float = outG2["GC%d" % i].y
		var yh2: float = outG2["GH%d" % i].y
		var yr2: float = outG2["GR%d" % i].y
		var dev2: float = maxf(absf(yc2 - yh2), absf(yh2 - yr2))
		_chk(dev2 < 1.0, "G2 平衡布局 视觉树%d 三节点同 y（dev=%.0fpx）" % [i, dev2])
	_overlap_check(gv, outG2, kindG, labelG)

	# ---- 段H：图2 复现——多根弱链大分量 + 支撑链，深度列必须整齐（结构服从关系）----
	var kindH := {}
	var labelH := {}
	var relH := []
	for i in 2:
		var hc := "HC%d" % i
		var hh := "HH%d" % i
		var hr := "HR%d" % i
		kindH[hc] = "clue"
		kindH[hh] = "hypo"
		kindH[hr] = "conclusion"
		labelH[hc] = "线索：支撑文本"
		labelH[hh] = "推断：中间文本"
		labelH[hr] = "结论：链尾文本"
		relH.append({"from": hc, "to": hh, "kind": "support"})
		relH.append({"from": hh, "to": hr, "kind": "support"})
	relH.append({"from": "HR0", "to": "HR1", "kind": "relate"})
	for idh in kindH:
		gv._graph_nodes.append({"id": idh, "kind": kindH[idh], "label": labelH[idh], "sub": "", "data": {}})
	gv._relations = relH.duplicate()
	var nodesH := []
	for idh in kindH:
		nodesH.append({"id": idh, "kind": kindH[idh], "label": labelH[idh]})
	var outH := {}
	gv._layout._logic_tree_layout(nodesH, center, {}, outH)
	for i in 2:
		var yhc: float = outH["HC%d" % i].y
		var yhh: float = outH["HH%d" % i].y
		var yhr: float = outH["HR%d" % i].y
		var devh: float = maxf(absf(yhc - yhh), absf(yhh - yhr))
		_chk(devh < 1.0, "H1 视觉链%d 三节点同 y（dev=%.0fpx）" % [i, devh])
	var xs_by_kind := {"clue": {}, "hypo": {}, "conclusion": {}}
	for idh in outH:
		xs_by_kind[kindH[idh]][outH[idh].x] = true
	for kk in xs_by_kind:
		_chk(xs_by_kind[kk].size() == 1, "H2 %s 全部节点同 x 列（占 %d 列）" % [kk, xs_by_kind[kk].size()])
	_overlap_check(gv, outH, kindH, labelH)

	# ---- 段I：思傅 2026-09-21 图1/图2/图3 复现——纯 support 无根森林任意叶数都单主列（结构服从关系）----
	# 全实线 support（游戏方向 from=子/to=父）。拓扑：
	#   T1: C10→C11(串行)→H10→{CL10a,CL10b}
	#   T2: C20→{H20a,H20b}→{CL20a,CL20b}（extra 时再加无子推断 H20c）
	#   T3: C30→C31(串行)→{H30a,H30b}→{CL30a,CL30b}
	# R = 6 叶（=图2 正确形态）；S = 7 叶（旧代码 >6 触发拆列 → 结论根被甩到另一列（图3）+ 树带交错（图1））。
	for case_i in 2:
		var extra: bool = case_i == 1
		var tagI: String = "I%s" % ("S7" if extra else "R6")
		var kindI := {}
		var labelI := {}
		var relI := []
		kindI["C10"] = "conclusion"; kindI["C11"] = "conclusion"; kindI["H10"] = "hypo"
		kindI["CL10a"] = "clue"; kindI["CL10b"] = "clue"
		labelI["C10"] = "结论10"; labelI["C11"] = "结论10b"; labelI["H10"] = "推断10"
		labelI["CL10a"] = "线索10a"; labelI["CL10b"] = "线索10b"
		relI.append({"from": "C11", "to": "C10", "kind": "support"})
		relI.append({"from": "H10", "to": "C11", "kind": "support"})
		relI.append({"from": "CL10a", "to": "H10", "kind": "support"})
		relI.append({"from": "CL10b", "to": "H10", "kind": "support"})
		kindI["C20"] = "conclusion"; kindI["H20a"] = "hypo"; kindI["H20b"] = "hypo"
		kindI["CL20a"] = "clue"; kindI["CL20b"] = "clue"
		labelI["C20"] = "结论20"; labelI["H20a"] = "推断20a"; labelI["H20b"] = "推断20b"
		labelI["CL20a"] = "线索20a"; labelI["CL20b"] = "线索20b"
		relI.append({"from": "H20a", "to": "C20", "kind": "support"})
		relI.append({"from": "H20b", "to": "C20", "kind": "support"})
		relI.append({"from": "CL20a", "to": "H20a", "kind": "support"})
		relI.append({"from": "CL20b", "to": "H20b", "kind": "support"})
		if extra:
			kindI["H20c"] = "hypo"
			labelI["H20c"] = "推断20c（无子线索，本身即叶子）"
			relI.append({"from": "H20c", "to": "C20", "kind": "support"})
		kindI["C30"] = "conclusion"; kindI["C31"] = "conclusion"
		kindI["H30a"] = "hypo"; kindI["H30b"] = "hypo"
		kindI["CL30a"] = "clue"; kindI["CL30b"] = "clue"
		labelI["C30"] = "结论30"; labelI["C31"] = "结论30b"
		labelI["H30a"] = "推断30a"; labelI["H30b"] = "推断30b"
		labelI["CL30a"] = "线索30a"; labelI["CL30b"] = "线索30b"
		relI.append({"from": "C31", "to": "C30", "kind": "support"})
		relI.append({"from": "H30a", "to": "C31", "kind": "support"})
		relI.append({"from": "H30b", "to": "C31", "kind": "support"})
		relI.append({"from": "CL30a", "to": "H30a", "kind": "support"})
		relI.append({"from": "CL30b", "to": "H30b", "kind": "support"})
		gv._graph_nodes = []
		var nodesI := []
		for idi in kindI:
			gv._graph_nodes.append({"id": idi, "kind": kindI[idi], "label": labelI[idi], "sub": "", "data": {}})
			nodesI.append({"id": idi, "kind": kindI[idi], "label": labelI[idi]})
		gv._relations = relI.duplicate()
		var outI := {}
		gv._layout._logic_tree_layout(nodesI, center, {}, outI)
		# I-1 结论根全部单主列
		var root_xsI := {}
		for rid in ["C10", "C20", "C30"]:
			root_xsI[outI[rid].x] = true
		_chk(root_xsI.size() == 1 and absf(outI["C10"].x - center.x) < 1.0,
			"%s-1 三结论根全部单主列 x=%.0f（占 %d 列）" % [tagI, outI["C10"].x, root_xsI.size()])
		# I-2 T1 串行链水平平整（C10/C11/H10 同 y）
		var d1: float = maxf(absf(outI["C10"].y - outI["C11"].y), absf(outI["C11"].y - outI["H10"].y))
		_chk(d1 < 1.0, "%s-2 T1 串行链三节点同 y（dev=%.0fpx）" % [tagI, d1])
		# I-3 三棵树的 y 区间互不交错（带状堆叠）
		var treesI := {
			"T1": ["C10", "C11", "H10", "CL10a", "CL10b"],
			"T2": ["C20", "H20a", "H20b", "CL20a", "CL20b"],
			"T3": ["C30", "C31", "H30a", "H30b", "CL30a", "CL30b"],
		}
		if extra:
			treesI["T2"].append("H20c")
		var rangesI := []
		var inter := false
		for t in treesI:
			var gmin := 1e18
			var gmax := -1e18
			for nid in treesI[t]:
				gmin = minf(gmin, outI[nid].y)
				gmax = maxf(gmax, outI[nid].y)
			rangesI.append([gmin, gmax])
		for i in range(1, rangesI.size()):
			if rangesI[i - 1][1] >= rangesI[i][0] - 0.5:
				inter = true
		_chk(not inter, "%s-3 三树带互不交错（y 区间 %s）" % [tagI, str(rangesI)])
		# I-4 全部 support 边右向流
		var flowI := true
		for r in relI:
			if outI[r["to"]].x >= outI[r["from"]].x:
				flowI = false
		_chk(flowI, "%s-4 全部 support 边右向流" % tagI)
		_overlap_check(gv, outI, kindI, labelI)

	if _ok:
		print("WRAP_RESULT: PASS — 叶子计数触发搬迁布局全部性质验证通过")
	else:
		print("WRAP_RESULT: FAIL")
	quit()
