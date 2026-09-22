extends SceneTree
## 真值回归：思傅真实墙（华生案 · 38 卡 · 6 弱连通分量，2026-09-22 Ctrl+Shift+D 导出）
## 输入取自 tools/fixtures/wall_real_hop_input.json（只存输入）。
## 断言：① 与 fixture 的 expected_after 逐点一致（R3 装箱后的金标准，容差 0.5px）
##       ② 真实卡片矩形零重叠 ③ 组件矩形两两不相交 ④ 不变量合规
## 打印：组件包围盒、全局包围盒面积/填充率、与导出时（修复前）坐标的差异节点数
## 重新生成金标准：运行后在输出里取 EXPECTED_AFTER={...} 整行写回 fixture 的 expected_after 字段。
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var txt := f.get_as_text()
	f.close()
	var d: Variant = JSON.parse_string(txt)
	return d if d is Dictionary else {}

func _initialize() -> void:
	await process_frame
	var data: Dictionary = _load_json("res://tools/fixtures/wall_real_hop_input.json")
	if data.is_empty():
		print("FAIL 无法读取 fixture")
		print("WALL_REAL_REPRO: FAIL")
		quit()
		return
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new()
	canvas.size = Vector2(data["canvas"][0], data["canvas"][1])
	holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	gv._case_wide = bool(data.get("case_wide", false))
	gv._focus_person = str(data.get("focus_person", ""))
	gv._layout._relayout_on_edge = false
	gv._manual_nodes = (data["manual"] as Array).duplicate()
	gv._root_anchor_pos = (data["pins"] as Dictionary).duplicate()
	var nodes: Array = data["nodes"]
	for nd in nodes:
		gv._node_kind[nd["id"]] = nd["kind"]
		gv._node_data[nd["id"]] = {}
		var v = gv._cards.make_node({"id": nd["id"], "kind": nd["kind"], "label": "", "sub": "", "data": {}})
		canvas.add_child(v)
		gv._node_views[nd["id"]] = v
	await process_frame
	gv._relations = (data["relations"] as Array).duplicate()
	print("节点=%d 关系=%d manual=%d" % [nodes.size(), gv._relations.size(), gv._manual_nodes.size()])

	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	if gv._layout._has_overlap():
		print("  [note] _apply_global_overlap_fix 后仍有重叠 → 走残留兜底")
		out = gv._layout._resolve_residual_overlaps(nodes, {})
		gv._node_center = out.duplicate()
	out = gv._node_center

	# ---------- ① 与 R3 之后的金标准逐点比对 ----------
	var exp: Dictionary = data.get("expected_after", {})
	if exp.is_empty():
		print("  [warn] fixture 尚无 expected_after → 本次仅生成，不做比对")
	else:
		var bad := []
		for k in exp.keys():
			if not out.has(k):
				bad.append("%s 缺失" % k)
				continue
			if absf(out[k].x - float(exp[k][0])) > 0.5 or absf(out[k].y - float(exp[k][1])) > 0.5:
				bad.append("%s(%.0f,%.0f≠%.0f,%.0f)" % [k, out[k].x, out[k].y, float(exp[k][0]), float(exp[k][1])])
		_chk(exp.size() == out.size() and bad.is_empty(),
			"金标准逐点一致（%d 节点）%s" % [out.size(), "" if bad.is_empty() else "；差异：" + str(bad.slice(0, 5))])

	# ---------- 参考：与修复前导出坐标的差异（R3 装箱后按设计改变） ----------
	var before: Dictionary = data.get("computed_before", {})
	var changed := 0
	for k in before.keys():
		if out.has(k) and (absf(out[k].x - float(before[k][0])) > 0.5 or absf(out[k].y - float(before[k][1])) > 0.5):
			changed += 1
	print("相对修复前导出的移动节点数 = %d / %d" % [changed, before.size()])

	# ---------- ② 真实卡片矩形重叠 ----------
	var ids: Array = out.keys()
	ids.sort()
	var ov: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Vector2 = out[ids[i]]; var b: Vector2 = out[ids[j]]
			if absf(a.x - b.x) < 260.0 and absf(a.y - b.y) < 400.0:
				ov.append("%s×%s" % [ids[i], ids[j]])
	_chk(ov.is_empty(), "真实卡片矩形零重叠%s" % ("" if ov.is_empty() else "；违例：" + str(ov)))
	if not ov.is_empty():
		for o in ov: print("   " + str(o))

	# ---------- ③ 组件矩形互不相交 ----------
	var comp_map: Dictionary = gv._layout._relation_components()
	var groups := {}
	for k in out.keys():
		var cid: int = int(comp_map.get(str(k), -1))
		if not groups.has(cid): groups[cid] = []
		groups[cid].append(str(k))
	var box_of := {}
	for cid in groups.keys():
		var lo := Vector2(1e18, 1e18); var hi := Vector2(-1e18, -1e18)
		for sid in groups[cid]:
			var p: Vector2 = out[sid]
			lo = Vector2(minf(lo.x, p.x - 130.0), minf(lo.y, p.y - 200.0))
			hi = Vector2(maxf(hi.x, p.x + 130.0), maxf(hi.y, p.y + 200.0))
		box_of[cid] = [lo, hi]
	print("组件包围盒（%d 个）：" % groups.size())
	var cks: Array = box_of.keys(); cks.sort()
	for cid in cks:
		var lo2: Vector2 = box_of[cid][0]; var hi2: Vector2 = box_of[cid][1]
		print("  成员=%2d  %.0f×%.0f @(%.0f,%.0f)" % [groups[cid].size(), hi2.x - lo2.x, hi2.y - lo2.y, lo2.x, lo2.y])
	var bad2 := []
	for i in cks.size():
		for j in range(i + 1, cks.size()):
			var A: Array = box_of[cks[i]]; var B: Array = box_of[cks[j]]
			if A[0].x < B[1].x and B[0].x < A[1].x and A[0].y < B[1].y and B[0].y < A[1].y:
				bad2.append("分量%s×分量%s" % [cks[i], cks[j]])
	_chk(bad2.is_empty(), "组件矩形两两不相交（装箱无交错）%s" % ("" if bad2.is_empty() else "；违例：" + str(bad2)))

	# ---------- ④ 全局包围盒 / 填充率 ----------
	var glo := Vector2(1e18, 1e18); var ghi := Vector2(-1e18, -1e18)
	for k in out.keys():
		var p2: Vector2 = out[k]
		glo = Vector2(minf(glo.x, p2.x - 130.0), minf(glo.y, p2.y - 200.0))
		ghi = Vector2(maxf(ghi.x, p2.x + 130.0), maxf(ghi.y, p2.y + 200.0))
	var area: float = (ghi.x - glo.x) * (ghi.y - glo.y)
	var used: float = float(out.size()) * 260.0 * 400.0
	print("全局包围盒 %.0f×%.0f（面积 %.2fM，卡片填充率 %.1f%%）" %
		[ghi.x - glo.x, ghi.y - glo.y, area / 1e6, used / area * 100.0])

	# ---------- ⑤ 不变量 ----------
	var viol: Array = gv._layout.check_invariants()
	_chk(viol.is_empty(), "不变量合规%s" % ("" if viol.is_empty() else "；" + str(viol.slice(0, 4))))

	# ---------- 输出新金标准（供写回 fixture） ----------
	var flat := {}
	for k in ids:
		flat[str(k)] = [round(out[k].x * 100.0) / 100.0, round(out[k].y * 100.0) / 100.0]
	print("EXPECTED_AFTER=" + JSON.stringify(flat))
	print("WALL_REAL_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
