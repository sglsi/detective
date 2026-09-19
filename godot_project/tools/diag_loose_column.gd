extends SceneTree
## 诊断：无根链为何仍排为一竖列
## 复刻真实场景的无根链形状，打印门控判定与 X 跨度，定位是否 tidy-Y 把线性链压成 0 高度导致门控不触发。

func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载")
		quit()
		return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var center := Vector2(960.0, 540.0)

	# ---------- 场景1：6 条线性无根链 conclusion->hypo->clue（最常见真实形状）----------
	_diag("场景1: 6条线性无根链(C->H->CL)", _linear_forest(6), center, gv)

	# ---------- 场景2：6 条分支无根链 C->{Ha,Hb}->{CLa1,2,CLb1,2} ----------
	_diag("场景2: 6条分支无根链(2推断4线索)", _branch_forest(6), center, gv)

	# ---------- 场景3：12 条线性无根链 ----------
	_diag("场景3: 12条线性无根链", _linear_forest(12), center, gv)

	quit()


func _linear_forest(n: int) -> Dictionary:
	var KIND := {}
	var LABEL := {}
	var REL := []
	for i in n:
		var c := "LC%d" % i
		KIND[c] = "conclusion"
		LABEL[c] = "无根结论%d：基础推断落点" % i
		var h := "LH%d" % i
		KIND[h] = "hypo"
		LABEL[h] = "无根推断%d：单层推断" % i
		REL.append({"from": h, "to": c, "kind": "support"})
		var cl := "LCL%d" % i
		KIND[cl] = "clue"
		LABEL[cl] = "无根线索%d：单条支撑线索" % i
		REL.append({"from": cl, "to": h, "kind": "support"})
	return {"KIND": KIND, "LABEL": LABEL, "REL": REL}


func _branch_forest(n: int) -> Dictionary:
	var KIND := {}
	var LABEL := {}
	var REL := []
	for i in n:
		var c := "BC%d" % i
		KIND[c] = "conclusion"
		LABEL[c] = "无根结论%d：分支推断落点" % i
		for hb in ["a", "b"]:
			var h := "BH%d_%s" % [i, hb]
			KIND[h] = "hypo"
			LABEL[h] = "无根推断%d_%s" % [i, hb]
			REL.append({"from": h, "to": c, "kind": "support"})
			for k in [1, 2]:
				var cl := "BCL%d_%s%d" % [i, hb, k]
				KIND[cl] = "clue"
				LABEL[cl] = "无根线索%d_%s%d" % [i, hb, k]
				REL.append({"from": cl, "to": h, "kind": "support"})
	return {"KIND": KIND, "LABEL": LABEL, "REL": REL}


func _diag(name: String, data: Dictionary, center: Vector2, gv) -> void:
	var nodes := []
	for id in data["KIND"]:
		nodes.append({"id": id, "kind": data["KIND"][id], "label": data["LABEL"][id]})
	gv._graph_nodes = []
	for id in data["KIND"]:
		gv._graph_nodes.append({"id": id, "kind": data["KIND"][id], "label": data["LABEL"][id], "sub": "", "data": {}})
	gv._relations = data["REL"].duplicate()
	var out := {}
	gv._layout._logic_tree_layout(nodes, center, {}, out)

	# 复刻门控逻辑测算
	var parent_of = gv._layout._build_parent_of()
	var has_parent := {}
	for ch in parent_of:
		has_parent[ch] = true
	var roots := []
	for nd in nodes:
		if not has_parent.has(nd.id):
			roots.append(nd.id)
	var loose := []
	for r in roots:
		var rk: String = gv._fold._kind_of(r)
		if rk != "person" and rk != "event":
			loose.append(r)

	# 计算 root_range（复刻布局内 tidy-Y 得到的 y 跨度）
	var child_map := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not child_map.has(p): child_map[p] = []
		if not (ch in child_map[p]): child_map[p].append(ch)
	var est_h := {}
	for nd in nodes:
		est_h[nd.id] = gv._layout._real_node_height(nd.id, nd)
	var max_h: float = 140.0
	for nd in nodes:
		max_h = maxf(max_h, est_h[nd.id])
	var ROW_STEP: float = max_h + 80.0
	var root_range := {}
	for r in roots:
		var ty: Dictionary = gv._layout._tidy_y(str(r), child_map, ROW_STEP)
		var gmin: float = 1e18
		var gmax: float = -1e18
		for nid in ty.keys():
			gmin = minf(gmin, ty[nid])
			gmax = maxf(gmax, ty[nid])
		root_range[r] = [gmin, gmax]

	# 复刻 loose_total / wrap_h
	var loose_total: float = 0.0
	for r in loose:
		var _chh: float = maxf(root_range[r][1] - root_range[r][0], 412.0)
		loose_total += _chh + 40.0
	var wrap_h: float = 1200.0

	# X 跨度
	var min_x := 1e18
	var max_x := -1e18
	for id in out:
		min_x = minf(min_x, out[id].x)
		max_x = maxf(max_x, out[id].x)

	print("==== %s ====" % name)
	print("  无根链根数 = %d" % loose.size())
	print("  tidy-Y 各链 y 跨度(高度):")
	for r in loose:
		print("    %s : %.0f" % [r, root_range[r][1] - root_range[r][0]])
	print("  loose_total(门控用高度预算) = %.0f   wrap_h = %.0f" % [loose_total, wrap_h])
	print("  门控触发(loose_total>wrap_h) = %s" % str(loose_total > wrap_h))
	print("  最终 X 跨度 = %.0f (单竖列应≈单链宽~260)" % (max_x - min_x))
	print("")
