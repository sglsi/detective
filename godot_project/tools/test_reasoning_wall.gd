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
	wall.queue_free()
	await create_timer(0.1).timeout
	print("REASONING_WALL_TEST: PASS")
	quit(0)
