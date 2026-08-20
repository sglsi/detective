extends Control
## 验证：①用户关系边 always=true（Mode C 常显）②_remove_edge 删除连线（可撤销）。
## 运行：godot --headless res://tools/test_remove_edge.tscn

func _ready() -> void:
	_run()

func _run() -> void:
	var clues: Array = []
	if ClueSystem:
		ClueSystem.clear_source("rm_t")
		ClueSystem.collect_clue_from_catalog("c1", "车轮印", "窄轮距马车", true, "rm_t", -1, "", "", [], [], [], ["NPC_WT"])
		ClueSystem.collect_clue_from_catalog("c2", "毒药", "生物碱毒药", true, "rm_t", -1)
		clues = ClueSystem.get_collected("rm_t")
	var hypo := {"title": "马车夫作案", "description": "凶手是出租马车夫", "milestones": []}
	var wall = load("res://scripts/clue/reasoning_wall.gd").new()
	wall.name = "RW_RM"
	add_child(wall)
	wall.setup(clues, hypo, Callable(), Callable(), 1)
	await get_tree().create_timer(0.4).timeout
	var gv = wall.get("_graph_view")
	var hypo_id: String = ""
	for id in gv._node_kind:
		if gv._node_kind[id] == "hypo":
			hypo_id = id; break
	# 建边
	gv._handle_connect_click("c1", "clue")
	gv._handle_connect_click(hypo_id, "hypo")
	await get_tree().create_timer(0.1).timeout
	print("[RM] after add: relations=%d edges=%d" % [wall._relations.size(), gv._edge_list.size()])
	var found_always := false
	for e in gv._edge_list:
		if e.from == "c1" and e.to == hypo_id:
			found_always = e.always
	print("[RM] c1->hypo edge always=%s (期望 true=常显)" % found_always)
	# 删除（kind 取实际建立的值）
	var actual_kind: String = wall._relations[0].get("kind", "relate")
	print("[RM] actual kind=%s" % actual_kind)
	gv._remove_edge("c1", hypo_id, actual_kind)
	await get_tree().create_timer(0.1).timeout
	print("[RM] after remove: relations=%d (期望 0)" % wall._relations.size())
	# 撤销恢复
	gv.undo()
	await get_tree().create_timer(0.1).timeout
	print("[RM] after undo: relations=%d (期望 1)" % wall._relations.size())
	get_tree().quit(0)
