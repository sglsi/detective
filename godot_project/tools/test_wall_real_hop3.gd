extends SceneTree
## 真值回归 #3：思傅真实墙（39 卡 / 7 分量 + 2 张孤立卡）。
## 症状（导出 2026-09-22 22:33）：人物 NPC_DRE 无任何关系边，被孤悬在远离整墙处
##   （y=-2620，而整墙 y∈[-220,1300]），距最近卡片 2000px。
## 复现（本脚本）：场景A pre_center={} / 场景B pre_center=computed_before —— 两者坐标**完全相同**，
##   证明该位不是玩家摆放，而是布局自算（装箱前的带堆叠长柱），被装箱排除后残留 ⇒ 孤悬。
## 修后断言：
##   ① 金标准逐点一致 ② 真卡零重叠 ③ 组件矩形两两不相交 ④ 不变量合规
##   ⑤ **孤立卡不孤悬**（与最近其它卡片的间隙 ≤ 480 = 一个行距；修前 2000）
##   ⑥ **有硬锚点的孤立卡 = 玩家布设**（保持原位，不被装箱搬运）
## 重新生成金标准：取输出里的 EXPECTED_AFTER={...} 写回 fixture。
var _ok := true
func _chk(c: bool, m: String) -> void:
	if c: print("PASS " + m)
	else:
		_ok = false
		print("FAIL " + m)


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var t := f.get_as_text(); f.close()
	var d: Variant = JSON.parse_string(t)
	return d if d is Dictionary else {}


func _vec(d: Dictionary) -> Dictionary:
	## JSON 只有数组，游戏内是 Vector2 ⇒ 必须转换（否则「锚点跟随」整段被静默跳过）
	var out := {}
	for k in d.keys():
		var v: Variant = d[k]
		if v is Array and (v as Array).size() >= 2:
			out[str(k)] = Vector2(float(v[0]), float(v[1]))
		elif v is Vector2:
			out[str(k)] = v
	return out


var _data: Dictionary = {}
var _nodes: Array = []


func _make_gv(pre: Dictionary, pins: Dictionary) -> Dictionary:
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	var gv = GV.new()
	var holder := Control.new(); holder.size = Vector2(1920, 1080); root.add_child(holder); holder.add_child(gv)
	await process_frame
	var canvas := Control.new()
	canvas.size = Vector2(_data["canvas"][0], _data["canvas"][1])
	holder.add_child(canvas); gv._canvas = canvas
	gv._mode = GV.ViewMode.MODE_C
	gv._case_wide = bool(_data.get("case_wide", false))
	gv._focus_person = str(_data.get("focus_person", ""))
	gv._layout._relayout_on_edge = false
	gv._manual_nodes = (_data["manual"] as Array).duplicate()
	gv._root_anchor_pos = pins.duplicate()
	for nd in _nodes:
		gv._node_kind[nd["id"]] = nd["kind"]; gv._node_data[nd["id"]] = {}
		var v = gv._cards.make_node({"id": nd["id"], "kind": nd["kind"], "label": "", "sub": "", "data": {}})
		canvas.add_child(v); gv._node_views[nd["id"]] = v
	await process_frame
	gv._relations = (_data["relations"] as Array).duplicate()
	gv._node_center = pre.duplicate()
	var out: Dictionary = gv._layout._compute_layout(_nodes, pre)
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	if gv._layout._has_overlap():
		out = gv._layout._resolve_residual_overlaps(_nodes, pre)
		gv._node_center = out.duplicate()
	out = gv._node_center
	return {"gv": gv, "out": out}


## 孤立卡「孤悬度」= 与**其它任一卡片**（跨组，含另一张孤立卡）的最小 AABB 间隙
func _stray_gap(gv: Object, out: Dictionary, tag: String) -> float:
	var comp: Dictionary = gv._layout._relation_components()
	var strays: Array = []
	for k in out.keys():
		if not comp.has(str(k)):
			strays.append(str(k))
	var worst: float = 0.0
	for sid in strays:
		var a: Vector2 = out[sid]
		var best: float = 1e18
		for oid in out.keys():
			if str(oid) == sid: continue
			var b: Vector2 = out[oid]
			var dx: float = maxf(absf(a.x - b.x) - 260.0, 0.0)
			var dy: float = maxf(absf(a.y - b.y) - 400.0, 0.0)
			best = minf(best, sqrt(dx * dx + dy * dy))
		worst = maxf(worst, best)
		print("  [%s] 孤立卡 %s (%.0f,%.0f) 距最近卡片间隙 %.0f px" % [tag, sid, a.x, a.y, best])
	print("  [%s] 孤立卡 %d 张 %s；最大间隙 %.0f px" % [tag, strays.size(), str(strays), worst])
	return worst


func _boxes(gv: Object, out: Dictionary) -> Array:
	var comp: Dictionary = gv._layout._relation_components()
	var groups := {}
	for k in out.keys():
		var sid := str(k)
		if not comp.has(sid): continue
		var cid: int = int(comp[sid])
		if not groups.has(cid): groups[cid] = []
		groups[cid].append(sid)
	var boxes := []
	var glo := Vector2(1e18, 1e18); var ghi := Vector2(-1e18, -1e18)
	for cid in groups.keys():
		var lo := Vector2(1e18, 1e18); var hi := Vector2(-1e18, -1e18)
		for sid in groups[cid]:
			var p: Vector2 = out[sid]
			lo = Vector2(minf(lo.x, p.x - 130.0), minf(lo.y, p.y - 200.0))
			hi = Vector2(maxf(hi.x, p.x + 130.0), maxf(hi.y, p.y + 200.0))
		boxes.append([cid, lo, hi])
		glo = Vector2(minf(glo.x, lo.x), minf(glo.y, lo.y)); ghi = Vector2(maxf(ghi.x, hi.x), maxf(ghi.y, hi.y))
	return [boxes, glo, ghi]


