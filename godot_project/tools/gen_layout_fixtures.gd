extends SceneTree
## P0 · fixture 生成器：把「当前布局行为」固化为金标准 fixture（tools/fixtures/*.json）。
## 每个 fixture = 输入(节点/边/钉位) + 期望坐标(expected，即此刻的真实输出) + 违规清单快照。
## 用途：① 真值回归（同输入→同坐标/同不变量）② P1 等价重构的证明（坐标须逐点一致）。
## 运行：Godot --headless --path . --script res://tools/gen_layout_fixtures.gd

const OUT_DIR := "res://tools/fixtures"

var _gv = null
var _canvas: Control = null

func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
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

	var scenarios: Array = _scenarios()
	for sc in scenarios:
		await _emit(sc)
	print("GEN_FIXTURES_DONE count=%d" % scenarios.size())
	quit()


func _scenarios() -> Array:
	# 每条：{name, nodes:[[id,kind,label]], rel:[[from,to,kind]], pins:{id:[x,y]}, manual:[id]}
	return [
		{
			"name": "chain3_pure",
			"nodes": [["C", "conclusion", "曾帮华生带过东西"], ["H", "hypo", "不是亲弟弟的颜色"], ["L", "clue", "华生脸色黝黑"]],
			"rel": [["H", "C", "support"], ["L", "H", "support"]],
			"pins": {}, "manual": [],
		},
		{
			"name": "chain_person_isolated",
			"nodes": [["P", "person", "佐生"], ["C", "conclusion", "是名军医"], ["H", "hypo", "从事医疗行业"], ["L", "clue", "身上有消毒液气味"]],
			"rel": [["H", "C", "support"], ["L", "H", "support"]],
			"pins": {}, "manual": [],
		},
		{
			"name": "wall9_person2concl",
			"nodes": [
				["P", "person", "佐生"], ["C1", "conclusion", "曾经帮华生带过东西"], ["C2", "conclusion", "不接受的任务只可能来自甲级任务"],
				["H1", "hypo", "不是亲弟弟的颜色"], ["H2", "hypo", "失窃初步与肤色差别有关"],
				["L1", "clue", "华生脸色黝黑"], ["L2", "clue", "华生手腕肤色分界"], ["L3", "clue", "华生面容憔悴"],
			],
			"rel": [["L1", "H1", "support"], ["L2", "H2", "support"], ["L3", "H2", "support"],
				["H1", "C1", "support"], ["H2", "C2", "support"], ["P", "C1", "support"], ["P", "C2", "support"]],
			"pins": {}, "manual": [],
		},
		{
			"name": "wall16_traced",
			"nodes": [
				["t1", "conclusion", "链A结论"], ["b1", "hypo", "链A推断"], ["g2", "clue", "链A线索甲"], ["g1", "clue", "链A线索乙"],
				["t2", "conclusion", "链B结论"], ["t3", "hypo", "链B推断甲"], ["b3", "hypo", "链B推断乙"],
				["b2", "clue", "链B线索甲"], ["g4", "clue", "链B线索乙"], ["g3", "clue", "链B线索丙"],
				["t4", "conclusion", "链C结论"], ["t5", "hypo", "链C推断"], ["b4", "hypo", "链C推断甲"], ["b5", "hypo", "链C推断乙"],
				["g5", "clue", "链C线索甲"], ["g6", "clue", "链C线索乙"],
			],
			"rel": [
				["b1", "t1", "support"], ["g2", "b1", "support"], ["g1", "g2", "support"],
				["t3", "t2", "support"], ["b3", "t2", "support"], ["b2", "t3", "support"],
				["g4", "b3", "support"], ["g3", "b2", "support"],
				["t5", "t4", "support"], ["b4", "t5", "support"], ["b5", "t5", "support"],
				["g5", "b4", "support"], ["g6", "b5", "support"],
			],
			"pins": {}, "manual": [],
		},
		{
			"name": "multiband3_grid",
			"nodes": [
				["A1", "conclusion", "链一结论"], ["H1", "hypo", "链一推断"], ["L1", "clue", "链一线索"],
				["A2", "conclusion", "链二结论"], ["H2", "hypo", "链二推断甲"], ["K2", "clue", "链二线索乙"],
				["A3", "conclusion", "链三结论"], ["H3", "hypo", "链三推断"], ["J3", "clue", "链三线索"], ["M3", "clue", "链三线索二"],
			],
			"rel": [["H1", "A1", "support"], ["L1", "H1", "support"],
				["H2", "A2", "support"], ["K2", "A2", "support"],
				["H3", "A3", "support"], ["J3", "A3", "support"], ["M3", "A3", "support"]],
			"pins": {}, "manual": [],
		},
		{
			"name": "wall9_pinned_conflict",
			"nodes": [
				["C", "conclusion", "结论"], ["H", "hypo", "推断"], ["L", "clue", "线索"],
				["X", "hypo", "玩家另拖的孤立推断"],
			],
			"rel": [["H", "C", "support"], ["L", "H", "support"], ["X", "L", "relate"]],
			"pins": {"X": [1340.0, 300.0]}, "manual": ["X"],
		},
	]


