extends SceneTree

func _initialize() -> void:
	await create_timer(0.2).timeout
	var rw_cls = load("res://scripts/clue/reasoning_wall.gd")
	if not rw_cls:
		print("REASONING_WALL_TEST: FAIL - cannot load script")
		quit(1)
		return

	var wall = rw_cls.new()
	wall.name = "TestReasoningWall"
	root.add_child(wall)

	var clues := [
		{"id":"c1","name":"热带晒痕","desc":"手腕肤色分界明显","correct":true,"source":"观察"},
		{"id":"c2","name":"旧伤","desc":"左臂旧伤","correct":true,"source":"观察"},
		{"id":"c3","name":"袖口磨损","desc":"衣服旧了","correct":false,"source":"观察"},
	]
	var hypo := {
		"title": "测试假设",
		"description": "这是一个用于 headless 冒烟的测试假设",
		"battlefield": {
			"hypotheses": [
				{"id":"H1","text":"线索A支持假设","correct":true},
				{"id":"H2","text":"线索B反对假设","correct":false},
			],
			"contradictions": [],
		},
		"milestones": [
			{"id":"M1","text":"里程碑1"},
			{"id":"M2","text":"里程碑2"},
		],
	}
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable())
	await create_timer(0.1).timeout

	# 测试关联
	wall.test_associate("c1")
	wall.test_associate("c2")
	var verdict: int = wall.get_verdict()
	var ms: Dictionary = wall.get_milestone_state()
	var diff: int = wall.get_difficulty()
	print("REASONING_WALL_TEST: verdict=%d milestones=%s/%s diff=%d" % [verdict, ms.get("confirmed"), ms.get("total"), diff])

	# UI 结构检查：确保关键容器已创建且有子节点
	var clue_count: int = 0
	var tree_count: int = 0
	var battle_count: int = 0
	var assoc_count: int = 0
	if wall.has_method("_debug_ui_counts"):
		var ui_counts: Dictionary = wall._debug_ui_counts()
		clue_count = ui_counts.get("clue_list", 0)
		tree_count = ui_counts.get("tree_root", 0)
		battle_count = ui_counts.get("battlefield", 0)
		assoc_count = ui_counts.get("assoc_list", 0)
		print("REASONING_WALL_TEST: ui_counts=%s" % str(ui_counts))

	# 历史面板反射调用测试
	wall._show_history_panel()
	await create_timer(0.05).timeout
	var hist: Variant = wall.get("_history_panel")
	var has_history: bool = hist != null and is_instance_valid(hist as Object)
	print("REASONING_WALL_TEST: history_panel=%s" % has_history)
	wall._close_history_panel()

	wall.queue_free()
	await create_timer(0.1).timeout
	print("REASONING_WALL_TEST: PASS")
	quit(0)
