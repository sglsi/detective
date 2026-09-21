extends SceneTree
## 验证「多带行网格错位」机制：两条独立根链（不同高度）→ 带起点非整行 → 带间行错位/半行叠压。
## 预期（修复前）：带1单行与带2子行偏移不是 ROW_STEP 整数倍（半行 → 同列卡叠压）。
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
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new(); canvas.size = Vector2(1920, 1080); holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	# 链1：单链（A1→H1→L1，全单子 ⇒ 同一行）
	# 链2：A2→{H2, K2}（双子 ⇒ 父居中于子，产生半步跨度 ⇒ 带高为奇数次半步）
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
		gv._graph_nodes.append({"id":s[0],"kind":s[1],"label":s[2],"sub":"","data":{}})
		gv._node_kind[s[0]] = s[1]; gv._node_data[s[0]] = {}
		var v = gv._cards.make_node({"id":s[0],"kind":s[1],"label":s[2],"sub":"","data":{}})
		canvas.add_child(v); gv._node_views[s[0]] = v
	await process_frame
	gv._relations = REL; gv._root_anchor_pos = {}; gv._manual_nodes = []; gv._node_center = {}
	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	out = gv._node_center
	print("== 多带布局结果 ==")
	for s in SPEC: print("  %-3s x=%7.1f y=%7.1f" % [s[0], out[s[0]].x, out[s[0]].y])
	# 行距基准：链1三卡应同行
	print("链1 内部 y: %.1f %.1f %.1f" % [out["A1"].y, out["H1"].y, out["L1"].y])
	# 链2：A2 应为 H2/K2 中点
	var mid: float = (out["H2"].y + out["K2"].y) * 0.5
	_chk(absf(out["A2"].y - mid) < 1.0, "链2 父居中于子 A2=%.1f 中点=%.1f" % [out["A2"].y, mid])
	# 跨带行对齐：链1行(A1) 与 链2 子行 之差应为行距整数倍
	var step: float = absf(out["H2"].y - out["K2"].y)
	var d1: float = absf(out["A1"].y - out["H2"].y)
	var d2: float = absf(out["A1"].y - out["K2"].y)
	var r1: float = fmod(d1, step); var r2: float = fmod(d2, step)
	print("行距=%.1f  d1=%.1f(余%.1f)  d2=%.1f(余%.1f)" % [step, d1, r1, d2, r2])
	_chk(minf(r1, step - r1) < 2.0 or minf(r2, step - r2) < 2.0,
		"跨带行网格对齐（至少一条与链1同行）")
	# 跨带共格：各带「叶子行（tidy 偏移 0）」应落在同一行网格上（H1/H2/H3 均为各带首子行的代表）。
	# 旧实现每带累加一次 subtree_sep(40) ⇒ 相邻带叶子行差 = 480+40=520（非 480 整数倍）→ 行网格错位。
	var rows := {"链一": out["H1"].y, "链二": out["H2"].y, "链三": out["H3"].y}
	var bad := []
	var keys: Array = rows.keys()
	for i in range(1, keys.size()):
		var diff: float = absf(rows[keys[i]] - rows[keys[i - 1]])
		var rem: float = fmod(diff, step)
		if minf(rem, step - rem) > 2.0:
			bad.append("%s↔%s 差=%.0f(余%.0f)" % [keys[i - 1], keys[i], diff, rem])
	_chk(bad.is_empty(), "各带叶子行共格（差为行距 %.0f 整数倍）" % step
		+ ("" if bad.is_empty() else "；违例：" + ", ".join(bad)))
	print("叶子行: 链一=%.0f 链二=%.0f 链三=%.0f" % [out["H1"].y, out["H2"].y, out["H3"].y])
	print("MULTIBAND_GRID_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
