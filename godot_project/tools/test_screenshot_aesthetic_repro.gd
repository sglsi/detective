extends SceneTree
## 复现思傅 2026-09-21 截图（华生/佐生人物 + 2结论 + 2推断 + 3线索）：
## 真实拓扑（全 support；人物边为玩家实际画法 from=人物 to=结论）：
##   L1→H1, L2→H2, L3→H2, H1→C1, H2→C2, P→C1, P→C2
## 修复前：from=人物 边被「人物恒为根」强制剔除 → P/C1/C2 三个独立根竖摞同列
##        （截图「结论排在人物下面、推断线索在人物右边」的真病灶）。
## 修复后：_build_parent_of 对 from=人物 边反转挂接 → 单根 P 整洁树。
## 检验：① 单根=P ② 人物列只有人物 ③ 美学1 同层同侧共线（平衡布局镜像口径）
##       ④ 美学3 父居中于子。走生产全路径：_compute_layout + _apply_global_overlap_fix。

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

	var KIND := {
		"P": "person", "C1": "conclusion", "C2": "conclusion",
		"H1": "hypo", "H2": "hypo", "L1": "clue", "L2": "clue", "L3": "clue",
	}
	var LABEL := {
		"P": "佐生", "C1": "曾经帮华生带过东西", "C2": "不接受的任务只可能来自甲级任务",
		"H1": "不是亲弟弟的颜色", "H2": "失窃初步与肤色差别有关",
		"L1": "华生脸色黝黑", "L2": "华生手腕肤色分界", "L3": "华生面容憔悴",
	}
	# 人物边 = 玩家实际画法（从人物起笔 / 拖人物到结论上归属）：from=P、to=结论
	var REL := [
		{"from": "L1", "to": "H1", "kind": "support"},
		{"from": "L2", "to": "H2", "kind": "support"},
		{"from": "L3", "to": "H2", "kind": "support"},
		{"from": "H1", "to": "C1", "kind": "support"},
		{"from": "H2", "to": "C2", "kind": "support"},
		{"from": "P", "to": "C1", "kind": "support"},
		{"from": "P", "to": "C2", "kind": "support"},
	]
	var nodes := []
	for id in KIND:
		nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id]})

	# ===== 场景1：无钉位（纯自动排布——思傅指认的乱序来源）=====
	var gv = GV.new()
	var holder := Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	gv._graph_nodes = []
	for id in KIND:
		gv._graph_nodes.append({"id": id, "kind": KIND[id], "label": LABEL[id], "sub": "", "data": {}})
	gv._relations = REL
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	gv._node_center = {}
	gv._layout._relayout_on_edge = false

	var pf: Dictionary = gv._layout._build_parent_of()
	var roots0: Array = []
	for id in KIND:
		if not pf.has(id):
			roots0.append(id)
	roots0.sort()
	_chk(roots0 == ["P"], "[无钉位] 单根=P（修复前 P/C1/C2 三独立根）实际根=" + str(roots0))

	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	out = gv._node_center

	print("== positions (无钉位) ==")
	for id in KIND:
		print("  %s (%s): %.0f, %.0f" % [id, KIND[id], out[id].x, out[id].y])
	_run_checks(gv, out, KIND, "无钉位")

	# ===== 场景2：带历史钉位（C2 曾被拖动钉位；C2 现已有父 → 布局入口自动清钉归树）=====
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

	print("== positions (P钉位/C2历史钉位) ==")
	for id in KIND:
		print("  %s (%s): %.0f, %.0f" % [id, KIND[id], out2[id].x, out2[id].y])
	_run_checks(gv2, out2, KIND, "P钉位")

	# ===== 场景3（思傅 2026-09-21 截图2）：孤立人物 + 纯 结论→推断→线索 链（链与人物无任何关系边）=====
	# 人物冻结在链条整洁带（画布中心列 col0）上 → 旧去重叠把结论单独垂直推下 → 链条成阶梯，
	# 父居中于子/同层共线被破坏。修复后：去重叠按弱连通分量整块刚性平移（孤立单点让位）。
	var gv3 = GV.new()
	var holder3 := Control.new()
	root.add_child(holder3)
	holder3.add_child(gv3)
	await process_frame
	gv3._canvas = canvas
	gv3._mode = GV.ViewMode.MODE_C
	gv3._graph_nodes = [
		{"id": "P", "kind": "person", "label": "华生", "sub": "", "data": {}},
		{"id": "C", "kind": "conclusion", "label": "是名军医", "sub": "", "data": {}},
		{"id": "H", "kind": "hypo", "label": "从事医疗行业", "sub": "", "data": {}},
		{"id": "L", "kind": "clue", "label": "身上有消毒液气味", "sub": "", "data": {}},
	]
	gv3._relations = [
		# 生产口径：from=更深层(子)、to=更浅层(父)（_add_edge 新建时归一化后的存盘形态）
		{"from": "H", "to": "C", "kind": "support"},
		{"from": "L", "to": "H", "kind": "support"},
	]
	gv3._root_anchor_pos = {}
	gv3._manual_nodes = []
	# 人物冻结位：与链条整洁带（col0=center.x=960、带垂直居中 y≈540）同列相撞，且在链上方
	gv3._node_center = {
		"P": Vector2(960.0, 300.0),
		"C": Vector2(200.0, 800.0), "H": Vector2(500.0, 800.0), "L": Vector2(800.0, 800.0),
	}
	gv3._layout._relayout_on_edge = false
	var out3: Dictionary = gv3._layout._compute_layout(
		gv3._graph_nodes.duplicate(), {})
	gv3._node_center = out3.duplicate()
	gv3._layout._apply_global_overlap_fix()
	out3 = gv3._node_center

	print("== positions (孤立人物+纯链) ==")
	for id in ["P", "C", "H", "L"]:
		print("  %s: %.0f, %.0f" % [id, out3[id].x, out3[id].y])
	# ⑤ 链条三卡共线（同 y）——旧实现结论被单独推下即在此失败
	var collinear: bool = absf(out3["C"].y - out3["H"].y) < 1.0 \
		and absf(out3["H"].y - out3["L"].y) < 1.0
	_chk(collinear, "[纯链] ⑤ 结论/推断/线索 同 y 共线（父居中于子）C=%.0f H=%.0f L=%.0f"
		% [out3["C"].y, out3["H"].y, out3["L"].y])
	# ⑥ 列右向展开：C < H < L
	_chk(out3["C"].x < out3["H"].x and out3["H"].x < out3["L"].x,
		"[纯链] ⑥ 深度列右向 C=%.0f H=%.0f L=%.0f" % [out3["C"].x, out3["H"].x, out3["L"].x])
	# ⑦ 与孤立人物无 AABB 重叠
	var hit := []
	for id in ["C", "H", "L"]:
		var rp: Rect2 = gv3._layout._node_rect("P")
		var rq: Rect2 = gv3._layout._node_rect(id)
		if rp.intersects(rq):
			hit.append(id)
	_chk(hit.is_empty(), "[纯链] ⑦ 链与孤立人物无重叠" + ("" if hit.is_empty() else "；撞：" + ", ".join(hit)))

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
	# ① 单根=P
	var roots_sorted: Array = roots.duplicate()
	roots_sorted.sort()
	_chk(roots_sorted == ["P"], "[%s] ① 单根=P" % tag + ("；实际=" + str(roots_sorted) if roots_sorted != ["P"] else ""))
	# ② 人物列只有人物自己（坏方向的病灶特征：结论与人物同列竖摞）
	var same_col := []
	for id in KIND:
		if id == "P":
			continue
		if absf(out[id].x - out["P"].x) < 1.0:
			same_col.append(id)
	_chk(same_col.is_empty(), "[%s] ② 人物列只有人物" % tag + ("" if same_col.is_empty() else "；同列违例：" + ", ".join(same_col)))
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
	# ③ 美学1 同层同侧共线（平衡布局镜像：同深度同侧节点共 x 列；跨侧镜像允许异列）
	var col_err := []
	var by_key := {}
	for id in depth_of:
		if id == "P":
			continue
		var side: int = 1 if out[id].x >= out["P"].x else -1
		var key := "%d|%d" % [depth_of[id], side]
		if not by_key.has(key):
			by_key[key] = {}
		by_key[key][out[id].x] = true
	for key in by_key:
		if by_key[key].size() > 1:
			col_err.append("%s xs=%s" % [key, str(by_key[key].keys())])
	_chk(col_err.is_empty(), "[%s] ③ 美学1 同层同侧共线" % tag + ("" if col_err.is_empty() else "；违例：" + ", ".join(col_err)))
	# ④ 美学3 父居中于子（父 y = 直接子群 y 中点）
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
	_chk(cen_err.is_empty(), "[%s] ④ 美学3 父居中于子" % tag + ("" if cen_err.is_empty() else "；违例：" + ", ".join(cen_err)))