func _emit(sc: Dictionary) -> void:
	# 清场（含状态复位：`_balanced_layout` 被「人物≥2结论」自动置 true 后会跨场景粘住，必须复位，
	# 否则 fixture 结果取决于生成顺序 —— 测试装置自身的状态泄漏）
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
	for s in sc["nodes"]:
		var id: String = str(s[0])
		var nd := {"id": id, "kind": str(s[1]), "label": str(s[2]), "sub": "", "data": {}}
		nodes.append(nd)
		_gv._node_kind[id] = nd.kind
		_gv._node_data[id] = {}
		var v = _gv._cards.make_node(nd)
		_canvas.add_child(v)
		_gv._node_views[id] = v
	await process_frame

	var rel: Array = []
	for r in sc["rel"]:
		rel.append({"from": str(r[0]), "to": str(r[1]), "kind": str(r[2]), "color_key": "green"})
	_gv._relations = rel
	var pins: Dictionary = {}
	for pk in sc["pins"]:
		var pv: Array = sc["pins"][pk]
		pins[str(pk)] = Vector2(float(pv[0]), float(pv[1]))
	_gv._root_anchor_pos = pins.duplicate()
	_gv._manual_nodes = (sc["manual"] as Array).duplicate()

	# —— 生产路径复刻（与 _rebuild_graph 同序）：布局 → 去重叠 → 残留兜底 ——
	var out: Dictionary = _gv._layout._compute_layout(nodes, {})
	_gv._node_center = out.duplicate()
	_gv._layout._apply_global_overlap_fix()
	if _gv._layout._has_overlap():
		out = _gv._layout._resolve_residual_overlaps(nodes, {})
		_gv._node_center = out.duplicate()
	out = _gv._node_center

	var expected := {}
	for id in out:
		expected[str(id)] = [snappedf(out[id].x, 0.01), snappedf(out[id].y, 0.01)]
	var fixture := {
		"name": str(sc["name"]),
		"canvas": [_canvas.size.x, _canvas.size.y],
		"nodes": _gv._layout.layout_diagnostic().get("nodes", []),
		"relations": rel,
		"pins": sc["pins"],
		"manual": sc["manual"],
		"expected": expected,
		"expected_violations": _gv._layout.check_invariants(),
	}
	var path: String = "%s/%s.json" % [OUT_DIR, str(sc["name"])]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("FAIL 无法写入 " + path)
		return
	f.store_string(JSON.stringify(fixture, "  "))
	f.close()
	print("  fixture %s → %s（%d 节点，违规 %d 项）"
		% [sc["name"], path, (fixture["nodes"] as Array).size(), (fixture["expected_violations"] as Array).size()])
