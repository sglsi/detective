extends Control

## 单元验证 _apply_global_overlap_fix 的四类相交组合：
##   A 上方可动 × 下方可动  → 推下方（原行为）
##   B 上方可动 × 下方**钉位** → 必须推上方（原实现直接 continue → 漏修，用户截图那种「覆盖」）
##   C 上方钉位 × 下方可动  → 推下方
##   D 上方钉位 × 下方钉位  → 无解，跳过（且不得把两者挪动）
## 运行：godot --headless --path godot_project res://scenes/test_overlap_pinned_unit.tscn

var _fail := 0

func _ready() -> void:
	_run()

func _chk(cond: bool, name: String) -> void:
	if cond: print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)


var _ids: Array = []

func _mk() -> Control:
	var gv = load("res://scripts/clue/graph_view_controller.gd").new()
	add_child(gv)
	var clues := [{"id": "c1", "name": "线索一"}, {"id": "c2", "name": "线索二"},
		{"id": "c3", "name": "线索三"}, {"id": "c4", "name": "线索四"}]
	var hypo := {"battlefield": {"hypotheses": [
		{"id": "A", "text": "甲", "correct": true, "gate_clue_ids": ["c1"]},
		{"id": "B", "text": "乙", "correct": true, "gate_clue_ids": ["c2"]},
		{"id": "C", "text": "丙", "correct": true, "gate_clue_ids": ["c3"]},
		{"id": "D", "text": "丁", "correct": true, "gate_clue_ids": ["c4"]}], "conclusions": []}}
	gv.build({"clues": clues, "hypo": hypo, "persons": [], "difficulty": 1, "editable": true,
		"show_toolbar": true, "state_store": {}, "on_tag": Callable(), "on_add_edge": Callable(),
		"on_remove_relation": Callable(), "on_close": Callable()})
	if gv._canvas and is_instance_valid(gv._canvas):
		gv._canvas.size = Vector2(1920, 1080)
	gv._rebuild_graph()
	return gv

func _collect_ids(gv) -> void:
	_ids = []
	for k in gv._node_kind.keys():
		if str(gv._node_kind[k]) == "hypo":
			_ids.append(str(k))
	while _ids.size() < 2:
		_ids.append("__pad_%d" % _ids.size())

func _overlap_pairs(gv) -> Array:
	var out := []
	for i in range(_ids.size()):
		for j in range(i + 1, _ids.size()):
			var a = gv._node_views.get(_ids[i])
			var b = gv._node_views.get(_ids[j])
			if a == null or b == null: continue
			if Rect2(a.position, a.size).intersects(Rect2(b.position, b.size)):
				out.append("%s✕%s" % [_ids[i], _ids[j]])
	return out


## 把 two 摆成「上、下且相交」，指定谁是钉位，然后跑去重叠修复
func _case(tag: String, gv, pin_a: bool, pin_b: bool, expect_fixed: bool) -> void:
	var ida: String = _ids[0]
	var idb: String = _ids[1]
	gv._manual_nodes = []
	if pin_a: gv._manual_nodes.append(ida)
	if pin_b: gv._manual_nodes.append(idb)
	gv._node_center[ida] = Vector2(600.0, 300.0)
	gv._node_center[idb] = Vector2(600.0, 330.0)
	for id in [ida, idb]:
		var v = gv._node_views[id]
		v.position = gv._node_center[id] - v.size * 0.5
	var before := _overlap_pairs(gv)
	gv._layout._apply_global_overlap_fix()
	var after := _overlap_pairs(gv)
	print("  [%s] 修复前=%s 修复后=%s" % [tag, str(before), str(after)])
	print("      上(%s)=%s  下(%s)=%s" % [ida, str(gv._node_center[ida]), idb, str(gv._node_center[idb])])
	if expect_fixed:
		_chk(after.is_empty(), tag + "：应已解决重叠")
	else:
		_chk(before.is_empty() or not after.is_empty(), tag + "：双方均刚性时应保持不误移")
	if pin_a: _chk(gv._node_center[ida] == Vector2(600.0, 300.0), tag + "：钉位上方节点未被移动")
	if pin_b: _chk(gv._node_center[idb] == Vector2(600.0, 330.0), tag + "：钉位下方节点未被移动")


func _run() -> void:
	await get_tree().process_frame
	var gv := _mk()
	await get_tree().process_frame
	# 派生 4 条推断，产生真实节点
	gv._derive_hypo("c1", "A"); await get_tree().process_frame
	gv._derive_hypo("c2", "B"); await get_tree().process_frame
	gv._derive_hypo("c3", "C"); await get_tree().process_frame
	gv._derive_hypo("c4", "D"); await get_tree().process_frame
	gv._rebuild_graph(); await get_tree().process_frame
	_collect_ids(gv)
	print("  节点 id = %s" % str(_ids))
	# 先整体验证一次「无人物自由推导 + 真实视图矩形」下确实无重叠
	# （对照 test_overlap_after_derive：后者用合成高度模型，与当前"布局消费真实 size"口径不一致 → 假阳性）
	var all_ids := []
	for k in gv._node_views.keys():
		all_ids.append(str(k))
	var ov_all := []
	for i in range(all_ids.size()):
		for j in range(i + 1, all_ids.size()):
			var va = gv._node_views[all_ids[i]]
			var vb = gv._node_views[all_ids[j]]
			if Rect2(va.position, va.size).intersects(Rect2(vb.position, vb.size)):
				ov_all.append("%s✕%s" % [all_ids[i], all_ids[j]])
	_chk(ov_all.is_empty(), "无人物自由推导后（真实矩形）无重叠" + ("  实际:%s" % str(ov_all) if not ov_all.is_empty() else ""))
	print("=== 四类相交组合 ===")
	_case("A 上可动/下可动", gv, false, false, true)
	_case("B 上可动/下钉位", gv, false, true, true)
	_case("C 上钉位/下可动", gv, true, false, true)
	_case("D 上钉位/下钉位", gv, true, true, false)
	print("=== OVERLAP_PINNED_UNIT: %s (fail=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _fail])
	get_tree().quit(0 if _fail == 0 else 1)
