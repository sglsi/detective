extends SceneTree
## P0 · 布局 fixture 回归 runner：同一输入 → 断言「不变量合规 + 坐标与金标准逐点一致」。
## 用途：① 真值回归（用户那面墙导出 JSON 丢进 tools/fixtures/ 即成为永久回归）
##       ② P1 等价重构的证明（坐标必须逐点一致，任何偏差即 FAIL）。
## 运行：Godot --headless --path . --script res://tools/test_layout_fixtures.gd

const FIX_DIR := "res://tools/fixtures"
const TOL := 0.5   # 坐标容差（px）

var _ok := true
var _gv = null
var _canvas: Control = null


func _chk(cond: bool, msg: String) -> void:
	if cond:
		print("PASS " + msg)
	else:
		_ok = false
		print("FAIL " + msg)


func _initialize() -> void:
	await process_frame
	var GV = load("res://scripts/clue/graph_view_controller.gd")
	_gv = GV.new()
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	root.add_child(holder)
	holder.add_child(_gv)
	await process_frame
	_canvas = Control.new()
	_canvas.size = Vector2(1920, 1080)
	holder.add_child(_canvas)
	_gv._canvas = _canvas
	_gv._mode = GV.ViewMode.MODE_C
	_gv._layout._relayout_on_edge = false

	var dir := DirAccess.open(FIX_DIR)
	if dir == null:
		print("FAIL 无法打开 " + FIX_DIR)
		print("FIXTURES: FAIL")
		quit()
		return
	var files: Array = []
	for fn in dir.get_files():
		if str(fn).ends_with(".json"):
			files.append(str(fn))
	files.sort()
	_chk(not files.is_empty(), "fixture 非空（%d 个）" % files.size())
	for fn in files:
		await _run_fixture(fn)
	print("FIXTURES: " + ("PASS" if _ok else "FAIL"))
	quit()


func _run_fixture(fn: String) -> void:
	var path: String = "%s/%s" % [FIX_DIR, fn]
	var txt: String = FileAccess.get_file_as_string(path)
	var fx: Variant = JSON.parse_string(txt)
	if not (fx is Dictionary):
		_chk(false, "%s 解析失败" % fn)
		return
	var data: Dictionary = fx
	# 清场（含布局/控制器状态复位：`_balanced_layout` 会被「人物≥2结论」自动置 true 并**跨场景粘住**，
	# 不复位会导致「同一 fixture 因先后顺序不同而结果不同」——测试装置自身的状态泄漏，必须清）。
	for ch in _canvas.get_children():
		ch.queue_free()
	_gv._node_views = {}
	_gv._node_center = {}
	_gv._node_kind = {}
	_gv._node_data = {}
	_gv._graph_nodes = []
	_gv._relations = []
	_gv._root_anchor_pos = {}
	_gv._manual_nodes = []
	_gv._balanced_layout = false
	_gv._use_rank_layout = false
	_gv._state_store = {}
	_gv._folded_nodes = {}
	_gv._layout._row_step_scale = 1.0
	_gv._layout._relayout_on_edge = false
	await process_frame

	var nodes: Array = []
	for nd in data.get("nodes", []):
		var id: String = str(nd.get("id", ""))
		if id == "":
			continue
		var rec := {"id": id, "kind": str(nd.get("kind", "hypo")), "label": str(nd.get("label", "")), "sub": "", "data": {}}
		nodes.append(rec)
		_gv._node_kind[id] = rec.kind
		_gv._node_data[id] = {}
		var v = _gv._cards.make_node(rec)
		_canvas.add_child(v)
		_gv._node_views[id] = v
	await process_frame

	var rel: Array = []
	for r in data.get("relations", []):
		rel.append({"from": str(r.get("from", "")), "to": str(r.get("to", "")),
			"kind": str(r.get("kind", "support")), "color_key": str(r.get("color_key", "green"))})
	_gv._relations = rel
	var pins: Dictionary = {}
	var raw_pins: Variant = data.get("pins", {})
	if raw_pins is Dictionary:
		for pk in raw_pins:
			var pv: Variant = raw_pins[pk]
			if pv is Array and (pv as Array).size() >= 2:
				pins[str(pk)] = Vector2(float(pv[0]), float(pv[1]))
	_gv._root_anchor_pos = pins.duplicate()
	var man: Array = []
	for m in data.get("manual", []):
		man.append(str(m))
	_gv._manual_nodes = man

	# —— 生产路径复刻（与 _rebuild_graph 同序）——
	var out: Dictionary = _gv._layout._compute_layout(nodes, {})
	_gv._node_center = out.duplicate()
	_gv._layout._apply_global_overlap_fix()
	if _gv._layout._has_overlap():
		out = _gv._layout._resolve_residual_overlaps(nodes, {})
		_gv._node_center = out.duplicate()
	out = _gv._node_center

	# ① 不变量合规（与金标准一致或为空）
	var viol: Array = _gv._layout.check_invariants()
	var exp_viol: Array = data.get("expected_violations", [])
	_chk(viol.size() == exp_viol.size(),
		"[%s] 不变量违规数 %d == 金标准 %d %s" % [fn, viol.size(), exp_viol.size(), str(viol)])
	# ② 坐标逐点一致
	var exp: Variant = data.get("expected", {})
	if exp is Dictionary:
		var worst := 0.0
		var worst_id := ""
		for id in exp:
			var e: Array = exp[id]
			var got: Vector2 = out.get(str(id), Vector2(1e9, 1e9))
			var d: float = maxf(absf(got.x - float(e[0])), absf(got.y - float(e[1])))
			if d > worst:
				worst = d
				worst_id = str(id)
		_chk(worst <= TOL, "[%s] 坐标与金标准一致（最大偏差 %.2fpx @%s ≤ %.1f）"
			% [fn, worst, worst_id, TOL])
	_chk(out.size() == nodes.size(), "[%s] 布局覆盖全部节点（%d/%d）" % [fn, out.size(), nodes.size()])
