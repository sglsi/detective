extends SceneTree

# 场景一教学墙（非 case_wide）验证：未放置线索默认进左栏「已收集线索栏」，不在画布。

func _init() -> void:
	# 首帧后再 load（autoload 如图谱组件此时已注册，直接 load 会因 ClueSystem 未注册编译失败）
	await process_frame
	await process_frame
	var wall: Control = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "ReasoningWall"
	root.add_child(wall)
	wall.size = Vector2(1920, 1080)
	await process_frame

	var clues: Array = []
	for i in range(3):
		clues.append({"id": "s1_c%d" % i, "name": "教学线索%d" % i, "desc": "d", "kind": "clue",
			"source": "watson", "related_npcs": ["NPC_WT"]})
	var hypo := {"case_name": "场景一教学", "chain_id": "chain"}
	# auto_fold=false → non case_wide（教学墙）
	wall.setup(clues, hypo, Callable(), Callable(), 1, Callable(), {}, Callable(), false)
	await process_frame
	await process_frame

	var gv: Control = wall._graph_view
	var nl: Array = gv._node_list()
	var on_canvas: Array = []
	for n in nl:
		if n.get("kind", "") == "clue":
			on_canvas.append(n.get("id", ""))
	var placed: Array = gv._placed_clues
	print("[Q5] 非case_wide 画布线索=", on_canvas, " placed=", placed)
	var s1c0: bool = "s1_c0" in placed
	var s1c0_canvas: bool = "s1_c0" in on_canvas
	print("[Q5] s1_c0 已在画布=", s1c0_canvas, " 正确(应false,在左栏)=", not s1c0_canvas)
	if not s1c0_canvas:
		print("Q5_OK 场景一教学墙线索默认进左栏")
	else:
		print("Q5_FAIL 场景一线索仍在画布")
	quit(99)