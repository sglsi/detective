extends SceneTree
## 真值回归 #2：思傅真实墙·建关系中间态（39 卡 / 4 分量 / NPC_HOP 被钉 @3915,-935）
## 输入取自 tools/fixtures/wall_real_hop2_input.json。
## 断言：① 钉位成立（NPC_HOP 恰在锚点）② 金标准逐点一致 ③ 真卡零重叠
##       ④ 组件矩形两两不相交 ⑤ 不变量合规 ⑥ 钉位不把包围盒炸开（面积/适配缩放上限，防回归）
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

## JSON 只有数组，游戏内是 Vector2 ⇒ fixture 装载必须转换（否则「锚点跟随」整段被跳过）
func _pins_vec(raw: Dictionary) -> Dictionary:
	var out := {}
	for k in raw.keys():
		var v: Variant = raw[k]
		if v is Array and (v as Array).size() >= 2:
			out[str(k)] = Vector2(float(v[0]), float(v[1]))
		elif v is Vector2:
			out[str(k)] = v
	return out

func _initialize() -> void:
	await process_frame
	var data: Dictionary = _load("res://tools/fixtures/wall_real_hop2_input.json")
	if data.is_empty():
		print("FAIL 无法读取 fixture"); print("WALL_REAL2_REPRO: FAIL"); quit(); return
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
	gv._root_anchor_pos = _pins_vec(data["pins"])
	var nodes: Array = data["nodes"]
	for nd in nodes:
		gv._node_kind[nd["id"]] = nd["kind"]; gv._node_data[nd["id"]] = {}
		var v = gv._cards.make_node({"id": nd["id"], "kind": nd["kind"], "label": "", "sub": "", "data": {}})
		canvas.add_child(v); gv._node_views[nd["id"]] = v
	await process_frame
	gv._relations = (data["relations"] as Array).duplicate()
	print("节点=%d 关系=%d manual=%d pins=%d" % [nodes.size(), gv._relations.size(), gv._manual_nodes.size(), gv._root_anchor_pos.size()])

	var out: Dictionary = gv._layout._compute_layout(nodes, {})
	gv._node_center = out.duplicate()
	gv._layout._apply_global_overlap_fix()
	if gv._layout._has_overlap():
		print("  [note] 去重叠后仍有重叠 → 走残留兜底")
		out = gv._layout._resolve_residual_overlaps(nodes, {})
		gv._node_center = out.duplicate()
	out = gv._node_center

	# ① 钉位成立
	var pin_target := Vector2(float(data["pins"]["NPC_HOP"][0]), float(data["pins"]["NPC_HOP"][1]))
	_chk(out.has("NPC_HOP") and out["NPC_HOP"].distance_to(pin_target) < 1.0,
		"钉位成立：NPC_HOP 恰在锚点 (%.0f,%.0f)（实=%.0f,%.0f）" %
		[pin_target.x, pin_target.y, out["NPC_HOP"].x, out["NPC_HOP"].y])

	# ② 金标准逐点
	var exp: Dictionary = data.get("expected_after", {})
	if exp.is_empty():
		print("  [warn] fixture 尚无 expected_after → 本次仅生成")
	else:
		var bad := []
		for k in exp.keys():
			if not out.has(k):
				bad.append("%s 缺失" % k); continue
			if absf(out[k].x - float(exp[k][0])) > 0.5 or absf(out[k].y - float(exp[k][1])) > 0.5:
				bad.append("%s(%.0f,%.0f≠%.0f,%.0f)" % [k, out[k].x, out[k].y, float(exp[k][0]), float(exp[k][1])])
		_chk(exp.size() == out.size() and bad.is_empty(),
			"金标准逐点一致（%d 节点）%s" % [out.size(), "" if bad.is_empty() else "；差异：" + str(bad.slice(0, 5))])

	# ③ 真卡零重叠
	var ids: Array = out.keys(); ids.sort()
	var ov := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if absf(out[ids[i]].x - out[ids[j]].x) < 260.0 and absf(out[ids[i]].y - out[ids[j]].y) < 400.0:
				ov.append("%s×%s" % [ids[i], ids[j]])
	_chk(ov.is_empty(), "真实卡片矩形零重叠%s" % ("" if ov.is_empty() else "；" + str(ov)))

	# ④⑤ 组件矩形不相交 + 不变量 + 全局指标
	var comp: Dictionary = gv._layout._relation_components()
	var groups := {}
	for k in out.keys():
		var cid: int = int(comp[str(k)]) if comp.has(str(k)) else -1
		if not groups.has(cid): groups[cid] = []
		groups[cid].append(str(k))
	var glo := Vector2(1e18, 1e18); var ghi := Vector2(-1e18, -1e18)
	var boxes := []
	for cid in groups.keys():
		var lo := Vector2(1e18, 1e18); var hi := Vector2(-1e18, -1e18)
		for sid in groups[cid]:
			var p: Vector2 = out[sid]
			lo = Vector2(minf(lo.x, p.x - 130.0), minf(lo.y, p.y - 200.0))
			hi = Vector2(maxf(hi.x, p.x + 130.0), maxf(hi.y, p.y + 200.0))
		boxes.append([cid, lo, hi])
		glo = Vector2(minf(glo.x, lo.x), minf(glo.y, lo.y)); ghi = Vector2(maxf(ghi.x, hi.x), maxf(ghi.y, hi.y))
	var inter := []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var A = boxes[i]; var B = boxes[j]
			if A[1].x < B[2].x and B[1].x < A[2].x and A[1].y < B[2].y and B[1].y < A[2].y:
				inter.append("分量%s×分量%s" % [A[0], B[0]])
	_chk(inter.is_empty(), "组件矩形两两不相交%s" % ("" if inter.is_empty() else "；" + str(inter)))
	var viol: Array = gv._layout.check_invariants()
	_chk(viol.is_empty(), "不变量合规%s" % ("" if viol.is_empty() else "；" + str(viol.slice(0, 4))))
	var W: float = ghi.x - glo.x
	var H: float = ghi.y - glo.y
	var fit: float = maxf(W / 1920.0, H / 1080.0)
	print("全局包围盒 %.0f×%.0f（面积 %.2fM，适配缩放 %.2f）" % [W, H, W * H / 1e6, fit])
	# ⑥ 钉位不得把包围盒炸开：修前为 5495×4415 / 24.26M / fit 4.09
	_chk(W * H / 1e6 <= 16.0, "钉位未炸开包围盒（面积 %.2fM ≤ 16.0M；修前 24.26M）" % (W * H / 1e6))
	_chk(fit <= 3.0, "适配缩放 %.2f ≤ 3.0（修前 4.09）" % fit)

	var flat := {}
	for k in ids:
		flat[str(k)] = [round(out[k].x * 100.0) / 100.0, round(out[k].y * 100.0) / 100.0]
	print("EXPECTED_AFTER=" + JSON.stringify(flat))
	print("WALL_REAL2_REPRO: " + ("PASS" if _ok else "FAIL"))
	quit()
