extends Control
## 验证 _commit_move 拖拽建边（程序化：不依赖真实 GUI 拾取）。
## 运行：godot --headless res://tools/test_drag_edge.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	var clues: Array = []
	if ClueSystem:
		ClueSystem.clear_source("drag_t")
		ClueSystem.collect_clue_from_catalog("c1", "车轮印", "窄轮距马车", true, "drag_t", -1, "", "", [], [], [], ["NPC_WT"])
		clues = ClueSystem.get_collected("drag_t")
	var hypo := {"title": "马车夫作案", "description": "凶手是出租马车夫", "milestones": []}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW_DRAG"
	add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1)
	await get_tree().create_timer(0.4).timeout
	var gv = wall.get("_graph_view")
	var hypo_id: String = ""
	for id in gv._node_kind:
		if gv._node_kind[id] == "hypo":
			hypo_id = id; break
	print("[DRAG] hypo=%s relations_before=%d" % [hypo_id, wall._relations.size()])
	var n2: Control = gv._node_views.get(hypo_id)
	var target: Vector2 = n2.get_global_rect().get_center()
	# 模拟：按下 c1（drag_start 记录），移动（warp 鼠标到目标中心），松手提交
	var n1: Control = gv._node_views.get("c1")
	var start: Vector2 = n1.get_global_rect().get_center()
	gv._drag_start = target - Vector2(40, 0)
	Input.warp_mouse(target)
	await get_tree().create_timer(0.05).timeout
	var gp: Vector2 = get_viewport().get_mouse_position()
	print("[DRAG] start=%s warp_target=%s actual_gp=%s" % [start, target, gp])
	# 直接验证命中函数（显式坐标）
	var drop: String = gv._drop_node_except(target, "c1")
	var near: String = gv._nearest_node_except(target, "c1", 48.0)
	print("[DRAG] drop_node_except(H_core center)=%s nearest=%s" % [drop, near])
	# 用实际 gp 测
	var drop2: String = gv._drop_node_except(gp, "c1")
	var near2: String = gv._nearest_node_except(gp, "c1", 48.0)
	print("[DRAG] with actual gp: drop=%s nearest=%s" % [drop2, near2])
	gv._dragging = true
	gv._drag_id = "c1"
	gv._drag_mode = "move"
	gv._commit_move("c1", target)
	await get_tree().create_timer(0.15).timeout
	print("[DRAG] after commit_move: relations=%d" % wall._relations.size())
	for rr in wall._relations:
		print("[DRAG]   rel: %s -> %s kind=%s ck=%s dashed=%s" % [rr.get("from",""), rr.get("to",""), rr.get("kind",""), rr.get("color_key",""), rr.get("dashed",false)])
	get_tree().quit(0)
