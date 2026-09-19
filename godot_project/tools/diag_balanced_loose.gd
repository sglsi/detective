extends SceneTree
## 诊断：平衡布局（_balanced_tree_layout）下无根链是否从主列竖列分流到树右侧并按 >6 叶分列
## 场景：人物 P1（2 条结论链：结论→推断→线索）+ 8 条无根链（结论→线索，无父）
## 预期：主列叶子(2 线索+8 无根叶=10 >6) 触发 do_relocate → 无根链搬到树右侧、按 >6 叶分列、与树留清晰间隔

var _ok := true
func _chk(cond: bool, msg: String) -> void:
	if cond: print("PASS " + msg)
	else: _ok = false; print("FAIL " + msg)

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

	# 1. 人物居中于 center.x
	_chk(absf(out["P1"].x - center.x) < 60.0, "人物 P1 居中于 center.x (x=%.0f)" % out["P1"].x)
	# 2. 无根链根搬到树右侧（x 明显 > center.x）
	var loose_roots := []
	for i in 8:
		loose_roots.append("LC%d" % i)
	var min_loose_x := 1e18
	for id in loose_roots:
		min_loose_x = minf(min_loose_x, out[id].x)
	_chk(min_loose_x > center.x + 150.0, "无根链整体搬到树右侧（最左无根根 x=%.0f > center+150，非主列竖列）" % min_loose_x)
	# 2b. 无根链按 >6 叶分列 → 结论根应占 ≥2 个 x 列
	var lcols := {}
	for id in loose_roots:
		lcols[out[id].x] = true
	_chk(lcols.size() >= 2, "无根链 8 叶 >6 → 分 ≥2 列（占 %d 个 x 列）" % lcols.size())
	# 2c. 与整洁树留清晰间隔：树最右沿（人物各节点 x 最大值）到无根链最左 > 120
	var tree_right := -1e18
	for id in ["P1", "C0", "C1", "H0", "H1", "CL0", "CL1"]:
		tree_right = maxf(tree_right, out[id].x)
	_chk(min_loose_x > tree_right + 120.0, "无根链与整洁树留清晰间隔（min_x=%.0f > 树最右沿 %.0f + 120）" % [min_loose_x, tree_right])
	# 3. 无根链内部仍右向流（结论.x < 线索.x）
	var flow := true
	for i in 8:
		if out["LCL%d" % i].x <= out["LC%d" % i].x:
			flow = false
	_chk(flow, "无根链内部右向流（结论.x < 线索.x）")
	# 4. 零重叠
	_overlap_check(gv, out, KIND, LABEL)
	# 5. 主列（center.x ± 120）上不应再堆叠无根链根（验证确实被分流）
	var on_main_col := 0
	for i in 8:
		if absf(out["LC%d" % i].x - center.x) < 120.0:
			on_main_col += 1
	_chk(on_main_col == 0, "无根链根未留在主列竖列（留在主列数=%d，应为 0）" % on_main_col)

	print("RESULT " + ("ALL_PASS" if _ok else "HAS_FAIL"))
	quit()