func _initialize() -> void:
	await process_frame
	_data = _load("res://tools/fixtures/wall_real_hop3_input.json")
	if _data.is_empty():
		print("FAIL 无法读取 fixture"); print("WALL_REAL3_REPRO: FAIL"); quit(); return
	_nodes = _data["nodes"]
	var before: Dictionary = _vec(_data.get("computed_before", {}))

	# 场景 A：无拖前位（等价于「读档后首次布局 / 边变更触发的重排」）
	var ra: Dictionary = await _make_gv({}, {})
	var gva = ra["gv"]; var out_a: Dictionary = ra["out"]
	print("---- 场景A pre_center={} ----")
	var gap_a: float = _stray_gap(gva, out_a, "A")

	# 场景 B：拖前位 = 修前的导出坐标（病态输入）
	var rb: Dictionary = await _make_gv(before, {})
	var out_b: Dictionary = rb["out"]
	print("---- 场景B pre_center=computed_before（修前病态输入）----")
	var gap_b: float = _stray_gap(rb["gv"], out_b, "B")

	# ① 金标准（场景 A）
	var exp: Dictionary = _data.get("expected_after", {})
	if exp.is_empty():
		print("  [warn] fixture 尚无 expected_after → 本次仅生成")
	else:
		var bad := []
		for k in exp.keys():
			if not out_a.has(k):
				bad.append("%s 缺失" % k); continue
			if absf(out_a[k].x - float(exp[k][0])) > 0.5 or absf(out_a[k].y - float(exp[k][1])) > 0.5:
				bad.append("%s(%.0f,%.0f≠%.0f,%.0f)" % [k, out_a[k].x, out_a[k].y, float(exp[k][0]), float(exp[k][1])])
		_chk(exp.size() == out_a.size() and bad.is_empty(),
			"金标准逐点一致（%d 节点）%s" % [out_a.size(), "" if bad.is_empty() else "；差异：" + str(bad.slice(0, 5))])

	# ② 真卡零重叠（场景 A）
	var ids: Array = out_a.keys(); ids.sort()
	var ov := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if absf(out_a[ids[i]].x - out_a[ids[j]].x) < 260.0 and absf(out_a[ids[i]].y - out_a[ids[j]].y) < 400.0:
				ov.append("%s×%s" % [ids[i], ids[j]])
	_chk(ov.is_empty(), "真实卡片矩形零重叠%s" % ("" if ov.is_empty() else "；" + str(ov)))

	# ③ 组件矩形两两不相交 + 全局指标
	var bk: Array = _boxes(gva, out_a)
	var boxes: Array = bk[0]; var glo: Vector2 = bk[1]; var ghi: Vector2 = bk[2]
	var inter := []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var A = boxes[i]; var B = boxes[j]
			if A[1].x < B[2].x and B[1].x < A[2].x and A[1].y < B[2].y and B[1].y < A[2].y:
				inter.append("分量%s×分量%s" % [A[0], B[0]])
	_chk(inter.is_empty(), "组件矩形两两不相交%s" % ("" if inter.is_empty() else "；" + str(inter)))
	var W: float = ghi.x - glo.x
	var H: float = ghi.y - glo.y
	print("组件包围盒 %.0f×%.0f（面积 %.2fM，适配缩放 %.2f）" % [W, H, W * H / 1e6, maxf(W / 1920.0, H / 1080.0)])

	# ④ 不变量（场景 A）
	var viol: Array = gva._layout.check_invariants()
	_chk(viol.is_empty(), "不变量合规%s" % ("" if viol.is_empty() else "；" + str(viol.slice(0, 4))))

	# ⑤ 孤立卡不孤悬（核心回归闸门）：修前 = 2000px（NPC_DRE 被装箱排除后残留于带堆叠长柱）
	_chk(gap_a <= 480.0, "孤立卡不孤悬（场景A 最大间隙 %.0f ≤ 480 = 一个行距）" % gap_a)
	_chk(gap_b <= 480.0, "孤立卡不孤悬（场景B 病态输入下最大间隙 %.0f ≤ 480）" % gap_b)

	# ⑥ 有硬锚点的孤立卡 = 玩家布设：位置必须保持，且不被装箱搬走
	var anchor := Vector2(1600.0, -1600.0)
	var rc: Dictionary = await _make_gv(before, {"NPC_DRE": anchor})
	var out_c: Dictionary = rc["out"]
	_chk(out_c.has("NPC_DRE") and out_c["NPC_DRE"].distance_to(anchor) < 1.0,
		"孤立卡带硬锚点 → 保持玩家布设 (%.0f,%.0f)（实=%.0f,%.0f）" %
		[anchor.x, anchor.y, out_c["NPC_DRE"].x, out_c["NPC_DRE"].y])
	var ov_c := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if absf(out_c[ids[i]].x - out_c[ids[j]].x) < 260.0 and absf(out_c[ids[i]].y - out_c[ids[j]].y) < 400.0:
				ov_c.append("%s×%s" % [ids[i], ids[j]])
	_chk(ov_c.is_empty(), "钉位场景仍零重叠%s" % ("" if ov_c.is_empty() else "；" + str(ov_c)))

	var flat := {}
	for k in ids:
		flat[str(k)] = [round(out_a[k].x * 100.0) / 100.0, round(out_a[k].y * 100.0) / 100.0]
	print("EXPECTED_AFTER=" + JSON.stringify(flat))
	print("WALL_REAL3_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
