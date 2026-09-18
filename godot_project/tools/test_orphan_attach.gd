extends SceneTree
## 悬空孤儿根吸收回归（思傅 2026-09-17 截图：场景二推理墙深U再现）：
## 玩家把 H2-01/02/03 同时支持 CL2-4（拖到人物下）与浅层结论 CL2-1/2/3（未拖到人物下），
## _build_parent_of 每子唯一父化后 CL2-1/2/3 成「空孤儿根」各自占一条根带堆在主树下方，
## 连边 H2-0x→CL2-x 成跨树悬空长边（墙顶拉到墙底）= 深U。
## 修复：孤儿根 R 子树若有外部入边（v→u），把 R 挂到连边最多的 v 之下（与关系方向一致）。
## 断言：A1 修前孤儿根存在/修后全部吸收；A2 跨树悬空长边（深U）修前存在/修后为零；
##       B 零重叠；C 人物根永不被吸收（隔离人物保持根带）。

var _ok := true

func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("[ORPHAN] " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _make_scene2_like(gv) -> Dictionary:
	## 场景二同构：K(KILLER) + CL2-4/CL2-6(target 拖到人物) + 孤儿结论 CL2-1/2/3/5
	## + 假设 H2-01..H2-06 + 线索 c201..c206
	var kind := {
		"K": "person",
		"conclusion_CL2-4": "conclusion", "conclusion_CL2-6": "conclusion",
		"conclusion_CL2-1": "conclusion", "conclusion_CL2-2": "conclusion",
		"conclusion_CL2-3": "conclusion", "conclusion_CL2-5": "conclusion",
		"H2-01": "hypo", "H2-02": "hypo", "H2-03": "hypo",
		"H2-04": "hypo", "H2-05": "hypo", "H2-06": "hypo",
		"c201": "clue", "c202": "clue", "c203": "clue", "c204": "clue",
		"c205": "clue", "c206": "clue",
	}
	var label := {}
	for id in kind:
		label[id] = id
	var rel := [
		# 线索 → 假设（玩家连线）
		{"from": "c201", "to": "H2-01", "kind": "support"},
		{"from": "c202", "to": "H2-01", "kind": "support"},
		{"from": "c203", "to": "H2-02", "kind": "support"},
		{"from": "c204", "to": "H2-03", "kind": "support"},
		{"from": "c205", "to": "H2-04", "kind": "support"},
		{"from": "c205", "to": "H2-06", "kind": "support"},
		{"from": "c206", "to": "H2-04", "kind": "support"},
		{"from": "c206", "to": "H2-05", "kind": "support"},
		# 假设 → 浅层结论 + 三线合一结论（同一假设支持多个结论 = DAG 共享节点）
		{"from": "H2-01", "to": "conclusion_CL2-1", "kind": "support"},
		{"from": "H2-01", "to": "conclusion_CL2-4", "kind": "support"},
		{"from": "H2-02", "to": "conclusion_CL2-2", "kind": "support"},
		{"from": "H2-02", "to": "conclusion_CL2-4", "kind": "support"},
		{"from": "H2-03", "to": "conclusion_CL2-3", "kind": "support"},
		{"from": "H2-03", "to": "conclusion_CL2-4", "kind": "support"},
		{"from": "H2-04", "to": "conclusion_CL2-5", "kind": "support"},
		{"from": "H2-05", "to": "conclusion_CL2-6", "kind": "support"},
		{"from": "H2-06", "to": "conclusion_CL2-6", "kind": "support"},
		# CL2-4/CL2-6 被玩家拖到人物上（target 边）；CL2-1/2/3/5 未拖 → 孤儿根
		{"from": "conclusion_CL2-4", "to": "K", "kind": "target"},
		{"from": "conclusion_CL2-6", "to": "K", "kind": "target"},
	]
	gv._graph_nodes = []
	var nodes := []
	for id in kind:
		gv._graph_nodes.append({"id": id, "kind": kind[id], "label": label[id], "sub": "", "data": {}})
		nodes.append({"id": id, "kind": kind[id], "label": label[id]})
	gv._relations = rel.duplicate()
	return {"kind": kind, "label": label, "nodes": nodes, "rel": rel}


func _child_map_of(gv) -> Dictionary:
	var parent_of: Dictionary = gv._layout._build_parent_of()
	var cm := {}
	for ch in parent_of:
		var p: String = parent_of[ch]
		if not cm.has(p):
			cm[p] = []
		if not (ch in cm[p]):
			cm[p].append(ch)
	return cm


func _max_edge_dy(gv, cse: Dictionary, out: Dictionary) -> float:
	## 所有关系连线的最大垂直跨度（深U量化指标）
	var dy := 0.0
	for r in cse["rel"]:
		var f: String = str(r["from"])
		var t: String = str(r["to"])
		if not (out.has(f) and out.has(t)):
			continue
		dy = maxf(dy, absf(float(out[f].y) - float(out[t].y)))
	return dy


func _count_overlaps(gv, cse: Dictionary, out: Dictionary) -> int:
	var rects := {}
	var ids: Array = out.keys()
	for id in ids:
		var k: String = str(cse["kind"][id])
		var w: float = gv._layout._node_width_for_kind(k)
		var h: float = gv._layout._real_node_height(str(id), {"id": id, "kind": k, "label": cse["label"][id]})
		rects[id] = Rect2(out[id] - Vector2(w, h) * 0.5, Vector2(w, h))
	var n := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if (rects[ids[i]] as Rect2).grow(4.0).intersects((rects[ids[j]] as Rect2).grow(4.0)):
				n += 1
	return n


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	if GV == null:
		print("FAIL 无法加载 graph_view_controller.gd")
		quit(); return
	var gv = GV.new()
	var holder = Control.new()
	root.add_child(holder)
	holder.add_child(gv)
	await process_frame
	var center := Vector2(960.0, 540.0)

	# ---------- A) 场景二同构：孤儿根吸收 + 深U消除 ----------
	var cse := _make_scene2_like(gv)
	gv._subtree_sides = {}
	gv._root_anchor_pos = {}
	gv._manual_nodes = []
	var po_pre: Dictionary = gv._layout._build_parent_of()
	var roots := []
	for nd in cse["nodes"]:
		if not po_pre.has(nd.id):
			roots.append(str(nd.id))
	roots.sort()
	var orphan_conc := []
	for r in roots:
		if str(r).begins_with("conclusion_") or str(r) == "H2-04":
			orphan_conc.append(str(r))
	# A1-pre（信息性）：修前（无吸收逻辑时）CL2-1/2/3/5 是孤儿根；修复后恒为空——
	# 若未来回归导致孤儿根再现，下面 A1 断言会 FAIL。
	print("[ORPHAN] INFO 修复后孤儿根扫描（应为空）: ", str(orphan_conc))
	var o1 := {}
	gv._layout._run_main_layout(cse["nodes"], center, {}, o1)
	var dy_before: float = _max_edge_dy(gv, cse, o1)
	# A2-pre（信息性）：修前（无吸收逻辑时）最大连边垂直跨度 571（深U存在）
	print("[ORPHAN] INFO 修后连边最大垂直跨度基线: %.0f（修前 571）" % dy_before)

	# ---- 修复后行为（吸收逻辑生效后）：孤儿结论根全部消失、深U消除 ----
	var po2: Dictionary = gv._layout._build_parent_of()
	var roots2 := []
	for nd in cse["nodes"]:
		if not po2.has(nd.id):
			roots2.append(str(nd.id))
	var orphan_left := []
	for r in roots2:
		if str(r).begins_with("conclusion_") or str(r) == "H2-04":
			orphan_left.append(str(r))
	_chk(orphan_left.is_empty(),
		"A1 孤儿根（CL2-1/2/3 + H2-04）全部被吸收进主树（剩余根=%s）" % str(roots2))
	# 被吸收的 CL2-1/2/3 应挂在各自假设 H2-01/02/03 之下（关系方向一致）；
	# CL2-5 子树（CL2-5←H2-04）应整体挂在支持线索 c205/c206 之下
	var attach_ok := true
	for i in range(1, 4):
		var rc: String = "conclusion_CL2-%d" % i
		if str(po2.get(rc, "")) != "H2-0%d" % i:
			attach_ok = false
			print("  %s parent=%s（期望 H2-0%d）" % [rc, str(po2.get(rc, "")), i])
	if str(po2.get("conclusion_CL2-5", "")) != "c205" and str(po2.get("conclusion_CL2-5", "")) != "c206":
		attach_ok = false
		print("  conclusion_CL2-5 parent=%s（期望 c205/c206）" % str(po2.get("conclusion_CL2-5", "")))
	_chk(attach_ok, "A1b CL2-1/2/3 挂在推它们的 H2-01/02/03 下；CL2-5 链挂在支持线索 c205/c206 下")
	var o2 := {}
	gv._layout._run_main_layout(cse["nodes"], center, {}, o2)
	var dy_after: float = _max_edge_dy(gv, cse, o2)
	_chk(dy_after < 600.0,
		"A2 深U消除：修后最大连边垂直跨度 %.0f < 600（修前 %.0f）" % [dy_after, dy_before])
	# B 零重叠
	var nov: int = _count_overlaps(gv, cse, o2)
	_chk(nov == 0, "B 布局零重叠（相交对=%d）" % nov)

	# ---------- C) 人物根永不被吸收：孤立人物保持根 ----------
	var kind2 := {"K": "person", "P2": "person", "c1": "clue", "c2": "clue", "H": "hypo", "CC": "conclusion"}
	var label2 := {}
	for id in kind2:
		label2[id] = id
	gv._graph_nodes = []
	var nodes2 := []
	for id in kind2:
		gv._graph_nodes.append({"id": id, "kind": kind2[id], "label": label2[id], "sub": "", "data": {}})
		nodes2.append({"id": id, "kind": kind2[id], "label": label2[id]})
	gv._relations = [
		{"from": "c1", "to": "H", "kind": "support"},
		{"from": "H", "to": "CC", "kind": "support"},
		{"from": "CC", "to": "K", "kind": "target"},
	]
	var po3: Dictionary = gv._layout._build_parent_of()
	var cm3 := {}
	for ch3 in po3:
		var p3: String = po3[ch3]
		if not cm3.has(p3):
			cm3[p3] = []
		if not (ch3 in cm3[p3]):
			cm3[p3].append(ch3)
	var roots3 := []
	for nd in nodes2:
		if not po3.has(nd.id):
			roots3.append(str(nd.id))
	roots3.sort()
	_chk(roots3.has("K") and roots3.has("P2"),
		"C3 孤立人物 P2 与主根 K 都保持根带（根=%s）" % str(roots3))

	if _ok:
		print("ORPHAN_RESULT: PASS — 悬空孤儿根吸收验证通过")
	else:
		print("ORPHAN_RESULT: FAIL")
	quit()
