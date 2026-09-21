extends SceneTree
## 复现思傅 2026-09-21 截图3（链路重叠）：真实卡片视图 + 生产布局路径。
## 拓扑（截图）：结论A → 推断H1/H2/H3 → (线索X1/推断X2/线索X3) → 线索Y1/Y2
## 目的：量出所有卡片的 AABB，找出重叠对与产生的环节（布局网格 vs 去重叠遗漏）。

var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	holder.add_child(canvas)
	gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C

	var SPEC := [
		["A", "conclusion", "英国在热带做的事情，为阿富汗"],
		["H1", "hypo", "多年从事军事行业形成的气质"],
		["H2", "hypo", "曾经在热带生活过"],
		["H3", "hypo", "从事医疗行业"],
		["X1", "clue", "华生站姿军人气质"],
		["X2", "hypo", "不是原来的颜色"],
		["X3", "clue", "身上有消毒液气味"],
		["Y1", "clue", "华生脸色黝黑"],
		["Y2", "clue", "华生手腕肤色分界"],
	]
	# 玩家实画笔法：from=子(更深层) → to=父
	var REL := [
		{"from": "H1", "to": "A", "kind": "support"},
		{"from": "H2", "to": "A", "kind": "support"},
		{"from": "H3", "to": "A", "kind": "support"},
		{"from": "X1", "to": "H1", "kind": "support"},
		{"from": "X2", "to": "H2", "kind": "support"},
		{"from": "X3", "to": "H3", "kind": "support"},
		{"from": "Y1", "to": "X1", "kind": "support"},
		{"from": "Y2", "to": "X2", "kind": "support"},
	]
	var nodes := []
	for s in SPEC:
		nodes.append({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})

	# 先建真实视图（生产路径同序：建视图 → 布局 → 去重叠）
	for s in SPEC:
		gv._graph_nodes.append({"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}})
		var nd := {"id": s[0], "kind": s[1], "label": s[2], "sub": "", "data": {}}
		gv._node_kind[s[0]] = s[1]
		gv._node_data[s[0]] = {}
		var v = gv._cards.make_node(nd)
		canvas.add_child(v)
		gv._node_views[s[0]] = v
	await process_frame

	gv._relations = REL
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	gv._node_center = {}

	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	out = gv._node_center

	# 尺寸汇总
	var heights := {}
	for s in SPEC:
		var v = gv._node_views[s[0]]
		heights[s[0]] = v.size.y
	print("视图高度集合: ", heights)

	print("== 布局结果（中心坐标） ==")
	var order := ["A", "H1", "H2", "H3", "X1", "X2", "X3", "Y1", "Y2"]
	for id in order:
		var c: Vector2 = out[id]
		var r: Rect2 = gv._layout._node_rect(id)
		print("  %-3s x=%7.1f y=%7.1f   框 y[%.0f,%.0f] x[%.0f,%.0f]"
			% [id, c.x, c.y, r.position.y, r.end.y, r.position.x, r.end.x])

	# 重叠检测
	print("== 重叠对 ==")
	var hits := []
	for i in order.size():
		for j in range(i + 1, order.size()):
			var a: Rect2 = gv._layout._node_rect(order[i])
			var b: Rect2 = gv._layout._node_rect(order[j])
			if a.intersects(b):
				var ov := a.intersection(b).size
				hits.append("%s×%s(%.0fx%.0f)" % [order[i], order[j], ov.x, ov.y])
	if hits.is_empty(): print("  （无）")
	else: for hh in hits: print("  " + hh)
	_chk(hits.is_empty(), "无卡片 AABB 重叠")

	# 行距检查：同列相邻卡中心距应 ≥ 卡高 + 间隙
	var bycol := {}
	for id in order:
		var key := "%.0f" % out[id].x
		if not bycol.has(key): bycol[key] = []
		bycol[key].append(id)
	for key in bycol:
		var col: Array = bycol[key]
		col.sort_custom(func(a, b): return out[a].y < out[b].y)
		for k in range(1, col.size()):
			var gap: float = out[col[k]].y - out[col[k - 1]].y
			_chk(gap >= 400.0, "列 x=%s 相邻 %s→%s 中心距=%.0f ≥400" % [key, col[k - 1], col[k], gap])

	# ===== 场景B：状态型重叠（松散根带钉位，压在链卡上）→ 兜底须清掉且不破坏五律 =====
	# 模拟思傅截图3：某根被玩家/存盘钉在非网格位（间距 245 < 卡高 400）→ 与链卡叠压。
	var nodes_b := nodes.duplicate()
	nodes_b.append({"id": "Z", "kind": "hypo", "label": "玩家另拖的一条孤立推断", "sub": "", "data": {}})
	gv._node_kind["Z"] = "hypo"
	gv._node_data["Z"] = {}
	var vz = gv._cards.make_node({"id": "Z", "kind": "hypo", "label": "玩家另拖的一条孤立推断", "sub": "", "data": {}})
	canvas.add_child(vz)
	gv._node_views["Z"] = vz
	await process_frame
	gv._relations = REL.duplicate()
	# 仅弱关联连到 X1 → 布局树里 Z 无 support 父 ⇒ 独立根（其钉位不会被“已获父节点”清除）
	gv._relations.append({"from": "Z", "to": "X1", "kind": "relate"})
	# 钉位：正好压在 X2 上（模拟截图的 245 非网格间距）
	gv._root_anchor_pos = {"Z": Vector2(out["X2"].x, out["X2"].y - 245.0)}
	gv._manual_nodes = ["Z"]
	gv._node_center = {}

	var out_b: Dictionary = gv._layout._compute_layout(nodes_b, {})
	gv._node_center = out_b.duplicate()
	gv._layout._apply_global_overlap_fix()
	var pre_fixed: bool = not gv._layout._has_overlap()
	print("场景B 兜底前是否已无重叠: ", pre_fixed, "  Z y=", gv._node_center["Z"].y)

	var out_c: Dictionary = gv._layout._resolve_residual_overlaps(nodes_b, {})
	gv._node_center = out_c.duplicate()
	_chk(not gv._layout._has_overlap(), "场景B 兜底后零重叠")
	var col_h1: float = out_c["H1"].x
	_chk(absf(out_c["H1"].x - col_h1) < 1.0 and absf(out_c["H2"].x - col_h1) < 1.0
		and absf(out_c["H3"].x - col_h1) < 1.0, "场景B 兜底后 H1/H2/H3 仍同列（美学1）")
	_chk(absf(out_c["H2"].y - out_c["H1"].y) >= 400.0
		and absf(out_c["H3"].y - out_c["H2"].y) >= 400.0, "场景B 兜底后链内行距 ≥400（美学3/兄弟有序）")
	var mid_h: float = (out_c["H1"].y + out_c["H3"].y) * 0.5
	_chk(absf(out_c["A"].y - mid_h) < 60.0, "场景B 兜底后 A 仍居中于 H 群（美学3）: A=%.0f 中点=%.0f"
		% [out_c["A"].y, mid_h])

	print("WALL_OVERLAP_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
