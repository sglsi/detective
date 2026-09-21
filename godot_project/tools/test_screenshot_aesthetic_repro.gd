extends SceneTree
## 复现思傅 2026-09-21 截图（佐生人物 + 2结论 + 2推断 + 3线索）：
## 拓扑（全 support，from=子 to=父）：
##   L1→H1, L2→H2, L3→H2, H1→C1, H2→C1, H2→C2（多父 DAG）, P→H1（人物放射边）
## 检验：美学1 同层共线（同树深同 x 列）、美学3 父居中于子（父 y = 子群 y 中点）。
## 走生产全路径：_compute_layout + _apply_global_overlap_fix。

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("PASS " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit()
		return
	var canvas := Control.new()
	canvas.size = Vector2(1920.0, 1080.0)

	var gv = GV.new()
	var holder := Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C

	var KIND := {
		"P": "person", "C1": "conclusion", "C2": "conclusion",
		"H1": "hypo", "H2": "hypo", "L1": "clue", "L2": "clue", "L3": "clue",
	}
	var LABEL := {
		"P": "佐生", "C1": "曾经帮华生带过东西", "C2": "不接受的任务只可能来自甲级任务",
		"H1": "不是亲弟弟的颜色", "H2": "失窃初步与肤色差别有关",
		"L1": "华生脸色黝黑", "L2": "华生手腕肤色分界", "L3": "华生面容憔悴",
	}
	var REL := [
		{"from": "L1", "to": "H1", "kind": "support"},
		{"from": "L2", "to": "H2", "kind": "support"},
		{"from": "L3", "to": "H2", "kind": "support"},
		{"from": "H1", "to": "C1", "kind": "support"},
		{"from": "H2", "to": "C1", "kind": "support"},
		{"from": "H2", "to": "C2", "kind": "support"},
		{"from": "P", "to": "H1", "kind": "support"},
	]
	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL
	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	gv._node_center = {}
	gv._layout._relayout_on_edge = false

	# ---- 最终树（调试可见）----
	var pf: Dictionary = gv._layout._build_parent_of()
	print("== final parent_of ==")
	for ch in pf:
		print("  %s -> %s" % [ch, pf[ch]])

	# ---- 生产路径：_compute_layout + 全局去重叠 ----
	# 场景1：无钉位（纯整洁树）
	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	out = gv._node_center

	print("== positions (无钉位) ==")
	for id in KIND:
		print("  %s (%s): %.0f, %.0f" % [id, KIND[id], out[id].x, out[id].y])
	_run_checks(gv, out, KIND, "无钉位")

	# ---- 场景2：模拟玩家拖过的墙（P 钉上方、C2 钉下方，持久化钉位）----
	var gv2 = GV.new()
	var holder2 := Control.new()
	root.add_child(holder2)
	holder2.add_child(gv2)
	await process_frame
	gv2._canvas = canvas
	gv2._mode = GV.ViewMode.MODE_C
	gv2._graph_nodes = []
	for id in KIND:
		gv2._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv2._relations = REL
	gv2._root_anchor_pos = {"P": Vector2(760.0, 140.0), "C2": Vector2(760.0, 950.0)}
	gv2._manual_nodes = ["P", "C2"]
	# stale 历史位（读档恢复的旧卡位）
	var stale := {}
	var ids2: Array = KIND.keys()
	ids2.sort()
	for k in ids2.size():
		stale[ids2[k]] = Vector2(700.0 + (k % 4) * 180.0, 160.0 + k * 90.0)
	gv2._node_center = stale
	gv2._layout._relayout_on_edge = false
	var out2: Dictionary = gv2._layout._compute_layout(nodes, {})
	gv2._node_center = out2.duplicate()
	gv2._layout._apply_global_overlap_fix()
	out2 = gv2._node_center

	print("== positions (P/C2 钉位) ==")
	for id in KIND:
		print("  %s (%s): %.0f, %.0f" % [id, KIND[id], out2[id].x, out2[id].y])
	_run_checks(gv2, out2, KIND, "P/C2钉位")

	if _ok:
		print("AESTHETIC_REPRO: PASS")
	else:
		print("AESTHETIC_REPRO: FAIL")
	quit()


func _run_checks(gv, out: Dictionary, KIND: Dictionary, tag: String) -> void:
	var pf: Dictionary = gv._layout._build_parent_of()
	var child_map := {}
	for ch in pf:
		if not child_map.has(pf[ch]):
			child_map[pf[ch]] = []
		child_map[pf[ch]].append(str(ch))
	var roots: Array = []
	for id in KIND:
		if not pf.has(id):
			roots.append(id)
	var depth_of := {}
	var q: Array = []
	for r in roots:
		depth_of[r] = 0
		q.append(r)
	while q.size() > 0:
		var u: String = q.pop_front()
		for c in child_map.get(u, []):
			if depth_of.has(c):
				continue
			depth_of[c] = depth_of[u] + 1
			q.append(c)
	# 美学1：同树深同 x 列
	var col_err := []
	var by_depth := {}
	for id in depth_of:
		var d: int = depth_of[id]
		if not by_depth.has(d):
			by_depth[d] = {}
		by_depth[d][out[id].x] = true
	for d in by_depth:
		if by_depth[d].size() > 1:
			col_err.append("depth%d xs=%s" % [d, str(by_depth[d].keys())])
	_chk(col_err.is_empty(), "[%s] 美学1 同层共线" % tag + ("" if col_err.is_empty() else "；违例：" + ", ".join(col_err)))
	# 美学3：父居中于子
	var cen_err := []
	for p in child_map:
		var chs: Array = child_map[p]
		if chs.is_empty():
			continue
		var lo: float = 1e18
		var hi: float = -1e18
		for c in chs:
			lo = minf(lo, out[c].y)
			hi = maxf(hi, out[c].y)
		var mid: float = (lo + hi) * 0.5
		if absf(out[p].y - mid) > 1.0:
			cen_err.append("%s(y=%.0f 子中点=%.0f)" % [p, out[p].y, mid])
	_chk(cen_err.is_empty(), "[%s] 美学3 父居中于子" % tag + ("" if cen_err.is_empty() else "；违例：" + ", ".join(cen_err)))
