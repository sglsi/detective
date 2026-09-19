extends SceneTree
## 诊断：do_relocate（树 + 无根链分 2 列）时，两列无根链之间的可见水平间隔
## 应等于「160 + 无根链半宽」规则下的可见间隔（= col_gap = 160），而非旧版的 160 - 半宽。

var _ok := true
func _chk(cond: bool, msg: String) -> void:
	if cond: print("PASS " + msg)
	else: _ok = false; print("FAIL " + msg)

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	if gv._canvas != null:
		gv._canvas.size = Vector2(5000.0, 4000.0)
	var center := Vector2(960.0, 540.0)

	var KIND := {}
	var LABEL := {}
	var REL := []
	KIND["P1"] = "person"; LABEL["P1"] = "人物：张三"
	for i in 2:
		var c := "C%d" % i
		KIND[c] = "conclusion"; LABEL[c] = "结论%d" % i
		REL.append({"from": c, "to": "P1", "kind": "support"})
		var h := "H%d" % i
		KIND[h] = "hypo"; LABEL[h] = "推断%d" % i
		REL.append({"from": h, "to": c, "kind": "support"})
		var cl := "CL%d" % i
		KIND[cl] = "clue"; LABEL[cl] = "线索%d" % i
		REL.append({"from": cl, "to": h, "kind": "support"})
	for i in 8:
		var rc := "LC%d" % i
		KIND[rc] = "conclusion"; LABEL[rc] = "无根结论%d" % i
		var lc := "LCL%d" % i
		KIND[lc] = "clue"; LABEL[lc] = "无根线索%d" % i
		REL.append({"from": lc, "to": rc, "kind": "support"})

	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL.duplicate()
	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})

	var out := {}
	gv._layout._balanced_tree_layout(nodes, center, {}, out)

	# 把每条无根链（结论根 + 其线索子）归到同一列；按根索引进列
	var per: int = ceili(8.0 / maxf(1.0, ceili(8.0 / 6.0)))   # 与布局口径一致：ncols=ceili(8/6)=2 → per=4
	var col_members: Array = []
	for i in 8:
		var ci: int = i / per
		while col_members.size() <= ci:
			col_members.append([])
		col_members[ci].append("LC%d" % i)
		col_members[ci].append("LCL%d" % i)
	var col_xs: Array = []
	for c in col_members:
		col_xs.append(out[c[0]].x)
	_chk(col_members.size() >= 2, "无根链 ≥2 列（实际 %d 列）" % col_members.size())

	# 树最右沿（人物各节点 x 最大值 + 半宽）与首列无根链最左节点左沿的可见间隔
	var tree_right := -1e18
	for id in ["P1", "C0", "C1", "H0", "H1", "CL0", "CL1"]:
		tree_right = maxf(tree_right, out[id].x + gv._layout._node_width_for_kind(KIND[id]) * 0.5)
	var first_col_left := 1e18
	for id in col_members[0]:
		first_col_left = minf(first_col_left, out[id].x - gv._layout._node_width_for_kind(KIND[id]) * 0.5)
	var tree_to_first_gap: float = first_col_left - tree_right
	print("INFO 树→首列可见间隔 = %.1f" % tree_to_first_gap)

	# 计算相邻两列（含线索子节点）的可见水平间隔（左列最右节点右沿 → 右列最左节点左沿）
	var min_gap := 1e18
	for k in range(col_members.size() - 1):
		var left_ids: Array = col_members[k]
		var right_ids: Array = col_members[k + 1]
		var left_right_edge := -1e18
		for id in left_ids:
			left_right_edge = maxf(left_right_edge, out[id].x + gv._layout._node_width_for_kind(KIND[id]) * 0.5)
		var right_left_edge := 1e18
		for id in right_ids:
			right_left_edge = minf(right_left_edge, out[id].x - gv._layout._node_width_for_kind(KIND[id]) * 0.5)
		var gap := right_left_edge - left_right_edge
		min_gap = minf(min_gap, gap)
		print("INFO 列%d→列%d 可见间隔 = %.1f" % [k, k + 1, gap])
	_chk(min_gap >= 150.0, "相邻两列无根链可见间隔 ≥ 150（=col_gap=160，旧版仅 160-半宽≈70）：实测 %.1f" % min_gap)
	_chk(absf(tree_to_first_gap - min_gap) < 5.0, "树→首列间隔(%.1f) 与 列间间隔(%.1f) 一致（同规则）" % [tree_to_first_gap, min_gap])

	print("RESULT " + ("ALL_PASS" if _ok else "HAS_FAIL"))
	quit()
