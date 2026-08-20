extends Control
## 交互链路诊断：顶栏按钮（线型/性质/连线）+ 连线模式建边，模拟真实点击。
## 运行：godot --headless res://tools/test_wall_interact.tscn --quit

func _ready() -> void:
	await _run()
	get_tree().quit(0)

func _run() -> void:
	# 准备线索（模拟场景收集）
	var clues: Array = []
	if ClueSystem:
		ClueSystem.clear_source("wall_diag")
		ClueSystem.collect_clue_from_catalog("c1", "车轮印", "窄轮距马车", true, "wall_diag", -1, "", "", [], [], [], ["NPC_WT"])
		ClueSystem.collect_clue_from_catalog("c2", "毒药", "生物碱毒药", true, "wall_diag", -1)
		clues = ClueSystem.get_collected("wall_diag")
		print("[DIAG] clues=%d %s" % [clues.size(), clues])

	var hypo := {"title": "马车夫作案", "description": "凶手是出租马车夫", "milestones": []}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW_DIAG"
	add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1)
	await get_tree().create_timer(0.2).timeout

	var gv = wall.get("_graph_view")
	print("[DIAG] graph_view=%s" % gv)

	# 1) 模拟点击「虚线」按钮
	wall._set_pen_dashed(true)
	print("[DIAG] after 虚线: gv._pen_dashed=%s" % gv._pen_dashed)
	print("[DIAG] after 虚线: solid_btn.pressed=%s dashed_btn.pressed=%s" % [wall._pen_solid_btn.button_pressed, wall._pen_dashed_btn.button_pressed])

	# 2) 模拟点击「反对」按钮
	wall._set_pen_color("red")
	print("[DIAG] after 反对: gv._pen_color_key=%s gv._pen_dashed=%s" % [gv._pen_color_key, gv._pen_dashed])

	# 3) 模拟点击「🔗 连线」
	wall._connect_btn.button_pressed = true
	wall._on_top_connect_toggle()
	print("[DIAG] after 连线: gv._connect_mode=%s connect_btn.pressed=%s" % [gv._connect_mode, wall._connect_btn.button_pressed])

	# 4) 连线模式两次点节点（线索 c1 → 推断）
	print("[DIAG] relations before=%d" % wall._relations.size())
	var r1 = gv._handle_connect_click("c1", "clue")
	print("[DIAG] click c1 -> %s, first=%s" % [r1, gv._connect_first_id])
	# 找推断节点 id（假设 h0）
	var hypo_id: String = ""
	for id in gv._node_kind:
		if gv._node_kind[id] == "hypo":
			hypo_id = id
			break
	print("[DIAG] hypo node id=%s" % hypo_id)
	var r2 = gv._handle_connect_click(hypo_id, "hypo")
	print("[DIAG] click hypo -> %s, first=%s" % [r2, gv._connect_first_id])
	print("[DIAG] relations after=%d" % wall._relations.size())
	for r in wall._relations:
		print("[DIAG]   rel: %s -> %s kind=%s ck=%s dashed=%s" % [r.get("from",""), r.get("to",""), r.get("kind",""), r.get("color_key",""), r.get("dashed",false)])
