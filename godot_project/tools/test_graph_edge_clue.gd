extends SceneTree
## 图谱三需求回归（2026-08-21）：
##  1) 节点文本框真实自适应（长名卡片更高/更宽，替代字符数估算）
##  2) 关系连线可选中点击 → 删除 / 线型切换 / 性质切换（含坐标命中修复验证）
##  3) 左侧拖线索关联推断后，线索节点入图 + associated 标记（实线绿边反馈）
## 运行：godot --headless --script res://tools/test_graph_edge_clue.gd

var _pass := 0
var _fail := 0

func _initialize() -> void:
	await _run()

func _chk(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("[PASS] " + name)
	else:
		_fail += 1
		print("[FAIL] " + name)

func _find_edge(gv, id_a: String, id_b: String) -> Dictionary:
	for e in gv._edge_list:
		if (e.get("from", "") == id_a and e.get("to", "") == id_b) \
			or (e.get("from", "") == id_b and e.get("to", "") == id_a):
			return e
	return {}

func _rel_state(gv, id_a: String, id_b: String) -> Array:
	# 返回 [是否存在, kind, dashed]
	for r in gv._relations:
		if (r.get("from", "") == id_a and r.get("to", "") == id_b) \
			or (r.get("from", "") == id_b and r.get("to", "") == id_a):
			return [true, r.get("kind", ""), bool(r.get("dashed", false))]
	return [false, "", false]

func _run() -> void:
	# c1 短名挂 P_A（焦点）；c3 超长名挂 P_A（自适应）；c2 不挂人物（拖拽"外来"线索）
	var clues := [
		{"id": "c1", "name": "车轮印", "desc": "窄轮距马车", "correct": true, "related_npcs": ["P_A"]},
		{"id": "c3", "name": "这是一条非常非常长的线索名称用来测试文本框自适应换行效果好不好", "desc": "长名线索", "correct": true, "related_npcs": ["P_A"]},
		{"id": "c2", "name": "身高特征", "desc": "凶手高大", "correct": true, "related_npcs": []},
	]
	var hypo := {"title": "测试假设", "battlefield": {"hypotheses": [{"id": "H1", "text": "马车夫作案"}]}}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW"
	root.add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1)
	await process_frame
	await process_frame
	var gv = wall._graph_view
	_chk(gv != null and is_instance_valid(gv), "图谱视图已构建")
	_chk(gv._focus_person == "P_A", "焦点人物派生为 P_A (实得 %s)" % gv._focus_person)

	# ===== 需求1：文本框真实自适应 =====
	var v_c1: Control = gv._node_views.get("c1")
	var v_c3: Control = gv._node_views.get("c3")
	_chk(v_c1 != null and v_c3 != null, "c1/c3 节点已渲染")
	_chk(v_c3.size.y > v_c1.size.y,
		"长名线索卡片更高（自适应，c1.y=%d c3.y=%d）" % [v_c1.size.y, v_c3.size.y])
	_chk(v_c3.size.x >= 160.0 and v_c3.size.x <= 500.0,
		"长名卡片经自适应封顶宽度合理 [160,500]（实得 %.0f）" % v_c3.size.x)
	_chk(v_c1.size.x >= 125.0 and v_c1.size.x <= 180.0,
		"短名卡片宽度也收窄（c1.x=%.0f）" % v_c1.size.x)

	# ===== 需求3：拖拽关联（等价 _confirm_link 路径）后线索入图 =====
	_chk(not gv._node_views.has("c2"), "关联前 c2 不显示（非焦点人物线索）")
	gv._confirm_link("c2", "H1", "hypo")
	_chk(gv._node_views.has("c2"), "关联后 c2 作为节点出现在图谱中")
	var c2_assoc := false
	for c in gv._clues:
		if c.get("id", "") == "c2":
			c2_assoc = bool(c.get("associated", false))
	_chk(c2_assoc, "c2 associated=true（实线绿边已关联反馈）")
	var e: Dictionary = _find_edge(gv, "c2", "H1")
	_chk(not e.is_empty(), "c2↔H1 边已派生进 _edge_list")
	_chk(bool(e.get("always", false)), "该边 always=true 常显（可直接点中）")

	# ===== 需求2：边选中（坐标命中修复）+ 线型/性质切换 + 删除 =====
	var a: Vector2 = gv._node_center.get("c2", Vector2.ZERO)
	var b: Vector2 = gv._node_center.get("H1", Vector2.ZERO)
	var mid := (a + b) * 0.5
	var delta := b - a
	var perp := Vector2(-delta.y, delta.x).normalized() * 50.0
	var ctrl := mid + perp
	var p05 := 0.25 * a + 0.5 * ctrl + 0.25 * b   # 贝塞尔曲线中点（实际绘制路径上的点）
	var global_pos: Vector2 = gv._canvas.get_global_transform() * p05
	gv._on_canvas_left_click(global_pos)
	_chk(gv._selected_edge >= 0, "点击连线曲线命中选中 (idx=%d)" % gv._selected_edge)
	_chk(gv._edge_menu != null and is_instance_valid(gv._edge_menu), "连线编辑菜单已弹出")

	var st0: Array = _rel_state(gv, "c2", "H1")
	gv._edge_toggle_dashed(e)
	var st1: Array = _rel_state(gv, "c2", "H1")
	_chk(st1[0] and bool(st1[2]) != bool(st0[2]), "线型切换生效 (dashed %s→%s)" % [st0[2], st1[2]])

	var kind_before: String = st1[1]
	gv._edge_cycle_kind(e)
	var st2: Array = _rel_state(gv, "c2", "H1")
	_chk(st2[0] and st2[1] != kind_before, "性质切换生效 (%s→%s)" % [kind_before, st2[1]])

	var e2: Dictionary = _find_edge(gv, "c2", "H1")
	gv._edge_delete(e2)
	var st3: Array = _rel_state(gv, "c2", "H1")
	_chk(not st3[0], "删除连线后 c2↔H1 关系已移除")

	print("=== GRAPH_FEAT_RESULT: %s (PASS=%d FAIL=%d) ===" % ["PASS" if _fail == 0 else "FAIL", _pass, _fail])
	quit()
