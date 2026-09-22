extends SceneTree
## R3 组件矩形装箱回归（2026-09-22）：三条互不相关的独立链 = 三个弱连通分量 → 三个矩形块。
## 新契约（取代旧的「所有组件的带共用一张全局行网格」）：
##   ① 链内整洁树不变（父居中于子 / 同层共线）
##   ② 真实卡片矩形零重叠
##   ③ 组件矩形两两不相交（分量为最小装箱单位）
##   ④ 同一货架行内的组件**顶对齐**（装箱行的对齐性质 → 视觉上成排）
##   ⑤ 确定性：同一输入重复布局结果逐点一致（装箱必须稳定）
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _compute(gv, nodes: Array) -> Dictionary:
	gv._node_center = {}
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	return gv._node_center

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	# 链1：单链（同行）；链2：结论双子；链3：结论三子（高度不同 → 旧实现会带间漂移）
	var SPEC := [["A1","conclusion","链一结论"],["H1","hypo","链一推断"],["L1","clue","链一线索"],
		["A2","conclusion","链二结论"],["H2","hypo","链二推断甲"],["K2","clue","链二线索乙"],
		["A3","conclusion","链三结论"],["H3","hypo","链三推断"],["J3","clue","链三线索"],
		["M3","clue","链三线索二"]]
	var REL := [{"from":"H1","to":"A1","kind":"support"},{"from":"L1","to":"H1","kind":"support"},
		{"from":"H2","to":"A2","kind":"support"},{"from":"K2","to":"A2","kind":"support"},
		{"from":"H3","to":"A3","kind":"support"},{"from":"J3","to":"A3","kind":"support"},
		{"from":"M3","to":"A3","kind":"support"}]
	var nodes := []
	for s in SPEC:
		nodes.append({"id":s[0],"kind":s[1],"label":s[2],"sub":"","data":{}})
		gv._node_kind[s[0]] = s[1]; gv._node_data[s[0]] = {}
		var v = gv._cards.make_node({"id":s[0],"kind":s[1],"label":s[2],"sub":"","data":{}})
		canvas.add_child(v); gv._node_views[s[0]] = v
	await process_frame
	gv._relations = REL

	var out: Dictionary = _compute(gv, nodes)
	print("== 三链装箱结果 ==")
	for s in SPEC: print("  %-3s x=%7.1f y=%7.1f" % [s[0], out[s[0]].x, out[s[0]].y])

	# ① 链内整洁树
	_chk(absf(out["A1"].y - out["H1"].y) < 1.0 and absf(out["H1"].y - out["L1"].y) < 1.0,
		"链1（单链）三卡同行")
	var mid: float = (out["H2"].y + out["K2"].y) * 0.5
	_chk(absf(out["A2"].y - mid) < 1.0, "链2 父居中于子 A2=%.1f 中点=%.1f" % [out["A2"].y, mid])
	_chk(absf(out["H3"].x - out["J3"].x) < 1.0 and absf(out["J3"].x - out["M3"].x) < 1.0,
		"链3 三个子节点同列（同层共线）")

	# ② 真实卡片矩形零重叠
	var ids: Array = out.keys(); ids.sort()
	var ov := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if absf(out[ids[i]].x - out[ids[j]].x) < 260.0 and absf(out[ids[i]].y - out[ids[j]].y) < 400.0:
				ov.append("%s×%s" % [ids[i], ids[j]])
	_chk(ov.is_empty(), "真实卡片矩形零重叠%s" % ("" if ov.is_empty() else "；" + str(ov)))

	# ③④ 组件矩形不相交 + 同货架行顶对齐
	var comp: Dictionary = gv._layout._relation_components()
	var groups := {}
	for k in out.keys():
		var cid: int = int(comp.get(str(k), -1))
		if not groups.has(cid): groups[cid] = []
		groups[cid].append(str(k))
	var boxes := []
	for cid in groups.keys():
		var lo := Vector2(1e18, 1e18); var hi := Vector2(-1e18, -1e18)
		for sid in groups[cid]:
			lo = Vector2(minf(lo.x, out[sid].x - 130.0), minf(lo.y, out[sid].y - 200.0))
			hi = Vector2(maxf(hi.x, out[sid].x + 130.0), maxf(hi.y, out[sid].y + 200.0))
		boxes.append([cid, lo, hi])
	print("组件矩形（%d 个）：" % boxes.size())
	for b in boxes:
		print("  分量%s  %.0f×%.0f @(%.0f,%.0f)" % [b[0], b[2].x - b[1].x, b[2].y - b[1].y, b[1].x, b[1].y])
	var inter := []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var A = boxes[i]; var B = boxes[j]
			if A[1].x < B[2].x and B[1].x < A[2].x and A[1].y < B[2].y and B[1].y < A[2].y:
				inter.append("分量%s×分量%s" % [A[0], B[0]])
	_chk(inter.is_empty(), "组件矩形两两不相交%s" % ("" if inter.is_empty() else "；" + str(inter)))
	var tops := {}
	for b in boxes: tops[int(round(b[1].y))] = int(tops.get(int(round(b[1].y)), 0)) + 1
	var same_row := 0
	for k in tops.keys(): same_row = maxi(same_row, int(tops[k]))
	_chk(same_row >= 2, "同一货架行顶对齐（最多同顶组件数 = %d）" % same_row)

	# ⑤ 确定性
	var out2: Dictionary = _compute(gv, nodes)
	var drift := []
	for k in out.keys():
		if absf(out[k].x - out2[k].x) > 0.5 or absf(out[k].y - out2[k].y) > 0.5:
			drift.append(str(k))
	_chk(drift.is_empty(), "装箱确定性（重复布局逐点一致）%s" % ("" if drift.is_empty() else "；漂移：" + str(drift)))

	print("MULTIBAND_GRID_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
